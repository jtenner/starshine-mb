///|
test "optimize-instructions matches v132 signed maximum comparisons" {
  let i32_func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 2147483647 i32.lt_s))",
  )
  let i32_root = @ir.hot_root_get(i32_func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(i32_func, i32_root),
    Some(@lib.Instruction::i32_ne()),
  )

  let i64_func = optimize_instructions_test_run_hot(
    "(module (func (param i64) (result i32) local.get 0 i64.const 9223372036854775807 i64.lt_s))",
  )
  let i64_root = @ir.hot_root_get(i64_func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(i64_func, i64_root),
    Some(@lib.Instruction::i64_ne()),
  )
}

///|
test "optimize-instructions matches v132 signed minimum comparisons" {
  let i32_func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const -2147483648 i32.gt_s))",
  )
  let i32_root = @ir.hot_root_get(i32_func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(i32_func, i32_root),
    Some(@lib.Instruction::i32_ne()),
  )

  let i64_func = optimize_instructions_test_run_hot(
    "(module (func (param i64) (result i32) local.get 0 i64.const -9223372036854775808 i64.gt_s))",
  )
  let i64_root = @ir.hot_root_get(i64_func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(i64_func, i64_root),
    Some(@lib.Instruction::i64_ne()),
  )
}

///|
test "optimize-instructions signed endpoint comparison keeps effectful lhs" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (result i32) call $effect i32.const 2147483647 i32.lt_s) (func $effect (result i32) i32.const 3))",
  )
  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_ne()),
  )
  let lhs = @ir.hot_child_get(func, root, 0)
  match @ir.hot_node_get(func, lhs).op {
    @ir.HotOp::Call => ()
    other => fail("expected effectful lhs call to remain, got \{other}")
  }
}
