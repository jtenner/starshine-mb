///|
test "hot verify core reports root child span label owner and side-table corruption" {
  let invalid_root = HotFunc::new()
  invalid_root.roots.push(3)
  match hot_verify_core(invalid_root) {
    Err(HotVerifyError::InvalidRoot(0, 3)) => ()
    other => fail("expected invalid root error, got \{other}")
  }

  let invalid_child_span = HotFunc::new()
  invalid_child_span.nodes.push({
    op: HotOp::Nop,
    ty: hot_type_void(invalid_child_span),
    flags: hot_default_flags_for_op(HotOp::Nop),
    imm0: 0,
    imm1: 0,
    child_base: 1,
    child_count: 1,
  })
  match hot_verify_core(invalid_child_span) {
    Err(HotVerifyError::InvalidChildSpan(0, 1, 1)) => ()
    other => fail("expected invalid child span error, got \{other}")
  }

  let invalid_label_owner = HotFunc::new()
  let label_id = hot_label_alloc(
    invalid_label_owner,
    HotLabelKind::BlockLabel,
    hot_type_void(invalid_label_owner),
    99,
    0,
  )
  match hot_verify_core(invalid_label_owner) {
    Err(HotVerifyError::InvalidLabelOwner(owner_label, owner)) => {
      @debug.assert_eq(owner_label, label_id)
      @debug.assert_eq(owner, 99)
    }
    other => fail("expected invalid label owner, got \{other}")
  }

  let invalid_side_table = HotFunc::new()
  let selector = hot_build_const_i32(invalid_side_table, @lib.I32(0))
  let br_table = hot_build_node(
    invalid_side_table,
    HotOp::BrTable,
    hot_type_void(invalid_side_table),
    imm0=17,
    children=[selector],
  )
  hot_root_append(invalid_side_table, br_table)
  match hot_verify_core(invalid_side_table) {
    Err(
      HotVerifyError::InvalidSideTableRef(
        node_id,
        HotSideTableKind::BranchTableTable,
        table_id
      )
    ) => {
      @debug.assert_eq(node_id, br_table)
      @debug.assert_eq(table_id, 17)
    }
    other => fail("expected invalid branch-table side table ref, got \{other}")
  }
}

///|
fn hot_verify_wb_simple_ssa_fixture() -> (
  HotFunc,
  HotCfg,
  HotDominators,
  HotLocalSsa,
) {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let value = hot_build_const_i32(func, @lib.I32(1))
  let set = hot_build_local_set(func, 0, value)
  let get = hot_build_local_get(func, 0)
  hot_root_append(func, set)
  hot_root_append(func, hot_build_drop(func, get))
  let cfg = cfg_build(func)
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let ssa = ssa_build_local(func, cfg, dom, liveness, use_def)
  (func, cfg, dom, ssa)
}

///|
test "hot verify cfg rejects stale node to block ownership" {
  let (func, cfg, _, _) = hot_verify_wb_simple_ssa_fixture()
  let set = hot_root_get(func, 0)
  let bad_node_to_block = cfg.node_to_block.copy()
  bad_node_to_block[set] = cfg_exit_block(cfg)
  let bad_cfg : HotCfg = {
    blocks: cfg.blocks,
    node_to_block: bad_node_to_block,
    region_roots: cfg.region_roots,
    entry_block: cfg.entry_block,
    exit_block: cfg.exit_block,
    exceptional_exit_block: cfg.exceptional_exit_block,
  }

  match hot_verify_cfg(func, bad_cfg) {
    Err(HotVerifyError::InvalidCfgNodeMapping(node_id, block_id)) => {
      @debug.assert_eq(node_id, set)
      @debug.assert_eq(block_id, cfg_exit_block(cfg))
    }
    other => fail("expected invalid cfg node mapping, got \{other}")
  }
}

///|
test "hot verify dominators rejects mismatched entry block" {
  let (_, cfg, dom, _) = hot_verify_wb_simple_ssa_fixture()
  let bad_dom : HotDominators = {
    entry_block: cfg_exit_block(cfg),
    reachable: dom.reachable,
    idoms: dom.idoms,
    children: dom.children,
    frontiers: dom.frontiers,
    dom_preorder: dom.dom_preorder,
    dom_postorder: dom.dom_postorder,
  }

  match hot_verify_dominators(cfg, bad_dom) {
    Err(HotVerifyError::InvalidDomEntry(actual, expected)) => {
      @debug.assert_eq(actual, cfg_exit_block(cfg))
      @debug.assert_eq(expected, cfg_entry_block(cfg))
    }
    other => fail("expected invalid dominator entry, got \{other}")
  }
}

///|
test "hot verify ssa rejects stale revisions" {
  let (func, cfg, _, ssa) = hot_verify_wb_simple_ssa_fixture()
  let stale_ssa : HotLocalSsa = {
    revision: hot_revision_current(func) + 1,
    value_types: ssa.value_types,
    value_origins: ssa.value_origins,
    phis: ssa.phis,
    entry_defs: ssa.entry_defs,
    phi_value_ids: ssa.phi_value_ids,
    block_phis: ssa.block_phis,
    phi_inputs: ssa.phi_inputs,
    local_get_values: ssa.local_get_values,
    local_write_defs: ssa.local_write_defs,
    value_uses: ssa.value_uses,
  }

  match hot_verify_ssa(func, cfg, stale_ssa) {
    Err(HotVerifyError::InvalidSsaRevision(actual, expected)) => {
      @debug.assert_eq(actual, hot_revision_current(func) + 1)
      @debug.assert_eq(expected, hot_revision_current(func))
    }
    other => fail("expected stale ssa revision, got \{other}")
  }
}

///|
fn hot_verify_wb_phi_fixture() -> (HotFunc, HotCfg, HotLocalSsa, PhiId) {
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
  let ssa = ssa_build_local(func, cfg, dom, liveness, use_def)
  let join_block = cfg_block_for_region_root(cfg, HotRegionRef::root(), 1).unwrap()
  (func, cfg, ssa, ssa.block_phis[join_block][0])
}

///|
test "hot verify ssa rejects phi inputs from non predecessors" {
  let (func, cfg, ssa, phi_id) = hot_verify_wb_phi_fixture()
  let bad_inputs = ssa.phi_inputs.copy()
  let inputs = bad_inputs[phi_id].copy()
  inputs[0] = HotSsaPhiInput::new(cfg_exit_block(cfg), inputs[0].value_id)
  bad_inputs[phi_id] = inputs
  let bad_ssa : HotLocalSsa = {
    revision: ssa.revision,
    value_types: ssa.value_types,
    value_origins: ssa.value_origins,
    phis: ssa.phis,
    entry_defs: ssa.entry_defs,
    phi_value_ids: ssa.phi_value_ids,
    block_phis: ssa.block_phis,
    phi_inputs: bad_inputs,
    local_get_values: ssa.local_get_values,
    local_write_defs: ssa.local_write_defs,
    value_uses: ssa.value_uses,
  }

  match hot_verify_ssa(func, cfg, bad_ssa) {
    Err(HotVerifyError::InvalidSsaPhiInput(found_phi, predecessor, _)) => {
      @debug.assert_eq(found_phi, phi_id)
      @debug.assert_eq(predecessor, cfg_exit_block(cfg))
    }
    other => fail("expected invalid phi input, got \{other}")
  }
}
