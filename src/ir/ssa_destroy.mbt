///|
pub struct HotSsaCopy {
  source_local : LocalId
  target_local : LocalId
} derive(Eq, Show, Debug)

///|
pub fn HotSsaCopy::new(
  source_local : LocalId,
  target_local : LocalId,
) -> HotSsaCopy {
  if source_local < 0 || target_local < 0 {
    abort("ssa copies require non-negative local ids")
  }
  { source_local, target_local }
}

///|
pub struct HotSsaConcreteLocals {
  value_locals : Array[LocalId]
  extra_local_types : Array[ValType]
} derive(Eq, Show, Debug)

///|
pub fn HotSsaConcreteLocals::new(
  value_locals? : Array[LocalId] = [],
  extra_local_types? : Array[ValType] = [],
) -> HotSsaConcreteLocals {
  { value_locals, extra_local_types }
}

///|
pub enum HotSsaDestroyPolicy {
  ReusePhiLocals
} derive(Eq, Show, Debug)

///|
fn ssa_destroy_local_type(func : HotFunc, local_id : LocalId) -> ValType {
  match hot_local_type(func, local_id) {
    Some(ty) => ty
    None => abort("ssa destruction requires every referenced local to exist")
  }
}

///|
fn ssa_destroy_block_region_ref(block : HotBlockInfo) -> HotRegionRef {
  if block.region_holder == HOT_NONE_NODE {
    return HotRegionRef::root()
  }
  { holder: block.region_holder }
}

///|
fn ssa_destroy_insert_index(func : HotFunc, block : HotBlockInfo) -> Int {
  if block.nodes.length() == 0 {
    return block.end_slot
  }
  let last_node = block.nodes[block.nodes.length() - 1]
  if cfg_op_is_terminator(hot_node_get(func, last_node).op) {
    return block.end_slot - 1
  }
  block.end_slot
}

///|
fn ssa_destroy_append_body_local(func : HotFunc, ty : ValType) -> LocalId {
  let local_id = hot_local_count(func)
  func.locals.locals.push(ty)
  hot_revision_bump(func)
  local_id
}

///|
fn ssa_destroy_pending_sources(copies : Array[HotSsaCopy]) -> Array[LocalId] {
  let sources : Array[LocalId] = []
  for copy in copies {
    sources.push(copy.source_local)
  }
  sources
}

///|
fn ssa_destroy_remove_copy(copies : Array[HotSsaCopy], idx : Int) -> HotSsaCopy {
  let removed = copies[idx]
  let last = copies.length() - 1
  for slot = idx; slot < last; slot = slot + 1 {
    copies[slot] = copies[slot + 1]
  }
  ignore(copies.pop())
  removed
}

///|
fn ssa_destroy_schedule_copies(
  func : HotFunc,
  copies : Array[HotSsaCopy],
) -> Array[HotSsaCopy] {
  let pending : Array[HotSsaCopy] = []
  for copy in copies {
    if copy.source_local == copy.target_local {
      continue
    }
    pending.push(copy)
  }
  let schedule : Array[HotSsaCopy] = []
  while pending.length() > 0 {
    let sources = ssa_destroy_pending_sources(pending)
    let mut ready = -1
    for idx = 0; idx < pending.length(); idx = idx + 1 {
      let target = pending[idx].target_local
      let mut used_as_source = false
      for source in sources {
        if source == target {
          used_as_source = true
          break
        }
      }
      if !used_as_source {
        ready = idx
        break
      }
    }
    if ready >= 0 {
      schedule.push(ssa_destroy_remove_copy(pending, ready))
      continue
    }
    let cycle = pending[0]
    let temp_local = ssa_destroy_append_body_local(
      func,
      ssa_destroy_local_type(func, cycle.target_local),
    )
    schedule.push(HotSsaCopy::new(cycle.source_local, temp_local))
    for idx = 0; idx < pending.length(); idx = idx + 1 {
      if pending[idx].source_local == cycle.source_local {
        pending[idx] = HotSsaCopy::new(temp_local, pending[idx].target_local)
      }
    }
  }
  schedule
}

///|
pub fn ssa_assign_concrete_locals(
  ssa : HotLocalSsa,
  locals : HotLocals,
) -> HotSsaConcreteLocals {
  let value_locals = Array::make(ssa.value_types.length(), -1)
  let extra_local_types : Array[ValType] = []
  let mut next_local = locals.param_count + locals.locals.length()
  for value_id = 0
      value_id < ssa.value_origins.length()
      value_id = value_id + 1 {
    value_locals[value_id] = match ssa.value_origins[value_id] {
      HotSsaValueOrigin::EntryParamDef(local_id)
      | HotSsaValueOrigin::EntryDefaultInitDef(local_id) => local_id
      HotSsaValueOrigin::PhiDef(phi_id) => ssa.phis[phi_id].local_id
      HotSsaValueOrigin::LocalSetDef(_) | HotSsaValueOrigin::LocalTeeDef(_) => {
        extra_local_types.push(ssa.value_types[value_id])
        let local_id = next_local
        next_local = next_local + 1
        local_id
      }
    }
  }
  { value_locals, extra_local_types }
}

