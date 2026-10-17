///|
test "local-subtyping preserves exactness when normalizing ref.null" {
  let exact = @lib.RefType::new(
    true,
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
    exact=true,
  )
  match ls_ref_null_normalized_type(exact) {
    @lib.RefTypeValType(normalized) => {
      assert_true(normalized.is_nullable())
      assert_true(normalized.is_exact())
      @debug.assert_eq(normalized.get_heap_type(), exact.get_heap_type())
    }
    other => fail("expected normalized reference type, got \{other}")
  }
}
