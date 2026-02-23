///|
priv suberror EncodingFailed {
  EncodingFailed(BinaryEncodeError)
}

///|
priv suberror DecodingFailed {
  DecodingFailed(BinaryDecodeError)
}

///|
fn[T : Encode + Decode + Eq + Show] roundtrip(x : T) -> Unit raise {
  let buf = @buffer.new()
  match Encode::encode(x, buf) {
    Ok(_) => ()
    Err(t) => raise EncodingFailed(t)
  }
  let bytes = buf.to_bytes()
  let (y, i2) = match Decode::decode(bytes, 0) {
    Ok(t) => t
    Err(t) => raise DecodingFailed(t)
  }
  if bytes.length() != i2 {
    println(("Failed: Byte Length Mismatch", bytes.length(), i2))
  }
  if y != x {
    println(("Failed", x))
    println(("Byte Representation", bytes.to_array()))
    let compare = @buffer.new()
    match Encode::encode(y, compare) {
      Ok(_) =>
        println(("Decoded byte representation", compare.to_bytes().to_array()))
      Err(t) => println("Could not re-encode actual value \{t}")
    }
    println(("Decoded", y))
  }
  assert_eq(i2, bytes.length())
  assert_eq(y, x)
}

///|
fn[T : Encode + Decode + Eq + Show + @quickcheck.Arbitrary] roundtrip_arbitrary(
  count : Int,
) -> Array[T] raise {
  let st = @splitmix.new()
  let a = Array::new(capacity=count)
  loop count {
    0 => break a
    n => {
      let val = T::arbitrary(n, st)
      roundtrip(val)
      a.push(val)
      continue n - 1
    }
  }
}

///|
fn[T] assert_decode_err_contains(
  result : Result[(T, Int), BinaryDecodeError],
  expected : BinaryDecodeError,
) -> Unit raise {
  match result {
    Ok(_) => fail("expected decode failure: \{expected}")
    Err(err) => assert_eq(err, expected)
  }
}

///|
fn assert_encode_err_contains(
  result : Result[Unit, BinaryEncodeError],
  expected : BinaryEncodeError,
) -> Unit raise {
  match result {
    Ok(_) => fail("expected encode failure: \{expected}")
    Err(err) => assert_eq(err, expected)
  }
}

///|
test "binary codec errors derive eq show debug" {
  let enc = BinaryEncodeError::CannotEncodeDefTypeHeapType
  let dec = BinaryDecodeError::InvalidCompType
  assert_eq(enc, BinaryEncodeError::CannotEncodeDefTypeHeapType)
  assert_eq(dec, BinaryDecodeError::InvalidCompType)
  inspect(enc, content="CannotEncodeDefTypeHeapType")
  inspect(dec, content="InvalidCompType")
  debug_inspect(enc, content="CannotEncodeDefTypeHeapType")
  debug_inspect(dec, content="InvalidCompType")
}

///|
test "uleb roundtrip u33" {
  let vals : Array[UInt64] = [0, 1, 127, 128, 129, 0xffff, 0xffffffff]
  for v in vals {
    let buf = @buffer.new()
    encode_unsigned(v, buf, 33).unwrap()
    let bytes = buf.to_bytes()
    let (v2, i2) = decode_unsigned(bytes, 0, 33).unwrap()
    assert_eq(v2, v)
    assert_eq(i2, bytes.length())
  }
}

///|
test "sleb roundtrip s33 boundary" {
  let vals : Array[Int64] = [
    0, 1, -1, 63, -64, 64, -65, 2147483647, -2147483648,
  ]
  for v in vals {
    let buf = @buffer.new()
    encode_signed(v, buf, 33).unwrap()
    let bytes = buf.to_bytes()
    let (v2, i2) = decode_signed(bytes, 0, 33).unwrap()
    assert_eq(v2, v)
    assert_eq(i2, bytes.length())
  }
}

///|
test "uleb rejects terminal unused bits at max width" {
  let bytes : Bytes = [
    0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x02,
  ]
  match decode_unsigned(bytes, 0, 64) {
    Ok(_) => fail("expected error")
    Err(err) =>
      assert_eq(err, BinaryDecodeError::UnsignedLebTerminalHasNonZeroUnusedBits)
  }
}

