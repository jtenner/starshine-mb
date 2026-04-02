///|
pub fn code_pushing_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new("code-pushing")
}

///|
pub fn code_pushing_summary() -> String {
  "Analyze Binaryen-style `local.set` code-pushing candidates and subtree barriers before landing the rewrite."
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
fn cp_bitset_any(bitset : @ir.Bitset) -> Bool {
  for idx = 0; idx < bitset.size; idx = idx + 1 {
    if @ir.bitset_contains(bitset, idx) {
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
  let summary = {
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
fn code_pushing_run(_ctx : HotPassContext, func : @ir.HotFunc) -> HotPassResult {
  ignore(cp_analyze_locals(func))
  let cache = cp_new_summary_cache(func)
  for root_idx = 0; root_idx < @ir.hot_root_count(func); root_idx = root_idx + 1 {
    let root_id = @ir.hot_root_get(func, root_idx)
    if root_id < 0 || !@ir.hot_node_is_live(func, root_id) {
      continue
    }
    ignore(cp_effect_summary_for_node(cache, func, root_id))
  }
  HotPassResult::unchanged()
}
