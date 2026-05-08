///|
fn[S : @debug.Debug] cfg_test_show_text(value : S) -> String {
  @debug.to_string(value)
}

///|
fn[S : Show] cfg_test_show_array(values : Array[S]) -> Array[String] {
  let out : Array[String] = []
  for value in values {
    out.push(value.to_string())
  }
  out
}

///|
fn cfg_test_boundary_fixture() -> HotFunc {
  hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [
              @lib.Instruction::loop_(
                @lib.BlockType::void_(),
                @lib.Expr::new([@lib.Instruction::nop()]),
              ),
            ],
            Some([@lib.Instruction::return_()]),
          ),
        ]),
      ),
    ]),
    HotLocals::new(),
  )
}

///|
fn cfg_test_builder_ops_fixture() -> Array[HotOp] {
  let func = HotFunc::new()
  let cond = hot_build_const_i32(func, @lib.I32(1))
  let branch_target = hot_control_node_label(
    func,
    hot_build_block(func, @lib.BlockType::void_(), []),
  )
  let exnref = hot_build_ref_null(
    func,
    @lib.RefType::abs(@lib.AbsHeapType::extern_()),
  )

  let block_id = hot_build_block(func, @lib.BlockType::void_(), [])
  let loop_id = hot_build_loop(func, @lib.BlockType::void_(), [])
  let if_id = hot_build_if(
    func,
    @lib.BlockType::void_(),
    cond,
    [],
    else_body=Some([]),
  )
  let try_id = hot_build_try(
    func,
    @lib.BlockType::void_(),
    [],
    catch_body=Some([]),
  )
  let try_table_id = hot_build_try_table(func, @lib.BlockType::void_(), [], [])
  let call_id = hot_build_call(func, 0, [], [])
  let br_if_id = hot_build_br_if(func, branch_target, cond)
  let return_id = hot_build_return(func, [])
  let throw_ref_id = hot_build_throw_ref(func, exnref)
  let delegate_id = hot_build_delegate(func, branch_target)
  let nop_id = hot_build_nop(func)

  [
    hot_node_get(func, block_id).op,
    hot_node_get(func, loop_id).op,
    hot_node_get(func, if_id).op,
    hot_node_get(func, try_id).op,
    hot_node_get(func, try_table_id).op,
    hot_node_get(func, call_id).op,
    hot_node_get(func, br_if_id).op,
    hot_node_get(func, return_id).op,
    hot_node_get(func, throw_ref_id).op,
    hot_node_get(func, delegate_id).op,
    hot_node_get(func, nop_id).op,
  ]
}

///|
test "cfg control successor policy distinguishes current structured control families" {
  let ops = cfg_test_builder_ops_fixture()
  @debug.assert_eq(
    cfg_test_show_text(cfg_control_successor_policy(ops[0])),
    "Some(InlineBodyRegion)",
  )
  @debug.assert_eq(
    cfg_test_show_text(cfg_control_successor_policy(ops[1])),
    "Some(InlineBodyRegion)",
  )
  @debug.assert_eq(
    cfg_test_show_text(cfg_control_successor_policy(ops[2])),
    "Some(SplitThenElse)",
  )
  @debug.assert_eq(
    cfg_test_show_text(cfg_control_successor_policy(ops[3])),
    "Some(SplitBodyCatch)",
  )
  @debug.assert_eq(
    cfg_test_show_text(cfg_control_successor_policy(ops[4])),
    "Some(SplitBodyCatchList)",
  )
  @debug.assert_eq(
    @debug.to_string(cfg_control_successor_policy(ops[5])),
    "None",
  )
}

///|
test "cfg boundary classification marks control entries and terminators" {
  let func = cfg_test_boundary_fixture()
  let block_id = hot_root_get(func, 0)
  let if_id = hot_child_get(func, block_id, 0)
  let then_region = hot_child_get(func, if_id, 1)
  let loop_id = hot_child_get(func, then_region, 0)
  let else_region = hot_child_get(func, if_id, 2)
  let return_id = hot_child_get(func, else_region, 0)

  @debug.assert_eq(
    cfg_test_show_array(cfg_block_boundary_reasons(func, block_id)),
    ["RootEntry", "ControlHeader", "BodyRegionEntry", "Terminator"],
  )
  @debug.assert_eq(
    cfg_test_show_array(cfg_block_boundary_reasons(func, if_id)),
    ["ControlHeader", "ThenRegionEntry", "ElseRegionEntry", "Terminator"],
  )
  @debug.assert_eq(
    cfg_test_show_array(cfg_block_boundary_reasons(func, loop_id)),
    ["ControlHeader", "BodyRegionEntry", "LoopHeader", "Terminator"],
  )
  @debug.assert_eq(
    cfg_test_show_array(cfg_block_boundary_reasons(func, return_id)),
    ["Terminator"],
  )
}

///|
test "cfg terminator edge kinds and exception policies stay explicit" {
  let ops = cfg_test_builder_ops_fixture()
  @debug.assert_eq(cfg_test_show_array(cfg_terminator_edge_kinds(ops[6])), [
    "BranchEdge", "FallthroughEdge",
  ])
  @debug.assert_eq(cfg_test_show_array(cfg_terminator_edge_kinds(ops[7])), [
    "ReturnEdge",
  ])
  @debug.assert_eq(cfg_test_show_array(cfg_terminator_edge_kinds(ops[8])), [
    "ExceptionalEdge",
  ])
  @debug.assert_eq(
    cfg_test_show_text(cfg_exception_target_policy(ops[4])),
    "ToCatchListRegion",
  )
  @debug.assert_eq(
    cfg_test_show_text(cfg_exception_target_policy(ops[9])),
    "DelegateToTarget",
  )
  @debug.assert_eq(
    cfg_test_show_text(cfg_exception_target_policy(ops[10])),
    "NoExceptionEdge",
  )
}
