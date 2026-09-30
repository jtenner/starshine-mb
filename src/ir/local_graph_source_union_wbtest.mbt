///|
fn source_union_compare_query(
  func : HotFunc,
  cfg : HotCfg,
  block : BlockId,
  local : LocalId,
  exceptional : Bool,
  unique : Bool,
  membership : Array[Int]?,
) -> Array[Int] raise {
  let actions = local_graph_reverse_action_sequences(func, cfg)
  let writes = local_graph_build_write_local_ids(func)
  let transparent = local_graph_reverse_transparent_predecessors(
    writes, cfg, actions, exceptional,
  )
  let writer_blocks = if unique {
    let owners = Array::make(hot_node_count(func), -1)
    for block_id, nodes in actions {
      for node_id in nodes {
        assert_eq(owners[node_id], -1)
        owners[node_id] = block_id
      }
    }
    Some(owners)
  } else {
    None
  }
  let count = cfg_block_count(cfg)
  let cache : Array[@hashmap.HashMap[Int, Array[Int]]?] = Array::make(
    count,
    None,
  )
  let indices : Array[@hashmap.HashMap[Int, NodeId]?] = Array::make(count, None)
  let seen = Array::make(count, false)
  let visited : Array[BlockId] = []
  let work : Array[BlockId] = []
  let result = local_graph_reverse_entry_sources_impl(
    writes,
    cfg,
    actions,
    transparent,
    block,
    local,
    exceptional,
    cache,
    indices,
    seen,
    visited,
    work,
    hot_local_count(func),
    writer_blocks,
    membership,
    None,
  )
  assert_eq(seen, Array::make(count, false))
  assert_eq(visited, [])
  assert_eq(work, [])
  let original_cache : Array[@hashmap.HashMap[Int, Array[Int]]?] = Array::make(
    count,
    None,
  )
  let original_indices : Array[@hashmap.HashMap[Int, NodeId]?] = Array::make(
    count,
    None,
  )
  let original = source_union_reference_entry_sources(
    writes,
    cfg,
    actions,
    transparent,
    block,
    local,
    exceptional,
    original_cache,
    original_indices,
    seen,
    visited,
    work,
    hot_local_count(func),
  )
  assert_eq(result, original)
  let later = local_graph_reverse_entry_sources_impl(
    writes,
    cfg,
    actions,
    transparent,
    block,
    local,
    exceptional,
    cache,
    indices,
    seen,
    visited,
    work,
    hot_local_count(func),
    writer_blocks,
    membership,
    None,
  )
  assert_true(physical_equal(result, later))
  result
}

///|
test "reverse writer visitation preserves rows with bounded tiny membership searches" {
  let (func, cfg, blocks, _) = local_graph_predecessor_cache_fixture(
    3,
    overwrite=true,
  )
  let membership = [0]
  let revision = hot_revision_current(func)
  let free = func.free_nodes.copy()
  for exceptional in [false, true] {
    for block in blocks {
      let sources = source_union_compare_query(
        func,
        cfg,
        block,
        0,
        exceptional,
        true,
        Some(membership),
      )
      assert_true(!sources.is_empty())
    }
  }
  assert_true(membership[0] <= 20)
  assert_eq(hot_revision_current(func), revision)
  assert_eq(func.free_nodes, free)
}

///|
test "reverse writer visitation retains the initial-block loop source and parallel edges" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  let read = hot_build_local_get(func, 0)
  let write = hot_build_local_tee(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  let builder = cfg_builder_new(func, true, true)
  let entry = cfg_builder_add_block(builder, [], true)
  builder.cfg.entry_block = entry
  let query = cfg_builder_add_block(builder, [read, write], false)
  cfg_builder_add_edge(builder, entry, query, CfgEdgeKind::FallthroughEdge)
  cfg_builder_add_edge(builder, query, query, CfgEdgeKind::BranchEdge)
  cfg_builder_add_edge(builder, query, query, CfgEdgeKind::ExceptionalEdge)
  for exceptional in [false, true] {
    let membership = [0]
    assert_eq(
      source_union_compare_query(
        func,
        builder.cfg,
        query,
        0,
        exceptional,
        true,
        Some(membership),
      ),
      [local_graph_set_source_id(2, write), local_graph_entry_source_id(0)],
    )
    assert_eq(
      source_union_compare_query(
        func,
        builder.cfg,
        query,
        1,
        exceptional,
        true,
        Some(membership),
      ),
      [local_graph_entry_source_id(1)],
    )
    assert_true(membership[0] <= 2)
  }
}

