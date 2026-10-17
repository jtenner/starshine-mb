///|
// Exact pre-change region builder for source-order admission controls.
fn cfg_region_proof_reference(
  builder : CfgBuilder,
  func : HotFunc,
  region_ref : HotRegionRef,
  handler_target~ : BlockId? = None,
) -> CfgRegionSegments {
  let segments = CfgRegionSegments::new()
  let region_holder = cfg_builder_region_holder(region_ref)
  let root_count = hot_region_root_count(func, region_ref)
  let expanded = builder.operand_seen is Some(_)
  let ordered_nodes : Array[NodeId] = []
  let root_slots : Array[Int32] = []
  let roots : Array[NodeId] = []
  if expanded {
    for slot = 0; slot < root_count; slot = slot + 1 {
      roots.push(hot_region_get(func, region_ref, slot))
    }
  }
  let facts = if expanded && root_count > 1 {
    match builder.source_order {
      Some(facts) => Some(facts)
      None => {
        let minima = match builder.operand_minima {
          Some(minima) => minima
          None => {
            let minima = Array::make(hot_node_count(func), -1)
            builder.operand_minima = Some(minima)
            minima
          }
        }
        if cfg_region_may_need_source_order(func, roots, minima) {
          let facts = HotSourceOrderFacts::new(func)
          builder.source_order = Some(facts)
          Some(facts)
        } else {
          None
        }
      }
    }
  } else {
    None
  }
  let suffix_minima = match facts {
    Some(facts) => hot_source_order_future_suffix_minima(func, roots, facts)
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
        // Even after another region initialized facts, the final root has
        // no future statement to constrain. Operand expansion still runs.
        if slot + 1 < root_count && facts is Some(_) {
          let facts = facts.unwrap()
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
      let previous_op = hot_node_get(func, previous).op
      if cfg_op_is_terminator(previous_op) ||
        (
          handler_target is Some(_) &&
          (
            previous_op is HotOp::Call ||
            previous_op is HotOp::CallIndirect ||
            previous_op is HotOp::CallRef
          )
        ) {
        break
      }
      let next = ordered_nodes[end]
      if hot_is_control_node(func, next) {
        break
      }
      if cfg_expression_has_continuation_targets(
          func,
          previous,
          builder.continuation_targets,
        ) ||
        (
          previous_op is HotOp::Drop &&
          cfg_region_segment_break_after_drop_operand_control(func, previous)
        ) {
        break
      }
      end = end + 1
    }
    let nodes = cfg_copy_segment_nodes(ordered_nodes, start, end)
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

///|
fn cfg_region_proof_fixture(
  siblings : Int32,
  width : Int32,
) -> (HotFunc, Array[HotRegionRef]) {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let regions : Array[HotRegionRef] = []
  for region = 0; region < siblings + 2; region = region + 1 {
    let roots : Array[NodeId] = []
    if region == 0 || region == siblings + 1 {
      let carried = hot_build_local_get(func, 0)
      roots.push(
        hot_build_local_set(func, 0, hot_build_const_i32(func, @lib.I32(9))),
      )
      roots.push(hot_build_drop(func, carried))
    } else {
      for index in 0..<width {
        roots.push(
          hot_build_local_set(
            func,
            0,
            hot_build_const_i32(func, @lib.I32(index)),
          ),
        )
        roots.push(hot_build_drop(func, hot_build_local_get(func, 0)))
      }
    }
    let holder = hot_build_block(func, @lib.BlockType::void_(), roots)
    hot_root_append(func, holder)
    regions.push(hot_region_body_ref(func, holder))
  }
  hot_verify_all_or_abort(func)
  (func, regions)
}

///|
test "CFG ordered siblings retain exact fields without source-order query workspace" {
  let (func, regions) = cfg_region_proof_fixture(4, 8)
  let revision = hot_revision_current(func)
  let selected = cfg_builder_new(func, true, true)
  let reference = cfg_builder_new(func, true, true)
  let first = cfg_builder_region_segments(selected, func, regions[0])
  let expected_first = cfg_region_proof_reference(reference, func, regions[0])
  assert_eq(first.rows, expected_first.rows)
  assert_eq(selected.cfg, reference.cfg)
  let facts = selected.source_order.unwrap()
  assert_true(facts.dependency_scratch is Some(_))
  // Release only the private query workspace to detect work in the siblings.
  // Source facts and their immutable operand snapshot remain fully populated.
  facts.dependency_scratch = None
  for index = 1; index < regions.length() - 1; index = index + 1 {
    let actual = cfg_builder_region_segments(selected, func, regions[index])
    let expected = cfg_region_proof_reference(reference, func, regions[index])
    assert_eq(actual.rows, expected.rows)
    assert_eq(selected.cfg, reference.cfg)
    assert_eq(actual.length(), 1)
    let block = selected.cfg.blocks[actual.block_id(0)]
    assert_eq(block.nodes.length(), 32)
    assert_eq(block.start_slot, 0)
    assert_eq(block.end_slot, 16)
    assert_true(physical_equal(facts, selected.source_order.unwrap()))
    assert_true(
      facts.dependency_scratch is None,
      msg="ordered sibling allocated source-order query workspace",
    )
  }
  // A later carried region must still use the shared facts and preserve reads.
  let last = regions[regions.length() - 1]
  let actual = cfg_builder_region_segments(selected, func, last)
  let expected = cfg_region_proof_reference(reference, func, last)
  assert_eq(actual.rows, expected.rows)
  assert_eq(selected.cfg, reference.cfg)
  assert_true(facts.dependency_scratch is Some(_))
  let write = hot_region_get(func, last, 0)
  let drop = hot_region_get(func, last, 1)
  assert_eq(selected.cfg.blocks[actual.block_id(0)].nodes, [
    hot_child_get(func, drop, 0),
    hot_child_get(func, write, 0),
    write,
    drop,
  ])
  assert_eq(hot_revision_current(func), revision)
  cfg_verify(cfg_build(func, expand_operand_control=true))
}
