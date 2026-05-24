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
test "parse_fuzz_cli_args accepts seed sweep, shard, and report flags" {
  let parsed = parse_fuzz_cli_args([
    "cmd-harness", "smoke", "--seed=0x10", "--seed-count", "5", "--shard-index",
    "1", "--shard-count", "2", "--report-json", "tmp/fuzz-report.json",
  ])
  @debug.assert_eq(parsed.suite, "cmd-harness")
  @debug.assert_eq(parsed.profile, "smoke")
  @debug.assert_eq(parsed.seed_i64, 0x10L)
  @debug.assert_eq(parsed.seed_count, 5)
  @debug.assert_eq(parsed.shard_index, 1)
  @debug.assert_eq(parsed.shard_count, 2)
  @debug.assert_eq(parsed.report_json_path, Some("tmp/fuzz-report.json"))
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
  assert_true(report.contains("\"runs\":["))
  assert_true(report.contains("\"seed_index\":0"))
  assert_true(report.contains("\"seed_index\":1"))
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
    }
    _ => fail("expected emit-gen-valid-batch command")
  }
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
    "validate-valid", "validate-invalid-ast", "validate-invalid-binary", "validate-invalid-text",
    "validate-invalid-text-dynamic", "validate-invalid-spec-seed", "binary-roundtrip",
    "cmd-harness",
  ])
  @debug.assert_eq(fuzz_reserved_suite_names(), [])
  @debug.assert_eq(fuzz_suite_inventory_lines(), [
    "active\twast-roundtrip", "active\twat-roundtrip", "active\twast-validate-roundtrip",
    "active\tgen-valid-wat-validate-roundtrip", "active\tvalidate-valid", "active\tvalidate-invalid-ast",
    "active\tvalidate-invalid-binary", "active\tvalidate-invalid-text", "active\tvalidate-invalid-text-dynamic",
    "active\tvalidate-invalid-spec-seed", "active\tbinary-roundtrip", "active\tcmd-harness",
  ])
}

///|
test "fuzz usage text distinguishes active and reserved suites" {
  let usage = fuzz_usage_text()
  assert_true(
    usage.contains(
      "active suites: wast-roundtrip, wat-roundtrip, wast-validate-roundtrip, gen-valid-wat-validate-roundtrip, validate-valid, validate-invalid-ast, validate-invalid-binary, validate-invalid-text, validate-invalid-text-dynamic, validate-invalid-spec-seed, binary-roundtrip, cmd-harness",
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
  @debug.assert_eq(result.attempts, 20)
  match result.details_json {
    Some(details) => {
      assert_true(details.contains("dynamic-gen-valid-missing-closing-paren"))
      assert_true(details.contains("dynamic-gen-valid-duplicate-export"))
      assert_true(details.contains("dynamic-gen-valid-bad-opcode-token"))
      assert_true(details.contains("dynamic-gen-valid-bad-lane-index"))
      assert_true(details.contains("dynamic-gen-valid-bad-memarg-align"))
      assert_true(details.contains("source:gen-valid-wat"))
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
