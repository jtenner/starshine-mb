///|
fn access_fields_bench(
  it : @bench.T,
  depth : Int,
  reference : Bool,
  cold : Bool,
) -> Unit raise {
  let (func, root) = access_fields_fixture(depth)
  access_fields_assert(func, [root])
  it.bench(fn() {
    let facts = HotSourceOrderFacts::new(func)
    if cold {
      it.keep(
        if reference {
          access_fields_reference_nodes(func, root, facts)
        } else {
          hot_source_order_local_access_nodes(func, root, facts)
        },
      )
    } else {
      // Fresh root enumeration over an already allocated fact snapshot.
      for _ in 0..<64 {
        facts.local_access_nodes[root] = None
        it.keep(
          if reference {
            access_fields_reference_nodes(func, root, facts)
          } else {
            hot_source_order_local_access_nodes(func, root, facts)
          },
        )
      }
    }
  })
}

///|
test "bench local access shallow cold header" (it : @bench.T) {
  access_fields_bench(it, 8, true, true)
}

///|
test "bench local access shallow cold fields" (it : @bench.T) {
  access_fields_bench(it, 8, false, true)
}

///|
test "bench local access deep cold header" (it : @bench.T) {
  access_fields_bench(it, 128, true, true)
}

///|
test "bench local access deep cold fields" (it : @bench.T) {
  access_fields_bench(it, 128, false, true)
}

///|
test "bench local access shallow repeated header" (it : @bench.T) {
  access_fields_bench(it, 8, true, false)
}

///|
test "bench local access shallow repeated fields" (it : @bench.T) {
  access_fields_bench(it, 8, false, false)
}

///|
test "bench local access deep repeated header" (it : @bench.T) {
  access_fields_bench(it, 128, true, false)
}

///|
test "bench local access deep repeated fields" (it : @bench.T) {
  access_fields_bench(it, 128, false, false)
}
