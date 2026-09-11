///|
test "coalesce-locals CFG includes locals added for conditional array operands" {
  let input = @binary.decode_module(
    b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x12\x03\x5f\x03\x6d\x01\x7f\x01\x7f\x01\x5e\x6d\x01\x60\x02\x64\x00\x7f\x00\x03\x02\x01\x02\x0a\x46\x01\x44\x02\x01\x64\x00\x06\x7f\x20\x00\x22\x02\xfb\x02\x00\x01\x20\x02\xfb\x02\x00\x02\x49\x1a\x03\x40\x41\x00\x04\x40\x20\x02\xfb\x02\x00\x00\xfb\x16\x01\x41\x00\x20\x02\xfb\x02\x00\x00\xfb\x16\x01\x41\x00\x41\x00\x04\x7f\x20\x04\x05\x20\x07\x0b\xfb\x11\x01\x01\x00\x0b\x0b\x0b",
  ).unwrap()
  // The raw and lifted access counts happen to match, but array.copy's
  // conditional operand adds capture locals beyond the original local table.
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "coalesce-locals",
  ]).unwrap()
  ignore(@validate.validate_module(output).unwrap())
}

///|
fn cl_dew_execute_reduced_i32(
  func : @lib.Func,
  params : Array[Int],
) -> Int raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = func
  let locals = params.copy()
  for _ in 0..<body_locals.length() {
    locals.push(0)
  }
  let stack : Array[Int] = []
  fn execute(instrs : Array[@lib.Instruction]) -> Bool raise {
    for instr in instrs {
      match instr {
        @lib.Nop => ()
        @lib.I32Const(@lib.I32(value)) => stack.push(value)
        @lib.LocalGet(@lib.LocalIdx(idx)) =>
          stack.push(locals[idx.reinterpret_as_int()])
        @lib.LocalSet(@lib.LocalIdx(idx)) =>
          locals[idx.reinterpret_as_int()] = stack.pop().unwrap()
        @lib.LocalTee(@lib.LocalIdx(idx)) =>
          locals[idx.reinterpret_as_int()] = stack[stack.length() - 1]
        @lib.Drop => ignore(stack.pop().unwrap())
        @lib.I32LtU => {
          let rhs = stack.pop().unwrap()
          let lhs = stack.pop().unwrap()
          stack.push(if lhs < rhs { 1 } else { 0 })
        }
        @lib.If(_, then_body, else_body) => {
          let condition = stack.pop().unwrap()
          if execute(if condition != 0 { then_body } else { else_body.or([]) }) {
            return true
          }
        }
        @lib.I32Add => {
          let rhs = stack.pop().unwrap()
          let lhs = stack.pop().unwrap()
          stack.push(lhs + rhs)
        }
        @lib.Return => return true
        @lib.Block(_, @lib.Expr(nested)) | @lib.Loop(_, @lib.Expr(nested)) =>
          if execute(nested) {
            return true
          }
        _ => fail("unexpected coalesce instruction: \{instr}")
      }
    }
    false
  }
  ignore(execute(body))
  assert_eq(stack.length(), 1)
  stack[0]
}

///|
test "coalesce-locals CFG preserves stack captures when coloring their body" {
  let input = @binary.decode_module(
    b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x05\x01\x60\x00\x01\x7f\x03\x02\x01\x00\x07\x07\x01\x03\x72\x75\x6e\x00\x00\x0a\x1e\x01\x1c\x01\x02\x7f\x41\x15\x21\x00\x03\x40\x20\x00\x22\x01\x20\x01\x6a\x0f\x41\x00\x21\x00\x41\x00\x21\x00\x0b\x00\x0b",
  ).unwrap()
  let original = input.code_sec.unwrap().0[0]
  let rewrite = cl_rewrite_loop_func_cfg(
    input,
    @lib.FuncIdx::new(0U),
    @ir.hot_module_context_from_module(input),
    original,
    [],
  )
  ignore(
    @validate.validate_module(
      input.with_code_sec(@lib.CodeSec::new([rewrite.func])),
    ).unwrap(),
  )
  @debug.assert_eq(cl_dew_execute_reduced_i32(original, []), 42)
  @debug.assert_eq(cl_dew_execute_reduced_i32(rewrite.func, []), 42)
}

///|
test "coalesce-locals CFG keeps default entry values separate from parameters" {
  let input = @binary.decode_module(
    b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x06\x01\x60\x01\x7f\x01\x7f\x03\x02\x01\x00\x07\x07\x01\x03\x72\x75\x6e\x00\x00\x0a\x0d\x01\x0b\x01\x02\x7f\x03\x40\x20\x01\x0f\x0b\x00\x0b",
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "coalesce-locals",
  ]).unwrap()
  ignore(@validate.validate_module(output).unwrap())
  for module_ in [input, output] {
    @debug.assert_eq(
      cl_dew_execute_reduced_i32(module_.code_sec.unwrap().0[0], [9]),
      0,
    )
  }
}

///|
test "coalesce-locals CFG preserves branch reads inside a local.set operand" {
  let input = @binary.decode_module(
    b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x06\x01\x60\x01\x7f\x01\x7f\x03\x02\x01\x00\x07\x07\x01\x03\x72\x75\x6e\x00\x00\x0a\x26\x01\x24\x01\x04\x7f\x03\x40\x20\x00\x41\x05\x21\x02\x22\x01\x20\x02\x49\x04\x7f\x41\x09\x21\x00\x20\x01\x05\x20\x02\x0b\x21\x03\x20\x03\x0f\x0b\x00\x0b",
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "coalesce-locals",
  ]).unwrap()
  ignore(@validate.validate_module(output).unwrap())
  for module_ in [input, output] {
    @debug.assert_eq(
      cl_dew_execute_reduced_i32(module_.code_sec.unwrap().0[0], [3]),
      3,
    )
  }
}
