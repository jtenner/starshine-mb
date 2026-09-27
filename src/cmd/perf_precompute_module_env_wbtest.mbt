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

///|
test "command precompute propagation preserves a conditional local write and default source" {
  let output = cmd_deep_audit_run(
    "(module (func (export \"branch\") (param i32) (result i32) (local i32) local.get 0 if i32.const 7 local.set 1 end local.get 1))",
    "precompute-propagate",
  )
  @validate.validate_module(output).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(
    body.last().unwrap(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  )
  assert_true(body[1] is @lib.If(_, _, _))
}

///|
test "command precompute propagation converges on equal branch writes" {
  let output = cmd_deep_audit_run(
    "(module (func (export \"joined\") (param i32) (result i32) (local i32) local.get 0 if i32.const 7 local.set 1 else i32.const 7 local.set 1 end local.get 1))",
    "precompute-propagate",
  )
  @validate.validate_module(output).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(body.last().unwrap(), @lib.Instruction::i32_const(@lib.I32(7)))
}
