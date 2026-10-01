///|
test "command root admission still cleans nested captures and preserves the exported result" {
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
      let @lib.Block(_, @lib.Expr(nested)) = body[0]
      assert_true(nested.contains(@lib.Instruction::i32_const(@lib.I32(7))))
      assert_false(
        nested.contains(@lib.Instruction::local_set(@lib.LocalIdx::new(1U))),
      )
      assert_false(
        nested.contains(@lib.Instruction::local_get(@lib.LocalIdx::new(1U))),
      )
    }
  }
}
