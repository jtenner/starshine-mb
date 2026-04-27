///|
priv enum DirectizeTarget {
  DirectizeKnown(@lib.FuncIdx)
  DirectizeTrap
  DirectizeUnknown
}

///|
priv struct DirectizeTableInfo {
  can_optimize : Bool
  entries : Array[@lib.FuncIdx?]
}

///|
priv struct DirectizeInfo {
  env : @validate.Env
  func_types : Array[@lib.TypeIdx]
  tables : Array[DirectizeTableInfo]
}

///|
priv struct DirectizeFuncContext {
  info : DirectizeInfo
  base_local_count : Int
  extra_locals : Array[@lib.ValType]
}

///|
priv struct DirectizeSelectRewrite {
  arg_start : Int
  arg_instrs : Array[@lib.Instruction]
  condition_instrs : Array[@lib.Instruction]
  params : Array[@lib.ValType]
  results : Array[@lib.ValType]
  is_return : Bool
  then_func : @lib.FuncIdx
  else_func : @lib.FuncIdx
}

///|
fn directize_summary() -> String {
  "Rewrite provably known indirect calls through immutable table facts into direct calls, traps, or select-lowered branches."
}

///|
fn directize_table_slot(table_idx : @lib.TableIdx) -> Int {
  match table_idx {
    @lib.TableIdx(raw) => raw.reinterpret_as_int()
  }
}

///|
fn directize_func_slot(func_idx : @lib.FuncIdx) -> Int {
  match func_idx {
    @lib.FuncIdx(raw) => raw.reinterpret_as_int()
  }
}

///|
fn directize_const_i32(expr : @lib.Expr) -> Int? {
  match expr {
    @lib.Expr([@lib.I32Const(@lib.I32(value))]) => Some(value)
    _ => None
  }
}

///|
fn directize_func_from_elem_expr(expr : @lib.Expr) -> @lib.FuncIdx?? {
  match expr {
    @lib.Expr([@lib.RefFunc(func_idx)]) => Some(Some(func_idx))
    @lib.Expr([@lib.RefNull(_)]) => Some(None)
    _ => None
  }
}

///|
fn directize_imported_table_count(mod_ : @lib.Module) -> Int {
  let mut count = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.TableExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn directize_imported_func_count(mod_ : @lib.Module) -> Int {
  let mut count = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn directize_table_types(mod_ : @lib.Module) -> Array[@lib.TableType] {
  let tables : Array[@lib.TableType] = []
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.TableExternType(table_type)) =>
            tables.push(table_type)
          _ => ()
        }
      }
    None => ()
  }
  match mod_.table_sec {
    Some(@lib.TableSec(defs)) =>
      for table in defs {
        match table {
          @lib.Table(table_type, _) => tables.push(table_type)
        }
      }
    None => ()
  }
  tables
}

///|
fn directize_table_initial_size(table_type : @lib.TableType) -> Int? {
  match table_type {
    @lib.TableType(_, @lib.I32Limits(initial, _)) =>
      Some(initial.reinterpret_as_int())
    @lib.TableType(_, @lib.I64Limits(initial, _)) =>
      if initial > 2147483647UL {
        None
      } else {
        Some(initial.to_int())
      }
  }
}

///|
fn directize_func_types(mod_ : @lib.Module) -> Array[@lib.TypeIdx] {
  let types : Array[@lib.TypeIdx] = []
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(type_idx)) =>
            types.push(type_idx)
          _ => ()
        }
      }
    None => ()
  }
  match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) =>
      for type_idx in type_idxs {
        types.push(type_idx)
      }
    None => ()
  }
  types
}

///|
fn directize_mark_table(
  tables : Array[Bool],
  table_idx : @lib.TableIdx,
  value : Bool,
) -> Unit {
  let slot = directize_table_slot(table_idx)
  if slot >= 0 && slot < tables.length() {
    tables[slot] = value
  }
}

