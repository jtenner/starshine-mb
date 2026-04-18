///|
fn invalid_binary_test_validation_family_label(
  family : ValidationIssueFamily,
) -> String {
  match family {
    TypeSectionFamily => "type"
    ImportSectionFamily => "import"
    FunctionSectionFamily => "function"
    TableSectionFamily => "table"
    MemorySectionFamily => "memory"
    TagSectionFamily => "tag"
    GlobalSectionFamily => "global"
    ElementSectionFamily => "element"
    DataSectionFamily => "data"
    DataCountSectionFamily => "datacount"
    StartSectionFamily => "start"
    ExportSectionFamily => "export"
    CodeSectionFamily => "code"
    NameSectionFamily => "name"
    FunctionBodyFamily => "function-body"
  }
}

///|
fn invalid_binary_test_expected_label(
  expected_result : ValidateInvalidBinaryExpectedResult,
) -> String {
  match expected_result {
    DecodeRejected => "decode"
    ValidateRejected(family_label) => "validate-" + family_label
  }
}

///|
fn invalid_binary_test_base_module(seed : UInt64) -> Module {
  gen_valid_module_with_config(
    @splitmix.new(seed~),
    GenValidConfig::coverage_forced_default(),
  )
}

///|
test "validate_invalid_binary_registry exposes curated stage-aware strategies" {
  let registry = validate_invalid_binary_registry()
  assert_eq(registry.map(fn(spec) { spec.stable_id }), [
    "trailing-garbage", "truncated-module", "duplicate-type-section", "wrong-section-order",
    "invalid-func-type-index",
  ])
  assert_eq(
    registry.map(fn(spec) {
      invalid_binary_test_expected_label(spec.expected_result)
    }),
    ["decode", "decode", "decode", "decode", "validate-function"],
  )
  let smoke_required = registry.filter(fn(spec) { spec.required_in_smoke })
  assert_eq(smoke_required.length(), 5)
}

///|
fn invalid_binary_expect_strategy_rejects(
  strategy_stable_id : String,
  seed : UInt64,
  expected_label : String,
) -> Result[Unit, String] {
  let registry = validate_invalid_binary_registry()
  let mut spec : ValidateInvalidBinaryStrategySpec? = None
  for entry in registry {
    if entry.stable_id == strategy_stable_id {
      spec = Some(entry)
      break
    }
  }
  let spec = match spec {
    Some(entry) => entry
    None =>
      return Err("missing binary invalid strategy '\{strategy_stable_id}'")
  }
  let base = invalid_binary_test_base_module(seed)
  match validate_module(base) {
    Ok(_) => ()
    Err(err) =>
      return Err(
        "expected base gen-valid module to validate before binary corruption: \{validation_error_message(err)}",
      )
  }
  let mutation = match apply_validate_invalid_binary_strategy(spec.id, base) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  if !mutation.applicable {
    return Err("expected binary mutation to be applicable")
  }
  match decode_module(mutation.mutated_bytes) {
    Err(_) =>
      if expected_label == "decode" {
        Ok(())
      } else {
        Err(
          "expected decode success followed by validation failure for family=\{expected_label}",
        )
      }
    Ok(decoded) =>
      match validate_module(decoded) {
        Ok(_) => Err("expected corrupted binary to fail decode or validation")
        Err(err) => {
          let family = validation_issue_family(
            validation_error_diagnostic(err).issue,
          )
          let family_label = invalid_binary_test_validation_family_label(family)
          if expected_label == "decode" {
            Err(
              "expected decode rejection but validation failed with family=\{family_label}",
            )
          } else if family_label == expected_label {
            Ok(())
          } else {
            Err(
              "expected family=\{expected_label} actual=\{family_label} message=\{validation_error_message(err)}",
            )
          }
        }
      }
  }
}

///|
test "trailing garbage binary strategy rejects at decode stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "trailing-garbage", 0x5ef2UL, "decode",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid func type index binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "invalid-func-type-index", 0x5ef3UL, "function",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "run_validate_invalid_binary_fuzz returns deterministic fixed-seed strategy stats" {
  let first = match run_validate_invalid_binary_fuzz("smoke", 0x5eedUL) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let second = match run_validate_invalid_binary_fuzz("smoke", 0x5eedUL) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  assert_true(first == second)
  assert_eq(first.attempts, 20)
  let mut saw_decode = false
  let mut saw_validate = false
  for stat in first.strategy_stats {
    assert_true(stat.attempted > 0)
    assert_true(stat.applicable > 0)
    assert_true(stat.mutated > 0)
    assert_true(stat.rejected_expected > 0)
    if stat.decode_rejected > 0 {
      saw_decode = true
    }
    if stat.validate_rejected > 0 {
      saw_validate = true
    }
    assert_eq(stat.accepted, 0)
  }
  assert_true(saw_decode)
  assert_true(saw_validate)
}

