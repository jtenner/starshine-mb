///|
test "validate_invalid_text_registry exposes curated stage-aware strategies" {
  let registry = validate_invalid_text_registry()
  @debug.assert_eq(registry.map(fn(spec) { spec.stable_id }), [
    "malformed-quote-missing-paren", "invalid-result-stack", "unlinkable-unknown-import",
    "malformed-trailing-garbage", "invalid-mutable-global-const-init", "unlinkable-unknown-memory-import",
    "malformed-invalid-const-token", "invalid-start-func-param", "unlinkable-unknown-global-import",
    "malformed-invalid-f64-const-token", "invalid-duplicate-export-name", "unlinkable-unknown-table-import",
    "malformed-invalid-i64-const-token", "invalid-start-func-result", "unlinkable-incompatible-func-import-type",
    "malformed-invalid-i32-hex-token", "invalid-imported-start-func-param", "unlinkable-incompatible-global-import-type",
    "malformed-invalid-i64-hex-token", "invalid-imported-start-func-result", "unlinkable-incompatible-tag-import-type",
    "malformed-invalid-i32-bad-opcode", "invalid-imported-start-func-param-result",
    "unlinkable-incompatible-global-import-mutability", "malformed-invalid-f32-bad-opcode",
    "invalid-imported-start-func-multi-param", "unlinkable-incompatible-global-import-i64",
    "malformed-invalid-i64-bad-opcode", "invalid-imported-start-func-f32-param",
    "invalid-imported-start-func-externref-param", "malformed-invalid-f64-bad-opcode",
    "invalid-imported-start-func-funcref-param", "unlinkable-incompatible-global-import-f64",
    "unlinkable-incompatible-memory-import-max", "invalid-start-func-out-of-range",
    "unlinkable-incompatible-memory-import-min", "unlinkable-incompatible-table-import-limits",
    "invalid-global-init-body-op", "invalid-data-offset-body-op", "invalid-element-offset-body-op",
  ])
  @debug.assert_eq(
    registry.map(fn(spec) {
      validate_invalid_text_stage_name(spec.expected_stage)
    }),
    [
      "parse-or-lower-rejected", "validate-rejected", "valid-before-link", "parse-or-lower-rejected",
      "validate-rejected", "valid-before-link", "parse-or-lower-rejected", "validate-rejected",
      "valid-before-link", "parse-or-lower-rejected", "validate-rejected", "valid-before-link",
      "parse-or-lower-rejected", "validate-rejected", "valid-before-link", "parse-or-lower-rejected",
      "validate-rejected", "valid-before-link", "parse-or-lower-rejected", "validate-rejected",
      "valid-before-link", "parse-or-lower-rejected", "validate-rejected", "valid-before-link",
      "parse-or-lower-rejected", "validate-rejected", "valid-before-link", "parse-or-lower-rejected",
      "validate-rejected", "validate-rejected", "parse-or-lower-rejected", "validate-rejected",
      "valid-before-link", "valid-before-link", "validate-rejected", "valid-before-link",
      "valid-before-link", "validate-rejected", "validate-rejected", "validate-rejected",
    ],
  )
  let smoke_required = registry.filter(fn(spec) { spec.required_in_smoke })
  @debug.assert_eq(smoke_required.length(), 40)
}

