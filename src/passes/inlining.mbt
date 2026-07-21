///|
pub fn inlining_summary() -> String {
  "Inline profitable direct callsites and remove private helpers that become dead."
}

///|
pub fn inlining_optimizing_summary() -> String {
  "Inline profitable direct callsites and run the optimizing sibling's nested cleanup approximation on touched functions."
}

///|
pub fn inline_main_summary() -> String {
  "Inline the single direct call from defined `main` to defined `__original_main`."
}

///|
priv enum InlToolchainInlineHint {
  DefaultInline
  NeverInline
  AlwaysInline
}

///|
priv struct InlFunctionInfo {
  params : Array[@lib.ValType]
  results : Array[@lib.ValType]
  type_idx : @lib.TypeIdx?
  size : Int
  max_combined_binary_size : Int
  inlineable : Bool
}

///|
priv struct InlTailCallsiteHoist {
  post_body : Array[@lib.Instruction]
}

///|
priv struct InlRewriteState {
  mut func : @lib.Func
  mut changed : Bool
  size : Int
  tail_callsite_hoists : Array[InlTailCallsiteHoist]
}

///|
priv struct InlPassResult {
  mod_out : @lib.Module
  touched : Array[Bool]
  inlined_from : Array[Bool]
  changed : Bool
}

///|
priv struct InlRemovalResult {
  mod_out : @lib.Module
  touched : Array[Bool]
  original_abs : Array[Int]
}

///|
priv struct InlOriginalGraphInfo {
  cycle_remove : Array[Bool]
  public_scc_representative : Array[Int]
  predicted_unreachable_counts : @hashmap.HashMap[String, Int]
  final_trim_counts : @hashmap.HashMap[String, Int]
  retain_inlined_helper_counts : @hashmap.HashMap[String, Int]
  skip_trailing_exact_move : Bool
  force_predicted_pad_on_retain_return : Bool
}

///|
priv struct InlDeadSuffixTargets {
  has_any : Bool
  total_count : Int
  targets : Array[Int]
  counts : Array[Int]
}

///|
priv struct InlDeadSuffixPreserveFacts {
  imports : Int
  defined : Int
  used : Array[Bool]
  signatures : Array[String]
  dead_suffix_targets : Array[InlDeadSuffixTargets]
}

///|
fn inl_imported_func_count(mod_ : @lib.Module) -> Int {
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
fn inl_defined_func_count(mod_ : @lib.Module) -> Int {
  match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => type_idxs.length()
    None => 0
  }
}

///|
fn inl_func_idx_slot(idx : @lib.FuncIdx) -> Int {
  let @lib.FuncIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn inl_local_idx_slot(idx : @lib.LocalIdx) -> Int {
  let @lib.LocalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn inl_label_idx_slot(idx : @lib.LabelIdx) -> Int {
  let @lib.LabelIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn inl_collect_func_type_indices(mod_ : @lib.Module) -> Array[@lib.TypeIdx] {
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
fn inl_type_sec_func_type(
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
fn inl_resolve_func_type(
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
  func_abs : Int,
) -> @lib.FuncType? {
  if func_abs < 0 || func_abs >= func_type_indices.length() {
    return None
  }
  match mod_.type_sec {
    Some(type_sec) =>
      inl_type_sec_func_type(type_sec, func_type_indices[func_abs])
    None => None
  }
}

///|
fn inl_find_zero_param_result_type(
  mod_ : @lib.Module,
  results : Array[@lib.ValType],
) -> @lib.TypeIdx? {
  match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) => {
      let mut idx = 0
      for rec_type in rec_types {
        match rec_type {
          @lib.SingleRecType(subtype) => {
            match subtype.get_comptype() {
              @lib.FuncCompType(params, type_results) =>
                if params.length() == 0 && type_results == results {
                  return Some(@lib.TypeIdx::new(idx.reinterpret_as_uint()))
                }
              _ => ()
            }
            idx += 1
          }
          @lib.GroupRecType(group) =>
            for subtype in group {
              match subtype.get_comptype() {
                @lib.FuncCompType(params, type_results) =>
                  if params.length() == 0 && type_results == results {
                    return Some(@lib.TypeIdx::new(idx.reinterpret_as_uint()))
                  }
                _ => ()
              }
              idx += 1
            }
        }
      }
      None
    }
    None => None
  }
}

///|
fn inl_append_zero_param_result_type(
  mod_ : @lib.Module,
  results : Array[@lib.ValType],
) -> @lib.Module {
  let rec_types = match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) => rec_types.copy()
    None => []
  }
  rec_types.push(
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], results))),
  )
  mod_.with_type_sec(@lib.TypeSec::new(rec_types))
}

///|
fn inl_prepare_multivalue_block_types(
  mod_ : @lib.Module,
  optimize_level : Int,
  shrink_level : Int,
) -> @lib.Module {
  let func_type_indices = inl_collect_func_type_indices(mod_)
  let refs = Array::make(func_type_indices.length(), 0)
  let used = Array::make(func_type_indices.length(), false)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => []
  }
  for func in funcs {
    let @lib.Func(_, @lib.Expr(body)) = func
    inl_scan_refs(body, refs, used)
  }
  let (no_full_inline, _) = no_inline_policy_flags(mod_)
  let imports = inl_imported_func_count(mod_)
  let speed_focused = optimize_level >= 3 && shrink_level == 0
  let mut current = mod_
  let mut abs = imports
  while abs < func_type_indices.length() {
    let def_idx = abs - imports
    if def_idx >= 0 && def_idx < funcs.length() && refs[abs] > 0 {
      let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
      let (calls, loops, tries, _) = inl_scan_shape_instrs(body)
      let size = inl_count_instrs(body)
      let no_full_policy = abs >= 0 &&
        abs < no_full_inline.length() &&
        no_full_inline[abs]
      let may_not_shrink = speed_focused && !calls && !loops && size <= 20
      match inl_resolve_func_type(current, func_type_indices, abs) {
        Some(@lib.FuncType(params, results)) =>
          if !no_full_policy &&
            !tries &&
            params.length() > 0 &&
            results.length() > 1 &&
            (size <= 2 || refs[abs] == 1 || may_not_shrink) &&
            inl_find_zero_param_result_type(current, results) is None {
            current = inl_append_zero_param_result_type(current, results)
          }
        None => ()
      }
    }
    abs += 1
  }
  current
}

///|
fn inl_result_block_type(
  results : Array[@lib.ValType],
  type_idx : @lib.TypeIdx?,
) -> @lib.BlockType? {
  match results.length() {
    0 => Some(@lib.BlockType::void_())
    1 => Some(@lib.BlockType::val_type(results[0]))
    _ =>
      match type_idx {
        Some(type_idx) => Some(@lib.BlockType::type_idx(type_idx))
        None => None
      }
  }
}

///|
fn inl_count_instr(instr : @lib.Instruction) -> Int {
  match instr {
    @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
      1 + inl_count_instrs(body)
    @lib.If(_, then_body, Some(else_body)) =>
      1 + inl_count_instrs(then_body) + inl_count_instrs(else_body)
    @lib.If(_, then_body, None) => 1 + inl_count_instrs(then_body)
    @lib.TryTable(_, _, @lib.Expr(body)) => 1 + inl_count_instrs(body)
    _ => 1
  }
}

///|
fn inl_count_instrs(instrs : Array[@lib.Instruction]) -> Int {
  let mut count = 0
  for instr in instrs {
    count += inl_count_instr(instr)
  }
  count
}

///|
fn inl_combined_binary_size_within_limit(
  caller_size : Int,
  callee_size : Int,
  max_combined_binary_size? : Int = 400 * 1024,
) -> Bool {
  // Binaryen estimates 2.5 encoded bytes per expression and uses a strict
  // comparison against the configured combined-size ceiling.
  let combined_exprs = caller_size + callee_size
  combined_exprs * 5 < max_combined_binary_size * 2
}

///|
fn inl_scan_shape_instr(instr : @lib.Instruction) -> (Bool, Bool, Bool, Bool) {
  match instr {
    @lib.Call(_) => (true, false, false, false)
    @lib.CallIndirect(_, _) | @lib.CallRef(_) => (false, false, false, false)
    @lib.ReturnCall(_) => (true, false, false, true)
    @lib.ReturnCallIndirect(_, _) | @lib.ReturnCallRef(_) =>
      (false, false, false, true)
    @lib.Loop(_, @lib.Expr(body)) => {
      let (calls, loops, tries, tails) = inl_scan_shape_instrs(body)
      (calls, true || loops, tries, tails)
    }
    @lib.Block(_, @lib.Expr(body)) => inl_scan_shape_instrs(body)
    @lib.If(_, then_body, Some(else_body)) => {
      let (a, b, c, d) = inl_scan_shape_instrs(then_body)
      let (e, f, g, h) = inl_scan_shape_instrs(else_body)
      (a || e, b || f, c || g, d || h)
    }
    @lib.If(_, then_body, None) => inl_scan_shape_instrs(then_body)
    @lib.TryTable(_, _, @lib.Expr(body)) => {
      let (calls, loops, nested_tail_in_try, tails) = inl_scan_shape_instrs(
        body,
      )
      (calls, loops, nested_tail_in_try || tails, tails)
    }
    _ => (false, false, false, false)
  }
}

///|
fn inl_scan_shape_instrs(
  instrs : Array[@lib.Instruction],
) -> (Bool, Bool, Bool, Bool) {
  let mut calls = false
  let mut loops = false
  let mut tries = false
  let mut tails = false
  for instr in instrs {
    let (a, b, c, d) = inl_scan_shape_instr(instr)
    calls = calls || a
    loops = loops || b
    tries = tries || c
    tails = tails || d
  }
  (calls, loops, tries, tails)
}

///|
fn inl_is_binary_trivial_op(instr : @lib.Instruction) -> Bool {
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
    | @lib.I32GeU
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
    | @lib.F32Eq
    | @lib.F32Ne
    | @lib.F32Lt
    | @lib.F32Gt
    | @lib.F32Le
    | @lib.F32Ge
    | @lib.F32Add
    | @lib.F32Sub
    | @lib.F32Mul
    | @lib.F32Div
    | @lib.F32Min
    | @lib.F32Max
    | @lib.F32Copysign
    | @lib.F64Eq
    | @lib.F64Ne
    | @lib.F64Lt
    | @lib.F64Gt
    | @lib.F64Le
    | @lib.F64Ge
    | @lib.F64Add
    | @lib.F64Sub
    | @lib.F64Mul
    | @lib.F64Div
    | @lib.F64Min
    | @lib.F64Max
    | @lib.F64Copysign
    | @lib.RefEq
    | @lib.V128And
    | @lib.V128Andnot
    | @lib.V128Or
    | @lib.V128Xor
    | @lib.I8x16Shuffle(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | @lib.I8x16Swizzle
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
    | @lib.I8x16NarrowI16x8S
    | @lib.I8x16NarrowI16x8U
    | @lib.I8x16Shl
    | @lib.I8x16ShrS
    | @lib.I8x16ShrU
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
    | @lib.I16x8Eq
    | @lib.I16x8Ne
    | @lib.I16x8LtS
    | @lib.I16x8LtU
    | @lib.I16x8GtS
    | @lib.I16x8GtU
    | @lib.I16x8LeS
    | @lib.I16x8LeU
    | @lib.I16x8GeS
    | @lib.I16x8GeU
    | @lib.I16x8Q15mulrSatS
    | @lib.I16x8NarrowI32x4S
    | @lib.I16x8NarrowI32x4U
    | @lib.I16x8Shl
    | @lib.I16x8ShrS
    | @lib.I16x8ShrU
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
    | @lib.I16x8ExtmulLowI8x16S
    | @lib.I16x8ExtmulHighI8x16S
    | @lib.I16x8ExtmulLowI8x16U
    | @lib.I16x8ExtmulHighI8x16U
    | @lib.I32x4Eq
    | @lib.I32x4Ne
    | @lib.I32x4LtS
    | @lib.I32x4LtU
    | @lib.I32x4GtS
    | @lib.I32x4GtU
    | @lib.I32x4LeS
    | @lib.I32x4LeU
    | @lib.I32x4GeS
    | @lib.I32x4GeU
    | @lib.I32x4Shl
    | @lib.I32x4ShrS
    | @lib.I32x4ShrU
    | @lib.I32x4Add
    | @lib.I32x4Sub
    | @lib.I32x4Mul
    | @lib.I32x4MinS
    | @lib.I32x4MinU
    | @lib.I32x4MaxS
    | @lib.I32x4MaxU
    | @lib.I32x4DotI16x8S
    | @lib.I32x4ExtmulLowI16x8S
    | @lib.I32x4ExtmulHighI16x8S
    | @lib.I32x4ExtmulLowI16x8U
    | @lib.I32x4ExtmulHighI16x8U
    | @lib.I64x2Eq
    | @lib.I64x2Ne
    | @lib.I64x2LtS
    | @lib.I64x2GtS
    | @lib.I64x2LeS
    | @lib.I64x2GeS
    | @lib.I64x2Shl
    | @lib.I64x2ShrS
    | @lib.I64x2ShrU
    | @lib.I64x2Add
    | @lib.I64x2Sub
    | @lib.I64x2Mul
    | @lib.I64x2ExtmulLowI32x4S
    | @lib.I64x2ExtmulHighI32x4S
    | @lib.I64x2ExtmulLowI32x4U
    | @lib.I64x2ExtmulHighI32x4U
    | @lib.F32x4Eq
    | @lib.F32x4Ne
    | @lib.F32x4Lt
    | @lib.F32x4Gt
    | @lib.F32x4Le
    | @lib.F32x4Ge
    | @lib.F32x4Add
    | @lib.F32x4Sub
    | @lib.F32x4Mul
    | @lib.F32x4Div
    | @lib.F32x4Min
    | @lib.F32x4Max
    | @lib.F32x4Pmin
    | @lib.F32x4Pmax
    | @lib.F64x2Eq
    | @lib.F64x2Ne
    | @lib.F64x2Lt
    | @lib.F64x2Gt
    | @lib.F64x2Le
    | @lib.F64x2Ge
    | @lib.F64x2Add
    | @lib.F64x2Sub
    | @lib.F64x2Mul
    | @lib.F64x2Div
    | @lib.F64x2Min
    | @lib.F64x2Max
    | @lib.F64x2Pmin
    | @lib.F64x2Pmax
    | @lib.I8x16ReplaceLane(_)
    | @lib.I16x8ReplaceLane(_)
    | @lib.I32x4ReplaceLane(_)
    | @lib.I64x2ReplaceLane(_)
    | @lib.F32x4ReplaceLane(_)
    | @lib.F64x2ReplaceLane(_)
    | @lib.V128Load8Lane(_, _)
    | @lib.V128Load16Lane(_, _)
    | @lib.V128Load32Lane(_, _)
    | @lib.V128Load64Lane(_, _)
    | @lib.I8x16RelaxedSwizzle
    | @lib.F32x4RelaxedMin
    | @lib.F32x4RelaxedMax
    | @lib.F64x2RelaxedMin
    | @lib.F64x2RelaxedMax
    | @lib.I16x8RelaxedQ15mulrS
    | @lib.I32Store(_)
    | @lib.I64Store(_)
    | @lib.F32Store(_)
    | @lib.F64Store(_)
    | @lib.I32Store8(_)
    | @lib.I32Store16(_)
    | @lib.I64Store8(_)
    | @lib.I64Store16(_)
    | @lib.I64Store32(_)
    | @lib.V128Store(_)
    | @lib.V128Store8Lane(_, _)
    | @lib.V128Store16Lane(_, _)
    | @lib.V128Store32Lane(_, _)
    | @lib.V128Store64Lane(_, _)
    | @lib.TableSet(_)
    | @lib.TableGrow(_) => true
    _ => false
  }
}

///|
fn inl_body_is_ordered_param_passthrough_prefix(
  body : Array[@lib.Instruction],
  param_count : Int,
) -> Bool {
  if body.length() < param_count {
    return false
  }
  let mut idx = 0
  while idx < param_count {
    match body[idx] {
      @lib.LocalGet(local_idx) =>
        if inl_local_idx_slot(local_idx) != idx {
          return false
        }
      _ => return false
    }
    idx += 1
  }
  true
}

///|
fn inl_body_is_shrinking_trivial(
  body : Array[@lib.Instruction],
  param_count : Int,
  mod_? : @lib.Module = @lib.Module::new(),
  func_type_indices? : Array[@lib.TypeIdx] = [],
) -> Bool {
  if body.length() > 0 {
    let operand_count = body.length() - 1
    if operand_count <= param_count &&
      inl_body_is_ordered_param_passthrough_prefix(body, operand_count) {
      // Binaryen accepts an ordered prefix of the parameters: trailing unused
      // parameters do not appear among the instruction's direct children.
      // Stack-effect evidence distinguishes true children from unrelated values
      // left on the function result stack by a zero-input trailing instruction.
      match body[operand_count] {
        @lib.Block(_, _)
        | @lib.Loop(_, _)
        | @lib.If(_, _, _)
        | @lib.TryTable(_, _, _) => ()
        final_instr =>
          match dae_instr_stack_effect(final_instr, mod_, func_type_indices) {
            Some((inputs, _)) if inputs == operand_count => return true
            _ => ()
          }
      }
    }
  }
  if param_count == 2 && body.length() == 3 {
    match (body[0], body[1]) {
      (@lib.LocalGet(first), @lib.LocalGet(second)) => {
        let gc_trivial = match body[2] {
          @lib.StructSet(_, _)
          | @lib.StructNew(_)
          | @lib.StructNewDesc(_)
          | @lib.ArrayNew(_)
          | @lib.ArrayNewFixed(_, _)
          | @lib.ArrayNewData(_, _)
          | @lib.ArrayNewElem(_, _)
          | @lib.ArrayGet(_)
          | @lib.ArrayGetS(_)
          | @lib.ArrayGetU(_) => true
          _ => false
        }
        let final_trivial = inl_is_binary_trivial_op(body[2]) || gc_trivial
        return inl_local_idx_slot(first) == 0 &&
          inl_local_idx_slot(second) == 1 &&
          final_trivial
      }
      _ => return false
    }
  }
  if param_count == 3 && body.length() == 4 {
    match (body[0], body[1], body[2]) {
      (@lib.LocalGet(first), @lib.LocalGet(second), @lib.LocalGet(third)) => {
        let final_trivial = match body[3] {
          @lib.Select(_)
          | @lib.V128Bitselect
          | @lib.F32x4RelaxedMadd
          | @lib.F32x4RelaxedNmadd
          | @lib.F64x2RelaxedMadd
          | @lib.F64x2RelaxedNmadd
          | @lib.MemoryFill(_)
          | @lib.MemoryCopy(_, _)
          | @lib.MemoryInit(_, _)
          | @lib.TableFill(_)
          | @lib.TableCopy(_, _)
          | @lib.TableInit(_, _)
          | @lib.ArraySet(_) => true
          _ => false
        }
        return inl_local_idx_slot(first) == 0 &&
          inl_local_idx_slot(second) == 1 &&
          inl_local_idx_slot(third) == 2 &&
          final_trivial
      }
      _ => return false
    }
  }
  if param_count == 4 && body.length() == 5 {
    match (body[0], body[1], body[2], body[3]) {
      (
        @lib.LocalGet(first),
        @lib.LocalGet(second),
        @lib.LocalGet(third),
        @lib.LocalGet(fourth),
      ) => {
        let final_trivial = match body[4] {
          @lib.ArrayFill(_)
          | @lib.ArrayInitData(_, _)
          | @lib.ArrayInitElem(_, _) => true
          _ => false
        }
        return inl_local_idx_slot(first) == 0 &&
          inl_local_idx_slot(second) == 1 &&
          inl_local_idx_slot(third) == 2 &&
          inl_local_idx_slot(fourth) == 3 &&
          final_trivial
      }
      _ => return false
    }
  }
  if param_count == 5 && body.length() == 6 {
    match (body[0], body[1], body[2], body[3], body[4]) {
      (
        @lib.LocalGet(first),
        @lib.LocalGet(second),
        @lib.LocalGet(third),
        @lib.LocalGet(fourth),
        @lib.LocalGet(fifth),
      ) => {
        let final_trivial = match body[5] {
          @lib.ArrayCopy(_, _) => true
          _ => false
        }
        return inl_local_idx_slot(first) == 0 &&
          inl_local_idx_slot(second) == 1 &&
          inl_local_idx_slot(third) == 2 &&
          inl_local_idx_slot(fourth) == 3 &&
          inl_local_idx_slot(fifth) == 4 &&
          final_trivial
      }
      _ => return false
    }
  }
  false
}

///|
fn inl_hot_trivial_instruction_modes(
  mod_ : @lib.Module,
  func_abs : Int,
  module_ctx : @ir.HotModuleContext,
  measured_size : Int,
) -> (Bool, Bool) {
  let hot = match
    @ir.hot_lift_func_with_context_result(
      mod_,
      @lib.FuncIdx::new(func_abs.reinterpret_as_uint()),
      module_ctx,
    ) {
    Ok(func) => func
    Err(_) => return (false, false)
  }
  let root_region = @ir.HotRegionRef::root()
  if @ir.hot_region_root_count(hot, root_region) != 1 {
    return (false, false)
  }
  let root_id = @ir.hot_region_get(hot, root_region, 0)
  let root = @ir.hot_node_get(hot, root_id)
  match root.op {
    @ir.HotOp::Block
    | @ir.HotOp::Loop
    | @ir.HotOp::If
    | @ir.HotOp::Try
    | @ir.HotOp::TryTable => return (false, false)
    _ => ()
  }
  let child_count = @ir.hot_child_count(hot, root_id)
  let mut shrinks = true
  let mut slot = 0
  while slot < child_count {
    let child_id = @ir.hot_child_get(hot, root_id, slot)
    let child = @ir.hot_node_get(hot, child_id)
    match child.op {
      @ir.HotOp::LocalGet if child.imm0 == slot => ()
      _ => {
        shrinks = false
        break
      }
    }
    slot += 1
  }
  let may_not_shrink = measured_size == child_count + 1
  (shrinks, may_not_shrink)
}

///|
fn inl_mark_global_uses(mod_ : @lib.Module, used : Array[Bool]) -> Unit {
  match mod_.export_sec {
    Some(@lib.ExportSec(exports)) =>
      for export_ in exports {
        match export_ {
          @lib.Export(_, @lib.FuncExternIdx(func_idx)) => {
            let slot = inl_func_idx_slot(func_idx)
            if slot >= 0 && slot < used.length() {
              used[slot] = true
            }
          }
          _ => ()
        }
      }
    None => ()
  }
  match mod_.start_sec {
    Some(@lib.StartSec(func_idx)) => {
      let slot = inl_func_idx_slot(func_idx)
      if slot >= 0 && slot < used.length() {
        used[slot] = true
      }
    }
    None => ()
  }
  match mod_.table_sec {
    Some(@lib.TableSec(tables)) =>
      for table in tables {
        let @lib.Table(_, init) = table
        match init {
          Some(@lib.Expr(instrs)) =>
            inl_scan_refs(instrs, Array::make(used.length(), 0), used)
          None => ()
        }
      }
    None => ()
  }
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) =>
      for global in globals {
        let @lib.Global(_, @lib.Expr(instrs)) = global
        inl_scan_refs(instrs, Array::make(used.length(), 0), used)
      }
    None => ()
  }
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) =>
      for elem in elems {
        let @lib.Elem(_, kind) = elem
        match kind {
          @lib.FuncsElemKind(funcs) =>
            for func_idx in funcs {
              let slot = inl_func_idx_slot(func_idx)
              if slot >= 0 && slot < used.length() {
                used[slot] = true
              }
            }
          @lib.FuncExprsElemKind(exprs) | @lib.TypedExprsElemKind(_, exprs) =>
            for expr in exprs {
              let @lib.Expr(instrs) = expr
              inl_scan_refs(instrs, Array::make(used.length(), 0), used)
            }
        }
      }
    None => ()
  }
}

///|
fn inl_scan_refs(
  instrs : Array[@lib.Instruction],
  refs : Array[Int],
  used : Array[Bool],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.Call(func_idx) | @lib.ReturnCall(func_idx) => {
        let slot = inl_func_idx_slot(func_idx)
        if slot >= 0 && slot < refs.length() {
          refs[slot] += 1
        }
      }
      @lib.RefFunc(func_idx) => {
        let slot = inl_func_idx_slot(func_idx)
        if slot >= 0 && slot < refs.length() {
          refs[slot] += 1
          used[slot] = true
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) => inl_scan_refs(body, refs, used)
      @lib.If(_, then_body, Some(else_body)) => {
        inl_scan_refs(then_body, refs, used)
        inl_scan_refs(else_body, refs, used)
      }
      @lib.If(_, then_body, None) => inl_scan_refs(then_body, refs, used)
      _ => ()
    }
  }
}

///|
fn inl_toolchain_inline_hints(
  mod_ : @lib.Module,
  total : Int,
) -> Array[InlToolchainInlineHint] {
  let hints = Array::make(total, InlToolchainInlineHint::DefaultInline)
  match mod_.func_annotation_sec {
    Some(@lib.FuncAnnotationSec(entries)) =>
      for entry in entries {
        let @lib.FuncAnnotationAssoc(raw_idx, annotations) = entry
        let slot = raw_idx.reinterpret_as_int()
        if slot < 0 || slot >= total {
          continue
        }
        for annotation in annotations {
          if annotation.name == "binaryen.inline" &&
            annotation.args.length() > 0 {
            let arg = annotation.args[annotation.args.length() - 1]
            if arg == "\"\\00\"" {
              hints[slot] = InlToolchainInlineHint::NeverInline
            } else if arg == "\"\\7f\"" || arg == "\"\\7F\"" {
              hints[slot] = InlToolchainInlineHint::AlwaysInline
            }
          }
        }
      }
    None => ()
  }
  hints
}

///|
fn inl_partial_wrapper_annotation_name() -> String {
  "starshine.partial-inline-wrapper"
}

///|
fn inl_annotation_map(
  mod_ : @lib.Module,
  total : Int,
) -> Array[Array[@lib.FuncAnnotation]] {
  let by_func : Array[Array[@lib.FuncAnnotation]] = []
  let mut idx = 0
  while idx < total {
    by_func.push([])
    idx += 1
  }
  match mod_.func_annotation_sec {
    Some(@lib.FuncAnnotationSec(entries)) =>
      for entry in entries {
        let @lib.FuncAnnotationAssoc(raw_idx, annotations) = entry
        let slot = raw_idx.reinterpret_as_int()
        if slot >= 0 && slot < total {
          by_func[slot] = annotations.copy()
        }
      }
    None => ()
  }
  by_func
}

///|
fn inl_build_func_annotation_sec_from_map(
  by_func : Array[Array[@lib.FuncAnnotation]],
) -> @lib.FuncAnnotationSec? {
  let entries : Array[@lib.FuncAnnotationAssoc] = []
  let mut idx = 0
  while idx < by_func.length() {
    if by_func[idx].length() > 0 {
      entries.push(
        @lib.FuncAnnotationAssoc::new(idx.reinterpret_as_uint(), by_func[idx]),
      )
    }
    idx += 1
  }
  if entries.length() == 0 {
    None
  } else {
    Some(@lib.FuncAnnotationSec::new(entries))
  }
}

