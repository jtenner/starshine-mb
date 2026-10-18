///|
fn[T : Encode + Decode + Eq + @debug.Debug] limits_u32_assert_roundtrip(
  value : T,
  expected : Bytes,
) -> Unit raise {
  let buf = @buffer.new()
  Encode::encode(value, buf).unwrap()
  @debug.assert_eq(buf.to_bytes(), expected)
  @debug.assert_eq(
    (Decode::decode(expected, 0) : Result[(T, Int32), BinaryDecodeError]),
    Ok((value, expected.length())),
  )
}

///|
test "i32 limits encode high minima as five byte unsigned values" {
  for
    (value, expected) in [
      (0x7fffffffU, b"\x00\xff\xff\xff\xff\x07"),
      (0x80000000U, b"\x00\x80\x80\x80\x80\x08"),
      (0xffffffffU, b"\x00\xff\xff\xff\xff\x0f"),
    ] {
    limits_u32_assert_roundtrip(Limits::i32(value, None), expected)
  }
}

///|
test "i32 limits encode high optional maxima as five byte unsigned values" {
  for
    (value, expected) in [
      (0x7fffffffU, b"\x01\x00\xff\xff\xff\xff\x07"),
      (0x80000000U, b"\x01\x00\x80\x80\x80\x80\x08"),
      (0xffffffffU, b"\x01\x00\xff\xff\xff\xff\x0f"),
    ] {
    limits_u32_assert_roundtrip(Limits::i32(0U, Some(value)), expected)
  }
}

///|
test "i32 memory types preserve high minima with both sharing flags" {
  for
    (value, unshared, shared) in [
      (0x7fffffffU, b"\x00\xff\xff\xff\xff\x07", b"\x02\xff\xff\xff\xff\x07"),
      (0x80000000U, b"\x00\x80\x80\x80\x80\x08", b"\x02\x80\x80\x80\x80\x08"),
      (0xffffffffU, b"\x00\xff\xff\xff\xff\x0f", b"\x02\xff\xff\xff\xff\x0f"),
    ] {
    let limits = Limits::i32(value, None)
    limits_u32_assert_roundtrip(MemType::new(limits), unshared)
    limits_u32_assert_roundtrip(MemType::new(limits, shared=true), shared)
  }
}

///|
test "i32 memory types preserve high optional maxima with both sharing flags" {
  for
    (value, unshared, shared) in [
      (
        0x7fffffffU, b"\x01\x00\xff\xff\xff\xff\x07", b"\x03\x00\xff\xff\xff\xff\x07",
      ),
      (
        0x80000000U, b"\x01\x00\x80\x80\x80\x80\x08", b"\x03\x00\x80\x80\x80\x80\x08",
      ),
      (
        0xffffffffU, b"\x01\x00\xff\xff\xff\xff\x0f", b"\x03\x00\xff\xff\xff\xff\x0f",
      ),
    ] {
    let limits = Limits::i32(0U, Some(value))
    limits_u32_assert_roundtrip(MemType::new(limits), unshared)
    limits_u32_assert_roundtrip(MemType::new(limits, shared=true), shared)
  }
}
