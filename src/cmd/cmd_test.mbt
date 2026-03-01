///|
using @binary {trait Decode, trait Encode}

///|
using @cli {type CliInputFormat}

///|
using @lib {
  type Module,
  type Func,
  type CodeSec,
  type TExpr,
  type TInstr,
  type TInstrKind,
}

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
fn bytes_to_ascii_string(bytes : Bytes) -> String {
  let out = StringBuilder::new()
  for b in bytes {
    let i = b.to_int()
    if i >= 0 && i <= 127 {
      out.write_char(i.unsafe_to_char())
    } else {
      out.write_char('?')
    }
  }
  out.to_string()
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
  let t_i32 = @lib.single_rec_type(
    @lib.comp_type_sub_type(@lib.func_comp_type([], [@lib.ValType::i32()])),
  )
  Module::new()
  .with_code_sec(
    CodeSec::new([
      Func::t_func([], TExpr::new([TInstr::i32_const(@lib.I32(value))])),
    ]),
  )
  .with_type_sec(@lib.TypeSec::new([t_i32]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0)]))
}

///|
fn fixture_f32_nan_module() -> Module {
  let nan_bits : UInt = 0x7FC00000
  let nan = @lib.F32(Float::reinterpret_from_uint(nan_bits))
  let t_f32 = @lib.single_rec_type(
    @lib.comp_type_sub_type(@lib.func_comp_type([], [@lib.ValType::f32()])),
  )
  Module::new()
  .with_code_sec(
    CodeSec::new([Func::t_func([], TExpr::new([TInstr::f32_const(nan)]))]),
  )
  .with_type_sec(@lib.TypeSec::new([t_f32]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0)]))
}

///|
fn fixture_mergeable_block_module() -> Module {
  let t_void = @lib.single_rec_type(
    @lib.comp_type_sub_type(@lib.func_comp_type([], [])),
  )
  Module::new()
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::block(
            @lib.BlockType::void_(),
            TExpr::new([
              TInstr::drop(TInstr::i32_const(@lib.I32(9))),
              TInstr::nop(),
            ]),
          ),
        ]),
      ),
    ]),
  )
  .with_type_sec(@lib.TypeSec::new([t_void]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0)]))
}

///|
fn run_optimize_wat_fixture_regression(
  path : String,
  wat_text : String,
  lowered_wasm? : Bytes? = None,
) -> Unit raise {
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(candidate) { candidate == path },
    list_candidates=fn() { [path] },
    read_file=fn(candidate) {
      if candidate == path {
        Ok(bytes_from_string(wat_text))
      } else {
        Err("missing fixture")
      }
    },
    lower_text_module=fn(candidate, _, _) {
      match lowered_wasm {
        Some(wasm) if candidate == path => Ok(wasm)
        _ => Err("text lowering not configured")
      }
    },
    write_file=fn(out_path, bytes) {
      writes.push((out_path, bytes))
      Ok(())
    },
  )
  let summary = match
    run_cmd_with_adapter(["--optimize", "--out", "out.wasm", path], io) {
    Ok(v) => v
    Err(e) => fail("expected --optimize success for \{path}, got \{e}")
  }
  assert_eq(summary.resolved_passes, ["optimize"])
  assert_eq(writes.length(), 1)
  assert_eq(writes[0].0, "out.wasm")
  ignore(decode_module_bytes(writes[0].1))
}

///|

///|
test "run_cmd_with_adapter --optimize handles examples/modules/simple.wat" {
  let wat =
    #|(module
    #|  (func (export "add_then_shift") (param i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    i32.add
    #|    i32.const 1
    #|    i32.shl))
  run_optimize_wat_fixture_regression("examples/modules/simple.wat", wat)
}

