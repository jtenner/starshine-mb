///|
test "fourth audit structurally equivalent imported reference globals alias" {
  let output = audit_run(
    "(module (type $t0 (func)) (type $t1 (func)) (import \"m\" \"a\" (global $a (mut (ref null $t0)))) (import \"m\" \"b\" (global $b (mut (ref null $t1)))) (func $f (type $t1)) (elem declare func $f) (func (export \"test\") (result i32) ref.null $t0 global.set $a ref.func $f global.set $b global.get $a ref.is_null))",
    "simplify-globals-optimizing",
  )
  @debug.assert_eq(
    audit_count(audit_body(output, index=1), fn(i) { i is @lib.GlobalGet(_) }),
    1,
  )
}
