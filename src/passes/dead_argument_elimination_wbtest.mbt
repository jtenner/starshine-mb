///|
fn dae_wbtest_call_summary_fixture() -> @lib.Module {
  let void_type = @lib.TypeIdx::new(0U)
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([void_type, void_type, void_type]))
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("entry"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(1U))]),
      ),
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::call(@lib.FuncIdx::new(1U)),
          @lib.Instruction::call(@lib.FuncIdx::new(2U)),
          @lib.Instruction::call(@lib.FuncIdx::new(2U)),
        ]),
      ),
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
    ]),
  )
}

///|
test "dae call boundary facts expose reusable forwarding gates" {
  let facts = dae_make_call_boundary_facts(
    [false, true, false],
    [false, false, true],
    [[1], [0, 2], []],
  )
  assert_true(dae_call_boundary_allows_forwarding(facts, 0))
  assert_false(dae_call_boundary_allows_forwarding(facts, 1))
  assert_false(dae_call_boundary_allows_forwarding(facts, 2))
  assert_eq(dae_call_boundary_direct_callers(facts, 1), [0, 2])
  assert_eq(dae_call_boundary_direct_callers(facts, 4), [])
}

///|
test "dae target callsite evidence centralizes direct and return-call matching" {
  let direct = @lib.Instruction::call(@lib.FuncIdx::new(2U))
  let tail = @lib.Instruction::return_call(@lib.FuncIdx::new(2U))
  match dae_target_callsite_evidence(direct, 2, DaeTargetDirectCallOnly) {
    Some(evidence) => {
      assert_eq(evidence.callee_abs, 2)
      assert_false(evidence.is_return_call)
    }
    None => fail("expected direct-call target evidence")
  }
  match dae_target_callsite_evidence(tail, 2, DaeTargetDirectCallOnly) {
    Some(_) => fail("direct-only target evidence should reject return_call")
    None => ()
  }
  match dae_target_callsite_evidence(tail, 2, DaeTargetDirectOrReturnCall) {
    Some(evidence) => {
      assert_eq(evidence.callee_abs, 2)
      assert_true(evidence.is_return_call)
    }
    None => fail("expected return-call target evidence in tail-aware mode")
  }
  match dae_target_callsite_evidence(direct, 3, DaeTargetDirectOrReturnCall) {
    Some(_) => fail("wrong callee must not match target evidence")
    None => ()
  }
  match dae_target_callsite_evidence(direct, -1, DaeTargetDirectOrReturnCall) {
    Some(_) => fail("negative callee must not match target evidence")
    None => ()
  }
}

///|
test "dae call boundary candidate centralizes owned callee counts" {
  let current : DaeCurrentCallFacts = {
    direct_calls: [2, 0, 1, 4],
    tail_calls: [false, false, true, false],
    direct_callers: [[1, 3], [], [0], [0, 1, 2]],
    dropped_calls: [1, 0, 0, 3],
    escaped: [false, true, false, false],
  }
  let facts = dae_call_boundary_facts_from_current(current)
  match dae_call_boundary_candidate(facts, 0, def_idx=2) {
    Some(candidate) => {
      assert_true(candidate.owned)
      assert_eq(candidate.direct_call_count, 2)
      assert_eq(candidate.dropped_call_count, 1)
      assert_eq(candidate.direct_callers, [1, 3])
      assert_false(candidate.has_self_direct_caller)
      assert_true(candidate.allows_nonself_direct_rewrite)
    }
    None => fail("expected owned boundary candidate")
  }
  match dae_call_boundary_candidate(facts, 3, def_idx=1) {
    Some(candidate) => {
      assert_true(candidate.owned)
      assert_true(candidate.has_self_direct_caller)
      assert_false(candidate.allows_nonself_direct_rewrite)
    }
    None => fail("expected self-caller boundary candidate")
  }
  match dae_call_boundary_candidate(facts, 1) {
    Some(candidate) => assert_false(candidate.owned)
    None => fail("expected escaped boundary candidate")
  }
  match dae_call_boundary_candidate(facts, 2) {
    Some(candidate) => assert_false(candidate.owned)
    None => fail("expected tail-call boundary candidate")
  }
  match dae_call_boundary_candidate(facts, 6) {
    Some(_) => fail("out-of-range boundary candidate must be rejected")
    None => ()
  }
}

///|
test "dae dropped result candidate centralizes call facts and owned eligibility" {
  let current : DaeCurrentCallFacts = {
    direct_calls: [2, 1, 3],
    tail_calls: [false, false, true],
    direct_callers: [[0, 1], [2], [1, 2]],
    dropped_calls: [2, 1, 3],
    escaped: [false, true, false],
  }
  match dae_dropped_result_candidate_from_current_call_facts(current, 0) {
    Some(candidate) => {
      assert_eq(candidate.callee_abs, 0)
      assert_eq(candidate.direct_call_count, 2)
      assert_eq(candidate.dropped_call_count, 2)
      assert_eq(candidate.direct_callers, [0, 1])
      assert_true(candidate.owned)
      assert_true(candidate.all_direct_calls_dropped)
      assert_true(candidate.owned_dropped_result_candidate)
    }
    None => fail("expected dropped-result candidate")
  }
  match dae_dropped_result_candidate_from_current_call_facts(current, 1) {
    Some(candidate) => {
      assert_false(candidate.owned)
      assert_true(candidate.all_direct_calls_dropped)
      assert_false(candidate.owned_dropped_result_candidate)
    }
    None => fail("expected escaped dropped-result facts")
  }
  match dae_dropped_result_candidate_from_current_call_facts(current, 2) {
    Some(candidate) => {
      assert_false(candidate.owned)
      assert_true(candidate.all_direct_calls_dropped)
      assert_false(candidate.owned_dropped_result_candidate)
    }
    None => fail("expected tail-call dropped-result facts")
  }
  match dae_dropped_result_candidate_from_current_call_facts(current, 4) {
    Some(_) => fail("out-of-range dropped-result candidate must be rejected")
    None => ()
  }
}

///|
test "dae dropped result candidate reuses boundary candidate facts" {
  let current : DaeCurrentCallFacts = {
    direct_calls: [2, 0, 1, 4],
    tail_calls: [false, false, true, false],
    direct_callers: [[1, 3], [], [0], [0, 1, 2]],
    dropped_calls: [2, 0, 1, 3],
    escaped: [false, true, false, false],
  }
  let boundary_facts = dae_call_boundary_facts_from_current(current)
  match dae_dropped_result_candidate_from_boundary_facts(boundary_facts, 0) {
    Some(candidate) => {
      assert_eq(candidate.direct_call_count, 2)
      assert_eq(candidate.dropped_call_count, 2)
      assert_eq(candidate.direct_callers, [1, 3])
      assert_true(candidate.owned)
      assert_true(candidate.all_direct_calls_dropped)
      assert_true(candidate.owned_dropped_result_candidate)
    }
    None => fail("expected dropped-result candidate from boundary facts")
  }
  match dae_dropped_result_candidate_from_boundary_facts(boundary_facts, 3) {
    Some(candidate) => {
      assert_true(candidate.owned)
      assert_false(candidate.all_direct_calls_dropped)
      assert_false(candidate.owned_dropped_result_candidate)
    }
    None => fail("expected partial dropped-result boundary candidate")
  }
  match dae_dropped_result_candidate_from_boundary_facts(boundary_facts, 2) {
    Some(candidate) => {
      assert_false(candidate.owned)
      assert_true(candidate.all_direct_calls_dropped)
      assert_false(candidate.owned_dropped_result_candidate)
    }
    None => fail("expected tail-call dropped-result boundary facts")
  }
  match dae_dropped_result_candidate_from_boundary_facts(boundary_facts, 6) {
    Some(_) => fail("out-of-range boundary candidate must be rejected")
    None => ()
  }
}

///|
test "dae module boundary snapshot carries counts facts and type indices" {
  let void_type = @lib.TypeIdx::new(0U)
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("imp"),
          @lib.ExternType::func(void_type),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([void_type, void_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(2U))]),
        ),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
  let snapshot = dae_collect_module_boundary_snapshot(mod_)
  assert_eq(snapshot.imported, 1)
  assert_eq(snapshot.defined, 2)
  assert_eq(snapshot.total, 3)
  assert_eq(snapshot.type_indices.length(), 3)
  assert_eq(snapshot.call_facts.direct_calls[2], 1)
  match dae_call_boundary_candidate(snapshot.boundary_facts, 2) {
    Some(candidate) => {
      assert_true(candidate.owned)
      assert_eq(candidate.direct_call_count, 1)
      assert_eq(candidate.direct_callers, [0])
    }
    None => fail("expected boundary candidate from snapshot facts")
  }
}

///|
test "dae original boundary snapshot carries original counts escapes and call summaries" {
  let void_type = @lib.TypeIdx::new(0U)
  let param_type = @lib.TypeIdx::new(1U)
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], []),
          ),
        ),
      ]),
    )
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("imp"),
          @lib.ExternType::func(void_type),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([param_type, void_type]))
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("entry"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(1U)),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(2U))]),
        ),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
  let snapshot = dae_collect_original_boundary_snapshot(mod_)
  assert_eq(snapshot.imported, 1)
  assert_eq(snapshot.defined, 2)
  assert_eq(snapshot.total, 3)
  assert_eq(snapshot.param_counts, [1, 0])
  assert_true(snapshot.escaped[1])
  assert_false(snapshot.escaped[2])
  assert_eq(snapshot.call_summary.call_counts, [0, 1])
  assert_eq(snapshot.call_summary.prior_call_counts, [0, 1])
  assert_eq(snapshot.call_summary.nonself_undropped_call_counts, [0, 1])
}

///|
test "dae original result preservation evidence centralizes shared guards" {
  let context = dae_original_result_preservation_context(
    [0, 1, 0],
    [0, 3, 1],
    [0, 1, 0],
    [0, 1, 0],
    [0, 2, 0],
    [0, 2, 0],
    [0, 0, 4],
    [0, 0, 0],
    [false, true, false],
    [false, true, false],
    [false, false, false],
    [0, 0, 0],
    [0, 0, 0],
    [false, true, false],
    [false, true, false],
    [false, true, false],
    [false, false, false],
    [false, false, false],
    [0, 5, 0],
    [0, 7, 0],
    [0, 0, 0],
  )
  let evidence = dae_original_result_preservation_evidence_from_context(
    1, context,
  )
  assert_true(evidence.same_self_result_operand)
  assert_false(evidence.result_from_undropped_self_caller)
  assert_true(evidence.escaped_result_operand_chain)
  assert_true(evidence.mixed_self_result)
  assert_false(evidence.escaped_block_self_result)
  assert_true(evidence.param_operand_self_result_side_callee)
  assert_false(evidence.undropped_self_result_from_no_param_dropped_caller)
  assert_false(evidence.dropped_escaped_result_under_self_caller)
  assert_true(evidence.parameterized_undropped_self_side_chain)
  assert_true(evidence.result_side_chain_cleanup_preservation)
  assert_true(dae_original_result_preservation_any(evidence))
  let paramless_evidence = dae_original_result_preservation_evidence_from_context(
    2, context,
  )
  assert_true(paramless_evidence.escaped_result_operand_chain)
  assert_false(paramless_evidence.mixed_self_result)
}

///|
test "dae original result preservation row centralizes indexed guard facts" {
  let context = dae_original_result_preservation_context(
    [0, 1, 0],
    [0, 3, 1],
    [0, 1, 0],
    [0, 1, 0],
    [0, 2, 0],
    [0, 2, 0],
    [0, 0, 4],
    [0, 0, 0],
    [false, true, false],
    [false, true, false],
    [false, false, false],
    [0, 0, 0],
    [0, 0, 0],
    [false, true, false],
    [false, true, false],
    [false, true, false],
    [false, false, false],
    [false, false, false],
    [0, 5, 0],
    [0, 7, 0],
    [0, 0, 0],
  )
  let row = dae_original_result_preservation_row_from_context(1, context)
  assert_eq(row.param_count, 1)
  assert_eq(row.call_count, 3)
  assert_eq(row.active_nonself_call_count, 1)
  assert_eq(row.nonself_undropped_call_count, 2)
  assert_eq(row.self_call_count, 2)
  assert_true(row.dead_suffix_same_self_result_operand_call)
  assert_true(row.dead_suffix_undropped_self_call_param_operand)
  assert_eq(row.dead_suffix_calls_from_param_operand_self_result_caller, 5)
  assert_eq(row.dead_suffix_escaped_result_operand_call_count, 7)
  let row_evidence = dae_original_result_preservation_evidence_from_row(row)
  assert_true(row_evidence.same_self_result_operand)
  assert_true(row_evidence.escaped_result_operand_chain)
  assert_true(row_evidence.param_operand_self_result_side_callee)
  assert_true(row_evidence.parameterized_undropped_self_side_chain)
  assert_true(row_evidence.result_side_chain_cleanup_preservation)
  let no_param_guard = dae_original_no_param_dropped_caller_guard_evidence_from_row(
    row,
  )
  assert_false(
    dae_should_preserve_undropped_self_result_from_no_param_dropped_caller_evidence(
      no_param_guard,
    ),
  )
  let side_chain = dae_original_parameterized_undropped_self_side_chain_evidence_from_row(
    row,
  )
  assert_true(
    dae_should_preserve_parameterized_undropped_self_side_chain_evidence(
      side_chain,
    ),
  )
  let empty_row = dae_original_result_preservation_row_from_context(9, context)
  assert_eq(empty_row.param_count, 0)
  assert_eq(empty_row.call_count, 0)
  assert_false(empty_row.dead_suffix_undropped_self_call)
  assert_false(
    dae_original_result_preservation_any(
      dae_original_result_preservation_evidence_from_row(empty_row),
    ),
  )
}

///|
test "dae original result removal prune row centralizes indexed guard facts" {
  let later_row = dae_original_result_removal_prune_row(
    1,
    [0, 1, 1],
    [0, 1, 3],
    [0, 0, 1],
    [0, 0, 1],
    [0, 0, 0],
    [0, 0, 0],
    [0, 0, 1],
    [0, 0, 0],
    [false, false, false],
    [false, false, true],
    [false, false, false],
    [false, false, false],
    [false, false, false],
    [false, false, false],
    [false, true, false],
    [0, 2, 0],
    [false, false, false],
    [0, 0, 3],
    [false, false, true],
    [0, 0, 4],
    [0, 5, 0],
  )
  assert_eq(later_row.param_count, 1)
  assert_eq(later_row.self_call_count, 0)
  assert_true(later_row.dead_suffix_dropped_earlier_result_call)
  assert_eq(later_row.later_dead_suffix_dropped_call_count, 2)
  assert_eq(later_row.dead_suffix_mixed_dropped_undropped_call_count, 5)
  assert_true(dae_should_prune_later_mutual_dropped_result_from_row(later_row))
  assert_false(
    dae_should_prune_mixed_dropped_undropped_caller_from_row(later_row),
  )
  assert_false(
    dae_should_prune_dropped_self_result_with_void_side_callers_from_row(
      later_row,
    ),
  )
  assert_false(
    dae_should_prune_dropped_only_private_result_side_caller_from_row(later_row),
  )
  let mixed_row = dae_original_result_removal_prune_row(
    1,
    [0, 1],
    [0, 1],
    [0, 0],
    [0, 0],
    [0, 0],
    [0, 0],
    [0, 0],
    [0, 1],
    [false, false],
    [false, false],
    [false, false],
    [false, false],
    [false, false],
    [false, false],
    [false, false],
    [0, 0],
    [false, false],
    [0, 0],
    [false, false],
    [0, 0],
    [0, 1],
  )
  assert_true(
    dae_should_prune_mixed_dropped_undropped_caller_from_row(mixed_row),
  )
  assert_false(dae_should_preserve_mixed_self_suffix_from_row(mixed_row))
  let mixed_self_row = dae_original_result_removal_prune_row(
    1,
    [0, 1],
    [0, 2],
    [0, 0],
    [0, 0],
    [0, 0],
    [0, 1],
    [0, 2],
    [0, 0],
    [false, true],
    [false, true],
    [false, false],
    [false, true],
    [false, false],
    [false, false],
    [false, false],
    [0, 0],
    [false, false],
    [0, 0],
    [false, false],
    [0, 0],
    [0, 0],
  )
  assert_true(dae_should_preserve_mixed_self_suffix_from_row(mixed_self_row))
  assert_true(
    dae_should_preserve_same_self_result_operand_from_row(mixed_self_row),
  )
  assert_false(
    dae_should_preserve_escaped_block_self_result_from_row(mixed_self_row, true),
  )
  let escaped_block_row = dae_original_result_removal_prune_row(
    1,
    [0, 1],
    [0, 2],
    [0, 0],
    [0, 0],
    [0, 0],
    [0, 0],
    [0, 1],
    [0, 1],
    [false, true],
    [false, true],
    [false, true],
    [false, false],
    [false, false],
    [false, false],
    [false, false],
    [0, 0],
    [false, false],
    [0, 0],
    [false, false],
    [0, 0],
    [0, 0],
  )
  assert_true(
    dae_should_preserve_escaped_block_self_result_from_row(
      escaped_block_row, true,
    ),
  )
  let void_side_row = dae_original_result_removal_prune_row(
    2,
    [0, 1, 1],
    [0, 1, 3],
    [0, 0, 1],
    [0, 0, 1],
    [0, 0, 0],
    [0, 0, 0],
    [0, 0, 1],
    [0, 0, 0],
    [false, false, false],
    [false, false, true],
    [false, false, false],
    [false, false, false],
    [false, false, false],
    [false, false, false],
    [false, true, false],
    [0, 2, 0],
    [false, false, false],
    [0, 0, 3],
    [false, false, true],
    [0, 0, 4],
    [0, 5, 0],
  )
  assert_true(void_side_row.dead_suffix_dropped_self_call)
  assert_false(void_side_row.dead_suffix_dropped_self_call_full_param_forward)
  assert_true(
    dae_should_prune_dropped_self_result_with_void_side_callers_from_row(
      void_side_row,
    ),
  )
  assert_false(
    dae_should_prune_later_mutual_dropped_result_from_row(void_side_row),
  )
  assert_false(
    dae_should_prune_dropped_only_private_result_side_caller_from_row(
      void_side_row,
    ),
  )
  assert_false(
    dae_should_prune_dropped_only_no_param_result_side_caller_from_row(
      void_side_row,
    ),
  )
  let dropped_only_row = dae_original_result_removal_prune_row(
    1,
    [0, 1],
    [0, 1],
    [0, 0],
    [0, 0],
    [0, 0],
    [0, 0],
    [0, 0],
    [0, 0],
    [false, false],
    [false, false],
    [false, false],
    [false, false],
    [false, false],
    [false, false],
    [false, false],
    [0, 0],
    [false, false],
    [0, 1],
    [false, true],
    [0, 1],
    [0, 0],
  )
  assert_true(
    dae_should_prune_dropped_only_private_result_side_caller_from_row(
      dropped_only_row,
    ),
  )
  assert_true(
    dae_should_prune_dropped_only_no_param_result_side_caller_from_row(
      dropped_only_row,
    ),
  )
  let dropped_only_prune = dae_original_result_removal_prune_evidence_from_row(
    dropped_only_row,
  )
  assert_false(dropped_only_prune.dropped_self_result_with_void_side_callers)
  assert_false(dropped_only_prune.later_mutual_dropped_result)
  assert_false(dropped_only_prune.mixed_dropped_undropped_caller)
  assert_true(dropped_only_prune.dropped_only_private_result_side_caller)
  assert_true(dropped_only_prune.dropped_only_no_param_result_side_caller)
  assert_true(dropped_only_prune.params_absent_result_cleanup_prune)
  assert_true(dropped_only_prune.uncalled_after_param_cleanup_prune)
  assert_true(dae_should_prune_params_absent_result_cleanup(dropped_only_prune))
  assert_true(
    dae_should_block_uncalled_after_param_cleanup_from_prune_evidence(
      dropped_only_prune,
    ),
  )
  let empty_row = dae_original_result_removal_prune_row(
    9,
    [1],
    [1],
    [1],
    [1],
    [1],
    [1],
    [1],
    [1],
    [true],
    [true],
    [true],
    [true],
    [true],
    [true],
    [true],
    [1],
    [true],
    [1],
    [true],
    [1],
    [1],
  )
  assert_eq(empty_row.param_count, 0)
  assert_eq(empty_row.call_count, 0)
  assert_false(empty_row.dead_suffix_dropped_self_call)
  assert_false(dae_should_prune_later_mutual_dropped_result_from_row(empty_row))
  assert_false(
    dae_should_prune_dropped_self_result_with_void_side_callers_from_row(
      empty_row,
    ),
  )
  assert_false(
    dae_should_prune_mixed_dropped_undropped_caller_from_row(empty_row),
  )
  assert_false(
    dae_should_prune_dropped_only_private_result_side_caller_from_row(empty_row),
  )
  assert_false(
    dae_should_prune_dropped_only_no_param_result_side_caller_from_row(
      empty_row,
    ),
  )
  assert_false(dae_should_preserve_mixed_self_suffix_from_row(empty_row))
  assert_false(dae_should_preserve_same_self_result_operand_from_row(empty_row))
  assert_false(
    dae_should_preserve_escaped_block_self_result_from_row(empty_row, false),
  )
  let empty_prune = dae_original_result_removal_prune_evidence_from_row(
    empty_row,
  )
  assert_false(empty_prune.params_absent_result_cleanup_prune)
  assert_false(empty_prune.uncalled_after_param_cleanup_prune)
  assert_false(dae_should_prune_params_absent_result_cleanup(empty_prune))
  assert_false(
    dae_should_block_uncalled_after_param_cleanup_from_prune_evidence(
      empty_prune,
    ),
  )
}

///|
test "dae original dead-suffix side-call evidence centralizes cleanup gates" {
  let result_side_row = dae_original_result_removal_prune_row(
    1,
    [0, 1],
    [0, 3],
    [0, 2],
    [0, 0],
    [0, 0],
    [0, 2],
    [0, 1],
    [0, 0],
    [false, true],
    [false, false],
    [false, false],
    [false, true],
    [false, false],
    [false, false],
    [false, false],
    [0, 0],
    [false, true],
    [0, 0],
    [false, false],
    [0, 0],
    [0, 0],
  )
  let result_side = dae_original_dead_suffix_side_call_evidence(
    result_side_row, true, false, false, true,
  )
  assert_false(result_side.void_side_cleanup_preservation)
  assert_true(result_side.result_side_chain_preservation)
  assert_true(result_side.same_self_result_operand_preservation)
  let void_side_row = dae_original_result_removal_prune_row(
    1,
    [0, 1],
    [0, 2],
    [0, 1],
    [0, 0],
    [0, 0],
    [0, 0],
    [0, 0],
    [0, 0],
    [false, false],
    [false, false],
    [false, false],
    [false, false],
    [false, false],
    [false, false],
    [false, false],
    [0, 0],
    [false, false],
    [0, 0],
    [false, false],
    [0, 0],
    [0, 0],
  )
  let void_side = dae_original_dead_suffix_side_call_evidence(
    void_side_row, true, false, true, false,
  )
  assert_true(void_side.void_side_cleanup_preservation)
  assert_false(void_side.result_side_chain_preservation)
  assert_false(void_side.same_self_result_operand_preservation)
}

///|
test "dae original no-param dropped caller guard centralizes indexed facts" {
  let evidence = dae_original_no_param_dropped_caller_guard_evidence(
    1,
    [0, 1],
    [0, 3],
    [0, 2],
    [0, 0],
    [0, 0],
    [0, 1],
    [0, 0],
    [false, true],
    [false, true],
    [false, true],
    [false, false],
  )
  assert_eq(evidence.param_count, 1)
  assert_eq(evidence.call_count, 3)
  assert_eq(evidence.active_nonself_call_count, 2)
  assert_eq(evidence.active_parameterized_nonself_call_count, 0)
  assert_eq(evidence.nonself_undropped_call_count, 0)
  assert_eq(evidence.self_call_count, 1)
  assert_eq(evidence.escaped_dead_suffix_call_count, 0)
  assert_true(evidence.dead_suffix_undropped_self_call)
  assert_true(evidence.dead_suffix_undropped_self_call_param_operand)
  assert_true(evidence.dead_suffix_result_other_call)
  assert_false(evidence.dead_suffix_mutual_call)
  assert_true(
    dae_should_preserve_undropped_self_result_from_no_param_dropped_caller_evidence(
      evidence,
    ),
  )
  let out_of_range = dae_original_no_param_dropped_caller_guard_evidence(
    3,
    [1],
    [2],
    [3],
    [4],
    [5],
    [6],
    [7],
    [true],
    [true],
    [true],
    [true],
  )
  assert_eq(out_of_range.param_count, 0)
  assert_eq(out_of_range.call_count, 0)
  assert_false(out_of_range.dead_suffix_undropped_self_call)
  assert_false(
    dae_should_preserve_undropped_self_result_from_no_param_dropped_caller_evidence(
      out_of_range,
    ),
  )
}

///|
test "dae original parameterized self side-chain guard centralizes indexed facts" {
  let context = dae_original_result_preservation_context(
    [0, 1],
    [0, 3],
    [0, 2],
    [0, 2],
    [0, 0],
    [0, 1],
    [0, 0],
    [0, 0],
    [false, true],
    [false, false],
    [false, false],
    [0, 0],
    [0, 0],
    [false, false],
    [false, false],
    [false, true],
    [false, false],
    [false, false],
    [0, 0],
    [0, 0],
    [0, 0],
  )
  let evidence = dae_original_parameterized_undropped_self_side_chain_evidence_from_context(
    1, context,
  )
  assert_eq(evidence.param_count, 1)
  assert_eq(evidence.call_count, 3)
  assert_eq(evidence.active_parameterized_nonself_call_count, 2)
  assert_eq(evidence.self_call_count, 1)
  assert_eq(evidence.escaped_dead_suffix_call_count, 0)
  assert_true(evidence.dead_suffix_undropped_self_call)
  assert_true(evidence.dead_suffix_result_other_call)
  assert_true(
    dae_should_preserve_parameterized_undropped_self_side_chain_evidence(
      evidence,
    ),
  )
  let out_of_range = dae_original_parameterized_undropped_self_side_chain_evidence_from_context(
    4, context,
  )
  assert_eq(out_of_range.param_count, 0)
  assert_eq(out_of_range.call_count, 0)
  assert_false(out_of_range.dead_suffix_undropped_self_call)
  assert_false(
    dae_should_preserve_parameterized_undropped_self_side_chain_evidence(
      out_of_range,
    ),
  )
}

///|
test "dae original result preservation repair gate reuses shared evidence" {
  let clear = {
    same_self_result_operand: false,
    result_from_undropped_self_caller: false,
    escaped_result_operand_chain: false,
    mixed_self_result: false,
    escaped_block_self_result: false,
    param_operand_self_result_side_callee: false,
    undropped_self_result_from_no_param_dropped_caller: false,
    dropped_escaped_result_under_self_caller: false,
    parameterized_undropped_self_side_chain: false,
    result_side_chain_cleanup_preservation: false,
  }
  assert_false(
    dae_original_result_preservation_blocks_argument_side_result_repair(
      clear, true,
    ),
  )
  let param_operand_only = {
    same_self_result_operand: false,
    result_from_undropped_self_caller: false,
    escaped_result_operand_chain: false,
    mixed_self_result: false,
    escaped_block_self_result: false,
    param_operand_self_result_side_callee: true,
    undropped_self_result_from_no_param_dropped_caller: false,
    dropped_escaped_result_under_self_caller: false,
    parameterized_undropped_self_side_chain: false,
    result_side_chain_cleanup_preservation: false,
  }
  assert_false(
    dae_original_result_preservation_blocks_argument_side_result_repair(
      param_operand_only, true,
    ),
  )
  let parameterized_only = {
    same_self_result_operand: false,
    result_from_undropped_self_caller: false,
    escaped_result_operand_chain: false,
    mixed_self_result: false,
    escaped_block_self_result: false,
    param_operand_self_result_side_callee: false,
    undropped_self_result_from_no_param_dropped_caller: false,
    dropped_escaped_result_under_self_caller: false,
    parameterized_undropped_self_side_chain: true,
    result_side_chain_cleanup_preservation: true,
  }
  assert_true(
    dae_original_result_preservation_blocks_argument_side_result_repair(
      parameterized_only, true,
    ),
  )
  assert_false(
    dae_original_result_preservation_blocks_argument_side_result_repair(
      parameterized_only, false,
    ),
  )
}

///|
test "dae dropped result call rewrite policy centralizes dead suffix handling" {
  let callee = @lib.FuncIdx::new(1U)
  let body = [
    @lib.Instruction::call(callee),
    @lib.Instruction::drop(),
    @lib.Instruction::unreachable_(),
    @lib.Instruction::call(callee),
    @lib.Instruction::drop(),
  ]
  let (stop_body, stop_rewrites) = dae_rewrite_dropped_result_calls_with_policy_instrs(
    body, 1, true,
  )
  assert_eq(stop_body, [
    @lib.Instruction::call(callee),
    @lib.Instruction::unreachable_(),
  ])
  assert_eq(stop_rewrites, 1)
  let (anywhere_body, anywhere_rewrites) = dae_rewrite_dropped_result_calls_with_policy_instrs(
    body, 1, false,
  )
  assert_eq(anywhere_body, [
    @lib.Instruction::call(callee),
    @lib.Instruction::unreachable_(),
    @lib.Instruction::call(callee),
  ])
  assert_eq(anywhere_rewrites, 2)
}

