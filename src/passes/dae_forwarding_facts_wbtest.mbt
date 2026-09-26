///|
fn dae_forwarding_facts_fixture(count : Int) -> DaeCurrentBoundaryGraph {
  let text = StringBuilder::new()
  text.write_string("(module ")
  for i in 0..<count {
    text.write_string("(func $h\{i} (param i32) (result i32) local.get 0) ")
  }
  text.write_string("(func (export \"run\") (param i32) ")
  for _ in 0..<2 {
    for i in 0..<count {
      text.write_string("local.get 0 call $h\{i} drop ")
    }
  }
  text.write_string("))")
  dae_current_boundary_graph_new(pass_test_module_from_wat(text.to_string()))
}

///|
test "dae forwarding facts reuse snapshot types and deduplicate exact edges" {
  let graph = dae_forwarding_facts_fixture(32)
  let @lib.Func(_, @lib.Expr(body)) = graph.snapshot.funcs[32]
  let edges : Array[DaeParameterForwardingEdge] = []
  let callers = dae_dependency_adjacency_new(33)
  let resolutions = [0]
  let probes = [0]
  dae_collect_parameter_forwarding_dependencies_instrs(
    body,
    0,
    graph.mod_,
    32,
    1,
    graph.snapshot.type_indices,
    graph.function_epochs,
    edges,
    callers,
    function_types=Some(graph.snapshot.function_types),
    type_resolutions=Some(resolutions),
    edge_probes=Some(probes),
  )
  assert_eq(edges.length(), 32)
  for i in 0..<32 {
    assert_eq(edges[i].caller_def, 32)
    assert_eq(edges[i].caller_param_idx, 0)
    assert_eq(edges[i].callee_def, i)
    assert_eq(edges[i].callee_param_idx, 0)
    assert_eq(callers[i], [32])
  }
  assert_eq(resolutions[0], 0)
  assert_true(probes[0] <= 64, msg="forwarding membership probes: \{probes[0]}")
}

///|
test "dae forwarding membership retains every caller of a shared callee" {
  let text = StringBuilder::new()
  text.write_string(
    "(module (func $target (param i32) (result i32) local.get 0)",
  )
  for _ in 0..<6 {
    text.write_string(
      "(func (param i32) local.get 0 call $target drop local.get 0 call $target drop)",
    )
  }
  text.write_string(")")
  let graph = dae_current_boundary_graph_new(
    pass_test_module_from_wat(text.to_string()),
  )
  let facts = dae_boundary_dependency_graph_new(graph)
  assert_eq(facts.parameter_forwarders_by_def[0], [1, 2, 3, 4, 5, 6])
  assert_eq(facts.parameter_forwarding_edges.length(), 6)
}
