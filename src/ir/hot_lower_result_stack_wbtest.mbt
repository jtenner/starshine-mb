///|
test "lower result stack preserves scalar tuple block and GC result order without changing interned types" {
  let func = HotFunc::new()
  let values = [
    @lib.ValType::i32(),
    @lib.ValType::i64(),
    @lib.ValType::f64(),
    @lib.ValType::externref(),
  ]
  let shapes = [
    hot_type_intern_void(func),
    hot_type_intern_value(func, @lib.ValType::i32()),
    hot_type_intern_value(func, @lib.ValType::f64()),
    hot_type_intern_value(func, @lib.ValType::externref()),
    hot_type_intern_block_result(func, @lib.BlockType::void_()),
    hot_type_intern_block_result(
      func,
      @lib.BlockType::val_type(@lib.ValType::i64()),
    ),
    hot_type_intern_results(func, values),
    hot_type_intern_results(func, []),
    hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [@lib.ValType::f32()],
      values,
    ),
  ]
  for shape in shapes {
    // The helper reads only a node's result type; no opcode/region admission is changed.
    let node = hot_build_node(func, HotOp::Nop, shape)
    let expected = hot_type_results(func, shape)
    let revision = hot_revision_current(func)
    let stack : HotLowerValueStack = hot_lower_value_stack_makei(1, fn(_) {
      { node_id: -1, val_type: @lib.ValType::f32(), }
    })
    hot_lower_impl_push_results(func, node, stack)
    hot_lower_impl_push_results(func, node, stack)
    assert_eq(stack.length(), 1 + 2 * expected.length())
    assert_eq(stack[0].node_id, -1)
    assert_eq(stack[0].val_type, @lib.ValType::f32())
    for index in 0..<(2 * expected.length()) {
      assert_eq(stack[index + 1].node_id, node)
      assert_eq(stack[index + 1].val_type, expected[index % expected.length()])
    }
    stack.clear()
    let owned = hot_type_results(func, shape)
    owned.clear()
    assert_eq(hot_type_results(func, shape), expected)
    assert_eq(hot_revision_current(func), revision)
  }
}
