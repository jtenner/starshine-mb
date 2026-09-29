///|
fn cl_color_with_order_reference(
  order : Array[Int],
  types : Array[@lib.ValType],
  param_count : Int,
  interferences : CLBitMatrix,
  weights : CLCopyWeights,
) -> CLColoring {
  let total_locals = types.length()
  let old_to_new = Array::make(total_locals, -1)
  for idx = 0; idx < param_count; idx = idx + 1 {
    old_to_new[idx] = idx
  }
  let slot_types : Array[@lib.ValType] = []
  let slot_members : Array[Array[Int]] = []
  for idx = 0; idx < param_count; idx = idx + 1 {
    slot_types.push(types[idx])
    slot_members.push([idx])
  }
  for local_idx in order {
    let ty = types[local_idx]
    let slot_copy_scores = Array::make(slot_types.length(), 0)
    for edge in weights.rows[local_idx] {
      let (other, weight) = edge
      let assigned_slot = old_to_new[other]
      if assigned_slot >= 0 && assigned_slot < slot_copy_scores.length() {
        slot_copy_scores[assigned_slot] += weight
      }
    }
    let mut best_slot = -1
    let mut best_score = -1
    for slot = 0; slot < slot_types.length(); slot = slot + 1 {
      if slot_types[slot] == ty &&
        !cl_slot_interferes(slot_members[slot], local_idx, interferences) {
        let score = slot_copy_scores[slot]
        if score > best_score {
          best_score = score
          best_slot = slot
        }
      }
    }
    if best_slot < 0 {
      best_slot = slot_types.length()
      slot_types.push(ty)
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
  for lhs = 0; lhs < total_locals; lhs = lhs + 1 {
    for edge in weights.rows[lhs] {
      let (rhs, weight) = edge
      if rhs > lhs && old_to_new[lhs] == old_to_new[rhs] {
        removed_copies += weight
      }
    }
  }
  { old_to_new, slot_types: body_slot_types, removed_copies, }
}
