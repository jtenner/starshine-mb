///|
test "command coalesce-locals reuses slots across a loop copy" {
  let output = cmd_deep_audit_run(
    "(module (func (export \"run\") (result i32) (local i32 i32) i32.const 7 local.set 0 loop local.get 0 local.set 1 end local.get 1))",
    "coalesce-locals",
  )
  assert_true(@validate.validate_module(output) is Ok(_))
  let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
  assert_true(locals.length() <= 1)
}
