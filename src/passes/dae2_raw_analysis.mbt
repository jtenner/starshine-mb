///|
// Symbols name only boundary locations or joins of distinct dependencies.
// Constants and default-initialized locals have symbol -1; unary operators
// alias their operand. Qualification never mutates the module-wide graph.
priv struct Dae2RawPlan {
  base : Int
  mut count : Int
  consumers : Array[Int]
  sources : Array[Int]
  observations : Array[Int]
}

///|
fn Dae2RawPlan::new(base : Int) -> Dae2RawPlan {
  { base, count: 0, consumers: [], sources: [], observations: [], }
}

///|
fn Dae2RawPlan::edge(self : Dae2RawPlan, consumer : Int, source : Int) -> Unit {
  if consumer >= 0 && source >= 0 {
    self.consumers.push(consumer)
    self.sources.push(source)
  }
}

///|
fn Dae2RawPlan::join(self : Dae2RawPlan, left : Int, right : Int) -> Int {
  if left < 0 {
    return right
  }
  if right < 0 || left == right {
    return left
  }
  let value = self.base + self.count
  self.count += 1
  self.edge(value, left)
  self.edge(value, right)
  value
}

///|
fn Dae2RawPlan::commit(self : Dae2RawPlan, graph : Dae2Graph) -> Unit {
  if graph.locations(self.count) != self.base {
    abort("DAE2 raw dependency plan lost its graph range")
  }
  for edge in 0..<self.sources.length() {
    graph.edge(self.consumers[edge], self.sources[edge])
  }
  for source in self.observations {
    graph.observe(source)
  }
}

