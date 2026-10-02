///|
// This candidate accepts exactly 51 or 57 top-level non-Nop instructions.
// Count before owning a row or inspecting nested control. Once the upper bound
// is exceeded no later instruction can restore the required size. Nested Nops
// stay inside their original instruction; only the top-level row is owned.
fn vacuum_indexed_tag_candidate_non_nops(
  body : Array[@lib.Instruction],
) -> Array[@lib.Instruction]? {
  let mut count = 0
  for instr in body {
    if !(instr is @lib.Nop) {
      count += 1
      if count > 57 {
        return None
      }
    }
  }
  if count != 51 && count != 57 {
    return None
  }
  let row = Array::make(count, @lib.Instruction::nop())
  let mut next = 0
  for instr in body {
    if !(instr is @lib.Nop) {
      row[next] = instr
      next += 1
    }
  }
  Some(row)
}
