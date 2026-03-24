///|
test "lifted control nodes expose label ownership and branch arity" {
  let func = hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [@lib.Instruction::nop()],
            Some([@lib.Instruction::nop()]),
          ),
          @lib.Instruction::loop_(
            @lib.BlockType::val_type(@lib.ValType::i32()),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(2))]),
          ),
        ]),
      ),
    ]),
    HotLocals::new(),
  )

  let block = hot_root_get(func, 0)
  let if_ = hot_child_get(func, block, 0)
  let loop_ = hot_child_get(func, block, 1)

  let block_label = hot_control_node_label(func, block)
  let if_label = hot_control_node_label(func, if_)
  let loop_label = hot_control_node_label(func, loop_)

  assert_eq(hot_label_owner(func, block_label), block)
  assert_eq(hot_label_owner(func, if_label), if_)
  assert_eq(hot_label_owner(func, loop_label), loop_)

  match hot_label_kind(func, block_label) {
    BlockLabel => ()
    _ => fail("expected block label")
  }
  match hot_label_kind(func, if_label) {
    IfLabel => ()
    _ => fail("expected if label")
  }
  match hot_label_kind(func, loop_label) {
    LoopLabel => ()
    _ => fail("expected loop label")
  }

  assert_eq(hot_label_branch_arity(func, block_label), 0)
  assert_eq(hot_label_branch_arity(func, if_label), 0)
  assert_eq(hot_label_branch_arity(func, loop_label), 1)

  assert_eq(
    hot_label_result_type(func, block_label),
    hot_node_get(func, block).ty,
  )
  assert_eq(hot_label_result_type(func, if_label), hot_node_get(func, if_).ty)
  assert_eq(
    hot_label_result_type(func, loop_label),
    hot_node_get(func, loop_).ty,
  )
}
