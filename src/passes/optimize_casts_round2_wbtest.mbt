///|
test "round2 optimize casts exact shared struct matches shared abstract supertypes" {
  let input = pass_test_module_from_wat("(module (type $S (shared (struct))))")
  let ctx = @ir.hot_module_context_from_module(input)
  let source = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
    exact=true,
  )
  for
    target in [
      @lib.AbsHeapType::struct_(),
      @lib.AbsHeapType::eq(),
      @lib.AbsHeapType::any(),
    ] {
    assert_false(
      oc_ref_never_matches(
        ctx,
        source,
        @lib.RefType::new(false, @lib.HeapType::shared_abs(target)),
      ),
    )
  }
}

///|
test "round2 optimize casts continuation supertype can contain subtype" {
  let input = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::cont(@lib.TypeIdx::new(0U))),
      ),
      @lib.RecType::new(
        @lib.SubType::new(
          false,
          [@lib.TypeIdx::new(1U)],
          @lib.CompType::cont(@lib.TypeIdx::new(0U)),
        ),
      ),
    ]),
  )
  assert_true(@validate.validate_module(input).is_ok())
  let ctx = @ir.hot_module_context_from_module(input)
  assert_false(
    oc_ref_never_matches(
      ctx,
      @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
      @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(2U))),
    ),
  )
}
