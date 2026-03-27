///|
pub fn heap_store_optimization_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new(
    "heap-store-optimization",
    requires=[@ir.HotAnalysis::effects()],
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
pub fn heap_store_optimization_summary() -> String {
  "Fold exact struct.set writes into nearby struct.new allocations when local and effect ordering stays safe."
}

///|
priv struct HsoPredicateCache {
  readonly_revision : Array[Int]
  readonly_result : Array[Bool]
  skip_revision : Array[Int]
  skip_result : Array[Bool]
}

///|
priv struct HsoTypeCache {
  default_field_counts : Array[Int]
}

///|
fn hso_new_predicate_cache(func : @ir.HotFunc) -> HsoPredicateCache {
  {
    readonly_revision: Array::make(@ir.hot_node_count(func), -1),
    readonly_result: Array::make(@ir.hot_node_count(func), false),
    skip_revision: Array::make(@ir.hot_node_count(func), -1),
    skip_result: Array::make(@ir.hot_node_count(func), false),
  }
}

///|
fn hso_new_type_cache() -> HsoTypeCache {
  { default_field_counts: [] }
}

///|
fn hso_ensure_predicate_cache_capacity(
  cache : HsoPredicateCache,
  node_id : Int,
) -> Unit {
  while cache.readonly_revision.length() <= node_id {
    cache.readonly_revision.push(-1)
    cache.readonly_result.push(false)
    cache.skip_revision.push(-1)
    cache.skip_result.push(false)
  }
}

///|
fn hso_ensure_type_cache_capacity(
  cache : HsoTypeCache,
  type_slot : Int,
) -> Unit {
  while cache.default_field_counts.length() <= type_slot {
    cache.default_field_counts.push(-2)
  }
}

///|
fn hso_effects_for_node(
  func : @ir.HotFunc,
  node_masks : Array[UInt],
  node_id : Int,
) -> UInt {
  if node_id >= 0 && node_id < node_masks.length() {
    return node_masks[node_id]
  }
  @ir.effects_for_node(func, node_id)
}

///|
fn hso_reorder_effect_mask(
  cache : HsoPredicateCache,
  func : @ir.HotFunc,
  node_masks : Array[UInt],
  node_id : Int,
) -> UInt {
  let mask = hso_effects_for_node(func, node_masks, node_id)
  if hso_subtree_may_skip_local_set(cache, func, node_id) {
    mask
  } else {
    mask ^ (mask & @ir.EFFECT_MASK_CONTROL)
  }
}

///|
fn hso_mask_has_control_transfer(mask : UInt) -> Bool {
  (
    mask &
    (@ir.EFFECT_MASK_CONTROL | @ir.EFFECT_MASK_CALL | @ir.EFFECT_MASK_THROW)
  ) !=
  0U
}

///|
fn hso_mask_invalidates(barrier_mask : UInt, moved_mask : UInt) -> Bool {
  if hso_mask_is_pure(barrier_mask) || hso_mask_is_pure(moved_mask) {
    return false
  }
  if hso_mask_has_control_transfer(barrier_mask) ||
    (barrier_mask & @ir.EFFECT_MASK_TRAP) != 0U {
    return true
  }
  if (barrier_mask & @ir.EFFECT_MASK_LOCAL_STATE) != 0U &&
    (moved_mask & @ir.EFFECT_MASK_LOCAL_STATE) != 0U {
    return true
  }
  if (barrier_mask & @ir.EFFECT_MASK_GLOBAL_STATE) != 0U &&
    (moved_mask & @ir.EFFECT_MASK_GLOBAL_STATE) != 0U {
    return true
  }
  let barrier_reads_memory = (barrier_mask & @ir.EFFECT_MASK_MEMORY_READ) != 0U
  let barrier_writes_memory = (barrier_mask & @ir.EFFECT_MASK_MEMORY_WRITE) !=
    0U
  let moved_reads_memory = (moved_mask & @ir.EFFECT_MASK_MEMORY_READ) != 0U
  let moved_writes_memory = (moved_mask & @ir.EFFECT_MASK_MEMORY_WRITE) != 0U
  if barrier_writes_memory && (moved_reads_memory || moved_writes_memory) {
    return true
  }
  if barrier_reads_memory && moved_writes_memory {
    return true
  }
  let barrier_reads_table = (barrier_mask & @ir.EFFECT_MASK_TABLE_READ) != 0U
  let barrier_writes_table = (barrier_mask & @ir.EFFECT_MASK_TABLE_WRITE) != 0U
  let moved_reads_table = (moved_mask & @ir.EFFECT_MASK_TABLE_READ) != 0U
  let moved_writes_table = (moved_mask & @ir.EFFECT_MASK_TABLE_WRITE) != 0U
  if barrier_writes_table && (moved_reads_table || moved_writes_table) {
    return true
  }
  if barrier_reads_table && moved_writes_table {
    return true
  }
  false
}

///|
fn hso_mask_is_pure(mask : UInt) -> Bool {
  mask == 0U
}

///|
fn hso_region_touches_local(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  local_id : Int,
) -> Bool {
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    if hso_subtree_touches_local(
        func,
        @ir.hot_region_get(func, region_ref, idx),
        local_id,
      ) {
      return true
    }
  }
  false
}

