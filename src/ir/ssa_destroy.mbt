///|
pub struct HotSsaCopy {
  source_local : LocalId
  target_local : LocalId
} derive(Eq, Debug)

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
} derive(Eq, Debug)

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
} derive(Eq, Debug)

///|
struct HotSsaPendingInsert {
  insert_idx : Int
  nodes : Array[NodeId]
  order : Int
} derive(Eq, Debug)

///|
struct HotSsaRegionInsertGroup {
  region_ref : HotRegionRef
  inserts : Array[HotSsaPendingInsert]
} derive(Eq, Debug)

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
    let temp_local = hot_append_body_local(
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
pub fn ssa_assign_concrete_locals(
  func : HotFunc,
  ssa : HotLocalSsa,
  preserve_write_nodes? : @bitset.BitSet = @bitset.BitSet::new(0),
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
        if node_id >= 0 &&
          node_id < preserve_write_nodes.length() &&
          preserve_write_nodes[node_id] {
          hot_node_get(func, node_id).imm0
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
fn ssa_destroy_is_region_slot(op : HotOp, slot : Int) -> Bool {
  match op {
    HotOp::Block | HotOp::Loop => true
    HotOp::If => slot == 1 || slot == 2
    HotOp::Try | HotOp::TryTable => slot == 0 || slot == 1
    _ => false
  }
}

///|
fn ssa_destroy_assign_node_order_region(
  func : HotFunc,
  region_ref : HotRegionRef,
  node_order : Array[Int],
  next_order : Int,
) -> Int {
  let mut cursor = next_order
  for idx = 0; idx < hot_region_root_count(func, region_ref); idx = idx + 1 {
    let root_id = hot_region_get(func, region_ref, idx)
    cursor = ssa_destroy_assign_node_order_node(
      func, root_id, node_order, cursor,
    )
  }
  cursor
}

///|
fn ssa_destroy_assign_node_order_node(
  func : HotFunc,
  node_id : NodeId,
  node_order : Array[Int],
  next_order : Int,
) -> Int {
  if node_id == HOT_NONE_NODE || !hot_node_is_live(func, node_id) {
    return next_order
  }
  if node_order[node_id] >= 0 {
    return next_order
  }
  let mut cursor = next_order
  let node = hot_node_get(func, node_id)
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    if ssa_destroy_is_region_slot(node.op, slot) {
      continue
    }
    cursor = ssa_destroy_assign_node_order_node(
      func,
      hot_child_get(func, node_id, slot),
      node_order,
      cursor,
    )
  }
  match node.op {
    HotOp::Block | HotOp::Loop =>
      cursor = ssa_destroy_assign_node_order_region(
        func,
        hot_region_body_ref(func, node_id),
        node_order,
        cursor,
      )
    HotOp::If => {
      cursor = ssa_destroy_assign_node_order_region(
        func,
        hot_region_then_ref(func, node_id),
        node_order,
        cursor,
      )
      match hot_region_else_ref(func, node_id) {
        Some(region_ref) =>
          cursor = ssa_destroy_assign_node_order_region(
            func, region_ref, node_order, cursor,
          )
        None => ()
      }
    }
    HotOp::Try => {
      cursor = ssa_destroy_assign_node_order_region(
        func,
        hot_region_body_ref(func, node_id),
        node_order,
        cursor,
      )
      match hot_region_catch_ref(func, node_id) {
        Some(region_ref) =>
          cursor = ssa_destroy_assign_node_order_region(
            func, region_ref, node_order, cursor,
          )
        None => ()
      }
    }
    HotOp::TryTable => {
      cursor = ssa_destroy_assign_node_order_region(
        func,
        hot_region_body_ref(func, node_id),
        node_order,
        cursor,
      )
      cursor = ssa_destroy_assign_node_order_region(
        func,
        hot_region_catch_list_ref(func, node_id),
        node_order,
        cursor,
      )
    }
    _ => ()
  }
  node_order[node_id] = cursor
  cursor + 1
}

///|
fn ssa_destroy_mark_reachable_node_tree(
  func : HotFunc,
  node_id : NodeId,
  reachable_nodes : Array[Bool],
) -> Unit {
  if node_id == HOT_NONE_NODE ||
    !hot_node_is_live(func, node_id) ||
    reachable_nodes[node_id] {
    return
  }
  reachable_nodes[node_id] = true
  let node = hot_node_get(func, node_id)
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    if ssa_destroy_is_region_slot(node.op, slot) {
      continue
    }
    ssa_destroy_mark_reachable_node_tree(
      func,
      hot_child_get(func, node_id, slot),
      reachable_nodes,
    )
  }
  match node.op {
    HotOp::Block | HotOp::Loop =>
      ssa_destroy_mark_reachable_region_tree(
        func,
        hot_region_body_ref(func, node_id),
        reachable_nodes,
      )
    HotOp::If => {
      ssa_destroy_mark_reachable_region_tree(
        func,
        hot_region_then_ref(func, node_id),
        reachable_nodes,
      )
      match hot_region_else_ref(func, node_id) {
        Some(region_ref) =>
          ssa_destroy_mark_reachable_region_tree(
            func, region_ref, reachable_nodes,
          )
        None => ()
      }
    }
    HotOp::Try => {
      ssa_destroy_mark_reachable_region_tree(
        func,
        hot_region_body_ref(func, node_id),
        reachable_nodes,
      )
      match hot_region_catch_ref(func, node_id) {
        Some(region_ref) =>
          ssa_destroy_mark_reachable_region_tree(
            func, region_ref, reachable_nodes,
          )
        None => ()
      }
    }
    HotOp::TryTable => {
      ssa_destroy_mark_reachable_region_tree(
        func,
        hot_region_body_ref(func, node_id),
        reachable_nodes,
      )
      ssa_destroy_mark_reachable_region_tree(
        func,
        hot_region_catch_list_ref(func, node_id),
        reachable_nodes,
      )
    }
    _ => ()
  }
}

///|
fn ssa_destroy_mark_reachable_region_tree(
  func : HotFunc,
  region_ref : HotRegionRef,
  reachable_nodes : Array[Bool],
) -> Unit {
  for idx = 0; idx < hot_region_root_count(func, region_ref); idx = idx + 1 {
    ssa_destroy_mark_reachable_node_tree(
      func,
      hot_region_get(func, region_ref, idx),
      reachable_nodes,
    )
  }
}

///|
fn ssa_destroy_region_may_fall_through(
  func : HotFunc,
  region_ref : HotRegionRef,
) -> Bool {
  let mut reachable = true
  for idx = 0; idx < hot_region_root_count(func, region_ref); idx = idx + 1 {
    if !reachable {
      break
    }
    reachable = ssa_destroy_node_may_fall_through(
      func,
      hot_region_get(func, region_ref, idx),
    )
  }
  reachable
}

///|
fn ssa_destroy_node_may_fall_through(func : HotFunc, node_id : NodeId) -> Bool {
  if node_id == HOT_NONE_NODE || !hot_node_is_live(func, node_id) {
    return true
  }
  let node = hot_node_get(func, node_id)
  if cfg_op_is_terminator(node.op) {
    return false
  }
  match node.op {
    HotOp::Block =>
      ssa_destroy_region_may_fall_through(
        func,
        hot_region_body_ref(func, node_id),
      )
    HotOp::If => {
      let then_falls = ssa_destroy_region_may_fall_through(
        func,
        hot_region_then_ref(func, node_id),
      )
      let else_falls = match hot_region_else_ref(func, node_id) {
        Some(region_ref) =>
          ssa_destroy_region_may_fall_through(func, region_ref)
        None => true
      }
      then_falls || else_falls
    }
    _ => true
  }
}

///|
fn ssa_destroy_reachable_nodes(func : HotFunc) -> Array[Bool] {
  let reachable_nodes = Array::make(hot_node_count(func), false)
  let mut root_reachable = true
  for idx = 0; idx < hot_root_count(func); idx = idx + 1 {
    if !root_reachable {
      break
    }
    let root_id = hot_root_get(func, idx)
    ssa_destroy_mark_reachable_node_tree(func, root_id, reachable_nodes)
    root_reachable = ssa_destroy_node_may_fall_through(func, root_id)
  }
  reachable_nodes
}

///|
fn ssa_destroy_mark_block_region(
  func : HotFunc,
  region_ref : HotRegionRef,
  block_id : Int,
  node_blocks : Array[Int],
) -> Unit {
  for idx = 0; idx < hot_region_root_count(func, region_ref); idx = idx + 1 {
    ssa_destroy_mark_block_node(
      func,
      hot_region_get(func, region_ref, idx),
      block_id,
      node_blocks,
    )
  }
}

///|
fn ssa_destroy_mark_block_node(
  func : HotFunc,
  node_id : NodeId,
  block_id : Int,
  node_blocks : Array[Int],
) -> Unit {
  if node_id == HOT_NONE_NODE || !hot_node_is_live(func, node_id) {
    return
  }
  if node_blocks[node_id] < 0 {
    node_blocks[node_id] = block_id
  }
  let node = hot_node_get(func, node_id)
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    if ssa_destroy_is_region_slot(node.op, slot) {
      continue
    }
    ssa_destroy_mark_block_node(
      func,
      hot_child_get(func, node_id, slot),
      block_id,
      node_blocks,
    )
  }
  match node.op {
    HotOp::Block | HotOp::Loop =>
      ssa_destroy_mark_block_region(
        func,
        hot_region_body_ref(func, node_id),
        block_id,
        node_blocks,
      )
    HotOp::If => {
      ssa_destroy_mark_block_region(
        func,
        hot_region_then_ref(func, node_id),
        block_id,
        node_blocks,
      )
      match hot_region_else_ref(func, node_id) {
        Some(region_ref) =>
          ssa_destroy_mark_block_region(func, region_ref, block_id, node_blocks)
        None => ()
      }
    }
    HotOp::Try => {
      ssa_destroy_mark_block_region(
        func,
        hot_region_body_ref(func, node_id),
        block_id,
        node_blocks,
      )
      match hot_region_catch_ref(func, node_id) {
        Some(region_ref) =>
          ssa_destroy_mark_block_region(func, region_ref, block_id, node_blocks)
        None => ()
      }
    }
    HotOp::TryTable => {
      ssa_destroy_mark_block_region(
        func,
        hot_region_body_ref(func, node_id),
        block_id,
        node_blocks,
      )
      ssa_destroy_mark_block_region(
        func,
        hot_region_catch_list_ref(func, node_id),
        block_id,
        node_blocks,
      )
    }
    _ => ()
  }
}

