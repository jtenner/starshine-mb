///|
// Pack scalar parameter and result counts in two bits.
fn dae2_first_input_reference_loop_shape(
  bt : @lib.BlockType,
  context : @ir.HotModuleContext?,
) -> Int32 {
  match bt {
    @lib.VoidBlockType => 0
    @lib.ValTypeBlockType(_) => 1
    @lib.TypeIdxBlockType(index) =>
      match context {
        Some(context) =>
          match @ir.hot_module_resolve_type_func_type(context, index) {
            Some(@lib.FuncType(params, results)) =>
              if params.length() <= 1 && results.length() <= 1 {
                2 * params.length() + results.length()
              } else {
                -1
              }
            None => -1
          }
        None => -1
      }
  }
}

///|
// Forward labels and scalar loops share the established leaf contracts.
// Handlers, wider control signatures and virtual dead tails stay HOT.
fn dae2_first_input_reference_forward_instruction_count(
  instructions : Array[@lib.Instruction],
  context : @ir.HotModuleContext?,
) -> Int32 {
  let limit = (2147483647 - 64) / 8
  let mut count = 0
  for instr in instructions {
    let mut nested = 0
    match instr {
      @lib.Block(bt, @lib.Expr(body)) => {
        if dae2_raw_control_arity(bt) < 0 {
          return -1
        }
        nested = dae2_first_input_reference_forward_instruction_count(
          body, context,
        )
        if nested < 0 {
          return -1
        }
      }
      @lib.Loop(bt, @lib.Expr(body)) => {
        if dae2_first_input_reference_loop_shape(bt, context) < 0 {
          return -1
        }
        nested = dae2_first_input_reference_forward_instruction_count(
          body, context,
        )
        if nested < 0 {
          return -1
        }
      }
      @lib.If(bt, yes, no) => {
        if dae2_raw_control_arity(bt) < 0 {
          return -1
        }
        nested = dae2_first_input_reference_forward_instruction_count(
          yes, context,
        )
        if nested < 0 {
          return -1
        }
        match no {
          Some(body) => {
            let other = dae2_first_input_reference_forward_instruction_count(
              body, context,
            )
            if other < 0 {
              return -1
            }
            nested += other
          }
          None => if dae2_raw_control_arity(bt) != 0 { return -1 }
        }
      }
      @lib.Nop
      | @lib.Drop
      | @lib.LocalSet(_)
      | @lib.LocalTee(_)
      | @lib.Call(_)
      | @lib.CallIndirect(_, _)
      | @lib.CallRef(_)
      | @lib.Return
      | @lib.Unreachable
      | @lib.Br(_)
      | @lib.BrIf(_) => ()
      @lib.BrTable(targets, _) => nested = targets.length()
      _ =>
        if dae2_raw_pure_arity(instr) < 0 &&
          dae2_raw_observer_arity(instr) < 0 &&
          dae2_raw_observed_producer_arity(instr, context) < 0 {
          return -1
        }
    }
    if nested > limit - count - 1 {
      return -1
    }
    count += nested + 1
  }
  count
}

///|
priv struct Dae2FirstInputReferenceFrame {
  undo_mark : Int32
  arity : Int32
  mut value : Int32
  mut is_loop : Bool
  mut label_arity : Int32
  mut loop_locals : Dae2RawArmWrites?
  mut backedge_epoch : Int32
  mut event_cursor : Int32
  mut entries : Dae2RawArmWrites?
  mut incoming : Dae2RawArmWrites?
  mut reachable : Bool
  mut branch_epoch : Int32
  mut incoming_epoch : Int32
}

///|
fn Dae2FirstInputReferenceFrame::new(
  state : Dae2RawControlState,
  event_cursor : Int32,
  arity : Int32,
) -> Dae2FirstInputReferenceFrame {
  let value = if arity == 0 {
    -1
  } else {
    let location = state.plan.base + state.plan.count
    state.plan.count += 1
    location
  }
  {
    undo_mark: state.undo_locals.length(),
    arity,
    value,
    is_loop: false,
    label_arity: arity,
    loop_locals: None,
    backedge_epoch: -1,
    event_cursor,
    entries: None,
    incoming: None,
    reachable: false,
    branch_epoch: -1,
    incoming_epoch: -1,
  }
}

