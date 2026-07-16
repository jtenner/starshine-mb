///|
test "root mutation helpers splice insert remove and bump revision once per edit" {
  let func = HotFunc::new()
  let first = hot_build_nop(func)
  let second = hot_build_unreachable(func)
  let third = hot_build_drop(func, hot_build_const_i32(func, @lib.I32(9)))

  let rev0 = hot_revision_current(func)
  hot_root_append(func, first)
  @debug.assert_eq(hot_revision_current(func), rev0 + 1)
  @debug.assert_eq(hot_root_count(func), 1)
  @debug.assert_eq(hot_root_get(func, 0), first)

  let rev1 = hot_revision_current(func)
  hot_root_insert(func, 0, second)
  @debug.assert_eq(hot_revision_current(func), rev1 + 1)
  @debug.assert_eq(hot_root_count(func), 2)
  @debug.assert_eq(hot_root_get(func, 0), second)
  @debug.assert_eq(hot_root_get(func, 1), first)

  let rev2 = hot_revision_current(func)
  let removed = hot_root_splice(func, 1, 1, [third, first])
  @debug.assert_eq(hot_revision_current(func), rev2 + 1)
  @debug.assert_eq(removed, [first])
  @debug.assert_eq(hot_root_count(func), 3)
  @debug.assert_eq(hot_root_get(func, 0), second)
  @debug.assert_eq(hot_root_get(func, 1), third)
  @debug.assert_eq(hot_root_get(func, 2), first)

  let rev3 = hot_revision_current(func)
  let removed_root = hot_root_remove(func, 0)
  @debug.assert_eq(hot_revision_current(func), rev3 + 1)
  @debug.assert_eq(removed_root, second)
  @debug.assert_eq(hot_root_count(func), 2)
  @debug.assert_eq(hot_root_get(func, 0), third)
  @debug.assert_eq(hot_root_get(func, 1), first)
}

///|
test "child span replacement rewires node children and returns replaced slots" {
  let func = HotFunc::new()
  let first = hot_build_const_i32(func, @lib.I32(1))
  let second = hot_build_const_i32(func, @lib.I32(2))
  let third = hot_build_const_i32(func, @lib.I32(3))
  let block = hot_build_block(func, @lib.BlockType::void_(), [first])

  let rev0 = hot_revision_current(func)
  let replaced = hot_replace_child_span(func, block, [first, second, third])
  @debug.assert_eq(hot_revision_current(func), rev0 + 1)
  @debug.assert_eq(replaced, [first])
  @debug.assert_eq(hot_child_count(func, block), 3)
  @debug.assert_eq(hot_child_get(func, block, 0), first)
  @debug.assert_eq(hot_child_get(func, block, 1), second)
  @debug.assert_eq(hot_child_get(func, block, 2), third)
}

///|
test "batched child span replacement and control result updates bump revision once" {
  let func = HotFunc::new()
  let payload = hot_build_const_i32(func, @lib.I32(1))
  let if_id = hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    hot_build_const_i32(func, @lib.I32(1)),
    [hot_build_const_i32(func, @lib.I32(2))],
    else_body=Some([hot_build_const_i32(func, @lib.I32(3))]),
  )
  let branch = hot_build_br(func, hot_control_node_label(func, if_id), values=[
    payload,
  ])
  hot_region_replace_body(func, hot_region_then_ref(func, if_id), [branch])

  let rev0 = hot_revision_current(func)
  hot_replace_child_spans_and_control_result_type(
    func,
    if_id,
    hot_type_void(func),
    [HotChildSpanRewrite::new(branch, [])],
  )
  @debug.assert_eq(hot_revision_current(func), rev0 + 1)
  @debug.assert_eq(hot_child_count(func, branch), 0)
  @debug.assert_eq(hot_node_result_arity(func, if_id), 0)
  @debug.assert_eq(
    hot_label_branch_arity(func, hot_control_node_label(func, if_id)),
    0,
  )
}

///|
test "node deletion records tombstones without immediate free-list reuse" {
  let func = HotFunc::new()
  let deleted = hot_build_nop(func)
  let survivor = hot_build_unreachable(func)

  hot_root_append(func, survivor)
  let rev0 = hot_revision_current(func)
  hot_delete_node(func, deleted)
  @debug.assert_eq(hot_revision_current(func), rev0 + 1)
  assert_false(hot_node_is_live(func, deleted))
  assert_true(hot_node_is_live(func, survivor))

  let next = hot_build_unreachable(func)
  @debug.assert_eq(next, 2)

  let rev1 = hot_revision_current(func)
  hot_revision_bump(func)
  @debug.assert_eq(hot_revision_current(func), rev1 + 1)
}

