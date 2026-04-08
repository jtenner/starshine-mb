///|
pub fn simplify_locals_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new(
    "simplify-locals",
    requires=[
      @ir.HotAnalysis::effects(),
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
enum SimplifyLocalsForwardRewrite {
  ReplaceNode(Int)
  ReplaceChild(Int, Int)
  ReplaceNodeWithTee(Int, Int)
  ReplaceChildWithTee(Int, Int, Int)
} derive(Eq, Show, Debug)

///|
enum SimplifyLocalsForwardCleanup {
  DeadLocalSet(Int)
  DeadDrop(Int)
  NopNode(Int)
} derive(Eq, Show, Debug)

///|
struct SimplifyLocalsForwardTarget {
  def_id : Int
  value_id : Int
  cleanup : SimplifyLocalsForwardCleanup
  rewrite : SimplifyLocalsForwardRewrite
} derive(Eq, Show, Debug)

///|
struct SimplifyLocalsRootUsePath {
  holder_id : Int
  slot : Int
  rewrite : SimplifyLocalsForwardRewrite
} derive(Eq, Show, Debug)

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
fn simplify_locals_same_local_storeback_if_target(
  func : @ir.HotFunc,
  root_idx : Int,
) -> (Int, Int)? {
  let root_id = @ir.hot_root_get(func, root_idx)
  let root = @ir.hot_node_get(func, root_id)
  match root.op {
    @ir.HotOp::LocalSet => ()
    _ => return None
  }
  let if_id = @ir.hot_child_get(func, root_id, 0)
  let if_node = @ir.hot_node_get(func, if_id)
  match if_node.op {
    @ir.HotOp::If => ()
    _ => return None
  }
  if @ir.hot_type_result_arity(func, if_node.ty) != 1 {
    return None
  }
  let else_region = match @ir.hot_region_else_ref(func, if_id) {
    Some(region) => region
    None => return None
  }
  if @ir.hot_region_root_count(func, else_region) != 1 {
    return None
  }
  let else_root = @ir.hot_region_get(func, else_region, 0)
  let else_node = @ir.hot_node_get(func, else_root)
  match else_node.op {
    @ir.HotOp::LocalGet => if else_node.imm0 != root.imm0 { return None }
    _ => return None
  }
  let then_region = @ir.hot_region_then_ref(func, if_id)
  if @ir.hot_region_root_count(func, then_region) == 0 {
    return None
  }
  Some((root_id, if_id))
}

///|
fn simplify_locals_has_explicit_exit(func : @ir.HotFunc, node_id : Int) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Br
    | @ir.HotOp::BrIf
    | @ir.HotOp::BrTable
    | @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail
    | @ir.HotOp::Delegate
    | @ir.HotOp::Return
    | @ir.HotOp::Throw
    | @ir.HotOp::ThrowRef
    | @ir.HotOp::Rethrow => return true
    _ => ()
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    let child_id = @ir.hot_child_get(func, node_id, slot)
    if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
      continue
    }
    if simplify_locals_has_explicit_exit(func, child_id) {
      return true
    }
  }
  false
}

///|
fn simplify_locals_has_nested_local_write(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => return true
    _ => ()
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    let child_id = @ir.hot_child_get(func, node_id, slot)
    if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
      continue
    }
    if simplify_locals_has_nested_local_write(func, child_id) {
      return true
    }
  }
  false
}

///|
fn simplify_locals_is_safe_structured_forward_value(
  node_masks : Array[@ir.EffectMask],
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let mask = node_masks[node_id]
  let allowed = @ir.EFFECT_MASK_LOCAL_STATE | @ir.EFFECT_MASK_CONTROL
  if (mask & allowed) != mask {
    return false
  }
  !simplify_locals_has_nested_local_write(func, node_id)
}

