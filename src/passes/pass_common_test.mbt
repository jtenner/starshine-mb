///|
fn pass_common_fixture_wat() -> String {
  "(module (func (param i32) (local i32) local.get 0 if i32.const 7 local.set 1 else nop end local.get 1 drop))"
}

///|
test "pass_require helpers build and reuse derived analyses" {
  let func = pass_test_lift_first_func(pass_common_fixture_wat())
  let ctx = HotPassContext::new(
    @ir.HotPassDescriptor::new("test"),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  let cfg0 = pass_require_cfg(ctx, func)
  let cfg1 = pass_require_cfg(ctx, func)
  let _dom = pass_require_dom(ctx, func)
  let _liveness = pass_require_liveness(ctx, func)
  let _ssa = pass_require_ssa(ctx, func)

  assert_eq(cfg0, cfg1)
  assert_true(ctx.cache.cfg is Some(_))
  assert_true(ctx.cache.dom is Some(_))
  assert_true(ctx.cache.liveness is Some(_))
  assert_true(ctx.cache.ssa is Some(_))
}

///|
test "pass_splice_region and pass_delete_detached_nodes mark mutation" {
  let func = pass_test_lift_first_func("(module (func nop i32.const 4 drop))")
  let ctx = HotPassContext::new(
    @ir.HotPassDescriptor::new("test"),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  let rev0 = @ir.hot_revision_current(func)

  let removed = pass_splice_region(ctx, func, @ir.HotRegionRef::root(), 0, 1, [])
  pass_delete_detached_nodes(ctx, func, removed)

  assert_true(@ir.hot_revision_current(func) > rev0)
  assert_eq(@ir.hot_root_count(func), 1)
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected helper-mutated function to verify, got \{err}")
  }
}

///|
test "pass_test helpers run public pipeline code" {
  let optimized = match
    pass_test_run_pipeline("(module (func (result i32) nop i32.const 9))", [
      "vacuum",
    ]) {
    Ok(mod) => mod
    Err(err) => fail("expected helper pipeline success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("nop"))
  assert_true(pretty.contains("I32(9)"))
}
