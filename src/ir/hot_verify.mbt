///|
pub enum HotVerifyError {
  InvalidBodyResultType(TypeId)
  MissingTypeKey(TypeId, String)
  MismatchedTypeKey(TypeId, String, TypeId)
  InvalidRoot(Int, NodeId)
  InvalidNodeType(NodeId, TypeId)
  InvalidNodeFlags(NodeId, UInt, UInt)
  InvalidChildSpan(NodeId, Int, Int)
  InvalidChildRef(NodeId, Int, NodeId)
  InvalidLabelResultType(LabelId, TypeId)
  InvalidLabelOwner(LabelId, NodeId)
  InvalidLabelOwnerKind(LabelId, HotLabelKind, HotOp)
  InvalidControlLabel(NodeId, LabelId)
  InvalidSideTableRef(NodeId, HotSideTableKind, SideTableId)
  InvalidControlChildCount(NodeId, Int, Int)
  InvalidControlChild(NodeId, Int, NodeId)
  InvalidBranchTarget(NodeId, LabelId)
  InvalidBranchArity(NodeId, LabelId, Int, Int)
  InvalidCfgEntry(BlockId)
  InvalidCfgExit(BlockId)
  InvalidCfgBlockId(BlockId, BlockId)
  InvalidCfgEdge(BlockId, CfgEdge)
  InvalidCfgEdgeSymmetry(BlockId, CfgEdge)
  InvalidCfgNodeMapping(NodeId, BlockId)
  InvalidCfgBlockNode(BlockId, NodeId)
  InvalidCfgRegionRoot(NodeId, Int, BlockId)
  InvalidCfgShape(String, Int, Int)
  InvalidDomEntry(BlockId, BlockId)
  InvalidDomShape(String, Int, Int)
  InvalidDomReachable(BlockId)
  InvalidDomIdom(BlockId, BlockId)
  InvalidDomChild(BlockId, BlockId)
  InvalidDomFrontier(BlockId, BlockId)
  InvalidSsaRevision(Int, Int)
  InvalidSsaShape(String, Int, Int)
  InvalidSsaValue(SsaValueId)
  InvalidSsaPhi(PhiId)
  InvalidSsaLocal(LocalId)
  InvalidSsaNode(NodeId)
  InvalidSsaValueOrigin(SsaValueId, HotSsaValueOrigin)
  InvalidSsaPhiInput(PhiId, BlockId, SsaValueId)
  InvalidSsaPhiAlignment(PhiId, BlockId, Int, Int)
  InvalidSsaType(SsaValueId, ValType, ValType)
  InvalidSsaUse(SsaValueId, HotSsaUseOrigin)
  InvalidSsaDominance(SsaValueId, BlockId, BlockId)
} derive(Eq, Debug)

///|
fn hot_verify_type_id_is_valid(func : HotFunc, ty : TypeId) -> Bool {
  ty >= 0 && ty < func.types.length()
}

///|
fn hot_verify_label_id_is_valid(func : HotFunc, label_id : LabelId) -> Bool {
  label_id >= 0 && label_id < func.labels.length()
}

///|
fn hot_verify_side_table_id_is_valid(
  func : HotFunc,
  kind : HotSideTableKind,
  side_table_id : SideTableId,
) -> Bool {
  if side_table_id < 0 {
    return false
  }
  match kind {
    HotSideTableKind::ConstPayloadTable => side_table_id < func.consts.length()
    HotSideTableKind::MemArgTable => side_table_id < func.memargs.length()
    HotSideTableKind::BranchTableTable =>
      side_table_id < func.branch_tables.length()
    HotSideTableKind::CatchInfoTable => side_table_id < func.catches.length()
    HotSideTableKind::CallSigTable => side_table_id < func.call_sigs.length()
    HotSideTableKind::InstrPayloadTable =>
      side_table_id < func.instr_payloads.length()
  }
}

///|
fn hot_verify_region_holder(func : HotFunc, node_id : NodeId) -> Bool {
  if !hot_node_is_live(func, node_id) {
    return false
  }
  let node = hot_node_get(func, node_id)
  if node.op != HotOp::Block {
    return false
  }
  let label_id = hot_control_node_label(func, node_id)
  hot_verify_label_id_is_valid(func, label_id) &&
  hot_label_kind(func, label_id) == HotLabelKind::RegionLabel
}

///|
fn hot_verify_branch_payload_arity(func : HotFunc, node_id : NodeId) -> Int? {
  let node = hot_node_get(func, node_id)
  match node.op {
    HotOp::Br | HotOp::Delegate => Some(node.child_count)
    HotOp::BrOnNonNull =>
      if node.child_count == 0 {
        None
      } else {
        // `br_on_non_null` carries the tested non-null reference as the final
        // taken-edge branch payload. Any explicit payload children are prefix
        // values, and the guard child itself accounts for the final label
        // result.
        Some(node.child_count)
      }
    HotOp::BrIf
    | HotOp::BrTable
    | HotOp::BrOnNull
    | HotOp::BrOnCast
    | HotOp::BrOnCastFail =>
      if node.child_count == 0 {
        None
      } else {
        Some(node.child_count - 1)
      }
    _ => Some(0)
  }
}

///|
fn hot_verify_control_label_kind(
  func : HotFunc,
  node_id : NodeId,
  node : HotNode,
) -> Result[Unit, HotVerifyError] {
  let label_id = hot_control_node_label(func, node_id)
  if !hot_verify_label_id_is_valid(func, label_id) {
    return Err(HotVerifyError::InvalidControlLabel(node_id, label_id))
  }
  let expected = match node.op {
    HotOp::Block => None
    HotOp::Loop => Some(HotLabelKind::LoopLabel)
    HotOp::If => Some(HotLabelKind::IfLabel)
    HotOp::Try => Some(HotLabelKind::TryLabel)
    HotOp::TryTable => Some(HotLabelKind::TryTableLabel)
    _ => None
  }
  match expected {
    Some(kind) if hot_label_kind(func, label_id) != kind =>
      Err(HotVerifyError::InvalidLabelOwnerKind(label_id, kind, node.op))
    _ => Ok(())
  }
}

