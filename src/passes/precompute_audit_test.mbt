///|
test "audit precompute preserves valid typed loop entry operands" {
  let wat =
    #|(module (func (result i32) (local i32 i32)
    #| i32.const 7 loop (param i32) (result i32)
    #| i32.const 0 local.set 0 local.tee 1 nop end))
  let output = audit_run(wat, "precompute")
  ignore(@validate.validate_module(output).unwrap())
}

///|
test "audit precompute propagate retains receiver tee effects" {
  let wat =
    #|(module
    #| (type $s (struct (field i32)))
    #| (global $g (ref $s) (struct.new $s (i32.const 7)))
    #| (func (result i32) (local $r (ref null $s))
    #| global.get $g local.tee $r struct.get $s 0 drop
    #| local.get $r ref.is_null))
  let output = audit_run(wat, "precompute-propagate")
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.LocalTee(_) || i is @lib.LocalSet(_)
    }) >
    0,
  )
}

///|
test "audit precompute condition facts respect loop backedges" {
  let wat =
    #|(module (func (param i32) (result i32) (local $x i32) (local $sum i32)
    #| i32.const 1 local.tee $x if (result i32)
    #|  loop
    #|   local.get $sum local.get $x i32.add local.set $sum
    #|   local.get $x i32.const 1 i32.add local.tee $x
    #|   local.get 0 i32.lt_s br_if 0
    #|  end local.get $sum
    #| else i32.const 0 end))
  let output = audit_run(wat, "precompute-propagate")
  @debug.assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], [4L]), [6L])
}
