///|
fn tuple_copy_child_mask_perf_fixture(islands : Int) -> String {
  let wat = StringBuilder::new()
  wat.write_string(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (import \"env\" \"tri\" (func (type 0))) (func (local",
  )
  for _ in 0..<(islands * 12) {
    wat.write_string(" i32")
  }
  wat.write_string(")")
  for island in 0..<islands {
    let base = island * 12
    wat.write_string(
      " i32.const 42 i32.const 10000 call 0 local.set \{base + 8} local.set \{base + 7} local.tee \{base + 6} local.set \{base + 11} local.get \{base + 7} local.set \{base + 10} block (result i32 i32 i32) local.get \{base + 11} local.get \{base + 10} local.get \{base + 8} end local.set \{base + 5} local.set \{base + 4} local.tee \{base + 3} block (result i32 i32 i32) local.get \{base + 3} local.get \{base + 4} local.get \{base + 5} end local.set \{base + 2} local.set \{base + 1} local.tee \{base} drop drop local.get \{base} drop",
    )
  }
  wat.write_string("))")
  wat.to_string()
}

///|
fn tuple_copy_child_mask_perf_bench(it : @bench.T, islands : Int) -> Unit {
  let fixture = @ir.ir_test_build_hot_from_wat(
    tuple_copy_child_mask_perf_fixture(islands),
  )
  let func = fixture.hot_func
  let use_def = @ir.use_def_build(func)
  let analysis = tuple_optimization_analyze(func, use_def)
  if analysis.groups.length() != islands * 3 {
    abort("tuple-copy mask fixture did not form three groups per island")
  }
  it.bench(fn() {
    it.keep(
      tuple_optimization_build_group_rewrite_mask(
        func,
        use_def,
        analysis.query_summary,
        analysis.groups,
      ),
    )
  })
}

///|
test "TupleOptimization copy-consumer index preserves child order and host rules" {
  let fixture = @ir.ir_test_build_hot_from_wat(
    tuple_copy_child_mask_perf_fixture(1),
  )
  let use_def = @ir.use_def_build(fixture.hot_func)
  let groups = tuple_optimization_analyze(fixture.hot_func, use_def).groups
  assert_eq(groups.length(), 3)
  groups[0].copy_source = Some(0)
  groups[1].copy_source = Some(0)
  groups[2].copy_source = Some(0)
  groups[1].host_lane = None
  groups[2].host_lane = None
  let no_hosts = tuple_optimization_build_copy_consumers(groups)
  assert_eq(no_hosts.children_by_source[0], [0, 1, 2])
  assert_false(no_hosts.has_host_consumer[0])
  groups[2].host_lane = Some(0)
  let with_host = tuple_optimization_build_copy_consumers(groups)
  assert_true(with_host.has_host_consumer[0])
  groups[2].copy_source = Some(99)
  let invalid = tuple_optimization_build_copy_consumers(groups)
  assert_eq(invalid.children_by_source[0], [0, 1])
  assert_false(invalid.has_host_consumer[0])
}

///|
test "bench TupleOptimization copy-child mask islands=32" (it : @bench.T) {
  tuple_copy_child_mask_perf_bench(it, 32)
}

///|
test "bench TupleOptimization copy-child mask islands=64" (it : @bench.T) {
  tuple_copy_child_mask_perf_bench(it, 64)
}
