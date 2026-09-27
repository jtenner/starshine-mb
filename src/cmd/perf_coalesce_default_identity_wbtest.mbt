///|
test "command coalesce preserves live parameters beside implicit and explicit defaults" {
  let output = cmd_deep_audit_run(
    "(module (func (export \"run\") (param i32 i32) (result i32) (local i32 i32) i32.const 5 local.set 2 local.get 0 if local.get 3 drop else i32.const 0 local.set 3 end local.get 0 local.get 1 i32.add local.get 2 i32.add local.get 3 i32.add))",
    "coalesce-locals",
  )
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  for (a, b) in [(0, 99), (1, 77), (-3, -8)] {
    let values = Array::make(locals.length() + 2, 0)
    values[0] = a
    values[1] = b
    let stack : Array[Int] = []
    fn execute(instructions : Array[@lib.Instruction]) -> Unit {
      for instruction in instructions {
        match instruction {
          @lib.I32Const(@lib.I32(value)) => stack.push(value)
          @lib.LocalGet(@lib.LocalIdx(raw)) => stack.push(values[raw.to_int()])
          @lib.LocalSet(@lib.LocalIdx(raw)) =>
            values[raw.to_int()] = stack.pop().unwrap()
          @lib.LocalTee(@lib.LocalIdx(raw)) =>
            values[raw.to_int()] = stack[stack.length() - 1]
          @lib.I32Add => {
            let rhs = stack.pop().unwrap()
            let lhs = stack.pop().unwrap()
            stack.push(lhs + rhs)
          }
          @lib.Drop => ignore(stack.pop().unwrap())
          @lib.Nop => ()
          @lib.Block(_, @lib.Expr(nested)) | @lib.Loop(_, @lib.Expr(nested)) =>
            execute(nested)
          @lib.If(_, yes, no) =>
            if stack.pop().unwrap() != 0 {
              execute(yes)
            } else {
              match no {
                Some(body) => execute(body)
                None => ()
              }
            }
          _ =>
            abort(
              "unexpected numeric default fixture instruction: \{instruction}",
            )
        }
      }
    }
    execute(body)
    assert_eq(stack, [a + b + 5])
  }
}
