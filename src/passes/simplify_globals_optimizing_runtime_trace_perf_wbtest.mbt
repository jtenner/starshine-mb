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
    [],
  )
  assert_true(has_barrier)
}

///|
fn sgo_runtime_trace_sparse_barrier_fixture(
  global_count : Int,
  barrier_count : Int,
) -> (@lib.Expr, Array[SgoGlobalInfo]) {
  let globals : Array[@lib.Global] = []
  for idx in 0..<global_count {
    globals.push(
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), true),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(idx))]),
      ),
    )
  }
  let mod_ = @lib.Module::new().with_global_sec(@lib.GlobalSec::new(globals))
  let (infos, _) = sgo_collect_global_infos(mod_)
  let instrs : Array[@lib.Instruction] = []
  for _ in 0..<barrier_count {
    instrs.push(@lib.Instruction::i32_const(@lib.I32(1)))
    instrs.push(@lib.Instruction::global_set(@lib.GlobalIdx::new(0U)))
    instrs.push(@lib.Instruction::call(@lib.FuncIdx::new(0U)))
  }
  (@lib.Expr::new(instrs), infos)
}

///|
fn sgo_runtime_trace_sparse_barrier_bench(it : @bench.T, count : Int) -> Unit {
  let (fixture, infos) = sgo_runtime_trace_sparse_barrier_fixture(count, count)
  let (preflight, changed) = sgo_rewrite_runtime_trace_expr(fixture, infos)
  if changed || preflight != fixture {
    abort("SGO sparse-barrier fixture unexpectedly changed")
  }
  it.bench(fn() { it.keep(sgo_rewrite_runtime_trace_expr(fixture, infos)) })
}

///|
test "bench SGO runtime trace sparse barriers=256 globals=256" (it : @bench.T) {
  sgo_runtime_trace_sparse_barrier_bench(it, 256)
}

///|
test "bench SGO runtime trace sparse barriers=512 globals=512" (it : @bench.T) {
  sgo_runtime_trace_sparse_barrier_bench(it, 512)
}

///|
test "SGO sparse runtime fact clear preserves call barriers" {
  let (_, infos) = sgo_runtime_trace_sparse_barrier_fixture(8, 0)
  let input = @lib.Expr::new([
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::drop(),
  ])
  let (output, changed) = sgo_rewrite_runtime_trace_expr(input, infos)
  assert_true(changed)
  let @lib.Expr(instrs) = output
  @debug.assert_eq(instrs[2], @lib.Instruction::i32_const(@lib.I32(7)))
  @debug.assert_eq(
    instrs[5],
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
  )
}
