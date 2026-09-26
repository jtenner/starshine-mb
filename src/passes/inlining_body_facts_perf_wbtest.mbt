///|
fn inlining_body_facts_bench(it : @bench.T, count : Int) -> Unit {
  let body : Array[@lib.Instruction] = []
  for _ in 0..<count {
    body.push(
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::drop(),
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        ]),
      ),
    )
  }
  if inl_measure_body(body) != (true, false, false, false, count * 4) {
    abort("inlining measurement fixture lost its size or direct call")
  }
  it.bench(fn() { it.keep(inl_measure_body(body)) })
}

///|
test "bench inlining body facts blocks=128" (it : @bench.T) {
  inlining_body_facts_bench(it, 128)
}

///|
test "bench inlining body facts blocks=512" (it : @bench.T) {
  inlining_body_facts_bench(it, 512)
}