///|
test "unadmitted shared writer actions retain ordinary source union" {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let write = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  let read = hot_build_local_get(func, 0)
  let builder = cfg_builder_new(func, true, true)
  let entry = cfg_builder_add_block(builder, [], true)
  builder.cfg.entry_block = entry
  let left = cfg_builder_add_block(builder, [write], false)
  let right = cfg_builder_add_block(builder, [write], false)
  let query = cfg_builder_add_block(builder, [read], false)
  for block in [left, right] {
    cfg_builder_add_edge(builder, entry, block, CfgEdgeKind::FallthroughEdge)
    cfg_builder_add_edge(builder, block, query, CfgEdgeKind::FallthroughEdge)
  }
  let membership = [0]
  assert_eq(
    source_union_compare_query(
      func,
      builder.cfg,
      query,
      0,
      true,
      false,
      Some(membership),
    ),
    [local_graph_set_source_id(1, write)],
  )
  assert_true(membership[0] > 0)
  let projected = local_graph_build_full_flow(func, builder.cfg)
  let reference = source_union_reference_build_reverse_flow(
    func,
    builder.cfg,
    true,
  )
  assert_eq(projected, reference)
}

///|
test "reverse writer visitation retains complete public graph facts" {
  let (func, cfg, _, _) = local_graph_predecessor_cache_fixture(
    4,
    overwrite=true,
  )
  assert_eq(
    local_graph_build_full_flow(func, cfg),
    source_union_reference_build_reverse_flow(func, cfg, true),
  )
  let (func, cfg, blocks, _) = local_graph_predecessor_cache_fixture(4)
  for block in blocks {
    ignore(source_union_compare_query(func, cfg, block, 0, true, true, None))
  }
  assert_eq(
    local_graph_build_full_flow(func, cfg),
    source_union_reference_build_reverse_flow(func, cfg, true),
  )
}

///|
test "reverse writer visitation preserves real control source and influence rows" {
  let funcs = [
    cfg_segment_storage_fixture(4),
    local_graph_query_fixture(2, 3).0,
  ]
  for func in funcs {
    for expanded in [false, true] {
      let cfg = cfg_build(func, expand_operand_control=expanded)
      assert_eq(
        local_graph_build_full_flow(func, cfg),
        source_union_reference_build_reverse_flow(func, cfg, true),
      )
    }
  }
}

///|
fn source_union_reference_entry_sources(
  write_local_ids : Array[LocalId],
  cfg : HotCfg,
  actions : Array[Array[NodeId]],
  transparent_predecessors : Array[BlockId],
  block_id : BlockId,
  local_id : LocalId,
  include_exceptional : Bool,
  cache : Array[@hashmap.HashMap[Int, Array[Int]]?],
  last_writes : Array[@hashmap.HashMap[Int, NodeId]?],
  seen : Array[Bool],
  visited : Array[BlockId],
  work : Array[BlockId],
  local_count : Int,
  cache_slots? : Array[Int]? = None,
) -> Array[Int] {
  if cache[block_id] is Some(row) {
    if row.get(local_id) is Some(sources) {
      // Completed rows are immutable; readers either borrow or copy on write.
      return sources
    }
  }
  let sources : Array[Int] = []
  work.push(block_id)
  seen[block_id] = true
  visited.push(block_id)
  while !work.is_empty() {
    let current = work.pop().unwrap()
    let mut has_predecessor = false
    for edge in cfg_predecessor_edges(cfg, current) {
      if !include_exceptional && edge.kind == CfgEdgeKind::ExceptionalEdge {
        continue
      }
      has_predecessor = true
      let pred = transparent_predecessors[edge.block]
      match
        local_graph_reverse_indexed_last_write(
          write_local_ids, actions, pred, local_id, last_writes,
        ) {
        Some(write_id) => {
          let source_id = local_graph_set_source_id(local_count, write_id)
          if !local_graph_array_contains(sources, source_id) {
            sources.push(source_id)
          }
        }
        None =>
          if !seen[pred] {
            seen[pred] = true
            visited.push(pred)
            work.push(pred)
          }
      }
    }
    if !has_predecessor && current == cfg_entry_block(cfg) {
      let entry_source = local_graph_entry_source_id(local_id)
      if !local_graph_array_contains(sources, entry_source) {
        sources.push(entry_source)
      }
    }
  }
  for block in visited {
    seen[block] = false
  }
  visited.clear()
  let row = match cache[block_id] {
    Some(row) => row
    None => {
      let row = @hashmap.new()
      cache[block_id] = Some(row)
      row
    }
  }
  row.set(local_id, sources)
  match cache_slots {
    Some(count) => count[0] += 1
    None => ()
  }
  sources
}

