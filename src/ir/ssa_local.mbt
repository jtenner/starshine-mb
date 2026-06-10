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
    HotOp::If => slot == 1 || slot == 2
    HotOp::Try | HotOp::TryTable => slot == 0 || slot == 1
    _ => false
  }
}

///|
fn ssa_simple_node_is_forbidden_control(
  func : HotFunc,
  node_id : NodeId,
) -> Bool {
  if node_id < 0 || !hot_node_is_live(func, node_id) {
    return false
  }
  if hot_is_terminator_node(func, node_id) || hot_is_branch(func, node_id) {
    return true
  }
  match hot_node_get(func, node_id).op {
    HotOp::Block
    | HotOp::Loop
    | HotOp::If
    | HotOp::Try
    | HotOp::TryTable
    | HotOp::Br
    | HotOp::BrIf
    | HotOp::BrTable
    | HotOp::Return
    | HotOp::Unreachable
    | HotOp::Throw
    | HotOp::ThrowRef
    | HotOp::Rethrow
    | HotOp::Delegate => true
    _ => false
  }
}

///|
fn ssa_simple_value_block_subtree_is_straight_line(
  func : HotFunc,
  node_id : NodeId,
  allow_block_root : Bool,
) -> Bool {
  if node_id < 0 || !hot_node_is_live(func, node_id) {
    return true
  }
  let node = hot_node_get(func, node_id)
  if !allow_block_root && ssa_simple_node_is_forbidden_control(func, node_id) {
    return false
  }
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    let child_id = func.children[node.child_base + slot]
    if child_id == HOT_NONE_NODE || !hot_node_is_live(func, child_id) {
      continue
    }
    if !ssa_simple_value_block_subtree_is_straight_line(func, child_id, false) {
      return false
    }
  }
  if allow_block_root && node.op == HotOp::Block {
    let body = hot_region_body_ref(func, node_id)
    for slot = 0; slot < hot_region_root_count(func, body); slot = slot + 1 {
      let root_id = hot_region_get(func, body, slot)
      if root_id == HOT_NONE_NODE || !hot_node_is_live(func, root_id) {
        continue
      }
      if !ssa_simple_value_block_subtree_is_straight_line(func, root_id, false) {
        return false
      }
    }
  }
  true
}

///|
fn ssa_simple_subtree_has_local_write(func : HotFunc, node_id : NodeId) -> Bool {
  if node_id < 0 || !hot_node_is_live(func, node_id) {
    return false
  }
  match hot_node_get(func, node_id).op {
    HotOp::LocalSet | HotOp::LocalTee => return true
    _ => ()
  }
  let node = hot_node_get(func, node_id)
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    let child_id = func.children[node.child_base + slot]
    if child_id == HOT_NONE_NODE || !hot_node_is_live(func, child_id) {
      continue
    }
    if ssa_simple_subtree_has_local_write(func, child_id) {
      return true
    }
  }
  false
}

///|
fn ssa_simple_result_if_region_is_straight_line(
  func : HotFunc,
  region_ref : HotRegionRef,
) -> Bool {
  for slot = 0; slot < hot_region_root_count(func, region_ref); slot = slot + 1 {
    let root_id = hot_region_get(func, region_ref, slot)
    if root_id == HOT_NONE_NODE || !hot_node_is_live(func, root_id) {
      continue
    }
    if !ssa_simple_value_block_subtree_is_straight_line(func, root_id, false) {
      return false
    }
  }
  true
}

///|
fn ssa_simple_result_if_has_i32_result(func : HotFunc, if_id : NodeId) -> Bool {
  let results = hot_type_results(func, hot_node_get(func, if_id).ty)
  results.length() == 1 && results[0] == @lib.ValType::i32()
}

