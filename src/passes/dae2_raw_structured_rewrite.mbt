///|
priv struct Dae2RawStructuredFrame {
  value : Int32
  arity : Int32
  results : Int32
  is_loop : Bool
  mut reachable : Bool
}

///|
fn Dae2RawStructuredFrame::new(
  value : Int32,
  arity : Int32,
  results : Int32,
  is_loop : Bool,
) -> Dae2RawStructuredFrame {
  { value, arity, results, is_loop, reachable: false, }
}

///|
// Reject unsupported replay shapes before allocating expression rows. Control
// results stay scalar; whether each result remains demanded is checked later.
fn dae2_raw_structured_instruction_count(
  body : Array[@lib.Instruction],
  infos : Array[Dae2Function],
  context : @ir.HotModuleContext,
) -> Int32 {
  let limit = (2147483647 - 64) / 8
  let mut count = 0
  for instr in body {
    let mut nested = 0
    match instr {
      @lib.Block(bt, @lib.Expr(child)) => {
        if dae2_raw_control_arity(bt) < 0 {
          return -1
        }
        nested = dae2_raw_structured_instruction_count(child, infos, context)
      }
      @lib.Loop(bt, @lib.Expr(child)) => {
        if dae2_raw_loop_shape(bt, Some(context)) < 0 {
          return -1
        }
        nested = dae2_raw_structured_instruction_count(child, infos, context)
      }
      @lib.If(bt, yes, no) => {
        let arity = dae2_raw_control_arity(bt)
        if arity < 0 {
          return -1
        }
        nested = dae2_raw_structured_instruction_count(yes, infos, context)
        if nested < 0 {
          return -1
        }
        match no {
          Some(child) => {
            let other = dae2_raw_structured_instruction_count(
              child, infos, context,
            )
            if other < 0 || other > limit - nested {
              return -1
            }
            nested += other
          }
          None => if arity != 0 { return -1 }
        }
      }
      @lib.Call(@lib.FuncIdx(raw)) => {
        let callee = raw.reinterpret_as_int()
        if callee < 0 ||
          callee >= infos.length() ||
          infos[callee].results.length() > 1 {
          return -1
        }
      }
      @lib.Nop
      | @lib.Drop
      | @lib.LocalSet(_)
      | @lib.LocalTee(_)
      | @lib.Return
      | @lib.Unreachable
      | @lib.Br(_)
      | @lib.BrIf(_) => ()
      @lib.BrTable(targets, _) => nested = targets.length()
      _ =>
        if dae2_raw_pure_arity(instr) < 0 &&
          dae2_raw_observer_arity(instr) < 0 &&
          dae2_raw_observed_producer_arity(instr, Some(context)) < 0 {
          return -1
        }
    }
    if nested < 0 || nested > limit - count - 1 {
      return -1
    }
    count += nested + 1
  }
  count
}

///|
fn dae2_raw_structured_owned_leaf(instr : @lib.Instruction) -> @lib.Instruction {
  match instr {
    @lib.BrTable(targets, default) =>
      @lib.Instruction::br_table(targets.copy(), default)
    @lib.Select(Some(types)) =>
      @lib.Instruction::select(types=Some(types.copy()))
    _ => instr
  }
}

///|
// Expression demand is ephemeral. Solved source-write demand supplies all
// cross-region local flow, so replay needs no local definitions or CFG.
priv struct Dae2RawStructuredRewrite {
  source : Dae2Graph
  graph : Dae2Graph
  info : Dae2Function
  infos : Array[Dae2Function]
  context : @ir.HotModuleContext
  kinds : Array[Int32]
  items : Array[@lib.Instruction]
  emitted : Array[Bool]
  written : Array[Bool]
  uniform_body_locals : Bool
  mut regroup_body_locals : Bool
  capture_base : Int32
  capture_types : Array[@lib.ValType]
  capture_reads : Array[Int32]
  mut captures : Array[Int32]?
  branch_values : Array[Int32]
  get_positions : @hashmap.HashMap[Int32, Array[Int32]]
  body_ends : @hashmap.HashMap[Int32, Int32]
  body_results : @hashmap.HashMap[Int32, Int32]
  control_inputs : @hashmap.HashMap[Int32, Int32]
  emit_nodes : Array[Int32]
  emit_edges : Array[Int32]
  mut capture_cursor : Int32
  mut entry_cursor : Int32
  mut has_tee : Bool
  stack : Array[Int32]
  frames : Array[Dae2RawStructuredFrame]
  entries : Array[Int32]
  discarded_args : Array[Int32]
  mut cursor : Int32
  mut write_cursor : Int32
  mut remaining : Int32
}

///|
fn Dae2RawStructuredRewrite::spend(
  self : Dae2RawStructuredRewrite,
  amount : Int32,
) -> Bool {
  if amount < 0 || self.remaining < amount {
    self.remaining = -1
    false
  } else {
    self.remaining -= amount
    true
  }
}

///|
fn Dae2RawStructuredRewrite::edge(
  self : Dae2RawStructuredRewrite,
  value : Int32,
  source : Int32,
) -> Bool {
  if !self.spend(1) {
    return false
  }
  self.graph.edge(value, source)
  true
}

