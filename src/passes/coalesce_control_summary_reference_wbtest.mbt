///|
fn cl_br_table_all_past_depth_reference(
  labels : Array[@lib.LabelIdx],
  default_label : @lib.LabelIdx,
  boundary_depth : Int,
) -> Bool {
  if cl_label_idx_raw(default_label) <= boundary_depth {
    return false
  }
  for label in labels {
    if cl_label_idx_raw(label) <= boundary_depth {
      return false
    }
  }
  true
}

///|
fn cl_instr_escapes_past_depth_reference(
  instr : @lib.Instruction,
  boundary_depth : Int,
) -> Bool {
  if cl_instr_is_terminal(instr) {
    return true
  }
  match instr {
    @lib.Br(label_idx) => cl_label_idx_raw(label_idx) > boundary_depth
    @lib.BrTable(labels, default_label) =>
      cl_br_table_all_past_depth_reference(
        labels, default_label, boundary_depth,
      )
    @lib.Block(_, @lib.Expr(body)) =>
      !body.any(fn(child) {
        cl_instr_tree_branches_to_depth_reference(child, 0)
      }) &&
      cl_instrs_end_in_escape_past_depth_reference(body, boundary_depth + 1)
    @lib.If(_, then_body, Some(else_body)) =>
      !then_body.any(fn(child) {
        cl_instr_tree_branches_to_depth_reference(child, 0)
      }) &&
      !else_body.any(fn(child) {
        cl_instr_tree_branches_to_depth_reference(child, 0)
      }) &&
      cl_instrs_end_in_escape_past_depth_reference(
        then_body,
        boundary_depth + 1,
      ) &&
      cl_instrs_end_in_escape_past_depth_reference(
        else_body,
        boundary_depth + 1,
      )
    @lib.TryTable(_, _, @lib.Expr(body)) =>
      !body.any(fn(child) {
        cl_instr_tree_branches_to_depth_reference(child, 0)
      }) &&
      cl_instrs_end_in_escape_past_depth_reference(body, boundary_depth + 1)
    _ => false
  }
}

///|
fn cl_instrs_end_in_escape_past_depth_reference(
  instrs : Array[@lib.Instruction],
  boundary_depth : Int,
) -> Bool {
  if instrs.length() == 0 {
    return false
  }
  let last_idx = instrs.length() - 1
  // ReFinalize-style cleanup keeps an unreachable sentinel after a control
  // transfer when an enclosing typed region still needs stack polymorphism.
  // Look through that dead sentinel when deciding which enclosing label the
  // transfer actually escapes; otherwise a branch to the current block is
  // mistaken for a trap that escapes its parent as well.
  if last_idx > 0 && instrs[last_idx] == @lib.Instruction::unreachable_() {
    let previous = instrs[last_idx - 1]
    // Escaping this boundary implies that the previous instruction cannot
    // fall through. Check it first so a deeply nested escape is not walked
    // again by the more general no-fallthrough query at every enclosing
    // unreachable sentinel.
    if cl_instr_escapes_past_depth_reference(previous, boundary_depth) {
      return true
    }
    if cl_instr_never_falls_through_reference(previous) {
      return false
    }
  }
  cl_instr_escapes_past_depth_reference(instrs[last_idx], boundary_depth)
}

///|
fn cl_instr_never_falls_through_reference(instr : @lib.Instruction) -> Bool {
  if cl_instr_is_terminal(instr) {
    return true
  }
  match instr {
    @lib.Br(_) | @lib.BrTable(_, _) => true
    @lib.Block(_, @lib.Expr(body)) =>
      !body.any(fn(child) {
        cl_instr_tree_branches_to_depth_reference(child, 0)
      }) &&
      cl_instrs_end_in_escape_past_depth_reference(body, 0)
    @lib.If(_, then_body, Some(else_body)) =>
      !then_body.any(fn(child) {
        cl_instr_tree_branches_to_depth_reference(child, 0)
      }) &&
      !else_body.any(fn(child) {
        cl_instr_tree_branches_to_depth_reference(child, 0)
      }) &&
      cl_instrs_end_in_escape_past_depth_reference(then_body, 0) &&
      cl_instrs_end_in_escape_past_depth_reference(else_body, 0)
    @lib.TryTable(_, _, @lib.Expr(body)) =>
      !body.any(fn(child) {
        cl_instr_tree_branches_to_depth_reference(child, 0)
      }) &&
      cl_instrs_end_in_escape_past_depth_reference(body, 0)
    _ => false
  }
}

