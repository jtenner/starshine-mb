///|
test "exact body measurement avoids framing buffers and preserves encoder errors" {
  for width in [0, 125, 126, 127, 128] {
    let func = @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new(Array::make(width, @lib.Instruction::nop())),
    )
    let state = EncodedModuleSizeState::new(None)
    let buffers = [0]
    measure_module_code([func], [], state, body_buffers=Some(buffers)).unwrap()
    let encoded = @buffer.new()
    Encode::encode(func, encoded).unwrap()
    assert_eq(state.sizes, [encoded.length()])
    assert_eq(buffers[0], 1)
  }
  let invalid = @lib.Func::new(
    @lib.Locals::from_types([@lib.ValType::bottom()]),
    @lib.Expr::new([]),
  )
  let reference = Encode::encode(invalid, @buffer.new())
  let state = EncodedModuleSizeState::new(None)
  assert_eq(measure_module_code([invalid], [], state), reference)
}
