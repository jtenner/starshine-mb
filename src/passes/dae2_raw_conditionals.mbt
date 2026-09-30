///|
// The established flat planner runs first. This separate preflight accepts only
// fallthrough, no-input void/single-value controls; branches/loops/handlers stay HOT.
fn dae2_raw_conditional_qualified(
  instructions : Array[@lib.Instruction],
  context : @ir.HotModuleContext?,
  nested : Bool,
) -> Bool {
  for position, instr in instructions {
    match instr {
      @lib.Block(bt, @lib.Expr(body)) =>
        if !(bt is @lib.VoidBlockType || bt is @lib.ValTypeBlockType(_)) ||
          !dae2_raw_conditional_qualified(body, context, true) {
          return false
        }
      @lib.If(bt, yes, no) => {
        if !(bt is @lib.VoidBlockType || bt is @lib.ValTypeBlockType(_)) ||
          !dae2_raw_conditional_qualified(yes, context, true) {
          return false
        }
        match no {
          Some(body) =>
            if !dae2_raw_conditional_qualified(body, context, true) {
              return false
            }
          None => if !(bt is @lib.VoidBlockType) { return false }
        }
      }
      @lib.Nop
      | @lib.Drop
      | @lib.LocalSet(_)
      | @lib.LocalTee(_)
      | @lib.Call(_)
      | @lib.CallIndirect(_, _)
      | @lib.CallRef(_) => ()
      @lib.Return if !nested && position == instructions.length() - 1 => ()
      _ =>
        if dae2_raw_pure_arity(instr) < 0 &&
          dae2_raw_observer_arity(instr) < 0 &&
          dae2_raw_observed_producer_arity(instr, context) < 0 {
          return false
        }
    }
  }
  true
}

///|
priv struct Dae2RawArmWrites {
  order : Array[Int]
  values : @hashmap.HashMap[Int, Int]
}

///|
fn Dae2RawArmWrites::new() -> Dae2RawArmWrites {
  { order: [], values: @hashmap.new(), }
}

///|
priv struct Dae2RawControlState {
  plan : Dae2RawPlan
  infos : Array[Dae2Function]
  type_infos : Array[Int]
  intrinsic_imports : Array[Bool]?
  context : @ir.HotModuleContext?
  stack : Array[Int]
  locals : Array[Int]
  undo_locals : Array[Int]
  undo_values : Array[Int]
  mut arm_depth : Int
}

///|
fn Dae2RawControlState::new(
  plan : Dae2RawPlan,
  infos : Array[Dae2Function],
  index : Int,
  type_infos : Array[Int],
  local_count : Int,
  intrinsic_imports : Array[Bool]?,
  context : @ir.HotModuleContext?,
) -> Dae2RawControlState {
  let info = infos[index]
  let locals = Array::make(info.params.length() + local_count, -1)
  for param in 0..<info.params.length() {
    locals[param] = info.param_locations[param]
  }
  {
    plan,
    infos,
    type_infos,
    intrinsic_imports,
    context,
    stack: [],
    locals,
    undo_locals: [],
    undo_values: [],
    arm_depth: 0,
  }
}

///|
fn Dae2RawControlState::assign(
  self : Dae2RawControlState,
  local_id : Int,
  value : Int,
) -> Unit {
  if self.arm_depth > 0 {
    self.undo_locals.push(local_id)
    self.undo_values.push(self.locals[local_id])
  }
  self.locals[local_id] = value
}

///|
// Capture final values only for distinct written locals, then restore entry in
// reverse. No writes means no map, row or full local-array copy. Parent arms
// record merged assignments separately, so nested undo segments stay isolated.
fn Dae2RawControlState::restore_arm(
  self : Dae2RawControlState,
  mark : Int,
) -> Dae2RawArmWrites? {
  if self.undo_locals.length() == mark {
    return None
  }
  let writes = Dae2RawArmWrites::new()
  let order = writes.order
  let values = writes.values
  while self.undo_locals.length() > mark {
    let local_id = self.undo_locals.pop().unwrap()
    if values.get(local_id) is None {
      order.push(local_id)
      values.set(local_id, self.locals[local_id])
    }
    self.locals[local_id] = self.undo_values.pop().unwrap()
  }
  Some(writes)
}

