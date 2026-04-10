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
fn cmd_native_wbtest_normalize_func_by_index(
  bytes : Bytes,
  func_idx : Int,
) -> String {
  if func_idx < 0 {
    abort("expected non-negative function index")
  }
  let in_path = cmd_native_tmp_path("cmd-test-normalize-in", ".wasm")
  let out_path = cmd_native_tmp_path("cmd-test-normalize-out", ".wasm")
  match cmd_native_write_file(in_path, bytes) {
    Ok(_) => ()
    Err(err) => abort("failed to stage native normalize input: \{err}")
  }
  let in_q = cmd_native_shell_quote(in_path)
  let out_q = cmd_native_shell_quote(out_path)
  let command = "wasm-opt \{in_q} --strip-debug --all-features -o \{out_q}"
  let code = cmd_native_system(cmd_native_c_string(command))
  if code != 0 || !cmd_native_file_exists(out_path) {
    abort("failed to normalize wasm bytes with native wasm-opt")
  }
  let normalized = match cmd_native_read_file(out_path) {
    Ok(out) => out
    Err(err) => abort("failed to read native normalized wasm bytes: \{err}")
  }
  let mod_ = match decode_module(normalized) {
    Ok(mod_) => mod_
    Err(err) => abort("failed to decode native normalized wasm bytes: \{err}")
  }
  cmd_native_remove_file(in_path)
  cmd_native_remove_file(out_path)
  mod_.pretty_print_func(@lib.FuncIdx::new(func_idx.reinterpret_as_uint()))
}

///|
#cfg(target="native")
fn cmd_native_wbtest_binaryen_tuple_opt_func_by_index(
  bytes : Bytes,
  func_idx : Int,
) -> String {
  if func_idx < 0 {
    abort("expected non-negative function index")
  }
  let in_path = cmd_native_tmp_path("cmd-test-binaryen-tuple-in", ".wasm")
  let out_path = cmd_native_tmp_path("cmd-test-binaryen-tuple-out", ".wasm")
  match cmd_native_write_file(in_path, bytes) {
    Ok(_) => ()
    Err(err) => abort("failed to stage native binaryen tuple input: \{err}")
  }
  let in_q = cmd_native_shell_quote(in_path)
  let out_q = cmd_native_shell_quote(out_path)
  let command = "wasm-opt \{in_q} --tuple-optimization --all-features --strip-debug -o \{out_q}"
  let code = cmd_native_system(cmd_native_c_string(command))
  if code != 0 || !cmd_native_file_exists(out_path) {
    abort("failed to run native binaryen tuple-optimization")
  }
  let optimized = match cmd_native_read_file(out_path) {
    Ok(out) => out
    Err(err) => abort("failed to read native binaryen tuple wasm bytes: \{err}")
  }
  let mod_ = match decode_module(optimized) {
    Ok(mod_) => mod_
    Err(err) => abort("failed to decode native binaryen tuple wasm bytes: \{err}")
  }
  cmd_native_remove_file(in_path)
  cmd_native_remove_file(out_path)
  mod_.pretty_print_func(@lib.FuncIdx::new(func_idx.reinterpret_as_uint()))
}

///|
#cfg(target="native")
test "run_cmd_with_adapter tuple-optimization keeps chained host-copy tail-live0 source lanes live through downstream tees" {
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
    "call 0", "local.set 8", "local.set 7", "local.tee 6", "local.set 11", "local.get 7",
    "local.set 10", "local.get 11", "local.get 10", "local.get 8", "local.set 3",
    "local.get 3", "local.get 4", "local.get 5", "local.tee 0", "local.set 12",
    "local.get 12", "drop", "local.get 3", "drop",
  ])
}

