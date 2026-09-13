///|
test "campaign ssa retains nonnullable merge definite initialization" {
  let output = audit_run(
    (
      #|(module (type $s (struct))
      #| (func (param $p (ref $s)) (param $c i32) (local $x (ref $s))
      #|  local.get $p local.set $x
      #|  local.get $c if
      #|   local.get $p local.set $x
      #|  else local.get $p local.set $x end
      #|  local.get $x drop))
    ),
    "ssa",
  )
  assert_true(@validate.validate_module(output) is Ok(_))
}
