///|
test "command DAE2 write proofs preserve exported mutable parameter results" {
  for pass in ["dae2", "dae2-optimizing"] {
    let wat = "(module (func (export \"run\") (param i32 i32 i32) (result i32) local.get 1 i32.const 1 i32.add local.set 1 local.get 1))"
    let input = @wast.wast_to_binary_module(wat).unwrap()
    let output = cmd_deep_audit_run(wat, pass)
    @validate.validate_module(output).unwrap()
    let body = cmd_deep_audit_body(output)
    assert_true(body.contains(@lib.Instruction::i32_add()))
    assert_true(
      body.contains(@lib.Instruction::local_get(@lib.LocalIdx::new(1U))),
    )
    assert_eq(output.func_sec, input.func_sec)
    assert_eq(output.type_sec, input.type_sec)
  }
}
