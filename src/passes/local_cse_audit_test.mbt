///|
test "audit local cse preserves repeated tee writes" {
  let wat =
    #|(module (func (result i32) (local i32)
    #| i32.const 1 local.tee 0 i32.const 3 i32.add drop
    #| i32.const 2 local.set 0
    #| i32.const 1 local.tee 0 i32.const 3 i32.add drop local.get 0))
  let output = audit_run(wat, "local-cse")
  @debug.assert_eq(try! scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    1L,
  ])
}

///|
test "audit local cse accounts for global result producers" {
  let wat =
    #|(module (global (mut i32) (i32.const 9))
    #| (func (result i32 i32)
    #| i32.const 3 i32.const 4 global.get 0 i32.add drop
    #| i32.const 3 i32.const 4 i32.add))
  let output = audit_run(wat, "local-cse")
  @debug.assert_eq(
    try! scalar_fixture_run(output.code_sec.unwrap().0[0], [], globals=[9L]),
    [3L, 7L],
  )
}

///|
test "audit HOT local cse retains repeated effectful calls" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"f\" (func $f (param i32) (result i32))) (func (param i32) local.get 0 call $f drop local.get 0 call $f drop))",
  )
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(1U))
  let ctx = HotPassContext::new(
    local_cse_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  ignore(local_cse_run(ctx, func))
  let root = @ir.HotRegionRef::root()
  let second = @ir.hot_region_get(func, root, 1)
  assert_true(
    @ir.hot_node_get(func, @ir.hot_child_get(func, second, 0)).op
    is @ir.HotOp::Call,
  )
}
