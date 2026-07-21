///|
pub fn simplify_globals_optimizing_summary() -> String {
  "Simplify private global state and rerun default function cleanup on changed functions."
}

///|
priv struct SgoGlobalInfo {
  imported : Bool
  mut exported : Bool
  mut mutable_ : Bool
  value_type : @lib.ValType
  mut init : @lib.Expr?
  mut read_count : Int
  mut write_count : Int
}

///|
priv struct SgoRewriteState {
  consts : Array[@lib.Instruction?]
  aliases : Array[@lib.GlobalIdx?]
  remove_sets : Array[Bool]
  mut changed : Bool
}

///|
priv struct SgoGlobalInitRewriteState {
  consts : Array[@lib.Instruction?]
  aliases : Array[@lib.GlobalIdx?]
  inlines : Array[@lib.Expr?]
  mut changed : Bool
}

///|
priv struct SgoPassResult {
  mod_out : @lib.Module
  touched : Array[Bool]
}

///|
priv enum SgoScalarFlowKind {
  SgoFlowI32
  SgoFlowI64
  SgoFlowF32
  SgoFlowF64
} derive(Eq)

///|
priv struct SgoScalarIndependentFragment {
  result_kind : SgoScalarFlowKind
  start_pos : Int
  next_pos : Int
  replay_end_pos : Int
  replay_nested_block : Bool
}

///|
fn sgo_global_idx_slot(idx : @lib.GlobalIdx) -> Int {
  let @lib.GlobalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn sgo_defined_global_abs_idx(imported_globals : Int, defined_idx : Int) -> Int {
  imported_globals + defined_idx
}

///|
fn sgo_const_instr(instr : @lib.Instruction) -> @lib.Instruction? {
  match instr {
    @lib.I32Const(_)
    | @lib.I64Const(_)
    | @lib.F32Const(_)
    | @lib.F64Const(_)
    | @lib.V128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | @lib.RefNull(_)
    | @lib.RefFunc(_)
    | @lib.StringConst(_) => Some(instr)
    _ => None
  }
}

///|
fn sgo_expr_single_const(expr : @lib.Expr) -> @lib.Instruction? {
  match expr {
    @lib.Expr([instr]) => sgo_const_instr(instr)
    _ => None
  }
}

///|
fn sgo_empty_const_array(length : Int) -> Array[@lib.Instruction?] {
  Array::make(length, None)
}

///|
fn sgo_empty_expr_array(length : Int) -> Array[@lib.Expr?] {
  Array::make(length, None)
}

///|
fn sgo_empty_global_idx_array(length : Int) -> Array[@lib.GlobalIdx?] {
  Array::make(length, None)
}

///|
fn sgo_scan_global_idx(
  infos : Array[SgoGlobalInfo],
  idx : @lib.GlobalIdx,
  read : Bool,
) -> Unit {
  let slot = sgo_global_idx_slot(idx)
  if slot < 0 || slot >= infos.length() {
    return
  }
  if read {
    infos[slot].read_count = infos[slot].read_count + 1
  } else {
    infos[slot].write_count = infos[slot].write_count + 1
  }
}

///|
fn sgo_scan_instr(
  instr : @lib.Instruction,
  infos : Array[SgoGlobalInfo],
) -> Unit {
  match instr {
    @lib.GlobalGet(idx) => sgo_scan_global_idx(infos, idx, true)
    @lib.GlobalSet(idx) => sgo_scan_global_idx(infos, idx, false)
    @lib.Block(_, body) | @lib.Loop(_, body) => sgo_scan_expr(body, infos)
    @lib.If(_, then_body, else_body) => {
      sgo_scan_instrs(then_body, infos)
      match else_body {
        Some(body) => sgo_scan_instrs(body, infos)
        None => ()
      }
    }
    @lib.TryTable(_, _, body) => sgo_scan_expr(body, infos)
    _ => ()
  }
}

///|
fn sgo_scan_instrs(
  instrs : Array[@lib.Instruction],
  infos : Array[SgoGlobalInfo],
) -> Unit {
  for instr in instrs {
    sgo_scan_instr(instr, infos)
  }
}

///|
fn sgo_scan_expr(expr : @lib.Expr, infos : Array[SgoGlobalInfo]) -> Unit {
  let @lib.Expr(instrs) = expr
  sgo_scan_instrs(instrs, infos)
}

///|
fn sgo_instr_may_reference_global(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.GlobalGet(_) | @lib.GlobalSet(_) => true
    @lib.Block(_, body) | @lib.Loop(_, body) | @lib.TryTable(_, _, body) =>
      sgo_expr_may_reference_global(body)
    @lib.If(_, then_body, else_body) => {
      let else_refs = match else_body {
        Some(body) => sgo_instrs_may_reference_global(body)
        None => false
      }
      sgo_instrs_may_reference_global(then_body) || else_refs
    }
    _ => false
  }
}

///|
fn sgo_instrs_may_reference_global(instrs : Array[@lib.Instruction]) -> Bool {
  instrs.any(sgo_instr_may_reference_global)
}

///|
fn sgo_instr_references_global_idx(
  instr : @lib.Instruction,
  idx : @lib.GlobalIdx,
) -> Bool {
  match instr {
    @lib.GlobalGet(get_idx) | @lib.GlobalSet(get_idx) => get_idx == idx
    @lib.Block(_, body) | @lib.Loop(_, body) | @lib.TryTable(_, _, body) =>
      sgo_expr_references_global_idx(body, idx)
    @lib.If(_, then_body, else_body) => {
      let else_refs = match else_body {
        Some(body) => sgo_instrs_reference_global_idx(body, idx)
        None => false
      }
      sgo_instrs_reference_global_idx(then_body, idx) || else_refs
    }
    _ => false
  }
}

///|
fn sgo_instrs_reference_global_idx(
  instrs : Array[@lib.Instruction],
  idx : @lib.GlobalIdx,
) -> Bool {
  instrs.any(fn(instr) { sgo_instr_references_global_idx(instr, idx) })
}

///|
fn sgo_expr_references_global_idx(
  expr : @lib.Expr,
  idx : @lib.GlobalIdx,
) -> Bool {
  let @lib.Expr(instrs) = expr
  sgo_instrs_reference_global_idx(instrs, idx)
}

///|
fn sgo_expr_may_reference_global(expr : @lib.Expr) -> Bool {
  let @lib.Expr(instrs) = expr
  sgo_instrs_may_reference_global(instrs)
}

///|
fn sgo_type_sec_func_type(
  type_sec : @lib.TypeSec,
  type_idx : @lib.TypeIdx,
) -> @lib.FuncType? {
  match (type_sec, type_idx) {
    (@lib.TypeSec(rec_types), @lib.TypeIdx(raw)) => {
      let slot = raw.reinterpret_as_int()
      if slot < 0 || slot >= rec_types.length() {
        return None
      }
      match rec_types[slot] {
        @lib.SingleRecType(subtype) =>
          match subtype.get_comptype() {
            @lib.FuncCompType(params, results) =>
              Some(@lib.FuncType::new(params, results))
            _ => None
          }
        @lib.GroupRecType(_) => None
      }
    }
    _ => None
  }
}

///|
fn sgo_collect_func_type_indices(mod_ : @lib.Module) -> Array[@lib.TypeIdx] {
  let out : Array[@lib.TypeIdx] = []
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(type_idx)) => out.push(type_idx)
          _ => ()
        }
      }
    None => ()
  }
  match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => out.append(type_idxs)
    None => ()
  }
  out
}

///|
fn sgo_resolve_func_type(
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
  func_abs : Int,
) -> @lib.FuncType? {
  if func_abs < 0 || func_abs >= func_type_indices.length() {
    return None
  }
  match mod_.type_sec {
    Some(type_sec) =>
      sgo_type_sec_func_type(type_sec, func_type_indices[func_abs])
    None => None
  }
}

///|
fn sgo_func_idx_slot(idx : @lib.FuncIdx) -> Int {
  let @lib.FuncIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn sgo_call_has_no_params_one_result(
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
  func_idx : @lib.FuncIdx,
) -> Bool {
  match
    sgo_resolve_func_type(mod_, func_type_indices, sgo_func_idx_slot(func_idx)) {
    Some(@lib.FuncType(params, results)) =>
      params.length() == 0 && results.length() == 1
    None => false
  }
}

///|
fn sgo_call_has_no_params_no_results(
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
  func_idx : @lib.FuncIdx,
) -> Bool {
  match
    sgo_resolve_func_type(mod_, func_type_indices, sgo_func_idx_slot(func_idx)) {
    Some(@lib.FuncType(params, results)) =>
      params.length() == 0 && results.length() == 0
    None => false
  }
}

///|
fn sgo_scalar_flow_kind(value_type : @lib.ValType) -> SgoScalarFlowKind? {
  match value_type {
    @lib.NumTypeValType(@lib.I32NumType) => Some(SgoFlowI32)
    @lib.NumTypeValType(@lib.I64NumType) => Some(SgoFlowI64)
    @lib.NumTypeValType(@lib.F32NumType) => Some(SgoFlowF32)
    @lib.NumTypeValType(@lib.F64NumType) => Some(SgoFlowF64)
    _ => None
  }
}

///|
fn sgo_call_no_params_scalar_result_kind(
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
  func_idx : @lib.FuncIdx,
) -> SgoScalarFlowKind? {
  match
    sgo_resolve_func_type(mod_, func_type_indices, sgo_func_idx_slot(func_idx)) {
    Some(@lib.FuncType(params, [result])) if params.length() == 0 =>
      sgo_scalar_flow_kind(result)
    _ => None
  }
}

///|
fn sgo_collect_global_infos(mod_ : @lib.Module) -> (Array[SgoGlobalInfo], Int) {
  let infos : Array[SgoGlobalInfo] = []
  let mut imported_globals = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(
            _,
            _,
            @lib.GlobalExternType(@lib.GlobalType(value_type, mutable_))
          ) => {
            infos.push({
              imported: true,
              exported: false,
              mutable_,
              value_type,
              init: None,
              read_count: 0,
              write_count: 0,
            })
            imported_globals += 1
          }
          _ => ()
        }
      }
    None => ()
  }
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) =>
      for global_ in globals {
        let @lib.Global(@lib.GlobalType(value_type, mutable_), init) = global_
        infos.push({
          imported: false,
          exported: false,
          mutable_,
          value_type,
          init: Some(init),
          read_count: 0,
          write_count: 0,
        })
      }
    None => ()
  }
  match mod_.export_sec {
    Some(@lib.ExportSec(exports)) =>
      for export_ in exports {
        let @lib.Export(_, idx) = export_
        match idx {
          @lib.GlobalExternIdx(global_idx) => {
            let slot = sgo_global_idx_slot(global_idx)
            if slot >= 0 && slot < infos.length() {
              infos[slot].exported = true
            }
          }
          _ => ()
        }
      }
    None => ()
  }
  sgo_scan_table_sec(mod_.table_sec, infos)
  sgo_scan_global_sec(mod_.global_sec, infos)
  sgo_scan_elem_sec(mod_.elem_sec, infos)
  sgo_scan_data_sec(mod_.data_sec, infos)
  sgo_scan_code_sec(mod_.code_sec, infos)
  (infos, imported_globals)
}

///|
fn sgo_scan_table_sec(
  table_sec : @lib.TableSec?,
  infos : Array[SgoGlobalInfo],
) -> Unit {
  match table_sec {
    Some(@lib.TableSec(tables)) =>
      for table in tables {
        match table {
          @lib.Table(_, Some(init)) => sgo_scan_expr(init, infos)
          _ => ()
        }
      }
    None => ()
  }
}

///|
fn sgo_scan_global_sec(
  global_sec : @lib.GlobalSec?,
  infos : Array[SgoGlobalInfo],
) -> Unit {
  match global_sec {
    Some(@lib.GlobalSec(globals)) =>
      for global_ in globals {
        let @lib.Global(_, init) = global_
        sgo_scan_expr(init, infos)
      }
    None => ()
  }
}

///|
fn sgo_scan_elem_mode(
  mode : @lib.ElemMode,
  infos : Array[SgoGlobalInfo],
) -> Unit {
  match mode {
    @lib.Active(_, offset) => sgo_scan_expr(offset, infos)
    _ => ()
  }
}

///|
fn sgo_scan_elem_kind(
  kind : @lib.ElemKind,
  infos : Array[SgoGlobalInfo],
) -> Unit {
  match kind {
    @lib.FuncExprsElemKind(exprs) | @lib.TypedExprsElemKind(_, exprs) =>
      for expr in exprs {
        sgo_scan_expr(expr, infos)
      }
    _ => ()
  }
}

///|
fn sgo_scan_elem_sec(
  elem_sec : @lib.ElemSec?,
  infos : Array[SgoGlobalInfo],
) -> Unit {
  match elem_sec {
    Some(@lib.ElemSec(elems)) =>
      for elem in elems {
        let @lib.Elem(mode, kind) = elem
        sgo_scan_elem_mode(mode, infos)
        sgo_scan_elem_kind(kind, infos)
      }
    None => ()
  }
}

///|
fn sgo_scan_data_sec(
  data_sec : @lib.DataSec?,
  infos : Array[SgoGlobalInfo],
) -> Unit {
  match data_sec {
    Some(@lib.DataSec(datas)) =>
      for data in datas {
        let @lib.Data(mode, _) = data
        match mode {
          @lib.Active(_, offset) => sgo_scan_expr(offset, infos)
          _ => ()
        }
      }
    None => ()
  }
}

///|
fn sgo_scan_code_sec(
  code_sec : @lib.CodeSec?,
  infos : Array[SgoGlobalInfo],
) -> Unit {
  match code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func_ in funcs {
        let @lib.Func(_, body) = func_
        sgo_scan_expr(body, infos)
      }
    None => ()
  }
}

///|
fn sgo_same_init_write_flags(
  code_sec : @lib.CodeSec?,
  infos : Array[SgoGlobalInfo],
) -> Array[Bool] {
  let init_consts = sgo_build_initial_startup_consts(infos)
  let flags = Array::make(infos.length(), true)
  match code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func_ in funcs {
        let @lib.Func(_, body) = func_
        if sgo_expr_may_reference_global(body) {
          sgo_mark_same_init_writes_expr(body, init_consts, flags)
        }
      }
    None => ()
  }
  flags
}

///|
fn sgo_mark_same_init_writes_expr(
  expr : @lib.Expr,
  init_consts : Array[@lib.Instruction?],
  flags : Array[Bool],
) -> Unit {
  let @lib.Expr(instrs) = expr
  sgo_mark_same_init_writes_instrs(instrs, init_consts, flags)
}

///|
fn sgo_mark_same_init_writes_instrs(
  instrs : Array[@lib.Instruction],
  init_consts : Array[@lib.Instruction?],
  flags : Array[Bool],
) -> Unit {
  for pos = 0; pos < instrs.length(); pos = pos + 1 {
    let instr = instrs[pos]
    match instr {
      @lib.GlobalSet(idx) =>
        sgo_mark_same_init_write(idx, pos, instrs, init_consts, flags)
      @lib.Block(_, body) | @lib.Loop(_, body) =>
        sgo_mark_same_init_writes_expr(body, init_consts, flags)
      @lib.If(_, then_body, else_body) => {
        sgo_mark_same_init_writes_instrs(then_body, init_consts, flags)
        match else_body {
          Some(body) =>
            sgo_mark_same_init_writes_instrs(body, init_consts, flags)
          None => ()
        }
      }
      @lib.TryTable(_, _, body) =>
        sgo_mark_same_init_writes_expr(body, init_consts, flags)
      _ => ()
    }
  }
}

///|
fn sgo_mark_same_init_write(
  idx : @lib.GlobalIdx,
  pos : Int,
  instrs : Array[@lib.Instruction],
  init_consts : Array[@lib.Instruction?],
  flags : Array[Bool],
) -> Unit {
  let slot = sgo_global_idx_slot(idx)
  if slot < 0 || slot >= flags.length() || slot >= init_consts.length() {
    return
  }
  let mut matches_init = false
  if pos > 0 {
    match (sgo_const_instr(instrs[pos - 1]), init_consts[slot]) {
      (Some(actual), Some(expected)) if actual == expected =>
        matches_init = true
      _ => ()
    }
  }
  if !matches_init {
    flags[slot] = false
  }
}

///|
fn sgo_read_only_to_write_flags(
  mod_ : @lib.Module,
  infos : Array[SgoGlobalInfo],
) -> Array[Bool] {
  let safe_reads = Array::make(infos.length(), 0)
  let func_type_indices = sgo_collect_func_type_indices(mod_)
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func_ in funcs {
        let @lib.Func(_, body) = func_
        if sgo_expr_may_reference_global(body) {
          sgo_count_read_only_to_write_expr(
            body, safe_reads, mod_, func_type_indices,
          )
          sgo_count_nested_multiglobal_read_only_to_write_expr(
            body, safe_reads, infos,
          )
        }
      }
    None => ()
  }
  let flags = Array::make(infos.length(), false)
  for idx = 0; idx < infos.length(); idx = idx + 1 {
    flags[idx] = infos[idx].read_count > 0 &&
      safe_reads[idx] == infos[idx].read_count
  }
  flags
}

