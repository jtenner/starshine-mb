///|
fn capture_cleanup_cmd_checked(pass : String) -> Unit raise {
  let input = @passes.pass_test_module_from_wat(
    "(module (import \"host\" \"tick\" (func $tick (param i32))) (func $h (param i32 i64) (result i32) local.get 0 i32.const 1 i32.add) (func (export \"run\") (param i32) (result i32) local.get 0 call $tick local.get 0 i64.const 9 call $h))",
  )
  let bytes = @binary.encode_module(input).unwrap()
  let writes : Array[Bytes] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["input.wasm"] },
    file_exists=fn(path) { path == "input.wasm" },
    read_file=fn(_) { Ok(bytes) },
    write_file=fn(_, output) {
      writes.push(output)
      Ok(())
    },
  )
  let summary = run_cmd_with_adapter(
    ["--" + pass, "input.wasm", "-o", "out.wasm"],
    io,
  ).unwrap()
  assert_eq(summary.resolved_passes, [pass])
  assert_eq(writes.length(), 1)
  let output = @binary.decode_module(writes[0]).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(output.import_sec, input.import_sec)
  assert_eq(
    @validate.Env::new()
    .with_module(output)
    .get_functype_by_funcidx(@lib.FuncIdx::new(1U)),
    Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
  )
  let @lib.Func(_, @lib.Expr(helper)) = output.code_sec.unwrap().0[0]
  assert_eq(helper, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_add(),
  ])
  let @lib.Func(_, @lib.Expr(caller)) = output.code_sec.unwrap().0[1]
  assert_eq(caller, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
  ])
  assert_eq(@binary.encode_module(input).unwrap(), bytes)
}

///|
test "command dae preserves host effects and unused-argument pruning" {
  capture_cleanup_cmd_checked("dae")
}

///|
test "command dae-optimizing preserves host effects and unused-argument pruning" {
  capture_cleanup_cmd_checked("dae-optimizing")
}

///|
test "command dae2 preserves host effects and unused-argument pruning" {
  capture_cleanup_cmd_checked("dae2")
}

///|
test "command dae2-optimizing preserves host effects and unused-argument pruning" {
  capture_cleanup_cmd_checked("dae2-optimizing")
}
