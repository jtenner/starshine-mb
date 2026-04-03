///|
pub fn code_pushing_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new("code-pushing")
}

///|
pub fn code_pushing_summary() -> String {
  "Push Binaryen-style SFA `local.set` roots closer to conditional push points with conservative HOT-region rewrites."
}

///|
pub struct CpLocalInfo {
  num_sets : Int
  num_gets : Int
  num_gets_so_far : Int
  saw_get_before_set : Bool
  is_param : Bool
  sfa : Bool
} derive(Eq, Show, Debug)

///|
priv struct CpEffectSummary {
  mask : UInt
  local_reads : @ir.Bitset
  local_writes : @ir.Bitset
  global_reads : @ir.Bitset
  global_writes : @ir.Bitset
}

///|
priv struct CpSummaryCache {
  local_count : Int
  global_count : Int
  live_nodes : Array[Bool]
  ready : Array[Bool]
  summaries : Array[CpEffectSummary]
  explicit_exit_ready : Array[Bool]
  explicit_exit_values : Array[Bool]
  region_explicit_exit_roots_ready : Array[Bool]
  region_explicit_exit_roots_values : Array[Array[Int]]
  dropped_region_owner_ready : Array[Bool]
  dropped_region_owner_values : Array[Int]
  nonvoid_block_root_guard_ready : Array[Bool]
  nonvoid_block_root_guard_values : Array[Bool]
}

///|
priv struct CpBarrierSummary {
  mut mask : UInt
  local_reads : @ir.Bitset
  local_writes : @ir.Bitset
  global_reads : @ir.Bitset
  global_writes : @ir.Bitset
}

///|
priv struct CpBlockOwnerExitSummary {
  mut has_owner_exit : Bool
  mut has_dropped_owner_exit : Bool
  mut has_unsafe_explicit_exit : Bool
}

///|
fn cp_new_local_info(is_param : Bool) -> CpLocalInfo {
  {
    num_sets: 0,
    num_gets: 0,
    num_gets_so_far: 0,
    saw_get_before_set: false,
    is_param,
    sfa: false,
  }
}

///|
fn cp_empty_effect_summary(
  local_count : Int,
  global_count : Int,
) -> CpEffectSummary {
  {
    mask: 0U,
    local_reads: @ir.bitset_new(local_count),
    local_writes: @ir.bitset_new(local_count),
    global_reads: @ir.bitset_new(global_count),
    global_writes: @ir.bitset_new(global_count),
  }
}

///|
fn cp_new_barrier_summary(
  local_count : Int,
  global_count : Int,
) -> CpBarrierSummary {
  {
    mask: 0U,
    local_reads: @ir.bitset_new(local_count),
    local_writes: @ir.bitset_new(local_count),
    global_reads: @ir.bitset_new(global_count),
    global_writes: @ir.bitset_new(global_count),
  }
}

///|
fn cp_bitset_any(bitset : @ir.Bitset) -> Bool {
  for idx = 0; idx < bitset.size; idx = idx + 1 {
    if @ir.bitset_contains(bitset, idx) {
      return true
    }
  }
  false
}

///|
fn cp_bitset_overlaps(lhs : @ir.Bitset, rhs : @ir.Bitset) -> Bool {
  let limit = if lhs.size < rhs.size { lhs.size } else { rhs.size }
  for idx = 0; idx < limit; idx = idx + 1 {
    if @ir.bitset_contains(lhs, idx) && @ir.bitset_contains(rhs, idx) {
      return true
    }
  }
  false
}

///|
fn cp_summary_note_node(
  summary : CpEffectSummary,
  node : @ir.HotNode,
  global_count : Int,
) -> Unit {
  match node.op {
    @ir.HotOp::LocalGet =>
      ignore(@ir.bitset_set(summary.local_reads, node.imm0))
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee =>
      ignore(@ir.bitset_set(summary.local_writes, node.imm0))
    @ir.HotOp::GlobalGet =>
      if node.imm0 >= 0 && node.imm0 < global_count {
        ignore(@ir.bitset_set(summary.global_reads, node.imm0))
      }
    @ir.HotOp::GlobalSet =>
      if node.imm0 >= 0 && node.imm0 < global_count {
        ignore(@ir.bitset_set(summary.global_writes, node.imm0))
      }
    _ => ()
  }
}

///|
fn cp_summary_merge_bits_into(
  dst : CpEffectSummary,
  src : CpEffectSummary,
) -> Unit {
  ignore(@ir.bitset_union_into(dst.local_reads, src.local_reads))
  ignore(@ir.bitset_union_into(dst.local_writes, src.local_writes))
  ignore(@ir.bitset_union_into(dst.global_reads, src.global_reads))
  ignore(@ir.bitset_union_into(dst.global_writes, src.global_writes))
}

///|
fn cp_barrier_merge_summary(
  barrier : CpBarrierSummary,
  summary : CpEffectSummary,
) -> Unit {
  barrier.mask = barrier.mask | summary.mask
  ignore(@ir.bitset_union_into(barrier.local_reads, summary.local_reads))
  ignore(@ir.bitset_union_into(barrier.local_writes, summary.local_writes))
  ignore(@ir.bitset_union_into(barrier.global_reads, summary.global_reads))
  ignore(@ir.bitset_union_into(barrier.global_writes, summary.global_writes))
}

///|
fn cp_barrier_merge_root_summary(
  barrier : CpBarrierSummary,
  cache : CpSummaryCache,
  func : @ir.HotFunc,
  root_id : Int,
  summary : CpEffectSummary,
) -> Unit {
  let effective_mask = if cp_node_has_explicit_exit(cache, func, root_id) {
    summary.mask
  } else {
    summary.mask ^ (summary.mask & @ir.EFFECT_MASK_CONTROL)
  }
  barrier.mask = barrier.mask | effective_mask
  ignore(@ir.bitset_union_into(barrier.local_reads, summary.local_reads))
  ignore(@ir.bitset_union_into(barrier.local_writes, summary.local_writes))
  ignore(@ir.bitset_union_into(barrier.global_reads, summary.global_reads))
  ignore(@ir.bitset_union_into(barrier.global_writes, summary.global_writes))
}

///|
fn cp_max_global_index(func : @ir.HotFunc, live_nodes : Array[Bool]) -> Int {
  let mut max_idx = -1
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !live_nodes[node_id] {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::GlobalGet | @ir.HotOp::GlobalSet =>
        if node.imm0 > max_idx {
          max_idx = node.imm0
        }
      _ => ()
    }
  }
  max_idx + 1
}

