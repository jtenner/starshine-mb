///|
test "command DAE2 variants preserve conditional reaching definitions" {
  for pass in ["dae2", "dae2-optimizing"] {
    let output = cmd_deep_audit_run(
      "(module (func $helper (param i32 i32 i32 i32) (result i32) local.get 0 if local.get 1 local.set 2 end local.get 2) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i32.const 9 call $helper))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    assert_eq(cmd_deep_audit_body(output, index=1), [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    ])
  }
}
