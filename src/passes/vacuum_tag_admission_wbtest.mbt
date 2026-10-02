///|
test "indexed tag candidate gate intentionally rejects other top-level lengths" {
  for width in [0, 1, 50, 52, 56, 58, 256] {
    let body = Array::make(width, @lib.Instruction::drop())
    body.push(@lib.Instruction::nop())
    assert_eq(vacuum_indexed_tag_candidate_non_nops(body), None)
  }
}

///|
test "indexed tag candidate gate owns exact rows and ignores only top-level nops" {
  for width in [51, 57] {
    let nested = @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::nop()]),
    )
    let expected = Array::make(width, nested)
    let body : Array[@lib.Instruction] = [@lib.Instruction::nop()]
    for instr in expected {
      body.push(instr)
      body.push(@lib.Instruction::nop())
    }
    let row = vacuum_indexed_tag_candidate_non_nops(body).unwrap()
    assert_eq(row, expected)
    assert_eq(row.capacity(), width)
    row[0] = @lib.Instruction::drop()
    assert_eq(body[1], nested)
    assert_eq(expected[0], nested)
  }
}

///|
test "indexed tag candidates retain both shapes nop padding and unreachable rejection" {
  for
    body in [
      pass_manager_test_vacuum_indexed_tag_cascade_body(),
      pass_manager_test_vacuum_shifted_indexed_tag_cascade_body(),
    ] {
    let admits = run_hot_pipeline_raw_vacuum_body_is_indexed_call_local_set_tag_cascade_if_wrapper_candidate
    assert_true(admits(body))
    let padded : Array[@lib.Instruction] = [@lib.Instruction::nop()]
    for instr in body {
      padded.push(instr)
      padded.push(@lib.Instruction::nop())
    }
    assert_true(admits(padded))
    let last = body.length() - 1
    let changed = body.copy()
    let @lib.If(type_, then_body, else_body) = changed[last]
    changed[last] = @lib.Instruction::if_(
      type_,
      then_body + [@lib.Instruction::unreachable_()],
      else_body,
    )
    assert_false(admits(changed))
    assert_true(admits(body))
    // Same supported length but an incorrect index/call prefix stays rejected.
    changed[0] = @lib.Instruction::drop()
    assert_false(admits(changed))
  }
}
