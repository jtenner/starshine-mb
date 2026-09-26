///|
test "command dae2 prunes an unused argument while retaining a cross-block local write" {
  let output = cmd_deep_audit_run(
    "(module (func $helper (param i32 i32) (result i32) (local i32) local.get 0 local.set 2 block nop end local.get 2) (func (export \"run\") (result i32) i32.const 7 i32.const 9 call $helper))",
    "dae2",
  )
  assert_true(@validate.validate_module(output) is Ok(_))
  assert_eq(cmd_deep_audit_body(output, index=1), [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ])
}
