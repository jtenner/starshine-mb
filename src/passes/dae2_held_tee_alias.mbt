///|
// A tee copies the current stack value without consuming it. Find an earlier
// single writer of that same lane through a bounded, balanced suffix. Calls,
// loads and conditional bodies keep their exact evaluation positions.
fn dae2_alias_held_tee_source(
  instrs : Array[@lib.Instruction],
  end : Int32,
  writes : Array[Int32],
  stack_effects : ((@lib.Instruction) -> (Int32, Int32)?)?,
) -> Int32 {
  let query = match stack_effects {
    Some(query) => query
    None => return -1
  }
  let mut needed = 1
  for position = end - 1
      position >= 0 && position >= end - 64
      position = position - 1 {
    match instrs[position] {
      @lib.LocalTee(@lib.LocalIdx(raw)) =>
        if needed == 1 {
          let source = raw.to_int()
          return if source >= 0 &&
            source < writes.length() &&
            writes[source] == 1 {
            source
          } else {
            -1
          }
        }
      @lib.If(@lib.VoidBlockType, _, _) => needed += 1
      instr => {
        let (inputs, outputs) = match query(instr) {
          Some(effect) => effect
          None => return -1
        }
        // The wanted lane must precede this producer. A newly produced lane
        // has no proved local alias. Bound both work and stack-depth arithmetic.
        if inputs < 0 ||
          outputs < 0 ||
          inputs > 64 ||
          outputs > 64 ||
          needed <= outputs {
          return -1
        }
        needed = needed - outputs + inputs
      }
    }
  }
  -1
}
