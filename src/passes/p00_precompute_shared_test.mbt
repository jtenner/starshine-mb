///|
test "precompute-propagate preserves shared branch payload and fallthrough drop" {
  let output = pass_test_run_pipeline(
    "(module (func (param i32) (result i32) (block $B (result i32) (drop (br_if $B (block (result i32) (i32.const 0)) (local.get 0))) (i32.const 1))))",
    ["precompute-propagate"],
  ).unwrap()
  @validate.validate_module(
    @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap(),
  ).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(audit_count(body, fn(instr) { instr is @lib.BrIf(_) }), 1)
  assert_eq(
    audit_count(body, fn(instr) { instr is @lib.I32Const(@lib.I32(1)) }),
    1,
  )
}
