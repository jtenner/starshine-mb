///|
fn postdom_test_shared_exit_fixture() -> (
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
test "postdominators compute shared-exit ipdoms and frontiers" {
  let (cfg, if_header, then_block, else_block, continuation, exit) = postdom_test_shared_exit_fixture()
  let postdom = postdom_build(cfg)

  assert_eq(postdom_ipdom(postdom, exit), None)
  assert_eq(postdom_ipdom(postdom, continuation), Some(exit))
  assert_eq(postdom_ipdom(postdom, if_header), Some(continuation))
  assert_eq(postdom_ipdom(postdom, then_block), Some(continuation))
  assert_eq(postdom_ipdom(postdom, else_block), Some(continuation))
  assert_true(postdom_postdominates(postdom, continuation, if_header))
  assert_true(postdom_postdominates(postdom, exit, then_block))
  assert_eq(postdom_frontier(postdom, then_block), [if_header])
  assert_eq(postdom_frontier(postdom, else_block), [if_header])
}

///|
test "postdominators keep return and exceptional exits separate" {
  let func = HotFunc::new()
  let condition = hot_build_const_i32(func, @lib.I32(1))
  let return_ = hot_build_return(func, [])
  let throw_ = hot_build_throw(func, @lib.TagIdx::new(0U), [])
  let if_id = hot_build_if(
    func,
    @lib.BlockType::void_(),
    condition,
    [return_],
    else_body=Some([throw_]),
  )
  hot_root_append(func, if_id)
  let cfg = cfg_build(func)
  let postdom = postdom_build(cfg)
  let then_block = cfg_block_for_region_root(
    cfg,
    hot_region_then_ref(func, if_id),
    0,
  ).unwrap()
  let else_block = cfg_block_for_region_root(
    cfg,
    hot_region_else_ref(func, if_id).unwrap(),
    0,
  ).unwrap()
  let exceptional_exit = cfg_exceptional_exit_block(cfg).unwrap()
  let if_header = cfg_block_for_region_root(cfg, HotRegionRef::root(), 0).unwrap()

  assert_eq(postdom_ipdom(postdom, cfg_exit_block(cfg)), None)
  assert_eq(postdom_ipdom(postdom, exceptional_exit), None)
  assert_eq(postdom_ipdom(postdom, then_block), Some(cfg_exit_block(cfg)))
  assert_eq(postdom_ipdom(postdom, else_block), Some(exceptional_exit))
  assert_eq(postdom_ipdom(postdom, if_header), None)
  assert_true(postdom_postdominates(postdom, cfg_exit_block(cfg), then_block))
  assert_true(postdom_postdominates(postdom, exceptional_exit, else_block))
  assert_false(postdom_postdominates(postdom, cfg_exit_block(cfg), if_header))
}

///|
test "postdominators make loop side-exit policy explicit" {
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
  let loop_header = cfg_block_for_node(cfg, loop_id).unwrap()
  let loop_body = cfg_block_for_region_root(
    cfg,
    hot_region_body_ref(func, loop_id),
    0,
  ).unwrap()
  let continuation = cfg_block_for_region_root(cfg, body_region, 1).unwrap()
  let postdom = postdom_build(cfg)

  assert_true(postdom_postdominates(postdom, cfg_exit_block(cfg), continuation))
  assert_true(postdom_postdominates(postdom, continuation, loop_body))
  assert_true(postdom_postdominates(postdom, continuation, loop_header))
}
