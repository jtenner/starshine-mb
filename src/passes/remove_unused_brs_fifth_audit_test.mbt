///|
test "fifth audit remove-unused-brs condition local write 1" {
  let output = audit_run(
    "(module (func (result i32) (local $x i32) (if (result i32) (local.tee $x (i32.const 1)) (then (return (local.get $x))) (else (i32.const 9)))))",
    "remove-unused-brs",
  )
  let body = audit_body(output)
  assert_eq(audit_count(body, fn(i) { i is @lib.Select(_) }), 0)
}

///|
test "fifth audit remove-unused-brs condition local write 7" {
  let output = audit_run(
    "(module (func (result i32) (local $x i32) (if (result i32) (local.tee $x (i32.const 7)) (then (return (local.get $x))) (else (i32.const 9)))))",
    "remove-unused-brs",
  )
  let body = audit_body(output)
  assert_eq(audit_count(body, fn(i) { i is @lib.Select(_) }), 0)
}

///|
test "fifth audit remove-unused-brs condition local write 42" {
  let output = audit_run(
    "(module (func (result i32) (local $x i32) (if (result i32) (local.tee $x (i32.const 42)) (then (return (local.get $x))) (else (i32.const 9)))))",
    "remove-unused-brs",
  )
  let body = audit_body(output)
  assert_eq(audit_count(body, fn(i) { i is @lib.Select(_) }), 0)
}
