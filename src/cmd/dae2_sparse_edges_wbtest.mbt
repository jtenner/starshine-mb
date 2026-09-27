///|
test "command DAE2 variants preserve observed dependencies while removing dead parameters" {
  for pass in ["dae2", "dae2-optimizing"] {
    let output = cmd_deep_audit_run(
      "(module (func $helper (param i32 i32) (result i32) local.get 1) (func (export \"run\") (param i32) (result i32) i32.const 7 local.get 0 call $helper))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    let signature = @validate.empty_env()
      .with_module(output)
      .resolve_functype(output.func_sec.unwrap().0[0])
      .unwrap()
    let @lib.FuncType(params, results) = signature
    assert_eq(params, [@lib.ValType::i32()])
    assert_eq(results, [@lib.ValType::i32()])
    assert_eq(cmd_deep_audit_body(output), [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    ])
    assert_eq(
      cmd_deep_audit_count(cmd_deep_audit_body(output, index=1), fn(instr) {
        instr is @lib.I32Const(@lib.I32(7))
      }),
      0,
    )
  }
}
