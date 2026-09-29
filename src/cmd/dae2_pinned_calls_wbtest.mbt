///|
test "command DAE2 variants prune active helper arguments beside pinned imported calls" {
  for pass in ["dae2", "dae2-optimizing"] {
    let output = cmd_deep_audit_run(
      "(module (import \"host\" \"echo\" (func $echo (param i32) (result i32))) (func $h (param i32) (result i32) i32.const 7) (func (export \"run\") (result i32) i32.const 9 call $h) (func (export \"keep\") (param i32) (result i32) local.get 0 call $echo))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    assert_eq(cmd_deep_audit_body(output, index=1), [
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    ])
    assert_eq(cmd_deep_audit_body(output, index=2), [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    ])
    assert_eq(
      @validate.Env::new()
      .with_module(output)
      .get_functype_by_funcidx(@lib.FuncIdx::new(1U)),
      Some(@lib.FuncType::new([], [@lib.ValType::i32()])),
    )
  }
}
