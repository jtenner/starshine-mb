///|
test "audit DAE materialized floats distinguish signed zero" {
  for
    pair in [
      (
        @lib.Instruction::f32_const(@lib.F32::new(0.0)),
        @lib.Instruction::f32_const(@lib.F32::new(-0.0)),
      ),
      (
        @lib.Instruction::f64_const(@lib.F64::new(0.0)),
        @lib.Instruction::f64_const(@lib.F64::new(-0.0)),
      ),
    ] {
    let (positive, negative) = pair
    assert_false(dae_materialized_const_equal(positive, negative))
  }
}

///|
test "audit similar function parameter vectors distinguish signed zero" {
  assert_false(
    msf_instruction_vectors_equal(
      [@lib.Instruction::f32_const(@lib.F32::new(0.0))],
      [@lib.Instruction::f32_const(@lib.F32::new(-0.0))],
    ),
  )
}

///|
test "audit code folding compares floating constant bits" {
  let func = pass_test_lift_first_func(
    "(module (func (result f32 f32) f32.const 0 f32.const -0))",
  )
  let root = @ir.HotRegionRef::root()
  let left = @ir.hot_region_get(func, root, 0)
  let right = @ir.hot_region_get(func, root, 1)
  assert_false(code_folding_nodes_equal_exact_labels(func, left, right))
}

///|
test "audit similar function specialization preserves signed zero sites" {
  let funcs = [0.0, -0.0].map(fn(value) {
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::f64_const(@lib.F64::new(value))]),
    )
  })
  let (params, _) = msf_derive_params(funcs, { members: [0, 1], }, []).unwrap()
  @debug.assert_eq(params.length(), 1)
}
