///|
test "scalar f32 NaN literals preserve signed payload bits" {
  for
    (text, expected) in [
      ("nan", 0x7fc00000),
      ("+nan", 0x7fc00000),
      ("-nan", 0xffc00000),
      ("nan:0x1", 0x7f800001),
      ("+nan:0x400001", 0x7fc00001),
      ("-nan:0x400001", 0xffc00001),
      ("nan:0x7fffff", 0x7fffffff),
      ("nan:0x40_0001", 0x7fc00001),
    ] {
    let mod_ = wast_to_binary_module(
      "(module (func (result f32) f32.const \{text}))",
    ).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = mod_.code_sec.unwrap().0[0]
    match body {
      [@lib.F32Const(@lib.F32(value))] => {
        assert_eq(value.reinterpret_as_int(), expected)
        let bytes = @binary.encode_module(mod_.without_name_sec()).unwrap()
        let start = bytes.length() - 6
        assert_eq(bytes[start], (0x43).to_byte())
        for offset in 0..<4 {
          assert_eq(
            bytes[start + offset + 1],
            ((expected.reinterpret_as_uint() >> (offset * 8)) & 0xffU).to_byte(),
          )
        }
        assert_eq(bytes[bytes.length() - 1], (0x0b).to_byte())
        @validate.validate_module(@binary.decode_module(bytes).unwrap()).unwrap()
      }
      _ => fail("expected a scalar f32 constant")
    }
  }
}

///|
test "scalar f64 NaN literals preserve signed payload bits" {
  for
    (text, expected) in [
      ("nan", 0x7ff8000000000000L),
      ("+nan", 0x7ff8000000000000L),
      ("-nan", 0xfff8000000000000L),
      ("nan:0x1", 0x7ff0000000000001L),
      ("+nan:0x8000000000001", 0x7ff8000000000001L),
      ("-nan:0x8000000000001", 0xfff8000000000001L),
      ("nan:0xfffffffffffff", 0x7fffffffffffffffL),
      ("nan:0x8_0000_0000_0001", 0x7ff8000000000001L),
    ] {
    let mod_ = wast_to_binary_module(
      "(module (func (result f64) f64.const \{text}))",
    ).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = mod_.code_sec.unwrap().0[0]
    match body {
      [@lib.F64Const(@lib.F64(value))] => {
        assert_eq(value.reinterpret_as_int64(), expected)
        let bytes = @binary.encode_module(mod_.without_name_sec()).unwrap()
        let start = bytes.length() - 10
        assert_eq(bytes[start], (0x44).to_byte())
        for offset in 0..<8 {
          assert_eq(
            bytes[start + offset + 1],
            ((expected.reinterpret_as_uint64() >> (offset * 8)) & 0xffUL).to_byte(),
          )
        }
        assert_eq(bytes[bytes.length() - 1], (0x0b).to_byte())
        @validate.validate_module(@binary.decode_module(bytes).unwrap()).unwrap()
      }
      _ => fail("expected a scalar f64 constant")
    }
  }
}

///|
test "scalar NaN literals intentionally reject zero and out-of-range payloads" {
  for
    (kind, text) in [
      ("f32", "nan:0x0"),
      ("f32", "nan:0x800000"),
      ("f64", "nan:0x0"),
      ("f64", "nan:0x10000000000000"),
      ("f32", "nan:0xg"),
      ("f64", "nan:0x"),
    ] {
    assert_true(
      wast_to_binary_module(
        "(module (func (result \{kind}) \{kind}.const \{text}))",
      )
      is Err(_),
    )
  }
}

///|
test "scalar signed zero and ordinary numbers keep their exact bits" {
  let @lib.F32(negative_f32) = wt_parse_f32("-0").unwrap()
  let @lib.F64(negative_f64) = wt_parse_f64("-0").unwrap()
  let @lib.F32(ordinary_f32) = wt_parse_f32("1.5").unwrap()
  let @lib.F64(ordinary_f64) = wt_parse_f64("1.5").unwrap()
  assert_eq(negative_f32.reinterpret_as_int(), 0x80000000)
  assert_eq(negative_f64.reinterpret_as_int64(), 0x8000000000000000L)
  assert_eq(ordinary_f32.reinterpret_as_int(), 0x3fc00000)
  assert_eq(ordinary_f64.reinterpret_as_int64(), 0x3ff8000000000000L)
}
