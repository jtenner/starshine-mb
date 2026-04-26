///|
pub fn rse_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new("redundant-set-elimination", invalidates=[
    @ir.HotAnalysis::cfg(),
    @ir.HotAnalysis::dominance(),
    @ir.HotAnalysis::liveness(),
    @ir.HotAnalysis::use_def(),
    @ir.HotAnalysis::effects(),
    @ir.HotAnalysis::loop_info(),
    @ir.HotAnalysis::ssa(),
  ])
}

///|
pub fn rse_summary() -> String {
  "Remove redundant same-value local.set/local.tee shells while preserving RHS evaluation."
}

///|
priv struct RseState {
  local_values : Array[Int]
  value_ids : @hashmap.HashMap[String, Int]
  mut next_value : Int
  mut changed : Bool
}

///|
fn RseState::new(func : @ir.HotFunc) -> RseState {
  let state = {
    local_values: Array::make(@ir.hot_local_count(func), -1),
    value_ids: @hashmap.new(capacity=@ir.hot_local_count(func) * 2 + 17),
    next_value: 0,
    changed: false,
  }
  for local_id = 0
      local_id < state.local_values.length()
      local_id = local_id + 1 {
    state.local_values[local_id] = rse_intern_value(state, "local:\{local_id}")
  }
  state
}

///|
fn RseState::clone_from(other : RseState) -> RseState {
  // Branch-local exploration can share the value interner because value ids are
  // immutable once assigned. Only the per-local facts and changed flag need to
  // be copied back explicitly.
  {
    local_values: other.local_values.copy(),
    value_ids: other.value_ids,
    next_value: other.next_value,
    changed: other.changed,
  }
}

///|
fn rse_sync_interner(dst : RseState, src : RseState) -> Unit {
  if src.next_value > dst.next_value {
    dst.next_value = src.next_value
  }
  if src.changed {
    dst.changed = true
  }
}

///|
fn rse_intern_value(state : RseState, key : String) -> Int {
  match state.value_ids.get(key) {
    Some(value) => value
    None => {
      let value = state.next_value
      state.next_value += 1
      state.value_ids.set(key, value)
      value
    }
  }
}

///|
fn rse_fresh_value(state : RseState, node_id : Int) -> Int {
  let value = state.next_value
  state.next_value += 1
  ignore(node_id)
  value
}

///|
fn rse_local_value_get(state : RseState, local_id : Int) -> Int {
  if local_id < 0 || local_id >= state.local_values.length() {
    -1
  } else {
    state.local_values[local_id]
  }
}

///|
fn rse_local_value_set(state : RseState, local_id : Int, value : Int) -> Unit {
  if local_id >= 0 && local_id < state.local_values.length() {
    state.local_values[local_id] = value
  }
}

///|
fn rse_clear_all_local_values(state : RseState) -> Unit {
  for idx = 0; idx < state.local_values.length(); idx = idx + 1 {
    state.local_values[idx] = -1
  }
}

///|
fn rse_merge_local_values(
  state : RseState,
  lhs : RseState,
  rhs : RseState,
) -> Unit {
  rse_sync_interner(state, lhs)
  rse_sync_interner(state, rhs)
  let count = state.local_values.length()
  for idx = 0; idx < count; idx = idx + 1 {
    let lhs_value = lhs.local_values[idx]
    let rhs_value = rhs.local_values[idx]
    state.local_values[idx] = if lhs_value == rhs_value {
      lhs_value
    } else {
      -1
    }
  }
}

///|
fn rse_node_const_key(func : @ir.HotFunc, node : @ir.HotNode) -> String {
  "const:\{node.ty}:\{@debug.to_string(@ir.hot_const_get(func, node.imm0))}"
}

///|
fn rse_node_can_structurally_value(func : @ir.HotFunc, node_id : Int) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  ignore(func)
  ignore(node_id)
  match node.op {
    @ir.HotOp::Const | @ir.HotOp::RefNull | @ir.HotOp::RefFunc => true
    _ => false
  }
}