///|
fn sgo_count_read_only_to_write_expr(
  expr : @lib.Expr,
  safe_reads : Array[Int],
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> Unit {
  let @lib.Expr(instrs) = expr
  sgo_count_read_only_to_write_instrs(
    instrs, safe_reads, mod_, func_type_indices,
  )
}

///|
fn sgo_count_read_only_to_write_safe_read(
  idx : @lib.GlobalIdx,
  safe_reads : Array[Int],
) -> Unit {
  let slot = sgo_global_idx_slot(idx)
  if slot >= 0 && slot < safe_reads.length() {
    safe_reads[slot] = safe_reads[slot] + 1
  }
}

///|
fn sgo_guarded_scalar_pure_producer_read(
  instr : @lib.Instruction,
  result_kind : SgoScalarFlowKind,
) -> @lib.GlobalIdx? {
  match instr {
    @lib.GlobalGet(idx) => Some(idx)
    @lib.Block(@lib.ValTypeBlockType(value_type), @lib.Expr(body))
    | @lib.Loop(@lib.ValTypeBlockType(value_type), @lib.Expr(body))
    | @lib.TryTable(@lib.ValTypeBlockType(value_type), _, @lib.Expr(body)) =>
      match sgo_scalar_flow_kind(value_type) {
        Some(kind) if kind == result_kind =>
          sgo_guarded_scalar_pure_body_read(body, result_kind)
        _ => None
      }
    _ => None
  }
}

///|
fn sgo_guarded_scalar_pure_body_read(
  body : Array[@lib.Instruction],
  result_kind : SgoScalarFlowKind,
) -> @lib.GlobalIdx? {
  if body.length() == 0 {
    return None
  }
  let idx = match sgo_guarded_scalar_pure_producer_read(body[0], result_kind) {
    Some(idx) => idx
    None => return None
  }
  let mut kind = result_kind
  let mut pos = 1
  while pos < body.length() {
    match sgo_scalar_unary_result(body[pos], kind) {
      Some(next_kind) => {
        kind = next_kind
        pos = pos + 1
        continue
      }
      None => ()
    }
    if pos + 1 < body.length() && sgo_scalar_const_kind(body[pos]) == Some(kind) {
      match sgo_scalar_binary_result(body[pos + 1], kind) {
        Some(next_kind) => {
          kind = next_kind
          pos = pos + 2
          continue
        }
        None => ()
      }
    }
    return None
  }
  if kind == result_kind {
    Some(idx)
  } else {
    None
  }
}

///|
fn sgo_structured_guarded_scalar_read(
  instr : @lib.Instruction,
) -> (@lib.GlobalIdx, SgoScalarFlowKind)? {
  match instr {
    @lib.Loop(@lib.ValTypeBlockType(value_type), @lib.Expr(body)) =>
      match sgo_scalar_flow_kind(value_type) {
        Some(result_kind) =>
          match sgo_guarded_scalar_pure_body_read(body, result_kind) {
            Some(idx) => Some((idx, result_kind))
            None => None
          }
        None => None
      }
    @lib.TryTable(@lib.ValTypeBlockType(value_type), _, @lib.Expr(body)) =>
      match sgo_scalar_flow_kind(value_type) {
        Some(result_kind) =>
          match sgo_guarded_scalar_pure_body_read(body, result_kind) {
            Some(idx) => Some((idx, result_kind))
            None => None
          }
        None => None
      }
    @lib.Block(@lib.ValTypeBlockType(value_type), @lib.Expr(body)) =>
      match sgo_scalar_flow_kind(value_type) {
        Some(result_kind) => {
          let nested_pure_idx = if body.length() > 0 {
            match body[0] {
              @lib.TryTable(_, _, _) =>
                sgo_guarded_scalar_pure_body_read(body, result_kind)
              _ => None
            }
          } else {
            None
          }
          match nested_pure_idx {
            Some(idx) => Some((idx, result_kind))
            None =>
              match body {
                [
                  @lib.GlobalGet(idx),
                  @lib.LocalGet(_),
                  @lib.BrIf(_),
                  @lib.Drop,
                  result,
                ] if sgo_scalar_const_kind(result) == Some(result_kind) =>
                  Some((idx, result_kind))
                _ => None
              }
          }
        }
        None => None
      }
    _ => None
  }
}

///|
fn sgo_count_structured_guarded_scalar_read(
  instrs : Array[@lib.Instruction],
  pos : Int,
  safe_reads : Array[Int],
) -> Unit {
  match sgo_structured_guarded_scalar_read(instrs[pos]) {
    Some((idx, result_kind)) => {
      let prefix_start = sgo_scalar_const_prefix_start(instrs, pos)
      if sgo_scalar_pure_suffix_with_prefix_tail_matches(
          instrs,
          pos + 1,
          idx,
          result_kind,
          prefix_start,
          pos,
        ) {
        sgo_count_read_only_to_write_safe_read(idx, safe_reads)
      }
    }
    None => ()
  }
}

///|
fn sgo_count_read_only_to_write_instrs(
  instrs : Array[@lib.Instruction],
  safe_reads : Array[Int],
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> Unit {
  for pos = 0; pos < instrs.length(); pos = pos + 1 {
    let instr = instrs[pos]
    match instr {
      @lib.GlobalGet(idx) =>
        if sgo_read_only_to_write_read_at(
            instrs, pos, idx, mod_, func_type_indices,
          ) {
          sgo_count_read_only_to_write_safe_read(idx, safe_reads)
        }
      @lib.Block(_, body) => {
        sgo_count_structured_guarded_scalar_read(instrs, pos, safe_reads)
        sgo_count_block_condition_external_pure_read(instrs, pos, safe_reads)
        sgo_count_block_condition_external_pure_if_return_read(
          instrs, pos, safe_reads,
        )
        sgo_count_block_condition_reverse_external_pure_read(
          instrs, pos, safe_reads,
        )
        sgo_count_block_condition_reverse_external_pure_if_return_read(
          instrs, pos, safe_reads,
        )
        if pos + 1 < instrs.length() {
          sgo_count_block_condition_read_only_to_write_read(
            instr,
            instrs[pos + 1],
            safe_reads,
          )
          sgo_count_block_condition_independent_call_read_only_to_write_read(
            instr,
            instrs[pos + 1],
            safe_reads,
            mod_,
            func_type_indices,
          )
          sgo_count_block_condition_independent_memory_read_only_to_write_read(
            instr,
            instrs[pos + 1],
            safe_reads,
          )
          sgo_count_block_condition_independent_table_read_only_to_write_read(
            instr,
            instrs[pos + 1],
            safe_reads,
          )
          sgo_count_block_condition_independent_local_read_only_to_write_read(
            instr,
            instrs[pos + 1],
            safe_reads,
          )
          sgo_count_block_condition_independent_global_set_read_only_to_write_read(
            instr,
            instrs[pos + 1],
            safe_reads,
          )
        }
        sgo_count_block_condition_independent_call_if_return_read(
          instrs, pos, safe_reads, mod_, func_type_indices,
        )
        sgo_count_block_condition_independent_memory_if_return_read(
          instrs, pos, safe_reads,
        )
        sgo_count_block_condition_independent_table_if_return_read(
          instrs, pos, safe_reads,
        )
        sgo_count_block_condition_independent_local_if_return_read(
          instrs, pos, safe_reads,
        )
        sgo_count_block_condition_independent_global_set_if_return_read(
          instrs, pos, safe_reads,
        )
        if pos + 2 < instrs.length() {
          if pos + 3 == instrs.length() {
            sgo_count_block_condition_if_return_block_set_read(
              instr,
              instrs[pos + 1],
              instrs[pos + 2],
              safe_reads,
            )
          }
          sgo_count_block_condition_eqz_read_only_to_write_read(
            instr,
            instrs[pos + 1],
            instrs[pos + 2],
            safe_reads,
          )
          sgo_count_block_condition_reverse_compare_read_only_to_write_read(
            instrs, pos, safe_reads,
          )
        }
        if pos + 3 < instrs.length() {
          if pos + 4 == instrs.length() {
            sgo_count_block_condition_if_return_set_read(
              instr,
              instrs[pos + 1],
              instrs[pos + 2],
              instrs[pos + 3],
              safe_reads,
            )
            sgo_count_block_condition_eqz_if_return_block_set_read(
              instr,
              instrs[pos + 1],
              instrs[pos + 2],
              instrs[pos + 3],
              safe_reads,
            )
            sgo_count_block_condition_reverse_compare_if_return_block_set_read(
              instrs, pos, safe_reads,
            )
          }
          sgo_count_block_condition_compare_read_only_to_write_read(
            instr,
            instrs[pos + 1],
            instrs[pos + 2],
            instrs[pos + 3],
            safe_reads,
          )
        }
        if pos + 4 < instrs.length() {
          if pos + 5 == instrs.length() {
            sgo_count_block_condition_eqz_if_return_set_read(
              instr,
              instrs[pos + 1],
              instrs[pos + 2],
              instrs[pos + 3],
              instrs[pos + 4],
              safe_reads,
            )
            sgo_count_block_condition_reverse_compare_if_return_set_read(
              instrs, pos, safe_reads,
            )
            sgo_count_block_condition_compare_if_return_block_set_read(
              instr,
              instrs[pos + 1],
              instrs[pos + 2],
              instrs[pos + 3],
              instrs[pos + 4],
              safe_reads,
            )
          }
        }
        if pos + 5 < instrs.length() {
          if pos + 6 == instrs.length() {
            sgo_count_block_condition_compare_if_return_set_read(
              instr,
              instrs[pos + 1],
              instrs[pos + 2],
              instrs[pos + 3],
              instrs[pos + 4],
              instrs[pos + 5],
              safe_reads,
            )
          }
        }
        sgo_count_read_only_to_write_expr(
          body, safe_reads, mod_, func_type_indices,
        )
      }
      @lib.Loop(_, body) => {
        sgo_count_structured_guarded_scalar_read(instrs, pos, safe_reads)
        sgo_count_read_only_to_write_expr(
          body, safe_reads, mod_, func_type_indices,
        )
      }
      @lib.If(_, then_body, else_body) => {
        sgo_count_if_arm_condition_read_only_to_write_read(
          instrs, pos, safe_reads,
        )
        sgo_count_if_arm_condition_if_return_read(instrs, pos, safe_reads)
        sgo_count_read_only_to_write_instrs(
          then_body, safe_reads, mod_, func_type_indices,
        )
        match else_body {
          Some(body) =>
            sgo_count_read_only_to_write_instrs(
              body, safe_reads, mod_, func_type_indices,
            )
          None => ()
        }
      }
      @lib.TryTable(_, _, body) => {
        sgo_count_structured_guarded_scalar_read(instrs, pos, safe_reads)
        sgo_count_read_only_to_write_expr(
          body, safe_reads, mod_, func_type_indices,
        )
      }
      _ => ()
    }
  }
}

///|
fn sgo_if_is_read_only_to_write_set(
  instr : @lib.Instruction,
  idx : @lib.GlobalIdx,
) -> Bool {
  match instr {
    @lib.If(_, then_body, None) =>
      sgo_instrs_are_single_const_global_set(then_body, idx)
    _ => false
  }
}

///|
fn sgo_if_arm_condition_read_idx(instr : @lib.Instruction) -> @lib.GlobalIdx? {
  match instr {
    @lib.If(_, then_body, Some(else_body)) => {
      let then_idx = sgo_block_condition_safe_arm_read_idx(then_body)
      let else_idx = sgo_block_condition_safe_arm_read_idx(else_body)
      match (then_idx, else_idx) {
        (Some(idx), None) if !sgo_instrs_may_reference_global(else_body) =>
          Some(idx)
        (None, Some(idx)) if !sgo_instrs_may_reference_global(then_body) =>
          Some(idx)
        _ => None
      }
    }
    _ => None
  }
}

///|
fn sgo_count_if_arm_condition_read_only_to_write_read(
  instrs : Array[@lib.Instruction],
  pos : Int,
  safe_reads : Array[Int],
) -> Unit {
  match sgo_if_arm_condition_read_idx(instrs[pos]) {
    Some(idx) =>
      for scan = pos + 1; scan < instrs.length(); scan = scan + 1 {
        let instr = instrs[scan]
        match instr {
          @lib.If(_, _, _) => {
            if sgo_if_is_read_only_to_write_set(instr, idx) {
              sgo_count_read_only_to_write_safe_read(idx, safe_reads)
            }
            return
          }
          _ =>
            if !sgo_is_read_only_to_write_pure_condition_instr(instr) {
              return
            }
        }
      }
    None => ()
  }
}

///|
fn sgo_count_if_arm_condition_if_return_read(
  instrs : Array[@lib.Instruction],
  pos : Int,
  safe_reads : Array[Int],
) -> Unit {
  match sgo_if_arm_condition_read_idx(instrs[pos]) {
    Some(idx) =>
      for scan = pos + 1; scan < instrs.length(); scan = scan + 1 {
        let instr = instrs[scan]
        if sgo_is_return_guard(instr) {
          if sgo_if_return_tail_matches(instrs, scan + 1, idx) {
            sgo_count_read_only_to_write_safe_read(idx, safe_reads)
          }
          return
        }
        if !sgo_is_read_only_to_write_pure_condition_instr(instr) {
          return
        }
      }
    None => ()
  }
}

///|
fn sgo_read_only_to_write_read_at(
  instrs : Array[@lib.Instruction],
  pos : Int,
  idx : @lib.GlobalIdx,
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> Bool {
  sgo_is_exact_if_return_set(instrs, pos, idx) ||
  sgo_is_pure_condition_if_return_set(instrs, pos, idx) ||
  sgo_scalar_call_parent_chain_read_at(
    instrs, pos, idx, mod_, func_type_indices,
  ) ||
  sgo_select_operand_independent_call_read_at(
    instrs, pos, idx, mod_, func_type_indices,
  ) ||
  sgo_compare_operand_independent_call_read_at(
    instrs, pos, idx, mod_, func_type_indices,
  ) ||
  sgo_pure_i32_binary_operand_independent_call_read_at(
    instrs, pos, idx, mod_, func_type_indices,
  ) ||
  sgo_pure_i64_binary_operand_independent_call_read_at(
    instrs, pos, idx, mod_, func_type_indices,
  ) ||
  sgo_float_binary_operand_independent_call_read_at(
    instrs, pos, idx, mod_, func_type_indices,
  ) ||
  sgo_compare_operand_independent_memory_read_at(instrs, pos, idx) ||
  sgo_compare_operand_independent_table_read_at(instrs, pos, idx) ||
  sgo_compare_operand_independent_local_tee_read_at(instrs, pos, idx) ||
  sgo_compare_operand_independent_global_set_read_at(instrs, pos, idx) ||
  sgo_compare_operand_independent_memory_store_read_at(instrs, pos, idx) ||
  sgo_select_operand_independent_memory_read_at(instrs, pos, idx) ||
  sgo_select_operand_independent_table_read_at(instrs, pos, idx) ||
  sgo_select_operand_independent_local_tee_read_at(instrs, pos, idx) ||
  (
    pos + 1 < instrs.length() &&
    sgo_if_is_read_only_to_write_set(instrs[pos + 1], idx)
  ) ||
  (
    pos + 2 < instrs.length() &&
    instrs[pos + 1] == @lib.Instruction::i32_eqz() &&
    sgo_if_is_read_only_to_write_set(instrs[pos + 2], idx)
  ) ||
  (
    pos + 3 < instrs.length() &&
    sgo_const_instr(instrs[pos + 1]) != None &&
    (
      instrs[pos + 2] == @lib.Instruction::i32_eq() ||
      instrs[pos + 2] == @lib.Instruction::i32_ne()
    ) &&
    sgo_if_is_read_only_to_write_set(instrs[pos + 3], idx)
  ) ||
  (
    pos > 0 &&
    pos + 2 < instrs.length() &&
    sgo_const_instr(instrs[pos - 1]) != None &&
    (
      instrs[pos + 1] == @lib.Instruction::i32_eq() ||
      instrs[pos + 1] == @lib.Instruction::i32_ne()
    ) &&
    sgo_if_is_read_only_to_write_set(instrs[pos + 2], idx)
  ) ||
  sgo_read_only_to_write_pure_condition_read_at(instrs, pos, idx) ||
  sgo_read_only_to_write_if_return_value_read_at(instrs, pos, idx)
}

///|
fn sgo_local_effect_value_is_independent(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.LocalGet(_) => true
    _ => sgo_const_instr(instr) != None
  }
}

///|
fn sgo_select_operand_independent_local_tee_read_at(
  instrs : Array[@lib.Instruction],
  pos : Int,
  idx : @lib.GlobalIdx,
) -> Bool {
  // Narrow FlowScanner subset: an independent constant local.tee supplies one
  // select operand while the guarded global supplies the other. The guarded
  // value must not flow into the local write; it may only flow through select
  // to the same-global guarded write or if-return tail.
  match instrs[pos] {
    @lib.GlobalGet(get_idx) if get_idx == idx => ()
    _ => return false
  }
  if pos + 5 < instrs.length() {
    match
      (
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
      ) {
      (value, @lib.LocalTee(_), const_instr, @lib.Select(_), if_instr) if sgo_const_instr(
          value,
        ) !=
        None &&
        sgo_const_instr(const_instr) != None =>
        if sgo_if_is_read_only_to_write_set(if_instr, idx) ||
          (
            sgo_is_return_guard(if_instr) &&
            sgo_if_return_tail_matches(instrs, pos + 6, idx)
          ) {
          return true
        }
      _ => ()
    }
  }
  if pos > 1 && pos + 3 < instrs.length() {
    match
      (
        instrs[pos - 2],
        instrs[pos - 1],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
      ) {
      (value, @lib.LocalTee(_), const_instr, @lib.Select(_), if_instr) if sgo_const_instr(
          value,
        ) !=
        None &&
        sgo_const_instr(const_instr) != None =>
        if sgo_if_is_read_only_to_write_set(if_instr, idx) ||
          (
            sgo_is_return_guard(if_instr) &&
            sgo_if_return_tail_matches(instrs, pos + 4, idx)
          ) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn sgo_compare_operand_independent_local_tee_read_at(
  instrs : Array[@lib.Instruction],
  pos : Int,
  idx : @lib.GlobalIdx,
) -> Bool {
  // Narrow FlowScanner subset: an independent constant-or-local.get local.tee
  // supplies one compare operand while the guarded global supplies the other.
  // The guarded value must not flow into the local write; it may only reach the
  // compare that feeds the same-global guarded write or if-return tail.
  match instrs[pos] {
    @lib.GlobalGet(get_idx) if get_idx == idx => ()
    _ => return false
  }
  if pos + 4 < instrs.length() {
    match (instrs[pos + 1], instrs[pos + 2], instrs[pos + 3], instrs[pos + 4]) {
      (value, @lib.LocalTee(_), compare, if_instr) if sgo_local_effect_value_is_independent(
          value,
        ) &&
        sgo_is_compare_instr(compare) =>
        if sgo_if_is_read_only_to_write_set(if_instr, idx) ||
          (
            sgo_is_return_guard(if_instr) &&
            sgo_if_return_tail_matches(instrs, pos + 5, idx)
          ) {
          return true
        }
      _ => ()
    }
  }
  if pos > 1 && pos + 2 < instrs.length() {
    match (instrs[pos - 2], instrs[pos - 1], instrs[pos + 1], instrs[pos + 2]) {
      (value, @lib.LocalTee(_), compare, if_instr) if sgo_local_effect_value_is_independent(
          value,
        ) &&
        sgo_is_compare_instr(compare) =>
        if sgo_if_is_read_only_to_write_set(if_instr, idx) ||
          (
            sgo_is_return_guard(if_instr) &&
            sgo_if_return_tail_matches(instrs, pos + 3, idx)
          ) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn sgo_global_set_result_block_value_is_independent(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.LocalGet(_) => true
    _ => sgo_const_instr(instr) != None
  }
}

///|
fn sgo_independent_global_set_result_block_matches(
  instr : @lib.Instruction,
  idx : @lib.GlobalIdx,
) -> Bool {
  match instr {
    @lib.Block(
      @lib.ValTypeBlockType(_)
      | @lib.TypeIdxBlockType(_),
      @lib.Expr([value, @lib.GlobalSet(set_idx), result_const])
    ) =>
      set_idx != idx &&
      sgo_global_set_result_block_value_is_independent(value) &&
      sgo_const_instr(result_const) != None
    _ => false
  }
}

///|
fn sgo_compare_operand_independent_global_set_read_at(
  instrs : Array[@lib.Instruction],
  pos : Int,
  idx : @lib.GlobalIdx,
) -> Bool {
  // Narrow FlowScanner subset: an independent constant-or-local.get global.set
  // to a different global may produce the other compare operand through a
  // result block. The guarded value reaches only the compare and final
  // same-global guarded write / if-return tail; it must not feed the
  // independent set.
  match instrs[pos] {
    @lib.GlobalGet(get_idx) if get_idx == idx => ()
    _ => return false
  }
  if pos + 3 < instrs.length() {
    match (instrs[pos + 1], instrs[pos + 2], instrs[pos + 3]) {
      (block, compare, if_instr) if sgo_is_compare_instr(compare) &&
        sgo_independent_global_set_result_block_matches(block, idx) =>
        if sgo_if_is_read_only_to_write_set(if_instr, idx) ||
          (
            sgo_is_return_guard(if_instr) &&
            sgo_if_return_tail_matches(instrs, pos + 4, idx)
          ) {
          return true
        }
      _ => ()
    }
  }
  if pos > 0 && pos + 2 < instrs.length() {
    match (instrs[pos - 1], instrs[pos + 1], instrs[pos + 2]) {
      (block, compare, if_instr) if sgo_is_compare_instr(compare) &&
        sgo_independent_global_set_result_block_matches(block, idx) =>
        if sgo_if_is_read_only_to_write_set(if_instr, idx) ||
          (
            sgo_is_return_guard(if_instr) &&
            sgo_if_return_tail_matches(instrs, pos + 3, idx)
          ) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn sgo_is_plain_memory_store_instr(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.I32Store(_)
    | @lib.I64Store(_)
    | @lib.F32Store(_)
    | @lib.F64Store(_)
    | @lib.I32Store8(_)
    | @lib.I32Store16(_)
    | @lib.I64Store8(_)
    | @lib.I64Store16(_)
    | @lib.I64Store32(_)
    | @lib.V128Store(_) => true
    _ => false
  }
}

///|
fn sgo_memory_store_result_block_operand_is_independent(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.LocalGet(_) => true
    _ => sgo_const_instr(instr) != None
  }
}

///|
fn sgo_independent_memory_store_result_block_matches(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.Block(
      @lib.ValTypeBlockType(_)
      | @lib.TypeIdxBlockType(_),
      @lib.Expr([addr, value, store, result_const])
    ) =>
      sgo_memory_store_result_block_operand_is_independent(addr) &&
      sgo_memory_store_result_block_operand_is_independent(value) &&
      sgo_is_plain_memory_store_instr(store) &&
      sgo_const_instr(result_const) != None
    _ => false
  }
}

///|
fn sgo_push_memory_store_result_block_effect(
  instr : @lib.Instruction,
  out : Array[@lib.Instruction],
) -> Unit {
  match instr {
    @lib.Block(
      @lib.ValTypeBlockType(_)
      | @lib.TypeIdxBlockType(_),
      @lib.Expr([addr, value, store, _])
    ) if sgo_memory_store_result_block_operand_is_independent(addr) &&
      sgo_memory_store_result_block_operand_is_independent(value) &&
      sgo_is_plain_memory_store_instr(store) => {
      out.push(addr)
      out.push(value)
      out.push(store)
    }
    _ => ()
  }
}

///|
fn sgo_compare_operand_independent_memory_store_read_at(
  instrs : Array[@lib.Instruction],
  pos : Int,
  idx : @lib.GlobalIdx,
) -> Bool {
  // Narrow FlowScanner subset: an independent constant memory store may produce
  // the other compare operand through a result block. The guarded value reaches
  // only the compare and final same-global guarded write / if-return tail; it
  // must not feed the store address or stored value.
  match instrs[pos] {
    @lib.GlobalGet(get_idx) if get_idx == idx => ()
    _ => return false
  }
  if pos + 3 < instrs.length() {
    match (instrs[pos + 1], instrs[pos + 2], instrs[pos + 3]) {
      (block, compare, if_instr) if sgo_is_compare_instr(compare) &&
        sgo_independent_memory_store_result_block_matches(block) =>
        if sgo_if_is_read_only_to_write_set(if_instr, idx) ||
          (
            sgo_is_return_guard(if_instr) &&
            sgo_if_return_tail_matches(instrs, pos + 4, idx)
          ) {
          return true
        }
      _ => ()
    }
  }
  if pos > 0 && pos + 2 < instrs.length() {
    match (instrs[pos - 1], instrs[pos + 1], instrs[pos + 2]) {
      (block, compare, if_instr) if sgo_is_compare_instr(compare) &&
        sgo_independent_memory_store_result_block_matches(block) =>
        if sgo_if_is_read_only_to_write_set(if_instr, idx) ||
          (
            sgo_is_return_guard(if_instr) &&
            sgo_if_return_tail_matches(instrs, pos + 3, idx)
          ) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn sgo_select_operand_independent_call_read_at(
  instrs : Array[@lib.Instruction],
  pos : Int,
  idx : @lib.GlobalIdx,
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> Bool {
  // Narrow FlowScanner subset: from a valid empty-stack prefix, the guarded
  // global is the first select operand while a following zero-param call
  // provides the second operand independently. The global-derived select
  // result may then only reach the final same-global guarded write.
  if pos != 0 || pos + 4 >= instrs.length() {
    return false
  }
  match instrs[pos] {
    @lib.GlobalGet(get_idx) if get_idx == idx => ()
    _ => return false
  }
  match (instrs[pos + 1], instrs[pos + 2], instrs[pos + 3], instrs[pos + 4]) {
    (@lib.Call(func_idx), const_instr, @lib.Select(_), if_instr) =>
      sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) &&
      sgo_const_instr(const_instr) != None &&
      (
        sgo_if_is_read_only_to_write_set(if_instr, idx) ||
        (
          sgo_is_return_guard(if_instr) &&
          sgo_if_return_tail_matches(instrs, pos + 5, idx)
        )
      )
    _ => false
  }
}

///|
fn sgo_compare_operand_independent_call_read_at(
  instrs : Array[@lib.Instruction],
  pos : Int,
  idx : @lib.GlobalIdx,
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> Bool {
  // Narrow FlowScanner subset: a zero-param/result call supplies one compare
  // operand independently of the guarded global, so the global-derived value
  // reaches only the final same-global guarded write or if-return tail.
  match instrs[pos] {
    @lib.GlobalGet(get_idx) if get_idx == idx => ()
    _ => return false
  }
  if pos + 3 < instrs.length() {
    match (instrs[pos + 1], instrs[pos + 2], instrs[pos + 3]) {
      (@lib.Call(func_idx), compare, if_instr) if sgo_is_compare_instr(compare) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) =>
        if sgo_if_is_read_only_to_write_set(if_instr, idx) ||
          (
            sgo_is_return_guard(if_instr) &&
            sgo_if_return_tail_matches(instrs, pos + 4, idx)
          ) {
          return true
        }
      _ => ()
    }
  }
  if pos > 0 && pos + 2 < instrs.length() {
    match (instrs[pos - 1], instrs[pos + 1], instrs[pos + 2]) {
      (@lib.Call(func_idx), compare, if_instr) if sgo_is_compare_instr(compare) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) =>
        if sgo_if_is_read_only_to_write_set(if_instr, idx) ||
          (
            sgo_is_return_guard(if_instr) &&
            sgo_if_return_tail_matches(instrs, pos + 3, idx)
          ) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn sgo_is_nontrapping_i32_binary_flow_instr(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.I32Add
    | @lib.I32Sub
    | @lib.I32Mul
    | @lib.I32And
    | @lib.I32Or
    | @lib.I32Xor
    | @lib.I32Shl
    | @lib.I32ShrS
    | @lib.I32ShrU
    | @lib.I32Rotl
    | @lib.I32Rotr => true
    _ => false
  }
}

///|
fn sgo_i32_call_binary_pure_suffix_depth_after(
  instr : @lib.Instruction,
  depth : Int,
) -> Int? {
  // Narrow source-backed suffixes: one nontrapping pure i32 parent above the
  // nontrapping i32 binary call sibling. Broader pure suffix chains still need
  // separate probes and tests before admission.
  match instr {
    @lib.I32Eqz | @lib.I32Clz | @lib.I32Ctz | @lib.I32Popcnt =>
      if depth >= 1 {
        Some(depth)
      } else {
        None
      }
    _ => None
  }
}

///|
fn sgo_i32_pure_suffix_tail_matches(
  instrs : Array[@lib.Instruction],
  start : Int,
  idx : @lib.GlobalIdx,
) -> Bool {
  // One source-backed suffix may also be a constant-fed i32 equality compare.
  // This is intentionally limited to eq/ne and exactly one constant operand.
  if start + 2 < instrs.length() &&
    sgo_const_instr(instrs[start]) != None &&
    sgo_is_compare_instr(instrs[start + 1]) {
    let tail = instrs[start + 2]
    return sgo_if_is_read_only_to_write_set(tail, idx) ||
      (
        sgo_is_return_guard(tail) &&
        sgo_if_return_tail_matches(instrs, start + 3, idx)
      )
  }
  let mut depth = 1
  let mut suffix_count = 0
  for scan = start; scan < instrs.length(); scan = scan + 1 {
    let instr = instrs[scan]
    match instr {
      @lib.If(_, _, _) if depth == 1 =>
        return sgo_if_is_read_only_to_write_set(instr, idx) ||
          (
            sgo_is_return_guard(instr) &&
            sgo_if_return_tail_matches(instrs, scan + 1, idx)
          )
      _ => {
        if suffix_count >= 1 {
          return false
        }
        match sgo_i32_call_binary_pure_suffix_depth_after(instr, depth) {
          Some(next_depth) => {
            suffix_count = suffix_count + 1
            depth = next_depth
          }
          None => return false
        }
      }
    }
  }
  false
}

///|
fn sgo_i32_pure_suffix_empty_if_end(
  instrs : Array[@lib.Instruction],
  start : Int,
) -> Int? {
  if start + 2 < instrs.length() &&
    sgo_const_instr(instrs[start]) != None &&
    sgo_is_compare_instr(instrs[start + 1]) &&
    sgo_instr_is_empty_void_if(instrs[start + 2]) {
    return Some(start + 3)
  }
  let mut depth = 1
  let mut suffix_count = 0
  for scan = start; scan < instrs.length(); scan = scan + 1 {
    let instr = instrs[scan]
    if depth == 1 && sgo_instr_is_empty_void_if(instr) {
      return Some(scan + 1)
    }
    if suffix_count >= 1 {
      return None
    }
    match sgo_i32_call_binary_pure_suffix_depth_after(instr, depth) {
      Some(next_depth) => {
        suffix_count = suffix_count + 1
        depth = next_depth
      }
      None => return None
    }
  }
  None
}

///|
fn sgo_i32_pure_suffix_if_return_drop_end(
  instrs : Array[@lib.Instruction],
  start : Int,
) -> Int? {
  if start + 4 < instrs.length() &&
    sgo_const_instr(instrs[start]) != None &&
    sgo_is_compare_instr(instrs[start + 1]) &&
    sgo_is_return_guard(instrs[start + 2]) &&
    sgo_const_instr(instrs[start + 3]) != None &&
    instrs[start + 4] == @lib.Instruction::drop() {
    return Some(start + 5)
  }
  let mut depth = 1
  let mut suffix_count = 0
  for scan = start; scan < instrs.length(); scan = scan + 1 {
    let instr = instrs[scan]
    if depth == 1 && sgo_is_return_guard(instr) {
      if scan + 2 < instrs.length() &&
        sgo_const_instr(instrs[scan + 1]) != None &&
        instrs[scan + 2] == @lib.Instruction::drop() {
        return Some(scan + 3)
      }
      return None
    }
    if suffix_count >= 1 {
      return None
    }
    match sgo_i32_call_binary_pure_suffix_depth_after(instr, depth) {
      Some(next_depth) => {
        suffix_count = suffix_count + 1
        depth = next_depth
      }
      None => return None
    }
  }
  None
}

///|
fn sgo_pure_i32_binary_operand_independent_call_read_at(
  instrs : Array[@lib.Instruction],
  pos : Int,
  idx : @lib.GlobalIdx,
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> Bool {
  // Narrow FlowScanner subset: an independent zero-param/one-result call
  // supplies the other operand to a nontrapping pure i32 binary operator while
  // the guarded global supplies one operand. The guarded value reaches only the
  // pure operator and final same-global guarded write / if-return tail; it must
  // not flow into the call itself. Trapping div/rem operators stay excluded.
  match instrs[pos] {
    @lib.GlobalGet(get_idx) if get_idx == idx => ()
    _ => return false
  }
  if pos + 2 < instrs.length() {
    match (instrs[pos + 1], instrs[pos + 2]) {
      (@lib.Call(func_idx), op) if sgo_is_nontrapping_i32_binary_flow_instr(op) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) =>
        if sgo_i32_pure_suffix_tail_matches(instrs, pos + 3, idx) {
          return true
        }
      _ => ()
    }
  }
  if pos > 0 && pos + 1 < instrs.length() {
    match (instrs[pos - 1], instrs[pos + 1]) {
      (@lib.Call(func_idx), op) if sgo_is_nontrapping_i32_binary_flow_instr(op) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) =>
        if sgo_i32_pure_suffix_tail_matches(instrs, pos + 2, idx) {
          return true
        }
      _ => ()
    }
  }
  // Constant-first equality comparison around the binary result. These two
  // stack orders are separate from the result-first suffix above because the
  // constant is already below the guarded expression when we reach the get.
  if pos > 0 &&
    pos + 3 < instrs.length() &&
    sgo_const_instr(instrs[pos - 1]) != None {
    match (instrs[pos + 1], instrs[pos + 2], instrs[pos + 3]) {
      (@lib.Call(func_idx), op, compare) if sgo_is_nontrapping_i32_binary_flow_instr(
          op,
        ) &&
        sgo_is_compare_instr(compare) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) =>
        if sgo_i32_pure_suffix_tail_matches(instrs, pos + 4, idx) {
          return true
        }
      _ => ()
    }
  }
  if pos > 1 &&
    pos + 2 < instrs.length() &&
    sgo_const_instr(instrs[pos - 2]) != None {
    match (instrs[pos - 1], instrs[pos + 1], instrs[pos + 2]) {
      (@lib.Call(func_idx), op, compare) if sgo_is_nontrapping_i32_binary_flow_instr(
          op,
        ) &&
        sgo_is_compare_instr(compare) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) =>
        if sgo_i32_pure_suffix_tail_matches(instrs, pos + 3, idx) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn sgo_is_nontrapping_i64_binary_flow_instr(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.I64Add
    | @lib.I64Sub
    | @lib.I64Mul
    | @lib.I64And
    | @lib.I64Or
    | @lib.I64Xor
    | @lib.I64Shl
    | @lib.I64ShrS
    | @lib.I64ShrU
    | @lib.I64Rotl
    | @lib.I64Rotr => true
    _ => false
  }
}

///|
fn sgo_is_i64_equality_compare(instr : @lib.Instruction) -> Bool {
  instr == @lib.Instruction::i64_eq() || instr == @lib.Instruction::i64_ne()
}

///|
fn sgo_is_i64_const(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.I64Const(_) => true
    _ => false
  }
}

///|
fn sgo_i64_pure_suffix_tail_matches(
  instrs : Array[@lib.Instruction],
  start : Int,
  idx : @lib.GlobalIdx,
) -> Bool {
  // Narrow source-backed i64 suffixes: one i64.eqz, or one constant-fed
  // i64.eq/ne. A direct tail is accepted only for the constant-first compare
  // order, where the comparison instruction was already visited by the caller.
  // Broader i64 chains and relational comparisons remain excluded.
  if start < instrs.length() {
    let tail = instrs[start]
    if sgo_if_is_read_only_to_write_set(tail, idx) ||
      (
        sgo_is_return_guard(tail) &&
        sgo_if_return_tail_matches(instrs, start + 1, idx)
      ) {
      return true
    }
  }
  if start + 1 < instrs.length() && instrs[start] == @lib.Instruction::i64_eqz() {
    let tail = instrs[start + 1]
    return sgo_if_is_read_only_to_write_set(tail, idx) ||
      (
        sgo_is_return_guard(tail) &&
        sgo_if_return_tail_matches(instrs, start + 2, idx)
      )
  }
  if start + 2 < instrs.length() {
    match (instrs[start], instrs[start + 1]) {
      (@lib.I64Const(_), compare) if sgo_is_i64_equality_compare(compare) => {
        let tail = instrs[start + 2]
        return sgo_if_is_read_only_to_write_set(tail, idx) ||
          (
            sgo_is_return_guard(tail) &&
            sgo_if_return_tail_matches(instrs, start + 3, idx)
          )
      }
      _ => ()
    }
  }
  false
}

///|
fn sgo_i64_pure_suffix_empty_if_end(
  instrs : Array[@lib.Instruction],
  start : Int,
) -> Int? {
  if start + 1 < instrs.length() &&
    instrs[start] == @lib.Instruction::i64_eqz() &&
    sgo_instr_is_empty_void_if(instrs[start + 1]) {
    return Some(start + 2)
  }
  if start + 2 < instrs.length() {
    match (instrs[start], instrs[start + 1]) {
      (@lib.I64Const(_), compare) if sgo_is_i64_equality_compare(compare) &&
        sgo_instr_is_empty_void_if(instrs[start + 2]) => return Some(start + 3)
      _ => ()
    }
  }
  None
}

///|
fn sgo_i64_pure_suffix_if_return_drop_end(
  instrs : Array[@lib.Instruction],
  start : Int,
) -> Int? {
  if start + 3 < instrs.length() &&
    instrs[start] == @lib.Instruction::i64_eqz() &&
    sgo_is_return_guard(instrs[start + 1]) &&
    sgo_const_instr(instrs[start + 2]) != None &&
    instrs[start + 3] == @lib.Instruction::drop() {
    return Some(start + 4)
  }
  if start + 4 < instrs.length() {
    match (instrs[start], instrs[start + 1]) {
      (@lib.I64Const(_), compare) if sgo_is_i64_equality_compare(compare) &&
        sgo_is_return_guard(instrs[start + 2]) &&
        sgo_const_instr(instrs[start + 3]) != None &&
        instrs[start + 4] == @lib.Instruction::drop() => return Some(start + 5)
      _ => ()
    }
  }
  None
}

///|
fn sgo_pure_i64_binary_operand_independent_call_read_at(
  instrs : Array[@lib.Instruction],
  pos : Int,
  idx : @lib.GlobalIdx,
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> Bool {
  // Narrow FlowScanner subset: an independent zero-param/one-result call and
  // the guarded i64 global feed a nontrapping pure i64 binary parent. The
  // result then reaches exactly one i64.eqz or constant-fed i64.eq/ne before
  // the same-global guarded write / if-return tail.
  match instrs[pos] {
    @lib.GlobalGet(get_idx) if get_idx == idx => ()
    _ => return false
  }
  if pos + 2 < instrs.length() {
    match (instrs[pos + 1], instrs[pos + 2]) {
      (@lib.Call(func_idx), op) if sgo_is_nontrapping_i64_binary_flow_instr(op) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) =>
        if sgo_i64_pure_suffix_tail_matches(instrs, pos + 3, idx) {
          return true
        }
      _ => ()
    }
  }
  if pos > 0 && pos + 1 < instrs.length() {
    match (instrs[pos - 1], instrs[pos + 1]) {
      (@lib.Call(func_idx), op) if sgo_is_nontrapping_i64_binary_flow_instr(op) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) =>
        if sgo_i64_pure_suffix_tail_matches(instrs, pos + 2, idx) {
          return true
        }
      _ => ()
    }
  }
  // Constant-first equality around the binary result, for both binary operand
  // orders. The comparison constant is already below the guarded expression.
  if pos > 0 && pos + 3 < instrs.length() && sgo_is_i64_const(instrs[pos - 1]) {
    match (instrs[pos + 1], instrs[pos + 2], instrs[pos + 3]) {
      (@lib.Call(func_idx), op, compare) if sgo_is_nontrapping_i64_binary_flow_instr(
          op,
        ) &&
        sgo_is_i64_equality_compare(compare) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) =>
        if sgo_i64_pure_suffix_tail_matches(instrs, pos + 4, idx) {
          return true
        }
      _ => ()
    }
  }
  if pos > 1 && pos + 2 < instrs.length() && sgo_is_i64_const(instrs[pos - 2]) {
    match (instrs[pos - 1], instrs[pos + 1], instrs[pos + 2]) {
      (@lib.Call(func_idx), op, compare) if sgo_is_nontrapping_i64_binary_flow_instr(
          op,
        ) &&
        sgo_is_i64_equality_compare(compare) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) =>
        if sgo_i64_pure_suffix_tail_matches(instrs, pos + 3, idx) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn sgo_is_f32_binary_flow_instr(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.F32Add
    | @lib.F32Sub
    | @lib.F32Mul
    | @lib.F32Div
    | @lib.F32Min
    | @lib.F32Max
    | @lib.F32Copysign => true
    _ => false
  }
}

///|
fn sgo_is_f64_binary_flow_instr(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.F64Add
    | @lib.F64Sub
    | @lib.F64Mul
    | @lib.F64Div
    | @lib.F64Min
    | @lib.F64Max
    | @lib.F64Copysign => true
    _ => false
  }
}

///|
fn sgo_is_f32_compare_instr(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.F32Eq
    | @lib.F32Ne
    | @lib.F32Lt
    | @lib.F32Gt
    | @lib.F32Le
    | @lib.F32Ge => true
    _ => false
  }
}

///|
fn sgo_is_f64_compare_instr(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.F64Eq
    | @lib.F64Ne
    | @lib.F64Lt
    | @lib.F64Gt
    | @lib.F64Le
    | @lib.F64Ge => true
    _ => false
  }
}

///|
fn sgo_is_i32_flow_compare_instr(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.I32Eq
    | @lib.I32Ne
    | @lib.I32LtS
    | @lib.I32LtU
    | @lib.I32GtS
    | @lib.I32GtU
    | @lib.I32LeS
    | @lib.I32LeU
    | @lib.I32GeS
    | @lib.I32GeU => true
    _ => false
  }
}

///|
fn sgo_is_i64_flow_compare_instr(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.I64Eq
    | @lib.I64Ne
    | @lib.I64LtS
    | @lib.I64LtU
    | @lib.I64GtS
    | @lib.I64GtU
    | @lib.I64LeS
    | @lib.I64LeU
    | @lib.I64GeS
    | @lib.I64GeU => true
    _ => false
  }
}

///|
fn sgo_scalar_const_kind(instr : @lib.Instruction) -> SgoScalarFlowKind? {
  match instr {
    @lib.I32Const(_) => Some(SgoFlowI32)
    @lib.I64Const(_) => Some(SgoFlowI64)
    @lib.F32Const(_) => Some(SgoFlowF32)
    @lib.F64Const(_) => Some(SgoFlowF64)
    _ => None
  }
}

///|
fn sgo_scalar_same_type_unary_result(
  instr : @lib.Instruction,
  kind : SgoScalarFlowKind,
) -> SgoScalarFlowKind? {
  match (kind, instr) {
    (SgoFlowI32, @lib.I32Clz | @lib.I32Ctz | @lib.I32Popcnt) => Some(SgoFlowI32)
    (SgoFlowI64, @lib.I64Clz | @lib.I64Ctz | @lib.I64Popcnt) => Some(SgoFlowI64)
    (
      SgoFlowF32,
      @lib.F32Abs
      | @lib.F32Neg
      | @lib.F32Ceil
      | @lib.F32Floor
      | @lib.F32Trunc
      | @lib.F32Nearest
      | @lib.F32Sqrt,
    ) => Some(SgoFlowF32)
    (
      SgoFlowF64,
      @lib.F64Abs
      | @lib.F64Neg
      | @lib.F64Ceil
      | @lib.F64Floor
      | @lib.F64Trunc
      | @lib.F64Nearest
      | @lib.F64Sqrt,
    ) => Some(SgoFlowF64)
    _ => None
  }
}

///|
fn sgo_scalar_unary_result(
  instr : @lib.Instruction,
  kind : SgoScalarFlowKind,
) -> SgoScalarFlowKind? {
  match sgo_scalar_same_type_unary_result(instr, kind) {
    Some(next) => return Some(next)
    None => ()
  }
  match (kind, instr) {
    (SgoFlowI32, @lib.I32Eqz) => Some(SgoFlowI32)
    (SgoFlowI64, @lib.I64Eqz) => Some(SgoFlowI32)
    (SgoFlowI64, @lib.I32WrapI64) => Some(SgoFlowI32)
    (SgoFlowI32, @lib.I64ExtendI32S | @lib.I64ExtendI32U) => Some(SgoFlowI64)
    (
      SgoFlowI32,
      @lib.F32ConvertI32S
      | @lib.F32ConvertI32U
      | @lib.F32ReinterpretI32,
    ) => Some(SgoFlowF32)
    (SgoFlowI32, @lib.F64ConvertI32S | @lib.F64ConvertI32U) => Some(SgoFlowF64)
    (SgoFlowI64, @lib.F32ConvertI64S | @lib.F32ConvertI64U) => Some(SgoFlowF32)
    (
      SgoFlowI64,
      @lib.F64ConvertI64S
      | @lib.F64ConvertI64U
      | @lib.F64ReinterpretI64,
    ) => Some(SgoFlowF64)
    (
      SgoFlowF32,
      @lib.I32ReinterpretF32
      | @lib.I32TruncSatF32S
      | @lib.I32TruncSatF32U,
    ) => Some(SgoFlowI32)
    (SgoFlowF32, @lib.I64TruncSatF32S | @lib.I64TruncSatF32U) =>
      Some(SgoFlowI64)
    (SgoFlowF32, @lib.F64PromoteF32) => Some(SgoFlowF64)
    (
      SgoFlowF64,
      @lib.I64ReinterpretF64
      | @lib.I64TruncSatF64S
      | @lib.I64TruncSatF64U,
    ) => Some(SgoFlowI64)
    (SgoFlowF64, @lib.I32TruncSatF64S | @lib.I32TruncSatF64U) =>
      Some(SgoFlowI32)
    (SgoFlowF64, @lib.F32DemoteF64) => Some(SgoFlowF32)
    _ => None
  }
}

///|
fn sgo_scalar_trapping_unary_result(
  instr : @lib.Instruction,
  kind : SgoScalarFlowKind,
) -> SgoScalarFlowKind? {
  match (kind, instr) {
    (SgoFlowF32, @lib.I32TruncF32S | @lib.I32TruncF32U) => Some(SgoFlowI32)
    (SgoFlowF64, @lib.I32TruncF64S | @lib.I32TruncF64U) => Some(SgoFlowI32)
    (SgoFlowF32, @lib.I64TruncF32S | @lib.I64TruncF32U) => Some(SgoFlowI64)
    (SgoFlowF64, @lib.I64TruncF64S | @lib.I64TruncF64U) => Some(SgoFlowI64)
    _ => None
  }
}

///|
fn sgo_scalar_any_unary_result(
  instr : @lib.Instruction,
  kind : SgoScalarFlowKind,
) -> SgoScalarFlowKind? {
  match sgo_scalar_unary_result(instr, kind) {
    Some(next) => Some(next)
    None => sgo_scalar_trapping_unary_result(instr, kind)
  }
}

///|
fn sgo_is_any_scalar_unary(instr : @lib.Instruction) -> Bool {
  sgo_scalar_any_unary_result(instr, SgoFlowI32) != None ||
  sgo_scalar_any_unary_result(instr, SgoFlowI64) != None ||
  sgo_scalar_any_unary_result(instr, SgoFlowF32) != None ||
  sgo_scalar_any_unary_result(instr, SgoFlowF64) != None
}

///|
fn sgo_scalar_load_result_kind(instr : @lib.Instruction) -> SgoScalarFlowKind? {
  match instr {
    @lib.I32Load(_)
    | @lib.I32Load8S(_)
    | @lib.I32Load8U(_)
    | @lib.I32Load16S(_)
    | @lib.I32Load16U(_) => Some(SgoFlowI32)
    @lib.I64Load(_)
    | @lib.I64Load8S(_)
    | @lib.I64Load8U(_)
    | @lib.I64Load16S(_)
    | @lib.I64Load16U(_)
    | @lib.I64Load32S(_)
    | @lib.I64Load32U(_) => Some(SgoFlowI64)
    @lib.F32Load(_) => Some(SgoFlowF32)
    @lib.F64Load(_) => Some(SgoFlowF64)
    _ => None
  }
}

///|
fn sgo_scalar_pure_expr_result_kind(
  instrs : Array[@lib.Instruction],
) -> SgoScalarFlowKind? {
  if instrs.length() == 0 {
    return None
  }
  let mut kind = match sgo_scalar_const_kind(instrs[0]) {
    Some(kind) => kind
    None => return None
  }
  for pos = 1; pos < instrs.length(); pos = pos + 1 {
    match sgo_scalar_unary_result(instrs[pos], kind) {
      Some(next_kind) => kind = next_kind
      None => return None
    }
  }
  Some(kind)
}

///|
fn sgo_scalar_result_block_effect_prefix(
  body : Array[@lib.Instruction],
) -> (SgoScalarFlowKind, Int)? {
  match body {
    [value, @lib.LocalSet(_), result] if sgo_local_effect_value_is_independent(
        value,
      ) =>
      match sgo_scalar_const_kind(result) {
        Some(result_kind) => Some((result_kind, 2))
        None => None
      }
    [value, @lib.LocalTee(_), @lib.Drop, result] if sgo_local_effect_value_is_independent(
        value,
      ) =>
      match sgo_scalar_const_kind(result) {
        Some(result_kind) => Some((result_kind, 3))
        None => None
      }
    [ref_value, grow_delta, @lib.TableGrow(_), @lib.Drop, result] if sgo_table_grow_arg_is_independent(
        ref_value,
      ) &&
      sgo_table_grow_arg_is_independent(grow_delta) =>
      match sgo_scalar_const_kind(result) {
        Some(result_kind) => Some((result_kind, 3))
        None => None
      }
    [delta, @lib.MemoryGrow(_), @lib.Drop, result] if sgo_memory_grow_arg_is_independent(
        delta,
      ) =>
      match sgo_scalar_const_kind(result) {
        Some(result_kind) => Some((result_kind, 2))
        None => None
      }
    [left, right, @lib.I32Add, @lib.MemoryGrow(_), @lib.Drop, result] if sgo_i32_add_grow_arg_is_independent(
        left,
        right,
        @lib.Instruction::i32_add(),
      ) =>
      match sgo_scalar_const_kind(result) {
        Some(result_kind) => Some((result_kind, 4))
        None => None
      }
    _ => None
  }
}

///|
fn sgo_scalar_result_if_kind(instr : @lib.Instruction) -> SgoScalarFlowKind? {
  match instr {
    @lib.If(@lib.ValTypeBlockType(value_type), then_body, Some(else_body)) =>
      match sgo_scalar_flow_kind(value_type) {
        Some(result_kind) =>
          if sgo_scalar_pure_expr_result_kind(then_body) == Some(result_kind) &&
            sgo_scalar_pure_expr_result_kind(else_body) == Some(result_kind) {
            Some(result_kind)
          } else {
            None
          }
        None => None
      }
    _ => None
  }
}

///|
fn sgo_scalar_independent_fragment_starts_at(
  instrs : Array[@lib.Instruction],
  pos : Int,
) -> Bool {
  if pos < 0 || pos >= instrs.length() {
    return false
  }
  match instrs[pos] {
    @lib.Call(_) | @lib.MemorySize(_) | @lib.Block(_, _) | @lib.Loop(_, _) =>
      true
    @lib.LocalGet(_) | @lib.I32Const(_) if pos + 1 < instrs.length() &&
      sgo_scalar_result_if_kind(instrs[pos + 1]) != None => true
    @lib.I32Const(_) if pos + 1 < instrs.length() =>
      sgo_scalar_load_result_kind(instrs[pos + 1]) != None
    _ => false
  }
}

///|
fn sgo_scalar_independent_fragment_can_end_at(
  instrs : Array[@lib.Instruction],
  end_pos : Int,
) -> Bool {
  if end_pos <= 0 {
    return false
  }
  match instrs[end_pos - 1] {
    @lib.Call(_)
    | @lib.MemorySize(_)
    | @lib.Block(_, _)
    | @lib.Loop(_, _)
    | @lib.If(_, _, _) => true
    @lib.LocalTee(_) => false
    instr =>
      sgo_scalar_load_result_kind(instr) != None ||
      sgo_is_any_scalar_unary(instr)
  }
}

///|
fn sgo_scalar_independent_fragment_at(
  instrs : Array[@lib.Instruction],
  pos : Int,
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> SgoScalarIndependentFragment? {
  if pos < 0 || pos >= instrs.length() {
    return None
  }
  match instrs[pos] {
    @lib.Call(_) | @lib.MemorySize(_) if pos + 1 < instrs.length() =>
      match instrs[pos + 1] {
        @lib.LocalTee(_) | @lib.LocalSet(_) | @lib.GlobalSet(_) => return None
        _ => ()
      }
    @lib.I32Const(_) if pos + 2 < instrs.length() &&
      sgo_scalar_load_result_kind(instrs[pos + 1]) != None =>
      match instrs[pos + 2] {
        @lib.LocalTee(_) | @lib.LocalSet(_) | @lib.GlobalSet(_) => return None
        _ => ()
      }
    _ => ()
  }
  match instrs[pos] {
    @lib.LocalGet(_) | @lib.I32Const(_) if pos + 1 < instrs.length() =>
      match sgo_scalar_result_if_kind(instrs[pos + 1]) {
        Some(result_kind) =>
          Some({
            result_kind,
            start_pos: pos,
            next_pos: pos + 2,
            replay_end_pos: pos,
            replay_nested_block: false,
          })
        None =>
          match instrs[pos] {
            @lib.I32Const(_) =>
              match sgo_scalar_load_result_kind(instrs[pos + 1]) {
                Some(result_kind) =>
                  Some({
                    result_kind,
                    start_pos: pos,
                    next_pos: pos + 2,
                    replay_end_pos: pos + 2,
                    replay_nested_block: false,
                  })
                None => None
              }
            _ => None
          }
      }
    @lib.Block(@lib.ValTypeBlockType(value_type), @lib.Expr(body)) =>
      match sgo_scalar_flow_kind(value_type) {
        Some(result_kind) =>
          match sgo_scalar_pure_expr_result_kind(body) {
            Some(body_kind) if body_kind == result_kind =>
              Some({
                result_kind,
                start_pos: pos,
                next_pos: pos + 1,
                replay_end_pos: pos,
                replay_nested_block: false,
              })
            _ =>
              match
                sgo_scalar_independent_fragment_at(
                  body, 0, mod_, func_type_indices,
                ) {
                Some(nested) => {
                  let mut kind = nested.result_kind
                  let mut scan = nested.next_pos
                  while scan < body.length() {
                    match sgo_scalar_any_unary_result(body[scan], kind) {
                      Some(next_kind) => {
                        kind = next_kind
                        scan = scan + 1
                      }
                      None => break
                    }
                  }
                  if scan == body.length() && kind == result_kind {
                    Some({
                      result_kind,
                      start_pos: pos,
                      next_pos: pos + 1,
                      replay_end_pos: pos,
                      replay_nested_block: true,
                    })
                  } else {
                    None
                  }
                }
                None =>
                  match sgo_scalar_result_block_effect_prefix(body) {
                    Some((body_kind, _)) if body_kind == result_kind =>
                      Some({
                        result_kind,
                        start_pos: pos,
                        next_pos: pos + 1,
                        replay_end_pos: pos,
                        replay_nested_block: true,
                      })
                    _ if !sgo_instrs_may_reference_global(body) =>
                      Some({
                        result_kind,
                        start_pos: pos,
                        next_pos: pos + 1,
                        replay_end_pos: pos + 1,
                        replay_nested_block: false,
                      })
                    _ => None
                  }
              }
          }
        None => None
      }
    @lib.Loop(@lib.ValTypeBlockType(value_type), @lib.Expr(body)) =>
      match sgo_scalar_flow_kind(value_type) {
        Some(result_kind) if !sgo_instrs_may_reference_global(body) =>
          Some({
            result_kind,
            start_pos: pos,
            next_pos: pos + 1,
            replay_end_pos: pos + 1,
            replay_nested_block: false,
          })
        _ => None
      }
    @lib.Call(func_idx) =>
      match
        sgo_call_no_params_scalar_result_kind(mod_, func_type_indices, func_idx) {
        Some(SgoFlowI32) if pos + 1 < instrs.length() =>
          match sgo_scalar_result_if_kind(instrs[pos + 1]) {
            Some(result_kind) =>
              Some({
                result_kind,
                start_pos: pos,
                next_pos: pos + 2,
                replay_end_pos: pos + 1,
                replay_nested_block: false,
              })
            None =>
              Some({
                result_kind: SgoFlowI32,
                start_pos: pos,
                next_pos: pos + 1,
                replay_end_pos: pos + 1,
                replay_nested_block: false,
              })
          }
        Some(result_kind) =>
          Some({
            result_kind,
            start_pos: pos,
            next_pos: pos + 1,
            replay_end_pos: pos + 1,
            replay_nested_block: false,
          })
        None => None
      }
    @lib.MemorySize(_) =>
      Some({
        result_kind: SgoFlowI32,
        start_pos: pos,
        next_pos: pos + 1,
        replay_end_pos: pos,
        replay_nested_block: false,
      })
    _ => None
  }
}

///|
fn sgo_scalar_fragment_cleanup_replay(
  instrs : Array[@lib.Instruction],
  fragment : SgoScalarIndependentFragment,
  unary_end : Int,
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> Array[@lib.Instruction] {
  let replay : Array[@lib.Instruction] = []
  if fragment.replay_nested_block {
    match instrs[fragment.start_pos] {
      @lib.Block(_, @lib.Expr(body)) =>
        match
          sgo_scalar_independent_fragment_at(body, 0, mod_, func_type_indices) {
          Some(nested) =>
            replay.append(
              sgo_scalar_fragment_cleanup_replay(
                body,
                nested,
                body.length(),
                mod_,
                func_type_indices,
              ),
            )
          None =>
            match sgo_scalar_result_block_effect_prefix(body) {
              Some((_, replay_end)) =>
                match body {
                  [value, @lib.LocalSet(local_idx), _]
                  | [value, @lib.LocalTee(local_idx), @lib.Drop, _] => {
                    replay.push(value)
                    replay.push(@lib.Instruction::local_tee(local_idx))
                  }
                  _ =>
                    for replay_pos = 0
                        replay_pos < replay_end
                        replay_pos = replay_pos + 1 {
                      replay.push(body[replay_pos])
                    }
                }
              None => ()
            }
        }
      _ => ()
    }
  } else {
    for replay_pos = fragment.start_pos
        replay_pos < fragment.replay_end_pos
        replay_pos = replay_pos + 1 {
      replay.push(instrs[replay_pos])
    }
  }
  let mut kind = fragment.result_kind
  for scan = fragment.next_pos; scan < unary_end; scan = scan + 1 {
    match sgo_scalar_unary_result(instrs[scan], kind) {
      Some(next_kind) => kind = next_kind
      None =>
        match sgo_scalar_trapping_unary_result(instrs[scan], kind) {
          Some(next_kind) => {
            replay.push(instrs[scan])
            kind = next_kind
          }
          None => ()
        }
    }
  }
  replay
}

///|
fn sgo_scalar_independent_fragment_before(
  instrs : Array[@lib.Instruction],
  end_pos : Int,
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> (Int, SgoScalarIndependentFragment)? {
  if end_pos > 0 {
    match
      sgo_scalar_independent_fragment_at(
        instrs,
        end_pos - 1,
        mod_,
        func_type_indices,
      ) {
      Some(fragment) if fragment.next_pos == end_pos =>
        return Some((end_pos - 1, fragment))
      _ => ()
    }
  }
  if end_pos > 1 {
    match
      sgo_scalar_independent_fragment_at(
        instrs,
        end_pos - 2,
        mod_,
        func_type_indices,
      ) {
      Some(fragment) if fragment.next_pos == end_pos =>
        return Some((end_pos - 2, fragment))
      _ => ()
    }
  }
  None
}

///|
fn sgo_scalar_binary_result(
  instr : @lib.Instruction,
  kind : SgoScalarFlowKind,
) -> SgoScalarFlowKind? {
  match kind {
    SgoFlowI32 =>
      if sgo_is_nontrapping_i32_binary_flow_instr(instr) {
        Some(SgoFlowI32)
      } else if sgo_is_i32_flow_compare_instr(instr) {
        Some(SgoFlowI32)
      } else {
        None
      }
    SgoFlowI64 =>
      if sgo_is_nontrapping_i64_binary_flow_instr(instr) {
        Some(SgoFlowI64)
      } else if sgo_is_i64_flow_compare_instr(instr) {
        Some(SgoFlowI32)
      } else {
        None
      }
    SgoFlowF32 =>
      if sgo_is_f32_binary_flow_instr(instr) {
        Some(SgoFlowF32)
      } else if sgo_is_f32_compare_instr(instr) {
        Some(SgoFlowI32)
      } else {
        None
      }
    SgoFlowF64 =>
      if sgo_is_f64_binary_flow_instr(instr) {
        Some(SgoFlowF64)
      } else if sgo_is_f64_compare_instr(instr) {
        Some(SgoFlowI32)
      } else {
        None
      }
  }
}

///|
fn sgo_float_const_matches_binary(
  const_instr : @lib.Instruction,
  op : @lib.Instruction,
) -> Bool {
  match const_instr {
    @lib.F32Const(_) => sgo_is_f32_binary_flow_instr(op)
    @lib.F64Const(_) => sgo_is_f64_binary_flow_instr(op)
    _ => false
  }
}

///|
fn sgo_float_binary_compare_types_match(
  op : @lib.Instruction,
  compare_const : @lib.Instruction,
  compare : @lib.Instruction,
) -> Bool {
  match compare_const {
    @lib.F32Const(_) =>
      sgo_is_f32_binary_flow_instr(op) && sgo_is_f32_compare_instr(compare)
    @lib.F64Const(_) =>
      sgo_is_f64_binary_flow_instr(op) && sgo_is_f64_compare_instr(compare)
    _ => false
  }
}

///|
fn sgo_scalar_flow_guard_tail_matches(
  instrs : Array[@lib.Instruction],
  tail_pos : Int,
  idx : @lib.GlobalIdx,
  kind : SgoScalarFlowKind,
) -> Bool {
  if kind != SgoFlowI32 || tail_pos >= instrs.length() {
    return false
  }
  let tail = instrs[tail_pos]
  sgo_if_is_read_only_to_write_set(tail, idx) ||
  (
    sgo_is_return_guard(tail) &&
    sgo_if_return_tail_matches(instrs, tail_pos + 1, idx)
  )
}

///|
fn sgo_scalar_const_prefix_start(
  instrs : Array[@lib.Instruction],
  end : Int,
) -> Int {
  let mut start = end
  while start > 0 && sgo_scalar_const_kind(instrs[start - 1]) != None {
    start = start - 1
  }
  start
}

///|
fn sgo_scalar_pure_suffix_with_prefix_tail_matches(
  instrs : Array[@lib.Instruction],
  start : Int,
  idx : @lib.GlobalIdx,
  initial_kind : SgoScalarFlowKind,
  prefix_start : Int,
  prefix_end : Int,
) -> Bool {
  let mut scan = start
  let mut kind = initial_kind
  let mut prefix_scan = prefix_end
  while scan < instrs.length() {
    if prefix_scan == prefix_start &&
      sgo_scalar_flow_guard_tail_matches(instrs, scan, idx, kind) {
      return true
    }
    match sgo_scalar_unary_result(instrs[scan], kind) {
      Some(next_kind) => {
        kind = next_kind
        scan = scan + 1
        continue
      }
      None => ()
    }
    if scan + 1 < instrs.length() &&
      sgo_scalar_const_kind(instrs[scan]) == Some(kind) {
      match sgo_scalar_binary_result(instrs[scan + 1], kind) {
        Some(next_kind) => {
          kind = next_kind
          scan = scan + 2
          continue
        }
        None => ()
      }
    }
    if prefix_scan > prefix_start &&
      sgo_scalar_const_kind(instrs[prefix_scan - 1]) == Some(kind) {
      match sgo_scalar_binary_result(instrs[scan], kind) {
        Some(next_kind) => {
          prefix_scan = prefix_scan - 1
          kind = next_kind
          scan = scan + 1
          continue
        }
        None => ()
      }
    }
    return false
  }
  false
}

///|
fn sgo_scalar_pure_suffix_cleanup_end(
  instrs : Array[@lib.Instruction],
  start : Int,
  initial_kind : SgoScalarFlowKind,
  if_return : Bool,
  prefix_start : Int,
  prefix_end : Int,
) -> Int? {
  let mut scan = start
  let mut kind = initial_kind
  let mut prefix_scan = prefix_end
  while scan < instrs.length() {
    if prefix_scan == prefix_start && kind == SgoFlowI32 {
      if !if_return && sgo_instr_is_empty_void_if(instrs[scan]) {
        return Some(scan + 1)
      }
      if if_return &&
        sgo_is_return_guard(instrs[scan]) &&
        scan + 2 < instrs.length() &&
        sgo_const_instr(instrs[scan + 1]) != None &&
        instrs[scan + 2] == @lib.Instruction::drop() {
        return Some(scan + 3)
      }
    }
    match sgo_scalar_unary_result(instrs[scan], kind) {
      Some(next_kind) => {
        kind = next_kind
        scan = scan + 1
        continue
      }
      None => ()
    }
    if scan + 1 < instrs.length() &&
      sgo_scalar_const_kind(instrs[scan]) == Some(kind) {
      match sgo_scalar_binary_result(instrs[scan + 1], kind) {
        Some(next_kind) => {
          kind = next_kind
          scan = scan + 2
          continue
        }
        None => ()
      }
    }
    if prefix_scan > prefix_start &&
      sgo_scalar_const_kind(instrs[prefix_scan - 1]) == Some(kind) {
      match sgo_scalar_binary_result(instrs[scan], kind) {
        Some(next_kind) => {
          prefix_scan = prefix_scan - 1
          kind = next_kind
          scan = scan + 1
          continue
        }
        None => ()
      }
    }
    return None
  }
  None
}

///|
fn sgo_scalar_call_parent_chain_read_at(
  instrs : Array[@lib.Instruction],
  pos : Int,
  idx : @lib.GlobalIdx,
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> Bool {
  match instrs[pos] {
    @lib.GlobalGet(get_idx) if get_idx == idx => ()
    _ => return false
  }
  let direct_candidate = sgo_scalar_independent_fragment_starts_at(
    instrs,
    pos + 1,
  )
  let reverse_candidate = sgo_scalar_independent_fragment_can_end_at(
    instrs, pos,
  )
  if !direct_candidate && !reverse_candidate {
    return false
  }
  // Bounded straight-line FlowScanner subset: an independent scalar producer
  // (zero-param call, memory.size, or constant-address scalar load) and the
  // guarded global meet at a nontrapping scalar binary/compare parent. Unary
  // instructions on the independent producer may be removable or trap-capable;
  // they cannot depend on the guarded value and are replayed by cleanup when
  // needed. Instructions after the first parent remain pure because the guarded
  // value flows through them.
  let direct_prefix_start = sgo_scalar_const_prefix_start(instrs, pos)
  match
    sgo_scalar_independent_fragment_at(instrs, pos + 1, mod_, func_type_indices) {
    Some(fragment) => {
      let mut scan = fragment.next_pos
      let mut parent_input_kind = fragment.result_kind
      while scan < instrs.length() {
        match sgo_scalar_any_unary_result(instrs[scan], parent_input_kind) {
          Some(next_kind) => {
            parent_input_kind = next_kind
            scan = scan + 1
          }
          None => break
        }
      }
      if scan < instrs.length() {
        match sgo_scalar_binary_result(instrs[scan], parent_input_kind) {
          Some(result_kind) =>
            if sgo_scalar_pure_suffix_with_prefix_tail_matches(
                instrs,
                scan + 1,
                idx,
                result_kind,
                direct_prefix_start,
                pos,
              ) {
              return true
            }
          None => ()
        }
      }
    }
    None => ()
  }
  let mut fragment_end = pos
  while fragment_end > 0 && sgo_is_any_scalar_unary(instrs[fragment_end - 1]) {
    fragment_end = fragment_end - 1
  }
  match
    sgo_scalar_independent_fragment_before(
      instrs, fragment_end, mod_, func_type_indices,
    ) {
    Some((fragment_pos, fragment)) => {
      let mut scan = fragment.next_pos
      let mut parent_input_kind = fragment.result_kind
      while scan < pos {
        match sgo_scalar_any_unary_result(instrs[scan], parent_input_kind) {
          Some(next_kind) => {
            parent_input_kind = next_kind
            scan = scan + 1
          }
          None => break
        }
      }
      if scan == pos && pos + 1 < instrs.length() {
        match sgo_scalar_binary_result(instrs[pos + 1], parent_input_kind) {
          Some(result_kind) => {
            let reverse_prefix_start = sgo_scalar_const_prefix_start(
              instrs, fragment_pos,
            )
            if sgo_scalar_pure_suffix_with_prefix_tail_matches(
                instrs,
                pos + 2,
                idx,
                result_kind,
                reverse_prefix_start,
                fragment_pos,
              ) {
              return true
            }
          }
          None => ()
        }
      }
    }
    None => ()
  }
  false
}

///|
fn sgo_scalar_call_parent_cleanup_prefix(
  instrs : Array[@lib.Instruction],
  pos : Int,
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> (Array[@lib.Instruction], SgoScalarFlowKind, Int, Int, Int)? {
  if pos >= instrs.length() {
    return None
  }
  let mut leading_const_end = pos
  while leading_const_end < instrs.length() &&
        sgo_scalar_const_kind(instrs[leading_const_end]) != None {
    leading_const_end = leading_const_end + 1
  }
  for producer_pos = pos
      producer_pos <= leading_const_end
      producer_pos = producer_pos + 1 {
    match
      sgo_scalar_independent_fragment_at(
        instrs, producer_pos, mod_, func_type_indices,
      ) {
      Some(fragment) => {
        if fragment.next_pos >= instrs.length() {
          continue
        }
        match instrs[fragment.next_pos] {
          @lib.LocalTee(_) | @lib.LocalSet(_) | @lib.GlobalSet(_) => continue
          _ => ()
        }
        let mut parent_input_kind = fragment.result_kind
        let mut scan = fragment.next_pos
        while scan < instrs.length() {
          match sgo_scalar_unary_result(instrs[scan], parent_input_kind) {
            Some(next_kind) => {
              parent_input_kind = next_kind
              scan = scan + 1
              continue
            }
            None => ()
          }
          match
            sgo_scalar_trapping_unary_result(instrs[scan], parent_input_kind) {
            Some(next_kind) => {
              parent_input_kind = next_kind
              scan = scan + 1
              continue
            }
            None => break
          }
        }
        // Producer-first order: optional prefix constants, producer fragment,
        // replaced global constant, first parent.
        if scan + 1 < instrs.length() &&
          sgo_scalar_const_kind(instrs[scan]) == Some(parent_input_kind) {
          match sgo_scalar_binary_result(instrs[scan + 1], parent_input_kind) {
            Some(result_kind) => {
              let replay = sgo_scalar_fragment_cleanup_replay(
                instrs, fragment, scan, mod_, func_type_indices,
              )
              return Some((replay, result_kind, scan + 2, pos, producer_pos))
            }
            None => ()
          }
        }
        // Global-first order: optional prefix constants, replaced global
        // constant, producer fragment, first parent.
        if producer_pos > pos &&
          sgo_scalar_const_kind(instrs[producer_pos - 1]) ==
          Some(parent_input_kind) &&
          scan < instrs.length() {
          match sgo_scalar_binary_result(instrs[scan], parent_input_kind) {
            Some(result_kind) => {
              let replay = sgo_scalar_fragment_cleanup_replay(
                instrs, fragment, scan, mod_, func_type_indices,
              )
              return Some(
                (replay, result_kind, scan + 1, pos, producer_pos - 1),
              )
            }
            None => ()
          }
        }
      }
      None => ()
    }
  }
  None
}

///|
fn sgo_float_guard_tail_matches(
  instrs : Array[@lib.Instruction],
  tail_pos : Int,
  idx : @lib.GlobalIdx,
) -> Bool {
  if tail_pos >= instrs.length() {
    return false
  }
  let tail = instrs[tail_pos]
  sgo_if_is_read_only_to_write_set(tail, idx) ||
  (
    sgo_is_return_guard(tail) &&
    sgo_if_return_tail_matches(instrs, tail_pos + 1, idx)
  )
}

///|
fn sgo_float_result_first_compare_tail_matches(
  instrs : Array[@lib.Instruction],
  start : Int,
  idx : @lib.GlobalIdx,
  op : @lib.Instruction,
) -> Bool {
  if start + 2 >= instrs.length() {
    return false
  }
  sgo_float_binary_compare_types_match(op, instrs[start], instrs[start + 1]) &&
  sgo_float_guard_tail_matches(instrs, start + 2, idx)
}

///|
fn sgo_float_binary_operand_independent_call_read_at(
  instrs : Array[@lib.Instruction],
  pos : Int,
  idx : @lib.GlobalIdx,
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> Bool {
  // Narrow FlowScanner subset: an independent zero-param/one-result float call
  // and the guarded same-typed float global feed one IEEE float binary parent.
  // The result then reaches exactly one same-typed float comparison with a
  // constant before the guarded write / if-return tail. IEEE div, min/max,
  // copysign, and NaN-sensitive comparisons are nontrapping and admitted.
  match instrs[pos] {
    @lib.GlobalGet(get_idx) if get_idx == idx => ()
    _ => return false
  }
  // Result-first comparison constant, with both binary operand orders.
  if pos + 2 < instrs.length() {
    match (instrs[pos + 1], instrs[pos + 2]) {
      (@lib.Call(func_idx), op) if (
          sgo_is_f32_binary_flow_instr(op) || sgo_is_f64_binary_flow_instr(op)
        ) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) &&
        sgo_float_result_first_compare_tail_matches(instrs, pos + 3, idx, op) =>
        return true
      _ => ()
    }
  }
  if pos > 0 && pos + 1 < instrs.length() {
    match (instrs[pos - 1], instrs[pos + 1]) {
      (@lib.Call(func_idx), op) if (
          sgo_is_f32_binary_flow_instr(op) || sgo_is_f64_binary_flow_instr(op)
        ) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) &&
        sgo_float_result_first_compare_tail_matches(instrs, pos + 2, idx, op) =>
        return true
      _ => ()
    }
  }
  // Constant-first comparison, with both binary operand orders.
  if pos > 0 && pos + 3 < instrs.length() {
    match (instrs[pos - 1], instrs[pos + 1], instrs[pos + 2], instrs[pos + 3]) {
      (compare_const, @lib.Call(func_idx), op, compare) if sgo_float_binary_compare_types_match(
          op, compare_const, compare,
        ) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) &&
        sgo_float_guard_tail_matches(instrs, pos + 4, idx) => return true
      _ => ()
    }
  }
  if pos > 1 && pos + 2 < instrs.length() {
    match (instrs[pos - 2], instrs[pos - 1], instrs[pos + 1], instrs[pos + 2]) {
      (compare_const, @lib.Call(func_idx), op, compare) if sgo_float_binary_compare_types_match(
          op, compare_const, compare,
        ) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) &&
        sgo_float_guard_tail_matches(instrs, pos + 3, idx) => return true
      _ => ()
    }
  }
  false
}

///|
fn sgo_float_call_binary_compare_prefix_func(
  instrs : Array[@lib.Instruction],
  pos : Int,
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> @lib.FuncIdx? {
  if pos + 4 >= instrs.length() {
    return None
  }
  match
    (
      instrs[pos],
      instrs[pos + 1],
      instrs[pos + 2],
      instrs[pos + 3],
      instrs[pos + 4],
    ) {
    (value_const, @lib.Call(func_idx), op, compare_const, compare) if sgo_float_const_matches_binary(
        value_const, op,
      ) &&
      sgo_float_binary_compare_types_match(op, compare_const, compare) &&
      sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) =>
      Some(func_idx)
    (@lib.Call(func_idx), value_const, op, compare_const, compare) if sgo_float_const_matches_binary(
        value_const, op,
      ) &&
      sgo_float_binary_compare_types_match(op, compare_const, compare) &&
      sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) =>
      Some(func_idx)
    (compare_const, value_const, @lib.Call(func_idx), op, compare) if sgo_float_const_matches_binary(
        value_const, op,
      ) &&
      sgo_float_binary_compare_types_match(op, compare_const, compare) &&
      sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) =>
      Some(func_idx)
    (compare_const, @lib.Call(func_idx), value_const, op, compare) if sgo_float_const_matches_binary(
        value_const, op,
      ) &&
      sgo_float_binary_compare_types_match(op, compare_const, compare) &&
      sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) =>
      Some(func_idx)
    _ => None
  }
}

///|
fn sgo_memory_grow_arg_is_independent(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.LocalGet(_) => true
    _ => sgo_const_instr(instr) != None
  }
}

///|
fn sgo_i32_add_grow_arg_is_independent(
  left : @lib.Instruction,
  right : @lib.Instruction,
  op : @lib.Instruction,
) -> Bool {
  sgo_memory_grow_arg_is_independent(left) &&
  sgo_memory_grow_arg_is_independent(right) &&
  op == @lib.Instruction::i32_add()
}

///|
fn sgo_compare_operand_independent_memory_read_at(
  instrs : Array[@lib.Instruction],
  pos : Int,
  idx : @lib.GlobalIdx,
) -> Bool {
  // Narrow FlowScanner subset: an independent memory.size or constant-or-local.get
  // memory.grow supplies one compare operand while the guarded global supplies
  // the other. A memory.grow delta must be independent so the guarded value
  // cannot affect the grow.
  match instrs[pos] {
    @lib.GlobalGet(get_idx) if get_idx == idx => ()
    _ => return false
  }
  if pos + 3 < instrs.length() {
    match (instrs[pos + 1], instrs[pos + 2], instrs[pos + 3]) {
      (@lib.MemorySize(_), compare, if_instr) if sgo_is_compare_instr(compare) =>
        if sgo_if_is_read_only_to_write_set(if_instr, idx) ||
          (
            sgo_is_return_guard(if_instr) &&
            sgo_if_return_tail_matches(instrs, pos + 4, idx)
          ) {
          return true
        }
      _ => ()
    }
  }
  if pos + 4 < instrs.length() {
    match (instrs[pos + 1], instrs[pos + 2], instrs[pos + 3], instrs[pos + 4]) {
      (grow_delta, @lib.MemoryGrow(_), compare, if_instr) if sgo_memory_grow_arg_is_independent(
          grow_delta,
        ) &&
        sgo_is_compare_instr(compare) =>
        if sgo_if_is_read_only_to_write_set(if_instr, idx) ||
          (
            sgo_is_return_guard(if_instr) &&
            sgo_if_return_tail_matches(instrs, pos + 5, idx)
          ) {
          return true
        }
      _ => ()
    }
  }
  if pos + 6 < instrs.length() {
    match
      (
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
        instrs[pos + 6],
      ) {
      (grow_left, grow_right, grow_op, @lib.MemoryGrow(_), compare, if_instr) if sgo_i32_add_grow_arg_is_independent(
          grow_left, grow_right, grow_op,
        ) &&
        sgo_is_compare_instr(compare) =>
        if sgo_if_is_read_only_to_write_set(if_instr, idx) ||
          (
            sgo_is_return_guard(if_instr) &&
            sgo_if_return_tail_matches(instrs, pos + 7, idx)
          ) {
          return true
        }
      _ => ()
    }
  }
  if pos > 0 && pos + 2 < instrs.length() {
    match (instrs[pos - 1], instrs[pos + 1], instrs[pos + 2]) {
      (@lib.MemorySize(_), compare, if_instr) if sgo_is_compare_instr(compare) =>
        if sgo_if_is_read_only_to_write_set(if_instr, idx) ||
          (
            sgo_is_return_guard(if_instr) &&
            sgo_if_return_tail_matches(instrs, pos + 3, idx)
          ) {
          return true
        }
      _ => ()
    }
  }
  if pos > 1 && pos + 2 < instrs.length() {
    match (instrs[pos - 2], instrs[pos - 1], instrs[pos + 1], instrs[pos + 2]) {
      (grow_delta, @lib.MemoryGrow(_), compare, if_instr) if sgo_memory_grow_arg_is_independent(
          grow_delta,
        ) &&
        sgo_is_compare_instr(compare) =>
        if sgo_if_is_read_only_to_write_set(if_instr, idx) ||
          (
            sgo_is_return_guard(if_instr) &&
            sgo_if_return_tail_matches(instrs, pos + 3, idx)
          ) {
          return true
        }
      _ => ()
    }
  }
  if pos > 3 && pos + 2 < instrs.length() {
    match
      (
        instrs[pos - 4],
        instrs[pos - 3],
        instrs[pos - 2],
        instrs[pos - 1],
        instrs[pos + 1],
        instrs[pos + 2],
      ) {
      (grow_left, grow_right, grow_op, @lib.MemoryGrow(_), compare, if_instr) if sgo_i32_add_grow_arg_is_independent(
          grow_left, grow_right, grow_op,
        ) &&
        sgo_is_compare_instr(compare) =>
        if sgo_if_is_read_only_to_write_set(if_instr, idx) ||
          (
            sgo_is_return_guard(if_instr) &&
            sgo_if_return_tail_matches(instrs, pos + 3, idx)
          ) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn sgo_table_grow_arg_is_independent(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.LocalGet(_) => true
    _ => sgo_const_instr(instr) != None
  }
}

///|
fn sgo_compare_operand_independent_table_read_at(
  instrs : Array[@lib.Instruction],
  pos : Int,
  idx : @lib.GlobalIdx,
) -> Bool {
  // Narrow FlowScanner subset: an independent table.size or constant-or-local.get
  // table.grow supplies one compare operand while the guarded global supplies
  // the other. A table.grow ref and delta must be independent so the guarded
  // value cannot affect the grow.
  match instrs[pos] {
    @lib.GlobalGet(get_idx) if get_idx == idx => ()
    _ => return false
  }
  if pos + 3 < instrs.length() {
    match (instrs[pos + 1], instrs[pos + 2], instrs[pos + 3]) {
      (@lib.TableSize(_), compare, if_instr) if sgo_is_compare_instr(compare) =>
        if sgo_if_is_read_only_to_write_set(if_instr, idx) ||
          (
            sgo_is_return_guard(if_instr) &&
            sgo_if_return_tail_matches(instrs, pos + 4, idx)
          ) {
          return true
        }
      _ => ()
    }
  }
  if pos + 5 < instrs.length() {
    match
      (
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
      ) {
      (ref_value, grow_delta, @lib.TableGrow(_), compare, if_instr) if sgo_table_grow_arg_is_independent(
          ref_value,
        ) &&
        sgo_table_grow_arg_is_independent(grow_delta) &&
        sgo_is_compare_instr(compare) =>
        if sgo_if_is_read_only_to_write_set(if_instr, idx) ||
          (
            sgo_is_return_guard(if_instr) &&
            sgo_if_return_tail_matches(instrs, pos + 6, idx)
          ) {
          return true
        }
      _ => ()
    }
  }
  if pos + 7 < instrs.length() {
    match
      (
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
        instrs[pos + 6],
        instrs[pos + 7],
      ) {
      (
        ref_value,
        grow_left,
        grow_right,
        grow_op,
        @lib.TableGrow(_),
        compare,
        if_instr,
      ) if sgo_table_grow_arg_is_independent(ref_value) &&
        sgo_i32_add_grow_arg_is_independent(grow_left, grow_right, grow_op) &&
        sgo_is_compare_instr(compare) =>
        if sgo_if_is_read_only_to_write_set(if_instr, idx) ||
          (
            sgo_is_return_guard(if_instr) &&
            sgo_if_return_tail_matches(instrs, pos + 8, idx)
          ) {
          return true
        }
      _ => ()
    }
  }
  if pos > 0 && pos + 2 < instrs.length() {
    match (instrs[pos - 1], instrs[pos + 1], instrs[pos + 2]) {
      (@lib.TableSize(_), compare, if_instr) if sgo_is_compare_instr(compare) =>
        if sgo_if_is_read_only_to_write_set(if_instr, idx) ||
          (
            sgo_is_return_guard(if_instr) &&
            sgo_if_return_tail_matches(instrs, pos + 3, idx)
          ) {
          return true
        }
      _ => ()
    }
  }
  if pos > 2 && pos + 2 < instrs.length() {
    match
      (
        instrs[pos - 3],
        instrs[pos - 2],
        instrs[pos - 1],
        instrs[pos + 1],
        instrs[pos + 2],
      ) {
      (ref_value, grow_delta, @lib.TableGrow(_), compare, if_instr) if sgo_table_grow_arg_is_independent(
          ref_value,
        ) &&
        sgo_table_grow_arg_is_independent(grow_delta) &&
        sgo_is_compare_instr(compare) =>
        if sgo_if_is_read_only_to_write_set(if_instr, idx) ||
          (
            sgo_is_return_guard(if_instr) &&
            sgo_if_return_tail_matches(instrs, pos + 3, idx)
          ) {
          return true
        }
      _ => ()
    }
  }
  if pos > 4 && pos + 2 < instrs.length() {
    match
      (
        instrs[pos - 5],
        instrs[pos - 4],
        instrs[pos - 3],
        instrs[pos - 2],
        instrs[pos - 1],
        instrs[pos + 1],
        instrs[pos + 2],
      ) {
      (
        ref_value,
        grow_left,
        grow_right,
        grow_op,
        @lib.TableGrow(_),
        compare,
        if_instr,
      ) if sgo_table_grow_arg_is_independent(ref_value) &&
        sgo_i32_add_grow_arg_is_independent(grow_left, grow_right, grow_op) &&
        sgo_is_compare_instr(compare) =>
        if sgo_if_is_read_only_to_write_set(if_instr, idx) ||
          (
            sgo_is_return_guard(if_instr) &&
            sgo_if_return_tail_matches(instrs, pos + 3, idx)
          ) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn sgo_select_operand_independent_memory_read_at(
  instrs : Array[@lib.Instruction],
  pos : Int,
  idx : @lib.GlobalIdx,
) -> Bool {
  // Narrow FlowScanner subset: the guarded global is a select operand while an
  // independent memory query/grow supplies the other operand. A memory.grow is
  // accepted when its delta is a constant or local.get independent of the
  // guarded global value.
  match instrs[pos] {
    @lib.GlobalGet(get_idx) if get_idx == idx => ()
    _ => return false
  }
  if pos + 4 < instrs.length() {
    match (instrs[pos + 1], instrs[pos + 2], instrs[pos + 3], instrs[pos + 4]) {
      (@lib.MemorySize(_), const_instr, @lib.Select(_), if_instr) =>
        if sgo_const_instr(const_instr) != None &&
          (
            sgo_if_is_read_only_to_write_set(if_instr, idx) ||
            (
              sgo_is_return_guard(if_instr) &&
              sgo_if_return_tail_matches(instrs, pos + 5, idx)
            )
          ) {
          return true
        }
      _ => ()
    }
  }
  if pos + 5 < instrs.length() {
    match
      (
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
      ) {
      (grow_delta, @lib.MemoryGrow(_), const_instr, @lib.Select(_), if_instr) =>
        if sgo_memory_grow_arg_is_independent(grow_delta) &&
          sgo_const_instr(const_instr) != None &&
          (
            sgo_if_is_read_only_to_write_set(if_instr, idx) ||
            (
              sgo_is_return_guard(if_instr) &&
              sgo_if_return_tail_matches(instrs, pos + 6, idx)
            )
          ) {
          return true
        }
      _ => ()
    }
  }
  if pos + 7 < instrs.length() {
    match
      (
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
        instrs[pos + 6],
        instrs[pos + 7],
      ) {
      (
        grow_left,
        grow_right,
        grow_op,
        @lib.MemoryGrow(_),
        const_instr,
        @lib.Select(_),
        if_instr,
      ) =>
        if sgo_i32_add_grow_arg_is_independent(grow_left, grow_right, grow_op) &&
          sgo_const_instr(const_instr) != None &&
          (
            sgo_if_is_read_only_to_write_set(if_instr, idx) ||
            (
              sgo_is_return_guard(if_instr) &&
              sgo_if_return_tail_matches(instrs, pos + 8, idx)
            )
          ) {
          return true
        }
      _ => ()
    }
  }
  if pos > 3 && pos + 3 < instrs.length() {
    match
      (
        instrs[pos - 4],
        instrs[pos - 3],
        instrs[pos - 2],
        instrs[pos - 1],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
      ) {
      (
        grow_left,
        grow_right,
        grow_op,
        @lib.MemoryGrow(_),
        const_instr,
        @lib.Select(_),
        if_instr,
      ) =>
        if sgo_i32_add_grow_arg_is_independent(grow_left, grow_right, grow_op) &&
          sgo_const_instr(const_instr) != None &&
          (
            sgo_if_is_read_only_to_write_set(if_instr, idx) ||
            (
              sgo_is_return_guard(if_instr) &&
              sgo_if_return_tail_matches(instrs, pos + 4, idx)
            )
          ) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn sgo_select_operand_independent_table_read_at(
  instrs : Array[@lib.Instruction],
  pos : Int,
  idx : @lib.GlobalIdx,
) -> Bool {
  // Narrow FlowScanner subset: the guarded global is a select operand while an
  // independent table.size or constant-or-local.get table.grow supplies the other
  // operand. A table.grow ref and delta must be independent so the guarded value
  // cannot affect the table growth.
  match instrs[pos] {
    @lib.GlobalGet(get_idx) if get_idx == idx => ()
    _ => return false
  }
  if pos == 0 && pos + 4 < instrs.length() {
    match (instrs[pos + 1], instrs[pos + 2], instrs[pos + 3], instrs[pos + 4]) {
      (@lib.TableSize(_), const_instr, @lib.Select(_), if_instr) =>
        if sgo_const_instr(const_instr) != None &&
          (
            sgo_if_is_read_only_to_write_set(if_instr, idx) ||
            (
              sgo_is_return_guard(if_instr) &&
              sgo_if_return_tail_matches(instrs, pos + 5, idx)
            )
          ) {
          return true
        }
      _ => ()
    }
  }
  if pos == 0 && pos + 6 < instrs.length() {
    match
      (
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
        instrs[pos + 6],
      ) {
      (
        ref_value,
        grow_delta,
        @lib.TableGrow(_),
        const_instr,
        @lib.Select(_),
        if_instr,
      ) =>
        if sgo_table_grow_arg_is_independent(ref_value) &&
          sgo_table_grow_arg_is_independent(grow_delta) &&
          sgo_const_instr(const_instr) != None &&
          (
            sgo_if_is_read_only_to_write_set(if_instr, idx) ||
            (
              sgo_is_return_guard(if_instr) &&
              sgo_if_return_tail_matches(instrs, pos + 7, idx)
            )
          ) {
          return true
        }
      _ => ()
    }
  }
  if pos == 0 && pos + 8 < instrs.length() {
    match
      (
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
        instrs[pos + 6],
        instrs[pos + 7],
        instrs[pos + 8],
      ) {
      (
        ref_value,
        grow_left,
        grow_right,
        grow_op,
        @lib.TableGrow(_),
        const_instr,
        @lib.Select(_),
        if_instr,
      ) =>
        if sgo_table_grow_arg_is_independent(ref_value) &&
          sgo_i32_add_grow_arg_is_independent(grow_left, grow_right, grow_op) &&
          sgo_const_instr(const_instr) != None &&
          (
            sgo_if_is_read_only_to_write_set(if_instr, idx) ||
            (
              sgo_is_return_guard(if_instr) &&
              sgo_if_return_tail_matches(instrs, pos + 9, idx)
            )
          ) {
          return true
        }
      _ => ()
    }
  }
  if pos > 0 && pos + 3 < instrs.length() {
    match (instrs[pos - 1], instrs[pos + 1], instrs[pos + 2], instrs[pos + 3]) {
      (@lib.TableSize(_), const_instr, @lib.Select(_), if_instr) =>
        if sgo_const_instr(const_instr) != None &&
          (
            sgo_if_is_read_only_to_write_set(if_instr, idx) ||
            (
              sgo_is_return_guard(if_instr) &&
              sgo_if_return_tail_matches(instrs, pos + 4, idx)
            )
          ) {
          return true
        }
      _ => ()
    }
  }
  if pos > 2 && pos + 3 < instrs.length() {
    match
      (
        instrs[pos - 3],
        instrs[pos - 2],
        instrs[pos - 1],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
      ) {
      (
        ref_value,
        grow_delta,
        @lib.TableGrow(_),
        const_instr,
        @lib.Select(_),
        if_instr,
      ) =>
        if sgo_table_grow_arg_is_independent(ref_value) &&
          sgo_table_grow_arg_is_independent(grow_delta) &&
          sgo_const_instr(const_instr) != None &&
          (
            sgo_if_is_read_only_to_write_set(if_instr, idx) ||
            (
              sgo_is_return_guard(if_instr) &&
              sgo_if_return_tail_matches(instrs, pos + 4, idx)
            )
          ) {
          return true
        }
      _ => ()
    }
  }
  if pos > 4 && pos + 3 < instrs.length() {
    match
      (
        instrs[pos - 5],
        instrs[pos - 4],
        instrs[pos - 3],
        instrs[pos - 2],
        instrs[pos - 1],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
      ) {
      (
        ref_value,
        grow_left,
        grow_right,
        grow_op,
        @lib.TableGrow(_),
        const_instr,
        @lib.Select(_),
        if_instr,
      ) =>
        if sgo_table_grow_arg_is_independent(ref_value) &&
          sgo_i32_add_grow_arg_is_independent(grow_left, grow_right, grow_op) &&
          sgo_const_instr(const_instr) != None &&
          (
            sgo_if_is_read_only_to_write_set(if_instr, idx) ||
            (
              sgo_is_return_guard(if_instr) &&
              sgo_if_return_tail_matches(instrs, pos + 4, idx)
            )
          ) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn sgo_is_i32_pure_condition_instr(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.I32Clz
    | @lib.I32Ctz
    | @lib.I32Popcnt
    | @lib.I32Eqz
    | @lib.I32Eq
    | @lib.I32Ne
    | @lib.I32Add
    | @lib.I32Sub
    | @lib.I32Mul
    | @lib.I32And
    | @lib.I32Or
    | @lib.I32Xor
    | @lib.I32Shl
    | @lib.I32ShrS
    | @lib.I32ShrU
    | @lib.I32Rotl
    | @lib.I32Rotr
    | @lib.I32LtS
    | @lib.I32LtU
    | @lib.I32GtS
    | @lib.I32GtU
    | @lib.I32LeS
    | @lib.I32LeU
    | @lib.I32GeS
    | @lib.I32GeU => true
    _ => false
  }
}

///|
fn sgo_is_i64_pure_condition_instr(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.I64Clz
    | @lib.I64Ctz
    | @lib.I64Popcnt
    | @lib.I64Eqz
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
    | @lib.I64Add
    | @lib.I64Sub
    | @lib.I64Mul
    | @lib.I64And
    | @lib.I64Or
    | @lib.I64Xor
    | @lib.I64Shl
    | @lib.I64ShrS
    | @lib.I64ShrU
    | @lib.I64Rotl
    | @lib.I64Rotr => true
    _ => false
  }
}

///|
fn sgo_is_float_compare_condition_instr(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.F32Eq
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
    | @lib.F64Ge => true
    _ => false
  }
}

///|
fn sgo_is_numeric_conversion_condition_instr(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.I32WrapI64
    | @lib.I64ExtendI32S
    | @lib.I64ExtendI32U
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
    | @lib.I64TruncSatF64U => true
    _ => false
  }
}

///|
fn sgo_is_ref_condition_instr(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.RefIsNull
    | @lib.RefEq
    | @lib.RefTest(_, _, _)
    | @lib.RefTestDesc(_, _) => true
    _ => false
  }
}

///|
fn sgo_is_float_value_condition_instr(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.F32Abs
    | @lib.F32Neg
    | @lib.F32Ceil
    | @lib.F32Floor
    | @lib.F32Trunc
    | @lib.F32Nearest
    | @lib.F32Sqrt
    | @lib.F32Add
    | @lib.F32Sub
    | @lib.F32Mul
    | @lib.F32Div
    | @lib.F32Min
    | @lib.F32Max
    | @lib.F32Copysign
    | @lib.F64Abs
    | @lib.F64Neg
    | @lib.F64Ceil
    | @lib.F64Floor
    | @lib.F64Trunc
    | @lib.F64Nearest
    | @lib.F64Sqrt
    | @lib.F64Add
    | @lib.F64Sub
    | @lib.F64Mul
    | @lib.F64Div
    | @lib.F64Min
    | @lib.F64Max
    | @lib.F64Copysign => true
    _ => false
  }
}

///|
fn sgo_is_read_only_to_write_pure_condition_instr(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.LocalGet(_) => true
    _ =>
      sgo_const_instr(instr) != None ||
      sgo_is_i32_pure_condition_instr(instr) ||
      sgo_is_i64_pure_condition_instr(instr) ||
      sgo_is_float_compare_condition_instr(instr) ||
      sgo_is_float_value_condition_instr(instr) ||
      sgo_is_numeric_conversion_condition_instr(instr) ||
      sgo_is_ref_condition_instr(instr)
  }
}

///|
fn sgo_read_only_to_write_pure_condition_read_at(
  instrs : Array[@lib.Instruction],
  pos : Int,
  idx : @lib.GlobalIdx,
) -> Bool {
  for scan = pos + 1; scan < instrs.length(); scan = scan + 1 {
    let instr = instrs[scan]
    match instr {
      @lib.If(_, _, _) => return sgo_if_is_read_only_to_write_set(instr, idx)
      @lib.Select(_) if scan + 1 < instrs.length() => {
        for after_select = scan + 1
            after_select < instrs.length()
            after_select = after_select + 1 {
          let next = instrs[after_select]
          match next {
            @lib.If(_, _, _) =>
              return sgo_if_is_read_only_to_write_set(next, idx)
            _ =>
              if !sgo_is_read_only_to_write_pure_condition_instr(next) {
                return false
              }
          }
        }
        return false
      }
      _ =>
        if !sgo_is_read_only_to_write_pure_condition_instr(instr) {
          return false
        }
    }
  }
  false
}

///|
fn sgo_read_only_to_write_if_return_value_read_at(
  instrs : Array[@lib.Instruction],
  pos : Int,
  idx : @lib.GlobalIdx,
) -> Bool {
  for scan = pos + 1; scan < instrs.length(); scan = scan + 1 {
    let instr = instrs[scan]
    if sgo_is_return_guard(instr) {
      return sgo_if_return_tail_matches(instrs, scan + 1, idx)
    }
    match instr {
      @lib.Select(_) if scan + 1 < instrs.length() => {
        for after_select = scan + 1
            after_select < instrs.length()
            after_select = after_select + 1 {
          let next = instrs[after_select]
          if sgo_is_return_guard(next) {
            return sgo_if_return_tail_matches(instrs, after_select + 1, idx)
          }
          if !sgo_is_read_only_to_write_pure_condition_instr(next) {
            return false
          }
        }
        return false
      }
      _ =>
        if !sgo_is_read_only_to_write_pure_condition_instr(instr) {
          return false
        }
    }
  }
  false
}

///|
fn sgo_is_return_guard(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.If(_, [@lib.Return], None) => true
    _ => false
  }
}

///|
fn sgo_if_return_set_tail_matches(
  value : @lib.Instruction,
  set : @lib.Instruction,
  idx : @lib.GlobalIdx,
) -> Bool {
  match set {
    @lib.GlobalSet(set_idx) => set_idx == idx && sgo_const_instr(value) != None
    _ => false
  }
}

///|
fn sgo_if_return_block_tail_matches(
  instr : @lib.Instruction,
  idx : @lib.GlobalIdx,
) -> Bool {
  match instr {
    @lib.Block(@lib.VoidBlockType, @lib.Expr(body)) =>
      sgo_instrs_are_single_const_global_set(body, idx)
    _ => false
  }
}

///|
fn sgo_is_compare_instr(instr : @lib.Instruction) -> Bool {
  instr == @lib.Instruction::i32_eq() || instr == @lib.Instruction::i32_ne()
}

///|
fn sgo_is_exact_if_return_set(
  instrs : Array[@lib.Instruction],
  pos : Int,
  idx : @lib.GlobalIdx,
) -> Bool {
  match instrs {
    [@lib.GlobalGet(get_idx), if_instr, block_tail] =>
      pos == 0 &&
      get_idx == idx &&
      sgo_is_return_guard(if_instr) &&
      sgo_if_return_block_tail_matches(block_tail, idx)
    [@lib.GlobalGet(get_idx), first, second, third] if first ==
      @lib.Instruction::i32_eqz() =>
      pos == 0 &&
      get_idx == idx &&
      sgo_is_return_guard(second) &&
      sgo_if_return_block_tail_matches(third, idx)
    [@lib.GlobalGet(get_idx), if_instr, value, set] =>
      pos == 0 &&
      get_idx == idx &&
      sgo_is_return_guard(if_instr) &&
      sgo_if_return_set_tail_matches(value, set, idx)
    [@lib.GlobalGet(get_idx), first, second, value, set] if first ==
      @lib.Instruction::i32_eqz() =>
      pos == 0 &&
      get_idx == idx &&
      sgo_is_return_guard(second) &&
      sgo_if_return_set_tail_matches(value, set, idx)
    [@lib.GlobalGet(get_idx), const_instr, cmp_instr, if_instr, block_tail] =>
      pos == 0 &&
      get_idx == idx &&
      sgo_const_instr(const_instr) != None &&
      sgo_is_compare_instr(cmp_instr) &&
      sgo_is_return_guard(if_instr) &&
      sgo_if_return_block_tail_matches(block_tail, idx)
    [const_instr, @lib.GlobalGet(get_idx), cmp_instr, if_instr, block_tail] =>
      pos == 1 &&
      get_idx == idx &&
      sgo_const_instr(const_instr) != None &&
      sgo_is_compare_instr(cmp_instr) &&
      sgo_is_return_guard(if_instr) &&
      sgo_if_return_block_tail_matches(block_tail, idx)
    [@lib.GlobalGet(get_idx), const_instr, cmp_instr, if_instr, value, set] =>
      pos == 0 &&
      get_idx == idx &&
      sgo_const_instr(const_instr) != None &&
      sgo_is_compare_instr(cmp_instr) &&
      sgo_is_return_guard(if_instr) &&
      sgo_if_return_set_tail_matches(value, set, idx)
    [const_instr, @lib.GlobalGet(get_idx), cmp_instr, if_instr, value, set] =>
      pos == 1 &&
      get_idx == idx &&
      sgo_const_instr(const_instr) != None &&
      sgo_is_compare_instr(cmp_instr) &&
      sgo_is_return_guard(if_instr) &&
      sgo_if_return_set_tail_matches(value, set, idx)
    _ => false
  }
}

///|
fn sgo_if_return_tail_matches(
  instrs : Array[@lib.Instruction],
  start : Int,
  idx : @lib.GlobalIdx,
) -> Bool {
  if start + 2 == instrs.length() {
    return sgo_if_return_set_tail_matches(instrs[start], instrs[start + 1], idx)
  }
  if start + 1 == instrs.length() {
    return sgo_if_return_block_tail_matches(instrs[start], idx)
  }
  false
}

///|
fn sgo_is_pure_condition_if_return_set(
  instrs : Array[@lib.Instruction],
  pos : Int,
  idx : @lib.GlobalIdx,
) -> Bool {
  if pos != 0 {
    return false
  }
  for scan = pos + 1; scan < instrs.length(); scan = scan + 1 {
    let instr = instrs[scan]
    if sgo_is_return_guard(instr) {
      return sgo_if_return_tail_matches(instrs, scan + 1, idx)
    }
    if !sgo_is_read_only_to_write_pure_condition_instr(instr) {
      return false
    }
  }
  false
}

///|
fn sgo_collect_read_only_to_write_body(
  instrs : Array[@lib.Instruction],
  out : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Nop => ()
      @lib.Block(@lib.VoidBlockType, body) => {
        let @lib.Expr(body_instrs) = body
        if !sgo_collect_read_only_to_write_body(body_instrs, out) {
          return false
        }
      }
      _ => out.push(instr)
    }
  }
  true
}

///|
fn sgo_skip_noop_const_drops(instrs : Array[@lib.Instruction]) -> Int {
  let mut start = 0
  while start + 1 < instrs.length() &&
        sgo_const_instr(instrs[start]) != None &&
        instrs[start + 1] == @lib.Instruction::drop() {
    start = start + 2
  }
  start
}

///|
fn sgo_single_const_global_set_idx(
  instrs : Array[@lib.Instruction],
) -> @lib.GlobalIdx? {
  let flat : Array[@lib.Instruction] = []
  if !sgo_collect_read_only_to_write_body(instrs, flat) {
    return None
  }
  let start = sgo_skip_noop_const_drops(flat)
  if start + 2 != flat.length() {
    return None
  }
  match (flat[start], flat[start + 1]) {
    (value, @lib.GlobalSet(set_idx)) if sgo_const_instr(value) != None =>
      Some(set_idx)
    _ => None
  }
}

///|
fn sgo_instrs_are_single_const_global_set(
  instrs : Array[@lib.Instruction],
  idx : @lib.GlobalIdx,
) -> Bool {
  match sgo_single_const_global_set_idx(instrs) {
    Some(set_idx) => set_idx == idx
    None => false
  }
}

///|
fn sgo_instrs_are_const_global_set_with_nested_guards(
  instrs : Array[@lib.Instruction],
  idx : @lib.GlobalIdx,
  infos : Array[SgoGlobalInfo],
) -> Bool {
  let flat : Array[@lib.Instruction] = []
  if !sgo_collect_read_only_to_write_body(instrs, flat) {
    return false
  }
  let mut seen_target_set = false
  let mut seen_nested_guard = false
  let mut scan = 0
  while scan < flat.length() {
    if scan + 1 < flat.length() &&
      sgo_const_instr(flat[scan]) != None &&
      flat[scan + 1] == @lib.Instruction::drop() {
      scan = scan + 2
      continue
    }
    if scan + 1 < flat.length() {
      match (flat[scan], flat[scan + 1]) {
        (value, @lib.GlobalSet(set_idx)) if set_idx == idx &&
          sgo_const_instr(value) != None => {
          if seen_target_set {
            return false
          }
          seen_target_set = true
          scan = scan + 2
          continue
        }
        (@lib.GlobalGet(nested_idx), if_instr) if nested_idx != idx &&
          sgo_global_has_one_read(infos, nested_idx) &&
          (
            sgo_if_is_read_only_to_write_set(if_instr, nested_idx) ||
            sgo_if_is_nested_multiglobal_read_only_to_write_set(
              if_instr, nested_idx, infos,
            )
          ) => {
          seen_nested_guard = true
          scan = scan + 2
          continue
        }
        _ => ()
      }
    }
    return false
  }
  seen_target_set && seen_nested_guard
}

///|
fn sgo_global_has_one_read(
  infos : Array[SgoGlobalInfo],
  idx : @lib.GlobalIdx,
) -> Bool {
  let slot = sgo_global_idx_slot(idx)
  slot >= 0 && slot < infos.length() && infos[slot].read_count == 1
}

///|
fn sgo_if_is_nested_multiglobal_read_only_to_write_set(
  instr : @lib.Instruction,
  idx : @lib.GlobalIdx,
  infos : Array[SgoGlobalInfo],
) -> Bool {
  match instr {
    @lib.If(_, then_body, None) =>
      sgo_instrs_are_const_global_set_with_nested_guards(then_body, idx, infos)
    _ => false
  }
}

///|
fn sgo_count_nested_multiglobal_read_only_to_write_expr(
  expr : @lib.Expr,
  safe_reads : Array[Int],
  infos : Array[SgoGlobalInfo],
) -> Unit {
  let @lib.Expr(instrs) = expr
  sgo_count_nested_multiglobal_read_only_to_write_instrs(
    instrs, safe_reads, infos,
  )
}

///|
fn sgo_count_nested_multiglobal_read_only_to_write_instrs(
  instrs : Array[@lib.Instruction],
  safe_reads : Array[Int],
  infos : Array[SgoGlobalInfo],
) -> Unit {
  for pos = 0; pos < instrs.length(); pos = pos + 1 {
    match instrs[pos] {
      @lib.GlobalGet(idx) if pos + 1 < instrs.length() &&
        sgo_if_is_nested_multiglobal_read_only_to_write_set(
          instrs[pos + 1],
          idx,
          infos,
        ) => sgo_count_read_only_to_write_safe_read(idx, safe_reads)
      @lib.Block(_, body) | @lib.Loop(_, body) | @lib.TryTable(_, _, body) =>
        sgo_count_nested_multiglobal_read_only_to_write_expr(
          body, safe_reads, infos,
        )
      @lib.If(_, then_body, else_body) => {
        sgo_count_nested_multiglobal_read_only_to_write_instrs(
          then_body, safe_reads, infos,
        )
        match else_body {
          Some(body) =>
            sgo_count_nested_multiglobal_read_only_to_write_instrs(
              body, safe_reads, infos,
            )
          None => ()
        }
      }
      _ => ()
    }
  }
}

///|
fn sgo_collect_read_only_to_write_condition_body(
  instrs : Array[@lib.Instruction],
  out : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Nop => ()
      @lib.Block(_, body) => {
        let @lib.Expr(body_instrs) = body
        if !sgo_collect_read_only_to_write_condition_body(body_instrs, out) {
          return false
        }
      }
      _ => out.push(instr)
    }
  }
  true
}

