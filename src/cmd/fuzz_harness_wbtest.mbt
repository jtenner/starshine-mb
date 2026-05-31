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
  @debug.assert_eq(report.wasm_tools_valid, Some(true))
  @debug.assert_eq(report.binaryen_valid, Some(true))
  @debug.assert_eq(report.per_case_timeout_ms, None)
  assert_true(!report.wasm_tools_timeout)
  assert_true(!report.binaryen_timeout)
}

///|
test "FUZ1052B1 export invocation classifier covers result matrix" {
  @debug.assert_eq(
    classify_export_invocation_results(
      ExportInvocationResult::value("i32:7"),
      ExportInvocationResult::value("i32:7"),
    ),
    ExportInvocationClassification::equal_result(),
  )
  @debug.assert_eq(
    classify_export_invocation_results(
      ExportInvocationResult::trap("unreachable"),
      ExportInvocationResult::trap("integer divide by zero"),
    ),
    ExportInvocationClassification::equal_trap(),
  )
  @debug.assert_eq(
    classify_export_invocation_results(
      ExportInvocationResult::unsupported_runtime("missing wasm-tools run"),
      ExportInvocationResult::value("i32:7"),
    ),
    ExportInvocationClassification::unsupported_runtime(),
  )
  @debug.assert_eq(
    classify_export_invocation_results(
      ExportInvocationResult::nondeterministic_import("env.now"),
      ExportInvocationResult::value("i32:7"),
    ),
    ExportInvocationClassification::nondeterministic_import(),
  )
  @debug.assert_eq(
    classify_export_invocation_results(
      ExportInvocationResult::value("i32:7"),
      ExportInvocationResult::value("i32:8"),
    ),
    ExportInvocationClassification::semantic_mismatch(
      "value mismatch: left=i32:7 right=i32:8",
    ),
  )
}

///|
test "FUZ1052B2 simple export invocation args cover numeric params" {
  let args = match
    choose_simple_export_invocation_args([
      @lib.ValType::i32(),
      @lib.ValType::i64(),
      @lib.ValType::f32(),
      @lib.ValType::f64(),
    ]) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(args, ["i32:0", "i64:0", "f32:0", "f64:0"])
  match choose_simple_export_invocation_args([@lib.ValType::v128()]) {
    Ok(v) => fail("expected unsupported vector param, got \{@debug.to_string(v)}")
    Err(msg) => assert_true(msg.contains("unsupported export param type"))
  }
}

///|
test "FUZ1052B3 export invocation comparison report retains context" {
  let report = compare_export_invocation_results(
    "run",
    ["i32:0"],
    ExportInvocationResult::value("i32:1"),
    ExportInvocationResult::value("i32:2"),
  )
  @debug.assert_eq(report.export_name, "run")
  @debug.assert_eq(report.args, ["i32:0"])
  @debug.assert_eq(report.left_result, ExportInvocationResult::value("i32:1"))
  @debug.assert_eq(report.right_result, ExportInvocationResult::value("i32:2"))
  @debug.assert_eq(
    report.classification,
    ExportInvocationClassification::semantic_mismatch(
      "value mismatch: left=i32:1 right=i32:2",
    ),
  )
}

///|
test "FUZ1052B4 export invocation matrix summary counts classifications" {
  let reports = [
    compare_export_invocation_results(
      "ok", [], ExportInvocationResult::value("i32:1"), ExportInvocationResult::value("i32:1"),
    ),
    compare_export_invocation_results(
      "trap", [], ExportInvocationResult::trap("left"), ExportInvocationResult::trap("right"),
    ),
    compare_export_invocation_results(
      "unsupported", [], ExportInvocationResult::unsupported_runtime("missing"), ExportInvocationResult::value("i32:1"),
    ),
    compare_export_invocation_results(
      "nondet", [], ExportInvocationResult::nondeterministic_import("env.now"), ExportInvocationResult::value("i32:1"),
    ),
    compare_export_invocation_results(
      "bad", [], ExportInvocationResult::value("i32:1"), ExportInvocationResult::value("i32:2"),
    ),
  ]
  let summary = summarize_export_invocation_matrix(reports)
  @debug.assert_eq(summary.total, 5)
  @debug.assert_eq(summary.equal_results, 1)
  @debug.assert_eq(summary.equal_traps, 1)
  @debug.assert_eq(summary.unsupported_runtimes, 1)
  @debug.assert_eq(summary.nondeterministic_imports, 1)
  @debug.assert_eq(summary.semantic_mismatches, 1)
}

