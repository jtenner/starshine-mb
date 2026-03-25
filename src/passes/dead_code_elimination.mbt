///|
pub fn dead_code_elimination_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new(
    "dead-code-elimination",
    requires=[@ir.HotAnalysis::use_def(), @ir.HotAnalysis::effects()],
    invalidates=[
      @ir.HotAnalysis::cfg(),
      @ir.HotAnalysis::dominance(),
      @ir.HotAnalysis::liveness(),
      @ir.HotAnalysis::use_def(),
      @ir.HotAnalysis::effects(),
      @ir.HotAnalysis::loop_info(),
      @ir.HotAnalysis::ssa(),
    ],
  )
}

///|
pub fn dead_code_elimination_summary() -> String {
  "Prune unreachable tails, dead dropped values, and dead-result structured control in hot IR regions."
}

///|
fn dead_code_elimination_has_fallthrough(op : @ir.HotOp) -> Bool {
  let edge_kinds = @ir.cfg_terminator_edge_kinds(op)
  if edge_kinds.length() == 0 {
    return true
  }
  for edge_kind in edge_kinds {
    match edge_kind {
      @ir.CfgEdgeKind::FallthroughEdge => return true
      _ => ()
    }
  }
  false
}

///|
fn dead_code_elimination_live_children(
  func : @ir.HotFunc,
  node_id : Int,
) -> Array[Int] {
  let children : Array[Int] = []
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    let child_id = @ir.hot_child_get(func, node_id, slot)
    if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
      continue
    }
    children.push(child_id)
  }
  children
}

///|
fn dead_code_elimination_collect_detached_nodes(
  func : @ir.HotFunc,
  node_id : Int,
  out : Array[Int],
) -> Unit {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return
  }
  out.push(node_id)
  for child_id in dead_code_elimination_live_children(func, node_id) {
    dead_code_elimination_collect_detached_nodes(func, child_id, out)
  }
}

///|
fn dead_code_elimination_delete_unused_nodes(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_ids : Array[Int],
) -> Unit {
  let mut changed = false
  for node_id in node_ids {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    if !pass_node_is_unused(ctx, func, node_id) {
      continue
    }
    @ir.hot_delete_node(func, node_id)
    changed = true
  }
  if changed {
    pass_mark_mutated(ctx, func)
  }
}

///|
fn dead_code_elimination_drop_is_dead(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Drop =>
      if @ir.hot_child_count(func, node_id) != 1 {
        return false
      }
    _ => return false
  }
  let child_id = @ir.hot_child_get(func, node_id, 0)
  child_id >= 0 &&
  @ir.hot_node_is_live(func, child_id) &&
  @ir.effects_is_pure(@ir.effects_for_node(func, child_id))
}

///|
fn dead_code_elimination_can_voidify_control(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if @ir.hot_node_result_arity(func, node_id) == 0 {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Block
    | @ir.HotOp::Loop
    | @ir.HotOp::If
    | @ir.HotOp::Try
    | @ir.HotOp::TryTable => true
    _ => false
  }
}

///|
fn dead_code_elimination_has_incoming_branches(
  func : @ir.HotFunc,
  label_id : Int,
) -> Bool {
  for branch_id = 0
      branch_id < @ir.hot_node_count(func)
      branch_id = branch_id + 1 {
    if !@ir.hot_node_is_live(func, branch_id) {
      continue
    }
    match @ir.hot_branch_target(func, branch_id) {
      Some(target) if target == label_id => return true
      _ => ()
    }
  }
  false
}

///|
fn dead_code_elimination_branch_payload_count(
  func : @ir.HotFunc,
  node_id : Int,
) -> Int {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Br | @ir.HotOp::Delegate => node.child_count
    @ir.HotOp::BrIf
    | @ir.HotOp::BrTable
    | @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail =>
      if node.child_count == 0 {
        0
      } else {
        node.child_count - 1
      }
    _ => 0
  }
}

///|
fn dead_code_elimination_visit_node_regions(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      dead_code_elimination_visit_region(
        ctx,
        func,
        @ir.hot_region_body_ref(func, node_id),
      )
    @ir.HotOp::If => {
      let mut changed = dead_code_elimination_visit_region(
        ctx,
        func,
        @ir.hot_region_then_ref(func, node_id),
      )
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          changed = dead_code_elimination_visit_region(ctx, func, else_region) ||
            changed
        None => ()
      }
      changed
    }
    @ir.HotOp::Try => {
      let mut changed = dead_code_elimination_visit_region(
        ctx,
        func,
        @ir.hot_region_body_ref(func, node_id),
      )
      match @ir.hot_region_catch_ref(func, node_id) {
        Some(catch_region) =>
          changed = dead_code_elimination_visit_region(ctx, func, catch_region) ||
            changed
        None => ()
      }
      changed
    }
    @ir.HotOp::TryTable =>
      dead_code_elimination_visit_region(
        ctx,
        func,
        @ir.hot_region_body_ref(func, node_id),
      ) ||
      dead_code_elimination_visit_region(
        ctx,
        func,
        @ir.hot_region_catch_list_ref(func, node_id),
      )
    _ => false
  }
}

