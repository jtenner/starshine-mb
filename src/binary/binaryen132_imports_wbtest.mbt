///|
test "Binaryen 132 compact imports expand both groups in logical order" {
  let fixtures = [
    // One shared-module group: func m.a, immutable i32 global m.b.
    b"\x02\x0f\x01\x01m\x00\x7f\x02\x01a\x00\x00\x01b\x03\x7f\x00",
    // One shared-module-and-type group: funcs m.a and m.b.
     b"\x02\x0c\x01\x01m\x00\x7e\x00\x00\x02\x01a\x01b",
  ]
  for i, bytes in fixtures {
    let (sec, next) : (ImportSec, Int) = match Decode::decode(bytes, 0) {
      Ok(value) => value
      Err(err) => fail("expected compact import decode: \{err}")
    }
    assert_eq(next, bytes.length())
    let ImportSec(imports) = sec
    let second_type = if i == 0 {
      ExternType::global(GlobalType::new(ValType::i32(), false))
    } else {
      ExternType::func(TypeIdx::new(0U))
    }
    @debug.assert_eq(imports, [
      Import::new(
        Name::new("m"),
        Name::new("a"),
        ExternType::func(TypeIdx::new(0U)),
      ),
      Import::new(Name::new("m"), Name::new("b"), second_type),
    ])
    let buf = @buffer.new()
    match Encode::encode(sec, buf) {
      Ok(_) => ()
      Err(err) => fail("expected logical import encode: \{err}")
    }
    let (again, _) : (ImportSec, Int) = match
      Decode::decode(buf.to_bytes(), 0) {
      Ok(value) => value
      Err(err) => fail("expected logical import re-decode: \{err}")
    }
    @debug.assert_eq(again, sec)
  }
}

///|
test "Binaryen 132 compact writer groups only consecutive compatible imports when enabled" {
  let func_type = ExternType::func(TypeIdx::new(0U))
  let imports = [
    Import::new(Name::new("m"), Name::new("a"), func_type),
    Import::new(Name::new("m"), Name::new("b"), func_type),
    Import::new(Name::new("n"), Name::new("c"), func_type),
    Import::new(Name::new("m"), Name::new("d"), func_type),
  ]
  let mod_ = Module::new(import_sec=Some(ImportSec::new(imports)))
  let encoded = match encode_module(mod_, compact_imports=true) {
    Ok(bytes) => bytes
    Err(err) => fail("expected compact module encoding: \{err}")
  }
  @debug.assert_eq(
    encoded, b"\x00asm\x01\x00\x00\x00\x02\x18\x03\x01m\x00\x7e\x00\x00\x02\x01a\x01b\x01n\x01c\x00\x00\x01m\x01d\x00\x00",
  )
  let decoded = match decode_module(encoded) {
    Ok(mod_) => mod_
    Err(err) => fail("expected compact module decode: \{err}")
  }
  @debug.assert_eq(decoded.import_sec, mod_.import_sec)
  let ordinary = match encode_module(mod_) {
    Ok(bytes) => bytes
    Err(err) => fail("expected ordinary encoding: \{err}")
  }
  assert_false(ordinary == encoded)
}

///|
test "Binaryen 132 compact imports reject intentionally invalid truncated and nested groups" {
  let invalid = [
    b"\x02\x06\x01\x01m\x00\x7f\x01", b"\x02\x08\x01\x01m\x00\x7e\x00\x00\x01", b"\x02\x09\x01\x01m\x00\x7f\x01\x00\x7f\x00",
    b"\x02\x08\x01\x01m\x01x\x7e\x00\x00",
  ]
  for bytes in invalid {
    assert_true(
      (Decode::decode(bytes, 0) : Result[(ImportSec, Int), BinaryDecodeError])
      is Err(_),
    )
  }
}
