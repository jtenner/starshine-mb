///|
pub fn coalesce_locals_summary() -> String {
  "Coalesce compatible same-typed body locals and remove redundant local copies."
}

///|
priv enum CLActionKind {
  Get
  Set
  Tee
}

///|
priv enum CLValueSource {
  Unique
  Const(String)
  Local(Int)
}

///|
priv struct CLAction {
  kind : CLActionKind
  local_idx : Int
  source : CLValueSource
}

///|
priv struct CLLiveness {
  effective : Array[Bool]
  live_at_entry : Array[Bool]
}

///|
priv struct CLValueInterner {
  keys : Array[String]
  mut next_value : Int
}

///|
fn CLValueInterner::new() -> CLValueInterner {
  { keys: [], next_value: 0 }
}

///|
fn CLValueInterner::fresh(self : CLValueInterner) -> Int {
  let value = self.next_value
  self.next_value += 1
  value
}

///|
fn CLValueInterner::intern(self : CLValueInterner, key : String) -> Int {
  for idx = 0; idx < self.keys.length(); idx = idx + 1 {
    if self.keys[idx] == key {
      return idx
    }
  }
  self.keys.push(key)
  self.keys.length() - 1
}

///|
priv struct CLColoring {
  old_to_new : Array[Int]
  slot_types : Array[@lib.ValType]
  removed_copies : Int
}

///|
priv struct CLFuncRewrite {
  func : @lib.Func
  changed : Bool
}

///|
fn cl_imported_func_count(mod_ : @lib.Module) -> Int {
  let mut count = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn cl_local_idx_raw(idx : @lib.LocalIdx) -> Int {
  let @lib.LocalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn cl_local_idx_from_int(idx : Int) -> @lib.LocalIdx {
  @lib.LocalIdx::new(idx.reinterpret_as_uint())
}

///|
fn cl_flatten_locals(
  locals : @lib.Locals,
  local_count : Int,
) -> Array[@lib.ValType] {
  let out : Array[@lib.ValType] = Array::new(capacity=local_count)
  for run in locals.runs() {
    let ty = run.val_type()
    let run_len = run.count().reinterpret_as_int()
    for _idx = 0; _idx < run_len; _idx = _idx + 1 {
      out.push(ty)
    }
  }
  out
}

///|
fn cl_all_local_types(
  params : Array[@lib.ValType],
  body_locals : @lib.Locals,
) -> Array[@lib.ValType] {
  let body_count = body_locals.length()
  let out : Array[@lib.ValType] = Array::new(
    capacity=params.length() + body_count,
  )
  for param in params {
    out.push(param)
  }
  for body_ty in cl_flatten_locals(body_locals, body_count) {
    out.push(body_ty)
  }
  out
}

///|
fn cl_simple_const_source(instr : @lib.Instruction) -> CLValueSource? {
  match instr {
    @lib.I32Const(_)
    | @lib.I64Const(_)
    | @lib.F32Const(_)
    | @lib.F64Const(_)
    | @lib.RefNull(_)
    | @lib.StringConst(_) => Some(CLValueSource::Const(@debug.to_string(instr)))
    _ => None
  }
}

///|
fn cl_value_source_before(
  instrs : Array[@lib.Instruction],
  idx : Int,
) -> CLValueSource {
  if idx <= 0 {
    return CLValueSource::Unique
  }
  match instrs[idx - 1] {
    @lib.LocalGet(local_idx) =>
      CLValueSource::Local(cl_local_idx_raw(local_idx))
    other =>
      match cl_simple_const_source(other) {
        Some(source) => source
        None => CLValueSource::Unique
      }
  }
}

///|
fn cl_instr_is_terminal(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Unreachable
    | @lib.Return
    | @lib.ReturnCall(_)
    | @lib.ReturnCallIndirect(_, _)
    | @lib.ReturnCallRef(_)
    | @lib.Throw(_)
    | @lib.ThrowRef => true
    _ => false
  }
}

///|
fn cl_instrs_end_in_terminal(instrs : Array[@lib.Instruction]) -> Bool {
  if instrs.length() == 0 {
    return false
  }
  cl_instr_never_falls_through(instrs[instrs.length() - 1])
}

///|
fn cl_instr_never_falls_through(instr : @lib.Instruction) -> Bool {
  if cl_instr_is_terminal(instr) {
    return true
  }
  match instr {
    @lib.Block(_, @lib.Expr(body)) => cl_instrs_end_in_terminal(body)
    @lib.If(_, then_body, Some(else_body)) =>
      cl_instrs_end_in_terminal(then_body) &&
      cl_instrs_end_in_terminal(else_body)
    @lib.TryTable(_, _, @lib.Expr(body)) => cl_instrs_end_in_terminal(body)
    _ => false
  }
}

///|
fn cl_instr_makes_rest_unreachable(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Br(_) | @lib.BrTable(_, _) => true
    _ => cl_instr_never_falls_through(instr)
  }
}

