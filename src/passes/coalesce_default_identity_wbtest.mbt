///|
test "coalesce numeric defaults reuse exact interned identities across fresh values" {
  let actual = CLValueInterner::new()
  let reference = CLValueInterner::new()
  let formats = [0]
  let types = [
    @lib.ValType::i32(),
    @lib.ValType::i64(),
    @lib.ValType::f32(),
    @lib.ValType::f64(),
    @lib.ValType::v128(),
  ]
  for round in 0..<8 {
    assert_eq(actual.fresh(), reference.fresh())
    for ty in types {
      let expected = reference.intern("default:\{@debug.to_string(ty)}")
      assert_eq(
        cl_default_identity(actual, ty, formats=Some(formats)),
        expected,
      )
    }
    assert_eq(
      actual.intern("const:\{round}"),
      reference.intern("const:\{round}"),
    )
  }
  assert_eq(actual.ids.length(), reference.ids.length())
  assert_eq(actual.next_value, reference.next_value)
  assert_eq(actual.ids.length(), 13)
  assert_eq(formats[0], 5)
}

///|
test "coalesce default identity cache remains local to its interner" {
  let first = CLValueInterner::new()
  let second = CLValueInterner::new()
  ignore(first.intern("const:previous"))
  assert_eq(cl_default_identity(first, @lib.ValType::i32()), 1)
  assert_eq(cl_default_identity(second, @lib.ValType::i32()), 0)
  assert_eq(first.ids.length(), 2)
  assert_eq(second.ids.length(), 1)
  assert_eq(
    cl_default_identity(first, @lib.ValType::i32()),
    first.intern("default:\{@debug.to_string(@lib.ValType::i32())}"),
  )
  assert_eq(
    cl_default_identity(second, @lib.ValType::i32()),
    second.intern("default:\{@debug.to_string(@lib.ValType::i32())}"),
  )
}

///|
test "coalesce numeric cache preserves parameter and reference initialization identities" {
  let actual = CLValueInterner::new()
  let reference = CLValueInterner::new()
  let nonnullable = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let prefix = [
    @lib.ValType::i32(),
    nonnullable,
    @lib.ValType::funcref(),
    @lib.ValType::ref_null(@lib.HeapType::new(@lib.TypeIdx::new(0U))),
    nonnullable,
  ]
  for idx in 0..<prefix.length() {
    assert_eq(
      cl_initial_value(actual, idx, 2, prefix[idx]),
      cl_default_identity_reference_initial(reference, idx, 2, prefix[idx]),
    )
  }
  assert_true(actual.numeric_defaults is None)
  for
    ty in [
      @lib.ValType::i32(),
      @lib.ValType::f64(),
      @lib.ValType::funcref(),
      @lib.ValType::i32(),
    ] {
    assert_eq(
      cl_initial_value(actual, 5, 2, ty),
      cl_default_identity_reference_initial(reference, 5, 2, ty),
    )
  }
  assert_eq(actual.ids.length(), reference.ids.length())
  assert_eq(actual.next_value, reference.next_value)
}