///|
fn ssa_destroy_node_blocks(func : HotFunc) -> Array[Int] {
  let cfg = cfg_build(func)
  let node_blocks = Array::make(hot_node_count(func), -1)
  for block in cfg.blocks {
    for node_id in block.nodes {
      ssa_destroy_mark_block_node(func, node_id, block.id, node_blocks)
    }
  }
  node_blocks
}

///|
fn ssa_destroy_node_contains_terminator(
  func : HotFunc,
  node_id : NodeId,
) -> Bool {
  if node_id == HOT_NONE_NODE || !hot_node_is_live(func, node_id) {
    return false
  }
  let node = hot_node_get(func, node_id)
  if cfg_op_is_terminator(node.op) {
    return true
  }
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    if ssa_destroy_is_region_slot(node.op, slot) {
      continue
    }
    if ssa_destroy_node_contains_terminator(
        func,
        hot_child_get(func, node_id, slot),
      ) {
      return true
    }
  }
  match node.op {
    HotOp::Block | HotOp::Loop =>
      for idx = 0
          idx < hot_region_root_count(func, hot_region_body_ref(func, node_id))
          idx = idx + 1 {
        if ssa_destroy_node_contains_terminator(
            func,
            hot_region_get(func, hot_region_body_ref(func, node_id), idx),
          ) {
          return true
        }
      }
    HotOp::If => {
      let then_ref = hot_region_then_ref(func, node_id)
      for idx = 0; idx < hot_region_root_count(func, then_ref); idx = idx + 1 {
        if ssa_destroy_node_contains_terminator(
            func,
            hot_region_get(func, then_ref, idx),
          ) {
          return true
        }
      }
      match hot_region_else_ref(func, node_id) {
        Some(else_ref) =>
          for idx = 0
              idx < hot_region_root_count(func, else_ref)
              idx = idx + 1 {
            if ssa_destroy_node_contains_terminator(
                func,
                hot_region_get(func, else_ref, idx),
              ) {
              return true
            }
          }
        None => ()
      }
    }
    HotOp::Try => {
      let body_ref = hot_region_body_ref(func, node_id)
      for idx = 0; idx < hot_region_root_count(func, body_ref); idx = idx + 1 {
        if ssa_destroy_node_contains_terminator(
            func,
            hot_region_get(func, body_ref, idx),
          ) {
          return true
        }
      }
      match hot_region_catch_ref(func, node_id) {
        Some(catch_ref) =>
          for idx = 0
              idx < hot_region_root_count(func, catch_ref)
              idx = idx + 1 {
            if ssa_destroy_node_contains_terminator(
                func,
                hot_region_get(func, catch_ref, idx),
              ) {
              return true
            }
          }
        None => ()
      }
    }
    HotOp::TryTable => {
      let body_ref = hot_region_body_ref(func, node_id)
      for idx = 0; idx < hot_region_root_count(func, body_ref); idx = idx + 1 {
        if ssa_destroy_node_contains_terminator(
            func,
            hot_region_get(func, body_ref, idx),
          ) {
          return true
        }
      }
      let catches_ref = hot_region_catch_list_ref(func, node_id)
      for idx = 0; idx < hot_region_root_count(func, catches_ref); idx = idx + 1 {
        if ssa_destroy_node_contains_terminator(
            func,
            hot_region_get(func, catches_ref, idx),
          ) {
          return true
        }
      }
    }
    _ => ()
  }
  false
}

