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
    gen_invalid_binary_coverage_seed_generator_config(),
  )
}

///|
test "validate_invalid_binary_registry exposes curated stage-aware strategies" {
  let registry = validate_invalid_binary_registry()
  @debug.assert_eq(registry.map(fn(spec) { spec.stable_id }), [
    "trailing-garbage", "truncated-module", "duplicate-type-section", "wrong-section-order",
    "invalid-func-type-index", "invalid-start-signature-module", "invalid-imported-start-func-param-module",
    "invalid-imported-start-func-result-module", "invalid-imported-start-func-param-result-module",
    "invalid-imported-start-func-multi-param-module", "invalid-imported-start-func-f32-param-module",
    "invalid-imported-start-func-externref-param-module", "invalid-imported-start-func-funcref-param-module",
    "duplicate-export-name-module", "funcsec-without-codesec-module", "datacount-without-data-sec-module",
    "invalid-name-section-func-index-module", "invalid-local-name-section-index-module",
    "invalid-label-name-section-index-module", "bad-magic-header", "bad-version-header",
    "malformed-section-size-uleb", "section-payload-length-overflow", "codesec-without-funcsec-module",
    "invalid-table-name-section-index-module", "invalid-global-name-section-index-module",
    "reserved-section-id", "invalid-custom-section-name-utf8", "invalid-type-name-section-index-module",
    "invalid-field-name-section-index-module", "invalid-elem-name-section-index-module",
    "invalid-data-name-section-index-module", "invalid-export-table-index-module",
    "invalid-export-global-index-module", "invalid-export-memory-index-module", "invalid-export-tag-index-module",
    "invalid-tag-name-section-index-module", "invalid-imported-tag-type-index-module",
    "datacount-mismatch-too-small-module", "datacount-mismatch-too-large-module",
    "duplicate-import-section", "duplicate-export-section", "duplicate-table-section",
    "duplicate-memory-section", "duplicate-global-section", "duplicate-function-section",
    "duplicate-code-section", "duplicate-element-section", "duplicate-data-section",
    "duplicate-tag-section", "malformed-simd-immediate", "simd-lane-index-overflow",
    "malformed-custom-section-payload", "malformed-custom-section-name-length-uleb",
    "malformed-name-subsection-size-uleb", "invalid-opcode-byte", "invalid-prefix-subopcode-byte",
    "malformed-memarg-immediate", "malformed-load-memarg-align-uleb", "malformed-store-memarg-align-uleb",
    "malformed-load-memarg-offset-uleb", "malformed-store-memarg-offset-uleb", "malformed-blocktype-immediate",
    "malformed-memory-min-uleb", "malformed-table-min-uleb", "malformed-memory-max-uleb",
    "malformed-table-max-uleb", "invalid-export-name-utf8", "invalid-import-module-name-utf8",
    "invalid-import-field-name-utf8", "invalid-import-kind-byte", "malformed-import-func-type-index-uleb",
    "malformed-import-tag-type-index-uleb", "malformed-import-memory-min-uleb", "malformed-import-table-min-uleb",
    "malformed-import-memory-max-uleb", "malformed-import-table-max-uleb", "invalid-import-table-reftype-byte",
    "invalid-import-memory-limits-flag-byte", "invalid-import-global-valtype-byte",
    "invalid-import-global-mutability-byte", "invalid-table-reftype-byte", "invalid-table-limits-flag-byte",
    "malformed-ref-null-heaptype-immediate", "malformed-ref-cast-heaptype-immediate",
    "malformed-ref-test-heaptype-immediate", "invalid-global-valtype-byte", "invalid-export-kind-byte",
    "invalid-memory-limits-flag-byte", "invalid-tag-attribute-byte", "invalid-global-mutability-byte",
    "malformed-export-func-index-uleb", "malformed-export-table-index-uleb", "malformed-export-memory-index-uleb",
    "malformed-export-global-index-uleb", "malformed-export-tag-index-uleb", "invalid-element-segment-flag-byte",
    "invalid-element-kind-byte", "invalid-data-segment-flag-byte", "type-section-count-overflow",
    "code-section-count-overflow", "table-section-count-overflow", "export-section-count-overflow",
    "import-section-count-overflow", "global-section-count-overflow", "function-section-count-overflow",
    "memory-section-count-overflow", "element-section-count-overflow", "data-section-count-overflow",
    "tag-section-count-overflow", "malformed-tag-type-index-uleb", "malformed-local-index-uleb",
    "malformed-local-set-index-uleb", "malformed-local-tee-index-uleb", "malformed-global-index-uleb",
    "malformed-global-set-index-uleb", "malformed-i32-const-sleb", "malformed-i64-const-sleb",
    "malformed-f32-const-immediate", "malformed-f64-const-immediate", "malformed-call-func-index-uleb",
    "malformed-return-call-func-index-uleb", "malformed-ref-func-index-uleb", "malformed-call-indirect-type-index-uleb",
    "malformed-call-indirect-table-index-uleb", "malformed-br-label-index-uleb",
    "malformed-br-if-label-index-uleb", "malformed-br-table-target-count-uleb", "malformed-br-table-target-label-index-uleb",
    "malformed-br-table-default-label-index-uleb", "malformed-table-index-uleb",
    "malformed-table-set-index-uleb", "malformed-memory-size-memory-index-uleb",
    "malformed-memory-grow-memory-index-uleb", "malformed-memory-copy-dst-index-uleb",
    "malformed-memory-copy-src-index-uleb", "malformed-table-copy-dst-index-uleb",
    "malformed-table-copy-src-index-uleb", "malformed-select-type-count-uleb", "invalid-typed-select-valtype-byte",
    "malformed-start-func-index-uleb", "malformed-datacount-uleb", "simd-shuffle-lane-overflow",
    "simd-load-lane-index-overflow", "simd-store-lane-index-overflow", "simd-extract-lane-index-overflow",
    "simd-replace-lane-index-overflow", "malformed-data-index-uleb", "malformed-memory-init-memory-index-uleb",
    "malformed-elem-index-uleb", "malformed-table-init-table-index-uleb", "malformed-data-segment-memory-index-uleb",
    "malformed-element-segment-table-index-uleb", "invalid-name-section-func-name-utf8",
    "invalid-name-section-local-name-utf8", "invalid-name-section-module-name-utf8",
    "invalid-name-section-type-name-utf8", "invalid-name-section-table-name-utf8",
    "invalid-name-section-memory-name-utf8", "invalid-name-section-global-name-utf8",
    "invalid-name-section-elem-name-utf8", "invalid-name-section-data-name-utf8",
    "invalid-name-section-field-name-utf8", "invalid-name-section-label-name-utf8",
    "invalid-name-section-tag-name-utf8", "invalid-functype-byte", "invalid-code-local-valtype-byte",
    "type-section-count-underflow", "code-section-count-underflow", "import-section-count-underflow",
    "export-section-count-underflow", "table-section-count-underflow", "memory-section-count-underflow",
    "global-section-count-underflow", "function-section-count-underflow", "element-section-count-underflow",
    "data-section-count-underflow", "tag-section-count-underflow", "type-section-size-underflow",
    "code-body-size-underflow", "import-section-size-underflow", "export-section-size-underflow",
    "table-section-size-underflow", "memory-section-size-underflow", "global-section-size-underflow",
    "function-section-size-underflow", "element-section-size-underflow", "data-section-size-underflow",
    "tag-section-size-underflow", "type-section-size-overflow", "import-section-size-overflow",
    "export-section-size-overflow", "table-section-size-overflow", "memory-section-size-overflow",
    "global-section-size-overflow", "function-section-size-overflow", "element-section-size-overflow",
    "data-section-size-overflow", "tag-section-size-overflow", "start-section-size-underflow",
    "datacount-section-size-underflow", "start-section-size-overflow", "datacount-section-size-overflow",
  ])
  @debug.assert_eq(
    registry.map(fn(spec) {
      invalid_binary_test_expected_label(spec.expected_result)
    }),
    [
      "decode", "decode", "decode", "decode", "validate-function", "validate-start",
      "validate-start", "validate-start", "validate-start", "validate-start", "validate-start",
      "validate-start", "validate-start", "validate-export", "validate-code", "validate-datacount",
      "validate-name", "validate-name", "validate-name", "decode", "decode", "decode",
      "decode", "validate-code", "validate-name", "validate-name", "decode", "decode",
      "validate-name", "validate-name", "validate-name", "validate-name", "validate-export",
      "validate-export", "validate-export", "validate-export", "validate-name", "validate-import",
      "validate-datacount", "validate-datacount", "decode", "decode", "decode", "decode",
      "decode", "decode", "decode", "decode", "decode", "decode", "decode", "decode",
      "decode", "decode", "decode", "decode", "decode", "decode", "decode", "decode",
      "decode", "decode", "decode", "decode", "decode", "decode", "decode", "decode",
      "decode", "decode", "decode", "decode", "decode", "decode", "decode", "decode",
      "decode", "decode", "decode", "decode", "decode", "decode", "decode", "decode",
      "decode", "decode", "decode", "decode", "decode", "decode", "decode", "decode",
      "decode", "decode", "decode", "decode", "decode", "decode", "decode", "decode",
      "decode", "decode", "decode", "decode", "decode", "decode", "decode", "decode",
      "decode", "decode", "decode", "decode", "decode", "decode", "decode", "decode",
      "decode", "decode", "decode", "decode", "decode", "decode", "decode", "decode",
      "decode", "decode", "decode", "decode", "decode", "decode", "decode", "decode",
      "decode", "decode", "decode", "decode", "decode", "decode", "decode", "decode",
      "decode", "decode", "decode", "decode", "decode", "decode", "decode", "decode",
      "decode", "decode", "decode", "decode", "decode", "decode", "decode", "decode",
      "decode", "decode", "decode", "decode", "decode", "decode", "decode", "decode",
      "decode", "decode", "decode", "decode", "decode", "decode", "decode", "decode",
      "decode", "decode", "decode", "decode", "decode", "decode", "decode", "decode",
      "decode", "decode", "decode", "decode", "decode", "decode", "decode", "decode",
      "decode", "decode", "decode", "decode", "decode", "decode", "decode", "decode",
      "decode", "decode", "decode", "decode", "decode", "decode", "decode",
    ],
  )
  let smoke_required = registry.filter(fn(spec) { spec.required_in_smoke })
  @debug.assert_eq(smoke_required.length(), 40)
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
test "invalid start signature binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "invalid-start-signature-module", 0x5ef4UL, "start",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "duplicate export binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "duplicate-export-name-module", 0x5ef5UL, "export",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "funcsec without codesec binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "funcsec-without-codesec-module", 0x5ef6UL, "code",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "datacount without data section binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "datacount-without-data-sec-module", 0x5ef7UL, "datacount",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid name-section func index binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "invalid-name-section-func-index-module", 0x5ef8UL, "name",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid local name-section index binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "invalid-local-name-section-index-module", 0x5ef81UL, "name",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid label name-section index binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "invalid-label-name-section-index-module", 0x5ef82UL, "name",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid field name-section index binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "invalid-field-name-section-index-module", 0x5ef83UL, "name",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "bad magic header binary strategy rejects at decode stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "bad-magic-header", 0x5ef9UL, "decode",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "bad version header binary strategy rejects at decode stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "bad-version-header", 0x5efaUL, "decode",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "malformed section size uleb binary strategy rejects at decode stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "malformed-section-size-uleb", 0x5efa1UL, "decode",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "section payload length overflow binary strategy rejects at decode stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "section-payload-length-overflow", 0x5efa2UL, "decode",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "codesec without funcsec binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "codesec-without-funcsec-module", 0x5efbUL, "code",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid table name-section index binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "invalid-table-name-section-index-module", 0x5efcUL, "name",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid global name-section index binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "invalid-global-name-section-index-module", 0x5efdUL, "name",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "reserved section id binary strategy rejects at decode stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "reserved-section-id", 0x5efeUL, "decode",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid custom section name utf8 strategy rejects at decode stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "invalid-custom-section-name-utf8", 0x5effUL, "decode",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid type name-section index binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "invalid-type-name-section-index-module", 0x5f00UL, "name",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid elem name-section index binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "invalid-elem-name-section-index-module", 0x5f01UL, "name",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid data name-section index binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "invalid-data-name-section-index-module", 0x5f02UL, "name",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid export table index binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "invalid-export-table-index-module", 0x5f03UL, "export",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid export global index binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "invalid-export-global-index-module", 0x5f04UL, "export",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid imported start func param binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "invalid-imported-start-func-param-module", 0x5f041UL, "start",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid imported start func result binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "invalid-imported-start-func-result-module", 0x5f042UL, "start",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid imported start func param-result binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "invalid-imported-start-func-param-result-module", 0x5f043UL, "start",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid imported start func multi-param binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "invalid-imported-start-func-multi-param-module", 0x5f044UL, "start",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid imported start func f32-param binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "invalid-imported-start-func-f32-param-module", 0x5f045UL, "start",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid imported start func externref-param binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "invalid-imported-start-func-externref-param-module", 0x5f046UL, "start",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid imported start func funcref-param binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "invalid-imported-start-func-funcref-param-module", 0x5f0461UL, "start",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid export memory index binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "invalid-export-memory-index-module", 0x5f051UL, "export",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid export tag index binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "invalid-export-tag-index-module", 0x5f05UL, "export",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid tag name-section index binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "invalid-tag-name-section-index-module", 0x5f06UL, "name",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid imported tag type index binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "invalid-imported-tag-type-index-module", 0x5f061UL, "import",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "datacount mismatch too-small binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "datacount-mismatch-too-small-module", 0x5f07UL, "datacount",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "datacount mismatch too-large binary strategy rejects at validate stage" {
  match
    invalid_binary_expect_strategy_rejects(
      "datacount-mismatch-too-large-module", 0x5f08UL, "datacount",
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
  @debug.assert_eq(first.attempts, 40)
  let mut saw_decode = false
  let mut saw_validate = false
  for stat in first.strategy_stats {
    if stat.attempted > 0 {
      if stat.applicable > 0 {
        assert_true(stat.mutated > 0)
        assert_true(stat.rejected_expected > 0)
      }
      if stat.decode_rejected > 0 {
        saw_decode = true
      }
      if stat.validate_rejected > 0 {
        saw_validate = true
      }
      @debug.assert_eq(stat.accepted, 0)
    }
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
          @debug.assert_eq(
            invalid_binary_test_validation_family_label(family),
            "function",
          )
        }
      }
  }
}

