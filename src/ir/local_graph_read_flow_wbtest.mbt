///|
fn read_flow_assert_sources(func : HotFunc, cfg : HotCfg) -> Unit raise {
  let original = entry_read_reference_build_reverse_flow(func, cfg, true)
  assert_eq(local_graph_build_full_flow(func, cfg), original)
  let projected = local_graph_build_read_sources(func, cfg)
  for node in 0..<hot_node_count(func) {
    let count = local_graph_reaching_source_count_for_get(original, node)
    assert_eq(local_read_source_count_for_get(projected, node), count)
    for index in 0..<count {
      assert_eq(
        local_read_source_value_for_get(projected, node, index),
        local_graph_reaching_source_value_for_get(original, node, index),
      )
    }
  }
}

///|
test "read-source flow preserves ordered joins loops references and unknown reads" {
  for
    source in [
      "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 7 local.set 1 else i32.const 9 local.set 1 end local.get 1))",
      "(module (func (param i32) (result i32) (local i32) block local.get 0 if i32.const 7 local.set 1 br 1 end i32.const 9 local.set 1 end local.get 1))",
      "(module (func (param i32) (result i32) (local i32) i32.const 3 local.set 1 loop local.get 1 i32.const 1 i32.sub local.tee 1 br_if 0 end local.get 0))",
      "(module (func (param externref) (result externref) (local externref) local.get 0 local.set 1 local.get 1))",
      "(module (func (param i32) unreachable local.get 0 drop))",
    ] {
    let module_ = ir_test_module_from_wat(source)
    let func = hot_lift_func(module_, @lib.FuncIdx::new(0U))
    let revision = hot_revision_current(func)
    for expanded in [false, true] {
      read_flow_assert_sources(
        func,
        cfg_build(func, expand_operand_control=expanded),
      )
    }
    assert_eq(hot_revision_current(func), revision)
    hot_verify_all(func).unwrap()
  }
}

///|
test "read-source flow preserves exceptional edges and shared-action fallback" {
  for shared in [false, true] {
    let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
    let first_read = hot_build_local_get(func, 0)
    let next_read = if shared {
      first_read
    } else {
      hot_build_local_get(func, 0)
    }
    let write = hot_build_local_tee(
      func,
      0,
      hot_build_const_i32(func, @lib.I32(7)),
    )
    let isolated_read = hot_build_local_get(func, 0)
    let builder = cfg_builder_new(func, true, true)
    let entry = cfg_builder_add_block(builder, [first_read], false)
    let changed = cfg_builder_add_block(builder, [write], false)
    let handler = cfg_builder_add_block(builder, [next_read], false)
    let isolated = cfg_builder_add_block(builder, [isolated_read], false)
    let exit = cfg_builder_add_block(builder, [], true)
    builder.cfg.entry_block = entry
    builder.cfg.exit_block = exit
    for
      (from, to, kind) in [
        (entry, changed, CfgEdgeKind::FallthroughEdge),
        (entry, handler, CfgEdgeKind::ExceptionalEdge),
        (changed, handler, CfgEdgeKind::FallthroughEdge),
        (handler, exit, CfgEdgeKind::FallthroughEdge),
        (isolated, exit, CfgEdgeKind::FallthroughEdge),
      ] {
      cfg_builder_add_edge(builder, from, to, kind)
    }
    cfg_verify(builder.cfg)
    read_flow_assert_sources(func, builder.cfg)
  }
}

///|
test "read-source flow retains its snapshot across later local rewrites" {
  let module_ = ir_test_module_from_wat(
    "(module (func (param i32 i32) (result i32) local.get 0))",
  )
  let func = hot_lift_func(module_, @lib.FuncIdx::new(0U))
  let read = hot_root_get(func, 0)
  let first = local_graph_build_read_sources(func, cfg_build(func))
  let source = local_read_source_value_for_get(first, read, 0)
  assert_true(source.is_entry)
  assert_eq(source.index, 0)
  hot_replace_node(func, read, { ..hot_node_get(func, read), imm0: 1, })
  let second = local_graph_build_read_sources(func, cfg_build(func))
  assert_eq(local_read_source_value_for_get(first, read, 0), source)
  assert_eq(local_read_source_value_for_get(second, read, 0).index, 1)
}