///|
priv struct Dae2FirstInputReferenceState {
  state : Dae2RawControlState
  frames : Array[Dae2FirstInputReferenceFrame]
  // Monotonic discovery includes source writes and synthetic loop entries.
  // Undo rewinds per arm; source-write provenance remains in the plan only.
  write_entries : Array[Int32]
  write_locals : Array[Int32]
  mut branch_epoch : Int32
  mut function_branch_epoch : Int32
  mut state_epoch : Int32
  mut remaining_work : Int32
  // Allocated only after a repeated multi-lane incoming merge finishes.
  mut changed_locals : Array[Int32]?
  mut change_base_epoch : Int32
}

///|
fn Dae2FirstInputReferenceState::new(
  state : Dae2RawControlState,
  work : Int32,
) -> Dae2FirstInputReferenceState {
  {
    state,
    frames: [],
    write_entries: [],
    write_locals: [],
    branch_epoch: 0,
    function_branch_epoch: -1,
    state_epoch: 0,
    remaining_work: work,
    changed_locals: None,
    change_base_epoch: -1,
  }
}

///|
fn Dae2FirstInputReferenceState::spend(
  self : Dae2FirstInputReferenceState,
  work : Int32,
) -> Bool {
  if work < 0 || self.remaining_work < work {
    self.remaining_work = -1
    false
  } else {
    self.remaining_work -= work
    true
  }
}

///|
fn Dae2FirstInputReferenceState::changed(
  self : Dae2FirstInputReferenceState,
  local~ : Int32 = -1,
) -> Unit {
  if self.state_epoch == 2147483647 {
    self.remaining_work = -1
  } else {
    self.state_epoch += 1
    match self.changed_locals {
      Some(changes) =>
        if local >= 0 && local < self.state.locals.length() {
          // Every mutation already has its source-write/restore/apply/phi
          // work charge. This adds one bounded entry to that same event.
          changes.push(local)
        } else {
          // Private callers without exact mutation provenance keep the old
          // full scan. Never use an incomplete journal as a state proof.
          self.changed_locals = None
          self.change_base_epoch = -1
        }
      None => ()
    }
  }
}

///|
fn Dae2FirstInputReferenceState::push_frame(
  self : Dae2FirstInputReferenceState,
  arity : Int32,
) -> Dae2FirstInputReferenceFrame {
  let frame = Dae2FirstInputReferenceFrame::new(
    self.state,
    self.write_entries.length(),
    arity,
  )
  self.frames.push(frame)
  self.state.arm_depth += 1
  frame
}

///|
fn Dae2FirstInputReferenceState::restore(
  self : Dae2FirstInputReferenceState,
  mark : Int32,
) -> Unit {
  let state = self.state
  while state.undo_locals.length() > mark {
    if !self.spend(1) {
      return
    }
    let local = state.undo_locals.pop().unwrap()
    let value = state.undo_values.pop().unwrap()
    if state.locals[local] != value {
      state.locals[local] = value
      self.changed(local~)
    }
  }
}

///|
fn Dae2FirstInputReferenceState::merge_incoming_local(
  self : Dae2FirstInputReferenceState,
  frame : Dae2FirstInputReferenceFrame,
  entries : Dae2RawArmWrites,
  incoming : Dae2RawArmWrites,
  local : Int32,
  incoming_sets~ : Array[Int32]? = None,
) -> Bool {
  let state = self.state
  if !self.spend(1) {
    return false
  }
  let previous = incoming.values.get(local)
  let value = if frame.reachable {
    state.plan.join(
      previous.unwrap_or(entries.values.get(local).unwrap()),
      state.locals[local],
    )
  } else {
    state.locals[local]
  }
  if previous is None {
    if !self.spend(1) {
      return false
    }
    incoming.order.push(local)
  }
  match previous {
    Some(previous_value) if previous_value == value => ()
    _ => {
      match incoming_sets {
        Some(count) => count[0] += 1
        None => ()
      }
      incoming.values.set(local, value)
    }
  }
  true
}

