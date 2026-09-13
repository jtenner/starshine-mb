///|
test "round2 code folding preserves reachable trap after block exit" {
  let output = audit_run(
    (
      #|(module (func (param i32) block $b local.get 0 br_if $b return end unreachable))
    ),
    "code-folding",
  )
  assert_eq(
    audit_count(audit_body(output, index=0), fn(i) { i is @lib.Unreachable }),
    1,
  )
}

///|
test "round2 code folding keeps effects after unreachable dead" {
  let output = audit_run(
    (
      #|(module (import "m" "side" (func $side)) (func block unreachable call $side end))
    ),
    "code-folding",
  )
  let body = audit_body(output)
  let mut reached_trap = false
  for i in body {
    if i is @lib.Unreachable {
      reached_trap = true
    }
    if i is @lib.Call(_) {
      assert_true(reached_trap)
    }
  }
}
