///|
// Flat controls isolate this output-array boundary. Both paths use the same
// instruction rewriter; no complete-old-recursive-scan claim is made.
fn type_remap_lazy_bench(
  it : @bench.T,
  width : Int,
  pattern : Int,
  before : Bool,
) -> Unit raise {
  let body : Array[@lib.Instruction] = []
  for index in 0..<width {
    body.push(
      if pattern == 2 || (pattern == 1 && index + 1 == width) {
        @lib.Instruction::call_ref(@lib.TypeIdx::new(1U))
      } else {
        @lib.Instruction::nop()
      },
    )
  }
  let remap : Map[UInt, UInt] = Map([])
  remap[1U] = 0U
  let expected = type_remap_eager_reference(body, remap)
  assert_eq(dfe_try_rewrite_instruction_array_type_idxs(body, remap), expected)
  it.bench(fn() {
    it.keep(
      if before {
        type_remap_eager_reference(body, remap)
      } else {
        dfe_try_rewrite_instruction_array_type_idxs(body, remap)
      },
    )
  })
}

///|
test "bench type remap width=4 unchanged before" (it : @bench.T) {
  type_remap_lazy_bench(it, 4, 0, true)
}

///|
test "bench type remap width=4 unchanged current" (it : @bench.T) {
  type_remap_lazy_bench(it, 4, 0, false)
}

///|
test "bench type remap width=4 last before" (it : @bench.T) {
  type_remap_lazy_bench(it, 4, 1, true)
}

///|
test "bench type remap width=4 last current" (it : @bench.T) {
  type_remap_lazy_bench(it, 4, 1, false)
}

///|
test "bench type remap width=4 dense before" (it : @bench.T) {
  type_remap_lazy_bench(it, 4, 2, true)
}

///|
test "bench type remap width=4 dense current" (it : @bench.T) {
  type_remap_lazy_bench(it, 4, 2, false)
}

///|
test "bench type remap width=128 unchanged before" (it : @bench.T) {
  type_remap_lazy_bench(it, 128, 0, true)
}

///|
test "bench type remap width=128 unchanged current" (it : @bench.T) {
  type_remap_lazy_bench(it, 128, 0, false)
}

///|
test "bench type remap width=128 last before" (it : @bench.T) {
  type_remap_lazy_bench(it, 128, 1, true)
}

///|
test "bench type remap width=128 last current" (it : @bench.T) {
  type_remap_lazy_bench(it, 128, 1, false)
}

///|
test "bench type remap width=128 dense before" (it : @bench.T) {
  type_remap_lazy_bench(it, 128, 2, true)
}

///|
test "bench type remap width=128 dense current" (it : @bench.T) {
  type_remap_lazy_bench(it, 128, 2, false)
}
