///|
test "lowering operand queries preserve order without copying dense child slots" {
  let func = HotFunc::new()
  let left = hot_build_const_i32(func, @lib.I32(7))
  let right = hot_build_const_i32(func, @lib.I32(9))
  let sum = hot_build_binary(func, @lib.ValType::i32(), left, right)
  let copies = [0]
  let inputs = hot_lower_impl_input_info(func, sum, copied_slots=Some(copies))
  assert_eq(inputs.nodes.length(), 2)
  assert_eq(inputs.nodes[0], left)
  assert_eq(inputs.nodes[1], right)
  assert_eq(inputs.pop_count, 2)
  assert_eq(copies[0], 0)
}

///|
test "lowering operand views separate control headers from their regions" {
  let func = HotFunc::new()
  let first = hot_build_const_i32(func, @lib.I32(7))
  let second = hot_build_const_i32(func, @lib.I32(9))
  let condition = hot_build_const_i32(func, @lib.I32(1))
  let body = hot_build_drop(func, first)
  let block = hot_build_block(func, @lib.BlockType::void_(), [body])
  let if_ = hot_build_if(
    func,
    @lib.BlockType::void_(),
    condition,
    [body],
    else_body=Some([]),
  )
  let ty = hot_type_intern_resolved_block_result(
    func,
    @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
    [@lib.ValType::i32(), @lib.ValType::i32()],
    [],
  )
  let loop_ = hot_build_node(func, HotOp::Loop, ty, children=[
    first, second, body,
  ])
  let label = hot_label_alloc(func, HotLabelKind::LoopLabel, ty, loop_, 2)
  hot_node_set(func, loop_, { ..hot_node_get(func, loop_), imm0: label, })
  let block_inputs = hot_lower_impl_input_info(func, block)
  assert_eq(block_inputs.nodes.length(), 0)
  assert_eq(block_inputs.pop_count, 0)
  let copies = [0]
  let if_inputs = hot_lower_impl_input_info(
    func,
    if_,
    copied_slots=Some(copies),
  )
  assert_eq(if_inputs.nodes.length(), 1)
  assert_eq(if_inputs.nodes[0], condition)
  assert_eq(if_inputs.pop_count, 1)
  let loop_inputs = hot_lower_impl_input_info(
    func,
    loop_,
    copied_slots=Some(copies),
  )
  assert_eq(loop_inputs.nodes.length(), 2)
  assert_eq(loop_inputs.nodes[0], first)
  assert_eq(loop_inputs.nodes[1], second)
  assert_eq(loop_inputs.pop_count, 2)
  assert_eq(copies[0], 0)
}

///|
test "lowering operand queries retain duplicate lanes and compact intentionally absent slots" {
  let func = HotFunc::new()
  let tuple = hot_build_call(
    func,
    0,
    [@lib.ValType::i32(), @lib.ValType::i32()],
    [],
  )
  let consumer = hot_build_call(func, 1, [], [tuple, tuple])
  let duplicate = hot_lower_impl_input_info(func, consumer)
  assert_eq(duplicate.nodes.length(), 2)
  assert_eq(duplicate.nodes[0], tuple)
  assert_eq(duplicate.nodes[1], tuple)
  assert_eq(duplicate.pop_count, 2)
  // An intentionally absent child is omitted by this query's existing contract.
  let sparse = hot_build_node(func, HotOp::Call, hot_type_void(func), children=[
    tuple,
    HOT_NONE_NODE,
    tuple,
  ])
  let copies = [0]
  let filtered = hot_lower_impl_input_info(
    func,
    sparse,
    copied_slots=Some(copies),
  )
  assert_eq(filtered.nodes.length(), 2)
  assert_eq(filtered.nodes[0], tuple)
  assert_eq(filtered.nodes[1], tuple)
  assert_eq(filtered.pop_count, 2)
  assert_eq(copies[0], 2)
}

///|
test "lowering branch operands keep payloads while consuming only branch selectors" {
  let func = HotFunc::new()
  let payload = hot_build_const_i32(func, @lib.I32(7))
  let selector = hot_build_const_i32(func, @lib.I32(1))
  for
    op in [
      HotOp::BrIf,
      HotOp::BrTable,
      HotOp::BrOnNull,
      HotOp::BrOnNonNull,
      HotOp::BrOnCast,
      HotOp::BrOnCastFail,
    ] {
    let branch = hot_build_node(func, op, hot_type_void(func), children=[
      payload, selector,
    ])
    if op is HotOp::BrOnCast || op is HotOp::BrOnCastFail {
      let heap = @lib.HeapType::new(@lib.TypeIdx::new(0U))
      let instr = if op is HotOp::BrOnCast {
        @lib.Instruction::br_on_cast(
          @lib.LabelIdx::new(0U),
          true,
          heap,
          true,
          heap,
        )
      } else {
        @lib.Instruction::br_on_cast_fail(
          @lib.LabelIdx::new(0U),
          true,
          heap,
          true,
          heap,
        )
      }
      hot_node_exact_instr_set(func, branch, instr)
    }
    let inputs = hot_lower_impl_input_info(func, branch)
    assert_eq(inputs.nodes.length(), 2)
    assert_eq(inputs.nodes[0], payload)
    assert_eq(inputs.nodes[1], selector)
    assert_eq(inputs.pop_count, 1)
  }
  let branch = hot_build_node(func, HotOp::BrOnCast, hot_type_void(func), children=[
    payload, selector,
  ])
  let ref_type = @lib.RefType::new(
    true,
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
  )
  hot_node_exact_instr_set(
    func,
    branch,
    @lib.Instruction::br_on_cast_desc_eq(
      @lib.LabelIdx::new(0U),
      ref_type,
      ref_type,
    ),
  )
  assert_eq(hot_lower_impl_input_info(func, branch).pop_count, 2)
}
