///|
test "fourth audit flatten preserves null trap before later operand effect" {
  let output = audit_run(
    "(module (global $g (mut i32) (i32.const 0)) (func $sink (param (ref any) i32)) (func (export \"run\") (param $x anyref) local.get $x ref.as_non_null (block (result i32) i32.const 99 global.set $g i32.const 0) call $sink))",
    "flatten",
  )
  let body = audit_body(output, index=1)
  let mut saw_trap = false
  for instr in body {
    if instr is @lib.RefAsNonNull {
      saw_trap = true
    }
    if instr is @lib.GlobalSet(_) {
      assert_true(saw_trap)
    }
  }
}

///|
test "fourth audit HOT flatten preserves null trap before later operand effect" {
  let input = pass_test_module_from_wat(
    "(module (global $g (mut i32) (i32.const 0)) (func $sink (param (ref any) i32)) (func (param $x anyref) local.get $x ref.as_non_null (block (result i32) i32.const 99 global.set $g i32.const 0) call $sink))",
  )
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(1U))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  ignore(hot_pass_run(ctx, func).unwrap())
  let @lib.Func(_, @lib.Expr(body)) = @ir.hot_lower_func(func)
  let mut saw_trap = false
  for instr in body {
    if instr is @lib.RefAsNonNull {
      saw_trap = true
    }
    if instr is @lib.GlobalSet(_) {
      assert_true(saw_trap)
    }
  }
}
