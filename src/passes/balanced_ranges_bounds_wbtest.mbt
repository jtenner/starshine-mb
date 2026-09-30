///|
test "raw cleanup ranges retain suffix typing at every exclusive end" {
  let env = @validate.Env::new()
  let fixtures = [
    [
      @lib.Instruction::nop(),
      @lib.Instruction::i32_const(@lib.I32(7)),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::i32_div_s(),
    ],
    [
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i64_const(@lib.I64(2L)),
    ],
    [
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(7))]),
      ),
      @lib.Instruction::drop(),
    ],
    // Intentionally invalid/incomplete prefixes retain exact failure handling.
    [
      @lib.Instruction::drop(),
      @lib.Instruction::i64_const(@lib.I64(1L)),
      @lib.Instruction::i32_eqz(),
    ],
    [@lib.Instruction::unreachable_(), @lib.Instruction::i32_const(@lib.I32(7))],
  ]
  for body in fixtures {
    let saved = body.copy()
    for end in 0..<(body.length() + 1) {
      for count in [0, 1, 2] {
        let prefix = Array::makei(end, fn(index) { body[index] })
        let old = sl_balanced_range_reference_suffix(prefix, count, env)
        let actual = sl_value_suffix_at(body, end, count, env)
        assert_eq(end - actual.length(), old.0.length())
        assert_eq(actual, old.1)
      }
    }
    assert_eq(body, saved)
  }
}

///|
test "raw cleanup statement ranges retain absolute boundaries and escape handling" {
  let env = @validate.Env::new()
  let fixtures = [
    [
      @lib.Instruction::nop(),
      @lib.Instruction::i32_const(@lib.I32(7)),
      @lib.Instruction::drop(),
      @lib.Instruction::nop(),
    ],
    [@lib.Instruction::unreachable_(), @lib.Instruction::i32_const(@lib.I32(7))],
    // Intentionally invalid prefix: starting after it must not recheck it.
    [
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::drop(),
    ],
    [],
  ]
  for body in fixtures {
    let saved = body.copy()
    for start in 0..<(body.length() + 1) {
      let tail = Array::makei(body.length() - start, fn(index) {
        body[start + index]
      })
      for escape in [false, true] {
        assert_eq(
          run_hot_pipeline_raw_simplify_locals_statement_prefix_end(
            body,
            env,
            escape,
            start~,
          ),
          start + sl_prefix_reference(tail, env, escape),
        )
      }
    }
    assert_eq(body, saved)
  }
}
