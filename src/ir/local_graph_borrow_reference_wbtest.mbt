///|
fn local_graph_borrow_reference_merge(
  cfg : HotCfg,
  block_id : BlockId,
  local_count : Int32,
  out_states : Array[Array[Array[Int32]]],
  include_exceptional : Bool,
) -> Array[Array[Int32]] {
  let merged = local_graph_empty_state(local_count)
  for pred in cfg_predecessor_edges(cfg, block_id) {
    if !include_exceptional && pred.kind == CfgEdgeKind::ExceptionalEdge {
      continue
    }
    let pred_state = out_states[pred.block]
    for local_id = 0; local_id < local_count; local_id = local_id + 1 {
      merged[local_id] = local_graph_borrow_reference_join(
        merged[local_id],
        pred_state[local_id],
      )
    }
  }
  merged
}

///|
fn local_graph_borrow_reference_join(
  lhs : Array[Int32],
  rhs : Array[Int32],
) -> Array[Int32] {
  if lhs.is_empty() {
    return rhs
  }
  if rhs.all(fn(source) { local_graph_array_contains(lhs, source) }) {
    return lhs
  }
  let merged = lhs.copy()
  ignore(local_graph_union_into(merged, rhs))
  merged
}
