///|
test "dae2 prunes mixed parameter types with one cleanup module environment" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $result (func (result i32)))
      #|  (func $left (param i32) (result i32)
      #|    block (type $result) i32.const 7 end)
      #|  (func $right (param i64) (result i32)
      #|    block (type $result) i32.const 9 end)
      #|  (func (export "run") (result i32)
      #|    i32.const 1 call $left
      #|    i64.const 2 call $right
      #|    i32.add))
    ),
  )
  let builds = [0]
  let output = dae2_run_module_pass(
    input,
    false,
    cleanup_module_env_builds=Some(builds),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let context = @ir.hot_module_context_from_module(output)
  for index in [0U, 1U, 2U] {
    match @ir.hot_module_resolve_func_type(context, @lib.FuncIdx::new(index)) {
      Some(@lib.FuncType(params, results)) => {
        assert_eq(params.length(), 0)
        assert_eq(results, [@lib.ValType::i32()])
      }
      None => fail("expected a surviving function signature")
    }
  }
  let @lib.CodeSec(funcs) = output.code_sec.unwrap()
  for index in [0, 1] {
    let @lib.Func(_, @lib.Expr(body)) = funcs[index]
    assert_eq(body, [
      @lib.Instruction::i32_const(@lib.I32(if index == 0 { 7 } else { 9 })),
    ])
  }
  let @lib.Func(_, @lib.Expr(main_body)) = funcs[2]
  assert_eq(main_body.filter(fn(instr) { instr is @lib.Call(_) }), [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
  ])
  assert_eq(main_body[main_body.length() - 1], @lib.Instruction::i32_add())
  assert_true(builds[0] <= 1, msg="cleanup environments built: \{builds[0]}")
}
