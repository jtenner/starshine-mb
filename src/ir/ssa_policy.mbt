///|
pub type SsaValueId = Int

///|
pub type PhiId = Int

///|
pub enum HotSsaValueOrigin {
  EntryParamDef(LocalId)
  EntryDefaultInitDef(LocalId)
  LocalSetDef(NodeId)
  LocalTeeDef(NodeId)
  PhiDef(PhiId)
} derive(Eq, Show, Debug)

///|
pub enum HotSsaUseOrigin {
  LocalGetUse(NodeId)
  PhiInputUse(PhiId, BlockId)
} derive(Eq, Show, Debug)

///|
pub struct HotSsaPhi {
  block : BlockId
  local_id : LocalId
} derive(Eq, Show, Debug)

///|
pub fn HotSsaPhi::new(block : BlockId, local_id : LocalId) -> HotSsaPhi {
  if block < 0 {
    abort("ssa phi block ids must be non-negative")
  }
  if local_id < 0 {
    abort("ssa phi local ids must be non-negative")
  }
  { block, local_id }
}

///|
pub struct HotSsaPhiInput {
  predecessor : BlockId
  value_id : SsaValueId
} derive(Eq, Show, Debug)

///|
pub fn HotSsaPhiInput::new(
  predecessor : BlockId,
  value_id : SsaValueId,
) -> HotSsaPhiInput {
  if predecessor < 0 {
    abort("ssa phi input predecessors must be non-negative")
  }
  if value_id < 0 {
    abort("ssa phi input values must be non-negative")
  }
  { predecessor, value_id }
}

///|
pub struct HotLocalSsa {
  revision : Int
  value_types : Array[ValType]
  value_origins : Array[HotSsaValueOrigin]
  phis : Array[HotSsaPhi]
  entry_defs : Array[SsaValueId]
  phi_value_ids : Array[SsaValueId]
  block_phis : Array[Array[PhiId]]
  phi_inputs : Array[Array[HotSsaPhiInput]]
  local_get_values : Array[SsaValueId]
  local_write_defs : Array[SsaValueId]
  value_uses : Array[Array[HotSsaUseOrigin]]
} derive(Eq, Show, Debug)

///|
pub fn HotLocalSsa::new(
  revision? : Int = 0,
  value_types? : Array[ValType] = [],
  value_origins? : Array[HotSsaValueOrigin] = [],
  phis? : Array[HotSsaPhi] = [],
  entry_defs? : Array[SsaValueId] = [],
  phi_value_ids? : Array[SsaValueId] = [],
  block_phis? : Array[Array[PhiId]] = [],
  phi_inputs? : Array[Array[HotSsaPhiInput]] = [],
  local_get_values? : Array[SsaValueId] = [],
  local_write_defs? : Array[SsaValueId] = [],
  value_uses? : Array[Array[HotSsaUseOrigin]] = [],
) -> HotLocalSsa {
  if revision < 0 {
    abort("ssa overlays require a non-negative hot revision")
  }
  if value_types.length() != value_origins.length() {
    abort("ssa overlays require one origin for every value type")
  }
  if phi_value_ids.length() != 0 && phi_value_ids.length() != phis.length() {
    abort("ssa overlays require one phi value id per phi")
  }
  if phi_inputs.length() != 0 && phi_inputs.length() != phis.length() {
    abort("ssa overlays require one phi input list per phi")
  }
  if value_uses.length() != 0 && value_uses.length() != value_types.length() {
    abort("ssa overlays require one use list per value")
  }
  {
    revision,
    value_types,
    value_origins,
    phis,
    entry_defs,
    phi_value_ids,
    block_phis,
    phi_inputs,
    local_get_values,
    local_write_defs,
    value_uses,
  }
}

///|
pub enum HotSsaRenamePolicy {
  DominatorTreeRename
} derive(Eq, Show, Debug)

///|
pub enum HotSsaDestructionPolicy {
  ParallelCopiesInPredecessors
} derive(Eq, Show, Debug)

///|
pub enum HotSsaExcludedFeature {
  ExceptionalEdges
  PersistentHotPhiNodes
  IrOwnedSsaBodies
  NonLocalValues
} derive(Eq, Show, Debug)

///|
fn ssa_require_value_range(ssa : HotLocalSsa, value_id : SsaValueId) -> Unit {
  if value_id < 0 || value_id >= ssa.value_types.length() {
    abort("ssa value queries require a valid value id")
  }
}

///|
fn ssa_require_phi_range(ssa : HotLocalSsa, phi_id : PhiId) -> Unit {
  if phi_id < 0 || phi_id >= ssa.phis.length() {
    abort("ssa phi queries require a valid phi id")
  }
}

///|
fn ssa_require_local_range(func : HotFunc, local_id : LocalId) -> Unit {
  if local_id < 0 || local_id >= hot_local_count(func) {
    abort("ssa policy queries require a valid local id")
  }
}

///|
fn ssa_require_cfg_shapes(
  func : HotFunc,
  cfg : HotCfg,
  liveness : HotLiveness,
  use_def : HotUseDef,
) -> Unit {
  let block_count = cfg_block_count(cfg)
  if liveness.live_in_sets.length() != block_count ||
    liveness.live_out_sets.length() != block_count {
    abort("ssa policy requires liveness for the same cfg block count")
  }
  if use_def.block_defs.length() != block_count ||
    use_def.block_uses.length() != block_count {
    abort("ssa policy requires use-def block sets for the same cfg block count")
  }
  if use_def.local_reads.length() != hot_local_count(func) ||
    use_def.local_writes.length() != hot_local_count(func) ||
    use_def.local_write_blocks.length() != hot_local_count(func) {
    abort("ssa policy requires use-def local sets for all locals")
  }
}

