///|
test "typed select retains owned state input snapshots and control facts" {
  for
    ty in [
      ValType::i32(),
      ValType::i64(),
      ValType::f32(),
      ValType::f64(),
      ValType::i31ref(),
    ] {
    let env = empty_env()
    let input = [ty, ty, ValType::i32()]
    let state = make_state(env, input)
    state.initialized_locals.push(true)
    state.initialized_locals.push(false)
    state.reachable_escape_depths.push(3)
    let sibling = TcState::{ ..state, }
    let out = typecheck_select_typed(state, [ty]).unwrap()
    assert_true(physical_equal(out, state))
    assert_true(physical_equal(out.env, env))
    assert_true(
      physical_equal(out.initialized_locals, sibling.initialized_locals),
    )
    assert_eq(out.stack, [ty])
    assert_eq(out.initialized_locals, [true, false])
    assert_eq(out.reachable_escape_depths, [3])
    assert_true(out.reachable)
    assert_eq(out.escape, NoTcEscape)
    assert_eq(input, [ty, ty, ValType::i32()])
  }
}

///|
test "typed select preserves condition right operand then left operand failure order" {
  for reachable in [false, true] {
    for invalid in 0..<3 {
      let values = [ValType::i32(), ValType::i32(), ValType::i32()]
      values[2 - invalid] = ValType::f64()
      let state = tc_state_new(
        empty_env(),
        values,
        reachable,
        if reachable {
          NoTcEscape
        } else {
          TerminalTcEscape
        },
      )
      assert_eq(
        typecheck_select_typed(state, [ValType::i32()]).unwrap_err(),
        "type mismatch: expected=I32 actual=F64",
      )
      assert_eq(state.stack, Array::make(2 - invalid, ValType::i32()))
      assert_eq(state.reachable, reachable)
      assert_eq(
        state.escape,
        if reachable {
          NoTcEscape
        } else {
          TerminalTcEscape
        },
      )
    }
  }
  for available in 0..<3 {
    let state = make_state(empty_env(), Array::make(available, ValType::i32()))
    assert_eq(
      typecheck_select_typed(state, [ValType::i32()]).unwrap_err(),
      "stack underflow",
    )
    assert_eq(state.stack, [])
  }
}

///|
test "typed select retains virtual bottom and reference subtyping" {
  let bottom = tc_state_new(empty_env(), [], false, TerminalTcEscape)
  assert_true(
    physical_equal(
      typecheck_select_typed(bottom, [ValType::i64()]).unwrap(),
      bottom,
    ),
  )
  assert_eq(bottom.stack, [ValType::i64()])
  assert_false(bottom.reachable)
  let concrete_bottom = make_state(empty_env(), [
    ValType::bottom(),
    ValType::bottom(),
    ValType::i32(),
  ])
  assert_true(typecheck_select_typed(concrete_bottom, [ValType::f32()]).is_ok())
  assert_eq(concrete_bottom.stack, [ValType::f32()])
  let refs = make_state(empty_env(), [
    ValType::eqref_null(),
    ValType::eqref_null(),
    ValType::i32(),
  ])
  assert_true(typecheck_select_typed(refs, [ValType::anyref()]).is_ok())
  assert_eq(refs.stack, [ValType::anyref()])
}

///|
test "typed select intentionally rejects invalid type annotations before popping" {
  let bad = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(999U))),
  )
  let types = [bad]
  let state = make_state(empty_env(), [ValType::f64()])
  let annotation = Validate::validate(types, state.env).unwrap_err()
  assert_eq(
    typecheck_select_typed(state, types).unwrap_err(),
    "invalid select type annotation: " + annotation,
  )
  assert_eq(state.stack, [ValType::f64()])
}
