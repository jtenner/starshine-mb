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
