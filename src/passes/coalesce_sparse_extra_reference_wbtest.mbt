///|
fn cl_add_structured_write_live_interferences_reference(
  write_live_hazards : CLBitMatrix,
  types : Array[@lib.ValType],
  param_count : Int,
  interferences : CLBitMatrix,
) -> Unit {
  for source = param_count; source < types.length(); source = source + 1 {
    for dest = 0; dest < types.length(); dest = dest + 1 {
      if source != dest &&
        source < write_live_hazards.length() &&
        dest < write_live_hazards.length() &&
        cl_bit_matrix_get(write_live_hazards, source, dest) &&
        types[source] == types[dest] {
        cl_add_interference(interferences, source, dest)
      }
    }
  }
}

///|
fn cl_add_plain_live_interferences_reference(
  actions : Array[CLAction],
  liveness : CLLiveness,
  interferences : CLBitMatrix,
) -> Unit {
  let total_locals = interferences.length()
  let remaining_gets = Array::make(total_locals, 0)
  for action in actions {
    match action.kind {
      CLActionKind::Get => remaining_gets[action.local_idx] += 1
      _ => ()
    }
  }
  let live = liveness.live_at_entry.copy()
  for action_idx = 0; action_idx < actions.length(); action_idx = action_idx + 1 {
    let action = actions[action_idx]
    match action.kind {
      CLActionKind::Get => {
        live[action.local_idx] = true
        for other = 0; other < total_locals; other = other + 1 {
          if other != action.local_idx && live[other] {
            cl_add_interference(interferences, action.local_idx, other)
          }
        }
        remaining_gets[action.local_idx] -= 1
        if remaining_gets[action.local_idx] == 0 {
          live[action.local_idx] = false
        }
      }
      CLActionKind::Set | CLActionKind::Tee => {
        for other = 0; other < total_locals; other = other + 1 {
          if other != action.local_idx && live[other] {
            cl_add_interference(interferences, action.local_idx, other)
          }
        }
        if liveness.effective[action_idx] {
          live[action.local_idx] = true
        } else {
          live[action.local_idx] = false
        }
      }
    }
  }
}