///|
test "node deletion keeps large free-list liveness queries correct" {
  let func = HotFunc::new()
  let nodes : Array[Int] = []
  for idx = 0; idx < 40; idx = idx + 1 {
    ignore(idx)
    nodes.push(hot_build_nop(func))
  }

  for idx = 0; idx < 35; idx = idx + 1 {
    hot_delete_node(func, nodes[idx])
  }

  assert_false(hot_node_is_live(func, nodes[0]))
  assert_false(hot_node_is_live(func, nodes[34]))
  assert_true(hot_node_is_live(func, nodes[35]))
  assert_true(hot_node_is_live(func, nodes[39]))

  let fresh = hot_build_unreachable(func)
  assert_true(hot_node_is_live(func, fresh))
}

///|
test "body local append helper returns the next local id and bumps revision" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i64(),
    ]),
  )

  let rev0 = hot_revision_current(func)
  let first = hot_append_body_local(func, @lib.ValType::f32())
  @debug.assert_eq(first, 2)
  @debug.assert_eq(hot_revision_current(func), rev0 + 1)
  @debug.assert_eq(hot_local_count(func), 3)
  @debug.assert_eq(hot_local_body_count(func), 2)
  @debug.assert_eq(hot_local_type(func, first), Some(@lib.ValType::f32()))

  let rev1 = hot_revision_current(func)
  let second = hot_append_body_local(func, @lib.ValType::i32())
  @debug.assert_eq(second, 3)
  @debug.assert_eq(hot_revision_current(func), rev1 + 1)
  @debug.assert_eq(hot_local_count(func), 4)
  @debug.assert_eq(hot_local_body_count(func), 3)
  @debug.assert_eq(hot_local_type(func, second), Some(@lib.ValType::i32()))
}

///|
test "detached node deletion fast path records tombstones without immediate free-list reuse" {
  let func = HotFunc::new()
  let deleted = hot_build_nop(func)
  let survivor = hot_build_unreachable(func)

  hot_root_append(func, survivor)
  let rev0 = hot_revision_current(func)
  hot_delete_detached_node(func, deleted)
  @debug.assert_eq(hot_revision_current(func), rev0 + 1)
  assert_false(hot_node_is_live(func, deleted))
  assert_true(hot_node_is_live(func, survivor))

  let next = hot_build_unreachable(func)
  @debug.assert_eq(next, 2)
}

///|
test "batched detached node deletion tombstones the whole set with one revision" {
  let func = HotFunc::new()
  let first = hot_build_nop(func)
  let second = hot_build_const_i32(func, @lib.I32(9))
  let third = hot_build_unreachable(func)
  let survivor = hot_build_nop(func)
  hot_root_append(func, survivor)

  let rev0 = hot_revision_current(func)
  hot_delete_detached_nodes(func, [first, second, third])
  @debug.assert_eq(hot_revision_current(func), rev0 + 1)
  assert_false(hot_node_is_live(func, first))
  assert_false(hot_node_is_live(func, second))
  assert_false(hot_node_is_live(func, third))
  assert_true(hot_node_is_live(func, survivor))

  let next = hot_build_unreachable(func)
  @debug.assert_eq(next, 4)
}

