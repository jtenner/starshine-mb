///|
test "dispatcher RSE preserves many distinct reference locals" {
  let source = StringBuilder::new()
  source.write_string("(module (func (export \"run\") ")
  for _ in 0..<128 {
    source.write_string("(param eqref) ")
  }
  for local_id in 0..<128 {
    source.write_string("local.get \{local_id} drop ")
  }
  source.write_string("))")
  let input = @passes.pass_test_module_from_wat(source.to_string())
  let output = optimize_module_with_pass_flags(
    input,
    ["redundant-set-elimination"],
    OptimizeOptions::new(),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  @debug.assert_eq(output.code_sec, input.code_sec)
}
