///|
fn cmd_oi_descriptor_raw_parity_fixture(seed : UInt64) -> Module {
  let profile = @validate.gen_valid_profile_by_name("pass-oi-descriptor-gc").unwrap()
  @validate.gen_valid_module_result_from_seed(
    seed,
    @validate.GenValidConfig::for_profile(profile),
  ).unwrap().wasm_module
}

///|
test "command OI descriptor cleanup keeps four fixed cases at oracle raw sizes" {
  for
    (seed, expected_types, expected_bytes) in [
      (0UL, 3, 56),
      (1UL, 2, 58),
      (2UL, 3, 56),
      (3UL, 3, 81),
    ] {
    let input = cmd_oi_descriptor_raw_parity_fixture(seed)
    let output = optimize_module_with_pass_flags(
      input,
      ["optimize-instructions"],
      OptimizeOptions::new(),
    ).unwrap()
    @validate.validate_module(output).unwrap()
    @debug.assert_eq(output.type_sec.unwrap().0.length(), expected_types)
    @debug.assert_eq(
      output.type_sec.unwrap().0[0],
      input.type_sec.unwrap().0[0],
    )
    @debug.assert_eq(
      @binary.encode_module(output).unwrap().length(),
      expected_bytes,
    )
  }
}
