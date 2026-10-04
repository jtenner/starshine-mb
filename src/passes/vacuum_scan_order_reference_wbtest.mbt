// Frozen 15255efd6 predicates: only the order of the unreachable query changes.

///|
fn vacuum_scan_order_reference_0(body : Array[@lib.Instruction]) -> UInt? {
  let non_nops : Array[@lib.Instruction] = []
  for instr in body {
    match instr {
      @lib.Nop => ()
      _ => non_nops.push(instr)
    }
  }
  if non_nops.length() != body.length() {
    return vacuum_scan_order_reference_0(non_nops)
  }
  if body.length() < 23 ||
    run_hot_pipeline_raw_vacuum_instrs_contain_unreachable(body) {
    return None
  }
  match body[body.length() - 1] {
    @lib.If(@lib.VoidBlockType, _, _) => ()
    _ => return None
  }
  if !run_hot_pipeline_raw_vacuum_final_if_has_else_or_top_level_outer_branch(
      body,
    ) {
    return None
  }
  let (slot_raw, increment_raw, root_raw, probe_raw, result_raw) = match
    (
      body[0],
      body[1],
      body[2],
      body[3],
      body[4],
      body[5],
      body[6],
      body[7],
      body[8],
      body[9],
      body[10],
      body[11],
      body[12],
      body[13],
      body[14],
    ) {
    (
      @lib.LocalGet(@lib.LocalIdx(slot_raw)),
      @lib.I32Load(_),
      @lib.I32Const(@lib.I32(1)),
      @lib.I32Add,
      @lib.LocalSet(@lib.LocalIdx(increment_raw)),
      @lib.LocalGet(@lib.LocalIdx(root_raw)),
      @lib.I32Load(_),
      @lib.LocalTee(@lib.LocalIdx(probe_raw)),
      @lib.Call(_),
      @lib.LocalGet(@lib.LocalIdx(next_probe_raw)),
      @lib.LocalGet(@lib.LocalIdx(next_increment_raw)),
      @lib.Call(_),
      @lib.LocalSet(@lib.LocalIdx(result_raw)),
      @lib.LocalGet(@lib.LocalIdx(release_probe_raw)),
      @lib.Call(_),
    ) if next_probe_raw == probe_raw &&
      release_probe_raw == probe_raw &&
      next_increment_raw == increment_raw =>
      (slot_raw, increment_raw, root_raw, probe_raw, result_raw)
    _ => return None
  }
  let mut saw_result_call = false
  let mut saw_condition_tee = false
  for idx = 15; idx + 1 < body.length(); idx = idx + 1 {
    match body[idx] {
      @lib.LocalGet(@lib.LocalIdx(raw)) if raw == result_raw =>
        if idx + 1 < body.length() && body[idx + 1] is @lib.Call(_) {
          saw_result_call = true
        }
      @lib.LocalTee(_) => saw_condition_tee = true
      @lib.LocalGet(@lib.LocalIdx(raw)) if raw == root_raw => ()
      @lib.LocalGet(_)
      | @lib.Call(_)
      | @lib.I32Const(_)
      | @lib.I32Eq
      | @lib.I32Eqz
      | @lib.I32And
      | @lib.I32WrapI64
      | @lib.I64Const(_)
      | @lib.I64Eq => ()
      _ => ()
    }
  }
  ignore(increment_raw)
  ignore(probe_raw)
  if saw_result_call && saw_condition_tee {
    Some(slot_raw)
  } else {
    None
  }
}

