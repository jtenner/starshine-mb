///|
test "command optimize-instructions removes integer tee reuse" {
  let input = @wast.wast_to_binary_module(
    "(module (func (param i64) (result i64 i64) (local i64) local.get 0 local.tee 1 local.get 1 i64.or local.get 1))",
    filename="tee-reuse.wat",
  ).unwrap()
  let output = optimize_module_with_pass_flags(
    input,
    ["optimize-instructions"],
    OptimizeOptions::new(),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.CodeSec(codes) = output.code_sec.unwrap()
  let @lib.Func(_, @lib.Expr(body)) = codes[0]
  @debug.assert_eq(body, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ])
}
