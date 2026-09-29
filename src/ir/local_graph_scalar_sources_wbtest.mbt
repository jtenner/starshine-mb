///|
test "scalar local sources preserve indexed source order and owned query isolation" {
  let input = @wast.wast_to_binary_module(
    "(module (func (param i32 i32 i32) (result i32) local.get 0 if local.get 1 local.set 2 end local.get 2 local.get 2 i32.add))",
  ).unwrap()
  let func = hot_lift_func(input, @lib.FuncIdx::new(0U))
  let cfg = cfg_build(func, expand_operand_control=true)
  for
    graph in [
      local_graph_build_with_exceptional_policy(func, cfg, true),
      local_graph_build_sparse_flow(func, cfg, true),
      local_graph_build_reverse_flow(func, cfg, true),
    ] {
    let mut compared = 0
    for node in 0..<hot_node_count(func) {
      let data = hot_node_get(func, node)
      if data.op is LocalGet {
        let owned = local_graph_reaching_sources_for_get(graph, node)
        let saved = owned.copy()
        owned.clear()
        assert_eq(
          local_graph_reaching_source_count_for_get(graph, node),
          saved.length(),
        )
        for index in 0..<saved.length() {
          let value = local_graph_reaching_source_value_for_get(
            graph, node, index,
          )
          match saved[index] {
            EntrySource(local) => {
              assert_true(value.is_entry)
              assert_eq(value.index, local)
            }
            SetSource(write) => {
              assert_false(value.is_entry)
              assert_eq(value.index, write)
            }
          }
          assert_eq(
            local_graph_reaching_source_for_get(graph, node, index),
            saved[index],
          )
          compared += 1
        }
      }
    }
    assert_true(compared > 0)
  }
}
