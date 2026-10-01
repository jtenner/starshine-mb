///|
fn access_fields_fixture(depth : Int) -> (HotFunc, NodeId) {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  let mut value = hot_build_local_get(func, 0)
  for i in 0..<depth {
    let write = hot_build_local_tee(
      func,
      1,
      hot_build_const_i32(func, @lib.I32(i)),
    )
    value = hot_build_binary(func, @lib.ValType::i32(), value, write)
  }
  (func, value)
}

///|
fn access_fields_assert(func : HotFunc, roots : Array[NodeId]) -> Unit raise {
  let facts = HotSourceOrderFacts::new(func)
  let reference = HotSourceOrderFacts::new(func)
  let revision = hot_revision_current(func)
  let free = func.free_nodes.copy()
  for root in roots {
    for _ in 0..<2 {
      assert_eq(
        hot_source_order_local_access_nodes(func, root, facts),
        access_fields_reference_nodes(func, root, reference),
      )
    }
    assert_eq(
      hot_lower_impl_local_state_child_count(func, root),
      access_fields_reference_child_count(func, root),
    )
  }
  assert_eq(hot_revision_current(func), revision)
  assert_eq(func.free_nodes, free)
}

///|
test "checked access fields preserve exact scalar traversal and borrowed cached rows" {
  let (func, root) = access_fields_fixture(8)
  access_fields_assert(func, [root])
  let facts = HotSourceOrderFacts::new(func)
  let first = hot_source_order_local_access_nodes(func, root, facts)
  assert_eq(first.length(), 9)
  assert_true(
    physical_equal(
      first,
      hot_source_order_local_access_nodes(func, root, facts),
    ),
  )
  let shared = hot_build_binary(func, @lib.ValType::i32(), root, root)
  access_fields_assert(func, [shared])
}

///|
test "checked local-state fields keep block loop dead-tail and legacy deletion admission" {
  for op in [HotOp::Block, HotOp::Loop] {
    let func = HotFunc::new(
      locals=HotLocals::new(params=[@lib.ValType::i32(), @lib.ValType::i32()]),
    )
    let deleted = hot_build_nop(func)
    let live_read = hot_build_local_get(func, 0)
    let dead_read = hot_build_local_get(func, 1)
    let roots = [
      hot_build_drop(func, live_read),
      hot_build_unreachable(func),
      hot_build_drop(func, dead_read),
    ]
    // This is the local-state query's explicit region-child layout, including
    // its intentionally supported dead tail after an unconditional terminator.
    let node = hot_build_node(func, op, hot_type_void(func), children=roots)
    let label = hot_label_alloc(
      func,
      if op == HotOp::Block {
        HotLabelKind::BlockLabel
      } else {
        HotLabelKind::LoopLabel
      },
      hot_type_void(func),
      node,
      0,
    )
    hot_node_set(func, node, { ..hot_node_get(func, node), imm0: label, })
    assert_eq(hot_lower_impl_local_state_child_count(func, node), 2)
    access_fields_assert(func, [node])
    assert_eq(
      hot_source_order_local_access_nodes(
        func,
        node,
        HotSourceOrderFacts::new(func),
      ),
      [live_read],
    )
    hot_delete_node(func, deleted)
    func.deleted_nodes.clear()
    access_fields_assert(func, [node])
  }
}