///|
fn inl_partial_wrapper_flags(mod_ : @lib.Module, total : Int) -> Array[Bool] {
  let flags = Array::make(total, false)
  match mod_.func_annotation_sec {
    Some(@lib.FuncAnnotationSec(entries)) =>
      for entry in entries {
        let @lib.FuncAnnotationAssoc(raw_idx, annotations) = entry
        let slot = raw_idx.reinterpret_as_int()
        if slot >= 0 && slot < total {
          for annotation in annotations {
            if annotation.name == inl_partial_wrapper_annotation_name() {
              flags[slot] = true
            }
          }
        }
      }
    None => ()
  }
  flags
}

///|
fn inl_partial_simple_unary(instr : @lib.Instruction) -> Bool {
  // Mirrors Binaryen v131's `Unary` expression family plus `RefIsNull`.
  // Do not admit other one-input operations such as loads, ref casts, or GC
  // conversions: partial inlining duplicates these conditions at callsites.
  match instr {
    @lib.I32Eqz
    | @lib.I64Eqz
    | @lib.RefIsNull
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
    | @lib.I64TruncSatF64U
    | @lib.I8x16Splat
    | @lib.I16x8Splat
    | @lib.I32x4Splat
    | @lib.I64x2Splat
    | @lib.F32x4Splat
    | @lib.F64x2Splat
    | @lib.V128Not
    | @lib.V128AnyTrue
    | @lib.I8x16Abs
    | @lib.I8x16Neg
    | @lib.I8x16AllTrue
    | @lib.I8x16Bitmask
    | @lib.I8x16Popcnt
    | @lib.I16x8Abs
    | @lib.I16x8Neg
    | @lib.I16x8AllTrue
    | @lib.I16x8Bitmask
    | @lib.I32x4Abs
    | @lib.I32x4Neg
    | @lib.I32x4AllTrue
    | @lib.I32x4Bitmask
    | @lib.I64x2Abs
    | @lib.I64x2Neg
    | @lib.I64x2AllTrue
    | @lib.I64x2Bitmask
    | @lib.F32x4Abs
    | @lib.F32x4Neg
    | @lib.F32x4Sqrt
    | @lib.F32x4Ceil
    | @lib.F32x4Floor
    | @lib.F32x4Trunc
    | @lib.F32x4Nearest
    | @lib.F64x2Abs
    | @lib.F64x2Neg
    | @lib.F64x2Sqrt
    | @lib.F64x2Ceil
    | @lib.F64x2Floor
    | @lib.F64x2Trunc
    | @lib.F64x2Nearest
    | @lib.I16x8ExtaddPairwiseI8x16S
    | @lib.I16x8ExtaddPairwiseI8x16U
    | @lib.I32x4ExtaddPairwiseI16x8S
    | @lib.I32x4ExtaddPairwiseI16x8U
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
    | @lib.I32x4TruncSatF32x4S
    | @lib.I32x4TruncSatF32x4U
    | @lib.F32x4ConvertI32x4S
    | @lib.F32x4ConvertI32x4U
    | @lib.I32x4TruncSatF64x2SZero
    | @lib.I32x4TruncSatF64x2UZero
    | @lib.F64x2ConvertLowI32x4S
    | @lib.F64x2ConvertLowI32x4U
    | @lib.F32x4DemoteF64x2Zero
    | @lib.F64x2PromoteLowF32x4
    | @lib.I32x4RelaxedTruncF32x4S
    | @lib.I32x4RelaxedTruncF32x4U
    | @lib.I32x4RelaxedTruncZeroF64x2S
    | @lib.I32x4RelaxedTruncZeroF64x2U => true
    _ => false
  }
}

///|
fn inl_partial_simple_expr(
  instrs : Array[@lib.Instruction],
  start : Int,
  end : Int,
) -> Bool {
  if start < 0 || end <= start || end > instrs.length() {
    return false
  }
  match instrs[start] {
    @lib.LocalGet(_) | @lib.GlobalGet(_) => ()
    _ => return false
  }
  let mut idx = start + 1
  while idx < end {
    if !inl_partial_simple_unary(instrs[idx]) {
      return false
    }
    idx += 1
  }
  true
}

///|
priv struct InlPartialPatternA {
  condition : Array[@lib.Instruction]
  suffix : Array[@lib.Instruction]
}

///|
fn inl_partial_pattern_a(body : Array[@lib.Instruction]) -> InlPartialPatternA? {
  let mut if_idx = 1
  while if_idx < body.length() {
    match body[if_idx] {
      @lib.If(block_type, [@lib.Return], None) if block_type ==
        @lib.BlockType::void_() &&
        inl_partial_simple_expr(body, 0, if_idx) => {
        let condition : Array[@lib.Instruction] = []
        let suffix : Array[@lib.Instruction] = []
        let mut idx = 0
        while idx < if_idx {
          condition.push(body[idx])
          idx += 1
        }
        idx = if_idx + 1
        while idx < body.length() {
          suffix.push(body[idx])
          idx += 1
        }
        if suffix.length() > 0 {
          return Some({ condition, suffix })
        }
        return None
      }
      _ => ()
    }
    // The first top-level item must be the guard. Once a non-simple prefix can
    // no longer be its condition, no later if can match Pattern A.
    if !inl_partial_simple_expr(body, 0, if_idx + 1) {
      return None
    }
    if_idx += 1
  }
  None
}

///|
priv struct InlPartialPatternBArm {
  condition : Array[@lib.Instruction]
  body : Array[@lib.Instruction]
  terminal_exit : Bool
}

///|
priv struct InlPartialPatternB {
  arms : Array[InlPartialPatternBArm]
  final_item : Array[@lib.Instruction]
}

///|
fn inl_partial_instrs_have_return(instrs : Array[@lib.Instruction]) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Return
      | @lib.ReturnCall(_)
      | @lib.ReturnCallIndirect(_, _)
      | @lib.ReturnCallRef(_) => return true
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if inl_partial_instrs_have_return(body) {
          return true
        }
      @lib.If(_, then_body, Some(else_body)) =>
        if inl_partial_instrs_have_return(then_body) ||
          inl_partial_instrs_have_return(else_body) {
          return true
        }
      @lib.If(_, then_body, None) =>
        if inl_partial_instrs_have_return(then_body) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn inl_partial_terminal_exit(body : Array[@lib.Instruction]) -> Bool {
  if body.length() == 0 {
    return false
  }
  let last = body[body.length() - 1]
  let terminal = inl_instr_terminates_sequence(last)
  if !terminal {
    return false
  }
  let prefix : Array[@lib.Instruction] = []
  let mut idx = 0
  while idx + 1 < body.length() {
    prefix.push(body[idx])
    idx += 1
  }
  !inl_partial_instrs_have_return(prefix)
}

///|
fn inl_partial_instr_has_escaping_branch(
  instr : @lib.Instruction,
  depth : Int,
) -> Bool {
  match instr {
    @lib.Br(label) | @lib.BrIf(label) => inl_label_idx_slot(label) >= depth
    @lib.BrTable(labels, default) => {
      if inl_label_idx_slot(default) >= depth {
        return true
      }
      for label in labels {
        if inl_label_idx_slot(label) >= depth {
          return true
        }
      }
      false
    }
    @lib.Block(_, @lib.Expr(body))
    | @lib.Loop(_, @lib.Expr(body))
    | @lib.TryTable(_, _, @lib.Expr(body)) =>
      inl_partial_instrs_have_escaping_branch(body, depth + 1)
    @lib.If(_, then_body, Some(else_body)) =>
      inl_partial_instrs_have_escaping_branch(then_body, depth) ||
      inl_partial_instrs_have_escaping_branch(else_body, depth)
    @lib.If(_, then_body, None) =>
      inl_partial_instrs_have_escaping_branch(then_body, depth)
    _ => false
  }
}

///|
fn inl_partial_instrs_have_escaping_branch(
  instrs : Array[@lib.Instruction],
  depth : Int,
) -> Bool {
  for instr in instrs {
    if inl_partial_instr_has_escaping_branch(instr, depth) {
      return true
    }
  }
  false
}

///|
fn inl_partial_collect_local_sets(
  instrs : Array[@lib.Instruction],
  written : Array[Bool],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.LocalSet(idx) | @lib.LocalTee(idx) => {
        let slot = inl_local_idx_slot(idx)
        if slot >= 0 && slot < written.length() {
          written[slot] = true
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        inl_partial_collect_local_sets(body, written)
      @lib.If(_, then_body, Some(else_body)) => {
        inl_partial_collect_local_sets(then_body, written)
        inl_partial_collect_local_sets(else_body, written)
      }
      @lib.If(_, then_body, None) =>
        inl_partial_collect_local_sets(then_body, written)
      _ => ()
    }
  }
}

///|
fn inl_partial_simple_expr_reads_written_local(
  instrs : Array[@lib.Instruction],
  written : Array[Bool],
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.LocalGet(idx) => {
        let slot = inl_local_idx_slot(idx)
        if slot >= 0 && slot < written.length() && written[slot] {
          return true
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn inl_partial_pattern_b(
  body : Array[@lib.Instruction],
  max_ifs : Int,
  local_count : Int,
) -> InlPartialPatternB? {
  if max_ifs <= 0 {
    return None
  }
  let arms : Array[InlPartialPatternBArm] = []
  let written = Array::make(local_count, false)
  let mut start = 0
  while start < body.length() && arms.length() < max_ifs {
    let mut if_idx = start + 1
    while if_idx < body.length() &&
          inl_partial_simple_expr(body, start, if_idx + 1) {
      if_idx += 1
    }
    if if_idx >= body.length() || !inl_partial_simple_expr(body, start, if_idx) {
      break
    }
    let (then_body, has_else) = match body[if_idx] {
      @lib.If(_, then_body, Some(_)) => (then_body, true)
      @lib.If(_, then_body, None) => (then_body, false)
      _ => break
    }
    if has_else || inl_partial_instrs_have_escaping_branch(then_body, 0) {
      return None
    }
    let terminal_exit = inl_partial_terminal_exit(then_body)
    if inl_partial_instrs_have_return(then_body) && !terminal_exit {
      return None
    }
    let condition : Array[@lib.Instruction] = []
    let mut idx = start
    while idx < if_idx {
      condition.push(body[idx])
      idx += 1
    }
    arms.push({ condition, body: then_body, terminal_exit })
    inl_partial_collect_local_sets(then_body, written)
    start = if_idx + 1
  }
  if arms.length() == 0 {
    return None
  }
  // Seeing one more initial if than the configured maximum rejects Pattern B;
  // it is not an optional final value.
  if start < body.length() {
    let mut next_if = start + 1
    while next_if < body.length() &&
          inl_partial_simple_expr(body, start, next_if + 1) {
      next_if += 1
    }
    if next_if < body.length() && inl_partial_simple_expr(body, start, next_if) {
      match body[next_if] {
        @lib.If(_, _, _) => return None
        _ => ()
      }
    }
  }
  let final_item : Array[@lib.Instruction] = []
  let mut idx = start
  while idx < body.length() {
    final_item.push(body[idx])
    idx += 1
  }
  if final_item.length() > 0 &&
    !inl_partial_simple_expr(final_item, 0, final_item.length()) {
    return None
  }
  if inl_partial_simple_expr_reads_written_local(final_item, written) {
    return None
  }
  Some({ arms, final_item })
}

///|
fn inl_func_name_strings(mod_ : @lib.Module, total : Int) -> Array[String] {
  let names : Array[String] = []
  let mut idx = 0
  while idx < total {
    names.push(idx.to_string())
    idx += 1
  }
  match mod_.name_sec {
    Some(sec) =>
      match sec.func_names {
        Some(@lib.NameMap(entries)) =>
          for entry in entries {
            let @lib.NameAssoc(raw_idx, @lib.Name(name)) = entry
            let slot = raw_idx.reinterpret_as_int()
            if slot >= 0 && slot < total {
              names[slot] = name.to_owned()
            }
          }
        None => ()
      }
    None => ()
  }
  names
}

///|
fn inl_unique_generated_func_name(
  names : Array[String],
  base : String,
) -> String {
  let mut candidate = base
  let mut suffix = 1
  while names.any(fn(name) { name == candidate }) {
    candidate = "\{base}$\{suffix}"
    suffix += 1
  }
  candidate
}

///|
fn inl_name_sec_with_generated_func_names(
  sec : @lib.NameSec?,
  generated : Array[(UInt, String)],
) -> @lib.NameSec? {
  if generated.length() == 0 {
    return sec
  }
  let func_names : Array[@lib.NameAssoc] = []
  match sec {
    Some(existing) =>
      match existing.func_names {
        Some(@lib.NameMap(entries)) => func_names.append(entries)
        None => ()
      }
    None => ()
  }
  for pair in generated {
    let (idx, name) = pair
    func_names.push(@lib.NameAssoc::new(idx, @lib.Name::from_string(name)))
  }
  match sec {
    Some(existing) =>
      Some(
        @lib.NameSec::new(
          module_name=existing.module_name,
          func_names=Some(@lib.NameMap::new(func_names)),
          local_names=existing.local_names,
          label_names=existing.label_names,
          type_names=existing.type_names,
          table_names=existing.table_names,
          memory_names=existing.memory_names,
          global_names=existing.global_names,
          elem_names=existing.elem_names,
          data_names=existing.data_names,
          field_names=existing.field_names,
          tag_names=existing.tag_names,
        ),
      )
    None =>
      Some(@lib.NameSec::new(func_names=Some(@lib.NameMap::new(func_names))))
  }
}

///|
fn inl_rebuild_with_func_annotations(
  mod_ : @lib.Module,
  annotations : @lib.FuncAnnotationSec?,
) -> @lib.Module {
  @lib.Module::new(
    custom_secs=mod_.custom_secs,
    type_sec=mod_.type_sec,
    import_sec=mod_.import_sec,
    func_annotation_sec=annotations,
    func_sec=mod_.func_sec,
    table_sec=mod_.table_sec,
    mem_sec=mod_.mem_sec,
    tag_sec=mod_.tag_sec,
    stringrefs_sec=mod_.stringrefs_sec,
    global_sec=mod_.global_sec,
    export_sec=mod_.export_sec,
    start_sec=mod_.start_sec,
    elem_sec=mod_.elem_sec,
    data_cnt_sec=mod_.data_cnt_sec,
    code_sec=mod_.code_sec,
    data_sec=mod_.data_sec,
    name_sec=mod_.name_sec,
    raw_name_sec_payload=mod_.raw_name_sec_payload,
  )
}

///|
fn inl_apply_partial_pattern_a_splits(
  mod_ : @lib.Module,
  optimize_level : Int,
  shrink_level : Int,
  always_inline_max_size : Int,
  one_caller_inline_max_size : Int,
  flexible_inline_max_size : Int,
  max_combined_binary_size : Int,
  allow_functions_with_loops : Bool,
  partial_inlining_ifs : Int,
) -> @lib.Module {
  if partial_inlining_ifs <= 0 || optimize_level < 3 || shrink_level != 0 {
    return mod_
  }
  let original_type_idxs = match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => type_idxs
    None => return mod_
  }
  let original_funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  let imports = inl_imported_func_count(mod_)
  let original_total = imports + original_funcs.length()
  let infos = inl_build_function_infos(
    mod_,
    optimize_level~,
    shrink_level~,
    always_inline_max_size~,
    one_caller_inline_max_size~,
    flexible_inline_max_size~,
    max_combined_binary_size~,
    allow_functions_with_loops~,
  )
  let (_, no_partial) = no_inline_policy_flags(mod_)
  let existing_partial = inl_partial_wrapper_flags(mod_, original_total)
  let annotations = inl_annotation_map(mod_, original_total)
  let names = inl_func_name_strings(mod_, original_total)
  let type_idxs = original_type_idxs.copy()
  let funcs = original_funcs.copy()
  let generated_names : Array[(UInt, String)] = []
  let mut changed = false
  let mut def_idx = 0
  while def_idx < original_funcs.length() {
    let abs = imports + def_idx
    if infos[abs].inlineable || no_partial[abs] || existing_partial[abs] {
      def_idx += 1
      continue
    }
    let @lib.Func(locals, @lib.Expr(body)) = original_funcs[def_idx]
    let source_annotations = annotations[abs].copy()
    let mut split_this = false
    let pattern_a = if infos[abs].results.length() == 0 {
      inl_partial_pattern_a(body)
    } else {
      None
    }
    match pattern_a {
      Some(pattern) => {
        let outlined_abs = imports + funcs.length()
        type_idxs.push(original_type_idxs[def_idx])
        funcs.push(@lib.Func::new(locals, @lib.Expr::new(pattern.suffix)))
        let forwarded : Array[@lib.Instruction] = []
        let mut param_idx = 0
        while param_idx < infos[abs].params.length() {
          forwarded.push(
            @lib.Instruction::local_get(
              @lib.LocalIdx::new(param_idx.reinterpret_as_uint()),
            ),
          )
          param_idx += 1
        }
        forwarded.push(
          @lib.Instruction::call(
            @lib.FuncIdx::new(outlined_abs.reinterpret_as_uint()),
          ),
        )
        let wrapper_body = pattern.condition.copy()
        wrapper_body.push(@lib.Instruction::i32_eqz())
        wrapper_body.push(
          @lib.Instruction::if_(@lib.BlockType::void_(), forwarded, None),
        )
        funcs[def_idx] = @lib.Func::new(locals, @lib.Expr::new(wrapper_body))
        annotations.push(source_annotations)
        let generated_name = inl_unique_generated_func_name(
          names,
          "byn-split-outlined-A$\{names[abs]}",
        )
        names.push(generated_name)
        generated_names.push(
          (outlined_abs.reinterpret_as_uint(), generated_name),
        )
        changed = true
        split_this = true
      }
      None => {
        let pattern = match
          inl_partial_pattern_b(
            body,
            partial_inlining_ifs,
            infos[abs].params.length() + locals.length(),
          ) {
          Some(pattern) => pattern
          None => {
            def_idx += 1
            continue
          }
        }
        if infos[abs].results.length() > 0 &&
          pattern.arms.any(fn(arm) { !arm.terminal_exit }) {
          def_idx += 1
          continue
        }
        let wrapper_body : Array[@lib.Instruction] = []
        for arm in pattern.arms {
          let outlined_abs = imports + funcs.length()
          type_idxs.push(original_type_idxs[def_idx])
          funcs.push(@lib.Func::new(locals, @lib.Expr::new(arm.body)))
          annotations.push(source_annotations.copy())
          let generated_name = inl_unique_generated_func_name(
            names,
            "byn-split-outlined-B$\{names[abs]}",
          )
          names.push(generated_name)
          generated_names.push(
            (outlined_abs.reinterpret_as_uint(), generated_name),
          )
          wrapper_body.append(arm.condition)
          let forwarded : Array[@lib.Instruction] = []
          let mut param_idx = 0
          while param_idx < infos[abs].params.length() {
            forwarded.push(
              @lib.Instruction::local_get(
                @lib.LocalIdx::new(param_idx.reinterpret_as_uint()),
              ),
            )
            param_idx += 1
          }
          forwarded.push(
            @lib.Instruction::call(
              @lib.FuncIdx::new(outlined_abs.reinterpret_as_uint()),
            ),
          )
          if arm.terminal_exit {
            forwarded.push(@lib.Instruction::return_())
          }
          wrapper_body.push(
            @lib.Instruction::if_(@lib.BlockType::void_(), forwarded, None),
          )
        }
        wrapper_body.append(pattern.final_item)
        funcs[def_idx] = @lib.Func::new(locals, @lib.Expr::new(wrapper_body))
        changed = true
        split_this = true
      }
    }
    if split_this {
      let marker = @lib.FuncAnnotation::new(
        inl_partial_wrapper_annotation_name(),
      )
      if !inl_func_annotation_present(annotations[abs], marker) {
        annotations[abs].push(marker)
      }
    }
    def_idx += 1
  }
  if !changed {
    return mod_
  }
  let rewritten = mod_
    .with_func_sec(@lib.FuncSec::new(type_idxs))
    .with_code_sec(@lib.CodeSec::new(funcs))
  let rewritten = match
    inl_name_sec_with_generated_func_names(rewritten.name_sec, generated_names) {
    Some(sec) => rewritten.with_name_sec(sec)
    None => rewritten
  }
  inl_rebuild_with_func_annotations(
    rewritten,
    inl_build_func_annotation_sec_from_map(annotations),
  )
}

///|
fn inl_strip_partial_wrapper_annotations(mod_ : @lib.Module) -> @lib.Module {
  let total = inl_imported_func_count(mod_) + inl_defined_func_count(mod_)
  let annotations = inl_annotation_map(mod_, total)
  let mut changed = false
  let mut idx = 0
  while idx < annotations.length() {
    let filtered : Array[@lib.FuncAnnotation] = []
    for annotation in annotations[idx] {
      if annotation.name == inl_partial_wrapper_annotation_name() {
        changed = true
      } else {
        filtered.push(annotation)
      }
    }
    annotations[idx] = filtered
    idx += 1
  }
  if !changed {
    mod_
  } else {
    inl_rebuild_with_func_annotations(
      mod_,
      inl_build_func_annotation_sec_from_map(annotations),
    )
  }
}

///|
fn inl_build_function_infos(
  mod_ : @lib.Module,
  optimize_level? : Int = 0,
  shrink_level? : Int = 0,
  always_inline_max_size? : Int = 2,
  one_caller_inline_max_size? : Int = -1,
  flexible_inline_max_size? : Int = 20,
  max_combined_binary_size? : Int = 400 * 1024,
  allow_functions_with_loops? : Bool = false,
) -> Array[InlFunctionInfo] {
  let imports = inl_imported_func_count(mod_)
  let total = imports + inl_defined_func_count(mod_)
  let refs = Array::make(total, 0)
  let used = Array::make(total, false)
  inl_mark_global_uses(mod_, used)
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(_, @lib.Expr(body)) = func
        inl_scan_refs(body, refs, used)
      }
    None => ()
  }
  let types = inl_collect_func_type_indices(mod_)
  let (no_full_inline, _) = no_inline_policy_flags(mod_)
  let partial_wrappers = inl_partial_wrapper_flags(mod_, total)
  let toolchain_inline_hints = inl_toolchain_inline_hints(mod_, total)
  let infos : Array[InlFunctionInfo] = []
  let module_ctx = @ir.hot_module_context_from_module(mod_)
  let mut abs = 0
  while abs < total {
    let (
      params,
      results,
      size,
      has_calls,
      has_loops,
      _,
      has_return_call,
      trivial_shrinks,
      trivial_may_not_shrink,
    ) = if abs < imports {
      match inl_resolve_func_type(mod_, types, abs) {
        Some(@lib.FuncType(params, results)) =>
          (params, results, 1000000, true, false, false, true, false, false)
        None => ([], [], 1000000, true, false, false, true, false, false)
      }
    } else {
      let def_idx = abs - imports
      let func = match mod_.code_sec {
        Some(@lib.CodeSec(funcs)) => funcs[def_idx]
        None => abort("missing code section for inlining info")
      }
      let @lib.Func(_, @lib.Expr(body)) = func
      let (calls, loops, tries, tails) = inl_scan_shape_instrs(body)
      let measured_size = inl_count_instrs(body)
      let (hot_trivial_shrinks, trivial_may_not_shrink) = inl_hot_trivial_instruction_modes(
        mod_, abs, module_ctx, measured_size,
      )
      match inl_resolve_func_type(mod_, types, abs) {
        Some(@lib.FuncType(params, results)) => {
          let trivial_shrinks = hot_trivial_shrinks ||
            inl_body_is_shrinking_trivial(
              body,
              params.length(),
              mod_~,
              func_type_indices=types,
            )
          (
            params, results, measured_size, calls, loops, tries, tails, trivial_shrinks,
            trivial_may_not_shrink,
          )
        }
        None => ([], [], 1000000, true, false, true, true, false, false)
      }
    }
    let func_type_idx = if abs >= 0 && abs < types.length() {
      Some(types[abs])
    } else {
      None
    }
    let type_idx = if results.length() <= 1 {
      None
    } else if params.length() == 0 {
      func_type_idx
    } else {
      inl_find_zero_param_result_type(mod_, results)
    }
    let block_type_ok = inl_result_block_type(results, type_idx) is Some(_)
    let partial_wrapper = abs >= 0 &&
      abs < partial_wrappers.length() &&
      partial_wrappers[abs]
    let no_full_policy = abs >= 0 &&
      abs < no_full_inline.length() &&
      no_full_inline[abs] &&
      !partial_wrapper
    let toolchain_inline_hint = if abs >= 0 &&
      abs < toolchain_inline_hints.length() {
      toolchain_inline_hints[abs]
    } else {
      InlToolchainInlineHint::DefaultInline
    }
    let speed_focused = optimize_level >= 3 && shrink_level == 0
    let one_caller_size_ok = one_caller_inline_max_size < 0 ||
      size <= one_caller_inline_max_size
    let profitable = if partial_wrapper {
      true
    } else {
      match toolchain_inline_hint {
        NeverInline => false
        AlwaysInline => true
        DefaultInline =>
          if size <= always_inline_max_size {
            true
          } else if refs[abs] == 1 && !used[abs] && one_caller_size_ok {
            true
          } else if trivial_shrinks {
            true
          } else if size > flexible_inline_max_size || !speed_focused {
            false
          } else if trivial_may_not_shrink {
            true
          } else {
            !has_calls && (!has_loops || allow_functions_with_loops)
          }
      }
    }
    let inlineable = abs >= imports &&
      !no_full_policy &&
      block_type_ok &&
      profitable
    ignore(has_return_call)
    infos.push({
      params,
      results,
      type_idx,
      size,
      max_combined_binary_size,
      inlineable,
    })
    abs += 1
  }
  infos
}

///|
fn inl_copy_local_idx(
  idx : @lib.LocalIdx,
  local_map : Array[Int],
) -> @lib.LocalIdx {
  let slot = inl_local_idx_slot(idx)
  if slot >= 0 && slot < local_map.length() {
    @lib.LocalIdx::new(local_map[slot].reinterpret_as_uint())
  } else {
    idx
  }
}

///|
priv struct InlNestedReturnHoistState {
  mut next_local_idx : Int
  extra_types : Array[@lib.ValType]
  hoists : Array[InlTailCallsiteHoist]
  mut failed : Bool
}

///|
fn inl_nested_return_call_operand_types(
  instr : @lib.Instruction,
  mod_ : @lib.Module,
  infos : Array[InlFunctionInfo],
) -> Array[@lib.ValType]? {
  match instr {
    @lib.ReturnCall(func_idx) => {
      let target = inl_func_idx_slot(func_idx)
      if target >= 0 && target < infos.length() {
        Some(infos[target].params.copy())
      } else {
        None
      }
    }
    @lib.ReturnCallIndirect(type_idx, table_idx) =>
      match mod_.type_sec {
        Some(type_sec) =>
          match inl_type_sec_func_type(type_sec, type_idx) {
            Some(@lib.FuncType(params, _)) =>
              match
                @ir.hot_module_resolve_table_index_type(
                  @ir.hot_module_context_from_module(mod_),
                  table_idx,
                ) {
                Some(index_type) => {
                  let types = params.copy()
                  types.push(index_type)
                  Some(types)
                }
                None => None
              }
            None => None
          }
        None => None
      }
    @lib.ReturnCallRef(type_idx) =>
      match mod_.type_sec {
        Some(type_sec) =>
          match inl_type_sec_func_type(type_sec, type_idx) {
            Some(@lib.FuncType(params, _)) => {
              let types = params.copy()
              types.push(
                @lib.ValType::ref_type(
                  @lib.RefType::new(true, @lib.HeapType::new(type_idx)),
                ),
              )
              Some(types)
            }
            None => None
          }
        None => None
      }
    _ => None
  }
}

