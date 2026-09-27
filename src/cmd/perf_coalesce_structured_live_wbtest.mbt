///|
test "command coalesce preserves distinct live inputs through structured slot rewriting" {
  let pieces : Array[String] = []
  for i in 0..<16 {
    pieces.push("local.get 0 i32.const \{i} i32.add local.set \{i + 1}")
  }
  pieces.push("local.get 0 if nop else nop end block (result i32) local.get 1")
  for i in 2..<17 {
    pieces.push("local.get \{i} i32.add")
  }
  pieces.push("end")
  let locals = Array::make(16, "i32").join(" ")
  let source = "(module (func (export \"run\") (param i32) (result i32) (local \{locals}) \{pieces.join(" ")}))"
  let output = cmd_deep_audit_run(source, "coalesce-locals")
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  for argument in [-2, 0, 9] {
    let values = Array::make(locals.length() + 1, 0)
    values[0] = argument
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
          @lib.If(_, yes, no) =>
            if stack.pop().unwrap() != 0 {
              execute(yes)
            } else {
              match no {
                Some(body) => execute(body)
                None => ()
              }
            }
          @lib.Block(_, @lib.Expr(nested)) | @lib.Loop(_, @lib.Expr(nested)) =>
            execute(nested)
          _ => abort("unexpected straight loop instruction: \{instruction}")
        }
      }
    }
    execute(body)
    assert_eq(stack, [16 * argument + 120])
  }
}
