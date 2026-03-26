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
fn liveness_update_block_words(
  succs : Array[CfgEdge],
  live_in_sets : Array[Bitset],
  defs : Bitset,
  uses : Bitset,
  live_out : Bitset,
  live_in : Bitset,
  include_exceptional_edges : Bool,
) -> (Bool, Bool) {
  bitset_require_compatible(live_out, live_in)
  bitset_require_compatible(live_out, defs)
  bitset_require_compatible(live_out, uses)
  let mut out_changed = false
  let mut in_changed = false
  for word_idx = 0; word_idx < live_out.words.length(); word_idx = word_idx + 1 {
    let word_mask = bitset_word_mask(live_out, word_idx)
    let mut next_out_word = 0UL
    for edge in succs {
      if !include_exceptional_edges && edge.kind == CfgEdgeKind::ExceptionalEdge {
        continue
      }
      next_out_word = next_out_word | live_in_sets[edge.block].words[word_idx]
    }
    next_out_word = next_out_word & word_mask
    if live_out.words[word_idx] != next_out_word {
      live_out.words[word_idx] = next_out_word
      out_changed = true
    }
    let next_in_word = (
        (next_out_word & UInt64::lnot(defs.words[word_idx])) |
        uses.words[word_idx]
      ) &
      word_mask
    if live_in.words[word_idx] != next_in_word {
      live_in.words[word_idx] = next_in_word
      in_changed = true
    }
  }
  (out_changed, in_changed)
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

  while worklist.length() > 0 {
    let block_id = worklist.pop().unwrap()
    queued[block_id] = false
    let block = cfg.blocks[block_id]
    let (out_changed, in_changed) = liveness_update_block_words(
      block.succs,
      live_in_sets,
      use_def.block_defs[block_id],
      use_def.block_uses[block_id],
      live_out_sets[block_id],
      live_in_sets[block_id],
      include_exceptional_edges,
    )
    if out_changed || in_changed {
      for edge in block.preds {
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
