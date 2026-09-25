///|
fn dce_delete_perf_fixture(
  live_count : Int,
  detached_count : Int,
  nonleaf? : Bool = false,
) -> (@ir.HotFunc, Array[Int]) {
  let func = @ir.HotFunc::new()
  for _ in 0..<live_count {
    if nonleaf {
      @ir.hot_append_root(
        func,
        @ir.hot_build_drop(func, @ir.hot_build_const_i32(func, @lib.I32(0))),
      )
    } else {
      @ir.hot_append_root(func, @ir.hot_build_nop(func))
    }
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
fn dce_delete_perf_bench(
  it : @bench.T,
  live_count : Int,
  nonleaf? : Bool = false,
) -> Unit {
  let (preflight, detached) = dce_delete_perf_fixture(live_count, 16, nonleaf~)
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
    let (func, candidates) = dce_delete_perf_fixture(live_count, 16, nonleaf~)
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
test "DCE small deletion keeps candidate referenced by live nonleaf root" {
  let (func, detached) = dce_delete_perf_fixture(8, 2)
  @ir.hot_append_root(func, @ir.hot_build_drop(func, detached[1]))
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
test "DCE small deletion handles sparse candidate IDs and a retained middle reference" {
  let (func, _) = dce_delete_perf_fixture(8, 0)
  let first = @ir.hot_build_const_i32(func, @lib.I32(1))
  for _ in 0..<64 {
    ignore(@ir.hot_build_nop(func))
  }
  let middle = @ir.hot_build_const_i32(func, @lib.I32(2))
  @ir.hot_append_root(func, @ir.hot_build_drop(func, middle))
  for _ in 0..<64 {
    ignore(@ir.hot_build_nop(func))
  }
  let last = @ir.hot_build_const_i32(func, @lib.I32(3))
  dead_code_elimination_delete_unused_nodes(
    dce_delete_perf_ctx(),
    func,
    DeadCodeEliminationNodeUseCache::new(func),
    [last, middle, first, last],
  )
  assert_false(@ir.hot_node_is_live(func, first))
  assert_true(@ir.hot_node_is_live(func, middle))
  assert_false(@ir.hot_node_is_live(func, last))
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

///|
test "bench DCE small deletion nonleaf live=512" (it : @bench.T) {
  dce_delete_perf_bench(it, 512, nonleaf=true)
}

///|
test "bench DCE small deletion nonleaf live=1024" (it : @bench.T) {
  dce_delete_perf_bench(it, 1024, nonleaf=true)
}

///|
fn dce_label_owned_delete_perf_bench(it : @bench.T, live_count : Int) -> Unit {
  it.bench(fn() {
    let (func, _) = dce_delete_perf_fixture(live_count, 0)
    let ctx = dce_delete_perf_ctx()
    let cache = DeadCodeEliminationNodeUseCache::new(func)
    for _ in 0..<16 {
      let block = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
      dead_code_elimination_delete_unused_nodes(ctx, func, cache, [block])
      if !@ir.hot_node_is_live(func, block) {
        abort("DCE deleted a label-owning detached block")
      }
    }
    it.keep(func)
  })
}

///|
test "DCE label-owning detached block protects mixed candidate batch" {
  let (func, _) = dce_delete_perf_fixture(8, 0)
  let block = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let constant = @ir.hot_build_const_i32(func, @lib.I32(7))
  dead_code_elimination_delete_unused_nodes(
    dce_delete_perf_ctx(),
    func,
    DeadCodeEliminationNodeUseCache::new(func),
    [block, constant],
  )
  assert_true(@ir.hot_node_is_live(func, block))
  assert_false(@ir.hot_node_is_live(func, constant))
}

///|
test "DCE label-owning detached block still protects referenced candidate" {
  let (func, _) = dce_delete_perf_fixture(8, 0)
  let constant = @ir.hot_build_const_i32(func, @lib.I32(7))
  let block = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    @ir.hot_build_drop(func, constant),
  ])
  dead_code_elimination_delete_unused_nodes(
    dce_delete_perf_ctx(),
    func,
    DeadCodeEliminationNodeUseCache::new(func),
    [block, constant],
  )
  assert_true(@ir.hot_node_is_live(func, block))
  assert_true(@ir.hot_node_is_live(func, constant))
}

///|
test "bench DCE label-owned deletion live=512" (it : @bench.T) {
  dce_label_owned_delete_perf_bench(it, 512)
}

///|
test "bench DCE label-owned deletion live=1024" (it : @bench.T) {
  dce_label_owned_delete_perf_bench(it, 1024)
}
