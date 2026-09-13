///|
test "campaign constraint lowering keeps terminating loop stack closure" {
  let input = pass_test_module_from_wat(
    (
      #|(module (func (loop (result i32) br 0) drop unreachable))
    ),
  )
  let @lib.CodeSec(funcs) = input.code_sec.unwrap()
  let output = input.with_code_sec(
    @lib.CodeSec::new([ca_lower_refinalize(funcs[0], input)]),
  )
  assert_true(@validate.validate_module(output) is Ok(_))
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_true(body[body.length() - 1] is @lib.Unreachable)
}
