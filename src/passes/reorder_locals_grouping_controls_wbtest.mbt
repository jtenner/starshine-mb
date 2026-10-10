///|
fn rl_grouping_control_func(
  types : Array[@lib.ValType],
  counts : Array[Int],
) -> @lib.Func {
  let body : Array[@lib.Instruction] = []
  for round = 0; round < 3; round = round + 1 {
    for index = 0; index < types.length(); index = index + 1 {
      if round < counts[index] {
        body.push(
          @lib.Instruction::local_get(
            @lib.LocalIdx::new(index.reinterpret_as_uint()),
          ),
        )
        body.push(@lib.Instruction::drop())
      }
    }
  }
  @lib.Func::new(@lib.Locals::from_types(types), @lib.Expr::new(body))
}

///|
test "reorder-locals rejects changed equal-size and larger grouping candidates" {
  let a = @lib.ValType::i32()
  let b = @lib.ValType::i64()
  let c = @lib.ValType::f32()
  for
    (types, counts, proposed) in [
      ([a, b, c, c, b, c], [3, 3, 3, 2, 2, 2], [0, 1, 2, 4, 3, 5]),
      ([a, b, b, a], [3, 3, 2, 2], [0, 1, 3, 2]),
    ] {
    let original = rl_grouping_control_func(types, counts)
    let result = rl_rewrite_func(original, [])
    assert_false(result.changed)
    @debug.assert_eq(result.func, original)
    @debug.assert_eq(result.old_to_new, [])
    let current_bytes = @buffer.new()
    let candidate_bytes = @buffer.new()
    @binary.Encode::encode(@lib.Locals::from_types(types), current_bytes).unwrap()
    @binary.Encode::encode(
      @lib.Locals::from_types(proposed.map(fn(i) { types[i] })),
      candidate_bytes,
    ).unwrap()
    assert_true(candidate_bytes.length() >= current_bytes.length())
  }
}

///|
test "reorder-locals grouping deliberately retains baseline order for inline DefType keys" {
  // Inline graph keys are not representable by this binary declaration encoder.
  // The bounded tie-search does not hash them or widen the existing owner.
  let graph = @lib.DefType::new(
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    0U,
  )
  let reference = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::def_type(graph)),
  )
  let original = rl_grouping_control_func(
    [reference, @lib.ValType::i32(), reference, @lib.ValType::i32()],
    [1, 1, 1, 1],
  )
  let result = rl_rewrite_func(original, [])
  assert_false(result.changed)
  @debug.assert_eq(result.func, original)
}

///|
test "reorder-locals grouping measures merged local run counts beyond ULEB127" {
  let types : Array[@lib.ValType] = []
  for index = 0; index < 258; index = index + 1 {
    types.push(
      if index % 2 == 0 {
        @lib.ValType::i32()
      } else {
        @lib.ValType::i64()
      },
    )
  }
  let original = rl_grouping_control_func(types, Array::make(types.length(), 1))
  let result = rl_rewrite_func(original, [])
  let @lib.Func(locals, _) = result.func
  @debug.assert_eq(locals.runs().length(), 2)
  @debug.assert_eq(locals.runs()[0].count(), 129U)
  @debug.assert_eq(locals.runs()[1].count(), 129U)
  let bytes = @buffer.new()
  @binary.Encode::encode(locals, bytes).unwrap()
  @debug.assert_eq(bytes.length(), 7)
}