///|
test "dae dropped result rewrite scope centralizes selected caller handling" {
  let callee = @lib.FuncIdx::new(2U)
  let all_scope = dae_dropped_result_scope_from_optional(3, None)
  assert_eq(all_scope.caller_defs, [0, 1, 2])
  let selected_scope = dae_dropped_result_scope_from_optional(
    3,
    Some([1, -1, 99]),
  )
  assert_eq(selected_scope.caller_defs, [1, -1, 99])
  let funcs = [
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(callee), @lib.Instruction::drop()]),
    ),
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(callee), @lib.Instruction::drop()]),
    ),
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(callee)]),
    ),
  ]
  assert_true(
    dae_dropped_result_scope_direct_call_evidence(funcs, all_scope, 2, -1).has_live_undropped_direct_call,
  )
  assert_false(
    dae_dropped_result_scope_direct_call_evidence(funcs, selected_scope, 2, -1).has_live_undropped_direct_call,
  )
  let selected_funcs = funcs.copy()
  let rewrites = dae_rewrite_dropped_result_calls_in_scope(
    selected_funcs, selected_scope, 2,
  )
  assert_eq(rewrites, 1)
  assert_eq(selected_funcs[0], funcs[0])
  assert_eq(
    selected_funcs[1],
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(callee)]),
    ),
  )
  assert_eq(selected_funcs[2], funcs[2])
}

///|
test "dae dropped result module context centralizes section scope and legality facts" {
  let result_type = @lib.TypeIdx::new(0U)
  let callee = @lib.FuncIdx::new(1U)
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([result_type, result_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(callee),
            @lib.Instruction::drop(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(1)]),
        ),
      ]),
    )
  match dae_dropped_result_module_context(mod_, 1, caller_defs=Some([0])) {
    Some(context) => {
      assert_eq(context.imported, 0)
      assert_eq(context.def_idx, 1)
      assert_eq(context.type_indices.length(), 2)
      assert_eq(context.type_idxs.length(), 2)
      assert_eq(context.funcs.length(), 2)
      assert_eq(context.scope.caller_defs, [0])
      assert_eq(context.params.length(), 0)
      assert_eq(context.results, [@lib.ValType::i32()])
      assert_eq(context.result_removal_legality.result_count, 1)
      assert_false(context.result_removal_legality.has_live_tail_call)
      assert_false(context.result_removal_legality.has_undropped_direct_call)
      assert_false(
        dae_dropped_result_removal_legality_blocks(
          context.result_removal_legality,
        ),
      )
    }
    None => fail("expected dropped-result module context")
  }
  match dae_dropped_result_module_context(mod_, 4) {
    Some(_) => fail("out-of-range dropped-result module context must reject")
    None => ()
  }
}

///|
test "dae dropped result removal legality centralizes result blockers" {
  let callee = @lib.FuncIdx::new(2U)
  let blocked_funcs = [
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(callee), @lib.Instruction::drop()]),
    ),
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(callee)]),
    ),
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::return_call(callee)]),
    ),
  ]
  let full_scope = dae_dropped_result_scope_from_optional(3, None)
  let result_evidence = dae_dropped_result_removal_legality_evidence(
    blocked_funcs,
    full_scope,
    2,
    -1,
    [@lib.ValType::i32()],
  )
  assert_eq(result_evidence.result_count, 1)
  assert_false(result_evidence.skip_large_result_cleanup)
  assert_true(result_evidence.has_live_tail_call)
  assert_true(result_evidence.has_undropped_direct_call)
  assert_true(result_evidence.blocks_result_removal)
  let void_evidence = dae_dropped_result_removal_legality_evidence(
    blocked_funcs,
    full_scope,
    2,
    -1,
    [],
  )
  assert_eq(void_evidence.result_count, 0)
  assert_false(void_evidence.has_live_tail_call)
  assert_false(void_evidence.has_undropped_direct_call)
  assert_false(void_evidence.blocks_result_removal)
  let dropped_only_funcs = [
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(callee), @lib.Instruction::drop()]),
    ),
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
  ]
  let selected_scope = dae_dropped_result_scope_from_optional(3, Some([0]))
  let dropped_only_evidence = dae_dropped_result_removal_legality_evidence(
    dropped_only_funcs,
    selected_scope,
    2,
    -1,
    [@lib.ValType::i32()],
  )
  assert_false(dropped_only_evidence.has_live_tail_call)
  assert_false(dropped_only_evidence.has_undropped_direct_call)
  assert_false(dropped_only_evidence.blocks_result_removal)
}

///|
test "dae dropped result callee rewrite evidence centralizes suffix and legality facts" {
  let callee = @lib.FuncIdx::new(1U)
  let result_type = [@lib.ValType::i32()]
  let clear_legality : DaeDroppedResultRemovalLegalityEvidence = {
    result_count: 1,
    skip_large_result_cleanup: false,
    has_live_tail_call: false,
    has_undropped_direct_call: false,
    blocks_result_removal: false,
  }
  let unreachable_with_suffix = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::unreachable_(),
      @lib.Instruction::call(callee),
      @lib.Instruction::drop(),
    ]),
  )
  let dropped_evidence = dae_dropped_result_callee_rewrite_evidence(
    unreachable_with_suffix,
    [],
    result_type,
    clear_legality,
    1,
  )
  assert_eq(dropped_evidence.param_count, 0)
  assert_eq(dropped_evidence.result_count, 1)
  assert_false(dropped_evidence.original_unreachable_only)
  assert_true(dropped_evidence.simplified_unreachable_only)
  assert_true(dropped_evidence.has_dropped_dead_suffix_call)
  assert_false(dropped_evidence.has_undropped_dead_suffix_call)
  assert_false(dropped_evidence.missing_dropped_dead_suffix_call)
  assert_true(dropped_evidence.missing_undropped_dead_suffix_call)
  assert_false(dropped_evidence.blocks_result_removal)
  let undropped_evidence = dae_dropped_result_callee_rewrite_evidence(
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([
        @lib.Instruction::unreachable_(),
        @lib.Instruction::call(callee),
      ]),
    ),
    [@lib.ValType::i32()],
    result_type,
    clear_legality,
    1,
  )
  assert_eq(undropped_evidence.param_count, 1)
  assert_true(undropped_evidence.has_undropped_dead_suffix_call)
  assert_true(undropped_evidence.missing_dropped_dead_suffix_call)
  assert_false(undropped_evidence.missing_undropped_dead_suffix_call)
  let blocked_legality : DaeDroppedResultRemovalLegalityEvidence = {
    result_count: 1,
    skip_large_result_cleanup: false,
    has_live_tail_call: true,
    has_undropped_direct_call: false,
    blocks_result_removal: true,
  }
  let blocked_evidence = dae_dropped_result_callee_rewrite_evidence(
    unreachable_with_suffix,
    [],
    result_type,
    blocked_legality,
    1,
  )
  assert_true(blocked_evidence.blocks_result_removal)
}

///|
test "dae escaped result direct call evidence centralizes dropped and undropped suffix facts" {
  let result_type = @lib.TypeIdx::new(0U)
  let void_type = @lib.TypeIdx::new(1U)
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([result_type, result_type, void_type]))
  let type_indices = dae_collect_func_type_indices(mod_)
  let escaped = [true, true, true]
  let body = [
    @lib.Instruction::unreachable_(),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(1U))]),
    ),
    @lib.Instruction::call(@lib.FuncIdx::new(2U)),
    @lib.Instruction::drop(),
  ]
  let evidence = dae_escaped_result_direct_call_evidence(
    body, mod_, type_indices, escaped,
  )
  assert_true(evidence.has_dropped_escaped_result_call)
  assert_true(evidence.has_undropped_escaped_result_call)
  match
    dae_dead_suffix_escaped_result_direct_call_evidence(
      body, mod_, type_indices, escaped,
    ) {
    Some(suffix_evidence) => {
      assert_true(suffix_evidence.has_dropped_escaped_result_call)
      assert_true(suffix_evidence.has_undropped_escaped_result_call)
    }
    None => fail("expected escaped-result dead-suffix direct-call evidence")
  }
  let void_only = dae_escaped_result_direct_call_evidence(
    [@lib.Instruction::call(@lib.FuncIdx::new(2U)), @lib.Instruction::drop()],
    mod_,
    type_indices,
    escaped,
  )
  assert_false(void_only.has_dropped_escaped_result_call)
  assert_false(void_only.has_undropped_escaped_result_call)
  match
    dae_dead_suffix_escaped_result_direct_call_evidence(
      [@lib.Instruction::call(@lib.FuncIdx::new(1U))],
      mod_,
      type_indices,
      escaped,
    ) {
    Some(_) => fail("dead-suffix escaped result evidence requires suffix")
    None => ()
  }
}

///|
test "dae dead suffix direct target evidence centralizes dropped and undropped target lists" {
  let imported = 1
  let defined = 5
  let body = [
    @lib.Instruction::call(@lib.FuncIdx::new(4U)),
    @lib.Instruction::unreachable_(),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::call(@lib.FuncIdx::new(2U)),
        @lib.Instruction::call(@lib.FuncIdx::new(3U)),
        @lib.Instruction::drop(),
      ]),
    ),
    @lib.Instruction::return_call(@lib.FuncIdx::new(5U)),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
  ]
  match dae_dead_suffix_direct_target_evidence(body, imported, defined) {
    Some(evidence) => {
      assert_eq(evidence.direct_targets, [0, 1, 2, 2])
      assert_eq(evidence.dropped_direct_targets, [0])
      assert_eq(evidence.undropped_direct_targets, [1, 4, 2])
    }
    None => fail("expected dead-suffix direct target evidence")
  }
  match
    dae_dead_suffix_direct_target_evidence(
      [@lib.Instruction::call(@lib.FuncIdx::new(1U))],
      imported,
      defined,
    ) {
    Some(_) => fail("dead-suffix direct target evidence requires suffix")
    None => ()
  }
}

///|
test "dae dropped result scope direct call evidence centralizes selected caller facts" {
  let callee = @lib.FuncIdx::new(2U)
  let funcs = [
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(callee), @lib.Instruction::drop()]),
    ),
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(callee)]),
    ),
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([
        @lib.Instruction::unreachable_(),
        @lib.Instruction::call(callee),
      ]),
    ),
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([
        @lib.Instruction::unreachable_(),
        @lib.Instruction::return_call(callee),
      ]),
    ),
  ]
  let scope = dae_dropped_result_scope_from_optional(
    funcs.length(),
    Some([0, 1, 2, 3, -1, 99]),
  )
  let live_evidence = dae_dropped_result_scope_direct_call_evidence(
    funcs, scope, 2, -1,
  )
  assert_eq(live_evidence.direct_call_count, 3)
  assert_eq(live_evidence.dropped_direct_call_count, 1)
  assert_true(live_evidence.has_direct_call)
  assert_true(live_evidence.has_undropped_direct_call)
  assert_true(live_evidence.has_live_undropped_direct_call)
  let skipped_live_evidence = dae_dropped_result_scope_direct_call_evidence(
    funcs, scope, 2, 1,
  )
  assert_eq(skipped_live_evidence.direct_call_count, 2)
  assert_eq(skipped_live_evidence.dropped_direct_call_count, 1)
  assert_true(skipped_live_evidence.has_direct_call)
  assert_true(skipped_live_evidence.has_undropped_direct_call)
  assert_false(skipped_live_evidence.has_live_undropped_direct_call)
}

///|
test "dae tail call boundary evidence centralizes rewrite and result blockers" {
  let direct_callee = @lib.FuncIdx::new(1U)
  let type_idx = @lib.TypeIdx::new(0U)
  let direct_only = [
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::return_call(direct_callee)]),
    ),
  ]
  let direct_evidence = dae_tail_call_boundary_evidence(direct_only)
  assert_true(direct_evidence.has_direct_tail_call)
  assert_false(direct_evidence.has_indirect_tail_call)
  assert_false(direct_evidence.blocks_direct_call_rewrite)
  assert_true(direct_evidence.blocks_result_removal)
  let indirect_nested = [
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::return_call_ref(type_idx)]),
        ),
      ]),
    ),
  ]
  let indirect_evidence = dae_tail_call_boundary_evidence(indirect_nested)
  assert_false(indirect_evidence.has_direct_tail_call)
  assert_true(indirect_evidence.has_indirect_tail_call)
  assert_true(indirect_evidence.blocks_direct_call_rewrite)
  assert_true(indirect_evidence.blocks_result_removal)
  let clear_evidence = dae_tail_call_boundary_evidence([])
  assert_false(clear_evidence.has_direct_tail_call)
  assert_false(clear_evidence.has_indirect_tail_call)
  assert_false(clear_evidence.blocks_direct_call_rewrite)
  assert_false(clear_evidence.blocks_result_removal)
}

///|
test "dae dropped result repair plan centralizes dead suffix cleanup" {
  let callee = @lib.FuncIdx::new(2U)
  let scope = dae_dropped_result_scope_from_optional(3, Some([0, 1, 2]))
  let no_param_type = @lib.TypeIdx::new(0U)
  let one_param_type = @lib.TypeIdx::new(1U)
  let type_indices = [no_param_type, one_param_type, no_param_type]
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
    ),
  ])
  let funcs = [
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([
        @lib.Instruction::unreachable_(),
        @lib.Instruction::call(callee),
      ]),
    ),
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([
        @lib.Instruction::unreachable_(),
        @lib.Instruction::call(callee),
      ]),
    ),
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(callee), @lib.Instruction::drop()]),
    ),
  ]
  let no_param_plan = dae_dropped_result_repair_plan(
    scope,
    2,
    2,
    DaeRepairDeadSuffixNoParamCallers,
    remove_dropped_call_drops=true,
    remove_dropped_call_drops_before_repair=false,
  )
  assert_true(dae_dropped_result_repair_plan_removes_call_drops(no_param_plan))
  let no_param_funcs = funcs.copy()
  dae_apply_dropped_result_repair_plan(
    no_param_funcs, type_indices, type_sec, 0, no_param_plan,
  )
  assert_eq(
    no_param_funcs[0],
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
  )
  assert_eq(no_param_funcs[1], funcs[1])
  assert_eq(
    no_param_funcs[2],
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(callee)]),
    ),
  )
  let all_callers_plan = dae_dropped_result_repair_plan(
    scope,
    2,
    1,
    DaeRepairDeadSuffixAllCallers,
    remove_dropped_call_drops=false,
    remove_dropped_call_drops_before_repair=false,
  )
  assert_false(
    dae_dropped_result_repair_plan_removes_call_drops(all_callers_plan),
  )
  let all_callers_funcs = funcs.copy()
  dae_apply_dropped_result_repair_plan(
    all_callers_funcs, type_indices, type_sec, 0, all_callers_plan,
  )
  assert_eq(
    all_callers_funcs[0],
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
  )
  assert_eq(all_callers_funcs[1], funcs[1])
  assert_eq(all_callers_funcs[2], funcs[2])
}

///|
test "dae uniform const boundary facts carry direct caller evidence" {
  let caller_type = @lib.TypeIdx::new(0U)
  let callee_type = @lib.TypeIdx::new(1U)
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], []),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([caller_type, callee_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(42)),
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let boundary_facts = dae_make_call_boundary_facts(
    [false, false],
    [false, false],
    [[], [0]],
  )
  match
    dae_collect_uniform_const_actuals_from_boundary_facts(
      mod_,
      1,
      1,
      [caller_type, callee_type],
      boundary_facts,
    ) {
    Some(values) =>
      match values[0] {
        Some(@lib.I32Const(@lib.I32(value))) => assert_eq(value, 42)
        Some(_) => fail("expected i32.const uniform actual")
        None => fail("expected uniform actual from boundary direct caller")
      }
    None => fail("expected boundary-carried uniform actual collection")
  }
}

///|
test "dae uniform const candidate recorder centralizes merge invalidation" {
  let seen = Array::make(2, false)
  let invalid = Array::make(2, false)
  let candidates : Array[@lib.Instruction?] = Array::make(2, None)
  let one = @lib.Instruction::i32_const(@lib.I32(1))
  let two = @lib.Instruction::i32_const(@lib.I32(2))
  let seven = @lib.Instruction::i64_const(@lib.I64(7L))
  dae_record_uniform_const_candidate(seen, invalid, candidates, 0, one)
  assert_true(seen[0])
  assert_false(invalid[0])
  match candidates[0] {
    Some(candidate) => assert_true(dae_materialized_const_equal(candidate, one))
    None => fail("expected first candidate to be recorded")
  }
  dae_record_uniform_const_candidate(seen, invalid, candidates, 0, one)
  assert_false(invalid[0])
  dae_record_uniform_const_candidate(seen, invalid, candidates, 0, two)
  assert_true(invalid[0])
  dae_record_uniform_const_candidate(seen, invalid, candidates, 1, seven)
  assert_true(seen[1])
  assert_false(invalid[1])
  match candidates[1] {
    Some(candidate) =>
      assert_true(dae_materialized_const_equal(candidate, seven))
    None => fail("expected independent candidate lane to be recorded")
  }
}

///|
test "dae control result slices centralize flat and return arm bounds" {
  let pair_type = @lib.TypeIdx::new(0U)
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([], [@lib.ValType::i32(), @lib.ValType::i64()]),
        ),
      ),
    ]),
  )
  let block_arm = [
    @lib.Instruction::block(
      @lib.BlockType::type_idx(pair_type),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i64_const(@lib.I64(2L)),
      ]),
    ),
  ]
  match dae_single_block_result_carrier_evidence(mod_, block_arm, 2) {
    Some(evidence) => {
      assert_eq(evidence.result_count, 2)
      assert_eq(evidence.body.length(), 2)
      assert_false(evidence.body_has_effect_or_branch)
    }
    None => fail("expected shared single-block result carrier evidence")
  }
  match dae_find_multi_result_control_slice(mod_, block_arm, 2) {
    Some(slice) => {
      assert_eq(slice.slice.start, 0)
      assert_eq(slice.slice.end, 2)
      assert_eq(slice.result_count, 2)
      assert_eq(slice.carrier_kind, 1)
      assert_true(slice.flattened)
      assert_false(slice.terminal_return)
      assert_false(slice.slice.has_effect_or_branch)
    }
    None => fail("expected reusable flattened block result slice")
  }
  let return_arm = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i64_const(@lib.I64(2L)),
    @lib.Instruction::return_(),
  ]
  match
    dae_find_multi_result_control_slice(
      mod_,
      return_arm,
      2,
      require_terminal_return=true,
    ) {
    Some(slice) => {
      assert_eq(slice.slice.start, 0)
      assert_eq(slice.slice.end, 2)
      assert_eq(slice.result_count, 2)
      assert_eq(slice.carrier_kind, 0)
      assert_false(slice.flattened)
      assert_true(slice.terminal_return)
      assert_false(slice.slice.has_effect_or_branch)
    }
    None => fail("expected reusable terminal-return result slice")
  }
}

///|
test "dae control result GC evidence centralizes lane candidates and rewrites" {
  let base_type = @lib.TypeIdx::new(0U)
  let leaf_type = @lib.TypeIdx::new(1U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let expected_leaf_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf_type), exact=true),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let body = [
    @lib.Instruction::struct_new_default(leaf_type),
    @lib.Instruction::block(
      @lib.BlockType::val_type(base_ref),
      @lib.Expr::new([@lib.Instruction::struct_new_default(leaf_type)]),
    ),
  ]
  let slice = match
    dae_make_multi_result_control_slice(body, 0, 2, 0, false, false) {
    Some(slice) => slice
    None => fail("expected valid multi-result control slice")
  }
  match
    dae_control_result_slice_gc_evidence(
      mod_,
      [],
      None,
      slice,
      [base_ref, base_ref],
      require_refined=true,
    ) {
    Some(evidence) => {
      assert_true(evidence.saw_candidate)
      assert_true(evidence.body_changed)
      assert_eq(evidence.candidates[0], Some(expected_leaf_ref))
      assert_eq(evidence.candidates[1], Some(expected_leaf_ref))
      assert_eq(evidence.refined_candidates[0], Some(expected_leaf_ref))
      assert_eq(evidence.refined_candidates[1], Some(expected_leaf_ref))
      assert_eq(evidence.rewritten_body[0], body[0])
      assert_eq(
        evidence.rewritten_body[1],
        @lib.Instruction::block(
          @lib.BlockType::val_type(expected_leaf_ref),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf_type)]),
        ),
      )
    }
    None => fail("expected reusable per-lane control GC evidence")
  }
}

///|
test "dae single-result control pair GC evidence centralizes LUB rewrites" {
  let base_type = @lib.TypeIdx::new(0U)
  let left_type = @lib.TypeIdx::new(1U)
  let right_type = @lib.TypeIdx::new(2U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let expected_common_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(base_type)),
  )
  let expected_left_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(left_type), exact=true),
  )
  let expected_right_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(right_type), exact=true),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let then_body = [@lib.Instruction::struct_new_default(left_type)]
  let else_body = [@lib.Instruction::struct_new_default(right_type)]
  let then_rewrite = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(expected_left_ref),
      @lib.Expr::new([@lib.Instruction::struct_new_default(left_type)]),
    ),
  ]
  let else_rewrite = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(expected_right_ref),
      @lib.Expr::new([@lib.Instruction::struct_new_default(right_type)]),
    ),
  ]
  match
    dae_single_result_control_pair_gc_evidence(
      mod_,
      then_body,
      expected_left_ref,
      Some(then_rewrite),
      else_body,
      expected_right_ref,
      Some(else_rewrite),
      base_ref,
    ) {
    Some(evidence) => {
      assert_eq(evidence.candidate, expected_common_ref)
      assert_eq(evidence.rewritten_then_body[0], then_rewrite[0])
      assert_eq(evidence.rewritten_else_body[0], else_rewrite[0])
    }
    None => fail("expected reusable single-result control pair GC evidence")
  }
  match
    dae_single_result_control_pair_gc_evidence(
      mod_,
      then_body,
      expected_left_ref,
      None,
      else_body,
      expected_right_ref,
      None,
      base_ref,
    ) {
    Some(evidence) => {
      assert_eq(evidence.candidate, expected_common_ref)
      assert_eq(evidence.rewritten_then_body[0], then_body[0])
      assert_eq(evidence.rewritten_else_body[0], else_body[0])
    }
    None => fail("expected no-rewrite single-result control pair evidence")
  }
}

///|
test "dae single-result control pair application centralizes if rewrites" {
  let leaf_type = @lib.TypeIdx::new(1U)
  let candidate = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf_type), exact=true),
  )
  let then_body = [@lib.Instruction::struct_new_default(leaf_type)]
  let else_body = [@lib.Instruction::local_get(@lib.LocalIdx::new(0U))]
  let evidence : DaeSingleResultControlPairGcEvidence = {
    candidate,
    rewritten_then_body: then_body,
    rewritten_else_body: else_body,
  }
  match dae_apply_single_result_control_pair_gc_evidence(evidence, false) {
    Some((rewritten, application)) => {
      assert_false(application.result_is_void)
      assert_eq(application.then_body_length, then_body.length())
      assert_eq(application.else_body_length, else_body.length())
      assert_eq(
        rewritten,
        @lib.Instruction::if_(
          @lib.BlockType::val_type(candidate),
          then_body,
          Some(else_body),
        ),
      )
    }
    None => fail("expected value-result if application evidence")
  }
  match dae_apply_single_result_control_pair_gc_evidence(evidence, true) {
    Some((rewritten, application)) => {
      assert_true(application.result_is_void)
      assert_eq(
        rewritten,
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          then_body,
          Some(else_body),
        ),
      )
    }
    None => fail("expected void-result if application evidence")
  }
}

///|
test "dae single-result control pair repair evidence gathers arm candidates" {
  let base_type = @lib.TypeIdx::new(0U)
  let left_type = @lib.TypeIdx::new(1U)
  let right_type = @lib.TypeIdx::new(2U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let expected_common_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(base_type)),
  )
  let expected_left_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(left_type), exact=true),
  )
  let expected_right_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(right_type), exact=true),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let then_body = [@lib.Instruction::struct_new_default(left_type)]
  let else_body = [@lib.Instruction::struct_new_default(right_type)]
  let then_rewrite = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(expected_left_ref),
      @lib.Expr::new(then_body),
    ),
  ]
  let else_rewrite = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(expected_right_ref),
      @lib.Expr::new(else_body),
    ),
  ]
  match
    dae_single_result_control_pair_repair_evidence(
      mod_,
      then_body,
      else_body,
      base_ref,
      false,
      fn(body) {
        if body == then_body {
          Some((expected_left_ref, Some(then_rewrite)))
        } else if body == else_body {
          Some((expected_right_ref, Some(else_rewrite)))
        } else {
          None
        }
      },
    ) {
    Some(evidence) => {
      assert_eq(evidence.pair.candidate, expected_common_ref)
      assert_false(evidence.application.result_is_void)
      assert_eq(evidence.application.then_body_length, then_rewrite.length())
      assert_eq(evidence.application.else_body_length, else_rewrite.length())
      assert_eq(
        evidence.rewritten,
        @lib.Instruction::if_(
          @lib.BlockType::val_type(expected_common_ref),
          then_rewrite,
          Some(else_rewrite),
        ),
      )
    }
    None => fail("expected request-backed if-arm repair evidence")
  }
  match
    dae_single_result_control_pair_repair_evidence(
      mod_,
      then_body,
      else_body,
      base_ref,
      true,
      fn(body) {
        if body == then_body {
          Some((expected_left_ref, None))
        } else if body == else_body {
          Some((expected_right_ref, None))
        } else {
          None
        }
      },
    ) {
    Some(evidence) => {
      assert_true(evidence.application.result_is_void)
      assert_eq(
        evidence.rewritten,
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          then_body,
          Some(else_body),
        ),
      )
    }
    None => fail("expected void-result if-arm repair evidence")
  }
}

///|
test "dae control result pair GC evidence centralizes terminal arm LUB rewrites" {
  let base_type = @lib.TypeIdx::new(0U)
  let left_type = @lib.TypeIdx::new(1U)
  let right_type = @lib.TypeIdx::new(2U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let expected_common_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(base_type)),
  )
  let expected_left_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(left_type), exact=true),
  )
  let expected_right_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(right_type), exact=true),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let then_body = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(base_ref),
      @lib.Expr::new([@lib.Instruction::struct_new_default(left_type)]),
    ),
  ]
  let else_body = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(base_ref),
      @lib.Expr::new([@lib.Instruction::struct_new_default(right_type)]),
    ),
  ]
  let then_slice = match
    dae_make_multi_result_control_slice(then_body, 0, 1, 0, false, false) {
    Some(slice) => slice
    None => fail("expected valid then result slice")
  }
  let else_slice = match
    dae_make_multi_result_control_slice(else_body, 0, 1, 0, false, false) {
    Some(slice) => slice
    None => fail("expected valid else result slice")
  }
  let then_evidence = match
    dae_control_result_slice_gc_evidence(mod_, [], None, then_slice, [base_ref]) {
    Some(evidence) => evidence
    None => fail("expected then control-result evidence")
  }
  let else_evidence = match
    dae_control_result_slice_gc_evidence(mod_, [], None, else_slice, [base_ref]) {
    Some(evidence) => evidence
    None => fail("expected else control-result evidence")
  }
  match
    dae_control_result_pair_gc_evidence(mod_, then_evidence, else_evidence, [
      base_ref,
    ]) {
    Some(evidence) => {
      assert_true(evidence.saw_refinement)
      assert_true(evidence.then_body_changed)
      assert_true(evidence.else_body_changed)
      assert_eq(evidence.refined_results[0], expected_common_ref)
      let application_next_results = [base_ref]
      let application_refined_results = [base_ref]
      match
        dae_apply_control_result_pair_refinements(
          evidence,
          application_next_results,
          refined_results=Some(application_refined_results),
        ) {
        Some(application) => {
          assert_eq(application.result_count, 1)
          assert_eq(application.next_results_length, 1)
          assert_eq(application.refined_results_length, 1)
          assert_true(application.saw_refinement)
          assert_eq(application_next_results[0], expected_common_ref)
          assert_eq(application_refined_results[0], expected_common_ref)
        }
        None => fail("expected paired refinement application evidence")
      }
      assert_eq(
        evidence.rewritten_then_body[0],
        @lib.Instruction::block(
          @lib.BlockType::val_type(expected_left_ref),
          @lib.Expr::new([@lib.Instruction::struct_new_default(left_type)]),
        ),
      )
      assert_eq(
        evidence.rewritten_else_body[0],
        @lib.Instruction::block(
          @lib.BlockType::val_type(expected_right_ref),
          @lib.Expr::new([@lib.Instruction::struct_new_default(right_type)]),
        ),
      )
    }
    None => fail("expected paired control-result GC evidence")
  }
  match
    dae_multi_result_if_pair_gc_refinement_evidence(
      mod_,
      [],
      None,
      then_body,
      else_body,
      [base_ref],
    ) {
    Some(evidence) => {
      assert_true(evidence.if_body_changed)
      assert_eq(evidence.pair.refined_results[0], expected_common_ref)
      assert_eq(evidence.pair.rewritten_then_body.length(), 1)
      assert_eq(evidence.pair.rewritten_else_body.length(), 1)
    }
    None => fail("expected fallthrough if-pair refinement evidence")
  }
  let terminal_then_body = [then_body[0], @lib.Instruction::return_()]
  let terminal_else_body = [else_body[0], @lib.Instruction::return_()]
  match
    dae_multi_result_if_pair_gc_refinement_evidence(
      mod_,
      [],
      None,
      terminal_then_body,
      terminal_else_body,
      [base_ref],
      require_terminal_return=true,
    ) {
    Some(evidence) => {
      assert_true(evidence.if_body_changed)
      assert_eq(evidence.pair.refined_results[0], expected_common_ref)
      assert_eq(evidence.pair.rewritten_then_body.length(), 2)
      assert_eq(evidence.pair.rewritten_else_body.length(), 2)
    }
    None => fail("expected terminal-return if-pair refinement evidence")
  }
}

