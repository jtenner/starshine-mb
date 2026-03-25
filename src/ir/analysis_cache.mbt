///|
pub struct HotCacheEntry[T] {
  built_at_revision : Int
  value : T
} derive(Eq, Show, Debug)

///|
pub struct HotCfgOrders {
  preorder : Array[BlockId]
  postorder : Array[BlockId]
  reverse_postorder : Array[BlockId]
  reverse_postorder_with_exceptions : Array[BlockId]
  reverse_exit_postorder : Array[BlockId]
  reverse_exit_postorder_with_exceptions : Array[BlockId]
  worklist_seed : Array[BlockId]
} derive(Eq, Show, Debug)

///|
pub struct HotEffectsSummary {
  node_masks : Array[EffectMask]
  block_masks : Array[EffectMask]
  root_region_mask : EffectMask
} derive(Eq, Show, Debug)

///|
pub struct HotAnalysisCache {
  mut cfg : HotCacheEntry[HotCfg]?
  mut orders : HotCacheEntry[HotCfgOrders]?
  mut dom : HotCacheEntry[HotDominators]?
  mut postdom : HotCacheEntry[HotPostDominators]?
  mut loop_info : HotCacheEntry[HotLoopInfo]?
  mut use_def : HotCacheEntry[HotUseDef]?
  mut liveness : HotCacheEntry[HotLiveness]?
  mut effects : HotCacheEntry[HotEffectsSummary]?
  mut ssa : HotCacheEntry[HotLocalSsa]?
} derive(Eq, Show, Debug)

///|
pub fn HotAnalysisCache::new() -> HotAnalysisCache {
  {
    cfg: None,
    orders: None,
    dom: None,
    postdom: None,
    loop_info: None,
    use_def: None,
    liveness: None,
    effects: None,
    ssa: None,
  }
}

///|
fn[T] cache_entry_is_current(entry : HotCacheEntry[T]?, revision : Int) -> Bool {
  match entry {
    Some(item) => item.built_at_revision == revision
    None => false
  }
}

///|
fn[T] cache_entry_value(entry : HotCacheEntry[T]?) -> T {
  match entry {
    Some(item) => item.value
    None => abort("analysis cache entry must exist before reading its value")
  }
}

///|
fn cache_effects_build(func : HotFunc, cfg : HotCfg) -> HotEffectsSummary {
  let node_masks : Array[EffectMask] = []
  for node_id = 0; node_id < hot_node_count(func); node_id = node_id + 1 {
    node_masks.push(
      if hot_node_is_live(func, node_id) {
        effects_for_node(func, node_id)
      } else {
        0U
      },
    )
  }
  let block_masks : Array[EffectMask] = []
  for block_id = 0; block_id < cfg_block_count(cfg); block_id = block_id + 1 {
    block_masks.push(effects_for_block(func, cfg, block_id))
  }
  {
    node_masks,
    block_masks,
    root_region_mask: effects_for_region(func, HotRegionRef::root()),
  }
}

///|
pub fn cache_invalidate_all(cache : HotAnalysisCache) -> Unit {
  cache.cfg = None
  cache.orders = None
  cache.dom = None
  cache.postdom = None
  cache.loop_info = None
  cache.use_def = None
  cache.liveness = None
  cache.effects = None
  cache.ssa = None
}

///|
pub fn cache_get_or_build_cfg(
  cache : HotAnalysisCache,
  func : HotFunc,
) -> HotCfg {
  let revision = hot_revision_current(func)
  if cache_entry_is_current(cache.cfg, revision) {
    return cache_entry_value(cache.cfg)
  }
  let value = cfg_build(func)
  cache.cfg = Some({ built_at_revision: revision, value })
  value
}

