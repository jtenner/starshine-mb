///|
fn hot_root_splice_reference(
  func : HotFunc,
  idx : Int,
  remove_count : Int,
  new_roots : Array[NodeId],
) -> Array[NodeId] {
  hot_mutate_require_root_index(func, idx, allow_end=true)
  hot_mutate_require_remove_count(func.roots.length(), idx, remove_count)
  for root in new_roots {
    hot_mutate_require_live_node(func, root, "hot root slots")
  }
  let removed : Array[NodeId] = []
  for i = idx; i < idx + remove_count; i = i + 1 {
    removed.push(func.roots[i])
  }
  for _ in 0..<remove_count {
    ignore(hot_mutate_root_remove_no_bump(func, idx))
  }
  for insert_idx = 0
      insert_idx < new_roots.length()
      insert_idx = insert_idx + 1 {
    hot_mutate_root_insert_no_bump(
      func,
      idx + insert_idx,
      new_roots[insert_idx],
    )
  }
  hot_revision_bump(func)
  removed
}

///|
fn hot_root_splice_bulk_bench(
  it : @bench.T,
  count : Int,
  reference : Bool,
) -> Unit {
  let func = HotFunc::new()
  let roots = Array::makei(count, fn(_) { hot_build_nop(func) })
  for root in roots {
    hot_root_append(func, root)
  }
  let removed = hot_root_splice(func, 0, count, roots)
  if removed != roots || hot_root_span(func) != roots {
    abort("splice benchmark lost root order")
  }
  hot_verify_all_or_abort(func)
  it.bench(fn() {
    it.keep(
      if reference {
        hot_root_splice_reference(func, 0, count, roots)
      } else {
        hot_root_splice(func, 0, count, roots)
      },
    )
  })
}

///|
test "bench root bulk replacement roots=16 reference" (it : @bench.T) {
  hot_root_splice_bulk_bench(it, 16, true)
}

///|
test "bench root bulk replacement roots=16 bulk" (it : @bench.T) {
  hot_root_splice_bulk_bench(it, 16, false)
}

///|
test "bench root bulk replacement roots=256 reference" (it : @bench.T) {
  hot_root_splice_bulk_bench(it, 256, true)
}

///|
test "bench root bulk replacement roots=256 bulk" (it : @bench.T) {
  hot_root_splice_bulk_bench(it, 256, false)
}

///|
test "bench root bulk replacement roots=4096 reference" (it : @bench.T) {
  hot_root_splice_bulk_bench(it, 4096, true)
}

///|
test "bench root bulk replacement roots=4096 bulk" (it : @bench.T) {
  hot_root_splice_bulk_bench(it, 4096, false)
}
