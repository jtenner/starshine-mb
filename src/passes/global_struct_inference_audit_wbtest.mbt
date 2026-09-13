///|
test "audit global struct singleton facts include mutable global allocations" {
  let facts = gsi_test_closed_world_facts(
    "(module (type $s (struct (field i32))) (global (ref $s) (struct.new $s (i32.const 1))) (global (mut (ref $s)) (struct.new $s (i32.const 2))))",
  )
  assert_true(
    gsi_test_closed_world_type_is_poisoned(facts, @lib.TypeIdx::new(0U)),
  )
}
