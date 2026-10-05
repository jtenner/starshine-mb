///|
test "command OI retains zero fold and first effect before intervening select" {
  let output = cmd_deep_audit_run(
    "(module (import \"env\" \"log\" (func $log (param i32))) (func $se (param i32) (result i32) (call $log (local.get 0)) (i32.const 0)) (func (export \"f\") (result i32) (local i32) i32.const 1 call $se i32.const 0 i32.and i32.const 5 i32.const 0 i32.const 2 call $se i32.const 0 select local.set 0 i32.add))",
    "optimize-instructions",
  )
  @validate.validate_module(output).unwrap()
  let body = cmd_deep_audit_body(output, index=1)
  let arguments : Array[Int] = []
  fn walk(body : Array[@lib.Instruction]) -> Unit {
    let mut constant = -1
    for instr in body {
      match instr {
        @lib.I32Const(@lib.I32(value)) => constant = value
        @lib.Call(@lib.FuncIdx(1U)) => arguments.push(constant)
        @lib.Block(_, @lib.Expr(nested)) => walk(nested)
        _ => ()
      }
    }
  }
  walk(body)
  assert_eq(arguments, [1, 2])
  assert_eq(cmd_deep_audit_count(body, fn(instr) { instr is @lib.I32And }), 0)
}