///|
fn ssa_destroy_mark_root_slot_node(
  func : HotFunc,
  node_id : NodeId,
  root_slot : Int,
  node_root_slots : Array[Int],
) -> Unit {
  if node_id == HOT_NONE_NODE || !hot_node_is_live(func, node_id) {
    return
  }
  if node_root_slots[node_id] >= 0 {
    return
  }
  node_root_slots[node_id] = root_slot
  let node = hot_node_get(func, node_id)
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    if ssa_destroy_is_region_slot(node.op, slot) {
      continue
    }
    ssa_destroy_mark_root_slot_node(
      func,
      hot_child_get(func, node_id, slot),
      root_slot,
      node_root_slots,
    )
  }
  match node.op {
    HotOp::Block | HotOp::Loop =>
      ssa_destroy_mark_root_slot_region(
        func,
        hot_region_body_ref(func, node_id),
        root_slot,
        node_root_slots,
      )
    HotOp::If => {
      ssa_destroy_mark_root_slot_region(
        func,
        hot_region_then_ref(func, node_id),
        root_slot,
        node_root_slots,
      )
      match hot_region_else_ref(func, node_id) {
        Some(region_ref) =>
          ssa_destroy_mark_root_slot_region(
            func, region_ref, root_slot, node_root_slots,
          )
        None => ()
      }
    }
    HotOp::Try => {
      ssa_destroy_mark_root_slot_region(
        func,
        hot_region_body_ref(func, node_id),
        root_slot,
        node_root_slots,
      )
      match hot_region_catch_ref(func, node_id) {
        Some(region_ref) =>
          ssa_destroy_mark_root_slot_region(
            func, region_ref, root_slot, node_root_slots,
          )
        None => ()
      }
    }
    HotOp::TryTable => {
      ssa_destroy_mark_root_slot_region(
        func,
        hot_region_body_ref(func, node_id),
        root_slot,
        node_root_slots,
      )
      ssa_destroy_mark_root_slot_region(
        func,
        hot_region_catch_list_ref(func, node_id),
        root_slot,
        node_root_slots,
      )
    }
    _ => ()
  }
}

