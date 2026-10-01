///|
fn trivial_sort_fixture(
  count : Int,
) -> (HotFunc, NodeId, Array[NodeId], Array[NodeId]) {
  let func = HotFunc::new()
  let values : Array[NodeId] = []
  for i in 0..<count {
    values.push(hot_build_call(func, i, [@lib.ValType::i32()], []))
  }
  let barrier = hot_build_call(func, count, [], [])
  let future = [hot_build_drop(func, hot_build_const_i32(func, @lib.I32(17)))]
  // Reverse discovery must still select source order for nontrivial rows.
  for i = count - 1; i >= 0; i = i - 1 {
    future.push(hot_build_drop(func, values[i]))
  }
  if count > 0 {
    // Shared consumers must not duplicate the selected value.
    future.push(hot_build_drop(func, values[0]))
  }
  (func, barrier, future, values)
}

///|
test "trivial source dependency rows preserve order ownership and clean reused scratch" {
  for count in [0, 1, 8] {
    let (func, barrier, future, expected) = trivial_sort_fixture(count)
    let facts = HotSourceOrderFacts::new(func)
    let reference = HotSourceOrderFacts::new(func)
    let revision = hot_revision_current(func)
    let free = func.free_nodes.copy()
    let held = hot_source_order_preceding_dependencies(
      func,
      barrier,
      future,
      0,
      None,
      facts,
    )
    assert_eq(held, expected)
    for start in [0, future.length(), 0] {
      let actual = hot_source_order_preceding_dependencies(
        func,
        barrier,
        future,
        start,
        None,
        facts,
      )
      assert_eq(
        actual,
        trivial_sort_reference_query(
          func,
          barrier,
          future,
          start,
          None,
          reference,
        ),
      )
      assert_eq(held, expected)
    }
    // Returned selection rows are owned even though the internal carried row
    // and membership marks are reused.
    held.clear()
    assert_eq(
      hot_source_order_preceding_dependencies(
        func,
        barrier,
        future,
        0,
        None,
        facts,
      ),
      expected,
    )
    if facts.dependency_scratch is Some(scratch) {
      assert_true(scratch.carried.is_empty())
      assert_true(scratch.touched.is_empty())
      for i in 0..<hot_node_count(func) {
        assert_eq(scratch.seen_consumer[i], hot_node_count(func))
        assert_eq(scratch.consumer_bounds[i], -1)
        assert_false(scratch.anti_dependencies[i])
      }
    }
    assert_eq(hot_revision_current(func), revision)
    assert_eq(func.free_nodes, free)
  }
}
