///|
// Deliberately omit roots: these live nodes have no represented CFG source.
// The required fallback retains all definitions of the selected local.
fn dae2_fallback_hub_fixture(reads : Int32, writes : Int32) -> @ir.HotFunc {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=Array::make(4, @lib.ValType::i32())),
  )
  let body_local = @ir.hot_append_body_local(func, @lib.ValType::i32())
  for _ in 0..<writes {
    ignore(@ir.hot_build_local_set(func, 0, @ir.hot_build_local_get(func, 1)))
    ignore(
      @ir.hot_build_local_set(
        func,
        body_local,
        @ir.hot_build_local_get(func, 2),
      ),
    )
  }
  for _ in 0..<reads {
    ignore(@ir.hot_build_local_get(func, 0))
    ignore(@ir.hot_build_local_get(func, body_local))
  }
  func
}

///|
// Independent direct-edge reference for this local-only, rootless fixture.
fn dae2_fallback_direct_reference(
  graph : Dae2Graph,
  info : Dae2Function,
  func : @ir.HotFunc,
) -> Unit {
  for node in 0..<info.node_count {
    let data = @ir.hot_node_get(func, node)
    let value = dae2_node_location(info, node)
    match data.op {
      @ir.LocalGet => {
        if data.imm0 < info.params.length() {
          graph.edge(value, info.param_locations[data.imm0])
        }
        for write in 0..<info.node_count {
          let writer = @ir.hot_node_get(func, write)
          if (writer.op is @ir.LocalSet || writer.op is @ir.LocalTee) &&
            writer.imm0 == data.imm0 {
            graph.edge(value, dae2_node_location(info, write))
          }
        }
      }
      @ir.LocalSet | @ir.LocalTee =>
        graph.edge(
          value,
          dae2_node_location(info, @ir.hot_child_get(func, node, 0)),
        )
      _ => abort("fallback fixture contains an unexpected opcode")
    }
  }
}

///|
test "dae2 intentionally unrepresented read demand matches conservative direct edges" {
  let func = dae2_fallback_hub_fixture(3, 2)
  let count = @ir.hot_node_count(func)
  // Include no demand, a writer, both local families, and combined demand.
  for seeds in [[], [1], [count - 2], [count - 1], [count - 2, count - 1]] {
    let actual = Dae2Graph::new()
    let reference = Dae2Graph::new()
    let params = Array::make(4, @lib.ValType::i32())
    let info = Dae2Function::new(actual, params, [])
    let expected_info = Dae2Function::new(reference, params, [])
    info.assign_node_locations(actual, count)
    expected_info.assign_node_locations(reference, count)
    let original_locations = actual.used.length()
    dae2_analyze_function(actual, [info], 0, [], func)
    dae2_fallback_direct_reference(reference, expected_info, func)
    for node in seeds {
      actual.observe(dae2_node_location(info, node))
      reference.observe(dae2_node_location(expected_info, node))
    }
    actual.solve()
    reference.solve()
    for location in 0..<original_locations {
      assert_eq(actual.used[location], reference.used[location])
    }
    // A hub for one local must not retain another local's definitions.
    assert_false(actual.used[info.param_locations[3]])
    if seeds == [count - 2] {
      assert_true(actual.used[info.param_locations[0]])
      assert_true(actual.used[info.param_locations[1]])
      assert_false(actual.used[info.param_locations[2]])
    }
    if seeds == [count - 1] {
      assert_false(actual.used[info.param_locations[0]])
      assert_false(actual.used[info.param_locations[1]])
      assert_true(actual.used[info.param_locations[2]])
    }
  }
}

///|
test "dae2 intentionally unrepresented read demand uses linear fallback edges" {
  let reads = 16
  let writes = 12
  let func = dae2_fallback_hub_fixture(reads, writes)
  let graph = Dae2Graph::new()
  let info = Dae2Function::new(graph, Array::make(4, @lib.ValType::i32()), [])
  info.assign_node_locations(graph, @ir.hot_node_count(func))
  dae2_analyze_function(graph, [info], 0, [], func)
  let last = @ir.hot_node_count(func) - 1
  graph.observe(dae2_node_location(info, last))
  graph.solve()
  assert_true(graph.used[info.param_locations[2]])
  assert_false(graph.used[info.param_locations[0]])
  assert_false(graph.used[info.param_locations[1]])
  assert_false(graph.used[info.param_locations[3]])
  assert_true(graph.edges.length() <= 2 * reads + 6 * writes + 2)
}
