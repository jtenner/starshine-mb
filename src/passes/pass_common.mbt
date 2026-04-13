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
  let revision = @ir.hot_revision_current(func)
  let is_current = match ctx.cache.cfg {
    Some(entry) => entry.built_at_revision == revision
    None => false
  }
  if is_current {
    return @ir.cache_get_or_build_cfg(ctx.cache, func)
  }
  let start_us = perf_start_timer_opt(ctx.perf, "analysis:cfg")
  let cfg = @ir.cache_get_or_build_cfg(ctx.cache, func)
  perf_stop_timer_opt(ctx.perf, "analysis:cfg", start_us)
  match ctx.perf {
    Some(perf) => {
      perf_count_cfg_build(perf)
      perf_count_traversal_visit(perf, count=@ir.cfg_block_count(cfg))
      perf_dump_cfg(perf, cfg, "analysis:cfg")
    }
    None => ()
  }
  cfg
}

///|
pub fn pass_require_orders(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> @ir.HotCfgOrders {
  let revision = @ir.hot_revision_current(func)
  let is_current = match ctx.cache.orders {
    Some(entry) => entry.built_at_revision == revision
    None => false
  }
  if is_current {
    return @ir.cache_get_or_build_orders(ctx.cache, func)
  }
  let start_us = perf_start_timer_opt(ctx.perf, "analysis:orders")
  let orders = @ir.cache_get_or_build_orders(ctx.cache, func)
  perf_stop_timer_opt(ctx.perf, "analysis:orders", start_us)
  match ctx.perf {
    Some(perf) => {
      perf_count_dataflow_build(perf, "orders")
      perf_count_traversal_visit(perf, count=orders.worklist_seed.length())
    }
    None => ()
  }
  orders
}

///|
pub fn pass_require_dom(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> @ir.HotDominators {
  let revision = @ir.hot_revision_current(func)
  let is_current = match ctx.cache.dom {
    Some(entry) => entry.built_at_revision == revision
    None => false
  }
  if is_current {
    return @ir.cache_get_or_build_dom(ctx.cache, func)
  }
  let start_us = perf_start_timer_opt(ctx.perf, "analysis:dom")
  let dom = @ir.cache_get_or_build_dom(ctx.cache, func)
  perf_stop_timer_opt(ctx.perf, "analysis:dom", start_us)
  match ctx.perf {
    Some(perf) => {
      perf_count_dataflow_build(perf, "dom")
      perf_count_traversal_visit(
        perf,
        count=@ir.cfg_block_count(pass_require_cfg(ctx, func)),
      )
    }
    None => ()
  }
  dom
}

///|
pub fn pass_require_postdom(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> @ir.HotPostDominators {
  let revision = @ir.hot_revision_current(func)
  let is_current = match ctx.cache.postdom {
    Some(entry) => entry.built_at_revision == revision
    None => false
  }
  if is_current {
    return @ir.cache_get_or_build_postdom(ctx.cache, func)
  }
  let start_us = perf_start_timer_opt(ctx.perf, "analysis:postdom")
  let postdom = @ir.cache_get_or_build_postdom(ctx.cache, func)
  perf_stop_timer_opt(ctx.perf, "analysis:postdom", start_us)
  match ctx.perf {
    Some(perf) => {
      perf_count_dataflow_build(perf, "postdom")
      perf_count_traversal_visit(
        perf,
        count=@ir.cfg_block_count(pass_require_cfg(ctx, func)),
      )
    }
    None => ()
  }
  postdom
}

///|
pub fn pass_require_loop_info(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> @ir.HotLoopInfo {
  let revision = @ir.hot_revision_current(func)
  let is_current = match ctx.cache.loop_info {
    Some(entry) => entry.built_at_revision == revision
    None => false
  }
  if is_current {
    return @ir.cache_get_or_build_loop_info(ctx.cache, func)
  }
  let start_us = perf_start_timer_opt(ctx.perf, "analysis:loop-info")
  let loop_info = @ir.cache_get_or_build_loop_info(ctx.cache, func)
  perf_stop_timer_opt(ctx.perf, "analysis:loop-info", start_us)
  match ctx.perf {
    Some(perf) => {
      perf_count_dataflow_build(perf, "loop-info")
      perf_count_traversal_visit(
        perf,
        count=@ir.cfg_block_count(pass_require_cfg(ctx, func)),
      )
    }
    None => ()
  }
  loop_info
}

///|
pub fn pass_require_use_def(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> @ir.HotUseDef {
  let revision = @ir.hot_revision_current(func)
  let is_current = match ctx.cache.use_def {
    Some(entry) => entry.built_at_revision == revision
    None => false
  }
  if is_current {
    return @ir.cache_get_or_build_use_def(ctx.cache, func)
  }
  let start_us = perf_start_timer_opt(ctx.perf, "analysis:use-def")
  let use_def = @ir.cache_get_or_build_use_def(ctx.cache, func)
  perf_stop_timer_opt(ctx.perf, "analysis:use-def", start_us)
  match ctx.perf {
    Some(perf) => {
      perf_count_dataflow_build(perf, "use-def")
      perf_count_traversal_visit(perf, count=@ir.hot_node_count(func))
    }
    None => ()
  }
  use_def
}

///|
pub fn pass_require_liveness(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> @ir.HotLiveness {
  let revision = @ir.hot_revision_current(func)
  let is_current = match ctx.cache.liveness {
    Some(entry) => entry.built_at_revision == revision
    None => false
  }
  if is_current {
    return @ir.cache_get_or_build_liveness(ctx.cache, func)
  }
  let start_us = perf_start_timer_opt(ctx.perf, "analysis:liveness")
  let liveness = @ir.cache_get_or_build_liveness(ctx.cache, func)
  perf_stop_timer_opt(ctx.perf, "analysis:liveness", start_us)
  match ctx.perf {
    Some(perf) => {
      perf_count_dataflow_build(perf, "liveness")
      perf_count_traversal_visit(
        perf,
        count=@ir.cfg_block_count(pass_require_cfg(ctx, func)),
      )
    }
    None => ()
  }
  liveness
}

///|
pub fn pass_require_effects(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> @ir.HotEffectsSummary {
  let revision = @ir.hot_revision_current(func)
  let is_current = match ctx.cache.effects {
    Some(entry) => entry.built_at_revision == revision
    None => false
  }
  if is_current {
    return @ir.cache_get_or_build_effects(ctx.cache, func)
  }
  let start_us = perf_start_timer_opt(ctx.perf, "analysis:effects")
  let effects = @ir.cache_get_or_build_effects(ctx.cache, func)
  perf_stop_timer_opt(ctx.perf, "analysis:effects", start_us)
  match ctx.perf {
    Some(perf) => {
      perf_count_dataflow_build(perf, "effects")
      perf_count_traversal_visit(perf, count=@ir.hot_node_count(func))
    }
    None => ()
  }
  effects
}

///|
pub fn pass_require_ssa(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> @ir.HotLocalSsa {
  let revision = @ir.hot_revision_current(func)
  let is_current = match ctx.cache.ssa {
    Some(entry) => entry.built_at_revision == revision
    None => false
  }
  if is_current {
    return @ir.cache_get_or_build_ssa(ctx.cache, func)
  }
  let start_us = perf_start_timer_opt(ctx.perf, "analysis:ssa")
  let ssa = @ir.cache_get_or_build_ssa(ctx.cache, func)
  perf_stop_timer_opt(ctx.perf, "analysis:ssa", start_us)
  match ctx.perf {
    Some(perf) => {
      perf_count_dataflow_build(perf, "ssa")
      perf_count_traversal_visit(
        perf,
        count=@ir.cfg_block_count(pass_require_cfg(ctx, func)),
      )
    }
    None => ()
  }
  ssa
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
    match ctx.perf {
      Some(perf) => perf_count_region_splice(perf)
      None => ()
    }
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
    pipeline_verify_checkpoint_with_perf(
      ctx.perf,
      ctx.verify_policy,
      "verify before \{ctx.descriptor.name}",
      HotPipelineVerifyTarget::HotFuncTarget(func),
      "verify:before:\{ctx.descriptor.name}",
    ) {
    Ok(_) =>
      pipeline_verify_checkpoint_with_perf(
        ctx.perf,
        ctx.verify_policy,
        "verify after \{ctx.descriptor.name}",
        HotPipelineVerifyTarget::HotFuncTarget(func),
        "verify:after:\{ctx.descriptor.name}",
      )
    Err(err) => Err(err)
  }
}
