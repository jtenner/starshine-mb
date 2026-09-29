///|
test "command SSA keeps observers of successive writes on distinct versions" {
  let output = cmd_deep_audit_run(
    "(module (func (export \"run\") (param i32 i32) (result i32) (local i32) local.get 0 local.set 2 local.get 2 local.get 1 local.set 2 local.get 2 i32.sub))",
    "ssa-nomerge",
  )
  @validate.validate_module(output).unwrap()
  assert_eq(cmd_deep_audit_body(output), [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
    @lib.Instruction::i32_sub(),
  ])
}