///|
fn cp_new_summary_cache(func : @ir.HotFunc) -> CpSummaryCache {
  let node_count = @ir.hot_node_count(func)
  let live_nodes = Array::make(node_count, true)
  for free_id in func.free_nodes {
    if free_id >= 0 && free_id < node_count {
      live_nodes[free_id] = false
    }
  }
  let local_count = @ir.hot_local_count(func)
  let global_count = cp_max_global_index(func, live_nodes)
  let ready = Array::make(node_count, false)
  let summaries : Array[CpEffectSummary] = []
  for idx = 0; idx < node_count; idx = idx + 1 {
    let _ = idx
    summaries.push(cp_empty_effect_summary(local_count, global_count))
  }
  let region_cache_len = node_count + 1
  {
    local_count,
    global_count,
    live_nodes,
    ready,
    summaries,
    explicit_exit_ready: Array::make(node_count, false),
    explicit_exit_values: Array::make(node_count, false),
    region_explicit_exit_roots_ready: Array::make(region_cache_len, false),
    region_explicit_exit_roots_values: Array::make(region_cache_len, []),
    dropped_region_owner_ready: Array::make(region_cache_len, false),
    dropped_region_owner_values: Array::make(region_cache_len, -1),
    nonvoid_block_root_guard_ready: Array::make(node_count, false),
    nonvoid_block_root_guard_values: Array::make(node_count, false),
  }
}

///|
fn cp_node_is_live(cache : CpSummaryCache, node_id : Int) -> Bool {
  node_id >= 0 &&
  node_id < cache.live_nodes.length() &&
  cache.live_nodes[node_id]
}

///|
fn cp_effect_summary_for_node(
  cache : CpSummaryCache,
  func : @ir.HotFunc,
  node_id : Int,
) -> CpEffectSummary {
  if !cp_node_is_live(cache, node_id) {
    abort("code-pushing effect summary requires a live node")
  }
  if cache.ready[node_id] {
    return cache.summaries[node_id]
  }
  let node = func.nodes[node_id]
  let summary : CpEffectSummary = {
    mask: @ir.effects_for_node(func, node_id),
    local_reads: @ir.bitset_new(cache.local_count),
    local_writes: @ir.bitset_new(cache.local_count),
    global_reads: @ir.bitset_new(cache.global_count),
    global_writes: @ir.bitset_new(cache.global_count),
  }
  cp_summary_note_node(summary, node, cache.global_count)
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    let child_id = func.children[node.child_base + slot]
    if !cp_node_is_live(cache, child_id) {
      continue
    }
    cp_summary_merge_bits_into(
      summary,
      cp_effect_summary_for_node(cache, func, child_id),
    )
  }
  cache.summaries[node_id] = summary
  cache.ready[node_id] = true
  summary
}

///|
fn cp_summary_reads_local(summary : CpEffectSummary, local_id : Int) -> Bool {
  local_id >= 0 &&
  local_id < summary.local_reads.size &&
  @ir.bitset_contains(summary.local_reads, local_id)
}

///|
fn cp_summary_writes_local(summary : CpEffectSummary, local_id : Int) -> Bool {
  local_id >= 0 &&
  local_id < summary.local_writes.size &&
  @ir.bitset_contains(summary.local_writes, local_id)
}

///|
fn cp_summary_reads_global(summary : CpEffectSummary, global_id : Int) -> Bool {
  global_id >= 0 &&
  global_id < summary.global_reads.size &&
  @ir.bitset_contains(summary.global_reads, global_id)
}

///|
fn cp_summary_writes_global(summary : CpEffectSummary, global_id : Int) -> Bool {
  global_id >= 0 &&
  global_id < summary.global_writes.size &&
  @ir.bitset_contains(summary.global_writes, global_id)
}

///|
fn cp_has_unremovable_side_effects(summary : CpEffectSummary) -> Bool {
  let unremovable_mask = @ir.EFFECT_MASK_CONTROL |
    @ir.EFFECT_MASK_CALL |
    @ir.EFFECT_MASK_THROW |
    @ir.EFFECT_MASK_TRAP |
    @ir.EFFECT_MASK_MEMORY_WRITE |
    @ir.EFFECT_MASK_TABLE_WRITE
  if (summary.mask & unremovable_mask) != 0U {
    return true
  }
  cp_bitset_any(summary.local_writes) || cp_bitset_any(summary.global_writes)
}

///|
fn cp_summary_has_observable_nonlocal_effects(
  summary : CpEffectSummary,
) -> Bool {
  let observable_mask = @ir.EFFECT_MASK_CONTROL |
    @ir.EFFECT_MASK_CALL |
    @ir.EFFECT_MASK_THROW |
    @ir.EFFECT_MASK_TRAP |
    @ir.EFFECT_MASK_MEMORY_WRITE |
    @ir.EFFECT_MASK_TABLE_WRITE
  if (summary.mask & observable_mask) != 0U {
    return true
  }
  cp_bitset_any(summary.global_writes)
}

///|
fn cp_summary_conflicts_with_barrier(
  moving : CpEffectSummary,
  barrier : CpBarrierSummary,
) -> Bool {
  if (
      barrier.mask &
      (@ir.EFFECT_MASK_CONTROL | @ir.EFFECT_MASK_CALL | @ir.EFFECT_MASK_THROW)
    ) !=
    0U {
    return true
  }
  if (barrier.mask & @ir.EFFECT_MASK_TRAP) != 0U &&
    cp_summary_has_observable_nonlocal_effects(moving) {
    return true
  }
  if cp_bitset_overlaps(moving.local_writes, barrier.local_reads) ||
    cp_bitset_overlaps(moving.local_writes, barrier.local_writes) ||
    cp_bitset_overlaps(moving.local_reads, barrier.local_writes) {
    return true
  }
  if cp_bitset_overlaps(moving.global_writes, barrier.global_reads) ||
    cp_bitset_overlaps(moving.global_writes, barrier.global_writes) ||
    cp_bitset_overlaps(moving.global_reads, barrier.global_writes) {
    return true
  }
  if (moving.mask & @ir.EFFECT_MASK_MEMORY_READ) != 0U &&
    (barrier.mask & (@ir.EFFECT_MASK_MEMORY_WRITE | @ir.EFFECT_MASK_TRAP)) != 0U {
    return true
  }
  if (moving.mask & @ir.EFFECT_MASK_TABLE_READ) != 0U &&
    (barrier.mask & @ir.EFFECT_MASK_TABLE_WRITE) != 0U {
    return true
  }
  false
}

///|
fn cp_note_local_get(infos : Array[CpLocalInfo], local_id : Int) -> Unit {
  let info = infos[local_id]
  infos[local_id] = {
    num_sets: info.num_sets,
    num_gets: info.num_gets + 1,
    num_gets_so_far: info.num_gets_so_far + 1,
    saw_get_before_set: info.saw_get_before_set || info.num_sets == 0,
    is_param: info.is_param,
    sfa: false,
  }
}

///|
fn cp_note_local_set(infos : Array[CpLocalInfo], local_id : Int) -> Unit {
  let info = infos[local_id]
  infos[local_id] = {
    num_sets: info.num_sets + 1,
    num_gets: info.num_gets,
    num_gets_so_far: info.num_gets_so_far,
    saw_get_before_set: info.saw_get_before_set,
    is_param: info.is_param,
    sfa: false,
  }
}

