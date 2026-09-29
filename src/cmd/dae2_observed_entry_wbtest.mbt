///|
test "command DAE2 modes preserve private observable stores while pruning unrelated dead arguments" {
  for pass in ["dae2", "dae2-optimizing"] {
    let output = cmd_deep_audit_run(
      "(module (memory 1) (func $store (param i32 i32) local.get 0 local.get 1 i32.store) (func $helper (param i32) (result i32) i32.const 7) (func (export \"run\") (result i32) i32.const 9 call $helper) (func (export \"keep\") (param i32 i32) local.get 0 local.get 1 call $store))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    assert_eq(cmd_deep_audit_body(output, index=2), [
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    ])
    assert_eq(cmd_deep_audit_body(output, index=3), [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    ])
    assert_eq(
      @validate.Env::new()
      .with_module(output)
      .get_functype_by_funcidx(@lib.FuncIdx::new(0U)),
      Some(@lib.FuncType::new([@lib.ValType::i32(), @lib.ValType::i32()], [])),
    )
  }
}
