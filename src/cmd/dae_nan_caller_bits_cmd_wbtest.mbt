///|
fn cmd_nan_caller_bits_fixture(pruned : Bool) -> @lib.Module {
  let parameter = if pruned { "" } else { "(param i32)" }
  let callee_value = if pruned { "i32.const 7" } else { "local.get 0" }
  let argument = if pruned { "" } else { "i32.const 7" }
  @passes.pass_test_module_from_wat(
    "(module (import \"m\" \"f32\" (func $f32 (param f32))) (import \"m\" \"i32\" (func $i32 (param i32))) (import \"m\" \"f64\" (func $f64 (param f64))) " +
    "(global (export \"negative_zero\") f64 (f64.const -0)) " +
    "(func $h \{parameter} (result i32) \{callee_value} call $i32 i32.const 11) " +
    "(func (export \"run\") (result f64) f32.const nan:0x400021 call $f32 f64.const nan:0x8000000000021 call $f64 \{argument} call $h call $i32 f64.const nan:0x8000000000001) " +
    "(func (export \"unrelated_nan\") (result f32) f32.const nan:0x400077))",
  ).with_custom_secs([
    @lib.CustomSec::new(@lib.Name::new("vendor.nan.keep"), b"kept"),
  ])
}

///|
fn cmd_nan_caller_bits_checked(pass : String) -> Unit raise {
  let input = cmd_nan_caller_bits_fixture(false).with_name_sec(
    @lib.NameSec::new(
      func_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(3U, @lib.Name::new("private_target")),
        ]),
      ),
    ),
  )
  let expected = cmd_nan_caller_bits_fixture(true).without_name_sec()
  @validate.validate_module(input).unwrap()
  @validate.validate_module(expected).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let expected_bytes = @binary.encode_module(expected).unwrap()
  let writes : Array[Bytes] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["nan-caller.wasm"] },
    file_exists=fn(path) { path == "nan-caller.wasm" },
    read_file=fn(_) { Ok(saved) },
    write_file=fn(_, bytes) {
      writes.push(bytes)
      Ok(())
    },
  )
  let summary = run_cmd_with_adapter(
    ["--" + pass, "nan-caller.wasm", "-o", "out.wasm"],
    io,
  ).unwrap()
  assert_eq(summary.resolved_passes, [pass])
  assert_eq(writes.length(), 1)
  assert_eq(writes[0], expected_bytes)
  let output = @binary.decode_module(writes[0]).unwrap()
  @validate.validate_module(output).unwrap()
  let env = @validate.Env::new().with_module(output)
  assert_eq(
    env.get_functype_by_funcidx(@lib.FuncIdx::new(3U)),
    Some(@lib.FuncType::new([], [@lib.ValType::i32()])),
  )
  assert_eq(
    env.get_functype_by_funcidx(@lib.FuncIdx::new(4U)),
    Some(@lib.FuncType::new([], [@lib.ValType::f64()])),
  )
  let funcs = output.code_sec.unwrap().0
  assert_eq(funcs.length(), 3)
  let @lib.Func(_, @lib.Expr(callee)) = funcs[0]
  assert_eq(callee, [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(11)),
  ])
  let @lib.Func(_, @lib.Expr(caller)) = funcs[1]
  assert_eq(caller.length(), 7)
  match caller[0] {
    @lib.F32Const(@lib.F32(value)) =>
      assert_eq(value.reinterpret_as_uint(), 0x7fc00021U)
    _ => fail("first caller NaN must remain the exact f32 host-effect argument")
  }
  assert_eq(caller[1], @lib.Instruction::call(@lib.FuncIdx::new(0U)))
  match caller[2] {
    @lib.F64Const(@lib.F64(value)) =>
      assert_eq(value.reinterpret_as_uint64(), 0x7ff8000000000021UL)
    _ =>
      fail("interior caller NaN must remain the exact f64 host-effect argument")
  }
  assert_eq(caller[3], @lib.Instruction::call(@lib.FuncIdx::new(2U)))
  assert_eq(caller[4], @lib.Instruction::call(@lib.FuncIdx::new(3U)))
  assert_eq(caller[5], @lib.Instruction::call(@lib.FuncIdx::new(1U)))
  match caller[6] {
    @lib.F64Const(@lib.F64(value)) =>
      assert_eq(value.reinterpret_as_uint64(), 0x7ff8000000000001UL)
    _ => fail("last caller NaN must remain the exact exported result")
  }
  let @lib.Func(_, @lib.Expr(unrelated)) = funcs[2]
  match unrelated {
    [@lib.F32Const(@lib.F32(value))] =>
      assert_eq(value.reinterpret_as_uint(), 0x7fc00077U)
    _ => fail("unrelated NaN function must retain its payload")
  }
  let @lib.Global(_, @lib.Expr(global)) = output.global_sec.unwrap().0[0]
  match global {
    [@lib.F64Const(@lib.F64(value))] =>
      assert_eq(value.reinterpret_as_uint64(), 0x8000000000000000UL)
    _ => fail("negative zero global must retain its sign bit")
  }
  assert_true(output.name_sec is None)
  assert_eq(output.custom_secs, input.custom_secs)
  assert_eq(output.export_sec, expected.export_sec)
  // The same active dispatcher also receives the actual IR, so ownership is
  // checked beyond the command's decode/write boundary. No private telemetry.
  let direct = cmd_deep_audit_run_module(input, pass)
  @validate.validate_module(direct).unwrap()
  assert_eq(@binary.encode_module(direct).unwrap(), expected_bytes)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "command dae prunes a uniform parameter while retaining first interior last and unrelated NaN bits" {
  cmd_nan_caller_bits_checked("dae")
}

///|
test "command dae optimizing prunes a uniform parameter while retaining NaN host effects results and metadata" {
  cmd_nan_caller_bits_checked("dae-optimizing")
}
