test "build_cfg from simple expression" {
  // Simple constant return
  let expr = TExpr::new([TInstr::return_([TInstr::i32_const(42)])])
  let cfg = build_cfg(expr)
  
  // Should have an entry block
  assert_true(cfg.block(cfg.entry()) is Some(_))
  
  // Validate the CFG structure
  assert_eq(cfg.validate(), Ok(()))
}

test "build_cfg with conditional branch" {
  // if (local.get 0) { return 1 } else { return 0 }
  let expr = TExpr::new([
    TInstr::if_(
      BlockType::val_type(ValType::i32()),
      TInstr::local_get(LocalIdx::new(0)),
      TExpr::new([TInstr::i32_const(1)]),
      Some(TExpr::new([TInstr::i32_const(0)])),
    ),
    TInstr::return_([]),
  ])
  let cfg = build_cfg(expr)
  
  assert_eq(cfg.validate(), Ok(()))
  // Should have multiple blocks for the if/else
  assert_true(cfg.blocks.length() >= 2)
}

test "build_cfg with loop" {
  // loop { br 0 }
  let expr = TExpr::new([TInstr::loop_(BlockType::void_(), TExpr::new([TInstr::br(LabelIdx::new(0), [])]))])
  let cfg = build_cfg(expr)
  
  assert_eq(cfg.validate(), Ok(()))
}

test "cfg dominators" {
  let expr = TExpr::new([TInstr::return_([TInstr::i32_const(0)])])
  let cfg = build_cfg(expr)
  let _ = cfg.dominators()
  
  // Entry block should dominate itself
  let entry = cfg.entry()
  assert_true(cfg.dominates(entry, entry))
}

test "cfg dominance frontier" {
  let expr = TExpr::new([
    TInstr::if_(
      BlockType::void_(),
      TInstr::local_get(LocalIdx::new(0)),
      TExpr::new([TInstr::nop()]),
      Some(TExpr::new([TInstr::nop()])),
    ),
    TInstr::return_([TInstr::i32_const(0)]),
  ])
  let cfg = build_cfg(expr)
  let df = cfg.dominance_frontier()
  
  // Should compute dominance frontier for all blocks
  for block_id in cfg.blocks.keys() {
    assert_true(df.contains(block_id))
  }
}

test "cfg_to_ssa conversion" {
  let expr= TExpr::new([
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(42)),
    TInstr::return_([TInstr::local_get(LocalIdx::new(0))]),
  ])
  let cfg = build_cfg(expr)
  let doms = cfg.dominators()
  let df = cfg.dominance_frontier()
  
  let ssa_cfg = cfg_to_ssa(cfg, doms, df, 1) // 1 local
  
  // SSA should preserve entry
  assert_eq(ssa_cfg.entry, cfg.entry())
}

test "ssa_to_cfg roundtrip" {
  let expr = TExpr::new([
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(42)),
    TInstr::return_([TInstr::local_get(LocalIdx::new(0))]),
  ])
  let cfg = build_cfg(expr)
  let doms = cfg.dominators()
  let df = cfg.dominance_frontier()
  
  let ssa_cfg = cfg_to_ssa(cfg, doms, df, 1)
  let cfg2 = ssa_to_cfg(ssa_cfg, 1)
  
  assert_eq(cfg2.validate(), Ok(()))
}

test "compute_liveness" {
  let expr = TExpr::new([
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(1)),
    TInstr::local_set(LocalIdx::new(1), TInstr::local_get(LocalIdx::new(0))),
    TInstr::return_([TInstr::local_get(LocalIdx::new(1))]),
  ])
  let cfg = build_cfg(expr)
  let doms = cfg.dominators()
  let df = cfg.dominance_frontier()
  let ssa_cfg = cfg_to_ssa(cfg, doms, df, 2)
  
  let liveness = compute_liveness(ssa_cfg)
  
  // Should have liveness info for all blocks
  for block_id in ssa_cfg.blocks.keys() {
    let _ = liveness.get_live_in(block_id)
    let _ = liveness.get_live_out(block_id)
  }
}

test "build_use_def" {
  let expr = TExpr::new([
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(5)),
    TInstr::return_([TInstr::binary(BinaryOp::i32_add(), TInstr::local_get(LocalIdx::new(0)), TInstr::i32_const(3))]),
  ])
  let cfg = build_cfg(expr)
  let doms = cfg.dominators()
  let df = cfg.dominance_frontier()
  let ssa_cfg = cfg_to_ssa(cfg, doms, df, 1)
  
  let use_def = build_use_def(ssa_cfg)
  
  // Check that param values have definitions
  for entry in ssa_cfg.param_values {
    let (_, ssa_val) = entry
    assert_true(use_def.get_def(ssa_val) is Some(_))
  }
}

test "split_critical_edges" {
  // Create a CFG with potential critical edges (multiple preds, multiple succs)
  let expr = TExpr::new([
    TInstr::if_(
      BlockType::void_(),
      TInstr::local_get(LocalIdx::new(0)),
      TExpr::new([TInstr::br(LabelIdx::new(0), [])]),
      Some(TExpr::new([TInstr::br(LabelIdx::new(0), [])])),
    ),
    TInstr::return_([TInstr::i32_const(0)]),
  ])
  let cfg = build_cfg(expr)
  let doms = cfg.dominators()
  let df = cfg.dominance_frontier()
  let ssa_cfg = cfg_to_ssa(cfg, doms, df, 1)
  
  let split_cfg = split_critical_edges(ssa_cfg)
  
  // Should still be valid
  let back_to_cfg = ssa_to_cfg(split_cfg, 1)
  assert_eq(back_to_cfg.validate(), Ok(()))
}