///|
test "run_cmd_with_adapter --optimize handles examples/modules/feature_mix.wat" {
  let wat =
    #|(module
    #|  (memory (export "mem") 1)
    #|  (table 2 funcref)
    #|  (global $g (mut i32) (i32.const 7))
    #|
    #|  (func $inc (param i32) (result i32)
    #|    local.get 0
    #|    global.get $g
    #|    i32.add)
    #|
    #|  (func $twice (param i32) (result i32)
    #|    local.get 0
    #|    call $inc
    #|    local.get 0
    #|    call $inc
    #|    i32.add)
    #|
    #|  (elem (i32.const 0) func $inc $twice)
    #|  (data (i32.const 0) "starshine-demo")
    #|
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $twice))
  run_optimize_wat_fixture_regression("examples/modules/feature_mix.wat", wat)
}

///|
test "run_cmd_with_adapter --optimize handles examples/modules/table_dispatch.wat" {
  let wat =
    #|(module
    #|  (type $unary (func (param i32) (result i32)))
    #|  (table 2 funcref)
    #|
    #|  (func $inc (type $unary) (param i32) (result i32)
    #|    local.get 0
    #|    i32.const 1
    #|    i32.add)
    #|
    #|  (func $dec (type $unary) (param i32) (result i32)
    #|    local.get 0
    #|    i32.const 1
    #|    i32.sub)
    #|
    #|  (elem (i32.const 0) func $inc $dec)
    #|
    #|  (func (export "dispatch") (param i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    call_indirect (type $unary)))
  run_optimize_wat_fixture_regression(
    "examples/modules/table_dispatch.wat", wat,
  )
}

///|
test "run_cmd_with_adapter --optimize handles examples/modules/simd_lane_mix.wat" {
  let wat =
    #|(module
    #|  (func (export "lane_add0") (param i32 i32) (result i32)
    #|    local.get 0
    #|    i8x16.splat
    #|    local.get 1
    #|    i8x16.splat
    #|    i8x16.add
    #|    i8x16.extract_lane_s 0))
  run_optimize_wat_fixture_regression("examples/modules/simd_lane_mix.wat", wat)
}

///|
fn module_first_f32_const(mod : Module) -> Float? {
  match mod.code_sec {
    Some(CodeSec([Func(_, Expr([F32Const(F32(v))])), ..])) => Some(v)
    Some(
      CodeSec(
        [
          TFunc(
            _,
            { instrs: [{ kind: TInstrKind::TF32Const(F32(v)), .. }], .. }
          ),
          ..,
        ]
      )
    ) => Some(v)
    _ => None
  }
}

///|
fn has_string(values : Array[String], needle : String) -> Bool {
  values.contains(needle)
}

///|
test "run_cmd_with_adapter infers optimize preset from -O level flags" {
  let wasm = encode_module_bytes(fixture_i32_const_module(31))
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
  let summary = match
    run_cmd_with_adapter(["-O3", "--out", "out.wasm", "a.wasm"], io) {
    Ok(v) => v
    Err(e) => fail("expected -O3 success, got \{e}")
  }
  assert_eq(summary.resolved_passes, ["optimize"])
  assert_eq(summary.optimize_level, 3)
  assert_eq(summary.shrink_level, 0)
  assert_eq(summary.output_files, ["out.wasm"])
  assert_eq(writes.length(), 1)
}

