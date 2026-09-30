///|
fn signature_lookup_fixture(count : Int) -> @lib.Module {
  let rec_types = Array::makei(count, fn(i) {
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func(Array::make(i % 3, @lib.ValType::i32()), []),
      ),
    )
  })
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new(rec_types))
  .with_func_sec(
    @lib.FuncSec::new(
      Array::makei(count, fn(i) { @lib.TypeIdx::new(i.reinterpret_as_uint()) }),
    ),
  )
  .with_code_sec(
    @lib.CodeSec::new(
      Array::makei(count, fn(_) {
        @lib.Func::new(@lib.Locals::new([]), @lib.Expr::new([]))
      }),
    ),
  )
}

///|
test "raw signature lookup materializes one owned type table for repeated queries" {
  let module_ = signature_lookup_fixture(8)
  @validate.validate_module(module_).unwrap()
  let state = HotPipelineModuleState::new()
  let builds = [0]
  let first = run_hot_pipeline_require_raw_types(module_, state, Some(builds))
  for i in 0..<8 {
    let next = run_hot_pipeline_require_raw_types(module_, state, Some(builds))
    assert_eq(
      run_hot_pipeline_defined_func_params_indexed(
        module_,
        @lib.FuncIdx::new(i.reinterpret_as_uint()),
        Some(next),
      ),
      signature_lookup_reference_params(
        module_,
        @lib.FuncIdx::new(i.reinterpret_as_uint()),
      ),
    )
  }
  assert_eq(builds[0], 1)
  assert_true(
    physical_equal(
      first,
      run_hot_pipeline_require_raw_types(module_, state, Some(builds)),
    ),
  )
}

///|
test "raw signature lookup borrows the existing module context type table" {
  let module_ = signature_lookup_fixture(4)
  let state = HotPipelineModuleState::new()
  let context = run_hot_pipeline_require_module_ctx(
    module_,
    state,
    HotPipelineOptions::new(),
  )
  let builds = [0]
  let types = run_hot_pipeline_require_raw_types(module_, state, Some(builds))
  assert_eq(types, context.subtypes)
  assert_true(physical_equal(types, context.subtypes))
  assert_eq(builds[0], 0)
}

///|
test "raw signature lookup rebuilds after type replacement and append without changing old rows" {
  let first = pass_test_module_from_wat(
    "(module (type (func (param i32))) (func (type 0) (param i32)))",
  )
  let replacement = pass_test_module_from_wat(
    "(module (type (func (param i64))) (func (type 0) (param i64)))",
  )
  let state = HotPipelineModuleState::new()
  let builds = [0]
  let old = run_hot_pipeline_require_raw_types(first, state, Some(builds))
  let new = run_hot_pipeline_require_raw_types(replacement, state, Some(builds))
  assert_eq(
    run_hot_pipeline_defined_func_params_indexed(
      replacement,
      @lib.FuncIdx::new(0U),
      Some(new),
    ),
    Some([@lib.ValType::i64()]),
  )
  assert_eq(
    old[0].get_comptype(),
    @lib.CompType::func([@lib.ValType::i32()], []),
  )
  let @lib.TypeSec(rec_types) = replacement.type_sec.unwrap()
  let appended = rec_types.copy()
  appended.push(
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
    ),
  )
  let changed = replacement.with_type_sec(@lib.TypeSec::new(appended))
  let current = run_hot_pipeline_require_raw_types(changed, state, Some(builds))
  assert_eq(current.length(), 2)
  assert_eq(new.length(), 1)
  assert_eq(
    run_hot_pipeline_defined_func_params_indexed(
      changed,
      @lib.FuncIdx::new(0U),
      Some(current),
    ),
    Some([@lib.ValType::i64()]),
  )
  assert_eq(builds[0], 3)
  assert_false(physical_equal(old, new))
}

///|
test "indexed raw signature lookup preserves import offsets recursive groups and invalid boundaries" {
  let module_ = pass_test_module_from_wat(
    "(module (type $imp (func (param i64))) (rec (type $gc (struct (field i32))) (type $fn (func (param (ref null $gc) i32)))) (import \"m\" \"memory\" (memory 1)) (import \"m\" \"f\" (func (type $imp))) (func (type $fn) (param (ref null $gc) i32)))",
  )
  @validate.validate_module(module_).unwrap()
  let state = HotPipelineModuleState::new()
  let types = run_hot_pipeline_require_raw_types(module_, state, None)
  for index in [0U, 1U, 2U, 0xffffffffU] {
    assert_eq(
      run_hot_pipeline_defined_func_params_indexed(
        module_,
        @lib.FuncIdx::new(index),
        Some(types),
      ),
      signature_lookup_reference_params(module_, @lib.FuncIdx::new(index)),
    )
  }
  assert_eq(
    run_hot_pipeline_defined_func_params_indexed(
      module_,
      @lib.FuncIdx::new(1U),
      Some(types),
    )
    .unwrap()
    .length(),
    2,
  )
  // Missing sections and out-of-range or rec-relative declaration indices are
  // intentionally invalid lookup inputs; preserve the existing None contract.
  for
    invalid in [
      @lib.Module::new(),
      module_.with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(99U)])),
      module_.with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::rec(0U)])),
    ] {
    assert_eq(
      run_hot_pipeline_defined_func_params_indexed(
        invalid,
        @lib.FuncIdx::new(1U),
        Some(types),
      ),
      signature_lookup_reference_params(invalid, @lib.FuncIdx::new(1U)),
    )
  }
}

///|
test "raw signature lookup caches are isolated and reuse a type snapshot across body edits" {
  let module_ = signature_lookup_fixture(4)
  let first_state = HotPipelineModuleState::new()
  let second_state = HotPipelineModuleState::new()
  let first = run_hot_pipeline_require_raw_types(module_, first_state, None)
  let second = run_hot_pipeline_require_raw_types(
    signature_lookup_fixture(2),
    second_state,
    None,
  )
  assert_eq(first.length(), 4)
  assert_eq(second.length(), 2)
  let body_edit = module_.with_code_sec(@lib.CodeSec::new([]))
  assert_true(
    physical_equal(
      first,
      run_hot_pipeline_require_raw_types(body_edit, first_state, None),
    ),
  )
  let empty_state = HotPipelineModuleState::new()
  let empty = run_hot_pipeline_require_raw_types(
    @lib.Module::new(),
    empty_state,
    None,
  )
  assert_eq(empty, [])
  assert_true(
    physical_equal(
      empty,
      run_hot_pipeline_require_raw_types(@lib.Module::new(), empty_state, None),
    ),
  )
}
