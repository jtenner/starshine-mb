///|
test "multibyte array memarg decodes type index before offset" {
  // Binaryen #9222 and multibyte-array-access #10: flags, typeidx, offset.
  // Both immediates use two-byte LEBs and have different values.
  for opcode in [0x28, 0x36] {
    let bytes = Bytes::from_array([
      opcode.to_byte(),
      0x22,
      0x81,
      0x01,
      0xac,
      0x02,
    ])
    let (instr, next) : (Instruction, Int) = Decode::decode(bytes, 0).unwrap()
    assert_eq(next, bytes.length())
    match instr {
      ArrayLoad(_, TypeIdx(129U), MemArg(U32(2U), None, U64(300UL)))
      | ArrayStore(_, TypeIdx(129U), MemArg(U32(2U), None, U64(300UL))) => ()
      _ => fail("array memarg fields do not match proposal byte order")
    }
  }
}

///|
test "multibyte array memarg encodes exact proposal bytes" {
  let memarg = MemArg::new(U32(2U), None, U64(300UL))
  let expected_load = b"\x28\x22\x81\x01\xac\x02"
  let expected_store = b"\x36\x22\x81\x01\xac\x02"
  for
    (instr, expected) in [
      (
        Instruction::array_load(
          @lib.LoadOp::i32_load(),
          TypeIdx::new(129U),
          memarg~,
        ),
        expected_load,
      ),
      (
        Instruction::array_store(
          @lib.StoreOp::i32_store(),
          TypeIdx::new(129U),
          memarg~,
        ),
        expected_store,
      ),
    ] {
    let buf = @buffer.new()
    Encode::encode(instr, buf).unwrap()
    assert_eq(buf.to_bytes(), expected)
  }
}

///|
test "linear memory memargs keep offset after flags or memory index" {
  for bytes in [b"\x28\x02\xac\x02", b"\x28\x42\x81\x01\xac\x02"] {
    let (instr, next) : (Instruction, Int) = Decode::decode(bytes, 0).unwrap()
    assert_eq(next, bytes.length())
    let buf = @buffer.new()
    Encode::encode(instr, buf).unwrap()
    assert_eq(buf.to_bytes(), bytes)
  }
}
