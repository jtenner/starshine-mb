///|
// Local names keep their strings and entry counts under a bijective reorder.
// A nonincreasing index-width sum keeps their payload and length prefixes from
// growing. Bound row lookup; large metadata maps retain the existing order.
fn dae2_local_order_names_nonincreasing(
  names : @lib.NameSec?,
  function_abs : Int32,
  before : Array[Int32],
  after : Array[Int32],
) -> Bool {
  let rows = match names {
    Some(names) =>
      match names.local_names {
        Some(@lib.IndirectNameMap(rows)) => rows
        None => return true
      }
    None => return true
  }
  if rows.length() > 256 {
    return false
  }
  for row in rows {
    let @lib.IndirectNameAssoc(index, @lib.NameMap(entries)) = row
    if index.reinterpret_as_int() != function_abs {
      continue
    }
    let mut delta = 0L
    for entry in entries {
      let @lib.NameAssoc(raw, _) = entry
      let slot = raw.reinterpret_as_int()
      if slot >= 0 && slot < before.length() && before[slot] >= 0 {
        delta += dae2_local_index_width(after[slot]).to_int64() -
          dae2_local_index_width(before[slot]).to_int64()
      }
    }
    if delta > 0L {
      return false
    }
  }
  true
}

///|
// Reuse the complete cleanup census and its required remap. Equal types keep
// the local declaration byte-for-byte unchanged. Parameters are fixed, ties
// keep the old order, and both body and name payloads must not grow.
fn dae2_order_compacted_local_indices(
  indices : Array[Int32],
  reads : Array[Int32],
  writes : Array[Int32],
  params : Int32,
  retained : Array[@lib.ValType],
  names : @lib.NameSec?,
  function_abs : Int32,
) -> Bool {
  if retained.is_empty() ||
    dae2_local_index_width(params) ==
    dae2_local_index_width(params + retained.length() - 1) {
    return false
  }
  let ty = retained[0]
  for other in retained {
    if other != ty {
      return false
    }
  }
  let order : Array[Int32] = []
  let mut before_cost = 0L
  for old in params..<indices.length() {
    if indices[old] >= params {
      order.push(old)
      before_cost += (reads[old].to_int64() + writes[old].to_int64()) *
        dae2_local_index_width(indices[old]).to_int64()
    }
  }
  order.sort_by(fn(left, right) {
    let left_count = reads[left].to_int64() + writes[left].to_int64()
    let right_count = reads[right].to_int64() + writes[right].to_int64()
    if left_count == right_count {
      left.compare(right)
    } else {
      right_count.compare(left_count)
    }
  })
  let proposed = indices.copy()
  let mut after_cost = 0L
  for rank in 0..<order.length() {
    let old = order[rank]
    let next = params + rank
    proposed[old] = next
    after_cost += (reads[old].to_int64() + writes[old].to_int64()) *
      dae2_local_index_width(next).to_int64()
  }
  if after_cost >= before_cost ||
    !dae2_local_order_names_nonincreasing(
      names, function_abs, indices, proposed,
    ) {
    return false
  }
  for old in params..<indices.length() {
    indices[old] = proposed[old]
  }
  true
}