///|
fn inl_nested_return_call_with_local_operands(
  instr : @lib.Instruction,
  locals : Array[Int],
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  for local_idx in locals {
    out.push(
      @lib.Instruction::local_get(
        @lib.LocalIdx::new(local_idx.reinterpret_as_uint()),
      ),
    )
  }
  match instr {
    @lib.ReturnCall(func_idx) =>
      out.push(@lib.Instruction::return_call(func_idx))
    @lib.ReturnCallIndirect(type_idx, table_idx) =>
      out.push(@lib.Instruction::return_call_indirect(type_idx, table_idx))
    @lib.ReturnCallRef(type_idx) =>
      out.push(@lib.Instruction::return_call_ref(type_idx))
    _ => ()
  }
  out
}

///|
fn inl_hoist_nested_return_calls_in_instrs(
  instrs : Array[@lib.Instruction],
  try_depth : Int,
  state : InlNestedReturnHoistState,
  mod_ : @lib.Module,
  infos : Array[InlFunctionInfo],
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    if try_depth > 0 {
      match instr {
        @lib.ReturnCall(_)
        | @lib.ReturnCallIndirect(_, _)
        | @lib.ReturnCallRef(_) => {
          let operand_types = match
            inl_nested_return_call_operand_types(instr, mod_, infos) {
            Some(types) => types
            None => {
              state.failed = true
              out.push(instr)
              continue
            }
          }
          let locals : Array[Int] = []
          for operand_type in operand_types {
            locals.push(state.next_local_idx)
            state.next_local_idx += 1
            state.extra_types.push(operand_type)
          }
          let mut local_idx = locals.length() - 1
          while local_idx >= 0 {
            out.push(
              @lib.Instruction::local_set(
                @lib.LocalIdx::new(locals[local_idx].reinterpret_as_uint()),
              ),
            )
            local_idx -= 1
          }
          let hoist_id = state.hoists.length()
          out.push(inl_tail_callsite_hoist_placeholder(hoist_id))
          state.hoists.push({
            post_body: inl_nested_return_call_with_local_operands(instr, locals),
          })
          continue
        }
        _ => ()
      }
    }
    match instr {
      @lib.Block(block_type, @lib.Expr(body)) =>
        out.push(
          @lib.Instruction::block(
            block_type,
            @lib.Expr::new(
              inl_hoist_nested_return_calls_in_instrs(
                body, try_depth, state, mod_, infos,
              ),
            ),
          ),
        )
      @lib.Loop(block_type, @lib.Expr(body)) =>
        out.push(
          @lib.Instruction::loop_(
            block_type,
            @lib.Expr::new(
              inl_hoist_nested_return_calls_in_instrs(
                body, try_depth, state, mod_, infos,
              ),
            ),
          ),
        )
      @lib.If(block_type, then_body, else_body) => {
        let next_then = inl_hoist_nested_return_calls_in_instrs(
          then_body, try_depth, state, mod_, infos,
        )
        let next_else = match else_body {
          Some(body) =>
            Some(
              inl_hoist_nested_return_calls_in_instrs(
                body, try_depth, state, mod_, infos,
              ),
            )
          None => None
        }
        out.push(@lib.Instruction::if_(block_type, next_then, next_else))
      }
      @lib.TryTable(block_type, catches, @lib.Expr(body)) =>
        out.push(
          @lib.Instruction::try_table(
            block_type,
            catches,
            @lib.Expr::new(
              inl_hoist_nested_return_calls_in_instrs(
                body,
                try_depth + 1,
                state,
                mod_,
                infos,
              ),
            ),
          ),
        )
      _ => out.push(instr)
    }
  }
  out
}

///|
fn inl_prepare_nested_return_call_hoists(
  body : Array[@lib.Instruction],
  local_base : Int,
  mod_ : @lib.Module,
  infos : Array[InlFunctionInfo],
) -> (Array[@lib.Instruction], Array[@lib.ValType])? {
  let state : InlNestedReturnHoistState = {
    next_local_idx: local_base,
    extra_types: [],
    hoists: [],
    failed: false,
  }
  let transformed = inl_hoist_nested_return_calls_in_instrs(
    body, 0, state, mod_, infos,
  )
  if state.failed {
    return None
  }
  if state.hoists.length() == 0 {
    return Some((body, []))
  }
  let shifted = inl_shift_outer_target_branches(
    transformed,
    state.hoists.length(),
  )
  let mut current = inl_patch_tail_callsite_hoist_branches(
    shifted,
    state.hoists.length(),
    0,
  )
  current.push(@lib.Instruction::return_())
  let mut idx = state.hoists.length() - 1
  while idx >= 0 {
    let next : Array[@lib.Instruction] = [
      @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(current)),
    ]
    next.append(state.hoists[idx].post_body)
    current = next
    idx -= 1
  }
  Some((current, state.extra_types))
}

///|
fn inl_rewrite_callee_instr(
  instr : @lib.Instruction,
  local_map : Array[Int],
  return_depth : Int,
  preserve_tail_calls : Bool,
) -> @lib.Instruction {
  match instr {
    @lib.LocalGet(idx) =>
      @lib.Instruction::local_get(inl_copy_local_idx(idx, local_map))
    @lib.LocalSet(idx) =>
      @lib.Instruction::local_set(inl_copy_local_idx(idx, local_map))
    @lib.LocalTee(idx) =>
      @lib.Instruction::local_tee(inl_copy_local_idx(idx, local_map))
    @lib.Return =>
      @lib.Instruction::br(
        @lib.LabelIdx::new(return_depth.reinterpret_as_uint()),
      )
    @lib.Block(block_type, @lib.Expr(body)) =>
      @lib.Instruction::block(
        block_type,
        @lib.Expr::new(
          inl_rewrite_callee_instrs(
            body,
            local_map,
            return_depth + 1,
            preserve_tail_calls,
          ),
        ),
      )
    @lib.Loop(block_type, @lib.Expr(body)) =>
      @lib.Instruction::loop_(
        block_type,
        @lib.Expr::new(
          inl_rewrite_callee_instrs(
            body,
            local_map,
            return_depth + 1,
            preserve_tail_calls,
          ),
        ),
      )
    @lib.If(block_type, then_body, else_body) => {
      let next_then = inl_rewrite_callee_instrs(
        then_body,
        local_map,
        return_depth + 1,
        preserve_tail_calls,
      )
      let next_else = match else_body {
        Some(body) =>
          Some(
            inl_rewrite_callee_instrs(
              body,
              local_map,
              return_depth + 1,
              preserve_tail_calls,
            ),
          )
        None => None
      }
      @lib.Instruction::if_(block_type, next_then, next_else)
    }
    @lib.TryTable(block_type, catches, @lib.Expr(body)) =>
      @lib.Instruction::try_table(
        block_type,
        catches,
        @lib.Expr::new(
          inl_rewrite_callee_instrs(
            body,
            local_map,
            return_depth + 1,
            preserve_tail_calls,
          ),
        ),
      )
    _ => instr
  }
}

///|
fn inl_rewrite_callee_instrs(
  instrs : Array[@lib.Instruction],
  local_map : Array[Int],
  return_depth : Int,
  preserve_tail_calls : Bool,
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    if !preserve_tail_calls {
      match instr {
        @lib.ReturnCall(func_idx) => {
          out.push(@lib.Instruction::call(func_idx))
          out.push(
            @lib.Instruction::br(
              @lib.LabelIdx::new(return_depth.reinterpret_as_uint()),
            ),
          )
          continue
        }
        @lib.ReturnCallIndirect(type_idx, table_idx) => {
          out.push(@lib.Instruction::call_indirect(type_idx, table_idx))
          out.push(
            @lib.Instruction::br(
              @lib.LabelIdx::new(return_depth.reinterpret_as_uint()),
            ),
          )
          continue
        }
        @lib.ReturnCallRef(type_idx) => {
          out.push(@lib.Instruction::call_ref(type_idx))
          out.push(
            @lib.Instruction::br(
              @lib.LabelIdx::new(return_depth.reinterpret_as_uint()),
            ),
          )
          continue
        }
        _ => ()
      }
    }
    out.push(
      inl_rewrite_callee_instr(
        instr, local_map, return_depth, preserve_tail_calls,
      ),
    )
  }
  out
}

///|
fn inl_push_inline_replacement(
  out : Array[@lib.Instruction],
  replacement : Array[@lib.Instruction],
) -> Unit {
  if replacement.length() == 1 {
    match replacement[0] {
      @lib.Block(_, @lib.Expr([single])) => out.push(single)
      _ => out.append(replacement)
    }
  } else {
    out.append(replacement)
  }
}

///|
fn inl_tail_callsite_hoist_placeholder_base() -> Int {
  0x3fff0000
}

///|
fn inl_tail_callsite_hoist_placeholder(id : Int) -> @lib.Instruction {
  @lib.Instruction::br(
    @lib.LabelIdx::new(
      (inl_tail_callsite_hoist_placeholder_base() + id).reinterpret_as_uint(),
    ),
  )
}

///|
fn inl_tail_callsite_hoist_placeholder_id(label : @lib.LabelIdx) -> Int? {
  let slot = inl_label_idx_slot(label)
  let id = slot - inl_tail_callsite_hoist_placeholder_base()
  if id >= 0 {
    Some(id)
  } else {
    None
  }
}

///|
fn inl_shift_outer_target_label(
  label : @lib.LabelIdx,
  control_depth : Int,
  added_outer_depth : Int,
) -> @lib.LabelIdx {
  match inl_tail_callsite_hoist_placeholder_id(label) {
    Some(_) => return label
    None => ()
  }
  let slot = inl_label_idx_slot(label)
  if slot >= control_depth {
    @lib.LabelIdx::new((slot + added_outer_depth).reinterpret_as_uint())
  } else {
    label
  }
}

///|
fn inl_shift_outer_target_catches(
  catches : Array[@lib.Catch],
  control_depth : Int,
  added_outer_depth : Int,
) -> Array[@lib.Catch] {
  let out : Array[@lib.Catch] = []
  for catch_ in catches {
    match catch_ {
      @lib.Catch(tag, label) =>
        out.push(
          @lib.Catch::new(
            tag,
            inl_shift_outer_target_label(
              label, control_depth, added_outer_depth,
            ),
          ),
        )
      @lib.CatchRef(tag, label) =>
        out.push(
          @lib.Catch::ref_(
            tag,
            inl_shift_outer_target_label(
              label, control_depth, added_outer_depth,
            ),
          ),
        )
      @lib.CatchAll(label) =>
        out.push(
          @lib.Catch::all(
            inl_shift_outer_target_label(
              label, control_depth, added_outer_depth,
            ),
          ),
        )
      @lib.CatchAllRef(label) =>
        out.push(
          @lib.Catch::all_ref(
            inl_shift_outer_target_label(
              label, control_depth, added_outer_depth,
            ),
          ),
        )
    }
  }
  out
}

///|
fn inl_shift_outer_target_branches(
  instrs : Array[@lib.Instruction],
  added_outer_depth : Int,
  control_depth? : Int = 0,
) -> Array[@lib.Instruction] {
  if added_outer_depth <= 0 {
    return instrs
  }
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    match instr {
      @lib.Br(label) =>
        out.push(
          @lib.Instruction::br(
            inl_shift_outer_target_label(
              label, control_depth, added_outer_depth,
            ),
          ),
        )
      @lib.BrIf(label) =>
        out.push(
          @lib.Instruction::br_if(
            inl_shift_outer_target_label(
              label, control_depth, added_outer_depth,
            ),
          ),
        )
      @lib.BrTable(labels, fallback) => {
        let shifted : Array[@lib.LabelIdx] = []
        for label in labels {
          shifted.push(
            inl_shift_outer_target_label(
              label, control_depth, added_outer_depth,
            ),
          )
        }
        out.push(
          @lib.Instruction::br_table(
            shifted,
            inl_shift_outer_target_label(
              fallback, control_depth, added_outer_depth,
            ),
          ),
        )
      }
      @lib.BrOnNull(label) =>
        out.push(
          @lib.Instruction::br_on_null(
            inl_shift_outer_target_label(
              label, control_depth, added_outer_depth,
            ),
          ),
        )
      @lib.BrOnNonNull(label) =>
        out.push(
          @lib.Instruction::br_on_non_null(
            inl_shift_outer_target_label(
              label, control_depth, added_outer_depth,
            ),
          ),
        )
      @lib.BrOnCast(label, cast_op, source, target) =>
        out.push(
          @lib.Instruction::br_on_cast(
            inl_shift_outer_target_label(
              label, control_depth, added_outer_depth,
            ),
            cast_op.source_nullable(),
            source,
            cast_op.target_nullable(),
            target,
            source_exact=cast_op.source_exact(),
            target_exact=cast_op.target_exact(),
          ),
        )
      @lib.BrOnCastFail(label, cast_op, source, target) =>
        out.push(
          @lib.Instruction::br_on_cast_fail(
            inl_shift_outer_target_label(
              label, control_depth, added_outer_depth,
            ),
            cast_op.source_nullable(),
            source,
            cast_op.target_nullable(),
            target,
            source_exact=cast_op.source_exact(),
            target_exact=cast_op.target_exact(),
          ),
        )
      @lib.BrOnCastDescEq(label, source, target) =>
        out.push(
          @lib.Instruction::br_on_cast_desc_eq(
            inl_shift_outer_target_label(
              label, control_depth, added_outer_depth,
            ),
            source,
            target,
          ),
        )
      @lib.BrOnCastDescEqFail(label, source, target) =>
        out.push(
          @lib.Instruction::br_on_cast_desc_eq_fail(
            inl_shift_outer_target_label(
              label, control_depth, added_outer_depth,
            ),
            source,
            target,
          ),
        )
      @lib.Block(block_type, @lib.Expr(body)) =>
        out.push(
          @lib.Instruction::block(
            block_type,
            @lib.Expr::new(
              inl_shift_outer_target_branches(
                body,
                added_outer_depth,
                control_depth=control_depth + 1,
              ),
            ),
          ),
        )
      @lib.Loop(block_type, @lib.Expr(body)) =>
        out.push(
          @lib.Instruction::loop_(
            block_type,
            @lib.Expr::new(
              inl_shift_outer_target_branches(
                body,
                added_outer_depth,
                control_depth=control_depth + 1,
              ),
            ),
          ),
        )
      @lib.If(block_type, then_body, else_body) =>
        out.push(
          @lib.Instruction::if_(
            block_type,
            inl_shift_outer_target_branches(
              then_body,
              added_outer_depth,
              control_depth=control_depth + 1,
            ),
            match else_body {
              Some(body) =>
                Some(
                  inl_shift_outer_target_branches(
                    body,
                    added_outer_depth,
                    control_depth=control_depth + 1,
                  ),
                )
              None => None
            },
          ),
        )
      @lib.TryTable(block_type, catches, @lib.Expr(body)) =>
        out.push(
          @lib.Instruction::try_table(
            block_type,
            inl_shift_outer_target_catches(
              catches, control_depth, added_outer_depth,
            ),
            @lib.Expr::new(
              inl_shift_outer_target_branches(
                body,
                added_outer_depth,
                control_depth=control_depth + 1,
              ),
            ),
          ),
        )
      _ => out.push(instr)
    }
  }
  out
}

///|
fn inl_patch_tail_callsite_hoist_branches(
  instrs : Array[@lib.Instruction],
  hoist_count : Int,
  control_depth : Int,
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    match instr {
      @lib.Br(label) =>
        match inl_tail_callsite_hoist_placeholder_id(label) {
          Some(id) if id < hoist_count =>
            out.push(
              @lib.Instruction::br(
                @lib.LabelIdx::new(
                  (control_depth + hoist_count - 1 - id).reinterpret_as_uint(),
                ),
              ),
            )
          _ => out.push(instr)
        }
      @lib.Block(block_type, @lib.Expr(body)) =>
        out.push(
          @lib.Instruction::block(
            block_type,
            @lib.Expr::new(
              inl_patch_tail_callsite_hoist_branches(
                body,
                hoist_count,
                control_depth + 1,
              ),
            ),
          ),
        )
      @lib.Loop(block_type, @lib.Expr(body)) =>
        out.push(
          @lib.Instruction::loop_(
            block_type,
            @lib.Expr::new(
              inl_patch_tail_callsite_hoist_branches(
                body,
                hoist_count,
                control_depth + 1,
              ),
            ),
          ),
        )
      @lib.TryTable(block_type, catches, @lib.Expr(body)) =>
        out.push(
          @lib.Instruction::try_table(
            block_type,
            catches,
            @lib.Expr::new(
              inl_patch_tail_callsite_hoist_branches(
                body,
                hoist_count,
                control_depth + 1,
              ),
            ),
          ),
        )
      @lib.If(block_type, then_body, else_body) => {
        let next_then = inl_patch_tail_callsite_hoist_branches(
          then_body,
          hoist_count,
          control_depth + 1,
        )
        let next_else = match else_body {
          Some(body) =>
            Some(
              inl_patch_tail_callsite_hoist_branches(
                body,
                hoist_count,
                control_depth + 1,
              ),
            )
          None => None
        }
        out.push(@lib.Instruction::if_(block_type, next_then, next_else))
      }
      _ => out.push(instr)
    }
  }
  out
}

///|
fn inl_wrap_tail_callsite_hoists(
  body : Array[@lib.Instruction],
  hoists : Array[InlTailCallsiteHoist],
) -> Array[@lib.Instruction] {
  if hoists.length() == 0 {
    return body
  }
  let shifted = inl_shift_outer_target_branches(body, hoists.length())
  let mut current = inl_patch_tail_callsite_hoist_branches(
    shifted,
    hoists.length(),
    0,
  )
  current.push(@lib.Instruction::return_())
  let mut idx = hoists.length() - 1
  while idx >= 0 {
    let next : Array[@lib.Instruction] = [
      @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(current)),
    ]
    next.append(hoists[idx].post_body)
    next.push(@lib.Instruction::return_())
    current = next
    idx -= 1
  }
  current
}

///|
fn inl_can_inline_action(
  caller_abs : Int,
  caller_size : Int,
  callee_abs : Int,
  infos : Array[InlFunctionInfo],
  touched : Array[Bool],
) -> Bool {
  callee_abs >= 0 &&
  callee_abs < infos.length() &&
  caller_abs >= 0 &&
  caller_abs < infos.length() &&
  callee_abs != caller_abs &&
  infos[callee_abs].inlineable &&
  (callee_abs >= touched.length() || !touched[callee_abs]) &&
  inl_combined_binary_size_within_limit(
    caller_size,
    infos[callee_abs].size,
    max_combined_binary_size=infos[callee_abs].max_combined_binary_size,
  )
}

///|
fn inl_instr_terminates_sequence(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Unreachable
    | @lib.Return
    | @lib.ReturnCall(_)
    | @lib.ReturnCallIndirect(_, _)
    | @lib.ReturnCallRef(_)
    | @lib.Br(_)
    | @lib.BrTable(_, _)
    | @lib.Throw(_)
    | @lib.ThrowRef
    | @lib.Rethrow(_)
    | @lib.Resume(_, _)
    | @lib.ResumeThrow(_, _, _)
    | @lib.ResumeThrowRef(_, _)
    | @lib.StackSwitch(_, _) => true
    _ => false
  }
}

///|
fn inl_inline_call_instrs(
  instrs : Array[@lib.Instruction],
  caller_abs : Int,
  state : InlRewriteState,
  mod_ : @lib.Module,
  infos : Array[InlFunctionInfo],
  imports : Int,
  touched : Array[Bool],
  inlined_from : Array[Bool],
  try_depth? : Int = 0,
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  let mut reachable = true
  for instr in instrs {
    if !reachable {
      match instr {
        @lib.Call(_) | @lib.ReturnCall(_) => {
          out.push(instr)
          continue
        }
        _ => ()
      }
    }
    match instr {
      @lib.Call(func_idx) => {
        let callee_abs = inl_func_idx_slot(func_idx)
        if callee_abs >= imports &&
          inl_can_inline_action(
            caller_abs,
            state.size,
            callee_abs,
            infos,
            touched,
          ) {
          match
            inl_make_inline_replacement(
              state.func,
              mod_,
              infos,
              caller_abs,
              callee_abs,
              imports,
              false,
            ) {
            Some((next_func, replacement)) => {
              state.func = next_func
              state.changed = true
              if caller_abs >= 0 && caller_abs < touched.length() {
                touched[caller_abs] = true
              }
              if callee_abs >= 0 && callee_abs < inlined_from.length() {
                inlined_from[callee_abs] = true
              }
              inl_push_inline_replacement(out, replacement)
            }
            None => out.push(instr)
          }
        } else {
          out.push(instr)
        }
      }
      @lib.ReturnCall(func_idx) => {
        let callee_abs = inl_func_idx_slot(func_idx)
        if callee_abs >= imports &&
          inl_can_inline_action(
            caller_abs,
            state.size,
            callee_abs,
            infos,
            touched,
          ) {
          match
            inl_make_inline_replacement(
              state.func,
              mod_,
              infos,
              caller_abs,
              callee_abs,
              imports,
              true,
            ) {
            Some((next_func, replacement)) => {
              state.func = next_func
              state.changed = true
              if caller_abs >= 0 && caller_abs < touched.length() {
                touched[caller_abs] = true
              }
              if callee_abs >= 0 && callee_abs < inlined_from.length() {
                inlined_from[callee_abs] = true
              }
              if try_depth > 0 {
                let param_count = infos[callee_abs].params.length()
                let site_prefix : Array[@lib.Instruction] = []
                let post_body : Array[@lib.Instruction] = []
                let mut replacement_idx = 0
                while replacement_idx < replacement.length() {
                  if replacement_idx < param_count {
                    site_prefix.push(replacement[replacement_idx])
                  } else {
                    post_body.push(replacement[replacement_idx])
                  }
                  replacement_idx += 1
                }
                out.append(site_prefix)
                let hoist_id = state.tail_callsite_hoists.length()
                out.push(inl_tail_callsite_hoist_placeholder(hoist_id))
                state.tail_callsite_hoists.push({ post_body, })
              } else {
                inl_push_inline_replacement(out, replacement)
                out.push(@lib.Instruction::return_())
              }
            }
            None => out.push(instr)
          }
        } else {
          out.push(instr)
        }
      }
      @lib.Block(block_type, @lib.Expr(body)) =>
        out.push(
          @lib.Instruction::block(
            block_type,
            @lib.Expr::new(
              inl_inline_call_instrs(
                body,
                caller_abs,
                state,
                mod_,
                infos,
                imports,
                touched,
                inlined_from,
                try_depth~,
              ),
            ),
          ),
        )
      @lib.Loop(block_type, @lib.Expr(body)) =>
        out.push(
          @lib.Instruction::loop_(
            block_type,
            @lib.Expr::new(
              inl_inline_call_instrs(
                body,
                caller_abs,
                state,
                mod_,
                infos,
                imports,
                touched,
                inlined_from,
                try_depth~,
              ),
            ),
          ),
        )
      @lib.If(block_type, then_body, else_body) => {
        let next_then = inl_inline_call_instrs(
          then_body,
          caller_abs,
          state,
          mod_,
          infos,
          imports,
          touched,
          inlined_from,
          try_depth~,
        )
        let next_else = match else_body {
          Some(body) =>
            Some(
              inl_inline_call_instrs(
                body,
                caller_abs,
                state,
                mod_,
                infos,
                imports,
                touched,
                inlined_from,
                try_depth~,
              ),
            )
          None => None
        }
        out.push(@lib.Instruction::if_(block_type, next_then, next_else))
      }
      @lib.TryTable(block_type, catches, @lib.Expr(body)) =>
        out.push(
          @lib.Instruction::try_table(
            block_type,
            catches,
            @lib.Expr::new(
              inl_inline_call_instrs(
                body,
                caller_abs,
                state,
                mod_,
                infos,
                imports,
                touched,
                inlined_from,
                try_depth=try_depth + 1,
              ),
            ),
          ),
        )
      _ => out.push(instr)
    }
    if inl_instr_terminates_sequence(instr) {
      reachable = false
    }
  }
  out
}

///|
fn inl_default_local_init_instrs(
  local_type : @lib.ValType,
  local_idx : Int,
) -> Array[@lib.Instruction] {
  let idx = @lib.LocalIdx::new(local_idx.reinterpret_as_uint())
  let init = match local_type {
    @lib.NumTypeValType(@lib.I32NumType) =>
      Some(@lib.Instruction::i32_const(@lib.I32::new(0)))
    @lib.NumTypeValType(@lib.I64NumType) =>
      Some(@lib.Instruction::i64_const(@lib.I64::new(0L)))
    @lib.NumTypeValType(@lib.F32NumType) =>
      Some(@lib.Instruction::f32_const(@lib.F32::new(0.0)))
    @lib.NumTypeValType(@lib.F64NumType) =>
      Some(@lib.Instruction::f64_const(@lib.F64::new(0.0)))
    @lib.VecTypeValType =>
      Some(
        @lib.Instruction::v128_const(
          b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
          b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
        ),
      )
    @lib.RefTypeValType(rt) if rt.is_nullable() =>
      Some(@lib.Instruction::ref_null_type(rt))
    _ => None
  }
  match init {
    Some(instr) => [instr, @lib.Instruction::local_set(idx)]
    None => []
  }
}

