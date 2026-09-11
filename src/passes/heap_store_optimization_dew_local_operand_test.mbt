///|
test "heap-store-optimization keeps allocation operand reads before local overwrites" {
  let input = @binary.decode_module(
    b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x09\x02\x5f\x01\x7f\x00\x60\x00\x01\x7f\x03\x02\x01\x01\x07\x07\x01\x03\x72\x75\x6e\x00\x00\x0a\x1e\x01\x1c\x02\x01\x7f\x01\x64\x00\x41\x2a\x21\x00\x20\x00\xfb\x00\x00\x21\x01\x41\x07\x21\x00\x20\x01\xfb\x02\x00\x00\x0b\x00\x0d\x04\x6e\x61\x6d\x65\x04\x06\x01\x00\x03\x62\x6f\x78",
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "heap-store-optimization",
  ]).unwrap()
  ignore(@validate.validate_module(output).unwrap())
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  let mut overwrites = 0
  let mut allocations = 0
  for instr in body {
    match instr {
      @lib.LocalSet(@lib.LocalIdx(0U)) => overwrites += 1
      @lib.StructNew(_) => {
        @debug.assert_eq(overwrites, 1)
        allocations += 1
      }
      _ => ()
    }
  }
  @debug.assert_eq(allocations, 1)
  @debug.assert_eq(overwrites, 2)
}
