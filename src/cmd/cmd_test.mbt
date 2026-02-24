///|
using @binary {trait Decode, trait Encode}

///|
using @cli {type CliInputFormat}

///|
using @lib {type Module, type Func, type CodeSec, type TExpr, type TInstr}

///|
using @passes {
  optimize_module_with_options,
  type ModulePass,
  type OptimizeOptions,
}

///|
fn bytes_from_string(text : String) -> Bytes {
  let buf = @buffer.new(size_hint=text.length())
  for c in text {
    buf.write_byte(c.to_int().to_byte())
  }
  buf.to_bytes()
}

///|
fn encode_module_bytes(mod : Module) -> Bytes {
  let buf = @buffer.new()
  match Encode::encode(mod, buf) {
    Ok(_) => buf.to_bytes()
    Err(e) => abort("unexpected module encode failure in test fixture: \{e}")
  }
}

///|
fn decode_module_bytes(bytes : Bytes) -> Module {
  match Decode::decode(bytes, 0) {
    Ok((mod, idx)) => {
      if idx != bytes.length() {
        abort(
          "unexpected trailing bytes while decoding fixture module: decoded \{idx}, total \{bytes.length()}",
        )
      }
      mod
    }
    Err(e) => abort("unexpected module decode failure in test fixture: \{e}")
  }
}

///|
fn fixture_i32_const_module(value : Int) -> Module {
  Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func([], TExpr::new([TInstr::i32_const(@lib.I32(value))])),
    ]),
  )
}

///|
fn fixture_f32_nan_module() -> Module {
  let nan_bits : UInt = 0x7FC00000
  let nan = @lib.F32(Float::reinterpret_from_uint(nan_bits))
  Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], TExpr::new([TInstr::f32_const(nan)]))]),
  )
}

///|
fn fixture_mergeable_block_module() -> Module {
  Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::block(
            @lib.BlockType::void_(),
            TExpr::new([TInstr::i32_const(@lib.I32(9)), TInstr::nop()]),
          ),
        ]),
      ),
    ]),
  )
}

///|
fn module_first_f32_const(mod : Module) -> Float? {
  match mod.code_sec {
    Some(CodeSec([Func(_, Expr([F32Const(F32(v))])), ..])) => Some(v)
    Some(CodeSec([TFunc(_, TExpr([TF32Const(F32(v))])), ..])) => Some(v)
    _ => None
  }
}

///|
fn has_string(values : Array[String], needle : String) -> Bool {
  values.contains(needle)
}

///|
test "run_cmd_with_adapter rejects unknown pass flags with strict diagnostics" {
  let wasm = encode_module_bytes(fixture_i32_const_module(1))
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm"] },
    file_exists=fn(path) { path == "a.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(_, _) { Ok(()) },
  )
  match run_cmd_with_adapter(["--not-a-real-pass", "a.wasm"], io) {
    Ok(summary) =>
      fail("expected strict unknown-pass error, got summary \{summary}")
    Err(err) => assert_eq(err, CmdError::unknown_pass_flag("not-a-real-pass"))
  }
}

