///|
fn cl_dense_score_bench(
  it : @bench.T,
  count : Int,
  dense : Bool,
  reference : Bool,
) -> Unit {
  let params = count / 4
  let order = Array::makei(count - params, fn(index) { index + params })
  let types = Array::make(count, @lib.ValType::i32())
  let conflicts = CLBitMatrix::new(count)
  let weights = CLCopyWeights::new(count)
  if dense {
    for lhs in 0..<count {
      for rhs in (lhs + 1)..<count {
        cl_bit_matrix_set(conflicts, lhs, rhs, (lhs + rhs) % 3 == 0)
      }
      cl_copy_weight_add(weights, lhs, lhs / 2, 2)
    }
  }
  let expected = cl_color_with_order_reference(
    order, types, params, conflicts, weights,
  )
  let actual = cl_color_with_order(order, types, params, conflicts, weights)
  if actual.old_to_new != expected.old_to_new ||
    actual.slot_types != expected.slot_types ||
    actual.removed_copies != expected.removed_copies {
    abort("dense coloring benchmark changed coloring or copy score")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        cl_color_with_order_reference(order, types, params, conflicts, weights)
      } else {
        cl_color_with_order(order, types, params, conflicts, weights)
      },
    )
  })
}

///|
test "bench dense coloring locals=16 unweighted reference" (it : @bench.T) {
  cl_dense_score_bench(it, 16, false, true)
}

///|
test "bench dense coloring locals=16 unweighted bounded" (it : @bench.T) {
  cl_dense_score_bench(it, 16, false, false)
}

///|
test "bench dense coloring locals=16 weighted reference" (it : @bench.T) {
  cl_dense_score_bench(it, 16, true, true)
}

///|
test "bench dense coloring locals=16 weighted bounded" (it : @bench.T) {
  cl_dense_score_bench(it, 16, true, false)
}

///|
test "bench dense coloring locals=64 unweighted reference" (it : @bench.T) {
  cl_dense_score_bench(it, 64, false, true)
}

///|
test "bench dense coloring locals=64 unweighted bounded" (it : @bench.T) {
  cl_dense_score_bench(it, 64, false, false)
}

///|
test "bench dense coloring locals=64 weighted reference" (it : @bench.T) {
  cl_dense_score_bench(it, 64, true, true)
}

///|
test "bench dense coloring locals=64 weighted bounded" (it : @bench.T) {
  cl_dense_score_bench(it, 64, true, false)
}

///|
test "bench dense coloring locals=256 unweighted reference" (it : @bench.T) {
  cl_dense_score_bench(it, 256, false, true)
}

///|
test "bench dense coloring locals=256 unweighted bounded" (it : @bench.T) {
  cl_dense_score_bench(it, 256, false, false)
}

///|
test "bench dense coloring locals=256 weighted reference" (it : @bench.T) {
  cl_dense_score_bench(it, 256, true, true)
}

///|
test "bench dense coloring locals=256 weighted bounded" (it : @bench.T) {
  cl_dense_score_bench(it, 256, true, false)
}
