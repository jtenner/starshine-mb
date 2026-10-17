///|
fn code_pushing_value_br_if_encoding_fixture() -> @lib.Module {
  pass_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i32 i32) block (result i32) i32.const 7 local.set 1 i32.const 9 local.set 2 i32.const 42 local.get 0 br_if 0 drop local.get 1 drop local.get 2 end))",
  )
}

///|
test "code-pushing keeps value br_if drop before moved sets for canonical size" {
  let output = run_hot_pipeline(
    code_pushing_value_br_if_encoding_fixture(),
    HotPipelineOptions::new(),
    ["code-pushing"],
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let body = match output.code_sec.unwrap().0[0] {
    @lib.Func(_, @lib.Expr([@lib.Block(_, @lib.Expr(body))])) => body
    _ => fail("expected one result block")
  }
  @debug.assert_eq(body, [
    @lib.Instruction::i32_const(@lib.I32(42)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
  ])
  // The verified Binaryen 133 pass output is 51 bytes with this order.
  assert_eq(@binary.encode_module(output).unwrap().length(), 51)
}

///|
test "code-pushing keeps value br_if drop before one moved set" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i32) block (result i32) i32.const 7 local.set 1 i32.const 42 local.get 0 br_if 0 drop local.get 1 end))",
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "code-pushing",
  ]).unwrap()
  @validate.validate_module(output).unwrap()
  let body = match output.code_sec.unwrap().0[0] {
    @lib.Func(_, @lib.Expr([@lib.Block(_, @lib.Expr(body))])) => body
    _ => fail("expected one result block")
  }
  @debug.assert_eq(body, [
    @lib.Instruction::i32_const(@lib.I32(42)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ])
  // The verified Binaryen 133 pass output is 44 bytes with this order.
  assert_eq(@binary.encode_module(output).unwrap().length(), 44)
}
