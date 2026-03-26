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
struct HotSsaPendingInsert {
  insert_idx : Int
  nodes : Array[NodeId]
  order : Int
} derive(Eq, Show, Debug)

///|
struct HotSsaRegionInsertGroup {
  region_ref : HotRegionRef
  inserts : Array[HotSsaPendingInsert]
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
fn ssa_destroy_ensure_source_count(
  source_counts : Array[Int],
  local_id : LocalId,
) -> Unit {
  while source_counts.length() <= local_id {
    source_counts.push(0)
  }
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
  let source_counts : Array[Int] = []
  for copy in pending {
    ssa_destroy_ensure_source_count(source_counts, copy.source_local)
    source_counts[copy.source_local] = source_counts[copy.source_local] + 1
  }
  let schedule : Array[HotSsaCopy] = []
  while pending.length() > 0 {
    let mut ready = -1
    for idx = 0; idx < pending.length(); idx = idx + 1 {
      let target = pending[idx].target_local
      let used_as_source = target >= 0 &&
        target < source_counts.length() &&
        source_counts[target] > 0
      if !used_as_source {
        ready = idx
        break
      }
    }
    if ready >= 0 {
      let next = ssa_destroy_remove_copy(pending, ready)
      source_counts[next.source_local] = source_counts[next.source_local] - 1
      schedule.push(next)
      continue
    }
    let cycle = pending[0]
    let temp_local = ssa_destroy_append_body_local(
      func,
      ssa_destroy_local_type(func, cycle.target_local),
    )
    schedule.push(HotSsaCopy::new(cycle.source_local, temp_local))
    ssa_destroy_ensure_source_count(source_counts, temp_local)
    let mut rewritten = 0
    for idx = 0; idx < pending.length(); idx = idx + 1 {
      if pending[idx].source_local == cycle.source_local {
        pending[idx] = HotSsaCopy::new(temp_local, pending[idx].target_local)
        rewritten = rewritten + 1
      }
    }
    source_counts[cycle.source_local] = source_counts[cycle.source_local] -
      rewritten
    source_counts[temp_local] = source_counts[temp_local] + rewritten
  }
  schedule
}

///|
fn ssa_destroy_build_predecessor_copy_nodes(
  func : HotFunc,
  copies : Array[HotSsaCopy],
) -> Array[NodeId] {
  let schedule = ssa_destroy_schedule_copies(func, copies)
  let nodes : Array[NodeId] = []
  if schedule.length() == 0 {
    return nodes
  }
  for copy in schedule {
    let source_get = hot_build_local_get(func, copy.source_local)
    nodes.push(hot_build_local_set(func, copy.target_local, source_get))
  }
  nodes
}

///|
fn ssa_destroy_pending_insert_before(
  lhs : HotSsaPendingInsert,
  rhs : HotSsaPendingInsert,
) -> Bool {
  lhs.insert_idx < rhs.insert_idx ||
  (lhs.insert_idx == rhs.insert_idx && lhs.order > rhs.order)
}

///|
fn ssa_destroy_push_pending_insert(
  groups : Array[HotSsaRegionInsertGroup],
  region_ref : HotRegionRef,
  insert_idx : Int,
  nodes : Array[NodeId],
  order : Int,
) -> Unit {
  let mut group_idx = -1
  for idx = 0; idx < groups.length(); idx = idx + 1 {
    if groups[idx].region_ref.holder == region_ref.holder {
      group_idx = idx
      break
    }
  }
  if group_idx < 0 {
    group_idx = groups.length()
    groups.push({ region_ref, inserts: [] })
  }
  let inserts = groups[group_idx].inserts
  inserts.push({ insert_idx, nodes, order })
  for idx = inserts.length() - 1; idx > 0; idx = idx - 1 {
    if !ssa_destroy_pending_insert_before(inserts[idx], inserts[idx - 1]) {
      break
    }
    let current = inserts[idx]
    inserts[idx] = inserts[idx - 1]
    inserts[idx - 1] = current
  }
}

///|
fn ssa_destroy_region_roots(
  func : HotFunc,
  region_ref : HotRegionRef,
) -> Array[NodeId] {
  let roots : Array[NodeId] = []
  for idx = 0; idx < hot_region_root_count(func, region_ref); idx = idx + 1 {
    roots.push(hot_region_get(func, region_ref, idx))
  }
  roots
}

///|
fn ssa_destroy_apply_pending_inserts(
  func : HotFunc,
  group : HotSsaRegionInsertGroup,
) -> Unit {
  if group.inserts.length() == 0 {
    return
  }
  let current = ssa_destroy_region_roots(func, group.region_ref)
  let next : Array[NodeId] = []
  let mut insert_idx = 0
  for slot = 0; slot <= current.length(); slot = slot + 1 {
    while insert_idx < group.inserts.length() &&
          group.inserts[insert_idx].insert_idx == slot {
      for node_id in group.inserts[insert_idx].nodes {
        next.push(node_id)
      }
      insert_idx = insert_idx + 1
    }
    if slot < current.length() {
      next.push(current[slot])
    }
  }
  hot_region_replace_body(func, group.region_ref, next)
}

///|
fn ssa_destroy_original_write_local(
  func : HotFunc,
  node_id : NodeId,
) -> LocalId {
  let node = hot_node_get(func, node_id)
  match node.op {
    HotOp::LocalSet | HotOp::LocalTee => node.imm0
    _ =>
      abort(
        "ssa concrete local assignment requires local_set/local_tee defs, got \{node.op} at node \{node_id}",
      )
  }
}

///|
pub fn ssa_assign_concrete_locals(
  func : HotFunc,
  ssa : HotLocalSsa,
) -> HotSsaConcreteLocals {
  let value_locals = Array::make(ssa.value_types.length(), -1)
  let extra_local_types : Array[ValType] = []
  let mut next_local = hot_local_count(func)
  for value_id = 0
      value_id < ssa.value_origins.length()
      value_id = value_id + 1 {
    value_locals[value_id] = match ssa.value_origins[value_id] {
      HotSsaValueOrigin::EntryParamDef(local_id)
      | HotSsaValueOrigin::EntryDefaultInitDef(local_id) => local_id
      HotSsaValueOrigin::PhiDef(phi_id) => ssa.phis[phi_id].local_id
      HotSsaValueOrigin::LocalSetDef(node_id)
      | HotSsaValueOrigin::LocalTeeDef(node_id) =>
        if ssa.value_uses[value_id].length() == 0 {
          ssa_destroy_original_write_local(func, node_id)
        } else {
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
  let nodes = ssa_destroy_build_predecessor_copy_nodes(func, copies)
  if nodes.length() == 0 {
    return []
  }
  if predecessor_block.start_slot < 0 || predecessor_block.end_slot < 0 {
    abort(
      "ssa predecessor copies require a predecessor block with an insertion site",
    )
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
  let seen = Array::make(hot_node_count(func), false)
  for node_id in dead_nodes {
    if node_id < 0 || node_id >= seen.length() || seen[node_id] {
      continue
    }
    seen[node_id] = true
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
      HotOp::Drop => ()
      _ =>
        abort(
          "ssa dead-def cleanup requires local_set/local_tee nodes, got \{node.op} at node \{node_id}",
        )
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
  let concrete = ssa_assign_concrete_locals(func, ssa)
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
    for phi_id in ssa.block_phis[block_id] {
      let target_local = concrete.value_locals[ssa.phi_value_ids[phi_id]]
      for input in ssa.phi_inputs[phi_id] {
        copies_by_predecessor[input.predecessor].push(
          HotSsaCopy::new(concrete.value_locals[input.value_id], target_local),
        )
      }
    }
  }
  let pending_inserts : Array[HotSsaRegionInsertGroup] = []
  let mut insert_order = 0
  for block_id = cfg_block_count(cfg) - 1
      block_id >= 0
      block_id = block_id - 1 {
    if copies_by_predecessor[block_id].length() == 0 {
      continue
    }
    let block = cfg_block_get(cfg, block_id)
    let nodes = ssa_destroy_build_predecessor_copy_nodes(
      func,
      copies_by_predecessor[block_id],
    )
    if nodes.length() == 0 {
      continue
    }
    if block.start_slot < 0 || block.end_slot < 0 {
      abort(
        "ssa predecessor copies require a predecessor block with an insertion site",
      )
    }
    ssa_destroy_push_pending_insert(
      pending_inserts,
      ssa_destroy_block_region_ref(block),
      ssa_destroy_insert_index(func, block),
      nodes,
      insert_order,
    )
    insert_order = insert_order + 1
  }
  for group in pending_inserts {
    ssa_destroy_apply_pending_inserts(func, group)
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
      HotSsaValueOrigin::LocalTeeDef(node_id) => dead_nodes.push(node_id)
      _ => ()
    }
  }
  ssa_remove_dead_local_defs(func, dead_nodes)
  concrete
}
