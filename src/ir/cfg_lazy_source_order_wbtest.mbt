///|
fn cfg_lazy_single_region_fixture() -> (HotFunc, NodeId) {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let write = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  let root = hot_build_block(func, @lib.BlockType::void_(), [write])
  hot_root_append(func, root)
  hot_verify_all_or_abort(func)
  (func, root)
}

///|
test "CFG single-root segmentation preserves fields without source-order setup" {
  let (func, root) = cfg_lazy_single_region_fixture()
  let revision = hot_revision_current(func)
  let selected = cfg_builder_new(func, true, true)
  let reference = cfg_builder_new(func, true, true)
  let expected = cfg_segment_storage_reference(
    reference,
    func,
    HotRegionRef::root(),
  )
  let actual = cfg_builder_region_segments(selected, func, HotRegionRef::root())
  assert_eq(actual.length(), expected.length())
  assert_eq(selected.cfg, reference.cfg)
  assert_eq(actual.get(0).last_node, root)
  cfg_verify(cfg_build(func, expand_operand_control=true))
  assert_eq(hot_revision_current(func), revision)
  assert_true(
    selected.source_order is None,
    msg="single-root CFG eagerly built whole-function source-order facts",
  )
}

///|
test "CFG forward multi-root segmentation preserves fields without source-order setup" {
  let func = cfg_segment_storage_fixture(2)
  let revision = hot_revision_current(func)
  let selected = cfg_builder_new(func, true, true)
  let reference = cfg_builder_new(func, true, true)
  let expected = cfg_segment_storage_reference(
    reference,
    func,
    HotRegionRef::root(),
  )
  let actual = cfg_builder_region_segments(selected, func, HotRegionRef::root())
  assert_eq(actual.length(), expected.length())
  assert_eq(selected.cfg, reference.cfg)
  for i in 0..<actual.length() {
    assert_eq(actual.get(i).last_node, expected[i].last_node)
    assert_eq(actual.get(i).end_slot, expected[i].end_slot)
  }
  assert_true(
    selected.source_order is None,
    msg="forward-only CFG built unnecessary source-order facts",
  )
  cfg_verify(cfg_build(func, expand_operand_control=true))
  assert_eq(hot_revision_current(func), revision)
}

///|
test "CFG first nested multi-root query owns facts and keeps sibling builders cold" {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let carried = hot_build_local_get(func, 0)
  let write = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(9)),
  )
  let read = hot_build_drop(func, carried)
  let root = hot_build_block(func, @lib.BlockType::void_(), [write, read])
  hot_root_append(func, root)
  hot_verify_all_or_abort(func)
  let revision = hot_revision_current(func)
  let builder = cfg_builder_new(func, true, true)
  let sibling = cfg_builder_new(func, true, true)
  ignore(cfg_builder_region_segments(builder, func, HotRegionRef::root()))
  assert_true(builder.source_order is None)
  let region = hot_region_body_ref(func, root)
  let reference = cfg_builder_new(func, true, true)
  let expected = cfg_segment_storage_reference(reference, func, region)
  let actual = cfg_builder_region_segments(builder, func, region)
  assert_eq(actual.length(), expected.length())
  assert_eq(builder.cfg.blocks[1].nodes, [
    carried,
    hot_child_get(func, write, 0),
    write,
    read,
  ])
  let facts = builder.source_order.unwrap()
  ignore(cfg_builder_region_segments(builder, func, region))
  assert_true(physical_equal(facts, builder.source_order.unwrap()))
  assert_true(sibling.source_order is None)
  assert_eq(hot_revision_current(func), revision)
  cfg_verify(cfg_build(func, expand_operand_control=true))
}

///|
test "CFG operand minima bound shared work and stay owned by a snapshot" {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let carried = hot_build_local_get(func, 0)
  let mut value = carried
  for _ in 0..<16 {
    value = hot_build_select(
      func,
      @lib.ValType::i32(),
      value,
      value,
      hot_build_const_i32(func, @lib.I32(1)),
    )
  }
  let minima = Array::make(hot_node_count(func), -1)
  let visits = [0]
  assert_eq(
    cfg_operand_minimum_order(func, value, minima, visits=Some(visits)),
    0,
  )
  assert_eq(visits[0], hot_node_count(func))
  let revision = hot_revision_current(func)
  let saved = minima.copy()
  assert_eq(
    cfg_operand_minimum_order(func, value, minima, visits=Some(visits)),
    0,
  )
  assert_eq(visits[0], hot_node_count(func))
  assert_eq(minima, saved)
  assert_eq(hot_revision_current(func), revision)

  let written = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()]),
  )
  let old_read = hot_build_local_get(written, 0)
  let write = hot_build_local_set(
    written,
    0,
    hot_build_const_i32(written, @lib.I32(9)),
  )
  let drop = hot_build_drop(written, old_read)
  hot_root_append(written, write)
  hot_root_append(written, drop)
  let before = cfg_builder_new(written, true, true)
  ignore(cfg_builder_region_segments(before, written, HotRegionRef::root()))
  assert_true(before.source_order is Some(_))
  let old_minimum = before.operand_minima.unwrap()[drop]
  assert_eq(old_minimum, 0)
  let new_read = hot_build_local_get(written, 0)
  hot_child_set(written, drop, 0, new_read)
  hot_verify_all_or_abort(written)
  let after = cfg_builder_new(written, true, true)
  ignore(cfg_builder_region_segments(after, written, HotRegionRef::root()))
  assert_true(after.source_order is None)
  assert_eq(after.cfg.blocks[0].nodes, [
    hot_child_get(written, write, 0),
    write,
    new_read,
    drop,
  ])
  assert_eq(before.operand_minima.unwrap()[drop], old_minimum)
  cfg_verify(cfg_build(written, expand_operand_control=true))
}
