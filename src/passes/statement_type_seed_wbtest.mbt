///|
fn sl_type_seed_env(width : Int) -> @validate.Env {
  @validate.Env::new().with_locals(
    @lib.Locals::from_types(Array::make(width, @lib.ValType::i32())),
  )
}

///|
test "statement queries borrow initialization facts and own independent stacks" {
  let env = sl_type_seed_env(128)
  let seed = SlStatementTypeSeed::new(env)
  let first = seed.fresh_state()
  let second = seed.fresh_state()
  assert_true(
    physical_equal(first.initialized_locals, second.initialized_locals),
  )
  assert_true(
    physical_equal(first.initialized_locals, seed.state.initialized_locals),
  )
  assert_false(physical_equal(first.stack, second.stack))
  assert_false(physical_equal(first.stack, seed.state.stack))
  let first = @validate.Typecheck::typecheck(
    @lib.Instruction::i32_const(@lib.I32(7)),
    first,
  ).unwrap()
  assert_eq(first.stack, [@lib.ValType::i32()])
  assert_true(second.stack.is_empty())
  assert_true(seed.state.stack.is_empty())
  assert_true(seed.state.initialized_locals.all(fn(bit) { bit }))
}

///|
test "statement query failure and terminal escape do not leak into later queries" {
  let seed = SlStatementTypeSeed::new(sl_type_seed_env(128))
  let invalid = [@lib.Instruction::drop()]
  assert_true(
    @validate.Typecheck::typecheck(@lib.Expr::new(invalid), seed.fresh_state()).is_err(),
  )
  let terminal = @validate.Typecheck::typecheck(
    @lib.Instruction::unreachable_(),
    seed.fresh_state(),
  ).unwrap()
  assert_false(terminal.reachable)
  let next = seed.fresh_state()
  assert_true(next.reachable)
  assert_eq(next.escape, @validate.tc_escape_none())
  assert_true(next.reachable_escape_depths.is_empty())
  assert_true(next.stack.is_empty())
}

///|
test "statement type seeds remain isolated across changed local environments" {
  let first = SlStatementTypeSeed::new(sl_type_seed_env(128))
  let second = SlStatementTypeSeed::new(
    @validate.Env::new().with_locals(
      @lib.Locals::from_types(Array::make(129, @lib.ValType::f64())),
    ),
  )
  assert_false(
    physical_equal(
      first.state.initialized_locals,
      second.state.initialized_locals,
    ),
  )
  let index = @lib.Instruction::local_get(@lib.LocalIdx::new(128U))
  assert_true(
    @validate.Typecheck::typecheck(index, first.fresh_state()).is_err(),
  )
  let result = @validate.Typecheck::typecheck(index, second.fresh_state()).unwrap()
  assert_eq(result.stack, [@lib.ValType::f64()])
}

///|
test "seeded statement boundaries preserve reference typing, control and invalid prefixes" {
  let input = pass_test_module_from_wat(
    "(module (type $t (struct (field i32))) (tag $tag) (func (param (ref $t)) (local (ref $t) i64) local.get 0 local.set 1))",
  )
  @validate.validate_module(input).unwrap()
  let @lib.Func(locals, _) = input.code_sec.unwrap().0[0]
  let params = [
    @lib.ValType::ref_type(
      @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
    ),
  ]
  let env = @validate.Env::new()
    .with_module(input)
    .with_locals(@lib.Locals::from_types(params).copy())
  env.locals.append(locals)
  let seed = SlStatementTypeSeed::new(env)
  let read = @lib.Instruction::local_get(@lib.LocalIdx::new(1U))
  let write = @lib.Instruction::local_set(@lib.LocalIdx::new(1U))
  let fixtures = [
    [read, @lib.Instruction::drop()],
    [read, write],
    [
      @lib.Instruction::i64_const(@lib.I64(7L)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    ],
    [
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [read, write],
        Some([read, @lib.Instruction::drop()]),
      ),
    ],
    [
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(0U))]),
      ),
    ],
    [
      @lib.Instruction::try_table(
        @lib.BlockType::void_(),
        [],
        @lib.Expr::new([read, @lib.Instruction::drop()]),
      ),
    ],
    [@lib.Instruction::unreachable_(), read, @lib.Instruction::drop()],
    // Intentionally invalid: wrong scalar assignment, invalid index, underflow.
    [@lib.Instruction::i32_const(@lib.I32(7)), write],
    [@lib.Instruction::local_get(@lib.LocalIdx::new(99U))],
    [@lib.Instruction::drop(), read],
    [],
  ]
  for body in fixtures {
    let saved = body.copy()
    for start in 0..<(body.length() + 1) {
      for escape in [false, true] {
        let expected = run_hot_pipeline_raw_simplify_locals_statement_prefix_end(
          body,
          env,
          escape,
          start~,
        )
        assert_eq(
          run_hot_pipeline_raw_simplify_locals_statement_prefix_end(
            body,
            env,
            escape,
            start~,
            typed_seed=Some(seed),
          ),
          expected,
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
test "balanced statement cleanup preserves exact reference output on repeated queries" {
  for width in [8, 128] {
    let middle = Array::makei(7, fn(i) { "local.get \{i + 1} call $consume" }).join(
      " ",
    )
    let locals = Array::make(width, "i32").join(" ")
    let input = pass_test_module_from_wat(
      "(module (import \"env\" \"produce\" (func $produce (result i32))) (import \"env\" \"consume\" (func $consume (param i32))) (func (local \{locals}) call $produce local.set 0 \{middle} local.get 0 call $consume))",
    )
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let @lib.Func(local_types, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    let env = @validate.Env::new().with_module(input).with_locals(local_types)
    let expected = sl_balanced_tree_reference_flat(body, env)
    let actual = run_hot_pipeline_raw_simplify_locals_rewrite_balanced_statement_local_gets_flat(
      body, env,
    )
    assert_eq(actual, expected)
    assert_eq(actual.1, 1)
    assert_eq(
      actual.0.filter(fn(i) { i is @lib.Call(_) }),
      body.filter(fn(i) { i is @lib.Call(_) }),
    )
    assert_false(actual.0.any(fn(i) { i is @lib.LocalSet(@lib.LocalIdx(0U)) }))
    @validate.validate_module(
      input.with_code_sec(
        @lib.CodeSec::new([
          @lib.Func::new(local_types, @lib.Expr::new(actual.0)),
        ]),
      ),
    ).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
