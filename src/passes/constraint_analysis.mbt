///|
fn constraint_analysis_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new(
    "constraint-analysis",
    requires=[@ir.HotAnalysis::cfg()],
    invalidates=[
      @ir.HotAnalysis::cfg(),
      @ir.HotAnalysis::dominance(),
      @ir.HotAnalysis::liveness(),
      @ir.HotAnalysis::use_def(),
      @ir.HotAnalysis::effects(),
      @ir.HotAnalysis::loop_info(),
      @ir.HotAnalysis::ssa(),
    ],
  )
}

///|
priv struct CaValue {
  range : CaRange?
  nullness : Int // 1=null, 2=non-null, 3=unknown; zero is bottom.
} derive(Eq, @debug.Debug)

///|
fn ca_unknown() -> CaValue {
  { range: None, nullness: 3, }
}

///|
fn ca_integer(range : CaRange) -> CaValue {
  { range: Some(range), nullness: 3, }
}

///|
fn ca_value_type(ty : @lib.ValType, zero : Bool) -> CaValue {
  match ty {
    @lib.NumTypeValType(@lib.I32NumType) =>
      ca_integer(if zero { ca_exact(32, 0UL) } else { ca_top(32) })
    @lib.NumTypeValType(@lib.I64NumType) =>
      ca_integer(if zero { ca_exact(64, 0UL) } else { ca_top(64) })
    @lib.RefTypeValType(ref_type) =>
      {
        range: None,
        nullness: if !ref_type.is_nullable() {
          2
        } else if zero {
          1
        } else {
          3
        },
      }
    _ => ca_unknown()
  }
}

///|
fn ca_value_join(a : CaValue, b : CaValue) -> CaValue {
  {
    range: match (a.range, b.range) {
      (Some(x), Some(y)) if x.bits == y.bits => Some(ca_union(x, y))
      _ => None
    },
    nullness: a.nullness | b.nullness,
  }
}

///|
priv struct CaRelation {
  left : Int
  right : Int
  bits : Int
  signed : Bool
  relation : Int
} derive(Eq, @debug.Debug)

///|
priv struct CaState {
  mut reachable : Bool
  locals : Array[CaValue]
  versions : Array[Int]
  relations : Array[CaRelation]
} derive(Eq, @debug.Debug)

///|
fn CaState::copy(self : CaState) -> CaState {
  {
    reachable: self.reachable,
    locals: self.locals.copy(),
    versions: self.versions.copy(),
    relations: self.relations.copy(),
  }
}

///|
fn ca_state_join(a : CaState, b : CaState) -> CaState {
  if !a.reachable {
    return b.copy()
  }
  if !b.reachable {
    return a.copy()
  }
  {
    reachable: true,
    locals: Array::makei(a.locals.length(), fn(i) {
      ca_value_join(a.locals[i], b.locals[i])
    }),
    versions: a.versions.copy(),
    relations: a.relations.filter(fn(fact) { b.relations.contains(fact) }),
  }
}

///|
fn ca_state_equal(a : CaState, b : CaState) -> Bool {
  a.reachable == b.reachable &&
  (!a.reachable || (a.locals == b.locals && a.relations == b.relations))
}

///|
fn ca_write(state : CaState, index : Int, value : CaValue) -> Unit {
  state.locals[index] = value
  state.versions[index] += 1
  for i = state.relations.length() - 1; i >= 0; i = i - 1 {
    let fact = state.relations[i]
    if fact.left == index || fact.right == index {
      ignore(state.relations.remove(i))
    }
  }
}

///|
priv struct CaEval {
  value : CaValue
  binding : Int
  version : Int
}

///|
fn ca_evaluated(value : CaValue) -> CaEval {
  { value, binding: -1, version: -1, }
}

///|
fn ca_live_binding(state : CaState, value : CaEval) -> Int {
  if value.binding >= 0 && state.versions[value.binding] == value.version {
    value.binding
  } else {
    -1
  }
}

///|
fn ca_assume_null(state : CaState, value : CaEval, is_null : Bool) -> Unit {
  let mask = if is_null { 1 } else { 2 }
  if (value.value.nullness & mask) == 0 {
    state.reachable = false
  }
  let index = ca_live_binding(state, value)
  if index >= 0 {
    let nullness = state.locals[index].nullness & mask
    if nullness == 0 {
      state.reachable = false
    }
    state.locals[index] = { range: None, nullness, }
  }
}

///|
// Width belongs to the compared operands, not the i32 predicate result.
fn ca_comparison(instr : @lib.Instruction?) -> (Int, Int, Bool)? {
  match instr {
    Some(@lib.Instruction::I32Eq) => Some((32, 2, false))
    Some(@lib.Instruction::I32Ne) => Some((32, 5, false))
    Some(@lib.Instruction::I32LtS) => Some((32, 1, true))
    Some(@lib.Instruction::I32LtU) => Some((32, 1, false))
    Some(@lib.Instruction::I32LeS) => Some((32, 3, true))
    Some(@lib.Instruction::I32LeU) => Some((32, 3, false))
    Some(@lib.Instruction::I32GtS) => Some((32, 4, true))
    Some(@lib.Instruction::I32GtU) => Some((32, 4, false))
    Some(@lib.Instruction::I32GeS) => Some((32, 6, true))
    Some(@lib.Instruction::I32GeU) => Some((32, 6, false))
    Some(@lib.Instruction::I64Eq) => Some((64, 2, false))
    Some(@lib.Instruction::I64Ne) => Some((64, 5, false))
    Some(@lib.Instruction::I64LtS) => Some((64, 1, true))
    Some(@lib.Instruction::I64LtU) => Some((64, 1, false))
    Some(@lib.Instruction::I64LeS) => Some((64, 3, true))
    Some(@lib.Instruction::I64LeU) => Some((64, 3, false))
    Some(@lib.Instruction::I64GtS) => Some((64, 4, true))
    Some(@lib.Instruction::I64GtU) => Some((64, 4, false))
    Some(@lib.Instruction::I64GeS) => Some((64, 6, true))
    Some(@lib.Instruction::I64GeU) => Some((64, 6, false))
    _ => None
  }
}

