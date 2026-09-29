///|
fn inl_typed_scratch_bench(
  it : @bench.T,
  width : Int,
  mixed : Bool,
  indexed : Bool,
) -> Unit {
  let types = Array::makei(width, fn(index) {
    if mixed && index % 2 == 0 {
      @lib.ValType::i64()
    } else {
      @lib.ValType::i32()
    }
  })
  let used = Array::make(width, false)
  let locals = @lib.Locals::empty()
  let count = if mixed { width / 2 } else { width }
  it.bench(fn() {
    used.fill(false)
    let first = [0]
    let cursors : Array[InlScratchTypeCursor] = []
    for index = 0; index < count; index = index + 1 {
      let slot = inl_allocate_reusable_scratch_local(
        @lib.ValType::i32(),
        types,
        used,
        locals,
        0,
        first_unused=Some(first),
        type_cursors=if indexed { Some(cursors) } else { None },
      )
      if slot != (if mixed { index * 2 + 1 } else { index }) {
        abort("typed scratch cursor changed allocation order")
      }
    }
    it.keep(used)
  })
}

///|
test "bench inline scratch width=8 uniform reference" (it : @bench.T) {
  inl_typed_scratch_bench(it, 8, false, false)
}

///|
test "bench inline scratch width=8 uniform typed" (it : @bench.T) {
  inl_typed_scratch_bench(it, 8, false, true)
}

///|
test "bench inline scratch width=8 mixed reference" (it : @bench.T) {
  inl_typed_scratch_bench(it, 8, true, false)
}

///|
test "bench inline scratch width=8 mixed typed" (it : @bench.T) {
  inl_typed_scratch_bench(it, 8, true, true)
}

///|
test "bench inline scratch width=128 uniform reference" (it : @bench.T) {
  inl_typed_scratch_bench(it, 128, false, false)
}

///|
test "bench inline scratch width=128 uniform typed" (it : @bench.T) {
  inl_typed_scratch_bench(it, 128, false, true)
}

///|
test "bench inline scratch width=128 mixed reference" (it : @bench.T) {
  inl_typed_scratch_bench(it, 128, true, false)
}

///|
test "bench inline scratch width=128 mixed typed" (it : @bench.T) {
  inl_typed_scratch_bench(it, 128, true, true)
}

///|
test "bench inline scratch width=1024 uniform reference" (it : @bench.T) {
  inl_typed_scratch_bench(it, 1024, false, false)
}

///|
test "bench inline scratch width=1024 uniform typed" (it : @bench.T) {
  inl_typed_scratch_bench(it, 1024, false, true)
}

///|
test "bench inline scratch width=1024 mixed reference" (it : @bench.T) {
  inl_typed_scratch_bench(it, 1024, true, false)
}

///|
test "bench inline scratch width=1024 mixed typed" (it : @bench.T) {
  inl_typed_scratch_bench(it, 1024, true, true)
}