///|
fn rse_structural_value(
  func : @ir.HotFunc,
  state : RseState,
  node_id : Int,
  child_values : Array[Int],
) -> Int? {
  if !rse_node_can_structurally_value(func, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  let key = match node.op {
    @ir.HotOp::Const => rse_node_const_key(func, node)
    @ir.HotOp::RefNull => "ref.null:\{node.ty}:\{node.imm0}"
    @ir.HotOp::RefFunc => "ref.func:\{node.ty}:\{node.imm0}"
    _ => return None
  }
  ignore(child_values)
  Some(rse_intern_value(state, key))
}

///|
fn rse_replace_redundant_set(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  value_id : Int,
) -> Unit {
  let replacement_id = @ir.hot_build_drop(func, value_id)
  let replacement = @ir.hot_node_get(func, replacement_id)
  @ir.hot_delete_node(func, replacement_id)
  pass_replace_node(ctx, func, node_id, replacement)
}

///|
fn rse_replace_redundant_tee(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  value_id : Int,
) -> Unit {
  let replacement = @ir.hot_node_get(func, value_id)
  pass_replace_node(ctx, func, node_id, replacement)
}

///|
fn rse_visit_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : RseState,
  region_ref : @ir.HotRegionRef,
) -> Unit {
  let mut idx = 0
  while idx < @ir.hot_region_root_count(func, region_ref) {
    let root_id = @ir.hot_region_get(func, region_ref, idx)
    if root_id >= 0 && @ir.hot_node_is_live(func, root_id) {
      ignore(rse_visit_node(ctx, func, state, root_id))
    }
    idx += 1
  }
}

///|
fn rse_visit_if(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : RseState,
  node_id : Int,
) -> Int {
  if @ir.hot_child_count(func, node_id) > 0 {
    ignore(
      rse_visit_node(ctx, func, state, @ir.hot_child_get(func, node_id, 0)),
    )
  }
  let entry_state = RseState::clone_from(state)
  let then_state = RseState::clone_from(state)
  rse_visit_region(
    ctx,
    func,
    then_state,
    @ir.hot_region_then_ref(func, node_id),
  )
  let else_state = match @ir.hot_region_else_ref(func, node_id) {
    Some(else_ref) => {
      let branch_state = RseState::clone_from(entry_state)
      rse_visit_region(ctx, func, branch_state, else_ref)
      branch_state
    }
    None => entry_state
  }
  rse_merge_local_values(state, then_state, else_state)
  rse_fresh_value(state, node_id)
}

///|
fn rse_visit_control(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : RseState,
  node_id : Int,
) -> Int {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::If => rse_visit_if(ctx, func, state, node_id)
    @ir.HotOp::Block => {
      rse_visit_region(ctx, func, state, @ir.hot_region_body_ref(func, node_id))
      rse_fresh_value(state, node_id)
    }
    @ir.HotOp::Loop => {
      let loop_state = RseState::clone_from(state)
      rse_visit_region(
        ctx,
        func,
        loop_state,
        @ir.hot_region_body_ref(func, node_id),
      )
      rse_sync_interner(state, loop_state)
      // Loops need fixed-point value flow for full Binaryen parity. This first
      // active implementation still rewrites loop-internal straight-line facts,
      // then drops loop-exit facts conservatively.
      rse_clear_all_local_values(state)
      rse_fresh_value(state, node_id)
    }
    @ir.HotOp::Try | @ir.HotOp::TryTable => {
      // Exception edges make local facts path-sensitive. Visit children/regions
      // only for safe nested tee/set rewrites, then discard facts after the node.
      match node.op {
        @ir.HotOp::Try => {
          rse_visit_region(
            ctx,
            func,
            state,
            @ir.hot_region_body_ref(func, node_id),
          )
          match @ir.hot_region_catch_ref(func, node_id) {
            Some(catch_ref) => rse_visit_region(ctx, func, state, catch_ref)
            None => ()
          }
        }
        @ir.HotOp::TryTable => {
          rse_visit_region(
            ctx,
            func,
            state,
            @ir.hot_region_body_ref(func, node_id),
          )
          rse_visit_region(
            ctx,
            func,
            state,
            @ir.hot_region_catch_list_ref(func, node_id),
          )
        }
        _ => ()
      }
      rse_clear_all_local_values(state)
      rse_fresh_value(state, node_id)
    }
    _ => rse_fresh_value(state, node_id)
  }
}

