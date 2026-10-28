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

///|
test "r1 tooling positional separator preserves inlining alias filenames" {
  let parsed = @cli.parse_cli_args(["--", "-aimfs=7.wasm"]).unwrap()
  assert_eq(parsed.input_globs, ["-aimfs=7.wasm"])
}

///|
test "r1 tooling positional separator preserves report flag filenames" {
  let args = ["--", "--emit-optimizer-thresholds-json"]
  let (filtered, mode) = cmd_extract_optimizer_report_mode(args).unwrap()
  assert_eq(filtered, args)
  assert_eq(mode, None)
}

///|
test "R1-13 report extraction preserves suffix and pre-boundary modes" {
  let flags = [
    "--emit-optimizer-thresholds-json", "--emit-expanded-pass-queue-json", "--emit-runtime-interface-json",
  ]
  let suffix = [
    "--",
    flags[0],
    flags[1],
    flags[2],
    "-aimfs=7.wasm",
    "--",
    "file.wasm",
  ]
  let (literal, no_mode) = cmd_extract_optimizer_report_mode(suffix).unwrap()
  assert_eq(literal, suffix)
  assert_eq(no_mode, None)
  for flag in flags {
    let args = [flag, flag]
    for token in suffix {
      args.push(token)
    }
    let (filtered, mode) = cmd_extract_optimizer_report_mode(args).unwrap()
    assert_eq(filtered, suffix)
    assert_eq(mode, cmd_optimizer_report_flag_mode(flag))
  }
  assert_true(
    cmd_extract_optimizer_report_mode([flags[0], flags[1], "--"]) is Err(_),
  )
  let (empty, mode) = cmd_extract_optimizer_report_mode(["--"]).unwrap()
  assert_eq(empty, ["--"])
  assert_eq(mode, None)
}

///|
test "R1-13 command adapter reads report and alias filenames literally" {
  let paths = [
    "-aimfs=7.wasm", "--emit-optimizer-thresholds-json", "--emit-expanded-pass-queue-json",
    "--emit-runtime-interface-json",
  ]
  let args = ["--"]
  for path in paths {
    args.push(path)
  }
  let reads : Array[String] = []
  let io = CmdIO::new(
    read_file=fn(path) {
      reads.push(path)
      Ok(b"\x00asm\x01\x00\x00\x00")
    },
    write_file=fn(_, _) { Ok(()) },
  )
  assert_true(run_cmd_with_adapter(args, io) is Ok(_))
  assert_eq(reads, paths)
}

///|
test "r1 tooling optimizer JSON escapes valid Wasm name control characters" {
  assert_eq(cmd_optimizer_json_string("\u{0001}"), "\"\\u0001\"")
}

///|
test "r1 tooling optimizer JSON escapes every control and preserves Unicode" {
  let expected = [
    "\\u0000", "\\u0001", "\\u0002", "\\u0003", "\\u0004", "\\u0005", "\\u0006",
    "\\u0007", "\\u0008", "\\t", "\\n", "\\u000b", "\\u000c", "\\r", "\\u000e", "\\u000f",
    "\\u0010", "\\u0011", "\\u0012", "\\u0013", "\\u0014", "\\u0015", "\\u0016",
    "\\u0017", "\\u0018", "\\u0019", "\\u001a", "\\u001b", "\\u001c", "\\u001d",
    "\\u001e", "\\u001f",
  ]
  for code = 0; code < 32; code = code + 1 {
    let text = StringBuilder()
    text.write_char(code.unsafe_to_char())
    assert_eq(
      cmd_optimizer_json_string(text.to_string()),
      "\"\{expected[code]}\"",
    )
  }
  let text = "quote\" slash\\ LF\n CR\r tab\t é中文😀\u{007f}\u{0085}\u{2028}\u{2029}"
  assert_eq(
    cmd_optimizer_json_string(text),
    "\"quote\\\" slash\\\\ LF\\n CR\\r tab\\t é中文😀\u{007f}\u{0085}\u{2028}\u{2029}\"",
  )
  assert_eq(
    @json.parse(cmd_optimizer_json_string(text)).as_string(),
    Some(text),
  )
  assert_eq(cmd_optimizer_json_string(""), "\"\"")
}

///|
test "r1 tooling optimizer report stdout preserves Unicode as UTF-8" {
  let writes : Array[Bytes] = []
  let io = CmdIO::new(write_stdout=fn(bytes) {
    writes.push(bytes)
    Ok(())
  })
  cmd_write_optimizer_report_stdout(io, "\"é中文😀\"").unwrap()
  assert_eq(writes, [b"\"\xc3\xa9\xe4\xb8\xad\xe6\x96\x87\xf0\x9f\x98\x80\"\n"])
}
