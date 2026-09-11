///|
test "simplify-locals searches nested blocks once when a copied local is read later" {
  let wat = "(module (func (param i32) (result i32) (local i32) local.get 0 local.set 1 " +
    "block ".repeat(24) +
    "nop " +
    "end ".repeat(24) +
    "local.get 1 local.get 1 i32.add))"
  let input = pass_test_module_from_wat(wat)
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "simplify-locals",
  ]).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_true(body.contains(@lib.Instruction::i32_add()), msg=body.to_string())
  assert_true(output.code_sec != input.code_sec)
  ignore(@validate.validate_module(output).unwrap())
}
