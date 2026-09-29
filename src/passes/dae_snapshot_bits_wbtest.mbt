///|
test "DAE transaction identity rejects changed signed zero bodies" {
  for result in ["f32", "f64"] {
    let left = pass_test_module_from_wat(
      "(module (func (export \"run\") (result \{result}) \{result}.const 0))",
    )
    let right = pass_test_module_from_wat(
      "(module (func (export \"run\") (result \{result}) \{result}.const -0))",
    )
    assert_false(dae_snapshot_module_unchanged(left, right))
  }
}

///|
test "DAE transaction identity recognizes distinct identical NaN body bits" {
  let source = "(module (func (export \"run\") (result f32) block (result f32) f32.const nan end))"
  let left = pass_test_module_from_wat(source)
  let right = pass_test_module_from_wat(source)
  assert_eq(
    @binary.encode_module(left).unwrap(),
    @binary.encode_module(right).unwrap(),
  )
  assert_true(dae_snapshot_module_unchanged(left, right))
}

///|
test "DAE transaction identity rejects changed signed zero global initializers" {
  let left = pass_test_module_from_wat("(module (global f64 (f64.const 0)))")
  let right = pass_test_module_from_wat("(module (global f64 (f64.const -0)))")
  assert_false(dae_snapshot_module_unchanged(left, right))
}

///|
test "DAE transaction identity recognizes distinct identical NaN global bits" {
  let source = "(module (global f32 (f32.const nan)))"
  let left = pass_test_module_from_wat(source)
  let right = pass_test_module_from_wat(source)
  assert_eq(
    @binary.encode_module(left).unwrap(),
    @binary.encode_module(right).unwrap(),
  )
  assert_true(dae_snapshot_module_unchanged(left, right))
}

///|
fn dae_snapshot_bits_nested(value : @lib.Instruction, kind : Int) -> @lib.Expr {
  let body = @lib.Expr::new([value])
  let type_ = @lib.BlockType::val_type(@lib.ValType::f32())
  let instruction = match kind {
    0 => @lib.Instruction::block(type_, body)
    1 => @lib.Instruction::loop_(type_, body)
    2 => @lib.Instruction::if_(type_, [value], Some([value]))
    3 => @lib.Instruction::try_table(type_, [], body)
    _ => @lib.Instruction::try_(type_, body, [@lib.LegacyCatch::all(body)])
  }
  @lib.Expr::new([instruction])
}

///|
test "DAE transaction identity compares float bits in every structured body and legacy catch" {
  let plus = @lib.Instruction::f32_const(@lib.F32(0.0))
  let minus = @lib.Instruction::f32_const(@lib.F32(-0.0))
  let nan = @lib.Instruction::f32_const(
    @lib.F32((0x7fc00001 : Int).reinterpret_as_float()),
  )
  let other_nan = @lib.Instruction::f32_const(
    @lib.F32((0x7fc00002 : Int).reinterpret_as_float()),
  )
  for kind in 0..<5 {
    assert_false(
      dae_snapshot_expr_unchanged(
        dae_snapshot_bits_nested(plus, kind),
        dae_snapshot_bits_nested(minus, kind),
      ),
    )
    assert_true(
      dae_snapshot_expr_unchanged(
        dae_snapshot_bits_nested(nan, kind),
        dae_snapshot_bits_nested(nan, kind),
      ),
    )
    assert_false(
      dae_snapshot_expr_unchanged(
        dae_snapshot_bits_nested(nan, kind),
        dae_snapshot_bits_nested(other_nan, kind),
      ),
    )
  }
  let type_ = @lib.BlockType::val_type(@lib.ValType::f32())
  let normal = @lib.Expr::new([plus])
  let left = @lib.Expr::new([
    @lib.Instruction::try_(type_, normal, [
      @lib.LegacyCatch::all(@lib.Expr::new([plus])),
    ]),
  ])
  let right = @lib.Expr::new([
    @lib.Instruction::try_(type_, normal, [
      @lib.LegacyCatch::all(@lib.Expr::new([minus])),
    ]),
  ])
  assert_false(dae_snapshot_expr_unchanged(left, right))
}
