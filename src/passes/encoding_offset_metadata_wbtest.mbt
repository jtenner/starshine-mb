///|
fn encoding_offset_metadata_fixture() -> @lib.Module {
  pass_test_module_from_wat(
    "(module (type (func (param i64))) (type (func (result i32))) (func (type 1) (result i32) block (result i32) i32.const 7 end))",
  )
}

///|
test "OI encoding cleanup intentionally preserves unsupported offset metadata" {
  let input = encoding_offset_metadata_fixture()
  let output = oi_cleanup_module_encoding(input, touched=Some([true]))
  @validate.validate_module(output).unwrap()
  assert_true(output != input)
  let guarded = direct_metadata_guard_add_offset_metadata(input)
  assert_eq(oi_cleanup_module_encoding(guarded, touched=Some([true])), guarded)
}

///|
test "selected OI dispatch intentionally preserves unsupported offset metadata" {
  let input = encoding_offset_metadata_fixture()
  let descriptor = pass_registry_lookup_cached("optimize-instructions").unwrap().descriptor.unwrap()
  let run = fn(module_) {
    run_hot_pipeline_apply_hot_pass_to_touched(
      module_,
      descriptor,
      [true],
      HotPipelineOptions::new(),
    ).unwrap()
  }
  let output = run(input)
  @validate.validate_module(output).unwrap()
  assert_true(output != input)
  let guarded = direct_metadata_guard_add_offset_metadata(input)
  assert_eq(run(guarded), guarded)
}

///|
test "selected OI stack intentionally preserves unsupported offset metadata" {
  let input = encoding_offset_metadata_fixture()
  let descriptor = pass_registry_lookup_cached("optimize-instructions").unwrap().descriptor.unwrap()
  let run = fn(module_) {
    run_hot_pipeline_apply_hot_pass_stack_to_touched(
      module_,
      [descriptor],
      [true],
      HotPipelineOptions::new(),
    ).unwrap()
  }
  let output = run(input)
  @validate.validate_module(output).unwrap()
  assert_true(output != input)
  let guarded = direct_metadata_guard_add_offset_metadata(input)
  assert_eq(run(guarded), guarded)
}
