///|
fn source_order_own_masks_reference_facts(
  func : HotFunc,
) -> HotSourceOrderFacts {
  let orders = SourceOrderOwnMasksReferenceOrders::new(func)
  {
    local_access_cache: Array::make(hot_node_count(func), -1),
    value_orders: orders.value_orders,
    node_effects: own_masks_reference_node_masks(func),
    first_effect_orders: orders.first_effect_orders,
    preceding_dependency_min_cache: Array::make(hot_node_count(func), -2),
    local_access_nodes: Array::make(hot_node_count(func), None),
    first_local_access_orders: @hashmap.new(),
    last_wide_access_root: -1,
    local_access_seen: Array::make(hot_node_count(func), 0),
    local_access_stamp: 0,
    dependency_scratch: None,
  }
}

///|
fn source_order_own_masks_bench(
  it : @bench.T,
  width : Int,
  reference : Bool,
) -> Unit {
  let func = cfg_root_snapshot_fixture(width, 16)
  let expected = source_order_own_masks_reference_facts(func)
  let actual = HotSourceOrderFacts::new(func)
  if actual.value_orders != expected.value_orders ||
    actual.first_effect_orders != expected.first_effect_orders ||
    actual.node_effects != expected.node_effects {
    abort("own-effect reuse changed source-order facts")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        source_order_own_masks_reference_facts(func)
      } else {
        HotSourceOrderFacts::new(func)
      },
    )
  })
}

///|
test "bench source-order own masks roots=8 recomputed" (it : @bench.T) {
  source_order_own_masks_bench(it, 8, true)
}

///|
test "bench source-order own masks roots=8 reused" (it : @bench.T) {
  source_order_own_masks_bench(it, 8, false)
}

///|
test "bench source-order own masks roots=64 recomputed" (it : @bench.T) {
  source_order_own_masks_bench(it, 64, true)
}

///|
test "bench source-order own masks roots=64 reused" (it : @bench.T) {
  source_order_own_masks_bench(it, 64, false)
}

///|
test "bench source-order own masks roots=128 recomputed" (it : @bench.T) {
  source_order_own_masks_bench(it, 128, true)
}

///|
test "bench source-order own masks roots=128 reused" (it : @bench.T) {
  source_order_own_masks_bench(it, 128, false)
}

///|
fn source_order_own_masks_default_bench(
  it : @bench.T,
  width : Int,
  reference : Bool,
) -> Unit {
  let func = cfg_root_snapshot_fixture(width, 16)
  if effects_build_node_masks(func) != own_masks_reference_node_masks(func) {
    abort("default own-effect computation changed subtree masks")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        own_masks_reference_node_masks(func)
      } else {
        effects_build_node_masks(func)
      },
    )
  })
}

///|
test "bench default effects roots=8 original" (it : @bench.T) {
  source_order_own_masks_default_bench(it, 8, true)
}

///|
test "bench default effects roots=8 selected" (it : @bench.T) {
  source_order_own_masks_default_bench(it, 8, false)
}

///|
test "bench default effects roots=128 original" (it : @bench.T) {
  source_order_own_masks_default_bench(it, 128, true)
}

///|
test "bench default effects roots=128 selected" (it : @bench.T) {
  source_order_own_masks_default_bench(it, 128, false)
}
