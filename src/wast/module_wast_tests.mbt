///|
test "wast_to_module parse errors include filename and line" {
  match wast_to_module("(module (func", filename="sample.wast") {
    Ok(_) => fail("expected parse error for incomplete module text")
    Err(msg) => {
      assert_true(msg.contains("sample.wast"))
      assert_true(msg.contains(":1"))
    }
  }
}

///|
test "script_to_wast escapes register names and can be parsed back" {
  let script : WastScript = { commands: [Register("line\nbreak", None)] }
  let text = match script_to_wast(script) {
    Ok(t) => t
    Err(e) => fail("unexpected script_to_wast error: \{e}")
  }
  assert_true(text.contains("\\n"))
  assert_true(text.contains("(register"))
  let parsed = match wast_to_script("(module)") {
    Ok(s) => s
    Err(e) => fail("unexpected wast_to_script error: \{e}")
  }
  assert_eq(parsed.commands.length(), 1)
}
