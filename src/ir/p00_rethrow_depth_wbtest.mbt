///|
test "P00 raw lower cleanup accounts for rethrow label insertion and removal" {
  let rethrow = @lib.Instruction::rethrow(@lib.LabelIdx::new(1U))
  @debug.assert_eq(
    hot_lower_impl_rebase_instr(rethrow, 0),
    @lib.Instruction::rethrow(@lib.LabelIdx::new(0U)),
  )
  @debug.assert_eq(
    hot_lower_impl_expand_branch_depths_above_instr(rethrow, 0),
    @lib.Instruction::rethrow(@lib.LabelIdx::new(2U)),
  )
  assert_true(hot_lower_impl_instr_targets_removed_label(rethrow, 1))
}
