///|
test "source-order small-region index preserves every suffix query" {
  for width in [3, 15, 31] {
    for dense in [false, true] {
      let (func, carried, barrier, roots) = source_order_roots_fixture(width)
      if dense {
        for slot in 0..<width {
          roots[slot] = hot_build_drop(func, carried)
        }
      }
      let direct = HotSourceOrderFacts::new(func)
      let indexed = HotSourceOrderFacts::new(func)
      let index = Some(HotSourceOrderRootIndex::new(func, roots, indexed))
      assert_eq(
        hot_source_order_preceding_dependencies(
          func,
          barrier,
          roots,
          0,
          None,
          direct,
        ),
        [carried],
      )
      for start in 0..<(roots.length() + 1) {
        assert_eq(
          hot_source_order_preceding_dependencies(
            func, barrier, roots, start, index, indexed,
          ),
          hot_source_order_preceding_dependencies(
            func,
            barrier,
            roots,
            start,
            None,
            direct,
          ),
        )
      }
    }
  }
}

///|
test "source-order 32-root index selects only its carried dependency" {
  let (func, carried, barrier, roots) = source_order_roots_fixture(31)
  let facts = HotSourceOrderFacts::new(func)
  let index = Some(HotSourceOrderRootIndex::new(func, roots, facts))
  assert_eq(index.unwrap().candidates(0, hot_node_get(func, barrier).order), [
    31,
  ])
  assert_eq(
    hot_source_order_preceding_dependencies(
      func, barrier, roots, 0, index, facts,
    ),
    [carried],
  )
}
