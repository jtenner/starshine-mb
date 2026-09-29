///|
fn local_graph_unique_reads_fixture(
  count : Int,
) -> (HotFunc, NodeId, Array[NodeId]) {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let write = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  hot_root_append(func, write)
  let reads : Array[NodeId] = []
  for _ in 0..<count {
    let read = hot_build_local_get(func, 0)
    reads.push(read)
    hot_root_append(func, hot_build_drop(func, read))
  }
  (func, write, reads)
}

///|
test "reverse flow preserves every reader once in arena order" {
  let (func, write, reads) = local_graph_unique_reads_fixture(8)
  for expanded in [false, true] {
    let graph = local_graph_build_full_flow(
      func,
      cfg_build(func, expand_operand_control=expanded),
    )
    assert_eq(local_graph_influenced_gets_for_write(graph, write), reads)
    for read in reads {
      assert_eq(local_graph_reaching_sources_for_get(graph, read), [
        SetSource(write),
      ])
    }
  }
  hot_verify_all(func).unwrap()
}

///|
test "reverse influence recording retains joined writes and shared-read fallback" {
  let module_ = ir_test_module_from_wat(
    "(module (func (param i32) (local i32) local.get 0 if i32.const 7 local.set 1 else i32.const 9 local.set 1 end local.get 1 drop local.get 1 drop local.get 1 drop))",
  )
  let func = hot_lift_func(module_, @lib.FuncIdx::new(0U))
  let cfg = cfg_build(func, expand_operand_control=true)
  let actual = local_graph_build_full_flow(func, cfg)
  let expected = local_graph_build_with_exceptional_policy(func, cfg, true)
  let mut writes = 0
  for node in 0..<hot_node_count(func) {
    if hot_node_op(func, node) is HotOp::LocalSet {
      writes += 1
      let readers = local_graph_influenced_gets_for_write(actual, node)
      assert_eq(readers.length(), 3)
      assert_eq(readers, local_graph_influenced_gets_for_write(expected, node))
    }
  }
  assert_eq(writes, 2)
  let (shared, write, reads) = local_graph_unique_reads_fixture(1)
  hot_root_append(shared, hot_build_drop(shared, reads[0]))
  let graph = local_graph_build_full_flow(shared, cfg_build(shared))
  assert_eq(local_graph_influenced_gets_for_write(graph, write), reads)
}