///|
fn cl_collect_instrs(
  instrs : Array[@lib.Instruction],
  actions : Array[CLAction],
  total_locals : Int,
) -> Unit {
  let mut reachable = true
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    let instr = instrs[idx]
    if !reachable {
      continue
    }
    match instr {
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        cl_collect_instrs(body, actions, total_locals)
      @lib.If(_, then_body, else_body) => {
        cl_collect_instrs(then_body, actions, total_locals)
        match else_body {
          Some(body) => cl_collect_instrs(body, actions, total_locals)
          None => ()
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        cl_collect_instrs(body, actions, total_locals)
      @lib.LocalGet(local_idx) => {
        let raw = cl_local_idx_raw(local_idx)
        if raw >= 0 && raw < total_locals {
          actions.push({
            kind: CLActionKind::Get,
            local_idx: raw,
            source: CLValueSource::Unique,
          })
        }
      }
      @lib.LocalSet(local_idx) => {
        let raw = cl_local_idx_raw(local_idx)
        if raw >= 0 && raw < total_locals {
          actions.push({
            kind: CLActionKind::Set,
            local_idx: raw,
            source: cl_value_source_before(instrs, idx),
          })
        }
      }
      @lib.LocalTee(local_idx) => {
        let raw = cl_local_idx_raw(local_idx)
        if raw >= 0 && raw < total_locals {
          actions.push({
            kind: CLActionKind::Tee,
            local_idx: raw,
            source: cl_value_source_before(instrs, idx),
          })
        }
      }
      _ => ()
    }
    if cl_instr_makes_rest_unreachable(instr) {
      reachable = false
    }
  }
}

///|
fn cl_compute_liveness(
  actions : Array[CLAction],
  total_locals : Int,
) -> CLLiveness {
  let effective = Array::make(actions.length(), false)
  let live = Array::make(total_locals, false)
  let mut idx = actions.length() - 1
  while idx >= 0 {
    let action = actions[idx]
    match action.kind {
      CLActionKind::Get => live[action.local_idx] = true
      CLActionKind::Set | CLActionKind::Tee => {
        if live[action.local_idx] {
          effective[idx] = true
        }
        live[action.local_idx] = false
      }
    }
    idx -= 1
  }
  { effective, live_at_entry: live }
}

///|
fn cl_add_interference(
  interferences : Array[Array[Bool]],
  lhs : Int,
  rhs : Int,
) -> Unit {
  if lhs == rhs {
    return
  }
  interferences[lhs][rhs] = true
  interferences[rhs][lhs] = true
}

///|
fn cl_initial_value(
  interner : CLValueInterner,
  idx : Int,
  param_count : Int,
  ty : @lib.ValType,
) -> Int {
  if idx < param_count {
    interner.fresh()
  } else if @lib.has_default(ty) {
    interner.intern("default:\{@debug.to_string(ty)}")
  } else {
    interner.fresh()
  }
}

///|
fn cl_value_for_source(
  source : CLValueSource,
  current_values : Array[Int],
  interner : CLValueInterner,
) -> Int {
  match source {
    CLValueSource::Unique => interner.fresh()
    CLValueSource::Const(key) => interner.intern("const:\{key}")
    CLValueSource::Local(src_local) =>
      if src_local >= 0 && src_local < current_values.length() {
        current_values[src_local]
      } else {
        interner.fresh()
      }
  }
}

///|
fn cl_compute_interferences(
  actions : Array[CLAction],
  liveness : CLLiveness,
  types : Array[@lib.ValType],
  param_count : Int,
) -> Array[Array[Bool]] {
  let total_locals = types.length()
  let interferences : Array[Array[Bool]] = Array::new(capacity=total_locals)
  for _idx = 0; _idx < total_locals; _idx = _idx + 1 {
    interferences.push(Array::make(total_locals, false))
  }
  let interner = CLValueInterner::new()
  let current_values = Array::make(total_locals, -1)
  for idx = 0; idx < total_locals; idx = idx + 1 {
    current_values[idx] = cl_initial_value(
      interner,
      idx,
      param_count,
      types[idx],
    )
  }

  for lhs = 0; lhs < param_count; lhs = lhs + 1 {
    for rhs = lhs + 1; rhs < param_count; rhs = rhs + 1 {
      cl_add_interference(interferences, lhs, rhs)
    }
  }
  for local_idx = param_count
      local_idx < total_locals
      local_idx = local_idx + 1 {
    if liveness.live_at_entry[local_idx] {
      for param = 0; param < param_count; param = param + 1 {
        cl_add_interference(interferences, local_idx, param)
      }
      for other = param_count; other < local_idx; other = other + 1 {
        if liveness.live_at_entry[other] &&
          current_values[local_idx] != current_values[other] {
          cl_add_interference(interferences, local_idx, other)
        }
      }
    }
  }

  let remaining_gets = Array::make(total_locals, 0)
  for action in actions {
    match action.kind {
      CLActionKind::Get => remaining_gets[action.local_idx] += 1
      _ => ()
    }
  }
  let live = liveness.live_at_entry.copy()
  for action_idx = 0; action_idx < actions.length(); action_idx = action_idx + 1 {
    let action = actions[action_idx]
    match action.kind {
      CLActionKind::Get => {
        live[action.local_idx] = true
        for other = 0; other < total_locals; other = other + 1 {
          if other != action.local_idx &&
            live[other] &&
            current_values[other] != current_values[action.local_idx] {
            cl_add_interference(interferences, action.local_idx, other)
          }
        }
        remaining_gets[action.local_idx] -= 1
        if remaining_gets[action.local_idx] == 0 {
          live[action.local_idx] = false
        }
      }
      CLActionKind::Set | CLActionKind::Tee => {
        let new_value = cl_value_for_source(
          action.source,
          current_values,
          interner,
        )
        if liveness.effective[action_idx] {
          for other = 0; other < total_locals; other = other + 1 {
            if other != action.local_idx &&
              live[other] &&
              current_values[other] != new_value {
              cl_add_interference(interferences, action.local_idx, other)
            }
          }
          live[action.local_idx] = true
        } else {
          live[action.local_idx] = false
        }
        current_values[action.local_idx] = new_value
      }
    }
  }
  interferences
}

///|
fn cl_copy_weights(
  actions : Array[CLAction],
  total_locals : Int,
) -> Array[Array[Int]] {
  let weights : Array[Array[Int]] = Array::new(capacity=total_locals)
  for _idx = 0; _idx < total_locals; _idx = _idx + 1 {
    weights.push(Array::make(total_locals, 0))
  }
  for action in actions {
    match action.source {
      CLValueSource::Local(src) =>
        if src >= 0 && src < total_locals && src != action.local_idx {
          weights[action.local_idx][src] += 1
          weights[src][action.local_idx] += 1
        }
      _ => ()
    }
  }
  weights
}

///|
fn cl_slot_interferes(
  members : Array[Int],
  local_idx : Int,
  interferences : Array[Array[Bool]],
) -> Bool {
  for slot_member in members {
    if interferences[local_idx][slot_member] {
      return true
    }
  }
  false
}

///|
fn cl_slot_copy_score(
  members : Array[Int],
  local_idx : Int,
  weights : Array[Array[Int]],
) -> Int {
  let mut score = 0
  for slot_member in members {
    score += weights[local_idx][slot_member]
  }
  score
}

///|
fn cl_color_with_order(
  order : Array[Int],
  types : Array[@lib.ValType],
  param_count : Int,
  interferences : Array[Array[Bool]],
  weights : Array[Array[Int]],
) -> CLColoring {
  let total_locals = types.length()
  let old_to_new = Array::make(total_locals, -1)
  for idx = 0; idx < param_count; idx = idx + 1 {
    old_to_new[idx] = idx
  }
  let slot_types : Array[@lib.ValType] = []
  let slot_members : Array[Array[Int]] = []
  for idx = 0; idx < param_count; idx = idx + 1 {
    slot_types.push(types[idx])
    slot_members.push([idx])
  }
  for local_idx in order {
    let ty = types[local_idx]
    let mut best_slot = -1
    let mut best_score = -1
    for slot = 0; slot < slot_types.length(); slot = slot + 1 {
      if slot_types[slot] == ty &&
        !cl_slot_interferes(slot_members[slot], local_idx, interferences) {
        let score = cl_slot_copy_score(slot_members[slot], local_idx, weights)
        if score > best_score {
          best_score = score
          best_slot = slot
        }
      }
    }
    if best_slot < 0 {
      best_slot = slot_types.length()
      slot_types.push(ty)
      slot_members.push([])
    }
    old_to_new[local_idx] = best_slot
    slot_members[best_slot].push(local_idx)
  }

  let body_slot_types : Array[@lib.ValType] = []
  for slot = param_count; slot < slot_types.length(); slot = slot + 1 {
    body_slot_types.push(slot_types[slot])
  }

  let mut removed_copies = 0
  for lhs = 0; lhs < total_locals; lhs = lhs + 1 {
    for rhs = lhs + 1; rhs < total_locals; rhs = rhs + 1 {
      if old_to_new[lhs] == old_to_new[rhs] {
        removed_copies += weights[lhs][rhs]
      }
    }
  }
  { old_to_new, slot_types: body_slot_types, removed_copies }
}

///|
fn cl_coloring_is_better(candidate : CLColoring, best : CLColoring) -> Bool {
  if candidate.removed_copies != best.removed_copies {
    return candidate.removed_copies > best.removed_copies
  }
  candidate.slot_types.length() < best.slot_types.length()
}

///|
fn cl_pick_coloring(
  types : Array[@lib.ValType],
  param_count : Int,
  interferences : Array[Array[Bool]],
  weights : Array[Array[Int]],
) -> CLColoring {
  let natural : Array[Int] = []
  for idx = param_count; idx < types.length(); idx = idx + 1 {
    natural.push(idx)
  }
  let reverse : Array[Int] = []
  let mut idx = types.length() - 1
  while idx >= param_count {
    reverse.push(idx)
    idx -= 1
  }
  let best = cl_color_with_order(
    natural, types, param_count, interferences, weights,
  )
  let other = cl_color_with_order(
    reverse, types, param_count, interferences, weights,
  )
  if cl_coloring_is_better(other, best) {
    other
  } else {
    best
  }
}

///|
fn cl_rewrite_local_idx(
  idx : @lib.LocalIdx,
  old_to_new : Array[Int],
) -> @lib.LocalIdx {
  let raw = cl_local_idx_raw(idx)
  if raw < 0 || raw >= old_to_new.length() {
    abort("coalesce-locals local remap out of range")
  }
  cl_local_idx_from_int(old_to_new[raw])
}

///|
fn cl_rewrite_instrs_in_place(
  instrs : Array[@lib.Instruction],
  old_to_new : Array[Int],
  effective : Array[Bool],
  action_cursor : Array[Int],
) -> Unit {
  let mut reachable = true
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    let instr = instrs[idx]
    if !reachable {
      match instr {
        @lib.LocalGet(local_idx) =>
          instrs[idx] = @lib.Instruction::local_get(
            cl_rewrite_local_idx(local_idx, old_to_new),
          )
        @lib.LocalSet(local_idx) =>
          instrs[idx] = @lib.Instruction::local_set(
            cl_rewrite_local_idx(local_idx, old_to_new),
          )
        @lib.LocalTee(local_idx) =>
          instrs[idx] = @lib.Instruction::local_tee(
            cl_rewrite_local_idx(local_idx, old_to_new),
          )
        _ => ()
      }
      continue
    }
    match instr {
      @lib.Block(block_type, @lib.Expr(body)) => {
        cl_rewrite_instrs_in_place(body, old_to_new, effective, action_cursor)
        instrs[idx] = @lib.Instruction::block(block_type, @lib.Expr::new(body))
      }
      @lib.Loop(block_type, @lib.Expr(body)) => {
        cl_rewrite_instrs_in_place(body, old_to_new, effective, action_cursor)
        instrs[idx] = @lib.Instruction::loop_(block_type, @lib.Expr::new(body))
      }
      @lib.If(block_type, then_body, else_body) => {
        cl_rewrite_instrs_in_place(
          then_body, old_to_new, effective, action_cursor,
        )
        match else_body {
          Some(else_instrs) =>
            cl_rewrite_instrs_in_place(
              else_instrs, old_to_new, effective, action_cursor,
            )
          None => ()
        }
        instrs[idx] = @lib.Instruction::if_(block_type, then_body, else_body)
      }
      @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
        cl_rewrite_instrs_in_place(body, old_to_new, effective, action_cursor)
        instrs[idx] = @lib.Instruction::try_table(
          block_type,
          catches,
          @lib.Expr::new(body),
        )
      }
      @lib.LocalGet(local_idx) => {
        action_cursor[0] += 1
        instrs[idx] = @lib.Instruction::local_get(
          cl_rewrite_local_idx(local_idx, old_to_new),
        )
      }
      @lib.LocalSet(local_idx) => {
        let action_idx = action_cursor[0]
        action_cursor[0] += 1
        if action_idx < effective.length() && !effective[action_idx] {
          instrs[idx] = @lib.Instruction::drop()
        } else {
          instrs[idx] = @lib.Instruction::local_set(
            cl_rewrite_local_idx(local_idx, old_to_new),
          )
        }
      }
      @lib.LocalTee(local_idx) => {
        let action_idx = action_cursor[0]
        action_cursor[0] += 1
        if action_idx < effective.length() && !effective[action_idx] {
          instrs[idx] = @lib.Instruction::nop()
        } else {
          instrs[idx] = @lib.Instruction::local_tee(
            cl_rewrite_local_idx(local_idx, old_to_new),
          )
        }
      }
      _ => ()
    }
    if cl_instr_makes_rest_unreachable(instr) {
      reachable = false
    }
  }
}

