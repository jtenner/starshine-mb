///|
fn local_graph_tuple_reference_nested_region(
  func : HotFunc,
  local_count : Int,
  region : HotRegionRef,
  state : Array[Array[Int]],
  get_sources : LocalGraphSourceRecorder?,
  write_influences : Array[Array[NodeId]]?,
  evaluated_tuples : Array[Bool],
) -> Unit {
  for idx = 0; idx < hot_region_root_count(func, region); idx = idx + 1 {
    local_graph_tuple_reference_node(
      func,
      local_count,
      hot_region_get(func, region, idx),
      state,
      get_sources,
      write_influences,
      true,
      evaluated_tuples,
    )
  }
}

///|
fn local_graph_tuple_reference_node(
  func : HotFunc,
  local_count : Int,
  node_id : NodeId,
  state : Array[Array[Int]],
  get_sources : LocalGraphSourceRecorder?,
  write_influences : Array[Array[NodeId]]?,
  traverse_nested_blocks : Bool,
  evaluated_tuples : Array[Bool],
) -> Unit {
  if node_id == HOT_NONE_NODE || !hot_node_is_live(func, node_id) {
    return
  }
  let node = hot_node_get(func, node_id)
  // Multiple stack lanes name one evaluation of their producer. Replaying
  // the producer per lane invents local definitions and expands tuple-valued
  // control trees exponentially. Keep this state per execution path.
  let is_tuple = match hot_type_get(func, node.ty) {
    Results(values) | BlockResultResolved(_, _, values) => values.length() > 1
    _ => false
  }
  if traverse_nested_blocks && is_tuple {
    if evaluated_tuples[node_id] {
      return
    }
    evaluated_tuples[node_id] = true
  }
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    if local_graph_is_region_slot(node, slot) {
      continue
    }
    local_graph_tuple_reference_node(
      func,
      local_count,
      hot_child_get(func, node_id, slot),
      state,
      get_sources,
      write_influences,
      true,
      evaluated_tuples,
    )
  }
  if traverse_nested_blocks {
    match node.op {
      HotOp::If => {
        let yes = local_graph_state_clone(state)
        let no = local_graph_state_clone(state)
        let yes_tuples = evaluated_tuples.copy()
        let no_tuples = evaluated_tuples.copy()
        let yes_region = hot_region_then_ref(func, node_id)
        for idx = 0
            idx < hot_region_root_count(func, yes_region)
            idx = idx + 1 {
          local_graph_tuple_reference_node(
            func,
            local_count,
            hot_region_get(func, yes_region, idx),
            yes,
            get_sources,
            write_influences,
            true,
            yes_tuples,
          )
        }
        if hot_region_else_ref(func, node_id) is Some(no_region) {
          for idx = 0
              idx < hot_region_root_count(func, no_region)
              idx = idx + 1 {
            local_graph_tuple_reference_node(
              func,
              local_count,
              hot_region_get(func, no_region, idx),
              no,
              get_sources,
              write_influences,
              true,
              no_tuples,
            )
          }
        }
        for id = 0; id < evaluated_tuples.length(); id = id + 1 {
          evaluated_tuples[id] = yes_tuples[id] && no_tuples[id]
        }
        for local_id = 0; local_id < local_count; local_id = local_id + 1 {
          state[local_id] = local_graph_join_sources(
            yes[local_id],
            no[local_id],
          )
        }
      }
      HotOp::Block =>
        if local_graph_nested_operand_can_transfer(func, node_id) {
          local_graph_tuple_reference_nested_region(
            func,
            local_count,
            hot_region_body_ref(func, node_id),
            state,
            get_sources,
            write_influences,
            evaluated_tuples,
          )
        } else {
          local_graph_transfer_unknown_control(
            func, local_count, node_id, state, get_sources, write_influences,
          )
        }
      HotOp::Loop | HotOp::Try | HotOp::TryTable =>
        local_graph_transfer_unknown_control(
          func, local_count, node_id, state, get_sources, write_influences,
        )
      _ => ()
    }
  }
  match node.op {
    HotOp::LocalGet =>
      local_graph_record_get_sources(
        local_count,
        node_id,
        state[node.imm0],
        get_sources,
        write_influences,
      )
    HotOp::LocalSet | HotOp::LocalTee =>
      state[node.imm0] = [local_graph_set_source_id(local_count, node_id)]
    _ => ()
  }
}

///|
fn local_graph_tuple_reference_block(
  func : HotFunc,
  cfg : HotCfg,
  block_id : BlockId,
  in_state : Array[Array[Int]],
  get_sources : LocalGraphSourceRecorder?,
  write_influences : Array[Array[NodeId]]?,
  tuple_slots? : Array[Int]? = None,
) -> Array[Array[Int]] {
  let state = local_graph_state_clone(in_state)
  // Expanded CFGs already visit each tuple producer at its execution position.
  // Only recursive, unexpanded traversal needs per-producer bookkeeping.
  let evaluated_tuples = if cfg.operands_expanded {
    []
  } else {
    Array::make(hot_node_count(func), false)
  }
  match tuple_slots {
    Some(count) => count[0] += evaluated_tuples.length()
    None => ()
  }
  for node_id in cfg_block_get(cfg, block_id).nodes {
    if cfg.operands_expanded {
      // The CFG already lists each operand at its execution position.
      // Descending again invents extra reads and writes across control edges.
      let node = hot_node_get(func, node_id)
      match node.op {
        HotOp::LocalGet =>
          local_graph_record_get_sources(
            hot_local_count(func),
            node_id,
            state[node.imm0],
            get_sources,
            write_influences,
          )
        HotOp::LocalSet | HotOp::LocalTee =>
          state[node.imm0] = [
            local_graph_set_source_id(hot_local_count(func), node_id),
          ]
        _ => ()
      }
      continue
    }
    local_graph_tuple_reference_node(
      func,
      hot_local_count(func),
      node_id,
      state,
      get_sources,
      write_influences,
      false,
      evaluated_tuples,
    )
  }
  state
}
