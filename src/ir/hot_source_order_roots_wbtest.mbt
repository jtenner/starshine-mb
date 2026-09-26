///|
fn source_order_roots_fixture(
  count : Int,
) -> (HotFunc, NodeId, NodeId, Array[NodeId]) {
  let func = HotFunc::new()
  let carried = hot_build_call(func, 0, [@lib.ValType::i32()], [])
  let barrier = hot_build_call(func, 1, [], [])
  let future : Array[NodeId] = []
  for i in 0..<count {
    future.push(hot_build_drop(func, hot_build_const_i32(func, @lib.I32(i))))
  }
  future.push(hot_build_drop(func, carried))
  (func, carried, barrier, future)
}

///|
test "source-order root index selects the carried call past irrelevant roots" {
  let (func, carried, barrier, future) = source_order_roots_fixture(64)
  let facts = HotSourceOrderFacts::new(func)
  let minima = hot_source_order_future_suffix_minima(func, future, facts)
  let visits = [0]
  assert_eq(
    hot_source_order_preceding_dependencies(
      func,
      barrier,
      future,
      0,
      minima,
      facts,
      root_visits=Some(visits),
    ),
    [carried],
  )
  assert_eq(visits[0], 1)
  assert_eq(
    hot_source_order_preceding_dependencies(
      func,
      barrier,
      future,
      future.length(),
      minima,
      facts,
    ),
    [],
  )
}

///|
test "source-order indexed ranges preserve both consumer phases and strict cutoffs" {
  let func = HotFunc::new()
  let future : Array[NodeId] = []
  let barriers : Array[NodeId] = []
  for i in 0..<8 {
    let value = hot_build_call(func, i, [@lib.ValType::i32()], [])
    if i % 2 == 0 {
      barriers.push(hot_build_call(func, 20 + i, [], []))
    }
    future.push(hot_build_drop(func, value))
  }
  let indexed = HotSourceOrderFacts::new(func)
  let reference = HotSourceOrderFacts::new(func)
  let index = Some(HotSourceOrderRootIndex::new(func, future, indexed))
  for barrier in barriers {
    for start in [0, 1, 4, 7, 8] {
      assert_eq(
        hot_source_order_preceding_dependencies(
          func, barrier, future, start, index, indexed,
        ),
        hot_source_order_preceding_dependencies(
          func,
          barrier,
          future,
          start,
          None,
          reference,
        ),
      )
    }
  }
}
