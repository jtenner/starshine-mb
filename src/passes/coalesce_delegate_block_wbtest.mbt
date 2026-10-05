///|
test "coalesce-locals keeps a block targeted by a legacy delegate" {
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::try_(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::nop()]),
          [],
          delegate=Some(@lib.LabelIdx::new(0U)),
        ),
      ]),
    ),
  ]
  assert_false(cl_flatten_terminal_unbranched_void_blocks(body))
  assert_true(body[0] is @lib.Block(_, _))
}
