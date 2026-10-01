///|
// Frozen V65 complete-header local-state traversal controls.

///|
fn access_fields_reference_child_count(func : HotFunc, node_id : NodeId) -> Int {
  let count = hot_child_count(func, node_id)
  match hot_node_get(func, node_id).op {
    HotOp::Block | HotOp::Loop => {
      // Dead region tails cannot observe or overwrite a carried value.
      for slot = 0; slot < count; slot = slot + 1 {
        let child = hot_child_get(func, node_id, slot)
        if child >= 0 &&
          hot_node_is_live(func, child) &&
          hot_is_terminator_node(func, child) {
          return slot + 1
        }
      }
      count
    }
    _ => count
  }
}

///|
fn access_fields_reference_nodes(
  func : HotFunc,
  node_id : NodeId,
  facts : HotSourceOrderFacts,
) -> Array[NodeId] {
  if facts.local_access_nodes[node_id] is Some(nodes) {
    return nodes
  }
  facts.local_access_stamp += 1
  let stamp = facts.local_access_stamp
  let accesses : Array[NodeId] = []
  fn visit(id : NodeId) -> Unit {
    if id < 0 ||
      facts.local_access_seen[id] == stamp ||
      !hot_node_is_live(func, id) {
      return
    }
    facts.local_access_seen[id] = stamp
    match hot_node_get(func, id).op {
      HotOp::LocalGet | HotOp::LocalSet | HotOp::LocalTee => accesses.push(id)
      _ => ()
    }
    let count = access_fields_reference_child_count(func, id)
    for slot = 0; slot < count; slot = slot + 1 {
      visit(hot_child_get(func, id, slot))
    }
  }
  visit(node_id)
  facts.local_access_nodes[node_id] = Some(accesses)
  accesses
}
