///|
test "SGO dropped-if cleanup checks purity only at a real candidate" {
  let candidate_free = Array::make(20, @lib.Instruction::i32_const(@lib.I32(1)))
  let checks = [0]
  assert_eq(
    sgo_final_cleanup_dropped_pure_result_if_length(
      candidate_free,
      0,
      purity_checks=Some(checks),
    ),
    0,
  )
  assert_eq(checks[0], 0)
  let candidate = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [@lib.Instruction::i32_const(@lib.I32(3))],
      Some([@lib.Instruction::i32_const(@lib.I32(4))]),
    ),
    @lib.Instruction::drop(),
  ]
  checks[0] = 0
  assert_eq(
    sgo_final_cleanup_dropped_pure_result_if_length(
      candidate,
      0,
      purity_checks=Some(checks),
    ),
    5,
  )
  assert_eq(checks[0], 1)
  let (cleaned, changed) = sgo_final_cleanup_instrs(candidate)
  assert_true(changed)
  assert_eq(cleaned, [])
  assert_eq(candidate.length(), 5)
}
