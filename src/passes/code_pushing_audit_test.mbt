///|
test "audit code pushing preserves writes observed after nested branch" {
  let wat =
    #|(module (func (result i32) (local i32)
    #| block
    #| i32.const 7 local.set 0
    #| (try (do nop) (catch_all))
    #| i32.const 1 br_if 0
    #| local.get 0 drop end
    #| local.get 0))
  let output = audit_run(wat, "code-pushing")
  match audit_body(output)[0] {
    @lib.Block(_, @lib.Expr(body)) => assert_true(body[1] is @lib.LocalSet(_))
    other => fail("expected block containing write, got \{other}")
  }
}
