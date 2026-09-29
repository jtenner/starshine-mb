///|
// Qualified blocks have no inputs and no branches/early returns. Their ordered
// children have exactly the same scalar dependency and rewrite meaning when
// replayed in the parent. Indexed, tuple and other control stays on HOT.
fn dae2_raw_branchless_instructions(
  instructions : Array[@lib.Instruction],
  first_block? : Int = -1,
) -> Array[@lib.Instruction]? {
  let mut first = first_block
  if first < 0 {
    for index in 0..<instructions.length() {
      if instructions[index] is @lib.Block(_, _) {
        first = index
        break
      }
    }
  }
  if first < 0 {
    return Some(instructions)
  }
  let output : Array[@lib.Instruction] = []
  for index in 0..<first {
    output.push(instructions[index])
  }
  let sequences : Array[Array[@lib.Instruction]] = [instructions]
  let positions = [first]
  while !sequences.is_empty() {
    let frame = sequences.length() - 1
    let body = sequences[frame]
    let position = positions[frame]
    if position == body.length() {
      ignore(sequences.pop())
      ignore(positions.pop())
      continue
    }
    positions[frame] = position + 1
    let instr = body[position]
    match instr {
      @lib.Block(block_type, @lib.Expr(children)) => {
        match block_type {
          @lib.VoidBlockType | @lib.ValTypeBlockType(_) => ()
          _ => return None
        }
        sequences.push(children)
        positions.push(0)
      }
      @lib.Return if sequences.length() > 1 => return None
      // No label can remain or be rebased when an enclosing block is removed.
      @lib.Loop(_, _)
      | @lib.If(_, _, _)
      | @lib.Try(_, _, _, _)
      | @lib.TryTable(_, _, _)
      | @lib.Br(_)
      | @lib.BrIf(_)
      | @lib.BrTable(_, _)
      | @lib.Unreachable => return None
      _ => output.push(instr)
    }
  }
  Some(output)
}
