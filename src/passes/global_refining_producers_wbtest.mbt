///|
test "global-refining maps stacked null producers in one forward scan" {
  let instrs = [
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::eq())),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(1U)),
  ]
  let producers = gr_null_write_producers(instrs, @lib.Module::new(), [])
  @debug.assert_eq(producers, [-1, -1, 1, 0])
}
