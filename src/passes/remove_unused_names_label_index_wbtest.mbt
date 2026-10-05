///|
test "remove-unused-names label inventory finds nested outer continue" {
  let fixture = @ir.ir_test_build_hot_from_wat(
    "(module (func (loop (loop (br 1)))))",
  )
  let func = fixture.hot_func
  let used = remove_unused_names_compute_live_label_uses(func)
  let outer = @ir.hot_root_get(func, 0)
  let outer_label = @ir.hot_control_node_label(func, outer)
  let body_ref = @ir.hot_region_body_ref(func, outer)
  let inner = @ir.hot_region_get(func, body_ref, 0)
  let inner_label = @ir.hot_control_node_label(func, inner)
  @debug.assert_eq(used[outer_label], true)
  @debug.assert_eq(used[inner_label], false)
}

///|
test "remove-unused-names label inventory leaves branch-free loops unused" {
  let fixture = @ir.ir_test_build_hot_from_wat(
    "(module (func (loop (loop nop))))",
  )
  let func = fixture.hot_func
  let used = remove_unused_names_compute_live_label_uses(func)
  let outer = @ir.hot_root_get(func, 0)
  let inner = @ir.hot_region_get(func, @ir.hot_region_body_ref(func, outer), 0)
  @debug.assert_eq(used[@ir.hot_control_node_label(func, outer)], false)
  @debug.assert_eq(used[@ir.hot_control_node_label(func, inner)], false)
}

///|
test "remove-unused-names reuses removed-label workspace across sibling chains" {
  let func = @ir.HotFunc::new()
  for _ in 0..<256 {
    let inner = @ir.hot_build_block(func, @lib.BlockType::void_(), [
      @ir.hot_build_nop(func),
    ])
    @ir.hot_root_append(
      func,
      @ir.hot_build_block(func, @lib.BlockType::void_(), [inner]),
    )
  }
  let removed_ids : Array[Int] = []
  let peeled_roots : Array[Int] = []
  let used_labels = remove_unused_names_compute_live_label_uses(func)
  let removed_labels = @bitset.BitSet::new(func.labels.length())
  let touched_removed_labels : Array[Int] = []
  assert_true(
    remove_unused_names_visit_region(
      func,
      @ir.HotRegionRef::root(),
      removed_ids,
      peeled_roots,
      used_labels,
      removed_labels,
      touched_removed_labels,
    ),
  )
  assert_eq(touched_removed_labels.length(), 1)
  for idx = 0; idx < @ir.hot_root_count(func); idx = idx + 1 {
    let outer = @ir.hot_root_get(func, idx)
    let body = @ir.hot_region_body_ref(func, outer)
    assert_true(
      @ir.hot_node_get(func, @ir.hot_region_get(func, body, 0)).op
      is @ir.HotOp::Nop,
    )
  }
}
