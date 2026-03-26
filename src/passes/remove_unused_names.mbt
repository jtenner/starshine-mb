///|
pub fn remove_unused_names_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new("remove-unused-names", invalidates=[
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
pub fn remove_unused_names_summary() -> String {
  "Peel redundant same-typed block wrappers and demote loops whose labels have no remaining continue targets."
}

///|
fn remove_unused_names_control_block_type_for_ty(
  func : @ir.HotFunc,
  ty : Int,
) -> @lib.BlockType {
  match @ir.hot_type_get(func, ty) {
    @ir.HotTypeInfo::BlockResult(block_type) => block_type
    @ir.HotTypeInfo::BlockResultResolved(block_type, _) => block_type
    _ => @lib.BlockType::void_()
  }
}

///|
fn remove_unused_names_same_control_block_type(
  func : @ir.HotFunc,
  lhs_ty : Int,
  rhs_ty : Int,
) -> Bool {
  lhs_ty == rhs_ty ||
  remove_unused_names_control_block_type_for_ty(func, lhs_ty) ==
  remove_unused_names_control_block_type_for_ty(func, rhs_ty)
}

///|
fn remove_unused_names_compute_label_used(func : @ir.HotFunc) -> Array[Bool] {
  let label_used = Array::make(func.labels.length(), false)
  let mark_label = fn(label_id : Int) {
    if label_id >= 0 && label_id < label_used.length() {
      label_used[label_id] = true
    }
  }
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Br
      | @ir.HotOp::BrIf
      | @ir.HotOp::BrOnNull
      | @ir.HotOp::BrOnNonNull
      | @ir.HotOp::BrOnCast
      | @ir.HotOp::BrOnCastFail
      | @ir.HotOp::Delegate => mark_label(node.imm0)
      @ir.HotOp::BrTable => {
        mark_label(@ir.hot_branch_table_default_target(func, node.imm0))
        for label_id in @ir.hot_branch_table_targets(func, node.imm0) {
          mark_label(label_id)
        }
      }
      @ir.HotOp::TryTable => {
        let info = @ir.hot_catch_info_get(func, node.imm1)
        for catch_ in info.catches {
          let label_id = match catch_ {
            @ir.HotCatchArm::CatchArm(_, label_id)
            | @ir.HotCatchArm::CatchRefArm(_, label_id)
            | @ir.HotCatchArm::CatchAllArm(label_id)
            | @ir.HotCatchArm::CatchAllRefArm(label_id) => label_id
          }
          mark_label(label_id)
        }
      }
      _ => ()
    }
  }
  label_used
}

///|
fn remove_unused_names_label_is_used(
  label_id : Int,
  label_used : Array[Bool],
) -> Bool {
  label_id >= 0 && label_id < label_used.length() && label_used[label_id]
}

///|
fn remove_unused_names_any_removed_label_used(
  func : @ir.HotFunc,
  removed_ids : Array[Int],
  label_used : Array[Bool],
) -> Bool {
  for removed_id in removed_ids {
    if remove_unused_names_label_is_used(
        @ir.hot_control_node_label(func, removed_id),
        label_used,
      ) {
      return true
    }
  }
  false
}

///|
fn remove_unused_names_peel_same_typed_blocks(
  func : @ir.HotFunc,
  block_id : Int,
  removed_ids : Array[Int],
  roots : Array[Int],
) -> Unit {
  removed_ids.clear()
  let block_ty = @ir.hot_node_get(func, block_id).ty
  let block_type = remove_unused_names_control_block_type_for_ty(func, block_ty)
  let mut region_ref = @ir.hot_region_body_ref(func, block_id)
  while @ir.hot_region_root_count(func, region_ref) == 1 {
    let child_id = @ir.hot_region_get(func, region_ref, 0)
    if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
      break
    }
    let child = @ir.hot_node_get(func, child_id)
    match child.op {
      @ir.HotOp::Block =>
        if child.ty != block_ty &&
          remove_unused_names_control_block_type_for_ty(func, child.ty) !=
          block_type {
          break
        }
      _ => break
    }
    removed_ids.push(child_id)
    region_ref = @ir.hot_region_body_ref(func, child_id)
  }
  if removed_ids.is_empty() {
    return
  }
  roots.clear()
  let root_count = @ir.hot_region_root_count(func, region_ref)
  for idx = 0; idx < root_count; idx = idx + 1 {
    roots.push(@ir.hot_region_get(func, region_ref, idx))
  }
}

///|
fn remove_unused_names_detach_peeled_blocks(
  func : @ir.HotFunc,
  removed_ids : Array[Int],
) -> Unit {
  for removed_id in removed_ids {
    @ir.hot_region_replace_body(
      func,
      @ir.hot_region_body_ref(func, removed_id),
      [],
    )
  }
}

