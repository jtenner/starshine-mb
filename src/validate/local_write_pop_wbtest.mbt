///|
fn local_write_pop_reference(
  state : TcState,
  index : LocalIdx,
  tee : Bool,
  owner? : TcInitializationOwner? = None,
) -> TcResult {
  match state.env.get_local_type(index) {
    None => Err("invalid local index")
    Some(value) =>
      match state.pop_expect(value) {
        Err(error) => Err(error)
        Ok(next) => {
          let next = next.mark_local_initialized(
            index,
            initialization_owner=owner,
          )
          Ok(if tee { next.push1(value) } else { next })
        }
      }
  }
}

///|
fn local_write_pop_current(
  state : TcState,
  index : LocalIdx,
  tee : Bool,
  owner? : TcInitializationOwner? = None,
) -> TcResult {
  if tee {
    typecheck_local_tee(state, index, initialization_owner=owner)
  } else {
    typecheck_local_set(state, index, initialization_owner=owner)
  }
}

///|
test "local writes keep owned stack state and control metadata" {
  for tee in [false, true] {
    let env = empty_env().with_locals(Locals::single(1U, ValType::i32()))
    let input = [ValType::f64(), ValType::i32()]
    let state = make_state(env, input)
    state.reachable_escape_depths.push(2)
    let result = local_write_pop_current(state, LocalIdx::new(0U), tee).unwrap()
    assert_true(physical_equal(result, state))
    assert_true(physical_equal(result.env, env))
    assert_eq(result.initialized_locals, [true])
    assert_eq(result.reachable_escape_depths, [2])
    assert_eq(result.escape, NoTcEscape)
    assert_true(result.reachable)
    assert_eq(result.stack, if tee { input } else { [ValType::f64()] })
    assert_eq(input, [ValType::f64(), ValType::i32()])
  }
}

///|
test "local writes initialize nondefault references without changing sibling masks" {
  for tee in [false, true] {
    let ty = ValType::i31ref()
    let env = empty_env().with_locals(Locals::single(2U, ty))
    let entry = make_state(env, [ty])
    entry.initialized_locals.fill(false)
    let sibling = TcState::{ ..entry, }
    let owner = TcInitializationOwner::new()
    let first = local_write_pop_current(
      entry,
      LocalIdx::new(0U),
      tee,
      owner=Some(owner),
    ).unwrap()
    assert_eq(first.initialized_locals, [true, false])
    assert_eq(entry.initialized_locals, [false, false])
    if !tee {
      first.stack.push(ty)
    }
    let second = local_write_pop_current(
      first,
      LocalIdx::new(1U),
      tee,
      owner=Some(owner),
    ).unwrap()
    assert_eq(second.initialized_locals, [true, true])
    assert_true(
      physical_equal(first.initialized_locals, second.initialized_locals),
    )
    assert_eq(entry.initialized_locals, [false, false])
    assert_eq(sibling.initialized_locals, [false, false])
    assert_eq(second.stack, if tee { [ty] } else { [] })
  }
}

///|
test "local writes preserve first errors and concrete unreachable type checks" {
  for tee in [false, true] {
    let env = empty_env().with_locals(Locals::single(1U, ValType::i32()))
    for unreachable in [false, true] {
      for input in [[], [ValType::f32()], [ValType::bottom()]] {
        for index in [LocalIdx::new(0U), LocalIdx::new(99U)] {
          let current = make_state(env, [])
          let reference = make_state(env, [])
          let current = if unreachable {
            current.set_unreachable()
          } else {
            current
          }
          let reference = if unreachable {
            reference.set_unreachable()
          } else {
            reference
          }
          current.initialized_locals.fill(false)
          reference.initialized_locals.fill(false)
          for value in input {
            current.stack.push(value)
            reference.stack.push(value)
          }
          let actual = local_write_pop_current(current, index, tee)
          let expected = local_write_pop_reference(reference, index, tee)
          match (actual, expected) {
            (Ok(a), Ok(b)) => {
              assert_eq(a.stack, b.stack)
              assert_eq(a.initialized_locals, b.initialized_locals)
              assert_eq(a.reachable, b.reachable)
              assert_eq(a.escape, b.escape)
            }
            (Err(a), Err(b)) => {
              assert_eq(a, b)
              assert_eq(current.initialized_locals, [false])
              assert_eq(current.stack, reference.stack)
              if index == LocalIdx::new(99U) {
                assert_eq(a, "invalid local index")
                assert_eq(current.stack, input)
              }
            }
            _ => fail("local-write validation changed")
          }
        }
      }
    }
    let env = empty_env().with_locals(Locals::single(1U, ValType::anyref()))
    let state = make_state(env, [ValType::eqref_null()])
    let result = local_write_pop_current(state, LocalIdx::new(0U), tee).unwrap()
    assert_eq(result.stack, if tee { [ValType::anyref()] } else { [] })
  }
}
