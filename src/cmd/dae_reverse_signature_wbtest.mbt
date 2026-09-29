///|
test "command DAE modes materialize uniform actuals after unrelated heap types and imports" {
  for pass in ["dae", "dae-optimizing"] {
    let output = cmd_deep_audit_run(
      "(module (type $s (struct (field i32))) (type $sig (func (param i32) (result i32))) (import \"m\" \"value\" (func $v (result i32))) (func $h (type $sig) local.get 0 i32.const 1 i32.add) (func (export \"run\") (result i32) i32.const 7 call $h))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    assert_eq(
      @validate.Env::new()
      .with_module(output)
      .get_functype_by_funcidx(@lib.FuncIdx::new(1U)),
      Some(@lib.FuncType::new([], [@lib.ValType::i32()])),
    )
    assert_false(
      cmd_deep_audit_body(output, index=0).any(fn(instr) {
        instr is @lib.LocalGet(_)
      }),
    )
  }
}