///|
fn inl_make_inline_replacement(
  caller : @lib.Func,
  mod_ : @lib.Module,
  infos : Array[InlFunctionInfo],
  caller_abs : Int,
  callee_abs : Int,
  imports : Int,
  tail_callsite : Bool,
) -> (@lib.Func, Array[@lib.Instruction])? {
  let def_idx = callee_abs - imports
  let callee = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs[def_idx]
    None => return None
  }
  let @lib.Func(caller_locals, _) = caller
  let @lib.Func(callee_locals, @lib.Expr(callee_body)) = callee
  let info = infos[callee_abs]
  let block_type = match inl_result_block_type(info.results, info.type_idx) {
    Some(block_type) => block_type
    None => return None
  }
  let base = infos[caller_abs].params.length() + caller_locals.length()
  let local_map : Array[Int] = []
  for _ in info.params {
    local_map.push(base + local_map.length())
  }
  for local_type in callee_locals.iter() {
    local_map.push(base + local_map.length())
    ignore(local_type)
  }
  let prepared_body_and_locals = if tail_callsite {
    Some((callee_body, []))
  } else {
    inl_prepare_nested_return_call_hoists(
      callee_body,
      base + local_map.length(),
      mod_,
      infos,
    )
  }
  let (prepared_body, hoist_local_types) = match prepared_body_and_locals {
    Some(value) => value
    None => return None
  }
  let next_locals = caller_locals.copy()
  next_locals.append_types(info.params)
  next_locals.append(callee_locals)
  next_locals.append_types(hoist_local_types)
  let replacement : Array[@lib.Instruction] = []
  let mut param_idx = info.params.length() - 1
  while param_idx >= 0 {
    replacement.push(
      @lib.Instruction::local_set(
        @lib.LocalIdx::new(local_map[param_idx].reinterpret_as_uint()),
      ),
    )
    param_idx -= 1
  }
  let mut local_idx = 0
  for local_type in callee_locals.iter() {
    replacement.append(
      inl_default_local_init_instrs(
        local_type,
        local_map[info.params.length() + local_idx],
      ),
    )
    local_idx += 1
  }
  let body = inl_rewrite_callee_instrs(
    prepared_body, local_map, 0, tail_callsite,
  )
  replacement.push(@lib.Instruction::block(block_type, @lib.Expr::new(body)))
  Some(
    (
      @lib.Func::new(
        next_locals,
        match caller {
          @lib.Func(_, expr) => expr
        },
      ),
      replacement,
    ),
  )
}

///|
fn inl_rewrite_func_body(
  mod_ : @lib.Module,
  infos : Array[InlFunctionInfo],
  imports : Int,
  def_idx : Int,
  func : @lib.Func,
  touched : Array[Bool],
  inlined_from : Array[Bool],
) -> @lib.Func {
  let caller_abs = imports + def_idx
  let @lib.Func(_, @lib.Expr(body)) = func
  let state : InlRewriteState = {
    func,
    changed: false,
    size: if caller_abs >= 0 && caller_abs < infos.length() {
      infos[caller_abs].size
    } else {
      inl_count_instrs(body)
    },
    tail_callsite_hoists: [],
  }
  if caller_abs >= 0 &&
    caller_abs < inlined_from.length() &&
    inlined_from[caller_abs] {
    return func
  }
  let next_body = inl_inline_call_instrs(
    body, caller_abs, state, mod_, infos, imports, touched, inlined_from,
  )
  if state.changed {
    let @lib.Func(next_locals, _) = state.func
    @lib.Func::new(
      next_locals,
      @lib.Expr::new(
        inl_wrap_tail_callsite_hoists(next_body, state.tail_callsite_hoists),
      ),
    )
  } else {
    func
  }
}

///|
fn inl_rewrite_all_calls(
  mod_ : @lib.Module,
  infos : Array[InlFunctionInfo],
) -> InlPassResult {
  let imports = inl_imported_func_count(mod_)
  let total = infos.length()
  let touched = Array::make(total, false)
  let inlined_from = Array::make(total, false)
  let mut changed = false
  let next_mod = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let out : Array[@lib.Func] = []
      let mut def_idx = 0
      for func in funcs {
        let next = inl_rewrite_func_body(
          mod_, infos, imports, def_idx, func, touched, inlined_from,
        )
        if next != func {
          changed = true
        }
        out.push(next)
        def_idx += 1
      }
      mod_.with_code_sec(@lib.CodeSec::new(out))
    }
    None => mod_
  }
  { mod_out: next_mod, touched, inlined_from, changed }
}

///|
fn inl_rewrite_func_idx(
  idx : @lib.FuncIdx,
  remap : Array[UInt],
) -> @lib.FuncIdx {
  let @lib.FuncIdx(raw) = idx
  let slot = raw.reinterpret_as_int()
  if slot < 0 || slot >= remap.length() {
    idx
  } else {
    let next = remap[slot]
    if next == raw {
      idx
    } else {
      @lib.FuncIdx::new(next)
    }
  }
}

///|
fn inl_rewrite_instruction_func_idxs(
  instr : @lib.Instruction,
  remap : Array[UInt],
) -> @lib.Instruction {
  match instr {
    @lib.Block(block_type, expr) =>
      @lib.Instruction::block(
        block_type,
        inl_rewrite_expr_func_idxs(expr, remap),
      )
    @lib.Loop(block_type, expr) =>
      @lib.Instruction::loop_(
        block_type,
        inl_rewrite_expr_func_idxs(expr, remap),
      )
    @lib.If(block_type, then_body, else_body) => {
      let next_then : Array[@lib.Instruction] = []
      for nested in then_body {
        next_then.push(inl_rewrite_instruction_func_idxs(nested, remap))
      }
      let next_else = match else_body {
        Some(body) => {
          let out : Array[@lib.Instruction] = []
          for nested in body {
            out.push(inl_rewrite_instruction_func_idxs(nested, remap))
          }
          Some(out)
        }
        None => None
      }
      @lib.Instruction::if_(block_type, next_then, next_else)
    }
    @lib.Call(func_idx) =>
      @lib.Instruction::call(inl_rewrite_func_idx(func_idx, remap))
    @lib.ReturnCall(func_idx) =>
      @lib.Instruction::return_call(inl_rewrite_func_idx(func_idx, remap))
    @lib.TryTable(block_type, catches, body) =>
      @lib.Instruction::try_table(
        block_type,
        catches,
        inl_rewrite_expr_func_idxs(body, remap),
      )
    @lib.RefFunc(func_idx) =>
      @lib.Instruction::ref_func(inl_rewrite_func_idx(func_idx, remap))
    _ => instr
  }
}

///|
fn inl_rewrite_expr_func_idxs(
  expr : @lib.Expr,
  remap : Array[UInt],
) -> @lib.Expr {
  let @lib.Expr(instrs) = expr
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    out.push(inl_rewrite_instruction_func_idxs(instr, remap))
  }
  @lib.Expr::new(out)
}

///|
fn inl_rewrite_elem_kind_func_idxs(
  kind : @lib.ElemKind,
  remap : Array[UInt],
) -> @lib.ElemKind {
  match kind {
    @lib.FuncsElemKind(funcs) => {
      let out : Array[@lib.FuncIdx] = []
      for func_idx in funcs {
        out.push(inl_rewrite_func_idx(func_idx, remap))
      }
      @lib.ElemKind::funcs(out)
    }
    @lib.FuncExprsElemKind(exprs) => {
      let out : Array[@lib.Expr] = []
      for expr in exprs {
        out.push(inl_rewrite_expr_func_idxs(expr, remap))
      }
      @lib.ElemKind::func_exprs(out)
    }
    @lib.TypedExprsElemKind(ref_type, exprs) => {
      let out : Array[@lib.Expr] = []
      for expr in exprs {
        out.push(inl_rewrite_expr_func_idxs(expr, remap))
      }
      @lib.ElemKind::typed_exprs(ref_type, out)
    }
  }
}

///|
fn inl_remap_name_map(
  map : @lib.NameMap?,
  remap : Array[UInt],
  final_total : Int,
) -> @lib.NameMap? {
  let out : Array[@lib.NameAssoc] = []
  match map {
    Some(@lib.NameMap(entries)) =>
      for entry in entries {
        let @lib.NameAssoc(raw_idx, name) = entry
        let old_idx = raw_idx.reinterpret_as_int()
        if old_idx >= 0 && old_idx < remap.length() {
          let next_idx = remap[old_idx].reinterpret_as_int()
          if next_idx >= 0 && next_idx < final_total {
            out.push(@lib.NameAssoc::new(next_idx.reinterpret_as_uint(), name))
          }
        }
      }
    None => ()
  }
  if out.length() == 0 {
    None
  } else {
    Some(@lib.NameMap::new(out))
  }
}

///|
fn inl_remap_indirect_name_map(
  map : @lib.IndirectNameMap?,
  remap : Array[UInt],
  final_total : Int,
  drop_for_final? : Array[Bool]? = None,
) -> @lib.IndirectNameMap? {
  let out : Array[@lib.IndirectNameAssoc] = []
  match map {
    Some(@lib.IndirectNameMap(entries)) =>
      for entry in entries {
        let @lib.IndirectNameAssoc(raw_idx, inner) = entry
        let old_idx = raw_idx.reinterpret_as_int()
        if old_idx >= 0 && old_idx < remap.length() {
          let next_idx = remap[old_idx].reinterpret_as_int()
          let dropped = match drop_for_final {
            Some(flags) =>
              next_idx >= 0 && next_idx < flags.length() && flags[next_idx]
            None => false
          }
          if next_idx >= 0 && next_idx < final_total && !dropped {
            out.push(
              @lib.IndirectNameAssoc::new(next_idx.reinterpret_as_uint(), inner),
            )
          }
        }
      }
    None => ()
  }
  if out.length() == 0 {
    None
  } else {
    Some(@lib.IndirectNameMap::new(out))
  }
}

///|
fn inl_name_sec_is_empty(sec : @lib.NameSec) -> Bool {
  sec.module_name is None &&
  sec.func_names is None &&
  sec.local_names is None &&
  sec.label_names is None &&
  sec.type_names is None &&
  sec.table_names is None &&
  sec.memory_names is None &&
  sec.global_names is None &&
  sec.elem_names is None &&
  sec.data_names is None &&
  sec.field_names is None &&
  sec.tag_names is None
}

///|
fn inl_remap_name_sec(
  sec : @lib.NameSec?,
  remap : Array[UInt],
  final_total : Int,
  touched_final? : Array[Bool]? = None,
) -> @lib.NameSec? {
  match sec {
    Some(sec) => {
      let next = @lib.NameSec::new(
        module_name=sec.module_name,
        func_names=inl_remap_name_map(sec.func_names, remap, final_total),
        // Existing caller locals retain their indices because inlining appends
        // spills and copied callee locals. Preserve those valid names while
        // discarding entries only for functions removed by compaction.
        local_names=inl_remap_indirect_name_map(
          sec.local_names,
          remap,
          final_total,
        ),
        // A copied control tree can shift label ordinals. Preserve label names
        // for untouched functions, and drop only maps whose bodies changed.
        label_names=inl_remap_indirect_name_map(
          sec.label_names,
          remap,
          final_total,
          drop_for_final=touched_final,
        ),
        type_names=sec.type_names,
        table_names=sec.table_names,
        memory_names=sec.memory_names,
        global_names=sec.global_names,
        elem_names=sec.elem_names,
        data_names=sec.data_names,
        field_names=sec.field_names,
        tag_names=sec.tag_names,
      )
      if inl_name_sec_is_empty(next) {
        None
      } else {
        Some(next)
      }
    }
    None => None
  }
}

///|
fn inl_func_annotation_present(
  annotations : Array[@lib.FuncAnnotation],
  annotation : @lib.FuncAnnotation,
) -> Bool {
  for existing in annotations {
    if existing == annotation {
      return true
    }
  }
  false
}

///|
fn inl_remap_func_annotation_sec(
  sec : @lib.FuncAnnotationSec?,
  remap : Array[UInt],
  final_total : Int,
) -> @lib.FuncAnnotationSec? {
  if final_total <= 0 {
    return None
  }
  let by_func : Array[Array[@lib.FuncAnnotation]] = []
  let mut idx = 0
  while idx < final_total {
    by_func.push([])
    idx += 1
  }
  match sec {
    Some(@lib.FuncAnnotationSec(entries)) =>
      for entry in entries {
        let @lib.FuncAnnotationAssoc(raw_idx, annotations) = entry
        let old_idx = raw_idx.reinterpret_as_int()
        if old_idx >= 0 && old_idx < remap.length() {
          let next_idx = remap[old_idx].reinterpret_as_int()
          if next_idx >= 0 && next_idx < final_total {
            for annotation in annotations {
              if !inl_func_annotation_present(by_func[next_idx], annotation) {
                by_func[next_idx].push(annotation)
              }
            }
          }
        }
      }
    None => ()
  }
  let entries : Array[@lib.FuncAnnotationAssoc] = []
  idx = 0
  while idx < by_func.length() {
    if by_func[idx].length() > 0 {
      entries.push(
        @lib.FuncAnnotationAssoc::new(idx.reinterpret_as_uint(), by_func[idx]),
      )
    }
    idx += 1
  }
  if entries.length() == 0 {
    None
  } else {
    Some(@lib.FuncAnnotationSec::new(entries))
  }
}

///|
fn inl_apply_func_remap(
  mod_ : @lib.Module,
  remap : Array[UInt],
  touched_final? : Array[Bool]? = None,
) -> @lib.Module {
  let mut rewritten = mod_
  match rewritten.export_sec {
    Some(@lib.ExportSec(exports)) => {
      let out : Array[@lib.Export] = []
      for export_ in exports {
        let @lib.Export(name, idx) = export_
        let next_idx = match idx {
          @lib.FuncExternIdx(func_idx) =>
            @lib.ExternIdx::func(inl_rewrite_func_idx(func_idx, remap))
          _ => idx
        }
        out.push(@lib.Export::new(name, next_idx))
      }
      rewritten = rewritten.with_export_sec(@lib.ExportSec::new(out))
    }
    None => ()
  }
  match rewritten.start_sec {
    Some(@lib.StartSec(func_idx)) =>
      rewritten = rewritten.with_start_sec(
        @lib.StartSec::new(inl_rewrite_func_idx(func_idx, remap)),
      )
    None => ()
  }
  match rewritten.elem_sec {
    Some(@lib.ElemSec(elems)) => {
      let out : Array[@lib.Elem] = []
      for elem in elems {
        let @lib.Elem(mode, kind) = elem
        let next_mode = match mode {
          @lib.Active(table_idx, expr) =>
            @lib.ElemMode::active(
              table_idx,
              inl_rewrite_expr_func_idxs(expr, remap),
            )
          _ => mode
        }
        out.push(
          @lib.Elem::new(
            next_mode,
            inl_rewrite_elem_kind_func_idxs(kind, remap),
          ),
        )
      }
      rewritten = rewritten.with_elem_sec(@lib.ElemSec::new(out))
    }
    None => ()
  }
  match rewritten.table_sec {
    Some(@lib.TableSec(tables)) => {
      let out : Array[@lib.Table] = []
      for table in tables {
        let @lib.Table(table_type, init) = table
        out.push(
          @lib.Table::new(
            table_type,
            match init {
              Some(expr) => Some(inl_rewrite_expr_func_idxs(expr, remap))
              None => None
            },
          ),
        )
      }
      rewritten = rewritten.with_table_sec(@lib.TableSec::new(out))
    }
    None => ()
  }
  match rewritten.global_sec {
    Some(@lib.GlobalSec(globals)) => {
      let out : Array[@lib.Global] = []
      for global in globals {
        let @lib.Global(global_type, expr) = global
        out.push(
          @lib.Global::new(global_type, inl_rewrite_expr_func_idxs(expr, remap)),
        )
      }
      rewritten = rewritten.with_global_sec(@lib.GlobalSec::new(out))
    }
    None => ()
  }
  match rewritten.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let out : Array[@lib.Func] = []
      for func in funcs {
        let @lib.Func(locals, expr) = func
        out.push(
          @lib.Func::new(locals, inl_rewrite_expr_func_idxs(expr, remap)),
        )
      }
      rewritten = rewritten.with_code_sec(@lib.CodeSec::new(out))
    }
    None => ()
  }
  match rewritten.data_sec {
    Some(@lib.DataSec(datas)) => {
      let out : Array[@lib.Data] = []
      for data in datas {
        let @lib.Data(mode, bytes) = data
        let next_mode = match mode {
          @lib.Active(mem_idx, expr) =>
            @lib.DataMode::active(
              mem_idx,
              inl_rewrite_expr_func_idxs(expr, remap),
            )
          @lib.Passive => mode
        }
        out.push(@lib.Data::new(next_mode, bytes))
      }
      rewritten = rewritten.with_data_sec(@lib.DataSec::new(out))
    }
    None => ()
  }
  let final_total = inl_imported_func_count(rewritten) +
    inl_defined_func_count(rewritten)
  let remapped_annotations = inl_remap_func_annotation_sec(
    rewritten.func_annotation_sec,
    remap,
    final_total,
  )
  let remapped_names = inl_remap_name_sec(
    rewritten.name_sec,
    remap,
    final_total,
    touched_final~,
  )
  @lib.Module::new(
    custom_secs=rewritten.custom_secs,
    type_sec=rewritten.type_sec,
    import_sec=rewritten.import_sec,
    func_annotation_sec=remapped_annotations,
    func_sec=rewritten.func_sec,
    table_sec=rewritten.table_sec,
    mem_sec=rewritten.mem_sec,
    tag_sec=rewritten.tag_sec,
    stringrefs_sec=rewritten.stringrefs_sec,
    global_sec=rewritten.global_sec,
    export_sec=rewritten.export_sec,
    start_sec=rewritten.start_sec,
    elem_sec=rewritten.elem_sec,
    data_cnt_sec=rewritten.data_cnt_sec,
    code_sec=rewritten.code_sec,
    data_sec=rewritten.data_sec,
    name_sec=remapped_names,
    raw_name_sec_payload=None,
  )
}

///|
fn inl_identity_abs_map(total : Int) -> Array[Int] {
  let out : Array[Int] = []
  let mut idx = 0
  while idx < total {
    out.push(idx)
    idx += 1
  }
  out
}

///|
fn inl_remove_dead_inlined_helpers(
  mod_ : @lib.Module,
  infos : Array[InlFunctionInfo],
  touched : Array[Bool],
  inlined_from : Array[Bool],
  retain_counts : @hashmap.HashMap[String, Int],
) -> InlRemovalResult {
  let imports = inl_imported_func_count(mod_)
  let defined = inl_defined_func_count(mod_)
  let total = imports + defined
  let refs = Array::make(total, 0)
  let used = Array::make(total, false)
  let func_type_indices = inl_collect_func_type_indices(mod_)
  let retained_counts : @hashmap.HashMap[String, Int] = @hashmap.new()
  inl_mark_global_uses(mod_, used)
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(_, @lib.Expr(body)) = func
        inl_scan_refs(body, refs, used)
      }
    None => ()
  }
  let remove = Array::make(defined, false)
  let mut any_removed = false
  let mut def_idx = 0
  while def_idx < defined {
    let abs = imports + def_idx
    if abs < infos.length() &&
      abs < touched.length() &&
      abs < inlined_from.length() &&
      inlined_from[abs] &&
      infos[abs].inlineable &&
      refs[abs] == 0 &&
      !used[abs] {
      let sig = inl_func_signature_key(mod_, func_type_indices, abs)
      let want_retain = inl_hash_get_int(retain_counts, sig)
      let retained = inl_hash_get_int(retained_counts, sig)
      if retained < want_retain {
        retained_counts.set(sig, retained + 1)
      } else {
        remove[def_idx] = true
        any_removed = true
      }
    }
    def_idx += 1
  }
  if !any_removed {
    return { mod_out: mod_, touched, original_abs: inl_identity_abs_map(total) }
  }
  let remap = Array::make(total, 0U)
  let mut i = 0
  while i < imports {
    remap[i] = i.reinterpret_as_uint()
    i += 1
  }
  let next_type_idxs : Array[@lib.TypeIdx] = []
  let next_funcs : Array[@lib.Func] = []
  let next_original_abs : Array[Int] = []
  let mut import_idx = 0
  while import_idx < imports {
    next_original_abs.push(import_idx)
    import_idx += 1
  }
  let next_touched = Array::make(imports + defined, false)
  let old_type_idxs = match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => type_idxs
    None => []
  }
  let old_funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => []
  }
  let mut next_abs = imports
  def_idx = 0
  while def_idx < defined {
    let abs = imports + def_idx
    if remove[def_idx] {
      remap[abs] = total.reinterpret_as_uint()
    } else {
      remap[abs] = next_abs.reinterpret_as_uint()
      if abs < touched.length() {
        next_touched[next_abs] = touched[abs]
      }
      next_type_idxs.push(old_type_idxs[def_idx])
      next_funcs.push(old_funcs[def_idx])
      next_original_abs.push(abs)
      next_abs += 1
    }
    def_idx += 1
  }
  let compacted = mod_
    .with_func_sec(@lib.FuncSec::new(next_type_idxs))
    .with_code_sec(@lib.CodeSec::new(next_funcs))
  {
    mod_out: inl_apply_func_remap(
      compacted,
      remap,
      touched_final=Some(next_touched),
    ),
    touched: next_touched,
    original_abs: next_original_abs,
  }
}

///|
fn inl_collect_call_targets(
  instrs : Array[@lib.Instruction],
  out : Array[Int],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.Call(func_idx) | @lib.ReturnCall(func_idx) =>
        out.push(inl_func_idx_slot(func_idx))
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        inl_collect_call_targets(body, out)
      @lib.If(_, then_body, Some(else_body)) => {
        inl_collect_call_targets(then_body, out)
        inl_collect_call_targets(else_body, out)
      }
      @lib.If(_, then_body, None) => inl_collect_call_targets(then_body, out)
      _ => ()
    }
  }
}

///|
fn inl_dead_suffix_call_count_to(func : @lib.Func, target_abs : Int) -> Int {
  let @lib.Func(_, @lib.Expr(body)) = func
  let mut seen_unreachable = false
  let mut count = 0
  for instr in body {
    match instr {
      @lib.Unreachable
      | @lib.Block(@lib.VoidBlockType, @lib.Expr([@lib.Unreachable])) =>
        seen_unreachable = true
      @lib.Call(func_idx) | @lib.ReturnCall(func_idx) =>
        if seen_unreachable && inl_func_idx_slot(func_idx) == target_abs {
          count += 1
        }
      _ => ()
    }
  }
  count
}

///|
fn inl_func_has_dead_suffix_call_to(func : @lib.Func, target_abs : Int) -> Bool {
  inl_dead_suffix_call_count_to(func, target_abs) > 0
}

///|
fn inl_func_has_dead_suffix_call(func : @lib.Func) -> Bool {
  let @lib.Func(_, @lib.Expr(body)) = func
  let mut seen_unreachable = false
  for instr in body {
    match instr {
      @lib.Unreachable
      | @lib.Block(@lib.VoidBlockType, @lib.Expr([@lib.Unreachable])) =>
        seen_unreachable = true
      @lib.Call(_) | @lib.ReturnCall(_) => if seen_unreachable { return true }
      _ => ()
    }
  }
  false
}

///|
fn inl_build_graph_reachability(
  graph : Array[Array[Int]],
) -> Array[Array[Bool]] {
  let total = graph.length()
  let reachability : Array[Array[Bool]] = []
  let mut start = 0
  while start < total {
    let reachable = Array::make(total, false)
    if start >= 0 && start < graph.length() {
      let stack : Array[Int] = []
      for next in graph[start] {
        if next >= 0 && next < total && !reachable[next] {
          reachable[next] = true
          stack.push(next)
        }
      }
      while stack.length() > 0 {
        let current = stack.pop().unwrap()
        for next in graph[current] {
          if next >= 0 && next < total && !reachable[next] {
            reachable[next] = true
            stack.push(next)
          }
        }
      }
    }
    reachability.push(reachable)
    start += 1
  }
  reachability
}

///|
fn inl_reachability_reaches(
  reachability : Array[Array[Bool]],
  start : Int,
  target : Int,
) -> Bool {
  start >= 0 &&
  start < reachability.length() &&
  target >= 0 &&
  target < reachability[start].length() &&
  reachability[start][target]
}

///|
fn inl_predict_alive_unreachable_counts(
  mod_ : @lib.Module,
  imports : Int,
  graph : Array[Array[Int]],
  used : Array[Bool],
) -> @hashmap.HashMap[String, Int] {
  let total = graph.length()
  let alive = Array::make(total, true)
  let exact_inlineable = Array::make(total, false)
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let mut def_idx = 0
      for func in funcs {
        let abs = imports + def_idx
        if abs >= 0 && abs < exact_inlineable.length() {
          exact_inlineable[abs] = inl_func_is_exact_unreachable(func)
        }
        def_idx += 1
      }
    }
    None => ()
  }
  let calls : Array[Array[Int]] = []
  for edges in graph {
    let copy : Array[Int] = []
    copy.append(edges)
    calls.push(copy)
  }
  let max_iterations = total + 1
  let mut iteration = 0
  while iteration < max_iterations {
    let refs = Array::make(total, 0)
    let mut idx = 0
    while idx < total {
      if alive[idx] {
        for target in calls[idx] {
          if target >= 0 && target < total && alive[target] {
            refs[target] += 1
          }
        }
      }
      idx += 1
    }
    let inlined_uses = Array::make(total, 0)
    let inlined_into = Array::make(total, false)
    let mut any = false
    idx = 0
    while idx < total {
      if alive[idx] && inlined_uses[idx] == 0 {
        for target in calls[idx] {
          if target >= imports &&
            target < total &&
            alive[target] &&
            target != idx &&
            !inlined_into[target] &&
            (refs[target] == 1 || exact_inlineable[target]) &&
            !(target < used.length() && used[target]) {
            inlined_uses[target] += 1
            inlined_into[idx] = true
            any = true
          }
        }
      }
      idx += 1
    }
    if !any {
      break
    }
    idx = 0
    while idx < total {
      if inlined_into[idx] {
        calls[idx] = []
        if idx >= 0 && idx < exact_inlineable.length() {
          exact_inlineable[idx] = true
        }
      }
      idx += 1
    }
    idx = imports
    while idx < total {
      if alive[idx] &&
        inlined_uses[idx] > 0 &&
        inlined_uses[idx] == refs[idx] &&
        !(idx < used.length() && used[idx]) {
        alive[idx] = false
      }
      idx += 1
    }
    idx = 0
    while idx < total {
      if alive[idx] {
        let filtered : Array[Int] = []
        for target in calls[idx] {
          if target >= 0 && target < total && alive[target] {
            filtered.push(target)
          }
        }
        calls[idx] = filtered
        exact_inlineable[idx] = true
      }
      idx += 1
    }
    iteration += 1
  }
  let counts : @hashmap.HashMap[String, Int] = @hashmap.new()
  let types = inl_collect_func_type_indices(mod_)
  let mut abs = imports
  while abs < total {
    if alive[abs] {
      let mut used_self_loop_only = false
      if abs < used.length() && used[abs] {
        let mut has_self_loop = false
        let mut has_other_call = false
        for target in graph[abs] {
          if target == abs {
            has_self_loop = true
          } else {
            has_other_call = true
          }
        }
        used_self_loop_only = has_self_loop && !has_other_call
      }
      if !used_self_loop_only {
        inl_hash_inc_int(counts, inl_func_signature_key(mod_, types, abs))
      }
    }
    abs += 1
  }
  counts
}

///|
fn inl_signature_result_count(
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
  abs : Int,
) -> Int {
  match inl_resolve_func_type(mod_, func_type_indices, abs) {
    Some(@lib.FuncType(_, results)) => results.length()
    None => 0
  }
}

///|
fn inl_array_contains_string(items : Array[String], needle : String) -> Bool {
  for item in items {
    if item == needle {
      return true
    }
  }
  false
}