///|
fn Dae2RawStructuredRewrite::observe(
  self : Dae2RawStructuredRewrite,
  value : Int32,
) -> Bool {
  if !self.spend(1) {
    return false
  }
  self.graph.observe(value)
  true
}

///|
fn Dae2RawStructuredRewrite::write_demand(
  self : Dae2RawStructuredRewrite,
  local_id : Int32,
) -> Int32 {
  match self.info.raw_write_locations {
    Some(writes) if self.write_cursor < writes.length() => {
      let (recorded, location) = writes[self.write_cursor]
      self.write_cursor += 1
      if recorded != local_id ||
        location < 0 ||
        location >= self.source.used.length() {
        -1
      } else if self.source.used[location] {
        16
      } else {
        0
      }
    }
    _ => -1
  }
}

///|
fn Dae2RawStructuredRewrite::target_arity(
  self : Dae2RawStructuredRewrite,
  label : @lib.LabelIdx,
) -> Int32 {
  let @lib.LabelIdx(raw) = label
  let depth = raw.reinterpret_as_int()
  if depth < 0 || depth > self.frames.length() {
    -1
  } else if depth == self.frames.length() {
    self.info.results.length()
  } else {
    self.frames[self.frames.length() - depth - 1].arity
  }
}

///|
fn Dae2RawStructuredRewrite::target(
  self : Dae2RawStructuredRewrite,
  label : @lib.LabelIdx,
  arity : Int32,
  payload : Int32,
) -> Bool {
  if self.target_arity(label) != arity {
    return false
  }
  let @lib.LabelIdx(raw) = label
  let depth = raw.reinterpret_as_int()
  if depth == self.frames.length() {
    self.source.used[self.info.result_location] || self.info.results.is_empty()
  } else {
    let frame = self.frames[self.frames.length() - depth - 1]
    if frame.results > 0 {
      // HOT pins every targeted control owner, including scalar-result loops.
      self.kinds[frame.value] = self.kinds[frame.value] | 256
    }
    if frame.results == 0 {
      if !self.observe(frame.value) {
        return false
      }
    } else if !frame.is_loop {
      // Label reachability does not demand the control's result. Only a
      // consumer of that result activates the branch payload edge.
      if payload < 0 || !self.edge(frame.value, payload) {
        return false
      }
    }
    if !frame.is_loop {
      frame.reachable = true
    }
    true
  }
}

///|
fn Dae2RawStructuredRewrite::arm(
  self : Dae2RawStructuredRewrite,
  frame : Dae2RawStructuredFrame,
  body : Array[@lib.Instruction],
  floor : Int32,
) -> Bool {
  let start = self.cursor
  match self.build(body, floor, frame.results) {
    Some(true) => {
      frame.reachable = true
      if frame.results > 0 {
        let result = self.stack[self.stack.length() - 1]
        if !self.edge(frame.value, result) || !self.spend(1) {
          return false
        }
        self.body_results.set(start, result)
      }
    }
    Some(false) => ()
    None => return false
  }
  self.stack.truncate(floor)
  if !self.spend(1) {
    return false
  }
  self.body_ends.set(start, self.cursor)
  true
}

