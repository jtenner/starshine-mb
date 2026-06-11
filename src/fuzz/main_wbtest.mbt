///|
test "fuzz interestingness schema exposes stable ordered hash layers" {
  let schema = fuzz_interestingness_hash_schema()
  @debug.assert_eq(schema.schema_id, "starshine.fuzz-interestingness.v1")
  @debug.assert_eq(schema.layers.length(), 6)
  @debug.assert_eq(schema.layers[0].name, "raw")
  @debug.assert_eq(schema.layers[1].name, "decoded-shape")
  @debug.assert_eq(schema.layers[2].name, "feature-fact")
  @debug.assert_eq(schema.layers[3].name, "normalized")
  @debug.assert_eq(schema.layers[4].name, "predicate")
  @debug.assert_eq(schema.layers[5].name, "reduced-artifact")
  @debug.assert_eq(schema.layers[0].digest, "fnv1a64-hex")
  assert_true(schema.layers[0].description.contains("original specimen bytes"))
  assert_true(schema.layers[4].description.contains("oracle outcome"))
}

///|
test "fuzz interestingness case key keeps all schema hashes reversible" {
  let key = FuzzInterestingnessCaseKey::new(
    "raw:0011", "decoded:module-func", "features:gc+simd", "norm:abcd", "pred:pass-mismatch",
    "reduced:tiny",
  )
  @debug.assert_eq(key.raw_hash, "raw:0011")
  @debug.assert_eq(key.decoded_shape_hash, "decoded:module-func")
  @debug.assert_eq(key.feature_fact_hash, "features:gc+simd")
  @debug.assert_eq(key.normalized_hash, "norm:abcd")
  @debug.assert_eq(key.predicate_hash, "pred:pass-mismatch")
  @debug.assert_eq(key.reduced_artifact_hash, "reduced:tiny")
}

///|
test "build_fuzz_corpus_hash_metadata derives deterministic artifact predicate and feature hashes" {
  let first = build_fuzz_corpus_hash_metadata(
    fuzz_string_to_bytes("(module (func))"),
    reduced_artifact=Some(fuzz_string_to_bytes("(module)")),
    "pass=vacuum classification=semantic-mismatch",
    ["simd", "gc", "memory64"],
    "semantic-mismatch",
  )
  let second = build_fuzz_corpus_hash_metadata(
    fuzz_string_to_bytes("(module (func))"),
    reduced_artifact=Some(fuzz_string_to_bytes("(module)")),
    "pass=vacuum classification=semantic-mismatch",
    ["memory64", "simd", "gc"],
    "semantic-mismatch",
  )
  @debug.assert_eq(first, second)
  assert_true(first.raw_artifact_hash.contains("fnv1a64-"))
  assert_true(first.reduced_artifact_hash.contains("fnv1a64-"))
  assert_true(first.predicate_hash.contains("fnv1a64-"))
  assert_true(first.feature_fact_hash.contains("fnv1a64-"))
  @debug.assert_eq(first.interestingness_label, "semantic-mismatch")
  assert_true(first.raw_artifact_hash != first.reduced_artifact_hash)
}

///|
test "FUZ1050D1 fuzz corpus case index roundtrips duplicate raw reduced and normalized-shape hashes" {
  let first = FuzzCorpusPromotionMetadata::new(
    "case-a",
    "pass-mismatch",
    "pass-fuzz seed 1",
    "cases/a/raw.wasm",
    "2026-05-31",
    "suite=pass-fuzz profile=gen-valid seed=1 seed_index=0",
    ["gc"],
    "must reproduce mismatch",
    "semantic-mismatch",
    "bun scripts/pass-fuzz-compare.ts --seed 1",
    ["cases/a/raw.wasm", "cases/a/reduced.wasm"],
    "[FUZ]1050B",
    "first duplicate fixture",
    raw_artifact_hash="fnv1a64-raw-shared",
    reduced_artifact_hash="fnv1a64-reduced-shared",
    normalized_shape_hash="fnv1a64-normalized-shared",
    predicate_hash="fnv1a64-predicate-a",
    feature_fact_hash="fnv1a64-features-gc",
    interestingness_label="pass-mismatch",
  )
  let second = FuzzCorpusPromotionMetadata::new(
    "case-b",
    "quarantine",
    "pass-fuzz seed 2",
    "cases/b/raw.wasm",
    "2026-05-31",
    "suite=pass-fuzz profile=gen-valid seed=2 seed_index=1",
    ["gc"],
    "may reproduce mismatch",
    "unknown/risky",
    "bun scripts/pass-fuzz-compare.ts --seed 2",
    ["cases/b/raw.wasm", "cases/b/reduced.wasm"],
    "[FUZ]1050B",
    "second duplicate fixture",
    raw_artifact_hash="fnv1a64-raw-shared",
    reduced_artifact_hash="fnv1a64-reduced-shared",
    normalized_shape_hash="fnv1a64-normalized-shared",
    predicate_hash="fnv1a64-predicate-b",
    feature_fact_hash="fnv1a64-features-gc",
    interestingness_label="pass-mismatch",
  )
  let index = build_fuzz_corpus_case_index([first, second])
  @debug.assert_eq(index.entries.length(), 3)
  @debug.assert_eq(index.entries[0].hash_kind, "raw")
  @debug.assert_eq(index.entries[0].case_ids, ["case-a", "case-b"])
  @debug.assert_eq(index.entries[0].seeds, [1UL, 2UL])
  @debug.assert_eq(index.entries[0].profiles, ["gen-valid", "gen-valid"])
  @debug.assert_eq(index.entries[0].artifact_paths, [
    "cases/a/raw.wasm", "cases/b/raw.wasm",
  ])
  @debug.assert_eq(index.entries[1].hash_kind, "reduced")
  @debug.assert_eq(index.entries[1].artifact_paths, [
    "cases/a/reduced.wasm", "cases/b/reduced.wasm",
  ])
  @debug.assert_eq(index.entries[2].hash_kind, "normalized-shape")
  @debug.assert_eq(index.entries[2].hash, "fnv1a64-normalized-shared")
  @debug.assert_eq(index.entries[2].case_ids, ["case-a", "case-b"])
  @debug.assert_eq(index.entries[2].artifact_paths, [
    "cases/a/raw.wasm", "cases/b/raw.wasm",
  ])
  let json = format_fuzz_corpus_case_index_json(index)
  assert_true(
    json.contains("\"schema\":\"starshine.fuzz-corpus-case-index.v1\""),
  )
  assert_true(json.contains("\"hash\":\"fnv1a64-raw-shared\""))
  assert_true(json.contains("\"hash_kind\":\"normalized-shape\""))
  let parsed = match parse_fuzz_corpus_case_index_json(json) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(parsed, index)
}

///|
fn bytes_to_ascii(bytes : Bytes) -> String {
  let out = StringBuilder::new()
  for b in bytes {
    out.write_char(b.to_int().unsafe_to_char())
  }
  out.to_string()
}

///|
test "fuzz corpus dedup dry-run classifies duplicate reduced artifacts but keeps raw originals" {
  let index = FuzzCorpusCaseIndex::new([
    FuzzCorpusCaseIndexEntry::new(
      "raw",
      "fnv1a64-raw-shared",
      ["case-a", "case-b"],
      [1UL, 2UL],
      ["gen-valid", "gen-valid"],
      ["cases/a/raw.wasm", "cases/b/raw.wasm"],
    ),
    FuzzCorpusCaseIndexEntry::new(
      "reduced",
      "fnv1a64-reduced-shared",
      ["case-a", "case-b"],
      [1UL, 2UL],
      ["gen-valid", "gen-valid"],
      ["cases/a/reduced.wasm", "cases/b/reduced.wasm"],
    ),
  ])
  let plan = classify_fuzz_corpus_dedup_dry_run(index)
  @debug.assert_eq(plan.keep_count, 1)
  @debug.assert_eq(plan.duplicate_count, 0)
  @debug.assert_eq(plan.compress_count, 1)
  @debug.assert_eq(plan.decisions.length(), 2)
  @debug.assert_eq(plan.decisions[0].action, "keep")
  assert_true(plan.decisions[0].reason.contains("raw artifacts are originals"))
  @debug.assert_eq(plan.decisions[1].action, "compress")
  assert_true(plan.decisions[1].reason.contains("dry-run only"))
}

///|
test "fuzz corpus dedup dry-run never deletes sole unreduced failure artifact" {
  let index = FuzzCorpusCaseIndex::new([
    FuzzCorpusCaseIndexEntry::new(
      "raw",
      "fnv1a64-raw-only",
      ["case-unreduced"],
      [9UL],
      ["gen-valid"],
      ["cases/unreduced/raw.wasm"],
    ),
  ])
  let plan = classify_fuzz_corpus_dedup_dry_run(index)
  @debug.assert_eq(plan.keep_count, 1)
  @debug.assert_eq(plan.duplicate_count, 0)
  @debug.assert_eq(plan.compress_count, 0)
  @debug.assert_eq(plan.decisions[0].action, "keep")
  assert_true(plan.decisions[0].reason.contains("sole artifact"))
  let json = format_fuzz_corpus_dedup_dry_run_json(plan)
  assert_true(
    json.contains("\"schema\":\"starshine.fuzz-corpus-dedup-dry-run.v1\""),
  )
  assert_true(json.contains("\"action\":\"keep\""))
  assert_true(json.contains("never delete"))
}

///|
test "parse_fuzz_cli_args defaults to all smoke seed" {
  let parsed = parse_fuzz_cli_args([])
  @debug.assert_eq(parsed.suite, "all")
  @debug.assert_eq(parsed.profile, "smoke")
  match parsed.output_mode {
    Text => ()
    _ => fail("expected text output mode")
  }
  @debug.assert_eq(parsed.seed, parsed.seed_i64.reinterpret_as_uint64())
}

///|
test "parse_fuzz_cli_args accepts suite profile and hex seed" {
  let parsed = parse_fuzz_cli_args(["wat-roundtrip", "ci", "0x1234"])
  @debug.assert_eq(parsed.suite, "wat-roundtrip")
  @debug.assert_eq(parsed.profile, "ci")
  @debug.assert_eq(parsed.seed_i64, 0x1234L)
  @debug.assert_eq(parsed.seed, 0x1234UL)
}

///|
test "parse_fuzz_cli_args accepts --seed with equals" {
  let parsed = parse_fuzz_cli_args(["wat-roundtrip", "ci", "--seed=0x99"])
  @debug.assert_eq(parsed.suite, "wat-roundtrip")
  @debug.assert_eq(parsed.profile, "ci")
  @debug.assert_eq(parsed.seed_i64, 0x99L)
}

///|
test "parse_fuzz_cli_args accepts --seed and negative value" {
  let parsed = parse_fuzz_cli_args(["validate-valid", "smoke", "--seed", "-42"])
  @debug.assert_eq(parsed.suite, "validate-valid")
  @debug.assert_eq(parsed.profile, "smoke")
  @debug.assert_eq(parsed.seed_i64, -42L)
  @debug.assert_eq(parsed.seed, (-42L).reinterpret_as_uint64())
}

///|
test "parse_fuzz_cli_args accepts --output=jsonl" {
  let parsed = parse_fuzz_cli_args([
    "validate-valid", "ci", "--seed=0x5eed", "--output=jsonl",
  ])
  match parsed.output_mode {
    Jsonl => ()
    _ => fail("expected jsonl output mode")
  }
}

///|
test "parse_fuzz_cli_args accepts --jsonl alias" {
  let parsed = parse_fuzz_cli_args(["validate-valid", "ci", "--jsonl"])
  match parsed.output_mode {
    Jsonl => ()
    _ => fail("expected jsonl output mode")
  }
}

///|
test "parse_fuzz_cli_args accepts seed sweep, shard, report, and out-dir flags" {
  let parsed = parse_fuzz_cli_args([
    "cmd-harness", "smoke", "--seed=0x10", "--seed-count", "5", "--shard-index",
    "1", "--shard-count", "2", "--report-json", "tmp/fuzz-report.json", "--out-dir",
    "tmp/fuzz-out",
  ])
  @debug.assert_eq(parsed.suite, "cmd-harness")
  @debug.assert_eq(parsed.profile, "smoke")
  @debug.assert_eq(parsed.seed_i64, 0x10L)
  @debug.assert_eq(parsed.seed_count, 5)
  @debug.assert_eq(parsed.shard_index, 1)
  @debug.assert_eq(parsed.shard_count, 2)
  @debug.assert_eq(parsed.report_json_path, Some("tmp/fuzz-report.json"))
  @debug.assert_eq(parsed.out_dir, Some("tmp/fuzz-out"))
}

///|
test "build_fuzz_shard_queue assigns non-overlapping shard metadata and out dirs" {
  let recipe = FuzzRecipe::new(
    "nightly",
    "validate-valid",
    "stress",
    0x5eedL,
    output_mode=Jsonl,
    seed_count=8,
    shard_count=3,
  )
  let queue = match build_fuzz_shard_queue(recipe, Some("tmp/fuzz-nightly")) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(queue.length(), 3)
  @debug.assert_eq(queue[0].name, "nightly-shard-000-of-003")
  @debug.assert_eq(queue[0].suite, "validate-valid")
  @debug.assert_eq(queue[0].profile, "stress")
  @debug.assert_eq(queue[0].seed_i64, 0x5eedL)
  @debug.assert_eq(queue[0].seed_count, 8)
  @debug.assert_eq(queue[0].shard_index, 0)
  @debug.assert_eq(queue[0].shard_count, 3)
  @debug.assert_eq(queue[0].out_dir, Some("tmp/fuzz-nightly/shard-000-of-003"))
  @debug.assert_eq(queue[1].name, "nightly-shard-001-of-003")
  @debug.assert_eq(queue[1].shard_index, 1)
  @debug.assert_eq(queue[1].out_dir, Some("tmp/fuzz-nightly/shard-001-of-003"))
  @debug.assert_eq(queue[2].name, "nightly-shard-002-of-003")
  @debug.assert_eq(queue[2].shard_index, 2)
  @debug.assert_eq(queue[2].out_dir, Some("tmp/fuzz-nightly/shard-002-of-003"))
}

