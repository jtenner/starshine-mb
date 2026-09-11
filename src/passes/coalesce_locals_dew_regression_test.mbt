///|
test "coalesce-locals keeps branch-visible defaults separate from parameters" {
  let input = @binary.decode_module(
    b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x06\x01\x60\x01\x7f\x01\x7f\x03\x02\x01\x00\x07\x07\x01\x03\x72\x75\x6e\x00\x00\x0a\x24\x01\x22\x01\x01\x7f\x02\x40\x20\x00\x41\x01\x46\x04\x40\x41\x01\x21\x01\x0c\x01\x0b\x41\x01\x04\x40\x41\x00\x1a\x0c\x01\x0b\x00\x0b\x20\x01\x0b",
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "coalesce-locals",
  ]).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(
    body.last(),
    Some(@lib.Instruction::local_get(@lib.LocalIdx::new(1U))),
  )
  ignore(@validate.validate_module(output).unwrap())
}
