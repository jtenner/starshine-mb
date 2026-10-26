///|
// Deliberately omit roots: these live nodes have no represented CFG source.
// The required fallback retains all definitions of the selected local.
fn dae2_fallback_hub_fixture(
  reads : Int32,
  writes : Int32,
  body_locals~ : Int32 = 1,
  tee_writes~ : Bool = false,
) -> @ir.HotFunc {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=Array::make(4, @lib.ValType::i32())),
  )
  let body_local = @ir.hot_append_body_local(func, @lib.ValType::i32())
  for _ in 1..<body_locals {
    ignore(@ir.hot_append_body_local(func, @lib.ValType::i32()))
  }
  for _ in 0..<writes {
    ignore(@ir.hot_build_local_set(func, 0, @ir.hot_build_local_get(func, 1)))
    let source = @ir.hot_build_local_get(func, 2)
    ignore(
      if tee_writes {
        @ir.hot_build_local_tee(func, body_local, source)
      } else {
        @ir.hot_build_local_set(func, body_local, source)
      },
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
fn dae2_fallback_assert_matches_reference(func : @ir.HotFunc) -> Unit raise {
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
test "dae2 intentionally unrepresented read demand matches conservative direct edges" {
  for body_locals in [1, 128] {
    for tee_writes in [false, true] {
      dae2_fallback_assert_matches_reference(
        dae2_fallback_hub_fixture(3, 2, body_locals~, tee_writes~),
      )
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

///|
test "dae2 fallback buckets share only empty rows and preserve writer order" {
  let func = dae2_fallback_hub_fixture(3, 2, body_locals=128, tee_writes=true)
  let count = @ir.hot_node_count(func)
  let buckets = dae2_fallback_write_buckets(func, count)
  assert_eq(buckets.length(), 132)
  assert_eq(buckets[0], [1, 5])
  assert_eq(buckets[4], [3, 7])
  assert_false(physical_equal(buckets[0], buckets[4]))
  for local in 0..<buckets.length() {
    if local != 0 && local != 4 {
      assert_eq(buckets[local], [])
      assert_true(physical_equal(buckets[local], buckets[1]))
    }
  }
  // A second census owns both its outer array and all mutable writer rows.
  let next = dae2_fallback_write_buckets(func, count)
  assert_false(physical_equal(buckets, next))
  assert_false(physical_equal(buckets[0], next[0]))
  assert_false(physical_equal(buckets[4], next[4]))
}

///|
test "dae2 dense fallback writes preserve independent local demand" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=Array::make(4, @lib.ValType::i32())),
  )
  for _ in 0..<4 {
    ignore(@ir.hot_append_body_local(func, @lib.ValType::i32()))
  }
  for local in 0..<8 {
    ignore(
      @ir.hot_build_local_set(func, local, @ir.hot_build_local_get(func, 1)),
    )
    ignore(
      @ir.hot_build_local_tee(func, local, @ir.hot_build_local_get(func, 2)),
    )
  }
  let reads = Array::makei(8, fn(local) { @ir.hot_build_local_get(func, local) })
  let buckets = dae2_fallback_write_buckets(func, @ir.hot_node_count(func))
  for local in 0..<8 {
    assert_eq(buckets[local], [local * 4 + 1, local * 4 + 3])
    let actual = Dae2Graph::new()
    let reference = Dae2Graph::new()
    let params = Array::make(4, @lib.ValType::i32())
    let info = Dae2Function::new(actual, params, [])
    let expected = Dae2Function::new(reference, params, [])
    info.assign_node_locations(actual, @ir.hot_node_count(func))
    expected.assign_node_locations(reference, @ir.hot_node_count(func))
    let original_locations = actual.used.length()
    let builds = [0]
    dae2_analyze_function(
      actual,
      [info],
      0,
      [],
      func,
      fallback_write_builds=Some(builds),
    )
    assert_eq(builds[0], 1)
    dae2_fallback_direct_reference(reference, expected, func)
    actual.observe(dae2_node_location(info, reads[local]))
    reference.observe(dae2_node_location(expected, reads[local]))
    actual.solve()
    reference.solve()
    for location in 0..<original_locations {
      assert_eq(actual.used[location], reference.used[location])
    }
  }
}

///|
test "dae2 wide locals without unresolved reads build no fallback buckets" {
  let func = dae2_fallback_hub_fixture(0, 2, body_locals=128, tee_writes=true)
  let graph = Dae2Graph::new()
  let info = Dae2Function::new(graph, Array::make(4, @lib.ValType::i32()), [])
  info.assign_node_locations(graph, @ir.hot_node_count(func))
  let builds = [0]
  dae2_analyze_function(
    graph,
    [info],
    0,
    [],
    func,
    fallback_write_builds=Some(builds),
  )
  graph.observe(dae2_node_location(info, 3))
  graph.solve()
  assert_true(graph.used[info.param_locations[2]])
  assert_false(graph.used[info.param_locations[0]])
  assert_false(graph.used[info.param_locations[1]])
  assert_false(graph.used[info.param_locations[3]])
  assert_eq(builds[0], 0)
}