///|
test "build_fuzz_shard_queue rejects empty shard counts" {
  let recipe = FuzzRecipe::new("bad", "cmd-harness", "smoke", 1L, shard_count=0)
  match build_fuzz_shard_queue(recipe, None) {
    Ok(_) => fail("expected shard-count rejection")
    Err(msg) =>
      assert_true(msg.contains("shard-count must be greater than zero"))
  }
}

///|
test "build_fuzz_resume_shard_queue skips completed shard manifests" {
  let recipe = FuzzRecipe::new(
    "nightly",
    "validate-valid",
    "stress",
    0x5eedL,
    output_mode=Jsonl,
    seed_count=8,
    shard_count=3,
  )
  let completed = [
    "{\"schema\":\"starshine.fuzz-output.v1\",\"files\":[\"result.json\",\"cases.jsonl\"]}",
    "{\"schema\":\"starshine.fuzz-output.v1\",\"files\":[\"result.json\",\"cases.jsonl\"]}",
  ]
  let queue = match
    build_fuzz_resume_shard_queue(recipe, Some("tmp/fuzz-nightly"), completed) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(queue.length(), 1)
  @debug.assert_eq(queue[0].name, "nightly-shard-002-of-003")
  @debug.assert_eq(queue[0].shard_index, 2)
  @debug.assert_eq(queue[0].out_dir, Some("tmp/fuzz-nightly/shard-002-of-003"))
}

///|
test "merge_fuzz_shard_results orders cases by seed index then suite" {
  let late = FuzzSuiteResult::{
    suite: "validate-valid",
    profile: "smoke",
    seed: 18L,
    attempts: 1,
    elapsed_ms: 1UL,
    seed_index: 2,
    seed_count: 4,
    shard_index: 0,
    shard_count: 2,
    total_run_budget_ms: None,
    total_run_budget_exceeded: false,
    run_budget_classification: "within-budget",
    details_json: None,
  }
  let early = FuzzSuiteResult::{
    suite: "validate-valid",
    profile: "smoke",
    seed: 17L,
    attempts: 1,
    elapsed_ms: 1UL,
    seed_index: 1,
    seed_count: 4,
    shard_index: 1,
    shard_count: 2,
    total_run_budget_ms: None,
    total_run_budget_exceeded: false,
    run_budget_classification: "within-budget",
    details_json: None,
  }
  let same_seed_other_suite = FuzzSuiteResult::{
    suite: "cmd-harness",
    profile: "smoke",
    seed: 17L,
    attempts: 2,
    elapsed_ms: 1UL,
    seed_index: 1,
    seed_count: 4,
    shard_index: 1,
    shard_count: 2,
    total_run_budget_ms: None,
    total_run_budget_exceeded: false,
    run_budget_classification: "within-budget",
    details_json: None,
  }
  let merged = merge_fuzz_shard_results([[late], [early, same_seed_other_suite]])
  @debug.assert_eq(merged.length(), 3)
  @debug.assert_eq(merged[0].suite, "cmd-harness")
  @debug.assert_eq(merged[0].seed_index, 1)
  @debug.assert_eq(merged[1].suite, "validate-valid")
  @debug.assert_eq(merged[1].seed_index, 1)
  @debug.assert_eq(merged[2].seed_index, 2)
}