///|
fn directize_mark_mutated_instr(
  mutated : Array[Bool],
  instr : @lib.Instruction,
) -> Unit {
  match instr {
    @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
      directize_mark_mutated_instrs(mutated, body)
    @lib.If(_, then_body, else_body) => {
      directize_mark_mutated_instrs(mutated, then_body)
      match else_body {
        Some(body) => directize_mark_mutated_instrs(mutated, body)
        None => ()
      }
    }
    @lib.TryTable(_, _, @lib.Expr(body)) =>
      directize_mark_mutated_instrs(mutated, body)
    @lib.TableSet(table_idx)
    | @lib.TableGrow(table_idx)
    | @lib.TableFill(table_idx) =>
      directize_mark_table(mutated, table_idx, true)
    @lib.TableInit(_, table_idx) =>
      directize_mark_table(mutated, table_idx, true)
    @lib.TableCopy(dst, _) => directize_mark_table(mutated, dst, true)
    _ => ()
  }
}

///|
fn directize_mark_mutated_instrs(
  mutated : Array[Bool],
  instrs : Array[@lib.Instruction],
) -> Unit {
  for instr in instrs {
    directize_mark_mutated_instr(mutated, instr)
  }
}

///|
fn directize_mutated_tables(
  mod_ : @lib.Module,
  table_count : Int,
) -> Array[Bool] {
  let mutated = Array::make(table_count, false)
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(_, @lib.Expr(instrs)) = func
        directize_mark_mutated_instrs(mutated, instrs)
      }
    None => ()
  }
  mutated
}

///|
fn directize_base_table_infos(mod_ : @lib.Module) -> Array[DirectizeTableInfo] {
  let table_types = directize_table_types(mod_)
  let imported_tables = directize_imported_table_count(mod_)
  let mutated = directize_mutated_tables(mod_, table_types.length())
  let exported = Array::make(table_types.length(), false)
  match mod_.export_sec {
    Some(@lib.ExportSec(exports)) =>
      for export_ in exports {
        match export_ {
          @lib.Export(_, @lib.TableExternIdx(table_idx)) =>
            directize_mark_table(exported, table_idx, true)
          _ => ()
        }
      }
    None => ()
  }
  let infos : Array[DirectizeTableInfo] = []
  for idx = 0; idx < table_types.length(); idx = idx + 1 {
    let size = directize_table_initial_size(table_types[idx])
    let can_optimize = idx >= imported_tables &&
      !mutated[idx] &&
      !exported[idx] &&
      size is Some(_)
    infos.push({
      can_optimize,
      entries: match size {
        Some(n) => Array::make(n, None)
        None => []
      },
    })
  }
  infos
}

///|
fn directize_disable_table(
  tables : Array[DirectizeTableInfo],
  table_slot : Int,
) -> Unit {
  if table_slot >= 0 && table_slot < tables.length() {
    tables[table_slot] = { ..tables[table_slot], can_optimize: false }
  }
}

///|
fn directize_write_table_entry(
  tables : Array[DirectizeTableInfo],
  table_slot : Int,
  offset : Int,
  value : @lib.FuncIdx?,
) -> Unit {
  if table_slot < 0 || table_slot >= tables.length() {
    return
  }
  let info = tables[table_slot]
  if !info.can_optimize || offset < 0 || offset >= info.entries.length() {
    directize_disable_table(tables, table_slot)
    return
  }
  info.entries[offset] = value
}

///|
fn directize_record_elem_funcs(
  tables : Array[DirectizeTableInfo],
  table_slot : Int,
  base : Int,
  funcs : Array[@lib.FuncIdx],
) -> Unit {
  let mut rel = 0
  for func_idx in funcs {
    directize_write_table_entry(tables, table_slot, base + rel, Some(func_idx))
    rel += 1
  }
}

///|
fn directize_record_elem_exprs(
  tables : Array[DirectizeTableInfo],
  table_slot : Int,
  base : Int,
  exprs : Array[@lib.Expr],
) -> Unit {
  let mut rel = 0
  for expr in exprs {
    match directize_func_from_elem_expr(expr) {
      Some(value) =>
        directize_write_table_entry(tables, table_slot, base + rel, value)
      None => directize_disable_table(tables, table_slot)
    }
    rel += 1
  }
}

///|
fn directize_populate_table_infos(
  mod_ : @lib.Module,
  tables : Array[DirectizeTableInfo],
) -> Unit {
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) =>
      for elem in elems {
        match elem {
          @lib.Elem(@lib.Active(table_idx, offset_expr), kind) => {
            let table_slot = directize_table_slot(table_idx)
            match directize_const_i32(offset_expr) {
              Some(base) =>
                match kind {
                  @lib.FuncsElemKind(funcs) =>
                    directize_record_elem_funcs(tables, table_slot, base, funcs)
                  @lib.FuncExprsElemKind(exprs)
                  | @lib.TypedExprsElemKind(_, exprs) =>
                    directize_record_elem_exprs(tables, table_slot, base, exprs)
                }
              None => directize_disable_table(tables, table_slot)
            }
          }
          _ => ()
        }
      }
    None => ()
  }
}

