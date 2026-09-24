///|
fn tail_call_ancestry_fixture(depth : Int) -> @lib.Module {
  let mut body : Array[@lib.Instruction] = [@lib.Instruction::nop()]
  for _ in 0..<depth {
    body = [
      @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(body)),
    ]
  }
  opportunity_module(body, [], [])
}

///|
fn tail_call_ancestry_bench(it : @bench.T, depth : Int) -> Unit {
  let fixture = tail_call_ancestry_fixture(depth)
  let expected = opportunity_run(fixture, "tail-call", true)
  if expected != fixture {
    abort("call-free TailCall fixture must stay unchanged")
  }
  it.bench(fn() { it.keep(opportunity_run(fixture, "tail-call", false)) })
}

///|
test "bench tail-call ancestry depth=256" (it : @bench.T) {
  tail_call_ancestry_bench(it, 256)
}

///|
test "bench tail-call ancestry depth=512" (it : @bench.T) {
  tail_call_ancestry_bench(it, 512)
}
