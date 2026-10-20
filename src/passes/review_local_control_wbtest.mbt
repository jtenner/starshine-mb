///|
test "review local compaction remaps protected and caught legacy try accesses" {
  let local = @lib.LocalIdx::new(2U)
  let accesses = [
    @lib.Instruction::local_get(local),
    @lib.Instruction::local_set(local),
    @lib.Instruction::local_tee(local),
  ]
  let legacy = @lib.Instruction::try_(
    @lib.BlockType::void_(),
    @lib.Expr::new(accesses),
    [@lib.LegacyCatch::all(@lib.Expr::new(accesses))],
  )
  let expected = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
  ]
  match run_hot_pipeline_raw_compact_rewrite_local_refs([legacy], [0, -1, 1]) {
    [@lib.Try(_, @lib.Expr(body), [@lib.LegacyCatchAll(@lib.Expr(caught))], _)] => {
      @debug.assert_eq(body, expected)
      @debug.assert_eq(caught, expected)
    }
    _ => fail("expected a legacy try with remapped accesses")
  }
}

///|
test "review appended local ordering includes legacy protected and caught reads" {
  let legacy = @lib.Instruction::try_(
    @lib.BlockType::void_(),
    @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(3U))]),
    [
      @lib.LegacyCatch::all(
        @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(2U))]),
      ),
    ],
  )
  let ranks = Array::make(4, -1)
  assert_eq(
    run_hot_pipeline_raw_note_appended_local_first_refs([legacy], 2, ranks, 0),
    2,
  )
  @debug.assert_eq(ranks, [-1, -1, 1, 0])
  assert_true(run_hot_pipeline_raw_instrs_reference_local([legacy], 3))
  assert_true(run_hot_pipeline_raw_instrs_reference_local([legacy], 2))
}

///|
test "review vacuum includes effectful typed if entry operands" {
  let module_ = pass_test_module_from_wat(
    "(module (import \"env\" \"effect\" (func $effect (result i32))) (func (param i32) (result i32) call $effect local.get 0 if (param i32) (result i32) drop i32.const 5 else drop i32.const 6 end))",
  )
  let func = @ir.hot_lift_func(module_, @lib.FuncIdx::new(1U))
  let root = @ir.hot_region_get(func, @ir.HotRegionRef::root(), 0)
  assert_true(@ir.hot_node_get(func, root).op is @ir.HotOp::If)
  let workspace = VacuumDroppedNodeWorkspace::new(@ir.hot_node_count(func))
  assert_false(
    vacuum_can_remove_dropped_node_with_workspace(func, root, workspace),
  )
}

///|
test "review vacuum includes effectful typed block entry operands" {
  let module_ = pass_test_module_from_wat(
    "(module (import \"env\" \"effect\" (func $effect (result i32))) (func (result i32) i32.const 0 call $effect block (param i32 i32) (result i32) i32.const 5 br 0 end))",
  )
  let func = @ir.hot_lift_func(module_, @lib.FuncIdx::new(1U))
  let root = @ir.hot_region_get(func, @ir.HotRegionRef::root(), 0)
  assert_true(@ir.hot_node_get(func, root).op is @ir.HotOp::Block)
  let workspace = VacuumDroppedNodeWorkspace::new(@ir.hot_node_count(func))
  assert_false(
    vacuum_can_remove_dropped_node_with_workspace(func, root, workspace),
  )
}

///|
test "review vacuum rebases legacy delegate in its surrounding scope" {
  let legacy = @lib.Instruction::try_(
    @lib.BlockType::void_(),
    @lib.Expr::new([@lib.Instruction::unreachable_()]),
    [],
    delegate=Some(@lib.LabelIdx::new(2U)),
  )
  assert_false(run_hot_pipeline_raw_vacuum_instr_targets_owner(legacy, 0))
  assert_true(run_hot_pipeline_raw_vacuum_instr_targets_owner(legacy, 2))
  match run_hot_pipeline_raw_vacuum_rebase_outer_instr(legacy, 0) {
    @lib.Try(_, _, _, Some(@lib.LabelIdx(1U))) => ()
    _ => fail("expected outer delegate depth to decrease after owner removal")
  }
}