///|
test "FUZ1053A3 differential adapters classify per-case timeout results" {
  let bytes = encode_fixture_module(23)
  let adapters = DifferentialAdapters::new(
    wasm_tools_validate=fn(_) { Err("process timed out after budget") },
    binaryen_validate=fn(_) { Err("resource limit exceeded") },
    per_case_timeout_ms=Some(250),
  )
  let report = match differential_validate_wasm(bytes, adapters~) {
    Ok(v) => v
    Err(e) => fail("expected timeout classification report, got \{e}")
  }
  assert_true(report.internal_valid)
  @debug.assert_eq(report.wasm_tools_valid, None)
  @debug.assert_eq(report.binaryen_valid, None)
  @debug.assert_eq(report.per_case_timeout_ms, Some(250))
  assert_true(report.wasm_tools_timeout)
  assert_true(report.binaryen_timeout)
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
test "run_cmd_fuzz_harness supports zero-target configuration" {
  let stats = match run_cmd_fuzz_harness(0, seed=0x5eedUL) {
    Ok(v) => v
    Err(e) => fail("expected zero-target harness success, got \{e}")
  }
  @debug.assert_eq(stats.attempts, 0)
  @debug.assert_eq(stats.generated_valid, 0)
  @debug.assert_eq(stats.generated_invalid, 0)
}

///|
test "run_cmd_fuzz_harness_profile rejects unknown profile" {
  match run_cmd_fuzz_harness_profile("not-a-profile", 0x5eedUL) {
    Ok(_) => fail("expected unknown profile error")
    Err(msg) => assert_true(msg.contains("unknown cmd-harness fuzz profile"))
  }
}

///|
test "cmd harness profile config accepts GenValid and pass profile modifiers" {
  let config = match
    cmd_fuzz_harness_profile_config(
      "smoke+gen=natural-small+passes=cleanup+idempotence+codec-idempotence",
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(config.valid_target, 128)
  @debug.assert_eq(config.generator_profile, "natural-small")
  @debug.assert_eq(config.pass_profile, "cleanup")
  @debug.assert_eq(config.optimize_passes, ["vacuum", "remove-unused-brs"])
  assert_true(config.check_optimize_idempotence)
  assert_true(config.check_encode_decode_idempotence)
}

///|
test "cmd harness profile config expands broad executable pass profiles" {
  let each = match cmd_fuzz_harness_profile_config("smoke+passes=each-pass") {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  assert_true(each.optimize_passes.length() > 20)
  assert_true(each.optimize_passes.contains("dead-code-elimination"))
  assert_true(each.optimize_passes.contains("local-cse"))
  assert_true(each.optimize_passes.contains("directize"))
  assert_false(each.optimize_passes.contains("optimize"))
  assert_false(each.optimize_passes.contains("shrink"))
  assert_false(each.optimize_passes.contains("no-inline"))
  assert_false(each.optimize_passes.contains("flatten"))

  let clusters = match
    cmd_fuzz_harness_profile_config("smoke+passes=common-clusters") {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(clusters.pass_profile, "common-clusters")
  assert_true(clusters.optimize_passes.contains("dead-code-elimination"))
  assert_true(clusters.optimize_passes.contains("remove-unused-names"))
  assert_true(clusters.optimize_passes.contains("merge-blocks"))
  assert_true(clusters.optimize_passes.contains("vacuum"))
  assert_false(clusters.optimize_passes.contains("optimize-instructions"))
  assert_false(clusters.optimize_passes.contains("dae-optimizing"))
  assert_false(clusters.optimize_passes.contains("inlining-optimizing"))

  let default_pipeline = match
    cmd_fuzz_harness_profile_config("smoke+passes=default-pipeline") {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  assert_true(default_pipeline.optimize_passes.length() > 20)
  assert_true(default_pipeline.optimize_passes.contains("memory-packing"))
  assert_true(default_pipeline.optimize_passes.contains("directize"))
  assert_false(default_pipeline.optimize_passes.contains("optimize"))
}

///|
test "run_cmd_fuzz_harness can exercise selected GenValid profile and idempotence checks" {
  let stats = match
    run_cmd_fuzz_harness(
      1,
      seed=0x5eedUL,
      generator_profile="natural-small",
      optimize_passes=["vacuum"],
      check_optimize_idempotence=true,
      check_encode_decode_idempotence=true,
    ) {
    Ok(v) => v
    Err(e) => fail("expected profiled harness success, got \{e}")
  }
  @debug.assert_eq(stats.generated_valid, 1)
  @debug.assert_eq(stats.generator_profile, "natural-small")
  @debug.assert_eq(stats.pass_profile, "custom")
  @debug.assert_eq(stats.optimize_idempotence_checked, 1)
  @debug.assert_eq(stats.encode_decode_idempotence_checked, 1)
}

///|
test "cmd harness profile config reports pathological GenValid budgets" {
  let config = match
    cmd_fuzz_harness_profile_config("smoke+gen=pathological-valid") {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(config.generator_profile, "pathological-valid")
  match config.generator_config.max_rec_group_size_budget {
    Some(limit) => assert_true(limit >= 1)
    None => fail("expected pathological rec-group budget")
  }
  match config.generator_config.max_section_count_budget {
    Some(limit) => assert_true(limit >= 8)
    None => fail("expected pathological section-count budget")
  }
}

///|
test "minimize_fuzz_passes greedily removes non-essential pass names" {
  let minimized = minimize_fuzz_passes(
    ["flatten", "vacuum", "de-nan", "vacuum"],
    fn(passes) { passes.contains("de-nan") },
  )
  @debug.assert_eq(minimized, ["de-nan"])
}

///|
test "minimize_fuzz_passes can remove dependent chunks before single-pass cleanup" {
  let minimized = minimize_fuzz_passes(
    ["frontier-a", "frontier-b", "trigger", "tail"],
    fn(passes) {
      passes.contains("trigger") &&
      passes.contains("frontier-a") == passes.contains("frontier-b")
    },
  )
  @debug.assert_eq(minimized, ["trigger"])
}

///|
test "fuzz corpus dedup index records source and duplicate decisions by hash" {
  let index = FuzzCorpusDedupIndex::new()
  let first = FuzzCorpusSource::new(
    0x5eedUL, 1, "natural-wide", "cleanup", "roundtrip",
  )
  let second = FuzzCorpusSource::new(
    0xbeefUL, 2, "natural-small", "none", "differential",
  )
  let wasm = encode_fixture_module(33)
  let first_decision = index.record(wasm, first)
  let second_decision = index.record(wasm, second)
  @debug.assert_eq(first_decision.duplicate, false)
  @debug.assert_eq(second_decision.duplicate, true)
  @debug.assert_eq(second_decision.canonical_seed, Some(0x5eedUL))
  let text = index.to_text()
  assert_true(text.contains("version=1"))
  assert_true(text.contains("hash="))
  assert_true(
    text.contains(
      "source seed=24301 attempt=1 generator_profile=natural-wide pass_profile=cleanup stage=roundtrip duplicate=false canonical_seed=24301",
    ),
  )
  assert_true(
    text.contains(
      "source seed=48879 attempt=2 generator_profile=natural-small pass_profile=none stage=differential duplicate=true canonical_seed=24301",
    ),
  )
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
    generator_config_label="natural-small",
    generated_attempts=2,
    feature_facts="has_call=false;uses_v128=false",
    wasm=Some(encode_fixture_module(33)),
  )
  let (meta_path, wasm_path) = match
    persist_fuzz_failure_report(report, io, corpus_dir="tmp-corpus") {
    Ok(v) => v
    Err(e) => fail("expected artifact persistence success, got \{e}")
  }
  @debug.assert_eq(ensured_dirs, ["tmp-corpus"])
  assert_true(meta_path.contains("seed-24301"))
  match wasm_path {
    Some(path) => assert_true(path.contains(".wasm"))
    None => fail("expected wasm artifact path")
  }
  @debug.assert_eq(writes.length(), 2)
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
      assert_true(text.contains("generator_config_label=natural-small"))
      assert_true(text.contains("generated_attempts=2"))
      assert_true(text.contains("feature_facts=has_call=false;uses_v128=false"))
    } else if path.contains(".wasm") {
      saw_wasm = true
      assert_true(bytes.length() > 0)
    }
  }
  assert_true(saw_meta)
  assert_true(saw_wasm)
}

///|
test "run_cmd_fuzz_harness emits failure report on differential mismatch" {
  let reports : Array[FuzzFailureReport] = []
  let adapters = DifferentialAdapters::new(
    wasm_tools_validate=fn(_) { Ok(false) },
    binaryen_validate=fn(_) { Ok(true) },
  )
  match
    run_cmd_fuzz_harness(
      1,
      seed=0x5eedUL,
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
  @debug.assert_eq(reports.length(), 1)
  let report = reports[0]
  @debug.assert_eq(report.seed, 0x5eedUL)
  @debug.assert_eq(report.stage, "differential")
  @debug.assert_eq(report.optimize_passes, [])
  match report.wasm {
    Some(bytes) => assert_true(bytes.length() > 0)
    None => fail("expected captured failing wasm bytes")
  }
}

///|
test "run_cmd_fuzz_harness includes callback failure diagnostics" {
  let adapters = DifferentialAdapters::new(
    wasm_tools_validate=fn(_) { Ok(false) },
    binaryen_validate=fn(_) { Ok(true) },
  )
  match
    run_cmd_fuzz_harness(
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
test "run_cmd_fuzz_harness reports explicit hot pass names on optimize failure" {
  let reports : Array[FuzzFailureReport] = []
  match
    run_cmd_fuzz_harness(
      1,
      seed=0x5eedUL,
      optimize_passes=[
        "vacuum", "global-struct-inference-desc-cast", "remove-unused-brs",
      ],
      on_failure=Some(fn(report) {
        reports.push(report)
        Ok(())
      }),
    ) {
    Ok(stats) =>
      fail("expected optimize failure for boundary-only pass, got \{stats}")
    Err(msg) => {
      assert_true(msg.contains("global-struct-inference-desc-cast"))
      assert_true(msg.contains("boundary-only"))
    }
  }
  @debug.assert_eq(reports.length(), 1)
  @debug.assert_eq(reports[0].stage, "optimize")
  @debug.assert_eq(reports[0].optimize_passes, [
    "vacuum", "global-struct-inference-desc-cast", "remove-unused-brs",
  ])
  @debug.assert_eq(reports[0].minimized_passes, [
    "global-struct-inference-desc-cast",
  ])
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
    @debug.assert_eq(report.wasm_tools_valid, Some(true))
  }
  if has_binaryen {
    @debug.assert_eq(report.binaryen_valid, Some(true))
  }
}
