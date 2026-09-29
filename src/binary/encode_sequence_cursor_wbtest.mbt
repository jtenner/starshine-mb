///|
test "flat encoder cursor keeps exact bytes with constant work-item allocation" {
  let body = Array::make(64, @lib.Instruction::nop())
  let buffer = @buffer.new()
  let tasks = [0]
  encode_control_work(
    [ControlByte(0x0B), ControlSequence(body, 0)],
    buffer,
    work_items=Some(tasks),
  ).unwrap()
  let reference = @buffer.new()
  Encode::encode(@lib.Expr::new(body), reference).unwrap()
  assert_eq(buffer.to_bytes(), reference.to_bytes())
  assert_eq(buffer.length(), 65)
  assert_eq(tasks[0], 2)
  assert_eq(body, Array::make(64, @lib.Instruction::nop()))
}

///|
test "encoder sequence cursor preserves nested order and first encoding error" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::nop()],
      Some([@lib.Instruction::unreachable_()]),
    ),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::nop()]),
    ),
  ]
  let buffer = @buffer.new()
  encode_control_work([ControlByte(0x0B), ControlSequence(body, 0)], buffer).unwrap()
  assert_eq(
    buffer.to_bytes(),
    b"\x41\x01\x04\x40\x01\x05\x00\x0B\x02\x40\x01\x0B\x0B",
  )
  let bad = [
    @lib.Instruction::ref_null(@lib.HeapType::new(@lib.TypeIdx::rec(0U))),
  ]
  assert_eq(
    encode_control_work([ControlSequence(bad, 0)], @buffer.new()),
    Err(BinaryEncodeError::CannotEncodeRecursiveIndexHeapType),
  )
}
