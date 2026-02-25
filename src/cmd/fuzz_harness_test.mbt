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
fn bytes_to_ascii(bytes : Bytes) -> String {
  let out = StringBuilder::new()
  for b in bytes {
    out.write_char(b.to_int().unsafe_to_char())
  }
  out.to_string()
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
test "minimize_fuzz_passes greedily removes non-essential pass names" {
  let minimized = minimize_fuzz_passes(
    ["flatten", "vacuum", "de-nan", "vacuum"],
    fn(passes) { passes.contains("de-nan") },
  )
  assert_eq(minimized, ["de-nan"])
}

///|
test "persist_fuzz_failure_report writes deterministic corpus artifacts" {
  let ensured_dirs : Array[String] = []
  let writes : Array[(String, Bytes)] = []
  let io = FuzzFailurePersistIO::new(
    ensure_dir=fn(path) {
      ensured_dirs.push(path)
      Ok(())
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let report = FuzzFailureReport::new(
    0x5eedUL,
    13,
    7,
    "differential mismatch",
    "validator mismatch",
    optimize_passes=["flatten", "vacuum"],
    minimized_passes=["vacuum"],
    wasm=Some(encode_fixture_module(33)),
  )
  let (meta_path, wasm_path) = match
    persist_fuzz_failure_report(report, io, corpus_dir="tmp-corpus") {
    Ok(v) => v
    Err(e) => fail("expected artifact persistence success, got \{e}")
  }
  assert_eq(ensured_dirs, ["tmp-corpus"])
  assert_true(meta_path.contains("seed-24301"))
  match wasm_path {
    Some(path) => assert_true(path.contains(".wasm"))
    None => fail("expected wasm artifact path")
  }
  assert_eq(writes.length(), 2)
  let mut saw_meta = false
  let mut saw_wasm = false
  for entry in writes {
    let path = entry.0
    let bytes = entry.1
    if path.contains(".meta.txt") {
      saw_meta = true
      let text = bytes_to_ascii(bytes)
      assert_true(text.contains("seed=24301"))
      assert_true(text.contains("optimize_passes=flatten,vacuum"))
      assert_true(text.contains("minimized_passes=vacuum"))
    } else if path.contains(".wasm") {
      saw_wasm = true
      assert_true(bytes.length() > 0)
    }
  }
  assert_true(saw_meta)
  assert_true(saw_wasm)
}

///|
test "run_wasm_smith_fuzz_harness emits failure report on differential mismatch" {
  let reports : Array[FuzzFailureReport] = []
  let adapters = DifferentialAdapters::new(
    wasm_tools_validate=fn(_) { Ok(false) },
    binaryen_validate=fn(_) { Ok(true) },
  )
  match
    run_wasm_smith_fuzz_harness(
      1,
      seed=0xA11CUL,
      optimize_passes=[ModulePass::Vacuum],
      optimize_pass_names=Some(["vacuum"]),
      differential_adapters=Some(adapters),
      differential_every=1,
      on_failure=Some(fn(report) {
        reports.push(report)
        Ok(())
      }),
    ) {
    Ok(stats) =>
      fail("expected differential mismatch failure, got success stats \{stats}")
    Err(msg) => {
      assert_true(msg.contains("differential validation failed"))
      assert_true(msg.contains("module #1"))
    }
  }
  assert_eq(reports.length(), 1)
  let report = reports[0]
  assert_eq(report.seed, 0xA11CUL)
  assert_eq(report.stage, "differential")
  assert_eq(report.optimize_passes, ["vacuum"])
  match report.wasm {
    Some(bytes) => assert_true(bytes.length() > 0)
    None => fail("expected captured failing wasm bytes")
  }
}

///|
test "run_wasm_smith_fuzz_harness includes callback failure diagnostics" {
  let adapters = DifferentialAdapters::new(
    wasm_tools_validate=fn(_) { Ok(false) },
    binaryen_validate=fn(_) { Ok(true) },
  )
  match
    run_wasm_smith_fuzz_harness(
      1,
      seed=1234UL,
      differential_adapters=Some(adapters),
      differential_every=1,
      on_failure=Some(fn(_) { Err("disk full") }),
    ) {
    Ok(stats) =>
      fail("expected differential mismatch failure, got success stats \{stats}")
    Err(msg) => {
      assert_true(msg.contains("differential validation failed"))
      assert_true(msg.contains("disk full"))
    }
  }
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
