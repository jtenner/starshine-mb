///|
fn cleanup_flow_bench(it : @bench.T, depth : Int, branches : Bool) -> Unit {
  let leaf : Array[@lib.Instruction] = []
  for _ in 0..<128 {
    leaf.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
    leaf.push(@lib.Instruction::drop())
  }
  if branches {
    leaf.push(@lib.Instruction::br(@lib.LabelIdx::new(0U)))
  }
  let mut body = leaf
  for _ in 0..<depth {
    body = [
      @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(body)),
    ]
  }
  let counts = Array::make(1, 0)
  it.bench(fn() {
    counts[0] = 0
    run_hot_pipeline_simplify_locals_lowered_count_local_gets_in_body(
      body, counts,
    )
    it.keep(counts[0])
  })
}

///|
test "bench cleanup reachable counts flat" (it : @bench.T) {
  cleanup_flow_bench(it, 0, false)
}

///|
test "bench cleanup reachable counts depth=16" (it : @bench.T) {
  cleanup_flow_bench(it, 16, false)
}

///|
test "bench cleanup reachable counts depth=64" (it : @bench.T) {
  cleanup_flow_bench(it, 64, false)
}

///|
test "bench cleanup reachable counts depth=128" (it : @bench.T) {
  cleanup_flow_bench(it, 128, false)
}

///|
test "bench cleanup reachable counts branching depth=64" (it : @bench.T) {
  cleanup_flow_bench(it, 64, true)
}
