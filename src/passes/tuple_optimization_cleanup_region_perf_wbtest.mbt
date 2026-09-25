///|
fn tuple_cleanup_region_perf_fixture(
  count : Int,
) -> (@ir.HotFunc, Array[Int], Array[@ir.HotRegionRef]) {
  let wat = StringBuilder::new()
  wat.write_string("(module (func")
  for _ in 0..<count {
    wat.write_string(" block nop end")
  }
  wat.write_string("))")
  let func = @ir.ir_test_build_hot_from_wat(wat.to_string()).hot_func
  let roots : Array[Int] = []
  let regions : Array[@ir.HotRegionRef] = []
  let root_ref = @ir.HotRegionRef::root()
  if @ir.hot_region_root_count(func, root_ref) != count {
    abort("tuple cleanup benchmark root count changed")
  }
  for idx in 0..<count {
    let root_id = @ir.hot_region_get(func, root_ref, idx)
    roots.push(root_id)
    regions.push(@ir.hot_region_body_ref(func, root_id))
  }
  (func, roots, regions)
}

///|
fn tuple_cleanup_region_perf_plan(
  node_count : Int,
) -> HotTupleOptimizationRewriteCleanupPlan {
  {
    removable_root_defs: @bitset.BitSet::new(node_count),
    removable_root_regions: [],
    removable_root_region_seen: @bitset.BitSet::new(node_count),
    removable_root_region_root_seen: false,
    generated_nops: false,
    had_preexisting_nops: false,
    skip_drop_local_tee_cleanup: false,
    skip_scalarized_tuple_local_cleanup: false,
  }
}

///|
fn tuple_cleanup_region_perf_register(
  roots : Array[Int],
  regions : Array[@ir.HotRegionRef],
  node_count : Int,
) -> HotTupleOptimizationRewriteCleanupPlan {
  let plan = tuple_cleanup_region_perf_plan(node_count)
  for idx in 0..<roots.length() {
    tuple_optimization_cleanup_plan_add_removable_root(
      plan,
      roots[idx],
      regions[idx],
    )
  }
  for idx = roots.length() - 1; idx >= 0; idx = idx - 1 {
    tuple_optimization_cleanup_plan_add_removable_root(
      plan,
      roots[idx],
      regions[idx],
    )
  }
  plan
}

///|
test "tuple cleanup plan keeps distinct region order and deduplicates repeats" {
  let (func, roots, regions) = tuple_cleanup_region_perf_fixture(4)
  let plan = tuple_cleanup_region_perf_register(
    roots,
    regions,
    @ir.hot_node_count(func),
  )
  assert_eq(plan.removable_root_regions, regions)
  for root_id in roots {
    assert_true(plan.removable_root_defs[root_id])
  }
}

///|
test "tuple cleanup plan records root region once" {
  let (func, roots, _) = tuple_cleanup_region_perf_fixture(2)
  let plan = tuple_cleanup_region_perf_plan(@ir.hot_node_count(func))
  let root_ref = @ir.HotRegionRef::root()
  tuple_optimization_cleanup_plan_add_removable_root(plan, roots[0], root_ref)
  tuple_optimization_cleanup_plan_add_removable_root(plan, roots[1], root_ref)
  assert_eq(plan.removable_root_regions, [root_ref])
  assert_true(plan.removable_root_defs[roots[0]])
  assert_true(plan.removable_root_defs[roots[1]])
}

///|
fn tuple_cleanup_region_perf_bench(it : @bench.T, count : Int) -> Unit {
  let (func, roots, regions) = tuple_cleanup_region_perf_fixture(count)
  let node_count = @ir.hot_node_count(func)
  it.bench(fn() {
    it.keep(tuple_cleanup_region_perf_register(roots, regions, node_count))
  })
}

///|
test "bench tuple cleanup region dedup count=128" (it : @bench.T) {
  tuple_cleanup_region_perf_bench(it, 128)
}

///|
test "bench tuple cleanup region dedup count=256" (it : @bench.T) {
  tuple_cleanup_region_perf_bench(it, 256)
}
