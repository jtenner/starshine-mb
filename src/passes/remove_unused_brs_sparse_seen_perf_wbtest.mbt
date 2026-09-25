///|
fn remove_unused_brs_sparse_seen_perf_bench(
  it : @bench.T,
  unrelated_nodes : Int,
) -> Unit {
  let func = @ir.HotFunc::new()
  for _ in 0..<unrelated_nodes {
    ignore(@ir.hot_build_nop(func))
  }
  let subtree = @ir.hot_build_nop(func)
  it.bench(fn() {
    let targets : Array[Int] = []
    remove_unused_brs_collect_simple_branches_to_label(
      func, subtree, 0, targets,
    )
    it.keep(targets)
  })
}

///|
test "RemoveUnusedBrs sparse seen visits each node once after promotion" {
  for arena in [32, 16385] {
    let seen = RemoveUnusedBrsSparseSeen::new(arena)
    for node in 0..<32 {
      assert_true(seen.mark_if_new(node))
    }
    for node in 0..<32 {
      assert_false(seen.mark_if_new(node))
    }
  }
}

///|
test "bench RemoveUnusedBrs sparse seen arena=64" (it : @bench.T) {
  remove_unused_brs_sparse_seen_perf_bench(it, 64)
}

///|
test "bench RemoveUnusedBrs sparse seen arena=1024" (it : @bench.T) {
  remove_unused_brs_sparse_seen_perf_bench(it, 1024)
}

///|
test "bench RemoveUnusedBrs sparse seen arena=4096" (it : @bench.T) {
  remove_unused_brs_sparse_seen_perf_bench(it, 4096)
}

///|
fn rub_subtree_perf_bench(it : @bench.T, dense : Bool) -> Unit {
  let func = @ir.HotFunc::new()
  let children : Array[Int] = []
  for _ in 0..<128 {
    children.push(@ir.hot_build_nop(func))
  }
  let subtree = @ir.hot_build_block(func, @lib.BlockType::void_(), children)
  it.bench(fn() {
    let targets : Array[Int] = []
    if dense {
      let seen = Array::make(@ir.hot_node_count(func), false)
      remove_unused_brs_collect_simple_branches_to_label_dense(
        func, subtree, 0, seen, targets,
      )
      it.keep(seen)
    } else {
      remove_unused_brs_collect_simple_branches_to_label(
        func, subtree, 0, targets,
      )
    }
    it.keep(targets)
  })
}

///|
test "bench RemoveUnusedBrs dense reference subtree=128" (it : @bench.T) {
  rub_subtree_perf_bench(it, true)
}

///|
test "bench RemoveUnusedBrs sparse subtree=128" (it : @bench.T) {
  rub_subtree_perf_bench(it, false)
}
