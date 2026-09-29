///|
test "indexed local source queries preserve entry write order and owned query isolation" {
  let input = @wast.wast_to_binary_module(
    "(module (func (param i32 i32 i32) (result i32) local.get 0 if local.get 1 local.set 2 end local.get 2 local.get 2 i32.add))",
  ).unwrap()
  let func = hot_lift_func(input, @lib.FuncIdx::new(0U))
  let cfg = cfg_build(func, expand_operand_control=true)
  let reads : Array[NodeId] = []
  let mut write = HOT_NONE_NODE
  let mut entry_read = HOT_NONE_NODE
  for node in 0..<hot_node_count(func) {
    let data = hot_node_get(func, node)
    if data.op is LocalGet && data.imm0 == 2 {
      reads.push(node)
    }
    if data.op is LocalGet && data.imm0 == 0 {
      entry_read = node
    }
    if data.op is LocalSet && data.imm0 == 2 {
      write = node
    }
  }
  assert_eq(reads.length(), 2)
  assert_true(write >= 0 && entry_read >= 0)
  for
    graph in [
      local_graph_build_with_exceptional_policy(func, cfg, true),
      local_graph_build_sparse_flow(func, cfg, true),
      local_graph_build_reverse_flow(func, cfg, true),
    ] {
    assert_eq(local_graph_reaching_source_count_for_get(graph, entry_read), 1)
    assert_eq(
      local_graph_reaching_source_for_get(graph, entry_read, 0),
      EntrySource(0),
    )
    assert_eq(local_graph_reaching_source_count_for_get(graph, write), 0)
    for read in reads {
      let owned = local_graph_reaching_sources_for_get(graph, read)
      assert_eq(owned.length(), 2)
      assert_true(owned.contains(EntrySource(2)))
      assert_true(owned.contains(SetSource(write)))
      assert_eq(
        local_graph_reaching_source_count_for_get(graph, read),
        owned.length(),
      )
      for index in 0..<owned.length() {
        assert_eq(
          local_graph_reaching_source_for_get(graph, read, index),
          owned[index],
        )
      }
      let saved = owned.copy()
      owned.clear()
      for index in 0..<saved.length() {
        assert_eq(
          local_graph_reaching_source_for_get(graph, read, index),
          saved[index],
        )
      }
    }
  }
}

///|
test "indexed local sources keep intentionally unrepresented reads unknown" {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  // Live nodes without roots intentionally have no represented CFG sources.
  let read = hot_build_local_get(func, 0)
  let graph = local_graph_build_full_flow(func, cfg_build(func))
  assert_eq(local_graph_reaching_source_count_for_get(graph, read), 0)
  assert_eq(local_graph_reaching_sources_for_get(graph, read), [])
}
