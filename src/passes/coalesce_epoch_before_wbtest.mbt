///|
// This worker is called only by the existing linear-interference path. Keep
// branch joins and conservative barriers on the unchanged old worker.
fn cl_epoch_before(
  instrs : Array[@lib.Instruction],
  actions : Array[CLAction],
  effective : Array[Bool],
  types : Array[@lib.ValType],
  param_count : Int32,
  interferences : CLBitMatrix,
  candidate_visits~ : Array[Int32]? = None,
  fallback_calls~ : Array[Int32]? = None,
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
  let (writers, readers) = cl_source_write_dest_read_active_flags(
    actions,
    effective,
    types.length(),
  )
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
  let cleared_at = Array::make(types.length(), 0)
  // Each effective non-parameter write increments this once across ALL rows,
  // so tick <= effective action count <= actions.length(); no wrap is needed.
  let mut tick = 0
  for source in param_count..<types.length() {
    if !writers[source] {
      continue
    }
    let mut reset_at = tick
    let mut written_at = tick
    for step in steps {
      match step {
        Read(dest) => {
          if dest < 0 || dest >= types.length() {
            continue
          }
          let clear = if cleared_at[dest] > reset_at {
            cleared_at[dest]
          } else {
            reset_at
          }
          if written_at > clear {
            if dest != source &&
              types[source] == types[dest] &&
              !cl_bit_matrix_get(interferences, source, dest) {
              cl_add_interference(interferences, source, dest)
            }
            cleared_at[dest] = written_at
          }
        }
        Write(local, copied_dest) =>
          if local == source {
            tick += 1
            written_at = tick
            if copied_dest >= 0 && copied_dest < types.length() {
              cleared_at[copied_dest] = written_at
            }
          } else if local >= 0 && local < types.length() {
            cleared_at[local] = written_at
          }
        Reset => reset_at = tick
        Branch(_, _) | Barrier =>
          abort("linear hazard admission allowed a control step")
      }
    }
  }
}