///|
test "dae mixed single-result fallthrough arm evidence centralizes LUB and effect-free arms" {
  let base_type = @lib.TypeIdx::new(0U)
  let left_type = @lib.TypeIdx::new(1U)
  let right_type = @lib.TypeIdx::new(2U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let expected_left_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(left_type), exact=true),
  )
  let expected_common_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(base_type)),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let return_arm = [
    @lib.Instruction::struct_new_default(right_type),
    @lib.Instruction::return_(),
  ]
  match
    dae_mixed_single_result_return_arm_gc_evidence(
      mod_,
      [],
      None,
      return_arm,
      base_ref,
      expected_left_ref,
    ) {
    Some(evidence) => {
      assert_true(evidence.has_return)
      assert_false(evidence.effect_free_fallthrough)
      assert_false(evidence.body_changed)
      assert_eq(evidence.candidate, expected_common_ref)
    }
    None => fail("expected mixed single-result return arm evidence")
  }
  let effect_free_arm = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::drop(),
  ]
  match
    dae_mixed_single_result_return_arm_gc_evidence(
      mod_,
      [],
      None,
      effect_free_arm,
      base_ref,
      expected_left_ref,
    ) {
    Some(evidence) => {
      assert_false(evidence.has_return)
      assert_true(evidence.effect_free_fallthrough)
      assert_false(evidence.body_changed)
      assert_eq(evidence.candidate, expected_left_ref)
    }
    None => fail("expected effect-free single-result fallthrough arm evidence")
  }
  let effectful_arm = [@lib.Instruction::call(@lib.FuncIdx::new(0U))]
  match
    dae_mixed_single_result_return_arm_gc_evidence(
      mod_,
      [],
      None,
      effectful_arm,
      base_ref,
      expected_left_ref,
    ) {
    Some(_) => fail("effectful fallthrough arm should be rejected")
    None => ()
  }
}

///|
test "dae mixed multi-result return arm evidence centralizes LUB and effect-free arms" {
  let base_type = @lib.TypeIdx::new(0U)
  let left_type = @lib.TypeIdx::new(1U)
  let right_type = @lib.TypeIdx::new(2U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let expected_left_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(left_type), exact=true),
  )
  let expected_common_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(base_type)),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let combined_candidates : Array[@lib.ValType?] = [Some(expected_left_ref)]
  let rejected = [false]
  let return_arm = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(base_ref),
      @lib.Expr::new([@lib.Instruction::struct_new_default(right_type)]),
    ),
    @lib.Instruction::return_(),
  ]
  match
    dae_mixed_multi_result_return_arm_gc_evidence(
      mod_,
      [],
      None,
      return_arm,
      [base_ref],
      combined_candidates,
      rejected,
    ) {
    Some(evidence) => {
      assert_true(evidence.has_return)
      assert_false(evidence.effect_free_fallthrough)
      assert_eq(evidence.result_start, 0)
      assert_eq(combined_candidates[0], Some(expected_common_ref))
      assert_false(rejected[0])
    }
    None => fail("expected mixed multi-result return arm evidence")
  }
  let effect_free_arm = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::drop(),
  ]
  match
    dae_mixed_multi_result_return_arm_gc_evidence(
      mod_,
      [],
      None,
      effect_free_arm,
      [base_ref],
      combined_candidates,
      rejected,
    ) {
    Some(evidence) => {
      assert_false(evidence.has_return)
      assert_true(evidence.effect_free_fallthrough)
      assert_eq(evidence.result_start, -1)
      assert_eq(evidence.body.length(), 2)
    }
    None => fail("expected effect-free fallthrough arm evidence")
  }
}

///|
test "dae control result single refinement application centralizes next-result repair" {
  let base_type = @lib.TypeIdx::new(0U)
  let leaf_type = @lib.TypeIdx::new(1U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let leaf_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf_type), exact=true),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let body = [@lib.Instruction::struct_new_default(leaf_type)]
  let slice = match
    dae_make_multi_result_control_slice(body, 0, 1, 0, false, false) {
    Some(slice) => slice
    None => fail("expected one-slot control-result slice")
  }
  let evidence = match
    dae_control_result_slice_gc_evidence(mod_, [], None, slice, [base_ref]) {
    Some(evidence) => evidence
    None => fail("expected control-result GC evidence")
  }
  let next_results = [base_ref]
  let refined_results = [base_ref]
  match
    dae_apply_control_result_single_refinements(
      evidence,
      next_results,
      refined_results=Some(refined_results),
    ) {
    Some(application) => {
      assert_eq(application.result_count, 1)
      assert_true(application.saw_refinement)
      assert_eq(application.next_results_length, 1)
      assert_eq(application.refined_results_length, 1)
      assert_eq(application.body_changed, false)
      assert_eq(next_results[0], leaf_ref)
      assert_eq(refined_results[0], leaf_ref)
    }
    None => fail("expected single refinement application evidence")
  }
}

///|
test "dae parametric typeidx arm evidence reuses control result GC carrier" {
  let base_type = @lib.TypeIdx::new(0U)
  let leaf_type = @lib.TypeIdx::new(1U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let expected_leaf_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf_type), exact=true),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let arm_body = [
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      @lib.BlockType::val_type(base_ref),
      @lib.Expr::new([@lib.Instruction::struct_new_default(leaf_type)]),
    ),
    @lib.Instruction::struct_new_default(leaf_type),
  ]
  match
    dae_parametric_typeidx_multi_result_arm_gc_evidence(
      mod_,
      [],
      None,
      arm_body,
      1,
      [base_ref, base_ref],
    ) {
    Some(evidence) => {
      assert_true(evidence.saw_candidate)
      assert_true(evidence.body_changed)
      assert_eq(evidence.result_start, 1)
      assert_eq(evidence.candidates[0], Some(expected_leaf_ref))
      assert_eq(evidence.candidates[1], Some(expected_leaf_ref))
      assert_eq(evidence.refined_candidates[0], Some(expected_leaf_ref))
      assert_eq(evidence.refined_candidates[1], Some(expected_leaf_ref))
      assert_eq(evidence.body, arm_body)
      assert_eq(
        evidence.rewritten_body[1],
        @lib.Instruction::block(
          @lib.BlockType::val_type(expected_leaf_ref),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf_type)]),
        ),
      )
      assert_eq(evidence.rewritten_body[2], arm_body[2])
    }
    None => fail("expected parametric typeidx arm evidence carrier")
  }
}

///|
test "dae single-result control GC evidence centralizes block and loop rewrites" {
  let base_type = @lib.TypeIdx::new(0U)
  let leaf_type = @lib.TypeIdx::new(1U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let expected_leaf_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf_type), exact=true),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let nested_old_block = @lib.Instruction::block(
    @lib.BlockType::val_type(base_ref),
    @lib.Expr::new([@lib.Instruction::struct_new_default(leaf_type)]),
  )
  let body = [nested_old_block]
  let evidence = match
    dae_single_result_control_gc_candidate_evidence(
      mod_,
      [],
      None,
      @lib.BlockType::val_type(base_ref),
      body,
      base_ref,
    ) {
    Some(evidence) => evidence
    None => fail("expected single-result control GC candidate evidence")
  }
  assert_eq(evidence.candidate, expected_leaf_ref)
  assert_true(evidence.body_changed)
  assert_eq(evidence.body, body)
  assert_eq(
    evidence.rewritten_body[0],
    @lib.Instruction::struct_new_default(leaf_type),
  )
  match dae_apply_single_result_control_gc_candidate_evidence(evidence, 0) {
    Some(rewritten_block) =>
      assert_eq(
        rewritten_block,
        @lib.Instruction::block(
          @lib.BlockType::val_type(expected_leaf_ref),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf_type)]),
        ),
      )
    None => fail("expected block rewrite from control GC candidate evidence")
  }
  match dae_apply_single_result_control_gc_candidate_evidence(evidence, 1) {
    Some(rewritten_loop) =>
      assert_eq(
        rewritten_loop,
        @lib.Instruction::loop_(
          @lib.BlockType::val_type(expected_leaf_ref),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf_type)]),
        ),
      )
    None => fail("expected loop rewrite from control GC candidate evidence")
  }
  match dae_apply_single_result_control_gc_candidate_evidence(evidence, 2) {
    Some(_) =>
      fail(
        "single-result control candidate evidence should reject if-kind application",
      )
    None => ()
  }
}

///|
test "dae multi-result operand slot evidence centralizes suffix scan fallback" {
  let mod_ = @lib.Module::new()
  let body = [
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::drop(),
    @lib.Instruction::i64_const(@lib.I64(10L)),
    @lib.Instruction::i32_const(@lib.I32(1)),
  ]
  let prefix = match
    dae_multi_result_operand_slot_prefix_evidence(body, 0, body.length()) {
    Some(evidence) => evidence
    None => fail("expected skipped dropped-pair slot prefix evidence")
  }
  assert_eq(prefix.start, 0)
  assert_eq(prefix.end, body.length())
  assert_eq(prefix.operand_start, 2)
  assert_eq(prefix.next, 2)
  assert_eq(prefix.skipped_pairs, 1)
  assert_false(prefix.consumed_single_producer)
  match
    dae_multi_result_operand_slot_single_producer_evidence(
      mod_,
      [],
      body,
      prefix,
    ) {
    Some(evidence) => {
      assert_eq(evidence.operand_start, 2)
      assert_eq(evidence.next, 3)
      assert_eq(evidence.skipped_pairs, 1)
      assert_true(evidence.consumed_single_producer)
    }
    None => fail("expected single-producer fallback slot evidence")
  }
  match dae_multi_result_operand_slot_prefix_evidence(body, 0, 2) {
    Some(_) => fail("slot prefix evidence must reject exhausted suffixes")
    None => ()
  }
  match dae_multi_result_operand_slot_prefix_evidence(body, -1, body.length()) {
    Some(_) => fail("slot prefix evidence must reject out-of-range starts")
    None => ()
  }
}

///|
test "dae indexed instruction rewrite evidence centralizes shared body edits" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_const(@lib.I32(3)),
  ]
  let rewrites : Array[@lib.Instruction?] = [
    Some(@lib.Instruction::i32_const(@lib.I32(10))),
    None,
    Some(@lib.Instruction::i32_const(@lib.I32(30))),
  ]
  match
    dae_apply_indexed_instruction_rewrites_to_body(body, [0, 1, 2], rewrites) {
    Some((rewritten, evidence)) => {
      assert_true(evidence.body_changed)
      assert_eq(evidence.target_count, 3)
      assert_eq(evidence.rewrite_count, 2)
      assert_eq(rewritten[0], @lib.Instruction::i32_const(@lib.I32(10)))
      assert_eq(rewritten[1], body[1])
      assert_eq(rewritten[2], @lib.Instruction::i32_const(@lib.I32(30)))
    }
    None => fail("expected shared indexed rewrite evidence")
  }
  match
    dae_apply_indexed_instruction_rewrites_to_body(body, [0, 1, 1], rewrites) {
    Some(_) => fail("indexed rewrite evidence must reject duplicate targets")
    None => ()
  }
  match
    dae_apply_indexed_instruction_rewrites_to_body(body, [0, 3], [None, None]) {
    Some(_) => fail("indexed rewrite evidence must reject out-of-range targets")
    None => ()
  }
}

///|
test "dae first instruction rewrite evidence centralizes body repair scans" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_const(@lib.I32(3)),
  ]
  let rewrite_second = fn(instr : @lib.Instruction) -> @lib.Instruction? {
    match instr {
      @lib.I32Const(@lib.I32(2)) =>
        Some(@lib.Instruction::i32_const(@lib.I32(20)))
      _ => None
    }
  }
  match dae_apply_first_instruction_rewrite_to_body(body, rewrite_second) {
    Some((rewritten, evidence)) => {
      assert_true(evidence.body_changed)
      assert_eq(evidence.target_count, 1)
      assert_eq(evidence.rewrite_count, 1)
      assert_eq(rewritten[0], body[0])
      assert_eq(rewritten[1], @lib.Instruction::i32_const(@lib.I32(20)))
      assert_eq(rewritten[2], body[2])
    }
    None => fail("expected first-instruction rewrite evidence")
  }
  let no_rewrite = fn(_instr : @lib.Instruction) -> @lib.Instruction? { None }
  match dae_apply_first_instruction_rewrite_to_body(body, no_rewrite) {
    Some(_) => fail("first-instruction rewrite should reject no-match bodies")
    None => ()
  }
}

///|
test "dae control child rewrite helper centralizes recursive body repair" {
  let then_body = [@lib.Instruction::i32_const(@lib.I32(1))]
  let else_body = [@lib.Instruction::i32_const(@lib.I32(2))]
  let rewrite_else = fn(
    body : Array[@lib.Instruction],
  ) -> Array[@lib.Instruction]? {
    if body == else_body {
      Some([@lib.Instruction::i32_const(@lib.I32(20))])
    } else {
      None
    }
  }
  match
    dae_try_rewrite_first_control_child_body(
      @lib.Instruction::if_(@lib.BlockType::void_(), then_body, Some(else_body)),
      rewrite_else,
    ) {
    Some(@lib.If(_, rewritten_then, Some(rewritten_else))) => {
      assert_eq(rewritten_then, then_body)
      assert_eq(rewritten_else, [@lib.Instruction::i32_const(@lib.I32(20))])
    }
    _ => fail("expected if else-child rewrite")
  }
  let rewrite_any_single = fn(
    body : Array[@lib.Instruction],
  ) -> Array[@lib.Instruction]? {
    if body.length() == 1 {
      Some([@lib.Instruction::i32_const(@lib.I32(99))])
    } else {
      None
    }
  }
  match
    dae_try_rewrite_first_control_child_body(
      @lib.Instruction::if_(@lib.BlockType::void_(), then_body, Some(else_body)),
      rewrite_any_single,
    ) {
    Some(@lib.If(_, rewritten_then, Some(rewritten_else))) => {
      assert_eq(rewritten_then, [@lib.Instruction::i32_const(@lib.I32(99))])
      assert_eq(rewritten_else, else_body)
    }
    _ => fail("expected helper to rewrite the first eligible control child")
  }
  match
    dae_try_rewrite_first_control_child_body(
      @lib.Instruction::i32_const(@lib.I32(3)),
      rewrite_any_single,
    ) {
    Some(_) => fail("non-control instructions should not rewrite children")
    None => ()
  }
}

///|
test "dae recursive body rewrite helper centralizes current and child repair scans" {
  let root_body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
  ]
  let rewrite_current = fn(
    body : Array[@lib.Instruction],
  ) -> Array[@lib.Instruction]? {
    if body == root_body {
      Some([@lib.Instruction::i32_const(@lib.I32(10))])
    } else {
      None
    }
  }
  let rewrite_child_never = fn(
    _body : Array[@lib.Instruction],
  ) -> Array[@lib.Instruction]? {
    Some([@lib.Instruction::i32_const(@lib.I32(99))])
  }
  match
    dae_apply_first_current_or_control_child_body_rewrite(
      root_body, rewrite_current, rewrite_child_never,
    ) {
    Some(rewritten) =>
      assert_eq(rewritten, [@lib.Instruction::i32_const(@lib.I32(10))])
    None => fail("expected current body rewrite to win")
  }

  let then_body = [@lib.Instruction::i32_const(@lib.I32(3))]
  let else_body = [@lib.Instruction::i32_const(@lib.I32(4))]
  let outer_body = [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::if_(@lib.BlockType::void_(), then_body, Some(else_body)),
  ]
  let no_current = fn(
    _body : Array[@lib.Instruction],
  ) -> Array[@lib.Instruction]? {
    None
  }
  let rewrite_else = fn(
    body : Array[@lib.Instruction],
  ) -> Array[@lib.Instruction]? {
    if body == else_body {
      Some([@lib.Instruction::i32_const(@lib.I32(40))])
    } else {
      None
    }
  }
  match
    dae_apply_first_current_or_control_child_body_rewrite(
      outer_body, no_current, rewrite_else,
    ) {
    Some(rewritten) =>
      match rewritten[1] {
        @lib.If(_, rewritten_then, Some(rewritten_else)) => {
          assert_eq(rewritten[0], outer_body[0])
          assert_eq(rewritten_then, then_body)
          assert_eq(rewritten_else, [@lib.Instruction::i32_const(@lib.I32(40))])
        }
        _ => fail("expected nested control child rewrite")
      }
    None => fail("expected child body rewrite")
  }
}

///|
test "dae recursive body rewrite application evidence centralizes repair planning" {
  let root_body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
  ]
  let rewrite_current = fn(
    body : Array[@lib.Instruction],
  ) -> Array[@lib.Instruction]? {
    if body == root_body {
      Some([@lib.Instruction::i32_const(@lib.I32(10))])
    } else {
      None
    }
  }
  let rewrite_child_never = fn(
    _body : Array[@lib.Instruction],
  ) -> Array[@lib.Instruction]? {
    Some([@lib.Instruction::i32_const(@lib.I32(99))])
  }
  match
    dae_apply_first_recursive_body_rewrite(
      root_body, rewrite_current, rewrite_child_never,
    ) {
    Some((rewritten, evidence)) => {
      assert_eq(rewritten, [@lib.Instruction::i32_const(@lib.I32(10))])
      assert_true(evidence.applied_to_current_body)
      assert_eq(evidence.target_count, 0)
      assert_eq(evidence.rewrite_count, 1)
      assert_true(evidence.body_changed)
    }
    None => fail("expected current body rewrite application evidence")
  }

  let then_body = [@lib.Instruction::i32_const(@lib.I32(3))]
  let else_body = [@lib.Instruction::i32_const(@lib.I32(4))]
  let outer_body = [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::if_(@lib.BlockType::void_(), then_body, Some(else_body)),
  ]
  let no_current = fn(
    _body : Array[@lib.Instruction],
  ) -> Array[@lib.Instruction]? {
    None
  }
  let rewrite_else = fn(
    body : Array[@lib.Instruction],
  ) -> Array[@lib.Instruction]? {
    if body == else_body {
      Some([@lib.Instruction::i32_const(@lib.I32(40))])
    } else {
      None
    }
  }
  match
    dae_apply_first_recursive_body_rewrite(outer_body, no_current, rewrite_else) {
    Some((rewritten, evidence)) => {
      assert_false(evidence.applied_to_current_body)
      assert_eq(evidence.target_count, 1)
      assert_eq(evidence.rewrite_count, 1)
      assert_true(evidence.body_changed)
      match rewritten[1] {
        @lib.If(_, rewritten_then, Some(rewritten_else)) => {
          assert_eq(rewritten[0], outer_body[0])
          assert_eq(rewritten_then, then_body)
          assert_eq(rewritten_else, [@lib.Instruction::i32_const(@lib.I32(40))])
        }
        _ => fail("expected nested control child rewrite")
      }
    }
    None => fail("expected child body rewrite application evidence")
  }

  match
    dae_apply_first_recursive_control_child_body_rewrite(
      outer_body, rewrite_else,
    ) {
    Some((rewritten, evidence)) => {
      assert_false(evidence.applied_to_current_body)
      assert_eq(evidence.target_count, 1)
      assert_eq(evidence.rewrite_count, 1)
      assert_true(evidence.body_changed)
      match rewritten[1] {
        @lib.If(_, rewritten_then, Some(rewritten_else)) => {
          assert_eq(rewritten[0], outer_body[0])
          assert_eq(rewritten_then, then_body)
          assert_eq(rewritten_else, [@lib.Instruction::i32_const(@lib.I32(40))])
        }
        _ => fail("expected control-child-only recursive body rewrite")
      }
    }
    None => fail("expected control-child-only application evidence")
  }
  match
    dae_apply_first_recursive_control_child_body_rewrite(
      root_body, rewrite_else,
    ) {
    Some(_) =>
      fail(
        "control-child-only rewrite should reject bodies without rewritten control children",
      )
    None => ()
  }

  let rewrite_second_instr = fn(instr : @lib.Instruction) -> @lib.Instruction? {
    match instr {
      @lib.I32Const(@lib.I32(2)) =>
        Some(@lib.Instruction::i32_const(@lib.I32(22)))
      _ => None
    }
  }
  match
    dae_apply_first_recursive_instruction_body_rewrite_to_body(
      root_body, rewrite_second_instr,
    ) {
    Some(rewritten) => {
      assert_eq(rewritten[0], root_body[0])
      assert_eq(rewritten[1], @lib.Instruction::i32_const(@lib.I32(22)))
    }
    None =>
      fail("expected instruction rewrite adapter to return rewritten body")
  }
  let rewrite_no_instr = fn(_instr : @lib.Instruction) -> @lib.Instruction? {
    None
  }
  match
    dae_apply_first_recursive_instruction_body_rewrite_to_body(
      root_body, rewrite_no_instr,
    ) {
    Some(_) => fail("instruction rewrite adapter should reject no-match bodies")
    None => ()
  }
}

///|
test "dae body rewrite fixpoint evidence centralizes bounded convergence" {
  let start_body = [@lib.Instruction::i32_const(@lib.I32(0))]
  let rewrite_until_three = fn(
    body : Array[@lib.Instruction],
  ) -> Array[@lib.Instruction]? {
    if body.length() != 1 {
      return None
    }
    match body[0] {
      @lib.I32Const(@lib.I32(value)) if value < 3 =>
        Some([@lib.Instruction::i32_const(@lib.I32(value + 1))])
      _ => None
    }
  }
  match
    dae_apply_body_rewrite_until_stable(start_body, rewrite_until_three, 8) {
    Some((rewritten, evidence)) => {
      assert_eq(rewritten, [@lib.Instruction::i32_const(@lib.I32(3))])
      assert_eq(evidence.max_iters, 8)
      assert_eq(evidence.iteration_count, 3)
      assert_false(evidence.reached_limit)
      assert_true(evidence.body_changed)
    }
    None => fail("expected bounded fixpoint evidence")
  }
  match
    dae_apply_body_rewrite_until_stable(start_body, rewrite_until_three, 2) {
    Some((rewritten, evidence)) => {
      assert_eq(rewritten, [@lib.Instruction::i32_const(@lib.I32(2))])
      assert_eq(evidence.iteration_count, 2)
      assert_true(evidence.reached_limit)
      assert_true(evidence.body_changed)
    }
    None => fail("expected bounded limit evidence")
  }
  match
    dae_apply_body_rewrite_until_stable(
      [@lib.Instruction::i32_const(@lib.I32(3))],
      rewrite_until_three,
      8,
    ) {
    Some(_) => fail("unchanged fixpoint should not report a rewrite")
    None => ()
  }
}

///|
test "dae result rewrite application evidence centralizes masked slot repairs" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_const(@lib.I32(3)),
  ]
  let rewrites : Array[@lib.Instruction?] = [
    None,
    Some(@lib.Instruction::i32_const(@lib.I32(20))),
    Some(@lib.Instruction::i32_const(@lib.I32(30))),
  ]
  match dae_apply_result_rewrites_to_body(body, 0, rewrites) {
    Some((rewritten, evidence)) => {
      assert_true(evidence.body_changed)
      assert_eq(evidence.start, 0)
      assert_eq(evidence.result_count, 3)
      assert_eq(evidence.rewrite_count, 2)
      assert_eq(rewritten[0], body[0])
      assert_eq(rewritten[1], @lib.Instruction::i32_const(@lib.I32(20)))
      assert_eq(rewritten[2], @lib.Instruction::i32_const(@lib.I32(30)))
    }
    None => fail("expected unmasked result rewrite evidence")
  }
  match
    dae_apply_result_rewrites_to_body(
      body,
      0,
      rewrites,
      active=Some([true, false, true]),
    ) {
    Some((rewritten, evidence)) => {
      assert_true(evidence.body_changed)
      assert_eq(evidence.start, 0)
      assert_eq(evidence.result_count, 3)
      assert_eq(evidence.rewrite_count, 1)
      assert_eq(rewritten[0], body[0])
      assert_eq(rewritten[1], body[1])
      assert_eq(rewritten[2], @lib.Instruction::i32_const(@lib.I32(30)))
    }
    None => fail("expected masked result rewrite evidence")
  }
  match
    dae_apply_result_rewrites_to_body(
      body,
      1,
      rewrites,
      active=Some([true, false]),
    ) {
    Some(_) =>
      fail("mismatched active mask must reject result rewrite evidence")
    None => ()
  }
  match dae_apply_result_rewrites_to_body(body, 2, rewrites) {
    Some(_) => fail("out-of-range rewrite window must reject")
    None => ()
  }
}

///|
test "dae select value rewrite application evidence centralizes select repairs" {
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let refined_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let body = [
    @lib.Instruction::ref_null_type(
      @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
    ),
    @lib.Instruction::ref_null_type(
      @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::select(types=Some([base_ref])),
  ]
  let rewritten_left = @lib.Instruction::ref_null_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let rewritten_select = @lib.Instruction::select(types=Some([refined_ref]))
  match
    dae_apply_select_value_rewrites_to_body(
      body,
      0,
      1,
      3,
      Some(rewritten_left),
      None,
      Some(rewritten_select),
    ) {
    Some((rewritten, evidence)) => {
      assert_true(evidence.body_changed)
      assert_eq(evidence.left_idx, 0)
      assert_eq(evidence.right_idx, 1)
      assert_eq(evidence.select_idx, 3)
      assert_eq(evidence.rewrite_count, 2)
      assert_eq(rewritten[0], rewritten_left)
      assert_eq(rewritten[1], body[1])
      assert_eq(rewritten[3], rewritten_select)
    }
    None => fail("expected select rewrite application evidence")
  }
  match
    dae_apply_select_value_rewrites_to_body(body, 0, 1, 3, None, None, None) {
    Some((rewritten, evidence)) => {
      assert_false(evidence.body_changed)
      assert_eq(evidence.rewrite_count, 0)
      assert_eq(rewritten, body)
    }
    None => fail("expected unchanged select rewrite application evidence")
  }
  match
    dae_apply_select_value_rewrites_to_body(
      body,
      0,
      3,
      1,
      None,
      None,
      Some(rewritten_select),
    ) {
    Some(_) => fail("select rewrite application must reject unsorted slots")
    None => ()
  }
  match
    dae_apply_select_value_rewrites_to_body(
      body,
      0,
      1,
      4,
      None,
      None,
      Some(rewritten_select),
    ) {
    Some(_) => fail("select rewrite application must reject out-of-range slots")
    None => ()
  }
}

///|
test "dae mixed return-arm rewrite evidence centralizes refined slot repairs" {
  let base_type = @lib.TypeIdx::new(0U)
  let leaf_type = @lib.TypeIdx::new(1U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let leaf_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf_type), exact=true),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let old_slot = @lib.Instruction::block(
    @lib.BlockType::val_type(base_ref),
    @lib.Expr::new([@lib.Instruction::struct_new_default(leaf_type)]),
  )
  let scalar_slot = @lib.Instruction::i32_const(@lib.I32(7))
  let evidence : DaeMixedMultiResultReturnArmGcEvidence = {
    body: [old_slot, scalar_slot],
    result_start: 0,
    flattened: false,
    has_return: true,
    effect_free_fallthrough: false,
  }
  match
    dae_apply_mixed_multi_result_return_arm_refinements(
      mod_,
      [],
      None,
      evidence,
      [base_ref, @lib.ValType::i32()],
      [true, false],
    ) {
    Some(rewrite) => {
      assert_true(rewrite.body_changed)
      assert_eq(
        rewrite.body[0],
        @lib.Instruction::block(
          @lib.BlockType::val_type(leaf_ref),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf_type)]),
        ),
      )
      assert_eq(rewrite.body[1], scalar_slot)
    }
    None => fail("expected mixed return-arm rewrite evidence")
  }
  let fallthrough : DaeMixedMultiResultReturnArmGcEvidence = {
    body: [scalar_slot],
    result_start: -1,
    flattened: false,
    has_return: false,
    effect_free_fallthrough: true,
  }
  match
    dae_apply_mixed_multi_result_return_arm_refinements(
      mod_,
      [],
      None,
      fallthrough,
      [base_ref],
      [true],
    ) {
    Some(rewrite) => {
      assert_false(rewrite.body_changed)
      assert_eq(rewrite.body[0], scalar_slot)
    }
    None => fail("expected fallthrough arm rewrite evidence")
  }
}

