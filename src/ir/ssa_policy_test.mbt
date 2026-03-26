///|
fn[S : Show] ssa_policy_test_show_array(values : Array[S]) -> Array[String] {
  let out : Array[String] = []
  for value in values {
    out.push(value.to_string())
  }
  out
}

///|
test "ssa policy classifies entry defs and overlay phi metadata" {
  let ssa = HotLocalSsa::new(
    revision=9,
    value_types=[@lib.ValType::i32(), @lib.ValType::i64(), @lib.ValType::i32()],
    value_origins=[
      ssa_param_entry_def(0),
      ssa_default_init_def(1),
      ssa_local_set_def(17),
    ],
    phis=[HotSsaPhi::new(3, 1)],
  )

  assert_eq(ssa_value_type(ssa, 0), @lib.ValType::i32())
  assert_eq(ssa_value_type(ssa, 1), @lib.ValType::i64())
  assert_eq(ssa_value_origin(ssa, 0).to_string(), "EntryParamDef(0)")
  assert_eq(ssa_value_origin(ssa, 1).to_string(), "EntryDefaultInitDef(1)")
  assert_eq(ssa_value_origin(ssa, 2).to_string(), "LocalSetDef(17)")
  assert_eq(ssa_phi_block(ssa, 0), 3)
  assert_eq(ssa_phi_local(ssa, 0), 1)
}

///|
test "ssa policy places phis at live dominance frontiers" {
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
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let join_block = cfg_block_for_region_root(cfg, HotRegionRef::root(), 1).unwrap()

  assert_eq(
    ssa_phi_placement_blocks(
      func,
      cfg,
      dom,
      liveness,
      use_def,
      cfg_reverse_postorder(cfg),
      1,
    ),
    [join_block],
  )
}

///|
test "ssa policy keeps phi nodes overlay only and documents v1 limits" {
  assert_true(ssa_phi_nodes_are_overlay_only())
  assert_eq(ssa_rename_policy().to_string(), "DominatorTreeRename")
  assert_eq(
    ssa_destruction_policy().to_string(),
    "ParallelCopiesInPredecessors",
  )
  assert_eq(ssa_policy_test_show_array(ssa_v1_exclusions()), [
    "ExceptionalEdges", "PersistentHotPhiNodes", "IrOwnedSsaBodies", "NonLocalValues",
  ])
}

///|
test "ssa policy skips loop-header phis for locals with no writes" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let loop_id = hot_build_loop(func, @lib.BlockType::void_(), [])
  let loop_get = hot_build_local_get(func, 0)
  hot_region_replace_body(func, hot_region_body_ref(func, loop_id), [
    hot_build_drop(func, loop_get),
  ])
  hot_root_append(func, loop_id)

  let cfg = cfg_build(func)
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let loop_header = cfg_block_for_node(cfg, loop_id).unwrap()

  assert_eq(
    ssa_phi_placement_blocks(
      func,
      cfg,
      dom,
      liveness,
      use_def,
      cfg_reverse_postorder(cfg),
      0,
    ),
    [],
  )
  let ssa = ssa_build_local(func, cfg, dom, liveness, use_def)
  assert_eq(ssa_phis_for_block(ssa, loop_header), [])
  assert_eq(
    ssa_value_origin(ssa, ssa_value_for_local_get(ssa, loop_get)),
    ssa_default_init_def(0),
  )
}
