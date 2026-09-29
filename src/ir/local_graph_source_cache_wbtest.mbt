///|
test "reverse query cache shares completed immutable rows and isolates later merges" {
  let (func, _, _) = local_graph_query_fixture(1, 2)
  let cfg = cfg_build(func, expand_operand_control=true)
  let actions = local_graph_reverse_action_sequences(func, cfg)
  let writes = local_graph_build_write_local_ids(func)
  let transparent = local_graph_reverse_transparent_predecessors(
    writes, cfg, actions, true,
  )
  let cache : Array[@hashmap.HashMap[Int, Array[Int]]?] = Array::make(
    cfg_block_count(cfg),
    None,
  )
  let last_writes : Array[@hashmap.HashMap[Int, NodeId]?] = Array::make(
    cfg_block_count(cfg),
    None,
  )
  let seen = Array::make(cfg_block_count(cfg), false)
  let visited : Array[BlockId] = []
  let work : Array[BlockId] = []
  let block = cfg_entry_block(cfg)
  let first = local_graph_reverse_entry_sources(
    writes, cfg, actions, transparent, block, 1, true, cache, last_writes, seen,
    visited, work, 2,
  )
  let second = local_graph_reverse_entry_sources(
    writes, cfg, actions, transparent, block, 1, true, cache, last_writes, seen,
    visited, work, 2,
  )
  let cached = cache[block].unwrap().get(1).unwrap()
  assert_eq(first, [local_graph_entry_source_id(1)])
  assert_true(physical_equal(first, cached))
  assert_true(physical_equal(second, cached))
  let rows : Array[Array[Int]] = [[], []]
  let recorder = LocalGraphSourceRecorder::new(rows)
  recorder.record(0, first)
  recorder.record(1, second)
  recorder.record(0, [local_graph_set_source_id(2, 0)])
  assert_eq(rows[0], [1, 2])
  assert_eq(rows[1], [1])
  assert_eq(cached, [1])
}
