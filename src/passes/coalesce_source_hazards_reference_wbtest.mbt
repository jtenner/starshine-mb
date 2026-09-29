///|
fn cl_add_source_write_dest_read_interferences_reference(
  instrs : Array[@lib.Instruction],
  actions : Array[CLAction],
  effective : Array[Bool],
  types : Array[@lib.ValType],
  param_count : Int,
  interferences : CLBitMatrix,
) -> Unit {
  let (writers, readers) = cl_source_write_dest_read_active_flags(
    actions,
    effective,
    types.length(),
  )
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
  for source = param_count; source < types.length(); source = source + 1 {
    if !writers[source] {
      continue
    }
    let candidate_dests = cl_source_write_dest_read_candidate_dests(
      source, readers, types, interferences, first_effective_write, latest_get,
    )
    if candidate_dests.length() == 0 {
      continue
    }
    let hazards = cl_source_write_dest_read_hazards(
      instrs,
      effective,
      source,
      candidate_dests,
      types.length(),
    )
    for dest in candidate_dests {
      if hazards[dest] {
        cl_add_interference(interferences, source, dest)
      }
    }
  }
}
