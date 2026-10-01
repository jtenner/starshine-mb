///|
fn trivial_sort_bench(
  it : @bench.T,
  count : Int,
  cold : Bool,
  reference : Bool,
) -> Unit raise {
  let (func, barrier, future, expected) = trivial_sort_fixture(count)
  let facts = HotSourceOrderFacts::new(func)
  fn query(facts : HotSourceOrderFacts) -> Array[NodeId] {
    if reference {
      trivial_sort_reference_query(func, barrier, future, 0, None, facts)
    } else {
      hot_source_order_preceding_dependencies(
        func,
        barrier,
        future,
        0,
        None,
        facts,
      )
    }
  }
  assert_eq(query(facts), expected)
  it.bench(fn() {
    it.keep(query(if cold { HotSourceOrderFacts::new(func) } else { facts }))
  })
}

///|
test "bench carried sort empty warm reference" (it : @bench.T) {
  trivial_sort_bench(it, 0, false, true)
}

///|
test "bench carried sort empty warm guarded" (it : @bench.T) {
  trivial_sort_bench(it, 0, false, false)
}

///|
test "bench carried sort singleton warm reference" (it : @bench.T) {
  trivial_sort_bench(it, 1, false, true)
}

///|
test "bench carried sort singleton warm guarded" (it : @bench.T) {
  trivial_sort_bench(it, 1, false, false)
}

///|
test "bench carried sort wide warm reference" (it : @bench.T) {
  trivial_sort_bench(it, 8, false, true)
}

///|
test "bench carried sort wide warm guarded" (it : @bench.T) {
  trivial_sort_bench(it, 8, false, false)
}

///|
test "bench carried sort empty cold reference" (it : @bench.T) {
  trivial_sort_bench(it, 0, true, true)
}

///|
test "bench carried sort empty cold guarded" (it : @bench.T) {
  trivial_sort_bench(it, 0, true, false)
}

///|
test "bench carried sort singleton cold reference" (it : @bench.T) {
  trivial_sort_bench(it, 1, true, true)
}

///|
test "bench carried sort singleton cold guarded" (it : @bench.T) {
  trivial_sort_bench(it, 1, true, false)
}

///|
test "bench carried sort wide cold reference" (it : @bench.T) {
  trivial_sort_bench(it, 8, true, true)
}

///|
test "bench carried sort wide cold guarded" (it : @bench.T) {
  trivial_sort_bench(it, 8, true, false)
}