test "run_gvn optimization" {
  // Duplicate computations that GVN should optimize
  let expr = TExpr::new([
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(5)),
    TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(5)), // Same constant
    TInstr::return_([TInstr::binary(BinaryOp::i32_add(), TInstr::local_get(LocalIdx::new(0)), TInstr::local_get(LocalIdx::new(1)))]),
  ])
  let cfg = build_cfg(expr)
  let doms = cfg.dominators()
  let df = cfg.dominance_frontier()
  let ssa_cfg = cfg_to_ssa(cfg, doms, df, 2)
  
  let optimized = run_gvn(ssa_cfg, doms)
  
  // Should still produce valid CFG
  let back_to_cfg = ssa_to_cfg(optimized, 2)
  assert_eq(back_to_cfg.validate(), Ok(()))
}

test "BlockId and SSAValue equality" {
  let b1 = BlockId(0)
  let b2 = BlockId(0)
  let b3 = BlockId(1)
  
  assert_eq(b1, b2)
  assert_true(b1 != b3)
  
  let v1 = SSAValue(0)
  let v2 = SSAValue(0)
  let v3 = SSAValue(1)
  
  assert_eq(v1, v2)
  assert_true(v1 != v3)
}

test "BlockId and SSAValue hashing" {
  let map : Map[BlockId, Int] = {}
  map[BlockId(0)] = 10
  map[BlockId(1)] = 20
  
  assert_eq(map[BlockId(0)], 10)
  assert_eq(map[BlockId(1)], 20)
  
  let val_map : Map[SSAValue, String] = {}
  val_map[SSAValue(0)] = "first"
  val_map[SSAValue(1)] = "second"
  
  assert_eq(val_map[SSAValue(0)], "first")
}

test "infer_ssa_types" {
  let expr = TExpr::new([
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(42)),
    TInstr::return_([TInstr::local_get(LocalIdx::new(0))]),
  ])
  let cfg = build_cfg(expr)
  let doms = cfg.dominators()
  let df = cfg.dominance_frontier()
  let ssa_cfg = cfg_to_ssa(cfg, doms, df, 1)
  
  let type_ctx : TypeContext = {
    func_types: [],
    global_types: [],
    table_types: [],
    struct_types: [],
    array_types: [],
    tag_types: [],
    local_types: [ValType::i32()],
  }
  
  let type_info = infer_ssa_types(ssa_cfg, type_ctx)
  
  // Parameter value should have i32 type
  for entry in ssa_cfg.param_values {
    let (_, ssa_val) = entry
    assert_eq(type_info.get(ssa_val), Some(ValType::i32()))
  }
}

test "UseDefInfo dead code detection" {
  let expr = TExpr::new([
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(100)), // Potentially dead if not used
    TInstr::return_([TInstr::i32_const(0)]),
  ])
  let cfg = build_cfg(expr)
  let doms = cfg.dominators()
  let df = cfg.dominance_frontier()
  let ssa_cfg = cfg_to_ssa(cfg, doms, df, 1)
  
  let use_def = build_use_def(ssa_cfg)
  
  // Find values and check if any are dead
  for block in ssa_cfg.blocks.values() {
    for instr in block.instrs {
      match instr {
        Assign(val, _) => {
          let is_dead = use_def.is_dead(val)
          // Just verify the method works
          let _ = is_dead
        }
        Effect(_) => ()
      }
    }
  }
}

test "CFG predecessors and successors" {
  let expr = TExpr::new([
    TInstr::if_(
      BlockType::void_(),
      TInstr::local_get(LocalIdx::new(0)),
      TExpr::new([TInstr::nop()]),
      Some(TExpr::new([TInstr::nop()])),
    ),
    TInstr::return_([TInstr::i32_const(0)]),
  ])
  let cfg = build_cfg(expr)
  
  // Entry should have no predecessors
  assert_eq(cfg.predecessors(cfg.entry()).length(), 0)
  
  // Check that successors are computed
  let entry_succs = cfg.successors(cfg.entry())
  // Entry of an if should branch to two successors
  assert_true(entry_succs.length() >= 1)
}

test "LivenessInfo queries" {
  let expr = TExpr::new([
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(1)),
    TInstr::return_([TInstr::local_get(LocalIdx::new(0))]),
  ])
  let cfg = build_cfg(expr)
  let doms = cfg.dominators()
  let df = cfg.dominance_frontier()
  let ssa_cfg = cfg_to_ssa(cfg, doms, df, 1)
  let liveness = compute_liveness(ssa_cfg)
  
  let entry = ssa_cfg.entry
  let _ = liveness.get_live_in(entry)
  let _ = liveness.get_live_out(entry)
  
  // Verify we can query specific values
  for entry in ssa_cfg.param_values {
    let (_, val) = entry
    let _ = liveness.is_live_in(ssa_cfg.entry, val)
    let _ = liveness.is_live_out(ssa_cfg.entry, val)
  }
}