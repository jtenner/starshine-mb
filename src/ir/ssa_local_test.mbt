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
fn ssa_local_has_phi_input_use(
  uses : Array[HotSsaUseOrigin],
  expected_phi : PhiId,
  expected_predecessor : BlockId,
) -> Bool {
  for use_item in uses {
    match use_item {
      HotSsaUseOrigin::PhiInputUse(phi_id, predecessor) =>
        if phi_id == expected_phi && predecessor == expected_predecessor {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn ssa_local_has_local_get_use(
  uses : Array[HotSsaUseOrigin],
  expected_node : NodeId,
) -> Bool {
  for use_item in uses {
    match use_item {
      HotSsaUseOrigin::LocalGetUse(node_id) =>
        if node_id == expected_node {
          return true
        }
      _ => ()
    }
  }
  false
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

  @debug.assert_eq(phis.length(), 1)
  let phi_id = phis[0]
  @debug.assert_eq(ssa_phi_local(ssa, phi_id), 1)
  @debug.assert_eq(
    ssa_value_origin(ssa, ssa_value_for_local_get(ssa, join_get)),
    ssa_phi_def(phi_id),
  )
  let inputs = ssa_phi_inputs(ssa, phi_id)
  @debug.assert_eq(inputs.length(), 2)
  let then_input = ssa_local_find_phi_input(inputs, then_block)
  let else_input = ssa_local_find_phi_input(inputs, else_block)
  @debug.assert_eq(
    ssa_value_origin(ssa, then_input.value_id),
    ssa_local_set_def(then_set),
  )
  @debug.assert_eq(
    ssa_value_origin(ssa, else_input.value_id),
    ssa_default_init_def(1),
  )
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

  @debug.assert_eq(phis.length(), 1)
  let phi_id = phis[0]
  @debug.assert_eq(ssa_phi_local(ssa, phi_id), 0)
  @debug.assert_eq(
    ssa_value_origin(ssa, ssa_value_for_local_get(ssa, loop_get)),
    ssa_phi_def(phi_id),
  )
  let inputs = ssa_phi_inputs(ssa, phi_id)
  @debug.assert_eq(inputs.length(), 2)
  let preheader_input = ssa_local_find_phi_input(inputs, preheader_block)
  let backedge_input = ssa_local_find_phi_input(inputs, loop_body)
  @debug.assert_eq(
    ssa_value_origin(ssa, preheader_input.value_id),
    ssa_local_set_def(entry_set),
  )
  @debug.assert_eq(
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

  @debug.assert_eq(
    ssa_value_origin(ssa, ssa_value_for_local_get(ssa, local_get)),
    ssa_default_init_def(0),
  )
}

///|
test "ssa local build assigns value types for params defaults writes and phis" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i64()], locals=[
      @lib.ValType::f64(),
    ]),
  )
  let condition = hot_build_local_get(func, 0)
  let then_set = hot_build_local_set(
    func,
    1,
    hot_build_const_f64(func, @lib.F64(7.0)),
  )
  let result_if = hot_build_if(
    func,
    @lib.BlockType::void_(),
    condition,
    [then_set],
    else_body=Some([hot_build_nop(func)]),
  )
  let final_get = hot_build_local_get(func, 1)
  hot_root_append(func, result_if)
  hot_root_append(func, hot_build_drop(func, final_get))

  let cfg = cfg_build(func)
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let ssa = ssa_build_local(func, cfg, dom, liveness, use_def)
  let join_block = cfg_block_for_region_root(cfg, HotRegionRef::root(), 1).unwrap()
  let phis = ssa_phis_for_block(ssa, join_block)

  @debug.assert_eq(ssa_value_type(ssa, ssa.entry_defs[0]), @lib.ValType::i64())
  @debug.assert_eq(ssa_value_type(ssa, ssa.entry_defs[1]), @lib.ValType::f64())
  @debug.assert_eq(
    ssa_value_type(ssa, ssa_def_for_local_set(ssa, then_set)),
    @lib.ValType::f64(),
  )
  @debug.assert_eq(phis.length(), 1)
  @debug.assert_eq(
    ssa_value_type(ssa, ssa_value_for_local_get(ssa, final_get)),
    @lib.ValType::f64(),
  )
  @debug.assert_eq(
    ssa_value_origin(ssa, ssa_value_for_local_get(ssa, final_get)),
    ssa_phi_def(phis[0]),
  )
}

///|
test "ssa local build carries dominating writes into both if arms without phis" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let dominating_set = hot_build_local_set(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(11)),
  )
  let then_get = hot_build_local_get(func, 1)
  let else_get = hot_build_local_get(func, 1)
  let result_if = hot_build_if(
    func,
    @lib.BlockType::void_(),
    hot_build_local_get(func, 0),
    [hot_build_drop(func, then_get)],
    else_body=Some([hot_build_drop(func, else_get)]),
  )
  hot_root_append(func, dominating_set)
  hot_root_append(func, result_if)

  let cfg = cfg_build(func)
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let ssa = ssa_build_local(func, cfg, dom, liveness, use_def)

  @debug.assert_eq(ssa.phis.length(), 0)
  @debug.assert_eq(
    ssa_value_for_local_get(ssa, then_get),
    ssa_def_for_local_set(ssa, dominating_set),
  )
  @debug.assert_eq(
    ssa_value_for_local_get(ssa, else_get),
    ssa_def_for_local_set(ssa, dominating_set),
  )
}

