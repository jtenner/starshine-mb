///|
fn local_write_pop_bench(it : @bench.T, tee : Bool, kind : Int) -> Unit raise {
  let expected = if kind == 2 { ValType::anyref() } else { ValType::i32() }
  let actual = if kind == 2 {
    ValType::eqref_null()
  } else if kind == 1 {
    ValType::f32()
  } else {
    expected
  }
  let env = empty_env().with_locals(Locals::single(1U, expected))
  let state = make_state(env, [])
  let reference = make_state(env, [actual])
  state.stack.push(actual)
  match
    (
      local_write_pop_current(state, LocalIdx::new(0U), tee),
      local_write_pop_reference(reference, LocalIdx::new(0U), tee),
    ) {
    (Ok(a), Ok(b)) => assert_eq(a.stack, b.stack)
    (Err(a), Err(b)) => assert_eq(a, b)
    _ => fail("local-write benchmark changed behavior")
  }
  it.bench(fn() {
    state.stack.clear()
    state.stack.push(actual)
    it.keep(local_write_pop_current(state, LocalIdx::new(0U), tee))
  })
}

///|
test "bench local set numeric owned state" (it : @bench.T) {
  local_write_pop_bench(it, false, 0)
}

///|
test "bench local tee numeric owned state" (it : @bench.T) {
  local_write_pop_bench(it, true, 0)
}

///|
test "bench local tee reference subtype" (it : @bench.T) {
  local_write_pop_bench(it, true, 2)
}

///|
test "bench local set invalid concrete operand control" (it : @bench.T) {
  local_write_pop_bench(it, false, 1)
}
