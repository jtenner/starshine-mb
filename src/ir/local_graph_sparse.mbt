///|
// A block summary contains only locals changed within that block. Negative
// sources name a block entry; nonnegative sources retain ordinary write IDs.
// Resolve entry sources on demand instead of retaining locals × blocks states.
fn local_graph_sparse_entry_sources(
  cfg : HotCfg,
  summaries : Array[@hashmap.HashMap[Int, Array[Int]]],
  block_id : BlockId,
  local_id : LocalId,
  include_exceptional : Bool,
  cache : Array[@hashmap.HashMap[Int, Array[Int]]],
) -> Array[Int] {
  match cache[block_id].get(local_id) {
    Some(sources) => return sources
    None => ()
  }
  let sources : Array[Int] = []
  let work = [block_id]
  let seen = Array::make(cfg_block_count(cfg), false)
  seen[block_id] = true
  while !work.is_empty() {
    let current = work.pop().unwrap()
    if current == cfg_entry_block(cfg) {
      ignore(
        local_graph_union_into(sources, [local_graph_entry_source_id(local_id)]),
      )
    }
    for pred in cfg_predecessor_edges(cfg, current) {
      if !include_exceptional && pred.kind == CfgEdgeKind::ExceptionalEdge {
        continue
      }
      match summaries[pred.block].get(local_id) {
        Some(summary) =>
          for source in summary {
            if source >= 0 {
              if !local_graph_array_contains(sources, source) {
                sources.push(source)
              }
            } else {
              let entry = -source - 1
              if !seen[entry] {
                seen[entry] = true
                work.push(entry)
              }
            }
          }
        None =>
          if !seen[pred.block] {
            seen[pred.block] = true
            work.push(pred.block)
          }
      }
    }
  }
  // Cache only after the complete backwards closure. A cycle encountered
  // during traversal is not evidence that its remaining entry sources vanish.
  cache[block_id].set(local_id, sources)
  sources
}

///|
fn local_graph_build_sparse_flow(
  func : HotFunc,
  cfg : HotCfg,
  include_exceptional : Bool,
) -> HotLocalGraph {
  let local_count = hot_local_count(func)
  let node_count = hot_node_count(func)
  let get_sources : Array[Array[Int]] = Array::makei(node_count, fn(_) { [] })
  let summaries : Array[@hashmap.HashMap[Int, Array[Int]]] = []
  let cache : Array[@hashmap.HashMap[Int, Array[Int]]] = []
  for block = 0; block < cfg_block_count(cfg); block = block + 1 {
    let entry_source = -block - 1
    let state = Array::make(local_count, [entry_source])
    // Reuse the same path-sensitive transfer for nested conditionals,
    // unknown nested regions and shared tuple evaluations as the full solver.
    let exit_state = local_graph_transfer_block(
      func,
      cfg,
      block,
      state,
      Some(get_sources),
      None,
    )
    let summary : @hashmap.HashMap[Int, Array[Int]] = @hashmap.new()
    for local_id = 0; local_id < local_count; local_id = local_id + 1 {
      let sources = exit_state[local_id]
      if sources.length() != 1 || sources[0] != entry_source {
        summary.set(local_id, sources)
      }
    }
    summaries.push(summary)
    cache.push(@hashmap.new())
  }
  let write_influences = local_graph_empty_influences(func)
  for node = 0; node < node_count; node = node + 1 {
    if !hot_node_is_live(func, node) ||
      !(hot_node_get(func, node).op is HotOp::LocalGet) {
      continue
    }
    let local_id = hot_node_get(func, node).imm0
    let symbolic = get_sources[node]
    get_sources[node] = []
    for source in symbolic {
      let resolved = if source >= 0 {
        [source]
      } else {
        local_graph_sparse_entry_sources(
          cfg,
          summaries,
          -source - 1,
          local_id,
          include_exceptional,
          cache,
        )
      }
      local_graph_record_get_sources(
        local_count,
        node,
        resolved,
        Some(get_sources),
        Some(write_influences),
      )
    }
  }
  {
    local_count,
    param_count: hot_param_count(func),
    get_source_ids: get_sources,
    set_influence_gets: write_influences,
    write_local_ids: local_graph_build_write_local_ids(func),
    write_is_tees: local_graph_build_write_is_tees(func),
    local_is_already_ssa: local_graph_build_local_already_ssa(
      func, local_count, get_sources,
    ),
    local_has_legal_default: local_graph_build_local_defaultability(
      func, local_count,
    ),
  }
}