///|
fn ssa_destroy_mark_root_slot_region(
  func : HotFunc,
  region_ref : HotRegionRef,
  root_slot : Int,
  node_root_slots : Array[Int],
) -> Unit {
  for idx = 0; idx < hot_region_root_count(func, region_ref); idx = idx + 1 {
    ssa_destroy_mark_root_slot_node(
      func,
      hot_region_get(func, region_ref, idx),
      root_slot,
      node_root_slots,
    )
  }
}

///|
fn ssa_destroy_node_root_slots(func : HotFunc) -> Array[Int] {
  let node_root_slots = Array::make(hot_node_count(func), -1)
  for root_slot = 0; root_slot < hot_root_count(func); root_slot = root_slot + 1 {
    ssa_destroy_mark_root_slot_node(
      func,
      hot_root_get(func, root_slot),
      root_slot,
      node_root_slots,
    )
  }
  node_root_slots
}

///|
fn ssa_destroy_root_slot_range(
  node_root_slots : Array[Int],
  start_node_id : NodeId,
  end_node_id : NodeId,
) -> (Int, Int) {
  if start_node_id < 0 ||
    start_node_id >= node_root_slots.length() ||
    end_node_id < 0 ||
    end_node_id >= node_root_slots.length() {
    return (-1, -1)
  }
  let start_root_slot = node_root_slots[start_node_id]
  let end_root_slot = node_root_slots[end_node_id]
  if start_root_slot < 0 ||
    end_root_slot < 0 ||
    end_root_slot <= start_root_slot {
    return (-1, -1)
  }
  (start_root_slot, end_root_slot)
}

