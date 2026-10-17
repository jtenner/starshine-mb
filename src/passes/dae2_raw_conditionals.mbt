// Licensing scope: see ../../LICENSE and this directory's LICENSE and NOTICE.
// Potentially incorporated Binaryen expression retains Apache-2.0 terms.
// Original Starshine contributions use the scoped MIT grant in ../../LICENSE.
// Modified for Starshine through 2026: implementation and validation use
// Starshine's representations and APIs; this is not an unchanged upstream file.
// Conservative notice retention does not establish copying or independence.

///|
// The established flat planner runs first. This separate preflight accepts only
// no-input void/single-value controls and terminal returns/traps. Branches,
// loops, handlers and materialized dead tails stay HOT.
fn dae2_raw_conditional_qualified(
  instructions : Array[@lib.Instruction],
  context : @ir.HotModuleContext?,
) -> Bool {
  for instr in instructions {
    match instr {
      @lib.Block(bt, @lib.Expr(body)) =>
        if !(bt is @lib.VoidBlockType || bt is @lib.ValTypeBlockType(_)) ||
          !dae2_raw_conditional_qualified(body, context) {
          return false
        }
      @lib.If(bt, yes, no) => {
        if !(bt is @lib.VoidBlockType || bt is @lib.ValTypeBlockType(_)) ||
          !dae2_raw_conditional_qualified(yes, context) {
          return false
        }
        match no {
          Some(body) =>
            if !dae2_raw_conditional_qualified(body, context) {
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
      | @lib.CallRef(_)
      | @lib.Return
      | @lib.Unreachable => ()
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
  order : Array[Int32]
  values : @hashmap.HashMap[Int32, Int32]
}

///|
fn Dae2RawArmWrites::new() -> Dae2RawArmWrites {
  { order: [], values: @hashmap.new(), }
}

///|
priv struct Dae2RawControlState {
  plan : Dae2RawPlan
  infos : Array[Dae2Function]
  type_infos : Array[Int32]
  intrinsic_imports : Array[Bool]?
  context : @ir.HotModuleContext?
  result_location : Int32
  result_count : Int32
  stack : Array[Int32]
  locals : Array[Int32]
  undo_locals : Array[Int32]
  undo_values : Array[Int32]
  mut arm_depth : Int32
}

///|
fn Dae2RawControlState::new(
  plan : Dae2RawPlan,
  infos : Array[Dae2Function],
  index : Int32,
  type_infos : Array[Int32],
  local_count : Int32,
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
    result_location: info.result_location,
    result_count: info.results.length(),
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
  local_id : Int32,
  value : Int32,
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
  mark : Int32,
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
fn Dae2RawControlState::apply_arm(
  self : Dae2RawControlState,
  writes : Dae2RawArmWrites?,
) -> Unit {
  match writes {
    Some(writes) =>
      for local_id in writes.order {
        self.assign(local_id, writes.values.get(local_id).unwrap())
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
  floor : Int32,
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
fn dae2_raw_control_arity(bt : @lib.BlockType) -> Int32 {
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
  floor : Int32,
  result_count : Int32,
) -> Bool? {
  // None rejects qualification. Some(false) has no fallthrough; only the
  // surviving arm can supply definitions and results after a conditional.
  let mut falls_through = true
  for instr in instructions {
    if !falls_through {
      // HOT Drop has no DAE2 child demand, even for a concrete result slot
      // after a nonreturning control. These tails add no writes or exits.
      match instr {
        @lib.Drop | @lib.Nop | @lib.Unreachable => continue
        _ => return None
      }
    }
    match instr {
      @lib.Block(bt, @lib.Expr(body)) => {
        let arity = dae2_raw_control_arity(bt)
        if arity < 0 {
          return None
        }
        match self.body(body, self.stack.length(), arity) {
          Some(fallthrough) => falls_through = fallthrough
          None => return None
        }
      }
      @lib.If(bt, yes, no) => {
        let arity = dae2_raw_control_arity(bt)
        if arity < 0 || self.stack.length() == floor {
          return None
        }
        // HOT observes conditions even when every arm result is dead.
        self.plan.observations.push(self.stack.pop().unwrap())
        let arm_floor = self.stack.length()
        let mark = self.undo_locals.length()
        self.arm_depth += 1
        let yes_fallthrough = match self.body(yes, arm_floor, arity) {
          Some(fallthrough) => fallthrough
          None => return None
        }
        let yes_value = if yes_fallthrough && arity == 1 {
          self.stack.pop().unwrap()
        } else {
          -1
        }
        let yes_writes = self.restore_arm(mark)
        let (no_value, no_fallthrough) = match no {
          Some(body) => {
            let fallthrough = match self.body(body, arm_floor, arity) {
              Some(fallthrough) => fallthrough
              None => return None
            }
            let value = if fallthrough && arity == 1 {
              self.stack.pop().unwrap()
            } else {
              -1
            }
            (value, fallthrough)
          }
          None => {
            if arity != 0 {
              return None
            }
            (-1, true)
          }
        }
        let no_writes = self.restore_arm(mark)
        self.arm_depth -= 1
        match (yes_fallthrough, no_fallthrough) {
          (true, true) => self.join_arms(yes_writes, no_writes)
          (true, false) => self.apply_arm(yes_writes)
          (false, true) => self.apply_arm(no_writes)
          (false, false) => ()
        }
        falls_through = yes_fallthrough || no_fallthrough
        if falls_through && arity == 1 {
          // A terminated arm has no result source, represented by -1.
          self.stack.push(self.plan.join(yes_value, no_value))
        }
      }
      @lib.Return => {
        if self.stack.length() - floor < self.result_count {
          return None
        }
        let start = self.stack.length() - self.result_count
        for slot in start..<self.stack.length() {
          self.plan.edge(self.result_location, self.stack[slot])
        }
        falls_through = false
      }
      @lib.Unreachable => {
        // Unlike Return, HOT leaves preceding concrete values in the region's
        // roots at a trap. Decline this shape rather than omit those edges.
        if self.stack.length() != floor {
          return None
        }
        falls_through = false
      }
      _ => if !self.leaf(instr, floor) { return None }
    }
    if !falls_through {
      self.stack.truncate(floor)
    }
  }
  if !falls_through {
    Some(false)
  } else if self.stack.length() == floor + result_count {
    Some(true)
  } else {
    None
  }
}

///|
fn dae2_raw_conditional_dependency_plan(
  graph : Dae2Graph,
  infos : Array[Dae2Function],
  index : Int32,
  type_infos : Array[Int32],
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
  if !dae2_raw_conditional_qualified(instructions, context) {
    return dae2_raw_forward_dependency_plan(
      graph, infos, index, type_infos, body, intrinsic_imports, context,
    )
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
  match state.body(instructions, 0, infos[index].results.length()) {
    Some(_) => ()
    None => return None
  }
  for source in state.stack {
    plan.edge(infos[index].result_location, source)
  }
  Some(plan)
}
