///|
test "command DAE variants preserve NaN payloads during signature cleanup" {
  for pass in ["dae", "dae-optimizing"] {
    let parsed = @passes.pass_test_module_from_wat(
      "(module (func $target (param i32) (result f32) f32.const 0) (func (export \"run\") (result i32) i32.const 7 call $target i32.reinterpret_f32))",
    )
    let funcs = parsed.code_sec.unwrap().0.copy()
    let @lib.Func(locals, _) = funcs[0]
    funcs[0] = @lib.Func::new(
      locals,
      @lib.Expr::new([
        @lib.Instruction::f32_const(
          @lib.F32(Float::reinterpret_from_uint(0x7fc00001U)),
        ),
      ]),
    )
    let output = cmd_deep_audit_run_module(
      parsed.with_code_sec(@lib.CodeSec::new(funcs)),
      pass,
    )
    @validate.validate_module(output).unwrap()
    let funcs = output.code_sec.unwrap().0
    let mut payloads = 0
    for func in funcs {
      let @lib.Func(_, @lib.Expr(body)) = func
      payloads += cmd_deep_audit_count(body, fn(instr) {
        match instr {
          @lib.F32Const(@lib.F32(value)) =>
            value.reinterpret_as_uint() == 0x7fc00001U
          @lib.I32Const(@lib.I32(value)) =>
            value.reinterpret_as_uint() == 0x7fc00001U
          _ => false
        }
      })
    }
    assert_true(
      payloads > 0,
      msg="\{pass}: \{@debug.to_string(output.code_sec)}",
    )
  }
}
