///|
test "command optimizing DAE preserves observed calls from parameter-free callers" {
  let output = cmd_deep_audit_run(
    "(module (import \"env\" \"value\" (func $value (result i32))) (func $helper (param i32 i32) (result i32) local.get 1) (func (export \"run\") (result i32) (local i32) call $value local.set 0 i32.const 8 local.get 0 call $helper))",
    "dae-optimizing",
  )
  assert_true(@validate.validate_module(output) is Ok(_))
  assert_eq(cmd_deep_audit_body(output, index=0), [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
  assert_eq(cmd_deep_audit_body(output, index=1), [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
  ])
}