///|
fn cp_visit_node_postorder(
  func : @ir.HotFunc,
  node_id : Int,
  infos : Array[CpLocalInfo],
  seen : Array[Bool],
) -> Unit {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) || seen[node_id] {
    return
  }
  seen[node_id] = true
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    cp_visit_node_postorder(
      func,
      @ir.hot_child_get(func, node_id, slot),
      infos,
      seen,
    )
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet => cp_note_local_get(infos, node.imm0)
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee =>
      cp_note_local_set(infos, node.imm0)
    _ => ()
  }
}

///|
pub fn cp_analyze_locals(func : @ir.HotFunc) -> Array[CpLocalInfo] {
  let infos : Array[CpLocalInfo] = []
  let local_count = @ir.hot_local_count(func)
  let param_count = @ir.hot_param_count(func)
  for local_id = 0; local_id < local_count; local_id = local_id + 1 {
    infos.push(cp_new_local_info(local_id < param_count))
  }
  let seen = Array::make(@ir.hot_node_count(func), false)
  for root_idx = 0; root_idx < @ir.hot_root_count(func); root_idx = root_idx + 1 {
    cp_visit_node_postorder(func, @ir.hot_root_get(func, root_idx), infos, seen)
  }
  for local_id = 0; local_id < infos.length(); local_id = local_id + 1 {
    let info = infos[local_id]
    infos[local_id] = {
      num_sets: info.num_sets,
      num_gets: info.num_gets,
      num_gets_so_far: info.num_gets_so_far,
      saw_get_before_set: info.saw_get_before_set,
      is_param: info.is_param,
      sfa: !info.is_param && info.num_sets == 1 && !info.saw_get_before_set,
    }
  }
  infos
}

///|
pub fn cp_node_reads_local(
  func : @ir.HotFunc,
  node_id : Int,
  local_id : Int,
) -> Bool {
  let cache = cp_new_summary_cache(func)
  cp_summary_reads_local(
    cp_effect_summary_for_node(cache, func, node_id),
    local_id,
  )
}

///|
pub fn cp_node_writes_local(
  func : @ir.HotFunc,
  node_id : Int,
  local_id : Int,
) -> Bool {
  let cache = cp_new_summary_cache(func)
  cp_summary_writes_local(
    cp_effect_summary_for_node(cache, func, node_id),
    local_id,
  )
}

///|
pub fn cp_node_reads_global(
  func : @ir.HotFunc,
  node_id : Int,
  global_id : Int,
) -> Bool {
  let cache = cp_new_summary_cache(func)
  cp_summary_reads_global(
    cp_effect_summary_for_node(cache, func, node_id),
    global_id,
  )
}

///|
pub fn cp_node_writes_global(
  func : @ir.HotFunc,
  node_id : Int,
  global_id : Int,
) -> Bool {
  let cache = cp_new_summary_cache(func)
  cp_summary_writes_global(
    cp_effect_summary_for_node(cache, func, node_id),
    global_id,
  )
}

///|
pub fn cp_node_has_unremovable_side_effects(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let cache = cp_new_summary_cache(func)
  cp_has_unremovable_side_effects(
    cp_effect_summary_for_node(cache, func, node_id),
  )
}

