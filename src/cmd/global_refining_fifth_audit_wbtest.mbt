///|
test "fifth audit command null write nop" {
  let output = cmd_deep_audit_run(
    "(module (type $S (struct)) (global $g (mut anyref) (struct.new_default $S)) (func (export \"f\") ref.null any nop global.set $g))",
    "global-refining",
  )
  assert_true(@validate.validate_module(output).is_ok())
}

///|
test "fifth audit command null write block" {
  let output = cmd_deep_audit_run(
    "(module (type $S (struct)) (global $g (mut anyref) (struct.new_default $S)) (func (export \"f\") block (result anyref) ref.null any end global.set $g))",
    "global-refining",
  )
  assert_true(@validate.validate_module(output).is_ok())
}

///|
test "fifth audit command null write double nop" {
  let output = cmd_deep_audit_run(
    "(module (type $S (struct)) (global $g (mut anyref) (struct.new_default $S)) (func (export \"f\") ref.null any nop nop global.set $g))",
    "global-refining",
  )
  assert_true(@validate.validate_module(output).is_ok())
}
