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
  "Sink local.sets into later gets on linear traces, canonicalize equivalent copies, and remove dead local writes without restructuring control."
}

///|
priv struct SimplifyLocalsEffects {
  mask : @ir.EffectMask
  local_reads : Array[Bool]
  local_writes : Array[Bool]
}

///|
priv struct SimplifyLocalsSinkableInfo {
  node_id : Int
  effects : SimplifyLocalsEffects
}

///|
fn simplify_locals_new_sinkables(
  func : @ir.HotFunc,
) -> Array[SimplifyLocalsSinkableInfo?] {
  Array::make(@ir.hot_local_count(func), None)
}

///|
fn simplify_locals_clear_sinkables(
  sinkables : Array[SimplifyLocalsSinkableInfo?],
) -> Unit {
  for idx = 0; idx < sinkables.length(); idx = idx + 1 {
    sinkables[idx] = None
  }
}

///|
fn simplify_locals_collect_local_effects(
  func : @ir.HotFunc,
  node_id : Int,
  local_reads : Array[Bool],
  local_writes : Array[Bool],
) -> Unit {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet =>
      if node.imm0 >= 0 && node.imm0 < local_reads.length() {
        local_reads[node.imm0] = true
      }
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee =>
      if node.imm0 >= 0 && node.imm0 < local_writes.length() {
        local_writes[node.imm0] = true
      }
    _ => ()
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    let child_id = @ir.hot_child_get(func, node_id, slot)
    simplify_locals_collect_local_effects(
      func, child_id, local_reads, local_writes,
    )
  }
}

///|
fn simplify_locals_effects_for_node(
  func : @ir.HotFunc,
  node_id : Int,
) -> SimplifyLocalsEffects {
  let local_reads = Array::make(@ir.hot_local_count(func), false)
  let local_writes = Array::make(@ir.hot_local_count(func), false)
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return { mask: 0U, local_reads, local_writes }
  }
  simplify_locals_collect_local_effects(
    func, node_id, local_reads, local_writes,
  )
  { mask: @ir.effects_for_node(func, node_id), local_reads, local_writes }
}

///|
fn simplify_locals_effects_has(
  mask : @ir.EffectMask,
  bit : @ir.EffectMask,
) -> Bool {
  (mask & bit) != 0U
}

///|
fn simplify_locals_effects_conflict_locals(
  lhs : SimplifyLocalsEffects,
  rhs : SimplifyLocalsEffects,
) -> Bool {
  for idx = 0; idx < lhs.local_reads.length(); idx = idx + 1 {
    if lhs.local_writes[idx] && (rhs.local_reads[idx] || rhs.local_writes[idx]) {
      return true
    }
    if lhs.local_reads[idx] && rhs.local_writes[idx] {
      return true
    }
  }
  false
}

///|
fn simplify_locals_effects_ordered_before(
  lhs : SimplifyLocalsEffects,
  rhs : SimplifyLocalsEffects,
) -> Bool {
  if simplify_locals_effects_has(lhs.mask, @ir.EFFECT_MASK_CALL) ||
    simplify_locals_effects_has(rhs.mask, @ir.EFFECT_MASK_CALL) {
    return true
  }

  let lhs_non_linear = simplify_locals_effects_has(
    lhs.mask,
    @ir.EFFECT_MASK_CONTROL | @ir.EFFECT_MASK_THROW,
  )
  let rhs_non_linear = simplify_locals_effects_has(
    rhs.mask,
    @ir.EFFECT_MASK_CONTROL | @ir.EFFECT_MASK_THROW,
  )
  if (lhs_non_linear || rhs_non_linear) && lhs.mask != 0U && rhs.mask != 0U {
    return true
  }

  if simplify_locals_effects_conflict_locals(lhs, rhs) {
    return true
  }

  if simplify_locals_effects_has(lhs.mask, @ir.EFFECT_MASK_GLOBAL_STATE) &&
    simplify_locals_effects_has(rhs.mask, @ir.EFFECT_MASK_GLOBAL_STATE) {
    return true
  }

  let lhs_reads_memory = simplify_locals_effects_has(
    lhs.mask,
    @ir.EFFECT_MASK_MEMORY_READ,
  )
  let lhs_writes_memory = simplify_locals_effects_has(
    lhs.mask,
    @ir.EFFECT_MASK_MEMORY_WRITE,
  )
  let rhs_reads_memory = simplify_locals_effects_has(
    rhs.mask,
    @ir.EFFECT_MASK_MEMORY_READ,
  )
  let rhs_writes_memory = simplify_locals_effects_has(
    rhs.mask,
    @ir.EFFECT_MASK_MEMORY_WRITE,
  )
  if lhs_writes_memory && (rhs_reads_memory || rhs_writes_memory) {
    return true
  }
  if lhs_reads_memory && rhs_writes_memory {
    return true
  }

  let lhs_reads_table = simplify_locals_effects_has(
    lhs.mask,
    @ir.EFFECT_MASK_TABLE_READ,
  )
  let lhs_writes_table = simplify_locals_effects_has(
    lhs.mask,
    @ir.EFFECT_MASK_TABLE_WRITE,
  )
  let rhs_reads_table = simplify_locals_effects_has(
    rhs.mask,
    @ir.EFFECT_MASK_TABLE_READ,
  )
  let rhs_writes_table = simplify_locals_effects_has(
    rhs.mask,
    @ir.EFFECT_MASK_TABLE_WRITE,
  )
  if lhs_writes_table && (rhs_reads_table || rhs_writes_table) {
    return true
  }
  if lhs_reads_table && rhs_writes_table {
    return true
  }

  let lhs_traps = simplify_locals_effects_has(lhs.mask, @ir.EFFECT_MASK_TRAP)
  let rhs_traps = simplify_locals_effects_has(rhs.mask, @ir.EFFECT_MASK_TRAP)
  if lhs_traps && rhs.mask != 0U {
    return true
  }
  if rhs_traps && lhs.mask != 0U {
    return true
  }

  false
}