///|
fn ca_boolean(value : Bool) -> CaValue {
  ca_integer(ca_exact(32, if value { 1UL } else { 0UL }))
}

///|
fn ca_unknown_boolean() -> CaValue {
  ca_integer(ca_range(32, [{ lo: 0UL, hi: 1UL, }]))
}

///|
fn ca_compare_references(
  state : CaState,
  left : CaEval,
  right : CaEval,
) -> CaValue {
  let l = ca_live_binding(state, left)
  let r = ca_live_binding(state, right)
  if (l >= 0 && l == r) ||
    (left.value.nullness == 1 && right.value.nullness == 1) {
    return ca_boolean(true)
  }
  if (left.value.nullness & right.value.nullness) == 0 {
    return ca_boolean(false)
  }
  for fact in state.relations {
    if fact.bits == 0 &&
      (
        (fact.left == l && fact.right == r) ||
        (fact.left == r && fact.right == l)
      ) {
      if fact.relation == 2 {
        return ca_boolean(true)
      }
      if fact.relation == 5 {
        return ca_boolean(false)
      }
    }
  }
  ca_unknown_boolean()
}

///|
fn ca_compare_values(
  state : CaState,
  left : CaEval,
  right : CaEval,
  relation : Int,
  signed : Bool,
) -> CaValue {
  let mut possible = match (left.value.range, right.value.range) {
    (Some(a), Some(b)) if a.bits == b.bits => ca_relation_possible(a, b, signed)
    _ => return ca_unknown_boolean()
  }
  let l = ca_live_binding(state, left)
  let r = ca_live_binding(state, right)
  if l >= 0 && r >= 0 {
    if l == r {
      possible = 2
    }
    for fact in state.relations {
      if fact.signed == signed || fact.relation == 2 || fact.relation == 5 {
        if fact.left == l && fact.right == r {
          possible = possible & fact.relation
        }
        if fact.left == r && fact.right == l {
          possible = possible & ca_flip(fact.relation)
        }
      }
    }
  }
  if possible != 0 && (possible & relation) == possible {
    ca_boolean(true)
  } else if possible != 0 && (possible & relation) == 0 {
    ca_boolean(false)
  } else {
    ca_unknown_boolean()
  }
}

///|
fn ca_refine_value(
  state : CaState,
  value : CaEval,
  constraint : CaRange,
) -> Unit {
  let index = ca_live_binding(state, value)
  if index < 0 {
    return
  }
  for equal_local in ca_equal_locals(state, index) {
    match state.locals[equal_local].range {
      Some(old) if old.bits == constraint.bits => {
        let range = ca_intersect(old, constraint)
        if range.spans.is_empty() {
          state.reachable = false
        }
        state.locals[equal_local] = ca_integer(range)
      }
      _ => ()
    }
  }
}

///|
fn ca_relation_range_from_range(
  bits : Int,
  relation : Int,
  signed : Bool,
  other : CaRange,
) -> CaRange {
  let sign = if signed { 1UL << (bits - 1) } else { 0UL }
  let ranked = ca_add(other, sign)
  let mut result = ca_range(bits, [])
  for span in ranked.spans {
    if (relation & 1) != 0 {
      result = ca_union(
        result,
        ca_relation_range(bits, 1, signed, span.hi ^ sign),
      )
    }
    if (relation & 2) != 0 {
      result = ca_union(
        result,
        ca_add(ca_range(bits, [{ lo: span.lo, hi: span.hi, }]), sign),
      )
    }
    if (relation & 4) != 0 {
      result = ca_union(
        result,
        ca_relation_range(bits, 4, signed, span.lo ^ sign),
      )
    }
  }
  result
}

///|
fn ca_assume_comparison(
  state : CaState,
  left : CaEval,
  right : CaEval,
  bits : Int,
  relation : Int,
  signed : Bool,
) -> Unit {
  match right.value.range {
    Some(range) if range.bits == bits =>
      ca_refine_value(
        state,
        left,
        ca_relation_range_from_range(bits, relation, signed, range),
      )
    _ => ()
  }
  match left.value.range {
    Some(range) if range.bits == bits =>
      ca_refine_value(
        state,
        right,
        ca_relation_range_from_range(bits, ca_flip(relation), signed, range),
      )
    _ => ()
  }
  let l = ca_live_binding(state, left)
  let r = ca_live_binding(state, right)
  if l >= 0 && r >= 0 {
    ca_record_relation(state, l, r, bits, signed, relation)
  }
}

