///|
fn pass_lower_flatten_perf_fixture(depth : Int) -> Array[@lib.Instruction] {
  let mut body = @lib.Expr::new([@lib.Instruction::nop()])
  for _ in 0..<depth {
    body = @lib.Expr::new([
      @lib.Instruction::nop(),
      @lib.Instruction::block(@lib.BlockType::void_(), body),
    ])
  }
  let @lib.Expr(instrs) = body
  instrs
}

///|
fn pass_lower_flatten_perf_bench(it : @bench.T, depth : Int) -> Unit {
  let fixture = pass_lower_flatten_perf_fixture(depth)
  let env = @validate.Env::new().with_module(@lib.Module::new())
  let (preflight, changed, branchless) = pass_lower_flatten_branchless_blocks(
    fixture, env,
  )
  if !changed ||
    !branchless ||
    preflight.length() != depth + 1 ||
    !preflight.all(fn(instr) { instr == @lib.Instruction::nop() }) {
    abort("lower capture cleanup fixture failed to flatten")
  }
  it.bench(fn() { it.keep(pass_lower_flatten_branchless_blocks(fixture, env)) })
}

///|
test "bench lower capture flatten nested blocks=128" (it : @bench.T) {
  pass_lower_flatten_perf_bench(it, 128)
}

///|
test "bench lower capture flatten nested blocks=256" (it : @bench.T) {
  pass_lower_flatten_perf_bench(it, 256)
}

///|
test "lower capture flatten keeps barrier block and label slots" {
  let env = @validate.Env::new().with_module(@lib.Module::new())
  let source = [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::nop()]),
        ),
        @lib.Instruction::unreachable_(),
      ]),
    ),
  ]
  let keep : Array[Bool] = []
  let (actual, changed, branchless) = pass_lower_flatten_branchless_blocks(
    source,
    env,
    label_keep=Some(keep),
  )
  assert_true(changed)
  assert_false(branchless)
  @debug.assert_eq(actual, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::nop(), @lib.Instruction::unreachable_()]),
    ),
  ])
  @debug.assert_eq(keep, [true, false])
}
