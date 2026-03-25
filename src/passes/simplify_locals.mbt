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
        let value_id = @ir.ssa_def_for_local_set(ssa, node_id)
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
  pass_delete_detached_nodes(ctx, func, detached_tee_nodes)
  pass_mark_mutated(ctx, func)
  HotPassResult::changed()
}
