///|
test "command inlining refreshes body facts after helper substitution" {
  let source =
    #|(module
    #| (func $a (result i32) i32.const 7)
    #| (func $b (result i32) call $a)
    #| (func (export "run") (result i32) call $b))
  let output = cmd_deep_audit_run(source, "inlining")
  @validate.validate_module(output).unwrap()
  assert_eq(output.code_sec.unwrap().0.length(), 1)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(body, [@lib.Instruction::i32_const(@lib.I32(7))])
}