///|
fn ssa_destroy_has_branchy_root_between(
  func : HotFunc,
  node_root_slots : Array[Int],
  start_node_id : NodeId,
  end_node_id : NodeId,
) -> Bool {
  let (start_root_slot, end_root_slot) = ssa_destroy_root_slot_range(
    node_root_slots, start_node_id, end_node_id,
  )
  if start_root_slot < 0 {
    return false
  }
  for root_slot = start_root_slot + 1
      root_slot < end_root_slot
      root_slot = root_slot + 1 {
    let root_id = hot_root_get(func, root_slot)
    if hot_is_control_node(func, root_id) &&
      ssa_destroy_node_contains_terminator(func, root_id) {
      return true
    }
  }
  false
}

///|
fn ssa_destroy_has_value_block_root_between(
  func : HotFunc,
  node_root_slots : Array[Int],
  start_node_id : NodeId,
  end_node_id : NodeId,
) -> Bool {
  let (start_root_slot, end_root_slot) = ssa_destroy_root_slot_range(
    node_root_slots, start_node_id, end_node_id,
  )
  if start_root_slot < 0 {
    return false
  }
  let void_ty = hot_type_void(func)
  for root_slot = start_root_slot + 1
      root_slot < end_root_slot
      root_slot = root_slot + 1 {
    let root_id = hot_root_get(func, root_slot)
    let root = hot_node_get(func, root_id)
    if root.op == HotOp::Block && root.ty != void_ty {
      return true
    }
  }
  false
}

///|
fn ssa_destroy_has_live_parent(func : HotFunc, node_id : NodeId) -> Bool {
  for parent_id = 0; parent_id < hot_node_count(func); parent_id = parent_id + 1 {
    if !hot_node_is_live(func, parent_id) {
      continue
    }
    let parent = hot_node_get(func, parent_id)
    for slot = 0; slot < parent.child_count; slot = slot + 1 {
      if ssa_destroy_is_region_slot(parent.op, slot) {
        continue
      }
      if hot_child_get(func, parent_id, slot) == node_id {
        return true
      }
    }
  }
  false
}

///|
fn ssa_destroy_should_preserve_dead_write_local(
  func : HotFunc,
  node_id : NodeId,
  local_id : LocalId,
  node_order : Array[Int],
  node_blocks : Array[Int],
  node_root_slots : Array[Int],
  reachable_nodes : Array[Bool],
) -> Bool {
  let write_order = node_order[node_id]
  if write_order < 0 {
    return false
  }
  let write_block = node_blocks[node_id]
  for candidate_id = 0
      candidate_id < hot_node_count(func)
      candidate_id = candidate_id + 1 {
    if !hot_node_is_live(func, candidate_id) ||
      reachable_nodes[candidate_id] ||
      node_order[candidate_id] <= write_order {
      continue
    }
    let candidate = hot_node_get(func, candidate_id)
    if (candidate.op == HotOp::LocalSet || candidate.op == HotOp::LocalTee) &&
      candidate.imm0 == local_id &&
      node_blocks[candidate_id] == write_block {
      break
    }
    if candidate.op == HotOp::LocalGet &&
      candidate.imm0 == local_id &&
      ssa_destroy_has_branchy_root_between(
        func, node_root_slots, node_id, candidate_id,
      ) {
      return true
    }
  }
  false
}

