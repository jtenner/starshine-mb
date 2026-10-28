///|
test "r1 tooling fallback preserves raw UTF-8 data" {
  let source = b"(module (memory 1) (data (i32.const 0) \"\xc3\xa9\"))"
  let encoded = lower_text_module_in_process(
    "unicode.wat",
    @cli.CliInputFormat::wat(),
    source,
  ).unwrap()
  let mod_ = @binary.decode_module(encoded).unwrap()
  let @lib.Data(_, actual) = mod_.data_sec.unwrap().0[0]
  assert_eq(actual, b"\xc3\xa9")
}

///|
test "r1 tooling config file preserves UTF-8 input paths" {
  let reads : Array[String] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == "cfg.json" },
    read_file=fn(path) {
      reads.push(path)
      if path == "cfg.json" {
        Ok(b"{\"inputs\":{\"globs\":[\"\xc3\xa9.wasm\"]}}")
      } else if path == "é.wasm" {
        Ok(b"\x00asm\x01\x00\x00\x00")
      } else {
        Err("unexpected path")
      }
    },
    write_file=fn(_, _) { Ok(()) },
  )
  let result = run_cmd_with_adapter(["--config", "cfg.json"], io)
  assert_eq(reads, ["cfg.json", "é.wasm"])
  assert_true(result is Ok(_))
}

///|
test "r1 tooling text decoder preserves Unicode scalars ASCII and controls" {
  assert_eq(
    bytes_to_string_lossy(
      b"ASCII\x00\t\n\r\x7f\xc3\xa9\xe4\xb8\xad\xf0\x9f\x98\x80\xe2\x80\xa8",
    ),
    "ASCII\u{0000}\t\n\r\u{007f}é中😀\u{2028}",
  )
  assert_eq(bytes_to_string_lossy(b""), "")
  assert_eq(bytes_to_string_lossy(b"\xef\xbb\xbfA"), "\u{feff}A")
}

///|
test "r1 tooling intentionally malformed UTF-8 uses replacement characters" {
  // Invalid source bytes remain lossy, without destroying adjacent valid text.
  assert_eq(bytes_to_string_lossy(b"A\xffB\xc3\xa9\xe2\x82"), "A�Bé�")
  assert_eq(bytes_to_string_lossy(b"\xc0\xaf"), "��")
  assert_eq(bytes_to_string_lossy(b"\xed\xa0\x80"), "���")
}