///|
fn ca_assume(
  func : @ir.HotFunc,
  state : CaState,
  values : Array[CaEval?],
  node : Int,
  truth : Bool,
  depth : Int,
) -> CaState {
  if !state.reachable || depth > 64 {
    return state
  }
  let evaluated = match values[node] {
    Some(value) => value
    None => return state
  }
  match evaluated.value.range {
    Some(range) =>
      if (truth && ca_single(range) == Some(0UL)) ||
        (!truth && !ca_contains(range, 0UL)) {
        state.reachable = false
        return state
      }
    None => ()
  }
  let children = @ir.hot_child_span(func, node)
  let instr = @ir.hot_node_exact_instr(func, node)
  if (
      instr is Some(@lib.Instruction::I32Eqz) ||
      instr is Some(@lib.Instruction::I64Eqz)
    ) &&
    children.length() == 1 {
    let child = children[0]
    return ca_assume(func, state, values, child, !truth, depth + 1)
  }
  if (
      instr is Some(@lib.Instruction::I32And) ||
      instr is Some(@lib.Instruction::I32Or)
    ) &&
    children.length() == 2 {
    let left = values[children[0]]
    let right = values[children[1]]
    let boolean = fn(value : CaEval?) {
      match value {
        Some(v) =>
          match v.value.range {
            Some(r) => r.spans.all(fn(s) { s.hi <= 1UL })
            None => false
          }
        None => false
      }
    }
    if boolean(left) && boolean(right) {
      let is_and = instr is Some(@lib.Instruction::I32And)
      if is_and == truth {
        let next = ca_assume(func, state, values, children[0], truth, depth + 1)
        return ca_assume(func, next, values, children[1], truth, depth + 1)
      }
      return ca_state_join(
        ca_assume(func, state.copy(), values, children[0], truth, depth + 1),
        ca_assume(func, state, values, children[1], truth, depth + 1),
      )
    }
  }
  match ca_comparison(instr) {
    Some((bits, mask, signed)) if children.length() == 2 => {
      match (values[children[0]], values[children[1]]) {
        (Some(left), Some(right)) =>
          ca_assume_comparison(
            state,
            left,
            right,
            bits,
            if truth {
              mask
            } else {
              ca_not(mask)
            },
            signed,
          )
        _ => ()
      }
      return state
    }
    _ => ()
  }
  if instr is Some(@lib.Instruction::RefEq) && children.length() == 2 {
    match (values[children[0]], values[children[1]]) {
      (Some(left), Some(right)) => {
        if right.value.nullness == 1 {
          ca_assume_null(state, left, truth)
        }
        if left.value.nullness == 1 {
          ca_assume_null(state, right, truth)
        }
        ca_assume_comparison(
          state,
          left,
          right,
          0,
          if truth {
            2
          } else {
            5
          },
          false,
        )
      }
      _ => ()
    }
    return state
  }
  if @ir.hot_node_get(func, node).op is @ir.RefIsNull && children.length() == 1 {
    match values[children[0]] {
      Some(value) => {
        let index = ca_live_binding(state, value)
        if index >= 0 {
          let nullness = state.locals[index].nullness &
            (if truth { 1 } else { 2 })
          if nullness == 0 {
            state.reachable = false
          }
          state.locals[index] = { range: None, nullness, }
        }
      }
      None => ()
    }
  } else {
    match evaluated.value.range {
      Some(range) =>
        ca_refine_value(
          state,
          evaluated,
          ca_relation_range(range.bits, if truth { 5 } else { 2 }, false, 0UL),
        )
      None => ()
    }
  }
  state
}

///|
fn ca_node_type_value(func : @ir.HotFunc, node : Int) -> CaValue {
  let types = @ir.hot_type_results(func, @ir.hot_node_type(func, node))
  if types.length() == 1 {
    ca_value_type(types[0], false)
  } else {
    ca_unknown()
  }
}

///|
priv struct CaBlockEval {
  state : CaState
  fast_math : Bool
  expression_blocks : Array[Int]
  loop_plan : CaLoopPlan
  values : Array[CaEval?]
  touched : Array[Int]
  mut condition : Int
  mut conditional_branch : Bool
  mut null_branch : Int
  proofs : Array[(Int, Int)]
  mut exhausted : Bool
}

