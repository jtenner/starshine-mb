///|
test "fourth audit command simplify-globals-optimizing imported mutable aliases" {
  let output = cmd_deep_audit_run(
    "(module (import \"m\" \"a\" (global $a (mut i32))) (import \"m\" \"b\" (global $b (mut i32))) (func (export \"f\") (result i32) i32.const 1 global.set $a i32.const 2 global.set $b global.get $a))",
    "simplify-globals-optimizing",
  )
  @debug.assert_eq(
    cmd_deep_audit_count(cmd_deep_audit_body(output), fn(i) {
      i is @lib.GlobalGet(_)
    }),
    1,
  )
}
