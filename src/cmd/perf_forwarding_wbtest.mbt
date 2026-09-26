///|
test "command DAE variants prune a forwarded unused argument" {
  for pass in ["dae", "dae-optimizing"] {
    let output = cmd_deep_audit_run(
      "(module (func $sink (param i32) (result i32) i32.const 7) (func $forward (param i32) (result i32) local.get 0 call $sink) (func (export \"run\") (param i32) (result i32) local.get 0 call $forward))",
      pass,
    )
    assert_true(@validate.validate_module(output) is Ok(_))
    assert_eq(cmd_deep_audit_body(output, index=2), [
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    ])
  }
}
