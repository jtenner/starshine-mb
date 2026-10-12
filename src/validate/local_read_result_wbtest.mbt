///|
fn local_read_expr_reference(
  expr : Expr,
  state : TcState,
  context : Bool,
) -> TcResult {
  let Expr(instrs) = expr
  let mut current = state
  for index, instr in instrs {
    match Typecheck::typecheck(instr, current) {
      Ok(next) => current = next
      Err(error) => {
        if context {
          return Err(
            "instruction[\{index}] \{instr}: \{error}; stack=\{current.stack}",
          )
        }
        return Err(error)
      }
    }
  }
  Ok(current)
}

///|
test "pinned local premise rejects a deliberately weakened initialization context" {
  // Core 3.0 algorithm get_local at spec revision
  // 7e9fb78c63d65018cc111422f657947b3df80d7b requires initialization.
  // This test-only context intentionally omits that premise; no production
  // validator switch or guest execution is introduced.
  let ty = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::extern_())),
  )
  let env = empty_env().with_locals(Locals::single(1U, ty))
  let strong = make_state(env, [])
  strong.initialized_locals.fill(false)
  assert_eq(
    typecheck_local_get(strong, LocalIdx::new(0U)).unwrap_err(),
    "uninitialized local: 0",
  )
  let deliberately_weakened = make_state(env, [])
  deliberately_weakened.initialized_locals.fill(true)
  let falsely_accepted = typecheck_local_get(
    deliberately_weakened,
    LocalIdx::new(0U),
  ).unwrap()
  assert_eq(falsely_accepted.stack, [ty])
  assert_false(strong.initialized_locals[0])
}

///|
test "local read expression retains owned state and sibling initialization masks" {
  for ty in [ValType::i32(), ValType::i64(), ValType::i31ref()] {
    let env = empty_env().with_locals(Locals::single(1U, ty))
    let input = [ValType::f64()]
    let state = make_state(env, input)
    state.initialized_locals.fill(true)
    state.reachable_escape_depths.push(2)
    let sibling = TcState::{ ..state, }
    let result = Typecheck::typecheck(
      Expr::new(Array::make(8, Instruction::local_get(LocalIdx::new(0U)))),
      state,
    ).unwrap()
    assert_true(physical_equal(result, state))
    assert_true(physical_equal(result.env, env))
    assert_true(
      physical_equal(result.initialized_locals, sibling.initialized_locals),
    )
    assert_eq(result.initialized_locals, [true])
    assert_eq(result.reachable_escape_depths, [2])
    assert_eq(result.escape, NoTcEscape)
    assert_true(result.reachable)
    assert_eq(result.stack.length(), 9)
    assert_eq(result.stack[0], ValType::f64())
    for i in 1..<9 {
      assert_eq(result.stack[i], ty)
    }
    assert_eq(input, [ValType::f64()])
  }
}

///|
test "local read expressions preserve first diagnostics and unreachable initialization checks" {
  let env = empty_env().with_locals(Locals::single(1U, ValType::i32()))
  for reachable in [false, true] {
    for initialized in [false, true] {
      for raw in [0U, 1U, 0x7fffffffU, 0xffffffffU] {
        for context in [false, true] {
          let make = fn() {
            let state = make_state(env, [ValType::f64()])
            let state = if reachable { state } else { state.set_unreachable() }
            state.initialized_locals.fill(initialized)
            state
          }
          let body = Expr::new([
            Instruction::local_get(LocalIdx::new(raw)),
            Instruction::local_get(LocalIdx::new(1U)),
            Instruction::unreachable_(),
          ])
          let actual_state = make()
          let expected_state = make()
          let expected = local_read_expr_reference(
            body, expected_state, context,
          )
          let actual = typecheck_expr_with_context(body, actual_state, context)
          // The second index is intentionally invalid even if the first succeeds.
          assert_eq(actual.unwrap_err(), expected.unwrap_err())
          assert_eq(actual_state.stack, expected_state.stack)
          assert_eq(
            actual_state.initialized_locals,
            expected_state.initialized_locals,
          )
          assert_eq(actual_state.reachable, expected_state.reachable)
          assert_eq(actual_state.escape, expected_state.escape)
        }
      }
    }
  }
}