///|
fn sgo_block_condition_direct_read_idx(
  instrs : Array[@lib.Instruction],
) -> @lib.GlobalIdx? {
  let flat : Array[@lib.Instruction] = []
  if !sgo_collect_read_only_to_write_condition_body(instrs, flat) {
    return None
  }
  let start = sgo_skip_noop_const_drops(flat)
  if start + 1 == flat.length() {
    match flat[start] {
      @lib.GlobalGet(idx) => return Some(idx)
      _ => ()
    }
  }
  None
}

///|
fn sgo_block_condition_single_read_idx(
  instrs : Array[@lib.Instruction],
) -> @lib.GlobalIdx? {
  match sgo_block_condition_direct_read_idx(instrs) {
    Some(idx) => return Some(idx)
    None => ()
  }
  let flat : Array[@lib.Instruction] = []
  if !sgo_collect_read_only_to_write_condition_body(instrs, flat) {
    return None
  }
  let start = sgo_skip_noop_const_drops(flat)
  if start + 2 == flat.length() &&
    flat[start + 1] == @lib.Instruction::i32_eqz() {
    match flat[start] {
      @lib.GlobalGet(idx) => return Some(idx)
      _ => ()
    }
  }
  None
}

///|
fn sgo_block_condition_safe_arm_read_idx(
  instrs : Array[@lib.Instruction],
) -> @lib.GlobalIdx? {
  match sgo_block_condition_direct_read_idx(instrs) {
    Some(idx) => return Some(idx)
    None => ()
  }
  let flat : Array[@lib.Instruction] = []
  if !sgo_collect_read_only_to_write_condition_body(instrs, flat) {
    return None
  }
  let start = sgo_skip_noop_const_drops(flat)
  if start >= flat.length() {
    return None
  }
  match flat[start] {
    @lib.GlobalGet(idx) => {
      for scan = start + 1; scan < flat.length(); scan = scan + 1 {
        if !sgo_is_read_only_to_write_pure_condition_instr(flat[scan]) {
          return None
        }
      }
      Some(idx)
    }
    @lib.If(_, _, Some(_)) =>
      match sgo_if_arm_condition_read_idx(flat[start]) {
        Some(idx) => {
          for scan = start + 1; scan < flat.length(); scan = scan + 1 {
            if !sgo_is_read_only_to_write_pure_condition_instr(flat[scan]) {
              return None
            }
          }
          Some(idx)
        }
        None => None
      }
    _ => {
      for if_pos = start; if_pos < flat.length(); if_pos = if_pos + 1 {
        match flat[if_pos] {
          @lib.If(_, _, Some(_)) =>
            match sgo_if_arm_condition_read_idx(flat[if_pos]) {
              Some(idx) => {
                for scan = start; scan < if_pos; scan = scan + 1 {
                  if sgo_instr_may_reference_global(flat[scan]) {
                    return None
                  }
                }
                for scan = if_pos + 1; scan < flat.length(); scan = scan + 1 {
                  if !sgo_is_read_only_to_write_pure_condition_instr(flat[scan]) {
                    return None
                  }
                }
                return Some(idx)
              }
              None => ()
            }
          _ => ()
        }
      }
      None
    }
  }
}