///|
fn Dae2FirstInputReferenceState::merge_incoming(
  self : Dae2FirstInputReferenceState,
  frame : Dae2FirstInputReferenceFrame,
  incoming_sets~ : Array[Int32]? = None,
) -> Unit {
  if frame.incoming_epoch == self.state_epoch {
    return
  }
  // Each logged write increments state_epoch once. Restores and incoming
  // frame applications increment it without adding a write event. When both
  // differences are exactly one, every other incoming local is unchanged.
  let one_changed_local = if frame.incoming is Some(_) &&
    self.write_entries.length() - frame.event_cursor == 1 &&
    self.state_epoch - frame.incoming_epoch == 1 {
    self.write_locals[frame.event_cursor]
  } else {
    -1
  }
  let had_incoming = frame.incoming is Some(_)
  let mut activate_changes = false
  if frame.event_cursor < self.write_entries.length() {
    let entries = match frame.entries {
      Some(entries) => entries
      None => {
        if !self.spend(1) {
          return
        }
        let entries = Dae2RawArmWrites::new()
        frame.entries = Some(entries)
        entries
      }
    }
    while frame.event_cursor < self.write_entries.length() {
      if !self.spend(1) {
        return
      }
      let event = frame.event_cursor
      frame.event_cursor += 1
      let local = self.write_locals[event]
      if entries.values.get(local) is None {
        if !self.spend(1) {
          return
        }
        entries.order.push(local)
        entries.values.set(local, self.write_entries[event])
      }
    }
  }
  match frame.entries {
    Some(entries) => {
      let incoming = match frame.incoming {
        Some(incoming) => incoming
        None => {
          if !self.spend(1) {
            return
          }
          let incoming = Dae2RawArmWrites::new()
          frame.incoming = Some(incoming)
          incoming
        }
      }
      let changes = self.changed_locals
      let change_start = if had_incoming &&
        one_changed_local < 0 &&
        self.change_base_epoch >= 0 &&
        frame.incoming_epoch >= self.change_base_epoch {
        frame.incoming_epoch - self.change_base_epoch
      } else {
        -1
      }
      let use_changes = match changes {
        Some(changes) if change_start >= 0 && change_start <= changes.length() => {
          let count = changes.length() - change_start
          // At most eight current reads, 28 preceding-ID comparisons and
          // eight lane merges. Every operation below keeps its work charge.
          // Use it only when this worst case is cheaper than the old scan.
          count > 0 &&
          count <= 8 &&
          count * (count + 3) / 2 < entries.order.length()
        }
        _ => false
      }
      if use_changes {
        let changes = changes.unwrap()
        for event in change_start..<changes.length() {
          if !self.spend(1) {
            return
          }
          let local = changes[event]
          let mut duplicate = false
          for earlier in change_start..<event {
            if !self.spend(1) {
              return
            }
            if changes[earlier] == local {
              duplicate = true
              break
            }
          }
          if duplicate {
            continue
          }
          if entries.values.get(local) is Some(_) &&
            !self.merge_incoming_local(
              frame,
              entries,
              incoming,
              local,
              incoming_sets~,
            ) {
            return
          }
        }
      } else {
        let lanes = if one_changed_local >= 0 {
          1
        } else {
          entries.order.length()
        }
        for lane in 0..<lanes {
          let local = if one_changed_local >= 0 {
            one_changed_local
          } else {
            entries.order[lane]
          }
          if !self.merge_incoming_local(
              frame,
              entries,
              incoming,
              local,
              incoming_sets~,
            ) {
            return
          }
        }
        // First input, unchanged input and the exact one-write fast path
        // allocate nothing. Start only after real repeated multi-lane work.
        activate_changes = had_incoming &&
          one_changed_local < 0 &&
          entries.order.length() > 1 &&
          self.changed_locals is None
      }
    }
    None => ()
  }
  frame.reachable = true
  frame.incoming_epoch = self.state_epoch
  if activate_changes {
    // One empty vector per production attempt is fixed startup work covered
    // by the existing 64-unit reserve, like the plan and undo vectors. All
    // repeated event reads, dedup probes and lane merges stay charged above.
    self.changed_locals = Some([])
    self.change_base_epoch = self.state_epoch
  }
}

