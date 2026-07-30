///|
priv enum DirectizeTarget {
  DirectizeKnown(@lib.FuncIdx)
  DirectizeTrap
  DirectizeUnknown
}

///|
priv enum DirectizeTableEntry {
  DirectizeEntryFunc(@lib.FuncIdx)
  DirectizeEntryNull
}

///|
priv enum DirectizeTableDefault {
  DirectizeDefaultFunc(@lib.FuncIdx)
  DirectizeDefaultNull
  DirectizeDefaultUnknown
}

///|
priv struct DirectizeTableInfo {
  can_optimize : Bool
  has_grow : Bool
  initial_size : UInt64
  entries : @hashmap.HashMap[UInt64, DirectizeTableEntry]
  default_entry : DirectizeTableDefault
}

///|
priv struct DirectizeBlockSignature {
  results : Array[@lib.ValType]
  type_idx : @lib.TypeIdx
}

///|
priv struct DirectizeInfo {
  env : @validate.Env
  func_types : Array[@lib.TypeIdx]
  tables : Array[DirectizeTableInfo]
  base_type_count : Int
  block_signatures : Array[DirectizeBlockSignature]
  extra_block_types : Array[@lib.RecType]
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
  then_target : DirectizeTarget
  else_target : DirectizeTarget
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
fn directize_const_table_offset(expr : @lib.Expr) -> UInt64? {
  match expr {
    @lib.Expr([@lib.I32Const(@lib.I32(value))]) =>
      Some(value.reinterpret_as_uint().to_uint64())
    @lib.Expr([@lib.I64Const(@lib.I64(value))]) =>
      Some(value.reinterpret_as_uint64())
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
fn directize_table_initial_size(table_type : @lib.TableType) -> UInt64 {
  match table_type {
    @lib.TableType(_, @lib.I32Limits(initial, _)) => initial.to_uint64()
    @lib.TableType(_, @lib.I64Limits(initial, _)) => initial
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
fn directize_mark_runtime_table_instr(
  mutated : Array[Bool],
  grown : Array[Bool],
  instr : @lib.Instruction,
) -> Unit {
  match instr {
    @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
      for nested in body {
        directize_mark_runtime_table_instr(mutated, grown, nested)
      }
    @lib.If(_, then_body, else_body) => {
      for nested in then_body {
        directize_mark_runtime_table_instr(mutated, grown, nested)
      }
      match else_body {
        Some(body) =>
          for nested in body {
            directize_mark_runtime_table_instr(mutated, grown, nested)
          }
        None => ()
      }
    }
    @lib.Try(_, @lib.Expr(body), catches, _) => {
      for nested in body {
        directize_mark_runtime_table_instr(mutated, grown, nested)
      }
      for catch_ in catches {
        match catch_ {
          @lib.LegacyCatch(_, @lib.Expr(catch_body))
          | @lib.LegacyCatchAll(@lib.Expr(catch_body)) =>
            for nested in catch_body {
              directize_mark_runtime_table_instr(mutated, grown, nested)
            }
        }
      }
    }
    @lib.TryTable(_, _, @lib.Expr(body)) =>
      for nested in body {
        directize_mark_runtime_table_instr(mutated, grown, nested)
      }
    @lib.TableGrow(table_idx) => directize_mark_table(grown, table_idx, true)
    @lib.TableSet(table_idx)
    | @lib.TableFill(table_idx)
    | @lib.TableInit(_, table_idx) =>
      directize_mark_table(mutated, table_idx, true)
    @lib.TableCopy(dst, _) => directize_mark_table(mutated, dst, true)
    _ => ()
  }
}

///|
fn directize_runtime_table_facts(
  mod_ : @lib.Module,
  table_count : Int,
) -> (Array[Bool], Array[Bool]) {
  let mutated = Array::make(table_count, false)
  let grown = Array::make(table_count, false)
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(_, @lib.Expr(instrs)) = func
        for instr in instrs {
          directize_mark_runtime_table_instr(mutated, grown, instr)
        }
      }
    None => ()
  }
  (mutated, grown)
}

///|
fn directize_base_table_infos(mod_ : @lib.Module) -> Array[DirectizeTableInfo] {
  let table_types = directize_table_types(mod_)
  let imported_tables = directize_imported_table_count(mod_)
  let (mutated, grown) = directize_runtime_table_facts(
    mod_,
    table_types.length(),
  )
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
    infos.push({
      can_optimize: idx >= imported_tables && !mutated[idx] && !exported[idx],
      has_grow: grown[idx],
      initial_size: directize_table_initial_size(table_types[idx]),
      entries: @hashmap.new(),
      default_entry: DirectizeDefaultNull,
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
  offset : UInt64,
  value : DirectizeTableEntry,
) -> Unit {
  if table_slot < 0 || table_slot >= tables.length() {
    return
  }
  let info = tables[table_slot]
  if !info.can_optimize || offset >= info.initial_size {
    directize_disable_table(tables, table_slot)
    return
  }
  info.entries.set(offset, value)
}

///|
fn directize_record_elem_funcs(
  tables : Array[DirectizeTableInfo],
  table_slot : Int,
  base : UInt64,
  funcs : Array[@lib.FuncIdx],
) -> Unit {
  let mut rel = 0UL
  for func_idx in funcs {
    if base > 0xFFFF_FFFF_FFFF_FFFFUL - rel {
      directize_disable_table(tables, table_slot)
      return
    }
    directize_write_table_entry(
      tables,
      table_slot,
      base + rel,
      DirectizeEntryFunc(func_idx),
    )
    rel += 1UL
  }
}

///|
fn directize_record_elem_exprs(
  tables : Array[DirectizeTableInfo],
  table_slot : Int,
  base : UInt64,
  exprs : Array[@lib.Expr],
) -> Unit {
  let mut rel = 0UL
  for expr in exprs {
    if base > 0xFFFF_FFFF_FFFF_FFFFUL - rel {
      directize_disable_table(tables, table_slot)
      return
    }
    match directize_func_from_elem_expr(expr) {
      Some(Some(func_idx)) =>
        directize_write_table_entry(
          tables,
          table_slot,
          base + rel,
          DirectizeEntryFunc(func_idx),
        )
      Some(None) =>
        directize_write_table_entry(
          tables,
          table_slot,
          base + rel,
          DirectizeEntryNull,
        )
      None => directize_disable_table(tables, table_slot)
    }
    rel += 1UL
  }
}

///|
fn directize_apply_table_initializers(
  mod_ : @lib.Module,
  tables : Array[DirectizeTableInfo],
) -> Unit {
  let imported_tables = directize_imported_table_count(mod_)
  match mod_.table_sec {
    Some(@lib.TableSec(defs)) => {
      let mut def_idx = 0
      for table in defs {
        let slot = imported_tables + def_idx
        if slot >= 0 && slot < tables.length() && tables[slot].can_optimize {
          let @lib.Table(_, init) = table
          tables[slot] = {
            ..tables[slot],
            default_entry: match init {
              Some(@lib.Expr([@lib.RefFunc(func_idx)])) =>
                DirectizeDefaultFunc(func_idx)
              None => DirectizeDefaultNull
              Some(_) => DirectizeDefaultUnknown
            },
          }
        }
        def_idx += 1
      }
    }
    None => ()
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
            match directize_const_table_offset(offset_expr) {
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
fn directize_type_count(mod_ : @lib.Module) -> Int {
  match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) => {
      let mut count = 0
      for rec_type in rec_types {
        count += match rec_type {
          @lib.SingleRecType(_) => 1
          @lib.GroupRecType(subtypes) => subtypes.length()
        }
      }
      count
    }
    None => 0
  }
}

///|
fn directize_block_signatures(
  mod_ : @lib.Module,
) -> Array[DirectizeBlockSignature] {
  let signatures : Array[DirectizeBlockSignature] = []
  match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) => {
      let mut flat_idx = 0
      for rec_type in rec_types {
        let subtypes = match rec_type {
          @lib.SingleRecType(subtype) => [subtype]
          @lib.GroupRecType(group) => group
        }
        for subtype in subtypes {
          match subtype.get_comptype() {
            @lib.FuncCompType(params, results) if params.length() == 0 =>
              signatures.push({
                results,
                type_idx: @lib.TypeIdx::new(flat_idx.reinterpret_as_uint()),
              })
            _ => ()
          }
          flat_idx += 1
        }
      }
    }
    None => ()
  }
  signatures
}

///|
fn directize_build_info(mod_ : @lib.Module) -> DirectizeInfo {
  let tables = directize_base_table_infos(mod_)
  directize_apply_table_initializers(mod_, tables)
  directize_populate_table_infos(mod_, tables)
  {
    env: @validate.Env::new().with_module(mod_),
    func_types: directize_func_types(mod_),
    tables,
    base_type_count: directize_type_count(mod_),
    block_signatures: directize_block_signatures(mod_),
    extra_block_types: [],
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
fn directize_classify_func(
  info : DirectizeInfo,
  func_idx : @lib.FuncIdx,
  call_type : @lib.TypeIdx,
) -> DirectizeTarget {
  if directize_func_type_matches(info, func_idx, call_type) {
    DirectizeKnown(func_idx)
  } else {
    DirectizeTrap
  }
}

///|
fn directize_classify_target(
  info : DirectizeInfo,
  table_idx : @lib.TableIdx,
  offset : UInt64,
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
  match table_info.entries.get(offset) {
    Some(DirectizeEntryFunc(func_idx)) =>
      return directize_classify_func(info, func_idx, call_type)
    Some(DirectizeEntryNull) => return DirectizeTrap
    None => ()
  }
  if offset >= table_info.initial_size {
    return if table_info.has_grow { DirectizeUnknown } else { DirectizeTrap }
  }
  match table_info.default_entry {
    DirectizeDefaultFunc(func_idx) =>
      directize_classify_func(info, func_idx, call_type)
    DirectizeDefaultNull => DirectizeTrap
    DirectizeDefaultUnknown => DirectizeUnknown
  }
}

///|
fn directize_target_const(instr : @lib.Instruction) -> UInt64? {
  match instr {
    @lib.I32Const(@lib.I32(value)) =>
      Some(value.reinterpret_as_uint().to_uint64())
    @lib.I64Const(@lib.I64(value)) => Some(value.reinterpret_as_uint64())
    _ => None
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
  info : DirectizeInfo,
) -> @lib.BlockType {
  if results.length() == 0 {
    @lib.BlockType::void_()
  } else if results.length() == 1 {
    @lib.BlockType::val_type(results[0])
  } else {
    for signature in info.block_signatures {
      if signature.results == results {
        return @lib.BlockType::type_idx(signature.type_idx)
      }
    }
    let type_idx = @lib.TypeIdx::new(
      (info.base_type_count + info.extra_block_types.length()).reinterpret_as_uint(),
    )
    info.extra_block_types.push(
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([], results)),
      ),
    )
    info.block_signatures.push({ results, type_idx })
    @lib.BlockType::type_idx(type_idx)
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
    @lib.Try(block_type, @lib.Expr(body), catches, delegate) => {
      let (next_body, body_changed) = directize_rewrite_instrs(body, ctx)
      let next_catches : Array[@lib.LegacyCatch] = []
      let mut catches_changed = false
      for catch_ in catches {
        match catch_ {
          @lib.LegacyCatch(tag_idx, @lib.Expr(catch_body)) => {
            let (next_catch, changed) = directize_rewrite_instrs(
              catch_body, ctx,
            )
            if changed {
              catches_changed = true
            }
            next_catches.push(
              @lib.LegacyCatch::tagged(tag_idx, @lib.Expr::new(next_catch)),
            )
          }
          @lib.LegacyCatchAll(@lib.Expr(catch_body)) => {
            let (next_catch, changed) = directize_rewrite_instrs(
              catch_body, ctx,
            )
            if changed {
              catches_changed = true
            }
            next_catches.push(@lib.LegacyCatch::all(@lib.Expr::new(next_catch)))
          }
        }
      }
      if body_changed || catches_changed {
        (
          @lib.Instruction::try_(
            block_type,
            @lib.Expr::new(next_body),
            next_catches,
            delegate~,
          ),
          true,
        )
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
  let select_idx = out.length() - 1
  for cond_start = select_idx - 1; cond_start >= 2; cond_start = cond_start - 1 {
    let if_true = match directize_target_const(out[cond_start - 2]) {
      Some(value) => value
      None => continue
    }
    let if_false = match directize_target_const(out[cond_start - 1]) {
      Some(value) => value
      None => continue
    }
    let condition_instrs = directize_instr_slice(out, cond_start, select_idx)
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
    if true_target is DirectizeUnknown || false_target is DirectizeUnknown {
      continue
    }
    match directize_find_arg_start(out, cond_start - 2, params, ctx.info) {
      Some(arg_start) =>
        return Some({
          arg_start,
          arg_instrs: directize_instr_slice(out, arg_start, cond_start - 2),
          condition_instrs,
          params,
          results,
          is_return,
          then_target: true_target,
          else_target: false_target,
        })
      None => ()
    }
  }
  None
}

///|
fn directize_make_call_body(
  locals : Array[@lib.LocalIdx],
  target : DirectizeTarget,
  is_return : Bool,
) -> Array[@lib.Instruction] {
  match target {
    DirectizeKnown(func_idx) => {
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
    DirectizeTrap => [@lib.Instruction::unreachable_()]
    DirectizeUnknown => []
  }
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
    @lib.BlockType::void_()
  } else {
    directize_blocktype_for_results(rewrite.results, ctx.info)
  }
  out.push(
    @lib.Instruction::if_(
      block_type,
      directize_make_call_body(locals, rewrite.then_target, rewrite.is_return),
      Some(
        directize_make_call_body(locals, rewrite.else_target, rewrite.is_return),
      ),
    ),
  )
  if rewrite.is_return {
    out.push(@lib.Instruction::unreachable_())
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
  match instr {
    @lib.CallIndirect(type_idx, table_idx)
    | @lib.ReturnCallIndirect(type_idx, table_idx) => {
      let is_return = instr is @lib.ReturnCallIndirect(_, _)
      match directize_target_const(out[out.length() - 1]) {
        Some(offset) =>
          match directize_classify_target(info, table_idx, offset, type_idx) {
            DirectizeKnown(func_idx) => {
              ignore(out.pop())
              out.push(
                if is_return {
                  @lib.Instruction::return_call(func_idx)
                } else {
                  @lib.Instruction::call(func_idx)
                },
              )
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
        None =>
          match out[out.length() - 1] {
            @lib.Select(_) =>
              match
                directize_find_select_rewrite(
                  out, type_idx, table_idx, ctx, is_return,
                ) {
                Some(rewrite) => {
                  directize_apply_select_rewrite(out, rewrite, ctx)
                  true
                }
                None => false
              }
            _ => false
          }
      }
    }
    _ => false
  }
}

///|
fn directize_instr_has_indirect_call(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.CallIndirect(_, _) | @lib.ReturnCallIndirect(_, _) => true
    @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
      directize_instrs_have_indirect_call(body)
    @lib.If(_, then_body, else_body) => {
      if directize_instrs_have_indirect_call(then_body) {
        return true
      }
      match else_body {
        Some(body) => directize_instrs_have_indirect_call(body)
        None => false
      }
    }
    @lib.Try(_, @lib.Expr(body), catches, _) => {
      if directize_instrs_have_indirect_call(body) {
        return true
      }
      for catch_ in catches {
        let catch_body = match catch_ {
          @lib.LegacyCatch(_, @lib.Expr(catch_body))
          | @lib.LegacyCatchAll(@lib.Expr(catch_body)) => catch_body
        }
        if directize_instrs_have_indirect_call(catch_body) {
          return true
        }
      }
      false
    }
    @lib.TryTable(_, _, @lib.Expr(body)) =>
      directize_instrs_have_indirect_call(body)
    _ => false
  }
}

///|
fn directize_instrs_have_indirect_call(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    if directize_instr_has_indirect_call(instr) {
      return true
    }
  }
  false
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
fn directize_append_block_types(
  mod_ : @lib.Module,
  extra : Array[@lib.RecType],
) -> @lib.Module {
  if extra.length() == 0 {
    return mod_
  }
  let rec_types = match mod_.type_sec {
    Some(@lib.TypeSec(existing)) => existing.copy()
    None => []
  }
  for rec_type in extra {
    rec_types.push(rec_type)
  }
  mod_.with_type_sec(@lib.TypeSec::new(rec_types))
}

///|
fn directize_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  let info = directize_build_info(mod_)
  let mut has_optimizable_table = false
  for table in info.tables {
    if table.can_optimize {
      has_optimizable_table = true
      break
    }
  }
  if !has_optimizable_table {
    return mod_
  }
  let imported_funcs = directize_imported_func_count(mod_)
  let rewritten : Array[@lib.Func] = []
  let mut changed = false
  for code_idx = 0; code_idx < funcs.length(); code_idx = code_idx + 1 {
    let func = funcs[code_idx]
    let @lib.Func(locals, @lib.Expr(body)) = func
    if !directize_instrs_have_indirect_call(body) {
      rewritten.push(func)
      continue
    }
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
    directize_append_block_types(
      mod_.with_code_sec(@lib.CodeSec::new(rewritten)),
      info.extra_block_types,
    )
  } else {
    mod_
  }
}
