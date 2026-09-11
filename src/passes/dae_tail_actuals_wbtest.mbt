///|
fn dae_tail_actuals_execute(mod_ : @lib.Module) -> Unit raise {
  let module_ctx = @ir.hot_module_context_from_module(mod_)
  let funcs = mod_.code_sec.unwrap().0
  let mut fuel = 500
  fn invoke(index : Int, args : Array[Int]) -> Array[Int] raise {
    let @lib.FuncType(params, results) = @ir.hot_module_resolve_func_type(
      module_ctx,
      @lib.FuncIdx::new(index.to_uint()),
    ).unwrap()
    @debug.assert_eq(args.length(), params.length())
    let @lib.Func(body_locals, @lib.Expr(body)) = funcs[index]
    let locals = Array::make(params.length() + body_locals.length(), 0)
    for i, value in args {
      locals[i] = value
    }
    let stack : Array[Int] = []
    fn execute(instrs : Array[@lib.Instruction]) -> Bool raise {
      for instr in instrs {
        fuel -= 1
        assert_true(
          fuel >= 0,
          msg="tail call did not finish within 500 instructions",
        )
        match instr {
          @lib.Nop => ()
          @lib.Drop => ignore(stack.pop().unwrap())
          @lib.I32Const(@lib.I32(value)) => stack.push(value)
          @lib.LocalGet(@lib.LocalIdx(local_)) =>
            stack.push(locals[local_.to_int()])
          @lib.LocalSet(@lib.LocalIdx(local_)) =>
            locals[local_.to_int()] = stack.pop().unwrap()
          @lib.LocalTee(@lib.LocalIdx(local_)) =>
            locals[local_.to_int()] = stack[stack.length() - 1]
          @lib.I32Eqz => {
            let value = stack.pop().unwrap()
            stack.push(if value == 0 { 1 } else { 0 })
          }
          @lib.I32Add | @lib.I32Sub | @lib.I32Eq | @lib.I32Ne => {
            let rhs = stack.pop().unwrap()
            let lhs = stack.pop().unwrap()
            stack.push(
              match instr {
                @lib.I32Add => lhs + rhs
                @lib.I32Sub => lhs - rhs
                @lib.I32Eq => if lhs == rhs { 1 } else { 0 }
                _ => if lhs != rhs { 1 } else { 0 }
              },
            )
          }
          @lib.If(_, then_body, else_body) => {
            let condition = stack.pop().unwrap()
            if execute(
                if condition != 0 {
                  then_body
                } else {
                  else_body.or([])
                },
              ) {
              return true
            }
          }
          @lib.Block(_, @lib.Expr(nested)) => if execute(nested) { return true }
          @lib.Call(@lib.FuncIdx(callee))
          | @lib.ReturnCall(@lib.FuncIdx(callee)) => {
            let @lib.FuncType(callee_params, _) = @ir.hot_module_resolve_func_type(
              module_ctx,
              @lib.FuncIdx::new(callee),
            ).unwrap()
            let arguments = Array::make(callee_params.length(), 0)
            for i = arguments.length() - 1; i >= 0; i = i - 1 {
              arguments[i] = stack.pop().unwrap()
            }
            let values = invoke(callee.to_int(), arguments)
            if instr is @lib.ReturnCall(_) {
              stack.clear()
              stack.append(values)
              return true
            }
            stack.append(values)
          }
          @lib.Return => return true
          _ => fail("unexpected tail-actual instruction or trap: \{instr}")
        }
      }
      false
    }
    ignore(execute(body))
    @debug.assert_eq(stack.length(), results.length())
    stack
  }
  @debug.assert_eq(invoke(funcs.length() - 1, []), [])
}

///|
test "dae-optimizing keeps changing tail-recursion actuals" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #| (func $sum (param i32 i32) (result i32)
      #|  local.get 0 if
      #|   local.get 0 i32.const 1 i32.sub
      #|   local.get 1 i32.const 1 i32.add return_call $sum
      #|  else end local.get 1)
      #| (func (export "main")
      #|  i32.const 4 i32.const 0 call $sum
      #|  i32.const 4 i32.ne if unreachable end))
    ),
  )
  dae_tail_actuals_execute(input)
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "dae-optimizing",
  ]).unwrap()
  ignore(@validate.validate_module(output).unwrap())
  dae_tail_actuals_execute(output)
}

///|
test "dae-optimizing requires agreeing ordinary and tail-call constants" {
  for tail_value in [4, 7] {
    let template = pass_test_module_from_wat(
      (
        #|(module
        #| (func $value (param i32) (result i32) local.get 0)
        #| (func $tail (result i32) i32.const 7 return_call $value)
        #| (func (export "main")
        #|  i32.const 4 call $value i32.const 4 i32.ne if unreachable end
        #|  call $tail i32.const 7 i32.ne if unreachable end))
      ),
    )
    let funcs = template.code_sec.unwrap().0.copy()
    let @lib.Func(tail_locals, @lib.Expr(tail_body)) = funcs[1]
    let next_tail = tail_body.copy()
    next_tail[0] = @lib.Instruction::i32_const(@lib.I32(tail_value))
    funcs[1] = @lib.Func::new(tail_locals, @lib.Expr::new(next_tail))
    let @lib.Func(main_locals, @lib.Expr(main_body)) = funcs[2]
    let next_main = main_body.copy()
    next_main[6] = @lib.Instruction::i32_const(@lib.I32(tail_value))
    funcs[2] = @lib.Func::new(main_locals, @lib.Expr::new(next_main))
    let input = template.with_code_sec(@lib.CodeSec::new(funcs))
    ignore(@validate.validate_module(input).unwrap())
    dae_tail_actuals_execute(input)
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
      "dae-optimizing",
    ]).unwrap()
    ignore(@validate.validate_module(output).unwrap())
    dae_tail_actuals_execute(output)
    let @lib.FuncType(params, _) = @ir.hot_module_resolve_func_type(
      @ir.hot_module_context_from_module(output),
      @lib.FuncIdx::new(0U),
    ).unwrap()
    @debug.assert_eq(params.length(), if tail_value == 4 { 0 } else { 1 })
  }
}
