///|
test "optimize-instructions type group parity nondeferred remaps live array indices" {
  let input = pass_test_module_from_wat(
    "(module (type (struct (field i32))) (type (array (mut i32))) (func (result (ref 1)) unreachable))",
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::new([]),
        @lib.Expr::new([
          @lib.Instruction::i32_const(1),
          @lib.Instruction::array_new_fixed(@lib.TypeIdx::new(1U), 1U),
        ]),
      ),
    ]),
  )
  let entry = pass_registry_lookup("optimize-instructions").unwrap()
  let options = HotPipelineOptions::new()
  let output = run_hot_pipeline_apply_hot_pass(
    input,
    entry,
    options,
    defer_optimize_instructions_writeback_guard=false,
  ).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 2)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(
    body.last(),
    Some(@lib.Instruction::array_new_fixed(@lib.TypeIdx::new(0U), 1U)),
  )
}

///|
test "optimize-instructions type group parity stack remaps live array indices" {
  let input = pass_test_module_from_wat(
    "(module (type (struct (field i32))) (type (array (mut i32))) (func (result (ref 1)) unreachable))",
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::new([]),
        @lib.Expr::new([
          @lib.Instruction::i32_const(1),
          @lib.Instruction::array_new_fixed(@lib.TypeIdx::new(1U), 1U),
        ]),
      ),
    ]),
  )
  let entry = pass_registry_lookup("optimize-instructions").unwrap()
  let options = HotPipelineOptions::new()
  let output = run_hot_pipeline_apply_hot_pass_stack(input, [entry], options).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 2)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(
    body.last(),
    Some(@lib.Instruction::array_new_fixed(@lib.TypeIdx::new(0U), 1U)),
  )
}

///|
test "optimize-instructions type group parity touched stack remaps live array indices" {
  let input = pass_test_module_from_wat(
    "(module (type (struct (field i32))) (type (array (mut i32))) (func (result (ref 1)) unreachable))",
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::new([]),
        @lib.Expr::new([
          @lib.Instruction::i32_const(1),
          @lib.Instruction::array_new_fixed(@lib.TypeIdx::new(1U), 1U),
        ]),
      ),
    ]),
  )
  let entry = pass_registry_lookup("optimize-instructions").unwrap()
  let options = HotPipelineOptions::new()
  let output = run_hot_pipeline_apply_hot_pass_stack_to_touched(
    input,
    [entry.descriptor.unwrap()],
    [true],
    options,
  ).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 2)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(
    body.last(),
    Some(@lib.Instruction::array_new_fixed(@lib.TypeIdx::new(0U), 1U)),
  )
}

///|
test "optimize-instructions type group parity touched single remaps live array indices" {
  let input = pass_test_module_from_wat(
    "(module (type (struct (field i32))) (type (array (mut i32))) (func (result (ref 1)) unreachable))",
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::new([]),
        @lib.Expr::new([
          @lib.Instruction::i32_const(1),
          @lib.Instruction::array_new_fixed(@lib.TypeIdx::new(1U), 1U),
        ]),
      ),
    ]),
  )
  let entry = pass_registry_lookup("optimize-instructions").unwrap()
  let options = HotPipelineOptions::new()
  let output = run_hot_pipeline_apply_hot_pass_to_touched(
    input,
    entry.descriptor.unwrap(),
    [true],
    options,
  ).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 2)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(
    body.last(),
    Some(@lib.Instruction::array_new_fixed(@lib.TypeIdx::new(0U), 1U)),
  )
}