///|
test "run_cmd_with_adapter infers shrink preset from -O level with z bias" {
  let wasm = encode_module_bytes(fixture_i32_const_module(32))
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
  let summary = match
    run_cmd_with_adapter(["-O3z", "--out", "out.wasm", "a.wasm"], io) {
    Ok(v) => v
    Err(e) => fail("expected -O3z success, got \{e}")
  }
  assert_eq(summary.resolved_passes, ["shrink"])
  assert_eq(summary.optimize_level, 3)
  assert_eq(summary.shrink_level, 3)
  assert_eq(summary.output_files, ["out.wasm"])
  assert_eq(writes.length(), 1)
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
test "run_cmd_with_adapter lowers wat through in-process fallback when adapter is unavailable" {
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == "m.wat" },
    list_candidates=fn() { ["m.wat"] },
    read_file=fn(path) {
      if path == "m.wat" {
        Ok(bytes_from_string("(module (func (result i32) i32.const 41))"))
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match run_cmd_with_adapter(["m.wat"], io) {
    Ok(v) => v
    Err(e) =>
      fail("expected in-process wat lowering fallback success, got \{e}")
  }
  assert_eq(summary.output_files, ["m.wasm"])
  assert_eq(writes.length(), 1)
  let mod = decode_module_bytes(writes[0].1)
  match mod.code_sec {
    Some(CodeSec([Func(_, Expr([I32Const(I32(v))]))])) => assert_eq(v, 41)
    _ => fail("expected decoded wasm output from in-process wat fallback")
  }
}

///|
test "run_cmd_with_adapter lowers wast through in-process fallback when adapter is unavailable" {
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == "n.wast" },
    list_candidates=fn() { ["n.wast"] },
    read_file=fn(path) {
      if path == "n.wast" {
        Ok(bytes_from_string("(module (memory 1) (data (i32.const 0) \"A\"))"))
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = match run_cmd_with_adapter(["n.wast"], io) {
    Ok(v) => v
    Err(e) =>
      fail("expected in-process wast lowering fallback success, got \{e}")
  }
  assert_eq(summary.output_files, ["n.wasm"])
  assert_eq(writes.length(), 1)
  let mod = decode_module_bytes(writes[0].1)
  match (mod.mem_sec, mod.data_sec) {
    (Some(_), Some(DataSec([Data(_, bytes)]))) =>
      assert_eq(bytes_to_ascii_string(bytes), "A")
    _ => fail("expected decoded wasm output from in-process wast fallback")
  }
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
test "run_cmd_with_adapter reports config read failures with ConfigReadFailed" {
  let io = CmdIO::new(file_exists=fn(path) { path == "cfg.json" }, read_file=fn(
    path,
  ) {
    if path == "cfg.json" {
      Err("permission denied")
    } else {
      Err("missing fixture")
    }
  })
  match run_cmd_with_adapter(["--config", "cfg.json"], io) {
    Ok(summary) => fail("expected config read failure, got summary \{summary}")
    Err(CmdError::ConfigReadFailed(msg)) => {
      assert_true(msg.contains("cfg.json"))
      assert_true(msg.contains("permission denied"))
    }
    Err(err) => fail("expected ConfigReadFailed, got \{err}")
  }
}

///|
test "run_cmd_with_adapter reports decode failures with DecodeFailed" {
  let io = CmdIO::new(
    file_exists=fn(path) { path == "bad.wasm" },
    list_candidates=fn() { ["bad.wasm"] },
    read_file=fn(path) {
      if path == "bad.wasm" {
        Ok(bytes_from_string("not-wasm"))
      } else {
        Err("missing fixture")
      }
    },
  )
  match run_cmd_with_adapter(["bad.wasm"], io) {
    Ok(summary) => fail("expected decode failure, got summary \{summary}")
    Err(CmdError::DecodeFailed(path, err)) => {
      assert_eq(path, "bad.wasm")
      match err {
        @binary.DecodeError::Decode(
          @binary.BinaryDecodeError::InvalidMagicHeader
        ) => ()
        _ => fail("expected typed decode cause, got \{err}")
      }
    }
    Err(err) => fail("expected DecodeFailed, got \{err}")
  }
}

///|
test "run_cmd_with_adapter reports input read failures with InputReadFailed" {
  let io = CmdIO::new(
    file_exists=fn(path) { path == "a.wasm" },
    list_candidates=fn() { ["a.wasm"] },
    read_file=fn(path) {
      if path == "a.wasm" {
        Err("io timeout")
      } else {
        Err("missing fixture")
      }
    },
  )
  match run_cmd_with_adapter(["a.wasm"], io) {
    Ok(summary) => fail("expected input read failure, got summary \{summary}")
    Err(CmdError::InputReadFailed(msg)) => {
      assert_true(msg.contains("a.wasm"))
      assert_true(msg.contains("io timeout"))
    }
    Err(err) => fail("expected InputReadFailed, got \{err}")
  }
}

///|
test "run_cmd_with_adapter reports encode failures with EncodeFailed" {
  let wasm = encode_module_bytes(fixture_i32_const_module(8))
  let io = CmdIO::new(
    file_exists=fn(path) { path == "a.wasm" },
    list_candidates=fn() { ["a.wasm"] },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    encode_module=fn(_) {
      Err(CmdEncodeError::adapter("forced encode failure"))
    },
  )
  match run_cmd_with_adapter(["a.wasm"], io) {
    Ok(summary) => fail("expected encode failure, got summary \{summary}")
    Err(CmdError::EncodeFailed(path, err)) => {
      assert_eq(path, "a.wasm")
      assert_eq(err, CmdEncodeError::adapter("forced encode failure"))
    }
    Err(err) => fail("expected EncodeFailed, got \{err}")
  }
}

///|
test "config pass flags take precedence over env pass overlays when cli pass flags are absent" {
  let config_json =
    #|{
    #|  "inputs": { "globs": ["a.wasm"] },
    #|  "passes": ["global-effects"]
    #|}
  let wasm = encode_module_bytes(fixture_i32_const_module(17))
  let io = CmdIO::new(
    get_env=fn(name) {
      if name == "STARSHINE_PASSES" {
        Some("vacuum")
      } else {
        None
      }
    },
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
  let summary = match run_cmd_with_adapter(["--config", "cfg.json"], io) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  assert_eq(summary.resolved_passes, ["global-effects"])
}

///|
test "env optimize and trap overlays take precedence over config values when cli omits options" {
  let config_json =
    #|{
    #|  "inputs": { "globs": ["a.wasm"] },
    #|  "optimize": { "olevel": "O1", "trapMode": "allow" }
    #|}
  let wasm = encode_module_bytes(fixture_i32_const_module(18))
  let io = CmdIO::new(
    get_env=fn(name) {
      match name {
        "STARSHINE_OLEVEL" => Some("O3")
        "STARSHINE_TRAP_MODE" => Some("never")
        _ => None
      }
    },
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
  let summary = match run_cmd_with_adapter(["--config", "cfg.json"], io) {
    Ok(v) => v
    Err(e) => fail("unexpected run failure: \{e}")
  }
  assert_eq(summary.resolved_passes, ["optimize"])
  assert_eq(summary.optimize_level, 3)
  assert_true(summary.traps_never_happen)
}

///|
test "run_cmd_with_adapter prints help text and exits successfully for --help" {
  let stdout_writes : Array[Bytes] = []
  let io = CmdIO::new(write_stdout=fn(bytes) {
    stdout_writes.push(bytes)
    Ok(())
  })
  let summary = match run_cmd_with_adapter(["--help"], io) {
    Ok(v) => v
    Err(e) => fail("expected help success, got \{e}")
  }
  assert_eq(summary.input_files, [])
  assert_eq(summary.output_files, [])
  assert_eq(stdout_writes.length(), 1)
  let help = bytes_to_ascii_string(stdout_writes[0])
  assert_true(help.contains("Starshine Wasm Binary Toolkit"))
  assert_true(help.contains("v0.1.0"))
  assert_true(help.contains("Usage:"))
  assert_true(help.contains("--help"))
  assert_true(help.contains("--version"))
  assert_true(help.contains("--glob"))
  assert_true(help.contains("--global-effects"))
  assert_true(help.contains("--remove-unused"))
}

///|
test "run_cmd_with_adapter prints version and exits successfully for --version" {
  let stdout_writes : Array[Bytes] = []
  let io = CmdIO::new(write_stdout=fn(bytes) {
    stdout_writes.push(bytes)
    Ok(())
  })
  let summary = match run_cmd_with_adapter(["--version"], io) {
    Ok(v) => v
    Err(e) => fail("expected version success, got \{e}")
  }
  assert_eq(summary.input_files, [])
  assert_eq(summary.output_files, [])
  assert_eq(stdout_writes.length(), 1)
  assert_eq(bytes_to_ascii_string(stdout_writes[0]), "v0.1.0\n")
}

///|
test "run_cmd_with_adapter prints version and exits successfully for -V" {
  let stdout_writes : Array[Bytes] = []
  let io = CmdIO::new(write_stdout=fn(bytes) {
    stdout_writes.push(bytes)
    Ok(())
  })
  let summary = match run_cmd_with_adapter(["-V"], io) {
    Ok(v) => v
    Err(e) => fail("expected version success, got \{e}")
  }
  assert_eq(summary.input_files, [])
  assert_eq(summary.output_files, [])
  assert_eq(stdout_writes.length(), 1)
  assert_eq(bytes_to_ascii_string(stdout_writes[0]), "v0.1.0\n")
}

///|
test "run_cmd_with_adapter spec subcommand runs wast spec suite" {
  let stdout_writes : Array[Bytes] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == "ok.wast" },
    list_candidates=fn() { ["ok.wast"] },
    read_file=fn(path) {
      if path == "ok.wast" {
        Ok(bytes_from_string("(module)"))
      } else {
        Err("missing fixture")
      }
    },
    write_stdout=fn(bytes) {
      stdout_writes.push(bytes)
      Ok(())
    },
  )
  let summary = match run_cmd_with_adapter(["spec", "ok.wast"], io) {
    Ok(v) => v
    Err(e) => fail("expected spec run success, got \{e}")
  }
  assert_eq(summary.input_files, ["ok.wast"])
  assert_eq(summary.resolved_passes, ["spec"])
  assert_eq(stdout_writes.length(), 1)
  assert_true(bytes_to_ascii_string(stdout_writes[0]).contains("failed=0"))
}

///|
test "run_cmd_with_adapter spec subcommand only expands wildcard inputs with --glob" {
  let io = CmdIO::new(
    file_exists=fn(path) { path == "ok.wast" },
    list_candidates=fn() { ["ok.wast"] },
    read_file=fn(path) {
      if path == "ok.wast" {
        Ok(bytes_from_string("(module)"))
      } else {
        Err("missing fixture")
      }
    },
  )

  match run_cmd_with_adapter(["spec", "ok*.wast"], io) {
    Ok(summary) => fail("expected literal wildcard path failure, got \{summary}")
    Err(CmdError::InputReadFailed(msg)) =>
      assert_true(msg.contains("ok*.wast"))
    Err(err) => fail("expected InputReadFailed, got \{err}")
  }

  let summary = match run_cmd_with_adapter(["spec", "--glob", "ok*.wast"], io) {
    Ok(v) => v
    Err(e) => fail("expected glob-enabled spec success, got \{e}")
  }
  assert_eq(summary.input_files, ["ok.wast"])
}

///|
test "run_cmd_with_adapter spec subcommand reports failures" {
  let stdout_writes : Array[Bytes] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == "broken.wast" },
    list_candidates=fn() { ["broken.wast"] },
    read_file=fn(path) {
      if path == "broken.wast" {
        Ok(bytes_from_string("(assert_invalid (module) \"must fail\")"))
      } else {
        Err("missing fixture")
      }
    },
    write_stdout=fn(bytes) {
      stdout_writes.push(bytes)
      Ok(())
    },
  )
  match run_cmd_with_adapter(["spec", "broken.wast"], io) {
    Ok(summary) => fail("expected spec failure, got \{summary}")
    Err(CmdError::SpecFailed(msg)) => assert_true(msg.contains("broken.wast"))
    Err(err) => fail("expected SpecFailed, got \{err}")
  }
  assert_eq(stdout_writes.length(), 2)
  assert_true(bytes_to_ascii_string(stdout_writes[0]).contains("failed=1"))
}

///|
test "run_cmd_exit_code_with_adapter returns zero for successful runs" {
  let wasm = encode_module_bytes(fixture_i32_const_module(21))
  let io = CmdIO::new(
    file_exists=fn(path) { path == "a.wasm" },
    list_candidates=fn() { ["a.wasm"] },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(_, _) { Ok(()) },
  )
  let code = run_cmd_exit_code_with_adapter(["a.wasm"], io)
  assert_eq(code, 0)
}

///|
test "run_cmd_exit_code_with_adapter returns zero for --help" {
  let io = CmdIO::new(write_stdout=fn(_) { Ok(()) })
  let code = run_cmd_exit_code_with_adapter(["--help"], io)
  assert_eq(code, 0)
}

///|
test "run_cmd_exit_code_with_adapter returns zero for --version" {
  let io = CmdIO::new(write_stdout=fn(_) { Ok(()) })
  let code = run_cmd_exit_code_with_adapter(["--version"], io)
  assert_eq(code, 0)
}

///|
test "run_cmd_exit_code_with_adapter returns non-zero for failures" {
  let wasm = encode_module_bytes(fixture_i32_const_module(22))
  let io = CmdIO::new(
    file_exists=fn(path) { path == "a.wasm" },
    list_candidates=fn() { ["a.wasm"] },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(_, _) { Ok(()) },
  )
  let code = run_cmd_exit_code_with_adapter(["--not-a-real-pass", "a.wasm"], io)
  assert_eq(code, 1)
}

///|
test "run_cmd_exit_code_with_adapter writes CmdError details to stderr on failures" {
  let wasm = encode_module_bytes(fixture_i32_const_module(122))
  let stderr_writes : Array[Bytes] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == "a.wasm" },
    list_candidates=fn() { ["a.wasm"] },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(_, _) { Ok(()) },
    write_stderr=fn(bytes) {
      stderr_writes.push(bytes)
      Ok(())
    },
  )
  let code = run_cmd_exit_code_with_adapter(["--not-a-real-pass", "a.wasm"], io)
  assert_eq(code, 1)
  assert_eq(stderr_writes.length(), 1)
  let stderr_text = bytes_to_ascii_string(stderr_writes[0])
  assert_true(stderr_text.contains("error:"))
  assert_true(stderr_text.contains("not-a-real-pass"))
}