///|
fn rse_visit_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : RseState,
  node_id : Int,
) -> Int {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return -1
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Block
    | @ir.HotOp::Loop
    | @ir.HotOp::If
    | @ir.HotOp::Try
    | @ir.HotOp::TryTable => return rse_visit_control(ctx, func, state, node_id)
    _ => ()
  }

  let child_values : Array[Int] = []
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    child_values.push(
      rse_visit_node(ctx, func, state, @ir.hot_child_get(func, node_id, slot)),
    )
  }

  match node.op {
    @ir.HotOp::LocalGet => rse_local_value_get(state, node.imm0)
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => {
      if child_values.length() != 1 {
        return rse_fresh_value(state, node_id)
      }
      let value_id = @ir.hot_child_get(func, node_id, 0)
      let value = child_values[0]
      let current = rse_local_value_get(state, node.imm0)
      if value >= 0 && current == value {
        match node.op {
          @ir.HotOp::LocalSet =>
            rse_replace_redundant_set(ctx, func, node_id, value_id)
          @ir.HotOp::LocalTee =>
            rse_replace_redundant_tee(ctx, func, node_id, value_id)
          _ => ()
        }
        state.changed = true
      }
      rse_local_value_set(state, node.imm0, value)
      value
    }
    @ir.HotOp::Br
    | @ir.HotOp::Return
    | @ir.HotOp::Unreachable
    | @ir.HotOp::Throw
    | @ir.HotOp::Rethrow
    | @ir.HotOp::ThrowRef => {
      rse_clear_all_local_values(state)
      rse_fresh_value(state, node_id)
    }
    _ =>
      match rse_structural_value(func, state, node_id, child_values) {
        Some(value) => value
        None => rse_fresh_value(state, node_id)
      }
  }
}

///|
fn rse_has_candidate(func : @ir.HotFunc) -> Bool {
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => return true
      _ => ()
    }
  }
  false
}

///|
fn rse_run(ctx : HotPassContext, func : @ir.HotFunc) -> HotPassResult {
  if !rse_has_candidate(func) {
    return HotPassResult::unchanged()
  }
  let state = RseState::new(func)
  rse_visit_region(ctx, func, state, @ir.HotRegionRef::root())
  if state.changed {
    HotPassResult::changed()
  } else {
    HotPassResult::unchanged()
  }
}

///|
priv struct RseRawState {
  local_values : Array[String]
  stack : Array[String]
  mut next_unknown : Int
  mut changed : Bool
}

///|
fn RseRawState::new(local_count : Int) -> RseRawState {
  let state = {
    local_values: Array::make(local_count, ""),
    stack: [],
    next_unknown: 0,
    changed: false,
  }
  for local_id = 0
      local_id < state.local_values.length()
      local_id = local_id + 1 {
    state.local_values[local_id] = "local:\{local_id}"
  }
  state
}

///|
fn RseRawState::clone_from(other : RseRawState) -> RseRawState {
  {
    local_values: other.local_values.copy(),
    stack: other.stack.copy(),
    next_unknown: other.next_unknown,
    changed: other.changed,
  }
}

///|
fn rse_raw_fresh(state : RseRawState) -> String {
  let key = "unknown:\{state.next_unknown}"
  state.next_unknown += 1
  key
}

///|
fn rse_raw_pop(state : RseRawState) -> String {
  match state.stack.pop() {
    Some(value) => value
    None => ""
  }
}

///|
fn rse_raw_push(state : RseRawState, value : String) -> Unit {
  state.stack.push(value)
}

