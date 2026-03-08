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
test "module_to_wast preserves table elem-abbreviation offsets and typed items" {
  let src =
    #|(module
    #|  (func $f)
    #|  (table 4 funcref (elem (i32.const 2) funcref (item (ref.null func)) (item (ref.func $f)))))
  let mod = match wast_to_module(src) {
    Ok(m) => m
    Err(e) =>
      fail("unexpected parse error for typed table elem-abbrev fixture: \{e}")
  }
  let text = match module_to_wast(mod) {
    Ok(t) => t
    Err(e) =>
      fail("unexpected print error for typed table elem-abbrev fixture: \{e}")
  }
  assert_true(text.contains("(i32.const 2)"))
  assert_true(text.contains("(item"))
  assert_true(text.contains("ref.null func"))
  assert_true(text.contains("ref.func $f"))
  match wast_to_module(text, filename="printed-table-typed-items.wat") {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected module_to_wast typed table elem-abbrev output to parse back: \{e}",
      )
  }
}

///|
test "module_to_wast preserves concrete typed-heap value types" {
  let src =
    #|(module
    #|  (type $t (func))
    #|  (func (param (ref $t)) (result (ref null $t))
    #|    (ref.null $t)))
  let mod = match wast_to_module(src) {
    Ok(m) => m
    Err(e) =>
      fail("unexpected parse error for typed-heap value-type fixture: \{e}")
  }
  let text = match module_to_wast(mod) {
    Ok(t) => t
    Err(e) =>
      fail("unexpected print error for typed-heap value-type fixture: \{e}")
  }
  assert_true(text.contains("(param (ref $t))"))
  assert_true(text.contains("(result (ref null $t))"))
  assert_true(text.contains("ref.null $t"))
  match wast_to_module(text, filename="printed-typed-heap-values.wat") {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected module_to_wast typed-heap value-type output to parse back: \{e}",
      )
  }
}

///|
test "module_to_wast preserves abstract non-func heap refs in value types and ref.null" {
  let src =
    #|(module
    #|  (func
    #|    (param (ref any) (ref eq) (ref i31) (ref none) (ref nofunc) (ref noextern) (ref noexn))
    #|    (result (ref null any) (ref null eq) (ref null i31) (ref null none) (ref null nofunc) (ref null noextern) (ref null noexn))
    #|    (ref.null any)
    #|    (ref.null eq)
    #|    (ref.null i31)
    #|    (ref.null none)
    #|    (ref.null nofunc)
    #|    (ref.null noextern)
    #|    (ref.null noexn)))
  let mod = match wast_to_module(src) {
    Ok(m) => m
    Err(e) =>
      fail(
        "unexpected parse error for abstract heap-kind value-type fixture: \{e}",
      )
  }
  let text = match module_to_wast(mod) {
    Ok(t) => t
    Err(e) =>
      fail(
        "unexpected print error for abstract heap-kind value-type fixture: \{e}",
      )
  }
  assert_true(text.contains("(ref any)"))
  assert_true(text.contains("(ref eq)"))
  assert_true(text.contains("(ref i31)"))
  assert_true(text.contains("(ref none)"))
  assert_true(text.contains("(ref nofunc)"))
  assert_true(text.contains("(ref noextern)"))
  assert_true(text.contains("(ref noexn)"))
  assert_true(text.contains("(ref null any)"))
  assert_true(text.contains("(ref null eq)"))
  assert_true(text.contains("(ref null i31)"))
  assert_true(text.contains("(ref null none)"))
  assert_true(text.contains("(ref null nofunc)"))
  assert_true(text.contains("(ref null noextern)"))
  assert_true(text.contains("(ref null noexn)"))
  assert_true(text.contains("ref.null any"))
  assert_true(text.contains("ref.null eq"))
  assert_true(text.contains("ref.null i31"))
  assert_true(text.contains("ref.null none"))
  assert_true(text.contains("ref.null nofunc"))
  assert_true(text.contains("ref.null noextern"))
  assert_true(text.contains("ref.null noexn"))
  match wast_to_module(text, filename="printed-abstract-heap-values.wat") {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected module_to_wast abstract heap-kind output to parse back: \{e}",
      )
  }
}

///|
test "module_to_wast preserves abstract heap refs across table global tag and import surfaces" {
  let src =
    #|(module
    #|  (type $tag_t (func (param (ref null noextern))))
    #|  (import "env" "itbl" (table 1 (ref null nofunc)))
    #|  (import "env" "ig" (global (mut (ref null any))))
    #|  (import "env" "itag" (tag (type $tag_t)))
    #|  (table 2 (ref null noextern))
    #|  (global (mut (ref null none)) (ref.null none))
    #|  (tag (type $tag_t)))
  let mod = match wast_to_module(src) {
    Ok(m) => m
    Err(e) =>
      fail(
        "unexpected parse error for abstract heap-kind module-surface fixture: \{e}",
      )
  }
  let text = match module_to_wast(mod) {
    Ok(t) => t
    Err(e) =>
      fail(
        "unexpected print error for abstract heap-kind module-surface fixture: \{e}",
      )
  }
  assert_true(text.contains("(table 1 (ref null nofunc))"))
  assert_true(text.contains("(global (mut (ref null any)))"))
  assert_true(text.contains("(tag (type $tag_t))"))
  assert_true(text.contains("(table 2 (ref null noextern))"))
  assert_true(text.contains("(global (mut (ref null none))"))
  assert_true(text.contains("ref.null none"))
  assert_true(text.contains("(param (ref null noextern))"))
  match
    wast_to_module(text, filename="printed-abstract-heap-module-surfaces.wat") {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected module_to_wast abstract heap-kind module-surface output to parse back: \{e}",
      )
  }
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
