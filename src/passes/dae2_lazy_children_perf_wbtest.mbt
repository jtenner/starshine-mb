///|
fn dae2_lazy_children_bench(
  it : @bench.T,
  repetitions : Int,
  lazy : Bool,
) -> Unit {
  let (graph, infos, func, root, state) = dae2_lazy_children_fixture(true)
  let memo = Array::make(@ir.hot_node_count(func), -1)
  let arities = Array::makei(memo.length(), fn(node) {
    @ir.hot_node_result_arity(func, node)
  })
  let original = @ir.hot_child_span(func, root)
  let revision = @ir.hot_revision_current(func)
  let reference = fn() {
    @ir.hot_child_span(func, root).map(fn(child) {
      dae2_rewrite_node(graph, infos, 0, func, child, memo, arities, state, [])
    })
  }
  if reference() != original ||
    dae2_rewrite_children(graph, infos, 0, func, root, memo, arities, state, [])
    is Some(_) {
    abort("unchanged child rewrites changed the retained expression")
  }
  it.bench(fn() {
    for _ in 0..<repetitions {
      if lazy {
        it.keep(
          dae2_rewrite_children(
            graph,
            infos,
            0,
            func,
            root,
            memo,
            arities,
            state,
            [],
          ),
        )
      } else {
        it.keep(reference())
      }
    }
  })
  if @ir.hot_revision_current(func) != revision ||
    @ir.hot_child_span(func, root) != original {
    abort("child rewrite benchmark mutated its parent")
  }
  @ir.hot_verify_core(func).unwrap()
}

///|
test "bench DAE2 owned child snapshots repetitions=1" (it : @bench.T) {
  dae2_lazy_children_bench(it, 1, false)
}

///|
test "bench DAE2 lazy child snapshots repetitions=1" (it : @bench.T) {
  dae2_lazy_children_bench(it, 1, true)
}

///|
test "bench DAE2 owned child snapshots repetitions=4096" (it : @bench.T) {
  dae2_lazy_children_bench(it, 4096, false)
}

///|
test "bench DAE2 lazy child snapshots repetitions=4096" (it : @bench.T) {
  dae2_lazy_children_bench(it, 4096, true)
}
