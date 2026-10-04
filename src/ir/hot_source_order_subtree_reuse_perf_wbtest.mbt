///|
fn source_order_subtree_reuse_bench(
  it : @bench.T,
  count : Int,
  overlapping : Bool,
) -> Unit raise {
  let (func, roots, write) = source_order_uniform_fixture(count, 0)
  hot_verify_all(func).unwrap()
  it.bench(fn() {
    let facts = HotSourceOrderFacts::new(func)
    if overlapping {
      for root in roots {
        it.keep(hot_source_order_local_access_nodes(func, root, facts))
        it.keep(
          hot_lower_impl_carried_local_write_conflicts(func, write, root, facts),
        )
      }
    } else {
      it.keep(
        hot_source_order_local_access_nodes(
          func,
          roots[roots.length() - 1],
          facts,
        ),
      )
    }
  })
}

///|
test "bench source-order subtree reuse tiny cold" (it : @bench.T) {
  source_order_subtree_reuse_bench(it, 8, false)
}

///|
test "bench source-order subtree reuse wide cold" (it : @bench.T) {
  source_order_subtree_reuse_bench(it, 128, false)
}

///|
test "bench source-order subtree reuse tiny overlapping" (it : @bench.T) {
  source_order_subtree_reuse_bench(it, 8, true)
}

///|
test "bench source-order subtree reuse wide overlapping" (it : @bench.T) {
  source_order_subtree_reuse_bench(it, 128, true)
}