///|
fn simplify_locals_invalidate_sinkables(
  func : @ir.HotFunc,
  sinkables : Array[SimplifyLocalsSinkableInfo?],
  effects : SimplifyLocalsEffects,
  skip_local? : Int = -1,
) -> Unit {
  if effects.mask == 0U {
    return
  }
  for idx = 0; idx < sinkables.length(); idx = idx + 1 {
    if idx == skip_local {
      continue
    }
    match sinkables[idx] {
      Some(info) =>
        if !@ir.hot_node_is_live(func, info.node_id) ||
          simplify_locals_effects_ordered_before(info.effects, effects) {
          sinkables[idx] = None
        }
      None => ()
    }
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
fn simplify_locals_make_local_get(
  func : @ir.HotFunc,
  local_id : Int,
) -> @ir.HotNode {
  let replacement_id = @ir.hot_build_local_get(func, local_id)
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
  sinkables : Array[SimplifyLocalsSinkableInfo?],
  first_cycle : Bool,
  get_counts : Array[Int],
  effects : SimplifyLocalsEffects,
) -> Bool {
  let local_id = node.imm0
  let mut changed = false
  match sinkables[local_id] {
    Some(previous_info) =>
      if @ir.hot_node_is_live(func, previous_info.node_id) {
        let previous_node = @ir.hot_node_get(func, previous_info.node_id)
        match previous_node.op {
          @ir.HotOp::LocalSet => {
            let previous_value_id = @ir.hot_child_get(
              func,
              previous_info.node_id,
              0,
            )
            @ir.hot_replace_node(
              func,
              previous_info.node_id,
              simplify_locals_make_drop(func, previous_value_id),
            )
            changed = true
          }
          _ => ()
        }
      }
    None => ()
  }
  sinkables[local_id] = None
  if get_counts[local_id] == 0 {
    return changed
  }
  if first_cycle && get_counts[local_id] > 1 {
    return changed
  }
  sinkables[local_id] = Some({ node_id, effects })
  changed
}

///|
fn simplify_locals_scan_region(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  sinkables : Array[SimplifyLocalsSinkableInfo?],
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
  sinkables : Array[SimplifyLocalsSinkableInfo?],
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

  let original_effects = simplify_locals_effects_for_node(func, node_id)
  let mut current = @ir.hot_node_get(func, node_id)
  match current.op {
    @ir.HotOp::LocalGet => {
      let local_id = current.imm0
      match sinkables[local_id] {
        Some(info) =>
          if @ir.hot_node_is_live(func, info.node_id) {
            let pending_node = @ir.hot_node_get(func, info.node_id)
            match pending_node.op {
              @ir.HotOp::LocalSet => {
                let value_id = @ir.hot_child_get(func, info.node_id, 0)
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
                @ir.hot_replace_node(
                  func,
                  info.node_id,
                  simplify_locals_make_nop(func),
                )
                sinkables[local_id] = None
                changed = true
              }
              _ => sinkables[local_id] = None
            }
          } else {
            sinkables[local_id] = None
          }
        None => ()
      }
      simplify_locals_invalidate_sinkables(func, sinkables, original_effects)
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
  let current_effects = simplify_locals_effects_for_node(func, node_id)
  match current.op {
    @ir.HotOp::LocalSet => {
      simplify_locals_invalidate_sinkables(
        func,
        sinkables,
        current_effects,
        skip_local=current.imm0,
      )
      if simplify_locals_record_local_set(
          func, node_id, current, sinkables, first_cycle, get_counts, current_effects,
        ) {
        changed = true
      }
      changed
    }
    _ => {
      simplify_locals_invalidate_sinkables(func, sinkables, current_effects)
      changed
    }
  }
}

///|
fn simplify_locals_new_equivalences(func : @ir.HotFunc) -> Array[Array[Bool]] {
  let equivalences : Array[Array[Bool]] = []
  for local_id = 0
      local_id < @ir.hot_local_count(func)
      local_id = local_id + 1 {
    let row = Array::make(@ir.hot_local_count(func), false)
    row[local_id] = true
    equivalences.push(row)
  }
  equivalences
}

///|
fn simplify_locals_clone_equivalences(
  equivalences : Array[Array[Bool]],
) -> Array[Array[Bool]] {
  let cloned : Array[Array[Bool]] = []
  for row in equivalences {
    cloned.push(row.copy())
  }
  cloned
}

///|
fn simplify_locals_clear_equivalences(
  equivalences : Array[Array[Bool]],
) -> Unit {
  for row = 0; row < equivalences.length(); row = row + 1 {
    for col = 0; col < equivalences[row].length(); col = col + 1 {
      equivalences[row][col] = row == col
    }
  }
}

///|
fn simplify_locals_reset_equivalent_local(
  equivalences : Array[Array[Bool]],
  local_id : Int,
) -> Unit {
  if local_id < 0 || local_id >= equivalences.length() {
    return
  }
  for idx = 0; idx < equivalences.length(); idx = idx + 1 {
    equivalences[local_id][idx] = false
    equivalences[idx][local_id] = false
  }
  equivalences[local_id][local_id] = true
}

///|
fn simplify_locals_equivalent_check(
  equivalences : Array[Array[Bool]],
  lhs : Int,
  rhs : Int,
) -> Bool {
  lhs >= 0 &&
  rhs >= 0 &&
  lhs < equivalences.length() &&
  rhs < equivalences.length() &&
  equivalences[lhs][rhs]
}

///|
fn simplify_locals_add_equivalence(
  equivalences : Array[Array[Bool]],
  local_id : Int,
  other_local : Int,
) -> Unit {
  if local_id < 0 ||
    other_local < 0 ||
    local_id >= equivalences.length() ||
    other_local >= equivalences.length() {
    return
  }
  let related = equivalences[other_local].copy()
  related[other_local] = true
  equivalences[local_id][local_id] = true
  for idx = 0; idx < related.length(); idx = idx + 1 {
    if related[idx] {
      equivalences[local_id][idx] = true
      equivalences[idx][local_id] = true
    }
  }
}

///|
fn simplify_locals_equivalent_local_get_value(
  func : @ir.HotFunc,
  node_id : Int,
) -> Int? {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet => Some(node.imm0)
    _ => None
  }
}

///|
fn simplify_locals_type_env(ctx : HotPassContext) -> @validate.Env? {
  match ctx.module_ctx {
    Some(module_ctx) =>
      Some(@validate.Env::new().with_types(module_ctx.subtypes))
    None => None
  }
}

///|
fn simplify_locals_local_type_is_subtype(
  env : @validate.Env?,
  func : @ir.HotFunc,
  lhs : Int,
  rhs : Int,
) -> Bool {
  let lhs_type = match @ir.hot_local_type(func, lhs) {
    Some(lhs_type) => lhs_type
    None => return false
  }
  let rhs_type = match @ir.hot_local_type(func, rhs) {
    Some(rhs_type) => rhs_type
    None => return false
  }
  if lhs_type == rhs_type {
    return true
  }
  match env {
    Some(env) => @validate.Match::matches(lhs_type, rhs_type, env)
    None => false
  }
}

///|
fn simplify_locals_get_count_ignoring_current(
  get_counts : Array[Int],
  current_local : Int,
  local_id : Int,
) -> Int {
  let count = get_counts[local_id]
  if local_id == current_local && count > 0 {
    count - 1
  } else {
    count
  }
}

///|
fn simplify_locals_pick_best_equivalent_local(
  env : @validate.Env?,
  func : @ir.HotFunc,
  equivalences : Array[Array[Bool]],
  get_counts : Array[Int],
  local_id : Int,
) -> Int {
  let mut best = local_id
  for candidate = 0
      candidate < equivalences.length()
      candidate = candidate + 1 {
    if !equivalences[local_id][candidate] {
      continue
    }
    if candidate == best ||
      !simplify_locals_local_type_is_subtype(env, func, candidate, best) {
      continue
    }
    let candidate_type = @ir.hot_local_type(func, candidate)
    let best_type = @ir.hot_local_type(func, best)
    let candidate_has_more_gets = simplify_locals_get_count_ignoring_current(
        get_counts, local_id, candidate,
      ) >
      simplify_locals_get_count_ignoring_current(get_counts, local_id, best)
    if candidate_type != best_type || candidate_has_more_gets {
      best = candidate
    }
  }
  best
}

///|
fn simplify_locals_scan_equivalent_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  equivalences : Array[Array[Bool]],
  get_counts : Array[Int],
) -> Bool {
  let mut changed = false
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    if simplify_locals_scan_equivalent_node(
        ctx, func, node_id, equivalences, get_counts,
      ) {
      changed = true
    }
  }
  changed
}

///|
fn simplify_locals_scan_equivalent_current(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  equivalences : Array[Array[Bool]],
  get_counts : Array[Int],
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => {
      let local_id = node.imm0
      let value_id = @ir.hot_child_get(func, node_id, 0)
      match simplify_locals_equivalent_local_get_value(func, value_id) {
        Some(value_local) =>
          if simplify_locals_equivalent_check(
              equivalences, local_id, value_local,
            ) {
            false
          } else {
            simplify_locals_reset_equivalent_local(equivalences, local_id)
            simplify_locals_add_equivalence(equivalences, local_id, value_local)
            false
          }
        None => {
          simplify_locals_reset_equivalent_local(equivalences, local_id)
          false
        }
      }
    }
    @ir.HotOp::LocalGet => {
      let local_id = node.imm0
      let env = simplify_locals_type_env(ctx)
      let best = simplify_locals_pick_best_equivalent_local(
        env, func, equivalences, get_counts, local_id,
      )
      if best == local_id ||
        !simplify_locals_local_type_is_subtype(env, func, best, local_id) {
        return false
      }
      let best_type = @ir.hot_local_type(func, best)
      let old_type = @ir.hot_local_type(func, local_id)
      let has_more_gets = simplify_locals_get_count_ignoring_current(
          get_counts, local_id, best,
        ) >
        simplify_locals_get_count_ignoring_current(
          get_counts, local_id, local_id,
        )
      if !has_more_gets && best_type == old_type {
        return false
      }
      @ir.hot_replace_node(
        func,
        node_id,
        simplify_locals_make_local_get(func, best),
      )
      if best >= 0 && best < get_counts.length() {
        get_counts[best] = get_counts[best] + 1
      }
      if local_id >= 0 &&
        local_id < get_counts.length() &&
        get_counts[local_id] > 0 {
        get_counts[local_id] = get_counts[local_id] - 1
      }
      true
    }
    _ => false
  }
}

