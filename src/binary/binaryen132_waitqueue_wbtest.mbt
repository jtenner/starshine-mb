///|
test "Binaryen 132 waitqueue instructions preserve released opcodes" {
  for bytes in [b"\xfe\x07", b"\xfe\x06", b"\xfe\x05\x00\x01"] {
    let (instruction, next) : (Instruction, Int) = match
      Decode::decode(bytes, 0) {
      Ok(value) => value
      Err(err) => fail("waitqueue decode: \{err}")
    }
    assert_eq(next, bytes.length())
    let encoded = @buffer.new()
    Encode::encode(instruction, encoded).unwrap()
    assert_eq(encoded.to_bytes(), bytes)
  }
}

///|
test "Binaryen 132 waitqueue and bottom heap encodings roundtrip" {
  for bytes in [b"\x5c", b"\x5b", b"\x65\x5c", b"\x65\x5b"] {
    let (heap, next) : (HeapType, Int) = match Decode::decode(bytes, 0) {
      Ok(value) => value
      Err(err) => fail("waitqueue heap decode: \{err}")
    }
    assert_eq(next, bytes.length())
    let encoded = @buffer.new()
    Encode::encode(heap, encoded).unwrap()
    assert_eq(encoded.to_bytes(), bytes)
  }
}