///|
fn cl_truncate_dead_tails(instrs : Array[@lib.Instruction]) -> Bool {
  let mut changed = false
  let out : Array[@lib.Instruction] = []
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    let mut instr = instrs[idx]
    match instr {
      @lib.Block(block_type, @lib.Expr(body)) => {
        if cl_truncate_dead_tails(body) {
          changed = true
        }
        instr = @lib.Instruction::block(block_type, @lib.Expr::new(body))
      }
      @lib.Loop(block_type, @lib.Expr(body)) => {
        if cl_truncate_dead_tails(body) {
          changed = true
        }
        instr = @lib.Instruction::loop_(block_type, @lib.Expr::new(body))
      }
      @lib.If(block_type, then_body, else_body) => {
        if cl_truncate_dead_tails(then_body) {
          changed = true
        }
        match else_body {
          Some(else_instrs) =>
            if cl_truncate_dead_tails(else_instrs) {
              changed = true
            }
          None => ()
        }
        instr = @lib.Instruction::if_(block_type, then_body, else_body)
      }
      @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
        if cl_truncate_dead_tails(body) {
          changed = true
        }
        instr = @lib.Instruction::try_table(
          block_type,
          catches,
          @lib.Expr::new(body),
        )
      }
      _ => ()
    }
    out.push(instr)
    if cl_instr_makes_rest_unreachable(instr) && idx + 1 < instrs.length() {
      if !cl_instr_is_terminal(instr) {
        out.push(@lib.Instruction::unreachable_())
      }
      changed = true
      break
    }
  }
  if changed {
    instrs.clear()
    for instr in out {
      instrs.push(instr)
    }
  }
  changed
}