///|
// Match pass_can_discard_unused_value's scalar numeric families. In particular,
// generic SIMD, integer division, trapping conversions and GC reads stay HOT.
fn dae2_raw_pure_arity(instr : @lib.Instruction) -> Int {
  match instr {
    @lib.I32Const(_)
    | @lib.I64Const(_)
    | @lib.F32Const(_)
    | @lib.F64Const(_)
    | @lib.V128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | @lib.StringConst(_)
    | @lib.RefNull(_)
    | @lib.RefFunc(_)
    | @lib.GlobalGet(_)
    | @lib.MemorySize(_)
    | @lib.TableSize(_)
    | @lib.LocalGet(_) => 0
    @lib.I32Eqz
    | @lib.I64Eqz
    | @lib.I32Clz
    | @lib.I32Ctz
    | @lib.I32Popcnt
    | @lib.I64Clz
    | @lib.I64Ctz
    | @lib.I64Popcnt
    | @lib.F32Abs
    | @lib.F32Neg
    | @lib.F32Ceil
    | @lib.F32Floor
    | @lib.F32Trunc
    | @lib.F32Nearest
    | @lib.F32Sqrt
    | @lib.F64Abs
    | @lib.F64Neg
    | @lib.F64Ceil
    | @lib.F64Floor
    | @lib.F64Trunc
    | @lib.F64Nearest
    | @lib.F64Sqrt
    | @lib.I32WrapI64
    | @lib.I64ExtendI32S
    | @lib.I64ExtendI32U
    | @lib.F32ConvertI32S
    | @lib.F32ConvertI32U
    | @lib.F32ConvertI64S
    | @lib.F32ConvertI64U
    | @lib.F32DemoteF64
    | @lib.F64ConvertI32S
    | @lib.F64ConvertI32U
    | @lib.F64ConvertI64S
    | @lib.F64ConvertI64U
    | @lib.F64PromoteF32
    | @lib.I32ReinterpretF32
    | @lib.I64ReinterpretF64
    | @lib.F32ReinterpretI32
    | @lib.F64ReinterpretI64
    | @lib.I32Extend8S
    | @lib.I32Extend16S
    | @lib.I64Extend8S
    | @lib.I64Extend16S
    | @lib.I64Extend32S
    | @lib.I32TruncSatF32S
    | @lib.I32TruncSatF32U
    | @lib.I32TruncSatF64S
    | @lib.I32TruncSatF64U
    | @lib.I64TruncSatF32S
    | @lib.I64TruncSatF32U
    | @lib.I64TruncSatF64S
    | @lib.I64TruncSatF64U
    | @lib.RefIsNull
    | @lib.RefTest(_, _, _) => 1
    @lib.I32Eq
    | @lib.I32Ne
    | @lib.I32LtS
    | @lib.I32LtU
    | @lib.I32GtS
    | @lib.I32GtU
    | @lib.I32LeS
    | @lib.I32LeU
    | @lib.I32GeS
    | @lib.I32GeU
    | @lib.I64Eq
    | @lib.I64Ne
    | @lib.I64LtS
    | @lib.I64LtU
    | @lib.I64GtS
    | @lib.I64GtU
    | @lib.I64LeS
    | @lib.I64LeU
    | @lib.I64GeS
    | @lib.I64GeU
    | @lib.F32Eq
    | @lib.F32Ne
    | @lib.F32Lt
    | @lib.F32Gt
    | @lib.F32Le
    | @lib.F32Ge
    | @lib.F64Eq
    | @lib.F64Ne
    | @lib.F64Lt
    | @lib.F64Gt
    | @lib.F64Le
    | @lib.F64Ge
    | @lib.I32Add
    | @lib.I32Sub
    | @lib.I32Mul
    | @lib.I32And
    | @lib.I32Or
    | @lib.I32Xor
    | @lib.I32Shl
    | @lib.I32ShrS
    | @lib.I32ShrU
    | @lib.I32Rotl
    | @lib.I32Rotr
    | @lib.I64Add
    | @lib.I64Sub
    | @lib.I64Mul
    | @lib.I64And
    | @lib.I64Or
    | @lib.I64Xor
    | @lib.I64Shl
    | @lib.I64ShrS
    | @lib.I64ShrU
    | @lib.I64Rotl
    | @lib.I64Rotr
    | @lib.F32Add
    | @lib.F32Sub
    | @lib.F32Mul
    | @lib.F32Div
    | @lib.F32Min
    | @lib.F32Max
    | @lib.F32Copysign
    | @lib.F64Add
    | @lib.F64Sub
    | @lib.F64Mul
    | @lib.F64Div
    | @lib.F64Min
    | @lib.F64Max
    | @lib.F64Copysign => 2
    @lib.Select(_) => 3
    _ => -1
  }
}

///|
fn dae2_raw_observer_arity(instr : @lib.Instruction) -> Int {
  match instr {
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
    _ => -1
  }
}