///|
test "ssa local build renames locals inside drop operand result-if arms" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let condition = hot_build_local_get(func, 0)
  let then_set = hot_build_local_set(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  let then_get = hot_build_local_get(func, 1)
  let else_set = hot_build_local_set(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(9)),
  )
  let else_get = hot_build_local_get(func, 1)
  let result_if = hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    condition,
    [then_set, then_get],
    else_body=Some([else_set, else_get]),
  )
  let drop = hot_build_drop(func, result_if)
  let final_get = hot_build_local_get(func, 1)
  hot_root_append(func, drop)
  hot_root_append(func, hot_build_drop(func, final_get))

  let cfg = cfg_build(func)
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let ssa = ssa_build_local(func, cfg, dom, liveness, use_def)
  let then_value = ssa_def_for_local_set(ssa, then_set)
  let else_value = ssa_def_for_local_set(ssa, else_set)
  let final_value = ssa_value_for_local_get(ssa, final_get)

  assert_false(final_value == then_value)
  assert_false(final_value == else_value)
  @debug.assert_eq(
    ssa_value_origin(ssa, ssa_value_for_local_get(ssa, then_get)),
    ssa_local_set_def(then_set),
  )
  @debug.assert_eq(
    ssa_value_origin(ssa, ssa_value_for_local_get(ssa, else_get)),
    ssa_local_set_def(else_set),
  )
  let entry_block = cfg_entry_block(cfg)
  let next_roots_block = cfg_block_for_region_root(cfg, HotRegionRef::root(), 1).unwrap()
  assert_false(entry_block == next_roots_block)
  let phis = ssa_phis_for_block(ssa, next_roots_block)
  @debug.assert_eq(phis.length(), 1)
  let phi_id = phis[0]
  @debug.assert_eq(ssa_phi_local(ssa, phi_id), 1)
  let inputs = ssa_phi_inputs(ssa, phi_id)
  @debug.assert_eq(inputs.length(), 2)
}

///|
fn ssa_local_test_drop_result_if_scalar_phi(
  result_type : @lib.ValType,
  build_then_const : (HotFunc) -> NodeId,
  build_else_const : (HotFunc) -> NodeId,
) -> Unit raise {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[result_type]),
  )
  let condition = hot_build_local_get(func, 0)
  let then_set = hot_build_local_set(func, 1, build_then_const(func))
  let then_get = hot_build_local_get(func, 1)
  let else_set = hot_build_local_set(func, 1, build_else_const(func))
  let else_get = hot_build_local_get(func, 1)
  let result_if = hot_build_if(
    func,
    @lib.BlockType::val_type(result_type),
    condition,
    [then_set, then_get],
    else_body=Some([else_set, else_get]),
  )
  let drop = hot_build_drop(func, result_if)
  let final_get = hot_build_local_get(func, 1)
  hot_root_append(func, drop)
  hot_root_append(func, hot_build_drop(func, final_get))

  let cfg = cfg_build(func)
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let ssa = ssa_build_local(func, cfg, dom, liveness, use_def)
  let then_value = ssa_def_for_local_set(ssa, then_set)
  let else_value = ssa_def_for_local_set(ssa, else_set)
  let final_value = ssa_value_for_local_get(ssa, final_get)

  assert_false(final_value == then_value)
  assert_false(final_value == else_value)
  let next_roots_block = cfg_block_for_region_root(cfg, HotRegionRef::root(), 1).unwrap()
  let phis = ssa_phis_for_block(ssa, next_roots_block)
  @debug.assert_eq(phis.length(), 1)
  @debug.assert_eq(ssa_phi_local(ssa, phis[0]), 1)
  @debug.assert_eq(ssa_phi_inputs(ssa, phis[0]).length(), 2)
}

