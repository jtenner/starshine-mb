///|
test "dae2 command result wrapper parity preserves effectful argument order without a block" {
  let input = @passes.pass_test_module_from_wat(
    "(module (import \"host\" \"effect\" (func (param i32) (result i32))) (func (param i32 i32 i32) (result i32) local.get 0) (func (export \"run\") (result i32) i32.const 1 call 0 i32.const 2 call 0 i32.const 3 call 0 call 1))",
  )
  let output = optimize_module_with_pass_flags(
    input,
    ["dae2"],
    OptimizeOptions::new(),
  ).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  assert_false(body.any(fn(i) { i is @lib.Block(_, _) }))
  @debug.assert_eq(body.filter(fn(i) { i is @lib.Call(_) }).length(), 4)
  @debug.assert_eq(body.filter(fn(i) { i is @lib.I32Const(_) }), [
    @lib.Instruction::i32_const(1),
    @lib.Instruction::i32_const(2),
    @lib.Instruction::i32_const(3),
  ])
}
