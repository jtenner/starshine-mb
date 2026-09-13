///|
test "round2 untee preserves unreachable nondefaultable initialization" {
  let output = audit_run(
    (
      #|(module (func (local (ref func)) unreachable local.tee 0 drop local.get 0 drop))
    ),
    "untee",
  )
  assert_true(@validate.validate_module(output).is_ok())
}
