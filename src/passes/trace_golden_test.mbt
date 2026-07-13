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
      "pipeline:start requested=1", "pass[vacuum]:mutated funcs=1", "pass[vacuum]:funcs count=1 changed=1",
      "pipeline:done",
    ]),
  )
}

///|
test "vacuum trace batches mutated function summaries" {
  let fixture =
    #|(module
    #|  (func nop)
    #|  (func nop)
    #|  (func nop))
    #|
  let trace = match pass_test_capture_trace(fixture, ["vacuum"]) {
    Ok(lines) => lines
    Err(err) => fail("expected pass trace capture success, got \{err}")
  }

  let per_func_mutations = trace.filter(fn(line) {
    line.contains("pass[vacuum]:mutated count=")
  })
  @debug.assert_eq(per_func_mutations.length(), 0)
  @debug.assert_eq(
    pass_trace_join_lines(trace),
    pass_trace_join_lines([
      "pipeline:start requested=1", "pass[vacuum]:mutated funcs=3", "pass[vacuum]:funcs count=3 changed=3",
      "pipeline:done",
    ]),
  )
}
