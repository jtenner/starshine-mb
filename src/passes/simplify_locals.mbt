///|
pub fn simplify_locals_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new("simplify-locals", requires=[], invalidates=[
    @ir.HotAnalysis::cfg(),
    @ir.HotAnalysis::dominance(),
    @ir.HotAnalysis::liveness(),
    @ir.HotAnalysis::use_def(),
    @ir.HotAnalysis::effects(),
    @ir.HotAnalysis::loop_info(),
    @ir.HotAnalysis::ssa(),
  ])
}

///|
pub fn simplify_locals_summary() -> String {
  "Sink local.sets into later gets on linear traces and remove dead local writes without restructuring control."
}

///|
fn simplify_locals_new_sinkables(func : @ir.HotFunc) -> Array[Int] {
  Array::make(@ir.hot_local_count(func), -1)
}

///|
fn simplify_locals_clear_sinkables(sinkables : Array[Int]) -> Unit {
  for idx = 0; idx < sinkables.length(); idx = idx + 1 {
    sinkables[idx] = -1
  }
}

///|
fn simplify_locals_make_nop(func : @ir.HotFunc) -> @ir.HotNode {
  let replacement_id = @ir.hot_build_nop(func)
  let replacement = @ir.hot_node_get(func, replacement_id)
  @ir.hot_delete_node(func, replacement_id)
  replacement
}

///|
fn simplify_locals_make_drop(func : @ir.HotFunc, value_id : Int) -> @ir.HotNode {
  let replacement_id = @ir.hot_build_drop(func, value_id)
  let replacement = @ir.hot_node_get(func, replacement_id)
  @ir.hot_delete_node(func, replacement_id)
  replacement
}

///|
fn simplify_locals_make_local_tee(
  func : @ir.HotFunc,
  local_id : Int,
  value_id : Int,
) -> @ir.HotNode {
  let replacement_id = @ir.hot_build_local_tee(func, local_id, value_id)
  let replacement = @ir.hot_node_get(func, replacement_id)
  @ir.hot_delete_node(func, replacement_id)
  replacement
}

///|
fn simplify_locals_make_local_set(
  func : @ir.HotFunc,
  local_id : Int,
  value_id : Int,
) -> @ir.HotNode {
  let replacement_id = @ir.hot_build_local_set(func, local_id, value_id)
  let replacement = @ir.hot_node_get(func, replacement_id)
  @ir.hot_delete_node(func, replacement_id)
  replacement
}

///|
fn simplify_locals_count_local_gets(func : @ir.HotFunc) -> Array[Int] {
  let counts = Array::make(@ir.hot_local_count(func), 0)
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::LocalGet =>
        if node.imm0 >= 0 && node.imm0 < counts.length() {
          counts[node.imm0] = counts[node.imm0] + 1
        }
      _ => ()
    }
  }
  counts
}

///|
fn simplify_locals_value_is_pure(func : @ir.HotFunc, node_id : Int) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return true
  }
  let node = @ir.hot_node_get(func, node_id)
  let op_is_pure = match node.op {
    @ir.HotOp::Nop
    | @ir.HotOp::Const
    | @ir.HotOp::LocalGet
    | @ir.HotOp::GlobalGet
    | @ir.HotOp::Drop
    | @ir.HotOp::Select
    | @ir.HotOp::RefNull
    | @ir.HotOp::RefIsNull
    | @ir.HotOp::RefFunc
    | @ir.HotOp::RefTest
    | @ir.HotOp::RefTestDesc
    | @ir.HotOp::Unary
    | @ir.HotOp::Binary
    | @ir.HotOp::Compare
    | @ir.HotOp::TupleMake
    | @ir.HotOp::TupleExtract
    | @ir.HotOp::StringOp
    | @ir.HotOp::MemorySize
    | @ir.HotOp::TableSize
    | @ir.HotOp::Simd => true
    _ => false
  }
  if !op_is_pure {
    return false
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    let child_id = @ir.hot_child_get(func, node_id, slot)
    if child_id >= 0 &&
      @ir.hot_node_is_live(func, child_id) &&
      !simplify_locals_value_is_pure(func, child_id) {
      return false
    }
  }
  true
}

///|
fn simplify_locals_collect_label_owned_nodes(
  func : @ir.HotFunc,
  owner : Int,
) -> Bool {
  for label_id = 0; label_id < func.labels.length(); label_id = label_id + 1 {
    if @ir.hot_label_owner(func, label_id) == owner {
      return true
    }
  }
  false
}

