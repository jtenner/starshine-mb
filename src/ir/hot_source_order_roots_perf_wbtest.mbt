///|
fn source_order_roots_bench(it : @bench.T, count : Int) -> Unit {
  let (func, carried, barrier, future) = source_order_roots_fixture(count)
  let facts = HotSourceOrderFacts::new(func)
  let minima = hot_source_order_future_suffix_minima(func, future, facts)
  if hot_source_order_preceding_dependencies(
      func, barrier, future, 0, minima, facts,
    ) !=
    [carried] {
    abort("root query benchmark lost the carried call")
  }
  it.bench(fn() {
    for _ in 0..<64 {
      it.keep(
        hot_source_order_preceding_dependencies(
          func, barrier, future, 0, minima, facts,
        ),
      )
    }
  })
}

///|
test "bench source-order irrelevant future roots=256" (it : @bench.T) {
  source_order_roots_bench(it, 256)
}

///|
test "bench source-order irrelevant future roots=1024" (it : @bench.T) {
  source_order_roots_bench(it, 1024)
}

///|
fn source_order_dense_roots_bench(it : @bench.T, indexed : Bool) -> Unit {
  let func = HotFunc::new()
  let carried = hot_build_call(func, 0, [@lib.ValType::i32()], [])
  let barrier = hot_build_call(func, 1, [], [])
  let roots = Array::makei(256, fn(_) { hot_build_drop(func, carried) })
  let facts = HotSourceOrderFacts::new(func)
  let index = if indexed {
    hot_source_order_future_suffix_minima(func, roots, facts)
  } else {
    None
  }
  if hot_source_order_preceding_dependencies(
      func, barrier, roots, 0, index, facts,
    ) !=
    [carried] {
    abort("dense root query lost its carried call")
  }
  it.bench(fn() {
    for _ in 0..<64 {
      it.keep(
        hot_source_order_preceding_dependencies(
          func, barrier, roots, 0, index, facts,
        ),
      )
    }
  })
}

///|
test "bench source-order dense roots direct" (it : @bench.T) {
  source_order_dense_roots_bench(it, false)
}

///|
test "bench source-order dense roots indexed" (it : @bench.T) {
  source_order_dense_roots_bench(it, true)
}