///|
fn cl_remove_redundant_copy_pairs(instrs : Array[@lib.Instruction]) -> Bool {
  let mut changed = false
  let out : Array[@lib.Instruction] = []
  let mut idx = 0
  while idx < instrs.length() {
    match instrs[idx] {
      @lib.Block(block_type, @lib.Expr(body)) => {
        if cl_remove_redundant_copy_pairs(body) {
          changed = true
        }
        out.push(@lib.Instruction::block(block_type, @lib.Expr::new(body)))
      }
      @lib.Loop(block_type, @lib.Expr(body)) => {
        if cl_remove_redundant_copy_pairs(body) {
          changed = true
        }
        out.push(@lib.Instruction::loop_(block_type, @lib.Expr::new(body)))
      }
      @lib.If(block_type, then_body, else_body) => {
        if cl_remove_redundant_copy_pairs(then_body) {
          changed = true
        }
        match else_body {
          Some(else_instrs) =>
            if cl_remove_redundant_copy_pairs(else_instrs) {
              changed = true
            }
          None => ()
        }
        out.push(@lib.Instruction::if_(block_type, then_body, else_body))
      }
      @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
        if cl_remove_redundant_copy_pairs(body) {
          changed = true
        }
        out.push(
          @lib.Instruction::try_table(block_type, catches, @lib.Expr::new(body)),
        )
      }
      @lib.LocalGet(local_idx) if idx + 1 < instrs.length() =>
        match instrs[idx + 1] {
          @lib.LocalSet(next_idx) if next_idx == local_idx => {
            out.push(@lib.Instruction::nop())
            changed = true
            idx += 1
          }
          @lib.LocalTee(next_idx) if next_idx == local_idx => {
            out.push(@lib.Instruction::local_get(local_idx))
            changed = true
            idx += 1
          }
          _ => out.push(instrs[idx])
        }
      _ => out.push(instrs[idx])
    }
    idx += 1
  }
  if changed {
    instrs.clear()
    for instr in out {
      instrs.push(instr)
    }
  }
  changed
}