///|
fn hso_subtree_touches_local(
  func : @ir.HotFunc,
  node_id : Int,
  local_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet | @ir.HotOp::LocalSet | @ir.HotOp::LocalTee =>
      if node.imm0 == local_id {
        return true
      }
    _ => ()
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    if hso_subtree_touches_local(
        func,
        @ir.hot_child_get(func, node_id, slot),
        local_id,
      ) {
      return true
    }
  }
  match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      hso_region_touches_local(
        func,
        @ir.hot_region_body_ref(func, node_id),
        local_id,
      )
    @ir.HotOp::If => {
      let then_touches = hso_region_touches_local(
        func,
        @ir.hot_region_then_ref(func, node_id),
        local_id,
      )
      if then_touches {
        true
      } else {
        match @ir.hot_region_else_ref(func, node_id) {
          Some(region_ref) =>
            hso_region_touches_local(func, region_ref, local_id)
          None => false
        }
      }
    }
    @ir.HotOp::Try => {
      let body_touches = hso_region_touches_local(
        func,
        @ir.hot_region_body_ref(func, node_id),
        local_id,
      )
      if body_touches {
        true
      } else {
        match @ir.hot_region_catch_ref(func, node_id) {
          Some(region_ref) =>
            hso_region_touches_local(func, region_ref, local_id)
          None => false
        }
      }
    }
    @ir.HotOp::TryTable =>
      hso_region_touches_local(
        func,
        @ir.hot_region_body_ref(func, node_id),
        local_id,
      ) ||
      hso_region_touches_local(
        func,
        @ir.hot_region_catch_list_ref(func, node_id),
        local_id,
      )
    _ => false
  }
}

///|
fn hso_region_may_skip_local_set(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  active_owners : Array[Int],
) -> Bool {
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    if hso_subtree_may_skip_local_set_from_root(
        func,
        @ir.hot_region_get(func, region_ref, idx),
        active_owners,
      ) {
      return true
    }
  }
  false
}

///|
fn hso_active_owners_contains(
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
fn hso_branch_escapes_active_owners(
  func : @ir.HotFunc,
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
    return true
  }
  for label_id in targets {
    let owner_id = @ir.hot_label_owner(func, label_id)
    if !hso_active_owners_contains(active_owners, owner_id) {
      return true
    }
  }
  false
}

///|
fn hso_subtree_may_skip_local_set(
  cache : HsoPredicateCache,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  hso_ensure_predicate_cache_capacity(cache, node_id)
  let revision = @ir.hot_revision_current(func)
  if cache.skip_revision[node_id] == revision {
    return cache.skip_result[node_id]
  }
  let active_owners : Array[Int] = []
  let result = hso_subtree_may_skip_local_set_from_root(
    func, node_id, active_owners,
  )
  cache.skip_revision[node_id] = revision
  cache.skip_result[node_id] = result
  result
}

///|
fn hso_subtree_may_skip_local_set_from_root(
  func : @ir.HotFunc,
  node_id : Int,
  active_owners : Array[Int],
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  if @ir.hot_is_branch(func, node_id) &&
    hso_branch_escapes_active_owners(func, active_owners, node_id) {
    return true
  }
  match node.op {
    @ir.HotOp::Return
    | @ir.HotOp::ReturnCall
    | @ir.HotOp::ReturnCallIndirect
    | @ir.HotOp::ReturnCallRef
    | @ir.HotOp::Throw
    | @ir.HotOp::Rethrow
    | @ir.HotOp::ThrowRef
    | @ir.HotOp::Delegate
    | @ir.HotOp::Unreachable => return true
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
    if hso_subtree_may_skip_local_set_from_root(
        func,
        @ir.hot_child_get(func, node_id, slot),
        active_owners,
      ) {
      if pushes_owner {
        ignore(active_owners.pop())
      }
      return true
    }
  }
  let result = match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      hso_region_may_skip_local_set(
        func,
        @ir.hot_region_body_ref(func, node_id),
        active_owners,
      )
    @ir.HotOp::If => {
      let then_skips = hso_region_may_skip_local_set(
        func,
        @ir.hot_region_then_ref(func, node_id),
        active_owners,
      )
      if then_skips {
        true
      } else {
        match @ir.hot_region_else_ref(func, node_id) {
          Some(region_ref) =>
            hso_region_may_skip_local_set(func, region_ref, active_owners)
          None => false
        }
      }
    }
    @ir.HotOp::Try => {
      let body_skips = hso_region_may_skip_local_set(
        func,
        @ir.hot_region_body_ref(func, node_id),
        active_owners,
      )
      if body_skips {
        true
      } else {
        match @ir.hot_region_catch_ref(func, node_id) {
          Some(region_ref) =>
            hso_region_may_skip_local_set(func, region_ref, active_owners)
          None => false
        }
      }
    }
    @ir.HotOp::TryTable =>
      hso_region_may_skip_local_set(
        func,
        @ir.hot_region_body_ref(func, node_id),
        active_owners,
      ) ||
      hso_region_may_skip_local_set(
        func,
        @ir.hot_region_catch_list_ref(func, node_id),
        active_owners,
      )
    _ => false
  }
  if pushes_owner {
    ignore(active_owners.pop())
  }
  result
}

