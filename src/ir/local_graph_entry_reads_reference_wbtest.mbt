///|
fn entry_read_reference_build_reverse_flow(
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
            if last_writes[node.imm0] < 0 {
              written_locals.push(node.imm0)
            }
            last_writes[node.imm0] = node_id
          }
          HotOp::LocalGet => nearest_writes[node_id] = last_writes[node.imm0]
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
    } else {
      local_graph_reverse_entry_sources(
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
