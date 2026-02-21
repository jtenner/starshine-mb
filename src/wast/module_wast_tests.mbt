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

///|
test "module_to_wast preserves descriptor instruction keywords" {
  let src =
    #|(module
    #|  (func (param funcref) (result i32)
    #|    (drop (ref.get_desc (local.get 0)))
    #|    (drop (ref.test_desc 0 (local.get 0)))
    #|    (drop (ref.test_desc_null 0 (local.get 0)))
    #|    (drop (ref.cast_desc_eq 0 (local.get 0)))
    #|    (drop (ref.cast_desc_eq_null 0 (local.get 0)))
    #|    (i32.const 0)))
  let mod = match wast_to_module(src) {
    Ok(m) => m
    Err(e) => fail("unexpected parse error: \{e}")
  }
  let text = match module_to_wast(mod) {
    Ok(t) => t
    Err(e) => fail("unexpected print error: \{e}")
  }
  assert_true(text.contains("ref.get_desc"))
  assert_true(text.contains("ref.test_desc 0"))
  assert_true(text.contains("ref.test_desc_null 0"))
  assert_true(text.contains("ref.cast_desc_eq 0"))
  assert_true(text.contains("ref.cast_desc_eq_null 0"))
}

///|
test "wast_to_module malformed fixtures return targeted parse diagnostics" {
  let fixtures : Array[(String, String, String, String)] = [
    (
      "unknown module field", "(module (oops))", "expected module field", "field-fixture.wast",
    ),
    (
      "import missing descriptor", "(module (import \"env\" \"f\" ()))", "expected import descriptor",
      "import-fixture.wast",
    ),
    (
      "memory missing minimum limit", "(module (memory))", "expected minimum limit",
      "memory-fixture.wast",
    ),
    (
      "mutable global missing value type", "(module (global (mut) (i32.const 0)))",
      "expected value type", "global-fixture.wast",
    ),
    (
      "incomplete module expression", "(module (func", "expected ')'", "eof-fixture.wast",
    ),
  ]
  for fixture in fixtures {
    let (name, source, detail, filename) = fixture
    match wast_to_module(source, filename~) {
      Ok(_) => fail("expected malformed module fixture '\{name}' to fail")
      Err(msg) => {
        assert_true(msg.contains(detail))
        assert_true(msg.contains(filename))
        assert_true(msg.contains(":1"))
      }
    }
  }
}
