///|
fn ssa_local_find_phi_input(
  inputs : Array[HotSsaPhiInput],
  predecessor : BlockId,
) -> HotSsaPhiInput {
  for input in inputs {
    if input.predecessor == predecessor {
      return input
    }
  }
  abort("expected phi input for predecessor \{predecessor}")
}

///|
test "ssa local build inserts a join phi for diamond local merges" {
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
  let then_set = hot_region_get(func, then_region, 0)
  let join_drop = hot_root_get(func, 1)
  let join_get = hot_child_get(func, join_drop, 0)
  let cfg = cfg_build(func)
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let ssa = ssa_build_local(func, cfg, dom, liveness, use_def)
  let then_block = cfg_block_for_region_root(cfg, then_region, 0).unwrap()
  let else_block = cfg_block_for_region_root(
    cfg,
    hot_region_else_ref(func, if_id).unwrap(),
    0,
  ).unwrap()
  let join_block = cfg_block_for_region_root(cfg, HotRegionRef::root(), 1).unwrap()
  let phis = ssa_phis_for_block(ssa, join_block)

  assert_eq(phis.length(), 1)
  let phi_id = phis[0]
  assert_eq(ssa_phi_local(ssa, phi_id), 1)
  assert_eq(
    ssa_value_origin(ssa, ssa_value_for_local_get(ssa, join_get)),
    ssa_phi_def(phi_id),
  )
  let inputs = ssa_phi_inputs(ssa, phi_id)
  assert_eq(inputs.length(), 2)
  let then_input = ssa_local_find_phi_input(inputs, then_block)
  let else_input = ssa_local_find_phi_input(inputs, else_block)
  assert_eq(
    ssa_value_origin(ssa, then_input.value_id),
    ssa_local_set_def(then_set),
  )
  assert_eq(ssa_value_origin(ssa, else_input.value_id), ssa_default_init_def(1))
}

///|
test "ssa local build inserts a loop-carried phi at loop headers" {
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
  let preheader_block = cfg_block_for_region_root(cfg, HotRegionRef::root(), 0).unwrap()
  let loop_header = cfg_block_for_node(cfg, loop_id).unwrap()
  let loop_body = cfg_block_for_region_root(
    cfg,
    hot_region_body_ref(func, loop_id),
    0,
  ).unwrap()
  let phis = ssa_phis_for_block(ssa, loop_header)

  assert_eq(phis.length(), 1)
  let phi_id = phis[0]
  assert_eq(ssa_phi_local(ssa, phi_id), 0)
  assert_eq(
    ssa_value_origin(ssa, ssa_value_for_local_get(ssa, loop_get)),
    ssa_phi_def(phi_id),
  )
  let inputs = ssa_phi_inputs(ssa, phi_id)
  assert_eq(inputs.length(), 2)
  let preheader_input = ssa_local_find_phi_input(inputs, preheader_block)
  let backedge_input = ssa_local_find_phi_input(inputs, loop_body)
  assert_eq(
    ssa_value_origin(ssa, preheader_input.value_id),
    ssa_local_set_def(entry_set),
  )
  assert_eq(
    ssa_value_origin(ssa, backedge_input.value_id),
    ssa_local_set_def(loop_set),
  )
}

///|
test "ssa local build resolves uninitialized locals to default-init entry defs" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let local_get = hot_build_local_get(func, 0)
  hot_root_append(func, hot_build_drop(func, local_get))

  let cfg = cfg_build(func)
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let ssa = ssa_build_local(func, cfg, dom, liveness, use_def)

  assert_eq(
    ssa_value_origin(ssa, ssa_value_for_local_get(ssa, local_get)),
    ssa_default_init_def(0),
  )
}

///|
test "ssa local build records local tee defs for later reads" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let value = hot_build_const_i32(func, @lib.I32(9))
  let tee = hot_build_local_tee(func, 0, value)
  let read = hot_build_local_get(func, 0)
  hot_root_append(func, hot_build_drop(func, tee))
  hot_root_append(func, hot_build_drop(func, read))

  let cfg = cfg_build(func)
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let ssa = ssa_build_local(func, cfg, dom, liveness, use_def)
  let tee_value = ssa_def_for_local_set(ssa, tee)

  assert_eq(ssa_value_origin(ssa, tee_value), ssa_local_tee_def(tee))
  assert_eq(ssa_value_for_local_get(ssa, read), tee_value)
}
