///|
test "round2 code pushing preserves operand call with relaxed traps memory False" {
  let output = pass_test_run_pipeline(
    (
      #|(module  (import "m" "side" (func $side (result i32))) (func (param i32) (local i32) (local.set 1 (i32.div_s (call $side) (i32.const 1))) (if (local.get 0) (then (drop (local.get 1))))))
    ),
    ["code-pushing"],
    options=HotPipelineOptions::new(traps_never_happen=true),
  ).unwrap()
  assert_eq(audit_body(output).filter(fn(i) { i is @lib.Call(_) }).length(), 1)
}

///|
test "round2 code pushing preserves operand call with relaxed traps memory True" {
  let output = pass_test_run_pipeline(
    (
      #|(module (memory 1) (import "m" "side" (func $side (result i32))) (func (param i32) (local i32) (local.set 1 (i32.load (call $side))) (if (local.get 0) (then (drop (local.get 1))))))
    ),
    ["code-pushing"],
    options=HotPipelineOptions::new(ignore_implicit_traps=true),
  ).unwrap()
  assert_eq(audit_body(output).filter(fn(i) { i is @lib.Call(_) }).length(), 1)
}
