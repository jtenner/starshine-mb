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
