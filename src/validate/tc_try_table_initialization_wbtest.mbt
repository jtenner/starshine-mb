///|
fn tc_try_mask_fixture(width : Int32) -> TcState {
  let env = empty_env()
    .with_locals(Locals::single(width.to_uint(), ValType::i32()))
    .with_label([])
  let entry = make_state(env, [])
  entry.initialized_locals.fill(false)
  entry
}

///|
fn tc_try_mask_assert_equivalent(
  entry : TcState,
  block_type : BlockType,
  catches : Array[Catch],
  body : Expr,
) -> TcResult raise {
  let saved_mask = entry.initialized_locals.copy()
  let expected = tc_try_table_owned_reference(
    tc_state_with_stack(entry, entry.stack),
    block_type,
    catches,
    body,
  )
  let actual = typecheck_try_table(
    tc_state_with_stack(entry, entry.stack),
    block_type,
    catches,
    body,
  )
  match (actual, expected) {
    (Ok(actual), Ok(expected)) => {
      assert_true(physical_equal(actual.env, expected.env))
      assert_eq(actual.stack, expected.stack)
      assert_eq(actual.reachable, expected.reachable)
      assert_eq(actual.polymorphic, expected.polymorphic)
      assert_eq(actual.escape, expected.escape)
      assert_eq(
        actual.reachable_escape_depths,
        expected.reachable_escape_depths,
      )
      assert_eq(actual.initialized_locals, expected.initialized_locals)
    }
    (Err(actual), Err(expected)) => assert_eq(actual, expected)
    _ => assert_true(false, msg="try_table reference and current disagree")
  }
  assert_eq(entry.initialized_locals, saved_mask)
  actual
}

///|
test "try_table initialization remains local to its body and sibling controls" {
  for width in [1, 17, 256] {
    let entry = tc_try_mask_fixture(width)
    let local = LocalIdx::new((width - 1).to_uint())
    let body = Expr::new([
      Instruction::i32_const(I32(7)),
      Instruction::local_set(local),
      Instruction::local_get(local),
      Instruction::drop(),
    ])
    let actual = tc_try_mask_assert_equivalent(
      entry,
      BlockType::void_(),
      [Catch::all(LabelIdx::new(0U))],
      body,
    ).unwrap()
    assert_false(actual.initialized_locals[width - 1])
    // Intentionally invalid: the parent and sibling did not initialize it.
    assert_true(typecheck_local_get(actual, local) is Err(_))
    assert_true(typecheck_local_get(entry, local) is Err(_))
    let invalid_sibling = Expr::new([
      Instruction::local_get(local),
      Instruction::drop(),
    ])
    assert_true(
      tc_try_mask_assert_equivalent(
        entry,
        BlockType::void_(),
        [],
        invalid_sibling,
      )
      is Err(_),
    )
  }
}

///|
test "try_table failed body and catch checks preserve entry initialization and error order" {
  let entry = tc_try_mask_fixture(17)
  let written = [
    Instruction::i32_const(I32(7)),
    Instruction::local_set(LocalIdx::new(16U)),
  ]
  let invalid_catch = [Catch::all(LabelIdx::new(9U))]
  let catch_failure = tc_try_mask_assert_equivalent(
    entry,
    BlockType::void_(),
    invalid_catch,
    Expr::new(written),
  )
  assert_true(catch_failure is Err("Invalid catch label index"))
  let invalid_body = written.copy()
  invalid_body.push(Instruction::local_get(LocalIdx::new(0U)))
  let body_failure = tc_try_mask_assert_equivalent(
    entry,
    BlockType::void_(),
    invalid_catch,
    Expr::new(invalid_body),
  )
  assert_true(body_failure is Err(error) && error.contains("instruction[2]"))
  assert_true(
    body_failure is Err(error) && error != "Invalid catch label index",
  )
}

///|
test "nested try_table initialization cannot change a later outer write owner" {
  let entry = tc_try_mask_fixture(17)
  let local = LocalIdx::new(16U)
  let inner = Instruction::try_table(
    BlockType::void_(),
    [],
    Expr::new([Instruction::i32_const(I32(3)), Instruction::local_set(local)]),
  )
  let body = Expr::new([
    inner,
    Instruction::i32_const(I32(7)),
    Instruction::local_tee(local),
    Instruction::drop(),
    Instruction::local_get(local),
    Instruction::drop(),
  ])
  let actual = tc_try_mask_assert_equivalent(
    entry,
    BlockType::void_(),
    [],
    body,
  ).unwrap()
  assert_false(actual.initialized_locals[16])
}

///|
test "try_table non-null local initialization does not escape its control frame" {
  let heap_type = HeapType::abs(AbsHeapType::func())
  let local_type = ValType::ref_type(RefType::new(false, heap_type))
  let env = empty_env().with_locals(Locals::single(1U, local_type))
  let entry = make_state(env, [])
  entry.initialized_locals[0] = false
  let local = LocalIdx::new(0U)
  let body = Expr::new([
    Instruction::ref_null(heap_type),
    Instruction::ref_as_non_null(),
    Instruction::local_set(local),
    Instruction::local_get(local),
    Instruction::drop(),
  ])
  let actual = tc_try_mask_assert_equivalent(
    entry,
    BlockType::void_(),
    [],
    body,
  ).unwrap()
  assert_false(entry.initialized_locals[0])
  assert_false(actual.initialized_locals[0])
  // Intentionally invalid: a non-null parent local has no initialization.
  assert_true(typecheck_local_get(actual, local) is Err(_))
}
