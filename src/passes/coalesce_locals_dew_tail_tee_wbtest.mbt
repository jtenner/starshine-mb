///|
fn cl_dew_tail_tee_execute(func : @lib.Func, index : Int) -> Int raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = func
  let locals = Array::make(body_locals.length() + 1, 0)
  locals[0] = index
  let stack : Array[Int] = []
  let mut fuel = 200
  fn execute(instrs : Array[@lib.Instruction]) -> Bool raise {
    for instr in instrs {
      fuel -= 1
      assert_true(fuel >= 0, msg="tail tee exceeded 200 instructions")
      match instr {
        @lib.Nop => ()
        @lib.Drop => ignore(stack.pop().unwrap())
        @lib.I32Const(@lib.I32(value)) => stack.push(value)
        @lib.LocalGet(@lib.LocalIdx(index)) =>
          stack.push(locals[index.to_int()])
        @lib.LocalSet(@lib.LocalIdx(index)) =>
          locals[index.to_int()] = stack.pop().unwrap()
        @lib.LocalTee(@lib.LocalIdx(index)) =>
          locals[index.to_int()] = stack[stack.length() - 1]
        @lib.I32Add | @lib.I32GeU | @lib.I32GtU | @lib.I32Ne => {
          let rhs = stack.pop().unwrap()
          let lhs = stack.pop().unwrap()
          stack.push(
            match instr {
              @lib.I32Add => lhs + rhs
              @lib.I32GeU => if lhs.to_uint() >= rhs.to_uint() { 1 } else { 0 }
              @lib.I32GtU => if lhs.to_uint() > rhs.to_uint() { 1 } else { 0 }
              _ => if lhs != rhs { 1 } else { 0 }
            },
          )
        }
        @lib.If(_, then_body, else_body) => {
          let condition = stack.pop().unwrap()
          if execute(if condition != 0 { then_body } else { else_body.or([]) }) {
            return true
          }
        }
        @lib.Block(_, @lib.Expr(nested)) => if execute(nested) { return true }
        @lib.Return => return true
        _ => fail("unexpected tail tee instruction or trap: \{instr}")
      }
    }
    false
  }
  ignore(execute(body))
  @debug.assert_eq(stack.length(), 1)
  stack[0]
}

///|
test "coalesce-locals removes an overwritten tee before reusing a parameter" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #| (func (export "run") (param i32) (result i32) (local i32)
      #|  local.get 0 i32.const 10 local.tee 1 i32.ge_u
      #|  if (result i32) i32.const 1 else local.get 0 i32.const 99 i32.gt_u end
      #|  if unreachable end
      #|  local.get 0 i32.const 1 i32.add local.tee 1 local.get 1 i32.add))
    ),
  )
  for pass_name in ["coalesce-locals", "coalesce-locals-cfg"] {
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass_name]).unwrap()
    ignore(@validate.validate_module(output).unwrap())
    let before = input.code_sec.unwrap().0[0]
    let after = output.code_sec.unwrap().0[0]
    for index in [0, 2, 9] {
      @debug.assert_eq(cl_dew_tail_tee_execute(before, index), 2 * (index + 1))
      @debug.assert_eq(cl_dew_tail_tee_execute(after, index), 2 * (index + 1))
    }
    let @lib.Func(locals, _) = after
    @debug.assert_eq(locals.length(), 0)
  }
}
