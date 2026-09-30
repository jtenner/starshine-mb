///|
// A chain of conditional writes forces immutable selector reads to cross
// earlier joins and unrelated writers in the original reverse solver.
fn entry_read_fixture(count : Int) -> (HotFunc, HotCfg, Array[NodeId], NodeId) {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  let initial = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(0)),
  )
  let reads = Array::makei(count, fn(_) { hot_build_local_get(func, 1) })
  let writes = Array::makei(count, fn(i) {
    hot_build_local_set(func, 0, hot_build_const_i32(func, @lib.I32(i + 1)))
  })
  let final_read = hot_build_local_get(func, 0)
  let builder = cfg_builder_new(func, true, true)
  let entry = cfg_builder_add_block(builder, [initial], false)
  builder.cfg.entry_block = entry
  let mut previous = entry
  for i in 0..<count {
    let condition = cfg_builder_add_block(builder, [reads[i]], false)
    let written = cfg_builder_add_block(builder, [writes[i]], false)
    let join = cfg_builder_add_block(builder, [], true)
    cfg_builder_add_edge(
      builder,
      previous,
      condition,
      CfgEdgeKind::FallthroughEdge,
    )
    cfg_builder_add_edge(builder, condition, written, CfgEdgeKind::BranchEdge)
    cfg_builder_add_edge(builder, condition, join, CfgEdgeKind::FallthroughEdge)
    cfg_builder_add_edge(builder, written, join, CfgEdgeKind::FallthroughEdge)
    previous = join
  }
  let exit = cfg_builder_add_block(builder, [final_read], false)
  builder.cfg.exit_block = exit
  cfg_builder_add_edge(builder, previous, exit, CfgEdgeKind::FallthroughEdge)
  cfg_verify(builder.cfg)
  (func, builder.cfg, reads, final_read)
}

///|
test "immutable entry reads avoid per-block source caches and preserve full graph" {
  let (func, cfg, reads, final_read) = entry_read_fixture(16)
  let revision = hot_revision_current(func)
  let free = func.free_nodes.copy()
  let slots = [0]
  let actual = local_graph_build_reverse_flow(
    func,
    cfg,
    true,
    cache_slots=Some(slots),
  )
  let original = entry_read_reference_build_reverse_flow(func, cfg, true)
  assert_eq(actual, original)
  for read in reads {
    assert_eq(local_graph_reaching_sources_for_get(actual, read), [
      EntrySource(1),
    ])
  }
  assert_eq(
    local_graph_reaching_sources_for_get(actual, final_read).length(),
    17,
  )
  assert_eq(hot_revision_current(func), revision)
  assert_eq(func.free_nodes, free)
  // Only the written local needs a cached predecessor query. The original
  // allocates a further completed entry-source cache slot for each selector.
  assert_eq(slots[0], cfg_block_count(cfg) + 1)
}

