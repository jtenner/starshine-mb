///|
fn region_fields_assert_snapshot(func : HotFunc) -> Unit raise {
  let revision = hot_revision_current(func)
  let free = func.free_nodes.copy()
  let deleted = func.deleted_nodes.copy()
  let children = func.children.copy()
  for id in 0..<hot_node_count(func) {
    assert_eq(
      hot_region_is_region_holder(func, id),
      region_fields_header_holder(func, id),
    )
    if !hot_node_is_live(func, id) {
      continue
    }
    assert_eq(hot_query_op(func, id), hot_node_get(func, id).op)
    assert_eq(
      hot_control_node_label(func, id),
      region_fields_header_label(func, id),
    )
    assert_eq(
      hot_region_body_base(func, id),
      region_fields_header_base(func, id),
    )
    if region_fields_header_holder(func, id) {
      let region = hot_region_body_ref(func, id)
      assert_eq(region.holder, id)
      assert_eq(
        hot_region_root_count(func, region),
        region_fields_header_count(func, region),
      )
      for slot in 0..<hot_region_root_count(func, region) {
        assert_eq(
          hot_region_get(func, region, slot),
          region_fields_header_get(func, region, slot),
        )
      }
    }
  }
  assert_false(hot_region_is_region_holder(func, -2))
  assert_false(hot_region_is_region_holder(func, hot_node_count(func)))
  assert_eq(hot_revision_current(func), revision)
  assert_eq(func.free_nodes, free)
  assert_eq(func.deleted_nodes, deleted)
  assert_eq(func.children, children)
}

///|
test "region field queries preserve every control family and absent arms" {
  let func = HotFunc::new()
  let value = hot_build_const_i32(func, @lib.I32(7))
  let body = hot_build_drop(func, value)
  let block = hot_build_block(func, @lib.BlockType::void_(), [body])
  ignore(hot_build_loop(func, @lib.BlockType::void_(), [body]))
  let condition = hot_build_const_i32(func, @lib.I32(1))
  let if_both = hot_build_if(
    func,
    @lib.BlockType::void_(),
    condition,
    [body],
    else_body=Some([body]),
  )
  let if_one = hot_build_if(func, @lib.BlockType::void_(), condition, [body])
  let try_both = hot_build_try(
    func,
    @lib.BlockType::void_(),
    [body],
    catch_body=Some([body]),
  )
  let try_one = hot_build_try(func, @lib.BlockType::void_(), [body])
  let try_table = hot_build_try_table(
    func,
    @lib.BlockType::void_(),
    [HotCatchArm::all(hot_control_node_label(func, block))],
    [body],
  )
  region_fields_assert_snapshot(func)
  assert_eq(hot_region_get(func, hot_region_then_ref(func, if_both), 0), body)
  assert_eq(
    hot_region_get(func, hot_region_else_ref(func, if_both).unwrap(), 0),
    body,
  )
  assert_eq(hot_region_else_ref(func, if_one), None)
  assert_eq(
    hot_region_get(func, hot_region_catch_ref(func, try_both).unwrap(), 0),
    body,
  )
  assert_eq(hot_region_catch_ref(func, try_one), None)
  assert_eq(hot_region_get(func, hot_region_body_ref(func, try_table), 0), body)
  assert_eq(
    hot_region_root_count(func, hot_region_catch_list_ref(func, try_table)),
    0,
  )
}

///|
test "region field queries distinguish indexed control inputs from body roots" {
  let func = HotFunc::new()
  let first = hot_build_const_i32(func, @lib.I32(7))
  let second = hot_build_const_i32(func, @lib.I32(11))
  let body = hot_build_nop(func)
  let ty = hot_type_intern_resolved_block_result(
    func,
    @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
    [@lib.ValType::i32(), @lib.ValType::i32()],
    [],
  )
  // Query-only fixtures exercise the temporary resolved HOT representation;
  // encoded-module validation is covered by the bounded compiler replay.
  for op in [HotOp::Block, HotOp::Loop] {
    let id = hot_build_node(func, op, ty, children=[first, second, body, body])
    let label = hot_label_alloc(
      func,
      if op == HotOp::Loop {
        HotLabelKind::LoopLabel
      } else {
        HotLabelKind::BlockLabel
      },
      ty,
      id,
      if op == HotOp::Loop {
        2
      } else {
        0
      },
    )
    hot_node_set(func, id, {
      ..hot_node_get(func, id),
      imm0: label,
      imm1: if op == HotOp::Block {
        2
      } else {
        0
      },
    })
    assert_eq(hot_region_body_base(func, id), 2)
    let region = hot_region_body_ref(func, id)
    assert_eq(hot_region_root_count(func, region), 2)
    assert_eq(hot_region_get(func, region, 0), body)
    assert_eq(hot_region_get(func, region, 1), body)
  }
  region_fields_assert_snapshot(func)
  hot_root_append(func, first)
  hot_root_append(func, second)
  let root = HotRegionRef::root()
  assert_eq(hot_region_root_count(func, root), 2)
  assert_eq(hot_region_get(func, root, 1), second)
}

///|
test "region field queries preserve deletion fallback and reused node identity" {
  let func = HotFunc::new()
  let deleted = hot_build_nop(func)
  let body = hot_build_nop(func)
  let block = hot_build_block(func, @lib.BlockType::void_(), [body])
  let old_label = hot_control_node_label(func, block)
  hot_delete_node(func, deleted)
  region_fields_assert_snapshot(func)
  func.deleted_nodes.clear()
  region_fields_assert_snapshot(func)
  // Replacing a live node must be visible immediately, without a stale cache.
  hot_node_set(func, block, hot_node_get(func, body))
  assert_eq(hot_control_node_label(func, block), -1)
  assert_false(hot_region_is_region_holder(func, block))
  assert_eq(hot_label_owner(func, old_label), block)
  region_fields_assert_snapshot(func)
}

///|
test "region holder queries fail closed for intentionally invalid labels" {
  let func = HotFunc::new()
  let block = hot_build_block(func, @lib.BlockType::void_(), [
    hot_build_nop(func),
  ])
  let original = hot_node_get(func, block)
  for label in [-1, func.labels.length()] {
    hot_node_set(func, block, { ..original, imm0: label, })
    assert_false(hot_region_is_region_holder(func, block))
    assert_eq(hot_control_node_label(func, block), label)
  }
  hot_node_set(func, block, original)
  let label = hot_control_node_label(func, block)
  let info = hot_label_get(func, label)
  for kind in [HotLabelKind::LoopLabel, HotLabelKind::IfLabel] {
    func.labels[label] = { ..info, kind, }
    assert_false(hot_region_is_region_holder(func, block))
  }
  func.labels[label] = { ..info, kind: HotLabelKind::RegionLabel, }
  assert_true(hot_region_is_region_holder(func, block))
}