///|
fn source_union_reference_build_reverse_flow(
  func : HotFunc,
  cfg : HotCfg,
  include_exceptional : Bool,
  cache_slots? : Array[Int]? = None,
) -> HotLocalGraph {
  let local_count = hot_local_count(func)
  let node_count = hot_node_count(func)
  // Reverse scans require a complete linear action list for every CFG block.
  // Nested branching operands have multiple paths and use the forward join.
  for block in cfg.blocks {
    if cfg.operands_expanded {
      // Operand control is represented by CFG edges rather than hidden in
      // a root's subtree, so every block already has a linear action list.
      break
    }
    for root in block.nodes {
      let data = hot_node_get(func, root)
      for slot = 0; slot < data.child_count; slot = slot + 1 {
        if !local_graph_is_region_slot(data, slot) &&
          !local_graph_nested_block_node_is_straight_line(
            func,
            hot_child_get(func, root, slot),
          ) {
          return local_graph_build_sparse_flow(func, cfg, include_exceptional)
        }
      }
    }
  }
  let actions = local_graph_reverse_action_sequences(func, cfg)
  let node_blocks = Array::make(node_count, -1)
  let nearest_writes = Array::make(node_count, -1)
  let last_writes = Array::make(local_count, -1)
  let written_anywhere = Array::make(local_count, false)
  let written_locals : Array[Int] = []
  for block_id = 0; block_id < actions.length(); block_id = block_id + 1 {
    for idx = 0; idx < actions[block_id].length(); idx = idx + 1 {
      let node_id = actions[block_id][idx]
      if node_id >= 0 && node_id < node_count {
        if node_blocks[node_id] >= 0 {
          // A shared expression can have several reaching contexts.
          return local_graph_build_sparse_flow(func, cfg, include_exceptional)
        }
        node_blocks[node_id] = block_id
        let node = hot_node_get(func, node_id)
        match node.op {
          HotOp::LocalSet | HotOp::LocalTee => {
            written_anywhere[node.imm0] = true
            if last_writes[node.imm0] < 0 {
              written_locals.push(node.imm0)
            }
            last_writes[node.imm0] = node_id
          }
          HotOp::LocalGet =>
            nearest_writes[node_id] = if last_writes[node.imm0] >= 0 {
              last_writes[node.imm0]
            } else {
              // Keep the local in the existing per-node scratch row. -1
              // remains a nonread; known writers retain their node IDs.
              -node.imm0 - 2
            }
          _ => ()
        }
      }
    }
    for local_id in written_locals {
      last_writes[local_id] = -1
    }
    written_locals.clear()
  }

  // The final graph already needs this immutable index. Reuse it for every
  // predecessor query instead of decoding the same node at each visit.
  let write_facts = local_graph_build_write_facts(func)
  let write_local_ids = write_facts.local_ids
  let transparent_predecessors = local_graph_reverse_transparent_predecessors(
    write_local_ids, cfg, actions, include_exceptional,
  )
  let get_sources : Array[Array[Int]] = Array::make(node_count, [])
  let write_influences = local_graph_empty_influences(func)
  let cache : Array[@hashmap.HashMap[Int, Array[Int]]?] = Array::make(
    cfg_block_count(cfg),
    None,
  )
  let block_writes : Array[@hashmap.HashMap[Int, NodeId]?] = Array::make(
    cfg_block_count(cfg),
    None,
  )
  let seen = Array::make(cfg_block_count(cfg), false)
  let visited : Array[BlockId] = []
  let work : Array[BlockId] = []
  let entry_rows : Array[Array[Int]] = Array::make(local_count, [])
  if written_anywhere.any(fn(written) { !written }) {
    let entry = cfg_entry_block(cfg)
    // Match the reverse query's exact origin rule: entry contributes only
    // when it has no admitted predecessors. Closed/unreachable cycles must
    // retain unknown rows rather than inventing an entry definition.
    let mut entry_origin = true
    for edge in cfg_predecessor_edges(cfg, entry) {
      if include_exceptional || edge.kind != CfgEdgeKind::ExceptionalEdge {
        entry_origin = false
        break
      }
    }
    if entry_origin {
      work.push(entry)
      seen[entry] = true
      visited.push(entry)
      while !work.is_empty() {
        let current = work.pop().unwrap()
        for node_id in actions[current] {
          let encoded = nearest_writes[node_id]
          if encoded <= -2 {
            let local_id = -encoded - 2
            if !written_anywhere[local_id] {
              // A disjoint negative range marks reachable immutable reads.
              nearest_writes[node_id] = encoded - local_count
            }
          }
        }
        for edge in cfg_successor_edges(cfg, current) {
          if !include_exceptional && edge.kind == CfgEdgeKind::ExceptionalEdge {
            continue
          }
          if !seen[edge.block] {
            seen[edge.block] = true
            visited.push(edge.block)
            work.push(edge.block)
          }
        }
      }
      for block in visited {
        seen[block] = false
      }
      visited.clear()
    }
  }
  match cache_slots {
    Some(count) => count[0] += cache.length()
    None => ()
  }
  for node_id = 0; node_id < node_count; node_id = node_id + 1 {
    if !hot_node_is_live(func, node_id) ||
      !(hot_node_get(func, node_id).op is HotOp::LocalGet) {
      continue
    }
    let block_id = node_blocks[node_id]
    if block_id < 0 {
      continue
    }
    let local_id = hot_node_get(func, node_id).imm0
    let write_id = nearest_writes[node_id]
    let sources = if write_id >= 0 {
      [local_graph_set_source_id(local_count, write_id)]
    } else if !written_anywhere[local_id] {
      if write_id <= -local_count - 2 {
        if entry_rows[local_id].is_empty() {
          entry_rows[local_id] = [local_graph_entry_source_id(local_id)]
        }
        // Source rows are immutable borrowed graph data, as with completed
        // reverse-cache rows. Share one entry row across this local's reads.
        entry_rows[local_id]
      } else {
        []
      }
    } else {
      source_union_reference_entry_sources(
        write_local_ids,
        cfg,
        actions,
        transparent_predecessors,
        block_id,
        local_id,
        include_exceptional,
        cache,
        block_writes,
        seen,
        visited,
        work,
        local_count,
        cache_slots~,
      )
    }
    local_graph_record_unique_get_sources(
      local_count, node_id, sources, get_sources, write_influences,
    )
  }
  {
    local_count,
    param_count: hot_param_count(func),
    get_source_ids: get_sources,
    set_influence_gets: write_influences,
    write_local_ids,
    write_is_tees: write_facts.is_tees,
    local_is_already_ssa: local_graph_build_local_already_ssa(
      func, local_count, get_sources,
    ),
    local_has_legal_default: local_graph_build_local_defaultability(
      func, local_count,
    ),
  }
}

