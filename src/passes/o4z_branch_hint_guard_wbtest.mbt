///|
fn o4z_branch_hint_guard_fixture() -> @lib.Module {
  pass_test_module_from_wat(
    "(module (func (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 select (result i32)))",
  ).with_func_annotation_sec(
    @lib.FuncAnnotationSec::new([
      @lib.FuncAnnotationAssoc::new(0U, [
        @lib.FuncAnnotation::new("metadata.code.branch_hint", args=["\"\\01\""]),
        @lib.FuncAnnotation::new("keep.annotation"),
      ]),
    ]),
  )
}

///|
test "O4z strips discardable branch hints while guarding remaining debug offsets" {
  let hint = @lib.CustomSec::new(
    @lib.Name::from_string("metadata.code.branch_hint"),
    b"opaque-branch-hints",
  )
  let keep = @lib.CustomSec::new(@lib.Name::from_string("keep.me"), b"payload")
  for section_name in [".debug_info", "metadata.code.future", "reloc.CODE"] {
    let guarded_section = @lib.CustomSec::new(
      @lib.Name::from_string(section_name),
      b"opaque-code-offsets",
    )
    let input = o4z_branch_hint_guard_fixture().with_custom_secs([
      hint, guarded_section, keep,
    ])
    let expected = input
      .with_custom_secs([guarded_section, keep])
      .with_func_annotation_sec(
        @lib.FuncAnnotationSec::new([
          @lib.FuncAnnotationAssoc::new(0U, [
            @lib.FuncAnnotation::new("keep.annotation"),
          ]),
        ]),
      )
    // The known hint section is deliberately discarded. Remaining opaque
    // offsets still forbid changing the typed-select body or module indices.
    @debug.assert_eq(o4z_canonicalize_final_size_candidate(input), expected)
    let (optimized, changed) = o4z_canonicalize_final_size_candidate_with_changed(
      input,
    )
    @debug.assert_eq(optimized, expected)
    assert_true(changed)
  }
}

///|
test "O4z resumes size canonicalization after discarding the only offset metadata" {
  let input = o4z_branch_hint_guard_fixture().with_custom_secs([
    @lib.CustomSec::new(
      @lib.Name::from_string("metadata.code.branch_hint"),
      b"opaque-branch-hints",
    ),
  ])
  let (optimized, changed) = o4z_canonicalize_final_size_candidate_with_changed(
    input,
  )
  assert_true(changed)
  @debug.assert_eq(optimized.custom_secs, [])
  @debug.assert_eq(
    optimized.func_annotation_sec,
    Some(
      @lib.FuncAnnotationSec::new([
        @lib.FuncAnnotationAssoc::new(0U, [
          @lib.FuncAnnotation::new("keep.annotation"),
        ]),
      ]),
    ),
  )
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      assert_true(instrs.last() is Some(@lib.Select(None)))
    other => fail("expected one canonicalized function, got \{other}")
  }
}
