///|
fn local_graph_borrow_fixture() -> (HotFunc, HotCfg) {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let builder = cfg_builder_new(func, true, false)
  let entry = cfg_builder_add_block(builder, [], true)
  let exit = cfg_builder_add_block(builder, [], true)
  let handler = cfg_builder_add_block(builder, [], true)
  builder.cfg.entry_block = entry
  builder.cfg.exit_block = exit
  cfg_builder_add_edge(builder, entry, exit, CfgEdgeKind::FallthroughEdge)
  cfg_builder_add_edge(builder, handler, exit, CfgEdgeKind::ExceptionalEdge)
  (func, builder.cfg)
}

///|
test "local-flow joins borrow a single admitted predecessor and empty transfer" {
  let (func, cfg) = local_graph_borrow_fixture()
  let states = [[[0], [1]], [[], []], [[2], [1]]]
  let merged = local_graph_merge_predecessors(
    cfg,
    cfg.exit_block,
    2,
    states,
    false,
  )
  assert_eq(
    merged,
    local_graph_borrow_reference_merge(cfg, cfg.exit_block, 2, states, false),
  )
  assert_true(physical_equal(merged, states[0]))
  let transferred = local_graph_transfer_block(
    func,
    cfg,
    cfg.exit_block,
    merged,
    None,
    None,
  )
  assert_eq(transferred, merged)
  assert_true(physical_equal(transferred, merged))
}

///|
test "local-flow multi-predecessor union preserves source order and owned transfer" {
  let (func, cfg) = local_graph_borrow_fixture()
  let states = [[[0], [1]], [[], []], [[2], [1]]]
  let merged = local_graph_merge_predecessors(
    cfg,
    cfg.exit_block,
    2,
    states,
    true,
  )
  assert_eq(merged, [[0, 2], [1]])
  assert_eq(
    merged,
    local_graph_borrow_reference_merge(cfg, cfg.exit_block, 2, states, true),
  )
  assert_eq(states[0], [[0], [1]])
  assert_eq(states[2], [[2], [1]])
  assert_false(physical_equal(merged, states[0]))
  let write = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(9)),
  )
  cfg_block_get(cfg, cfg.exit_block).nodes.push(write)
  let out = local_graph_transfer_block(
    func,
    cfg,
    cfg.exit_block,
    merged,
    None,
    None,
  )
  assert_eq(merged, [[0, 2], [1]])
  assert_eq(out[0], [local_graph_set_source_id(2, write)])
  assert_false(physical_equal(out, merged))
}

///|
test "local-flow subset joins preserve their first immutable state" {
  let (_, cfg) = local_graph_borrow_fixture()
  let states = [[[0, 2], [1]], [[], []], [[2], []]]
  let merged = local_graph_merge_predecessors(
    cfg,
    cfg.exit_block,
    2,
    states,
    true,
  )
  assert_eq(
    merged,
    local_graph_borrow_reference_merge(cfg, cfg.exit_block, 2, states, true),
  )
  assert_true(physical_equal(merged, states[0]))
}