///|
fn hot_verify_branch_target(
  func : HotFunc,
  node_id : NodeId,
  target : LabelId,
  actual_arity : Int,
) -> Result[Unit, HotVerifyError] {
  if !hot_verify_label_id_is_valid(func, target) {
    return Err(HotVerifyError::InvalidBranchTarget(node_id, target))
  }
  let expected_arity = hot_label_branch_arity(func, target)
  if actual_arity != expected_arity {
    return Err(
      HotVerifyError::InvalidBranchArity(
        node_id, target, actual_arity, expected_arity,
      ),
    )
  }
  Ok(())
}

///|
fn hot_verify_branch_targets(
  func : HotFunc,
  node_id : NodeId,
  targets : Array[LabelId],
  actual_arity : Int,
) -> Result[Unit, HotVerifyError] {
  for target in targets {
    match hot_verify_branch_target(func, node_id, target, actual_arity) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
  }
  Ok(())
}

///|
pub fn hot_verify_core(func : HotFunc) -> Result[Unit, HotVerifyError] {
  if !hot_verify_type_id_is_valid(func, hot_body_result_type(func)) {
    return Err(
      HotVerifyError::InvalidBodyResultType(hot_body_result_type(func)),
    )
  }

  for type_id = 0; type_id < func.types.length(); type_id = type_id + 1 {
    let key = func.types[type_id].to_string()
    match func.type_ids.get(key) {
      Some(mapped) if mapped == type_id => ()
      Some(mapped) =>
        return Err(HotVerifyError::MismatchedTypeKey(type_id, key, mapped))
      None => return Err(HotVerifyError::MissingTypeKey(type_id, key))
    }
  }

  for root_idx = 0; root_idx < func.roots.length(); root_idx = root_idx + 1 {
    let root_id = func.roots[root_idx]
    if !hot_node_is_live(func, root_id) {
      return Err(HotVerifyError::InvalidRoot(root_idx, root_id))
    }
  }

  for label_id = 0; label_id < func.labels.length(); label_id = label_id + 1 {
    let label = func.labels[label_id]
    if !hot_verify_type_id_is_valid(func, label.result_type) {
      return Err(
        HotVerifyError::InvalidLabelResultType(label_id, label.result_type),
      )
    }
    if !hot_node_is_live(func, label.owner) {
      return Err(HotVerifyError::InvalidLabelOwner(label_id, label.owner))
    }
    let owner = hot_node_get(func, label.owner)
    if hot_control_node_label(func, label.owner) != label_id {
      return Err(HotVerifyError::InvalidLabelOwner(label_id, label.owner))
    }
    match label.kind {
      HotLabelKind::BlockLabel if owner.op != HotOp::Block =>
        return Err(
          HotVerifyError::InvalidLabelOwnerKind(label_id, label.kind, owner.op),
        )
      HotLabelKind::LoopLabel if owner.op != HotOp::Loop =>
        return Err(
          HotVerifyError::InvalidLabelOwnerKind(label_id, label.kind, owner.op),
        )
      HotLabelKind::IfLabel if owner.op != HotOp::If =>
        return Err(
          HotVerifyError::InvalidLabelOwnerKind(label_id, label.kind, owner.op),
        )
      HotLabelKind::TryLabel if owner.op != HotOp::Try =>
        return Err(
          HotVerifyError::InvalidLabelOwnerKind(label_id, label.kind, owner.op),
        )
      HotLabelKind::TryTableLabel if owner.op != HotOp::TryTable =>
        return Err(
          HotVerifyError::InvalidLabelOwnerKind(label_id, label.kind, owner.op),
        )
      HotLabelKind::RegionLabel if owner.op != HotOp::Block =>
        return Err(
          HotVerifyError::InvalidLabelOwnerKind(label_id, label.kind, owner.op),
        )
      _ => ()
    }
  }

  for node_id = 0; node_id < func.nodes.length(); node_id = node_id + 1 {
    if !hot_node_is_live(func, node_id) {
      continue
    }
    let node = func.nodes[node_id]
    if !hot_verify_type_id_is_valid(func, node.ty) {
      return Err(HotVerifyError::InvalidNodeType(node_id, node.ty))
    }
    let expected_flags = hot_default_flags_for_op(node.op)
    if node.flags != expected_flags {
      return Err(
        HotVerifyError::InvalidNodeFlags(node_id, node.flags, expected_flags),
      )
    }
    if node.child_base < 0 ||
      node.child_count < 0 ||
      node.child_base + node.child_count > func.children.length() {
      return Err(
        HotVerifyError::InvalidChildSpan(
          node_id,
          node.child_base,
          node.child_count,
        ),
      )
    }
    for slot = 0; slot < node.child_count; slot = slot + 1 {
      let child_id = func.children[node.child_base + slot]
      if child_id == HOT_NONE_NODE {
        continue
      }
      if !hot_node_is_live(func, child_id) {
        return Err(HotVerifyError::InvalidChildRef(node_id, slot, child_id))
      }
    }
    match hot_side_table_kind_for_op(node.op) {
      Some(kind) => {
        let skip_side_table = match node.op {
          HotOp::Atomic =>
            if node.imm1 >= 0 && node.imm1 < func.instr_payloads.length() {
              match hot_instr_payload_get(func, node.imm1).instr {
                Instruction::StructAtomicGet(_, _, _)
                | Instruction::StructAtomicGetS(_, _, _)
                | Instruction::StructAtomicGetU(_, _, _) => true
                _ => false
              }
            } else {
              false
            }
          _ => false
        }
        if !skip_side_table {
          let side_table_id = if node.op == HotOp::TryTable {
            node.imm1
          } else {
            node.imm0
          }
          if !hot_verify_side_table_id_is_valid(func, kind, side_table_id) {
            return Err(
              HotVerifyError::InvalidSideTableRef(node_id, kind, side_table_id),
            )
          }
        }
      }
      None => ()
    }
    if !hot_verify_node_exact_instr_payload(func, node_id) {
      let payload_id = match hot_node_exact_instr_payload_id(func, node_id) {
        Some(id) => id
        None => -1
      }
      return Err(
        HotVerifyError::InvalidSideTableRef(
          node_id,
          HotSideTableKind::InstrPayloadTable,
          payload_id,
        ),
      )
    }
  }

  Ok(())
}

