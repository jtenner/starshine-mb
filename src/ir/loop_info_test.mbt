///|
fn loop_info_test_exit_targets(exits : Array[HotLoopExit]) -> Array[BlockId] {
  let out : Array[BlockId] = []
  for exit in exits {
    out.push(exit.edge.block)
  }
  out
}

///|
test "loop info excludes unreachable predecessors of a latch" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (loop (block br 0 nop) i32.const 1 br_if 0)))",
  )
  let cfg = cfg_build(fixture.hot_func)
  let dom = dom_build(cfg)
  let loops = loop_info_build(cfg, dom)
  let mut unreachable_count = 0
  for block_id = 0; block_id < cfg_block_count(cfg); block_id = block_id + 1 {
    if block_id != cfg_entry_block(cfg) && dom_idom(dom, block_id) is None {
      unreachable_count += 1
      assert_eq(loop_for_block(loops, block_id), None)
    }
  }
  assert_true(unreachable_count > 0)
}

///|
test "loop info builds one natural loop with header body latch and exit" {
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
  let dom = dom_build(cfg)
  let info = loop_info_build(cfg, dom)
  let block_id = hot_root_get(func, 0)
  let body_region = hot_region_body_ref(func, block_id)
  let loop_id = hot_region_get(func, body_region, 0)
  let loop_header_block = cfg_block_for_node(cfg, loop_id).unwrap()
  let loop_body = cfg_block_for_region_root(
    cfg,
    hot_region_body_ref(func, loop_id),
    0,
  ).unwrap()
  let continuation = cfg_block_for_region_root(cfg, body_region, 1).unwrap()
  let loop_idx = loop_for_block(info, loop_body).unwrap()

  @debug.assert_eq(loop_header(info, loop_idx), loop_body)
  @debug.assert_eq(loop_blocks(info, loop_idx), [loop_body])
  @debug.assert_eq(loop_latches(info, loop_idx), [loop_body])
  @debug.assert_eq(loop_info_test_exit_targets(loop_exits(info, loop_idx)), [
    continuation,
  ])
  @debug.assert_eq(loop_depth(info, loop_header_block), 0)
  @debug.assert_eq(loop_depth(info, loop_body), 1)
}

///|
test "loop info maps nested loops to the innermost containing header" {
  let func = hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::loop_(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::loop_(
                @lib.BlockType::void_(),
                @lib.Expr::new([
                  @lib.Instruction::i32_const(@lib.I32(1)),
                  @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
                ]),
              ),
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
  let dom = dom_build(cfg)
  let info = loop_info_build(cfg, dom)
  let block_id = hot_root_get(func, 0)
  let outer_region = hot_region_body_ref(func, block_id)
  let outer_loop_id = hot_region_get(func, outer_region, 0)
  let inner_loop_id = hot_region_get(
    func,
    hot_region_body_ref(func, outer_loop_id),
    0,
  )
  let outer_header = cfg_block_for_node(cfg, outer_loop_id).unwrap()
  let inner_header = cfg_block_for_node(cfg, inner_loop_id).unwrap()
  let inner_body = cfg_block_for_region_root(
    cfg,
    hot_region_body_ref(func, inner_loop_id),
    0,
  ).unwrap()
  let outer_latch = cfg_block_for_region_root(
    cfg,
    hot_region_body_ref(func, outer_loop_id),
    1,
  ).unwrap()
  let inner_loop = loop_for_block(info, inner_body).unwrap()
  let outer_loop = loop_for_block(info, outer_latch).unwrap()

  @debug.assert_eq(loop_header(info, outer_loop), inner_header)
  @debug.assert_eq(loop_header(info, inner_loop), inner_body)
  @debug.assert_eq(loop_depth(info, outer_header), 0)
  @debug.assert_eq(loop_depth(info, inner_header), 1)
  @debug.assert_eq(loop_depth(info, inner_body), 2)
  @debug.assert_eq(loop_for_block(info, inner_header), Some(outer_loop))
}

///|
test "loop info records early-exit successors that leave the natural loop body" {
  let func = hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::loop_(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
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
  let dom = dom_build(cfg)
  let info = loop_info_build(cfg, dom)
  let block_id = hot_root_get(func, 0)
  let body_region = hot_region_body_ref(func, block_id)
  let loop_id = hot_region_get(func, body_region, 0)
  let exit_block = cfg_block_for_region_root(cfg, body_region, 1).unwrap()
  let loop_idx = loop_for_block(
    info,
    cfg_block_for_region_root(cfg, hot_region_body_ref(func, loop_id), 0).unwrap(),
  ).unwrap()

  assert_true(
    loop_info_test_exit_targets(loop_exits(info, loop_idx)).contains(exit_block),
  )
}