///|
test "persist_fuzz_run_output writes result cases and manifest only when requested" {
  let ensured_dirs : Array[String] = []
  let writes : Array[(String, Bytes)] = []
  let io = FuzzRunOutputIO::new(
    ensure_dir=fn(path) {
      ensured_dirs.push(path)
      Ok(())
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let result = FuzzSuiteResult::{
    suite: "cmd-harness",
    profile: "smoke",
    seed: 16L,
    attempts: 3,
    elapsed_ms: 7UL,
    seed_index: 0,
    seed_count: 1,
    shard_index: 0,
    shard_count: 1,
    total_run_budget_ms: None,
    total_run_budget_exceeded: false,
    run_budget_classification: "within-budget",
    details_json: Some("{\"optimized\":3}"),
  }
  match
    persist_fuzz_run_output(
      "tmp/fuzz-out",
      "cmd-harness",
      "smoke",
      16L,
      1,
      0,
      1,
      [result],
      io,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(ensured_dirs, [
    "tmp/fuzz-out", "tmp/fuzz-out/ledgers", "tmp/fuzz-out/replay",
  ])
  @debug.assert_eq(writes.length(), 5)
  let mut saw_result = false
  let mut saw_cases = false
  let mut saw_manifest = false
  let mut saw_suite_ledger = false
  let mut saw_replay_manifest = false
  for entry in writes {
    let path = entry.0
    let text = bytes_to_ascii(entry.1)
    if path == "tmp/fuzz-out/result.json" {
      saw_result = true
      assert_true(text.contains("\"suite\":\"cmd-harness\""))
      assert_true(text.contains("\"run_count\":1"))
    } else if path == "tmp/fuzz-out/cases.jsonl" {
      saw_cases = true
      assert_true(text.contains("\"seed\":16"))
      assert_true(text.contains("\"details\":{\"optimized\":3}"))
    } else if path == "tmp/fuzz-out/manifest.json" {
      saw_manifest = true
      assert_true(text.contains("\"schema\":\"starshine.fuzz-output.v1\""))
      assert_true(text.contains("result.json"))
      assert_true(text.contains("cases.jsonl"))
      assert_true(text.contains("ledgers/cmd-harness-ledger.json"))
      assert_true(text.contains("replay/cmd-harness-replay.json"))
    } else if path == "tmp/fuzz-out/ledgers/cmd-harness-ledger.json" {
      saw_suite_ledger = true
      assert_true(
        text.contains("\"schema\":\"starshine.fuzz-suite-ledger.v1\""),
      )
      assert_true(text.contains("\"suite\":\"cmd-harness\""))
      assert_true(text.contains("\"details\":{\"optimized\":3}"))
    } else if path == "tmp/fuzz-out/replay/cmd-harness-replay.json" {
      saw_replay_manifest = true
      assert_true(
        text.contains("\"schema\":\"starshine.fuzz-replay-manifest.v1\""),
      )
      assert_true(text.contains("\"suite\":\"cmd-harness\""))
      assert_true(text.contains("\"seed\":16"))
      assert_true(text.contains("\"args\":["))
    }
  }
  assert_true(saw_result)
  assert_true(saw_cases)
  assert_true(saw_manifest)
  assert_true(saw_suite_ledger)
  assert_true(saw_replay_manifest)
}

///|
test "FUZ1053C1 total run budget timeout is distinct in result and summary metadata" {
  let base = FuzzSuiteResult::{
    suite: "cmd-harness",
    profile: "smoke",
    seed: 0x1053L,
    attempts: 5,
    elapsed_ms: 150UL,
    seed_index: 0,
    seed_count: 1,
    shard_index: 0,
    shard_count: 1,
    total_run_budget_ms: None,
    total_run_budget_exceeded: false,
    run_budget_classification: "within-budget",
    details_json: Some("{\"cases\":5}"),
  }
  let budgeted = fuzz_suite_result_with_total_run_budget(base, 100UL)
  @debug.assert_eq(budgeted.total_run_budget_ms, Some(100UL))
  @debug.assert_eq(budgeted.total_run_budget_exceeded, true)
  @debug.assert_eq(budgeted.run_budget_classification, "run-budget-timeout")
  let line = format_fuzz_suite_result(budgeted, FuzzOutputMode::Jsonl)
  assert_true(line.contains("\"pass\":false"))
  assert_true(line.contains("\"total_run_budget_ms\":100"))
  assert_true(
    line.contains("\"run_budget_classification\":\"run-budget-timeout\""),
  )
  let report = format_fuzz_run_report_json(
    "cmd-harness",
    "smoke",
    0x1053L,
    1,
    0,
    1,
    [budgeted],
  )
  assert_true(report.contains("\"pass\":false"))
  assert_true(report.contains("\"run-budget-timeout\":1"))
  assert_true(report.contains("\"failures\":1"))
}

///|
test "persist_fuzz_run_output writes validate-valid coverage summary report" {
  let writes : Array[(String, Bytes)] = []
  let io = FuzzRunOutputIO::new(ensure_dir=fn(_) { Ok(()) }, write_file=fn(
    path,
    bytes,
  ) {
    writes.push((path, bytes))
    Ok(())
  })
  let details = "{\"validated\":2,\"feature_stats\":{\"modules\":2,\"imports\":1,\"ref_types\":2,\"v128\":1}}"
  let result = FuzzSuiteResult::{
    suite: "validate-valid",
    profile: "smoke",
    seed: 0x1048BL,
    attempts: 2,
    elapsed_ms: 11UL,
    seed_index: 0,
    seed_count: 1,
    shard_index: 0,
    shard_count: 1,
    total_run_budget_ms: None,
    total_run_budget_exceeded: false,
    run_budget_classification: "within-budget",
    details_json: Some(details),
  }
  match
    persist_fuzz_run_output(
      "tmp/fuzz-valid",
      "validate-valid",
      "smoke",
      0x1048BL,
      1,
      0,
      1,
      [result],
      io,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  let mut saw_summary = false
  let mut saw_manifest_summary = false
  for entry in writes {
    let path = entry.0
    let text = bytes_to_ascii(entry.1)
    if path == "tmp/fuzz-valid/summary.json" {
      saw_summary = true
      assert_true(
        text.contains("\"schema\":\"starshine.fuzz-summary-report.v1\""),
      )
      assert_true(text.contains("\"suite\":\"validate-valid\""))
      assert_true(text.contains("\"seed\":\"0x1048b\""))
      assert_true(text.contains("\"required_modules\":2"))
      assert_true(text.contains("\"required_imports\":1"))
      assert_true(text.contains("\"required_ref_types\":2"))
      assert_true(text.contains("\"required_v128\":1"))
      assert_true(text.contains("\"required_validate_valid\":2"))
      assert_true(text.contains("\"validate-valid\":1"))
      assert_true(text.contains("\"wall_ms\":11"))
      assert_true(text.contains("\"runs\":1"))
    } else if path == "tmp/fuzz-valid/manifest.json" {
      saw_manifest_summary = text.contains("summary.json")
    }
  }
  assert_true(saw_summary)
  assert_true(saw_manifest_summary)
}

///|
test "run_fuzz_suite_sweep derives deterministic shard seeds" {
  let results = match
    run_fuzz_suite_sweep("cmd-harness", "smoke", 10L, 5, 1, 2) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(results.length(), 2)
  @debug.assert_eq(results[0].seed_index, 1)
  @debug.assert_eq(results[0].seed, 11L)
  @debug.assert_eq(results[0].seed_count, 5)
  @debug.assert_eq(results[0].shard_index, 1)
  @debug.assert_eq(results[0].shard_count, 2)
  @debug.assert_eq(results[1].seed_index, 3)
  @debug.assert_eq(results[1].seed, 13L)
}

///|
test "format and parse fuzz corpus promotion metadata states" {
  let states = [
    "promoted-valid", "promoted-invalid", "pass-mismatch", "tool-failure", "accepted-divergence",
    "quarantine",
  ]
  for state in states {
    let entry = FuzzCorpusPromotionMetadata::new(
      "case-\{state}",
      state,
      "validate-valid smoke seed 42",
      "corpus/\{state}/case.wasm",
      "2026-05-31",
      "suite=validate-valid profile=smoke seed=42 attempt=1",
      ["gc", "simd"],
      "must replay recorded outcome",
      "semantic-safe",
      "moon run src/fuzz -- validate-valid smoke --seed 42",
      ["corpus/\{state}/case.wasm", "corpus/\{state}/reduction.txt"],
      "[FUZ]1042B",
      "fixture metadata",
      raw_artifact_hash="fnv1a64-raw-\{state}",
      reduced_artifact_hash="fnv1a64-reduced-\{state}",
      normalized_shape_hash="fnv1a64-normalized-\{state}",
      predicate_hash="fnv1a64-predicate-\{state}",
      feature_fact_hash="fnv1a64-features-\{state}",
      interestingness_label="state-\{state}",
    )
    let json = format_fuzz_corpus_promotion_metadata_json(entry)
    assert_true(json.contains("\"schema\":\"starshine.fuzz-corpus-entry.v1\""))
    assert_true(json.contains("\"state\":\"\{state}\""))
    assert_true(json.contains("\"raw_artifact_hash\":\"fnv1a64-raw-\{state}\""))
    assert_true(
      json.contains("\"normalized_shape_hash\":\"fnv1a64-normalized-\{state}\""),
    )
    let parsed = match parse_fuzz_corpus_promotion_metadata_json(json) {
      Ok(v) => v
      Err(msg) => fail(msg)
    }
    @debug.assert_eq(parsed.id, "case-\{state}")
    @debug.assert_eq(parsed.state, state)
    @debug.assert_eq(parsed.features, ["gc", "simd"])
    @debug.assert_eq(parsed.artifacts.length(), 2)
    @debug.assert_eq(parsed.owner_or_task, "[FUZ]1042B")
    @debug.assert_eq(parsed.raw_artifact_hash, "fnv1a64-raw-\{state}")
    @debug.assert_eq(parsed.reduced_artifact_hash, "fnv1a64-reduced-\{state}")
    @debug.assert_eq(
      parsed.normalized_shape_hash,
      "fnv1a64-normalized-\{state}",
    )
    @debug.assert_eq(parsed.predicate_hash, "fnv1a64-predicate-\{state}")
    @debug.assert_eq(parsed.feature_fact_hash, "fnv1a64-features-\{state}")
    @debug.assert_eq(parsed.interestingness_label, "state-\{state}")
  }
  let escaped = FuzzCorpusPromotionMetadata::new(
    "case-escaped",
    "quarantine",
    "manual",
    "corpus/quarantine/case.wat",
    "2026-05-31",
    "manual generator",
    ["text\\wat"],
    "must preserve \"quoted\" note",
    "unknown/risky",
    "moon run src/fuzz -- validate-invalid-text smoke",
    ["corpus/quarantine/case.wat"],
    "[FUZ]1042B",
    "line one\nline two",
  )
  let escaped_json = format_fuzz_corpus_promotion_metadata_json(escaped)
  let escaped_parsed = match
    parse_fuzz_corpus_promotion_metadata_json(escaped_json) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(escaped_parsed.features, ["text\\wat"])
  @debug.assert_eq(escaped_parsed.expectation, "must preserve \"quoted\" note")
  @debug.assert_eq(escaped_parsed.notes, "line one\nline two")
}

///|
test "build and parse fuzz corpus replay command metadata" {
  let entry = FuzzCorpusPromotionMetadata::new(
    "case-1042c",
    "quarantine",
    "pass-fuzz seed 48879",
    ".tmp/pass-fuzz/case.wasm",
    "2026-05-31",
    "suite=pass-fuzz profile=gen-valid seed=48879 strategy=gen-valid-stack seed_index=7",
    ["gc"],
    "expect semantic mismatch replay",
    "semantic-mismatch",
    "bun scripts/pass-fuzz-compare.ts --pass vacuum --seed 48879 --profile gen-valid",
    [".tmp/pass-fuzz/case.wasm", ".tmp/pass-fuzz/result.json"],
    "[FUZ]1042C",
    "metadata fixture",
  )
  let replay = match build_fuzz_corpus_replay_command_metadata(entry) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(replay.case_id, "case-1042c")
  @debug.assert_eq(replay.suite, "pass-fuzz")
  @debug.assert_eq(replay.profile, "gen-valid")
  @debug.assert_eq(replay.seed, 48879UL)
  @debug.assert_eq(replay.seed_index, 7)
  @debug.assert_eq(replay.strategy_or_artifact, "gen-valid-stack")
  @debug.assert_eq(replay.expected_outcome, "expect semantic mismatch replay")
  @debug.assert_eq(replay.classification, "semantic-mismatch")
  @debug.assert_eq(
    replay.command,
    "bun scripts/pass-fuzz-compare.ts --pass vacuum --seed 48879 --profile gen-valid",
  )
  let json = format_fuzz_corpus_replay_command_metadata_json(replay)
  assert_true(json.contains("\"schema\":\"starshine.fuzz-replay-command.v1\""))
  assert_true(json.contains("\"strategy_or_artifact\":\"gen-valid-stack\""))
  let parsed = match parse_fuzz_corpus_replay_command_metadata_json(json) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(parsed.case_id, "case-1042c")
  @debug.assert_eq(parsed.suite, "pass-fuzz")
  @debug.assert_eq(parsed.profile, "gen-valid")
  @debug.assert_eq(parsed.seed, 48879UL)
  @debug.assert_eq(parsed.seed_index, 7)
  @debug.assert_eq(parsed.strategy_or_artifact, "gen-valid-stack")
  @debug.assert_eq(parsed.expected_outcome, "expect semantic mismatch replay")
  @debug.assert_eq(parsed.classification, "semantic-mismatch")
}

///|
test "build_fuzz_corpus_replay_command_metadata falls back to artifact path" {
  let entry = FuzzCorpusPromotionMetadata::new(
    "case-artifact",
    "promoted-invalid",
    "manual",
    "cases/invalid.wat",
    "2026-05-31",
    "suite=validate-invalid-text profile=smoke seed=42",
    [],
    "must reject",
    "validate-rejected",
    "moon run src/fuzz -- validate-invalid-text smoke --seed 42",
    [],
    "[FUZ]1042C",
    "artifact fallback",
  )
  let replay = match build_fuzz_corpus_replay_command_metadata(entry) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(replay.strategy_or_artifact, "cases/invalid.wat")
  @debug.assert_eq(replay.seed_index, 0)
}

///|
test "plan_fuzz_corpus_replay_manifest reports planned skipped and malformed entries" {
  let promoted = format_fuzz_corpus_promotion_metadata_json(
    FuzzCorpusPromotionMetadata::new(
      "case-promoted",
      "promoted-valid",
      "manual",
      "cases/promoted.wasm",
      "2026-05-31",
      "suite=validate-valid profile=smoke seed=100 seed_index=2",
      [],
      "must validate",
      "valid",
      "moon run src/fuzz -- validate-valid smoke --seed 100",
      [],
      "[FUZ]1042D",
      "promoted fixture",
    ),
  )
  let quarantined = format_fuzz_corpus_promotion_metadata_json(
    FuzzCorpusPromotionMetadata::new(
      "case-quarantine",
      "quarantine",
      "manual",
      "cases/quarantine.wat",
      "2026-05-31",
      "suite=validate-invalid-text profile=smoke seed=101 strategy=bad-wat",
      [],
      "may reject",
      "unknown/risky",
      "moon run src/fuzz -- validate-invalid-text smoke --seed 101",
      ["cases/quarantine.wat"],
      "[FUZ]1042D",
      "quarantine fixture",
    ),
  )
  let missing_seed = format_fuzz_corpus_promotion_metadata_json(
    FuzzCorpusPromotionMetadata::new(
      "case-missing-seed",
      "promoted-invalid",
      "manual",
      "cases/missing-seed.wat",
      "2026-05-31",
      "suite=validate-invalid-text profile=smoke",
      [],
      "must reject",
      "validate-rejected",
      "moon run src/fuzz -- validate-invalid-text smoke",
      [],
      "[FUZ]1042D",
      "missing seed should skip planning",
    ),
  )
  let manifest = "{\"schema\":\"starshine.fuzz-corpus-replay-all-manifest.v1\",\"entries\":[\{promoted},\{quarantined},\{missing_seed},{\"schema\":\"wrong\"}]}"
  let plan = match plan_fuzz_corpus_replay_manifest(manifest) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(plan.planned_count, 2)
  @debug.assert_eq(plan.skipped_count, 1)
  @debug.assert_eq(plan.malformed_count, 1)
  @debug.assert_eq(plan.commands.length(), 2)
  @debug.assert_eq(plan.commands[0].case_id, "case-promoted")
  @debug.assert_eq(plan.commands[0].seed, 100UL)
  @debug.assert_eq(plan.commands[0].seed_index, 2)
  @debug.assert_eq(plan.commands[1].case_id, "case-quarantine")
  @debug.assert_eq(plan.commands[1].strategy_or_artifact, "bad-wat")
}

///|
test "parse_fuzz_corpus_promotion_metadata rejects malformed state and missing fields" {
  let bad_state = "{\"schema\":\"starshine.fuzz-corpus-entry.v1\",\"id\":\"bad\",\"state\":\"maybe\",\"source\":\"manual\",\"input\":\"case.wasm\",\"created_at\":\"2026-05-31\",\"generator\":\"manual\",\"features\":[],\"expectation\":\"none\",\"classification\":\"unknown\",\"replay\":\"echo replay\",\"artifacts\":[],\"owner_or_task\":\"[FUZ]1042B\",\"notes\":\"bad\",\"raw_artifact_hash\":\"raw\",\"reduced_artifact_hash\":\"reduced\",\"normalized_shape_hash\":\"normalized\",\"predicate_hash\":\"predicate\",\"feature_fact_hash\":\"features\",\"interestingness_label\":\"label\"}"
  match parse_fuzz_corpus_promotion_metadata_json(bad_state) {
    Ok(_) => fail("expected unknown state rejection")
    Err(msg) => assert_true(msg.contains("unknown corpus state"))
  }
  let missing_owner = "{\"schema\":\"starshine.fuzz-corpus-entry.v1\",\"id\":\"bad\",\"state\":\"quarantine\",\"source\":\"manual\",\"input\":\"case.wasm\",\"created_at\":\"2026-05-31\",\"generator\":\"manual\",\"features\":[],\"expectation\":\"none\",\"classification\":\"unknown\",\"replay\":\"echo replay\",\"artifacts\":[],\"notes\":\"bad\"}"
  match parse_fuzz_corpus_promotion_metadata_json(missing_owner) {
    Ok(_) => fail("expected missing owner rejection")
    Err(msg) =>
      assert_true(msg.contains("missing corpus metadata field owner_or_task"))
  }
}

///|
test "fuzz_corpus_promotion_metadata_schema names required states" {
  let schema = fuzz_corpus_promotion_metadata_schema_json()
  assert_true(schema.contains("promoted-valid"))
  assert_true(schema.contains("promoted-invalid"))
  assert_true(schema.contains("pass-mismatch"))
  assert_true(schema.contains("tool-failure"))
  assert_true(schema.contains("accepted-divergence"))
  assert_true(schema.contains("quarantine"))
  assert_true(schema.contains("owner_or_task"))
  assert_true(schema.contains("raw_artifact_hash"))
  assert_true(schema.contains("reduced_artifact_hash"))
  assert_true(schema.contains("normalized_shape_hash"))
  assert_true(schema.contains("predicate_hash"))
  assert_true(schema.contains("feature_fact_hash"))
  assert_true(schema.contains("interestingness_label"))
}

///|
test "parse_fuzz_replay_manifest_commands keeps deterministic corpus order" {
  let manifest = "{\"schema\":\"starshine.fuzz-replay-manifest.v1\",\"commands\":[{\"suite\":\"cmd-harness\",\"profile\":\"smoke\",\"seed\":16,\"seed_index\":0},{\"suite\":\"validate-valid\",\"profile\":\"ci\",\"seed\":17,\"seed_index\":1}]}"
  let commands = match parse_fuzz_replay_manifest_commands(manifest) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(commands.length(), 2)
  @debug.assert_eq(commands[0].suite, "cmd-harness")
  @debug.assert_eq(commands[0].profile, "smoke")
  @debug.assert_eq(commands[0].seed, 16L)
  @debug.assert_eq(commands[0].seed_index, 0)
  @debug.assert_eq(commands[1].suite, "validate-valid")
  @debug.assert_eq(commands[1].seed, 17L)
}

///|
test "run_fuzz_replay_manifest replays every manifest command once" {
  let manifest = "{\"schema\":\"starshine.fuzz-replay-manifest.v1\",\"commands\":[{\"suite\":\"cmd-harness\",\"profile\":\"smoke\",\"seed\":16,\"seed_index\":0},{\"suite\":\"cmd-harness\",\"profile\":\"smoke\",\"seed\":17,\"seed_index\":1}]}"
  let results = match run_fuzz_replay_manifest(manifest) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(results.length(), 2)
  @debug.assert_eq(results[0].suite, "cmd-harness")
  @debug.assert_eq(results[0].seed, 16L)
  @debug.assert_eq(results[0].seed_index, 0)
  @debug.assert_eq(results[0].seed_count, 1)
  @debug.assert_eq(results[1].seed, 17L)
  @debug.assert_eq(results[1].seed_index, 1)
}

///|
test "format_fuzz_run_report_json summarizes sweep results" {
  let results = match
    run_fuzz_suite_sweep("cmd-harness", "smoke", 7L, 2, 0, 1) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let report = format_fuzz_run_report_json(
    "cmd-harness", "smoke", 7L, 2, 0, 1, results,
  )
  assert_true(report.contains("\"suite\":\"cmd-harness\""))
  assert_true(report.contains("\"profile\":\"smoke\""))
  assert_true(report.contains("\"base_seed\":7"))
  assert_true(report.contains("\"seed_count\":2"))
  assert_true(report.contains("\"shard_index\":0"))
  assert_true(report.contains("\"shard_count\":1"))
  assert_true(report.contains("\"schema\":\"starshine.fuzz.summary.v1\""))
  assert_true(report.contains("\"runs\":["))
  assert_true(report.contains("\"summary\":{\"total_attempts\":"))
  assert_true(report.contains("\"total_elapsed_ms\":"))
  assert_true(report.contains("\"failure_classes\":{}"))
  assert_true(report.contains("\"strategy_outcomes\":{}"))
  assert_true(report.contains("\"artifact_counts\":{"))
  assert_true(report.contains("\"runs\":2"))
  assert_true(report.contains("\"ledgers\":1"))
  assert_true(report.contains("\"replay_manifests\":1"))
  assert_true(report.contains("\"seed_index\":0"))
  assert_true(report.contains("\"seed_index\":1"))
}

///|
test "FUZ1045A7 text differential suite is opt-in and skips unavailable tools" {
  assert_true(fuzz_standard_recipe_names().contains("text-differential-smoke"))
  assert_false(fuzz_active_suite_names().contains("text-differential"))
  let results = match
    run_fuzz_suite_sweep("text-differential", "smoke", 0x1045A7L, 1, 0, 1) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(results.length(), 1)
  @debug.assert_eq(results[0].suite, "text-differential")
  @debug.assert_eq(results[0].attempts, 1)
  match results[0].details_json {
    Some(details) => {
      assert_true(details.contains("\"local_reparse_lower_ok\":1"), msg=details)
      assert_true(details.contains("\"adapter_unavailable\":2"), msg=details)
      assert_true(
        details.contains("\"adapter_unavailable_classifications\":1"),
        msg=details,
      )
      assert_true(
        details.contains(
          "\"external_adapters\":[\"wabt-unavailable\",\"wasm-tools-unavailable\"]",
        ),
        msg=details,
      )
    }
    None => fail("expected text differential details")
  }
}

///|
test "validate-valid-metamorphic suite is active and reports transform details" {
  assert_true(fuzz_active_suite_names().contains("validate-valid-metamorphic"))
  let results = match
    run_fuzz_suite_sweep(
      "validate-valid-metamorphic", "smoke", 0x1036L, 1, 0, 1,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(results.length(), 1)
  @debug.assert_eq(results[0].attempts >= 1, true)
  match results[0].details_json {
    Some(details) => {
      assert_true(details.contains("\"transformed\":478"))
      assert_true(details.contains("add-non-name-custom-section"))
      assert_true(
        details.contains("add-duplicate-equivalent-immutable-v128-global"),
      )
      assert_true(
        details.contains("add-duplicate-equivalent-mutable-v128-global"),
      )
      assert_true(
        details.contains(
          "add-duplicate-equivalent-imported-mutable-v128-global",
        ),
      )
      assert_true(
        details.contains(
          "add-leading-nested-empty-void-blocks-to-defined-functions",
        ),
      )
      assert_true(
        details.contains(
          "add-trailing-nested-empty-void-blocks-to-defined-functions",
        ),
      )
      assert_true(
        details.contains("wrap-defined-function-bodies-in-identity-loop"),
      )
      assert_true(
        details.contains(
          "wrap-defined-function-bodies-in-nested-identity-loops",
        ),
      )
      assert_true(
        details.contains("add-duplicate-equivalent-imported-anyref-table"),
      )
      assert_true(
        details.contains("add-duplicate-equivalent-imported-nofunc-table"),
      )
      assert_true(
        details.contains("add-duplicate-equivalent-imported-none-table"),
      )
      assert_true(details.contains("add-duplicate-equivalent-none-table"))
      assert_true(
        details.contains(
          "add-leading-loop-wrapped-numeric-const-drops-to-defined-functions",
        ),
      )
      assert_true(details.contains("add-tag-export-aliases"))
      assert_true(details.contains("add-imported-global-export-aliases"))
      assert_true(details.contains("add-defined-global-export-aliases"))
      assert_true(details.contains("add-imported-memory-export-aliases"))
      assert_true(details.contains("add-defined-memory-export-aliases"))
      assert_true(details.contains("add-imported-table-export-aliases"))
      assert_true(details.contains("add-defined-table-export-aliases"))
      assert_true(details.contains("add-imported-tag-export-aliases"))
      assert_true(details.contains("add-defined-tag-export-aliases"))
      assert_true(details.contains("add-duplicate-equivalent-memory64"))
      assert_true(
        details.contains("add-duplicate-equivalent-imported-memory64"),
      )
      assert_true(
        details.contains(
          "add-duplicate-equivalent-imported-immutable-v128-global",
        ),
      )
      assert_true(
        details.contains("add-duplicate-equivalent-imported-shared-memory"),
      )
      assert_true(
        details.contains("add-duplicate-equivalent-imported-shared-memory64"),
      )
      assert_true(
        details.contains("add-duplicate-equivalent-imported-eqref-table"),
      )
      assert_true(details.contains("add-duplicate-equivalent-eqref-table"))
      assert_true(details.contains("add-duplicate-equivalent-nofunc-table"))
      assert_true(
        details.contains("add-duplicate-equivalent-immutable-f64-global"),
      )
      assert_true(
        details.contains("add-duplicate-equivalent-mutable-i32-global"),
      )
      assert_true(
        details.contains("add-duplicate-equivalent-mutable-f32-global"),
      )
      assert_true(
        details.contains("add-duplicate-equivalent-immutable-i64-global"),
      )
      assert_true(
        details.contains("add-duplicate-equivalent-immutable-f32-global"),
      )
      assert_true(
        details.contains("add-duplicate-equivalent-mutable-i64-global"),
      )
      assert_true(
        details.contains("add-duplicate-equivalent-mutable-f64-global"),
      )
      assert_true(details.contains("add-duplicate-equivalent-tag"))
      assert_true(details.contains("add-duplicate-equivalent-memory"))
      assert_true(details.contains("add-duplicate-equivalent-imported-memory"))
      assert_true(
        details.contains("add-duplicate-equivalent-imported-function"),
      )
      assert_true(
        details.contains(
          "add-duplicate-equivalent-imported-immutable-i32-global",
        ),
      )
      assert_true(
        details.contains(
          "add-duplicate-equivalent-imported-immutable-f32-global",
        ),
      )
      assert_true(
        details.contains(
          "add-duplicate-equivalent-imported-immutable-f64-global",
        ),
      )
      assert_true(
        details.contains(
          "add-duplicate-equivalent-imported-immutable-i64-global",
        ),
      )
      assert_true(
        details.contains("add-duplicate-equivalent-imported-mutable-i32-global"),
      )
      assert_true(
        details.contains("add-duplicate-equivalent-imported-mutable-f32-global"),
      )
      assert_true(
        details.contains("add-duplicate-equivalent-imported-mutable-f64-global"),
      )
      assert_true(
        details.contains("add-duplicate-equivalent-imported-mutable-i64-global"),
      )
      assert_true(
        details.contains("add-duplicate-equivalent-imported-funcref-table"),
      )
      assert_true(
        details.contains("add-duplicate-equivalent-imported-externref-table"),
      )
      assert_true(details.contains("add-duplicate-equivalent-imported-tag"))
      assert_true(details.contains("add-leading-non-name-custom-section"))
      assert_true(details.contains("add-custom-section-stress"))
      assert_true(
        details.contains(
          "add-leading-block-wrapped-i32-const-drop-to-defined-functions",
        ),
      )
      assert_true(
        details.contains("add-leading-ref-eq-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-ref-eq-i31-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-ref-i31-test-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-ref-i31-cast-drop-to-defined-functions"),
      )
      assert_true(
        details.contains(
          "add-leading-ref-eq-empty-struct-drop-to-defined-functions",
        ),
      )
      assert_true(
        details.contains("add-leading-ref-eq-func-drop-to-defined-functions"),
      )
      assert_true(
        details.contains(
          "add-leading-loop-wrapped-i32-const-drop-to-defined-functions",
        ),
      )
      assert_true(
        details.contains(
          "add-trailing-loop-wrapped-i32-const-drop-to-defined-functions",
        ),
      )
      assert_true(
        details.contains("add-duplicate-equivalent-empty-function-types"),
      )
      assert_true(
        details.contains("add-duplicate-equivalent-scalar-function-types"),
      )
      assert_true(details.contains("add-imported-function-export-aliases"))
      assert_true(details.contains("add-defined-function-export-aliases"))
      assert_true(details.contains("reshape-passive-element-segments"))
      assert_true(
        details.contains(
          "wrap-defined-function-bodies-in-nested-identity-blocks",
        ),
      )
      assert_true(details.contains("add-passive-data-segment-shape-stress"))
      assert_true(
        details.contains("add-leading-table-size-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-table-size-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-v128-const-drop-to-defined-functions"),
      )
      assert_true(
        details.contains(
          "add-leading-nullable-ref-test-drop-to-defined-functions",
        ),
      )
      assert_true(
        details.contains(
          "add-trailing-nullable-ref-cast-drop-to-defined-functions",
        ),
      )
      assert_true(
        details.contains(
          "add-leading-ref-null-is-null-drop-to-defined-functions",
        ),
      )
      assert_true(
        details.contains(
          "add-trailing-ref-null-is-null-drop-to-defined-functions",
        ),
      )
      assert_true(
        details.contains(
          "add-leading-any-convert-extern-drop-to-defined-functions",
        ),
      )
      assert_true(
        details.contains(
          "add-trailing-extern-convert-any-drop-to-defined-functions",
        ),
      )
      assert_true(
        details.contains("add-leading-ref-i31-get-s-drop-to-defined-functions"),
      )
      assert_true(
        details.contains(
          "add-leading-i8x16-extract-lane-s-drop-to-defined-functions",
        ),
      )
      assert_true(
        details.contains(
          "add-leading-i8x16-replace-lane-drop-to-defined-functions",
        ),
      )
      assert_true(
        details.contains("add-trailing-v128-const-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-i8x16-splat-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-i8x16-shl-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-i64x2-shr-u-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-v128-not-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-i64x2-bitmask-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-i32-clz-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-i64-popcnt-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-i32-extend8-s-drop-to-defined-functions"),
      )
      assert_true(
        details.contains(
          "add-trailing-i64-extend32-s-drop-to-defined-functions",
        ),
      )
      assert_true(
        details.contains(
          "add-leading-i32-trunc-sat-f32-s-drop-to-defined-functions",
        ),
      )
      assert_true(
        details.contains(
          "add-trailing-i64-trunc-sat-f64-u-drop-to-defined-functions",
        ),
      )
      assert_true(
        details.contains("add-leading-f32-demote-f64-drop-to-defined-functions"),
      )
      assert_true(
        details.contains(
          "add-trailing-f64-promote-f32-drop-to-defined-functions",
        ),
      )
      assert_true(
        details.contains("add-leading-i32-wrap-i64-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-i32-wrap-i64-drop-to-defined-functions"),
      )
      assert_true(
        details.contains(
          "add-leading-i64-extend-i32-s-drop-to-defined-functions",
        ),
      )
      assert_true(
        details.contains(
          "add-trailing-i64-extend-i32-u-drop-to-defined-functions",
        ),
      )
      assert_true(
        details.contains(
          "add-leading-f32-convert-i32-s-drop-to-defined-functions",
        ),
      )
      assert_true(
        details.contains(
          "add-trailing-f32-convert-i64-u-drop-to-defined-functions",
        ),
      )
      assert_true(
        details.contains(
          "add-leading-f64-convert-i32-s-drop-to-defined-functions",
        ),
      )
      assert_true(
        details.contains(
          "add-trailing-f64-convert-i32-u-drop-to-defined-functions",
        ),
      )
      assert_true(
        details.contains(
          "add-leading-f64-convert-i64-s-drop-to-defined-functions",
        ),
      )
      assert_true(
        details.contains(
          "add-trailing-f64-convert-i64-u-drop-to-defined-functions",
        ),
      )
      assert_true(details.contains("add-module-name-section"))
      assert_true(details.contains("add-unused-passive-data-segment"))
      assert_true(details.contains("add-unused-immutable-i32-global"))
      assert_true(details.contains("add-unused-empty-function"))
      assert_true(details.contains("add-unused-empty-function-type"))
      assert_true(details.contains("add-duplicate-equivalent-function-type"))
      assert_true(details.contains("add-unused-funcref-table"))
      assert_true(details.contains("add-duplicate-equivalent-funcref-table"))
      assert_true(
        details.contains("add-unused-passive-funcref-element-segment"),
      )
      assert_true(details.contains("add-function-names-section"))
      assert_true(details.contains("add-local-names-section"))
      assert_true(details.contains("add-label-names-section"))
      assert_true(details.contains("add-type-names-section"))
      assert_true(details.contains("add-global-names-section"))
      assert_true(details.contains("add-table-names-section"))
      assert_true(details.contains("add-memory-names-section"))
      assert_true(details.contains("add-data-names-section"))
      assert_true(details.contains("add-elem-names-section"))
      assert_true(details.contains("add-tag-names-section"))
      assert_true(details.contains("add-field-names-section"))
      assert_true(
        details.contains("wrap-defined-function-bodies-in-identity-block"),
      )
      assert_true(details.contains("split-merge-local-declarations"))
      assert_true(details.contains("add-unused-i32-local-to-defined-functions"))
      assert_true(
        details.contains("add-unused-numeric-locals-to-defined-functions"),
      )
      assert_true(
        details.contains("add-unused-reference-locals-to-defined-functions"),
      )
      assert_true(
        details.contains("add-unused-v128-local-to-defined-functions"),
      )
      assert_true(
        details.contains("add-unused-gc-reference-locals-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-ref-null-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-ref-null-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-i64-const-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-i64-const-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f32-const-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f32-const-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f64-const-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f64-const-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-i32-eqz-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-i32-eqz-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-i64-eqz-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-i64-eqz-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-i32-rotl-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-i64-rotr-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-i32-eq-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-i32-eq-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-i32-ne-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-i32-ne-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-i64-eq-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-i64-eq-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-i64-ne-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-i64-ne-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-i32-lt-s-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-i64-gt-s-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f32-abs-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f32-abs-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f64-abs-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f64-abs-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f32-ceil-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f32-ceil-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f32-floor-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f32-floor-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f64-ceil-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f64-ceil-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f64-floor-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f64-floor-drop-to-defined-functions"),
      )
      assert_true(details.contains("add-leading-false-if-to-defined-functions"))
      assert_true(
        details.contains("add-trailing-false-if-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f32-trunc-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f64-nearest-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f32-add-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f32-add-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f32-sub-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f32-sub-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f64-add-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f64-add-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f64-sub-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f64-sub-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f32-mul-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f32-mul-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f32-div-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f32-div-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f64-mul-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f64-mul-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f64-div-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f64-div-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f32-min-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f32-min-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f32-max-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f32-max-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f64-min-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f64-min-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f64-max-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f64-max-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f32-copysign-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f32-copysign-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f64-copysign-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f64-copysign-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f32-eq-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f32-eq-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f32-ne-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f32-ne-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f64-eq-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f64-eq-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f64-ne-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f64-ne-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f32-le-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f32-le-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f32-ge-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f32-ge-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f64-le-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f64-le-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-f64-ge-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-f64-ge-drop-to-defined-functions"),
      )
      assert_true(details.contains("add-leading-nop-to-defined-functions"))
      assert_true(details.contains("add-trailing-nop-to-defined-functions"))
      assert_true(
        details.contains("add-leading-i32-const-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-i32-const-drop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-empty-void-block-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-empty-void-block-to-defined-functions"),
      )
      assert_true(
        details.contains("add-leading-empty-void-loop-to-defined-functions"),
      )
      assert_true(
        details.contains("add-trailing-empty-void-loop-to-defined-functions"),
      )
      assert_true(details.contains("add-export-aliases"))
      assert_true(details.contains("add-prefixed-export-aliases"))
      assert_true(details.contains("add-suffixed-export-aliases"))
      assert_true(details.contains("reverse-custom-sections"))
    }
    None => fail("expected metamorphic details json")
  }
}

///|
test "format_fuzz_run_report_json includes detailed suite ledgers" {
  let valid_results = match
    run_fuzz_suite_sweep("validate-valid", "smoke", 3L, 1, 0, 1) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let valid_report = format_fuzz_run_report_json(
    "validate-valid", "smoke", 3L, 1, 0, 1, valid_results,
  )
  assert_true(valid_report.contains("\"details\":{"))
  assert_true(valid_report.contains("\"validated\":"))
  assert_true(valid_report.contains("\"feature_stats\":{"))
  assert_true(valid_report.contains("\"modules\":"))
  assert_true(valid_report.contains("\"calls\":"))
  assert_true(valid_report.contains("\"feature_floors\":["))

  let invalid_results = match
    run_fuzz_suite_sweep("validate-invalid-ast", "smoke", 4L, 1, 0, 1) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let invalid_report = format_fuzz_run_report_json(
    "validate-invalid-ast", "smoke", 4L, 1, 0, 1, invalid_results,
  )
  assert_true(invalid_report.contains("\"details\":{"))
  assert_true(invalid_report.contains("\"seed_profiles\":["))
  assert_true(invalid_report.contains("\"profile\":\"rich\""))
  assert_true(invalid_report.contains("\"strategy_stats\":["))
  assert_true(invalid_report.contains("\"stable_id\":"))
  assert_true(invalid_report.contains("\"rejected_expected\":"))

  let wat_results = match
    run_fuzz_suite_sweep("wat-roundtrip", "smoke", 5L, 1, 0, 1) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let wat_report = format_fuzz_run_report_json(
    "wat-roundtrip", "smoke", 5L, 1, 0, 1, wat_results,
  )
  assert_true(wat_report.contains("\"details\":{"))
  assert_true(wat_report.contains("\"module_print_failures\":"))
  assert_true(wat_report.contains("\"parse_failures\":"))
  assert_true(wat_report.contains("\"unstable_text\":"))
  assert_true(wat_report.contains("\"script_render_failures\":"))
  assert_true(wat_report.contains("\"script_no_module_commands\":"))

  let lower_results = match
    run_fuzz_suite_sweep("wast-validate-roundtrip", "smoke", 6L, 1, 0, 1) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let lower_report = format_fuzz_run_report_json(
    "wast-validate-roundtrip", "smoke", 6L, 1, 0, 1, lower_results,
  )
  assert_true(lower_report.contains("\"details\":{"))
  assert_true(lower_report.contains("\"printed\":"))
  assert_true(lower_report.contains("\"parsed\":"))
  assert_true(lower_report.contains("\"lowered\":"))
  assert_true(lower_report.contains("\"validated\":"))
  assert_true(lower_report.contains("\"lower_failures\":"))

  let gen_text_results = match
    run_fuzz_suite_sweep(
      "gen-valid-wat-validate-roundtrip", "smoke", 7L, 1, 0, 1,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let gen_text_report = format_fuzz_run_report_json(
    "gen-valid-wat-validate-roundtrip", "smoke", 7L, 1, 0, 1, gen_text_results,
  )
  assert_true(gen_text_report.contains("\"details\":{"))
  assert_true(gen_text_report.contains("\"generated\":"))
  assert_true(gen_text_report.contains("\"printed\":"))
  assert_true(gen_text_report.contains("\"parsed\":"))
  assert_true(gen_text_report.contains("\"lowered\":"))
  assert_true(gen_text_report.contains("\"validated\":"))
}

///|
test "valid multi-module wast generator emits registered linked resources" {
  let specimen = gen_valid_multi_module_wast_case(0x1055A3UL)
  assert_true(specimen.text.contains("(module $provider"))
  assert_true(specimen.text.contains("(register \"provider"))
  assert_true(specimen.text.contains("(import \"provider\" \"f\" (func"))
  assert_true(specimen.feature_facts.contains("multi-module"))
  assert_true(specimen.feature_facts.contains("valid-linking"))
  assert_true(specimen.feature_facts.contains("import:func"))
  assert_true(specimen.feature_facts.contains("export:global"))

  let script = match
    wast_to_script(specimen.text, filename="gen-valid-linking.wast") {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(script.commands.length(), 4)
  match
    @wast.run_wast_spec_file("gen-valid-linking.wast", specimen.text).status {
    @wast.WastSpecFileStatus::Passed => ()
    @wast.WastSpecFileStatus::Skipped(msg) =>
      fail("expected generated valid linking script to pass, got skip: \{msg}")
    @wast.WastSpecFileStatus::Failed(msg) =>
      fail(
        "expected generated valid linking script to pass, got failure: \{msg}",
      )
  }
}

///|
test "valid multi-module wast generator can emit memory table and global focused variants" {
  let specimens = gen_valid_multi_module_wast_cases(0x1055A3UL, 4)
  @debug.assert_eq(specimens.length(), 4)
  let mut saw_memory = false
  let mut saw_table = false
  let mut saw_global = false
  for specimen in specimens {
    match wast_to_script(specimen.text, filename=specimen.name + ".wast") {
      Ok(_) => ()
      Err(msg) => fail(msg)
    }
    match
      @wast.run_wast_spec_file(specimen.name + ".wast", specimen.text).status {
      @wast.WastSpecFileStatus::Passed => ()
      @wast.WastSpecFileStatus::Skipped(msg) =>
        fail("expected generated multi-module script to pass, got skip: \{msg}")
      @wast.WastSpecFileStatus::Failed(msg) =>
        fail(
          "expected generated multi-module script to pass, got failure: \{msg}",
        )
    }
    saw_memory = saw_memory || specimen.feature_facts.contains("import:memory")
    saw_table = saw_table || specimen.feature_facts.contains("import:table")
    saw_global = saw_global || specimen.feature_facts.contains("import:global")
  }
  assert_true(saw_memory)
  assert_true(saw_table)
  assert_true(saw_global)
}

///|
test "unlinkable multi-module wast generator emits missing and mismatch import assertions" {
  let specimens = gen_unlinkable_multi_module_wast_cases(0x1055B3UL, 10)
  @debug.assert_eq(specimens.length(), 10)
  let mut saw_missing_func = false
  let mut saw_missing_memory = false
  let mut saw_missing_table = false
  let mut saw_missing_global = false
  let mut saw_missing_tag = false
  let mut saw_mismatch_func = false
  let mut saw_mismatch_memory = false
  let mut saw_mismatch_table = false
  let mut saw_mismatch_global = false
  let mut saw_mismatch_tag = false
  for specimen in specimens {
    assert_true(specimen.text.contains("(module $unlinkable_provider_"))
    assert_true(specimen.text.contains("(register \"provider\""))
    assert_true(specimen.text.contains("(assert_unlinkable"))
    assert_true(specimen.feature_facts.contains("multi-module"))
    assert_true(specimen.feature_facts.contains("unlinkable"))
    let script = match
      wast_to_script(specimen.text, filename=specimen.name + ".wast") {
      Ok(v) => v
      Err(msg) => fail(msg)
    }
    @debug.assert_eq(script.commands.length(), 3)
    match
      @wast.run_wast_spec_file(specimen.name + ".wast", specimen.text).status {
      @wast.WastSpecFileStatus::Passed => ()
      @wast.WastSpecFileStatus::Skipped(msg) =>
        fail(
          "expected generated unlinkable script to pass static harness, got skip: \{msg}",
        )
      @wast.WastSpecFileStatus::Failed(msg) =>
        fail(
          "expected generated unlinkable script to pass static harness, got failure: \{msg}",
        )
    }
    match
      evaluate_wast_static_assertion(
        script.commands[2],
        specimen.name + ".wast",
      ) {
      Ok(result) =>
        match result.stage {
          @wast.ValidBeforeLink => ()
          _ =>
            fail(
              "expected generated unlinkable assertion to be valid before link",
            )
        }
      Err(msg) => fail(msg)
    }
    saw_missing_func = saw_missing_func ||
      specimen.feature_facts.contains("missing-import:func")
    saw_missing_memory = saw_missing_memory ||
      specimen.feature_facts.contains("missing-import:memory")
    saw_missing_table = saw_missing_table ||
      specimen.feature_facts.contains("missing-import:table")
    saw_missing_global = saw_missing_global ||
      specimen.feature_facts.contains("missing-import:global")
    saw_missing_tag = saw_missing_tag ||
      specimen.feature_facts.contains("missing-import:tag")
    saw_mismatch_func = saw_mismatch_func ||
      specimen.feature_facts.contains("type-mismatch:func")
    saw_mismatch_memory = saw_mismatch_memory ||
      specimen.feature_facts.contains("type-mismatch:memory")
    saw_mismatch_table = saw_mismatch_table ||
      specimen.feature_facts.contains("type-mismatch:table")
    saw_mismatch_global = saw_mismatch_global ||
      specimen.feature_facts.contains("type-mismatch:global")
    saw_mismatch_tag = saw_mismatch_tag ||
      specimen.feature_facts.contains("type-mismatch:tag")
  }
  assert_true(saw_missing_func)
  assert_true(saw_missing_memory)
  assert_true(saw_missing_table)
  assert_true(saw_missing_global)
  assert_true(saw_missing_tag)
  assert_true(saw_mismatch_func)
  assert_true(saw_mismatch_memory)
  assert_true(saw_mismatch_table)
  assert_true(saw_mismatch_global)
  assert_true(saw_mismatch_tag)
}

///|
test "duplicate multi-module wast fixtures classify script-name failures separately" {
  let module_specimen = gen_duplicate_multi_module_wast_case(0x1055C1UL)
  assert_true(module_specimen.text.contains("(module $dup_module_"))
  assert_true(module_specimen.feature_facts.contains("duplicate-module-name"))
  match classify_multi_module_wast_case(module_specimen) {
    DuplicateModuleName => ()
    other =>
      fail(
        "expected duplicate module-name classification, got \{@debug.to_string(other)}",
      )
  }

  let register_specimen = gen_duplicate_multi_module_wast_case(0x1055C2UL)
  assert_true(register_specimen.text.contains("(register \"dupe\""))
  assert_true(
    register_specimen.feature_facts.contains("duplicate-register-name"),
  )
  match classify_multi_module_wast_case(register_specimen) {
    DuplicateRegisterName => ()
    other =>
      fail(
        "expected duplicate register-name classification, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "valid multi-module linking fuzz runner reports link counters separately" {
  assert_true(fuzz_active_suite_names().contains("valid-multi-module-linking"))
  let stats = match run_valid_multi_module_linking_fuzz("smoke", 0x1055A4UL) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(stats.generated, stats.attempts)
  @debug.assert_eq(stats.parsed_scripts, stats.attempts)
  @debug.assert_eq(stats.single_module_validation_failures, 0)
  @debug.assert_eq(stats.link_failed, 0)
  @debug.assert_eq(stats.link_skipped, 0)
  assert_true(stats.single_module_validated >= stats.attempts * 2)
  @debug.assert_eq(stats.link_passed, stats.attempts)

  let results = match
    run_fuzz_suite_sweep(
      "valid-multi-module-linking", "smoke", 0x1055A4L, 1, 0, 1,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let report = format_fuzz_run_report_json(
    "valid-multi-module-linking", "smoke", 0x1055A4L, 1, 0, 1, results,
  )
  assert_true(report.contains("\"single_module_validated\":"))
  assert_true(report.contains("\"link_passed\":"))
  assert_true(report.contains("\"link_failed\":0"))
}

///|
test "parse_fuzz_recipe_text parses core key value schema" {
  let recipe = match
    parse_fuzz_recipe_text(
      "# standard smoke\nschema=starshine.fuzz.recipe.v1\nname=smoke\nsuite=validate-valid\nprofile=ci\nseed=0x5eed\nseed-count=4\nshard-count=2\noutput=jsonl\n",
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(recipe.name, "smoke")
  @debug.assert_eq(recipe.suite, "validate-valid")
  @debug.assert_eq(recipe.profile, "ci")
  @debug.assert_eq(recipe.seed_i64, 0x5eedL)
  @debug.assert_eq(recipe.seed_count, 4)
  @debug.assert_eq(recipe.shard_count, 2)
  match recipe.output_mode {
    Jsonl => ()
    _ => fail("expected jsonl recipe output")
  }
}

///|
test "parse_fuzz_recipe_text requires supported schema version" {
  match parse_fuzz_recipe_text("name=smoke\nsuite=validate-valid\n") {
    Ok(_) => fail("expected missing schema to fail")
    Err(msg) => assert_true(msg.contains("recipe missing schema"))
  }
  match
    parse_fuzz_recipe_text(
      "schema=starshine.fuzz.recipe.v2\nname=smoke\nsuite=validate-valid\n",
    ) {
    Ok(_) => fail("expected unsupported schema to fail")
    Err(msg) => assert_true(msg.contains("unsupported recipe schema"))
  }
}

///|
test "standard fuzz recipe catalog includes required checked-in recipes" {
  let names = fuzz_standard_recipe_names()
  assert_true(names.contains("smoke"))
  assert_true(names.contains("ci"))
  assert_true(names.contains("nightly"))
  assert_true(names.contains("pass-signoff"))
  assert_true(names.contains("validator-stress"))
  assert_true(names.contains("parser-stress"))
  assert_true(names.contains("binaryen-oracle"))
  assert_true(names.contains("default-smoke"))
  assert_true(names.contains("default-ci"))
  let smoke_recipe = match fuzz_standard_recipe_by_name("default-smoke") {
    Some(v) => v
    None => fail("expected default-smoke recipe")
  }
  @debug.assert_eq(smoke_recipe.suite, "all")
  @debug.assert_eq(smoke_recipe.profile, "smoke")
  @debug.assert_eq(smoke_recipe.seed_i64, 0x5eedL)
  let ci_recipe = match fuzz_standard_recipe_by_name("default-ci") {
    Some(v) => v
    None => fail("expected default-ci recipe")
  }
  @debug.assert_eq(ci_recipe.suite, "all")
  @debug.assert_eq(ci_recipe.profile, "ci")
  assert_true(ci_recipe.seed_count > smoke_recipe.seed_count)
  let recipe = match fuzz_standard_recipe_by_name("pass-signoff") {
    Some(v) => v
    None => fail("expected pass-signoff recipe")
  }
  @debug.assert_eq(recipe.suite, "cmd-harness")
  assert_true(recipe.profile.contains("gen-valid=binaryen-oracle-portable"))
  assert_true(recipe.profile.contains("passes=each-pass"))
  assert_true(recipe.profile.contains("check-idempotence"))
  @debug.assert_eq(recipe.seed_i64, 0x5eedL)
  @debug.assert_eq(recipe.seed_count, 8)
  @debug.assert_eq(recipe.shard_count, 4)
  let validator_recipe = match
    fuzz_standard_recipe_by_name("validator-stress") {
    Some(v) => v
    None => fail("expected validator-stress recipe")
  }
  @debug.assert_eq(validator_recipe.suite, "validate-valid")
  @debug.assert_eq(validator_recipe.profile, "stress")
  @debug.assert_eq(validator_recipe.seed_i64, 0x10d69L)
  @debug.assert_eq(validator_recipe.seed_count, 16)
  @debug.assert_eq(validator_recipe.shard_count, 4)
}

///|
test "parse_fuzz_cli_command accepts golden seed smoke runner" {
  match parse_fuzz_cli_command(["--golden-seed-smoke"]) {
    FuzzCliCommand::GoldenSeedSmoke => ()
    _ => fail("expected golden seed smoke command")
  }
}

///|
test "parse_fuzz_cli_command accepts recipe listing command" {
  match parse_fuzz_cli_command(["--list-recipes"]) {
    FuzzCliCommand::ListRecipes => ()
    _ => fail("expected recipe listing command")
  }
}

///|
test "golden seed smoke runner asserts stable high-level counters" {
  let report = match run_fuzz_golden_seed_smoke() {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(report.schema_id, "starshine.fuzz-golden-seed-smoke.v1")
  @debug.assert_eq(report.recipe_name, "smoke")
  @debug.assert_eq(report.seed, 0x5eedL)
  @debug.assert_eq(report.cases.length(), 2)
  let recipe_case = report.cases[0]
  @debug.assert_eq(recipe_case.catalog_entry_id, None)
  @debug.assert_eq(recipe_case.suite, "validate-valid")
  @debug.assert_eq(recipe_case.profile, "smoke")
  @debug.assert_eq(recipe_case.seed_index, 0)
  @debug.assert_eq(recipe_case.attempts, 128)
  @debug.assert_eq(recipe_case.details_required, true)
  @debug.assert_eq(recipe_case.expected_counter_count, 0)
  assert_true(recipe_case.details_json_contains("\"validated\":128"))
  assert_true(
    recipe_case.details_json_contains(
      "\"generator_config\":\"coverage-forced\"",
    ),
  )
  let catalog_case = report.cases[1]
  @debug.assert_eq(
    catalog_case.catalog_entry_id,
    Some("gen-valid-coverage-forced-smoke"),
  )
  @debug.assert_eq(catalog_case.suite, "validate-valid")
  @debug.assert_eq(catalog_case.profile, "smoke")
  @debug.assert_eq(catalog_case.seed, 0xf71004L)
  @debug.assert_eq(catalog_case.attempts, 128)
  @debug.assert_eq(catalog_case.details_required, true)
  @debug.assert_eq(catalog_case.expected_counter_count, 2)
  assert_true(catalog_case.details_json_contains("\"validated\":128"))
  assert_true(catalog_case.details_json_contains("\"v128\":"))
}

///|
test "standard fuzz recipe texts parse through the public recipe parser" {
  for name in fuzz_standard_recipe_names() {
    let text = match fuzz_standard_recipe_text_by_name(name) {
      Some(v) => v
      None => fail("missing standard recipe text for \{name}")
    }
    let recipe = match parse_fuzz_recipe_text(text) {
      Ok(v) => v
      Err(msg) => fail("standard recipe \{name} did not parse: \{msg}")
    }
    @debug.assert_eq(recipe.name, name)
    assert_true(
      recipe.suite == "all" ||
      fuzz_active_suite_names().contains(recipe.suite) ||
      recipe.suite == "text-differential",
    )
    assert_true(recipe.seed_count > 0)
    assert_true(recipe.shard_count > 0)
  }
}

///|
test "parse_fuzz_cli_args loads checked-in recipe defaults by name" {
  let parsed = parse_fuzz_cli_args(["--recipe", "default-ci"])
  @debug.assert_eq(parsed.suite, "all")
  @debug.assert_eq(parsed.profile, "ci")
  @debug.assert_eq(parsed.seed_i64, 0x5eedL)
  @debug.assert_eq(parsed.seed_count, 4)
  match parsed.output_mode {
    Jsonl => ()
    _ => fail("expected default-ci to select jsonl output")
  }
}

///|
test "parse_fuzz_cli_args applies recipe defaults before cli overrides" {
  let recipe = match
    parse_fuzz_recipe_text(
      "schema=starshine.fuzz.recipe.v1\nname=ci\nsuite=validate-valid\nprofile=ci\nseed=0x10\nseed-count=8\nshard-count=4\noutput=jsonl\n",
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let parsed = parse_fuzz_cli_args_with_recipe(
    ["--recipe", "ci", "--profile=stress", "--seed-count=2", "--output=text"],
    Some(recipe),
  )
  @debug.assert_eq(parsed.suite, "validate-valid")
  @debug.assert_eq(parsed.profile, "stress")
  @debug.assert_eq(parsed.seed_i64, 0x10L)
  @debug.assert_eq(parsed.seed_count, 2)
  @debug.assert_eq(parsed.shard_count, 4)
  match parsed.output_mode {
    Text => ()
    _ => fail("expected cli output override")
  }
}

///|
test "parse_fuzz_cli_command detects control commands" {
  match parse_fuzz_cli_command(["--help"]) {
    Help => ()
    _ => fail("expected help command")
  }
  match parse_fuzz_cli_command(["-h"]) {
    Help => ()
    _ => fail("expected help command")
  }
  match parse_fuzz_cli_command(["--list-suites"]) {
    ListSuites => ()
    _ => fail("expected list suites command")
  }
  match parse_fuzz_cli_command(["--list-profiles"]) {
    ListProfiles => ()
    _ => fail("expected list profiles command")
  }
}

///|
test "parse_fuzz_cli_command detects emit-gen-valid-batch command" {
  match
    parse_fuzz_cli_command([
      "--emit-gen-valid-batch", "--count", "2", "--seed", "0x5eed", "--out-dir",
      "tmp/gen-valid",
    ]) {
    EmitGenValidBatch(args) => {
      @debug.assert_eq(args.count, 2)
      @debug.assert_eq(args.seed, 0x5eedUL)
      @debug.assert_eq(args.out_dir, "tmp/gen-valid")
      @debug.assert_eq(args.profile, "binaryen-oracle-portable")
      @debug.assert_eq(args.required_features.length(), 0)
      @debug.assert_eq(args.excluded_features.length(), 0)
      @debug.assert_eq(args.max_attempts, 2)
      @debug.assert_eq(args.metamorphic_transform_ids.length(), 0)
    }
    _ => fail("expected emit-gen-valid-batch command")
  }
}

///|
test "parse_fuzz_cli_command parses gen-valid batch profile and feature filters" {
  match
    parse_fuzz_cli_command([
      "--emit-gen-valid-batch", "--count=3", "--seed=0xf71004", "--out-dir=tmp/gen-valid",
      "--gen-valid-profile=coverage-forced", "--require-feature", "v128", "--require-feature=mems:2",
      "--exclude-feature=imports", "--max-attempts", "12", "--manifest=tmp/gen-valid/manifest.json",
      "--metamorphic-transform", "add-non-name-custom-section", "--metamorphic-transform=add-module-name-section",
    ]) {
    EmitGenValidBatch(args) => {
      @debug.assert_eq(args.count, 3)
      @debug.assert_eq(args.seed, 0xf71004UL)
      @debug.assert_eq(args.out_dir, "tmp/gen-valid")
      @debug.assert_eq(args.profile, "coverage-forced")
      @debug.assert_eq(args.required_features.length(), 2)
      @debug.assert_eq(args.required_features[0].min_count, 1)
      @debug.assert_eq(args.required_features[1].min_count, 2)
      @debug.assert_eq(args.excluded_features.length(), 1)
      @debug.assert_eq(args.max_attempts, 12)
      @debug.assert_eq(args.manifest_path, Some("tmp/gen-valid/manifest.json"))
      @debug.assert_eq(args.metamorphic_transform_ids.length(), 2)
      @debug.assert_eq(
        args.metamorphic_transform_ids[0],
        "add-non-name-custom-section",
      )
      @debug.assert_eq(
        args.metamorphic_transform_ids[1],
        "add-module-name-section",
      )
    }
    _ => fail("expected emit-gen-valid-batch command")
  }
}

///|
test "gen-valid batch treats table-size transform without table as skipped candidate" {
  let args = EmitGenValidBatchArgs::new(
    1,
    0x5eedUL,
    "tmp/gen-valid",
    profile="binaryen-oracle-portable",
    max_attempts=1,
    metamorphic_transform_ids=[
      "add-leading-table-size-drop-to-defined-functions",
    ],
  )
  match emit_gen_valid_batch_selection(args) {
    Ok(_) => fail("expected no table-bearing candidate in one attempt")
    Err(msg) => {
      assert_true(msg.contains("unmet feature floors"), msg~)
      assert_false(
        msg.contains("requires at least one valid table index"),
        msg~,
      )
    }
  }
}

///|
test "gen-valid batch applies table-size transforms once table index exists" {
  let args = EmitGenValidBatchArgs::new(
    2,
    0x5eedUL,
    "tmp/gen-valid",
    profile="natural-small",
    max_attempts=64,
    metamorphic_transform_ids=[
      "add-leading-table-size-drop-to-defined-functions", "add-trailing-table-size-drop-to-defined-functions",
    ],
  )
  let selection = match emit_gen_valid_batch_selection(args) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let manifest = format_gen_valid_batch_manifest_json(args, selection)
  assert_true(
    manifest.contains(
      "\"transform_id\":\"add-leading-table-size-drop-to-defined-functions\"",
    ),
  )
  assert_true(
    manifest.contains(
      "\"transform_id\":\"add-trailing-table-size-drop-to-defined-functions\"",
    ),
  )
}

///|
test "gen-valid batch manifest reports requested and applied metamorphic transforms" {
  let args = EmitGenValidBatchArgs::new(
    2,
    0x1036UL,
    "tmp/gen-valid",
    profile="natural-small",
    max_attempts=8,
    metamorphic_transform_ids=[
      "add-non-name-custom-section", "add-module-name-section",
    ],
  )
  let selection = match emit_gen_valid_batch_selection(args) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let manifest = format_gen_valid_batch_manifest_json(args, selection)
  assert_true(
    manifest.contains(
      "\"metamorphic_transform_ids\":[\"add-non-name-custom-section\",\"add-module-name-section\"]",
    ),
  )
  assert_true(
    manifest.contains("\"transform_id\":\"add-non-name-custom-section\""),
  )
  assert_true(manifest.contains("\"transform_id\":\"add-module-name-section\""))
}

///|
test "parse_fuzz_cli_command detects emit-invalid-repro command" {
  match
    parse_fuzz_cli_command([
      "--emit-invalid-repro", "--suite", "binary", "--strategy", "trailing-garbage",
      "--seed", "0x5eed", "--attempt", "7", "--out-dir", "tmp/invalid", "--profile",
      "ci",
    ]) {
    EmitInvalidRepro(args) => {
      @debug.assert_eq(args.suite, "binary")
      @debug.assert_eq(args.strategy_id, "trailing-garbage")
      @debug.assert_eq(args.seed, 0x5eedUL)
      @debug.assert_eq(args.attempt, 7)
      @debug.assert_eq(args.profile, "ci")
      @debug.assert_eq(args.out_dir, "tmp/invalid")
    }
    _ => fail("expected emit-invalid-repro command")
  }
}

///|
test "emit_invalid_repro_report builds a persisted-report-ready case" {
  let report = match
    emit_invalid_repro_report(
      EmitInvalidReproArgs::new(
        "ast", "duplicate-export-name", 0x5eedUL, 5, "tmp/invalid",
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(report.suite, "validate-invalid-ast")
  @debug.assert_eq(report.strategy_id, "duplicate-export-name")
  @debug.assert_eq(report.profile, "smoke")
  @debug.assert_eq(report.seed_profile, Some("repro"))
  @debug.assert_eq(report.seed_mode, Some("random-valid"))
  @debug.assert_eq(report.artifacts.length(), 2)
}

///|
test "emit_gen_valid_batch_artifacts_with_manifest returns deterministic diagnostics" {
  let batch = match emit_gen_valid_batch_artifacts_with_manifest(2, 0x5eedUL) {
    Ok(v) => v
    Err(e) => fail("expected gen-valid batch success, got \{e}")
  }
  @debug.assert_eq(batch.artifacts.length(), 2)
  @debug.assert_eq(batch.manifest.length(), 2)
  @debug.assert_eq(batch.manifest[0].file_name, "gen-valid-000001.wasm")
  @debug.assert_eq(batch.manifest[0].seed, 0x5eedUL)
  @debug.assert_eq(batch.manifest[0].index, 1)
  @debug.assert_eq(
    batch.manifest[0].config_label,
    "binaryen-oracle-coverage-forced",
  )
  assert_true(batch.manifest[0].attempts >= 1)
  @debug.assert_eq(batch.manifest[0].validated, true)
  assert_true(batch.manifest[0].validation_error_message is None)
  @debug.assert_eq(
    batch.manifest[0].facts.mode,
    emit_gen_valid_batch_config().mode,
  )
}

///|
test "emit_gen_valid_batch_artifacts_until_features satisfies ssa-nomerge SSA floors" {
  let chain_floor = match
    @validate.validate_valid_feature_floor_by_label(
      "ssa-straight-line-local-chain", 1,
    ) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  let branch_floor = match
    @validate.validate_valid_feature_floor_by_label(
      "ssa-block-branch-merge-copy", 1,
    ) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  let br_if_floor = match
    @validate.validate_valid_feature_floor_by_label(
      "ssa-block-br-if-merge-copy", 1,
    ) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  let selected = match
    emit_gen_valid_batch_artifacts_until_features(
      1,
      0x5eedUL,
      match GenValidConfig::profile("ssa-nomerge-smoke") {
        Ok(v) => v
        Err(e) => fail(e)
      },
      [chain_floor, branch_floor, br_if_floor],
      [],
      32,
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected ssa-nomerge feature-guided batch success, got \{e}")
  }
  @debug.assert_eq(selected.artifacts.length(), 1)
  let chain_count = match
    @validate.validate_valid_feature_actual_count_by_label(
      selected.feature_stats,
      "ssa-straight-line-local-chain",
    ) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  let branch_count = match
    @validate.validate_valid_feature_actual_count_by_label(
      selected.feature_stats,
      "ssa-block-branch-merge-copy",
    ) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  let br_if_count = match
    @validate.validate_valid_feature_actual_count_by_label(
      selected.feature_stats,
      "ssa-block-br-if-merge-copy",
    ) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  assert_true(chain_count >= 1)
  assert_true(branch_count >= 1)
  assert_true(br_if_count >= 1)
}

///|
test "emit_gen_valid_batch_artifacts_until_features continues after floors are satisfied" {
  let v128_floor = match
    @validate.validate_valid_feature_floor_by_label("v128", 1) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  let selected = match
    emit_gen_valid_batch_artifacts_until_features(
      5,
      0xf71004UL,
      GenValidConfig::coverage_forced_default(),
      [v128_floor],
      [],
      32,
    ) {
    Ok(v) => v
    Err(e) =>
      fail(
        "expected feature-guided batch to fill count after floors met, got \{e}",
      )
  }
  @debug.assert_eq(selected.artifacts.length(), 5)
  @debug.assert_eq(selected.selected, 5)
  let v128_count = match
    @validate.validate_valid_feature_actual_count_by_label(
      selected.feature_stats,
      "v128",
    ) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  assert_true(v128_count >= 1)
}

///|
test "emit_gen_valid_batch_artifacts_until_features selects bounded feature-covering modules" {
  let v128_floor = match
    @validate.validate_valid_feature_floor_by_label("v128", 1) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  let selected = match
    emit_gen_valid_batch_artifacts_until_features(
      1,
      0xf71004UL,
      GenValidConfig::coverage_forced_default(),
      [v128_floor],
      [],
      8,
    ) {
    Ok(v) => v
    Err(e) => fail("expected feature-guided gen-valid batch success, got \{e}")
  }
  @debug.assert_eq(selected.artifacts.length(), 1)
  @debug.assert_eq(selected.manifest.length(), 1)
  @debug.assert_eq(selected.selected, 1)
  assert_true(selected.attempts >= 1)
  let v128_count = match
    @validate.validate_valid_feature_actual_count_by_label(
      selected.feature_stats,
      "v128",
    ) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  assert_true(v128_count >= 1)
}

///|
test "emit_gen_valid_batch_artifacts_until_features reports unmet floors" {
  let mems_floor = match
    @validate.validate_valid_feature_floor_by_label("mems", 1) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  match
    emit_gen_valid_batch_artifacts_until_features(
      1,
      0x5eedUL,
      emit_gen_valid_batch_config(),
      [mems_floor],
      [],
      3,
    ) {
    Ok(_) => fail("expected impossible feature floor to fail")
    Err(msg) => {
      assert_true(msg.contains("unmet feature floors after 3 attempts"))
      assert_true(msg.contains("mems actual=0 min=1"))
    }
  }
}

///|
test "emit_gen_valid_batch_to_dir writes opt-in manifest for selected modules" {
  let v128_floor = match
    @validate.validate_valid_feature_floor_by_label("v128", 1) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  let out_dir = ".tmp/fuzz-main-wbtest-gen-valid-manifest"
  let manifest_path = "\{out_dir}/manifest.json"
  let selection = match
    emit_gen_valid_batch_to_dir(
      EmitGenValidBatchArgs::new(
        1,
        0xf71004UL,
        out_dir,
        profile="coverage-forced",
        required_features=[v128_floor],
        max_attempts=8,
        manifest_path=Some(manifest_path),
      ),
    ) {
    Ok(v) => v
    Err(e) => fail("expected manifest-backed gen-valid selection, got \{e}")
  }
  @debug.assert_eq(selection.selected, 1)
  let manifest = match read_file_sync(manifest_path) {
    Ok(v) => v
    Err(e) => fail("expected manifest file to exist, got \{e}")
  }
  assert_true(manifest.contains("\"generator\":\"gen-valid\""))
  assert_true(manifest.contains("\"profile\":\"coverage-forced\""))
  assert_true(manifest.contains("\"file_name\":\"gen-valid-000001.wasm\""))
  assert_true(manifest.contains("\"validated\":true"))
  assert_true(manifest.contains("\"feature_stats\":"))
  assert_true(manifest.contains("\"stream_derivations\":"))
  assert_true(manifest.contains("\"label\":\"module-topology\""))
  assert_true(manifest.contains("\"label\":\"globals\""))
  assert_true(manifest.contains("\"label\":\"tags\""))
  assert_true(manifest.contains("\"label\":\"start\""))
  assert_true(manifest.contains("\"label\":\"bodies\""))
  assert_true(manifest.contains("\"derived_seed\":"))
}

///|
test "golden seed catalog schema records deterministic coverage contract" {
  let schema = golden_seed_catalog_schema_json()
  assert_true(
    schema.contains("\"schema\":\"starshine.fuzz.golden-seed-catalog.v1\""),
  )
  assert_true(schema.contains("\"seed\""))
  assert_true(schema.contains("\"suite\""))
  assert_true(schema.contains("\"profile\""))
  assert_true(schema.contains("\"expected_counters\""))
  assert_true(schema.contains("\"covered_surfaces\""))
  assert_true(schema.contains("\"artifacts\""))
  assert_true(schema.contains("\"notes\""))
  assert_true(
    schema.contains(
      "\"required\":[\"id\",\"suite\",\"profile\",\"seed\",\"expected_counters\",\"covered_surfaces\"]",
    ),
  )
  assert_true(
    schema.contains(
      "\"counter_value_kind\":\"exact-or-minimum-nonnegative-integer\"",
    ),
  )
}

///|
test "golden seed smoke suite catalog covers major deterministic surfaces" {
  let catalog = golden_seed_smoke_suite_catalog()
  @debug.assert_eq(catalog.length(), 7)
  let expected_ids = [
    "gen-valid-coverage-forced-smoke", "invalid-ast-repro-smoke", "invalid-binary-repro-smoke",
    "invalid-text-repro-smoke", "pass-fuzz-metadata-smoke", "minimization-repro-smoke",
    "wast-roundtrip-smoke",
  ]
  let mut i = 0
  while i < expected_ids.length() {
    @debug.assert_eq(catalog[i].id, expected_ids[i])
    @debug.assert_eq(catalog[i].seed > 0UL, true)
    assert_true(catalog[i].covered_surfaces.length() >= 2)
    i += 1
  }
  assert_true(catalog[0].covered_surfaces.contains("GenValid"))
  assert_true(catalog[0].artifacts.contains("inputs/gen-valid/manifest.json"))
  assert_true(catalog[1].covered_surfaces.contains("invalid-ast"))
  assert_true(catalog[2].covered_surfaces.contains("invalid-binary"))
  assert_true(catalog[3].covered_surfaces.contains("invalid-text"))
  assert_true(catalog[4].covered_surfaces.contains("pass-fuzz-metadata"))
  assert_true(catalog[5].covered_surfaces.contains("minimization"))
  assert_true(catalog[6].covered_surfaces.contains("text"))
}

///|
test "golden seed smoke suite catalog formats checked-in json document" {
  let json = format_golden_seed_catalog_json(golden_seed_smoke_suite_catalog())
  assert_true(
    json.contains("\"schema\":\"starshine.fuzz.golden-seed-catalog.v1\""),
  )
  assert_true(json.contains("\"entries\":["))
  assert_true(json.contains("\"id\":\"gen-valid-coverage-forced-smoke\""))
  assert_true(json.contains("\"id\":\"invalid-ast-repro-smoke\""))
  assert_true(json.contains("\"id\":\"invalid-binary-repro-smoke\""))
  assert_true(json.contains("\"id\":\"invalid-text-repro-smoke\""))
  assert_true(json.contains("\"id\":\"pass-fuzz-metadata-smoke\""))
  assert_true(json.contains("\"id\":\"minimization-repro-smoke\""))
  assert_true(json.contains("\"id\":\"wast-roundtrip-smoke\""))
}

///|
test "golden seed smoke report includes catalog ids and asserted counter counts" {
  let text = format_fuzz_golden_seed_smoke_report(
    FuzzGoldenSeedSmokeReport::new(
      "starshine.fuzz-golden-seed-smoke.v1",
      "smoke",
      0x5eedL,
      [
        FuzzGoldenSeedSmokeCase::new(
          "validate-valid",
          "smoke",
          0xf71004L,
          0,
          128,
          true,
          details_json=Some("{\"validated\":128}"),
          catalog_entry_id=Some("gen-valid-coverage-forced-smoke"),
          expected_counter_count=2,
        ),
      ],
    ),
  )
  assert_true(text.contains("catalog_entry_id=gen-valid-coverage-forced-smoke"))
  assert_true(text.contains("expected_counters=2"))
}

///|
test "golden seed catalog example formats expected counters and surfaces" {
  let entry = GoldenSeedCatalogEntry::new(
    "gen-valid-smoke-v128",
    "validate-valid",
    "smoke",
    0x5eedUL,
    expected_counters=[GoldenSeedExpectedCounter::minimum("features.v128", 1)],
    covered_surfaces=["GenValid", "v128"],
    artifacts=["result.json"],
    notes="stable v128 smoke seed",
  )
  let json = format_golden_seed_catalog_entry_json(entry)
  assert_true(json.contains("\"id\":\"gen-valid-smoke-v128\""))
  assert_true(json.contains("\"suite\":\"validate-valid\""))
  assert_true(json.contains("\"profile\":\"smoke\""))
  assert_true(json.contains("\"seed\":24301"))
  assert_true(json.contains("\"kind\":\"minimum\""))
  assert_true(json.contains("\"name\":\"features.v128\""))
  assert_true(json.contains("\"value\":1"))
  assert_true(json.contains("\"covered_surfaces\":[\"GenValid\",\"v128\"]"))
  assert_true(json.contains("\"artifacts\":[\"result.json\"]"))
  assert_true(json.contains("\"notes\":\"stable v128 smoke seed\""))
}

///|
test "gen-valid batch manifest stream derivations roundtrip through parser" {
  let args = EmitGenValidBatchArgs::new(
    1,
    0x51034UL,
    ".tmp/fuzz-main-wbtest-gen-valid-stream-roundtrip",
    profile="coverage-forced",
    max_attempts=4,
  )
  let selection = match emit_gen_valid_batch_selection(args) {
    Ok(v) => v
    Err(e) => fail("expected gen-valid selection, got \{e}")
  }
  let manifest = format_gen_valid_batch_manifest_json(args, selection)
  let derivations = match
    parse_gen_valid_batch_manifest_stream_derivations(manifest) {
    Ok(v) => v
    Err(e) => fail("expected stream derivation manifest parse, got \{e}")
  }
  @debug.assert_eq(
    derivations.length(),
    gen_valid_random_stream_labels().length(),
  )
  @debug.assert_eq(derivations[0].label, "module-topology")
  @debug.assert_eq(
    derivations[0].derived_seed,
    gen_valid_derive_stream_seed(0x51034UL, gen_valid_random_stream_labels()[0]),
  )
  let mut saw_harness = false
  for derivation in derivations {
    if derivation.label == "harness-shuffling" {
      saw_harness = true
      @debug.assert_eq(
        derivation.derived_seed,
        emit_gen_valid_batch_harness_stream_seed(0x51034UL),
      )
    }
  }
  assert_true(saw_harness)
}

///|
test "gen-valid batch candidate seeds come from harness-shuffling stream" {
  let first = emit_gen_valid_batch_candidate_seed(0x51034UL, 1)
  let first_again = emit_gen_valid_batch_candidate_seed(0x51034UL, 1)
  let second = emit_gen_valid_batch_candidate_seed(0x51034UL, 2)
  let other_root = emit_gen_valid_batch_candidate_seed(0x51035UL, 1)
  @debug.assert_eq(first, first_again)
  assert_true(first != second)
  assert_true(first != other_root)
  assert_true(first != (0x51034UL ^ 1UL))
}

///|
test "emit_gen_valid_batch_to_dir creates the output directory for selected modules" {
  let v128_floor = match
    @validate.validate_valid_feature_floor_by_label("v128", 1) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  let out_dir = ".tmp/fuzz-main-wbtest-gen-valid-batch"
  let selection = match
    emit_gen_valid_batch_to_dir(
      EmitGenValidBatchArgs::new(
        1,
        0xf71004UL,
        out_dir,
        profile="coverage-forced",
        required_features=[v128_floor],
        max_attempts=8,
      ),
    ) {
    Ok(v) => v
    Err(e) => fail("expected directory-backed gen-valid selection, got \{e}")
  }
  @debug.assert_eq(selection.selected, 1)
  let files = match list_files_recursive(out_dir) {
    Ok(v) => v
    Err(e) => fail("expected output directory to exist, got \{e}")
  }
  assert_true(files.length() >= 1)
}

///|
test "emit_gen_valid_batch_artifacts returns deterministic validated wasm files" {
  let first = match emit_gen_valid_batch_artifacts(2, 0x5eedUL) {
    Ok(v) => v
    Err(e) => fail("expected gen-valid artifacts success, got \{e}")
  }
  let second = match emit_gen_valid_batch_artifacts(2, 0x5eedUL) {
    Ok(v) => v
    Err(e) => fail("expected second gen-valid artifacts success, got \{e}")
  }
  @debug.assert_eq(first.length(), 2)
  @debug.assert_eq(first, second)
  @debug.assert_eq(first[0].0, "gen-valid-000001.wasm")
  @debug.assert_eq(first[1].0, "gen-valid-000002.wasm")
  for artifact in first {
    assert_true(artifact.1.length() > 0)
    let decoded = match decode_module(artifact.1) {
      Ok(v) => v
      Err(e) => fail("expected generated artifact to decode, got \{e}")
    }
    match validate_module(decoded) {
      Ok(_) => ()
      Err(e) =>
        fail(
          "expected generated artifact to validate, got \{validation_error_message(e)}",
        )
    }
  }
}

///|
test "emit_gen_valid_batch_artifacts matches the pinned Binaryen-oracle generator config" {
  let config = emit_gen_valid_batch_config()
  @debug.assert_eq(config.max_imports, 0)
  @debug.assert_eq(config.max_tables, 0)
  @debug.assert_eq(config.max_mems, 0)
  @debug.assert_eq(config.max_globals, 0)
  @debug.assert_eq(config.max_tags, 0)
  @debug.assert_eq(config.max_elems, 0)
  @debug.assert_eq(config.max_datas, 0)
  assert_false(config.features.allow_imports)
  assert_false(config.features.allow_tables)
  assert_false(config.features.allow_mems)
  assert_false(config.features.allow_globals)
  assert_false(config.features.allow_ref_types)
  assert_false(config.features.allow_v128)
  assert_false(config.features.allow_tags)
  assert_false(config.features.allow_elems)
  assert_false(config.features.allow_datas)
  assert_false(config.features.allow_call_indirect)
  assert_false(config.features.allow_tail_calls)
  assert_false(config.features.allow_memory64)
  let artifacts = match emit_gen_valid_batch_artifacts(1, 0x5eedUL) {
    Ok(v) => v
    Err(e) => fail("expected gen-valid artifact success, got \{e}")
  }
  let direct = match
    gen_valid_module_result_from_seed(
      emit_gen_valid_batch_candidate_seed(0x5eedUL, 1),
      config,
    ) {
    Ok(generated) => generated.wasm_module
    Err(failure) => failure.last_candidate
  }
  let encoded = match encode_module(direct) {
    Ok(v) => v
    Err(e) =>
      fail(
        "expected direct Binaryen-oracle gen-valid module to encode, got \{e}",
      )
  }
  @debug.assert_eq(artifacts[0].1, encoded)
}

///|
test "fuzz suite inventory separates active and reserved suite ids" {
  @debug.assert_eq(fuzz_active_suite_names(), [
    "wast-roundtrip", "wat-roundtrip", "wast-validate-roundtrip", "gen-valid-wat-validate-roundtrip",
    "valid-multi-module-linking", "validate-valid", "validate-valid-metamorphic",
    "validate-invalid-ast", "validate-invalid-binary", "validate-invalid-text", "validate-invalid-text-dynamic",
    "validate-invalid-spec-seed", "binary-roundtrip", "cmd-harness",
  ])
  @debug.assert_eq(fuzz_reserved_suite_names(), [])
  @debug.assert_eq(fuzz_suite_inventory_lines(), [
    "active\twast-roundtrip", "active\twat-roundtrip", "active\twast-validate-roundtrip",
    "active\tgen-valid-wat-validate-roundtrip", "active\tvalid-multi-module-linking",
    "active\tvalidate-valid", "active\tvalidate-valid-metamorphic", "active\tvalidate-invalid-ast",
    "active\tvalidate-invalid-binary", "active\tvalidate-invalid-text", "active\tvalidate-invalid-text-dynamic",
    "active\tvalidate-invalid-spec-seed", "active\tbinary-roundtrip", "active\tcmd-harness",
  ])
}

///|
test "fuzz usage text distinguishes active and reserved suites" {
  let usage = fuzz_usage_text()
  assert_true(
    usage.contains(
      "active suites: wast-roundtrip, wat-roundtrip, wast-validate-roundtrip, gen-valid-wat-validate-roundtrip, valid-multi-module-linking, validate-valid, validate-valid-metamorphic, validate-invalid-ast, validate-invalid-binary, validate-invalid-text, validate-invalid-text-dynamic, validate-invalid-spec-seed, binary-roundtrip, cmd-harness",
    ),
  )
  assert_true(usage.contains("reserved suite ids: (none)"))
  assert_true(usage.contains("portable coverage-forced batch"))
  assert_true(usage.contains("--emit-invalid-repro"))
}

///|
test "cmd-harness suite accepts broad executable pass profiles" {
  let each = match fuzz_cmd_harness_pass_profile("each-pass") {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  assert_true(each.length() > 20)
  assert_true(each.contains("dead-code-elimination"))
  assert_true(each.contains("local-cse"))
  assert_true(each.contains("directize"))
  assert_false(each.contains("optimize"))
  assert_false(each.contains("no-inline"))

  let clusters = match fuzz_cmd_harness_pass_profile("common-clusters") {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  assert_true(clusters.contains("dead-code-elimination"))
  assert_true(clusters.contains("remove-unused-names"))
  assert_true(clusters.contains("merge-blocks"))
  assert_true(clusters.contains("vacuum"))
  assert_false(clusters.contains("optimize-instructions"))
  assert_false(clusters.contains("dae-optimizing"))
  assert_false(clusters.contains("inlining-optimizing"))

  let default_pipeline = match
    fuzz_cmd_harness_pass_profile("default-pipeline") {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  assert_true(default_pipeline.length() > 20)
  assert_true(default_pipeline.contains("memory-packing"))
  assert_true(default_pipeline.contains("directize"))
  assert_false(default_pipeline.contains("optimize"))
}

///|
test "cmd-harness suite accepts GenValid and pass profile modifiers" {
  let result = match
    run_fuzz_suite(
      "cmd-harness", "smoke+gen=natural-small+passes=cleanup+codec-idempotence",
      -42L,
    ) {
    Ok([single]) => single
    Ok(_) => fail("expected exactly one suite result")
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(result.suite, "cmd-harness")
  @debug.assert_eq(
    result.profile,
    "smoke+gen=natural-small+passes=cleanup+codec-idempotence",
  )
  assert_true(result.attempts >= 1)
}

///|
test "format_fuzz_suite_result supports jsonl output" {
  let parsed = parse_fuzz_cli_args(["--jsonl"])
  let result = match run_fuzz_suite("cmd-harness", "smoke", -42L) {
    Ok([single]) => single
    Ok(_) => fail("expected exactly one suite result")
    Err(msg) => fail(msg)
  }
  let line = format_fuzz_suite_result(result, parsed.output_mode)
  assert_true(line.contains("\"suite\":\"cmd-harness\""))
  assert_true(line.contains("\"profile\":\"smoke\""))
  assert_true(line.contains("\"seed\":-42"))
  assert_true(line.contains("\"attempts\":128"))
  assert_true(line.contains("\"pass\":true"))
  assert_true(line.contains("\"elapsed_ms\":"))
}

///|
test "run_fuzz_suite routes validate-invalid-ast profile errors through the AST invalid runner" {
  match run_fuzz_suite("validate-invalid-ast", "not-a-profile", 0x5eedL) {
    Ok(_) => fail("expected validate-invalid-ast profile error")
    Err(msg) => {
      assert_true(msg.contains("unknown validate-invalid-ast fuzz profile"))
      assert_false(msg.contains("reserved"))
      assert_false(msg.contains("unknown suite"))
    }
  }
}

///|
test "run_fuzz_suite routes validate-invalid-binary profile errors through the binary invalid runner" {
  match run_fuzz_suite("validate-invalid-binary", "not-a-profile", 0x5eedL) {
    Ok(_) => fail("expected validate-invalid-binary profile error")
    Err(msg) => {
      assert_true(msg.contains("unknown validate-invalid-binary fuzz profile"))
      assert_false(msg.contains("reserved"))
      assert_false(msg.contains("unknown suite"))
    }
  }
}

///|
test "run_fuzz_suite routes validate-invalid-text profile errors through the text invalid runner" {
  match run_fuzz_suite("validate-invalid-text", "not-a-profile", 0x5eedL) {
    Ok(_) => fail("expected validate-invalid-text profile error")
    Err(msg) => {
      assert_true(msg.contains("unknown validate-invalid-text fuzz profile"))
      assert_false(msg.contains("reserved"))
      assert_false(msg.contains("unknown suite"))
    }
  }
}

///|
test "run_fuzz_suite routes validate-invalid-text-dynamic through dynamic GenValid WAT runner" {
  let result = match
    run_fuzz_suite("validate-invalid-text-dynamic", "smoke", 0x5eedL) {
    Ok([single]) => single
    Ok(_) => fail("expected exactly one dynamic invalid text suite result")
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(result.suite, "validate-invalid-text-dynamic")
  @debug.assert_eq(result.profile, "smoke")
  @debug.assert_eq(result.attempts, 48)
  match result.details_json {
    Some(details) => {
      assert_true(details.contains("dynamic-gen-valid-missing-closing-paren"))
      assert_true(details.contains("dynamic-gen-valid-duplicate-export"))
      assert_true(details.contains("dynamic-gen-valid-bad-opcode-token"))
      assert_true(details.contains("dynamic-gen-valid-bad-type-token"))
      assert_true(details.contains("dynamic-gen-valid-bad-lane-index"))
      assert_true(details.contains("dynamic-gen-valid-bad-memarg-align"))
      assert_true(details.contains("dynamic-gen-valid-bad-table-index"))
      assert_true(details.contains("mutation:bad-table-index"))
      assert_true(
        details.contains("dynamic-gen-valid-mutable-global-const-init"),
      )
      assert_true(details.contains("dynamic-gen-valid-bad-export-string"))
      assert_true(details.contains("dynamic-gen-valid-bad-start-type"))
      assert_true(details.contains("dynamic-gen-valid-unknown-import"))
      assert_true(details.contains("dynamic-gen-valid-unknown-memory-import"))
      assert_true(details.contains("source:gen-valid-wat"))
      assert_true(details.contains("mutation:mutable-global-const-init"))
      assert_true(details.contains("mutation:bad-export-string"))
      assert_true(details.contains("mutation:bad-start-type"))
      assert_true(details.contains("mutation:unknown-import"))
      assert_true(details.contains("mutation:unknown-memory-import"))
      assert_true(details.contains("\"stream_label\":\"text-mutation-choice\""))
      assert_true(details.contains("\"stream_seed\":"))
      assert_true(
        details.contains("\"variant_id\":\"gen-valid-wat/duplicate-export\""),
      )
    }
    None => fail("expected dynamic invalid text suite details")
  }
}

///|
test "run_fuzz_suite routes validate-invalid-text-dynamic profile errors through dynamic runner" {
  match
    run_fuzz_suite("validate-invalid-text-dynamic", "not-a-profile", 0x5eedL) {
    Ok(_) => fail("expected validate-invalid-text-dynamic profile error")
    Err(msg) => {
      assert_true(
        msg.contains("unknown validate-invalid-text dynamic fuzz profile"),
      )
      assert_false(msg.contains("reserved"))
      assert_false(msg.contains("unknown suite"))
    }
  }
}

///|
test "run_fuzz_suite routes validate-invalid-spec-seed profile errors through the spec-seed runner" {
  match run_fuzz_suite("validate-invalid-spec-seed", "not-a-profile", 0x5eedL) {
    Ok(_) => fail("expected validate-invalid-spec-seed profile error")
    Err(msg) => {
      assert_true(
        msg.contains("unknown validate-invalid-spec-seed fuzz profile"),
      )
      assert_false(msg.contains("reserved"))
      assert_false(msg.contains("unknown suite"))
    }
  }
}

///|
test "run_fuzz_suite returns error for unknown suite" {
  match run_fuzz_suite("not-a-suite", "smoke", 0x5eedL) {
    Ok(_) => fail("expected unknown suite error")
    Err(msg) => assert_true(msg.contains("unknown suite"))
  }
}

///|
test "run_fuzz_suite routes binary-roundtrip to binary runner" {
  match run_fuzz_suite("binary-roundtrip", "not-a-profile", 0x5eedL) {
    Ok(_) => fail("expected binary profile error")
    Err(msg) => {
      assert_true(msg.contains("binary fuzz profile"))
      assert_false(msg.contains("unknown suite"))
    }
  }
}

///|
test "run_fuzz_suite reports arbitrary binary coverage details" {
  match run_fuzz_suite("binary-roundtrip", "smoke", 0x5eedL) {
    Ok(results) => {
      @debug.assert_eq(results.length(), 1)
      let result = results[0]
      @debug.assert_eq(result.attempts, 2944)
      match result.details_json {
        Some(details) => {
          assert_true(details.contains("\"arbitrary_roundtrips\":2944"))
          assert_true(details.contains("\"instruction_roundtrips\":1024"))
          assert_true(details.contains("\"section_roundtrips\":224"))
          assert_true(details.contains("\"immediate_roundtrips\":1208"))
        }
        None => fail("expected binary roundtrip details json")
      }
    }
    Err(msg) =>
      fail("expected arbitrary binary roundtrip suite success: \{msg}")
  }
}

///|
test "run_fuzz_suite reports GenValid binary roundtrip details" {
  match run_fuzz_suite("binary-roundtrip", "gen-valid-smoke", 0x5eedL) {
    Ok(results) => {
      @debug.assert_eq(results.length(), 1)
      let result = results[0]
      @debug.assert_eq(result.attempts, 8)
      match result.details_json {
        Some(details) => {
          assert_true(details.contains("\"arbitrary_roundtrips\":0"))
          assert_true(details.contains("\"gen_valid_modules\":8"))
          assert_true(details.contains("\"gen_valid_validated\":8"))
          assert_true(details.contains("\"byte_fuzz_cases\":0"))
          assert_true(details.contains("\"byte_fuzz_decode_rejections\":0"))
          assert_true(details.contains("\"instruction_roundtrips\":0"))
          assert_true(details.contains("\"section_roundtrips\":0"))
          assert_true(details.contains("\"immediate_roundtrips\":0"))
        }
        None => fail("expected binary roundtrip details json")
      }
    }
    Err(msg) => fail("expected GenValid binary roundtrip suite success: \{msg}")
  }
}

///|
test "run_fuzz_suite reports byte-fuzz binary roundtrip details" {
  match run_fuzz_suite("binary-roundtrip", "byte-fuzz-smoke", 0x5eedL) {
    Ok(results) => {
      @debug.assert_eq(results.length(), 1)
      let result = results[0]
      @debug.assert_eq(result.attempts, 16)
      match result.details_json {
        Some(details) => {
          assert_true(details.contains("\"byte_fuzz_cases\":16"))
          assert_true(details.contains("\"byte_fuzz_decode_rejections\":"))
          assert_true(details.contains("\"byte_fuzz_decode_accepts\":"))
          assert_true(details.contains("\"boundary_roundtrips\":0"))
          assert_true(details.contains("\"instruction_roundtrips\":0"))
          assert_true(details.contains("\"section_roundtrips\":0"))
          assert_true(details.contains("\"immediate_roundtrips\":0"))
        }
        None => fail("expected binary roundtrip details json")
      }
    }
    Err(msg) =>
      fail("expected byte-fuzz binary roundtrip suite success: \{msg}")
  }
}

///|
test "run_fuzz_suite reports boundary corpus binary roundtrip details" {
  match run_fuzz_suite("binary-roundtrip", "boundary-smoke", 0x5eedL) {
    Ok(results) => {
      @debug.assert_eq(results.length(), 1)
      let result = results[0]
      @debug.assert_eq(result.attempts, 40)
      match result.details_json {
        Some(details) => {
          assert_true(details.contains("\"boundary_roundtrips\":40"))
          assert_true(details.contains("\"arbitrary_roundtrips\":0"))
          assert_true(details.contains("\"byte_fuzz_cases\":0"))
          assert_true(details.contains("\"instruction_roundtrips\":0"))
        }
        None => fail("expected binary roundtrip details json")
      }
    }
    Err(msg) =>
      fail("expected boundary corpus binary roundtrip suite success: \{msg}")
  }
}

///|
test "run_fuzz_suite routes validate-valid profile errors through the validator runner" {
  match run_fuzz_suite("validate-valid", "not-a-profile", 0x5eedL) {
    Ok(_) => fail("expected validate-valid profile error")
    Err(msg) => {
      assert_true(msg.contains("unknown validate-valid fuzz profile"))
      assert_false(msg.contains("unknown suite"))
    }
  }
}
