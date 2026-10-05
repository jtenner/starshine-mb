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
      @lib.CompType::struct_([
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::const_(),
        ),
      ]),
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

///|
test "optimize-casts write index deduplicates repeated writes" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let first = @ir.hot_build_local_set(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  )
  let second = @ir.hot_build_local_set(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(2)),
  )
  let root = @ir.hot_build_block(func, @lib.BlockType::void_(), [first, second])
  let writes : Array[Int] = []
  let write_mask = Array::make(1, false)
  oc_collect_written_locals(func, root, writes, write_mask)
  @debug.assert_eq(writes, [0])
  assert_true(write_mask[0])
}

///|
test "optimize-casts fresh local lookup is indexed by cast node" {
  let fresh_by_cast = Array::make(16384, -1)
  fresh_by_cast[3] = 91
  fresh_by_cast[16000] = 117
  assert_eq(oc_find_fresh_local_for_cast(fresh_by_cast, 3), Some(91))
  assert_eq(oc_find_fresh_local_for_cast(fresh_by_cast, 16000), Some(117))
  assert_eq(oc_find_fresh_local_for_cast(fresh_by_cast, 8192), None)
}
