///|
fn use_def_test_show_sites(sites : Array[HotUseSite]) -> Array[String] {
  let out : Array[String] = []
  for site in sites {
    out.push(site.to_string())
  }
  out
}

///|
test "use-def tracks child-edge use sites for expression trees" {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let local_get = hot_build_local_get(func, 0)
  let const_ = hot_build_const_i32(func, @lib.I32(7))
  let add = hot_build_binary(func, @lib.ValType::i32(), local_get, const_)
  hot_root_append(func, add)

  let use_def = use_def_build(func)

  assert_eq(use_def_test_show_sites(node_use_sites(use_def, local_get)), [
    "{user: \{add}, slot: 0, kind: ChildUseSlot}",
  ])
  assert_eq(node_use_count(use_def, const_), 1)
  assert_eq(use_def_test_show_sites(node_use_sites(use_def, add)), [
    "{user: -1, slot: 0, kind: RootUseSlot}",
  ])
}

///|
test "use-def distinguishes root-slot uses from child-slot uses" {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let local_get = hot_build_local_get(func, 0)
  let block_id = hot_build_block(func, @lib.BlockType::void_(), [local_get])
  hot_root_append(func, block_id)

  let use_def = use_def_build(func)

  assert_eq(use_def_test_show_sites(node_use_sites(use_def, local_get)), [
    "{user: \{block_id}, slot: 0, kind: RootUseSlot}",
  ])
  assert_eq(use_def_test_show_sites(node_use_sites(use_def, block_id)), [
    "{user: -1, slot: 0, kind: RootUseSlot}",
  ])
}

///|
test "use-def builds block-local defs and uses across a CFG join" {
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
    ]),
    HotLocals::new(params=[@lib.ValType::i32()], locals=[@lib.ValType::i32()]),
  )
  let cfg = cfg_build(func)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let if_id = hot_root_get(func, 0)
  let then_block = cfg_block_for_region_root(
    cfg,
    hot_region_then_ref(func, if_id),
    0,
  ).unwrap()
  let join_block = cfg_block_for_region_root(cfg, HotRegionRef::root(), 1).unwrap()
  let local_get = hot_root_get(func, 1)
  let local_set = hot_region_get(func, hot_region_then_ref(func, if_id), 0)

  assert_true(bitset_contains(block_local_defs(use_def, then_block), 1))
  assert_false(bitset_contains(block_local_uses(use_def, then_block), 1))
  assert_false(bitset_contains(block_local_defs(use_def, join_block), 1))
  assert_true(bitset_contains(block_local_uses(use_def, join_block), 1))
  assert_eq(local_read_nodes(use_def, 1), [local_get])
  assert_eq(local_write_nodes(use_def, 1), [local_set])
}