///|
test "detached structured subtree deletion removes owned labels atomically" {
  let func = HotFunc::new()
  let condition = hot_build_const_i32(func, @lib.I32(1))
  let nested_if = hot_build_if(
    func,
    @lib.BlockType::void_(),
    condition,
    [hot_build_nop(func)],
    else_body=Some([hot_build_unreachable(func)]),
  )
  let subtree = hot_build_block(func, @lib.BlockType::void_(), [nested_if])
  let subtree_label = hot_control_node_label(func, subtree)
  let if_label = hot_control_node_label(func, nested_if)
  let then_holder = hot_child_get(func, nested_if, 1)
  let else_holder = hot_child_get(func, nested_if, 2)
  let then_label = hot_control_node_label(func, then_holder)
  let else_label = hot_control_node_label(func, else_holder)
  let survivor = hot_build_nop(func)
  hot_root_append(func, survivor)

  let rev0 = hot_revision_current(func)
  assert_true(hot_delete_detached_control_subtree(func, subtree))
  @debug.assert_eq(hot_revision_current(func), rev0 + 1)
  for node_id in [condition, nested_if, then_holder, else_holder, subtree] {
    assert_false(hot_node_is_live(func, node_id))
  }
  for label_id in [subtree_label, if_label, then_label, else_label] {
    assert_false(hot_label_is_live(func, label_id))
  }
  assert_true(hot_node_is_live(func, survivor))
  match hot_verify_control(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected structured subtree deletion to verify, got \{err}")
  }

  let externally_targeted = HotFunc::new()
  let targeted = hot_build_block(externally_targeted, @lib.BlockType::void_(), [
    hot_build_nop(externally_targeted),
  ])
  let targeted_label = hot_control_node_label(externally_targeted, targeted)
  hot_root_append(
    externally_targeted,
    hot_build_br(externally_targeted, targeted_label),
  )
  let targeted_revision = hot_revision_current(externally_targeted)
  assert_false(
    hot_delete_detached_control_subtree(externally_targeted, targeted),
  )
  @debug.assert_eq(hot_revision_current(externally_targeted), targeted_revision)
  assert_true(hot_node_is_live(externally_targeted, targeted))
  assert_true(hot_label_is_live(externally_targeted, targeted_label))

  let shared = HotFunc::new()
  let shared_child = hot_build_nop(shared)
  let shared_subtree = hot_build_block(shared, @lib.BlockType::void_(), [
    shared_child, shared_child,
  ])
  let shared_revision = hot_revision_current(shared)
  assert_false(hot_delete_detached_control_subtree(shared, shared_subtree))
  @debug.assert_eq(hot_revision_current(shared), shared_revision)
  assert_true(hot_node_is_live(shared, shared_subtree))
  assert_true(hot_node_is_live(shared, shared_child))
}

///|
test "detached mixed forest deletion owns ordinary nodes and structured labels atomically" {
  let func = HotFunc::new()
  let scalar_const = hot_build_const_i32(func, @lib.I32(1))
  let scalar_drop = hot_build_drop(func, scalar_const)
  let block_const = hot_build_const_i32(func, @lib.I32(2))
  let block_drop = hot_build_drop(func, block_const)
  let block_id = hot_build_block(func, @lib.BlockType::void_(), [block_drop])
  let block_label = hot_control_node_label(func, block_id)
  let dead_unreachable = hot_build_unreachable(func)
  let survivor = hot_build_nop(func)
  hot_root_append(func, survivor)

  let rev0 = hot_revision_current(func)
  assert_true(
    hot_delete_detached_forest(func, [scalar_drop, block_id, dead_unreachable]),
  )
  @debug.assert_eq(hot_revision_current(func), rev0 + 1)
  for
    node_id in [
      scalar_const, scalar_drop, block_const, block_drop, block_id, dead_unreachable,
    ] {
    assert_false(hot_node_is_live(func, node_id))
  }
  assert_false(hot_label_is_live(func, block_label))
  assert_true(hot_node_is_live(func, survivor))
  match hot_verify_control(func) {
    Ok(_) => ()
    Err(err) => fail("expected mixed forest deletion to verify, got \{err}")
  }

  let blocked = HotFunc::new()
  let blocked_const = hot_build_const_i32(blocked, @lib.I32(3))
  let blocked_drop = hot_build_drop(blocked, blocked_const)
  let blocked_loop = hot_build_loop(blocked, @lib.BlockType::void_(), [
    hot_build_nop(blocked),
  ])
  let blocked_label = hot_control_node_label(blocked, blocked_loop)
  hot_root_append(blocked, hot_build_br(blocked, blocked_label))
  let blocked_revision = hot_revision_current(blocked)
  assert_false(
    hot_delete_detached_forest(blocked, [blocked_drop, blocked_loop]),
  )
  @debug.assert_eq(hot_revision_current(blocked), blocked_revision)
  assert_true(hot_node_is_live(blocked, blocked_const))
  assert_true(hot_node_is_live(blocked, blocked_drop))
  assert_true(hot_node_is_live(blocked, blocked_loop))
  assert_true(hot_label_is_live(blocked, blocked_label))
}

