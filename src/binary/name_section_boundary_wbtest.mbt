///|
test "name section decoding stops before a following custom section" {
  // Empty module with name subsection 0 (module name n), then custom x: 01 02.
  let bytes : Bytes = b"\x00asm\x01\x00\x00\x00\x00\x09\x04name\x00\x02\x01n\x00\x04\x01x\x01\x02"
  let decoded = decode_module(bytes).unwrap()
  assert_eq(
    decoded.name_sec,
    Some(NameSec::new(module_name=Some(Name::new("n")))),
  )
  assert_eq(decoded.raw_name_sec_payload, Some(b"\x00\x02\x01n"))
  assert_eq(decoded.custom_secs, [CustomSec::new(Name::new("x"), b"\x01\x02")])
}

///|
test "name subsection cannot consume bytes from the following section" {
  // The module-name string claims two bytes, but only n belongs to this section.
  let bytes : Bytes = b"\x00asm\x01\x00\x00\x00\x00\x09\x04name\x00\x03\x02n\x00\x04\x01x\x01\x02"
  assert_true(decode_module(bytes) is Err(_))
}
