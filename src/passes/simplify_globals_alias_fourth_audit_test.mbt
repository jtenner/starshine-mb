///|
test "fourth audit simplify-globals-optimizing imported mutable aliases" {
  let output = audit_run(
    "(module (import \"m\" \"a\" (global $a (mut i32))) (import \"m\" \"b\" (global $b (mut i32))) (func (export \"f\") (result i32) i32.const 1 global.set $a i32.const 2 global.set $b global.get $a))",
    "simplify-globals-optimizing",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.GlobalGet(_) }),
    1,
  )
}

///|
test "fourth audit imported mutable i64 aliases" {
  let output = audit_run(
    "(module (import \"m\" \"a\" (global $a (mut i64))) (import \"m\" \"b\" (global $b (mut i64))) (func (export \"f\") (result i64) i64.const 1 global.set $a i64.const 2 global.set $b global.get $a))",
    "simplify-globals-optimizing",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.GlobalGet(_) }),
    1,
  )
}

///|
test "fourth audit imported mutable f32 aliases" {
  let output = audit_run(
    "(module (import \"m\" \"a\" (global $a (mut f32))) (import \"m\" \"b\" (global $b (mut f32))) (func (export \"f\") (result f32) f32.const 1 global.set $a f32.const 2 global.set $b global.get $a))",
    "simplify-globals-optimizing",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.GlobalGet(_) }),
    1,
  )
}

///|
test "fourth audit imported mutable f64 aliases" {
  let output = audit_run(
    "(module (import \"m\" \"a\" (global $a (mut f64))) (import \"m\" \"b\" (global $b (mut f64))) (func (export \"f\") (result f64) f64.const 1 global.set $a f64.const 2 global.set $b global.get $a))",
    "simplify-globals-optimizing",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.GlobalGet(_) }),
    1,
  )
}
