///|
test "memory-packing segment-limit guard allows exact wasm maximum only" {
  assert_false(mp_data_segment_limit_exceeded(99999, 1, 0))
  assert_false(mp_data_segment_limit_exceeded(99998, 1, 1))
  assert_true(mp_data_segment_limit_exceeded(99999, 2, 0))
}

///|
test "memory-packing operand scanner uses exact validator stack deltas" {
  let heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  @debug.assert_eq(
    mp_instr_stack_counts(@lib.Instruction::table_set(@lib.TableIdx::new(0U))),
    Some((2, 0)),
  )
  @debug.assert_eq(
    mp_instr_stack_counts(
      @lib.Instruction::array_copy(@lib.TypeIdx::new(0U), @lib.TypeIdx::new(0U)),
    ),
    Some((5, 0)),
  )
  @debug.assert_eq(
    mp_instr_stack_counts(@lib.Instruction::br_on_null(@lib.LabelIdx::new(0U))),
    Some((1, 1)),
  )
  @debug.assert_eq(
    mp_instr_stack_counts(@lib.Instruction::ref_test_desc(false, heap)),
    Some((2, 1)),
  )
  @debug.assert_eq(
    mp_instr_stack_counts(@lib.Instruction::ref_cast_desc_eq(false, heap)),
    Some((2, 1)),
  )
}
