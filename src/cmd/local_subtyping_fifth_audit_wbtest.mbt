///|
test "fifth audit command select compound condition" {
  let output = cmd_deep_audit_run("(module (func (param eqref (ref null i31) (ref null i31)) (result eqref) (local eqref) local.get 0 local.set 3 local.get 0 local.get 1 local.get 2 ref.is_null select (result eqref)))", "local-subtyping")
  assert_true(@validate.validate_module(output).is_ok())
}

///|
test "fifth audit command null call result i32" {
  let output = cmd_deep_audit_run("(module (type $t (func (result i32))) (func (result i32) (local (ref null $t)) ref.null nofunc local.set 0 local.get 0 call_ref $t))", "local-subtyping")
  assert_true(@validate.validate_module(output).is_ok())
}

///|
test "fifth audit command null call result i64" {
  let output = cmd_deep_audit_run("(module (type $t (func (result i64))) (func (result i64) (local (ref null $t)) ref.null nofunc local.set 0 local.get 0 call_ref $t))", "local-subtyping")
  assert_true(@validate.validate_module(output).is_ok())
}

///|
test "fifth audit command null call result f32" {
  let output = cmd_deep_audit_run("(module (type $t (func (result f32))) (func (result f32) (local (ref null $t)) ref.null nofunc local.set 0 local.get 0 call_ref $t))", "local-subtyping")
  assert_true(@validate.validate_module(output).is_ok())
}

///|
test "fifth audit command null call result f64" {
  let output = cmd_deep_audit_run("(module (type $t (func (result f64))) (func (result f64) (local (ref null $t)) ref.null nofunc local.set 0 local.get 0 call_ref $t))", "local-subtyping")
  assert_true(@validate.validate_module(output).is_ok())
}

///|
test "fifth audit command null call result empty" {
  let output = cmd_deep_audit_run("(module (type $t (func )) (func  (local (ref null $t)) ref.null nofunc local.set 0 local.get 0 call_ref $t))", "local-subtyping")
  assert_true(@validate.validate_module(output).is_ok())
}

///|
test "fifth audit command null call result multi" {
  let output = cmd_deep_audit_run("(module (type $t (func (result i32 i64))) (func (result i32 i64) (local (ref null $t)) ref.null nofunc local.set 0 local.get 0 call_ref $t))", "local-subtyping")
  assert_true(@validate.validate_module(output).is_ok())
}

///|
test "fifth audit command null call result funcref" {
  let output = cmd_deep_audit_run("(module (type $t (func (result funcref))) (func (result funcref) (local (ref null $t)) ref.null nofunc local.set 0 local.get 0 call_ref $t))", "local-subtyping")
  assert_true(@validate.validate_module(output).is_ok())
}

