///|
test "Coalesce weightless member coloring stops at the first valid equal-score slot" {
  let count = 8
  let types = Array::make(count, @lib.ValType::i32())
  let interferences = CLCfgSparseInterferences::new(count)
  let weights = CLCfgSparseWeights::new(count)
  let steps = [0]
  let expected = cl_cfg_slot_reference_color(
    [4, 5, 6, 7],
    types,
    4,
    interferences,
    weights,
  )
  let actual = cl_cfg_sparse_color_with_order(
    [4, 5, 6, 7],
    types,
    4,
    interferences,
    weights,
    query_steps=Some(steps),
  )
  assert_eq(actual.old_to_new, [0, 1, 2, 3, 0, 0, 0, 0])
  assert_eq(actual.old_to_new, expected.old_to_new)
  assert_eq(actual.slot_types, expected.slot_types)
  assert_eq(actual.removed_copies, 0)
  assert_eq(weights.rows, Array::makei(count, fn(_) { [] }))
  // No copy weight can improve zero; later equal-score slots cannot win.
  assert_eq(steps[0], 10)
}

///|
test "Coalesce weightless stopping retains interference types and weighted preference" {
  let count = 12
  let types = Array::make(count, @lib.ValType::i32())
  types[1] = @lib.ValType::i64()
  types[5] = @lib.ValType::i64()
  let interferences = CLCfgSparseInterferences::new(count)
  let weights = CLCfgSparseWeights::new(count)
  for idx in 4..<count {
    cl_cfg_sparse_add_interference(interferences, idx, 0)
    if idx % 3 == 0 {
      cl_cfg_sparse_add_interference(interferences, idx, 2)
    }
  }
  // Local4 prefers the later slot3 over slot2. Nonempty weighted rows must
  // retain the complete search, including equal-score earliest-slot ties.
  cl_cfg_sparse_weight_add(weights, 4, 3)
  cl_cfg_sparse_weight_add(weights, 4, 3)
  cl_cfg_sparse_weight_add(weights, 6, 2)
  cl_cfg_sparse_weight_add(weights, 6, 3)
  for reverse in [false, true] {
    let order = Array::makei(count - 4, fn(i) {
      if reverse {
        count - 1 - i
      } else {
        i + 4
      }
    })
    let expected = cl_cfg_slot_reference_color(
      order, types, 4, interferences, weights,
    )
    let actual = cl_cfg_sparse_color_with_order(
      order, types, 4, interferences, weights,
    )
    assert_eq(actual.old_to_new, expected.old_to_new)
    assert_eq(actual.slot_types, expected.slot_types)
    assert_eq(actual.removed_copies, expected.removed_copies)
    if !reverse {
      assert_eq(actual.old_to_new[4], 3)
    }
  }
}