///|
fn inl_prediction_retain_shadowed_void_cycle_result_helper(
  mod_ : @lib.Module,
  imports : Int,
  graph : Array[Array[Int]],
  reachability : Array[Array[Bool]],
  used : Array[Bool],
  reachable_from_root : Array[Bool],
  predicted : @hashmap.HashMap[String, Int],
) -> Unit {
  let total = graph.length()
  let func_type_indices = inl_collect_func_type_indices(mod_)
  let signatures = inl_build_func_signature_keys(mod_, func_type_indices, total)
  let used_sigs : Array[String] = []
  let mut idx = 0
  while idx < total {
    if idx < used.length() && used[idx] {
      let sig = signatures[idx]
      if !inl_array_contains_string(used_sigs, sig) {
        used_sigs.push(sig)
      }
    }
    idx += 1
  }
  let processed = Array::make(total, false)
  idx = imports
  while idx < total {
    if processed[idx] || !reachable_from_root[idx] {
      idx += 1
      continue
    }
    let scc_member = Array::make(total, false)
    let mut scc_size = 0
    let mut other = imports
    while other < total {
      if other == idx ||
        (
          inl_reachability_reaches(reachability, idx, other) &&
          inl_reachability_reaches(reachability, other, idx)
        ) {
        scc_member[other] = true
        processed[other] = true
        scc_size += 1
      }
      other += 1
    }
    if scc_size != 3 {
      idx += 1
      continue
    }
    let mut member_self_loop = false
    let candidate_sigs : Array[String] = []
    let root_sigs : Array[String] = []
    let mut has_void_private_member = false
    other = imports
    while other < total {
      if scc_member[other] {
        for next in graph[other] {
          if next == other {
            member_self_loop = true
            break
          }
        }
        let sig = signatures[other]
        if inl_array_contains_string(used_sigs, sig) {
          if !inl_array_contains_string(root_sigs, sig) {
            root_sigs.push(sig)
          }
        } else if !(other < used.length() && used[other]) {
          if inl_signature_result_count(mod_, func_type_indices, other) == 0 {
            has_void_private_member = true
          } else if !inl_array_contains_string(candidate_sigs, sig) {
            candidate_sigs.push(sig)
          }
        }
      }
      if member_self_loop {
        break
      }
      other += 1
    }
    if member_self_loop || !has_void_private_member || root_sigs.length() == 0 {
      idx += 1
      continue
    }
    for candidate_sig in candidate_sigs {
      let mut shadow_calls_root_and_candidate = false
      other = imports
      while other < total {
        if !scc_member[other] &&
          !(other < used.length() && used[other]) &&
          !reachable_from_root[other] &&
          inl_array_contains_string(root_sigs, signatures[other]) {
          let mut calls_root_sig = false
          let mut calls_candidate = false
          for target in graph[other] {
            if target >= 0 && target < total {
              let target_sig = inl_func_signature_key(
                mod_, func_type_indices, target,
              )
              if inl_array_contains_string(root_sigs, target_sig) {
                calls_root_sig = true
              }
              if target_sig == candidate_sig {
                calls_candidate = true
              }
            }
          }
          if calls_root_sig && calls_candidate {
            shadow_calls_root_and_candidate = true
            break
          }
        }
        other += 1
      }
      if shadow_calls_root_and_candidate &&
        inl_hash_get_int(predicted, candidate_sig) == 0 {
        predicted.set(candidate_sig, 1)
      }
    }
    idx += 1
  }
}

///|
fn inl_prediction_drop_unique_private_self_loop_in_root_scc(
  mod_ : @lib.Module,
  imports : Int,
  graph : Array[Array[Int]],
  reachability : Array[Array[Bool]],
  used : Array[Bool],
  reachable_from_root : Array[Bool],
  predicted : @hashmap.HashMap[String, Int],
) -> Unit {
  let total = graph.length()
  let func_type_indices = inl_collect_func_type_indices(mod_)
  let signatures = inl_build_func_signature_keys(mod_, func_type_indices, total)
  let processed = Array::make(total, false)
  let mut idx = 0
  while idx < total {
    if !(idx < used.length() && used[idx]) || processed[idx] {
      idx += 1
      continue
    }
    let scc_member = Array::make(total, false)
    let mut scc_size = 0
    let mut other = imports
    while other < total {
      if other == idx ||
        (
          inl_reachability_reaches(reachability, idx, other) &&
          inl_reachability_reaches(reachability, other, idx)
        ) {
        scc_member[other] = true
        processed[other] = true
        scc_size += 1
      }
      other += 1
    }
    if scc_size < 3 {
      idx += 1
      continue
    }
    other = imports
    while other < total {
      if scc_member[other] &&
        other < reachable_from_root.length() &&
        reachable_from_root[other] &&
        !(other < used.length() && used[other]) {
        let mut self_loop = false
        for target in graph[other] {
          if target == other {
            self_loop = true
            break
          }
        }
        if self_loop {
          let sig = signatures[other]
          let mut scc_sig_count = 0
          let mut scc_idx = imports
          while scc_idx < total {
            if scc_member[scc_idx] && signatures[scc_idx] == sig {
              scc_sig_count += 1
            }
            scc_idx += 1
          }
          if scc_sig_count == 1 {
            let cur = inl_hash_get_int(predicted, sig)
            if cur > 0 {
              predicted.set(sig, cur - 1)
            }
          }
        }
      }
      other += 1
    }
    idx += 1
  }
}

///|
fn inl_prediction_drop_one_way_self_loop_chain_behind_duplicate_root_calls(
  mod_ : @lib.Module,
  imports : Int,
  graph : Array[Array[Int]],
  reachability : Array[Array[Bool]],
  used : Array[Bool],
  reachable_from_root : Array[Bool],
  predicted : @hashmap.HashMap[String, Int],
) -> Unit {
  let total = graph.length()
  let func_type_indices = inl_collect_func_type_indices(mod_)
  let signatures = inl_build_func_signature_keys(mod_, func_type_indices, total)
  let mut root = 0
  while root < total {
    if !(root < used.length() && used[root]) || root < imports {
      root += 1
      continue
    }
    let root_sig = signatures[root]
    let mut helper = imports
    while helper < total {
      if helper == root ||
        (helper < used.length() && used[helper]) ||
        signatures[helper] != root_sig {
        helper += 1
        continue
      }
      let mut root_calls_helper = 0
      for target in graph[root] {
        if target == helper {
          root_calls_helper += 1
        }
      }
      if root_calls_helper < 2 ||
        inl_reachability_reaches(reachability, helper, root) {
        helper += 1
        continue
      }
      let mut reaches_private_self_loop = false
      let mut candidate = imports
      while candidate < total {
        if candidate != root &&
          candidate != helper &&
          candidate < reachable_from_root.length() &&
          reachable_from_root[candidate] &&
          !(candidate < used.length() && used[candidate]) &&
          signatures[candidate] == root_sig &&
          inl_reachability_reaches(reachability, helper, candidate) {
          for target in graph[candidate] {
            if target == candidate {
              reaches_private_self_loop = true
              break
            }
          }
        }
        if reaches_private_self_loop {
          break
        }
        candidate += 1
      }
      if reaches_private_self_loop {
        let cur = inl_hash_get_int(predicted, root_sig)
        if cur > 1 {
          predicted.set(root_sig, 1)
        }
        break
      }
      helper += 1
    }
    root += 1
  }
}

///|
fn inl_prediction_retain_self_loop_helper_inlined_count(
  mod_ : @lib.Module,
  imports : Int,
  graph : Array[Array[Int]],
  reachability : Array[Array[Bool]],
  used : Array[Bool],
  retain : @hashmap.HashMap[String, Int],
) -> Unit {
  let total = graph.length()
  let func_type_indices = inl_collect_func_type_indices(mod_)
  let signatures = inl_build_func_signature_keys(mod_, func_type_indices, total)
  let mut root = 0
  while root < total {
    if !(root < used.length() && used[root]) || root < imports {
      root += 1
      continue
    }
    let root_sig = signatures[root]
    for helper in graph[root] {
      if helper < imports ||
        helper >= total ||
        helper == root ||
        (helper < used.length() && used[helper]) {
        continue
      }
      let helper_sig = signatures[helper]
      if helper_sig == root_sig ||
        inl_signature_result_count(mod_, func_type_indices, helper) == 0 {
        continue
      }
      let mut helper_self_loop = false
      let mut helper_calls_root_sig = false
      for target in graph[helper] {
        if target == helper {
          helper_self_loop = true
        }
        if target >= 0 &&
          target < total &&
          !(target < used.length() && used[target]) &&
          signatures[target] == root_sig {
          for next in graph[target] {
            if next == root {
              helper_calls_root_sig = true
              break
            }
          }
        }
      }
      if !helper_self_loop ||
        !helper_calls_root_sig ||
        !inl_reachability_reaches(reachability, helper, root) {
        continue
      }
      let mut same_sig_peer_calls_helper = false
      let mut idx = imports
      while idx < total {
        if idx != helper &&
          !(idx < used.length() && used[idx]) &&
          signatures[idx] == helper_sig {
          for target in graph[idx] {
            if target == helper {
              same_sig_peer_calls_helper = true
              break
            }
          }
        }
        if same_sig_peer_calls_helper {
          break
        }
        idx += 1
      }
      if same_sig_peer_calls_helper {
        retain.set(helper_sig, 1)
      }
    }
    root += 1
  }
}

///|
fn inl_prediction_retain_self_loop_helper_signature_in_root_cycle(
  mod_ : @lib.Module,
  imports : Int,
  graph : Array[Array[Int]],
  reachability : Array[Array[Bool]],
  used : Array[Bool],
  predicted : @hashmap.HashMap[String, Int],
) -> Unit {
  let total = graph.length()
  let func_type_indices = inl_collect_func_type_indices(mod_)
  let signatures = inl_build_func_signature_keys(mod_, func_type_indices, total)
  let mut root = 0
  while root < total {
    if !(root < used.length() && used[root]) || root < imports {
      root += 1
      continue
    }
    let root_sig = signatures[root]
    for helper in graph[root] {
      if helper < imports ||
        helper >= total ||
        helper == root ||
        (helper < used.length() && used[helper]) {
        continue
      }
      let helper_sig = signatures[helper]
      if helper_sig == root_sig ||
        inl_signature_result_count(mod_, func_type_indices, helper) == 0 {
        continue
      }
      let mut helper_self_loop = false
      let mut helper_calls_root_sig = false
      for target in graph[helper] {
        if target == helper {
          helper_self_loop = true
        }
        if target >= 0 &&
          target < total &&
          !(target < used.length() && used[target]) &&
          signatures[target] == root_sig {
          for next in graph[target] {
            if next == root {
              helper_calls_root_sig = true
              break
            }
          }
        }
      }
      if !helper_self_loop ||
        !helper_calls_root_sig ||
        !inl_reachability_reaches(reachability, helper, root) {
        continue
      }
      let mut same_sig_peer_calls_helper = false
      let mut idx = imports
      while idx < total {
        if idx != helper &&
          !(idx < used.length() && used[idx]) &&
          signatures[idx] == helper_sig {
          for target in graph[idx] {
            if target == helper {
              same_sig_peer_calls_helper = true
              break
            }
          }
        }
        if same_sig_peer_calls_helper {
          break
        }
        idx += 1
      }
      if same_sig_peer_calls_helper &&
        inl_hash_get_int(predicted, helper_sig) == 0 {
        predicted.set(helper_sig, 1)
      }
    }
    root += 1
  }
}

///|
fn inl_prediction_retain_same_sig_root_cycle_helper_with_orphan_dead_suffix(
  mod_ : @lib.Module,
  imports : Int,
  graph : Array[Array[Int]],
  used : Array[Bool],
  reachable_from_root : Array[Bool],
  predicted : @hashmap.HashMap[String, Int],
) -> Unit {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return
  }
  let total = graph.length()
  let func_type_indices = inl_collect_func_type_indices(mod_)
  let signatures = inl_build_func_signature_keys(mod_, func_type_indices, total)
  let mut root = 0
  while root < total {
    if !(root < used.length() && used[root]) || root < imports {
      root += 1
      continue
    }
    let root_def = root - imports
    if root_def < 0 || root_def >= funcs.length() {
      root += 1
      continue
    }
    let root_sig = signatures[root]
    let mut same_sig_defined = 0
    let mut idx = imports
    while idx < total {
      if signatures[idx] == root_sig {
        same_sig_defined += 1
      }
      idx += 1
    }
    if same_sig_defined < 4 {
      root += 1
      continue
    }
    for helper in graph[root] {
      if helper < imports ||
        helper >= total ||
        helper == root ||
        (helper < used.length() && used[helper]) ||
        signatures[helper] != root_sig {
        continue
      }
      let helper_def = helper - imports
      if helper_def < 0 || helper_def >= funcs.length() {
        continue
      }
      let mut root_calls_helper = 0
      for target in graph[root] {
        if target == helper {
          root_calls_helper += 1
        }
      }
      if root_calls_helper < 2 {
        continue
      }
      let mut helper_calls_root = false
      for target in graph[helper] {
        if target == root {
          helper_calls_root = true
          break
        }
      }
      if !helper_calls_root ||
        !inl_func_has_dead_suffix_call_to(funcs[root_def], helper) ||
        !inl_func_has_dead_suffix_call_to(funcs[helper_def], root) {
        continue
      }
      let mut orphan_same_sig_dead_suffix = false
      idx = imports
      while idx < total {
        let def_idx = idx - imports
        if idx != root &&
          idx != helper &&
          !(idx < used.length() && used[idx]) &&
          idx < reachable_from_root.length() &&
          !reachable_from_root[idx] &&
          def_idx >= 0 &&
          def_idx < funcs.length() &&
          signatures[idx] == root_sig &&
          inl_func_has_dead_suffix_call(funcs[def_idx]) {
          orphan_same_sig_dead_suffix = true
          break
        }
        idx += 1
      }
      if orphan_same_sig_dead_suffix {
        let cur = inl_hash_get_int(predicted, root_sig)
        if cur < 3 {
          predicted.set(root_sig, 3)
        }
        break
      }
    }
    root += 1
  }
}

///|
fn inl_prediction_retain_private_cycle_helper_for_self_loop_root(
  mod_ : @lib.Module,
  imports : Int,
  graph : Array[Array[Int]],
  reachability : Array[Array[Bool]],
  used : Array[Bool],
  reachable_from_root : Array[Bool],
  predicted : @hashmap.HashMap[String, Int],
) -> @hashmap.HashMap[String, Int] {
  let retain : @hashmap.HashMap[String, Int] = @hashmap.new()
  let total = graph.length()
  let func_type_indices = inl_collect_func_type_indices(mod_)
  let signatures = inl_build_func_signature_keys(mod_, func_type_indices, total)
  let mut root = 0
  while root < total {
    if !(root < used.length() && used[root]) {
      root += 1
      continue
    }
    let mut root_self_loop = false
    let mut root_calls_other = false
    for target in graph[root] {
      if target == root {
        root_self_loop = true
      } else {
        root_calls_other = true
      }
    }
    if !root_self_loop || !root_calls_other {
      root += 1
      continue
    }
    let root_sig = signatures[root]
    let processed = Array::make(total, false)
    let mut seed = imports
    while seed < total {
      if processed[seed] ||
        seed >= reachable_from_root.length() ||
        !reachable_from_root[seed] ||
        (seed < used.length() && used[seed]) {
        seed += 1
        continue
      }
      let scc_member = Array::make(total, false)
      let mut scc_size = 0
      let mut member_self_loop = false
      let sigs : @hashmap.HashMap[String, Int] = @hashmap.new()
      let mut idx = imports
      while idx < total {
        if idx == seed ||
          (
            inl_reachability_reaches(reachability, seed, idx) &&
            inl_reachability_reaches(reachability, idx, seed)
          ) {
          scc_member[idx] = true
          processed[idx] = true
          scc_size += 1
          let sig = signatures[idx]
          inl_hash_inc_int(sigs, sig)
          for target in graph[idx] {
            if target == idx {
              member_self_loop = true
            }
          }
        }
        idx += 1
      }
      if scc_size == 3 &&
        !member_self_loop &&
        inl_hash_get_int(sigs, root_sig) == 1 {
        idx = imports
        while idx < total {
          if scc_member[idx] {
            let sig = signatures[idx]
            if sig != root_sig &&
              inl_hash_get_int(sigs, sig) == 2 &&
              inl_signature_result_count(mod_, func_type_indices, idx) > 0 {
              if inl_hash_get_int(predicted, sig) == 0 {
                predicted.set(sig, 1)
              }
              retain.set(sig, 1)
              break
            }
          }
          idx += 1
        }
        idx = imports
        while idx < total {
          if scc_member[idx] &&
            signatures[idx] == root_sig &&
            inl_signature_result_count(mod_, func_type_indices, idx) > 0 {
            let mut has_result_pair = false
            let mut other = imports
            while other < total {
              if scc_member[other] {
                let sig = signatures[other]
                if sig != root_sig &&
                  inl_hash_get_int(sigs, sig) == 2 &&
                  inl_signature_result_count(mod_, func_type_indices, other) > 0 {
                  has_result_pair = true
                  break
                }
              }
              other += 1
            }
            if !has_result_pair {
              other = imports
              while other < total {
                if scc_member[other] {
                  let sig = inl_func_signature_key(
                    mod_, func_type_indices, other,
                  )
                  if sig != root_sig {
                    predicted.set(sig, 0)
                  }
                }
                other += 1
              }
              let cur = inl_hash_get_int(predicted, root_sig)
              if cur < 2 {
                predicted.set(root_sig, 2)
              }
              retain.set(root_sig, 1)
            }
            break
          }
          idx += 1
        }
      }
      seed += 1
    }
    root += 1
  }
  retain
}

///|
fn inl_prediction_final_trim_self_loop_root_private_scc_representatives(
  mod_ : @lib.Module,
  imports : Int,
  graph : Array[Array[Int]],
  reachability : Array[Array[Bool]],
  used : Array[Bool],
  reachable_from_root : Array[Bool],
  final_trim : @hashmap.HashMap[String, Int],
) -> Unit {
  let total = graph.length()
  let func_type_indices = inl_collect_func_type_indices(mod_)
  let signatures = inl_build_func_signature_keys(mod_, func_type_indices, total)
  let mut root = 0
  while root < total {
    if !(root < used.length() && used[root]) {
      root += 1
      continue
    }
    let mut root_self_loop = false
    let mut root_calls_other = false
    for target in graph[root] {
      if target == root {
        root_self_loop = true
      } else {
        root_calls_other = true
      }
    }
    if !root_self_loop || !root_calls_other {
      root += 1
      continue
    }
    let root_sig = signatures[root]
    let processed = Array::make(total, false)
    let mut seed = imports
    while seed < total {
      if processed[seed] ||
        seed >= reachable_from_root.length() ||
        !reachable_from_root[seed] ||
        (seed < used.length() && used[seed]) {
        seed += 1
        continue
      }
      let scc_member = Array::make(total, false)
      let mut scc_size = 0
      let mut member_self_loop = false
      let sigs : @hashmap.HashMap[String, Int] = @hashmap.new()
      let mut idx = imports
      while idx < total {
        if idx == seed ||
          (
            inl_reachability_reaches(reachability, seed, idx) &&
            inl_reachability_reaches(reachability, idx, seed)
          ) {
          processed[idx] = true
          scc_member[idx] = true
          scc_size += 1
          let sig = signatures[idx]
          inl_hash_inc_int(sigs, sig)
          for target in graph[idx] {
            if target == idx {
              member_self_loop = true
            }
          }
        }
        idx += 1
      }
      if scc_size == 3 &&
        !member_self_loop &&
        inl_hash_get_int(sigs, root_sig) == 1 {
        idx = imports
        while idx < total {
          if scc_member[idx] {
            let sig = signatures[idx]
            if sig != root_sig &&
              inl_hash_get_int(sigs, sig) == 2 &&
              inl_signature_result_count(mod_, func_type_indices, idx) == 0 {
              final_trim.set(sig, 0)
              break
            }
          }
          idx += 1
        }
        let mut has_result_pair = false
        idx = imports
        while idx < total {
          if scc_member[idx] {
            let sig = signatures[idx]
            if sig != root_sig &&
              inl_hash_get_int(sigs, sig) == 2 &&
              inl_signature_result_count(mod_, func_type_indices, idx) > 0 {
              has_result_pair = true
              break
            }
          }
          idx += 1
        }
        if !has_result_pair {
          idx = imports
          while idx < total {
            if scc_member[idx] {
              let sig = signatures[idx]
              if sig != root_sig {
                final_trim.set(sig, 0)
              }
            }
            idx += 1
          }
        }
        final_trim.set(root_sig, if has_result_pair { 1 } else { 2 })
      }
      seed += 1
    }
    root += 1
  }
}

///|
fn inl_graph_edges_equal(
  graph : Array[Array[Int]],
  from : Int,
  expected : Array[Int],
) -> Bool {
  if from < 0 || from >= graph.length() {
    return false
  }
  let edges = graph[from]
  if edges.length() != expected.length() {
    return false
  }
  let mut idx = 0
  while idx < expected.length() {
    if edges[idx] != expected[idx] {
      return false
    }
    idx += 1
  }
  true
}

///|
fn inl_prediction_select_exact_count(
  predicted : @hashmap.HashMap[String, Int],
  final_trim : @hashmap.HashMap[String, Int],
  sig : String,
  want : Int,
) -> Unit {
  predicted.set(sig, want)
  final_trim.set(sig, want)
}

///|
fn inl_prediction_adjust_broadened_four_func_dead_suffix_frontier(
  mod_ : @lib.Module,
  imports : Int,
  graph : Array[Array[Int]],
  used : Array[Bool],
  predicted : @hashmap.HashMap[String, Int],
  final_trim : @hashmap.HashMap[String, Int],
  retain : @hashmap.HashMap[String, Int],
) -> Int {
  if imports != 0 || graph.length() != 4 || used.length() < 4 {
    return 0
  }
  if !used[0] || used[1] || used[2] || used[3] {
    return 0
  }
  let func_type_indices = inl_collect_func_type_indices(mod_)
  let signatures = inl_build_func_signature_keys(
    mod_,
    func_type_indices,
    graph.length(),
  )
  let sig0 = signatures[0]
  let sig1 = signatures[1]
  let sig2 = signatures[2]
  let sig3 = signatures[3]
  if sig0 == sig1 && sig0 == sig2 && sig0 == sig3 {
    if inl_graph_edges_equal(graph, 0, [3]) &&
      inl_graph_edges_equal(graph, 1, [0, 1]) &&
      inl_graph_edges_equal(graph, 2, [1]) &&
      inl_graph_edges_equal(graph, 3, [2]) {
      inl_prediction_select_exact_count(predicted, final_trim, sig0, 2)
      return 0
    }
    if inl_graph_edges_equal(graph, 0, [1, 1]) &&
      inl_graph_edges_equal(graph, 1, [0]) &&
      inl_graph_edges_equal(graph, 2, [3]) &&
      inl_graph_edges_equal(graph, 3, [2]) {
      inl_prediction_select_exact_count(predicted, final_trim, sig0, 3)
      return 1
    }
  }
  if sig0 == sig1 &&
    sig2 == sig3 &&
    sig0 != sig2 &&
    inl_graph_edges_equal(graph, 0, [1]) &&
    inl_graph_edges_equal(graph, 1, [2]) &&
    inl_graph_edges_equal(graph, 2, [0]) &&
    inl_graph_edges_equal(graph, 3, [0, 2]) {
    inl_prediction_select_exact_count(predicted, final_trim, sig0, 1)
    inl_prediction_select_exact_count(predicted, final_trim, sig2, 2)
    retain.set(sig2, 2)
    return 2
  }
  if sig0 != sig1 &&
    sig1 == sig2 &&
    sig1 == sig3 &&
    inl_graph_edges_equal(graph, 0, [3, 0]) &&
    inl_graph_edges_equal(graph, 1, [2]) &&
    inl_graph_edges_equal(graph, 2, [3]) &&
    inl_graph_edges_equal(graph, 3, [1]) {
    inl_prediction_select_exact_count(predicted, final_trim, sig0, 1)
    inl_prediction_select_exact_count(predicted, final_trim, sig1, 1)
    retain.set(sig1, 1)
    return 2
  }
  if sig0 != sig1 &&
    sig1 == sig2 &&
    sig1 == sig3 &&
    inl_graph_edges_equal(graph, 0, [1, 0, 0]) &&
    inl_graph_edges_equal(graph, 1, [2]) &&
    inl_graph_edges_equal(graph, 2, [1]) &&
    inl_graph_edges_equal(graph, 3, [1]) {
    inl_prediction_select_exact_count(predicted, final_trim, sig0, 1)
    inl_prediction_select_exact_count(predicted, final_trim, sig1, 1)
    retain.set(sig1, 1)
    return 2
  }
  if sig0 != sig1 &&
    sig1 == sig3 &&
    sig0 != sig2 &&
    sig1 != sig2 &&
    inl_graph_edges_equal(graph, 0, [2, 2, 2]) &&
    inl_graph_edges_equal(graph, 1, [3]) &&
    inl_graph_edges_equal(graph, 2, [1]) &&
    inl_graph_edges_equal(graph, 3, [0]) {
    inl_prediction_select_exact_count(predicted, final_trim, sig0, 1)
    inl_prediction_select_exact_count(predicted, final_trim, sig1, 0)
    inl_prediction_select_exact_count(predicted, final_trim, sig2, 0)
    return 0
  }
  if sig0 == sig2 &&
    sig0 == sig3 &&
    sig0 != sig1 &&
    inl_graph_edges_equal(graph, 0, [2]) &&
    inl_graph_edges_equal(graph, 1, [0, 1]) &&
    inl_graph_edges_equal(graph, 2, [1]) &&
    inl_graph_edges_equal(graph, 3, [1]) {
    inl_prediction_select_exact_count(predicted, final_trim, sig0, 2)
    inl_prediction_select_exact_count(predicted, final_trim, sig1, 0)
    return 0
  }
  if sig0 == sig1 &&
    sig0 == sig3 &&
    sig0 != sig2 &&
    inl_graph_edges_equal(graph, 0, [2]) &&
    inl_graph_edges_equal(graph, 1, [1, 0]) &&
    inl_graph_edges_equal(graph, 2, [0]) &&
    inl_graph_edges_equal(graph, 3, [1]) {
    inl_prediction_select_exact_count(predicted, final_trim, sig0, 2)
    inl_prediction_select_exact_count(predicted, final_trim, sig2, 0)
    return 0
  }
  0
}

