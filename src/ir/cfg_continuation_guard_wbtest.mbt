///|
test "CFG continuation existence reads published rows without copying them" {
  let func = HotFunc::new()
  let root = hot_build_nop(func)
  let cache : Array[Array[LabelId]?] = [Some([])]
  assert_false(cfg_expression_has_continuation_targets(func, root, cache))
  let targets = [3, 7]
  // Published rows are opaque to the lookup predicate. Their ownership and
  // ordering must survive an existence check, just as with the list query.
  cache[root] = Some(targets)
  assert_true(cfg_expression_has_continuation_targets(func, root, cache))
  assert_eq(cfg_expression_continuation_targets(func, root, cache), targets)
  assert_true(physical_equal(cache[root].unwrap(), targets))
  assert_eq(targets, [3, 7])
}

///|
test "CFG continuation existence keeps empty and cold caches correct" {
  let func = cfg_segment_storage_fixture(3)
  let revision = hot_revision_current(func)
  let empty : Array[Array[LabelId]?] = []
  let cache : Array[Array[LabelId]?] = Array::make(hot_node_count(func), None)
  for root in hot_root_span(func) {
    assert_false(cfg_expression_has_continuation_targets(func, root, empty))
    assert_eq(empty, [])
    assert_false(cfg_expression_has_continuation_targets(func, root, cache))
    assert_eq(cfg_expression_continuation_targets(func, root, cache), [])
    assert_true(cache[root] is Some(_))
  }
  assert_eq(hot_revision_current(func), revision)
}

///|
test "CFG continuation guard preserves packed segments and root block mappings" {
  let func = cfg_segment_storage_fixture(4)
  for expanded in [false, true] {
    let selected = cfg_builder_new(func, true, expanded)
    let original = cfg_builder_new(func, true, expanded)
    let actual = cfg_builder_region_segments(
      selected,
      func,
      HotRegionRef::root(),
    )
    let expected = cfg_continuation_guard_reference_segments(
      original,
      func,
      HotRegionRef::root(),
    )
    assert_eq(actual.rows, expected.rows)
    assert_eq(selected.cfg, original.cfg)
    cfg_verify(cfg_build(func, expand_operand_control=expanded))
  }
}

///|
// Frozen v17 packed segmentation, including empty continuation queries.
fn cfg_continuation_guard_reference_segments(
  builder : CfgBuilder,
  func : HotFunc,
  region_ref : HotRegionRef,
) -> CfgRegionSegments {
  // Retained original reference includes eager source-order initialization.
  if builder.operand_seen is Some(_) && builder.source_order is None {
    builder.source_order = Some(HotSourceOrderFacts::new(func))
  }
  let segments = CfgRegionSegments::new()
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
    segments.push(block_id, root_slots[end - 1] + 1, ordered_nodes[end - 1])
    start = end
  }
  segments
}
