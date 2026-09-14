///|
test "deep audit vacuum discards excess stack values at a terminal owner branch" {
  let output = audit_run(
    "(module (func (local i32) (block i32.const 1 local.set 0 i32.const 42 br 0)))",
    "vacuum",
  )
  assert_true(@validate.validate_module(output) is Ok(_))
}
