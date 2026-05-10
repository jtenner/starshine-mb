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
    } else if lhs_value >= 0 && rhs_value >= 0 {
      rse_fresh_value(state, idx)
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
      // The HOT fallback does not yet model label-exit merge facts. Raw RSE
      // handles structured label exits precisely; keep HOT block exits safe by
      // dropping post-block local facts instead of trusting the fallthrough-only
      // body state after conditional branches to the block label.
      rse_clear_all_local_values(state)
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
    | @ir.HotOp::BrIf
    | @ir.HotOp::BrTable
    | @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail
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
priv enum RseRawLabelKind {
  ExitLabel
  LoopLabel
}

///|
priv struct RseRawLabelScope {
  kind : RseRawLabelKind
  exits : Array[Array[String]]
}

///|
fn RseRawLabelScope::new(kind : RseRawLabelKind) -> RseRawLabelScope {
  { kind, exits: [] }
}

///|
priv struct RseRawState {
  local_values : Array[String]
  local_types : Array[@lib.ValType]
  env : @validate.Env
  stack : Array[String]
  mut next_unknown : Int
  mut changed : Bool
  mut reachable : Bool
}

///|
fn RseRawState::new(
  local_types : Array[@lib.ValType],
  param_count : Int,
  env : @validate.Env,
) -> RseRawState {
  let state = {
    local_values: Array::make(local_types.length(), ""),
    local_types,
    env,
    stack: [],
    next_unknown: 0,
    changed: false,
    reachable: true,
  }
  for local_id = 0
      local_id < state.local_values.length()
      local_id = local_id + 1 {
    state.local_values[local_id] = if local_id < param_count {
      "local:\{local_id}"
    } else {
      match rse_raw_default_value_for_type(local_types[local_id]) {
        Some(value) => value
        None => "local:\{local_id}"
      }
    }
  }
  state
}

///|
fn RseRawState::clone_from(other : RseRawState) -> RseRawState {
  {
    local_values: other.local_values.copy(),
    local_types: other.local_types,
    env: other.env,
    stack: other.stack.copy(),
    next_unknown: other.next_unknown,
    changed: other.changed,
    reachable: other.reachable,
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
fn rse_raw_default_value_for_type(ty : @lib.ValType) -> String? {
  match ty {
    @lib.NumTypeValType(@lib.I32NumType) => Some("i32:\{@lib.I32::new(0)}")
    @lib.NumTypeValType(@lib.I64NumType) => Some("i64:\{@lib.I64::new(0L)}")
    @lib.NumTypeValType(@lib.F32NumType) => Some("f32:\{@lib.F32::new(0.0)}")
    @lib.NumTypeValType(@lib.F64NumType) => Some("f64:\{@lib.F64::new(0.0)}")
    @lib.RefTypeValType(ref_type) if ref_type.is_nullable() =>
      Some("ref.null:\{ref_type.make_nullable()}")
    _ => None
  }
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
fn rse_raw_local_type(state : RseRawState, local_id : Int) -> @lib.ValType? {
  if local_id >= 0 && local_id < state.local_types.length() {
    Some(state.local_types[local_id])
  } else {
    None
  }
}

///|
fn rse_raw_is_strict_subtype_local(
  state : RseRawState,
  candidate_id : Int,
  original_id : Int,
) -> Bool {
  if candidate_id == original_id {
    return false
  }
  match
    (
      rse_raw_local_type(state, candidate_id),
      rse_raw_local_type(state, original_id),
    ) {
    (Some(candidate), Some(original)) =>
      candidate != original &&
      @validate.Match::matches(candidate, original, state.env)
    _ => false
  }
}

///|
fn rse_raw_refined_get_local(state : RseRawState, local_id : Int) -> Int {
  let value = rse_raw_local_get(state, local_id)
  if value == "" {
    return local_id
  }
  for candidate_id = 0
      candidate_id < state.local_values.length()
      candidate_id = candidate_id + 1 {
    if state.local_values[candidate_id] == value &&
      rse_raw_is_strict_subtype_local(state, candidate_id, local_id) {
      return candidate_id
    }
  }
  local_id
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
fn rse_raw_merge_sources(
  state : RseRawState,
  sources : Array[Array[String]],
) -> Unit {
  state.stack.clear()
  if sources.length() == 0 {
    rse_raw_clear_values(state)
    state.reachable = false
    return
  }
  state.reachable = true
  for local_id = 0
      local_id < state.local_values.length()
      local_id = local_id + 1 {
    let mut first_known = ""
    let mut saw_known = false
    let mut saw_unknown = false
    let mut disagreement = false
    for source in sources {
      let value = source[local_id]
      if value == "" {
        saw_unknown = true
        continue
      }
      if !saw_known {
        first_known = value
        saw_known = true
      } else if value != first_known {
        disagreement = true
      }
    }
    state.local_values[local_id] = if disagreement {
      if saw_unknown {
        ""
      } else {
        rse_raw_fresh(state)
      }
    } else if saw_known && !saw_unknown {
      first_known
    } else {
      ""
    }
  }
}

///|
fn rse_raw_local_id(idx : @lib.LocalIdx) -> Int {
  let @lib.LocalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn rse_raw_label_depth(idx : @lib.LabelIdx) -> Int {
  let @lib.LabelIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn rse_raw_record_branch_exit(
  state : RseRawState,
  scopes : Array[RseRawLabelScope],
  label_depth : Int,
) -> Unit {
  if label_depth < 0 || label_depth >= scopes.length() {
    return
  }
  let scope = scopes[scopes.length() - 1 - label_depth]
  match scope.kind {
    RseRawLabelKind::LoopLabel => ()
    _ => scope.exits.push(state.local_values.copy())
  }
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
fn rse_raw_rewrite_expr_scoped(
  instrs : Array[@lib.Instruction],
  state : RseRawState,
  scopes : Array[RseRawLabelScope],
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    if !state.reachable {
      out.push(instr)
      continue
    }
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
        let local_id = rse_raw_local_id(local_idx)
        let refined_id = rse_raw_refined_get_local(state, local_id)
        if refined_id != local_id {
          out.push(
            @lib.Instruction::local_get(
              @lib.LocalIdx::new(refined_id.reinterpret_as_uint()),
            ),
          )
          state.changed = true
        } else {
          out.push(instr)
        }
        rse_raw_push(state, rse_raw_local_get(state, local_id))
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
      @lib.Instruction::RefAsNonNull
      | @lib.Instruction::RefCast(_, _)
      | @lib.Instruction::RefCastDescEq(_, _) => {
        let value = rse_raw_pop(state)
        out.push(instr)
        rse_raw_push(state, value)
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
        let scope = RseRawLabelScope::new(RseRawLabelKind::ExitLabel)
        scopes.push(scope)
        let then_state = RseRawState::clone_from(state)
        let next_then = rse_raw_rewrite_expr_scoped(
          then_body, then_state, scopes,
        )
        let (next_else, else_state) = match else_body {
          Some(else_instrs) => {
            let branch_state = RseRawState::clone_from(entry)
            (
              Some(
                rse_raw_rewrite_expr_scoped(else_instrs, branch_state, scopes),
              ),
              branch_state,
            )
          }
          None => (None, entry)
        }
        ignore(scopes.pop())
        if then_state.next_unknown > state.next_unknown {
          state.next_unknown = then_state.next_unknown
        }
        if else_state.next_unknown > state.next_unknown {
          state.next_unknown = else_state.next_unknown
        }
        if then_state.changed || else_state.changed {
          state.changed = true
        }
        let sources : Array[Array[String]] = []
        if then_state.reachable {
          sources.push(then_state.local_values.copy())
        }
        if else_state.reachable {
          sources.push(else_state.local_values.copy())
        }
        for exit in scope.exits {
          sources.push(exit)
        }
        rse_raw_merge_sources(state, sources)
        out.push(@lib.Instruction::if_(block_type, next_then, next_else))
        if state.reachable {
          rse_raw_push(state, rse_raw_fresh(state))
        }
      }
      @lib.Instruction::Block(block_type, @lib.Expr(body)) => {
        let scope = RseRawLabelScope::new(RseRawLabelKind::ExitLabel)
        scopes.push(scope)
        let next = rse_raw_rewrite_expr_scoped(body, state, scopes)
        ignore(scopes.pop())
        let sources : Array[Array[String]] = []
        if state.reachable {
          sources.push(state.local_values.copy())
        }
        for exit in scope.exits {
          sources.push(exit)
        }
        rse_raw_merge_sources(state, sources)
        out.push(@lib.Instruction::block(block_type, @lib.Expr::new(next)))
        if state.reachable {
          rse_raw_push(state, rse_raw_fresh(state))
        }
      }
      @lib.Instruction::Loop(block_type, @lib.Expr(body)) => {
        let loop_state = RseRawState::clone_from(state)
        let scope = RseRawLabelScope::new(RseRawLabelKind::LoopLabel)
        scopes.push(scope)
        let next = rse_raw_rewrite_expr_scoped(body, loop_state, scopes)
        ignore(scopes.pop())
        if loop_state.changed {
          state.changed = true
        }
        if loop_state.next_unknown > state.next_unknown {
          state.next_unknown = loop_state.next_unknown
        }
        rse_raw_clear_values(state)
        state.reachable = true
        out.push(@lib.Instruction::loop_(block_type, @lib.Expr::new(next)))
        rse_raw_push(state, rse_raw_fresh(state))
      }
      @lib.Instruction::Br(label_idx) => {
        rse_raw_record_branch_exit(
          state,
          scopes,
          rse_raw_label_depth(label_idx),
        )
        out.push(instr)
        state.stack.clear()
        rse_raw_clear_values(state)
        state.reachable = false
      }
      @lib.Instruction::BrIf(label_idx)
      | @lib.Instruction::BrOnNull(label_idx)
      | @lib.Instruction::BrOnNonNull(label_idx)
      | @lib.Instruction::BrOnCast(label_idx, _, _, _)
      | @lib.Instruction::BrOnCastFail(label_idx, _, _, _) => {
        ignore(rse_raw_pop(state))
        rse_raw_record_branch_exit(
          state,
          scopes,
          rse_raw_label_depth(label_idx),
        )
        out.push(instr)
        state.stack.clear()
      }
      @lib.Instruction::BrTable(label_idxs, fallback) => {
        ignore(rse_raw_pop(state))
        for target in label_idxs {
          rse_raw_record_branch_exit(state, scopes, rse_raw_label_depth(target))
        }
        rse_raw_record_branch_exit(state, scopes, rse_raw_label_depth(fallback))
        out.push(instr)
        state.stack.clear()
        rse_raw_clear_values(state)
        state.reachable = false
      }
      @lib.Instruction::Return | @lib.Instruction::Unreachable => {
        out.push(instr)
        state.stack.clear()
        rse_raw_clear_values(state)
        state.reachable = false
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
fn rse_raw_rewrite_expr(
  instrs : Array[@lib.Instruction],
  state : RseRawState,
) -> Array[@lib.Instruction] {
  let scopes : Array[RseRawLabelScope] = []
  rse_raw_rewrite_expr_scoped(instrs, state, scopes)
}

///|
fn rse_raw_local_types(
  params : Array[@lib.ValType],
  locals : @lib.Locals,
) -> Array[@lib.ValType] {
  let types = params.copy()
  for local_id = 0; local_id < locals.length(); local_id = local_id + 1 {
    types.push(locals.get(local_id))
  }
  types
}

///|
fn rse_run_raw_func(
  func : @lib.Func,
  params : Array[@lib.ValType],
  env : @validate.Env,
) -> (@lib.Func, Bool) {
  let @lib.Func(locals, @lib.Expr(instrs)) = func
  let state = RseRawState::new(
    rse_raw_local_types(params, locals),
    params.length(),
    env,
  )
  let rewritten = rse_raw_rewrite_expr(instrs, state)
  if state.changed {
    (@lib.Func::new(locals, @lib.Expr::new(rewritten)), true)
  } else {
    (func, false)
  }
}
