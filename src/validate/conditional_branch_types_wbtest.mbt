///|
test "br_if fallthrough adopts label types and preserves the deeper stack" {
  let nonnull = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::func())),
  )
  let env = empty_env().with_label([ValType::funcref()])
  let state = make_state(env, [ValType::i64(), nonnull, ValType::i32()])
  let out = typecheck_br_if(state, LabelIdx::new(0U)).unwrap()
  assert_eq(out.stack, [ValType::i64(), ValType::funcref()])
}

///|
test "br_if materializes polymorphic label operands on fallthrough" {
  let env = empty_env().with_label([ValType::i32()])
  let state = tc_state_new(env, [ValType::i32()], false, TerminalTcEscape)
  let out = typecheck_br_if(state, LabelIdx::new(0U)).unwrap()
  assert_eq(out.stack, [ValType::i32()])
  assert_true(tc_state_validate_end_stack(out, []).is_err())
}

///|
test "br_on_null accepts bottom and materializes its label prefix" {
  let env = empty_env().with_label([ValType::i32()])
  let state = tc_state_new(env, [], false, TerminalTcEscape)
  let out = match typecheck_br_on_null(state, LabelIdx::new(0U)) {
    Ok(out) => out
    Err(error) => fail(error)
  }
  assert_eq(out.stack, [ValType::i32(), ValType::bottom()])
}

///|
test "br_on_null adopts label prefix types and retains nonnull refinement" {
  let nonnull = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::func())),
  )
  let env = empty_env().with_label([ValType::funcref()])
  let state = make_state(env, [ValType::i64(), nonnull, ValType::funcref()])
  let out = typecheck_br_on_null(state, LabelIdx::new(0U)).unwrap()
  assert_eq(out.stack, [ValType::i64(), ValType::funcref(), nonnull])
}

///|
test "br_on_non_null fallthrough adopts concrete and polymorphic label prefixes" {
  let nonnull = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::func())),
  )
  for polymorphic in [false, true] {
    let env = empty_env().with_label([ValType::funcref(), ValType::funcref()])
    let state = if polymorphic {
      tc_state_new(env, [], false, TerminalTcEscape)
    } else {
      make_state(env, [nonnull, ValType::funcref()])
    }
    let out = typecheck_br_on_non_null(state, LabelIdx::new(0U)).unwrap()
    assert_eq(out.stack, [ValType::funcref()])
  }
}

///|
test "cast branches adopt label prefix types even with polymorphic underflow" {
  let heap = HeapType::abs(AbsHeapType::func())
  let nonnull = ValType::ref_type(RefType::new(false, heap))
  for fail_branch in [false, true] {
    for polymorphic in [false, true] {
      let env = empty_env().with_label([ValType::funcref(), ValType::funcref()])
      let state = if polymorphic {
        tc_state_new(env, [ValType::funcref()], false, TerminalTcEscape)
      } else {
        make_state(env, [nonnull, ValType::funcref()])
      }
      let op = CastOp::new(true, true)
      let checked = if fail_branch {
        typecheck_br_on_cast_fail(state, LabelIdx::new(0U), op, heap, heap)
      } else {
        typecheck_br_on_cast(state, LabelIdx::new(0U), op, heap, heap)
      }
      let out = checked.unwrap()
      let result = if fail_branch { ValType::funcref() } else { nonnull }
      assert_eq(out.stack, [ValType::funcref(), result])
    }
  }
}

///|
test "ref_is_null accepts virtual and explicit bottom but rejects concrete numbers" {
  for explicit_bottom in [false, true] {
    let state = tc_state_new(empty_env(), [], false, TerminalTcEscape)
    let state = if explicit_bottom {
      typecheck_select_untyped(state).unwrap()
    } else {
      state
    }
    let out = match typecheck_ref_is_null(state) {
      Ok(out) => out
      Err(error) => fail(error)
    }
    assert_eq(out.stack, [ValType::i32()])
  }
  let concrete = tc_state_new(
    empty_env(),
    [ValType::i32()],
    false,
    TerminalTcEscape,
  )
  assert_true(typecheck_ref_is_null(concrete).is_err())
}