///|
#cfg(target="native")
test "run_cmd_with_adapter tuple-optimization keeps chained host-copy tail-live0 downstream tees and drop tails" {
  let input_mod = match
    @wast.wast_to_binary_module(
      "(module (type (func (param i32 i32) (result i32 i32 i32))) (import \"env\" \"tri\" (func (type 0))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 8 local.set 7 local.tee 6 local.set 11 local.get 7 local.set 10 block (result i32 i32 i32) local.get 11 local.get 10 local.get 8 end local.set 5 local.set 4 local.tee 3 block (result i32 i32 i32) local.get 3 local.get 4 local.get 5 end local.set 2 local.set 1 local.tee 0 drop drop local.get 0))",
      filename="tuple-host-tail-live0.wat",
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("unexpected tail-live0 parity fixture parse failure: \{err}")
  }
  let wasm = match encode_module(input_mod) {
    Ok(bytes) => bytes
    Err(err) =>
      fail("unexpected tail-live0 parity fixture encode failure: \{err}")
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
    Err(e) =>
      fail("unexpected tuple-optimization tail-live0 carrier failure: \{e}")
  }
  assert_eq(writes.length(), 1)
  let printed = cmd_native_wbtest_print_wasm_bytes(writes[0].1)
  cnw_assert_occurs_in_order(printed, [
    "local.tee 6", "local.set 11", "local.get 7", "local.set 10", "local.set 3",
    "local.tee 0", "local.set 12", "local.get 12", "drop", "local.get 3", "drop",
  ])
  assert_eq(cnw_count_substring(printed, "local.tee "), 2, msg=printed)
}

///|
#cfg(target="native")
test "run_cmd_with_adapter tuple-optimization matches Binaryen for mixed scalar-forward bridges from direct producers" {
  let input_mod = match
    @wast.wast_to_binary_module(
      "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 local.get 8 local.get 7 local.get 6 call 1 local.set 0 local.get 0))",
      filename="tuple-direct-mixed-forward.wat",
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "unexpected mixed direct-producer parity fixture parse failure: \{err}",
      )
  }
  let wasm = match encode_module(input_mod) {
    Ok(bytes) => bytes
    Err(err) =>
      fail(
        "unexpected mixed direct-producer parity fixture encode failure: \{err}",
      )
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["tuple-direct-mixed-forward.wasm"] },
    file_exists=fn(path) { path == "tuple-direct-mixed-forward.wasm" },
    read_file=fn(path) {
      if path == "tuple-direct-mixed-forward.wasm" {
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
        "--tuple-optimization", "--out", "out.wasm", "tuple-direct-mixed-forward.wasm",
      ],
      io,
    ) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "unexpected mixed direct-producer tuple-optimization failure: \{e}",
      )
  }
  assert_eq(writes.length(), 1)
  let binaryen_func = cmd_native_wbtest_binaryen_tuple_opt_func_by_index(wasm, 2)
  let tuple_func = cmd_native_wbtest_normalize_func_by_index(writes[0].1, 2)
  assert_eq(tuple_func, binaryen_func, msg=tuple_func)
}

///|
#cfg(target="native")
test "run_cmd_with_adapter tuple-optimization matches Binaryen for scrambled tuple copy carriers" {
  let input_mod = match
    @wast.wast_to_binary_module(
      "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 block (result i32 i32 i32) local.get 8 local.get 7 local.get 6 end local.set 11 local.set 9 local.set 10 local.get 10 local.get 9 local.get 11 call 1))",
      filename="tuple-scrambled-copy-order.wat",
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "unexpected scrambled tuple copy carrier parity fixture parse failure: \{err}",
      )
  }
  let wasm = match encode_module(input_mod) {
    Ok(bytes) => bytes
    Err(err) =>
      fail(
        "unexpected scrambled tuple copy carrier parity fixture encode failure: \{err}",
      )
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["tuple-scrambled-copy-order.wasm"] },
    file_exists=fn(path) { path == "tuple-scrambled-copy-order.wasm" },
    read_file=fn(path) {
      if path == "tuple-scrambled-copy-order.wasm" {
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
        "--tuple-optimization", "--out", "out.wasm", "tuple-scrambled-copy-order.wasm",
      ],
      io,
    ) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "unexpected scrambled tuple copy carrier tuple-optimization failure: \{e}",
      )
  }
  assert_eq(writes.length(), 1)
  let binaryen_func = cmd_native_wbtest_binaryen_tuple_opt_func_by_index(wasm, 2)
  let tuple_func = cmd_native_wbtest_normalize_func_by_index(writes[0].1, 2)
  assert_eq(tuple_func, binaryen_func, msg=tuple_func)
}

