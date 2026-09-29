///|
// Frozen V14 traversal, including its per-query arena-sized visitation row.
fn sl_effect_scan_before_workspace(
  func : @ir.HotFunc,
  node_id : Int,
) -> (@ir.EffectMask, Int) {
  let pending : Array[Int] = [node_id]
  let seen = Array::make(@ir.hot_node_count(func), false)
  let mut mask = 0U
  let mut visited_nodes = 0
  while !pending.is_empty() {
    let current_id = pending.pop().unwrap()
    if current_id < 0 ||
      current_id >= seen.length() ||
      seen[current_id] ||
      !@ir.hot_node_is_live(func, current_id) {
      continue
    }
    seen[current_id] = true
    visited_nodes += 1
    mask = mask | simplify_locals_effects_mask_for_exact_node(func, current_id)
    let current = @ir.hot_node_get(func, current_id)
    for slot = 0; slot < @ir.hot_child_count(func, current_id); slot = slot + 1 {
      if !simplify_locals_is_region_child_slot(func, current_id, slot) {
        pending.push(@ir.hot_child_get(func, current_id, slot))
      }
    }
    match current.op {
      @ir.HotOp::Block | @ir.HotOp::Loop =>
        simplify_locals_effect_scan_push_region(
          func,
          @ir.hot_region_body_ref(func, current_id),
          pending,
        )
      @ir.HotOp::If => {
        simplify_locals_effect_scan_push_region(
          func,
          @ir.hot_region_then_ref(func, current_id),
          pending,
        )
        match @ir.hot_region_else_ref(func, current_id) {
          Some(else_ref) =>
            simplify_locals_effect_scan_push_region(func, else_ref, pending)
          None => ()
        }
      }
      @ir.HotOp::Try => {
        simplify_locals_effect_scan_push_region(
          func,
          @ir.hot_region_body_ref(func, current_id),
          pending,
        )
        match @ir.hot_region_catch_ref(func, current_id) {
          Some(catch_ref) =>
            simplify_locals_effect_scan_push_region(func, catch_ref, pending)
          None => ()
        }
      }
      @ir.HotOp::TryTable => {
        simplify_locals_effect_scan_push_region(
          func,
          @ir.hot_region_body_ref(func, current_id),
          pending,
        )
        simplify_locals_effect_scan_push_region(
          func,
          @ir.hot_region_catch_list_ref(func, current_id),
          pending,
        )
      }
      _ => ()
    }
  }
  (mask, visited_nodes)
}
