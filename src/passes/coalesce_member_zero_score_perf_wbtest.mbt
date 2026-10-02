///|
fn cl_member_zero_score_bench(
  it : @bench.T,
  count : Int,
  weighted : Bool,
  reference : Bool,
) -> Unit raise {
  let params = if count <= 4 { 1 } else { 8 }
  let order = Array::makei(count - params, fn(i) { i + params })
  let types = Array::make(count, @lib.ValType::i32())
  let interferences = CLCfgSparseInterferences::new(count)
  let weights = CLCfgSparseWeights::new(count)
  if weighted {
    for idx in params..<count {
      cl_cfg_sparse_weight_add(weights, idx, params - 1)
      if idx % 3 == 0 {
        cl_cfg_sparse_add_interference(interferences, idx, params - 1)
      }
    }
  }
  let expected = cl_cfg_slot_reference_color(
    order, types, params, interferences, weights,
  )
  let actual = cl_cfg_sparse_color_with_order(
    order, types, params, interferences, weights,
  )
  assert_eq(actual.old_to_new, expected.old_to_new)
  assert_eq(actual.slot_types, expected.slot_types)
  assert_eq(actual.removed_copies, expected.removed_copies)
  it.bench(fn() {
    it.keep(
      if reference {
        cl_cfg_slot_reference_color(
          order, types, params, interferences, weights,
        )
      } else {
        cl_cfg_sparse_color_with_order(
          order, types, params, interferences, weights,
        )
      },
    )
  })
}

///|
test "bench CL member zero-score 4 weightless original" (it : @bench.T) {
  cl_member_zero_score_bench(it, 4, false, true)
}

///|
test "bench CL member zero-score 4 weightless bounded" (it : @bench.T) {
  cl_member_zero_score_bench(it, 4, false, false)
}

///|
test "bench CL member zero-score 32 weightless original" (it : @bench.T) {
  cl_member_zero_score_bench(it, 32, false, true)
}

///|
test "bench CL member zero-score 32 weightless bounded" (it : @bench.T) {
  cl_member_zero_score_bench(it, 32, false, false)
}

///|
test "bench CL member zero-score 63 weightless original" (it : @bench.T) {
  cl_member_zero_score_bench(it, 63, false, true)
}

///|
test "bench CL member zero-score 63 weightless bounded" (it : @bench.T) {
  cl_member_zero_score_bench(it, 63, false, false)
}

///|
test "bench CL member zero-score 63 weighted original" (it : @bench.T) {
  cl_member_zero_score_bench(it, 63, true, true)
}

///|
test "bench CL member zero-score 63 weighted bounded" (it : @bench.T) {
  cl_member_zero_score_bench(it, 63, true, false)
}
