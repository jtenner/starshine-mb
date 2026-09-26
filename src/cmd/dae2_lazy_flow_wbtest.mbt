///|
test "command dae2 keeps the observed argument when pruning a sibling argument" {
  let output = cmd_deep_audit_run(
    "(module (func $helper (param i32 i32) (result i32) local.get 1) (func (export \"run\") (param i32) (result i32) i32.const 8 local.get 0 call $helper))",
    "dae2",
  )
  assert_true(@validate.validate_module(output) is Ok(_))
  assert_eq(cmd_deep_audit_body(output, index=0), [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
  assert_eq(cmd_deep_audit_body(output, index=1), [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ])
}
