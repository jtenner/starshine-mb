///|
test "command DAE2 modes prune tee carriers and preserve discarded imported argument effects" {
  for pass in ["dae2", "dae2-optimizing"] {
    let output = cmd_deep_audit_run(
      "(module (import \"m\" \"value\" (func $v (result i32))) (func $h (param i32 i32 i32) (result i32) local.get 1 local.tee 0 drop local.get 0) (func (export \"run\") (param i32) (result i32) call $v local.get 0 i32.const 8 call $h))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    assert_eq(
      @validate.Env::new()
      .with_module(output)
      .get_functype_by_funcidx(@lib.FuncIdx::new(1U)),
      Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
    )
    assert_eq(cmd_deep_audit_body(output, index=1), [
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    ])
  }
}

///|
test "command DAE2 modes remove unread original body-local tee writes" {
  for pass in ["dae2", "dae2-optimizing"] {
    let output = cmd_deep_audit_run(
      "(module (memory 1) (func $h (param i32 i32 i32) (result i32) (local i32) local.get 1 i32.load local.tee 3) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 i32.const 8 call $h))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    assert_eq(
      @validate.Env::new()
      .with_module(output)
      .get_functype_by_funcidx(@lib.FuncIdx::new(0U)),
      Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
    )
    assert_eq(cmd_deep_audit_body(output, index=0), [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::i32_load(@lib.MemArg::new(2U, None, 0UL)),
    ])
  }
}
