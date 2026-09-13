///|
test "audit once redundant nested tail call still returns" {
  let wat =
    #|(module (global $g (mut i32) (i32.const 0))
    #|(global $side (export "side") (mut i32) (i32.const 0))
    #|(func $once global.get $g if return end i32.const 1 global.set $g
    #| i32.const 7 global.set $side)
    #|(func (export "run") call $once block return_call $once end
    #| i32.const 9 global.set $side))
  let output = audit_run(wat, "once-reduction")
  assert_true(
    audit_count(audit_body(output, index=1), fn(i) {
      i is @lib.Return || i is @lib.ReturnCall(_)
    }) >
    0,
  )
}

///|
test "audit once records if label when merging block exits" {
  let wat =
    #|(module (global $g (mut i32) (i32.const 0))
    #|(global $side (export "side") (mut i32) (i32.const 0))
    #|(func $once global.get $g if return end i32.const 1 global.set $g
    #| i32.const 7 global.set $side)
    #|(func (export "run") (param i32)
    #| block $exit local.get 0 if br $exit end call $once end call $once))
  let output = audit_run(wat, "once-reduction")
  assert_true(
    audit_body(output, index=1).contains(
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    ),
  )
}

///|
test "audit once merges exception exits before call elimination" {
  let wat =
    #|(module (tag $e) (global $g (mut i32) (i32.const 0))
    #|(global $side (export "side") (mut i32) (i32.const 0))
    #|(func $once global.get $g if return end i32.const 1 global.set $g
    #| i32.const 7 global.set $side)
    #|(func (export "run") (param i32)
    #| block $exit try_table (catch_all $exit)
    #| local.get 0 if throw $e end call $once end end call $once))
  let output = audit_run(wat, "once-reduction")
  assert_true(
    audit_body(output, index=1).contains(
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    ),
  )
}

///|
test "audit once preserves inactive observable guard wrapper" {
  let wat =
    #|(module (global $g (mut i32) (i32.const 0))
    #|(global $side (export "side") (mut i32) (i32.const 0))
    #|(func $once global.get $g if return end i32.const 1 global.set $g
    #| i32.const 7 global.set $side)
    #|(global $other (mut i32) (i32.const 0))
    #|(func (export "set") global.get $other if return end i32.const 1 global.set $other)
    #|(func (export "get") (result i32) global.get $other))
  let output = audit_run(wat, "once-reduction")
  @debug.assert_eq(
    audit_count(audit_body(output, index=1), fn(i) { i is @lib.GlobalSet(_) }),
    1,
  )
}

///|
test "audit once preserves wrapper sharing an observable guard" {
  let wat =
    #|(module (global $g (mut i32) (i32.const 0))
    #|(global $side (export "side") (mut i32) (i32.const 0))
    #|(func $once global.get $g if return end i32.const 1 global.set $g
    #| i32.const 7 global.set $side)
    #|(func (export "set") global.get $g if return end i32.const 1 global.set $g))
  let output = audit_run(wat, "once-reduction")
  @debug.assert_eq(
    audit_count(audit_body(output, index=1), fn(i) { i is @lib.GlobalSet(_) }),
    1,
  )
}