///|
fn ssa_destroy_should_keep_dead_tee_temp(
  func : HotFunc,
  node_id : NodeId,
  original_local_id : LocalId,
  node_order : Array[Int],
  node_root_slots : Array[Int],
  reachable_nodes : Array[Bool],
) -> Bool {
  let write_order = node_order[node_id]
  if write_order < 0 || original_local_id < 0 {
    return false
  }
  for candidate_id = 0
      candidate_id < hot_node_count(func)
      candidate_id = candidate_id + 1 {
    if !hot_node_is_live(func, candidate_id) ||
      reachable_nodes[candidate_id] ||
      node_order[candidate_id] <= write_order {
      continue
    }
    let candidate = hot_node_get(func, candidate_id)
    if candidate.op == HotOp::LocalGet &&
      candidate.imm0 == original_local_id &&
      ssa_destroy_has_live_parent(func, candidate_id) &&
      ssa_destroy_has_value_block_root_between(
        func, node_root_slots, node_id, candidate_id,
      ) &&
      !ssa_destroy_has_branchy_root_between(
        func, node_root_slots, node_id, candidate_id,
      ) {
      return true
    }
  }
  false
}

///|
fn ssa_destroy_has_value_if_order_between(
  func : HotFunc,
  node_order : Array[Int],
  start_node_id : NodeId,
  end_node_id : NodeId,
) -> Bool {
  let start_order = node_order[start_node_id]
  let end_order = node_order[end_node_id]
  if start_order < 0 || end_order <= start_order {
    return false
  }
  let void_ty = hot_type_void(func)
  for candidate_id = 0
      candidate_id < hot_node_count(func)
      candidate_id = candidate_id + 1 {
    if !hot_node_is_live(func, candidate_id) ||
      node_order[candidate_id] <= start_order ||
      node_order[candidate_id] >= end_order {
      continue
    }
    let candidate = hot_node_get(func, candidate_id)
    if candidate.op == HotOp::If && candidate.ty != void_ty {
      return true
    }
  }
  false
}

///|
fn ssa_destroy_has_branchy_root_after(
  func : HotFunc,
  node_root_slots : Array[Int],
  node_id : NodeId,
) -> Bool {
  if node_id < 0 || node_id >= node_root_slots.length() {
    return false
  }
  let start_root_slot = node_root_slots[node_id]
  if start_root_slot < 0 {
    return false
  }
  for root_slot = start_root_slot + 1
      root_slot < hot_root_count(func)
      root_slot = root_slot + 1 {
    let root_id = hot_root_get(func, root_slot)
    if hot_is_control_node(func, root_id) &&
      ssa_destroy_node_contains_terminator(func, root_id) {
      return true
    }
  }
  false
}

///|
fn ssa_destroy_should_reuse_original_dead_tee_local(
  func : HotFunc,
  node_id : NodeId,
  original_local_id : LocalId,
  node_order : Array[Int],
  node_root_slots : Array[Int],
  reachable_nodes : Array[Bool],
) -> Bool {
  let write_order = node_order[node_id]
  if write_order < 0 || original_local_id < 0 || reachable_nodes[node_id] {
    return false
  }
  let rewritten_local_id = hot_node_get(func, node_id).imm0
  for candidate_id = 0
      candidate_id < hot_node_count(func)
      candidate_id = candidate_id + 1 {
    if !hot_node_is_live(func, candidate_id) ||
      reachable_nodes[candidate_id] ||
      node_order[candidate_id] <= write_order {
      continue
    }
    let candidate = hot_node_get(func, candidate_id)
    if candidate.op == HotOp::LocalGet &&
      (
        candidate.imm0 == original_local_id ||
        candidate.imm0 == rewritten_local_id
      ) &&
      ssa_destroy_has_live_parent(func, candidate_id) &&
      ssa_destroy_has_value_if_order_between(
        func, node_order, node_id, candidate_id,
      ) &&
      !ssa_destroy_has_branchy_root_between(
        func, node_root_slots, node_id, candidate_id,
      ) &&
      ssa_destroy_has_branchy_root_after(func, node_root_slots, candidate_id) {
      return true
    }
  }
  false
}

