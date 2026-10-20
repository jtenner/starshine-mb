///|
// Unique scalar subtrees preserve use-site ordering. Local access lists also
// keep their order when no local occurs on both sides of the permutation.
fn cache_swap_collect_disjoint_local_accesses(
  func : HotFunc,
  uses : HotUseDef,
  node_id : NodeId,
  locals : @hashmap.HashMap[LocalId, Bool],
  collect : Bool,
) -> Bool {
  if uses.node_uses[node_id].length() != 1 {
    return false
  }
  let node = hot_node_get(func, node_id)
  match node.op {
    HotOp::LocalGet | HotOp::LocalSet | HotOp::LocalTee =>
      if collect {
        locals.set(node.imm0, true)
      } else if locals.contains(node.imm0) {
        return false
      }
    _ => ()
  }
  for slot = 0; slot < hot_child_count(func, node_id); slot = slot + 1 {
    let child = hot_child_get(func, node_id, slot)
    if child < 0 ||
      !hot_node_is_live(func, child) ||
      !cache_swap_collect_disjoint_local_accesses(
        func, uses, child, locals, collect,
      ) {
      return false
    }
  }
  true
}

///|
// Scalar permutations retain aggregate effects when the control-flow shape
// and own effects do not change. Disjoint unique scalar subtrees and leaf
// permutations can also patch exact use slots without rebuilding the overlay.
pub fn cache_swap_scalar_operands(
  cache : HotAnalysisCache,
  func : HotFunc,
  node_id : Int32,
  instr~ : Instruction? = None,
) -> Bool {
  if hot_child_count(func, node_id) != 2 {
    return false
  }
  match hot_node_get(func, node_id).op {
    HotOp::Binary | HotOp::Compare => ()
    _ => return false
  }
  cache_bind_func(cache, func)
  let lhs = hot_child_get(func, node_id, 0)
  let rhs = hot_child_get(func, node_id, 1)
  if lhs < 0 ||
    rhs < 0 ||
    !hot_node_is_live(func, lhs) ||
    !hot_node_is_live(func, rhs) {
    return false
  }
  let mut leaves = true
  for child in [lhs, rhs] {
    match hot_node_get(func, child).op {
      HotOp::Const
      | HotOp::RefNull
      | HotOp::RefFunc
      | HotOp::LocalGet
      | HotOp::GlobalGet =>
        if hot_child_count(func, child) != 0 {
          leaves = false
        }
      _ => leaves = false
    }
  }
  let revision = hot_revision_current(func)
  let effects = match cache.effects {
    Some(entry) if entry.built_at_revision == revision => Some(entry.value)
    _ => None
  }
  if !leaves {
    match effects {
      Some(effects) if (
          (effects.node_masks[lhs] | effects.node_masks[rhs]) &
          (EFFECT_MASK_CONTROL | EFFECT_MASK_CALL | EFFECT_MASK_THROW)
        ) ==
        0U => ()
      _ => return false
    }
  }
  let left = hot_node_get(func, lhs)
  let right = hot_node_get(func, rhs)
  // The local read list is ordered. Two occurrences of one local need the
  // general rebuild even though their node-use slots can be exchanged.
  let leaf_uses_unchanged = leaves &&
    lhs != rhs &&
    !(left.op is HotOp::LocalGet &&
    right.op is HotOp::LocalGet &&
    left.imm0 == right.imm0)
  let uses = match cache.use_def {
    Some(entry) if entry.built_at_revision == revision =>
      if leaf_uses_unchanged {
        Some(entry.value)
      } else if !leaves {
        let locals : @hashmap.HashMap[LocalId, Bool] = @hashmap.new()
        if cache_swap_collect_disjoint_local_accesses(
            func,
            entry.value,
            lhs,
            locals,
            true,
          ) &&
          cache_swap_collect_disjoint_local_accesses(
            func,
            entry.value,
            rhs,
            locals,
            false,
          ) {
          Some(entry.value)
        } else {
          None
        }
      } else {
        None
      }
    _ => None
  }
  let before_mask = effects_mask_for_flags(hot_node_flags(func, node_id)) |
    effects_mask_for_node_exact(func, node_id)
  hot_child_set(func, node_id, 0, rhs)
  hot_child_set(func, node_id, 1, lhs)
  match instr {
    Some(instr) => hot_node_exact_instr_set(func, node_id, instr)
    None => ()
  }
  let after_mask = effects_mask_for_flags(hot_node_flags(func, node_id)) |
    effects_mask_for_node_exact(func, node_id)
  cache_invalidate_all(cache)
  cache.owner_roots = Some(func.roots)
  let revision = hot_revision_current(func)
  match uses {
    Some(uses) if before_mask == after_mask => {
      for child in [lhs, rhs] {
        let sites = uses.node_uses[child]
        for idx = 0; idx < sites.length(); idx = idx + 1 {
          let site = sites[idx]
          if site.user == node_id && site.kind is HotUseSlotKind::ChildUseSlot {
            sites[idx] = {
              user: node_id,
              slot: 1 - site.slot,
              kind: site.kind,
            }
          }
        }
      }
      cache.use_def = Some({ built_at_revision: revision, value: uses, })
    }
    _ => ()
  }
  match effects {
    Some(effects) if before_mask == after_mask =>
      cache.effects = Some({ built_at_revision: revision, value: effects, })
    _ => ()
  }
  true
}
