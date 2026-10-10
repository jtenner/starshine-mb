///|
fn encoding_selected_type_restore_fixture() -> @lib.Module {
  pass_test_module_from_wat(
    "(module (type (func (param i64))) (type (func)) (type (func (result i32))) (table 1 funcref) (func (type 1) block end) (func (type 1) i32.const 0 call_indirect (type 2) drop))",
  )
}

///|
fn encoding_selected_type_restore_assert_valid(
  original : @lib.Module,
  cleaned : @lib.Module,
) -> Unit raise {
  @validate.validate_module(cleaned).unwrap()
  let restored = inl_restore_untouched_funcs(original, cleaned, [true, false])
  @validate.validate_module(restored).unwrap()
  @debug.assert_eq(
    restored.code_sec.unwrap().0[1],
    original.code_sec.unwrap().0[1],
  )
  @debug.assert_eq(restored.type_sec, original.type_sec)
  let @lib.Func(_, @lib.Expr(selected_body)) = restored.code_sec.unwrap().0[0]
  assert_true(selected_body.is_empty())
}

///|
test "selected simplify-locals cleanup preserves untouched indirect call type on restore" {
  let original = encoding_selected_type_restore_fixture()
  let cleaned = simplify_locals_cleanup_module_encoding(
    original,
    touched=Some([true, false]),
  )
  encoding_selected_type_restore_assert_valid(original, cleaned)
}

///|
test "selected merge-blocks cleanup preserves untouched indirect call type on restore" {
  let original = encoding_selected_type_restore_fixture()
  let cleaned = pass_cleanup_control_and_type_encoding(
    original,
    touched=Some([true, false]),
  )
  encoding_selected_type_restore_assert_valid(original, cleaned)
}

///|
test "selected optimize-instructions cleanup preserves untouched indirect call type on restore" {
  let original = encoding_selected_type_restore_fixture()
  let cleaned = oi_cleanup_module_encoding(
    original,
    touched=Some([true, false]),
  )
  encoding_selected_type_restore_assert_valid(original, cleaned)
}

///|
test "all selected merge-blocks bodies still permit unused type cleanup" {
  let original = encoding_selected_type_restore_fixture()
  let cleaned = pass_cleanup_control_and_type_encoding(
    original,
    touched=Some([true, true]),
  )
  @validate.validate_module(cleaned).unwrap()
  let original_groups = original.type_sec.unwrap().0
  let cleaned_groups = cleaned.type_sec.unwrap().0
  assert_true(cleaned_groups.length() < original_groups.length())
  let restored = inl_restore_untouched_funcs(original, cleaned, [true, true])
  @validate.validate_module(restored).unwrap()
  let @lib.Func(_, @lib.Expr(selected_body)) = restored.code_sec.unwrap().0[0]
  assert_true(selected_body.is_empty())
}

///|
test "selected descriptor cleanup preserves old untouched type references" {
  let generated = oi_descriptor_raw_parity_fixture(2UL)
  let funcs = generated.code_sec.unwrap().0.copy()
  let described_ref = @lib.RefType::new(
    true,
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
    exact=true,
  )
  let @lib.Func(selected_locals, _) = funcs[0]
  funcs[0] = @lib.Func::new(
    selected_locals,
    @lib.Expr::new([@lib.Instruction::ref_null_type(described_ref)]),
  )
  let @lib.Func(untouched_locals, @lib.Expr(untouched_body)) = funcs[1]
  let old_type_ref = @lib.RefType::new(
    true,
    @lib.HeapType::new(@lib.TypeIdx::new(4U)),
  )
  funcs[1] = @lib.Func::new(
    untouched_locals,
    @lib.Expr::new(
      [@lib.Instruction::ref_null_type(old_type_ref), @lib.Instruction::drop()] +
      untouched_body,
    ),
  )
  let original = generated.with_code_sec(@lib.CodeSec::new(funcs))
  @validate.validate_module(original).unwrap()
  let cleaned = oi_cleanup_descriptor_encoding(
    original,
    touched=Some([true, false]),
  )
  @validate.validate_module(cleaned).unwrap()
  let restored = inl_restore_untouched_funcs(original, cleaned, [true, false])
  @validate.validate_module(restored).unwrap()
  @debug.assert_eq(
    restored.code_sec.unwrap().0[1],
    original.code_sec.unwrap().0[1],
  )
  @debug.assert_eq(restored.type_sec, original.type_sec)
  let @lib.Func(_, @lib.Expr(selected_body)) = restored.code_sec.unwrap().0[0]
  @debug.assert_eq(selected_body, [
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::none())),
  ])
}

///|
test "production selected optimize-instructions preserves untouched indirect call type" {
  let original = encoding_selected_type_restore_fixture()
  let descriptor = pass_registry_lookup_cached("optimize-instructions").unwrap().descriptor.unwrap()
  let cleaned = run_hot_pipeline_apply_hot_pass_to_touched(
    original,
    descriptor,
    [true, false],
    HotPipelineOptions::new(),
  ).unwrap()
  encoding_selected_type_restore_assert_valid(original, cleaned)
}
