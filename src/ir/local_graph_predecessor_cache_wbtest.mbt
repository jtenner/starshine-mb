///|
// Frozen v13 query for source-order and construction-inclusive controls.
fn local_graph_predecessor_cache_reference_sources(
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
fn local_graph_predecessor_cache_fixture(
  reads : Int,
  overwrite? : Bool = false,
) -> (HotFunc, HotCfg, Array[BlockId], Array[NodeId]) {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  let writes : Array[NodeId] = []
  for value in 0..<8 {
    let write = hot_build_local_set(
      func,
      0,
      hot_build_const_i32(func, @lib.I32(value)),
    )
    writes.push(write)
  }
  let read_nodes = Array::makei(reads, fn(_) { hot_build_local_get(func, 0) })
  let overwritten = if overwrite {
    Array::makei(reads, fn(i) {
      hot_build_local_set(func, 0, hot_build_const_i32(func, @lib.I32(i + 10)))
    })
  } else {
    []
  }
  let builder = cfg_builder_new(func, true, true)
  let entry = cfg_builder_add_block(builder, [], true)
  builder.cfg.entry_block = entry
  let predecessors : Array[BlockId] = [entry]
  for write in writes {
    let block = cfg_builder_add_block(builder, [write], false)
    cfg_builder_add_edge(builder, entry, block, CfgEdgeKind::FallthroughEdge)
    predecessors.push(block)
  }
  let blocks : Array[BlockId] = []
  let mut previous = -1
  for i, read in read_nodes {
    let nodes = if overwrite { [read, overwritten[i]] } else { [read] }
    let block = cfg_builder_add_block(builder, nodes, false)
    if previous < 0 {
      for predecessor in predecessors {
        cfg_builder_add_edge(
          builder,
          predecessor,
          block,
          CfgEdgeKind::FallthroughEdge,
        )
      }
    } else {
      cfg_builder_add_edge(
        builder,
        previous,
        block,
        CfgEdgeKind::FallthroughEdge,
      )
    }
    blocks.push(block)
    previous = block
  }
  let exit = cfg_builder_add_block(builder, [], true)
  builder.cfg.exit_block = exit
  cfg_builder_add_edge(builder, previous, exit, CfgEdgeKind::FallthroughEdge)
  (func, builder.cfg, blocks, writes)
}

///|
fn local_graph_predecessor_cache_queries(
  func : HotFunc,
  cfg : HotCfg,
  blocks : Array[BlockId],
  local_id : LocalId,
  reference : Bool,
  include_exceptional? : Bool = true,
) -> Array[Array[Int]] {
  let actions = local_graph_reverse_action_sequences(func, cfg)
  let writes = local_graph_build_write_local_ids(func)
  let transparent = local_graph_reverse_transparent_predecessors(
    writes, cfg, actions, include_exceptional,
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
  let rows : Array[Array[Int]] = []
  for block in blocks {
    rows.push(
      if reference {
        local_graph_predecessor_cache_reference_sources(
          writes,
          cfg,
          actions,
          transparent,
          block,
          local_id,
          include_exceptional,
          cache,
          last_writes,
          seen,
          visited,
          work,
          hot_local_count(func),
        )
      } else {
        local_graph_predecessor_cache_candidate_sources(
          writes,
          cfg,
          actions,
          transparent,
          block,
          local_id,
          include_exceptional,
          cache,
          last_writes,
          seen,
          visited,
          work,
          hot_local_count(func),
        )
      },
    )
    if !visited.is_empty() ||
      !work.is_empty() ||
      seen.any(fn(marked) { marked }) {
      abort("reverse query retained incomplete scratch state")
    }
  }
  rows
}

///|
test "candidate reverse queries share completed predecessor rows across read-only blocks" {
  let (func, cfg, blocks, _) = local_graph_predecessor_cache_fixture(3)
  let rows = local_graph_predecessor_cache_queries(func, cfg, blocks, 0, false)
  assert_eq(
    rows,
    local_graph_predecessor_cache_queries(func, cfg, blocks, 0, true),
  )
  assert_eq(rows[0].length(), 9)
  assert_true(physical_equal(rows[0], rows[1]))
  assert_true(physical_equal(rows[1], rows[2]))
  let outputs : Array[Array[Int]] = [[], []]
  let recorder = LocalGraphSourceRecorder::new(outputs)
  recorder.record(0, rows[0])
  recorder.record(1, rows[1])
  recorder.record(0, [local_graph_set_source_id(2, hot_node_count(func))])
  assert_eq(outputs[0].length(), 10)
  assert_eq(outputs[1], rows[0])
  assert_eq(rows[0].length(), 9)
}

///|
test "candidate reverse predecessor cache respects writes merges loops and exceptional policy" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  let first = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  let second = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(9)),
  )
  let other = hot_build_local_set(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(3)),
  )
  let reads = Array::makei(10, fn(_) { hot_build_local_get(func, 0) })
  let builder = cfg_builder_new(func, true, true)
  let entry = cfg_builder_add_block(builder, [], true)
  builder.cfg.entry_block = entry
  let origin = cfg_builder_add_block(builder, [first], false)
  let a = cfg_builder_add_block(builder, [reads[0], other], false)
  let b = cfg_builder_add_block(builder, [reads[1], second], false)
  let c = cfg_builder_add_block(builder, [reads[2]], false)
  let merged = cfg_builder_add_block(builder, [reads[3]], false)
  let handler = cfg_builder_add_block(builder, [reads[4]], false)
  let handler_next = cfg_builder_add_block(builder, [reads[5]], false)
  let loop_head = cfg_builder_add_block(builder, [reads[6]], false)
  let loop_body = cfg_builder_add_block(builder, [reads[7]], false)
  let dead_a = cfg_builder_add_block(builder, [reads[8]], false)
  let dead_b = cfg_builder_add_block(builder, [reads[9]], false)
  builder.cfg.exit_block = c
  for
    (from, to) in [
      (entry, origin),
      (origin, a),
      (a, b),
      (b, c),
      (origin, merged),
      (b, merged),
      (handler, handler_next),
      (entry, loop_head),
      (loop_head, loop_body),
      (loop_body, loop_head),
      (dead_a, dead_b),
      (dead_b, dead_a),
    ] {
    cfg_builder_add_edge(builder, from, to, CfgEdgeKind::FallthroughEdge)
  }
  cfg_builder_add_edge(builder, a, handler, CfgEdgeKind::ExceptionalEdge)
  let blocks = [
    a, b, c, merged, handler, handler_next, loop_head, loop_body, dead_a, dead_b,
  ]
  for exceptional in [false, true] {
    for local in [0, 1] {
      let rows = local_graph_predecessor_cache_queries(
        func,
        builder.cfg,
        blocks,
        local,
        false,
        include_exceptional=exceptional,
      )
      assert_eq(
        rows,
        local_graph_predecessor_cache_queries(
          func,
          builder.cfg,
          blocks,
          local,
          true,
          include_exceptional=exceptional,
        ),
      )
      assert_eq(rows[8], [])
      assert_eq(rows[9], [])
      assert_eq(rows[6], [local_graph_entry_source_id(local)])
      assert_eq(rows[7], rows[6])
      if !exceptional {
        assert_eq(rows[4], [])
        assert_eq(rows[5], [])
      }
      if local == 0 {
        assert_eq(rows[1], [local_graph_set_source_id(2, first)])
        assert_eq(rows[2], [local_graph_set_source_id(2, second)])
        assert_eq(rows[3].length(), 2)
      } else {
        assert_eq(rows[1], [local_graph_set_source_id(2, other)])
        assert_eq(rows[2], rows[1])
      }
    }
  }
}

