///|
test "liveness keeps join uses live across a diamond" {
  let func = hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        ],
        Some([@lib.Instruction::nop()]),
      ),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::drop(),
    ]),
    HotLocals::new(params=[@lib.ValType::i32()], locals=[@lib.ValType::i32()]),
  )
  let cfg = cfg_build(func)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let if_id = hot_root_get(func, 0)
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
  let join_block = cfg_block_for_region_root(cfg, HotRegionRef::root(), 1).unwrap()

  assert_true(local_live_in(liveness, join_block, 1))
  assert_false(local_live_out(liveness, join_block, 1))
  assert_true(local_live_out(liveness, then_block, 1))
  assert_false(local_live_in(liveness, then_block, 1))
  assert_true(local_live_out(liveness, else_block, 1))
  assert_true(local_live_in(liveness, else_block, 1))
}

///|
test "liveness keeps loop-carried locals live around the backedge" {
  let func = hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::loop_(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
              @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
            ]),
          ),
          @lib.Instruction::nop(),
        ]),
      ),
    ]),
    HotLocals::new(params=[@lib.ValType::i32()], locals=[@lib.ValType::i32()]),
  )
  let cfg = cfg_build(func)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
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

  assert_true(local_live_in(liveness, loop_body, 1))
  assert_true(local_live_out(liveness, loop_body, 1))
  assert_true(local_live_out(liveness, loop_header, 1))
  assert_false(local_live_in(liveness, continuation, 1))
}

///|
test "liveness v1 ignores exceptional successors for live-out propagation" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let throw_ = hot_build_throw(func, @lib.TagIdx::new(0U), [])
  let catch_get = hot_build_local_get(func, 1)
  let catch_drop = hot_build_drop(func, catch_get)
  let try_id = hot_build_try(
    func,
    @lib.BlockType::void_(),
    [throw_],
    catch_body=Some([catch_drop]),
  )
  hot_root_append(func, try_id)

  let cfg = cfg_build(func)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let body_block = cfg_block_for_region_root(
    cfg,
    hot_region_body_ref(func, try_id),
    0,
  ).unwrap()
  let catch_block = cfg_block_for_region_root(
    cfg,
    hot_region_catch_ref(func, try_id).unwrap(),
    0,
  ).unwrap()

  assert_true(local_live_in(liveness, catch_block, 1))
  assert_false(local_live_out(liveness, body_block, 1))
}