///|
// These HOT families always observe their inputs, even when their result is
// dropped. Constants proven nontrapping also have no boundary dependency.
fn dae2_raw_observed_producer_arity(
  instr : @lib.Instruction,
  context : @ir.HotModuleContext?,
) -> Int {
  match instr {
    @lib.StructNewDefault(_) => 0
    @lib.I32Load(_)
    | @lib.I64Load(_)
    | @lib.F32Load(_)
    | @lib.F64Load(_)
    | @lib.I32Load8S(_)
    | @lib.I32Load8U(_)
    | @lib.I32Load16S(_)
    | @lib.I32Load16U(_)
    | @lib.I64Load8S(_)
    | @lib.I64Load8U(_)
    | @lib.I64Load16S(_)
    | @lib.I64Load16U(_)
    | @lib.I64Load32S(_)
    | @lib.I64Load32U(_)
    | @lib.I32TruncF32S
    | @lib.I32TruncF32U
    | @lib.I32TruncF64S
    | @lib.I32TruncF64U
    | @lib.I64TruncF32S
    | @lib.I64TruncF32U
    | @lib.I64TruncF64S
    | @lib.I64TruncF64U
    | @lib.StructGet(_, _)
    | @lib.StructGetS(_, _)
    | @lib.StructGetU(_, _)
    | @lib.ArrayLen
    | @lib.ArrayNewDefault(_)
    | @lib.RefAsNonNull
    | @lib.AnyConvertExtern
    | @lib.ExternConvertAny
    | @lib.RefI31
    | @lib.RefI31Shared
    | @lib.I31GetS
    | @lib.I31GetU
    | @lib.RefCast(_, _, _)
    | @lib.TableGet(_)
    | @lib.MemoryGrow(_) => 1
    @lib.I32DivS
    | @lib.I32DivU
    | @lib.I32RemS
    | @lib.I32RemU
    | @lib.I64DivS
    | @lib.I64DivU
    | @lib.I64RemS
    | @lib.I64RemU
    | @lib.ArrayGet(_)
    | @lib.ArrayGetS(_)
    | @lib.ArrayGetU(_)
    | @lib.ArrayLoad(_, _, _)
    | @lib.ArrayNew(_)
    | @lib.ArrayNewData(_, _)
    | @lib.ArrayNewElem(_, _)
    | @lib.RefEq
    | @lib.TableGrow(_) => 2
    @lib.ArrayNewFixed(_, @lib.U32(count)) => count.reinterpret_as_int()
    @lib.StructNew(type_idx) =>
      match context {
        Some(context) =>
          match @ir.hot_module_resolve_subtype(context, type_idx) {
            Some(subtype) =>
              match subtype.get_comptype() {
                @lib.StructCompType(fields) => fields.length()
                _ => -1
              }
            None => -1
          }
        None => -1
      }
    _ => -1
  }
}

///|
// Flat bodies keep the original single preflight scan and shared instruction
// storage. Only a real block allocates a flattened candidate for rechecking.
fn dae2_raw_qualified_instructions(
  instructions : Array[@lib.Instruction],
  module_context : @ir.HotModuleContext?,
) -> Array[@lib.Instruction]? {
  // Reject unsupported control before allocating symbolic stack/edge data.
  for position in 0..<instructions.length() {
    let instr = instructions[position]
    if dae2_raw_pure_arity(instr) >= 0 ||
      dae2_raw_observer_arity(instr) >= 0 ||
      dae2_raw_observed_producer_arity(instr, module_context) >= 0 {
      continue
    }
    match instr {
      @lib.Nop
      | @lib.Drop
      | @lib.LocalSet(_)
      | @lib.LocalTee(_)
      | @lib.Call(_)
      | @lib.CallIndirect(_, _)
      | @lib.CallRef(_) => ()
      @lib.Return if position == instructions.length() - 1 => ()
      @lib.Block(_, _) => {
        let flattened = match
          dae2_raw_branchless_instructions(instructions, first_block=position) {
          Some(flattened) => flattened
          None => return None
        }
        return dae2_raw_qualified_instructions(flattened, module_context)
      }
      _ => return None
    }
  }
  Some(instructions)
}