///|
fn cl_label_targets_depth_reference(
  label_idx : @lib.LabelIdx,
  depth : Int,
) -> Bool {
  cl_label_idx_raw(label_idx) == depth
}

///|
fn cl_instr_tree_branches_to_depth_reference(
  instr : @lib.Instruction,
  depth : Int,
) -> Bool {
  match instr {
    @lib.Br(label_idx)
    | @lib.BrIf(label_idx)
    | @lib.BrOnNull(label_idx)
    | @lib.BrOnNonNull(label_idx) =>
      cl_label_targets_depth_reference(label_idx, depth)
    @lib.BrOnCast(label_idx, _, _, _)
    | @lib.BrOnCastFail(label_idx, _, _, _)
    | @lib.BrOnCastDescEq(label_idx, _, _)
    | @lib.BrOnCastDescEqFail(label_idx, _, _) =>
      cl_label_targets_depth_reference(label_idx, depth)
    @lib.BrTable(labels, default_label) => {
      if cl_label_targets_depth_reference(default_label, depth) {
        return true
      }
      labels.any(fn(label_idx) {
        cl_label_targets_depth_reference(label_idx, depth)
      })
    }
    @lib.TryTable(_, catches, @lib.Expr(body)) => {
      for catch_ in catches {
        let label = match catch_ {
          @lib.Catch(_, label)
          | @lib.CatchRef(_, label)
          | @lib.CatchAll(label)
          | @lib.CatchAllRef(label) => label
        }
        if cl_label_targets_depth_reference(label, depth) {
          return true
        }
      }
      body.any(fn(child) {
        cl_instr_tree_branches_to_depth_reference(child, depth + 1)
      })
    }
    @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
      body.any(fn(child) {
        cl_instr_tree_branches_to_depth_reference(child, depth + 1)
      })
    @lib.If(_, then_body, else_body) => {
      if then_body.any(fn(child) {
          cl_instr_tree_branches_to_depth_reference(child, depth + 1)
        }) {
        return true
      }
      match else_body {
        Some(body) =>
          body.any(fn(child) {
            cl_instr_tree_branches_to_depth_reference(child, depth + 1)
          })
        None => false
      }
    }
    @lib.Try(_, @lib.Expr(body), catches, _) => {
      if body.any(fn(child) {
          cl_instr_tree_branches_to_depth_reference(child, depth + 1)
        }) {
        return true
      }
      for catch_ in catches {
        let catch_body = match catch_ {
          @lib.LegacyCatch(_, @lib.Expr(catch_body))
          | @lib.LegacyCatchAll(@lib.Expr(catch_body)) => catch_body
        }
        if catch_body.any(fn(child) {
            cl_instr_tree_branches_to_depth_reference(child, depth + 1)
          }) {
          return true
        }
      }
      false
    }
    _ => false
  }
}

///|
fn cl_collect_instrs_reference(
  instrs : Array[@lib.Instruction],
  actions : Array[CLAction],
  total_locals : Int,
) -> Unit {
  let mut reachable = true
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    let instr = instrs[idx]
    if !reachable {
      continue
    }
    match instr {
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        cl_collect_instrs_reference(body, actions, total_locals)
      @lib.If(_, then_body, else_body) => {
        cl_collect_instrs_reference(then_body, actions, total_locals)
        match else_body {
          Some(body) => cl_collect_instrs_reference(body, actions, total_locals)
          None => ()
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        cl_collect_instrs_reference(body, actions, total_locals)
      @lib.LocalGet(local_idx) => {
        let raw = cl_local_idx_raw(local_idx)
        if raw >= 0 && raw < total_locals {
          actions.push({
            kind: CLActionKind::Get,
            local_idx: raw,
            source: CLValueSource::Unique,
          })
        }
      }
      @lib.LocalSet(local_idx) => {
        let raw = cl_local_idx_raw(local_idx)
        if raw >= 0 && raw < total_locals {
          actions.push({
            kind: CLActionKind::Set,
            local_idx: raw,
            source: cl_value_source_before(instrs, idx),
          })
        }
      }
      @lib.LocalTee(local_idx) => {
        let raw = cl_local_idx_raw(local_idx)
        if raw >= 0 && raw < total_locals {
          actions.push({
            kind: CLActionKind::Tee,
            local_idx: raw,
            source: cl_value_source_before(instrs, idx),
          })
        }
      }
      _ => ()
    }
    if cl_instr_never_falls_through_reference(instr) {
      reachable = false
    }
  }
}
