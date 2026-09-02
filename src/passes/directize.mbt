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
  locals : @lib.Locals
  extra_locals : Array[@lib.ValType]
}

///|
priv struct DirectizeSelectRewrite {
  arg_start : Int
  arg_instrs : Array[@lib.Instruction]
  condition_instrs : Array[@lib.Instruction]
  params : Array[@lib.ValType]
  results : Array[@lib.ValType]
  has_stack_prefix : Bool
  is_return : Bool
  then_target : DirectizeTarget
  else_target : DirectizeTarget
}

///|
priv struct DirectizeProducerValue {
  ty : @lib.ValType
  start : Int
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
    tables[table_slot] = { ..tables[table_slot], can_optimize: false, }
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
  ctx.locals.push(vt)
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
    info.block_signatures.push({ results, type_idx, })
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
fn directize_stack_suffix(
  stack : Array[@lib.ValType],
  count : Int,
) -> Array[@lib.ValType] {
  let suffix : Array[@lib.ValType] = Array::new(capacity=count)
  let start = stack.length() - count
  for idx = start; idx < stack.length(); idx = idx + 1 {
    suffix.push(stack[idx])
  }
  suffix
}

///|
fn directize_candidate_after_matches(
  before_stack : Array[@lib.ValType],
  after : @validate.TcState,
  pop_count : Int,
  candidate_after : @validate.TcState,
) -> Bool {
  if candidate_after.reachable != after.reachable ||
    candidate_after.escape != after.escape {
    return false
  }
  let prefix_len = before_stack.length() - pop_count
  if prefix_len + candidate_after.stack.length() != after.stack.length() {
    return false
  }
  for idx = 0; idx < prefix_len; idx = idx + 1 {
    if before_stack[idx] != after.stack[idx] {
      return false
    }
  }
  for idx = 0; idx < candidate_after.stack.length(); idx = idx + 1 {
    if candidate_after.stack[idx] != after.stack[prefix_len + idx] {
      return false
    }
  }
  true
}

///|
fn directize_fast_pop_count(instr : @lib.Instruction) -> Int? {
  match instr {
    @lib.Nop
    | @lib.I32Const(_)
    | @lib.I64Const(_)
    | @lib.F32Const(_)
    | @lib.F64Const(_)
    | @lib.StringConst(_)
    | @lib.LocalGet(_)
    | @lib.GlobalGet(_)
    | @lib.MemorySize(_)
    | @lib.TableSize(_)
    | @lib.RefNull(_)
    | @lib.RefFunc(_)
    | @lib.DataDrop(_)
    | @lib.ElemDrop(_) => Some(0)
    @lib.LocalSet(_)
    | @lib.LocalTee(_)
    | @lib.GlobalSet(_)
    | @lib.TableGet(_)
    | @lib.MemoryGrow(_)
    | @lib.Drop
    | @lib.RefIsNull
    | @lib.I32Eqz
    | @lib.I64Eqz
    | @lib.I32Clz
    | @lib.I32Ctz
    | @lib.I32Popcnt
    | @lib.I64Clz
    | @lib.I64Ctz
    | @lib.I64Popcnt
    | @lib.F32Abs
    | @lib.F32Neg
    | @lib.F32Ceil
    | @lib.F32Floor
    | @lib.F32Trunc
    | @lib.F32Nearest
    | @lib.F32Sqrt
    | @lib.F64Abs
    | @lib.F64Neg
    | @lib.F64Ceil
    | @lib.F64Floor
    | @lib.F64Trunc
    | @lib.F64Nearest
    | @lib.F64Sqrt
    | @lib.I32WrapI64
    | @lib.I32TruncF32S
    | @lib.I32TruncF32U
    | @lib.I32TruncF64S
    | @lib.I32TruncF64U
    | @lib.I64ExtendI32S
    | @lib.I64ExtendI32U
    | @lib.I64TruncF32S
    | @lib.I64TruncF32U
    | @lib.I64TruncF64S
    | @lib.I64TruncF64U
    | @lib.F32ConvertI32S
    | @lib.F32ConvertI32U
    | @lib.F32ConvertI64S
    | @lib.F32ConvertI64U
    | @lib.F32DemoteF64
    | @lib.F64ConvertI32S
    | @lib.F64ConvertI32U
    | @lib.F64ConvertI64S
    | @lib.F64ConvertI64U
    | @lib.F64PromoteF32
    | @lib.I32ReinterpretF32
    | @lib.I64ReinterpretF64
    | @lib.F32ReinterpretI32
    | @lib.F64ReinterpretI64
    | @lib.I32Extend8S
    | @lib.I32Extend16S
    | @lib.I64Extend8S
    | @lib.I64Extend16S
    | @lib.I64Extend32S
    | @lib.I32TruncSatF32S
    | @lib.I32TruncSatF32U
    | @lib.I32TruncSatF64S
    | @lib.I32TruncSatF64U
    | @lib.I64TruncSatF32S
    | @lib.I64TruncSatF32U
    | @lib.I64TruncSatF64S
    | @lib.I64TruncSatF64U => Some(1)
    @lib.TableSet(_)
    | @lib.TableGrow(_)
    | @lib.I32Eq
    | @lib.I32Ne
    | @lib.I32LtS
    | @lib.I32LtU
    | @lib.I32GtS
    | @lib.I32GtU
    | @lib.I32LeS
    | @lib.I32LeU
    | @lib.I32GeS
    | @lib.I32GeU
    | @lib.I64Eq
    | @lib.I64Ne
    | @lib.I64LtS
    | @lib.I64LtU
    | @lib.I64GtS
    | @lib.I64GtU
    | @lib.I64LeS
    | @lib.I64LeU
    | @lib.I64GeS
    | @lib.I64GeU
    | @lib.F32Eq
    | @lib.F32Ne
    | @lib.F32Lt
    | @lib.F32Gt
    | @lib.F32Le
    | @lib.F32Ge
    | @lib.F64Eq
    | @lib.F64Ne
    | @lib.F64Lt
    | @lib.F64Gt
    | @lib.F64Le
    | @lib.F64Ge
    | @lib.I32Add
    | @lib.I32Sub
    | @lib.I32Mul
    | @lib.I32DivS
    | @lib.I32DivU
    | @lib.I32RemS
    | @lib.I32RemU
    | @lib.I32And
    | @lib.I32Or
    | @lib.I32Xor
    | @lib.I32Shl
    | @lib.I32ShrS
    | @lib.I32ShrU
    | @lib.I32Rotl
    | @lib.I32Rotr
    | @lib.I64Add
    | @lib.I64Sub
    | @lib.I64Mul
    | @lib.I64DivS
    | @lib.I64DivU
    | @lib.I64RemS
    | @lib.I64RemU
    | @lib.I64And
    | @lib.I64Or
    | @lib.I64Xor
    | @lib.I64Shl
    | @lib.I64ShrS
    | @lib.I64ShrU
    | @lib.I64Rotl
    | @lib.I64Rotr
    | @lib.F32Add
    | @lib.F32Sub
    | @lib.F32Mul
    | @lib.F32Div
    | @lib.F32Min
    | @lib.F32Max
    | @lib.F32Copysign
    | @lib.F64Add
    | @lib.F64Sub
    | @lib.F64Mul
    | @lib.F64Div
    | @lib.F64Min
    | @lib.F64Max
    | @lib.F64Copysign => Some(2)
    @lib.TableFill(_)
    | @lib.TableCopy(_, _)
    | @lib.TableInit(_, _)
    | @lib.MemoryCopy(_, _)
    | @lib.MemoryFill(_)
    | @lib.MemoryInit(_, _) => Some(3)
    _ => None
  }
}

///|
fn directize_instr_pop_count(
  instr : @lib.Instruction,
  before : @validate.TcState,
  after : @validate.TcState,
) -> Int? {
  match directize_fast_pop_count(instr) {
    Some(count) if count <= before.stack.length() => return Some(count)
    _ => ()
  }
  for count = 0; count <= before.stack.length(); count = count + 1 {
    let candidate = @validate.tc_state_with_owned_stack(
      before,
      directize_stack_suffix(before.stack, count),
    )
    match @validate.Typecheck::typecheck(instr, candidate) {
      Ok(candidate_after) =>
        if directize_candidate_after_matches(
            before.stack,
            after,
            count,
            candidate_after,
          ) {
          return Some(count)
        }
      Err(_) => ()
    }
  }
  None
}

///|
fn directize_scan_producer_instr(
  instr : @lib.Instruction,
  instr_idx : Int,
  state : @validate.TcState,
  values : Array[DirectizeProducerValue],
) -> @validate.TcState? {
  let typecheck_state = @validate.tc_state_with_stack(state, state.stack)
  let after = match @validate.Typecheck::typecheck(instr, typecheck_state) {
    Ok(next) => next
    Err(_) => return None
  }
  if !after.reachable || after.escape != @validate.tc_escape_none() {
    return None
  }
  let pop_count = match directize_instr_pop_count(instr, state, after) {
    Some(count) => count
    None => return None
  }
  if values.length() != state.stack.length() || pop_count > values.length() {
    return None
  }
  let prefix_len = values.length() - pop_count
  let mut producer_start = instr_idx
  for idx = prefix_len; idx < values.length(); idx = idx + 1 {
    if values[idx].start < producer_start {
      producer_start = values[idx].start
    }
  }
  while values.length() > prefix_len {
    ignore(values.pop())
  }
  for idx = prefix_len; idx < after.stack.length(); idx = idx + 1 {
    values.push({ ty: after.stack[idx], start: producer_start, })
  }
  Some(after)
}

///|
fn directize_producer_stack_before(
  out : Array[@lib.Instruction],
  start : Int,
  end : Int,
  info : DirectizeInfo,
) -> Array[DirectizeProducerValue] {
  let values : Array[DirectizeProducerValue] = []
  let mut state = @validate.make_state(info.env, [])
  for idx = start; idx < end; idx = idx + 1 {
    match directize_scan_producer_instr(out[idx], idx, state, values) {
      Some(next) => state = next
      None => {
        values.clear()
        state = @validate.make_state(info.env, [])
        match directize_scan_producer_instr(out[idx], idx, state, values) {
          Some(next) => state = next
          None => {
            values.clear()
            state = @validate.make_state(info.env, [])
          }
        }
      }
    }
  }
  values
}

///|
fn directize_find_select_rewrite(
  out : Array[@lib.Instruction],
  scan_start : Int,
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
  let values = directize_producer_stack_before(
    out,
    scan_start,
    select_idx,
    ctx.info,
  )
  let required = params.length() + 3
  if values.length() < required {
    return None
  }
  let condition_slot = values.length() - 1
  let false_slot = condition_slot - 1
  let true_slot = condition_slot - 2
  let arg_slot = true_slot - params.length()
  if !directize_stack_matches(
      [values[condition_slot].ty],
      [@lib.ValType::i32()],
      ctx.info.env,
    ) {
    return None
  }
  let cond_start = values[condition_slot].start
  if cond_start < scan_start + 2 ||
    values[true_slot].start != cond_start - 2 ||
    values[false_slot].start != cond_start - 1 {
    return None
  }
  let if_true = match directize_target_const(out[cond_start - 2]) {
    Some(value) => value
    None => return None
  }
  let if_false = match directize_target_const(out[cond_start - 1]) {
    Some(value) => value
    None => return None
  }
  let actual_params : Array[@lib.ValType] = []
  let mut arg_start = cond_start - 2
  for idx = 0; idx < params.length(); idx = idx + 1 {
    let value = values[arg_slot + idx]
    actual_params.push(value.ty)
    if value.start < arg_start {
      arg_start = value.start
    }
  }
  if !directize_stack_matches(actual_params, params, ctx.info.env) {
    return None
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
    return None
  }
  let arg_instrs = directize_instr_slice(out, arg_start, cond_start - 2)
  let condition_instrs = directize_instr_slice(out, cond_start, select_idx)
  // Validate only the two materialized matches. Discovery itself performs one
  // stack-effect scan and does not allocate or typecheck every candidate suffix.
  if !directize_suffix_produces_params(arg_instrs, params, ctx.info) ||
    !directize_suffix_produces_params(
      condition_instrs,
      [@lib.ValType::i32()],
      ctx.info,
    ) {
    return None
  }
  Some({
    arg_start,
    arg_instrs,
    condition_instrs,
    params,
    results,
    has_stack_prefix: values.length() > required,
    is_return,
    then_target: true_target,
    else_target: false_target,
  })
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
fn directize_call_input_producer(
  out : Array[@lib.Instruction],
  scan_start : Int,
  type_idx : @lib.TypeIdx,
  info : DirectizeInfo,
) -> (Int, Int, Bool)? {
  let (params, results) = match directize_call_signature(info, type_idx) {
    Some(signature) => signature
    None => return None
  }
  let values = directize_producer_stack_before(
    out,
    scan_start,
    out.length(),
    info,
  )
  let required = params.length() + 1
  if values.length() < required {
    return None
  }
  let mut producer_start = out.length()
  for idx = values.length() - required; idx < values.length(); idx = idx + 1 {
    if values[idx].start < producer_start {
      producer_start = values[idx].start
    }
  }
  Some((producer_start, results.length(), values.length() > required))
}

///|
fn directize_try_rewrite_call_tail(
  out : Array[@lib.Instruction],
  scan_start : Int,
  instr : @lib.Instruction,
  ctx : DirectizeFuncContext,
) -> (Int, Bool)? {
  let info = ctx.info
  if out.length() == 0 {
    return None
  }
  match instr {
    @lib.CallIndirect(type_idx, table_idx)
    | @lib.ReturnCallIndirect(type_idx, table_idx) => {
      let is_return = instr is @lib.ReturnCallIndirect(_, _)
      match directize_target_const(out[out.length() - 1]) {
        Some(offset) => {
          let input_producer = directize_call_input_producer(
            out, scan_start, type_idx, info,
          )
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
              match input_producer {
                Some((producer_start, result_count, has_stack_prefix)) if !is_return &&
                  result_count > 0 =>
                  Some((producer_start, result_count == 1 && !has_stack_prefix))
                _ => Some((out.length(), false))
              }
            }
            DirectizeTrap =>
              match directize_call_param_types(info, type_idx) {
                Some(params) => {
                  directize_push_trap_replacement(out, params, info)
                  Some((out.length(), false))
                }
                None => None
              }
            DirectizeUnknown => None
          }
        }
        None =>
          match out[out.length() - 1] {
            @lib.Select(_) =>
              match
                directize_find_select_rewrite(
                  out, scan_start, type_idx, table_idx, ctx, is_return,
                ) {
                Some(rewrite) => {
                  let next_scan_start = if !is_return &&
                    rewrite.results.length() > 0 {
                    rewrite.arg_start
                  } else {
                    out.length()
                  }
                  directize_apply_select_rewrite(out, rewrite, ctx)
                  Some(
                    (
                      next_scan_start,
                      rewrite.results.length() == 1 && !rewrite.has_stack_prefix,
                    ),
                  )
                }
                None => None
              }
            _ => None
          }
      }
    }
    _ => None
  }
}

