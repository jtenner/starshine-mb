///|
pub fn simplify_locals_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new(
    "simplify-locals",
    requires=[
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
fn simplify_locals_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> HotPassResult {
  let ssa = pass_require_ssa(ctx, func)
  let dead_nodes : Array[Int] = []
  let detached_tee_nodes : Array[Int] = []
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
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
          @ir.HotOp::LocalTee => {
            let child_id = @ir.hot_child_get(func, node_id, 0)
            if child_id >= 0 && @ir.hot_node_is_live(func, child_id) {
              detached_tee_nodes.push(child_id)
            }
          }
          _ => ()
        }
      }
      _ => ()
    }
  }
  if dead_nodes.length() == 0 {
    return HotPassResult::unchanged()
  }
  @ir.ssa_remove_dead_local_defs(func, dead_nodes)
  @ir.cache_invalidate_all(ctx.cache)
  simplify_locals_delete_detached_nodes(ctx, func, detached_tee_nodes)
  pass_mark_mutated(ctx, func)
  HotPassResult::changed()
}
