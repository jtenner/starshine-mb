///|
test "Binaryen 132 descriptor branches preserve exact target result and label typing" {
  let source = RefType::new(true, HeapType::new(TypeIdx::new(0U)))
  let target = RefType::new(false, HeapType::new(TypeIdx::new(0U)), exact=true)
  let descriptor = RefType::new(
    true,
    HeapType::new(TypeIdx::new(1U)),
    exact=true,
  )
  let base = tcneg_descriptor_struct_env()
  for fail_branch in [false, true] {
    let label = if fail_branch { source } else { target }
    let env = base.with_labels([[ValType::ref_type(label)]])
    let state = tcneg_make_state(env, [
      ValType::ref_type(source),
      ValType::ref_type(descriptor),
    ])
    let instr = if fail_branch {
      Instruction::br_on_cast_desc_eq_fail(LabelIdx::new(0U), source, target)
    } else {
      Instruction::br_on_cast_desc_eq(LabelIdx::new(0U), source, target)
    }
    match Typecheck::typecheck(instr, state) {
      Ok(next) =>
        if fail_branch {
          assert_stack(next, [ValType::ref_type(target)])
        }
      Err(err) => fail("exact descriptor branch: \{err}")
    }
  }
}