///|
fn simplify_locals_scan_equivalent_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  equivalences : Array[Array[Bool]],
  get_counts : Array[Int],
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let mut changed = false
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Block => {
      if simplify_locals_scan_equivalent_region(
          ctx,
          func,
          @ir.hot_region_body_ref(func, node_id),
          equivalences,
          get_counts,
        ) {
        changed = true
      }
      return changed
    }
    @ir.HotOp::If => {
      let condition_id = @ir.hot_child_get(func, node_id, 0)
      if simplify_locals_scan_equivalent_node(
          ctx, func, condition_id, equivalences, get_counts,
        ) {
        changed = true
      }
      let then_equivalences = simplify_locals_clone_equivalences(equivalences)
      if simplify_locals_scan_equivalent_region(
          ctx,
          func,
          @ir.hot_region_then_ref(func, node_id),
          then_equivalences,
          get_counts,
        ) {
        changed = true
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) => {
          let else_equivalences = simplify_locals_clone_equivalences(
            equivalences,
          )
          if simplify_locals_scan_equivalent_region(
              ctx, func, else_ref, else_equivalences, get_counts,
            ) {
            changed = true
          }
        }
        None => ()
      }
      simplify_locals_clear_equivalences(equivalences)
      return changed
    }
    @ir.HotOp::Loop => {
      let loop_equivalences = simplify_locals_new_equivalences(func)
      if simplify_locals_scan_equivalent_region(
          ctx,
          func,
          @ir.hot_region_body_ref(func, node_id),
          loop_equivalences,
          get_counts,
        ) {
        changed = true
      }
      simplify_locals_clear_equivalences(equivalences)
      return changed
    }
    @ir.HotOp::Try => {
      let body_equivalences = simplify_locals_new_equivalences(func)
      if simplify_locals_scan_equivalent_region(
          ctx,
          func,
          @ir.hot_region_body_ref(func, node_id),
          body_equivalences,
          get_counts,
        ) {
        changed = true
      }
      match @ir.hot_region_catch_ref(func, node_id) {
        Some(catch_ref) => {
          let catch_equivalences = simplify_locals_new_equivalences(func)
          if simplify_locals_scan_equivalent_region(
              ctx, func, catch_ref, catch_equivalences, get_counts,
            ) {
            changed = true
          }
        }
        None => ()
      }
      simplify_locals_clear_equivalences(equivalences)
      return changed
    }
    @ir.HotOp::TryTable => {
      let body_equivalences = simplify_locals_new_equivalences(func)
      if simplify_locals_scan_equivalent_region(
          ctx,
          func,
          @ir.hot_region_body_ref(func, node_id),
          body_equivalences,
          get_counts,
        ) {
        changed = true
      }
      let catch_equivalences = simplify_locals_new_equivalences(func)
      if simplify_locals_scan_equivalent_region(
          ctx,
          func,
          @ir.hot_region_catch_list_ref(func, node_id),
          catch_equivalences,
          get_counts,
        ) {
        changed = true
      }
      simplify_locals_clear_equivalences(equivalences)
      return changed
    }
    _ =>
      for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
        let child_id = @ir.hot_child_get(func, node_id, slot)
        if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
          continue
        }
        if simplify_locals_scan_equivalent_node(
            ctx, func, child_id, equivalences, get_counts,
          ) {
          changed = true
        }
      }
  }
  if simplify_locals_scan_equivalent_current(
      ctx, func, node_id, equivalences, get_counts,
    ) {
    changed = true
  }
  changed
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
fn simplify_locals_run_equivalent_cleanup(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> Bool {
  simplify_locals_scan_equivalent_region(
    ctx,
    func,
    @ir.HotRegionRef::root(),
    simplify_locals_new_equivalences(func),
    simplify_locals_count_local_gets(func),
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
        let value_id = @ir.hot_child_get(func, node_id, 0)
        if value_id >= 0 && @ir.hot_node_is_live(func, value_id) {
          let value = @ir.hot_node_get(func, value_id)
          match value.op {
            @ir.HotOp::LocalGet if value.imm0 == node.imm0 => {
              @ir.hot_replace_node(
                func,
                node_id,
                simplify_locals_make_nop(func),
              )
              detached.push(value_id)
              changed = true
              continue
            }
            _ => ()
          }
        }
        if get_counts[node.imm0] != 0 {
          continue
        }
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
        let value_id = @ir.hot_child_get(func, node_id, 0)
        if value_id >= 0 && @ir.hot_node_is_live(func, value_id) {
          let value = @ir.hot_node_get(func, value_id)
          match value.op {
            @ir.HotOp::LocalGet if value.imm0 == node.imm0 => {
              @ir.hot_replace_node(
                func,
                node_id,
                @ir.hot_node_get(func, value_id),
              )
              detached.push(value_id)
              changed = true
              continue
            }
            _ => ()
          }
        }
        if get_counts[node.imm0] != 0 {
          continue
        }
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
    if main_changed || cleanup_changed {
      continue
    }

    let late_changed = simplify_locals_run_equivalent_cleanup(ctx, func)
    let late_cleanup_detached : Array[Int] = []
    let late_cleanup_changed = simplify_locals_run_dead_cleanup(
      func, late_cleanup_detached,
    )
    simplify_locals_delete_detached_nodes(func, late_cleanup_detached)

    if late_changed || late_cleanup_changed {
      changed = true
      continue
    }
    break
  }
  if !changed {
    return HotPassResult::unchanged()
  }
  pass_mark_mutated(ctx, func)
  HotPassResult::changed()
}
