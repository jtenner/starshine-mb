///|
#cfg(target="native")
#borrow(name, value)
extern "c" fn cmd_native_wbtest_setenv(
  name : Bytes,
  value : Bytes,
  overwrite : Int,
) -> Int = "setenv"

///|
#cfg(target="native")
#borrow(name)
extern "c" fn cmd_native_wbtest_unsetenv(name : Bytes) -> Int = "unsetenv"

///|
#cfg(target="native")
fn cmd_native_wbtest_set_env(name : String, value : String) -> Bool {
  cmd_native_wbtest_setenv(
    cmd_native_c_string(name),
    cmd_native_c_string(value),
    1,
  ) ==
  0
}

///|
#cfg(target="native")
fn cmd_native_wbtest_unset_env(name : String) -> Unit {
  ignore(cmd_native_wbtest_unsetenv(cmd_native_c_string(name)))
}

///|
#cfg(target="native")
test "cmd_native_get_env reads process environment without shelling out" {
  let name = "STARSHINE_CMD_NATIVE_GET_ENV_TEST"
  let value = " spaced value with punctuation !@# "
  cmd_native_wbtest_unset_env(name)
  @debug.assert_eq(cmd_native_get_env(name), None)
  assert_true(cmd_native_wbtest_set_env(name, value))
  @debug.assert_eq(cmd_native_get_env(name), Some(value))
  cmd_native_wbtest_unset_env(name)
  @debug.assert_eq(cmd_native_get_env(name), None)
}

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
fn cnw_starts_with(text : String, prefix : String) -> Bool {
  text.length() >= prefix.length() &&
  text.sub(start=0, end=prefix.length()).to_string() == prefix
}

///|
#cfg(target="native")
fn cnw_starts_with_at(text : String, start : Int, prefix : String) -> Bool {
  start >= 0 &&
  start + prefix.length() <= text.length() &&
  text.sub(start~, end=start + prefix.length()).to_string() == prefix
}

///|
#cfg(target="native")
fn cmd_native_wbtest_canonicalize_body_locals(body : String) -> String {
  let local_ids : @hashmap.HashMap[Int, Int] = @hashmap.new(capacity=32)
  let out = StringBuilder::new()
  let mut next_local = 0
  let mut i = 0
  while i < body.length() {
    if i + 7 <= body.length() &&
      body.sub(start=i, end=i + 7).to_string() == "(Local " {
      out.write_string("(Local ")
      i += 7
      let mut local_id = 0
      while i < body.length() && body[i] >= '0' && body[i] <= '9' {
        local_id = local_id * 10 + (body[i].to_int() - '0'.to_int())
        i += 1
      }
      let canonical_local = match local_ids.get(local_id) {
        Some(canonical_local) => canonical_local
        None => {
          let canonical_local = next_local
          next_local += 1
          local_ids.set(local_id, canonical_local)
          canonical_local
        }
      }
      out.write_string(canonical_local.to_string())
      continue
    }
    out.write_char(body[i].unsafe_to_char())
    i += 1
  }
  out.to_string()
}

///|
#cfg(target="native")
fn cmd_native_wbtest_token_local_id(token : String) -> Int? {
  let marker = "(Local "
  let mut i = 0
  while i + marker.length() <= token.length() {
    if token.sub(start=i, end=i + marker.length()).to_string() == marker {
      let mut j = i + marker.length()
      let mut local_id = 0
      let mut saw_digit = false
      while j < token.length() && token[j] >= '0' && token[j] <= '9' {
        local_id = local_id * 10 + (token[j].to_int() - '0'.to_int())
        j += 1
        saw_digit = true
      }
      if saw_digit {
        return Some(local_id)
      }
    }
    i += 1
  }
  None
}

