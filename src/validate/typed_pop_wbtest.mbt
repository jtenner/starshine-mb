///|
test "typed consumers retain state identity and control metadata" {
  for kind in 0..<4 {
    let env = empty_env()
    let input = [ValType::f64(), ValType::i32(), ValType::i32()]
    let state = make_state(env, input)
    state.reachable_escape_depths.push(2)
    state.initialized_locals.push(true)
    state.initialized_locals.push(false)
    let result = match kind {
      0 => state.pop_types([ValType::i32(), ValType::i32()])
      1 => pop_types_rev(state, [ValType::i32(), ValType::i32()])
      2 => typecheck_binary(state, ValType::i32(), ValType::i64())
      _ => typecheck_unary(state, ValType::i32(), ValType::i64())
    }
    assert_true(physical_equal(result.unwrap(), state))
    assert_true(physical_equal(state.env, env))
    assert_eq(state.reachable_escape_depths, [2])
    assert_eq(state.initialized_locals, [true, false])
    assert_true(state.reachable)
    assert_eq(state.escape, NoTcEscape)
    assert_eq(
      state.stack,
      match kind {
        0 | 1 => [ValType::f64()]
        2 => [ValType::f64(), ValType::i64()]
        _ => [ValType::f64(), ValType::i32(), ValType::i64()]
      },
    )
    assert_eq(input, [ValType::f64(), ValType::i32(), ValType::i32()])
  }
}

///|
test "typed consumers stop at the same first invalid operand" {
  for kind in 0..<3 {
    let state = make_state(empty_env(), [
      ValType::f64(),
      ValType::f32(),
      ValType::i32(),
    ])
    let result = match kind {
      0 => state.pop_types([ValType::i32(), ValType::i32()])
      1 => pop_types_rev(state, [ValType::i32(), ValType::i32()])
      _ => typecheck_binary(state, ValType::i32(), ValType::i64())
    }
    // Invalid concrete operands remain invalid after the first successful pop.
    assert_eq(result.unwrap_err(), "type mismatch: expected=I32 actual=F32")
    assert_eq(state.stack, [ValType::f64()])
    let short = make_state(empty_env(), [ValType::i32()])
    assert_eq(
      typecheck_binary(short, ValType::i32(), ValType::i64()).unwrap_err(),
      "stack underflow",
    )
    assert_eq(short.stack, [])
  }
}

///|
test "typed consumers distinguish polymorphic bottom and concrete GC operands" {
  let state = make_state(empty_env(), []).set_unreachable()
  assert_true(
    physical_equal(
      typecheck_binary(state, ValType::i32(), ValType::i64()).unwrap(),
      state,
    ),
  )
  assert_eq(state.stack, [ValType::i64()])
  // Unreachable code still rejects the concrete i64 as an i32 operand.
  assert_eq(
    typecheck_unary(state, ValType::i32(), ValType::i64()).unwrap_err(),
    "type mismatch: expected=I32 actual=I64",
  )
  assert_false(state.reachable)
  assert_eq(state.escape, TerminalTcEscape)
  state.stack.push(ValType::bottom())
  assert_true(typecheck_unary(state, ValType::i32(), ValType::i64()).is_ok())
  let refs = make_state(empty_env(), [ValType::eqref_null()])
  assert_true(
    physical_equal(
      typecheck_unary(refs, ValType::anyref(), ValType::i32()).unwrap(),
      refs,
    ),
  )
  assert_eq(refs.stack, [ValType::i32()])
}