///|
fn cl_old_to_new_is_identity(old_to_new : Array[Int]) -> Bool {
  for idx = 0; idx < old_to_new.length(); idx = idx + 1 {
    if old_to_new[idx] != idx {
      return false
    }
  }
  true
}

///|
fn cl_rewrite_func(
  func : @lib.Func,
  params : Array[@lib.ValType],
) -> CLFuncRewrite {
  let @lib.Func(body_locals, body) = func
  let body_local_count = body_locals.length()
  if body_local_count == 0 {
    return { func, changed: false }
  }
  let types = cl_all_local_types(params, body_locals)
  let total_locals = types.length()
  let actions : Array[CLAction] = []
  let @lib.Expr(original_instrs) = body
  cl_collect_instrs(original_instrs, actions, total_locals)
  let liveness = cl_compute_liveness(actions, total_locals)
  let interferences = cl_compute_interferences(
    actions,
    liveness,
    types,
    params.length(),
  )
  let weights = cl_copy_weights(actions, total_locals)
  let coloring = cl_pick_coloring(
    types,
    params.length(),
    interferences,
    weights,
  )
  let rewritten_locals = @lib.Locals::from_types(coloring.slot_types)
  let rewritten_instrs = original_instrs.copy()
  cl_rewrite_instrs_in_place(
    rewritten_instrs,
    coloring.old_to_new,
    liveness.effective,
    [0],
  )
  let rewrite_changed = rewritten_instrs != original_instrs
  let dead_tail_changed = cl_truncate_dead_tails(rewritten_instrs)
  let cleanup_changed = cl_remove_redundant_copy_pairs(rewritten_instrs)
  let changed = rewrite_changed ||
    dead_tail_changed ||
    cleanup_changed ||
    !cl_old_to_new_is_identity(coloring.old_to_new) ||
    rewritten_locals != body_locals
  if !changed {
    return { func, changed: false }
  }
  {
    func: @lib.Func::new(rewritten_locals, @lib.Expr::new(rewritten_instrs)),
    changed: true,
  }
}