///|
fn directize_table_can_optimize(
  info : DirectizeInfo,
  table_idx : @lib.TableIdx,
) -> Bool {
  let slot = directize_table_slot(table_idx)
  slot >= 0 && slot < info.tables.length() && info.tables[slot].can_optimize
}

///|
fn directize_instr_has_nested_rewrite_candidate(
  instr : @lib.Instruction,
  info : DirectizeInfo,
) -> Bool {
  match instr {
    @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
      directize_instrs_have_rewrite_candidate(body, info)
    @lib.If(_, then_body, else_body) => {
      if directize_instrs_have_rewrite_candidate(then_body, info) {
        return true
      }
      match else_body {
        Some(body) => directize_instrs_have_rewrite_candidate(body, info)
        None => false
      }
    }
    @lib.Try(_, @lib.Expr(body), catches, _) => {
      if directize_instrs_have_rewrite_candidate(body, info) {
        return true
      }
      for catch_ in catches {
        let catch_body = match catch_ {
          @lib.LegacyCatch(_, @lib.Expr(catch_body))
          | @lib.LegacyCatchAll(@lib.Expr(catch_body)) => catch_body
        }
        if directize_instrs_have_rewrite_candidate(catch_body, info) {
          return true
        }
      }
      false
    }
    @lib.TryTable(_, _, @lib.Expr(body)) =>
      directize_instrs_have_rewrite_candidate(body, info)
    _ => false
  }
}