///|
pub fn cache_get_or_build_orders(
  cache : HotAnalysisCache,
  func : HotFunc,
) -> HotCfgOrders {
  let revision = hot_revision_current(func)
  if cache_entry_is_current(cache.orders, revision) {
    return cache_entry_value(cache.orders)
  }
  let cfg = cache_get_or_build_cfg(cache, func)
  let value = {
    preorder: cfg_preorder(cfg),
    postorder: cfg_postorder(cfg),
    reverse_postorder: cfg_reverse_postorder(cfg),
    reverse_postorder_with_exceptions: cfg_reverse_postorder_with_exceptions(
      cfg,
    ),
    reverse_exit_postorder: cfg_reverse_postorder_from_exit(cfg),
    reverse_exit_postorder_with_exceptions: cfg_reverse_postorder_from_exit_with_exceptions(
      cfg,
    ),
    worklist_seed: cfg_block_worklist_seed(cfg),
  }
  cache.orders = Some({ built_at_revision: revision, value })
  value
}

///|
pub fn cache_get_or_build_dom(
  cache : HotAnalysisCache,
  func : HotFunc,
) -> HotDominators {
  let revision = hot_revision_current(func)
  if cache_entry_is_current(cache.dom, revision) {
    return cache_entry_value(cache.dom)
  }
  let value = dom_build(cache_get_or_build_cfg(cache, func))
  cache.dom = Some({ built_at_revision: revision, value })
  value
}

///|
pub fn cache_get_or_build_postdom(
  cache : HotAnalysisCache,
  func : HotFunc,
) -> HotPostDominators {
  let revision = hot_revision_current(func)
  if cache_entry_is_current(cache.postdom, revision) {
    return cache_entry_value(cache.postdom)
  }
  let value = postdom_build(cache_get_or_build_cfg(cache, func))
  cache.postdom = Some({ built_at_revision: revision, value })
  value
}

///|
pub fn cache_get_or_build_loop_info(
  cache : HotAnalysisCache,
  func : HotFunc,
) -> HotLoopInfo {
  let revision = hot_revision_current(func)
  if cache_entry_is_current(cache.loop_info, revision) {
    return cache_entry_value(cache.loop_info)
  }
  let cfg = cache_get_or_build_cfg(cache, func)
  let dom = cache_get_or_build_dom(cache, func)
  let value = loop_info_build(cfg, dom)
  cache.loop_info = Some({ built_at_revision: revision, value })
  value
}

///|
pub fn cache_get_or_build_use_def(
  cache : HotAnalysisCache,
  func : HotFunc,
) -> HotUseDef {
  let revision = hot_revision_current(func)
  if cache_entry_is_current(cache.use_def, revision) {
    return cache_entry_value(cache.use_def)
  }
  let value = use_def_build(func, cfg=Some(cache_get_or_build_cfg(cache, func)))
  cache.use_def = Some({ built_at_revision: revision, value })
  value
}

///|
pub fn cache_get_or_build_liveness(
  cache : HotAnalysisCache,
  func : HotFunc,
) -> HotLiveness {
  let revision = hot_revision_current(func)
  if cache_entry_is_current(cache.liveness, revision) {
    return cache_entry_value(cache.liveness)
  }
  let cfg = cache_get_or_build_cfg(cache, func)
  let value = liveness_build(cfg, cache_get_or_build_use_def(cache, func))
  cache.liveness = Some({ built_at_revision: revision, value })
  value
}

///|
pub fn cache_get_or_build_effects(
  cache : HotAnalysisCache,
  func : HotFunc,
) -> HotEffectsSummary {
  let revision = hot_revision_current(func)
  if cache_entry_is_current(cache.effects, revision) {
    return cache_entry_value(cache.effects)
  }
  let value = cache_effects_build(func, cache_get_or_build_cfg(cache, func))
  cache.effects = Some({ built_at_revision: revision, value })
  value
}

///|
pub fn cache_get_or_build_ssa(
  cache : HotAnalysisCache,
  func : HotFunc,
) -> HotLocalSsa {
  let revision = hot_revision_current(func)
  if cache_entry_is_current(cache.ssa, revision) {
    return cache_entry_value(cache.ssa)
  }
  let cfg = cache_get_or_build_cfg(cache, func)
  let dom = cache_get_or_build_dom(cache, func)
  let use_def = cache_get_or_build_use_def(cache, func)
  let liveness = cache_get_or_build_liveness(cache, func)
  let value = ssa_build_local(func, cfg, dom, liveness, use_def)
  cache.ssa = Some({ built_at_revision: revision, value })
  value
}
