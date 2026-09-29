///|
test "writer facts allocate their known arena spans once" {
  for count in [0, 15] {
    let func = HotFunc::new()
    for _ in 0..<count {
      hot_root_append(func, hot_build_nop(func))
    }
    let facts = local_graph_build_write_facts(func)
    assert_eq(facts.local_ids, Array::make(count, -1))
    assert_eq(facts.is_tees, Array::make(count, false))
    assert_eq(facts.local_ids.capacity(), count)
    assert_eq(facts.is_tees.capacity(), count)
  }
}

///|
test "writer facts preserve live set tee and incomplete deletion-index rows" {
  let (func, actions) = local_graph_write_index_fixture()
  let deleted = hot_build_local_tee(
    func,
    3,
    hot_build_const_i32(func, @lib.I32(19)),
  )
  hot_delete_node(func, deleted)
  let revision = hot_revision_current(func)
  let free = func.free_nodes.copy()
  for incomplete in [false, true] {
    if incomplete {
      func.deleted_nodes.clear()
    }
    let facts = local_graph_build_write_facts(func)
    assert_eq(facts.local_ids, write_facts_reference_locals(func))
    assert_eq(facts.is_tees, write_facts_reference_tees(func))
    assert_eq(facts.local_ids[actions[0]], 0)
    assert_eq(facts.local_ids[actions[1]], -1)
    assert_eq(facts.local_ids[actions[2]], 1)
    assert_eq(facts.local_ids[actions[3]], 0)
    assert_true(facts.is_tees[actions[2]])
    assert_false(facts.is_tees[actions[0]])
    assert_eq(facts.local_ids[deleted], -1)
    assert_false(facts.is_tees[deleted])
    assert_eq(hot_revision_current(func), revision)
    assert_eq(func.free_nodes, free)
  }
}

///|
test "all LocalGraph builders retain the original writer metadata" {
  let (func, _, _, _) = local_graph_predecessor_cache_fixture(4, overwrite=true)
  for expanded in [false, true] {
    let cfg = cfg_build(func, expand_operand_control=expanded)
    for
      graph in [
        local_graph_build(func, cfg),
        local_graph_build_full_flow(func, cfg),
        local_graph_build_sparse_flow(func, cfg, true),
      ] {
      assert_eq(graph.write_local_ids, write_facts_reference_locals(func))
      assert_eq(graph.write_is_tees, write_facts_reference_tees(func))
    }
  }
}

///|
fn write_facts_reference_locals(func : HotFunc) -> Array[LocalId] {
  let write_local_ids : Array[LocalId] = []
  for node_id = 0; node_id < hot_node_count(func); node_id = node_id + 1 {
    if hot_node_is_live(func, node_id) {
      let node = hot_node_get(func, node_id)
      match node.op {
        HotOp::LocalSet | HotOp::LocalTee => write_local_ids.push(node.imm0)
        _ => write_local_ids.push(-1)
      }
    } else {
      write_local_ids.push(-1)
    }
  }
  write_local_ids
}

///|
fn write_facts_reference_tees(func : HotFunc) -> Array[Bool] {
  let write_is_tees : Array[Bool] = []
  for node_id = 0; node_id < hot_node_count(func); node_id = node_id + 1 {
    if hot_node_is_live(func, node_id) {
      let node = hot_node_get(func, node_id)
      match node.op {
        HotOp::LocalTee => write_is_tees.push(true)
        _ => write_is_tees.push(false)
      }
    } else {
      write_is_tees.push(false)
    }
  }
  write_is_tees
}