///|
#cfg(target="native")
test "run_cmd_with_adapter tuple-optimization matches Binaryen for root local.set copy groups" {
  let input_mod = match
    @wast.wast_to_binary_module(
      "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 block (result i32 i32 i32) local.get 8 local.get 7 local.get 6 end local.set 2 local.set 1 local.set 0 local.get 0 local.get 1 local.get 2 call 1 local.set 9 local.get 9))",
      filename="tuple-root-copy-order.wat",
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "unexpected root local.set tuple copy carrier parity fixture parse failure: \{err}",
      )
  }
  let wasm = match encode_module(input_mod) {
    Ok(bytes) => bytes
    Err(err) =>
      fail(
        "unexpected root local.set tuple copy carrier parity fixture encode failure: \{err}",
      )
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["tuple-root-copy-order.wasm"] },
    file_exists=fn(path) { path == "tuple-root-copy-order.wasm" },
    read_file=fn(path) {
      if path == "tuple-root-copy-order.wasm" {
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
        "--tuple-optimization", "--out", "out.wasm", "tuple-root-copy-order.wasm",
      ],
      io,
    ) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "unexpected root local.set tuple copy carrier tuple-optimization failure: \{e}",
      )
  }
  assert_eq(writes.length(), 1)
  let binaryen_func = cmd_native_wbtest_binaryen_tuple_opt_func_by_index(wasm, 2)
  let tuple_func = cmd_native_wbtest_normalize_func_by_index(writes[0].1, 2)
  assert_eq(tuple_func, binaryen_func, msg=tuple_func)
}

///|
#cfg(target="native")
test "run_cmd_with_adapter tuple-optimization matches Binaryen for chained scalar-forward no-host copy groups" {
  let input_mod = match
    @wast.wast_to_binary_module(
      "(module (type (func (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32) block (result i32 i32 i32) i32.const 1 i32.const 2 i32.const 3 end local.set 2 local.set 1 local.set 0 local.get 0 local.set 3 local.get 1 local.set 4 local.get 2 local.set 5 block (result i32 i32 i32) local.get 3 local.get 4 local.get 5 end local.set 8 local.set 6 local.set 7 local.get 7 local.get 6 local.get 8 call 0))",
      filename="tuple-scalar-forward-no-host-chain.wat",
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "unexpected chained scalar-forward no-host copy parity fixture parse failure: \{err}",
      )
  }
  let wasm = match encode_module(input_mod) {
    Ok(bytes) => bytes
    Err(err) =>
      fail(
        "unexpected chained scalar-forward no-host copy parity fixture encode failure: \{err}",
      )
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["tuple-scalar-forward-no-host-chain.wasm"] },
    file_exists=fn(path) { path == "tuple-scalar-forward-no-host-chain.wasm" },
    read_file=fn(path) {
      if path == "tuple-scalar-forward-no-host-chain.wasm" {
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
        "--tuple-optimization",
        "--out",
        "out.wasm",
        "tuple-scalar-forward-no-host-chain.wasm",
      ],
      io,
    ) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "unexpected chained scalar-forward no-host copy tuple-optimization failure: \{e}",
      )
  }
  assert_eq(writes.length(), 1)
  let binaryen_func = cmd_native_wbtest_binaryen_tuple_opt_func_by_index(wasm, 1)
  let tuple_func = cmd_native_wbtest_normalize_func_by_index(writes[0].1, 1)
  assert_eq(tuple_func, binaryen_func, msg=tuple_func)
}

///|
#cfg(target="native")
test "run_cmd_with_adapter tuple-optimization matches Binaryen for chained mixed scalar-forward bridges" {
  let input_mod = match
    @wast.wast_to_binary_module(
      "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 local.get 7 local.set 9 local.get 8 local.get 9 local.get 6 call 1 local.set 0 local.get 0))",
      filename="tuple-direct-chained-forward.wat",
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "unexpected chained direct-producer parity fixture parse failure: \{err}",
      )
  }
  let wasm = match encode_module(input_mod) {
    Ok(bytes) => bytes
    Err(err) =>
      fail(
        "unexpected chained direct-producer parity fixture encode failure: \{err}",
      )
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["tuple-direct-chained-forward.wasm"] },
    file_exists=fn(path) { path == "tuple-direct-chained-forward.wasm" },
    read_file=fn(path) {
      if path == "tuple-direct-chained-forward.wasm" {
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
        "--tuple-optimization", "--out", "out.wasm", "tuple-direct-chained-forward.wasm",
      ],
      io,
    ) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "unexpected chained direct-producer tuple-optimization failure: \{e}",
      )
  }
  assert_eq(writes.length(), 1)
  let binaryen_func = cmd_native_wbtest_binaryen_tuple_opt_func_by_index(wasm, 2)
  let tuple_func = cmd_native_wbtest_normalize_func_by_index(writes[0].1, 2)
  assert_eq(tuple_func, binaryen_func, msg=tuple_func)
}

