///|
#cfg(target="native")
fn cnw_assert_occurs_in_order(text : String, needles : Array[String]) -> Unit {
  let mut start = 0
  for needle in needles {
    let mut found : Int? = None
    let mut i = start
    while i + needle.length() <= text.length() {
      if text.sub(start=i, end=i + needle.length()).to_string() == needle {
        found = Some(i)
        break
      }
      i += 1
    }
    match found {
      Some(idx) => start = idx + needle.length()
      None =>
        abort("expected `\{needle}` after byte offset \{start} in `\{text}`")
    }
  }
}

///|
#cfg(target="native")
fn cnw_count_substring(text : String, needle : String) -> Int {
  if needle.is_empty() {
    return 0
  }
  let mut count = 0
  let mut start = 0
  while start + needle.length() <= text.length() {
    let mut found : Int? = None
    let mut i = start
    while i + needle.length() <= text.length() {
      if text.sub(start=i, end=i + needle.length()).to_string() == needle {
        found = Some(i)
        break
      }
      i += 1
    }
    match found {
      Some(idx) => {
        count += 1
        start = idx + needle.length()
      }
      None => break
    }
  }
  count
}

///|
#cfg(target="native")
fn cmd_native_wbtest_print_wasm_bytes(bytes : Bytes) -> String {
  let in_path = cmd_native_tmp_path("cmd-test-print-in", ".wasm")
  let out_path = cmd_native_tmp_path("cmd-test-print-out", ".wat")
  match cmd_native_write_file(in_path, bytes) {
    Ok(_) => ()
    Err(err) => abort("failed to stage native print input: \{err}")
  }
  let in_q = cmd_native_shell_quote(in_path)
  let out_q = cmd_native_shell_quote(out_path)
  let commands = [
    "wasm-tools print \{in_q} -o \{out_q}",
    "wasm-tools print \{in_q} > \{out_q}",
  ]
  let mut printed = false
  for command in commands {
    let code = cmd_native_system(cmd_native_c_string(command))
    if code == 0 && cmd_native_file_exists(out_path) {
      printed = true
      break
    }
  }
  let wat = if printed {
    match cmd_native_read_file(out_path) {
      Ok(out) => bytes_to_string_lossy(out)
      Err(err) => abort("failed to read native printed wat: \{err}")
    }
  } else {
    abort("failed to print wasm bytes with native wasm-tools")
  }
  cmd_native_remove_file(in_path)
  cmd_native_remove_file(out_path)
  wat
}

///|
#cfg(target="native")
test "run_cmd_with_adapter tuple-optimization keeps compare-shape source remat stage in native wasm output" {
  let input_mod = match
    @wast.wast_to_binary_module(
      "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"trim\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 local.get 6 local.set 3 local.get 7 local.set 2 local.get 8 local.tee 1 local.get 2 local.get 3 call 1 local.set 0 local.get 0))",
      filename="tuple-compare-shape-forward.wat",
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "unexpected compare-shape scalar forwarding fixture parse failure: \{err}",
      )
  }
  let wasm = match encode_module(input_mod) {
    Ok(bytes) => bytes
    Err(err) =>
      fail(
        "unexpected compare-shape scalar forwarding fixture encode failure: \{err}",
      )
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["tuple-compare-shape-forward.wasm"] },
    file_exists=fn(path) { path == "tuple-compare-shape-forward.wasm" },
    read_file=fn(path) {
      if path == "tuple-compare-shape-forward.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  match
    run_cmd_with_adapter(
      [
        "--tuple-optimization", "--out", "out.wasm", "tuple-compare-shape-forward.wasm",
      ],
      io,
    ) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "unexpected tuple-optimization compare-shape forwarding failure: \{e}",
      )
  }
  assert_eq(writes.length(), 1)
  let printed = cmd_native_wbtest_print_wasm_bytes(writes[0].1)
  cnw_assert_occurs_in_order(printed, [
    "call 0", "local.set 11", "local.set 10", "local.tee 9", "local.set 15", "local.get 11",
    "local.set 14", "local.get 10", "local.set 13", "local.get 9", "local.set 12",
    "block (type 3) (result i32 i32 i32)", "local.set 3", "local.set 7", "local.tee 8",
    "drop", "local.get 7", "local.set 2", "local.get 8", "local.tee 1",
  ])
}