///|
// Operand-nested `drop(if (result i32) …)` is a narrow CFG shape: both arms are
// straight-line, the condition has no nested control or local writes, and the else
// arm is required. Broader nested `if` (nested branches/loops/exceptions, missing
// else, multi-value results) stays fail-closed in `ssa-nomerge`.
pub fn ssa_simple_drop_result_if_allowed(
  func : HotFunc,
  drop_id : NodeId,
  operand_slot : Int,
  if_id : NodeId,
) -> Bool {
  if drop_id < 0 ||
    operand_slot != 0 ||
    if_id < 0 ||
    !hot_node_is_live(func, drop_id) ||
    !hot_node_is_live(func, if_id) {
    return false
  }
  if hot_node_get(func, drop_id).op != HotOp::Drop ||
    hot_node_get(func, if_id).op != HotOp::If {
    return false
  }
  if !ssa_simple_result_if_has_i32_result(func, if_id) {
    return false
  }
  let else_ref = match hot_region_else_ref(func, if_id) {
    Some(region_ref) => region_ref
    None => return false
  }
  let condition_id = func.children[hot_node_get(func, if_id).child_base]
  if condition_id == HOT_NONE_NODE ||
    !hot_node_is_live(func, condition_id) ||
    ssa_simple_subtree_has_local_write(func, condition_id) ||
    !ssa_simple_value_block_subtree_is_straight_line(func, condition_id, false) {
    return false
  }
  ssa_simple_result_if_region_is_straight_line(
    func,
    hot_region_then_ref(func, if_id),
  ) &&
  ssa_simple_result_if_region_is_straight_line(func, else_ref)
}

///|
pub fn ssa_simple_drop_value_block_allowed(
  func : HotFunc,
  drop_id : NodeId,
  operand_slot : Int,
  block_id : NodeId,
) -> Bool {
  if drop_id < 0 ||
    operand_slot != 0 ||
    block_id < 0 ||
    !hot_node_is_live(func, drop_id) ||
    !hot_node_is_live(func, block_id) {
    return false
  }
  if hot_node_get(func, drop_id).op != HotOp::Drop ||
    hot_node_get(func, block_id).op != HotOp::Block {
    return false
  }
  ssa_simple_value_block_subtree_is_straight_line(func, block_id, true)
}

///|
fn ssa_local_visit_region_roots(
  func : HotFunc,
  ssa : HotLocalSsa,
  region_ref : HotRegionRef,
  local_stacks : Array[Array[SsaValueId]],
  pushed_locals : Array[LocalId],
) -> Unit {
  for slot = 0; slot < hot_region_root_count(func, region_ref); slot = slot + 1 {
    let root_id = hot_region_get(func, region_ref, slot)
    if root_id == HOT_NONE_NODE || !hot_node_is_live(func, root_id) {
      continue
    }
    ssa_local_visit_node(func, ssa, root_id, local_stacks, pushed_locals)
  }
}

