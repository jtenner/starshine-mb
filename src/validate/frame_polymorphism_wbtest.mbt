///|
test "dead child frames do not consume the parent execution escape depth" {
  for kind in 0..<3 {
    let entry = tc_state_new(empty_env(), [], false, BranchTcEscape(3))
    let result = match kind {
      0 => typecheck_block(entry, BlockType::void_(), Expr::new([]))
      1 => typecheck_loop(entry, BlockType::void_(), Expr::new([]))
      _ => typecheck_if(entry, BlockType::void_(), [], Some([]))
    }
    let out = result.unwrap()
    assert_false(out.reachable)
    assert_true(out.polymorphic)
    assert_eq(out.escape, BranchTcEscape(3))
  }
}

///|
test "nested block unreachable does not make the outer validation frame polymorphic" {
  let dead = [Instruction::unreachable_()]
  for
    (block_type, results) in [
      (BlockType::void_(), [ValType::i32()]),
      (BlockType::val_type(ValType::i32()), []),
      (BlockType::val_type(ValType::i32()), [ValType::f32()]),
    ] {
    let state = typecheck_block(
      make_state(empty_env(), []),
      block_type,
      Expr::new(dead),
    ).unwrap()
    assert_true(tc_state_validate_end_stack(state, results).is_err())
    assert_false(state.reachable)
  }
}

///|
test "nested frame validation rejects invalid bodies even after outer unreachable" {
  for kind in 0..<3 {
    for
      body in [
        [Instruction::i32_add()],
        [Instruction::i32_const(I32(1))],
        [Instruction::unreachable_(), Instruction::i64_const(I64(2))],
      ] {
      let entry = tc_state_new(empty_env(), [], false, TerminalTcEscape)
      let result = match kind {
        0 => typecheck_block(entry, BlockType::void_(), Expr::new(body))
        1 => typecheck_loop(entry, BlockType::void_(), Expr::new(body))
        _ => typecheck_if(entry, BlockType::void_(), body, Some([]))
      }
      assert_true(result.is_err())
    }
  }
}

///|
test "valid nested frame exits retain declared results and the outer concrete prefix" {
  for kind in 0..<3 {
    let entry = make_state(empty_env(), [ValType::f32()])
    let dead = [Instruction::unreachable_()]
    let state = match kind {
      0 =>
        typecheck_block(
          entry,
          BlockType::val_type(ValType::i32()),
          Expr::new(dead),
        )
      1 =>
        typecheck_loop(
          entry,
          BlockType::val_type(ValType::i32()),
          Expr::new(dead),
        )
      _ => {
        entry.stack.push(ValType::i32())
        typecheck_if(
          entry,
          BlockType::val_type(ValType::i32()),
          dead,
          Some(dead),
        )
      }
    }
    let state = state.unwrap()
    assert_eq(state.stack, [ValType::f32(), ValType::i32()])
    tc_state_validate_end_stack(state, [ValType::f32(), ValType::i32()]).unwrap()
    assert_false(state.reachable)
  }
}

///|
test "polymorphic select still rejects different concrete operand types" {
  let state = tc_state_new(
    empty_env(),
    [ValType::i32(), ValType::i64(), ValType::i32()],
    false,
    TerminalTcEscape,
  )
  assert_true(typecheck_select_untyped(state).is_err())
}

///|
test "polymorphic select preserves the available concrete operand type" {
  for ty in [ValType::i32(), ValType::i64(), ValType::f32(), ValType::f64()] {
    let state = tc_state_new(
      empty_env(),
      [ty, ValType::i32()],
      false,
      TerminalTcEscape,
    )
    assert_eq(typecheck_select_untyped(state).unwrap().stack, [ty])
  }
}

///|
test "polymorphic reference branches reject wrong concrete label prefixes" {
  let env = empty_env().with_label([ValType::i32(), ValType::funcref()])
  let null_env = empty_env().with_label([ValType::i32()])
  let make = fn(context, stack) {
    tc_state_new(context, stack, false, TerminalTcEscape)
  }
  assert_true(
    typecheck_br_on_null(
      make(null_env, [ValType::i64(), ValType::funcref()]),
      LabelIdx::new(0U),
    ).is_err(),
  )
  assert_true(
    typecheck_br_on_non_null(
      make(env, [ValType::i64(), ValType::funcref()]),
      LabelIdx::new(0U),
    ).is_err(),
  )
  let op = CastOp::new(true, true)
  let ht = HeapType::abs(AbsHeapType::func())
  assert_true(
    typecheck_br_on_cast(
      make(env, [ValType::i64(), ValType::funcref()]),
      LabelIdx::new(0U),
      op,
      ht,
      ht,
    ).is_err(),
  )
  assert_true(
    typecheck_br_on_cast_fail(
      make(env, [ValType::i64(), ValType::funcref()]),
      LabelIdx::new(0U),
      op,
      ht,
      ht,
    ).is_err(),
  )
  ignore(
    typecheck_br_on_null(
      make(null_env, [ValType::i32(), ValType::funcref()]),
      LabelIdx::new(0U),
    ).unwrap(),
  )
  ignore(
    typecheck_br_on_non_null(
      make(env, [ValType::i32(), ValType::funcref()]),
      LabelIdx::new(0U),
    ).unwrap(),
  )
}
