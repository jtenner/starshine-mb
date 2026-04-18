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
  assert_eq(ensured_dirs, [
    "tmp-invalid-corpus", "tmp-invalid-corpus/validate-invalid-binary", "tmp-invalid-corpus/validate-invalid-binary/invalid-func-type-index",
    "tmp-invalid-corpus/validate-invalid-binary/invalid-func-type-index/seed-24301-attempt-2",
  ])
  assert_eq(
    meta_path, "tmp-invalid-corpus/validate-invalid-binary/invalid-func-type-index/seed-24301-attempt-2/repro.meta.txt",
  )
  assert_eq(artifact_paths, [
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
      assert_true(text.contains("artifact=original|original.wasm"))
      assert_true(text.contains("artifact=seed|seed.wasm"))
      assert_true(text.contains("reduced=reduced|reduced.wasm"))
    }
  }
  assert_true(saw_meta)
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
  assert_eq(parsed.suite, "validate-invalid-text")
  assert_eq(parsed.strategy_id, "invalid-result-stack")
  assert_eq(invalid_fuzz_source_kind_name(parsed.source_kind), "text")
  assert_eq(parsed.artifacts.length(), 1)
  assert_eq(parsed.reduced_artifacts.length(), 1)
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
  assert_eq(report.actual_stage, "validate-rejected")
  assert_eq(report.actual_diagnostic_family, Some("start"))
  assert_eq(report.artifacts.length(), 2)
  assert_eq(report.artifacts[0].label, "original")
  assert_eq(report.artifacts[1].label, "seed")
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
  assert_eq(report.actual_stage, "decode-rejected")
  assert_eq(report.actual_diagnostic_family, None)
  assert_eq(report.artifacts.length(), 2)
  assert_eq(report.artifacts[0].label, "original")
  assert_eq(report.artifacts[1].label, "seed")
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
  assert_eq(report.actual_stage, "validate-rejected")
  assert_eq(
    report.source_path,
    Some("inline-text-invalid/invalid-result-stack.wast"),
  )
  assert_eq(report.artifacts.length(), 1)
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
  assert_eq(report.actual_stage, "valid-before-link")
  assert_eq(report.source_path, Some("tests/spec/imports.wast"))
  assert_eq(report.artifacts.length(), 1)
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
  assert_eq(shrunk.reduced_artifacts.length(), 1)
  assert_true(
    shrunk.reduced_artifacts[0].bytes.length() <
    shrunk.artifacts[0].bytes.length(),
  )
  let replay = match replay_invalid_fuzz_failure_report(shrunk) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  assert_eq(replay.stage, "validate-rejected")
  assert_eq(replay.diagnostic_family, Some("export"))
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
  assert_eq(shrunk.reduced_artifacts.length(), 1)
  assert_true(
    shrunk.reduced_artifacts[0].bytes.length() <=
    shrunk.artifacts[0].bytes.length(),
  )
  let replay = match replay_invalid_fuzz_failure_report(shrunk) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  assert_eq(replay.stage, "validate-rejected")
  assert_eq(replay.diagnostic_family, Some("function"))
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
  assert_eq(shrunk.reduced_artifacts.length(), 1)
  let replay = match replay_invalid_fuzz_failure_report(shrunk) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  assert_eq(replay.stage, "validate-rejected")
  assert_eq(replay.diagnostic_family, None)
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
  assert_eq(shrunk.reduced_artifacts.length(), 1)
  assert_true(
    shrunk.reduced_artifacts[0].bytes.length() <
    shrunk.artifacts[0].bytes.length(),
  )
  let replay = match replay_invalid_fuzz_failure_report(shrunk) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  assert_eq(replay.stage, "valid-before-link")
  assert_eq(replay.diagnostic_family, None)
}