///|
test "dae GC actual shape evidence centralizes control and select repairs" {
  let base_type = @lib.TypeIdx::new(0U)
  let leaf_type = @lib.TypeIdx::new(1U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let expected_leaf_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf_type), exact=true),
  )
  let expected_nullable_leaf_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(leaf_type), exact=true),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let control_body = [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::block(
      @lib.BlockType::val_type(expected_leaf_ref),
      @lib.Expr::new([@lib.Instruction::struct_new_default(leaf_type)]),
    ),
  ]
  match
    dae_gc_actual_shape_evidence(
      control_body,
      { start: 0, end: 2, pure: true },
      mod_,
      base_ref,
      [],
    ) {
    Some(evidence) => {
      assert_eq(evidence.candidate, expected_leaf_ref)
      assert_eq(evidence.refined_candidate, Some(expected_leaf_ref))
      assert_eq(evidence.left_rewrite, None)
      assert_eq(evidence.right_rewrite, None)
      assert_eq(evidence.terminal_rewrite, None)
    }
    None => fail("expected control actual shape evidence")
  }
  let select_body = [
    @lib.Instruction::ref_null_type(
      @lib.RefType::new(true, @lib.HeapType::new(base_type)),
    ),
    @lib.Instruction::struct_new_default(leaf_type),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::select(types=Some([base_ref])),
  ]
  match
    dae_gc_actual_shape_evidence(
      select_body,
      { start: 0, end: 4, pure: true },
      mod_,
      expected_nullable_leaf_ref,
      [],
      rewrite_type=Some(expected_nullable_leaf_ref),
    ) {
    Some(evidence) => {
      assert_eq(evidence.candidate, expected_nullable_leaf_ref)
      assert_eq(evidence.refined_candidate, None)
      assert_eq(
        evidence.left_rewrite,
        Some(
          @lib.Instruction::ref_null_type(
            @lib.RefType::new(true, @lib.HeapType::new(leaf_type), exact=true),
          ),
        ),
      )
      assert_eq(evidence.right_rewrite, None)
      assert_eq(
        evidence.terminal_rewrite,
        Some(@lib.Instruction::select(types=Some([expected_nullable_leaf_ref]))),
      )
    }
    None => fail("expected select actual shape rewrite evidence")
  }
}

///|
test "dae select value slices centralize operand and condition bounds" {
  let ref_type = @lib.TypeIdx::new(0U)
  let ref_val = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(ref_type)),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let body = [
    @lib.Instruction::struct_new_default(ref_type),
    @lib.Instruction::block(
      @lib.BlockType::val_type(ref_val),
      @lib.Expr::new([@lib.Instruction::struct_new_default(ref_type)]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::select(types=Some([ref_val])),
  ]
  match dae_find_select_value_slices(mod_, [], body, 3) {
    Some(slices) => {
      assert_eq(slices.left.start, 0)
      assert_eq(slices.left.end, 1)
      assert_eq(slices.right.start, 1)
      assert_eq(slices.right.end, 2)
      assert_eq(slices.condition_start, 2)
      assert_eq(slices.select_idx, 3)
      assert_false(slices.left.has_effect_or_branch)
      assert_false(slices.right.has_effect_or_branch)
    }
    None => fail("expected reusable select value slice bounds")
  }
  match dae_find_select_value_slices(mod_, [], body, 3, required_left_start=1) {
    Some(_) => fail("expected required left-start mismatch to reject slices")
    None => ()
  }
}

///|
test "dae multi-result suffix bounds centralize terminal result scans" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i64_const(@lib.I64(3L)),
  ]
  let bounds = dae_multi_result_suffix_bounds_evidence(body, 2, 1)
  assert_eq(bounds.length(), 2)
  assert_eq(bounds[0].suffix_start, 0)
  assert_eq(bounds[0].operand_end, 4)
  assert_false(bounds[0].has_terminal_return)
  assert_eq(bounds[1].suffix_start, 2)
  assert_eq(bounds[1].operand_end, 4)
  assert_false(bounds[1].has_terminal_return)

  let terminal_body = [
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(5)),
    @lib.Instruction::i64_const(@lib.I64(6L)),
    @lib.Instruction::return_(),
  ]
  let terminal_bounds = dae_multi_result_suffix_bounds_evidence(
    terminal_body, 2, 1,
  )
  assert_eq(terminal_bounds.length(), 4)
  assert_eq(terminal_bounds[2].suffix_start, 0)
  assert_eq(terminal_bounds[2].operand_end, 4)
  assert_true(terminal_bounds[2].has_terminal_return)
  assert_eq(terminal_bounds[3].suffix_start, 2)
  assert_eq(terminal_bounds[3].operand_end, 4)
  assert_true(terminal_bounds[3].has_terminal_return)

  let too_short_select = dae_multi_result_suffix_bounds_evidence(body, 2, 3)
  assert_eq(too_short_select.length(), 0)
}

///|
test "dae operand disposition centralizes removed operand repair" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ]
  let pure_disp = match dae_operand_disposition_from_range(body, 0, 2) {
    Some(disposition) => disposition
    None => fail("expected pure operand disposition")
  }
  assert_true(pure_disp.droppable_without_repair)
  assert_false(pure_disp.preserve_effects_on_removal)
  assert_false(pure_disp.has_effect_or_branch)
  let call_disp = match dae_operand_disposition_from_range(body, 2, 3) {
    Some(disposition) => disposition
    None => fail("expected effectful operand disposition")
  }
  assert_false(call_disp.droppable_without_repair)
  assert_true(call_disp.preserve_effects_on_removal)
  assert_true(call_disp.has_effect_or_branch)
  assert_true(dae_operand_disposition_drops_without_repair(pure_disp))
  assert_true(dae_operand_disposition_needs_repair_on_removal(call_disp))
  let branch_body = [@lib.Instruction::br(@lib.LabelIdx::new(0U))]
  let branch_disp = match
    dae_operand_disposition_from_range(branch_body, 0, 1) {
    Some(disposition) => disposition
    None => fail("expected branch operand disposition")
  }
  assert_true(dae_operand_disposition_rejects_direct_removal(branch_disp))
  assert_false(dae_operand_disposition_needs_repair_on_removal(branch_disp))
  let dropped : Array[@lib.Instruction] = []
  dae_append_operand_with_removal_plan(
    dropped,
    body,
    dae_operand_removal_plan(call_disp, false),
  )
  assert_eq(dropped, [body[2], @lib.Instruction::drop()])
  let kept : Array[@lib.Instruction] = []
  dae_append_operand_with_removal_plan(
    kept,
    body,
    dae_operand_removal_plan(pure_disp, true),
  )
  assert_eq(kept, [body[0], body[1]])
}

///|
test "dae dead suffix evidence centralizes unreachable tails" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::unreachable_(),
    @lib.Instruction::call(@lib.FuncIdx::new(2U)),
    @lib.Instruction::drop(),
  ]
  match dae_dead_suffix_evidence(body) {
    Some(evidence) => {
      assert_eq(evidence.root_idx, 1)
      assert_eq(evidence.suffix_start, 2)
      assert_eq(evidence.suffix, [body[2], body[3]])
    }
    None => fail("expected dead suffix evidence")
  }
  match dae_dead_suffix_evidence([@lib.Instruction::nop()]) {
    Some(_) => fail("non-terminal bodies must not expose dead suffix evidence")
    None => ()
  }
}

///|
test "dae direct call target evidence centralizes count and live undropped facts" {
  let callee = @lib.FuncIdx::new(2U)
  let block_type = @lib.BlockType::void_()
  let body = [
    @lib.Instruction::call(callee),
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      block_type,
      @lib.Expr::new([@lib.Instruction::call(callee)]),
    ),
    @lib.Instruction::unreachable_(),
    @lib.Instruction::call(callee),
    @lib.Instruction::return_call(callee),
  ]
  let evidence = dae_direct_call_target_evidence(body, 2)
  assert_eq(evidence.direct_call_count, 3)
  assert_eq(evidence.dropped_direct_call_count, 1)
  assert_true(evidence.has_direct_call)
  assert_true(evidence.has_undropped_direct_call)
  assert_true(evidence.has_live_undropped_direct_call)

  let dead_suffix_only = [
    @lib.Instruction::unreachable_(),
    @lib.Instruction::call(callee),
  ]
  let dead_evidence = dae_direct_call_target_evidence(dead_suffix_only, 2)
  assert_eq(dead_evidence.direct_call_count, 1)
  assert_true(dead_evidence.has_undropped_direct_call)
  assert_false(dead_evidence.has_live_undropped_direct_call)
  assert_eq(dae_count_direct_call_anywhere_to(dead_suffix_only, 2), 1)
  assert_false(
    dae_direct_call_target_evidence(dead_suffix_only, 2).has_live_undropped_direct_call,
  )
}

///|
test "dae dead suffix direct call evidence centralizes dropped and undropped facts" {
  let callee = @lib.FuncIdx::new(2U)
  let block_type = @lib.BlockType::void_()
  let body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::unreachable_(),
    @lib.Instruction::call(callee),
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      block_type,
      @lib.Expr::new([@lib.Instruction::call(callee)]),
    ),
    @lib.Instruction::return_call(callee),
  ]
  match dae_dead_suffix_direct_call_evidence(body, 2) {
    Some(evidence) => {
      assert_true(evidence.has_dropped_direct_call)
      assert_true(evidence.has_undropped_direct_call)
    }
    None => fail("expected reusable dead-suffix direct-call evidence")
  }
  match dae_dead_suffix_direct_call_evidence([@lib.Instruction::nop()], 2) {
    Some(_) => fail("non-dead suffix body must not expose target facts")
    None => ()
  }
}

///|
test "dae control-result undropped direct-call evidence centralizes suffix block scans" {
  let callee = @lib.FuncIdx::new(2U)
  let result_block = @lib.Instruction::block(
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @lib.Expr::new([@lib.Instruction::call(callee)]),
  )
  match dae_control_result_undropped_direct_call_evidence(result_block, 2) {
    Some(evidence) => {
      assert_true(evidence.result_arity_known)
      assert_eq(evidence.result_arity, 1)
      assert_true(evidence.has_result)
      assert_true(evidence.primary_has_undropped_direct_call)
      assert_false(evidence.secondary_has_undropped_direct_call)
      assert_true(evidence.has_undropped_direct_call)
      assert_true(evidence.blocks_result_removal)
    }
    None => fail("expected result block evidence")
  }

  let void_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [@lib.Instruction::call(callee)],
    Some([@lib.Instruction::call(callee)]),
  )
  match dae_control_result_undropped_direct_call_evidence(void_if, 2) {
    Some(evidence) => {
      assert_true(evidence.result_arity_known)
      assert_eq(evidence.result_arity, 0)
      assert_false(evidence.has_result)
      assert_true(evidence.primary_has_undropped_direct_call)
      assert_true(evidence.secondary_has_undropped_direct_call)
      assert_true(evidence.has_undropped_direct_call)
      assert_false(evidence.blocks_result_removal)
    }
    None => fail("expected void if evidence")
  }

  let typeidx_if = @lib.Instruction::if_(
    @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
    [],
    Some([@lib.Instruction::call(callee)]),
  )
  match dae_control_result_undropped_direct_call_evidence(typeidx_if, 2) {
    Some(evidence) => {
      assert_false(evidence.result_arity_known)
      assert_eq(evidence.result_arity, 0)
      assert_true(evidence.has_result)
      assert_false(evidence.primary_has_undropped_direct_call)
      assert_true(evidence.secondary_has_undropped_direct_call)
      assert_true(evidence.blocks_result_removal)
    }
    None => fail("expected typeidx if evidence")
  }

  match
    dae_control_result_undropped_direct_call_evidence(
      @lib.Instruction::call(callee),
      2,
    ) {
    Some(_) => fail("non-control instruction must not expose control evidence")
    None => ()
  }
}

///|
test "dae stack operand evidence centralizes source slices and updates" {
  let bool_stack = [false, true, true, false]
  let window = match dae_stack_operand_window_evidence(bool_stack.length(), 2) {
    Some(window) => window
    None => fail("expected reusable top-of-stack operand window")
  }
  assert_eq(window.start, 2)
  assert_eq(window.end, 4)
  assert_eq(window.requested_operands, 2)
  assert_eq(window.available_operands, 2)
  let underfull = match dae_stack_operand_window_evidence(1, 3) {
    Some(window) => window
    None => fail("expected underfull stack window to keep available operands")
  }
  assert_eq(underfull.start, 0)
  assert_eq(underfull.end, 1)
  assert_eq(underfull.requested_operands, 3)
  assert_eq(underfull.available_operands, 1)
  assert_true(dae_stack_bool_has_true_operand(bool_stack, 2))
  assert_false(dae_stack_bool_has_true_operand(bool_stack, 1))
  dae_stack_bool_apply_effect(bool_stack, 2, 3, true)
  assert_eq(bool_stack, [false, true, true, true, true])

  let int_stack = [-1, 2, 3, 2]
  assert_true(dae_stack_int_has_known_operand(int_stack, 2))
  assert_true(dae_stack_int_has_operand_value(int_stack, 2, 3))
  assert_false(dae_stack_int_has_operand_value(int_stack, 1, 3))
  dae_stack_int_apply_effect(int_stack, 3, 2, -1)
  assert_eq(int_stack, [-1, -1, -1])
}

///|
test "dae stack effect evidence centralizes provenance updates" {
  let mod_ = @lib.Module::new()
  match dae_stack_effect_evidence(@lib.Instruction::i32_add(), mod_, []) {
    Some(evidence) => {
      assert_eq(evidence.inputs, 2)
      assert_eq(evidence.outputs, 1)
    }
    None => fail("expected reusable stack-effect evidence")
  }

  match
    dae_stack_single_value_producer_evidence(
      @lib.Instruction::i32_const(@lib.I32(7)),
      mod_,
      [],
    ) {
    Some(evidence) => {
      assert_eq(evidence.inputs, 0)
      assert_eq(evidence.outputs, 1)
    }
    None => fail("expected reusable stack single-value producer evidence")
  }
  match
    dae_stack_single_value_producer_evidence(
      @lib.Instruction::i32_add(),
      mod_,
      [],
    ) {
    Some(_) => fail("binary op consumes operands before producing one value")
    None => ()
  }

  let bool_stack = [true, false]
  assert_true(
    dae_stack_bool_apply_instr_effect(
      bool_stack,
      @lib.Instruction::i32_add(),
      mod_,
      [],
      true,
    ),
  )
  assert_eq(bool_stack, [true])
  assert_false(
    dae_stack_bool_apply_instr_effect(
      bool_stack,
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      mod_,
      [],
      false,
    ),
  )
  assert_eq(bool_stack, [true])

  let int_stack = [1, 2]
  assert_true(
    dae_stack_int_apply_instr_effect(
      int_stack,
      @lib.Instruction::i32_add(),
      mod_,
      [],
      -1,
    ),
  )
  assert_eq(int_stack, [-1])
  assert_true(
    dae_stack_int_apply_instr_effect(
      int_stack,
      @lib.Instruction::i32_const(@lib.I32(7)),
      mod_,
      [],
      7,
    ),
  )
  assert_eq(int_stack, [-1, 7])
}

///|
test "dae escaping branch evidence centralizes localization blockers" {
  let local_block = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(0U))]),
  )
  match dae_escaping_branch_evidence([local_block], 0) {
    Some(evidence) => {
      assert_eq(evidence.start, 0)
      assert_eq(evidence.end, 1)
      assert_eq(evidence.depth, 0)
      assert_eq(evidence.instr_count, 1)
      assert_false(evidence.has_escaping_branch)
    }
    None => fail("expected reusable no-escaping-branch evidence")
  }
  match dae_no_escaping_branch_evidence([local_block], 0) {
    Some(evidence) => assert_false(evidence.has_escaping_branch)
    None => fail("local branch should be accepted by no-escape evidence")
  }
  match
    dae_escaping_branch_evidence(
      [@lib.Instruction::br(@lib.LabelIdx::new(0U))],
      0,
    ) {
    Some(evidence) => assert_true(evidence.has_escaping_branch)
    None => fail("expected escaping branch evidence")
  }
  match
    dae_no_escaping_branch_evidence(
      [@lib.Instruction::br(@lib.LabelIdx::new(0U))],
      0,
    ) {
    Some(_) => fail("top-level branch should escape depth zero")
    None => ()
  }
  let mixed_instrs = [local_block, @lib.Instruction::br(@lib.LabelIdx::new(0U))]
  match dae_no_escaping_branch_prefix_evidence(mixed_instrs, 1, 0) {
    Some(evidence) => {
      assert_eq(evidence.start, 0)
      assert_eq(evidence.end, 1)
      assert_false(evidence.has_escaping_branch)
    }
    None => fail("local branch prefix should be accepted by prefix evidence")
  }
  match dae_no_escaping_branch_range_evidence(mixed_instrs, 0, 1, 0) {
    Some(evidence) => {
      assert_eq(evidence.start, 0)
      assert_eq(evidence.end, 1)
      assert_false(evidence.has_escaping_branch)
    }
    None => fail("local branch prefix should be accepted by range evidence")
  }
  match dae_no_escaping_branch_copied_range_evidence(mixed_instrs, 0, 1, 0) {
    Some(evidence) => {
      assert_eq(evidence.branch.start, 0)
      assert_eq(evidence.branch.end, 1)
      assert_false(evidence.branch.has_escaping_branch)
      assert_eq(evidence.instrs.length(), 1)
      assert_eq(evidence.instrs[0], local_block)
    }
    None => fail("local branch prefix should be copied by range evidence")
  }
  match dae_no_escaping_branch_copied_prefix_evidence(mixed_instrs, 1, 0) {
    Some(evidence) => {
      assert_eq(evidence.branch.start, 0)
      assert_eq(evidence.branch.end, 1)
      assert_false(evidence.branch.has_escaping_branch)
      assert_eq(evidence.instrs.length(), 1)
      assert_eq(evidence.instrs[0], local_block)
    }
    None => fail("local branch prefix should be copied by prefix evidence")
  }
  match dae_no_escaping_branch_copied_suffix_evidence(mixed_instrs, 1, 0) {
    Some(_) => fail("top-level branch suffix should not be copied")
    None => ()
  }
  match dae_terminal_no_escape_prefix_evidence(mixed_instrs, 0) {
    Some(evidence) => {
      assert_eq(evidence.terminal_idx, 1)
      assert_eq(evidence.prefix.branch.start, 0)
      assert_eq(evidence.prefix.branch.end, 1)
      assert_eq(evidence.prefix.instrs, [local_block])
      assert_eq(evidence.terminal, @lib.Instruction::br(@lib.LabelIdx::new(0U)))
    }
    None => fail("terminal no-escape prefix should copy only the safe prefix")
  }
  match
    dae_terminal_no_escape_prefix_evidence(
      [@lib.Instruction::br(@lib.LabelIdx::new(0U)), @lib.Instruction::drop()],
      0,
    ) {
    Some(_) => fail("terminal no-escape prefix should reject escaping prefixes")
    None => ()
  }
  match dae_terminal_no_escape_prefix_evidence([], 0) {
    Some(_) => fail("terminal no-escape prefix should reject empty bodies")
    None => ()
  }
  let terminal_then = [@lib.Instruction::br(@lib.LabelIdx::new(1U))]
  let terminal_else = [local_block]
  let terminal_loop_body = [
    local_block,
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      terminal_then,
      Some(terminal_else),
    ),
  ]
  match
    dae_terminal_if_no_escape_carrier_evidence(terminal_loop_body, 1, None) {
    Some(evidence) => {
      assert_eq(evidence.condition_prefix.branch.start, 0)
      assert_eq(evidence.condition_prefix.branch.end, 1)
      assert_eq(evidence.condition_prefix.instrs, [local_block])
      assert_eq(evidence.then_body, terminal_then)
      match evidence.else_body {
        Some(else_evidence) => {
          assert_eq(else_evidence.branch.start, 0)
          assert_eq(else_evidence.branch.end, 1)
          assert_eq(else_evidence.instrs, terminal_else)
        }
        None => fail("terminal if carrier should copy no-escape else body")
      }
    }
    None => fail("terminal if carrier should accept no-escape prefix and else")
  }
  let escaping_else_loop_body = [
    local_block,
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      terminal_then,
      Some([@lib.Instruction::br(@lib.LabelIdx::new(0U))]),
    ),
  ]
  match
    dae_terminal_if_no_escape_carrier_evidence(escaping_else_loop_body, 1, None) {
    Some(_) => fail("terminal if carrier should reject escaping else body")
    None => ()
  }
  match dae_escaping_branch_range_evidence(mixed_instrs, 1, 2, 0) {
    Some(evidence) => {
      assert_eq(evidence.start, 1)
      assert_eq(evidence.end, 2)
      assert_true(evidence.has_escaping_branch)
    }
    None => fail("top-level branch range should produce escaping evidence")
  }
  match dae_no_escaping_branch_range_evidence(mixed_instrs, 1, 2, 0) {
    Some(_) =>
      fail("top-level branch range should be rejected by no-escape evidence")
    None => ()
  }
  match dae_no_escaping_branch_suffix_evidence(mixed_instrs, 1, 0) {
    Some(_) =>
      fail("top-level branch suffix should be rejected by no-escape evidence")
    None => ()
  }
  match dae_no_escaping_branch_prefix_evidence(mixed_instrs, 3, 0) {
    Some(_) => fail("oversized prefix should be rejected by prefix evidence")
    None => ()
  }
  match dae_escaping_branch_range_evidence(mixed_instrs, -1, 1, 0) {
    Some(_) => fail("negative branch range start should be rejected")
    None => ()
  }
  match dae_escaping_branch_evidence([], -1) {
    Some(_) => fail("negative branch depth should be rejected")
    None => ()
  }
}

///|
test "dae multi result carrier chain evidence centralizes fallthrough and return slices" {
  let pair_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([], [@lib.ValType::i32(), @lib.ValType::i64()]),
    ),
  )
  let mod_ = @lib.Module::new().with_type_sec(@lib.TypeSec::new([pair_type]))
  let pair_carrier = @lib.Instruction::block(
    @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(7)),
      @lib.Instruction::i64_const(@lib.I64(9L)),
    ]),
  )
  match
    dae_multi_result_control_carrier_chain_slice(
      mod_,
      [pair_carrier],
      2,
      terminal_return=false,
      match_terminal_return=false,
      append_terminal_return=false,
    ) {
    Some(evidence) => {
      assert_true(evidence.flattened)
      assert_false(evidence.terminal_return)
      assert_eq(evidence.carrier_kind, 1)
      assert_eq(evidence.slice.start, 0)
      assert_eq(evidence.slice.end, 2)
      assert_eq(evidence.body.length(), 2)
    }
    None => fail("expected fallthrough carrier-chain slice evidence")
  }
  match
    dae_multi_result_control_carrier_chain_slice(
      mod_,
      [pair_carrier],
      2,
      terminal_return=true,
      match_terminal_return=false,
      append_terminal_return=true,
    ) {
    Some(evidence) => {
      assert_true(evidence.flattened)
      assert_true(evidence.terminal_return)
      assert_eq(evidence.carrier_kind, 1)
      assert_eq(evidence.slice.start, 0)
      assert_eq(evidence.slice.end, 2)
      assert_eq(evidence.body.length(), 3)
      match evidence.body[2] {
        @lib.Return => ()
        _ => fail("expected appended terminal return")
      }
    }
    None => fail("expected terminal carrier-chain slice evidence")
  }
  match
    dae_multi_result_control_carrier_chain_slice(
      mod_,
      [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i64_const(@lib.I64(2L)),
        @lib.Instruction::return_(),
      ],
      2,
      terminal_return=true,
      match_terminal_return=true,
      append_terminal_return=false,
    ) {
    Some(evidence) => {
      assert_false(evidence.flattened)
      assert_true(evidence.terminal_return)
      assert_eq(evidence.carrier_kind, 0)
      assert_eq(evidence.slice.start, 0)
      assert_eq(evidence.slice.end, 2)
    }
    None => fail("expected direct terminal-return slice evidence")
  }
}

///|
test "dae stack slice localization evidence carries transition escape and repair facts" {
  let mod_ = @lib.Module::new()
  let body = [@lib.Instruction::i32_const(@lib.I32(7))]
  let request = dae_stack_slice_localization_request(
    body,
    0,
    body.length(),
    0,
    1,
    0,
    fn(instr) { !dae_instr_has_branch(instr) },
    false,
  )
  match dae_stack_slice_localization_evidence_from_request(mod_, [], request) {
    Some(evidence) => {
      assert_eq(evidence.transition.simulation.start, 0)
      assert_eq(evidence.transition.simulation.end, body.length())
      assert_eq(evidence.transition.simulation.final_stack_values, 1)
      assert_eq(evidence.transition.expected_final_stack_values, 1)
      assert_eq(evidence.no_escape_branch.start, 0)
      assert_eq(evidence.no_escape_branch.end, body.length())
      assert_eq(evidence.no_escape_branch.depth, 0)
      assert_false(evidence.no_escape_branch.has_escaping_branch)
      assert_eq(evidence.copied_slice.branch.start, 0)
      assert_eq(evidence.copied_slice.branch.end, body.length())
      assert_eq(evidence.copied_slice.instrs.length(), body.length())
      assert_eq(evidence.disposition.start, 0)
      assert_eq(evidence.disposition.end, body.length())
      assert_eq(evidence.removal_plan.start, 0)
      assert_eq(evidence.removal_plan.end, body.length())
      assert_true(
        dae_operand_removal_plan_drops_without_repair(evidence.removal_plan),
      )
    }
    None => fail("expected request-backed localization evidence")
  }
  let wrong_final_request = dae_stack_slice_localization_request(
    body,
    0,
    body.length(),
    0,
    0,
    0,
    fn(instr) { !dae_instr_has_branch(instr) },
    false,
  )
  match
    dae_stack_slice_localization_evidence_from_request(
      mod_,
      [],
      wrong_final_request,
    ) {
    Some(_) => fail("localization evidence should reject wrong final stack")
    None => ()
  }
  let escaping_request = dae_stack_slice_localization_request(
    [@lib.Instruction::br(@lib.LabelIdx::new(0U))],
    0,
    1,
    0,
    0,
    0,
    fn(_) { true },
    false,
  )
  match
    dae_stack_slice_localization_evidence_from_request(
      mod_,
      [],
      escaping_request,
    ) {
    Some(_) => fail("localization evidence should reject escaping branches")
    None => ()
  }
  let parametric_request = dae_stack_slice_localization_request(
    [@lib.Instruction::i32_add(), @lib.Instruction::drop()],
    0,
    2,
    2,
    0,
    0,
    dae_parametric_typeidx_stack_slice_instr_allowed,
    true,
  )
  match
    dae_stack_slice_localization_evidence_from_request(
      mod_,
      [],
      parametric_request,
    ) {
    Some(evidence) => {
      assert_eq(evidence.transition.simulation.initial_stack_values, 2)
      assert_eq(evidence.transition.simulation.final_stack_values, 0)
      assert_true(evidence.removal_plan.keep_operand)
    }
    None => fail("expected parametric request-backed localization evidence")
  }
  let select_policy = dae_select_condition_localization_policy()
  match
    dae_stack_slice_localization_evidence_from_policy(
      mod_,
      [],
      body,
      0,
      body.length(),
      select_policy,
    ) {
    Some(evidence) => {
      assert_eq(evidence.transition.simulation.initial_stack_values, 0)
      assert_eq(evidence.transition.simulation.final_stack_values, 1)
      assert_eq(evidence.no_escape_branch.depth, 0)
      assert_true(evidence.removal_plan.keep_operand)
    }
    None => fail("expected select policy localization evidence")
  }
  assert_true(
    dae_stack_slice_localization_policy_accepts(
      mod_,
      [],
      body,
      0,
      body.length(),
      select_policy,
    ),
  )
  let parametric_policy = dae_parametric_typeidx_prefix_localization_policy(2)
  match
    dae_stack_slice_localization_evidence_from_policy(
      mod_,
      [],
      [@lib.Instruction::i32_add(), @lib.Instruction::drop()],
      0,
      2,
      parametric_policy,
    ) {
    Some(evidence) => {
      assert_eq(evidence.transition.simulation.initial_stack_values, 2)
      assert_eq(evidence.transition.simulation.final_stack_values, 0)
      assert_true(evidence.removal_plan.keep_operand)
    }
    None => fail("expected parametric policy localization evidence")
  }
  assert_true(
    dae_stack_slice_localization_policy_accepts(
      mod_,
      [],
      [@lib.Instruction::i32_add(), @lib.Instruction::drop()],
      0,
      2,
      parametric_policy,
    ),
  )
}

