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

///|
test "audit HOT local cse retains independent shared memory loads" {
  let input = pass_test_module_from_wat(
    "(module (memory 1 1 shared) (func (param i32) (result i32) local.get 0 i32.load drop local.get 0 i32.load))",
  )
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let first = @ir.hot_child_get(func, @ir.hot_root_get(func, 0), 0)
  assert_true(@ir.hot_node_get(func, first).op is @ir.HotOp::Load)
  assert_true(@ir.effects_reads_memory(@ir.effects_for_node(func, first)))
  @debug.assert_eq(@ir.hot_root_count(func), 2)
  let second = @ir.hot_root_get(func, 1)
  assert_true(@ir.hot_node_get(func, second).op is @ir.HotOp::Load)
  @debug.assert_eq(
    @ir.hot_type_results(func, @ir.hot_node_type(func, first)).length(),
    1,
  )
  @debug.assert_eq(
    @ir.hot_type_results(func, @ir.hot_node_type(func, second)).length(),
    1,
  )
  let ctx = HotPassContext::new(
    local_cse_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  ignore(local_cse_run(ctx, func))
  let @lib.Func(_, @lib.Expr(body)) = @ir.hot_lower_func(func)
  @debug.assert_eq(audit_count(body, fn(i) { i is @lib.I32Load(_) }), 2)
}

///|
test "local cse invalidates transitive global reads on global set" {
  for
    expr in [
      "global.get 0 i32.const 10 i32.add", "global.get 0 i32.const 10 i32.add i32.const 2 i32.mul",
    ] {
    for nested in [false, true] {
      let second = if nested {
        "(block (result i32) i32.const 5 global.set 0 " + expr + ")"
      } else {
        "i32.const 5 global.set 0 " + expr
      }
      let output = audit_run(
        "(module (global (mut i32) (i32.const 1)) (func (result i32) " +
        expr +
        " drop " +
        second +
        "))",
        "local-cse",
      )
      @debug.assert_eq(
        try! scalar_fixture_run(output.code_sec.unwrap().0[0], [], globals=[1L]),
        [if expr.ends_with("i32.mul") { 30L } else { 15L }],
      )
      @debug.assert_eq(
        audit_count(audit_body(output), fn(i) { i is @lib.GlobalGet(_) }),
        2,
      )
    }
  }
}

///|
test "local cse retains pure candidates across global set and stable global reads" {
  for
    pair in [
      ("local.get 0 i32.const 10 i32.add", "i32.const 5 global.set 0"),
      ("global.get 0 i32.const 10 i32.add", ""),
    ] {
    let (expr, middle) = pair
    let output = audit_run(
      "(module (global (mut i32) (i32.const 1)) (func (param i32) (result i32) " +
      expr +
      " drop " +
      middle +
      " " +
      expr +
      "))",
      "local-cse",
    )
    @debug.assert_eq(
      audit_count(audit_body(output), fn(i) { i is @lib.I32Add }),
      1,
    )
  }
}
