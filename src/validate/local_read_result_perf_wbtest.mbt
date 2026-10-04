///|
fn local_read_result_bench(
  it : @bench.T,
  count : Int,
  reference_type : Bool,
  invalid : Bool,
) -> Unit raise {
  let ty = if reference_type { ValType::i31ref() } else { ValType::i32() }
  let env = empty_env().with_locals(Locals::single(1U, ty))
  let state = make_state(env, [])
  state.initialized_locals.fill(true)
  let body = Expr::new(
    Array::make(
      count,
      Instruction::local_get(LocalIdx::new(if invalid { 1U } else { 0U })),
    ),
  )
  let expected_state = make_state(env, [])
  expected_state.initialized_locals.fill(true)
  match
    (
      Typecheck::typecheck(body, state),
      local_read_expr_reference(body, expected_state, true),
    ) {
    (Ok(a), Ok(b)) => assert_eq(a.stack, b.stack)
    (Err(a), Err(b)) => assert_eq(a, b)
    _ => fail("local read control differs from instruction reference")
  }
  it.bench(fn() {
    state.stack.clear()
    it.keep(Typecheck::typecheck(body, state))
  })
}

///|
test "bench local read expression single" (it : @bench.T) {
  local_read_result_bench(it, 1, false, false)
}

///|
test "bench local read expression wide scalar" (it : @bench.T) {
  local_read_result_bench(it, 256, false, false)
}

///|
test "bench local read expression wide reference" (it : @bench.T) {
  local_read_result_bench(it, 256, true, false)
}

///|
test "bench local read expression intentionally invalid index" (it : @bench.T) {
  local_read_result_bench(it, 1, false, true)
}
