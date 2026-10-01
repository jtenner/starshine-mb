///|
test "command DAE2 optimizing sinks constant assignment before preserving releases" {
  let output = cmd_deep_audit_run(
    "(module (import \"env\" \"combine\" (func $combine (param i32 i32))) (import \"env\" \"release\" (func $release (param i32))) (func (export \"run\") (param i32 i32 i32) (result i32) (local i32 i32) block (result i32) local.get 1 end local.set 3 i32.const 5 local.set 1 local.get 0 local.get 3 i32.ge_s local.set 4 local.get 0 local.get 1 call $combine local.get 2 if local.get 0 call $release local.get 1 call $release end local.get 4))",
    "dae2-optimizing",
  )
  @validate.validate_module(output).unwrap()
  let body = cmd_deep_audit_body(output)
  assert_eq(body[0], @lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  assert_eq(body[1], @lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
  assert_eq(body[2], @lib.Instruction::i32_ge_s())
  assert_true(
    body.contains(@lib.Instruction::local_tee(@lib.LocalIdx::new(1U))),
  )
}
