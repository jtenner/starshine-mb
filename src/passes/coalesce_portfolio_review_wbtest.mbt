///|
fn cl_pick_coloring_seven_order_reference(
  types : Array[@lib.ValType],
  param_count : Int32,
  interferences : CLBitMatrix,
  weights : CLCopyWeights,
  preferred : Array[Bool],
  retained_copy_destinations : Array[Bool],
  structured_scalar_preferred : Array[Bool],
) -> CLColoring {
  let natural : Array[Int32] = []
  for idx = param_count; idx < types.length(); idx = idx + 1 {
    natural.push(idx)
  }
  let reverse : Array[Int32] = []
  let mut idx = types.length() - 1
  while idx >= param_count {
    reverse.push(idx)
    idx -= 1
  }
  let orders = [
    natural,
    reverse,
    cl_copy_weighted_order(weights, param_count, false),
    cl_copy_weighted_order(weights, param_count, true),
    cl_preferred_compaction_order(preferred, types, param_count),
    cl_flagged_compaction_order(retained_copy_destinations, types, param_count),
    cl_flagged_compaction_order(structured_scalar_preferred, types, param_count),
  ]
  let mut best = cl_color_with_order(
    orders[0],
    types,
    param_count,
    interferences,
    weights,
  )
  for order_idx = 1; order_idx < orders.length(); order_idx = order_idx + 1 {
    let candidate = cl_color_with_order(
      orders[order_idx],
      types,
      param_count,
      interferences,
      weights,
    )
    if cl_coloring_is_better(
        candidate, best, preferred, retained_copy_destinations, structured_scalar_preferred,
        types, param_count,
      ) {
      best = candidate
    }
  }
  best
}

///|
fn cl_portfolio_review_bench(
  it : @bench.T,
  width : Int32,
  weighted : Bool,
  reference : Bool,
  verify_selected~ : Bool = true,
) -> Unit {
  let types = Array::make(width, @lib.ValType::i32())
  let conflicts = CLBitMatrix::new(width)
  conflicts.bits.fill(true)
  let weights = CLCopyWeights::new(width)
  let preferred = Array::makei(width, fn(i) { weighted && i % 3 == 0 })
  let retained = Array::makei(width, fn(i) { weighted && i % 5 == 0 })
  let structured = Array::makei(width, fn(i) { weighted && i % 7 == 0 })
  if weighted {
    for i in 1..<width {
      cl_copy_weight_add(weights, i - 1, i, i % 7 + 1)
    }
  }
  if verify_selected {
    let before = cl_pick_coloring_seven_order_reference(
      types, 0, conflicts, weights, preferred, retained, structured,
    )
    let after = cl_pick_coloring(
      types, 0, conflicts, weights, preferred, retained, structured,
    )
    if before.old_to_new != after.old_to_new ||
      before.slot_types != after.slot_types ||
      before.removed_copies != after.removed_copies {
      abort("portfolio deduplication changed the selected coloring")
    }
  }
  it.bench(fn() {
    it.keep(
      if reference {
        cl_pick_coloring_seven_order_reference(
          types, 0, conflicts, weights, preferred, retained, structured,
        )
      } else {
        cl_pick_coloring(
          types, 0, conflicts, weights, preferred, retained, structured,
        )
      },
    )
  })
}

///|
test "bench coalesce portfolio unweighted seven 256" (it : @bench.T) {
  cl_portfolio_review_bench(it, 256, false, true)
}

///|
test "bench coalesce portfolio unweighted distinct 256" (it : @bench.T) {
  cl_portfolio_review_bench(it, 256, false, false)
}

///|
test "bench coalesce portfolio unweighted seven 512" (it : @bench.T) {
  cl_portfolio_review_bench(it, 512, false, true)
}

///|
test "bench coalesce portfolio unweighted distinct 512" (it : @bench.T) {
  cl_portfolio_review_bench(it, 512, false, false)
}

///|
test "bench coalesce portfolio unweighted seven 1024" (it : @bench.T) {
  cl_portfolio_review_bench(it, 1024, false, true)
}

///|
test "bench coalesce portfolio unweighted distinct 1024" (it : @bench.T) {
  cl_portfolio_review_bench(it, 1024, false, false)
}

///|
test "bench coalesce portfolio weighted seven 256" (it : @bench.T) {
  cl_portfolio_review_bench(it, 256, true, true)
}

///|
test "bench coalesce portfolio weighted distinct 256" (it : @bench.T) {
  cl_portfolio_review_bench(it, 256, true, false)
}

///|
test "bench coalesce portfolio weighted seven 512" (it : @bench.T) {
  cl_portfolio_review_bench(it, 512, true, true)
}

///|
test "bench coalesce portfolio weighted distinct 512" (it : @bench.T) {
  cl_portfolio_review_bench(it, 512, true, false)
}

///|
test "bench coalesce portfolio weighted seven 1024" (it : @bench.T) {
  cl_portfolio_review_bench(it, 1024, true, true)
}

///|
test "bench coalesce portfolio weighted distinct 1024" (it : @bench.T) {
  cl_portfolio_review_bench(it, 1024, true, false)
}
