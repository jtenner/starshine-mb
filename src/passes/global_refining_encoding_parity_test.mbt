///|
test "global-refining encoding parity groups numeric locals and removes dead signatures" {
  let input = pass_test_module_from_wat(
    "(module (type (func (result i64))) (type (func (result i64))) (type (func (result i64))) (func (export \"run\") (type 0) (local i64 i32 i64) i64.const 17 local.set 2 local.get 2))",
  )
  let output = global_refining_run_module_pass(input)
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 1)
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(locals.runs().length(), 2)
  @debug.assert_eq(body, [
    @lib.Instruction::i64_const(@lib.I64(17L)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ])
  assert_true(
    @binary.encode_module(output).unwrap().length() <
    @binary.encode_module(input).unwrap().length(),
  )
}
