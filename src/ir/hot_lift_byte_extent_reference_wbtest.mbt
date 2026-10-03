///|
fn lift_extent_reference_collect(
  func : HotFunc,
  node_id : NodeId,
  masks : HotLiftLocalAccessReferenceMasks,
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
  // Preserve checked admission while projecting the existing arena record
  // here, without a complete-node return boundary or a new view allocation.
  hot_node_require_live_read(func, node_id)
  let node = func.nodes[node_id]
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
      lift_extent_reference_collect(func, child, masks, node_visits)
      reads = reads | masks.reads[child]
      writes = writes | masks.writes[child]
    }
  }
  masks.reads[node_id] = reads
  masks.writes[node_id] = writes
  masks.ready[node_id] = true
}

///|
// Preserve both directions of a pending stack value's local dependency. A
// later write must not change its reads; a later read must see its writes.
// Explicit captures make these edges visible to every tree transform.
fn lift_extent_reference_conflict(
  func : HotFunc,
  node_id : NodeId,
  local_id : Int,
  is_write : Bool,
  masks? : HotLiftLocalAccessReferenceMasks? = None,
  node_visits? : Array[Int]? = None,
) -> Bool {
  if node_id < 0 || !hot_node_is_live(func, node_id) {
    return false
  }
  match node_visits {
    Some(count) => count[0] += 1
    None => ()
  }
  // Preserve checked admission while projecting the existing arena record
  // here, without a complete-node return boundary or a new view allocation.
  hot_node_require_live_read(func, node_id)
  let node = func.nodes[node_id]
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
      lift_extent_reference_collect(func, node_id, masks, node_visits)
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
    if lift_extent_reference_conflict(
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
