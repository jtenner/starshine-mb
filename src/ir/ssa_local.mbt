///|
fn ssa_local_require_local_type(func : HotFunc, local_id : LocalId) -> ValType {
  match hot_local_type(func, local_id) {
    Some(ty) => ty
    None => abort("ssa local build requires every referenced local to exist")
  }
}

///|
fn ssa_local_require_node_range(ssa : HotLocalSsa, node_id : NodeId) -> Unit {
  if node_id < 0 || node_id >= ssa.local_get_values.length() {
    abort("ssa local node queries require a valid node id")
  }
}

///|
fn ssa_local_require_block_range(ssa : HotLocalSsa, block_id : BlockId) -> Unit {
  if block_id < 0 || block_id >= ssa.block_phis.length() {
    abort("ssa local block queries require a valid block id")
  }
}

///|
fn ssa_local_current_value(
  local_stacks : Array[Array[SsaValueId]],
  local_id : LocalId,
) -> SsaValueId {
  let stack = local_stacks[local_id]
  if stack.length() == 0 {
    abort("ssa local rename requires a current reaching definition")
  }
  stack[stack.length() - 1]
}

///|
fn ssa_local_add_value(
  ssa : HotLocalSsa,
  ty : ValType,
  origin : HotSsaValueOrigin,
) -> SsaValueId {
  let value_id = ssa.value_types.length()
  ssa.value_types.push(ty)
  ssa.value_origins.push(origin)
  ssa.value_uses.push([])
  value_id
}

///|
fn ssa_local_record_use(
  ssa : HotLocalSsa,
  value_id : SsaValueId,
  use_origin : HotSsaUseOrigin,
) -> Unit {
  ssa.value_uses[value_id].push(use_origin)
}

///|
fn ssa_local_is_region_slot(op : HotOp, slot : Int) -> Bool {
  match op {
    HotOp::Block | HotOp::Loop => true
    _ => {
      for slot_info in hot_control_region_slot_info(op) {
        if slot_info.slot == slot {
          return true
        }
      }
      false
    }
  }
}

///|
fn ssa_local_live_child(
  func : HotFunc,
  node_id : NodeId,
  slot : Int,
) -> NodeId? {
  let child_id = hot_child_get(func, node_id, slot)
  if child_id == HOT_NONE_NODE || !hot_node_is_live(func, child_id) {
    return None
  }
  Some(child_id)
}

///|
fn ssa_local_visit_node(
  func : HotFunc,
  ssa : HotLocalSsa,
  node_id : NodeId,
  local_stacks : Array[Array[SsaValueId]],
  pushed_locals : Array[LocalId],
) -> Unit {
  let node = hot_node_get(func, node_id)
  for slot = 0; slot < hot_child_count(func, node_id); slot = slot + 1 {
    if ssa_local_is_region_slot(node.op, slot) {
      continue
    }
    match ssa_local_live_child(func, node_id, slot) {
      Some(child_id) =>
        ssa_local_visit_node(func, ssa, child_id, local_stacks, pushed_locals)
      None => ()
    }
  }
  match node.op {
    HotOp::LocalGet => {
      let value_id = ssa_local_current_value(local_stacks, node.imm0)
      ssa.local_get_values[node_id] = value_id
      ssa_local_record_use(ssa, value_id, HotSsaUseOrigin::LocalGetUse(node_id))
    }
    HotOp::LocalSet => {
      let value_id = ssa_local_add_value(
        ssa,
        ssa_local_require_local_type(func, node.imm0),
        ssa_local_set_def(node_id),
      )
      ssa.local_write_defs[node_id] = value_id
      local_stacks[node.imm0].push(value_id)
      pushed_locals.push(node.imm0)
    }
    HotOp::LocalTee => {
      let value_id = ssa_local_add_value(
        ssa,
        ssa_local_require_local_type(func, node.imm0),
        ssa_local_tee_def(node_id),
      )
      ssa.local_write_defs[node_id] = value_id
      local_stacks[node.imm0].push(value_id)
      pushed_locals.push(node.imm0)
    }
    _ => ()
  }
}

///|
fn ssa_local_record_successor_phi_inputs(
  cfg : HotCfg,
  ssa : HotLocalSsa,
  block_id : BlockId,
  local_stacks : Array[Array[SsaValueId]],
) -> Unit {
  for succ in cfg_successors(cfg, block_id) {
    if succ.kind == CfgEdgeKind::ExceptionalEdge {
      continue
    }
    for phi_id in ssa.block_phis[succ.block] {
      let local_id = ssa.phis[phi_id].local_id
      let value_id = ssa_local_current_value(local_stacks, local_id)
      ssa.phi_inputs[phi_id].push(HotSsaPhiInput::new(block_id, value_id))
      ssa_local_record_use(
        ssa,
        value_id,
        HotSsaUseOrigin::PhiInputUse(phi_id, block_id),
      )
    }
  }
}

///|
fn ssa_local_visit_block(
  func : HotFunc,
  cfg : HotCfg,
  dom : HotDominators,
  ssa : HotLocalSsa,
  block_id : BlockId,
  local_stacks : Array[Array[SsaValueId]],
) -> Unit {
  let pushed_locals : Array[LocalId] = []
  for phi_id in ssa.block_phis[block_id] {
    let local_id = ssa.phis[phi_id].local_id
    let value_id = ssa.phi_value_ids[phi_id]
    local_stacks[local_id].push(value_id)
    pushed_locals.push(local_id)
  }
  for node_id in cfg_block_get(cfg, block_id).nodes {
    ssa_local_visit_node(func, ssa, node_id, local_stacks, pushed_locals)
  }
  ssa_local_record_successor_phi_inputs(cfg, ssa, block_id, local_stacks)
  for child_block in dom_children(dom, block_id) {
    ssa_local_visit_block(func, cfg, dom, ssa, child_block, local_stacks)
  }
  for idx = pushed_locals.length() - 1; idx >= 0; idx = idx - 1 {
    ignore(local_stacks[pushed_locals[idx]].pop())
  }
}

