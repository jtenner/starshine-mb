///|
test "encode nested control without recursive instruction frames" {
  let mut instruction = @lib.Instruction::nop()
  let expected : Array[Byte] = []
  for _ in 0..<128 {
    instruction = @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [instruction],
      Some([]),
    )
    expected.push(0x04)
    expected.push(0x40)
  }
  expected.push(0x01)
  for _ in 0..<128 {
    expected.push(0x05)
    expected.push(0x0B)
  }
  let buf = @buffer.new()
  assert_eq(Encode::encode(instruction, buf), Ok(()))
  assert_eq(buf.to_bytes(), Bytes::from_array(expected))
  let expression_buf = @buffer.new()
  assert_eq(
    Encode::encode(@lib.Expr::new([instruction]), expression_buf),
    Ok(()),
  )
  expected.push(0x0B)
  assert_eq(expression_buf.to_bytes(), Bytes::from_array(expected))
}