///|
fn cp_region_roots_copy(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Array[Int] {
  let roots : Array[Int] = []
  let mut idx = 0
  while idx < @ir.hot_region_root_count(func, region_ref) {
    roots.push(@ir.hot_region_get(func, region_ref, idx))
    idx = idx + 1
  }
  roots
}

///|
fn cp_node_has_explicit_exit(
  cache : CpSummaryCache,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if !cp_node_is_live(cache, node_id) {
    return false
  }
  if node_id < cache.explicit_exit_ready.length() &&
    cache.explicit_exit_ready[node_id] {
    return cache.explicit_exit_values[node_id]
  }
  let node = func.nodes[node_id]
  let result = match node.op {
    @ir.HotOp::Br
    | @ir.HotOp::BrIf
    | @ir.HotOp::BrTable
    | @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail
    | @ir.HotOp::Return
    | @ir.HotOp::ReturnCall
    | @ir.HotOp::ReturnCallIndirect
    | @ir.HotOp::ReturnCallRef
    | @ir.HotOp::Throw
    | @ir.HotOp::ThrowRef
    | @ir.HotOp::Rethrow
    | @ir.HotOp::Delegate
    | @ir.HotOp::Unreachable => true
    _ => {
      let mut saw_exit = false
      for slot = 0; slot < node.child_count; slot = slot + 1 {
        if cp_node_has_explicit_exit(
            cache,
            func,
            func.children[node.child_base + slot],
          ) {
          saw_exit = true
          break
        }
      }
      saw_exit
    }
  }
  if node_id < cache.explicit_exit_ready.length() {
    cache.explicit_exit_ready[node_id] = true
    cache.explicit_exit_values[node_id] = result
  }
  result
}

///|
fn cp_root_is_unconditional_terminal_explicit_exit(
  cache : CpSummaryCache,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if !cp_node_is_live(cache, node_id) {
    return false
  }
  match func.nodes[node_id].op {
    @ir.HotOp::Br
    | @ir.HotOp::BrTable
    | @ir.HotOp::Return
    | @ir.HotOp::ReturnCall
    | @ir.HotOp::ReturnCallIndirect
    | @ir.HotOp::ReturnCallRef
    | @ir.HotOp::Throw
    | @ir.HotOp::ThrowRef
    | @ir.HotOp::Rethrow
    | @ir.HotOp::Unreachable => true
    _ => false
  }
}

///|
fn cp_region_last_unconditional_terminal_root_idx(
  cache : CpSummaryCache,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  target_idx : Int,
) -> Int {
  let mut last = -1
  let mut idx = 0
  while idx < @ir.hot_region_root_count(func, region_ref) && idx <= target_idx {
    let root_id = @ir.hot_region_get(func, region_ref, idx)
    if cp_root_is_unconditional_terminal_explicit_exit(cache, func, root_id) {
      last = idx
    }
    idx = idx + 1
  }
  last
}

///|
fn cp_active_owners_contains(
  active_owners : Array[Int],
  owner_id : Int,
) -> Bool {
  for active_owner_id in active_owners {
    if active_owner_id == owner_id {
      return true
    }
  }
  false
}

///|
fn cp_dropped_region_owner_id(
  cache : CpSummaryCache,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Int? {
  let holder_id = match @ir.hot_region_holder_block_root(func, region_ref) {
    Some(holder_id) => holder_id
    None => return None
  }
  let cache_slot = holder_id + 1
  if cache_slot >= 0 &&
    cache_slot < cache.dropped_region_owner_ready.length() &&
    cache.dropped_region_owner_ready[cache_slot] {
    let cached = cache.dropped_region_owner_values[cache_slot]
    return if cached >= 0 { Some(cached) } else { None }
  }
  let mut dropped_owner : Int? = None
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !cp_node_is_live(cache, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Drop =>
        if @ir.hot_child_count(func, node_id) > 0 &&
          @ir.hot_child_get(func, node_id, 0) == holder_id {
          dropped_owner = Some(holder_id)
          break
        }
      _ => ()
    }
  }
  if cache_slot >= 0 && cache_slot < cache.dropped_region_owner_ready.length() {
    cache.dropped_region_owner_ready[cache_slot] = true
    cache.dropped_region_owner_values[cache_slot] = match dropped_owner {
      Some(owner_id) => owner_id
      None => -1
    }
  }
  dropped_owner
}

///|
fn cp_branch_exits_block_owner(
  func : @ir.HotFunc,
  owner_id : Int,
  active_owners : Array[Int],
  dropped_region_owner_id : Int?,
  node_id : Int,
) -> Bool {
  let mut saw_owner_target = false
  let mut saw_dropped_region_owner_target = false
  let note_target = fn(label_id : Int) -> Bool {
    let target_owner_id = func.labels[label_id].owner
    if target_owner_id == owner_id {
      saw_owner_target = true
      return false
    }
    if cp_active_owners_contains(active_owners, target_owner_id) {
      return false
    }
    match dropped_region_owner_id {
      Some(dropped_owner_id) if target_owner_id == dropped_owner_id => {
        saw_dropped_region_owner_target = true
        return false
      }
      _ => ()
    }
    true
  }
  let node = func.nodes[node_id]
  match node.op {
    @ir.HotOp::BrTable => {
      let table = func.branch_tables[node.imm0]
      for label_id in table.targets {
        if note_target(label_id) {
          return true
        }
      }
      return note_target(table.default_target)
    }
    _ => return note_target(node.imm0)
  }
  saw_owner_target && !saw_dropped_region_owner_target
}

///|
fn cp_collect_block_owner_exit_summary_for_branch(
  func : @ir.HotFunc,
  owner_id : Int,
  active_owner_marks : Array[Bool],
  dropped_region_owner_id : Int,
  node_id : Int,
  summary : CpBlockOwnerExitSummary,
) -> Unit {
  let node = func.nodes[node_id]
  match node.op {
    @ir.HotOp::BrTable => {
      let table = func.branch_tables[node.imm0]
      for label_id in table.targets {
        let target_owner_id = func.labels[label_id].owner
        if target_owner_id == owner_id {
          summary.has_owner_exit = true
        } else if target_owner_id >= 0 &&
          target_owner_id < active_owner_marks.length() &&
          active_owner_marks[target_owner_id] {
          ()
        } else if dropped_region_owner_id >= 0 &&
          target_owner_id == dropped_region_owner_id {
          summary.has_dropped_owner_exit = true
        } else {
          summary.has_unsafe_explicit_exit = true
        }
        if summary.has_unsafe_explicit_exit {
          return
        }
      }
      let target_owner_id = func.labels[table.default_target].owner
      if target_owner_id == owner_id {
        summary.has_owner_exit = true
      } else if target_owner_id >= 0 &&
        target_owner_id < active_owner_marks.length() &&
        active_owner_marks[target_owner_id] {
        ()
      } else if dropped_region_owner_id >= 0 &&
        target_owner_id == dropped_region_owner_id {
        summary.has_dropped_owner_exit = true
      } else {
        summary.has_unsafe_explicit_exit = true
      }
    }
    _ => {
      let target_owner_id = func.labels[node.imm0].owner
      if target_owner_id == owner_id {
        summary.has_owner_exit = true
      } else if target_owner_id >= 0 &&
        target_owner_id < active_owner_marks.length() &&
        active_owner_marks[target_owner_id] {
        ()
      } else if dropped_region_owner_id >= 0 &&
        target_owner_id == dropped_region_owner_id {
        summary.has_dropped_owner_exit = true
      } else {
        summary.has_unsafe_explicit_exit = true
      }
    }
  }
}

///|
fn cp_collect_block_owner_exit_summary(
  cache : CpSummaryCache,
  func : @ir.HotFunc,
  node_id : Int,
  owner_id : Int,
  active_owner_marks : Array[Bool],
  dropped_region_owner_id : Int,
  summary : CpBlockOwnerExitSummary,
) -> Unit {
  if node_id < 0 ||
    !cp_node_is_live(cache, node_id) ||
    summary.has_unsafe_explicit_exit {
    return
  }
  if !cp_node_has_explicit_exit(cache, func, node_id) {
    return
  }
  let node = func.nodes[node_id]
  match node.op {
    @ir.HotOp::Br
    | @ir.HotOp::BrIf
    | @ir.HotOp::BrTable
    | @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail => {
      cp_collect_block_owner_exit_summary_for_branch(
        func, owner_id, active_owner_marks, dropped_region_owner_id, node_id, summary,
      )
      return
    }
    @ir.HotOp::Return
    | @ir.HotOp::ReturnCall
    | @ir.HotOp::ReturnCallIndirect
    | @ir.HotOp::ReturnCallRef
    | @ir.HotOp::Throw
    | @ir.HotOp::ThrowRef
    | @ir.HotOp::Rethrow
    | @ir.HotOp::Delegate => {
      summary.has_unsafe_explicit_exit = true
      return
    }
    @ir.HotOp::Unreachable => return
    _ => ()
  }
  let pushes_owner = match node.op {
    @ir.HotOp::Block
    | @ir.HotOp::Loop
    | @ir.HotOp::If
    | @ir.HotOp::Try
    | @ir.HotOp::TryTable => true
    _ => false
  }
  if pushes_owner {
    active_owner_marks[node_id] = true
  }
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    cp_collect_block_owner_exit_summary(
      cache,
      func,
      func.children[node.child_base + slot],
      owner_id,
      active_owner_marks,
      dropped_region_owner_id,
      summary,
    )
    if summary.has_unsafe_explicit_exit {
      break
    }
  }
  if !summary.has_unsafe_explicit_exit {
    match node.op {
      @ir.HotOp::Block | @ir.HotOp::Loop =>
        cp_collect_block_owner_exit_summary_for_region(
          cache, func, node_id, owner_id, active_owner_marks, dropped_region_owner_id,
          summary,
        )
      @ir.HotOp::If => {
        let then_holder = func.children[node.child_base + 1]
        cp_collect_block_owner_exit_summary_for_region(
          cache, func, then_holder, owner_id, active_owner_marks, dropped_region_owner_id,
          summary,
        )
        if !summary.has_unsafe_explicit_exit {
          let else_holder = if node.child_count > 2 {
            func.children[node.child_base + 2]
          } else {
            -1
          }
          if else_holder != -1 {
            cp_collect_block_owner_exit_summary_for_region(
              cache, func, else_holder, owner_id, active_owner_marks, dropped_region_owner_id,
              summary,
            )
          }
        }
      }
      @ir.HotOp::Try => {
        let body_holder = func.children[node.child_base]
        cp_collect_block_owner_exit_summary_for_region(
          cache, func, body_holder, owner_id, active_owner_marks, dropped_region_owner_id,
          summary,
        )
        if !summary.has_unsafe_explicit_exit {
          let catch_holder = if node.child_count > 1 {
            func.children[node.child_base + 1]
          } else {
            -1
          }
          if catch_holder != -1 {
            cp_collect_block_owner_exit_summary_for_region(
              cache, func, catch_holder, owner_id, active_owner_marks, dropped_region_owner_id,
              summary,
            )
          }
        }
      }
      @ir.HotOp::TryTable => {
        let body_holder = func.children[node.child_base]
        cp_collect_block_owner_exit_summary_for_region(
          cache, func, body_holder, owner_id, active_owner_marks, dropped_region_owner_id,
          summary,
        )
        if !summary.has_unsafe_explicit_exit {
          let catch_list_holder = func.children[node.child_base + 1]
          cp_collect_block_owner_exit_summary_for_region(
            cache, func, catch_list_holder, owner_id, active_owner_marks, dropped_region_owner_id,
            summary,
          )
        }
      }
      _ => ()
    }
  }
  if pushes_owner {
    active_owner_marks[node_id] = false
  }
}

