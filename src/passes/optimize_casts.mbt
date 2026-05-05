///|
pub fn optimize_casts_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new("optimize-casts", invalidates=[
    @ir.HotAnalysis::cfg(),
    @ir.HotAnalysis::dominance(),
    @ir.HotAnalysis::liveness(),
    @ir.HotAnalysis::use_def(),
    @ir.HotAnalysis::effects(),
    @ir.HotAnalysis::loop_info(),
    @ir.HotAnalysis::ssa(),
  ])
}

///|
pub fn optimize_casts_summary() -> String {
  "Remove provably redundant GC casts and fold ref.test outcomes from static reference types."
}

///|
fn oc_abs_heap_matches(
  source : @lib.AbsHeapType,
  target : @lib.AbsHeapType,
) -> Bool {
  if source == target {
    return true
  }
  match (source, target) {
    (@lib.NoneAbsHeapType, @lib.StructAbsHeapType)
    | (@lib.NoneAbsHeapType, @lib.ArrayAbsHeapType)
    | (@lib.NoneAbsHeapType, @lib.EqAbsHeapType)
    | (@lib.NoneAbsHeapType, @lib.AnyAbsHeapType)
    | (@lib.NoFuncAbsHeapType, @lib.FuncAbsHeapType)
    | (@lib.NoFuncAbsHeapType, @lib.AnyAbsHeapType)
    | (@lib.NoExternAbsHeapType, @lib.ExternAbsHeapType)
    | (@lib.NoExnAbsHeapType, @lib.ExnAbsHeapType)
    | (@lib.I31AbsHeapType, @lib.EqAbsHeapType)
    | (@lib.I31AbsHeapType, @lib.AnyAbsHeapType)
    | (@lib.StructAbsHeapType, @lib.EqAbsHeapType)
    | (@lib.StructAbsHeapType, @lib.AnyAbsHeapType)
    | (@lib.ArrayAbsHeapType, @lib.EqAbsHeapType)
    | (@lib.ArrayAbsHeapType, @lib.AnyAbsHeapType)
    | (@lib.EqAbsHeapType, @lib.AnyAbsHeapType)
    | (@lib.FuncAbsHeapType, @lib.AnyAbsHeapType)
    | (@lib.ExternAbsHeapType, @lib.AnyAbsHeapType) => true
    _ => false
  }
}

///|
fn oc_comptype_matches_abs(ct : @lib.CompType, abs : @lib.AbsHeapType) -> Bool {
  match ct {
    @lib.StructCompType(_) =>
      abs == @lib.AbsHeapType::struct_() ||
      abs == @lib.AbsHeapType::eq() ||
      abs == @lib.AbsHeapType::any()
    @lib.ArrayCompType(_) =>
      abs == @lib.AbsHeapType::array() ||
      abs == @lib.AbsHeapType::eq() ||
      abs == @lib.AbsHeapType::any()
    @lib.FuncCompType(_, _) =>
      abs == @lib.AbsHeapType::func() || abs == @lib.AbsHeapType::any()
  }
}

///|
fn oc_subtype_as_heap_matches(
  module_ctx : @ir.HotModuleContext,
  subtype : @lib.SubType,
  target : @lib.HeapType,
  fuel : Int,
) -> Bool {
  if fuel <= 0 {
    return false
  }
  let (is_final, supers, ct) = match subtype {
    @lib.CompTypeSubType(_, ct) => (false, [], ct)
    @lib.SubType(is_final, supers, _, ct) => (is_final, supers, ct)
  }
  match target {
    @lib.AbsHeapTypeHeapType(abs) => {
      if oc_comptype_matches_abs(ct, abs) {
        return true
      }
      if is_final {
        return false
      }
    }
    _ => ()
  }
  for super_idx in supers {
    if oc_heap_matches(
        module_ctx,
        @lib.HeapType::new(super_idx),
        target,
        fuel - 1,
      ) {
      return true
    }
  }
  false
}

