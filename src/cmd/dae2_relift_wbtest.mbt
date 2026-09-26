///|
test "command dae2 preserves an unchanged export while pruning a sibling signature" {
  let output = cmd_deep_audit_run(
    "(module (func $helper (param i32) (result i32) i32.const 7) (func (export \"run\") (result i32) i32.const 8 call $helper) (func (export \"keep\") (result i32) i32.const 9))",
    "dae2",
  )
  assert_true(@validate.validate_module(output) is Ok(_))
  assert_eq(cmd_deep_audit_body(output, index=2), [
    @lib.Instruction::i32_const(@lib.I32(9)),
  ])
  assert_eq(cmd_deep_audit_body(output, index=1), [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ])
}
