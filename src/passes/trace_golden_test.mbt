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

  assert_eq(
    pass_trace_join_lines(trace),
    pass_trace_join_lines([
      "pipeline:start requested=1", "pass[vacuum]:start", "pass[vacuum]:mutated revision=6",
      "pass[vacuum]:mutated revision=7", "pass[vacuum]:done changed=true", "pipeline:done",
    ]),
  )
}