///|
priv struct SimplifyLocalsDetachedControlOwner {
  replacement_id : Int
  detached_id : Int
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
  func : @ir.HotFunc,
  node_ids : Array[Int],
) -> Unit {
  let pending = node_ids.copy()
  let mut progress = true
  while progress {
    progress = false
    for idx = 0; idx < pending.length(); idx = idx + 1 {
      let node_id = pending[idx]
      if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
        pending[idx] = -1
        continue
      }
      if simplify_locals_collect_label_owned_nodes(func, node_id) {
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
      for user_id = 0
          user_id < @ir.hot_node_count(func) && !referenced
          user_id = user_id + 1 {
        if !@ir.hot_node_is_live(func, user_id) || user_id == node_id {
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
fn simplify_locals_record_local_set(
  func : @ir.HotFunc,
  node_id : Int,
  node : @ir.HotNode,
  sinkables : Array[Int],
  first_cycle : Bool,
  get_counts : Array[Int],
) -> Bool {
  let local_id = node.imm0
  let mut changed = false
  let previous = sinkables[local_id]
  if previous >= 0 && @ir.hot_node_is_live(func, previous) {
    let previous_node = @ir.hot_node_get(func, previous)
    match previous_node.op {
      @ir.HotOp::LocalSet => {
        let previous_value_id = @ir.hot_child_get(func, previous, 0)
        @ir.hot_replace_node(
          func,
          previous,
          simplify_locals_make_drop(func, previous_value_id),
        )
        changed = true
      }
      _ => ()
    }
  }
  sinkables[local_id] = -1
  if get_counts[local_id] == 0 {
    return changed
  }
  if first_cycle && get_counts[local_id] > 1 {
    return changed
  }
  sinkables[local_id] = node_id
  changed
}

///|
fn simplify_locals_scan_region(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  sinkables : Array[Int],
  first_cycle : Bool,
  get_counts : Array[Int],
  detached : Array[Int],
) -> Bool {
  let mut changed = false
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    if simplify_locals_scan_node(
        func, node_id, sinkables, first_cycle, get_counts, detached,
      ) {
      changed = true
    }
  }
  changed
}

///|
fn simplify_locals_scan_node(
  func : @ir.HotFunc,
  node_id : Int,
  sinkables : Array[Int],
  first_cycle : Bool,
  get_counts : Array[Int],
  detached : Array[Int],
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let mut changed = false
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop => {
      if simplify_locals_scan_region(
          func,
          @ir.hot_region_body_ref(func, node_id),
          sinkables,
          first_cycle,
          get_counts,
          detached,
        ) {
        changed = true
      }
      simplify_locals_clear_sinkables(sinkables)
      return changed
    }
    @ir.HotOp::If => {
      let condition_id = @ir.hot_child_get(func, node_id, 0)
      if simplify_locals_scan_node(
          func, condition_id, sinkables, first_cycle, get_counts, detached,
        ) {
        changed = true
      }
      simplify_locals_clear_sinkables(sinkables)
      let then_sinkables = simplify_locals_new_sinkables(func)
      if simplify_locals_scan_region(
          func,
          @ir.hot_region_then_ref(func, node_id),
          then_sinkables,
          first_cycle,
          get_counts,
          detached,
        ) {
        changed = true
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) => {
          let else_sinkables = simplify_locals_new_sinkables(func)
          if simplify_locals_scan_region(
              func, else_ref, else_sinkables, first_cycle, get_counts, detached,
            ) {
            changed = true
          }
        }
        None => ()
      }
      simplify_locals_clear_sinkables(sinkables)
      return changed
    }
    @ir.HotOp::Try => {
      let body_sinkables = simplify_locals_new_sinkables(func)
      if simplify_locals_scan_region(
          func,
          @ir.hot_region_body_ref(func, node_id),
          body_sinkables,
          first_cycle,
          get_counts,
          detached,
        ) {
        changed = true
      }
      match @ir.hot_region_catch_ref(func, node_id) {
        Some(catch_ref) => {
          let catch_sinkables = simplify_locals_new_sinkables(func)
          if simplify_locals_scan_region(
              func, catch_ref, catch_sinkables, first_cycle, get_counts, detached,
            ) {
            changed = true
          }
        }
        None => ()
      }
      simplify_locals_clear_sinkables(sinkables)
      return changed
    }
    @ir.HotOp::TryTable => {
      let body_sinkables = simplify_locals_new_sinkables(func)
      if simplify_locals_scan_region(
          func,
          @ir.hot_region_body_ref(func, node_id),
          body_sinkables,
          first_cycle,
          get_counts,
          detached,
        ) {
        changed = true
      }
      let catch_sinkables = simplify_locals_new_sinkables(func)
      if simplify_locals_scan_region(
          func,
          @ir.hot_region_catch_list_ref(func, node_id),
          catch_sinkables,
          first_cycle,
          get_counts,
          detached,
        ) {
        changed = true
      }
      simplify_locals_clear_sinkables(sinkables)
      return changed
    }
    _ =>
      for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
        let child_id = @ir.hot_child_get(func, node_id, slot)
        if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
          continue
        }
        if simplify_locals_scan_node(
            func, child_id, sinkables, first_cycle, get_counts, detached,
          ) {
          changed = true
        }
      }
  }

  let mut current = @ir.hot_node_get(func, node_id)
  match current.op {
    @ir.HotOp::LocalGet => {
      let local_id = current.imm0
      let pending = sinkables[local_id]
      if pending >= 0 && @ir.hot_node_is_live(func, pending) {
        let pending_node = @ir.hot_node_get(func, pending)
        match pending_node.op {
          @ir.HotOp::LocalSet => {
            let value_id = @ir.hot_child_get(func, pending, 0)
            let one_use = first_cycle || get_counts[local_id] == 1
            if one_use {
              @ir.hot_replace_node(
                func,
                node_id,
                @ir.hot_node_get(func, value_id),
              )
              detached.push(value_id)
            } else {
              @ir.hot_replace_node(
                func,
                node_id,
                simplify_locals_make_local_tee(func, local_id, value_id),
              )
            }
            @ir.hot_replace_node(func, pending, simplify_locals_make_nop(func))
            sinkables[local_id] = -1
            return true
          }
          _ => sinkables[local_id] = -1
        }
      }
      simplify_locals_clear_sinkables(sinkables)
      return changed
    }
    _ => ()
  }

  match current.op {
    @ir.HotOp::Drop => {
      let child_id = @ir.hot_child_get(func, node_id, 0)
      if child_id >= 0 && @ir.hot_node_is_live(func, child_id) {
        let child = @ir.hot_node_get(func, child_id)
        match child.op {
          @ir.HotOp::LocalTee => {
            let value_id = @ir.hot_child_get(func, child_id, 0)
            @ir.hot_replace_node(
              func,
              node_id,
              simplify_locals_make_local_set(func, child.imm0, value_id),
            )
            detached.push(child_id)
            changed = true
          }
          _ => ()
        }
      }
    }
    _ => ()
  }

  current = @ir.hot_node_get(func, node_id)
  match current.op {
    @ir.HotOp::LocalSet => {
      if simplify_locals_record_local_set(
          func, node_id, current, sinkables, first_cycle, get_counts,
        ) {
        changed = true
      }
      changed
    }
    @ir.HotOp::Nop | @ir.HotOp::Const => changed
    _ => {
      simplify_locals_clear_sinkables(sinkables)
      changed
    }
  }
}