///|
test "dae stack slice simulation centralizes condition and typeidx scans" {
  let mod_ = @lib.Module::new()
  let body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_add(),
  ]
  let evidence = match
    dae_stack_slice_simulation_evidence(mod_, [], body, 0, body.length(), 0, fn(
      instr,
    ) {
      !dae_instr_has_branch(instr)
    }) {
    Some(evidence) => evidence
    None => fail("expected reusable stack-slice simulation evidence")
  }
  assert_eq(evidence.start, 0)
  assert_eq(evidence.end, body.length())
  assert_eq(evidence.initial_stack_values, 0)
  assert_eq(evidence.final_stack_values, 1)
  assert_eq(evidence.max_stack_values, 2)
  assert_false(evidence.saw_effect_or_branch)
  let transition = match
    dae_stack_slice_transition_evidence(
      mod_,
      [],
      body,
      0,
      body.length(),
      0,
      1,
      fn(instr) { !dae_instr_has_branch(instr) },
    ) {
    Some(evidence) => evidence
    None => fail("expected reusable stack-slice transition evidence")
  }
  assert_eq(transition.expected_final_stack_values, 1)
  assert_eq(transition.simulation.final_stack_values, 1)
  match
    dae_stack_slice_transition_evidence(
      mod_,
      [],
      body,
      0,
      body.length(),
      0,
      0,
      fn(instr) { !dae_instr_has_branch(instr) },
    ) {
    Some(_) => fail("mismatched final stack count should be rejected")
    None => ()
  }
  assert_true(dae_select_condition_slice_is_stack_local(mod_, body, 0, 3, []))

  match
    dae_stack_slice_simulation_evidence(
      mod_,
      [],
      [@lib.Instruction::i32_add()],
      0,
      1,
      1,
      fn(_) { true },
    ) {
    Some(_) => fail("underfull stack slices should be rejected")
    None => ()
  }
  match
    dae_stack_slice_simulation_evidence(
      mod_,
      [],
      [@lib.Instruction::local_set(@lib.LocalIdx::new(0U))],
      0,
      1,
      1,
      fn(_) { false },
    ) {
    Some(_) => fail("policy-rejected instructions should be rejected")
    None => ()
  }

  assert_true(
    dae_parametric_typeidx_prefix_consumes_params_stack_safe(
      mod_,
      [],
      [@lib.Instruction::i32_add(), @lib.Instruction::drop()],
      2,
      2,
    ),
  )

  let dropped_pairs = [
    @lib.Instruction::i32_const(@lib.I32(99)),
    @lib.Instruction::drop(),
    @lib.Instruction::i64_const(@lib.I64(11L)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ]
  match
    dae_dropped_operand_pair_skip_evidence(
      dropped_pairs,
      0,
      dropped_pairs.length(),
    ) {
    Some(evidence) => {
      assert_eq(evidence.start, 0)
      assert_eq(evidence.end, dropped_pairs.length())
      assert_eq(evidence.next, 4)
      assert_eq(evidence.skipped_pairs, 2)
    }
    None => fail("expected dropped operand-pair skip evidence")
  }
  match dae_dropped_operand_pair_skip_evidence(dropped_pairs, 4, 2) {
    Some(_) => fail("invalid dropped operand-pair ranges should be rejected")
    None => ()
  }
}

///|
test "dae callsite value evidence centralizes cursor and operand dispositions" {
  let mod_ = @lib.Module::new()
  let body = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
  ]
  match dae_callsite_value_slice_evidence(body, 2, 2, 0, mod_, []) {
    Some(evidence) => {
      assert_eq(evidence.call_idx, 2)
      assert_eq(evidence.arg_count, 2)
      assert_eq(evidence.cursor, 0)
      assert_eq(evidence.entry_stack_values, 0)
      assert_true(
        dae_callsite_value_slice_evidence_is_consistent(evidence, 2, 2, 0),
      )
      assert_eq(evidence.slices.length(), 2)
      assert_eq(evidence.slices[0].start, 0)
      assert_eq(evidence.slices[0].end, 1)
      assert_eq(evidence.slices[1].start, 1)
      assert_eq(evidence.slices[1].end, 2)
      assert_true(
        dae_operand_disposition_drops_without_repair(
          evidence.slices[0].disposition,
        ),
      )
      assert_true(
        dae_operand_disposition_drops_without_repair(
          evidence.slices[1].disposition,
        ),
      )
      assert_true(dae_value_slice_disposition_is_consistent(evidence.slices[0]))
      assert_true(dae_value_slice_disposition_is_consistent(evidence.slices[1]))
    }
    None => fail("expected reusable callsite value evidence")
  }
}

///|
test "dae callsite single instruction actual evidence centralizes slice lookup" {
  let mod_ = @lib.Module::new()
  let body = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
  ]
  let evidence = match
    dae_callsite_value_slice_evidence(body, 2, 2, 0, mod_, []) {
    Some(evidence) => evidence
    None => fail("expected reusable callsite value evidence")
  }
  match dae_callsite_single_instruction_actual(evidence, 0, body) {
    Some(actual) => {
      assert_eq(actual.param_idx, 0)
      assert_eq(actual.actual_idx, 0)
      assert_eq(actual.instr, body[0])
      assert_true(
        dae_callsite_single_instruction_actual_is_consistent(actual, 0, body),
      )
    }
    None => fail("expected first single-instruction actual evidence")
  }
  match dae_callsite_single_instruction_actual(evidence, 1, body) {
    Some(actual) => {
      assert_eq(actual.param_idx, 1)
      assert_eq(actual.actual_idx, 1)
      assert_eq(actual.instr, body[1])
    }
    None => fail("expected second single-instruction actual evidence")
  }
  match dae_callsite_single_instruction_actual(evidence, 2, body) {
    Some(_) => fail("expected out-of-range actual lookup to reject")
    None => ()
  }
}

///|
test "dae value slices carry reusable operand disposition" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ]
  let disposition = match dae_operand_disposition_from_range(body, 0, 2) {
    Some(disposition) => disposition
    None => fail("expected value-slice operand disposition")
  }
  let slice = dae_value_slice_from_operand_disposition(disposition)
  assert_eq(slice.start, 0)
  assert_eq(slice.end, 2)
  assert_false(slice.pure)
  assert_true(slice.has_effect_or_branch)
  assert_eq(slice.disposition.start, disposition.start)
  assert_eq(slice.disposition.end, disposition.end)
  assert_eq(
    slice.disposition.preserve_effects_on_removal,
    disposition.preserve_effects_on_removal,
  )
  let computed_body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_add(),
  ]
  let computed_slice = dae_value_slice_from_range(computed_body, 0, 3)
  assert_true(computed_slice.pure)
  assert_false(computed_slice.disposition.droppable_without_repair)
  assert_true(computed_slice.disposition.preserve_effects_on_removal)
}

///|
test "dae callsite value slice exposes reusable single-instruction evidence" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ]
  let computed = dae_value_slice_from_range(body, 0, 3)
  let single = dae_value_slice_from_range(body, 3, 4)
  match dae_value_slice_single_instruction_index(computed) {
    Some(_) => fail("computed range is not a single actual instruction")
    None => ()
  }
  match dae_value_slice_single_instruction_index(single) {
    Some(idx) => assert_eq(idx, 3)
    None => fail("expected single-instruction actual evidence")
  }
}

///|
test "dae control entry stack evidence centralizes nested block inputs" {
  let typeidx_block_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i64()], [
        @lib.ValType::f32(),
      ]),
    ),
  )
  let single_result_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i64()])),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([typeidx_block_type, single_result_type]),
  )
  let typeidx_signature = match
    dae_control_block_type_signature_evidence(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      mod_,
    ) {
    Some(evidence) => evidence
    None => fail("expected typeidx block signature evidence")
  }
  assert_eq(typeidx_signature.input_count, 2)
  assert_eq(typeidx_signature.output_count, 1)
  assert_eq(typeidx_signature.params.length(), 2)
  assert_eq(typeidx_signature.results.length(), 1)
  match
    dae_control_block_type_stack_shape_evidence(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      mod_.type_sec,
      2,
      1,
    ) {
    Some(shape) => {
      assert_eq(shape.input_count, 2)
      assert_eq(shape.output_count, 1)
    }
    None => fail("expected shared typeidx stack-shape evidence")
  }
  assert_true(
    dae_control_block_type_exact_signature_accepts(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      mod_.type_sec,
      [@lib.ValType::i32(), @lib.ValType::i64()],
      [@lib.ValType::f32()],
    ),
  )
  assert_false(
    dae_control_block_type_exact_signature_accepts(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      mod_.type_sec,
      [@lib.ValType::i64(), @lib.ValType::i32()],
      [@lib.ValType::f32()],
    ),
  )
  match typeidx_signature.type_idx {
    Some(type_idx) => assert_eq(type_idx, @lib.TypeIdx::new(0U))
    None => fail("expected typeidx signature to retain control typeidx")
  }
  match
    dae_control_single_result_block_type_evidence(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      mod_,
    ) {
    Some(_) =>
      fail("typeidx block with params is not a stack single-result producer")
    None => ()
  }
  let typeidx_single_result = match
    dae_control_single_result_block_type_evidence(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      mod_,
    ) {
    Some(evidence) => evidence
    None => fail("expected zero-param typeidx single-result evidence")
  }
  assert_eq(typeidx_single_result.input_count, 0)
  assert_eq(typeidx_single_result.output_count, 1)
  match typeidx_single_result.type_idx {
    Some(type_idx) => assert_eq(type_idx, @lib.TypeIdx::new(1U))
    None => fail("expected typeidx single-result evidence to retain typeidx")
  }

  let typeidx_evidence = match
    dae_control_entry_stack_evidence(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      mod_,
    ) {
    Some(evidence) => evidence
    None => fail("expected typeidx block stack evidence")
  }
  assert_eq(typeidx_evidence.entry_stack_values, 2)
  assert_eq(typeidx_evidence.result_stack_values, 1)

  let valtype_single_result = match
    dae_control_single_result_block_type_evidence(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      mod_,
    ) {
    Some(evidence) => evidence
    None => fail("expected valtype single-result block evidence")
  }
  assert_eq(valtype_single_result.input_count, 0)
  assert_eq(valtype_single_result.output_count, 1)

  let valtype_evidence = match
    dae_control_entry_stack_evidence(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      mod_,
    ) {
    Some(evidence) => evidence
    None => fail("expected valtype block stack evidence")
  }
  assert_eq(valtype_evidence.entry_stack_values, 0)
  assert_eq(valtype_evidence.result_stack_values, 1)

  match
    dae_control_single_result_block_type_evidence(@lib.BlockType::void_(), mod_) {
    Some(_) => fail("void block type is not a stack single-result producer")
    None => ()
  }

  match
    dae_control_entry_stack_evidence(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(9U)),
      mod_,
    ) {
    Some(_) => fail("out-of-range typeidx should not produce stack evidence")
    None => ()
  }

  match
    dae_control_entry_stack_values(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      mod_,
    ) {
    Some(entry_stack_values) => assert_eq(entry_stack_values, 2)
    None => fail("expected shared control entry stack value")
  }
  match
    dae_control_entry_stack_values(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(9U)),
      mod_,
    ) {
    Some(_) => fail("out-of-range helper lookup should reject")
    None => ()
  }

  let block_instr = @lib.Instruction::block(
    @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
    @lib.Expr::new([]),
  )
  match dae_nested_control_entry_evidence(block_instr, mod_) {
    Some(evidence) => {
      assert_eq(evidence.entry_stack_values, 2)
      assert_eq(evidence.result_stack_values, 1)
      assert_eq(evidence.control_kind, 0)
      assert_false(evidence.has_else_arm)
    }
    None => fail("expected reusable nested block entry evidence")
  }

  let if_instr = @lib.Instruction::if_(
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
    Some([]),
  )
  match dae_nested_control_entry_evidence(if_instr, mod_) {
    Some(evidence) => {
      assert_eq(evidence.entry_stack_values, 0)
      assert_eq(evidence.result_stack_values, 1)
      assert_eq(evidence.control_kind, 3)
      assert_true(evidence.has_else_arm)
    }
    None => fail("expected reusable nested if entry evidence")
  }
  match dae_nested_control_children_evidence(if_instr, mod_) {
    Some(evidence) => {
      assert_eq(evidence.entry_stack_values, 0)
      assert_eq(evidence.result_stack_values, 1)
      assert_eq(evidence.control_kind, 3)
      assert_true(evidence.has_else_arm)
      assert_eq(evidence.primary_body.length(), 0)
      match evidence.secondary_body {
        Some(body) => assert_eq(body.length(), 0)
        None => fail("expected else body in nested-control child evidence")
      }
    }
    None => fail("expected reusable nested if child evidence")
  }
  match dae_nested_control_children_evidence(block_instr, mod_) {
    Some(evidence) => {
      assert_eq(evidence.entry_stack_values, 2)
      assert_eq(evidence.result_stack_values, 1)
      assert_eq(evidence.control_kind, 0)
      assert_false(evidence.has_else_arm)
      assert_eq(evidence.primary_body.length(), 0)
      match evidence.secondary_body {
        Some(_) => fail("plain block should not expose secondary body")
        None => ()
      }
    }
    None => fail("expected reusable nested block child evidence")
  }

  let try_instr = @lib.Instruction::try_table(
    @lib.BlockType::void_(),
    [@lib.Catch::all(@lib.LabelIdx::new(0U))],
    @lib.Expr::new([@lib.Instruction::nop()]),
  )
  match dae_nested_control_children_evidence(try_instr, mod_) {
    Some(evidence) => {
      match
        dae_rebuild_nested_control_children(
          try_instr,
          evidence,
          [@lib.Instruction::i32_const(@lib.I32(3))],
          None,
        ) {
        Some(rebuilt) =>
          assert_eq(
            rebuilt,
            @lib.Instruction::try_table(
              @lib.BlockType::void_(),
              [@lib.Catch::all(@lib.LabelIdx::new(0U))],
              @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(3))]),
            ),
          )
        None => fail("expected reusable nested try_table rebuild evidence")
      }
      match
        dae_rebuild_nested_control_children(
          try_instr,
          evidence,
          [@lib.Instruction::nop()],
          Some([]),
        ) {
        Some(_) => fail("non-if nested rebuild should reject secondary body")
        None => ()
      }
    }
    None => fail("expected reusable nested try_table child evidence")
  }
  match dae_nested_control_children_evidence(if_instr, mod_) {
    Some(evidence) =>
      match
        dae_rebuild_nested_control_children(
          if_instr,
          evidence,
          [@lib.Instruction::nop()],
          None,
        ) {
        Some(_) => fail("if-with-else rebuild should preserve secondary body")
        None => ()
      }
    None => fail("expected reusable nested if child evidence")
  }

  match dae_nested_control_entry_evidence(@lib.Instruction::nop(), mod_) {
    Some(_) => fail("non-control instructions must not expose entry evidence")
    None => ()
  }
}

///|
test "dae callsite value slices expose reusable repair disposition" {
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0UL))
  let body = [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ]
  let (slices, cursor) = match
    dae_collect_callsite_value_slices(body, 3, 2, 0, @lib.Module::new(), []) {
    Some(result) => result
    None => fail("expected callsite value slices")
  }
  assert_eq(cursor, 0)
  assert_eq(slices[0].start, 0)
  assert_eq(slices[0].end, 2)
  assert_false(slices[0].pure)
  assert_true(slices[0].disposition.preserve_effects_on_removal)
  assert_false(slices[0].has_effect_or_branch)
  assert_eq(slices[1].start, 2)
  assert_eq(slices[1].end, 3)
  assert_true(slices[1].pure)
  assert_false(slices[1].disposition.preserve_effects_on_removal)
  let repaired : Array[@lib.Instruction] = []
  dae_append_operand_with_removal_plan(
    repaired,
    body,
    dae_operand_removal_plan(slices[0].disposition, false),
  )
  assert_eq(repaired, [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::drop(),
  ])
}

///|
test "dae callsite removal plan centralizes keep replay and drop repair" {
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0UL))
  let body = [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ]
  let evidence = match
    dae_callsite_value_slice_evidence(body, 3, 2, 0, @lib.Module::new(), []) {
    Some(evidence) => evidence
    None => fail("expected callsite value-slice evidence")
  }
  let effectful_removed = match
    dae_callsite_operand_removal_plan(evidence, 0, true) {
    Some(plan) => plan
    None => fail("expected effectful removed-operand repair plan")
  }
  assert_false(effectful_removed.keep_operand)
  assert_true(effectful_removed.replay_operand)
  assert_true(effectful_removed.append_drop)
  assert_false(effectful_removed.rejects_direct_removal)
  let kept = match dae_callsite_operand_removal_plan(evidence, 1, false) {
    Some(plan) => plan
    None => fail("expected kept-operand plan")
  }
  assert_true(kept.keep_operand)
  assert_true(kept.replay_operand)
  assert_false(kept.append_drop)
  let pure_removed = match
    dae_callsite_operand_removal_plan(evidence, 1, true) {
    Some(plan) => plan
    None => fail("expected pure removed-operand plan")
  }
  assert_false(pure_removed.keep_operand)
  assert_false(pure_removed.replay_operand)
  assert_false(pure_removed.append_drop)
  match dae_callsite_operand_removal_plan(evidence, 2, true) {
    Some(_) => fail("out-of-range param should not produce a repair plan")
    None => ()
  }
}

///|
test "dae control block input evidence centralizes zero-input control checks" {
  let ref_type = @lib.TypeIdx::new(0U)
  let zero_multi_type = @lib.TypeIdx::new(1U)
  let param_type = @lib.TypeIdx::new(2U)
  let concrete_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(ref_type), exact=true),
  )
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(@lib.SubType::new(false, [], @lib.CompType::struct_([]))),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([], [@lib.ValType::i32(), concrete_ref]),
      ),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i32()], [concrete_ref]),
      ),
    ),
  ])
  match
    dae_control_block_type_zero_input_evidence(
      @lib.BlockType::type_idx(zero_multi_type),
      Some(type_sec),
    ) {
    Some(evidence) => {
      assert_eq(evidence.input_count, 0)
      assert_eq(evidence.output_count, 2)
      assert_eq(evidence.results[1], concrete_ref)
    }
    None => fail("expected zero-input typeidx control evidence")
  }
  match
    dae_control_block_type_zero_input_output_count_evidence(
      @lib.BlockType::type_idx(zero_multi_type),
      Some(type_sec),
      2,
    ) {
    Some(evidence) => {
      assert_eq(evidence.input_count, 0)
      assert_eq(evidence.output_count, 2)
      assert_eq(evidence.results[1], concrete_ref)
    }
    None => fail("expected zero-input/output-count typeidx evidence")
  }
  match
    dae_control_block_type_zero_input_evidence(
      @lib.BlockType::val_type(concrete_ref),
      Some(type_sec),
    ) {
    Some(evidence) => {
      assert_eq(evidence.input_count, 0)
      assert_eq(evidence.output_count, 1)
      assert_eq(evidence.results[0], concrete_ref)
    }
    None => fail("expected valtype zero-input control evidence")
  }
  match
    dae_control_block_type_zero_input_evidence(
      @lib.BlockType::type_idx(param_type),
      Some(type_sec),
    ) {
    Some(_) => fail("parametric typeidx control must not be zero-input")
    None => ()
  }
  match
    dae_control_block_type_zero_input_output_count_evidence(
      @lib.BlockType::type_idx(zero_multi_type),
      Some(type_sec),
      1,
    ) {
    Some(_) => fail("wrong output-count control must not produce evidence")
    None => ()
  }
  match
    dae_control_block_type_zero_input_evidence(
      @lib.BlockType::type_idx(zero_multi_type),
      None,
    ) {
    Some(_) =>
      fail("typeidx control without type section must not produce evidence")
    None => ()
  }
}

///|
test "dae control block GC result evidence centralizes single and trailing slots" {
  let ref_type = @lib.TypeIdx::new(0U)
  let pair_type = @lib.TypeIdx::new(1U)
  let nullable_type = @lib.TypeIdx::new(2U)
  let concrete_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(ref_type), exact=true),
  )
  let nullable_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(ref_type)),
  )
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(@lib.SubType::new(false, [], @lib.CompType::struct_([]))),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i32()], [
          @lib.ValType::i64(),
          concrete_ref,
        ]),
      ),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([], [nullable_ref])),
    ),
  ])
  match
    dae_control_block_type_non_null_concrete_gc_result_evidence(
      @lib.BlockType::type_idx(pair_type),
      Some(type_sec),
      1,
    ) {
    Some(evidence) => {
      assert_eq(evidence.result_index, 1)
      assert_eq(evidence.signature.input_count, 1)
      assert_eq(evidence.signature.output_count, 2)
      assert_eq(evidence.candidate, concrete_ref)
    }
    None => fail("expected trailing concrete GC result evidence")
  }
  match
    dae_control_block_type_non_null_concrete_gc_result_evidence(
      @lib.BlockType::type_idx(pair_type),
      Some(type_sec),
      0,
    ) {
    Some(_) => fail("non-GC leading result must not produce GC evidence")
    None => ()
  }
  match
    dae_control_block_type_non_null_concrete_gc_result_evidence(
      @lib.BlockType::type_idx(pair_type),
      Some(type_sec),
      2,
    ) {
    Some(_) => fail("out-of-range result slot must not produce evidence")
    None => ()
  }
  match
    dae_control_block_type_single_non_null_concrete_gc_result_evidence(
      @lib.BlockType::val_type(concrete_ref),
      Some(type_sec),
    ) {
    Some(evidence) => {
      assert_eq(evidence.result_index, 0)
      assert_eq(evidence.signature.output_count, 1)
      assert_eq(evidence.candidate, concrete_ref)
    }
    None => fail("expected single valtype concrete GC result evidence")
  }
  match
    dae_control_block_type_single_non_null_concrete_gc_result_evidence(
      @lib.BlockType::type_idx(pair_type),
      Some(type_sec),
    ) {
    Some(_) => fail("multi-result typeidx is not single-result evidence")
    None => ()
  }
  match
    dae_control_block_type_last_non_null_concrete_gc_result_evidence(
      @lib.BlockType::type_idx(pair_type),
      Some(type_sec),
    ) {
    Some(evidence) => {
      assert_eq(evidence.result_index, 1)
      assert_eq(evidence.candidate, concrete_ref)
    }
    None => fail("expected trailing GC result evidence")
  }
  match
    dae_control_block_type_last_non_null_concrete_gc_result_evidence(
      @lib.BlockType::type_idx(nullable_type),
      Some(type_sec),
    ) {
    Some(_) => fail("nullable GC result must not produce non-null evidence")
    None => ()
  }
}

///|
test "dae GC select value evidence computes reusable LUB and refined candidates" {
  let base_type = @lib.TypeIdx::new(0U)
  let mid_type = @lib.TypeIdx::new(1U)
  let leaf1_type = @lib.TypeIdx::new(2U)
  let leaf2_type = @lib.TypeIdx::new(3U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let expected_mid_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(mid_type)),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [mid_type], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [mid_type], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let body = [
    @lib.Instruction::struct_new_default(leaf1_type),
    @lib.Instruction::struct_new_default(leaf2_type),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::select(types=Some([base_ref])),
  ]
  match
    dae_gc_select_value_slice_evidence(
      mod_,
      [],
      None,
      body,
      0,
      1,
      2,
      3,
      base_ref,
      require_refined=true,
    ) {
    Some(evidence) => {
      assert_eq(evidence.candidate, expected_mid_ref)
      assert_eq(evidence.refined_candidate, Some(expected_mid_ref))
      assert_eq(evidence.left_rewrite, None)
      assert_eq(evidence.right_rewrite, None)
    }
    None => fail("expected reusable GC select value evidence")
  }
}

///|
test "dae indirect GC result slice evidence centralizes call_ref and call_indirect operands" {
  let base_type = @lib.TypeIdx::new(0U)
  let leaf_type = @lib.TypeIdx::new(1U)
  let callee_type = @lib.TypeIdx::new(2U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let expected_leaf_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf_type)),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([@lib.ValType::i32()], [expected_leaf_ref]),
        ),
      ),
    ]),
  )
  let call_ref_body = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
    @lib.Instruction::call_ref(callee_type),
  ]
  match
    dae_indirect_call_gc_result_slice_evidence(
      mod_,
      [],
      call_ref_body,
      0,
      1,
      1,
      callee_type,
      base_ref,
    ) {
    Some(evidence) => {
      assert_eq(evidence.candidate, expected_leaf_ref)
      assert_eq(evidence.param_count, 1)
      assert_eq(evidence.stack_value_count, 1)
    }
    None => fail("expected reusable call_ref GC result evidence")
  }
  let call_indirect_body = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::call_indirect(callee_type, @lib.TableIdx::new(0U)),
  ]
  match
    dae_indirect_call_gc_result_slice_evidence(
      mod_,
      [],
      call_indirect_body,
      0,
      1,
      2,
      callee_type,
      base_ref,
    ) {
    Some(evidence) => {
      assert_eq(evidence.candidate, expected_leaf_ref)
      assert_eq(evidence.param_count, 1)
      assert_eq(evidence.stack_value_count, 2)
    }
    None => fail("expected reusable call_indirect GC result evidence")
  }
  let effectful_table_body = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::call_indirect(callee_type, @lib.TableIdx::new(0U)),
  ]
  match
    dae_indirect_call_gc_result_slice_evidence(
      mod_,
      [],
      effectful_table_body,
      0,
      1,
      2,
      callee_type,
      base_ref,
    ) {
    Some(_) =>
      fail("expected effectful call_indirect table operand to be rejected")
    None => ()
  }
}

///|
test "dae GC result slot evidence centralizes candidate refinement and rewrite" {
  let base_type = @lib.TypeIdx::new(0U)
  let leaf_type = @lib.TypeIdx::new(1U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let leaf_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf_type), exact=true),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let block_instr = @lib.Instruction::block(
    @lib.BlockType::val_type(base_ref),
    @lib.Expr::new([@lib.Instruction::struct_new_default(leaf_type)]),
  )
  match
    dae_gc_result_slot_evidence(
      mod_,
      [],
      None,
      block_instr,
      base_ref,
      require_refined=true,
    ) {
    Some(evidence) => {
      assert_eq(evidence.candidate, leaf_ref)
      assert_eq(evidence.refined_candidate, Some(leaf_ref))
      assert_eq(
        evidence.rewrite,
        Some(
          @lib.Instruction::block(
            @lib.BlockType::val_type(leaf_ref),
            @lib.Expr::new([@lib.Instruction::struct_new_default(leaf_type)]),
          ),
        ),
      )
    }
    None => fail("expected reusable GC result slot evidence")
  }
  match
    dae_gc_result_slot_evidence(
      mod_,
      [],
      None,
      @lib.Instruction::struct_new_default(leaf_type),
      leaf_ref,
      require_refined=true,
    ) {
    Some(_) => fail("expected unchanged slot evidence to be rejected")
    None => ()
  }
}

///|
test "dae direct call GC result evidence centralizes signature and refinement" {
  let base_type = @lib.TypeIdx::new(0U)
  let leaf_type = @lib.TypeIdx::new(1U)
  let callee_type = @lib.TypeIdx::new(2U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let leaf_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf_type)),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([@lib.ValType::i32()], [leaf_ref]),
        ),
      ),
    ]),
  )
  let func_type_indices = [callee_type]
  match
    dae_direct_call_gc_result_signature_evidence(
      mod_,
      func_type_indices,
      @lib.FuncIdx::new(0U),
    ) {
    Some(evidence) => {
      assert_eq(evidence.candidate, leaf_ref)
      assert_eq(evidence.refined_candidate, None)
      assert_eq(evidence.param_count, 1)
    }
    None => fail("expected direct-call GC result signature evidence")
  }
  match
    dae_direct_call_gc_result_refinement_evidence(
      mod_,
      func_type_indices,
      @lib.FuncIdx::new(0U),
      base_ref,
    ) {
    Some(evidence) => {
      assert_eq(evidence.candidate, leaf_ref)
      assert_eq(evidence.refined_candidate, Some(leaf_ref))
      assert_eq(evidence.param_count, 1)
    }
    None => fail("expected direct-call GC result refinement evidence")
  }
  let exact_old_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf_type)),
  )
  match
    dae_direct_call_gc_result_refinement_evidence(
      mod_,
      func_type_indices,
      @lib.FuncIdx::new(0U),
      exact_old_ref,
    ) {
    Some(_) =>
      fail("expected unchanged direct-call result evidence to be rejected")
    None => ()
  }
}