///|
fn hso_region_is_trapless_readonly(
  cache : HsoPredicateCache,
  func : @ir.HotFunc,
  node_masks : Array[UInt],
  region_ref : @ir.HotRegionRef,
) -> Bool {
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    if !hso_subtree_is_trapless_readonly(
        cache,
        func,
        node_masks,
        @ir.hot_region_get(func, region_ref, idx),
      ) {
      return false
    }
  }
  true
}

///|
fn hso_compute_subtree_is_trapless_readonly(
  cache : HsoPredicateCache,
  func : @ir.HotFunc,
  node_masks : Array[UInt],
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  let mask = hso_reorder_effect_mask(cache, func, node_masks, node_id)
  let allowed_effects = @ir.EFFECT_MASK_LOCAL_STATE |
    @ir.EFFECT_MASK_GLOBAL_STATE |
    @ir.EFFECT_MASK_MEMORY_READ |
    @ir.EFFECT_MASK_TABLE_READ
  let disallowed_effects = mask ^ (mask & allowed_effects)
  let allows_side_effect = match node.op {
    @ir.HotOp::Drop => true
    _ => false
  }
  if disallowed_effects != 0U ||
    (!allows_side_effect && @ir.hot_has_side_effect(func, node_id)) ||
    @ir.hot_may_trap(func, node_id) ||
    @ir.hot_is_branch(func, node_id) ||
    @ir.hot_is_terminator_node(func, node_id) ||
    @ir.hot_node_may_throw_exception(func, node_id) {
    return false
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    if !hso_subtree_is_trapless_readonly(
        cache,
        func,
        node_masks,
        @ir.hot_child_get(func, node_id, slot),
      ) {
      return false
    }
  }
  match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      hso_region_is_trapless_readonly(
        cache,
        func,
        node_masks,
        @ir.hot_region_body_ref(func, node_id),
      )
    @ir.HotOp::If => {
      let then_is_readonly = hso_region_is_trapless_readonly(
        cache,
        func,
        node_masks,
        @ir.hot_region_then_ref(func, node_id),
      )
      if !then_is_readonly {
        false
      } else {
        match @ir.hot_region_else_ref(func, node_id) {
          Some(region_ref) =>
            hso_region_is_trapless_readonly(cache, func, node_masks, region_ref)
          None => true
        }
      }
    }
    @ir.HotOp::Try => {
      let body_is_readonly = hso_region_is_trapless_readonly(
        cache,
        func,
        node_masks,
        @ir.hot_region_body_ref(func, node_id),
      )
      if !body_is_readonly {
        false
      } else {
        match @ir.hot_region_catch_ref(func, node_id) {
          Some(region_ref) =>
            hso_region_is_trapless_readonly(cache, func, node_masks, region_ref)
          None => true
        }
      }
    }
    @ir.HotOp::TryTable =>
      hso_region_is_trapless_readonly(
        cache,
        func,
        node_masks,
        @ir.hot_region_body_ref(func, node_id),
      ) &&
      hso_region_is_trapless_readonly(
        cache,
        func,
        node_masks,
        @ir.hot_region_catch_list_ref(func, node_id),
      )
    _ => true
  }
}

///|
fn hso_subtree_is_trapless_readonly(
  cache : HsoPredicateCache,
  func : @ir.HotFunc,
  node_masks : Array[UInt],
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  hso_ensure_predicate_cache_capacity(cache, node_id)
  let revision = @ir.hot_revision_current(func)
  if cache.readonly_revision[node_id] == revision {
    return cache.readonly_result[node_id]
  }
  let result = hso_compute_subtree_is_trapless_readonly(
    cache, func, node_masks, node_id,
  )
  cache.readonly_revision[node_id] = revision
  cache.readonly_result[node_id] = result
  result
}

///|
fn hso_nodes_can_reorder(
  cache : HsoPredicateCache,
  func : @ir.HotFunc,
  node_masks : Array[UInt],
  barrier_id : Int,
  barrier_mask : UInt,
  moved_id : Int,
  moved_mask : UInt,
) -> Bool {
  if !hso_mask_invalidates(barrier_mask, moved_mask) {
    return true
  }
  hso_subtree_is_trapless_readonly(cache, func, node_masks, barrier_id) &&
  hso_subtree_is_trapless_readonly(cache, func, node_masks, moved_id)
}

