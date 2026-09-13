///|
test "parity followup constraint removes branchless folded condition block shell" {
  let input = @binary.decode_module(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x07, 0x01, 0x60, 0x02,
      0x7f, 0x7f, 0x01, 0x7f, 0x03, 0x02, 0x01, 0x00, 0x06, 0x06, 0x01, 0x7f, 0x01,
      0x41, 0x00, 0x0b, 0x07, 0x07, 0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00, 0x0a,
      0x1c, 0x01, 0x1a, 0x01, 0x01, 0x7f, 0x41, 0x00, 0x22, 0x00, 0x41, 0x00, 0x46,
      0x04, 0x7f, 0x41, 0x01, 0x24, 0x00, 0x20, 0x00, 0x41, 0x00, 0x46, 0x05, 0x41,
      0x00, 0x0b, 0x0b,
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
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    // Keep assignment and conditional effects in order without their shell.
    assert_false(body.any(fn(instr) { instr is @lib.Block(_, _) }))
  }
}

///|
test "parity followup constraint removes branchless copied control block shell" {
  let input = @binary.decode_module(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x07, 0x01, 0x60, 0x02,
      0x7f, 0x7f, 0x01, 0x7f, 0x03, 0x02, 0x01, 0x00, 0x06, 0x06, 0x01, 0x7f, 0x01,
      0x41, 0x00, 0x0b, 0x07, 0x0f, 0x02, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00, 0x05,
      0x73, 0x74, 0x61, 0x74, 0x65, 0x03, 0x00, 0x0a, 0x1d, 0x01, 0x1b, 0x01, 0x01,
      0x7f, 0x02, 0x7f, 0x20, 0x00, 0x04, 0x40, 0x23, 0x00, 0x41, 0xf7, 0x00, 0x6a,
      0x24, 0x00, 0x0b, 0x20, 0x01, 0x0b, 0x21, 0x02, 0x20, 0x02, 0x45, 0x0b,
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
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    // Keep assignment and conditional effects in order without their shell.
    assert_false(body.any(fn(instr) { instr is @lib.Block(_, _) }))
  }
}

///|
test "constraint block flattening intentionally excludes branch targets and block parameters" {
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
        ),
      ),
    ]),
  )
  for
    body in [
      [
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::i32_const(7),
            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
          ]),
        ),
      ],
      [
        @lib.Instruction::i32_const(7),
        @lib.Instruction::block(
          @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
          @lib.Expr::new([]),
        ),
      ],
    ] {
    let original = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
    let (output, changed) = ca_lower_cleanup_raw(original, mod_)
    assert_false(changed)
    assert_eq(output, original)
  }
}