///|
test "detached structured forest deletion preflights every tree before one mutation" {
  let func = HotFunc::new()
  let block_const = hot_build_const_i32(func, @lib.I32(1))
  let block_drop = hot_build_drop(func, block_const)
  let block_id = hot_build_block(func, @lib.BlockType::void_(), [block_drop])
  let block_label = hot_control_node_label(func, block_id)

  let condition = hot_build_const_i32(func, @lib.I32(1))
  let then_const = hot_build_const_i32(func, @lib.I32(2))
  let then_drop = hot_build_drop(func, then_const)
  let else_const = hot_build_const_i32(func, @lib.I32(3))
  let else_drop = hot_build_drop(func, else_const)
  let if_id = hot_build_if(
    func,
    @lib.BlockType::void_(),
    condition,
    [then_drop],
    else_body=Some([else_drop]),
  )
  let if_label = hot_control_node_label(func, if_id)
  let then_holder = hot_region_then_ref(func, if_id).holder
  let then_label = hot_control_node_label(func, then_holder)
  let else_holder = hot_region_else_ref(func, if_id).unwrap().holder
  let else_label = hot_control_node_label(func, else_holder)

  let loop_const = hot_build_const_i32(func, @lib.I32(4))
  let loop_drop = hot_build_drop(func, loop_const)
  let loop_id = hot_build_loop(func, @lib.BlockType::void_(), [loop_drop])
  let loop_label = hot_control_node_label(func, loop_id)
  let survivor = hot_build_nop(func)
  hot_root_append(func, survivor)

  let rev0 = hot_revision_current(func)
  assert_true(
    hot_delete_detached_control_forest(func, [block_id, if_id, loop_id]),
  )
  @debug.assert_eq(hot_revision_current(func), rev0 + 1)
  for
    node_id in [
      block_const, block_drop, block_id, condition, then_const, then_drop, then_holder,
      else_const, else_drop, else_holder, if_id, loop_const, loop_drop, loop_id,
    ] {
    assert_false(hot_node_is_live(func, node_id))
  }
  for label_id in [block_label, if_label, then_label, else_label, loop_label] {
    assert_false(hot_label_is_live(func, label_id))
  }
  assert_true(hot_node_is_live(func, survivor))
  match hot_verify_control(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected structured forest deletion to verify, got \{err}")
  }

  let blocked = HotFunc::new()
  let first = hot_build_block(blocked, @lib.BlockType::void_(), [
    hot_build_nop(blocked),
  ])
  let second = hot_build_loop(blocked, @lib.BlockType::void_(), [
    hot_build_nop(blocked),
  ])
  let second_label = hot_control_node_label(blocked, second)
  hot_root_append(blocked, hot_build_br(blocked, second_label))
  let blocked_revision = hot_revision_current(blocked)
  assert_false(hot_delete_detached_control_forest(blocked, [first, second]))
  @debug.assert_eq(hot_revision_current(blocked), blocked_revision)
  assert_true(hot_node_is_live(blocked, first))
  assert_true(hot_node_is_live(blocked, second))
  assert_true(
    hot_label_is_live(blocked, hot_control_node_label(blocked, first)),
  )
  assert_true(hot_label_is_live(blocked, second_label))
}

///|
test "label owner helper rehomes built control labels to replacement node ids" {
  let func = HotFunc::new()
  let temp_block = hot_build_block(func, @lib.BlockType::void_(), [
    hot_build_const_i32(func, @lib.I32(1)),
  ])
  let replacement = hot_build_nop(func)
  let replacement_node = hot_node_get(func, temp_block)
  let label_id = hot_control_node_label(func, temp_block)

  hot_node_set(func, replacement, replacement_node)
  hot_label_owner_set(func, label_id, replacement)
  hot_root_append(func, replacement)
  hot_delete_node(func, temp_block)

  @debug.assert_eq(hot_label_owner(func, label_id), replacement)
  match hot_verify_control(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected rehomed control label verification success, got \{err}")
  }
}

