///|
// Frozen c2aec5040 mask/conflict workers; preserve complete-node reads.
fn lift_access_fields_original_collect_local_access_masks(
  func : HotFunc,
  node_id : NodeId,
  masks : HotLiftLocalAccessMasks,
  node_visits : Array[Int]?,
) -> Unit {
  while masks.ready.length() <= node_id {
    masks.reads.push(0UL)
    masks.writes.push(0UL)
    masks.ready.push(false)
  }
  if masks.ready[node_id] {
    return
  }
  match node_visits {
    Some(count) => count[0] += 1
    None => ()
  }
  let node = hot_node_get(func, node_id)
  let mut reads = 0UL
  let mut writes = 0UL
  match node.op {
    HotOp::LocalGet => reads = 1UL << (node.imm0 & 63)
    HotOp::LocalSet | HotOp::LocalTee => writes = 1UL << (node.imm0 & 63)
    _ => ()
  }
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    let child = hot_child_get(func, node_id, slot)
    if child >= 0 && hot_node_is_live(func, child) {
      lift_access_fields_original_collect_local_access_masks(
        func, child, masks, node_visits,
      )
      reads = reads | masks.reads[child]
      writes = writes | masks.writes[child]
    }
  }
  masks.reads[node_id] = reads
  masks.writes[node_id] = writes
  masks.ready[node_id] = true
}

///|
fn lift_access_fields_original_value_conflicts_with_local_access(
  func : HotFunc,
  node_id : NodeId,
  local_id : Int,
  is_write : Bool,
  masks? : HotLiftLocalAccessMasks? = None,
  node_visits? : Array[Int]? = None,
) -> Bool {
  if node_id < 0 || !hot_node_is_live(func, node_id) {
    return false
  }
  match node_visits {
    Some(count) => count[0] += 1
    None => ()
  }
  let node = hot_node_get(func, node_id)
  if node.imm0 == local_id {
    match node.op {
      HotOp::LocalSet | HotOp::LocalTee => return true
      HotOp::LocalGet if is_write => return true
      _ => ()
    }
  }
  if node.child_count == 0 {
    return false
  }
  match masks {
    Some(masks) => {
      lift_access_fields_original_collect_local_access_masks(
        func, node_id, masks, node_visits,
      )
      let mask = if is_write {
        masks.reads[node_id] | masks.writes[node_id]
      } else {
        masks.writes[node_id]
      }
      if (mask & (1UL << (local_id & 63))) == 0UL {
        return false
      }
    }
    None => ()
  }
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    if lift_access_fields_original_value_conflicts_with_local_access(
        func,
        hot_child_get(func, node_id, slot),
        local_id,
        is_write,
        masks~,
        node_visits~,
      ) {
      return true
    }
  }
  false
}
