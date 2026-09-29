///|
fn tc_pop_expect_reference(st : TcState, expected : ValType) -> TcResult {
  match st.pop1() {
    Err(e) => Err(e)
    Ok((st2, actual)) => {
      if actual == ValType::bottom() {
        return Ok(st2)
      }
      if Match::matches(actual, expected, st.env) {
        Ok(st2)
      } else {
        Err("type mismatch: expected=\{expected} actual=\{actual}")
      }
    }
  }
}

///|
fn tc_pop_expect_bench(it : @bench.T, count : Int, reference : Bool) -> Unit {
  let state = make_state(empty_env(), [])
  state.stack.push(ValType::i32())
  let actual = state.pop_expect(ValType::i32()).unwrap()
  if !physical_equal(actual, state) || !state.stack.is_empty() {
    abort("typed pop changed owned state")
  }
  it.bench(fn() {
    for _ in 0..<count {
      state.stack.push(ValType::i32())
      it.keep(
        if reference {
          tc_pop_expect_reference(state, ValType::i32())
        } else {
          state.pop_expect(ValType::i32())
        },
      )
    }
  })
}

///|
test "bench typed operand pops count=16 reference" (it : @bench.T) {
  tc_pop_expect_bench(it, 16, true)
}

///|
test "bench typed operand pops count=16 direct" (it : @bench.T) {
  tc_pop_expect_bench(it, 16, false)
}

///|
test "bench typed operand pops count=1024 reference" (it : @bench.T) {
  tc_pop_expect_bench(it, 1024, true)
}

///|
test "bench typed operand pops count=1024 direct" (it : @bench.T) {
  tc_pop_expect_bench(it, 1024, false)
}