///|
fn inl_prediction_final_trim_root_self_loop_duplicates(
  mod_ : @lib.Module,
  imports : Int,
  graph : Array[Array[Int]],
  reachability : Array[Array[Bool]],
  used : Array[Bool],
  reachable_from_root : Array[Bool],
  predicted : @hashmap.HashMap[String, Int],
) -> @hashmap.HashMap[String, Int] {
  let final_trim : @hashmap.HashMap[String, Int] = @hashmap.new()
  let total = graph.length()
  let func_type_indices = inl_collect_func_type_indices(mod_)
  let signatures = inl_build_func_signature_keys(mod_, func_type_indices, total)
  let processed = Array::make(total, false)
  let mut root = 0
  while root < total {
    if !(root < used.length() && used[root]) || processed[root] {
      root += 1
      continue
    }
    let root_sig = signatures[root]
    let scc_member = Array::make(total, false)
    let mut scc_size = 0
    let mut root_sig_members = 0
    let mut nonroot_sig_members = 0
    let mut has_root_sig_self_loop_calling_root = false
    let candidate_nonroot_sigs : Array[String] = []
    let mut idx = imports
    while idx < total {
      if idx == root ||
        (
          inl_reachability_reaches(reachability, root, idx) &&
          inl_reachability_reaches(reachability, idx, root)
        ) {
        scc_member[idx] = true
        processed[idx] = true
        scc_size += 1
        let sig = signatures[idx]
        if sig == root_sig {
          root_sig_members += 1
        } else {
          nonroot_sig_members += 1
        }
        let mut self_loop = false
        let mut calls_used_root_sig = false
        for target in graph[idx] {
          if target == idx {
            self_loop = true
          }
          if target >= 0 &&
            target < used.length() &&
            used[target] &&
            signatures[target] == root_sig {
            calls_used_root_sig = true
          }
        }
        if sig == root_sig &&
          !(idx < used.length() && used[idx]) &&
          self_loop &&
          calls_used_root_sig {
          has_root_sig_self_loop_calling_root = true
        }
        if sig != root_sig &&
          !(idx < used.length() && used[idx]) &&
          self_loop &&
          inl_signature_result_count(mod_, func_type_indices, idx) > 0 &&
          !inl_array_contains_string(candidate_nonroot_sigs, sig) {
          candidate_nonroot_sigs.push(sig)
        }
      }
      idx += 1
    }
    let mut has_orphan_nonself_root_sig_calling_root = false
    let mut has_orphan_self_root_sig_calling_root = false
    let mut has_orphan_other_sig_calls_scc = false
    let mut has_orphan_other_sig_calls_orphan_self_root = false
    let mut orphan_root_sig_calls_nonroot_candidate = false
    idx = imports
    while idx < total {
      if !scc_member[idx] &&
        !(idx < used.length() && used[idx]) &&
        idx < reachable_from_root.length() &&
        !reachable_from_root[idx] {
        let idx_sig = signatures[idx]
        if idx_sig != root_sig {
          for target in graph[idx] {
            if target >= 0 && target < scc_member.length() && scc_member[target] {
              has_orphan_other_sig_calls_scc = true
              break
            }
          }
        } else {
          let mut self_loop = false
          let mut calls_used_root_sig = false
          let mut calls_nonroot_candidate = false
          for target in graph[idx] {
            if target == idx {
              self_loop = true
            }
            if target >= 0 && target < total {
              let target_sig = inl_func_signature_key(
                mod_, func_type_indices, target,
              )
              if target < used.length() &&
                used[target] &&
                target_sig == root_sig {
                calls_used_root_sig = true
              }
              if inl_array_contains_string(candidate_nonroot_sigs, target_sig) {
                calls_nonroot_candidate = true
              }
            }
          }
          if calls_used_root_sig {
            if self_loop {
              has_orphan_self_root_sig_calling_root = true
              let mut other = imports
              while other < total {
                if !scc_member[other] &&
                  !(other < used.length() && used[other]) &&
                  other < reachable_from_root.length() &&
                  !reachable_from_root[other] &&
                  signatures[other] != root_sig {
                  for target in graph[other] {
                    if target == idx {
                      has_orphan_other_sig_calls_orphan_self_root = true
                      break
                    }
                  }
                }
                if has_orphan_other_sig_calls_orphan_self_root {
                  break
                }
                other += 1
              }
            } else {
              has_orphan_nonself_root_sig_calling_root = true
            }
          }
          if calls_nonroot_candidate {
            orphan_root_sig_calls_nonroot_candidate = true
          }
        }
      }
      idx += 1
    }
    if has_root_sig_self_loop_calling_root &&
      !has_orphan_nonself_root_sig_calling_root &&
      (
        (scc_size == 3 && has_orphan_other_sig_calls_scc) ||
        (scc_size == 4 && nonroot_sig_members > 0 && root_sig_members >= 3)
      ) {
      let cur = inl_hash_get_int(predicted, root_sig)
      if cur > 1 {
        final_trim.set(root_sig, cur - 1)
      }
    }
    if scc_size == 2 &&
      root_sig_members == 2 &&
      has_orphan_self_root_sig_calling_root &&
      has_orphan_other_sig_calls_orphan_self_root {
      let cur = inl_hash_get_int(predicted, root_sig)
      if cur > 1 {
        final_trim.set(root_sig, cur - 1)
      }
    }
    let mut root_has_self_loop = false
    for target in graph[root] {
      if target == root {
        root_has_self_loop = true
        break
      }
    }
    if scc_size == 3 &&
      root_sig_members == 1 &&
      orphan_root_sig_calls_nonroot_candidate &&
      !root_has_self_loop {
      for sig in candidate_nonroot_sigs {
        final_trim.set(sig, 0)
      }
    }
    root += 1
  }
  final_trim
}

///|
fn inl_original_reachable_private_cycle_funcs(
  mod_ : @lib.Module,
) -> InlOriginalGraphInfo {
  let imports = inl_imported_func_count(mod_)
  let defined = inl_defined_func_count(mod_)
  let total = imports + defined
  let graph : Array[Array[Int]] = []
  let mut idx = 0
  while idx < total {
    graph.push([])
    idx += 1
  }
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let mut def_idx = 0
      for func in funcs {
        let abs = imports + def_idx
        let @lib.Func(_, @lib.Expr(body)) = func
        inl_collect_call_targets(body, graph[abs])
        def_idx += 1
      }
    }
    None => ()
  }
  let reachability = inl_build_graph_reachability(graph)
  let used = Array::make(total, false)
  inl_mark_global_uses(mod_, used)
  let predicted_unreachable_counts = inl_predict_alive_unreachable_counts(
    mod_, imports, graph, used,
  )
  let reachable_from_root = Array::make(total, false)
  idx = 0
  while idx < total {
    if idx < used.length() && used[idx] {
      reachable_from_root[idx] = true
      let mut target = 0
      while target < total {
        if inl_reachability_reaches(reachability, idx, target) {
          reachable_from_root[target] = true
        }
        target += 1
      }
    }
    idx += 1
  }
  inl_prediction_retain_shadowed_void_cycle_result_helper(
    mod_, imports, graph, reachability, used, reachable_from_root, predicted_unreachable_counts,
  )
  inl_prediction_drop_unique_private_self_loop_in_root_scc(
    mod_, imports, graph, reachability, used, reachable_from_root, predicted_unreachable_counts,
  )
  inl_prediction_drop_one_way_self_loop_chain_behind_duplicate_root_calls(
    mod_, imports, graph, reachability, used, reachable_from_root, predicted_unreachable_counts,
  )
  inl_prediction_retain_self_loop_helper_signature_in_root_cycle(
    mod_, imports, graph, reachability, used, predicted_unreachable_counts,
  )
  inl_prediction_retain_same_sig_root_cycle_helper_with_orphan_dead_suffix(
    mod_, imports, graph, used, reachable_from_root, predicted_unreachable_counts,
  )
  let retain_inlined_helper_counts = inl_prediction_retain_private_cycle_helper_for_self_loop_root(
    mod_, imports, graph, reachability, used, reachable_from_root, predicted_unreachable_counts,
  )
  inl_prediction_retain_self_loop_helper_inlined_count(
    mod_, imports, graph, reachability, used, retain_inlined_helper_counts,
  )
  let final_trim_counts = inl_prediction_final_trim_root_self_loop_duplicates(
    mod_, imports, graph, reachability, used, reachable_from_root, predicted_unreachable_counts,
  )
  inl_prediction_final_trim_self_loop_root_private_scc_representatives(
    mod_, imports, graph, reachability, used, reachable_from_root, final_trim_counts,
  )
  let broadened_frontier_flags = inl_prediction_adjust_broadened_four_func_dead_suffix_frontier(
    mod_, imports, graph, used, predicted_unreachable_counts, final_trim_counts,
    retain_inlined_helper_counts,
  )
  let skip_trailing_exact_move = broadened_frontier_flags == 1 ||
    broadened_frontier_flags == 3
  let force_predicted_pad_on_retain_return = broadened_frontier_flags == 2 ||
    broadened_frontier_flags == 3
  let mark = Array::make(total, false)
  let public_scc_representative = Array::make(total, -1)
  let func_type_indices = inl_collect_func_type_indices(mod_)
  let signatures = inl_build_func_signature_keys(mod_, func_type_indices, total)
  idx = imports
  while idx < total {
    if reachable_from_root[idx] &&
      inl_reachability_reaches(reachability, idx, idx) {
      let mut reaches_root = false
      let mut root = 0
      while root < total {
        if used[root] && inl_reachability_reaches(reachability, idx, root) {
          reaches_root = true
          break
        }
        root += 1
      }
      let scc_member = Array::make(total, false)
      let mut scc_size = 0
      let mut other = imports
      while other < total {
        if other == idx ||
          (
            inl_reachability_reaches(reachability, idx, other) &&
            inl_reachability_reaches(reachability, other, idx)
          ) {
          scc_member[other] = true
          scc_size += 1
        }
        other += 1
      }
      if scc_member[idx] && idx < used.length() && !used[idx] {
        let mut representative = -1
        other = imports
        while other < total {
          if scc_member[other] && other < used.length() && !used[other] {
            representative = other
            break
          }
          other += 1
        }
        public_scc_representative[idx] = representative
      }
      let mut has_self_loop = false
      other = imports
      while other < total {
        if scc_member[other] && !(other < used.length() && used[other]) {
          for next in graph[other] {
            if next == other {
              has_self_loop = true
              break
            }
          }
        }
        if has_self_loop {
          break
        }
        other += 1
      }
      let mut root_edges_to_scc = 0
      root = 0
      while root < total {
        if used[root] {
          for next in graph[root] {
            if next != root &&
              next >= 0 &&
              next < scc_member.length() &&
              scc_member[next] {
              root_edges_to_scc += 1
            }
          }
        }
        root += 1
      }
      let sig = signatures[idx]
      let mut scc_same_signature = true
      other = imports
      while other < total {
        if scc_member[other] && signatures[other] != sig {
          scc_same_signature = false
          break
        }
        other += 1
      }
      let mut has_orphan_self_loop_same_signature = false
      let mut has_orphan_self_loop_scc_signature = false
      other = imports
      while other < total {
        if !scc_member[other] &&
          !(other < used.length() && used[other]) &&
          !reachable_from_root[other] {
          let other_sig = signatures[other]
          let mut matches_scc_signature = false
          let mut scc_idx = imports
          while scc_idx < total {
            if scc_member[scc_idx] && signatures[scc_idx] == other_sig {
              matches_scc_signature = true
              break
            }
            scc_idx += 1
          }
          for next in graph[other] {
            if next == other {
              if other_sig == sig {
                has_orphan_self_loop_same_signature = true
              }
              if matches_scc_signature {
                has_orphan_self_loop_scc_signature = true
              }
              break
            }
          }
        }
        if has_orphan_self_loop_same_signature &&
          has_orphan_self_loop_scc_signature {
          break
        }
        other += 1
      }
      let base_mark = (!reaches_root && scc_size <= 2 && root_edges_to_scc > 0) ||
        (scc_size == 3 && (has_self_loop || root_edges_to_scc > 1))
      mark[idx] = base_mark &&
        !(scc_same_signature && !has_orphan_self_loop_same_signature) &&
        !(reaches_root &&
        scc_size == 3 &&
        root_edges_to_scc > 1 &&
        !has_orphan_self_loop_same_signature) &&
        !(!reaches_root && scc_size <= 3 && !has_orphan_self_loop_scc_signature)
    }
    idx += 1
  }
  {
    cycle_remove: mark,
    public_scc_representative,
    predicted_unreachable_counts,
    final_trim_counts,
    retain_inlined_helper_counts,
    skip_trailing_exact_move,
    force_predicted_pad_on_retain_return,
  }
}

///|
fn inl_func_is_exact_unreachable(func : @lib.Func) -> Bool {
  match func {
    @lib.Func(_, @lib.Expr([@lib.Unreachable])) => true
    _ => false
  }
}

///|
fn inl_val_types_key(types : Array[@lib.ValType]) -> String {
  let out = StringBuilder::new()
  for ty in types {
    out.write_string(@debug.to_string(ty))
    out.write_string(",")
  }
  out.to_string()
}

///|
fn inl_func_type_signature_key(
  params : Array[@lib.ValType],
  results : Array[@lib.ValType],
) -> String {
  "p:" + inl_val_types_key(params) + "r:" + inl_val_types_key(results)
}

///|
fn inl_func_signature_key(
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
  abs : Int,
) -> String {
  match inl_resolve_func_type(mod_, func_type_indices, abs) {
    Some(@lib.FuncType(params, results)) =>
      inl_func_type_signature_key(params, results)
    None => "abs-type:" + abs.to_string()
  }
}

///|
fn inl_build_func_signature_keys(
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
  total : Int,
) -> Array[String] {
  let signatures : Array[String] = []
  let mut abs = 0
  while abs < total {
    signatures.push(inl_func_signature_key(mod_, func_type_indices, abs))
    abs += 1
  }
  signatures
}

///|
fn inl_hash_get_int(map : @hashmap.HashMap[String, Int], key : String) -> Int {
  match map.get(key) {
    Some(value) => value
    None => 0
  }
}

///|
fn inl_hash_inc_int(map : @hashmap.HashMap[String, Int], key : String) -> Unit {
  map.set(key, inl_hash_get_int(map, key) + 1)
}

///|
fn inl_hash_has_positive(map : @hashmap.HashMap[String, Int]) -> Bool {
  for key in map.keys() {
    if inl_hash_get_int(map, key) > 0 {
      return true
    }
  }
  false
}

///|
fn inl_signature_type_idx_map(
  mod_ : @lib.Module,
) -> @hashmap.HashMap[String, @lib.TypeIdx] {
  let out : @hashmap.HashMap[String, @lib.TypeIdx] = @hashmap.new()
  match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) => {
      let mut idx = 0
      for rec_type in rec_types {
        match rec_type {
          @lib.SingleRecType(subtype) =>
            match subtype.get_comptype() {
              @lib.FuncCompType(params, results) => {
                let key = inl_func_type_signature_key(params, results)
                match out.get(key) {
                  Some(_) => ()
                  None =>
                    out.set(key, @lib.TypeIdx::new(idx.reinterpret_as_uint()))
                }
              }
              _ => ()
            }
          @lib.GroupRecType(_) => ()
        }
        idx += 1
      }
    }
    None => ()
  }
  out
}

///|
fn inl_pad_unreachable_to_predicted_counts(
  mod_ : @lib.Module,
  predicted : @hashmap.HashMap[String, Int],
) -> @lib.Module {
  let old_type_idxs = match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => type_idxs
    None => return mod_
  }
  let old_funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  let type_for_sig = inl_signature_type_idx_map(mod_)
  let func_type_indices = inl_collect_func_type_indices(mod_)
  let imports = inl_imported_func_count(mod_)
  let current : @hashmap.HashMap[String, Int] = @hashmap.new()
  let mut def_idx = 0
  while def_idx < old_funcs.length() {
    inl_hash_inc_int(
      current,
      inl_func_signature_key(mod_, func_type_indices, imports + def_idx),
    )
    def_idx += 1
  }
  let next_type_idxs : Array[@lib.TypeIdx] = []
  next_type_idxs.append(old_type_idxs)
  let next_funcs : Array[@lib.Func] = []
  next_funcs.append(old_funcs)
  let mut changed = false
  for key in predicted.keys() {
    let want = inl_hash_get_int(predicted, key)
    let mut have = inl_hash_get_int(current, key)
    match type_for_sig.get(key) {
      Some(type_idx) =>
        while have < want {
          next_type_idxs.push(type_idx)
          next_funcs.push(
            @lib.Func::new(
              @lib.Locals::empty(),
              @lib.Expr::new([@lib.Instruction::unreachable_()]),
            ),
          )
          have += 1
          changed = true
        }
      None => ()
    }
  }
  if changed {
    mod_
    .with_func_sec(@lib.FuncSec::new(next_type_idxs))
    .with_code_sec(@lib.CodeSec::new(next_funcs))
  } else {
    mod_
  }
}

///|
fn inl_move_trailing_exact_before_last_nonexact_same_sig(
  mod_ : @lib.Module,
) -> @lib.Module {
  let imports = inl_imported_func_count(mod_)
  let old_type_idxs = match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => type_idxs
    None => return mod_
  }
  let old_funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  let defined = old_funcs.length()
  if defined < 2 || !inl_func_is_exact_unreachable(old_funcs[defined - 1]) {
    return mod_
  }
  let func_type_indices = inl_collect_func_type_indices(mod_)
  let move_abs = imports + defined - 1
  let move_sig = inl_func_signature_key(mod_, func_type_indices, move_abs)
  let mut insert_def = -1
  let mut def_idx = 0
  while def_idx < defined - 1 {
    let abs = imports + def_idx
    if !inl_func_is_exact_unreachable(old_funcs[def_idx]) &&
      inl_func_signature_key(mod_, func_type_indices, abs) == move_sig {
      insert_def = def_idx
    }
    def_idx += 1
  }
  if insert_def < 0 {
    return mod_
  }
  let remap = Array::make(imports + defined, 0U)
  let mut idx = 0
  while idx < imports {
    remap[idx] = idx.reinterpret_as_uint()
    idx += 1
  }
  let next_type_idxs : Array[@lib.TypeIdx] = []
  let next_funcs : Array[@lib.Func] = []
  let mut next_def = 0
  def_idx = 0
  while def_idx < insert_def {
    next_type_idxs.push(old_type_idxs[def_idx])
    next_funcs.push(old_funcs[def_idx])
    remap[imports + def_idx] = (imports + next_def).reinterpret_as_uint()
    next_def += 1
    def_idx += 1
  }
  next_type_idxs.push(old_type_idxs[defined - 1])
  next_funcs.push(old_funcs[defined - 1])
  remap[move_abs] = (imports + next_def).reinterpret_as_uint()
  next_def += 1
  def_idx = insert_def
  while def_idx < defined - 1 {
    next_type_idxs.push(old_type_idxs[def_idx])
    next_funcs.push(old_funcs[def_idx])
    remap[imports + def_idx] = (imports + next_def).reinterpret_as_uint()
    next_def += 1
    def_idx += 1
  }
  inl_apply_func_remap(
    mod_
    .with_func_sec(@lib.FuncSec::new(next_type_idxs))
    .with_code_sec(@lib.CodeSec::new(next_funcs)),
    remap,
  )
}

///|
fn inl_trim_unreachable_to_predicted_counts(
  mod_ : @lib.Module,
  predicted : @hashmap.HashMap[String, Int],
) -> @lib.Module {
  let imports = inl_imported_func_count(mod_)
  let defined = inl_defined_func_count(mod_)
  let total = imports + defined
  let old_type_idxs = match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => type_idxs
    None => return mod_
  }
  let old_funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  let func_type_indices = inl_collect_func_type_indices(mod_)
  let used = Array::make(total, false)
  let refs = Array::make(total, 0)
  inl_mark_global_uses(mod_, used)
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(_, @lib.Expr(body)) = func
        inl_scan_refs(body, refs, used)
      }
    None => ()
  }
  let used_self_loop_sigs : @hashmap.HashMap[String, Int] = @hashmap.new()
  let mut used_has_self_loop = false
  let mut def_idx = 0
  while def_idx < defined {
    let abs = imports + def_idx
    if abs >= 0 && abs < used.length() && used[abs] {
      let @lib.Func(_, @lib.Expr(body)) = old_funcs[def_idx]
      let calls : Array[Int] = []
      inl_collect_call_targets(body, calls)
      for target in calls {
        if target == abs {
          let sig = inl_func_signature_key(mod_, func_type_indices, abs)
          used_self_loop_sigs.set(sig, 1)
          used_has_self_loop = true
          break
        }
      }
    }
    def_idx += 1
  }
  let current : @hashmap.HashMap[String, Int] = @hashmap.new()
  def_idx = 0
  while def_idx < defined {
    let abs = imports + def_idx
    let sig = inl_func_signature_key(mod_, func_type_indices, abs)
    if (!used_has_self_loop && inl_hash_get_int(used_self_loop_sigs, sig) == 0) ||
      inl_func_is_exact_unreachable(old_funcs[def_idx]) {
      inl_hash_inc_int(current, sig)
    }
    def_idx += 1
  }
  let remove = Array::make(defined, false)
  let mut any_removed = false
  def_idx = defined - 1
  while def_idx >= 0 {
    let abs = imports + def_idx
    if abs >= 0 &&
      abs < used.length() &&
      refs[abs] == 0 &&
      !used[abs] &&
      inl_func_is_exact_unreachable(old_funcs[def_idx]) {
      let sig = inl_func_signature_key(mod_, func_type_indices, abs)
      let cur = inl_hash_get_int(current, sig)
      let want = inl_hash_get_int(predicted, sig)
      if cur > want {
        remove[def_idx] = true
        current.set(sig, cur - 1)
        any_removed = true
      }
    }
    def_idx -= 1
  }
  if !any_removed {
    return mod_
  }
  let remap = Array::make(total, 0U)
  let mut idx = 0
  while idx < imports {
    remap[idx] = idx.reinterpret_as_uint()
    idx += 1
  }
  let next_type_idxs : Array[@lib.TypeIdx] = []
  let next_funcs : Array[@lib.Func] = []
  let mut next_abs = imports
  def_idx = 0
  while def_idx < defined {
    let abs = imports + def_idx
    if remove[def_idx] {
      remap[abs] = total.reinterpret_as_uint()
    } else {
      remap[abs] = next_abs.reinterpret_as_uint()
      next_type_idxs.push(old_type_idxs[def_idx])
      next_funcs.push(old_funcs[def_idx])
      next_abs += 1
    }
    def_idx += 1
  }
  inl_apply_func_remap(
    mod_
    .with_func_sec(@lib.FuncSec::new(next_type_idxs))
    .with_code_sec(@lib.CodeSec::new(next_funcs)),
    remap,
  )
}

///|
fn inl_trim_unreachable_to_selected_counts(
  mod_ : @lib.Module,
  selected : @hashmap.HashMap[String, Int],
) -> @lib.Module {
  let imports = inl_imported_func_count(mod_)
  let defined = inl_defined_func_count(mod_)
  let total = imports + defined
  let old_type_idxs = match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => type_idxs
    None => return mod_
  }
  let old_funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  let func_type_indices = inl_collect_func_type_indices(mod_)
  let used = Array::make(total, false)
  let refs = Array::make(total, 0)
  inl_mark_global_uses(mod_, used)
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(_, @lib.Expr(body)) = func
        inl_scan_refs(body, refs, used)
      }
    None => ()
  }
  let current : @hashmap.HashMap[String, Int] = @hashmap.new()
  let mut def_idx = 0
  while def_idx < defined {
    let abs = imports + def_idx
    let sig = inl_func_signature_key(mod_, func_type_indices, abs)
    match selected.get(sig) {
      Some(_) => inl_hash_inc_int(current, sig)
      None => ()
    }
    def_idx += 1
  }
  let remove = Array::make(defined, false)
  let mut any_removed = false
  def_idx = defined - 1
  while def_idx >= 0 {
    let abs = imports + def_idx
    if abs >= 0 &&
      abs < used.length() &&
      refs[abs] == 0 &&
      !used[abs] &&
      inl_func_is_exact_unreachable(old_funcs[def_idx]) {
      let sig = inl_func_signature_key(mod_, func_type_indices, abs)
      match selected.get(sig) {
        Some(want) => {
          let cur = inl_hash_get_int(current, sig)
          if cur > want {
            remove[def_idx] = true
            current.set(sig, cur - 1)
            any_removed = true
          }
        }
        None => ()
      }
    }
    def_idx -= 1
  }
  if !any_removed {
    return mod_
  }
  let remap = Array::make(total, 0U)
  let mut idx = 0
  while idx < imports {
    remap[idx] = idx.reinterpret_as_uint()
    idx += 1
  }
  let next_type_idxs : Array[@lib.TypeIdx] = []
  let next_funcs : Array[@lib.Func] = []
  let mut next_abs = imports
  def_idx = 0
  while def_idx < defined {
    let abs = imports + def_idx
    if remove[def_idx] {
      remap[abs] = total.reinterpret_as_uint()
    } else {
      remap[abs] = next_abs.reinterpret_as_uint()
      next_type_idxs.push(old_type_idxs[def_idx])
      next_funcs.push(old_funcs[def_idx])
      next_abs += 1
    }
    def_idx += 1
  }
  inl_apply_func_remap(
    mod_
    .with_func_sec(@lib.FuncSec::new(next_type_idxs))
    .with_code_sec(@lib.CodeSec::new(next_funcs)),
    remap,
  )
}

///|
fn inl_remove_dead_unreachable_private_funcs(
  mod_ : @lib.Module,
  original_abs : Array[Int],
  original_cycle_remove : Array[Bool],
  retain_counts : @hashmap.HashMap[String, Int],
) -> @lib.Module {
  let imports = inl_imported_func_count(mod_)
  let defined = inl_defined_func_count(mod_)
  let total = imports + defined
  let refs = Array::make(total, 0)
  let used = Array::make(total, false)
  let func_type_indices = inl_collect_func_type_indices(mod_)
  let retained_counts : @hashmap.HashMap[String, Int] = @hashmap.new()
  inl_mark_global_uses(mod_, used)
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(_, @lib.Expr(body)) = func
        inl_scan_refs(body, refs, used)
      }
    None => ()
  }
  let old_type_idxs = match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => type_idxs
    None => return mod_
  }
  let old_funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  let mut abs = 0
  let remove = Array::make(defined, false)
  let mut any_removed = false
  let mut def_idx = 0
  while def_idx < defined {
    abs = imports + def_idx
    if refs[abs] == 0 &&
      !used[abs] &&
      inl_func_is_exact_unreachable(old_funcs[def_idx]) {
      let original = if abs >= 0 && abs < original_abs.length() {
        original_abs[abs]
      } else {
        abs
      }
      if original >= 0 &&
        original < original_cycle_remove.length() &&
        original_cycle_remove[original] {
        let sig = inl_func_signature_key(mod_, func_type_indices, abs)
        let want_retain = inl_hash_get_int(retain_counts, sig)
        let retained = inl_hash_get_int(retained_counts, sig)
        if retained < want_retain {
          retained_counts.set(sig, retained + 1)
        } else {
          remove[def_idx] = true
          any_removed = true
        }
      }
    }
    def_idx += 1
  }
  if !any_removed {
    return mod_
  }
  let remap = Array::make(total, 0U)
  let mut i = 0
  while i < imports {
    remap[i] = i.reinterpret_as_uint()
    i += 1
  }
  let next_type_idxs : Array[@lib.TypeIdx] = []
  let next_funcs : Array[@lib.Func] = []
  let mut next_abs = imports
  def_idx = 0
  while def_idx < defined {
    let abs = imports + def_idx
    if remove[def_idx] {
      remap[abs] = total.reinterpret_as_uint()
    } else {
      remap[abs] = next_abs.reinterpret_as_uint()
      next_type_idxs.push(old_type_idxs[def_idx])
      next_funcs.push(old_funcs[def_idx])
      next_abs += 1
    }
    def_idx += 1
  }
  inl_apply_func_remap(
    mod_
    .with_func_sec(@lib.FuncSec::new(next_type_idxs))
    .with_code_sec(@lib.CodeSec::new(next_funcs)),
    remap,
  )
}

