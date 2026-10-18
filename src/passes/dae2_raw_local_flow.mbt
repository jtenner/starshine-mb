///|
// Raw local flow is a graph of immutable block exits. Local reads request only
// the reaching definitions they need; joins never copy the complete local state.
priv struct Dae2RawLocalBlock {
  predecessors : Array[Int32]
  mut writes : @hashmap.HashMap[Int32, Int32]?
  mut entries : @hashmap.HashMap[Int32, Int32]?
  mut frozen : Bool
}

///|
fn Dae2RawLocalBlock::new() -> Dae2RawLocalBlock {
  { predecessors: [], writes: None, entries: None, frozen: false, }
}

///|
priv struct Dae2RawLocalFrame {
  target : Int32
  exit : Int32
  value : Int32
  arity : Int32
  label_arity : Int32
  is_loop : Bool
  mut branch_epoch : Int32
}

///|
fn Dae2RawLocalFrame::new(
  target : Int32,
  exit : Int32,
  value : Int32,
  arity : Int32,
  label_arity : Int32,
  is_loop : Bool,
) -> Dae2RawLocalFrame {
  { target, exit, value, arity, label_arity, is_loop, branch_epoch: -1, }
}

///|
priv struct Dae2RawLocalFlow {
  state : Dae2RawControlState
  param_locations : Array[Int32]
  blocks : Array[Dae2RawLocalBlock]
  frames : Array[Dae2RawLocalFrame]
  query_blocks : Array[Int32]
  query_locals : Array[Int32]
  query_symbols : Array[Int32]
  mut current : Int32
  mut remaining_work : Int32
  mut branch_epoch : Int32
  mut function_branch_epoch : Int32
}

///|
fn Dae2RawLocalFlow::new(
  state : Dae2RawControlState,
  param_locations : Array[Int32],
  work : Int32,
) -> Dae2RawLocalFlow {
  {
    state,
    param_locations,
    blocks: [Dae2RawLocalBlock::new()],
    frames: [],
    query_blocks: [],
    query_locals: [],
    query_symbols: [],
    current: 0,
    remaining_work: work,
    branch_epoch: 0,
    function_branch_epoch: -1,
  }
}

///|
fn Dae2RawLocalFlow::spend(self : Dae2RawLocalFlow, work : Int32) -> Bool {
  if work < 0 || self.remaining_work < work {
    self.remaining_work = -1
    false
  } else {
    self.remaining_work -= work
    true
  }
}

///|
fn Dae2RawLocalFlow::block(self : Dae2RawLocalFlow) -> Int32 {
  if !self.spend(1) {
    return -1
  }
  let index = self.blocks.length()
  self.blocks.push(Dae2RawLocalBlock::new())
  index
}

///|
fn Dae2RawLocalFlow::connect(self : Dae2RawLocalFlow, target : Int32) -> Bool {
  if !self.spend(1) || target < 0 {
    return false
  }
  self.blocks[self.current].frozen = true
  let predecessors = self.blocks[target].predecessors
  if predecessors.last() != Some(self.current) {
    predecessors.push(self.current)
  }
  true
}

///|
fn Dae2RawLocalFlow::entry(
  self : Dae2RawLocalFlow,
  block : Int32,
  local_id : Int32,
) -> Int32 {
  if block == 0 {
    return if local_id < self.param_locations.length() {
      self.param_locations[local_id]
    } else {
      -1
    }
  }
  let row = self.blocks[block]
  let entries = match row.entries {
    Some(entries) => entries
    None => {
      let entries = @hashmap.new()
      row.entries = Some(entries)
      entries
    }
  }
  match entries.get(local_id) {
    Some(value) => value
    None => {
      if !self.spend(1) {
        return -1
      }
      let value = self.state.plan.base + self.state.plan.count
      self.state.plan.count += 1
      entries.set(local_id, value)
      self.query_blocks.push(block)
      self.query_locals.push(local_id)
      self.query_symbols.push(value)
      value
    }
  }
}

///|
fn Dae2RawLocalFlow::read(
  self : Dae2RawLocalFlow,
  block : Int32,
  local_id : Int32,
) -> Int32 {
  match self.blocks[block].writes {
    Some(writes) =>
      match writes.get(local_id) {
        Some(value) => return value
        None => ()
      }
    None => ()
  }
  self.entry(block, local_id)
}