///|
fn dead_code_elimination_voidify_control(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if !dead_code_elimination_can_voidify_control(func, node_id) {
    return false
  }
  let label_id = @ir.hot_control_node_label(func, node_id)
  if dead_code_elimination_has_incoming_branches(func, label_id) {
    return false
  }
  let detached : Array[Int] = []
  for branch_id = 0
      branch_id < @ir.hot_node_count(func)
      branch_id = branch_id + 1 {
    if !@ir.hot_node_is_live(func, branch_id) {
      continue
    }
    match @ir.hot_branch_target(func, branch_id) {
      Some(target) if target == label_id => {
        let payload_count = dead_code_elimination_branch_payload_count(
          func, branch_id,
        )
        if payload_count == 0 {
          continue
        }
        for slot = 0; slot < payload_count; slot = slot + 1 {
          let child_id = @ir.hot_child_get(func, branch_id, slot)
          if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
            continue
          }
          if !@ir.effects_is_pure(@ir.effects_for_node(func, child_id)) {
            return false
          }
          dead_code_elimination_collect_detached_nodes(func, child_id, detached)
        }
        let new_children : Array[Int] = []
        if payload_count < @ir.hot_child_count(func, branch_id) {
          new_children.push(
            @ir.hot_child_get(
              func,
              branch_id,
              @ir.hot_child_count(func, branch_id) - 1,
            ),
          )
        }
        ignore(@ir.hot_replace_child_span(func, branch_id, new_children))
        pass_mark_mutated(ctx, func)
      }
      _ => ()
    }
  }
  @ir.hot_control_result_type_set(func, node_id, @ir.hot_type_void(func))
  pass_mark_mutated(ctx, func)
  dead_code_elimination_delete_unused_nodes(ctx, func, detached)
  true
}

///|
fn dead_code_elimination_remove_roots(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  remove_count : Int,
) -> Bool {
  if remove_count <= 0 {
    return false
  }
  let removed_roots = pass_splice_region(
    ctx,
    func,
    region_ref,
    idx,
    remove_count,
    [],
  )
  let detached : Array[Int] = []
  for node_id in removed_roots {
    dead_code_elimination_collect_detached_nodes(func, node_id, detached)
  }
  dead_code_elimination_delete_unused_nodes(ctx, func, detached)
  true
}

///|
fn dead_code_elimination_replace_root_with_child(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  child_id : Int,
) -> Bool {
  let removed = pass_splice_region(ctx, func, region_ref, idx, 1, [child_id])
  dead_code_elimination_delete_unused_nodes(ctx, func, removed)
  true
}

///|
fn dead_code_elimination_visit_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let mut changed = false
  let result_arity = if region_ref == @ir.HotRegionRef::root() {
    -1
  } else {
    @ir.hot_region_result_arity(func, region_ref)
  }
  let mut idx = 0
  while idx < @ir.hot_region_root_count(func, region_ref) {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
      idx += 1
      continue
    }

    changed = dead_code_elimination_visit_node_regions(ctx, func, node_id) ||
      changed

    if dead_code_elimination_drop_is_dead(func, node_id) {
      ignore(dead_code_elimination_remove_roots(ctx, func, region_ref, idx, 1))
      changed = true
      continue
    }

    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Drop =>
        if @ir.hot_child_count(func, node_id) == 1 {
          let child_id = @ir.hot_child_get(func, node_id, 0)
          if child_id >= 0 &&
            @ir.hot_node_is_live(func, child_id) &&
            pass_node_use_count(ctx, func, child_id) == 1 &&
            dead_code_elimination_voidify_control(ctx, func, child_id) {
            ignore(
              dead_code_elimination_replace_root_with_child(
                ctx, func, region_ref, idx, child_id,
              ),
            )
            changed = true
            continue
          }
        }
      _ => ()
    }

    if result_arity == 0 && @ir.hot_node_result_arity(func, node_id) > 0 {
      let is_final_root = idx + 1 == @ir.hot_region_root_count(func, region_ref)
      if is_final_root &&
        pass_node_use_count(ctx, func, node_id) == 1 &&
        @ir.effects_is_pure(@ir.effects_for_node(func, node_id)) {
        ignore(
          dead_code_elimination_remove_roots(ctx, func, region_ref, idx, 1),
        )
        changed = true
        continue
      }
      if is_final_root &&
        pass_node_use_count(ctx, func, node_id) == 1 &&
        dead_code_elimination_voidify_control(ctx, func, node_id) {
        changed = true
        continue
      }
    }

    if !dead_code_elimination_has_fallthrough(node.op) &&
      idx + 1 < @ir.hot_region_root_count(func, region_ref) {
      ignore(
        dead_code_elimination_remove_roots(
          ctx,
          func,
          region_ref,
          idx + 1,
          @ir.hot_region_root_count(func, region_ref) - (idx + 1),
        ),
      )
      changed = true
    }
    idx += 1
  }
  changed
}

///|
fn dead_code_elimination_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> HotPassResult {
  if dead_code_elimination_visit_region(ctx, func, @ir.HotRegionRef::root()) {
    HotPassResult::changed()
  } else {
    HotPassResult::unchanged()
  }
}