///|
fn Dae2RawStructuredRewrite::build(
  self : Dae2RawStructuredRewrite,
  instructions : Array[@lib.Instruction],
  floor : Int32,
  results : Int32,
) -> Bool? {
  let stack = self.stack
  let mut falls_through = true
  for position in 0..<instructions.length() {
    if !falls_through || self.cursor >= self.kinds.length() || !self.spend(1) {
      return None
    }
    let instr = instructions[position]
    let value = self.cursor
    self.cursor += 1
    self.items[value] = instr
    match instr {
      @lib.Block(bt, @lib.Expr(body)) => {
        let result_arity = dae2_raw_control_arity(bt)
        if result_arity < 0 {
          return None
        }
        self.kinds[value] = 9 + 64 * result_arity
        if stack.length() > 0 {
          self.kinds[value] = self.kinds[value] | 512
        }
        let frame = Dae2RawStructuredFrame::new(
          value, result_arity, result_arity, false,
        )
        self.frames.push(frame)
        if !self.arm(frame, body, stack.length()) {
          return None
        }
        ignore(self.frames.pop())
        falls_through = frame.reachable
        if falls_through && result_arity > 0 {
          stack.push(value)
        }
      }
      @lib.Loop(bt, @lib.Expr(body)) => {
        let shape = dae2_raw_loop_shape(bt, Some(self.context))
        if shape < 0 || shape / 2 > stack.length() - floor {
          return None
        }
        let result_arity = shape % 2
        self.kinds[value] = 9 + 64 * result_arity
        let params = shape / 2
        let loop_floor = stack.length() - params
        if loop_floor > 0 {
          self.kinds[value] = self.kinds[value] | 512
        }
        if params > 0 {
          if !self.spend(1) {
            return None
          }
          let original = stack[loop_floor]
          let entry = self.graph.location()
          if !self.edge(entry, original) ||
            !self.edge(value, original) ||
            !self.spend(1) {
            return None
          }
          self.control_inputs.set(value, original)
          stack[loop_floor] = entry
          // A retained header always receives its complete entry. This slice
          // delegates entries whose body value disappears to general lowering.
          self.entries.push(entry)
          self.entries.push(value)
        }
        let frame = Dae2RawStructuredFrame::new(
          value, params, result_arity, true,
        )
        self.frames.push(frame)
        if !self.arm(frame, body, loop_floor) {
          return None
        }
        ignore(self.frames.pop())
        falls_through = frame.reachable
        if falls_through && result_arity > 0 {
          stack.push(value)
        }
      }
      @lib.If(bt, yes, no) => {
        let result_arity = dae2_raw_control_arity(bt)
        if result_arity < 0 || stack.length() == floor {
          return None
        }
        let condition = stack.pop().unwrap()
        if !self.observe(condition) ||
          !self.edge(value, condition) ||
          !self.spend(1) {
          return None
        }
        self.control_inputs.set(value, condition)
        self.kinds[value] = 10 + 64 * result_arity
        if stack.length() > 0 {
          self.kinds[value] = self.kinds[value] | 512
        }
        let arm_floor = stack.length()
        let frame = Dae2RawStructuredFrame::new(
          value, result_arity, result_arity, false,
        )
        self.frames.push(frame)
        if !self.arm(frame, yes, arm_floor) {
          return None
        }
        match no {
          Some(body) => if !self.arm(frame, body, arm_floor) { return None }
          None => {
            if result_arity != 0 {
              return None
            }
            frame.reachable = true
          }
        }
        ignore(self.frames.pop())
        falls_through = frame.reachable
        if falls_through && result_arity > 0 {
          stack.push(value)
        }
      }
      @lib.Br(label) | @lib.BrIf(label) => {
        let conditional = instr is @lib.BrIf(_)
        if conditional {
          if stack.length() == floor {
            return None
          }
          let condition = stack.pop().unwrap()
          if !self.observe(condition) || !self.edge(value, condition) {
            return None
          }
        }
        let arity = self.target_arity(label)
        if arity < 0 || arity > stack.length() - floor {
          return None
        }
        for slot in (stack.length() - arity)..<stack.length() {
          if !self.observe(stack[slot]) {
            return None
          }
          if !self.edge(value, stack[slot]) {
            return None
          }
          self.branch_values.push(stack[slot])
        }
        let payload = if arity > 0 { stack[stack.length() - 1] } else { -1 }
        if !self.target(label, arity, payload) {
          return None
        }
        self.kinds[value] = if conditional { 12 } else { 11 }
        falls_through = conditional
      }
      @lib.BrTable(targets, default) => {
        if stack.length() == floor {
          return None
        }
        let selector = stack.pop().unwrap()
        if !self.observe(selector) || !self.edge(value, selector) {
          return None
        }
        let arity = self.target_arity(default)
        if arity < 0 || arity != stack.length() - floor {
          return None
        }
        for slot in floor..<stack.length() {
          if !self.observe(stack[slot]) {
            return None
          }
          if !self.edge(value, stack[slot]) {
            return None
          }
          self.branch_values.push(stack[slot])
        }
        let payload = if arity > 0 { stack[stack.length() - 1] } else { -1 }
        for target in targets {
          if !self.target(target, arity, payload) {
            return None
          }
        }
        if !self.target(default, arity, payload) {
          return None
        }
        self.kinds[value] = 13
        falls_through = false
      }
      @lib.Return => {
        if self.info.results.length() > stack.length() - floor {
          return None
        }
        if !self.info.results.is_empty() &&
          self.source.used[self.info.result_location] {
          for
            slot in (stack.length() - self.info.results.length())..<stack.length() {
            if !self.observe(stack[slot]) {
              return None
            }
          }
        }
        for
          slot in (stack.length() - self.info.results.length())..<stack.length() {
          if !self.edge(value, stack[slot]) {
            return None
          }
        }
        self.kinds[value] = 6
        falls_through = false
      }
      @lib.Unreachable => {
        if stack.length() != floor {
          return None
        }
        self.kinds[value] = 14
        falls_through = false
      }
      _ => {
        let pure = dae2_raw_pure_arity(instr)
        let observer = dae2_raw_observer_arity(instr)
        let producer = dae2_raw_observed_producer_arity(
          instr,
          Some(self.context),
        )
        let (kind, consumed, produced) = if pure >= 0 {
          (
            if instr is @lib.MemorySize(_) || instr is @lib.TableSize(_) {
              2
            } else {
              0
            },
            pure,
            1,
          )
        } else if observer >= 0 {
          (1, observer, 0)
        } else if producer >= 0 {
          (2, producer, 1)
        } else {
          match instr {
            @lib.LocalSet(_) => (3, 1, 0)
            @lib.LocalTee(_) => (8, 1, 1)
            @lib.Drop => (5, 1, 0)
            @lib.Nop => (7, 0, 0)
            @lib.Call(@lib.FuncIdx(raw)) => {
              let callee = raw.reinterpret_as_int()
              if callee < 0 ||
                callee >= self.infos.length() ||
                self.infos[callee].results.length() > 1 {
                return None
              }
              (
                4,
                self.infos[callee].params.length(),
                self.infos[callee].results.length(),
              )
            }
            _ => return None
          }
        }
        if consumed > stack.length() - floor {
          return None
        }
        let start = stack.length() - consumed
        let mut stored_kind = kind
        match kind {
          0 | 3 | 5 | 8 => {
            for slot in start..<stack.length() {
              if !self.edge(value, stack[slot]) {
                return None
              }
            }
            if kind == 3 || kind == 8 {
              let local_id = match instr {
                @lib.LocalSet(@lib.LocalIdx(raw))
                | @lib.LocalTee(@lib.LocalIdx(raw)) => raw.reinterpret_as_int()
                _ => return None
              }
              if kind == 8 {
                self.has_tee = true
              }
              let demand = self.write_demand(local_id)
              if demand < 0 {
                return None
              }
              stored_kind += demand
              if demand > 0 {
                if kind == 3 &&
                  dae2_stack_suffix_needs_control_capture(
                    instructions,
                    position,
                    Some(self.context),
                    params=self.info.params.length(),
                    uniform_body_locals=self.uniform_body_locals,
                  ) {
                  // Original body slots survive capture compaction. Reject
                  // this known-wide case before doing the remaining replay.
                  if self.capture_base > 128 {
                    return None
                  }
                  // Check the final local count after capture compaction. A
                  // bounded exact-type regroup can keep the original stack
                  // value without the declaration-order cost of this shape.
                  self.regroup_body_locals = true
                }
                if !self.observe(stack[start]) {
                  return None
                }
              }
            }
          }
          1 | 2 =>
            for slot in start..<stack.length() {
              if !self.observe(stack[slot]) || !self.edge(value, stack[slot]) {
                return None
              }
            }
          4 => {
            guard instr is @lib.Call(@lib.FuncIdx(raw)) else { return None }
            let callee = self.infos[raw.reinterpret_as_int()]
            let removed = callee.param_locations.any(fn(location) {
              !self.source.used[location]
            })
            for arg in 0..<callee.params.length() {
              if self.source.used[callee.param_locations[arg]] {
                if !self.observe(stack[start + arg]) ||
                  !self.edge(value, stack[start + arg]) {
                  return None
                }
                if removed {
                  let producer = stack[start + arg]
                  if producer >= self.kinds.length() ||
                    !@lib.has_default(callee.params[arg]) ||
                    !self.spend(2) {
                    return None
                  }
                  let captures = match self.captures {
                    Some(captures) => captures
                    None => {
                      if !self.spend(self.kinds.length()) {
                        return None
                      }
                      let captures = Array::make(self.kinds.length(), -1)
                      self.captures = Some(captures)
                      captures
                    }
                  }
                  if captures[producer] >= 0 {
                    return None
                  }
                  let local_id = self.capture_base + self.capture_types.length()
                  captures[producer] = local_id
                  self.capture_types.push(callee.params[arg])
                  self.capture_reads.push(local_id)
                }
              } else {
                if !self.spend(1) {
                  return None
                }
                self.discarded_args.push(stack[start + arg])
              }
            }
          }
          _ => ()
        }
        self.kinds[value] = stored_kind
        stack.truncate(start)
        if produced > 0 {
          stack.push(value)
        }
      }
    }
    if !falls_through {
      stack.truncate(floor)
    }
  }
  if !falls_through {
    Some(false)
  } else if stack.length() == floor + results {
    Some(true)
  } else {
    None
  }
}

