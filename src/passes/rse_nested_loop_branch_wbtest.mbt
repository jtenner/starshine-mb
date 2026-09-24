///|
test "RSE nested loop branch scan distinguishes branch-free bodies" {
  let quiet : Array[@lib.Instruction] = [
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::eq())),
        @lib.Instruction::drop(),
      ]),
    ),
  ]
  @debug.assert_eq(rse_raw_expr_may_branch(quiet), false)
  let branched : Array[@lib.Instruction] = [
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(0U))]),
    ),
  ]
  @debug.assert_eq(rse_raw_expr_may_branch(branched), true)
}
