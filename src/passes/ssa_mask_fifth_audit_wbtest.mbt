///|
test "fifth audit SSA intentionally unrelated masked local 1" {
  let input = pass_test_module_from_wat("(module (func (param i32) (result i32) (local i32) block local.get 0 i32.const 0 i32.and local.tee 1 drop end local.get 0 i32.eqz))")
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (rewritten, _) = run_hot_pipeline_raw_ssa_nomerge_retarget_mask_eqz_after_nested_update(body)
  @debug.assert_eq(rewritten, body)
}

///|
test "fifth audit SSA intentionally unrelated masked local 7" {
  let input = pass_test_module_from_wat("(module (func (param i32) (result i32) (local i32) block local.get 0 i32.const 7 i32.and local.tee 1 drop end local.get 0 i32.eqz))")
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (rewritten, _) = run_hot_pipeline_raw_ssa_nomerge_retarget_mask_eqz_after_nested_update(body)
  @debug.assert_eq(rewritten, body)
}

///|
test "fifth audit SSA intentionally unrelated masked local 42" {
  let input = pass_test_module_from_wat("(module (func (param i32) (result i32) (local i32) block local.get 0 i32.const 42 i32.and local.tee 1 drop end local.get 0 i32.eqz))")
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (rewritten, _) = run_hot_pipeline_raw_ssa_nomerge_retarget_mask_eqz_after_nested_update(body)
  @debug.assert_eq(rewritten, body)
}
