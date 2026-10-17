///|
#valtype
priv struct PassLowerBranchlessSummary {
  has_candidate : Bool
  branchless : Bool
  has_children : Bool
}

///|
#inline
fn pass_lower_instruction_transfers_control(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Br(_)
    | @lib.BrIf(_)
    | @lib.BrTable(_, _)
    | @lib.BrOnNull(_)
    | @lib.BrOnNonNull(_)
    | @lib.BrOnCast(_, _, _, _)
    | @lib.BrOnCastFail(_, _, _, _)
    | @lib.BrOnCastDescEq(_, _, _)
    | @lib.BrOnCastDescEqFail(_, _, _)
    | @lib.Return
    | @lib.ReturnCall(_)
    | @lib.ReturnCallIndirect(_, _)
    | @lib.ReturnCallRef(_)
    | @lib.Unreachable
    | @lib.Try(_, _, _, _)
    | @lib.TryTable(_, _, _)
    | @lib.Throw(_)
    | @lib.ThrowRef
    | @lib.Rethrow(_)
    | @lib.Suspend(_)
    | @lib.Resume(_, _)
    | @lib.ResumeThrow(_, _, _)
    | @lib.ResumeThrowRef(_, _)
    | @lib.StackSwitch(_, _) => true
    _ => false
  }
}

///|
// Removing a branchless Block cannot remove or add a transfer instruction.
// If no candidate is found, branchless is the old worker's exact result.
// Once a candidate is found, branchless is conservatively false; ancestors
// already have a candidate and do not need its exact branchless result.
// Keep invalid headers and option-dependent Blocks as conservative candidates;
// only the existing worker expands their signatures and decides to flatten.
fn pass_lower_branchless_summary(
  body : Array[@lib.Instruction],
  visits~ : Array[Int32]? = None,
) -> PassLowerBranchlessSummary {
  let mut branchless = true
  let mut has_children = false
  let mut visited = 0
  for instr in body {
    visited += 1
    let child : PassLowerBranchlessSummary = match instr {
      @lib.Block(_, @lib.Expr(child)) => {
        has_children = true
        let child = pass_lower_branchless_summary(child, visits~)
        {
          has_candidate: child.has_candidate || child.branchless,
          branchless: child.branchless,
          has_children: false,
        }
      }
      @lib.Loop(_, @lib.Expr(child)) => {
        has_children = true
        pass_lower_branchless_summary(child, visits~)
      }
      @lib.If(_, yes, no) => {
        has_children = true
        let yes = pass_lower_branchless_summary(yes, visits~)
        let no = if yes.has_candidate {
          { has_candidate: false, branchless: false, has_children: false, }
        } else {
          match no {
            Some(no) => pass_lower_branchless_summary(no, visits~)
            None =>
              { has_candidate: false, branchless: true, has_children: false, }
          }
        }
        {
          has_candidate: yes.has_candidate || no.has_candidate,
          branchless: yes.branchless && no.branchless,
          has_children: false,
        }
      }
      @lib.TryTable(_, _, @lib.Expr(child)) => {
        has_children = true
        let child = pass_lower_branchless_summary(child, visits~)
        {
          has_candidate: child.has_candidate,
          branchless: false,
          has_children: false,
        }
      }
      @lib.Try(_, @lib.Expr(child), catches, _) => {
        has_children = true
        let child = pass_lower_branchless_summary(child, visits~)
        let mut candidate = child.has_candidate
        if !candidate {
          for catch_ in catches {
            let @lib.Expr(child) = match catch_ {
              @lib.LegacyCatch(_, child) | @lib.LegacyCatchAll(child) => child
            }
            if pass_lower_branchless_summary(child, visits~).has_candidate {
              candidate = true
              break
            }
          }
        }
        { has_candidate: candidate, branchless: false, has_children: false, }
      }
      _ =>
        {
          has_candidate: false,
          branchless: !pass_lower_instruction_transfers_control(instr),
          has_children: false,
        }
    }
    if child.has_candidate {
      match visits {
        Some(visits) => visits[0] += visited
        None => ()
      }
      return { has_candidate: true, branchless: false, has_children, }
    }
    branchless = branchless && child.branchless
  }
  match visits {
    Some(visits) => visits[0] += visited
    None => ()
  }
  { has_candidate: false, branchless, has_children, }
}

///|
#inline
fn pass_lower_branchless_leaf(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Block(_, _)
    | @lib.Loop(_, _)
    | @lib.If(_, _, _)
    | @lib.Try(_, _, _, _)
    | @lib.TryTable(_, _, _) => false
    _ => !pass_lower_instruction_transfers_control(instr)
  }
}
