///|
test "flatten preserves tee initialization before subsequent cast reads" {
  let input = @binary.decode_module(
    b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x0e\x03\x5f\x01\x7f\x00\x60\x01\x6d\x01\x7f\x60\x00\x01\x7f\x03\x03\x02\x01\x02\x07\x07\x01\x03\x72\x75\x6e\x00\x01\x0a\x25\x02\x19\x01\x01\x6d\x20\x00\x22\x01\xfb\x16\x00\xfb\x02\x00\x00\x20\x01\xfb\x16\x00\xfb\x02\x00\x00\x6a\x0b\x09\x00\x41\x15\xfb\x00\x00\x10\x00\x0b\x00\x15\x04\x6e\x61\x6d\x65\x01\x06\x01\x00\x03\x73\x75\x6d\x04\x06\x01\x00\x03\x62\x6f\x78",
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["flatten"]).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  // No use of local 1 may precede the write split out from its original tee.
  @debug.assert_eq(body[0], @lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  @debug.assert_eq(body[1], @lib.Instruction::local_set(@lib.LocalIdx::new(1U)))
  assert_true(output.code_sec != input.code_sec)
  ignore(@validate.validate_module(output).unwrap())
}
