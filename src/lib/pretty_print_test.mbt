///|
test "pretty print snapshots for core wasm types" {
  let ty = NumType::i32()

  inspect(ty, content="I32")
  inspect_debug(ty, content="I32NumType")
  inspect_pretty_print(ty, content="I32")
}

///|
test "pretty print wraps long lines with configured width" {
  let expr = Expr::new([
    Instruction::i32_const(I32(1)),
    Instruction::i32_const(I32(2)),
    Instruction::i32_const(I32(3)),
    Instruction::i32_add(),
    Instruction::drop(),
  ])
  let ctx = PrettyPrintContext::new(max_line_width=24U)
  inspect_pretty_print(
    expr,
    ctx~,
    content="(i32.const\n  I32(1))(i32.const\n  I32(2))(i32.const\n  I32(3))i32.adddrop(end)",
  )
}
