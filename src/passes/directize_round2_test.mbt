///|
test "round2 directize retains runtime subtype check for imported target" {
  let output = audit_run(
    (
      #|(module (type $base (sub (func (result i32))))
      #|(type $child (sub $base (func (result i32))))
      #|(import "m" "f" (func $f (type $base)))
      #|(table 1 funcref) (elem (i32.const 0) $f)
      #|(func (export "run") (result i32) i32.const 0 call_indirect (type $child)))
    ),
    "directize",
  )
  assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.CallIndirect(_, _) }),
    1,
  )
}

///|
test "round2 directize retains known trap folding for final imports" {
  let output = audit_run(
    "(module (type $a (func (param i32))) (type $b (func (param i64))) (import \"m\" \"f\" (func $f (type $a))) (table 1 funcref) (elem (i32.const 0) $f) (func (export \"main\") i64.const 0 i32.const 0 call_indirect (type $b)))",
    "directize",
  )
  assert_eq(audit_count(audit_body(output), fn(i) { i is @lib.CallIndirect(_) }), 0)
  assert_true(audit_count(audit_body(output), fn(i) { i is @lib.Unreachable }) > 0)
}
