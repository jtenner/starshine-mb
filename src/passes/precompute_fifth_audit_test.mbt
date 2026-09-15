///|
test "fifth audit precompute ref branch before br 1" {
  let output = audit_run("(module (global (export \"g\") (mut i32) (i32.const 0)) (func (param anyref) block block local.get 0 br_on_null 0 drop br 1 end i32.const 7 global.set 0 end))", "precompute")
  assert_true(@validate.validate_module(output).is_ok())
  assert_eq(audit_count(audit_body(output), fn(i) { i is @lib.GlobalSet(_) }), 1)
}

///|
test "fifth audit precompute ref branch before return" {
  let output = audit_run("(module (global (export \"g\") (mut i32) (i32.const 0)) (func (param anyref) block block local.get 0 br_on_null 0 drop return end i32.const 7 global.set 0 end))", "precompute")
  assert_true(@validate.validate_module(output).is_ok())
  assert_eq(audit_count(audit_body(output), fn(i) { i is @lib.GlobalSet(_) }), 1)
}

///|
test "fifth audit precompute-propagate ref branch before br 1" {
  let output = audit_run("(module (global (export \"g\") (mut i32) (i32.const 0)) (func (param anyref) block block local.get 0 br_on_null 0 drop br 1 end i32.const 7 global.set 0 end))", "precompute-propagate")
  assert_true(@validate.validate_module(output).is_ok())
  assert_eq(audit_count(audit_body(output), fn(i) { i is @lib.GlobalSet(_) }), 1)
}

///|
test "fifth audit precompute-propagate ref branch before return" {
  let output = audit_run("(module (global (export \"g\") (mut i32) (i32.const 0)) (func (param anyref) block block local.get 0 br_on_null 0 drop return end i32.const 7 global.set 0 end))", "precompute-propagate")
  assert_true(@validate.validate_module(output).is_ok())
  assert_eq(audit_count(audit_body(output), fn(i) { i is @lib.GlobalSet(_) }), 1)
}

