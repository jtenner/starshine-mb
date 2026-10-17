///|
// Frozen original worker: unconditional reader-index construction.
fn cl_reader_admission_unconditional_reference(
  instrs : Array[@lib.Instruction],
  actions : Array[CLAction],
  effective : Array[Bool],
  types : Array[@lib.ValType],
  param_count : Int32,
  interferences : CLBitMatrix,
  instruction_visits~ : Array[Int32]? = None,
  candidate_visits~ : Array[Int32]? = None,
  indexed_readers~ : Bool = true,
) -> Unit {
  let (writers, readers) = cl_source_write_dest_read_active_flags(
    actions,
    effective,
    types.length(),
  )
  let reader_index = if indexed_readers {
    Some(cl_source_hazard_reader_index(types, readers))
  } else {
    None
  }
  let first_effective_write = Array::make(types.length(), -1)
  let latest_get = Array::make(types.length(), -1)
  for action_idx = 0; action_idx < actions.length(); action_idx = action_idx + 1 {
    let action = actions[action_idx]
    match action.kind {
      CLActionKind::Get => latest_get[action.local_idx] = action_idx
      CLActionKind::Set | CLActionKind::Tee =>
        if cl_action_is_effective(effective, action_idx) &&
          first_effective_write[action.local_idx] < 0 {
          first_effective_write[action.local_idx] = action_idx
        }
    }
  }
  let mut compiled : Array[CLSourceHazardStep]? = None
  for source = param_count; source < types.length(); source = source + 1 {
    if !writers[source] {
      continue
    }
    let candidate_dests = match reader_index {
      Some(index) =>
        cl_source_write_dest_read_candidate_dests_indexed(
          source,
          index,
          interferences,
          first_effective_write,
          latest_get,
          candidate_visits~,
        )
      None =>
        cl_source_write_dest_read_candidate_dests(
          source,
          readers,
          types,
          interferences,
          first_effective_write,
          latest_get,
          candidate_visits~,
        )
    }
    if candidate_dests.length() == 0 {
      continue
    }
    let steps = match compiled {
      Some(steps) => steps
      None => {
        let steps = []
        cl_compile_source_hazard_steps(
          instrs,
          effective,
          [0],
          steps,
          instruction_visits,
        )
        compiled = Some(steps)
        steps
      }
    }
    let hazards = Array::make(types.length(), false)
    cl_run_source_hazard_steps(
      steps,
      source,
      candidate_dests,
      Array::make(types.length(), false),
      hazards,
    )
    for dest in candidate_dests {
      if hazards[dest] {
        cl_add_interference(interferences, source, dest)
      }
    }
  }
}
