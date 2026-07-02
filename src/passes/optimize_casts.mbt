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
  exact : Bool,
  heap_type : @lib.HeapType,
) -> @lib.RefType {
  @lib.RefType::new(nullable, heap_type, exact~)
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
fn oc_comptype_may_overlap(a : @lib.CompType, b : @lib.CompType) -> Bool {
  match (a, b) {
    (@lib.StructCompType(_), @lib.StructCompType(_)) => true
    (@lib.ArrayCompType(_), @lib.ArrayCompType(_)) => true
    (@lib.FuncCompType(_, _), @lib.FuncCompType(_, _)) => true
    _ => false
  }
}

///|
fn oc_heap_never_matches(
  module_ctx : @ir.HotModuleContext,
  source : @lib.HeapType,
  target : @lib.HeapType,
) -> Bool {
  if oc_heap_matches(module_ctx, source, target, 512) {
    return false
  }
  match (source, target) {
    (@lib.AbsHeapTypeHeapType(source_abs), @lib.AbsHeapTypeHeapType(target_abs)) =>
      !oc_abs_heap_matches(source_abs, target_abs) &&
      !oc_abs_heap_matches(target_abs, source_abs)
    (@lib.HeapType(source_idx), @lib.HeapType(target_idx)) =>
      match
        (
          @ir.hot_module_resolve_subtype(module_ctx, source_idx),
          @ir.hot_module_resolve_subtype(module_ctx, target_idx),
        ) {
        (Some(source_subtype), Some(target_subtype)) =>
          !oc_comptype_may_overlap(
            source_subtype.get_comptype(),
            target_subtype.get_comptype(),
          )
        _ => false
      }
    (@lib.HeapType(source_idx), @lib.AbsHeapTypeHeapType(target_abs)) =>
      match @ir.hot_module_resolve_subtype(module_ctx, source_idx) {
        Some(source_subtype) =>
          !oc_comptype_matches_abs(source_subtype.get_comptype(), target_abs)
        None => false
      }
    (@lib.AbsHeapTypeHeapType(source_abs), @lib.HeapType(target_idx)) =>
      match @ir.hot_module_resolve_subtype(module_ctx, target_idx) {
        Some(target_subtype) =>
          !oc_comptype_matches_abs(target_subtype.get_comptype(), source_abs)
        None => false
      }
    _ => false
  }
}

///|
fn oc_ref_never_matches(
  module_ctx : @ir.HotModuleContext,
  source : @lib.RefType,
  target : @lib.RefType,
) -> Bool {
  if source.is_nullable() && target.is_nullable() {
    return false
  }
  if target.is_exact() {
    return source.is_exact() && source.get_heap_type() != target.get_heap_type()
  }
  if source.is_exact() &&
    !oc_heap_matches(
      module_ctx,
      source.get_heap_type(),
      target.get_heap_type(),
      512,
    ) {
    return true
  }
  oc_heap_never_matches(
    module_ctx,
    source.get_heap_type(),
    target.get_heap_type(),
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
fn oc_replace_with_unconditional_br(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Unit {
  let node = @ir.hot_node_get(func, node_id)
  let values : Array[Int] = []
  for i = 0; i < @ir.hot_child_count(func, node_id); i = i + 1 {
    values.push(@ir.hot_child_get(func, node_id, i))
  }
  let temp = @ir.hot_build_br(func, node.imm0, values~)
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_delete_node(func, temp)
  pass_replace_node(ctx, func, node_id, replacement)
}

///|
fn oc_node_children(func : @ir.HotFunc, node_id : Int) -> Array[Int] {
  let children : Array[Int] = []
  for i = 0; i < @ir.hot_child_count(func, node_id); i = i + 1 {
    children.push(@ir.hot_child_get(func, node_id, i))
  }
  children
}

///|
fn oc_node_is_local_get(
  func : @ir.HotFunc,
  node_id : Int,
  local_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet => node.imm0 == local_id
    _ => false
  }
}

///|
fn oc_count_local_gets(
  func : @ir.HotFunc,
  node_id : Int,
  local_id : Int,
) -> Int {
  if !@ir.hot_node_is_live(func, node_id) {
    return 0
  }
  let mut count = if oc_node_is_local_get(func, node_id, local_id) {
    1
  } else {
    0
  }
  let children = oc_node_children(func, node_id)
  for child_id in children {
    count += oc_count_local_gets(func, child_id, local_id)
  }
  count
}

///|
fn oc_retarget_local_gets(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  local_id : Int,
  fresh_local : Int,
) -> Int {
  if !@ir.hot_node_is_live(func, node_id) {
    return 0
  }
  let children = oc_node_children(func, node_id)
  let mut count = 0
  if oc_node_is_local_get(func, node_id, local_id) {
    let temp = @ir.hot_build_local_get(func, fresh_local)
    let replacement = @ir.hot_node_get(func, temp)
    @ir.hot_delete_node(func, temp)
    pass_replace_node(ctx, func, node_id, replacement)
    count += 1
  }
  for child_id in children {
    count += oc_retarget_local_gets(ctx, func, child_id, local_id, fresh_local)
  }
  count
}

///|
fn oc_collect_written_locals(
  func : @ir.HotFunc,
  node_id : Int,
  writes : Array[Int],
) -> Unit {
  if !@ir.hot_node_is_live(func, node_id) {
    return
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => writes.push(node.imm0)
    _ => ()
  }
  let children = oc_node_children(func, node_id)
  for child_id in children {
    oc_collect_written_locals(func, child_id, writes)
  }
}

///|
fn oc_refinement_source_local(func : @ir.HotFunc, node_id : Int) -> Int? {
  let requires_nullable_source = match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::RefCast(_, _, _)) => false
    Some(@lib.Instruction::RefAsNonNull) => true
    _ => return None
  }
  if @ir.hot_child_count(func, node_id) != 1 {
    return None
  }
  let child_id = @ir.hot_child_get(func, node_id, 0)
  let child = @ir.hot_node_get(func, child_id)
  match child.op {
    @ir.HotOp::LocalGet | @ir.HotOp::LocalTee => {
      if requires_nullable_source {
        match oc_ref_type_from_node(func, child_id) {
          Some(ref_type) => if !ref_type.is_nullable() { return None }
          None => return None
        }
      }
      Some(child.imm0)
    }
    _ => None
  }
}

///|
fn oc_contains_local(locals : Array[Int], local_id : Int) -> Bool {
  for written in locals {
    if written == local_id {
      return true
    }
  }
  false
}

///|
fn oc_collect_refinements(
  func : @ir.HotFunc,
  node_id : Int,
  out : Array[(Int, Int)],
) -> Unit {
  if !@ir.hot_node_is_live(func, node_id) {
    return
  }
  match oc_refinement_source_local(func, node_id) {
    Some(local_id) => out.push((local_id, node_id))
    None => ()
  }
  let children = oc_node_children(func, node_id)
  for child_id in children {
    oc_collect_refinements(func, child_id, out)
  }
}

///|
fn oc_refinements_include_local(
  refinements : Array[(Int, Int)],
  local_id : Int,
) -> Bool {
  for refinement in refinements {
    if refinement.0 == local_id {
      return true
    }
  }
  false
}

///|
fn oc_cast_is_more_refined(
  module_ctx : @ir.HotModuleContext,
  func : @ir.HotFunc,
  candidate_id : Int,
  current_id : Int,
) -> Bool {
  let candidate = match oc_ref_type_from_node(func, candidate_id) {
    Some(ref_type) => ref_type
    None => return false
  }
  let current = match oc_ref_type_from_node(func, current_id) {
    Some(ref_type) => ref_type
    None => return true
  }
  candidate != current && oc_ref_always_matches(module_ctx, candidate, current)
}

///|
fn oc_wrap_refinement_with_tee(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  cast_id : Int,
  fresh_local : Int,
) -> Bool {
  if !@ir.hot_node_is_live(func, cast_id) {
    return false
  }
  let cast_node = @ir.hot_node_get(func, cast_id)
  let clone = @ir.hot_build_node(
    func,
    cast_node.op,
    cast_node.ty,
    imm0=cast_node.imm0,
    imm1=cast_node.imm1,
    children=oc_node_children(func, cast_id),
  )
  let tee = @ir.hot_build_local_tee(func, fresh_local, clone)
  let replacement = @ir.hot_node_get(func, tee)
  @ir.hot_delete_node(func, tee)
  pass_replace_node(ctx, func, cast_id, replacement)
  true
}

///|
fn oc_later_reuse_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  module_ctx : @ir.HotModuleContext,
) -> Bool {
  let local_count = @ir.hot_local_count(func)
  let best_casts = Array::make(local_count, -1)
  let fresh_locals = Array::make(local_count, -1)
  let mut changed = false
  let root_count = @ir.hot_root_count(func)
  for root_idx = 0; root_idx < root_count; root_idx = root_idx + 1 {
    let root_id = @ir.hot_root_get(func, root_idx)
    let writes : Array[Int] = []
    oc_collect_written_locals(func, root_id, writes)
    let refinements : Array[(Int, Int)] = []
    oc_collect_refinements(func, root_id, refinements)
    for local_id = 0; local_id < local_count; local_id = local_id + 1 {
      let best_cast = best_casts[local_id]
      if best_cast >= 0 &&
        !oc_contains_local(writes, local_id) &&
        !oc_refinements_include_local(refinements, local_id) &&
        oc_count_local_gets(func, root_id, local_id) > 0 {
        let fresh_local = if fresh_locals[local_id] >= 0 {
          fresh_locals[local_id]
        } else {
          let ref_type = match oc_ref_type_from_node(func, best_cast) {
            Some(ref_type) => ref_type
            None => continue
          }
          let fresh_ref_type = @lib.RefType::new(
            true,
            ref_type.get_heap_type(),
            exact=ref_type.is_exact(),
          )
          let fresh = @ir.hot_append_body_local(
            func,
            @lib.ValType::ref_type(fresh_ref_type),
          )
          fresh_locals[local_id] = fresh
          ignore(oc_wrap_refinement_with_tee(ctx, func, best_cast, fresh))
          fresh
        }
        if oc_retarget_local_gets(ctx, func, root_id, local_id, fresh_local) > 0 {
          changed = true
        }
      }
    }
    for local_id in writes {
      if local_id >= 0 && local_id < local_count {
        best_casts[local_id] = -1
        fresh_locals[local_id] = -1
      }
    }
    for refinement in refinements {
      let (local_id, cast_id) = refinement
      if local_id >= 0 && local_id < local_count {
        if best_casts[local_id] < 0 ||
          oc_cast_is_more_refined(
            module_ctx,
            func,
            cast_id,
            best_casts[local_id],
          ) {
          best_casts[local_id] = cast_id
          fresh_locals[local_id] = -1
        }
      }
    }
  }
  changed
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
    Some(@lib.Instruction::RefCast(nullable, exact, heap_type))
    | Some(@lib.Instruction::RefCastDescEq(nullable, exact, heap_type)) => {
      if @ir.hot_child_count(func, node_id) != 1 {
        return false
      }
      let child_id = @ir.hot_child_get(func, node_id, 0)
      match oc_ref_type_from_node(func, child_id) {
        Some(source_ref) => {
          let target_ref = oc_target_ref_type(nullable, exact, heap_type)
          if oc_ref_always_matches(module_ctx, source_ref, target_ref) {
            oc_replace_with_child(ctx, func, node_id)
            return true
          }
        }
        None => ()
      }
      false
    }
    Some(@lib.Instruction::RefTest(nullable, heap_type))
    | Some(@lib.Instruction::RefTestDesc(nullable, heap_type)) => {
      if @ir.hot_child_count(func, node_id) != 1 {
        return false
      }
      let child_id = @ir.hot_child_get(func, node_id, 0)
      match oc_ref_type_from_node(func, child_id) {
        Some(source_ref) => {
          let target_ref = oc_target_ref_type(nullable, false, heap_type)
          if oc_ref_always_matches(module_ctx, source_ref, target_ref) {
            oc_replace_with_const_i32(ctx, func, node_id, 1)
            return true
          }
          if oc_ref_never_matches(module_ctx, source_ref, target_ref) {
            oc_replace_with_const_i32(ctx, func, node_id, 0)
            return true
          }
        }
        None => ()
      }
      false
    }
    Some(@lib.Instruction::BrOnCast(_, @lib.CastOp(_, nullable), _, heap_type)) => {
      if @ir.hot_child_count(func, node_id) == 0 {
        return false
      }
      let child_id = @ir.hot_child_get(
        func,
        node_id,
        @ir.hot_child_count(func, node_id) - 1,
      )
      match oc_ref_type_from_node(func, child_id) {
        Some(source_ref) => {
          let target_ref = oc_target_ref_type(nullable, false, heap_type)
          if oc_ref_always_matches(module_ctx, source_ref, target_ref) {
            oc_replace_with_unconditional_br(ctx, func, node_id)
            return true
          }
          if oc_ref_never_matches(module_ctx, source_ref, target_ref) &&
            @ir.hot_child_count(func, node_id) == 1 {
            oc_replace_with_child(ctx, func, node_id)
            return true
          }
        }
        None => ()
      }
      false
    }
    Some(
      @lib.Instruction::BrOnCastFail(_, @lib.CastOp(_, nullable), _, heap_type)
    ) => {
      if @ir.hot_child_count(func, node_id) != 1 {
        return false
      }
      let child_id = @ir.hot_child_get(func, node_id, 0)
      match oc_ref_type_from_node(func, child_id) {
        Some(source_ref) => {
          let target_ref = oc_target_ref_type(nullable, false, heap_type)
          if oc_ref_always_matches(module_ctx, source_ref, target_ref) {
            oc_replace_with_child(ctx, func, node_id)
            return true
          }
          if oc_ref_never_matches(module_ctx, source_ref, target_ref) {
            oc_replace_with_unconditional_br(ctx, func, node_id)
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
  if oc_later_reuse_run(ctx, func, module_ctx) {
    changed = true
  }
  if changed {
    HotPassResult::changed()
  } else {
    HotPassResult::unchanged()
  }
}
