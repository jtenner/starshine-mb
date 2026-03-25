///|
test "ssa destruction lowers diamond phis to predecessor copies" {
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
  let if_id = hot_root_get(func, 0)
  let then_region = hot_region_then_ref(func, if_id)
  let else_region = hot_region_else_ref(func, if_id).unwrap()
  let then_set = hot_region_get(func, then_region, 0)
  let join_drop = hot_root_get(func, 1)
  let join_get = hot_child_get(func, join_drop, 0)
  let cfg = cfg_build(func)
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let ssa = ssa_build_local(func, cfg, dom, liveness, use_def)

  ignore(ssa_destroy_into_hot(func, cfg, ssa))

  assert_eq(hot_local_count(func), 3)
  assert_eq(hot_node_get(func, then_set).imm0, 2)
  assert_eq(hot_region_root_count(func, then_region), 2)
  let then_copy = hot_region_get(func, then_region, 1)
  assert_eq(hot_node_get(func, then_copy).op.to_string(), "LocalSet")
  assert_eq(hot_node_get(func, then_copy).imm0, 1)
  let then_copy_get = hot_child_get(func, then_copy, 0)
  assert_eq(hot_node_get(func, then_copy_get).op.to_string(), "LocalGet")
  assert_eq(hot_node_get(func, then_copy_get).imm0, 2)
  assert_eq(hot_region_root_count(func, else_region), 1)
  assert_eq(hot_node_get(func, join_get).imm0, 1)
}

///|
test "ssa destruction lowers loop-header phis before the backedge and preheader" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let entry_value = hot_build_const_i32(func, @lib.I32(1))
  let entry_set = hot_build_local_set(func, 0, entry_value)
  let loop_id = hot_build_loop(func, @lib.BlockType::void_(), [])
  let loop_label = hot_control_node_label(func, loop_id)
  let loop_get = hot_build_local_get(func, 0)
  let loop_drop = hot_build_drop(func, loop_get)
  let loop_value = hot_build_const_i32(func, @lib.I32(2))
  let loop_set = hot_build_local_set(func, 0, loop_value)
  let cond = hot_build_const_i32(func, @lib.I32(1))
  let loop_br = hot_build_br_if(func, loop_label, cond)
  hot_region_replace_body(func, hot_region_body_ref(func, loop_id), [
    loop_drop, loop_set, loop_br,
  ])
  hot_root_append(func, entry_set)
  hot_root_append(func, loop_id)

  let cfg = cfg_build(func)
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let ssa = ssa_build_local(func, cfg, dom, liveness, use_def)

  ignore(ssa_destroy_into_hot(func, cfg, ssa))

  assert_eq(hot_local_count(func), 3)
  assert_eq(hot_node_get(func, entry_set).imm0, 1)
  assert_eq(hot_root_count(func), 3)
  let preheader_copy = hot_root_get(func, 1)
  assert_eq(hot_node_get(func, preheader_copy).op.to_string(), "LocalSet")
  assert_eq(hot_node_get(func, preheader_copy).imm0, 0)
  let preheader_get = hot_child_get(func, preheader_copy, 0)
  assert_eq(hot_node_get(func, preheader_get).imm0, 1)

  let loop_body = hot_region_body_ref(func, loop_id)
  assert_eq(hot_node_get(func, loop_get).imm0, 0)
  assert_eq(hot_node_get(func, loop_set).imm0, 2)
  assert_eq(hot_region_root_count(func, loop_body), 4)
  let body_copy = hot_region_get(func, loop_body, 2)
  assert_eq(hot_node_get(func, body_copy).op.to_string(), "LocalSet")
  assert_eq(hot_node_get(func, body_copy).imm0, 0)
  let body_get = hot_child_get(func, body_copy, 0)
  assert_eq(hot_node_get(func, body_get).imm0, 2)
  assert_eq(hot_region_get(func, loop_body, 3), loop_br)
}

///|
test "ssa predecessor copy insertion allocates a temp for cycles" {
  let func = HotFunc::new(
    locals=HotLocals::new(locals=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  let nop = hot_build_nop(func)
  hot_root_append(func, nop)
  let cfg = cfg_build(func)
  let block = cfg_block_for_region_root(cfg, HotRegionRef::root(), 0).unwrap()

  ignore(
    ssa_insert_predecessor_copies(
      func,
      HotRegionRef::root(),
      cfg_block_get(cfg, block),
      [HotSsaCopy::new(0, 1), HotSsaCopy::new(1, 0)],
    ),
  )

  assert_eq(hot_local_count(func), 3)
  assert_eq(hot_root_count(func), 4)
  let temp_copy = hot_root_get(func, 1)
  let first_copy = hot_root_get(func, 2)
  let second_copy = hot_root_get(func, 3)
  assert_eq(hot_node_get(func, temp_copy).imm0, 2)
  assert_eq(hot_node_get(func, first_copy).imm0, 0)
  assert_eq(hot_node_get(func, second_copy).imm0, 1)
}