///|
fn dae2_raw_dependency_plan(
  graph : Dae2Graph,
  infos : Array[Dae2Function],
  index : Int,
  type_infos : Array[Int],
  body : @lib.Func,
  intrinsic_imports : Array[Bool]?,
  module_context? : @ir.HotModuleContext? = None,
) -> Dae2RawPlan? {
  let @lib.Func(locals, @lib.Expr(original_instructions)) = body
  let instructions = match
    dae2_raw_qualified_instructions(original_instructions, module_context) {
    Some(instructions) => instructions
    None => return None
  }
  let info = infos[index]
  let plan = Dae2RawPlan::new(graph.used.length())
  let stack : Array[Int] = []
  let values = Array::make(info.params.length() + locals.length(), -1)
  for param in 0..<info.params.length() {
    values[param] = info.param_locations[param]
  }
  for instr in instructions {
    let arity = dae2_raw_pure_arity(instr)
    if arity >= 0 {
      if stack.length() < arity {
        return None
      }
      if arity == 0 {
        let symbol = match instr {
          @lib.LocalGet(@lib.LocalIdx(raw)) => {
            let local = raw.reinterpret_as_int()
            if local < 0 || local >= info.params.length() + locals.length() {
              return None
            }
            values[local]
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
      continue
    }
    let observed = dae2_raw_observer_arity(instr)
    if observed >= 0 {
      if stack.length() < observed {
        return None
      }
      let start = stack.length() - observed
      for slot in start..<stack.length() {
        plan.observations.push(stack[slot])
      }
      stack.truncate(start)
      continue
    }
    let producer = dae2_raw_observed_producer_arity(instr, module_context)
    if producer >= 0 {
      if stack.length() < producer {
        return None
      }
      let start = stack.length() - producer
      for slot in start..<stack.length() {
        plan.observations.push(stack[slot])
      }
      stack.truncate(start)
      stack.push(-1)
      continue
    }
    match instr {
      @lib.Nop => ()
      @lib.Drop => {
        if stack.is_empty() {
          return None
        }
        ignore(stack.pop())
      }
      @lib.LocalSet(@lib.LocalIdx(raw)) | @lib.LocalTee(@lib.LocalIdx(raw)) => {
        let local = raw.reinterpret_as_int()
        if local < 0 || local >= values.length() || stack.is_empty() {
          return None
        }
        values[local] = stack[stack.length() - 1]
        if instr is @lib.LocalSet(_) {
          ignore(stack.pop())
        }
      }
      @lib.Call(_) | @lib.CallIndirect(_, _) | @lib.CallRef(_) => {
        let (callee_index, indirect) = match instr {
          @lib.Call(@lib.FuncIdx(raw)) => (raw.reinterpret_as_int(), false)
          @lib.CallIndirect(type_idx, _) | @lib.CallRef(type_idx) => {
            let slot = dae2_type_slot(type_idx, 0)
            if slot < 0 || slot >= type_infos.length() {
              return None
            }
            (type_infos[slot], true)
          }
          _ => abort("DAE2 raw call classifier is incomplete")
        }
        if callee_index < 0 || callee_index >= infos.length() {
          return None
        }
        match intrinsic_imports {
          Some(mask) if callee_index < mask.length() && mask[callee_index] =>
            return None
          _ => ()
        }
        let callee = infos[callee_index]
        let consumed = callee.params.length() + (if indirect { 1 } else { 0 })
        if stack.length() < consumed {
          return None
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
      }
      @lib.Return => {
        if stack.length() != info.results.length() {
          return None
        }
        let start = stack.length() - info.results.length()
        for slot in start..<stack.length() {
          plan.edge(info.result_location, stack[slot])
        }
        return Some(plan)
      }
      _ => return None
    }
  }
  if stack.length() != info.results.length() {
    return None
  }
  for source in stack {
    plan.edge(info.result_location, source)
  }
  Some(plan)
}

///|
// Recreate expression liveness only for a body that will actually be rewritten.
// All known boundary locations seed a fresh graph before any edges are added;
// the module graph remains solved and sealed throughout the rewrite phase.
fn Dae2Graph::for_raw_rewrite(
  self : Dae2Graph,
  boundary_count : Int,
) -> Dae2Graph {
  let replay = Dae2Graph::new()
  ignore(replay.locations(boundary_count))
  for location in 0..<boundary_count {
    if self.used[location] {
      replay.observe(location)
    }
  }
  replay
}

///|
// One per-module workspace retains only its largest rewritten flat body.
// Boundary IDs stay stable; previous expression edges and work never survive.
fn Dae2Graph::reset_for_raw_rewrite(
  self : Dae2Graph,
  source : Dae2Graph,
  boundary_count : Int,
) -> Unit {
  self.cursor = 0
  self.edges.clear()
  self.next_edge.clear()
  self.work.clear()
  self.first_edge.clear()
  self.last_edge.clear()
  self.used.clear()
  ignore(self.locations(boundary_count))
  for location in 0..<boundary_count {
    if source.used[location] {
      self.observe(location)
    }
  }
}