///|
#cfg(target="native")
test "run_cmd_with_adapter tuple-optimization keeps no-host exact-copy chains from materialized lanes scalar" {
  let input_mod = match
    @wast.wast_to_binary_module(
      "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 8 local.set 7 local.set 6 block (result i32 i32 i32) local.get 6 local.get 7 local.get 8 end local.set 5 local.set 4 local.set 3 block (result i32 i32 i32) local.get 3 local.get 4 local.get 5 end local.set 2 local.set 1 local.set 0 local.get 0 local.get 1 local.get 2 call 1))",
      filename="tuple-nohost-materialized-chain.wat",
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "unexpected no-host materialized chain fixture parse failure: \{err}",
      )
  }
  let wasm = match encode_module(input_mod) {
    Ok(bytes) => bytes
    Err(err) =>
      fail(
        "unexpected no-host materialized chain fixture encode failure: \{err}",
      )
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["tuple-nohost-materialized-chain.wasm"] },
    file_exists=fn(path) { path == "tuple-nohost-materialized-chain.wasm" },
    read_file=fn(path) {
      if path == "tuple-nohost-materialized-chain.wasm" {
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
        "--tuple-optimization", "--out", "out.wasm", "tuple-nohost-materialized-chain.wasm",
      ],
      io,
    ) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "unexpected tuple-optimization no-host materialized chain failure: \{e}",
      )
  }
  assert_eq(writes.length(), 1)
  let printed = cmd_native_wbtest_print_wasm_bytes(writes[0].1)
  assert_eq(cnw_count_substring(printed, "tuple.make"), 0, msg=printed)
}

///|
#cfg(target="native")
test "run_cmd_with_adapter tuple-optimization leaves chained terminal drop-only no-host copy groups scalarized" {
  let input_mod = match
    @wast.wast_to_binary_module(
      "(module (type (func (param i32 i32) (result i32 i32 i32))) (import \"env\" \"tri\" (func (type 0))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 8 local.set 7 local.set 6 block (result i32 i32 i32) local.get 6 local.get 7 local.get 8 end local.set 5 local.set 4 local.set 3 block (result i32 i32 i32) local.get 3 local.get 4 local.get 5 end local.set 2 local.set 1 local.set 0 local.get 1 drop local.get 2 drop local.get 0))",
      filename="tuple-chained-drop-only-nohost.wat",
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("unexpected chained no-host drop-only fixture parse failure: \{err}")
  }
  let wasm = match encode_module(input_mod) {
    Ok(bytes) => bytes
    Err(err) =>
      fail(
        "unexpected chained no-host drop-only fixture encode failure: \{err}",
      )
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["tuple-chained-drop-only-nohost.wasm"] },
    file_exists=fn(path) { path == "tuple-chained-drop-only-nohost.wasm" },
    read_file=fn(path) {
      if path == "tuple-chained-drop-only-nohost.wasm" {
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
        "--tuple-optimization", "--out", "out.wasm", "tuple-chained-drop-only-nohost.wasm",
      ],
      io,
    ) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "unexpected tuple-optimization chained no-host drop-only failure: \{e}",
      )
  }
  assert_eq(writes.length(), 1)
  let printed = cmd_native_wbtest_print_wasm_bytes(writes[0].1)
  cnw_assert_occurs_in_order(printed, [
    "call 0", "local.set 8", "local.set 7", "local.set 6", "local.get 8", "local.set 5",
    "local.get 7", "local.set 4", "local.get 6", "local.set 3", "local.get 5", "local.set 2",
    "local.get 4", "local.set 1", "local.get 3", "local.set 0", "local.get 1", "drop",
    "local.get 2", "drop", "local.get 0",
  ])
  assert_eq(cnw_count_substring(printed, "block (type "), 0, msg=printed)
}