///|
test "gen_invalid_binary_generate supports start-section invalid modules" {
  let generated = match
    gen_invalid_binary_generate(
      @splitmix.new(seed=0x5eedUL),
      GenInvalidBinaryParams::repro_seed(InvalidStartSignatureModule),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match decode_module(generated.mutation.mutated_bytes) {
    Err(msg) => fail("expected start invalid bytes to decode first: \{msg}")
    Ok(decoded) =>
      match validate_module(decoded) {
        Ok(_) =>
          fail("expected decoded start-invalid binary to fail validation")
        Err(err) => {
          let family = validation_issue_family(
            validation_error_diagnostic(err).issue,
          )
          @debug.assert_eq(
            invalid_binary_test_validation_family_label(family),
            "start",
          )
        }
      }
  }
}

///|
test "gen_invalid_binary_generate supports invalid table-name modules" {
  let generated = match
    gen_invalid_binary_generate(
      @splitmix.new(seed=0x5eedUL),
      GenInvalidBinaryParams::repro_seed(InvalidTableNameSectionIndexModule),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match decode_module(generated.mutation.mutated_bytes) {
    Err(msg) =>
      fail("expected table-name invalid bytes to decode first: \{msg}")
    Ok(decoded) =>
      match validate_module(decoded) {
        Ok(_) =>
          fail("expected decoded table-name-invalid binary to fail validation")
        Err(err) => {
          let family = validation_issue_family(
            validation_error_diagnostic(err).issue,
          )
          @debug.assert_eq(
            invalid_binary_test_validation_family_label(family),
            "name",
          )
        }
      }
  }
}

///|
test "gen_invalid_binary_generate supports invalid elem-name modules" {
  let generated = match
    gen_invalid_binary_generate(
      @splitmix.new(seed=0x5eedUL),
      GenInvalidBinaryParams::repro_seed(InvalidElemNameSectionIndexModule),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match decode_module(generated.mutation.mutated_bytes) {
    Err(msg) => fail("expected elem-name invalid bytes to decode first: \{msg}")
    Ok(decoded) =>
      match validate_module(decoded) {
        Ok(_) =>
          fail("expected decoded elem-name-invalid binary to fail validation")
        Err(err) => {
          let family = validation_issue_family(
            validation_error_diagnostic(err).issue,
          )
          @debug.assert_eq(
            invalid_binary_test_validation_family_label(family),
            "name",
          )
        }
      }
  }
}

///|
test "gen_invalid_binary_generate supports invalid local-name modules" {
  let generated = match
    gen_invalid_binary_generate(
      @splitmix.new(seed=0x5eedUL),
      GenInvalidBinaryParams::repro_seed(InvalidLocalNameSectionIndexModule),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match decode_module(generated.mutation.mutated_bytes) {
    Err(msg) =>
      fail("expected local-name invalid bytes to decode first: \{msg}")
    Ok(decoded) =>
      match validate_module(decoded) {
        Ok(_) =>
          fail("expected decoded local-name-invalid binary to fail validation")
        Err(err) => {
          let family = validation_issue_family(
            validation_error_diagnostic(err).issue,
          )
          @debug.assert_eq(
            invalid_binary_test_validation_family_label(family),
            "name",
          )
        }
      }
  }
}

///|
test "gen_invalid_binary_generate supports invalid field-name modules" {
  let generated = match
    gen_invalid_binary_generate(
      @splitmix.new(seed=0x5eedUL),
      GenInvalidBinaryParams::repro_seed(InvalidFieldNameSectionIndexModule),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match decode_module(generated.mutation.mutated_bytes) {
    Err(msg) =>
      fail("expected field-name invalid bytes to decode first: \{msg}")
    Ok(decoded) =>
      match validate_module(decoded) {
        Ok(_) =>
          fail("expected decoded field-name-invalid binary to fail validation")
        Err(err) => {
          let family = validation_issue_family(
            validation_error_diagnostic(err).issue,
          )
          @debug.assert_eq(
            invalid_binary_test_validation_family_label(family),
            "name",
          )
        }
      }
  }
}

///|
test "gen_invalid_binary_generate supports invalid imported-start-result modules" {
  let generated = match
    gen_invalid_binary_generate(
      @splitmix.new(seed=0x5eedUL),
      GenInvalidBinaryParams::repro_seed(InvalidImportedStartFuncResultModule),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match decode_module(generated.mutation.mutated_bytes) {
    Err(msg) =>
      fail("expected imported-start invalid bytes to decode first: \{msg}")
    Ok(decoded) =>
      match validate_module(decoded) {
        Ok(_) =>
          fail(
            "expected decoded imported-start-invalid binary to fail validation",
          )
        Err(err) => {
          let family = validation_issue_family(
            validation_error_diagnostic(err).issue,
          )
          @debug.assert_eq(
            invalid_binary_test_validation_family_label(family),
            "start",
          )
        }
      }
  }
}

///|
test "gen_invalid_binary_generate supports invalid imported-start-externref modules" {
  let generated = match
    gen_invalid_binary_generate(
      @splitmix.new(seed=0x5ff224UL),
      GenInvalidBinaryParams::repro_seed(
        InvalidImportedStartFuncExternrefParamModule,
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected invalid-imported-start-func-externref-param-module base module to validate, got \{validation_error_message(err)}",
      )
  }
  match decode_module(generated.mutation.mutated_bytes) {
    Err(err) =>
      fail(
        "expected decode success for invalid-imported-start-func-externref-param-module mutation, got \{err}",
      )
    Ok(decoded) =>
      match validate_module(decoded) {
        Ok(_) =>
          fail(
            "expected invalid-imported-start-func-externref-param-module mutation to fail validation",
          )
        Err(err) => {
          let family = validation_issue_family(
            validation_error_diagnostic(err).issue,
          )
          @debug.assert_eq(
            invalid_binary_test_validation_family_label(family),
            "start",
          )
        }
      }
  }
}

///|
test "gen_invalid_binary_generate supports invalid export-memory modules" {
  let generated = match
    gen_invalid_binary_generate(
      @splitmix.new(seed=0x5eedUL),
      GenInvalidBinaryParams::repro_seed(InvalidExportMemoryIndexModule),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match decode_module(generated.mutation.mutated_bytes) {
    Err(msg) =>
      fail("expected export-memory invalid bytes to decode first: \{msg}")
    Ok(decoded) =>
      match validate_module(decoded) {
        Ok(_) =>
          fail(
            "expected decoded export-memory-invalid binary to fail validation",
          )
        Err(err) => {
          let family = validation_issue_family(
            validation_error_diagnostic(err).issue,
          )
          @debug.assert_eq(
            invalid_binary_test_validation_family_label(family),
            "export",
          )
        }
      }
  }
}

///|
test "gen_invalid_binary_generate supports invalid export-tag modules" {
  let generated = match
    gen_invalid_binary_generate(
      @splitmix.new(seed=0x5eedUL),
      GenInvalidBinaryParams::repro_seed(InvalidExportTagIndexModule),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match decode_module(generated.mutation.mutated_bytes) {
    Err(msg) =>
      fail("expected export-tag invalid bytes to decode first: \{msg}")
    Ok(decoded) =>
      match validate_module(decoded) {
        Ok(_) =>
          fail("expected decoded export-tag-invalid binary to fail validation")
        Err(err) => {
          let family = validation_issue_family(
            validation_error_diagnostic(err).issue,
          )
          @debug.assert_eq(
            invalid_binary_test_validation_family_label(family),
            "export",
          )
        }
      }
  }
}

///|
test "gen_invalid_binary_generate supports invalid imported-tag-type modules" {
  let generated = match
    gen_invalid_binary_generate(
      @splitmix.new(seed=0x5eedUL),
      GenInvalidBinaryParams::repro_seed(InvalidImportedTagTypeIndexModule),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match decode_module(generated.mutation.mutated_bytes) {
    Err(msg) =>
      fail("expected imported-tag invalid bytes to decode first: \{msg}")
    Ok(decoded) =>
      match validate_module(decoded) {
        Ok(_) =>
          fail(
            "expected decoded imported-tag-invalid binary to fail validation",
          )
        Err(err) => {
          let family = validation_issue_family(
            validation_error_diagnostic(err).issue,
          )
          @debug.assert_eq(
            invalid_binary_test_validation_family_label(family),
            "import",
          )
        }
      }
  }
}

///|
test "invalid binary FZG025 decodes malformed export descriptor index ULEBs as invalid" {
  for
    strategy in [
      "malformed-export-func-index-uleb", "malformed-export-table-index-uleb", "malformed-export-memory-index-uleb",
      "malformed-export-global-index-uleb", "malformed-export-tag-index-uleb",
    ] {
    match invalid_binary_expect_strategy_rejects(strategy, 0x5f10UL, "decode") {
      Ok(_) => ()
      Err(msg) => fail("\{strategy}: \{msg}")
    }
  }
}

///|
test "invalid binary FZG026 decodes malformed import descriptor index ULEBs as invalid" {
  for
    strategy in [
      "malformed-import-func-type-index-uleb", "malformed-import-tag-type-index-uleb",
    ] {
    match invalid_binary_expect_strategy_rejects(strategy, 0x5f11UL, "decode") {
      Ok(_) => ()
      Err(msg) => fail("\{strategy}: \{msg}")
    }
  }
}

///|
test "invalid binary FZG027 decodes malformed bulk init secondary indices as invalid" {
  for
    strategy in [
      "malformed-memory-init-memory-index-uleb", "malformed-table-init-table-index-uleb",
    ] {
    match invalid_binary_expect_strategy_rejects(strategy, 0x5f12UL, "decode") {
      Ok(_) => ()
      Err(msg) => fail("\{strategy}: \{msg}")
    }
  }
}

///|
test "invalid binary FZG029 decodes malformed limit minimum ULEBs as invalid" {
  for strategy in ["malformed-memory-min-uleb", "malformed-table-min-uleb"] {
    match invalid_binary_expect_strategy_rejects(strategy, 0x5f14UL, "decode") {
      Ok(_) => ()
      Err(msg) => fail("\{strategy}: \{msg}")
    }
  }
}

///|
test "invalid binary FZG030 decodes malformed ref cast heaptype immediate as invalid" {
  match
    invalid_binary_expect_strategy_rejects(
      "malformed-ref-cast-heaptype-immediate", 0x5f15UL, "decode",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid binary FZG031 decodes malformed ref test heaptype immediate as invalid" {
  match
    invalid_binary_expect_strategy_rejects(
      "malformed-ref-test-heaptype-immediate", 0x5f16UL, "decode",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid binary FZG032 decodes malformed br_table target-label ULEB as invalid" {
  match
    invalid_binary_expect_strategy_rejects(
      "malformed-br-table-target-label-index-uleb", 0x5f17UL, "decode",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid binary FZG034 decodes malformed table and memory index ULEBs as invalid" {
  for
    strategy in [
      "malformed-table-set-index-uleb", "malformed-memory-size-memory-index-uleb",
      "malformed-memory-grow-memory-index-uleb",
    ] {
    match invalid_binary_expect_strategy_rejects(strategy, 0x5f19UL, "decode") {
      Ok(_) => ()
      Err(msg) => fail("\{strategy}: \{msg}")
    }
  }
}

///|
test "invalid binary FZG035 decodes invalid typed select valtype byte as invalid" {
  match
    invalid_binary_expect_strategy_rejects(
      "invalid-typed-select-valtype-byte", 0x5f20UL, "decode",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid binary FZG036 decodes invalid import descriptor bytes as invalid" {
  for
    strategy in [
      "malformed-import-memory-min-uleb", "malformed-import-table-min-uleb", "malformed-import-memory-max-uleb",
      "malformed-import-table-max-uleb", "invalid-import-table-reftype-byte", "invalid-import-memory-limits-flag-byte",
      "invalid-import-global-valtype-byte", "invalid-import-global-mutability-byte",
    ] {
    match invalid_binary_expect_strategy_rejects(strategy, 0x5f21UL, "decode") {
      Ok(_) => ()
      Err(msg) => fail("\{strategy}: \{msg}")
    }
  }
}

///|
test "invalid binary FZG033 decodes malformed active segment index ULEBs as invalid" {
  for
    strategy in [
      "malformed-data-segment-memory-index-uleb", "malformed-element-segment-table-index-uleb",
    ] {
    match invalid_binary_expect_strategy_rejects(strategy, 0x5f18UL, "decode") {
      Ok(_) => ()
      Err(msg) => fail("\{strategy}: \{msg}")
    }
  }
}

///|
test "invalid binary FZG028 decodes SIMD extract-lane overflow as invalid" {
  match
    invalid_binary_expect_strategy_rejects(
      "simd-extract-lane-index-overflow", 0x5f13UL, "decode",
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "invalid binary FZG025 decodes new binary-surface corruptions as invalid" {
  for
    strategy in [
      "duplicate-import-section", "duplicate-export-section", "duplicate-table-section",
      "duplicate-memory-section", "duplicate-global-section", "duplicate-function-section",
      "duplicate-code-section", "duplicate-element-section", "duplicate-data-section",
      "duplicate-tag-section", "malformed-simd-immediate", "simd-lane-index-overflow",
      "malformed-custom-section-payload", "malformed-custom-section-name-length-uleb",
      "malformed-name-subsection-size-uleb", "invalid-opcode-byte", "invalid-prefix-subopcode-byte",
      "malformed-memarg-immediate", "malformed-load-memarg-align-uleb", "malformed-store-memarg-align-uleb",
      "malformed-load-memarg-offset-uleb", "malformed-store-memarg-offset-uleb",
      "malformed-blocktype-immediate", "malformed-memory-min-uleb", "malformed-table-min-uleb",
      "malformed-memory-max-uleb", "malformed-table-max-uleb", "invalid-export-name-utf8",
      "invalid-import-module-name-utf8", "invalid-import-field-name-utf8", "invalid-import-kind-byte",
      "malformed-import-func-type-index-uleb", "malformed-import-tag-type-index-uleb",
      "malformed-import-memory-min-uleb", "malformed-import-table-min-uleb", "malformed-import-memory-max-uleb",
      "malformed-import-table-max-uleb", "invalid-import-table-reftype-byte", "invalid-import-memory-limits-flag-byte",
      "invalid-import-global-valtype-byte", "invalid-import-global-mutability-byte",
      "invalid-table-reftype-byte", "invalid-table-limits-flag-byte", "malformed-ref-null-heaptype-immediate",
      "malformed-ref-cast-heaptype-immediate", "malformed-ref-test-heaptype-immediate",
      "invalid-global-valtype-byte", "invalid-export-kind-byte", "invalid-memory-limits-flag-byte",
      "invalid-tag-attribute-byte", "invalid-global-mutability-byte", "malformed-export-func-index-uleb",
      "malformed-export-table-index-uleb", "malformed-export-memory-index-uleb",
      "malformed-export-global-index-uleb", "malformed-export-tag-index-uleb", "invalid-element-segment-flag-byte",
      "invalid-element-kind-byte", "invalid-data-segment-flag-byte", "type-section-count-overflow",
      "code-section-count-overflow", "table-section-count-overflow", "export-section-count-overflow",
      "import-section-count-overflow", "global-section-count-overflow", "function-section-count-overflow",
      "memory-section-count-overflow", "element-section-count-overflow", "data-section-count-overflow",
      "tag-section-count-overflow", "malformed-tag-type-index-uleb", "malformed-local-index-uleb",
      "malformed-local-set-index-uleb", "malformed-local-tee-index-uleb", "malformed-global-index-uleb",
      "malformed-global-set-index-uleb", "malformed-i32-const-sleb", "malformed-i64-const-sleb",
      "malformed-f32-const-immediate", "malformed-f64-const-immediate", "malformed-call-func-index-uleb",
      "malformed-return-call-func-index-uleb", "malformed-ref-func-index-uleb", "malformed-call-indirect-type-index-uleb",
      "malformed-call-indirect-table-index-uleb", "malformed-br-label-index-uleb",
      "malformed-br-if-label-index-uleb", "malformed-br-table-target-count-uleb",
      "malformed-br-table-default-label-index-uleb", "malformed-table-index-uleb",
      "malformed-table-set-index-uleb", "malformed-memory-size-memory-index-uleb",
      "malformed-memory-grow-memory-index-uleb", "malformed-memory-copy-dst-index-uleb",
      "malformed-memory-copy-src-index-uleb", "malformed-table-copy-dst-index-uleb",
      "malformed-table-copy-src-index-uleb", "malformed-select-type-count-uleb",
      "invalid-typed-select-valtype-byte", "malformed-start-func-index-uleb", "malformed-datacount-uleb",
      "simd-shuffle-lane-overflow", "simd-load-lane-index-overflow", "simd-store-lane-index-overflow",
      "simd-extract-lane-index-overflow", "simd-replace-lane-index-overflow", "malformed-data-index-uleb",
      "malformed-memory-init-memory-index-uleb", "malformed-elem-index-uleb", "malformed-table-init-table-index-uleb",
      "malformed-data-segment-memory-index-uleb", "malformed-element-segment-table-index-uleb",
      "invalid-name-section-func-name-utf8", "invalid-name-section-local-name-utf8",
      "invalid-name-section-module-name-utf8", "invalid-name-section-type-name-utf8",
      "invalid-name-section-table-name-utf8", "invalid-name-section-memory-name-utf8",
      "invalid-name-section-global-name-utf8", "invalid-name-section-elem-name-utf8",
      "invalid-name-section-data-name-utf8", "invalid-name-section-field-name-utf8",
      "invalid-name-section-label-name-utf8", "invalid-name-section-tag-name-utf8",
      "invalid-functype-byte", "invalid-code-local-valtype-byte", "type-section-count-underflow",
      "code-section-count-underflow", "import-section-count-underflow", "export-section-count-underflow",
      "table-section-count-underflow", "memory-section-count-underflow", "global-section-count-underflow",
      "function-section-count-underflow", "element-section-count-underflow", "data-section-count-underflow",
      "tag-section-count-underflow", "type-section-size-underflow", "code-body-size-underflow",
      "import-section-size-underflow", "export-section-size-underflow", "table-section-size-underflow",
      "memory-section-size-underflow", "global-section-size-underflow", "function-section-size-underflow",
      "element-section-size-underflow", "data-section-size-underflow", "tag-section-size-underflow",
      "type-section-size-overflow", "import-section-size-overflow", "export-section-size-overflow",
      "table-section-size-overflow", "memory-section-size-overflow", "global-section-size-overflow",
      "function-section-size-overflow", "element-section-size-overflow", "data-section-size-overflow",
      "tag-section-size-overflow", "start-section-size-underflow", "datacount-section-size-underflow",
      "start-section-size-overflow", "datacount-section-size-overflow",
    ] {
    match invalid_binary_expect_strategy_rejects(strategy, 0x5f09UL, "decode") {
      Ok(_) => ()
      Err(msg) => fail("\{strategy}: \{msg}")
    }
  }
}

///|
test "gen_invalid_binary_generate supports datacount mismatch too-large modules" {
  let generated = match
    gen_invalid_binary_generate(
      @splitmix.new(seed=0x5eedUL),
      GenInvalidBinaryParams::repro_seed(DataCountMismatchTooLargeModule),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match decode_module(generated.mutation.mutated_bytes) {
    Err(msg) =>
      fail("expected datacount mismatch invalid bytes to decode first: \{msg}")
    Ok(decoded) =>
      match validate_module(decoded) {
        Ok(_) =>
          fail(
            "expected decoded datacount-mismatch-invalid binary to fail validation",
          )
        Err(err) => {
          let family = validation_issue_family(
            validation_error_diagnostic(err).issue,
          )
          @debug.assert_eq(
            invalid_binary_test_validation_family_label(family),
            "datacount",
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
  let expected = gen_invalid_binary_coverage_seed_generator_config()
  assert_true(params.seed_mode == RandomValidSeed)
  assert_true(params.generator_config == expected)
}

///|
test "gen_invalid_binary new enables strategy prereqs by default" {
  let params = GenInvalidBinaryParams::new(InvalidFuncTypeIndex)
  assert_true(params.require_strategy_prereqs)
}

///|
test "gen_invalid_binary new can disable strategy prereqs" {
  let params = GenInvalidBinaryParams::new(
    InvalidFuncTypeIndex,
    require_strategy_prereqs=false,
  )
  assert_false(params.require_strategy_prereqs)
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
test "gen_invalid_binary small_natural_seed enables strategy prereqs by default" {
  let params = GenInvalidBinaryParams::small_natural_seed(InvalidFuncTypeIndex)
  assert_true(params.require_strategy_prereqs)
}

///|
test "gen_invalid_binary small_coverage_forced_seed uses a smaller coverage config" {
  let params = GenInvalidBinaryParams::small_coverage_forced_seed(
    TrailingGarbage,
  )
  let forced = gen_invalid_binary_coverage_seed_generator_config()
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
          @debug.assert_eq(
            invalid_binary_test_validation_family_label(family),
            "function",
          )
        }
      }
  }
}

///|
test "gen_invalid_binary repro_seed matches small coverage-forced seed defaults" {
  let repro = GenInvalidBinaryParams::repro_seed(TrailingGarbage)
  let small = GenInvalidBinaryParams::small_coverage_forced_seed(
    TrailingGarbage,
  )
  assert_true(repro.seed_mode == small.seed_mode)
  assert_true(repro.generator_config == small.generator_config)
  assert_true(repro.require_strategy_prereqs == small.require_strategy_prereqs)
}

///|
test "gen_invalid_binary_params_profile_name identifies named and custom profiles" {
  @debug.assert_eq(
    gen_invalid_binary_params_profile_name(
      GenInvalidBinaryParams::natural_seed(TrailingGarbage),
    ),
    "natural",
  )
  @debug.assert_eq(
    gen_invalid_binary_params_profile_name(
      GenInvalidBinaryParams::coverage_forced_seed(TrailingGarbage),
    ),
    "coverage-forced",
  )
  @debug.assert_eq(
    gen_invalid_binary_params_profile_name(
      GenInvalidBinaryParams::small_natural_seed(TrailingGarbage),
    ),
    "small-natural",
  )
  @debug.assert_eq(
    gen_invalid_binary_params_profile_name(
      GenInvalidBinaryParams::small_coverage_forced_seed(TrailingGarbage),
    ),
    "small-coverage-forced",
  )
  @debug.assert_eq(
    gen_invalid_binary_params_profile_name(
      GenInvalidBinaryParams::repro_seed(TrailingGarbage),
    ),
    "repro",
  )
  @debug.assert_eq(
    gen_invalid_binary_params_profile_name(
      GenInvalidBinaryParams::minimal_seed(TrailingGarbage),
    ),
    "minimal",
  )
  @debug.assert_eq(
    gen_invalid_binary_params_profile_name(
      GenInvalidBinaryParams::new(
        TrailingGarbage,
        generator_config=GenValidConfig::natural_default(),
      ),
    ),
    "custom",
  )
}
