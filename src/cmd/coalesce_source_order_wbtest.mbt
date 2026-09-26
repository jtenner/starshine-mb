///|
test "command coalesce-locals keeps default local values separate from parameters" {
  let output = cmd_deep_audit_run(
    "(module (func (export \"run\") (param i32) (result i32) (local i32 i32) loop local.get 1 local.set 2 end local.get 2))",
    "coalesce-locals",
  )
  assert_true(@validate.validate_module(output) is Ok(_))
  let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 1)
  let body = cmd_deep_audit_body(output)
  assert_eq(
    body[body.length() - 1],
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  )
}
