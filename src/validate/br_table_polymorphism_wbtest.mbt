///|
test "br_table accepts a polymorphic operand for distinct numeric label types" {
  let env = empty_env().with_labels([[ValType::f32()], [ValType::f64()]])
  let state = make_state(env, []).set_unreachable()
  state.stack.push(ValType::i32())
  let checked = match
    typecheck_br_table(
      state,
      [LabelIdx::new(0U), LabelIdx::new(1U)],
      LabelIdx::new(1U),
    ) {
    Ok(checked) => checked
    Err(error) => fail("polymorphic numeric br_table rejected: \{error}")
  }
  assert_eq(checked.stack, [])
  assert_false(checked.reachable)
  assert_true(checked.polymorphic)
}

///|
test "br_table accepts an explicit bottom operand for distinct numeric labels" {
  let env = empty_env().with_labels([[ValType::f32()], [ValType::f64()]])
  let state = make_state(env, [ValType::bottom(), ValType::i32()])
  let checked = match
    typecheck_br_table(state, [LabelIdx::new(0U)], LabelIdx::new(1U)) {
    Ok(checked) => checked
    Err(error) => fail("explicit-bottom br_table rejected: \{error}")
  }
  assert_eq(checked.stack, [])
  assert_false(checked.reachable)
}

///|
test "br_table accepts reference operands matching every target label" {
  let env = empty_env().with_labels([
    [ValType::eqref_null()],
    [ValType::anyref()],
  ])
  let state = make_state(env, [ValType::i31ref(), ValType::i32()])
  let checked = match
    typecheck_br_table(state, [LabelIdx::new(0U)], LabelIdx::new(1U)) {
    Ok(checked) => checked
    Err(error) => fail("common reference-subtype br_table rejected: \{error}")
  }
  assert_eq(checked.stack, [])
  assert_false(checked.reachable)
}

///|
test "br_table rejects distinct label arities even with polymorphic operands" {
  let env = empty_env().with_labels([[ValType::f32()], []])
  let state = make_state(env, []).set_unreachable()
  state.stack.push(ValType::i32())
  assert_true(
    typecheck_br_table(state, [LabelIdx::new(0U)], LabelIdx::new(1U)).is_err(),
  )
}

///|
test "br_table checks concrete operands against every target after unreachable" {
  let env = empty_env().with_labels([[ValType::f32()], [ValType::f64()]])
  for concrete in [ValType::f32(), ValType::f64()] {
    let state = make_state(env, []).set_unreachable()
    state.stack.push(concrete)
    state.stack.push(ValType::i32())
    assert_true(
      typecheck_br_table(state, [LabelIdx::new(0U)], LabelIdx::new(1U)).is_err(),
    )
  }
}

///|
test "br_table rejects reference operands that only match the default target" {
  let env = empty_env().with_labels([
    [ValType::eqref_null()],
    [ValType::anyref()],
  ])
  let state = make_state(env, [ValType::anyref(), ValType::i32()])
  assert_true(
    typecheck_br_table(state, [LabelIdx::new(0U)], LabelIdx::new(1U)).is_err(),
  )
}
