///|
test "fourth audit command vacuum discards branch stack debris in value function" {
  let output = cmd_deep_audit_run(
    "(module (func (export \"f\") (result i32) (local i32) (block i32.const 1 local.set 0 i32.const 42 br 0) i32.const 99))",
    "vacuum",
  )
  assert_true(@validate.validate_module(output) is Ok(_))
}
