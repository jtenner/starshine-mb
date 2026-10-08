///|
test "mass codec keeps UTF-8 data bytes from raw Unicode and Unicode escapes" {
  for
    (text, expected) in [
      ("é", b"\xc3\xa9"),
      ("漢", b"\xe6\xbc\xa2"),
      ("😀", b"\xf0\x9f\x98\x80"),
      ("\\u{e9}", b"\xc3\xa9"),
      ("\\u{6f22}", b"\xe6\xbc\xa2"),
      ("\\u{1f600}", b"\xf0\x9f\x98\x80"),
    ] {
    let mod_ = wast_to_binary_module(
      "(module (memory 1) (data (i32.const 0) \"\{text}\"))",
    ).unwrap()
    let @lib.Data(_, actual) = mod_.data_sec.unwrap().0[0]
    assert_eq(actual, expected)
    let decoded = @binary.decode_module(@binary.encode_module(mod_).unwrap()).unwrap()
    let @lib.Data(_, saved) = decoded.data_sec.unwrap().0[0]
    assert_eq(saved, expected)
  }
}

///|
test "mass codec decodes import and export name escapes" {
  let mod_ = wast_to_binary_module(
    "(module (import \"h\\6fst\" \"r\\75n\" (func $f)) (export \"g\\6f\" (func $f)))",
  ).unwrap()
  let @lib.Import(module_name, field_name, _) = mod_.import_sec.unwrap().0[0]
  let @lib.Export(export_name, _) = mod_.export_sec.unwrap().0[0]
  assert_eq(module_name, @lib.Name::new("host"))
  assert_eq(field_name, @lib.Name::new("run"))
  assert_eq(export_name, @lib.Name::new("go"))
  let inline = wast_to_binary_module("(module (func (export \"g\\6f\")))").unwrap()
  let @lib.Export(inline_name, _) = inline.export_sec.unwrap().0[0]
  assert_eq(inline_name, @lib.Name::new("go"))
}

///|
test "mass codec rejects intentionally invalid unsigned index overflow" {
  for
    source in [
      "(module (func (param i32) (result i32) local.get 4294967296))", "(module (func (param i32) (result i32) local.get 0x100000000))",
      "(module (func block br 4294967296 end))", "(module (func) (export \"f\" (func 4294967296)))",
      "(module (table 4294967296 funcref))", "(module (func (result i32) v128.const i32x4 0 0 0 0 i32x4.extract_lane 4294967296))",
    ] {
    // These indices exceed u32. They must not wrap to index or lane zero.
    assert_true(wast_to_module(source) is Err(_))
  }
}

///|
test "mass codec rejects intentionally invalid unsigned memarg overflow" {
  for
    immediate in [
      "offset=18446744073709551616", "offset=0x10000000000000000", "align=18446744073709551617",
    ] {
    // All values exceed u64. They must not wrap to a valid offset or alignment.
    assert_true(
      wast_to_module(
        "(module (memory 1) (func (result i32) i32.const 0 i32.load \{immediate}))",
      )
      is Err(_),
    )
  }
}

///|
test "mass codec rejects intentionally invalid text after a single module" {
  for source in ["(module) (module)", "(module) garbage"] {
    assert_true(wast_to_module(source) is Err(_))
  }
}

///|
test "mass codec rejects intentionally invalid skipped lexer characters" {
  // A comma is invalid WAT syntax. The lexer must not discard it silently.
  assert_true(wast_to_module("(module ,)") is Err(_))
}

///|
test "mass codec rejects intentionally invalid inline explicit type mismatches" {
  let matching = wast_to_binary_module(
    "(module (type (func (param i32))) (func (type 0) (param i32)))",
  ).unwrap()
  assert_eq(matching.func_sec.unwrap().0, [@lib.TypeIdx::new(0U)])
  for
    source in [
      "(module (type (func (param i32))) (func (type 0) (param f32)))", "(module (type (func)) (func (type 0) (result i32) unreachable))",
    ] {
    // Lowering must not discard the inline signature and hide the mismatch.
    assert_true(wast_to_binary_module(source) is Err(_))
  }
}

///|
test "mass codec keeps Unicode escapes with digit separators" {
  for
    (text, expected) in [
      ("\\u{e_9}", b"\xc3\xa9"),
      ("\\u{0_0_e_9}", b"\xc3\xa9"),
      ("\\u{6_f_2_2}", b"\xe6\xbc\xa2"),
      ("\\u{1f_600}", b"\xf0\x9f\x98\x80"),
    ] {
    let mod_ = wast_to_binary_module(
      "(module (memory 1) (data (i32.const 0) \"\{text}\"))",
    ).unwrap()
    let @lib.Data(_, actual) = mod_.data_sec.unwrap().0[0]
    assert_eq(actual, expected)
  }
  let names = wast_to_binary_module(
    "(module (import \"\\u{e_9}\" \"\\u{1f_600}\" (func $f)) (export \"\\u{6f_22}\" (func $f)))",
  ).unwrap()
  let @lib.Import(module_name, field_name, _) = names.import_sec.unwrap().0[0]
  let @lib.Export(export_name, _) = names.export_sec.unwrap().0[0]
  assert_eq(module_name, @lib.Name::new("é"))
  assert_eq(field_name, @lib.Name::new("😀"))
  assert_eq(export_name, @lib.Name::new("漢"))
}

///|
test "mass codec low-level parsers reject intentionally invalid lexer input" {
  for source in ["(module ,)", "(module) \"unfinished"] {
    let buf = @buffer.new()
    buf.write_string_utf8(source.to_string_view())
    let parser = WastParser::new(WastLexer::new(buf.to_bytes(), "module.wast"))
    let parsed : Result[Module, String] = Result::Ok(parser.parse_module()) catch {
      _ => Err("parse failure")
    }
    assert_true(parsed is Err(_))
  }
  for source in ["(module) ,", "(module) \"unfinished"] {
    let buf = @buffer.new()
    buf.write_string_utf8(source.to_string_view())
    let parser = WastParser::new(WastLexer::new(buf.to_bytes(), "script.wast"))
    let parsed : Result[WastScript, String] = Result::Ok(parser.parse_script()) catch {
      _ => Err("parse failure")
    }
    assert_true(parsed is Err(_))
  }
}

///|
test "mass codec compiles quoted fragments without adding whitespace" {
  let mod_ = spec_compile_module_def(
    WastModuleDef::Quote(["(mo", "dule (func (result i32) i32.const 1", "2))"]),
    "quote-fragments.wast",
  ).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = mod_.code_sec.unwrap().0[0]
  assert_eq(body, [@lib.Instruction::i32_const(@lib.I32::new(12))])
  assert_true(@validate.validate_module(mod_) is Ok(_))
}

///|
test "mass codec checks a quoted module split inside its keyword" {
  let source =
    #|(module quote "(mo" "dule (func (result i32) i32.const 7))")
  let report = run_wast_spec_file("quote-keyword-boundary.wast", source)
  match report.status {
    Passed => ()
    Skipped(reason) => fail("expected quoted module check: \{reason}")
    Failed(reason) => fail("expected quoted module check: \{reason}")
  }
  assert_eq(report.checked_commands, 1)
  assert_eq(report.skipped_commands, 0)
}