///|
#cfg(target="native")
test "run_cmd_with_adapter tuple-optimization keeps nested no-host source copy chains scalar" {
  let input_mod = match
    @wast.wast_to_binary_module(
      "(module (type (func (param i32 i64) (result i32 i32 i32))) (import \"env\" \"tri\" (func (type 0))) (func (param i32) (result i32) (local i32 i32 i32 i32 i32 i32) block (result i32) block block local.get 0 i64.const 1 call 0 local.set 5 local.set 4 local.set 3 end local.get 5 local.set 2 local.get 4 local.set 1 end local.get 3 end))",
      filename="tuple-nested-nohost-source-copy.wat",
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "unexpected nested no-host source copy fixture parse failure: \{err}",
      )
  }
  let wasm = match encode_module(input_mod) {
    Ok(bytes) => bytes
    Err(err) =>
      fail(
        "unexpected nested no-host source copy fixture encode failure: \{err}",
      )
  }
  let no_pass_writes : Array[(String, Bytes)] = []
  let tuple_writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["tuple-nested-nohost-source-copy.wasm"] },
    file_exists=fn(path) { path == "tuple-nested-nohost-source-copy.wasm" },
    read_file=fn(path) {
      if path == "tuple-nested-nohost-source-copy.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      if path == "out-no-pass.wasm" {
        no_pass_writes.push((path, bytes))
      } else {
        tuple_writes.push((path, bytes))
      }
      Ok(())
    },
  )
  match
    run_cmd_with_adapter(
      ["--out", "out-no-pass.wasm", "tuple-nested-nohost-source-copy.wasm"],
      io,
    ) {
    Ok(_) => ()
    Err(e) => fail("unexpected nested no-host no-pass command failure: \{e}")
  }
  match
    run_cmd_with_adapter(
      [
        "--tuple-optimization", "--out", "out-pass.wasm", "tuple-nested-nohost-source-copy.wasm",
      ],
      io,
    ) {
    Ok(_) => ()
    Err(e) => fail("unexpected nested no-host tuple-optimization failure: \{e}")
  }
  assert_eq(no_pass_writes.length(), 1)
  assert_eq(tuple_writes.length(), 1)
  let binaryen_func = cmd_native_wbtest_binaryen_tuple_opt_func_by_index(
    no_pass_writes[0].1,
    1,
  )
  let tuple_func = cmd_native_wbtest_normalize_func_by_index(
    tuple_writes[0].1,
    1,
  )
  assert_eq(tuple_func, binaryen_func, msg=tuple_func)
}

///|
#cfg(target="native")
test "run_cmd_with_adapter tuple-optimization matches nested exact copy scalar-result carriers" {
  let input_mod = match
    @wast.wast_to_binary_module(
      "(module (type (func (param i32 i64) (result i32 i32 i32))) (import \"env\" \"tri\" (func (type 0))) (func (param i32) (result i32) (local i32 i32 i32 i32 i32 i32) local.get 0 i64.const 1 call 0 local.set 5 local.set 4 local.set 3 block block block (result i32) block (result i32 i32 i32) local.get 3 local.get 4 local.get 5 end local.set 2 local.set 1 end local.set 0 end end local.get 0))",
      filename="tuple-nested-exact-copy.wat",
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("unexpected nested exact-copy fixture parse failure: \{err}")
  }
  let wasm = match encode_module(input_mod) {
    Ok(bytes) => bytes
    Err(err) =>
      fail("unexpected nested exact-copy fixture encode failure: \{err}")
  }
  let no_pass_writes : Array[(String, Bytes)] = []
  let tuple_writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["tuple-nested-exact-copy.wasm"] },
    file_exists=fn(path) { path == "tuple-nested-exact-copy.wasm" },
    read_file=fn(path) {
      if path == "tuple-nested-exact-copy.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      if path == "out-no-pass.wasm" {
        no_pass_writes.push((path, bytes))
      } else {
        tuple_writes.push((path, bytes))
      }
      Ok(())
    },
  )
  match
    run_cmd_with_adapter(
      ["--out", "out-no-pass.wasm", "tuple-nested-exact-copy.wasm"],
      io,
    ) {
    Ok(_) => ()
    Err(e) => fail("unexpected nested exact-copy no-pass command failure: \{e}")
  }
  match
    run_cmd_with_adapter(
      [
        "--tuple-optimization", "--out", "out-pass.wasm", "tuple-nested-exact-copy.wasm",
      ],
      io,
    ) {
    Ok(_) => ()
    Err(e) =>
      fail("unexpected nested exact-copy tuple-optimization failure: \{e}")
  }
  assert_eq(no_pass_writes.length(), 1)
  assert_eq(tuple_writes.length(), 1)
  let binaryen_func = cmd_native_wbtest_binaryen_tuple_opt_func_by_index(
    no_pass_writes[0].1,
    1,
  )
  let tuple_func = cmd_native_wbtest_normalize_func_by_index(
    tuple_writes[0].1,
    1,
  )
  assert_eq(tuple_func, binaryen_func, msg=tuple_func)
}

