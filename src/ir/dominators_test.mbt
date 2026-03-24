///|
fn dom_test_diamond_fixture() -> (
  HotCfg,
  BlockId,
  BlockId,
  BlockId,
  BlockId,
  BlockId,
) {
  let func = hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [@lib.Instruction::nop()],
        Some([@lib.Instruction::nop()]),
      ),
      @lib.Instruction::nop(),
    ]),
    HotLocals::new(),
  )
  let cfg = cfg_build(func)
  let if_id = hot_root_get(func, 0)
  (
    cfg,
    cfg_block_for_region_root(cfg, HotRegionRef::root(), 0).unwrap(),
    cfg_block_for_region_root(cfg, hot_region_then_ref(func, if_id), 0).unwrap(),
    cfg_block_for_region_root(cfg, hot_region_else_ref(func, if_id).unwrap(), 0).unwrap(),
    cfg_block_for_region_root(cfg, HotRegionRef::root(), 1).unwrap(),
    cfg_exit_block(cfg),
  )
}

///|
test "dominators compute diamond idoms and frontiers" {
  let (cfg, if_header, then_block, else_block, continuation, exit) = dom_test_diamond_fixture()
  let dom = dom_build(cfg)

  assert_eq(dom_idom(dom, cfg_entry_block(cfg)), None)
  assert_eq(dom_idom(dom, if_header), Some(cfg_entry_block(cfg)))
  assert_eq(dom_idom(dom, then_block), Some(if_header))
  assert_eq(dom_idom(dom, else_block), Some(if_header))
  assert_eq(dom_idom(dom, continuation), Some(if_header))
  assert_eq(dom_idom(dom, exit), Some(continuation))
  assert_true(dom_dominates(dom, if_header, continuation))
  assert_true(dom_strictly_dominates(dom, if_header, then_block))
  assert_false(dom_strictly_dominates(dom, then_block, then_block))
  assert_eq(dom_frontier(dom, then_block), [continuation])
  assert_eq(dom_frontier(dom, else_block), [continuation])
  assert_eq(dom_frontier(dom, if_header), [])
}

///|
test "dominators compute loop header self-frontiers from backedges" {
  let func = hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::loop_(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
            ]),
          ),
          @lib.Instruction::nop(),
        ]),
      ),
    ]),
    HotLocals::new(),
  )
  let cfg = cfg_build(func)
  let block_id = hot_root_get(func, 0)
  let body_region = hot_region_body_ref(func, block_id)
  let loop_id = hot_region_get(func, body_region, 0)
  let root_block = cfg_block_for_node(cfg, block_id).unwrap()
  let loop_header = cfg_block_for_node(cfg, loop_id).unwrap()
  let loop_body = cfg_block_for_region_root(
    cfg,
    hot_region_body_ref(func, loop_id),
    0,
  ).unwrap()
  let continuation = cfg_block_for_region_root(cfg, body_region, 1).unwrap()
  let dom = dom_build(cfg)

  assert_eq(dom_idom(dom, loop_header), Some(root_block))
  assert_eq(dom_idom(dom, loop_body), Some(loop_header))
  assert_eq(dom_idom(dom, continuation), Some(loop_body))
  assert_true(dom_dominates(dom, loop_header, continuation))
  assert_eq(dom_frontier(dom, loop_header), [loop_header])
  assert_eq(dom_frontier(dom, loop_body), [loop_header])
}

///|
test "dominators exclude unreachable blocks from dominance queries" {
  let func = hot_lift_body(
    @lib.Expr::new([@lib.Instruction::return_(), @lib.Instruction::nop()]),
    HotLocals::new(),
  )
  let cfg = cfg_build(func)
  let dom = dom_build(cfg)
  let return_block = cfg_block_for_region_root(cfg, HotRegionRef::root(), 0).unwrap()
  let unreachable_block = cfg_block_for_region_root(
    cfg,
    HotRegionRef::root(),
    1,
  ).unwrap()

  assert_eq(dom_idom(dom, return_block), Some(cfg_entry_block(cfg)))
  assert_eq(dom_idom(dom, unreachable_block), None)
  assert_false(dom_dominates(dom, cfg_entry_block(cfg), unreachable_block))
  assert_eq(dom_frontier(dom, unreachable_block), [])
  assert_false(
    dom_children(dom, cfg_entry_block(cfg)).contains(unreachable_block),
  )
}
