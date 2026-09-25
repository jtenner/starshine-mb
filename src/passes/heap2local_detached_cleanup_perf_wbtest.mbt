///|
fn h2l_detached_cleanup_perf_bench(it : @bench.T, node_count : Int) -> Unit {
  it.bench(fn() {
    let func = @ir.HotFunc::new()
    let detached : Array[Int] = []
    for idx in 0..<node_count {
      detached.push(@ir.hot_build_const_i32(func, @lib.I32(idx)))
    }
    h2l_delete_detached_live_nodes(func, detached)
    it.keep(func)
  })
}

///|
test "Heap2Local detached cleanup tolerates duplicate and dead node ids" {
  let func = @ir.HotFunc::new()
  let first = @ir.hot_build_const_i32(func, @lib.I32(1))
  let dead = @ir.hot_build_const_i32(func, @lib.I32(2))
  let untouched = @ir.hot_build_const_i32(func, @lib.I32(3))
  @ir.hot_delete_node(func, dead)
  h2l_delete_detached_live_nodes(func, [first, first, dead])
  assert_false(@ir.hot_node_is_live(func, first))
  assert_false(@ir.hot_node_is_live(func, dead))
  assert_true(@ir.hot_node_is_live(func, untouched))
}

///|
test "bench Heap2Local detached cleanup nodes=512" (it : @bench.T) {
  h2l_detached_cleanup_perf_bench(it, 512)
}

///|
test "bench Heap2Local detached cleanup nodes=1024" (it : @bench.T) {
  h2l_detached_cleanup_perf_bench(it, 1024)
}
