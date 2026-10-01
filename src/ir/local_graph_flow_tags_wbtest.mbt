///|
fn flow_tag_fixture(
  count : Int,
  immutable : Bool,
  extra? : Bool = false,
) -> (HotFunc, HotCfg, Array[NodeId], NodeId) {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  // Exercise writer node ID zero as well as the nonread sentinel -1.
  let hole = hot_build_nop(func)
  let initial_value = hot_build_const_i32(func, @lib.I32(0))
  hot_delete_node(func, hole)
  let initial = hot_build_local_tee(func, 0, initial_value)
  let same_block_read = hot_build_local_get(func, 0)
  let reads = Array::makei(count, fn(_) {
    hot_build_local_get(func, if immutable { 1 } else { 0 })
  })
  let writes = Array::makei(count, fn(i) {
    hot_build_local_set(func, 0, hot_build_const_i32(func, @lib.I32(i + 1)))
  })
  let final_read = hot_build_local_get(func, 0)
  if extra {
    // Orphan arena metadata must survive even though these are not CFG actions.
    ignore(hot_build_local_get(func, 1))
    ignore(
      hot_build_local_set(func, 1, hot_build_const_i32(func, @lib.I32(17))),
    )
    let deleted = hot_build_local_get(func, 0)
    hot_delete_node(func, deleted)
  }
  let builder = cfg_builder_new(func, true, true)
  let entry = cfg_builder_add_block(builder, [initial, same_block_read], false)
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
fn flow_tag_assert_rows(func : HotFunc, cfg : HotCfg) -> Unit raise {
  let revision = hot_revision_current(func)
  let free = func.free_nodes.copy()
  for full in [false, true] {
    let expected = flow_tag_reference_build_reverse_rows(
      func,
      cfg,
      true,
      full_metadata=full,
    )
    let actual = local_graph_build_reverse_rows(
      func,
      cfg,
      true,
      full_metadata=full,
    )
    assert_eq(actual.get_source_ids, expected.get_source_ids)
    assert_eq(actual.write_influences, expected.write_influences)
    assert_eq(actual.write_facts.local_ids, expected.write_facts.local_ids)
    assert_eq(actual.write_facts.is_tees, expected.write_facts.is_tees)
    if full {
      assert_eq(
        local_graph_finish_full_flow(func, actual),
        local_graph_finish_full_flow(func, expected),
      )
    }
  }
  assert_eq(hot_revision_current(func), revision)
  assert_eq(func.free_nodes, free)
}

///|
test "reverse entry admission requires an observed never-written read, not unused locals" {
  let (func, cfg, _, _) = flow_tag_fixture(8, false, extra=true)
  flow_tag_assert_rows(func, cfg)
  // These are valid admission tags: a writer/nonread, a same-block writer
  // source, and a read of local zero without a writer in its current block.
  // Local one is unused by the CFG despite live orphan read/write metadata.
  let actions = [[0, 1], [2]]
  let nearest = [-1, 0, -2]
  let written = [true, false]
  assert_false(local_graph_has_immutable_entry_read(actions, nearest, written))
}

///|
test "flow entry admission borrows tags and only requests actual immutable reads" {
  for
    (actions, nearest, written, needed) in [
      ([[0]], [-2], [false], true),
      ([[0]], [-2], [true, false], false),
      ([[]], [], [false], false),
      ([[0, 1]], [-1, -3], [true, false], true),
      ([[0]], [0], [true, false], false),
    ] {
    let saved_actions = actions.map(fn(row) { row.copy() })
    let saved_nearest = nearest.copy()
    let saved_written = written.copy()
    assert_eq(
      local_graph_has_immutable_entry_read(actions, nearest, written),
      needed,
    )
    assert_eq(actions, saved_actions)
    assert_eq(nearest, saved_nearest)
    assert_eq(written, saved_written)
  }
}

///|
test "flow tags preserve complete graphs for written and immutable selectors" {
  for immutable in [false, true] {
    for extra in [false, true] {
      let (func, cfg, _, _) = flow_tag_fixture(8, immutable, extra~)
      flow_tag_assert_rows(func, cfg)
    }
  }
}

///|
test "flow tag projection matches full headers on scalar GC control and shared actions" {
  for
    source in [
      "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 7 local.set 1 else i32.const 9 local.set 1 end local.get 1))",
      "(module (func (param i32) (result i32) (local i32) i32.const 3 local.set 1 loop local.get 1 i32.const 1 i32.sub local.tee 1 br_if 0 end local.get 0))",
      "(module (type $s (struct (field i32))) (func (param (ref null $s)) (result (ref null $s)) (local (ref null $s)) local.get 0 local.set 1 local.get 1))",
      "(module (func (param i32) unreachable local.get 0 drop))",
    ] {
    let module_ = ir_test_module_from_wat(source)
    let func = hot_lift_func(module_, @lib.FuncIdx::new(0U))
    for expanded in [false, true] {
      flow_tag_assert_rows(
        func,
        cfg_build(func, expand_operand_control=expanded),
      )
    }
    hot_verify_all(func).unwrap()
  }
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let shared = hot_build_local_get(func, 0)
  let builder = cfg_builder_new(func, true, true)
  let entry = cfg_builder_add_block(builder, [shared], false)
  let exit = cfg_builder_add_block(builder, [shared], false)
  builder.cfg.entry_block = entry
  builder.cfg.exit_block = exit
  cfg_builder_add_edge(builder, entry, exit, CfgEdgeKind::FallthroughEdge)
  cfg_verify(builder.cfg)
  flow_tag_assert_rows(func, builder.cfg)
}
