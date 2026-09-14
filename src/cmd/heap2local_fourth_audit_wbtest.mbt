///|
test "fourth audit command heap2local rewrites reads in next initializer" {
  let output = cmd_deep_audit_run(
    "(module (type $S (struct (field i32))) (func (result i32) (local $s (ref null $S)) (local.set $s (struct.new $S (i32.const 7))) (drop (struct.get $S 0 (local.get $s))) (local.set $s (struct.new $S (struct.get $S 0 (local.get $s)))) (struct.get $S 0 (local.get $s))))",
    "heap2local",
  )
  @debug.assert_eq(
    cmd_deep_audit_count(cmd_deep_audit_body(output), fn(i) {
      i is @lib.StructGet(_, _)
    }),
    0,
  )
}
