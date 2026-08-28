///|
test "dead-code-elimination memoizes absent unreachable children across shared DAGs" {
  let func = @ir.HotFunc::new()
  let mut value = @ir.hot_build_const_i32(func, @lib.I32(1))
  for _ in 0..<16 {
    value = @ir.hot_build_select(
      func,
      @lib.ValType::i32(),
      value,
      value,
      @ir.hot_build_const_i32(func, @lib.I32(0)),
    )
  }
  let original_node_count = @ir.hot_node_count(func)
  let visits = [0]
  let cache = DeadCodeEliminationNodeUseCache::new(
    func,
    first_unreachable_visits=Some(visits),
  )

  match
    dead_code_elimination_collect_first_unreachable_child_cleanup(
      cache, func, value,
    ) {
    None => ()
    Some(_) => fail("expected shared DAG to contain no unreachable child")
  }
  @debug.assert_eq(@ir.hot_node_count(func), original_node_count)
  assert_true(visits[0] <= original_node_count)
}

///|
test "dead-code-elimination raw instruction summary visits nested control once" {
  let mut instrs : Array[@lib.Instruction] = [
    @lib.Instruction::i32_const(@lib.I32(1)),
  ]
  for _ in 0..<64 {
    instrs = [
      @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(instrs)),
    ]
  }
  let visits = [0]
  let (_, has_structured, _, _, _, instr_count) = run_hot_pipeline_instr_scan(
    instrs,
    visit_count=Some(visits),
  )

  assert_true(has_structured)
  @debug.assert_eq(instr_count, 65)
  @debug.assert_eq(visits[0], instr_count)
}

///|
test "dead-code-elimination raw summary records dead drops after nonfallthrough" {
  let dead_drop = [false]
  ignore(
    run_hot_pipeline_instr_scan(
      [@lib.Instruction::return_(), @lib.Instruction::drop()],
      dead_drop_after_nonfallthrough=Some(dead_drop),
    ),
  )
  assert_true(dead_drop[0])

  let live_drop = [false]
  ignore(
    run_hot_pipeline_instr_scan(
      [@lib.Instruction::i32_const(@lib.I32(1)), @lib.Instruction::drop()],
      dead_drop_after_nonfallthrough=Some(live_drop),
    ),
  )
  assert_false(live_drop[0])
}

///|
test "dead-code-elimination caches unchanged lowering admission by function" {
  let state = HotPipelineModuleState::new()
  let func_idx = @lib.FuncIdx::new(17U)
  @debug.assert_eq(
    run_hot_pipeline_dce_cached_requires_unchanged_lowering(state, func_idx),
    None,
  )
  run_hot_pipeline_dce_record_requires_unchanged_lowering(state, func_idx, true)
  @debug.assert_eq(
    run_hot_pipeline_dce_cached_requires_unchanged_lowering(state, func_idx),
    Some(true),
  )
}
