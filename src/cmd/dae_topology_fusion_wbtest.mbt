///|
test "command DAE variants retain tail topology while pruning forwarded arguments" {
  for pass in ["dae", "dae-optimizing"] {
    let output = cmd_deep_audit_run(
      "(module (func $target (param i32 i32) (result i32) local.get 1) (func $forward (param i32 i32) (result i32) local.get 0 local.get 1 return_call $target) (func (export \"run\") (param i32) (result i32) i32.const 7 local.get 0 call $forward))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    assert_eq(cmd_deep_audit_body(output, index=0), [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    ])
    assert_eq(cmd_deep_audit_body(output, index=1), [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::return_call(@lib.FuncIdx::new(0U)),
    ])
    assert_eq(cmd_deep_audit_body(output, index=2), [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    ])
  }
}
