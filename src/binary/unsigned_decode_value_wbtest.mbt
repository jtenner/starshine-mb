///|
fn unsigned_decode_assert_indices(
  bytes : Bytes,
  start : Int,
  value : UInt,
  end : Int,
) -> Unit raise {
  assert_eq(
    (Decode::decode(bytes, start) : Result[(U32, Int), BinaryDecodeError]),
    Ok((U32(value), end)),
  )
  assert_eq(
    (Decode::decode(bytes, start) : Result[(TypeIdx, Int), BinaryDecodeError]),
    Ok((TypeIdx::new(value), end)),
  )
  assert_eq(
    (Decode::decode(bytes, start) : Result[(FuncIdx, Int), BinaryDecodeError]),
    Ok((FuncIdx::new(value), end)),
  )
  assert_eq(
    (Decode::decode(bytes, start) : Result[(TableIdx, Int), BinaryDecodeError]),
    Ok((TableIdx::new(value), end)),
  )
  assert_eq(
    (Decode::decode(bytes, start) : Result[(MemIdx, Int), BinaryDecodeError]),
    Ok((MemIdx::new(value), end)),
  )
  assert_eq(
    (Decode::decode(bytes, start) : Result[(GlobalIdx, Int), BinaryDecodeError]),
    Ok((GlobalIdx::new(value), end)),
  )
  assert_eq(
    (Decode::decode(bytes, start) : Result[(TagIdx, Int), BinaryDecodeError]),
    Ok((TagIdx::new(value), end)),
  )
  assert_eq(
    (Decode::decode(bytes, start) : Result[(ElemIdx, Int), BinaryDecodeError]),
    Ok((ElemIdx::new(value), end)),
  )
  assert_eq(
    (Decode::decode(bytes, start) : Result[(DataIdx, Int), BinaryDecodeError]),
    Ok((DataIdx::new(value), end)),
  )
  assert_eq(
    (Decode::decode(bytes, start) : Result[(LocalIdx, Int), BinaryDecodeError]),
    Ok((LocalIdx::new(value), end)),
  )
  assert_eq(
    (Decode::decode(bytes, start) : Result[(LabelIdx, Int), BinaryDecodeError]),
    Ok((LabelIdx::new(value), end)),
  )
}

///|
test "unsigned index decoders preserve offsets maximum values and permitted padding" {
  for
    (bytes, value, end) in [
      (b"\x55\x00\x66", 0U, 2),
      (b"\x55\x7f\x66", 127U, 2),
      (b"\x55\x80\x01\x66", 128U, 3),
      (b"\x55\xff\xff\xff\xff\x0f\x66", 0xffffffffU, 6),
      (b"\x55\x80\x80\x80\x80\x00\x66", 0U, 6),
      (b"\x55\x81\x80\x80\x80\x00\x66", 1U, 6),
    ] {
    unsigned_decode_assert_indices(bytes, 1, value, end)
  }
  let bytes = b"\x00\x80\x01\xff\x00\x7f"
  let (a, next) = (
    Decode::decode(bytes, 0) : Result[(LocalIdx, Int), BinaryDecodeError]).unwrap()
  let (b, next) = (
    Decode::decode(bytes, next) : Result[(FuncIdx, Int), BinaryDecodeError]).unwrap()
  let (c, next) = (
    Decode::decode(bytes, next) : Result[(TypeIdx, Int), BinaryDecodeError]).unwrap()
  assert_eq(
    (a, b, c, next),
    (LocalIdx::new(0U), FuncIdx::new(128U), TypeIdx::new(127U), 5),
  )
  assert_eq(bytes[next], 0x7f)
}

///|
test "unsigned index decoders reject malformed input with unchanged first errors" {
  // These are intentionally invalid encodings, not unsupported valid values.
  for
    (bytes, expected) in [
      (b"", BinaryDecodeError::UnexpectedEofInUnsignedLeb),
      (b"\x80", BinaryDecodeError::UnexpectedEofInUnsignedLeb),
      (b"\x80\x80\x80\x80\x80", BinaryDecodeError::UnexpectedEofInUnsignedLeb),
      (b"\x80\x80\x80\x80\x80\x00", BinaryDecodeError::UnsignedLebTooManyBytes),
      (
        b"\xff\xff\xff\xff\x1f",
        BinaryDecodeError::UnsignedLebOutOfRangeForBitWidth,
      ),
    ] {
    assert_eq(
      (Decode::decode(bytes, 0) : Result[(U32, Int), BinaryDecodeError]).unwrap_err(),
      expected,
    )
    assert_eq(
      (Decode::decode(bytes, 0) : Result[(LocalIdx, Int), BinaryDecodeError]).unwrap_err(),
      expected,
    )
    assert_eq(
      (Decode::decode(bytes, 0) : Result[(LabelIdx, Int), BinaryDecodeError]).unwrap_err(),
      expected,
    )
    assert_eq(
      (Decode::decode(bytes, 0) : Result[(TypeIdx, Int), BinaryDecodeError]).unwrap_err(),
      expected,
    )
  }
}

///|
test "unsigned 64-bit decode retains high bits padding and terminal checks" {
  for
    (bytes, value, end) in [
      (
        b"\x55\xff\xff\xff\xff\xff\xff\xff\xff\xff\x01\x66", 0xffffffffffffffffUL,
        11,
      ),
      (
        b"\x55\x80\x80\x80\x80\x80\x80\x80\x80\x80\x01\x66", 0x8000000000000000UL,
        11,
      ),
      (b"\x55\x81\x80\x80\x80\x80\x80\x80\x80\x80\x00\x66", 1UL, 11),
    ] {
    assert_eq(
      (Decode::decode(bytes, 1) : Result[(U64, Int), BinaryDecodeError]),
      Ok((U64(value), end)),
    )
  }
  assert_eq(
    (
      Decode::decode(b"\x80\x80\x80\x80\x80\x80\x80\x80\x80\x02", 0) :
      Result[(U64, Int), BinaryDecodeError]).unwrap_err(),
    BinaryDecodeError::UnsignedLebTerminalHasNonZeroUnusedBits,
  )
}
