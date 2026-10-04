///|
fn dae2_live_control_bench(it : @bench.T, depth : Int) -> Unit {
  let (graph, infos, func, root, state) = dae2_live_control_fixture(
    depth, false,
  )
  let memo = Array::make(@ir.hot_node_count(func), -1)
  let arities = Array::makei(memo.length(), fn(node) {
    @ir.hot_node_result_arity(func, node)
  })
  let saved = @ir.hot_lower_func_unverified(func)
  let revision = @ir.hot_revision_current(func)
  it.bench(fn() {
    memo.fill(-1)
    it.keep(
      dae2_rewrite_node(graph, infos, 0, func, root, memo, arities, state, []),
    )
  })
  if @ir.hot_revision_current(func) != revision ||
    @ir.hot_lower_func_unverified(func) != saved {
    abort("live control rewrite benchmark changed an observed body")
  }
  @ir.hot_verify_core(func).unwrap()
}

///|
test "bench DAE2 live controls depth1" (it : @bench.T) {
  dae2_live_control_bench(it, 1)
}

///|
test "bench DAE2 live controls depth8" (it : @bench.T) {
  dae2_live_control_bench(it, 8)
}

///|
test "bench DAE2 live controls depth32" (it : @bench.T) {
  dae2_live_control_bench(it, 32)
}
