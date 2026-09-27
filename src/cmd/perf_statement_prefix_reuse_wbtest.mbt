///|
test "command simplify-locals keeps multi-instruction statement prefixes in order" {
  let output = cmd_deep_audit_run(
    "(module (import \"env\" \"observe\" (func $observe (param i32))) (func (export \"run\") (result i32) (local i32) i32.const 20 i32.const 22 i32.add local.set 0 i32.const 1 i32.const 2 i32.add call $observe local.get 0))",
    "simplify-locals",
  )
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  let values = Array::make(locals.length(), 0)
  let stack : Array[Int] = []
  let observed : Array[Int] = []
  for instr in body {
    match instr {
      @lib.I32Const(@lib.I32(value)) => stack.push(value)
      @lib.I32Add => {
        let right = stack.pop().unwrap()
        let left = stack.pop().unwrap()
        stack.push(left + right)
      }
      @lib.LocalGet(@lib.LocalIdx(raw)) => stack.push(values[raw.to_int()])
      @lib.LocalSet(@lib.LocalIdx(raw)) =>
        values[raw.to_int()] = stack.pop().unwrap()
      @lib.LocalTee(@lib.LocalIdx(raw)) =>
        values[raw.to_int()] = stack[stack.length() - 1]
      @lib.Call(@lib.FuncIdx(raw)) => {
        assert_eq(raw, 0U)
        observed.push(stack.pop().unwrap())
      }
      @lib.Nop => ()
      _ => fail("unexpected straight-line rewrite: \{instr}")
    }
  }
  assert_eq(observed, [3])
  assert_eq(stack, [42])
}
