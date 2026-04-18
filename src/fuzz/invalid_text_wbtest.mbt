///|
test "validate_invalid_text_registry exposes curated stage-aware strategies" {
  let registry = validate_invalid_text_registry()
  assert_eq(registry.map(fn(spec) { spec.stable_id }), [
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
    "invalid-imported-start-func-externref-param", "unlinkable-incompatible-global-import-f64",
    "invalid-start-func-out-of-range", "unlinkable-incompatible-memory-import-min",
    "unlinkable-incompatible-table-import-limits",
  ])
  assert_eq(
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
      "validate-rejected", "validate-rejected", "valid-before-link", "validate-rejected",
      "valid-before-link", "valid-before-link",
    ],
  )
  let smoke_required = registry.filter(fn(spec) { spec.required_in_smoke })
  assert_eq(smoke_required.length(), 34)
}

///|
test "validate_invalid_spec_seed_registry exposes curated malformed invalid and unlinkable seeds" {
  let registry = validate_invalid_spec_seed_registry()
  assert_eq(registry.map(fn(spec) { spec.stable_id }), [
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
  ])
  assert_eq(
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
    ],
  )
  let smoke_required = registry.filter(fn(spec) { spec.required_in_smoke })
  assert_eq(smoke_required.length(), 36)
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
test "inline trailing garbage malformed strategy rejects during parse or lower" {
  match
    run_validate_invalid_text_case_by_stable_id("malformed-trailing-garbage") {
    Ok(stage) => assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline mutable global const-init strategy rejects during validation" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "invalid-mutable-global-const-init",
    ) {
    Ok(stage) => assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline unknown memory import strategy stays valid before link" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "unlinkable-unknown-memory-import",
    ) {
    Ok(stage) => assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "inline malformed invalid const token strategy rejects during parse or lower" {
  match
    run_validate_invalid_text_case_by_stable_id("malformed-invalid-const-token") {
    Ok(stage) => assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline invalid start func param strategy rejects during validation" {
  match
    run_validate_invalid_text_case_by_stable_id("invalid-start-func-param") {
    Ok(stage) => assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline unknown global import strategy stays valid before link" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "unlinkable-unknown-global-import",
    ) {
    Ok(stage) => assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "inline malformed invalid f64 const token strategy rejects during parse or lower" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "malformed-invalid-f64-const-token",
    ) {
    Ok(stage) => assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline duplicate export name strategy rejects during validation" {
  match
    run_validate_invalid_text_case_by_stable_id("invalid-duplicate-export-name") {
    Ok(stage) => assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline unknown table import strategy stays valid before link" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "unlinkable-unknown-table-import",
    ) {
    Ok(stage) => assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "inline malformed invalid i64 const token strategy rejects during parse or lower" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "malformed-invalid-i64-const-token",
    ) {
    Ok(stage) => assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline invalid start func result strategy rejects during validation" {
  match
    run_validate_invalid_text_case_by_stable_id("invalid-start-func-result") {
    Ok(stage) => assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline incompatible func import type strategy stays valid before link" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "unlinkable-incompatible-func-import-type",
    ) {
    Ok(stage) => assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "inline malformed invalid i32 hex token strategy rejects during parse or lower" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "malformed-invalid-i32-hex-token",
    ) {
    Ok(stage) => assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline invalid imported start func param strategy rejects during validation" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "invalid-imported-start-func-param",
    ) {
    Ok(stage) => assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline incompatible global import type strategy stays valid before link" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "unlinkable-incompatible-global-import-type",
    ) {
    Ok(stage) => assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "inline malformed invalid i64 hex token strategy rejects during parse or lower" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "malformed-invalid-i64-hex-token",
    ) {
    Ok(stage) => assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline invalid imported start func result strategy rejects during validation" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "invalid-imported-start-func-result",
    ) {
    Ok(stage) => assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline incompatible tag import type strategy stays valid before link" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "unlinkable-incompatible-tag-import-type",
    ) {
    Ok(stage) => assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "inline malformed invalid i32 bad opcode strategy rejects during parse or lower" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "malformed-invalid-i32-bad-opcode",
    ) {
    Ok(stage) => assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline invalid imported start func param-result strategy rejects during validation" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "invalid-imported-start-func-param-result",
    ) {
    Ok(stage) => assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline incompatible global import mutability strategy stays valid before link" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "unlinkable-incompatible-global-import-mutability",
    ) {
    Ok(stage) => assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "inline malformed invalid f32 bad opcode strategy rejects during parse or lower" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "malformed-invalid-f32-bad-opcode",
    ) {
    Ok(stage) => assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline invalid imported start func multi-param strategy rejects during validation" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "invalid-imported-start-func-multi-param",
    ) {
    Ok(stage) => assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline incompatible global import i64 strategy stays valid before link" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "unlinkable-incompatible-global-import-i64",
    ) {
    Ok(stage) => assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "inline malformed invalid i64 bad opcode strategy rejects during parse or lower" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "malformed-invalid-i64-bad-opcode",
    ) {
    Ok(stage) => assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline invalid imported start func f32 param strategy rejects during validation" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "invalid-imported-start-func-f32-param",
    ) {
    Ok(stage) => assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline invalid imported start func externref param strategy rejects during validation" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "invalid-imported-start-func-externref-param",
    ) {
    Ok(stage) => assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline incompatible global import f64 strategy stays valid before link" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "unlinkable-incompatible-global-import-f64",
    ) {
    Ok(stage) => assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "inline start func out of range strategy rejects during validation" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "invalid-start-func-out-of-range",
    ) {
    Ok(stage) => assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "inline incompatible memory import min strategy stays valid before link" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "unlinkable-incompatible-memory-import-min",
    ) {
    Ok(stage) => assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "inline incompatible table import limits strategy stays valid before link" {
  match
    run_validate_invalid_text_case_by_stable_id(
      "unlinkable-incompatible-table-import-limits",
    ) {
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
test "second spec-seed malformed case rejects during parse or lower" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id("const-malformed-quote-2") {
    Ok(stage) => assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "second spec-seed invalid case rejects during validation" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "f32-invalid-type-mismatch-2",
    ) {
    Ok(stage) => assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "second spec-seed unlinkable case stays valid before link" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "imports-unlinkable-unknown-import-2",
    ) {
    Ok(stage) => assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "third spec-seed malformed case rejects during parse or lower" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id("const-malformed-quote-3") {
    Ok(stage) => assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "third spec-seed invalid case rejects during validation" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "f32-invalid-type-mismatch-3",
    ) {
    Ok(stage) => assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "incompatible import type spec-seed case stays valid before link" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "imports-unlinkable-incompatible-import-type-1",
    ) {
    Ok(stage) => assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "fourth spec-seed malformed case rejects during parse or lower" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id("const-malformed-quote-4") {
    Ok(stage) => assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "fourth spec-seed invalid case rejects during validation" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "f32-invalid-type-mismatch-4",
    ) {
    Ok(stage) => assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "second incompatible import type spec-seed case stays valid before link" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "imports-unlinkable-incompatible-import-type-2",
    ) {
    Ok(stage) => assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "fifth spec-seed malformed case rejects during parse or lower" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id("const-malformed-quote-5") {
    Ok(stage) => assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "fifth spec-seed invalid case rejects during validation" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "f32-invalid-type-mismatch-5",
    ) {
    Ok(stage) => assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "third incompatible import type spec-seed case stays valid before link" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "imports-unlinkable-incompatible-import-type-3",
    ) {
    Ok(stage) => assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "sixth spec-seed malformed case rejects during parse or lower" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id("const-malformed-quote-6") {
    Ok(stage) => assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "sixth spec-seed invalid case rejects during validation" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "f32-invalid-type-mismatch-6",
    ) {
    Ok(stage) => assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "fourth incompatible import type spec-seed case stays valid before link" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "imports-unlinkable-incompatible-import-type-4",
    ) {
    Ok(stage) => assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "seventh spec-seed malformed case rejects during parse or lower" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id("const-malformed-quote-7") {
    Ok(stage) => assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "seventh spec-seed invalid case rejects during validation" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "f32-invalid-type-mismatch-7",
    ) {
    Ok(stage) => assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "fifth incompatible import type spec-seed case stays valid before link" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "imports-unlinkable-incompatible-import-type-5",
    ) {
    Ok(stage) => assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "eighth spec-seed malformed case rejects during parse or lower" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id("const-malformed-quote-8") {
    Ok(stage) => assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "eighth spec-seed invalid case rejects during validation" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "f32-invalid-type-mismatch-8",
    ) {
    Ok(stage) => assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "sixth incompatible import type spec-seed case stays valid before link" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "imports-unlinkable-incompatible-import-type-6",
    ) {
    Ok(stage) => assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "ninth spec-seed malformed case rejects during parse or lower" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id("const-malformed-quote-9") {
    Ok(stage) => assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "ninth spec-seed invalid case rejects during validation" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "f32-invalid-type-mismatch-9",
    ) {
    Ok(stage) => assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "seventh incompatible import type spec-seed case stays valid before link" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "imports-unlinkable-incompatible-import-type-7",
    ) {
    Ok(stage) => assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "tenth spec-seed malformed case rejects during parse or lower" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id("const-malformed-quote-10") {
    Ok(stage) => assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "tenth spec-seed invalid case rejects during validation" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "f32-invalid-type-mismatch-10",
    ) {
    Ok(stage) => assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "eighth incompatible import type spec-seed case stays valid before link" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "imports-unlinkable-incompatible-import-type-8",
    ) {
    Ok(stage) => assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "eleventh malformed quote spec-seed case rejects during parse or lower" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id("const-malformed-quote-11") {
    Ok(stage) => assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "eleventh invalid type mismatch spec-seed case rejects during validation" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "f32-invalid-type-mismatch-11",
    ) {
    Ok(stage) => assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "ninth incompatible import type spec-seed case stays valid before link" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "imports-unlinkable-incompatible-import-type-9",
    ) {
    Ok(stage) => assert_eq(stage, "valid-before-link")
    Err(msg) => fail(msg)
  }
}

///|
test "twelfth malformed quote spec-seed case rejects during parse or lower" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id("const-malformed-quote-12") {
    Ok(stage) => assert_eq(stage, "parse-or-lower-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "store invalid type mismatch spec-seed case rejects during validation" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "store-invalid-type-mismatch-1",
    ) {
    Ok(stage) => assert_eq(stage, "validate-rejected")
    Err(msg) => fail(msg)
  }
}

///|
test "tenth incompatible import type spec-seed case stays valid before link" {
  match
    run_validate_invalid_spec_seed_case_by_stable_id(
      "imports-unlinkable-incompatible-import-type-10",
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
  assert_eq(first.attempts, 34)
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
  assert_eq(first.attempts, 36)
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
