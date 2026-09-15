///|
test "fifth audit SSA intentionally unrelated loop exit local False" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i32 i32) block loop local.get 0  if i32.const 42 local.set 2 br 2 end end end local.get 0))",
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "ssa-nomerge",
  ]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  for value in [0, 1, 7, 42] {
    assert_eq(
      fifth_audit_execute_locals(output.code_sec.unwrap().0[0], value),
      value,
    )
  }
}

///|
test "fifth audit SSA intentionally unrelated loop exit local True" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i32 i32) block loop local.get 0 i32.const 7 local.set 1 if i32.const 42 local.set 2 br 2 end end end local.get 0))",
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "ssa-nomerge",
  ]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  for value in [0, 1, 7, 42] {
    assert_eq(
      fifth_audit_execute_locals(output.code_sec.unwrap().0[0], value),
      value,
    )
  }
}

///|
fn fifth_audit_execute_locals(func : @lib.Func, param : Int) -> Int raise {
  let @lib.Func(types, @lib.Expr(body)) = func
  let locals = Array::make(types.length() + 1, 0)
  locals[0] = param
  let stack : Array[Int] = []
  let mut fuel = 200
  fn execute(body : Array[@lib.Instruction]) -> Int? raise {
    for instr in body {
      fuel -= 1
      assert_true(fuel > 0)
      match instr {
        @lib.Nop => ()
        @lib.I32Const(@lib.I32(value)) => stack.push(value)
        @lib.LocalGet(@lib.LocalIdx(id)) =>
          stack.push(locals[id.reinterpret_as_int()])
        @lib.LocalSet(@lib.LocalIdx(id)) =>
          locals[id.reinterpret_as_int()] = stack.pop().unwrap()
        @lib.LocalTee(@lib.LocalIdx(id)) =>
          locals[id.reinterpret_as_int()] = stack[stack.length() - 1]
        @lib.Drop => ignore(stack.pop())
        @lib.Br(@lib.LabelIdx(depth)) => return Some(depth.reinterpret_as_int())
        @lib.Return => return Some(-1)
        @lib.Block(_, @lib.Expr(child)) =>
          match execute(child) {
            Some(depth) if depth != 0 =>
              return Some(if depth < 0 { depth } else { depth - 1 })
            _ => ()
          }
        @lib.Loop(_, @lib.Expr(child)) => {
          let mut again = true
          while again {
            match execute(child) {
              Some(0) => ()
              Some(depth) =>
                return Some(if depth < 0 { depth } else { depth - 1 })
              None => again = false
            }
          }
        }
        @lib.If(_, then_body, else_body) => {
          let child = if stack.pop().unwrap() != 0 {
            then_body
          } else {
            else_body.unwrap_or([])
          }
          match execute(child) {
            Some(depth) if depth != 0 =>
              return Some(if depth < 0 { depth } else { depth - 1 })
            _ => ()
          }
        }
        _ => fail("unexpected audit instruction: \{instr}")
      }
    }
    None
  }
  ignore(execute(body))
  assert_eq(stack.length(), 1)
  stack[0]
}

///|
test "fifth audit SSA pipeline preserves unrelated loop exit values" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i32 i32) block loop local.get 0 i32.const 7 local.set 1 if i32.const 42 local.set 2 br 2 end end end local.get 0))",
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "ssa-nomerge",
  ]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  for value in [0, 1, 7, 42] {
    assert_eq(
      fifth_audit_execute_locals(output.code_sec.unwrap().0[0], value),
      value,
    )
  }
}
