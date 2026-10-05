///|
test "memory-packing suffix union matches pairwise partial trampling" {
  let offsets = [0, 2, 4, 40, 1, 42, 9, 3, 44, 6, 12, 0]
  let datas : Array[@lib.Data] = []
  for offset in offsets {
    datas.push(
      @lib.Data::new(
        @lib.DataMode::active(
          @lib.MemIdx::new(0U),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(offset))]),
        ),
        b"ABCDEFGHIJ",
      ),
    )
  }
  let expected = datas.copy()
  let actual = datas.copy()
  mp_zero_out_trampled_data_pairwise(expected)
  mp_zero_out_trampled_data(actual)
  @debug.assert_eq(actual, expected)
  @debug.assert_eq(
    datas[0],
    @lib.Data::new(
      @lib.DataMode::active(
        @lib.MemIdx::new(0U),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
      ),
      b"ABCDEFGHIJ",
    ),
  )
}

///|
test "memory-packing suffix union matches pairwise at memory64 limit" {
  let offsets = [-12L, -10L, -9L, -8L, -7L, -6L, -4L, -3L]
  let datas : Array[@lib.Data] = []
  for offset in offsets {
    datas.push(
      @lib.Data::new(
        @lib.DataMode::active(
          @lib.MemIdx::new(0U),
          @lib.Expr::new([@lib.Instruction::i64_const(@lib.I64(offset))]),
        ),
        b"ABC",
      ),
    )
  }
  let expected = datas.copy()
  let actual = datas.copy()
  mp_zero_out_trampled_data_pairwise(expected)
  mp_zero_out_trampled_data(actual)
  @debug.assert_eq(actual, expected)
}

///|
test "memory-packing span union stays balanced for descending disjoint spans" {
  let covered = MpSpanUnion::new()
  for index = 1023; index >= 0; index = index - 1 {
    let start = (index * 4).reinterpret_as_uint().to_uint64()
    mp_span_union_insert(covered, MpSpan::new(start, start + 2UL, false))
  }
  assert_true(mp_span_union_height(covered, covered.root) <= 16)
  let mut node = mp_span_union_lower_bound(covered, 0UL)
  let mut expected = 0
  while node >= 0 {
    @debug.assert_eq(
      covered.spans[node].start,
      (expected * 4).reinterpret_as_uint().to_uint64(),
    )
    expected += 1
    node = mp_span_union_successor(covered, covered.spans[node].start)
  }
  assert_eq(expected, 1024)
}