///|
#cfg(target="native")
fn cmd_native_wbtest_reorder_scalar_ladders(body : String) -> String {
  let tokens : Array[String] = []
  let mut i = 0
  while i < body.length() {
    let ch = body[i].unsafe_to_char()
    if ch == ' ' || ch == '\n' || ch == '\t' {
      i += 1
      continue
    }
    if ch == '(' {
      let start = i
      let mut depth = 0
      while i < body.length() {
        let inner = body[i].unsafe_to_char()
        if inner == '(' {
          depth += 1
        } else if inner == ')' {
          depth -= 1
          if depth == 0 {
            i += 1
            break
          }
        }
        i += 1
      }
      tokens.push(body.sub(start~, end=i).to_string())
      continue
    }
    if cnw_starts_with_at(body, i, "drop") {
      tokens.push("drop")
      i += 4
      continue
    }
    i += 1
  }
  let out = StringBuilder::new()
  let mut token_idx = 0
  while token_idx < tokens.length() {
    if token_idx + 8 < tokens.length() &&
      cnw_starts_with(tokens[token_idx], "(local.get (Local ") &&
      cnw_starts_with(tokens[token_idx + 1], "(local.set (Local ") &&
      cnw_starts_with(tokens[token_idx + 2], "(local.get (Local ") &&
      cnw_starts_with(tokens[token_idx + 3], "(local.get (Local ") &&
      cnw_starts_with(tokens[token_idx + 4], "(local.get (Local ") &&
      cnw_starts_with(tokens[token_idx + 5], "(local.set (Local ") &&
      cnw_starts_with(tokens[token_idx + 6], "(local.set (Local ") &&
      cnw_starts_with(tokens[token_idx + 7], "(local.tee (Local ") &&
      cnw_starts_with(tokens[token_idx + 8], "(local.set (Local ") &&
      cmd_native_wbtest_token_local_id(tokens[token_idx + 1]) ==
      cmd_native_wbtest_token_local_id(tokens[token_idx + 3]) {
      out.write_string(tokens[token_idx + 2])
      out.write_string(tokens[token_idx])
      out.write_string(tokens[token_idx + 4])
      out.write_string(tokens[token_idx + 5])
      out.write_string(tokens[token_idx + 6])
      out.write_string(tokens[token_idx + 7])
      out.write_string(tokens[token_idx + 8])
      token_idx += 9
      continue
    }
    if token_idx + 6 < tokens.length() &&
      cnw_starts_with(tokens[token_idx], "(local.get (Local ") &&
      cnw_starts_with(tokens[token_idx + 1], "(local.set (Local ") &&
      cnw_starts_with(tokens[token_idx + 2], "(local.get (Local ") &&
      cnw_starts_with(tokens[token_idx + 3], "(local.set (Local ") &&
      cnw_starts_with(tokens[token_idx + 4], "(local.get (Local ") &&
      cnw_starts_with(tokens[token_idx + 5], "(local.tee (Local ") &&
      cnw_starts_with(tokens[token_idx + 6], "(local.set (Local ") {
      out.write_string(tokens[token_idx + 4])
      out.write_string(tokens[token_idx + 2])
      out.write_string(tokens[token_idx])
      out.write_string(tokens[token_idx + 1])
      out.write_string(tokens[token_idx + 3])
      out.write_string(tokens[token_idx + 5])
      out.write_string(tokens[token_idx + 6])
      token_idx += 7
      continue
    }
    out.write_string(tokens[token_idx])
    token_idx += 1
  }
  out.to_string()
}

///|
#cfg(target="native")
fn cmd_native_wbtest_canonicalize_func_pretty(pretty : String) -> String {
  let out = StringBuilder::new()
  let mut wrote_line = false
  let mut in_body = false
  for raw_line in pretty.split("\n") {
    let line = raw_line.to_string()
    if cnw_starts_with(line, "  type_idx:") ||
      line == "  locals:" ||
      cnw_starts_with(line, "    [") {
      continue
    }
    let normalized_line = if cnw_starts_with(line, "  body_raw:") {
      in_body = true
      if line.length() == "  body_raw:".length() {
        line
      } else {
        "  body_raw:" +
        cmd_native_wbtest_reorder_scalar_ladders(
          cmd_native_wbtest_canonicalize_body_locals(
            line.sub(start="  body_raw:".length()).to_string(),
          ),
        )
      }
    } else if in_body {
      let mut indent = 0
      while indent < line.length() && line[indent].unsafe_to_char() == ' ' {
        indent += 1
      }
      line.sub(start=0, end=indent).to_string() +
      cmd_native_wbtest_reorder_scalar_ladders(
        cmd_native_wbtest_canonicalize_body_locals(
          line.sub(start=indent).to_string(),
        ),
      )
    } else {
      line
    }
    if wrote_line {
      out.write_char('\n')
    }
    out.write_string(normalized_line)
    wrote_line = true
  }
  out.to_string()
}

