///|
test "local-subtyping command no-change parity removes unused signatures" {
  let input = @passes.pass_test_module_from_wat(
    "(module (type (func)) (type (func)) (type (func)) (func (type 0)))",
  )
  let output = optimize_module_with_pass_flags(
    input,
    ["local-subtyping"],
    OptimizeOptions::new(),
  ).unwrap()
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 1)
}
