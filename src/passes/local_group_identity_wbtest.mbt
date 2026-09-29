///|
test "unchanged local grouping avoids repeated body equality and preserves exact bytes" {
  let mod_ = pass_test_module_from_wat(
    "(module (func (export \"value\") (param i32) (result i32) (local i32) local.get 0))",
  )
  let oi_visits = [0]
  let dfe_visits = [0]
  let oi = oi_group_numeric_locals_if_smaller(
    mod_,
    function_comparisons=Some(oi_visits),
  )
  let dfe = dfe_group_numeric_locals_if_smaller(
    mod_,
    function_comparisons=Some(dfe_visits),
  )
  assert_true(physical_equal(oi, mod_))
  assert_true(physical_equal(dfe, mod_))
  assert_eq(
    @binary.encode_module(oi).unwrap(),
    @binary.encode_module(mod_).unwrap(),
  )
  assert_eq(
    @binary.encode_module(dfe).unwrap(),
    @binary.encode_module(mod_).unwrap(),
  )
  assert_eq(oi_visits[0], 0)
  assert_eq(dfe_visits[0], 0)
}

///|
test "local grouping identity guard retains profitable remapping and active cleanup" {
  let mod_ = pass_test_module_from_wat(
    "(module (func (export \"value\") (result i32) (local i32 i64 i32 i64 i32 i64) i32.const 7 local.set 4 local.get 4))",
  )
  let expected = @binary.encode_module(mod_).unwrap().length()
  for
    output in [
      oi_group_numeric_locals_if_smaller(mod_),
      dfe_group_numeric_locals_if_smaller(mod_),
    ] {
    @validate.validate_module(output).unwrap()
    assert_true(@binary.encode_module(output).unwrap().length() < expected)
    let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    assert_eq(Array::makei(locals.length(), fn(index) { locals.get(index) }), [
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i64(),
      @lib.ValType::i64(),
      @lib.ValType::i64(),
    ])
    assert_eq(body, [
      @lib.Instruction::i32_const(@lib.I32(7)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    ])
  }
  for name in ["optimize-instructions", "duplicate-function-elimination"] {
    @validate.validate_module(
      run_hot_pipeline(mod_, HotPipelineOptions::new(), [name]).unwrap(),
    ).unwrap()
  }
}
