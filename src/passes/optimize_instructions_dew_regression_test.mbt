///|
test "optimize-instructions preserves zero call arguments below arithmetic" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #| (func $a (param i32) (result i32)
      #|   local.get 0 i32.const 10 i32.add)
      #| (func $b (param i32) (result i32)
      #|   local.get 0 i32.const 2 i32.mul)
      #| (func (export "main") (result i32)
      #|   i32.const 3 call $a i32.const 0 call $b i32.add))
    ),
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "optimize-instructions",
  ]).unwrap()
  let @lib.Func(_, @lib.Expr(main)) = output.code_sec.unwrap().0[2]
  @debug.assert_eq(main, [
    @lib.Instruction::i32_const(@lib.I32(3)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::i32_add(),
  ])
  // The unrelated multiplication must still be optimized.
  assert_true(output.code_sec.unwrap().0[1] != input.code_sec.unwrap().0[1])
  ignore(@validate.validate_module(output).unwrap())
}

///|
test "optimize-instructions removes actual neutral left and right operands" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #| (func (param i32) (result i32) i32.const 0 local.get 0 i32.add)
      #| (func (param i64) (result i64) i64.const 0 local.get 0 i64.add)
      #| (func (param i32) (result i32) local.get 0 i32.const 0 i32.add))
    ),
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "optimize-instructions",
  ]).unwrap()
  for function_ in output.code_sec.unwrap().0 {
    let @lib.Func(_, @lib.Expr(body)) = function_
    @debug.assert_eq(body, [@lib.Instruction::local_get(@lib.LocalIdx::new(0U))])
  }
  ignore(@validate.validate_module(output).unwrap())
}