///|
test "sleb s33 accepts 0x3f" {
  match decode_signed(b"\x3f", 0, 33) {
    Ok((value, _)) => assert_eq(value, 63L)
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "uleb u33 rejects too many bytes" {
  let bytes : Bytes = [0x80, 0x80, 0x80, 0x80, 0x80, 0x00]
  match decode_unsigned(bytes, 0, 33) {
    Ok(_) => fail("expected error")
    Err(err) => assert_eq(err, BinaryDecodeError::UnsignedLebTooManyBytes)
  }
}

///|
test "uleb allows trailing zeros within max bytes" {
  let bytes : Bytes = [0x83, 0x00]
  let (v, i) = decode_unsigned(bytes, 0, 8).unwrap()
  assert_eq(v, 3)
  assert_eq(i, 2)
}

///|
test "uleb u33 boundaries roundtrip" {
  let vals : Array[UInt64] = [
    0UL,
    1UL,
    31UL,
    32UL,
    127UL,
    128UL,
    0xffffffffUL,
    (1UL << 33) - 1UL,
  ]
  for v in vals {
    let buf = @buffer.new()
    encode_unsigned(v, buf, 33).unwrap()
    let bytes = buf.to_bytes()
    let (v2, i2) = decode_unsigned(bytes, 0, 33).unwrap()
    assert_eq(v2, v)
    assert_eq(i2, bytes.length())
  }
}

///|
test "uleb allows trailing zeros within bound" {
  let (v, i) = decode_unsigned(b"\x83\x00", 0, 8).unwrap()
  assert_eq(v, 3UL)
  assert_eq(i, 2)
}

///|
test "sleb s33 boundaries roundtrip" {
  let min = -1L << 32
  let max = (1L << 32) - 1L
  let vals : Array[Int64] = [
    min,
    min + 1,
    -1,
    0,
    1,
    31,
    32,
    63,
    64,
    max - 1,
    max,
  ]
  for v in vals {
    let buf = @buffer.new()
    encode_signed(v, buf, 33).unwrap()
    let bytes = buf.to_bytes()
    let (v2, i2) = decode_signed(bytes, 0, 33).unwrap()
    assert_eq(v2, v)
    assert_eq(i2, bytes.length())
  }
}

///|
test "decode S33 accepts full unsigned upper bound" {
  let max_u32_in_s33 : Int64 = (1L << 32) - 1L
  let buf = @buffer.new()
  encode_signed(max_u32_in_s33, buf, 33).unwrap()
  let bytes = buf.to_bytes()
  let decoded : Result[(S33, Int), BinaryDecodeError] = Decode::decode(bytes, 0)
  match decoded {
    Ok((S33(v), i)) => {
      assert_eq(v, 0xffffffff)
      assert_eq(i, bytes.length())
    }
    Err(e) => fail("expected S33 upper bound to decode, got error: \{e}")
  }
}

///|
test "S33 roundtrip includes upper bound" {
  let values : Array[S33] = [S33(0), S33(1), S33(0xffffffff)]
  for value in values {
    roundtrip(value)
  }
}

///|
test "sleb s33 rejects too many bytes" {
  match decode_signed(b"\x80\x80\x80\x80\x80\x00", 0, 33) {
    Ok(_) => fail("expected error")
    Err(err) => assert_eq(err, BinaryDecodeError::SignedLebTooManyBytes)
  }
}

///|
test "sleb allows extra sign extension within bound" {
  let (v, i) = decode_signed(b"\xff\x7f", 0, 8).unwrap()
  assert_eq(v, -1)
  assert_eq(i, 2)
}

///|
test "sleb rejects malformed sign-extension bits" {
  match decode_signed(b"\xff\xff\xff\xff\x5f", 0, 33) {
    Ok(_) => fail("expected malformed sign-extension error")
    Err(err) =>
      assert_eq(err, BinaryDecodeError::SignedLebOutOfRangeForBitWidth)
  }
}

///|
test "optional decode fallthrough keeps cursor on decode failure" {
  let (none1, i1) = (
    Decode::decode(b"\x02", 0) : Result[(Bool?, Int), BinaryDecodeError]).unwrap()
  assert_eq(none1, None)
  assert_eq(i1, 0)

  let (none2, i2) = (
    Decode::decode(b"", 0) : Result[(Bool?, Int), BinaryDecodeError]).unwrap()
  assert_eq(none2, None)
  assert_eq(i2, 0)
}

///|
test "numeric decoders reject out-of-bounds fixed-width loads" {
  assert_decode_err_contains(
    (Decode::decode(b"\x00\x00\x00", 0) : Result[(F32, Int), BinaryDecodeError]),
    BinaryDecodeError::IndexOutOfBounds,
  )
  assert_decode_err_contains(
    (
      Decode::decode(b"\x00\x00\x00\x00\x00\x00\x00", 0) :
      Result[(F64, Int), BinaryDecodeError]),
    BinaryDecodeError::IndexOutOfBounds,
  )
}

///|
test "decode helpers reject invalid bit widths and truncated inputs" {
  match decode_unsigned(b"\x00", 0, 0) {
    Ok(_) => fail("expected invalid nbits error for uleb nbits=0")
    Err(err) => assert_eq(err, BinaryDecodeError::InvalidUnsignedLebBitWidth)
  }
  match decode_unsigned(b"\x00", 0, 65) {
    Ok(_) => fail("expected invalid nbits error for uleb nbits=65")
    Err(err) => assert_eq(err, BinaryDecodeError::InvalidUnsignedLebBitWidth)
  }
  match decode_unsigned(b"\x80", 0, 8) {
    Ok(_) => fail("expected EOF error for unterminated uleb")
    Err(err) => assert_eq(err, BinaryDecodeError::UnexpectedEofInUnsignedLeb)
  }
  match decode_signed(b"\x00", 0, 0) {
    Ok(_) => fail("expected invalid nbits error for sleb nbits=0")
    Err(err) => assert_eq(err, BinaryDecodeError::InvalidSignedLebBitWidth)
  }
  match decode_signed(b"\x00", 0, 65) {
    Ok(_) => fail("expected invalid nbits error for sleb nbits=65")
    Err(err) => assert_eq(err, BinaryDecodeError::InvalidSignedLebBitWidth)
  }
  match decode_signed(b"\x80", 0, 8) {
    Ok(_) => fail("expected EOF error for unterminated sleb")
    Err(err) => assert_eq(err, BinaryDecodeError::UnexpectedEofInSignedLeb)
  }
}

///|
test "bool decode rejects invalid byte and out of bounds" {
  let invalid : Result[(Bool, Int), BinaryDecodeError] = Decode::decode(
    b"\x02", 0,
  )
  assert_decode_err_contains(invalid, BinaryDecodeError::InvalidBoolByte)
  let oob : Result[(Bool, Int), BinaryDecodeError] = Decode::decode(b"", 0)
  assert_decode_err_contains(oob, BinaryDecodeError::IndexOutOfBounds)
}

///|
test "decode reports invalid bytes for instruction and lane index" {
  assert_decode_err_contains(
    (Decode::decode(b"\xFF", 0) : Result[(Instruction, Int), BinaryDecodeError]),
    BinaryDecodeError::InvalidInstruction,
  )
  assert_decode_err_contains(
    (Decode::decode(b"\x10", 0) : Result[(LaneIdx, Int), BinaryDecodeError]),
    BinaryDecodeError::InvalidLaneIndex,
  )
}

///|
test "decode i8x16.shuffle preserves all 16 lane indices in order" {
  let bytes : Bytes = [
    0xFD, 0x0D, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A,
    0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
  ]
  match
    (Decode::decode(bytes, 0) : Result[(Instruction, Int), BinaryDecodeError]) {
    Ok((instr, next)) => {
      assert_eq(
        instr,
        Instruction::i8x16_shuffle(
          LaneIdx::new(0),
          LaneIdx::new(1),
          LaneIdx::new(2),
          LaneIdx::new(3),
          LaneIdx::new(4),
          LaneIdx::new(5),
          LaneIdx::new(6),
          LaneIdx::new(7),
          LaneIdx::new(8),
          LaneIdx::new(9),
          LaneIdx::new(10),
          LaneIdx::new(11),
          LaneIdx::new(12),
          LaneIdx::new(13),
          LaneIdx::new(14),
          LaneIdx::new(15),
        ),
      )
      assert_eq(next, bytes.length())
    }
    Err(e) => fail("unexpected shuffle decode failure: \{e}")
  }
}

///|
test "decode reports invalid atomic.fence immediate" {
  assert_decode_err_contains(
    (
      Decode::decode(b"\xFE\x03\x01", 0) :
      Result[(Instruction, Int), BinaryDecodeError]),
    BinaryDecodeError::InvalidAtomicFenceImmediate,
  )
}

///|
test "type section decode reports payload EOF and trailing bytes" {
  assert_decode_err_contains(
    (
      Decode::decode(b"\x01\x03\x00", 0) :
      Result[(TypeSec, Int), BinaryDecodeError]),
    BinaryDecodeError::SectionPayloadLengthOutOfRange,
  )
  assert_decode_err_contains(
    (
      Decode::decode(b"\x01\x02\x00\x00", 0) :
      Result[(TypeSec, Int), BinaryDecodeError]),
    BinaryDecodeError::InvalidSectionPayloadTrailingBytes,
  )
}

///|
test "module decode bubbles section errors instead of generic invalid module" {
  assert_decode_err_contains(
    (
      Decode::decode(b"\x00\x61\x73\x6D\x01\x00\x00\x00\x00\x02\x00", 0) :
      Result[(Module, Int), BinaryDecodeError]),
    BinaryDecodeError::CustomSectionPayloadLengthOutOfRange,
  )
  assert_decode_err_contains(
    (
      Decode::decode(b"\x00\x61\x73\x6D\x01\x00\x00\x00\x01\x02\x01\xFF", 0) :
      Result[(Module, Int), BinaryDecodeError]),
    BinaryDecodeError::InvalidCompType,
  )
}

///|
test "invalid decode vectors are table-driven across decoders" {
  let module_vectors : Array[(String, Bytes, BinaryDecodeError)] = [
    (
      "bad magic header",
      b"\x01\x61\x73\x6D\x01\x00\x00\x00",
      BinaryDecodeError::InvalidMagicHeader,
    ),
    (
      "module trailing bytes",
      b"\x00\x61\x73\x6D\x01\x00\x00\x00\x7F",
      BinaryDecodeError::InvalidModule,
    ),
    (
      "custom section payload overflow",
      b"\x00\x61\x73\x6D\x01\x00\x00\x00\x00\x02\x00",
      BinaryDecodeError::CustomSectionPayloadLengthOutOfRange,
    ),
    (
      "type section invalid payload content",
      b"\x00\x61\x73\x6D\x01\x00\x00\x00\x01\x02\x01\xFF",
      BinaryDecodeError::InvalidCompType,
    ),
  ]
  for vector in module_vectors {
    let (name, bytes, expected) = vector
    match
      (Decode::decode(bytes, 0) : Result[(Module, Int), BinaryDecodeError]) {
      Ok(_) => fail("expected module decode failure for vector '\{name}'")
      Err(err) => assert_eq(err, expected)
    }
  }

  let type_sec_vectors : Array[(String, Bytes, BinaryDecodeError)] = [
    (
      "wrong section header",
      b"\x02\x00",
      BinaryDecodeError::InvalidSectionHeader,
    ),
    (
      "payload length overflow",
      b"\x01\x03\x00",
      BinaryDecodeError::SectionPayloadLengthOutOfRange,
    ),
    (
      "unconsumed payload bytes",
      b"\x01\x02\x00\x00",
      BinaryDecodeError::InvalidSectionPayloadTrailingBytes,
    ),
  ]
  for vector in type_sec_vectors {
    let (name, bytes, expected) = vector
    match
      (Decode::decode(bytes, 0) : Result[(TypeSec, Int), BinaryDecodeError]) {
      Ok(_) => fail("expected TypeSec decode failure for vector '\{name}'")
      Err(err) => assert_eq(err, expected)
    }
  }

  let instruction_vectors : Array[(String, Bytes, BinaryDecodeError)] = [
    ("unknown opcode", b"\xFF", BinaryDecodeError::InvalidInstruction),
    (
      "atomic.fence with non-zero immediate",
      b"\xFE\x03\x01",
      BinaryDecodeError::InvalidAtomicFenceImmediate,
    ),
  ]
  for vector in instruction_vectors {
    let (name, bytes, expected) = vector
    match
      (Decode::decode(bytes, 0) : Result[(Instruction, Int), BinaryDecodeError]) {
      Ok(_) => fail("expected Instruction decode failure for vector '\{name}'")
      Err(err) => assert_eq(err, expected)
    }
  }
}

///|
test "decode primitive error branches include oob and nested failures" {
  assert_decode_err_contains(
    (Decode::decode(b"", 0) : Result[(NumType, Int), BinaryDecodeError]),
    BinaryDecodeError::IndexOutOfBounds,
  )
  assert_decode_err_contains(
    (Decode::decode(b"", 0) : Result[(AbsHeapType, Int), BinaryDecodeError]),
    BinaryDecodeError::IndexOutOfBounds,
  )
  assert_decode_err_contains(
    (Decode::decode(b"", 0) : Result[(RefType, Int), BinaryDecodeError]),
    BinaryDecodeError::IndexOutOfBounds,
  )
  assert_decode_err_contains(
    (Decode::decode(b"\x63", 0) : Result[(RefType, Int), BinaryDecodeError]),
    BinaryDecodeError::UnexpectedEofInSignedLeb,
  )
  assert_decode_err_contains(
    (Decode::decode(b"\x64", 0) : Result[(RefType, Int), BinaryDecodeError]),
    BinaryDecodeError::UnexpectedEofInSignedLeb,
  )
  assert_decode_err_contains(
    (Decode::decode(b"", 0) : Result[(ValType, Int), BinaryDecodeError]),
    BinaryDecodeError::IndexOutOfBounds,
  )
  assert_decode_err_contains(
    (Decode::decode(b"", 0) : Result[(CompType, Int), BinaryDecodeError]),
    BinaryDecodeError::IndexOutOfBounds,
  )
  assert_decode_err_contains(
    (Decode::decode(b"", 0) : Result[(Mut, Int), BinaryDecodeError]),
    BinaryDecodeError::UnexpectedEofDecodingMut,
  )
  assert_decode_err_contains(
    (Decode::decode(b"\x02", 0) : Result[(Mut, Int), BinaryDecodeError]),
    BinaryDecodeError::InvalidMutByte,
  )
  assert_decode_err_contains(
    (Decode::decode(b"\x79", 0) : Result[(StorageType, Int), BinaryDecodeError]),
    BinaryDecodeError::InvalidStorageType,
  )
  assert_decode_err_contains(
    (Decode::decode(b"\x79", 0) : Result[(PackType, Int), BinaryDecodeError]),
    BinaryDecodeError::InvalidPackedType,
  )
  assert_decode_err_contains(
    (Decode::decode(b"", 0) : Result[(RecType, Int), BinaryDecodeError]),
    BinaryDecodeError::IndexOutOfBounds,
  )
  assert_decode_err_contains(
    (Decode::decode(b"\x4E", 0) : Result[(RecType, Int), BinaryDecodeError]),
    BinaryDecodeError::UnexpectedEofInUnsignedLeb,
  )
  assert_decode_err_contains(
    (Decode::decode(b"", 0) : Result[(SubType, Int), BinaryDecodeError]),
    BinaryDecodeError::IndexOutOfBounds,
  )
  assert_decode_err_contains(
    (Decode::decode(b"\x4F", 0) : Result[(SubType, Int), BinaryDecodeError]),
    BinaryDecodeError::UnexpectedEofInUnsignedLeb,
  )
}

///|
test "generic list decode and encode propagate nested failures" {
  assert_decode_err_contains(
    (Decode::decode(b"", 0) : Result[(@list.List[Bool], Int), BinaryDecodeError]),
    BinaryDecodeError::UnexpectedEofInUnsignedLeb,
  )
  assert_decode_err_contains(
    (
      Decode::decode(b"\x01\x02", 0) :
      Result[(@list.List[Bool], Int), BinaryDecodeError]),
    BinaryDecodeError::InvalidBoolByte,
  )
  match
    (
      Decode::decode(b"\x02\x00\x01", 0) :
      Result[(@list.List[Bool], Int), BinaryDecodeError]) {
    Ok((decoded, i)) => {
      assert_eq(i, 3)
      assert_eq(decoded.to_array(), [false, true])
    }
    Err(e) => fail("unexpected list decode failure: \{e}")
  }

  let bad_list = @list.List::from_array([TypeIdx::new(0), TypeIdx::rec(0)])
  assert_encode_err_contains(
    Encode::encode(bad_list, @buffer.new()),
    BinaryEncodeError::CannotEncodeNonStandardTypeIndex,
  )
}

///|
test "encode rejects unsupported type/index forms" {
  assert_encode_err_contains(
    Encode::encode(TypeIdx::rec(0), @buffer.new()),
    BinaryEncodeError::CannotEncodeNonStandardTypeIndex,
  )
  assert_encode_err_contains(
    Encode::encode(HeapType::new(TypeIdx::rec(0)), @buffer.new()),
    BinaryEncodeError::CannotEncodeRecursiveIndexHeapType,
  )
  assert_encode_err_contains(
    Encode::encode(ValType::bottom(), @buffer.new()),
    BinaryEncodeError::CannotEncodeBottomValType,
  )
  assert_encode_err_contains(
    Encode::encode(BlockType::type_idx(TypeIdx::rec(0)), @buffer.new()),
    BinaryEncodeError::CannotEncodeRecursiveIndexBlockType,
  )
  assert_encode_err_contains(
    Encode::encode(
      HeapType::def_type(DefType::new(RecType::group([]), 0)),
      @buffer.new(),
    ),
    BinaryEncodeError::CannotEncodeDefTypeHeapType,
  )
  assert_encode_err_contains(
    Encode::encode(MemArg::new(64, None, 0), @buffer.new()),
    BinaryEncodeError::InvalidMemArgEncoding,
  )
}

///|
test "encode section payload errors propagate from nested values" {
  let bad_type_sec = TypeSec::new([
    RecType::new(SubType::comp_type(CompType::func([ValType::bottom()], []))),
  ])
  assert_encode_err_contains(
    Encode::encode(bad_type_sec, @buffer.new()),
    BinaryEncodeError::CannotEncodeBottomValType,
  )

  let bad_import_sec = ImportSec::new([
    Import::new(
      Name::new("m"),
      Name::new("f"),
      ExternType::func(TypeIdx::rec(0)),
    ),
  ])
  assert_encode_err_contains(
    Encode::encode(bad_import_sec, @buffer.new()),
    BinaryEncodeError::CannotEncodeNonStandardTypeIndex,
  )

  let bad_code_sec = CodeSec::new([
    Func::new(
      [],
      Expr::new([
        Instruction::block(BlockType::type_idx(TypeIdx::rec(0)), Expr::new([])),
      ]),
    ),
  ])
  assert_encode_err_contains(
    Encode::encode(bad_code_sec, @buffer.new()),
    BinaryEncodeError::CannotEncodeRecursiveIndexBlockType,
  )

  let bad_module = Module::new().with_type_sec(bad_type_sec)
  assert_encode_err_contains(
    Encode::encode(bad_module, @buffer.new()),
    BinaryEncodeError::CannotEncodeBottomValType,
  )
}

///|
test "uleb encoder never exceeds ceil(nbits/7)" {
  let buf = @buffer.new()
  encode_unsigned((1UL << 33) - 1UL, buf, 33).unwrap()
  assert_true(buf.to_bytes().length() <= max_leb_bytes(33))
}

///|
test "sleb encoder never exceeds ceil(nbits/7)" {
  let buf = @buffer.new()
  encode_signed(-1L << 32, buf, 33).unwrap()
  assert_true(buf.to_bytes().length() <= max_leb_bytes(33))
}

///|
test "leb sizing and encoding reject invalid bit widths and ranges" {
  assert_encode_err_contains(
    encode_unsigned(1UL, @buffer.new(), 0),
    BinaryEncodeError::InvalidUnsignedLebBitWidth,
  )
  assert_encode_err_contains(
    encode_unsigned(256UL, @buffer.new(), 8),
    BinaryEncodeError::UnsignedLebValueOutOfRange,
  )
  assert_encode_err_contains(
    encode_signed(1L, @buffer.new(), 0),
    BinaryEncodeError::InvalidSignedLebBitWidth,
  )
  assert_encode_err_contains(
    encode_signed(200L, @buffer.new(), 8),
    BinaryEncodeError::SignedLebValueOutOfRange,
  )

  match size_unsigned(1UL, 0) {
    Ok(_) => fail("expected invalid nbits for size_unsigned")
    Err(e) => assert_eq(e, BinaryEncodeError::InvalidUnsignedLebBitWidth)
  }
  match size_unsigned(300UL, 8) {
    Ok(_) => fail("expected out-of-range size_unsigned")
    Err(e) => assert_eq(e, BinaryEncodeError::UnsignedLebValueOutOfRange)
  }
  match size_signed(1L, 0) {
    Ok(_) => fail("expected invalid nbits for size_signed")
    Err(e) => assert_eq(e, BinaryEncodeError::InvalidSignedLebBitWidth)
  }
  match size_signed(200L, 8) {
    Ok(_) => fail("expected out-of-range size_signed")
    Err(e) => assert_eq(e, BinaryEncodeError::SignedLebValueOutOfRange)
  }
}

///|
test "max leb constants match common widths" {
  assert_eq(MAX_LEB128_BYTES_32, 5)
  assert_eq(MAX_LEB128_BYTES_33, 5)
  assert_eq(MAX_LEB128_BYTES_64, 10)
  assert_eq(max_leb_bytes(32), MAX_LEB128_BYTES_32)
  assert_eq(max_leb_bytes(33), MAX_LEB128_BYTES_33)
  assert_eq(max_leb_bytes(64), MAX_LEB128_BYTES_64)
}

///|
test "write_section helper writes id length and payload" {
  let buf = @buffer.new()
  match
    write_section(42, buf, fn(payload) {
      payload.write_byte(0xAB)
      payload.write_byte(0xCD)
      Ok(())
    }) {
    Ok(_) => assert_eq(buf.to_bytes().to_array(), [42, 2, 0xAB, 0xCD])
    Err(e) => fail("unexpected write_section error: \{e}")
  }
}

///|
test "write_section helper propagates payload errors" {
  let buf = @buffer.new()
  assert_encode_err_contains(
    write_section(1, buf, fn(_) {
      Err(BinaryEncodeError::CannotEncodeBottomValType)
    }),
    BinaryEncodeError::CannotEncodeBottomValType,
  )
}

///|
test "start code and data count sections encode with canonical payload lengths" {
  let start_buf = @buffer.new()
  match Encode::encode(StartSec::new(FuncIdx::new(0)), start_buf) {
    Ok(_) => assert_eq(start_buf.to_bytes().to_array(), [0x08, 0x01, 0x00])
    Err(e) => fail("unexpected start section encode failure: \{e}")
  }

  let code_buf = @buffer.new()
  match Encode::encode(CodeSec::new([]), code_buf) {
    Ok(_) => assert_eq(code_buf.to_bytes().to_array(), [0x0A, 0x01, 0x00])
    Err(e) => fail("unexpected code section encode failure: \{e}")
  }

  let data_cnt_buf = @buffer.new()
  match Encode::encode(DataCntSec::new(U32(0)), data_cnt_buf) {
    Ok(_) => assert_eq(data_cnt_buf.to_bytes().to_array(), [0x0C, 0x01, 0x00])
    Err(e) => fail("unexpected data count section encode failure: \{e}")
  }
}

///|
test "start code and data count sections decode canonical payload wrappers" {
  match
    (
      Decode::decode(b"\x08\x01\x00", 0) :
      Result[(StartSec, Int), BinaryDecodeError]) {
    Ok((start, next)) => {
      assert_eq(start, StartSec::new(FuncIdx::new(0)))
      assert_eq(next, 3)
    }
    Err(e) => fail("unexpected start section decode failure: \{e}")
  }

  match
    (
      Decode::decode(b"\x0A\x01\x00", 0) :
      Result[(CodeSec, Int), BinaryDecodeError]) {
    Ok((code, next)) => {
      assert_eq(code, CodeSec::new([]))
      assert_eq(next, 3)
    }
    Err(e) => fail("unexpected code section decode failure: \{e}")
  }

  match
    (
      Decode::decode(b"\x0C\x01\x00", 0) :
      Result[(DataCntSec, Int), BinaryDecodeError]) {
    Ok((data_count, next)) => {
      assert_eq(data_count, DataCntSec::new(U32(0)))
      assert_eq(next, 3)
    }
    Err(e) => fail("unexpected data count section decode failure: \{e}")
  }
}

///|
test "start code and data count sections reject legacy non-length encoding forms" {
  assert_decode_err_contains(
    (Decode::decode(b"\x08\x00", 0) : Result[(StartSec, Int), BinaryDecodeError]),
    BinaryDecodeError::UnexpectedEofInUnsignedLeb,
  )
  assert_decode_err_contains(
    (Decode::decode(b"\x0A\x00", 0) : Result[(CodeSec, Int), BinaryDecodeError]),
    BinaryDecodeError::UnexpectedEofInUnsignedLeb,
  )
  assert_decode_err_contains(
    (
      Decode::decode(b"\x0C\x00", 0) :
      Result[(DataCntSec, Int), BinaryDecodeError]),
    BinaryDecodeError::UnexpectedEofInUnsignedLeb,
  )
}

///|
test "numtype valtype" {
  roundtrip(NumType::f32())
  roundtrip(NumType::f64())
  roundtrip(NumType::i32())
  roundtrip(NumType::i64())
}

///|
test "Heap Types" {
  roundtrip(HeapType::abs(AbsHeapType::exn()))
  roundtrip(HeapType::abs(AbsHeapType::array()))
  roundtrip(HeapType::abs(AbsHeapType::struct_()))
  roundtrip(HeapType::abs(AbsHeapType::i31()))
  roundtrip(HeapType::abs(AbsHeapType::eq()))
  roundtrip(HeapType::abs(AbsHeapType::any()))
  roundtrip(HeapType::abs(AbsHeapType::extern_()))
  roundtrip(HeapType::abs(AbsHeapType::func()))
  roundtrip(HeapType::abs(AbsHeapType::none()))
  roundtrip(HeapType::abs(AbsHeapType::no_extern()))
  roundtrip(HeapType::abs(AbsHeapType::no_func()))
  roundtrip(HeapType::abs(AbsHeapType::no_exn()))
  roundtrip(HeapType::new(TypeIdx::new(23)))
}

///|
test "Type Indexes" {
  let _ : Array[TypeIdx] = roundtrip_arbitrary(50)
}

///|
test "Ref Types" {
  let _ : Array[RefType] = roundtrip_arbitrary(20)
}

///|
test "Comp Types" {
  roundtrip(
    CompType::array(FieldType::new(StorageType::val_type(ValType::i32()), Var)),
  )
  roundtrip(
    CompType::struct_([
      FieldType::new(
        StorageType::val_type(
          ValType::ref_type(
            RefType::new(true, HeapType::abs(AbsHeapType::i31())),
          ),
        ),
        Var,
      ),
    ]),
  )
  roundtrip(
    CompType::func([ValType::i32(), ValType::i64()], [
      ValType::i64(),
      ValType::i32(),
    ]),
  )
  let _ : Array[CompType] = roundtrip_arbitrary(30)
}

///|
test "Storage Type" {
  let _ : Array[StorageType] = roundtrip_arbitrary(30)
}

///|
test "Packed Type" {
  roundtrip(PackType::i8())
  roundtrip(PackType::i16())
}

///|
test "SubTypes" {
  roundtrip(
    SubType::comp_type(
      CompType::array(
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ),
    ),
  )
  roundtrip(
    SubType::new(
      false,
      [TypeIdx::new(0), TypeIdx::new(2), TypeIdx::new(4)],
      CompType::func([], []),
    ),
  )
}

///|
test "SubTypes arbitrary" {
  let _ : Array[SubType] = roundtrip_arbitrary(100)
}

///|
test "RecTypes arbitrary" {
  let _ : Array[RecType] = roundtrip_arbitrary(100)
}

///|
test "TagTypes arbitrary" {
  let _ : Array[TagType] = roundtrip_arbitrary(100)
}

///|
test "MemTypes arbitrary" {
  let _ : Array[MemType] = roundtrip_arbitrary(100)
}

///|
test "TableTypes arbitrary" {
  let _ : Array[TableType] = roundtrip_arbitrary(100)
}

///|
test "ExternTypes arbitrary" {
  let _ : Array[TableType] = roundtrip_arbitrary(100)
}

///|
test "MemArg arbitrary" {
  let _ : Array[MemArg] = roundtrip_arbitrary(100)
}

///|
test "LaneIdx" {
  let _ : Array[LaneIdx] = roundtrip_arbitrary(100)
}

///|
test "Float specific edge case?" {
  roundtrip(Instruction::f32_const(F32(0.011397957801818848)))
}

///|
test "Floats arbitrary" {
  let _ : Array[F32] = roundtrip_arbitrary(10000)
}

///|
test "Doubles arbitrary" {
  let _ : Array[F64] = roundtrip_arbitrary(10000)
}

///|
test "Signed integers" {
  let _ : Array[I64] = roundtrip_arbitrary(100000)
}

///|
test "Block Types" {
  let _ : Array[BlockType] = roundtrip_arbitrary(1000)
}

///|
test "Descriptor instruction roundtrip" {
  roundtrip(Instruction::ref_get_desc())
  roundtrip(Instruction::ref_test_desc(true, HeapType::abs(AbsHeapType::eq())))
  roundtrip(Instruction::ref_test_desc(false, HeapType::new(TypeIdx::new(0))))
  roundtrip(
    Instruction::ref_cast_desc_eq(true, HeapType::abs(AbsHeapType::struct_())),
  )
  roundtrip(
    Instruction::ref_cast_desc_eq(false, HeapType::new(TypeIdx::new(2))),
  )
}

///|
test "Instructions arbitrary" {
  let st = @splitmix.new()
  loop 1000000 {
    0 => break ()
    n => {
      let val = Instruction::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary CustomSec" {
  let st = @splitmix.new()
  loop 100 {
    0 => break ()
    n => {
      let val = CustomSec::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary TypeSec" {
  let st = @splitmix.new()
  loop 100 {
    0 => break ()
    n => {
      let val = TypeSec::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary ImportSec" {
  let st = @splitmix.new()
  loop 100 {
    0 => break ()
    n => {
      let val = ImportSec::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary FuncSec" {
  let st = @splitmix.new()
  loop 100 {
    0 => break ()
    n => {
      let val = FuncSec::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary TableSec" {
  let st = @splitmix.new()
  loop 100 {
    0 => break ()
    n => {
      let val = TableSec::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary MemSec" {
  let st = @splitmix.new()
  loop 100 {
    0 => break ()
    n => {
      let val = MemSec::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary GlobalSec" {
  let st = @splitmix.new()
  loop 100 {
    0 => break ()
    n => {
      let val = GlobalSec::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary ExportSec" {
  let st = @splitmix.new()
  loop 100 {
    0 => break ()
    n => {
      let val = ExportSec::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary StartSec" {
  let st = @splitmix.new()
  loop 100 {
    0 => break ()
    n => {
      let val = StartSec::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary Elem" {
  let st = @splitmix.new()
  loop 1000 {
    0 => break ()
    n => {
      let val = Elem::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary ElemSec" {
  let st = @splitmix.new()
  loop 100 {
    0 => break ()
    n => {
      let val = ElemSec::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary Func" {
  let st = @splitmix.new()
  loop 1000 {
    0 => break ()
    n => {
      let val = Func::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary CodeSec" {
  let st = @splitmix.new()
  loop 100 {
    0 => break ()
    n => {
      let val = CodeSec::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary Data" {
  let st = @splitmix.new()
  loop 1000 {
    0 => break ()
    n => {
      let val = Data::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary DataSec" {
  let st = @splitmix.new()
  loop 100 {
    0 => break ()
    n => {
      let val = DataSec::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary DataCntSec" {
  let st = @splitmix.new()
  loop 100 {
    0 => break ()
    n => {
      let val = DataCntSec::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary TagSec" {
  let st = @splitmix.new()
  loop 100 {
    0 => break ()
    n => {
      let val = TagSec::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary Module" {
  let st = @splitmix.new()
  loop 1000 {
    0 => break ()
    n => {
      let val = Module::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Names" {
  let st = @splitmix.new()
  loop 1000 {
    0 => break ()
    n => {
      let val = Name::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}
