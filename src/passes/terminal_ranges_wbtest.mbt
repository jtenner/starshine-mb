///|
fn sl_terminal_fixture(
  type_ : String,
  value : String,
) -> (@validate.Env, @lib.Instruction) {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"tick\" (func $tick)) (func (local \{type_} \{type_}) \{value} drop))",
  )
  @validate.validate_module(input).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  (
    @validate.Env::new()
    .with_module(input)
    .with_locals(locals)
    .with_return_type(Some([])),
    body[0],
  )
}

///|
test "terminal copy admission preserves typed suffix decisions and barriers" {
  for
    (type_, value) in [
      ("i32", "i32.const 7"),
      ("i64", "i64.const 7"),
      ("externref", "ref.null extern"),
    ] {
    let (env, replacement) = sl_terminal_fixture(type_, value)
    let read = @lib.Instruction::local_get(@lib.LocalIdx::new(0U))
    for
      (body, accepted) in [
        ([read], true),
        ([@lib.Instruction::nop(), read], true),
        ([@lib.Instruction::call(@lib.FuncIdx::new(0U)), read], true),
        ([replacement, @lib.Instruction::drop(), read], true),
        ([read, @lib.Instruction::drop()], false),
        ([@lib.Instruction::nop(), replacement], false),
        ([@lib.Instruction::local_get(@lib.LocalIdx::new(1U))], false),
        (
          [
            replacement,
            @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
            read,
          ],
          false,
        ),
        (
          [
            replacement,
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            read,
          ],
          false,
        ),
        (
          [
            @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new([])),
            read,
          ],
          false,
        ),
        ([], false),
      ] {
      let saved = body.copy()
      let actual = run_hot_pipeline_raw_simplify_locals_try_rewrite_dupable_copy_terminal_value_suffix(
        body,
        0,
        replacement,
        [1],
        env,
      )
      assert_eq(
        actual,
        sl_terminal_reference_terminal_value_suffix(
          body,
          0,
          replacement,
          [1],
          env,
        ),
      )
      assert_eq(actual is Some(_), accepted)
      assert_eq(body, saved)
    }
  }
}

///|
test "terminal copy intentionally rejects an invalid local environment" {
  let body = [@lib.Instruction::local_get(@lib.LocalIdx::new(0U))]
  let env = @validate.Env::new()
  let replacement = @lib.Instruction::i32_const(@lib.I32(7))
  assert_eq(
    run_hot_pipeline_raw_simplify_locals_try_rewrite_dupable_copy_terminal_value_suffix(
      body,
      0,
      replacement,
      [],
      env,
    ),
    None,
  )
}

///|
test "terminal copy preserves a prevalidated nonnullable local environment" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"produce\" (func (result (ref extern)))) (func (local (ref extern)) call 0 local.set 0 local.get 0 drop))",
  )
  @validate.validate_module(input).unwrap()
  let @lib.Func(locals, _) = input.code_sec.unwrap().0[0]
  let env = @validate.Env::new().with_module(input).with_locals(locals)
  let body = [@lib.Instruction::local_get(@lib.LocalIdx::new(0U))]
  // Suffix checking inherits a validated prefix, not function-entry initialization.
  assert_eq(
    run_hot_pipeline_raw_simplify_locals_try_rewrite_dupable_copy_terminal_value_suffix(
      body,
      0,
      body[0],
      [],
      env,
    ),
    Some(([@lib.Instruction::nop(), body[0]], 1)),
  )
}

///|
test "terminal and next-if ranges preserve offsets and future-read barriers" {
  let (env, replacement) = sl_terminal_fixture("i32", "i32.const 7")
  let read = @lib.Instruction::local_get(@lib.LocalIdx::new(0U))
  let write = @lib.Instruction::local_set(@lib.LocalIdx::new(0U))
  let branch = @lib.Instruction::if_(@lib.BlockType::void_(), [], None)
  for
    suffix in [
      [read],
      [@lib.Instruction::nop(), read],
      [read, branch],
      [read, branch, read, @lib.Instruction::drop()],
      [read, branch, replacement, write, read, @lib.Instruction::drop()],
      [replacement, write, read],
      [],
    ] {
    let body = [replacement, write]
    for instr in suffix {
      body.push(instr)
    }
    let saved = body.copy()
    assert_eq(
      run_hot_pipeline_raw_simplify_locals_try_rewrite_dupable_copy_terminal_value_suffix(
        body,
        0,
        replacement,
        [],
        env,
        start=2,
      ),
      sl_terminal_reference_terminal_value_suffix(
        suffix,
        0,
        replacement,
        [],
        env,
      ),
    )
    assert_eq(
      run_hot_pipeline_raw_simplify_locals_try_rewrite_dupable_copy_into_next_if_condition(
        body,
        0,
        replacement,
        [],
        start=2,
      ),
      sl_terminal_reference_into_next_if_condition(suffix, 0, replacement, []),
    )
    assert_eq(body, saved)
  }
}