///|
fn Dae2FirstInputReferenceState::finish_frame(
  self : Dae2FirstInputReferenceState,
  frame : Dae2FirstInputReferenceFrame,
) -> Bool {
  self.restore(frame.undo_mark)
  if self.remaining_work < 0 {
    return false
  }
  ignore(self.frames.pop())
  self.state.arm_depth -= 1
  if frame.reachable {
    match frame.incoming {
      Some(incoming) =>
        for local in incoming.order {
          if !self.spend(1) {
            return false
          }
          let value = incoming.values.get(local).unwrap()
          if self.state.locals[local] != value {
            self.state.assign(local, value)
            self.changed(local~)
          }
        }
      None => ()
    }
    if frame.arity > 0 {
      self.state.stack.push(frame.value)
    }
  }
  frame.reachable
}

///|
fn Dae2FirstInputReferenceState::arm(
  self : Dae2FirstInputReferenceState,
  frame : Dae2FirstInputReferenceFrame,
  instructions : Array[@lib.Instruction],
  floor : Int32,
) -> Bool {
  match self.body(instructions, floor, frame.arity) {
    Some(true) => {
      if frame.arity > 0 {
        self.state.plan.edge(frame.value, self.state.stack.pop().unwrap())
      }
      self.merge_incoming(frame)
    }
    Some(false) => ()
    None => return false
  }
  self.state.stack.truncate(floor)
  self.restore(frame.undo_mark)
  self.remaining_work >= 0
}

///|
fn Dae2FirstInputReferenceState::target_arity(
  self : Dae2FirstInputReferenceState,
  label : @lib.LabelIdx,
) -> Int32 {
  let @lib.LabelIdx(raw) = label
  let depth = raw.reinterpret_as_int()
  let count = self.frames.length()
  if depth < 0 || depth > count {
    -1
  } else if depth == count {
    self.state.result_count
  } else {
    self.frames[count - depth - 1].label_arity
  }
}

///|
fn Dae2FirstInputReferenceState::branch_to(
  self : Dae2FirstInputReferenceState,
  label : @lib.LabelIdx,
  start : Int32,
  arity : Int32,
) -> Bool {
  if self.target_arity(label) != arity {
    return false
  }
  let @lib.LabelIdx(raw) = label
  let depth = raw.reinterpret_as_int()
  let state = self.state
  if depth == self.frames.length() {
    if self.function_branch_epoch == self.branch_epoch {
      return true
    }
    self.function_branch_epoch = self.branch_epoch
    if !self.spend(arity) {
      return false
    }
    // An implicit function-label branch pins the whole result, unlike Return.
    state.plan.observations.push(state.result_location)
    for slot in start..<(start + arity) {
      state.plan.edge(state.result_location, state.stack[slot])
    }
    return true
  }
  let frame = self.frames[self.frames.length() - depth - 1]
  // Repeated table labels share one exit state and one control observation.
  if frame.branch_epoch == self.branch_epoch {
    return true
  }
  frame.branch_epoch = self.branch_epoch
  if !self.spend(arity) {
    return false
  }
  state.plan.observations.push(frame.value)
  for slot in start..<(start + arity) {
    if !frame.is_loop {
      state.plan.edge(frame.value, state.stack[slot])
    }
  }
  if frame.is_loop {
    if frame.backedge_epoch != self.state_epoch {
      match frame.loop_locals {
        Some(locals) =>
          for local in locals.order {
            if !self.spend(1) {
              return false
            }
            state.plan.edge(
              locals.values.get(local).unwrap(),
              state.locals[local],
            )
          }
        None => ()
      }
      frame.backedge_epoch = self.state_epoch
    }
  } else {
    self.merge_incoming(frame)
  }
  self.remaining_work >= 0
}

