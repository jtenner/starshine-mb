///|
// Frozen V63 reverse-row construction, including original admission/header scans.
fn flow_tag_reference_build_reverse_rows(
  func : HotFunc,
  cfg : HotCfg,
  include_exceptional : Bool,
  cache_slots? : Array[Int]? = None,
  full_metadata~ : Bool,
) -> LocalGraphFlowRows {
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
          return local_graph_build_sparse_rows(
            func,
            cfg,
            include_exceptional,
            full_metadata~,
          )
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
          return local_graph_build_sparse_rows(
            func,
            cfg,
            include_exceptional,
            full_metadata~,
          )
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
  let write_facts = local_graph_build_write_facts(
    func,
    include_tees=full_metadata,
  )
  let write_local_ids = write_facts.local_ids
  let transparent_predecessors = local_graph_reverse_transparent_predecessors(
    write_local_ids, cfg, actions, include_exceptional,
  )
  let get_sources : Array[Array[Int]] = Array::make(node_count, [])
  let write_influences = if full_metadata {
    local_graph_empty_influences(func)
  } else {
    []
  }
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
  // Publish the admitted immutable owner index once. Constructing its
  // nullable argument at every query otherwise repeats reference-count work.
  let writer_blocks = Some(node_blocks)
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
      local_graph_reverse_entry_sources_impl(
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
        writer_blocks,
        None,
        cache_slots,
      )
    }
    if full_metadata {
      local_graph_record_unique_get_sources(
        local_count, node_id, sources, get_sources, write_influences,
      )
    } else {
      get_sources[node_id] = sources
    }
  }
  LocalGraphFlowRows::new(get_sources, write_influences, write_facts)
}
