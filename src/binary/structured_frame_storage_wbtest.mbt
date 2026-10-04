///|
test "structured decoder appends only to the active owned body" {
  let bt = BlockType::void_()
  let value = Instruction::i32_const(I32(7))
  for kind in 0..<8 {
    let body : Array[Instruction] = []
    let sibling = [Instruction::nop()]
    let catches : Array[@lib.LegacyCatch] = []
    let frame = match kind {
      0 => BlockFrame(bt, 17, body)
      1 => LoopFrame(bt, 17, body)
      2 => IfFrame(bt, 17, body, None)
      3 => IfFrame(bt, 17, sibling, Some(body))
      4 => LegacyTryFrame(bt, 17, body, catches, None, Some(LabelIdx::new(2U)))
      5 =>
        LegacyTryFrame(
          bt,
          17,
          sibling,
          catches,
          Some(LegacyTaggedCatchFrame(TagIdx::new(3U), body)),
          None,
        )
      6 =>
        LegacyTryFrame(
          bt,
          17,
          sibling,
          catches,
          Some(LegacyCatchAllFrame(body)),
          None,
        )
      _ => TryTableFrame(bt, [], 17, body)
    }
    let next = structured_frame_push_instruction(frame, value)
    assert_eq(structured_frame_body_instruction_depth(next), 17)
    @debug.assert_eq(body, [value])
    @debug.assert_eq(sibling, [Instruction::nop()])
    assert_eq(catches.length(), 0)
    let final = structured_frame_finish(next)
    let expected = match kind {
      0 => Instruction::block(bt, Expr::new([value]))
      1 => Instruction::loop_(bt, Expr::new([value]))
      2 => Instruction::if_(bt, [value], None)
      3 => Instruction::if_(bt, sibling, Some([value]))
      4 =>
        Instruction::try_(
          bt,
          Expr::new([value]),
          [],
          delegate=Some(LabelIdx::new(2U)),
        )
      5 =>
        Instruction::try_(bt, Expr::new(sibling), [
          @lib.LegacyCatch::tagged(TagIdx::new(3U), Expr::new([value])),
        ])
      6 =>
        Instruction::try_(bt, Expr::new(sibling), [
          @lib.LegacyCatch::all(Expr::new([value])),
        ])
      _ => Instruction::try_table(bt, [], Expr::new([value]))
    }
    @debug.assert_eq(final, expected)
  }
}

///|
test "structured decoder keeps nested arms catches and delegates at byte boundaries" {
  let bt = BlockType::void_()
  let nested = Instruction::block(
    bt,
    Expr::new([
      Instruction::loop_(bt, Expr::new([Instruction::nop()])),
      Instruction::if_(
        bt,
        [Instruction::nop()],
        Some([Instruction::i32_const(I32(7)), Instruction::drop()]),
      ),
      Instruction::try_(bt, Expr::new([Instruction::nop()]), [
        @lib.LegacyCatch::tagged(
          TagIdx::new(128U),
          Expr::new([Instruction::nop()]),
        ),
        @lib.LegacyCatch::all(
          Expr::new([Instruction::i32_const(I32(9)), Instruction::drop()]),
        ),
      ]),
      Instruction::try_(
        bt,
        Expr::new([Instruction::nop()]),
        [],
        delegate=Some(LabelIdx::new(0U)),
      ),
      Instruction::try_table(bt, [], Expr::new([Instruction::nop()])),
    ]),
  )
  let buf = @buffer.new()
  buf.write_byte(0xff)
  Encode::encode(nested, buf).unwrap()
  let end = buf.to_bytes().length()
  buf.write_byte(0x01)
  let bytes = buf.to_bytes()
  let (decoded, next) = (
    Decode::decode(bytes, 1) : Result[(Instruction, Int), BinaryDecodeError]).unwrap()
  @debug.assert_eq(decoded, nested)
  assert_eq(next, end)
  let encoded = @buffer.new()
  Encode::encode(decoded, encoded).unwrap()
  assert_eq(encoded.to_bytes(), bytes[1:end].to_owned())
}

///|
test "structured decoder rejects intentionally malformed arm and catch delimiters" {
  for
    bytes in [
      b"\x02\x40\x05\x0b", b"\x04\x40\x05\x05\x0b", b"\x06\x40\x19\x07\x00\x0b",
      b"\x06\x40\x19\x19\x0b",
    ] {
    assert_eq(
      (Decode::decode(bytes, 0) : Result[(Instruction, Int), BinaryDecodeError]).unwrap_err(),
      BinaryDecodeError::InvalidInstruction,
    )
  }
}
