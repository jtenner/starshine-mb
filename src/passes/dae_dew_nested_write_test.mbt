///|
test "dae retains varying nested-write actuals while specializing constant arguments" {
  let input = @binary.decode_module(
    b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x0c\x02\x60\x02\x7f\x7f\x01\x7f\x60\x01\x7f\x01\x7f\x03\x03\x02\x00\x01\x07\x07\x01\x03\x72\x75\x6e\x00\x01\x0a\x24\x02\x07\x00\x20\x00\x20\x01\x6a\x0b\x1a\x01\x01\x7f\x41\x30\x21\x01\x20\x00\x04\x40\x20\x01\x41\x01\x6b\x21\x01\x0b\x20\x01\x41\x07\x10\x00\x0b\x00\x10\x04\x6e\x61\x6d\x65\x01\x09\x01\x00\x06\x63\x61\x6c\x6c\x65\x65",
  ).unwrap()
  for pass_name in ["dae", "dae-optimizing"] {
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass_name]).unwrap()
    let module_ctx = @ir.hot_module_context_from_module(output)
    let @lib.FuncType(params, _) = @ir.hot_module_resolve_func_type(
      module_ctx,
      @lib.FuncIdx::new(0U),
    ).unwrap()
    @debug.assert_eq(params, [@lib.ValType::i32()])
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    assert_true(
      body.contains(@lib.Instruction::local_get(@lib.LocalIdx::new(0U))),
      msg=body.to_string(),
    )
    assert_true(
      body.contains(@lib.Instruction::i32_const(@lib.I32(7))),
      msg=body.to_string(),
    )
  }
}
