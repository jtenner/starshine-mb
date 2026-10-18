///|
test "reverse sources query each visited nonroot predecessor only once" {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let read = hot_build_local_get(func, 0)
  let builder = cfg_builder_new(func, true, true)
  let entry = cfg_builder_add_block(builder, [], true)
  builder.cfg.entry_block = entry
  let query = cfg_builder_add_block(builder, [read], false)
  // Parallel ordinary and exceptional edges converge on the same entry.
  // A visited predecessor must still count as a predecessor, including when
  // it is skipped, so a closed cycle cannot invent an entry source.
  for _ in 0..<8 {
    cfg_builder_add_edge(builder, entry, query, CfgEdgeKind::BranchEdge)
    cfg_builder_add_edge(builder, entry, query, CfgEdgeKind::ExceptionalEdge)
  }
  for exceptional in [false, true] {
    let cfg = builder.cfg
    let actions = local_graph_reverse_action_sequences(func, cfg)
    let writes = local_graph_build_write_local_ids(func)
    let transparent = local_graph_reverse_transparent_predecessors(
      writes, cfg, actions, exceptional,
    )
    let count = cfg_block_count(cfg)
    let seen = Array::make(count, false)
    let visited : Array[BlockId] = []
    let work : Array[BlockId] = []
    let queries = [0]
    let actual = local_graph_reverse_entry_sources_impl(
      writes,
      cfg,
      actions,
      transparent,
      query,
      0,
      exceptional,
      Array::make(count, None),
      Array::make(count, None),
      seen,
      visited,
      work,
      1,
      None,
      None,
      None,
      predecessor_queries=Some(queries),
    )
    assert_eq(actual, [0])
    assert_eq(
      actual,
      source_union_compare_query(func, cfg, query, 0, exceptional, false, None),
    )
    assert_eq(seen, Array::make(count, false))
    assert_eq(visited, [])
    assert_eq(work, [])
    // Resource regression after the complete ordered-row and reset checks.
    assert_eq(queries[0], 1)
  }
}