///|
fn hso_root_can_swap_before_local_struct_new(
  cache : HsoPredicateCache,
  func : @ir.HotFunc,
  node_masks : Array[UInt],
  node_id : Int,
  target_local_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let mask = hso_reorder_effect_mask(cache, func, node_masks, node_id)
  let disallowed_effects = @ir.EFFECT_MASK_CONTROL |
    @ir.EFFECT_MASK_CALL |
    @ir.EFFECT_MASK_THROW |
    @ir.EFFECT_MASK_TRAP |
    @ir.EFFECT_MASK_MEMORY_READ |
    @ir.EFFECT_MASK_MEMORY_WRITE |
    @ir.EFFECT_MASK_TABLE_READ |
    @ir.EFFECT_MASK_TABLE_WRITE
  if (mask & @ir.EFFECT_MASK_LOCAL_STATE) != 0U &&
    hso_subtree_touches_local(func, node_id, target_local_id) {
    return false
  }
  if (mask & disallowed_effects) == 0U {
    return true
  }
  hso_subtree_is_trapless_readonly(cache, func, node_masks, node_id)
}

///|
fn hso_swapped_readonly_roots_respect_ref_order(
  cache : HsoPredicateCache,
  func : @ir.HotFunc,
  node_masks : Array[UInt],
  swapped_roots : Array[Int],
  ref_id : Int,
) -> Bool {
  for root_id in swapped_roots {
    if root_id < 0 || !@ir.hot_node_is_live(func, root_id) {
      continue
    }
    let mask = hso_reorder_effect_mask(cache, func, node_masks, root_id)
    if !hso_mask_is_pure(mask) &&
      hso_subtree_is_trapless_readonly(cache, func, node_masks, root_id) &&
      ref_id < root_id {
      return false
    }
  }
  true
}

///|
fn hso_build_const_f32(func : @ir.HotFunc) -> Int {
  @ir.hot_build_const_f32(func, @lib.F32(0.0))
}

///|
fn hso_build_const_f64(func : @ir.HotFunc) -> Int {
  @ir.hot_build_const_f64(func, @lib.F64(0.0))
}

///|
fn hso_build_const_v128_zero(func : @ir.HotFunc) -> Int {
  @ir.hot_build_const_v128_zero(func)
}

///|
fn hso_build_default_value(func : @ir.HotFunc, vt : @lib.ValType) -> Int? {
  match vt {
    @lib.NumTypeValType(@lib.I32NumType) =>
      Some(@ir.hot_build_const_i32(func, @lib.I32(0)))
    @lib.NumTypeValType(@lib.I64NumType) =>
      Some(@ir.hot_build_const_i64(func, @lib.I64(0L)))
    @lib.NumTypeValType(@lib.F32NumType) => Some(hso_build_const_f32(func))
    @lib.NumTypeValType(@lib.F64NumType) => Some(hso_build_const_f64(func))
    @lib.VecTypeValType => Some(hso_build_const_v128_zero(func))
    @lib.RefTypeValType(ref_type) =>
      if ref_type.is_nullable() {
        Some(@ir.hot_build_ref_null(func, ref_type))
      } else {
        None
      }
    @lib.BotValType => None
  }
}

///|
fn hso_type_has_defaultable_struct_fields(
  type_cache : HsoTypeCache,
  module_ctx : @ir.HotModuleContext,
  type_idx : @lib.TypeIdx,
) -> Int? {
  let type_slot = match type_idx {
    @lib.TypeIdx(raw_idx) | @lib.RecIdx(raw_idx) => raw_idx.reinterpret_as_int()
  }
  hso_ensure_type_cache_capacity(type_cache, type_slot)
  match type_cache.default_field_counts[type_slot] {
    count if count >= 0 => return Some(count)
    -1 => return None
    _ => ()
  }
  let fields = match
    @ir.hot_module_resolve_struct_fields(module_ctx, type_idx) {
    Some(fields) => fields
    None => return None
  }
  for field in fields {
    let @lib.FieldType(stor, _) = field
    match stor.unpack() {
      @lib.RefTypeValType(ref_type) =>
        if !ref_type.is_nullable() {
          type_cache.default_field_counts[type_slot] = -1
          return None
        }
      _ => ()
    }
  }
  type_cache.default_field_counts[type_slot] = fields.length()
  Some(fields.length())
}

///|
fn hso_build_default_struct_new_children(
  func : @ir.HotFunc,
  module_ctx : @ir.HotModuleContext,
  type_idx : @lib.TypeIdx,
  field_idx : Int,
  replacement_id : Int,
  desc_id : Int?,
) -> Array[Int]? {
  let fields = match
    @ir.hot_module_resolve_struct_fields(module_ctx, type_idx) {
    Some(fields) => fields
    None => return None
  }
  let children : Array[Int] = []
  for idx = 0; idx < fields.length(); idx = idx + 1 {
    if idx == field_idx {
      children.push(replacement_id)
      continue
    }
    let @lib.FieldType(stor, _) = fields[idx]
    match hso_build_default_value(func, stor.unpack()) {
      Some(value_id) => children.push(value_id)
      None => return None
    }
  }
  match desc_id {
    Some(desc_id) => children.push(desc_id)
    None => ()
  }
  Some(children)
}

