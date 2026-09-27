///|
test "command local-flow consumers retain one evaluation of a tuple producer" {
  for
    pass in [
      "coalesce-locals", "dae2", "precompute-propagate", "optimize-instructions",
    ] {
    let output = cmd_deep_audit_run(
      "(module (import \"env\" \"pair\" (func (result i32 i32))) (func (export \"run\") (result i32) (local i32) call 0 local.set 0 local.get 0 i32.add))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    let body = cmd_deep_audit_body(output)
    assert_eq(
      cmd_deep_audit_count(body, fn(instr) {
        instr is @lib.Call(@lib.FuncIdx(0U))
      }),
      1,
    )
    assert_eq(cmd_deep_audit_count(body, fn(instr) { instr is @lib.I32Add }), 1)
  }
}