///|
fn ssa_destroy_rewrite_unreachable_local_gets_after(
  func : HotFunc,
  node_id : NodeId,
  from_local_id : LocalId,
  to_local_id : LocalId,
  node_root_slots : Array[Int],
  reachable_nodes : Array[Bool],
) -> Unit {
  if node_id < 0 ||
    node_id >= node_root_slots.length() ||
    node_root_slots[node_id] < 0 ||
    from_local_id == to_local_id {
    return
  }
  let start_root_slot = node_root_slots[node_id]
  for candidate_id = 0
      candidate_id < hot_node_count(func)
      candidate_id = candidate_id + 1 {
    if !hot_node_is_live(func, candidate_id) ||
      reachable_nodes[candidate_id] ||
      candidate_id >= node_root_slots.length() ||
      node_root_slots[candidate_id] <= start_root_slot {
      continue
    }
    let candidate = hot_node_get(func, candidate_id)
    if candidate.op == HotOp::LocalGet && candidate.imm0 == from_local_id {
      ssa_rewrite_local_use(func, candidate_id, to_local_id)
    }
  }
}

///|
fn ssa_destroy_last_local_get_orders(
  func : HotFunc,
) -> (Array[Int], Array[Int]) {
  let node_order = Array::make(hot_node_count(func), -1)
  ignore(
    ssa_destroy_assign_node_order_region(
      func,
      HotRegionRef::root(),
      node_order,
      0,
    ),
  )
  let reachable_nodes = ssa_destroy_reachable_nodes(func)
  let last_local_get_order = Array::make(hot_local_count(func), -1)
  for node_id = 0; node_id < hot_node_count(func); node_id = node_id + 1 {
    if node_order[node_id] < 0 ||
      !hot_node_is_live(func, node_id) ||
      !reachable_nodes[node_id] {
      continue
    }
    let node = hot_node_get(func, node_id)
    if node.op != HotOp::LocalGet ||
      node.imm0 < 0 ||
      node.imm0 >= last_local_get_order.length() {
      continue
    }
    if last_local_get_order[node.imm0] < node_order[node_id] {
      last_local_get_order[node.imm0] = node_order[node_id]
    }
  }
  (node_order, last_local_get_order)
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
fn ssa_trim_unused_trailing_temp_locals(
  func : HotFunc,
  original_local_count : Int,
) -> Unit {
  let mut max_used_local = hot_param_count(func) - 1
  for node_id = 0; node_id < hot_node_count(func); node_id = node_id + 1 {
    if !hot_node_is_live(func, node_id) {
      continue
    }
    let node = hot_node_get(func, node_id)
    match node.op {
      HotOp::LocalGet | HotOp::LocalSet | HotOp::LocalTee =>
        if node.imm0 > max_used_local {
          max_used_local = node.imm0
        }
      _ => ()
    }
  }
  while hot_local_count(func) > original_local_count {
    let trailing_local_id = hot_local_count(func) - 1
    if trailing_local_id <= max_used_local {
      break
    }
    ignore(func.locals.locals.pop())
    hot_revision_bump(func)
  }
}

///|
pub fn ssa_remove_dead_local_defs(
  func : HotFunc,
  dead_nodes : Array[NodeId],
) -> Unit {
  let seen = Array::make(hot_node_count(func), false)
  let (node_order, last_local_get_order) = ssa_destroy_last_local_get_orders(
    func,
  )
  for node_id in dead_nodes {
    if node_id < 0 || node_id >= seen.length() || seen[node_id] {
      continue
    }
    seen[node_id] = true
    let node = hot_node_get(func, node_id)
    let local_id = match node.op {
      HotOp::LocalSet | HotOp::LocalTee => node.imm0
      _ => -1
    }
    if local_id >= 0 &&
      local_id < last_local_get_order.length() &&
      node_order[node_id] >= 0 &&
      last_local_get_order[local_id] > node_order[node_id] {
      continue
    }
    match node.op {
      HotOp::LocalSet =>
        hot_replace_node(func, node_id, {
          ..node,
          op: HotOp::Drop,
          ty: hot_type_void(func),
          imm0: 0,
          imm1: 0,
        })
      HotOp::LocalTee => ()
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
  preserve_write_nodes? : @bitset.BitSet = @bitset.BitSet::new(0),
) -> HotSsaConcreteLocals {
  ignore(policy)
  let original_local_count = hot_local_count(func)
  let concrete = ssa_assign_concrete_locals(func, ssa, preserve_write_nodes~)
  for ty in concrete.extra_local_types {
    ignore(hot_append_body_local(func, ty))
  }

  let original_write_locals = Array::make(ssa.local_write_defs.length(), -1)
  for node_id = 0
      node_id < ssa.local_write_defs.length()
      node_id = node_id + 1 {
    if !hot_node_is_live(func, node_id) {
      continue
    }
    match hot_node_get(func, node_id).op {
      HotOp::LocalSet | HotOp::LocalTee =>
        original_write_locals[node_id] = hot_node_get(func, node_id).imm0
      _ => ()
    }
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
  let (node_order, last_local_get_order) = ssa_destroy_last_local_get_orders(
    func,
  )
  let node_blocks = ssa_destroy_node_blocks(func)
  let node_root_slots = ssa_destroy_node_root_slots(func)
  let reachable_nodes = ssa_destroy_reachable_nodes(func)
  for node_id = 0
      node_id < ssa.local_write_defs.length()
      node_id = node_id + 1 {
    if ssa.local_write_defs[node_id] >= 0 || !hot_node_is_live(func, node_id) {
      continue
    }
    let node = hot_node_get(func, node_id)
    match node.op {
      HotOp::LocalSet | HotOp::LocalTee => {
        if node.imm0 >= 0 &&
          node.imm0 < last_local_get_order.length() &&
          (
            (
              node_order[node_id] >= 0 &&
              last_local_get_order[node.imm0] > node_order[node_id]
            ) ||
            ssa_destroy_should_preserve_dead_write_local(
              func,
              node_id,
              node.imm0,
              node_order,
              node_blocks,
              node_root_slots,
              reachable_nodes,
            ) ||
            (
              node.op == HotOp::LocalTee &&
              ssa_destroy_should_reuse_original_dead_tee_local(
                func,
                node_id,
                node.imm0,
                node_order,
                node_root_slots,
                reachable_nodes,
              )
            )
          ) {
          continue
        }
        let fresh_local = hot_append_body_local(
          func,
          ssa_destroy_local_type(func, node.imm0),
        )
        ssa_rewrite_local_use(func, node_id, fresh_local)
        dead_nodes.push(node_id)
      }
      _ => ()
    }
  }
  for value_id = 0
      value_id < ssa.value_origins.length()
      value_id = value_id + 1 {
    if ssa.value_uses[value_id].length() != 0 {
      continue
    }
    match ssa.value_origins[value_id] {
      HotSsaValueOrigin::LocalSetDef(node_id) => dead_nodes.push(node_id)
      HotSsaValueOrigin::LocalTeeDef(node_id) =>
        if ssa_destroy_should_reuse_original_dead_tee_local(
            func,
            node_id,
            original_write_locals[node_id],
            node_order,
            node_root_slots,
            reachable_nodes,
          ) {
          let rewritten_local_id = hot_node_get(func, node_id).imm0
          ssa_rewrite_local_use(func, node_id, original_write_locals[node_id])
          ssa_destroy_rewrite_unreachable_local_gets_after(
            func,
            node_id,
            rewritten_local_id,
            original_write_locals[node_id],
            node_root_slots,
            reachable_nodes,
          )
        } else if !ssa_destroy_should_keep_dead_tee_temp(
            func,
            node_id,
            original_write_locals[node_id],
            node_order,
            node_root_slots,
            reachable_nodes,
          ) {
          dead_nodes.push(node_id)
        }
      _ => ()
    }
  }
  ssa_remove_dead_local_defs(func, dead_nodes)
  ssa_trim_unused_trailing_temp_locals(func, original_local_count)
  concrete
}
