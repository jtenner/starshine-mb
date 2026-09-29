///|
test "command SL modes retain local dependencies while cleaning repeated tee carriers" {
  let wat = [
    "(module (func (export \"run\") (param i32) (result i32) (local i32) local.get 0",
  ]
  for _ in 0..<16 {
    wat.push("i32.const 7 i32.add local.tee 1 drop local.get 1")
  }
  wat.push("))")
  let input = @wast.wast_to_binary_module(wat.join(" ")).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for
    pass in [
      "simplify-locals", "simplify-locals-nonesting", "simplify-locals-notee", "simplify-locals-nostructure",
      "simplify-locals-notee-nostructure",
    ] {
    let output = cmd_deep_audit_run_module(input, pass)
    @validate.validate_module(output).unwrap()
    assert_eq(
      @validate.Env::new()
      .with_module(output)
      .get_functype_by_funcidx(@lib.FuncIdx::new(0U)),
      Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
    )
    assert_true(
      cmd_deep_audit_body(output, index=0).any(fn(instr) {
        instr is @lib.LocalGet(@lib.LocalIdx(0U))
      }),
    )
    assert_true(
      cmd_deep_audit_body(output, index=0).any(fn(instr) {
        instr is @lib.I32Add
      }),
    )
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
