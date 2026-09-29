///|
test "command DAE2 modes prune scalar flat calls while preserving writes and effects" {
  for pass in ["dae2", "dae2-optimizing"] {
    let output = cmd_deep_audit_run(
      "(module (import \"m\" \"value\" (func $v (result i32))) (func $h (param i32 i32) (result i32) local.get 1 local.set 0 local.get 0) (func (export \"run\") (param i32) (result i32) call $v local.get 0 call $h))",
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
