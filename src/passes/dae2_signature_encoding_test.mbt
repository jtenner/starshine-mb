///|
test "dae2 signature encoding interns unchanged simple signatures" {
  let input = pass_test_module_from_wat(
    "(module (type (func)) (type (func)) (func (export \"a\") (type 0)) (func (export \"b\") (type 1)))",
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["dae2"]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 1)
  @debug.assert_eq(output.export_sec, input.export_sec)
}

///|
test "dae2 signature encoding interns rewritten simple signatures" {
  let input = pass_test_module_from_wat(
    "(module (type (func)) (type (func)) (type (func (param i32))) (func (type 2) (param i32) nop) (func (export \"run\") (type 0) i32.const 7 call 0) (func (export \"other\") (type 1) nop))",
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["dae2"]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 1)
  @debug.assert_eq(output.export_sec, input.export_sec)
}

///|
test "dae2-optimizing signature encoding interns unchanged simple signatures" {
  let input = pass_test_module_from_wat(
    "(module (type (func)) (type (func)) (func (export \"a\") (type 0)) (func (export \"b\") (type 1)))",
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "dae2-optimizing",
  ]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 1)
  @debug.assert_eq(output.export_sec, input.export_sec)
}

///|
test "dae2-optimizing signature encoding interns rewritten simple signatures" {
  let input = pass_test_module_from_wat(
    "(module (type (func)) (type (func)) (type (func (param i32))) (func (type 2) (param i32) nop) (func (export \"run\") (type 0) i32.const 7 call 0) (func (export \"other\") (type 1) nop))",
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "dae2-optimizing",
  ]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 1)
  @debug.assert_eq(output.export_sec, input.export_sec)
}
