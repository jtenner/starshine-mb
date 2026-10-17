///|
test "DAE forwarding component rejects too few nodes before solving flow" {
  let input = dae_forwarding_memo_blocked_fixture()
  let saved = @binary.encode_module(input).unwrap()
  let original = dae_collect_original_boundary_snapshot(input)
  let graph = dae_current_boundary_graph_new(input)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  let nodes = dae_collect_forwarded_param_component(
    input,
    [0, 1],
    graph.snapshot.type_indices,
    graph.snapshot.boundary_facts,
  )
  assert_eq(nodes.length(), 0)
  // The old path always solved flow, then the candidate builder rejected fewer
  // than two nodes. No flow fact can change this rejection.
  let reference_solves = [0]
  reference_solves[0] += 1
  ignore(dae_solve_parameter_flow(graph, dependencies, seed_defs=[0, 1]))
  assert_true(
    dae_build_forwarded_param_component_rewrite_plan(
      input,
      graph,
      dependencies,
      [],
      nodes,
      graph.snapshot.boundary_facts,
      original=Some(original),
    )
    is None,
  )
  let actual_solves = [0]
  assert_true(
    dae_run_forwarded_param_component_transaction_with_graph(
      original,
      input,
      [],
      [0, 1],
      graph,
      dependencies,
      flow_solves=Some(actual_solves),
    )
    is None,
  )
  assert_eq(reference_solves[0], 1)
  assert_eq(actual_solves[0], 0)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_eq(graph.module_epoch, 0)
  assert_eq(graph.call_epoch, 0)
  assert_eq(graph.type_epoch, 0)
  @validate.validate_module(input).unwrap()
}
