///|
test "Binaryen 132 multibyte array accesses consume and preserve memory arguments" {
  // The array flag shares ordinary load/store opcodes. Alignment is a log2
  // exponent, followed by the offset and array type index, with no memidx.
  for
    opcode in [
      0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f, 0x30, 0x31, 0x32, 0x33, 0x34,
      0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e,
    ] {
    let bytes = Bytes::from_array([opcode.to_byte(), 0x20, 0x91, 0x01, 0x02])
    let (instr, next) : (Instruction, Int) = match Decode::decode(bytes, 0) {
      Ok(decoded) => decoded
      Err(err) => fail("released array memory argument: \{err}")
    }
    assert_eq(next, bytes.length())
    let buf = @buffer.new()
    match Encode::encode(instr, buf) {
      Ok(_) => ()
      Err(err) => fail("array memory argument encode: \{err}")
    }
    assert_eq(buf.to_bytes(), bytes)
  }
}

///|
test "Binaryen 132 array memory arguments reject simultaneous memory index flags" {
  // Both backing-array and explicit-memory flags are invalid together.
  let result : Result[(Instruction, Int), BinaryDecodeError] = Decode::decode(
    b"\x28\x60\x00\x00\x00", 0,
  )
  match result {
    Err(_) => ()
    Ok(_) => fail("array load accepted a memory index")
  }
}

///|
test "Binaryen 132 array v128 load and store preserve their memory arguments" {
  for opcode in [0x00, 0x0b] {
    let bytes = Bytes::from_array([
      0xfd,
      opcode.to_byte(),
      0x24,
      0xff,
      0xff,
      0xff,
      0xff,
      0x0f,
      0x00,
    ])
    let (instr, next) : (Instruction, Int) = match Decode::decode(bytes, 0) {
      Ok(decoded) => decoded
      Err(err) => fail("v128 array memory argument: \{err}")
    }
    assert_eq(next, bytes.length())
    let buf = @buffer.new()
    match Encode::encode(instr, buf) {
      Ok(_) => ()
      Err(err) => fail("v128 array encoding: \{err}")
    }
    assert_eq(buf.to_bytes(), bytes)
  }
}

///|
test "Binaryen 132 array offsets reject values above u32 and invalid flags" {
  for
    bytes in [
      b"\x28\x20\x80\x80\x80\x80\x10\x00", b"\x28\x30\x00\x00\x00", b"\x28\x29\x00\x00",
    ] {
    let result : Result[(Instruction, Int), BinaryDecodeError] = Decode::decode(
      bytes, 0,
    )
    match result {
      Err(_) => ()
      Ok(_) => fail("invalid array memory argument accepted")
    }
  }
}