///|
#cfg(target="native")
test "cmd_native_wbtest reorder scalar ladders normalizes reused temp chains" {
  let body = "(local.get (Local 6))(local.set (Local 9))(local.get (Local 8))(local.get (Local 9))(local.get (Local 5))(local.set (Local 10))(local.set (Local 11))(local.tee (Local 12))(local.set (Local 13))"
  @debug.assert_eq(
    cmd_native_wbtest_reorder_scalar_ladders(body),
    "(local.get (Local 8))(local.get (Local 6))(local.get (Local 5))(local.set (Local 10))(local.set (Local 11))(local.tee (Local 12))(local.set (Local 13))",
  )
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
  cmd_native_wbtest_canonicalize_func_pretty(
    mod_.pretty_print_func(@lib.FuncIdx::new(func_idx.reinterpret_as_uint())),
  )
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
    Err(err) =>
      abort("failed to decode native binaryen tuple wasm bytes: \{err}")
  }
  cmd_native_remove_file(in_path)
  cmd_native_remove_file(out_path)
  cmd_native_wbtest_canonicalize_func_pretty(
    mod_.pretty_print_func(@lib.FuncIdx::new(func_idx.reinterpret_as_uint())),
  )
}

///|
#cfg(target="native")
fn cmd_native_wbtest_write_u32_leb(buf : @buffer.Buffer, value : Int) -> Unit {
  @binary.encode_unsigned(value.to_uint64(), buf, 32).unwrap()
}

///|
#cfg(target="native")
fn cmd_native_wbtest_deep_nested_block_module_bytes(depth : Int) -> Bytes {
  let type_payload = @buffer.new()
  cmd_native_wbtest_write_u32_leb(type_payload, 1)
  type_payload.write_byte(0x60)
  cmd_native_wbtest_write_u32_leb(type_payload, 0)
  cmd_native_wbtest_write_u32_leb(type_payload, 0)

  let func_payload = @buffer.new()
  cmd_native_wbtest_write_u32_leb(func_payload, 1)
  cmd_native_wbtest_write_u32_leb(func_payload, 0)

  let body = @buffer.new()
  cmd_native_wbtest_write_u32_leb(body, 0)
  for _ in 0..<depth {
    body.write_byte(0x02)
    body.write_byte(0x40)
  }
  for _ in 0..<depth {
    body.write_byte(0x0B)
  }
  body.write_byte(0x0B)
  let body_bytes = body.to_bytes()

  let code_payload = @buffer.new()
  cmd_native_wbtest_write_u32_leb(code_payload, 1)
  cmd_native_wbtest_write_u32_leb(code_payload, body_bytes.length())
  code_payload.write_bytes(body_bytes)

  let wasm = @buffer.new()
  wasm.write_bytes(b"\x00\x61\x73\x6D\x01\x00\x00\x00")
  wasm.write_byte(0x01)
  cmd_native_wbtest_write_u32_leb(wasm, type_payload.to_bytes().length())
  wasm.write_bytes(type_payload.to_bytes())
  wasm.write_byte(0x03)
  cmd_native_wbtest_write_u32_leb(wasm, func_payload.to_bytes().length())
  wasm.write_bytes(func_payload.to_bytes())
  wasm.write_byte(0x0A)
  cmd_native_wbtest_write_u32_leb(wasm, code_payload.to_bytes().length())
  wasm.write_bytes(code_payload.to_bytes())
  wasm.to_bytes()
}

