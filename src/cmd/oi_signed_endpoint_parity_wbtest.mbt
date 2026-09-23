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