///|
pub fn hot_verify_control(func : HotFunc) -> Result[Unit, HotVerifyError] {
  match hot_verify_core(func) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }

  for node_id = 0; node_id < func.nodes.length(); node_id = node_id + 1 {
    if !hot_node_is_live(func, node_id) {
      continue
    }
    let node = hot_node_get(func, node_id)
    match node.op {
      HotOp::Block | HotOp::Loop | HotOp::If | HotOp::Try | HotOp::TryTable =>
        match hot_verify_control_label_kind(func, node_id, node) {
          Ok(_) => ()
          Err(err) => return Err(err)
        }
      _ => ()
    }

    match node.op {
      HotOp::Block | HotOp::Loop =>
        for slot = 0; slot < node.child_count; slot = slot + 1 {
          let child_id = hot_child_get(func, node_id, slot)
          if child_id == HOT_NONE_NODE {
            return Err(
              HotVerifyError::InvalidControlChild(node_id, slot, child_id),
            )
          }
        }
      HotOp::If => {
        if node.child_count != 3 {
          return Err(
            HotVerifyError::InvalidControlChildCount(
              node_id,
              node.child_count,
              3,
            ),
          )
        }
        let condition_id = hot_child_get(func, node_id, 0)
        if condition_id == HOT_NONE_NODE ||
          !hot_node_is_live(func, condition_id) {
          return Err(
            HotVerifyError::InvalidControlChild(node_id, 0, condition_id),
          )
        }
        let then_region = hot_child_get(func, node_id, 1)
        if !hot_verify_region_holder(func, then_region) {
          return Err(
            HotVerifyError::InvalidControlChild(node_id, 1, then_region),
          )
        }
        let else_region = hot_child_get(func, node_id, 2)
        if else_region != HOT_NONE_NODE &&
          !hot_verify_region_holder(func, else_region) {
          return Err(
            HotVerifyError::InvalidControlChild(node_id, 2, else_region),
          )
        }
      }
      HotOp::Try => {
        if node.child_count != 2 {
          return Err(
            HotVerifyError::InvalidControlChildCount(
              node_id,
              node.child_count,
              2,
            ),
          )
        }
        for slot = 0; slot < 2; slot = slot + 1 {
          let child_id = hot_child_get(func, node_id, slot)
          if slot == 1 && child_id == HOT_NONE_NODE {
            continue
          }
          if !hot_verify_region_holder(func, child_id) {
            return Err(
              HotVerifyError::InvalidControlChild(node_id, slot, child_id),
            )
          }
        }
      }
      HotOp::TryTable => {
        if node.child_count != 2 {
          return Err(
            HotVerifyError::InvalidControlChildCount(
              node_id,
              node.child_count,
              2,
            ),
          )
        }
        for slot = 0; slot < 2; slot = slot + 1 {
          let child_id = hot_child_get(func, node_id, slot)
          if !hot_verify_region_holder(func, child_id) {
            return Err(
              HotVerifyError::InvalidControlChild(node_id, slot, child_id),
            )
          }
        }
        let catch_info = hot_catch_info_get(func, node.imm1)
        for catch_arm in catch_info.catches {
          let target = match catch_arm {
            HotCatchArm::CatchArm(_, label_id)
            | HotCatchArm::CatchRefArm(_, label_id)
            | HotCatchArm::CatchAllArm(label_id)
            | HotCatchArm::CatchAllRefArm(label_id) => label_id
          }
          if target != HOT_IMPLICIT_FUNCTION_LABEL &&
            !hot_verify_label_id_is_valid(func, target) {
            return Err(HotVerifyError::InvalidBranchTarget(node_id, target))
          }
        }
      }
      HotOp::Br
      | HotOp::BrIf
      | HotOp::BrTable
      | HotOp::BrOnNull
      | HotOp::BrOnNonNull
      | HotOp::BrOnCast
      | HotOp::BrOnCastFail
      | HotOp::Delegate => {
        let actual_arity = match
          hot_verify_branch_payload_arity(func, node_id) {
          Some(arity) => arity
          None =>
            return Err(
              HotVerifyError::InvalidControlChildCount(
                node_id,
                node.child_count,
                1,
              ),
            )
        }
        match node.op {
          HotOp::Br =>
            match
              hot_verify_branch_target(func, node_id, node.imm0, actual_arity) {
              Ok(_) => ()
              Err(err) => return Err(err)
            }
          HotOp::Delegate =>
            match
              hot_verify_branch_target(func, node_id, node.imm0, actual_arity) {
              Ok(_) => ()
              Err(err) => return Err(err)
            }
          HotOp::BrIf
          | HotOp::BrOnNull
          | HotOp::BrOnNonNull
          | HotOp::BrOnCast
          | HotOp::BrOnCastFail => {
            let guard_id = hot_child_get(func, node_id, node.child_count - 1)
            if guard_id == HOT_NONE_NODE || !hot_node_is_live(func, guard_id) {
              return Err(
                HotVerifyError::InvalidControlChild(
                  node_id,
                  node.child_count - 1,
                  guard_id,
                ),
              )
            }
            match
              hot_verify_branch_target(func, node_id, node.imm0, actual_arity) {
              Ok(_) => ()
              Err(err) => return Err(err)
            }
          }
          HotOp::BrTable => {
            let selector_id = hot_child_get(func, node_id, node.child_count - 1)
            if selector_id == HOT_NONE_NODE ||
              !hot_node_is_live(func, selector_id) {
              return Err(
                HotVerifyError::InvalidControlChild(
                  node_id,
                  node.child_count - 1,
                  selector_id,
                ),
              )
            }
            let targets = hot_branch_table_targets_for_node(func, node_id)
            let all_targets = targets.copy()
            all_targets.push(hot_branch_table_default_target(func, node.imm0))
            match
              hot_verify_branch_targets(
                func, node_id, all_targets, actual_arity,
              ) {
              Ok(_) => ()
              Err(err) => return Err(err)
            }
          }
          _ => ()
        }
      }
      _ => ()
    }
  }

  Ok(())
}

