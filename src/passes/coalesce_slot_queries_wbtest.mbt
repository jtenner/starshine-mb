///|
fn cl_cfg_slot_reference_color(
  order : Array[Int],
  types : Array[@lib.ValType],
  param_count : Int,
  interferences : CLCfgSparseInterferences,
  weights : CLCfgSparseWeights,
  query_steps? : Array[Int]? = None,
) -> CLColoring {
  let old_to_new = Array::make(types.length(), -1)
  let slot_types : Array[@lib.ValType] = []
  let slot_members : Array[Array[Int]] = []
  for idx = 0; idx < param_count; idx = idx + 1 {
    old_to_new[idx] = idx
    slot_types.push(types[idx])
    slot_members.push([idx])
  }
  let weight_values = Array::make(types.length(), 0)
  let weight_marks = Array::make(types.length(), -1)
  for local_idx in order {
    for edge in weights.rows[local_idx] {
      let (other, weight) = edge
      weight_values[other] = weight
      weight_marks[other] = local_idx
    }
    let mut best_slot = -1
    let mut best_score = -1
    for slot = 0; slot < slot_types.length(); slot = slot + 1 {
      if slot_types[slot] == types[local_idx] &&
        !cl_cfg_sparse_slot_interferes(
          slot_members[slot],
          local_idx,
          interferences,
          query_steps~,
        ) {
        let score = cl_cfg_sparse_slot_copy_score(
          slot_members[slot],
          local_idx,
          weight_values,
          weight_marks,
        )
        if score > best_score {
          best_score = score
          best_slot = slot
        }
      }
    }
    if best_slot < 0 {
      best_slot = slot_types.length()
      slot_types.push(types[local_idx])
      slot_members.push([])
    }
    old_to_new[local_idx] = best_slot
    slot_members[best_slot].push(local_idx)
  }
  let body_slot_types : Array[@lib.ValType] = []
  for slot = param_count; slot < slot_types.length(); slot = slot + 1 {
    body_slot_types.push(slot_types[slot])
  }
  let mut removed_copies = 0
  for lhs = 0; lhs < weights.rows.length(); lhs = lhs + 1 {
    for edge in weights.rows[lhs] {
      let (rhs, weight) = edge
      if rhs > lhs && old_to_new[lhs] == old_to_new[rhs] {
        removed_copies += weight
      }
    }
  }
  { old_to_new, slot_types: body_slot_types, removed_copies, }
}

///|
test "Coalesce slot queries preserve ordered coloring without repeated member probes" {
  let count = 128
  let types = Array::make(count, @lib.ValType::i32())
  let order = Array::makei(count, fn(i) { i })
  let interferences = CLCfgSparseInterferences::new(count)
  let weights = CLCfgSparseWeights::new(count)
  let steps = [0]
  let result = cl_cfg_sparse_color_with_order(
    order,
    types,
    0,
    interferences,
    weights,
    query_steps=Some(steps),
  )
  assert_eq(result.old_to_new, Array::make(count, 0))
  assert_eq(result.slot_types, [@lib.ValType::i32()])
  assert_true(steps[0] <= 512, msg="coloring query steps: \{steps[0]}")
  for idx in 0..<count {
    if idx % 17 == 0 {
      types[idx] = @lib.ValType::i64()
    }
  }
  for idx in 2..<count {
    if idx % 3 == 0 {
      cl_cfg_sparse_add_interference(interferences, idx, idx - 2)
    }
    cl_cfg_sparse_weight_add(weights, idx, idx - 1)
    if idx % 5 == 0 {
      cl_cfg_sparse_weight_add(weights, idx, idx - 1)
    }
  }
  for params in [0, 2] {
    for reverse in [false, true] {
      let order = Array::makei(count - params, fn(i) {
        if reverse {
          count - 1 - i
        } else {
          params + i
        }
      })
      let expected = cl_cfg_slot_reference_color(
        order, types, params, interferences, weights,
      )
      let actual = cl_cfg_sparse_color_with_order(
        order, types, params, interferences, weights,
      )
      assert_eq(actual.old_to_new, expected.old_to_new)
      assert_eq(actual.slot_types, expected.slot_types)
      assert_eq(actual.removed_copies, expected.removed_copies)
    }
  }
}
