///|
test "optimize-instructions command matches v132 signed maximum comparison" {
  let output = cmd_deep_audit_run(
    "(module (func (param i32) (result i32) local.get 0 i32.const 2147483647 i32.lt_s))",
    "optimize-instructions",
  )
  @debug.assert_eq(cmd_deep_audit_body(output), [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(2147483647)),
    @lib.Instruction::i32_ne(),
  ])
}

///|
test "optimize-instructions command matches v132 i64 signed maximum comparison" {
  let output = cmd_deep_audit_run(
    "(module (func (param i64) (result i32) local.get 0 i64.const 9223372036854775807 i64.lt_s))",
    "optimize-instructions",
  )
  @debug.assert_eq(cmd_deep_audit_body(output), [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i64_const(@lib.I64(9223372036854775807L)),
    @lib.Instruction::i64_ne(),
  ])
}

///|
test "optimize-instructions command matches v132 signed minimum comparisons" {
  let i32_output = cmd_deep_audit_run(
    "(module (func (param i32) (result i32) local.get 0 i32.const -2147483648 i32.gt_s))",
    "optimize-instructions",
  )
  @debug.assert_eq(cmd_deep_audit_body(i32_output), [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(-2147483648)),
    @lib.Instruction::i32_ne(),
  ])

  let i64_output = cmd_deep_audit_run(
    "(module (func (param i64) (result i32) local.get 0 i64.const -9223372036854775808 i64.gt_s))",
    "optimize-instructions",
  )
  @debug.assert_eq(cmd_deep_audit_body(i64_output), [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i64_const(@lib.I64(-9223372036854775808L)),
    @lib.Instruction::i64_ne(),
  ])
}