///|
fn ca_eval_node(
  func : @ir.HotFunc,
  cfg : @ir.HotCfg,
  block : Int,
  eval : CaBlockEval,
  node : Int,
  depth : Int,
) -> CaEval {
  if depth > 512 {
    eval.exhausted = true
    return ca_evaluated(ca_node_type_value(func, node))
  }
  if eval.values[node] is Some(value) {
    return value
  }
  let data = @ir.hot_node_get(func, node)
  let children = @ir.hot_child_span(func, node)
  let mut parameter_slot = -1
  let mut parameter_depth = -1
  for parameter in eval.loop_plan.block_parameters[block] {
    let (producer, slot) = parameter
    let scope_depth = eval.loop_plan.depths[slot -
      eval.loop_plan.local_types.length()]
    if producer == node && scope_depth > parameter_depth {
      parameter_slot = slot
      parameter_depth = scope_depth
    }
  }
  if parameter_slot >= 0 {
    let slot = parameter_slot
    let value = if @ir.hot_node_result_arity(func, node) == 1 {
      {
        value: eval.state.locals[slot],
        binding: slot,
        version: eval.state.versions[slot],
      }
    } else {
      ca_evaluated(ca_unknown())
    }
    eval.touched.push(node)
    eval.values[node] = Some(value)
    return value
  }
  if @ir.hot_is_control_node(func, node) {
    if data.op is @ir.Block && @ir.hot_node_result_arity(func, node) == 1 {
      let body = @ir.hot_region_body_ref(func, node)
      if @ir.hot_region_root_count(func, body) == 1 {
        let source = @ir.hot_region_get(func, body, 0)
        if @ir.hot_node_get(func, source).op is @ir.LocalGet {
          let value = ca_eval_node(func, cfg, block, eval, source, depth + 1)
          eval.touched.push(node)
          eval.values[node] = Some(value)
          return value
        }
      }
    }
    if data.op is @ir.Loop {
      let slots = eval.loop_plan.loop_slots[node]
      let initial = Array::makei(slots.length(), fn(index) {
        ca_eval_node(func, cfg, block, eval, children[index], depth + 1).value
      })
      for index = 0; index < slots.length(); index = index + 1 {
        ca_write(eval.state, slots[index], initial[index])
      }
    }
    if data.op is @ir.If {
      ignore(ca_eval_node(func, cfg, block, eval, children[0], depth + 1))
      eval.condition = children[0]
    }
    // CFG owns control-region execution. For a nested shape absent from this
    // CFG, forget local facts and decline its rewrites rather than linearize it.
    if eval.expression_blocks[node] != block {
      for index = 0; index < eval.state.locals.length(); index = index + 1 {
        ca_write(
          eval.state,
          index,
          ca_value_type(ca_slot_type(eval.loop_plan, index), false),
        )
      }
      eval.condition = -1
    }
    let value = ca_evaluated(ca_node_type_value(func, node))
    eval.touched.push(node)
    eval.values[node] = Some(value)
    return value
  }
  let args = children.map(fn(child) {
    ca_eval_node(func, cfg, block, eval, child, depth + 1)
  })
  let instr = @ir.hot_node_exact_instr(func, node)
  let mut value = ca_evaluated(ca_node_type_value(func, node))
  match data.op {
    @ir.Const =>
      match @ir.hot_const_get(func, data.imm0) {
        @ir.HotConstPayload::I32Const(@lib.I32(n)) =>
          value = ca_evaluated(
            ca_integer(ca_exact(32, n.reinterpret_as_uint().to_uint64())),
          )
        @ir.HotConstPayload::I64Const(@lib.I64(n)) =>
          value = ca_evaluated(
            ca_integer(ca_exact(64, n.reinterpret_as_uint64())),
          )
        _ => ()
      }
    @ir.LocalGet => {
      let slot = eval.loop_plan.local_slots[data.imm0]
      if slot >= 0 {
        value = {
          value: eval.state.locals[slot],
          binding: slot,
          version: eval.state.versions[slot],
        }
      }
    }
    @ir.LocalSet | @ir.LocalTee =>
      if args.length() == 1 {
        let slot = eval.loop_plan.local_slots[data.imm0]
        let source = ca_live_binding(eval.state, args[0])
        if slot < 0 {
          value = ca_evaluated(args[0].value)
        } else {
          if source == slot {
            // An exact self-copy preserves relational facts, but old evaluated
            // bindings still receive a fresh write version.
            eval.state.locals[slot] = args[0].value
            eval.state.versions[slot] += 1
          } else {
            ca_write(eval.state, slot, args[0].value)
            if source >= 0 {
              let bits = match args[0].value.range {
                Some(range) => Some(range.bits)
                None =>
                  match ca_slot_type(eval.loop_plan, source) {
                    @lib.RefTypeValType(_) => Some(0)
                    _ => None
                  }
              }
              match bits {
                Some(bits) =>
                  ca_record_relation(eval.state, source, slot, bits, false, 2)
                None => ()
              }
            }
          }
          value = {
            value: args[0].value,
            binding: slot,
            version: eval.state.versions[slot],
          }
        }
      }
    @ir.RefNull => value = ca_evaluated({ range: None, nullness: 1, })
    @ir.RefFunc => value = ca_evaluated({ range: None, nullness: 2, })
    @ir.RefIsNull =>
      if args.length() == 1 {
        value = ca_evaluated(
          if args[0].value.nullness == 1 {
            ca_boolean(true)
          } else if args[0].value.nullness == 2 {
            ca_boolean(false)
          } else {
            ca_unknown_boolean()
          },
        )
      }
    @ir.BrIf => {
      eval.condition = if children.is_empty() {
        -1
      } else {
        children[children.length() - 1]
      }
      eval.conditional_branch = true
    }
    @ir.BrOnNull | @ir.BrOnNonNull => {
      eval.condition = if children.is_empty() {
        -1
      } else {
        children[children.length() - 1]
      }
      eval.conditional_branch = true
      eval.null_branch = if data.op is @ir.BrOnNull { 1 } else { 2 }
    }
    _ => ()
  }
  match ca_comparison(instr) {
    Some((_, relation, signed)) if args.length() == 2 =>
      value = ca_evaluated(
        ca_compare_values(eval.state, args[0], args[1], relation, signed),
      )
    _ => ()
  }
  match instr {
    Some(@lib.Instruction::F32Eq) | Some(@lib.Instruction::F64Eq) =>
      if eval.fast_math && children.length() == 2 {
        let left = @ir.hot_node_get(func, children[0])
        let right = @ir.hot_node_get(func, children[1])
        if left.op is @ir.LocalGet &&
          right.op is @ir.LocalGet &&
          left.imm0 == right.imm0 {
          value = ca_evaluated(ca_boolean(true))
        }
      }
    Some(@lib.Instruction::RefEq) =>
      if args.length() == 2 {
        value = ca_evaluated(
          ca_compare_references(eval.state, args[0], args[1]),
        )
      }
    Some(@lib.Instruction::I32Eqz) | Some(@lib.Instruction::I64Eqz) =>
      if args.length() == 1 {
        value = ca_evaluated(
          match args[0].value.range {
            Some(range) =>
              if ca_single(range) == Some(0UL) {
                ca_boolean(true)
              } else if !ca_contains(range, 0UL) {
                ca_boolean(false)
              } else {
                ca_unknown_boolean()
              }
            None => ca_unknown_boolean()
          },
        )
      }
    Some(@lib.Instruction::I32Add)
    | Some(@lib.Instruction::I64Add)
    | Some(@lib.Instruction::I32Sub)
    | Some(@lib.Instruction::I64Sub) =>
      if args.length() == 2 {
        match (args[0].value.range, args[1].value.range) {
          (Some(left), Some(right)) => {
            let subtract = instr is Some(@lib.Instruction::I32Sub) ||
              instr is Some(@lib.Instruction::I64Sub)
            match ca_single(right) {
              Some(increment) =>
                value = ca_evaluated(
                  ca_integer(
                    ca_add(
                      left,
                      if subtract {
                        0UL - increment
                      } else {
                        increment
                      },
                    ),
                  ),
                )
              None =>
                if !subtract {
                  match ca_single(left) {
                    Some(increment) =>
                      value = ca_evaluated(ca_integer(ca_add(right, increment)))
                    None => ()
                  }
                }
            }
          }
          _ => ()
        }
      }
    Some(@lib.Instruction::I32And) | Some(@lib.Instruction::I32Or) =>
      if args.length() == 2 {
        match (args[0].value.range, args[1].value.range) {
          (Some(left), Some(right)) if left.spans.all(fn(s) { s.hi <= 1UL }) &&
            right.spans.all(fn(s) { s.hi <= 1UL }) => {
            let possibilities : Array[CaSpan] = []
            for l = 0; l <= 1; l = l + 1 {
              for r = 0; r <= 1; r = r + 1 {
                if ca_contains(left, l.to_uint64()) &&
                  ca_contains(right, r.to_uint64()) {
                  let n = if instr is Some(@lib.Instruction::I32And) {
                    l & r
                  } else {
                    l | r
                  }
                  possibilities.push({ lo: n.to_uint64(), hi: n.to_uint64(), })
                }
              }
            }
            value = ca_evaluated(ca_integer(ca_range(32, possibilities)))
          }
          _ => ()
        }
      }
    _ => ()
  }
  let predicate = ca_comparison(instr) is Some(_) ||
    (
      eval.fast_math &&
      (
        instr is Some(@lib.Instruction::F32Eq) ||
        instr is Some(@lib.Instruction::F64Eq)
      )
    ) ||
    data.op is @ir.RefIsNull ||
    instr is Some(@lib.Instruction::RefEq) ||
    instr is Some(@lib.Instruction::I32Eqz) ||
    instr is Some(@lib.Instruction::I64Eqz)
  if predicate && eval.state.reachable {
    let mut proven = -1
    match value.value.range {
      Some(range) =>
        match ca_single(range) {
          Some(n) if n <= 1UL => proven = n.to_int()
          _ => ()
        }
      None => ()
    }
    // A shared node must be proved on every path where it is evaluated.
    eval.proofs.push((node, proven))
  }
  eval.touched.push(node)
  eval.values[node] = Some(value)
  value
}

