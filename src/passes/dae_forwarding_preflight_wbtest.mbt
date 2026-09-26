///|
test "dae forwarding analysis skips callers without function parameters" {
  let mod_ = pass_test_module_from_wat(
    "(module (func $helper (param i32) (result i32) local.get 0) (func (export \"run\") (result i32) (local i32) i32.const 7 local.set 0 block local.get 0 call $helper drop end local.get 0 call $helper))",
  )
  let graph = dae_current_boundary_graph_new(mod_)
  let @lib.Func(_, @lib.Expr(body)) = graph.snapshot.funcs[1]
  let edges : Array[DaeParameterForwardingEdge] = []
  let callers = dae_dependency_adjacency_new(2)
  let visits = [0]
  dae_collect_parameter_forwarding_dependencies_instrs(
    body,
    0,
    mod_,
    1,
    0,
    graph.snapshot.type_indices,
    graph.function_epochs,
    edges,
    callers,
    visits=Some(visits),
  )
  assert_eq(edges.length(), 0)
  assert_eq(callers, [[], []])
  let dependencies = dae_boundary_dependency_graph_new(graph)
  assert_true(dependencies.callers_by_def[0].contains(1))
  assert_true(dependencies.result_observers_by_def[0].contains(1))
  assert_eq(visits[0], 0)
}

///|
test "dae forwarding analysis still records nested parameter reads" {
  let mod_ = pass_test_module_from_wat(
    "(module (func $helper (param i32) (result i32) local.get 0) (func (export \"run\") (param i32) (result i32) block (result i32) local.get 0 call $helper end))",
  )
  let graph = dae_current_boundary_graph_new(mod_)
  let @lib.Func(_, @lib.Expr(body)) = graph.snapshot.funcs[1]
  let edges : Array[DaeParameterForwardingEdge] = []
  let callers = dae_dependency_adjacency_new(2)
  dae_collect_parameter_forwarding_dependencies_instrs(
    body,
    0,
    mod_,
    1,
    1,
    graph.snapshot.type_indices,
    graph.function_epochs,
    edges,
    callers,
  )
  assert_eq(edges.length(), 1)
  assert_eq(edges[0].caller_def, 1)
  assert_eq(edges[0].caller_param_idx, 0)
  assert_eq(edges[0].callee_def, 0)
  assert_eq(edges[0].callee_param_idx, 0)
  assert_eq(callers, [[1], []])
}
