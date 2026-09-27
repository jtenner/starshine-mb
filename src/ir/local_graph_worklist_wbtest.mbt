///|
fn local_graph_rounds_reference(
  func : HotFunc,
  cfg : HotCfg,
  include_exceptional : Bool,
  block_transfers? : Array[Int]? = None,
) -> Array[Array[Array[Int]]] {
  let local_count = hot_local_count(func)
  let in_states : Array[Array[Array[Int]]] = []
  let out_states : Array[Array[Array[Int]]] = []
  for _ in 0..<cfg_block_count(cfg) {
    in_states.push(local_graph_empty_state(local_count))
    out_states.push(local_graph_empty_state(local_count))
  }
  let entry_state = local_graph_entry_state(local_count)
  in_states[cfg_entry_block(cfg)] = entry_state
  let mut changed = true
  let mut first_round = true
  while changed {
    changed = false
    for block_id = 0; block_id < cfg_block_count(cfg); block_id = block_id + 1 {
      let next_in = if block_id == cfg_entry_block(cfg) {
        entry_state
      } else {
        local_graph_merge_predecessors(
          cfg, block_id, local_count, out_states, include_exceptional,
        )
      }
      let input_changed = !local_graph_state_equal(in_states[block_id], next_in)
      if input_changed {
        in_states[block_id] = next_in
        changed = true
      }
      // Transfers read a fixed function/CFG and mutate only their cloned state.
      // An unchanged input therefore retains the previous output exactly.
      if first_round || input_changed {
        match block_transfers {
          Some(count) => count[0] += 1
          None => ()
        }
        let next_out = local_graph_transfer_block(
          func,
          cfg,
          block_id,
          in_states[block_id],
          None,
          None,
        )
        if !local_graph_state_equal(out_states[block_id], next_out) {
          out_states[block_id] = next_out
          changed = true
        }
      }
    }
    first_round = false
  }
  in_states
}

///|
test "local-flow worklist avoids stable predecessor merges with exact source states" {
  let (func, writes, _) = local_graph_query_fixture(4, 16)
  for expanded in [false, true] {
    let cfg = cfg_build(func, expand_operand_control=expanded)
    let merges = [0]
    let states = local_graph_build_in_states(
      func,
      cfg,
      true,
      block_merges=Some(merges),
    )
    assert_eq(states, local_graph_rounds_reference(func, cfg, true))
    for local in 0..<4 {
      assert_eq(states[cfg.exit_block][local], [
        local_graph_set_source_id(16, writes[local]),
      ])
    }
    assert_eq(states[cfg.exit_block][15], [local_graph_entry_source_id(15)])
    // CFG exit/region blocks can precede their inputs in block order. Allow
    // their required revisit while bounding unrelated stable merges.
    assert_true(
      merges[0] <= 2 * cfg_block_count(cfg),
      msg="predecessor merges: \{merges[0]}, blocks: \{cfg_block_count(cfg)}",
    )
  }
}

///|
test "local-flow worklist preserves cyclic joins and exceptional edge selection" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let write = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(9)),
  )
  let read = hot_build_drop(func, hot_build_local_get(func, 0))
  let builder = cfg_builder_new(func, true, false)
  let entry = cfg_builder_add_block(builder, [], true)
  let exit = cfg_builder_add_block(builder, [], true)
  let header = cfg_builder_add_block(builder, [read], false)
  let body = cfg_builder_add_block(builder, [write], false)
  let handler = cfg_builder_add_block(builder, [], true)
  builder.cfg.entry_block = entry
  builder.cfg.exit_block = exit
  cfg_builder_add_edge(builder, entry, header, CfgEdgeKind::FallthroughEdge)
  cfg_builder_add_edge(builder, header, body, CfgEdgeKind::FallthroughEdge)
  cfg_builder_add_edge(builder, body, header, CfgEdgeKind::FallthroughEdge)
  cfg_builder_add_edge(builder, header, exit, CfgEdgeKind::FallthroughEdge)
  cfg_builder_add_edge(builder, body, handler, CfgEdgeKind::ExceptionalEdge)
  for include_exceptional in [false, true] {
    let states = local_graph_build_in_states(
      func,
      builder.cfg,
      include_exceptional,
    )
    assert_eq(
      states,
      local_graph_rounds_reference(func, builder.cfg, include_exceptional),
    )
    assert_eq(states[header][0].length(), 2)
    assert_true(states[header][0].contains(local_graph_entry_source_id(0)))
    assert_true(states[header][0].contains(local_graph_set_source_id(2, write)))
    assert_eq(states[exit][1], [local_graph_entry_source_id(1)])
    assert_eq(
      states[handler][0],
      if include_exceptional {
        [local_graph_set_source_id(2, write)]
      } else {
        []
      },
    )
  }
}