///|
fn ca_evaluate_block(
  func : @ir.HotFunc,
  cfg : @ir.HotCfg,
  block : Int,
  input : CaState,
  expression_blocks : Array[Int],
  loop_plan : CaLoopPlan,
  values : Array[CaEval?],
  touched : Array[Int],
  fast_math : Bool,
) -> CaBlockEval {
  // Only these entries belong to the preceding block evaluation. Clearing the
  // sparse frontier avoids allocating a whole-function table for every edge
  // revisit while retaining the same block-owned expression facts.
  while !touched.is_empty() {
    values[touched.pop().unwrap()] = None
  }
  let eval : CaBlockEval = {
    state: input.copy(),
    fast_math,
    expression_blocks,
    loop_plan,
    values,
    touched,
    condition: -1,
    conditional_branch: false,
    null_branch: 0,
    proofs: [],
    exhausted: false,
  }
  for root in cfg.blocks[block].nodes {
    ignore(ca_eval_node(func, cfg, block, eval, root, 0))
  }
  eval
}

///|
fn ca_initial_state(func : @ir.HotFunc, loop_plan : CaLoopPlan) -> CaState {
  let locals = Array::makei(loop_plan.local_types.length(), fn(slot) {
    ca_value_type(
      loop_plan.local_types[slot],
      loop_plan.local_ids[slot] >= @ir.hot_param_count(func),
    )
  })
  for ty in loop_plan.types {
    locals.push(ca_value_type(ty, false))
  }
  {
    reachable: true,
    locals,
    versions: Array::make(locals.length(), 0),
    relations: [],
  }
}

///|
fn ca_replace_predicate(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node : Int,
  value : Int,
) -> Unit {
  let children = @ir.hot_child_span(func, node)
  let retained : Array[Int] = []
  for child in children {
    ca_preserve_evaluation(func, child, retained, 0)
  }
  if retained.is_empty() {
    precompute_replace_with_const_i32(ctx, func, node, @lib.I32(value))
  } else {
    retained.push(@ir.hot_build_const_i32(func, @lib.I32(value)))
    let block = @ir.hot_build_block(
      func,
      @lib.BlockType::val_type(@lib.ValType::i32()),
      retained,
    )
    let replacement = @ir.hot_node_get(func, block)
    precompute_replace_node_rehoming_control_label(func, node, replacement)
    @ir.hot_delete_node(func, block)
    pass_mark_mutated(ctx, func)
  }
}

