///|
fn cl_structured_live_reference(
  actions : Array[CLAction],
  liveness : CLLiveness,
  types : Array[@lib.ValType],
  param_count : Int,
) -> CLBitMatrix {
  let total_locals = types.length()
  let interferences = CLBitMatrix::new(total_locals)
  let interner = CLValueInterner::new()
  let current_values = Array::make(total_locals, -1)
  for idx = 0; idx < total_locals; idx = idx + 1 {
    current_values[idx] = cl_initial_value(
      interner,
      idx,
      param_count,
      types[idx],
    )
  }

  for lhs = 0; lhs < param_count; lhs = lhs + 1 {
    for rhs = lhs + 1; rhs < param_count; rhs = rhs + 1 {
      cl_add_interference(interferences, lhs, rhs)
    }
  }
  for local_idx = param_count
      local_idx < total_locals
      local_idx = local_idx + 1 {
    if liveness.live_at_entry[local_idx] {
      for param = 0; param < param_count; param = param + 1 {
        cl_add_interference(interferences, local_idx, param)
      }
      for other = param_count; other < local_idx; other = other + 1 {
        if liveness.live_at_entry[other] &&
          current_values[local_idx] != current_values[other] {
          cl_add_interference(interferences, local_idx, other)
        }
      }
    }
  }

  let remaining_gets = Array::make(total_locals, 0)
  for action in actions {
    match action.kind {
      CLActionKind::Get => remaining_gets[action.local_idx] += 1
      _ => ()
    }
  }
  let live = liveness.live_at_entry.copy()
  let mut live_count = 0
  for is_live in live {
    if is_live {
      live_count += 1
    }
  }
  for action_idx = 0; action_idx < actions.length(); action_idx = action_idx + 1 {
    let action = actions[action_idx]
    match action.kind {
      CLActionKind::Get => {
        if !live[action.local_idx] {
          live[action.local_idx] = true
          live_count += 1
        }
        if live_count > 1 {
          for other = 0; other < total_locals; other = other + 1 {
            if other != action.local_idx &&
              live[other] &&
              current_values[other] != current_values[action.local_idx] {
              cl_add_interference(interferences, action.local_idx, other)
            }
          }
        }
        remaining_gets[action.local_idx] -= 1
        if remaining_gets[action.local_idx] == 0 && live[action.local_idx] {
          live[action.local_idx] = false
          live_count -= 1
        }
      }
      CLActionKind::Set | CLActionKind::Tee => {
        let new_value = if cl_source_is_explicit_default(
            action.source,
            types[action.local_idx],
          ) {
          interner.intern(
            "default:\{@debug.to_string(types[action.local_idx])}",
          )
        } else {
          cl_value_for_source(action.source, current_values, interner)
        }
        if liveness.effective[action_idx] {
          if live_count > 0 {
            for other = 0; other < total_locals; other = other + 1 {
              if other != action.local_idx &&
                live[other] &&
                current_values[other] != new_value {
                cl_add_interference(interferences, action.local_idx, other)
              }
            }
          }
          if !live[action.local_idx] {
            live_count += 1
          }
          live[action.local_idx] = true
        } else {
          if live[action.local_idx] {
            live_count -= 1
          }
          live[action.local_idx] = false
        }
        current_values[action.local_idx] = new_value
      }
    }
  }
  interferences
}
