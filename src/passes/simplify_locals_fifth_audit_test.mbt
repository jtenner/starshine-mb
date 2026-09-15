///|
test "fifth audit simplify locals preserves scoped nondefaultable initialization" {
  let output = audit_run(
    "(module (type $s (struct)) (func (param (ref $s)) (result (ref $s)) (local (ref $s)) block local.get 0 local.set 1 local.get 1 drop local.get 1 drop end local.get 0))",
    "simplify-locals",
  )
  assert_true(@validate.validate_module(output).is_ok())
}
