///|
fn issue9_cache_warm_all(cache : HotAnalysisCache, func : HotFunc) -> Unit {
  ignore(cache_get_or_build_cfg(cache, func))
  ignore(cache_get_or_build_orders(cache, func))
  ignore(cache_get_or_build_dom(cache, func))
  ignore(cache_get_or_build_postdom(cache, func))
  ignore(cache_get_or_build_loop_info(cache, func))
  ignore(cache_get_or_build_use_def(cache, func))
  ignore(cache_get_or_build_liveness(cache, func))
  ignore(cache_get_or_build_effects(cache, func))
  ignore(cache_get_or_build_ssa(cache, func))
}

///|
fn issue9_assert_cache_matches_fresh(
  cache : HotAnalysisCache,
  func : HotFunc,
) -> Unit raise {
  // A new cache reconstructs every fact from the canonical HotFunc. It shares
  // the production builders, so this qualifies cache invalidation rather than
  // providing an independently implemented analysis oracle.
  let fresh = HotAnalysisCache::new()
  assert_eq(
    cache_get_or_build_cfg(cache, func),
    cache_get_or_build_cfg(fresh, func),
  )
  assert_eq(
    cache_get_or_build_orders(cache, func),
    cache_get_or_build_orders(fresh, func),
  )
  assert_eq(
    cache_get_or_build_dom(cache, func),
    cache_get_or_build_dom(fresh, func),
  )
  assert_eq(
    cache_get_or_build_postdom(cache, func),
    cache_get_or_build_postdom(fresh, func),
  )
  assert_eq(
    cache_get_or_build_loop_info(cache, func),
    cache_get_or_build_loop_info(fresh, func),
  )
  assert_eq(
    cache_get_or_build_use_def(cache, func),
    cache_get_or_build_use_def(fresh, func),
  )
  assert_eq(
    cache_get_or_build_liveness(cache, func),
    cache_get_or_build_liveness(fresh, func),
  )
  assert_eq(
    cache_get_or_build_effects(cache, func),
    cache_get_or_build_effects(fresh, func),
  )
  assert_eq(
    cache_get_or_build_ssa(cache, func),
    cache_get_or_build_ssa(fresh, func),
  )
}

///|
fn issue9_local_diamond_fixture() -> HotFunc {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let condition = hot_build_local_get(func, 0)
  let then_write = hot_build_local_set(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(3)),
  )
  let else_write = hot_build_local_set(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(5)),
  )
  hot_root_append(
    func,
    hot_build_if(
      func,
      @lib.BlockType::void_(),
      condition,
      [then_write],
      else_body=Some([else_write]),
    ),
  )
  hot_root_append(func, hot_build_drop(func, hot_build_local_get(func, 1)))
  func
}

///|
test "analysis cache facts match fresh reconstruction after node and effect mutation" {
  let func = HotFunc::new()
  let pure = hot_build_nop(func)
  let calling = hot_build_call(func, 0, [], [])
  hot_root_append(func, pure)
  let cache = HotAnalysisCache::new()
  issue9_cache_warm_all(cache, func)

  hot_replace_node(func, pure, hot_node_get(func, calling))

  issue9_assert_cache_matches_fresh(cache, func)
  assert_true(
    (
      cache_get_or_build_effects(cache, func).root_region_mask &
      EFFECT_MASK_CALL
    ) !=
    0U,
  )
}

///|
test "analysis cache facts match fresh reconstruction after root and child splices" {
  let func = HotFunc::new()
  let first = hot_build_nop(func)
  let inserted_child = hot_build_nop(func)
  let block = hot_build_block(func, @lib.BlockType::void_(), [first])
  let inserted_root = hot_build_nop(func)
  hot_root_append(func, block)
  let cache = HotAnalysisCache::new()
  issue9_cache_warm_all(cache, func)

  ignore(
    hot_region_splice(func, hot_region_body_ref(func, block), 1, 0, [
      inserted_child,
    ]),
  )
  issue9_assert_cache_matches_fresh(cache, func)

  ignore(hot_region_splice(func, HotRegionRef::root(), 1, 0, [inserted_root]))
  issue9_assert_cache_matches_fresh(cache, func)
}

///|
test "analysis cache facts match fresh reconstruction after legal branch retargeting" {
  let func = HotFunc::new()
  let outer = hot_build_block(func, @lib.BlockType::void_(), [])
  let inner = hot_build_block(func, @lib.BlockType::void_(), [])
  let branch = hot_build_br_if(
    func,
    hot_control_node_label(func, outer),
    hot_build_const_i32(func, @lib.I32(1)),
  )
  ignore(hot_replace_child_span(func, inner, [branch]))
  ignore(hot_replace_child_span(func, outer, [inner]))
  hot_root_append(func, outer)
  hot_verify_control(func).unwrap()
  let cache = HotAnalysisCache::new()
  issue9_cache_warm_all(cache, func)

  hot_branch_target_set(func, branch, hot_control_node_label(func, inner))

  hot_verify_control(func).unwrap()
  issue9_assert_cache_matches_fresh(cache, func)
}