///|
fn simplify_locals_single_root_use_path(
  use_def : @ir.HotUseDef,
  node_masks : Array[@ir.EffectMask],
  func : @ir.HotFunc,
  origin_id : Int,
  current_id : Int,
  replace_parent : Int,
  replace_slot : Int,
) -> SimplifyLocalsRootUsePath? {
  let sites = @ir.node_use_sites_borrowed(use_def, current_id)
  if sites.length() != 1 {
    return None
  }
  let site = sites[0]
  match site.kind {
    @ir.HotUseSlotKind::RootUseSlot => {
      let rewrite = if current_id == origin_id {
        SimplifyLocalsForwardRewrite::ReplaceNode(origin_id)
      } else {
        SimplifyLocalsForwardRewrite::ReplaceChild(replace_parent, replace_slot)
      }
      Some({ holder_id: site.user, slot: site.slot, rewrite })
    }
    @ir.HotUseSlotKind::ChildUseSlot => {
      let next_replace_parent = if replace_parent < 0 {
        site.user
      } else {
        replace_parent
      }
      let next_replace_slot = if replace_parent < 0 {
        site.slot
      } else {
        replace_slot
      }
      for slot = 0; slot < site.slot; slot = slot + 1 {
        let sibling_id = @ir.hot_child_get(func, site.user, slot)
        if sibling_id < 0 || !@ir.hot_node_is_live(func, sibling_id) {
          continue
        }
        if !@ir.effects_is_pure(node_masks[sibling_id]) {
          return None
        }
      }
      if @ir.node_use_count(use_def, site.user) != 1 {
        return None
      }
      simplify_locals_single_root_use_path(
        use_def,
        node_masks,
        func,
        origin_id,
        site.user,
        next_replace_parent,
        next_replace_slot,
      )
    }
  }
}

///|
fn simplify_locals_immediate_next_root_use_path(
  use_def : @ir.HotUseDef,
  node_masks : Array[@ir.EffectMask],
  func : @ir.HotFunc,
  def_id : Int,
  use_id : Int,
) -> SimplifyLocalsRootUsePath? {
  let def_sites = @ir.node_use_sites_borrowed(use_def, def_id)
  if def_sites.length() != 1 {
    return None
  }
  let def_site = def_sites[0]
  match def_site.kind {
    @ir.HotUseSlotKind::RootUseSlot => ()
    _ => return None
  }
  match
    simplify_locals_single_root_use_path(
      use_def, node_masks, func, use_id, use_id, -1, -1,
    ) {
    Some(path) =>
      if path.holder_id != def_site.user || path.slot != def_site.slot + 1 {
        None
      } else {
        Some(path)
      }
    None => None
  }
}

///|
fn simplify_locals_forward_rewrite_to_tee(
  rewrite : SimplifyLocalsForwardRewrite,
  local_id : Int,
) -> SimplifyLocalsForwardRewrite {
  match rewrite {
    SimplifyLocalsForwardRewrite::ReplaceNode(node_id) =>
      SimplifyLocalsForwardRewrite::ReplaceNodeWithTee(node_id, local_id)
    SimplifyLocalsForwardRewrite::ReplaceChild(parent_id, slot) =>
      SimplifyLocalsForwardRewrite::ReplaceChildWithTee(
        parent_id, slot, local_id,
      )
    SimplifyLocalsForwardRewrite::ReplaceNodeWithTee(_, _)
    | SimplifyLocalsForwardRewrite::ReplaceChildWithTee(_, _, _) => rewrite
  }
}

///|
fn simplify_locals_can_preserve_later_reads_with_immediate_tee(
  ssa : @ir.HotLocalSsa,
  use_def : @ir.HotUseDef,
  node_masks : Array[@ir.EffectMask],
  func : @ir.HotFunc,
  value_id : Int,
  immediate_use_id : Int,
  immediate_path : SimplifyLocalsRootUsePath,
) -> Bool {
  let uses = @ir.ssa_uses_of_value(ssa, value_id)
  for value_use in uses {
    match value_use {
      @ir.HotSsaUseOrigin::LocalGetUse(get_id) =>
        if get_id == immediate_use_id {
          continue
        } else {
          match
            simplify_locals_single_root_use_path(
              use_def, node_masks, func, get_id, get_id, -1, -1,
            ) {
            Some(path) =>
              if path.holder_id != immediate_path.holder_id ||
                path.slot <= immediate_path.slot {
                return false
              }
            None => return false
          }
        }
      _ => return false
    }
  }
  true
}

