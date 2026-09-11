///|
fn sl_dew_assert_reduced_i32_result(module_ : @lib.Module) -> Unit raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = module_.code_sec.unwrap().0[1]
  let locals = Array::make(body_locals.length(), 0)
  let stack : Array[Int] = []
  let mut calls = 0
  fn execute(instrs : Array[@lib.Instruction]) -> Int? raise {
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
        @lib.Call(@lib.FuncIdx(0U)) => {
          stack.push(21 + calls)
          calls += 1
        }
        @lib.I32Add => {
          let rhs = stack.pop().unwrap()
          let lhs = stack.pop().unwrap()
          stack.push(lhs + rhs)
        }
        @lib.I32Sub => {
          let rhs = stack.pop().unwrap()
          let lhs = stack.pop().unwrap()
          stack.push(lhs - rhs)
        }
        @lib.I32Mul => {
          let rhs = stack.pop().unwrap()
          let lhs = stack.pop().unwrap()
          stack.push(lhs * rhs)
        }
        @lib.BrTable(labels, fallback) => {
          let index = stack.pop().unwrap()
          let @lib.LabelIdx(depth) = if index >= 0 && index < labels.length() {
            labels[index]
          } else {
            fallback
          }
          return Some(depth.reinterpret_as_int())
        }
        @lib.BrIf(@lib.LabelIdx(depth)) =>
          if stack.pop().unwrap() != 0 {
            return Some(depth.reinterpret_as_int())
          }
        @lib.Loop(_, @lib.Expr(nested)) => {
          let mut iterations = 0
          while true {
            iterations += 1
            if iterations > 8 {
              fail("reduced loop exceeded eight iterations")
            }
            match execute(nested) {
              Some(-1) => return Some(-1)
              Some(0) => continue
              Some(depth) => return Some(depth - 1)
              None => break
            }
          }
        }
        @lib.Return => return Some(-1)
        @lib.Block(_, @lib.Expr(nested)) =>
          match execute(nested) {
            Some(-1) => return Some(-1)
            Some(depth) if depth > 0 => return Some(depth - 1)
            _ => ()
          }
        @lib.If(_, then_body, else_body) => {
          let condition = stack.pop().unwrap()
          let nested = if condition != 0 { then_body } else { else_body.or([]) }
          match execute(nested) {
            Some(-1) => return Some(-1)
            Some(depth) if depth > 0 => return Some(depth - 1)
            _ => ()
          }
        }
        _ => fail("unexpected branch-table instruction: \{instr}")
      }
    }
    None
  }
  ignore(execute(body))
  @debug.assert_eq(stack, [42])
  @debug.assert_eq(calls, 1)
}

///|
test "simplify-locals preserves a value read after an inner branch table" {
  let input = @binary.decode_module(
    b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x05\x01\x60\x00\x01\x7f\x03\x03\x02\x00\x00\x05\x03\x01\x00\x01\x07\x07\x01\x03\x72\x75\x6e\x00\x01\x0a\x2f\x02\x04\x00\x41\x15\x0b\x28\x01\x08\x7f\x41\x01\x22\x02\x04\x40\x10\x00\x21\x01\x02\x40\x02\x40\x20\x01\x41\x14\x6b\x0e\x02\x01\x00\x01\x0b\x20\x01\x41\x02\x6c\x0f\x0b\x00\x0b\x41\x00\x0b\x0b\x0a\x01\x00\x41\x00\x0b\x04\x15\x00\x00\x00\x00\x11\x04\x6e\x61\x6d\x65\x01\x0a\x01\x00\x07\x70\x72\x6f\x64\x75\x63\x65",
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "simplify-locals",
  ]).unwrap()
  ignore(@validate.validate_module(output).unwrap())
  // A call returns 21 before the nested blocks. Its value selects the inner
  // br_table exit, and a second read after that exit must still return 21.
  for module_ in [input, output] {
    sl_dew_assert_reduced_i32_result(module_)
  }
}

///|
test "simplify-locals keeps a call before a repeated loop read" {
  let input = @binary.decode_module(
    b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x05\x01\x60\x00\x01\x7f\x03\x03\x02\x00\x00\x06\x06\x01\x7f\x01\x41\x15\x0b\x07\x07\x01\x03\x72\x75\x6e\x00\x01\x0a\x32\x02\x0b\x00\x23\x00\x23\x00\x41\x01\x6a\x24\x00\x0b\x24\x01\x08\x7f\x41\x02\x22\x02\x04\x40\x10\x00\x21\x01\x03\x40\x20\x01\x20\x00\x6a\x21\x00\x20\x02\x41\x01\x6b\x22\x02\x0d\x00\x0b\x0b\x20\x00\x0b\x00\x1b\x04\x6e\x61\x6d\x65\x01\x0a\x01\x00\x07\x70\x72\x6f\x64\x75\x63\x65\x07\x08\x01\x00\x05\x63\x61\x6c\x6c\x73",
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "simplify-locals",
  ]).unwrap()
  ignore(@validate.validate_module(output).unwrap())
  // The producer runs once. Both iterations must read its first result, 21.
  // Sinking the call through the loop backedge instead produces 21 + 22.
  for module_ in [input, output] {
    sl_dew_assert_reduced_i32_result(module_)
  }
}
