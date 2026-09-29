///|
test "command DAE2 modes prune branchless scalar blocks while retaining import effects and loads" {
  for pass in ["dae2", "dae2-optimizing"] {
    let output = cmd_deep_audit_run(
      "(module (memory 1) (import \"m\" \"value\" (func $v (result i32))) (func $h (param i32 i32 i32) (result i32) call $v drop block (result i32) local.get 1 i32.load end) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 i32.const 8 call $h))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    assert_eq(
      @validate.Env::new()
      .with_module(output)
      .get_functype_by_funcidx(@lib.FuncIdx::new(1U)),
      Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
    )
    assert_eq(cmd_deep_audit_body(output), [
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::i32_load(@lib.MemArg::new(2U, None, 0UL)),
    ])
  }
}

///|
test "command DAE2 modes preserve stacked entry values across branchless block overwrites" {
  for pass in ["dae2", "dae2-optimizing"] {
    let output = cmd_deep_audit_run(
      "(module (func $h (param i32 i32 i32) (result i32) local.get 1 block i32.const 11 local.set 1 end local.get 1 i32.add) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 i32.const 8 call $h))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    assert_eq(
      @validate.Env::new()
      .with_module(output)
      .get_functype_by_funcidx(@lib.FuncIdx::new(0U)),
      Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
    )
    let @lib.Func(_, @lib.Expr(caller)) = output.code_sec.unwrap().0[1]
    assert_eq(caller, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    ])
  }
}
