///|
test "fifth audit SSA preserves spilled operand order" {
  let input = pass_test_module_from_wat("(module (memory 1) (func (param i32) (result i32) (local i32 i32) local.get 0 i32.load local.set 1 local.get 0 call 1 local.get 1 local.tee 2 drop drop local.get 2) (func (param i32) (result i32) i32.const 7))")
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (rewritten, _) = run_hot_pipeline_raw_ssa_nomerge_repair_stack_spill_arg_alias(body, [@lib.ValType::i32()], locals, [])
  @debug.assert_eq(rewritten, body)
}

///|
test "fifth audit SSA call result is not its argument" {
  let input = pass_test_module_from_wat("(module (memory 1) (global i32 (i32.const 0)) (func (param i32) (result i32) (local i32 i32) local.get 0 call 1 local.set 1 local.get 0 local.get 0 local.get 0 local.set 2 global.get 0 local.get 2 i32.store i32.add) (func (param i32) (result i32) i32.const 7))")
  assert_true(@validate.validate_module(input).is_ok())
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (rewritten, _) = run_hot_pipeline_raw_ssa_nomerge_repair_stack_spill_arg_alias(body, [@lib.ValType::i32()], locals, [])
  @debug.assert_eq(rewritten, body)
}

///|
test "fifth audit SSA stored local does not alias another local" {
  let input = pass_test_module_from_wat("(module (memory 1) (global i32 (i32.const 0)) (func (param i32) (result i32) (local i32 i32) i32.const 42 local.set 1 global.get 0 local.get 1 i32.store local.get 0 local.get 0 local.set 2 global.get 0 local.get 2 i32.store) (func (param i32) (result i32) i32.const 7))")
  assert_true(@validate.validate_module(input).is_ok())
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (rewritten, _) = run_hot_pipeline_raw_ssa_nomerge_repair_stack_spill_arg_alias(body, [@lib.ValType::i32()], locals, [])
  @debug.assert_eq(rewritten, body)
}
