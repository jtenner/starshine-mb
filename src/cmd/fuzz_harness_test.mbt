///|
fn encode_fixture_module(value : Int) -> Bytes {
  let text = "(module (func (result i32) i32.const \{value}))"
  let mod = match @wast.wast_to_binary_module(text, filename="fixture.wat") {
    Ok(v) => v
    Err(e) => abort("unexpected fixture parse failure: \{e}")
  }
  match @binary.encode_module(mod) {
    Ok(bytes) => bytes
    Err(e) => abort("unexpected fixture encode failure: \{e}")
  }
}

///|
test "differential_validate_wasm returns report when all validators agree" {
  let bytes = encode_fixture_module(11)
  let adapters = DifferentialAdapters::new(
    wasm_tools_validate=fn(_) { Ok(true) },
    binaryen_validate=fn(_) { Ok(true) },
  )
  let report = match differential_validate_wasm(bytes, adapters~) {
    Ok(v) => v
    Err(e) => fail("expected differential agreement, got \{e}")
  }
  assert_true(report.internal_valid)
  assert_eq(report.wasm_tools_valid, Some(true))
  assert_eq(report.binaryen_valid, Some(true))
}

///|
test "differential_validate_wasm reports mismatch when wasm-tools diverges" {
  let bytes = encode_fixture_module(17)
  let adapters = DifferentialAdapters::new(
    wasm_tools_validate=fn(_) { Ok(false) },
    binaryen_validate=fn(_) { Ok(true) },
  )
  match differential_validate_wasm(bytes, adapters~) {
    Ok(report) =>
      fail("expected wasm-tools mismatch error, got success report \{report}")
    Err(msg) => {
      assert_true(msg.contains("wasm-tools"))
      assert_true(msg.contains("internal=true"))
    }
  }
}

///|
test "run_wasm_smith_fuzz_harness smoke covers full pipeline" {
  let stats = match run_wasm_smith_fuzz_harness(128, seed=0x5eedUL) {
    Ok(v) => v
    Err(e) => fail("expected fuzz harness smoke success, got \{e}")
  }
  assert_eq(stats.generated_valid, 128)
  assert_eq(stats.pipeline_validated, 128)
  assert_eq(stats.optimized, 128)
  assert_eq(stats.roundtripped, 128)
}

///|
#cfg(target="native")
test "differential_validate_wasm agrees with installed wasm-tools and binaryen validators" {
  let (has_wasm_tools, has_binaryen) = native_differential_tools_available()
  if !has_wasm_tools && !has_binaryen {
    return
  }
  let bytes = encode_fixture_module(23)
  let report = match differential_validate_wasm(bytes) {
    Ok(v) => v
    Err(e) => fail("expected native differential agreement, got \{e}")
  }
  assert_true(report.internal_valid)
  if has_wasm_tools {
    assert_eq(report.wasm_tools_valid, Some(true))
  }
  if has_binaryen {
    assert_eq(report.binaryen_valid, Some(true))
  }
}

///|
#cfg(target="native")
test "run_wasm_smith_fuzz_harness validates one hundred thousand generated modules" {
  let stats = match
    run_wasm_smith_fuzz_harness(100000, seed=0x5eed5eedUL, optimize_passes=[]) {
    Ok(v) => v
    Err(e) => fail("expected 100k fuzz harness success, got \{e}")
  }
  assert_true(stats.generated_valid >= 100000)
  assert_eq(stats.pipeline_validated, stats.generated_valid)
  assert_eq(stats.optimized, stats.generated_valid)
  assert_eq(stats.roundtripped, stats.generated_valid)
}
