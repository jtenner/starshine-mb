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
  false
}

///|
fn hso_supported_struct_new(
  func : @ir.HotFunc,
  node_id : Int,
) -> (@lib.TypeIdx, Int, Int?)? {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return None
  }
  let child_count = @ir.hot_child_count(func, node_id)
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::StructNew(type_idx)) =>
      Some((type_idx, child_count, None))
    Some(@lib.Instruction::StructNewDesc(type_idx)) =>
      if child_count > 0 {
        Some(
          (
            type_idx,
            child_count - 1,
            Some(@ir.hot_child_get(func, node_id, child_count - 1)),
          ),
        )
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
fn hso_try_fold_into_struct_new(
  func : @ir.HotFunc,
  node_masks : Array[UInt],
  struct_new_id : Int,
  type_idx : @lib.TypeIdx,
  field_idx : Int,
  value_id : Int,
  local_id : Int,
) -> Bool {
  let (new_type_idx, field_count, desc_id) = match
    hso_supported_struct_new(func, struct_new_id) {
    Some(parts) => parts
    _ => return false
  }
  if new_type_idx != type_idx || field_idx < 0 || field_idx >= field_count {
    return false
  }

  let value_mask = hso_effects_for_node(func, node_masks, value_id)
  if hso_subtree_touches_local(func, value_id, local_id) ||
    hso_mask_has_control_transfer(value_mask) {
    return false
  }
  if hso_mask_invalidates(
      hso_struct_new_shallow_effects(func, struct_new_id),
      value_mask,
    ) {
    return false
  }

  for idx = field_idx + 1; idx < field_count; idx = idx + 1 {
    let later_id = @ir.hot_child_get(func, struct_new_id, idx)
    if hso_mask_invalidates(
        hso_effects_for_node(func, node_masks, later_id),
        value_mask,
      ) {
      return false
    }
  }
  match desc_id {
    Some(desc_id) =>
      if hso_mask_invalidates(
          hso_effects_for_node(func, node_masks, desc_id),
          value_mask,
        ) {
        return false
      }
    None => ()
  }

  let old_value_id = @ir.hot_child_get(func, struct_new_id, field_idx)
  let replacement = match
    hso_build_preserved_replacement(func, node_masks, old_value_id, value_id) {
    Some(replacement) => replacement
    None => return false
  }
  @ir.hot_child_set(func, struct_new_id, field_idx, replacement)
  true
}

///|
fn hso_try_fold_tee_wrapped_struct_set(
  func : @ir.HotFunc,
  node_masks : Array[UInt],
  node_id : Int,
) -> Bool {
  let (type_idx, field_idx, ref_id, value_id) = match
    hso_struct_set_parts(func, node_id) {
    Some(parts) => parts
    None => return false
  }
  if !@ir.hot_node_is_live(func, ref_id) {
    return false
  }
  let ref_node = @ir.hot_node_get(func, ref_id)
  match ref_node.op {
    @ir.HotOp::LocalTee => ()
    _ => return false
  }
  if @ir.hot_child_count(func, ref_id) != 1 {
    return false
  }
  let struct_new_id = @ir.hot_child_get(func, ref_id, 0)
  if !hso_try_fold_into_struct_new(
      func,
      node_masks,
      struct_new_id,
      type_idx,
      field_idx,
      value_id,
      ref_node.imm0,
    ) {
    return false
  }
  let replacement_id = @ir.hot_build_local_set(
    func,
    ref_node.imm0,
    struct_new_id,
  )
  let replacement = @ir.hot_node_get(func, replacement_id)
  @ir.hot_delete_node(func, replacement_id)
  @ir.hot_replace_node(func, node_id, replacement)
  true
}

///|
fn hso_local_set_struct_new(
  func : @ir.HotFunc,
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
  match hso_supported_struct_new(func, struct_new_id) {
    Some((type_idx, _, _)) => Some((node.imm0, struct_new_id, type_idx))
    None => None
  }
}

///|
fn hso_struct_set_for_local(
  func : @ir.HotFunc,
  node_id : Int,
  local_id : Int,
  expected_type_idx : @lib.TypeIdx,
) -> (Int, Int)? {
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
  Some((field_idx, value_id))
}

///|
fn hso_process_node_regions(
  func : @ir.HotFunc,
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
        func,
        node_masks,
        @ir.hot_region_body_ref(func, node_id),
      )
    @ir.HotOp::If => {
      let mut changed = hso_process_region(
        func,
        node_masks,
        @ir.hot_region_then_ref(func, node_id),
      )
      match @ir.hot_region_else_ref(func, node_id) {
        Some(region_ref) =>
          changed = hso_process_region(func, node_masks, region_ref) || changed
        None => ()
      }
      changed
    }
    @ir.HotOp::Try => {
      let mut changed = hso_process_region(
        func,
        node_masks,
        @ir.hot_region_body_ref(func, node_id),
      )
      match @ir.hot_region_catch_ref(func, node_id) {
        Some(region_ref) =>
          changed = hso_process_region(func, node_masks, region_ref) || changed
        None => ()
      }
      changed
    }
    @ir.HotOp::TryTable =>
      hso_process_region(
        func,
        node_masks,
        @ir.hot_region_body_ref(func, node_id),
      ) ||
      hso_process_region(
        func,
        node_masks,
        @ir.hot_region_catch_list_ref(func, node_id),
      )
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
  func : @ir.HotFunc,
  node_masks : Array[UInt],
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let roots = hso_region_roots(func, region_ref)
  let mut changed = false

  for root_id in roots {
    changed = hso_process_node_regions(func, node_masks, root_id) || changed
  }

  let next_roots : Array[Int] = []
  let mut idx = 0
  while idx < roots.length() {
    let root_id = roots[idx]
    changed = hso_try_fold_tee_wrapped_struct_set(func, node_masks, root_id) ||
      changed
    match hso_local_set_struct_new(func, root_id) {
      Some((local_id, struct_new_id, type_idx)) => {
        let mut next_idx = idx + 1
        while next_idx < roots.length() {
          match
            hso_struct_set_for_local(func, roots[next_idx], local_id, type_idx) {
            Some((field_idx, value_id)) =>
              if hso_try_fold_into_struct_new(
                  func, node_masks, struct_new_id, type_idx, field_idx, value_id,
                  local_id,
                ) {
                changed = true
                next_roots.push(@ir.hot_build_nop(func))
                next_idx = next_idx + 1
                continue
              }
            None => ()
          }
          if next_idx < roots.length() - 1 &&
            hso_mask_is_pure(
              hso_effects_for_node(func, node_masks, roots[next_idx]),
            ) {
            next_roots.push(roots[next_idx])
            changed = true
            next_idx = next_idx + 1
            continue
          }
          break
        }
        next_roots.push(root_id)
        idx = next_idx
      }
      None => {
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
  if hso_process_region(func, effects.node_masks, @ir.HotRegionRef::root()) {
    pass_mark_mutated(ctx, func)
    HotPassResult::changed()
  } else {
    HotPassResult::unchanged()
  }
}