///|
fn hso_supported_struct_new(
  type_cache : HsoTypeCache,
  func : @ir.HotFunc,
  module_ctx : @ir.HotModuleContext?,
  node_id : Int,
) -> (@lib.TypeIdx, Int, Int?, Bool)? {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return None
  }
  let child_count = @ir.hot_child_count(func, node_id)
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::StructNew(type_idx)) =>
      Some((type_idx, child_count, None, false))
    Some(@lib.Instruction::StructNewDesc(type_idx)) =>
      if child_count > 0 {
        Some(
          (
            type_idx,
            child_count - 1,
            Some(@ir.hot_child_get(func, node_id, child_count - 1)),
            false,
          ),
        )
      } else {
        None
      }
    Some(@lib.Instruction::StructNewDefault(type_idx)) =>
      match module_ctx {
        Some(module_ctx) =>
          match
            hso_type_has_defaultable_struct_fields(
              type_cache, module_ctx, type_idx,
            ) {
            Some(field_count) => Some((type_idx, field_count, None, true))
            None => None
          }
        None => None
      }
    Some(@lib.Instruction::StructNewDefaultDesc(type_idx)) =>
      if child_count > 0 {
        let desc_id = @ir.hot_child_get(func, node_id, child_count - 1)
        match module_ctx {
          Some(module_ctx) =>
            match
              hso_type_has_defaultable_struct_fields(
                type_cache, module_ctx, type_idx,
              ) {
              Some(field_count) =>
                Some((type_idx, field_count, Some(desc_id), true))
              None => None
            }
          None => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn hso_struct_new_shallow_effects(func : @ir.HotFunc, node_id : Int) -> UInt {
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::StructNew(_))
    | Some(@lib.Instruction::StructNewDefault(_))
    | Some(@lib.Instruction::StructNewDesc(_))
    | Some(@lib.Instruction::StructNewDefaultDesc(_)) =>
      @ir.EFFECT_MASK_MEMORY_READ |
      @ir.EFFECT_MASK_MEMORY_WRITE |
      @ir.EFFECT_MASK_TRAP
    _ => 0U
  }
}

///|
fn hso_struct_set_parts(
  func : @ir.HotFunc,
  node_id : Int,
) -> (@lib.TypeIdx, Int, Int, Int)? {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return None
  }
  if @ir.hot_child_count(func, node_id) != 2 {
    return None
  }
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::StructSet(type_idx, field_idx)) => {
      let @lib.U32(raw_field_idx) = field_idx
      Some(
        (
          type_idx,
          raw_field_idx.reinterpret_as_int(),
          @ir.hot_child_get(func, node_id, 0),
          @ir.hot_child_get(func, node_id, 1),
        ),
      )
    }
    _ => None
  }
}

///|
fn hso_sequence_result_type(
  func : @ir.HotFunc,
  value_id : Int,
) -> @lib.BlockType? {
  let results = @ir.hot_type_results(func, @ir.hot_node_get(func, value_id).ty)
  if results.length() != 1 {
    return None
  }
  Some(@lib.BlockType::val_type(results[0]))
}

///|
fn hso_value_has_readonly_prefix_block(
  cache : HsoPredicateCache,
  func : @ir.HotFunc,
  node_masks : Array[UInt],
  value_id : Int,
) -> Bool {
  if value_id < 0 || !@ir.hot_node_is_live(func, value_id) {
    return false
  }
  let node = @ir.hot_node_get(func, value_id)
  match node.op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  let body_ref = @ir.hot_region_body_ref(func, value_id)
  let root_count = @ir.hot_region_root_count(func, body_ref)
  if root_count < 2 {
    return false
  }
  let mut has_local_or_global_state = false
  for idx = 0; idx < root_count; idx = idx + 1 {
    let root_id = @ir.hot_region_get(func, body_ref, idx)
    if !hso_subtree_is_trapless_readonly(cache, func, node_masks, root_id) {
      return false
    }
    let root_mask = hso_reorder_effect_mask(cache, func, node_masks, root_id)
    if (
        root_mask & (@ir.EFFECT_MASK_LOCAL_STATE | @ir.EFFECT_MASK_GLOBAL_STATE)
      ) !=
      0U {
      has_local_or_global_state = true
    }
  }
  has_local_or_global_state
}

///|
fn hso_build_preserved_replacement(
  func : @ir.HotFunc,
  node_masks : Array[UInt],
  old_value_id : Int,
  new_value_id : Int,
) -> Int? {
  let old_mask = hso_effects_for_node(func, node_masks, old_value_id)
  if hso_mask_is_pure(old_mask) {
    return Some(new_value_id)
  }
  match hso_sequence_result_type(func, new_value_id) {
    Some(block_type) => {
      let drop_old = @ir.hot_build_drop(func, old_value_id)
      Some(@ir.hot_build_block(func, block_type, [drop_old, new_value_id]))
    }
    None => None
  }
}

