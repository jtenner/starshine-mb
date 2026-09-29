///|
test "command DAE modes prune unused arguments beside a preserved NaN payload" {
  let wat = "(module (func $h (param i32 i32) (result i32) local.get 1) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 call $h) (func (export \"nan\") (result f32) f32.const nan:0x400001))"
  let original = @wast.wast_to_binary_module(wat, filename="audit.wat").unwrap()
  let original_bits = match cmd_deep_audit_body(original, index=2) {
    [@lib.F32Const(@lib.F32(value))] => value.reinterpret_as_int()
    _ => fail("expected the original NaN instruction")
  }
  for pass in ["dae", "dae-optimizing"] {
    let output = cmd_deep_audit_run(wat, pass)
    @validate.validate_module(output).unwrap()
    assert_eq(cmd_deep_audit_body(output, index=1), [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    ])
    assert_eq(
      @validate.Env::new()
      .with_module(output)
      .get_functype_by_funcidx(@lib.FuncIdx::new(0U)),
      Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
    )
    match cmd_deep_audit_body(output, index=2) {
      [@lib.F32Const(@lib.F32(value))] =>
        assert_eq(value.reinterpret_as_int(), original_bits)
      _ => fail("expected the unchanged NaN payload instruction")
    }
  }
}
