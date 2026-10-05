///|
fn descriptor_branch_validation_instruction(
  source : RefType,
  target : RefType,
  fail_branch : Bool,
) -> Instruction {
  if fail_branch {
    Instruction::br_on_cast_desc_eq_fail(LabelIdx::new(0U), source, target)
  } else {
    Instruction::br_on_cast_desc_eq(LabelIdx::new(0U), source, target)
  }
}

///|
fn descriptor_branch_validation_descriptor() -> ValType {
  ValType::ref_type(RefType::new(true, HeapType::new(TypeIdx::new(1U))))
}

///|
test "descriptor branches accept nullable targets from nonnullable sources" {
  let source = RefType::new(false, HeapType::abs(AbsHeapType::any()))
  let target = RefType::new(true, HeapType::new(TypeIdx::new(0U)))
  for fail_branch in [false, true] {
    let branch_type = if fail_branch { source } else { target }
    let fallthrough_type = if fail_branch { target } else { source }
    let env = tcneg_descriptor_struct_env().with_labels([
      [ValType::ref_type(branch_type)],
    ])
    let state = tcneg_make_state(env, [
      ValType::ref_type(source),
      descriptor_branch_validation_descriptor(),
    ])
    let next = match
      Typecheck::typecheck(
        descriptor_branch_validation_instruction(source, target, fail_branch),
        state,
      ) {
      Ok(next) => next
      Err(err) => fail(err)
    }
    assert_stack(next, [ValType::ref_type(fallthrough_type)])
  }
}

///|
test "descriptor branches accept unrelated heap types in the GC hierarchy" {
  let source = RefType::new(true, HeapType::abs(AbsHeapType::i31()))
  let source_diff = RefType::new(false, source.get_heap_type())
  let target = RefType::new(true, HeapType::new(TypeIdx::new(0U)))
  for fail_branch in [false, true] {
    let branch_type = if fail_branch { source_diff } else { target }
    let fallthrough_type = if fail_branch { target } else { source_diff }
    let env = tcneg_descriptor_struct_env().with_labels([
      [ValType::ref_type(branch_type)],
    ])
    let state = tcneg_make_state(env, [
      ValType::ref_type(source),
      descriptor_branch_validation_descriptor(),
    ])
    let next = match
      Typecheck::typecheck(
        descriptor_branch_validation_instruction(source, target, fail_branch),
        state,
      ) {
      Ok(next) => next
      Err(err) => fail(err)
    }
    assert_stack(next, [ValType::ref_type(fallthrough_type)])
  }
}

///|
test "descriptor branches preserve exact source types on the failed cast edge" {
  let source = RefType::new(true, HeapType::new(TypeIdx::new(1U)), exact=true)
  let source_diff = RefType::new(false, source.get_heap_type(), exact=true)
  let target = RefType::new(true, HeapType::new(TypeIdx::new(0U)))
  for fail_branch in [false, true] {
    let branch_type = if fail_branch { source_diff } else { target }
    let fallthrough_type = if fail_branch { target } else { source_diff }
    let env = tcneg_descriptor_struct_env().with_labels([
      [ValType::ref_type(branch_type)],
    ])
    let state = tcneg_make_state(env, [
      ValType::ref_type(source),
      descriptor_branch_validation_descriptor(),
    ])
    let next = match
      Typecheck::typecheck(
        descriptor_branch_validation_instruction(source, target, fail_branch),
        state,
      ) {
      Ok(next) => next
      Err(err) => fail(err)
    }
    assert_stack(next, [ValType::ref_type(fallthrough_type)])
  }
}

///|
test "descriptor branches retype sent prefix values to label annotations" {
  let source = RefType::new(true, HeapType::abs(AbsHeapType::any()))
  let target = RefType::new(false, HeapType::new(TypeIdx::new(0U)))
  let prefix_type = ValType::ref_type(source)
  let actual_prefix = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::eq())),
  )
  for fail_branch in [false, true] {
    let branch_type = if fail_branch { source } else { target }
    let fallthrough_type = if fail_branch { target } else { source }
    let env = tcneg_descriptor_struct_env().with_labels([
      [prefix_type, ValType::ref_type(branch_type)],
    ])
    let state = tcneg_make_state(env, [
      ValType::i64(),
      actual_prefix,
      ValType::ref_type(source),
      descriptor_branch_validation_descriptor(),
    ])
    let next = match
      Typecheck::typecheck(
        descriptor_branch_validation_instruction(source, target, fail_branch),
        state,
      ) {
      Ok(next) => next
      Err(err) => fail(err)
    }
    assert_stack(next, [
      ValType::i64(),
      prefix_type,
      ValType::ref_type(fallthrough_type),
    ])
  }
}

///|
test "descriptor branches materialize sent prefix types after unreachable" {
  let source = RefType::new(true, HeapType::abs(AbsHeapType::any()))
  let target = RefType::new(false, HeapType::new(TypeIdx::new(0U)))
  let prefix_type = ValType::ref_type(source)
  for fail_branch in [false, true] {
    let branch_type = if fail_branch { source } else { target }
    let fallthrough_type = if fail_branch { target } else { source }
    let env = tcneg_descriptor_struct_env().with_labels([
      [prefix_type, ValType::ref_type(branch_type)],
    ])
    let state = tcneg_make_state(env, []).set_unreachable()
    let next = match
      Typecheck::typecheck(
        descriptor_branch_validation_instruction(source, target, fail_branch),
        state,
      ) {
      Ok(next) => next
      Err(err) => fail(err)
    }
    assert_stack(next, [prefix_type, ValType::ref_type(fallthrough_type)])
  }
}

///|
test "descriptor branches reject function references outside the GC hierarchy" {
  // A function reference cannot participate in a descriptor-bearing struct cast.
  let source = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let target = RefType::new(false, HeapType::new(TypeIdx::new(0U)))
  for fail_branch in [false, true] {
    let branch_type = if fail_branch { source } else { target }
    let env = tcneg_descriptor_struct_env().with_labels([
      [ValType::ref_type(branch_type)],
    ])
    let state = tcneg_make_state(env, [
      ValType::ref_type(source),
      descriptor_branch_validation_descriptor(),
    ])
    assert_true(
      Typecheck::typecheck(
        descriptor_branch_validation_instruction(source, target, fail_branch),
        state,
      ).is_err(),
    )
  }
}

///|
test "descriptor branches reject labels that cannot receive the cast edge" {
  // Success can carry null; failure carries anyref rather than the struct type.
  let source = RefType::new(true, HeapType::abs(AbsHeapType::any()))
  let target = RefType::new(true, HeapType::new(TypeIdx::new(0U)))
  let invalid_label = RefType::new(false, target.get_heap_type())
  for fail_branch in [false, true] {
    let env = tcneg_descriptor_struct_env().with_labels([
      [ValType::ref_type(invalid_label)],
    ])
    let state = tcneg_make_state(env, [
      ValType::ref_type(source),
      descriptor_branch_validation_descriptor(),
    ])
    assert_true(
      Typecheck::typecheck(
        descriptor_branch_validation_instruction(source, target, fail_branch),
        state,
      ).is_err(),
    )
  }
}