///|
fn Dae2RawStructuredRewrite::mark_reads(
  self : Dae2RawStructuredRewrite,
  body : Array[@lib.Instruction],
  reads : Array[Bool],
) -> Unit {
  for instr in body {
    let position = self.cursor
    self.cursor += 1
    match instr {
      @lib.LocalGet(@lib.LocalIdx(raw)) if self.graph.used[position] => {
        let local_id = raw.reinterpret_as_int()
        reads[local_id] = true
        if self.has_tee {
          if !self.spend(1) {
            return
          }
          let positions = match self.get_positions.get(local_id) {
            Some(positions) => positions
            None => {
              let positions = []
              self.get_positions.set(local_id, positions)
              positions
            }
          }
          positions.push(position)
        }
      }
      @lib.Block(_, @lib.Expr(child)) | @lib.Loop(_, @lib.Expr(child)) =>
        self.mark_reads(child, reads)
      @lib.If(_, yes, no) => {
        self.mark_reads(yes, reads)
        match no {
          Some(child) => self.mark_reads(child, reads)
          None => ()
        }
      }
      _ => ()
    }
  }
}

///|
fn Dae2RawStructuredRewrite::prepare_stable(
  self : Dae2RawStructuredRewrite,
  count : Int32,
  reads : Array[Bool],
) -> Unit {
  // Removed stores cannot change a delayed source read. Tee storage also
  // depends on the emitted-read census, matching the emission rule below.
  for value in 0..<count {
    match self.items[value] {
      @lib.LocalSet(@lib.LocalIdx(raw)) if (self.kinds[value] & 16) != 0 =>
        self.written[raw.reinterpret_as_int()] = true
      @lib.LocalTee(@lib.LocalIdx(raw)) => {
        let local_id = raw.reinterpret_as_int()
        if ((self.kinds[value] & 16) != 0 || self.graph.used[value]) &&
          reads[local_id] {
          self.written[local_id] = true
        }
      }
      _ => ()
    }
  }
  // Pure operands precede their consumer. One forward pass proves expressions
  // independent of mutable source locals; no expression recursion is needed.
  for value in 0..<count {
    let kind = self.kinds[value] % 16
    let mut stable = kind == 0
    match self.items[value] {
      @lib.LocalGet(@lib.LocalIdx(raw)) =>
        stable = !self.written[raw.reinterpret_as_int()]
      @lib.GlobalGet(_) => stable = false
      @lib.LocalTee(@lib.LocalIdx(raw)) =>
        stable = !reads[raw.reinterpret_as_int()]
      _ => ()
    }
    let mut edge = self.graph.first_edge[value]
    while stable && edge >= 0 {
      let child = self.graph.edges[edge]
      stable = child < self.kinds.length() && (self.kinds[child] & 32) != 0
      edge = self.graph.next_edge[edge]
    }
    if stable {
      self.kinds[value] = self.kinds[value] | 32
    }
  }
}

