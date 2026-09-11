///|
test "simplify-locals preserves a local write before an outer block exit" {
  let input = @binary.decode_module(
    b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x05\x01\x60\x00\x01\x7f\x03\x02\x01\x00\x07\x07\x01\x03\x72\x75\x6e\x00\x00\x0a\x14\x01\x12\x01\x01\x7f\x02\x40\x02\x40\x41\x1f\x21\x00\x0c\x01\x0b\x0b\x20\x00\x0b\x00\x16\x04\x6e\x61\x6d\x65\x03\x0f\x01\x00\x02\x00\x03\x6f\x75\x74\x01\x05\x69\x6e\x6e\x65\x72",
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "simplify-locals",
  ]).unwrap()
  ignore(@validate.validate_module(output).unwrap())
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  // Execute structured branches with their actual label depths. The old
  // rewrite moved the write behind the exiting branch and returned zero.
  let stack : Array[Int] = []
  let mut value = 0
  fn execute(instrs : Array[@lib.Instruction]) -> Int? raise {
    for instr in instrs {
      match instr {
        @lib.Nop => ()
        @lib.I32Const(@lib.I32(n)) => stack.push(n)
        @lib.LocalGet(@lib.LocalIdx(0U)) => stack.push(value)
        @lib.LocalSet(@lib.LocalIdx(0U)) => value = stack.pop().unwrap()
        @lib.LocalTee(@lib.LocalIdx(0U)) => value = stack[stack.length() - 1]
        @lib.Br(@lib.LabelIdx(depth)) => return Some(depth.reinterpret_as_int())
        @lib.Block(_, @lib.Expr(nested)) =>
          match execute(nested) {
            Some(depth) if depth > 0 => return Some(depth - 1)
            _ => ()
          }
        _ => fail("unexpected outer-exit instruction: \{instr}")
      }
    }
    None
  }
  @debug.assert_eq(execute(body), None)
  @debug.assert_eq(stack, [31])
}
