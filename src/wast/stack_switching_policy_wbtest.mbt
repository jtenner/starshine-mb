///|
test "core tag assertions reject result-bearing declarations and imports" {
  // Keep the command identities of tests/spec/tag.wast: the two core-invalid
  // declarations are commands 4 and 5, after ordinary definitions/imports.
  let source =
    #|(module (tag (export "tag") (param i32)))
    #|(register "test")
    #|(module (import "test" "tag" (tag (param i32))))
    #|(assert_invalid (module (tag (result i32))) "non-empty tag result type")
    #|(assert_invalid (module (import "" "" (tag (result i32)))) "non-empty tag result type")
  let report = run_wast_spec_file("tests/spec/tag.wast", source)
  match report.status {
    Passed => ()
    Skipped(reason) => fail("core tag validation was skipped: \{reason}")
    Failed(reason) => fail("core tag validation failed: \{reason}")
  }
  @debug.assert_eq(report.total_commands, 5)
  @debug.assert_eq(report.checked_commands, 4)
  @debug.assert_eq(report.skipped_commands, 1)
  @debug.assert_eq(report.blocked_commands, 0)
  for command_index in [3, 4] {
    let command_report = report.command_reports[command_index]
    @debug.assert_eq(command_report.command_index, command_index)
    match command_report.status {
      Passed => ()
      other =>
        fail(
          "expected core tag assertion checked, got \{@debug.to_string(other)}",
        )
    }
  }
}

///|
test "core module directives enforce the same tag policy as invalid assertions" {
  for
    source in [
      "(module (tag (result i32)))", "(module (import \"\" \"\" (tag (result i32))))",
    ] {
    let report = run_wast_spec_file("tests/spec/tag.wast", source)
    match report.status {
      Failed(_) => ()
      other =>
        fail(
          "expected core tag module rejected, got \{@debug.to_string(other)}",
        )
    }
    @debug.assert_eq(report.skipped_commands, 0)
    @debug.assert_eq(report.blocked_commands, 0)
  }
}

///|
test "stack switching remains enabled for user and proposal scripts" {
  let source =
    #|(module (tag (result i32)))
    #|(module (import "" "" (tag (result i32))))
  for path in ["user.wast", "tests/spec/proposals/stack-switching/tag.wast"] {
    let report = run_wast_spec_file(path, source)
    match report.status {
      Passed => ()
      other =>
        fail(
          "expected suspension tags supported, got \{@debug.to_string(other)}",
        )
    }
    @debug.assert_eq(report.checked_commands, 2)
    @debug.assert_eq(report.skipped_commands, 0)
  }
}

///|
test "legacy core scripts enforce the empty-result exception tag rule" {
  let source =
    #|(assert_invalid (module (tag (result i32))) "non-empty tag result type")
    #|(assert_invalid (module (import "" "" (tag (result i32)))) "non-empty tag result type")
  let report = run_wast_spec_file("tests/spec/legacy/tag.wast", source)
  match report.status {
    Passed => ()
    other =>
      fail(
        "expected legacy core assertions checked, got \{@debug.to_string(other)}",
      )
  }
  @debug.assert_eq(report.checked_commands, 2)
  @debug.assert_eq(report.skipped_commands, 0)
}
