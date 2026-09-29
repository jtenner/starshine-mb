///|
test "inlining mixed scratch pools scan each requested type monotonically" {
  let types = Array::makei(128, fn(index) {
    if index % 2 == 0 {
      @lib.ValType::i64()
    } else {
      @lib.ValType::i32()
    }
  })
  let used = Array::make(128, false)
  let locals = @lib.Locals::from_types(types)
  let first = [0]
  let cursors : Array[InlScratchTypeCursor] = []
  let visits = [0]
  for index = 0; index < 64; index = index + 1 {
    let slot = inl_allocate_reusable_scratch_local(
      @lib.ValType::i32(),
      types,
      used,
      locals,
      7,
      first_unused=Some(first),
      slot_visits=Some(visits),
      type_cursors=Some(cursors),
    )
    assert_eq(slot, 7 + index * 2 + 1)
  }
  assert_eq(locals.length(), 128)
  assert_true(visits[0] <= 128)
  for index = 0; index < 128; index = index + 1 {
    assert_eq(used[index], index % 2 == 1)
  }
}

///|
test "inlining typed scratch cursors preserve remaining types append slots and fresh callsites" {
  for _ in 0..<2 {
    let types = Array::makei(128, fn(index) {
      if index % 2 == 0 {
        @lib.ValType::i64()
      } else {
        @lib.ValType::i32()
      }
    })
    let used = Array::make(128, false)
    let locals = @lib.Locals::from_types(types)
    let first = [0]
    let cursors : Array[InlScratchTypeCursor] = []
    for index = 0; index < 64; index = index + 1 {
      assert_eq(
        inl_allocate_reusable_scratch_local(
          @lib.ValType::i32(),
          types,
          used,
          locals,
          7,
          first_unused=Some(first),
          type_cursors=Some(cursors),
        ),
        8 + index * 2,
      )
    }
    for index = 0; index < 64; index = index + 1 {
      assert_eq(
        inl_allocate_reusable_scratch_local(
          @lib.ValType::i64(),
          types,
          used,
          locals,
          7,
          first_unused=Some(first),
          type_cursors=Some(cursors),
        ),
        7 + index * 2,
      )
    }
    assert_eq(
      inl_allocate_reusable_scratch_local(
        @lib.ValType::f32(),
        types,
        used,
        locals,
        7,
        first_unused=Some(first),
        type_cursors=Some(cursors),
      ),
      135,
    )
    assert_eq(locals.length(), 129)
    assert_true(used.all(fn(value) { value }))
  }
}
