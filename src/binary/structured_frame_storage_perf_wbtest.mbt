///|
fn structured_frame_storage_bench(
  it : @bench.T,
  width : Int,
  depth : Int,
  legacy : Bool,
) -> Unit {
  let bt = BlockType::void_()
  let body = Array::make(width, Instruction::nop())
  let mut instr = if legacy {
    Instruction::try_(bt, Expr::new(body), [
      @lib.LegacyCatch::all(Expr::new(body)),
    ])
  } else {
    Instruction::block(bt, Expr::new(body))
  }
  for _ in 0..<depth {
    instr = Instruction::block(bt, Expr::new([instr]))
  }
  let buf = @buffer.new()
  Encode::encode(instr, buf).unwrap()
  let bytes = buf.to_bytes()
  it.bench(fn() {
    it.keep(
      (Decode::decode(bytes, 0) : Result[(Instruction, Int), BinaryDecodeError]),
    )
  })
}

///|
test "bench structured frame width=1" (it : @bench.T) {
  structured_frame_storage_bench(it, 1, 0, false)
}

///|
test "bench structured frame width=1024" (it : @bench.T) {
  structured_frame_storage_bench(it, 1024, 0, false)
}

///|
test "bench structured frame depth=128" (it : @bench.T) {
  structured_frame_storage_bench(it, 1, 128, false)
}

///|
test "bench structured frame legacy width=32" (it : @bench.T) {
  structured_frame_storage_bench(it, 32, 0, true)
}
