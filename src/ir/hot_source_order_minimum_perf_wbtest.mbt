///|
fn source_order_minimum_bench(
  it : @bench.T,
  count : Int,
  cold : Bool,
  reference : Bool,
) -> Unit {
  let (func, old, barrier, root) = source_order_minimum_fixture(count)
  let future = [root]
  let facts = HotSourceOrderFacts::new(func)
  if hot_source_order_preceding_dependencies(
      func,
      barrier,
      future,
      0,
      None,
      facts,
    ) !=
    [old] ||
    source_order_minimum_reference_query(
      func,
      barrier,
      future,
      0,
      None,
      HotSourceOrderFacts::new(func),
    ) !=
    [old] {
    abort("minimum pruning must retain the old call")
  }
  it.bench(fn() {
    let snapshot = if cold { HotSourceOrderFacts::new(func) } else { facts }
    it.keep(
      if reference {
        source_order_minimum_reference_query(
          func,
          barrier,
          future,
          0,
          None,
          snapshot,
        )
      } else {
        hot_source_order_preceding_dependencies(
          func,
          barrier,
          future,
          0,
          None,
          snapshot,
        )
      },
    )
  })
}

///|
test "bench dependency minima leaves=8 warm reference" (it : @bench.T) {
  source_order_minimum_bench(it, 8, false, true)
}

///|
test "bench dependency minima leaves=8 warm selected" (it : @bench.T) {
  source_order_minimum_bench(it, 8, false, false)
}

///|
test "bench dependency minima leaves=8 cold reference" (it : @bench.T) {
  source_order_minimum_bench(it, 8, true, true)
}

///|
test "bench dependency minima leaves=8 cold selected" (it : @bench.T) {
  source_order_minimum_bench(it, 8, true, false)
}

///|
test "bench dependency minima leaves=128 warm reference" (it : @bench.T) {
  source_order_minimum_bench(it, 128, false, true)
}

///|
test "bench dependency minima leaves=128 warm selected" (it : @bench.T) {
  source_order_minimum_bench(it, 128, false, false)
}

///|
test "bench dependency minima leaves=128 cold reference" (it : @bench.T) {
  source_order_minimum_bench(it, 128, true, true)
}

///|
test "bench dependency minima leaves=128 cold selected" (it : @bench.T) {
  source_order_minimum_bench(it, 128, true, false)
}

///|
test "bench dependency minima leaves=1024 warm reference" (it : @bench.T) {
  source_order_minimum_bench(it, 1024, false, true)
}

///|
test "bench dependency minima leaves=1024 warm selected" (it : @bench.T) {
  source_order_minimum_bench(it, 1024, false, false)
}

///|
test "bench dependency minima leaves=1024 cold reference" (it : @bench.T) {
  source_order_minimum_bench(it, 1024, true, true)
}

///|
test "bench dependency minima leaves=1024 cold selected" (it : @bench.T) {
  source_order_minimum_bench(it, 1024, true, false)
}