///|
fn remove_unused_names_has_candidate(func : @ir.HotFunc) -> Bool {
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Loop => return true
      @ir.HotOp::Block => {
        let region_ref = @ir.hot_region_body_ref(func, node_id)
        if @ir.hot_region_root_count(func, region_ref) != 1 {
          continue
        }
        let child_id = @ir.hot_region_get(func, region_ref, 0)
        if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
          continue
        }
        let child = @ir.hot_node_get(func, child_id)
        match child.op {
          @ir.HotOp::Block =>
            if remove_unused_names_same_control_block_type(
                func,
                child.ty,
                node.ty,
              ) {
              return true
            }
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn remove_unused_names_visit_region(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  label_used : Array[Bool],
  removed_ids : Array[Int],
  peeled_roots : Array[Int],
) -> Bool {
  let mut changed = false
  let root_count = @ir.hot_region_root_count(func, region_ref)
  let mut idx = 0
  while idx < root_count {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id >= 0 && @ir.hot_node_is_live(func, node_id) {
      let node = @ir.hot_node_get(func, node_id)
      match node.op {
        @ir.HotOp::Block
        | @ir.HotOp::Loop
        | @ir.HotOp::If
        | @ir.HotOp::Try
        | @ir.HotOp::TryTable =>
          changed = remove_unused_names_visit_control_node(
              func, node_id, node, label_used, removed_ids, peeled_roots,
            ) ||
            changed
        _ => ()
      }
    }
    idx = idx + 1
  }
  changed
}

///|
fn remove_unused_names_demote_loop(func : @ir.HotFunc, node_id : Int) -> Unit {
  @ir.hot_control_demote_loop_to_block(func, node_id)
}

///|
fn remove_unused_names_visit_control_node(
  func : @ir.HotFunc,
  node_id : Int,
  node : @ir.HotNode,
  label_used : Array[Bool],
  removed_ids : Array[Int],
  peeled_roots : Array[Int],
) -> Bool {
  let mut changed = false
  match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      changed = remove_unused_names_visit_region(
          func,
          @ir.hot_region_body_ref(func, node_id),
          label_used,
          removed_ids,
          peeled_roots,
        ) ||
        changed
    @ir.HotOp::If => {
      changed = remove_unused_names_visit_region(
          func,
          @ir.hot_region_then_ref(func, node_id),
          label_used,
          removed_ids,
          peeled_roots,
        ) ||
        changed
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          changed = remove_unused_names_visit_region(
              func, else_region, label_used, removed_ids, peeled_roots,
            ) ||
            changed
        None => ()
      }
    }
    @ir.HotOp::Try => {
      changed = remove_unused_names_visit_region(
          func,
          @ir.hot_region_body_ref(func, node_id),
          label_used,
          removed_ids,
          peeled_roots,
        ) ||
        changed
      match @ir.hot_region_catch_ref(func, node_id) {
        Some(catch_region) =>
          changed = remove_unused_names_visit_region(
              func, catch_region, label_used, removed_ids, peeled_roots,
            ) ||
            changed
        None => ()
      }
    }
    @ir.HotOp::TryTable => {
      changed = remove_unused_names_visit_region(
          func,
          @ir.hot_region_body_ref(func, node_id),
          label_used,
          removed_ids,
          peeled_roots,
        ) ||
        changed
      changed = remove_unused_names_visit_region(
          func,
          @ir.hot_region_catch_list_ref(func, node_id),
          label_used,
          removed_ids,
          peeled_roots,
        ) ||
        changed
    }
    _ => return false
  }

  match node.op {
    @ir.HotOp::Block => {
      remove_unused_names_peel_same_typed_blocks(
        func, node_id, removed_ids, peeled_roots,
      )
      if removed_ids.is_empty() {
        return changed
      }
      if remove_unused_names_any_removed_label_used(
          func, removed_ids, label_used,
        ) {
        return changed
      }
      @ir.hot_region_replace_body(
        func,
        @ir.hot_region_body_ref(func, node_id),
        peeled_roots,
      )
      remove_unused_names_detach_peeled_blocks(func, removed_ids)
      true
    }
    @ir.HotOp::Loop => {
      let label_id = @ir.hot_control_node_label(func, node_id)
      if remove_unused_names_label_is_used(label_id, label_used) {
        return changed
      }
      remove_unused_names_demote_loop(func, node_id)
      true
    }
    _ => changed
  }
}

///|
fn remove_unused_names_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> HotPassResult {
  if !remove_unused_names_has_candidate(func) {
    return HotPassResult::unchanged()
  }
  let label_used = remove_unused_names_compute_label_used(func)
  let removed_ids : Array[Int] = []
  let peeled_roots : Array[Int] = []
  if !remove_unused_names_visit_region(
      func,
      @ir.HotRegionRef::root(),
      label_used,
      removed_ids,
      peeled_roots,
    ) {
    return HotPassResult::unchanged()
  }
  pass_mark_mutated(ctx, func)
  HotPassResult::changed()
}