///|
fn rse_raw_local_get(state : RseRawState, local_id : Int) -> String {
  if local_id >= 0 && local_id < state.local_values.length() {
    state.local_values[local_id]
  } else {
    ""
  }
}

///|
fn rse_raw_local_set(
  state : RseRawState,
  local_id : Int,
  value : String,
) -> Unit {
  if local_id >= 0 && local_id < state.local_values.length() {
    state.local_values[local_id] = value
  }
}

///|
fn rse_raw_clear_values(state : RseRawState) -> Unit {
  for local_id = 0
      local_id < state.local_values.length()
      local_id = local_id + 1 {
    state.local_values[local_id] = ""
  }
}

///|
fn rse_raw_merge_values(
  state : RseRawState,
  lhs : RseRawState,
  rhs : RseRawState,
) -> Unit {
  if lhs.next_unknown > state.next_unknown {
    state.next_unknown = lhs.next_unknown
  }
  if rhs.next_unknown > state.next_unknown {
    state.next_unknown = rhs.next_unknown
  }
  if lhs.changed || rhs.changed {
    state.changed = true
  }
  for local_id = 0
      local_id < state.local_values.length()
      local_id = local_id + 1 {
    let lhs_value = lhs.local_values[local_id]
    let rhs_value = rhs.local_values[local_id]
    state.local_values[local_id] = if lhs_value == rhs_value {
      lhs_value
    } else {
      ""
    }
  }
  state.stack.clear()
}