///|
fn cp_collect_block_owner_exit_summary_for_region(
  cache : CpSummaryCache,
  func : @ir.HotFunc,
  region_holder : Int,
  owner_id : Int,
  active_owner_marks : Array[Bool],
  dropped_region_owner_id : Int,
  summary : CpBlockOwnerExitSummary,
) -> Unit {
  let cache_slot = region_holder + 1
  if !cache.region_explicit_exit_roots_ready[cache_slot] {
    let roots : Array[Int] = []
    if region_holder == -1 {
      for root_id in func.roots {
        if cp_node_has_explicit_exit(cache, func, root_id) {
          roots.push(root_id)
        }
      }
    } else {
      let node = func.nodes[region_holder]
      let body_base = match node.op {
        @ir.HotOp::Loop => {
          let label_id = @ir.hot_control_node_label(func, region_holder)
          if label_id < 0 {
            0
          } else {
            @ir.hot_label_branch_arity(func, label_id)
          }
        }
        _ => 0
      }
      let mut slot = body_base
      while slot < node.child_count {
        let root_id = func.children[node.child_base + slot]
        if cp_node_has_explicit_exit(cache, func, root_id) {
          roots.push(root_id)
        }
        slot = slot + 1
      }
    }
    cache.region_explicit_exit_roots_ready[cache_slot] = true
    cache.region_explicit_exit_roots_values[cache_slot] = roots
  }
  for root_id in cache.region_explicit_exit_roots_values[cache_slot] {
    cp_collect_block_owner_exit_summary(
      cache, func, root_id, owner_id, active_owner_marks, dropped_region_owner_id,
      summary,
    )
    if summary.has_unsafe_explicit_exit {
      return
    }
  }
}

///|
fn cp_block_root_has_only_self_and_dropped_owner_exits(
  cache : CpSummaryCache,
  func : @ir.HotFunc,
  root_id : Int,
  dropped_region_owner_id : Int,
) -> Bool {
  if root_id >= 0 &&
    root_id < cache.nonvoid_block_root_guard_ready.length() &&
    cache.nonvoid_block_root_guard_ready[root_id] {
    return !cache.nonvoid_block_root_guard_values[root_id]
  }
  let summary = {
    has_owner_exit: false,
    has_dropped_owner_exit: false,
    has_unsafe_explicit_exit: false,
  }
  let active_owner_marks = Array::make(@ir.hot_node_count(func), false)
  active_owner_marks[root_id] = true
  cp_collect_block_owner_exit_summary(
    cache, func, root_id, root_id, active_owner_marks, dropped_region_owner_id, summary,
  )
  let result = summary.has_dropped_owner_exit &&
    !summary.has_unsafe_explicit_exit
  let should_guard = (
      summary.has_owner_exit || summary.has_unsafe_explicit_exit
    ) &&
    !result
  if root_id >= 0 && root_id < cache.nonvoid_block_root_guard_ready.length() {
    cache.nonvoid_block_root_guard_ready[root_id] = true
    cache.nonvoid_block_root_guard_values[root_id] = should_guard
  }
  result
}

///|
fn cp_region_has_block_exiting_explicit_exit(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  owner_id : Int,
  active_owners : Array[Int],
  dropped_region_owner_id : Int?,
) -> Bool {
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    let root_id = @ir.hot_region_get(func, region_ref, idx)
    if cp_subtree_has_block_exiting_explicit_exit(
        func, root_id, owner_id, active_owners, dropped_region_owner_id,
      ) {
      return true
    }
  }
  false
}

///|
fn cp_subtree_has_block_exiting_explicit_exit(
  func : @ir.HotFunc,
  node_id : Int,
  owner_id : Int,
  active_owners : Array[Int],
  dropped_region_owner_id : Int?,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Br
    | @ir.HotOp::BrIf
    | @ir.HotOp::BrTable
    | @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail =>
      return cp_branch_exits_block_owner(
        func, owner_id, active_owners, dropped_region_owner_id, node_id,
      )
    @ir.HotOp::Return
    | @ir.HotOp::ReturnCall
    | @ir.HotOp::ReturnCallIndirect
    | @ir.HotOp::ReturnCallRef
    | @ir.HotOp::Throw
    | @ir.HotOp::Rethrow
    | @ir.HotOp::ThrowRef
    | @ir.HotOp::Delegate => return true
    @ir.HotOp::Unreachable => return false
    _ => ()
  }
  let pushes_owner = match node.op {
    @ir.HotOp::Block
    | @ir.HotOp::Loop
    | @ir.HotOp::If
    | @ir.HotOp::Try
    | @ir.HotOp::TryTable => true
    _ => false
  }
  if pushes_owner {
    active_owners.push(node_id)
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    if cp_subtree_has_block_exiting_explicit_exit(
        func,
        @ir.hot_child_get(func, node_id, slot),
        owner_id,
        active_owners,
        dropped_region_owner_id,
      ) {
      if pushes_owner {
        ignore(active_owners.pop())
      }
      return true
    }
  }
  let exits_owner = match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      cp_region_has_block_exiting_explicit_exit(
        func,
        @ir.hot_region_body_ref(func, node_id),
        owner_id,
        active_owners,
        dropped_region_owner_id,
      )
    @ir.HotOp::If => {
      let then_exits_owner = cp_region_has_block_exiting_explicit_exit(
        func,
        @ir.hot_region_then_ref(func, node_id),
        owner_id,
        active_owners,
        dropped_region_owner_id,
      )
      let else_exits_owner = match @ir.hot_region_else_ref(func, node_id) {
        Some(region_ref) =>
          cp_region_has_block_exiting_explicit_exit(
            func, region_ref, owner_id, active_owners, dropped_region_owner_id,
          )
        None => false
      }
      then_exits_owner || else_exits_owner
    }
    @ir.HotOp::Try => {
      let body_exits_owner = cp_region_has_block_exiting_explicit_exit(
        func,
        @ir.hot_region_body_ref(func, node_id),
        owner_id,
        active_owners,
        dropped_region_owner_id,
      )
      let catch_exits_owner = match @ir.hot_region_catch_ref(func, node_id) {
        Some(region_ref) =>
          cp_region_has_block_exiting_explicit_exit(
            func, region_ref, owner_id, active_owners, dropped_region_owner_id,
          )
        None => false
      }
      body_exits_owner || catch_exits_owner
    }
    @ir.HotOp::TryTable =>
      cp_region_has_block_exiting_explicit_exit(
        func,
        @ir.hot_region_body_ref(func, node_id),
        owner_id,
        active_owners,
        dropped_region_owner_id,
      ) ||
      cp_region_has_block_exiting_explicit_exit(
        func,
        @ir.hot_region_catch_list_ref(func, node_id),
        owner_id,
        active_owners,
        dropped_region_owner_id,
      )
    _ => false
  }
  if pushes_owner {
    ignore(active_owners.pop())
  }
  exits_owner
}

