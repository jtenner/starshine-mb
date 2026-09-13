///|
test "audit inlining recognizes continuation function exits" {
  let type_ = @lib.TypeIdx::new(0U)
  let tag = @lib.TagIdx::new(0U)
  let handlers = [@lib.ResumeHandler::on_label(tag, @lib.LabelIdx::new(0U))]
  for
    instr in [
      @lib.Instruction::resume_(type_, handlers),
      @lib.Instruction::resume_throw(type_, tag, handlers),
      @lib.Instruction::resume_throw_ref(type_, handlers),
    ] {
    assert_true(inl_instrs_have_function_label_escape([instr]))
  }
}

///|
test "audit inlining rebases continuation outer handlers" {
  let type_ = @lib.TypeIdx::new(0U)
  let tag = @lib.TagIdx::new(0U)
  let handlers = [@lib.ResumeHandler::on_label(tag, @lib.LabelIdx::new(0U))]
  for
    instr in [
      @lib.Instruction::resume_(type_, handlers),
      @lib.Instruction::resume_throw(type_, tag, handlers),
      @lib.Instruction::resume_throw_ref(type_, handlers),
    ] {
    let shifted = inl_shift_outer_target_branches([instr], 1)
    let next = match shifted[0] {
      @lib.Resume(_, hs)
      | @lib.ResumeThrow(_, _, hs)
      | @lib.ResumeThrowRef(_, hs) => hs
      _ => fail("expected resume")
    }
    assert_true(next[0] is @lib.ResumeOnLabel(_, @lib.LabelIdx(1U)))
  }
}

///|
test "audit inlining preserves suffix after resumable calls" {
  let type_ = @lib.TypeIdx::new(0U)
  let tag = @lib.TagIdx::new(0U)
  for
    instr in [
      @lib.Instruction::resume_(type_, []),
      @lib.Instruction::resume_throw(type_, tag, []),
      @lib.Instruction::resume_throw_ref(type_, []),
    ] {
    assert_false(inl_instr_terminates_sequence(instr))
  }
}
