///|
test "command HOT passes preserve carried calls before later region effects" {
  for
    pass in [
      "coalesce-locals", "dae2", "precompute-propagate", "simplify-locals", "optimize-instructions",
    ] {
    let output = cmd_deep_audit_run(
      "(module (import \"env\" \"value\" (func (result i32))) (import \"env\" \"log\" (func)) (func (export \"run\") (result i32) block (result i32) call 0 call 1 end i32.const 4 i32.add))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    let calls : Array[Int] = []
    fn collect(body : Array[@lib.Instruction]) -> Unit {
      for instr in body {
        match instr {
          @lib.Call(@lib.FuncIdx(raw)) => calls.push(raw.to_int())
          @lib.Block(_, @lib.Expr(nested)) | @lib.Loop(_, @lib.Expr(nested)) =>
            collect(nested)
          @lib.If(_, yes, no) => {
            collect(yes)
            match no {
              Some(body) => collect(body)
              None => ()
            }
          }
          _ => ()
        }
      }
    }
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    collect(body)
    assert_eq(calls, [0, 1], msg=pass)
  }
}
