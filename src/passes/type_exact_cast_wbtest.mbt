///|
test "type index rewrite preserves exact cast branch flags" {
  let source = @lib.HeapType::new(@lib.TypeIdx::new(3U))
  let target = @lib.HeapType::new(@lib.TypeIdx::new(4U))
  for source_exact in [false, true] {
    for target_exact in [false, true] {
      for fail_branch in [false, true] {
        let input = if fail_branch {
          @lib.Instruction::br_on_cast_fail(
            @lib.LabelIdx::new(2U),
            true,
            source,
            false,
            target,
            source_exact~,
            target_exact~,
          )
        } else {
          @lib.Instruction::br_on_cast(
            @lib.LabelIdx::new(2U),
            true,
            source,
            false,
            target,
            source_exact~,
            target_exact~,
          )
        }
        for remap in [{ 3U: 1U }, { 4U: 2U }, { 3U: 1U, 4U: 2U }] {
          let expected = if fail_branch {
            @lib.Instruction::br_on_cast_fail(
              @lib.LabelIdx::new(2U),
              true,
              dfe_rewrite_heap_type(source, remap),
              false,
              dfe_rewrite_heap_type(target, remap),
              source_exact~,
              target_exact~,
            )
          } else {
            @lib.Instruction::br_on_cast(
              @lib.LabelIdx::new(2U),
              true,
              dfe_rewrite_heap_type(source, remap),
              false,
              dfe_rewrite_heap_type(target, remap),
              source_exact~,
              target_exact~,
            )
          }
          @debug.assert_eq(
            dfe_rewrite_instruction_type_idxs(input, remap),
            expected,
          )
          @debug.assert_eq(
            dfe_try_rewrite_instruction_type_idxs(input, remap),
            Some(expected),
          )
        }
      }
    }
  }
}
