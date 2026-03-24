///|
fn cfg_order_is_traversable_edge(
  edge : CfgEdge,
  include_exceptional : Bool,
) -> Bool {
  include_exceptional || edge.kind != CfgEdgeKind::ExceptionalEdge
}

///|
fn cfg_order_push_root(
  stack : Array[(BlockId, Bool)],
  visited : Array[Bool],
  block_id : BlockId,
) -> Unit {
  if block_id < 0 || block_id >= visited.length() || visited[block_id] {
    return
  }
  stack.push((block_id, false))
}

///|
fn cfg_order_postorder_from_roots(
  cfg : HotCfg,
  roots : Array[BlockId],
  reverse? : Bool = false,
  include_exceptional? : Bool = false,
) -> Array[BlockId] {
  let visited = Array::make(cfg_block_count(cfg), false)
  let stack : Array[(BlockId, Bool)] = []
  let postorder : Array[BlockId] = []
  for idx = roots.length() - 1; idx >= 0; idx = idx - 1 {
    cfg_order_push_root(stack, visited, roots[idx])
  }
  while stack.length() > 0 {
    let (block_id, expanded) = stack.pop().unwrap()
    if expanded {
      postorder.push(block_id)
      continue
    }
    if visited[block_id] {
      continue
    }
    visited[block_id] = true
    stack.push((block_id, true))
    let edges = if reverse {
      cfg_predecessors(cfg, block_id)
    } else {
      cfg_successors(cfg, block_id)
    }
    for idx = edges.length() - 1; idx >= 0; idx = idx - 1 {
      let edge = edges[idx]
      if cfg_order_is_traversable_edge(edge, include_exceptional) &&
        !visited[edge.block] {
        stack.push((edge.block, false))
      }
    }
  }
  postorder
}

///|
fn cfg_order_preorder_from_roots(
  cfg : HotCfg,
  roots : Array[BlockId],
  reverse? : Bool = false,
  include_exceptional? : Bool = false,
) -> Array[BlockId] {
  let visited = Array::make(cfg_block_count(cfg), false)
  let stack : Array[BlockId] = []
  let preorder : Array[BlockId] = []
  for idx = roots.length() - 1; idx >= 0; idx = idx - 1 {
    let block_id = roots[idx]
    if block_id >= 0 && block_id < visited.length() && !visited[block_id] {
      stack.push(block_id)
    }
  }
  while stack.length() > 0 {
    let block_id = stack.pop().unwrap()
    if visited[block_id] {
      continue
    }
    visited[block_id] = true
    preorder.push(block_id)
    let edges = if reverse {
      cfg_predecessors(cfg, block_id)
    } else {
      cfg_successors(cfg, block_id)
    }
    for idx = edges.length() - 1; idx >= 0; idx = idx - 1 {
      let edge = edges[idx]
      if cfg_order_is_traversable_edge(edge, include_exceptional) &&
        !visited[edge.block] {
        stack.push(edge.block)
      }
    }
  }
  preorder
}

///|
fn cfg_order_reverse(blocks : Array[BlockId]) -> Array[BlockId] {
  let out : Array[BlockId] = []
  for idx = blocks.length() - 1; idx >= 0; idx = idx - 1 {
    out.push(blocks[idx])
  }
  out
}

///|
fn cfg_order_exit_roots(
  cfg : HotCfg,
  include_exceptional : Bool,
) -> Array[BlockId] {
  let roots = [cfg_exit_block(cfg)]
  if include_exceptional {
    match cfg_exceptional_exit_block(cfg) {
      Some(block_id) if block_id != cfg_exit_block(cfg) => roots.push(block_id)
      _ => ()
    }
  }
  roots
}

///|
fn cfg_region_direct_blocks(
  cfg : HotCfg,
  region_ref : HotRegionRef,
) -> Array[BlockId] {
  let direct : Array[BlockId] = []
  let seen = Array::make(cfg_block_count(cfg), false)
  for entry in cfg.region_roots {
    if entry.region_holder != region_ref.holder {
      continue
    }
    if !seen[entry.block] {
      seen[entry.block] = true
      direct.push(entry.block)
    }
  }
  direct
}

///|
pub fn cfg_preorder(cfg : HotCfg) -> Array[BlockId] {
  cfg_order_preorder_from_roots(cfg, [cfg_entry_block(cfg)])
}

///|
pub fn cfg_postorder(cfg : HotCfg) -> Array[BlockId] {
  cfg_order_postorder_from_roots(cfg, [cfg_entry_block(cfg)])
}

///|
pub fn cfg_reverse_postorder(cfg : HotCfg) -> Array[BlockId] {
  cfg_order_reverse(cfg_postorder(cfg))
}

///|
pub fn cfg_reverse_postorder_with_exceptions(cfg : HotCfg) -> Array[BlockId] {
  cfg_order_reverse(
    cfg_order_postorder_from_roots(
      cfg,
      [cfg_entry_block(cfg)],
      include_exceptional=true,
    ),
  )
}

///|
pub fn cfg_reverse_postorder_from_exit(cfg : HotCfg) -> Array[BlockId] {
  cfg_order_reverse(
    cfg_order_postorder_from_roots(
      cfg,
      cfg_order_exit_roots(cfg, false),
      reverse=true,
    ),
  )
}

///|
pub fn cfg_reverse_postorder_from_exit_with_exceptions(
  cfg : HotCfg,
) -> Array[BlockId] {
  cfg_order_reverse(
    cfg_order_postorder_from_roots(
      cfg,
      cfg_order_exit_roots(cfg, true),
      reverse=true,
      include_exceptional=true,
    ),
  )
}

///|
pub fn cfg_region_blocks_in_rpo(
  cfg : HotCfg,
  region_ref : HotRegionRef,
) -> Array[BlockId] {
  let direct_blocks = cfg_region_direct_blocks(cfg, region_ref)
  let out : Array[BlockId] = []
  let seen = Array::make(cfg_block_count(cfg), false)
  for block_id in cfg_reverse_postorder(cfg) {
    if direct_blocks.contains(block_id) {
      seen[block_id] = true
      out.push(block_id)
    }
  }
  for block_id in direct_blocks {
    if !seen[block_id] {
      out.push(block_id)
    }
  }
  out
}

///|
pub fn cfg_block_worklist_seed(cfg : HotCfg) -> Array[BlockId] {
  cfg_reverse_postorder(cfg)
}
