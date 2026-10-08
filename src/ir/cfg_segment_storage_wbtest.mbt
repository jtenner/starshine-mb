///|
// Frozen boxed v13 metadata for field and allocation controls.
priv struct CfgSegmentBoxedReference {
  block_id : BlockId
  end_slot : Int
  last_node : NodeId
}

///|
fn cfg_segment_storage_reference(
  builder : CfgBuilder,
  func : HotFunc,
  region_ref : HotRegionRef,
) -> Array[CfgSegmentBoxedReference] {
  // Retained original reference includes eager source-order initialization.
  if builder.operand_seen is Some(_) && builder.source_order is None {
    builder.source_order = Some(HotSourceOrderFacts::new(func))
  }
  let segments : Array[CfgSegmentBoxedReference] = []
  let region_holder = cfg_builder_region_holder(region_ref)
  let root_count = hot_region_root_count(func, region_ref)
  let expanded = builder.operand_seen is Some(_)
  let ordered_nodes : Array[NodeId] = []
  let root_slots : Array[Int] = []
  let roots : Array[NodeId] = []
  let suffix_minima = match builder.source_order {
    Some(facts) => {
      for slot = 0; slot < root_count; slot = slot + 1 {
        roots.push(hot_region_get(func, region_ref, slot))
      }
      hot_source_order_future_suffix_minima(func, roots, facts)
    }
    None => None
  }
  for slot = 0; slot < root_count; slot = slot + 1 {
    let root_id = if expanded {
      roots[slot]
    } else {
      hot_region_get(func, region_ref, slot)
    }
    match builder.operand_seen {
      Some(seen) => {
        let facts = builder.source_order.unwrap()
        for
          dependency in hot_source_order_preceding_dependencies(
            func,
            root_id,
            roots,
            slot + 1,
            suffix_minima,
            facts,
          ) {
          cfg_builder_collect_operand_nodes(
            builder, func, dependency, slot, seen, ordered_nodes, root_slots,
          )
        }
        cfg_builder_collect_operand_nodes(
          builder, func, root_id, slot, seen, ordered_nodes, root_slots,
        )
      }
      None => {
        ordered_nodes.push(root_id)
        root_slots.push(slot)
      }
    }
  }
  let mut start = 0
  while start < ordered_nodes.length() {
    let mut end = start + 1
    while end < ordered_nodes.length() {
      let previous = ordered_nodes[end - 1]
      if cfg_op_is_terminator(hot_node_get(func, previous).op) {
        break
      }
      let next = ordered_nodes[end]
      if hot_is_control_node(func, next) {
        break
      }
      if !cfg_expression_continuation_targets(
          func,
          previous,
          builder.continuation_targets,
        ).is_empty() ||
        cfg_region_segment_break_after_drop_operand_control(func, previous) {
        break
      }
      end = end + 1
    }
    let nodes : Array[NodeId] = []
    for slot = start; slot < end; slot = slot + 1 {
      nodes.push(ordered_nodes[slot])
    }
    let block_id = cfg_builder_add_block(
      builder,
      nodes,
      false,
      region_holder~,
      start_slot=root_slots[start],
      end_slot=root_slots[end - 1] + 1,
    )
    for index = start; index < end; index = index + 1 {
      let slot = root_slots[index]
      // Expanded operands reuse the immutable root snapshot already built
      // for source ordering. Without expansion, every listed node is a root.
      if !expanded || ordered_nodes[index] == roots[slot] {
        builder.cfg.region_roots.push({ region_holder, slot, block: block_id, })
      }
    }
    segments.push({
      block_id,
      end_slot: root_slots[end - 1] + 1,
      last_node: ordered_nodes[end - 1],
    })
    start = end
  }
  segments
}

///|
test "CFG segment arena keeps three ordered scalar fields per entry" {
  let segments = CfgRegionSegments::new()
  segments.push(7, 3, 12)
  segments.push(2, 9, -1)
  assert_eq(segments.length(), 2)
  assert_eq(segments.block_id(0), 7)
  assert_eq(segments.block_id(1), 2)
  assert_eq(segments.rows, [7, 3, 12, 2, 9, -1])
  let first = segments.get(0)
  assert_eq(first.block_id, 7)
  assert_eq(first.end_slot, 3)
  assert_eq(first.last_node, 12)
  let second = segments.get(1)
  assert_eq(second.block_id, 2)
  assert_eq(second.end_slot, 9)
  assert_eq(second.last_node, HOT_NONE_NODE)
}

///|
test "CFG segment arena growth preserves earlier entries and empty regions" {
  let segments = CfgRegionSegments::new()
  assert_eq(segments.length(), 0)
  for i in 0..<16 {
    segments.push(i + 5, i * 2, i * 3)
  }
  assert_eq(segments.length(), 16)
  for i in 0..<16 {
    let segment = segments.get(i)
    assert_eq(segment.block_id, i + 5)
    assert_eq(segment.end_slot, i * 2)
    assert_eq(segment.last_node, i * 3)
  }
}

///|
fn cfg_segment_storage_fixture(count : Int) -> HotFunc {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  for i in 0..<count {
    let write = hot_build_local_set(
      func,
      0,
      hot_build_const_i32(func, @lib.I32(i)),
    )
    let condition = hot_build_local_get(func, 0)
    hot_root_append(
      func,
      hot_build_if(func, @lib.BlockType::void_(), condition, [write]),
    )
    hot_root_append(
      func,
      hot_build_drop(func, hot_build_const_i32(func, @lib.I32(i))),
    )
  }
  func
}

///|
test "packed CFG segmentation preserves block fields and root mappings" {
  let func = cfg_segment_storage_fixture(4)
  for expanded in [false, true] {
    let selected = cfg_builder_new(func, true, expanded)
    let reference = cfg_builder_new(func, true, expanded)
    let actual = cfg_builder_region_segments(
      selected,
      func,
      HotRegionRef::root(),
    )
    let expected = cfg_segment_storage_reference(
      reference,
      func,
      HotRegionRef::root(),
    )
    assert_eq(actual.length(), expected.length())
    for i in 0..<actual.length() {
      let segment = actual.get(i)
      assert_eq(segment.block_id, expected[i].block_id)
      assert_eq(segment.end_slot, expected[i].end_slot)
      assert_eq(segment.last_node, expected[i].last_node)
    }
    assert_eq(selected.cfg, reference.cfg)
    cfg_verify(cfg_build(func, expand_operand_control=expanded))
  }
}
