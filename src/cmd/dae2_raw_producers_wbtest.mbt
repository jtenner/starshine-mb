///|
test "command DAE2 modes keep mandatory load and allocation operands while pruning a dead argument" {
  for
    source in [
      "(module (memory 1) (func $h (param i32 i32) (result i32) local.get 0 i32.load) (func (export \"run\") (param i32) (result i32) local.get 0 i32.const 9 call $h))",
      "(module (type $s (struct (field i32))) (func $h (param i32 i32) (result i32) local.get 0 struct.new $s struct.get $s 0) (func (export \"run\") (param i32) (result i32) local.get 0 i32.const 9 call $h))",
    ] {
    for pass in ["dae2", "dae2-optimizing"] {
      let output = cmd_deep_audit_run(source, pass)
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
    }
  }
}
