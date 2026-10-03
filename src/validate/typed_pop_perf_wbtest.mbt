///|
// Frozen typed-pop result boundary before the error-only worker optimization.
fn typed_pop_reference(st : TcState, expected : ValType) -> TcResult {
  // The stack is already owned and mutated by pop1. Check its popped value
  // directly so typed operands do not allocate an intermediate state/value pair.
  let actual = match st.stack.pop() {
    Some(value) => value
    None =>
      if !st.reachable {
        return Ok(st)
      } else {
        return Err("stack underflow")
      }
  }
  if actual == ValType::bottom() || Match::matches(actual, expected, st.env) {
    Ok(st)
  } else {
    Err("type mismatch: expected=\{expected} actual=\{actual}")
  }
}

///|
fn typed_pop_consumer_reference(st : TcState, ts : Array[ValType]) -> TcResult {
  let mut cur = st
  for i = ts.length() - 1; i >= 0; i = i - 1 {
    cur = match typed_pop_reference(cur, ts[i]) {
      Err(e) => return Err(e)
      Ok(s) => s
    }
  }
  Ok(cur)
}

///|
fn typed_pop_bench(it : @bench.T, kind : Int, before : Bool) -> Unit raise {
  let width = if kind == 1 { 32 } else if kind == 0 { 0 } else { 2 }
  let expected = if kind == 2 { ValType::anyref() } else { ValType::i32() }
  let actual = match kind {
    2 => ValType::eqref_null()
    3 => ValType::i64()
    _ => ValType::i32()
  }
  let signature = Array::make(width, expected)
  let left = make_state(empty_env(), Array::make(width, actual))
  let right = make_state(empty_env(), Array::make(width, actual))
  let ref_result = typed_pop_consumer_reference(left, signature)
  let new_result = pop_types_rev(right, signature)
  match (ref_result, new_result) {
    (Ok(_), Ok(_)) => ()
    (Err(a), Err(b)) => assert_eq(a, b)
    _ => fail("typed-pop behavior changed")
  }
  assert_eq(left.stack, right.stack)
  assert_eq(left.reachable, right.reachable)
  let state = make_state(empty_env(), [])
  it.bench(fn() {
    state.stack.clear()
    for _ in 0..<width {
      state.stack.push(actual)
    }
    it.keep(
      if before {
        typed_pop_consumer_reference(state, signature)
      } else {
        pop_types_rev(state, signature)
      },
    )
  })
}

///|
test "bench typed pop empty before" (it : @bench.T) {
  typed_pop_bench(it, 0, true)
}

///|
test "bench typed pop empty current" (it : @bench.T) {
  typed_pop_bench(it, 0, false)
}

///|
test "bench typed pop wide before" (it : @bench.T) {
  typed_pop_bench(it, 1, true)
}

///|
test "bench typed pop wide current" (it : @bench.T) {
  typed_pop_bench(it, 1, false)
}

///|
test "bench typed pop reference before" (it : @bench.T) {
  typed_pop_bench(it, 2, true)
}

///|
test "bench typed pop reference current" (it : @bench.T) {
  typed_pop_bench(it, 2, false)
}

///|
test "bench typed pop invalid before" (it : @bench.T) {
  typed_pop_bench(it, 3, true)
}

///|
test "bench typed pop invalid current" (it : @bench.T) {
  typed_pop_bench(it, 3, false)
}

///|
test "bench typed pop scalar before" (it : @bench.T) {
  typed_pop_bench(it, 4, true)
}

///|
test "bench typed pop scalar current" (it : @bench.T) {
  typed_pop_bench(it, 4, false)
}
