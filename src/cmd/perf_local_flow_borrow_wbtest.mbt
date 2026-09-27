///|
test "command propagation keeps later branch writes out of an earlier borrowed state" {
  let output = cmd_deep_audit_run(
    "(module (func (export \"run\") (param i32) (result i32) (local i32 i32) i32.const 7 local.set 1 block local.get 1 local.set 2 end local.get 0 if i32.const 8 local.set 1 else i32.const 9 local.set 1 end local.get 2))",
    "precompute-propagate",
  )
  @validate.validate_module(output).unwrap()
  let body = cmd_deep_audit_body(output)
  assert_true(body[body.length() - 1] is @lib.I32Const(@lib.I32(7)))
}