///|
test "ssa local build renames locals inside scalar drop operand result-if arms" {
  ssa_local_test_drop_result_if_scalar_phi(
    @lib.ValType::i64(),
    fn(func) { hot_build_const_i64(func, @lib.I64(7L)) },
    fn(func) { hot_build_const_i64(func, @lib.I64(9L)) },
  )
  ssa_local_test_drop_result_if_scalar_phi(
    @lib.ValType::f32(),
    fn(func) { hot_build_const_f32(func, @lib.F32(7.0)) },
    fn(func) { hot_build_const_f32(func, @lib.F32(9.0)) },
  )
  ssa_local_test_drop_result_if_scalar_phi(
    @lib.ValType::f64(),
    fn(func) { hot_build_const_f64(func, @lib.F64(7.0)) },
    fn(func) { hot_build_const_f64(func, @lib.F64(9.0)) },
  )
}

///|
test "ssa local build renames condition local writes before drop operand result-if arms" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let condition = hot_build_local_tee(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(1)),
  )
  let then_set = hot_build_local_set(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  let then_get = hot_build_local_get(func, 1)
  let else_set = hot_build_local_set(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(9)),
  )
  let else_get = hot_build_local_get(func, 1)
  let result_if = hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    condition,
    [then_set, then_get],
    else_body=Some([else_set, else_get]),
  )
  let drop = hot_build_drop(func, result_if)
  let final_get = hot_build_local_get(func, 1)
  hot_root_append(func, drop)
  hot_root_append(func, hot_build_drop(func, final_get))

  let cfg = cfg_build(func)
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let ssa = ssa_build_local(func, cfg, dom, liveness, use_def)
  let condition_value = ssa_def_for_local_set(ssa, condition)
  let then_value = ssa_def_for_local_set(ssa, then_set)
  let else_value = ssa_def_for_local_set(ssa, else_set)
  let final_value = ssa_value_for_local_get(ssa, final_get)

  @debug.assert_eq(
    ssa_value_origin(ssa, condition_value),
    ssa_local_tee_def(condition),
  )
  assert_false(final_value == condition_value)
  assert_false(final_value == then_value)
  assert_false(final_value == else_value)
  let drop_block = cfg_block_for_node(cfg, drop).unwrap()
  let writes = local_write_block_ids(use_def, 1)
  assert_true(
    writes.length() >= 2,
    msg="expected condition and arm local writes",
  )
  @debug.assert_eq(writes[0], drop_block)
}

///|
test "ssa local build carries condition-written local into then and else arms" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  let condition = hot_build_local_tee(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(4)),
  )
  let then_set = hot_build_local_set(func, 2, hot_build_local_get(func, 1))
  let then_get = hot_build_local_get(func, 2)
  let else_set = hot_build_local_set(
    func,
    2,
    hot_build_const_i32(func, @lib.I32(2)),
  )
  let else_get = hot_build_local_get(func, 2)
  let result_if = hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    condition,
    [then_set, then_get],
    else_body=Some([else_set, else_get]),
  )
  let drop = hot_build_drop(func, result_if)
  let final_get_1 = hot_build_local_get(func, 1)
  let final_get_2 = hot_build_local_get(func, 2)
  hot_root_append(func, drop)
  hot_root_append(func, hot_build_drop(func, final_get_1))
  hot_root_append(func, hot_build_drop(func, final_get_2))

  let cfg = cfg_build(func)
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let ssa = ssa_build_local(func, cfg, dom, liveness, use_def)
  let condition_value = ssa_def_for_local_set(ssa, condition)

  @debug.assert_eq(
    ssa_value_for_local_get(ssa, final_get_1),
    condition_value,
    msg="condition-written local must reach post-if continuation",
  )
  assert_false(
    ssa_value_for_local_get(ssa, final_get_2) ==
    ssa_def_for_local_set(ssa, then_set),
  )
  assert_false(
    ssa_value_for_local_get(ssa, final_get_2) ==
    ssa_def_for_local_set(ssa, else_set),
  )
  let join_block = cfg_block_for_region_root(cfg, HotRegionRef::root(), 1).unwrap()
  let phis = ssa_phis_for_block(ssa, join_block)
  @debug.assert_eq(phis.length(), 1)
  @debug.assert_eq(ssa_phi_local(ssa, phis[0]), 2)
}