///|
fn cp_nonvoid_prefix_has_explicit_exit_guard(
  cache : CpSummaryCache,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  target_idx : Int,
) -> Bool {
  let dropped_region_owner_id = match
    cp_dropped_region_owner_id(cache, func, region_ref) {
    Some(owner_id) => owner_id
    None => -1
  }
  let mut idx = cp_region_last_unconditional_terminal_root_idx(
      cache, func, region_ref, target_idx,
    ) +
    1
  while idx < @ir.hot_region_root_count(func, region_ref) && idx <= target_idx {
    let root_id = @ir.hot_region_get(func, region_ref, idx)
    let root_node = @ir.hot_node_get(func, root_id)
    let root_summary = cp_effect_summary_for_node(cache, func, root_id)
    match root_node.op {
      @ir.HotOp::Drop => ()
      @ir.HotOp::Block =>
        if (root_summary.mask & @ir.EFFECT_MASK_CONTROL) != 0U &&
          !cp_block_root_has_only_self_and_dropped_owner_exits(
            cache, func, root_id, dropped_region_owner_id,
          ) {
          return true
        }
      _ =>
        if (root_summary.mask & @ir.EFFECT_MASK_CONTROL) != 0U &&
          cp_node_has_explicit_exit(cache, func, root_id) &&
          !cp_root_is_unconditional_terminal_explicit_exit(cache, func, root_id) {
          return true
        }
    }
    idx = idx + 1
  }
  false
}

///|
fn cp_node_id_arrays_equal(lhs : Array[Int], rhs : Array[Int]) -> Bool {
  if lhs.length() != rhs.length() {
    return false
  }
  let mut idx = 0
  while idx < lhs.length() {
    if lhs[idx] != rhs[idx] {
      return false
    }
    idx = idx + 1
  }
  true
}

///|
fn cp_root_pushable_local(
  infos : Array[CpLocalInfo],
  cache : CpSummaryCache,
  func : @ir.HotFunc,
  root_id : Int,
) -> Int? {
  if root_id < 0 || !@ir.hot_node_is_live(func, root_id) {
    return None
  }
  let node = @ir.hot_node_get(func, root_id)
  match node.op {
    @ir.HotOp::LocalSet => ()
    _ => return None
  }
  if node.imm0 < 0 || node.imm0 >= infos.length() || !infos[node.imm0].sfa {
    return None
  }
  if @ir.hot_child_count(func, root_id) == 0 {
    return Some(node.imm0)
  }
  let value_id = @ir.hot_child_get(func, root_id, 0)
  if value_id < 0 || !@ir.hot_node_is_live(func, value_id) {
    return Some(node.imm0)
  }
  let value_summary = cp_effect_summary_for_node(cache, func, value_id)
  if cp_has_unremovable_side_effects(value_summary) {
    return None
  }
  if (
      value_summary.mask &
      (
        @ir.EFFECT_MASK_CONTROL |
        @ir.EFFECT_MASK_CALL |
        @ir.EFFECT_MASK_THROW |
        @ir.EFFECT_MASK_TRAP |
        @ir.EFFECT_MASK_MEMORY_WRITE |
        @ir.EFFECT_MASK_TABLE_WRITE
      )
    ) !=
    0U {
    return None
  }
  Some(node.imm0)
}

///|
fn cp_region_reads_local(
  cache : CpSummaryCache,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  local_id : Int,
) -> Bool {
  let mut idx = 0
  while idx < @ir.hot_region_root_count(func, region_ref) {
    if cp_summary_reads_local(
        cp_effect_summary_for_node(
          cache,
          func,
          @ir.hot_region_get(func, region_ref, idx),
        ),
        local_id,
      ) {
      return true
    }
    idx = idx + 1
  }
  false
}

///|
fn cp_region_reads_local_after_index(
  cache : CpSummaryCache,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  start_idx : Int,
  local_id : Int,
) -> Bool {
  let mut idx = start_idx
  while idx < @ir.hot_region_root_count(func, region_ref) {
    if cp_summary_reads_local(
        cp_effect_summary_for_node(
          cache,
          func,
          @ir.hot_region_get(func, region_ref, idx),
        ),
        local_id,
      ) {
      return true
    }
    idx = idx + 1
  }
  false
}

///|
fn cp_root_is_trivial_dead_move_gap(
  cache : CpSummaryCache,
  func : @ir.HotFunc,
  root_id : Int,
) -> Bool {
  if root_id < 0 || !@ir.hot_node_is_live(func, root_id) {
    return true
  }
  if cp_node_has_explicit_exit(cache, func, root_id) {
    return false
  }
  let summary = cp_effect_summary_for_node(cache, func, root_id)
  if cp_bitset_any(summary.local_reads) ||
    cp_bitset_any(summary.local_writes) ||
    cp_bitset_any(summary.global_reads) ||
    cp_bitset_any(summary.global_writes) {
    return false
  }
  let noncontrol_mask = summary.mask ^ (summary.mask & @ir.EFFECT_MASK_CONTROL)
  noncontrol_mask == 0U
}

///|
fn cp_summary_conflicts_with_dead_move_gap(
  moving : CpEffectSummary,
  gap : CpEffectSummary,
) -> Bool {
  let blocked_mask = @ir.EFFECT_MASK_CALL |
    @ir.EFFECT_MASK_THROW |
    @ir.EFFECT_MASK_TRAP |
    @ir.EFFECT_MASK_MEMORY_WRITE |
    @ir.EFFECT_MASK_TABLE_WRITE
  if (gap.mask & blocked_mask) != 0U {
    return true
  }
  if cp_bitset_any(gap.global_reads) || cp_bitset_any(gap.global_writes) {
    return true
  }
  if cp_bitset_overlaps(moving.local_writes, gap.local_reads) ||
    cp_bitset_overlaps(moving.local_writes, gap.local_writes) ||
    cp_bitset_overlaps(moving.local_reads, gap.local_writes) {
    return true
  }
  if cp_bitset_overlaps(moving.global_writes, gap.global_reads) ||
    cp_bitset_overlaps(moving.global_writes, gap.global_writes) ||
    cp_bitset_overlaps(moving.global_reads, gap.global_writes) {
    return true
  }
  if (moving.mask & @ir.EFFECT_MASK_MEMORY_READ) != 0U &&
    (gap.mask & (@ir.EFFECT_MASK_MEMORY_WRITE | @ir.EFFECT_MASK_TRAP)) != 0U {
    return true
  }
  if (moving.mask & @ir.EFFECT_MASK_TABLE_READ) != 0U &&
    (gap.mask & @ir.EFFECT_MASK_TABLE_WRITE) != 0U {
    return true
  }
  false
}

