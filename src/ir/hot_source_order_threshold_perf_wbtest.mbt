///|
fn source_order_threshold_bench(
  it : @bench.T,
  width : Int,
  dense : Bool,
  indexed : Bool,
) -> Unit {
  let (func, carried, barrier, roots) = source_order_roots_fixture(width)
  if dense {
    for slot in 0..<width {
      roots[slot] = hot_build_drop(func, carried)
    }
  }
  let check_facts = HotSourceOrderFacts::new(func)
  let index = if indexed {
    Some(HotSourceOrderRootIndex::new(func, roots, check_facts))
  } else {
    None
  }
  if hot_source_order_preceding_dependencies(
      func, barrier, roots, 0, index, check_facts,
    ) !=
    [carried] {
    abort("root threshold control lost a carried call")
  }
  // Include facts/index construction in each batch. One query per root keeps
  // the cache lifetime comparable to building one source-ordered region.
  it.bench(fn() {
    let facts = HotSourceOrderFacts::new(func)
    let index = if indexed {
      Some(HotSourceOrderRootIndex::new(func, roots, facts))
    } else {
      None
    }
    for start in 0..<roots.length() {
      it.keep(
        hot_source_order_preceding_dependencies(
          func, barrier, roots, start, index, facts,
        ),
      )
    }
  })
}

///|
test "bench source-order index lifetime roots=4 sparse direct" (it : @bench.T) {
  source_order_threshold_bench(it, 3, false, false)
}

///|
test "bench source-order index lifetime roots=4 sparse indexed" (it : @bench.T) {
  source_order_threshold_bench(it, 3, false, true)
}

///|
test "bench source-order index lifetime roots=4 dense direct" (it : @bench.T) {
  source_order_threshold_bench(it, 3, true, false)
}

///|
test "bench source-order index lifetime roots=4 dense indexed" (it : @bench.T) {
  source_order_threshold_bench(it, 3, true, true)
}

///|
test "bench source-order index lifetime roots=16 sparse direct" (it : @bench.T) {
  source_order_threshold_bench(it, 15, false, false)
}

///|
test "bench source-order index lifetime roots=16 sparse indexed" (it : @bench.T) {
  source_order_threshold_bench(it, 15, false, true)
}

///|
test "bench source-order index lifetime roots=16 dense direct" (it : @bench.T) {
  source_order_threshold_bench(it, 15, true, false)
}

///|
test "bench source-order index lifetime roots=16 dense indexed" (it : @bench.T) {
  source_order_threshold_bench(it, 15, true, true)
}

///|
test "bench source-order index lifetime roots=32 sparse direct" (it : @bench.T) {
  source_order_threshold_bench(it, 31, false, false)
}

///|
test "bench source-order index lifetime roots=32 sparse indexed" (it : @bench.T) {
  source_order_threshold_bench(it, 31, false, true)
}

///|
test "bench source-order index lifetime roots=32 dense direct" (it : @bench.T) {
  source_order_threshold_bench(it, 31, true, false)
}

///|
test "bench source-order index lifetime roots=32 dense indexed" (it : @bench.T) {
  source_order_threshold_bench(it, 31, true, true)
}