///|
#cfg(target="native")
test "run_cmd_with_adapter decodes deep nested wasm on native without stack-limit hacks" {
  let wasm = cmd_native_wbtest_deep_nested_block_module_bytes(10000)
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == "deep.wasm" },
    list_candidates=fn() { ["deep.wasm"] },
    read_file=fn(path) {
      if path == "deep.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    encode_module=fn(_) { Ok(wasm) },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  match run_cmd_with_adapter(["--out", "deep-out.wasm", "deep.wasm"], io) {
    Ok(summary) => {
      @debug.assert_eq(summary.input_files, ["deep.wasm"])
      @debug.assert_eq(summary.output_files, ["deep-out.wasm"])
      @debug.assert_eq(writes.length(), 1)
      @debug.assert_eq(writes[0].0, "deep-out.wasm")
      @debug.assert_eq(writes[0].1, wasm)
    }
    Err(err) => fail("expected deep native decode success, got \{err}")
  }
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
  @debug.assert_eq(writes.length(), 1)
  let printed = cmd_native_wbtest_print_wasm_bytes(writes[0].1)
  cnw_assert_occurs_in_order(printed, [
    "call 0", "local.set 8", "local.set 7", "local.tee 6", "local.set 11", "local.get 7",
    "local.set 10", "local.get 11", "local.get 10", "local.get 8", "local.set 5",
    "local.set 4", "local.tee 3", "local.set 15", "local.get 5", "local.set 14",
    "local.get 4", "local.set 13", "local.get 3", "local.tee 12", "local.set 16",
    "local.get 16", "local.tee 0", "drop", "local.get 15", "drop",
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
  @debug.assert_eq(writes.length(), 1)
  let printed = cmd_native_wbtest_print_wasm_bytes(writes[0].1)
  cnw_assert_occurs_in_order(printed, [
    "local.tee 6", "local.set 11", "local.get 7", "local.set 10", "local.tee 3",
    "local.set 15", "local.tee 12", "local.set 16", "local.tee 0", "drop", "local.get 15",
    "drop",
  ])
  @debug.assert_eq(cnw_count_substring(printed, "local.tee "), 4, msg=printed)
}

///|
#cfg(target="native")
test "run_cmd_with_adapter tuple-optimization matches Binaryen for chained host-copy tail-live0" {
  let input_mod = match
    @wast.wast_to_binary_module(
      "(module (type (func (param i32 i32) (result i32 i32 i32))) (import \"env\" \"tri\" (func (type 0))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 8 local.set 7 local.tee 6 local.set 11 local.get 7 local.set 10 block (result i32 i32 i32) local.get 11 local.get 10 local.get 8 end local.set 5 local.set 4 local.tee 3 block (result i32 i32 i32) local.get 3 local.get 4 local.get 5 end local.set 2 local.set 1 local.tee 0 drop drop local.get 0))",
      filename="tuple-host-tail-live0.wat",
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("unexpected tail-live0 exact parity fixture parse failure: \{err}")
  }
  let wasm = match encode_module(input_mod) {
    Ok(bytes) => bytes
    Err(err) =>
      fail("unexpected tail-live0 exact parity fixture encode failure: \{err}")
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
      fail(
        "unexpected tuple-optimization tail-live0 exact parity failure: \{e}",
      )
  }
  @debug.assert_eq(writes.length(), 1)
  let actual = cmd_native_wbtest_normalize_func_by_index(writes[0].1, 1)
  let expected = cmd_native_wbtest_binaryen_tuple_opt_func_by_index(wasm, 1)
  @debug.assert_eq(actual, expected)
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
      fail("unexpected mixed direct-producer tuple-optimization failure: \{e}")
  }
  @debug.assert_eq(writes.length(), 1)
  let binaryen_func = cmd_native_wbtest_binaryen_tuple_opt_func_by_index(
    wasm, 2,
  )
  let tuple_func = cmd_native_wbtest_normalize_func_by_index(writes[0].1, 2)
  @debug.assert_eq(tuple_func, binaryen_func, msg=tuple_func)
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
  @debug.assert_eq(writes.length(), 1)
  let binaryen_func = cmd_native_wbtest_binaryen_tuple_opt_func_by_index(
    wasm, 2,
  )
  let tuple_func = cmd_native_wbtest_normalize_func_by_index(writes[0].1, 2)
  @debug.assert_eq(tuple_func, binaryen_func, msg=tuple_func)
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
  @debug.assert_eq(writes.length(), 1)
  let binaryen_func = cmd_native_wbtest_binaryen_tuple_opt_func_by_index(
    wasm, 2,
  )
  let tuple_func = cmd_native_wbtest_normalize_func_by_index(writes[0].1, 2)
  @debug.assert_eq(tuple_func, binaryen_func, msg=tuple_func)
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
        "--tuple-optimization", "--out", "out.wasm", "tuple-scalar-forward-no-host-chain.wasm",
      ],
      io,
    ) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "unexpected chained scalar-forward no-host copy tuple-optimization failure: \{e}",
      )
  }
  @debug.assert_eq(writes.length(), 1)
  let binaryen_func = cmd_native_wbtest_binaryen_tuple_opt_func_by_index(
    wasm, 1,
  )
  let tuple_func = cmd_native_wbtest_normalize_func_by_index(writes[0].1, 1)
  @debug.assert_eq(tuple_func, binaryen_func, msg=tuple_func)
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
  @debug.assert_eq(writes.length(), 1)
  let binaryen_func = cmd_native_wbtest_binaryen_tuple_opt_func_by_index(
    wasm, 2,
  )
  let tuple_func = cmd_native_wbtest_normalize_func_by_index(writes[0].1, 2)
  @debug.assert_eq(tuple_func, binaryen_func, msg=tuple_func)
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
  @debug.assert_eq(writes.length(), 1)
  let printed = cmd_native_wbtest_print_wasm_bytes(writes[0].1)
  @debug.assert_eq(cnw_count_substring(printed, "tuple.make"), 0, msg=printed)
}