///|
test "run_cmd_with_adapter transforms every resolved input file and writes each to out dir" {
  let wasm_a = encode_module_bytes(fixture_i32_const_module(1))
  let wasm_b = encode_module_bytes(fixture_i32_const_module(2))
  let writes : Array[(String, Bytes)] = []

  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm", "b.wasm"] },
    file_exists=fn(path) { path == "a.wasm" || path == "b.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm_a)
      } else if path == "b.wasm" {
        Ok(wasm_b)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )

  let summary = match
    run_cmd_with_adapter(
      ["--out-dir", "dist", "a.wasm", "b.wasm", "--global-effects"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  assert_eq(summary.input_files, ["a.wasm", "b.wasm"])
  assert_eq(summary.output_files, ["dist/a.wasm", "dist/b.wasm"])
  assert_eq(writes.length(), 2)
}

///|
test "run_cmd_with_adapter lowers wat and wast inputs through text-module adapter" {
  let lowered = encode_module_bytes(fixture_i32_const_module(9))
  let lower_calls : Array[(String, CliInputFormat)] = []
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wat", "b.wast"] },
    file_exists=fn(path) { path == "a.wat" || path == "b.wast" },
    read_file=fn(path) {
      if path == "a.wat" || path == "b.wast" {
        Ok(bytes_from_string("(module (func))"))
      } else {
        Err("missing fixture")
      }
    },
    lower_text_module=fn(path, format, _) {
      lower_calls.push((path, format))
      Ok(lowered)
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      ["--out-dir", "dist", "a.wat", "b.wast", "--vacuum"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  assert_eq(lower_calls, [
    ("a.wat", CliInputFormat::wat()),
    ("b.wast", CliInputFormat::wast()),
  ])
  assert_eq(summary.output_files, ["dist/a.wasm", "dist/b.wasm"])
  assert_eq(writes.length(), 2)
}

///|
test "run_cmd_with_adapter runs requested passes for each module" {
  let wasm = encode_module_bytes(fixture_f32_nan_module())
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm", "b.wasm"] },
    file_exists=fn(path) { path == "a.wasm" || path == "b.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" || path == "b.wasm" {
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
  let summary = match
    run_cmd_with_adapter(
      ["--de-nan", "--out-dir", "dist", "a.wasm", "b.wasm"],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  assert_eq(writes.length(), 2)
  for entry in writes {
    let (_, bytes) = entry
    let mod = decode_module_bytes(bytes)
    match module_first_f32_const(mod) {
      Some(v) => assert_eq(v, 0.0)
      None => fail("expected module to contain first f32 const")
    }
  }
  assert_true(has_string(summary.resolved_passes, "de-nan"))
}

///|
test "run_cmd_with_adapter runs re-reloop when requested" {
  let input_mod = fixture_mergeable_block_module()
  let input_wasm = encode_module_bytes(input_mod)
  let expected_mod = match
    optimize_module_with_options(
      input_mod,
      [ModulePass::ReReloop],
      OptimizeOptions::new(),
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected re_reloop fixture output, got optimize error: \{e}")
  }
  let expected_wasm = encode_module_bytes(expected_mod)
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm"] },
    file_exists=fn(path) { path == "a.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(input_wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(["--re-reloop", "--out", "out.wasm", "a.wasm"], io) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  assert_eq(summary.resolved_passes, ["re-reloop"])
  assert_eq(writes.length(), 1)
  assert_eq(writes[0].0, "out.wasm")
  assert_eq(writes[0].1, expected_wasm)
}

///|
test "run_cmd_with_adapter preserves repeated pass flags in cli order" {
  let wasm = encode_module_bytes(fixture_i32_const_module(4))
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm"] },
    file_exists=fn(path) { path == "a.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(_, _) { Ok(()) },
  )
  let summary = match
    run_cmd_with_adapter(["--vacuum", "--optimize", "--vacuum", "a.wasm"], io) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  assert_eq(summary.resolved_passes, ["vacuum", "optimize", "vacuum"])
}

///|
test "run_cmd_with_adapter uses config passes when cli does not provide pass flags" {
  let config_json =
    #|{
    #|  "inputs": { "globs": ["cfg.wasm", "cli.wasm"] },
    #|  "outputs": { "outDir": "cfg-dist" },
    #|  "passes": ["global-effects"],
    #|  "optimize": { "trapMode": "never", "olevel": "O3" },
    #|  "options": {
    #|    "monomorphizeMinBenefit": 2,
    #|    "lowMemoryUnused": true,
    #|    "lowMemoryBound": 4096
    #|  }
    #|}
  let wasm = encode_module_bytes(fixture_i32_const_module(5))
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["cfg.wasm", "cli.wasm"] },
    file_exists=fn(path) {
      path == "cfg.json" || path == "cfg.wasm" || path == "cli.wasm"
    },
    read_file=fn(path) {
      match path {
        "cfg.json" => Ok(bytes_from_string(config_json))
        "cfg.wasm" | "cli.wasm" => Ok(wasm)
        _ => Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(
      [
        "--config", "cfg.json", "--out-dir", "cli-dist", "-O1", "--trap-mode", "allow",
        "--monomorphize-min-benefit", "11", "--no-low-memory-unused", "--low-memory-bound",
        "2048", "cli.wasm",
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  assert_true(has_string(summary.input_files, "cfg.wasm"))
  assert_true(has_string(summary.input_files, "cli.wasm"))
  assert_true(has_string(summary.resolved_passes, "global-effects"))
  assert_eq(summary.resolved_passes, ["global-effects"])
  assert_eq(summary.optimize_level, 1)
  assert_eq(summary.traps_never_happen, false)
  assert_eq(summary.monomorphize_min_benefit, 11)
  assert_eq(summary.low_memory_unused, false)
  assert_eq(summary.low_memory_bound, 2048UL)
  for entry in writes {
    let (path, _) = entry
    assert_true(path.has_prefix("cli-dist/"))
  }
}

///|
test "run_cmd_with_adapter lets cli pass flags override config pass lists" {
  let config_json =
    #|{
    #|  "inputs": { "globs": ["a.wasm"] },
    #|  "passes": ["global-effects", "remove-unused-names"]
    #|}
  let wasm = encode_module_bytes(fixture_i32_const_module(6))
  let io = CmdIO::new(
    file_exists=fn(path) { path == "cfg.json" || path == "a.wasm" },
    list_candidates=fn() { ["a.wasm"] },
    read_file=fn(path) {
      match path {
        "cfg.json" => Ok(bytes_from_string(config_json))
        "a.wasm" => Ok(wasm)
        _ => Err("missing fixture")
      }
    },
    write_file=fn(_, _) { Ok(()) },
  )
  let summary = match
    run_cmd_with_adapter(["--config", "cfg.json", "--vacuum", "a.wasm"], io) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  assert_eq(summary.resolved_passes, ["vacuum"])
}

///|
test "run_cmd_with_adapter ignores unknown config pass flags when cli pass flags are present" {
  let config_json =
    #|{
    #|  "inputs": { "globs": ["a.wasm"] },
    #|  "passes": ["not-a-real-pass"]
    #|}
  let wasm = encode_module_bytes(fixture_i32_const_module(8))
  let io = CmdIO::new(
    file_exists=fn(path) { path == "cfg.json" || path == "a.wasm" },
    list_candidates=fn() { ["a.wasm"] },
    read_file=fn(path) {
      match path {
        "cfg.json" => Ok(bytes_from_string(config_json))
        "a.wasm" => Ok(wasm)
        _ => Err("missing fixture")
      }
    },
    write_file=fn(_, _) { Ok(()) },
  )
  let summary = match
    run_cmd_with_adapter(["--config", "cfg.json", "--vacuum", "a.wasm"], io) {
    Ok(v) => v
    Err(e) =>
      fail(
        "config pass list should be ignored once cli pass flags are set, got error \{e}",
      )
  }
  assert_eq(summary.resolved_passes, ["vacuum"])
}

///|
test "run_cmd_with_adapter uses input paths when no explicit outputs are set" {
  let wasm = encode_module_bytes(fixture_i32_const_module(7))
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm"] },
    file_exists=fn(path) { path == "a.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" {
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
  let summary = match run_cmd_with_adapter(["a.wasm", "--vacuum"], io) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  assert_eq(summary.output_files, ["a.wasm"])
  assert_eq(writes.length(), 1)
  assert_eq(writes[0].0, "a.wasm")
}

///|
test "run_cmd_with_adapter rejects a single --out target for multiple inputs" {
  let wasm = encode_module_bytes(fixture_i32_const_module(11))
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm", "b.wasm"] },
    file_exists=fn(path) { path == "a.wasm" || path == "b.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" || path == "b.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
  )
  match run_cmd_with_adapter(["--out", "one.wasm", "a.wasm", "b.wasm"], io) {
    Ok(summary) => fail("expected ambiguous output error, got \{summary}")
    Err(err) => assert_eq(err, CmdError::ambiguous_output_file("one.wasm"))
  }
}

///|
test "run_cmd_with_adapter loads default config path when present" {
  let config_json =
    #|{
    #|  "inputs": { "globs": ["cfg.wasm"] },
    #|  "outputs": { "outDir": "cfg-out" },
    #|  "passes": ["global-effects"]
    #|}
  let wasm = encode_module_bytes(fixture_i32_const_module(3))
  let io = CmdIO::new(
    list_candidates=fn() { ["cfg.wasm"] },
    file_exists=fn(path) {
      path == @cli.DEFAULT_CONFIG_PATH || path == "cfg.wasm"
    },
    read_file=fn(path) {
      if path == @cli.DEFAULT_CONFIG_PATH {
        Ok(bytes_from_string(config_json))
      } else if path == "cfg.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(_, _) { Ok(()) },
  )
  let summary = match run_cmd_with_adapter([], io) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  assert_eq(summary.input_files, ["cfg.wasm"])
  assert_eq(summary.output_files, ["cfg-out/cfg.wasm"])
  assert_true(has_string(summary.resolved_passes, "global-effects"))
}

///|
test "run_cmd_with_adapter accepts optional inline json config in the same call" {
  let config_json =
    #|{
    #|  "inputs": { "globs": ["a.wasm"] },
    #|  "outputs": { "outDir": "inline-out" },
    #|  "passes": ["global-effects"],
    #|  "options": { "trapsNeverHappen": true }
    #|}
  let wasm = encode_module_bytes(fixture_i32_const_module(12))
  let io = CmdIO::new(
    list_candidates=fn() { ["a.wasm"] },
    file_exists=fn(path) { path == "a.wasm" },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(_, _) { Ok(()) },
  )
  let summary = match
    run_cmd_with_adapter([], io, config_json=Some(config_json)) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  assert_eq(summary.output_files, ["inline-out/a.wasm"])
  assert_eq(summary.resolved_passes, ["global-effects"])
  assert_true(summary.traps_never_happen)
}

///|
#cfg(target="native")
fn native_c_string(text : String) -> Bytes {
  let out = @buffer.new(size_hint=text.length() + 1)
  for c in text {
    let code = c.to_int()
    if code >= 0 && code <= 255 {
      out.write_byte(code.to_byte())
    } else {
      out.write_byte('?'.to_int().to_byte())
    }
  }
  out.write_byte(0)
  out.to_bytes()
}

///|
#cfg(target="native")
#borrow(path, mode)
extern "c" fn native_fopen(path : Bytes, mode : Bytes) -> Int = "fopen"

///|
#cfg(target="native")
extern "c" fn native_fclose(stream : Int) -> Int = "fclose"

///|
#cfg(target="native")
extern "c" fn native_fseek(stream : Int, offset : Int, whence : Int) -> Int = "fseek"

///|
#cfg(target="native")
extern "c" fn native_ftell(stream : Int) -> Int = "ftell"

///|
#cfg(target="native")
#borrow(ptr)
extern "c" fn native_fread(
  ptr : Bytes,
  size : Int,
  count : Int,
  stream : Int,
) -> Int = "fread"

///|
#cfg(target="native")
#borrow(ptr)
extern "c" fn native_fwrite(
  ptr : Bytes,
  size : Int,
  count : Int,
  stream : Int,
) -> Int = "fwrite"

///|
#cfg(target="native")
#borrow(path)
extern "c" fn native_remove(path : Bytes) -> Int = "remove"

///|
#cfg(target="native")
#borrow(name, value)
extern "c" fn native_setenv(
  name : Bytes,
  value : Bytes,
  overwrite : Int,
) -> Int = "setenv"

///|
#cfg(target="native")
#borrow(name)
extern "c" fn native_unsetenv(name : Bytes) -> Int = "unsetenv"

///|
#cfg(target="native")
extern "c" fn native_dup(fd : Int) -> Int = "dup"

///|
#cfg(target="native")
extern "c" fn native_dup2(old_fd : Int, new_fd : Int) -> Int = "dup2"

///|
#cfg(target="native")
extern "c" fn native_close(fd : Int) -> Int = "close"

///|
#cfg(target="native")
extern "c" fn native_fflush(stream : Int) -> Int = "fflush"

///|
#cfg(target="native")
fn native_remove_if_exists(path : String) -> Unit {
  ignore(native_remove(native_c_string(path)))
}

///|
#cfg(target="native")
fn native_tmp_file(name : String) -> String {
  "/tmp/starshine-cmd-\{name}-\{@env.now()}.wasm"
}

///|
#cfg(target="native")
fn native_write_bytes(path : String, bytes : Bytes) -> Bool {
  let file = native_fopen(native_c_string(path), native_c_string("wb"))
  if file == 0 {
    return false
  }
  let expected = bytes.length()
  let wrote = if expected == 0 {
    0
  } else {
    native_fwrite(bytes, 1, expected, file)
  }
  let close_code = native_fclose(file)
  if expected == 0 {
    close_code == 0
  } else {
    wrote == expected && close_code == 0
  }
}

///|
#cfg(target="native")
fn native_read_bytes(path : String) -> Bytes? {
  let file = native_fopen(native_c_string(path), native_c_string("rb"))
  if file == 0 {
    return None
  }
  if native_fseek(file, 0, 2) != 0 {
    ignore(native_fclose(file))
    return None
  }
  let size = native_ftell(file)
  if size < 0 {
    ignore(native_fclose(file))
    return None
  }
  if native_fseek(file, 0, 0) != 0 {
    ignore(native_fclose(file))
    return None
  }
  let out = Bytes::new(size)
  if size > 0 {
    let read = native_fread(out, 1, size, file)
    if read != size {
      ignore(native_fclose(file))
      return None
    }
  }
  if native_fclose(file) != 0 {
    return None
  }
  Some(out)
}

///|
#cfg(target="native")
fn native_set_env(name : String, value : String) -> Bool {
  native_setenv(native_c_string(name), native_c_string(value), 1) == 0
}

///|
#cfg(target="native")
fn native_unset_env(name : String) -> Unit {
  ignore(native_unsetenv(native_c_string(name)))
}

///|
#cfg(target="native")
test "run_cmd uses native default io to read inputs and write outputs" {
  let input_path = native_tmp_file("io-input")
  let output_path = native_tmp_file("io-output")
  native_remove_if_exists(input_path)
  native_remove_if_exists(output_path)

  let wasm = encode_module_bytes(fixture_i32_const_module(13))
  assert_true(native_write_bytes(input_path, wasm))

  let summary = match run_cmd(["--vacuum", "--out", output_path, input_path]) {
    Ok(v) => v
    Err(e) => fail("expected native run_cmd success, got \{e}")
  }
  assert_eq(summary.input_files, [input_path])
  assert_eq(summary.output_files, [output_path])

  match native_read_bytes(output_path) {
    Some(bytes) => ignore(decode_module_bytes(bytes))
    None => fail("expected native output file at \{output_path}")
  }

  native_remove_if_exists(input_path)
  native_remove_if_exists(output_path)
}

///|
#cfg(target="native")
test "run_cmd reads STARSHINE_INPUT from native environment" {
  let input_path = native_tmp_file("env-input")
  let output_path = native_tmp_file("env-output")
  native_remove_if_exists(input_path)
  native_remove_if_exists(output_path)

  let wasm = encode_module_bytes(fixture_i32_const_module(14))
  assert_true(native_write_bytes(input_path, wasm))
  assert_true(native_set_env("STARSHINE_INPUT", input_path))

  let result = run_cmd(["--vacuum", "--out", output_path])
  native_unset_env("STARSHINE_INPUT")
  let summary = match result {
    Ok(v) => v
    Err(e) =>
      fail(
        "expected native STARSHINE_INPUT wiring to provide inputs, got error \{e}",
      )
  }
  assert_eq(summary.input_files, [input_path])
  assert_eq(summary.output_files, [output_path])

  native_remove_if_exists(input_path)
  native_remove_if_exists(output_path)
}

///|
#cfg(target="native")
test "run_cmd uses native stdout wiring and surfaces write failures" {
  let input_path = native_tmp_file("stdout-input")
  native_remove_if_exists(input_path)
  let wasm = encode_module_bytes(fixture_i32_const_module(15))
  assert_true(native_write_bytes(input_path, wasm))

  let saved_stdout = native_dup(1)
  if saved_stdout < 0 {
    native_remove_if_exists(input_path)
    fail("failed to duplicate stdout fd")
  }
  ignore(native_close(1))
  let result = run_cmd(["--stdout", "--vacuum", input_path])
  ignore(native_dup2(saved_stdout, 1))
  ignore(native_close(saved_stdout))
  ignore(native_fflush(0))

  native_remove_if_exists(input_path)

  match result {
    Err(CmdError::OutputWriteFailed(msg)) =>
      assert_true(msg.contains("stdout for"))
    Ok(summary) =>
      fail(
        "expected stdout write failure with closed fd, got summary \{summary}",
      )
    Err(err) =>
      fail("expected OutputWriteFailed when stdout is closed, got \{err}")
  }
}

///|
#cfg(target="native")
test "run_cmd uses native default candidate enumeration for wildcard input globs" {
  let prefix = "tmp-starshine-cmd-glob-\{@env.now()}"
  let input_path = "\{prefix}.wasm"
  native_remove_if_exists(input_path)

  let wasm = encode_module_bytes(fixture_i32_const_module(16))
  assert_true(native_write_bytes(input_path, wasm))

  let summary = match run_cmd(["--vacuum", "\{prefix}*.wasm"]) {
    Ok(v) => v
    Err(e) => {
      native_remove_if_exists(input_path)
      fail(
        "expected wildcard input to resolve via native list_candidates, got \{e}",
      )
    }
  }
  assert_eq(summary.input_files, [input_path])

  native_remove_if_exists(input_path)
}

///|
#cfg(target="native")
test "run_cmd wires native default text-lowering hook for wat inputs" {
  let base = "tmp-starshine-cmd-wat-\{@env.now()}"
  let wat_path = "\{base}.wat"
  let out_path = "\{base}.wasm"
  native_remove_if_exists(wat_path)
  native_remove_if_exists(out_path)
  assert_true(native_write_bytes(wat_path, bytes_from_string("(module)")))

  let result = run_cmd([wat_path])
  match result {
    Ok(summary) => {
      assert_eq(summary.input_files, [wat_path])
      assert_eq(summary.output_files, [out_path])
      match native_read_bytes(out_path) {
        Some(bytes) => ignore(decode_module_bytes(bytes))
        None => fail("expected lowered wasm output at \{out_path}")
      }
    }
    Err(CmdError::TextLoweringFailed(msg)) =>
      assert_false(msg.contains("text lowering not configured"))
    Err(e) => fail("unexpected native wat run_cmd failure: \{e}")
  }

  native_remove_if_exists(wat_path)
  native_remove_if_exists(out_path)
}
