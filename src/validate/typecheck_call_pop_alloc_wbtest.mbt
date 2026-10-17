///|
#skip("single-call native allocation edge probe; behavior is checked first")
test "allocation direct call pop empty signature" {
  let params : Array[ValType] = []
  let results = [ValType::f64()]
  let input = [ValType::f32()]
  let env = call_pop_test_env(params, results)
  let state = make_state(env, input)
  let checked = typecheck_call(state, FuncIdx::new(0U)).unwrap()
  assert_true(physical_equal(checked, state))
  assert_eq(checked.stack, [ValType::f32(), ValType::f64()])
  assert_eq(input, [ValType::f32()])
  assert_eq(params, [])
  assert_eq(results, [ValType::f64()])
}

///|
#skip("single-call native allocation edge probe with typed operands")
test "allocation direct call pop mixed signature" {
  let params = [ValType::i32(), ValType::i64()]
  let results = [ValType::f64()]
  let input = [ValType::f32(), ValType::i32(), ValType::i64()]
  let state = make_state(call_pop_test_env(params, results), input)
  assert_true(
    physical_equal(typecheck_call(state, FuncIdx::new(0U)).unwrap(), state),
  )
  assert_eq(state.stack, [ValType::f32(), ValType::f64()])
  assert_eq(input, [ValType::f32(), ValType::i32(), ValType::i64()])
  assert_eq(params, [ValType::i32(), ValType::i64()])
  assert_eq(results, [ValType::f64()])
}
