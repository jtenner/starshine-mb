///|
using @binary {trait Decode, trait Encode}

///|
using @cli {type CliInputFormat}

///|
using @lib {type Module, type Func, type CodeSec, type TExpr, type TInstr}

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
test "run_cmd_with_adapter enforces cli over env over config precedence" {
  let config_json =
    #|{
    #|  "inputs": { "globs": ["cfg.wasm"] },
    #|  "outputs": { "outDir": "cfg-dist" },
    #|  "passes": ["global-effects"],
    #|  "optimize": { "trapMode": "never", "olevel": "O1" }
    #|}
  let wasm = encode_module_bytes(fixture_i32_const_module(5))
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    get_env=fn(key) {
      match key {
        "STARSHINE_INPUT" => Some("env.wasm")
        "STARSHINE_OUT_DIR" => Some("env-dist")
        "STARSHINE_PASSES" => Some("remove-unused-names")
        "STARSHINE_TRAP_MODE" => Some("never")
        "STARSHINE_OLEVEL" => Some("O2z")
        _ => None
      }
    },
    list_candidates=fn() { ["cfg.wasm", "env.wasm", "cli.wasm"] },
    file_exists=fn(path) {
      path == "cfg.json" ||
      path == "cfg.wasm" ||
      path == "env.wasm" ||
      path == "cli.wasm"
    },
    read_file=fn(path) {
      match path {
        "cfg.json" => Ok(bytes_from_string(config_json))
        "cfg.wasm" | "env.wasm" | "cli.wasm" => Ok(wasm)
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
        "--config", "cfg.json", "--out-dir", "cli-dist", "--vacuum", "--trap-mode",
        "allow", "-O3", "cli.wasm",
      ],
      io,
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  assert_true(has_string(summary.input_files, "cfg.wasm"))
  assert_true(has_string(summary.input_files, "env.wasm"))
  assert_true(has_string(summary.input_files, "cli.wasm"))
  assert_true(has_string(summary.resolved_passes, "global-effects"))
  assert_true(has_string(summary.resolved_passes, "remove-unused-names"))
  assert_true(has_string(summary.resolved_passes, "vacuum"))
  assert_eq(summary.optimize_level, 3)
  assert_eq(summary.traps_never_happen, false)
  for entry in writes {
    let (path, _) = entry
    assert_true(path.has_prefix("cli-dist/"))
  }
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