///|
test "dae GC select actual evidence centralizes nullable refinement and rewrites" {
  let base_type = @lib.TypeIdx::new(0U)
  let leaf_type = @lib.TypeIdx::new(1U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let expected_leaf_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(leaf_type), exact=true),
  )
  let expected_leaf_rt = @lib.RefType::new(
    true,
    @lib.HeapType::new(leaf_type),
    exact=true,
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::new(false, [], @lib.CompType::struct_([])),
      ),
      @lib.RecType::new(
        @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
      ),
    ]),
  )
  let body = [
    @lib.Instruction::ref_null(@lib.HeapType::new(base_type)),
    @lib.Instruction::struct_new_default(leaf_type),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::select(types=Some([base_ref])),
  ]
  match
    dae_gc_select_actual_value_evidence(
      mod_,
      [],
      body,
      0,
      1,
      2,
      3,
      base_ref,
      rewrite_type=Some(expected_leaf_ref),
    ) {
    Some(evidence) => {
      assert_eq(evidence.candidate, expected_leaf_ref)
      assert_eq(evidence.refined_candidate, Some(expected_leaf_ref))
      assert_eq(
        evidence.left_rewrite,
        Some(@lib.Instruction::ref_null_type(expected_leaf_rt)),
      )
      assert_eq(evidence.right_rewrite, None)
    }
    None => fail("expected reusable GC select actual evidence")
  }
}

///|
test "dae original call summary counts repeated undropped callees once per caller" {
  let mod_ = dae_wbtest_call_summary_fixture()
  let summary = dae_collect_original_boundary_snapshot(mod_).call_summary
  assert_eq(summary.call_counts, [0, 2, 2])
  assert_eq(summary.prior_call_counts, [0, 1, 2])
  assert_eq(summary.self_call_counts, [0, 1, 0])
  assert_eq(summary.nonself_undropped_call_counts, [0, 1, 1])
  assert_eq(summary.prior_undropped_call_counts, [0, 1, 1])
  assert_eq(summary.active_nonself_call_counts, [0, 1, 2])
}

///|
test "dae selected dropped-result fallback skips covered entries" {
  let fallback = dae_selected_dropped_result_fallback_neighborhood_defs()
  assert_false(fallback.contains(3799))
  assert_false(fallback.contains(503))
  assert_false(fallback.contains(298))
  assert_false(fallback.contains(299))
  assert_false(fallback.contains(459))
  assert_false(fallback.contains(472))
  assert_false(fallback.contains(476))
  assert_false(fallback.contains(3566))
  assert_false(fallback.contains(3732))
  assert_false(fallback.contains(3814))
  assert_false(fallback.contains(4232))
  assert_false(fallback.contains(4241))
  assert_false(fallback.contains(4242))
}

///|
test "dae large dropped-result bucket order interleaves fallback neighborhood before low tail" {
  let selected = Array::make(5000, false)
  selected[1] = true
  selected[2] = true
  selected[427] = true
  selected[459] = true
  selected[472] = true
  selected[476] = true
  selected[4644] = true
  selected[4645] = true
  selected[4646] = true
  selected[4647] = true
  selected[4648] = true
  assert_eq(
    dae_collect_bucketed_large_dropped_result_attempts(selected, 5000, 8),
    [4648, 4647, 4646, 4645, 1, 2],
  )
}

///|
test "dae raw cleanup preserves nops and strips selected dropped pure leaves after any DAE touch" {
  let v128_zero = @lib.Instruction::v128_const(
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
  )
  let v128_ones = @lib.Instruction::v128_const(
    b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff',
    b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff',
  )
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0UL))
  let pure_typeidx_block_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let param_typeidx_block_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let pure_void_typeidx_block_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let param_void_typeidx_block_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
  )
  let shuffle_low_lanes = @lib.Instruction::i8x16_shuffle(
    @lib.LaneIdx::new(b'\x00'),
    @lib.LaneIdx::new(b'\x01'),
    @lib.LaneIdx::new(b'\x02'),
    @lib.LaneIdx::new(b'\x03'),
    @lib.LaneIdx::new(b'\x04'),
    @lib.LaneIdx::new(b'\x05'),
    @lib.LaneIdx::new(b'\x06'),
    @lib.LaneIdx::new(b'\x07'),
    @lib.LaneIdx::new(b'\x08'),
    @lib.LaneIdx::new(b'\x09'),
    @lib.LaneIdx::new(b'\x0a'),
    @lib.LaneIdx::new(b'\x0b'),
    @lib.LaneIdx::new(b'\x0c'),
    @lib.LaneIdx::new(b'\x0d'),
    @lib.LaneIdx::new(b'\x0e'),
    @lib.LaneIdx::new(b'\x0f'),
  )
  let noisy_body = [
    @lib.Instruction::nop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::drop(),
    @lib.Instruction::i64_const(@lib.I64(9L)),
    @lib.Instruction::drop(),
    @lib.Instruction::f32_const(@lib.F32(1.5)),
    @lib.Instruction::drop(),
    @lib.Instruction::f64_const(@lib.F64(2.25)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::i8x16_splat(),
    @lib.Instruction::drop(),
    @lib.Instruction::f64_const(@lib.F64(2.5)),
    @lib.Instruction::f64x2_splat(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32x4_extract_lane(@lib.LaneIdx::new(b'\x00')),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::f64x2_extract_lane(@lib.LaneIdx::new(b'\x00')),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::i8x16_replace_lane(@lib.LaneIdx::new(b'\x00')),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::f64_const(@lib.F64(3.5)),
    @lib.Instruction::f64x2_replace_lane(@lib.LaneIdx::new(b'\x00')),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32_const(@lib.I32(3)),
    @lib.Instruction::i8x16_shl(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::i32x4_shr_u(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i16x8_extend_low_i8x16s(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32x4_extadd_pairwise_i16x8u(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::i8x16_narrow_i16x8s(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::i16x8_narrow_i32x4u(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::i16x8_extmul_low_i8x16s(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::i32x4_extmul_high_i16x8u(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::i64x2_extmul_low_i32x4u(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::i32x4_dot_i16x8s(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::f32x4_demote_f64x2_zero(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::f64x2_promote_low_f32x4(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32x4_trunc_sat_f32x4s(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32x4_trunc_sat_f64x2u_zero(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::f32x4_convert_i32x4u(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::f64x2_convert_low_i32x4s(),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::table_size(@lib.TableIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(11)),
    @lib.Instruction::i32_const(@lib.I32(3)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::drop(),
    @lib.Instruction::f64_const(@lib.F64(16.75)),
    @lib.Instruction::f64_sqrt(),
    @lib.Instruction::drop(),
    @lib.Instruction::f32_const(@lib.F32(1.5)),
    @lib.Instruction::i32_trunc_sat_f32s(),
    @lib.Instruction::drop(),
    @lib.Instruction::f32_const(@lib.F32(1.5)),
    @lib.Instruction::i32_trunc_f32s(),
    @lib.Instruction::drop(),
    @lib.Instruction::f32_const(@lib.F32(2.5)),
    @lib.Instruction::i32_trunc_f32s(),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::drop(),
    @lib.Instruction::f64_const(@lib.F64(42.0)),
    @lib.Instruction::i64_trunc_sat_f64u(),
    @lib.Instruction::drop(),
    @lib.Instruction::f32_const(@lib.F32(9.25)),
    @lib.Instruction::f32_const(@lib.F32(2.5)),
    @lib.Instruction::f32_max(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(41)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_add(),
      ]),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
    ),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(12)),
        @lib.Instruction::i32_const(@lib.I32(30)),
        @lib.Instruction::i32_add(),
      ]),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
    ),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(3)),
    @lib.Instruction::i32_mul(),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(71)),
        @lib.Instruction::drop(),
      ]),
    ),
    @lib.Instruction::block(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(2U)),
      @lib.Expr::new([
        @lib.Instruction::i64_const(@lib.I64(72L)),
        @lib.Instruction::drop(),
      ]),
    ),
    @lib.Instruction::i32_const(@lib.I32(100)),
    @lib.Instruction::block(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(3U)),
      @lib.Expr::new([@lib.Instruction::drop()]),
    ),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(73)),
        @lib.Instruction::drop(),
      ]),
    ),
    @lib.Instruction::loop_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(2U)),
      @lib.Expr::new([
        @lib.Instruction::i64_const(@lib.I64(74L)),
        @lib.Instruction::drop(),
      ]),
    ),
    @lib.Instruction::i32_const(@lib.I32(101)),
    @lib.Instruction::loop_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(3U)),
      @lib.Expr::new([@lib.Instruction::drop()]),
    ),
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::i32_const(@lib.I32(75)), @lib.Instruction::drop()],
      None,
    ),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::if_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(2U)),
      [@lib.Instruction::i64_const(@lib.I64(76L)), @lib.Instruction::drop()],
      Some([]),
    ),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::if_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(2U)),
      [],
      Some([@lib.Instruction::i32_const(@lib.I32(77)), @lib.Instruction::drop()]),
    ),
    @lib.Instruction::i32_const(@lib.I32(102)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(3U)),
      [@lib.Instruction::drop()],
      Some([@lib.Instruction::drop()]),
    ),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::unreachable_()],
      None,
    ),
    @lib.Instruction::try_table(
      @lib.BlockType::void_(),
      [],
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(78)),
        @lib.Instruction::drop(),
      ]),
    ),
    @lib.Instruction::try_table(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(2U)),
      [],
      @lib.Expr::new([
        @lib.Instruction::i64_const(@lib.I64(79L)),
        @lib.Instruction::drop(),
      ]),
    ),
    @lib.Instruction::i32_const(@lib.I32(103)),
    @lib.Instruction::try_table(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(3U)),
      [],
      @lib.Expr::new([@lib.Instruction::drop()]),
    ),
    @lib.Instruction::try_table(
      @lib.BlockType::void_(),
      [],
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::select(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::v128_not(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::v128_any_true(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i8x16_abs(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i8x16_bitmask(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::f32x4_sqrt(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::f64x2_nearest(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::v128_and(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::i8x16_add(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::i32x4_eq(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::f32x4_div(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    shuffle_low_lanes,
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::i8x16_swizzle(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    v128_zero,
    @lib.Instruction::v128_bitselect(),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::extern_())),
    @lib.Instruction::ref_is_null(),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::extern_())),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::extern_())),
    @lib.Instruction::ref_eq(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(123)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(321)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::ref_as_non_null(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(654)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::ref_cast(
      false,
      @lib.HeapType::abs(@lib.AbsHeapType::i31()),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(656)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::ref_cast(
      false,
      @lib.HeapType::abs(@lib.AbsHeapType::eq()),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(657)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::ref_cast(
      true,
      @lib.HeapType::abs(@lib.AbsHeapType::any()),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(655)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::ref_cast(
      true,
      @lib.HeapType::abs(@lib.AbsHeapType::i31()),
    ),
    @lib.Instruction::ref_as_non_null(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(456)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::i31_get_s(),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::extern_())),
    @lib.Instruction::any_convert_extern(),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::extern_())),
    @lib.Instruction::ref_test(
      true,
      @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::eq())),
    @lib.Instruction::ref_test_desc(
      true,
      @lib.HeapType::abs(@lib.AbsHeapType::eq()),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
    @lib.Instruction::extern_convert_any(),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
    @lib.Instruction::ref_cast(true, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
    @lib.Instruction::ref_cast(true, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
    @lib.Instruction::ref_test(true, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::i31())),
    @lib.Instruction::i31_get_s(),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
    @lib.Instruction::ref_as_non_null(),
    @lib.Instruction::extern_convert_any(),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::extern_())),
    @lib.Instruction::ref_as_non_null(),
    @lib.Instruction::ref_test(
      true,
      @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::eq())),
    @lib.Instruction::ref_as_non_null(),
    @lib.Instruction::ref_test_desc(
      true,
      @lib.HeapType::abs(@lib.AbsHeapType::eq()),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::extern_())),
    @lib.Instruction::ref_as_non_null(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::extern_())),
    @lib.Instruction::ref_eq(),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::extern_())),
    @lib.Instruction::ref_as_non_null(),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::i31())),
    @lib.Instruction::ref_cast(
      false,
      @lib.HeapType::abs(@lib.AbsHeapType::i31()),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
    @lib.Instruction::ref_cast(true, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
    @lib.Instruction::ref_as_non_null(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(84)),
    @lib.Instruction::i32_const(@lib.I32(3)),
    @lib.Instruction::i32_div_s(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(84)),
    @lib.Instruction::i32_const(@lib.I32(3)),
    @lib.Instruction::i32_div_s(),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::drop(),
    @lib.Instruction::i64_const(@lib.I64(84L)),
    @lib.Instruction::i64_const(@lib.I64(3L)),
    @lib.Instruction::i64_div_s(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(84)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_div_s(),
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(99)),
    @lib.Instruction::block(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      @lib.Expr::new([]),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::i64_const(@lib.I64(-9223372036854775808L)),
    @lib.Instruction::i64_const(@lib.I64(-1L)),
    @lib.Instruction::i64_div_s(),
    @lib.Instruction::drop(),
    @lib.Instruction::f64_const(@lib.F64(4294967296.0)),
    @lib.Instruction::i32_trunc_f64u(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::i32_const(@lib.I32(5)),
    @lib.Instruction::i32_const(@lib.I32(84)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_div_s(),
    @lib.Instruction::select(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::i8x16_splat(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::i8x16_abs(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::i32x4_extract_lane(@lib.LaneIdx::new(b'\x00')),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::i8x16_replace_lane(@lib.LaneIdx::new(b'\x00')),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::i8x16_replace_lane(@lib.LaneIdx::new(b'\x00')),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::i32_const(@lib.I32(3)),
    @lib.Instruction::i8x16_shl(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::i8x16_shl(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::i16x8_extend_low_i8x16s(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::i32x4_extadd_pairwise_i16x8u(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    v128_zero,
    @lib.Instruction::i8x16_narrow_i16x8s(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::i16x8_extmul_low_i8x16s(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    v128_zero,
    @lib.Instruction::i32x4_dot_i16x8s(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::f32x4_demote_f64x2_zero(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::i32x4_trunc_sat_f32x4s(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::f64x2_convert_low_i32x4s(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    v128_zero,
    @lib.Instruction::i8x16_add(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    v128_zero,
    shuffle_low_lanes,
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    v128_zero,
    @lib.Instruction::i8x16_swizzle(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    v128_zero,
    v128_ones,
    @lib.Instruction::v128_bitselect(),
    @lib.Instruction::drop(),
    @lib.Instruction::return_(),
  ]
  let table_type = @lib.TableType::new(
    @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func())),
    @lib.Limits::i32(1U, None),
  )
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        pure_typeidx_block_type, param_typeidx_block_type, pure_void_typeidx_block_type,
        param_void_typeidx_block_type,
      ]),
    )
    .with_table_sec(@lib.TableSec::new([@lib.Table::new(table_type, None)]))
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(noisy_body)),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(noisy_body)),
      ]),
    )
  let no_touch_result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [
    false, false,
  ])
  assert_false(no_touch_result.changed)
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [
    true, false,
  ])
  assert_true(result.changed)
  assert_eq(result.primary_def, 0)
  assert_eq(result.touched, [true, false])
  let no_return_touched_result = dae_strip_module_nops_and_dropped_pure_leaf_once(
    mod_,
    [true, false],
    return_touched=false,
  )
  assert_true(no_return_touched_result.changed)
  assert_eq(no_return_touched_result.primary_def, 0)
  assert_eq(no_return_touched_result.touched, [])
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned0)) = funcs[0]
      let @lib.Func(_, @lib.Expr(cleaned1)) = funcs[1]
      let preserved_trapping = [
        @lib.Instruction::nop(),
        @lib.Instruction::i32_const(@lib.I32(100)),
        @lib.Instruction::block(
          @lib.BlockType::type_idx(@lib.TypeIdx::new(3U)),
          @lib.Expr::new([@lib.Instruction::drop()]),
        ),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::unreachable_()]),
        ),
        @lib.Instruction::i32_const(@lib.I32(101)),
        @lib.Instruction::loop_(
          @lib.BlockType::type_idx(@lib.TypeIdx::new(3U)),
          @lib.Expr::new([@lib.Instruction::drop()]),
        ),
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::unreachable_()]),
        ),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(102)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::if_(
          @lib.BlockType::type_idx(@lib.TypeIdx::new(3U)),
          [@lib.Instruction::drop()],
          Some([@lib.Instruction::drop()]),
        ),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [@lib.Instruction::unreachable_()],
          None,
        ),
        @lib.Instruction::i32_const(@lib.I32(103)),
        @lib.Instruction::try_table(
          @lib.BlockType::type_idx(@lib.TypeIdx::new(3U)),
          [],
          @lib.Expr::new([@lib.Instruction::drop()]),
        ),
        @lib.Instruction::try_table(
          @lib.BlockType::void_(),
          [],
          @lib.Expr::new([@lib.Instruction::unreachable_()]),
        ),
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::i31())),
        @lib.Instruction::i31_get_s(),
        @lib.Instruction::drop(),
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
        @lib.Instruction::ref_as_non_null(),
        @lib.Instruction::drop(),
        @lib.Instruction::ref_null(
          @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
        ),
        @lib.Instruction::ref_as_non_null(),
        @lib.Instruction::drop(),
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::eq())),
        @lib.Instruction::ref_as_non_null(),
        @lib.Instruction::drop(),
        @lib.Instruction::ref_null(
          @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
        ),
        @lib.Instruction::ref_as_non_null(),
        @lib.Instruction::drop(),
        @lib.Instruction::ref_null(
          @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
        ),
        @lib.Instruction::ref_as_non_null(),
        @lib.Instruction::drop(),
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::i31())),
        @lib.Instruction::ref_cast(
          false,
          @lib.HeapType::abs(@lib.AbsHeapType::i31()),
        ),
        @lib.Instruction::drop(),
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
        @lib.Instruction::ref_cast(
          true,
          @lib.HeapType::abs(@lib.AbsHeapType::eq()),
        ),
        @lib.Instruction::ref_as_non_null(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(84)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_div_s(),
        @lib.Instruction::drop(),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([@lib.Instruction::unreachable_()]),
        ),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(99)),
        @lib.Instruction::block(
          @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
          @lib.Expr::new([]),
        ),
        @lib.Instruction::drop(),
        @lib.Instruction::i64_const(@lib.I64(-9223372036854775808L)),
        @lib.Instruction::i64_const(@lib.I64(-1L)),
        @lib.Instruction::i64_div_s(),
        @lib.Instruction::drop(),
        @lib.Instruction::f64_const(@lib.F64(4294967296.0)),
        @lib.Instruction::i32_trunc_f64u(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::i32_const(@lib.I32(5)),
        @lib.Instruction::i32_const(@lib.I32(84)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_div_s(),
        @lib.Instruction::select(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        v128_zero,
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::i8x16_replace_lane(@lib.LaneIdx::new(b'\x00')),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        v128_zero,
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::i8x16_shl(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        v128_zero,
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::i16x8_extmul_low_i8x16s(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        v128_zero,
        v128_ones,
        @lib.Instruction::v128_bitselect(),
        @lib.Instruction::drop(),
        @lib.Instruction::return_(),
      ]
      assert_eq(cleaned0, preserved_trapping)
      assert_eq(cleaned1, preserved_trapping)
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae direct pass flattens no-normal result block before hard unreachable" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (func (result i32)
    #|     memory.size
    #|     (block (result i64)
    #|       f64.const 0
    #|       unreachable)
    #|     unreachable))
    #|
  let optimized = match
    pass_test_run_pipeline(input, ["dead-argument-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected dead-argument-elimination success, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(instrs)) = funcs[0]
      assert_eq(instrs, [
        @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
        @lib.Instruction::f64_const(@lib.F64(0.0)),
        @lib.Instruction::unreachable_(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup strips dropped unreachable debris before hard unreachable" {
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
          @lib.Instruction::drop(),
          @lib.Instruction::f64_const(@lib.F64(7.52804e-317)),
          @lib.Instruction::drop(),
          @lib.Instruction::unreachable_(),
          @lib.Instruction::drop(),
          @lib.Instruction::unreachable_(),
        ]),
      ),
    ]),
  )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [@lib.Instruction::unreachable_()])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup preserves dropped local get binary expressions" {
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_add(),
          @lib.Instruction::drop(),
          @lib.Instruction::i32_const(@lib.I32(2)),
          @lib.Instruction::i32_const(@lib.I32(3)),
          @lib.Instruction::i32_add(),
          @lib.Instruction::drop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::drop(),
        ]),
      ),
    ]),
  )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_add(),
        @lib.Instruction::drop(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup strips local and global self assignments and tees" {
  let same_global_set = [
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
  ]
  let different_global_set = [
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(1U)),
  ]
  let same_global_set_read_drop = [
    @lib.Instruction::i32_const(@lib.I32(8)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::drop(),
  ]
  let same_global_set_read_drop_cleaned = [
    @lib.Instruction::i32_const(@lib.I32(8)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
  ]
  let same_global_set_read_set = [
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
  ]
  let same_global_set_read_set_cleaned = [
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
  ]
  let different_global_set_read = [
    @lib.Instruction::i32_const(@lib.I32(10)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(1U)),
  ]
  let same_local_set = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
  ]
  let same_local_tee_drop = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ]
  let same_local_tee_pure_use_drop = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::drop(),
  ]
  let same_local_tee_set = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ]
  let same_local_tee_used = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ]
  let same_local_tee_used_cleaned = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ]
  let same_local_set_read = [
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
  ]
  let same_local_set_read_cleaned = [
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
  ]
  let same_local_tee_set_from_const = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
  ]
  let same_local_tee_set_from_const_cleaned = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
  ]
  let local_tee_drop_from_effect = [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
    @lib.Instruction::drop(),
  ]
  let local_tee_drop_from_effect_cleaned = [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
  ]
  let same_local_set_read_drop = [
    @lib.Instruction::i32_const(@lib.I32(5)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::drop(),
  ]
  let same_local_set_read_drop_cleaned = [
    @lib.Instruction::i32_const(@lib.I32(5)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
  ]
  let same_local_set_read_set = [
    @lib.Instruction::i32_const(@lib.I32(6)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
  ]
  let same_local_set_read_set_cleaned = [
    @lib.Instruction::i32_const(@lib.I32(6)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
  ]
  let effect_local_set_read_drop = [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::drop(),
  ]
  let effect_local_set_read_drop_cleaned = [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::drop(),
  ]
  let different_local_set_read = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
  ]
  let different_local_set = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ]
  let different_local_tee_drop = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ]
  let different_local_tee_drop_cleaned = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ]
  let mod_ = @lib.Module::new()
    .with_global_sec(
      @lib.GlobalSec::new([
        @lib.Global::new(
          @lib.GlobalType::new(@lib.ValType::i32(), true),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(1))]),
        ),
        @lib.Global::new(
          @lib.GlobalType::new(@lib.ValType::i32(), true),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(2))]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new(
            [
              ..same_global_set,
              ..same_local_set,
              ..same_local_tee_drop,
              ..same_local_tee_pure_use_drop,
              ..same_local_tee_set,
              ..same_local_tee_used,
              ..same_local_set_read,
              ..same_local_tee_set_from_const,
              ..local_tee_drop_from_effect,
              ..same_local_set_read_drop,
              ..same_local_set_read_set,
              ..effect_local_set_read_drop,
              ..same_global_set_read_drop,
              ..same_global_set_read_set,
              ..different_global_set_read,
              ..different_local_set_read,
              ..different_global_set,
              ..different_local_set,
              ..different_local_tee_drop,
              @lib.Instruction::return_(),
            ],
          ),
        ),
      ]),
    )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(
        cleaned,
        [
          ..same_local_tee_used_cleaned,
          ..same_local_set_read_cleaned,
          ..same_local_tee_set_from_const_cleaned,
          ..local_tee_drop_from_effect_cleaned,
          ..same_local_set_read_drop_cleaned,
          ..same_local_set_read_set_cleaned,
          ..effect_local_set_read_drop_cleaned,
          ..same_global_set_read_drop_cleaned,
          ..same_global_set_read_set_cleaned,
          ..different_global_set_read,
          ..different_local_set_read,
          ..different_global_set,
          ..different_local_set,
          ..different_local_tee_drop_cleaned,
          @lib.Instruction::return_(),
        ],
      )
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup strips live integer constant identities" {
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0UL))
  let mod_ = @lib.Module::new()
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_sub(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_or(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_xor(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_shl(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_shr_s(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_shr_u(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_rotl(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_rotr(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_mul(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(-1)),
            @lib.Instruction::i32_and(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_const(@lib.I64(0L)),
            @lib.Instruction::i64_add(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_const(@lib.I64(0L)),
            @lib.Instruction::i64_sub(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_const(@lib.I64(0L)),
            @lib.Instruction::i64_shr_u(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_const(@lib.I64(1L)),
            @lib.Instruction::i64_mul(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_const(@lib.I64(-1L)),
            @lib.Instruction::i64_and(),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_load(memarg),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_load(memarg),
            @lib.Instruction::i32_add(),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_mul(),
            @lib.Instruction::i32_const(@lib.I32(-1)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_and(),
            @lib.Instruction::i64_const(@lib.I64(0L)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_xor(),
            @lib.Instruction::i64_const(@lib.I64(1L)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_mul(),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_sub(),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_shl(),
            @lib.Instruction::return_(),
          ]),
        ),
      ]),
    )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::i32_add(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_sub(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_shl(),
        @lib.Instruction::return_(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup canonicalizes live integer zero comparisons" {
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0UL))
  let mod_ = @lib.Module::new()
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_ne(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_const(@lib.I64(0L)),
            @lib.Instruction::i64_eq(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_const(@lib.I64(0L)),
            @lib.Instruction::i64_ne(),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_ne(),
            @lib.Instruction::i64_const(@lib.I64(0L)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_eq(),
            @lib.Instruction::i64_const(@lib.I64(0L)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_ne(),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_load(memarg),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::return_(),
          ]),
        ),
      ]),
    )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i64_const(@lib.I64(0L)),
        @lib.Instruction::i64_eq(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i64_eqz(),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::i64_const(@lib.I64(0L)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i64_eq(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i64_eqz(),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::return_(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup strips double eqz from live if conditions" {
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0UL))
  let then_body = [@lib.Instruction::unreachable_()]
  let mod_ = @lib.Module::new()
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_eqz(),
            @lib.Instruction::i32_eqz(),
            @lib.Instruction::if_(@lib.BlockType::void_(), then_body, None),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_load(memarg),
            @lib.Instruction::i32_eqz(),
            @lib.Instruction::i32_eqz(),
            @lib.Instruction::if_(@lib.BlockType::void_(), then_body, None),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_eqz(),
            @lib.Instruction::i32_eqz(),
            @lib.Instruction::return_(),
          ]),
        ),
      ]),
    )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_ne(),
        @lib.Instruction::if_(@lib.BlockType::void_(), then_body, None),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_ne(),
        @lib.Instruction::if_(@lib.BlockType::void_(), then_body, None),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::return_(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup canonicalizes live integer and ref self comparisons" {
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_eq(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_ne(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_le_s(),
          @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
          @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
          @lib.Instruction::i64_gt_u(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          @lib.Instruction::ref_eq(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::i32_eq(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
          @lib.Instruction::f32_eq(),
          @lib.Instruction::return_(),
        ]),
      ),
    ]),
  )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
        @lib.Instruction::f32_eq(),
        @lib.Instruction::return_(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup folds live integer self binary operations" {
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_and(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_or(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_xor(),
          @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
          @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
          @lib.Instruction::i64_sub(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::i32_xor(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          @lib.Instruction::f32_sub(),
          @lib.Instruction::return_(),
        ]),
      ),
    ]),
  )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i64_const(@lib.I64(0L)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_xor(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::f32_sub(),
        @lib.Instruction::return_(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae dropped pure leaf cleanup evidence centralizes stack and leaf preservation" {
  let tmp = @lib.LocalIdx::new(1U)
  let stack_after_same_set = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(tmp),
    @lib.Instruction::local_get(tmp),
  ]
  let same_set_stack = dae_dropped_pure_leaf_cleanup_evidence_from_stack(
    stack_after_same_set, 2, false, false,
  )
  assert_true(same_set_stack.range_allows_cleanup)
  assert_false(same_set_stack.preserve_integer_const_debris)
  assert_true(same_set_stack.preserve_local_get_after_same_set)
  assert_false(same_set_stack.preserve_local_get_after_effect)
  assert_false(
    dae_dropped_pure_leaf_cleanup_allows_stack_truncation(same_set_stack),
  )
  let stack_integer_after_effect = [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(0)),
  ]
  let integer_stack = dae_dropped_pure_leaf_cleanup_evidence_from_stack(
    stack_integer_after_effect, 1, false, true,
  )
  assert_true(integer_stack.preserve_integer_const_debris)
  assert_false(
    dae_dropped_pure_leaf_cleanup_allows_stack_truncation(integer_stack),
  )
  let local_leaf_after_effect = dae_dropped_pure_leaf_cleanup_evidence_from_leaf(
    [@lib.Instruction::call(@lib.FuncIdx::new(0U))],
    @lib.Instruction::local_get(tmp),
    false,
    false,
  )
  assert_true(local_leaf_after_effect.preserve_local_get_after_effect)
  assert_false(
    dae_dropped_pure_leaf_cleanup_allows_leaf_drop(local_leaf_after_effect),
  )
  let plain_leaf = dae_dropped_pure_leaf_cleanup_evidence_from_leaf(
    [],
    @lib.Instruction::i32_const(@lib.I32(7)),
    false,
    false,
  )
  assert_false(plain_leaf.preserve_integer_const_debris)
  assert_false(plain_leaf.preserve_local_get_after_same_set)
  assert_false(plain_leaf.preserve_local_get_after_effect)
  assert_true(dae_dropped_pure_leaf_cleanup_allows_leaf_drop(plain_leaf))
}

///|
test "dae raw cleanup preserves dropped integer constants after live calls" {
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::drop(),
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::drop(),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::drop(),
        ]),
      ),
    ]),
  )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::drop(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup preserves dropped local-get after same-local set debris" {
  let tmp = @lib.LocalIdx::new(1U)
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::drop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_set(tmp),
          @lib.Instruction::local_get(tmp),
          @lib.Instruction::drop(),
        ]),
      ),
    ]),
  )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(tmp),
        @lib.Instruction::local_get(tmp),
        @lib.Instruction::drop(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup preserves dropped integer constants inside live if branches" {
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [@lib.Instruction::i32_const(@lib.I32(0)), @lib.Instruction::drop()],
            Some([
              @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
              @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              @lib.Instruction::br(@lib.LabelIdx::new(0U)),
            ]),
          ),
          @lib.Instruction::i32_const(@lib.I32(2)),
          @lib.Instruction::drop(),
        ]),
      ),
    ]),
  )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [@lib.Instruction::i32_const(@lib.I32(0)), @lib.Instruction::drop()],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
          ]),
        ),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup preserves nested dropped integer branch debris in effectful if" {
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [@lib.Instruction::return_()],
            Some([
              @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::i32_eq(),
              @lib.Instruction::if_(
                @lib.BlockType::void_(),
                [
                  @lib.Instruction::i32_const(@lib.I32(0)),
                  @lib.Instruction::drop(),
                ],
                Some([
                  @lib.Instruction::i32_const(@lib.I32(0)),
                  @lib.Instruction::drop(),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ]),
  )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_false(result.changed)
}

///|
test "dae func237 leading default carrier folds to local0" {
  let body = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([
                @lib.Instruction::block(
                  @lib.BlockType::void_(),
                  @lib.Expr::new([
                    @lib.Instruction::block(
                      @lib.BlockType::void_(),
                      @lib.Expr::new([
                        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                        @lib.Instruction::i32_eqz(),
                        @lib.Instruction::if_(
                          @lib.BlockType::void_(),
                          [
                            @lib.Instruction::nop(),
                            @lib.Instruction::call(@lib.FuncIdx::new(26U)),
                            @lib.Instruction::local_get(
                              @lib.LocalIdx::new(117U),
                            ),
                            @lib.Instruction::local_set(@lib.LocalIdx::new(6U)),
                            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
                          ],
                          Some([
                            @lib.Instruction::call(@lib.FuncIdx::new(28U)),
                            @lib.Instruction::local_get(
                              @lib.LocalIdx::new(118U),
                            ),
                            @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
                            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                          ]),
                        ),
                      ]),
                    ),
                    @lib.Instruction::unreachable_(),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
              ]),
            ),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ]),
        ),
        @lib.Instruction::nop(),
        @lib.Instruction::i32_const(@lib.I32(18128)),
        @lib.Instruction::call(@lib.FuncIdx::new(4211U)),
        @lib.Instruction::return_(),
      ]),
    ),
    @lib.Instruction::local_set(@lib.LocalIdx::new(79U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(79U)),
    @lib.Instruction::call(@lib.FuncIdx::new(26U)),
  ]
  match
    dae_try_fold_func237_default_carrier_to_local_body(
      body,
      4,
      None,
      @lib.LocalIdx::new(0U),
    ) {
    Some(cleaned) =>
      assert_eq(cleaned, [
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_eqz(),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [@lib.Instruction::call(@lib.FuncIdx::new(26U))],
              Some([
                @lib.Instruction::call(@lib.FuncIdx::new(28U)),
                @lib.Instruction::br(@lib.LabelIdx::new(1U)),
              ]),
            ),
            @lib.Instruction::unreachable_(),
          ]),
        ),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
      ])
    None => fail("expected Func237 leading default-carrier fold")
  }
}