///|
test "ssa local build renames condition value-block locals before drop operand result-if arms" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let condition_block = hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [
      hot_build_local_set(func, 1, hot_build_const_i32(func, @lib.I32(1))),
      hot_build_local_get(func, 1),
    ],
  )
  let then_set = hot_build_local_set(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  let then_get = hot_build_local_get(func, 1)
  let else_set = hot_build_local_set(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(9)),
  )
  let else_get = hot_build_local_get(func, 1)
  let result_if = hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    condition_block,
    [then_set, then_get],
    else_body=Some([else_set, else_get]),
  )
  let drop = hot_build_drop(func, result_if)
  let final_get = hot_build_local_get(func, 1)
  hot_root_append(func, drop)
  hot_root_append(func, hot_build_drop(func, final_get))

  assert_true(
    ssa_simple_drop_result_if_allowed(func, drop, 0, result_if),
    msg="expected condition value-block drop result-if shape to be allowed",
  )
  let cfg = cfg_build(func)
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let ssa = ssa_build_local(func, cfg, dom, liveness, use_def)
  let condition_set = hot_region_get(
    func,
    hot_region_body_ref(func, condition_block),
    0,
  )
  let condition_value = ssa_def_for_local_set(ssa, condition_set)
  let then_value = ssa_def_for_local_set(ssa, then_set)
  let else_value = ssa_def_for_local_set(ssa, else_set)
  let final_value = ssa_value_for_local_get(ssa, final_get)

  assert_false(final_value == condition_value)
  assert_false(final_value == then_value)
  assert_false(final_value == else_value)
  let drop_block = cfg_block_for_node(cfg, drop).unwrap()
  let writes = local_write_block_ids(use_def, 1)
  assert_true(
    writes.length() >= 2,
    msg="expected condition-block and arm local writes",
  )
  @debug.assert_eq(writes[0], drop_block)
}

///|
test "ssa local build carries condition-block-written local into then and else arms" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  let condition_block = hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [
      hot_build_local_set(func, 1, hot_build_const_i32(func, @lib.I32(4))),
      hot_build_local_get(func, 0),
    ],
  )
  let then_set = hot_build_local_set(func, 2, hot_build_local_get(func, 1))
  let then_get = hot_build_local_get(func, 2)
  let else_set = hot_build_local_set(
    func,
    2,
    hot_build_const_i32(func, @lib.I32(2)),
  )
  let else_get = hot_build_local_get(func, 2)
  let result_if = hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    condition_block,
    [then_set, then_get],
    else_body=Some([else_set, else_get]),
  )
  let drop = hot_build_drop(func, result_if)
  let final_get_1 = hot_build_local_get(func, 1)
  let final_get_2 = hot_build_local_get(func, 2)
  hot_root_append(func, drop)
  hot_root_append(func, hot_build_drop(func, final_get_1))
  hot_root_append(func, hot_build_drop(func, final_get_2))

  let cfg = cfg_build(func)
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let ssa = ssa_build_local(func, cfg, dom, liveness, use_def)
  let condition_set = hot_region_get(
    func,
    hot_region_body_ref(func, condition_block),
    0,
  )
  let condition_value = ssa_def_for_local_set(ssa, condition_set)

  @debug.assert_eq(
    ssa_value_for_local_get(ssa, final_get_1),
    condition_value,
    msg="condition-block-written local must reach post-if continuation",
  )
  assert_false(
    ssa_value_for_local_get(ssa, final_get_2) ==
    ssa_def_for_local_set(ssa, then_set),
  )
  assert_false(
    ssa_value_for_local_get(ssa, final_get_2) ==
    ssa_def_for_local_set(ssa, else_set),
  )
  let join_block = cfg_block_for_region_root(cfg, HotRegionRef::root(), 1).unwrap()
  let phis = ssa_phis_for_block(ssa, join_block)
  @debug.assert_eq(phis.length(), 1)
  @debug.assert_eq(ssa_phi_local(ssa, phis[0]), 2)
}

