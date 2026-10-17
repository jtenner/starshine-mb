///|
fn call_pop_bench(it : @bench.T, mode : Int32) -> Unit raise {
  let params = if mode == 0 { [] } else { [ValType::i32(), ValType::i64()] }
  let results = [ValType::f64()]
  let env = call_pop_test_env(params, results)
  let input = match mode {
    0 => [ValType::f32()]
    1 => [ValType::f32(), ValType::i32(), ValType::i64()]
    2 => []
    3 => [ValType::f32()]
    _ => abort("unknown call pop bench mode")
  }
  let state = tc_state_new(
    env,
    input.copy(),
    mode < 2,
    if mode < 2 {
      NoTcEscape
    } else {
      TerminalTcEscape
    },
  )
  let checked = typecheck_call(state, FuncIdx::new(0U))
  if mode == 3 {
    assert_eq(checked.unwrap_err(), "type mismatch: expected=I64 actual=F32")
    assert_eq(state.stack, [])
  } else {
    assert_true(physical_equal(checked.unwrap(), state))
    assert_eq(
      state.stack,
      if mode < 2 {
        [ValType::f32(), ValType::f64()]
      } else {
        [ValType::f64()]
      },
    )
  }
  it.bench(fn() {
    state.stack.clear()
    state.stack.append(input)
    it.keep(typecheck_call(state, FuncIdx::new(0U)))
  })
  assert_eq(
    params,
    if mode == 0 {
      []
    } else {
      [ValType::i32(), ValType::i64()]
    },
  )
  assert_eq(results, [ValType::f64()])
  assert_eq(
    input,
    match mode {
      0 | 3 => [ValType::f32()]
      1 => [ValType::f32(), ValType::i32(), ValType::i64()]
      2 => []
      _ => abort("unknown call pop bench mode")
    },
  )
}

///|
#skip("paired native empty-parameter direct-call control")
test "bench direct call pop empty signature" (it : @bench.T) {
  call_pop_bench(it, 0)
}

///|
#skip("paired native mixed-parameter direct-call control")
test "bench direct call pop mixed signature" (it : @bench.T) {
  call_pop_bench(it, 1)
}

///|
#skip("paired native polymorphic direct-call control")
test "bench direct call pop virtual bottom" (it : @bench.T) {
  call_pop_bench(it, 2)
}

///|
#skip("paired native concrete wrong-type dead-stack direct-call control")
test "bench direct call pop invalid concrete dead stack" (it : @bench.T) {
  call_pop_bench(it, 3)
}

///|
#skip("paired native unchanged public typed-pop control")
test "bench direct call pop public API control" (it : @bench.T) {
  let params = [ValType::i32(), ValType::i64()]
  let input = [ValType::f32(), ValType::i32(), ValType::i64()]
  let state = make_state(empty_env(), input)
  assert_true(physical_equal(state.pop_types(params).unwrap(), state))
  assert_eq(state.stack, [ValType::f32()])
  it.bench(fn() {
    state.stack.clear()
    state.stack.append(input)
    it.keep(state.pop_types(params))
  })
  assert_eq(input, [ValType::f32(), ValType::i32(), ValType::i64()])
  assert_eq(params, [ValType::i32(), ValType::i64()])
}