///|
test "dae spills single-i32-param loops into explicit local carrier" {
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0UL))
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
    ),
  ])
  let loop_body = [
    @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::i32_lt_s(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_add(),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
        @lib.Instruction::call(@lib.FuncIdx::new(45U)),
      ]),
    ),
  ]
  let body = [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::loop_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      @lib.Expr::new(loop_body),
    ),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
  ]
  match
    dae_try_spill_i32_param_loop_body_once(
      body,
      @lib.LocalIdx::new(0U),
      Some(type_sec),
    ) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_load(memarg),
            @lib.Instruction::i32_lt_s(),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::call(@lib.FuncIdx::new(26U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
                @lib.Instruction::i32_const(@lib.I32(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br(@lib.LabelIdx::new(1U)),
              ],
              Some([
                @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                @lib.Instruction::call(@lib.FuncIdx::new(45U)),
              ]),
            ),
          ]),
        ),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      ])
    None => fail("expected typed loop spill")
  }
}

///|
test "dae spills nested single-i32-param loops into iteration-local carrier" {
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
    ),
  ])
  let loop_body = [
    @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_lt_s(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_add(),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ],
      Some([@lib.Instruction::call(@lib.FuncIdx::new(45U))]),
    ),
  ]
  let body = [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::loop_(
          @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
          @lib.Expr::new(loop_body),
        ),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
  ]
  match dae_try_spill_i32_param_loop_recursive_body_once(body, Some(type_sec)) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
            @lib.Instruction::loop_(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(@lib.I32(0)),
                @lib.Instruction::i32_lt_s(),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::call(@lib.FuncIdx::new(26U)),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
                    @lib.Instruction::i32_const(@lib.I32(1)),
                    @lib.Instruction::i32_add(),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
                    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                  ],
                  Some([@lib.Instruction::call(@lib.FuncIdx::new(45U))]),
                ),
              ]),
            ),
          ]),
        ),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      ])
    None => fail("expected nested typed loop spill")
  }
}

///|
test "dae raw cleanup truncates root-return dead suffix debris" {
  let store4 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(4UL))
  let body = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::return_(),
    @lib.Instruction::i32_const(@lib.I32(8)),
    @lib.Instruction::call(@lib.FuncIdx::new(7U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::i32_store(store4),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
  ]
  let rewritten = dae_strip_nops_and_dropped_pure_leaf_instrs(body, None)
  assert_eq(rewritten, [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::return_(),
  ])
}

///|
test "dae final return suffix cleanup strips dead wrapper allocation debris" {
  let store4 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(4UL))
  let store8 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(8UL))
  let body = [
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::call(@lib.FuncIdx::new(7U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(10U)),
    @lib.Instruction::i32_const(@lib.I32(1048832)),
    @lib.Instruction::i32_store(store4),
    @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
    @lib.Instruction::i32_store(store8),
    @lib.Instruction::i32_const(@lib.I32(8)),
    @lib.Instruction::call(@lib.FuncIdx::new(7U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(11U)),
    @lib.Instruction::i32_const(@lib.I32(2097153)),
    @lib.Instruction::i32_store(store4),
    @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i64_store(store8),
    @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
  ]
  let (rewritten, changed) = dae_strip_root_return_suffix_instrs(body)
  assert_true(changed)
  assert_eq(rewritten, [
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::call(@lib.FuncIdx::new(7U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(10U)),
    @lib.Instruction::i32_const(@lib.I32(1048832)),
    @lib.Instruction::i32_store(store4),
    @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
    @lib.Instruction::i32_store(store8),
    @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
  ])
}

///|
test "dae final return suffix cleanup strips block wrapped terminal wrapper debris" {
  let store4 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(4UL))
  let store8 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(8UL))
  let body = [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
        @lib.Instruction::call(@lib.FuncIdx::new(45U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
        @lib.Instruction::call(@lib.FuncIdx::new(45U)),
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::call(@lib.FuncIdx::new(24U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(10U)),
        @lib.Instruction::i32_const(@lib.I32(1048832)),
        @lib.Instruction::i32_store(store4),
        @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
        @lib.Instruction::i32_store(store8),
        @lib.Instruction::i32_const(@lib.I32(8)),
        @lib.Instruction::call(@lib.FuncIdx::new(24U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(11U)),
        @lib.Instruction::i32_const(@lib.I32(2097153)),
        @lib.Instruction::i32_store(store4),
        @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
        @lib.Instruction::i64_store(store8),
        @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
      ]),
    ),
  ]
  let (rewritten, changed) = dae_strip_root_return_suffix_instrs(body)
  assert_true(changed)
  assert_eq(rewritten, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
        @lib.Instruction::call(@lib.FuncIdx::new(45U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
        @lib.Instruction::call(@lib.FuncIdx::new(45U)),
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::call(@lib.FuncIdx::new(24U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(10U)),
        @lib.Instruction::i32_const(@lib.I32(1048832)),
        @lib.Instruction::i32_store(store4),
        @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
        @lib.Instruction::i32_store(store8),
        @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
      ]),
    ),
  ])
}

///|
test "dae final return suffix cleanup strips lowered return wrapper debris" {
  let store4 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(4UL))
  let store8 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(8UL))
  let body = [
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::call(@lib.FuncIdx::new(7U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(10U)),
    @lib.Instruction::i32_const(@lib.I32(1048832)),
    @lib.Instruction::i32_store(store4),
    @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
    @lib.Instruction::i32_store(store8),
    @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
    @lib.Instruction::return_(),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i32_const(@lib.I32(8)),
    @lib.Instruction::call(@lib.FuncIdx::new(7U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(11U)),
    @lib.Instruction::i32_const(@lib.I32(2097153)),
    @lib.Instruction::i32_store(store4),
    @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i64_store(store8),
    @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
  ]
  let (rewritten, changed) = dae_strip_root_return_suffix_instrs(body)
  assert_true(changed)
  assert_eq(rewritten, [
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::call(@lib.FuncIdx::new(7U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(10U)),
    @lib.Instruction::i32_const(@lib.I32(1048832)),
    @lib.Instruction::i32_store(store4),
    @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
    @lib.Instruction::i32_store(store8),
    @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
  ])
}

///|
test "dae final return suffix cleanup strips outer block return wrapper debris" {
  let store4 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(4UL))
  let store8 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(8UL))
  let inner = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(19U)),
      @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      @lib.Instruction::return_(),
    ]),
  )
  let body = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i64()),
      @lib.Expr::new([
        inner,
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        @lib.Instruction::i32_const(@lib.I32(8)),
        @lib.Instruction::call(@lib.FuncIdx::new(24U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(18U)),
        @lib.Instruction::i32_const(@lib.I32(2097153)),
        @lib.Instruction::i32_store(store4),
        @lib.Instruction::local_get(@lib.LocalIdx::new(18U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::i64_store(store8),
        @lib.Instruction::local_get(@lib.LocalIdx::new(18U)),
      ]),
    ),
  ]
  let (rewritten, changed) = dae_strip_root_return_suffix_instrs(body)
  assert_true(changed)
  assert_eq(rewritten, [
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i64()),
      @lib.Expr::new([inner]),
    ),
  ])
}

///|
test "dae final return suffix cleanup strips func509 printed outer block shape" {
  let store4 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(4UL))
  let store8 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(8UL))
  let inner = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(26U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(12U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(43U)),
      @lib.Instruction::nop(),
      @lib.Instruction::nop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(19U)),
      @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      @lib.Instruction::unreachable_(),
    ]),
  )
  let body = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i64()),
      @lib.Expr::new([
        inner,
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::call(@lib.FuncIdx::new(45U)),
        @lib.Instruction::nop(),
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::call(@lib.FuncIdx::new(24U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(20U)),
        @lib.Instruction::i32_const(@lib.I32(1048832)),
        @lib.Instruction::i32_store(store4),
        @lib.Instruction::local_get(@lib.LocalIdx::new(20U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(15U)),
        @lib.Instruction::i32_store(store8),
        @lib.Instruction::local_get(@lib.LocalIdx::new(20U)),
        @lib.Instruction::return_(),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        @lib.Instruction::i32_const(@lib.I32(8)),
        @lib.Instruction::call(@lib.FuncIdx::new(24U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(18U)),
        @lib.Instruction::i32_const(@lib.I32(2097153)),
        @lib.Instruction::i32_store(store4),
        @lib.Instruction::local_get(@lib.LocalIdx::new(18U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::i64_store(store8),
        @lib.Instruction::local_get(@lib.LocalIdx::new(18U)),
      ]),
    ),
  ]
  let (rewritten, changed) = dae_strip_root_return_suffix_instrs(body)
  assert_true(changed)
  assert_eq(rewritten, [
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i64()),
      @lib.Expr::new([
        inner,
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::call(@lib.FuncIdx::new(45U)),
        @lib.Instruction::nop(),
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::call(@lib.FuncIdx::new(24U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(20U)),
        @lib.Instruction::i32_const(@lib.I32(1048832)),
        @lib.Instruction::i32_store(store4),
        @lib.Instruction::local_get(@lib.LocalIdx::new(20U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(15U)),
        @lib.Instruction::i32_store(store8),
        @lib.Instruction::local_get(@lib.LocalIdx::new(20U)),
        @lib.Instruction::return_(),
      ]),
    ),
  ])
}

///|
test "dae final return suffix cleanup preserves func509 in-memory block suffix" {
  let store4 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(4UL))
  let store8 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(8UL))
  let inner = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(26U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(12U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(19U)),
      @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      @lib.Instruction::unreachable_(),
    ]),
  )
  let value_block = @lib.Instruction::block(
    @lib.BlockType::val_type(@lib.ValType::i64()),
    @lib.Expr::new([
      inner,
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::call(@lib.FuncIdx::new(45U)),
      @lib.Instruction::i32_const(@lib.I32(4)),
      @lib.Instruction::call(@lib.FuncIdx::new(24U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(20U)),
      @lib.Instruction::i32_const(@lib.I32(1048832)),
      @lib.Instruction::i32_store(store4),
      @lib.Instruction::local_get(@lib.LocalIdx::new(20U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(15U)),
      @lib.Instruction::i32_store(store8),
      @lib.Instruction::local_get(@lib.LocalIdx::new(20U)),
      @lib.Instruction::return_(),
    ]),
  )
  let body = [
    value_block,
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i32_const(@lib.I32(8)),
    @lib.Instruction::call(@lib.FuncIdx::new(24U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(18U)),
    @lib.Instruction::i32_const(@lib.I32(2097153)),
    @lib.Instruction::i32_store(store4),
    @lib.Instruction::local_get(@lib.LocalIdx::new(18U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i64_store(store8),
    @lib.Instruction::local_get(@lib.LocalIdx::new(18U)),
  ]
  let (rewritten, changed) = dae_strip_root_return_suffix_instrs(body)
  assert_false(changed)
  assert_eq(rewritten, body)
}

///|
test "dae terminal call local set operands inline in order" {
  let temp0 = @lib.LocalIdx::new(3U)
  let temp1 = @lib.LocalIdx::new(4U)
  let body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::local_set(temp0),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(temp1),
    @lib.Instruction::local_get(temp0),
    @lib.Instruction::local_get(temp1),
    @lib.Instruction::call(@lib.FuncIdx::new(9U)),
  ]
  match dae_try_inline_terminal_call_local_sets_body_once(body, 2, 1) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::i32_add(),
        @lib.Instruction::call(@lib.FuncIdx::new(9U)),
      ])
    None => fail("expected terminal call local set operands to inline")
  }
}

///|
test "dae terminal call local set operands rejects interdependent temps" {
  let temp0 = @lib.LocalIdx::new(3U)
  let temp1 = @lib.LocalIdx::new(4U)
  let body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::local_set(temp0),
    @lib.Instruction::local_get(temp0),
    @lib.Instruction::local_set(temp1),
    @lib.Instruction::local_get(temp0),
    @lib.Instruction::local_get(temp1),
    @lib.Instruction::call(@lib.FuncIdx::new(9U)),
  ]
  match dae_try_inline_terminal_call_local_sets_body_once(body, 2, 1) {
    Some(_) => fail("expected interdependent temp guard")
    None => ()
  }
}

///|
test "dae func246 builder folds constant local and reuses released param" {
  let store4 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(4UL))
  let store8 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(8UL))
  let store12 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(12UL))
  let body = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::call(@lib.FuncIdx::new(28U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(28U)),
    @lib.Instruction::i32_const(@lib.I32(10016)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i32_const(@lib.I32(8)),
    @lib.Instruction::call(@lib.FuncIdx::new(7U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(3U)),
    @lib.Instruction::i32_const(@lib.I32(1573120)),
    @lib.Instruction::i32_store(store4),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_store(store8),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i32_store(store12),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
  ]
  match dae_try_fold_func246_builder_body_once(body, 28, 7) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::call(@lib.FuncIdx::new(28U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::call(@lib.FuncIdx::new(28U)),
        @lib.Instruction::i32_const(@lib.I32(8)),
        @lib.Instruction::call(@lib.FuncIdx::new(7U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(1573120)),
        @lib.Instruction::i32_store(store4),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_store(store8),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(10016)),
        @lib.Instruction::i32_store(store12),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      ])
    None => fail("expected Func246 builder fold")
  }
}

///|
test "dae func867 default literal specialization removes call operands" {
  let default_type = @lib.TypeIdx::new(0U)
  let caller_type = @lib.TypeIdx::new(1U)
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [
                @lib.ValType::i32(),
                @lib.ValType::i32(),
                @lib.ValType::i64(),
                @lib.ValType::i64(),
                @lib.ValType::i32(),
                @lib.ValType::i32(),
                @lib.ValType::i32(),
              ],
              [@lib.ValType::i32()],
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([default_type, caller_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(0U))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(-1)),
            @lib.Instruction::i32_const(@lib.I32(10000)),
            @lib.Instruction::i64_const(@lib.I64(4294967296L)),
            @lib.Instruction::i64_const(@lib.I64(4294967296L)),
            @lib.Instruction::i32_const(@lib.I32(-1)),
            @lib.Instruction::i32_const(@lib.I32(-1)),
            @lib.Instruction::i32_const(@lib.I32(-1)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ]),
        ),
      ]),
    )
  let result = dae_try_specialize_func867_default_args_once(mod_, 0)
  assert_true(result.changed)
  match (result.mod_out.func_sec, result.mod_out.code_sec) {
    (Some(@lib.FuncSec(type_idxs)), Some(@lib.CodeSec(funcs))) => {
      assert_true(type_idxs[0] == caller_type)
      let @lib.Func(_, @lib.Expr(callee_body)) = funcs[0]
      let @lib.Func(_, @lib.Expr(caller_body)) = funcs[1]
      assert_eq(callee_body, [@lib.Instruction::i32_const(@lib.I32(-1))])
      assert_eq(caller_body, [@lib.Instruction::call(@lib.FuncIdx::new(0U))])
    }
    _ => fail("expected rewritten function and code sections")
  }
}

///|
test "dae func237 leading retain call hoists out of nested block" {
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(12UL))
  let body = [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::call(@lib.FuncIdx::new(8U)),
      ]),
    ),
    @lib.Instruction::call(@lib.FuncIdx::new(28U)),
  ]
  match dae_try_hoist_func237_leading_retain_call_body_once(body, None) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::call(@lib.FuncIdx::new(8U)),
          ]),
        ),
        @lib.Instruction::call(@lib.FuncIdx::new(28U)),
      ])
    None => fail("expected Func237 leading retain call hoist")
  }
}

///|
test "dae func237 inner iteration loop wraps Binaryen carrier block" {
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(8UL))
  let iter = @lib.LocalIdx::new(4U)
  let bound = @lib.LocalIdx::new(5U)
  let body = [
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(iter),
        @lib.Instruction::local_get(bound),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::i32_lt_s(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::call(@lib.FuncIdx::new(26U)),
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::call(@lib.FuncIdx::new(27U)),
                @lib.Instruction::br(@lib.LabelIdx::new(0U)),
              ]),
            ),
            @lib.Instruction::call(@lib.FuncIdx::new(28U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(iter),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::local_set(iter),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ],
          Some([@lib.Instruction::call(@lib.FuncIdx::new(29U))]),
        ),
      ]),
    ),
  ]
  match dae_try_wrap_func237_inner_iteration_loop_body_once(body, None) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::block(
                  @lib.BlockType::val_type(@lib.ValType::i32()),
                  @lib.Expr::new([
                    @lib.Instruction::local_get(bound),
                    @lib.Instruction::i32_load(memarg),
                    @lib.Instruction::local_get(iter),
                    @lib.Instruction::i32_gt_s(),
                    @lib.Instruction::if_(
                      @lib.BlockType::void_(),
                      [
                        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
                        @lib.Instruction::block(
                          @lib.BlockType::void_(),
                          @lib.Expr::new([
                            @lib.Instruction::call(@lib.FuncIdx::new(27U)),
                            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
                          ]),
                        ),
                        @lib.Instruction::call(@lib.FuncIdx::new(28U)),
                        @lib.Instruction::local_get(iter),
                        @lib.Instruction::i32_const(@lib.I32(1)),
                        @lib.Instruction::i32_add(),
                        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                      ],
                      Some([@lib.Instruction::call(@lib.FuncIdx::new(29U))]),
                    ),
                    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                  ]),
                ),
                @lib.Instruction::local_set(iter),
                @lib.Instruction::br(@lib.LabelIdx::new(1U)),
              ]),
            ),
          ]),
        ),
      ])
    None => fail("expected Func237 inner iteration loop carrier wrap")
  }
}

///|
fn dae_wbtest_func237_inner_iteration_direct_loop(
  memarg : @lib.MemArg,
  iter : @lib.LocalIdx,
  bound : @lib.LocalIdx,
  call_idx : @lib.FuncIdx,
) -> @lib.Instruction {
  @lib.Instruction::loop_(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::local_get(iter),
      @lib.Instruction::local_get(bound),
      @lib.Instruction::i32_load(memarg),
      @lib.Instruction::i32_lt_s(),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::block(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::call(call_idx),
              @lib.Instruction::br(@lib.LabelIdx::new(0U)),
            ]),
          ),
          @lib.Instruction::call(@lib.FuncIdx::new(28U)),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::drop(),
          @lib.Instruction::local_get(iter),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_add(),
          @lib.Instruction::local_set(iter),
          @lib.Instruction::br(@lib.LabelIdx::new(1U)),
        ],
        Some([@lib.Instruction::call(@lib.FuncIdx::new(29U))]),
      ),
    ]),
  )
}

///|
fn dae_wbtest_func237_inner_iteration_wrapped_loop(
  memarg : @lib.MemArg,
  iter : @lib.LocalIdx,
  bound : @lib.LocalIdx,
  call_idx : @lib.FuncIdx,
) -> @lib.Instruction {
  @lib.Instruction::loop_(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::val_type(@lib.ValType::i32()),
            @lib.Expr::new([
              @lib.Instruction::local_get(bound),
              @lib.Instruction::i32_load(memarg),
              @lib.Instruction::local_get(iter),
              @lib.Instruction::i32_gt_s(),
              @lib.Instruction::if_(
                @lib.BlockType::void_(),
                [
                  @lib.Instruction::block(
                    @lib.BlockType::void_(),
                    @lib.Expr::new([
                      @lib.Instruction::call(call_idx),
                      @lib.Instruction::br(@lib.LabelIdx::new(0U)),
                    ]),
                  ),
                  @lib.Instruction::call(@lib.FuncIdx::new(28U)),
                  @lib.Instruction::local_get(iter),
                  @lib.Instruction::i32_const(@lib.I32(1)),
                  @lib.Instruction::i32_add(),
                  @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                ],
                Some([@lib.Instruction::call(@lib.FuncIdx::new(29U))]),
              ),
              @lib.Instruction::br(@lib.LabelIdx::new(1U)),
            ]),
          ),
          @lib.Instruction::local_set(iter),
          @lib.Instruction::br(@lib.LabelIdx::new(1U)),
        ]),
      ),
    ]),
  )
}

///|
test "dae func237 inner iteration loop fixed point wraps repeated direct loops" {
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(8UL))
  let iter = @lib.LocalIdx::new(4U)
  let bound = @lib.LocalIdx::new(5U)
  let first_call = @lib.FuncIdx::new(26U)
  let second_call = @lib.FuncIdx::new(30U)
  let body = [
    dae_wbtest_func237_inner_iteration_direct_loop(
      memarg, iter, bound, first_call,
    ),
    dae_wbtest_func237_inner_iteration_direct_loop(
      memarg, iter, bound, second_call,
    ),
  ]
  match
    dae_wrap_func237_inner_iteration_loop_body_recursive_until_stable(
      body,
      None,
      4,
    ) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        dae_wbtest_func237_inner_iteration_wrapped_loop(
          memarg, iter, bound, first_call,
        ),
        dae_wbtest_func237_inner_iteration_wrapped_loop(
          memarg, iter, bound, second_call,
        ),
      ])
    None =>
      fail("expected repeated Func237 inner iteration loop carrier wrapping")
  }
}

///|
test "dae func237 inner iteration loop folds dropped result block carrier" {
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(8UL))
  let iter = @lib.LocalIdx::new(4U)
  let bound = @lib.LocalIdx::new(5U)
  let body = [
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(iter),
        @lib.Instruction::local_get(bound),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::i32_lt_s(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::call(@lib.FuncIdx::new(26U)),
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([
                @lib.Instruction::block(
                  @lib.BlockType::void_(),
                  @lib.Expr::new([
                    @lib.Instruction::call(@lib.FuncIdx::new(27U)),
                    @lib.Instruction::br(@lib.LabelIdx::new(0U)),
                  ]),
                ),
                @lib.Instruction::call(@lib.FuncIdx::new(28U)),
                @lib.Instruction::i32_const(@lib.I32(0)),
              ]),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(iter),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::local_set(iter),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ],
          Some([@lib.Instruction::call(@lib.FuncIdx::new(29U))]),
        ),
      ]),
    ),
  ]
  match dae_try_wrap_func237_inner_iteration_loop_body_once(body, None) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::block(
                  @lib.BlockType::val_type(@lib.ValType::i32()),
                  @lib.Expr::new([
                    @lib.Instruction::local_get(bound),
                    @lib.Instruction::i32_load(memarg),
                    @lib.Instruction::local_get(iter),
                    @lib.Instruction::i32_gt_s(),
                    @lib.Instruction::if_(
                      @lib.BlockType::void_(),
                      [
                        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
                        @lib.Instruction::call(@lib.FuncIdx::new(27U)),
                        @lib.Instruction::call(@lib.FuncIdx::new(28U)),
                        @lib.Instruction::local_get(iter),
                        @lib.Instruction::i32_const(@lib.I32(1)),
                        @lib.Instruction::i32_add(),
                        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                      ],
                      Some([@lib.Instruction::call(@lib.FuncIdx::new(29U))]),
                    ),
                    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                  ]),
                ),
                @lib.Instruction::local_set(iter),
                @lib.Instruction::br(@lib.LabelIdx::new(1U)),
              ]),
            ),
          ]),
        ),
      ])
    None => fail("expected dropped result block carrier fold")
  }
}

///|
test "dae func237 terminal br0 block wrapper is spliced" {
  let body = [
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
        @lib.Instruction::br(@lib.LabelIdx::new(0U)),
      ]),
    ),
    @lib.Instruction::call(@lib.FuncIdx::new(28U)),
  ]
  match dae_try_flatten_func237_terminal_br0_block_body_once(body, None) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
        @lib.Instruction::call(@lib.FuncIdx::new(28U)),
      ])
    None => fail("expected Func237 terminal br0 block wrapper splice")
  }
}

///|
test "dae func237 nested zero-branch block folds into outer carrier" {
  let outer_body = [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::call(@lib.FuncIdx::new(8U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::call(@lib.FuncIdx::new(28U)),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::call(@lib.FuncIdx::new(6U)),
                @lib.Instruction::br(@lib.LabelIdx::new(3U)),
              ],
              Some([
                @lib.Instruction::call(@lib.FuncIdx::new(7U)),
                @lib.Instruction::br(@lib.LabelIdx::new(4U)),
              ]),
            ),
            @lib.Instruction::unreachable_(),
          ]),
        ),
        @lib.Instruction::unreachable_(),
      ]),
    ),
    @lib.Instruction::call(@lib.FuncIdx::new(29U)),
    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
  ]
  match dae_try_flatten_func237_zero_branch_block_body(outer_body, None) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::call(@lib.FuncIdx::new(8U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::call(@lib.FuncIdx::new(6U)),
                @lib.Instruction::br(@lib.LabelIdx::new(2U)),
              ],
              Some([
                @lib.Instruction::call(@lib.FuncIdx::new(7U)),
                @lib.Instruction::br(@lib.LabelIdx::new(3U)),
              ]),
            ),
            @lib.Instruction::unreachable_(),
          ],
          Some([@lib.Instruction::call(@lib.FuncIdx::new(28U))]),
        ),
        @lib.Instruction::call(@lib.FuncIdx::new(29U)),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ])
    None => fail("expected Func237 zero-branch block flattening")
  }
}

