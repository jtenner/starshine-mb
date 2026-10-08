///|
test "command precompute-propagate preserves shared branch payload" {
  let output = cmd_deep_audit_run(
    "(module (func (param i32) (result i32) (block $B (result i32) (drop (br_if $B (block (result i32) (i32.const 0)) (local.get 0))) (i32.const 1))))",
    "precompute-propagate",
  )
  @validate.validate_module(decode_module_bytes(encode_module_bytes(output))).unwrap()
  assert_eq(
    cmd_deep_audit_count(cmd_deep_audit_body(output), fn(instr) {
      instr is @lib.BrIf(_)
    }),
    1,
  )
}
