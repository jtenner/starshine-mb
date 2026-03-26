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
fn remove_unused_names_control_block_type(
  func : @ir.HotFunc,
  node_id : Int,
) -> @lib.BlockType {
  match @ir.hot_type_get(func, @ir.hot_node_get(func, node_id).ty) {
    @ir.HotTypeInfo::BlockResult(block_type) => block_type
    @ir.HotTypeInfo::BlockResultResolved(block_type, _) => block_type
    _ => @lib.BlockType::void_()
  }
}

///|
fn remove_unused_names_region_roots(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Array[Int] {
  let roots : Array[Int] = []
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    roots.push(@ir.hot_region_get(func, region_ref, idx))
  }
  roots
}

///|
fn remove_unused_names_targets_any_label(
  func : @ir.HotFunc,
  roots : Array[Int],
  removed : Array[Bool],
) -> Bool {
  match
    @ir.hot_worklist_walk(func, roots, false, fn(
      _,
      node_id,
    ) -> @ir.HotVisitCtl[Bool, Unit] {
      let node = @ir.hot_node_get(func, node_id)
      let has_removed = fn(label_id : Int) {
        label_id >= 0 && label_id < removed.length() && removed[label_id]
      }
      match @ir.hot_branch_target(func, node_id) {
        Some(label_id) if has_removed(label_id) =>
          return @ir.hot_visit_stop(true)
        _ => ()
      }
      match node.op {
        @ir.HotOp::BrTable =>
          for label_id in @ir.hot_branch_table_targets_for_node(func, node_id) {
            if has_removed(label_id) {
              return @ir.hot_visit_stop(true)
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
            if has_removed(label_id) {
              return @ir.hot_visit_stop(true)
            }
          }
        }
        _ => ()
      }
      @ir.hot_visit_continue(false)
    }) {
    Ok(found) => found
    Err(_) => false
  }
}

///|
fn remove_unused_names_targets_label(
  func : @ir.HotFunc,
  roots : Array[Int],
  label_id : Int,
) -> Bool {
  if label_id < 0 {
    return false
  }
  let targets : Array[Bool] = []
  for _ in 0..<func.labels.length() {
    targets.push(false)
  }
  targets[label_id] = true
  remove_unused_names_targets_any_label(func, roots, targets)
}

///|
fn remove_unused_names_peel_same_typed_blocks(
  func : @ir.HotFunc,
  block_id : Int,
) -> (Array[Int], Array[Int]) {
  let removed_ids : Array[Int] = []
  let block_type = remove_unused_names_control_block_type(func, block_id)
  let mut region_ref = @ir.hot_region_body_ref(func, block_id)
  while @ir.hot_region_root_count(func, region_ref) == 1 {
    let child_id = @ir.hot_region_get(func, region_ref, 0)
    if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
      break
    }
    let child = @ir.hot_node_get(func, child_id)
    match child.op {
      @ir.HotOp::Block =>
        if remove_unused_names_control_block_type(func, child_id) != block_type {
          break
        }
      _ => break
    }
    removed_ids.push(child_id)
    region_ref = @ir.hot_region_body_ref(func, child_id)
  }
  (removed_ids, remove_unused_names_region_roots(func, region_ref))
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
fn remove_unused_names_visit_region(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let mut changed = false
  let mut idx = 0
  while idx < @ir.hot_region_root_count(func, region_ref) {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    changed = remove_unused_names_visit_node(func, node_id) || changed
    idx = idx + 1
  }
  changed
}

///|
fn remove_unused_names_demote_loop(func : @ir.HotFunc, node_id : Int) -> Unit {
  @ir.hot_control_demote_loop_to_block(func, node_id)
}

