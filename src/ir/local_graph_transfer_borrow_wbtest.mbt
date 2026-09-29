///|
fn local_graph_transfer_borrow_fixture(
  func : HotFunc,
  nodes : Array[NodeId],
  expanded : Bool,
) -> HotCfg {
  let builder = cfg_builder_new(func, true, expanded)
  let block = cfg_builder_add_block(builder, nodes, true)
  builder.cfg.entry_block = block
  builder.cfg.exit_block = block
  builder.cfg
}

///|
test "expanded read-only transfer borrows input and records reaching writes" {
  let func = HotFunc::new(
    locals=HotLocals::new(locals=Array::make(4, @lib.ValType::i32())),
  )
  let write = hot_build_local_set(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  let read = hot_build_local_get(func, 1)
  let cfg = local_graph_transfer_borrow_fixture(func, [read], true)
  let incoming = local_graph_entry_state(4)
  incoming[1] = [1, local_graph_set_source_id(4, write)]
  let sources = Array::makei(hot_node_count(func), fn(_) { [] })
  let influences = Array::makei(hot_node_count(func), fn(_) { [] })
  let result = local_graph_transfer_block(
    func,
    cfg,
    cfg.entry_block,
    incoming,
    Some(LocalGraphSourceRecorder::new(sources)),
    Some(influences),
  )
  assert_eq(result, [[0], [1, local_graph_set_source_id(4, write)], [2], [3]])
  assert_eq(sources[read], incoming[1])
  assert_eq(influences[write], [read])
  assert_true(physical_equal(result, incoming))
}

///|
test "expanded transfer owns its first write and preserves sibling sources" {
  let func = HotFunc::new(
    locals=HotLocals::new(locals=Array::make(4, @lib.ValType::i32())),
  )
  let first = hot_build_local_set(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  let between = hot_build_local_get(func, 1)
  let second = hot_build_local_tee(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(9)),
  )
  let after = hot_build_local_get(func, 1)
  let cfg = local_graph_transfer_borrow_fixture(
    func,
    [first, between, second, after],
    true,
  )
  let incoming = local_graph_entry_state(4)
  let sibling_cfg = local_graph_transfer_borrow_fixture(func, [after], true)
  let sibling_sources = Array::makei(hot_node_count(func), fn(_) { [] })
  let sources = Array::makei(hot_node_count(func), fn(_) { [] })
  let influences = Array::makei(hot_node_count(func), fn(_) { [] })
  let result = local_graph_transfer_block(
    func,
    cfg,
    cfg.entry_block,
    incoming,
    Some(LocalGraphSourceRecorder::new(sources)),
    Some(influences),
  )
  let sibling = local_graph_transfer_block(
    func,
    sibling_cfg,
    sibling_cfg.entry_block,
    incoming,
    Some(LocalGraphSourceRecorder::new(sibling_sources)),
    None,
  )
  assert_eq(incoming, [[0], [1], [2], [3]])
  assert_eq(result[1], [local_graph_set_source_id(4, second)])
  assert_eq(sources[between], [local_graph_set_source_id(4, first)])
  assert_eq(sources[after], [local_graph_set_source_id(4, second)])
  assert_eq(influences[first], [between])
  assert_eq(influences[second], [after])
  assert_false(physical_equal(result, incoming))
  assert_true(physical_equal(result[0], incoming[0]))
  assert_eq(sibling_sources[after], [1])
  assert_true(physical_equal(sibling, incoming))
}

///|
test "unexpanded recursive transfer retains owned state across nested writes" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let write = hot_build_local_tee(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  let drop = hot_build_drop(func, write)
  let cfg = local_graph_transfer_borrow_fixture(func, [drop], false)
  let incoming = local_graph_entry_state(1)
  let result = local_graph_transfer_block(
    func,
    cfg,
    cfg.entry_block,
    incoming,
    None,
    None,
  )
  assert_eq(result, [[local_graph_set_source_id(1, write)]])
  assert_eq(incoming, [[0]])
  assert_false(physical_equal(result, incoming))
}
