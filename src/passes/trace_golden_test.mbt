///|
fn pass_trace_join_lines(lines : Array[String]) -> String {
  let out = StringBuilder::new()
  for i = 0; i < lines.length(); i = i + 1 {
    if i > 0 {
      out.write_string("\n")
    }
    out.write_string(lines[i])
  }
  out.to_string()
}

///|
test "pass test helpers capture deterministic vacuum trace lines" {
  let trace = match
    pass_test_capture_trace("(module (func (result i32) nop i32.const 9))", [
      "vacuum",
    ]) {
    Ok(lines) => lines
    Err(err) => fail("expected pass trace capture success, got \{err}")
  }

  @debug.assert_eq(
    pass_trace_join_lines(trace),
    pass_trace_join_lines([
      "pipeline:start requested=1", "pass[vacuum]:func func_idx=(Func 0)", "pass[vacuum]:start",
      "pass[vacuum]:mutated revision=6", "pass[vacuum]:mutated revision=7", "pass[vacuum]:done changed=true",
      "pipeline:done",
    ]),
  )
}

///|
test "stacked hot scheduler runs compatible passes per function" {
  let trace : Array[String] = []
  let fixture =
    #|(module
    #|  (func nop)
    #|  (func nop))
    #|
  match
    pass_test_run_pipeline(
      fixture,
      ["remove-unused-names", "remove-unused-names"],
      options=HotPipelineOptions::new(
        stack_function_passes=true,
        trace=Some(fn(line) { trace.push(line) }),
      ),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected stacked hot pipeline success, got \{err}")
  }
  let expected = [
    "pass[remove-unused-names]:func func_idx=(Func 0)", "pass[remove-unused-names]:func func_idx=(Func 0)",
    "pass[remove-unused-names]:func func_idx=(Func 1)",
  ]
  let mut cursor = 0
  for line in trace {
    if cursor < expected.length() && line == expected[cursor] {
      cursor += 1
    }
  }
  @debug.assert_eq(cursor, expected.length())
}
