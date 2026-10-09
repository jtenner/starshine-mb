///|
fn stack_switching_test_tag_module(
  params : Array[ValType],
  results : Array[ValType],
  imported : Bool,
) -> Module {
  let module_ = Module::new().with_type_sec(
    TypeSec::new([
      RecType::new(SubType::comp_type(CompType::func(params, results))),
    ]),
  )
  let tag = TagType::new(TypeIdx::new(0U))
  if imported {
    module_.with_import_sec(
      ImportSec::new([
        Import::new(Name::new("env"), Name::new("tag"), ExternType::tag(tag)),
      ]),
    )
  } else {
    module_.with_tag_sec(TagSec::new([tag]))
  }
}

///|
test "stack switching policy controls defined and imported result-bearing tags" {
  let feature = match proposal_feature_by_name("stack-switching") {
    Some(feature) => feature
    None => fail("stack-switching feature missing")
  }
  for imported in [false, true] {
    let module_ = stack_switching_test_tag_module(
      [ValType::i32()],
      [ValType::i64()],
      imported,
    )
    @debug.assert_eq(module_proposal_features(module_), [feature])
    assert_true(validate_module(module_) is Ok(_))
    match validate_module(module_, disabled_features=[feature]) {
      Err(err) =>
        assert_true(validation_error_message(err).contains("stack-switching"))
      Ok(_) => fail("disabled stack switching accepted a result-bearing tag")
    }
  }
}

///|
test "disabling stack switching preserves ordinary exception tags" {
  let feature = match proposal_feature_by_name("stack-switching") {
    Some(feature) => feature
    None => fail("stack-switching feature missing")
  }
  for imported in [false, true] {
    let module_ = stack_switching_test_tag_module(
      [ValType::i32()],
      [],
      imported,
    )
    @debug.assert_eq(module_proposal_features(module_), [])
    assert_true(validate_module(module_, disabled_features=[feature]) is Ok(_))
  }
}

///|
test "stack switching policy detects continuation types without instructions" {
  let feature = match proposal_feature_by_name("stack-switching") {
    Some(feature) => feature
    None => fail("stack-switching feature missing")
  }
  let module_ = Module::new().with_type_sec(
    TypeSec::new([
      RecType::new(SubType::comp_type(CompType::func([], []))),
      RecType::new(SubType::comp_type(CompType::cont(TypeIdx::new(0U)))),
    ]),
  )
  @debug.assert_eq(module_proposal_features(module_), [feature])
  assert_true(validate_module(module_) is Ok(_))
  assert_true(validate_module(module_, disabled_features=[feature]) is Err(_))
  for heap in [AbsHeapType::cont(), AbsHeapType::no_cont()] {
    let reference = ValType::ref_type(RefType::new(true, HeapType::abs(heap)))
    let module_ = proposal_test_function([reference], [], [])
    @debug.assert_eq(module_proposal_features(module_), [feature])
    assert_true(validate_module(module_) is Ok(_))
    assert_true(validate_module(module_, disabled_features=[feature]) is Err(_))
  }
}

///|
test "stack switching discovery scans every continuation opcode in nested code" {
  let feature = match proposal_feature_by_name("stack-switching") {
    Some(feature) => feature
    None => fail("stack-switching feature missing")
  }
  let type_idx = TypeIdx::new(0U)
  let tag_idx = TagIdx::new(0U)
  // Feature discovery runs before structural validation, including unreachable
  // code. These intentionally index-incomplete modules isolate opcode discovery
  // rather than depending on a continuation declaration to detect the feature.
  for
    instruction in [
      Instruction::cont_new(type_idx),
      Instruction::cont_bind(type_idx, type_idx),
      Instruction::suspend(tag_idx),
      Instruction::resume_(type_idx, []),
      Instruction::resume_throw(type_idx, tag_idx, []),
      Instruction::resume_throw_ref(type_idx, []),
      Instruction::stack_switch(type_idx, tag_idx),
    ] {
    let module_ = proposal_test_function([], [], [
      Instruction::block(
        BlockType::void_(),
        Expr::new([Instruction::unreachable_(), instruction]),
      ),
    ])
    @debug.assert_eq(module_proposal_features(module_), [feature])
    match validate_module(module_, disabled_features=[feature]) {
      Err(err) =>
        assert_true(validation_error_message(err).contains("stack-switching"))
      Ok(_) => fail("disabled continuation instruction accepted")
    }
  }
}
