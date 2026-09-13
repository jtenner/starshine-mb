///|
test "audit vacuum preserves legacy branch owner" {
  let wat =
    #|(module (func (result i32)
    #| block (result i32)
    #| (try (do i32.const 7 br 1) (catch_all))
    #| i32.const 9 end drop i32.const 42))
  let output = audit_run(wat, "vacuum")
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.Block(_, _) }),
    1,
  )
}