///|
fn inl_trace_nested_cleanup(
  pass_name : String,
  optimize : Bool,
  touched : Array[Bool],
  trace : ((String) -> Unit)?,
) -> Unit {
  if !optimize {
    return
  }
  let mut count = 0
  for item in touched {
    if item {
      count += 1
    }
  }
  if count == 0 {
    return
  }
  match trace {
    Some(cb) =>
      cb(
        "pass[\{pass_name}]:nested-cleanup prefix=precompute-propagate touched=\{count}",
      )
    None => ()
  }
}

///|
fn inl_mark_local_uses_instrs(
  instrs : Array[@lib.Instruction],
  used : Array[Bool],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.LocalGet(idx) | @lib.LocalSet(idx) | @lib.LocalTee(idx) => {
        let slot = inl_local_idx_slot(idx)
        if slot >= 0 && slot < used.length() {
          used[slot] = true
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        inl_mark_local_uses_instrs(body, used)
      @lib.If(_, then_body, Some(else_body)) => {
        inl_mark_local_uses_instrs(then_body, used)
        inl_mark_local_uses_instrs(else_body, used)
      }
      @lib.If(_, then_body, None) => inl_mark_local_uses_instrs(then_body, used)
      _ => ()
    }
  }
}

///|
fn inl_rewrite_local_idx(
  idx : @lib.LocalIdx,
  remap : Array[Int],
) -> @lib.LocalIdx {
  let slot = inl_local_idx_slot(idx)
  if slot >= 0 && slot < remap.length() {
    @lib.LocalIdx::new(remap[slot].reinterpret_as_uint())
  } else {
    idx
  }
}

///|
fn inl_rewrite_local_idxs_instr(
  instr : @lib.Instruction,
  remap : Array[Int],
) -> @lib.Instruction {
  match instr {
    @lib.LocalGet(idx) =>
      @lib.Instruction::local_get(inl_rewrite_local_idx(idx, remap))
    @lib.LocalSet(idx) =>
      @lib.Instruction::local_set(inl_rewrite_local_idx(idx, remap))
    @lib.LocalTee(idx) =>
      @lib.Instruction::local_tee(inl_rewrite_local_idx(idx, remap))
    @lib.Block(block_type, @lib.Expr(body)) =>
      @lib.Instruction::block(
        block_type,
        @lib.Expr::new(inl_rewrite_local_idxs_instrs(body, remap)),
      )
    @lib.Loop(block_type, @lib.Expr(body)) =>
      @lib.Instruction::loop_(
        block_type,
        @lib.Expr::new(inl_rewrite_local_idxs_instrs(body, remap)),
      )
    @lib.If(block_type, then_body, else_body) =>
      @lib.Instruction::if_(
        block_type,
        inl_rewrite_local_idxs_instrs(then_body, remap),
        match else_body {
          Some(body) => Some(inl_rewrite_local_idxs_instrs(body, remap))
          None => None
        },
      )
    @lib.TryTable(block_type, catches, @lib.Expr(body)) =>
      @lib.Instruction::try_table(
        block_type,
        catches,
        @lib.Expr::new(inl_rewrite_local_idxs_instrs(body, remap)),
      )
    _ => instr
  }
}

///|
fn inl_rewrite_local_idxs_instrs(
  instrs : Array[@lib.Instruction],
  remap : Array[Int],
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    out.push(inl_rewrite_local_idxs_instr(instr, remap))
  }
  out
}

///|
fn inl_instrs_have_tail_call(instrs : Array[@lib.Instruction]) -> Bool {
  for instr in instrs {
    match instr {
      @lib.ReturnCall(_)
      | @lib.ReturnCallIndirect(_, _)
      | @lib.ReturnCallRef(_) => return true
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if inl_instrs_have_tail_call(body) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if inl_instrs_have_tail_call(then_body) {
          return true
        }
        match else_body {
          Some(body) => if inl_instrs_have_tail_call(body) { return true }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn inl_compact_unused_locals_func(
  func : @lib.Func,
  param_count : Int,
) -> @lib.Func {
  let @lib.Func(locals, @lib.Expr(body)) = func
  // Fail closed around tail-call operands. The compact-local rewriter is purely
  // syntactic, while invalid nested cleanup candidates from random-all fuzzing
  // showed stale local remaps feeding return_call operands that Starshine's
  // internal validator did not reject. Keep tail-call functions valid until the
  // tail-call/local-compaction interaction has a narrower type-aware repair.
  if inl_instrs_have_tail_call(body) {
    return func
  }
  let total = param_count + locals.length()
  let used = Array::make(total, false)
  let mut i = 0
  while i < param_count {
    used[i] = true
    i += 1
  }
  inl_mark_local_uses_instrs(body, used)
  let remap = Array::make(total, 0)
  i = 0
  while i < param_count {
    remap[i] = i
    i += 1
  }
  let next_local_types : Array[@lib.ValType] = []
  let mut next_idx = param_count
  let mut local_idx = 0
  for local_type in locals.iter() {
    let abs = param_count + local_idx
    if used[abs] {
      remap[abs] = next_idx
      next_idx += 1
      next_local_types.push(local_type)
    }
    local_idx += 1
  }
  if next_idx == total {
    return func
  }
  @lib.Func::new(
    @lib.Locals::from_types(next_local_types),
    @lib.Expr::new(inl_rewrite_local_idxs_instrs(body, remap)),
  )
}

///|
fn inl_compact_unused_locals(
  mod_ : @lib.Module,
  touched : Array[Bool],
) -> @lib.Module {
  let types = inl_collect_func_type_indices(mod_)
  let imports = inl_imported_func_count(mod_)
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let out : Array[@lib.Func] = []
      let mut changed = false
      let mut def_idx = 0
      for func in funcs {
        let abs = imports + def_idx
        if abs >= touched.length() || !touched[abs] {
          out.push(func)
          def_idx += 1
          continue
        }
        let param_count = match inl_resolve_func_type(mod_, types, abs) {
          Some(@lib.FuncType(params, _)) => params.length()
          None => 0
        }
        let next = inl_compact_unused_locals_func(func, param_count)
        if next != func {
          changed = true
        }
        out.push(next)
        def_idx += 1
      }
      if changed {
        mod_.with_code_sec(@lib.CodeSec::new(out))
      } else {
        mod_
      }
    }
    None => mod_
  }
}

///|
fn inl_instr_is_nontrapping_prefix(
  instrs : Array[@lib.Instruction],
  idx : Int,
) -> Bool {
  match instrs[idx] {
    @lib.Unreachable
    | @lib.Nop
    | @lib.Drop
    | @lib.Select(_)
    | @lib.Br(_)
    | @lib.BrIf(_)
    | @lib.BrTable(_, _)
    | @lib.LocalGet(_)
    | @lib.LocalSet(_)
    | @lib.LocalTee(_)
    | @lib.I32Const(_)
    | @lib.I64Const(_)
    | @lib.F32Const(_)
    | @lib.F64Const(_)
    | @lib.I32Eqz
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
    | @lib.I32Clz
    | @lib.I32Ctz
    | @lib.I32Popcnt
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
    | @lib.I64Clz
    | @lib.I64Ctz
    | @lib.I64Popcnt
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
    | @lib.F32Abs
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
    | @lib.F64Copysign
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
    | @lib.F64ConvertI32S
    | @lib.F64ConvertI32U
    | @lib.F64ConvertI64S
    | @lib.F64ConvertI64U
    | @lib.F32DemoteF64
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
    @lib.I32DivS | @lib.I32DivU | @lib.I32RemS | @lib.I32RemU =>
      if idx > 0 {
        match instrs[idx - 1] {
          @lib.I32Const(@lib.I32(value)) => value != 0
          _ => false
        }
      } else {
        false
      }
    @lib.I64DivS | @lib.I64DivU | @lib.I64RemS | @lib.I64RemU =>
      if idx > 0 {
        match instrs[idx - 1] {
          @lib.I64Const(@lib.I64(value)) => value != 0L
          _ => false
        }
      } else {
        false
      }
    @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) => {
      let mut ok = true
      let mut child = 0
      while child < body.length() {
        if !inl_instr_is_nontrapping_prefix(body, child) {
          ok = false
          break
        }
        child += 1
      }
      ok
    }
    @lib.If(_, then_body, Some(else_body)) => {
      let mut ok = true
      let mut child = 0
      while child < then_body.length() {
        if !inl_instr_is_nontrapping_prefix(then_body, child) {
          ok = false
          break
        }
        child += 1
      }
      child = 0
      while ok && child < else_body.length() {
        if !inl_instr_is_nontrapping_prefix(else_body, child) {
          ok = false
          break
        }
        child += 1
      }
      ok
    }
    @lib.If(_, then_body, None) => {
      let mut ok = true
      let mut child = 0
      while child < then_body.length() {
        if !inl_instr_is_nontrapping_prefix(then_body, child) {
          ok = false
          break
        }
        child += 1
      }
      ok
    }
    _ => false
  }
}

///|
fn inl_instrs_have_call_to_func(
  instrs : Array[@lib.Instruction],
  target_abs : Int,
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Call(func_idx) | @lib.ReturnCall(func_idx) =>
        if inl_func_idx_slot(func_idx) == target_abs {
          return true
        }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if inl_instrs_have_call_to_func(body, target_abs) {
          return true
        }
      @lib.If(_, then_body, Some(else_body)) =>
        if inl_instrs_have_call_to_func(then_body, target_abs) ||
          inl_instrs_have_call_to_func(else_body, target_abs) {
          return true
        }
      @lib.If(_, then_body, None) =>
        if inl_instrs_have_call_to_func(then_body, target_abs) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn inl_suffix_calls_marked_func(
  body : Array[@lib.Instruction],
  start : Int,
  marked : Array[Bool],
) -> Bool {
  let suffix : Array[@lib.Instruction] = []
  let mut idx = start
  while idx < body.length() {
    suffix.push(body[idx])
    idx += 1
  }
  for target_abs = 0; target_abs < marked.length(); target_abs = target_abs + 1 {
    if marked[target_abs] && inl_instrs_have_call_to_func(suffix, target_abs) {
      return true
    }
  }
  false
}

///|
fn inl_suffix_has_self_call(
  body : Array[@lib.Instruction],
  start : Int,
  self_abs : Int,
) -> Bool {
  let marked = Array::make(self_abs + 1, false)
  marked[self_abs] = true
  inl_suffix_calls_marked_func(body, start, marked)
}

///|
fn inl_suffix_has_polymorphic_self_call(
  body : Array[@lib.Instruction],
  start : Int,
  self_abs : Int,
) -> Bool {
  let mut seen_unreachable = false
  let mut idx = start
  while idx < body.length() {
    match body[idx] {
      @lib.Unreachable
      | @lib.Block(@lib.VoidBlockType, @lib.Expr([@lib.Unreachable])) =>
        seen_unreachable = true
      @lib.Call(func_idx) | @lib.ReturnCall(func_idx) =>
        if seen_unreachable && inl_func_idx_slot(func_idx) == self_abs {
          return true
        }
      _ => ()
    }
    idx += 1
  }
  false
}

///|
fn inl_func_collapse_unreachable_root(
  func : @lib.Func,
  self_abs : Int,
  self_recursive_funcs : Array[Bool],
  check_dead_suffix_calls? : Bool = true,
  check_marked_suffix_calls? : Bool = true,
) -> @lib.Func {
  let @lib.Func(locals, @lib.Expr(body)) = func
  let mut idx = 0
  while idx < body.length() {
    let is_unreachable_root = match body[idx] {
      @lib.Unreachable => true
      @lib.Block(@lib.VoidBlockType, @lib.Expr([@lib.Unreachable])) => true
      _ => false
    }
    if is_unreachable_root {
      let mut ok = true
      let mut prefix = 0
      while prefix < idx {
        if !inl_instr_is_nontrapping_prefix(body, prefix) {
          ok = false
          break
        }
        prefix += 1
      }
      if ok &&
        (
          !check_dead_suffix_calls ||
          (
            !inl_suffix_has_self_call(body, idx + 1, self_abs) &&
            (
              !check_marked_suffix_calls ||
              !inl_suffix_calls_marked_func(body, idx + 1, self_recursive_funcs)
            )
          )
        ) {
        ignore(locals)
        return @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::unreachable_()]),
        )
      }
    }
    idx += 1
  }
  func
}

///|
fn inl_collect_dead_suffix_targets(func : @lib.Func) -> InlDeadSuffixTargets {
  let @lib.Func(_, @lib.Expr(body)) = func
  let targets : Array[Int] = []
  let counts : Array[Int] = []
  let mut seen_unreachable = false
  let mut total_count = 0
  for instr in body {
    match instr {
      @lib.Unreachable
      | @lib.Block(@lib.VoidBlockType, @lib.Expr([@lib.Unreachable])) =>
        seen_unreachable = true
      @lib.Call(func_idx) | @lib.ReturnCall(func_idx) =>
        if seen_unreachable {
          total_count += 1
          let target = inl_func_idx_slot(func_idx)
          let mut found = false
          let mut idx = 0
          while idx < targets.length() {
            if targets[idx] == target {
              counts[idx] = counts[idx] + 1
              found = true
              break
            }
            idx += 1
          }
          if !found {
            targets.push(target)
            counts.push(1)
          }
        }
      _ => ()
    }
  }
  { has_any: total_count > 0, total_count, targets, counts }
}

///|
fn inl_dead_suffix_targets_count_to(
  facts : InlDeadSuffixTargets,
  target_abs : Int,
) -> Int {
  let mut idx = 0
  while idx < facts.targets.length() {
    if facts.targets[idx] == target_abs {
      return facts.counts[idx]
    }
    idx += 1
  }
  0
}

///|
fn inl_build_dead_suffix_preserve_facts(
  mod_ : @lib.Module,
  funcs : Array[@lib.Func],
  imports : Int,
) -> InlDeadSuffixPreserveFacts {
  let total = imports + funcs.length()
  let used = Array::make(total, false)
  inl_mark_global_uses(mod_, used)
  let func_type_indices = inl_collect_func_type_indices(mod_)
  let signatures = inl_build_func_signature_keys(mod_, func_type_indices, total)
  let dead_suffix_targets : Array[InlDeadSuffixTargets] = []
  for func in funcs {
    dead_suffix_targets.push(inl_collect_dead_suffix_targets(func))
  }
  { imports, defined: funcs.length(), used, signatures, dead_suffix_targets }
}

///|
fn inl_dead_suffix_preserve_facts_should_preserve(
  facts : InlDeadSuffixPreserveFacts,
  self_abs : Int,
) -> Bool {
  if self_abs < facts.imports ||
    self_abs >= facts.used.length() ||
    self_abs - facts.imports >= facts.defined {
    return false
  }
  let self_def = self_abs - facts.imports
  let self_sig = facts.signatures[self_abs]
  let self_targets = facts.dead_suffix_targets[self_def]
  let mut root_def = 0
  while root_def < facts.defined {
    let root_abs = facts.imports + root_def
    if root_abs < facts.used.length() &&
      facts.used[root_abs] &&
      facts.signatures[root_abs] == self_sig {
      let root_calls_self = inl_dead_suffix_targets_count_to(
        facts.dead_suffix_targets[root_def],
        self_abs,
      )
      let self_calls_root = inl_dead_suffix_targets_count_to(
          self_targets, root_abs,
        ) >
        0
      if self_abs != root_abs &&
        !(self_abs < facts.used.length() && facts.used[self_abs]) &&
        root_calls_self >= 2 &&
        self_calls_root &&
        self_targets.total_count ==
        inl_dead_suffix_targets_count_to(self_targets, root_abs) {
        let mut orphan_def = 0
        while orphan_def < facts.defined {
          let orphan_abs = facts.imports + orphan_def
          if orphan_abs != root_abs &&
            orphan_abs != self_abs &&
            orphan_abs < facts.used.length() &&
            !facts.used[orphan_abs] &&
            facts.signatures[orphan_abs] == self_sig &&
            facts.dead_suffix_targets[orphan_def].has_any {
            return true
          }
          orphan_def += 1
        }
      }
    }
    root_def += 1
  }
  if !(self_abs < facts.used.length() && facts.used[self_abs]) {
    return false
  }
  let mut helper_def = 0
  while helper_def < facts.defined {
    let helper_abs = facts.imports + helper_def
    let helper_targets = facts.dead_suffix_targets[helper_def]
    if helper_abs != self_abs &&
      helper_abs < facts.used.length() &&
      !facts.used[helper_abs] &&
      facts.signatures[helper_abs] == self_sig &&
      inl_dead_suffix_targets_count_to(self_targets, helper_abs) >= 2 &&
      inl_dead_suffix_targets_count_to(helper_targets, self_abs) > 0 &&
      helper_targets.total_count ==
      inl_dead_suffix_targets_count_to(helper_targets, self_abs) {
      let mut orphan_def = 0
      while orphan_def < facts.defined {
        let orphan_abs = facts.imports + orphan_def
        if orphan_abs != self_abs &&
          orphan_abs != helper_abs &&
          orphan_abs < facts.used.length() &&
          !facts.used[orphan_abs] &&
          facts.signatures[orphan_abs] == self_sig &&
          facts.dead_suffix_targets[orphan_def].has_any {
          return true
        }
        orphan_def += 1
      }
    }
    helper_def += 1
  }
  false
}

///|
fn inl_func_has_dead_suffix_call_to_marked(
  func : @lib.Func,
  marked : Array[Bool],
) -> Bool {
  let mut abs = 0
  while abs < marked.length() {
    if marked[abs] && inl_func_has_dead_suffix_call_to(func, abs) {
      return true
    }
    abs += 1
  }
  false
}

///|
fn inl_collapse_unreachable_private_except_used_suffix_roots(
  mod_ : @lib.Module,
) -> @lib.Module {
  let imports = inl_imported_func_count(mod_)
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let used = Array::make(imports + funcs.length(), false)
      inl_mark_global_uses(mod_, used)
      let no_marked = Array::make(imports + funcs.length(), false)
      let out : Array[@lib.Func] = []
      let mut changed = false
      let mut def_idx = 0
      for func in funcs {
        let abs = imports + def_idx
        let keep = abs < used.length() &&
          (used[abs] || inl_func_has_dead_suffix_call_to_marked(func, used))
        let next = if keep {
          func
        } else {
          inl_func_collapse_unreachable_root(
            func,
            abs,
            no_marked,
            check_dead_suffix_calls=false,
            check_marked_suffix_calls=false,
          )
        }
        if next != func {
          changed = true
        }
        out.push(next)
        def_idx += 1
      }
      if changed {
        mod_.with_code_sec(@lib.CodeSec::new(out))
      } else {
        mod_
      }
    }
    None => mod_
  }
}

///|
fn inl_has_same_sig_root_cycle_dead_suffix(mod_ : @lib.Module) -> Bool {
  let imports = inl_imported_func_count(mod_)
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let facts = inl_build_dead_suffix_preserve_facts(mod_, funcs, imports)
      let mut def_idx = 0
      while def_idx < funcs.length() {
        if inl_dead_suffix_preserve_facts_should_preserve(
            facts,
            imports + def_idx,
          ) {
          return true
        }
        def_idx += 1
      }
      false
    }
    None => false
  }
}

///|
fn inl_collapse_unreachable_roots(
  mod_ : @lib.Module,
  touched : Array[Bool],
  check_dead_suffix_calls? : Bool = true,
  check_marked_suffix_calls? : Bool = true,
) -> @lib.Module {
  let imports = inl_imported_func_count(mod_)
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let self_recursive_funcs = Array::make(imports + funcs.length(), false)
      let mut scan_def_idx = 0
      for func in funcs {
        let abs = imports + scan_def_idx
        let @lib.Func(_, @lib.Expr(body)) = func
        let mut idx = 0
        while idx < body.length() {
          let is_unreachable_root = match body[idx] {
            @lib.Unreachable => true
            @lib.Block(@lib.VoidBlockType, @lib.Expr([@lib.Unreachable])) =>
              true
            _ => false
          }
          if is_unreachable_root && inl_suffix_has_self_call(body, idx + 1, abs) {
            self_recursive_funcs[abs] = true
            break
          }
          idx += 1
        }
        scan_def_idx += 1
      }
      let preserve_facts = if check_dead_suffix_calls {
        Some(inl_build_dead_suffix_preserve_facts(mod_, funcs, imports))
      } else {
        None
      }
      let out : Array[@lib.Func] = []
      let mut changed = false
      let mut def_idx = 0
      for func in funcs {
        let abs = imports + def_idx
        ignore(touched)
        let preserve_root_cycle = match preserve_facts {
          Some(facts) =>
            inl_dead_suffix_preserve_facts_should_preserve(facts, abs)
          None => false
        }
        let next = if preserve_root_cycle {
          func
        } else {
          inl_func_collapse_unreachable_root(
            func,
            abs,
            self_recursive_funcs,
            check_dead_suffix_calls~,
            check_marked_suffix_calls~,
          )
        }
        if next != func {
          changed = true
        }
        out.push(next)
        def_idx += 1
      }
      if changed {
        mod_.with_code_sec(@lib.CodeSec::new(out))
      } else {
        mod_
      }
    }
    None => mod_
  }
}

///|
fn inl_instr_is_unreachable_root(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Unreachable => true
    @lib.Block(@lib.VoidBlockType, @lib.Expr([@lib.Unreachable])) => true
    _ => false
  }
}

///|
fn inl_instr_is_dead_unreachable_value(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Block(_, @lib.Expr(body)) => {
      if body.length() == 0 {
        return false
      }
      for nested in body {
        if !inl_instr_is_unreachable_root(nested) {
          return false
        }
      }
      true
    }
    _ => false
  }
}

///|
fn inl_prune_dead_unreachable_drops_in_instrs(
  instrs : Array[@lib.Instruction],
) -> Array[@lib.Instruction] {
  let rewritten : Array[@lib.Instruction] = []
  for instr in instrs {
    match instr {
      @lib.Block(block_type, @lib.Expr(body)) =>
        rewritten.push(
          @lib.Instruction::block(
            block_type,
            @lib.Expr::new(inl_prune_dead_unreachable_drops_in_instrs(body)),
          ),
        )
      @lib.Loop(block_type, @lib.Expr(body)) =>
        rewritten.push(
          @lib.Instruction::loop_(
            block_type,
            @lib.Expr::new(inl_prune_dead_unreachable_drops_in_instrs(body)),
          ),
        )
      @lib.If(block_type, then_body, else_body) => {
        let next_then = inl_prune_dead_unreachable_drops_in_instrs(then_body)
        let next_else = match else_body {
          Some(body) => Some(inl_prune_dead_unreachable_drops_in_instrs(body))
          None => None
        }
        rewritten.push(@lib.Instruction::if_(block_type, next_then, next_else))
      }
      @lib.TryTable(block_type, catches, @lib.Expr(body)) =>
        rewritten.push(
          @lib.Instruction::try_table(
            block_type,
            catches,
            @lib.Expr::new(inl_prune_dead_unreachable_drops_in_instrs(body)),
          ),
        )
      _ => rewritten.push(instr)
    }
  }
  let out : Array[@lib.Instruction] = []
  let mut idx = 0
  while idx < rewritten.length() {
    if idx + 2 < rewritten.length() &&
      inl_instr_is_unreachable_root(rewritten[idx]) {
      let next_is_drop = match rewritten[idx + 1] {
        @lib.Drop => true
        _ => false
      }
      if next_is_drop && inl_instr_is_unreachable_root(rewritten[idx + 2]) {
        idx += 2
        continue
      }
    }
    if idx + 1 < rewritten.length() &&
      inl_instr_is_dead_unreachable_value(rewritten[idx]) &&
      inl_instr_is_unreachable_root(rewritten[idx + 1]) {
      idx += 1
      continue
    }
    out.push(rewritten[idx])
    idx += 1
  }
  out
}

///|
fn inl_prune_dead_unreachable_drops(mod_ : @lib.Module) -> @lib.Module {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let out : Array[@lib.Func] = []
      let mut changed = false
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(body)) = func
        let next_body = inl_prune_dead_unreachable_drops_in_instrs(body)
        if next_body != body {
          changed = true
        }
        out.push(@lib.Func::new(locals, @lib.Expr::new(next_body)))
      }
      if changed {
        mod_.with_code_sec(@lib.CodeSec::new(out))
      } else {
        mod_
      }
    }
    None => mod_
  }
}

///|
fn inl_func_has_hot_unsafe_self_suffix(func : @lib.Func, abs : Int) -> Bool {
  let @lib.Func(_, @lib.Expr(body)) = func
  let mut idx = 0
  while idx < body.length() {
    let is_unreachable_root = match body[idx] {
      @lib.Unreachable => true
      @lib.Block(@lib.VoidBlockType, @lib.Expr([@lib.Unreachable])) => true
      _ => false
    }
    if is_unreachable_root &&
      inl_suffix_has_polymorphic_self_call(body, idx + 1, abs) {
      return true
    }
    idx += 1
  }
  false
}

///|
fn inl_has_two_func_exact_root_hot_unsafe_helper(mod_ : @lib.Module) -> Bool {
  let imports = inl_imported_func_count(mod_)
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      funcs.length() == 2 &&
      inl_func_is_exact_unreachable(funcs[0]) &&
      inl_func_has_hot_unsafe_self_suffix(funcs[1], imports + 1)
    None => false
  }
}

///|
fn inl_abs_touched_to_defined(
  touched : Array[Bool],
  imports : Int,
  defined : Int,
) -> Array[Bool] {
  let out = Array::make(defined, false)
  let mut def_idx = 0
  while def_idx < defined {
    let abs = imports + def_idx
    if abs >= 0 && abs < touched.length() {
      out[def_idx] = touched[abs]
    }
    def_idx += 1
  }
  out
}

///|
fn inl_restore_untouched_funcs(
  original : @lib.Module,
  cleaned : @lib.Module,
  touched : Array[Bool],
) -> @lib.Module {
  let imports = inl_imported_func_count(original)
  match (original.code_sec, cleaned.code_sec) {
    (Some(@lib.CodeSec(original_funcs)), Some(@lib.CodeSec(cleaned_funcs))) => {
      if original_funcs.length() != cleaned_funcs.length() {
        return cleaned
      }
      let out : Array[@lib.Func] = []
      let mut def_idx = 0
      for cleaned_func in cleaned_funcs {
        let abs = imports + def_idx
        if abs < touched.length() && touched[abs] {
          out.push(cleaned_func)
        } else {
          out.push(original_funcs[def_idx])
        }
        def_idx += 1
      }
      cleaned.with_code_sec(@lib.CodeSec::new(out))
    }
    _ => cleaned
  }
}

///|
fn inl_trace_nested_pass(
  trace : ((String) -> Unit)?,
  pass_name : String,
) -> Unit {
  match trace {
    Some(cb) => cb("pass[inlining-optimizing]:nested-pass name=\{pass_name}")
    None => ()
  }
}

