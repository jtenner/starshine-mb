///|
test "r1 tooling optimizer JSON escapes valid Wasm name control characters" {
  assert_eq(cmd_optimizer_json_string("\u{0001}"), "\"\\u0001\"")
}

///|
test "r1 tooling optimizer JSON escapes every control and preserves Unicode" {
  let expected = [
    "\\u0000", "\\u0001", "\\u0002", "\\u0003", "\\u0004", "\\u0005",
    "\\u0006", "\\u0007", "\\u0008", "\\t", "\\n", "\\u000b",
    "\\u000c", "\\r", "\\u000e", "\\u000f", "\\u0010", "\\u0011",
    "\\u0012", "\\u0013", "\\u0014", "\\u0015", "\\u0016", "\\u0017",
    "\\u0018", "\\u0019", "\\u001a", "\\u001b", "\\u001c", "\\u001d",
    "\\u001e", "\\u001f",
  ]
  for code = 0; code < 32; code = code + 1 {
    let text = StringBuilder()
    text.write_char(code.unsafe_to_char())
    assert_eq(cmd_optimizer_json_string(text.to_string()), "\"\{expected[code]}\"")
  }
  let text = "quote\" slash\\ LF\n CR\r tab\t é中文😀\u{007f}\u{0085}\u{2028}\u{2029}"
  assert_eq(
    cmd_optimizer_json_string(text),
    "\"quote\\\" slash\\\\ LF\\n CR\\r tab\\t é中文😀\u{007f}\u{0085}\u{2028}\u{2029}\"",
  )
  assert_eq(@json.parse(cmd_optimizer_json_string(text)).as_string(), Some(text))
  assert_eq(cmd_optimizer_json_string(""), "\"\"")
}
