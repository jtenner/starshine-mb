///|
fn sl_multivalue_source_cmd_execute(
  func : @lib.Func,
  argument : Int32,
) -> Int32 raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = func
  let locals = Array::make(body_locals.length() + 1, 0)
  locals[0] = argument
  let stack : Array[Int32] = []
  fn execute(instrs : Array[@lib.Instruction]) -> Unit raise {
    for instr in instrs {
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
        @lib.I32Add => {
          let rhs = stack.pop().unwrap()
          stack.push(stack.pop().unwrap() + rhs)
        }
        @lib.Block(_, @lib.Expr(nested)) => execute(nested)
        _ => fail("unsupported command multivalue source instruction: \{instr}")
      }
    }
  }
  execute(body)
  assert_eq(stack.length(), 1)
  stack[0]
}

///|
test "command simplify-locals alone retains a tuple producer source before lane publication" {
  let input = @passes.pass_test_module_from_wat(
    (
      #|(module (type $pair (func (result i32 i32)))
      #| (func (export "run") (param i32) (result i32) (local i32 i32 i32)
      #|  local.get 0 local.set 1
      #|  block (type $pair)
      #|   local.get 1 i32.const 1 i32.add
      #|   local.get 1 i32.const 2 i32.add
      #|  end local.set 1 local.set 2
      #|  local.get 2 local.get 1 i32.add))
    ),
  )
  ignore(@validate.validate_module(input).unwrap())
  let output = cmd_deep_audit_run_module(input, "simplify-locals-nostructure")
  let output = decode_module_bytes(encode_module_bytes(output))
  ignore(@validate.validate_module(output).unwrap())
  for argument in [0, 10, -7, 32767] {
    let expected = argument + argument + 3
    assert_eq(
      sl_multivalue_source_cmd_execute(input.code_sec.unwrap().0[0], argument),
      expected,
    )
    assert_eq(
      sl_multivalue_source_cmd_execute(output.code_sec.unwrap().0[0], argument),
      expected,
    )
  }
}
