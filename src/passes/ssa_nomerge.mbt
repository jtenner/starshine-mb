///|
pub fn ssa_nomerge_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new("ssa-nomerge", invalidates=[
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
pub fn ssa_nomerge_summary() -> String {
  "Untangle hot locals into semi-SSA form and lower overlay phis through predecessor copies."
}

///|
fn ssa_nomerge_has_local_writes(func : @ir.HotFunc) -> Bool {
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => return true
      _ => ()
    }
  }
  false
}

///|
fn ssa_nomerge_needs_rewrite(ssa : @ir.HotLocalSsa) -> Bool {
  if ssa.phis.length() != 0 {
    return true
  }
  for origin in ssa.value_origins {
    match origin {
      @ir.HotSsaValueOrigin::LocalSetDef(_)
      | @ir.HotSsaValueOrigin::LocalTeeDef(_) => return true
      _ => ()
    }
  }
  false
}

///|
fn ssa_nomerge_run(ctx : HotPassContext, func : @ir.HotFunc) -> HotPassResult {
  if !ssa_nomerge_has_local_writes(func) {
    return HotPassResult::unchanged()
  }
  let cfg = pass_require_cfg(ctx, func)
  let ssa = pass_require_ssa(ctx, func)
  if !ssa_nomerge_needs_rewrite(ssa) {
    return HotPassResult::unchanged()
  }
  let before_revision = @ir.hot_revision_current(func)
  ignore(@ir.ssa_destroy_into_hot(func, cfg, ssa))
  if @ir.hot_revision_current(func) == before_revision {
    return HotPassResult::unchanged()
  }
  pass_mark_mutated(ctx, func)
  HotPassResult::changed()
}
