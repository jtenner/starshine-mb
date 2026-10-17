///|
fn call_pop_test_env(params : Array[ValType], results : Array[ValType]) -> Env {
  empty_env().with_funcs([FuncType::new(params, results)])
}

///|
test "direct call consumes mixed operands and keeps owned state and signature snapshots" {
  let params = [ValType::i32(), ValType::i64(), ValType::anyref()]
  let results = [ValType::f32(), ValType::f64()]
  let env = call_pop_test_env(params, results)
  let input = [
    ValType::f64(),
    ValType::i32(),
    ValType::i64(),
    ValType::eqref_null(),
  ]
  let state = make_state(env, input)
  state.initialized_locals.push(true)
  state.initialized_locals.push(false)
  state.reachable_escape_depths.push(3)
  let sibling = TcState::{ ..state, }
  let output = typecheck_call(state, FuncIdx::new(0U)).unwrap()
  assert_true(physical_equal(output, state))
  assert_true(physical_equal(output.env, env))
  assert_true(
    physical_equal(output.initialized_locals, sibling.initialized_locals),
  )
  assert_true(
    physical_equal(
      output.reachable_escape_depths,
      sibling.reachable_escape_depths,
    ),
  )
  assert_eq(output.stack, [ValType::f64(), ValType::f32(), ValType::f64()])
  assert_eq(output.initialized_locals, [true, false])
  assert_eq(output.reachable_escape_depths, [3])
  assert_true(output.reachable)
  assert_false(output.polymorphic)
  assert_eq(output.escape, NoTcEscape)
  assert_eq(input, [
    ValType::f64(),
    ValType::i32(),
    ValType::i64(),
    ValType::eqref_null(),
  ])
  assert_eq(params, [ValType::i32(), ValType::i64(), ValType::anyref()])
  assert_eq(results, [ValType::f32(), ValType::f64()])
}

///|
test "direct call keeps function lookup before reverse operand errors and partial pops" {
  let params = [ValType::i32(), ValType::i64()]
  let env = call_pop_test_env(params, [ValType::f32()])
  for reachable in [true, false] {
    let input = [ValType::f64(), ValType::f32(), ValType::i64()]
    let state = tc_state_new(
      env,
      input.copy(),
      reachable,
      if reachable {
        NoTcEscape
      } else {
        TerminalTcEscape
      },
    )
    assert_eq(
      typecheck_call(state, FuncIdx::new(1U)).unwrap_err(),
      "invalid function index",
    )
    assert_eq(state.stack, input)
    assert_eq(
      typecheck_call(state, FuncIdx::new(0U)).unwrap_err(),
      "type mismatch: expected=I32 actual=F32",
    )
    assert_eq(state.stack, [ValType::f64()])
    assert_eq(state.reachable, reachable)
    assert_eq(input, [ValType::f64(), ValType::f32(), ValType::i64()])
  }
  let short = make_state(env, [ValType::i64()])
  assert_eq(
    typecheck_call(short, FuncIdx::new(0U)).unwrap_err(),
    "stack underflow",
  )
  assert_eq(short.stack, [])
  assert_eq(params, [ValType::i32(), ValType::i64()])
}

///|
test "direct call accepts virtual bottom and rejects wrong concrete dead operands" {
  let env = call_pop_test_env([ValType::i32(), ValType::i64()], [ValType::f64()])
  let bottom = tc_state_new(env, [], false, TerminalTcEscape)
  bottom.reachable_escape_depths.push(4)
  assert_true(
    physical_equal(typecheck_call(bottom, FuncIdx::new(0U)).unwrap(), bottom),
  )
  assert_eq(bottom.stack, [ValType::f64()])
  assert_false(bottom.reachable)
  assert_true(bottom.polymorphic)
  assert_eq(bottom.escape, TerminalTcEscape)
  assert_eq(bottom.reachable_escape_depths, [4])
  let concrete = tc_state_new(env, [ValType::f32()], false, TerminalTcEscape)
  assert_eq(
    typecheck_call(concrete, FuncIdx::new(0U)).unwrap_err(),
    "type mismatch: expected=I64 actual=F32",
  )
  assert_eq(concrete.stack, [])
  assert_false(concrete.reachable)
  assert_true(concrete.polymorphic)
  assert_eq(concrete.escape, TerminalTcEscape)
}

///|
test "public typed pop keeps its existing result state and error behavior" {
  let signature = [ValType::i32(), ValType::i64()]
  let valid = make_state(empty_env(), [
    ValType::f64(),
    ValType::i32(),
    ValType::i64(),
  ])
  assert_true(
    physical_equal(tc_state_pop_types(valid, signature).unwrap(), valid),
  )
  assert_eq(valid.stack, [ValType::f64()])
  let bad = make_state(empty_env(), [
    ValType::f64(),
    ValType::f32(),
    ValType::i64(),
  ])
  assert_eq(
    tc_state_pop_types(bad, signature).unwrap_err(),
    "type mismatch: expected=I32 actual=F32",
  )
  assert_eq(bad.stack, [ValType::f64()])
  assert_true(physical_equal(tc_state_pop_types(valid, []).unwrap(), valid))
  assert_eq(valid.stack, [ValType::f64()])
  assert_eq(signature, [ValType::i32(), ValType::i64()])
}

///|
fn call_pop_old_reference(state : TcState, fidx : FuncIdx) -> TcResult {
  let FuncType(params, results) = match
    state.env.get_functype_by_funcidx(fidx) {
    None => return Err("invalid function index")
    Some(ft) => ft
  }
  let popped = match state.pop_types(params) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  Ok(popped.push_types(results))
}

///|
test "direct call matches public-pop reference for bounded errors and state mutation" {
  let inputs = [
    [],
    [ValType::i64()],
    [ValType::i32(), ValType::i64()],
    [ValType::f32(), ValType::i64()],
    [ValType::i64(), ValType::f32()],
    [ValType::bottom(), ValType::i64()],
    [ValType::f64(), ValType::i32(), ValType::i64()],
  ]
  for params in [[], [ValType::i32(), ValType::i64()]] {
    let env = call_pop_test_env(params, [ValType::f64()])
    for input in inputs {
      let saved = input.copy()
      for reachable in [true, false] {
        for index in [0U, 1U] {
          let escape = if reachable { NoTcEscape } else { TerminalTcEscape }
          let actual = tc_state_new(env, input.copy(), reachable, escape)
          let expected = tc_state_new(env, input.copy(), reachable, escape)
          actual.reachable_escape_depths.push(2)
          expected.reachable_escape_depths.push(2)
          match
            (
              typecheck_call(actual, FuncIdx::new(index)),
              call_pop_old_reference(expected, FuncIdx::new(index)),
            ) {
            (Ok(a), Ok(e)) => {
              assert_true(physical_equal(a, actual))
              assert_true(physical_equal(e, expected))
            }
            (Err(a), Err(e)) => assert_eq(a, e)
            _ => abort("direct-call result differs from public-pop reference")
          }
          assert_eq(actual.stack, expected.stack)
          assert_eq(actual.reachable, expected.reachable)
          assert_eq(actual.polymorphic, expected.polymorphic)
          assert_eq(actual.escape, expected.escape)
          assert_eq(
            actual.reachable_escape_depths,
            expected.reachable_escape_depths,
          )
          assert_eq(actual.initialized_locals, expected.initialized_locals)
          assert_true(physical_equal(actual.env, env))
          assert_eq(input, saved)
        }
      }
    }
  }
}
