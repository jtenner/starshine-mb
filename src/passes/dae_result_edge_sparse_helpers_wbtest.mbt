///|
fn dae_result_edge_sparse_assert_equal(
  actual : DaeBoundaryDependencyGraph,
  expected : DaeBoundaryDependencyGraph,
) -> Unit raise {
  assert_eq(actual.callers_by_def, expected.callers_by_def)
  assert_eq(actual.callees_by_def, expected.callees_by_def)
  assert_eq(actual.return_callers_by_def, expected.return_callers_by_def)
  assert_eq(
    actual.parameter_forwarding_edges,
    expected.parameter_forwarding_edges,
  )
  assert_eq(
    actual.parameter_forwarders_by_def,
    expected.parameter_forwarders_by_def,
  )
  assert_eq(
    actual.uniform_value_forwarders_by_def,
    expected.uniform_value_forwarders_by_def,
  )
  assert_eq(actual.result_forwarders_by_def, expected.result_forwarders_by_def)
  assert_eq(
    actual.result_dependencies_by_def,
    expected.result_dependencies_by_def,
  )
  assert_eq(actual.result_observers_by_def, expected.result_observers_by_def)
  assert_eq(
    actual.tail_result_dependencies_by_def,
    expected.tail_result_dependencies_by_def,
  )
  assert_eq(actual.type_dependencies_by_def, expected.type_dependencies_by_def)
  assert_eq(
    actual.body_use_dependencies_by_def,
    expected.body_use_dependencies_by_def,
  )
  assert_eq(
    actual.nested_cleanup_dependencies_by_def,
    expected.nested_cleanup_dependencies_by_def,
  )
  assert_eq(actual.component_by_def, expected.component_by_def)
  assert_eq(actual.component_members, expected.component_members)
  assert_eq(
    actual.forwarding_component_by_def,
    expected.forwarding_component_by_def,
  )
  assert_eq(
    actual.forwarding_component_members,
    expected.forwarding_component_members,
  )
}

///|
fn dae_result_edge_sparse_fixture(width : Int32, mode : Int32) -> @lib.Module {
  if mode == 4 {
    return dae_result_edge_sparse_many_callees_fixture(width)
  }
  let text = StringBuilder::new()
  text.write_string("(module (import \"m\" \"mark\" (func $mark)) ")
  text.write_string(
    "(func $target (param i32) (result i32) local.get 0 i32.const 1 i32.add) ",
  )
  let idle = if mode == 0 || mode == 3 { width } else { 8 }
  for _ in 0..<idle {
    text.write_string("(func) ")
  }
  text.write_string("(func (export \"run\") (result i32) (local i32) ")
  let sites = if mode == 3 { 1 } else { width }
  for index in 0..<sites {
    text.write_string("call $mark ")
    if mode == 0 || (mode == 2 && index % 2 == 0) {
      text.write_string("i32.const 7 call $target drop ")
    } else {
      text.write_string("block i32.const 7 call $target local.set 0 end ")
    }
  }
  if mode == 0 {
    text.write_string("i32.const 8))")
  } else {
    text.write_string("i32.const 7 return_call $target))")
  }
  pass_test_module_from_wat(text.to_string())
}

///|
fn dae_result_edge_sparse_round(
  input : @lib.Module,
  reference : Bool,
) -> DaeCoreResultApplication raise {
  let graph = dae_current_boundary_graph_new(input)
  let dependencies = if reference {
    dae_result_edge_sparse_reference(graph)
  } else {
    dae_boundary_dependency_graph_build(graph)
  }
  let item = dae_work_item_new(graph, dependencies, 0, DaeUniformActualWork)
  match
    dae_process_work_item(
      dae_collect_original_boundary_snapshot(input),
      input,
      [],
      false,
      graph,
      dependencies,
      item,
      dae_diagnostics_new(),
    ) {
    DaeWorkCommitted(application) => application
    _ => fail("the graph control must reach an active scalar rewrite")
  }
}

///|
fn dae_result_edge_sparse_check(input : @lib.Module) -> Unit raise {
  let saved = @binary.encode_module(input).unwrap()
  @validate.validate_module(input).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  let actual = dae_boundary_dependency_graph_build(graph)
  let expected = dae_result_edge_sparse_reference(graph)
  dae_result_edge_sparse_assert_equal(actual, expected)
  let again = dae_boundary_dependency_graph_build(graph)
  dae_result_edge_sparse_assert_equal(again, expected)
  // Every graph row is owned by its build, including rows copied for other domains.
  if actual.result_forwarders_by_def.length() > 0 {
    actual.result_forwarders_by_def[0].push(-99)
    dae_result_edge_sparse_assert_equal(again, expected)
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
fn dae_result_edge_sparse_many_callees_fixture(width : Int32) -> @lib.Module {
  let text = StringBuilder::new()
  text.write_string("(module (import \"m\" \"mark\" (func $mark)) ")
  for index in 0..<width {
    text.write_string(
      "(func $t\{index} (param i32) (result i32) local.get 0 i32.const 1 i32.add) ",
    )
  }
  text.write_string("(func (export \"run\") (result i32) (local i32) ")
  for index in 0..<width {
    text.write_string("call $mark i32.const 7 call $t\{index} local.set 0 ")
  }
  text.write_string("i32.const 7 return_call $t0))")
  pass_test_module_from_wat(text.to_string())
}