///|
fn simplify_locals_local_get_rewrite_target(
  ssa : @ir.HotLocalSsa,
  use_def : @ir.HotUseDef,
  node_masks : Array[@ir.EffectMask],
  func : @ir.HotFunc,
  node_id : Int,
) -> SimplifyLocalsForwardTarget? {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet => ()
    _ => return None
  }
  let value_id = ssa.local_get_values[node_id]
  if value_id < 0 {
    return None
  }
  match ssa.value_origins[value_id] {
    @ir.HotSsaValueOrigin::LocalTeeDef(tee_id) => {
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
      Some({
        def_id: tee_id,
        value_id: child_id,
        cleanup: SimplifyLocalsForwardCleanup::DeadDrop(site.user),
        rewrite: SimplifyLocalsForwardRewrite::ReplaceNode(node_id),
      })
    }
    @ir.HotSsaValueOrigin::LocalSetDef(set_id) => {
      let child_id = @ir.hot_child_get(func, set_id, 0)
      if !simplify_locals_is_root_node(func, set_id) ||
        !simplify_locals_is_root_node(func, node_id) {
        if !simplify_locals_is_safe_structured_forward_value(
            node_masks, func, child_id,
          ) ||
          simplify_locals_has_explicit_exit(func, child_id) {
          return None
        }
        let uses = @ir.ssa_uses_of_value(ssa, value_id)
        let immediate_path = match
          simplify_locals_immediate_next_root_use_path(
            use_def, node_masks, func, set_id, node_id,
          ) {
          Some(path) => path
          None => return None
        }
        if uses.length() == 1 {
          return Some({
            def_id: set_id,
            value_id: child_id,
            cleanup: SimplifyLocalsForwardCleanup::DeadLocalSet(set_id),
            rewrite: immediate_path.rewrite,
          })
        }
        if !simplify_locals_can_preserve_later_reads_with_immediate_tee(
            ssa, use_def, node_masks, func, value_id, node_id, immediate_path,
          ) {
          return None
        }
        return Some({
          def_id: set_id,
          value_id: child_id,
          cleanup: SimplifyLocalsForwardCleanup::NopNode(set_id),
          rewrite: simplify_locals_forward_rewrite_to_tee(
            immediate_path.rewrite,
            @ir.hot_node_get(func, set_id).imm0,
          ),
        })
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
      if !simplify_locals_is_trivially_forwardable_value(func, child_id) {
        return None
      }
      Some({
        def_id: set_id,
        value_id: child_id,
        cleanup: SimplifyLocalsForwardCleanup::DeadLocalSet(set_id),
        rewrite: SimplifyLocalsForwardRewrite::ReplaceNode(node_id),
      })
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
  let node_masks = pass_require_effect_node_masks(ctx, func)
  let dead_nodes : Array[Int] = []
  let detached_tee_nodes : Array[Int] = []
  let detached_control_owners : Array[SimplifyLocalsDetachedControlOwner] = []
  let noppable_local_set_nodes : Array[Int] = []
  let noppable_drop_nodes : Array[Int] = []
  let forwarded_local_gets : Array[SimplifyLocalsForwardTarget] = []
  let forwarded_drop_nodes : Array[Int] = []
  let forwarded_nop_nodes : Array[Int] = []
  let storeback_if_roots : Array[(Int, Int)] = []
  for root_idx = 0; root_idx < @ir.hot_root_count(func); root_idx = root_idx + 1 {
    match simplify_locals_same_local_storeback_if_target(func, root_idx) {
      Some((root_id, if_id)) => storeback_if_roots.push((root_id, if_id))
      None => ()
    }
  }
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match
      simplify_locals_local_get_rewrite_target(
        ssa, use_def, node_masks, func, node_id,
      ) {
      Some(target) => {
        forwarded_local_gets.push(target)
        match target.cleanup {
          SimplifyLocalsForwardCleanup::DeadLocalSet(node_id) => {
            dead_nodes.push(target.def_id)
            noppable_local_set_nodes.push(node_id)
          }
          SimplifyLocalsForwardCleanup::DeadDrop(node_id) => {
            dead_nodes.push(target.def_id)
            forwarded_drop_nodes.push(node_id)
          }
          SimplifyLocalsForwardCleanup::NopNode(node_id) =>
            forwarded_nop_nodes.push(node_id)
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
  if dead_nodes.length() == 0 &&
    storeback_if_roots.length() == 0 &&
    forwarded_local_gets.length() == 0 {
    return HotPassResult::unchanged()
  }
  @ir.ssa_remove_dead_local_defs(func, dead_nodes)
  simplify_locals_rehome_detached_control_owners(func, detached_control_owners)
  for storeback in storeback_if_roots {
    let (root_id, if_id) = storeback
    if !@ir.hot_node_is_live(func, root_id) ||
      !@ir.hot_node_is_live(func, if_id) {
      continue
    }
    let root = @ir.hot_node_get(func, root_id)
    let then_region = @ir.hot_region_then_ref(func, if_id)
    let then_count = @ir.hot_region_root_count(func, then_region)
    if then_count == 0 {
      continue
    }
    let then_roots : Array[Int] = []
    for idx = 0; idx < then_count - 1; idx = idx + 1 {
      then_roots.push(@ir.hot_region_get(func, then_region, idx))
    }
    let then_value = @ir.hot_region_get(func, then_region, then_count - 1)
    then_roots.push(@ir.hot_build_local_set(func, root.imm0, then_value))
    @ir.hot_region_replace_body(func, then_region, then_roots)
    let else_region = @ir.hot_region_else_ref(func, if_id).unwrap()
    @ir.hot_region_replace_body(func, else_region, [])
    @ir.hot_control_result_type_set(func, if_id, @ir.hot_type_void(func))
    for root_idx = 0
        root_idx < @ir.hot_root_count(func)
        root_idx = root_idx + 1 {
      if @ir.hot_root_get(func, root_idx) == root_id {
        @ir.hot_root_set(func, root_idx, if_id)
        break
      }
    }
  }
  for forwarded in forwarded_local_gets {
    if !@ir.hot_node_is_live(func, forwarded.value_id) {
      continue
    }
    match forwarded.rewrite {
      SimplifyLocalsForwardRewrite::ReplaceNode(node_id) =>
        if @ir.hot_node_is_live(func, node_id) {
          @ir.hot_replace_node(
            func,
            node_id,
            @ir.hot_node_get(func, forwarded.value_id),
          )
        }
      SimplifyLocalsForwardRewrite::ReplaceChild(parent_id, slot) =>
        if @ir.hot_node_is_live(func, parent_id) {
          @ir.hot_child_set(func, parent_id, slot, forwarded.value_id)
        }
      SimplifyLocalsForwardRewrite::ReplaceNodeWithTee(node_id, local_id) =>
        if @ir.hot_node_is_live(func, node_id) {
          let tee = @ir.hot_build_local_tee(func, local_id, forwarded.value_id)
          @ir.hot_replace_node(func, node_id, @ir.hot_node_get(func, tee))
        }
      SimplifyLocalsForwardRewrite::ReplaceChildWithTee(
        parent_id,
        slot,
        local_id
      ) =>
        if @ir.hot_node_is_live(func, parent_id) {
          let tee = @ir.hot_build_local_tee(func, local_id, forwarded.value_id)
          @ir.hot_child_set(func, parent_id, slot, tee)
        }
    }
  }
  @ir.ssa_remove_dead_local_defs(func, dead_nodes)
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
  for node_id in forwarded_nop_nodes {
    if @ir.hot_node_is_live(func, node_id) {
      simplify_locals_replace_with_nop(func, node_id)
    }
  }
  @ir.cache_invalidate_all(ctx.cache)
  simplify_locals_delete_detached_nodes(ctx, func, detached_tee_nodes)
  pass_mark_mutated(ctx, func)
  HotPassResult::changed()
}
