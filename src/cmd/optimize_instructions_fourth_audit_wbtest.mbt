///|
test "fourth audit command i31 high bit 0 -2147483648" {
  let output = cmd_deep_audit_run(
    "(module (func (result i32) i32.const 0 ref.i31 i32.const -2147483648 ref.i31 ref.eq))",
    "optimize-instructions",
  )
  @debug.assert_eq(cmd_deep_audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "fourth audit command i31 high bit 2147483647 -1" {
  let output = cmd_deep_audit_run(
    "(module (func (result i32) i32.const 2147483647 ref.i31 i32.const -1 ref.i31 ref.eq))",
    "optimize-instructions",
  )
  @debug.assert_eq(cmd_deep_audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "fourth audit command i31 high bit 17 -2147483631" {
  let output = cmd_deep_audit_run(
    "(module (func (result i32) i32.const 17 ref.i31 i32.const -2147483631 ref.i31 ref.eq))",
    "optimize-instructions",
  )
  @debug.assert_eq(cmd_deep_audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "fourth audit command i31 high bit -2147483648 0" {
  let output = cmd_deep_audit_run(
    "(module (func (result i32) i32.const -2147483648 ref.i31 i32.const 0 ref.i31 ref.eq))",
    "optimize-instructions",
  )
  @debug.assert_eq(cmd_deep_audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "fourth audit command i31 high bit -1 2147483647" {
  let output = cmd_deep_audit_run(
    "(module (func (result i32) i32.const -1 ref.i31 i32.const 2147483647 ref.i31 ref.eq))",
    "optimize-instructions",
  )
  @debug.assert_eq(cmd_deep_audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}
