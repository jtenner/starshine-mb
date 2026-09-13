///|
test "audit heap2local retains nullable allocation dominance trap" {
  let wat =
    #|(module (type $s (struct (field i32)))
    #|(func (param i32) (result i32) (local $r (ref null $s))
    #| local.get 0 if i32.const 7 struct.new $s local.set $r end
    #| local.get $r struct.get $s 0))
  let output = audit_run(wat, "heap2local")
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.StructGet(_, _) ||
      i is @lib.RefAsNonNull ||
      i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "audit heap2local preserves signed packed struct reads" {
  let wat =
    #|(module (type $s (struct (field (mut i8))))
    #|(func (result i32) (local $r (ref null $s))
    #| i32.const 255 struct.new $s local.set $r
    #| local.get $r struct.get_s $s 0))
  let output = audit_run(wat, "heap2local")
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.StructGetS(_, _) ||
      i is @lib.I32Extend8S ||
      i == @lib.Instruction::i32_const(@lib.I32::new(-1))
    }) >
    0,
    msg="expected packed sign extension: \{audit_body(output)}",
  )
}
