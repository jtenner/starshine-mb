///|
test "inlining planning omits unused HOT classifications while retaining active helper removal" {
  let input = pass_test_module_from_wat(
    "(module (func $helper (param i32) (result i32) local.get 0 i32.const 1 i32.add) (func (export \"value\") (param i32) (result i32) local.get 0 i32.const 3 i32.add call $helper i32.const 7 i32.mul))",
  )
  let original = @binary.encode_module(input).unwrap()
  let full_builds = [0]
  let full = inl_build_function_infos(
    input,
    module_context_builds=Some(full_builds),
  )
  assert_eq(full_builds[0], 1)
  let planned_builds = [0]
  let planned = inl_build_function_infos(
    input,
    classify_uncalled=false,
    module_context_builds=Some(planned_builds),
  )
  assert_eq(planned[0].inlineable, full[0].inlineable)
  assert_eq(planned[0].params, full[0].params)
  assert_eq(planned[1].direct_targets, [0])
  assert_eq(planned_builds[0], 0)
  let full_rewrite = inl_rewrite_all_calls(input, full)
  let planned_rewrite = inl_rewrite_all_calls(input, planned)
  assert_eq(
    @binary.encode_module(planned_rewrite.mod_out).unwrap(),
    @binary.encode_module(full_rewrite.mod_out).unwrap(),
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["inlining"]).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(output.code_sec.unwrap().0.length(), 1)
  assert_eq(@binary.encode_module(input).unwrap(), original)
}

///|
test "full inlining classification keeps uncalled eligibility for partial splitting" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32 i32) (result i32) local.get 0 local.get 1 i32.add))",
  )
  let full = inl_build_function_infos(input)
  let planning = inl_build_function_infos(input, classify_uncalled=false)
  assert_true(full[0].inlineable)
  assert_false(planning[0].inlineable)
  assert_eq(planning[0].params, full[0].params)
  assert_eq(planning[0].results, full[0].results)
  assert_eq(planning[0].direct_targets, [])
  @validate.validate_module(input).unwrap()
}
