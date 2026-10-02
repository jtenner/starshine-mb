///|
test "CFG fixed workspaces cover dead arena slots and own their mappings" {
  for count in [9, 129] {
    let func = HotFunc::new()
    for i in 0..<count {
      let node = hot_build_nop(func)
      if i != 4 {
        hot_root_append(func, node)
      }
    }
    hot_delete_node(func, 4)
    for _ in 0..<3 {
      hot_root_append(
        func,
        hot_build_block(func, @lib.BlockType::void_(), [hot_build_nop(func)]),
      )
    }
    let revision = hot_revision_current(func)
    for expanded in [false, true] {
      let builder = cfg_builder_new(func, true, expanded)
      let sibling = cfg_builder_new(func, true, expanded)
      assert_eq(
        builder.cfg.node_to_block,
        Array::make(hot_node_count(func), -1),
      )
      assert_eq(builder.label_targets, Array::make(func.labels.length(), -1))
      // Both spans have known lengths before construction. They should not
      // retain geometric growth slack or omit deleted node IDs.
      assert_eq(builder.cfg.node_to_block.capacity(), hot_node_count(func))
      assert_eq(builder.label_targets.capacity(), func.labels.length())
      builder.cfg.node_to_block[4] = 7
      builder.label_targets[0] = 8
      assert_eq(sibling.cfg.node_to_block[4], -1)
      assert_eq(sibling.label_targets[0], -1)
      cfg_verify(cfg_build(func, expand_operand_control=expanded))
    }
    assert_eq(hot_revision_current(func), revision)
  }
}

///|
test "CFG fixed workspaces keep empty arenas empty in both builder modes" {
  let func = HotFunc::new()
  for expanded in [false, true] {
    let builder = cfg_builder_new(func, false, expanded)
    assert_eq(builder.cfg.node_to_block, [])
    assert_eq(builder.label_targets, [])
    assert_eq(builder.cfg.blocks, [])
    assert_eq(builder.cfg.region_roots, [])
    assert_eq(builder.cfg.entry_block, -1)
    assert_eq(builder.cfg.exit_block, -1)
    assert_true(builder.cfg.exceptional_exit_block is None)
    assert_eq(builder.continuation_targets, [])
    match builder.operand_seen {
      Some(seen) => assert_eq(seen, [])
      None => assert_false(expanded)
    }
  }
}

///|
// Frozen original fixed-span initialization for allocation/timing controls.
fn cfg_fixed_workspace_reference_new(
  func : HotFunc,
  conservative_exception_entries : Bool,
  expand_operand_control : Bool,
) -> CfgBuilder {
  let node_to_block : Array[BlockId] = []
  let mut has_continuations = false
  for node in 0..<hot_node_count(func) {
    node_to_block.push(-1)
    if hot_node_is_live(func, node) &&
      hot_node_get(func, node).op == HotOp::Continuation {
      has_continuations = true
    }
  }
  let label_targets : Array[BlockId] = []
  for _ in 0..<func.labels.length() {
    label_targets.push(-1)
  }
  {
    cfg: {
      operands_expanded: expand_operand_control,
      blocks: [],
      node_to_block,
      region_roots: [],
      entry_block: -1,
      exit_block: -1,
      exceptional_exit_block: None,
    },
    label_targets,
    conservative_exception_entries,
    operand_seen: if expand_operand_control {
      Some(Array::make(hot_node_count(func), false))
    } else {
      None
    },
    source_order: if expand_operand_control {
      Some(HotSourceOrderFacts::new(func))
    } else {
      None
    },
    operand_minima: None,
    continuation_targets: if has_continuations {
      Array::make(hot_node_count(func), None)
    } else {
      []
    },
  }
}
