///|
fn hso_swapped_ref_order_perf_bench(it : @bench.T, root_count : Int) -> Unit {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let swapped_roots : Array[Int] = []
  for _ in 0..<root_count {
    swapped_roots.push(
      @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 0)),
    )
  }
  let ref_id = @ir.hot_build_local_get(func, 0)
  let node_masks : Array[UInt] = []
  for node = 0; node < @ir.hot_node_count(func); node = node + 1 {
    node_masks.push(@ir.effects_for_node(func, node))
  }
  let cache = hso_new_predicate_cache()
  if !hso_swapped_readonly_roots_respect_ref_order(
      cache, func, node_masks, swapped_roots, ref_id,
    ) {
    abort("HeapStore swapped-root fixture unexpectedly rejects earlier roots")
  }
  it.bench(fn() {
    it.keep(
      hso_swapped_readonly_roots_respect_ref_order(
        cache, func, node_masks, swapped_roots, ref_id,
      ),
    )
  })
}

///|
test "HeapStore swapped ref order still rejects a later same-local root" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let ref_id = @ir.hot_build_local_get(func, 0)
  let root_id = @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 0))
  let node_masks : Array[UInt] = []
  for node = 0; node < @ir.hot_node_count(func); node = node + 1 {
    node_masks.push(@ir.effects_for_node(func, node))
  }
  assert_false(
    hso_swapped_readonly_roots_respect_ref_order(
      hso_new_predicate_cache(),
      func,
      node_masks,
      [root_id],
      ref_id,
    ),
  )
}

///|
test "bench HeapStore swapped ref order roots=64" (it : @bench.T) {
  hso_swapped_ref_order_perf_bench(it, 64)
}

///|
test "bench HeapStore swapped ref order roots=128" (it : @bench.T) {
  hso_swapped_ref_order_perf_bench(it, 128)
}