///|
test "scalar catch payload repair captures the first descendant atomically" {
  let func = HotFunc::new()
  let payload = hot_build_catch_payload(
    func,
    @lib.TagIdx::new(0U),
    @lib.ValType::i32(),
  )
  let payload_drop = hot_build_drop(func, payload)
  let inner = hot_build_block(func, @lib.BlockType::void_(), [payload_drop])
  let outer = hot_build_block(func, @lib.BlockType::void_(), [inner])
  let try_id = hot_build_try(
    func,
    @lib.BlockType::void_(),
    [hot_build_nop(func)],
    catch_body=Some([payload, outer]),
  )
  hot_root_append(func, try_id)

  assert_true(hot_scalar_catch_payloads_repairable(func))
  let revision = hot_revision_current(func)
  assert_true(hot_repair_scalar_catch_payloads(func))
  assert_true(hot_revision_current(func) > revision)
  @debug.assert_eq(hot_local_count(func), 1)
  @debug.assert_eq(hot_local_type(func, 0), Some(@lib.ValType::i32()))
  let catch_ref = hot_region_catch_ref(func, try_id).unwrap()
  @debug.assert_eq(hot_region_root_count(func, catch_ref), 3)
  @debug.assert_eq(hot_region_get(func, catch_ref, 0), payload)
  let capture = hot_region_get(func, catch_ref, 1)
  @debug.assert_eq(hot_node_get(func, capture).op.to_string(), "LocalSet")
  @debug.assert_eq(hot_node_get(func, capture).imm0, 0)
  @debug.assert_eq(hot_child_get(func, capture, 0), payload)
  @debug.assert_eq(hot_region_get(func, catch_ref, 2), outer)
  let replacement = hot_child_get(func, payload_drop, 0)
  @debug.assert_eq(hot_node_get(func, replacement).op.to_string(), "LocalGet")
  @debug.assert_eq(hot_node_get(func, replacement).imm0, 0)
  match hot_verify_control(func) {
    Ok(_) => ()
    Err(err) => fail("expected repaired catch payload to verify, got \{err}")
  }

  let blocked = HotFunc::new()
  let blocked_payload = hot_build_catch_payload(
    blocked,
    @lib.TagIdx::new(0U),
    @lib.ValType::i32(),
  )
  let blocked_drop = hot_build_drop(blocked, blocked_payload)
  let blocked_loop = hot_build_loop(blocked, @lib.BlockType::void_(), [
    blocked_drop,
  ])
  let blocked_try = hot_build_try(
    blocked,
    @lib.BlockType::void_(),
    [hot_build_nop(blocked)],
    catch_body=Some([blocked_payload, blocked_loop]),
  )
  hot_root_append(blocked, blocked_try)
  let blocked_revision = hot_revision_current(blocked)
  let blocked_nodes = hot_node_count(blocked)
  let blocked_locals = hot_local_count(blocked)
  let blocked_catch_ref = hot_region_catch_ref(blocked, blocked_try).unwrap()
  let blocked_roots = hot_region_root_count(blocked, blocked_catch_ref)

  assert_false(hot_scalar_catch_payloads_repairable(blocked))
  assert_false(hot_repair_scalar_catch_payloads(blocked))
  @debug.assert_eq(hot_revision_current(blocked), blocked_revision)
  @debug.assert_eq(hot_node_count(blocked), blocked_nodes)
  @debug.assert_eq(hot_local_count(blocked), blocked_locals)
  @debug.assert_eq(
    hot_region_root_count(blocked, blocked_catch_ref),
    blocked_roots,
  )
  @debug.assert_eq(hot_child_get(blocked, blocked_drop, 0), blocked_payload)
}

