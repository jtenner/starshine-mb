///|
test "directize removable suffix stops after the nearest nonremovable producer" {
  let out = [
    @lib.Instruction::nop(),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::i32_const(@lib.I32(100)),
  ]
  assert_eq(directize_removable_suffix_lower_bound(out, 3), 3)
  assert_eq(
    directize_removable_suffix_lower_bound(
      [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(100)),
      ],
      2,
    ),
    0,
  )
}
