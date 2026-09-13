///|
test "parity followup constraint result loop needs no outer stack closure" {
  // Keep the generator's original stack encoding: WAT authoring itself can
  // refinalize bottom control and hide the cleanup opportunity.
  let input = @binary.decode_module(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x0c, 0x02, 0x60, 0x00,
      0x02, 0x7f, 0x7c, 0x60, 0x01, 0x7f, 0x02, 0x7f, 0x7c, 0x03, 0x02, 0x01, 0x01,
      0x07, 0x07, 0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00, 0x0a, 0x4b, 0x01, 0x49,
      0x01, 0x02, 0x7f, 0x03, 0x00, 0x20, 0x00, 0x22, 0x02, 0x41, 0xf3, 0xea, 0xa0,
      0xf6, 0x01, 0x46, 0x04, 0x00, 0x20, 0x02, 0x44, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0xf4, 0x3f, 0x0f, 0x05, 0x20, 0x01, 0x41, 0x02, 0x49, 0x04, 0x7f, 0x20,
      0x01, 0x41, 0x01, 0x6a, 0x22, 0x01, 0x1a, 0x41, 0x01, 0x05, 0x41, 0x00, 0x0b,
      0x04, 0x00, 0x0c, 0x02, 0x05, 0x20, 0x02, 0x44, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x04, 0x40, 0x0f, 0x0b, 0x0b, 0x0b, 0x0b,
    ]),
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "constraint-analysis",
  ]).unwrap()
  assert_true(@validate.validate_module(output) is Ok(_))
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  // The sole loop already has exactly the enclosing function's result types.
  // Its terminating body requires neither outer drops nor an unreachable.
  assert_eq(body.length(), 1)
  assert_true(body[0] is @lib.Loop(_, _))
}

///|
test "parity followup constraint parameter loop returns stack result directly" {
  let input = @binary.decode_module(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x0a, 0x02, 0x60, 0x01,
      0x7f, 0x00, 0x60, 0x01, 0x7f, 0x01, 0x7f, 0x03, 0x02, 0x01, 0x01, 0x07, 0x07,
      0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00, 0x0a, 0x29, 0x01, 0x27, 0x01, 0x01,
      0x7f, 0x20, 0x00, 0x41, 0x16, 0x71, 0x21, 0x00, 0x02, 0x7f, 0x41, 0x00, 0x03,
      0x01, 0x21, 0x01, 0x20, 0x01, 0x41, 0x01, 0x6a, 0x20, 0x01, 0x20, 0x00, 0x4f,
      0x0e, 0x01, 0x00, 0x01, 0x0b, 0x0b, 0x21, 0x01, 0x20, 0x01, 0x0b,
    ]),
  ).unwrap()
  for
    output in [
      run_hot_pipeline(input, HotPipelineOptions::new(), ["constraint-analysis"]).unwrap(),
      run_hot_pipeline_apply_hot_pass_stack(
        input,
        [pass_registry_lookup("constraint-analysis").unwrap()],
        HotPipelineOptions::new(),
      ).unwrap(),
      run_hot_pipeline_apply_hot_pass_stack_to_touched(
        input,
        [constraint_analysis_descriptor()],
        [true],
        HotPipelineOptions::new(),
      ).unwrap(),
    ] {
    assert_true(@validate.validate_module(output) is Ok(_))
    let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    // Preserve the parameter loop's body local and return its stack result.
    assert_eq(locals.length(), 1)
    assert_true(body[body.length() - 1] is @lib.Block(_, _))
  }
}

///|
test "constraint terminal local cleanup intentionally excludes nested writes and different indices" {
  let zero = @lib.LocalIdx::new(0U)
  let one = @lib.LocalIdx::new(1U)
  // A nested write can be observed after the region. A different final read
  // does not reproduce the stored value. Neither is this cleanup's identity.
  for
    body in [
      [
        @lib.Instruction::i32_const(7),
        @lib.Instruction::local_set(zero),
        @lib.Instruction::local_get(one),
      ],
      [
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::i32_const(7),
            @lib.Instruction::local_set(zero),
            @lib.Instruction::local_get(zero),
          ]),
        ),
      ],
    ] {
    let original = @lib.Func::new(
      @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
      @lib.Expr::new(body),
    )
    let (output, changed) = ca_lower_trim_terminal_local_roundtrip(original)
    assert_false(changed)
    assert_eq(output, original)
  }
}
