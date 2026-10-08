///|
test "command precompute removes a typed identity block and retains its input" {
  for pass in ["precompute", "precompute-propagate"] {
    let output = cmd_deep_audit_run(
      "(module (type $t (func (param i32) (result i32))) (func (export \"f\") (param i32) (result i32) i32.const 1 local.get 0 block (type $t) end i32.add))",
      pass,
    )
    @validate.validate_module(decode_module_bytes(encode_module_bytes(output))).unwrap()
    let body = cmd_deep_audit_body(output)
    assert_eq(
      cmd_deep_audit_count(body, fn(instr) {
        instr is @lib.LocalGet(@lib.LocalIdx(0U))
      }),
      1,
    )
    assert_eq(cmd_deep_audit_count(body, fn(instr) { instr is @lib.I32Add }), 1)
    assert_eq(
      cmd_deep_audit_count(body, fn(instr) { instr is @lib.Block(_, _) }),
      0,
    )
  }
}