///|
fn ssa_local_normal_predecessors(
  cfg : HotCfg,
  block_id : BlockId,
) -> Array[BlockId] {
  let preds : Array[BlockId] = []
  for pred in cfg_predecessors(cfg, block_id) {
    if pred.kind == CfgEdgeKind::ExceptionalEdge {
      continue
    }
    preds.push(pred.block)
  }
  preds
}

///|
fn ssa_local_sort_phi_inputs(cfg : HotCfg, ssa : HotLocalSsa) -> Unit {
  for phi_id = 0; phi_id < ssa.phis.length(); phi_id = phi_id + 1 {
    let current = ssa.phi_inputs[phi_id].copy()
    let ordered : Array[HotSsaPhiInput] = []
    let used = Array::make(current.length(), false)
    for
      predecessor in ssa_local_normal_predecessors(cfg, ssa.phis[phi_id].block) {
      let mut matched = false
      for idx = 0; idx < current.length(); idx = idx + 1 {
        if used[idx] || current[idx].predecessor != predecessor {
          continue
        }
        ordered.push(current[idx])
        used[idx] = true
        matched = true
        break
      }
      if !matched {
        abort("ssa phi inputs must align with normal-flow predecessors")
      }
    }
    if ordered.length() != current.length() {
      abort("ssa phi inputs must not contain extra predecessor entries")
    }
    ssa.phi_inputs[phi_id] = ordered
  }
}

///|
pub fn ssa_build_local(
  func : HotFunc,
  cfg : HotCfg,
  dom : HotDominators,
  liveness : HotLiveness,
  use_def : HotUseDef,
) -> HotLocalSsa {
  let local_count = hot_local_count(func)
  let node_count = hot_node_count(func)
  let block_count = cfg_block_count(cfg)
  let entry_defs = Array::make(local_count, -1)
  let local_stacks : Array[Array[SsaValueId]] = []
  for _ in 0..<local_count {
    local_stacks.push([])
  }
  let block_phis : Array[Array[PhiId]] = []
  for _ in 0..<block_count {
    block_phis.push([])
  }
  let ssa = HotLocalSsa::new(
    revision=hot_revision_current(func),
    local_get_values=Array::make(node_count, -1),
    local_write_defs=Array::make(node_count, -1),
    entry_defs~,
    block_phis~,
  )

  for local_id = 0; local_id < local_count; local_id = local_id + 1 {
    let entry_value = ssa_local_add_value(
      ssa,
      ssa_local_require_local_type(func, local_id),
      if hot_local_is_param(func, local_id) {
        ssa_param_entry_def(local_id)
      } else {
        ssa_default_init_def(local_id)
      },
    )
    ssa.entry_defs[local_id] = entry_value
    local_stacks[local_id].push(entry_value)
  }

  for local_id = 0; local_id < local_count; local_id = local_id + 1 {
    for
      block_id in ssa_phi_placement_blocks(
        func, cfg, dom, liveness, use_def, local_id,
      ) {
      let phi_id = ssa.phis.length()
      ssa.phis.push(HotSsaPhi::new(block_id, local_id))
      block_phis[block_id].push(phi_id)
      let value_id = ssa_local_add_value(
        ssa,
        ssa_local_require_local_type(func, local_id),
        ssa_phi_def(phi_id),
      )
      ssa.phi_value_ids.push(value_id)
      ssa.phi_inputs.push([])
    }
  }

  ssa_local_visit_block(func, cfg, dom, ssa, cfg_entry_block(cfg), local_stacks)
  ssa_local_sort_phi_inputs(cfg, ssa)
  ssa
}

///|
pub fn ssa_value_for_local_get(
  ssa : HotLocalSsa,
  node_id : NodeId,
) -> SsaValueId {
  ssa_local_require_node_range(ssa, node_id)
  let value_id = ssa.local_get_values[node_id]
  if value_id < 0 {
    abort(
      "ssa local-get queries require a local_get node mapped by ssa_build_local",
    )
  }
  value_id
}

///|
pub fn ssa_def_for_local_set(ssa : HotLocalSsa, node_id : NodeId) -> SsaValueId {
  ssa_local_require_node_range(ssa, node_id)
  let value_id = ssa.local_write_defs[node_id]
  if value_id < 0 {
    abort(
      "ssa local-def queries require a local_set/local_tee node mapped by ssa_build_local",
    )
  }
  value_id
}

///|
pub fn ssa_maybe_def_for_local_set(
  ssa : HotLocalSsa,
  node_id : NodeId,
) -> SsaValueId? {
  ssa_local_require_node_range(ssa, node_id)
  let value_id = ssa.local_write_defs[node_id]
  if value_id < 0 {
    None
  } else {
    Some(value_id)
  }
}

///|
pub fn ssa_phis_for_block(
  ssa : HotLocalSsa,
  block_id : BlockId,
) -> Array[PhiId] {
  ssa_local_require_block_range(ssa, block_id)
  ssa.block_phis[block_id].copy()
}

///|
pub fn ssa_phi_inputs(
  ssa : HotLocalSsa,
  phi_id : PhiId,
) -> Array[HotSsaPhiInput] {
  ssa_require_phi_range(ssa, phi_id)
  ssa.phi_inputs[phi_id].copy()
}

///|
pub fn ssa_uses_of_value(
  ssa : HotLocalSsa,
  value_id : SsaValueId,
) -> Array[HotSsaUseOrigin] {
  ssa_require_value_range(ssa, value_id)
  ssa.value_uses[value_id].copy()
}
