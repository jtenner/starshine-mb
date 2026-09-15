///|
test "local-subtyping no-change parity removes unused signatures" {
  let input = pass_test_module_from_wat(
    "(module (type (func)) (type (func)) (type (func)) (type (func)) (func (type 0) (local i32 (ref null 0) anyref)))",
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "local-subtyping",
  ]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 1)
  @debug.assert_eq(output.code_sec, input.code_sec)
}
