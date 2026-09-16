///|
test "dae2 command signature encoding interns unchanged simple signatures" {
  let input = @passes.pass_test_module_from_wat(
    "(module (type (func)) (type (func)) (func (export \"a\") (type 0)) (func (export \"b\") (type 1)))",
  )
  let output = optimize_module_with_pass_flags(
    input,
    ["dae2"],
    OptimizeOptions::new(),
  ).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 1)
  @debug.assert_eq(output.export_sec, input.export_sec)
}

///|
test "dae2 command signature encoding interns rewritten simple signatures" {
  let input = @passes.pass_test_module_from_wat(
    "(module (type (func)) (type (func)) (type (func (param i32))) (func (type 2) (param i32) nop) (func (export \"run\") (type 0) i32.const 7 call 0) (func (export \"other\") (type 1) nop))",
  )
  let output = optimize_module_with_pass_flags(
    input,
    ["dae2"],
    OptimizeOptions::new(),
  ).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 1)
  @debug.assert_eq(output.export_sec, input.export_sec)
}

///|
test "dae2-optimizing command signature encoding interns unchanged simple signatures" {
  let input = @passes.pass_test_module_from_wat(
    "(module (type (func)) (type (func)) (func (export \"a\") (type 0)) (func (export \"b\") (type 1)))",
  )
  let output = optimize_module_with_pass_flags(
    input,
    ["dae2-optimizing"],
    OptimizeOptions::new(),
  ).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 1)
  @debug.assert_eq(output.export_sec, input.export_sec)
}

///|
test "dae2-optimizing command signature encoding interns rewritten simple signatures" {
  let input = @passes.pass_test_module_from_wat(
    "(module (type (func)) (type (func)) (type (func (param i32))) (func (type 2) (param i32) nop) (func (export \"run\") (type 0) i32.const 7 call 0) (func (export \"other\") (type 1) nop))",
  )
  let output = optimize_module_with_pass_flags(
    input,
    ["dae2-optimizing"],
    OptimizeOptions::new(),
  ).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 1)
  @debug.assert_eq(output.export_sec, input.export_sec)
}
