///|
test "optimize-instructions retains tee and removes idempotent integer reuse" {
  for (width, op) in [("i32", "and"), ("i32", "or"), ("i64", "and"), ("i64", "or")] {
    let func = optimize_instructions_test_run_hot(
      "(module (func (param \{width}) (result \{width}) (local \{width}) local.get 0 local.tee 1 local.get 1 \{width}.\{op}))",
    )
    let root = @ir.hot_root_get(func, 0)
    assert_true(@ir.hot_node_get(func, root).op is @ir.HotOp::LocalTee)
    @debug.assert_eq(@ir.hot_node_get(func, root).imm0, 1)
    @debug.assert_eq(@ir.hot_child_count(func, root), 1)
    assert_true(@ir.hot_node_get(func, @ir.hot_child_get(func, root, 0)).op is @ir.HotOp::LocalGet)
  }
}

///|
test "optimize-instructions tee identity retains trapping dividend" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32) (result i32) (local i32) local.get 0 local.get 1 i32.div_s local.tee 2 local.get 2 i32.or))",
  )
  let root = @ir.hot_root_get(func, 0)
  assert_true(@ir.hot_node_get(func, root).op is @ir.HotOp::LocalTee)
  @debug.assert_eq(@ir.hot_node_exact_instr(func, @ir.hot_child_get(func, root, 0)), Some(@lib.Instruction::i32_div_s()))
}

///|
test "optimize-instructions tee identity rejects a changed rhs local" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32) (result i32) (local i32) (i32.or (local.tee 2 (local.get 0)) (block (result i32) (local.set 2 (local.get 1)) (local.get 2)))))",
  )
  @debug.assert_eq(@ir.hot_node_exact_instr(func, @ir.hot_root_get(func, 0)), Some(@lib.Instruction::i32_or()))
}
