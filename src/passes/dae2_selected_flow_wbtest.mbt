///|
test "DAE2 selects every unresolved read and excludes complete entry proofs" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32 i32 i32) (result i32) local.get 1 i32.const 1 i32.add local.set 1 local.get 1 if i32.const 7 local.set 0 end local.get 1 if i32.const 9 local.set 0 end local.get 0))",
  )
  @validate.validate_module(input).unwrap()
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let entry = dae2_entry_read_sources(func)
  assert_true(entry is Some(_))
  let written = [true, true, false]
  let mask = dae2_unresolved_flow_reads(func, written, entry)
  let selected = Array::makei(mask.length(), fn(node) { node }).filter(fn(
    node,
  ) {
    mask[node]
  })
  assert_eq(selected.length(), 1)
  let read = @ir.hot_node_get(func, selected[0])
  assert_true(read.op is @ir.LocalGet)
  assert_eq(read.imm0, 0)
  let all = dae2_unresolved_flow_reads(func, written, None)
  assert_true(all.filter(fn(bit) { bit }).length() > 1)
  let cfg = @ir.cfg_build(func, expand_operand_control=true)
  let complete = @ir.local_graph_build_read_sources(func, cfg)
  let partial = @ir.local_graph_build_read_sources(
    func,
    cfg,
    selected_gets=Some(mask),
  )
  for node in selected {
    let count = @ir.local_read_source_count_for_get(complete, node)
    assert_eq(@ir.local_read_source_count_for_get(partial, node), count)
    for source in 0..<count {
      assert_eq(
        @ir.local_read_source_value_for_get(partial, node, source),
        @ir.local_read_source_value_for_get(complete, node, source),
      )
    }
  }
}