///|
fn directize_build_info(mod_ : @lib.Module) -> DirectizeInfo {
  let tables = directize_base_table_infos(mod_)
  directize_populate_table_infos(mod_, tables)
  {
    env: @validate.Env::new().with_module(mod_),
    func_types: directize_func_types(mod_),
    tables,
  }
}

///|
fn directize_func_type(
  info : DirectizeInfo,
  func_idx : @lib.FuncIdx,
) -> @lib.TypeIdx? {
  let slot = directize_func_slot(func_idx)
  if slot >= 0 && slot < info.func_types.length() {
    Some(info.func_types[slot])
  } else {
    None
  }
}

///|
fn directize_func_type_matches(
  info : DirectizeInfo,
  func_idx : @lib.FuncIdx,
  call_type : @lib.TypeIdx,
) -> Bool {
  match directize_func_type(info, func_idx) {
    Some(type_idx) =>
      @validate.Match::matches(
        @lib.ExternType::func(type_idx),
        @lib.ExternType::func(call_type),
        info.env,
      )
    None => false
  }
}

///|
fn directize_classify_target(
  info : DirectizeInfo,
  table_idx : @lib.TableIdx,
  offset : Int,
  call_type : @lib.TypeIdx,
) -> DirectizeTarget {
  let table_slot = directize_table_slot(table_idx)
  if table_slot < 0 || table_slot >= info.tables.length() {
    return DirectizeUnknown
  }
  let table_info = info.tables[table_slot]
  if !table_info.can_optimize {
    return DirectizeUnknown
  }
  if offset < 0 || offset >= table_info.entries.length() {
    return DirectizeTrap
  }
  match table_info.entries[offset] {
    Some(func_idx) =>
      if directize_func_type_matches(info, func_idx, call_type) {
        DirectizeKnown(func_idx)
      } else {
        DirectizeTrap
      }
    None => DirectizeTrap
  }
}

///|
fn directize_call_param_types(
  info : DirectizeInfo,
  type_idx : @lib.TypeIdx,
) -> Array[@lib.ValType]? {
  match info.env.resolve_functype(type_idx) {
    Some(@lib.FuncType(params, _)) => Some(params)
    None => None
  }
}

///|
fn directize_call_signature(
  info : DirectizeInfo,
  type_idx : @lib.TypeIdx,
) -> (Array[@lib.ValType], Array[@lib.ValType])? {
  match info.env.resolve_functype(type_idx) {
    Some(@lib.FuncType(params, results)) => Some((params, results))
    None => None
  }
}

///|
fn directize_instr_is_removable_if_trapped(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.I32Const(_) | @lib.I64Const(_) | @lib.F32Const(_) | @lib.F64Const(_) =>
      true
    @lib.LocalGet(_) => true
    @lib.GlobalGet(_) => true
    @lib.RefNull(_) | @lib.RefFunc(_) => true
    _ => false
  }
}

///|
fn directize_instrs_are_removable_if_trapped(
  instrs : Array[@lib.Instruction],
) -> Bool {
  instrs.all(fn(instr) { directize_instr_is_removable_if_trapped(instr) })
}

///|
fn directize_stack_matches(
  actual : Array[@lib.ValType],
  expected : Array[@lib.ValType],
  env : @validate.Env,
) -> Bool {
  if actual.length() != expected.length() {
    return false
  }
  @validate.Match::matches(actual, expected, env)
}

///|
fn directize_suffix_produces_params(
  suffix : Array[@lib.Instruction],
  params : Array[@lib.ValType],
  info : DirectizeInfo,
) -> Bool {
  match
    @validate.Typecheck::typecheck(
      @lib.Expr::new(suffix),
      @validate.make_state(info.env, []),
    ) {
    Ok(state) =>
      state.reachable &&
      state.escape == @validate.tc_escape_none() &&
      directize_stack_matches(state.stack, params, info.env)
    Err(_) => false
  }
}