///|
test "ordered two-lane catch repair captures payloads atomically" {
  let func = HotFunc::new()
  let first = hot_build_catch_payload(
    func,
    @lib.TagIdx::new(0U),
    @lib.ValType::i32(),
  )
  let second = hot_build_catch_payload(
    func,
    @lib.TagIdx::new(0U),
    @lib.ValType::f32(),
  )
  let first_drop = hot_build_drop(func, first)
  let second_drop = hot_build_drop(func, second)
  let inner = hot_build_block(func, @lib.BlockType::void_(), [
    first_drop, second_drop,
  ])
  let outer = hot_build_block(func, @lib.BlockType::void_(), [inner])
  let try_id = hot_build_try(
    func,
    @lib.BlockType::void_(),
    [hot_build_nop(func)],
    catch_body=Some([first, second, outer]),
  )
  hot_root_append(func, try_id)

  assert_false(hot_scalar_catch_payloads_repairable(func))
  assert_true(hot_ordered_catch_payloads_repairable(func))
  assert_true(hot_repair_ordered_catch_payloads(func))
  @debug.assert_eq(hot_local_count(func), 2)
  @debug.assert_eq(hot_local_type(func, 0), Some(@lib.ValType::i32()))
  @debug.assert_eq(hot_local_type(func, 1), Some(@lib.ValType::f32()))
  let catch_ref = hot_region_catch_ref(func, try_id).unwrap()
  @debug.assert_eq(hot_region_root_count(func, catch_ref), 5)
  @debug.assert_eq(hot_region_get(func, catch_ref, 0), first)
  @debug.assert_eq(hot_region_get(func, catch_ref, 1), second)
  let second_capture = hot_region_get(func, catch_ref, 2)
  let first_capture = hot_region_get(func, catch_ref, 3)
  @debug.assert_eq(
    hot_node_get(func, second_capture).op.to_string(),
    "LocalSet",
  )
  @debug.assert_eq(hot_node_get(func, second_capture).imm0, 1)
  @debug.assert_eq(hot_child_get(func, second_capture, 0), second)
  @debug.assert_eq(hot_node_get(func, first_capture).op.to_string(), "LocalSet")
  @debug.assert_eq(hot_node_get(func, first_capture).imm0, 0)
  @debug.assert_eq(hot_child_get(func, first_capture, 0), first)
  @debug.assert_eq(hot_region_get(func, catch_ref, 4), outer)
  let first_get = hot_child_get(func, first_drop, 0)
  let second_get = hot_child_get(func, second_drop, 0)
  @debug.assert_eq(hot_node_get(func, first_get).op.to_string(), "LocalGet")
  @debug.assert_eq(hot_node_get(func, first_get).imm0, 0)
  @debug.assert_eq(hot_node_get(func, second_get).op.to_string(), "LocalGet")
  @debug.assert_eq(hot_node_get(func, second_get).imm0, 1)
  match hot_verify_control(func) {
    Ok(_) => ()
    Err(err) => fail("expected ordered catch repair to verify, got \{err}")
  }
}

///|
test "ordered two-lane catch repair rejects a partial lane without mutation" {
  let func = HotFunc::new()
  let first = hot_build_catch_payload(
    func,
    @lib.TagIdx::new(0U),
    @lib.ValType::i32(),
  )
  let second = hot_build_catch_payload(
    func,
    @lib.TagIdx::new(0U),
    @lib.ValType::f32(),
  )
  let first_drop = hot_build_drop(func, first)
  let second_drop = hot_build_drop(func, second)
  let inner = hot_build_block(func, @lib.BlockType::void_(), [
    first_drop, second_drop,
  ])
  let outer = hot_build_block(func, @lib.BlockType::void_(), [inner])
  let try_id = hot_build_try(
    func,
    @lib.BlockType::void_(),
    [hot_build_nop(func)],
    catch_body=Some([first, second, outer]),
  )
  hot_root_append(func, try_id)
  let outside_drop = hot_build_drop(func, second)
  hot_root_append(func, outside_drop)
  let revision = hot_revision_current(func)
  let node_count = hot_node_count(func)
  let local_count = hot_local_count(func)
  let root_count = hot_root_count(func)
  let catch_ref = hot_region_catch_ref(func, try_id).unwrap()
  let catch_root_count = hot_region_root_count(func, catch_ref)

  assert_false(hot_ordered_catch_payloads_repairable(func))
  assert_false(hot_repair_ordered_catch_payloads(func))
  @debug.assert_eq(hot_revision_current(func), revision)
  @debug.assert_eq(hot_node_count(func), node_count)
  @debug.assert_eq(hot_local_count(func), local_count)
  @debug.assert_eq(hot_root_count(func), root_count)
  @debug.assert_eq(hot_region_root_count(func, catch_ref), catch_root_count)
  @debug.assert_eq(hot_child_get(func, first_drop, 0), first)
  @debug.assert_eq(hot_child_get(func, second_drop, 0), second)
  @debug.assert_eq(hot_child_get(func, outside_drop, 0), second)
}

///|
test "appended body locals lower in append order" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  ignore(hot_append_body_local(func, @lib.ValType::f32()))
  ignore(hot_append_body_local(func, @lib.ValType::i64()))

  let lowered = hot_lower_func(func)
  let @lib.Func(locals, body) = lowered

  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::f32(),
      @lib.ValType::i64(),
    ]),
  )
  @debug.assert_eq(body, @lib.Expr::new([]))
}