///|
fn ssa_local_live_child(func : HotFunc, node : HotNode, slot : Int) -> NodeId? {
  let child_id = func.children[node.child_base + slot]
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
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    if ssa_local_is_region_slot(node.op, slot) {
      continue
    }
    match ssa_local_live_child(func, node, slot) {
      Some(child_id) =>
        if node.op == HotOp::Drop &&
          ssa_simple_drop_value_block_allowed(func, node_id, slot, child_id) {
          ssa_local_visit_region_roots(
            func,
            ssa,
            hot_region_body_ref(func, child_id),
            local_stacks,
            pushed_locals,
          )
        } else {
          ssa_local_visit_node(func, ssa, child_id, local_stacks, pushed_locals)
        }
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

// SSA v1 intentionally skips exceptional CFG edges (see `cfg.mbt`, `local-ssa-policy.md`).
// The CFG records them for try/try_table headers and throw-family terminators; catch
// bodies are not dominated by throwing blocks in the normal-flow dominator tree.
// Liveness, dominators, phi placement, rename, and destroy all follow the normal-flow-only
// contract until upgraded together. Do not remove the `ExceptionalEdge` continues below
// without that full upgrade. Until then, mutation passes such as `ssa-nomerge` fail closed
// on exceptional-flow functions.

///|
fn ssa_local_record_successor_phi_inputs(
  cfg : HotCfg,
  ssa : HotLocalSsa,
  block_id : BlockId,
  local_stacks : Array[Array[SsaValueId]],
) -> Unit {
  for succ in cfg_successor_edges(cfg, block_id) {
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
  for child_block in dom.children[block_id] {
    ssa_local_visit_block(func, cfg, dom, ssa, child_block, local_stacks)
  }
  for idx = pushed_locals.length() - 1; idx >= 0; idx = idx - 1 {
    ignore(local_stacks[pushed_locals[idx]].pop())
  }
}

///|
fn ssa_local_normal_predecessors(
  cfg : HotCfg,
  dom : HotDominators,
  block_id : BlockId,
) -> Array[BlockId] {
  let preds : Array[BlockId] = []
  for pred in cfg_predecessor_edges(cfg, block_id) {
    if pred.kind == CfgEdgeKind::ExceptionalEdge ||
      !dom_dominates(dom, dom.entry_block, pred.block) {
      continue
    }
    preds.push(pred.block)
  }
  preds
}

///|
fn ssa_local_phi_alignment_abort(
  ssa : HotLocalSsa,
  block_id : BlockId,
  phi_id : PhiId,
  preds : Array[BlockId],
  current : Array[HotSsaPhiInput],
) -> Unit {
  let phi = ssa.phis[phi_id]
  abort(
    "ssa phi inputs must align with normal-flow predecessors: block=\{block_id} phi=\{phi_id} phi_block=\{phi.block} local=\{phi.local_id} preds=\{preds} inputs=\{current}",
  )
}

///|
fn ssa_local_sort_phi_inputs(
  cfg : HotCfg,
  dom : HotDominators,
  ssa : HotLocalSsa,
) -> Unit {
  let pred_order = Array::make(cfg_block_count(cfg), -1)
  for block_id = 0; block_id < ssa.block_phis.length(); block_id = block_id + 1 {
    let preds = ssa_local_normal_predecessors(cfg, dom, block_id)
    for predecessor in preds {
      pred_order[predecessor] = -1
    }
    for idx = 0; idx < preds.length(); idx = idx + 1 {
      pred_order[preds[idx]] = idx
    }
    for phi_id in ssa.block_phis[block_id] {
      let current = ssa.phi_inputs[phi_id]
      if current.length() == 0 {
        continue
      }
      let ordered = Array::make(current.length(), current[0])
      let filled = Array::make(current.length(), false)
      for input in current {
        let idx = if input.predecessor >= 0 &&
          input.predecessor < pred_order.length() {
          pred_order[input.predecessor]
        } else {
          -1
        }
        if idx < 0 || idx >= ordered.length() || filled[idx] {
          ssa_local_phi_alignment_abort(ssa, block_id, phi_id, preds, current)
        }
        ordered[idx] = input
        filled[idx] = true
      }
      for is_filled in filled {
        if !is_filled {
          ssa_local_phi_alignment_abort(ssa, block_id, phi_id, preds, current)
        }
      }
      ssa.phi_inputs[phi_id] = ordered
    }
    for predecessor in preds {
      pred_order[predecessor] = -1
    }
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
  let rpo = cfg_reverse_postorder(cfg)
  let rpo_index = ssa_phi_block_order_index(cfg, rpo)
  let phi_placed_stamps = Array::make(block_count, -1)
  let phi_queued_stamps = Array::make(block_count, -1)
  let phi_queue : Array[BlockId] = []
  let phi_placements : Array[BlockId] = []
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
      block_id in ssa_phi_placement_blocks_with_scratch(
        func, cfg, dom, liveness, use_def, local_id, rpo_index, phi_placed_stamps,
        phi_queued_stamps, phi_queue, phi_placements, local_id,
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
  ssa_local_sort_phi_inputs(cfg, dom, ssa)
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