///|
fn hot_verify_block_id_is_valid(cfg : HotCfg, block_id : BlockId) -> Bool {
  block_id >= 0 && block_id < cfg_block_count(cfg)
}

///|
fn hot_verify_cfg_edge_has_symmetry(
  cfg : HotCfg,
  from : BlockId,
  edge : CfgEdge,
) -> Bool {
  for pred in cfg_predecessor_edges(cfg, edge.block) {
    if pred.block == from && pred.kind == edge.kind {
      return true
    }
  }
  false
}

///|
fn hot_verify_cfg_pred_has_symmetry(
  cfg : HotCfg,
  to : BlockId,
  edge : CfgEdge,
) -> Bool {
  for succ in cfg_successor_edges(cfg, edge.block) {
    if succ.block == to && succ.kind == edge.kind {
      return true
    }
  }
  false
}

///|
fn hot_verify_cfg_block_contains_node(
  cfg : HotCfg,
  block_id : BlockId,
  node_id : NodeId,
) -> Bool {
  for mapped in cfg_block_get(cfg, block_id).nodes {
    if mapped == node_id {
      return true
    }
  }
  false
}

///|
fn hot_verify_node_child_is_region_slot(op : HotOp, slot : Int) -> Bool {
  match op {
    HotOp::Block | HotOp::Loop => true
    HotOp::If => slot == 1 || slot == 2
    HotOp::Try | HotOp::TryTable => slot == 0 || slot == 1
    _ => false
  }
}

///|
fn hot_verify_node_tree_contains(
  func : HotFunc,
  root_id : NodeId,
  needle_id : NodeId,
) -> Bool {
  if root_id == needle_id {
    return true
  }
  if !hot_node_is_live(func, root_id) {
    return false
  }
  let root = hot_node_get(func, root_id)
  for slot = 0; slot < root.child_count; slot = slot + 1 {
    if hot_verify_node_child_is_region_slot(root.op, slot) {
      continue
    }
    let child_id = hot_child_get(func, root_id, slot)
    if child_id == HOT_NONE_NODE || !hot_node_is_live(func, child_id) {
      continue
    }
    if hot_verify_node_tree_contains(func, child_id, needle_id) {
      return true
    }
  }
  false
}

///|
fn hot_verify_cfg_block_for_node_tree(
  func : HotFunc,
  cfg : HotCfg,
  node_id : NodeId,
) -> BlockId? {
  match cfg_block_for_node(cfg, node_id) {
    Some(block_id) => return Some(block_id)
    None => ()
  }
  for block_id = 0; block_id < cfg_block_count(cfg); block_id = block_id + 1 {
    for root_id in cfg_block_get(cfg, block_id).nodes {
      if hot_verify_node_tree_contains(func, root_id, node_id) {
        return Some(block_id)
      }
    }
  }
  None
}

///|
fn hot_verify_region_root_is_valid(
  func : HotFunc,
  entry : CfgRegionRootBlock,
) -> Bool {
  let region_ref = if entry.region_holder == HOT_NONE_NODE {
    HotRegionRef::root()
  } else {
    if !hot_node_is_live(func, entry.region_holder) {
      return false
    }
    match hot_node_get(func, entry.region_holder).op {
      HotOp::Block | HotOp::Loop => { holder: entry.region_holder }
      _ => return false
    }
  }
  entry.slot >= 0 && entry.slot < hot_region_root_count(func, region_ref)
}

