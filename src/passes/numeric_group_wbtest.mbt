///|
test "already grouped numeric locals retain their function without an expanded mapping" {
  let func = @lib.Func::new(
    @lib.Locals::new([@lib.LocalRun::new(17U, @lib.ValType::i32())]),
    @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(17U))]),
  )
  let slots = [0]
  let (actual, remap) = run_hot_pipeline_raw_group_body_locals_by_type_func(
    func,
    [@lib.ValType::i32()],
    mapping_slots=Some(slots),
  )
  assert_true(physical_equal(actual, func))
  assert_eq(remap, None)
  assert_eq(slots[0], 0)
}

///|
test "numeric grouping retains parameter indices and stable order within each type" {
  let locals = @lib.Locals::from_types([
    @lib.ValType::i32(),
    @lib.ValType::f64(),
    @lib.ValType::i32(),
    @lib.ValType::f64(),
  ])
  let body = Array::makei(5, fn(i) {
    @lib.Instruction::local_get(@lib.LocalIdx::new(i.to_uint()))
  })
  let func = @lib.Func::new(locals, @lib.Expr::new(body))
  let params = [@lib.ValType::i32()]
  let actual = run_hot_pipeline_raw_group_body_locals_by_type_func(func, params)
  assert_eq(actual, numeric_group_reference_func(func, params))
  assert_eq(actual.1, Some([0, 1, 3, 2, 4]))
  assert_eq(body[2], @lib.Instruction::local_get(@lib.LocalIdx::new(2U)))
}

///|
test "numeric grouping normalizes adjacent groups and preserves reference-local admission" {
  let i32 = @lib.ValType::i32()
  let runs = [@lib.LocalRun::new(2U, i32), @lib.LocalRun::new(3U, i32)]
  let func = @lib.Func::new(
    @lib.Locals::from_decl_runs_preserving_groups(runs),
    @lib.Expr::new([]),
  )
  assert_eq(
    run_hot_pipeline_raw_group_body_locals_by_type_func(func, []),
    numeric_group_reference_func(func, []),
  )
  let refs = @lib.Locals::single(
    3U,
    @lib.ValType::ref_type(@lib.RefType::abs(@lib.AbsHeapType::func())),
  )
  let func = @lib.Func::new(refs, @lib.Expr::new([]))
  assert_eq(
    run_hot_pipeline_raw_group_body_locals_by_type_func(func, []),
    (func, None),
  )
}

///|
test "numeric grouping ignores empty declaration groups and crosses ULEB local boundaries" {
  let i32 = @lib.ValType::i32()
  let f64 = @lib.ValType::f64()
  let reference = @lib.ValType::ref_type(
    @lib.RefType::abs(@lib.AbsHeapType::func()),
  )
  let locals = @lib.Locals::from_decl_runs_preserving_groups([
    @lib.LocalRun::new(64U, i32),
    @lib.LocalRun::new(0U, reference),
    @lib.LocalRun::new(64U, f64),
    @lib.LocalRun::new(64U, i32),
  ])
  let body = Array::makei(193, fn(i) {
    @lib.Instruction::local_get(@lib.LocalIdx::new(i.to_uint()))
  })
  let func = @lib.Func::new(locals, @lib.Expr::new(body))
  let params = [i32]
  let actual = run_hot_pipeline_raw_group_body_locals_by_type_func(func, params)
  assert_eq(actual, numeric_group_reference_func(func, params))
  let remap = actual.1.unwrap()
  assert_eq(remap[0], 0)
  assert_eq(remap[64], 64)
  assert_eq(remap[65], 129)
  assert_eq(remap[128], 192)
  assert_eq(remap[129], 65)
  assert_eq(remap[192], 128)
}