///|
fn cl_module_subtypes(mod_ : @lib.Module) -> Array[@lib.SubType] {
  let subtypes : Array[@lib.SubType] = match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) => Array::new(capacity=rec_types.length())
    None => []
  }
  match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) =>
      for rec_type in rec_types {
        match rec_type {
          @lib.SingleRecType(subtype) => subtypes.push(subtype)
          @lib.GroupRecType(group) =>
            for subtype in group {
              subtypes.push(subtype)
            }
        }
      }
    None => abort("coalesce-locals missing type section")
  }
  subtypes
}

///|
fn cl_params_for_type_idx(
  subtypes : Array[@lib.SubType],
  type_idx : @lib.TypeIdx,
) -> Array[@lib.ValType] {
  let subtype = match type_idx {
    @lib.TypeIdx(type_pos) =>
      match subtypes.get(type_pos.reinterpret_as_int()) {
        Some(subtype) => subtype
        None => abort("coalesce-locals missing function subtype")
      }
    @lib.RecIdx(_) =>
      abort("coalesce-locals unsupported recursive function type index")
  }
  match subtype.get_comptype() {
    @lib.FuncCompType(params, _) => params
    _ => abort("coalesce-locals expected function type")
  }
}

///|
fn cl_defined_func_param_cache(
  mod_ : @lib.Module,
) -> Array[Array[@lib.ValType]] {
  let subtypes = cl_module_subtypes(mod_)
  let out : Array[Array[@lib.ValType]] = match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => Array::new(capacity=type_idxs.length())
    None => []
  }
  match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) =>
      for type_idx in type_idxs {
        out.push(cl_params_for_type_idx(subtypes, type_idx))
      }
    None => abort("coalesce-locals missing function section")
  }
  out
}