///|
fn Dae2RawControlState::join_arms(
  self : Dae2RawControlState,
  yes : Dae2RawArmWrites?,
  no : Dae2RawArmWrites?,
) -> Unit {
  match yes {
    Some(yes) =>
      for local_id in yes.order {
        let other = match no {
          Some(no) => no.values.get(local_id).unwrap_or(self.locals[local_id])
          None => self.locals[local_id]
        }
        self.assign(
          local_id,
          self.plan.join(yes.values.get(local_id).unwrap(), other),
        )
      }
    None => ()
  }
  match no {
    Some(no) =>
      for local_id in no.order {
        let in_yes = match yes {
          Some(yes) => yes.values.get(local_id) is Some(_)
          None => false
        }
        if !in_yes {
          self.assign(
            local_id,
            self.plan.join(
              self.locals[local_id],
              no.values.get(local_id).unwrap(),
            ),
          )
        }
      }
    None => ()
  }
}

///|
// Leaf dependency contracts intentionally mirror the flat planner. The stack
// floor prevents an arm/block from consuming values belonging to its parent.
fn Dae2RawControlState::leaf(
  self : Dae2RawControlState,
  instr : @lib.Instruction,
  floor : Int,
) -> Bool {
  let stack = self.stack
  let plan = self.plan
  let arity = dae2_raw_pure_arity(instr)
  if arity >= 0 {
    if stack.length() - floor < arity {
      return false
    }
    if arity == 0 {
      let symbol = match instr {
        @lib.LocalGet(@lib.LocalIdx(raw)) => {
          let local_id = raw.reinterpret_as_int()
          if local_id < 0 || local_id >= self.locals.length() {
            return false
          }
          self.locals[local_id]
        }
        _ => -1
      }
      stack.push(symbol)
    } else if arity > 1 {
      let start = stack.length() - arity
      let mut symbol = stack[start]
      for slot in (start + 1)..<stack.length() {
        symbol = plan.join(symbol, stack[slot])
      }
      stack.truncate(start)
      stack.push(symbol)
    }
    return true
  }
  let observed = dae2_raw_observer_arity(instr)
  if observed >= 0 {
    if stack.length() - floor < observed {
      return false
    }
    let start = stack.length() - observed
    for slot in start..<stack.length() {
      plan.observations.push(stack[slot])
    }
    stack.truncate(start)
    return true
  }
  let producer = dae2_raw_observed_producer_arity(instr, self.context)
  if producer >= 0 {
    if stack.length() - floor < producer {
      return false
    }
    let start = stack.length() - producer
    for slot in start..<stack.length() {
      plan.observations.push(stack[slot])
    }
    stack.truncate(start)
    stack.push(-1)
    return true
  }
  match instr {
    @lib.Nop => true
    @lib.Drop => {
      if stack.length() == floor {
        return false
      }
      ignore(stack.pop())
      true
    }
    @lib.LocalSet(@lib.LocalIdx(raw)) | @lib.LocalTee(@lib.LocalIdx(raw)) => {
      let local_id = raw.reinterpret_as_int()
      if local_id < 0 ||
        local_id >= self.locals.length() ||
        stack.length() == floor {
        return false
      }
      let location = plan.write(local_id, stack[stack.length() - 1])
      self.assign(local_id, location)
      if instr is @lib.LocalSet(_) {
        ignore(stack.pop())
      } else {
        stack[stack.length() - 1] = location
      }
      true
    }
    @lib.Call(_) | @lib.CallIndirect(_, _) | @lib.CallRef(_) => {
      let (callee_index, indirect) = match instr {
        @lib.Call(@lib.FuncIdx(raw)) => (raw.reinterpret_as_int(), false)
        @lib.CallIndirect(type_idx, _) | @lib.CallRef(type_idx) => {
          let slot = dae2_type_slot(type_idx, 0)
          if slot < 0 || slot >= self.type_infos.length() {
            return false
          }
          (self.type_infos[slot], true)
        }
        _ => abort("DAE2 conditional call classifier is incomplete")
      }
      if callee_index < 0 || callee_index >= self.infos.length() {
        return false
      }
      match self.intrinsic_imports {
        Some(mask) if callee_index < mask.length() && mask[callee_index] =>
          return false
        _ => ()
      }
      let callee = self.infos[callee_index]
      let consumed = callee.params.length() + (if indirect { 1 } else { 0 })
      if stack.length() - floor < consumed {
        return false
      }
      let start = stack.length() - consumed
      for arg in 0..<callee.params.length() {
        plan.edge(callee.param_locations[arg], stack[start + arg])
      }
      if indirect {
        plan.observations.push(stack[stack.length() - 1])
      }
      stack.truncate(start)
      for _ in callee.results {
        stack.push(callee.result_location)
      }
      true
    }
    _ => false
  }
}