///|
test "ssa local build renames locals inside drop operand value blocks" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let prior_set = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(3)),
  )
  let nested_set = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  let nested_get = hot_build_local_get(func, 0)
  let value_block = hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [nested_set, nested_get],
  )
  let drop = hot_build_drop(func, value_block)
  let final_get = hot_build_local_get(func, 0)
  hot_root_append(func, prior_set)
  hot_root_append(func, drop)
  hot_root_append(func, hot_build_drop(func, final_get))

  let cfg = cfg_build(func)
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let ssa = ssa_build_local(func, cfg, dom, liveness, use_def)
  let prior_value = ssa_def_for_local_set(ssa, prior_set)
  let nested_value = ssa_def_for_local_set(ssa, nested_set)

  @debug.assert_eq(ssa_value_for_local_get(ssa, final_get), nested_value)
  assert_false(ssa_value_for_local_get(ssa, final_get) == prior_value)
  @debug.assert_eq(
    ssa_value_origin(ssa, ssa_value_for_local_get(ssa, nested_get)),
    ssa_local_set_def(nested_set),
  )
}

///|
fn ssa_local_test_arm_value_block_drop_result_if(
  func : HotFunc,
  condition : NodeId,
  then_body : Array[NodeId],
  else_body : Array[NodeId],
) -> (NodeId, NodeId, NodeId, NodeId) {
  let then_block = hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    then_body,
  )
  let else_block = hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    else_body,
  )
  let then_set = hot_region_get(func, hot_region_body_ref(func, then_block), 0)
  let else_set = hot_region_get(func, hot_region_body_ref(func, else_block), 0)
  let result_if = hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    condition,
    [then_block],
    else_body=Some([else_block]),
  )
  let drop = hot_build_drop(func, result_if)
  hot_root_append(func, drop)
  hot_root_append(func, hot_build_drop(func, hot_build_local_get(func, 1)))
  (result_if, drop, then_set, else_set)
}

///|
fn ssa_local_test_mixed_arm_value_block_drop_result_if(
  func : HotFunc,
  condition : NodeId,
  then_prefix : NodeId,
  then_body : Array[NodeId],
  else_prefix : NodeId,
  else_body : Array[NodeId],
) -> (NodeId, NodeId, NodeId, NodeId, NodeId, NodeId) {
  let then_block = hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    then_body,
  )
  let else_block = hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    else_body,
  )
  let then_body_get = hot_region_get(
    func,
    hot_region_body_ref(func, then_block),
    0,
  )
  let then_block_set = hot_region_get(
    func,
    hot_region_body_ref(func, then_block),
    then_body.length() - 2,
  )
  let else_block_set = hot_region_get(
    func,
    hot_region_body_ref(func, else_block),
    else_body.length() - 2,
  )
  let result_if = hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    condition,
    [then_prefix, then_block],
    else_body=Some([else_prefix, else_block]),
  )
  let drop = hot_build_drop(func, result_if)
  hot_root_append(func, drop)
  hot_root_append(func, hot_build_drop(func, hot_build_local_get(func, 1)))
  hot_root_append(func, hot_build_drop(func, hot_build_local_get(func, 2)))
  (result_if, drop, then_prefix, then_body_get, then_block_set, else_block_set)
}

///|
test "ssa local build renames result-if arm value-block locals" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let (_, drop, then_set, else_set) = ssa_local_test_arm_value_block_drop_result_if(
    func,
    hot_build_local_get(func, 0),
    [
      hot_build_local_set(func, 1, hot_build_const_i32(func, @lib.I32(7))),
      hot_build_local_get(func, 1),
    ],
    [
      hot_build_local_set(func, 1, hot_build_const_i32(func, @lib.I32(9))),
      hot_build_local_get(func, 1),
    ],
  )
  let final_get = hot_child_get(func, hot_root_get(func, 1), 0)
  assert_true(
    ssa_simple_drop_result_if_allowed(
      func,
      drop,
      0,
      hot_child_get(func, drop, 0),
    ),
    msg="expected arm value-block drop result-if shape to be allowed",
  )
  let cfg = cfg_build(func)
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let ssa = ssa_build_local(func, cfg, dom, liveness, use_def)
  let then_value = ssa_def_for_local_set(ssa, then_set)
  let else_value = ssa_def_for_local_set(ssa, else_set)
  let final_value = ssa_value_for_local_get(ssa, final_get)

  assert_false(final_value == then_value)
  assert_false(final_value == else_value)
  let join_block = cfg_block_for_region_root(cfg, HotRegionRef::root(), 1).unwrap()
  let phis = ssa_phis_for_block(ssa, join_block)
  @debug.assert_eq(phis.length(), 1)
  @debug.assert_eq(ssa_phi_local(ssa, phis[0]), 1)
}

