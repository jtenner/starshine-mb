///|
test "command DAE2 variants prune unused inputs while retaining leaf arithmetic" {
  for pass in ["dae2", "dae2-optimizing"] {
    let output = cmd_deep_audit_run(
      "(module (func $h (param i32) (result i32) i32.const 40 i32.const 2 i32.add) (func (export \"run\") (result i32) i32.const 9 call $h))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    assert_eq(cmd_deep_audit_body(output, index=1), [
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    ])
    let expected = [
      @lib.Instruction::i32_const(@lib.I32(40)),
      @lib.Instruction::i32_const(@lib.I32(2)),
      @lib.Instruction::i32_add(),
    ]
    assert_eq(cmd_deep_audit_body(output, index=0), expected)
  }
}
