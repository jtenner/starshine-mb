///|
fn dae2_graph_fields_build(nodes : Int) -> Dae2Graph {
  let graph = Dae2Graph::new()
  ignore(graph.locations(nodes + 2))
  for node in 0..<(nodes - 1) {
    graph.edge(node, node + 1)
    if node + 2 < nodes {
      graph.edge(node, node + 2)
    }
  }
  graph.edge(nodes, nodes + 1)
  graph.edge(nodes + 1, nodes)
  graph.observe(0)
  graph.solve()
  graph
}

///|
fn dae2_graph_fields_reference(nodes : Int) -> Dae2MutableGraphReference {
  let graph = Dae2MutableGraphReference::new()
  ignore(graph.locations(nodes + 2))
  for node in 0..<(nodes - 1) {
    graph.edge(node, node + 1)
    if node + 2 < nodes {
      graph.edge(node, node + 2)
    }
  }
  graph.edge(nodes, nodes + 1)
  graph.edge(nodes + 1, nodes)
  graph.observe(0)
  graph.solve()
  graph
}

///|
fn dae2_graph_fields_bench(
  it : @bench.T,
  nodes : Int,
  reference : Bool,
) -> Unit {
  let actual = dae2_graph_fields_build(nodes)
  let expected = dae2_graph_fields_reference(nodes)
  if actual.used != expected.used ||
    actual.edges != expected.edges ||
    actual.work != expected.work {
    abort("graph field control changed topology or solved liveness")
  }
  for node in 0..<nodes {
    if !actual.used[node] {
      abort("graph control lost an observed dependency")
    }
  }
  if actual.used[nodes] || actual.used[nodes + 1] {
    abort("unobserved forwarding cycle became live")
  }
  it.bench(fn() {
    if reference {
      let graph = dae2_graph_fields_reference(nodes)
      it.keep((graph.used, graph.edges, graph.work))
    } else {
      let graph = dae2_graph_fields_build(nodes)
      it.keep((graph.used, graph.edges, graph.work))
    }
  })
}

///|
test "bench DAE2 graph fields nodes=16 mutable reference" (it : @bench.T) {
  dae2_graph_fields_bench(it, 16, true)
}

///|
test "bench DAE2 graph fields nodes=16 immutable" (it : @bench.T) {
  dae2_graph_fields_bench(it, 16, false)
}

///|
test "bench DAE2 graph fields nodes=8192 mutable reference" (it : @bench.T) {
  dae2_graph_fields_bench(it, 8192, true)
}

///|
test "bench DAE2 graph fields nodes=8192 immutable" (it : @bench.T) {
  dae2_graph_fields_bench(it, 8192, false)
}
