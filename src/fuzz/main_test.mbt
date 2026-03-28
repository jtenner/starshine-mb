///|
using @binary {decode_module}

///|
using @validate {validate_module, validation_error_message}

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
