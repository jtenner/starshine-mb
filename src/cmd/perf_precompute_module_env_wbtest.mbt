///|
test "command precompute variants flatten branchless result blocks and retain parameter blocks" {
  for name in ["precompute", "precompute-propagate"] {
    let output = cmd_deep_audit_run(
      "(module (type $io (func (param i32) (result i32))) (func (export \"plain\") (param i32) (result i32) block (result i32) local.get 0 end) (func (export \"parameter\") (param i32) (result i32) local.get 0 block (type $io) end))",
      name,
    )
    @validate.validate_module(output).unwrap()
    let funcs = output.code_sec.unwrap().0
    let @lib.Func(_, @lib.Expr(first_body)) = funcs[0]
    let @lib.Func(_, @lib.Expr(second_body)) = funcs[1]
    assert_eq(first_body, [@lib.Instruction::local_get(@lib.LocalIdx::new(0U))])
    assert_true(second_body[1] is @lib.Block(@lib.TypeIdxBlockType(_), _))
  }
}
