///|
test "r1 review lib WAT output preserves escaped newline export names" {
  let mod_ = @wast.wast_to_binary_module(
      "(module (func (export \"line\\nbreak\")))",
    )
    .unwrap()
    .without_name_sec()
  let text = lib_module_to_wat(mod_).unwrap()
  let output = match @wast.wast_to_binary_module(text) {
    Ok(output) => output
    Err(error) => fail("printed WAT must lower: \{error}")
  }
  let @lib.Export(name, _) = output.export_sec.unwrap().0[0]
  assert_eq(name, @lib.Name::new("line\nbreak"))
}

///|
test "lib WAT names escape ASCII controls and preserve UTF-8 bytes" {
  let hex = "0123456789abcdef"
  for code in 0..<128 {
    if code >= 32 && code != 127 {
      continue
    }
    let escaped = "\\\{hex[code / 16].to_int().unsafe_to_char()}\{hex[code % 16].to_int().unsafe_to_char()}"
    let input = @wast.wast_to_binary_module(
        "(module (func (export \"a\{escaped}f\")))",
      )
      .unwrap()
      .without_name_sec()
    let @lib.Export(name, _) = input.export_sec.unwrap().0[0]
    assert_eq(lib_name_to_wat(name), "\"a\{escaped}f\"")
    let output = @wast.wast_to_binary_module(lib_module_to_wat(input).unwrap()).unwrap()
    assert_eq(output.export_sec, input.export_sec)
  }
  for
    source_name in [
      "", "plain", "é水😀", "quote\\\"slash\\\\", "\\c3\\a9\\00z",
    ] {
    let input = @wast.wast_to_binary_module(
        "(module (func (export \"\{source_name}\")))",
      )
      .unwrap()
      .without_name_sec()
    let output = @wast.wast_to_binary_module(lib_module_to_wat(input).unwrap()).unwrap()
    assert_eq(output.export_sec, input.export_sec)
  }
}
