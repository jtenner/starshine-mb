///|
test "round2 remove unused brs retains loop prefix effects" {
  let output = audit_run(
    (
      #|(module (import "m" "tick" (func $tick)) (import "m" "work" (func $work)) (func (param i32) loop $L block $B call $tick local.get 0 br_if $B call $work br $L end end))
    ),
    "remove-unused-brs",
  )
  assert_eq(
    audit_count(audit_body(output, index=0), fn(i) {
      i is @lib.Call(@lib.FuncIdx(0U))
    }),
    1,
  )
}

///|
test "round2 remove unused brs preserves farther exit destination" {
  let output = audit_run(
    (
      #|(module (import "m" "side" (func $side)) (func (param i32) block $OUT block $B loop $L local.get 0 br_if $OUT br $L end end call $side end))
    ),
    "remove-unused-brs",
  )
  let mut calls = 0
  ignore(
    try! scalar_fixture_run(
      output.code_sec.unwrap().0[0],
      [1L],
      call_params=[0],
      call=Some(fn(_, _) {
        calls += 1
        []
      }),
    ),
  )
  assert_eq(calls, 0)
}

///|
test "round2 remove unused brs retains prefix before inert suffix" {
  let output = audit_run(
    "(module (global $side (export \"side\") (mut i32) (i32.const 0)) (func (param i32) (loop $L (block $B (global.set $side (i32.const 7)) (br_if $B (local.get 0)) (drop (i32.const 9)) (br $L)))))",
    "remove-unused-brs",
  )
  assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.GlobalSet(_) }),
    1,
  )
}