///|
test "validate_invalid_spec_seed_registry exposes curated malformed invalid and unlinkable seeds" {
  let registry = validate_invalid_spec_seed_registry()
  @debug.assert_eq(registry.map(fn(spec) { spec.stable_id }), [
    "const-malformed-quote-1", "f32-invalid-type-mismatch-1", "imports-unlinkable-unknown-import-1",
    "const-malformed-quote-2", "f32-invalid-type-mismatch-2", "imports-unlinkable-unknown-import-2",
    "const-malformed-quote-3", "f32-invalid-type-mismatch-3", "imports-unlinkable-incompatible-import-type-1",
    "const-malformed-quote-4", "f32-invalid-type-mismatch-4", "imports-unlinkable-incompatible-import-type-2",
    "const-malformed-quote-5", "f32-invalid-type-mismatch-5", "imports-unlinkable-incompatible-import-type-3",
    "const-malformed-quote-6", "f32-invalid-type-mismatch-6", "imports-unlinkable-incompatible-import-type-4",
    "const-malformed-quote-7", "f32-invalid-type-mismatch-7", "imports-unlinkable-incompatible-import-type-5",
    "const-malformed-quote-8", "f32-invalid-type-mismatch-8", "imports-unlinkable-incompatible-import-type-6",
    "const-malformed-quote-9", "f32-invalid-type-mismatch-9", "imports-unlinkable-incompatible-import-type-7",
    "const-malformed-quote-10", "f32-invalid-type-mismatch-10", "imports-unlinkable-incompatible-import-type-8",
    "const-malformed-quote-11", "f32-invalid-type-mismatch-11", "imports-unlinkable-incompatible-import-type-9",
    "const-malformed-quote-12", "store-invalid-type-mismatch-1", "imports-unlinkable-incompatible-import-type-10",
    "const-malformed-quote-13", "store-invalid-type-mismatch-2", "imports-unlinkable-incompatible-import-type-11",
  ])
  @debug.assert_eq(
    registry.map(fn(spec) {
      validate_invalid_text_stage_name(spec.expected_stage)
    }),
    [
      "parse-or-lower-rejected", "validate-rejected", "valid-before-link", "parse-or-lower-rejected",
      "validate-rejected", "valid-before-link", "parse-or-lower-rejected", "validate-rejected",
      "valid-before-link", "parse-or-lower-rejected", "validate-rejected", "valid-before-link",
      "parse-or-lower-rejected", "validate-rejected", "valid-before-link", "parse-or-lower-rejected",
      "validate-rejected", "valid-before-link", "parse-or-lower-rejected", "validate-rejected",
      "valid-before-link", "parse-or-lower-rejected", "validate-rejected", "valid-before-link",
      "parse-or-lower-rejected", "validate-rejected", "valid-before-link", "parse-or-lower-rejected",
      "validate-rejected", "valid-before-link", "parse-or-lower-rejected", "validate-rejected",
      "valid-before-link", "parse-or-lower-rejected", "validate-rejected", "valid-before-link",
      "parse-or-lower-rejected", "validate-rejected", "valid-before-link",
    ],
  )
  let smoke_required = registry.filter(fn(spec) { spec.required_in_smoke })
  @debug.assert_eq(smoke_required.length(), 39)
}

