///|
test "r1 tooling environment inputs preserve explicit ignore implicit traps" {
  let io = CmdIO::new(
    get_env=fn(key) { if key == "STARSHINE_INPUT" { Some("a.wasm") } else { None } },
    read_file=fn(_) { Ok(b"\x00asm\x01\x00\x00\x00") },
    write_file=fn(_, _) { Ok(()) },
  )
  let summary = run_cmd_with_adapter(["--ignore-implicit-traps"], io).unwrap()
  assert_true(summary.ignore_implicit_traps)
}

///|
test "r1 tooling empty environment preserves explicit ignore implicit traps" {
  let io = CmdIO::new(
    get_env=fn(key) { if key == "STARSHINE_INPUT" { Some("") } else { None } },
    read_file=fn(_) { Ok(b"\x00asm\x01\x00\x00\x00") },
    write_file=fn(_, _) { Ok(()) },
  )
  let summary = run_cmd_with_adapter(
    ["--ignore-implicit-traps", "cli.wasm"], io,
  ).unwrap()
  assert_true(summary.ignore_implicit_traps)
  assert_eq(summary.input_files, ["cli.wasm"])
}

///|
test "r1 tooling absent environment preserves explicit ignore implicit traps" {
  let io = CmdIO::new(
    get_env=fn(_) { None },
    read_file=fn(_) { Ok(b"\x00asm\x01\x00\x00\x00") },
    write_file=fn(_, _) { Ok(()) },
  )
  let summary = run_cmd_with_adapter(
    ["--ignore-implicit-traps", "cli.wasm"], io,
  ).unwrap()
  assert_true(summary.ignore_implicit_traps)
  assert_eq(summary.input_files, ["cli.wasm"])
}

///|
test "r1 tooling environment input controls retain default trap option and paths" {
  for input in [Some("env.wasm"), Some(""), None] {
    let reads : Array[String] = []
    let io = CmdIO::new(
      get_env=fn(key) { if key == "STARSHINE_INPUT" { input } else { None } },
      read_file=fn(path) {
        reads.push(path)
        Ok(b"\x00asm\x01\x00\x00\x00")
      },
      write_file=fn(_, _) { Ok(()) },
    )
    let summary = run_cmd_with_adapter(["cli.wasm"], io).unwrap()
    assert_false(summary.ignore_implicit_traps)
    let expected = if input == Some("env.wasm") {
      ["cli.wasm", "env.wasm"]
    } else {
      ["cli.wasm"]
    }
    assert_eq(summary.input_files, expected)
    assert_eq(reads, expected)
  }
}
