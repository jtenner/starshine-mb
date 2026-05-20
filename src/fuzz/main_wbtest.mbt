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
  let direct = gen_valid_module_with_config(
    @splitmix.new(seed=0x5eedUL),
    config,
  )
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
    "wast-roundtrip", "wat-roundtrip", "validate-valid", "validate-invalid-ast",
    "validate-invalid-binary", "validate-invalid-text", "validate-invalid-spec-seed",
    "binary-roundtrip", "cmd-harness",
  ])
  @debug.assert_eq(fuzz_reserved_suite_names(), [])
  @debug.assert_eq(fuzz_suite_inventory_lines(), [
    "active\twast-roundtrip", "active\twat-roundtrip", "active\tvalidate-valid",
    "active\tvalidate-invalid-ast", "active\tvalidate-invalid-binary", "active\tvalidate-invalid-text",
    "active\tvalidate-invalid-spec-seed", "active\tbinary-roundtrip", "active\tcmd-harness",
  ])
}

///|
test "fuzz usage text distinguishes active and reserved suites" {
  let usage = fuzz_usage_text()
  assert_true(
    usage.contains(
      "active suites: wast-roundtrip, wat-roundtrip, validate-valid, validate-invalid-ast, validate-invalid-binary, validate-invalid-text, validate-invalid-spec-seed, binary-roundtrip, cmd-harness",
    ),
  )
  assert_true(usage.contains("reserved suite ids: (none)"))
  assert_true(usage.contains("portable coverage-forced batch"))
  assert_true(usage.contains("--emit-invalid-repro"))
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
test "run_fuzz_suite routes validate-valid profile errors through the validator runner" {
  match run_fuzz_suite("validate-valid", "not-a-profile", 0x5eedL) {
    Ok(_) => fail("expected validate-valid profile error")
    Err(msg) => {
      assert_true(msg.contains("unknown validate-valid fuzz profile"))
      assert_false(msg.contains("unknown suite"))
    }
  }
}
