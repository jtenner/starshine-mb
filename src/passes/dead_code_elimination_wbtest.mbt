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
test "dead-code-elimination raw candidate summary visits targeted control once" {
  let visits = [0]
  let has_candidate = [false]
  let (_, _, _, _, _, instr_count) = run_hot_pipeline_instr_scan(
    [
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(0U))]),
      ),
    ],
    visit_count=Some(visits),
    dce_candidate=Some(has_candidate),
  )

  @debug.assert_eq(instr_count, 2)
  @debug.assert_eq(visits[0], instr_count)
  assert_false(has_candidate[0])
}

///|
test "dead-code-elimination raw candidate summary distinguishes loop targets" {
  let self_loop_candidate = [false]
  ignore(
    run_hot_pipeline_instr_scan(
      [
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(0U))]),
        ),
      ],
      dce_candidate=Some(self_loop_candidate),
    ),
  )
  assert_false(self_loop_candidate[0])

  let outer_branch_candidate = [false]
  ignore(
    run_hot_pipeline_instr_scan(
      [
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::loop_(
              @lib.BlockType::void_(),
              @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(1U))]),
            ),
          ]),
        ),
      ],
      dce_candidate=Some(outer_branch_candidate),
    ),
  )
  assert_true(outer_branch_candidate[0])
}

///|
test "dead-code-elimination raw candidate summary ignores void final nonfallthrough if" {
  let has_candidate = [false]
  ignore(
    run_hot_pipeline_instr_scan(
      [
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [@lib.Instruction::unreachable_()],
          Some([@lib.Instruction::unreachable_()]),
        ),
      ],
      dce_candidate=Some(has_candidate),
    ),
  )
  assert_false(has_candidate[0])
}

///|
test "dead-code-elimination raw candidate summary distinguishes safe drop regions" {
  let scalar_drop_candidate = [false]
  ignore(
    run_hot_pipeline_instr_scan(
      [@lib.Instruction::i32_const(@lib.I32(1)), @lib.Instruction::drop()],
      dce_candidate=Some(scalar_drop_candidate),
    ),
  )
  assert_false(scalar_drop_candidate[0])

  let structured_drop_candidate = [false]
  ignore(
    run_hot_pipeline_instr_scan(
      [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::if_(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          [@lib.Instruction::i32_const(@lib.I32(2))],
          Some([@lib.Instruction::i32_const(@lib.I32(3))]),
        ),
        @lib.Instruction::drop(),
      ],
      dce_candidate=Some(structured_drop_candidate),
    ),
  )
  assert_true(structured_drop_candidate[0])

  let branch_drop_candidate = [false]
  ignore(
    run_hot_pipeline_instr_scan(
      [
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(0U))]),
        ),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::drop(),
      ],
      dce_candidate=Some(branch_drop_candidate),
    ),
  )
  assert_true(branch_drop_candidate[0])
}

///|
test "dead-code-elimination raw candidate summary admits rewrite boundaries" {
  let cases : Array[Array[@lib.Instruction]] = [
    [@lib.Instruction::return_(), @lib.Instruction::drop()],
    [@lib.Instruction::i32_const(@lib.I32(1)), @lib.Instruction::unreachable_()],
    [
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([@lib.Instruction::unreachable_()]),
      ),
    ],
    [
      @lib.Instruction::loop_(
        @lib.BlockType::void_(),
        @lib.Expr::new([@lib.Instruction::unreachable_()]),
      ),
    ],
    [
      @lib.Instruction::if_(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        [@lib.Instruction::unreachable_()],
        Some([@lib.Instruction::unreachable_()]),
      ),
    ],
    [
      @lib.Instruction::try_table(
        @lib.BlockType::void_(),
        [],
        @lib.Expr::new([@lib.Instruction::unreachable_()]),
      ),
    ],
  ]
  for instrs in cases {
    let has_candidate = [false]
    ignore(
      run_hot_pipeline_instr_scan(instrs, dce_candidate=Some(has_candidate)),
    )
    assert_true(has_candidate[0])
  }
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
test "dead-code-elimination raw skip consumes precomputed scan facts" {
  let mod_ = pass_test_module_from_wat(
    "(module (func (result i32) i32.const 9))",
  )
  let original = run_hot_pipeline_original_func(mod_, @lib.FuncIdx::new(0U))
  let @lib.Func(_, @lib.Expr(instrs)) = original
  let (_, has_structured, has_branches, has_drop, has_dead_tail, _) = run_hot_pipeline_instr_scan(
    instrs,
  )
  assert_true(
    run_hot_pipeline_dce_can_skip_raw_with_facts(
      original,
      @ir.hot_module_context_from_module(mod_),
      @lib.FuncIdx::new(0U),
      has_structured,
      has_branches,
      has_drop,
      has_dead_tail,
    ),
  )
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
