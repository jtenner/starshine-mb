///|
test "unsigned seed batch command accepts high-bit hex and decimal roots" {
  for
    (text, expected) in [
      ("0x8000000000000000", 0x8000000000000000UL),
      ("9223372036854775808", 0x8000000000000000UL),
      ("0xed5d9aa4110c3cf5", 0xed5d9aa4110c3cf5UL),
      ("0xFFFFFFFFFFFFFFFF", 0xffffffffffffffffUL),
      ("18446744073709551615", 0xffffffffffffffffUL),
    ] {
    for seed_args in [["--seed", text], ["--seed=\{text}"]] {
      let args = ["--emit-gen-valid-batch", "--count", "1"]
      args.append(seed_args)
      args.append(["--out-dir", "tmp/unsigned-seed-regression"])
      match parse_fuzz_cli_command(args) {
        EmitGenValidBatch(parsed) => {
          @debug.assert_eq(parsed.seed, expected)
          @debug.assert_eq(parsed.count, 1)
          @debug.assert_eq(parsed.out_dir, "tmp/unsigned-seed-regression")
        }
        _ => fail("expected unsigned batch command")
      }
    }
  }
}

///|
test "unsigned seed random profile command keeps every seed bit" {
  for
    (text, expected) in [
      ("0x8000000000000000", 0x8000000000000000UL),
      ("18446744073709551615", 0xffffffffffffffffUL),
    ] {
    @debug.assert_eq(
      parse_fuzz_cli_command([
        "--resolve-random-pass-profile", "random-short", "--seed", text,
      ]),
      FuzzCliCommand::ResolveRandomPassProfile("random-short", expected),
    )
  }
}

///|
test "unsigned seed invalid repro command keeps high-bit replay roots" {
  for text in ["0xffffffffffffffff", "18446744073709551615"] {
    for seed_args in [["--seed", text], ["--seed=\{text}"]] {
      let args = [
        "--emit-invalid-repro", "--suite", "binary", "--strategy", "invalid-func-type-index",
        "--attempt", "1", "--out-dir", "tmp/unsigned-repro-regression",
      ]
      args.append(seed_args)
      match parse_fuzz_cli_command(args) {
        EmitInvalidRepro(parsed) => {
          @debug.assert_eq(parsed.seed, 0xffffffffffffffffUL)
          @debug.assert_eq(parsed.attempt, 1)
          @debug.assert_eq(parsed.strategy_id, "invalid-func-type-index")
        }
        _ => fail("expected unsigned invalid-repro command")
      }
    }
  }
}

///|
test "unsigned seed parser retains accepted low roots and zero spellings" {
  for
    (text, expected) in [
      ("0", 0UL),
      ("-0", 0UL),
      ("-0x0_0", 0UL),
      (" +0X5_eEd ", 0x5eedUL),
      ("9223372036854775807", 0x7fffffffffffffffUL),
      ("+18_446_744_073_709_551_615", 0xffffffffffffffffUL),
    ] {
    @debug.assert_eq(fuzz_parse_uint64(text), Ok(expected))
  }
}

///|
test "unsigned seed parser intentionally rejects overflow and negative roots" {
  for
    text in [
      "18446744073709551616", "0x10000000000000000", "999999999999999999999999999999999999999999",
    ] {
    match fuzz_parse_uint64(text) {
      Err(message) => assert_true(message.contains("out of range for uint64"))
      Ok(_) => fail("overflow must not wrap into a replay seed")
    }
  }
  for text in ["-1", "-0x1", "-9223372036854775808"] {
    @debug.assert_eq(fuzz_parse_uint64(text), Err("seed must be non-negative"))
  }
}

///|
test "unsigned seed parser intentionally rejects missing and malformed digits" {
  for text in ["", " ", "+", "-", "0x", "0X_", "_", "0xg", "1 2", "1.0", "0b10"] {
    match fuzz_parse_uint64(text) {
      Err(_) => ()
      Ok(_) => fail("invalid seed spelling must not become zero")
    }
  }
}

///|
test "unsigned seed repair preserves ordinary signed seed boundaries" {
  @debug.assert_eq(
    fuzz_parse_seed("0x7fffffffffffffff"),
    Ok(0x7fffffffffffffffL),
  )
  @debug.assert_eq(
    fuzz_parse_seed("-9223372036854775808"),
    Ok(-9223372036854775808L),
  )
  @debug.assert_eq(fuzz_parse_seed("-42"), Ok(-42L))
  for
    text in [
      "0x8000000000000000", "18446744073709551615", "-9223372036854775809",
    ] {
    match fuzz_parse_seed(text) {
      Err(message) => assert_true(message.contains("out of range for int64"))
      Ok(_) => fail("ordinary signed seeds must retain their Int64 boundary")
    }
  }
}

///|
test "unsigned seed batch reproduces an exact high-bit owner input in one slot" {
  let args = match
    parse_fuzz_cli_command([
      "--emit-gen-valid-batch", "--count", "1", "--seed", "0xed5d9aa4110c3cf5", "--gen-valid-profile",
      "heap2local-owner-updates", "--max-attempts", "1", "--out-dir", "tmp/unsigned-exact-owner",
    ]) {
    EmitGenValidBatch(args) => args
    _ => fail("expected unsigned batch command")
  }
  let selection = match emit_gen_valid_batch_selection(args) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  @debug.assert_eq(selection.selected, 1)
  @debug.assert_eq(selection.attempts, 1)
  @debug.assert_eq(selection.artifacts.length(), 1)
  @debug.assert_eq(selection.manifest.length(), 1)
  let record = selection.manifest[0]
  @debug.assert_eq(record.seed, 0xed5d9aa4110c3cf5UL)
  @debug.assert_eq(record.case_seed, 17103996989274389753UL)
  @debug.assert_eq(record.index, 1)
  @debug.assert_eq(record.wasm_hash, "fnv1a64-4d636d8f695dcee7")
  @debug.assert_eq(record.selected_profile, "heap2local-owner-updates")
  assert_true(record.validated)
  @debug.assert_eq(selection.artifacts[0].1.length(), 205)
  let wasm_module = match decode_module(selection.artifacts[0].1) {
    Ok(value) => value
    Err(message) => fail("generated replay must decode: \{message}")
  }
  match @validate.validate_module(wasm_module) {
    Ok(_) => ()
    Err(message) => fail("generated replay must validate: \{message}")
  }
}