///|
fn simplify_locals_run_main_cycle(
  func : @ir.HotFunc,
  first_cycle : Bool,
  detached : Array[Int],
) -> Bool {
  let sinkables = simplify_locals_new_sinkables(func)
  simplify_locals_scan_region(
    func,
    @ir.HotRegionRef::root(),
    sinkables,
    first_cycle,
    simplify_locals_count_local_gets(func),
    detached,
  )
}

///|
fn simplify_locals_run_dead_cleanup(
  func : @ir.HotFunc,
  detached : Array[Int],
) -> Bool {
  let get_counts = simplify_locals_count_local_gets(func)
  let mut changed = false
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::LocalSet => {
        if get_counts[node.imm0] != 0 {
          continue
        }
        let value_id = @ir.hot_child_get(func, node_id, 0)
        if simplify_locals_value_is_pure(func, value_id) {
          @ir.hot_replace_node(func, node_id, simplify_locals_make_nop(func))
          detached.push(value_id)
        } else {
          @ir.hot_replace_node(
            func,
            node_id,
            simplify_locals_make_drop(func, value_id),
          )
        }
        changed = true
      }
      @ir.HotOp::LocalTee => {
        if get_counts[node.imm0] != 0 {
          continue
        }
        let value_id = @ir.hot_child_get(func, node_id, 0)
        @ir.hot_replace_node(func, node_id, @ir.hot_node_get(func, value_id))
        detached.push(value_id)
        changed = true
      }
      _ => ()
    }
  }
  changed
}

///|
fn simplify_locals_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> HotPassResult {
  let mut first_cycle = true
  let mut changed = false
  while true {
    let main_detached : Array[Int] = []
    let main_changed = simplify_locals_run_main_cycle(
      func, first_cycle, main_detached,
    )
    simplify_locals_delete_detached_nodes(func, main_detached)

    let cleanup_detached : Array[Int] = []
    let cleanup_changed = simplify_locals_run_dead_cleanup(
      func, cleanup_detached,
    )
    simplify_locals_delete_detached_nodes(func, cleanup_detached)

    if main_changed || cleanup_changed {
      changed = true
    }
    if first_cycle {
      first_cycle = false
      continue
    }
    if !main_changed && !cleanup_changed {
      break
    }
  }
  if !changed {
    return HotPassResult::unchanged()
  }
  pass_mark_mutated(ctx, func)
  HotPassResult::changed()
}
