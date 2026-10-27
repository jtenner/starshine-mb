///|
test "sparse collector rows retain every snapshot field and productive public DAE output" {
  row_check_productive()
  let input = row_fixture_same()
  row_check_input(input)
  let snapshot = dae_collect_original_boundary_snapshot(input)
  assert_eq(snapshot.private_result_same_operand_call_counts, [2, 0, 0, 0])
  let input = row_fixture_escaped()
  row_check_input(input)
  let snapshot = dae_collect_original_boundary_snapshot(input)
  let evidence : DaeOriginalDeadSuffixEscapedResultCallFacts = {
    dropped_calls: [true, true, true],
    undropped_calls: [false, false, false],
  }
  let facts = dae_collect_original_escaped_result_operand_call_facts_with_escaped(
    input,
    snapshot.escaped,
    evidence,
  )
  assert_eq(facts.dead_suffix_escaped_result_operand_call_counts, [1, 0, 0])
  assert_eq(facts.private_result_escaped_operand_call_counts, [1, 0, 0])
}

///|
test "sparse collector rows retain alias bodies self exclusion and new invocation state" {
  let original = row_fixture_same()
  let funcs = original.code_sec.unwrap().0
  let input = original.with_code_sec(
    @lib.CodeSec::new([funcs[0], funcs[1], funcs[1], funcs[3]]),
  )
  assert_true(
    physical_equal(input.code_sec.unwrap().0[1], input.code_sec.unwrap().0[2]),
  )
  row_check_input(input)
  assert_eq(
    dae_collect_original_boundary_snapshot(input).private_result_same_operand_call_counts,
    [2, 0, 0, 0],
  )
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[1]
  // This is an external alias write BETWEEN complete collector invocations.
  // The next query must recompute from the new body, never retain row stamps.
  body.push(@lib.Instruction::nop())
  row_check_input(input)
  assert_eq(
    dae_collect_original_boundary_snapshot(input).private_result_same_operand_call_counts,
    [2, 0, 0, 0],
  )
  row_check_input(
    pass_test_module_from_wat(
      "(module (func $self (param i32) (result i32) unreachable i32.const 1 call $self call $self) (func (export \"run\") (result i32) i32.const 7 call $self))",
    ),
  )
  let single = pass_test_module_from_wat(
    "(module (func $t (param i32) (result i32) local.get 0) " +
    "(func (result i32) unreachable i32.const 7 call $t call $t))",
  )
  for _ in 0..<2 {
    row_check_input(single)
    assert_eq(
      dae_collect_original_boundary_snapshot(single).private_result_same_operand_call_counts,
      [1, 0],
    )
  }
  let self_input = pass_test_module_from_wat(
    "(module (func $self (param i32) (result i32) unreachable i32.const 1 call $self call $self))",
  )
  assert_eq(
    dae_collect_original_boundary_snapshot(self_input).private_result_same_operand_call_counts,
    [0],
  )
}

///|
test "sparse collector rows retain empty import-only cold and noneligible modules" {
  for
    text in [
      "(module)", "(module (import \"m\" \"f\" (func)))", "(module (func) (func (export \"run\")))",
      "(module (func (result i32) i32.const 7))",
    ] {
    row_check_input(pass_test_module_from_wat(text))
  }
}

///|
test "sparse collector rows remove real same-operand row work only after complete behavior" {
  let input = row_fixture_same()
  row_check_input(input)
  row_check_productive()
  let saved = @binary.encode_module(input).unwrap()
  let snapshot = dae_collect_original_boundary_snapshot(input)
  let work = [0, 0, 0]
  let actual = row_probe_dae_collect_original_private_result_same_operand_call_counts_with_escaped(
    input,
    snapshot.escaped,
    row_work=Some(work),
  )
  assert_eq(actual, [2, 0, 0, 0])
  assert_eq(
    actual,
    row_ref_dae_collect_original_private_result_same_operand_call_counts_with_escaped(
      input,
      snapshot.escaped,
    ),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  // Actual row constructor and loop-site counters. Baseline must reach RED
  // here after complete output, trace, effects, validity and ownership gates.
  assert_eq(work, [1, 4, 0])
  let cold = pass_test_module_from_wat(
    "(module (func (result i32) i32.const 7))",
  )
  row_check_input(cold)
  let cold_work = [0, 0, 0]
  let cold_counts = row_probe_dae_collect_original_private_result_same_operand_call_counts_with_escaped(
    cold,
    [false],
    row_work=Some(cold_work),
  )
  assert_eq(cold_counts, [0])
  assert_true(cold_work[0] <= 1)
  assert_true(cold_work[1] <= 1)
  assert_eq(cold_work[2], 0)
  let empty = pass_test_module_from_wat("(module (func) (func))")
  row_check_input(empty)
  let empty_work = [0, 0, 0]
  assert_eq(
    row_probe_dae_collect_original_private_result_same_operand_call_counts_with_escaped(
      empty,
      [false, false],
      row_work=Some(empty_work),
    ),
    [0, 0],
  )
  assert_eq(empty_work, [0, 0, 0])
}

///|
test "sparse collector rows remove real escaped-operand row work only after complete behavior" {
  let input = row_fixture_escaped()
  row_check_input(input)
  row_check_productive()
  let saved = @binary.encode_module(input).unwrap()
  let snapshot = dae_collect_original_boundary_snapshot(input)
  let evidence : DaeOriginalDeadSuffixEscapedResultCallFacts = {
    dropped_calls: [true, true, true],
    undropped_calls: [false, false, false],
  }
  let work = [0, 0, 0]
  let actual = row_probe_dae_collect_original_escaped_result_operand_call_facts_with_escaped(
    input,
    snapshot.escaped,
    evidence,
    row_work=Some(work),
  )
  let expected = row_ref_dae_collect_original_escaped_result_operand_call_facts_with_escaped(
    input,
    snapshot.escaped,
    evidence,
  )
  assert_eq(actual.dead_suffix_escaped_result_operand_call_counts, [1, 0, 0])
  assert_eq(actual.private_result_escaped_operand_call_counts, [1, 0, 0])
  assert_eq(
    actual.dead_suffix_escaped_result_operand_call_counts,
    expected.dead_suffix_escaped_result_operand_call_counts,
  )
  assert_eq(
    actual.private_result_escaped_operand_call_counts,
    expected.private_result_escaped_operand_call_counts,
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_eq(work, [1, 3, 0])
}

///|
#skip("Dedicated width control; not a default stress test")
test "sparse collector rows scale cold result callers without dense scratch rows" {
  let text = StringBuilder()
  text.write_string("(module ")
  for _ in 0..<128 {
    text.write_string("(func (result i32) i32.const 7) ")
  }
  text.write_string(")")
  let input = pass_test_module_from_wat(text.to_string())
  row_check_input(input)
  let snapshot = dae_collect_original_boundary_snapshot(input)
  let work = [0, 0, 0]
  let actual = row_probe_dae_collect_original_private_result_same_operand_call_counts_with_escaped(
    input,
    snapshot.escaped,
    row_work=Some(work),
  )
  assert_eq(actual, Array::make(128, 0))
  assert_eq(work, [1, 128, 0])
}
