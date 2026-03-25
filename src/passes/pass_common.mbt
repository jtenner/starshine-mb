///|
pub fn pass_prepare_requirements(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> Unit {
  for analysis in @ir.hot_pass_requires(ctx.descriptor) {
    match analysis {
      @ir.HotAnalysis::Cfg => ignore(pass_require_cfg(ctx, func))
      @ir.HotAnalysis::Dominance => ignore(pass_require_dom(ctx, func))
      @ir.HotAnalysis::Liveness => ignore(pass_require_liveness(ctx, func))
      @ir.HotAnalysis::UseDef => ignore(pass_require_use_def(ctx, func))
      @ir.HotAnalysis::Effects => ignore(pass_require_effects(ctx, func))
      @ir.HotAnalysis::LoopInfo => ignore(pass_require_loop_info(ctx, func))
      @ir.HotAnalysis::Ssa => ignore(pass_require_ssa(ctx, func))
    }
  }
}

///|
pub fn pass_require_cfg(ctx : HotPassContext, func : @ir.HotFunc) -> @ir.HotCfg {
  @ir.cache_get_or_build_cfg(ctx.cache, func)
}

///|
pub fn pass_require_orders(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> @ir.HotCfgOrders {
  @ir.cache_get_or_build_orders(ctx.cache, func)
}

///|
pub fn pass_require_dom(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> @ir.HotDominators {
  @ir.cache_get_or_build_dom(ctx.cache, func)
}

///|
pub fn pass_require_postdom(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> @ir.HotPostDominators {
  @ir.cache_get_or_build_postdom(ctx.cache, func)
}

///|
pub fn pass_require_loop_info(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> @ir.HotLoopInfo {
  @ir.cache_get_or_build_loop_info(ctx.cache, func)
}

///|
pub fn pass_require_use_def(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> @ir.HotUseDef {
  @ir.cache_get_or_build_use_def(ctx.cache, func)
}

///|
pub fn pass_require_liveness(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> @ir.HotLiveness {
  @ir.cache_get_or_build_liveness(ctx.cache, func)
}

///|
pub fn pass_require_effects(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> @ir.HotEffectsSummary {
  @ir.cache_get_or_build_effects(ctx.cache, func)
}

///|
pub fn pass_require_ssa(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> @ir.HotLocalSsa {
  @ir.cache_get_or_build_ssa(ctx.cache, func)
}

///|
pub fn pass_mark_mutated(ctx : HotPassContext, func : @ir.HotFunc) -> Unit {
  @ir.cache_invalidate_all(ctx.cache)
  pipeline_trace_hook(
    ctx.trace,
    ctx.descriptor.name,
    "mutated",
    payload="revision=\{@ir.hot_revision_current(func)}",
  )
}

///|
pub fn pass_replace_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  new_node : @ir.HotNode,
) -> Unit {
  @ir.hot_replace_node(func, node_id, new_node)
  pass_mark_mutated(ctx, func)
}

///|
pub fn pass_splice_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  remove_count : Int,
  node_ids : Array[Int],
) -> Array[Int] {
  let removed = @ir.hot_region_splice(
    func, region_ref, idx, remove_count, node_ids,
  )
  if remove_count != 0 || !node_ids.is_empty() {
    pass_mark_mutated(ctx, func)
  }
  removed
}

///|
pub fn pass_delete_detached_nodes(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_ids : Array[Int],
) -> Unit {
  let mut changed = false
  for node_id in node_ids {
    if @ir.hot_node_is_live(func, node_id) {
      @ir.hot_delete_node(func, node_id)
      changed = true
    }
  }
  if changed {
    pass_mark_mutated(ctx, func)
  }
}

///|
pub fn pass_node_use_count(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Int {
  @ir.node_use_count(pass_require_use_def(ctx, func), node_id)
}

///|
pub fn pass_node_is_unused(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  pass_node_use_count(ctx, func, node_id) == 0
}

///|
pub fn pass_verify_before_after(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> Result[Unit, String] {
  match
    pipeline_verify_checkpoint(
      ctx.verify_policy,
      "verify before \{ctx.descriptor.name}",
      HotPipelineVerifyTarget::HotFuncTarget(func),
    ) {
    Ok(_) =>
      pipeline_verify_checkpoint(
        ctx.verify_policy,
        "verify after \{ctx.descriptor.name}",
        HotPipelineVerifyTarget::HotFuncTarget(func),
      )
    Err(err) => Err(err)
  }
}
