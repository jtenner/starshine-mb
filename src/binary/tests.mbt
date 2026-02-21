///|
priv suberror EncodingFailed {
  EncodingFailed(String)
}

///|
priv suberror DecodingFailed {
  DecodingFailed(String)
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
  result : Result[(T, Int), String],
  needle : String,
) -> Unit raise {
  match result {
    Ok(_) => fail("expected decode failure containing \{needle}")
    Err(msg) => assert_true(msg.contains(needle))
  }
}

///|
fn assert_encode_err_contains(
  result : Result[Unit, String],
  needle : String,
) -> Unit raise {
  match result {
    Ok(_) => fail("expected encode failure containing \{needle}")
    Err(msg) => assert_true(msg.contains(needle))
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
test "uleb u33 rejects terminal unused bits" {
  let bytes : Bytes = [0x80, 0x80, 0x80, 0x80, 0x20]
  match decode_unsigned(bytes, 0, 33) {
    Ok(_) => fail("expected error")
    Err(_) => ()
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
    Err(_) => ()
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
test "sleb s33 rejects too many bytes" {
  match decode_signed(b"\x80\x80\x80\x80\x80\x00", 0, 33) {
    Ok(_) => fail("expected error")
    Err(_) => ()
  }
}

///|
test "sleb allows extra sign extension within bound" {
  let (v, i) = decode_signed(b"\xff\x7f", 0, 8).unwrap()
  assert_eq(v, -1)
  assert_eq(i, 2)
}

///|
test "decode helpers reject invalid bit widths and truncated inputs" {
  match decode_unsigned(b"\x00", 0, 0) {
    Ok(_) => fail("expected invalid nbits error for uleb nbits=0")
    Err(_) => ()
  }
  match decode_unsigned(b"\x00", 0, 65) {
    Ok(_) => fail("expected invalid nbits error for uleb nbits=65")
    Err(_) => ()
  }
  match decode_unsigned(b"\x80", 0, 8) {
    Ok(_) => fail("expected EOF error for unterminated uleb")
    Err(_) => ()
  }
  match decode_signed(b"\x00", 0, 0) {
    Ok(_) => fail("expected invalid nbits error for sleb nbits=0")
    Err(_) => ()
  }
  match decode_signed(b"\x00", 0, 65) {
    Ok(_) => fail("expected invalid nbits error for sleb nbits=65")
    Err(_) => ()
  }
  match decode_signed(b"\x80", 0, 8) {
    Ok(_) => fail("expected EOF error for unterminated sleb")
    Err(_) => ()
  }
}

///|
test "bool decode rejects invalid byte and out of bounds" {
  let invalid : Result[(Bool, Int), String] = Decode::decode(b"\x02", 0)
  match invalid {
    Ok(_) => fail("expected invalid bool byte error")
    Err(_) => ()
  }
  let oob : Result[(Bool, Int), String] = Decode::decode(b"", 0)
  match oob {
    Ok(_) => fail("expected bool decode out-of-bounds error")
    Err(_) => ()
  }
}

///|
test "decode reports invalid bytes for instruction and lane index" {
  assert_decode_err_contains(
    (Decode::decode(b"\xFF", 0) : Result[(Instruction, Int), String]),
    "Invalid Instruction",
  )
  assert_decode_err_contains(
    (Decode::decode(b"\x10", 0) : Result[(LaneIdx, Int), String]),
    "Invalid Lane Index",
  )
}

///|
test "decode reports invalid atomic.fence immediate" {
  assert_decode_err_contains(
    (Decode::decode(b"\xFE\x03\x01", 0) : Result[(Instruction, Int), String]),
    "Invalid atomic.fence immediate",
  )
}

///|
test "type section decode reports payload EOF and trailing bytes" {
  assert_decode_err_contains(
    (Decode::decode(b"\x01\x03\x00", 0) : Result[(TypeSec, Int), String]),
    "payload length out of range",
  )
  assert_decode_err_contains(
    (Decode::decode(b"\x01\x02\x00\x00", 0) : Result[(TypeSec, Int), String]),
    "Invalid section - didn't consume all bytes",
  )
}

///|
test "module decode bubbles section errors instead of generic invalid module" {
  assert_decode_err_contains(
    (
      Decode::decode(b"\x00\x61\x73\x6D\x01\x00\x00\x00\x00\x02\x00", 0) :
      Result[(Module, Int), String]),
    "payload length out of range",
  )
  assert_decode_err_contains(
    (
      Decode::decode(b"\x00\x61\x73\x6D\x01\x00\x00\x00\x01\x02\x01\xFF", 0) :
      Result[(Module, Int), String]),
    "Invalid Comp Type",
  )
}

///|
test "encode rejects unsupported type/index forms" {
  assert_encode_err_contains(
    Encode::encode(TypeIdx::rec(0), @buffer.new()),
    "non standard type index",
  )
  assert_encode_err_contains(
    Encode::encode(HeapType::new(TypeIdx::rec(0)), @buffer.new()),
    "recursive indexes",
  )
  assert_encode_err_contains(
    Encode::encode(ValType::bottom(), @buffer.new()),
    "bottom type",
  )
  assert_encode_err_contains(
    Encode::encode(BlockType::type_idx(TypeIdx::rec(0)), @buffer.new()),
    "recursive indexes",
  )
}

///|
test "encode section payload errors propagate from nested values" {
  let bad_type_sec = TypeSec::new([
    RecType::new(SubType::comp_type(CompType::func([ValType::bottom()], []))),
  ])
  assert_encode_err_contains(
    Encode::encode(bad_type_sec, @buffer.new()),
    "bottom type",
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
    "non standard type index",
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
    "recursive indexes",
  )

  let bad_module = Module::new().with_type_sec(bad_type_sec)
  assert_encode_err_contains(
    Encode::encode(bad_module, @buffer.new()),
    "bottom type",
  )
}

///|
test "uleb encoder never exceeds ceil(nbits/7)" {
  let buf = @buffer.new()
  encode_unsigned((1UL << 33) - 1UL, buf, 33).unwrap()
  assert_true(buf.to_bytes().length() <= max_leb_bytes(33))
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