///|
test "immutable entry reads preserve unknown rows and exceptional entry policy" {
  for entry_backedge in [false, true] {
    let func = HotFunc::new(
      locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
        @lib.ValType::i32(),
      ]),
    )
    let reads = Array::makei(7, fn(i) { hot_build_local_get(func, i % 2) })
    let builder = cfg_builder_new(func, true, true)
    let entry = cfg_builder_add_block(builder, [reads[0]], false)
    let reached = cfg_builder_add_block(builder, [reads[1]], false)
    let loop_header = cfg_builder_add_block(builder, [reads[2]], false)
    let loop_body = cfg_builder_add_block(builder, [], true)
    let dead_a = cfg_builder_add_block(builder, [reads[3]], false)
    let dead_b = cfg_builder_add_block(builder, [reads[4]], false)
    let handler = cfg_builder_add_block(builder, [reads[5]], false)
    let isolated = cfg_builder_add_block(builder, [reads[6]], false)
    let exit = cfg_builder_add_block(builder, [], true)
    builder.cfg.entry_block = entry
    builder.cfg.exit_block = exit
    for
      (from, to) in [
        (entry, reached),
        (reached, loop_header),
        (loop_header, loop_body),
        (loop_body, loop_header),
        (loop_header, exit),
        (dead_a, dead_b),
        (dead_b, dead_a),
        (handler, exit),
        (isolated, exit),
      ] {
      cfg_builder_add_edge(builder, from, to, CfgEdgeKind::FallthroughEdge)
    }
    cfg_builder_add_edge(
      builder,
      reached,
      handler,
      CfgEdgeKind::ExceptionalEdge,
    )
    if entry_backedge {
      cfg_builder_add_edge(
        builder,
        loop_body,
        entry,
        CfgEdgeKind::ExceptionalEdge,
      )
    }
    cfg_verify(builder.cfg)
    for exceptional in [false, true] {
      let graph = local_graph_build_reverse_flow(func, builder.cfg, exceptional)
      assert_eq(
        graph,
        entry_read_reference_build_reverse_flow(func, builder.cfg, exceptional),
      )
      let origin = !entry_backedge || !exceptional
      for index in 0..<3 {
        assert_eq(
          local_graph_reaching_sources_for_get(graph, reads[index]),
          if origin {
            [EntrySource(index % 2)]
          } else {
            []
          },
        )
      }
      for index in [3, 4, 6] {
        assert_eq(local_graph_reaching_sources_for_get(graph, reads[index]), [])
      }
      assert_eq(
        local_graph_reaching_sources_for_get(graph, reads[5]),
        if origin && exceptional {
          [EntrySource(1)]
        } else {
          []
        },
      )
    }
  }
}

///|
test "immutable entry reads retain full control metadata in both operand modes" {
  for
    source in [
      "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 7 local.set 1 else local.get 1 drop end local.get 0 local.get 1 i32.add))",
      "(module (func (param i32) (result i32) (local i32) block local.get 0 if i32.const 7 local.set 1 br 1 end i32.const 9 local.set 1 end local.get 0 local.get 1 i32.add))",
      "(module (func (param i32) (result i32) (local i32) i32.const 3 local.set 1 loop local.get 0 drop local.get 1 i32.const 1 i32.sub local.tee 1 br_if 0 end local.get 0))",
      "(module (func (param externref) (result externref) local.get 0))", "(module (func (param i32) unreachable local.get 0 drop))",
    ] {
    let module_ = ir_test_module_from_wat(source)
    let func = hot_lift_func(module_, @lib.FuncIdx::new(0U))
    for expanded in [false, true] {
      let cfg = cfg_build(func, expand_operand_control=expanded)
      for exceptional in [false, true] {
        assert_eq(
          local_graph_build_reverse_flow(func, cfg, exceptional),
          entry_read_reference_build_reverse_flow(func, cfg, exceptional),
        )
      }
    }
    hot_verify_all(func).unwrap()
  }
}

///|
test "shared immutable actions keep the complete sparse fallback" {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let read = hot_build_local_get(func, 0)
  let builder = cfg_builder_new(func, true, true)
  let entry = cfg_builder_add_block(builder, [], true)
  let first = cfg_builder_add_block(builder, [read], false)
  let second = cfg_builder_add_block(builder, [read], false)
  let exit = cfg_builder_add_block(builder, [], true)
  builder.cfg.entry_block = entry
  builder.cfg.exit_block = exit
  for (from, to) in [(entry, first), (first, second), (second, exit)] {
    cfg_builder_add_edge(builder, from, to, CfgEdgeKind::FallthroughEdge)
  }
  cfg_verify(builder.cfg)
  let slots = [0]
  let graph = local_graph_build_reverse_flow(
    func,
    builder.cfg,
    true,
    cache_slots=Some(slots),
  )
  assert_eq(
    graph,
    entry_read_reference_build_reverse_flow(func, builder.cfg, true),
  )
  assert_eq(graph, local_graph_build_sparse_flow(func, builder.cfg, true))
  assert_eq(local_graph_reaching_sources_for_get(graph, read), [EntrySource(0)])
  assert_eq(slots, [0])
}
