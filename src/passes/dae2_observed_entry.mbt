///|
// Only flat, non-terminating instructions qualify. Unknown control, tail calls
// and trapping producers retain the HOT dependency analysis.
fn dae2_flat_observed_arity(
  instruction : @lib.Instruction,
  graph : Dae2Graph,
  infos : Array[Dae2Function],
  indices : Array[@lib.TypeIdx],
  type_infos : Array[Int],
  exposure : Array[DaeFunctionExposure],
) -> Int {
  if dae_instr_is_droppable_pure_leaf(instruction) ||
    dae_instr_is_nontrapping_pure_unary(instruction) ||
    dae_instr_is_nontrapping_pure_binary(instruction) {
    return 0
  }
  match instruction {
    @lib.Nop
    | @lib.Drop
    | @lib.LocalSet(_)
    | @lib.LocalTee(_)
    | @lib.RefFunc(_) => 0
    @lib.GlobalSet(_) => 1
    @lib.I32Store(_)
    | @lib.I64Store(_)
    | @lib.F32Store(_)
    | @lib.F64Store(_)
    | @lib.I32Store8(_)
    | @lib.I32Store16(_)
    | @lib.I64Store8(_)
    | @lib.I64Store16(_)
    | @lib.I64Store32(_)
    | @lib.TableSet(_)
    | @lib.StructSet(_, _) => 2
    @lib.ArraySet(_) => 3
    @lib.Call(@lib.FuncIdx(raw)) => {
      let callee = raw.reinterpret_as_int()
      if callee < 0 || callee >= indices.length() {
        return -1
      }
      if dae2_boundary_is_pinned(
          graph, infos, callee, indices, type_infos, exposure,
        ) {
        infos[callee].params.length()
      } else {
        0
      }
    }
    @lib.CallIndirect(index, _) | @lib.CallRef(index) => {
      let slot = dae2_type_slot(index, 0)
      if slot < 0 || slot >= type_infos.length() {
        return -1
      }
      let callee = type_infos[slot]
      if callee < 0 || callee >= infos.length() {
        return -1
      }
      if dae2_boundary_is_pinned(
          graph, infos, callee, indices, type_infos, exposure,
        ) {
        infos[callee].params.length() + 1
      } else {
        1
      }
    }
    _ => -1
  }
}

///|
// A readonly entry parameter directly consumed by an observable instruction is
// already live. Seeding that fact before lifting can pin a private void boundary
// and its callers. Qualification covers the entire body before adding seeds;
// any parameter assignment or unsupported control retains the normal analysis.
fn dae2_pin_flat_observable_params(
  graph : Dae2Graph,
  infos : Array[Dae2Function],
  index : Int,
  body : Array[@lib.Instruction],
  indices : Array[@lib.TypeIdx],
  type_infos : Array[Int],
  exposure : Array[DaeFunctionExposure],
) -> Unit {
  let info = infos[index]
  if !info.results.is_empty() ||
    info.params.is_empty() ||
    dae2_boundary_is_pinned(graph, infos, index, indices, type_infos, exposure) {
    return
  }
  let observations : Array[Int] = []
  let mut written : Array[Bool]? = None
  for position = 0; position < body.length(); position = position + 1 {
    let instruction = body[position]
    let arity = dae2_flat_observed_arity(
      instruction, graph, infos, indices, type_infos, exposure,
    )
    if arity < 0 {
      return
    }
    if arity > 0 {
      observations.push(position)
      observations.push(arity)
    }
    match instruction {
      @lib.LocalSet(@lib.LocalIdx(raw)) | @lib.LocalTee(@lib.LocalIdx(raw)) => {
        let local = raw.reinterpret_as_int()
        if local >= 0 && local < info.params.length() {
          let flags = match written {
            Some(flags) => flags
            None => {
              let flags = Array::make(info.params.length(), false)
              written = Some(flags)
              flags
            }
          }
          flags[local] = true
        }
      }
      _ => ()
    }
  }
  for observation = 0
      observation < observations.length()
      observation = observation + 2 {
    let mut producer = observations[observation] - 1
    let mut remaining = observations[observation + 1]
    while producer >= 0 && remaining > 0 {
      let instruction = body[producer]
      if !dae_instr_is_droppable_pure_leaf(instruction) {
        break
      }
      match instruction {
        @lib.LocalGet(@lib.LocalIdx(raw)) => {
          let local = raw.reinterpret_as_int()
          let unassigned = match written {
            Some(flags) => local < 0 || local >= flags.length() || !flags[local]
            None => true
          }
          if local >= 0 && local < info.params.length() && unassigned {
            graph.observe(info.param_locations[local])
          }
        }
        _ => ()
      }
      producer = producer - 1
      remaining = remaining - 1
    }
  }
}