///|
fn directize_instrs_have_rewrite_candidate(
  instrs : Array[@lib.Instruction],
  info : DirectizeInfo,
) -> Bool {
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    let instr = instrs[idx]
    if directize_instr_has_nested_rewrite_candidate(instr, info) {
      return true
    }
    let table_idx = match instr {
      @lib.CallIndirect(_, table_idx) | @lib.ReturnCallIndirect(_, table_idx) =>
        table_idx
      _ => continue
    }
    if idx == 0 || !directize_table_can_optimize(info, table_idx) {
      continue
    }
    match instrs[idx - 1] {
      @lib.I32Const(_) | @lib.I64Const(_) | @lib.Select(_) => return true
      _ => ()
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
  let mut scan_start = 0
  let mut reset_scan_after_drop = false
  for instr in instrs {
    let (current, nested_changed) = directize_rewrite_nested_instr(instr, ctx)
    if nested_changed {
      changed = true
    }
    if reset_scan_after_drop {
      reset_scan_after_drop = false
      if current is @lib.Drop {
        out.push(current)
        scan_start = out.length()
        continue
      }
    }
    match directize_try_rewrite_call_tail(out, scan_start, current, ctx) {
      Some((next_scan_start, reset_after_drop)) => {
        changed = true
        scan_start = next_scan_start
        reset_scan_after_drop = reset_after_drop
      }
      None => {
        let input_producer = match current {
          @lib.CallIndirect(type_idx, _) =>
            directize_call_input_producer(out, scan_start, type_idx, ctx.info)
          _ => None
        }
        out.push(current)
        match input_producer {
          Some((producer_start, result_count, has_stack_prefix)) if result_count >
            0 => {
            scan_start = producer_start
            reset_scan_after_drop = result_count == 1 && !has_stack_prefix
          }
          Some((_, _, _)) => scan_start = out.length()
          None =>
            if current is @lib.ReturnCallIndirect(_, _) {
              scan_start = out.length()
            }
        }
      }
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
            locals: all_locals,
            extra_locals: [],
          }
        }
        Err(_) =>
          {
            info: base,
            base_local_count: locals.length(),
            locals: locals.copy(),
            extra_locals: [],
          }
      }
    None =>
      {
        info: base,
        base_local_count: locals.length(),
        locals: locals.copy(),
        extra_locals: [],
      }
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
/// Shared final lowering for an independently proven exact `call_ref` target.
/// The explicit reference operand is always evaluated and dropped before the
/// direct call, preserving its effects, traps, exceptions, and evaluation order.
fn directize_exact_ref_call_replacement(
  env : @validate.Env,
  instr : @lib.Instruction,
  target : @lib.FuncIdx,
) -> Array[@lib.Instruction]? {
  let call_type = match instr {
    @lib.CallRef(type_) | @lib.ReturnCallRef(type_) => type_
    _ => return None
  }
  let target_type = match env.get_functypeidx_by_funcidx(target) {
    Some(type_) => type_
    None => return None
  }
  if !@validate.Match::matches(
      @lib.ExternType::func(target_type),
      @lib.ExternType::func(call_type),
      env,
    ) {
    return None
  }
  Some([
    @lib.Instruction::drop(),
    match instr {
      @lib.ReturnCallRef(_) => @lib.Instruction::return_call(target)
      _ => @lib.Instruction::call(target)
    },
  ])
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
    if !directize_instrs_have_rewrite_candidate(body, info) {
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
