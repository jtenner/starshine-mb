///|
fn inlining_initialization_bench(
  it : @bench.T,
  count : Int,
  reference : Bool,
) -> Unit {
  let body : Array[@lib.Instruction] = []
  for index in 0..<count {
    body.push(@lib.Instruction::i32_const(index))
    body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(index.to_uint())))
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(index.to_uint())))
    body.push(@lib.Instruction::drop())
  }
  if inl_locals_read_before_write(body, 0, count) != Array::make(count, false) {
    abort("inlining initialization benchmark lost definite writes")
  }
  it.bench(fn() {
    if reference {
      it.keep(
        Array::makei(count, fn(index) {
          inl_local_may_read_before_write(body, index)
        }),
      )
    } else {
      it.keep(inl_locals_read_before_write(body, 0, count))
    }
  })
}

///|
test "bench inlining initialization locals=64 reference" (it : @bench.T) {
  inlining_initialization_bench(it, 64, true)
}

///|
test "bench inlining initialization locals=64 shared" (it : @bench.T) {
  inlining_initialization_bench(it, 64, false)
}

///|
test "bench inlining initialization locals=256 reference" (it : @bench.T) {
  inlining_initialization_bench(it, 256, true)
}

///|
test "bench inlining initialization locals=256 shared" (it : @bench.T) {
  inlining_initialization_bench(it, 256, false)
}
