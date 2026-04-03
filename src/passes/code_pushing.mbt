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
  ready : Array[Bool]
  summaries : Array[CpEffectSummary]
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
fn cp_max_global_index(func : @ir.HotFunc) -> Int {
  let mut max_idx = -1
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
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
  let local_count = @ir.hot_local_count(func)
  let global_count = cp_max_global_index(func)
  let ready = Array::make(@ir.hot_node_count(func), false)
  let summaries : Array[CpEffectSummary] = []
  for idx = 0; idx < @ir.hot_node_count(func); idx = idx + 1 {
    let _ = idx
    summaries.push(cp_empty_effect_summary(local_count, global_count))
  }
  { local_count, global_count, ready, summaries }
}

///|
fn cp_effect_summary_for_node(
  cache : CpSummaryCache,
  func : @ir.HotFunc,
  node_id : Int,
) -> CpEffectSummary {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    abort("code-pushing effect summary requires a live node")
  }
  if cache.ready[node_id] {
    return cache.summaries[node_id]
  }
  let node = @ir.hot_node_get(func, node_id)
  let summary : CpEffectSummary = {
    mask: @ir.effects_for_node(func, node_id),
    local_reads: @ir.bitset_new(cache.local_count),
    local_writes: @ir.bitset_new(cache.local_count),
    global_reads: @ir.bitset_new(cache.global_count),
    global_writes: @ir.bitset_new(cache.global_count),
  }
  cp_summary_note_node(summary, node, cache.global_count)
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    let child_id = @ir.hot_child_get(func, node_id, slot)
    if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
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
    @ir.HotOp::LocalSet => cp_note_local_set(infos, node.imm0)
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
fn cp_node_has_explicit_exit(func : @ir.HotFunc, node_id : Int) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
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
    | @ir.HotOp::Unreachable => return true
    _ => ()
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    if cp_node_has_explicit_exit(func, @ir.hot_child_get(func, node_id, slot)) {
      return true
    }
  }
  false
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
fn cp_branch_exits_block_owner(
  func : @ir.HotFunc,
  owner_id : Int,
  active_owners : Array[Int],
  node_id : Int,
) -> Bool {
  let targets : Array[Int] = []
  match @ir.hot_branch_target(func, node_id) {
    Some(label_id) => targets.push(label_id)
    None => ()
  }
  for label_id in @ir.hot_branch_table_targets_for_node(func, node_id) {
    targets.push(label_id)
  }
  if targets.is_empty() {
    return false
  }
  for label_id in targets {
    let target_owner_id = @ir.hot_label_owner(func, label_id)
    if target_owner_id != owner_id &&
      cp_active_owners_contains(active_owners, target_owner_id) {
      return false
    }
  }
  true
}

///|
fn cp_region_has_block_exiting_explicit_exit(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  owner_id : Int,
  active_owners : Array[Int],
) -> Bool {
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    let root_id = @ir.hot_region_get(func, region_ref, idx)
    if cp_subtree_has_block_exiting_explicit_exit(
        func, root_id, owner_id, active_owners,
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
      return cp_branch_exits_block_owner(func, owner_id, active_owners, node_id)
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
      )
    @ir.HotOp::If => {
      let then_exits_owner = cp_region_has_block_exiting_explicit_exit(
        func,
        @ir.hot_region_then_ref(func, node_id),
        owner_id,
        active_owners,
      )
      let else_exits_owner = match @ir.hot_region_else_ref(func, node_id) {
        Some(region_ref) =>
          cp_region_has_block_exiting_explicit_exit(
            func, region_ref, owner_id, active_owners,
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
      )
      let catch_exits_owner = match @ir.hot_region_catch_ref(func, node_id) {
        Some(region_ref) =>
          cp_region_has_block_exiting_explicit_exit(
            func, region_ref, owner_id, active_owners,
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
      ) ||
      cp_region_has_block_exiting_explicit_exit(
        func,
        @ir.hot_region_catch_list_ref(func, node_id),
        owner_id,
        active_owners,
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
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  target_idx : Int,
) -> Bool {
  let mut idx = 0
  while idx < @ir.hot_region_root_count(func, region_ref) && idx <= target_idx {
    let root_id = @ir.hot_region_get(func, region_ref, idx)
    let root_node = @ir.hot_node_get(func, root_id)
    match root_node.op {
      @ir.HotOp::Drop => ()
      @ir.HotOp::Block =>
        if cp_subtree_has_block_exiting_explicit_exit(func, root_id, root_id, [
            root_id,
          ]) {
          return true
        }
      _ => if cp_node_has_explicit_exit(func, root_id) { return true }
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
  if @ir.hot_node_result_arity(func, if_id) != 0 {
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
    cp_barrier_merge_summary(barrier, root_summary)
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
  if @ir.hot_region_result_arity(func, region_ref) != 0 &&
    cp_nonvoid_prefix_has_explicit_exit_guard(func, region_ref, target_idx) {
    return false
  }
  match cp_root_if_pushpoint_id(func, roots[target_idx]) {
    Some(if_id) if @ir.hot_node_result_arity(func, if_id) != 0 => return false
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
        if !cp_summary_conflicts_with_barrier(root_summary, barrier) {
          match cp_root_if_pushpoint_id(func, roots[target_idx]) {
            Some(if_id) =>
              if @ir.hot_node_result_arity(func, if_id) == 0 &&
                !cp_summary_reads_local(pushpoint_summary, local_id) &&
                !cp_summary_writes_local(pushpoint_summary, local_id) {
                move_after_target[scan] = true
              }
            None => ()
          }
          true
        } else {
          false
        }
      None => false
    }
    if can_move {
      movable[scan] = true
    } else {
      cp_barrier_merge_summary(barrier, root_summary)
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
    match @ir.hot_node_get(func, root_id).op {
      @ir.HotOp::Block | @ir.HotOp::Loop =>
        if cp_try_rewrite_region(
            ctx,
            func,
            @ir.hot_region_body_ref(func, root_id),
            infos,
            cache,
          ) {
          return true
        }
      @ir.HotOp::If => {
        if cp_try_rewrite_region(
            ctx,
            func,
            @ir.hot_region_then_ref(func, root_id),
            infos,
            cache,
          ) {
          return true
        }
        match @ir.hot_region_else_ref(func, root_id) {
          Some(else_ref) =>
            if cp_try_rewrite_region(ctx, func, else_ref, infos, cache) {
              return true
            }
          None => ()
        }
      }
      @ir.HotOp::Try => {
        if cp_try_rewrite_region(
            ctx,
            func,
            @ir.hot_region_body_ref(func, root_id),
            infos,
            cache,
          ) {
          return true
        }
        match @ir.hot_region_catch_ref(func, root_id) {
          Some(catch_ref) =>
            if cp_try_rewrite_region(ctx, func, catch_ref, infos, cache) {
              return true
            }
          None => ()
        }
      }
      @ir.HotOp::TryTable =>
        if cp_try_rewrite_region(
            ctx,
            func,
            @ir.hot_region_body_ref(func, root_id),
            infos,
            cache,
          ) ||
          cp_try_rewrite_region(
            ctx,
            func,
            @ir.hot_region_catch_list_ref(func, root_id),
            infos,
            cache,
          ) {
          return true
        }
      _ => ()
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
