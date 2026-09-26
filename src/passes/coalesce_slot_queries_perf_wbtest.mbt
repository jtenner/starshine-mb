///|
fn coalesce_slot_queries_bench(
  it : @bench.T,
  count : Int,
  dense : Bool,
  indexed : Bool,
) -> Unit {
  let types = Array::make(count, @lib.ValType::i32())
  let order = Array::makei(count, fn(i) { i })
  let interferences = CLCfgSparseInterferences::new(count)
  let weights = CLCfgSparseWeights::new(count)
  for lhs in 0..<count {
    if dense {
      for rhs in 0..<lhs {
        cl_cfg_sparse_add_interference(interferences, lhs, rhs)
      }
    } else if lhs > 1 {
      cl_cfg_sparse_weight_add(weights, lhs, lhs - 1)
    }
  }
  let actual = cl_cfg_sparse_color_with_order(
    order, types, 0, interferences, weights,
  )
  let expected = cl_cfg_slot_reference_color(
    order, types, 0, interferences, weights,
  )
  if actual.old_to_new != expected.old_to_new ||
    actual.removed_copies != expected.removed_copies {
    abort("coloring changed")
  }
  it.bench(fn() {
    it.keep(
      if indexed {
        cl_cfg_sparse_color_with_order(order, types, 0, interferences, weights)
      } else {
        cl_cfg_slot_reference_color(order, types, 0, interferences, weights)
      },
    )
  })
}

///|
test "bench Coalesce sparse slots reference=512" (it : @bench.T) {
  coalesce_slot_queries_bench(it, 512, false, false)
}

///|
test "bench Coalesce sparse slots indexed=512" (it : @bench.T) {
  coalesce_slot_queries_bench(it, 512, false, true)
}

///|
test "bench Coalesce sparse slots reference=2048" (it : @bench.T) {
  coalesce_slot_queries_bench(it, 2048, false, false)
}

///|
test "bench Coalesce sparse slots indexed=2048" (it : @bench.T) {
  coalesce_slot_queries_bench(it, 2048, false, true)
}

///|
test "bench Coalesce dense slots reference=128" (it : @bench.T) {
  coalesce_slot_queries_bench(it, 128, true, false)
}

///|
test "bench Coalesce dense slots indexed=128" (it : @bench.T) {
  coalesce_slot_queries_bench(it, 128, true, true)
}
