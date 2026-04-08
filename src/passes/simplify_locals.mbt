///|
pub fn simplify_locals_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new(
    "simplify-locals",
    requires=[
      @ir.HotAnalysis::use_def(),
      @ir.HotAnalysis::liveness(),
      @ir.HotAnalysis::ssa(),
    ],
    invalidates=[
      @ir.HotAnalysis::cfg(),
      @ir.HotAnalysis::dominance(),
      @ir.HotAnalysis::liveness(),
      @ir.HotAnalysis::use_def(),
      @ir.HotAnalysis::effects(),
      @ir.HotAnalysis::loop_info(),
      @ir.HotAnalysis::ssa(),
    ],
  )
}

///|
pub fn simplify_locals_summary() -> String {
  "Remove dead local.set/local.tee defs through the hot SSA overlay."
}

///|
priv struct SimplifyLocalsDetachedControlOwner {
  replacement_id : Int
  detached_id : Int
}

///|
fn simplify_locals_is_trivially_removable_value(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Nop
    | @ir.HotOp::Const
    | @ir.HotOp::RefNull
    | @ir.HotOp::RefFunc => true
    _ => false
  }
}

///|
fn simplify_locals_is_trivially_forwardable_value(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Const | @ir.HotOp::RefNull | @ir.HotOp::RefFunc => true
    _ => false
  }
}

///|
fn simplify_locals_replace_with_nop(func : @ir.HotFunc, node_id : Int) -> Unit {
  let nop = @ir.hot_build_nop(func)
  @ir.hot_replace_node(func, node_id, @ir.hot_node_get(func, nop))
}

///|
fn simplify_locals_is_root_node(func : @ir.HotFunc, node_id : Int) -> Bool {
  for idx = 0; idx < @ir.hot_root_count(func); idx = idx + 1 {
    if @ir.hot_root_get(func, idx) == node_id {
      return true
    }
  }
  false
}

///|
fn simplify_locals_local_get_rewrite_target(
  ssa : @ir.HotLocalSsa,
  use_def : @ir.HotUseDef,
  func : @ir.HotFunc,
  node_id : Int,
) -> (Int, Int, Int, Bool)? {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet => ()
    _ => return None
  }
  let value_id = ssa.local_get_values[node_id]
  if value_id < 0 {
    return None
  }
  let uses = @ir.ssa_uses_of_value(ssa, value_id)
  if uses.length() != 1 {
    return None
  }
  match uses[0] {
    @ir.HotSsaUseOrigin::LocalGetUse(get_id) =>
      if get_id != node_id {
        return None
      }
    _ => return None
  }
  match ssa.value_origins[value_id] {
    @ir.HotSsaValueOrigin::LocalTeeDef(tee_id) => {
      let sites = @ir.node_use_sites_borrowed(use_def, tee_id)
      if sites.length() != 1 {
        return None
      }
      let site = sites[0]
      match site.kind {
        @ir.HotUseSlotKind::ChildUseSlot => ()
        _ => return None
      }
      match @ir.hot_node_get(func, site.user).op {
        @ir.HotOp::Drop => ()
        _ => return None
      }
      let child_id = @ir.hot_child_get(func, tee_id, 0)
      if !simplify_locals_is_trivially_forwardable_value(func, child_id) {
        return None
      }
      Some((tee_id, child_id, site.user, false))
    }
    @ir.HotSsaValueOrigin::LocalSetDef(set_id) => {
      if !simplify_locals_is_root_node(func, set_id) ||
        !simplify_locals_is_root_node(func, node_id) {
        return None
      }
      let child_id = @ir.hot_child_get(func, set_id, 0)
      if !simplify_locals_is_trivially_forwardable_value(func, child_id) {
        return None
      }
      Some((set_id, child_id, set_id, true))
    }
    _ => None
  }
}

///|
fn simplify_locals_rehome_detached_control_owners(
  func : @ir.HotFunc,
  owners : Array[SimplifyLocalsDetachedControlOwner],
) -> Unit {
  for owner in owners {
    if owner.replacement_id < 0 ||
      !@ir.hot_node_is_live(func, owner.replacement_id) {
      continue
    }
    if owner.detached_id < 0 || !@ir.hot_node_is_live(func, owner.detached_id) {
      continue
    }
    let detached = @ir.hot_node_get(func, owner.detached_id)
    let label_id = match detached.op {
      @ir.HotOp::Block
      | @ir.HotOp::Loop
      | @ir.HotOp::If
      | @ir.HotOp::Try
      | @ir.HotOp::TryTable =>
        @ir.hot_control_node_label(func, owner.detached_id)
      _ => continue
    }
    @ir.hot_label_owner_set(func, label_id, owner.replacement_id)
  }
}

///|
fn simplify_locals_delete_detached_nodes(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_ids : Array[Int],
) -> Unit {
  let pending = node_ids.copy()
  let mut progress = true
  while progress {
    progress = false
    for idx = 0; idx < pending.length(); idx = idx + 1 {
      let node_id = pending[idx]
      if node_id < 0 {
        continue
      }
      if !@ir.hot_node_is_live(func, node_id) {
        pending[idx] = -1
        continue
      }
      if !pass_node_is_unused(ctx, func, node_id) {
        continue
      }
      let mut referenced = false
      for root_idx = 0
          root_idx < @ir.hot_root_count(func)
          root_idx = root_idx + 1 {
        if @ir.hot_root_get(func, root_idx) == node_id {
          referenced = true
          break
        }
      }
      if referenced {
        continue
      }
      for user_id = 0; user_id < @ir.hot_node_count(func); user_id = user_id + 1 {
        if referenced ||
          !@ir.hot_node_is_live(func, user_id) ||
          user_id == node_id {
          continue
        }
        for slot = 0; slot < @ir.hot_child_count(func, user_id); slot = slot + 1 {
          if @ir.hot_child_get(func, user_id, slot) == node_id {
            referenced = true
            break
          }
        }
      }
      if referenced {
        continue
      }
      @ir.hot_delete_node(func, node_id)
      pending[idx] = -1
      progress = true
    }
  }
}

