///|
test "raw control summary records every label-bearing conditional target" {
  let label = @lib.LabelIdx::new(0U)
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let eq_heap = @lib.HeapType::abs(@lib.AbsHeapType::eq())
  let nullable_any = @lib.RefType::new(true, any_heap)
  let nullable_eq = @lib.RefType::new(true, eq_heap)
  let branches = [
    @lib.Instruction::br_on_null(label),
    @lib.Instruction::br_on_non_null(label),
    @lib.Instruction::br_on_cast(label, true, any_heap, true, eq_heap),
    @lib.Instruction::br_on_cast_fail(label, true, any_heap, true, eq_heap),
    @lib.Instruction::br_on_cast_desc_eq(label, nullable_any, nullable_eq),
    @lib.Instruction::br_on_cast_desc_eq_fail(label, nullable_any, nullable_eq),
  ]
  for branch in branches {
    let state = HotPipelineInstrScanState::new(None)
    let token = hot_pipeline_instr_scan_push_control(state)
    let summary = run_hot_pipeline_instr_scan_impl([branch], state)
    assert_true(summary.has_branches)
    assert_true(state.targeted_controls[token])
    assert_eq(summary.min_branch_target_token, token)
  }
}

///|
test "raw control summary records legacy delegate against surrounding scope" {
  let state = HotPipelineInstrScanState::new(None)
  let outer = hot_pipeline_instr_scan_push_control(state)
  let summary = run_hot_pipeline_instr_scan_impl(
    [
      @lib.Instruction::try_(
        @lib.BlockType::void_(),
        @lib.Expr::new([@lib.Instruction::unreachable_()]),
        [],
        delegate=Some(@lib.LabelIdx::new(0U)),
      ),
    ],
    state,
  )
  assert_true(summary.has_branches)
  assert_true(state.targeted_controls[outer])
  assert_eq(summary.min_branch_target_token, outer)
  assert_eq(state.control_tokens.length(), 1)
}

///|
test "merge-locals call-store guard scans legacy try body and catches" {
  let call = @lib.Instruction::call(@lib.FuncIdx::new(0U))
  let store = @lib.Instruction::i32_store(@lib.MemArg::new(0U, None, 0UL))
  let body_only = [
    @lib.Instruction::try_(
      @lib.BlockType::void_(),
      @lib.Expr::new([call, store]),
      [],
    ),
  ]
  assert_eq(
    run_hot_pipeline_raw_merge_locals_call_store_shape(body_only),
    (true, true),
  )

  let catches_only = [
    @lib.Instruction::try_(@lib.BlockType::void_(), @lib.Expr::new([]), [
      @lib.LegacyCatch::all(@lib.Expr::new([call])),
      @lib.LegacyCatch::all(@lib.Expr::new([store])),
    ]),
  ]
  assert_eq(
    run_hot_pipeline_raw_merge_locals_call_store_shape(catches_only),
    (true, true),
  )
}

///|
test "Vacuum dropped-node workspace reuses storage and isolates generations" {
  let func = @ir.HotFunc::new()
  let value = @ir.hot_build_const_i32(func, @lib.I32(7))
  let replacement = @ir.hot_build_nop(func)
  let workspace = VacuumDroppedNodeWorkspace::new(@ir.hot_node_count(func))
  let initial_state_capacity = workspace.states.capacity()
  let initial_generation_capacity = workspace.generations.capacity()
  assert_true(
    vacuum_can_remove_dropped_node_with_workspace(func, value, workspace),
  )
  let warmed_touched_capacity = workspace.touched.capacity()

  for _ in 0..<128 {
    assert_true(
      vacuum_can_remove_dropped_node_with_workspace(func, value, workspace),
    )
    assert_eq(workspace.touched.length(), 1)
  }
  assert_eq(workspace.states.capacity(), initial_state_capacity)
  assert_eq(workspace.generations.capacity(), initial_generation_capacity)
  assert_eq(workspace.touched.capacity(), warmed_touched_capacity)

  @ir.hot_node_set(func, value, @ir.hot_node_get(func, replacement))
  assert_false(
    vacuum_can_remove_dropped_node_with_workspace(func, value, workspace),
  )
  assert_eq(workspace.touched.length(), 1)
}