///|
test "candidate reverse query resolves a sole preceding write without traversal scratch" {
  let (func, cfg, blocks, _) = local_graph_predecessor_cache_fixture(
    2,
    overwrite=true,
  )
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
  let sources = local_graph_predecessor_cache_candidate_sources(
    writes,
    cfg,
    actions,
    transparent,
    blocks[1],
    0,
    true,
    cache,
    last_writes,
    seen,
    visited,
    work,
    2,
  )
  let write = actions[blocks[0]].last().unwrap()
  assert_eq(sources, [local_graph_set_source_id(2, write)])
  assert_eq(cache[blocks[1]].unwrap().get(0), Some(sources))
  assert_eq(visited.capacity(), 0)
  assert_eq(work.capacity(), 0)
  for marked in seen {
    assert_false(marked)
  }
}

///|
// Rejected v14b candidate retained only for semantic and performance controls.
fn local_graph_predecessor_cache_candidate_sources(
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
  // Resolve a sole predecessor once. Its last write is already a complete
  // answer; without one, an immutable completed entry row is also its exit
  // row for this local. Other locals can still have changed in that block.
  let predecessors = cfg_predecessor_edges(cfg, block_id)
  let mut first_predecessor = -1
  let resolved = if predecessors.length() == 1 &&
    (
      include_exceptional ||
      predecessors[0].kind != CfgEdgeKind::ExceptionalEdge
    ) {
    let direct_predecessor = predecessors[0].block
    let predecessor = transparent_predecessors[direct_predecessor]
    match
      local_graph_reverse_indexed_last_write(
        write_local_ids, actions, predecessor, local_id, last_writes,
      ) {
      Some(write) => Some([local_graph_set_source_id(local_count, write)])
      None => {
        first_predecessor = predecessor
        match cache[direct_predecessor] {
          Some(row) => row.get(local_id)
          None => None
        }
      }
    }
  } else {
    None
  }
  let sources = match resolved {
    Some(sources) => sources
    None => {
      let sources : Array[Int] = []
      seen[block_id] = true
      visited.push(block_id)
      if first_predecessor >= 0 {
        // The first edge and write query have already been processed.
        if !seen[first_predecessor] {
          seen[first_predecessor] = true
          visited.push(first_predecessor)
          work.push(first_predecessor)
        }
      } else {
        work.push(block_id)
      }
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
      sources
    }
  }
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
