///|
// Read-only predicate rows borrow clean input. A filtered row owns its array;
// neither result permits a caller to mutate child instruction payloads.
fn vacuum_predicate_non_nops(
  body : Array[@lib.Instruction],
) -> Array[@lib.Instruction] {
  let mut first_nop = -1
  for index, instr in body {
    if instr is @lib.Nop {
      first_nop = index
      break
    }
  }
  if first_nop < 0 {
    return body
  }
  let row = []
  for index in 0..<first_nop {
    row.push(body[index])
  }
  for index in (first_nop + 1)..<body.length() {
    match body[index] {
      @lib.Nop => ()
      instr => row.push(instr)
    }
  }
  row
}

///|
fn vacuum_predicate_non_nops_at_most(
  body : Array[@lib.Instruction],
  limit : Int32,
  visits~ : Array[Int32]? = None,
) -> Array[@lib.Instruction]? {
  if limit < 0 {
    return None
  }
  if body.length() <= limit {
    match visits {
      Some(visits) => visits[0] += body.length()
      None => ()
    }
    return Some(vacuum_predicate_non_nops(body))
  }
  let mut first_nop = -1
  for index, instr in body {
    match visits {
      Some(visits) => visits[0] += 1
      None => ()
    }
    if instr is @lib.Nop {
      first_nop = index
      break
    }
    if index >= limit {
      return None
    }
  }
  if first_nop < 0 {
    return Some(body)
  }
  // No earlier Nop exists, so this copied prefix has at most limit
  // instructions. Preserve the unconstrained helper's array growth.
  let row = []
  for index in 0..<first_nop {
    row.push(body[index])
  }
  for index in (first_nop + 1)..<body.length() {
    match visits {
      Some(visits) => visits[0] += 1
      None => ()
    }
    match body[index] {
      @lib.Nop => ()
      instr => {
        if row.length() >= limit {
          return None
        }
        row.push(instr)
      }
    }
  }
  Some(row)
}