///|
test "inline malformed text strategy rejects during parse or lower" {
  match
    run_validate_invalid_text_case_by_stable_id("malformed-quote-missing-paren") {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline invalid text strategy rejects during validation" {
  match run_validate_invalid_text_case_by_stable_id("invalid-result-stack") {
    Ok(stage) => @debug.assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline unlinkable text strategy stays valid before link" {
  match
    run_validate_invalid_text_case_by_stable_id("unlinkable-unknown-import") {
    Ok(stage) => @debug.assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "inline trailing garbage malformed strategy rejects during parse or lower" {
  match
    run_validate_invalid_text_case_by_stable_id("malformed-trailing-garbage") {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline mutable global const-init strategy rejects during validation" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "invalid-mutable-global-const-init",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline body-only const-expression strategies reject during validation" {
  for
    stable_id in [
      "invalid-global-init-body-op", "invalid-data-offset-body-op", "invalid-element-offset-body-op",
    ] {
    match run_validate_invalid_text_case_by_stable_id(stable_id) {
      Ok(stage) => @debug.assert_eq(stage, "validate-rejected")
      Err(msg) => fail(msg)
    }
  }
}

///|
test "inline unknown memory import strategy stays valid before link" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "unlinkable-unknown-memory-import",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "inline malformed invalid const token strategy rejects during parse or lower" {
  match
    run_validate_invalid_text_case_by_stable_id("malformed-invalid-const-token") {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline invalid start func param strategy rejects during validation" {
  match
    run_validate_invalid_text_case_by_stable_id("invalid-start-func-param") {
    Ok(stage) => @debug.assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline unknown global import strategy stays valid before link" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "unlinkable-unknown-global-import",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "inline malformed invalid f64 const token strategy rejects during parse or lower" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "malformed-invalid-f64-const-token",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline duplicate export name strategy rejects during validation" {
  match
    run_validate_invalid_text_case_by_stable_id("invalid-duplicate-export-name") {
    Ok(stage) => @debug.assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline unknown table import strategy stays valid before link" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "unlinkable-unknown-table-import",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "inline malformed invalid i64 const token strategy rejects during parse or lower" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "malformed-invalid-i64-const-token",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline invalid start func result strategy rejects during validation" {
  match
    run_validate_invalid_text_case_by_stable_id("invalid-start-func-result") {
    Ok(stage) => @debug.assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline incompatible func import type strategy stays valid before link" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "unlinkable-incompatible-func-import-type",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "inline malformed invalid i32 hex token strategy rejects during parse or lower" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "malformed-invalid-i32-hex-token",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline invalid imported start func param strategy rejects during validation" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "invalid-imported-start-func-param",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline incompatible global import type strategy stays valid before link" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "unlinkable-incompatible-global-import-type",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "inline malformed invalid i64 hex token strategy rejects during parse or lower" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "malformed-invalid-i64-hex-token",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline invalid imported start func result strategy rejects during validation" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "invalid-imported-start-func-result",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline incompatible tag import type strategy stays valid before link" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "unlinkable-incompatible-tag-import-type",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "inline malformed invalid i32 bad opcode strategy rejects during parse or lower" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "malformed-invalid-i32-bad-opcode",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline invalid imported start func param-result strategy rejects during validation" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "invalid-imported-start-func-param-result",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline incompatible global import mutability strategy stays valid before link" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "unlinkable-incompatible-global-import-mutability",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "inline malformed invalid f32 bad opcode strategy rejects during parse or lower" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "malformed-invalid-f32-bad-opcode",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline invalid imported start func multi-param strategy rejects during validation" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "invalid-imported-start-func-multi-param",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline incompatible global import i64 strategy stays valid before link" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "unlinkable-incompatible-global-import-i64",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "inline malformed invalid i64 bad opcode strategy rejects during parse or lower" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "malformed-invalid-i64-bad-opcode",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline invalid imported start func f32 param strategy rejects during validation" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "invalid-imported-start-func-f32-param",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline invalid imported start func externref param strategy rejects during validation" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "invalid-imported-start-func-externref-param",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline malformed invalid f64 bad opcode strategy rejects during parse or lower" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "malformed-invalid-f64-bad-opcode",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline invalid imported start func funcref param strategy rejects during validation" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "invalid-imported-start-func-funcref-param",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline incompatible global import f64 strategy stays valid before link" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "unlinkable-incompatible-global-import-f64",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "inline incompatible memory import max strategy stays valid before link" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "unlinkable-incompatible-memory-import-max",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "inline start func out of range strategy rejects during validation" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "invalid-start-func-out-of-range",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline incompatible memory import min strategy stays valid before link" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "unlinkable-incompatible-memory-import-min",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "inline incompatible table import limits strategy stays valid before link" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "unlinkable-incompatible-table-import-limits",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "spec-seed malformed case rejects during parse or lower" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id("const-malformed-quote-1") {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "spec-seed invalid case rejects during validation" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "f32-invalid-type-mismatch-1",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "spec-seed unlinkable case stays valid before link" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "imports-unlinkable-unknown-import-1",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "second spec-seed malformed case rejects during parse or lower" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id("const-malformed-quote-2") {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "second spec-seed invalid case rejects during validation" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "f32-invalid-type-mismatch-2",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "second spec-seed unlinkable case stays valid before link" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "imports-unlinkable-unknown-import-2",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "third spec-seed malformed case rejects during parse or lower" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id("const-malformed-quote-3") {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "third spec-seed invalid case rejects during validation" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "f32-invalid-type-mismatch-3",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "incompatible import type spec-seed case stays valid before link" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "imports-unlinkable-incompatible-import-type-1",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "fourth spec-seed malformed case rejects during parse or lower" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id("const-malformed-quote-4") {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "fourth spec-seed invalid case rejects during validation" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "f32-invalid-type-mismatch-4",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "second incompatible import type spec-seed case stays valid before link" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "imports-unlinkable-incompatible-import-type-2",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "fifth spec-seed malformed case rejects during parse or lower" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id("const-malformed-quote-5") {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "fifth spec-seed invalid case rejects during validation" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "f32-invalid-type-mismatch-5",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "third incompatible import type spec-seed case stays valid before link" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "imports-unlinkable-incompatible-import-type-3",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "sixth spec-seed malformed case rejects during parse or lower" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id("const-malformed-quote-6") {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "sixth spec-seed invalid case rejects during validation" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "f32-invalid-type-mismatch-6",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "fourth incompatible import type spec-seed case stays valid before link" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "imports-unlinkable-incompatible-import-type-4",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "seventh spec-seed malformed case rejects during parse or lower" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id("const-malformed-quote-7") {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "seventh spec-seed invalid case rejects during validation" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "f32-invalid-type-mismatch-7",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "fifth incompatible import type spec-seed case stays valid before link" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "imports-unlinkable-incompatible-import-type-5",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "eighth spec-seed malformed case rejects during parse or lower" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id("const-malformed-quote-8") {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "eighth spec-seed invalid case rejects during validation" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "f32-invalid-type-mismatch-8",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "sixth incompatible import type spec-seed case stays valid before link" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "imports-unlinkable-incompatible-import-type-6",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "ninth spec-seed malformed case rejects during parse or lower" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id("const-malformed-quote-9") {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "ninth spec-seed invalid case rejects during validation" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "f32-invalid-type-mismatch-9",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "seventh incompatible import type spec-seed case stays valid before link" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "imports-unlinkable-incompatible-import-type-7",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "tenth spec-seed malformed case rejects during parse or lower" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id("const-malformed-quote-10") {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "tenth spec-seed invalid case rejects during validation" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "f32-invalid-type-mismatch-10",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "eighth incompatible import type spec-seed case stays valid before link" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "imports-unlinkable-incompatible-import-type-8",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "eleventh malformed quote spec-seed case rejects during parse or lower" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id("const-malformed-quote-11") {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "eleventh invalid type mismatch spec-seed case rejects during validation" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "f32-invalid-type-mismatch-11",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "ninth incompatible import type spec-seed case stays valid before link" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "imports-unlinkable-incompatible-import-type-9",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "twelfth malformed quote spec-seed case rejects during parse or lower" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id("const-malformed-quote-12") {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "store invalid type mismatch spec-seed case rejects during validation" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "store-invalid-type-mismatch-1",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "thirteenth malformed quote spec-seed case rejects during parse or lower" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id("const-malformed-quote-13") {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "second store invalid type mismatch spec-seed case rejects during validation" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "store-invalid-type-mismatch-2",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "tenth incompatible import type spec-seed case stays valid before link" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "imports-unlinkable-incompatible-import-type-10",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "eleventh incompatible import type spec-seed case stays valid before link" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "imports-unlinkable-incompatible-import-type-11",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "dynamic spec-seed source scanner classifies assertion kind occurrence and feature family" {
  let source =
    #|(module)
    #|(assert_malformed (module quote "\00") "bad string")
    #|(assert_invalid (module (func (result i32))) "type mismatch")
    #|(assert_unlinkable (module (import "missing" "f" (func))) "unknown import")
    #|(assert_invalid (module (func (i32.const 1) (i64.add))) "type mismatch")
  let scanned = match
    validate_invalid_spec_seed_scan_source(
      "tests/spec/example-family.wast", source,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(scanned.length(), 4)
  @debug.assert_eq(scanned.map(fn(item) { item.stable_id }), [
    "example-family-malformed-1", "example-family-invalid-1", "example-family-invalid-2",
    "example-family-unlinkable-1",
  ])
  @debug.assert_eq(scanned.map(fn(item) { item.feature_family }), [
    "example-family", "example-family", "example-family", "example-family",
  ])
  @debug.assert_eq(scanned.map(fn(item) { item.assertion_occurrence }), [
    0, 0, 1, 0,
  ])
  @debug.assert_eq(
    scanned.map(fn(item) {
      validate_invalid_text_stage_name(item.expected_stage)
    }),
    [
      "parse-or-lower-rejected", "validate-rejected", "validate-rejected", "valid-before-link",
    ],
  )
}

///|
test "dynamic spec-seed directory scanner discovers non-curated committed spec assertions" {
  let scanned = match validate_invalid_spec_seed_scan_directory("tests/spec") {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  assert_true(scanned.length() > validate_invalid_spec_seed_registry().length())
  assert_true(
    scanned.any(fn(item) {
      item.stable_id == "token-malformed-1" &&
      item.path == "tests/spec/token.wast"
    }),
  )
}

///|
test "dynamic spec-seed sampler filters scanned assertions by file kind and occurrence" {
  let source =
    #|(assert_malformed (module quote "\00") "bad string")
    #|(assert_invalid (module (func (result i32))) "type mismatch")
    #|(assert_invalid (module (func (i32.const 1) (i64.add))) "type mismatch")
  let scanned = match
    validate_invalid_spec_seed_scan_source(
      "tests/spec/filter-family.wast", source,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let selected = validate_invalid_spec_seed_select(
    scanned,
    path_filter="tests/spec/filter-family.wast",
    assertion_kind_filter=Some(InvalidTextAssertion),
    occurrence_filter=Some(1),
    feature_family_filter="filter-family",
  )
  @debug.assert_eq(selected.length(), 1)
  @debug.assert_eq(selected[0].stable_id, "filter-family-invalid-2")
  @debug.assert_eq(selected[0].assertion_source.contains("i64.add"), true)
}

///|
test "dynamic invalid text source feature facts classify generated WAT fields and operations" {
  let source =
    #|(module
    #|  (type (func))
    #|  (import "env" "f" (func))
    #|  (memory 1)
    #|  (table 1 funcref)
    #|  (global i32 (i32.const 0))
    #|  (elem (i32.const 0) func 0)
    #|  (data (i32.const 0) "x")
    #|  (func (export "run") (result i32) i32.const 7 i32.add)
    #|  (start 1))
  let facts = validate_invalid_text_dynamic_source_feature_facts(source)
  assert_true(facts.contains("source:gen-valid-wat"))
  assert_true(facts.contains("wat-field:type"))
  assert_true(facts.contains("wat-field:import"))
  assert_true(facts.contains("wat-field:func"))
  assert_true(facts.contains("wat-field:export"))
  assert_true(facts.contains("wat-field:memory"))
  assert_true(facts.contains("wat-field:table"))
  assert_true(facts.contains("wat-field:global"))
  assert_true(facts.contains("wat-field:elem"))
  assert_true(facts.contains("wat-field:data"))
  assert_true(facts.contains("wat-field:start"))
  assert_true(facts.contains("wat-op:i32.const"))
  assert_true(facts.contains("wat-op:i32.add"))
}

///|
test "dynamic invalid text missing paren mutates generated valid WAT into malformed assertion" {
  let generated = match
    validate_invalid_text_dynamic_case(
      0x5eedUL, "dynamic-gen-valid-missing-closing-paren",
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    generated.stable_id,
    "dynamic-gen-valid-missing-closing-paren",
  )
  @debug.assert_eq(generated.variant_id, "gen-valid-wat/missing-closing-paren")
  @debug.assert_eq(
    validate_invalid_text_stage_name(generated.expected_stage),
    "parse-or-lower-rejected",
  )
  assert_true(generated.base_source.contains("(module"))
  assert_true(generated.assertion_source.contains("(assert_malformed"))
  assert_true(generated.assertion_source.contains("module quote"))
  assert_false(generated.assertion_source.contains(generated.base_source))
  match
    run_validate_invalid_text_dynamic_case(
      0x5eedUL, "dynamic-gen-valid-missing-closing-paren",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "dynamic invalid text duplicate export mutates generated valid WAT into invalid assertion" {
  let generated = match
    validate_invalid_text_dynamic_case(
      0x5eedUL, "dynamic-gen-valid-duplicate-export",
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(generated.stable_id, "dynamic-gen-valid-duplicate-export")
  @debug.assert_eq(generated.variant_id, "gen-valid-wat/duplicate-export")
  @debug.assert_eq(
    validate_invalid_text_stage_name(generated.expected_stage),
    "validate-rejected",
  )
  assert_true(generated.source_feature_facts.contains("source:gen-valid-wat"))
  assert_true(generated.assertion_source.contains("(assert_invalid"))
  assert_true(generated.assertion_source.contains("dynamic duplicate export"))
  assert_true(generated.assertion_source.contains("dynamic_duplicate_export"))
  match
    run_validate_invalid_text_dynamic_case(
      0x5eedUL, "dynamic-gen-valid-duplicate-export",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "dynamic invalid text bad opcode mutates generated valid WAT into malformed assertion" {
  let generated = match
    validate_invalid_text_dynamic_case(
      0x5eedUL, "dynamic-gen-valid-bad-opcode-token",
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(generated.stable_id, "dynamic-gen-valid-bad-opcode-token")
  @debug.assert_eq(generated.variant_id, "gen-valid-wat/bad-opcode-token")
  @debug.assert_eq(
    validate_invalid_text_stage_name(generated.expected_stage),
    "parse-or-lower-rejected",
  )
  assert_true(generated.source_feature_facts.contains("source:gen-valid-wat"))
  assert_true(generated.assertion_source.contains("(assert_malformed"))
  assert_true(generated.assertion_source.contains("dynamic.unknown_opcode"))
  match
    run_validate_invalid_text_dynamic_case(
      0x5eedUL, "dynamic-gen-valid-bad-opcode-token",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "dynamic invalid text bad type token mutates generated valid WAT into malformed assertion" {
  let generated = match
    validate_invalid_text_dynamic_case(
      0x5eedUL, "dynamic-gen-valid-bad-type-token",
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(generated.stable_id, "dynamic-gen-valid-bad-type-token")
  @debug.assert_eq(generated.variant_id, "gen-valid-wat/bad-type-token")
  @debug.assert_eq(
    validate_invalid_text_stage_name(generated.expected_stage),
    "parse-or-lower-rejected",
  )
  assert_true(generated.source_feature_facts.contains("source:gen-valid-wat"))
  assert_true(generated.assertion_source.contains("(assert_malformed"))
  assert_true(generated.assertion_source.contains("(param dyn_i32)"))
  match
    run_validate_invalid_text_dynamic_case(
      0x5eedUL, "dynamic-gen-valid-bad-type-token",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "dynamic invalid text bad lane mutates generated valid WAT into malformed assertion" {
  let generated = match
    validate_invalid_text_dynamic_case(
      0x5eedUL, "dynamic-gen-valid-bad-lane-index",
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(generated.stable_id, "dynamic-gen-valid-bad-lane-index")
  @debug.assert_eq(generated.variant_id, "gen-valid-wat/bad-lane-index")
  @debug.assert_eq(
    validate_invalid_text_stage_name(generated.expected_stage),
    "parse-or-lower-rejected",
  )
  assert_true(generated.source_feature_facts.contains("source:gen-valid-wat"))
  assert_true(generated.assertion_source.contains("(assert_malformed"))
  assert_true(generated.assertion_source.contains("i8x16.extract_lane_u 16"))
  match
    run_validate_invalid_text_dynamic_case(
      0x5eedUL, "dynamic-gen-valid-bad-lane-index",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "dynamic invalid text bad memarg mutates generated valid WAT into malformed assertion" {
  let generated = match
    validate_invalid_text_dynamic_case(
      0x5eedUL, "dynamic-gen-valid-bad-memarg-align",
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(generated.stable_id, "dynamic-gen-valid-bad-memarg-align")
  @debug.assert_eq(generated.variant_id, "gen-valid-wat/bad-memarg-align")
  @debug.assert_eq(
    validate_invalid_text_stage_name(generated.expected_stage),
    "parse-or-lower-rejected",
  )
  assert_true(generated.source_feature_facts.contains("source:gen-valid-wat"))
  assert_true(generated.assertion_source.contains("(assert_malformed"))
  assert_true(generated.assertion_source.contains("i32.load8_s align=0"))
  match
    run_validate_invalid_text_dynamic_case(
      0x5eedUL, "dynamic-gen-valid-bad-memarg-align",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "dynamic invalid text unknown import mutates generated valid WAT into unlinkable assertion" {
  let generated = match
    validate_invalid_text_dynamic_case(
      0x5eedUL, "dynamic-gen-valid-unknown-import",
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(generated.stable_id, "dynamic-gen-valid-unknown-import")
  @debug.assert_eq(generated.variant_id, "gen-valid-wat/unknown-import")
  @debug.assert_eq(
    validate_invalid_text_stage_name(generated.expected_stage),
    "valid-before-link",
  )
  assert_true(generated.source_feature_facts.contains("source:gen-valid-wat"))
  assert_true(
    generated.source_feature_facts.contains("mutation:unknown-import"),
  )
  assert_true(generated.assertion_source.contains("(assert_unlinkable"))
  assert_true(generated.assertion_source.contains("dynamic_unknown_import"))
  match
    run_validate_invalid_text_dynamic_case(
      0x5eedUL, "dynamic-gen-valid-unknown-import",
    ) {
    Ok(stage) => @debug.assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "dynamic invalid text attempt seeds come from text-mutation stream and stable strategy salts" {
  let stream_seed = validate_invalid_text_dynamic_stream_seed(0x51034UL)
  let left = validate_invalid_text_dynamic_attempt_seed(
    0x51034UL, "dynamic-gen-valid-bad-opcode-token", 0,
  )
  let left_again = validate_invalid_text_dynamic_attempt_seed(
    0x51034UL, "dynamic-gen-valid-bad-opcode-token", 0,
  )
  let next_attempt = validate_invalid_text_dynamic_attempt_seed(
    0x51034UL, "dynamic-gen-valid-bad-opcode-token", 1,
  )
  let other_strategy = validate_invalid_text_dynamic_attempt_seed(
    0x51034UL, "dynamic-gen-valid-bad-memarg-align", 0,
  )
  @debug.assert_eq(left, left_again)
  assert_true(left != next_attempt)
  assert_true(left != other_strategy)
  assert_true(left != 0x51034UL)
  assert_true(stream_seed != 0x51034UL)
  assert_true(left != stream_seed)
}

///|
test "dynamic invalid text fuzz is deterministic and records generated mutation stats" {
  let first = match run_validate_invalid_text_dynamic_fuzz("smoke", 0x5eedUL) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let second = match run_validate_invalid_text_dynamic_fuzz("smoke", 0x5eedUL) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  assert_true(first == second)
  @debug.assert_eq(first.profile, "smoke")
  @debug.assert_eq(first.attempts, 28)
  @debug.assert_eq(first.generated, 28)
  @debug.assert_eq(first.mutated, 28)
  @debug.assert_eq(first.parse_or_lower_rejected, 20)
  @debug.assert_eq(first.validate_rejected, 4)
  @debug.assert_eq(first.valid_before_link, 4)
  @debug.assert_eq(first.matched_expected, 28)
  @debug.assert_eq(first.strategy_stats.length(), 7)
  @debug.assert_eq(first.stream_label, "text-mutation-choice")
  @debug.assert_eq(
    first.stream_seed,
    validate_invalid_text_dynamic_stream_seed(0x5eedUL),
  )
  @debug.assert_eq(
    first.strategy_stats[0].stable_id,
    "dynamic-gen-valid-missing-closing-paren",
  )
  @debug.assert_eq(
    first.strategy_stats[0].variant_id,
    "gen-valid-wat/missing-closing-paren",
  )
  @debug.assert_eq(
    first.strategy_stats[1].stable_id,
    "dynamic-gen-valid-duplicate-export",
  )
  @debug.assert_eq(
    first.strategy_stats[1].variant_id,
    "gen-valid-wat/duplicate-export",
  )
  @debug.assert_eq(
    first.strategy_stats[2].stable_id,
    "dynamic-gen-valid-bad-opcode-token",
  )
  @debug.assert_eq(
    first.strategy_stats[2].variant_id,
    "gen-valid-wat/bad-opcode-token",
  )
  @debug.assert_eq(
    first.strategy_stats[3].stable_id,
    "dynamic-gen-valid-bad-type-token",
  )
  @debug.assert_eq(
    first.strategy_stats[3].variant_id,
    "gen-valid-wat/bad-type-token",
  )
  @debug.assert_eq(
    first.strategy_stats[4].stable_id,
    "dynamic-gen-valid-bad-lane-index",
  )
  @debug.assert_eq(
    first.strategy_stats[4].variant_id,
    "gen-valid-wat/bad-lane-index",
  )
  @debug.assert_eq(
    first.strategy_stats[5].stable_id,
    "dynamic-gen-valid-bad-memarg-align",
  )
  @debug.assert_eq(
    first.strategy_stats[5].variant_id,
    "gen-valid-wat/bad-memarg-align",
  )
  assert_true(
    first.strategy_stats[5].source_feature_facts.contains(
      "source:gen-valid-wat",
    ),
  )
  @debug.assert_eq(
    first.strategy_stats[6].stable_id,
    "dynamic-gen-valid-unknown-import",
  )
  @debug.assert_eq(
    first.strategy_stats[6].variant_id,
    "gen-valid-wat/unknown-import",
  )
  assert_true(
    first.strategy_stats[6].source_feature_facts.contains(
      "mutation:unknown-import",
    ),
  )
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
  @debug.assert_eq(first.attempts, 40)
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
  @debug.assert_eq(first.attempts, 39)
  @debug.assert_eq(first.dynamic_attempted, 0)
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

///|
test "ci spec-seed fuzz samples dynamic scanned assertions by kind and family" {
  let stats = match run_validate_invalid_spec_seed_fuzz("ci", 0x5eedUL) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  assert_true(
    stats.dynamic_scanned > validate_invalid_spec_seed_registry().length(),
  )
  assert_true(stats.dynamic_attempted > 0)
  assert_true(stats.dynamic_matched_expected > 0)
  assert_true(stats.dynamic_malformed_matched > 0)
  assert_true(stats.dynamic_invalid_matched > 0)
  assert_true(stats.dynamic_unlinkable_matched > 0)
  assert_true(stats.dynamic_feature_families_matched.length() >= 3)
}
