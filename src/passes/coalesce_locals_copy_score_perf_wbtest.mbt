///|
fn cl_cfg_copy_score_perf_fixture(
  count : Int,
) -> (
  Array[Int],
  Array[@lib.ValType],
  CLCfgSparseInterferences,
  CLCfgSparseWeights,
) {
  let order : Array[Int] = []
  for idx in 0..<count {
    order.push(idx)
  }
  let types = Array::make(count, @lib.ValType::i32())
  let interferences = CLCfgSparseInterferences::new(count)
  let weights = CLCfgSparseWeights::new(count)
  for lhs = 0; lhs < count; lhs = lhs + 1 {
    for rhs = lhs + 1; rhs < count; rhs = rhs + 1 {
      cl_cfg_sparse_weight_add(weights, lhs, rhs)
    }
  }
  (order, types, interferences, weights)
}

///|
fn cl_cfg_copy_score_perf_bench(it : @bench.T, count : Int) -> Unit {
  let (order, types, interferences, weights) = cl_cfg_copy_score_perf_fixture(
    count,
  )
  let preflight = cl_cfg_sparse_color_with_order(
    order, types, 0, interferences, weights,
  )
  if preflight.slot_types.length() != 1 ||
    preflight.removed_copies != count * (count - 1) / 2 {
    abort("Coalesce dense-copy fixture did not merge its locals")
  }
  it.bench(fn() {
    it.keep(
      cl_cfg_sparse_color_with_order(order, types, 0, interferences, weights),
    )
  })
}

///|
test "bench Coalesce dense copy score locals=64" (it : @bench.T) {
  cl_cfg_copy_score_perf_bench(it, 64)
}

///|
test "bench Coalesce dense copy score locals=128" (it : @bench.T) {
  cl_cfg_copy_score_perf_bench(it, 128)
}

///|
test "Coalesce indexed copy weights keep preferred slot" {
  let types = Array::make(3, @lib.ValType::i32())
  let interferences = CLCfgSparseInterferences::new(3)
  cl_cfg_sparse_add_interference(interferences, 0, 1)
  let weights = CLCfgSparseWeights::new(3)
  cl_cfg_sparse_weight_add(weights, 2, 0)
  cl_cfg_sparse_weight_add(weights, 2, 1)
  cl_cfg_sparse_weight_add(weights, 2, 1)
  let result = cl_cfg_sparse_color_with_order(
    [0, 1, 2],
    types,
    0,
    interferences,
    weights,
  )
  @debug.assert_eq(result.old_to_new, [0, 1, 1])
  @debug.assert_eq(result.removed_copies, 2)
}