///|
fn source_union_width_fixture(writers : Int) -> (HotFunc, HotCfg, BlockId) {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let read = hot_build_local_get(func, 0)
  let writes = Array::makei(writers, fn(index) {
    hot_build_local_set(func, 0, hot_build_const_i32(func, @lib.I32(index)))
  })
  let builder = cfg_builder_new(func, true, true)
  let entry = cfg_builder_add_block(builder, [], true)
  let query = cfg_builder_add_block(builder, [read], false)
  builder.cfg.entry_block = entry
  builder.cfg.exit_block = query
  cfg_builder_add_edge(builder, entry, query, CfgEdgeKind::FallthroughEdge)
  for write in writes {
    let block = cfg_builder_add_block(builder, [write], false)
    cfg_builder_add_edge(builder, entry, block, CfgEdgeKind::FallthroughEdge)
    cfg_builder_add_edge(builder, block, query, CfgEdgeKind::FallthroughEdge)
    cfg_builder_add_edge(builder, block, query, CfgEdgeKind::ExceptionalEdge)
  }
  cfg_verify(builder.cfg)
  (func, builder.cfg, query)
}

///|
test "tiny source rows preserve ordered sources without writer mark storage" {
  let (func, cfg, query) = source_union_width_fixture(1)
  let work = [0, 0]
  let sources = source_union_compare_query(
    func,
    cfg,
    query,
    0,
    true,
    true,
    Some(work),
  )
  assert_eq(sources.length(), 2)
  assert_eq(
    local_graph_build_full_flow(func, cfg),
    source_union_reference_build_reverse_flow(func, cfg, true),
  )
  // Count actual writer-mark writes and resets, excluding the ordinary walk.
  assert_eq(work[1], 0)
}

///|
test "wide source rows stop searching after the tiny-row limit" {
  let (func, cfg, query) = source_union_width_fixture(16)
  let work = [0, 0]
  let sources = source_union_compare_query(
    func,
    cfg,
    query,
    0,
    true,
    true,
    Some(work),
  )
  assert_eq(sources.length(), 17)
  // Two edges per writer still need at most sixteen bounded searches.
  // The original keeps searching all 32 edges and the entry source.
  assert_true(work[0] <= 16)
  assert_true(work[1] > 0)
}
