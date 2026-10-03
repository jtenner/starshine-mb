///|
test "reverse type pops preserve mixed signature order and empty identity" {
  for method in [false, true] {
    let state = make_state(empty_env(), [
      ValType::f64(),
      ValType::i32(),
      ValType::i64(),
      ValType::eqref_null(),
    ])
    let signature = [ValType::i32(), ValType::i64(), ValType::anyref()]
    let result = if method {
      state.pop_types(signature)
    } else {
      pop_types_rev(state, signature)
    }
    assert_true(physical_equal(result.unwrap(), state))
    assert_eq(state.stack, [ValType::f64()])
    let empty = if method {
      state.pop_types([])
    } else {
      pop_types_rev(state, [])
    }
    assert_true(physical_equal(empty.unwrap(), state))
    assert_eq(state.stack, [ValType::f64()])
    assert_eq(signature, [ValType::i32(), ValType::i64(), ValType::anyref()])
  }
}

///|
test "reverse type pops stop at the first invalid operand or underflow" {
  for method in [false, true] {
    // Deliberately invalid stacks must retain the lower, unvisited operand.
    let state = make_state(empty_env(), [
      ValType::f64(),
      ValType::f32(),
      ValType::i64(),
    ])
    let signature = [ValType::i32(), ValType::i64()]
    let result = if method {
      state.pop_types(signature)
    } else {
      pop_types_rev(state, signature)
    }
    assert_true(result.is_err())
    assert_eq(state.stack, [ValType::f64()])
    let short = make_state(empty_env(), [ValType::i64()])
    let result = if method {
      short.pop_types(signature)
    } else {
      pop_types_rev(short, signature)
    }
    assert_eq(result.unwrap_err(), "stack underflow")
    assert_eq(short.stack, [])
  }
}

///|
test "reverse type pops distinguish virtual bottom from concrete unreachable types" {
  for method in [false, true] {
    let state = make_state(empty_env(), []).set_unreachable()
    let signature = [ValType::i32(), ValType::i64(), ValType::anyref()]
    let result = if method {
      state.pop_types(signature)
    } else {
      pop_types_rev(state, signature)
    }
    assert_true(physical_equal(result.unwrap(), state))
    assert_eq(state.stack, [])
    state.stack.push(ValType::funcref())
    // Concrete function references remain invalid in the anyref hierarchy.
    let result = if method {
      state.pop_types(signature)
    } else {
      pop_types_rev(state, signature)
    }
    assert_true(result.is_err())
    assert_eq(state.stack, [])
    assert_false(state.reachable)
  }
}