///|
fn ssa_phi_block_order_index(cfg : HotCfg, rpo : Array[BlockId]) -> Array[Int] {
  let out = Array::make(cfg_block_count(cfg), -1)
  for idx = 0; idx < rpo.length(); idx = idx + 1 {
    out[rpo[idx]] = idx
  }
  out
}

///|
fn ssa_phi_placement_blocks_with_scratch(
  func : HotFunc,
  cfg : HotCfg,
  dom : HotDominators,
  liveness : HotLiveness,
  use_def : HotUseDef,
  local_id : LocalId,
  rpo_index : Array[Int],
  placed_stamps : Array[Int],
  queued_stamps : Array[Int],
  queue : Array[BlockId],
  placements : Array[BlockId],
  stamp : Int,
) -> Array[BlockId] {
  ssa_require_local_range(func, local_id)
  ssa_require_cfg_shapes(func, cfg, liveness, use_def)

  let writes = use_def.local_write_blocks[local_id]
  if writes.length() == 0 || use_def.local_reads[local_id].length() == 0 {
    placements.clear()
    return []
  }

  queue.clear()
  placements.clear()
  for block_id in writes {
    if queued_stamps[block_id] == stamp {
      continue
    }
    queued_stamps[block_id] = stamp
    queue.push(block_id)
  }

  while queue.length() > 0 {
    let block_id = queue.pop().unwrap()
    for frontier in dom.frontiers[block_id] {
      if !bitset_contains(liveness.live_in_sets[frontier], local_id) {
        continue
      }
      if placed_stamps[frontier] != stamp {
        placed_stamps[frontier] = stamp
        placements.push(frontier)
      }
      if queued_stamps[frontier] != stamp {
        queued_stamps[frontier] = stamp
        queue.push(frontier)
      }
    }
  }
  if placements.length() > 1 {
    placements.sort_by((lhs, rhs) => rpo_index[lhs] - rpo_index[rhs])
  }
  placements
}

///|
pub fn ssa_param_entry_def(local_id : LocalId) -> HotSsaValueOrigin {
  if local_id < 0 {
    abort("ssa param entry defs require a non-negative local id")
  }
  HotSsaValueOrigin::EntryParamDef(local_id)
}

///|
pub fn ssa_default_init_def(local_id : LocalId) -> HotSsaValueOrigin {
  if local_id < 0 {
    abort("ssa default-init defs require a non-negative local id")
  }
  HotSsaValueOrigin::EntryDefaultInitDef(local_id)
}

///|
pub fn ssa_local_set_def(node_id : NodeId) -> HotSsaValueOrigin {
  if node_id < 0 {
    abort("ssa local-set defs require a non-negative node id")
  }
  HotSsaValueOrigin::LocalSetDef(node_id)
}

///|
pub fn ssa_local_tee_def(node_id : NodeId) -> HotSsaValueOrigin {
  if node_id < 0 {
    abort("ssa local-tee defs require a non-negative node id")
  }
  HotSsaValueOrigin::LocalTeeDef(node_id)
}

///|
pub fn ssa_phi_def(phi_id : PhiId) -> HotSsaValueOrigin {
  if phi_id < 0 {
    abort("ssa phi defs require a non-negative phi id")
  }
  HotSsaValueOrigin::PhiDef(phi_id)
}

///|
pub fn ssa_value_type(ssa : HotLocalSsa, value_id : SsaValueId) -> ValType {
  ssa_require_value_range(ssa, value_id)
  ssa.value_types[value_id]
}

///|
pub fn ssa_value_origin(
  ssa : HotLocalSsa,
  value_id : SsaValueId,
) -> HotSsaValueOrigin {
  ssa_require_value_range(ssa, value_id)
  ssa.value_origins[value_id]
}

///|
pub fn ssa_phi_block(ssa : HotLocalSsa, phi_id : PhiId) -> BlockId {
  ssa_require_phi_range(ssa, phi_id)
  ssa.phis[phi_id].block
}

///|
pub fn ssa_phi_local(ssa : HotLocalSsa, phi_id : PhiId) -> LocalId {
  ssa_require_phi_range(ssa, phi_id)
  ssa.phis[phi_id].local_id
}

///|
pub fn ssa_phi_placement_blocks(
  func : HotFunc,
  cfg : HotCfg,
  dom : HotDominators,
  liveness : HotLiveness,
  use_def : HotUseDef,
  rpo : Array[BlockId],
  local_id : LocalId,
) -> Array[BlockId] {
  ssa_phi_placement_blocks_with_scratch(
    func,
    cfg,
    dom,
    liveness,
    use_def,
    local_id,
    ssa_phi_block_order_index(cfg, rpo),
    Array::make(cfg_block_count(cfg), -1),
    Array::make(cfg_block_count(cfg), -1),
    [],
    [],
    0,
  )
}

///|
pub fn ssa_phi_nodes_are_overlay_only() -> Bool {
  true
}

///|
pub fn ssa_rename_policy() -> HotSsaRenamePolicy {
  HotSsaRenamePolicy::DominatorTreeRename
}

///|
pub fn ssa_destruction_policy() -> HotSsaDestructionPolicy {
  HotSsaDestructionPolicy::ParallelCopiesInPredecessors
}

///|
pub fn ssa_v1_exclusions() -> Array[HotSsaExcludedFeature] {
  [
    HotSsaExcludedFeature::ExceptionalEdges,
    HotSsaExcludedFeature::PersistentHotPhiNodes,
    HotSsaExcludedFeature::IrOwnedSsaBodies,
    HotSsaExcludedFeature::NonLocalValues,
  ]
}