///|
test "review vacuum rejects removal of a legacy delegate target frame" {
  // Removing this frame is unsupported while the delegate still targets it.
  let targeted = @lib.Instruction::try_(
    @lib.BlockType::void_(),
    @lib.Expr::new([@lib.Instruction::unreachable_()]),
    [],
    delegate=Some(@lib.LabelIdx::new(0U)),
  )
  assert_true(
    run_hot_pipeline_raw_vacuum_rebase_removable_outer_body([targeted], 0).is_none(),
  )
  let outer = @lib.Instruction::try_(
    @lib.BlockType::void_(),
    @lib.Expr::new([@lib.Instruction::unreachable_()]),
    [],
    delegate=Some(@lib.LabelIdx::new(1U)),
  )
  match
    run_hot_pipeline_raw_vacuum_rebase_removable_outer_body([outer], 0).unwrap() {
    [@lib.Try(_, _, _, Some(@lib.LabelIdx(0U)))] => ()
    _ => fail("expected the delegate to keep its outer target")
  }
}

///|
test "review wrapper branch detection visits legacy protected and caught bodies" {
  let branch = @lib.Instruction::br(@lib.LabelIdx::new(1U))
  for
    legacy in [
      @lib.Instruction::try_(
        @lib.BlockType::void_(),
        @lib.Expr::new([branch]),
        [],
      ),
      @lib.Instruction::try_(@lib.BlockType::void_(), @lib.Expr::new([]), [
        @lib.LegacyCatch::all(@lib.Expr::new([branch])),
      ]),
    ] {
    assert_true(run_hot_pipeline_raw_branch_targets_depth([legacy], 0U))
  }
}

///|
test "review frame removal rejects a catch that still targets its owner" {
  let input = pass_test_module_from_wat(
    "(module (func block try_table (catch_all 0) end end))",
  )
  let @lib.Func(_, @lib.Expr(roots)) = input.code_sec.unwrap().0[0]
  let body = match roots[0] {
    @lib.Block(_, @lib.Expr(body)) => body
    _ => fail("expected catch target owner")
  }
  assert_true(run_hot_pipeline_raw_vacuum_body_targets_owner(body, 0))
  // This frame cannot be removed while the exception edge still targets it.
  assert_true(
    run_hot_pipeline_raw_vacuum_rebase_removable_outer_body(body, 0).is_none(),
  )
}

///|
test "review loop proxy priorities visit legacy protected and caught locals" {
  let priorities = Array::make(4, false)
  fn proxy(local : UInt32) -> Array[@lib.Instruction] {
    let index = @lib.LocalIdx::new(local)
    [
      @lib.Instruction::local_set(index),
      @lib.Instruction::loop_(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::try_(
            @lib.BlockType::void_(),
            @lib.Expr::new([@lib.Instruction::local_get(index)]),
            [],
          ),
        ]),
      ),
    ]
  }
  let legacy = @lib.Instruction::try_(
    @lib.BlockType::void_(),
    @lib.Expr::new(proxy(2U)),
    [@lib.LegacyCatch::all(@lib.Expr::new(proxy(3U)))],
  )
  run_hot_pipeline_raw_note_typed_loop_proxy_scratch_locals(
    [legacy],
    2,
    priorities,
  )
  @debug.assert_eq(priorities, [false, false, true, true])
}

///|
test "review frame removal preserves resume handler owner labels" {
  // A resume edge to the removed frame makes this candidate unsupported.
  let targeted = @lib.Instruction::resume_(@lib.TypeIdx::new(0U), [
    @lib.ResumeHandler::on_label(@lib.TagIdx::new(0U), @lib.LabelIdx::new(0U)),
  ])
  assert_true(
    run_hot_pipeline_raw_vacuum_rebase_removable_outer_body([targeted], 0).is_none(),
  )
  let outer = @lib.Instruction::resume_(@lib.TypeIdx::new(0U), [
    @lib.ResumeHandler::on_label(@lib.TagIdx::new(0U), @lib.LabelIdx::new(1U)),
  ])
  match
    run_hot_pipeline_raw_vacuum_rebase_removable_outer_body([outer], 0).unwrap() {
    [@lib.Resume(_, [@lib.ResumeOnLabel(_, @lib.LabelIdx(0U))])] => ()
    _ => fail("expected the resume handler to keep its outer target")
  }
}
