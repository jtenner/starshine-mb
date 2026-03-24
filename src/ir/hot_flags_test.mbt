///|
test "lifted nodes expose canonical flag helpers" {
  let func = hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([@lib.Instruction::nop()]),
      ),
      @lib.Instruction::i32_const(@lib.I32(7)),
      @lib.Instruction::return_(),
    ]),
    HotLocals::new(param_count=0, locals=[]),
    body_result_type=@lib.BlockType::val_type(@lib.ValType::i32()),
  )

  let block = hot_root_get(func, 0)
  let ret = hot_root_get(func, 1)
  let ret_value = hot_child_get(func, ret, 0)

  assert_eq(
    hot_node_flags(func, block),
    hot_default_flags_for_op(hot_node_get(func, block).op),
  )
  assert_true(hot_is_control_node(func, block))
  assert_false(hot_is_terminator_node(func, block))
  assert_false(hot_has_side_effect(func, block))

  assert_eq(
    hot_node_flags(func, ret),
    hot_default_flags_for_op(hot_node_get(func, ret).op),
  )
  assert_true(hot_is_terminator_node(func, ret))
  assert_true(hot_has_side_effect(func, ret))
  assert_false(hot_is_control_node(func, ret))

  assert_eq(
    hot_node_flags(func, ret_value),
    hot_default_flags_for_op(hot_node_get(func, ret_value).op),
  )
  assert_false(hot_has_side_effect(func, ret_value))
  assert_false(hot_is_terminator_node(func, ret_value))
}
