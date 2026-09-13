///|
test "round2 local cse distinct signed zero" {
  let output = audit_run(
    (
      #|(module (func (result i32) (drop (i32.reinterpret_f32 (f32.const 0))) (i32.reinterpret_f32 (f32.const -0))))
    ),
    "local-cse",
  )
  assert_eq(try! scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    -2147483648L,
  ])
}

///|
test "round2 local cse nested local writes" {
  let output = audit_run(
    (
      #|(module (func (param i32) (result i32) (drop (i32.add (local.get 0) (i32.const 1))) (block (result i32) (block (local.set 0 (i32.const 10))) (i32.add (local.get 0) (i32.const 1)))))
    ),
    "local-cse",
  )
  assert_eq(try! scalar_fixture_run(output.code_sec.unwrap().0[0], [2L]), [11L])
}

///|
test "round2 local cse nested bulk writes" {
  let output = audit_run(
    (
      #|(module (memory 1) (func (result i32) (drop (i32.load (i32.const 0))) (block (result i32) (memory.fill (i32.const 0) (i32.const 1) (i32.const 4)) (i32.load (i32.const 0)))))
    ),
    "local-cse",
  )
  assert_eq(
    audit_count(audit_body(output, index=0), fn(i) { i is @lib.I32Load(_) }),
    2,
  )
}
