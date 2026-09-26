///|
fn dae_forwarding_facts_bench(it : @bench.T, count : Int) -> Unit {
  let graph = dae_forwarding_facts_fixture(count)
  let dependencies = dae_boundary_dependency_graph_build(graph)
  if dependencies.parameter_forwarding_edges.length() != count {
    abort("forwarding benchmark lost an exact parameter edge")
  }
  it.bench(fn() { it.keep(dae_boundary_dependency_graph_build(graph)) })
}

///|
test "bench DAE forwarding facts callees=128" (it : @bench.T) {
  dae_forwarding_facts_bench(it, 128)
}

///|
test "bench DAE forwarding facts callees=256" (it : @bench.T) {
  dae_forwarding_facts_bench(it, 256)
}
