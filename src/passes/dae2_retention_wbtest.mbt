///|
fn dae2_retention_fixture(count : Int) -> @lib.Module {
  let wat : Array[String] = []
  wat.push("(module (type $sig (func (param i32) (result i32)))")
  for index in 0..<count {
    wat.push("(func $h\{index} (type $sig) i32.const \{index})")
    wat.push(
      "(func (export \"run\{index}\") (result i32) i32.const 8 call $h\{index})",
    )
  }
  wat.push(
    "(func (export \"keep\") (result i32) i32.const 3 block (type $sig) drop i32.const 9 br 0 end))",
  )
  pass_test_module_from_wat(wat.join(""))
}

///|
test "dae2 analysis benchmark input remains reusable across active rewrites" {
  let input = dae2_retention_fixture(3)
  let original = @binary.encode_module(input).unwrap()
  let output = dae2_run_module_pass(input, false).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), original)
  assert_true(@binary.encode_module(output).unwrap() != original)
  assert_eq(
    @binary.encode_module(dae2_run_module_pass(input, false).unwrap()).unwrap(),
    @binary.encode_module(output).unwrap(),
  )
}
