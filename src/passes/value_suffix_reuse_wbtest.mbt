///|
fn sl_value_suffix_fixture(width : Int) -> Array[@lib.Instruction] {
  let body = Array::make(width, @lib.Instruction::i32_const(@lib.I32(1)))
  for _ in 0..<(width - 1) {
    body.push(@lib.Instruction::i32_add())
  }
  body
}

///|
test "value suffix rejects impossible arities before typechecking and keeps the latest split" {
  let body = sl_value_suffix_fixture(16)
  let original = body.copy()
  let visits = [0]
  let split = run_hot_pipeline_raw_simplify_locals_take_value_suffix(
    body,
    1,
    @validate.Env::new(),
    typed_instructions=Some(visits),
  )
  assert_eq(split, sl_value_suffix_reference(body, 1, @validate.Env::new()))
  assert_eq(split.0, [])
  assert_eq(split.1, body)
  assert_true(visits[0] <= body.length())
  assert_eq(body, original)
}

///|
test "value suffix retains multivalue traps invalid types and unsupported-control fallback" {
  let env = @validate.Env::new()
  let fixtures = [
    [
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i64_const(@lib.I64(2L)),
    ],
    [
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::i32_div_s(),
    ],
    // Intentionally invalid: arity proof cannot replace operand typechecking.
    [@lib.Instruction::i64_const(@lib.I64(1L)), @lib.Instruction::i32_eqz()],
    [
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(7))]),
      ),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_add(),
    ],
    [@lib.Instruction::unreachable_(), @lib.Instruction::i32_const(@lib.I32(7))],
  ]
  for body in fixtures {
    for count in [0, 1, 2] {
      assert_eq(
        run_hot_pipeline_raw_simplify_locals_take_value_suffix(body, count, env),
        sl_value_suffix_reference(body, count, env),
      )
    }
  }
}
