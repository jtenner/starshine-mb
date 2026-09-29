///|
fn source_order_region_lifetime_bench(
  it : @bench.T,
  count : Int,
  dense : Bool,
  indexed : Bool,
) -> Unit {
  let func = HotFunc::new()
  let carried = hot_build_call(func, 0, [@lib.ValType::i32()], [])
  let roots : Array[NodeId] = []
  for _ in 1..<count {
    roots.push(hot_build_call(func, 1, [], if dense { [carried] } else { [] }))
  }
  roots.push(hot_build_drop(func, carried))
  let direct = HotSourceOrderFacts::new(func)
  let indexed_facts = HotSourceOrderFacts::new(func)
  let index = Some(HotSourceOrderRootIndex::new(func, roots, indexed_facts))
  for position in 0..<roots.length() {
    let expected = hot_source_order_preceding_dependencies(
      func,
      roots[position],
      roots,
      position + 1,
      None,
      direct,
    )
    let actual = hot_source_order_preceding_dependencies(
      func,
      roots[position],
      roots,
      position + 1,
      index,
      indexed_facts,
    )
    if actual != expected {
      abort("region index changed dependencies at a real root position")
    }
  }
  // Build facts/index once per region, then query each actual root exactly once.
  // Every call root needs effect ordering, unlike pure roots that skip queries.
  it.bench(fn() {
    let facts = HotSourceOrderFacts::new(func)
    let index = if indexed {
      Some(HotSourceOrderRootIndex::new(func, roots, facts))
    } else {
      None
    }
    for position in 0..<roots.length() {
      it.keep(
        hot_source_order_preceding_dependencies(
          func,
          roots[position],
          roots,
          position + 1,
          index,
          facts,
        ),
      )
    }
  })
}

///|
test "bench source-order actual region roots=16 sparse direct" (it : @bench.T) {
  source_order_region_lifetime_bench(it, 16, false, false)
}

///|
test "bench source-order actual region roots=16 sparse indexed" (it : @bench.T) {
  source_order_region_lifetime_bench(it, 16, false, true)
}

///|
test "bench source-order actual region roots=16 dense direct" (it : @bench.T) {
  source_order_region_lifetime_bench(it, 16, true, false)
}

///|
test "bench source-order actual region roots=16 dense indexed" (it : @bench.T) {
  source_order_region_lifetime_bench(it, 16, true, true)
}

///|
test "bench source-order actual region roots=32 sparse direct" (it : @bench.T) {
  source_order_region_lifetime_bench(it, 32, false, false)
}

///|
test "bench source-order actual region roots=32 sparse indexed" (it : @bench.T) {
  source_order_region_lifetime_bench(it, 32, false, true)
}

///|
test "bench source-order actual region roots=32 dense direct" (it : @bench.T) {
  source_order_region_lifetime_bench(it, 32, true, false)
}

///|
test "bench source-order actual region roots=32 dense indexed" (it : @bench.T) {
  source_order_region_lifetime_bench(it, 32, true, true)
}
