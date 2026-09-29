///|
test "expanded reverse actions execute each local access exactly once" {
  let func = HotFunc::new(
    locals=HotLocals::new(locals=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  let first = hot_build_local_get(func, 0)
  let write = hot_build_local_set(func, 1, first)
  let second = hot_build_local_get(func, 1)
  hot_root_append(func, write)
  hot_root_append(func, hot_build_drop(func, second))
  let cfg = cfg_build(func, expand_operand_control=true)
  let actions = local_graph_reverse_action_sequences(func, cfg)
  let flattened : Array[NodeId] = []
  for sequence in actions {
    flattened.append(sequence)
  }
  assert_eq(flattened, [first, write, second])
  let graph = local_graph_build_reverse_flow(func, cfg, true)
  assert_eq(local_graph_reaching_sources_for_get(graph, first), [
    HotLocalGraphSource::EntrySource(0),
  ])
  assert_eq(local_graph_reaching_sources_for_get(graph, second), [
    HotLocalGraphSource::SetSource(write),
  ])
}

///|
test "expanded reverse flow matches dense reaching definitions across control" {
  for
    source in [
      "(module (func (param i32) (result i32) local.get 0 block i32.const 11 local.set 0 end local.get 0 i32.add))",
      "(module (func (param i32) (result i32) i32.const 5 local.set 0 local.get 0 block i32.const 11 local.set 0 end local.get 0 i32.add))",
      "(module (func (param i32) (result i32) (local i32) i32.const 2 local.set 1 loop (result i32) local.get 0 local.get 0 i32.const 1 i32.add local.set 0 local.get 1 i32.const 1 i32.sub local.tee 1 br_if 0 end local.get 0 i32.add))",
      "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 7 local.set 1 else local.get 1 drop end local.get 1))",
      "(module (func (param i32) (result i32) (local i32) block local.get 0 if i32.const 7 local.set 1 br 1 end i32.const 9 local.set 1 end local.get 1))",
      "(module (type $s (func (param i32) (result i32))) (func (param i32) (result i32) local.get 0 i32.const 7 local.tee 0 if (type $s) local.get 0 i32.add else local.get 0 i32.sub end))",
    ] {
    let input = ir_test_module_from_wat(source)
    let func = hot_lift_func(input, @lib.FuncIdx::new(0U))
    let cfg = cfg_build(func, expand_operand_control=true)
    let dense = local_graph_build_with_exceptional_policy(func, cfg, true)
    let actual = local_graph_build_full_flow(func, cfg)
    for id in 0..<hot_node_count(func) {
      if hot_node_is_live(func, id) && hot_node_op(func, id) is HotOp::LocalGet {
        let expected = local_graph_reaching_sources_for_get(dense, id)
        let sources = local_graph_reaching_sources_for_get(actual, id)
        assert_eq(sources.length(), expected.length())
        for source in expected {
          assert_true(sources.contains(source))
        }
      }
    }
    hot_verify_all(func).unwrap()
  }
}