///|
test "analysis cache facts match fresh reconstruction after local shape changes" {
  let func = issue9_local_diamond_fixture()
  let cache = HotAnalysisCache::new()
  issue9_cache_warm_all(cache, func)

  let local_id = hot_append_body_local(func, @lib.ValType::i64())
  issue9_assert_cache_matches_fresh(cache, func)

  assert_true(hot_set_body_local_type(func, local_id, @lib.ValType::f32()))
  issue9_assert_cache_matches_fresh(cache, func)
}

///|
test "analysis cache stays coherent after no-op and rejected mutations" {
  let func = issue9_local_diamond_fixture()
  let detached = hot_build_nop(func)
  let referenced = hot_build_const_i32(func, @lib.I32(7))
  let owner = hot_build_drop(func, referenced)
  hot_root_append(func, owner)
  let cache = HotAnalysisCache::new()
  issue9_cache_warm_all(cache, func)
  let revision = hot_revision_current(func)

  assert_eq(
    hot_region_splice(func, HotRegionRef::root(), hot_root_count(func), 0, []),
    [],
  )
  assert_eq(hot_revision_current(func), revision)
  issue9_assert_cache_matches_fresh(cache, func)

  let roots_before = hot_root_span(func)
  ignore(
    hot_region_splice(func, HotRegionRef::root(), hot_root_count(func), 0, [
      detached,
    ]),
  )
  issue9_assert_cache_matches_fresh(cache, func)
  ignore(
    hot_region_splice(func, HotRegionRef::root(), hot_root_count(func) - 1, 1, []),
  )
  assert_eq(hot_root_span(func), roots_before)
  assert_true(hot_revision_current(func) > revision)
  issue9_assert_cache_matches_fresh(cache, func)

  let rolled_back_revision = hot_revision_current(func)

  assert_false(
    hot_mutate_delete_detached_nodes_if_unreferenced(func, [
      detached, referenced,
    ]),
  )
  assert_eq(hot_revision_current(func), rolled_back_revision)
  assert_eq(hot_root_span(func), roots_before)
  assert_true(hot_node_is_live(func, detached))
  assert_true(hot_node_is_live(func, referenced))
  assert_true(hot_node_is_live(func, owner))
  issue9_assert_cache_matches_fresh(cache, func)
}

///|
test "analysis cache stale-domain control detects omitted local read invalidation" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  let read = hot_build_local_get(func, 0)
  hot_root_append(func, hot_build_drop(func, read))
  let cache = HotAnalysisCache::new()
  issue9_cache_warm_all(cache, func)
  let stale_use_def = cache_get_or_build_use_def(cache, func)
  let stale_liveness = cache_get_or_build_liveness(cache, func)
  let stale_ssa = cache_get_or_build_ssa(cache, func)
  let revision = hot_revision_current(func)

  // Test-only fault injection redirects the equal-typed read while omitting
  // the canonical hot_local_node_id_set revision bump.
  func.nodes[read] = { ..func.nodes[read], imm0: 1, }

  assert_eq(hot_revision_current(func), revision)
  let fresh = HotAnalysisCache::new()
  let stale_use_def_after = cache_get_or_build_use_def(cache, func)
  let stale_liveness_after = cache_get_or_build_liveness(cache, func)
  let stale_ssa_after = cache_get_or_build_ssa(cache, func)
  let fresh_use_def = cache_get_or_build_use_def(fresh, func)
  let fresh_liveness = cache_get_or_build_liveness(fresh, func)
  let fresh_ssa = cache_get_or_build_ssa(fresh, func)
  assert_eq(stale_use_def_after, stale_use_def)
  assert_eq(stale_liveness_after, stale_liveness)
  assert_eq(stale_ssa_after, stale_ssa)
  assert_true(stale_use_def_after != fresh_use_def)
  assert_true(stale_liveness_after != fresh_liveness)
  assert_true(stale_ssa_after != fresh_ssa)
}

///|
test "analysis cache stale-domain control detects omitted root invalidation" {
  let func = HotFunc::new()
  let pure = hot_build_nop(func)
  let calling = hot_build_call(func, 0, [], [])
  hot_root_append(func, pure)
  let cache = HotAnalysisCache::new()
  let stale_before = cache_get_or_build_effects(cache, func)
  let revision = hot_revision_current(func)

  // Test-only fault injection: bypass the canonical root mutator and therefore
  // omit the required revision bump. The warmed cache must now disagree with a
  // cache-independent reconstruction in the affected effects domain.
  func.roots[0] = calling

  assert_eq(hot_revision_current(func), revision)
  let stale_after = cache_get_or_build_effects(cache, func)
  let reconstructed = cache_get_or_build_effects(HotAnalysisCache::new(), func)
  assert_eq(stale_after, stale_before)
  assert_true(stale_after != reconstructed)
  assert_eq(stale_after.root_region_mask & EFFECT_MASK_CALL, 0U)
  assert_true((reconstructed.root_region_mask & EFFECT_MASK_CALL) != 0U)
}