///|
fn inl_run_nested_cleanup_pass(
  mod_ : @lib.Module,
  pass_name : String,
  def_touched : Array[Bool],
  options : HotPipelineOptions,
) -> Result[@lib.Module, String] {
  if pass_name == "local-cse" {
    return run_hot_pipeline_apply_local_cse_to_touched(
      mod_, def_touched, options,
    )
  }
  if pass_name == "coalesce-locals" {
    return run_hot_pipeline_apply_coalesce_locals_to_touched(mod_, def_touched)
  }
  if pass_name == "reorder-locals" {
    return run_hot_pipeline_apply_reorder_locals_to_touched(mod_, def_touched)
  }
  if pass_name == "merge-locals" {
    return run_hot_pipeline_apply_merge_locals_to_touched(
      mod_, def_touched, options,
    )
  }
  if pass_name == "local-subtyping" {
    pipeline_trace_hook(options.trace, "local-subtyping", "start")
    let next = match
      run_hot_pipeline_apply_local_subtyping_to_touched(mod_, def_touched) {
      Ok(next) => next
      Err(err) => return Err(err)
    }
    pipeline_trace_hook(options.trace, "local-subtyping", "done")
    return Ok(next)
  }
  let descriptor = match pass_registry_lookup_cached(pass_name) {
    Some(entry) =>
      match entry.descriptor {
        Some(descriptor) => descriptor
        None =>
          return Err(
            "inlining-optimizing nested cleanup pass \{pass_name} is not a hot pass",
          )
      }
    None =>
      return Err(
        "inlining-optimizing nested cleanup expanded to unknown pass \{pass_name}",
      )
  }
  run_hot_pipeline_apply_hot_pass_to_touched(
    mod_, descriptor, def_touched, options,
  )
}

///|
fn inl_run_nested_cleanup_passes(
  mod_ : @lib.Module,
  passes : Array[String],
  def_touched : Array[Bool],
  options : HotPipelineOptions,
  trace : ((String) -> Unit)?,
) -> Result[@lib.Module, String] {
  let mut current = mod_
  for pass_name in passes {
    inl_trace_nested_pass(trace, pass_name)
    current = match
      inl_run_nested_cleanup_pass(current, pass_name, def_touched, options) {
      Ok(next) => next
      Err(err) =>
        return Err(
          "inlining-optimizing nested cleanup pass \{pass_name}: \{err}",
        )
    }
  }
  Ok(current)
}

///|
fn inl_validate_or_original(
  candidate : @lib.Module,
  original : @lib.Module,
) -> @lib.Module {
  match @validate.validate_module(candidate) {
    Ok(_) => candidate
    Err(_) => original
  }
}

///|
fn inl_finalize_module_pass_result(
  mod_ : @lib.Module,
  _optimize : Bool,
) -> @lib.Module {
  inl_strip_partial_wrapper_annotations(mod_)
}

///|
fn inl_run_i32_add_accumulator_raw_cleanup(
  mod_ : @lib.Module,
  touched : Array[Bool],
) -> (@lib.Module, Bool) {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return (mod_, false)
  }
  let imports = inl_imported_func_count(mod_)
  let mut rewritten : Array[@lib.Func]? = None
  let mut changed = false
  for def_idx = 0; def_idx < funcs.length(); def_idx = def_idx + 1 {
    let abs_idx = imports + def_idx
    if abs_idx < 0 || abs_idx >= touched.length() || !touched[abs_idx] {
      continue
    }
    let @lib.Func(locals, @lib.Expr(body)) = funcs[def_idx]
    let (next_body, body_changed) = run_hot_pipeline_raw_simplify_locals_rewrite_i32_add_accumulator_chain(
      body,
    )
    if body_changed {
      let next_func = @lib.Func::new(locals, @lib.Expr::new(next_body))
      match rewritten {
        Some(copy) => copy[def_idx] = next_func
        None => {
          let copy = funcs.copy()
          copy[def_idx] = next_func
          rewritten = Some(copy)
        }
      }
      changed = true
    }
  }
  match rewritten {
    Some(copy) =>
      (mod_.with_code_sec(@lib.CodeSec::new(copy)).without_name_sec(), true)
    None => (mod_, changed)
  }
}

///|
fn inl_run_nested_cleanup(
  mod_ : @lib.Module,
  optimize : Bool,
  trace : ((String) -> Unit)?,
  touched : Array[Bool],
  optimize_level : Int,
  shrink_level : Int,
  perf? : HotPerfSession? = None,
) -> @lib.Module {
  if !optimize {
    return mod_
  }
  if inl_has_two_func_exact_root_hot_unsafe_helper(mod_) {
    return inl_compact_unused_locals(
      inl_collapse_unreachable_roots(
        mod_,
        touched,
        check_dead_suffix_calls=false,
      ),
      touched,
    )
  }
  if inl_has_same_sig_root_cycle_dead_suffix(mod_) {
    return inl_compact_unused_locals(mod_, touched)
  }
  let (raw_accumulator_cleaned, raw_accumulator_changed) = inl_run_i32_add_accumulator_raw_cleanup(
    mod_, touched,
  )
  if raw_accumulator_changed {
    match trace {
      Some(cb) =>
        cb(
          "pass[inlining-optimizing]:nested-cleanup-fast-path reason=i32-add-accumulator",
        )
      None => ()
    }
    return inl_compact_unused_locals(
      inl_collapse_unreachable_roots(raw_accumulator_cleaned, touched),
      touched,
    )
  }
  let prepared = inl_collapse_unreachable_roots(mod_, touched)
  let defined_count = inl_defined_func_count(prepared)
  let nested_verify_policy = if defined_count > 1000 {
    HotPipelineVerifyPolicy::AfterEachPass
  } else {
    HotPipelineVerifyPolicy::FinalModuleOnly
  }
  let options = HotPipelineOptions::new(
    verify_policy=nested_verify_policy,
    validate_final_module=false,
    trace~,
    perf~,
  )
  let imports = inl_imported_func_count(prepared)
  let def_touched = inl_abs_touched_to_defined(touched, imports, defined_count)
  inl_trace_nested_pass(trace, "precompute-propagate")
  let prefixed = match
    run_hot_pipeline_apply_hot_pass_to_touched(
      prepared,
      precompute_propagate_descriptor(),
      def_touched,
      options,
    ) {
    Ok(next) => next
    Err(_) => prepared
  }
  let passes = inlining_nested_function_pipeline_passes(
    optimize_level, shrink_level,
  )
  let cleaned = match
    inl_run_nested_cleanup_passes(prefixed, passes, def_touched, options, trace) {
    Ok(cleaned) =>
      inl_compact_unused_locals(
        inl_collapse_unreachable_roots(
          inl_prune_dead_unreachable_drops(
            inl_restore_untouched_funcs(mod_, cleaned, touched),
          ),
          touched,
        ),
        touched,
      )
    Err(_) =>
      inl_compact_unused_locals(
        inl_collapse_unreachable_roots(
          inl_prune_dead_unreachable_drops(mod_),
          touched,
        ),
        touched,
      )
  }
  inl_validate_or_original(cleaned, mod_)
}

///|
fn inl_count_true(flags : Array[Bool]) -> Int {
  let mut count = 0
  for flag in flags {
    if flag {
      count += 1
    }
  }
  count
}

///|
fn inl_trace_perf(trace : ((String) -> Unit)?, msg : String) -> Unit {
  match trace {
    Some(cb) => cb("pass[inlining-optimizing]:perf \{msg}")
    None => ()
  }
}

///|
fn inl_touched_original_abs(
  touched : Array[Bool],
  original_abs : Array[Int],
) -> Array[Int] {
  let out : Array[Int] = []
  let mut idx = 0
  while idx < touched.length() && idx < original_abs.length() {
    if touched[idx] {
      out.push(original_abs[idx])
    }
    idx += 1
  }
  out
}

///|
fn inl_find_named_func_abs(mod_ : @lib.Module, name : String) -> Int {
  let total = inl_imported_func_count(mod_) + inl_defined_func_count(mod_)
  let names = no_inline_func_names(mod_, total)
  let mut abs = 0
  while abs < names.length() {
    match names[abs] {
      Some(current) => if current == name { return abs }
      None => ()
    }
    abs += 1
  }
  -1
}

///|
fn inl_count_direct_target_calls(
  instrs : Array[@lib.Instruction],
  target_abs : Int,
) -> Int {
  let mut count = 0
  for instr in instrs {
    match instr {
      @lib.Call(func_idx) | @lib.ReturnCall(func_idx) =>
        if inl_func_idx_slot(func_idx) == target_abs {
          count += 1
        }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        count += inl_count_direct_target_calls(body, target_abs)
      @lib.If(_, then_body, Some(else_body)) => {
        count += inl_count_direct_target_calls(then_body, target_abs)
        count += inl_count_direct_target_calls(else_body, target_abs)
      }
      @lib.If(_, then_body, None) =>
        count += inl_count_direct_target_calls(then_body, target_abs)
      _ => ()
    }
  }
  count
}

///|
fn inl_inline_exact_target_instrs(
  instrs : Array[@lib.Instruction],
  caller_abs : Int,
  target_abs : Int,
  state : InlRewriteState,
  mod_ : @lib.Module,
  infos : Array[InlFunctionInfo],
  imports : Int,
  try_depth? : Int = 0,
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    match instr {
      @lib.Call(func_idx) if inl_func_idx_slot(func_idx) == target_abs =>
        match
          inl_make_inline_replacement(
            state.func,
            mod_,
            infos,
            caller_abs,
            target_abs,
            imports,
            false,
          ) {
          Some((next_func, replacement)) => {
            state.func = next_func
            state.changed = true
            inl_push_inline_replacement(out, replacement)
          }
          None => out.push(instr)
        }
      @lib.ReturnCall(func_idx) if inl_func_idx_slot(func_idx) == target_abs =>
        match
          inl_make_inline_replacement(
            state.func,
            mod_,
            infos,
            caller_abs,
            target_abs,
            imports,
            true,
          ) {
          Some((next_func, replacement)) => {
            state.func = next_func
            state.changed = true
            if try_depth > 0 {
              let param_count = infos[target_abs].params.length()
              let site_prefix : Array[@lib.Instruction] = []
              let post_body : Array[@lib.Instruction] = []
              let mut replacement_idx = 0
              while replacement_idx < replacement.length() {
                if replacement_idx < param_count {
                  site_prefix.push(replacement[replacement_idx])
                } else {
                  post_body.push(replacement[replacement_idx])
                }
                replacement_idx += 1
              }
              out.append(site_prefix)
              let hoist_id = state.tail_callsite_hoists.length()
              out.push(inl_tail_callsite_hoist_placeholder(hoist_id))
              state.tail_callsite_hoists.push({ post_body, })
            } else {
              inl_push_inline_replacement(out, replacement)
              out.push(@lib.Instruction::return_())
            }
          }
          None => out.push(instr)
        }
      @lib.Block(block_type, @lib.Expr(body)) =>
        out.push(
          @lib.Instruction::block(
            block_type,
            @lib.Expr::new(
              inl_inline_exact_target_instrs(
                body,
                caller_abs,
                target_abs,
                state,
                mod_,
                infos,
                imports,
                try_depth~,
              ),
            ),
          ),
        )
      @lib.Loop(block_type, @lib.Expr(body)) =>
        out.push(
          @lib.Instruction::loop_(
            block_type,
            @lib.Expr::new(
              inl_inline_exact_target_instrs(
                body,
                caller_abs,
                target_abs,
                state,
                mod_,
                infos,
                imports,
                try_depth~,
              ),
            ),
          ),
        )
      @lib.If(block_type, then_body, else_body) =>
        out.push(
          @lib.Instruction::if_(
            block_type,
            inl_inline_exact_target_instrs(
              then_body,
              caller_abs,
              target_abs,
              state,
              mod_,
              infos,
              imports,
              try_depth~,
            ),
            match else_body {
              Some(body) =>
                Some(
                  inl_inline_exact_target_instrs(
                    body,
                    caller_abs,
                    target_abs,
                    state,
                    mod_,
                    infos,
                    imports,
                    try_depth~,
                  ),
                )
              None => None
            },
          ),
        )
      @lib.TryTable(block_type, catches, @lib.Expr(body)) =>
        out.push(
          @lib.Instruction::try_table(
            block_type,
            catches,
            @lib.Expr::new(
              inl_inline_exact_target_instrs(
                body,
                caller_abs,
                target_abs,
                state,
                mod_,
                infos,
                imports,
                try_depth=try_depth + 1,
              ),
            ),
          ),
        )
      _ => out.push(instr)
    }
  }
  out
}

///|
pub fn inline_main_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  if pass_module_has_legacy_try(mod_) {
    return mod_
  }
  let imports = inl_imported_func_count(mod_)
  let main_abs = inl_find_named_func_abs(mod_, "main")
  let original_abs = inl_find_named_func_abs(mod_, "__original_main")
  if main_abs < imports || original_abs < imports {
    return mod_
  }
  let main_def = main_abs - imports
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  if main_def < 0 || main_def >= funcs.length() {
    return mod_
  }
  let @lib.Func(_, @lib.Expr(main_body)) = funcs[main_def]
  if inl_count_direct_target_calls(main_body, original_abs) != 1 {
    return mod_
  }
  let infos = inl_build_function_infos(mod_)
  if main_abs >= infos.length() || original_abs >= infos.length() {
    return mod_
  }
  let state : InlRewriteState = {
    func: funcs[main_def],
    changed: false,
    size: infos[main_abs].size,
    tail_callsite_hoists: [],
  }
  let next_body = inl_inline_exact_target_instrs(
    main_body, main_abs, original_abs, state, mod_, infos, imports,
  )
  if !state.changed {
    return mod_
  }
  let @lib.Func(next_locals, _) = state.func
  let next_funcs = funcs.copy()
  next_funcs[main_def] = @lib.Func::new(
    next_locals,
    @lib.Expr::new(
      inl_wrap_tail_callsite_hoists(next_body, state.tail_callsite_hoists),
    ),
  )
  let rewritten = mod_.with_code_sec(@lib.CodeSec::new(next_funcs))
  let total = imports + inl_defined_func_count(rewritten)
  let identity = Array::make(total, 0U)
  let mut idx = 0
  while idx < total {
    identity[idx] = idx.reinterpret_as_uint()
    idx += 1
  }
  match inl_remap_name_sec(rewritten.name_sec, identity, total) {
    Some(names) => rewritten.with_name_sec(names)
    None => rewritten.without_name_sec()
  }
}

///|
fn inl_run_module_pass_once(
  mod_ : @lib.Module,
  optimize : Bool,
  trace : ((String) -> Unit)?,
  pass_name : String,
  optimize_level : Int,
  shrink_level : Int,
  always_inline_max_size : Int,
  one_caller_inline_max_size : Int,
  flexible_inline_max_size : Int,
  max_combined_binary_size : Int,
  allow_functions_with_loops : Bool,
  partial_inlining_ifs : Int,
  perf? : HotPerfSession? = None,
) -> (@lib.Module, Bool, Array[Int]) {
  let prepare_start_us = perf_start_timer_opt(
    perf, "detail:inlining:once:prepare-multivalue-block-types",
  )
  let prepared = inl_prepare_multivalue_block_types(
    mod_, optimize_level, shrink_level,
  )
  perf_stop_timer_opt(
    perf, "detail:inlining:once:prepare-multivalue-block-types", prepare_start_us,
  )
  let split_prepared = inl_apply_partial_pattern_a_splits(
    prepared, optimize_level, shrink_level, always_inline_max_size, one_caller_inline_max_size,
    flexible_inline_max_size, max_combined_binary_size, allow_functions_with_loops,
    partial_inlining_ifs,
  )
  let infos_start_us = perf_start_timer_opt(
    perf, "detail:inlining:once:build-function-infos",
  )
  let infos = inl_build_function_infos(
    split_prepared,
    optimize_level~,
    shrink_level~,
    always_inline_max_size~,
    one_caller_inline_max_size~,
    flexible_inline_max_size~,
    max_combined_binary_size~,
    allow_functions_with_loops~,
  )
  perf_stop_timer_opt(
    perf, "detail:inlining:once:build-function-infos", infos_start_us,
  )
  let rewrite_start_us = perf_start_timer_opt(
    perf, "detail:inlining:once:rewrite-all-calls",
  )
  let result = inl_rewrite_all_calls(split_prepared, infos)
  perf_stop_timer_opt(
    perf, "detail:inlining:once:rewrite-all-calls", rewrite_start_us,
  )
  inl_trace_perf(
    trace,
    "once changed=\{result.changed} touched=\{inl_count_true(result.touched)} inlined_from=\{inl_count_true(result.inlined_from)} funcs=\{inl_defined_func_count(mod_)}",
  )
  if !result.changed {
    let prune_start_us = perf_start_timer_opt(
      perf, "detail:inlining:once:prune-dead-unreachable-drops",
    )
    let pruned = inl_prune_dead_unreachable_drops(mod_)
    perf_stop_timer_opt(
      perf, "detail:inlining:once:prune-dead-unreachable-drops", prune_start_us,
    )
    return (pruned, false, [])
  }
  let original_graph_start_us = perf_start_timer_opt(
    perf, "detail:inlining:once:original-reachable-private-cycle-funcs",
  )
  let original_graph_info = inl_original_reachable_private_cycle_funcs(mod_)
  perf_stop_timer_opt(
    perf, "detail:inlining:once:original-reachable-private-cycle-funcs", original_graph_start_us,
  )
  let preserve_start_us = perf_start_timer_opt(
    perf, "detail:inlining:once:preserve-root-cycle-check",
  )
  let preserve_root_cycle_cleanup = inl_has_same_sig_root_cycle_dead_suffix(
    mod_,
  )
  perf_stop_timer_opt(
    perf, "detail:inlining:once:preserve-root-cycle-check", preserve_start_us,
  )
  inl_trace_nested_cleanup(pass_name, optimize, result.touched, trace)
  // Binaryen's plain `--inlining` deletes private helpers that become dead
  // after direct substitution. The retain-count predictor is for the
  // optimizing cleanup suffix only; using it here preserves dead helper
  // representatives that Binaryen plain mode removes.
  let plain_retain_counts : @hashmap.HashMap[String, Int] = @hashmap.new()
  let remove_helpers_start_us = perf_start_timer_opt(
    perf, "detail:inlining:once:remove-dead-inlined-helpers",
  )
  let removal = inl_remove_dead_inlined_helpers(
    result.mod_out,
    infos,
    result.touched,
    result.inlined_from,
    if optimize {
      original_graph_info.retain_inlined_helper_counts
    } else {
      plain_retain_counts
    },
  )
  perf_stop_timer_opt(
    perf, "detail:inlining:once:remove-dead-inlined-helpers", remove_helpers_start_us,
  )
  inl_trace_perf(
    trace,
    "helpers removed=\{removal.original_abs.length() - inl_defined_func_count(removal.mod_out)} touched=\{inl_count_true(removal.touched)}",
  )
  let touched_original_abs = inl_touched_original_abs(
    removal.touched,
    removal.original_abs,
  )
  if !optimize {
    return (removal.mod_out, true, touched_original_abs)
  }
  let nested_start_us = perf_start_timer_opt(
    perf, "detail:inlining:once:nested-cleanup",
  )
  let nested_cleaned = if preserve_root_cycle_cleanup && optimize {
    inl_compact_unused_locals(
      inl_collapse_unreachable_private_except_used_suffix_roots(removal.mod_out),
      removal.touched,
    )
  } else {
    inl_run_nested_cleanup(
      removal.mod_out,
      optimize,
      trace,
      removal.touched,
      optimize_level,
      shrink_level,
      perf~,
    )
  }
  perf_stop_timer_opt(
    perf, "detail:inlining:once:nested-cleanup", nested_start_us,
  )
  let dead_unreachable_start_us = perf_start_timer_opt(
    perf, "detail:inlining:once:remove-dead-unreachable-private-funcs",
  )
  let cleaned = inl_remove_dead_unreachable_private_funcs(
    nested_cleaned,
    removal.original_abs,
    original_graph_info.cycle_remove,
    original_graph_info.retain_inlined_helper_counts,
  )
  perf_stop_timer_opt(
    perf, "detail:inlining:once:remove-dead-unreachable-private-funcs", dead_unreachable_start_us,
  )
  let collapse_start_us = perf_start_timer_opt(
    perf, "detail:inlining:once:collapse-unreachable-roots",
  )
  let collapsed = if preserve_root_cycle_cleanup {
    inl_collapse_unreachable_private_except_used_suffix_roots(cleaned)
  } else {
    inl_collapse_unreachable_roots(cleaned, removal.touched)
  }
  perf_stop_timer_opt(
    perf, "detail:inlining:once:collapse-unreachable-roots", collapse_start_us,
  )
  let pad_start_us = perf_start_timer_opt(
    perf, "detail:inlining:once:pad-unreachable-to-predicted-counts",
  )
  let padded = inl_pad_unreachable_to_predicted_counts(
    collapsed,
    original_graph_info.predicted_unreachable_counts,
  )
  perf_stop_timer_opt(
    perf, "detail:inlining:once:pad-unreachable-to-predicted-counts", pad_start_us,
  )
  let ordered = if preserve_root_cycle_cleanup &&
    !original_graph_info.skip_trailing_exact_move {
    inl_move_trailing_exact_before_last_nonexact_same_sig(padded)
  } else {
    padded
  }
  ignore(original_graph_info.public_scc_representative)
  let trim_start_us = perf_start_timer_opt(
    perf, "detail:inlining:once:trim-unreachable-to-predicted-counts",
  )
  let trimmed = inl_trim_unreachable_to_predicted_counts(
    ordered,
    original_graph_info.predicted_unreachable_counts,
  )
  perf_stop_timer_opt(
    perf, "detail:inlining:once:trim-unreachable-to-predicted-counts", trim_start_us,
  )
  (trimmed, true, touched_original_abs)
}

///|
fn inlining_run_module_pass_with_perf(
  mod_ : @lib.Module,
  optimize? : Bool = false,
  trace? : ((String) -> Unit)? = None,
  pass_name? : String = "inlining",
  optimize_level? : Int = 0,
  shrink_level? : Int = 0,
  always_inline_max_size? : Int = 2,
  one_caller_inline_max_size? : Int = -1,
  flexible_inline_max_size? : Int = 20,
  max_combined_binary_size? : Int = 400 * 1024,
  allow_functions_with_loops? : Bool = false,
  partial_inlining_ifs? : Int = 0,
  perf? : HotPerfSession? = None,
) -> @lib.Module {
  if pass_module_has_legacy_try(mod_) {
    return mod_
  }
  let initial_graph_start_us = perf_start_timer_opt(
    perf, "detail:inlining:initial-original-reachable-private-cycle-funcs",
  )
  let initial_graph_info = inl_original_reachable_private_cycle_funcs(mod_)
  perf_stop_timer_opt(
    perf, "detail:inlining:initial-original-reachable-private-cycle-funcs", initial_graph_start_us,
  )
  let initial_total = inl_imported_func_count(mod_) +
    inl_defined_func_count(mod_)
  let iteration_counts = Array::make(initial_total, 0)
  let max_iterations_for_func = 5
  let mut current = mod_
  let mut iterations = 0
  let max_iterations = inl_defined_func_count(mod_) + 1
  while iterations < max_iterations {
    let iteration_start_us = perf_start_timer_opt(
      perf, "detail:inlining:iteration",
    )
    let (next, changed, touched_original_abs) = inl_run_module_pass_once(
      current,
      optimize,
      trace,
      pass_name,
      optimize_level,
      shrink_level,
      always_inline_max_size,
      one_caller_inline_max_size,
      flexible_inline_max_size,
      max_combined_binary_size,
      allow_functions_with_loops,
      partial_inlining_ifs,
      perf~,
    )
    perf_stop_timer_opt(perf, "detail:inlining:iteration", iteration_start_us)
    inl_trace_perf(
      trace,
      "iteration index=\{iterations} changed=\{changed} touched_original=\{touched_original_abs.length()} funcs=\{inl_defined_func_count(current)}",
    )
    if !changed {
      let final_trim_start_us = perf_start_timer_opt(
        perf, "detail:inlining:final-trim-unreachable-to-selected-counts",
      )
      let final_trimmed = inl_trim_unreachable_to_selected_counts(
        next,
        initial_graph_info.final_trim_counts,
      )
      perf_stop_timer_opt(
        perf, "detail:inlining:final-trim-unreachable-to-selected-counts", final_trim_start_us,
      )
      let finalize_start_us = perf_start_timer_opt(
        perf, "detail:inlining:finalize-module-pass-result",
      )
      let finalized = inl_finalize_module_pass_result(final_trimmed, optimize)
      perf_stop_timer_opt(
        perf, "detail:inlining:finalize-module-pass-result", finalize_start_us,
      )
      inl_trace_perf(trace, "done iterations=\{iterations} reason=no-change")
      return finalized
    }
    current = next
    iterations += 1
    for original_abs in touched_original_abs {
      if original_abs >= 0 && original_abs < iteration_counts.length() {
        iteration_counts[original_abs] += 1
        if iteration_counts[original_abs] >= max_iterations_for_func {
          return inl_finalize_module_pass_result(
            inl_trim_unreachable_to_selected_counts(
              current,
              initial_graph_info.final_trim_counts,
            ),
            optimize,
          )
        }
      }
    }
    if optimize &&
      inl_hash_has_positive(initial_graph_info.retain_inlined_helper_counts) {
      let touched = Array::make(
        inl_imported_func_count(current) + inl_defined_func_count(current),
        false,
      )
      let collapsed = inl_collapse_unreachable_roots(
        current,
        touched,
        check_dead_suffix_calls=false,
        check_marked_suffix_calls=false,
      )
      let padded = if initial_graph_info.force_predicted_pad_on_retain_return {
        inl_pad_unreachable_to_predicted_counts(
          collapsed,
          initial_graph_info.predicted_unreachable_counts,
        )
      } else {
        collapsed
      }
      return inl_finalize_module_pass_result(
        inl_trim_unreachable_to_selected_counts(
          padded,
          initial_graph_info.final_trim_counts,
        ),
        optimize,
      )
    }
  }
  inl_finalize_module_pass_result(
    inl_trim_unreachable_to_selected_counts(
      current,
      initial_graph_info.final_trim_counts,
    ),
    optimize,
  )
}

///|
pub fn inlining_run_module_pass(
  mod_ : @lib.Module,
  optimize? : Bool = false,
  trace? : ((String) -> Unit)? = None,
  pass_name? : String = "inlining",
  optimize_level? : Int = 0,
  shrink_level? : Int = 0,
  always_inline_max_size? : Int = 2,
  one_caller_inline_max_size? : Int = -1,
  flexible_inline_max_size? : Int = 20,
  max_combined_binary_size? : Int = 400 * 1024,
  allow_functions_with_loops? : Bool = false,
  partial_inlining_ifs? : Int = 0,
) -> @lib.Module {
  inlining_run_module_pass_with_perf(
    mod_,
    optimize~,
    trace~,
    pass_name~,
    optimize_level~,
    shrink_level~,
    always_inline_max_size~,
    one_caller_inline_max_size~,
    flexible_inline_max_size~,
    max_combined_binary_size~,
    allow_functions_with_loops~,
    partial_inlining_ifs~,
  )
}
