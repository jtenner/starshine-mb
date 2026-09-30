///|
fn source_union_perf_run(it : @bench.T, writers : Int, original : Bool) -> Unit {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let read = hot_build_local_get(func, 0)
  let writer_nodes = Array::makei(writers, fn(index) {
    hot_build_local_set(func, 0, hot_build_const_i32(func, @lib.I32(index)))
  })
  let builder = cfg_builder_new(func, true, true)
  let entry = cfg_builder_add_block(builder, [], true)
  builder.cfg.entry_block = entry
  let query = cfg_builder_add_block(builder, [read], false)
  cfg_builder_add_edge(builder, entry, query, CfgEdgeKind::FallthroughEdge)
  for write in writer_nodes {
    let block = cfg_builder_add_block(builder, [write], false)
    cfg_builder_add_edge(builder, entry, block, CfgEdgeKind::FallthroughEdge)
    cfg_builder_add_edge(builder, block, query, CfgEdgeKind::FallthroughEdge)
    cfg_builder_add_edge(builder, block, query, CfgEdgeKind::ExceptionalEdge)
  }
  builder.cfg.exit_block = query
  cfg_verify(builder.cfg)
  let cfg = builder.cfg
  let actions = local_graph_reverse_action_sequences(func, cfg)
  let writes = local_graph_build_write_local_ids(func)
  let owners = Array::make(hot_node_count(func), -1)
  for block, nodes in actions {
    for node in nodes {
      owners[node] = block
    }
  }
  let transparent = local_graph_reverse_transparent_predecessors(
    writes, cfg, actions, true,
  )
  let count = cfg_block_count(cfg)
  let cache : Array[@hashmap.HashMap[Int, Array[Int]]?] = Array::make(
    count,
    None,
  )
  let indices : Array[@hashmap.HashMap[Int, NodeId]?] = Array::make(count, None)
  let seen = Array::make(count, false)
  let visited : Array[BlockId] = []
  let work : Array[BlockId] = []
  it.bench(fn() {
    // Force a fresh complete query; warm immutable rows must not hide union work.
    cache[query] = None
    it.keep(
      if original {
        source_union_reference_entry_sources(
          writes, cfg, actions, transparent, query, 0, true, cache, indices, seen,
          visited, work, 1,
        )
      } else {
        local_graph_reverse_entry_sources_impl(
          writes,
          cfg,
          actions,
          transparent,
          query,
          0,
          true,
          cache,
          indices,
          seen,
          visited,
          work,
          1,
          Some(owners),
          None,
          None,
        )
      },
    )
  })
}

///|
test "bench reverse source union writers=1 search" (it : @bench.T) {
  source_union_perf_run(it, 1, true)
}

///|
test "bench reverse source union writers=1 visited" (it : @bench.T) {
  source_union_perf_run(it, 1, false)
}

///|
test "bench reverse source union writers=8 search" (it : @bench.T) {
  source_union_perf_run(it, 8, true)
}

///|
test "bench reverse source union writers=8 visited" (it : @bench.T) {
  source_union_perf_run(it, 8, false)
}

///|
test "bench reverse source union writers=128 search" (it : @bench.T) {
  source_union_perf_run(it, 128, true)
}

///|
test "bench reverse source union writers=128 visited" (it : @bench.T) {
  source_union_perf_run(it, 128, false)
}

///|
test "bench reverse source union writers=2048 search" (it : @bench.T) {
  source_union_perf_run(it, 2048, true)
}

///|
test "bench reverse source union writers=2048 visited" (it : @bench.T) {
  source_union_perf_run(it, 2048, false)
}
