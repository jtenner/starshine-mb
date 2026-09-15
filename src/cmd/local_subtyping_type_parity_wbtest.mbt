///|
test "local-subtyping command type parity prunes dead groups after narrowing" {
  let input = @passes.pass_test_module_from_wat(
    "(module (type (func)) (rec (type (struct)) (type (struct))) (type (struct (field i32))) (func (type 0) (local anyref) struct.new_default 3 local.set 0 local.get 0 drop))",
  )
  let output = optimize_module_with_pass_flags(
    input,
    ["local-subtyping"],
    OptimizeOptions::new(),
  ).unwrap()
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 2)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(
    body[0],
    @lib.Instruction::struct_new_default(@lib.TypeIdx::new(1U)),
  )
}
