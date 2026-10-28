///|
test "r1 tooling rejects ambiguous output basename before overwriting another input" {
  // This output configuration is intentionally invalid: two inputs map to b/x.wasm.
  let files : @hashmap.HashMap[String, Bytes] = @hashmap.new()
  let first = b"\x00asm\x01\x00\x00\x00\x00\x02\x01a"
  let second = b"\x00asm\x01\x00\x00\x00\x00\x02\x01b"
  files.set("a/x.wasm", first)
  files.set("b/x.wasm", second)
  let writes : Array[String] = []
  let io = CmdIO::new(
    read_file=fn(path) {
      match files.get(path) {
        Some(bytes) => Ok(bytes)
        None => Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push(path)
      files.set(path, bytes)
      Ok(())
    },
  )
  let result = run_cmd_with_adapter(
    ["--out-dir", "b", "a/x.wasm", "b/x.wasm"],
    io,
  )
  assert_eq(files.get("b/x.wasm"), Some(second))
  assert_eq(writes, [])
  assert_true(result is Err(_))
}

///|
test "r1 output collision preflight rejects invalid plans before input IO" {
  let cases : Array[Array[String]] = [
    ["--out-dir", "dist", "a/x.wasm", "b/x.wasm"],
    ["--out-dir", "dist", "a/x.wat", "b/x.wasm"],
    ["--out-dir", "b", "a/x.wat", "b/x.wasm"],
    ["a/x.wat", "a/x.wasm"],
    ["--out-dir", "./b//tmp/..", "a/x.wasm", "b/./x.wasm"],
    ["--out-dir", "C:\\b", "C:/a/x.wasm", "C:/b/x.wasm"],
    ["--out-dir", "/b", "/a/x.wasm", "/b/x.wasm"],
    ["--out-dir", "../b", "../a/x.wasm", "../b/x.wasm"],
    ["-o", "dist/x.wasm", "--out-dir", "dist", "a/x.wasm"],
  ]
  for args in cases {
    let reads : Array[String] = []
    let writes : Array[String] = []
    let io = CmdIO::new(
      read_file=fn(path) {
        reads.push(path)
        Ok(b"\x00asm\x01\x00\x00\x00")
      },
      write_file=fn(path, _) {
        writes.push(path)
        Ok(())
      },
    )
    let result = run_cmd_with_adapter(args, io)
    assert_true(result is Err(AmbiguousOutputFile(_)))
    assert_eq(reads, [])
    assert_eq(writes, [])
  }
}

///|
test "r1 output preflight preserves supported same-file and distinct outputs" {
  let cases : Array[(Array[String], Array[String])] = [
    (["a/x.wasm"], ["a/x.wasm"]),
    (["-o", "./a/x.wasm", "a/x.wasm"], ["a/x.wasm"]),
    (["--out-dir", "a", "a/x.wasm"], ["a/x.wasm"]),
    (
      ["--out-dir", "dist", "a/x.wasm", "b/y.wasm"],
      ["dist/x.wasm", "dist/y.wasm"],
    ),
    (["--out-dir", "dist", "a/x.wat"], ["dist/x.wasm"]),
    (["--stdout", "a/x.wasm", "b/y.wasm"], []),
  ]
  for (args, expected) in cases {
    let writes : Array[String] = []
    let io = CmdIO::new(
      read_file=fn(_) { Ok(b"\x00asm\x01\x00\x00\x00") },
      lower_text_module=fn(_, _, bytes) { Ok(bytes) },
      write_file=fn(path, _) {
        writes.push(path)
        Ok(())
      },
      write_stdout=fn(_) { Ok(()) },
    )
    assert_true(run_cmd_with_adapter(args, io) is Ok(_))
    assert_eq(writes, expected)
  }
}
