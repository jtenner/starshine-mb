///|
test "fifth audit DAE reference branch label" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) i32.const 1 if (result i32) i32.const 7 ref.null any br_on_null 0 drop drop i32.const 8 else i32.const 0 end drop i32.const 9))",
  )
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let rewritten = dae_simplify_rewritten_control_instrs(body, false)
  assert_true(
    rewritten.any(fn(i) { i is @lib.Block(_, _) || i is @lib.If(_, _, _) }),
  )
}
