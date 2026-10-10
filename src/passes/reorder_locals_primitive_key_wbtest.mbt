///|
test "reorder-locals primitive type keys preserve sugar and reference flags" {
  let sugar = @lib.ValType::ref_type(
    @lib.RefType::abs(@lib.AbsHeapType::func()),
  )
  let explicit = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func())),
  )
  assert_true(rl_grouping_type_key(sugar).is_some())
  @debug.assert_eq(rl_grouping_type_key(sugar), rl_grouping_type_key(explicit))
  let seen : Map[UInt64, Bool] = {}
  for
    heap in [
      @lib.HeapType::abs(@lib.AbsHeapType::func()),
      @lib.HeapType::shared_abs(@lib.AbsHeapType::func()),
      @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      @lib.HeapType::new(@lib.TypeIdx::rec(0U)),
      @lib.HeapType::new(@lib.TypeIdx::new(0xffffffffU)),
      @lib.HeapType::new(@lib.TypeIdx::rec(0xffffffffU)),
    ] {
    for nullable in [false, true] {
      for exact in [false, true] {
        let ty = @lib.ValType::ref_type(
          @lib.RefType::new(nullable, heap, exact~),
        )
        let key = rl_grouping_type_key(ty).unwrap()
        assert_false(seen.contains(key))
        seen[key] = true
      }
    }
  }
  for
    ty in [
      @lib.ValType::i32(),
      @lib.ValType::i64(),
      @lib.ValType::f32(),
      @lib.ValType::f64(),
      @lib.ValType::v128(),
    ] {
    let key = rl_grouping_type_key(ty).unwrap()
    assert_false(seen.contains(key))
    seen[key] = true
  }
}

///|
test "reorder-locals primitive type keys cover every abstract heap proposal" {
  let seen : Map[UInt64, Bool] = {}
  for
    abs in [
      @lib.AbsHeapType::exn(),
      @lib.AbsHeapType::string_(),
      @lib.AbsHeapType::array(),
      @lib.AbsHeapType::struct_(),
      @lib.AbsHeapType::i31(),
      @lib.AbsHeapType::eq(),
      @lib.AbsHeapType::any(),
      @lib.AbsHeapType::extern_(),
      @lib.AbsHeapType::func(),
      @lib.AbsHeapType::cont(),
      @lib.AbsHeapType::none(),
      @lib.AbsHeapType::no_extern(),
      @lib.AbsHeapType::no_func(),
      @lib.AbsHeapType::no_exn(),
      @lib.AbsHeapType::no_cont(),
      @lib.AbsHeapType::waitqueue(),
      @lib.AbsHeapType::no_waitqueue(),
    ] {
    let key = rl_grouping_type_key(
      @lib.ValType::ref_type(@lib.RefType::abs(abs)),
    ).unwrap()
    assert_false(seen.contains(key))
    seen[key] = true
  }
  @debug.assert_eq(seen.length(), 17)
}
