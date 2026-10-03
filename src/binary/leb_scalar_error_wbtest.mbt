///|
// Freeze the old loops so nullable workers cannot validate themselves.

///|
fn leb_scalar_original_encode_unsigned(
  val : UInt64,
  buf : @buffer.Buffer,
  nbits : Int,
) -> Result[Unit, BinaryEncodeError] {
  if nbits <= 0 || nbits > 64 {
    return Err(BinaryEncodeError::InvalidUnsignedLebBitWidth)
  }
  if nbits < 64 {
    let max = (1UL << nbits) - 1UL
    if val > max {
      return Err(BinaryEncodeError::UnsignedLebValueOutOfRange)
    }
  }
  let max_bytes = max_leb_bytes(nbits)
  let mut x = val
  let mut count = 0
  while true {
    if count >= max_bytes {
      return Err(BinaryEncodeError::UnsignedLebExceedsMaxByteLimit)
    }
    let payload = x & 0x7fUL
    x = x >> 7
    let out = if x == 0UL { payload } else { payload | 0x80UL }
    buf.write_byte(out.to_byte())
    count += 1
    if x == 0UL {
      break
    }
  }
  Ok(())
}

///|
fn leb_scalar_original_encode_signed(
  val : Int64,
  buf : @buffer.Buffer,
  nbits : Int,
) -> Result[Unit, BinaryEncodeError] {
  if nbits <= 0 || nbits > 64 {
    return Err(BinaryEncodeError::InvalidSignedLebBitWidth)
  }
  if nbits < 64 {
    let min = -1L << (nbits - 1)
    let max = (1L << (nbits - 1)) - 1
    if val < min || val > max {
      return Err(BinaryEncodeError::SignedLebValueOutOfRange)
    }
  }
  let max_bytes = max_leb_bytes(nbits)
  let mut x = val
  let mut count = 0
  while true {
    if count >= max_bytes {
      return Err(BinaryEncodeError::SignedLebExceedsMaxByteLimit)
    }
    let payload_u = (x & 0x7f).reinterpret_as_uint64()
    let sign_bit = (payload_u & 0x40UL) != 0UL
    x = x >> 7
    let done = (x == 0 && !sign_bit) || (x == -1 && sign_bit)
    let out = if done { payload_u } else { payload_u | 0x80UL }
    buf.write_byte(out.to_byte())
    count += 1
    if done {
      break
    }
  }
  Ok(())
}

///|
fn leb_scalar_check_unsigned(val : UInt64, bits : Int) -> Unit raise {
  let old = @buffer.new()
  let current = @buffer.new()
  old.write_byte(0x55)
  current.write_byte(0x55)
  let expected = match leb_scalar_original_encode_unsigned(val, old, bits) {
    Ok(_) => None
    Err(error) => Some(error)
  }
  assert_eq(encode_unsigned_error(val, current, bits), expected)
  assert_eq(current.to_bytes(), old.to_bytes())
}

///|
fn leb_scalar_check_signed(val : Int64, bits : Int) -> Unit raise {
  let old = @buffer.new()
  let current = @buffer.new()
  old.write_byte(0x55)
  current.write_byte(0x55)
  let expected = match leb_scalar_original_encode_signed(val, old, bits) {
    Ok(_) => None
    Err(error) => Some(error)
  }
  assert_eq(encode_signed_error(val, current, bits), expected)
  assert_eq(current.to_bytes(), old.to_bytes())
}

///|
test "LEB nullable workers preserve every width signed extrema and errors" {
  for bits in 1..<=64 {
    let max_u = if bits == 64 {
      0xffffffffffffffffUL
    } else {
      (1UL << bits) - 1UL
    }
    for val in [0UL, 1UL, max_u >> 1, max_u] {
      leb_scalar_check_unsigned(val, bits)
    }
    let min_s = -1L << (bits - 1)
    let max_s = if bits == 64 {
      0x7fffffffffffffffL
    } else {
      (1L << (bits - 1)) - 1L
    }
    for val in [min_s, -1L, 0L, max_s] {
      leb_scalar_check_signed(val, bits)
    }
    if bits < 64 {
      leb_scalar_check_unsigned(max_u + 1UL, bits)
      leb_scalar_check_signed(min_s - 1L, bits)
      leb_scalar_check_signed(max_s + 1L, bits)
    }
  }
  for bits in [-1, 0, 65] {
    leb_scalar_check_unsigned(0UL, bits)
    leb_scalar_check_unsigned(0xffffffffffffffffUL, bits)
    leb_scalar_check_signed(0L, bits)
    leb_scalar_check_signed(-1L, bits)
  }
  let bad = @buffer.new()
  bad.write_byte(0x55)
  assert_eq(
    encode_unsigned_error(256UL, bad, 8),
    Some(BinaryEncodeError::UnsignedLebValueOutOfRange),
  )
  assert_eq(bad.to_bytes(), b"\x55")
  assert_eq(
    encode_signed_error(128L, bad, 8),
    Some(BinaryEncodeError::SignedLebValueOutOfRange),
  )
  assert_eq(bad.to_bytes(), b"\x55")
}

///|
test "LEB leaf consumers preserve local and integer literal byte boundaries" {
  let cases : Array[(Instruction, Bytes)] = [
    (Instruction::local_get(@lib.LocalIdx::new(128U)), b"\x20\x80\x01"),
    (
      Instruction::local_set(@lib.LocalIdx::new(0xffffffffU)),
      b"\x21\xff\xff\xff\xff\x0f",
    ),
    (Instruction::local_tee(@lib.LocalIdx::new(0U)), b"\x22\x00"),
    (Instruction::i32_const(@lib.I32::new(-64)), b"\x41\x40"),
    (Instruction::i32_const(@lib.I32::new(64)), b"\x41\xc0\x00"),
    (Instruction::i64_const(@lib.I64::new(-65L)), b"\x42\xbf\x7f"),
  ]
  for (instr, expected) in cases {
    let current = @buffer.new()
    assert_eq(encode_leaf_instruction_error(instr, current), None)
    assert_eq(current.to_bytes(), expected)
    let public_ = @buffer.new()
    assert_eq(Encode::encode(instr, public_), Ok(()))
    assert_eq(public_.to_bytes(), expected)
  }
}
