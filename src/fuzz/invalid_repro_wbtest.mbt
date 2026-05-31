///|
fn invalid_repro_test_bytes_to_ascii(bytes : Bytes) -> String {
  let out = StringBuilder::new()
  for byte in bytes {
    out.write_char(byte.to_int().unsafe_to_char())
  }
  out.to_string()
}

///|
fn invalid_repro_test_string_bytes(text : String) -> Bytes {
  let out : Array[Byte] = []
  for c in text {
    let code = c.to_int()
    if code >= 0 && code <= 255 {
      out.push(code.to_byte())
    } else {
      out.push('?'.to_int().to_byte())
    }
  }
  Bytes::from_array(out)
}

///|
fn invalid_repro_test_original_ast_report() -> Result[
  InvalidFuzzFailureReport,
  String,
] {
  build_invalid_fuzz_ast_failure_report_by_stable_id(
    "duplicate-export-name", 0x5eedUL, 1,
  )
}

///|
fn invalid_repro_test_original_binary_report() -> Result[
  InvalidFuzzFailureReport,
  String,
] {
  build_invalid_fuzz_binary_failure_report_by_stable_id(
    "invalid-func-type-index", 0x5eedUL, 2,
  )
}

///|
fn invalid_repro_test_original_text_report() -> Result[
  InvalidFuzzFailureReport,
  String,
] {
  build_invalid_fuzz_text_failure_report_by_stable_id(
    "invalid-result-stack", 0x5eedUL, 3,
  )
}

///|
fn invalid_repro_test_original_spec_seed_report() -> Result[
  InvalidFuzzFailureReport,
  String,
] {
  build_invalid_fuzz_spec_seed_failure_report_by_stable_id(
    "imports-unlinkable-unknown-import-1", 0x5eedUL, 4,
  )
}

///|
test "FUZ1026A1 builds deterministic two-fault AST invalid stress report" {
  let writes : Map[String, Bytes] = {}
  let io = InvalidFuzzPersistIO::new(ensure_dir=fn(_) { Ok(()) }, write_file=fn(
    path,
    bytes,
  ) {
    writes[path] = bytes
    Ok(())
  })
  let report = build_fuz1026_two_fault_ast_stress_report(0x1026UL, 1)
  @debug.assert_eq(report.suite, "validate-invalid-ast-multifault")
  @debug.assert_eq(report.strategy_id, "two-fault-ast-invalid-stress")
  assert_true(report.source_feature_facts.contains("multi_fault:true"))
  assert_true(
    report.multi_fault_mutation_ids.contains(
      "invalid-function-body-local-set-value-type",
    ),
  )
  assert_true(
    report.multi_fault_mutation_ids.contains(
      "invalid-function-body-branch-payload-type",
    ),
  )
  let (meta_path, artifact_paths) = match
    persist_invalid_fuzz_failure_report(report, io) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(artifact_paths.length(), 1)
  let meta_text = match writes.get(meta_path) {
    Some(v) => invalid_repro_test_bytes_to_ascii(v)
    None => fail("missing multifault AST metadata")
  }
  assert_true(meta_text.contains("source_feature_fact=multi_fault:true"))
  assert_true(
    meta_text.contains(
      "multi_fault_mutation_id=invalid-function-body-local-set-value-type",
    ),
  )
  assert_true(meta_text.contains("multi_fault_broad_outcome=validate-rejected"))
}

///|
test "FUZ1026A2 builds deterministic binary plus text multi-fault stress report" {
  let writes : Map[String, Bytes] = {}
  let io = InvalidFuzzPersistIO::new(ensure_dir=fn(_) { Ok(()) }, write_file=fn(
    path,
    bytes,
  ) {
    writes[path] = bytes
    Ok(())
  })
  let report = build_fuz1026_binary_text_multifault_stress_report(0x1026UL, 2)
  @debug.assert_eq(report.suite, "validate-invalid-binary-text-multifault")
  @debug.assert_eq(report.strategy_id, "binary-text-multifault-invalid-stress")
  assert_true(
    report.multi_fault_mutation_ids.contains("binary:trailing-garbage"),
  )
  assert_true(
    report.multi_fault_mutation_ids.contains("text:malformed-trailing-garbage"),
  )
  let (meta_path, artifact_paths) = match
    persist_invalid_fuzz_failure_report(report, io) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(artifact_paths.length(), 1)
  let meta_text = match writes.get(meta_path) {
    Some(v) => invalid_repro_test_bytes_to_ascii(v)
    None => fail("missing binary+text multifault metadata")
  }
  assert_true(
    meta_text.contains("multi_fault_mutation_id=binary:trailing-garbage"),
  )
  assert_true(
    meta_text.contains(
      "multi_fault_mutation_id=text:malformed-trailing-garbage",
    ),
  )
  assert_true(
    meta_text.contains("multi_fault_broad_outcome=decode-or-parse-rejected"),
  )
}

