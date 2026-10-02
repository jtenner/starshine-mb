///|
test "leaf error-only encoder preserves scalar SIMD and GC bytes" {
  let cases : Array[(Instruction, Bytes)] = [
    (Instruction::nop(), b"\x01"),
    (Instruction::i32_const(@lib.I32(-1)), b"\x41\x7f"),
    (Instruction::i32_add(), b"\x6a"),
    (
      Instruction::ref_null(HeapType::abs(@lib.AbsHeapType::extern_())),
      b"\xd0\x6f",
    ),
    (Instruction::struct_new(TypeIdx::new(128U)), b"\xfb\x00\x80\x01"),
    (Instruction::i32x4_add(), b"\xfd\xae\x01"),
  ]
  for (instruction, expected) in cases {
    let buffer = @buffer.new()
    assert_eq(encode_leaf_instruction_error(instruction, buffer), None)
    assert_eq(buffer.to_bytes(), expected)
    let public_buffer = @buffer.new()
    assert_eq(Encode::encode(instruction, public_buffer), Ok(()))
    assert_eq(public_buffer.to_bytes(), expected)
  }
  // Decode literal NaN payloads and signed zero so equality never rounds bits.
  for
    expected in [
      b"\x43\x01\x00\xc0\x7f", b"\x44\x01\x00\x00\x00\x00\x00\xf8\x7f", b"\x44\x00\x00\x00\x00\x00\x00\x00\x80",
    ] {
    let (instruction, end) : (Instruction, Int) = Decode::decode(expected, 0).unwrap()
    assert_eq(end, expected.length())
    let buffer = @buffer.new()
    assert_eq(encode_leaf_instruction_error(instruction, buffer), None)
    assert_eq(buffer.to_bytes(), expected)
  }
}

///|
test "leaf error-only encoder rejects intentionally unsupported immediates in order" {
  let cases : Array[(Instruction, BinaryEncodeError, Bytes)] = [
    (
      Instruction::ref_null(HeapType::new(TypeIdx::rec(0U))),
      BinaryEncodeError::CannotEncodeRecursiveIndexHeapType,
      b"\xd0",
    ),
    (
      Instruction::struct_new(TypeIdx::rec(0U)),
      BinaryEncodeError::CannotEncodeNonStandardTypeIndex,
      b"\xfb\x00",
    ),
    (
      Instruction::i32_load(@lib.MemArg::new(64U, None, 0UL)),
      BinaryEncodeError::InvalidMemArgEncoding,
      b"\x28",
    ),
  ]
  for (instruction, expected_error, partial_bytes) in cases {
    let buffer = @buffer.new()
    assert_eq(
      encode_leaf_instruction_error(instruction, buffer),
      Some(expected_error),
    )
    assert_eq(buffer.to_bytes(), partial_bytes)
    let public_buffer = @buffer.new()
    assert_eq(Encode::encode(instruction, public_buffer), Err(expected_error))
    assert_eq(public_buffer.to_bytes(), partial_bytes)
    let sequence_buffer = @buffer.new()
    assert_eq(
      Encode::encode(
        @lib.Expr::new([Instruction::nop(), instruction, Instruction::i32_add()]),
        sequence_buffer,
      ),
      Err(expected_error),
    )
    let expected_buffer = @buffer.new()
    expected_buffer.write_byte(0x01)
    expected_buffer.write_bytes(partial_bytes)
    assert_eq(sequence_buffer.to_bytes(), expected_buffer.to_bytes())
  }
}
