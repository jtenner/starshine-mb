///|
test "local-subtyping command return parity removes the dead root continuation" {
  let input = @passes.pass_test_module_from_wat(
    "(module (type (func)) (type (struct (field i32))) (func (type 0) (local anyref) struct.new_default 1 local.set 0 local.get 0 drop return local.get 0 drop))",
  )
  let output = optimize_module_with_pass_flags(
    input,
    ["local-subtyping"],
    OptimizeOptions::new(),
  ).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(body.last(), Some(@lib.Instruction::return_()))
  @debug.assert_eq(body.filter(fn(i) { i is @lib.LocalGet(_) }).length(), 1)
}
