///|
test "global-refining command encoding parity removes plain signature overhead" {
  let input = @passes.pass_test_module_from_wat(
    "(module (type (func)) (type (func)) (type (func)) (func (type 0) nop))",
  )
  let output = optimize_module_with_pass_flags(
    input,
    ["global-refining"],
    OptimizeOptions::new(),
  ).unwrap()
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 1)
}
