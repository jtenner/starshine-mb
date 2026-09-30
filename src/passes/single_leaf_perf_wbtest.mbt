///|
fn sl_leaf_bench(
  it : @bench.T,
  locals_count : Int,
  shape : Int,
  reference : Bool,
) -> Unit raise {
  let env = @validate.Env::new().with_locals(
    @lib.Locals::from_types(Array::make(locals_count, @lib.ValType::i32())),
  )
  let body = match shape {
    0 => [@lib.Instruction::i32_const(@lib.I32(7))]
    1 =>
      [
        @lib.Instruction::local_get(
          @lib.LocalIdx::new((locals_count - 1).reinterpret_as_uint()),
        ),
      ]
    2 =>
      [
        @lib.Instruction::i32_const(@lib.I32(3)),
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::i32_add(),
      ]
    // Intentionally invalid local: the general failure path must remain intact.
    3 =>
      [
        @lib.Instruction::local_get(
          @lib.LocalIdx::new(locals_count.reinterpret_as_uint()),
        ),
      ]
    4 =>
      [
        @lib.Instruction::ref_null(
          @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
        ),
      ]
    _ => []
  }
  let actual = sl_value_suffix_at(body, body.length(), 1, env)
  assert_eq(
    sl_leaf_bytes(actual),
    sl_leaf_bytes(sl_leaf_reference_suffix_at(body, body.length(), 1, env)),
  )
  assert_eq(actual.is_empty(), shape == 3 || shape == 5)
  if !actual.is_empty() {
    ignore(
      @validate.Typecheck::typecheck(
        @lib.Expr::new(actual),
        @validate.make_state(env, []),
      ).unwrap(),
    )
  }
  let saved = sl_leaf_bytes(body)
  it.bench(fn() {
    it.keep(
      if reference {
        sl_leaf_reference_suffix_at(body, body.length(), 1, env)
      } else {
        sl_value_suffix_at(body, body.length(), 1, env)
      },
    )
  })
  assert_eq(sl_leaf_bytes(body), saved)
}

///|
test "bench single leaf 8 constant original" (it : @bench.T) {
  sl_leaf_bench(it, 8, 0, true)
}

///|
test "bench single leaf 8 constant ranged" (it : @bench.T) {
  sl_leaf_bench(it, 8, 0, false)
}

///|
test "bench single leaf 8 local original" (it : @bench.T) {
  sl_leaf_bench(it, 8, 1, true)
}

///|
test "bench single leaf 8 local ranged" (it : @bench.T) {
  sl_leaf_bench(it, 8, 1, false)
}

///|
test "bench single leaf 8 compound original" (it : @bench.T) {
  sl_leaf_bench(it, 8, 2, true)
}

///|
test "bench single leaf 8 compound ranged" (it : @bench.T) {
  sl_leaf_bench(it, 8, 2, false)
}

///|
test "bench single leaf 8 invalid local original" (it : @bench.T) {
  sl_leaf_bench(it, 8, 3, true)
}

///|
test "bench single leaf 8 invalid local ranged" (it : @bench.T) {
  sl_leaf_bench(it, 8, 3, false)
}

///|
test "bench single leaf 8 reference fallback original" (it : @bench.T) {
  sl_leaf_bench(it, 8, 4, true)
}

///|
test "bench single leaf 8 reference fallback ranged" (it : @bench.T) {
  sl_leaf_bench(it, 8, 4, false)
}

///|
test "bench single leaf 8 empty original" (it : @bench.T) {
  sl_leaf_bench(it, 8, 5, true)
}

///|
test "bench single leaf 8 empty ranged" (it : @bench.T) {
  sl_leaf_bench(it, 8, 5, false)
}

///|
test "bench single leaf 4096 constant original" (it : @bench.T) {
  sl_leaf_bench(it, 4096, 0, true)
}

///|
test "bench single leaf 4096 constant ranged" (it : @bench.T) {
  sl_leaf_bench(it, 4096, 0, false)
}

///|
test "bench single leaf 4096 local original" (it : @bench.T) {
  sl_leaf_bench(it, 4096, 1, true)
}

///|
test "bench single leaf 4096 local ranged" (it : @bench.T) {
  sl_leaf_bench(it, 4096, 1, false)
}

///|
test "bench single leaf 4096 compound original" (it : @bench.T) {
  sl_leaf_bench(it, 4096, 2, true)
}

///|
test "bench single leaf 4096 compound ranged" (it : @bench.T) {
  sl_leaf_bench(it, 4096, 2, false)
}

///|
test "bench single leaf 4096 invalid local original" (it : @bench.T) {
  sl_leaf_bench(it, 4096, 3, true)
}

///|
test "bench single leaf 4096 invalid local ranged" (it : @bench.T) {
  sl_leaf_bench(it, 4096, 3, false)
}

///|
test "bench single leaf 4096 reference fallback original" (it : @bench.T) {
  sl_leaf_bench(it, 4096, 4, true)
}

///|
test "bench single leaf 4096 reference fallback ranged" (it : @bench.T) {
  sl_leaf_bench(it, 4096, 4, false)
}

///|
test "bench single leaf 4096 empty original" (it : @bench.T) {
  sl_leaf_bench(it, 4096, 5, true)
}

///|
test "bench single leaf 4096 empty ranged" (it : @bench.T) {
  sl_leaf_bench(it, 4096, 5, false)
}
