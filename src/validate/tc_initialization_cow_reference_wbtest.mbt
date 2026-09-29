///|
// Return the remaining proof budget, or -1 when borrowing is not proved safe.
// Only local.set/tee can change initialization; all nested bodies participate.
fn tc_body_initialization_budget_reference(
  body : Array[Instruction],
  initialized : Array[Bool],
  budget : Int,
) -> Int {
  if body.length() > budget {
    return -1
  }
  let mut remaining = budget
  for instr in body {
    if remaining <= 0 {
      return -1
    }
    remaining -= 1
    match instr {
      LocalSet(LocalIdx(raw)) | LocalTee(LocalIdx(raw)) => {
        let index = raw.reinterpret_as_int()
        if index < 0 || index >= initialized.length() || !initialized[index] {
          return -1
        }
      }
      Block(_, Expr(child))
      | Loop(_, Expr(child))
      | TryTable(_, _, Expr(child)) =>
        remaining = tc_body_initialization_budget_reference(
          child, initialized, remaining,
        )
      If(_, yes, no) => {
        remaining = tc_body_initialization_budget_reference(
          yes, initialized, remaining,
        )
        if no is Some(child) {
          remaining = tc_body_initialization_budget_reference(
            child, initialized, remaining,
          )
        }
      }
      Try(_, Expr(child), catches, _) => {
        remaining = tc_body_initialization_budget_reference(
          child, initialized, remaining,
        )
        for catch_ in catches {
          let child = match catch_ {
            LegacyCatch(_, Expr(child)) | LegacyCatchAll(Expr(child)) => child
          }
          remaining = tc_body_initialization_budget_reference(
            child, initialized, remaining,
          )
          if remaining < 0 {
            return -1
          }
        }
      }
      _ => ()
    }
    if remaining < 0 {
      return -1
    }
  }
  remaining
}

///|
fn tc_fork_initialized_for_body_reference(
  initialized : Array[Bool],
  body : Array[Instruction],
) -> Array[Bool] {
  if initialized.length() >= 128 &&
    body.length() <= 8 &&
    tc_body_initialization_budget_reference(body, initialized, 8) >= 0 {
    initialized
  } else {
    initialized.copy()
  }
}
