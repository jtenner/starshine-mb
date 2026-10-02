///|
test "CFG segment copy retains exact range and independent owned rows" {
  let source = [2, 7, 11, 19, 23]
  let saved = source.copy()
  let first = cfg_copy_segment_nodes(source, 1, 4)
  let sibling = cfg_copy_segment_nodes(source, 1, 4)
  assert_eq(first, [7, 11, 19])
  assert_eq(sibling, first)
  first[0] = 31
  assert_eq(sibling, [7, 11, 19])
  assert_eq(source, saved)
  source[2] = 37
  assert_eq(sibling, [7, 11, 19])
  assert_eq(first, [31, 11, 19])
  assert_eq(first.capacity(), first.length())
  assert_eq(sibling.capacity(), sibling.length())
  assert_eq(cfg_copy_segment_nodes(source, 0, 0), [])
  assert_eq(cfg_copy_segment_nodes(source, 5, 5), [])
  assert_eq(cfg_copy_segment_nodes(source, 0, 5), source)
  let singleton = cfg_copy_segment_nodes(source, 4, 5)
  assert_eq(singleton, [23])
  assert_eq(singleton.capacity(), 1)
  singleton[0] = 43
  assert_eq(source[4], 23)
}

///|
test "CFG segment copies preserve complete operand-expanded graph fields" {
  let func = cfg_segment_storage_fixture(8)
  let revision = hot_revision_current(func)
  for expanded in [false, true] {
    let original = cfg_builder_new(func, true, expanded)
    let selected = cfg_builder_new(func, true, expanded)
    let expected = cfg_segment_storage_reference(
      original,
      func,
      HotRegionRef::root(),
    )
    let actual = cfg_builder_region_segments(
      selected,
      func,
      HotRegionRef::root(),
    )
    assert_eq(actual.length(), expected.length())
    assert_eq(selected.cfg, original.cfg)
    for i in 0..<actual.length() {
      assert_eq(actual.get(i).last_node, expected[i].last_node)
      assert_eq(actual.get(i).end_slot, expected[i].end_slot)
    }
    cfg_verify(cfg_build(func, expand_operand_control=expanded))
  }
  assert_eq(hot_revision_current(func), revision)
}
