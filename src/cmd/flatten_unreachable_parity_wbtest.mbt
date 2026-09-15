///|
test "flatten command parity removes unreachable root debris" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (export \"run\") (block (result i32) unreachable) drop i32.const 0 if (result i32) unreachable else i32.const 30 end drop (loop (result i32) unreachable) drop))",
  )
  let output = optimize_module_with_pass_flags(
    input,
    ["flatten"],
    OptimizeOptions::new(),
  ).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(body, [@lib.Instruction::unreachable_()])
  @debug.assert_eq(locals.length(), 0)
}
