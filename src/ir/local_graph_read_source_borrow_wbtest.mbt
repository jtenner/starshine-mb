///|
test "small owned source rows reserve space for subsequent observations" {
  let rows : Array[Array[Int]] = [[]]
  let recorder = LocalGraphSourceRecorder::new(rows)
  let source = [0]
  recorder.record(0, source)
  recorder.record(0, [1])
  let capacity = rows[0].capacity()
  assert_eq(rows[0], [0, 1])
  assert_eq(source, [0])
  assert_true(capacity >= 4)
  recorder.record(0, [2])
  recorder.record(0, [3])
  assert_eq(rows[0], [0, 1, 2, 3])
  assert_eq(source, [0])
  assert_eq(rows[0].capacity(), capacity)
}

///|
test "local flow records immutable reaching sources without copying their rows" {
  let sources = [0, 5]
  let gets : Array[Array[Int]] = Array::makei(6, fn(_) { [] })
  let recorder = LocalGraphSourceRecorder::new(gets)
  let influences : Array[Array[NodeId]] = Array::makei(6, fn(_) { [] })
  local_graph_record_get_sources(
    2,
    0,
    sources,
    Some(recorder),
    Some(influences),
  )
  assert_eq(gets[0], [0, 5])
  assert_eq(influences[3], [0])
  assert_true(physical_equal(gets[0], sources))
  local_graph_record_get_sources(
    2,
    1,
    sources,
    Some(recorder),
    Some(influences),
  )
  assert_eq(influences[3], [0, 1])
  assert_true(physical_equal(gets[1], sources))
  local_graph_record_get_sources(2, 0, [4, 5], Some(recorder), Some(influences))
  assert_eq(gets[0], [0, 5, 4])
  assert_eq(gets[1], [0, 5])
  assert_eq(sources, [0, 5])
  assert_eq(influences[2], [0])
  assert_eq(influences[3], [0, 1])
  let extended = gets[0]
  local_graph_record_get_sources(2, 0, [7], Some(recorder), Some(influences))
  assert_eq(gets[0], [0, 5, 4, 7])
  assert_eq(gets[1], [0, 5])
  assert_eq(sources, [0, 5])
  assert_eq(influences[5], [0])
  assert_true(physical_equal(gets[0], extended))
  // One privately extended row does not need a node-sized ownership bitmap.
  assert_true(recorder.owned is None)
  local_graph_record_get_sources(2, 1, [6], Some(recorder), Some(influences))
  let second_extended = gets[1]
  local_graph_record_get_sources(2, 1, [7], Some(recorder), Some(influences))
  assert_eq(gets[0], [0, 5, 4, 7])
  assert_eq(gets[1], [0, 5, 6, 7])
  assert_eq(sources, [0, 5])
  assert_true(physical_equal(gets[1], second_extended))
}

///|
test "local flow builders share empty source rows without exposing mutable queries" {
  let module_ = @wast.wast_to_binary_module(
    "(module (func (param i32) local.get 0 drop i32.const 7 drop))",
  ).unwrap()
  let func = hot_lift_func(module_, @lib.FuncIdx::new(0U))
  let cfg = cfg_build(func, expand_operand_control=true)
  for
    graph in [
      local_graph_build_with_exceptional_policy(func, cfg, false),
      local_graph_build_sparse_flow(func, cfg, false),
      local_graph_build_reverse_flow(func, cfg, false),
    ] {
    let empty_nodes : Array[NodeId] = []
    for node in 0..<hot_node_count(func) {
      if graph.get_source_ids[node].is_empty() {
        empty_nodes.push(node)
      }
    }
    assert_true(empty_nodes.length() >= 2)
    let first = empty_nodes[0]
    let second = empty_nodes[1]
    let query = local_graph_reaching_sources_for_get(graph, first)
    query.push(HotLocalGraphSource::SetSource(0))
    assert_eq(local_graph_reaching_sources_for_get(graph, first), [])
    assert_eq(local_graph_reaching_sources_for_get(graph, second), [])
    assert_true(
      physical_equal(graph.get_source_ids[first], graph.get_source_ids[second]),
    )
  }
}

///|
test "local flow cleared symbolic rows lose their previous ownership" {
  let rows : Array[Array[Int]] = [[], []]
  let recorder = LocalGraphSourceRecorder::new(rows)
  recorder.record(0, [-1])
  recorder.record(0, [-2])
  let symbolic = rows[0]
  rows[0] = []
  let resolved = [3, 5]
  recorder.record(0, resolved)
  recorder.record(1, resolved)
  recorder.record(0, [7])
  assert_eq(symbolic, [-1, -2])
  assert_eq(resolved, [3, 5])
  assert_eq(rows[1], [3, 5])
  assert_eq(rows[0], [3, 5, 7])
  let extended = rows[0]
  recorder.record(0, [9])
  assert_eq(rows[0], [3, 5, 7, 9])
  assert_true(physical_equal(rows[0], extended))
}

///|
test "local flow public source queries remain owned when reads share a definition" {
  let module_ = @wast.wast_to_binary_module(
    "(module (func (param i32) (result i32) (local i32) local.get 0 local.set 1 local.get 1 local.get 1 i32.add))",
  ).unwrap()
  let func = hot_lift_func(module_, @lib.FuncIdx::new(0U))
  let graph = local_graph_build_full_flow(
    func,
    cfg_build(func, expand_operand_control=true),
  )
  let reads : Array[NodeId] = []
  let mut write = HOT_NONE_NODE
  for node in 0..<hot_node_count(func) {
    let data = hot_node_get(func, node)
    if data.op is HotOp::LocalSet && data.imm0 == 1 {
      write = node
    }
    if data.op is HotOp::LocalGet && data.imm0 == 1 {
      reads.push(node)
    }
  }
  assert_eq(reads.length(), 2)
  assert_true(write >= 0)
  let first = local_graph_reaching_sources_for_get(graph, reads[0])
  assert_eq(first, [HotLocalGraphSource::SetSource(write)])
  first.clear()
  assert_eq(local_graph_reaching_sources_for_get(graph, reads[0]), [
    HotLocalGraphSource::SetSource(write),
  ])
  assert_eq(local_graph_reaching_sources_for_get(graph, reads[1]), [
    HotLocalGraphSource::SetSource(write),
  ])
}
