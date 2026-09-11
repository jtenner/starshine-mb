///|
test "simplify-locals preserves an aggregate operand computed before a local overwrite" {
  let input = @binary.decode_module(
    b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x0b\x02\x5f\x02\x7f\x00\x7f\x00\x60\x00\x01\x7f\x03\x02\x01\x01\x07\x07\x01\x03\x72\x75\x6e\x00\x00\x0a\x22\x01\x20\x02\x01\x7f\x01\x6d\x41\x04\x21\x00\x41\x01\x20\x00\xfb\x00\x00\x41\x00\x21\x00\x21\x01\x20\x01\xfb\x16\x00\xfb\x02\x00\x01\x0b\x00\x0e\x04\x6e\x61\x6d\x65\x04\x07\x01\x00\x04\x70\x61\x69\x72",
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "simplify-locals-nostructure",
  ]).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_true(
    body.contains(@lib.Instruction::i32_const(@lib.I32(4))),
    msg=body.to_string(),
  )
  assert_true(output.code_sec != input.code_sec)
  assert_false(
    @lib.module_uses_custom_descriptors(output),
    msg="ordinary GC cleanup must preserve the input feature set",
  )
  ignore(@validate.validate_module(output).unwrap())
}
