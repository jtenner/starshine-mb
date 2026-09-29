///|
test "reverse local flow preserves sources through transparent chains and cycles" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  let write = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(9)),
  )
  let join_read = hot_build_local_get(func, 0)
  let loop_read = hot_build_local_get(func, 0)
  let dead_read = hot_build_local_get(func, 1)
  let handler_read = hot_build_local_get(func, 0)
  let builder = cfg_builder_new(func, true, true)
  let entry = cfg_builder_add_block(builder, [], true)
  let written = cfg_builder_add_block(builder, [write], false)
  let chain = cfg_builder_add_block(builder, [], true)
  let join = cfg_builder_add_block(builder, [join_read], false)
  let loop_header = cfg_builder_add_block(builder, [loop_read], false)
  let loop_body = cfg_builder_add_block(builder, [], true)
  let dead_a = cfg_builder_add_block(builder, [dead_read], false)
  let dead_b = cfg_builder_add_block(builder, [], true)
  let handler = cfg_builder_add_block(builder, [handler_read], false)
  let exit = cfg_builder_add_block(builder, [], true)
  builder.cfg.entry_block = entry
  builder.cfg.exit_block = exit
  for
    (from, to) in [
      (entry, written),
      (written, chain),
      (chain, join),
      (entry, join),
      (join, loop_header),
      (loop_header, loop_body),
      (loop_body, loop_header),
      (loop_header, exit),
      (dead_a, dead_b),
      (dead_b, dead_a),
      (entry, handler),
      (handler, exit),
    ] {
    cfg_builder_add_edge(builder, from, to, CfgEdgeKind::FallthroughEdge)
  }
  cfg_builder_add_edge(builder, written, handler, CfgEdgeKind::ExceptionalEdge)
  for exceptional in [false, true] {
    let actions = local_graph_reverse_action_sequences(func, builder.cfg)
    let transparent = local_graph_reverse_transparent_predecessors(
      func,
      builder.cfg,
      actions,
      exceptional,
    )
    assert_eq(transparent[chain], written)
    assert_eq(transparent[join], join)
    assert_eq(transparent[loop_body], loop_header)
    assert_eq(transparent[dead_a], transparent[dead_b])
    assert_eq(transparent[handler], if exceptional { handler } else { entry })
    let graph = local_graph_build_reverse_flow(func, builder.cfg, exceptional)
    let reference = local_graph_build_with_exceptional_policy(
      func,
      builder.cfg,
      exceptional,
    )
    for read in [join_read, loop_read, dead_read, handler_read] {
      let actual = local_graph_reaching_sources_for_get(graph, read)
      let expected = local_graph_reaching_sources_for_get(reference, read)
      assert_eq(actual.length(), expected.length())
      for source in expected {
        assert_true(actual.contains(source))
      }
    }
    for read in [join_read, loop_read] {
      let sources = local_graph_reaching_sources_for_get(graph, read)
      assert_eq(sources.length(), 2)
      assert_true(sources.contains(EntrySource(0)))
      assert_true(sources.contains(SetSource(write)))
    }
    assert_eq(local_graph_reaching_sources_for_get(graph, dead_read), [])
    assert_eq(
      local_graph_reaching_sources_for_get(graph, handler_read).length(),
      if exceptional {
        2
      } else {
        1
      },
    )
  }
}
