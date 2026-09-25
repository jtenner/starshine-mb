///|
fn sgo_runtime_trace_nested_block_fixture(depth : Int) -> @lib.Expr {
  let mut body = @lib.Expr::new([@lib.Instruction::nop()])
  for _ in 0..<depth {
    body = @lib.Expr::new([
      @lib.Instruction::block(@lib.BlockType::void_(), body),
    ])
  }
  body
}

///|
fn sgo_runtime_trace_nested_block_bench(it : @bench.T, depth : Int) -> Unit {
  let fixture = sgo_runtime_trace_nested_block_fixture(depth)
  let (preflight, changed) = sgo_rewrite_runtime_trace_expr(fixture, [])
  if changed || preflight != fixture {
    abort("SGO barrier-free nested-block fixture unexpectedly changed")
  }
  it.bench(fn() { it.keep(sgo_rewrite_runtime_trace_expr(fixture, [])) })
}

///|
test "bench SGO runtime trace nested blocks=128" (it : @bench.T) {
  sgo_runtime_trace_nested_block_bench(it, 128)
}

///|
test "bench SGO runtime trace nested blocks=256" (it : @bench.T) {
  sgo_runtime_trace_nested_block_bench(it, 256)
}

///|
test "SGO runtime trace carries nested block barriers" {
  let no_barrier = sgo_runtime_trace_nested_block_fixture(3)
  let (_, no_change, has_barrier) = sgo_rewrite_runtime_trace_expr_with_facts(
    no_barrier,
    [],
    [],
  )
  assert_false(no_change)
  assert_false(has_barrier)
  let with_call = @lib.Expr::new([
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(0U))]),
    ),
  ])
  let (_, _, has_barrier) = sgo_rewrite_runtime_trace_expr_with_facts(
    with_call,
    [],
    [],
  )
  assert_true(has_barrier)
  let with_if = @lib.Expr::new([
    @lib.Instruction::if_(@lib.BlockType::void_(), [], None),
  ])
  let (_, _, has_barrier) = sgo_rewrite_runtime_trace_expr_with_facts(
    with_if,
    [],
    [],
  )
  assert_true(has_barrier)
}