///|
fn Dae2RawLocalFlow::write(
  self : Dae2RawLocalFlow,
  local_id : Int32,
  value : Int32,
) -> Bool {
  if !self.spend(1) {
    return false
  }
  if self.blocks[self.current].frozen {
    let next = self.block()
    if next < 0 || !self.connect(next) {
      return false
    }
    self.current = next
  }
  let block = self.blocks[self.current]
  let writes = match block.writes {
    Some(writes) => writes
    None => {
      let writes = @hashmap.new()
      block.writes = Some(writes)
      writes
    }
  }
  writes.set(local_id, value)
  true
}

///|
fn Dae2RawLocalFlow::resolve(self : Dae2RawLocalFlow) -> Bool {
  let mut query = 0
  while query < self.query_blocks.length() {
    let block = self.query_blocks[query]
    let local_id = self.query_locals[query]
    let value = self.query_symbols[query]
    query += 1
    // This leaf workspace never restores local values. Every source write
    // installs its fresh plan location (>= base); untouched entries still hold
    // a parameter location (< base) or the default-value sentinel. Check this
    // only after the complete body, when loop backedges and all writes exist.
    if self.state.locals[local_id] < self.state.plan.base {
      if local_id < self.param_locations.length() {
        self.state.plan.edge(value, self.param_locations[local_id])
      }
      continue
    }
    for predecessor in self.blocks[block].predecessors {
      if !self.spend(1) {
        return false
      }
      let source = self.read(predecessor, local_id)
      if self.remaining_work < 0 {
        return false
      }
      self.state.plan.edge(value, source)
    }
  }
  true
}

///|
fn Dae2RawLocalFlow::target_arity(
  self : Dae2RawLocalFlow,
  label : @lib.LabelIdx,
) -> Int32 {
  let @lib.LabelIdx(raw) = label
  let depth = raw.reinterpret_as_int()
  if depth < 0 || depth > self.frames.length() {
    return -1
  }
  if depth == self.frames.length() {
    self.state.result_count
  } else {
    self.frames[self.frames.length() - depth - 1].label_arity
  }
}

///|
fn Dae2RawLocalFlow::branch(
  self : Dae2RawLocalFlow,
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
    state.plan.observations.push(state.result_location)
    for slot in start..<(start + arity) {
      state.plan.edge(state.result_location, state.stack[slot])
    }
    self.blocks[self.current].frozen = true
    return true
  }
  let frame = self.frames[self.frames.length() - depth - 1]
  if frame.branch_epoch == self.branch_epoch {
    return true
  }
  frame.branch_epoch = self.branch_epoch
  if !self.spend(arity) {
    return false
  }
  state.plan.observations.push(frame.value)
  if !frame.is_loop {
    for slot in start..<(start + arity) {
      state.plan.edge(frame.value, state.stack[slot])
    }
  }
  self.connect(frame.target)
}

///|
fn Dae2RawLocalFlow::arm(
  self : Dae2RawLocalFlow,
  frame : Dae2RawLocalFrame,
  body : Array[@lib.Instruction],
  floor : Int32,
) -> Bool {
  match self.body(body, floor, frame.arity) {
    None => return false
    Some(true) => {
      if frame.arity > 0 {
        self.state.plan.edge(frame.value, self.state.stack.pop().unwrap())
      }
      if !self.connect(frame.exit) {
        return false
      }
    }
    Some(false) => ()
  }
  self.state.stack.truncate(floor)
  true
}

