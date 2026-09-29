///|
fn dae2_replay_workspace_bench(
  it : @bench.T,
  boundaries : Int,
  reuse : Bool,
) -> Unit {
  let source = Dae2Graph::new()
  ignore(source.locations(boundaries))
  source.observe(boundaries - 1)
  source.solve()
  let saved_used = source.used.copy()
  let workspace = source.for_raw_rewrite(boundaries)
  let action = fn(reuse : Bool) {
    let mut sum = 0
    for _ in 0..<64 {
      let replay = if reuse {
        workspace.reset_for_raw_rewrite(source, boundaries)
        workspace
      } else {
        source.for_raw_rewrite(boundaries)
      }
      let base = replay.locations(64)
      replay.edge(boundaries - 1, base)
      for node in 1..<64 {
        replay.edge(base + node - 1, base + node)
      }
      replay.solve()
      for node in base..<(base + 64) {
        if replay.used[node] {
          sum += 1
        }
      }
    }
    sum
  }
  if action(false) != 4096 || action(true) != 4096 {
    abort("replay workspace changed observed dependencies")
  }
  it.bench(fn() { it.keep(action(reuse)) })
  if source.used != saved_used || source.cursor != 1 || !source.edges.is_empty() {
    abort("replay benchmark mutated solved module boundaries")
  }
}

///|
test "bench DAE2 fresh replay boundaries=128 bodies=64" (it : @bench.T) {
  dae2_replay_workspace_bench(it, 128, false)
}

///|
test "bench DAE2 reused replay boundaries=128 bodies=64" (it : @bench.T) {
  dae2_replay_workspace_bench(it, 128, true)
}

///|
test "bench DAE2 fresh replay boundaries=8192 bodies=64" (it : @bench.T) {
  dae2_replay_workspace_bench(it, 8192, false)
}

///|
test "bench DAE2 reused replay boundaries=8192 bodies=64" (it : @bench.T) {
  dae2_replay_workspace_bench(it, 8192, true)
}
