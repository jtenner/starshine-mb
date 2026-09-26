///|
test "source-order scratch reuse retains fresh dependency bounds" {
  let func = HotFunc::new()
  let first = hot_build_call(func, 0, [@lib.ValType::i32()], [])
  let barrier = hot_build_call(func, 1, [], [])
  let consumer = hot_build_drop(func, first)
  let second = hot_build_call(func, 2, [@lib.ValType::i32()], [])
  let later_barrier = hot_build_call(func, 3, [], [])
  let later_consumer = hot_build_drop(func, second)
  let facts = HotSourceOrderFacts::new(func)
  let builds = [0]
  for _ in 0..<3 {
    assert_eq(
      hot_source_order_preceding_dependencies(
        func,
        barrier,
        [consumer],
        0,
        None,
        facts,
        scratch_builds=Some(builds),
      ),
      [first],
    )
    assert_eq(
      hot_source_order_preceding_dependencies(
        func,
        later_barrier,
        [later_consumer],
        0,
        None,
        facts,
        scratch_builds=Some(builds),
      ),
      [second],
    )
    assert_eq(
      hot_source_order_preceding_dependencies(
        func,
        barrier,
        [],
        0,
        None,
        facts,
        scratch_builds=Some(builds),
      ),
      [],
    )
  }
  assert_eq(builds[0], 1)
}
