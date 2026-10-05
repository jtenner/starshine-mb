///|
fn vacuum_dropped_local_run_perf_fixture(count : Int) -> @lib.Module {
  let wat = StringBuilder::new()
  wat.write_string(
    "(module (global (mut i32) (i32.const 0)) (func (param i32) (local i32)",
  )
  for _ in 0..<count {
    wat.write_string(" local.get 0 drop")
  }
  wat.write_string(
    " local.get 0 if i32.const 1 local.set 1 local.get 0 br_if 0 end local.get 1 global.set 0))",
  )
  pass_test_module_from_wat(wat.to_string())
}

///|
fn vacuum_dropped_local_run_perf_bench(it : @bench.T, count : Int) -> Unit {
  let fixture = vacuum_dropped_local_run_perf_fixture(count)
  let ctx = HotPassContext::new(
    @ir.HotPassDescriptor::new("vacuum", requires=[], invalidates=[]),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  let preflight = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
  let workspace = VacuumDroppedNodeWorkspace::new(@ir.hot_node_count(preflight))
  if !hot_pass_vacuum_remove_dropped_local_gets_in_region_with_workspace(
      ctx,
      preflight,
      @ir.HotRegionRef::root(),
      workspace,
    ) ||
    @ir.hot_region_root_count(preflight, @ir.HotRegionRef::root()) >= count {
    abort("Vacuum dropped-local benchmark did not remove its candidates")
  }
  it.bench(fn() {
    let func = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
    ignore(
      hot_pass_vacuum_remove_dropped_local_gets_in_region_with_workspace(
        ctx,
        func,
        @ir.HotRegionRef::root(),
        workspace,
      ),
    )
    it.keep(func)
  })
}

///|
test "Vacuum batches dropped local run without removing branchy survivor" {
  let fixture = vacuum_dropped_local_run_perf_fixture(8)
  let func = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    @ir.HotPassDescriptor::new("vacuum", requires=[], invalidates=[]),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  let workspace = VacuumDroppedNodeWorkspace::new(@ir.hot_node_count(func))
  assert_true(
    hot_pass_vacuum_remove_dropped_local_gets_in_region_with_workspace(
      ctx,
      func,
      @ir.HotRegionRef::root(),
      workspace,
    ),
  )
  assert_eq(@ir.hot_region_root_count(func, @ir.HotRegionRef::root()), 2)
  assert_true(
    @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).op is @ir.HotOp::If,
  )
  assert_true(
    @ir.hot_node_get(func, @ir.hot_root_get(func, 1)).op is @ir.HotOp::GlobalSet,
  )
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) => fail("expected batched Vacuum HOT control to verify: \{err}")
  }
  let optimized = match
    run_hot_pipeline(fixture, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected branchy Vacuum pipeline success: \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected branchy Vacuum module to validate: \{err}")
  }
}

///|
test "bench Vacuum dropped local run count=128" (it : @bench.T) {
  vacuum_dropped_local_run_perf_bench(it, 128)
}

///|
test "bench Vacuum dropped local run count=256" (it : @bench.T) {
  vacuum_dropped_local_run_perf_bench(it, 256)
}

///|
test "bench Vacuum dropped local run count=512" (it : @bench.T) {
  vacuum_dropped_local_run_perf_bench(it, 512)
}

///|
test "bench Vacuum dropped local run count=1024" (it : @bench.T) {
  vacuum_dropped_local_run_perf_bench(it, 1024)
}