///|
fn directize_find_removable_arg_suffix(
  out : Array[@lib.Instruction],
  params : Array[@lib.ValType],
  info : DirectizeInfo,
) -> Int? {
  let end = out.length() - 1
  for start = end; start >= 0; start = start - 1 {
    let suffix : Array[@lib.Instruction] = []
    for idx = start; idx < end; idx = idx + 1 {
      suffix.push(out[idx])
    }
    if directize_instrs_are_removable_if_trapped(suffix) &&
      directize_suffix_produces_params(suffix, params, info) {
      return Some(start)
    }
  }
  None
}

///|
fn directize_truncate_out(
  out : Array[@lib.Instruction],
  new_length : Int,
) -> Unit {
  while out.length() > new_length {
    ignore(out.pop())
  }
}

///|
fn directize_instr_slice(
  instrs : Array[@lib.Instruction],
  start : Int,
  end : Int,
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  for idx = start; idx < end; idx = idx + 1 {
    out.push(instrs[idx])
  }
  out
}

///|
fn directize_allocate_local(
  ctx : DirectizeFuncContext,
  vt : @lib.ValType,
) -> @lib.LocalIdx {
  let slot = ctx.base_local_count + ctx.extra_locals.length()
  ctx.extra_locals.push(vt)
  @lib.LocalIdx::new(slot.reinterpret_as_uint())
}

///|
fn directize_blocktype_for_results(
  results : Array[@lib.ValType],
) -> @lib.BlockType? {
  if results.length() == 0 {
    Some(@lib.BlockType::void_())
  } else if results.length() == 1 {
    Some(@lib.BlockType::val_type(results[0]))
  } else {
    None
  }
}

///|
fn directize_push_trap_replacement(
  out : Array[@lib.Instruction],
  params : Array[@lib.ValType],
  info : DirectizeInfo,
) -> Unit {
  match directize_find_removable_arg_suffix(out, params, info) {
    Some(start) => directize_truncate_out(out, start)
    None => {
      ignore(out.pop())
      for _i = 0; _i < params.length(); _i = _i + 1 {
        out.push(@lib.Instruction::drop())
      }
    }
  }
  out.push(@lib.Instruction::unreachable_())
}

///|
fn directize_rewrite_nested_instr(
  instr : @lib.Instruction,
  ctx : DirectizeFuncContext,
) -> (@lib.Instruction, Bool) {
  match instr {
    @lib.Block(block_type, @lib.Expr(body)) => {
      let (next_body, changed) = directize_rewrite_instrs(body, ctx)
      if changed {
        (@lib.Instruction::block(block_type, @lib.Expr::new(next_body)), true)
      } else {
        (instr, false)
      }
    }
    @lib.Loop(block_type, @lib.Expr(body)) => {
      let (next_body, changed) = directize_rewrite_instrs(body, ctx)
      if changed {
        (@lib.Instruction::loop_(block_type, @lib.Expr::new(next_body)), true)
      } else {
        (instr, false)
      }
    }
    @lib.If(block_type, then_body, else_body) => {
      let (next_then, then_changed) = directize_rewrite_instrs(then_body, ctx)
      let (next_else, else_changed) = match else_body {
        Some(body) => {
          let (next, changed) = directize_rewrite_instrs(body, ctx)
          (Some(next), changed)
        }
        None => (None, false)
      }
      if then_changed || else_changed {
        (@lib.Instruction::if_(block_type, next_then, next_else), true)
      } else {
        (instr, false)
      }
    }
    @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
      let (next_body, changed) = directize_rewrite_instrs(body, ctx)
      if changed {
        (
          @lib.Instruction::try_table(
            block_type,
            catches,
            @lib.Expr::new(next_body),
          ),
          true,
        )
      } else {
        (instr, false)
      }
    }
    _ => (instr, false)
  }
}

///|
fn directize_find_arg_start(
  out : Array[@lib.Instruction],
  end : Int,
  params : Array[@lib.ValType],
  info : DirectizeInfo,
) -> Int? {
  for start = end; start >= 0; start = start - 1 {
    let suffix = directize_instr_slice(out, start, end)
    if directize_suffix_produces_params(suffix, params, info) {
      return Some(start)
    }
  }
  None
}

