///|
test "Binaryen 132 struct wait follows type remapping without changing its field" {
  let before = @lib.Instruction::struct_wait(
    @lib.TypeIdx::new(2U),
    @lib.U32(1U),
  )
  let after = @lib.Instruction::struct_wait(@lib.TypeIdx::new(1U), @lib.U32(1U))
  let remap = Map([(2U, 1U)])
  @debug.assert_eq(dfe_rewrite_instruction_type_idxs(before, remap), after)
  @debug.assert_eq(
    dfe_try_rewrite_instruction_type_idxs(before, remap),
    Some(after),
  )
}

///|
test "Binaryen 132 struct wait retains a type used only by its annotation" {
  let used = @bitset.BitSet::new(3)
  rume_mark_instruction_direct_types(
    used,
    @lib.Instruction::struct_wait(@lib.TypeIdx::new(2U), @lib.U32(0U)),
  )
  @debug.assert_eq([used[0], used[1], used[2]], [false, false, true])
}
