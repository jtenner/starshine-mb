///|
test "compound suffix queries reuse the original environment initialization row" {
  let env = sl_type_seed_env(128)
  let seed = SlStatementTypeSeed::new(env)
  let builds = [0]
  let body = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_add(),
  ]
  for _ in 0..<3 {
    assert_eq(
      sl_value_suffix_at(
        body,
        body.length(),
        1,
        env,
        typed_seed=Some(seed),
        state_builds=Some(builds),
      ),
      sl_compound_suffix_reference(body, body.length(), 1, env),
    )
  }
  assert_eq(builds[0], 0)
  assert_true(seed.state.stack.is_empty())
  assert_true(seed.state.initialized_locals.all(fn(bit) { bit }))
}

///|
test "compound suffix seed retains failed-query control GC and trap contracts" {
  let env = @validate.Env::new().with_locals(
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i64(),
      @lib.ValType::f64(),
      @lib.ValType::ref_type(
        @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::extern_())),
      ),
    ]),
  )
  let seed = SlStatementTypeSeed::new(env)
  let fixtures = [
    [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::i32_div_s(),
    ],
    [
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::i64_const(@lib.I64(2L)),
      @lib.Instruction::i64_add(),
    ],
    [
      @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      @lib.Instruction::f64_neg(),
    ],
    [
      @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(3U)),
    ],
    [
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(7))]),
      ),
    ],
    [
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::if_(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        [@lib.Instruction::i32_const(@lib.I32(7))],
        Some([@lib.Instruction::i32_const(@lib.I32(9))]),
      ),
    ],
    [
      @lib.Instruction::try_table(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        [],
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(4))]),
      ),
    ],
    [@lib.Instruction::unreachable_(), @lib.Instruction::i32_const(@lib.I32(7))],
    // Intentionally invalid operand/index/stack fixtures must still reject.
    [@lib.Instruction::i64_const(@lib.I64(1L)), @lib.Instruction::i32_eqz()],
    [@lib.Instruction::local_get(@lib.LocalIdx::new(99U))],
    [@lib.Instruction::drop()],
  ]
  for body in fixtures {
    let saved = body.copy()
    for end in 0..<(body.length() + 1) {
      for count in [0, 1, 2] {
        assert_eq(
          sl_value_suffix_at(body, end, count, env, typed_seed=Some(seed)),
          sl_compound_suffix_reference(body, end, count, env),
        )
      }
    }
    assert_eq(body, saved)
    assert_true(seed.state.stack.is_empty())
    assert_true(seed.state.reachable)
    assert_true(seed.state.reachable_escape_depths.is_empty())
    assert_true(seed.state.initialized_locals.all(fn(bit) { bit }))
  }
}

///|
test "compound suffix fresh local environments do not inherit previous query results" {
  let integer = sl_type_seed_env(128)
  let float_env = @validate.Env::new().with_locals(
    @lib.Locals::from_types(Array::make(128, @lib.ValType::f64())),
  )
  let body = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_add(),
  ]
  for env in [integer, float_env, integer] {
    let seed = SlStatementTypeSeed::new(env)
    assert_eq(
      sl_value_suffix_at(body, body.length(), 1, env, typed_seed=Some(seed)),
      sl_compound_suffix_reference(body, body.length(), 1, env),
    )
  }
}
