///|
test "round2 coalesce locals preserves value live on br on null exit" {
  let output = audit_run(
    (
      #|(module (func (export "f") (param externref) (result i32) (local i32)
      #|i32.const 7 local.set 1 block local.get 0 br_on_null 0 drop
      #|i32.const 9 local.set 1 end local.get 1))
    ),
    "coalesce-locals",
  )
  assert_eq(
    audit_count(audit_body(output), fn(i) {
      i is @lib.LocalSet(_) || i is @lib.LocalTee(_)
    }),
    2,
  )
}

///|
test "round2 coalesce caught exception keeps live local" {
  let output = audit_run(
    (
      #|(module (tag $e) (func (result i32) (local i32) i32.const 7 local.set 0 block $exit try_table (catch_all $exit) throw $e end end local.get 0))
    ),
    "coalesce-locals",
  )
  assert_eq(
    audit_count(audit_body(output, index=0), fn(i) {
      i is @lib.LocalSet(_) || i is @lib.LocalTee(_)
    }),
    1,
  )
}

///|
test "round2 coalesce dead local accesses do not shift tee liveness" {
  let output = audit_run(
    (
      #|(module (func (param i32) (result i32) (local i32 i32) local.get 0 if unreachable local.get 1 drop end block i32.const 7 local.tee 1 drop end i32.const 8 local.set 2 local.get 1))
    ),
    "coalesce-locals",
  )
  assert_eq(try! scalar_fixture_run(output.code_sec.unwrap().0[0], [0L]), [7L])
}
