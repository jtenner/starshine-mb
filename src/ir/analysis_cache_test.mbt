///|
fn analysis_cache_ssa_fixture() -> HotFunc {
  hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        ],
        Some([@lib.Instruction::nop()]),
      ),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::drop(),
    ]),
    HotLocals::new(params=[@lib.ValType::i32()], locals=[@lib.ValType::i32()]),
  )
}

///|
test "analysis cache reuses overlays while the hot revision is unchanged" {
  let func = analysis_cache_ssa_fixture()
  let cache = HotAnalysisCache::new()

  let cfg0 = cache_get_or_build_cfg(cache, func)
  let cfg1 = cache_get_or_build_cfg(cache, func)
  let dom0 = cache_get_or_build_dom(cache, func)
  let dom1 = cache_get_or_build_dom(cache, func)
  let effects0 = cache_get_or_build_effects(cache, func)
  let effects1 = cache_get_or_build_effects(cache, func)

  assert_eq(cfg0, cfg1)
  assert_eq(dom0, dom1)
  assert_eq(effects0, effects1)
  assert_eq(cache.cfg.unwrap().built_at_revision, hot_revision_current(func))
  assert_eq(
    cache.effects.unwrap().built_at_revision,
    hot_revision_current(func),
  )
}

///|
test "analysis cache rebuilds cfg after root mutation bumps revision" {
  let func = HotFunc::new()
  hot_root_append(func, hot_build_nop(func))
  let cache = HotAnalysisCache::new()
  let cfg0 = cache_get_or_build_cfg(cache, func)
  let rev0 = hot_revision_current(func)
  let slot0 = cfg_block_for_region_root(cfg0, HotRegionRef::root(), 0)
  let slot1_before = cfg_block_for_region_root(cfg0, HotRegionRef::root(), 1)

  hot_root_append(func, hot_build_unreachable(func))
  let cfg1 = cache_get_or_build_cfg(cache, func)
  let slot1_after = cfg_block_for_region_root(cfg1, HotRegionRef::root(), 1)

  assert_true(hot_revision_current(func) > rev0)
  assert_true(cfg1 != cfg0)
  assert_eq(cfg1, cache_get_or_build_cfg(cache, func))
  assert_eq(slot0, cfg_block_for_region_root(cfg1, HotRegionRef::root(), 0))
  assert_eq(slot1_before, None)
  assert_true(slot1_after is Some(_))
  assert_eq(cache.cfg.unwrap().built_at_revision, hot_revision_current(func))
}

///|
test "analysis cache rebuilds stale ssa through its dependencies" {
  let func = analysis_cache_ssa_fixture()
  let cache = HotAnalysisCache::new()
  let ssa0 = cache_get_or_build_ssa(cache, func)
  let rev0 = hot_revision_current(func)

  hot_root_append(func, hot_build_nop(func))
  let ssa1 = cache_get_or_build_ssa(cache, func)

  assert_true(hot_revision_current(func) > rev0)
  assert_true(ssa1.revision > ssa0.revision)
  assert_eq(cache.cfg.unwrap().built_at_revision, hot_revision_current(func))
  assert_eq(
    cache.liveness.unwrap().built_at_revision,
    hot_revision_current(func),
  )
  assert_eq(cache.ssa.unwrap().built_at_revision, hot_revision_current(func))
}

///|
test "analysis cache invalidate_all drops cached overlays" {
  let func = analysis_cache_ssa_fixture()
  let cache = HotAnalysisCache::new()

  ignore(cache_get_or_build_cfg(cache, func))
  ignore(cache_get_or_build_dom(cache, func))
  ignore(cache_get_or_build_effects(cache, func))

  assert_true(cache.cfg is Some(_))
  assert_true(cache.dom is Some(_))
  assert_true(cache.effects is Some(_))

  cache_invalidate_all(cache)

  assert_eq(cache.cfg, None)
  assert_eq(cache.orders, None)
  assert_eq(cache.dom, None)
  assert_eq(cache.postdom, None)
  assert_eq(cache.loop_info, None)
  assert_eq(cache.use_def, None)
  assert_eq(cache.liveness, None)
  assert_eq(cache.effects, None)
  assert_eq(cache.ssa, None)
}
