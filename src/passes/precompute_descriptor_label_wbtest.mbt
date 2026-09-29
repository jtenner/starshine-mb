///|
test "precompute detects descriptor branches to the current result label" {
  let ref_ = @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U)))
  for
    branch in [
      @lib.Instruction::br_on_cast_desc_eq(@lib.LabelIdx::new(0U), ref_, ref_),
      @lib.Instruction::br_on_cast_desc_eq_fail(
        @lib.LabelIdx::new(0U),
        ref_,
        ref_,
      ),
    ] {
    assert_true(
      precompute_raw_instrs_have_branch_to_current_label([branch]),
      msg=branch.to_string(),
    )
  }
}
