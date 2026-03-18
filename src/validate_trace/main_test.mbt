///|
test "validate trace corpus names stay fixed" {
  assert_eq(validate_trace_corpus_names(), [
    "deep-control", "wide-locals", "large-codesec", "ref-func-heavy",
  ])
}

///|
test "validate trace benchmark captures summary lines" {
  let results = match run_validate_trace_benchmark(["deep-control"], 1) {
    Ok(items) => items
    Err(e) => fail("unexpected validate trace benchmark error: \{e}")
  }
  assert_eq(results.length(), 1)
  let result = results[0]
  assert_eq(result.corpus, "deep-control")
  assert_eq(result.repeats, 1)
  assert_true(result.elapsed_ms > 0UL)
  assert_true(result.phase_totals.has_prefix("phase_totals"))
  assert_true(result.helper_totals.has_prefix("helper_totals"))
  match result.hotspots {
    Some(line) => assert_true(line.has_prefix("hotspots "))
    None => fail("expected hotspot summary for deep-control corpus")
  }
}

///|
test "validate trace benchmark rejects unknown corpus" {
  match run_validate_trace_benchmark(["not-a-corpus"], 1) {
    Ok(_) => fail("expected unknown corpus to fail")
    Err(e) => assert_true(e.contains("unknown validate-trace corpus"))
  }
}

///|
test "parse validate trace cli command accepts repeat and repeated corpora" {
  let parsed = parse_validate_trace_cli_command([
    "--repeat", "2", "--corpus", "deep-control", "--corpus", "wide-locals",
  ])
  match parsed {
    ValidateTraceCliCommand::Run(args) => {
      assert_eq(args.repeats, 2)
      assert_eq(args.corpora, ["deep-control", "wide-locals"])
    }
    _ => fail("expected run command")
  }
}

///|
test "parse validate trace cli command supports list-corpora" {
  match parse_validate_trace_cli_command(["--list-corpora"]) {
    ValidateTraceCliCommand::ListCorpora => ()
    _ => fail("expected list-corpora command")
  }
}
