///|
test "audit coalesce preserves exception catch owner" {
  let wat =
    #|(module (tag $e) (global (export "g") (mut i32) (i32.const 0))
    #| (func (local i32 i32)
    #| block $exit try_table (catch_all $exit) throw $e end end
    #| i32.const 7 global.set 0))
  let output = audit_run(wat, "coalesce-locals")
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.Block(_, _) }),
    1,
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.GlobalSet(_) }),
    1,
  )
}