///|
fn sgo_block_condition_final_read_matches(
  instrs : Array[@lib.Instruction],
  idx : @lib.GlobalIdx,
) -> Bool {
  let flat : Array[@lib.Instruction] = []
  if !sgo_collect_read_only_to_write_condition_body(instrs, flat) {
    return false
  }
  let len = flat.length()
  if len < 3 {
    return false
  }
  let cmp = flat[len - 1]
  if cmp != @lib.Instruction::i32_eq() && cmp != @lib.Instruction::i32_ne() {
    return false
  }
  match (flat[len - 3], flat[len - 2]) {
    (@lib.GlobalGet(get_idx), const_instr) =>
      get_idx == idx && sgo_const_instr(const_instr) != None
    (const_instr, @lib.GlobalGet(get_idx)) =>
      get_idx == idx && sgo_const_instr(const_instr) != None
    _ => false
  }
}

///|
fn sgo_block_condition_pure_read_matches(
  instrs : Array[@lib.Instruction],
  idx : @lib.GlobalIdx,
) -> Bool {
  let flat : Array[@lib.Instruction] = []
  if !sgo_collect_read_only_to_write_condition_body(instrs, flat) {
    return false
  }
  let start = sgo_skip_noop_const_drops(flat)
  if start >= flat.length() {
    return false
  }
  match flat[start] {
    @lib.GlobalGet(get_idx) if get_idx == idx => ()
    _ => return false
  }
  for scan = start + 1; scan < flat.length(); scan = scan + 1 {
    if !sgo_is_read_only_to_write_pure_condition_instr(flat[scan]) {
      return false
    }
  }
  true
}

