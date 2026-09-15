///|
test "fifth audit SSA intentionally ineligible assignment motion across nested read" {
  let input = pass_test_module_from_wat(
    "(module (global (mut i32) (i32.const 0)) (func (param i32) (local i32) block i32.const 1 local.set 1 block local.get 0 global.set 0 end local.get 1 local.set 0 br 0 end))",
  )
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (rewritten, _) = run_hot_pipeline_raw_ssa_nomerge_redirect_branch_alias_suffix(
    body,
  )
  @debug.assert_eq(rewritten, body)
}

///|
test "fifth audit SSA preserves copied temporary read outside its block" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i32) block i32.const 7 local.set 1 local.get 1 local.set 0 br 0 end local.get 1))",
  )
  assert_true(@validate.validate_module(input).is_ok())
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (rewritten, _) = run_hot_pipeline_raw_ssa_nomerge_redirect_branch_alias_suffix(
    body,
  )
  @debug.assert_eq(rewritten, body)
}
