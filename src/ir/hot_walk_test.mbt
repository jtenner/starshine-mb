///|
struct HotWalkSkipState {
  seen : Array[NodeId]
  skip_at : NodeId
} derive(Eq, Show, Debug)

///|
struct HotRewriteState {
  replacement : NodeId
  touched_slots : Array[Int]
} derive(Eq, Show, Debug)

///|
struct HotControlWalkState {
  slots : Array[Int]
  region_ids : Array[NodeId]
} derive(Eq, Show, Debug)

///|
fn hot_walk_collect_root(
  state : Array[NodeId],
  _root_idx : Int,
  node_id : NodeId,
) -> HotVisitCtl[Array[NodeId], String] {
  let next = state.copy()
  next.push(node_id)
  hot_visit_continue(next)
}

///|
fn hot_walk_collect_child(
  state : Array[NodeId],
  _slot : Int,
  node_id : NodeId,
) -> HotVisitCtl[Array[NodeId], String] {
  let next = state.copy()
  next.push(node_id)
  hot_visit_continue(next)
}

///|
fn hot_walk_collect_node(
  state : Array[NodeId],
  node_id : NodeId,
) -> HotVisitCtl[Array[NodeId], String] {
  let next = state.copy()
  next.push(node_id)
  hot_visit_continue(next)
}

///|
fn hot_walk_skip_node(
  state : HotWalkSkipState,
  node_id : NodeId,
) -> HotVisitCtl[HotWalkSkipState, String] {
  let next_seen = state.seen.copy()
  next_seen.push(node_id)
  let next = { seen: next_seen, skip_at: state.skip_at }
  if node_id == state.skip_at {
    hot_visit_skip(next)
  } else {
    hot_visit_continue(next)
  }
}

///|
fn hot_walk_stop_after_first_root(
  state : Array[NodeId],
  _root_idx : Int,
  node_id : NodeId,
) -> HotVisitCtl[Array[NodeId], String] {
  let next = state.copy()
  next.push(node_id)
  hot_visit_stop(next)
}

///|
fn hot_walk_collect_control_region(
  state : HotControlWalkState,
  _control_id : NodeId,
  slot_info : HotControlRegionSlotInfo,
  region_id : NodeId,
) -> HotVisitCtl[HotControlWalkState, String] {
  let next_slots = state.slots.copy()
  let next_regions = state.region_ids.copy()
  next_slots.push(slot_info.slot)
  next_regions.push(region_id)
  hot_visit_continue({ slots: next_slots, region_ids: next_regions })
}

///|
fn hot_walk_rewrite_if_children(
  state : HotRewriteState,
  _parent_id : NodeId,
  slot : Int,
  _child_id : NodeId,
) -> HotRewriteCtl[HotRewriteState, String] {
  let next_slots = state.touched_slots.copy()
  next_slots.push(slot)
  let next = { replacement: state.replacement, touched_slots: next_slots }
  if slot == 0 {
    hot_rewrite_replace(next, state.replacement)
  } else if slot == 2 {
    hot_rewrite_remove(next)
  } else {
    hot_rewrite_same(next)
  }
}

///|
test "root child subtree and worklist walkers keep stable order" {
  let func = HotFunc::new()
  let first = hot_build_const_i32(func, @lib.I32(1))
  let second = hot_build_const_i32(func, @lib.I32(2))
  let drop_second = hot_build_drop(func, second)
  let root = hot_build_block(func, @lib.BlockType::void_(), [first, drop_second])
  let extra_root = hot_build_unreachable(func)
  hot_root_append(func, root)
  hot_root_append(func, extra_root)

  let roots = match hot_for_each_root(func, [], hot_walk_collect_root) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  assert_eq(roots, [root, extra_root])

  let children = match
    hot_for_each_child(func, root, [], hot_walk_collect_child) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  assert_eq(children, [first, drop_second])

  let preorder = match
    hot_walk_subtree_preorder(func, root, [], hot_walk_collect_node) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  assert_eq(preorder, [root, first, drop_second, second])

  let postorder = match
    hot_walk_subtree_postorder(func, root, [], hot_walk_collect_node) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  assert_eq(postorder, [first, second, drop_second, root])

  let region = match hot_walk_region(func, root, [], hot_walk_collect_child) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  assert_eq(region, [first, drop_second])

  let worklist = match
    hot_worklist_walk(func, [root, extra_root], [], hot_walk_collect_node) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  assert_eq(worklist, [root, first, drop_second, second, extra_root])
}

///|
test "skip and stop semantics short circuit shared traversal helpers" {
  let func = HotFunc::new()
  let first = hot_build_const_i32(func, @lib.I32(1))
  let second = hot_build_const_i32(func, @lib.I32(2))
  let drop_second = hot_build_drop(func, second)
  let root = hot_build_block(func, @lib.BlockType::void_(), [first, drop_second])
  let extra_root = hot_build_unreachable(func)
  hot_root_append(func, root)
  hot_root_append(func, extra_root)

  let skipped = match
    hot_walk_subtree_preorder(
      func,
      root,
      { seen: [], skip_at: drop_second },
      hot_walk_skip_node,
    ) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  assert_eq(skipped.seen, [root, first, drop_second])

  let stopped_roots = match
    hot_for_each_root(func, [], hot_walk_stop_after_first_root) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  assert_eq(stopped_roots, [root])
}

///|
test "control region and rewrite walkers expose slots and optional child edits" {
  let func = HotFunc::new()
  let condition = hot_build_const_i32(func, @lib.I32(1))
  let replacement_condition = hot_build_const_i32(func, @lib.I32(0))
  let then_body = hot_build_drop(func, hot_build_const_i32(func, @lib.I32(7)))
  let else_body = hot_build_drop(func, hot_build_const_i32(func, @lib.I32(9)))
  let if_id = hot_build_if(
    func,
    @lib.BlockType::void_(),
    condition,
    [then_body],
    else_body=Some([else_body]),
  )

  let control_regions = match
    hot_walk_control_regions(
      func,
      if_id,
      { slots: [], region_ids: [] },
      hot_walk_collect_control_region,
    ) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  assert_eq(control_regions.slots, [1, 2])
  assert_eq(control_regions.region_ids.length(), 2)

  let rewritten = match
    hot_rewrite_children_by_slot(
      func,
      if_id,
      { replacement: replacement_condition, touched_slots: [] },
      hot_walk_rewrite_if_children,
    ) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  assert_eq(rewritten.touched_slots, [0, 1, 2])
  assert_eq(hot_child_get(func, if_id, 0), replacement_condition)
  assert_false(hot_node_is_live(func, hot_child_get(func, if_id, 2)))
}