///|
fn sgo_flat_prefix_is_read_only_to_write_guard(
  flat : Array[@lib.Instruction],
  start : Int,
  end_exclusive : Int,
  idx : @lib.GlobalIdx,
) -> Bool {
  if end_exclusive <= start + 1 || end_exclusive > flat.length() {
    return false
  }
  match flat[start] {
    @lib.GlobalGet(get_idx) if get_idx == idx => ()
    _ => return false
  }
  if !sgo_if_is_read_only_to_write_set(flat[end_exclusive - 1], idx) {
    return false
  }
  for scan = start + 1; scan < end_exclusive - 1; scan = scan + 1 {
    if !sgo_is_read_only_to_write_pure_condition_instr(flat[scan]) {
      return false
    }
  }
  true
}

///|
fn sgo_block_condition_nested_guard_final_read_matches(
  instrs : Array[@lib.Instruction],
  idx : @lib.GlobalIdx,
) -> Bool {
  let flat : Array[@lib.Instruction] = []
  if !sgo_collect_read_only_to_write_condition_body(instrs, flat) {
    return false
  }
  let start = sgo_skip_noop_const_drops(flat)
  let len = flat.length()
  if start + 2 >= len {
    return false
  }
  match flat[len - 1] {
    @lib.GlobalGet(get_idx) if get_idx == idx =>
      sgo_flat_prefix_is_read_only_to_write_guard(flat, start, len - 1, idx)
    _ => false
  }
}

///|
fn sgo_external_condition_stack_after(
  instr : @lib.Instruction,
  depth : Int,
) -> Int? {
  match sgo_const_instr(instr) {
    Some(_) => return Some(depth + 1)
    None => ()
  }
  match instr {
    @lib.I32Clz
    | @lib.I32Ctz
    | @lib.I32Popcnt
    | @lib.I32Eqz
    | @lib.I64Clz
    | @lib.I64Ctz
    | @lib.I64Popcnt
    | @lib.I64Eqz => if depth >= 1 { Some(depth) } else { None }
    _ =>
      if sgo_is_read_only_to_write_pure_condition_instr(instr) && depth >= 2 {
        Some(depth - 1)
      } else {
        None
      }
  }
}

///|
fn sgo_is_short_block_condition_external_legacy(
  instrs : Array[@lib.Instruction],
  pos : Int,
  if_index : Int,
) -> Bool {
  let start = pos + 1
  let len = if_index - start
  if len == 1 {
    return instrs[start] == @lib.Instruction::i32_eqz()
  }
  if len == 2 {
    return sgo_const_instr(instrs[start]) != None &&
      sgo_is_compare_instr(instrs[start + 1])
  }
  false
}

///|
fn sgo_is_short_block_condition_external_reverse_legacy(
  instrs : Array[@lib.Instruction],
  pos : Int,
  if_index : Int,
) -> Bool {
  pos > 0 &&
  if_index == pos + 2 &&
  sgo_const_instr(instrs[pos - 1]) != None &&
  sgo_is_compare_instr(instrs[pos + 1])
}

///|
fn sgo_block_condition_external_pure_if_index_with_depth(
  instrs : Array[@lib.Instruction],
  pos : Int,
  initial_depth : Int,
  reverse_legacy : Bool,
) -> Int? {
  let mut depth = initial_depth
  let mut pure_count = 0
  for scan = pos + 1; scan < instrs.length(); scan = scan + 1 {
    match instrs[scan] {
      @lib.If(_, _, _) => {
        let legacy = sgo_is_short_block_condition_external_legacy(
            instrs, pos, scan,
          ) ||
          (
            reverse_legacy &&
            sgo_is_short_block_condition_external_reverse_legacy(
              instrs, pos, scan,
            )
          )
        if pure_count > 0 && depth == 1 && !legacy {
          return Some(scan)
        } else {
          return None
        }
      }
      instr =>
        match sgo_external_condition_stack_after(instr, depth) {
          Some(next_depth) => {
            depth = next_depth
            pure_count = pure_count + 1
          }
          None => return None
        }
    }
  }
  None
}

///|
fn sgo_block_condition_external_pure_if_index(
  instrs : Array[@lib.Instruction],
  pos : Int,
) -> Int? {
  sgo_block_condition_external_pure_if_index_with_depth(instrs, pos, 1, false)
}

///|
fn sgo_block_condition_reverse_external_pure_if_index(
  instrs : Array[@lib.Instruction],
  pos : Int,
) -> Int? {
  if pos <= 0 || sgo_const_instr(instrs[pos - 1]) == None {
    return None
  }
  sgo_block_condition_external_pure_if_index_with_depth(instrs, pos, 2, true)
}

///|
fn sgo_count_block_condition_external_pure_read(
  instrs : Array[@lib.Instruction],
  pos : Int,
  safe_reads : Array[Int],
) -> Unit {
  match instrs[pos] {
    @lib.Block(_, @lib.Expr(body)) =>
      match sgo_block_condition_external_pure_if_index(instrs, pos) {
        Some(if_index) =>
          match instrs[if_index] {
            @lib.If(_, then_body, None) =>
              match sgo_single_const_global_set_idx(then_body) {
                Some(idx) =>
                  sgo_count_block_condition_safe_body_read(
                    body, idx, safe_reads,
                  )
                None => ()
              }
            _ => ()
          }
        None => ()
      }
    _ => ()
  }
}

///|
fn sgo_count_block_condition_external_pure_if_return_read(
  instrs : Array[@lib.Instruction],
  pos : Int,
  safe_reads : Array[Int],
) -> Unit {
  match instrs[pos] {
    @lib.Block(_, @lib.Expr(body)) =>
      match sgo_block_condition_external_pure_if_index(instrs, pos) {
        Some(if_index) if sgo_is_return_guard(instrs[if_index]) =>
          if if_index + 3 == instrs.length() {
            match instrs[if_index + 2] {
              @lib.GlobalSet(idx) if sgo_const_instr(instrs[if_index + 1]) !=
                None =>
                sgo_count_block_condition_safe_body_read(body, idx, safe_reads)
              _ => ()
            }
          } else if if_index + 2 == instrs.length() {
            match sgo_block_set_tail_idx(instrs[if_index + 1]) {
              Some(idx) =>
                sgo_count_block_condition_safe_body_read(body, idx, safe_reads)
              None => ()
            }
          }
        _ => ()
      }
    _ => ()
  }
}

///|
fn sgo_count_block_condition_reverse_external_pure_read(
  instrs : Array[@lib.Instruction],
  pos : Int,
  safe_reads : Array[Int],
) -> Unit {
  match instrs[pos] {
    @lib.Block(_, @lib.Expr(body)) =>
      match sgo_block_condition_reverse_external_pure_if_index(instrs, pos) {
        Some(if_index) =>
          match instrs[if_index] {
            @lib.If(_, then_body, None) =>
              match sgo_single_const_global_set_idx(then_body) {
                Some(idx) =>
                  sgo_count_block_condition_safe_body_read(
                    body, idx, safe_reads,
                  )
                None => ()
              }
            _ => ()
          }
        None => ()
      }
    _ => ()
  }
}

///|
fn sgo_count_block_condition_reverse_external_pure_if_return_read(
  instrs : Array[@lib.Instruction],
  pos : Int,
  safe_reads : Array[Int],
) -> Unit {
  match instrs[pos] {
    @lib.Block(_, @lib.Expr(body)) =>
      match sgo_block_condition_reverse_external_pure_if_index(instrs, pos) {
        Some(if_index) if sgo_is_return_guard(instrs[if_index]) =>
          if if_index + 3 == instrs.length() {
            match instrs[if_index + 2] {
              @lib.GlobalSet(idx) if sgo_const_instr(instrs[if_index + 1]) !=
                None =>
                sgo_count_block_condition_safe_body_read(body, idx, safe_reads)
              _ => ()
            }
          } else if if_index + 2 == instrs.length() {
            match sgo_block_set_tail_idx(instrs[if_index + 1]) {
              Some(idx) =>
                sgo_count_block_condition_safe_body_read(body, idx, safe_reads)
              None => ()
            }
          }
        _ => ()
      }
    _ => ()
  }
}

///|
fn sgo_count_block_condition_read_only_to_write_read(
  instr : @lib.Instruction,
  next : @lib.Instruction,
  safe_reads : Array[Int],
) -> Unit {
  match (instr, next) {
    (@lib.Block(_, @lib.Expr(body)), @lib.If(_, then_body, None)) =>
      match sgo_single_const_global_set_idx(then_body) {
        Some(idx) if sgo_block_condition_final_read_matches(body, idx) ||
          sgo_block_condition_pure_read_matches(body, idx) =>
          sgo_count_read_only_to_write_safe_read(idx, safe_reads)
        Some(idx) =>
          match sgo_block_condition_single_read_idx(body) {
            Some(read_idx) if read_idx == idx =>
              sgo_count_read_only_to_write_safe_read(idx, safe_reads)
            _ => ()
          }
        None => ()
      }
    _ => ()
  }
}

///|
fn sgo_block_condition_independent_call_final_read_idx(
  instrs : Array[@lib.Instruction],
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> @lib.GlobalIdx? {
  let flat : Array[@lib.Instruction] = []
  if !sgo_collect_read_only_to_write_condition_body(instrs, flat) {
    return None
  }
  match flat {
    [@lib.Call(func_idx), @lib.Drop, @lib.GlobalGet(idx)] if sgo_call_has_no_params_one_result(
        mod_, func_type_indices, func_idx,
      ) => Some(idx)
    [@lib.Call(func_idx), @lib.GlobalGet(idx)] if sgo_call_has_no_params_no_results(
        mod_, func_type_indices, func_idx,
      ) => Some(idx)
    _ => None
  }
}

///|
fn sgo_block_condition_independent_memory_final_read_idx(
  instrs : Array[@lib.Instruction],
) -> @lib.GlobalIdx? {
  let flat : Array[@lib.Instruction] = []
  if !sgo_collect_read_only_to_write_condition_body(instrs, flat) {
    return None
  }
  match flat {
    [@lib.MemorySize(_), @lib.Drop, @lib.GlobalGet(idx)] => Some(idx)
    [grow_delta, @lib.MemoryGrow(_), @lib.Drop, @lib.GlobalGet(idx)] if sgo_const_instr(
        grow_delta,
      ) !=
      None => Some(idx)
    _ => None
  }
}

///|
fn sgo_block_condition_independent_table_final_read_idx(
  instrs : Array[@lib.Instruction],
) -> @lib.GlobalIdx? {
  let flat : Array[@lib.Instruction] = []
  if !sgo_collect_read_only_to_write_condition_body(instrs, flat) {
    return None
  }
  match flat {
    [@lib.TableSize(_), @lib.Drop, @lib.GlobalGet(idx)] => Some(idx)
    [ref_value, grow_delta, @lib.TableGrow(_), @lib.Drop, @lib.GlobalGet(idx)] if sgo_const_instr(
        ref_value,
      ) !=
      None &&
      sgo_const_instr(grow_delta) != None => Some(idx)
    [dest, value, @lib.TableSet(_), @lib.GlobalGet(idx)] if sgo_const_instr(
        dest,
      ) !=
      None &&
      sgo_const_instr(value) != None => Some(idx)
    [dest, value, len, @lib.TableFill(_), @lib.GlobalGet(idx)] if sgo_const_instr(
        dest,
      ) !=
      None &&
      sgo_const_instr(value) != None &&
      sgo_const_instr(len) != None => Some(idx)
    [dest, src, len, @lib.TableCopy(_, _), @lib.GlobalGet(idx)] if sgo_const_instr(
        dest,
      ) !=
      None &&
      sgo_const_instr(src) != None &&
      sgo_const_instr(len) != None => Some(idx)
    [dest, src, len, @lib.TableInit(_, _), @lib.GlobalGet(idx)] if sgo_const_instr(
        dest,
      ) !=
      None &&
      sgo_const_instr(src) != None &&
      sgo_const_instr(len) != None => Some(idx)
    [@lib.ElemDrop(_), @lib.GlobalGet(idx)] => Some(idx)
    _ => None
  }
}

///|
fn sgo_block_condition_independent_local_final_read_idx(
  instrs : Array[@lib.Instruction],
) -> @lib.GlobalIdx? {
  let flat : Array[@lib.Instruction] = []
  if !sgo_collect_read_only_to_write_condition_body(instrs, flat) {
    return None
  }
  match flat {
    [value, @lib.LocalSet(_), @lib.GlobalGet(idx)] if sgo_const_instr(value) !=
      None => Some(idx)
    [value, @lib.LocalTee(_), @lib.Drop, @lib.GlobalGet(idx)] if sgo_const_instr(
        value,
      ) !=
      None => Some(idx)
    _ => None
  }
}

///|
fn sgo_block_condition_independent_local_compare_read_matches(
  instrs : Array[@lib.Instruction],
  idx : @lib.GlobalIdx,
) -> Bool {
  let flat : Array[@lib.Instruction] = []
  if !sgo_collect_read_only_to_write_condition_body(instrs, flat) {
    return false
  }
  if flat.length() != 5 ||
    !sgo_local_effect_value_is_independent(flat[0]) ||
    !sgo_is_compare_instr(flat[4]) {
    return false
  }
  match flat[1] {
    @lib.LocalSet(local_idx) =>
      match (flat[2], flat[3]) {
        (@lib.GlobalGet(read_idx), @lib.LocalGet(get_idx)) =>
          read_idx == idx && get_idx == local_idx
        (@lib.LocalGet(get_idx), @lib.GlobalGet(read_idx)) =>
          read_idx == idx && get_idx == local_idx
        _ => false
      }
    _ => false
  }
}

///|
fn sgo_block_condition_independent_global_set_final_read_idx(
  instrs : Array[@lib.Instruction],
) -> @lib.GlobalIdx? {
  let flat : Array[@lib.Instruction] = []
  if !sgo_collect_read_only_to_write_condition_body(instrs, flat) {
    return None
  }
  match flat {
    [value, @lib.GlobalSet(set_idx), @lib.GlobalGet(idx)] if set_idx != idx &&
      sgo_const_instr(value) != None => Some(idx)
    _ => None
  }
}

///|
fn sgo_count_block_condition_independent_memory_read_only_to_write_read(
  instr : @lib.Instruction,
  next : @lib.Instruction,
  safe_reads : Array[Int],
) -> Unit {
  match (instr, next) {
    (@lib.Block(_, @lib.Expr(body)), @lib.If(_, then_body, None)) =>
      match sgo_single_const_global_set_idx(then_body) {
        Some(idx) =>
          match sgo_block_condition_independent_memory_final_read_idx(body) {
            Some(read_idx) if read_idx == idx =>
              sgo_count_read_only_to_write_safe_read(idx, safe_reads)
            _ => ()
          }
        None => ()
      }
    _ => ()
  }
}

///|
fn sgo_count_block_condition_independent_table_read_only_to_write_read(
  instr : @lib.Instruction,
  next : @lib.Instruction,
  safe_reads : Array[Int],
) -> Unit {
  match (instr, next) {
    (@lib.Block(_, @lib.Expr(body)), @lib.If(_, then_body, None)) =>
      match sgo_single_const_global_set_idx(then_body) {
        Some(idx) =>
          match sgo_block_condition_independent_table_final_read_idx(body) {
            Some(read_idx) if read_idx == idx =>
              sgo_count_read_only_to_write_safe_read(idx, safe_reads)
            _ => ()
          }
        None => ()
      }
    _ => ()
  }
}

///|
fn sgo_count_block_condition_independent_local_read_only_to_write_read(
  instr : @lib.Instruction,
  next : @lib.Instruction,
  safe_reads : Array[Int],
) -> Unit {
  match (instr, next) {
    (@lib.Block(_, @lib.Expr(body)), @lib.If(_, then_body, None)) =>
      match sgo_single_const_global_set_idx(then_body) {
        Some(idx) => {
          if sgo_block_condition_independent_local_compare_read_matches(
              body, idx,
            ) {
            sgo_count_read_only_to_write_safe_read(idx, safe_reads)
            return
          }
          match sgo_block_condition_independent_local_final_read_idx(body) {
            Some(read_idx) if read_idx == idx =>
              sgo_count_read_only_to_write_safe_read(idx, safe_reads)
            _ => ()
          }
        }
        None => ()
      }
    _ => ()
  }
}

///|
fn sgo_count_block_condition_independent_global_set_read_only_to_write_read(
  instr : @lib.Instruction,
  next : @lib.Instruction,
  safe_reads : Array[Int],
) -> Unit {
  match (instr, next) {
    (@lib.Block(_, @lib.Expr(body)), @lib.If(_, then_body, None)) =>
      match sgo_single_const_global_set_idx(then_body) {
        Some(idx) =>
          match
            sgo_block_condition_independent_global_set_final_read_idx(body) {
            Some(read_idx) if read_idx == idx =>
              sgo_count_read_only_to_write_safe_read(idx, safe_reads)
            _ => ()
          }
        None => ()
      }
    _ => ()
  }
}

///|
fn sgo_count_block_condition_independent_call_read_only_to_write_read(
  instr : @lib.Instruction,
  next : @lib.Instruction,
  safe_reads : Array[Int],
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> Unit {
  match (instr, next) {
    (@lib.Block(_, @lib.Expr(body)), @lib.If(_, then_body, None)) =>
      match sgo_single_const_global_set_idx(then_body) {
        Some(idx) =>
          match
            sgo_block_condition_independent_call_final_read_idx(
              body, mod_, func_type_indices,
            ) {
            Some(read_idx) if read_idx == idx =>
              sgo_count_read_only_to_write_safe_read(idx, safe_reads)
            _ => ()
          }
        None => ()
      }
    _ => ()
  }
}

///|
fn sgo_count_block_condition_independent_call_if_return_read(
  instrs : Array[@lib.Instruction],
  pos : Int,
  safe_reads : Array[Int],
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> Unit {
  if pos + 2 >= instrs.length() {
    return
  }
  match instrs[pos] {
    @lib.Block(_, @lib.Expr(body)) if sgo_is_return_guard(instrs[pos + 1]) =>
      match
        sgo_block_condition_independent_call_final_read_idx(
          body, mod_, func_type_indices,
        ) {
        Some(idx) =>
          if sgo_if_return_tail_matches(instrs, pos + 2, idx) {
            sgo_count_read_only_to_write_safe_read(idx, safe_reads)
          }
        None => ()
      }
    _ => ()
  }
}

///|
fn sgo_count_block_condition_independent_memory_if_return_read(
  instrs : Array[@lib.Instruction],
  pos : Int,
  safe_reads : Array[Int],
) -> Unit {
  if pos + 2 >= instrs.length() {
    return
  }
  match instrs[pos] {
    @lib.Block(_, @lib.Expr(body)) if sgo_is_return_guard(instrs[pos + 1]) =>
      match sgo_block_condition_independent_memory_final_read_idx(body) {
        Some(idx) =>
          if sgo_if_return_tail_matches(instrs, pos + 2, idx) {
            sgo_count_read_only_to_write_safe_read(idx, safe_reads)
          }
        None => ()
      }
    _ => ()
  }
}

///|
fn sgo_count_block_condition_independent_table_if_return_read(
  instrs : Array[@lib.Instruction],
  pos : Int,
  safe_reads : Array[Int],
) -> Unit {
  if pos + 2 >= instrs.length() {
    return
  }
  match instrs[pos] {
    @lib.Block(_, @lib.Expr(body)) if sgo_is_return_guard(instrs[pos + 1]) =>
      match sgo_block_condition_independent_table_final_read_idx(body) {
        Some(idx) =>
          if sgo_if_return_tail_matches(instrs, pos + 2, idx) {
            sgo_count_read_only_to_write_safe_read(idx, safe_reads)
          }
        None => ()
      }
    _ => ()
  }
}

///|
fn sgo_count_block_condition_independent_local_if_return_read(
  instrs : Array[@lib.Instruction],
  pos : Int,
  safe_reads : Array[Int],
) -> Unit {
  if pos + 2 >= instrs.length() {
    return
  }
  match instrs[pos] {
    @lib.Block(_, @lib.Expr(body)) if sgo_is_return_guard(instrs[pos + 1]) =>
      match sgo_block_condition_independent_local_final_read_idx(body) {
        Some(idx) =>
          if sgo_if_return_tail_matches(instrs, pos + 2, idx) {
            sgo_count_read_only_to_write_safe_read(idx, safe_reads)
          }
        None => ()
      }
    _ => ()
  }
}

///|
fn sgo_count_block_condition_independent_global_set_if_return_read(
  instrs : Array[@lib.Instruction],
  pos : Int,
  safe_reads : Array[Int],
) -> Unit {
  if pos + 2 >= instrs.length() {
    return
  }
  match instrs[pos] {
    @lib.Block(_, @lib.Expr(body)) if sgo_is_return_guard(instrs[pos + 1]) =>
      match sgo_block_condition_independent_global_set_final_read_idx(body) {
        Some(idx) =>
          if sgo_if_return_tail_matches(instrs, pos + 2, idx) {
            sgo_count_read_only_to_write_safe_read(idx, safe_reads)
          }
        None => ()
      }
    _ => ()
  }
}

///|
fn sgo_count_block_condition_safe_body_read(
  body : Array[@lib.Instruction],
  idx : @lib.GlobalIdx,
  safe_reads : Array[Int],
) -> Unit {
  if sgo_block_condition_final_read_matches(body, idx) ||
    sgo_block_condition_pure_read_matches(body, idx) ||
    sgo_block_condition_nested_guard_final_read_matches(body, idx) ||
    sgo_block_condition_independent_local_compare_read_matches(body, idx) {
    sgo_count_read_only_to_write_safe_read(idx, safe_reads)
  } else {
    match sgo_block_condition_single_read_idx(body) {
      Some(read_idx) if read_idx == idx =>
        sgo_count_read_only_to_write_safe_read(idx, safe_reads)
      _ => ()
    }
  }
}

///|
fn sgo_count_block_condition_if_return_body_read(
  body : Array[@lib.Instruction],
  idx : @lib.GlobalIdx,
  safe_reads : Array[Int],
) -> Unit {
  sgo_count_block_condition_safe_body_read(body, idx, safe_reads)
}

///|
fn sgo_count_block_condition_eqz_read_only_to_write_read(
  instr : @lib.Instruction,
  eqz : @lib.Instruction,
  if_instr : @lib.Instruction,
  safe_reads : Array[Int],
) -> Unit {
  match (instr, if_instr) {
    (@lib.Block(_, @lib.Expr(body)), @lib.If(_, then_body, None)) if eqz ==
      @lib.Instruction::i32_eqz() =>
      match sgo_single_const_global_set_idx(then_body) {
        Some(idx) =>
          sgo_count_block_condition_safe_body_read(body, idx, safe_reads)
        None => ()
      }
    _ => ()
  }
}

///|
fn sgo_count_block_condition_compare_read_only_to_write_read(
  instr : @lib.Instruction,
  const_instr : @lib.Instruction,
  cmp_instr : @lib.Instruction,
  if_instr : @lib.Instruction,
  safe_reads : Array[Int],
) -> Unit {
  match (instr, if_instr) {
    (@lib.Block(_, @lib.Expr(body)), @lib.If(_, then_body, None)) if sgo_const_instr(
        const_instr,
      ) !=
      None &&
      sgo_is_compare_instr(cmp_instr) =>
      match sgo_single_const_global_set_idx(then_body) {
        Some(idx) =>
          sgo_count_block_condition_safe_body_read(body, idx, safe_reads)
        None => ()
      }
    _ => ()
  }
}

///|
fn sgo_count_block_condition_reverse_compare_read_only_to_write_read(
  instrs : Array[@lib.Instruction],
  pos : Int,
  safe_reads : Array[Int],
) -> Unit {
  if pos <= 0 || pos + 2 >= instrs.length() {
    return
  }
  let const_instr = instrs[pos - 1]
  let instr = instrs[pos]
  let cmp_instr = instrs[pos + 1]
  let if_instr = instrs[pos + 2]
  match (instr, if_instr) {
    (@lib.Block(_, @lib.Expr(body)), @lib.If(_, then_body, None)) if sgo_const_instr(
        const_instr,
      ) !=
      None &&
      sgo_is_compare_instr(cmp_instr) =>
      match sgo_single_const_global_set_idx(then_body) {
        Some(idx) =>
          sgo_count_block_condition_safe_body_read(body, idx, safe_reads)
        None => ()
      }
    _ => ()
  }
}

///|
fn sgo_count_block_condition_if_return_block_set_read(
  instr : @lib.Instruction,
  next : @lib.Instruction,
  block_tail : @lib.Instruction,
  safe_reads : Array[Int],
) -> Unit {
  match (instr, next, block_tail) {
    (
      @lib.Block(_, @lib.Expr(body)),
      if_instr,
      @lib.Block(@lib.VoidBlockType, @lib.Expr(tail)),
    ) if sgo_is_return_guard(if_instr) =>
      match sgo_single_const_global_set_idx(tail) {
        Some(idx) =>
          sgo_count_block_condition_if_return_body_read(body, idx, safe_reads)
        None => ()
      }
    _ => ()
  }
}

///|
fn sgo_count_block_condition_if_return_set_read(
  instr : @lib.Instruction,
  next : @lib.Instruction,
  value : @lib.Instruction,
  set : @lib.Instruction,
  safe_reads : Array[Int],
) -> Unit {
  match (instr, next, set) {
    (@lib.Block(_, @lib.Expr(body)), if_instr, @lib.GlobalSet(idx)) if sgo_is_return_guard(
        if_instr,
      ) &&
      sgo_const_instr(value) != None =>
      sgo_count_block_condition_if_return_body_read(body, idx, safe_reads)
    _ => ()
  }
}

///|
fn sgo_count_block_condition_eqz_if_return_set_read(
  instr : @lib.Instruction,
  eqz : @lib.Instruction,
  if_instr : @lib.Instruction,
  value : @lib.Instruction,
  set : @lib.Instruction,
  safe_reads : Array[Int],
) -> Unit {
  match (instr, set) {
    (@lib.Block(_, @lib.Expr(body)), @lib.GlobalSet(idx)) if eqz ==
      @lib.Instruction::i32_eqz() &&
      sgo_is_return_guard(if_instr) &&
      sgo_const_instr(value) != None =>
      sgo_count_block_condition_safe_body_read(body, idx, safe_reads)
    _ => ()
  }
}

///|
fn sgo_block_set_tail_idx(instr : @lib.Instruction) -> @lib.GlobalIdx? {
  match instr {
    @lib.Block(@lib.VoidBlockType, @lib.Expr(tail)) =>
      sgo_single_const_global_set_idx(tail)
    _ => None
  }
}

///|
fn sgo_count_block_condition_eqz_if_return_block_set_read(
  instr : @lib.Instruction,
  eqz : @lib.Instruction,
  if_instr : @lib.Instruction,
  block_tail : @lib.Instruction,
  safe_reads : Array[Int],
) -> Unit {
  match instr {
    @lib.Block(_, @lib.Expr(body)) if eqz == @lib.Instruction::i32_eqz() &&
      sgo_is_return_guard(if_instr) =>
      match sgo_block_set_tail_idx(block_tail) {
        Some(idx) =>
          sgo_count_block_condition_safe_body_read(body, idx, safe_reads)
        None => ()
      }
    _ => ()
  }
}

///|
fn sgo_count_block_condition_compare_if_return_set_read(
  instr : @lib.Instruction,
  const_instr : @lib.Instruction,
  cmp_instr : @lib.Instruction,
  if_instr : @lib.Instruction,
  value : @lib.Instruction,
  set : @lib.Instruction,
  safe_reads : Array[Int],
) -> Unit {
  match (instr, set) {
    (@lib.Block(_, @lib.Expr(body)), @lib.GlobalSet(idx)) if sgo_const_instr(
        const_instr,
      ) !=
      None &&
      sgo_is_compare_instr(cmp_instr) &&
      sgo_is_return_guard(if_instr) &&
      sgo_const_instr(value) != None =>
      sgo_count_block_condition_safe_body_read(body, idx, safe_reads)
    _ => ()
  }
}

///|
fn sgo_count_block_condition_compare_if_return_block_set_read(
  instr : @lib.Instruction,
  const_instr : @lib.Instruction,
  cmp_instr : @lib.Instruction,
  if_instr : @lib.Instruction,
  block_tail : @lib.Instruction,
  safe_reads : Array[Int],
) -> Unit {
  match instr {
    @lib.Block(_, @lib.Expr(body)) if sgo_const_instr(const_instr) != None &&
      sgo_is_compare_instr(cmp_instr) &&
      sgo_is_return_guard(if_instr) =>
      match sgo_block_set_tail_idx(block_tail) {
        Some(idx) =>
          sgo_count_block_condition_safe_body_read(body, idx, safe_reads)
        None => ()
      }
    _ => ()
  }
}

///|
fn sgo_count_block_condition_reverse_compare_if_return_set_read(
  instrs : Array[@lib.Instruction],
  pos : Int,
  safe_reads : Array[Int],
) -> Unit {
  if pos <= 0 || pos + 4 >= instrs.length() {
    return
  }
  let const_instr = instrs[pos - 1]
  let instr = instrs[pos]
  let cmp_instr = instrs[pos + 1]
  let if_instr = instrs[pos + 2]
  let value = instrs[pos + 3]
  let set = instrs[pos + 4]
  match (instr, set) {
    (@lib.Block(_, @lib.Expr(body)), @lib.GlobalSet(idx)) if sgo_const_instr(
        const_instr,
      ) !=
      None &&
      sgo_is_compare_instr(cmp_instr) &&
      sgo_is_return_guard(if_instr) &&
      sgo_const_instr(value) != None =>
      sgo_count_block_condition_safe_body_read(body, idx, safe_reads)
    _ => ()
  }
}

///|
fn sgo_count_block_condition_reverse_compare_if_return_block_set_read(
  instrs : Array[@lib.Instruction],
  pos : Int,
  safe_reads : Array[Int],
) -> Unit {
  if pos <= 0 || pos + 3 >= instrs.length() {
    return
  }
  let const_instr = instrs[pos - 1]
  let instr = instrs[pos]
  let cmp_instr = instrs[pos + 1]
  let if_instr = instrs[pos + 2]
  let block_tail = instrs[pos + 3]
  match instr {
    @lib.Block(_, @lib.Expr(body)) if sgo_const_instr(const_instr) != None &&
      sgo_is_compare_instr(cmp_instr) &&
      sgo_is_return_guard(if_instr) =>
      match sgo_block_set_tail_idx(block_tail) {
        Some(idx) =>
          sgo_count_block_condition_safe_body_read(body, idx, safe_reads)
        None => ()
      }
    _ => ()
  }
}

///|
fn sgo_plan_remove_sets(
  infos : Array[SgoGlobalInfo],
  same_init_writes : Array[Bool],
  read_only_to_write : Array[Bool],
) -> Array[Bool] {
  let remove_sets = Array::make(infos.length(), false)
  for idx = 0; idx < infos.length(); idx = idx + 1 {
    let info = infos[idx]
    if !info.imported &&
      !info.exported &&
      info.write_count > 0 &&
      (info.read_count == 0 || same_init_writes[idx] || read_only_to_write[idx]) {
      remove_sets[idx] = true
    }
  }
  remove_sets
}

///|
fn sgo_apply_practical_immutability(
  infos : Array[SgoGlobalInfo],
  remove_sets : Array[Bool],
) -> Bool {
  let mut changed = false
  for idx = 0; idx < infos.length(); idx = idx + 1 {
    let info = infos[idx]
    if info.imported || info.exported || !info.mutable_ {
      continue
    }
    if info.write_count == 0 || remove_sets[idx] {
      infos[idx].mutable_ = false
      changed = true
    }
  }
  changed
}

///|
fn sgo_rewrite_instr_with_state(
  instr : @lib.Instruction,
  state : SgoRewriteState,
  rewrite_sets : Bool,
) -> @lib.Instruction {
  match instr {
    @lib.GlobalGet(idx) => {
      let slot = sgo_global_idx_slot(idx)
      if slot >= 0 && slot < state.consts.length() {
        match state.consts[slot] {
          Some(replacement) => {
            state.changed = true
            return replacement
          }
          None => ()
        }
      }
      if slot >= 0 && slot < state.aliases.length() {
        match state.aliases[slot] {
          Some(target_idx) => {
            state.changed = true
            return @lib.Instruction::global_get(target_idx)
          }
          None => ()
        }
      }
      instr
    }
    @lib.GlobalSet(idx) if rewrite_sets => {
      let slot = sgo_global_idx_slot(idx)
      if slot >= 0 &&
        slot < state.remove_sets.length() &&
        state.remove_sets[slot] {
        state.changed = true
        return @lib.Instruction::drop()
      }
      instr
    }
    @lib.Block(block_type, body) =>
      @lib.Instruction::block(
        block_type,
        sgo_rewrite_expr_with_state(body, state, rewrite_sets),
      )
    @lib.Loop(block_type, body) =>
      @lib.Instruction::loop_(
        block_type,
        sgo_rewrite_expr_with_state(body, state, rewrite_sets),
      )
    @lib.If(block_type, then_body, else_body) => {
      let rewritten_then = sgo_rewrite_instrs_with_state(
        then_body, state, rewrite_sets,
      )
      let rewritten_else = match else_body {
        Some(body) =>
          Some(sgo_rewrite_instrs_with_state(body, state, rewrite_sets))
        None => None
      }
      @lib.Instruction::if_(block_type, rewritten_then, rewritten_else)
    }
    @lib.TryTable(block_type, catches, body) =>
      @lib.Instruction::try_table(
        block_type,
        catches,
        sgo_rewrite_expr_with_state(body, state, rewrite_sets),
      )
    _ => instr
  }
}

///|
fn sgo_rewrite_instrs_with_state(
  instrs : Array[@lib.Instruction],
  state : SgoRewriteState,
  rewrite_sets : Bool,
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    out.push(sgo_rewrite_instr_with_state(instr, state, rewrite_sets))
  }
  out
}

///|
fn sgo_rewrite_expr_with_state(
  expr : @lib.Expr,
  state : SgoRewriteState,
  rewrite_sets : Bool,
) -> @lib.Expr {
  let @lib.Expr(instrs) = expr
  @lib.Expr::new(sgo_rewrite_instrs_with_state(instrs, state, rewrite_sets))
}

///|
fn sgo_rewrite_expr(
  expr : @lib.Expr,
  consts : Array[@lib.Instruction?],
  aliases : Array[@lib.GlobalIdx?],
  remove_sets : Array[Bool],
  rewrite_sets : Bool,
) -> (@lib.Expr, Bool) {
  let state = { consts, aliases, remove_sets, changed: false }
  let rewritten = sgo_rewrite_expr_with_state(expr, state, rewrite_sets)
  (rewritten, state.changed)
}

///|
fn sgo_rewrite_global_init_instr_into(
  instr : @lib.Instruction,
  state : SgoGlobalInitRewriteState,
  out : Array[@lib.Instruction],
) -> Unit {
  match instr {
    @lib.GlobalGet(idx) => {
      let slot = sgo_global_idx_slot(idx)
      if slot >= 0 && slot < state.inlines.length() {
        match state.inlines[slot] {
          Some(@lib.Expr(replacement)) => {
            for item in replacement {
              out.push(item)
            }
            state.changed = true
            return
          }
          None => ()
        }
      }
      if slot >= 0 && slot < state.consts.length() {
        match state.consts[slot] {
          Some(replacement) => {
            out.push(replacement)
            state.changed = true
            return
          }
          None => ()
        }
      }
      if slot >= 0 && slot < state.aliases.length() {
        match state.aliases[slot] {
          Some(target_idx) => {
            out.push(@lib.Instruction::global_get(target_idx))
            state.changed = true
            return
          }
          None => ()
        }
      }
      out.push(instr)
    }
    @lib.Block(block_type, body) =>
      out.push(
        @lib.Instruction::block(
          block_type,
          sgo_rewrite_global_init_expr_with_state(body, state),
        ),
      )
    @lib.Loop(block_type, body) =>
      out.push(
        @lib.Instruction::loop_(
          block_type,
          sgo_rewrite_global_init_expr_with_state(body, state),
        ),
      )
    @lib.If(block_type, then_body, else_body) => {
      let rewritten_then = sgo_rewrite_global_init_instrs_with_state(
        then_body, state,
      )
      let rewritten_else = match else_body {
        Some(body) =>
          Some(sgo_rewrite_global_init_instrs_with_state(body, state))
        None => None
      }
      out.push(
        @lib.Instruction::if_(block_type, rewritten_then, rewritten_else),
      )
    }
    @lib.TryTable(block_type, catches, body) =>
      out.push(
        @lib.Instruction::try_table(
          block_type,
          catches,
          sgo_rewrite_global_init_expr_with_state(body, state),
        ),
      )
    _ => out.push(instr)
  }
}

///|
fn sgo_rewrite_global_init_instrs_with_state(
  instrs : Array[@lib.Instruction],
  state : SgoGlobalInitRewriteState,
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    sgo_rewrite_global_init_instr_into(instr, state, out)
  }
  out
}

///|
fn sgo_rewrite_global_init_expr_with_state(
  expr : @lib.Expr,
  state : SgoGlobalInitRewriteState,
) -> @lib.Expr {
  let @lib.Expr(instrs) = expr
  @lib.Expr::new(sgo_rewrite_global_init_instrs_with_state(instrs, state))
}

///|
fn sgo_rewrite_global_init_expr(
  expr : @lib.Expr,
  consts : Array[@lib.Instruction?],
  aliases : Array[@lib.GlobalIdx?],
  inlines : Array[@lib.Expr?],
) -> (@lib.Expr, Bool) {
  let state = { consts, aliases, inlines, changed: false }
  let rewritten = sgo_rewrite_global_init_expr_with_state(expr, state)
  (rewritten, state.changed)
}

///|
fn sgo_build_initial_startup_consts(
  infos : Array[SgoGlobalInfo],
) -> Array[@lib.Instruction?] {
  let consts = sgo_empty_const_array(infos.length())
  for idx = 0; idx < infos.length(); idx = idx + 1 {
    let info = infos[idx]
    if info.imported {
      continue
    }
    match info.init {
      Some(expr) => consts[idx] = sgo_expr_single_const(expr)
      None => ()
    }
  }
  consts
}

///|
fn sgo_build_code_consts(
  infos : Array[SgoGlobalInfo],
) -> Array[@lib.Instruction?] {
  let consts = sgo_empty_const_array(infos.length())
  for idx = 0; idx < infos.length(); idx = idx + 1 {
    let info = infos[idx]
    if info.imported || info.mutable_ {
      continue
    }
    match info.init {
      Some(expr) => consts[idx] = sgo_expr_single_const(expr)
      None => ()
    }
  }
  consts
}

///|
fn sgo_record_alias_for_global(
  aliases : Array[@lib.GlobalIdx?],
  infos : Array[SgoGlobalInfo],
  abs_idx : Int,
  init : @lib.Expr,
) -> Unit {
  if abs_idx < 0 || abs_idx >= infos.length() || infos[abs_idx].mutable_ {
    return
  }
  match init {
    @lib.Expr([@lib.GlobalGet(dep)]) => {
      let dep_slot = sgo_global_idx_slot(dep)
      if dep_slot < 0 || dep_slot >= infos.length() || infos[dep_slot].mutable_ {
        return
      }
      if infos[dep_slot].value_type != infos[abs_idx].value_type {
        return
      }
      aliases[abs_idx] = match aliases[dep_slot] {
        Some(target_idx) => Some(target_idx)
        None => Some(dep)
      }
    }
    _ => ()
  }
}

///|
fn sgo_rewrite_global_sec(
  global_sec : @lib.GlobalSec?,
  infos : Array[SgoGlobalInfo],
  imported_globals : Int,
) -> (@lib.GlobalSec?, Array[@lib.Instruction?], Array[@lib.GlobalIdx?], Bool) {
  let startup_consts = sgo_build_initial_startup_consts(infos)
  let aliases = sgo_empty_global_idx_array(infos.length())
  let init_inlines = sgo_empty_expr_array(infos.length())
  let mut changed = false
  match global_sec {
    Some(@lib.GlobalSec(globals)) => {
      let out : Array[@lib.Global] = []
      for defined_idx = 0
          defined_idx < globals.length()
          defined_idx = defined_idx + 1 {
        let abs_idx = sgo_defined_global_abs_idx(imported_globals, defined_idx)
        let @lib.Global(@lib.GlobalType(_, original_mutable), init) = globals[defined_idx]
        let (rewritten_init, init_changed) = sgo_rewrite_global_init_expr(
          init, startup_consts, aliases, init_inlines,
        )
        if init_changed {
          changed = true
        }
        let info = infos[abs_idx]
        if original_mutable != info.mutable_ {
          changed = true
        }
        infos[abs_idx].init = Some(rewritten_init)
        startup_consts[abs_idx] = sgo_expr_single_const(rewritten_init)
        sgo_record_alias_for_global(aliases, infos, abs_idx, rewritten_init)
        if !info.imported && !info.mutable_ && info.read_count == 1 {
          init_inlines[abs_idx] = Some(rewritten_init)
        }
        out.push(
          @lib.Global::new(
            @lib.GlobalType::new(info.value_type, info.mutable_),
            rewritten_init,
          ),
        )
      }
      (Some(@lib.GlobalSec::new(out)), startup_consts, aliases, changed)
    }
    None => (None, startup_consts, aliases, false)
  }
}

///|
fn sgo_rewrite_table_sec(
  table_sec : @lib.TableSec?,
  consts : Array[@lib.Instruction?],
  remove_sets : Array[Bool],
) -> (@lib.TableSec?, Bool) {
  match table_sec {
    Some(@lib.TableSec(tables)) => {
      let out : Array[@lib.Table] = []
      let mut changed = false
      for table in tables {
        match table {
          @lib.Table(table_type, Some(init)) => {
            let (rewritten, init_changed) = sgo_rewrite_expr(
              init,
              consts,
              sgo_empty_global_idx_array(consts.length()),
              remove_sets,
              false,
            )
            if init_changed {
              changed = true
            }
            out.push(@lib.Table::new(table_type, Some(rewritten)))
          }
          @lib.Table(_, _) => out.push(table)
        }
      }
      (Some(@lib.TableSec::new(out)), changed)
    }
    None => (None, false)
  }
}

///|
fn sgo_rewrite_elem_mode(
  mode : @lib.ElemMode,
  consts : Array[@lib.Instruction?],
  remove_sets : Array[Bool],
) -> (@lib.ElemMode, Bool) {
  match mode {
    @lib.Active(table_idx, offset) => {
      let (rewritten, changed) = sgo_rewrite_expr(
        offset,
        consts,
        sgo_empty_global_idx_array(consts.length()),
        remove_sets,
        false,
      )
      (@lib.ElemMode::active(table_idx, rewritten), changed)
    }
    _ => (mode, false)
  }
}

///|
fn sgo_rewrite_elem_kind(kind : @lib.ElemKind) -> (@lib.ElemKind, Bool) {
  // Element item expressions are reference-typed and need exact type/refinalize
  // care. Keep them unchanged in the first SGO slice; element offsets are still
  // rewritten through sgo_rewrite_elem_mode.
  (kind, false)
}

///|
fn sgo_rewrite_elem_sec(
  elem_sec : @lib.ElemSec?,
  consts : Array[@lib.Instruction?],
  remove_sets : Array[Bool],
) -> (@lib.ElemSec?, Bool) {
  match elem_sec {
    Some(@lib.ElemSec(elems)) => {
      let out : Array[@lib.Elem] = []
      let mut changed = false
      for elem in elems {
        let @lib.Elem(mode, kind) = elem
        let (next_mode, mode_changed) = sgo_rewrite_elem_mode(
          mode, consts, remove_sets,
        )
        let (next_kind, kind_changed) = sgo_rewrite_elem_kind(kind)
        if mode_changed || kind_changed {
          changed = true
        }
        out.push(@lib.Elem::new(next_mode, next_kind))
      }
      (Some(@lib.ElemSec::new(out)), changed)
    }
    None => (None, false)
  }
}

///|
fn sgo_rewrite_data_sec(
  data_sec : @lib.DataSec?,
  consts : Array[@lib.Instruction?],
  remove_sets : Array[Bool],
) -> (@lib.DataSec?, Bool) {
  match data_sec {
    Some(@lib.DataSec(datas)) => {
      let out : Array[@lib.Data] = []
      let mut changed = false
      for data in datas {
        let @lib.Data(mode, bytes) = data
        let next_mode = match mode {
          @lib.Active(mem_idx, offset) => {
            let (rewritten, offset_changed) = sgo_rewrite_expr(
              offset,
              consts,
              sgo_empty_global_idx_array(consts.length()),
              remove_sets,
              false,
            )
            if offset_changed {
              changed = true
            }
            @lib.DataMode::active(mem_idx, rewritten)
          }
          @lib.Passive => mode
        }
        out.push(@lib.Data::new(next_mode, bytes))
      }
      (Some(@lib.DataSec::new(out)), changed)
    }
    None => (None, false)
  }
}

///|
fn sgo_runtime_trace_clear(facts : Array[@lib.Instruction?]) -> Unit {
  for idx = 0; idx < facts.length(); idx = idx + 1 {
    facts[idx] = None
  }
}

///|
fn sgo_runtime_trace_barrier(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Call(_)
    | @lib.CallIndirect(_, _)
    | @lib.CallRef(_)
    | @lib.ReturnCall(_)
    | @lib.ReturnCallIndirect(_, _)
    | @lib.ReturnCallRef(_)
    | @lib.Block(_, _)
    | @lib.Loop(_, _)
    | @lib.If(_, _, _)
    | @lib.TryTable(_, _, _)
    | @lib.Br(_)
    | @lib.BrIf(_)
    | @lib.BrTable(_, _)
    | @lib.Return
    | @lib.Throw(_)
    | @lib.ThrowRef => true
    _ => false
  }
}

