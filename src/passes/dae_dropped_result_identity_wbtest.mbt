///|
test "DAE dropped-result cleanup retains unchanged body and nested instruction identities" {
  let body = [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::nop()]),
    ),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
  ]
  let (unchanged, count) = dae_rewrite_dropped_result_calls_with_policy_instrs(
    body, 0, false,
  )
  assert_eq(count, 0)
  assert_eq(unchanged, body)
  assert_true(physical_equal(unchanged, body))
  assert_true(physical_equal(unchanged[0], body[0]))
}

///|
test "DAE dropped-result cleanup preserves normalization and dead suffixes without counted rewrites" {
  let fixtures = [
    [
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([@lib.Instruction::unreachable_()]),
      ),
      @lib.Instruction::nop(),
    ],
    [
      @lib.Instruction::unreachable_(),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    ],
    [
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::nop(),
    ],
    [
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          @lib.Instruction::drop(),
        ]),
      ),
    ],
  ]
  for body in fixtures {
    for stop in [false, true] {
      for preserve in [false, true] {
        let (actual, count) = dae_rewrite_dropped_result_calls_with_policy_instrs(
          body,
          0,
          stop,
          preserve_uninhabitable_control=preserve,
        )
        let (expected, expected_count) = dae_dropped_result_cleanup_reference(
          body,
          0,
          stop,
          preserve_uninhabitable_control=preserve,
        )
        assert_eq(actual, expected)
        assert_eq(count, expected_count)
      }
    }
  }
}
