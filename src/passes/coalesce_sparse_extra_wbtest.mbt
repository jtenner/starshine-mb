///|
test "coalesce plain interference queries visit live members rather than all local slots" {
  let (actions, liveness, _) = cl_structured_live_fixture(128, 3)
  let expected = CLBitMatrix::new(128)
  let actual = CLBitMatrix::new(128)
  cl_add_plain_live_interferences_reference(actions, liveness, expected)
  let visits = [0]
  cl_add_plain_live_interferences(
    actions,
    liveness,
    actual,
    candidate_visits=Some(visits),
  )
  assert_eq(actual.bits, expected.bits)
  assert_true(visits[0] <= actions.length() * 4)
}

///|
test "coalesce structured write hazards visit only recorded symmetric pairs" {
  let hazards = CLBitMatrix::new(128)
  cl_bit_matrix_set(hazards, 0, 3, true)
  cl_bit_matrix_set(hazards, 2, 127, true)
  cl_bit_matrix_set(hazards, 7, 63, true)
  let types = Array::make(128, @lib.ValType::i32())
  types[63] = @lib.ValType::i64()
  let actual = CLBitMatrix::new(128)
  let expected = CLBitMatrix::new(128)
  cl_add_structured_write_live_interferences_reference(
    hazards, types, 2, expected,
  )
  let visits = [0]
  cl_add_structured_write_live_interferences(
    hazards,
    types,
    2,
    actual,
    candidate_visits=Some(visits),
  )
  assert_eq(actual.bits, expected.bits)
  assert_true(cl_bit_matrix_get(actual, 0, 3))
  assert_true(cl_bit_matrix_get(actual, 2, 127))
  assert_false(cl_bit_matrix_get(actual, 7, 63))
  assert_true(visits[0] <= 3)
}
