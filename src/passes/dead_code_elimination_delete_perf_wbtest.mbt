///|
fn dce_delete_perf_fixture(
  live_count : Int,
  detached_count : Int,
) -> (@ir.HotFunc, Array[Int]) {
  let func = @ir.HotFunc::new()
  for _ in 0..<live_count {
    @ir.hot_append_root(func, @ir.hot_build_nop(func))
  }
  let detached : Array[Int] = []
  for idx in 0..<detached_count {
    detached.push(@ir.hot_build_const_i32(func, @lib.I32(idx)))
  }
  (func, detached)
}

///|
fn dce_delete_perf_ctx() -> HotPassContext {
  HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
}

///|
fn dce_delete_perf_bench(it : @bench.T, live_count : Int) -> Unit {
  let (preflight, detached) = dce_delete_perf_fixture(live_count, 16)
  dead_code_elimination_delete_unused_nodes(
    dce_delete_perf_ctx(),
    preflight,
    DeadCodeEliminationNodeUseCache::new(preflight),
    detached,
  )
  for id in detached {
    if @ir.hot_node_is_live(preflight, id) {
      abort("DCE deletion benchmark left a detached candidate live")
    }
  }
  it.bench(fn() {
    let (func, candidates) = dce_delete_perf_fixture(live_count, 16)
    dead_code_elimination_delete_unused_nodes(
      dce_delete_perf_ctx(),
      func,
      DeadCodeEliminationNodeUseCache::new(func),
      candidates,
    )
    it.keep(func)
  })
}

///|
test "DCE small deletion keeps live references" {
  let (func, detached) = dce_delete_perf_fixture(8, 2)
  @ir.hot_append_root(func, detached[1])
  dead_code_elimination_delete_unused_nodes(
    dce_delete_perf_ctx(),
    func,
    DeadCodeEliminationNodeUseCache::new(func),
    detached,
  )
  assert_false(@ir.hot_node_is_live(func, detached[0]))
  assert_true(@ir.hot_node_is_live(func, detached[1]))
}

///|
test "DCE small deletion keeps references from other detached nodes" {
  let (func, detached) = dce_delete_perf_fixture(8, 2)
  ignore(@ir.hot_build_drop(func, detached[1]))
  dead_code_elimination_delete_unused_nodes(
    dce_delete_perf_ctx(),
    func,
    DeadCodeEliminationNodeUseCache::new(func),
    detached,
  )
  assert_false(@ir.hot_node_is_live(func, detached[0]))
  assert_true(@ir.hot_node_is_live(func, detached[1]))
}

///|
test "DCE small deletion removes a detached dependency after its user" {
  let (func, detached) = dce_delete_perf_fixture(8, 1)
  let user = @ir.hot_build_drop(func, detached[0])
  dead_code_elimination_delete_unused_nodes(
    dce_delete_perf_ctx(),
    func,
    DeadCodeEliminationNodeUseCache::new(func),
    [detached[0], user],
  )
  assert_false(@ir.hot_node_is_live(func, detached[0]))
  assert_false(@ir.hot_node_is_live(func, user))
}

///|
test "bench DCE small deletion live=512" (it : @bench.T) {
  dce_delete_perf_bench(it, 512)
}

///|
test "bench DCE small deletion live=1024" (it : @bench.T) {
  dce_delete_perf_bench(it, 1024)
}