///|
fn Dae2RawStructuredRewrite::emit_value(
  self : Dae2RawStructuredRewrite,
  value : Int32,
  out : Array[@lib.Instruction],
  local_map : Array[Int32],
) -> Bool {
  if value >= self.kinds.length() {
    return true
  }
  if (self.kinds[value] & 128) != 0 {
    let capture = self.captures.unwrap()[value]
    out.push(@lib.Instruction::local_get(@lib.LocalIdx::new(capture.to_uint())))
    return true
  }
  if self.emitted[value] {
    return true
  }
  if (self.kinds[value] & 32) == 0 {
    return false
  }
  let nodes = self.emit_nodes
  let edges = self.emit_edges
  nodes.clear()
  edges.clear()
  nodes.push(value)
  edges.push(self.graph.first_edge[value])
  while !nodes.is_empty() {
    let top = nodes.length() - 1
    let node = nodes[top]
    let edge = edges[top]
    if edge >= 0 {
      edges[top] = self.graph.next_edge[edge]
      let child = self.graph.edges[edge]
      if child >= self.kinds.length() || self.emitted[child] {
        continue
      }
      if (self.kinds[child] & 32) == 0 || (self.kinds[child] & 128) != 0 {
        return false
      }
      nodes.push(child)
      edges.push(self.graph.first_edge[child])
      continue
    }
    match self.items[node] {
      @lib.LocalGet(@lib.LocalIdx(raw)) => {
        let local_id = raw.reinterpret_as_int()
        if local_map[local_id] < 0 {
          return false
        }
        out.push(
          @lib.Instruction::local_get(
            @lib.LocalIdx::new(local_map[local_id].to_uint()),
          ),
        )
      }
      @lib.LocalTee(_) => ()
      instr => out.push(dae2_raw_structured_owned_leaf(instr))
    }
    self.emitted[node] = true
    ignore(nodes.pop())
    ignore(edges.pop())
  }
  true
}

///|
fn Dae2RawStructuredRewrite::emit_inputs(
  self : Dae2RawStructuredRewrite,
  value : Int32,
  out : Array[@lib.Instruction],
  local_map : Array[Int32],
  discard~ : Bool = false,
) -> Bool {
  let mut edge = self.graph.first_edge[value]
  while edge >= 0 {
    let child = self.graph.edges[edge]
    if self.graph.used[child] {
      if !self.emit_value(child, out, local_map) {
        return false
      }
      if discard {
        out.push(@lib.Instruction::drop())
      }
    }
    edge = self.graph.next_edge[edge]
  }
  true
}

///|
fn Dae2RawStructuredRewrite::flush_pending(
  self : Dae2RawStructuredRewrite,
  pending : Array[Int32],
  out : Array[@lib.Instruction],
  local_map : Array[Int32],
) -> Bool {
  for value in pending {
    if !self.emitted[value] && !self.emit_value(value, out, local_map) {
      return false
    }
  }
  pending.clear()
  true
}

///|
fn Dae2RawStructuredRewrite::later_get(
  self : Dae2RawStructuredRewrite,
  local_id : Int32,
  position : Int32,
  end : Int32,
) -> Bool? {
  match self.get_positions.get(local_id) {
    Some(positions) => {
      let mut low = 0
      let mut high = positions.length()
      while low < high {
        if !self.spend(1) {
          return None
        }
        let middle = low + (high - low) / 2
        if positions[middle] < end {
          low = middle + 1
        } else {
          high = middle
        }
      }
      Some(low > 0 && positions[low - 1] > position)
    }
    None => Some(false)
  }
}

