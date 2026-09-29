///|
test "raw precompute preserves an unchanged function and its reusable body" {
  let mod_ = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) local.get 0))",
  )
  let original = mod_.code_sec.unwrap().0[0]
  let (result, changed, reason) = precompute_run_raw_func(original, None).unwrap()
  assert_false(changed)
  assert_eq(reason, "no-precompute-candidates")
  assert_eq(result, original)
  assert_true(physical_equal(result, original))
  let output = run_hot_pipeline(mod_, HotPipelineOptions::new(), ["precompute"]).unwrap()
  assert_eq(output.code_sec.unwrap().0[0], original)
  @validate.validate_module(output).unwrap()
  assert_eq(mod_.code_sec.unwrap().0[0], original)
}

///|
test "raw precompute owns scalar folds and leaves the source body reusable" {
  let mod_ = pass_test_module_from_wat(
    "(module (func (export \"value\") (result i32) i32.const 1 i32.const 2 i32.add))",
  )
  let original = mod_.code_sec.unwrap().0[0]
  let (result, changed, _) = precompute_run_raw_func(original, None).unwrap()
  assert_true(changed)
  let @lib.Func(_, @lib.Expr(body)) = result
  assert_eq(body, [@lib.Instruction::i32_const(@lib.I32(3))])
  let @lib.Func(_, @lib.Expr(source)) = original
  assert_eq(source, [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_add(),
  ])
  let output = run_hot_pipeline(mod_, HotPipelineOptions::new(), ["precompute"]).unwrap()
  assert_eq(output.code_sec.unwrap().0[0], result)
  @validate.validate_module(output).unwrap()
}

///|
test "plain precompute avoids unused instruction statistics while folding" {
  let mod_ = pass_test_module_from_wat(
    "(module (func (result i32) i32.const 1 i32.const 2 i32.add))",
  )
  let scans = [0]
  let result = run_hot_pipeline_raw_precompute(
    mod_,
    @lib.FuncIdx::new(0U),
    HotPipelineModuleState::new(),
    precompute_descriptor(),
    HotPipelineOptions::new(),
    instruction_scans=Some(scans),
  ).unwrap()
  assert_false(result.unchanged_original)
  let @lib.Func(_, @lib.Expr(body)) = result.func
  assert_eq(body, [@lib.Instruction::i32_const(@lib.I32(3))])
  assert_eq(scans[0], 0)
}
