///|
test "command inlining variants preserve default values for multiple callee locals" {
  for pass in ["inlining", "inlining-optimizing"] {
    let output = cmd_deep_audit_run(
      "(module (func $read (result i32) (local i32 i32) local.get 0 local.get 1 i32.add) (func (export \"run\") (result i32) call $read))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    assert_eq(output.code_sec.unwrap().0.length(), 1)
    let body = cmd_deep_audit_body(output)
    assert_eq(
      cmd_deep_audit_count(body, fn(instr) { instr is @lib.Call(_) }),
      0,
    )
    if pass == "inlining" {
      assert_eq(
        cmd_deep_audit_count(body, fn(instr) {
          instr is @lib.I32Const(@lib.I32(0))
        }),
        2,
      )
    } else {
      assert_eq(body, [@lib.Instruction::i32_const(0)])
    }
  }
}

///|
test "command inline-main initializes copied locals and retains the named helper" {
  let output = cmd_deep_audit_run(
    "(module (func $__original_main (result i32) (local i32 i32) local.get 0 local.get 1 i32.add) (func $main (export \"main\") (result i32) call $__original_main))",
    "inline-main",
  )
  @validate.validate_module(output).unwrap()
  assert_eq(output.code_sec.unwrap().0.length(), 2)
  let body = cmd_deep_audit_body(output, index=1)
  assert_eq(cmd_deep_audit_count(body, fn(instr) { instr is @lib.Call(_) }), 0)
  assert_eq(
    cmd_deep_audit_count(body, fn(instr) { instr is @lib.I32Const(@lib.I32(0)) }),
    2,
  )
}