///|
fn directize_condition_suffix_is_i32(
  suffix : Array[@lib.Instruction],
  info : DirectizeInfo,
) -> Bool {
  directize_suffix_produces_params(suffix, [@lib.ValType::i32()], info)
}

///|
fn directize_find_select_rewrite(
  out : Array[@lib.Instruction],
  type_idx : @lib.TypeIdx,
  table_idx : @lib.TableIdx,
  ctx : DirectizeFuncContext,
  is_return : Bool,
) -> DirectizeSelectRewrite? {
  if out.length() < 4 {
    return None
  }
  match out[out.length() - 1] {
    @lib.Select(_) => ()
    _ => return None
  }
  let (params, results) = match directize_call_signature(ctx.info, type_idx) {
    Some(sig) => sig
    None => return None
  }
  let block_type = if is_return {
    Some(@lib.BlockType::void_())
  } else {
    directize_blocktype_for_results(results)
  }
  if block_type is None {
    return None
  }
  let select_idx = out.length() - 1
  for cond_start = select_idx - 1; cond_start >= 2; cond_start = cond_start - 1 {
    match (out[cond_start - 2], out[cond_start - 1]) {
      (@lib.I32Const(@lib.I32(if_true)), @lib.I32Const(@lib.I32(if_false))) => {
        let condition_instrs = directize_instr_slice(
          out, cond_start, select_idx,
        )
        if !directize_condition_suffix_is_i32(condition_instrs, ctx.info) {
          continue
        }
        let true_target = directize_classify_target(
          ctx.info,
          table_idx,
          if_true,
          type_idx,
        )
        let false_target = directize_classify_target(
          ctx.info,
          table_idx,
          if_false,
          type_idx,
        )
        match (true_target, false_target) {
          (DirectizeKnown(then_func), DirectizeKnown(else_func)) =>
            match
              directize_find_arg_start(out, cond_start - 2, params, ctx.info) {
              Some(arg_start) =>
                return Some({
                  arg_start,
                  arg_instrs: directize_instr_slice(
                    out,
                    arg_start,
                    cond_start - 2,
                  ),
                  condition_instrs,
                  params,
                  results,
                  is_return,
                  then_func,
                  else_func,
                })
              None => ()
            }
          _ => ()
        }
      }
      _ => ()
    }
  }
  None
}

///|
fn directize_make_call_body(
  locals : Array[@lib.LocalIdx],
  func_idx : @lib.FuncIdx,
  is_return : Bool,
) -> Array[@lib.Instruction] {
  let body : Array[@lib.Instruction] = []
  for local_idx in locals {
    body.push(@lib.Instruction::local_get(local_idx))
  }
  if is_return {
    body.push(@lib.Instruction::return_call(func_idx))
  } else {
    body.push(@lib.Instruction::call(func_idx))
  }
  body
}

///|
fn directize_apply_select_rewrite(
  out : Array[@lib.Instruction],
  rewrite : DirectizeSelectRewrite,
  ctx : DirectizeFuncContext,
) -> Unit {
  directize_truncate_out(out, rewrite.arg_start)
  for instr in rewrite.arg_instrs {
    out.push(instr)
  }
  let locals : Array[@lib.LocalIdx] = []
  for param in rewrite.params {
    locals.push(directize_allocate_local(ctx, param))
  }
  for idx = locals.length() - 1; idx >= 0; idx = idx - 1 {
    out.push(@lib.Instruction::local_set(locals[idx]))
  }
  for instr in rewrite.condition_instrs {
    out.push(instr)
  }
  let block_type = if rewrite.is_return {
    Some(@lib.BlockType::void_())
  } else {
    directize_blocktype_for_results(rewrite.results)
  }
  match block_type {
    Some(block_type) => {
      out.push(
        @lib.Instruction::if_(
          block_type,
          directize_make_call_body(locals, rewrite.then_func, rewrite.is_return),
          Some(
            directize_make_call_body(
              locals,
              rewrite.else_func,
              rewrite.is_return,
            ),
          ),
        ),
      )
      if rewrite.is_return {
        out.push(@lib.Instruction::unreachable_())
      }
    }
    None => ()
  }
}

