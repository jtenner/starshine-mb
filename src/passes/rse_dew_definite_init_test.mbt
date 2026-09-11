///|
test "rse keeps frame initialization while removing a later same-value tee" {
  let input = @binary.decode_module(
    b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x0c\x02\x5f\x01\x7f\x00\x60\x02\x64\x00\x7f\x01\x7f\x03\x02\x01\x01\x07\x07\x01\x03\x72\x75\x6e\x00\x00\x0a\x25\x01\x23\x01\x01\x64\x00\x20\x01\x04\x40\x20\x00\x21\x02\x05\x20\x00\x21\x02\x0b\x20\x00\x22\x02\x1a\x20\x00\x22\x02\x1a\x20\x02\xfb\x02\x00\x00\x0b\x00\x0d\x04\x6e\x61\x6d\x65\x04\x06\x01\x00\x03\x62\x6f\x78",
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "redundant-set-elimination",
  ]).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  let tees = body.filter(fn(instr) {
    instr == @lib.Instruction::local_tee(@lib.LocalIdx::new(2U))
  })
  @debug.assert_eq(tees.length(), 1)
  assert_true(output.code_sec != input.code_sec)
  ignore(@validate.validate_module(output).unwrap())
}