///|
fn Dae2RawStructuredRewrite::emit(
  self : Dae2RawStructuredRewrite,
  body : Array[@lib.Instruction],
  local_map : Array[Int32],
  reads : Array[Bool],
) -> Array[@lib.Instruction]? {
  let out : Array[@lib.Instruction] = []
  let pending : Array[Int32] = []
  let start = self.cursor
  let end = self.body_ends.get(self.cursor).unwrap_or(self.cursor)
  for index in 0..<body.length() {
    let instr = body[index]
    let position = self.cursor
    self.cursor += 1
    let stored = self.kinds[position]
    let kind = stored % 16
    let used = self.graph.used[position]
    let capture = match self.captures {
      Some(captures) => captures[position]
      None => -1
    }
    match kind {
      0 =>
        if used {
          if (stored & 32) != 0 {
            if capture < 0 {
              // A literal has no delayed inputs. Keep its source stack
              // position when no earlier pure operand is pending.
              if pending.is_empty() &&
                dae2_raw_pure_arity(instr) == 0 &&
                !(instr is @lib.LocalGet(_)) {
                if !self.emit_value(position, out, local_map) {
                  return None
                }
              } else {
                pending.push(position)
              }
            }
          } else {
            if !self.flush_pending(pending, out, local_map) ||
              !self.emit_inputs(position, out, local_map) {
              return None
            }
            match instr {
              @lib.LocalGet(@lib.LocalIdx(raw)) =>
                out.push(
                  @lib.Instruction::local_get(
                    @lib.LocalIdx::new(
                      local_map[raw.reinterpret_as_int()].to_uint(),
                    ),
                  ),
                )
              _ => out.push(dae2_raw_structured_owned_leaf(instr))
            }
            self.emitted[position] = true
          }
        } else if !self.emit_inputs(position, out, local_map, discard=true) {
          return None
        }
      3 => {
        guard instr is @lib.LocalSet(@lib.LocalIdx(raw)) else { return None }
        if (stored & 16) != 0 {
          if !self.emit_inputs(position, out, local_map) {
            return None
          }
          out.push(
            @lib.Instruction::local_set(
              @lib.LocalIdx::new(local_map[raw.reinterpret_as_int()].to_uint()),
            ),
          )
        } else if !self.emit_inputs(position, out, local_map, discard=true) {
          return None
        }
      }
      8 => {
        guard instr is @lib.LocalTee(@lib.LocalIdx(raw)) else { return None }
        let local_id = raw.reinterpret_as_int()
        let storage = ((stored & 16) != 0 || used) && reads[local_id]
        if storage {
          if used && capture < 0 && !self.flush_pending(pending, out, local_map) {
            return None
          }
          if !self.emit_inputs(position, out, local_map) {
            return None
          }
          let later = if used {
            true
          } else {
            match self.later_get(local_id, position, end) {
              Some(later) => later
              None => return None
            }
          }
          let local = @lib.LocalIdx::new(local_map[local_id].to_uint())
          if later {
            out.push(@lib.Instruction::local_tee(local))
            if !used {
              out.push(@lib.Instruction::drop())
            }
          } else {
            out.push(@lib.Instruction::local_set(local))
          }
          self.emitted[position] = true
        } else if used {
          if (stored & 32) != 0 {
            if capture < 0 {
              pending.push(position)
            }
          } else {
            if !self.emit_inputs(position, out, local_map) {
              return None
            }
            self.emitted[position] = true
          }
        } else if !self.emit_inputs(position, out, local_map, discard=true) {
          return None
        }
      }
      1 | 2 | 4 => {
        // A following store consumes this result before another expression can
        // need the region's held pure prefix. Other retained results keep the
        // original stack order by materializing that prefix first.
        let immediate_store = index + 1 < body.length() &&
          body[index + 1] is @lib.LocalSet(_)
        if kind != 1 &&
          used &&
          capture < 0 &&
          !immediate_store &&
          !self.flush_pending(pending, out, local_map) {
          return None
        }
        if kind == 4 {
          guard instr is @lib.Call(@lib.FuncIdx(raw)) else { return None }
          let callee = self.infos[raw.reinterpret_as_int()]
          let removed = callee.param_locations.any(fn(location) {
            !self.source.used[location]
          })
          if removed {
            for location in callee.param_locations {
              if self.source.used[location] {
                if self.capture_cursor >= self.capture_reads.length() {
                  return None
                }
                let local_id = self.capture_reads[self.capture_cursor]
                self.capture_cursor += 1
                out.push(
                  @lib.Instruction::local_get(
                    @lib.LocalIdx::new(local_id.to_uint()),
                  ),
                )
              }
            }
          } else if !self.emit_inputs(position, out, local_map) {
            return None
          }
          let result = !callee.results.is_empty() &&
            self.source.used[callee.result_location]
          if used && !result {
            return None
          }
          out.push(dae2_raw_structured_owned_leaf(instr))
          if result && !used {
            out.push(@lib.Instruction::drop())
          }
        } else {
          if !self.emit_inputs(position, out, local_map) {
            return None
          }
          out.push(dae2_raw_structured_owned_leaf(instr))
          if kind == 2 && !used {
            out.push(@lib.Instruction::drop())
          }
        }
        self.emitted[position] = true
      }
      5 =>
        if !self.emit_inputs(position, out, local_map, discard=true) {
          return None
        }
      6 | 11 | 12 | 13 | 14 => {
        if !self.flush_pending(pending, out, local_map) ||
          !self.emit_inputs(position, out, local_map) {
          return None
        }
        out.push(dae2_raw_structured_owned_leaf(instr))
      }
      7 => ()
      9 => {
        if (stored & 64) != 0 &&
          capture < 0 &&
          !self.flush_pending(pending, out, local_map) {
          return None
        }
        match self.control_inputs.get(position) {
          Some(input) =>
            if !self.emit_value(input, out, local_map) {
              return None
            }
          None => ()
        }
        match instr {
          @lib.Block(bt, @lib.Expr(child)) => {
            let child = match self.emit(child, local_map, reads) {
              Some(child) => child
              None => return None
            }
            let bt = if bt is @lib.ValTypeBlockType(_) && (stored & 64) == 0 {
              @lib.BlockType::void_()
            } else {
              bt
            }
            out.push(@lib.Instruction::block(bt, @lib.Expr::new(child)))
          }
          @lib.Loop(bt, @lib.Expr(child)) => {
            if dae2_raw_loop_shape(bt, Some(self.context)) / 2 > 0 {
              if self.entry_cursor + 1 >= self.entries.length() ||
                self.entries[self.entry_cursor + 1] != position {
                return None
              }
              self.entry_cursor += 2
            }
            let child = match self.emit(child, local_map, reads) {
              Some(child) => child
              None => return None
            }
            let bt = if bt is @lib.ValTypeBlockType(_) && (stored & 64) == 0 {
              @lib.BlockType::void_()
            } else {
              bt
            }
            out.push(@lib.Instruction::loop_(bt, @lib.Expr::new(child)))
          }
          _ => return None
        }
        self.emitted[position] = true
      }
      10 => {
        if (stored & 64) != 0 &&
          capture < 0 &&
          !self.flush_pending(pending, out, local_map) {
          return None
        }
        let condition = self.control_inputs.get(position).unwrap()
        if !self.emit_value(condition, out, local_map) {
          return None
        }
        guard instr is @lib.If(bt, yes, no) else { return None }
        let yes = match self.emit(yes, local_map, reads) {
          Some(child) => child
          None => return None
        }
        let no = match no {
          Some(child) =>
            match self.emit(child, local_map, reads) {
              Some(child) => Some(child)
              None => return None
            }
          None => None
        }
        let bt = if bt is @lib.ValTypeBlockType(_) && (stored & 64) == 0 {
          @lib.BlockType::void_()
        } else {
          bt
        }
        out.push(@lib.Instruction::if_(bt, yes, no))
        self.emitted[position] = true
      }
      _ => return None
    }
    if capture >= 0 {
      if !self.emit_value(position, out, local_map) {
        return None
      }
      out.push(
        @lib.Instruction::local_set(@lib.LocalIdx::new(capture.to_uint())),
      )
      self.kinds[position] = self.kinds[position] | 128
    }
  }
  match self.body_results.get(start) {
    Some(value) => if !self.emit_value(value, out, local_map) { return None }
    None => ()
  }
  Some(out)
}