#cfg(target="native")
test "run_cmd_with_adapter tuple-optimization leaves debug artifact func 1930 unchanged" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let wasm = match cmd_native_read_file(input_path) {
    Ok(bytes) => bytes
    Err(err) => fail("expected checked-in artifact at \{input_path}: \{err}")
  }
  let no_pass_writes : Array[(String, Bytes)] = []
  let tuple_writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { [input_path] },
    file_exists=fn(path) { path == input_path },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      if path == "out-no-pass.wasm" {
        no_pass_writes.push((path, bytes))
      } else {
        tuple_writes.push((path, bytes))
      }
      Ok(())
    },
  )
  match run_cmd_with_adapter(["--out", "out-no-pass.wasm", input_path], io) {
    Ok(_) => ()
    Err(e) => fail("unexpected debug-artifact no-pass replay failure: \{e}")
  }
  match
    run_cmd_with_adapter(
      ["--tuple-optimization", "--out", "out-pass.wasm", input_path],
      io,
    ) {
    Ok(_) => ()
    Err(e) =>
      fail("unexpected tuple-optimization debug-artifact replay failure: \{e}")
  }
  assert_eq(no_pass_writes.length(), 1)
  assert_eq(tuple_writes.length(), 1)
  let no_pass_func = cmd_native_wbtest_normalize_func_by_index(
    no_pass_writes[0].1,
    1930,
  )
  let tuple_func = cmd_native_wbtest_normalize_func_by_index(
    tuple_writes[0].1,
    1930,
  )
  assert_eq(tuple_func, no_pass_func, msg=tuple_func)
}

///|
#cfg(target="native")
test "run_cmd_with_adapter tuple-optimization matches Binaryen for debug artifact func 3598" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let wasm = match cmd_native_read_file(input_path) {
    Ok(bytes) => bytes
    Err(err) => fail("expected checked-in artifact at \{input_path}: \{err}")
  }
  let no_pass_writes : Array[(String, Bytes)] = []
  let tuple_writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { [input_path] },
    file_exists=fn(path) { path == input_path },
    read_file=fn(path) {
      if path == input_path {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      if path == "out-no-pass.wasm" {
        no_pass_writes.push((path, bytes))
      } else {
        tuple_writes.push((path, bytes))
      }
      Ok(())
    },
  )
  match run_cmd_with_adapter(["--out", "out-no-pass.wasm", input_path], io) {
    Ok(_) => ()
    Err(e) => fail("unexpected debug-artifact no-pass replay failure: \{e}")
  }
  match
    run_cmd_with_adapter(
      ["--tuple-optimization", "--out", "out-pass.wasm", input_path],
      io,
    ) {
    Ok(_) => ()
    Err(e) =>
      fail("unexpected tuple-optimization debug-artifact replay failure: \{e}")
  }
  assert_eq(no_pass_writes.length(), 1)
  assert_eq(tuple_writes.length(), 1)
  let binaryen_func = cmd_native_wbtest_binaryen_tuple_opt_func_by_index(
    no_pass_writes[0].1,
    3598,
  )
  let tuple_func = cmd_native_wbtest_normalize_func_by_index(
    tuple_writes[0].1,
    3598,
  )
  assert_eq(tuple_func, binaryen_func, msg=tuple_func)
}
