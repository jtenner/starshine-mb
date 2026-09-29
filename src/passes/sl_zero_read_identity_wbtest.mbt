///|
test "SimplifyLocals zero-read cleanup borrows unchanged bodies including NaNs" {
  let mod_ = pass_test_module_from_wat(
    "(module (func (export \"f\") (param i32) (result i32) f64.const nan:0x42 drop local.get 0))",
  )
  let func = mod_.code_sec.unwrap().0[0]
  let @lib.Func(_, @lib.Expr(body)) = func
  let before = @binary.encode_module(mod_).unwrap()
  let result = run_hot_pipeline_simplify_locals_lowered_drop_zero_read_sets_body(
    body,
    [1],
  )
  assert_true(physical_equal(result, body))
  assert_true(
    physical_equal(
      run_hot_pipeline_simplify_locals_lowered_drop_zero_read_sets_func(func),
      func,
    ),
  )
  assert_eq(@binary.encode_module(mod_).unwrap(), before)
}

///|
test "SimplifyLocals zero-read cleanup preserves siblings and active nested rewrites" {
  let mod_ = pass_test_module_from_wat(
    "(module (func (export \"f\") (param i32) (local i32) block local.get 0 drop end i32.const 1 if i32.const 7 local.set 1 else loop i32.const 9 local.set 1 end end try_table block i32.const 3 local.set 1 end end))",
  )
  let func = mod_.code_sec.unwrap().0[0]
  let @lib.Func(locals, @lib.Expr(body)) = func
  let before = @binary.encode_module(mod_).unwrap()
  let result = run_hot_pipeline_simplify_locals_lowered_drop_zero_read_sets_body(
    body,
    [1, 0],
  )
  assert_false(physical_equal(result, body))
  assert_true(physical_equal(result[0], body[0]))
  assert_eq(result, sl_zero_read_before_identity(body, [1, 0]))
  let rewritten = mod_.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(result))]),
  )
  @validate.validate_module(rewritten).unwrap()
  for
    name in [
      "simplify-locals", "simplify-locals-nonesting", "simplify-locals-notee", "simplify-locals-nostructure",
      "simplify-locals-notee-nostructure",
    ] {
    let output = run_hot_pipeline(mod_, HotPipelineOptions::new(), [name]).unwrap()
    @validate.validate_module(output).unwrap()
  }
  assert_eq(@binary.encode_module(mod_).unwrap(), before)
}