///|
fn sgo_runtime_trace_expr_has_barrier(expr : @lib.Expr) -> Bool {
  let @lib.Expr(instrs) = expr
  instrs.any(fn(instr) {
    match instr {
      @lib.Block(_, body) => sgo_runtime_trace_expr_has_barrier(body)
      _ => sgo_runtime_trace_barrier(instr)
    }
  })
}

///|
fn sgo_runtime_trace_copy_facts(
  dst : Array[@lib.Instruction?],
  src : Array[@lib.Instruction?],
) -> Unit {
  let limit = if dst.length() < src.length() {
    dst.length()
  } else {
    src.length()
  }
  for idx = 0; idx < limit; idx = idx + 1 {
    dst[idx] = src[idx]
  }
}

///|
fn sgo_runtime_trace_trackable(
  infos : Array[SgoGlobalInfo],
  slot : Int,
) -> Bool {
  slot >= 0 && slot < infos.length()
}

///|
fn sgo_rewrite_runtime_trace_expr(
  expr : @lib.Expr,
  infos : Array[SgoGlobalInfo],
) -> (@lib.Expr, Bool) {
  let facts = sgo_empty_const_array(infos.length())
  sgo_rewrite_runtime_trace_expr_with_facts(expr, infos, facts)
}

///|
fn sgo_i32_add_no_overflow(lhs : Int, rhs : Int) -> Int? {
  let sum = lhs.to_int64() + rhs.to_int64()
  if sum >= -2147483648L && sum <= 2147483647L {
    Some(sum.to_int())
  } else {
    None
  }
}

///|
fn sgo_instr_refs_local(
  instr : @lib.Instruction,
  local_idx : @lib.LocalIdx,
) -> Bool {
  match instr {
    @lib.LocalGet(idx) | @lib.LocalSet(idx) | @lib.LocalTee(idx) =>
      idx == local_idx
    @lib.Block(_, @lib.Expr(body))
    | @lib.Loop(_, @lib.Expr(body))
    | @lib.TryTable(_, _, @lib.Expr(body)) =>
      sgo_instrs_ref_local(body, local_idx, 0, body.length())
    @lib.If(_, then_body, else_body) => {
      if sgo_instrs_ref_local(then_body, local_idx, 0, then_body.length()) {
        return true
      }
      match else_body {
        Some(body) => sgo_instrs_ref_local(body, local_idx, 0, body.length())
        None => false
      }
    }
    _ => false
  }
}

///|
fn sgo_instrs_ref_local(
  instrs : Array[@lib.Instruction],
  local_idx : @lib.LocalIdx,
  skip_start : Int,
  skip_end : Int,
) -> Bool {
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    if idx >= skip_start && idx < skip_end {
      continue
    }
    if sgo_instr_refs_local(instrs[idx], local_idx) {
      return true
    }
  }
  false
}

///|
fn sgo_instr_is_empty_void_if(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.If(@lib.VoidBlockType, [], None) => true
    _ => false
  }
}

///|
fn sgo_instr_is_nonzero_i32_const(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.I32Const(@lib.I32(value)) => value != 0
    _ => false
  }
}