///|
fn ca_preserve_evaluation(
  func : @ir.HotFunc,
  node : Int,
  retained : Array[Int],
  depth : Int,
) -> Unit {
  // A local read participates in motion dependencies but is harmless to drop.
  // Strip only nontrapping value operations, keeping their children in order.
  if depth < 512 &&
    (
      pass_can_discard_unused_value(func, node) ||
      @ir.hot_node_exact_instr(func, node) is Some(@lib.Instruction::RefEq)
    ) {
    for child in @ir.hot_child_span(func, node) {
      ca_preserve_evaluation(func, child, retained, depth + 1)
    }
  } else {
    retained.push(dae2_discard(func, node))
  }
}

///|
fn constraint_analysis_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> HotPassResult {
  let cfg = pass_require_cfg(ctx, func)
  if cfg.entry_block < 0 {
    return HotPassResult::unchanged()
  }
  let expression_blocks = cfg.node_to_block.copy()
  for block in cfg.blocks {
    for root in block.nodes {
      if @ir.hot_node_get(func, root).op is @ir.Drop {
        let child = @ir.hot_child_get(func, root, 0)
        if child >= 0 {
          match @ir.hot_node_get(func, child).op {
            @ir.BrIf
            | @ir.BrOnNull
            | @ir.BrOnNonNull
            | @ir.BrOnCast
            | @ir.BrOnCastFail => expression_blocks[child] = block.id
            @ir.If if block.succs.length() >= 2 =>
              expression_blocks[child] = block.id
            _ => ()
          }
        }
      }
    }
  }
  // Do not infer absence of an incoming branch from an incomplete CFG view.
  for node = 0; node < @ir.hot_node_count(func); node = node + 1 {
    if @ir.hot_node_is_live(func, node) &&
      (
        @ir.hot_branch_target(func, node) is Some(_) ||
        !@ir.hot_branch_table_targets_for_node(func, node).is_empty() ||
        !@ir.hot_continuation_targets(func, node).is_empty() ||
        (
          @ir.hot_node_get(func, node).op is @ir.TryTable &&
          !@ir.hot_catch_info_get(func, @ir.hot_node_get(func, node).imm1).catches.is_empty()
        )
      ) &&
      expression_blocks[node] < 0 {
      return HotPassResult::unchanged()
    }
  }
  let thresholds : Array[UInt64] = [
    0UL, 1UL, 0x7fffffffUL, 0x80000000UL, 0xffffffffUL, 0x7fffffffffffffffUL, 0x8000000000000000UL,
    0xffffffffffffffffUL,
  ]
  for node = 0; node < @ir.hot_node_count(func); node = node + 1 {
    if @ir.hot_node_get(func, node).op is @ir.Const {
      match @ir.hot_const_get(func, @ir.hot_node_get(func, node).imm0) {
        @ir.HotConstPayload::I32Const(@lib.I32(n)) =>
          thresholds.push(n.reinterpret_as_uint().to_uint64())
        @ir.HotConstPayload::I64Const(@lib.I64(n)) =>
          thresholds.push(n.reinterpret_as_uint64())
        _ => ()
      }
    }
  }
  let loop_plan = ca_loop_plan(func, cfg)
  let values : Array[CaEval?] = Array::make(@ir.hot_node_count(func), None)
  let touched : Array[Int] = []
  let states : Array[CaState?] = Array::make(cfg.blocks.length(), None)
  states[cfg.entry_block] = Some(ca_initial_state(func, loop_plan))
  let queue = [cfg.entry_block]
  let queued = Array::make(cfg.blocks.length(), false)
  queued[cfg.entry_block] = true
  let visits = Array::make(cfg.blocks.length(), 0)
  // Budget is a refusal to rewrite, never a partially established proof.
  let budget = 64 * (cfg.blocks.length() + @ir.hot_node_count(func) + 1)
  for cursor = 0; cursor < queue.length(); cursor = cursor + 1 {
    if cursor >= budget {
      return HotPassResult::unchanged()
    }
    let block = queue[cursor]
    queued[block] = false
    let input = states[block].unwrap()
    if !input.reachable {
      continue
    }
    visits[block] += 1
    let eval = ca_evaluate_block(
      func,
      cfg,
      block,
      input,
      expression_blocks,
      loop_plan,
      values,
      touched,
      ctx.fast_math,
    )
    if eval.exhausted {
      return HotPassResult::unchanged()
    }
    let successors = cfg.blocks[block].succs
    for edge_index = 0
        edge_index < successors.length()
        edge_index = edge_index + 1 {
      let edge = successors[edge_index]
      let mut output = eval.state.copy()
      if edge.kind is @ir.ExceptionalEdge {
        // A trap/throw may happen before a later local assignment in this block.
        for index = 0; index < output.locals.length(); index = index + 1 {
          ca_write(
            output,
            index,
            ca_value_type(ca_slot_type(loop_plan, index), false),
          )
        }
      } else if eval.condition >= 0 {
        let truth = if eval.conditional_branch {
          edge.kind is @ir.BranchEdge
        } else {
          edge_index == 0
        }
        if eval.null_branch != 0 {
          match eval.values[eval.condition] {
            Some(value) =>
              ca_assume_null(output, value, (eval.null_branch == 1) == truth)
            None => ()
          }
        } else {
          output = ca_assume(
            func,
            output,
            eval.values,
            eval.condition,
            truth,
            0,
          )
        }
      }
      if !output.reachable {
        continue
      }
      if edge.kind is @ir.BranchEdge &&
        !loop_plan.header_slots[edge.block].is_empty() {
        ca_transfer_loop_arguments(func, cfg, block, edge.block, eval, output)
      }
      let old = states[edge.block]
      let next = match old {
        Some(previous) => ca_state_join(previous, output)
        None => output
      }
      if visits[edge.block] > 1 && edge.block <= block {
        match old {
          Some(previous) =>
            for index = 0; index < next.locals.length(); index = index + 1 {
              match (previous.locals[index].range, next.locals[index].range) {
                (Some(a), Some(b)) =>
                  next.locals[index] = ca_integer(ca_widen(a, b, thresholds))
                _ => ()
              }
            }
          None => ()
        }
      }
      if old is Some(previous) && ca_state_equal(previous, next) {
        continue
      }
      states[edge.block] = Some(next)
      if !queued[edge.block] {
        queue.push(edge.block)
        queued[edge.block] = true
      }
    }
  }
  // Replay only converged states. No analysis facts outlive this revision.
  let proofs : @hashmap.HashMap[Int, Int] = @hashmap.new()
  let conflicts : @hashmap.HashMap[Int, Bool] = @hashmap.new()
  for block = 0; block < states.length(); block = block + 1 {
    match states[block] {
      Some(state) if state.reachable => {
        let eval = ca_evaluate_block(
          func,
          cfg,
          block,
          state,
          expression_blocks,
          loop_plan,
          values,
          touched,
          ctx.fast_math,
        )
        if eval.exhausted {
          return HotPassResult::unchanged()
        }
        for proof in eval.proofs {
          let (node, value) = proof
          if value < 0 {
            conflicts.set(node, true)
          }
          if proofs.get(node) is Some(old) && old != value {
            conflicts.set(node, true)
          }
          proofs.set(node, value)
        }
      }
      _ => ()
    }
  }
  let nodes = proofs.keys().to_array()
  nodes.sort()
  let mut changed = false
  for node in nodes {
    if conflicts.contains(node) {
      continue
    }
    ca_replace_predicate(ctx, func, node, proofs.get(node).unwrap())
    changed = true
  }
  // Multi-value expressions can expose one physical region through several
  // CFG occurrences. A slot is dead only when every occurrence is dead; an
  // unrepresented slot is unknown. Plan all edits before changing any region.
  let slots_by_holder : @hashmap.HashMap[Int, Array[Int]] = @hashmap.new()
  for block in cfg.blocks {
    if block.is_synthetic || block.nodes.is_empty() {
      continue
    }
    let region = if block.region_holder == @ir.HotRegionRef::root().holder {
      @ir.HotRegionRef::root()
    } else {
      @ir.hot_region_body_ref(func, block.region_holder)
    }
    let slots = match slots_by_holder.get(block.region_holder) {
      Some(slots) => slots
      None => {
        let slots = Array::make(@ir.hot_region_root_count(func, region), 0)
        slots_by_holder.set(block.region_holder, slots)
        slots
      }
    }
    let live = states[block.id] is Some(state) && state.reachable
    for slot = block.start_slot; slot < block.end_slot; slot = slot + 1 {
      if live {
        slots[slot] = 2
      } else if slots[slot] == 0 {
        slots[slot] = 1
      }
    }
  }
  let holders = slots_by_holder.keys().to_array()
  holders.sort_by(fn(a, b) { b - a })
  for holder in holders {
    let region = if holder == @ir.HotRegionRef::root().holder {
      @ir.HotRegionRef::root()
    } else {
      @ir.hot_region_body_ref(func, holder)
    }
    let slots = slots_by_holder.get(holder).unwrap()
    let mut end = slots.length()
    while end > 0 {
      if slots[end - 1] != 1 {
        end -= 1
        continue
      }
      let mut start = end - 1
      while start > 0 && slots[start - 1] == 1 {
        start -= 1
      }
      if end - start != 1 ||
        !(@ir.hot_node_get(func, @ir.hot_region_get(func, region, start)).op
        is @ir.Unreachable) {
        ignore(
          pass_splice_region(ctx, func, region, start, end - start, [
            @ir.hot_build_unreachable(func),
          ]),
        )
        changed = true
      }
      end = start
    }
  }
  if changed {
    HotPassResult::changed()
  } else {
    HotPassResult::unchanged()
  }
}

