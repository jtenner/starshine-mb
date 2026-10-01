///|
test "command DAE2 optimizing preserves compound integer division and dependent captures" {
  let locals = Array::make(128, "i32").join(" ")
  let wat = "(module (func (export \"run\") (param i32 i32) (result i32) (local \{locals}) local.get 0 local.get 1 i32.div_s local.set 2 local.get 0 i32.const 1 i32.add local.set 3 local.get 2 local.get 3 i32.add))"
  for pass in ["dae2", "dae2-optimizing"] {
    let output = cmd_deep_audit_run(wat, pass)
    @validate.validate_module(output).unwrap()
    let body = cmd_deep_audit_body(output)
    assert_true(body.contains(@lib.Instruction::i32_div_s()))
    assert_true(body.contains(@lib.Instruction::i32_add()))
  }
}
