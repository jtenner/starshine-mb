///|
test "gen_valid_module_result reports success diagnostics" {
  let config = GenValidConfig::natural_default()
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0x5eedUL), config) {
    Ok(v) => v
    Err(failure) =>
      fail(
        "expected gen-valid success, got \{failure.validation_error_message}",
      )
  }
  assert_true(generated.attempts >= 1)
  @debug.assert_eq(generated.config_label, "natural")
  @debug.assert_eq(generated.config, config)
  @debug.assert_eq(generated.facts.mode, Natural)
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected generated module to validate, got \{validation_error_message(err)}",
      )
  }
}

///|
test "gen_valid named profiles expose stable labels and compatibility aliases" {
  @debug.assert_eq(
    gen_valid_profile_name(CoverageForcedAllFeaturesProfile),
    "coverage-forced-all-features",
  )
  @debug.assert_eq(
    GenValidConfig::for_profile(NaturalSmallProfile).mode,
    Natural,
  )
  @debug.assert_eq(
    GenValidConfig::for_profile(CoverageForcedPortableProfile),
    GenValidConfig::portable_coverage_forced_default(),
  )
  @debug.assert_eq(
    GenValidConfig::for_profile(BinaryenOraclePortableProfile),
    GenValidConfig::binaryen_oracle_coverage_forced_default(),
  )
  @debug.assert_eq(
    GenValidConfig::for_profile(PassFuzzStressProfile),
    GenValidConfig::binaryen_oracle_coverage_forced_default(),
  )
  @debug.assert_eq(
    gen_valid_config_label(GenValidConfig::for_profile(ValidatorStressProfile)),
    "validator-stress",
  )
  let looked_up = match gen_valid_profile_by_name("Coverage Forced Portable") {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(looked_up, CoverageForcedPortableProfile)
  match GenValidConfig::profile("not-a-profile") {
    Ok(_) => fail("expected unknown gen-valid profile to fail")
    Err(msg) => {
      assert_true(msg.contains("unknown gen-valid profile"))
      assert_true(msg.contains("natural-small"))
      assert_true(msg.contains("binaryen-oracle-portable"))
    }
  }
}

///|
test "gen_valid_module_with_config remains deterministic compatibility wrapper" {
  let config = GenValidConfig::binaryen_oracle_coverage_forced_default()
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0x51eedUL), config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  let wrapped = gen_valid_module_with_config(
    @splitmix.new(seed=0x51eedUL),
    config,
  )
  @debug.assert_eq(wrapped, generated.wasm_module)
  @debug.assert_eq(generated.config_label, "binaryen-oracle-coverage-forced")
}
