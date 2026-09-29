///|
test "typed operand consumption avoids result pairs and keeps polymorphic errors" {
  let env = empty_env()
  let state = make_state(env, [ValType::i32()])
  let pairs = [0]
  let result = state
    .pop_expect(ValType::i32(), operand_pairs=Some(pairs))
    .unwrap()
  assert_true(physical_equal(result, state))
  assert_eq(result.stack, [])
  assert_eq(pairs[0], 0)
  assert_eq(
    make_state(env, []).pop_expect(ValType::i32()).unwrap_err(),
    "stack underflow",
  )
  assert_true(
    make_state(env, [ValType::i64()]).pop_expect(ValType::i32()) is Err(_),
  )
  let dead = make_state(env, []).set_unreachable()
  assert_true(dead.pop_expect(ValType::i32()) is Ok(_))
  assert_eq(
    dead.push1(ValType::i64()).pop_expect(ValType::i32()).is_err(),
    true,
  )
}
