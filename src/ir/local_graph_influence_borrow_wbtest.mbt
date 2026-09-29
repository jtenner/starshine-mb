///|
test "local influence rows allocate only when a write gets its first observer" {
  let (func, writes, reads) = local_graph_query_fixture(2, 2)
  let rows = local_graph_empty_influences(func)
  let empty = rows[0]
  for row in rows {
    assert_true(physical_equal(row, empty))
  }
  local_graph_record_get_sources(2, reads[0], [2 + writes[0]], None, Some(rows))
  let first = rows[writes[0]]
  local_graph_record_get_sources(
    2,
    reads[1],
    [2 + writes[0], 2 + writes[1]],
    None,
    Some(rows),
  )
  local_graph_record_get_sources(2, reads[0], [2 + writes[0]], None, Some(rows))
  assert_eq(rows[writes[0]], [reads[0], reads[1]])
  assert_eq(rows[writes[1]], [reads[1]])
  assert_true(physical_equal(first, rows[writes[0]]))
  assert_false(physical_equal(first, rows[writes[1]]))
  assert_eq(empty, [])
  assert_eq(rows[reads[0]], [])
  assert_true(physical_equal(rows[reads[0]], empty))
}

///|
test "local influence builders retain independent owned public queries" {
  let (func, writes, reads) = local_graph_query_fixture(2, 2)
  let cfg = cfg_build(func, expand_operand_control=true)
  for
    graph in [
      local_graph_build_with_exceptional_policy(func, cfg, true),
      local_graph_build_reverse_flow(func, cfg, true),
      local_graph_build_sparse_flow(func, cfg, true),
    ] {
    for index in 0..<2 {
      assert_eq(local_graph_influenced_gets_for_write(graph, writes[index]), [
        reads[index],
      ])
      assert_eq(local_graph_reaching_sources_for_get(graph, reads[index]), [
        SetSource(writes[index]),
      ])
    }
    let query = local_graph_influenced_gets_for_write(graph, writes[0])
    query.clear()
    assert_eq(local_graph_influenced_gets_for_write(graph, writes[0]), [
      reads[0],
    ])
    assert_eq(local_graph_influenced_gets_for_write(graph, writes[1]), [
      reads[1],
    ])
    assert_true(
      physical_equal(
        graph.set_influence_gets[reads[0]],
        graph.set_influence_gets[reads[1]],
      ),
    )
  }
}
