///|
fn sl_flat_statement_reference(
  body : Array[@lib.Instruction],
  start : Int,
  env : @validate.Env,
) -> Int {
  let end = run_hot_pipeline_raw_simplify_locals_statement_prefix_end(
    body,
    env,
    false,
    start~,
  )
  for index in start..<end {
    if run_hot_pipeline_raw_simplify_locals_instr_is_structured(body[index]) ||
      run_hot_pipeline_raw_simplify_locals_instr_is_early_terminator(
        body[index],
      ) {
      return start
    }
  }
  end
}

///|
test "flat statements intentionally reject structured or terminal candidates before typechecking" {
  let env = @validate.Env::new()
  let nested = sl_prefix_fixture(8)
  for
    control in [
      @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(nested)),
      @lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new(nested)),
      @lib.Instruction::try_table(
        @lib.BlockType::void_(),
        [],
        @lib.Expr::new(nested),
      ),
      @lib.Instruction::if_(@lib.BlockType::void_(), nested, Some(nested)),
      @lib.Instruction::unreachable_(),
      @lib.Instruction::br(@lib.LabelIdx::new(0U)),
    ] {
    let body = [control, @lib.Instruction::nop()]
    let checked = [0]
    let actual = run_hot_pipeline_raw_simplify_locals_statement_prefix_end(
      body,
      env,
      false,
      flat_only=true,
      typed_instructions=Some(checked),
    )
    assert_eq(actual, sl_flat_statement_reference(body, 0, env))
    assert_eq(actual, 0)
    assert_eq(checked[0], 0)
  }
}

///|
test "flat statement admission preserves exact boundaries and still typechecks eligible instructions" {
  let env = @validate.Env::new()
  let control = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([@lib.Instruction::nop()]),
  )
  let body = [
    control,
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::drop(),
    control,
  ]
  for start in [0, 1, 3, 4] {
    let checked = [0]
    let end = run_hot_pipeline_raw_simplify_locals_statement_prefix_end(
      body,
      env,
      false,
      start~,
      flat_only=true,
      typed_instructions=Some(checked),
    )
    assert_eq(end, sl_flat_statement_reference(body, start, env))
    assert_eq(checked[0], if start == 1 { 2 } else { 0 })
  }
  // Intentionally invalid: eligible flat instructions retain their typecheck,
  // even when the first error prevents discovering a later boundary.
  let invalid = [
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(7)),
  ]
  let checked = [0]
  assert_eq(
    run_hot_pipeline_raw_simplify_locals_statement_prefix_end(
      invalid,
      env,
      false,
      flat_only=true,
      typed_instructions=Some(checked),
    ),
    0,
  )
  assert_eq(checked[0], 1)
  // Other prefix clients still accept a complete structured statement.
  assert_eq(
    run_hot_pipeline_raw_simplify_locals_statement_prefix_end(body, env, false),
    1,
  )
}

///|
test "balanced forwarding retains structured boundaries and performs later flat rewrites" {
  for type_ in ["i32", "i64", "externref"] {
    let (input, env, body) = sl_balanced_range_fixture(
      "call $produce local.set 0 block call $tick end local.get 0 call $consume call $produce local.set 0 call $tick local.get 0 call $consume",
      type_,
    )
    let saved = @binary.encode_module(input).unwrap()
    let actual = run_hot_pipeline_raw_simplify_locals_rewrite_balanced_statement_local_gets_flat(
      body, env,
    )
    assert_eq(actual, sl_balanced_tree_reference_flat(body, env))
    assert_true(actual.1 > 0)
    let @lib.Func(locals, _) = input.code_sec.unwrap().0[0]
    @validate.validate_module(
      input.with_code_sec(
        @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(actual.0))]),
      ),
    ).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
