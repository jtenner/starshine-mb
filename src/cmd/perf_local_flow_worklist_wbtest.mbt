///|
test "command propagation retains a constant across a finite loop fixed point" {
  let output = cmd_deep_audit_run(
    "(module (func (export \"run\") (result i32) (local i32 i32) i32.const 7 local.set 0 i32.const 2 local.set 1 block loop local.get 1 i32.eqz br_if 1 i32.const 7 local.set 0 local.get 1 i32.const 1 i32.sub local.set 1 br 0 end end local.get 0))",
    "precompute-propagate",
  )
  @validate.validate_module(output).unwrap()
  let body = cmd_deep_audit_body(output)
  assert_true(body[body.length() - 1] is @lib.I32Const(@lib.I32(7)))
}
