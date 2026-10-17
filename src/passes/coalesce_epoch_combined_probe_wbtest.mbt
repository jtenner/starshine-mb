///|
// This worker is called only by the existing linear-interference path. Keep
// branch joins and conservative barriers on the unchanged old worker.
fn cl_epoch_combined_instrumented(
  instrs : Array[@lib.Instruction],
  actions : Array[CLAction],
  effective : Array[Bool],
  types : Array[@lib.ValType],
  param_count : Int32,
  interferences : CLBitMatrix,
  candidate_visits~ : Array[Int32]? = None,
  fallback_calls~ : Array[Int32]? = None,
  step_work~ : Array[Int32]? = None,
  read_work~ : Array[Int32]? = None,
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.Block(_, _)
      | @lib.Loop(_, _)
      | @lib.If(_, _, _)
      | @lib.Try(_, _, _, _)
      | @lib.TryTable(_, _, _)
      | @lib.BrIf(_)
      | @lib.BrTable(_, _) => {
        match fallback_calls {
          Some(calls) => calls[0] += 1
          None => ()
        }
        cl_add_source_write_dest_read_interferences(
          instrs,
          actions,
          effective,
          types,
          param_count,
          interferences,
          candidate_visits~,
        )
        return
      }
      _ => ()
    }
  }
  let writers = Array::make(types.length(), false)
  let readers = Array::make(types.length(), false)
  let mut saw_source_write = false
  let mut has_later_read = false
  for action_idx = 0; action_idx < actions.length(); action_idx = action_idx + 1 {
    let action = actions[action_idx]
    match action.kind {
      CLActionKind::Get => {
        readers[action.local_idx] = true
        if saw_source_write {
          has_later_read = true
        }
      }
      CLActionKind::Set | CLActionKind::Tee =>
        if cl_action_is_effective(effective, action_idx) {
          writers[action.local_idx] = true
          if action.local_idx >= param_count {
            saw_source_write = true
          }
        }
    }
  }
  // No effective body-local write precedes any read. No source/dest hazard
  // can be added; retain the existing matrix and avoid compiling steps.
  if !has_later_read {
    return
  }
  if !readers.any(fn(read) { read }) {
    return
  }
  let mut has_source = false
  for source in param_count..<types.length() {
    if writers[source] {
      has_source = true
      break
    }
  }
  if !has_source {
    return
  }
  let steps : Array[CLSourceHazardStep] = []
  cl_compile_source_hazard_steps(instrs, effective, [0], steps, None)
  match step_work {
    Some(work) => {
      work[0] += 1
      work[1] += steps.length()
    }
    None => ()
  }
  let cleared_at = Array::make(types.length(), 0)
  // Each effective non-parameter write increments this once across ALL rows,
  // so tick <= effective action count <= actions.length(); no wrap is needed.
  let mut tick = 0
  for source in param_count..<types.length() {
    if !writers[source] {
      continue
    }
    // The existing writers[source] access proves 0 <= source < types.length().
    // Thus -1 - source is in [-Int32::MAX, -1], never overflows, and cannot alias
    // the nonnegative tick/reset epochs. No source+1 intermediate is needed.
    let row_done = -1 - source
    let mut reset_at = tick
    let mut written_at = tick
    for step in steps {
      match step {
        Read(dest) => {
          if dest < 0 || dest >= types.length() {
            continue
          }
          if cleared_at[dest] == row_done {
            continue
          }
          // Count the real unsettled read-state path. A future done-pair
          // fastpath must return before this state-resolution site.
          match read_work {
            Some(work) => work[0] += 1
            None => ()
          }
          let clear = if cleared_at[dest] > reset_at {
            cleared_at[dest]
          } else {
            reset_at
          }
          if written_at > clear {
            if dest != source {
              match read_work {
                Some(work) => work[1] += 1
                None => ()
              }
              if types[source] == types[dest] {
                match read_work {
                  Some(work) => work[2] += 1
                  None => ()
                }
                if !cl_bit_matrix_get(interferences, source, dest) {
                  cl_add_interference(interferences, source, dest)
                }
              }
            }
            cleared_at[dest] = row_done
          }
        }
        Write(local, copied_dest) =>
          if local == source {
            tick += 1
            written_at = tick
            if copied_dest >= 0 &&
              copied_dest < types.length() &&
              cleared_at[copied_dest] != row_done {
              cleared_at[copied_dest] = written_at
            }
          } else if local >= 0 &&
            local < types.length() &&
            cleared_at[local] != row_done {
            cleared_at[local] = written_at
          }
        Reset => reset_at = tick
        Branch(_, _) | Barrier =>
          abort("linear hazard admission allowed a control step")
      }
    }
  }
}