///|
fn dae2_raw_control_arity(bt : @lib.BlockType) -> Int {
  match bt {
    @lib.VoidBlockType => 0
    @lib.ValTypeBlockType(_) => 1
    _ => -1
  }
}

///|
fn Dae2RawControlState::body(
  self : Dae2RawControlState,
  instructions : Array[@lib.Instruction],
  floor : Int,
  result_count : Int,
  top : Bool,
) -> Bool {
  for position, instr in instructions {
    match instr {
      @lib.Block(bt, @lib.Expr(body)) => {
        let arity = dae2_raw_control_arity(bt)
        if arity < 0 || !self.body(body, self.stack.length(), arity, false) {
          return false
        }
      }
      @lib.If(bt, yes, no) => {
        let arity = dae2_raw_control_arity(bt)
        if arity < 0 || self.stack.length() == floor {
          return false
        }
        // HOT observes conditions even when every arm result is dead.
        self.plan.observations.push(self.stack.pop().unwrap())
        let arm_floor = self.stack.length()
        let mark = self.undo_locals.length()
        self.arm_depth += 1
        if !self.body(yes, arm_floor, arity, false) {
          return false
        }
        let yes_value = if arity == 1 { self.stack.pop().unwrap() } else { -1 }
        let yes_writes = self.restore_arm(mark)
        let no_value = match no {
          Some(body) => {
            if !self.body(body, arm_floor, arity, false) {
              return false
            }
            if arity == 1 {
              self.stack.pop().unwrap()
            } else {
              -1
            }
          }
          None => {
            if arity != 0 {
              return false
            }
            -1
          }
        }
        let no_writes = self.restore_arm(mark)
        self.arm_depth -= 1
        self.join_arms(yes_writes, no_writes)
        if arity == 1 {
          self.stack.push(self.plan.join(yes_value, no_value))
        }
      }
      @lib.Return =>
        if !top || position != instructions.length() - 1 {
          return false
        }
      _ => if !self.leaf(instr, floor) { return false }
    }
  }
  self.stack.length() == floor + result_count
}

///|
fn dae2_raw_conditional_dependency_plan(
  graph : Dae2Graph,
  infos : Array[Dae2Function],
  index : Int,
  type_infos : Array[Int],
  body : @lib.Func,
  intrinsic_imports : Array[Bool]?,
  context : @ir.HotModuleContext?,
) -> Dae2RawPlan? {
  let @lib.Func(locals, @lib.Expr(instructions)) = body
  // Collected call metadata can reject intrinsic bodies before allocating
  // symbolic state. The leaf classifier still guards callers without metadata.
  match intrinsic_imports {
    Some(mask) if infos[index].call_infos_ready =>
      for callee in infos[index].call_infos {
        if callee >= 0 && callee < mask.length() && mask[callee] {
          return None
        }
      }
    _ => ()
  }
  if !dae2_raw_conditional_qualified(instructions, context, false) {
    return None
  }
  let plan = Dae2RawPlan::new(graph.used.length())
  let state = Dae2RawControlState::new(
    plan,
    infos,
    index,
    type_infos,
    locals.length(),
    intrinsic_imports,
    context,
  )
  if !state.body(instructions, 0, infos[index].results.length(), true) {
    return None
  }
  for source in state.stack {
    plan.edge(infos[index].result_location, source)
  }
  Some(plan)
}
