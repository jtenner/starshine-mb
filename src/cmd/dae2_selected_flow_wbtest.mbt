///|
test "command DAE2 variants preserve resolved selectors and conditional entry dependencies" {
  for pass in ["dae2", "dae2-optimizing"] {
    let output = cmd_deep_audit_run(
      "(module (func $h (param i32 i32 i32) (result i32) local.get 1 i32.const 1 i32.add local.set 1 local.get 1 if i32.const 7 local.set 0 end local.get 1 if i32.const 9 local.set 0 end local.get 0) (func (export \"run\") (param i32 i32) (result i32) local.get 0 local.get 1 i32.const 99 call $h))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    assert_eq(
      @validate.Env::new()
      .with_module(output)
      .get_functype_by_funcidx(@lib.FuncIdx::new(0U)),
      Some(
        @lib.FuncType::new([@lib.ValType::i32(), @lib.ValType::i32()], [
          @lib.ValType::i32(),
        ]),
      ),
    )
    assert_eq(cmd_deep_audit_body(output, index=1), [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    ])
  }
}
