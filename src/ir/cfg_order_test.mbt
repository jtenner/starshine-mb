///|
fn cfg_order_test_diamond_fixture() -> (HotFunc, HotRegionRef, HotRegionRef) {
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
  let if_id = hot_root_get(func, 0)
  (
    func,
    hot_region_then_ref(func, if_id),
    hot_region_else_ref(func, if_id).unwrap(),
  )
}

///|
test "cfg reverse postorder stays deterministic on a diamond" {
  let (func, then_region, else_region) = cfg_order_test_diamond_fixture()
  let cfg = cfg_build(func)
  let entry = cfg_entry_block(cfg)
  let exit = cfg_exit_block(cfg)
  let if_header = cfg_block_for_region_root(cfg, HotRegionRef::root(), 0).unwrap()
  let continuation = cfg_block_for_region_root(cfg, HotRegionRef::root(), 1).unwrap()
  let then_block = cfg_block_for_region_root(cfg, then_region, 0).unwrap()
  let else_block = cfg_block_for_region_root(cfg, else_region, 0).unwrap()

  assert_eq(cfg_preorder(cfg), [
    entry, if_header, then_block, continuation, exit, else_block,
  ])
  assert_eq(cfg_reverse_postorder(cfg), [
    entry, if_header, else_block, then_block, continuation, exit,
  ])
  assert_eq(cfg_block_worklist_seed(cfg), cfg_reverse_postorder(cfg))
}

///|
test "cfg exceptional-inclusive rpo reaches catch-list entry blocks" {
  let func = cfg_test_try_table_fixture()
  let cfg = cfg_build(func)
  let root_block = cfg_block_for_region_root(cfg, HotRegionRef::root(), 0).unwrap()
  let body_region = hot_region_body_ref(func, hot_root_get(func, 0))
  let try_table_id = hot_region_get(func, body_region, 0)
  let try_table_block = cfg_block_for_node(cfg, try_table_id).unwrap()
  let catch_list_block = cfg_successors(cfg, try_table_block)[1].block
  let try_body_block = cfg_block_for_region_root(
    cfg,
    hot_region_body_ref(func, try_table_id),
    0,
  ).unwrap()
  let body_continuation = cfg_block_for_region_root(cfg, body_region, 1).unwrap()
  let outer_continuation = cfg_successors(cfg, body_continuation)[0].block

  assert_false(cfg_reverse_postorder(cfg).contains(catch_list_block))
  assert_eq(cfg_reverse_postorder_with_exceptions(cfg), [
    cfg_entry_block(cfg),
    root_block,
    try_table_block,
    catch_list_block,
    try_body_block,
    body_continuation,
    outer_continuation,
    cfg_exit_block(cfg),
  ])
}

///|
test "cfg region order keeps direct blocks and root unreachable tails explicit" {
  let func = hot_lift_body(
    @lib.Expr::new([@lib.Instruction::return_(), @lib.Instruction::nop()]),
    HotLocals::new(),
  )
  let cfg = cfg_build(func)
  let return_block = cfg_block_for_region_root(cfg, HotRegionRef::root(), 0).unwrap()
  let unreachable_block = cfg_block_for_region_root(
    cfg,
    HotRegionRef::root(),
    1,
  ).unwrap()

  assert_false(cfg_preorder(cfg).contains(unreachable_block))
  assert_eq(cfg_region_blocks_in_rpo(cfg, HotRegionRef::root()), [
    return_block, unreachable_block,
  ])
}
