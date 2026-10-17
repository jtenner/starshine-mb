///|
fn heap2local_owner_update_fixture(second_fields : String) -> String {
  "(module (type $S (struct (field i32) (field i32))) " +
  "(func (export \"run\") (param $flag i32) (result i32 i32) " +
  "(local $x (ref null $S)) " +
  "(local.set $x (if (result (ref $S)) (local.get $flag) " +
  "(then (struct.new $S (i32.const 10) (i32.const 20))) " +
  "(else (struct.new $S (i32.const 11) (i32.const 21))))) " +
  "(local.set $x (if (result (ref $S)) (local.get $flag) " +
  "(then (struct.new $S " +
  second_fields +
  ")) " +
  "(else (struct.new $S " +
  second_fields +
  ")))) " +
  "(struct.get $S 0 (local.get $x)) " +
  "(struct.get $S 1 (local.get $x))))"
}

///|
test "heap2local owner update keeps old field for a later constructor operand" {
  let text = heap2local_owner_update_fixture(
    "(i32.const 100) (struct.get $S 0 (local.get $x))",
  )
  let input = pass_test_module_from_wat(text)
  let output = heap2local_run_module(input)
  assert_eq(fourth_audit_heap_eval(input, [0], field_count=2), [100, 11])
  assert_eq(fourth_audit_heap_eval(input, [1], field_count=2), [100, 10])
  assert_eq(fourth_audit_heap_eval(output, [0], field_count=2), [100, 11])
  assert_eq(fourth_audit_heap_eval(output, [1], field_count=2), [100, 10])
  assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.StructNew(_) }),
    0,
  )
  assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.StructGet(_, _) }),
    0,
  )
}

///|
test "heap2local owner update swaps old fields without using a new field" {
  let text = heap2local_owner_update_fixture(
    "(struct.get $S 1 (local.get $x)) (struct.get $S 0 (local.get $x))",
  )
  let input = pass_test_module_from_wat(text)
  let output = heap2local_run_module(input)
  assert_eq(fourth_audit_heap_eval(input, [0], field_count=2), [21, 11])
  assert_eq(fourth_audit_heap_eval(input, [1], field_count=2), [20, 10])
  assert_eq(fourth_audit_heap_eval(output, [0], field_count=2), [21, 11])
  assert_eq(fourth_audit_heap_eval(output, [1], field_count=2), [20, 10])
  assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.StructNew(_) }),
    0,
  )
}

///|
test "heap2local owner update preserves safe earlier old-field reads" {
  let text = heap2local_owner_update_fixture(
    "(struct.get $S 0 (local.get $x)) (i32.const 7)",
  )
  let input = pass_test_module_from_wat(text)
  let output = heap2local_run_module(input)
  assert_eq(fourth_audit_heap_eval(output, [0], field_count=2), [11, 7])
  assert_eq(fourth_audit_heap_eval(output, [1], field_count=2), [10, 7])
  assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.StructNew(_) }),
    0,
  )
}
