///|
test "r1 review f32 decimal literals round directly to binary32" {
  // This decimal is above 1 + 2^-24, but rounds to that midpoint in f64.
  let mod_ = @wast.wast_to_binary_module(
    "(module (func (result f32) f32.const 1.0000000596046448))",
  ).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = mod_.code_sec.unwrap().0[0]
  match body {
    [@lib.F32Const(@lib.F32(value))] =>
      assert_eq(value.reinterpret_as_int(), 0x3f800001)
    _ => fail("expected one f32 constant")
  }
}