///|
pub fn ssa_rewrite_local_use(
  func : HotFunc,
  node_id : NodeId,
  local_id : LocalId,
) -> Unit {
  ignore(ssa_destroy_local_type(func, local_id))
  let node = hot_node_get(func, node_id)
  match node.op {
    HotOp::LocalGet | HotOp::LocalSet | HotOp::LocalTee =>
      hot_node_set(func, node_id, { ..node, imm0: local_id })
    _ =>
      abort("ssa local rewrites require a local_get/local_set/local_tee node")
  }
}

///|
pub fn ssa_insert_predecessor_copies(
  func : HotFunc,
  region_ref : HotRegionRef,
  predecessor_block : HotBlockInfo,
  copies : Array[HotSsaCopy],
) -> Array[NodeId] {
  if predecessor_block.is_synthetic {
    abort("ssa predecessor copies require a non-synthetic predecessor block")
  }
  let nodes : Array[NodeId] = []
  for copy in ssa_destroy_schedule_copies(func, copies) {
    let source_get = hot_build_local_get(func, copy.source_local)
    nodes.push(hot_build_local_set(func, copy.target_local, source_get))
  }
  if nodes.length() == 0 {
    return []
  }
  hot_region_insert(
    func,
    region_ref,
    ssa_destroy_insert_index(func, predecessor_block),
    nodes,
  )
  nodes
}

///|
pub fn ssa_remove_dead_local_defs(
  func : HotFunc,
  dead_nodes : Array[NodeId],
) -> Unit {
  for node_id in dead_nodes {
    let node = hot_node_get(func, node_id)
    match node.op {
      HotOp::LocalSet =>
        hot_replace_node(func, node_id, {
          ..node,
          op: HotOp::Drop,
          ty: hot_type_void(func),
          imm0: 0,
          imm1: 0,
        })
      HotOp::LocalTee => {
        let child = hot_node_get(func, hot_child_get(func, node_id, 0))
        hot_replace_node(func, node_id, child)
      }
      _ => abort("ssa dead-def cleanup requires local_set/local_tee nodes")
    }
  }
}

///|
pub fn ssa_destroy_into_hot(
  func : HotFunc,
  cfg : HotCfg,
  ssa : HotLocalSsa,
  policy? : HotSsaDestroyPolicy = HotSsaDestroyPolicy::ReusePhiLocals,
) -> HotSsaConcreteLocals {
  ignore(policy)
  let concrete = ssa_assign_concrete_locals(ssa, func.locals)
  for ty in concrete.extra_local_types {
    ignore(ssa_destroy_append_body_local(func, ty))
  }

  for node_id = 0
      node_id < ssa.local_write_defs.length()
      node_id = node_id + 1 {
    let value_id = ssa.local_write_defs[node_id]
    if value_id < 0 {
      continue
    }
    ssa_rewrite_local_use(func, node_id, concrete.value_locals[value_id])
  }
  for node_id = 0
      node_id < ssa.local_get_values.length()
      node_id = node_id + 1 {
    let value_id = ssa.local_get_values[node_id]
    if value_id < 0 {
      continue
    }
    ssa_rewrite_local_use(func, node_id, concrete.value_locals[value_id])
  }

  let copies_by_predecessor : Array[Array[HotSsaCopy]] = []
  for _ in 0..<cfg_block_count(cfg) {
    copies_by_predecessor.push([])
  }
  for block_id = 0; block_id < cfg_block_count(cfg); block_id = block_id + 1 {
    for phi_id in ssa_phis_for_block(ssa, block_id) {
      let target_local = concrete.value_locals[ssa.phi_value_ids[phi_id]]
      for input in ssa_phi_inputs(ssa, phi_id) {
        copies_by_predecessor[input.predecessor].push(
          HotSsaCopy::new(concrete.value_locals[input.value_id], target_local),
        )
      }
    }
  }
  for block_id = cfg_block_count(cfg) - 1
      block_id >= 0
      block_id = block_id - 1 {
    if copies_by_predecessor[block_id].length() == 0 {
      continue
    }
    let block = cfg_block_get(cfg, block_id)
    ignore(
      ssa_insert_predecessor_copies(
        func,
        ssa_destroy_block_region_ref(block),
        block,
        copies_by_predecessor[block_id],
      ),
    )
  }

  let dead_nodes : Array[NodeId] = []
  for value_id = 0
      value_id < ssa.value_origins.length()
      value_id = value_id + 1 {
    if ssa.value_uses[value_id].length() != 0 {
      continue
    }
    match ssa.value_origins[value_id] {
      HotSsaValueOrigin::LocalSetDef(node_id) => dead_nodes.push(node_id)
      _ => ()
    }
  }
  ssa_remove_dead_local_defs(func, dead_nodes)
  concrete
}