///|
fn oc_heap_matches(
  module_ctx : @ir.HotModuleContext,
  source : @lib.HeapType,
  target : @lib.HeapType,
  fuel : Int,
) -> Bool {
  if source == target {
    return true
  }
  if fuel <= 0 {
    return false
  }
  match (source, target) {
    (@lib.AbsHeapTypeHeapType(source_abs), @lib.AbsHeapTypeHeapType(target_abs)) =>
      oc_abs_heap_matches(source_abs, target_abs)
    (@lib.HeapType(source_idx), _) =>
      match @ir.hot_module_resolve_subtype(module_ctx, source_idx) {
        Some(subtype) =>
          oc_subtype_as_heap_matches(module_ctx, subtype, target, fuel - 1)
        None => false
      }
    (_, @lib.HeapType(target_idx)) =>
      match source {
        @lib.AbsHeapTypeHeapType(@lib.NoneAbsHeapType) =>
          match @ir.hot_module_resolve_subtype(module_ctx, target_idx) {
            Some(subtype) =>
              match subtype.get_comptype() {
                @lib.StructCompType(_) | @lib.ArrayCompType(_) => true
                _ => false
              }
            None => false
          }
        @lib.AbsHeapTypeHeapType(@lib.NoFuncAbsHeapType) =>
          match @ir.hot_module_resolve_subtype(module_ctx, target_idx) {
            Some(subtype) =>
              match subtype.get_comptype() {
                @lib.FuncCompType(_, _) => true
                _ => false
              }
            None => false
          }
        _ => false
      }
    _ => false
  }
}

///|
fn oc_ref_type_from_node(func : @ir.HotFunc, node_id : Int) -> @lib.RefType? {
  let results = @ir.hot_type_results(func, @ir.hot_node_type(func, node_id))
  if results.length() != 1 {
    return None
  }
  match results[0] {
    @lib.RefTypeValType(ref_type) => Some(ref_type)
    _ => None
  }
}

///|
fn oc_target_ref_type(
  nullable : Bool,
  heap_type : @lib.HeapType,
) -> @lib.RefType {
  @lib.RefType::new(nullable, heap_type)
}

///|
fn oc_ref_always_matches(
  module_ctx : @ir.HotModuleContext,
  source : @lib.RefType,
  target : @lib.RefType,
) -> Bool {
  if source.is_nullable() && !target.is_nullable() {
    return false
  }
  if target.is_exact() {
    return source.is_exact() && source.get_heap_type() == target.get_heap_type()
  }
  oc_heap_matches(
    module_ctx,
    source.get_heap_type(),
    target.get_heap_type(),
    512,
  )
}

///|
fn oc_replace_with_child(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Unit {
  if @ir.hot_child_count(func, node_id) != 1 {
    return
  }
  let child_id = @ir.hot_child_get(func, node_id, 0)
  pass_replace_node(ctx, func, node_id, @ir.hot_node_get(func, child_id))
}

///|
fn oc_replace_with_const_i32(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  value : Int,
) -> Unit {
  let temp = @ir.hot_build_const_i32(func, @lib.I32(value))
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_delete_node(func, temp)
  pass_replace_node(ctx, func, node_id, replacement)
}

///|
fn oc_rewrite_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  module_ctx : @ir.HotModuleContext,
  node_id : Int,
) -> Bool {
  if !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::RefCast(nullable, heap_type)) => {
      if @ir.hot_child_count(func, node_id) != 1 {
        return false
      }
      let child_id = @ir.hot_child_get(func, node_id, 0)
      match oc_ref_type_from_node(func, child_id) {
        Some(source_ref) => {
          let target_ref = oc_target_ref_type(nullable, heap_type)
          if oc_ref_always_matches(module_ctx, source_ref, target_ref) {
            oc_replace_with_child(ctx, func, node_id)
            return true
          }
        }
        None => ()
      }
      false
    }
    Some(@lib.Instruction::RefTest(nullable, heap_type)) => {
      if @ir.hot_child_count(func, node_id) != 1 {
        return false
      }
      let child_id = @ir.hot_child_get(func, node_id, 0)
      match oc_ref_type_from_node(func, child_id) {
        Some(source_ref) => {
          let target_ref = oc_target_ref_type(nullable, heap_type)
          if oc_ref_always_matches(module_ctx, source_ref, target_ref) {
            oc_replace_with_const_i32(ctx, func, node_id, 1)
            return true
          }
        }
        None => ()
      }
      false
    }
    _ => false
  }
}

///|
pub fn optimize_casts_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> HotPassResult {
  let module_ctx = match ctx.module_ctx {
    Some(module_ctx) => module_ctx
    None => return HotPassResult::unchanged()
  }
  let mut changed = false
  let node_count = func.nodes.length()
  for node_id = 0; node_id < node_count; node_id = node_id + 1 {
    if oc_rewrite_node(ctx, func, module_ctx, node_id) {
      changed = true
    }
  }
  if changed {
    HotPassResult::changed()
  } else {
    HotPassResult::unchanged()
  }
}