///|
fn hso_array_insert_prefix_roots(
  roots : Array[Int],
  idx : Int,
  inserted : Array[Int],
  count : Int,
) -> Unit {
  if count <= 0 {
    return
  }
  let suffix : Array[Int] = []
  for suffix_idx = idx; suffix_idx < roots.length(); suffix_idx = suffix_idx + 1 {
    suffix.push(roots[suffix_idx])
  }
  while roots.length() > idx {
    ignore(roots.pop())
  }
  for inserted_idx = 0; inserted_idx < count; inserted_idx = inserted_idx + 1 {
    roots.push(inserted[inserted_idx])
  }
  for suffix_root_id in suffix {
    roots.push(suffix_root_id)
  }
}

///|
fn hso_liftable_swapped_block_roots(
  cache : HsoPredicateCache,
  func : @ir.HotFunc,
  node_masks : Array[UInt],
  node_id : Int,
  local_id : Int,
) -> Array[Int]? {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Block => ()
    _ => return None
  }
  if hso_sequence_result_type(func, node_id) != None {
    return None
  }
  let body_ref = @ir.hot_region_body_ref(func, node_id)
  let roots = hso_region_roots(func, body_ref)
  if roots.is_empty() {
    return None
  }
  for root_id in roots {
    if !hso_root_can_swap_before_local_struct_new(
        cache, func, node_masks, root_id, local_id,
      ) {
      return None
    }
  }
  Some(roots)
}

///|
fn hso_try_fold_into_struct_new(
  cache : HsoPredicateCache,
  type_cache : HsoTypeCache,
  func : @ir.HotFunc,
  module_ctx : @ir.HotModuleContext?,
  node_masks : Array[UInt],
  struct_new_id : Int,
  type_idx : @lib.TypeIdx,
  field_idx : Int,
  value_id : Int,
  local_id : Int,
) -> Bool {
  let (new_type_idx, field_count, desc_id, needs_default_materialization) = match
    hso_supported_struct_new(type_cache, func, module_ctx, struct_new_id) {
    Some(parts) => parts
    _ => return false
  }
  if new_type_idx != type_idx || field_idx < 0 || field_idx >= field_count {
    return false
  }

  let value_mask = hso_effects_for_node(func, node_masks, value_id)
  let value_reorder_mask = hso_reorder_effect_mask(
    cache, func, node_masks, value_id,
  )
  if hso_value_has_readonly_prefix_block(cache, func, node_masks, value_id) {
    return false
  }
  if (value_mask & @ir.EFFECT_MASK_LOCAL_STATE) != 0U &&
    hso_subtree_touches_local(func, value_id, local_id) {
    return false
  }
  if hso_subtree_may_skip_local_set(cache, func, value_id) {
    return false
  }
  if hso_mask_invalidates(
      hso_struct_new_shallow_effects(func, struct_new_id),
      value_reorder_mask,
    ) &&
    !hso_subtree_is_trapless_readonly(cache, func, node_masks, value_id) {
    return false
  }

  for idx = field_idx + 1; idx < field_count; idx = idx + 1 {
    let later_id = if needs_default_materialization {
      -1
    } else {
      @ir.hot_child_get(func, struct_new_id, idx)
    }
    if !hso_nodes_can_reorder(
        cache,
        func,
        node_masks,
        later_id,
        if later_id >= 0 {
          hso_effects_for_node(func, node_masks, later_id)
        } else {
          0U
        },
        value_id,
        value_reorder_mask,
      ) {
      return false
    }
  }
  match desc_id {
    Some(desc_id) =>
      if !hso_nodes_can_reorder(
          cache,
          func,
          node_masks,
          desc_id,
          hso_effects_for_node(func, node_masks, desc_id),
          value_id,
          value_reorder_mask,
        ) {
        return false
      }
    None => ()
  }

  if needs_default_materialization {
    let module_ctx = match module_ctx {
      Some(module_ctx) => module_ctx
      None => return false
    }
    let children = match
      hso_build_default_struct_new_children(
        func, module_ctx, type_idx, field_idx, value_id, desc_id,
      ) {
      Some(children) => children
      None => return false
    }
    let instr = match desc_id {
      Some(_) => @lib.Instruction::struct_new_desc(type_idx)
      None => @lib.Instruction::struct_new(type_idx)
    }
    let replacement_id = @ir.hot_build_heap(
      func,
      @ir.hot_type_results(func, @ir.hot_node_get(func, struct_new_id).ty),
      instr,
      children,
    )
    let replacement = @ir.hot_node_get(func, replacement_id)
    @ir.hot_delete_node(func, replacement_id)
    @ir.hot_replace_node(func, struct_new_id, replacement)
  } else {
    let old_value_id = @ir.hot_child_get(func, struct_new_id, field_idx)
    let replacement = match
      hso_build_preserved_replacement(func, node_masks, old_value_id, value_id) {
      Some(replacement) => replacement
      None => return false
    }
    @ir.hot_child_set(func, struct_new_id, field_idx, replacement)
  }
  true
}