///|
priv struct CaLoopPlan {
  local_slots : Array[Int]
  local_ids : Array[Int]
  local_types : Array[@lib.ValType]
  types : Array[@lib.ValType]
  depths : Array[Int]
  loop_slots : Array[Array[Int]]
  header_slots : Array[Array[Int]]
  block_parameters : Array[Array[(Int, Int)]]
}

///|
fn ca_relevant_locals(func : @ir.HotFunc) -> Array[Int] {
  let slots = Array::make(@ir.hot_local_count(func), -1)
  let writes : Array[Array[Int]] = Array::makei(slots.length(), fn(_) { [] })
  let work : Array[Int] = []
  for node = 0; node < @ir.hot_node_count(func); node = node + 1 {
    if !@ir.hot_node_is_live(func, node) {
      continue
    }
    let data = @ir.hot_node_get(func, node)
    let instr = @ir.hot_node_exact_instr(func, node)
    if data.op is @ir.LocalSet || data.op is @ir.LocalTee {
      for child in @ir.hot_child_span(func, node) {
        writes[data.imm0].push(child)
      }
    }
    if ca_comparison(instr) is Some(_) ||
      data.op is @ir.RefIsNull ||
      instr is Some(@lib.RefEq) ||
      instr is Some(@lib.I32Eqz) ||
      instr is Some(@lib.I64Eqz) {
      work.push(node)
    }
    let children = @ir.hot_child_span(func, node)
    if !children.is_empty() {
      if data.op is @ir.If {
        work.push(children[0])
      } else if data.op is @ir.BrIf ||
        data.op is @ir.BrOnNull ||
        data.op is @ir.BrOnNonNull {
        work.push(children[children.length() - 1])
      }
    }
  }
  let seen = Array::make(@ir.hot_node_count(func), false)
  while !work.is_empty() {
    let node = work.pop().unwrap()
    if node < 0 || seen[node] {
      continue
    }
    seen[node] = true
    let data = @ir.hot_node_get(func, node)
    if data.op is @ir.LocalGet ||
      data.op is @ir.LocalSet ||
      data.op is @ir.LocalTee {
      let index = data.imm0
      if slots[index] < 0 {
        slots[index] = 0
        // Include every possible source, including copies through loops and
        // assignments outside the predicate's own expression tree.
        for source in writes[index] {
          work.push(source)
        }
      }
    }
    for child in @ir.hot_child_span(func, node) {
      work.push(child)
    }
  }
  let mut next = 0
  for index = 0; index < slots.length(); index = index + 1 {
    if slots[index] >= 0 {
      slots[index] = next
      next += 1
    }
  }
  slots
}

