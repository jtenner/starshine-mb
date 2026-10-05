///|
fn vacuum_interleaved_dropped_local_fixture(count : Int) -> @lib.Module {
  let wat = StringBuilder::new()
  wat.write_string(
    "(module (global (mut i32) (i32.const 0)) (func (param i32) (local i32)",
  )
  for _ in 0..<count {
    wat.write_string(" local.get 0 drop i32.const 0 drop")
  }
  wat.write_string(
    " local.get 0 if i32.const 1 local.set 1 local.get 0 br_if 0 end local.get 1 global.set 0))",
  )
  pass_test_module_from_wat(wat.to_string())
}

///|
fn vacuum_interleaved_dropped_local_bench(it : @bench.T, count : Int) -> Unit {
  let fixture = vacuum_interleaved_dropped_local_fixture(count)
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
    @ir.hot_region_root_count(preflight, @ir.HotRegionRef::root()) != count + 2 {
    abort("Vacuum interleaved fixture did not remove only local reads")
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
test "Vacuum batches interleaved dropped locals without removing survivors" {
  let fixture = vacuum_interleaved_dropped_local_fixture(32)
  let ctx = HotPassContext::new(
    @ir.HotPassDescriptor::new("vacuum", requires=[], invalidates=[]),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  let func = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
  let workspace = VacuumDroppedNodeWorkspace::new(@ir.hot_node_count(func))
  assert_true(
    hot_pass_vacuum_remove_dropped_local_gets_in_region_with_workspace(
      ctx,
      func,
      @ir.HotRegionRef::root(),
      workspace,
    ),
  )
  assert_eq(@ir.hot_region_root_count(func, @ir.HotRegionRef::root()), 34)
  for idx in 0..<32 {
    let root = @ir.hot_root_get(func, idx)
    assert_true(@ir.hot_node_get(func, root).op is @ir.HotOp::Drop)
    assert_true(
      @ir.hot_node_get(func, @ir.hot_child_get(func, root, 0)).op
      is @ir.HotOp::Const,
    )
  }
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) => fail("expected interleaved Vacuum HOT control: \{err}")
  }
  let optimized = match
    run_hot_pipeline(fixture, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected interleaved Vacuum pipeline: \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected interleaved Vacuum wasm validation: \{err}")
  }
}

///|
test "bench Vacuum interleaved dropped locals count=128" (it : @bench.T) {
  vacuum_interleaved_dropped_local_bench(it, 128)
}

///|
test "bench Vacuum interleaved dropped locals count=256" (it : @bench.T) {
  vacuum_interleaved_dropped_local_bench(it, 256)
}
