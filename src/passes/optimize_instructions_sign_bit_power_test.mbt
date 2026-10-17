///|
test "optimize-instructions unsigned division by the sign bit becomes a shift" {
  for
    (width, minimum, shift) in [
      ("i32", "-2147483648", 31),
      ("i64", "-9223372036854775808", 63),
    ] {
    let func = optimize_instructions_test_run_hot(
      "(module (func (param \{width}) (result \{width}) local.get 0 \{width}.const \{minimum} \{width}.div_u))",
    )
    let root = @ir.hot_root_get(func, 0)
    let expected = if width == "i32" {
      @lib.Instruction::i32_shr_u()
    } else {
      @lib.Instruction::i64_shr_u()
    }
    @debug.assert_eq(@ir.hot_node_exact_instr(func, root), Some(expected))
    let rhs = @ir.hot_child_get(func, root, 1)
    if width == "i32" {
      @debug.assert_eq(
        @ir.hot_const_get(func, @ir.hot_node_get(func, rhs).imm0),
        @ir.HotConstPayload::i32_const(@lib.I32(shift)),
      )
    } else {
      @debug.assert_eq(
        @ir.hot_const_get(func, @ir.hot_node_get(func, rhs).imm0),
        @ir.HotConstPayload::i64_const(@lib.I64(shift.to_int64())),
      )
    }
  }
}

///|
test "optimize-instructions sign-bit multiplication becomes a shift" {
  for
    (width, minimum) in [
      ("i32", "-2147483648"),
      ("i64", "-9223372036854775808"),
    ] {
    let func = optimize_instructions_test_run_hot(
      "(module (func (param \{width}) (result \{width}) local.get 0 \{width}.const \{minimum} \{width}.mul))",
    )
    let root = @ir.hot_root_get(func, 0)
    let expected = if width == "i32" {
      @lib.Instruction::i32_shl()
    } else {
      @lib.Instruction::i64_shl()
    }
    @debug.assert_eq(@ir.hot_node_exact_instr(func, root), Some(expected))
  }
}