///|
fn hso_try_fold_tee_wrapped_struct_set(
  cache : HsoPredicateCache,
  type_cache : HsoTypeCache,
  func : @ir.HotFunc,
  module_ctx : @ir.HotModuleContext?,
  node_masks : Array[UInt],
  node_id : Int,
) -> Array[Int]? {
  let (type_idx, field_idx, ref_id, value_id) = match
    hso_struct_set_parts(func, node_id) {
    Some(parts) => parts
    None => return None
  }
  if !@ir.hot_node_is_live(func, ref_id) {
    return None
  }
  let ref_node = @ir.hot_node_get(func, ref_id)
  match ref_node.op {
    @ir.HotOp::LocalTee => ()
    _ => return None
  }
  if @ir.hot_child_count(func, ref_id) != 1 {
    return None
  }
  let struct_new_id = @ir.hot_child_get(func, ref_id, 0)
  if !hso_try_fold_into_struct_new(
      cache,
      type_cache,
      func,
      module_ctx,
      node_masks,
      struct_new_id,
      type_idx,
      field_idx,
      value_id,
      ref_node.imm0,
    ) {
    return None
  }
  let local_set_id = @ir.hot_build_local_set(func, ref_node.imm0, struct_new_id)
  let replacement_roots : Array[Int] = [local_set_id]
  Some(replacement_roots)
}

///|
fn hso_local_set_struct_new(
  type_cache : HsoTypeCache,
  func : @ir.HotFunc,
  module_ctx : @ir.HotModuleContext?,
  node_id : Int,
) -> (Int, Int, @lib.TypeIdx)? {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalSet => ()
    _ => return None
  }
  if @ir.hot_child_count(func, node_id) != 1 {
    return None
  }
  let struct_new_id = @ir.hot_child_get(func, node_id, 0)
  match hso_supported_struct_new(type_cache, func, module_ctx, struct_new_id) {
    Some((type_idx, _, _, _)) => Some((node.imm0, struct_new_id, type_idx))
    None => None
  }
}

///|
fn hso_struct_set_for_local(
  func : @ir.HotFunc,
  node_id : Int,
  local_id : Int,
  expected_type_idx : @lib.TypeIdx,
) -> (Int, Int, Int)? {
  let (type_idx, field_idx, ref_id, value_id) = match
    hso_struct_set_parts(func, node_id) {
    Some(parts) => parts
    None => return None
  }
  if type_idx != expected_type_idx || !@ir.hot_node_is_live(func, ref_id) {
    return None
  }
  let ref_node = @ir.hot_node_get(func, ref_id)
  match ref_node.op {
    @ir.HotOp::LocalGet => if ref_node.imm0 != local_id { return None }
    _ => return None
  }
  Some((field_idx, ref_id, value_id))
}

///|
fn hso_process_node_regions(
  cache : HsoPredicateCache,
  type_cache : HsoTypeCache,
  func : @ir.HotFunc,
  module_ctx : @ir.HotModuleContext?,
  node_masks : Array[UInt],
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      hso_process_region(
        cache,
        type_cache,
        func,
        module_ctx,
        node_masks,
        @ir.hot_region_body_ref(func, node_id),
      )
    @ir.HotOp::If => {
      let mut changed = hso_process_region(
        cache,
        type_cache,
        func,
        module_ctx,
        node_masks,
        @ir.hot_region_then_ref(func, node_id),
      )
      match @ir.hot_region_else_ref(func, node_id) {
        Some(region_ref) =>
          changed = hso_process_region(
              cache, type_cache, func, module_ctx, node_masks, region_ref,
            ) ||
            changed
        None => ()
      }
      changed
    }
    @ir.HotOp::Try => {
      let mut changed = hso_process_region(
        cache,
        type_cache,
        func,
        module_ctx,
        node_masks,
        @ir.hot_region_body_ref(func, node_id),
      )
      match @ir.hot_region_catch_ref(func, node_id) {
        Some(region_ref) =>
          changed = hso_process_region(
              cache, type_cache, func, module_ctx, node_masks, region_ref,
            ) ||
            changed
        None => ()
      }
      changed
    }
    @ir.HotOp::TryTable =>
      hso_process_region(
        cache,
        type_cache,
        func,
        module_ctx,
        node_masks,
        @ir.hot_region_body_ref(func, node_id),
      ) ||
      hso_process_region(
        cache,
        type_cache,
        func,
        module_ctx,
        node_masks,
        @ir.hot_region_catch_list_ref(func, node_id),
      )
    _ => false
  }
}

///|
fn hso_node_may_have_regions(op : @ir.HotOp) -> Bool {
  match op {
    @ir.HotOp::Block
    | @ir.HotOp::Loop
    | @ir.HotOp::If
    | @ir.HotOp::Try
    | @ir.HotOp::TryTable => true
    _ => false
  }
}

///|
fn hso_region_roots(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Array[Int] {
  let roots : Array[Int] = []
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    roots.push(@ir.hot_region_get(func, region_ref, idx))
  }
  roots
}