///|
test "FUZ1026B1 parses all multi-fault mutation ids and broad outcomes" {
  let report = build_fuz1026_binary_text_multifault_stress_report(0x1026UL, 3)
  let meta_text = invalid_fuzz_failure_meta_text(report)
  let parsed = match
    parse_invalid_fuzz_failure_report(meta_text, fn(_) { Ok(b"") }) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(parsed.multi_fault_mutation_ids, [
    "binary:trailing-garbage", "text:malformed-trailing-garbage",
  ])
  @debug.assert_eq(parsed.multi_fault_broad_outcomes, [
    "decode-or-parse-rejected",
  ])
}

///|
test "persist_invalid_fuzz_failure_report writes deterministic suite strategy layout" {
  let ensured_dirs : Array[String] = []
  let writes : Array[(String, Bytes)] = []
  let io = InvalidFuzzPersistIO::new(
    ensure_dir=fn(path) {
      ensured_dirs.push(path)
      Ok(())
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let original = match invalid_repro_test_original_binary_report() {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let reduced = match
    build_validate_invalid_binary_minimal_repro_by_stable_id("trailing-garbage") {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let report = InvalidFuzzFailureReport::new(
    "validate-invalid-binary",
    "smoke",
    0x5eedUL,
    2,
    "invalid-func-type-index",
    invalid_fuzz_binary_source_kind(),
    "validate-rejected",
    expected_diagnostic_family=Some("function"),
    actual_stage="validate-rejected",
    actual_diagnostic_family=Some("function"),
    actual_diagnostic_location=Some("binary:offset=8:length=5"),
    artifacts=original.artifacts,
    reduced_artifacts=[
      InvalidFuzzArtifact::new("reduced", "reduced.wasm", reduced),
    ],
  )
  let (meta_path, artifact_paths) = match
    persist_invalid_fuzz_failure_report(
      report,
      io,
      corpus_dir="tmp-invalid-corpus",
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(ensured_dirs, [
    "tmp-invalid-corpus", "tmp-invalid-corpus/validate-invalid-binary", "tmp-invalid-corpus/validate-invalid-binary/invalid-func-type-index",
    "tmp-invalid-corpus/validate-invalid-binary/invalid-func-type-index/seed-24301-attempt-2",
  ])
  @debug.assert_eq(
    meta_path, "tmp-invalid-corpus/validate-invalid-binary/invalid-func-type-index/seed-24301-attempt-2/repro.meta.txt",
  )
  @debug.assert_eq(artifact_paths, [
    "tmp-invalid-corpus/validate-invalid-binary/invalid-func-type-index/seed-24301-attempt-2/original.wasm",
    "tmp-invalid-corpus/validate-invalid-binary/invalid-func-type-index/seed-24301-attempt-2/seed.wasm",
    "tmp-invalid-corpus/validate-invalid-binary/invalid-func-type-index/seed-24301-attempt-2/reduced.wasm",
  ])
  let mut saw_meta = false
  for entry in writes {
    let path = entry.0
    let bytes = entry.1
    if path == meta_path {
      saw_meta = true
      let text = invalid_repro_test_bytes_to_ascii(bytes)
      assert_true(text.contains("suite=validate-invalid-binary"))
      assert_true(text.contains("strategy_id=invalid-func-type-index"))
      assert_true(text.contains("source_kind=binary"))
      assert_true(
        text.contains("actual_diagnostic_location=binary:offset=8:length=5"),
      )
      assert_true(text.contains("artifact=original|original.wasm"))
      assert_true(text.contains("artifact=seed|seed.wasm"))
      assert_true(text.contains("reduced=reduced|reduced.wasm"))
    }
  }
  assert_true(saw_meta)
}

///|
test "FUZ1053B1 timeout repro metadata persists resource budgets" {
  let writes : Map[String, Bytes] = {}
  let io = InvalidFuzzPersistIO::new(ensure_dir=fn(_) { Ok(()) }, write_file=fn(
    path,
    bytes,
  ) {
    writes[path] = bytes
    Ok(())
  })
  let report = InvalidFuzzFailureReport::new(
    "validate-invalid-binary",
    "smoke",
    0x1053UL,
    1,
    "timeout-fixture",
    invalid_fuzz_binary_source_kind(),
    "timeout",
    actual_stage="timeout",
    actual_diagnostic_location=Some("adapter:wasm-tools"),
    timeout_budget_ms=Some(250),
    artifacts=[InvalidFuzzArtifact::new("partial", "partial.wasm", b"\x00asm")],
  )
  let (meta_path, _) = match persist_invalid_fuzz_failure_report(report, io) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let meta_text = match writes.get(meta_path) {
    Some(v) => invalid_repro_test_bytes_to_ascii(v)
    None => fail("missing timeout metadata")
  }
  assert_true(meta_text.contains("actual_stage=timeout"))
  assert_true(
    meta_text.contains("actual_diagnostic_location=adapter:wasm-tools"),
  )
  assert_true(meta_text.contains("timeout_budget_ms=250"))
  let parsed = match
    parse_invalid_fuzz_failure_report(meta_text, fn(_) { Ok(b"") }) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(parsed.actual_stage, "timeout")
  @debug.assert_eq(parsed.timeout_budget_ms, Some(250))
}

///|
test "FUZ1053B2 timeout repro persists manifest when partial artifact write fails" {
  let writes : Map[String, Bytes] = {}
  let io = InvalidFuzzPersistIO::new(ensure_dir=fn(_) { Ok(()) }, write_file=fn(
    path,
    bytes,
  ) {
    if path.contains("partial.wasm") {
      Err("disk quota")
    } else {
      writes[path] = bytes
      Ok(())
    }
  })
  let report = InvalidFuzzFailureReport::new(
    "validate-invalid-binary",
    "smoke",
    0x1053UL,
    2,
    "timeout-fixture",
    invalid_fuzz_binary_source_kind(),
    "timeout",
    actual_stage="timeout",
    timeout_budget_ms=Some(100),
    artifacts=[InvalidFuzzArtifact::new("partial", "partial.wasm", b"bad")],
  )
  let (meta_path, artifact_paths) = match
    persist_invalid_fuzz_failure_report(report, io) {
    Ok(v) => v
    Err(msg) =>
      fail(
        "expected partial timeout artifact persistence to keep metadata: \{msg}",
      )
  }
  @debug.assert_eq(artifact_paths.length(), 0)
  let meta_text = match writes.get(meta_path) {
    Some(v) => invalid_repro_test_bytes_to_ascii(v)
    None => fail("missing partial timeout metadata")
  }
  assert_true(meta_text.contains("timeout_budget_ms=100"))
  assert_true(
    meta_text.contains("partial_artifact_write_failure=partial.wasm|disk quota"),
  )
}

///|
test "parse_invalid_fuzz_failure_report roundtrips persisted artifacts" {
  let writes : Map[String, Bytes] = {}
  let io = InvalidFuzzPersistIO::new(ensure_dir=fn(_) { Ok(()) }, write_file=fn(
    path,
    bytes,
  ) {
    writes[path] = bytes
    Ok(())
  })
  let original = match invalid_repro_test_original_text_report() {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let report = InvalidFuzzFailureReport::new(
    "validate-invalid-text",
    "smoke",
    0x5eedUL,
    3,
    "invalid-result-stack",
    invalid_fuzz_text_source_kind(),
    "validate-rejected",
    actual_stage="validate-rejected",
    actual_diagnostic_location=Some("text:invalid-result-stack.wast:1:35"),
    source_path=original.source_path,
    artifacts=original.artifacts,
    reduced_artifacts=[
      InvalidFuzzArtifact::new(
        "reduced",
        "reduced.wast",
        invalid_repro_test_string_bytes(
          "(assert_invalid (module (func (result i32) nop)) \"type mismatch\")",
        ),
      ),
    ],
  )
  let (_, artifact_paths) = match
    persist_invalid_fuzz_failure_report(report, io) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let meta_text = match
    writes.get(
      "fuzz-corpus/invalid/validate-invalid-text/invalid-result-stack/seed-24301-attempt-3/repro.meta.txt",
    ) {
    Some(v) => invalid_repro_test_bytes_to_ascii(v)
    None => fail("missing persisted metadata")
  }
  let parsed = match
    parse_invalid_fuzz_failure_report(meta_text, fn(name) {
      for path in artifact_paths {
        if path.contains("/" + name) {
          match writes.get(path) {
            Some(v) => return Ok(v)
            None => ()
          }
        }
      }
      Err("missing artifact " + name)
    }) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(parsed.suite, "validate-invalid-text")
  @debug.assert_eq(parsed.strategy_id, "invalid-result-stack")
  @debug.assert_eq(invalid_fuzz_source_kind_name(parsed.source_kind), "text")
  @debug.assert_eq(parsed.seed_profile, None)
  @debug.assert_eq(parsed.seed_mode, None)
  @debug.assert_eq(parsed.seed_require_strategy_prereqs, None)
  @debug.assert_eq(
    parsed.actual_diagnostic_location,
    Some("text:invalid-result-stack.wast:1:35"),
  )
  assert_true(
    meta_text.contains(
      "actual_diagnostic_location=text:invalid-result-stack.wast:1:35",
    ),
  )
  @debug.assert_eq(parsed.artifacts.length(), 1)
  @debug.assert_eq(parsed.reduced_artifacts.length(), 1)
}

///|
test "dynamic valid-before-link repro persists link outcome metadata separately" {
  let writes : Map[String, Bytes] = {}
  let io = InvalidFuzzPersistIO::new(ensure_dir=fn(_) { Ok(()) }, write_file=fn(
    path,
    bytes,
  ) {
    writes[path] = bytes
    Ok(())
  })
  let report = match
    build_invalid_fuzz_dynamic_text_failure_report_by_stable_id(
      "dynamic-gen-valid-unknown-import", 0x5eedUL, 7,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(report.suite, "validate-invalid-text-dynamic")
  @debug.assert_eq(report.actual_stage, "valid-before-link")
  @debug.assert_eq(report.valid_before_link, Some(true))
  @debug.assert_eq(
    report.source_feature_facts.contains("mutation:unknown-import"),
    true,
  )
  let (_, artifact_paths) = match
    persist_invalid_fuzz_failure_report(report, io) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let meta_text = match
    writes.get(
      "fuzz-corpus/invalid/validate-invalid-text-dynamic/dynamic-gen-valid-unknown-import/seed-24301-attempt-7/repro.meta.txt",
    ) {
    Some(v) => invalid_repro_test_bytes_to_ascii(v)
    None => fail("missing persisted metadata")
  }
  assert_true(meta_text.contains("actual_stage=valid-before-link"))
  assert_true(meta_text.contains("valid_before_link=true"))
  assert_true(meta_text.contains("source_feature_fact=mutation:unknown-import"))
  let parsed = match
    parse_invalid_fuzz_failure_report(meta_text, fn(name) {
      for path in artifact_paths {
        if path.contains("/" + name) {
          match writes.get(path) {
            Some(v) => return Ok(v)
            None => ()
          }
        }
      }
      Err("missing artifact " + name)
    }) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(parsed.valid_before_link, Some(true))
  @debug.assert_eq(
    parsed.source_feature_facts.contains("mutation:unknown-import"),
    true,
  )
}

///|
test "FUZ1055B4 unlinkable repro persists link classifier metadata separately" {
  let writes : Map[String, Bytes] = {}
  let io = InvalidFuzzPersistIO::new(ensure_dir=fn(_) { Ok(()) }, write_file=fn(
    path,
    bytes,
  ) {
    writes[path] = bytes
    Ok(())
  })
  let report = build_fuz1055b4_unlinkable_failure_report(0x1055B4UL, 2)
  @debug.assert_eq(report.actual_stage, "valid-before-link")
  @debug.assert_eq(report.valid_before_link, Some(true))
  @debug.assert_eq(report.unlinkable_reason, Some("incompatible import type"))
  @debug.assert_eq(report.registered_module_name, Some("provider"))
  @debug.assert_eq(report.import_module_name, Some("provider"))
  @debug.assert_eq(report.import_name, Some("mem"))
  @debug.assert_eq(report.expected_import_type, Some("memory(2 5)"))
  @debug.assert_eq(report.provider_export_type, Some("memory(1)"))
  @debug.assert_eq(report.pre_link_validation_status, Some("valid-before-link"))
  let (_, artifact_paths) = match
    persist_invalid_fuzz_failure_report(report, io) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let meta_text = match
    writes.get(
      "fuzz-corpus/invalid/valid-multi-module-linking/unlinkable-multi-module/seed-1070516-attempt-2/repro.meta.txt",
    ) {
    Some(v) => invalid_repro_test_bytes_to_ascii(v)
    None => fail("missing persisted FUZ1055B4 metadata")
  }
  assert_true(meta_text.contains("unlinkable_reason=incompatible import type"))
  assert_true(meta_text.contains("registered_module_name=provider"))
  assert_true(meta_text.contains("import_module_name=provider"))
  assert_true(meta_text.contains("import_name=mem"))
  assert_true(meta_text.contains("expected_import_type=memory(2 5)"))
  assert_true(meta_text.contains("provider_export_type=memory(1)"))
  assert_true(
    meta_text.contains("pre_link_validation_status=valid-before-link"),
  )
  let parsed = match
    parse_invalid_fuzz_failure_report(meta_text, fn(name) {
      for path in artifact_paths {
        if path.contains("/" + name) {
          match writes.get(path) {
            Some(v) => return Ok(v)
            None => ()
          }
        }
      }
      Err("missing artifact " + name)
    }) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(parsed.unlinkable_reason, Some("incompatible import type"))
  @debug.assert_eq(parsed.import_name, Some("mem"))
  @debug.assert_eq(parsed.provider_export_type, Some("memory(1)"))
}

///|
test "FUZ1055B4 generic repro dispatcher builds unlinkable report" {
  let report = match
    build_invalid_fuzz_failure_report_by_suite_and_stable_id(
      "valid-multi-module-linking", "unlinkable-multi-module", 0x1055B4UL, 9,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(report.actual_stage, "valid-before-link")
  @debug.assert_eq(report.unlinkable_reason, Some("incompatible import type"))
  @debug.assert_eq(report.pre_link_validation_status, Some("valid-before-link"))
  match
    build_invalid_fuzz_failure_report_by_suite_and_stable_id(
      "valid-multi-module-linking", "not-unlinkable-multi-module", 0x1055B4UL, 9,
    ) {
    Ok(_) => fail("expected unknown multi-module strategy to fail")
    Err(msg) =>
      assert_true(msg.contains("unknown multi-module invalid strategy"))
  }
}

///|
test "parse_invalid_fuzz_failure_report roundtrips persisted seed metadata" {
  let writes : Map[String, Bytes] = {}
  let io = InvalidFuzzPersistIO::new(ensure_dir=fn(_) { Ok(()) }, write_file=fn(
    path,
    bytes,
  ) {
    writes[path] = bytes
    Ok(())
  })
  let report = match
    build_invalid_fuzz_binary_failure_report_by_stable_id(
      "trailing-garbage",
      0x5eedUL,
      33,
      params=Some(
        GenInvalidBinaryParams::repro_seed(
          TrailingGarbage,
          require_strategy_prereqs=false,
        ),
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let (_, artifact_paths) = match
    persist_invalid_fuzz_failure_report(report, io) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let meta_text = match
    writes.get(
      "fuzz-corpus/invalid/validate-invalid-binary/trailing-garbage/seed-24301-attempt-33/repro.meta.txt",
    ) {
    Some(v) => invalid_repro_test_bytes_to_ascii(v)
    None => fail("missing persisted metadata")
  }
  assert_true(meta_text.contains("seed_profile=repro"))
  assert_true(meta_text.contains("seed_mode=random-valid"))
  assert_true(meta_text.contains("seed_require_strategy_prereqs=false"))
  assert_true(meta_text.contains("stream_label=invalid-mutation-choice"))
  assert_true(meta_text.contains("stream_seed="))
  assert_true(meta_text.contains("attempt_seed="))
  let parsed = match
    parse_invalid_fuzz_failure_report(meta_text, fn(name) {
      for path in artifact_paths {
        if path.contains("/" + name) {
          match writes.get(path) {
            Some(v) => return Ok(v)
            None => ()
          }
        }
      }
      Err("missing artifact " + name)
    }) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(parsed.seed_profile, Some("repro"))
  @debug.assert_eq(parsed.seed_mode, Some("random-valid"))
  @debug.assert_eq(parsed.seed_require_strategy_prereqs, Some(false))
  @debug.assert_eq(parsed.stream_label, Some("invalid-mutation-choice"))
  @debug.assert_eq(parsed.stream_seed, report.stream_seed)
  @debug.assert_eq(parsed.attempt_seed, report.attempt_seed)
}

///|
test "build_invalid_fuzz_ast_failure_report_by_stable_id records invalid mutation stream metadata" {
  let report = match
    build_invalid_fuzz_ast_failure_report_by_stable_id(
      "duplicate-export-name", 0x51034UL, 12,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(report.stream_label, Some("invalid-mutation-choice"))
  match report.stream_seed {
    Some(v) => assert_true(v != 0x51034UL)
    None => fail("missing invalid mutation stream seed")
  }
  match report.attempt_seed {
    Some(v) => assert_true(v != report.stream_seed.unwrap())
    None => fail("missing invalid mutation attempt seed")
  }
}

///|
test "build_invalid_fuzz_ast_failure_report_by_stable_id supports minimal valid seeds" {
  let spec = match
    @validate.validate_invalid_ast_strategy_by_stable_id(
      "invalid-start-signature",
    ) {
    Some(v) => v
    None => fail("missing AST invalid strategy")
  }
  let report = match
    build_invalid_fuzz_ast_failure_report_by_stable_id(
      "invalid-start-signature",
      0x5eedUL,
      9,
      params=Some(@validate.GenInvalidAstParams::minimal_seed(spec.id)),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(report.actual_stage, "validate-rejected")
  @debug.assert_eq(report.actual_diagnostic_family, Some("start"))
  @debug.assert_eq(report.artifacts.length(), 2)
  @debug.assert_eq(report.artifacts[0].label, "original")
  @debug.assert_eq(report.artifacts[1].label, "seed")
}

///|
test "build_invalid_fuzz_binary_failure_report_by_stable_id supports minimal valid seeds" {
  let spec = match
    validate_invalid_binary_strategy_by_stable_id("trailing-garbage") {
    Some(v) => v
    None => fail("missing binary invalid strategy")
  }
  let report = match
    build_invalid_fuzz_binary_failure_report_by_stable_id(
      "trailing-garbage",
      0x5eedUL,
      10,
      params=Some(GenInvalidBinaryParams::minimal_seed(spec.id)),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(report.actual_stage, "decode-rejected")
  @debug.assert_eq(report.actual_diagnostic_family, None)
  @debug.assert_eq(report.artifacts.length(), 2)
  @debug.assert_eq(report.artifacts[0].label, "original")
  @debug.assert_eq(report.artifacts[1].label, "seed")
}

///|
test "default AST invalid report builder uses a compact coverage seed" {
  let spec = match
    @validate.validate_invalid_ast_strategy_by_stable_id(
      "duplicate-export-name",
    ) {
    Some(v) => v
    None => fail("missing AST invalid strategy")
  }
  let compact = match
    build_invalid_fuzz_ast_failure_report_by_stable_id(
      "duplicate-export-name", 0x5eedUL, 11,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let full = match
    build_invalid_fuzz_ast_failure_report_by_stable_id(
      "duplicate-export-name",
      0x5eedUL,
      11,
      params=Some(@validate.GenInvalidAstParams::coverage_forced_seed(spec.id)),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(compact.actual_stage, "validate-rejected")
  @debug.assert_eq(compact.actual_diagnostic_family, Some("export"))
  @debug.assert_eq(compact.seed_profile, Some("repro"))
  @debug.assert_eq(compact.seed_mode, Some("random-valid"))
  @debug.assert_eq(compact.seed_require_strategy_prereqs, Some(true))
  @debug.assert_eq(compact.artifacts.length(), 2)
  assert_true(
    compact.artifacts[1].bytes.length() < full.artifacts[1].bytes.length(),
  )
}

///|
test "build_invalid_fuzz_ast_failure_report_by_stable_id supports natural seeds" {
  let spec = match
    @validate.validate_invalid_ast_strategy_by_stable_id(
      "duplicate-export-name",
    ) {
    Some(v) => v
    None => fail("missing AST invalid strategy")
  }
  let report = match
    build_invalid_fuzz_ast_failure_report_by_stable_id(
      "duplicate-export-name",
      0x5eedUL,
      12,
      params=Some(@validate.GenInvalidAstParams::natural_seed(spec.id)),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(report.actual_stage, "validate-rejected")
  @debug.assert_eq(report.actual_diagnostic_family, Some("export"))
  @debug.assert_eq(report.seed_profile, Some("natural"))
  @debug.assert_eq(report.seed_mode, Some("random-valid"))
  @debug.assert_eq(report.seed_require_strategy_prereqs, Some(true))
  @debug.assert_eq(report.artifacts.length(), 2)
}

///|
test "build_invalid_fuzz_ast_failure_report_by_stable_id records prereq opt-out metadata" {
  let spec = match
    @validate.validate_invalid_ast_strategy_by_stable_id(
      "duplicate-export-name",
    ) {
    Some(v) => v
    None => fail("missing AST invalid strategy")
  }
  let report = match
    build_invalid_fuzz_ast_failure_report_by_stable_id(
      "duplicate-export-name",
      0x5eedUL,
      12,
      params=Some(
        @validate.GenInvalidAstParams::repro_seed(
          spec.id,
          require_strategy_prereqs=false,
        ),
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(report.seed_profile, Some("repro"))
  @debug.assert_eq(report.seed_mode, Some("random-valid"))
  @debug.assert_eq(report.seed_require_strategy_prereqs, Some(false))
}

///|
test "default binary invalid report builder uses a compact coverage seed" {
  let spec = match
    validate_invalid_binary_strategy_by_stable_id("invalid-func-type-index") {
    Some(v) => v
    None => fail("missing binary invalid strategy")
  }
  let compact = match
    build_invalid_fuzz_binary_failure_report_by_stable_id(
      "invalid-func-type-index", 0x5eedUL, 13,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let full = match
    build_invalid_fuzz_binary_failure_report_by_stable_id(
      "invalid-func-type-index",
      0x5eedUL,
      13,
      params=Some(GenInvalidBinaryParams::coverage_forced_seed(spec.id)),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(compact.actual_stage, "validate-rejected")
  @debug.assert_eq(compact.actual_diagnostic_family, Some("function"))
  @debug.assert_eq(compact.seed_profile, Some("repro"))
  @debug.assert_eq(compact.seed_mode, Some("random-valid"))
  @debug.assert_eq(compact.seed_require_strategy_prereqs, Some(true))
  @debug.assert_eq(compact.artifacts.length(), 2)
  assert_true(
    compact.artifacts[1].bytes.length() < full.artifacts[1].bytes.length(),
  )
}

///|
test "build_invalid_fuzz_binary_failure_report_by_stable_id supports coverage-forced seeds" {
  let spec = match
    validate_invalid_binary_strategy_by_stable_id("invalid-func-type-index") {
    Some(v) => v
    None => fail("missing binary invalid strategy")
  }
  let report = match
    build_invalid_fuzz_binary_failure_report_by_stable_id(
      "invalid-func-type-index",
      0x5eedUL,
      14,
      params=Some(GenInvalidBinaryParams::coverage_forced_seed(spec.id)),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(report.actual_stage, "validate-rejected")
  @debug.assert_eq(report.actual_diagnostic_family, Some("function"))
  @debug.assert_eq(report.seed_profile, Some("coverage-forced"))
  @debug.assert_eq(report.seed_mode, Some("random-valid"))
  @debug.assert_eq(report.seed_require_strategy_prereqs, Some(true))
  @debug.assert_eq(report.artifacts.length(), 2)
}

///|
test "build_invalid_fuzz_binary_failure_report_by_stable_id records prereq opt-out metadata" {
  let spec = match
    validate_invalid_binary_strategy_by_stable_id("trailing-garbage") {
    Some(v) => v
    None => fail("missing binary invalid strategy")
  }
  let report = match
    build_invalid_fuzz_binary_failure_report_by_stable_id(
      "trailing-garbage",
      0x5eedUL,
      14,
      params=Some(
        GenInvalidBinaryParams::repro_seed(
          spec.id,
          require_strategy_prereqs=false,
        ),
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(report.seed_profile, Some("repro"))
  @debug.assert_eq(report.seed_mode, Some("random-valid"))
  @debug.assert_eq(report.seed_require_strategy_prereqs, Some(false))
}

///|
test "build_invalid_fuzz_text_failure_report_by_stable_id preserves source path and stage" {
  let report = match
    build_invalid_fuzz_text_failure_report_by_stable_id(
      "invalid-result-stack", 0x5eedUL, 11,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(report.actual_stage, "validate-rejected")
  @debug.assert_eq(
    report.source_path,
    Some("inline-text-invalid/invalid-result-stack.wast"),
  )
  @debug.assert_eq(report.artifacts.length(), 1)
}

///|
test "build_invalid_fuzz_spec_seed_failure_report_by_stable_id preserves source path and stage" {
  let report = match
    build_invalid_fuzz_spec_seed_failure_report_by_stable_id(
      "imports-unlinkable-unknown-import-1", 0x5eedUL, 12,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(report.actual_stage, "valid-before-link")
  @debug.assert_eq(report.source_path, Some("tests/spec/imports.wast"))
  @debug.assert_eq(report.artifacts.length(), 1)
}

///|
test "build_invalid_fuzz_failure_report_by_suite_and_stable_id accepts suite aliases" {
  let ast = match
    build_invalid_fuzz_failure_report_by_suite_and_stable_id(
      "ast", "duplicate-export-name", 0x5eedUL, 41,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(ast.suite, "validate-invalid-ast")
  assert_true(ast.source_kind == invalid_fuzz_ast_source_kind())
  let binary = match
    build_invalid_fuzz_failure_report_by_suite_and_stable_id(
      "binary", "trailing-garbage", 0x5eedUL, 42,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(binary.suite, "validate-invalid-binary")
  assert_true(binary.source_kind == invalid_fuzz_binary_source_kind())
}

///|
test "build_invalid_fuzz_failure_report_by_suite_and_stable_id rejects unknown suites" {
  match
    build_invalid_fuzz_failure_report_by_suite_and_stable_id(
      "nope", "duplicate-export-name", 0x5eedUL, 43,
    ) {
    Ok(_) => fail("expected unknown suite error")
    Err(msg) => assert_true(msg.contains("unknown invalid fuzz suite"))
  }
}

///|
test "replay_invalid_fuzz_failure_report prefers original artifact over later seed artifacts" {
  let report = match invalid_repro_test_original_binary_report() {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let reordered = InvalidFuzzFailureReport::new(
    report.suite,
    report.profile,
    report.seed,
    report.attempt,
    report.strategy_id,
    report.source_kind,
    report.expected_stage,
    expected_diagnostic_family=report.expected_diagnostic_family,
    actual_stage=report.actual_stage,
    actual_diagnostic_family=report.actual_diagnostic_family,
    source_path=report.source_path,
    artifacts=[report.artifacts[1], report.artifacts[0]],
    reduced_artifacts=report.reduced_artifacts,
  )
  let replay = match
    replay_invalid_fuzz_failure_report(reordered, prefer_reduced=false) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(replay.stage, "validate-rejected")
  @debug.assert_eq(replay.diagnostic_family, Some("function"))
}

///|
test "shared reducer predicates classify stage and family metadata" {
  let report = match invalid_repro_test_original_binary_report() {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let predicate = fuzz_reduction_predicate_from_invalid_report(report)
  @debug.assert_eq(
    fuzz_reduction_failure_kind_name(predicate.kind),
    "validation-failure",
  )
  @debug.assert_eq(predicate.expected_stage, "validate-rejected")
  @debug.assert_eq(predicate.expected_family, Some("function"))
  let replay = FuzzReductionReplayResult::new(
    "validate-rejected",
    family=Some("function"),
    message=Some("func type index out of range"),
  )
  assert_true(fuzz_reduction_predicate_matches(predicate, replay))
  let wrong = FuzzReductionReplayResult::new(
    "validate-rejected",
    family=Some("table"),
  )
  assert_false(fuzz_reduction_predicate_matches(predicate, wrong))
}

///|
test "shared reducer predicates cover parser failures mismatches crashes timeouts and property failures" {
  let parser = FuzzReductionPredicate::new(
    ParseFailure,
    "parse-or-lower-rejected",
  )
  assert_true(
    fuzz_reduction_predicate_matches(
      parser,
      FuzzReductionReplayResult::new("parse-or-lower-rejected"),
    ),
  )
  let mismatch = FuzzReductionPredicate::new(
    PassMismatch,
    "mismatch",
    property=Some("normalized-output"),
  )
  assert_true(
    fuzz_reduction_predicate_matches(
      mismatch,
      FuzzReductionReplayResult::new(
        "mismatch",
        property=Some("normalized-output"),
      ),
    ),
  )
  assert_false(
    fuzz_reduction_predicate_matches(
      mismatch,
      FuzzReductionReplayResult::new("mismatch", property=Some("raw-output")),
    ),
  )
  @debug.assert_eq(fuzz_reduction_failure_kind_name(Crash), "crash")
  @debug.assert_eq(fuzz_reduction_failure_kind_name(Timeout), "timeout")
  @debug.assert_eq(
    fuzz_reduction_failure_kind_name(PropertyFailure),
    "property-failure",
  )
}

///|
test "shrink_invalid_fuzz_failure_report produces replayable AST reduced artifact" {
  let report = match invalid_repro_test_original_ast_report() {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let shrunk = match shrink_invalid_fuzz_failure_report(report) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(shrunk.reduced_artifacts.length(), 1)
  assert_true(
    shrunk.reduced_artifacts[0].bytes.length() <
    shrunk.artifacts[0].bytes.length(),
  )
  let replay = match replay_invalid_fuzz_failure_report(shrunk) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(replay.stage, "validate-rejected")
  @debug.assert_eq(replay.diagnostic_family, Some("export"))
}

///|
test "shrink_invalid_fuzz_failure_report produces replayable binary reduced artifact" {
  let report = match invalid_repro_test_original_binary_report() {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let shrunk = match shrink_invalid_fuzz_failure_report(report) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(shrunk.reduced_artifacts.length(), 1)
  assert_true(
    shrunk.reduced_artifacts[0].bytes.length() <=
    shrunk.artifacts[0].bytes.length(),
  )
  let replay = match replay_invalid_fuzz_failure_report(shrunk) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(replay.stage, "validate-rejected")
  @debug.assert_eq(replay.diagnostic_family, Some("function"))
}

///|
test "shrink_invalid_fuzz_failure_report produces replayable inline text reduced artifact" {
  let report = match invalid_repro_test_original_text_report() {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let shrunk = match shrink_invalid_fuzz_failure_report(report) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(shrunk.reduced_artifacts.length(), 1)
  let replay = match replay_invalid_fuzz_failure_report(shrunk) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(replay.stage, "validate-rejected")
  @debug.assert_eq(replay.diagnostic_family, None)
}

///|
test "shrink_invalid_fuzz_failure_report produces replayable spec-seed reduced artifact" {
  let report = match invalid_repro_test_original_spec_seed_report() {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let shrunk = match shrink_invalid_fuzz_failure_report(report) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(shrunk.reduced_artifacts.length(), 1)
  assert_true(
    shrunk.reduced_artifacts[0].bytes.length() <
    shrunk.artifacts[0].bytes.length(),
  )
  let replay = match replay_invalid_fuzz_failure_report(shrunk) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(replay.stage, "valid-before-link")
  @debug.assert_eq(replay.diagnostic_family, None)
}