///|
fn simplify_locals_dead_local_tee_is_safe(
  use_def : @ir.HotUseDef,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let sites = @ir.node_use_sites_borrowed(use_def, node_id)
  if sites.length() != 1 {
    return false
  }
  let site = sites[0]
  match site.kind {
    @ir.HotUseSlotKind::ChildUseSlot => ()
    _ => return false
  }
  match @ir.hot_node_get(func, site.user).op {
    @ir.HotOp::Drop => true
    _ => false
  }
}

///|
fn simplify_locals_dead_local_set_is_safe(
  use_def : @ir.HotUseDef,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  use_def.local_reads[node.imm0].length() == 0
}

///|
fn simplify_locals_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> HotPassResult {
  let ssa = pass_require_ssa(ctx, func)
  let use_def = pass_require_use_def(ctx, func)
  let dead_nodes : Array[Int] = []
  let detached_tee_nodes : Array[Int] = []
  let detached_control_owners : Array[SimplifyLocalsDetachedControlOwner] = []
  let noppable_local_set_nodes : Array[Int] = []
  let noppable_drop_nodes : Array[Int] = []
  let forwarded_local_gets : Array[(Int, Int)] = []
  let forwarded_drop_nodes : Array[Int] = []
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match
      simplify_locals_local_get_rewrite_target(ssa, use_def, func, node_id) {
      Some((def_id, child_id, cleanup_id, cleanup_is_set)) => {
        dead_nodes.push(def_id)
        forwarded_local_gets.push((node_id, child_id))
        if cleanup_is_set {
          noppable_local_set_nodes.push(cleanup_id)
        } else {
          forwarded_drop_nodes.push(cleanup_id)
        }
      }
      None => ()
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => {
        let value_id = match @ir.ssa_maybe_def_for_local_set(ssa, node_id) {
          Some(value_id) => value_id
          None => continue
        }
        if @ir.ssa_uses_of_value(ssa, value_id).length() != 0 {
          continue
        }
        dead_nodes.push(node_id)
        match node.op {
          @ir.HotOp::LocalSet =>
            if !simplify_locals_dead_local_set_is_safe(use_def, func, node_id) {
              ignore(dead_nodes.pop())
            } else if simplify_locals_is_trivially_removable_value(
                func,
                @ir.hot_child_get(func, node_id, 0),
              ) {
              noppable_local_set_nodes.push(node_id)
            }
          @ir.HotOp::LocalTee => {
            if !simplify_locals_dead_local_tee_is_safe(use_def, func, node_id) {
              ignore(dead_nodes.pop())
              continue
            }
            let child_id = @ir.hot_child_get(func, node_id, 0)
            if simplify_locals_is_trivially_removable_value(func, child_id) {
              let sites = @ir.node_use_sites_borrowed(use_def, node_id)
              noppable_drop_nodes.push(sites[0].user)
            }
            if child_id >= 0 && @ir.hot_node_is_live(func, child_id) {
              detached_tee_nodes.push(child_id)
              detached_control_owners.push({
                replacement_id: node_id,
                detached_id: child_id,
              })
            }
          }
          _ => ()
        }
      }
      _ => ()
    }
  }
  if dead_nodes.length() == 0 {
    return HotPassResult::unchanged()
  }
  @ir.ssa_remove_dead_local_defs(func, dead_nodes)
  simplify_locals_rehome_detached_control_owners(func, detached_control_owners)
  for forwarded in forwarded_local_gets {
    let (node_id, child_id) = forwarded
    if @ir.hot_node_is_live(func, node_id) &&
      @ir.hot_node_is_live(func, child_id) {
      @ir.hot_replace_node(func, node_id, @ir.hot_node_get(func, child_id))
    }
  }
  for node_id in noppable_local_set_nodes {
    if @ir.hot_node_is_live(func, node_id) {
      match @ir.hot_node_get(func, node_id).op {
        @ir.HotOp::Drop => simplify_locals_replace_with_nop(func, node_id)
        _ => ()
      }
    }
  }
  for node_id in noppable_drop_nodes {
    if @ir.hot_node_is_live(func, node_id) {
      match @ir.hot_node_get(func, node_id).op {
        @ir.HotOp::Drop => simplify_locals_replace_with_nop(func, node_id)
        _ => ()
      }
    }
  }
  for node_id in forwarded_drop_nodes {
    if @ir.hot_node_is_live(func, node_id) {
      match @ir.hot_node_get(func, node_id).op {
        @ir.HotOp::Drop => simplify_locals_replace_with_nop(func, node_id)
        _ => ()
      }
    }
  }
  @ir.cache_invalidate_all(ctx.cache)
  simplify_locals_delete_detached_nodes(ctx, func, detached_tee_nodes)
  pass_mark_mutated(ctx, func)
  HotPassResult::changed()
}