///|
fn rse_raw_local_id(idx : @lib.LocalIdx) -> Int {
  let @lib.LocalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn rse_raw_unary_key(op : String, value : String) -> String {
  if value == "" {
    ""
  } else {
    "\{op}(\{value})"
  }
}

///|
fn rse_raw_binary_key(op : String, lhs : String, rhs : String) -> String {
  if lhs == "" || rhs == "" {
    ""
  } else {
    "\{op}(\{lhs},\{rhs})"
  }
}

///|
fn rse_raw_rewrite_expr(
  instrs : Array[@lib.Instruction],
  state : RseRawState,
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    match instr {
      @lib.Instruction::I32Const(value) => {
        out.push(instr)
        rse_raw_push(state, "i32:\{value}")
      }
      @lib.Instruction::I64Const(value) => {
        out.push(instr)
        rse_raw_push(state, "i64:\{value}")
      }
      @lib.Instruction::F32Const(value) => {
        out.push(instr)
        rse_raw_push(state, "f32:\{value}")
      }
      @lib.Instruction::F64Const(value) => {
        out.push(instr)
        rse_raw_push(state, "f64:\{value}")
      }
      @lib.Instruction::RefNull(ref_type) => {
        out.push(instr)
        rse_raw_push(state, "ref.null:\{ref_type}")
      }
      @lib.Instruction::RefFunc(func_idx) => {
        out.push(instr)
        rse_raw_push(state, "ref.func:\{func_idx}")
      }
      @lib.Instruction::LocalGet(local_idx) => {
        out.push(instr)
        rse_raw_push(
          state,
          rse_raw_local_get(state, rse_raw_local_id(local_idx)),
        )
      }
      @lib.Instruction::LocalSet(local_idx) => {
        let value = rse_raw_pop(state)
        let local_id = rse_raw_local_id(local_idx)
        if value != "" && rse_raw_local_get(state, local_id) == value {
          out.push(@lib.Instruction::drop())
          state.changed = true
        } else {
          out.push(instr)
        }
        rse_raw_local_set(state, local_id, value)
      }
      @lib.Instruction::LocalTee(local_idx) => {
        let value = match state.stack.last() {
          Some(v) => v
          None => ""
        }
        let local_id = rse_raw_local_id(local_idx)
        if value != "" && rse_raw_local_get(state, local_id) == value {
          state.changed = true
        } else {
          out.push(instr)
        }
        rse_raw_local_set(state, local_id, value)
      }
      @lib.Instruction::Drop => {
        ignore(rse_raw_pop(state))
        out.push(instr)
      }
      @lib.Instruction::I32Eqz | @lib.Instruction::I64Eqz => {
        let value = rse_raw_pop(state)
        out.push(instr)
        rse_raw_push(state, rse_raw_unary_key(instr.to_string(), value))
      }
      @lib.Instruction::I32Add
      | @lib.Instruction::I32Sub
      | @lib.Instruction::I32Mul
      | @lib.Instruction::I32And
      | @lib.Instruction::I32Or
      | @lib.Instruction::I32Xor
      | @lib.Instruction::I32Shl
      | @lib.Instruction::I32ShrS
      | @lib.Instruction::I32ShrU
      | @lib.Instruction::I64Add
      | @lib.Instruction::I64Sub
      | @lib.Instruction::I64Mul
      | @lib.Instruction::I64And
      | @lib.Instruction::I64Or
      | @lib.Instruction::I64Xor
      | @lib.Instruction::I64Shl
      | @lib.Instruction::I64ShrS
      | @lib.Instruction::I64ShrU
      | @lib.Instruction::I32Eq
      | @lib.Instruction::I32Ne
      | @lib.Instruction::I64Eq
      | @lib.Instruction::I64Ne => {
        let rhs = rse_raw_pop(state)
        let lhs = rse_raw_pop(state)
        out.push(instr)
        rse_raw_push(state, rse_raw_binary_key(instr.to_string(), lhs, rhs))
      }
      @lib.Instruction::If(block_type, then_body, else_body) => {
        ignore(rse_raw_pop(state))
        let entry = RseRawState::clone_from(state)
        let then_state = RseRawState::clone_from(state)
        let next_then = rse_raw_rewrite_expr(then_body, then_state)
        let (next_else, else_state) = match else_body {
          Some(else_instrs) => {
            let branch_state = RseRawState::clone_from(entry)
            (
              Some(rse_raw_rewrite_expr(else_instrs, branch_state)),
              branch_state,
            )
          }
          None => (None, entry)
        }
        rse_raw_merge_values(state, then_state, else_state)
        out.push(@lib.Instruction::if_(block_type, next_then, next_else))
        rse_raw_push(state, rse_raw_fresh(state))
      }
      @lib.Instruction::Block(block_type, @lib.Expr(body)) => {
        let next = rse_raw_rewrite_expr(body, state)
        out.push(@lib.Instruction::block(block_type, @lib.Expr::new(next)))
        rse_raw_push(state, rse_raw_fresh(state))
      }
      @lib.Instruction::Loop(block_type, @lib.Expr(body)) => {
        let loop_state = RseRawState::clone_from(state)
        let next = rse_raw_rewrite_expr(body, loop_state)
        if loop_state.changed {
          state.changed = true
        }
        if loop_state.next_unknown > state.next_unknown {
          state.next_unknown = loop_state.next_unknown
        }
        rse_raw_clear_values(state)
        out.push(@lib.Instruction::loop_(block_type, @lib.Expr::new(next)))
        rse_raw_push(state, rse_raw_fresh(state))
      }
      @lib.Instruction::Br(_)
      | @lib.Instruction::Return
      | @lib.Instruction::Unreachable => {
        out.push(instr)
        state.stack.clear()
        rse_raw_clear_values(state)
      }
      _ => {
        out.push(instr)
        // Conservatively forget stack-producing details for unmodeled operations.
        state.stack.clear()
      }
    }
  }
  out
}

///|
fn rse_run_raw_func(func : @lib.Func, param_count : Int) -> (@lib.Func, Bool) {
  let @lib.Func(locals, @lib.Expr(instrs)) = func
  let state = RseRawState::new(param_count + locals.length())
  let rewritten = rse_raw_rewrite_expr(instrs, state)
  if state.changed {
    (@lib.Func::new(locals, @lib.Expr::new(rewritten)), true)
  } else {
    (func, false)
  }
}
