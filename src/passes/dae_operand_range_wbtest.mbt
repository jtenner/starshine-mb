///|
test "DAE borrowed operand proofs stay inside the owned argument range" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(99)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ]
  let saved = body.copy()
  assert_eq(
    dae_find_droppable_pure_stack_expr_start_in_range(body, None, 1, 4, None),
    Some(1),
  )
  // Intentionally incomplete owned operand: do not consume an earlier argument.
  assert_eq(
    dae_find_droppable_pure_stack_expr_start_in_range(body, None, 2, 4, None),
    None,
  )
  assert_eq(body, saved)
}

///|
test "DAE range boundaries constrain constant and marked reference trap proofs" {
  for
    (source, first) in [
      ("i32.const 8 i32.const 2 i32.div_s", 0),
      ("f64.const 3 i32.trunc_f64_s", 0),
      ("i32.const 5 ref.i31 i31.get_s i32.const 7 ref.i31 i31.get_u i32.add", 0),
    ] {
    let input = pass_test_module_from_wat(
      "(module (func (result i32) \{source}))",
    )
    let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    assert_eq(
      dae_find_droppable_pure_stack_expr_start_in_range(
        body,
        None,
        first,
        body.length(),
        None,
      ),
      Some(first),
    )
    assert_eq(
      dae_find_droppable_pure_stack_expr_start_in_range(
        body,
        None,
        first + 1,
        body.length(),
        None,
      ),
      None,
    )
  }
}

///|
test "DAE borrowed range proofs reject intentionally invalid or empty offsets" {
  let body = [@lib.Instruction::i32_const(@lib.I32(7))]
  for (first, end) in [(-1, 1), (0, 2), (1, 0), (0, 0), (1, 1)] {
    assert_eq(
      dae_find_droppable_pure_stack_expr_start_in_range(
        body,
        None,
        first,
        end,
        None,
      ),
      None,
    )
  }
}

///|
test "DAE dropped multi-result blocks retain an owned observable prefix without copying result candidates" {
  let input = pass_test_module_from_wat(
    "(module (type $pair (func (result i32 i64))) (import \"m\" \"value\" (func $v (result i32))) (func block (type $pair) call $v drop i32.const 7 i64.const 11 end drop drop))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (count, prefix) = dae_instr_dropped_pure_multivalue_block_prefix(
    body[0],
    input.type_sec,
  ).unwrap()
  assert_eq(count, 2)
  assert_eq(prefix, [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::drop(),
  ])
  prefix[0] = @lib.Instruction::nop()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