///|
test "ssa local build carries arm-value-block writes into post-drop join" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let (_, _, then_set, else_set) = ssa_local_test_arm_value_block_drop_result_if(
    func,
    hot_build_local_get(func, 0),
    [
      hot_build_local_set(func, 1, hot_build_const_i32(func, @lib.I32(7))),
      hot_build_local_get(func, 1),
    ],
    [
      hot_build_local_set(func, 1, hot_build_const_i32(func, @lib.I32(9))),
      hot_build_local_get(func, 1),
    ],
  )
  let final_get = hot_child_get(func, hot_root_get(func, 1), 0)
  let cfg = cfg_build(func)
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let ssa = ssa_build_local(func, cfg, dom, liveness, use_def)
  let then_value = ssa_def_for_local_set(ssa, then_set)
  let else_value = ssa_def_for_local_set(ssa, else_set)
  let final_value = ssa_value_for_local_get(ssa, final_get)
  let join_block = cfg_block_for_region_root(cfg, HotRegionRef::root(), 1).unwrap()
  let phis = ssa_phis_for_block(ssa, join_block)
  let inputs = ssa_phi_inputs(ssa, phis[0])
  let mut saw_then = false
  let mut saw_else = false

  @debug.assert_eq(inputs.length(), 2)
  for input in inputs {
    if input.value_id == then_value {
      saw_then = true
    } else if input.value_id == else_value {
      saw_else = true
    }
  }
  assert_true(saw_then)
  assert_true(saw_else)
  assert_false(final_value == then_value)
  assert_false(final_value == else_value)
}

///|
test "ssa local build lets arm value-blocks read prefix-written locals" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  let (_, _, then_prefix, then_body_get, _, _) = ssa_local_test_mixed_arm_value_block_drop_result_if(
    func,
    hot_build_local_get(func, 0),
    hot_build_local_set(func, 1, hot_build_const_i32(func, @lib.I32(4))),
    [
      hot_build_local_get(func, 1),
      hot_build_local_set(func, 2, hot_build_const_i32(func, @lib.I32(7))),
      hot_build_local_get(func, 2),
    ],
    hot_build_local_set(func, 1, hot_build_const_i32(func, @lib.I32(5))),
    [
      hot_build_local_get(func, 1),
      hot_build_local_set(func, 2, hot_build_const_i32(func, @lib.I32(9))),
      hot_build_local_get(func, 2),
    ],
  )
  let cfg = cfg_build(func)
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let ssa = ssa_build_local(func, cfg, dom, liveness, use_def)
  let prefix_value = ssa_def_for_local_set(ssa, then_prefix)

  @debug.assert_eq(
    ssa_value_for_local_get(ssa, then_body_get),
    prefix_value,
    msg="prefix write must reach final value-block body read",
  )
}