///|
test "gen_invalid_binary_generate returns valid base and validator-rejected bytes" {
  let generated = match
    gen_invalid_binary_generate(
      @splitmix.new(seed=0x5eedUL),
      GenInvalidBinaryParams::new(
        InvalidFuncTypeIndex,
        generator_config=GenValidConfig::natural_default(),
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected binary gen-invalid base module to validate, got \{validation_error_message(err)}",
      )
  }
  assert_true(generated.mutation.applicable)
  match decode_module(generated.mutation.mutated_bytes) {
    Err(msg) =>
      fail("expected validator-rejected binary to decode first: \{msg}")
    Ok(decoded) =>
      match validate_module(decoded) {
        Ok(_) => fail("expected decoded invalid binary to fail validation")
        Err(err) => {
          let family = validation_issue_family(
            validation_error_diagnostic(err).issue,
          )
          assert_eq(
            invalid_binary_test_validation_family_label(family),
            "function",
          )
        }
      }
  }
}

///|
test "gen_invalid_binary_generate supports minimal valid seeds for decode rejection" {
  let generated = match
    gen_invalid_binary_generate(
      @splitmix.new(seed=0x5eedUL),
      GenInvalidBinaryParams::minimal_seed(TrailingGarbage),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected minimal binary gen-invalid base module to validate, got \{validation_error_message(err)}",
      )
  }
  match decode_module(generated.mutation.mutated_bytes) {
    Err(_) => ()
    Ok(_) => fail("expected trailing-garbage minimal mutation to fail decode")
  }
}

///|
test "gen_invalid_binary natural_seed uses natural defaults" {
  let params = GenInvalidBinaryParams::natural_seed(TrailingGarbage)
  let expected = GenValidConfig::natural_default()
  assert_true(params.seed_mode == RandomValidSeed)
  assert_true(params.generator_config == expected)
}

///|
test "gen_invalid_binary coverage_forced_seed uses coverage-forced defaults" {
  let params = GenInvalidBinaryParams::coverage_forced_seed(TrailingGarbage)
  let expected = GenValidConfig::coverage_forced_default()
  assert_true(params.seed_mode == RandomValidSeed)
  assert_true(params.generator_config == expected)
}

///|
test "gen_invalid_binary small_natural_seed uses a smaller natural config" {
  let params = GenInvalidBinaryParams::small_natural_seed(TrailingGarbage)
  let natural = GenValidConfig::natural_default()
  assert_true(params.seed_mode == RandomValidSeed)
  assert_true(params.generator_config.mode == natural.mode)
  assert_true(params.generator_config.max_type_defs < natural.max_type_defs)
  assert_true(
    params.generator_config.max_defined_funcs < natural.max_defined_funcs,
  )
  assert_true(
    params.generator_config.max_body_statements < natural.max_body_statements,
  )
  assert_true(params.generator_config.max_body_depth < natural.max_body_depth)
}

///|
test "gen_invalid_binary small_coverage_forced_seed uses a smaller coverage config" {
  let params = GenInvalidBinaryParams::small_coverage_forced_seed(
    TrailingGarbage,
  )
  let forced = GenValidConfig::coverage_forced_default()
  assert_true(params.seed_mode == RandomValidSeed)
  assert_true(params.generator_config.mode == forced.mode)
  assert_true(params.generator_config.max_type_defs < forced.max_type_defs)
  assert_true(
    params.generator_config.max_defined_funcs < forced.max_defined_funcs,
  )
  assert_true(
    params.generator_config.max_body_statements < forced.max_body_statements,
  )
  assert_true(params.generator_config.max_body_depth < forced.max_body_depth)
}

///|
test "gen_invalid_binary_generate supports small coverage-forced seeds" {
  let generated = match
    gen_invalid_binary_generate(
      @splitmix.new(seed=0x5eedUL),
      GenInvalidBinaryParams::small_coverage_forced_seed(InvalidFuncTypeIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected small coverage-forced binary base module to validate, got \{validation_error_message(err)}",
      )
  }
  match decode_module(generated.mutation.mutated_bytes) {
    Err(msg) =>
      fail("expected small binary invalid bytes to decode first: \{msg}")
    Ok(decoded) =>
      match validate_module(decoded) {
        Ok(_) => fail("expected small binary invalid bytes to fail validation")
        Err(err) => {
          let family = validation_issue_family(
            validation_error_diagnostic(err).issue,
          )
          assert_eq(
            invalid_binary_test_validation_family_label(family),
            "function",
          )
        }
      }
  }
}
