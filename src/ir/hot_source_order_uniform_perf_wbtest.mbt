///|
fn source_order_uniform_bench(
  it : @bench.T,
  count : Int,
  reference : Bool,
) -> Unit {
  let (func, roots, write) = source_order_uniform_fixture(count, 1)
  hot_verify_all(func).unwrap()
  let left = HotSourceOrderFacts::new(func)
  let right = HotSourceOrderFacts::new(func)
  for root in roots {
    if source_order_write_scan_reference(func, root, write, left) !=
      hot_lower_impl_carried_local_write_conflicts(func, root, write, right) ||
      source_order_write_scan_reference(func, write, root, left) !=
      hot_lower_impl_carried_local_write_conflicts(func, write, root, right) {
      abort("uniform summary changed a directional conflict")
    }
  }
  it.bench(fn() {
    let facts = HotSourceOrderFacts::new(func)
    for root in roots {
      it.keep(
        if reference {
          source_order_write_scan_reference(func, root, write, facts)
        } else {
          hot_lower_impl_carried_local_write_conflicts(func, root, write, facts)
        },
      )
      it.keep(
        if reference {
          source_order_write_scan_reference(func, write, root, facts)
        } else {
          hot_lower_impl_carried_local_write_conflicts(func, write, root, facts)
        },
      )
    }
  })
}

///|
test "bench bidirectional source-order scan depth=16" (it : @bench.T) {
  source_order_uniform_bench(it, 16, true)
}

///|
test "bench bidirectional source-order selected depth=16" (it : @bench.T) {
  source_order_uniform_bench(it, 16, false)
}

///|
test "bench bidirectional source-order scan depth=128" (it : @bench.T) {
  source_order_uniform_bench(it, 128, true)
}

///|
test "bench bidirectional source-order selected depth=128" (it : @bench.T) {
  source_order_uniform_bench(it, 128, false)
}
