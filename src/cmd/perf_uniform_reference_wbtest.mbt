///|
test "command optimizing DAE retains externalized i31 materialization" {
  let output = cmd_deep_audit_run(
    "(module (func $target (param externref) (result externref) local.get 0) (func (export \"run\") (result externref) i32.const 7 ref.i31 extern.convert_any call $target drop i32.const 7 ref.i31 extern.convert_any call $target))",
    "dae-optimizing",
  )
  assert_true(@validate.validate_module(output) is Ok(_))
  let flat : Array[@lib.Instruction] = []
  fn collect(body : Array[@lib.Instruction]) -> Unit {
    for instr in body {
      match instr {
        @lib.Block(_, @lib.Expr(children)) => collect(children)
        _ => flat.push(instr)
      }
    }
  }
  collect(cmd_deep_audit_body(output, index=0))
  assert_eq(flat, [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::extern_convert_any(),
  ])
}