///|
fn ca_slot_type(plan : CaLoopPlan, slot : Int) -> @lib.ValType {
  if slot < plan.local_types.length() {
    plan.local_types[slot]
  } else {
    plan.types[slot - plan.local_types.length()]
  }
}

///|
fn ca_loop_plan(func : @ir.HotFunc, cfg : @ir.HotCfg) -> CaLoopPlan {
  let local_slots = ca_relevant_locals(func)
  let local_ids : Array[Int] = []
  let local_types : Array[@lib.ValType] = []
  for index = 0; index < local_slots.length(); index = index + 1 {
    if local_slots[index] >= 0 {
      local_ids.push(index)
      local_types.push(@ir.hot_local_type(func, index).unwrap())
    }
  }
  let plan : CaLoopPlan = {
    local_slots,
    local_ids,
    local_types,
    types: [],
    depths: [],
    loop_slots: Array::makei(@ir.hot_node_count(func), fn(_) { [] }),
    header_slots: Array::makei(cfg.blocks.length(), fn(_) { [] }),
    block_parameters: Array::makei(cfg.blocks.length(), fn(_) { [] }),
  }
  let loop_depths = Array::make(@ir.hot_node_count(func), 0)
  for node = 0; node < @ir.hot_node_count(func); node = node + 1 {
    let data = @ir.hot_node_get(func, node)
    if !(data.op is @ir.Loop) {
      continue
    }
    let params = match @ir.hot_type_get(func, data.ty) {
      @ir.BlockResultResolved(_, params, _) => params
      _ => []
    }
    if params.is_empty() {
      continue
    }
    let children = @ir.hot_child_span(func, node)
    let slots = plan.loop_slots[node]
    for ty in params {
      slots.push(plan.local_types.length() + plan.types.length())
      plan.types.push(ty)
      plan.depths.push(0)
    }
    let body = @ir.hot_region_body_ref(func, node)
    if @ir.hot_region_root_count(func, body) > 0 {
      if @ir.cfg_block_for_region_root(cfg, body, 0) is Some(header) {
        plan.header_slots[header] = slots
      }
    }
    // The same HOT node denotes the initial stack value outside the loop and
    // the current carried value inside it. Facts belong to that execution
    // context, never to the initial producer's literal opcode.
    let seen = Array::make(@ir.hot_node_count(func), false)
    seen[node] = true
    let work : Array[Int] = []
    for index = params.length(); index < children.length(); index = index + 1 {
      work.push(children[index])
    }
    while !work.is_empty() {
      let current = work.pop().unwrap()
      if current < 0 || seen[current] {
        continue
      }
      seen[current] = true
      if @ir.hot_node_get(func, current).op is @ir.Loop {
        loop_depths[current] += 1
      }
      let mut parameter = false
      for index = 0; index < params.length(); index = index + 1 {
        if current == children[index] {
          parameter = true
        }
      }
      if !parameter {
        for child in @ir.hot_child_span(func, current) {
          work.push(child)
        }
      }
    }
    for block in cfg.blocks {
      if block.region_holder < 0 || !seen[block.region_holder] {
        continue
      }
      for index = 0; index < params.length(); index = index + 1 {
        plan.block_parameters[block.id].push((children[index], slots[index]))
      }
    }
  }
  // Select the innermost parameter scope even when several nested loops reuse
  // the same initial producer. Node allocation order is not a nesting order.
  for node = 0; node < plan.loop_slots.length(); node = node + 1 {
    for slot in plan.loop_slots[node] {
      plan.depths[slot - plan.local_types.length()] = loop_depths[node]
    }
  }
  plan
}

///|
fn ca_transfer_loop_arguments(
  func : @ir.HotFunc,
  cfg : @ir.HotCfg,
  from : Int,
  target : Int,
  eval : CaBlockEval,
  output : CaState,
) -> Unit {
  let slots = eval.loop_plan.header_slots[target]
  let values = slots.map(fn(slot) {
    ca_value_type(
      eval.loop_plan.types[slot - eval.loop_plan.local_types.length()],
      false,
    )
  })
  let roots = cfg.blocks[from].nodes
  if !roots.is_empty() {
    let node = roots[roots.length() - 1]
    let op = @ir.hot_node_get(func, node).op
    if op is @ir.Br || op is @ir.BrIf || op is @ir.BrTable {
      let children = @ir.hot_child_span(func, node)
      for index = 0
          index < slots.length() && index < children.length()
          index = index + 1 {
        if eval.values[children[index]] is Some(value) {
          values[index] = value.value
        }
      }
    }
  }
  for index = 0; index < slots.length(); index = index + 1 {
    ca_write(output, slots[index], values[index])
  }
}