///|
#cfg(target="native")
test "run_cmd_with_adapter tuple-optimization matches Binaryen for two-lane exact-copy chains past unrelated multivalue blocks" {
  let input_mod = match
    @wast.wast_to_binary_module(
      "(module (func (result i32 i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) block (result i32 i32) i32.const 10 i32.const 20 end local.set 1 local.set 0 local.get 0 local.set 3 local.get 1 local.set 2 block (result i32 i32 i32) i32.const 30 i32.const 40 i32.const 50 end local.set 6 local.set 5 local.set 4 local.get 4 drop local.get 5 drop local.get 6 drop block (result i32 i32) local.get 2 local.get 3 end local.set 8 local.set 7 local.get 7 local.set 10 local.get 8 local.set 9 local.get 7 drop local.get 8 drop local.get 9 local.get 10))",
      filename="tuple-two-lane-exact-chain.wat",
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "unexpected two-lane exact-copy chain parity fixture parse failure: \{err}",
      )
  }
  let wasm = match encode_module(input_mod) {
    Ok(bytes) => bytes
    Err(err) =>
      fail(
        "unexpected two-lane exact-copy chain parity fixture encode failure: \{err}",
      )
  }
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["tuple-two-lane-exact-chain.wasm"] },
    file_exists=fn(path) { path == "tuple-two-lane-exact-chain.wasm" },
    read_file=fn(path) {
      if path == "tuple-two-lane-exact-chain.wasm" {
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
        "--tuple-optimization", "--out", "out.wasm", "tuple-two-lane-exact-chain.wasm",
      ],
      io,
    ) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "unexpected tuple-optimization two-lane exact-copy chain failure: \{e}",
      )
  }
  @debug.assert_eq(writes.length(), 1)
  let binaryen_func = cmd_native_wbtest_binaryen_tuple_opt_func_by_index(
    wasm, 0,
  )
  let tuple_func = cmd_native_wbtest_normalize_func_by_index(writes[0].1, 0)
  @debug.assert_eq(tuple_func, binaryen_func, msg=tuple_func)
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
  @debug.assert_eq(writes.length(), 1)
  let printed = cmd_native_wbtest_print_wasm_bytes(writes[0].1)
  cnw_assert_occurs_in_order(printed, [
    "call 0", "local.set 8", "local.set 7", "local.set 6", "local.get 8", "local.set 5",
    "local.get 7", "local.set 4", "local.get 6", "local.set 3", "local.get 5", "local.set 2",
    "local.get 4", "local.set 1", "local.get 3", "local.set 0", "local.get 1", "drop",
    "local.get 2", "drop", "local.get 0",
  ])
  @debug.assert_eq(cnw_count_substring(printed, "block (type "), 0, msg=printed)
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
  @debug.assert_eq(no_pass_writes.length(), 1)
  @debug.assert_eq(tuple_writes.length(), 1)
  let binaryen_func = cmd_native_wbtest_binaryen_tuple_opt_func_by_index(
    no_pass_writes[0].1,
    1,
  )
  let tuple_func = cmd_native_wbtest_normalize_func_by_index(
    tuple_writes[0].1,
    1,
  )
  @debug.assert_eq(tuple_func, binaryen_func, msg=tuple_func)
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
  @debug.assert_eq(no_pass_writes.length(), 1)
  @debug.assert_eq(tuple_writes.length(), 1)
  let binaryen_func = cmd_native_wbtest_binaryen_tuple_opt_func_by_index(
    no_pass_writes[0].1,
    1,
  )
  let tuple_func = cmd_native_wbtest_normalize_func_by_index(
    tuple_writes[0].1,
    1,
  )
  @debug.assert_eq(tuple_func, binaryen_func, msg=tuple_func)
}

///|
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
  @debug.assert_eq(no_pass_writes.length(), 1)
  @debug.assert_eq(tuple_writes.length(), 1)
  let no_pass_func = cmd_native_wbtest_normalize_func_by_index(
    no_pass_writes[0].1,
    1930,
  )
  let tuple_func = cmd_native_wbtest_normalize_func_by_index(
    tuple_writes[0].1,
    1930,
  )
  @debug.assert_eq(tuple_func, no_pass_func, msg=tuple_func)
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
  @debug.assert_eq(no_pass_writes.length(), 1)
  @debug.assert_eq(tuple_writes.length(), 1)
  let binaryen_func = cmd_native_wbtest_binaryen_tuple_opt_func_by_index(
    no_pass_writes[0].1,
    3598,
  )
  let tuple_func = cmd_native_wbtest_normalize_func_by_index(
    tuple_writes[0].1,
    3598,
  )
  @debug.assert_eq(tuple_func, binaryen_func, msg=tuple_func)
}
