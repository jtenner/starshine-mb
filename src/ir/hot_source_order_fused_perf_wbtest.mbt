///|
fn source_order_facts_reference(func : HotFunc) -> HotSourceOrderFacts {
  {
    local_access_cache: Array::make(hot_node_count(func), -1),
    value_orders: source_order_value_reference(func),
    node_effects: effects_build_node_masks(func),
    first_effect_orders: hot_lower_impl_build_first_effect_orders(func),
    preceding_dependency_min_cache: Array::make(hot_node_count(func), -2),
    local_access_nodes: Array::make(hot_node_count(func), None),
    first_local_access_orders: @hashmap.new(),
    local_access_seen: Array::make(hot_node_count(func), 0),
    local_access_stamp: 0,
    dependency_scratch: None,
  }
}

///|
fn source_order_fused_bench(
  it : @bench.T,
  width : Int,
  reference : Bool,
) -> Unit {
  let func = cfg_root_snapshot_fixture(width, 16)
  let expected = source_order_facts_reference(func)
  let actual = HotSourceOrderFacts::new(func)
  if actual.value_orders != expected.value_orders ||
    actual.first_effect_orders != expected.first_effect_orders {
    abort("source-order control changed operand metadata")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        source_order_facts_reference(func)
      } else {
        HotSourceOrderFacts::new(func)
      },
    )
  })
}

///|
test "bench source-order facts roots=8 reference" (it : @bench.T) {
  source_order_fused_bench(it, 8, true)
}

///|
test "bench source-order facts roots=8 selected" (it : @bench.T) {
  source_order_fused_bench(it, 8, false)
}

///|
test "bench source-order facts roots=64 reference" (it : @bench.T) {
  source_order_fused_bench(it, 64, true)
}

///|
test "bench source-order facts roots=64 selected" (it : @bench.T) {
  source_order_fused_bench(it, 64, false)
}

///|
test "bench source-order facts roots=128 reference" (it : @bench.T) {
  source_order_fused_bench(it, 128, true)
}

///|
test "bench source-order facts roots=128 selected" (it : @bench.T) {
  source_order_fused_bench(it, 128, false)
}