///|
#cfg(target="native")
test "run_cmd_with_adapter tuple-optimization rematerializes old source lanes before chained host-copy tail-live0 output" {
  let input_mod = match
    @wast.wast_to_binary_module(
      "(module (type (func (param i32 i32) (result i32 i32 i32))) (import \"env\" \"tri\" (func (type 0))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 8 local.set 7 local.tee 6 local.set 11 local.get 7 local.set 10 block (result i32 i32 i32) local.get 11 local.get 10 local.get 8 end local.set 5 local.set 4 local.tee 3 block (result i32 i32 i32) local.get 3 local.get 4 local.get 5 end local.set 2 local.set 1 local.tee 0 drop drop local.get 0))",
      filename="tuple-host-tail-live0.wat",
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("unexpected tail-live0 fixture parse failure: \{err}")
  }
  let wasm = match encode_module(input_mod) {
    Ok(bytes) => bytes
    Err(err) => fail("unexpected tail-live0 fixture encode failure: \{err}")
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["tuple-host-tail-live0.wasm"] },
    file_exists=fn(path) { path == "tuple-host-tail-live0.wasm" },
    read_file=fn(path) {
      if path == "tuple-host-tail-live0.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  match
    run_cmd_with_adapter(
      [
        "--tuple-optimization", "--out", "out.wasm", "tuple-host-tail-live0.wasm",
      ],
      io,
    ) {
    Ok(_) => ()
    Err(e) => fail("unexpected tuple-optimization tail-live0 failure: \{e}")
  }
  assert_eq(writes.length(), 1)
  let printed = cmd_native_wbtest_print_wasm_bytes(writes[0].1)
  cnw_assert_occurs_in_order(printed, [
    "call 0", "local.set 14", "local.set 13", "local.tee 12", "local.set 18", "local.get 14",
    "local.set 8", "local.get 13", "local.set 7", "local.get 18", "local.tee 6",
    "local.set 11",
  ])
  assert_eq(
    cnw_count_substring(printed, "block (type 2) (result i32 i32 i32)"),
    1,
    msg=printed,
  )
}

///|
#cfg(target="native")
test "run_cmd_with_adapter tuple-optimization leaves terminal drop-only host copy groups scalarized" {
  let input_mod = match
    @wast.wast_to_binary_module(
      "(module (type (func (param i32 i32) (result i32 i32 i32))) (import \"env\" \"tri\" (func (type 0))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 8 local.set 7 local.set 6 local.get 7 local.set 5 local.get 8 local.set 4 local.get 6 local.set 3 block (result i32 i32 i32) local.get 3 local.get 5 local.get 4 end local.set 2 local.set 1 local.tee 0 local.get 1 drop local.get 2 drop))",
      filename="tuple-terminal-drop-only-host.wat",
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("unexpected drop-only host copy fixture parse failure: \{err}")
  }
  let wasm = match encode_module(input_mod) {
    Ok(bytes) => bytes
    Err(err) =>
      fail("unexpected drop-only host copy fixture encode failure: \{err}")
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["tuple-terminal-drop-only-host.wasm"] },
    file_exists=fn(path) { path == "tuple-terminal-drop-only-host.wasm" },
    read_file=fn(path) {
      if path == "tuple-terminal-drop-only-host.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  match
    run_cmd_with_adapter(
      [
        "--tuple-optimization", "--out", "out.wasm", "tuple-terminal-drop-only-host.wasm",
      ],
      io,
    ) {
    Ok(_) => ()
    Err(e) =>
      fail("unexpected tuple-optimization drop-only host copy failure: \{e}")
  }
  assert_eq(writes.length(), 1)
  let printed = cmd_native_wbtest_print_wasm_bytes(writes[0].1)
  cnw_assert_occurs_in_order(printed, [
    "call 0", "local.set 8", "local.set 7", "local.set 6", "local.get 7", "local.set 5",
    "local.get 8", "local.set 4", "local.get 6", "local.set 3", "block (type 2) (result i32 i32 i32)",
    "local.get 3", "local.get 5", "local.get 4", "local.set 2", "local.set 1", "local.get 1",
    "drop", "local.get 2", "drop", "local.tee 0",
  ])
  assert_eq(
    cnw_count_substring(printed, "block (type 2) (result i32 i32 i32)"),
    1,
    msg=printed,
  )
}
