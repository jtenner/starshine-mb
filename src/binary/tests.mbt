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
fn[T : Encode + Decode + Eq + Show + @quickcheck.Arbitrary] roundtrip_arbitrary_with_state(
  count : Int,
  st : @splitmix.RandomState,
) -> Array[T] raise {
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
fn binary_fuzz_ascii_lower(input : String) -> String {
  let out = StringBuilder::new()
  for c in input {
    if c >= 'A' && c <= 'Z' {
      out.write_char((c.to_int() + 32).unsafe_to_char())
    } else {
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
pub struct BinaryRoundtripFuzzStats {
  profile : String
  seed : UInt64
  attempts : Int
} derive(Eq, Show, Debug)

///|
pub fn run_binary_roundtrip_fuzz(
  profile : String,
  seed : UInt64,
) -> Result[BinaryRoundtripFuzzStats, String] {
  let normalized = binary_fuzz_ascii_lower(profile.trim().to_string())
  let (
    small,
    medium,
    section_count,
    large,
    floats,
    signed_ints,
    block_types,
    instructions,
  ) = match normalized {
    "smoke" => (8, 24, 16, 64, 256, 512, 128, 1024)
    "ci" => (30, 100, 100, 2000, 2000, 20000, 500, 50000)
    "stress" => (50, 100, 100, 1000, 10000, 100000, 1000, 1000000)
    _ =>
      return Err(
        "unknown binary fuzz profile '\{profile}'; expected smoke|ci|stress",
      )
  }
  let st = @splitmix.new(seed~)
  let mut attempts = 0

  let _ : Array[TypeIdx] = roundtrip_arbitrary_with_state(small, st) catch {
    _ => return Err("binary fuzz failed while roundtripping TypeIdx values")
  }
  attempts += small
  let _ : Array[RefType] = roundtrip_arbitrary_with_state(small, st) catch {
    _ => return Err("binary fuzz failed while roundtripping RefType values")
  }
  attempts += small
  let _ : Array[CompType] = roundtrip_arbitrary_with_state(small, st) catch {
    _ => return Err("binary fuzz failed while roundtripping CompType values")
  }
  attempts += small
  let _ : Array[StorageType] = roundtrip_arbitrary_with_state(small, st) catch {
    _ => return Err("binary fuzz failed while roundtripping StorageType values")
  }
  attempts += small

  let _ : Array[SubType] = roundtrip_arbitrary_with_state(medium, st) catch {
    _ => return Err("binary fuzz failed while roundtripping SubType values")
  }
  attempts += medium
  let _ : Array[RecType] = roundtrip_arbitrary_with_state(medium, st) catch {
    _ => return Err("binary fuzz failed while roundtripping RecType values")
  }
  attempts += medium
  let _ : Array[TagType] = roundtrip_arbitrary_with_state(medium, st) catch {
    _ => return Err("binary fuzz failed while roundtripping TagType values")
  }
  attempts += medium
  let _ : Array[MemType] = roundtrip_arbitrary_with_state(medium, st) catch {
    _ => return Err("binary fuzz failed while roundtripping MemType values")
  }
  attempts += medium
  let _ : Array[TableType] = roundtrip_arbitrary_with_state(medium, st) catch {
    _ => return Err("binary fuzz failed while roundtripping TableType values")
  }
  attempts += medium
  let _ : Array[ExternType] = roundtrip_arbitrary_with_state(medium, st) catch {
    _ => return Err("binary fuzz failed while roundtripping ExternType values")
  }
  attempts += medium
  let _ : Array[MemArg] = roundtrip_arbitrary_with_state(medium, st) catch {
    _ => return Err("binary fuzz failed while roundtripping MemArg values")
  }
  attempts += medium
  let _ : Array[LaneIdx] = roundtrip_arbitrary_with_state(medium, st) catch {
    _ => return Err("binary fuzz failed while roundtripping LaneIdx values")
  }
  attempts += medium

  let _ : Array[F32] = roundtrip_arbitrary_with_state(floats, st) catch {
    _ => return Err("binary fuzz failed while roundtripping F32 values")
  }
  attempts += floats
  let _ : Array[F64] = roundtrip_arbitrary_with_state(floats, st) catch {
    _ => return Err("binary fuzz failed while roundtripping F64 values")
  }
  attempts += floats
  let _ : Array[I64] = roundtrip_arbitrary_with_state(signed_ints, st) catch {
    _ => return Err("binary fuzz failed while roundtripping I64 values")
  }
  attempts += signed_ints
  let _ : Array[BlockType] = roundtrip_arbitrary_with_state(block_types, st) catch {
    _ => return Err("binary fuzz failed while roundtripping BlockType values")
  }
  attempts += block_types
  let _ : Array[Instruction] = roundtrip_arbitrary_with_state(instructions, st) catch {
    _ => return Err("binary fuzz failed while roundtripping Instruction values")
  }
  attempts += instructions

  let _ : Array[CustomSec] = roundtrip_arbitrary_with_state(section_count, st) catch {
    _ => return Err("binary fuzz failed while roundtripping CustomSec values")
  }
  attempts += section_count
  let _ : Array[TypeSec] = roundtrip_arbitrary_with_state(section_count, st) catch {
    _ => return Err("binary fuzz failed while roundtripping TypeSec values")
  }
  attempts += section_count
  let _ : Array[ImportSec] = roundtrip_arbitrary_with_state(section_count, st) catch {
    _ => return Err("binary fuzz failed while roundtripping ImportSec values")
  }
  attempts += section_count
  let _ : Array[FuncSec] = roundtrip_arbitrary_with_state(section_count, st) catch {
    _ => return Err("binary fuzz failed while roundtripping FuncSec values")
  }
  attempts += section_count
  let _ : Array[TableSec] = roundtrip_arbitrary_with_state(section_count, st) catch {
    _ => return Err("binary fuzz failed while roundtripping TableSec values")
  }
  attempts += section_count
  let _ : Array[MemSec] = roundtrip_arbitrary_with_state(section_count, st) catch {
    _ => return Err("binary fuzz failed while roundtripping MemSec values")
  }
  attempts += section_count
  let _ : Array[GlobalSec] = roundtrip_arbitrary_with_state(section_count, st) catch {
    _ => return Err("binary fuzz failed while roundtripping GlobalSec values")
  }
  attempts += section_count
  let _ : Array[ExportSec] = roundtrip_arbitrary_with_state(section_count, st) catch {
    _ => return Err("binary fuzz failed while roundtripping ExportSec values")
  }
  attempts += section_count
  let _ : Array[StartSec] = roundtrip_arbitrary_with_state(section_count, st) catch {
    _ => return Err("binary fuzz failed while roundtripping StartSec values")
  }
  attempts += section_count
  let _ : Array[ElemSec] = roundtrip_arbitrary_with_state(section_count, st) catch {
    _ => return Err("binary fuzz failed while roundtripping ElemSec values")
  }
  attempts += section_count
  let _ : Array[CodeSec] = roundtrip_arbitrary_with_state(section_count, st) catch {
    _ => return Err("binary fuzz failed while roundtripping CodeSec values")
  }
  attempts += section_count
  let _ : Array[DataSec] = roundtrip_arbitrary_with_state(section_count, st) catch {
    _ => return Err("binary fuzz failed while roundtripping DataSec values")
  }
  attempts += section_count
  let _ : Array[DataCntSec] = roundtrip_arbitrary_with_state(section_count, st) catch {
    _ => return Err("binary fuzz failed while roundtripping DataCntSec values")
  }
  attempts += section_count
  let _ : Array[TagSec] = roundtrip_arbitrary_with_state(section_count, st) catch {
    _ => return Err("binary fuzz failed while roundtripping TagSec values")
  }
  attempts += section_count

  let _ : Array[Elem] = roundtrip_arbitrary_with_state(large, st) catch {
    _ => return Err("binary fuzz failed while roundtripping Elem values")
  }
  attempts += large
  let _ : Array[Func] = roundtrip_arbitrary_with_state(large, st) catch {
    _ => return Err("binary fuzz failed while roundtripping Func values")
  }
  attempts += large
  let _ : Array[Data] = roundtrip_arbitrary_with_state(large, st) catch {
    _ => return Err("binary fuzz failed while roundtripping Data values")
  }
  attempts += large
  let _ : Array[Module] = roundtrip_arbitrary_with_state(large, st) catch {
    _ => return Err("binary fuzz failed while roundtripping Module values")
  }
  attempts += large
  let _ : Array[Name] = roundtrip_arbitrary_with_state(large, st) catch {
    _ => return Err("binary fuzz failed while roundtripping Name values")
  }
  attempts += large

  Ok(BinaryRoundtripFuzzStats::{ profile: normalized, seed, attempts })
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
test "run_binary_roundtrip_fuzz rejects unknown profile" {
  match run_binary_roundtrip_fuzz("not-a-profile", 0x5eedUL) {
    Ok(_) => fail("expected unknown binary fuzz profile error")
    Err(msg) => assert_true(msg.contains("unknown binary fuzz profile"))
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
test "module codec wrapper errors derive eq show debug" {
  let enc = EncodeError::Encode(BinaryEncodeError::CannotEncodeBottomValType)
  let dec = DecodeError::Decode(BinaryDecodeError::InvalidModule)
  let trailing = DecodeError::TrailingBytes(1, 1)
  let spanned = DecodeError::DecodeAt(
    BinaryDecodeError::InvalidSectionHeader,
    8,
    2,
  )
  assert_eq(
    enc,
    EncodeError::Encode(BinaryEncodeError::CannotEncodeBottomValType),
  )
  assert_eq(dec, DecodeError::Decode(BinaryDecodeError::InvalidModule))
  assert_eq(trailing, DecodeError::TrailingBytes(1, 1))
  assert_eq(
    spanned,
    DecodeError::DecodeAt(BinaryDecodeError::InvalidSectionHeader, 8, 2),
  )
  inspect(enc, content="Encode(CannotEncodeBottomValType)")
  inspect(dec, content="Decode(InvalidModule)")
  inspect(trailing, content="TrailingBytes(1, 1)")
  inspect(spanned, content="DecodeAt(InvalidSectionHeader, 8, 2)")
  debug_inspect(enc, content="Encode(CannotEncodeBottomValType)")
  debug_inspect(dec, content="Decode(InvalidModule)")
  debug_inspect(trailing, content="TrailingBytes(1, 1)")
  debug_inspect(spanned, content="DecodeAt(InvalidSectionHeader, 8, 2)")
}

///|
test "decode_module wraps decode success and malformed extra bytes as decode errors" {
  let mod = Module::new()
  let wasm = match encode_module(mod) {
    Ok(bytes) => bytes
    Err(e) => fail("expected wrapper encode success: \{e}")
  }
  match decode_module(wasm) {
    Ok(decoded) => assert_eq(decoded, mod)
    Err(e) => fail("expected wrapper decode success: \{e}")
  }
  let trailing = b"\x00\x61\x73\x6d\x01\x00\x00\x00\x7f"
  match decode_module(trailing) {
    Ok(_) => fail("expected malformed extra-bytes decode failure")
    Err(DecodeError::TrailingBytes(offset, len)) => {
      assert_eq(offset, 8)
      assert_eq(len, 1)
    }
    Err(e) => fail("expected decode-error variant, got \{e}")
  }
}

///|
test "decode_module attaches section spans to wrapper decode errors" {
  let bad_standard = b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x02\x00"
  match decode_module(bad_standard) {
    Ok(_) => fail("expected decode failure for malformed section")
    Err(
      DecodeError::DecodeAt(
        BinaryDecodeError::SectionPayloadLengthOutOfRange,
        offset,
        len
      )
    ) => {
      assert_eq(offset, 8)
      assert_eq(len, 3)
    }
    Err(e) => fail("expected section span decode error, got \{e}")
  }

  let bad_custom = b"\x00\x61\x73\x6d\x01\x00\x00\x00\x00\x02\x00"
  match decode_module(bad_custom) {
    Ok(_) => fail("expected decode failure for malformed custom section")
    Err(
      DecodeError::DecodeAt(
        BinaryDecodeError::CustomSectionPayloadLengthOutOfRange,
        offset,
        len
      )
    ) => {
      assert_eq(offset, 8)
      assert_eq(len, 3)
    }
    Err(e) => fail("expected custom-section span decode error, got \{e}")
  }
}

///|
test "decode_module reports section span for non-length type section decode errors" {
  let bad_type_payload = b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x03\x01\x00\x00"
  match decode_module(bad_type_payload) {
    Ok(_) => fail("expected decode failure for invalid type section payload")
    Err(DecodeError::DecodeAt(BinaryDecodeError::InvalidCompType, offset, len)) => {
      assert_eq(offset, 8)
      assert_eq(len, 5)
    }
    Err(e) => fail("expected type-section span decode error, got \{e}")
  }
}

///|
test "decode_module reports section span for non-length custom section decode errors" {
  let bad_custom_name = b"\x00\x61\x73\x6d\x01\x00\x00\x00\x00\x01\x80"
  match decode_module(bad_custom_name) {
    Ok(_) => fail("expected decode failure for malformed custom section name")
    Err(
      DecodeError::DecodeAt(
        BinaryDecodeError::UnexpectedEofInUnsignedLeb,
        offset,
        len
      )
    ) => {
      assert_eq(offset, 8)
      assert_eq(len, 3)
    }
    Err(e) => fail("expected custom-section span decode error, got \{e}")
  }
}

///|
test "decode_module wraps decode failure variant" {
  match decode_module(b"not-wasm") {
    Ok(_) => fail("expected decode wrapper failure")
    Err(DecodeError::Decode(err)) =>
      assert_eq(err, BinaryDecodeError::InvalidMagicHeader)
    Err(e) => fail("expected decode-error variant, got \{e}")
  }
}

///|
test "encode_module keeps separated TFunc locals even when they share a param-prefix type pattern" {
  let ty = RecType::new(
    SubType::comp_type(
      CompType::func([ValType::i32(), ValType::i64()], [ValType::f32()]),
    ),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([ty]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32(), ValType::i64()],
          Locals::from_types([ValType::i32(), ValType::i64(), ValType::f32()]),
          TExpr::new([TInstr::local_get(LocalIdx::new(4))]),
        ),
      ]),
    )
  let wasm = match encode_module(mod) {
    Ok(bytes) => bytes
    Err(e) => fail("expected encode success, got \{e}")
  }
  let decoded = match decode_module(wasm) {
    Ok(v) => v
    Err(e) => fail("expected decode success, got \{e}")
  }
  match decoded.code_sec {
    Some(CodeSec([Func(locals, _)])) =>
      assert_eq(
        locals,
        Locals::from_types([ValType::i32(), ValType::i64(), ValType::f32()]),
      )
    Some(CodeSec([TFunc(_, locals, _)])) => {
      assert_eq(locals.length(), 3)
      assert_eq(locals.at(0), Some(ValType::i32()))
      assert_eq(locals.at(1), Some(ValType::i64()))
      assert_eq(locals.at(2), Some(ValType::f32()))
    }
    _ =>
      fail(
        "expected decoded module to preserve all three non-param locals with prefix-like types",
      )
  }
}

///|
test "encode_module keeps typed-function body locals without prefix stripping" {
  let ty = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::i64()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([ty]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          Locals::from_types([ValType::i32(), ValType::i64()]),
          TExpr::new([TInstr::local_get(LocalIdx::new(2))]),
        ),
      ]),
    )
  let wasm = match encode_module(mod) {
    Ok(bytes) => bytes
    Err(e) => fail("expected encode success, got \{e}")
  }
  let decoded = match decode_module(wasm) {
    Ok(v) => v
    Err(e) => fail("expected decode success, got \{e}")
  }
  match decoded.code_sec {
    Some(CodeSec([Func(locals, _)])) => {
      let expected = Locals::from_types([ValType::i32(), ValType::i64()])
      if locals != expected {
        fail("expected two declared body locals [i32, i64], got \{locals}")
      }
      assert_eq(locals, expected)
    }
    _ => fail("expected single decoded function body")
  }
}

///|
test "decode_module accepts elem header 6 with explicit reftype and roundtrips module semantics" {
  let wasm = b"\x00\x61\x73\x6d\x01\x00\x00\x00\x09\x0b\x01\x06\x00\x41\x00\x0b\x70\x01\xd2\x00\x0b"
  let mod = match decode_module(wasm) {
    Ok(v) => v
    Err(e) => fail("expected elem header 6 decode success, got \{e}")
  }
  let reencoded = match encode_module(mod) {
    Ok(bytes) => bytes
    Err(e) => fail("expected re-encode success for header 6 fixture, got \{e}")
  }
  let reparsed = match decode_module(reencoded) {
    Ok(v) => v
    Err(e) => fail("expected decode success after re-encode, got \{e}")
  }
  assert_eq(reparsed, mod)
}

///|
test "encode elem active non-zero table func exprs includes explicit funcref reftype for header 6" {
  let elem = Elem::new(
    ElemMode::active(
      TableIdx::new(1),
      Expr::new([Instruction::i32_const(I32(0))]),
    ),
    ElemKind::func_exprs([Expr::new([Instruction::ref_func(FuncIdx::new(0))])]),
  )
  let buf = @buffer.new()
  match Encode::encode(elem, buf) {
    Ok(_) => ()
    Err(e) => fail("expected elem encode success, got \{e}")
  }
  let bytes = buf.to_bytes()
  assert_eq(bytes, b"\x06\x01\x41\x00\x0b\x70\x01\xd2\x00\x0b")
  let (decoded, i) = match
    (Decode::decode(bytes, 0) : Result[(Elem, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => fail("expected elem decode success, got \{e}")
  }
  assert_eq(i, bytes.length())
  assert_eq(decoded, elem)
}

///|
test "encode elem supports active typed expr segments for header 6" {
  let rt = RefType::new(true, HeapType::abs(AbsHeapType::extern_()))
  let elem = Elem::new(
    ElemMode::active(
      TableIdx::new(0),
      Expr::new([Instruction::i32_const(I32(0))]),
    ),
    ElemKind::typed_exprs(rt, [
      Expr::new([Instruction::ref_null(HeapType::abs(AbsHeapType::extern_()))]),
    ]),
  )
  let buf = @buffer.new()
  match Encode::encode(elem, buf) {
    Ok(_) => ()
    Err(e) => fail("expected active typed elem encode success, got \{e}")
  }
  let bytes = buf.to_bytes()
  let (decoded, i) = match
    (Decode::decode(bytes, 0) : Result[(Elem, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => fail("expected active typed elem decode success, got \{e}")
  }
  assert_eq(i, bytes.length())
  assert_eq(decoded, elem)
}

///|
test "decode_module preserves trailing-byte diagnostics for section-order and duplicate-section invalid modules" {
  let vectors : Array[(String, Bytes, Int, Int)] = [
    (
      "duplicate type section", b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x01\x00\x01\x01\x00",
      11, 3,
    ),
    (
      "out-of-order type section after import section", b"\x00\x61\x73\x6d\x01\x00\x00\x00\x02\x01\x00\x01\x01\x00",
      11, 3,
    ),
  ]
  for vector in vectors {
    let (name, bytes, expected_offset, expected_len) = vector
    match
      (Decode::decode(bytes, 0) : Result[(Module, Int), BinaryDecodeError]) {
      Ok(_) => fail("expected raw module decode failure for '\{name}'")
      Err(err) => assert_eq(err, BinaryDecodeError::InvalidModule)
    }
    match decode_module(bytes) {
      Ok(_) => fail("expected wrapper decode failure for '\{name}'")
      Err(DecodeError::TrailingBytes(offset, len)) => {
        assert_eq(offset, expected_offset)
        assert_eq(len, expected_len)
      }
      Err(e) =>
        fail("expected trailing-byte wrapper error for '\{name}', got \{e}")
    }
  }
}

///|
test "encode_module wraps encode failure variant" {
  let bad = Module::new().with_type_sec(
    TypeSec::new([
      RecType::new(SubType::comp_type(CompType::func([ValType::bottom()], []))),
    ]),
  )
  match encode_module(bad) {
    Ok(_) => fail("expected encode wrapper failure")
    Err(EncodeError::Encode(err)) =>
      assert_eq(err, BinaryEncodeError::CannotEncodeBottomValType)
  }
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
test "Decode I32 rejects invalid terminal signed LEB unused bits" {
  assert_decode_err_contains(
    (
      Decode::decode(b"\x80\x80\x80\x80\x1f", 0) :
      Result[(I32, Int), BinaryDecodeError]),
    BinaryDecodeError::SignedLebOutOfRangeForBitWidth,
  )
  match
    (
      Decode::decode(b"\xff\xff\xff\xff\x4f", 0) :
      Result[(I32, Int), BinaryDecodeError]) {
    Ok(_) => fail("expected decode failure for invalid sign-extension bits")
    Err(_) => ()
  }
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
      Locals::empty(),
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
  roundtrip(TypeIdx::new(0))
  roundtrip(TypeIdx::new(23))
  roundtrip(TypeIdx::new(2048))
}

///|
test "Ref Types" {
  roundtrip(RefType::new(true, HeapType::abs(AbsHeapType::func())))
  roundtrip(RefType::new(false, HeapType::abs(AbsHeapType::extern_())))
  roundtrip(RefType::abs(AbsHeapType::eq()))
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
test "Float specific edge case?" {
  roundtrip(Instruction::f32_const(F32(0.011397957801818848)))
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
fn binary_name_section_fixture_module() -> Module {
  let struct_type = RecType::new(
    SubType::comp_type(
      CompType::struct_([
        FieldType::new(StorageType::val_type(ValType::i32()), Const),
      ]),
    ),
  )
  let func_type = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
  )
  let tag_type = RecType::new(SubType::comp_type(CompType::func([], [])))
  let table_type = TableType::new(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
    Limits::i32(1U, Some(1U)),
  )
  let name_sec = NameSec::new(
    module_name=Some(Name::new("fixture")),
    func_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("id"))])),
    local_names=Some(
      IndirectNameMap::new([
        IndirectNameAssoc::new(
          0U,
          NameMap::new([NameAssoc::new(0U, Name::new("x"))]),
        ),
      ]),
    ),
    label_names=Some(
      IndirectNameMap::new([
        IndirectNameAssoc::new(
          0U,
          NameMap::new([
            NameAssoc::new(0U, Name::new("entry")),
            NameAssoc::new(1U, Name::new("repeat")),
            NameAssoc::new(2U, Name::new("branch")),
          ]),
        ),
      ]),
    ),
    type_names=Some(
      NameMap::new([
        NameAssoc::new(0U, Name::new("Pair")),
        NameAssoc::new(1U, Name::new("IdSig")),
        NameAssoc::new(2U, Name::new("TagSig")),
      ]),
    ),
    table_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("dispatch"))])),
    memory_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("heap"))])),
    global_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("flag"))])),
    elem_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("targets"))])),
    data_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("blob"))])),
    field_names=Some(
      IndirectNameMap::new([
        IndirectNameAssoc::new(
          0U,
          NameMap::new([NameAssoc::new(0U, Name::new("value"))]),
        ),
      ]),
    ),
    tag_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("boom"))])),
  )
  Module::new()
  .with_type_sec(TypeSec::new([struct_type, func_type, tag_type]))
  .with_func_sec(FuncSec::new([TypeIdx::new(1U)]))
  .with_table_sec(TableSec::new([Table::new(table_type, None)]))
  .with_mem_sec(MemSec::new([MemType::new(Limits::i32(1U, Some(1U)))]))
  .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(2U))]))
  .with_global_sec(
    GlobalSec::new([
      Global::new(
        GlobalType::new(ValType::i32(), false),
        Expr::new([Instruction::i32_const(I32(1))]),
      ),
    ]),
  )
  .with_elem_sec(
    ElemSec::new([
      Elem::new(
        ElemMode::active(
          TableIdx::new(0U),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
        ElemKind::funcs([FuncIdx::new(0U)]),
      ),
    ]),
  )
  .with_data_sec(
    DataSec::new([
      Data::new(
        DataMode::active(
          MemIdx::new(0U),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
        b"fixture",
      ),
    ]),
  )
  .with_code_sec(
    CodeSec::new([
      Func::new(
        Locals::empty(),
        Expr::new([
          Instruction::block(BlockType::void_(), Expr::new([])),
          Instruction::loop_(BlockType::void_(), Expr::new([])),
          Instruction::i32_const(I32(1)),
          Instruction::if_(BlockType::void_(), [], Some([])),
          Instruction::local_get(LocalIdx::new(0U)),
        ]),
      ),
    ]),
  )
  .with_name_sec(name_sec)
}

///|
test "encode_module emits structured name section after standard sections and decode_module roundtrips it" {
  let mod = binary_name_section_fixture_module()
  let wasm = match encode_module(mod) {
    Ok(bytes) => bytes
    Err(e) => fail("expected encode success, got \{e}")
  }
  assert_eq(wasm[8], 0x01)

  let decoded = match decode_module(wasm) {
    Ok(v) => v
    Err(e) => fail("expected decode success, got \{e}")
  }
  assert_eq(decoded, mod)
  assert_eq(decoded.custom_secs.length(), 0)
  assert_eq(decoded.name_sec, mod.name_sec)
}

///|
test "decode_module rejects malformed function name map ordering inside name section" {
  let bad = b"\x00\x61\x73\x6d\x01\x00\x00\x00\x00\x0e\x04name\x01\x07\x02\x01\x01b\x00\x01a"
  match decode_module(bad) {
    Ok(_) => fail("expected malformed name section decode failure")
    Err(
      DecodeError::DecodeAt(BinaryDecodeError::InvalidNameMapOrder, offset, len)
    ) => {
      assert_eq(offset, 8)
      assert_eq(len, 16)
    }
    Err(e) =>
      fail("expected spanned malformed name-section decode error, got \{e}")
  }
}
