///|
test "command DAE modes retain observable effects and fold forwarded scalar actuals" {
  for pass in ["dae", "dae-optimizing"] {
    let output = cmd_deep_audit_run(
      "(module (import \"m\" \"tick\" (func $tick (param i32))) (func $h (param i32) (result i32) local.get 0 call $tick local.get 0) (func $forward (param i32) (result i32) local.get 0 call $h) (func (export \"run\") (result i32) i32.const 7 call $forward))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    let body = cmd_deep_audit_body(output, index=0)
    assert_true(body.contains(@lib.Instruction::call(@lib.FuncIdx::new(0U))))
    assert_true(body.contains(@lib.Instruction::i32_const(@lib.I32(7))))
    assert_false(body.any(fn(instr) { instr is @lib.LocalGet(_) }))
  }
}

///|
test "command DAE modes fold NaN forwarding without changing payload bits" {
  for pass in ["dae", "dae-optimizing"] {
    let output = cmd_deep_audit_run(
      "(module (func $h (param f64) (result i64) local.get 0 i64.reinterpret_f64) (func $f (param f64) (result i64) local.get 0 call $h) (func (export \"run\") (result i64) f64.const nan:0x123456 call $f))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    let body = cmd_deep_audit_body(output, index=0)
    assert_false(body.any(fn(instr) { instr is @lib.LocalGet(_) }))
    match body[0] {
      @lib.F64Const(@lib.F64(value)) =>
        assert_eq(value.reinterpret_as_int64(), 0x7ff0000000123456L)
      @lib.I64Const(@lib.I64(bits)) => assert_eq(bits, 0x7ff0000000123456L)
      _ => fail("expected the exact NaN or its folded reinterpretation")
    }
  }
}
