///|
test "encoding cleanup skips nop and block rewrites in branchful candidate-free body" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) block loop local.get 0 br_if 0 end end))",
  )
  @validate.validate_module(input).unwrap()
  let nop_attempts = [0]
  let flatten_attempts = [0]
  let output = pass_cleanup_control_and_type_encoding(
    input,
    nop_rewrite_attempts=Some(nop_attempts),
    flatten_attempts=Some(flatten_attempts),
  )
  assert_eq(output, input)
  @validate.validate_module(output).unwrap()
  assert_eq(nop_attempts[0], 0)
  assert_eq(flatten_attempts[0], 0)
}

///|
test "encoding cleanup still removes nested nop and branchless block" {
  let input = pass_test_module_from_wat(
    "(module (func loop block nop end br 0 end))",
  )
  @validate.validate_module(input).unwrap()
  let nop_attempts = [0]
  let flatten_attempts = [0]
  let output = pass_cleanup_control_and_type_encoding(
    input,
    nop_rewrite_attempts=Some(nop_attempts),
    flatten_attempts=Some(flatten_attempts),
  )
  @validate.validate_module(output).unwrap()
  assert_true(output != input)
  assert_eq(nop_attempts[0], 1)
  assert_eq(flatten_attempts[0], 1)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  match body {
    [@lib.Loop(_, @lib.Expr([@lib.Br(_)]))] => ()
    _ => fail("nested branchless block was not removed")
  }
}
