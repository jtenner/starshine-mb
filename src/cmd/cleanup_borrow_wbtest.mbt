///|
test "command continuation cleanup retains the result while removing dead nested captures" {
  for pass in ["dae2-optimizing", "simplify-locals"] {
    let output = cmd_deep_audit_run(
      "(module (func (export \"run\") (param i32) (result i32) (local i32) block i32.const 7 local.set 1 local.get 1 drop end local.get 0))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    let body = cmd_deep_audit_body(output)
    assert_eq(
      body.last(),
      Some(@lib.Instruction::local_get(@lib.LocalIdx::new(0U))),
    )
    if pass == "dae2-optimizing" {
      assert_eq(body.length(), 1)
    } else {
      // The zero-parameter wrapper and replacement nops have no effect.
      // Removing them keeps the scalar evaluation and exported result order.
      @debug.assert_eq(body, [
        @lib.Instruction::i32_const(7),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      ])
    }
  }
}
