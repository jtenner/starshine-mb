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
priv struct SgoFlowValue {
  tainted : Bool
  i31_ref : Bool
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
fn sgo_expr_may_reference_global(expr : @lib.Expr) -> Bool {
  let @lib.Expr(instrs) = expr
  sgo_instrs_may_reference_global(instrs)
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
  code_sec : @lib.CodeSec?,
  infos : Array[SgoGlobalInfo],
) -> Array[Bool] {
  let safe_reads = Array::make(infos.length(), 0)
  match code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func_ in funcs {
        let @lib.Func(_, body) = func_
        if sgo_expr_may_reference_global(body) {
          sgo_count_read_only_to_write_expr(body, safe_reads)
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
) -> Unit {
  let @lib.Expr(instrs) = expr
  sgo_count_read_only_to_write_instrs(instrs, safe_reads)
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
fn sgo_count_read_only_to_write_instrs(
  instrs : Array[@lib.Instruction],
  safe_reads : Array[Int],
) -> Unit {
  for pos = 0; pos < instrs.length(); pos = pos + 1 {
    let instr = instrs[pos]
    match instr {
      @lib.GlobalGet(idx) if sgo_read_only_to_write_read_at(instrs, pos, idx) =>
        sgo_count_read_only_to_write_safe_read(idx, safe_reads)
      @lib.Block(_, body) => {
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
          sgo_count_block_wrapped_nested_if_arm_flow_read(
            instr,
            instrs[pos + 1],
            safe_reads,
          )
        }
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
        sgo_count_read_only_to_write_expr(body, safe_reads)
      }
      @lib.Loop(_, body) => sgo_count_read_only_to_write_expr(body, safe_reads)
      @lib.If(_, then_body, else_body) => {
        sgo_count_nested_if_arm_flow_read(instrs, pos, safe_reads)
        sgo_count_read_only_to_write_instrs(then_body, safe_reads)
        match else_body {
          Some(body) => sgo_count_read_only_to_write_instrs(body, safe_reads)
          None => ()
        }
      }
      @lib.TryTable(_, _, body) =>
        sgo_count_read_only_to_write_expr(body, safe_reads)
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
fn sgo_flow_plain(tainted : Bool) -> SgoFlowValue {
  SgoFlowValue::{ tainted, i31_ref: false }
}

///|
fn sgo_flow_i31_ref(tainted : Bool) -> SgoFlowValue {
  SgoFlowValue::{ tainted, i31_ref: true }
}

///|
fn sgo_flow_pop(stack : Array[SgoFlowValue]) -> SgoFlowValue? {
  stack.pop()
}

///|
fn sgo_flow_push_clean(stack : Array[SgoFlowValue]) -> Unit {
  stack.push(sgo_flow_plain(false))
}

///|
fn sgo_flow_push_tainted(stack : Array[SgoFlowValue]) -> Unit {
  stack.push(sgo_flow_plain(true))
}

///|
fn sgo_flow_apply_unary(
  stack : Array[SgoFlowValue],
  instr : @lib.Instruction,
) -> Bool {
  match sgo_flow_pop(stack) {
    Some(value) =>
      match instr {
        @lib.RefI31 => {
          stack.push(sgo_flow_i31_ref(value.tainted))
          true
        }
        @lib.I31GetS | @lib.I31GetU =>
          if value.i31_ref {
            stack.push(sgo_flow_plain(value.tainted))
            true
          } else {
            false
          }
        @lib.RefAsNonNull =>
          if value.i31_ref {
            stack.push(value)
            true
          } else {
            false
          }
        _ => {
          stack.push(sgo_flow_plain(value.tainted))
          true
        }
      }
    None => false
  }
}

///|
fn sgo_flow_apply_binary(stack : Array[SgoFlowValue]) -> Bool {
  match (sgo_flow_pop(stack), sgo_flow_pop(stack)) {
    (Some(rhs), Some(lhs)) => {
      stack.push(sgo_flow_plain(lhs.tainted || rhs.tainted))
      true
    }
    _ => false
  }
}

///|
fn sgo_flow_pop_clean_pair(stack : Array[SgoFlowValue]) -> Bool {
  match (sgo_flow_pop(stack), sgo_flow_pop(stack)) {
    (Some(rhs), Some(lhs)) => !rhs.tainted && !lhs.tainted
    _ => false
  }
}

///|
fn sgo_flow_stack_has_taint(stack : Array[SgoFlowValue]) -> Bool {
  stack.any(fn(value) { value.tainted })
}

///|
fn sgo_flow_stack_single_taint(stack : Array[SgoFlowValue]) -> Bool {
  match stack {
    [value] => value.tainted
    _ => false
  }
}

///|
fn sgo_flow_clear_stack(stack : Array[SgoFlowValue]) -> Unit {
  while stack.length() > 0 {
    ignore(stack.pop())
  }
}

///|
fn sgo_is_flowscanner_nullary_pure_instr(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.MemorySize(_) | @lib.TableSize(_) => true
    _ => false
  }
}

///|
fn sgo_flow_apply_select(stack : Array[SgoFlowValue]) -> Bool {
  match (sgo_flow_pop(stack), sgo_flow_pop(stack), sgo_flow_pop(stack)) {
    (Some(condition), Some(second), Some(first)) => {
      stack.push(SgoFlowValue::{
        tainted: first.tainted || second.tainted || condition.tainted,
        i31_ref: first.i31_ref && second.i31_ref,
      })
      true
    }
    _ => false
  }
}

///|
fn sgo_is_flowscanner_unary_pure_instr(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.RefIsNull
    | @lib.RefTest(_, _)
    | @lib.RefAsNonNull
    | @lib.I31GetS
    | @lib.I31GetU
    | @lib.AnyConvertExtern
    | @lib.ExternConvertAny
    | @lib.RefI31
    | @lib.I32Clz
    | @lib.I32Ctz
    | @lib.I32Popcnt
    | @lib.I32Eqz
    | @lib.I64Clz
    | @lib.I64Ctz
    | @lib.I64Popcnt
    | @lib.I64Eqz
    | @lib.F32Abs
    | @lib.F32Neg
    | @lib.F32Ceil
    | @lib.F32Floor
    | @lib.F32Trunc
    | @lib.F32Nearest
    | @lib.F32Sqrt
    | @lib.F32ConvertI32S
    | @lib.F32ConvertI32U
    | @lib.F32ConvertI64S
    | @lib.F32ConvertI64U
    | @lib.F32DemoteF64
    | @lib.F64Abs
    | @lib.F64Neg
    | @lib.F64Ceil
    | @lib.F64Floor
    | @lib.F64Trunc
    | @lib.F64Nearest
    | @lib.F64Sqrt
    | @lib.F64ConvertI32S
    | @lib.F64ConvertI32U
    | @lib.F64ConvertI64S
    | @lib.F64ConvertI64U
    | @lib.F64PromoteF32
    | @lib.I32WrapI64
    | @lib.I64ExtendI32S
    | @lib.I64ExtendI32U
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
    | @lib.I64TruncSatF64U
    | @lib.I8x16Splat
    | @lib.I16x8Splat
    | @lib.I32x4Splat
    | @lib.I64x2Splat
    | @lib.F32x4Splat
    | @lib.F64x2Splat
    | @lib.I8x16Abs
    | @lib.I8x16Neg
    | @lib.I8x16Popcnt
    | @lib.I8x16Bitmask
    | @lib.I8x16AllTrue
    | @lib.F32x4Ceil
    | @lib.F32x4Floor
    | @lib.F32x4Trunc
    | @lib.F32x4Nearest
    | @lib.F64x2Ceil
    | @lib.F64x2Floor
    | @lib.F64x2Trunc
    | @lib.F64x2Nearest
    | @lib.I16x8Abs
    | @lib.I16x8Neg
    | @lib.I16x8AllTrue
    | @lib.I16x8Bitmask
    | @lib.I32x4Abs
    | @lib.I32x4Neg
    | @lib.I32x4AllTrue
    | @lib.I32x4Bitmask
    | @lib.F32x4DemoteF64x2Zero
    | @lib.F64x2PromoteLowF32x4
    | @lib.I16x8ExtendLowI8x16S
    | @lib.I16x8ExtendHighI8x16S
    | @lib.I16x8ExtendLowI8x16U
    | @lib.I16x8ExtendHighI8x16U
    | @lib.I32x4ExtendLowI16x8S
    | @lib.I32x4ExtendHighI16x8S
    | @lib.I32x4ExtendLowI16x8U
    | @lib.I32x4ExtendHighI16x8U
    | @lib.I64x2ExtendLowI32x4S
    | @lib.I64x2ExtendHighI32x4S
    | @lib.I64x2ExtendLowI32x4U
    | @lib.I64x2ExtendHighI32x4U
    | @lib.I16x8ExtaddPairwiseI8x16S
    | @lib.I16x8ExtaddPairwiseI8x16U
    | @lib.I32x4ExtaddPairwiseI16x8S
    | @lib.I32x4ExtaddPairwiseI16x8U
    | @lib.I32x4TruncSatF32x4S
    | @lib.I32x4TruncSatF32x4U
    | @lib.I32x4TruncSatF64x2SZero
    | @lib.I32x4TruncSatF64x2UZero
    | @lib.V128Not
    | @lib.V128AnyTrue
    | @lib.F32x4ConvertI32x4S
    | @lib.F32x4ConvertI32x4U
    | @lib.F64x2ConvertLowI32x4S
    | @lib.F64x2ConvertLowI32x4U
    | @lib.I8x16ExtractLaneS(_)
    | @lib.I8x16ExtractLaneU(_)
    | @lib.I16x8ExtractLaneS(_)
    | @lib.I16x8ExtractLaneU(_)
    | @lib.I32x4ExtractLane(_)
    | @lib.I64x2ExtractLane(_)
    | @lib.I64x2Abs
    | @lib.F32x4ExtractLane(_)
    | @lib.F64x2ExtractLane(_)
    | @lib.I64x2Neg
    | @lib.I64x2AllTrue
    | @lib.I64x2Bitmask
    | @lib.F32x4Abs
    | @lib.F32x4Neg
    | @lib.F32x4Sqrt
    | @lib.F64x2Abs
    | @lib.F64x2Neg
    | @lib.F64x2Sqrt => true
    _ => false
  }
}

///|
fn sgo_is_flowscanner_binary_pure_instr(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.RefEq
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
    | @lib.I64Rotr
    | @lib.F32Eq
    | @lib.F32Ne
    | @lib.F32Lt
    | @lib.F32Gt
    | @lib.F32Le
    | @lib.F32Ge
    | @lib.F32Add
    | @lib.F32Sub
    | @lib.F32Mul
    | @lib.F32Min
    | @lib.F32Max
    | @lib.F32Copysign
    | @lib.F32Div
    | @lib.F64Eq
    | @lib.F64Ne
    | @lib.F64Lt
    | @lib.F64Gt
    | @lib.F64Le
    | @lib.F64Ge
    | @lib.F64Add
    | @lib.F64Sub
    | @lib.F64Mul
    | @lib.F64Min
    | @lib.F64Max
    | @lib.F64Copysign
    | @lib.F64Div
    | @lib.I8x16Eq
    | @lib.I8x16Ne
    | @lib.I8x16LtS
    | @lib.I8x16LtU
    | @lib.I8x16GtS
    | @lib.I8x16GtU
    | @lib.I8x16LeS
    | @lib.I8x16LeU
    | @lib.I8x16GeS
    | @lib.I8x16GeU
    | @lib.I16x8Ne
    | @lib.I16x8LtS
    | @lib.I16x8LtU
    | @lib.I16x8GtS
    | @lib.I16x8GtU
    | @lib.I16x8LeS
    | @lib.I16x8LeU
    | @lib.I16x8GeS
    | @lib.I16x8GeU
    | @lib.I32x4Ne
    | @lib.I32x4LtS
    | @lib.I32x4LtU
    | @lib.I32x4GtS
    | @lib.I32x4GtU
    | @lib.I32x4LeS
    | @lib.I32x4LeU
    | @lib.I32x4GeS
    | @lib.I32x4GeU
    | @lib.I64x2Ne
    | @lib.I64x2LtS
    | @lib.I64x2GtS
    | @lib.I64x2LeS
    | @lib.I64x2GeS
    | @lib.F32x4Eq
    | @lib.F32x4Lt
    | @lib.F32x4Gt
    | @lib.F32x4Le
    | @lib.F32x4Ge
    | @lib.F64x2Eq
    | @lib.F64x2Lt
    | @lib.F64x2Gt
    | @lib.F64x2Le
    | @lib.F64x2Ge
    | @lib.V128And
    | @lib.V128Andnot
    | @lib.V128Or
    | @lib.V128Xor
    | @lib.I8x16Shuffle(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | @lib.I8x16Swizzle
    | @lib.I8x16ReplaceLane(_)
    | @lib.I16x8ReplaceLane(_)
    | @lib.I32x4ReplaceLane(_)
    | @lib.I64x2ReplaceLane(_)
    | @lib.F32x4ReplaceLane(_)
    | @lib.F64x2ReplaceLane(_)
    | @lib.I8x16Shl
    | @lib.I8x16ShrS
    | @lib.I8x16ShrU
    | @lib.I16x8Shl
    | @lib.I16x8ShrS
    | @lib.I16x8ShrU
    | @lib.I32x4Shl
    | @lib.I32x4ShrS
    | @lib.I32x4ShrU
    | @lib.I64x2Shl
    | @lib.I64x2ShrS
    | @lib.I64x2ShrU
    | @lib.I8x16NarrowI16x8S
    | @lib.I8x16NarrowI16x8U
    | @lib.I16x8NarrowI32x4S
    | @lib.I16x8NarrowI32x4U
    | @lib.I16x8ExtmulLowI8x16S
    | @lib.I16x8ExtmulHighI8x16S
    | @lib.I16x8ExtmulLowI8x16U
    | @lib.I16x8ExtmulHighI8x16U
    | @lib.I32x4ExtmulLowI16x8S
    | @lib.I32x4ExtmulHighI16x8S
    | @lib.I32x4ExtmulLowI16x8U
    | @lib.I32x4ExtmulHighI16x8U
    | @lib.I64x2ExtmulLowI32x4S
    | @lib.I64x2ExtmulHighI32x4S
    | @lib.I64x2ExtmulLowI32x4U
    | @lib.I64x2ExtmulHighI32x4U
    | @lib.I8x16Add
    | @lib.I8x16AddSatS
    | @lib.I8x16AddSatU
    | @lib.I8x16Sub
    | @lib.I8x16SubSatS
    | @lib.I8x16SubSatU
    | @lib.I8x16MinS
    | @lib.I8x16MinU
    | @lib.I8x16MaxS
    | @lib.I8x16MaxU
    | @lib.I8x16AvgrU
    | @lib.I16x8Add
    | @lib.I16x8AddSatS
    | @lib.I16x8AddSatU
    | @lib.I16x8Sub
    | @lib.I16x8SubSatS
    | @lib.I16x8SubSatU
    | @lib.I16x8Mul
    | @lib.I16x8MinS
    | @lib.I16x8MinU
    | @lib.I16x8MaxS
    | @lib.I16x8MaxU
    | @lib.I16x8AvgrU
    | @lib.I16x8Q15mulrSatS
    | @lib.I16x8Eq
    | @lib.I32x4Add
    | @lib.I32x4Sub
    | @lib.I32x4Mul
    | @lib.I32x4MinS
    | @lib.I32x4MinU
    | @lib.I32x4MaxS
    | @lib.I32x4MaxU
    | @lib.I32x4DotI16x8S
    | @lib.I32x4Eq
    | @lib.I64x2Add
    | @lib.I64x2Sub
    | @lib.I64x2Mul
    | @lib.I64x2Eq
    | @lib.F32x4Add
    | @lib.F32x4Sub
    | @lib.F32x4Mul
    | @lib.F32x4Div
    | @lib.F32x4Min
    | @lib.F32x4Max
    | @lib.F32x4Pmin
    | @lib.F32x4Pmax
    | @lib.F32x4Ne
    | @lib.F64x2Add
    | @lib.F64x2Sub
    | @lib.F64x2Mul
    | @lib.F64x2Div
    | @lib.F64x2Min
    | @lib.F64x2Max
    | @lib.F64x2Pmin
    | @lib.F64x2Pmax
    | @lib.F64x2Ne => true
    _ => false
  }
}

///|
fn sgo_is_flowscanner_trapping_read_instr(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.TableGet(_)
    | @lib.I32Load(_)
    | @lib.I64Load(_)
    | @lib.F32Load(_)
    | @lib.F64Load(_)
    | @lib.I32Load8S(_)
    | @lib.I32Load8U(_)
    | @lib.I32Load16S(_)
    | @lib.I32Load16U(_)
    | @lib.I64Load8S(_)
    | @lib.I64Load8U(_)
    | @lib.I64Load16S(_)
    | @lib.I64Load16U(_)
    | @lib.I64Load32S(_)
    | @lib.I64Load32U(_) => true
    _ => false
  }
}

///|
fn sgo_flow_scan_prefix_until(
  instrs : Array[@lib.Instruction],
  end_ : Int,
  idx : @lib.GlobalIdx,
) -> (Bool, Int, Array[SgoFlowValue]) {
  let stack : Array[SgoFlowValue] = []
  let mut reads = 0
  for scan = 0; scan < end_; scan = scan + 1 {
    let instr = instrs[scan]
    if sgo_const_instr(instr) != None ||
      sgo_is_flowscanner_nullary_pure_instr(instr) {
      sgo_flow_push_clean(stack)
      continue
    }
    match instr {
      @lib.GlobalGet(get_idx) => {
        if get_idx == idx {
          reads += 1
          sgo_flow_push_tainted(stack)
        } else {
          sgo_flow_push_clean(stack)
        }
        continue
      }
      @lib.LocalGet(_) => {
        sgo_flow_push_clean(stack)
        continue
      }
      @lib.TableSet(_)
      | @lib.I32Store(_)
      | @lib.I64Store(_)
      | @lib.I32Store8(_)
      | @lib.I32Store16(_) =>
        if sgo_flow_pop_clean_pair(stack) {
          continue
        } else {
          return (false, reads, stack)
        }
      @lib.GlobalSet(_) | @lib.LocalSet(_) =>
        match sgo_flow_pop(stack) {
          Some(value) if !value.tainted => continue
          _ => return (false, reads, stack)
        }
      @lib.LocalTee(_) =>
        match sgo_flow_pop(stack) {
          Some(value) if !value.tainted => {
            sgo_flow_push_clean(stack)
            continue
          }
          _ => return (false, reads, stack)
        }
      _ if sgo_is_flowscanner_trapping_read_instr(instr) =>
        match sgo_flow_pop(stack) {
          Some(value) if !value.tainted => {
            sgo_flow_push_clean(stack)
            continue
          }
          _ => return (false, reads, stack)
        }
      @lib.Drop =>
        match sgo_flow_pop(stack) {
          Some(value) if !value.tainted => continue
          _ => return (false, reads, stack)
        }
      @lib.Call(_) | @lib.CallIndirect(_, _) | @lib.CallRef(_) => {
        if sgo_flow_stack_has_taint(stack) {
          return (false, reads, stack)
        }
        sgo_flow_clear_stack(stack)
        sgo_flow_push_clean(stack)
        continue
      }
      @lib.Select(_) | @lib.V128Bitselect => {
        if !sgo_flow_apply_select(stack) {
          return (false, reads, stack)
        }
        continue
      }
      @lib.If(@lib.ValTypeBlockType(_), then_body, Some(else_body)) => {
        match sgo_flow_pop(stack) {
          Some(value) if !value.tainted => ()
          _ => return (false, reads, stack)
        }
        let (then_ok, then_reads, then_tainted) = sgo_flow_arm_result_taint_and_reads(
          then_body, idx,
        )
        let (else_ok, else_reads, else_tainted) = sgo_flow_arm_result_taint_and_reads(
          else_body, idx,
        )
        reads = reads + then_reads + else_reads
        if !then_ok || !else_ok || reads > 1 {
          return (false, reads, stack)
        }
        stack.push(sgo_flow_plain(then_tainted || else_tainted))
        continue
      }
      _ => {
        if sgo_is_flowscanner_unary_pure_instr(instr) {
          if !sgo_flow_apply_unary(stack, instr) {
            return (false, reads, stack)
          }
          continue
        }
        if sgo_is_flowscanner_binary_pure_instr(instr) {
          if !sgo_flow_apply_binary(stack) {
            return (false, reads, stack)
          }
          continue
        }
        return (false, reads, stack)
      }
    }
  }
  (true, reads, stack)
}

///|
fn sgo_flow_scan_clean_prefix_until(
  instrs : Array[@lib.Instruction],
  end_ : Int,
) -> (Bool, Array[SgoFlowValue]) {
  let stack : Array[SgoFlowValue] = []
  for scan = 0; scan < end_; scan = scan + 1 {
    let instr = instrs[scan]
    if sgo_const_instr(instr) != None ||
      sgo_is_flowscanner_nullary_pure_instr(instr) {
      sgo_flow_push_clean(stack)
      continue
    }
    match instr {
      @lib.GlobalGet(_) | @lib.LocalGet(_) => {
        sgo_flow_push_clean(stack)
        continue
      }
      @lib.TableSet(_)
      | @lib.I32Store(_)
      | @lib.I64Store(_)
      | @lib.I32Store8(_)
      | @lib.I32Store16(_) =>
        if sgo_flow_pop_clean_pair(stack) {
          continue
        } else {
          return (false, stack)
        }
      @lib.GlobalSet(_) | @lib.LocalSet(_) =>
        match sgo_flow_pop(stack) {
          Some(value) if !value.tainted => continue
          _ => return (false, stack)
        }
      @lib.LocalTee(_) =>
        match sgo_flow_pop(stack) {
          Some(value) if !value.tainted => {
            sgo_flow_push_clean(stack)
            continue
          }
          _ => return (false, stack)
        }
      _ if sgo_is_flowscanner_trapping_read_instr(instr) =>
        match sgo_flow_pop(stack) {
          Some(value) if !value.tainted => {
            sgo_flow_push_clean(stack)
            continue
          }
          _ => return (false, stack)
        }
      @lib.Drop =>
        match sgo_flow_pop(stack) {
          Some(value) if !value.tainted => continue
          _ => return (false, stack)
        }
      @lib.Call(_) | @lib.CallIndirect(_, _) | @lib.CallRef(_) => {
        if sgo_flow_stack_has_taint(stack) {
          return (false, stack)
        }
        sgo_flow_clear_stack(stack)
        sgo_flow_push_clean(stack)
        continue
      }
      @lib.Select(_) | @lib.V128Bitselect => {
        if !sgo_flow_apply_select(stack) {
          return (false, stack)
        }
        continue
      }
      _ => {
        if sgo_is_flowscanner_unary_pure_instr(instr) {
          if !sgo_flow_apply_unary(stack, instr) {
            return (false, stack)
          }
          continue
        }
        if sgo_is_flowscanner_binary_pure_instr(instr) {
          if !sgo_flow_apply_binary(stack) {
            return (false, stack)
          }
          continue
        }
        return (false, stack)
      }
    }
  }
  (true, stack)
}

///|
fn sgo_flow_arm_result_taint_and_reads(
  instrs : Array[@lib.Instruction],
  idx : @lib.GlobalIdx,
) -> (Bool, Int, Bool) {
  let stack : Array[SgoFlowValue] = []
  let mut reads = 0
  for scan = 0; scan < instrs.length(); scan = scan + 1 {
    let instr = instrs[scan]
    if sgo_const_instr(instr) != None ||
      sgo_is_flowscanner_nullary_pure_instr(instr) {
      sgo_flow_push_clean(stack)
      continue
    }
    match instr {
      @lib.GlobalGet(get_idx) => {
        if get_idx == idx {
          reads += 1
          if reads > 1 {
            return (false, reads, false)
          }
          sgo_flow_push_tainted(stack)
        } else {
          sgo_flow_push_clean(stack)
        }
        continue
      }
      @lib.LocalGet(_) => {
        sgo_flow_push_clean(stack)
        continue
      }
      @lib.TableSet(_)
      | @lib.I32Store(_)
      | @lib.I64Store(_)
      | @lib.I32Store8(_)
      | @lib.I32Store16(_) =>
        if sgo_flow_pop_clean_pair(stack) {
          continue
        } else {
          return (false, reads, false)
        }
      @lib.GlobalSet(_) | @lib.LocalSet(_) =>
        match sgo_flow_pop(stack) {
          Some(value) if !value.tainted => continue
          _ => return (false, reads, false)
        }
      @lib.LocalTee(_) =>
        match sgo_flow_pop(stack) {
          Some(value) if !value.tainted => {
            sgo_flow_push_clean(stack)
            continue
          }
          _ => return (false, reads, false)
        }
      _ if sgo_is_flowscanner_trapping_read_instr(instr) =>
        match sgo_flow_pop(stack) {
          Some(value) if !value.tainted => {
            sgo_flow_push_clean(stack)
            continue
          }
          _ => return (false, reads, false)
        }
      @lib.Drop =>
        match sgo_flow_pop(stack) {
          Some(value) if !value.tainted => continue
          _ => return (false, reads, false)
        }
      @lib.Block(_, @lib.Expr(body)) => {
        let (block_ok, block_reads, block_tainted) = sgo_flow_arm_result_taint_and_reads(
          body, idx,
        )
        reads = reads + block_reads
        if !block_ok || reads > 1 {
          return (false, reads, false)
        }
        stack.push(sgo_flow_plain(block_tainted))
        continue
      }
      @lib.If(@lib.ValTypeBlockType(_), then_body, Some(else_body)) => {
        match sgo_flow_pop(stack) {
          Some(value) if !value.tainted => ()
          _ => return (false, reads, false)
        }
        let (then_ok, then_reads, then_tainted) = sgo_flow_arm_result_taint_and_reads(
          then_body, idx,
        )
        let (else_ok, else_reads, else_tainted) = sgo_flow_arm_result_taint_and_reads(
          else_body, idx,
        )
        reads = reads + then_reads + else_reads
        if !then_ok || !else_ok || reads > 1 {
          return (false, reads, false)
        }
        stack.push(sgo_flow_plain(then_tainted || else_tainted))
        continue
      }
      @lib.Call(_) | @lib.CallIndirect(_, _) | @lib.CallRef(_) => {
        if sgo_flow_stack_has_taint(stack) {
          return (false, reads, false)
        }
        sgo_flow_clear_stack(stack)
        if scan + 1 == instrs.length() {
          sgo_flow_push_clean(stack)
        } else {
          match instrs[scan + 1] {
            @lib.GlobalGet(_) => ()
            _ => sgo_flow_push_clean(stack)
          }
        }
        continue
      }
      @lib.Select(_) | @lib.V128Bitselect => {
        if !sgo_flow_apply_select(stack) {
          return (false, reads, false)
        }
        continue
      }
      _ => {
        if sgo_is_flowscanner_unary_pure_instr(instr) {
          if !sgo_flow_apply_unary(stack, instr) {
            return (false, reads, false)
          }
          continue
        }
        if sgo_is_flowscanner_binary_pure_instr(instr) {
          if !sgo_flow_apply_binary(stack) {
            return (false, reads, false)
          }
          continue
        }
        return (false, reads, false)
      }
    }
  }
  match stack {
    [value] => (true, reads, value.tainted)
    _ => (false, reads, false)
  }
}

///|
fn sgo_nested_if_arm_flow_outer_if_index(
  instrs : Array[@lib.Instruction],
  pos : Int,
  prefix_stack : Array[SgoFlowValue],
) -> Int? {
  if pos + 1 >= instrs.length() || prefix_stack.length() == 0 {
    return None
  }
  let stack : Array[SgoFlowValue] = []
  for i = 0; i + 1 < prefix_stack.length(); i = i + 1 {
    stack.push(prefix_stack[i])
  }
  sgo_flow_push_tainted(stack)
  for scan = pos + 1; scan < instrs.length(); scan = scan + 1 {
    let instr = instrs[scan]
    if sgo_const_instr(instr) != None ||
      sgo_is_flowscanner_nullary_pure_instr(instr) {
      sgo_flow_push_clean(stack)
      continue
    }
    match instr {
      @lib.If(_, _, _) =>
        return if sgo_flow_stack_single_taint(stack) {
          Some(scan)
        } else {
          None
        }
      @lib.LocalGet(_) => {
        sgo_flow_push_clean(stack)
        continue
      }
      @lib.TableSet(_)
      | @lib.I32Store(_)
      | @lib.I64Store(_)
      | @lib.I32Store8(_)
      | @lib.I32Store16(_) =>
        if sgo_flow_pop_clean_pair(stack) {
          continue
        } else {
          return None
        }
      @lib.GlobalSet(_) | @lib.LocalSet(_) =>
        match sgo_flow_pop(stack) {
          Some(value) if !value.tainted => continue
          _ => return None
        }
      @lib.LocalTee(_) =>
        match sgo_flow_pop(stack) {
          Some(value) if !value.tainted => {
            sgo_flow_push_clean(stack)
            continue
          }
          _ => return None
        }
      _ if sgo_is_flowscanner_trapping_read_instr(instr) =>
        match sgo_flow_pop(stack) {
          Some(value) if !value.tainted => {
            sgo_flow_push_clean(stack)
            continue
          }
          _ => return None
        }
      @lib.Drop =>
        match sgo_flow_pop(stack) {
          Some(value) if !value.tainted => continue
          _ => return None
        }
      @lib.Call(_) | @lib.CallIndirect(_, _) | @lib.CallRef(_) => {
        if sgo_flow_stack_has_taint(stack) {
          return None
        }
        sgo_flow_clear_stack(stack)
        sgo_flow_push_clean(stack)
        continue
      }
      @lib.Select(_) | @lib.V128Bitselect => {
        if !sgo_flow_apply_select(stack) {
          return None
        }
        continue
      }
      _ => {
        if sgo_is_flowscanner_unary_pure_instr(instr) {
          if !sgo_flow_apply_unary(stack, instr) {
            return None
          }
          continue
        }
        if sgo_is_flowscanner_binary_pure_instr(instr) {
          if !sgo_flow_apply_binary(stack) {
            return None
          }
          continue
        }
        return None
      }
    }
  }
  None
}

///|
fn sgo_block_wrapped_nested_if_arm_flow_taint_and_reads(
  instrs : Array[@lib.Instruction],
  idx : @lib.GlobalIdx,
) -> (Bool, Int, Bool) {
  let stack : Array[SgoFlowValue] = []
  let mut reads = 0
  for scan = 0; scan < instrs.length(); scan = scan + 1 {
    let instr = instrs[scan]
    if sgo_const_instr(instr) != None ||
      sgo_is_flowscanner_nullary_pure_instr(instr) {
      sgo_flow_push_clean(stack)
      continue
    }
    match instr {
      @lib.GlobalGet(get_idx) => {
        if get_idx == idx {
          return (false, reads, false)
        }
        sgo_flow_push_clean(stack)
        continue
      }
      @lib.LocalGet(_) => {
        sgo_flow_push_clean(stack)
        continue
      }
      @lib.TableSet(_)
      | @lib.I32Store(_)
      | @lib.I64Store(_)
      | @lib.I32Store8(_)
      | @lib.I32Store16(_) =>
        if sgo_flow_pop_clean_pair(stack) {
          continue
        } else {
          return (false, reads, false)
        }
      @lib.GlobalSet(_) | @lib.LocalSet(_) =>
        match sgo_flow_pop(stack) {
          Some(value) if !value.tainted => continue
          _ => return (false, reads, false)
        }
      @lib.LocalTee(_) =>
        match sgo_flow_pop(stack) {
          Some(value) if !value.tainted => {
            sgo_flow_push_clean(stack)
            continue
          }
          _ => return (false, reads, false)
        }
      _ if sgo_is_flowscanner_trapping_read_instr(instr) =>
        match sgo_flow_pop(stack) {
          Some(value) if !value.tainted => {
            sgo_flow_push_clean(stack)
            continue
          }
          _ => return (false, reads, false)
        }
      @lib.Drop =>
        match sgo_flow_pop(stack) {
          Some(value) if !value.tainted => continue
          _ => return (false, reads, false)
        }
      @lib.Block(@lib.ValTypeBlockType(_), @lib.Expr(body)) => {
        let (block_ok, block_reads, block_tainted) = sgo_block_wrapped_nested_if_arm_flow_taint_and_reads(
          body, idx,
        )
        reads = reads + block_reads
        if !block_ok || reads > 1 {
          return (false, reads, false)
        }
        stack.push(sgo_flow_plain(block_tainted))
        continue
      }
      @lib.If(@lib.ValTypeBlockType(_), then_body, Some(else_body)) => {
        match sgo_flow_pop(stack) {
          Some(value) if !value.tainted => ()
          _ => return (false, reads, false)
        }
        let (then_ok, then_reads, then_tainted) = sgo_flow_arm_result_taint_and_reads(
          then_body, idx,
        )
        let (else_ok, else_reads, else_tainted) = sgo_flow_arm_result_taint_and_reads(
          else_body, idx,
        )
        reads = reads + then_reads + else_reads
        if !then_ok || !else_ok || reads > 1 {
          return (false, reads, false)
        }
        stack.push(sgo_flow_plain(then_tainted || else_tainted))
        continue
      }
      @lib.Call(_) | @lib.CallIndirect(_, _) | @lib.CallRef(_) => {
        if sgo_flow_stack_has_taint(stack) {
          return (false, reads, false)
        }
        sgo_flow_clear_stack(stack)
        sgo_flow_push_clean(stack)
        continue
      }
      @lib.Select(_) | @lib.V128Bitselect => {
        if !sgo_flow_apply_select(stack) {
          return (false, reads, false)
        }
        continue
      }
      _ => {
        if sgo_is_flowscanner_unary_pure_instr(instr) {
          if !sgo_flow_apply_unary(stack, instr) {
            return (false, reads, false)
          }
          continue
        }
        if sgo_is_flowscanner_binary_pure_instr(instr) {
          if !sgo_flow_apply_binary(stack) {
            return (false, reads, false)
          }
          continue
        }
        return (false, reads, false)
      }
    }
  }
  match stack {
    [value] => (true, reads, value.tainted)
    _ => (false, reads, false)
  }
}

///|
fn sgo_count_block_wrapped_nested_if_arm_flow_read(
  instr : @lib.Instruction,
  next : @lib.Instruction,
  safe_reads : Array[Int],
) -> Unit {
  match (instr, next) {
    (
      @lib.Block(@lib.ValTypeBlockType(_), @lib.Expr(body)),
      @lib.If(_, outer_then, None),
    ) => {
      let idx = match sgo_single_const_global_set_idx(outer_then) {
        Some(set_idx) => set_idx
        None => return
      }
      let (ok, reads, tainted) = sgo_block_wrapped_nested_if_arm_flow_taint_and_reads(
        body, idx,
      )
      if ok &&
        reads == 1 &&
        tainted &&
        !sgo_block_condition_flow_scanner_read_matches(body, idx) {
        sgo_count_read_only_to_write_safe_read(idx, safe_reads)
      }
    }
    _ => ()
  }
}

///|
fn sgo_count_nested_if_arm_flow_read(
  instrs : Array[@lib.Instruction],
  pos : Int,
  safe_reads : Array[Int],
) -> Unit {
  if pos + 1 >= instrs.length() {
    return
  }
  match instrs[pos] {
    @lib.If(@lib.ValTypeBlockType(_), then_body, Some(else_body)) => {
      let (clean_prefix_ok, clean_prefix_stack) = sgo_flow_scan_clean_prefix_until(
        instrs, pos,
      )
      if !clean_prefix_ok || clean_prefix_stack.length() == 0 {
        return
      }
      let if_index = match
        sgo_nested_if_arm_flow_outer_if_index(instrs, pos, clean_prefix_stack) {
        Some(index) => index
        None => return
      }
      let idx = match instrs[if_index] {
        @lib.If(_, outer_then, None) =>
          match sgo_single_const_global_set_idx(outer_then) {
            Some(set_idx) => set_idx
            None => return
          }
        _ => return
      }
      let (prefix_ok, prefix_reads, prefix_stack) = sgo_flow_scan_prefix_until(
        instrs, pos, idx,
      )
      if !prefix_ok ||
        prefix_reads != 0 ||
        prefix_stack.length() == 0 ||
        sgo_flow_stack_has_taint(prefix_stack) {
        return
      }
      let (then_ok, then_reads, then_tainted) = sgo_flow_arm_result_taint_and_reads(
        then_body, idx,
      )
      let (else_ok, else_reads, else_tainted) = sgo_flow_arm_result_taint_and_reads(
        else_body, idx,
      )
      if then_ok &&
        else_ok &&
        then_reads + else_reads == 1 &&
        (then_tainted || else_tainted) {
        sgo_count_read_only_to_write_safe_read(idx, safe_reads)
      }
    }
    _ => ()
  }
}

///|
fn sgo_read_only_to_write_flow_scanner_read_at(
  instrs : Array[@lib.Instruction],
  pos : Int,
  idx : @lib.GlobalIdx,
) -> Bool {
  let stack : Array[SgoFlowValue] = []
  for scan = 0; scan < instrs.length(); scan = scan + 1 {
    let instr = instrs[scan]
    if scan == pos {
      match instr {
        @lib.GlobalGet(get_idx) if get_idx == idx => {
          sgo_flow_push_tainted(stack)
          continue
        }
        _ => return false
      }
    }
    if sgo_const_instr(instr) != None ||
      sgo_is_flowscanner_nullary_pure_instr(instr) {
      sgo_flow_push_clean(stack)
      continue
    }
    match instr {
      @lib.GlobalGet(get_idx) => {
        if get_idx == idx {
          return false
        }
        sgo_flow_push_clean(stack)
        continue
      }
      @lib.LocalGet(_) => {
        sgo_flow_push_clean(stack)
        continue
      }
      @lib.TableSet(_)
      | @lib.I32Store(_)
      | @lib.I64Store(_)
      | @lib.I32Store8(_)
      | @lib.I32Store16(_) =>
        if sgo_flow_pop_clean_pair(stack) {
          continue
        } else {
          return false
        }
      @lib.GlobalSet(_) | @lib.LocalSet(_) =>
        match sgo_flow_pop(stack) {
          Some(value) if !value.tainted => continue
          _ => return false
        }
      @lib.LocalTee(_) =>
        match sgo_flow_pop(stack) {
          Some(value) if !value.tainted => {
            sgo_flow_push_clean(stack)
            continue
          }
          _ => return false
        }
      _ if sgo_is_flowscanner_trapping_read_instr(instr) =>
        match sgo_flow_pop(stack) {
          Some(value) if !value.tainted => {
            sgo_flow_push_clean(stack)
            continue
          }
          _ => return false
        }
      @lib.Drop =>
        match sgo_flow_pop(stack) {
          Some(value) if !value.tainted => continue
          _ => return false
        }
      @lib.Select(_) | @lib.V128Bitselect => {
        if !sgo_flow_apply_select(stack) {
          return false
        }
        continue
      }
      @lib.If(_, _, _) =>
        match sgo_flow_pop(stack) {
          Some(value) if value.tainted =>
            return sgo_if_is_read_only_to_write_set(instr, idx)
          Some(value) if !value.tainted => return false
          _ => return false
        }
      _ => {
        if sgo_is_flowscanner_unary_pure_instr(instr) {
          if !sgo_flow_apply_unary(stack, instr) {
            return false
          }
          continue
        }
        if sgo_is_flowscanner_binary_pure_instr(instr) {
          if !sgo_flow_apply_binary(stack) {
            return false
          }
          continue
        }
        return false
      }
    }
  }
  false
}

///|
fn sgo_read_only_to_write_pure_select_read_at(
  instrs : Array[@lib.Instruction],
  pos : Int,
  idx : @lib.GlobalIdx,
) -> Bool {
  let global_is_condition = pos >= 2 &&
    pos + 2 < instrs.length() &&
    sgo_const_instr(instrs[pos - 2]) != None &&
    sgo_const_instr(instrs[pos - 1]) != None &&
    instrs[pos + 1] == @lib.Instruction::select() &&
    sgo_if_is_read_only_to_write_set(instrs[pos + 2], idx)
  let global_is_first_value = pos + 4 < instrs.length() &&
    sgo_const_instr(instrs[pos + 1]) != None &&
    sgo_const_instr(instrs[pos + 2]) != None &&
    instrs[pos + 3] == @lib.Instruction::select() &&
    sgo_if_is_read_only_to_write_set(instrs[pos + 4], idx)
  let global_is_second_value = pos >= 1 &&
    pos + 3 < instrs.length() &&
    sgo_const_instr(instrs[pos - 1]) != None &&
    sgo_const_instr(instrs[pos + 1]) != None &&
    instrs[pos + 2] == @lib.Instruction::select() &&
    sgo_if_is_read_only_to_write_set(instrs[pos + 3], idx)
  global_is_condition || global_is_first_value || global_is_second_value
}

///|
fn sgo_read_only_to_write_select_condition_read_at(
  instrs : Array[@lib.Instruction],
  pos : Int,
  idx : @lib.GlobalIdx,
) -> Bool {
  if pos < 4 || pos + 5 >= instrs.length() {
    return false
  }
  if sgo_const_instr(instrs[pos - 4]) == None {
    return false
  }
  match instrs[pos - 3] {
    @lib.LocalTee(_) => ()
    _ => return false
  }
  if sgo_const_instr(instrs[pos - 2]) == None {
    return false
  }
  match instrs[pos - 1] {
    @lib.I32Load(_) => ()
    _ => return false
  }
  sgo_const_instr(instrs[pos + 1]) != None &&
  instrs[pos + 2] == @lib.Instruction::i32_add() &&
  instrs[pos + 3] == @lib.Instruction::select() &&
  instrs[pos + 4] == @lib.Instruction::i32_eqz() &&
  sgo_if_is_read_only_to_write_set(instrs[pos + 5], idx)
}

///|
fn sgo_read_only_to_write_select_value_read_at(
  instrs : Array[@lib.Instruction],
  pos : Int,
  idx : @lib.GlobalIdx,
) -> Bool {
  if pos + 9 >= instrs.length() {
    return false
  }
  if sgo_const_instr(instrs[pos + 1]) == None ||
    instrs[pos + 2] != @lib.Instruction::i32_add() ||
    sgo_const_instr(instrs[pos + 3]) == None {
    return false
  }
  match instrs[pos + 4] {
    @lib.LocalTee(_) => ()
    _ => return false
  }
  if sgo_const_instr(instrs[pos + 5]) == None {
    return false
  }
  match instrs[pos + 6] {
    @lib.I32Load(_) => ()
    _ => return false
  }
  instrs[pos + 7] == @lib.Instruction::select() &&
  instrs[pos + 8] == @lib.Instruction::i32_eqz() &&
  sgo_if_is_read_only_to_write_set(instrs[pos + 9], idx)
}

///|
fn sgo_read_only_to_write_select_second_value_read_at(
  instrs : Array[@lib.Instruction],
  pos : Int,
  idx : @lib.GlobalIdx,
) -> Bool {
  if pos < 2 || pos + 7 >= instrs.length() {
    return false
  }
  if sgo_const_instr(instrs[pos - 2]) == None {
    return false
  }
  match instrs[pos - 1] {
    @lib.LocalTee(_) => ()
    _ => return false
  }
  if sgo_const_instr(instrs[pos + 1]) == None ||
    instrs[pos + 2] != @lib.Instruction::i32_add() ||
    sgo_const_instr(instrs[pos + 3]) == None {
    return false
  }
  match instrs[pos + 4] {
    @lib.I32Load(_) => ()
    _ => return false
  }
  instrs[pos + 5] == @lib.Instruction::select() &&
  instrs[pos + 6] == @lib.Instruction::i32_eqz() &&
  sgo_if_is_read_only_to_write_set(instrs[pos + 7], idx)
}

///|
fn sgo_read_only_to_write_select_side_effect_read_at(
  instrs : Array[@lib.Instruction],
  pos : Int,
  idx : @lib.GlobalIdx,
) -> Bool {
  sgo_read_only_to_write_select_condition_read_at(instrs, pos, idx) ||
  sgo_read_only_to_write_select_value_read_at(instrs, pos, idx) ||
  sgo_read_only_to_write_select_second_value_read_at(instrs, pos, idx)
}

///|
fn sgo_read_only_to_write_read_at(
  instrs : Array[@lib.Instruction],
  pos : Int,
  idx : @lib.GlobalIdx,
) -> Bool {
  sgo_read_only_to_write_flow_scanner_read_at(instrs, pos, idx) ||
  sgo_is_exact_if_return_set(instrs, pos, idx) ||
  sgo_is_pure_condition_if_return_set(instrs, pos, idx) ||
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
  sgo_read_only_to_write_pure_select_read_at(instrs, pos, idx) ||
  sgo_read_only_to_write_select_side_effect_read_at(instrs, pos, idx)
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
fn sgo_is_read_only_to_write_pure_condition_instr(
  instr : @lib.Instruction,
) -> Bool {
  sgo_const_instr(instr) != None ||
  instr is @lib.RefTest(_, _) ||
  sgo_is_i32_pure_condition_instr(instr) ||
  sgo_is_i64_pure_condition_instr(instr) ||
  sgo_is_float_compare_condition_instr(instr)
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
fn sgo_block_condition_flow_scanner_read_matches(
  instrs : Array[@lib.Instruction],
  idx : @lib.GlobalIdx,
) -> Bool {
  let flat : Array[@lib.Instruction] = []
  if !sgo_collect_read_only_to_write_condition_body(instrs, flat) {
    return false
  }
  let (ok, reads, stack) = sgo_flow_scan_prefix_until(flat, flat.length(), idx)
  ok && reads == 1 && sgo_flow_stack_single_taint(stack)
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
    | @lib.I64Eqz
    | @lib.RefTest(_, _) => if depth >= 1 { Some(depth) } else { None }
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
          sgo_block_condition_pure_read_matches(body, idx) ||
          sgo_block_condition_flow_scanner_read_matches(body, idx) =>
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
fn sgo_prefix_has_only_nested_read_only_to_write_patterns(
  instrs : Array[@lib.Instruction],
  end_ : Int,
  idx : @lib.GlobalIdx,
) -> Bool {
  let mut scan = 0
  while scan < end_ {
    match instrs[scan] {
      @lib.Nop => {
        scan = scan + 1
        continue
      }
      _ => ()
    }
    if scan + 1 < end_ &&
      sgo_const_instr(instrs[scan]) != None &&
      instrs[scan + 1] == @lib.Instruction::drop() {
      scan = scan + 2
      continue
    }
    match instrs[scan] {
      @lib.GlobalGet(get_idx) if get_idx == idx => {
        if scan + 1 < end_ &&
          sgo_if_is_read_only_to_write_set(instrs[scan + 1], idx) {
          scan = scan + 2
          continue
        }
        if scan + 2 < end_ &&
          instrs[scan + 1] == @lib.Instruction::i32_eqz() &&
          sgo_if_is_read_only_to_write_set(instrs[scan + 2], idx) {
          scan = scan + 3
          continue
        }
        return false
      }
      _ => return false
    }
  }
  true
}

///|
fn sgo_block_condition_nested_final_direct_read_matches(
  instrs : Array[@lib.Instruction],
  idx : @lib.GlobalIdx,
) -> Bool {
  let mut end_ = instrs.length()
  while end_ > 0 {
    match instrs[end_ - 1] {
      @lib.Nop => end_ = end_ - 1
      _ => break
    }
  }
  if end_ <= 0 {
    return false
  }
  match instrs[end_ - 1] {
    @lib.GlobalGet(get_idx) if get_idx == idx =>
      sgo_prefix_has_only_nested_read_only_to_write_patterns(
        instrs,
        end_ - 1,
        idx,
      )
    _ => false
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
    sgo_block_condition_flow_scanner_read_matches(body, idx) ||
    sgo_block_condition_nested_final_direct_read_matches(body, idx) {
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
  code_sec : @lib.CodeSec?,
  infos : Array[SgoGlobalInfo],
  consts : Array[@lib.Instruction?],
  aliases : Array[@lib.GlobalIdx?],
  remove_sets : Array[Bool],
) -> (@lib.CodeSec?, Array[Bool], Bool) {
  match code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let out : Array[@lib.Func] = []
      let touched = Array::make(funcs.length(), false)
      let mut changed = false
      for idx = 0; idx < funcs.length(); idx = idx + 1 {
        let @lib.Func(locals, body) = funcs[idx]
        if !sgo_expr_may_reference_global(body) {
          out.push(funcs[idx])
          continue
        }
        let (rewritten, func_changed) = sgo_rewrite_expr(
          body, consts, aliases, remove_sets, true,
        )
        let (runtime_rewritten, runtime_changed) = sgo_rewrite_runtime_trace_expr(
          rewritten, infos,
        )
        if func_changed || runtime_changed {
          touched[idx] = true
          changed = true
          out.push(@lib.Func::new(locals, runtime_rewritten))
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
  let collect_start_us = perf_start_timer_opt(
    perf, "detail:sgo:collect-global-infos",
  )
  let (infos, imported_globals) = sgo_collect_global_infos(mod_)
  perf_stop_timer_opt(perf, "detail:sgo:collect-global-infos", collect_start_us)
  let flags_start_us = perf_start_timer_opt(perf, "detail:sgo:plan-flags")
  let same_init_writes = sgo_same_init_write_flags(mod_.code_sec, infos)
  let read_only_to_write = sgo_read_only_to_write_flags(mod_.code_sec, infos)
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
