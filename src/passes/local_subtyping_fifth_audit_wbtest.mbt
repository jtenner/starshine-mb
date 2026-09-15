///|
test "fifth audit local subtyping null call preserves numeric result signature" {
  let input = pass_test_module_from_wat(
    "(module (type $t (func (result i32))) (func (result i32) (local (ref null nofunc)) ref.null nofunc local.set 0 local.get 0 call_ref $t))",
  )
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (body, _) = ls_refine_selects_instrs(
    body,
    [],
    locals,
    @ir.hot_module_context_from_module(input),
  )
  let output = input.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]),
  )
  assert_true(@validate.validate_module(output).is_ok())
}
