///|
test "dispatcher optimize-instructions reaches the three profile fixed points" {
  for name in ["flatten-ifs", "flatten-loops", "ssa-merge-explicit"] {
    let profile = @validate.gen_valid_profile_by_name(name).unwrap()
    let input = @validate.gen_valid_module_result_from_seed(
        0x5eedUL,
        @validate.GenValidConfig::for_profile(profile),
      ).unwrap().wasm_module
    let once = optimize_module_with_pass_flags(
      input,
      ["optimize-instructions"],
      OptimizeOptions::new(),
    ).unwrap()
    let twice = optimize_module_with_pass_flags(
      once,
      ["optimize-instructions"],
      OptimizeOptions::new(),
    ).unwrap()
    assert_true(@validate.validate_module(once).is_ok())
    @debug.assert_eq(@binary.encode_module(once), @binary.encode_module(twice))
  }
}
