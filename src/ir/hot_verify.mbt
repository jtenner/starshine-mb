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
} derive(Eq, Show, Debug)

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
    HotOp::BrIf
    | HotOp::BrTable
    | HotOp::BrOnNull
    | HotOp::BrOnNonNull
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
      None => ()
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
          if !hot_verify_label_id_is_valid(func, target) {
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
pub fn[C] hot_verify_cfg(
  func : HotFunc,
  cfg : C,
) -> Result[Unit, HotVerifyError] {
  let _ = cfg
  hot_verify_control(func)
}

///|
pub fn[C, D] hot_verify_dominators(
  cfg : C,
  dom : D,
) -> Result[Unit, HotVerifyError] {
  let _ = cfg
  let _ = dom
  Ok(())
}

///|
pub fn[C, S] hot_verify_ssa(
  func : HotFunc,
  cfg : C,
  ssa : S,
) -> Result[Unit, HotVerifyError] {
  let _ = cfg
  let _ = ssa
  hot_verify_control(func)
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
