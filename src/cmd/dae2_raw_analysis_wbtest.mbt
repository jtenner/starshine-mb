///|
test "command DAE2 modes prune flat arithmetic dependencies and retain store operands" {
  for pass in ["dae2", "dae2-optimizing"] {
    let output = cmd_deep_audit_run(
      "(module (memory 1) (func $h (param i32 i32 i32) local.get 0 local.get 1 i32.const 7 i32.add i32.store local.get 2 drop) (func (export \"run\") (param i32 i32) local.get 0 local.get 1 i32.const 9 call $h))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    assert_eq(cmd_deep_audit_body(output, index=1), [
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
