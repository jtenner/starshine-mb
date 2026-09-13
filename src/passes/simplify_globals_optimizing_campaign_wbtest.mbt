///|
test "campaign simplify globals cleanup consumes block parameters" {
  let input = pass_test_module_from_wat(
    (
      #|(module (type $b (func (param i32) (result i32)))
      #| (func i32.const 99 (block (type $b) i32.const 1 br 0) drop))
    ),
  )
  let @lib.CodeSec(funcs) = input.code_sec.unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = funcs[0]
  let (cleaned, _) = sgo_final_cleanup_instrs(body)
  let output = input.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(cleaned))]),
  )
  assert_true(@validate.validate_module(output) is Ok(_))
}
