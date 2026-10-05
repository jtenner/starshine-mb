///|
test "rse repeated zero reset guard covers legacy try body and catches" {
  let local_idx = @lib.LocalIdx::new(0U)
  let resets = fn(count : Int) {
    let body : Array[@lib.Instruction] = []
    for rep = 0; rep < count; rep = rep + 1 {
      ignore(rep)
      body.push(@lib.Instruction::i32_const(@lib.I32(0)))
      body.push(@lib.Instruction::local_set(local_idx))
    }
    body
  }
  let block = [
    @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(resets(4))),
  ]
  let legacy_try = [
    @lib.Instruction::try_(@lib.BlockType::void_(), @lib.Expr::new(resets(2)), [
      @lib.LegacyCatch::all(@lib.Expr::new(resets(2))),
    ]),
  ]
  assert_true(
    run_hot_pipeline_raw_rse_has_repeated_structured_zero_reset(block),
  )
  assert_true(
    run_hot_pipeline_raw_rse_has_repeated_structured_zero_reset(legacy_try),
  )
}
