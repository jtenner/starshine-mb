///|
test "command future-read cleanup preserves the exported result across many distinct captures" {
  let width = 32
  let locals = Array::make(width, "i32").join(" ")
  let captures = Array::makei(width, fn(local) {
    "i32.const 7 local.set \{local + 1} local.get \{local + 1} drop"
  }).join(" ")
  for pass in ["dae2-optimizing", "simplify-locals"] {
    let output = cmd_deep_audit_run(
      "(module (func (export \"run\") (param i32) (result i32) (local \{locals}) \{captures} local.get 0))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    let body = cmd_deep_audit_body(output)
    assert_eq(
      body.last(),
      Some(@lib.Instruction::local_get(@lib.LocalIdx::new(0U))),
    )
    for instr in body {
      match instr {
        @lib.LocalSet(_) | @lib.LocalTee(_) => fail("dead capture retained")
        _ => ()
      }
    }
    if pass == "dae2-optimizing" {
      assert_eq(body.length(), 1)
    }
  }
}