///|
fn sgo_cheap_cleanup_compare_if_shell(
  instrs : Array[@lib.Instruction],
  pos : Int,
  out : Array[@lib.Instruction],
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> Int? {
  match
    sgo_scalar_call_parent_cleanup_prefix(instrs, pos, mod_, func_type_indices) {
    Some((replay, result_kind, suffix_start, prefix_start, prefix_end)) => {
      match
        sgo_scalar_pure_suffix_cleanup_end(
          instrs, suffix_start, result_kind, false, prefix_start, prefix_end,
        ) {
        Some(next_pos) => {
          if replay.length() > 0 {
            out.append(replay)
            out.push(@lib.Instruction::drop())
          }
          return Some(next_pos)
        }
        None => ()
      }
      match
        sgo_scalar_pure_suffix_cleanup_end(
          instrs, suffix_start, result_kind, true, prefix_start, prefix_end,
        ) {
        Some(next_pos) => {
          if replay.length() > 0 {
            out.append(replay)
            out.push(@lib.Instruction::drop())
          }
          return Some(next_pos)
        }
        None => ()
      }
    }
    None => ()
  }
  match
    sgo_float_call_binary_compare_prefix_func(
      instrs, pos, mod_, func_type_indices,
    ) {
    Some(func_idx) => {
      if pos + 5 < instrs.length() &&
        sgo_instr_is_empty_void_if(instrs[pos + 5]) {
        out.push(@lib.Instruction::call(func_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 6)
      }
      if pos + 7 < instrs.length() &&
        sgo_is_return_guard(instrs[pos + 5]) &&
        sgo_const_instr(instrs[pos + 6]) != None &&
        instrs[pos + 7] == @lib.Instruction::drop() {
        out.push(@lib.Instruction::call(func_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 8)
      }
    }
    None => ()
  }
  if pos + 5 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
      ) {
      (
        @lib.I64Const(_),
        @lib.I64Const(_),
        @lib.Call(func_idx),
        op,
        compare,
        if_instr,
      )
      | (
        @lib.I64Const(_),
        @lib.Call(func_idx),
        @lib.I64Const(_),
        op,
        compare,
        if_instr,
      ) if sgo_is_nontrapping_i64_binary_flow_instr(op) &&
        sgo_is_i64_equality_compare(compare) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(@lib.Instruction::call(func_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 6)
      }
      _ => ()
    }
  }
  if pos + 2 < instrs.length() {
    match (instrs[pos], instrs[pos + 1], instrs[pos + 2]) {
      (@lib.I64Const(_), @lib.Call(func_idx), op) if sgo_is_nontrapping_i64_binary_flow_instr(
          op,
        ) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) =>
        match sgo_i64_pure_suffix_empty_if_end(instrs, pos + 3) {
          Some(next_pos) => {
            out.push(@lib.Instruction::call(func_idx))
            out.push(@lib.Instruction::drop())
            return Some(next_pos)
          }
          None => ()
        }
      (@lib.Call(func_idx), @lib.I64Const(_), op) if sgo_is_nontrapping_i64_binary_flow_instr(
          op,
        ) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) =>
        match sgo_i64_pure_suffix_empty_if_end(instrs, pos + 3) {
          Some(next_pos) => {
            out.push(@lib.Instruction::call(func_idx))
            out.push(@lib.Instruction::drop())
            return Some(next_pos)
          }
          None => ()
        }
      _ => ()
    }
  }
  if pos + 5 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
      ) {
      (
        @lib.I32Const(_),
        @lib.I32Const(_),
        @lib.Call(func_idx),
        op,
        compare,
        if_instr,
      )
      | (
        @lib.I32Const(_),
        @lib.Call(func_idx),
        @lib.I32Const(_),
        op,
        compare,
        if_instr,
      ) if sgo_is_nontrapping_i32_binary_flow_instr(op) &&
        sgo_is_compare_instr(compare) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(@lib.Instruction::call(func_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 6)
      }
      _ => ()
    }
  }
  if pos + 2 < instrs.length() {
    match (instrs[pos], instrs[pos + 1], instrs[pos + 2]) {
      (@lib.I32Const(_), @lib.Call(func_idx), op) if sgo_is_nontrapping_i32_binary_flow_instr(
          op,
        ) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) =>
        match sgo_i32_pure_suffix_empty_if_end(instrs, pos + 3) {
          Some(next_pos) => {
            out.push(@lib.Instruction::call(func_idx))
            out.push(@lib.Instruction::drop())
            return Some(next_pos)
          }
          None => ()
        }
      (@lib.Call(func_idx), @lib.I32Const(_), op) if sgo_is_nontrapping_i32_binary_flow_instr(
          op,
        ) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) =>
        match sgo_i32_pure_suffix_empty_if_end(instrs, pos + 3) {
          Some(next_pos) => {
            out.push(@lib.Instruction::call(func_idx))
            out.push(@lib.Instruction::drop())
            return Some(next_pos)
          }
          None => ()
        }
      _ => ()
    }
  }
  if pos + 3 < instrs.length() {
    match (instrs[pos], instrs[pos + 1], instrs[pos + 2], instrs[pos + 3]) {
      (@lib.I32Const(_), @lib.Call(func_idx), compare, if_instr) if (
          sgo_is_compare_instr(compare) ||
          sgo_is_nontrapping_i32_binary_flow_instr(compare)
        ) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(@lib.Instruction::call(func_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 4)
      }
      (@lib.Call(func_idx), @lib.I32Const(_), compare, if_instr) if (
          sgo_is_compare_instr(compare) ||
          sgo_is_nontrapping_i32_binary_flow_instr(compare)
        ) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(@lib.Instruction::call(func_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 4)
      }
      (@lib.I32Const(_), @lib.MemorySize(_), compare, if_instr) if sgo_is_compare_instr(
          compare,
        ) &&
        sgo_instr_is_empty_void_if(if_instr) => return Some(pos + 4)
      (@lib.MemorySize(_), @lib.I32Const(_), compare, if_instr) if sgo_is_compare_instr(
          compare,
        ) &&
        sgo_instr_is_empty_void_if(if_instr) => return Some(pos + 4)
      (@lib.I32Const(_), @lib.TableSize(_), compare, if_instr) if sgo_is_compare_instr(
          compare,
        ) &&
        sgo_instr_is_empty_void_if(if_instr) => return Some(pos + 4)
      (@lib.TableSize(_), @lib.I32Const(_), compare, if_instr) if sgo_is_compare_instr(
          compare,
        ) &&
        sgo_instr_is_empty_void_if(if_instr) => return Some(pos + 4)
      (
        @lib.I32Const(_),
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr([value, @lib.GlobalSet(global_idx), result_const])
        ),
        compare,
        if_instr,
      ) if sgo_global_set_result_block_value_is_independent(value) &&
        sgo_const_instr(result_const) != None &&
        sgo_is_compare_instr(compare) &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(value)
        out.push(@lib.Instruction::global_set(global_idx))
        return Some(pos + 4)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr([value, @lib.GlobalSet(global_idx), result_const])
        ),
        @lib.I32Const(_),
        compare,
        if_instr,
      ) if sgo_global_set_result_block_value_is_independent(value) &&
        sgo_const_instr(result_const) != None &&
        sgo_is_compare_instr(compare) &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(value)
        out.push(@lib.Instruction::global_set(global_idx))
        return Some(pos + 4)
      }
      (@lib.I32Const(_), block, compare, if_instr) if sgo_independent_memory_store_result_block_matches(
          block,
        ) &&
        sgo_is_compare_instr(compare) &&
        sgo_instr_is_empty_void_if(if_instr) => {
        sgo_push_memory_store_result_block_effect(block, out)
        return Some(pos + 4)
      }
      (block, @lib.I32Const(_), compare, if_instr) if sgo_independent_memory_store_result_block_matches(
          block,
        ) &&
        sgo_is_compare_instr(compare) &&
        sgo_instr_is_empty_void_if(if_instr) => {
        sgo_push_memory_store_result_block_effect(block, out)
        return Some(pos + 4)
      }
      _ => ()
    }
  }
  if pos + 4 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
      ) {
      (value, @lib.LocalSet(local_idx), @lib.LocalGet(get_idx), eqz, if_instr) if local_idx ==
        get_idx &&
        eqz == @lib.Instruction::i32_eqz() &&
        sgo_local_effect_value_is_independent(value) &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(value)
        out.push(@lib.Instruction::local_set(local_idx))
        return Some(pos + 5)
      }
      (const_instr, value, @lib.LocalTee(local_idx), compare, if_instr) if sgo_const_instr(
          const_instr,
        ) !=
        None &&
        sgo_local_effect_value_is_independent(value) &&
        sgo_is_compare_instr(compare) &&
        sgo_instr_is_empty_void_if(if_instr) &&
        !sgo_instrs_ref_local(instrs, local_idx, pos, pos + 5) =>
        return Some(pos + 5)
      (value, @lib.LocalTee(local_idx), const_instr, compare, if_instr) if sgo_const_instr(
          const_instr,
        ) !=
        None &&
        sgo_local_effect_value_is_independent(value) &&
        sgo_is_compare_instr(compare) &&
        sgo_instr_is_empty_void_if(if_instr) &&
        !sgo_instrs_ref_local(instrs, local_idx, pos, pos + 5) =>
        return Some(pos + 5)
      (@lib.I32Const(_), grow_delta, @lib.MemoryGrow(mem_idx), compare, if_instr
      ) if sgo_memory_grow_arg_is_independent(grow_delta) &&
        sgo_is_compare_instr(compare) &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(grow_delta)
        out.push(@lib.Instruction::memory_grow(mem_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 5)
      }
      (grow_delta, @lib.MemoryGrow(mem_idx), @lib.I32Const(_), compare, if_instr
      ) if sgo_memory_grow_arg_is_independent(grow_delta) &&
        sgo_is_compare_instr(compare) &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(grow_delta)
        out.push(@lib.Instruction::memory_grow(mem_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 5)
      }
      _ => ()
    }
  }
  if pos + 6 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
        instrs[pos + 6],
      ) {
      (
        @lib.I32Const(_),
        grow_left,
        grow_right,
        grow_op,
        @lib.MemoryGrow(mem_idx),
        compare,
        if_instr,
      ) if sgo_i32_add_grow_arg_is_independent(grow_left, grow_right, grow_op) &&
        sgo_is_compare_instr(compare) &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(grow_left)
        out.push(grow_right)
        out.push(grow_op)
        out.push(@lib.Instruction::memory_grow(mem_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 7)
      }
      (
        grow_left,
        grow_right,
        grow_op,
        @lib.MemoryGrow(mem_idx),
        @lib.I32Const(_),
        compare,
        if_instr,
      ) if sgo_i32_add_grow_arg_is_independent(grow_left, grow_right, grow_op) &&
        sgo_is_compare_instr(compare) &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(grow_left)
        out.push(grow_right)
        out.push(grow_op)
        out.push(@lib.Instruction::memory_grow(mem_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 7)
      }
      _ => ()
    }
  }
  if pos + 5 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
      ) {
      (
        @lib.I32Const(_),
        ref_value,
        grow_delta,
        @lib.TableGrow(table_idx),
        compare,
        if_instr,
      ) if sgo_table_grow_arg_is_independent(ref_value) &&
        sgo_table_grow_arg_is_independent(grow_delta) &&
        sgo_is_compare_instr(compare) &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(ref_value)
        out.push(grow_delta)
        out.push(@lib.Instruction::table_grow(table_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 6)
      }
      (
        ref_value,
        grow_delta,
        @lib.TableGrow(table_idx),
        @lib.I32Const(_),
        compare,
        if_instr,
      ) if sgo_table_grow_arg_is_independent(ref_value) &&
        sgo_table_grow_arg_is_independent(grow_delta) &&
        sgo_is_compare_instr(compare) &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(ref_value)
        out.push(grow_delta)
        out.push(@lib.Instruction::table_grow(table_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 6)
      }
      _ => ()
    }
  }
  if pos + 7 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
        instrs[pos + 6],
        instrs[pos + 7],
      ) {
      (
        @lib.I32Const(_),
        ref_value,
        grow_left,
        grow_right,
        grow_op,
        @lib.TableGrow(table_idx),
        compare,
        if_instr,
      ) if sgo_table_grow_arg_is_independent(ref_value) &&
        sgo_i32_add_grow_arg_is_independent(grow_left, grow_right, grow_op) &&
        sgo_is_compare_instr(compare) &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(ref_value)
        out.push(grow_left)
        out.push(grow_right)
        out.push(grow_op)
        out.push(@lib.Instruction::table_grow(table_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 8)
      }
      (
        ref_value,
        grow_left,
        grow_right,
        grow_op,
        @lib.TableGrow(table_idx),
        @lib.I32Const(_),
        compare,
        if_instr,
      ) if sgo_table_grow_arg_is_independent(ref_value) &&
        sgo_i32_add_grow_arg_is_independent(grow_left, grow_right, grow_op) &&
        sgo_is_compare_instr(compare) &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(ref_value)
        out.push(grow_left)
        out.push(grow_right)
        out.push(grow_op)
        out.push(@lib.Instruction::table_grow(table_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 8)
      }
      _ => ()
    }
  }
  if pos + 7 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
        instrs[pos + 6],
        instrs[pos + 7],
      ) {
      (
        @lib.I64Const(_),
        @lib.I64Const(_),
        @lib.Call(func_idx),
        op,
        compare,
        if_instr,
        dropped_const,
        @lib.Drop,
      )
      | (
        @lib.I64Const(_),
        @lib.Call(func_idx),
        @lib.I64Const(_),
        op,
        compare,
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_is_nontrapping_i64_binary_flow_instr(op) &&
        sgo_is_i64_equality_compare(compare) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(@lib.Instruction::call(func_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 8)
      }
      _ => ()
    }
  }
  if pos + 2 < instrs.length() {
    match (instrs[pos], instrs[pos + 1], instrs[pos + 2]) {
      (@lib.I64Const(_), @lib.Call(func_idx), op) if sgo_is_nontrapping_i64_binary_flow_instr(
          op,
        ) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) =>
        match sgo_i64_pure_suffix_if_return_drop_end(instrs, pos + 3) {
          Some(next_pos) => {
            out.push(@lib.Instruction::call(func_idx))
            out.push(@lib.Instruction::drop())
            return Some(next_pos)
          }
          None => ()
        }
      (@lib.Call(func_idx), @lib.I64Const(_), op) if sgo_is_nontrapping_i64_binary_flow_instr(
          op,
        ) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) =>
        match sgo_i64_pure_suffix_if_return_drop_end(instrs, pos + 3) {
          Some(next_pos) => {
            out.push(@lib.Instruction::call(func_idx))
            out.push(@lib.Instruction::drop())
            return Some(next_pos)
          }
          None => ()
        }
      _ => ()
    }
  }
  if pos + 7 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
        instrs[pos + 6],
        instrs[pos + 7],
      ) {
      (
        @lib.I32Const(_),
        @lib.I32Const(_),
        @lib.Call(func_idx),
        op,
        compare,
        if_instr,
        dropped_const,
        @lib.Drop,
      )
      | (
        @lib.I32Const(_),
        @lib.Call(func_idx),
        @lib.I32Const(_),
        op,
        compare,
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_is_nontrapping_i32_binary_flow_instr(op) &&
        sgo_is_compare_instr(compare) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(@lib.Instruction::call(func_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 8)
      }
      _ => ()
    }
  }
  if pos + 2 < instrs.length() {
    match (instrs[pos], instrs[pos + 1], instrs[pos + 2]) {
      (@lib.I32Const(_), @lib.Call(func_idx), op) if sgo_is_nontrapping_i32_binary_flow_instr(
          op,
        ) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) =>
        match sgo_i32_pure_suffix_if_return_drop_end(instrs, pos + 3) {
          Some(next_pos) => {
            out.push(@lib.Instruction::call(func_idx))
            out.push(@lib.Instruction::drop())
            return Some(next_pos)
          }
          None => ()
        }
      (@lib.Call(func_idx), @lib.I32Const(_), op) if sgo_is_nontrapping_i32_binary_flow_instr(
          op,
        ) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) =>
        match sgo_i32_pure_suffix_if_return_drop_end(instrs, pos + 3) {
          Some(next_pos) => {
            out.push(@lib.Instruction::call(func_idx))
            out.push(@lib.Instruction::drop())
            return Some(next_pos)
          }
          None => ()
        }
      _ => ()
    }
  }
  if pos + 5 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
      ) {
      (
        value,
        @lib.LocalSet(local_idx),
        @lib.LocalGet(get_idx),
        const_instr,
        compare,
        if_instr,
      ) if pos + 6 == instrs.length() &&
        local_idx == get_idx &&
        sgo_local_effect_value_is_independent(value) &&
        sgo_const_instr(const_instr) != None &&
        sgo_is_compare_instr(compare) &&
        sgo_is_return_guard(if_instr) => {
        out.push(value)
        out.push(@lib.Instruction::local_set(local_idx))
        return Some(pos + 6)
      }
      (
        @lib.I32Const(_),
        @lib.Call(func_idx),
        compare,
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if (
          sgo_is_compare_instr(compare) ||
          sgo_is_nontrapping_i32_binary_flow_instr(compare)
        ) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(@lib.Instruction::call(func_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 6)
      }
      (
        @lib.Call(func_idx),
        @lib.I32Const(_),
        compare,
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if (
          sgo_is_compare_instr(compare) ||
          sgo_is_nontrapping_i32_binary_flow_instr(compare)
        ) &&
        sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(@lib.Instruction::call(func_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 6)
      }
      (
        @lib.I32Const(_),
        @lib.MemorySize(_),
        compare,
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_is_compare_instr(compare) &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => return Some(pos + 6)
      (
        @lib.MemorySize(_),
        @lib.I32Const(_),
        compare,
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_is_compare_instr(compare) &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => return Some(pos + 6)
      (
        @lib.I32Const(_),
        @lib.TableSize(_),
        compare,
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_is_compare_instr(compare) &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => return Some(pos + 6)
      (
        @lib.TableSize(_),
        @lib.I32Const(_),
        compare,
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_is_compare_instr(compare) &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => return Some(pos + 6)
      (
        @lib.I32Const(_),
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr([value, @lib.GlobalSet(global_idx), result_const])
        ),
        compare,
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_global_set_result_block_value_is_independent(value) &&
        sgo_const_instr(result_const) != None &&
        sgo_is_compare_instr(compare) &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(value)
        out.push(@lib.Instruction::global_set(global_idx))
        return Some(pos + 6)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr([value, @lib.GlobalSet(global_idx), result_const])
        ),
        @lib.I32Const(_),
        compare,
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_global_set_result_block_value_is_independent(value) &&
        sgo_const_instr(result_const) != None &&
        sgo_is_compare_instr(compare) &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(value)
        out.push(@lib.Instruction::global_set(global_idx))
        return Some(pos + 6)
      }
      (@lib.I32Const(_), block, compare, if_instr, dropped_const, @lib.Drop) if sgo_independent_memory_store_result_block_matches(
          block,
        ) &&
        sgo_is_compare_instr(compare) &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        sgo_push_memory_store_result_block_effect(block, out)
        return Some(pos + 6)
      }
      (block, @lib.I32Const(_), compare, if_instr, dropped_const, @lib.Drop) if sgo_independent_memory_store_result_block_matches(
          block,
        ) &&
        sgo_is_compare_instr(compare) &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        sgo_push_memory_store_result_block_effect(block, out)
        return Some(pos + 6)
      }
      _ => ()
    }
  }
  if pos + 6 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
        instrs[pos + 6],
      ) {
      (
        const_instr,
        value,
        @lib.LocalTee(local_idx),
        compare,
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_const_instr(const_instr) != None &&
        sgo_local_effect_value_is_independent(value) &&
        sgo_is_compare_instr(compare) &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None &&
        !sgo_instrs_ref_local(instrs, local_idx, pos, pos + 7) =>
        return Some(pos + 7)
      (
        value,
        @lib.LocalTee(local_idx),
        const_instr,
        compare,
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_const_instr(const_instr) != None &&
        sgo_local_effect_value_is_independent(value) &&
        sgo_is_compare_instr(compare) &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None &&
        !sgo_instrs_ref_local(instrs, local_idx, pos, pos + 7) =>
        return Some(pos + 7)
      (
        @lib.I32Const(_),
        grow_delta,
        @lib.MemoryGrow(mem_idx),
        compare,
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_memory_grow_arg_is_independent(grow_delta) &&
        sgo_is_compare_instr(compare) &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(grow_delta)
        out.push(@lib.Instruction::memory_grow(mem_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 7)
      }
      (
        grow_delta,
        @lib.MemoryGrow(mem_idx),
        @lib.I32Const(_),
        compare,
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_memory_grow_arg_is_independent(grow_delta) &&
        sgo_is_compare_instr(compare) &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(grow_delta)
        out.push(@lib.Instruction::memory_grow(mem_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 7)
      }
      _ => ()
    }
  }
  if pos + 8 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
        instrs[pos + 6],
        instrs[pos + 7],
        instrs[pos + 8],
      ) {
      (
        @lib.I32Const(_),
        grow_left,
        grow_right,
        grow_op,
        @lib.MemoryGrow(mem_idx),
        compare,
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_i32_add_grow_arg_is_independent(grow_left, grow_right, grow_op) &&
        sgo_is_compare_instr(compare) &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(grow_left)
        out.push(grow_right)
        out.push(grow_op)
        out.push(@lib.Instruction::memory_grow(mem_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 9)
      }
      (
        grow_left,
        grow_right,
        grow_op,
        @lib.MemoryGrow(mem_idx),
        @lib.I32Const(_),
        compare,
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_i32_add_grow_arg_is_independent(grow_left, grow_right, grow_op) &&
        sgo_is_compare_instr(compare) &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(grow_left)
        out.push(grow_right)
        out.push(grow_op)
        out.push(@lib.Instruction::memory_grow(mem_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 9)
      }
      _ => ()
    }
  }
  if pos + 7 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
        instrs[pos + 6],
        instrs[pos + 7],
      ) {
      (
        @lib.I32Const(_),
        ref_value,
        grow_delta,
        @lib.TableGrow(table_idx),
        compare,
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_table_grow_arg_is_independent(ref_value) &&
        sgo_table_grow_arg_is_independent(grow_delta) &&
        sgo_is_compare_instr(compare) &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(ref_value)
        out.push(grow_delta)
        out.push(@lib.Instruction::table_grow(table_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 8)
      }
      (
        ref_value,
        grow_delta,
        @lib.TableGrow(table_idx),
        @lib.I32Const(_),
        compare,
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_table_grow_arg_is_independent(ref_value) &&
        sgo_table_grow_arg_is_independent(grow_delta) &&
        sgo_is_compare_instr(compare) &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(ref_value)
        out.push(grow_delta)
        out.push(@lib.Instruction::table_grow(table_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 8)
      }
      _ => ()
    }
  }
  if pos + 9 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
        instrs[pos + 6],
        instrs[pos + 7],
        instrs[pos + 8],
        instrs[pos + 9],
      ) {
      (
        @lib.I32Const(_),
        ref_value,
        grow_left,
        grow_right,
        grow_op,
        @lib.TableGrow(table_idx),
        compare,
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_table_grow_arg_is_independent(ref_value) &&
        sgo_i32_add_grow_arg_is_independent(grow_left, grow_right, grow_op) &&
        sgo_is_compare_instr(compare) &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(ref_value)
        out.push(grow_left)
        out.push(grow_right)
        out.push(grow_op)
        out.push(@lib.Instruction::table_grow(table_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 10)
      }
      (
        ref_value,
        grow_left,
        grow_right,
        grow_op,
        @lib.TableGrow(table_idx),
        @lib.I32Const(_),
        compare,
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_table_grow_arg_is_independent(ref_value) &&
        sgo_i32_add_grow_arg_is_independent(grow_left, grow_right, grow_op) &&
        sgo_is_compare_instr(compare) &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(ref_value)
        out.push(grow_left)
        out.push(grow_right)
        out.push(grow_op)
        out.push(@lib.Instruction::table_grow(table_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 10)
      }
      _ => ()
    }
  }
  None
}

///|
fn sgo_cheap_cleanup_select_if_shell(
  instrs : Array[@lib.Instruction],
  pos : Int,
  out : Array[@lib.Instruction],
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> Int? {
  if pos == 0 && pos + 4 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
      ) {
      (
        @lib.I32Const(_),
        @lib.Call(func_idx),
        const_instr,
        @lib.Select(_),
        if_instr,
      ) =>
        if sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) &&
          sgo_const_instr(const_instr) != None &&
          sgo_instr_is_empty_void_if(if_instr) {
          out.push(@lib.Instruction::call(func_idx))
          out.push(@lib.Instruction::drop())
          return Some(pos + 5)
        }
      (
        @lib.Call(func_idx),
        @lib.I32Const(_),
        const_instr,
        @lib.Select(_),
        if_instr,
      ) =>
        if sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) &&
          sgo_const_instr(const_instr) != None &&
          sgo_instr_is_empty_void_if(if_instr) {
          out.push(@lib.Instruction::call(func_idx))
          out.push(@lib.Instruction::drop())
          return Some(pos + 5)
        }
      (
        @lib.I32Const(_),
        @lib.MemorySize(_),
        const_instr,
        @lib.Select(_),
        if_instr,
      ) =>
        if sgo_const_instr(const_instr) != None &&
          sgo_instr_is_empty_void_if(if_instr) {
          return Some(pos + 5)
        }
      (
        @lib.MemorySize(_),
        @lib.I32Const(_),
        const_instr,
        @lib.Select(_),
        if_instr,
      ) =>
        if sgo_const_instr(const_instr) != None &&
          sgo_instr_is_empty_void_if(if_instr) {
          return Some(pos + 5)
        }
      (
        @lib.I32Const(_),
        @lib.TableSize(_),
        const_instr,
        @lib.Select(_),
        if_instr,
      ) =>
        if sgo_const_instr(const_instr) != None &&
          sgo_instr_is_empty_void_if(if_instr) {
          return Some(pos + 5)
        }
      (
        @lib.TableSize(_),
        @lib.I32Const(_),
        const_instr,
        @lib.Select(_),
        if_instr,
      ) =>
        if sgo_const_instr(const_instr) != None &&
          sgo_instr_is_empty_void_if(if_instr) {
          return Some(pos + 5)
        }
      _ => ()
    }
  }
  if pos == 0 && pos + 5 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
      ) {
      (
        @lib.I32Const(_),
        value,
        @lib.LocalTee(local_idx),
        const_instr,
        @lib.Select(_),
        if_instr,
      ) if sgo_const_instr(value) != None &&
        sgo_const_instr(const_instr) != None &&
        sgo_instr_is_empty_void_if(if_instr) &&
        !sgo_instrs_ref_local(instrs, local_idx, pos, pos + 6) =>
        return Some(pos + 6)
      (
        value,
        @lib.LocalTee(local_idx),
        @lib.I32Const(_),
        const_instr,
        @lib.Select(_),
        if_instr,
      ) if sgo_const_instr(value) != None &&
        sgo_const_instr(const_instr) != None &&
        sgo_instr_is_empty_void_if(if_instr) &&
        !sgo_instrs_ref_local(instrs, local_idx, pos, pos + 6) =>
        return Some(pos + 6)
      _ => ()
    }
  }
  if pos == 0 && pos + 5 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
      ) {
      (
        @lib.I32Const(_),
        grow_delta,
        @lib.MemoryGrow(mem_idx),
        const_instr,
        @lib.Select(_),
        if_instr,
      ) =>
        if sgo_memory_grow_arg_is_independent(grow_delta) &&
          sgo_const_instr(const_instr) != None &&
          sgo_instr_is_empty_void_if(if_instr) {
          out.push(grow_delta)
          out.push(@lib.Instruction::memory_grow(mem_idx))
          out.push(@lib.Instruction::drop())
          return Some(pos + 6)
        }
      (
        grow_delta,
        @lib.MemoryGrow(mem_idx),
        @lib.I32Const(_),
        const_instr,
        @lib.Select(_),
        if_instr,
      ) =>
        if sgo_memory_grow_arg_is_independent(grow_delta) &&
          sgo_const_instr(const_instr) != None &&
          sgo_instr_is_empty_void_if(if_instr) {
          out.push(grow_delta)
          out.push(@lib.Instruction::memory_grow(mem_idx))
          out.push(@lib.Instruction::drop())
          return Some(pos + 6)
        }
      _ => ()
    }
  }
  if pos == 0 && pos + 7 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
        instrs[pos + 6],
        instrs[pos + 7],
      ) {
      (
        @lib.I32Const(_),
        grow_left,
        grow_right,
        grow_op,
        @lib.MemoryGrow(mem_idx),
        const_instr,
        @lib.Select(_),
        if_instr,
      ) =>
        if sgo_i32_add_grow_arg_is_independent(grow_left, grow_right, grow_op) &&
          sgo_const_instr(const_instr) != None &&
          sgo_instr_is_empty_void_if(if_instr) {
          out.push(grow_left)
          out.push(grow_right)
          out.push(grow_op)
          out.push(@lib.Instruction::memory_grow(mem_idx))
          out.push(@lib.Instruction::drop())
          return Some(pos + 8)
        }
      (
        grow_left,
        grow_right,
        grow_op,
        @lib.MemoryGrow(mem_idx),
        @lib.I32Const(_),
        const_instr,
        @lib.Select(_),
        if_instr,
      ) =>
        if sgo_i32_add_grow_arg_is_independent(grow_left, grow_right, grow_op) &&
          sgo_const_instr(const_instr) != None &&
          sgo_instr_is_empty_void_if(if_instr) {
          out.push(grow_left)
          out.push(grow_right)
          out.push(grow_op)
          out.push(@lib.Instruction::memory_grow(mem_idx))
          out.push(@lib.Instruction::drop())
          return Some(pos + 8)
        }
      _ => ()
    }
  }
  if pos + 6 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
        instrs[pos + 6],
      ) {
      (
        @lib.I32Const(_),
        @lib.Call(func_idx),
        const_instr,
        @lib.Select(_),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) &&
        sgo_const_instr(const_instr) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(@lib.Instruction::call(func_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 7)
      }
      (
        @lib.Call(func_idx),
        @lib.I32Const(_),
        const_instr,
        @lib.Select(_),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) &&
        sgo_const_instr(const_instr) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(@lib.Instruction::call(func_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 7)
      }
      (
        @lib.I32Const(_),
        @lib.MemorySize(_),
        const_instr,
        @lib.Select(_),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_const_instr(const_instr) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => return Some(pos + 7)
      (
        @lib.MemorySize(_),
        @lib.I32Const(_),
        const_instr,
        @lib.Select(_),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_const_instr(const_instr) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => return Some(pos + 7)
      (
        @lib.I32Const(_),
        @lib.TableSize(_),
        const_instr,
        @lib.Select(_),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_const_instr(const_instr) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => return Some(pos + 7)
      (
        @lib.TableSize(_),
        @lib.I32Const(_),
        const_instr,
        @lib.Select(_),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_const_instr(const_instr) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => return Some(pos + 7)
      (
        @lib.I32Const(_),
        ref_value,
        grow_delta,
        @lib.TableGrow(table_idx),
        const_instr,
        @lib.Select(_),
        if_instr,
      ) if sgo_table_grow_arg_is_independent(ref_value) &&
        sgo_table_grow_arg_is_independent(grow_delta) &&
        sgo_const_instr(const_instr) != None &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(ref_value)
        out.push(grow_delta)
        out.push(@lib.Instruction::table_grow(table_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 7)
      }
      (
        ref_value,
        grow_delta,
        @lib.TableGrow(table_idx),
        @lib.I32Const(_),
        const_instr,
        @lib.Select(_),
        if_instr,
      ) if sgo_table_grow_arg_is_independent(ref_value) &&
        sgo_table_grow_arg_is_independent(grow_delta) &&
        sgo_const_instr(const_instr) != None &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(ref_value)
        out.push(grow_delta)
        out.push(@lib.Instruction::table_grow(table_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 7)
      }
      (
        @lib.I32Const(_),
        @lib.I32Const(addr),
        @lib.I32Load(memarg),
        @lib.LocalTee(local_idx),
        cond,
        @lib.Select(_),
        if_instr,
      ) if sgo_instr_is_nonzero_i32_const(cond) &&
        sgo_instr_is_empty_void_if(if_instr) &&
        !sgo_instrs_ref_local(instrs, local_idx, pos, pos + 7) => {
        out.push(@lib.Instruction::i32_const(addr))
        out.push(@lib.Instruction::i32_load(memarg))
        out.push(@lib.Instruction::drop())
        return Some(pos + 7)
      }
      _ => ()
    }
  }
  if pos == 0 && pos + 8 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
        instrs[pos + 6],
        instrs[pos + 7],
        instrs[pos + 8],
      ) {
      (
        @lib.I32Const(_),
        ref_value,
        grow_left,
        grow_right,
        grow_op,
        @lib.TableGrow(table_idx),
        const_instr,
        @lib.Select(_),
        if_instr,
      ) if sgo_table_grow_arg_is_independent(ref_value) &&
        sgo_i32_add_grow_arg_is_independent(grow_left, grow_right, grow_op) &&
        sgo_const_instr(const_instr) != None &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(ref_value)
        out.push(grow_left)
        out.push(grow_right)
        out.push(grow_op)
        out.push(@lib.Instruction::table_grow(table_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 9)
      }
      (
        ref_value,
        grow_left,
        grow_right,
        grow_op,
        @lib.TableGrow(table_idx),
        @lib.I32Const(_),
        const_instr,
        @lib.Select(_),
        if_instr,
      ) if sgo_table_grow_arg_is_independent(ref_value) &&
        sgo_i32_add_grow_arg_is_independent(grow_left, grow_right, grow_op) &&
        sgo_const_instr(const_instr) != None &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(ref_value)
        out.push(grow_left)
        out.push(grow_right)
        out.push(grow_op)
        out.push(@lib.Instruction::table_grow(table_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 9)
      }
      _ => ()
    }
  }
  if pos + 7 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
        instrs[pos + 6],
        instrs[pos + 7],
      ) {
      (
        @lib.I32Const(_),
        value,
        @lib.LocalTee(local_idx),
        const_instr,
        @lib.Select(_),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_const_instr(value) != None &&
        sgo_const_instr(const_instr) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None &&
        !sgo_instrs_ref_local(instrs, local_idx, pos, pos + 8) =>
        return Some(pos + 8)
      (
        value,
        @lib.LocalTee(local_idx),
        @lib.I32Const(_),
        const_instr,
        @lib.Select(_),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_const_instr(value) != None &&
        sgo_const_instr(const_instr) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None &&
        !sgo_instrs_ref_local(instrs, local_idx, pos, pos + 8) =>
        return Some(pos + 8)
      (
        @lib.I32Const(_),
        grow_delta,
        @lib.MemoryGrow(mem_idx),
        const_instr,
        @lib.Select(_),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_memory_grow_arg_is_independent(grow_delta) &&
        sgo_const_instr(const_instr) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(grow_delta)
        out.push(@lib.Instruction::memory_grow(mem_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 8)
      }
      (
        grow_delta,
        @lib.MemoryGrow(mem_idx),
        @lib.I32Const(_),
        const_instr,
        @lib.Select(_),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_memory_grow_arg_is_independent(grow_delta) &&
        sgo_const_instr(const_instr) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(grow_delta)
        out.push(@lib.Instruction::memory_grow(mem_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 8)
      }
      _ => ()
    }
  }
  if pos + 9 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
        instrs[pos + 6],
        instrs[pos + 7],
        instrs[pos + 8],
        instrs[pos + 9],
      ) {
      (
        @lib.I32Const(_),
        grow_left,
        grow_right,
        grow_op,
        @lib.MemoryGrow(mem_idx),
        const_instr,
        @lib.Select(_),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_i32_add_grow_arg_is_independent(grow_left, grow_right, grow_op) &&
        sgo_const_instr(const_instr) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(grow_left)
        out.push(grow_right)
        out.push(grow_op)
        out.push(@lib.Instruction::memory_grow(mem_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 10)
      }
      (
        grow_left,
        grow_right,
        grow_op,
        @lib.MemoryGrow(mem_idx),
        @lib.I32Const(_),
        const_instr,
        @lib.Select(_),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_i32_add_grow_arg_is_independent(grow_left, grow_right, grow_op) &&
        sgo_const_instr(const_instr) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(grow_left)
        out.push(grow_right)
        out.push(grow_op)
        out.push(@lib.Instruction::memory_grow(mem_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 10)
      }
      _ => ()
    }
  }
  if pos + 8 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
        instrs[pos + 6],
        instrs[pos + 7],
        instrs[pos + 8],
      ) {
      (
        @lib.I32Const(_),
        ref_value,
        grow_delta,
        @lib.TableGrow(table_idx),
        const_instr,
        @lib.Select(_),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_table_grow_arg_is_independent(ref_value) &&
        sgo_table_grow_arg_is_independent(grow_delta) &&
        sgo_const_instr(const_instr) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(ref_value)
        out.push(grow_delta)
        out.push(@lib.Instruction::table_grow(table_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 9)
      }
      (
        ref_value,
        grow_delta,
        @lib.TableGrow(table_idx),
        @lib.I32Const(_),
        const_instr,
        @lib.Select(_),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_table_grow_arg_is_independent(ref_value) &&
        sgo_table_grow_arg_is_independent(grow_delta) &&
        sgo_const_instr(const_instr) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(ref_value)
        out.push(grow_delta)
        out.push(@lib.Instruction::table_grow(table_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 9)
      }
      _ => ()
    }
  }
  if pos + 10 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
        instrs[pos + 6],
        instrs[pos + 7],
        instrs[pos + 8],
        instrs[pos + 9],
        instrs[pos + 10],
      ) {
      (
        @lib.I32Const(_),
        ref_value,
        grow_left,
        grow_right,
        grow_op,
        @lib.TableGrow(table_idx),
        const_instr,
        @lib.Select(_),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_table_grow_arg_is_independent(ref_value) &&
        sgo_i32_add_grow_arg_is_independent(grow_left, grow_right, grow_op) &&
        sgo_const_instr(const_instr) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(ref_value)
        out.push(grow_left)
        out.push(grow_right)
        out.push(grow_op)
        out.push(@lib.Instruction::table_grow(table_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 11)
      }
      (
        ref_value,
        grow_left,
        grow_right,
        grow_op,
        @lib.TableGrow(table_idx),
        @lib.I32Const(_),
        const_instr,
        @lib.Select(_),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_table_grow_arg_is_independent(ref_value) &&
        sgo_i32_add_grow_arg_is_independent(grow_left, grow_right, grow_op) &&
        sgo_const_instr(const_instr) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(ref_value)
        out.push(grow_left)
        out.push(grow_right)
        out.push(grow_op)
        out.push(@lib.Instruction::table_grow(table_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 11)
      }
      _ => ()
    }
  }
  if pos + 8 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
        instrs[pos + 6],
        instrs[pos + 7],
        instrs[pos + 8],
      ) {
      (
        @lib.I32Const(addr),
        @lib.I32Load(memarg),
        @lib.I32Const(_),
        @lib.LocalTee(local_idx),
        cond,
        @lib.Select(_),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if pos + 9 == instrs.length() &&
        sgo_instr_is_nonzero_i32_const(cond) &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None &&
        !sgo_instrs_ref_local(instrs, local_idx, pos, pos + 9) => {
        out.push(@lib.Instruction::i32_const(addr))
        out.push(@lib.Instruction::i32_load(memarg))
        out.push(@lib.Instruction::drop())
        return Some(pos + 9)
      }
      (
        @lib.I32Const(addr),
        @lib.I32Load(memarg),
        @lib.I32Const(_),
        @lib.LocalTee(local_idx),
        cond,
        @lib.Select(_),
        if_instr,
        @lib.LocalGet(get_local),
        @lib.Drop,
      ) if local_idx == get_local &&
        sgo_instr_is_nonzero_i32_const(cond) &&
        sgo_is_return_guard(if_instr) &&
        !sgo_instrs_ref_local(instrs, local_idx, pos, pos + 9) => {
        out.push(@lib.Instruction::i32_const(addr))
        out.push(@lib.Instruction::i32_load(memarg))
        out.push(@lib.Instruction::drop())
        return Some(pos + 9)
      }
      (
        @lib.I32Const(addr),
        @lib.I32Load(memarg),
        @lib.I32Const(_),
        @lib.LocalTee(local_idx),
        cond,
        @lib.Select(_),
        if_instr,
        @lib.LocalGet(get_local),
        @lib.Drop,
      ) if local_idx == get_local &&
        sgo_instr_is_nonzero_i32_const(cond) &&
        sgo_instr_is_empty_void_if(if_instr) &&
        !sgo_instrs_ref_local(instrs, local_idx, pos, pos + 9) => {
        out.push(@lib.Instruction::i32_const(addr))
        out.push(@lib.Instruction::i32_load(memarg))
        out.push(@lib.Instruction::drop())
        return Some(pos + 9)
      }
      _ => ()
    }
  }
  if pos + 7 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
        instrs[pos + 6],
        instrs[pos + 7],
      ) {
      (
        @lib.I32Const(_),
        @lib.I32Const(addr),
        @lib.I32Load(memarg),
        @lib.LocalTee(local_idx),
        cond,
        @lib.Select(_),
        @lib.I32Eqz,
        if_instr,
      ) if sgo_instr_is_nonzero_i32_const(cond) &&
        sgo_instr_is_empty_void_if(if_instr) &&
        !sgo_instrs_ref_local(instrs, local_idx, pos, pos + 8) => {
        out.push(@lib.Instruction::i32_const(addr))
        out.push(@lib.Instruction::i32_load(memarg))
        out.push(@lib.Instruction::drop())
        return Some(pos + 8)
      }
      _ => ()
    }
  }
  if pos + 10 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
        instrs[pos + 6],
        instrs[pos + 7],
        instrs[pos + 8],
        instrs[pos + 9],
        instrs[pos + 10],
      ) {
      (
        @lib.I32Const(addr),
        @lib.I32Load(memarg),
        @lib.I32Const(_),
        @lib.LocalTee(local_idx),
        @lib.I32Const(@lib.I32(lhs)),
        @lib.I32Const(@lib.I32(rhs)),
        @lib.I32Add,
        @lib.Select(_),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if pos + 11 == instrs.length() &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None &&
        !sgo_instrs_ref_local(instrs, local_idx, pos, pos + 11) =>
        match sgo_i32_add_no_overflow(lhs, rhs) {
          Some(sum) if sum != 0 => {
            out.push(@lib.Instruction::i32_const(addr))
            out.push(@lib.Instruction::i32_load(memarg))
            out.push(@lib.Instruction::drop())
            return Some(pos + 11)
          }
          _ => ()
        }
      (
        @lib.I32Const(addr),
        @lib.I32Load(memarg),
        @lib.I32Const(_),
        @lib.LocalTee(local_idx),
        @lib.I32Const(@lib.I32(lhs)),
        @lib.I32Const(@lib.I32(rhs)),
        @lib.I32Add,
        @lib.Select(_),
        if_instr,
        @lib.LocalGet(get_local),
        @lib.Drop,
      ) if pos + 11 == instrs.length() &&
        local_idx == get_local &&
        sgo_is_return_guard(if_instr) &&
        !sgo_instrs_ref_local(instrs, local_idx, pos, pos + 11) =>
        match sgo_i32_add_no_overflow(lhs, rhs) {
          Some(sum) if sum != 0 => {
            out.push(@lib.Instruction::i32_const(addr))
            out.push(@lib.Instruction::i32_load(memarg))
            out.push(@lib.Instruction::drop())
            return Some(pos + 11)
          }
          _ => ()
        }
      _ => ()
    }
  }
  if pos + 9 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
        instrs[pos + 6],
        instrs[pos + 7],
        instrs[pos + 8],
        instrs[pos + 9],
      ) {
      (
        @lib.I32Const(addr),
        @lib.I32Load(memarg),
        @lib.I32Const(_),
        @lib.LocalTee(local_idx),
        cond,
        @lib.Select(_),
        @lib.I32Eqz,
        if_instr,
        @lib.LocalGet(get_local),
        @lib.Drop,
      ) if local_idx == get_local &&
        sgo_instr_is_nonzero_i32_const(cond) &&
        sgo_instr_is_empty_void_if(if_instr) &&
        !sgo_instrs_ref_local(instrs, local_idx, pos, pos + 10) => {
        out.push(@lib.Instruction::i32_const(addr))
        out.push(@lib.Instruction::i32_load(memarg))
        out.push(@lib.Instruction::drop())
        return Some(pos + 10)
      }
      (
        @lib.I32Const(addr),
        @lib.I32Load(memarg),
        @lib.I32Const(_),
        @lib.LocalTee(local_idx),
        cond,
        @lib.Select(_),
        @lib.I32Eqz,
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if pos + 10 == instrs.length() &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None &&
        sgo_instr_is_nonzero_i32_const(cond) &&
        !sgo_instrs_ref_local(instrs, local_idx, pos, pos + 10) => {
        out.push(@lib.Instruction::i32_const(addr))
        out.push(@lib.Instruction::i32_load(memarg))
        out.push(@lib.Instruction::drop())
        return Some(pos + 10)
      }
      _ => ()
    }
  }
  if pos + 7 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
        instrs[pos + 6],
        instrs[pos + 7],
      ) {
      (
        @lib.I32Const(addr),
        @lib.I32Load(memarg),
        @lib.I32Const(_),
        @lib.LocalTee(local_idx),
        cond,
        @lib.Select(_),
        @lib.I32Eqz,
        if_instr,
      ) if pos + 8 == instrs.length() &&
        sgo_is_return_guard(if_instr) &&
        sgo_instr_is_nonzero_i32_const(cond) &&
        !sgo_instrs_ref_local(instrs, local_idx, pos, pos + 8) => {
        out.push(@lib.Instruction::i32_const(addr))
        out.push(@lib.Instruction::i32_load(memarg))
        out.push(@lib.Instruction::drop())
        return Some(pos + 8)
      }
      _ => ()
    }
  }
  if pos + 5 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
      ) {
      (
        @lib.I32Const(addr),
        @lib.I32Load(memarg),
        @lib.I32Const(_),
        cond,
        @lib.Select(_),
        if_instr,
      ) if pos + 6 == instrs.length() &&
        sgo_is_return_guard(if_instr) &&
        sgo_instr_is_nonzero_i32_const(cond) => {
        out.push(@lib.Instruction::i32_const(addr))
        out.push(@lib.Instruction::i32_load(memarg))
        out.push(@lib.Instruction::drop())
        return Some(pos + 6)
      }
      _ => ()
    }
  }
  if pos + 6 < instrs.length() {
    match
      (
        instrs[pos],
        instrs[pos + 1],
        instrs[pos + 2],
        instrs[pos + 3],
        instrs[pos + 4],
        instrs[pos + 5],
        instrs[pos + 6],
      ) {
      (
        @lib.I32Const(addr),
        @lib.I32Load(memarg),
        @lib.I32Const(_),
        cond,
        @lib.Select(_),
        @lib.I32Eqz,
        if_instr,
      ) if pos + 7 == instrs.length() &&
        sgo_is_return_guard(if_instr) &&
        sgo_instr_is_nonzero_i32_const(cond) => {
        out.push(@lib.Instruction::i32_const(addr))
        out.push(@lib.Instruction::i32_load(memarg))
        out.push(@lib.Instruction::drop())
        return Some(pos + 7)
      }
      _ => ()
    }
  }
  None
}

