///|
test "r1 review WAST output keeps bindings for named parameter reads" {
  let source = "(module (func (param $x i32) (result i32) local.get $x))"
  let input = @wast.wast_to_binary_module(source).unwrap()
  let ast = @wast.wast_to_module(source).unwrap()
  let text = @wast.module_to_wast(ast).unwrap()
  let output = match @wast.wast_to_binary_module(text) {
    Ok(output) => output
    Err(error) => fail("printed WAT must lower: \{error}")
  }
  assert_eq(output.code_sec, input.code_sec)
}

///|
test "r1-04 mixed parameter bindings survive explicit and inline type uses" {
  for
    source in [
      "(module (func (param i32) (param $x i32) (param i32 i32) (param $y i32) (result i32) local.get $x local.get 4 i32.add local.get $y i32.add))",
      "(module (type $t (func (param i32 i32) (result i32))) (func (type $t) (param i32) (param $x i32) (result i32) local.get $x))",
      "(module (type $t (func (param i32) (result i32))) (import \"m\" \"f\" (func (type $t) (param $x i32) (result i32))) (func (param $y i32) (result i32) local.get $y call 0))",
      "(module (type $t (func (param i32) (result i32))) (table 1 funcref) (func (param $x i32) (result i32) local.get $x i32.const 0 call_indirect (type $t) (param i32) (result i32)))",
      "(module (func (param $x i32) (result i32) local.get $x block (param i32) (result i32) end))",
    ] {
    let input = @wast.wast_to_binary_module(source).unwrap()
    let text = @wast.module_to_wast(@wast.wast_to_module(source).unwrap()).unwrap()
    let output = match @wast.wast_to_binary_module(text) {
      Ok(output) => output
      Err(error) => fail("printed WAT must lower: \{error}; \{text}")
    }
    assert_eq(output.code_sec, input.code_sec)
    assert_eq(output.type_sec, input.type_sec)
    assert_eq(output.import_sec, input.import_sec)
  }
}