///|
fn directize_try_rewrite_call_tail(
  out : Array[@lib.Instruction],
  instr : @lib.Instruction,
  ctx : DirectizeFuncContext,
) -> Bool {
  let info = ctx.info
  if out.length() == 0 {
    return false
  }
  match (out[out.length() - 1], instr) {
    (@lib.I32Const(@lib.I32(offset)), @lib.CallIndirect(type_idx, table_idx)) =>
      match directize_classify_target(info, table_idx, offset, type_idx) {
        DirectizeKnown(func_idx) => {
          ignore(out.pop())
          out.push(@lib.Instruction::call(func_idx))
          true
        }
        DirectizeTrap =>
          match directize_call_param_types(info, type_idx) {
            Some(params) => {
              directize_push_trap_replacement(out, params, info)
              true
            }
            None => false
          }
        DirectizeUnknown => false
      }
    (
      @lib.I32Const(@lib.I32(offset)),
      @lib.ReturnCallIndirect(type_idx, table_idx),
    ) =>
      match directize_classify_target(info, table_idx, offset, type_idx) {
        DirectizeKnown(func_idx) => {
          ignore(out.pop())
          out.push(@lib.Instruction::return_call(func_idx))
          true
        }
        DirectizeTrap =>
          match directize_call_param_types(info, type_idx) {
            Some(params) => {
              directize_push_trap_replacement(out, params, info)
              true
            }
            None => false
          }
        DirectizeUnknown => false
      }
    (@lib.Select(_), @lib.CallIndirect(type_idx, table_idx)) =>
      match
        directize_find_select_rewrite(out, type_idx, table_idx, ctx, false) {
        Some(rewrite) => {
          directize_apply_select_rewrite(out, rewrite, ctx)
          true
        }
        None => false
      }
    (@lib.Select(_), @lib.ReturnCallIndirect(type_idx, table_idx)) =>
      match directize_find_select_rewrite(out, type_idx, table_idx, ctx, true) {
        Some(rewrite) => {
          directize_apply_select_rewrite(out, rewrite, ctx)
          true
        }
        None => false
      }
    _ => false
  }
}

///|
fn directize_rewrite_instrs(
  instrs : Array[@lib.Instruction],
  ctx : DirectizeFuncContext,
) -> (Array[@lib.Instruction], Bool) {
  let out : Array[@lib.Instruction] = []
  let mut changed = false
  for instr in instrs {
    let (current, nested_changed) = directize_rewrite_nested_instr(instr, ctx)
    if nested_changed {
      changed = true
    }
    if directize_try_rewrite_call_tail(out, current, ctx) {
      changed = true
    } else {
      out.push(current)
    }
  }
  (out, changed)
}

///|
fn directize_context_for_func(
  base : DirectizeInfo,
  func_idx : @lib.FuncIdx,
  locals : @lib.Locals,
) -> DirectizeFuncContext {
  match base.env.get_functype_by_funcidx(func_idx) {
    Some(@lib.FuncType(params, results)) =>
      match @lib.FunctionLocals::from_local_decls(params, locals) {
        Ok(function_locals) => {
          let all_locals = function_locals.all_locals()
          let env = base.env
            .with_locals(all_locals)
            .with_return_type(Some(results))
          {
            info: { ..base, env, },
            base_local_count: all_locals.length(),
            extra_locals: [],
          }
        }
        Err(_) =>
          { info: base, base_local_count: locals.length(), extra_locals: [] }
      }
    None => { info: base, base_local_count: locals.length(), extra_locals: [] }
  }
}

///|
fn directize_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  let info = directize_build_info(mod_)
  let imported_funcs = directize_imported_func_count(mod_)
  let rewritten : Array[@lib.Func] = []
  let mut changed = false
  for code_idx = 0; code_idx < funcs.length(); code_idx = code_idx + 1 {
    let func = funcs[code_idx]
    let @lib.Func(locals, @lib.Expr(body)) = func
    let ctx = directize_context_for_func(
      info,
      @lib.FuncIdx::new((imported_funcs + code_idx).reinterpret_as_uint()),
      locals,
    )
    let (next_body, func_changed) = directize_rewrite_instrs(body, ctx)
    if func_changed {
      changed = true
      let next_locals = locals.copy()
      next_locals.append_types(ctx.extra_locals)
      rewritten.push(@lib.Func::new(next_locals, @lib.Expr::new(next_body)))
    } else {
      rewritten.push(func)
    }
  }
  if changed {
    mod_.with_code_sec(@lib.CodeSec::new(rewritten))
  } else {
    mod_
  }
}
