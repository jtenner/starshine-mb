///|
fn selected_reads_assert(func : HotFunc, cfg : HotCfg) -> Unit raise {
  let complete = local_graph_build_read_sources(func, cfg)
  let count = hot_node_count(func)
  let mut reads = 0
  for node in 0..<count {
    if hot_node_is_live(func, node) &&
      hot_node_op(func, node) is HotOp::LocalGet {
      reads += 1
    }
  }
  assert_true(reads > 1)
  for selected in 0..<count {
    if !hot_node_is_live(func, selected) ||
      !(hot_node_op(func, selected) is HotOp::LocalGet) {
      continue
    }
    let mask = Array::make(count, false)
    mask[selected] = true
    let saved = mask.copy()
    let partial = local_graph_build_read_sources(
      func,
      cfg,
      selected_gets=Some(mask),
    )
    for node in 0..<count {
      let expected = if node == selected {
        local_read_source_count_for_get(complete, node)
      } else {
        0
      }
      assert_eq(local_read_source_count_for_get(partial, node), expected)
      for source in 0..<expected {
        assert_eq(
          local_read_source_value_for_get(partial, node, source),
          local_read_source_value_for_get(complete, node, source),
        )
      }
    }
    assert_eq(mask, saved)
  }
  let empty = local_graph_build_read_sources(
    func,
    cfg,
    selected_gets=Some(Array::make(count, false)),
  )
  assert_true(empty.get_source_ids.all(fn(row) { row.is_empty() }))
}

///|
test "selected read flow preserves ordered joins loops and reference writes" {
  for
    wat in [
      "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 7 local.set 1 else i32.const 9 local.set 1 end local.get 1 local.get 0 i32.add))",
      "(module (func (param i32) (result i32) (local i32) i32.const 3 local.set 1 loop local.get 1 i32.const 1 i32.sub local.tee 1 br_if 0 end local.get 1 local.get 0 i32.add))",
      "(module (func (param i32 i32) (result i32) local.get 0 if (result i32) local.get 1 else i32.const 5 end local.get 1 i32.add))",
      "(module (func (param externref) (result externref) (local externref) local.get 0 local.set 1 local.get 1 drop local.get 0))",
    ] {
    let module_ = ir_test_module_from_wat(wat)
    let func = hot_lift_func(module_, @lib.FuncIdx::new(0U))
    let revision = hot_revision_current(func)
    for expanded in [false, true] {
      selected_reads_assert(
        func,
        cfg_build(func, expand_operand_control=expanded),
      )
    }
    assert_eq(hot_revision_current(func), revision)
    hot_verify_all(func).unwrap()
  }
}

///|
test "selected read flow preserves shared-action fallback and exceptional joins" {
  for shared in [false, true] {
    let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
    let read = hot_build_local_get(func, 0)
    let next = if shared { read } else { hot_build_local_get(func, 0) }
    let last = hot_build_local_get(func, 0)
    let write = hot_build_local_tee(
      func,
      0,
      hot_build_const_i32(func, @lib.I32(7)),
    )
    let builder = cfg_builder_new(func, true, true)
    let entry = cfg_builder_add_block(builder, [read], false)
    let changed = cfg_builder_add_block(builder, [write], false)
    let handler = cfg_builder_add_block(builder, [next, last], false)
    let exit = cfg_builder_add_block(builder, [], true)
    builder.cfg.entry_block = entry
    builder.cfg.exit_block = exit
    for
      (from, to, kind) in [
        (entry, changed, CfgEdgeKind::FallthroughEdge),
        (entry, handler, CfgEdgeKind::ExceptionalEdge),
        (changed, handler, CfgEdgeKind::FallthroughEdge),
        (handler, exit, CfgEdgeKind::FallthroughEdge),
      ] {
      cfg_builder_add_edge(builder, from, to, kind)
    }
    cfg_verify(builder.cfg)
    selected_reads_assert(func, builder.cfg)
  }
}
