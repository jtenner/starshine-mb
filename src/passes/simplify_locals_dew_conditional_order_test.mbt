///|
fn sl_dew_conditional_order_execute(
  module_ : @lib.Module,
  condition : Int,
) -> Unit raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = module_.code_sec.unwrap().0[2]
  let locals = Array::make(body_locals.length() + 1, 0)
  locals[0] = condition
  let stack : Array[Int] = []
  let calls : Array[Int] = []
  // The two leaf functions return 42 and wrap their i64 argument to i32.
  // All values in this bounded fixture are exactly representable as i32.
  fn execute(instrs : Array[@lib.Instruction]) -> Unit raise {
    for instr in instrs {
      match instr {
        @lib.Nop => ()
        @lib.Drop => ignore(stack.pop().unwrap())
        @lib.I32Const(@lib.I32(value)) => stack.push(value)
        @lib.I64Const(@lib.I64(value)) => stack.push(value.to_int())
        @lib.I32WrapI64 => ()
        @lib.LocalGet(@lib.LocalIdx(idx)) =>
          stack.push(locals[idx.reinterpret_as_int()])
        @lib.LocalSet(@lib.LocalIdx(idx)) =>
          locals[idx.reinterpret_as_int()] = stack.pop().unwrap()
        @lib.LocalTee(@lib.LocalIdx(idx)) =>
          locals[idx.reinterpret_as_int()] = stack[stack.length() - 1]
        @lib.Call(@lib.FuncIdx(0U)) => {
          calls.push(-1)
          stack.push(42)
        }
        @lib.Call(@lib.FuncIdx(1U)) => calls.push(stack[stack.length() - 1])
        @lib.I32Add => {
          let rhs = stack.pop().unwrap()
          let lhs = stack.pop().unwrap()
          stack.push(lhs + rhs)
        }
        @lib.If(_, then_body, else_body) =>
          execute(
            if stack.pop().unwrap() != 0 {
              then_body
            } else {
              else_body.or([])
            },
          )
        @lib.Block(_, @lib.Expr(nested)) => execute(nested)
        _ => fail("unexpected conditional-order instruction: \{instr}")
      }
    }
  }
  execute(body)
  @debug.assert_eq(stack, if condition != 0 { [84] } else { [0] })
  @debug.assert_eq(calls, if condition != 0 { [-1, 42] } else { [] })
}

///|
test "simplify-locals keeps dependent conditional results in execution order" {
  let input = @wast.wast_to_binary_module(
    (
      #|(module
      #| (func $hash (result i64) i64.const 42)
      #| (func $bucket (param i64) (result i32) local.get 0 i32.wrap_i64)
      #| (func (export "run") (param i32) (result i32) (local i64 i64 i32 i32)
      #|   local.get 0
      #|   if call $hash local.set 1 else i64.const 0 local.set 1 end
      #|   local.get 1 local.set 2
      #|   local.get 0
      #|   if local.get 2 call $bucket local.set 3 else i32.const 0 local.set 3 end
      #|   local.get 3 local.set 4
      #|   local.get 0 if local.get 4 local.get 2 i32.wrap_i64 i32.add local.set 4 end local.get 4)
      #|)
    ),
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "simplify-locals",
  ]).unwrap()
  ignore(@validate.validate_module(output).unwrap())
  for module_ in [input, output] {
    for condition in [0, 1, -1] {
      sl_dew_conditional_order_execute(module_, condition)
    }
  }
}
