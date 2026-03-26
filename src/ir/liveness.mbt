///|
pub struct HotLiveness {
  include_exceptional_edges : Bool
  live_in_sets : Array[Bitset]
  live_out_sets : Array[Bitset]
} derive(Eq, Show, Debug)

///|
fn liveness_bitset_clone(src : Bitset) -> Bitset {
  let out = bitset_new(src.size)
  ignore(bitset_union_into(out, src))
  out
}

///|
fn liveness_bitset_clear(dst : Bitset) -> Unit {
  for idx = 0; idx < dst.words.length(); idx = idx + 1 {
    dst.words[idx] = 0UL
  }
}

///|
fn liveness_bitset_assign(dst : Bitset, src : Bitset) -> Unit {
  if dst.size != src.size {
    abort("liveness bitset assignment requires matching sizes")
  }
  for idx = 0; idx < dst.words.length(); idx = idx + 1 {
    dst.words[idx] = src.words[idx]
  }
}

///|
fn liveness_require_block_range(
  liveness : HotLiveness,
  block_id : BlockId,
) -> Unit {
  if block_id < 0 || block_id >= liveness.live_in_sets.length() {
    abort("liveness block query requires a valid block id")
  }
}

///|
fn liveness_require_local_range(
  liveness : HotLiveness,
  local_id : LocalId,
) -> Unit {
  let local_count = if liveness.live_in_sets.length() == 0 {
    0
  } else {
    liveness.live_in_sets[0].size
  }
  if local_id < 0 || local_id >= local_count {
    abort("liveness local query requires a valid local id")
  }
}

///|
fn liveness_require_use_def_shape(cfg : HotCfg, use_def : HotUseDef) -> Int {
  if use_def.block_defs.length() != cfg_block_count(cfg) ||
    use_def.block_uses.length() != cfg_block_count(cfg) {
    abort(
      "liveness_build requires block-local use-def summaries for the same cfg",
    )
  }
  if cfg_block_count(cfg) == 0 {
    return 0
  }
  let local_count = use_def.block_defs[0].size
  for block_id = 0; block_id < cfg_block_count(cfg); block_id = block_id + 1 {
    if use_def.block_defs[block_id].size != local_count ||
      use_def.block_uses[block_id].size != local_count {
      abort(
        "liveness_build requires use-def bitsets with one shared local count",
      )
    }
  }
  local_count
}

///|
pub fn liveness_build(cfg : HotCfg, use_def : HotUseDef) -> HotLiveness {
  let local_count = liveness_require_use_def_shape(cfg, use_def)
  let live_in_sets : Array[Bitset] = []
  let live_out_sets : Array[Bitset] = []
  let block_count = cfg_block_count(cfg)
  for _ in 0..<block_count {
    live_in_sets.push(bitset_new(local_count))
    live_out_sets.push(bitset_new(local_count))
  }
  let include_exceptional_edges = false
  let queued = Array::make(block_count, false)
  let worklist : Array[BlockId] = []
  for block_id = 0; block_id < block_count; block_id = block_id + 1 {
    queued[block_id] = true
    worklist.push(block_id)
  }
  let next_out = bitset_new(local_count)
  let next_in = bitset_new(local_count)

  while worklist.length() > 0 {
    let block_id = worklist.pop().unwrap()
    queued[block_id] = false

    liveness_bitset_clear(next_out)
    for edge in cfg_successor_edges(cfg, block_id) {
      if !include_exceptional_edges && edge.kind == CfgEdgeKind::ExceptionalEdge {
        continue
      }
      ignore(bitset_union_into(next_out, live_in_sets[edge.block]))
    }

    liveness_bitset_assign(next_in, next_out)
    ignore(bitset_difference_into(next_in, use_def.block_defs[block_id]))
    ignore(bitset_union_into(next_in, use_def.block_uses[block_id]))

    let out_changed = !bitset_equals(live_out_sets[block_id], next_out)
    let in_changed = !bitset_equals(live_in_sets[block_id], next_in)
    if out_changed {
      liveness_bitset_assign(live_out_sets[block_id], next_out)
    }
    if in_changed {
      liveness_bitset_assign(live_in_sets[block_id], next_in)
    }
    if out_changed || in_changed {
      for edge in cfg_predecessor_edges(cfg, block_id) {
        if !include_exceptional_edges &&
          edge.kind == CfgEdgeKind::ExceptionalEdge {
          continue
        }
        if !queued[edge.block] {
          queued[edge.block] = true
          worklist.push(edge.block)
        }
      }
    }
  }

  { include_exceptional_edges, live_in_sets, live_out_sets }
}

///|
pub fn live_in(liveness : HotLiveness, block_id : BlockId) -> Bitset {
  liveness_require_block_range(liveness, block_id)
  liveness_bitset_clone(liveness.live_in_sets[block_id])
}

///|
pub fn live_out(liveness : HotLiveness, block_id : BlockId) -> Bitset {
  liveness_require_block_range(liveness, block_id)
  liveness_bitset_clone(liveness.live_out_sets[block_id])
}

///|
pub fn local_live_in(
  liveness : HotLiveness,
  block_id : BlockId,
  local_id : LocalId,
) -> Bool {
  liveness_require_block_range(liveness, block_id)
  liveness_require_local_range(liveness, local_id)
  bitset_contains(liveness.live_in_sets[block_id], local_id)
}

///|
pub fn local_live_out(
  liveness : HotLiveness,
  block_id : BlockId,
  local_id : LocalId,
) -> Bool {
  liveness_require_block_range(liveness, block_id)
  liveness_require_local_range(liveness, local_id)
  bitset_contains(liveness.live_out_sets[block_id], local_id)
}
