// Retained native control fixture for the rejected reachability inlining experiment.

///|
fn dae_unreachable_before_inline(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Unreachable => true
    @lib.Block(_, @lib.Expr(body)) =>
      body.length() == 1 && dae_unreachable_before_inline(body[0])
    _ => false
  }
}

///|
fn dae_unreachable_inline_bench(
  it : @bench.T,
  depth : Int,
  unreachable : Bool,
  reference : Bool,
) -> Unit {
  let mut instr = if unreachable {
    @lib.Instruction::unreachable_()
  } else {
    @lib.Instruction::nop()
  }
  for _ in 0..<depth {
    instr = @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([instr]),
    )
  }
  if dae_instr_is_unreachable_root(instr) != unreachable ||
    dae_unreachable_before_inline(instr) != unreachable {
    abort("unreachable-root classification changed")
  }
  it.bench(fn() {
    for _ in 0..<256 {
      it.keep(
        if reference {
          dae_unreachable_before_inline(instr)
        } else {
          dae_instr_is_unreachable_root(instr)
        },
      )
    }
  })
}

///|
test "bench DAE unreachable root depth=0 terminal=false reference" (
  it : @bench.T,
) {
  dae_unreachable_inline_bench(it, 0, false, true)
}

///|
test "bench DAE unreachable root depth=0 terminal=false current" (it : @bench.T) {
  dae_unreachable_inline_bench(it, 0, false, false)
}

///|
test "bench DAE unreachable root depth=0 terminal=true reference" (
  it : @bench.T,
) {
  dae_unreachable_inline_bench(it, 0, true, true)
}

///|
test "bench DAE unreachable root depth=0 terminal=true current" (it : @bench.T) {
  dae_unreachable_inline_bench(it, 0, true, false)
}

///|
test "bench DAE unreachable root depth=4 terminal=false reference" (
  it : @bench.T,
) {
  dae_unreachable_inline_bench(it, 4, false, true)
}

///|
test "bench DAE unreachable root depth=4 terminal=false current" (it : @bench.T) {
  dae_unreachable_inline_bench(it, 4, false, false)
}

///|
test "bench DAE unreachable root depth=4 terminal=true reference" (
  it : @bench.T,
) {
  dae_unreachable_inline_bench(it, 4, true, true)
}

///|
test "bench DAE unreachable root depth=4 terminal=true current" (it : @bench.T) {
  dae_unreachable_inline_bench(it, 4, true, false)
}

///|
test "bench DAE unreachable root depth=32 terminal=false reference" (
  it : @bench.T,
) {
  dae_unreachable_inline_bench(it, 32, false, true)
}

///|
test "bench DAE unreachable root depth=32 terminal=false current" (
  it : @bench.T,
) {
  dae_unreachable_inline_bench(it, 32, false, false)
}

///|
test "bench DAE unreachable root depth=32 terminal=true reference" (
  it : @bench.T,
) {
  dae_unreachable_inline_bench(it, 32, true, true)
}

///|
test "bench DAE unreachable root depth=32 terminal=true current" (it : @bench.T) {
  dae_unreachable_inline_bench(it, 32, true, false)
}
