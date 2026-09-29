///|
test "DAE scalar needs scan retains exact pure arithmetic suffixes without a heap need stack" {
  let input = [
    @lib.Instruction::i32_const(@lib.I32(99)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::i32_add(),
  ]
  let saved = input.copy()
  let stacks = [0]
  assert_eq(
    dae_find_droppable_pure_stack_expr_start_with_scalar_needs(
      input,
      None,
      need_stacks=Some(stacks),
    ),
    Some(1),
  )
  assert_eq(stacks[0], 0)
  assert_eq(input, saved)
  assert_eq(
    dae_find_droppable_pure_stack_expr_start_with_scalar_needs([], None),
    None,
  )
  assert_eq(
    dae_find_droppable_pure_stack_expr_start_with_scalar_needs(
      [@lib.Instruction::i32_add()],
      None,
    ),
    None,
  )
}

///|
test "DAE scalar needs scan preserves marked reference operand ordering and null traps" {
  let any = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let eq = @lib.HeapType::abs(@lib.AbsHeapType::eq())
  let i31 = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  for
    case in [
      (
        [
          @lib.Instruction::i32_const(@lib.I32(5)),
          @lib.Instruction::ref_i31(),
          @lib.Instruction::i31_get_s(),
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::ref_i31(),
          @lib.Instruction::i31_get_u(),
          @lib.Instruction::i32_add(),
        ],
        Some(0),
      ),
      (
        [
          @lib.Instruction::i32_const(@lib.I32(11)),
          @lib.Instruction::ref_i31(),
          @lib.Instruction::ref_as_non_null(),
        ],
        Some(0),
      ),
      (
        [
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i31_get_s(),
        ],
        None,
      ),
      (
        [@lib.Instruction::ref_null(any), @lib.Instruction::ref_cast(true, eq)],
        Some(0),
      ),
      (
        [
          @lib.Instruction::ref_null(any),
          @lib.Instruction::ref_cast(false, i31),
        ],
        None,
      ),
    ] {
    let (body, expected) = case
    let saved = body.copy()
    let stacks = [0]
    assert_eq(
      dae_find_droppable_pure_stack_expr_start_with_scalar_needs(
        body,
        None,
        need_stacks=Some(stacks),
      ),
      expected,
    )
    assert_eq(stacks[0], 1)
    assert_eq(body, saved)
  }
}

///|
test "DAE scalar needs scan retains constant trap proofs and observable argument effects" {
  for
    case in [
      ("i32.const 8 i32.const 2 i32.div_s", Some(0)),
      ("i32.const 8 i32.const 0 i32.div_s", None),
      ("local.get 0 i32.const 2 i32.div_s", None),
      ("f64.const 3 i32.trunc_f64_s", Some(0)),
      ("f64.const nan i32.trunc_f64_s", None),
      ("call $value i32.const 9 i32.add", None),
      ("call $value drop i32.const 9", Some(2)),
    ] {
    let (source, expected) = case
    let mod_ = pass_test_module_from_wat(
      "(module (import \"m\" \"value\" (func $value (result i32))) (func (param i32) (result i32) \{source}))",
    )
    let @lib.Func(_, @lib.Expr(body)) = mod_.code_sec.unwrap().0[0]
    assert_eq(
      dae_find_droppable_pure_stack_expr_start_with_scalar_needs(
        body,
        mod_.type_sec,
      ),
      expected,
    )
  }
}

///|
test "DAE marked suffix handoff preserves pending sibling operands and excludes an observable prefix" {
  let body = [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(5)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::i31_get_s(),
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::i31_get_u(),
    @lib.Instruction::i32_add(),
  ]
  let saved = body.copy()
  // The last i31.get has been scanned; one arithmetic sibling remains.
  let needs = [0, 1]
  assert_eq(
    dae_find_droppable_marked_stack_expr_start(body, None, 5, needs),
    Some(1),
  )
  assert_eq(needs, [])
  assert_eq(body, saved)
  // Intentionally unknown nullable operand: i31.get can trap.
  assert_eq(
    dae_find_droppable_marked_stack_expr_start(
      [@lib.Instruction::local_get(@lib.LocalIdx::new(0U))],
      None,
      0,
      [1],
    ),
    None,
  )
}
