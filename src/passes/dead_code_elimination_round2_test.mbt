///|
test "round2 dce catch exit retains following trap" {
  let output = audit_run(
    (
      #|(module (tag $e) (global $side (export "side") (mut i32) (i32.const 0)) (func block $h try_table (catch_all $h) throw $e end end i32.const 7 global.set $side))
    ),
    "dead-code-elimination",
  )
  assert_true(@validate.validate_module(output).is_ok())
  assert_eq(
    audit_count(audit_body(output, index=0), fn(i) { i is @lib.GlobalSet(_) }),
    1,
  )
}
