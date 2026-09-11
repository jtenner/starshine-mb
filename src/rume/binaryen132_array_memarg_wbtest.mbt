///|
test "Binaryen 132 array memory operations follow type index remapping" {
  let before = @lib.TypeIdx::new(2U)
  let after = @lib.TypeIdx::new(1U)
  let remap = Map([(2U, 1U)])
  for
    entry in [
      (
        @lib.Instruction::array_load(@lib.LoadOp::i32_load(), before),
        @lib.Instruction::array_load(@lib.LoadOp::i32_load(), after),
      ),
      (
        @lib.Instruction::array_store(@lib.StoreOp::i64_store32(), before),
        @lib.Instruction::array_store(@lib.StoreOp::i64_store32(), after),
      ),
    ] {
    let (input, expected) = entry
    @debug.assert_eq(dfe_rewrite_instruction_type_idxs(input, remap), expected)
    @debug.assert_eq(
      dfe_try_rewrite_instruction_type_idxs(input, remap),
      Some(expected),
    )
  }
}
