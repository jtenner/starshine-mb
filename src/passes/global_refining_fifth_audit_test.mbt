///|
test "fifth audit null write nop" {
  let output = audit_run("(module (type $S (struct)) (global $g (mut anyref) (struct.new_default $S)) (func (export \"f\") ref.null any nop global.set $g))", "global-refining")
  assert_true(@validate.validate_module(output).is_ok())
}

///|
test "fifth audit null write block" {
  let output = audit_run("(module (type $S (struct)) (global $g (mut anyref) (struct.new_default $S)) (func (export \"f\") block (result anyref) ref.null any end global.set $g))", "global-refining")
  assert_true(@validate.validate_module(output).is_ok())
}

///|
test "fifth audit null write double nop" {
  let output = audit_run("(module (type $S (struct)) (global $g (mut anyref) (struct.new_default $S)) (func (export \"f\") ref.null any nop nop global.set $g))", "global-refining")
  assert_true(@validate.validate_module(output).is_ok())
}

///|
test "fifth audit global null producer across dropped value" {
  let output = audit_run("(module (type $S (struct))  (global $g (mut anyref) (struct.new_default $S)) (func (export \"f\") ref.null any i32.const 0 drop global.set $g))", "global-refining")
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Global(@lib.GlobalType(type_, _), _) = output.global_sec.unwrap().0[0]
  @debug.assert_eq(type_, @lib.ValType::ref_null(@lib.HeapType::new(@lib.TypeIdx::new(0U))))
}

///|
test "fifth audit global null producer across void call" {
  let output = audit_run("(module (type $S (struct)) (import \"m\" \"effect\" (func)) (global $g (mut anyref) (struct.new_default $S)) (func (export \"f\") ref.null any call 0 global.set $g))", "global-refining")
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Global(@lib.GlobalType(type_, _), _) = output.global_sec.unwrap().0[0]
  @debug.assert_eq(type_, @lib.ValType::ref_null(@lib.HeapType::new(@lib.TypeIdx::new(0U))))
}

