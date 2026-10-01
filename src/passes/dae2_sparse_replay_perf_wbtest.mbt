///|
fn dae2_sparse_replay_bench(
  it : @bench.T,
  boundaries : Int,
  nodes : Int,
  sparse : Bool,
) -> Unit {
  let source = Dae2Graph::new()
  ignore(source.locations(boundaries))
  for location in 1..<boundaries {
    source.observe(location)
  }
  source.solve()
  let saved_used = source.used.copy()
  let reference = Dae2RawReplayState::new(source, boundaries, sparse=false)
  let candidate = Dae2RawReplayState::new(source, boundaries)
  let action = fn(state : Dae2RawReplayState) {
    let mut sum = 0
    for body in 0..<16 {
      state.reset()
      let consumer = 1 + body % (boundaries - 1)
      let base = state.graph.locations(nodes)
      state.graph.edge(consumer, base)
      state.register(consumer)
      // An unused consumer must also be cleared on the next body.
      state.graph.edge(0, base + nodes - 1)
      state.register(0)
      for node in 1..<nodes {
        state.graph.edge(base + node - 1, base + node)
      }
      if !state.solve() {
        abort("replay benchmark changed module boundaries")
      }
      for node in base..<(base + nodes) {
        if state.graph.used[node] {
          sum += 1
        }
      }
    }
    sum
  }
  if action(reference) != 16 * nodes || action(candidate) != 16 * nodes {
    abort("sparse replay changed expression dependencies")
  }
  if reference.graph.used != candidate.graph.used ||
    reference.graph.first_edge != candidate.graph.first_edge ||
    reference.graph.edges != candidate.graph.edges {
    abort("sparse replay changed graph storage")
  }
  it.bench(fn() { it.keep(action(if sparse { candidate } else { reference })) })
  if source.used != saved_used || !source.edges.is_empty() {
    abort("replay mutated module mask")
  }
}

///|
test "bench DAE2 replay full boundaries=128 nodes=8 bodies=16" (it : @bench.T) {
  dae2_sparse_replay_bench(it, 128, 8, false)
}

///|
test "bench DAE2 replay sparse boundaries=128 nodes=8 bodies=16" (it : @bench.T) {
  dae2_sparse_replay_bench(it, 128, 8, true)
}

///|
test "bench DAE2 replay full boundaries=128 nodes=128 bodies=16" (it : @bench.T) {
  dae2_sparse_replay_bench(it, 128, 128, false)
}

///|
test "bench DAE2 replay sparse boundaries=128 nodes=128 bodies=16" (
  it : @bench.T,
) {
  dae2_sparse_replay_bench(it, 128, 128, true)
}

///|
test "bench DAE2 replay full boundaries=8192 nodes=8 bodies=16" (it : @bench.T) {
  dae2_sparse_replay_bench(it, 8192, 8, false)
}

///|
test "bench DAE2 replay sparse boundaries=8192 nodes=8 bodies=16" (
  it : @bench.T,
) {
  dae2_sparse_replay_bench(it, 8192, 8, true)
}

///|
test "bench DAE2 replay full boundaries=8192 nodes=128 bodies=16" (
  it : @bench.T,
) {
  dae2_sparse_replay_bench(it, 8192, 128, false)
}

///|
test "bench DAE2 replay sparse boundaries=8192 nodes=128 bodies=16" (
  it : @bench.T,
) {
  dae2_sparse_replay_bench(it, 8192, 128, true)
}

///|
test "bench DAE2 replay full boundaries=65536 nodes=8 bodies=16" (it : @bench.T) {
  dae2_sparse_replay_bench(it, 65536, 8, false)
}

///|
test "bench DAE2 replay sparse boundaries=65536 nodes=8 bodies=16" (
  it : @bench.T,
) {
  dae2_sparse_replay_bench(it, 65536, 8, true)
}

///|
test "bench DAE2 replay full boundaries=65536 nodes=128 bodies=16" (
  it : @bench.T,
) {
  dae2_sparse_replay_bench(it, 65536, 128, false)
}

///|
test "bench DAE2 replay sparse boundaries=65536 nodes=128 bodies=16" (
  it : @bench.T,
) {
  dae2_sparse_replay_bench(it, 65536, 128, true)
}
