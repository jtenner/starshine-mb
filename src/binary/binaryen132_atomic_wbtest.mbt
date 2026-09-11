///|
test "Binaryen 132 relaxed atomic order decodes and preserves exact bytes" {
  let fixtures = [
    b"\xfe\x10\x12\x02\x00", b"\xfe\x17\x12\x02\x00", b"\xfe\x1e\x12\x22\x00", b"\xfe\x48\x12\x22\x00",
    b"\xfe\x5c\x02\x00\x00", b"\xfe\x60\x22\x00\x00", b"\xfe\x67\x02\x00", b"\xfe\x6b\x22\x00",
    b"\xfe\x5f\x00\x00\x00", b"\xfe\x5f\x01\x00\x00", b"\xfe\x5f\x02\x00\x00", b"\xfe\x6a\x00\x00",
    b"\xfe\x6a\x01\x00", b"\xfe\x6a\x02\x00",
  ]
  for bytes in fixtures {
    let (instr, next) : (Instruction, Int) = match Decode::decode(bytes, 0) {
      Ok(value) => value
      Err(err) => fail("expected released relaxed atomic decode: \{err}")
    }
    assert_eq(next, bytes.length())
    let buf = @buffer.new()
    match Encode::encode(instr, buf) {
      Ok(_) => ()
      Err(err) => fail("expected released relaxed atomic encode: \{err}")
    }
    assert_eq(buf.to_bytes(), bytes)
  }
}