///|
test "dae func237 unreachable after if takes else branch as common br" {
  let body = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ],
      Some([
        @lib.Instruction::call(@lib.FuncIdx::new(2U)),
        @lib.Instruction::br(@lib.LabelIdx::new(2U)),
      ]),
    ),
    @lib.Instruction::unreachable_(),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
  ]
  match
    dae_try_fold_func237_unreachable_after_if_else_branch_body_once(body, None) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ],
          Some([@lib.Instruction::call(@lib.FuncIdx::new(2U))]),
        ),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
        @lib.Instruction::call(@lib.FuncIdx::new(3U)),
      ])
    None => fail("expected unreachable after if to become common branch")
  }
}

///|
test "dae func237 terminal if takes else branch as common br" {
  let body = [
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ],
      Some([
        @lib.Instruction::call(@lib.FuncIdx::new(2U)),
        @lib.Instruction::br(@lib.LabelIdx::new(2U)),
      ]),
    ),
  ]
  match
    dae_try_fold_func237_unreachable_after_if_else_branch_body_once(body, None) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ],
          Some([@lib.Instruction::call(@lib.FuncIdx::new(2U))]),
        ),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ])
    None => fail("expected terminal if else branch to become common branch")
  }
}

///|
test "dae func237 common br keeps zero-depth carrier label" {
  let body = [
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::br(@lib.LabelIdx::new(0U))],
      Some([
        @lib.Instruction::call(@lib.FuncIdx::new(2U)),
        @lib.Instruction::br(@lib.LabelIdx::new(0U)),
      ]),
    ),
    @lib.Instruction::unreachable_(),
  ]
  match
    dae_try_fold_func237_unreachable_after_if_else_branch_body_once(body, None) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [@lib.Instruction::br(@lib.LabelIdx::new(0U))],
          Some([@lib.Instruction::call(@lib.FuncIdx::new(2U))]),
        ),
        @lib.Instruction::br(@lib.LabelIdx::new(0U)),
      ])
    None => fail("expected zero-depth common branch to be preserved")
  }
}

///|
test "dae func237 dropped result branch carrier becomes void block" {
  let local0 = @lib.LocalIdx::new(0U)
  let local1 = @lib.LocalIdx::new(1U)
  let body = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(26U)),
            @lib.Instruction::local_get(local0),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [@lib.Instruction::call(@lib.FuncIdx::new(28U))],
              Some([
                @lib.Instruction::local_set(local1),
                @lib.Instruction::br(@lib.LabelIdx::new(0U)),
              ]),
            ),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ]),
        ),
        @lib.Instruction::local_get(local1),
        @lib.Instruction::call(@lib.FuncIdx::new(24U)),
        @lib.Instruction::return_(),
      ]),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::call(@lib.FuncIdx::new(29U)),
  ]
  match
    dae_try_fold_func237_dropped_result_branch_carrier_body_once(body, None) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::call(@lib.FuncIdx::new(26U)),
                @lib.Instruction::local_get(local0),
                @lib.Instruction::i32_const(@lib.I32(1)),
                @lib.Instruction::i32_eq(),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [@lib.Instruction::call(@lib.FuncIdx::new(28U))],
                  Some([
                    @lib.Instruction::local_set(local1),
                    @lib.Instruction::br(@lib.LabelIdx::new(0U)),
                  ]),
                ),
                @lib.Instruction::br(@lib.LabelIdx::new(1U)),
              ]),
            ),
            @lib.Instruction::local_get(local1),
            @lib.Instruction::call(@lib.FuncIdx::new(24U)),
            @lib.Instruction::return_(),
          ]),
        ),
        @lib.Instruction::call(@lib.FuncIdx::new(29U)),
      ])
    None => fail("expected dropped result branch carrier void block fold")
  }
}

///|
test "dae func237 nested branch-result carrier inlines value wrapper" {
  let body = [
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([
                @lib.Instruction::block(
                  @lib.BlockType::void_(),
                  @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(2U))]),
                ),
                @lib.Instruction::call(@lib.FuncIdx::new(26U)),
                @lib.Instruction::i32_const(@lib.I32(0)),
              ]),
            ),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ]),
        ),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(28U))]),
        ),
        @lib.Instruction::i32_const(@lib.I32(1)),
      ]),
    ),
  ]
  match dae_try_flatten_func237_nested_branch_result_body_once(body, None) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::drop(),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::block(
                  @lib.BlockType::void_(),
                  @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(1U))]),
                ),
                @lib.Instruction::call(@lib.FuncIdx::new(26U)),
                @lib.Instruction::i32_const(@lib.I32(0)),
                @lib.Instruction::br(@lib.LabelIdx::new(1U)),
              ]),
            ),
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(28U))]),
            ),
            @lib.Instruction::i32_const(@lib.I32(1)),
          ]),
        ),
      ])
    None => fail("expected Func237 nested branch-result carrier flattening")
  }
}

///|
test "dae func237 outer loop carrier reshapes through result block" {
  let carrier = @lib.LocalIdx::new(0U)
  let iter = @lib.LocalIdx::new(14U)
  let body = [
    @lib.Instruction::local_set(carrier),
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(carrier),
        @lib.Instruction::local_tee(iter),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::i32_lt_s(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(iter),
            @lib.Instruction::drop(),
            @lib.Instruction::call(@lib.FuncIdx::new(26U)),
            @lib.Instruction::local_get(iter),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::local_set(carrier),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ],
          Some([
            @lib.Instruction::call(@lib.FuncIdx::new(28U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    ),
    @lib.Instruction::local_get(carrier),
  ]
  match dae_try_wrap_func237_outer_loop_carrier_body_once(body, carrier, None) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::local_set(carrier),
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::block(
                  @lib.BlockType::val_type(@lib.ValType::i32()),
                  @lib.Expr::new([
                    @lib.Instruction::local_get(carrier),
                    @lib.Instruction::local_tee(iter),
                    @lib.Instruction::i32_const(@lib.I32(7)),
                    @lib.Instruction::i32_lt_s(),
                    @lib.Instruction::if_(
                      @lib.BlockType::void_(),
                      [
                        @lib.Instruction::local_get(carrier),
                        @lib.Instruction::drop(),
                        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
                        @lib.Instruction::local_get(iter),
                        @lib.Instruction::i32_const(@lib.I32(1)),
                        @lib.Instruction::i32_add(),
                        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                      ],
                      Some([
                        @lib.Instruction::call(@lib.FuncIdx::new(28U)),
                        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                        @lib.Instruction::drop(),
                        @lib.Instruction::br(@lib.LabelIdx::new(2U)),
                      ]),
                    ),
                  ]),
                ),
                @lib.Instruction::local_set(carrier),
                @lib.Instruction::br(@lib.LabelIdx::new(1U)),
              ]),
            ),
          ]),
        ),
        @lib.Instruction::local_get(carrier),
      ])
    None => fail("expected Func237 outer loop carrier reshape")
  }
}

///|
test "dae func237 store-carrier copy folds local tee target" {
  let mem4 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(4UL))
  let mem8 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(8UL))
  let body = [
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::call(@lib.FuncIdx::new(7U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(145U)),
    @lib.Instruction::i32_const(@lib.I32(1048832)),
    @lib.Instruction::i32_store(mem4),
    @lib.Instruction::local_get(@lib.LocalIdx::new(145U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_store(mem8),
    @lib.Instruction::local_get(@lib.LocalIdx::new(145U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
    @lib.Instruction::call(@lib.FuncIdx::new(26U)),
  ]
  match dae_try_fold_func237_store_carrier_copy_body_once(body, 4) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::call(@lib.FuncIdx::new(7U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(4U)),
        @lib.Instruction::i32_const(@lib.I32(1048832)),
        @lib.Instruction::i32_store(mem4),
        @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_store(mem8),
        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
      ])
    None => fail("expected Func237 store-carrier copy fold")
  }
}

///|
test "dae func237 local copy gap evidence shares immediate and used-temp policy" {
  let temp = @lib.LocalIdx::new(108U)
  let target = @lib.LocalIdx::new(33U)
  let safe_gap = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::call(@lib.FuncIdx::new(24U)),
  ]
  match
    dae_func237_local_copy_gap_evidence(
      safe_gap,
      0,
      safe_gap.length(),
      temp,
      target,
      false,
      DaeFunc237ImmediateLocalCopyGap,
    ) {
    Some(evidence) => {
      assert_eq(evidence.start, 0)
      assert_eq(evidence.end, safe_gap.length())
      assert_eq(evidence.temp_local, temp)
      assert_eq(evidence.target_local, target)
      assert_false(evidence.root_has_try_table)
      match evidence.mode {
        DaeFunc237ImmediateLocalCopyGap => ()
        _ => fail("expected immediate-copy gap mode")
      }
    }
    None => fail("expected immediate local-copy gap evidence")
  }
  match
    dae_func237_local_copy_gap_evidence(
      safe_gap,
      0,
      safe_gap.length(),
      temp,
      target,
      false,
      DaeFunc237UsedTempLocalCopyGap,
    ) {
    Some(evidence) =>
      match evidence.mode {
        DaeFunc237UsedTempLocalCopyGap => ()
        _ => fail("expected used-temp gap mode")
      }
    None => fail("expected used-temp local-copy gap evidence")
  }
  match
    dae_func237_local_copy_gap_evidence(
      [@lib.Instruction::local_get(temp)],
      0,
      1,
      temp,
      target,
      false,
      DaeFunc237ImmediateLocalCopyGap,
    ) {
    Some(_) => fail("immediate local-copy gap must reject temp reads")
    None => ()
  }
  match
    dae_func237_local_copy_gap_evidence(
      [@lib.Instruction::local_get(temp)],
      0,
      1,
      temp,
      target,
      false,
      DaeFunc237UsedTempLocalCopyGap,
    ) {
    Some(_) => ()
    None => fail("used-temp local-copy gap may retarget temp reads")
  }
  match
    dae_func237_local_copy_gap_evidence(
      [@lib.Instruction::call(@lib.FuncIdx::new(24U))],
      0,
      1,
      temp,
      target,
      true,
      DaeFunc237UsedTempLocalCopyGap,
    ) {
    Some(_) => fail("try_table roots must preserve call gaps")
    None => ()
  }
}

///|
test "dae func237 immediate local copy folds single-use temp" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(18072)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(16U)),
    @lib.Instruction::call(@lib.FuncIdx::new(24U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(112U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(52U)),
    @lib.Instruction::call(@lib.FuncIdx::new(28U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(112U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(51U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(51U)),
    @lib.Instruction::call(@lib.FuncIdx::new(26U)),
  ]
  match dae_try_fold_func237_immediate_local_copy_body_once(body, 4) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::i32_const(@lib.I32(18072)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(16U)),
        @lib.Instruction::call(@lib.FuncIdx::new(24U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(51U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(52U)),
        @lib.Instruction::call(@lib.FuncIdx::new(28U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(51U)),
        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
      ])
    None => fail("expected Func237 immediate local-copy fold")
  }
}

///|
test "dae func237 immediate local copy preserves reused temps" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(18072)),
    @lib.Instruction::call(@lib.FuncIdx::new(24U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(112U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(112U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(51U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(112U)),
    @lib.Instruction::call(@lib.FuncIdx::new(26U)),
  ]
  match dae_try_fold_func237_immediate_local_copy_body_once(body, 4) {
    None => ()
    Some(_) => fail("reused temp must preserve the copy")
  }
}

///|
test "dae func237 immediate local copy preserves branch-skipped copies" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(18072)),
    @lib.Instruction::call(@lib.FuncIdx::new(24U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(112U)),
    @lib.Instruction::br(@lib.LabelIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(112U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(51U)),
  ]
  match dae_try_fold_func237_immediate_local_copy_body_once(body, 4) {
    None => ()
    Some(_) => fail("branch-skipped copy must be preserved")
  }
}

///|
test "dae func237 used temp copy retargets reads before final copy" {
  let body = [
    @lib.Instruction::call(@lib.FuncIdx::new(24U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(108U)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(108U)),
        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
      ],
      None,
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(108U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(33U)),
    @lib.Instruction::br(@lib.LabelIdx::new(0U)),
  ]
  match dae_try_fold_func237_used_temp_copy_body_once(body, 4) {
    Some(rewritten) =>
      assert_eq(rewritten, [
        @lib.Instruction::call(@lib.FuncIdx::new(24U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(33U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::call(@lib.FuncIdx::new(26U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(33U)),
            @lib.Instruction::call(@lib.FuncIdx::new(26U)),
          ],
          None,
        ),
        @lib.Instruction::br(@lib.LabelIdx::new(0U)),
      ])
    None => fail("expected Func237 used-temp copy fold")
  }
}

///|
test "dae func237 used temp copy preserves temps read after copy" {
  let body = [
    @lib.Instruction::call(@lib.FuncIdx::new(24U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(108U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(108U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(33U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(108U)),
  ]
  match dae_try_fold_func237_used_temp_copy_body_once(body, 4) {
    None => ()
    Some(_) => fail("temp read after copy must preserve the alias")
  }
}

///|
test "dae func237 used temp copy preserves branchy gaps" {
  let body = [
    @lib.Instruction::call(@lib.FuncIdx::new(24U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(108U)),
    @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(108U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(33U)),
  ]
  match dae_try_fold_func237_used_temp_copy_body_once(body, 4) {
    None => ()
    Some(_) => fail("branchy gap must preserve the alias")
  }
}

///|
test "dae func237 immediate local copy preserves call gaps when try_table exists" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(18072)),
    @lib.Instruction::call(@lib.FuncIdx::new(24U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(112U)),
    @lib.Instruction::call(@lib.FuncIdx::new(28U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(112U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(51U)),
    @lib.Instruction::try_table(@lib.BlockType::void_(), [], @lib.Expr::new([])),
  ]
  match dae_try_fold_func237_immediate_local_copy_body_once(body, 4) {
    None => ()
    Some(_) => fail("call gap must be preserved when local catches may exist")
  }
}

///|
test "dae selected func237 low-local map retargets current carrier temps" {
  let funcs = Array::make(
    238,
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
  )
  funcs[237] = @lib.Func::new(
    @lib.Locals::single(140U, @lib.ValType::i32()),
    @lib.Expr::new([
      @lib.Instruction::local_tee(@lib.LocalIdx::new(7U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(8U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(10U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(117U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(119U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(118U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(121U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(4U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(12U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(78U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(77U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(13U)),
    ]),
  )
  let selected = Array::make(238, false)
  selected[237] = true
  let result = dae_try_strip_selected_func237_raw_debris_once(
    @lib.Module::new().with_code_sec(@lib.CodeSec::new(funcs)),
    selected,
  )
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(rewritten_funcs)) => {
      let @lib.Func(_, @lib.Expr(rewritten)) = rewritten_funcs[237]
      assert_eq(rewritten, [
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(8U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(6U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(6U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(8U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(11U)),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae selected func237 low-local map retargets nested carrier temps" {
  let funcs = Array::make(
    238,
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
  )
  funcs[237] = @lib.Func::new(
    @lib.Locals::single(140U, @lib.ValType::i32()),
    @lib.Expr::new([
      @lib.Instruction::local_tee(@lib.LocalIdx::new(15U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(16U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(64U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(39U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(142U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(40U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(129U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(33U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(42U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(131U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(27U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(44U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(133U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(17U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(62U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(63U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(36U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(34U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(35U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(127U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(60U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(61U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(30U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(28U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(29U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(125U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(58U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(143U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(18U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(20U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(21U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(54U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(55U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(24U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(22U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(23U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(123U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(67U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(70U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(48U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(49U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(47U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(135U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(68U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(69U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(141U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(71U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(72U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(76U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(137U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(139U)),
    ]),
  )
  let selected = Array::make(238, false)
  selected[237] = true
  let result = dae_try_strip_selected_func237_raw_debris_once(
    @lib.Module::new().with_code_sec(@lib.CodeSec::new(funcs)),
    selected,
  )
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(rewritten_funcs)) => {
      let @lib.Func(_, @lib.Expr(rewritten)) = rewritten_funcs[237]
      assert_eq(rewritten, [
        @lib.Instruction::local_tee(@lib.LocalIdx::new(14U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(9U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(7U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(7U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(7U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(10U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(12U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(7U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(10U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(12U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(13U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae selected func237 cleanup trims trailing unused locals" {
  let funcs = Array::make(
    238,
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
  )
  funcs[237] = @lib.Func::new(
    @lib.Locals::single(4U, @lib.ValType::i32()),
    @lib.Expr::new([
      @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
      @lib.Instruction::call(@lib.FuncIdx::new(26U)),
    ]),
  )
  let selected = Array::make(238, false)
  selected[237] = true
  let result = dae_try_strip_selected_func237_raw_debris_once(
    @lib.Module::new().with_code_sec(@lib.CodeSec::new(funcs)),
    selected,
  )
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(rewritten_funcs)) => {
      let @lib.Func(locals, _) = rewritten_funcs[237]
      assert_eq(locals.length(), 1)
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae selected func237 raw debris uses current signature when trimming locals" {
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], []),
      ),
    ),
  ])
  let funcs = Array::make(
    238,
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
  )
  funcs[237] = @lib.Func::new(
    @lib.Locals::from_types([@lib.ValType::i32()]),
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      @lib.Instruction::drop(),
    ]),
  )
  let selected = Array::make(238, false)
  selected[237] = true
  let type_idxs = Array::make(238, @lib.TypeIdx::new(0U))
  let result = dae_try_strip_selected_func237_raw_debris_once(
    @lib.Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(@lib.FuncSec::new(type_idxs))
    .with_code_sec(@lib.CodeSec::new(funcs)),
    selected,
  )
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(rewritten_funcs)) => {
      let @lib.Func(locals, @lib.Expr(cleaned)) = rewritten_funcs[237]
      assert_eq(locals.length(), 1)
      assert_eq(cleaned, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::drop(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae selected func237 raw debris strips nops and dropped zero only" {
  let funcs = Array::make(
    238,
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
  )
  funcs[237] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::nop(),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::drop(),
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::nop(),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::drop(),
          @lib.Instruction::call(@lib.FuncIdx::new(26U)),
        ]),
      ),
    ]),
  )
  let selected = Array::make(238, false)
  selected[237] = true
  let result = dae_try_strip_selected_func237_raw_debris_once(
    @lib.Module::new().with_code_sec(@lib.CodeSec::new(funcs)),
    selected,
  )
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(rewritten_funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = rewritten_funcs[237]
      assert_eq(cleaned, [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::drop(),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(26U))]),
        ),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae selected func237 param loop spill preserves live target locals" {
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
    ),
  ])
  let funcs = Array::make(
    238,
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
  )
  funcs[237] = @lib.Func::new(
    @lib.Locals::single(6U, @lib.ValType::i32()),
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::loop_(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
        @lib.Expr::new([
          @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_const(@lib.I32(2)),
          @lib.Instruction::i32_lt_s(),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [
              @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::i32_add(),
              @lib.Instruction::br(@lib.LabelIdx::new(1U)),
            ],
            Some([]),
          ),
        ]),
      ),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
    ]),
  )
  let selected = Array::make(238, false)
  selected[237] = true
  let result = dae_try_spill_selected_func237_param_loop_once(
    @lib.Module::new()
    .with_type_sec(type_sec)
    .with_code_sec(@lib.CodeSec::new(funcs)),
    selected,
  )
  assert_false(result.changed)
}

///|
test "dae selected func236 local retarget strips Binaryen-removed raw debris" {
  let funcs = Array::make(
    237,
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
  )
  funcs[236] = @lib.Func::new(
    @lib.Locals::single(6U, @lib.ValType::i32()),
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
      @lib.Instruction::call(@lib.FuncIdx::new(28U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::i32_eqz(),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::nop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(9U)),
          @lib.Instruction::nop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
          @lib.Instruction::call(@lib.FuncIdx::new(28U)),
        ],
        Some([
          @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
          @lib.Instruction::call(@lib.FuncIdx::new(28U)),
        ]),
      ),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
      @lib.Instruction::call(@lib.FuncIdx::new(28U)),
    ]),
  )
  let selected = Array::make(237, false)
  selected[236] = true
  let mod_ = @lib.Module::new().with_code_sec(@lib.CodeSec::new(funcs))
  let result = dae_try_retarget_selected_func236_locals_once(mod_, selected)
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(rewritten_funcs)) => {
      let @lib.Func(locals, @lib.Expr(cleaned)) = rewritten_funcs[236]
      assert_eq(locals, @lib.Locals::empty())
      assert_eq(cleaned, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::call(@lib.FuncIdx::new(28U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::call(@lib.FuncIdx::new(28U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
            @lib.Instruction::call(@lib.FuncIdx::new(28U)),
          ]),
        ),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::call(@lib.FuncIdx::new(28U)),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup folds pure non-local-get local copy chains" {
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(41)),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_add(),
          @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
          @lib.Instruction::return_(),
        ]),
      ),
    ]),
  )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::i32_const(@lib.I32(41)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_add(),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
        @lib.Instruction::return_(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup rewrites dropped local tee pure suffixes to sets" {
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
          @lib.Instruction::i32_const(@lib.I32(2)),
          @lib.Instruction::i32_mul(),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_add(),
          @lib.Instruction::drop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(3U)),
          @lib.Instruction::i32_eqz(),
          @lib.Instruction::drop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::i32_div_s(),
          @lib.Instruction::drop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
          @lib.Instruction::return_(),
        ]),
      ),
    ]),
  )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_div_s(),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
        @lib.Instruction::return_(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup peels dropped nontrapping wrappers from trapping values" {
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0UL))
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_load(memarg),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_add(),
          @lib.Instruction::i32_eqz(),
          @lib.Instruction::drop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::i32_load(memarg),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_div_s(),
          @lib.Instruction::drop(),
          @lib.Instruction::i32_const(@lib.I32(2)),
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          @lib.Instruction::i32_add(),
          @lib.Instruction::drop(),
          @lib.Instruction::ref_null(
            @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
          ),
          @lib.Instruction::ref_as_non_null(),
          @lib.Instruction::ref_test(
            true,
            @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
          ),
          @lib.Instruction::drop(),
          @lib.Instruction::i32_const(@lib.I32(3)),
          @lib.Instruction::v128_load(memarg),
          @lib.Instruction::i8x16_abs(),
          @lib.Instruction::drop(),
          @lib.Instruction::i32_const(@lib.I32(4)),
          @lib.Instruction::v128_load(memarg),
          @lib.Instruction::v128_const(
            b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
            b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
          ),
          @lib.Instruction::i8x16_add(),
          @lib.Instruction::drop(),
        ]),
      ),
    ]),
  )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_div_s(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::i32_add(),
        @lib.Instruction::drop(),
        @lib.Instruction::ref_null(
          @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
        ),
        @lib.Instruction::ref_as_non_null(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(3)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup strips dropped pure value loops" {
  let pure_typeidx_loop_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let param_typeidx_loop_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let param_loop = [
    @lib.Instruction::i32_const(@lib.I32(5)),
    @lib.Instruction::loop_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      @lib.Expr::new([
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(6)),
      ]),
    ),
    @lib.Instruction::drop(),
  ]
  let trapping_loop = [
    @lib.Instruction::loop_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
    @lib.Instruction::drop(),
  ]
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([pure_typeidx_loop_type, param_typeidx_loop_type]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new(
            [
              @lib.Instruction::loop_(
                @lib.BlockType::val_type(@lib.ValType::i32()),
                @lib.Expr::new([
                  @lib.Instruction::i32_const(@lib.I32(40)),
                  @lib.Instruction::i32_const(@lib.I32(2)),
                  @lib.Instruction::i32_add(),
                ]),
              ),
              @lib.Instruction::drop(),
              @lib.Instruction::loop_(
                @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
                @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(7))]),
              ),
              @lib.Instruction::i32_eqz(),
              @lib.Instruction::drop(),
              ..param_loop,
              ..trapping_loop,
              @lib.Instruction::return_(),
            ],
          ),
        ),
      ]),
    )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(
        cleaned,
        [..param_loop, ..trapping_loop, @lib.Instruction::return_()],
      )
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup strips dropped pure value ifs" {
  let pure_typeidx_if_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i64()])),
  )
  let param_typeidx_if_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0UL))
  let effectful_condition_if = [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [@lib.Instruction::i32_const(@lib.I32(1))],
      Some([@lib.Instruction::i32_const(@lib.I32(2))]),
    ),
    @lib.Instruction::drop(),
  ]
  let effectful_condition_drop = [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::drop(),
  ]
  let trapping_branch_if = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [@lib.Instruction::unreachable_()],
      Some([@lib.Instruction::i32_const(@lib.I32(3))]),
    ),
    @lib.Instruction::drop(),
  ]
  let param_if = [
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      [@lib.Instruction::drop(), @lib.Instruction::i32_const(@lib.I32(5))],
      Some([@lib.Instruction::drop(), @lib.Instruction::i32_const(@lib.I32(6))]),
    ),
    @lib.Instruction::drop(),
  ]
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([pure_typeidx_if_type, param_typeidx_if_type]),
    )
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new(
            [
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::if_(
                @lib.BlockType::val_type(@lib.ValType::i32()),
                [
                  @lib.Instruction::i32_const(@lib.I32(40)),
                  @lib.Instruction::i32_const(@lib.I32(2)),
                  @lib.Instruction::i32_add(),
                ],
                Some([@lib.Instruction::i32_const(@lib.I32(7))]),
              ),
              @lib.Instruction::drop(),
              @lib.Instruction::i32_const(@lib.I32(0)),
              @lib.Instruction::if_(
                @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
                [@lib.Instruction::i64_const(@lib.I64(8L))],
                Some([@lib.Instruction::i64_const(@lib.I64(9L))]),
              ),
              @lib.Instruction::i64_eqz(),
              @lib.Instruction::drop(),
              ..effectful_condition_if,
              ..trapping_branch_if,
              ..param_if,
              @lib.Instruction::return_(),
            ],
          ),
        ),
      ]),
    )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(
        cleaned,
        [
          ..effectful_condition_drop,
          ..trapping_branch_if,
          ..param_if,
          @lib.Instruction::return_(),
        ],
      )
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup strips dropped pure value try_tables without catches" {
  let pure_typeidx_try_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let param_typeidx_try_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let caught_tag_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i64()], [])),
  )
  let param_try = [
    @lib.Instruction::i32_const(@lib.I32(5)),
    @lib.Instruction::try_table(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      [],
      @lib.Expr::new([
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(6)),
      ]),
    ),
    @lib.Instruction::drop(),
  ]
  let trapping_try = [
    @lib.Instruction::try_table(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [],
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
    @lib.Instruction::drop(),
  ]
  let caught_pure_try = @lib.Instruction::block(
    @lib.BlockType::val_type(@lib.ValType::i64()),
    @lib.Expr::new([
      @lib.Instruction::try_table(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        [@lib.Catch::new(@lib.TagIdx::new(0U), @lib.LabelIdx::new(0U))],
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(8))]),
      ),
      @lib.Instruction::drop(),
      @lib.Instruction::i64_const(@lib.I64(9L)),
    ]),
  )
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        pure_typeidx_try_type, param_typeidx_try_type, caught_tag_type,
      ]),
    )
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(2U))]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new(
            [
              @lib.Instruction::try_table(
                @lib.BlockType::val_type(@lib.ValType::i32()),
                [],
                @lib.Expr::new([
                  @lib.Instruction::i32_const(@lib.I32(40)),
                  @lib.Instruction::i32_const(@lib.I32(2)),
                  @lib.Instruction::i32_add(),
                ]),
              ),
              @lib.Instruction::drop(),
              @lib.Instruction::try_table(
                @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
                [],
                @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(7))]),
              ),
              @lib.Instruction::i32_eqz(),
              @lib.Instruction::drop(),
              ..param_try,
              ..trapping_try,
              caught_pure_try,
              @lib.Instruction::drop(),
              @lib.Instruction::return_(),
            ],
          ),
        ),
      ]),
    )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(
        cleaned,
        [
          ..param_try,
          ..trapping_try,
          caught_pure_try,
          @lib.Instruction::drop(),
          @lib.Instruction::return_(),
        ],
      )
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup strips empty zero-result try_tables even with catches" {
  let param_void_typeidx_block_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
  )
  let catching_empty_body = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::try_table(
        @lib.BlockType::void_(),
        [@lib.Catch::all(@lib.LabelIdx::new(0U))],
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(12)),
          @lib.Instruction::drop(),
        ]),
      ),
    ]),
  )
  let catching_trapping_body = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::try_table(
        @lib.BlockType::void_(),
        [@lib.Catch::all(@lib.LabelIdx::new(0U))],
        @lib.Expr::new([@lib.Instruction::unreachable_()]),
      ),
    ]),
  )
  let catching_param_body = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(13)),
      @lib.Instruction::try_table(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
        [@lib.Catch::all(@lib.LabelIdx::new(0U))],
        @lib.Expr::new([]),
      ),
    ]),
  )
  let mod_ = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([param_void_typeidx_block_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            catching_empty_body,
            catching_trapping_body,
            catching_param_body,
            @lib.Instruction::return_(),
          ]),
        ),
      ]),
    )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        catching_trapping_body,
        catching_param_body,
        @lib.Instruction::return_(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}
