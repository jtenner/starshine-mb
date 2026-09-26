///|
fn dae_dependency_cache_bench(it : @bench.T, cached : Bool) -> Unit {
  let graph = dae_forwarding_facts_fixture(128)
  let facts = dae_boundary_dependency_graph_new(graph)
  if facts.parameter_forwarding_edges.length() != 128 {
    abort("missing forwarding edges")
  }
  it.bench(fn() {
    for _ in 0..<3 {
      it.keep(
        if cached {
          dae_boundary_dependency_graph_new(graph)
        } else {
          dae_boundary_dependency_graph_build(graph)
        },
      )
    }
  })
}

///|
test "bench DAE dependency queries rebuild" (it : @bench.T) {
  dae_dependency_cache_bench(it, false)
}

///|
test "bench DAE dependency queries cached" (it : @bench.T) {
  dae_dependency_cache_bench(it, true)
}