///|
fn hso_process_region(
  cache : HsoPredicateCache,
  type_cache : HsoTypeCache,
  func : @ir.HotFunc,
  module_ctx : @ir.HotModuleContext?,
  node_masks : Array[UInt],
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let roots = hso_region_roots(func, region_ref)
  let mut changed = false

  for root_id in roots {
    let root_node = @ir.hot_node_get(func, root_id)
    if hso_node_may_have_regions(root_node.op) {
      changed = hso_process_node_regions(
          cache, type_cache, func, module_ctx, node_masks, root_id,
        ) ||
        changed
    }
  }

  let next_roots : Array[Int] = []
  let mut idx = 0
  while idx < roots.length() {
    let root_id = roots[idx]
    let root_node = @ir.hot_node_get(func, root_id)
    match root_node.op {
      @ir.HotOp::Heap => {
        match
          hso_try_fold_tee_wrapped_struct_set(
            cache, type_cache, func, module_ctx, node_masks, root_id,
          ) {
          Some(replacement_roots) => {
            changed = true
            for replacement_root_id in replacement_roots {
              next_roots.push(replacement_root_id)
            }
          }
          None => next_roots.push(root_id)
        }
        idx = idx + 1
      }
      @ir.HotOp::LocalSet =>
        match hso_local_set_struct_new(type_cache, func, module_ctx, root_id) {
          Some((local_id, struct_new_id, type_idx)) => {
            let segment_roots : Array[Int] = [root_id]
            let swapped_prefix_roots : Array[Int] = []
            let mut segment_local_set_idx = 0
            let mut segment_has_swapped_prefix = false
            let mut next_idx = idx + 1
            while next_idx < roots.length() {
              match
                hso_struct_set_for_local(
                  func,
                  roots[next_idx],
                  local_id,
                  type_idx,
                ) {
                Some((field_idx, ref_id, value_id)) => {
                  if segment_has_swapped_prefix &&
                    !hso_swapped_readonly_roots_respect_ref_order(
                      cache, func, node_masks, swapped_prefix_roots, ref_id,
                    ) {
                    break
                  }
                  if hso_try_fold_into_struct_new(
                      cache, type_cache, func, module_ctx, node_masks, struct_new_id,
                      type_idx, field_idx, value_id, local_id,
                    ) {
                    let nop_id = @ir.hot_build_nop(func)
                    if segment_has_swapped_prefix {
                      hso_array_insert_prefix_roots(
                        segment_roots,
                        segment_local_set_idx,
                        [nop_id],
                        1,
                      )
                      segment_local_set_idx = segment_local_set_idx + 1
                    }
                    changed = true
                    if !segment_has_swapped_prefix {
                      segment_roots.push(nop_id)
                    }
                    next_idx = next_idx + 1
                    continue
                  }
                }
                None => ()
              }
              if next_idx < roots.length() - 1 {
                match
                  hso_liftable_swapped_block_roots(
                    cache,
                    func,
                    node_masks,
                    roots[next_idx],
                    local_id,
                  ) {
                  Some(lifted_roots) => {
                    hso_array_insert_prefix_roots(
                      segment_roots,
                      segment_local_set_idx,
                      lifted_roots,
                      lifted_roots.length(),
                    )
                    for lifted_root_id in lifted_roots {
                      swapped_prefix_roots.push(lifted_root_id)
                    }
                    segment_local_set_idx = segment_local_set_idx +
                      lifted_roots.length()
                    segment_has_swapped_prefix = true
                    changed = true
                    next_idx = next_idx + 1
                    continue
                  }
                  None =>
                    if hso_root_can_swap_before_local_struct_new(
                        cache,
                        func,
                        node_masks,
                        roots[next_idx],
                        local_id,
                      ) {
                      segment_roots.push(roots[next_idx])
                      let last_idx = segment_roots.length() - 1
                      let moved_local_set_id = segment_roots[segment_local_set_idx]
                      segment_roots[segment_local_set_idx] = segment_roots[last_idx]
                      segment_roots[last_idx] = moved_local_set_id
                      swapped_prefix_roots.push(roots[next_idx])
                      segment_local_set_idx = last_idx
                      segment_has_swapped_prefix = true
                      changed = true
                      next_idx = next_idx + 1
                      continue
                    }
                }
              }
              break
            }
            for segment_root_id in segment_roots {
              next_roots.push(segment_root_id)
            }
            idx = next_idx
          }
          None => {
            next_roots.push(root_id)
            idx = idx + 1
          }
        }
      _ => {
        next_roots.push(root_id)
        idx = idx + 1
      }
    }
  }

  if !@lib.equals(roots, next_roots) {
    ignore(
      @ir.hot_region_splice(func, region_ref, 0, roots.length(), next_roots),
    )
    changed = true
  }
  changed
}

///|
fn heap_store_optimization_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> HotPassResult {
  let effects = pass_require_effects(ctx, func)
  let predicate_cache = hso_new_predicate_cache(func)
  let type_cache = hso_new_type_cache()
  if hso_process_region(
      predicate_cache,
      type_cache,
      func,
      ctx.module_ctx,
      effects.node_masks,
      @ir.HotRegionRef::root(),
    ) {
    pass_mark_mutated(ctx, func)
    HotPassResult::changed()
  } else {
    HotPassResult::unchanged()
  }
}
