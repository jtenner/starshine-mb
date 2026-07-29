///|
test "reorder-globals ready heap preserves imports counts and original-order ties" {
  let counts = [1.0, 100.0, 5.0, 5.0]
  let heap : Array[Int] = []
  for candidate in [3, 1, 2, 0] {
    rg_ready_heap_push(heap, candidate, counts, 1)
  }
  @debug.assert_eq(rg_ready_heap_pop(heap, counts, 1), Some(0))
  @debug.assert_eq(rg_ready_heap_pop(heap, counts, 1), Some(1))
  @debug.assert_eq(rg_ready_heap_pop(heap, counts, 1), Some(2))
  @debug.assert_eq(rg_ready_heap_pop(heap, counts, 1), Some(3))
  @debug.assert_eq(rg_ready_heap_pop(heap, counts, 1), None)
}

///|
test "reorder-globals candidate families preserve source ordering and score dependencies" {
  let deps : Array[Array[Int]] = [[2], [], []]
  let true_counts = [0.0, 5.0, 10.0]
  @debug.assert_eq(rg_candidate_order(deps, [0.0, 0.0, 0.0], 0), [0, 1, 2])
  @debug.assert_eq(rg_candidate_order(deps, true_counts, 0), [1, 0, 2])
  let topological = rg_candidate_order(deps, [0.0, 0.0, 0.0], 0)
  let summed = rg_summed_dependent_counts(deps, true_counts, topological)
  @debug.assert_eq(summed, [10.0, 5.0, 10.0])
  @debug.assert_eq(rg_candidate_order(deps, summed, 0), [0, 2, 1])
  let exponential = rg_exponential_dependent_counts(
    deps, true_counts, topological,
  )
  @debug.assert_eq(exponential, [0.95, 5.0, 10.0])
  @debug.assert_eq(rg_candidate_order(deps, exponential, 0), [1, 0, 2])
}

///|
test "reorder-globals chooses the lowest true ULEB cost and keeps candidate ties stable" {
  let deps : Array[Array[Int]] = Array::new(capacity=129)
  for idx = 0; idx < 129; idx = idx + 1 {
    deps.push(if idx == 0 { [128] } else { [] })
  }
  let true_counts = Array::make(129, 0.0)
  true_counts[1] = 5.0
  true_counts[128] = 10.0
  let order = rg_choose_order(deps, true_counts, 0)
  @debug.assert_eq(order[0], 1)
  @debug.assert_eq(order[1], 0)
  @debug.assert_eq(order[2], 128)
  @debug.assert_eq(rg_order_cost(order, true_counts), 15.0)
}
