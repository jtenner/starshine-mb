///|
fn oc_wbtest_module_ctx() -> @ir.HotModuleContext {
  let base = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::struct_([])),
  )
  let child = @lib.RecType::new(
    @lib.SubType::new(
      false,
      [@lib.TypeIdx::new(0U)],
      @lib.CompType::struct_([]),
    ),
  )
  let sibling = @lib.RecType::new(
    @lib.SubType::new(
      false,
      [@lib.TypeIdx::new(0U)],
      @lib.CompType::struct_([]),
    ),
  )
  @ir.hot_module_context_from_module(
    @lib.Module::new().with_type_sec(@lib.TypeSec::new([base, child, sibling])),
  )
}

///|
test "optimize-casts recognizes exact refs that cannot match sibling heap targets" {
  let ctx = oc_wbtest_module_ctx()
  let exact_child = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
    exact=true,
  )
  let sibling = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(2U)),
  )
  assert_true(oc_ref_never_matches(ctx, exact_child, sibling))
}

///|
test "optimize-casts recognizes abstract struct and array refs as disjoint" {
  let ctx = oc_wbtest_module_ctx()
  let struct_ref = @lib.RefType::new(
    false,
    @lib.HeapType::abs(@lib.AbsHeapType::struct_()),
  )
  let array_ref = @lib.RefType::new(
    false,
    @lib.HeapType::abs(@lib.AbsHeapType::array()),
  )
  assert_true(oc_ref_never_matches(ctx, struct_ref, array_ref))
}

///|
test "optimize-casts recognizes nullable refs as never matching non-null disjoint targets" {
  let ctx = oc_wbtest_module_ctx()
  let nullable_struct = @lib.RefType::new(
    true,
    @lib.HeapType::abs(@lib.AbsHeapType::struct_()),
  )
  let array_ref = @lib.RefType::new(
    false,
    @lib.HeapType::abs(@lib.AbsHeapType::array()),
  )
  assert_true(oc_ref_never_matches(ctx, nullable_struct, array_ref))
}

///|
test "optimize-casts keeps inexact sibling refs conservative" {
  let ctx = oc_wbtest_module_ctx()
  let child = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let sibling = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(2U)),
  )
  assert_false(oc_ref_never_matches(ctx, child, sibling))
}
