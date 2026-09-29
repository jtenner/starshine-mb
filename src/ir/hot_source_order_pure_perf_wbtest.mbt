///|
fn source_order_pure_bench(
  it : @bench.T,
  count : Int,
  minimum : Bool,
  reference : Bool,
) -> Unit {
  let (func, root, _, barrier) = source_order_pure_fixture(count)
  let facts = HotSourceOrderFacts::new(func)
  if !effects_is_pure(facts.node_effects[root]) {
    abort("pure-tree benchmark contains effects")
  }
  let scratch = HotSourceOrderScratch::new(hot_node_count(func))
  it.bench(fn() {
    if minimum {
      let cache = Array::make(hot_node_count(func), -2)
      it.keep(
        if reference {
          source_order_reference_hot_lower_impl_preceding_dependency_min_node(
            func,
            root,
            cache,
            facts.value_orders,
            facts.node_effects,
          )
        } else {
          hot_lower_impl_preceding_dependency_min_node(
            func,
            root,
            cache,
            facts.value_orders,
            facts.node_effects,
          )
        },
      )
    } else {
      let selected : Array[NodeId] = []
      if reference {
        source_order_reference_hot_lower_impl_collect_preceding_dependency(
          func,
          root,
          barrier,
          root,
          facts.value_orders,
          facts.node_effects,
          scratch.seen_consumer,
          scratch.consumer_bounds,
          scratch.touched,
          selected,
        )
      } else {
        hot_lower_impl_collect_preceding_dependency(
          func,
          root,
          barrier,
          root,
          facts.value_orders,
          facts.node_effects,
          scratch.seen_consumer,
          scratch.consumer_bounds,
          scratch.touched,
          selected,
        )
      }
      it.keep(selected)
      for node in scratch.touched {
        scratch.seen_consumer[node] = hot_node_count(func)
        scratch.consumer_bounds[node] = -1
      }
      scratch.touched.clear()
    }
  })
}

///|
test "bench pure dependency leaves=64 collect reference" (it : @bench.T) {
  source_order_pure_bench(it, 64, false, true)
}

///|
test "bench pure dependency leaves=64 collect selected" (it : @bench.T) {
  source_order_pure_bench(it, 64, false, false)
}

///|
test "bench pure dependency leaves=64 minimum reference" (it : @bench.T) {
  source_order_pure_bench(it, 64, true, true)
}

///|
test "bench pure dependency leaves=64 minimum selected" (it : @bench.T) {
  source_order_pure_bench(it, 64, true, false)
}

///|
test "bench pure dependency leaves=512 collect reference" (it : @bench.T) {
  source_order_pure_bench(it, 512, false, true)
}

///|
test "bench pure dependency leaves=512 collect selected" (it : @bench.T) {
  source_order_pure_bench(it, 512, false, false)
}

///|
test "bench pure dependency leaves=512 minimum reference" (it : @bench.T) {
  source_order_pure_bench(it, 512, true, true)
}

///|
test "bench pure dependency leaves=512 minimum selected" (it : @bench.T) {
  source_order_pure_bench(it, 512, true, false)
}