///|
fn cp_region_dead_move_gap_is_safe(
  cache : CpSummaryCache,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  source_idx : Int,
  target_idx : Int,
  moving_summary : CpEffectSummary,
) -> Bool {
  let mut idx = source_idx + 1
  while idx < target_idx {
    let root_id = @ir.hot_region_get(func, region_ref, idx)
    if !cp_root_is_trivial_dead_move_gap(cache, func, root_id) &&
      cp_summary_conflicts_with_dead_move_gap(
        moving_summary,
        cp_effect_summary_for_node(cache, func, root_id),
      ) {
      return false
    }
    idx = idx + 1
  }
  true
}

///|
fn cp_region_has_terminal_last_live_root(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let mut idx = @ir.hot_region_root_count(func, region_ref) - 1
  while idx >= 0 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id >= 0 && @ir.hot_node_is_live(func, node_id) {
      match @ir.hot_node_get(func, node_id).op {
        @ir.HotOp::Br
        | @ir.HotOp::BrTable
        | @ir.HotOp::Return
        | @ir.HotOp::Throw
        | @ir.HotOp::ThrowRef
        | @ir.HotOp::Rethrow
        | @ir.HotOp::Delegate
        | @ir.HotOp::Unreachable => return true
        _ => return false
      }
    }
    idx = idx - 1
  }
  false
}

///|
fn cp_type_has_nonvoid_result(func : @ir.HotFunc, type_id : Int) -> Bool {
  match @ir.hot_type_get(func, type_id) {
    @ir.HotTypeInfo::VoidType => false
    @ir.HotTypeInfo::BlockResult(block_type) =>
      match block_type {
        @lib.VoidBlockType => false
        _ => true
      }
    @ir.HotTypeInfo::BlockResultResolved(_, values)
    | @ir.HotTypeInfo::Results(values) => !values.is_empty()
    @ir.HotTypeInfo::Value(_) => true
  }
}

///|
fn cp_node_has_nonvoid_result(func : @ir.HotFunc, node_id : Int) -> Bool {
  cp_type_has_nonvoid_result(func, @ir.hot_node_type(func, node_id))
}

///|
fn cp_region_has_nonvoid_result(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  if region_ref.holder < 0 {
    return cp_type_has_nonvoid_result(func, @ir.hot_body_result_type(func))
  }
  @ir.hot_region_result_arity(func, region_ref) != 0
}

///|
fn cp_root_pushpoint_id(func : @ir.HotFunc, root_id : Int) -> Int? {
  if root_id < 0 || !@ir.hot_node_is_live(func, root_id) {
    return None
  }
  match @ir.hot_node_get(func, root_id).op {
    @ir.HotOp::If
    | @ir.HotOp::BrIf
    | @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail => Some(root_id)
    @ir.HotOp::Drop =>
      if @ir.hot_child_count(func, root_id) == 0 {
        None
      } else {
        cp_root_pushpoint_id(func, @ir.hot_child_get(func, root_id, 0))
      }
    _ => None
  }
}

///|
fn cp_root_is_pushpoint(func : @ir.HotFunc, root_id : Int) -> Bool {
  match cp_root_pushpoint_id(func, root_id) {
    Some(_) => true
    None => false
  }
}

///|
fn cp_root_if_pushpoint_id(func : @ir.HotFunc, root_id : Int) -> Int? {
  match cp_root_pushpoint_id(func, root_id) {
    Some(pushpoint_id) =>
      match @ir.hot_node_get(func, pushpoint_id).op {
        @ir.HotOp::If => Some(pushpoint_id)
        _ => None
      }
    None => None
  }
}

///|
fn cp_if_sink_allows_later_reads(
  cache : CpSummaryCache,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  if_idx : Int,
  local_id : Int,
  target_is_then : Bool,
  then_ref : @ir.HotRegionRef,
  else_ref : @ir.HotRegionRef?,
) -> Bool {
  if !cp_region_reads_local_after_index(
      cache,
      func,
      region_ref,
      if_idx + 1,
      local_id,
    ) {
    return true
  }
  if target_is_then {
    match else_ref {
      Some(else_ref) => cp_region_has_terminal_last_live_root(func, else_ref)
      None => false
    }
  } else {
    cp_region_has_terminal_last_live_root(func, then_ref)
  }
}

///|
fn cp_try_sink_into_if(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  if_idx : Int,
  infos : Array[CpLocalInfo],
  cache : CpSummaryCache,
) -> Bool {
  if if_idx <= 0 {
    return false
  }
  let if_id = match
    cp_root_if_pushpoint_id(func, @ir.hot_region_get(func, region_ref, if_idx)) {
    Some(if_id) => if_id
    None => return false
  }
  if cp_node_has_nonvoid_result(func, if_id) {
    return false
  }
  let barrier = cp_new_barrier_summary(cache.local_count, cache.global_count)
  let cond_id = @ir.hot_child_get(func, if_id, 0)
  if cond_id >= 0 && @ir.hot_node_is_live(func, cond_id) {
    cp_barrier_merge_summary(
      barrier,
      cp_effect_summary_for_node(cache, func, cond_id),
    )
  }
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let else_ref = @ir.hot_region_else_ref(func, if_id)
  let mut scan = if_idx - 1
  while scan >= 0 {
    let root_id = @ir.hot_region_get(func, region_ref, scan)
    let root_summary = cp_effect_summary_for_node(cache, func, root_id)
    match cp_root_pushable_local(infos, cache, func, root_id) {
      Some(local_id) => {
        let then_reads = cp_region_reads_local(cache, func, then_ref, local_id)
        let else_reads = match else_ref {
          Some(else_ref) =>
            cp_region_reads_local(cache, func, else_ref, local_id)
          None => false
        }
        let target_is_then = then_reads && !else_reads
        if then_reads != else_reads &&
          cp_if_sink_allows_later_reads(
            cache, func, region_ref, if_idx, local_id, target_is_then, then_ref,
            else_ref,
          ) &&
          !cp_summary_conflicts_with_barrier(root_summary, barrier) {
          let target_region = if target_is_then {
            then_ref
          } else {
            else_ref.unwrap()
          }
          ignore(
            @ir.hot_region_set(func, region_ref, scan, @ir.hot_build_nop(func)),
          )
          @ir.hot_region_insert(func, target_region, 0, [root_id])
          pass_mark_mutated(ctx, func)
          return true
        }
      }
      None => ()
    }
    cp_barrier_merge_root_summary(barrier, cache, func, root_id, root_summary)
    scan = scan - 1
  }
  false
}

