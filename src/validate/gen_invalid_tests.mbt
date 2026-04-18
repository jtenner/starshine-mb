///|
test "gen_invalid_ast_seed_config widens missing-datacount prerequisites" {
  let restrictive = GenValidConfig::{
    ..GenValidConfig::natural_default(),
    max_mems: 0,
    max_datas: 0,
    section_bias: GenValidSectionBias::{
      ..GenValidSectionBias::natural_default(),
      mems_percent: 0,
      datas_percent: 0,
    },
    features: GenValidFeatureToggles::{
      ..GenValidFeatureToggles::natural_default(),
      allow_mems: false,
      allow_datas: false,
    },
  }
  let adjusted = gen_invalid_ast_seed_config(
    GenInvalidAstParams::new(MissingDataCount, generator_config=restrictive),
  )
  assert_eq(adjusted.max_mems, 1)
  assert_eq(adjusted.max_datas, 1)
  assert_eq(adjusted.section_bias.mems_percent, 100)
  assert_eq(adjusted.section_bias.datas_percent, 100)
  assert_true(adjusted.features.allow_mems)
  assert_true(adjusted.features.allow_datas)
}

///|
test "gen_invalid_ast_generate returns valid base and invalid mutation for a fixed strategy seed" {
  let params = GenInvalidAstParams::new(
    MissingDataCount,
    generator_config=GenValidConfig::natural_default(),
  )
  let generated = match
    gen_invalid_ast_generate(@splitmix.new(seed=0x5eedUL), params) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected gen-invalid base module to validate, got \{validation_error_message(err)}",
      )
  }
  assert_true(generated.mutation.applicable)
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected gen-invalid mutated module to fail validation")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
      assert_true(generated.mutation.expected_family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports minimal valid seeds" {
  let params = GenInvalidAstParams::minimal_seed(InvalidStartSignature)
  let generated = match
    gen_invalid_ast_generate(@splitmix.new(seed=0x5eedUL), params) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected minimal gen-invalid base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected minimal-seed gen-invalid mutation to fail validation")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == StartSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast natural_seed uses natural defaults" {
  let params = GenInvalidAstParams::natural_seed(DuplicateExportName)
  assert_true(params.seed_mode == RandomValidSeed)
  assert_true(params.generator_config.mode == Natural)
  assert_eq(
    params.generator_config.section_bias,
    GenValidSectionBias::natural_default(),
  )
  assert_eq(
    params.generator_config.features,
    GenValidFeatureToggles::natural_default(),
  )
}

///|
test "gen_invalid_ast coverage_forced_seed uses coverage-forced defaults" {
  let params = GenInvalidAstParams::coverage_forced_seed(DuplicateExportName)
  assert_true(params.seed_mode == RandomValidSeed)
  assert_true(params.generator_config.mode == CoverageForced)
  assert_eq(
    params.generator_config.section_bias,
    GenValidSectionBias::coverage_forced_default(),
  )
  assert_eq(
    params.generator_config.features,
    GenValidFeatureToggles::coverage_forced_default(),
  )
}