///|
fn remove_unused_names_visit_node(func : @ir.HotFunc, node_id : Int) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  let mut changed = false
  match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      changed = remove_unused_names_visit_region(
          func,
          @ir.hot_region_body_ref(func, node_id),
        ) ||
        changed
    @ir.HotOp::If => {
      changed = remove_unused_names_visit_region(
          func,
          @ir.hot_region_then_ref(func, node_id),
        ) ||
        changed
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          changed = remove_unused_names_visit_region(func, else_region) ||
            changed
        None => ()
      }
    }
    @ir.HotOp::Try => {
      changed = remove_unused_names_visit_region(
          func,
          @ir.hot_region_body_ref(func, node_id),
        ) ||
        changed
      match @ir.hot_region_catch_ref(func, node_id) {
        Some(catch_region) =>
          changed = remove_unused_names_visit_region(func, catch_region) ||
            changed
        None => ()
      }
    }
    @ir.HotOp::TryTable => {
      changed = remove_unused_names_visit_region(
          func,
          @ir.hot_region_body_ref(func, node_id),
        ) ||
        changed
      changed = remove_unused_names_visit_region(
          func,
          @ir.hot_region_catch_list_ref(func, node_id),
        ) ||
        changed
    }
    _ => return false
  }

  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Block => {
      let (removed_ids, peeled_roots) = remove_unused_names_peel_same_typed_blocks(
        func, node_id,
      )
      if removed_ids.is_empty() {
        return changed
      }
      let removed_labels : Array[Bool] = []
      for _ in 0..<func.labels.length() {
        removed_labels.push(false)
      }
      for removed_id in removed_ids {
        removed_labels[@ir.hot_control_node_label(func, removed_id)] = true
      }
      if remove_unused_names_targets_any_label(
          func, peeled_roots, removed_labels,
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
      let body_roots = remove_unused_names_region_roots(
        func,
        @ir.hot_region_body_ref(func, node_id),
      )
      if remove_unused_names_targets_label(func, body_roots, label_id) {
        return changed
      }
      remove_unused_names_demote_loop(func, node_id)
      true
    }
    _ => changed
  }
}

///|
fn remove_unused_names_has_candidate_in_region(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    if remove_unused_names_has_candidate_in_node(
        func,
        @ir.hot_region_get(func, region_ref, idx),
      ) {
      return true
    }
  }
  false
}

///|
fn remove_unused_names_has_candidate_in_node(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Loop => return true
    @ir.HotOp::Block => {
      let region_ref = @ir.hot_region_body_ref(func, node_id)
      if @ir.hot_region_root_count(func, region_ref) == 1 {
        let child_id = @ir.hot_region_get(func, region_ref, 0)
        if child_id >= 0 && @ir.hot_node_is_live(func, child_id) {
          let child = @ir.hot_node_get(func, child_id)
          match child.op {
            @ir.HotOp::Block =>
              if remove_unused_names_control_block_type(func, child_id) ==
                remove_unused_names_control_block_type(func, node_id) {
                return true
              }
            _ => ()
          }
        }
      }
      return remove_unused_names_has_candidate_in_region(func, region_ref)
    }
    @ir.HotOp::If => {
      if remove_unused_names_has_candidate_in_region(
          func,
          @ir.hot_region_then_ref(func, node_id),
        ) {
        return true
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          return remove_unused_names_has_candidate_in_region(func, else_region)
        None => return false
      }
    }
    @ir.HotOp::Try => {
      if remove_unused_names_has_candidate_in_region(
          func,
          @ir.hot_region_body_ref(func, node_id),
        ) {
        return true
      }
      match @ir.hot_region_catch_ref(func, node_id) {
        Some(catch_region) =>
          return remove_unused_names_has_candidate_in_region(func, catch_region)
        None => return false
      }
    }
    @ir.HotOp::TryTable =>
      return remove_unused_names_has_candidate_in_region(
          func,
          @ir.hot_region_body_ref(func, node_id),
        ) ||
        remove_unused_names_has_candidate_in_region(
          func,
          @ir.hot_region_catch_list_ref(func, node_id),
        )
    _ => return false
  }
}

///|
fn remove_unused_names_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> HotPassResult {
  if !remove_unused_names_has_candidate_in_region(
      func,
      @ir.HotRegionRef::root(),
    ) {
    return HotPassResult::unchanged()
  }
  if !remove_unused_names_visit_region(func, @ir.HotRegionRef::root()) {
    return HotPassResult::unchanged()
  }
  pass_mark_mutated(ctx, func)
  HotPassResult::changed()
}
