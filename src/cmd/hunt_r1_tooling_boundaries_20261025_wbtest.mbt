///|
test "r1 tooling fallback preserves raw UTF-8 data" {
  let source = b"(module (memory 1) (data (i32.const 0) \"\xc3\xa9\"))"
  let encoded = lower_text_module_in_process(
    "unicode.wat", @cli.CliInputFormat::wat(), source,
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
