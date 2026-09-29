///|
test "inlining signature planning does not construct an unused HOT environment" {
  let mod_ = pass_test_module_from_wat(
    "(module (func $helper (param i32) (result i32) local.get 0 i32.const 1 i32.add) (func (export \"value\") (result i32) i32.const 7 call $helper))",
  )
  let builds = [0]
  let infos = inl_build_function_infos(mod_, module_context_builds=Some(builds))
  assert_eq(infos[0].params, [@lib.ValType::i32()])
  assert_eq(infos[0].results, [@lib.ValType::i32()])
  assert_eq(builds[0], 0)
  let output = run_hot_pipeline(mod_, HotPipelineOptions::new(), ["inlining"]).unwrap()
  @validate.validate_module(output).unwrap()
  assert_true(
    output.code_sec.unwrap().0.length() < mod_.code_sec.unwrap().0.length(),
  )
}

///|
test "inlining scratch cursor keeps first compatible slots with linear uniform reuse" {
  let types = Array::make(16, @lib.ValType::i32())
  let used = Array::make(16, false)
  let locals = @lib.Locals::empty()
  let next = [0]
  let visits = [0]
  for slot = 0; slot < 16; slot = slot + 1 {
    assert_eq(
      inl_allocate_reusable_scratch_local(
        @lib.ValType::i32(),
        types,
        used,
        locals,
        3,
        first_unused=Some(next),
        slot_visits=Some(visits),
      ),
      3 + slot,
    )
  }
  assert_eq(locals.length(), 0)
  assert_true(visits[0] <= 16)
  let mixed = [@lib.ValType::i64(), @lib.ValType::i32()]
  let used = [false, false]
  next[0] = 0
  assert_eq(
    inl_allocate_reusable_scratch_local(
      @lib.ValType::i32(),
      mixed,
      used,
      locals,
      0,
      first_unused=Some(next),
    ),
    1,
  )
  assert_eq(
    inl_allocate_reusable_scratch_local(
      @lib.ValType::i64(),
      mixed,
      used,
      locals,
      0,
      first_unused=Some(next),
    ),
    0,
  )
}
