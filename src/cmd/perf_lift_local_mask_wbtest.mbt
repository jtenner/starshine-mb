///|
test "command hot passes preserve a compound carried read across local writes" {
  for
    pass in [
      "coalesce-locals", "dae2", "precompute-propagate", "simplify-locals",
    ] {
    let output = cmd_deep_audit_run(
      "(module (func (export \"run\") (param i32) (result i32) (local i32) local.get 0 i32.const 1 i32.add i32.const 2 local.set 1 i32.const 9 local.set 0 local.get 0 i32.add))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    for argument in [-7, 0, 11] {
      let values = Array::make(locals.length() + 1, 0)
      values[0] = argument
      let stack : Array[Int] = []
      fn execute(instructions : Array[@lib.Instruction]) -> Unit {
        for instruction in instructions {
          match instruction {
            @lib.I32Const(@lib.I32(value)) => stack.push(value)
            @lib.LocalGet(@lib.LocalIdx(raw)) =>
              stack.push(values[raw.to_int()])
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
            @lib.Block(_, @lib.Expr(nested)) => execute(nested)
            _ => abort("unexpected carried-read instruction: \{instruction}")
          }
        }
      }
      execute(body)
      assert_eq(stack, [argument + 10], msg=pass)
    }
  }
}
