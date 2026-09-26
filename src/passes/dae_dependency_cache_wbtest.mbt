///|
test "dae dependency cache preserves edges and invalidates on body and signature refresh" {
  let first_module = pass_test_module_from_wat(
    "(module (func $f (param i32) (result i32) local.get 0) (func (param i32) (result i32) local.get 0 call $f))",
  )
  let graph = dae_current_boundary_graph_new(first_module)
  let builds = [0]
  for _ in 0..<3 {
    let dependencies = dae_boundary_dependency_graph_new(
      graph,
      builds=Some(builds),
    )
    assert_eq(dependencies.callers_by_def[0], [1])
    assert_eq(dependencies.parameter_forwarding_edges.length(), 1)
    assert_eq(
      dependencies.parameter_forwarding_edges[0].source_type,
      @lib.ValType::i32(),
    )
  }
  assert_eq(builds[0], 1)
  let constant_module = pass_test_module_from_wat(
    "(module (func $f (param i32) (result i32) local.get 0) (func (param i32) (result i32) i32.const 7 call $f))",
  )
  dae_current_boundary_graph_refresh(graph, constant_module)
  let dependencies = dae_boundary_dependency_graph_new(
    graph,
    builds=Some(builds),
  )
  assert_eq(dependencies.callers_by_def[0], [1])
  assert_eq(dependencies.parameter_forwarding_edges.length(), 0)
  assert_eq(builds[0], 2)
  let wide_module = pass_test_module_from_wat(
    "(module (func $f (param i64) (result i64) local.get 0) (func (param i64) (result i64) local.get 0 call $f))",
  )
  dae_current_boundary_graph_refresh(graph, wide_module)
  let dependencies = dae_boundary_dependency_graph_new(
    graph,
    builds=Some(builds),
  )
  assert_eq(dependencies.parameter_forwarding_edges.length(), 1)
  assert_eq(
    dependencies.parameter_forwarding_edges[0].source_type,
    @lib.ValType::i64(),
  )
  assert_eq(builds[0], 3)
}

///|
test "dae lightweight parameter adoption discards cached forwarding edges" {
  let graph = dae_forwarding_facts_fixture(1)
  assert_eq(
    dae_boundary_dependency_graph_new(graph).parameter_forwarding_edges.length(),
    1,
  )
  let rewritten = pass_test_module_from_wat(
    "(module (func $h0 (result i32) i32.const 7) (func (export \"run\") (param i32) call $h0 drop call $h0 drop))",
  )
  assert_true(
    dae_current_boundary_graph_adopt_parameter_batch_lightweight(
      graph, rewritten,
    ),
  )
  let dependencies = dae_boundary_dependency_graph_new(graph)
  assert_eq(dependencies.parameter_forwarding_edges.length(), 0)
  assert_eq(dependencies.callers_by_def[0], [1])
}