///|
test "ssa local build carries mixed-arm prefix and block writes into post-drop join" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  let (_, _, then_prefix, _, then_block_set, else_block_set) = ssa_local_test_mixed_arm_value_block_drop_result_if(
    func,
    hot_build_local_get(func, 0),
    hot_build_local_set(func, 1, hot_build_const_i32(func, @lib.I32(1))),
    [
      hot_build_local_set(func, 2, hot_build_const_i32(func, @lib.I32(7))),
      hot_build_local_get(func, 2),
    ],
    hot_build_local_set(func, 1, hot_build_const_i32(func, @lib.I32(2))),
    [
      hot_build_local_set(func, 2, hot_build_const_i32(func, @lib.I32(9))),
      hot_build_local_get(func, 2),
    ],
  )
  let else_prefix = hot_region_get(
    func,
    hot_region_else_ref(func, hot_child_get(func, hot_root_get(func, 0), 0)).unwrap(),
    0,
  )
  let final_get_1 = hot_child_get(func, hot_root_get(func, 1), 0)
  let final_get_2 = hot_child_get(func, hot_root_get(func, 2), 0)
  let cfg = cfg_build(func)
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let ssa = ssa_build_local(func, cfg, dom, liveness, use_def)
  let then_prefix_value = ssa_def_for_local_set(ssa, then_prefix)
  let else_prefix_value = ssa_def_for_local_set(ssa, else_prefix)
  let then_block_value = ssa_def_for_local_set(ssa, then_block_set)
  let else_block_value = ssa_def_for_local_set(ssa, else_block_set)
  let final_value_1 = ssa_value_for_local_get(ssa, final_get_1)
  let final_value_2 = ssa_value_for_local_get(ssa, final_get_2)
  let join_block = cfg_block_for_region_root(cfg, HotRegionRef::root(), 1).unwrap()
  let phis = ssa_phis_for_block(ssa, join_block)
  let mut phi_local_1 : PhiId? = None
  let mut phi_local_2 : PhiId? = None

  for phi_id in phis {
    match ssa_phi_local(ssa, phi_id) {
      1 => phi_local_1 = Some(phi_id)
      2 => phi_local_2 = Some(phi_id)
      _ => ()
    }
  }
  match phi_local_1 {
    Some(phi_id) => {
      let inputs = ssa_phi_inputs(ssa, phi_id)
      @debug.assert_eq(inputs.length(), 2)
      let mut saw_then = false
      let mut saw_else = false
      for input in inputs {
        if input.value_id == then_prefix_value {
          saw_then = true
        } else if input.value_id == else_prefix_value {
          saw_else = true
        }
      }
      assert_true(saw_then)
      assert_true(saw_else)
      assert_false(final_value_1 == then_prefix_value)
      assert_false(final_value_1 == else_prefix_value)
    }
    None => fail("expected join phi for local 1")
  }
  match phi_local_2 {
    Some(phi_id) => {
      let inputs = ssa_phi_inputs(ssa, phi_id)
      @debug.assert_eq(inputs.length(), 2)
      let mut saw_then = false
      let mut saw_else = false
      for input in inputs {
        if input.value_id == then_block_value {
          saw_then = true
        } else if input.value_id == else_block_value {
          saw_else = true
        }
      }
      assert_true(saw_then)
      assert_true(saw_else)
      assert_false(final_value_2 == then_block_value)
      assert_false(final_value_2 == else_block_value)
    }
    None => fail("expected join phi for local 2")
  }
}

///|
test "ssa local build lets arm value-blocks read condition-written locals" {
  let source =
    #|(module
    #|  (func (param i32) (local i32 i32)
    #|    i32.const 4
    #|    local.set 1
    #|    local.get 0
    #|    if (result i32)
    #|      (block (result i32)
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.set 2
    #|        local.get 2)
    #|    else
    #|      (block (result i32)
    #|        local.get 1
    #|        i32.const 2
    #|        i32.add
    #|        local.set 2
    #|        local.get 2)
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2
    #|    drop))
    #|)
  let fixture = ir_test_build_hot_from_wat(source)
  let func = fixture.hot_func
  let pre_set = hot_root_get(func, 0)
  let final_get_1 = hot_child_get(func, hot_root_get(func, 2), 0)
  let final_get_2 = hot_child_get(func, hot_root_get(func, 3), 0)
  let cfg = cfg_build(func)
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let ssa = ssa_build_local(func, cfg, dom, liveness, use_def)
  let pre_value = ssa_def_for_local_set(ssa, pre_set)
  let final_value_2 = ssa_value_for_local_get(ssa, final_get_2)

  @debug.assert_eq(
    ssa_value_for_local_get(ssa, final_get_1),
    pre_value,
    msg="pre-if local write must reach post-if continuation",
  )
  match ssa_value_origin(ssa, final_value_2) {
    HotSsaValueOrigin::PhiDef(phi_id) =>
      @debug.assert_eq(ssa_phi_local(ssa, phi_id), 2)
    _ => fail("expected arm-written local 2 to merge through a join phi")
  }
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

  @debug.assert_eq(ssa_value_origin(ssa, tee_value), ssa_local_tee_def(tee))
  @debug.assert_eq(ssa_value_for_local_get(ssa, read), tee_value)
}

