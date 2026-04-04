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
  mut mask : UInt
  local_reads : @ir.Bitset
  local_writes : @ir.Bitset
  global_reads : @ir.Bitset
  global_writes : @ir.Bitset
}

///|
priv struct CpSummaryCache {
  local_count : Int
  global_count : Int
  node_masks : Array[@ir.EffectMask]
  live_nodes : Array[Bool]
  owner_exit_active_marks : Array[Bool]
  ready : Array[Bool]
  summaries : Array[CpEffectSummary]
  explicit_exit_ready : Array[Bool]
  explicit_exit_values : Array[Bool]
  dropped_region_owner_values : Array[Int]
  region_last_local_read_root_idxs : Array[Array[Int]?]
  pushable_local_ready : Array[Bool]
  pushable_local_values : Array[Int]
  trivial_dead_move_gap_ready : Array[Bool]
  trivial_dead_move_gap_values : Array[Bool]
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
priv struct CpFuncStaticScan {
  global_count : Int
  dropped_region_owner_values : Array[Int]
}

///|
priv struct CpTraversalGateScan {
  node_masks : Array[@ir.EffectMask]
  subtree_unremovable_ready : Array[Bool]
  subtree_unremovable_values : Array[Bool]
  subtree_reads_sfa_ready : Array[Bool]
  subtree_reads_sfa_values : Array[Bool]
  region_candidate_ready : Array[Bool]
  region_candidate_values : Array[Bool]
}

///|
priv struct CpRegionRootsView {
  root_count : Int
  base : Int
  uses_func_roots : Bool
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
fn cp_summary_merge_into(dst : CpEffectSummary, src : CpEffectSummary) -> Unit {
  dst.mask = dst.mask | src.mask
  cp_summary_merge_bits_into(dst, src)
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
fn cp_new_summary_cache(
  func : @ir.HotFunc,
  static_scan? : CpFuncStaticScan? = None,
  node_masks? : Array[@ir.EffectMask]? = None,
) -> CpSummaryCache {
  let node_count = @ir.hot_node_count(func)
  let live_nodes = Array::make(node_count, true)
  for free_id in func.free_nodes {
    if free_id >= 0 && free_id < node_count {
      live_nodes[free_id] = false
    }
  }
  let static_scan = match static_scan {
    Some(static_scan) => static_scan
    None => cp_prepare_func_static_scan(func)
  }
  let local_count = @ir.hot_local_count(func)
  let global_count = static_scan.global_count
  let node_masks = match node_masks {
    Some(node_masks) => node_masks
    None =>
      @ir.cache_get_or_build_effect_node_masks(
        @ir.HotAnalysisCache::new(),
        func,
      )
  }
  let ready = Array::make(node_count, false)
  let summaries = Array::make(node_count, cp_empty_effect_summary(0, 0))
  {
    local_count,
    global_count,
    node_masks,
    live_nodes,
    owner_exit_active_marks: Array::make(node_count, false),
    ready,
    summaries,
    explicit_exit_ready: Array::make(node_count, false),
    explicit_exit_values: Array::make(node_count, false),
    dropped_region_owner_values: static_scan.dropped_region_owner_values,
    region_last_local_read_root_idxs: Array::make(node_count + 1, None),
    pushable_local_ready: Array::make(node_count, false),
    pushable_local_values: Array::make(node_count, -1),
    trivial_dead_move_gap_ready: Array::make(node_count, false),
    trivial_dead_move_gap_values: Array::make(node_count, false),
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
    mask: cache.node_masks[node_id],
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
fn cp_infos_have_sfa_local(infos : Array[CpLocalInfo]) -> Bool {
  for info in infos {
    if info.sfa {
      return true
    }
  }
  false
}

///|
fn cp_func_has_candidate_shape(func : @ir.HotFunc) -> Bool {
  let param_count = @ir.hot_param_count(func)
  let mut saw_nonparam_set = false
  let mut saw_pushpoint = false
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = func.nodes[node_id]
    match node.op {
      @ir.HotOp::LocalSet | @ir.HotOp::LocalTee =>
        if node.imm0 >= param_count {
          saw_nonparam_set = true
        }
      @ir.HotOp::If
      | @ir.HotOp::BrIf
      | @ir.HotOp::BrOnNull
      | @ir.HotOp::BrOnNonNull
      | @ir.HotOp::BrOnCast
      | @ir.HotOp::BrOnCastFail => saw_pushpoint = true
      _ => ()
    }
    if saw_nonparam_set && saw_pushpoint {
      return true
    }
  }
  false
}

///|
fn cp_prepare_func_static_scan(func : @ir.HotFunc) -> CpFuncStaticScan {
  let node_count = @ir.hot_node_count(func)
  let dropped_region_owner_values = Array::make(node_count + 1, -1)
  let mut max_global_idx = -1
  for node_id = 0; node_id < node_count; node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = func.nodes[node_id]
    match node.op {
      @ir.HotOp::GlobalGet | @ir.HotOp::GlobalSet =>
        if node.imm0 > max_global_idx {
          max_global_idx = node.imm0
        }
      @ir.HotOp::Drop =>
        if node.child_count > 0 {
          let holder_id = func.children[node.child_base]
          let cache_slot = holder_id + 1
          if holder_id >= 0 && cache_slot < dropped_region_owner_values.length() {
            dropped_region_owner_values[cache_slot] = holder_id
          }
        }
      _ => ()
    }
  }
  { global_count: max_global_idx + 1, dropped_region_owner_values }
}

///|
fn cp_new_traversal_gate_scan(
  func : @ir.HotFunc,
  node_masks : Array[@ir.EffectMask],
) -> CpTraversalGateScan {
  let node_count = @ir.hot_node_count(func)
  {
    node_masks,
    subtree_unremovable_ready: Array::make(node_count, false),
    subtree_unremovable_values: Array::make(node_count, false),
    subtree_reads_sfa_ready: Array::make(node_count, false),
    subtree_reads_sfa_values: Array::make(node_count, false),
    region_candidate_ready: Array::make(node_count + 1, false),
    region_candidate_values: Array::make(node_count + 1, false),
  }
}

///|
fn cp_node_reads_any_sfa_local_cheap(
  infos : Array[CpLocalInfo],
  scan : CpTraversalGateScan,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  if scan.subtree_reads_sfa_ready[node_id] {
    return scan.subtree_reads_sfa_values[node_id]
  }
  let node = func.nodes[node_id]
  let mut reads_sfa = match node.op {
    @ir.HotOp::LocalGet =>
      node.imm0 >= 0 && node.imm0 < infos.length() && infos[node.imm0].sfa
    _ => false
  }
  if !reads_sfa {
    for slot = 0; slot < node.child_count; slot = slot + 1 {
      if cp_node_reads_any_sfa_local_cheap(
          infos,
          scan,
          func,
          func.children[node.child_base + slot],
        ) {
        reads_sfa = true
        break
      }
    }
  }
  scan.subtree_reads_sfa_ready[node_id] = true
  scan.subtree_reads_sfa_values[node_id] = reads_sfa
  reads_sfa
}

///|
fn cp_node_has_unremovable_value_effects_cheap(
  scan : CpTraversalGateScan,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  if scan.subtree_unremovable_ready[node_id] {
    return scan.subtree_unremovable_values[node_id]
  }
  let node = func.nodes[node_id]
  let blocked_mask = @ir.EFFECT_MASK_CONTROL |
    @ir.EFFECT_MASK_CALL |
    @ir.EFFECT_MASK_THROW |
    @ir.EFFECT_MASK_TRAP |
    @ir.EFFECT_MASK_MEMORY_WRITE |
    @ir.EFFECT_MASK_TABLE_WRITE
  let mut blocked = (scan.node_masks[node_id] & blocked_mask) != 0U
  if !blocked {
    match node.op {
      @ir.HotOp::LocalSet | @ir.HotOp::LocalTee | @ir.HotOp::GlobalSet =>
        blocked = true
      _ => ()
    }
  }
  if !blocked {
    for slot = 0; slot < node.child_count; slot = slot + 1 {
      if cp_node_has_unremovable_value_effects_cheap(
          scan,
          func,
          func.children[node.child_base + slot],
        ) {
        blocked = true
        break
      }
    }
  }
  scan.subtree_unremovable_ready[node_id] = true
  scan.subtree_unremovable_values[node_id] = blocked
  blocked
}

///|
fn cp_root_has_cheap_traversal_candidate(
  infos : Array[CpLocalInfo],
  scan : CpTraversalGateScan,
  func : @ir.HotFunc,
  root_id : Int,
) -> Bool {
  if root_id < 0 || !@ir.hot_node_is_live(func, root_id) {
    return false
  }
  let node = func.nodes[root_id]
  match node.op {
    @ir.HotOp::LocalSet => ()
    _ => return false
  }
  if node.imm0 < 0 || node.imm0 >= infos.length() || !infos[node.imm0].sfa {
    return false
  }
  if node.child_count == 0 {
    return true
  }
  !cp_node_has_unremovable_value_effects_cheap(
    scan,
    func,
    func.children[node.child_base],
  )
}

///|
fn cp_root_is_cheap_traversal_target(
  infos : Array[CpLocalInfo],
  scan : CpTraversalGateScan,
  func : @ir.HotFunc,
  root_id : Int,
) -> Bool {
  match cp_root_pushpoint_id(func, root_id) {
    Some(pushpoint_id) =>
      cp_node_reads_any_sfa_local_cheap(infos, scan, func, pushpoint_id)
    None => false
  }
}

///|
fn cp_node_nested_regions_have_traversal_candidate(
  func : @ir.HotFunc,
  node_id : Int,
  infos : Array[CpLocalInfo],
  scan : CpTraversalGateScan,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  match func.nodes[node_id].op {
    @ir.HotOp::Drop =>
      if @ir.hot_child_count(func, node_id) == 0 {
        false
      } else {
        cp_node_nested_regions_have_traversal_candidate(
          func,
          @ir.hot_child_get(func, node_id, 0),
          infos,
          scan,
        )
      }
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      cp_region_has_traversal_candidate(
        func,
        @ir.hot_region_body_ref(func, node_id),
        infos,
        scan,
      )
    @ir.HotOp::If =>
      if cp_region_has_traversal_candidate(
          func,
          @ir.hot_region_then_ref(func, node_id),
          infos,
          scan,
        ) {
        true
      } else {
        match @ir.hot_region_else_ref(func, node_id) {
          Some(else_ref) =>
            cp_region_has_traversal_candidate(func, else_ref, infos, scan)
          None => false
        }
      }
    @ir.HotOp::Try =>
      if cp_region_has_traversal_candidate(
          func,
          @ir.hot_region_body_ref(func, node_id),
          infos,
          scan,
        ) {
        true
      } else {
        match @ir.hot_region_catch_ref(func, node_id) {
          Some(catch_ref) =>
            cp_region_has_traversal_candidate(func, catch_ref, infos, scan)
          None => false
        }
      }
    @ir.HotOp::TryTable =>
      cp_region_has_traversal_candidate(
        func,
        @ir.hot_region_body_ref(func, node_id),
        infos,
        scan,
      ) ||
      cp_region_has_traversal_candidate(
        func,
        @ir.hot_region_catch_list_ref(func, node_id),
        infos,
        scan,
      )
    _ => false
  }
}

///|
fn cp_region_has_traversal_candidate(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  infos : Array[CpLocalInfo],
  scan : CpTraversalGateScan,
) -> Bool {
  let roots_view = cp_region_roots_view(func, region_ref)
  let cache_slot = region_ref.holder + 1
  if cache_slot >= 0 &&
    cache_slot < scan.region_candidate_ready.length() &&
    scan.region_candidate_ready[cache_slot] {
    return scan.region_candidate_values[cache_slot]
  }
  let mut saw_later_target = false
  let mut saw_later_live_root = false
  let mut has_candidate = false
  let mut idx = roots_view.root_count - 1
  while idx >= 0 {
    let root_id = cp_region_root_get(func, roots_view, idx)
    if cp_node_nested_regions_have_traversal_candidate(
        func, root_id, infos, scan,
      ) {
      has_candidate = true
      break
    }
    if saw_later_target &&
      cp_root_has_cheap_traversal_candidate(infos, scan, func, root_id) {
      has_candidate = true
      break
    }
    if !saw_later_target &&
      saw_later_live_root &&
      cp_root_is_pushpoint(func, root_id) {
      saw_later_target = true
    } else if cp_root_is_cheap_traversal_target(infos, scan, func, root_id) {
      saw_later_target = true
    }
    if root_id >= 0 && @ir.hot_node_is_live(func, root_id) {
      saw_later_live_root = true
    }
    idx = idx - 1
  }
  if cache_slot >= 0 && cache_slot < scan.region_candidate_ready.length() {
    scan.region_candidate_ready[cache_slot] = true
    scan.region_candidate_values[cache_slot] = has_candidate
  }
  has_candidate
}

///|
fn cp_func_has_traversal_candidate(
  func : @ir.HotFunc,
  infos : Array[CpLocalInfo],
  scan : CpTraversalGateScan,
) -> Bool {
  cp_region_has_traversal_candidate(func, @ir.HotRegionRef::root(), infos, scan)
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
fn cp_region_roots_view(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> CpRegionRootsView {
  let holder_id = region_ref.holder
  if holder_id < 0 {
    return { root_count: func.roots.length(), base: 0, uses_func_roots: true }
  }
  let holder = func.nodes[holder_id]
  let body_base = match holder.op {
    @ir.HotOp::Loop =>
      @ir.hot_label_branch_arity(
        func,
        @ir.hot_control_node_label(func, holder_id),
      )
    _ => 0
  }
  {
    root_count: holder.child_count - body_base,
    base: holder.child_base + body_base,
    uses_func_roots: false,
  }
}

///|
fn cp_region_root_get(
  func : @ir.HotFunc,
  roots : CpRegionRootsView,
  idx : Int,
) -> Int {
  if roots.uses_func_roots {
    func.roots[idx]
  } else {
    func.children[roots.base + idx]
  }
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
  if cache_slot >= 0 && cache_slot < cache.dropped_region_owner_values.length() {
    let cached = cache.dropped_region_owner_values[cache_slot]
    return if cached >= 0 { Some(cached) } else { None }
  }
  None
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
  if pushes_owner {
    active_owner_marks[node_id] = false
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
  let active_owner_marks = cache.owner_exit_active_marks
  active_owner_marks[root_id] = true
  cp_collect_block_owner_exit_summary(
    cache, func, root_id, root_id, active_owner_marks, dropped_region_owner_id, summary,
  )
  active_owner_marks[root_id] = false
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
  let roots_view = cp_region_roots_view(func, region_ref)
  for idx = 0; idx < roots_view.root_count; idx = idx + 1 {
    let root_id = cp_region_root_get(func, roots_view, idx)
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
  roots_view : CpRegionRootsView,
  region_ref : @ir.HotRegionRef,
  prefix_start_idx : Int,
  target_idx : Int,
) -> Bool {
  let dropped_region_owner_id = match
    cp_dropped_region_owner_id(cache, func, region_ref) {
    Some(owner_id) => owner_id
    None => -1
  }
  let mut idx = prefix_start_idx
  while idx < roots_view.root_count && idx <= target_idx {
    let root_id = cp_region_root_get(func, roots_view, idx)
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
fn cp_region_node_ids_equal(
  func : @ir.HotFunc,
  roots : CpRegionRootsView,
  ids : Array[Int],
) -> Bool {
  if ids.length() != roots.root_count {
    return false
  }
  let mut idx = 0
  while idx < ids.length() {
    if ids[idx] != cp_region_root_get(func, roots, idx) {
      return false
    }
    idx = idx + 1
  }
  true
}

///|
fn cp_append_reverse_ids(dst : Array[Int], src : Array[Int]) -> Unit {
  let mut idx = src.length() - 1
  while idx >= 0 {
    dst.push(src[idx])
    idx = idx - 1
  }
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
  if root_id < cache.pushable_local_ready.length() &&
    cache.pushable_local_ready[root_id] {
    let cached = cache.pushable_local_values[root_id]
    return if cached >= 0 { Some(cached) } else { None }
  }
  let node = @ir.hot_node_get(func, root_id)
  match node.op {
    @ir.HotOp::LocalSet => ()
    _ => {
      if root_id < cache.pushable_local_ready.length() {
        cache.pushable_local_ready[root_id] = true
        cache.pushable_local_values[root_id] = -1
      }
      return None
    }
  }
  if node.imm0 < 0 || node.imm0 >= infos.length() || !infos[node.imm0].sfa {
    if root_id < cache.pushable_local_ready.length() {
      cache.pushable_local_ready[root_id] = true
      cache.pushable_local_values[root_id] = -1
    }
    return None
  }
  if @ir.hot_child_count(func, root_id) == 0 {
    if root_id < cache.pushable_local_ready.length() {
      cache.pushable_local_ready[root_id] = true
      cache.pushable_local_values[root_id] = node.imm0
    }
    return Some(node.imm0)
  }
  let value_id = @ir.hot_child_get(func, root_id, 0)
  if value_id < 0 || !@ir.hot_node_is_live(func, value_id) {
    if root_id < cache.pushable_local_ready.length() {
      cache.pushable_local_ready[root_id] = true
      cache.pushable_local_values[root_id] = node.imm0
    }
    return Some(node.imm0)
  }
  let value_summary = cp_effect_summary_for_node(cache, func, value_id)
  if cp_has_unremovable_side_effects(value_summary) {
    if root_id < cache.pushable_local_ready.length() {
      cache.pushable_local_ready[root_id] = true
      cache.pushable_local_values[root_id] = -1
    }
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
    if root_id < cache.pushable_local_ready.length() {
      cache.pushable_local_ready[root_id] = true
      cache.pushable_local_values[root_id] = -1
    }
    return None
  }
  if root_id < cache.pushable_local_ready.length() {
    cache.pushable_local_ready[root_id] = true
    cache.pushable_local_values[root_id] = node.imm0
  }
  Some(node.imm0)
}

///|
fn cp_region_last_local_read_root_idxs(
  cache : CpSummaryCache,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Array[Int] {
  let roots_view = cp_region_roots_view(func, region_ref)
  let cache_slot = region_ref.holder + 1
  if cache_slot >= 0 &&
    cache_slot < cache.region_last_local_read_root_idxs.length() {
    match cache.region_last_local_read_root_idxs[cache_slot] {
      Some(last_read_root_idxs) => return last_read_root_idxs
      None => ()
    }
  }
  let last_read_root_idxs = Array::make(cache.local_count, -1)
  let mut idx = 0
  while idx < roots_view.root_count {
    let root_summary = cp_effect_summary_for_node(
      cache,
      func,
      cp_region_root_get(func, roots_view, idx),
    )
    @ir.bitset_for_each_set_bit(root_summary.local_reads, fn(local_id) {
      last_read_root_idxs[local_id] = idx
    })
    idx = idx + 1
  }
  if cache_slot >= 0 &&
    cache_slot < cache.region_last_local_read_root_idxs.length() {
    cache.region_last_local_read_root_idxs[cache_slot] = Some(
      last_read_root_idxs,
    )
  }
  last_read_root_idxs
}

///|
fn cp_region_reads_local(
  cache : CpSummaryCache,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  local_id : Int,
) -> Bool {
  if local_id < 0 || local_id >= cache.local_count {
    return false
  }
  let cache_slot = region_ref.holder + 1
  if cache_slot < 0 ||
    cache_slot >= cache.region_last_local_read_root_idxs.length() {
    return false
  }
  match cache.region_last_local_read_root_idxs[cache_slot] {
    Some(last_read_root_idxs) => last_read_root_idxs[local_id] >= 0
    None => {
      let last_read_root_idxs = cp_region_last_local_read_root_idxs(
        cache, func, region_ref,
      )
      last_read_root_idxs[local_id] >= 0
    }
  }
}

///|
fn cp_region_reads_local_after_index(
  cache : CpSummaryCache,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  start_idx : Int,
  local_id : Int,
) -> Bool {
  if local_id < 0 || local_id >= cache.local_count {
    return false
  }
  let last_read_root_idxs = cp_region_last_local_read_root_idxs(
    cache, func, region_ref,
  )
  last_read_root_idxs[local_id] >= start_idx
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
  if root_id < cache.trivial_dead_move_gap_ready.length() &&
    cache.trivial_dead_move_gap_ready[root_id] {
    return cache.trivial_dead_move_gap_values[root_id]
  }
  if cp_node_has_explicit_exit(cache, func, root_id) {
    if root_id < cache.trivial_dead_move_gap_ready.length() {
      cache.trivial_dead_move_gap_ready[root_id] = true
      cache.trivial_dead_move_gap_values[root_id] = false
    }
    return false
  }
  let summary = cp_effect_summary_for_node(cache, func, root_id)
  let result = if cp_bitset_any(summary.local_reads) ||
    cp_bitset_any(summary.local_writes) ||
    cp_bitset_any(summary.global_reads) ||
    cp_bitset_any(summary.global_writes) {
    false
  } else {
    let noncontrol_mask = summary.mask ^
      (summary.mask & @ir.EFFECT_MASK_CONTROL)
    noncontrol_mask == 0U
  }
  if root_id < cache.trivial_dead_move_gap_ready.length() {
    cache.trivial_dead_move_gap_ready[root_id] = true
    cache.trivial_dead_move_gap_values[root_id] = result
  }
  result
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
fn cp_region_has_terminal_last_live_root(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let roots_view = cp_region_roots_view(func, region_ref)
  let mut idx = roots_view.root_count - 1
  while idx >= 0 {
    let node_id = cp_region_root_get(func, roots_view, idx)
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
  roots_view : CpRegionRootsView,
  region_ref : @ir.HotRegionRef,
  if_idx : Int,
  infos : Array[CpLocalInfo],
  cache : CpSummaryCache,
) -> Bool {
  if if_idx <= 0 {
    return false
  }
  let if_id = match
    cp_root_if_pushpoint_id(func, cp_region_root_get(func, roots_view, if_idx)) {
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
    let root_id = cp_region_root_get(func, roots_view, scan)
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
  roots_view : CpRegionRootsView,
  region_ref : @ir.HotRegionRef,
  target_idx : Int,
  reachable_prefix_start_idx : Int,
  infos : Array[CpLocalInfo],
  cache : CpSummaryCache,
) -> Bool {
  if target_idx <= 0 {
    return false
  }
  let root_count = roots_view.root_count
  if cp_region_has_nonvoid_result(func, region_ref) &&
    cp_nonvoid_prefix_has_explicit_exit_guard(
      cache, func, roots_view, region_ref, reachable_prefix_start_idx, target_idx,
    ) {
    return false
  }
  let target_root_id = cp_region_root_get(func, roots_view, target_idx)
  let target_if_id = cp_root_if_pushpoint_id(func, target_root_id)
  match target_if_id {
    Some(if_id) if cp_node_has_nonvoid_result(func, if_id) => return false
    _ => ()
  }
  if !cp_root_is_pushpoint(func, target_root_id) {
    return false
  }
  let barrier = cp_new_barrier_summary(cache.local_count, cache.global_count)
  let dead_move_gap = cp_empty_effect_summary(
    cache.local_count,
    cache.global_count,
  )
  let moved_idxs_rev : Array[Int] = []
  let moved_before_rev : Array[Int] = []
  let moved_after_rev : Array[Int] = []
  let pushpoint_summary = cp_effect_summary_for_node(
    cache, func, target_root_id,
  )
  let mut scan = target_idx - 1
  while scan >= 0 {
    let root_id = cp_region_root_get(func, roots_view, scan)
    let root_summary = cp_effect_summary_for_node(cache, func, root_id)
    let move_after_target = match
      cp_root_pushable_local(infos, cache, func, root_id) {
      Some(local_id) =>
        if cp_summary_conflicts_with_barrier(root_summary, barrier) {
          None
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
                  Some(true)
                } else if !cp_summary_conflicts_with_dead_move_gap(
                    root_summary, dead_move_gap,
                  ) {
                  Some(true)
                } else {
                  None
                }
              } else {
                Some(false)
              }
            None => Some(false)
          }
        }
      None => None
    }
    match move_after_target {
      Some(move_after) => {
        moved_idxs_rev.push(scan)
        if move_after {
          moved_after_rev.push(root_id)
        } else {
          moved_before_rev.push(root_id)
        }
      }
      None =>
        cp_barrier_merge_root_summary(
          barrier, cache, func, root_id, root_summary,
        )
    }
    if !cp_root_is_trivial_dead_move_gap(cache, func, root_id) {
      cp_summary_merge_into(dead_move_gap, root_summary)
    }
    scan = scan - 1
  }
  if moved_idxs_rev.is_empty() {
    return false
  }
  let next : Array[Int] = []
  let mut moved_idx_cursor = moved_idxs_rev.length() - 1
  let mut idx = 0
  while idx < root_count {
    if idx == target_idx {
      cp_append_reverse_ids(next, moved_before_rev)
    }
    if moved_idx_cursor >= 0 && moved_idxs_rev[moved_idx_cursor] == idx {
      moved_idx_cursor = moved_idx_cursor - 1
    } else {
      next.push(cp_region_root_get(func, roots_view, idx))
    }
    if idx == target_idx {
      cp_append_reverse_ids(next, moved_after_rev)
    }
    idx = idx + 1
  }
  if cp_region_node_ids_equal(func, roots_view, next) {
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
  traversal_scan : CpTraversalGateScan,
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
          traversal_scan,
        )
      }
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      cp_try_rewrite_region(
        ctx,
        func,
        @ir.hot_region_body_ref(func, node_id),
        infos,
        cache,
        traversal_scan,
      )
    @ir.HotOp::If =>
      if cp_try_rewrite_region(
          ctx,
          func,
          @ir.hot_region_then_ref(func, node_id),
          infos,
          cache,
          traversal_scan,
        ) {
        true
      } else {
        match @ir.hot_region_else_ref(func, node_id) {
          Some(else_ref) =>
            cp_try_rewrite_region(
              ctx, func, else_ref, infos, cache, traversal_scan,
            )
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
          traversal_scan,
        ) {
        true
      } else {
        match @ir.hot_region_catch_ref(func, node_id) {
          Some(catch_ref) =>
            cp_try_rewrite_region(
              ctx, func, catch_ref, infos, cache, traversal_scan,
            )
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
        traversal_scan,
      ) ||
      cp_try_rewrite_region(
        ctx,
        func,
        @ir.hot_region_catch_list_ref(func, node_id),
        infos,
        cache,
        traversal_scan,
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
  traversal_scan : CpTraversalGateScan,
) -> Bool {
  if !cp_region_has_traversal_candidate(func, region_ref, infos, traversal_scan) {
    return false
  }
  let roots_view = cp_region_roots_view(func, region_ref)
  let root_count = roots_view.root_count
  let mut idx = 0
  let mut reachable_prefix_start_idx = 0
  while idx < root_count {
    let root_id = cp_region_root_get(func, roots_view, idx)
    if cp_try_sink_into_if(ctx, func, roots_view, region_ref, idx, infos, cache) ||
      cp_try_push_to_pushpoint(
        ctx, func, roots_view, region_ref, idx, reachable_prefix_start_idx, infos,
        cache,
      ) {
      return true
    }
    if root_id < 0 || !@ir.hot_node_is_live(func, root_id) {
      idx = idx + 1
      continue
    }
    if cp_try_rewrite_nested_regions(
        ctx, func, root_id, infos, cache, traversal_scan,
      ) {
      return true
    }
    if cp_root_is_unconditional_terminal_explicit_exit(cache, func, root_id) {
      reachable_prefix_start_idx = idx + 1
    }
    idx = idx + 1
  }
  false
}

///|
fn code_pushing_run(ctx : HotPassContext, func : @ir.HotFunc) -> HotPassResult {
  if @ir.hot_local_count(func) == 0 {
    return HotPassResult::unchanged()
  }
  if !cp_func_has_candidate_shape(func) {
    return HotPassResult::unchanged()
  }
  let static_scan = cp_prepare_func_static_scan(func)
  let mut changed = false
  while true {
    let infos = cp_analyze_locals(func)
    if !cp_infos_have_sfa_local(infos) {
      break
    }
    let node_masks = pass_require_effect_node_masks(ctx, func)
    let traversal_scan = cp_new_traversal_gate_scan(func, node_masks)
    if !cp_func_has_traversal_candidate(func, infos, traversal_scan) {
      break
    }
    let cache = cp_new_summary_cache(
      func,
      static_scan=Some(static_scan),
      node_masks=Some(node_masks),
    )
    if !cp_try_rewrite_region(
        ctx,
        func,
        @ir.HotRegionRef::root(),
        infos,
        cache,
        traversal_scan,
      ) {
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