///|
fn vacuum_scan_order_reference_1(
  body : Array[@lib.Instruction],
  parent_body : Array[@lib.Instruction],
  start_idx : Int,
) -> Bool {
  let non_nops = run_hot_pipeline_raw_vacuum_strip_top_level_nops(body)
  if non_nops.length() < 13 ||
    run_hot_pipeline_raw_vacuum_instrs_contain_unreachable(non_nops) {
    return false
  }
  let (owner_raw, retained_raw, result_raw, dispatch_raw, then_body, else_body) = match
    (
      non_nops[0],
      non_nops[1],
      non_nops[2],
      non_nops[3],
      non_nops[4],
      non_nops[5],
      non_nops[6],
      non_nops[7],
      non_nops[8],
      non_nops[9],
      non_nops[10],
      non_nops[11],
      non_nops[12],
    ) {
    (
      @lib.LocalGet(@lib.LocalIdx(owner_raw)),
      @lib.I32Load(@lib.MemArg(_, _, @lib.U64(8UL))),
      @lib.LocalTee(@lib.LocalIdx(retained_raw)),
      @lib.Call(_),
      @lib.LocalGet(@lib.LocalIdx(read_retained_raw)),
      @lib.LocalGet(_),
      @lib.Call(_),
      @lib.LocalSet(@lib.LocalIdx(result_raw)),
      @lib.LocalGet(@lib.LocalIdx(release_retained_raw)),
      @lib.Call(_),
      @lib.LocalGet(@lib.LocalIdx(read_result_raw)),
      @lib.LocalTee(@lib.LocalIdx(dispatch_raw)),
      @lib.If(@lib.VoidBlockType, then_body, Some(else_body)),
    ) if read_retained_raw == retained_raw &&
      release_retained_raw == retained_raw &&
      read_result_raw == result_raw =>
      (owner_raw, retained_raw, result_raw, dispatch_raw, then_body, else_body)
    _ => return false
  }
  retained_raw != owner_raw &&
  result_raw != retained_raw &&
  dispatch_raw != retained_raw &&
  run_hot_pipeline_raw_vacuum_f5369_then_has_refcount_dispatch_branch(
    then_body, dispatch_raw,
  ) &&
  run_hot_pipeline_raw_vacuum_f5369_else_has_release_branch(
    else_body, dispatch_raw, owner_raw,
  ) &&
  run_hot_pipeline_raw_vacuum_body_has_f5369_allocation_path_continuation(
    parent_body, start_idx,
  )
}

///|
fn vacuum_scan_order_reference_2(body : Array[@lib.Instruction]) -> Bool {
  let non_nops : Array[@lib.Instruction] = []
  for instr in body {
    match instr {
      @lib.Nop => ()
      _ => non_nops.push(instr)
    }
  }
  if non_nops.length() < 13 ||
    run_hot_pipeline_raw_vacuum_instrs_contain_unreachable(non_nops) {
    return false
  }
  let (receiver_raw, start_value, call_raw, first_local_raw) = match
    (non_nops[0], non_nops[1], non_nops[2], non_nops[3]) {
    (
      @lib.LocalGet(@lib.LocalIdx(receiver_raw)),
      @lib.I32Const(@lib.I32(start_value)),
      @lib.Call(@lib.FuncIdx(call_raw)),
      @lib.LocalSet(@lib.LocalIdx(first_local_raw)),
    ) => (receiver_raw, start_value, call_raw, first_local_raw)
    _ => return false
  }
  let mut group_count = 1
  while group_count < 4 && (group_count + 1) * 4 + 5 <= non_nops.length() {
    let base = group_count * 4
    match
      (
        non_nops[base],
        non_nops[base + 1],
        non_nops[base + 2],
        non_nops[base + 3],
      ) {
      (
        @lib.LocalGet(@lib.LocalIdx(next_receiver_raw)),
        @lib.I32Const(@lib.I32(value)),
        @lib.Call(@lib.FuncIdx(next_call_raw)),
        @lib.LocalSet(@lib.LocalIdx(next_local_raw)),
      ) if next_receiver_raw == receiver_raw &&
        next_call_raw == call_raw &&
        value == start_value + group_count &&
        next_local_raw != first_local_raw => group_count = group_count + 1
      _ => break
    }
  }
  if group_count < 2 || non_nops.length() != group_count * 4 + 5 {
    return false
  }
  let tag_idx = group_count * 4
  match
    (
      non_nops[tag_idx],
      non_nops[tag_idx + 1],
      non_nops[tag_idx + 2],
      non_nops[tag_idx + 3],
      non_nops[tag_idx + 4],
    ) {
    (
      @lib.LocalGet(@lib.LocalIdx(tag_local_raw)),
      @lib.I32Load(_),
      @lib.I32Const(@lib.I32(tag_value)),
      @lib.I32Eq,
      @lib.If(@lib.VoidBlockType, _, _),
    ) =>
      tag_local_raw == first_local_raw &&
      (
        (group_count == 4 && start_value == 0 && tag_value == 20) ||
        (group_count == 2 && start_value == 4 && tag_value == 72)
      )
    _ => false
  }
}
