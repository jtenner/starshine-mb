///|
test "CFG includes conditional operand branches before their local destination" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  let saved = hot_build_local_tee(func, 1, hot_build_local_get(func, 0))
  let then_get = hot_build_local_get(func, 1)
  let conditional = hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    saved,
    [
      hot_build_local_set(func, 0, hot_build_const_i32(func, @lib.I32(9))),
      then_get,
    ],
    else_body=Some([hot_build_const_i32(func, @lib.I32(5))]),
  )
  let destination = hot_build_local_set(func, 2, conditional)
  hot_root_append(func, destination)
  hot_root_append(func, hot_build_drop(func, hot_build_local_get(func, 2)))
  let cfg = cfg_build(func, expand_operand_control=true)
  assert_true(cfg_block_for_node(cfg, then_get) != None)
  let then_block = cfg_block_for_node(cfg, then_get).unwrap()
  let destination_block = cfg_block_for_node(cfg, destination).unwrap()
  assert_true(then_block != destination_block)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let live = liveness_build(cfg, use_def)
  assert_true(local_live_in(live, then_block, 1))
  assert_true(!local_live_in(live, destination_block, 1))
}

///|
test "expanded CFG visits a dropped conditional once" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let then_write = hot_build_local_set(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  let conditional = hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    hot_build_local_get(func, 0),
    [then_write, hot_build_local_get(func, 1)],
    else_body=Some([hot_build_const_i32(func, @lib.I32(5))]),
  )
  let drop = hot_build_drop(func, conditional)
  let final_read = hot_build_local_get(func, 1)
  hot_root_append(func, drop)
  hot_root_append(func, hot_build_drop(func, final_read))
  let cfg = cfg_build(func, expand_operand_control=true)
  let drop_block = cfg_block_for_node(cfg, drop).unwrap()
  let conditional_block = cfg_block_for_node(cfg, conditional).unwrap()
  assert_true(drop_block != conditional_block)
  assert_eq(cfg_successors(cfg, conditional_block).length(), 2)
  assert_eq(cfg_successors(cfg, drop_block).length(), 1)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let live = liveness_build(cfg, use_def)
  assert_true(local_live_in(live, drop_block, 1))
  assert_eq(local_write_block_ids(use_def, 1).length(), 1)
}
