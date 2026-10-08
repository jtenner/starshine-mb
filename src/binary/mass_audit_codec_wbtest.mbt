///|
test "mass codec rejects intentionally invalid function body size prefixes" {
  let canonical : Bytes = b"\x02\x00\x0b"
  let (func, next) = (
    Decode::decode(canonical, 0) : Result[(Func, Int), BinaryDecodeError]).unwrap()
  assert_eq(func, Func::new(Locals::new([]), Expr::new([])))
  assert_eq(next, canonical.length())
  for bytes in [b"\x00\x00\x0b", b"\x01\x00\x0b", b"\x03\x00\x0b"] {
    // The body has two bytes. A zero, short, or long frame is invalid.
    assert_true(
      (Decode::decode(bytes, 0) : Result[(Func, Int), BinaryDecodeError])
      is Err(_),
    )
  }
  for
    bytes in [
      b"\x00asm\x01\x00\x00\x00\x01\x04\x01\x60\x00\x00\x03\x02\x01\x00\x0a\x04\x01\x00\x00\x0b",
      b"\x00asm\x01\x00\x00\x00\x01\x04\x01\x60\x00\x00\x03\x02\x01\x00\x0a\x04\x01\x03\x00\x0b",
    ] {
    assert_true(decode_module(bytes) is Err(_))
  }
}

///|
test "mass codec rejects intentionally invalid global mutability bytes" {
  assert_eq(
    (
      Decode::decode(b"\x7f\x00", 0) :
      Result[(GlobalType, Int), BinaryDecodeError]),
    Ok((GlobalType::new(ValType::i32(), false), 2)),
  )
  for bytes in [b"\x7f", b"\x7f\x41"] {
    assert_true(
      (Decode::decode(bytes, 0) : Result[(GlobalType, Int), BinaryDecodeError])
      is Err(_),
    )
  }
  // 0x41 is an invalid mutability byte. It cannot become the initializer opcode.
  assert_true(
    decode_module(b"\x00asm\x01\x00\x00\x00\x06\x05\x01\x7f\x41\x00\x0b")
    is Err(_),
  )
}

///|
test "mass codec rejects intentionally invalid i32 limit overflow encodings" {
  assert_eq(
    (
      Decode::decode(b"\x00\xff\xff\xff\xff\x0f", 0) :
      Result[(Limits, Int), BinaryDecodeError]),
    Ok((Limits::i32(0xffffffffU, None), 6)),
  )
  for
    bytes in [
      b"\x00\x80\x80\x80\x80\x10", b"\x01\x00\x80\x80\x80\x80\x10", b"\x00\x80\x80\x80\x80\x80\x00",
    ] {
    // An i32 limit is a u32 LEB. A high value or a sixth byte is invalid.
    assert_true(
      (Decode::decode(bytes, 0) : Result[(Limits, Int), BinaryDecodeError])
      is Err(_),
    )
  }
  for
    bytes in [
      b"\x00\x80\x80\x80\x80\x10", b"\x01\x00\x80\x80\x80\x80\x10", b"\x03\x00\x80\x80\x80\x80\x10",
    ] {
    assert_true(
      (Decode::decode(bytes, 0) : Result[(MemType, Int), BinaryDecodeError])
      is Err(_),
    )
  }
}

///|
test "mass codec rejects intentionally invalid atomic memarg reserved bits" {
  let canonical : Bytes = b"\xfe\x10\x02\x00"
  let (instr, next) = (
    Decode::decode(canonical, 0) : Result[(Instruction, Int), BinaryDecodeError]).unwrap()
  assert_eq(next, canonical.length())
  let buf = @buffer.new()
  Encode::encode(instr, buf).unwrap()
  assert_eq(buf.to_bytes(), canonical)
  for bytes in [b"\xfe\x10\x82\x01\x00", b"\xfe\x10\x82\x02\x00"] {
    // Bit 7 and higher do not belong to the released memarg flag set.
    assert_true(
      (Decode::decode(bytes, 0) : Result[(Instruction, Int), BinaryDecodeError])
      is Err(_),
    )
  }
}

///|
test "mass codec rejects intentionally invalid byte-vector span overflow" {
  // Adding this length to its five-byte prefix wraps a UInt. No payload exists.
  assert_eq(
    (
      Decode::decode(b"\xff\xff\xff\xff\x0f", 0) :
      Result[(Bytes, Int), BinaryDecodeError]),
    Err(BinaryDecodeError::InvalidOffset),
  )
}

///|
test "mass codec rejects intentionally invalid name-map count overflow" {
  // A large unsigned count must not become a negative Int and an empty map.
  assert_true(
    (
      Decode::decode(b"\xff\xff\xff\xff\x0f", 0) :
      Result[(NameMap, Int), BinaryDecodeError])
    is Err(_),
  )
  assert_true(
    (
      Decode::decode(b"\xff\xff\xff\xff\x0f", 0) :
      Result[(IndirectNameMap, Int), BinaryDecodeError])
    is Err(_),
  )
}

///|
test "mass codec preserves an unknown optional name subsection" {
  // Unknown custom metadata is valid and must survive a binary round trip.
  let bytes : Bytes = b"\x00asm\x01\x00\x00\x00\x00\x07\x04name\x12\x00"
  let mod_ = decode_module(bytes).unwrap()
  assert_eq(mod_.raw_name_sec_payload, Some(b"\x12\x00"))
  assert_eq(encode_module(mod_).unwrap(), bytes)
}
