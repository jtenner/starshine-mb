///|
test "type index rewrite covers continuation and descriptor operands" {
  let a = @lib.TypeIdx::new(3U)
  let b = @lib.TypeIdx::new(4U)
  let x = @lib.TypeIdx::new(1U)
  let y = @lib.TypeIdx::new(2U)
  let label = @lib.LabelIdx::new(7U)
  let tag = @lib.TagIdx::new(5U)
  let handlers = [@lib.ResumeHandler::on_label(tag, label), @lib.ResumeHandler::on_switch(tag)]
  let source = @lib.RefType::new(true, @lib.HeapType::new(a), exact=true)
  let target = @lib.RefType::new(false, @lib.HeapType::new(b), exact=true)
  let next_source = @lib.RefType::new(true, @lib.HeapType::new(x), exact=true)
  let next_target = @lib.RefType::new(false, @lib.HeapType::new(y), exact=true)
  let pairs = [
    (@lib.Instruction::cont_new(a), @lib.Instruction::cont_new(x)),
    (@lib.Instruction::cont_bind(a, b), @lib.Instruction::cont_bind(x, y)),
    (@lib.Instruction::resume_(a, handlers), @lib.Instruction::resume_(x, handlers)),
    (@lib.Instruction::resume_throw(a, tag, handlers), @lib.Instruction::resume_throw(x, tag, handlers)),
    (@lib.Instruction::resume_throw_ref(a, handlers), @lib.Instruction::resume_throw_ref(x, handlers)),
    (@lib.Instruction::stack_switch(a, tag), @lib.Instruction::stack_switch(x, tag)),
    (@lib.Instruction::br_on_cast_desc_eq(label, source, target), @lib.Instruction::br_on_cast_desc_eq(label, next_source, next_target)),
    (@lib.Instruction::br_on_cast_desc_eq_fail(label, source, target), @lib.Instruction::br_on_cast_desc_eq_fail(label, next_source, next_target)),
  ]
  let remap = { 3U: 1U, 4U: 2U }
  for (input, expected) in pairs {
    @debug.assert_eq(dfe_rewrite_instruction_type_idxs(input, remap), expected)
    @debug.assert_eq(dfe_try_rewrite_instruction_type_idxs(input, remap), Some(expected))
    @debug.assert_eq(dfe_try_rewrite_instruction_type_idxs(input, { 3U: 3U, 4U: 4U }), None)
  }
}