///|
pub fn hot_verify_cfg(
  func : HotFunc,
  cfg : HotCfg,
) -> Result[Unit, HotVerifyError] {
  match hot_verify_control(func) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  if !hot_verify_block_id_is_valid(cfg, cfg_entry_block(cfg)) {
    return Err(HotVerifyError::InvalidCfgEntry(cfg_entry_block(cfg)))
  }
  if !hot_verify_block_id_is_valid(cfg, cfg_exit_block(cfg)) {
    return Err(HotVerifyError::InvalidCfgExit(cfg_exit_block(cfg)))
  }
  if !cfg_block_get(cfg, cfg_entry_block(cfg)).is_synthetic {
    return Err(HotVerifyError::InvalidCfgEntry(cfg_entry_block(cfg)))
  }
  if !cfg_block_get(cfg, cfg_exit_block(cfg)).is_synthetic {
    return Err(HotVerifyError::InvalidCfgExit(cfg_exit_block(cfg)))
  }
  match cfg_exceptional_exit_block(cfg) {
    Some(block_id) =>
      if !hot_verify_block_id_is_valid(cfg, block_id) ||
        !cfg_block_get(cfg, block_id).is_synthetic {
        return Err(HotVerifyError::InvalidCfgExit(block_id))
      }
    None => ()
  }
  if cfg.node_to_block.length() != hot_node_count(func) {
    return Err(
      HotVerifyError::InvalidCfgShape(
        "node_to_block",
        cfg.node_to_block.length(),
        hot_node_count(func),
      ),
    )
  }
  for block_id = 0; block_id < cfg_block_count(cfg); block_id = block_id + 1 {
    let block = cfg_block_get(cfg, block_id)
    if block.id != block_id {
      return Err(HotVerifyError::InvalidCfgBlockId(block_id, block.id))
    }
    for node_id in block.nodes {
      if !hot_node_is_live(func, node_id) {
        return Err(HotVerifyError::InvalidCfgBlockNode(block_id, node_id))
      }
      match cfg.node_to_block.get(node_id) {
        Some(mapped) if mapped == block_id => ()
        Some(mapped) =>
          return Err(HotVerifyError::InvalidCfgNodeMapping(node_id, mapped))
        None =>
          return Err(HotVerifyError::InvalidCfgBlockNode(block_id, node_id))
      }
    }
    for succ in block.succs {
      if !hot_verify_block_id_is_valid(cfg, succ.block) {
        return Err(HotVerifyError::InvalidCfgEdge(block_id, succ))
      }
      if !hot_verify_cfg_edge_has_symmetry(cfg, block_id, succ) {
        return Err(HotVerifyError::InvalidCfgEdgeSymmetry(block_id, succ))
      }
    }
    for pred in block.preds {
      if !hot_verify_block_id_is_valid(cfg, pred.block) {
        return Err(HotVerifyError::InvalidCfgEdge(block_id, pred))
      }
      if !hot_verify_cfg_pred_has_symmetry(cfg, block_id, pred) {
        return Err(HotVerifyError::InvalidCfgEdgeSymmetry(block_id, pred))
      }
    }
  }
  for node_id = 0; node_id < cfg.node_to_block.length(); node_id = node_id + 1 {
    let block_id = cfg.node_to_block[node_id]
    if block_id < 0 {
      continue
    }
    if !hot_node_is_live(func, node_id) ||
      !hot_verify_block_id_is_valid(cfg, block_id) ||
      !hot_verify_cfg_block_contains_node(cfg, block_id, node_id) {
      return Err(HotVerifyError::InvalidCfgNodeMapping(node_id, block_id))
    }
  }
  for entry in cfg.region_roots {
    if !hot_verify_block_id_is_valid(cfg, entry.block) ||
      !hot_verify_region_root_is_valid(func, entry) {
      return Err(
        HotVerifyError::InvalidCfgRegionRoot(
          entry.region_holder,
          entry.slot,
          entry.block,
        ),
      )
    }
    let block = cfg_block_get(cfg, entry.block)
    if block.region_holder != entry.region_holder ||
      entry.slot < block.start_slot ||
      entry.slot >= block.end_slot {
      return Err(
        HotVerifyError::InvalidCfgRegionRoot(
          entry.region_holder,
          entry.slot,
          entry.block,
        ),
      )
    }
  }
  Ok(())
}

///|
fn hot_verify_dom_reachable(dom : HotDominators, block_id : BlockId) -> Bool {
  if block_id < 0 || block_id >= dom.reachable.size {
    return false
  }
  bitset_contains(dom.reachable, block_id)
}

///|
pub fn hot_verify_dominators(
  cfg : HotCfg,
  dom : HotDominators,
) -> Result[Unit, HotVerifyError] {
  let block_count = cfg_block_count(cfg)
  if dom.entry_block != cfg_entry_block(cfg) {
    return Err(
      HotVerifyError::InvalidDomEntry(dom.entry_block, cfg_entry_block(cfg)),
    )
  }
  if dom.reachable.size != block_count {
    return Err(
      HotVerifyError::InvalidDomShape(
        "reachable",
        dom.reachable.size,
        block_count,
      ),
    )
  }
  if dom.idoms.length() != block_count {
    return Err(
      HotVerifyError::InvalidDomShape("idoms", dom.idoms.length(), block_count),
    )
  }
  if dom.children.length() != block_count {
    return Err(
      HotVerifyError::InvalidDomShape(
        "children",
        dom.children.length(),
        block_count,
      ),
    )
  }
  if dom.frontiers.length() != block_count {
    return Err(
      HotVerifyError::InvalidDomShape(
        "frontiers",
        dom.frontiers.length(),
        block_count,
      ),
    )
  }
  if dom.dom_preorder.length() != block_count {
    return Err(
      HotVerifyError::InvalidDomShape(
        "dom_preorder",
        dom.dom_preorder.length(),
        block_count,
      ),
    )
  }
  if dom.dom_postorder.length() != block_count {
    return Err(
      HotVerifyError::InvalidDomShape(
        "dom_postorder",
        dom.dom_postorder.length(),
        block_count,
      ),
    )
  }
  if !hot_verify_dom_reachable(dom, dom.entry_block) {
    return Err(HotVerifyError::InvalidDomReachable(dom.entry_block))
  }
  let child_counts = Array::make(block_count, 0)
  for block_id = 0; block_id < block_count; block_id = block_id + 1 {
    if !hot_verify_dom_reachable(dom, block_id) {
      if dom.idoms[block_id] != -1 {
        return Err(
          HotVerifyError::InvalidDomIdom(block_id, dom.idoms[block_id]),
        )
      }
      continue
    }
    if dom.dom_preorder[block_id] < 0 || dom.dom_postorder[block_id] < 0 {
      return Err(HotVerifyError::InvalidDomReachable(block_id))
    }
    if block_id == dom.entry_block {
      if dom.idoms[block_id] != block_id {
        return Err(
          HotVerifyError::InvalidDomIdom(block_id, dom.idoms[block_id]),
        )
      }
    } else {
      let idom = dom.idoms[block_id]
      if !hot_verify_block_id_is_valid(cfg, idom) ||
        !hot_verify_dom_reachable(dom, idom) {
        return Err(HotVerifyError::InvalidDomIdom(block_id, idom))
      }
      if !dom_dominates(dom, idom, block_id) {
        return Err(HotVerifyError::InvalidDomIdom(block_id, idom))
      }
    }
  }
  for parent = 0; parent < block_count; parent = parent + 1 {
    for child in dom.children[parent] {
      if !hot_verify_block_id_is_valid(cfg, child) || dom.idoms[child] != parent {
        return Err(HotVerifyError::InvalidDomChild(parent, child))
      }
      child_counts[child] = child_counts[child] + 1
    }
    for frontier in dom.frontiers[parent] {
      if !hot_verify_block_id_is_valid(cfg, frontier) ||
        !hot_verify_dom_reachable(dom, frontier) {
        return Err(HotVerifyError::InvalidDomFrontier(parent, frontier))
      }
    }
  }
  for block_id = 0; block_id < block_count; block_id = block_id + 1 {
    if !hot_verify_dom_reachable(dom, block_id) || block_id == dom.entry_block {
      continue
    }
    if child_counts[block_id] != 1 {
      return Err(HotVerifyError::InvalidDomChild(dom.idoms[block_id], block_id))
    }
  }
  Ok(())
}

