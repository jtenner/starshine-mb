///|
// Deliberately simple equivalent reference: search the suffix separately for
// each store. Native controls compare the new linear algorithm with this
// quadratic construction of the desired feature, not with a shipped speed.
fn sl_constant_sink_reference(
  instrs : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Int) {
  let changes = Array::make(instrs.length(), -1)
  let mut count = 0
  for store in 1..<instrs.length() {
    let local = match instrs[store] {
      @lib.LocalSet(@lib.LocalIdx(raw)) => raw.reinterpret_as_int()
      _ => continue
    }
    if !sl_sinkable_numeric_constant(instrs[store - 1]) {
      continue
    }
    for read = store + 1; read < instrs.length(); read = read + 1 {
      match instrs[read] {
        @lib.LocalGet(@lib.LocalIdx(raw)) =>
          if raw.reinterpret_as_int() == local {
            changes[store - 1] = -2
            changes[store] = -2
            changes[read] = store - 1
            count += 1
            break
          }
        @lib.LocalSet(@lib.LocalIdx(raw)) | @lib.LocalTee(@lib.LocalIdx(raw)) =>
          if raw.reinterpret_as_int() == local {
            break
          }
        instr => if !sl_constant_store_prefix_is_nontrapping(instr) { break }
      }
    }
  }
  if count == 0 {
    return (instrs, 0)
  }
  let result : Array[@lib.Instruction] = []
  for idx in 0..<instrs.length() {
    if changes[idx] >= 0 {
      result.push(instrs[changes[idx]])
      let local = match instrs[idx] {
        @lib.LocalGet(local) => local
        _ => abort("reference sink requires read")
      }
      result.push(@lib.Instruction::local_tee(local))
    } else if changes[idx] != -2 {
      result.push(instrs[idx])
    }
  }
  (result, count)
}
