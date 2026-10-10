///|
test "type index rewrite covers continuation and descriptor operands" {
  let a = @lib.TypeIdx::new(3U)
  let b = @lib.TypeIdx::new(4U)
  let x = @lib.TypeIdx::new(1U)
  let y = @lib.TypeIdx::new(2U)
  let label = @lib.LabelIdx::new(7U)
  let tag = @lib.TagIdx::new(5U)
  let handlers = [
    @lib.ResumeHandler::on_label(tag, label),
    @lib.ResumeHandler::on_switch(tag),
  ]
  let source = @lib.RefType::new(true, @lib.HeapType::new(a), exact=true)
  let target = @lib.RefType::new(false, @lib.HeapType::new(b), exact=true)
  let next_source = @lib.RefType::new(true, @lib.HeapType::new(x), exact=true)
  let next_target = @lib.RefType::new(false, @lib.HeapType::new(y), exact=true)
  let pairs = [
    (@lib.Instruction::cont_new(a), @lib.Instruction::cont_new(x)),
    (@lib.Instruction::cont_bind(a, b), @lib.Instruction::cont_bind(x, y)),
    (
      @lib.Instruction::resume_(a, handlers),
      @lib.Instruction::resume_(x, handlers),
    ),
    (
      @lib.Instruction::resume_throw(a, tag, handlers),
      @lib.Instruction::resume_throw(x, tag, handlers),
    ),
    (
      @lib.Instruction::resume_throw_ref(a, handlers),
      @lib.Instruction::resume_throw_ref(x, handlers),
    ),
    (
      @lib.Instruction::stack_switch(a, tag),
      @lib.Instruction::stack_switch(x, tag),
    ),
    (
      @lib.Instruction::br_on_cast_desc_eq(label, source, target),
      @lib.Instruction::br_on_cast_desc_eq(label, next_source, next_target),
    ),
    (
      @lib.Instruction::br_on_cast_desc_eq_fail(label, source, target),
      @lib.Instruction::br_on_cast_desc_eq_fail(label, next_source, next_target),
    ),
  ]
  let remap = { 3U: 1U, 4U: 2U }
  for (input, expected) in pairs {
    @debug.assert_eq(dfe_rewrite_instruction_type_idxs(input, remap), expected)
    @debug.assert_eq(
      dfe_try_rewrite_instruction_type_idxs(input, remap),
      Some(expected),
    )
    @debug.assert_eq(
      dfe_try_rewrite_instruction_type_idxs(input, { 7U: 1U }),
      None,
    )
  }
}

///|
test "type index rewrite handles unilateral continuation and descriptor remaps" {
  let a = @lib.TypeIdx::new(3U)
  let b = @lib.TypeIdx::new(4U)
  let source = @lib.RefType::new(true, @lib.HeapType::new(a), exact=true)
  let target = @lib.RefType::new(false, @lib.HeapType::new(b), exact=true)
  for remap in [{ 3U: 1U }, { 4U: 2U }] {
    let expected_source = dfe_rewrite_ref_type(source, remap)
    let expected_target = dfe_rewrite_ref_type(target, remap)
    for
      (input, expected) in [
        (
          @lib.Instruction::cont_bind(a, b),
          @lib.Instruction::cont_bind(
            dfe_rewrite_type_idx(a, remap),
            dfe_rewrite_type_idx(b, remap),
          ),
        ),
        (
          @lib.Instruction::br_on_cast_desc_eq(
            @lib.LabelIdx::new(7U),
            source,
            target,
          ),
          @lib.Instruction::br_on_cast_desc_eq(
            @lib.LabelIdx::new(7U),
            expected_source,
            expected_target,
          ),
        ),
        (
          @lib.Instruction::br_on_cast_desc_eq_fail(
            @lib.LabelIdx::new(7U),
            source,
            target,
          ),
          @lib.Instruction::br_on_cast_desc_eq_fail(
            @lib.LabelIdx::new(7U),
            expected_source,
            expected_target,
          ),
        ),
      ] {
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