///|
fn hot_verify_ssa_value_is_valid(
  ssa : HotLocalSsa,
  value_id : SsaValueId,
) -> Bool {
  value_id >= 0 && value_id < ssa.value_types.length()
}

///|
fn hot_verify_ssa_phi_is_valid(ssa : HotLocalSsa, phi_id : PhiId) -> Bool {
  phi_id >= 0 && phi_id < ssa.phis.length()
}

///|
fn hot_verify_ssa_value_def_block(
  func : HotFunc,
  cfg : HotCfg,
  ssa : HotLocalSsa,
  value_id : SsaValueId,
) -> BlockId? {
  match ssa.value_origins[value_id] {
    HotSsaValueOrigin::EntryParamDef(_)
    | HotSsaValueOrigin::EntryDefaultInitDef(_) => Some(cfg_entry_block(cfg))
    HotSsaValueOrigin::LocalSetDef(node_id)
    | HotSsaValueOrigin::LocalTeeDef(node_id) =>
      hot_verify_cfg_block_for_node_tree(func, cfg, node_id)
    HotSsaValueOrigin::PhiDef(phi_id) => Some(ssa.phis[phi_id].block)
  }
}

///|
fn hot_verify_ssa_normal_predecessors(
  cfg : HotCfg,
  dom : HotDominators,
  block_id : BlockId,
) -> Array[BlockId] {
  let preds : Array[BlockId] = []
  for pred in cfg_predecessor_edges(cfg, block_id) {
    if pred.kind == CfgEdgeKind::ExceptionalEdge ||
      !dom_dominates(dom, dom.entry_block, pred.block) {
      continue
    }
    preds.push(pred.block)
  }
  preds
}

///|
fn hot_verify_ssa_type_for_local(
  func : HotFunc,
  local_id : LocalId,
) -> Result[ValType, HotVerifyError] {
  match hot_local_type(func, local_id) {
    Some(ty) => Ok(ty)
    None => Err(HotVerifyError::InvalidSsaLocal(local_id))
  }
}

///|
fn hot_verify_ssa_use_value(
  func : HotFunc,
  cfg : HotCfg,
  dom : HotDominators,
  ssa : HotLocalSsa,
  value_id : SsaValueId,
  use_block : BlockId,
) -> Result[Unit, HotVerifyError] {
  if !hot_verify_ssa_value_is_valid(ssa, value_id) {
    return Err(HotVerifyError::InvalidSsaValue(value_id))
  }
  match hot_verify_ssa_value_def_block(func, cfg, ssa, value_id) {
    Some(def_block) =>
      if !dom_dominates(dom, def_block, use_block) {
        return Err(
          HotVerifyError::InvalidSsaDominance(value_id, def_block, use_block),
        )
      }
    None => return Err(HotVerifyError::InvalidSsaValue(value_id))
  }
  Ok(())
}

