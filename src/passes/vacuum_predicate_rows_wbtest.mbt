///|
test "vacuum read-only predicate rows retain exact call-prefix recognition without copying clean rows" {
  let body = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
  ]
  let saved = body.copy()
  let row = vacuum_predicate_non_nops(body)
  assert_eq(row, saved)
  assert_true(
    run_hot_pipeline_raw_vacuum_prefix_block_starts_two_arg_call_result_local_set_release(
      row,
    ),
  )
  assert_eq(body, saved)
  // Predicate-only rows borrow clean input instead of allocating a full copy.
  assert_true(physical_equal(row, body))
}

///|
test "vacuum predicate Nop filtering preserves order and owns changed rows" {
  let nop = @lib.Instruction::nop()
  let seven = @lib.Instruction::i32_const(@lib.I32(7))
  let nine = @lib.Instruction::i32_const(@lib.I32(9))
  for body in [[nop, seven, nop, nine, nop], [seven, nop, nine], [nop]] {
    let saved = body.copy()
    let expected = body.filter(fn(instr) { instr != nop })
    let row = vacuum_predicate_non_nops(body)
    assert_eq(row, expected)
    assert_false(physical_equal(row, body))
    row.push(@lib.Instruction::unreachable_())
    assert_eq(body, saved)
  }
  let empty : Array[@lib.Instruction] = []
  assert_eq(vacuum_predicate_non_nops(empty), [])
}

///|
test "vacuum and DAE2O dispatcher preserve predicate input ownership" {
  let input = pass_test_module_from_wat(
    "(module (func $f (param i32) (result i32) local.get 0) (func (export \"run\") (param i32) (result i32) (local i32) block nop local.get 0 call $f local.set 1 nop local.get 1 drop end local.get 0))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for name in ["vacuum", "dae2-optimizing"] {
    let actual = run_hot_pipeline(input, HotPipelineOptions::new(), [name]).unwrap()
    @validate.validate_module(actual).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "exact-width vacuum predicates reject wide rows with bounded reads" {
  let value = @lib.Instruction::i32_const(@lib.I32(7))
  let nop = @lib.Instruction::nop()
  for limit in [0, 6, 13] {
    for prefix in [[], [nop, nop]] {
      let body = prefix.copy()
      for _ in 0..<32 {
        body.push(value)
      }
      body.push(nop)
      let saved = body.copy()
      let visits = [0]
      // More than limit values is intentionally not an admitted exact-width
      // predicate row, even though the containing instruction list is valid.
      assert_true(
        vacuum_predicate_non_nops_at_most(body, limit, visits=Some(visits))
        is None,
      )
      assert_eq(body, saved)
      assert_eq(visits[0], prefix.length() + limit + 1)
    }
  }
}

///|
test "bounded vacuum rows preserve filtered order and borrowed or owned storage" {
  let seven = @lib.Instruction::i32_const(@lib.I32(7))
  let nine = @lib.Instruction::i32_const(@lib.I32(9))
  let nop = @lib.Instruction::nop()
  for body in [[], [seven, nine], [nop, seven, nop, nine, nop], [nop, nop]] {
    let saved = body.copy()
    let expected = vacuum_predicate_non_nops(body)
    let row = vacuum_predicate_non_nops_at_most(body, expected.length()).unwrap()
    assert_eq(row, expected)
    assert_eq(physical_equal(row, body), body.length() == expected.length())
    if !physical_equal(row, body) {
      row.push(seven)
    }
    assert_eq(body, saved)
  }
}

///|
test "bounded vacuum tag predicates retain both accepted group counts with Nop padding" {
  for groups in [2, 4] {
    let start = if groups == 4 { 0 } else { 4 }
    let tag = if groups == 4 { 20 } else { 72 }
    let calls = Array::makei(groups, fn(index) {
      "local.get 0 i32.const \{start + index} call $f local.set \{index + 1} "
    }).join("")
    let input = pass_test_module_from_wat(
      "(module (import \"host\" \"f\" (func $f (param i32 i32) (result i32))) (memory 1) (func (param i32) (local i32 i32 i32 i32) \{calls} local.get 1 i32.load i32.const \{tag} i32.eq if nop end))",
    )
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    assert_true(
      run_hot_pipeline_raw_vacuum_body_is_call_local_set_tag_cascade_if_wrapper_candidate(
        body,
      ),
    )
    let padded = []
    for instr in body {
      padded.push(@lib.Instruction::nop())
      padded.push(@lib.Instruction::nop())
      padded.push(instr)
    }
    assert_true(
      run_hot_pipeline_raw_vacuum_body_is_call_local_set_tag_cascade_if_wrapper_candidate(
        padded,
      ),
    )
    @validate.validate_module(
      input.with_code_sec(
        @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(padded))]),
      ),
    ).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