///|
test "run_cmd_exit_code_with_adapter does not write stderr on success" {
  let wasm = encode_module_bytes(fixture_i32_const_module(123))
  let stderr_writes : Array[Bytes] = []
  let io = CmdIO::new(
    file_exists=fn(path) { path == "a.wasm" },
    list_candidates=fn() { ["a.wasm"] },
    read_file=fn(path) {
      if path == "a.wasm" {
        Ok(wasm)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(_, _) { Ok(()) },
    write_stderr=fn(bytes) {
      stderr_writes.push(bytes)
      Ok(())
    },
  )
  let code = run_cmd_exit_code_with_adapter(["a.wasm"], io)
  assert_eq(code, 0)
  assert_eq(stderr_writes.length(), 0)
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
extern "c" fn native_fopen(path : Bytes, mode : Bytes) -> UInt64 = "fopen"

///|
#cfg(target="native")
extern "c" fn native_fclose(stream : UInt64) -> Int = "fclose"

///|
#cfg(target="native")
extern "c" fn native_fseek(stream : UInt64, offset : Int, whence : Int) -> Int = "fseek"

///|
#cfg(target="native")
extern "c" fn native_ftell(stream : UInt64) -> Int64 = "ftell"

///|
#cfg(target="native")
#borrow(ptr)
extern "c" fn native_fread(
  ptr : Bytes,
  size : UInt64,
  count : UInt64,
  stream : UInt64,
) -> UInt64 = "fread"

///|
#cfg(target="native")
#borrow(ptr)
extern "c" fn native_fwrite(
  ptr : Bytes,
  size : UInt64,
  count : UInt64,
  stream : UInt64,
) -> UInt64 = "fwrite"

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
extern "c" fn native_fork() -> Int = "fork"

///|
#cfg(target="native")
#borrow(status)
extern "c" fn native_waitpid(pid : Int, status : Bytes, options : Int) -> Int = "waitpid"

///|
#cfg(target="native")
extern "c" fn native_exit(code : Int) -> Unit = "exit"

///|
#cfg(target="native")
#borrow(tv)
extern "c" fn native_gettimeofday(tv : Bytes, tz : UInt64) -> Int = "gettimeofday"

///|
#cfg(target="native")
fn native_read_u64_timeval(bytes : Bytes, start : Int) -> UInt64 {
  let mut out = 0UL
  let mut i = 0
  while i < 8 {
    out = out | (bytes[start + i].to_uint64() << (i * 8))
    i += 1
  }
  out
}

///|
#cfg(target="native")
fn native_now_ms() -> UInt64 {
  let tv = Bytes::new(16)
  if native_gettimeofday(tv, 0UL) != 0 {
    return @env.now()
  }
  let sec = native_read_u64_timeval(tv, 0)
  let usec = native_read_u64_timeval(tv, 8)
  sec * 1000UL + usec / 1000UL
}

///|
#cfg(target="native")
fn native_remove_if_exists(path : String) -> Unit {
  let c_path = native_c_string(path)
  ignore(native_remove(c_path))
}

///|
#cfg(target="native")
fn native_tmp_file(name : String) -> String {
  "/tmp/starshine-cmd-\{name}-\{native_now_ms()}.wasm"
}

///|
#cfg(target="native")
fn native_write_bytes(path : String, bytes : Bytes) -> Bool {
  let c_path = native_c_string(path)
  let c_mode = native_c_string("wb")
  let file = native_fopen(c_path, c_mode)
  if file == 0UL {
    return false
  }
  let expected = bytes.length()
  let wrote = if expected == 0 {
    0UL
  } else {
    native_fwrite(bytes, 1UL, expected.to_uint64(), file)
  }
  let close_code = native_fclose(file)
  if expected == 0 {
    close_code == 0
  } else {
    wrote == expected.to_uint64() && close_code == 0
  }
}

///|
#cfg(target="native")
fn native_read_bytes(path : String) -> Bytes? {
  let c_path = native_c_string(path)
  let c_mode = native_c_string("rb")
  let file = native_fopen(c_path, c_mode)
  if file == 0UL {
    return None
  }
  if native_fseek(file, 0, 2) != 0 {
    ignore(native_fclose(file))
    return None
  }
  let size_i64 = native_ftell(file)
  if size_i64 < 0L {
    ignore(native_fclose(file))
    return None
  }
  let size_u = size_i64.reinterpret_as_uint64()
  if size_u > 2147483647UL {
    ignore(native_fclose(file))
    return None
  }
  let size = size_i64.to_int()
  if native_fseek(file, 0, 0) != 0 {
    ignore(native_fclose(file))
    return None
  }
  let out = Bytes::new(size)
  if size > 0 {
    let read = native_fread(out, 1UL, size_u, file)
    if read != size_u {
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
  let c_name = native_c_string(name)
  let c_value = native_c_string(value)
  native_setenv(c_name, c_value, 1) == 0
}

///|
#cfg(target="native")
fn native_unset_env(name : String) -> Unit {
  let c_name = native_c_string(name)
  ignore(native_unsetenv(c_name))
}

///|
#cfg(target="native")
fn native_wait_status_raw(status : Bytes) -> Int {
  let mut raw = 0
  let mut shift = 0
  let mut i = 0
  while i < status.length() {
    raw = raw | (status[i].to_int() << shift)
    i += 1
    shift += 8
  }
  raw
}

///|
#cfg(target="native")
fn native_run_cmd_exit_status(args : Array[String]) -> (Bool, Int) {
  let pid = native_fork()
  if pid < 0 {
    abort("failed to fork child process for run_cmd integration test")
  }
  if pid == 0 {
    let code = run_cmd_exit_code(args)
    native_exit(code)
    abort("native_exit should not return")
  }
  let status = Bytes::new(4)
  let waited = native_waitpid(pid, status, 0)
  if waited != pid {
    abort(
      "waitpid returned unexpected pid \{waited}; expected child pid \{pid}",
    )
  }
  let raw = native_wait_status_raw(status)
  let signal = raw & 0x7F
  if signal != 0 && signal != 0x7F {
    return (true, signal)
  }
  let code = (raw >> 8) & 0xFF
  (false, code)
}

///|
#cfg(target="native")
test "run_cmd native child process does not crash for file rewrite" {
  let input_path = native_tmp_file("child-io-input")
  let output_path = native_tmp_file("child-io-output")
  native_remove_if_exists(input_path)
  native_remove_if_exists(output_path)

  let wasm = encode_module_bytes(fixture_i32_const_module(31))
  assert_true(native_write_bytes(input_path, wasm))

  let (signaled, status) = native_run_cmd_exit_status([
    "--vacuum", "--out", output_path, input_path,
  ])
  if signaled {
    native_remove_if_exists(input_path)
    native_remove_if_exists(output_path)
    fail("expected child to exit normally, got signal \{status}")
  }
  assert_eq(status, 0)
  match native_read_bytes(output_path) {
    Some(bytes) => ignore(decode_module_bytes(bytes))
    None => fail("expected native output file at \{output_path}")
  }

  native_remove_if_exists(input_path)
  native_remove_if_exists(output_path)
}

///|
#cfg(target="native")
test "run_cmd native child process does not crash for --optimize" {
  let input_path = native_tmp_file("child-opt-input")
  let output_path = native_tmp_file("child-opt-output")
  native_remove_if_exists(input_path)
  native_remove_if_exists(output_path)

  let wasm = encode_module_bytes(fixture_i32_const_module(32))
  assert_true(native_write_bytes(input_path, wasm))

  let (signaled, status) = native_run_cmd_exit_status([
    "--optimize", "--out", output_path, input_path,
  ])
  if signaled {
    native_remove_if_exists(input_path)
    native_remove_if_exists(output_path)
    fail("expected child to exit normally, got signal \{status}")
  }
  assert_eq(status, 0)
  match native_read_bytes(output_path) {
    Some(bytes) => ignore(decode_module_bytes(bytes))
    None => fail("expected optimized output file at \{output_path}")
  }

  native_remove_if_exists(input_path)
  native_remove_if_exists(output_path)
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
  let prefix = "tmp-starshine-cmd-glob-\{native_now_ms()}"
  let input_path = "\{prefix}.wasm"
  native_remove_if_exists(input_path)

  let wasm = encode_module_bytes(fixture_i32_const_module(16))
  assert_true(native_write_bytes(input_path, wasm))

  match run_cmd(["--vacuum", "\{prefix}*.wasm"]) {
    Ok(summary) =>
      fail(
        "expected literal wildcard path to stay literal without --glob, got \{summary}",
      )
    Err(CmdError::InputReadFailed(msg)) =>
      assert_true(msg.contains("\{prefix}*.wasm"))
    Err(e) => {
      native_remove_if_exists(input_path)
      fail("expected InputReadFailed without --glob, got \{e}")
    }
  }

  let summary = match run_cmd(["--glob", "--vacuum", "\{prefix}*.wasm"]) {
    Ok(v) => v
    Err(e) => {
      native_remove_if_exists(input_path)
      fail(
        "expected wildcard input to resolve via native list_candidates with --glob, got \{e}",
      )
    }
  }
  assert_eq(summary.input_files, [input_path])

  native_remove_if_exists(input_path)
}

///|
#cfg(target="native")
test "run_cmd wires native default text-lowering hook for wat inputs" {
  let base = "tmp-starshine-cmd-wat-\{native_now_ms()}"
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

///|
#cfg(target="wasm")
test "run_cmd uses wasm default io for --help" {
  match run_cmd(["--help"]) {
    Ok(_) => ()
    Err(e) => fail("expected wasm --help success with default io, got \{e}")
  }
}

///|
#cfg(target="wasm")
test "run_cmd uses wasm default io for --version" {
  match run_cmd(["--version"]) {
    Ok(_) => ()
    Err(e) => fail("expected wasm --version success with default io, got \{e}")
  }
}
