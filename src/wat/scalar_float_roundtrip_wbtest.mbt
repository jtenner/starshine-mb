///|
test "lib WAT scalar float constants preserve their bits" {
  let input = match
    @wast.wast_to_binary_module(
      "(module (func f32.const 3.5 drop f32.const -0 drop f32.const inf drop f32.const -nan:0x12345 drop f64.const -0 drop f64.const nan:0x123456 drop))",
    ) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  let text = match lib_module_to_wat(input) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  let output = match @wast.wast_to_binary_module(text) {
    Ok(v) => v
    Err(e) => fail("printed float constants must parse: \{e}; \{text}")
  }
  let before = input.code_sec.unwrap().0[0]
  let after = output.code_sec.unwrap().0[0]
  let @lib.Func(_, @lib.Expr(before_body)) = before
  let @lib.Func(_, @lib.Expr(after_body)) = after
  assert_eq(before_body.length(), after_body.length())
  for index in 0..<before_body.length() {
    match (before_body[index], after_body[index]) {
      (@lib.F32Const(@lib.F32(a)), @lib.F32Const(@lib.F32(b))) =>
        assert_eq(a.reinterpret_as_int(), b.reinterpret_as_int())
      (@lib.F64Const(@lib.F64(a)), @lib.F64Const(@lib.F64(b))) =>
        assert_eq(a.reinterpret_as_int64(), b.reinterpret_as_int64())
      (@lib.Drop, @lib.Drop) => ()
      _ => fail("expected the same scalar float instructions")
    }
  }
}
