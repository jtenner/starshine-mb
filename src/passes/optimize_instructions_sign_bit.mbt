///|
// Keep the raw constant-fold shortcut consistent with the HOT power-of-two
// rules. Only the literal and its consuming operator change; the preceding
// dividend or multiplicand and all of its effects remain in place.
fn oi_sign_bit_raw_pair(
  rhs : @lib.Instruction,
  op : @lib.Instruction,
) -> (@lib.Instruction, @lib.Instruction)? {
  match (rhs, op) {
    (@lib.I32Const(@lib.I32(-2147483648)), @lib.I32DivU) =>
      Some(
        (
          @lib.Instruction::i32_const(@lib.I32(31)),
          @lib.Instruction::i32_shr_u(),
        ),
      )
    (@lib.I32Const(@lib.I32(-2147483648)), @lib.I32Mul) =>
      Some(
        (@lib.Instruction::i32_const(@lib.I32(31)), @lib.Instruction::i32_shl()),
      )
    (@lib.I32Const(@lib.I32(-2147483648)), @lib.I32RemU) =>
      Some(
        (
          @lib.Instruction::i32_const(@lib.I32(2147483647)),
          @lib.Instruction::i32_and(),
        ),
      )
    (@lib.I64Const(@lib.I64(-9223372036854775808L)), @lib.I64DivU) =>
      Some(
        (
          @lib.Instruction::i64_const(@lib.I64(63L)),
          @lib.Instruction::i64_shr_u(),
        ),
      )
    (@lib.I64Const(@lib.I64(-9223372036854775808L)), @lib.I64Mul) =>
      Some(
        (
          @lib.Instruction::i64_const(@lib.I64(63L)),
          @lib.Instruction::i64_shl(),
        ),
      )
    (@lib.I64Const(@lib.I64(-9223372036854775808L)), @lib.I64RemU) =>
      Some(
        (
          @lib.Instruction::i64_const(@lib.I64(9223372036854775807L)),
          @lib.Instruction::i64_and(),
        ),
      )
    _ => None
  }
}

///|
test "raw sign-bit matcher excludes zero and non-power bit patterns" {
  // These literals are outside this exact rule's domain. This does not limit
  // other division rules; replacing them with a fixed shift would be wrong.
  for value in [0, -2] {
    @debug.assert_eq(
      oi_sign_bit_raw_pair(
        @lib.Instruction::i32_const(@lib.I32(value)),
        @lib.Instruction::i32_div_u(),
      ),
      None,
    )
  }
  for value in [0L, -2L] {
    @debug.assert_eq(
      oi_sign_bit_raw_pair(
        @lib.Instruction::i64_const(@lib.I64(value)),
        @lib.Instruction::i64_div_u(),
      ),
      None,
    )
  }
}