///|
fn Dae2FirstInputReferenceState::collect_loop_writes(
  self : Dae2FirstInputReferenceState,
  instructions : Array[@lib.Instruction],
  writes : Dae2RawArmWrites,
) -> Bool {
  for instr in instructions {
    if !self.spend(1) {
      return false
    }
    match instr {
      @lib.LocalSet(@lib.LocalIdx(raw)) | @lib.LocalTee(@lib.LocalIdx(raw)) => {
        let local = raw.reinterpret_as_int()
        if local < 0 || local >= self.state.locals.length() {
          return false
        }
        if writes.values.get(local) is None {
          if !self.spend(1) {
            return false
          }
          writes.order.push(local)
          writes.values.set(local, -1)
        }
      }
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        if !self.collect_loop_writes(body, writes) {
          return false
        }
      @lib.If(_, yes, no) => {
        if !self.collect_loop_writes(yes, writes) {
          return false
        }
        match no {
          Some(body) =>
            if !self.collect_loop_writes(body, writes) {
              return false
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  true
}

///|
fn Dae2FirstInputReferenceState::prepare_loop(
  self : Dae2FirstInputReferenceState,
  frame : Dae2FirstInputReferenceFrame,
  body : Array[@lib.Instruction],
) -> Bool {
  if !self.spend(1) {
    return false
  }
  let writes = Dae2RawArmWrites::new()
  if !self.collect_loop_writes(body, writes) {
    return false
  }
  for local in writes.order {
    // Each sparse phi names the entry definition and the definitions at every
    // backedge. Synthetic entry writes must also reach enclosing exit frames.
    if !self.spend(4) {
      return false
    }
    let old = self.state.locals[local]
    let phi = self.state.plan.base + self.state.plan.count
    self.state.plan.count += 1
    self.state.plan.edge(phi, old)
    writes.values.set(local, phi)
    self.write_locals.push(local)
    self.write_entries.push(old)
    self.state.assign(local, phi)
    self.changed(local~)
  }
  frame.loop_locals = Some(writes)
  self.remaining_work >= 0
}

///|
fn Dae2FirstInputReferenceState::body(
  self : Dae2FirstInputReferenceState,
  instructions : Array[@lib.Instruction],
  floor : Int32,
  result_count : Int32,
) -> Bool? {
  let state = self.state
  let stack = state.stack
  let mut falls_through = true
  for instr in instructions {
    if !falls_through {
      // HOT Drop has no DAE2 child demand, even when a nonreturning control
      // leaves a concrete result slot. These tails add no writes or exits.
      match instr {
        @lib.Drop | @lib.Nop | @lib.Unreachable => continue
        _ => return None
      }
    }
    match instr {
      @lib.Loop(bt, @lib.Expr(body)) => {
        let shape = dae2_first_input_reference_loop_shape(bt, state.context)
        if shape < 0 {
          return None
        }
        let params = shape / 2
        let results = shape % 2
        if stack.length() - floor < params {
          return None
        }
        let loop_floor = stack.length() - params
        let frame = self.push_frame(results)
        frame.is_loop = true
        frame.label_arity = params
        if frame.value < 0 && params > 0 {
          frame.value = state.plan.base + state.plan.count
          state.plan.count += 1
        }
        if params > 0 {
          state.plan.edge(frame.value, stack[loop_floor])
        }
        if !self.prepare_loop(frame, body) || !self.arm(frame, body, loop_floor) {
          return None
        }
        falls_through = self.finish_frame(frame)
      }
      @lib.Block(bt, @lib.Expr(body)) => {
        let arity = dae2_raw_control_arity(bt)
        if arity < 0 {
          return None
        }
        let frame = self.push_frame(arity)
        if !self.arm(frame, body, stack.length()) {
          return None
        }
        falls_through = self.finish_frame(frame)
      }
      @lib.If(bt, yes, no) => {
        let arity = dae2_raw_control_arity(bt)
        if arity < 0 || stack.length() == floor {
          return None
        }
        state.plan.observations.push(stack.pop().unwrap())
        let arm_floor = stack.length()
        let frame = self.push_frame(arity)
        if !self.arm(frame, yes, arm_floor) {
          return None
        }
        match no {
          Some(body) => if !self.arm(frame, body, arm_floor) { return None }
          None => {
            if arity != 0 {
              return None
            }
            self.merge_incoming(frame)
          }
        }
        falls_through = self.finish_frame(frame)
      }
      @lib.Br(label) | @lib.BrIf(label) => {
        let conditional = instr is @lib.BrIf(_)
        if conditional {
          if stack.length() == floor {
            return None
          }
          state.plan.observations.push(stack.pop().unwrap())
        }
        let arity = self.target_arity(label)
        if arity < 0 || stack.length() - floor < arity {
          return None
        }
        let start = stack.length() - arity
        if !self.spend(arity) {
          return None
        }
        for slot in start..<stack.length() {
          state.plan.observations.push(stack[slot])
        }
        self.branch_epoch += 1
        if !self.branch_to(label, start, arity) {
          return None
        }
        falls_through = conditional
      }
      @lib.BrTable(targets, default_target) => {
        if stack.length() == floor {
          return None
        }
        state.plan.observations.push(stack.pop().unwrap())
        let arity = self.target_arity(default_target)
        // HOT keeps extra concrete stack values beside br_table in its region
        // roots. Keep that existing demand on HOT until it has a raw model.
        if arity < 0 || stack.length() - floor != arity {
          return None
        }
        let start = stack.length() - arity
        if !self.spend(arity) {
          return None
        }
        for slot in start..<stack.length() {
          state.plan.observations.push(stack[slot])
        }
        self.branch_epoch += 1
        for target in targets {
          if !self.branch_to(target, start, arity) {
            return None
          }
        }
        if !self.branch_to(default_target, start, arity) {
          return None
        }
        falls_through = false
      }
      @lib.Return => {
        if stack.length() - floor < state.result_count {
          return None
        }
        let start = stack.length() - state.result_count
        for slot in start..<stack.length() {
          state.plan.edge(state.result_location, stack[slot])
        }
        falls_through = false
      }
      @lib.Unreachable => {
        if stack.length() != floor {
          return None
        }
        falls_through = false
      }
      _ => {
        let write_local = match instr {
          @lib.LocalSet(@lib.LocalIdx(raw))
          | @lib.LocalTee(@lib.LocalIdx(raw)) => {
            let local = raw.reinterpret_as_int()
            if local < 0 || local >= state.locals.length() {
              return None
            }
            local
          }
          _ => -1
        }
        let old_value = if write_local >= 0 {
          state.locals[write_local]
        } else {
          -1
        }
        if !state.leaf(instr, floor) {
          return None
        }
        if write_local >= 0 {
          if !self.spend(1) {
            return None
          }
          self.write_locals.push(write_local)
          self.write_entries.push(old_value)
          self.changed(local=write_local)
        }
      }
    }
    if self.remaining_work < 0 {
      return None
    }
    if !falls_through {
      stack.truncate(floor)
    }
  }
  if !falls_through {
    Some(false)
  } else if stack.length() == floor + result_count {
    Some(true)
  } else {
    None
  }
}

///|
fn dae2_first_input_reference_forward_dependency_plan(
  graph : Dae2Graph,
  infos : Array[Dae2Function],
  index : Int32,
  type_infos : Array[Int32],
  body : @lib.Func,
  intrinsic_imports : Array[Bool]?,
  context : @ir.HotModuleContext?,
  work_left~ : Array[Int32]? = None,
) -> Dae2RawPlan? {
  let @lib.Func(locals, @lib.Expr(instructions)) = body
  let instruction_count = dae2_first_input_reference_forward_instruction_count(
    instructions, context,
  )
  if instruction_count < 0 {
    return None
  }
  // Count table labels as input too. Bound map discovery, stored map lanes,
  // incoming joins, restores/applications and branch payload work by the body
  // size. Exhaustion discards this uncommitted plan and keeps full HOT analysis.
  let work = 64 + 8 * instruction_count
  let plan = Dae2RawPlan::new(graph.used.length())
  let state = Dae2FirstInputReferenceState::new(
    Dae2RawControlState::new(
      plan,
      infos,
      index,
      type_infos,
      locals.length(),
      intrinsic_imports,
      context,
    ),
    work,
  )
  let outcome = state.body(instructions, 0, infos[index].results.length())
  match work_left {
    Some(remaining) => remaining[0] = state.remaining_work
    None => ()
  }
  match outcome {
    Some(_) => ()
    None => return None
  }
  for source in state.state.stack {
    plan.edge(infos[index].result_location, source)
  }
  Some(plan)
}
