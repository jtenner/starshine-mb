///|
// Faithful pre-change reverse iterator; pop_expect is unchanged by this trial.
fn tc_reverse_types_reference(st : TcState, ts : Array[ValType]) -> TcResult {
  let mut st = st
  for t in ts.rev_iter() {
    st = match st.pop_expect(t) {
      Err(error) => return Err(error)
      Ok(next) => next
    }
  }
  Ok(st)
}

///|
fn tc_reverse_types_bench(
  it : @bench.T,
  width : Int,
  kind : Int,
  before : Bool,
) -> Unit raise {
  let expected = if kind == 1 { ValType::anyref() } else { ValType::i32() }
  let actual = match kind {
    1 => ValType::eqref_null()
    2 => ValType::i64()
    _ => ValType::i32()
  }
  let signature = Array::make(width, expected)
  let state = make_state(empty_env(), [])
  for _ in 0..<width {
    state.stack.push(actual)
  }
  let result = pop_types_rev(state, signature)
  if kind == 2 {
    assert_true(result.is_err())
  } else {
    assert_true(result.is_ok())
  }
  state.stack.clear()
  it.bench(fn() {
    for _ in 0..<width {
      state.stack.push(actual)
    }
    it.keep(
      if before {
        tc_reverse_types_reference(state, signature)
      } else {
        pop_types_rev(state, signature)
      },
    )
    state.stack.clear()
  })
}

///|
test "bench reverse types empty before" (it : @bench.T) {
  tc_reverse_types_bench(it, 0, 0, true)
}

///|
test "bench reverse types empty current" (it : @bench.T) {
  tc_reverse_types_bench(it, 0, 0, false)
}

///|
test "bench reverse types scalar before" (it : @bench.T) {
  tc_reverse_types_bench(it, 1, 0, true)
}

///|
test "bench reverse types scalar current" (it : @bench.T) {
  tc_reverse_types_bench(it, 1, 0, false)
}

///|
test "bench reverse types multi before" (it : @bench.T) {
  tc_reverse_types_bench(it, 32, 0, true)
}

///|
test "bench reverse types multi current" (it : @bench.T) {
  tc_reverse_types_bench(it, 32, 0, false)
}

///|
test "bench reverse types reference before" (it : @bench.T) {
  tc_reverse_types_bench(it, 2, 1, true)
}

///|
test "bench reverse types reference current" (it : @bench.T) {
  tc_reverse_types_bench(it, 2, 1, false)
}

///|
test "bench reverse types invalid before" (it : @bench.T) {
  tc_reverse_types_bench(it, 2, 2, true)
}

///|
test "bench reverse types invalid current" (it : @bench.T) {
  tc_reverse_types_bench(it, 2, 2, false)
}