///|
fn cl_name_sec_without_local_names(name_sec : @lib.NameSec?) -> @lib.NameSec? {
  match name_sec {
    Some(sec) => {
      let {
        module_name,
        func_names,
        label_names,
        type_names,
        table_names,
        memory_names,
        global_names,
        elem_names,
        data_names,
        field_names,
        tag_names,
        ..,
      } = sec
      Some(
        @lib.NameSec::new(
          module_name~,
          func_names~,
          local_names=None,
          label_names~,
          type_names~,
          table_names~,
          memory_names~,
          global_names~,
          elem_names~,
          data_names~,
          field_names~,
          tag_names~,
        ),
      )
    }
    None => None
  }
}

///|
fn cl_rebuild_module(
  mod_ : @lib.Module,
  next_code_sec : @lib.CodeSec?,
  next_name_sec : @lib.NameSec?,
) -> @lib.Module {
  @lib.Module::new(
    custom_secs=mod_.custom_secs,
    type_sec=mod_.type_sec,
    import_sec=mod_.import_sec,
    func_annotation_sec=mod_.func_annotation_sec,
    func_sec=mod_.func_sec,
    table_sec=mod_.table_sec,
    mem_sec=mod_.mem_sec,
    tag_sec=mod_.tag_sec,
    stringrefs_sec=mod_.stringrefs_sec,
    global_sec=mod_.global_sec,
    export_sec=mod_.export_sec,
    start_sec=mod_.start_sec,
    elem_sec=mod_.elem_sec,
    data_cnt_sec=mod_.data_cnt_sec,
    code_sec=next_code_sec,
    data_sec=mod_.data_sec,
    name_sec=next_name_sec,
  )
}

///|
pub fn coalesce_locals_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  ignore(cl_imported_func_count(mod_))
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let defined_func_params = cl_defined_func_param_cache(mod_)
      let rewritten_funcs : Array[@lib.Func] = Array::new(
        capacity=funcs.length(),
      )
      let mut changed = false
      for code_idx = 0; code_idx < funcs.length(); code_idx = code_idx + 1 {
        let params = match defined_func_params.get(code_idx) {
          Some(params) => params
          None => abort("coalesce-locals missing defined function params")
        }
        let rewrite = cl_rewrite_func(funcs[code_idx], params)
        rewritten_funcs.push(rewrite.func)
        if rewrite.changed {
          changed = true
        }
      }
      if !changed {
        return mod_
      }
      cl_rebuild_module(
        mod_,
        Some(@lib.CodeSec::new(rewritten_funcs)),
        cl_name_sec_without_local_names(mod_.name_sec),
      )
    }
    None => mod_
  }
}