///|
test "ssa local build reads previous local value inside tee operands" {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let operand_get = hot_build_local_get(func, 0)
  let tee = hot_build_local_tee(func, 0, operand_get)
  let after_get = hot_build_local_get(func, 0)
  hot_root_append(func, hot_build_drop(func, tee))
  hot_root_append(func, hot_build_drop(func, after_get))

  let cfg = cfg_build(func)
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let ssa = ssa_build_local(func, cfg, dom, liveness, use_def)
  let tee_value = ssa_def_for_local_set(ssa, tee)

  @debug.assert_eq(
    ssa_value_origin(ssa, ssa_value_for_local_get(ssa, operand_get)),
    ssa_param_entry_def(0),
  )
  @debug.assert_eq(ssa_value_origin(ssa, tee_value), ssa_local_tee_def(tee))
  @debug.assert_eq(ssa_value_for_local_get(ssa, after_get), tee_value)
}

///|
test "ssa local build records local get and phi input uses" {
  let func = hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        ],
        Some([@lib.Instruction::nop()]),
      ),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
    ]),
    HotLocals::new(locals=[@lib.ValType::i32()]),
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
  @debug.assert_eq(phis.length(), 1)
  let phi_id = phis[0]
  let then_value = ssa_def_for_local_set(ssa, then_set)
  let phi_value = ssa_value_for_local_get(ssa, join_get)
  let ordered_inputs = ssa_phi_inputs(ssa, phi_id)
  let ordered_predecessors = cfg_predecessors(cfg, join_block)
  @debug.assert_eq(ordered_inputs.length(), ordered_predecessors.length())
  for idx = 0; idx < ordered_inputs.length(); idx = idx + 1 {
    @debug.assert_eq(
      ordered_inputs[idx].predecessor,
      ordered_predecessors[idx].block,
    )
  }

  assert_true(
    ssa_local_has_phi_input_use(
      ssa_uses_of_value(ssa, then_value),
      phi_id,
      then_block,
    ),
    msg="then-set value should be used by the join phi input",
  )
  assert_true(
    ssa_local_has_phi_input_use(
      ssa_uses_of_value(ssa, ssa.entry_defs[0]),
      phi_id,
      else_block,
    ),
    msg="default entry value should be used by the else phi input",
  )
  assert_true(
    ssa_local_has_local_get_use(ssa_uses_of_value(ssa, phi_value), join_get),
    msg="phi value should be used by the post-join local.get",
  )
}

///|
test "ssa local maybe-def queries distinguish writes from reads" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let set_id = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  let get_id = hot_build_local_get(func, 0)
  hot_root_append(func, set_id)
  hot_root_append(func, hot_build_drop(func, get_id))

  let cfg = cfg_build(func)
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let ssa = ssa_build_local(func, cfg, dom, liveness, use_def)

  match ssa_maybe_def_for_local_set(ssa, set_id) {
    Some(value_id) =>
      @debug.assert_eq(value_id, ssa_def_for_local_set(ssa, set_id))
    None => fail("expected local.set to have an SSA def")
  }
  match ssa_maybe_def_for_local_set(ssa, get_id) {
    Some(_) => fail("local.get must not have an SSA def")
    None => ()
  }
}

///|
test "ssa local build ignores unreachable predecessor blocks in branch-carry ladders" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (memory 1) (func (param i32) (result i32) local.get 0) (func (param i32 i32) (result i32) (local i32) local.get 0 call 0 local.get 1 call 0 i32.eq if loop local.get 0 call 0 local.get 2 i32.gt_s if local.get 0 local.get 2 i32.const 1 i32.shl i32.add i32.load16_u offset=8 local.get 1 local.get 2 i32.const 1 i32.shl i32.add i32.load16_u offset=8 i32.eq if local.get 2 i32.const 1 i32.add local.set 2 br 2 else i32.const 0 return end unreachable else i32.const 1 return end unreachable end unreachable else i32.const 0 return end unreachable))",
    code_idx=1,
  )

  let cfg = cfg_build(fixture.hot_func)
  let dom = dom_build(cfg)
  let use_def = use_def_build(fixture.hot_func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let ssa = ssa_build_local(fixture.hot_func, cfg, dom, liveness, use_def)

  assert_true(cfg_block_count(cfg) > 1)
  assert_true(ssa.entry_defs.length() > 0)
}