///|
fn sgo_cheap_cleanup_block_if_shell(
  instrs : Array[@lib.Instruction],
  pos : Int,
  out : Array[@lib.Instruction],
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> Int? {
  if pos + 1 < instrs.length() {
    match (instrs[pos], instrs[pos + 1]) {
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr([@lib.Call(func_idx), @lib.Drop, const_instr])
        ),
        if_instr,
      ) if sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) &&
        sgo_const_instr(const_instr) != None &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(@lib.Instruction::call(func_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 2)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr([@lib.Call(func_idx), const_instr])
        ),
        if_instr,
      ) if sgo_call_has_no_params_no_results(mod_, func_type_indices, func_idx) &&
        sgo_const_instr(const_instr) != None &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(@lib.Instruction::call(func_idx))
        return Some(pos + 2)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr([@lib.MemorySize(_), @lib.Drop, const_instr])
        ),
        if_instr,
      ) if sgo_const_instr(const_instr) != None &&
        sgo_instr_is_empty_void_if(if_instr) => return Some(pos + 2)
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr([@lib.TableSize(_), @lib.Drop, const_instr])
        ),
        if_instr,
      ) if sgo_const_instr(const_instr) != None &&
        sgo_instr_is_empty_void_if(if_instr) => return Some(pos + 2)
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr([value, @lib.LocalSet(local_idx), const_instr])
        ),
        if_instr,
      ) if sgo_local_effect_value_is_independent(value) &&
        sgo_const_instr(const_instr) != None &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(value)
        out.push(@lib.Instruction::local_set(local_idx))
        return Some(pos + 2)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr(
            [
              value,
              @lib.LocalSet(local_idx),
              const_instr,
              @lib.LocalGet(get_idx),
              compare,
            ]
          )
        ),
        if_instr,
      ) if local_idx == get_idx &&
        sgo_local_effect_value_is_independent(value) &&
        sgo_const_instr(const_instr) != None &&
        sgo_is_compare_instr(compare) &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(value)
        out.push(@lib.Instruction::local_set(local_idx))
        return Some(pos + 2)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr(
            [
              value,
              @lib.LocalSet(local_idx),
              @lib.LocalGet(get_idx),
              const_instr,
              compare,
            ]
          )
        ),
        if_instr,
      ) if local_idx == get_idx &&
        sgo_local_effect_value_is_independent(value) &&
        sgo_const_instr(const_instr) != None &&
        sgo_is_compare_instr(compare) &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(value)
        out.push(@lib.Instruction::local_set(local_idx))
        return Some(pos + 2)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr(
            [
              value,
              @lib.LocalSet(local_idx),
              const_instr,
              @lib.LocalGet(get_idx),
              compare,
            ]
          )
        ),
        if_instr,
      ) if pos + 2 == instrs.length() &&
        local_idx == get_idx &&
        sgo_local_effect_value_is_independent(value) &&
        sgo_const_instr(const_instr) != None &&
        sgo_is_compare_instr(compare) &&
        sgo_is_return_guard(if_instr) => {
        out.push(value)
        out.push(@lib.Instruction::local_set(local_idx))
        return Some(pos + 2)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr(
            [
              value,
              @lib.LocalSet(local_idx),
              @lib.LocalGet(get_idx),
              const_instr,
              compare,
            ]
          )
        ),
        if_instr,
      ) if pos + 2 == instrs.length() &&
        local_idx == get_idx &&
        sgo_local_effect_value_is_independent(value) &&
        sgo_const_instr(const_instr) != None &&
        sgo_is_compare_instr(compare) &&
        sgo_is_return_guard(if_instr) => {
        out.push(value)
        out.push(@lib.Instruction::local_set(local_idx))
        return Some(pos + 2)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr([value, @lib.GlobalSet(global_idx), const_instr])
        ),
        if_instr,
      ) if sgo_const_instr(value) != None &&
        sgo_const_instr(const_instr) != None &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(value)
        out.push(@lib.Instruction::global_set(global_idx))
        return Some(pos + 2)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr([value, @lib.LocalTee(local_idx), @lib.Drop, const_instr])
        ),
        if_instr,
      ) if sgo_local_effect_value_is_independent(value) &&
        sgo_const_instr(const_instr) != None &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(value)
        out.push(@lib.Instruction::local_set(local_idx))
        return Some(pos + 2)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr(
            [grow_delta, @lib.MemoryGrow(mem_idx), @lib.Drop, const_instr]
          )
        ),
        if_instr,
      ) if sgo_const_instr(grow_delta) != None &&
        sgo_const_instr(const_instr) != None &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(grow_delta)
        out.push(@lib.Instruction::memory_grow(mem_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 2)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr(
            [
              ref_value,
              grow_delta,
              @lib.TableGrow(table_idx),
              @lib.Drop,
              const_instr,
            ]
          )
        ),
        if_instr,
      ) if sgo_const_instr(ref_value) != None &&
        sgo_const_instr(grow_delta) != None &&
        sgo_const_instr(const_instr) != None &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(ref_value)
        out.push(grow_delta)
        out.push(@lib.Instruction::table_grow(table_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 2)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr([dest, value, @lib.TableSet(table_idx), const_instr])
        ),
        if_instr,
      ) if sgo_const_instr(dest) != None &&
        sgo_const_instr(value) != None &&
        sgo_const_instr(const_instr) != None &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(dest)
        out.push(value)
        out.push(@lib.Instruction::table_set(table_idx))
        return Some(pos + 2)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr([dest, value, len, @lib.TableFill(table_idx), const_instr])
        ),
        if_instr,
      ) if sgo_const_instr(dest) != None &&
        sgo_const_instr(value) != None &&
        sgo_const_instr(len) != None &&
        sgo_const_instr(const_instr) != None &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(dest)
        out.push(value)
        out.push(len)
        out.push(@lib.Instruction::table_fill(table_idx))
        return Some(pos + 2)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr(
            [dest, src, len, @lib.TableCopy(dst_idx, src_idx), const_instr]
          )
        ),
        if_instr,
      ) if sgo_const_instr(dest) != None &&
        sgo_const_instr(src) != None &&
        sgo_const_instr(len) != None &&
        sgo_const_instr(const_instr) != None &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(dest)
        out.push(src)
        out.push(len)
        out.push(@lib.Instruction::table_copy(dst_idx, src_idx))
        return Some(pos + 2)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr(
            [dest, src, len, @lib.TableInit(elem_idx, table_idx), const_instr]
          )
        ),
        if_instr,
      ) if sgo_const_instr(dest) != None &&
        sgo_const_instr(src) != None &&
        sgo_const_instr(len) != None &&
        sgo_const_instr(const_instr) != None &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(dest)
        out.push(src)
        out.push(len)
        out.push(@lib.Instruction::table_init(elem_idx, table_idx))
        return Some(pos + 2)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr([@lib.ElemDrop(elem_idx), const_instr])
        ),
        if_instr,
      ) if sgo_const_instr(const_instr) != None &&
        sgo_instr_is_empty_void_if(if_instr) => {
        out.push(@lib.Instruction::elem_drop(elem_idx))
        return Some(pos + 2)
      }
      _ => ()
    }
  }
  if pos + 3 < instrs.length() {
    match (instrs[pos], instrs[pos + 1], instrs[pos + 2], instrs[pos + 3]) {
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr([@lib.Call(func_idx), @lib.Drop, cond_const])
        ),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_call_has_no_params_one_result(mod_, func_type_indices, func_idx) &&
        sgo_const_instr(cond_const) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(@lib.Instruction::call(func_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 4)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr([@lib.Call(func_idx), cond_const])
        ),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_call_has_no_params_no_results(mod_, func_type_indices, func_idx) &&
        sgo_const_instr(cond_const) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(@lib.Instruction::call(func_idx))
        return Some(pos + 4)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr([@lib.MemorySize(_), @lib.Drop, cond_const])
        ),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_const_instr(cond_const) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => return Some(pos + 4)
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr([@lib.TableSize(_), @lib.Drop, cond_const])
        ),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_const_instr(cond_const) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => return Some(pos + 4)
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr([value, @lib.LocalSet(local_idx), cond_const])
        ),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_local_effect_value_is_independent(value) &&
        sgo_const_instr(cond_const) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(value)
        out.push(@lib.Instruction::local_set(local_idx))
        return Some(pos + 4)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr(
            [
              value,
              @lib.LocalSet(local_idx),
              cond_const,
              @lib.LocalGet(get_idx),
              compare,
            ]
          )
        ),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if local_idx == get_idx &&
        sgo_local_effect_value_is_independent(value) &&
        sgo_const_instr(cond_const) != None &&
        sgo_is_compare_instr(compare) &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(value)
        out.push(@lib.Instruction::local_set(local_idx))
        return Some(pos + 4)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr(
            [
              value,
              @lib.LocalSet(local_idx),
              @lib.LocalGet(get_idx),
              cond_const,
              compare,
            ]
          )
        ),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if local_idx == get_idx &&
        sgo_local_effect_value_is_independent(value) &&
        sgo_const_instr(cond_const) != None &&
        sgo_is_compare_instr(compare) &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(value)
        out.push(@lib.Instruction::local_set(local_idx))
        return Some(pos + 4)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr([value, @lib.GlobalSet(global_idx), cond_const])
        ),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_const_instr(value) != None &&
        sgo_const_instr(cond_const) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(value)
        out.push(@lib.Instruction::global_set(global_idx))
        return Some(pos + 4)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr([value, @lib.LocalTee(local_idx), @lib.Drop, cond_const])
        ),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_const_instr(value) != None &&
        sgo_const_instr(cond_const) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(value)
        out.push(@lib.Instruction::local_set(local_idx))
        return Some(pos + 4)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr(
            [grow_delta, @lib.MemoryGrow(mem_idx), @lib.Drop, cond_const]
          )
        ),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_const_instr(grow_delta) != None &&
        sgo_const_instr(cond_const) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(grow_delta)
        out.push(@lib.Instruction::memory_grow(mem_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 4)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr(
            [
              ref_value,
              grow_delta,
              @lib.TableGrow(table_idx),
              @lib.Drop,
              cond_const,
            ]
          )
        ),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_const_instr(ref_value) != None &&
        sgo_const_instr(grow_delta) != None &&
        sgo_const_instr(cond_const) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(ref_value)
        out.push(grow_delta)
        out.push(@lib.Instruction::table_grow(table_idx))
        out.push(@lib.Instruction::drop())
        return Some(pos + 4)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr([dest, value, @lib.TableSet(table_idx), cond_const])
        ),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_const_instr(dest) != None &&
        sgo_const_instr(value) != None &&
        sgo_const_instr(cond_const) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(dest)
        out.push(value)
        out.push(@lib.Instruction::table_set(table_idx))
        return Some(pos + 4)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr([dest, value, len, @lib.TableFill(table_idx), cond_const])
        ),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_const_instr(dest) != None &&
        sgo_const_instr(value) != None &&
        sgo_const_instr(len) != None &&
        sgo_const_instr(cond_const) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(dest)
        out.push(value)
        out.push(len)
        out.push(@lib.Instruction::table_fill(table_idx))
        return Some(pos + 4)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr(
            [dest, src, len, @lib.TableCopy(dst_idx, src_idx), cond_const]
          )
        ),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_const_instr(dest) != None &&
        sgo_const_instr(src) != None &&
        sgo_const_instr(len) != None &&
        sgo_const_instr(cond_const) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(dest)
        out.push(src)
        out.push(len)
        out.push(@lib.Instruction::table_copy(dst_idx, src_idx))
        return Some(pos + 4)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr(
            [dest, src, len, @lib.TableInit(elem_idx, table_idx), cond_const]
          )
        ),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_const_instr(dest) != None &&
        sgo_const_instr(src) != None &&
        sgo_const_instr(len) != None &&
        sgo_const_instr(cond_const) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(dest)
        out.push(src)
        out.push(len)
        out.push(@lib.Instruction::table_init(elem_idx, table_idx))
        return Some(pos + 4)
      }
      (
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr([@lib.ElemDrop(elem_idx), cond_const])
        ),
        if_instr,
        dropped_const,
        @lib.Drop,
      ) if sgo_const_instr(cond_const) != None &&
        sgo_is_return_guard(if_instr) &&
        sgo_const_instr(dropped_const) != None => {
        out.push(@lib.Instruction::elem_drop(elem_idx))
        return Some(pos + 4)
      }
      _ => ()
    }
  }
  None
}

///|
fn sgo_cleanup_unreachable_drop_debris_instrs(
  instrs : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Bool) {
  let normalized : Array[@lib.Instruction] = []
  let mut recursive_changed = false
  for instr in instrs {
    match instr {
      @lib.Block(block_type, body) => {
        let (next_body, body_changed) = sgo_cleanup_unreachable_drop_debris_expr(
          body,
        )
        recursive_changed = recursive_changed || body_changed
        normalized.push(
          if body_changed {
            @lib.Instruction::block(block_type, next_body)
          } else {
            instr
          },
        )
      }
      @lib.Loop(block_type, body) => {
        let (next_body, body_changed) = sgo_cleanup_unreachable_drop_debris_expr(
          body,
        )
        recursive_changed = recursive_changed || body_changed
        normalized.push(
          if body_changed {
            @lib.Instruction::loop_(block_type, next_body)
          } else {
            instr
          },
        )
      }
      @lib.If(block_type, then_body, else_body) => {
        let (next_then_expr, then_changed) = sgo_cleanup_unreachable_drop_debris_expr(
          @lib.Expr::new(then_body),
        )
        let @lib.Expr(next_then) = next_then_expr
        let mut else_changed = false
        let next_else = match else_body {
          Some(body) => {
            let (next_else_expr, changed) = sgo_cleanup_unreachable_drop_debris_expr(
              @lib.Expr::new(body),
            )
            let @lib.Expr(next_else_body) = next_else_expr
            else_changed = changed
            Some(next_else_body)
          }
          None => None
        }
        recursive_changed = recursive_changed || then_changed || else_changed
        normalized.push(
          if then_changed || else_changed {
            @lib.Instruction::if_(block_type, next_then, next_else)
          } else {
            instr
          },
        )
      }
      @lib.TryTable(block_type, catches, body) => {
        let (next_body, body_changed) = sgo_cleanup_unreachable_drop_debris_expr(
          body,
        )
        recursive_changed = recursive_changed || body_changed
        normalized.push(
          if body_changed {
            @lib.Instruction::try_table(block_type, catches, next_body)
          } else {
            instr
          },
        )
      }
      _ => normalized.push(instr)
    }
  }

  let out : Array[@lib.Instruction] = []
  let mut changed = recursive_changed
  let mut pos = 0
  while pos < normalized.length() {
    if pos + 1 < normalized.length() &&
      normalized[pos + 1] == @lib.Instruction::unreachable_() {
      match normalized[pos] {
        @lib.Block(
          @lib.ValTypeBlockType(_)
          | @lib.TypeIdxBlockType(_),
          @lib.Expr(body)
        ) =>
          match body {
            [@lib.Unreachable] => {
              out.push(@lib.Instruction::unreachable_())
              changed = true
              pos += 2
              continue
            }
            [dead_value, @lib.Unreachable] if sgo_const_instr(dead_value) !=
              None => {
              out.push(dead_value)
              out.push(@lib.Instruction::drop())
              out.push(@lib.Instruction::unreachable_())
              changed = true
              pos += 2
              continue
            }
            _ => ()
          }
        _ => ()
      }
    }
    match normalized[pos] {
      @lib.Unreachable => {
        let mut next = pos + 1
        while next < normalized.length() &&
              normalized[next] == @lib.Instruction::drop() {
          next += 1
        }
        if next > pos + 1 &&
          next < normalized.length() &&
          normalized[next] == @lib.Instruction::unreachable_() {
          out.push(@lib.Instruction::unreachable_())
          changed = true
          pos = next + 1
          continue
        }
      }
      _ => ()
    }
    out.push(normalized[pos])
    pos += 1
  }
  (out, changed)
}

///|
fn sgo_cleanup_unreachable_drop_debris_expr(
  expr : @lib.Expr,
) -> (@lib.Expr, Bool) {
  let @lib.Expr(instrs) = expr
  let (cleaned, changed) = sgo_cleanup_unreachable_drop_debris_instrs(instrs)
  (@lib.Expr::new(cleaned), changed)
}

///|
fn sgo_cheap_cleanup_whole_load_select_dead_if(
  instrs : Array[@lib.Instruction],
) -> Array[@lib.Instruction]? {
  match instrs {
    [
      @lib.I32Const(_),
      @lib.I32Const(addr),
      @lib.I32Load(memarg),
      @lib.LocalTee(local_idx),
      @lib.I32Const(_),
      @lib.I32Const(_),
      @lib.I32Add,
      @lib.I32Eqz,
      @lib.Select(_),
      @lib.If(@lib.VoidBlockType, [dropped_const, @lib.Drop], None),
    ] if sgo_const_instr(dropped_const) != None &&
      !sgo_instrs_ref_local(instrs, local_idx, 0, instrs.length()) =>
      Some([
        @lib.Instruction::i32_const(addr),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::drop(),
      ])
    _ => None
  }
}

///|
fn sgo_cheap_cleanup_instrs(
  instrs : Array[@lib.Instruction],
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> (Array[@lib.Instruction], Bool) {
  // This common post-SGO shell is already final after preserving the load's
  // trap/effect. Recognize it before recursive normalization and the general
  // compare/select matcher roster.
  match sgo_cheap_cleanup_whole_load_select_dead_if(instrs) {
    Some(cleaned) => return (cleaned, true)
    None => ()
  }
  let normalized : Array[@lib.Instruction] = []
  let mut recursive_changed = false
  for instr in instrs {
    match instr {
      @lib.Block(block_type, body) => {
        let (next_body, body_changed) = sgo_cheap_cleanup_expr(
          body, mod_, func_type_indices,
        )
        recursive_changed = recursive_changed || body_changed
        normalized.push(
          if body_changed {
            @lib.Instruction::block(block_type, next_body)
          } else {
            instr
          },
        )
      }
      @lib.Loop(block_type, body) => {
        let (next_body, body_changed) = sgo_cheap_cleanup_expr(
          body, mod_, func_type_indices,
        )
        recursive_changed = recursive_changed || body_changed
        normalized.push(
          if body_changed {
            @lib.Instruction::loop_(block_type, next_body)
          } else {
            instr
          },
        )
      }
      @lib.If(block_type, then_body, else_body) => {
        let (next_then_expr, then_changed) = sgo_cheap_cleanup_expr(
          @lib.Expr::new(then_body),
          mod_,
          func_type_indices,
        )
        let @lib.Expr(next_then) = next_then_expr
        let mut else_changed = false
        let next_else = match else_body {
          Some(body) => {
            let (next_else_expr, changed) = sgo_cheap_cleanup_expr(
              @lib.Expr::new(body),
              mod_,
              func_type_indices,
            )
            let @lib.Expr(next_else_body) = next_else_expr
            else_changed = changed
            Some(next_else_body)
          }
          None => None
        }
        recursive_changed = recursive_changed || then_changed || else_changed
        normalized.push(
          if then_changed || else_changed {
            @lib.Instruction::if_(block_type, next_then, next_else)
          } else {
            instr
          },
        )
      }
      @lib.TryTable(block_type, catches, body) => {
        let (next_body, body_changed) = sgo_cheap_cleanup_expr(
          body, mod_, func_type_indices,
        )
        recursive_changed = recursive_changed || body_changed
        normalized.push(
          if body_changed {
            @lib.Instruction::try_table(block_type, catches, next_body)
          } else {
            instr
          },
        )
      }
      _ => normalized.push(instr)
    }
  }

  let out : Array[@lib.Instruction] = []
  let mut changed = recursive_changed
  let mut pos = 0
  while pos < normalized.length() {
    match
      sgo_cheap_cleanup_block_if_shell(
        normalized, pos, out, mod_, func_type_indices,
      ) {
      Some(next_pos) => {
        changed = true
        pos = next_pos
        continue
      }
      None => ()
    }
    match
      sgo_cheap_cleanup_compare_if_shell(
        normalized, pos, out, mod_, func_type_indices,
      ) {
      Some(next_pos) => {
        changed = true
        pos = next_pos
        continue
      }
      None => ()
    }
    match
      sgo_cheap_cleanup_select_if_shell(
        normalized, pos, out, mod_, func_type_indices,
      ) {
      Some(next_pos) => {
        changed = true
        pos = next_pos
        continue
      }
      None => ()
    }
    match normalized[pos] {
      @lib.If(
        @lib.ValTypeBlockType(@lib.NumTypeValType(@lib.I32NumType)),
        _,
        Some(_)
      ) if pos + 1 < normalized.length() &&
        sgo_instr_is_empty_void_if(normalized[pos + 1]) => {
        // Once SGO removes the guarded write, the empty outer if still
        // consumes this result-if's i32 value. Preserve all arm effects and
        // traps by replacing only that outer control shell with drop.
        out.push(normalized[pos])
        out.push(@lib.Instruction::drop())
        changed = true
        pos = pos + 2
        continue
      }
      _ => ()
    }
    if pos + 1 < normalized.length() &&
      sgo_const_instr(normalized[pos]) != None &&
      normalized[pos + 1] == @lib.Instruction::drop() {
      changed = true
      pos = pos + 2
      continue
    }
    if pos + 1 < normalized.length() &&
      sgo_instr_is_empty_void_if(normalized[pos + 1]) &&
      sgo_const_instr(normalized[pos]) != None {
      changed = true
      pos = pos + 2
      continue
    }
    if pos + 5 < normalized.length() {
      match
        (
          normalized[pos],
          normalized[pos + 1],
          normalized[pos + 2],
          normalized[pos + 3],
          normalized[pos + 4],
          normalized[pos + 5],
        ) {
        (
          @lib.I32Const(@lib.I32(value)),
          @lib.LocalTee(local_idx),
          @lib.Drop,
          @lib.LocalGet(first_get),
          @lib.LocalGet(second_get),
          @lib.I32Add,
        ) if local_idx == first_get &&
          local_idx == second_get &&
          !sgo_instrs_ref_local(normalized, local_idx, pos, pos + 6) =>
          match sgo_i32_add_no_overflow(value, value) {
            Some(sum) => {
              out.push(@lib.Instruction::i32_const(@lib.I32(value)))
              out.push(@lib.Instruction::local_set(local_idx))
              out.push(@lib.Instruction::i32_const(@lib.I32(sum)))
              changed = true
              pos = pos + 6
              continue
            }
            None => ()
          }
        _ => ()
      }
    }
    if pos + 3 < normalized.length() {
      match
        (
          normalized[pos],
          normalized[pos + 1],
          normalized[pos + 2],
          normalized[pos + 3],
        ) {
        (value, @lib.LocalTee(local_idx), @lib.Drop, @lib.LocalGet(get_idx)) if local_idx ==
          get_idx &&
          sgo_local_effect_value_is_independent(value) &&
          !sgo_instrs_ref_local(normalized, local_idx, pos, pos + 4) => {
          out.push(value)
          changed = true
          pos = pos + 4
          continue
        }
        _ => ()
      }
    }
    if pos + 2 < normalized.length() {
      match (normalized[pos], normalized[pos + 1], normalized[pos + 2]) {
        (@lib.I32Const(@lib.I32(lhs)), @lib.I32Const(@lib.I32(rhs)), @lib.I32Add
        ) =>
          match sgo_i32_add_no_overflow(lhs, rhs) {
            Some(sum) => {
              out.push(@lib.Instruction::i32_const(@lib.I32(sum)))
              changed = true
              pos = pos + 3
              continue
            }
            None => ()
          }
        _ => ()
      }
    }
    if pos + 1 < normalized.length() {
      match (normalized[pos], normalized[pos + 1]) {
        (@lib.I32Const(@lib.I32(value)), @lib.I32Eqz) => {
          out.push(
            @lib.Instruction::i32_const(
              @lib.I32(if value == 0 { 1 } else { 0 }),
            ),
          )
          changed = true
          pos = pos + 2
          continue
        }
        _ => ()
      }
    }
    out.push(normalized[pos])
    pos = pos + 1
  }
  (out, changed)
}

///|
fn sgo_cheap_cleanup_expr(
  expr : @lib.Expr,
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> (@lib.Expr, Bool) {
  let mut current = expr
  let mut any_changed = false
  let mut keep_going = true
  while keep_going {
    let @lib.Expr(instrs) = current
    let (cleaned, changed) = sgo_cheap_cleanup_instrs(
      instrs, mod_, func_type_indices,
    )
    if changed {
      current = @lib.Expr::new(cleaned)
      any_changed = true
    } else {
      keep_going = false
    }
  }
  (current, any_changed)
}

///|
fn sgo_expr_is_final_runtime_set_get_shape(expr : @lib.Expr) -> Bool {
  match expr {
    @lib.Expr(
      [written, @lib.GlobalSet(_), @lib.LocalGet(_), replacement, @lib.I32Add]
    ) => sgo_const_instr(written) != None && written == replacement
    @lib.Expr(
      [written, @lib.GlobalSet(_), replacement, @lib.LocalGet(_), @lib.I32Add]
    ) => sgo_const_instr(written) != None && written == replacement
    _ => false
  }
}

///|
fn sgo_rewrite_runtime_trace_expr_with_facts(
  expr : @lib.Expr,
  infos : Array[SgoGlobalInfo],
  facts : Array[@lib.Instruction?],
) -> (@lib.Expr, Bool) {
  let @lib.Expr(instrs) = expr
  let out : Array[@lib.Instruction] = []
  let mut changed = false
  for pos = 0; pos < instrs.length(); pos = pos + 1 {
    let instr = instrs[pos]
    match instr {
      @lib.GlobalGet(idx) => {
        let slot = sgo_global_idx_slot(idx)
        if sgo_runtime_trace_trackable(infos, slot) {
          match facts[slot] {
            Some(replacement) => {
              out.push(replacement)
              changed = true
              continue
            }
            None => ()
          }
        }
        out.push(instr)
      }
      @lib.GlobalSet(idx) => {
        out.push(instr)
        let slot = sgo_global_idx_slot(idx)
        if sgo_runtime_trace_trackable(infos, slot) {
          facts[slot] = if pos > 0 {
            sgo_const_instr(instrs[pos - 1])
          } else {
            None
          }
        }
      }
      @lib.Block(block_type, body) => {
        let body_has_barrier = sgo_runtime_trace_expr_has_barrier(body)
        let body_facts = facts.copy()
        let (next_body, body_changed) = sgo_rewrite_runtime_trace_expr_with_facts(
          body, infos, body_facts,
        )
        out.push(
          if body_changed {
            @lib.Instruction::block(block_type, next_body)
          } else {
            instr
          },
        )
        changed = changed || body_changed
        if body_has_barrier {
          sgo_runtime_trace_clear(facts)
        } else {
          sgo_runtime_trace_copy_facts(facts, body_facts)
        }
      }
      @lib.If(block_type, then_body, Some(else_body)) => {
        let then_facts = facts.copy()
        let (next_then, then_changed) = sgo_rewrite_runtime_trace_expr_with_facts(
          @lib.Expr::new(then_body),
          infos,
          then_facts,
        )
        let @lib.Expr(next_then_body) = next_then
        out.push(
          if then_changed {
            @lib.Instruction::if_(block_type, next_then_body, Some(else_body))
          } else {
            instr
          },
        )
        changed = changed || then_changed
        sgo_runtime_trace_clear(facts)
      }
      @lib.If(block_type, then_body, None) => {
        let then_facts = facts.copy()
        let (next_then, then_changed) = sgo_rewrite_runtime_trace_expr_with_facts(
          @lib.Expr::new(then_body),
          infos,
          then_facts,
        )
        let @lib.Expr(next_then_body) = next_then
        out.push(
          if then_changed {
            @lib.Instruction::if_(block_type, next_then_body, None)
          } else {
            instr
          },
        )
        changed = changed || then_changed
        sgo_runtime_trace_clear(facts)
      }
      _ => {
        out.push(instr)
        if sgo_runtime_trace_barrier(instr) {
          sgo_runtime_trace_clear(facts)
        }
      }
    }
  }
  (@lib.Expr::new(out), changed)
}

///|
fn sgo_rewrite_code_sec(
  mod_ : @lib.Module,
  code_sec : @lib.CodeSec?,
  infos : Array[SgoGlobalInfo],
  consts : Array[@lib.Instruction?],
  aliases : Array[@lib.GlobalIdx?],
  remove_sets : Array[Bool],
) -> (@lib.CodeSec?, Array[Bool], Bool) {
  let func_type_indices = sgo_collect_func_type_indices(mod_)
  match code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let out : Array[@lib.Func] = []
      let touched = Array::make(funcs.length(), false)
      let mut changed = false
      for idx = 0; idx < funcs.length(); idx = idx + 1 {
        let @lib.Func(locals, body) = funcs[idx]
        if !sgo_expr_may_reference_global(body) {
          let @lib.Expr(original_instrs) = body
          let cleanup_allowed = locals.length() <= 192 &&
            original_instrs.length() <= 1000
          let (cleaned, cleanup_changed) = if cleanup_allowed {
            sgo_cleanup_unreachable_drop_debris_expr(body)
          } else {
            (body, false)
          }
          if cleanup_changed {
            out.push(@lib.Func::new(locals, cleaned))
            changed = true
          } else {
            out.push(funcs[idx])
          }
          continue
        }
        let (rewritten, func_changed) = sgo_rewrite_expr(
          body, consts, aliases, remove_sets, true,
        )
        let (runtime_rewritten, runtime_changed) = sgo_rewrite_runtime_trace_expr(
          rewritten, infos,
        )
        let @lib.Expr(original_instrs) = body
        let cleanup_allowed = locals.length() <= 192 &&
          original_instrs.length() <= 1000
        let (cleaned, cleanup_changed) = if cleanup_allowed {
          sgo_cheap_cleanup_expr(runtime_rewritten, mod_, func_type_indices)
        } else {
          (runtime_rewritten, false)
        }
        if func_changed || runtime_changed || cleanup_changed {
          let final_body = match cleaned {
            @lib.Expr([]) => @lib.Expr::new([@lib.Instruction::nop()])
            _ => cleaned
          }
          // When the SGO-owned cheap cleanup consumed the debris it created, or
          // runtime propagation already produced the same simple set/get shape
          // Binaryen leaves behind, do not enqueue large batches for the
          // expensive Binaryen-default nested cleanup roster just to rediscover
          // that no pass has work.
          touched[idx] = !(cleanup_allowed &&
            funcs.length() > 256 &&
            (
              cleanup_changed ||
              sgo_expr_is_final_runtime_set_get_shape(final_body)
            ))
          changed = true
          out.push(@lib.Func::new(locals, final_body))
        } else {
          out.push(funcs[idx])
        }
      }
      (Some(@lib.CodeSec::new(out)), touched, changed)
    }
    None => (None, [], false)
  }
}

///|
fn sgo_build_module(
  mod_ : @lib.Module,
  global_sec : @lib.GlobalSec?,
  table_sec : @lib.TableSec?,
  elem_sec : @lib.ElemSec?,
  data_sec : @lib.DataSec?,
  code_sec : @lib.CodeSec?,
) -> @lib.Module {
  @lib.Module::new(
    custom_secs=mod_.custom_secs,
    type_sec=mod_.type_sec,
    import_sec=mod_.import_sec,
    func_annotation_sec=mod_.func_annotation_sec,
    func_sec=mod_.func_sec,
    table_sec~,
    mem_sec=mod_.mem_sec,
    tag_sec=mod_.tag_sec,
    stringrefs_sec=mod_.stringrefs_sec,
    global_sec~,
    export_sec=mod_.export_sec,
    start_sec=mod_.start_sec,
    elem_sec~,
    data_cnt_sec=mod_.data_cnt_sec,
    code_sec~,
    data_sec~,
    name_sec=mod_.name_sec,
    raw_name_sec_payload=mod_.raw_name_sec_payload,
  )
}

///|
fn sgo_run_core(
  mod_ : @lib.Module,
  trace : (String) -> Unit,
  perf? : HotPerfSession? = None,
) -> SgoPassResult {
  if pass_module_has_legacy_try(mod_) {
    let touched = match mod_.code_sec {
      Some(@lib.CodeSec(funcs)) => Array::make(funcs.length(), false)
      None => []
    }
    return { mod_out: mod_, touched }
  }
  let collect_start_us = perf_start_timer_opt(
    perf, "detail:sgo:collect-global-infos",
  )
  let (infos, imported_globals) = sgo_collect_global_infos(mod_)
  perf_stop_timer_opt(perf, "detail:sgo:collect-global-infos", collect_start_us)
  let flags_start_us = perf_start_timer_opt(perf, "detail:sgo:plan-flags")
  let same_init_writes = sgo_same_init_write_flags(mod_.code_sec, infos)
  let read_only_to_write = sgo_read_only_to_write_flags(mod_, infos)
  let remove_sets = sgo_plan_remove_sets(
    infos, same_init_writes, read_only_to_write,
  )
  let mut changed = sgo_apply_practical_immutability(infos, remove_sets)
  perf_stop_timer_opt(perf, "detail:sgo:plan-flags", flags_start_us)
  let global_start_us = perf_start_timer_opt(perf, "detail:sgo:rewrite-globals")
  let (next_global_sec, startup_consts, aliases, global_changed) = sgo_rewrite_global_sec(
    mod_.global_sec,
    infos,
    imported_globals,
  )
  changed = changed || global_changed
  let code_consts = sgo_build_code_consts(infos)
  perf_stop_timer_opt(perf, "detail:sgo:rewrite-globals", global_start_us)
  let startup_start_us = perf_start_timer_opt(
    perf, "detail:sgo:rewrite-startup",
  )
  let (next_table_sec, table_changed) = sgo_rewrite_table_sec(
    mod_.table_sec,
    startup_consts,
    remove_sets,
  )
  let (next_elem_sec, elem_changed) = sgo_rewrite_elem_sec(
    mod_.elem_sec,
    startup_consts,
    remove_sets,
  )
  let (next_data_sec, data_changed) = sgo_rewrite_data_sec(
    mod_.data_sec,
    startup_consts,
    remove_sets,
  )
  perf_stop_timer_opt(perf, "detail:sgo:rewrite-startup", startup_start_us)
  let code_start_us = perf_start_timer_opt(perf, "detail:sgo:rewrite-code")
  let (next_code_sec, touched, code_changed) = sgo_rewrite_code_sec(
    mod_,
    mod_.code_sec,
    infos,
    code_consts,
    aliases,
    remove_sets,
  )
  perf_stop_timer_opt(perf, "detail:sgo:rewrite-code", code_start_us)
  changed = changed ||
    table_changed ||
    elem_changed ||
    data_changed ||
    code_changed
  if code_changed {
    trace(
      "pass[simplify-globals-optimizing]:rewrite touched=\{sgo_count_touched(touched)}",
    )
  }
  if !changed {
    return { mod_out: mod_, touched }
  }
  {
    mod_out: sgo_build_module(
      mod_, next_global_sec, next_table_sec, next_elem_sec, next_data_sec, next_code_sec,
    ),
    touched,
  }
}

///|
fn sgo_count_touched(touched : Array[Bool]) -> Int {
  let mut count = 0
  for item in touched {
    if item {
      count += 1
    }
  }
  count
}