///|
pub fn hot_verify_ssa(
  func : HotFunc,
  cfg : HotCfg,
  ssa : HotLocalSsa,
) -> Result[Unit, HotVerifyError] {
  match hot_verify_cfg(func, cfg) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  let dom = dom_build(cfg)
  match hot_verify_dominators(cfg, dom) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  if ssa.revision != hot_revision_current(func) {
    return Err(
      HotVerifyError::InvalidSsaRevision(
        ssa.revision,
        hot_revision_current(func),
      ),
    )
  }
  let node_count = hot_node_count(func)
  let local_count = hot_local_count(func)
  let block_count = cfg_block_count(cfg)
  if ssa.local_get_values.length() != node_count {
    return Err(
      HotVerifyError::InvalidSsaShape(
        "local_get_values",
        ssa.local_get_values.length(),
        node_count,
      ),
    )
  }
  if ssa.local_write_defs.length() != node_count {
    return Err(
      HotVerifyError::InvalidSsaShape(
        "local_write_defs",
        ssa.local_write_defs.length(),
        node_count,
      ),
    )
  }
  if ssa.block_phis.length() != block_count {
    return Err(
      HotVerifyError::InvalidSsaShape(
        "block_phis",
        ssa.block_phis.length(),
        block_count,
      ),
    )
  }
  if ssa.entry_defs.length() != local_count {
    return Err(
      HotVerifyError::InvalidSsaShape(
        "entry_defs",
        ssa.entry_defs.length(),
        local_count,
      ),
    )
  }
  if ssa.value_origins.length() != ssa.value_types.length() {
    return Err(
      HotVerifyError::InvalidSsaShape(
        "value_origins",
        ssa.value_origins.length(),
        ssa.value_types.length(),
      ),
    )
  }
  if ssa.value_uses.length() != ssa.value_types.length() {
    return Err(
      HotVerifyError::InvalidSsaShape(
        "value_uses",
        ssa.value_uses.length(),
        ssa.value_types.length(),
      ),
    )
  }
  if ssa.phi_value_ids.length() != ssa.phis.length() {
    return Err(
      HotVerifyError::InvalidSsaShape(
        "phi_value_ids",
        ssa.phi_value_ids.length(),
        ssa.phis.length(),
      ),
    )
  }
  if ssa.phi_inputs.length() != ssa.phis.length() {
    return Err(
      HotVerifyError::InvalidSsaShape(
        "phi_inputs",
        ssa.phi_inputs.length(),
        ssa.phis.length(),
      ),
    )
  }

  for local_id = 0; local_id < local_count; local_id = local_id + 1 {
    let value_id = ssa.entry_defs[local_id]
    if !hot_verify_ssa_value_is_valid(ssa, value_id) {
      return Err(HotVerifyError::InvalidSsaValue(value_id))
    }
    let expected = match hot_verify_ssa_type_for_local(func, local_id) {
      Ok(ty) => ty
      Err(err) => return Err(err)
    }
    if ssa.value_types[value_id] != expected {
      return Err(
        HotVerifyError::InvalidSsaType(
          value_id,
          ssa.value_types[value_id],
          expected,
        ),
      )
    }
  }

  for value_id = 0; value_id < ssa.value_types.length(); value_id = value_id + 1 {
    match ssa.value_origins[value_id] {
      HotSsaValueOrigin::EntryParamDef(local_id)
      | HotSsaValueOrigin::EntryDefaultInitDef(local_id) => {
        if local_id < 0 ||
          local_id >= local_count ||
          ssa.entry_defs[local_id] != value_id {
          return Err(
            HotVerifyError::InvalidSsaValueOrigin(
              value_id,
              ssa.value_origins[value_id],
            ),
          )
        }
        let expected = match hot_verify_ssa_type_for_local(func, local_id) {
          Ok(ty) => ty
          Err(err) => return Err(err)
        }
        if ssa.value_types[value_id] != expected {
          return Err(
            HotVerifyError::InvalidSsaType(
              value_id,
              ssa.value_types[value_id],
              expected,
            ),
          )
        }
      }
      HotSsaValueOrigin::LocalSetDef(node_id)
      | HotSsaValueOrigin::LocalTeeDef(node_id) => {
        if node_id < 0 ||
          node_id >= node_count ||
          !hot_node_is_live(func, node_id) {
          return Err(
            HotVerifyError::InvalidSsaValueOrigin(
              value_id,
              ssa.value_origins[value_id],
            ),
          )
        }
        let node = hot_node_get(func, node_id)
        let is_set_origin = match ssa.value_origins[value_id] {
          HotSsaValueOrigin::LocalSetDef(_) => node.op == HotOp::LocalSet
          HotSsaValueOrigin::LocalTeeDef(_) => node.op == HotOp::LocalTee
          _ => false
        }
        if !is_set_origin || ssa.local_write_defs[node_id] != value_id {
          return Err(
            HotVerifyError::InvalidSsaValueOrigin(
              value_id,
              ssa.value_origins[value_id],
            ),
          )
        }
        let expected = match hot_verify_ssa_type_for_local(func, node.imm0) {
          Ok(ty) => ty
          Err(err) => return Err(err)
        }
        if ssa.value_types[value_id] != expected {
          return Err(
            HotVerifyError::InvalidSsaType(
              value_id,
              ssa.value_types[value_id],
              expected,
            ),
          )
        }
      }
      HotSsaValueOrigin::PhiDef(phi_id) =>
        if !hot_verify_ssa_phi_is_valid(ssa, phi_id) ||
          ssa.phi_value_ids[phi_id] != value_id {
          return Err(
            HotVerifyError::InvalidSsaValueOrigin(
              value_id,
              ssa.value_origins[value_id],
            ),
          )
        }
    }
  }

  for block_id = 0; block_id < block_count; block_id = block_id + 1 {
    let seen_locals = Array::make(local_count, false)
    for phi_id in ssa.block_phis[block_id] {
      if !hot_verify_ssa_phi_is_valid(ssa, phi_id) {
        return Err(HotVerifyError::InvalidSsaPhi(phi_id))
      }
      let phi = ssa.phis[phi_id]
      if phi.block != block_id ||
        phi.local_id < 0 ||
        phi.local_id >= local_count {
        return Err(HotVerifyError::InvalidSsaPhi(phi_id))
      }
      if seen_locals[phi.local_id] {
        return Err(HotVerifyError::InvalidSsaPhi(phi_id))
      }
      seen_locals[phi.local_id] = true
      let value_id = ssa.phi_value_ids[phi_id]
      if !hot_verify_ssa_value_is_valid(ssa, value_id) {
        return Err(HotVerifyError::InvalidSsaValue(value_id))
      }
      let expected = match hot_verify_ssa_type_for_local(func, phi.local_id) {
        Ok(ty) => ty
        Err(err) => return Err(err)
      }
      if ssa.value_types[value_id] != expected {
        return Err(
          HotVerifyError::InvalidSsaType(
            value_id,
            ssa.value_types[value_id],
            expected,
          ),
        )
      }
      let preds = hot_verify_ssa_normal_predecessors(cfg, dom, block_id)
      if ssa.phi_inputs[phi_id].length() != preds.length() {
        return Err(
          HotVerifyError::InvalidSsaPhiAlignment(
            phi_id,
            block_id,
            ssa.phi_inputs[phi_id].length(),
            preds.length(),
          ),
        )
      }
      let seen_preds = Array::make(block_count, false)
      for input in ssa.phi_inputs[phi_id] {
        let mut found_pred = false
        for pred in preds {
          if pred == input.predecessor {
            found_pred = true
            break
          }
        }
        if !found_pred ||
          seen_preds[input.predecessor] ||
          !hot_verify_ssa_value_is_valid(ssa, input.value_id) {
          return Err(
            HotVerifyError::InvalidSsaPhiInput(
              phi_id,
              input.predecessor,
              input.value_id,
            ),
          )
        }
        seen_preds[input.predecessor] = true
        if ssa.value_types[input.value_id] != expected {
          return Err(
            HotVerifyError::InvalidSsaType(
              input.value_id,
              ssa.value_types[input.value_id],
              expected,
            ),
          )
        }
        let mut listed_use = false
        for use_origin in ssa.value_uses[input.value_id] {
          match use_origin {
            HotSsaUseOrigin::PhiInputUse(listed_phi, listed_pred) =>
              if listed_phi == phi_id && listed_pred == input.predecessor {
                listed_use = true
                break
              }
            _ => ()
          }
        }
        if !listed_use {
          return Err(
            HotVerifyError::InvalidSsaUse(
              input.value_id,
              HotSsaUseOrigin::PhiInputUse(phi_id, input.predecessor),
            ),
          )
        }
        match
          hot_verify_ssa_use_value(
            func,
            cfg,
            dom,
            ssa,
            input.value_id,
            input.predecessor,
          ) {
          Ok(_) => ()
          Err(err) => return Err(err)
        }
      }
    }
  }

  for phi_id = 0; phi_id < ssa.phis.length(); phi_id = phi_id + 1 {
    let phi = ssa.phis[phi_id]
    if !hot_verify_block_id_is_valid(cfg, phi.block) ||
      phi.local_id < 0 ||
      phi.local_id >= local_count {
      return Err(HotVerifyError::InvalidSsaPhi(phi_id))
    }
    let mut found = false
    for mapped in ssa.block_phis[phi.block] {
      if mapped == phi_id {
        found = true
        break
      }
    }
    if !found {
      return Err(HotVerifyError::InvalidSsaPhi(phi_id))
    }
  }

  for node_id = 0; node_id < node_count; node_id = node_id + 1 {
    if !hot_node_is_live(func, node_id) {
      continue
    }
    let node = hot_node_get(func, node_id)
    match node.op {
      HotOp::LocalGet => {
        let value_id = ssa.local_get_values[node_id]
        if !hot_verify_ssa_value_is_valid(ssa, value_id) {
          return Err(HotVerifyError::InvalidSsaValue(value_id))
        }
        let expected = match hot_verify_ssa_type_for_local(func, node.imm0) {
          Ok(ty) => ty
          Err(err) => return Err(err)
        }
        if ssa.value_types[value_id] != expected {
          return Err(
            HotVerifyError::InvalidSsaType(
              value_id,
              ssa.value_types[value_id],
              expected,
            ),
          )
        }
        let mut listed_use = false
        for use_origin in ssa.value_uses[value_id] {
          match use_origin {
            HotSsaUseOrigin::LocalGetUse(listed_node) =>
              if listed_node == node_id {
                listed_use = true
                break
              }
            _ => ()
          }
        }
        if !listed_use {
          return Err(
            HotVerifyError::InvalidSsaUse(
              value_id,
              HotSsaUseOrigin::LocalGetUse(node_id),
            ),
          )
        }
        match hot_verify_cfg_block_for_node_tree(func, cfg, node_id) {
          Some(use_block) =>
            match
              hot_verify_ssa_use_value(func, cfg, dom, ssa, value_id, use_block) {
              Ok(_) => ()
              Err(err) => return Err(err)
            }
          None => return Err(HotVerifyError::InvalidSsaNode(node_id))
        }
      }
      HotOp::LocalSet | HotOp::LocalTee => {
        let value_id = ssa.local_write_defs[node_id]
        if !hot_verify_ssa_value_is_valid(ssa, value_id) {
          return Err(HotVerifyError::InvalidSsaValue(value_id))
        }
      }
      _ => ()
    }
  }

  for value_id = 0; value_id < ssa.value_uses.length(); value_id = value_id + 1 {
    for use_origin in ssa.value_uses[value_id] {
      match use_origin {
        HotSsaUseOrigin::LocalGetUse(node_id) =>
          if node_id < 0 ||
            node_id >= node_count ||
            ssa.local_get_values[node_id] != value_id {
            return Err(HotVerifyError::InvalidSsaUse(value_id, use_origin))
          }
        HotSsaUseOrigin::PhiInputUse(phi_id, predecessor) => {
          if !hot_verify_ssa_phi_is_valid(ssa, phi_id) {
            return Err(HotVerifyError::InvalidSsaUse(value_id, use_origin))
          }
          let mut found = false
          for input in ssa.phi_inputs[phi_id] {
            if input.predecessor == predecessor && input.value_id == value_id {
              found = true
              break
            }
          }
          if !found {
            return Err(HotVerifyError::InvalidSsaUse(value_id, use_origin))
          }
        }
      }
    }
  }
  Ok(())
}

///|
pub fn[C] hot_verify_all(
  func : HotFunc,
  cache? : C? = None,
) -> Result[Unit, HotVerifyError] {
  let _ = cache
  match hot_verify_core(func) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  hot_verify_control(func)
}

///|
pub fn hot_verify_core_or_abort(func : HotFunc) -> Unit {
  match hot_verify_core(func) {
    Ok(_) => ()
    Err(err) => abort(err.to_string())
  }
}

///|
pub fn hot_verify_control_or_abort(func : HotFunc) -> Unit {
  match hot_verify_control(func) {
    Ok(_) => ()
    Err(err) => abort(err.to_string())
  }
}

///|
pub fn hot_verify_all_or_abort(func : HotFunc) -> Unit {
  match hot_verify_all(func, cache=Some(())) {
    Ok(_) => ()
    Err(err) => abort(err.to_string())
  }
}
