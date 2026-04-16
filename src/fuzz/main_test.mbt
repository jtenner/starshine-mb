///|
using @binary {decode_module, encode_module}

///|
using @validate {
  type GenValidConfig,
  gen_valid_module_with_config,
  validate_module,
  validation_error_message,
}

///|
test "parse_fuzz_cli_args defaults to all smoke seed" {
  let parsed = parse_fuzz_cli_args([])
  assert_eq(parsed.suite, "all")
  assert_eq(parsed.profile, "smoke")
  match parsed.output_mode {
    Text => ()
    _ => fail("expected text output mode")
  }
  assert_eq(parsed.seed, parsed.seed_i64.reinterpret_as_uint64())
}

///|
test "parse_fuzz_cli_args accepts suite profile and hex seed" {
  let parsed = parse_fuzz_cli_args(["wat-roundtrip", "ci", "0x1234"])
  assert_eq(parsed.suite, "wat-roundtrip")
  assert_eq(parsed.profile, "ci")
  assert_eq(parsed.seed_i64, 0x1234L)
  assert_eq(parsed.seed, 0x1234UL)
}

///|
test "parse_fuzz_cli_args accepts --seed with equals" {
  let parsed = parse_fuzz_cli_args(["wat-roundtrip", "ci", "--seed=0x99"])
  assert_eq(parsed.suite, "wat-roundtrip")
  assert_eq(parsed.profile, "ci")
  assert_eq(parsed.seed_i64, 0x99L)
}

///|
test "parse_fuzz_cli_args accepts --seed and negative value" {
  let parsed = parse_fuzz_cli_args(["validate-valid", "smoke", "--seed", "-42"])
  assert_eq(parsed.suite, "validate-valid")
  assert_eq(parsed.profile, "smoke")
  assert_eq(parsed.seed_i64, -42L)
  assert_eq(parsed.seed, (-42L).reinterpret_as_uint64())
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
      assert_eq(args.count, 2)
      assert_eq(args.seed, 0x5eedUL)
      assert_eq(args.out_dir, "tmp/gen-valid")
    }
    _ => fail("expected emit-gen-valid-batch command")
  }
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
  assert_eq(first.length(), 2)
  assert_eq(first, second)
  assert_eq(first[0].0, "gen-valid-000001.wasm")
  assert_eq(first[1].0, "gen-valid-000002.wasm")
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
test "emit_gen_valid_batch_artifacts matches the pinned coverage-forced generator config" {
  let artifacts = match emit_gen_valid_batch_artifacts(1, 0x5eedUL) {
    Ok(v) => v
    Err(e) => fail("expected gen-valid artifact success, got \{e}")
  }
  let direct = gen_valid_module_with_config(
    @splitmix.new(seed=0x5eedUL),
    GenValidConfig::coverage_forced_default(),
  )
  let encoded = match encode_module(direct) {
    Ok(v) => v
    Err(e) => fail("expected direct coverage-forced module to encode, got \{e}")
  }
  assert_eq(artifacts[0].1, encoded)
}

///|
test "fuzz suite inventory separates active and reserved suite ids" {
  assert_eq(fuzz_active_suite_names(), [
    "wast-roundtrip", "wat-roundtrip", "validate-valid", "validate-invalid-ast",
    "validate-invalid-binary", "validate-invalid-text", "validate-invalid-spec-seed",
    "binary-roundtrip", "cmd-harness",
  ])
  assert_eq(fuzz_reserved_suite_names(), [])
  assert_eq(fuzz_suite_inventory_lines(), [
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
  assert_true(usage.contains("coverage-forced batch"))
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
