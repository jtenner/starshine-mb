///|
test "command code-folding retains typed outer bottom after branch-table exit" {
  let output = cmd_deep_audit_run(
    "(module (func (param i32) (result i32) block (result i32) block i32.const 243 local.get 0 br_table 1 1 unreachable end unreachable end))",
    "code-folding",
  )
  @validate.validate_module(decode_module_bytes(encode_module_bytes(output))).unwrap()
  let outer = match cmd_deep_audit_body(output) {
    [@lib.Block(_, @lib.Expr(body))] => body
    _ => fail("expected result block")
  }
  assert_eq(outer.last(), Some(@lib.Instruction::unreachable_()))
  assert_eq(
    cmd_deep_audit_count(outer, fn(instr) { instr is @lib.BrTable(_, _) }),
    1,
  )
}