///|
fn cp_try_push_to_pushpoint(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  target_idx : Int,
  infos : Array[CpLocalInfo],
  cache : CpSummaryCache,
) -> Bool {
  if target_idx <= 0 {
    return false
  }
  let roots = cp_region_roots_copy(func, region_ref)
  if cp_region_has_nonvoid_result(func, region_ref) &&
    cp_nonvoid_prefix_has_explicit_exit_guard(
      cache, func, region_ref, target_idx,
    ) {
    return false
  }
  let target_if_id = cp_root_if_pushpoint_id(func, roots[target_idx])
  match target_if_id {
    Some(if_id) if cp_node_has_nonvoid_result(func, if_id) => return false
    _ => ()
  }
  if !cp_root_is_pushpoint(func, roots[target_idx]) {
    return false
  }
  let barrier = cp_new_barrier_summary(cache.local_count, cache.global_count)
  let movable = Array::make(roots.length(), false)
  let move_after_target = Array::make(roots.length(), false)
  let pushpoint_summary = cp_effect_summary_for_node(
    cache,
    func,
    roots[target_idx],
  )
  let mut scan = target_idx - 1
  while scan >= 0 {
    let root_id = roots[scan]
    let root_summary = cp_effect_summary_for_node(cache, func, root_id)
    let can_move = match cp_root_pushable_local(infos, cache, func, root_id) {
      Some(local_id) =>
        if cp_summary_conflicts_with_barrier(root_summary, barrier) {
          false
        } else {
          match target_if_id {
            Some(if_id) =>
              if !cp_node_has_nonvoid_result(func, if_id) &&
                !cp_summary_reads_local(pushpoint_summary, local_id) &&
                !cp_summary_writes_local(pushpoint_summary, local_id) {
                let has_later_read = cp_region_reads_local_after_index(
                  cache,
                  func,
                  region_ref,
                  target_idx + 1,
                  local_id,
                )
                if has_later_read {
                  move_after_target[scan] = true
                  true
                } else if cp_region_dead_move_gap_is_safe(
                    cache, func, region_ref, scan, target_idx, root_summary,
                  ) {
                  move_after_target[scan] = true
                  true
                } else {
                  false
                }
              } else {
                true
              }
            None => true
          }
        }
      None => false
    }
    if can_move {
      movable[scan] = true
    } else {
      cp_barrier_merge_root_summary(barrier, cache, func, root_id, root_summary)
    }
    scan = scan - 1
  }
  let moved : Array[Int] = []
  let mut idx = 0
  while idx < roots.length() {
    if movable[idx] {
      moved.push(roots[idx])
    }
    idx = idx + 1
  }
  if moved.is_empty() {
    return false
  }
  let moved_after : Array[Int] = []
  for node_id in moved {
    let mut source_idx = 0
    while source_idx < roots.length() {
      if roots[source_idx] == node_id && movable[source_idx] {
        if move_after_target[source_idx] {
          moved_after.push(node_id)
        }
        break
      }
      source_idx = source_idx + 1
    }
  }
  let next : Array[Int] = []
  idx = 0
  while idx < roots.length() {
    if idx == target_idx {
      for node_id in moved {
        let mut source_idx = 0
        let mut after_target = false
        while source_idx < roots.length() {
          if roots[source_idx] == node_id && movable[source_idx] {
            after_target = move_after_target[source_idx]
            break
          }
          source_idx = source_idx + 1
        }
        if !after_target {
          next.push(node_id)
        }
      }
    }
    if !movable[idx] {
      next.push(roots[idx])
    }
    if idx == target_idx {
      for node_id in moved_after {
        next.push(node_id)
      }
    }
    idx = idx + 1
  }
  if cp_node_id_arrays_equal(roots, next) {
    return false
  }
  @ir.hot_region_replace_body(func, region_ref, next)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn cp_try_rewrite_nested_regions(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  infos : Array[CpLocalInfo],
  cache : CpSummaryCache,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Drop =>
      if @ir.hot_child_count(func, node_id) == 0 {
        false
      } else {
        cp_try_rewrite_nested_regions(
          ctx,
          func,
          @ir.hot_child_get(func, node_id, 0),
          infos,
          cache,
        )
      }
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      cp_try_rewrite_region(
        ctx,
        func,
        @ir.hot_region_body_ref(func, node_id),
        infos,
        cache,
      )
    @ir.HotOp::If =>
      if cp_try_rewrite_region(
          ctx,
          func,
          @ir.hot_region_then_ref(func, node_id),
          infos,
          cache,
        ) {
        true
      } else {
        match @ir.hot_region_else_ref(func, node_id) {
          Some(else_ref) =>
            cp_try_rewrite_region(ctx, func, else_ref, infos, cache)
          None => false
        }
      }
    @ir.HotOp::Try =>
      if cp_try_rewrite_region(
          ctx,
          func,
          @ir.hot_region_body_ref(func, node_id),
          infos,
          cache,
        ) {
        true
      } else {
        match @ir.hot_region_catch_ref(func, node_id) {
          Some(catch_ref) =>
            cp_try_rewrite_region(ctx, func, catch_ref, infos, cache)
          None => false
        }
      }
    @ir.HotOp::TryTable =>
      cp_try_rewrite_region(
        ctx,
        func,
        @ir.hot_region_body_ref(func, node_id),
        infos,
        cache,
      ) ||
      cp_try_rewrite_region(
        ctx,
        func,
        @ir.hot_region_catch_list_ref(func, node_id),
        infos,
        cache,
      )
    _ => false
  }
}

///|
fn cp_try_rewrite_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  infos : Array[CpLocalInfo],
  cache : CpSummaryCache,
) -> Bool {
  let mut idx = 0
  while idx < @ir.hot_region_root_count(func, region_ref) {
    let root_id = @ir.hot_region_get(func, region_ref, idx)
    if cp_try_sink_into_if(ctx, func, region_ref, idx, infos, cache) ||
      cp_try_push_to_pushpoint(ctx, func, region_ref, idx, infos, cache) {
      return true
    }
    if root_id < 0 || !@ir.hot_node_is_live(func, root_id) {
      idx = idx + 1
      continue
    }
    if cp_try_rewrite_nested_regions(ctx, func, root_id, infos, cache) {
      return true
    }
    idx = idx + 1
  }
  false
}

///|
fn code_pushing_run(ctx : HotPassContext, func : @ir.HotFunc) -> HotPassResult {
  let mut changed = false
  while true {
    let infos = cp_analyze_locals(func)
    let cache = cp_new_summary_cache(func)
    if !cp_try_rewrite_region(ctx, func, @ir.HotRegionRef::root(), infos, cache) {
      break
    }
    changed = true
  }
  if changed {
    HotPassResult::changed()
  } else {
    HotPassResult::unchanged()
  }
}
