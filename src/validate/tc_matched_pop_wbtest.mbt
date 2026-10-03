///|
test "paired typed pops preserve partial consumption on either operand failure" {
  // These deliberately invalid operand stacks must fail at the first mismatch.
  let left_bad = make_state(empty_env(), [ValType::i64(), ValType::i32()])
  assert_true(
    typecheck_binary(left_bad, ValType::i32(), ValType::i32()).is_err(),
  )
  assert_eq(left_bad.stack, [])
  let right_bad = make_state(empty_env(), [ValType::i32(), ValType::i64()])
  assert_true(
    typecheck_binary(right_bad, ValType::i32(), ValType::i32()).is_err(),
  )
  assert_eq(right_bad.stack, [ValType::i32()])
  let short = make_state(empty_env(), [ValType::i32()])
  assert_eq(
    typecheck_binary(short, ValType::i32(), ValType::i32()).unwrap_err(),
    "stack underflow",
  )
  assert_eq(short.stack, [])
}

///|
test "matched typed pops retain reference subtyping and disjoint rejection" {
  let state = make_state(empty_env(), [ValType::eqref_null()])
  let checked = state.pop_expect(ValType::anyref()).unwrap()
  assert_true(physical_equal(state, checked))
  assert_eq(checked.stack, [])
  // Function references are intentionally outside the anyref hierarchy.
  let invalid = make_state(empty_env(), [ValType::funcref()])
  assert_true(invalid.pop_expect(ValType::anyref()).is_err())
  assert_eq(invalid.stack, [])
}

///|
test "paired typed pops distinguish virtual bottom from concrete unreachable values" {
  let dead = make_state(empty_env(), []).set_unreachable()
  let checked = typecheck_binary(dead, ValType::i64(), ValType::i64()).unwrap()
  assert_true(physical_equal(dead, checked))
  assert_eq(checked.stack, [ValType::i64()])
  assert_true(!checked.reachable)
  assert_true(
    typecheck_binary(checked, ValType::i32(), ValType::i32()).is_err(),
  )
  assert_eq(checked.stack, [])
  let bottom = make_state(empty_env(), [ValType::bottom(), ValType::i32()])
  let next = typecheck_binary(bottom, ValType::i32(), ValType::i32()).unwrap()
  assert_eq(next.stack, [ValType::i32()])
}
