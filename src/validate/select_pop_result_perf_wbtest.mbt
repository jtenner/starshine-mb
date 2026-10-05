///|
fn select_pop_result_bench(
  it : @bench.T,
  refs : Bool,
  stopped : Bool,
  invalid : Bool,
) -> Unit {
  let ty = if refs { ValType::anyref() } else { ValType::i32() }
  let actual = if refs { ValType::eqref_null() } else { ty }
  let types = [ty]
  let state = tc_state_new(
    empty_env(),
    [],
    !stopped,
    if stopped {
      TerminalTcEscape
    } else {
      NoTcEscape
    },
  )
  let reset = fn() {
    state.stack.clear()
    if !stopped {
      state.stack.push(actual)
      state.stack.push(actual)
      state.stack.push(if invalid { ValType::f64() } else { ValType::i32() })
    }
  }
  reset()
  if typecheck_select_typed(state, types).is_err() != invalid {
    abort("typed select control changed acceptance")
  }
  it.bench(fn() {
    reset()
    it.keep(typecheck_select_typed(state, types))
  })
}

///|
test "bench typed select scalar pop results" (it : @bench.T) {
  select_pop_result_bench(it, false, false, false)
}

///|
test "bench typed select subtype pop results" (it : @bench.T) {
  select_pop_result_bench(it, true, false, false)
}

///|
test "bench typed select virtual bottom pop results" (it : @bench.T) {
  select_pop_result_bench(it, false, true, false)
}

///|
test "bench typed select intentionally invalid condition" (it : @bench.T) {
  select_pop_result_bench(it, false, false, true)
}
