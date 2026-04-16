///|
test "validate_invalid_text_registry exposes curated stage-aware strategies" {
  let registry = validate_invalid_text_registry()
  assert_eq(registry.map(fn(spec) { spec.stable_id }), [
    "malformed-quote-missing-paren", "invalid-result-stack", "unlinkable-unknown-import",
  ])
  assert_eq(
    registry.map(fn(spec) {
      validate_invalid_text_stage_name(spec.expected_stage)
    }),
    ["parse-or-lower-rejected", "validate-rejected", "valid-before-link"],
  )
  let smoke_required = registry.filter(fn(spec) { spec.required_in_smoke })
  assert_eq(smoke_required.length(), 3)
}

///|
test "validate_invalid_spec_seed_registry exposes curated malformed invalid and unlinkable seeds" {
  let registry = validate_invalid_spec_seed_registry()
  assert_eq(registry.map(fn(spec) { spec.stable_id }), [
    "const-malformed-quote-1", "f32-invalid-type-mismatch-1", "imports-unlinkable-unknown-import-1",
  ])
  assert_eq(
    registry.map(fn(spec) {
      validate_invalid_text_stage_name(spec.expected_stage)
    }),
    ["parse-or-lower-rejected", "validate-rejected", "valid-before-link"],
  )
  let smoke_required = registry.filter(fn(spec) { spec.required_in_smoke })
  assert_eq(smoke_required.length(), 3)
}

///|
test "inline malformed text strategy rejects during parse or lower" {
  match
    run_validate_invalid_text_case_by_stable_id("malformed-quote-missing-paren") {
    Ok(stage) => assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline invalid text strategy rejects during validation" {
  match run_validate_invalid_text_case_by_stable_id("invalid-result-stack") {
    Ok(stage) => assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline unlinkable text strategy stays valid before link" {
  match
    run_validate_invalid_text_case_by_stable_id("unlinkable-unknown-import") {
    Ok(stage) => assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "spec-seed malformed case rejects during parse or lower" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id("const-malformed-quote-1") {
    Ok(stage) => assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "spec-seed invalid case rejects during validation" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "f32-invalid-type-mismatch-1",
    ) {
    Ok(stage) => assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "spec-seed unlinkable case stays valid before link" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "imports-unlinkable-unknown-import-1",
    ) {
    Ok(stage) => assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "run_validate_invalid_text_fuzz returns deterministic fixed-seed strategy stats" {
  let first = match run_validate_invalid_text_fuzz("smoke", 0x5eedUL) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let second = match run_validate_invalid_text_fuzz("smoke", 0x5eedUL) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  assert_true(first == second)
  assert_eq(first.attempts, 12)
  let mut saw_parse_or_lower = false
  let mut saw_validate = false
  let mut saw_valid_before_link = false
  for stat in first.strategy_stats {
    assert_true(stat.attempted > 0)
    assert_true(stat.applicable > 0)
    assert_true(stat.matched_expected > 0)
    if stat.parse_or_lower_rejected > 0 {
      saw_parse_or_lower = true
    }
    if stat.validate_rejected > 0 {
      saw_validate = true
    }
    if stat.valid_before_link > 0 {
      saw_valid_before_link = true
    }
  }
  assert_true(saw_parse_or_lower)
  assert_true(saw_validate)
  assert_true(saw_valid_before_link)
}

///|
test "run_validate_invalid_spec_seed_fuzz returns deterministic fixed-seed seed stats" {
  let first = match run_validate_invalid_spec_seed_fuzz("smoke", 0x5eedUL) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let second = match run_validate_invalid_spec_seed_fuzz("smoke", 0x5eedUL) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  assert_true(first == second)
  assert_eq(first.attempts, 12)
  let mut saw_parse_or_lower = false
  let mut saw_validate = false
  let mut saw_valid_before_link = false
  for stat in first.seed_stats {
    assert_true(stat.attempted > 0)
    assert_true(stat.applicable > 0)
    assert_true(stat.matched_expected > 0)
    if stat.parse_or_lower_rejected > 0 {
      saw_parse_or_lower = true
    }
    if stat.validate_rejected > 0 {
      saw_validate = true
    }
    if stat.valid_before_link > 0 {
      saw_valid_before_link = true
    }
  }
  assert_true(saw_parse_or_lower)
  assert_true(saw_validate)
  assert_true(saw_valid_before_link)
}