///|
fn dae2_rewrite_raw_structured_function(
  source : Dae2Graph,
  infos : Array[Dae2Function],
  index : Int32,
  original : @lib.Func,
  context : @ir.HotModuleContext,
  kept_params : Array[@lib.ValType],
  removed_params : Array[@lib.ValType],
) -> (@lib.Func, Array[Int32])? {
  let info = infos[index]
  if !info.raw_analysis || info.results.length() > 1 {
    return None
  }
  let keep_result = info.results.is_empty() || source.used[info.result_location]
  let @lib.Func(locals, @lib.Expr(body)) = original
  let count = dae2_raw_structured_instruction_count(body, infos, context)
  if count < 0 {
    return None
  }
  let graph = Dae2Graph::new()
  ignore(graph.locations(count))
  let written = Array::make(info.params.length() + locals.length(), false)
  let state : Dae2RawStructuredRewrite = {
    source,
    graph,
    info,
    infos,
    context,
    kinds: Array::make(count, -1),
    items: Array::make(count, @lib.Instruction::nop()),
    emitted: Array::make(count, false),
    written,
    uniform_body_locals: locals.run_count() == 1,
    regroup_body_locals: false,
    capture_base: kept_params.length() + locals.length(),
    capture_types: [],
    capture_reads: [],
    captures: None,
    branch_values: [],
    get_positions: @hashmap.new(),
    body_ends: @hashmap.new(),
    body_results: @hashmap.new(),
    control_inputs: @hashmap.new(),
    emit_nodes: [],
    emit_edges: [],
    capture_cursor: 0,
    entry_cursor: 0,
    has_tee: false,
    stack: [],
    frames: [],
    entries: [],
    discarded_args: [],
    cursor: 0,
    write_cursor: 0,
    remaining: 64 + 8 * count,
  }
  match state.build(body, 0, info.results.length()) {
    Some(_) => ()
    None => return None
  }
  state.body_ends.set(0, state.cursor)
  let instruction_count = state.cursor
  match info.raw_write_locations {
    Some(writes) if state.write_cursor != writes.length() => return None
    _ => ()
  }
  if keep_result {
    for value in state.stack {
      graph.observe(value)
    }
  }
  graph.solve()
  if !keep_result {
    // A separate demanded use can leave this value physically on the stack.
    // This slice removes result demand, but does not repair surviving slots.
    for value in state.stack {
      if graph.used[value] {
        return None
      }
    }
  }
  // A dead plain scalar result can disappear without changing a label payload.
  // Indexed signatures and independently demanded arm values still need HOT.
  for value in 0..<instruction_count {
    if (state.kinds[value] & 64) == 0 || graph.used[value] {
      continue
    }
    // Shrinking a header with a held prefix can lose downstream HOT cleanup.
    // Retained scalar and existing Void controls keep their established path.
    if (state.kinds[value] & (256 | 512)) != 0 {
      return None
    }
    let start = value + 1
    let mut other_start = -1
    match state.items[value] {
      @lib.Block(@lib.ValTypeBlockType(_), _)
      | @lib.Loop(@lib.ValTypeBlockType(_), _) => ()
      @lib.If(@lib.ValTypeBlockType(_), _, Some(_)) =>
        other_start = match state.body_ends.get(start) {
          Some(end) if end >= start && end <= instruction_count => end
          _ => return None
        }
      _ => return None
    }
    // Charge the bounded arm metadata work to the unchanged replay budget.
    if !state.spend(if other_start >= 0 { 6 } else { 3 }) {
      return None
    }
    match state.body_ends.get(start) {
      Some(end) if end >= start && end <= instruction_count => ()
      _ => return None
    }
    let mut has_fallthrough = false
    match state.body_results.get(start) {
      Some(result) => {
        if result < 0 || result >= instruction_count || graph.used[result] {
          return None
        }
        has_fallthrough = true
      }
      None => ()
    }
    if other_start >= 0 {
      match state.body_ends.get(other_start) {
        Some(end) if end >= other_start && end <= instruction_count => ()
        _ => return None
      }
      match state.body_results.get(other_start) {
        Some(result) => {
          if result < 0 || result >= instruction_count || graph.used[result] {
            return None
          }
          has_fallthrough = true
        }
        None => ()
      }
    }
    // Nested terminal control does not make its parent stack polymorphic.
    // Keep HOT lowering when the scalar header supplies only a virtual result.
    if !has_fallthrough {
      return None
    }
    // Check both arms before changing the private emission tables.
    state.kinds[value] = state.kinds[value] - 64
    state.body_results.remove(start)
    if other_start >= 0 {
      state.body_results.remove(other_start)
    }
  }
  // A branch payload can also survive on the fallthrough stack. Its producer
  // cannot disappear at a later removed argument without a separate slot edit.
  for value in state.discarded_args {
    if graph.used[value] {
      return None
    }
  }
  match state.captures {
    Some(captures) =>
      for value in state.branch_values {
        if value < captures.length() && captures[value] >= 0 {
          return None
        }
      }
    None => ()
  }
  for entry in state.entries {
    if !graph.used[entry] {
      return None
    }
  }
  let reads = Array::make(info.params.length() + locals.length(), false)
  state.cursor = 0
  state.mark_reads(body, reads)
  if state.remaining < 0 {
    return None
  }
  state.prepare_stable(instruction_count, reads)
  let local_map = Array::make(reads.length(), -1)
  let mut kept = 0
  let mut removed = 0
  for param in 0..<info.params.length() {
    if source.used[info.param_locations[param]] {
      local_map[param] = kept
      kept += 1
    } else {
      if !@lib.has_default(info.params[param]) {
        return None
      }
      local_map[param] = kept_params.length() +
        locals.length() +
        state.capture_types.length() +
        removed_params.length() -
        1 -
        removed
      removed += 1
    }
  }
  for local_id in 0..<locals.length() {
    local_map[info.params.length() + local_id] = kept_params.length() + local_id
  }
  state.cursor = 0
  let body = match state.emit(body, local_map, reads) {
    Some(body) => body
    None => return None
  }
  if keep_result {
    for value in state.stack {
      if !state.emit_value(value, body, local_map) {
        return None
      }
    }
  }
  let new_locals = locals.copy()
  for ty in state.capture_types {
    new_locals.push(ty)
  }
  for slot = removed_params.length() - 1; slot >= 0; slot = slot - 1 {
    new_locals.push(removed_params[slot])
  }
  let (rewritten, capture_map) = pass_lower_compact_captures_with_map(
    @lib.Func::new(new_locals, @lib.Expr::new(body)),
    original,
    kept_params,
  )
  let local_map = local_map.map(fn(local_id) { capture_map[local_id] })
  if state.regroup_body_locals {
    let @lib.Func(locals, _) = rewritten
    // Include kept parameters, relocated parameters and every surviving new
    // capture. No emitted local operand may cross the 127/128 LEB boundary.
    if kept_params.length() + locals.length() > 128 {
      return None
    }
    let (rewritten, grouped_map) = dae2_raw_group_small_body_locals(
      rewritten,
      kept_params.length(),
    )
    return Some(
      (
        rewritten,
        local_map.map(fn(local_id) {
          if local_id < 0 {
            -1
          } else {
            grouped_map[local_id]
          }
        }),
      ),
    )
  }
  Some((rewritten, local_map))
}