///|
fn Dae2RawLocalFlow::body(
  self : Dae2RawLocalFlow,
  instructions : Array[@lib.Instruction],
  floor : Int32,
  result_count : Int32,
) -> Bool? {
  let state = self.state
  let stack = state.stack
  let mut falls_through = true
  for instr in instructions {
    if !falls_through {
      match instr {
        @lib.Drop | @lib.Nop | @lib.Unreachable => continue
        _ => return None
      }
    }
    match instr {
      @lib.Block(bt, @lib.Expr(body))
      | @lib.Loop(bt, @lib.Expr(body))
      | @lib.If(bt, body, _) => {
        let is_loop = instr is @lib.Loop(_, _)
        let shape = if is_loop {
          dae2_raw_loop_shape(bt, state.context)
        } else {
          dae2_raw_control_arity(bt)
        }
        if shape < 0 {
          return None
        }
        let params = if is_loop { shape / 2 } else { 0 }
        let arity = if is_loop { shape % 2 } else { shape }
        if instr is @lib.If(_, _, _) {
          if stack.length() == floor {
            return None
          }
          state.plan.observations.push(stack.pop().unwrap())
        }
        if stack.length() - floor < params {
          return None
        }
        let arm_floor = stack.length() - params
        let exit = self.block()
        if exit < 0 {
          return None
        }
        let target = if is_loop {
          let header = self.block()
          if header < 0 || !self.connect(header) {
            return None
          }
          self.current = header
          header
        } else {
          exit
        }
        let value = if arity > 0 || params > 0 {
          let value = state.plan.base + state.plan.count
          state.plan.count += 1
          value
        } else {
          -1
        }
        if params > 0 {
          state.plan.edge(value, stack[arm_floor])
        }
        let frame = Dae2RawLocalFrame::new(
          target,
          exit,
          value,
          arity,
          if is_loop {
            params
          } else {
            arity
          },
          is_loop,
        )
        self.frames.push(frame)
        let entry = self.current
        // Seal the shared fork before either arm can overwrite its exit state.
        if instr is @lib.If(_, _, _) {
          self.blocks[entry].frozen = true
        }
        if !self.arm(frame, body, arm_floor) {
          return None
        }
        match instr {
          @lib.If(_, _, no) => {
            self.current = entry
            match no {
              Some(body) => if !self.arm(frame, body, arm_floor) { return None }
              None => if arity != 0 || !self.connect(exit) { return None }
            }
          }
          _ => ()
        }
        ignore(self.frames.pop())
        let predecessors = self.blocks[exit].predecessors
        falls_through = !predecessors.is_empty()
        if falls_through {
          self.current = if predecessors.length() == 1 {
            predecessors[0]
          } else {
            exit
          }
          if arity > 0 {
            stack.push(value)
          }
        }
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
        if !self.branch(label, start, arity) {
          return None
        }
        falls_through = conditional
      }
      @lib.BrTable(targets, fallback) => {
        if stack.length() == floor {
          return None
        }
        state.plan.observations.push(stack.pop().unwrap())
        let arity = self.target_arity(fallback)
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
          if !self.branch(target, start, arity) {
            return None
          }
        }
        if !self.branch(fallback, start, arity) {
          return None
        }
        falls_through = false
      }
      @lib.Return => {
        if stack.length() - floor < state.result_count {
          return None
        }
        for slot in (stack.length() - state.result_count)..<stack.length() {
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
      @lib.LocalGet(index) => {
        let @lib.LocalIdx(raw) = index
        let local_id = raw.reinterpret_as_int()
        if local_id < 0 || local_id >= state.locals.length() {
          return None
        }
        stack.push(self.read(self.current, local_id))
      }
      @lib.LocalSet(index) | @lib.LocalTee(index) => {
        if !state.leaf(instr, floor) {
          return None
        }
        let @lib.LocalIdx(raw) = index
        let local_id = raw.reinterpret_as_int()
        if !self.write(local_id, state.locals[local_id]) {
          return None
        }
      }
      _ => if !state.leaf(instr, floor) { return None }
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
fn dae2_raw_local_flow_dependency_plan(
  graph : Dae2Graph,
  infos : Array[Dae2Function],
  index : Int32,
  type_infos : Array[Int32],
  body : @lib.Func,
  intrinsic_imports : Array[Bool]?,
  context : @ir.HotModuleContext?,
) -> Dae2RawPlan? {
  let @lib.Func(locals, @lib.Expr(instructions)) = body
  let count = dae2_raw_forward_instruction_count(instructions, context)
  if count < 0 {
    return None
  }
  let plan = Dae2RawPlan::new(graph.used.length())
  let flow = Dae2RawLocalFlow::new(
    Dae2RawControlState::new(
      plan,
      infos,
      index,
      type_infos,
      locals.length(),
      intrinsic_imports,
      context,
    ),
    infos[index].param_locations,
    64 + 8 * count,
  )
  match flow.body(instructions, 0, infos[index].results.length()) {
    None => return None
    Some(_) => ()
  }
  for source in flow.state.stack {
    plan.edge(infos[index].result_location, source)
  }
  if !flow.resolve() {
    return None
  }
  Some(plan)
}
