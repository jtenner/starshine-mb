///|
test "command DAE modes prune beside unchanged owned NaN globals" {
  for pass in ["dae", "dae-optimizing"] {
    let output = cmd_deep_audit_run(
      "(module (global (export \"nan\") f32 (f32.const nan)) (func $h (param i32 i32) (result i32) local.get 1) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 call $h))",
      pass,
    )
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
    let @lib.Global(_, @lib.Expr(body)) = output.global_sec.unwrap().0[0]
    match body {
      [@lib.F32Const(@lib.F32(value))] => assert_true(value.is_nan())
      _ => fail("expected the unchanged NaN global initializer")
    }
  }
}
