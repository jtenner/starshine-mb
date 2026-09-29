///|
test "lower capture cleanup crosses balanced drops above a captured value" {
  let original = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([@lib.Instruction::i32_const(7)]),
  )
  let transformed = @lib.Func::new(
    @lib.Locals::from_types([@lib.ValType::i32()]),
    @lib.Expr::new([
      @lib.Instruction::i32_const(7),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::i32_const(0),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    ]),
  )
  let compacted = pass_lower_compact_captures(transformed, original, [])
  @debug.assert_eq(
    compacted,
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(7),
        @lib.Instruction::i32_const(0),
        @lib.Instruction::drop(),
      ]),
    ),
  )
}
