///|
test "global-refining command type parity prunes unused generated sibling" {
  let profile = @validate.gen_valid_profile_by_name(
    "global-refining-private-writes",
  ).unwrap()
  let input = @validate.gen_valid_module_result_from_seed(
      17UL,
      @validate.GenValidConfig::for_profile(profile),
    ).unwrap().wasm_module
  let output = optimize_module_with_pass_flags(
    input,
    ["global-refining"],
    OptimizeOptions::new(),
  ).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(
    output.type_sec.unwrap().0.length(),
    input.type_sec.unwrap().0.length() - 1,
  )
}
