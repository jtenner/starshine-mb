///| 
/// Copyright 2023 WebAssembly Community Group participants
/// 
/// Licensed under the Apache License, Version 2.0 (the "License");
/// you may not use this file except in compliance with the License.
/// You may obtain a copy of the License at
/// 
///     http://www.apache.org/licenses/LICENSE-2.0
/// 
/// Unless required by applicable law or agreed to in writing, software
/// distributed under the License is distributed on an "AS IS" BASIS,
/// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
/// See the License for the specific language governing permissions and
/// limitations under the License.
///

///|
const RUB_TOO_COSTLY_TO_RUN_UNCONDITIONALLY : Int = 8

///|
const RUB_LABEL_REBASE_CROSSES_REMOVED_SCOPE : String = "__remove_unused_brs_label_rebase_crosses_removed_scope__"

///|
const RUB_TRACE_PROGRESS_INTERVAL : Int = 4096

///|
const RUB_TRACE_PROGRESS_INTERVAL_MS : UInt64 = 250UL

///|
const RUB_TRACE_SLOW_CALL_MS : UInt64 = 50UL

///|
const RUB_TRACE_NO_PROGRESS_TIMEOUT_MS : UInt64 = 2000UL

///|
const RUB_NO_PROGRESS_TIMEOUT : String = "__remove_unused_brs_no_progress_timeout__"

///|
const RUB_JUMP_THREAD_BR_CHILD_SCOPE_REWRITE_ABORTED : String = "__remove_unused_brs_jump_thread_br_child_scope_rewrite_aborted__"

///|
const RUB_JUMP_THREAD_BR_CHILD_SCOPE_SCAN_VISIT_BUDGET : Int = 200000

///|
const RUB_JUMP_THREAD_BR_CHILD_SCOPE_SCAN_GUARD_INTERVAL : Int = 256

///|
const RUB_JUMP_THREAD_BR_CHILD_SCOPE_SCAN_TIMEOUT_MS : UInt64 = 200UL

///|
const RUB_JUMP_THREAD_BR_CHILD_SCOPE_REWRITE_VISIT_BUDGET : Int = 20000

///|
const RUB_JUMP_THREAD_BR_CHILD_SCOPE_REWRITE_GUARD_INTERVAL : Int = 256

///|
const RUB_JUMP_THREAD_BR_CHILD_SCOPE_REWRITE_TIMEOUT_MS : UInt64 = 200UL

///|
fn rub_trace_noop(_ : String) -> Unit {
  ()
}

///|
fn rub_trace_should_log_func(ordinal : Int, trace_all_funcs : Bool) -> Bool {
  pass_trace_log_enabled(ordinal, trace_all_funcs)
}

///|
fn rub_instr_kind_name(instr : TInstr) -> String {
  match instr.kind {
    TInstrKind::TBlock(_, _) => "block"
    TInstrKind::TLoop(_, _) => "loop"
    TInstrKind::TIf(_, _, _, _) => "if"
    TInstrKind::TTryTable(_, _, _) => "try_table"
    TInstrKind::TBr(_, _) => "br"
    TInstrKind::TBrIf(_, _, _) => "br_if"
    TInstrKind::TBrTable(_, _, _, _) => "br_table"
    TInstrKind::TReturn(_) => "return"
    TInstrKind::TDrop(_) => "drop"
    TInstrKind::TSelect(_, _, _, _) => "select"
    TInstrKind::TCall(_, _) => "call"
    TInstrKind::TCallIndirect(_, _, _, _) => "call_indirect"
    TInstrKind::TLocalGet(_) => "local.get"
    TInstrKind::TLocalSet(_, _) => "local.set"
    TInstrKind::TLocalTee(_, _) => "local.tee"
    _ => "other"
  }
}

///|
priv struct RUBRoundTraceState {
  log_func : Bool
  trace : (String) -> Unit
  ordinal : Int
  round : Int
  func_start_ms : UInt64
  round_start_ms : UInt64
  last_progress_ms : Ref[UInt64]
  no_progress_deadline_ms : Ref[UInt64]
  expr_visits : Ref[Int]
  instr_visits : Ref[Int]
  rewrites : Ref[Int]
}

///|
priv enum RUBChildScopeBranchScanResult {
  ScanFound
  ScanNotFound
  ScanAborted
}

///|
priv struct RUBChildScopeBranchScanState {
  remaining_budget : Ref[Int]
  visits_until_guard : Ref[Int]
  start_ms : UInt64
  trace_state : RUBRoundTraceState?
  no_progress_phase : String
}

///|
priv struct RUBChildScopeBranchRewriteState {
  remaining_budget : Ref[Int]
  visits_until_guard : Ref[Int]
  start_ms : UInt64
  trace_state : RUBRoundTraceState?
  no_progress_phase : String
}

///|
fn rub_round_trace_state(
  log_func : Bool,
  trace : (String) -> Unit,
  ordinal : Int,
  round : Int,
  func_start_ms : UInt64,
) -> RUBRoundTraceState {
  let round_start_ms = sl_trace_now_ms()
  {
    log_func,
    trace,
    ordinal,
    round,
    func_start_ms,
    round_start_ms,
    last_progress_ms: Ref::new(0UL),
    no_progress_deadline_ms: Ref::new(
      round_start_ms + RUB_TRACE_NO_PROGRESS_TIMEOUT_MS,
    ),
    expr_visits: Ref::new(0),
    instr_visits: Ref::new(0),
    rewrites: Ref::new(0),
  }
}

///|
fn rub_trace_emit_round_start(
  trace_state : RUBRoundTraceState,
  top_instrs : Int,
) -> Unit {
  let now_ms = sl_trace_now_ms()
  trace_state.last_progress_ms.val = now_ms
  trace_state.no_progress_deadline_ms.val = now_ms +
    RUB_TRACE_NO_PROGRESS_TIMEOUT_MS
  if !trace_state.log_func {
    return
  }
  (trace_state.trace)(
    "func[\{trace_state.ordinal}] round[\{trace_state.round}] walk:start top_instrs=\{top_instrs}",
  )
  (trace_state.trace)(
    "func[\{trace_state.ordinal}] round[\{trace_state.round}] progress phase=walk:start elapsed_ms=\{sl_trace_elapsed_ms(trace_state.func_start_ms)} round_ms=\{sl_trace_elapsed_ms(trace_state.round_start_ms)} exprs=0 instrs=0 rewrites=0",
  )
}

///|
fn rub_trace_maybe_emit_progress(
  trace_state : RUBRoundTraceState,
  phase : String,
) -> Unit {
  let now_ms = sl_trace_now_ms()
  let expr_visits = trace_state.expr_visits.val
  let instr_visits = trace_state.instr_visits.val
  let rewrites = trace_state.rewrites.val
  let work_done = expr_visits + instr_visits + rewrites
  let has_emitted_progress = trace_state.last_progress_ms.val != 0UL
  let since_last_ms = if has_emitted_progress &&
    now_ms >= trace_state.last_progress_ms.val {
    now_ms - trace_state.last_progress_ms.val
  } else {
    0UL
  }
  let should_emit_first = !has_emitted_progress && work_done >= 32
  let should_emit_periodic = (
      expr_visits > 0 &&
      (
        (expr_visits <= 256 && expr_visits % 64 == 0) ||
        expr_visits % RUB_TRACE_PROGRESS_INTERVAL == 0
      )
    ) ||
    (
      instr_visits > 0 &&
      (
        (instr_visits <= 512 && instr_visits % 128 == 0) ||
        instr_visits % RUB_TRACE_PROGRESS_INTERVAL == 0
      )
    ) ||
    (rewrites > 0 && rewrites % 32 == 0)
  let should_emit_timed = since_last_ms >= RUB_TRACE_PROGRESS_INTERVAL_MS

  if !(should_emit_first || should_emit_periodic || should_emit_timed) {
    return
  }

  trace_state.last_progress_ms.val = now_ms
  trace_state.no_progress_deadline_ms.val = now_ms +
    RUB_TRACE_NO_PROGRESS_TIMEOUT_MS
  if !trace_state.log_func {
    return
  }
  (trace_state.trace)(
    "func[\{trace_state.ordinal}] round[\{trace_state.round}] progress phase=\{phase} elapsed_ms=\{sl_trace_elapsed_ms(trace_state.func_start_ms)} round_ms=\{sl_trace_elapsed_ms(trace_state.round_start_ms)} exprs=\{expr_visits} instrs=\{instr_visits} rewrites=\{rewrites}",
  )
}

///|
fn rub_trace_check_no_progress(
  trace_state : RUBRoundTraceState?,
  phase : String,
) -> Result[Unit, String] {
  match trace_state {
    Some(trace_state) => {
      let now_ms = sl_trace_now_ms()
      if now_ms <= trace_state.no_progress_deadline_ms.val {
        return Ok(())
      }
      if trace_state.log_func {
        (trace_state.trace)(
          "func[\{trace_state.ordinal}] round[\{trace_state.round}] abort reason=no_progress_timeout phase=\{phase} elapsed_ms=\{sl_trace_elapsed_ms(trace_state.func_start_ms)} round_ms=\{sl_trace_elapsed_ms(trace_state.round_start_ms)} exprs=\{trace_state.expr_visits.val} instrs=\{trace_state.instr_visits.val} rewrites=\{trace_state.rewrites.val}",
        )
      }
      Err(RUB_NO_PROGRESS_TIMEOUT)
    }
    None => Ok(())
  }
}

///|
fn rub_trace_log_slow_instr(
  trace_state : RUBRoundTraceState?,
  phase : String,
  instr : TInstr,
  elapsed_ms : UInt64,
) -> Unit {
  if elapsed_ms < RUB_TRACE_SLOW_CALL_MS {
    return
  }
  match trace_state {
    Some(trace_state) =>
      if trace_state.log_func {
        (trace_state.trace)(
          "func[\{trace_state.ordinal}] round[\{trace_state.round}] slow phase=\{phase} kind=\{rub_instr_kind_name(instr)} elapsed_ms=\{elapsed_ms} children=\{eval_children(instr).length()}",
        )
      }
    None => ()
  }
}

///|
fn rub_trace_log_slow_helper(
  trace_state : RUBRoundTraceState?,
  helper : String,
  elapsed_ms : UInt64,
  instrs_len : Int,
) -> Unit {
  if elapsed_ms < RUB_TRACE_SLOW_CALL_MS {
    return
  }
  match trace_state {
    Some(trace_state) =>
      if trace_state.log_func {
        (trace_state.trace)(
          "func[\{trace_state.ordinal}] round[\{trace_state.round}] slow phase=helper helper=\{helper} elapsed_ms=\{elapsed_ms} instrs=\{instrs_len}",
        )
      }
    None => ()
  }
}

///|
fn rub_trace_log_helper_event(
  trace_state : RUBRoundTraceState?,
  helper : String,
  step : String,
  detail : String,
) -> Unit {
  match trace_state {
    Some(trace_state) =>
      if trace_state.log_func {
        (trace_state.trace)(
          "func[\{trace_state.ordinal}] round[\{trace_state.round}] helper=\{helper} step=\{step} \{detail}",
        )
      }
    None => ()
  }
}

///|
fn rub_trace_log_helper_step_done(
  trace_state : RUBRoundTraceState?,
  helper : String,
  step : String,
  elapsed_ms : UInt64,
  detail : String,
) -> Unit {
  if elapsed_ms < RUB_TRACE_SLOW_CALL_MS {
    return
  }
  match trace_state {
    Some(trace_state) =>
      if trace_state.log_func {
        (trace_state.trace)(
          "func[\{trace_state.ordinal}] round[\{trace_state.round}] helper=\{helper} step=\{step}:done elapsed_ms=\{elapsed_ms} \{detail}",
        )
      }
    None => ()
  }
}

///|
fn rub_trace_note_expr(
  trace_state : RUBRoundTraceState?,
  phase : String,
) -> Result[Unit, String] {
  match trace_state {
    Some(trace_state) => {
      match rub_trace_check_no_progress(Some(trace_state), phase) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      trace_state.expr_visits.val += 1
      rub_trace_maybe_emit_progress(trace_state, phase)
      Ok(())
    }
    None => Ok(())
  }
}

///|
fn rub_trace_note_instr(
  trace_state : RUBRoundTraceState?,
  phase : String,
) -> Result[Unit, String] {
  match trace_state {
    Some(trace_state) => {
      match rub_trace_check_no_progress(Some(trace_state), phase) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      trace_state.instr_visits.val += 1
      rub_trace_maybe_emit_progress(trace_state, phase)
      Ok(())
    }
    None => Ok(())
  }
}

///|
fn rub_trace_note_rewrite(
  trace_state : RUBRoundTraceState?,
  phase : String,
) -> Result[Unit, String] {
  match trace_state {
    Some(trace_state) => {
      match rub_trace_check_no_progress(Some(trace_state), phase) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      trace_state.rewrites.val += 1
      rub_trace_maybe_emit_progress(trace_state, phase)
      Ok(())
    }
    None => Ok(())
  }
}

///|
priv struct RUBTryTableCatcher {
  catches : Array[Catch]
  depth : Int
}

///|
priv struct RUBWalkState {
  in_function_body : Bool
  allow_list_splicing : Bool
  zero_break_is_fallthrough : Bool
  label_depth : Int
  catchers : Array[RUBTryTableCatcher]
  tag_payload_types : Map[TagIdx, Array[ValType]]
  local_base_count : Int
  scratch_locals : Ref[Array[ValType]]
}

///|
fn rub_new_scratch_locals_ref() -> Ref[Array[ValType]] {
  Ref::new([])
}

///|
fn rub_walk_state(
  in_function_body : Bool,
  allow_list_splicing : Bool,
  zero_break_is_fallthrough : Bool,
  label_depth? : Int = 0,
  catchers? : Array[RUBTryTableCatcher] = [],
  tag_payload_types? : Map[TagIdx, Array[ValType]] = Map::new(),
  local_base_count? : Int = 0,
  scratch_locals? : Ref[Array[ValType]] = rub_new_scratch_locals_ref(),
) -> RUBWalkState {
  {
    in_function_body,
    allow_list_splicing,
    zero_break_is_fallthrough,
    label_depth,
    catchers,
    tag_payload_types,
    local_base_count,
    scratch_locals,
  }
}

///|
fn rub_walk_function_body_state(root : RUBWalkState) -> RUBWalkState {
  rub_walk_state(
    true,
    false,
    true,
    label_depth=0,
    catchers=[],
    tag_payload_types=root.tag_payload_types,
    local_base_count=root.local_base_count,
    scratch_locals=root.scratch_locals,
  )
}

///|
fn rub_walk_nested_texpr_state(
  parent : RUBWalkState,
  bt : BlockType,
  zero_break_is_fallthrough : Bool,
) -> RUBWalkState {
  match bt {
    VoidBlockType =>
      rub_walk_state(
        false,
        true,
        zero_break_is_fallthrough,
        label_depth=parent.label_depth + 1,
        catchers=parent.catchers,
        tag_payload_types=parent.tag_payload_types,
        local_base_count=parent.local_base_count,
        scratch_locals=parent.scratch_locals,
      )
    _ =>
      rub_walk_state(
        false,
        false,
        zero_break_is_fallthrough,
        label_depth=parent.label_depth + 1,
        catchers=parent.catchers,
        tag_payload_types=parent.tag_payload_types,
        local_base_count=parent.local_base_count,
        scratch_locals=parent.scratch_locals,
      )
  }
}

///|
fn rub_push_try_table_catcher(
  state : RUBWalkState,
  catches : Array[Catch],
) -> RUBWalkState {
  let next_catchers = state.catchers.copy()
  next_catchers.push({ catches, depth: state.label_depth })
  rub_walk_state(
    state.in_function_body,
    state.allow_list_splicing,
    state.zero_break_is_fallthrough,
    label_depth=state.label_depth,
    catchers=next_catchers,
    tag_payload_types=state.tag_payload_types,
    local_base_count=state.local_base_count,
    scratch_locals=state.scratch_locals,
  )
}

///|
fn ModuleTransformer::rub_walk_tinstruction_result(
  self : ModuleTransformer[RUBWalkState, String],
  state : RUBWalkState,
  instr : TInstr,
) -> Result[TInstr, String] {
  match self.walk_tinstruction(state, instr) {
    Ok((next_instr, _)) => Ok(next_instr)
    Err(e) => Err(e)
  }
}

///|
fn ModuleTransformer::rub_walk_texpr_result(
  self : ModuleTransformer[RUBWalkState, String],
  state : RUBWalkState,
  expr : TExpr,
) -> Result[TExpr, String] {
  match self.walk_texpr(state, expr) {
    Ok((next_expr, _)) => Ok(next_expr)
    Err(e) => Err(e)
  }
}

///|
fn ModuleTransformer::rub_walk_blocktype_result(
  self : ModuleTransformer[RUBWalkState, String],
  state : RUBWalkState,
  bt : BlockType,
) -> Result[BlockType, String] {
  match self.walk_blocktype(state, bt) {
    Ok((next_bt, _)) => Ok(next_bt)
    Err(e) => Err(e)
  }
}

///|
fn ModuleTransformer::rub_walk_catches_result(
  self : ModuleTransformer[RUBWalkState, String],
  state : RUBWalkState,
  catches : Array[Catch],
) -> Result[Array[Catch], String] {
  match self.walk_array(state, ModuleTransformer::walk_catch, catches) {
    Ok((next_catches, _)) => Ok(next_catches)
    Err(e) => Err(e)
  }
}

///|
fn rub_label_to_int(label : LabelIdx) -> Int {
  let LabelIdx(raw) = label
  raw.reinterpret_as_int()
}

///|
fn rub_label_from_int(idx : Int) -> LabelIdx {
  LabelIdx::new(idx.reinterpret_as_uint())
}

///|
fn rub_is_label_zero(label : LabelIdx) -> Bool {
  rub_label_to_int(label) == 0
}

///|
fn rub_shift_label_at_depth(
  label : LabelIdx,
  depth : Int,
  delta : Int,
) -> Result[LabelIdx, String] {
  if delta == 0 {
    return Ok(label)
  }
  let curr = rub_label_to_int(label)
  if delta > 0 {
    if curr >= depth {
      Ok(rub_label_from_int(curr + delta))
    } else {
      Ok(label)
    }
  } else {
    let removed_scopes = -delta
    if curr < depth {
      Ok(label)
    } else if curr < depth + removed_scopes {
      Err(RUB_LABEL_REBASE_CROSSES_REMOVED_SCOPE)
    } else {
      Ok(rub_label_from_int(curr + delta))
    }
  }
}

///|
fn rub_walk_tinstruction_with_depth(
  transformer : ModuleTransformer[Int, String],
  depth : Int,
  instr : TInstr,
) -> VisitAction[Int, TInstr, String] {
  match instr.kind {
    TInstrKind::TBlock(bt, body) => {
      let next_body = match transformer.walk_texpr(depth + 1, body) {
        Ok((out, _)) => out
        Err(e) => return error(e)
      }
      if next_body == body {
        unchanged()
      } else {
        change(depth, TInstr::block(bt, next_body))
      }
    }
    TInstrKind::TLoop(bt, body) => {
      let next_body = match transformer.walk_texpr(depth + 1, body) {
        Ok((out, _)) => out
        Err(e) => return error(e)
      }
      if next_body == body {
        unchanged()
      } else {
        change(depth, TInstr::loop_(bt, next_body))
      }
    }
    TInstrKind::TIf(bt, cond, then_body, else_body) => {
      let next_cond = match transformer.walk_tinstruction(depth, cond) {
        Ok((out, _)) => out
        Err(e) => return error(e)
      }
      let next_then = match transformer.walk_texpr(depth + 1, then_body) {
        Ok((out, _)) => out
        Err(e) => return error(e)
      }
      let next_else = match else_body {
        Some(other) =>
          match transformer.walk_texpr(depth + 1, other) {
            Ok((out, _)) => Some(out)
            Err(e) => return error(e)
          }
        None => None
      }
      let next_instr = TInstr::if_(bt, next_cond, next_then, next_else)
      if next_instr == instr {
        unchanged()
      } else {
        change(depth, next_instr)
      }
    }
    TInstrKind::TTryTable(bt, catches, body) => {
      let next_catches = match
        transformer.walk_array(
          depth + 1,
          ModuleTransformer::walk_catch,
          catches,
        ) {
        Ok((out, _)) => out
        Err(e) => return error(e)
      }
      let next_body = match transformer.walk_texpr(depth + 1, body) {
        Ok((out, _)) => out
        Err(e) => return error(e)
      }
      let next_instr = TInstr::try_table(bt, next_catches, next_body)
      if next_instr == instr {
        unchanged()
      } else {
        change(depth, next_instr)
      }
    }
    _ => from_walk(transformer.walk_tinstruction_default(depth, instr))
  }
}

///|
fn rub_rebase_labels_in_texpr_result(
  expr : TExpr,
  delta : Int,
) -> Result[TExpr, String] {
  rub_rebase_labels_in_texpr_from_depth_result(expr, 0, delta)
}

///|
fn rub_rebase_labels_in_texpr_from_depth_result(
  expr : TExpr,
  start_depth : Int,
  delta : Int,
) -> Result[TExpr, String] {
  if delta == 0 {
    return Ok(expr)
  }
  let pass = ModuleTransformer::new()
    .on_labelidx_evt(fn(_, depth, label) {
      match rub_shift_label_at_depth(label, depth, delta) {
        Ok(next) =>
          if next == label {
            unchanged()
          } else {
            change(depth, next)
          }
        Err(e) => error(e)
      }
    })
    .on_tinstruction_evt(fn(self, depth, instr) {
      rub_walk_tinstruction_with_depth(self, depth, instr)
    })
  match pass.walk_texpr(start_depth, expr) {
    Ok((out, _)) => Ok(out)
    Err(e) => Err(e)
  }
}

///|
fn rub_rebase_labels_in_tinstruction_result(
  instr : TInstr,
  delta : Int,
) -> Result[TInstr, String] {
  if delta == 0 {
    return Ok(instr)
  }
  let pass = ModuleTransformer::new()
    .on_labelidx_evt(fn(_, depth, label) {
      match rub_shift_label_at_depth(label, depth, delta) {
        Ok(next) =>
          if next == label {
            unchanged()
          } else {
            change(depth, next)
          }
        Err(e) => error(e)
      }
    })
    .on_tinstruction_evt(fn(self, depth, curr) {
      rub_walk_tinstruction_with_depth(self, depth, curr)
    })
  match pass.walk_tinstruction(0, instr) {
    Ok((out, _)) => Ok(out)
    Err(e) => Err(e)
  }
}

///|
fn rub_try_rebase_labels_in_texpr(expr : TExpr, delta : Int) -> TExpr? {
  match rub_rebase_labels_in_texpr_result(expr, delta) {
    Ok(out) => Some(out)
    Err(e) =>
      if e == RUB_LABEL_REBASE_CROSSES_REMOVED_SCOPE {
        None
      } else {
        abort("unexpected remove_unused_brs texpr label rebase failure: \{e}")
      }
  }
}

///|
fn rub_try_rebase_labels_in_if_arm(expr : TExpr, delta : Int) -> TExpr? {
  match rub_rebase_labels_in_texpr_from_depth_result(expr, 1, delta) {
    Ok(out) => Some(out)
    Err(e) =>
      if e == RUB_LABEL_REBASE_CROSSES_REMOVED_SCOPE {
        None
      } else {
        abort("unexpected remove_unused_brs if-arm label rebase failure: \{e}")
      }
  }
}

///|
fn rub_try_rebase_labels_in_tinstruction(
  instr : TInstr,
  delta : Int,
) -> TInstr? {
  match rub_rebase_labels_in_tinstruction_result(instr, delta) {
    Ok(out) => Some(out)
    Err(e) =>
      if e == RUB_LABEL_REBASE_CROSSES_REMOVED_SCOPE {
        None
      } else {
        abort(
          "unexpected remove_unused_brs tinstruction label rebase failure: \{e}",
        )
      }
  }
}

///|
fn rub_rebase_labels_in_tinstruction(instr : TInstr, delta : Int) -> TInstr {
  match rub_rebase_labels_in_tinstruction_result(instr, delta) {
    Ok(out) => out
    Err(e) => abort("remove_unused_brs label rebase failed: \{e}")
  }
}

///|
fn rub_retarget_labels_for_sinked_if_arm(expr : TExpr) -> TExpr {
  let pass = ModuleTransformer::new()
    .on_labelidx_evt(fn(_, depth, label) {
      let curr = rub_label_to_int(label)
      let next = if curr == depth {
        rub_label_from_int(curr + 1)
      } else if curr == depth + 1 {
        rub_label_from_int(curr - 1)
      } else {
        label
      }
      if next == label {
        unchanged()
      } else {
        change(depth, next)
      }
    })
    .on_tinstruction_evt(fn(self, depth, instr) {
      rub_walk_tinstruction_with_depth(self, depth, instr)
    })
  match pass.walk_texpr(0, expr) {
    Ok((out, _)) => out
    Err(e) => abort("remove_unused_brs sunk-if arm label retarget failed: \{e}")
  }
}

///|
fn rub_wrap_sinked_if_arm(expr : TExpr) -> TExpr {
  TExpr::new([
    TInstr::block(
      BlockType::void_(),
      rub_retarget_labels_for_sinked_if_arm(expr),
    ),
  ])
}

///|
fn rub_retarget_labels_for_sinked_loop_body(expr : TExpr) -> TExpr {
  let pass = ModuleTransformer::new()
    .on_labelidx_evt(fn(_, depth, label) {
      let curr = rub_label_to_int(label)
      let next = if curr == depth {
        rub_label_from_int(curr + 1)
      } else {
        label
      }
      if next == label {
        unchanged()
      } else {
        change(depth, next)
      }
    })
    .on_tinstruction_evt(fn(self, depth, instr) {
      rub_walk_tinstruction_with_depth(self, depth, instr)
    })
  match pass.walk_texpr(0, expr) {
    Ok((out, _)) => out
    Err(e) =>
      abort("remove_unused_brs sunk-loop body label retarget failed: \{e}")
  }
}

///|
fn rub_wrap_sinked_loop_body(expr : TExpr) -> TExpr {
  TExpr::new([
    TInstr::block(
      BlockType::void_(),
      rub_retarget_labels_for_sinked_loop_body(expr),
    ),
  ])
}

///|
fn rub_redirect_simple_child_scope_branches(
  expr : TExpr,
  fallthrough_label : LabelIdx,
  trace_state? : RUBRoundTraceState? = None,
) -> (TExpr, Bool) {
  let target_base = rub_label_to_int(fallthrough_label) + 1
  let rewrite_state : RUBChildScopeBranchRewriteState = {
    remaining_budget: Ref::new(
      RUB_JUMP_THREAD_BR_CHILD_SCOPE_REWRITE_VISIT_BUDGET,
    ),
    visits_until_guard: Ref::new(
      RUB_JUMP_THREAD_BR_CHILD_SCOPE_REWRITE_GUARD_INTERVAL,
    ),
    start_ms: sl_trace_now_ms(),
    trace_state,
    no_progress_phase: "helper=jump_thread_br:rewrite_body",
  }
  let pass = ModuleTransformer::new().on_tinstruction_evt(fn(
    self,
    depth,
    instr,
  ) {
    if !rub_take_child_scope_branch_rewrite_step(rewrite_state) {
      return error(RUB_JUMP_THREAD_BR_CHILD_SCOPE_REWRITE_ABORTED)
    }
    let walked = match self.walk_tinstruction_default(depth, instr) {
      Ok((updated, _)) => updated
      Err(e) => return error(e)
    }
    match walked.kind {
      TInstrKind::TBr(label, []) =>
        if rub_label_to_int(label) == depth {
          change(depth, TInstr::br(rub_label_from_int(depth + target_base), []))
        } else {
          unchanged()
        }
      TInstrKind::TBrIf(label, cond, []) =>
        if rub_label_to_int(label) == depth {
          change(
            depth,
            TInstr::br_if(rub_label_from_int(depth + target_base), cond, []),
          )
        } else {
          unchanged()
        }
      _ => if walked == instr { unchanged() } else { change(depth, walked) }
    }
  })
  match pass.walk_texpr(0, expr) {
    Ok((out, _)) => (out, true)
    Err(e) =>
      if e == RUB_JUMP_THREAD_BR_CHILD_SCOPE_REWRITE_ABORTED {
        let visits = RUB_JUMP_THREAD_BR_CHILD_SCOPE_REWRITE_VISIT_BUDGET -
          rewrite_state.remaining_budget.val
        rub_trace_log_helper_event(
          trace_state,
          "jump_thread_br",
          "rewrite_abort",
          "body_instrs=\{expr.instrs.length()} visits=\{visits}",
        )
        (expr, false)
      } else {
        abort("remove_unused_brs child jump-thread failed: \{e}")
      }
  }
}

///|
fn rub_redirect_simple_child_scope_branches_with_branch_pair_with_budget(
  expr : TExpr,
  target_label : LabelIdx,
  cond : TInstr,
  default_label : LabelIdx,
  visit_budget : Int,
  trace_state? : RUBRoundTraceState? = None,
) -> (TExpr, Bool) {
  if visit_budget <= 0 {
    rub_trace_log_helper_event(
      trace_state,
      "jump_thread_br_if",
      "rewrite_abort",
      "body_instrs=\{expr.instrs.length()} visits=0",
    )
    return (expr, false)
  }
  let target_base = rub_label_to_int(target_label) + 1
  let default_base = rub_label_to_int(default_label) + 1
  let rewrite_state : RUBChildScopeBranchRewriteState = {
    remaining_budget: Ref::new(visit_budget),
    visits_until_guard: Ref::new(
      RUB_JUMP_THREAD_BR_CHILD_SCOPE_REWRITE_GUARD_INTERVAL,
    ),
    start_ms: sl_trace_now_ms(),
    trace_state,
    no_progress_phase: "helper=jump_thread_br_if:rewrite_body",
  }
  let pass = ModuleTransformer::new().on_tinstruction_evt(fn(
    self,
    depth,
    instr,
  ) {
    if !rub_take_child_scope_branch_rewrite_step(rewrite_state) {
      return error(RUB_JUMP_THREAD_BR_CHILD_SCOPE_REWRITE_ABORTED)
    }
    let walked = match self.walk_tinstruction_default(depth, instr) {
      Ok((updated, _)) => updated
      Err(e) => return error(e)
    }
    match walked.kind {
      TInstrKind::TBr(label, []) =>
        if rub_label_to_int(label) == depth {
          change(
            depth,
            TInstr::if_(
              BlockType::void_(),
              cond,
              TExpr::new([
                TInstr::br(rub_label_from_int(depth + target_base + 1), []),
              ]),
              Some(
                TExpr::new([
                  TInstr::br(rub_label_from_int(depth + default_base + 1), []),
                ]),
              ),
            ),
          )
        } else {
          unchanged()
        }
      TInstrKind::TBrIf(label, inner_cond, []) =>
        if rub_label_to_int(label) == depth {
          change(
            depth,
            TInstr::if_(
              BlockType::void_(),
              inner_cond,
              TExpr::new([
                TInstr::if_(
                  BlockType::void_(),
                  cond,
                  TExpr::new([
                    TInstr::br(rub_label_from_int(depth + target_base + 2), []),
                  ]),
                  Some(
                    TExpr::new([
                      TInstr::br(rub_label_from_int(depth + default_base + 2), []),
                    ]),
                  ),
                ),
              ]),
              None,
            ),
          )
        } else {
          unchanged()
        }
      _ => if walked == instr { unchanged() } else { change(depth, walked) }
    }
  })
  match pass.walk_texpr(0, expr) {
    Ok((out, _)) => (out, true)
    Err(e) =>
      if e == RUB_JUMP_THREAD_BR_CHILD_SCOPE_REWRITE_ABORTED {
        let visits = visit_budget - rewrite_state.remaining_budget.val
        rub_trace_log_helper_event(
          trace_state,
          "jump_thread_br_if",
          "rewrite_abort",
          "body_instrs=\{expr.instrs.length()} visits=\{visits}",
        )
        (expr, false)
      } else {
        abort("remove_unused_brs child jump-thread failed: \{e}")
      }
  }
}

///|
fn rub_redirect_simple_child_scope_branches_to_unreachable_with_budget(
  expr : TExpr,
  visit_budget : Int,
  trace_state? : RUBRoundTraceState? = None,
) -> (TExpr, Bool) {
  if visit_budget <= 0 {
    rub_trace_log_helper_event(
      trace_state,
      "jump_thread_unreachable",
      "rewrite_abort",
      "body_instrs=\{expr.instrs.length()} visits=0",
    )
    return (expr, false)
  }
  let rewrite_state : RUBChildScopeBranchRewriteState = {
    remaining_budget: Ref::new(visit_budget),
    visits_until_guard: Ref::new(
      RUB_JUMP_THREAD_BR_CHILD_SCOPE_REWRITE_GUARD_INTERVAL,
    ),
    start_ms: sl_trace_now_ms(),
    trace_state,
    no_progress_phase: "helper=jump_thread_unreachable:rewrite_body",
  }
  let pass = ModuleTransformer::new().on_tinstruction_evt(fn(
    self,
    depth,
    instr,
  ) {
    if !rub_take_child_scope_branch_rewrite_step(rewrite_state) {
      return error(RUB_JUMP_THREAD_BR_CHILD_SCOPE_REWRITE_ABORTED)
    }
    let walked = match self.walk_tinstruction_default(depth, instr) {
      Ok((updated, _)) => updated
      Err(e) => return error(e)
    }
    match walked.kind {
      TInstrKind::TBr(label, []) =>
        if rub_label_to_int(label) == depth {
          change(depth, TInstr::unreachable_())
        } else {
          unchanged()
        }
      TInstrKind::TBrIf(label, cond, []) =>
        if rub_label_to_int(label) == depth {
          change(
            depth,
            TInstr::if_(
              BlockType::void_(),
              cond,
              TExpr::new([TInstr::unreachable_()]),
              None,
            ),
          )
        } else {
          unchanged()
        }
      _ => if walked == instr { unchanged() } else { change(depth, walked) }
    }
  })
  match pass.walk_texpr(0, expr) {
    Ok((out, _)) => (out, true)
    Err(e) =>
      if e == RUB_JUMP_THREAD_BR_CHILD_SCOPE_REWRITE_ABORTED {
        let visits = visit_budget - rewrite_state.remaining_budget.val
        rub_trace_log_helper_event(
          trace_state,
          "jump_thread_unreachable",
          "rewrite_abort",
          "body_instrs=\{expr.instrs.length()} visits=\{visits}",
        )
        (expr, false)
      } else {
        abort("remove_unused_brs child trap-thread failed: \{e}")
      }
  }
}

///|
fn rub_redirect_simple_child_scope_branches_to_return_with_budget(
  expr : TExpr,
  visit_budget : Int,
  trace_state? : RUBRoundTraceState? = None,
) -> (TExpr, Bool) {
  if visit_budget <= 0 {
    rub_trace_log_helper_event(
      trace_state,
      "jump_thread_return",
      "rewrite_abort",
      "body_instrs=\{expr.instrs.length()} visits=0",
    )
    return (expr, false)
  }
  let rewrite_state : RUBChildScopeBranchRewriteState = {
    remaining_budget: Ref::new(visit_budget),
    visits_until_guard: Ref::new(
      RUB_JUMP_THREAD_BR_CHILD_SCOPE_REWRITE_GUARD_INTERVAL,
    ),
    start_ms: sl_trace_now_ms(),
    trace_state,
    no_progress_phase: "helper=jump_thread_return:rewrite_body",
  }
  let pass = ModuleTransformer::new().on_tinstruction_evt(fn(
    self,
    depth,
    instr,
  ) {
    if !rub_take_child_scope_branch_rewrite_step(rewrite_state) {
      return error(RUB_JUMP_THREAD_BR_CHILD_SCOPE_REWRITE_ABORTED)
    }
    let walked = match self.walk_tinstruction_default(depth, instr) {
      Ok((updated, _)) => updated
      Err(e) => return error(e)
    }
    match walked.kind {
      TInstrKind::TBr(label, []) =>
        if rub_label_to_int(label) == depth {
          change(depth, TInstr::return_([]))
        } else {
          unchanged()
        }
      TInstrKind::TBrIf(label, cond, []) =>
        if rub_label_to_int(label) == depth {
          change(
            depth,
            TInstr::if_(
              BlockType::void_(),
              cond,
              TExpr::new([TInstr::return_([])]),
              None,
            ),
          )
        } else {
          unchanged()
        }
      _ => if walked == instr { unchanged() } else { change(depth, walked) }
    }
  })
  match pass.walk_texpr(0, expr) {
    Ok((out, _)) => (out, true)
    Err(e) =>
      if e == RUB_JUMP_THREAD_BR_CHILD_SCOPE_REWRITE_ABORTED {
        let visits = visit_budget - rewrite_state.remaining_budget.val
        rub_trace_log_helper_event(
          trace_state,
          "jump_thread_return",
          "rewrite_abort",
          "body_instrs=\{expr.instrs.length()} visits=\{visits}",
        )
        (expr, false)
      } else {
        abort("remove_unused_brs child return-thread failed: \{e}")
      }
  }
}

///|
fn rub_zero_i32() -> TInstr {
  TInstr::i32_const(I32(0))
}

///|
fn rub_one_i32() -> TInstr {
  TInstr::i32_const(I32(1))
}

///|
fn rub_is_const_i32(instr : TInstr) -> Int? {
  match instr.kind {
    TInstrKind::TI32Const(I32(v)) => Some(v)
    _ => None
  }
}

///|
fn rub_has_side_effects(instr : TInstr) -> Bool {
  lcs_collect_effects(instr).has_unremovable_side_effects()
}

///|
fn rub_is_single_tinstr(expr : TExpr) -> TInstr? {
  match expr.instrs {
    [single] => Some(single)
    _ => None
  }
}

///|
fn rub_single_non_nop_tinstr(expr : TExpr) -> TInstr? {
  let mut single : TInstr? = None
  for instr in expr.instrs {
    match instr.kind {
      TInstrKind::TNop => ()
      _ =>
        match single {
          None => single = Some(instr)
          Some(_) => return None
        }
    }
  }
  single
}

///|
fn rub_instr_has_branch(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TBr(_, _)
    | TInstrKind::TBrIf(_, _, _)
    | TInstrKind::TBrTable(_, _, _, _)
    | TInstrKind::TBrOnNull(_, _, _)
    | TInstrKind::TBrOnNonNull(_, _, _)
    | TInstrKind::TBrOnCast(_, _, _, _, _, _)
    | TInstrKind::TBrOnCastFail(_, _, _, _, _, _)
    | TInstrKind::TReturn(_)
    | TInstrKind::TReturnCall(_, _)
    | TInstrKind::TReturnCallIndirect(_, _, _, _)
    | TInstrKind::TReturnCallRef(_, _, _)
    | TInstrKind::TThrow(_, _)
    | TInstrKind::TThrowRef(_) => true
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) => rub_texpr_has_branch(body)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      if rub_instr_has_branch(cond) || rub_texpr_has_branch(then_body) {
        return true
      }
      match else_body {
        Some(other) => rub_texpr_has_branch(other)
        None => false
      }
    }
    _ => {
      for child in eval_children(instr) {
        if rub_instr_has_branch(child) {
          return true
        }
      }
      false
    }
  }
}

///|
fn rub_texpr_has_branch(expr : TExpr) -> Bool {
  for instr in expr.instrs {
    if rub_instr_has_branch(instr) {
      return true
    }
  }
  false
}

///|
fn rub_texpr_is_reachable_and_stack_neutral(expr : TExpr) -> Bool {
  match rub_stack_sig_list(expr.instrs) {
    Some(sig) => sig.reachable && sig.required == sig.produced
    None => false
  }
}

///|
const RUB_SINGLE_CHILD_SCOPE_BR_IF_SCAN_ABORTED_COUNT : Int = -2

///|
fn rub_instr_has_branch_bounded(
  instr : TInstr,
  scan_state? : RUBChildScopeBranchScanState? = None,
) -> RUBChildScopeBranchScanResult {
  match scan_state {
    Some(scan_state) =>
      if !rub_take_child_scope_branch_scan_step(scan_state) {
        return ScanAborted
      }
    None => ()
  }
  match instr.kind {
    TInstrKind::TBr(_, _)
    | TInstrKind::TBrIf(_, _, _)
    | TInstrKind::TBrTable(_, _, _, _)
    | TInstrKind::TBrOnNull(_, _, _)
    | TInstrKind::TBrOnNonNull(_, _, _)
    | TInstrKind::TBrOnCast(_, _, _, _, _, _)
    | TInstrKind::TBrOnCastFail(_, _, _, _, _, _)
    | TInstrKind::TReturn(_)
    | TInstrKind::TReturnCall(_, _)
    | TInstrKind::TReturnCallIndirect(_, _, _, _)
    | TInstrKind::TReturnCallRef(_, _, _)
    | TInstrKind::TThrow(_, _)
    | TInstrKind::TThrowRef(_) => ScanFound
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) =>
      rub_texpr_has_branch_bounded(body, scan_state~)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      let cond_result = rub_instr_has_branch_bounded(cond, scan_state~)
      match cond_result {
        ScanFound | ScanAborted => return cond_result
        ScanNotFound => ()
      }
      let then_result = rub_texpr_has_branch_bounded(then_body, scan_state~)
      match then_result {
        ScanFound | ScanAborted => return then_result
        ScanNotFound => ()
      }
      match else_body {
        Some(other) => rub_texpr_has_branch_bounded(other, scan_state~)
        None => ScanNotFound
      }
    }
    _ => {
      for child in eval_children(instr) {
        match rub_instr_has_branch_bounded(child, scan_state~) {
          ScanFound => return ScanFound
          ScanAborted => return ScanAborted
          ScanNotFound => ()
        }
      }
      ScanNotFound
    }
  }
}

///|
fn rub_texpr_has_branch_bounded(
  expr : TExpr,
  scan_state? : RUBChildScopeBranchScanState? = None,
) -> RUBChildScopeBranchScanResult {
  for instr in expr.instrs {
    match rub_instr_has_branch_bounded(instr, scan_state~) {
      ScanFound => return ScanFound
      ScanAborted => return ScanAborted
      ScanNotFound => ()
    }
  }
  ScanNotFound
}

///|
fn rub_merge_single_child_scope_br_if_count(a : Int, b : Int) -> Int {
  if a == RUB_SINGLE_CHILD_SCOPE_BR_IF_SCAN_ABORTED_COUNT ||
    b == RUB_SINGLE_CHILD_SCOPE_BR_IF_SCAN_ABORTED_COUNT {
    return RUB_SINGLE_CHILD_SCOPE_BR_IF_SCAN_ABORTED_COUNT
  }
  if a < 0 || b < 0 {
    -1
  } else {
    let total = a + b
    if total > 1 {
      -1
    } else {
      total
    }
  }
}

///|
fn rub_count_single_child_scope_br_if_instr_bounded(
  instr : TInstr,
  depth : Int,
  scan_state? : RUBChildScopeBranchScanState? = None,
) -> Int {
  match scan_state {
    Some(scan_state) =>
      if !rub_take_child_scope_branch_scan_step(scan_state) {
        return RUB_SINGLE_CHILD_SCOPE_BR_IF_SCAN_ABORTED_COUNT
      }
    None => ()
  }
  match instr.kind {
    TInstrKind::TBrIf(label, cond, []) =>
      if rub_label_to_int(label) == depth {
        match rub_instr_has_branch_bounded(cond, scan_state~) {
          ScanFound => -1
          ScanNotFound => 1
          ScanAborted => RUB_SINGLE_CHILD_SCOPE_BR_IF_SCAN_ABORTED_COUNT
        }
      } else {
        -1
      }
    TInstrKind::TBr(_, _)
    | TInstrKind::TBrIf(_, _, _)
    | TInstrKind::TBrTable(_, _, _, _)
    | TInstrKind::TBrOnNull(_, _, _)
    | TInstrKind::TBrOnNonNull(_, _, _)
    | TInstrKind::TBrOnCast(_, _, _, _, _, _)
    | TInstrKind::TBrOnCastFail(_, _, _, _, _, _)
    | TInstrKind::TReturn(_)
    | TInstrKind::TReturnCall(_, _)
    | TInstrKind::TReturnCallIndirect(_, _, _, _)
    | TInstrKind::TReturnCallRef(_, _, _)
    | TInstrKind::TThrow(_, _)
    | TInstrKind::TThrowRef(_) => -1
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) =>
      rub_count_single_child_scope_br_if_texpr_bounded(
        body,
        depth + 1,
        scan_state~,
      )
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      let cond_count = rub_count_single_child_scope_br_if_instr_bounded(
        cond,
        depth,
        scan_state~,
      )
      let then_count = rub_count_single_child_scope_br_if_texpr_bounded(
        then_body,
        depth + 1,
        scan_state~,
      )
      let else_count = match else_body {
        Some(other) =>
          rub_count_single_child_scope_br_if_texpr_bounded(
            other,
            depth + 1,
            scan_state~,
          )
        None => 0
      }
      rub_merge_single_child_scope_br_if_count(
        rub_merge_single_child_scope_br_if_count(cond_count, then_count),
        else_count,
      )
    }
    _ => {
      let mut total = 0
      for child in eval_children(instr) {
        total = rub_merge_single_child_scope_br_if_count(
          total,
          rub_count_single_child_scope_br_if_instr_bounded(
            child,
            depth,
            scan_state~,
          ),
        )
        if total < 0 {
          return total
        }
      }
      total
    }
  }
}

///|
fn rub_count_single_child_scope_br_if_texpr_bounded(
  expr : TExpr,
  depth : Int,
  scan_state? : RUBChildScopeBranchScanState? = None,
) -> Int {
  let mut total = 0
  for instr in expr.instrs {
    total = rub_merge_single_child_scope_br_if_count(
      total,
      rub_count_single_child_scope_br_if_instr_bounded(
        instr,
        depth,
        scan_state~,
      ),
    )
    if total < 0 {
      return total
    }
  }
  total
}

///|
fn rub_has_single_top_level_child_scope_br_if_with_budget(
  expr : TExpr,
  visit_budget : Int,
  trace_state? : RUBRoundTraceState? = None,
) -> RUBChildScopeBranchScanResult {
  if visit_budget <= 0 {
    return ScanAborted
  }
  let scan_state : RUBChildScopeBranchScanState = {
    remaining_budget: Ref::new(visit_budget),
    visits_until_guard: Ref::new(
      RUB_JUMP_THREAD_BR_CHILD_SCOPE_SCAN_GUARD_INTERVAL,
    ),
    start_ms: sl_trace_now_ms(),
    trace_state,
    no_progress_phase: "helper=jump_thread_br_if:scan_body",
  }
  let scan_count = rub_count_single_child_scope_br_if_texpr_bounded(
    expr,
    0,
    scan_state=Some(scan_state),
  )
  if scan_count == RUB_SINGLE_CHILD_SCOPE_BR_IF_SCAN_ABORTED_COUNT {
    ScanAborted
  } else if scan_count == 1 {
    ScanFound
  } else {
    ScanNotFound
  }
}

///|
fn rub_has_top_level_child_scope_branch_instr(
  instr : TInstr,
  depth : Int,
) -> Bool {
  rub_has_top_level_child_scope_branch_instr_bounded(instr, depth) is ScanFound
}

///|
fn rub_has_top_level_child_scope_branch_texpr(
  expr : TExpr,
  depth : Int,
) -> Bool {
  for instr in expr.instrs {
    if rub_has_top_level_child_scope_branch_instr(instr, depth) {
      return true
    }
  }
  false
}

///|
fn rub_take_child_scope_branch_scan_step(
  scan_state : RUBChildScopeBranchScanState,
) -> Bool {
  if scan_state.remaining_budget.val <= 0 {
    return false
  }
  scan_state.remaining_budget.val -= 1
  let next_visits_until_guard = scan_state.visits_until_guard.val - 1
  if next_visits_until_guard > 0 {
    scan_state.visits_until_guard.val = next_visits_until_guard
    return true
  }
  scan_state.visits_until_guard.val = RUB_JUMP_THREAD_BR_CHILD_SCOPE_SCAN_GUARD_INTERVAL
  if sl_trace_elapsed_ms(scan_state.start_ms) >=
    RUB_JUMP_THREAD_BR_CHILD_SCOPE_SCAN_TIMEOUT_MS {
    return false
  }
  match
    rub_trace_check_no_progress(
      scan_state.trace_state,
      scan_state.no_progress_phase,
    ) {
    Ok(_) => true
    Err(_) => false
  }
}

///|
fn rub_take_child_scope_branch_rewrite_step(
  rewrite_state : RUBChildScopeBranchRewriteState,
) -> Bool {
  if rewrite_state.remaining_budget.val <= 0 {
    return false
  }
  rewrite_state.remaining_budget.val -= 1
  let next_visits_until_guard = rewrite_state.visits_until_guard.val - 1
  if next_visits_until_guard > 0 {
    rewrite_state.visits_until_guard.val = next_visits_until_guard
    return true
  }
  rewrite_state.visits_until_guard.val = RUB_JUMP_THREAD_BR_CHILD_SCOPE_REWRITE_GUARD_INTERVAL
  if sl_trace_elapsed_ms(rewrite_state.start_ms) >=
    RUB_JUMP_THREAD_BR_CHILD_SCOPE_REWRITE_TIMEOUT_MS {
    return false
  }
  match
    rub_trace_check_no_progress(
      rewrite_state.trace_state,
      rewrite_state.no_progress_phase,
    ) {
    Ok(_) => true
    Err(_) => false
  }
}

///|
fn rub_has_top_level_child_scope_branch_instr_bounded(
  instr : TInstr,
  depth : Int,
  scan_state? : RUBChildScopeBranchScanState? = None,
) -> RUBChildScopeBranchScanResult {
  match scan_state {
    Some(scan_state) =>
      if !rub_take_child_scope_branch_scan_step(scan_state) {
        return ScanAborted
      }
    None => ()
  }
  match instr.kind {
    TInstrKind::TBr(label, values) =>
      if values.length() == 0 && rub_label_to_int(label) == depth {
        ScanFound
      } else {
        ScanNotFound
      }
    TInstrKind::TBrIf(label, _, values) =>
      if values.length() == 0 && rub_label_to_int(label) == depth {
        ScanFound
      } else {
        ScanNotFound
      }
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) =>
      rub_has_top_level_child_scope_branch_texpr_bounded(
        body,
        depth + 1,
        scan_state~,
      )
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      let cond_result = rub_has_top_level_child_scope_branch_instr_bounded(
        cond,
        depth,
        scan_state~,
      )
      match cond_result {
        ScanFound | ScanAborted => return cond_result
        ScanNotFound => ()
      }
      let then_result = rub_has_top_level_child_scope_branch_texpr_bounded(
        then_body,
        depth + 1,
        scan_state~,
      )
      match then_result {
        ScanFound | ScanAborted => return then_result
        ScanNotFound => ()
      }
      match else_body {
        Some(other) =>
          rub_has_top_level_child_scope_branch_texpr_bounded(
            other,
            depth + 1,
            scan_state~,
          )
        None => ScanNotFound
      }
    }
    _ => {
      for child in eval_children(instr) {
        match
          rub_has_top_level_child_scope_branch_instr_bounded(
            child,
            depth,
            scan_state~,
          ) {
          ScanFound => return ScanFound
          ScanAborted => return ScanAborted
          ScanNotFound => ()
        }
      }
      ScanNotFound
    }
  }
}

///|
fn rub_has_top_level_child_scope_branch_texpr_bounded(
  expr : TExpr,
  depth : Int,
  scan_state? : RUBChildScopeBranchScanState? = None,
) -> RUBChildScopeBranchScanResult {
  for instr in expr.instrs {
    match
      rub_has_top_level_child_scope_branch_instr_bounded(
        instr,
        depth,
        scan_state~,
      ) {
      ScanFound => return ScanFound
      ScanAborted => return ScanAborted
      ScanNotFound => ()
    }
  }
  ScanNotFound
}

///|
fn rub_child_scope_branch_scan_result_name(
  result : RUBChildScopeBranchScanResult,
) -> String {
  match result {
    ScanFound => "found"
    ScanNotFound => "not_found"
    ScanAborted => "aborted"
  }
}

///|
fn rub_has_top_level_child_scope_branch_with_budget(
  expr : TExpr,
  visit_budget : Int,
  trace_state? : RUBRoundTraceState? = None,
) -> RUBChildScopeBranchScanResult {
  if visit_budget <= 0 {
    return ScanAborted
  }
  let scan_state : RUBChildScopeBranchScanState = {
    remaining_budget: Ref::new(visit_budget),
    visits_until_guard: Ref::new(
      RUB_JUMP_THREAD_BR_CHILD_SCOPE_SCAN_GUARD_INTERVAL,
    ),
    start_ms: sl_trace_now_ms(),
    trace_state,
    no_progress_phase: "helper=jump_thread_br:scan_body",
  }
  rub_has_top_level_child_scope_branch_texpr_bounded(
    expr,
    0,
    scan_state=Some(scan_state),
  )
}

///|
fn rub_has_top_level_child_scope_branch(expr : TExpr) -> Bool {
  rub_has_top_level_child_scope_branch_texpr(expr, 0)
}

///|
fn rub_if_arm_crosses_removed_scope(expr : TExpr) -> Bool {
  match rub_rebase_labels_in_texpr_from_depth_result(expr, 1, -1) {
    Ok(_) => false
    Err(e) =>
      if e == RUB_LABEL_REBASE_CROSSES_REMOVED_SCOPE {
        true
      } else {
        abort(
          "unexpected remove_unused_brs if-arm crossing check failure: \{e}",
        )
      }
  }
}

///|
fn rub_if_arm_is_single_simple_branch(expr : TExpr) -> Bool {
  match rub_single_non_nop_tinstr(expr) {
    Some(instr) =>
      match instr.kind {
        TInstrKind::TBr(_, _)
        | TInstrKind::TBrIf(_, _, _)
        | TInstrKind::TBrTable(_, _, _, _) => true
        _ => false
      }
    None => false
  }
}

///|
fn rub_instr_cost(instr : TInstr) -> Int {
  match instr.kind {
    TInstrKind::TI32Const(_)
    | TInstrKind::TI64Const(_)
    | TInstrKind::TF32Const(_)
    | TInstrKind::TF64Const(_)
    | TInstrKind::TRefNull(_)
    | TInstrKind::TRefFunc(_)
    | TInstrKind::TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | TInstrKind::TLocalGet(_)
    | TInstrKind::TNop => 0
    TInstrKind::TThrow(_, _) | TInstrKind::TThrowRef(_) =>
      RUB_TOO_COSTLY_TO_RUN_UNCONDITIONALLY
    TInstrKind::TRefCast(_, _, _) =>
      RUB_TOO_COSTLY_TO_RUN_UNCONDITIONALLY / 2 + 1
    _ => {
      let mut total = 1
      for child in eval_children(instr) {
        total += rub_instr_cost(child)
      }
      total
    }
  }
}

///|
fn rub_too_costly_to_run_unconditionally(
  options : OptimizeOptions,
  cost : Int,
) -> Bool {
  if options.shrink_level == 0 {
    cost > RUB_TOO_COSTLY_TO_RUN_UNCONDITIONALLY / 2
  } else if options.shrink_level == 1 {
    cost >= RUB_TOO_COSTLY_TO_RUN_UNCONDITIONALLY
  } else {
    false
  }
}

///|
fn rub_too_costly_expr(options : OptimizeOptions, instr : TInstr) -> Bool {
  if options.shrink_level >= 2 {
    return false
  }
  rub_too_costly_to_run_unconditionally(options, rub_instr_cost(instr))
}

///|
fn rub_too_costly_pair(
  options : OptimizeOptions,
  one : TInstr,
  two : TInstr,
) -> Bool {
  if options.shrink_level >= 2 {
    return false
  }
  let cost = Int::max(rub_instr_cost(one), rub_instr_cost(two))
  rub_too_costly_to_run_unconditionally(options, cost)
}

///|
fn rub_instr_list_effects(instrs : Array[TInstr]) -> LCSEffects {
  lcs_collect_effects(TInstr::block(BlockType::void_(), TExpr::new(instrs)))
}

///|
fn rub_values_cost(instrs : Array[TInstr]) -> Int {
  let mut total = 0
  for instr in instrs {
    total += rub_instr_cost(instr)
  }
  total
}

///|
fn rub_can_reorder_switch_condition_and_values(
  cond : TInstr,
  values : Array[TInstr],
) -> Bool {
  if values.length() == 0 {
    return true
  }
  let cond_effects = lcs_collect_effects(cond)
  let value_effects = rub_instr_list_effects(values)
  !cond_effects.invalidates(value_effects) &&
  !value_effects.invalidates(cond_effects)
}

///|
fn rub_branch_values_are_hoistable(
  if_condition : TInstr,
  values : Array[TInstr],
  options : OptimizeOptions,
) -> Bool {
  if values.length() == 0 {
    return true
  }
  let value_effects = rub_instr_list_effects(values)
  if value_effects.has_unremovable_side_effects() {
    return false
  }
  if lcs_collect_effects(if_condition).invalidates(value_effects) {
    return false
  }
  !rub_too_costly_to_run_unconditionally(options, rub_values_cost(values))
}

///|
fn rub_can_turn_if_into_br_if(
  if_condition : TInstr,
  br_values : Array[TInstr],
  options : OptimizeOptions,
) -> Bool {
  if is_unreachable_instr(if_condition) {
    return false
  }
  rub_branch_values_are_hoistable(if_condition, br_values, options)
}

///|
fn rub_fold_condition_to_bool(instr : TInstr) -> Bool? {
  match rub_is_const_i32(instr) {
    Some(v) => Some(v != 0)
    None =>
      match instr.kind {
        TInstrKind::TUnary(I32EqzOp, inner) =>
          match rub_is_const_i32(inner) {
            Some(v) => Some(v == 0)
            None => None
          }
        _ => None
      }
  }
}

///|
fn rub_texpr_is_unreachable(expr : TExpr) -> Bool {
  expr.instrs.length() > 0 &&
  is_unreachable_instr(expr.instrs[expr.instrs.length() - 1])
}

///|
fn rub_rebased_instr_suffix_expr(instrs : Array[TInstr], start : Int) -> TExpr {
  let next : Array[TInstr] = []
  let mut i = start
  while i < instrs.length() {
    next.push(rub_rebase_labels_in_tinstruction(instrs[i], 1))
    i += 1
  }
  TExpr::new(next)
}

///|
fn rub_append_rebased_instr_suffix(
  expr : TExpr,
  instrs : Array[TInstr],
  start : Int,
) -> TExpr {
  let next = expr.instrs.copy()
  let mut i = start
  while i < instrs.length() {
    next.push(rub_rebase_labels_in_tinstruction(instrs[i], 1))
    i += 1
  }
  TExpr::new(next)
}

///|
fn rub_loop_body_sink_has_safe_terminal_flow(expr : TExpr) -> Bool {
  rub_terminal_flow_of_texpr(expr) == NoFlow
}

///|
fn rub_default_only_switch(default_ : LabelIdx, cond : TInstr) -> TInstr {
  let next_cond = rub_rebase_labels_in_tinstruction(cond, 1)
  let next_default = match rub_shift_label_at_depth(default_, 0, 1) {
    Ok(next_default) => next_default
    Err(e) => abort("remove_unused_brs default-only switch rebase failed: \{e}")
  }
  TInstr::block(
    BlockType::void_(),
    TExpr::new([TInstr::drop(next_cond), TInstr::br(next_default, [])]),
  )
}

///|
fn rub_single_target_switch(
  target : LabelIdx,
  default_ : LabelIdx,
  cond : TInstr,
) -> TInstr {
  let next_target = match rub_shift_label_at_depth(target, 0, 1) {
    Ok(next_target) => next_target
    Err(e) =>
      abort("remove_unused_brs single-target switch rebase failed: \{e}")
  }
  let next_default = match rub_shift_label_at_depth(default_, 0, 1) {
    Ok(next_default) => next_default
    Err(e) =>
      abort("remove_unused_brs single-target switch rebase failed: \{e}")
  }
  TInstr::if_(
    BlockType::void_(),
    cond,
    TExpr::new([TInstr::br(next_default, [])]),
    Some(TExpr::new([TInstr::br(next_target, [])])),
  )
}

///|
fn rub_single_target_switch_with_values(
  default_ : LabelIdx,
  cond : TInstr,
  values : Array[TInstr],
) -> TInstr {
  let next_default = match rub_shift_label_at_depth(default_, 0, 1) {
    Ok(next_default) => next_default
    Err(e) =>
      abort(
        "remove_unused_brs single-target switch-with-values rebase failed: \{e}",
      )
  }
  let next_cond = rub_rebase_labels_in_tinstruction(cond, 1)
  let next_values : Array[TInstr] = []
  for value in values {
    next_values.push(rub_rebase_labels_in_tinstruction(value, 1))
  }
  TInstr::block(
    BlockType::void_(),
    TExpr::new([TInstr::drop(next_cond), TInstr::br(next_default, next_values)]),
  )
}

///|
fn rub_optimize_br_table(instr : TInstr) -> (TInstr, Bool) {
  match instr.kind {
    TInstrKind::TBrTable(targets, default_, cond, values) => {
      match rub_is_const_i32(cond) {
        Some(v) => {
          let chosen = if v >= 0 && v < targets.length() {
            targets[v]
          } else {
            default_
          }
          return (TInstr::br(chosen, values), true)
        }
        None => ()
      }
      let mut changed = false
      let mut targets = targets.copy()
      while targets.length() > 0 && targets[targets.length() - 1] == default_ {
        ignore(targets.pop())
        changed = true
      }
      let mut removable = 0
      while removable < targets.length() && targets[removable] == default_ {
        removable += 1
      }
      let mut cond = cond
      if removable > 0 {
        let shifted : Array[LabelIdx] = []
        for i in removable..<targets.length() {
          shifted.push(targets[i])
        }
        targets = shifted
        cond = TInstr::binary(
          BinaryOp::i32_sub(),
          cond,
          TInstr::i32_const(I32(removable)),
        )
        changed = true
      }

      let unique : Set[LabelIdx] = Set::new()
      unique.add(default_)
      for target in targets {
        unique.add(target)
      }
      if unique.length() == 1 {
        if values.length() == 0 {
          return (rub_default_only_switch(default_, cond), true)
        }
        if rub_can_reorder_switch_condition_and_values(cond, values) {
          return (
            rub_single_target_switch_with_values(default_, cond, values),
            true,
          )
        }
        return (TInstr::br_table(targets, default_, cond, values), changed)
      }

      if values.length() > 0 {
        let out = TInstr::br_table(targets, default_, cond, values)
        return (out, changed)
      }

      if targets.length() == 0 {
        return (rub_default_only_switch(default_, cond), true)
      }
      if targets.length() == 1 {
        return (rub_single_target_switch(targets[0], default_, cond), true)
      }
      (TInstr::br_table(targets, default_, cond, values), changed)
    }
    _ => (instr, false)
  }
}

///|
fn rub_optimize_if(instr : TInstr, options : OptimizeOptions) -> (TInstr, Bool) {
  match instr.kind {
    TInstrKind::TIf(bt, condition, then_body, else_body) =>
      match else_body {
        Some(_) => (instr, false)
        None =>
          match rub_is_single_tinstr(then_body) {
            Some(single_then) =>
              match rub_try_rebase_labels_in_tinstruction(single_then, -1) {
                Some({ kind: TInstrKind::TBr(label, values), .. }) =>
                  if rub_can_turn_if_into_br_if(condition, values, options) {
                    (TInstr::br_if(label, condition, values), true)
                  } else {
                    (instr, false)
                  }
                Some({ kind: TInstrKind::TBrIf(label, inner_cond, values), .. }) => {
                  if values.length() != 0 ||
                    rub_has_side_effects(inner_cond) ||
                    rub_too_costly_pair(options, inner_cond, rub_zero_i32()) {
                    return (instr, false)
                  }
                  let next_cond = TInstr::select(
                    None,
                    inner_cond,
                    condition,
                    rub_zero_i32(),
                  )
                  (TInstr::br_if(label, next_cond, []), true)
                }
                Some(
                  {
                    kind: TInstrKind::TIf(
                      child_bt,
                      child_cond,
                      child_then,
                      None
                    ),
                    ..,
                  }
                ) => {
                  if child_bt != bt {
                    return (instr, false)
                  }
                  if rub_has_side_effects(child_cond) ||
                    rub_too_costly_expr(options, child_cond) {
                    return (instr, false)
                  }
                  let next_cond = TInstr::select(
                    None,
                    child_cond,
                    condition,
                    rub_zero_i32(),
                  )
                  (TInstr::if_(bt, next_cond, child_then, None), true)
                }
                Some(_) => (instr, false)
                None => (instr, false)
              }
            None => (instr, false)
          }
      }
    _ => (instr, false)
  }
}

///|
fn rub_optimize_br_if(instr : TInstr) -> (TInstr, Bool) {
  match instr.kind {
    TInstrKind::TBrIf(label, cond, values) =>
      match rub_fold_condition_to_bool(cond) {
        Some(true) => (TInstr::br(label, values), true)
        Some(false) =>
          match values {
            [] => (TInstr::drop(cond), true)
            [single] => {
              let next_single = rub_rebase_labels_in_tinstruction(single, 1)
              let next_cond = rub_rebase_labels_in_tinstruction(cond, 1)
              (
                TInstr::block(
                  BlockType::void_(),
                  TExpr::new([
                    TInstr::drop(next_single),
                    TInstr::drop(next_cond),
                  ]),
                ),
                true,
              )
            }
            _ => (instr, false)
          }
        None => (instr, false)
      }
    _ => (instr, false)
  }
}

///|
fn rub_optimize_gc_branch(instr : TInstr) -> (TInstr, Bool) {
  match instr.kind {
    TInstrKind::TDrop({ kind: TInstrKind::TBrOnNull(label, ref_, values), .. }) =>
      if values.length() == 0 {
        match ref_.kind {
          TInstrKind::TRefNull(_) => (TInstr::br(label, []), true)
          TInstrKind::TRefFunc(_) => (TInstr::drop(ref_), true)
          _ => (instr, false)
        }
      } else {
        (instr, false)
      }
    TInstrKind::TDrop(
      { kind: TInstrKind::TBrOnNonNull(label, ref_, values), .. }
    ) =>
      if values.length() == 0 {
        match ref_.kind {
          TInstrKind::TRefNull(_) => (TInstr::drop(ref_), true)
          TInstrKind::TRefFunc(_) => (TInstr::br(label, []), true)
          _ => (instr, false)
        }
      } else {
        (instr, false)
      }
    _ => (instr, false)
  }
}

///|
priv enum RUBFlow {
  NoFlow
  BreakFlow(LabelIdx)
  ReturnFlow
} derive(Eq)

///|
fn rub_flow_through_scope(flow : RUBFlow) -> RUBFlow {
  match flow {
    BreakFlow(label) =>
      if rub_is_label_zero(label) {
        NoFlow
      } else {
        BreakFlow(rub_label_from_int(rub_label_to_int(label) - 1))
      }
    _ => flow
  }
}

///|
fn rub_merge_if_flows(then_flow : RUBFlow, else_flow : RUBFlow) -> RUBFlow {
  if then_flow == else_flow {
    then_flow
  } else {
    NoFlow
  }
}

///|
fn rub_terminal_flow_of_instr(instr : TInstr) -> RUBFlow {
  match instr.kind {
    TInstrKind::TBr(label, values) =>
      if values.length() == 0 {
        BreakFlow(label)
      } else {
        NoFlow
      }
    TInstrKind::TReturn(values) =>
      if values.length() == 0 {
        ReturnFlow
      } else {
        NoFlow
      }
    TInstrKind::TIf(_, _, then_body, Some(else_body)) => {
      let then_flow = rub_flow_through_scope(
        rub_terminal_flow_of_texpr(then_body),
      )
      let else_flow = rub_flow_through_scope(
        rub_terminal_flow_of_texpr(else_body),
      )
      rub_merge_if_flows(then_flow, else_flow)
    }
    _ => NoFlow
  }
}

///|
fn rub_terminal_flow_of_texpr(expr : TExpr) -> RUBFlow {
  if expr.instrs.length() == 0 {
    return NoFlow
  }
  rub_terminal_flow_of_instr(expr.instrs[expr.instrs.length() - 1])
}

///|
fn rub_direct_terminal_flow_of_if_arm(expr : TExpr) -> RUBFlow {
  match rub_single_non_nop_tinstr(expr) {
    Some({ kind: TInstrKind::TBr(label, values), .. }) =>
      if values.length() == 0 {
        BreakFlow(label)
      } else {
        NoFlow
      }
    Some({ kind: TInstrKind::TReturn(values), .. }) =>
      if values.length() == 0 {
        ReturnFlow
      } else {
        NoFlow
      }
    _ => NoFlow
  }
}

///|
fn rub_optimize_terminal_if_flow(
  instrs : Array[TInstr],
  in_function_body : Bool,
  zero_break_is_fallthrough : Bool,
) -> Bool {
  if instrs.length() == 0 {
    return false
  }
  let idx = instrs.length() - 1
  match instrs[idx].kind {
    TInstrKind::TIf(VoidBlockType, cond, then_body, Some(else_body)) => {
      let merged_flow = rub_merge_if_flows(
        rub_flow_through_scope(rub_direct_terminal_flow_of_if_arm(then_body)),
        rub_flow_through_scope(rub_direct_terminal_flow_of_if_arm(else_body)),
      )
      match merged_flow {
        BreakFlow(label) => {
          instrs[idx] = TInstr::drop(cond)
          if !(zero_break_is_fallthrough && rub_is_label_zero(label)) {
            instrs.push(TInstr::br(label, []))
          }
          true
        }
        ReturnFlow =>
          if in_function_body {
            instrs[idx] = TInstr::drop(cond)
            true
          } else {
            false
          }
        NoFlow => false
      }
    }
    _ => false
  }
}

///|
fn rub_remove_trailing_fallthrough_br_if(
  instrs : Array[TInstr],
  zero_break_is_fallthrough : Bool,
) -> Bool {
  if !zero_break_is_fallthrough || instrs.length() == 0 {
    return false
  }
  let last_i = instrs.length() - 1
  match instrs[last_i].kind {
    TInstrKind::TBrIf(label, cond, []) =>
      if rub_is_label_zero(label) {
        instrs[last_i] = TInstr::drop(cond)
        true
      } else {
        false
      }
    _ => false
  }
}

///|
fn rub_optimize_loop_tail_branches(
  instrs : Array[TInstr],
  zero_break_is_fallthrough : Bool,
) -> Bool {
  // Loop bodies are the only places where `br 0` is not fallthrough.
  if zero_break_is_fallthrough || instrs.length() == 0 {
    return false
  }
  if instrs.length() >= 3 {
    let last_i = instrs.length() - 1
    match (instrs[0].kind, instrs[last_i].kind) {
      (
        TInstrKind::TBrIf(first_label, first_cond, []),
        TInstrKind::TBr(last_label, []),
      ) =>
        if rub_is_label_zero(first_label) && rub_is_label_zero(last_label) {
          let mut only_nops_between = true
          let mut i = 1
          while i < last_i {
            if !(instrs[i].kind is TInstrKind::TNop) {
              only_nops_between = false
              break
            }
            i += 1
          }
          if only_nops_between {
            instrs[0] = TInstr::drop(first_cond)
            return true
          }
        }
      _ => ()
    }
  }
  if instrs.length() >= 2 {
    let last_i = instrs.length() - 1
    let mut second_last_i = last_i
    while second_last_i > 0 {
      second_last_i -= 1
      if !(instrs[second_last_i].kind is TInstrKind::TNop) {
        break
      }
    }
    if second_last_i < last_i &&
      !(instrs[second_last_i].kind is TInstrKind::TNop) {
      match (instrs[second_last_i].kind, instrs[last_i].kind) {
        (
          TInstrKind::TBrIf(exit_label, cond, []),
          TInstrKind::TBr(loop_label, []),
        ) =>
          if rub_is_label_zero(loop_label) {
            if rub_is_label_zero(exit_label) {
              instrs[second_last_i] = TInstr::drop(cond)
              return true
            }
            instrs[second_last_i] = TInstr::br_if(
              LabelIdx::new(0),
              TInstr::unary(UnaryOp::i32_eqz(), cond),
              [],
            )
            instrs[last_i] = TInstr::br(exit_label, [])
            return true
          }
        (
          TInstrKind::TIf(VoidBlockType, cond, then_body, Some(else_body)),
          TInstrKind::TBr(loop_label, []),
        ) =>
          if rub_is_label_zero(loop_label) {
            match
              (rub_is_single_tinstr(then_body), rub_is_single_tinstr(else_body)) {
              (
                Some({ kind: TInstrKind::TBr(then_label, then_values), .. }),
                Some({ kind: TInstrKind::TBr(else_label, else_values), .. }),
              ) =>
                if then_values.length() == 0 && else_values.length() == 0 {
                  let rebased_then = match
                    rub_shift_label_at_depth(then_label, 0, -1) {
                    Ok(label) => label
                    Err(_) => return false
                  }
                  let rebased_else = match
                    rub_shift_label_at_depth(else_label, 0, -1) {
                    Ok(label) => label
                    Err(_) => return false
                  }
                  if rub_is_label_zero(rebased_else) &&
                    !rub_is_label_zero(rebased_then) {
                    instrs[second_last_i] = TInstr::br_if(
                      LabelIdx::new(0),
                      TInstr::unary(UnaryOp::i32_eqz(), cond),
                      [],
                    )
                    instrs[last_i] = TInstr::br(rebased_then, [])
                    return true
                  } else if rub_is_label_zero(rebased_then) &&
                    !rub_is_label_zero(rebased_else) {
                    instrs[second_last_i] = TInstr::br_if(
                      LabelIdx::new(0),
                      cond,
                      [],
                    )
                    instrs[last_i] = TInstr::br(rebased_else, [])
                    return true
                  }
                }
              _ => ()
            }
          }
        _ => ()
      }
    }
  }

  let last_i = instrs.length() - 1
  match instrs[last_i].kind {
    TInstrKind::TBr(loop_label, []) =>
      if rub_is_label_zero(loop_label) && instrs.length() >= 3 {
        let mut i = last_i - 1
        while true {
          match instrs[i].kind {
            TInstrKind::TBrIf(label, cond, []) =>
              if !rub_is_label_zero(label) && i + 1 < instrs.length() {
                let next_then = TExpr::new([
                  TInstr::br(rub_label_from_int(rub_label_to_int(label) + 1), []),
                ])
                let next : Array[TInstr] = []
                for j in 0..<i {
                  next.push(instrs[j])
                }
                next.push(
                  TInstr::if_(
                    BlockType::void_(),
                    cond,
                    next_then,
                    Some(rub_rebased_instr_suffix_expr(instrs, i + 1)),
                  ),
                )
                instrs.clear()
                for item in next {
                  instrs.push(item)
                }
                return true
              } else {
                return false
              }
            TInstrKind::TIf(VoidBlockType, cond, then_body, else_body) =>
              if i + 1 < instrs.length() && !is_unreachable_instr(cond) {
                let next_if = match else_body {
                  None =>
                    if rub_texpr_is_unreachable(then_body) {
                      Some(
                        TInstr::if_(
                          BlockType::void_(),
                          cond,
                          then_body,
                          Some(rub_rebased_instr_suffix_expr(instrs, i + 1)),
                        ),
                      )
                    } else {
                      None
                    }
                  Some(else_body) =>
                    if rub_texpr_is_unreachable(then_body) &&
                      !rub_texpr_is_unreachable(else_body) {
                      Some(
                        TInstr::if_(
                          BlockType::void_(),
                          cond,
                          then_body,
                          Some(
                            rub_append_rebased_instr_suffix(
                              else_body,
                              instrs,
                              i + 1,
                            ),
                          ),
                        ),
                      )
                    } else if rub_texpr_is_unreachable(else_body) &&
                      !rub_texpr_is_unreachable(then_body) {
                      Some(
                        TInstr::if_(
                          BlockType::void_(),
                          cond,
                          rub_append_rebased_instr_suffix(
                            then_body,
                            instrs,
                            i + 1,
                          ),
                          Some(else_body),
                        ),
                      )
                    } else {
                      None
                    }
                }
                match next_if {
                  Some(next_if) => {
                    let next : Array[TInstr] = []
                    for j in 0..<i {
                      next.push(instrs[j])
                    }
                    next.push(next_if)
                    instrs.clear()
                    for item in next {
                      instrs.push(item)
                    }
                    return true
                  }
                  None => return false
                }
              } else {
                return false
              }
            _ => if rub_instr_has_branch(instrs[i]) { return false }
          }
          if i == 0 {
            break
          }
          i -= 1
        }
      }
    _ => ()
  }

  match instrs[last_i].kind {
    TInstrKind::TIf(VoidBlockType, cond, then_body, Some(else_body)) =>
      match (rub_is_single_tinstr(then_body), rub_is_single_tinstr(else_body)) {
        (
          Some({ kind: TInstrKind::TBr(then_label, []), .. }),
          Some({ kind: TInstrKind::TBr(else_label, []), .. }),
        ) => {
          let rebased_then = match rub_shift_label_at_depth(then_label, 0, -1) {
            Ok(label) => label
            Err(_) => return false
          }
          let rebased_else = match rub_shift_label_at_depth(else_label, 0, -1) {
            Ok(label) => label
            Err(_) => return false
          }
          if rub_is_label_zero(rebased_else) && !rub_is_label_zero(rebased_then) {
            instrs[last_i] = TInstr::br_if(
              LabelIdx::new(0),
              TInstr::unary(UnaryOp::i32_eqz(), cond),
              [],
            )
            instrs.push(TInstr::br(rebased_then, []))
            true
          } else if rub_is_label_zero(rebased_then) &&
            !rub_is_label_zero(rebased_else) {
            instrs[last_i] = TInstr::br_if(LabelIdx::new(0), cond, [])
            instrs.push(TInstr::br(rebased_else, []))
            true
          } else {
            false
          }
        }
        _ => false
      }
    _ => false
  }
}

///|
fn rub_optimize_single_if_void_block_wrapper(
  instr : TInstr,
  allow_removed_scope_sink : Bool,
) -> (TInstr, Bool) {
  match instr.kind {
    TInstrKind::TBlock(VoidBlockType, body) =>
      match rub_single_non_nop_tinstr(body) {
        Some(single) =>
          match single.kind {
            TInstrKind::TIf(VoidBlockType, cond, then_body, Some(else_body)) =>
              match rub_try_rebase_labels_in_tinstruction(single, -1) {
                Some(next_single) => (next_single, true)
                None =>
                  match rub_try_rebase_labels_in_tinstruction(cond, -1) {
                    Some(next_cond) =>
                      match
                        (
                          rub_try_rebase_labels_in_if_arm(then_body, -1),
                          rub_try_rebase_labels_in_if_arm(else_body, -1),
                        ) {
                        (None, Some(next_else)) =>
                          if rub_if_arm_crosses_removed_scope(else_body) ||
                            rub_if_arm_is_single_simple_branch(else_body) {
                            (instr, false)
                          } else {
                            (
                              TInstr::if_(
                                BlockType::void_(),
                                next_cond,
                                rub_wrap_sinked_if_arm(then_body),
                                Some(next_else),
                              ),
                              true,
                            )
                          }
                        (Some(next_then), None) =>
                          if rub_if_arm_crosses_removed_scope(then_body) ||
                            rub_if_arm_is_single_simple_branch(then_body) {
                            (instr, false)
                          } else {
                            (
                              TInstr::if_(
                                BlockType::void_(),
                                next_cond,
                                next_then,
                                Some(rub_wrap_sinked_if_arm(else_body)),
                              ),
                              true,
                            )
                          }
                        _ => (instr, false)
                      }
                    None => (instr, false)
                  }
              }
            TInstrKind::TIf(VoidBlockType, cond, then_body, None) =>
              match rub_try_rebase_labels_in_tinstruction(cond, -1) {
                Some(next_cond) =>
                  match rub_try_rebase_labels_in_if_arm(then_body, -1) {
                    None =>
                      (
                        TInstr::if_(
                          BlockType::void_(),
                          next_cond,
                          rub_wrap_sinked_if_arm(then_body),
                          None,
                        ),
                        true,
                      )
                    Some(_) => (instr, false)
                  }
                None => (instr, false)
              }
            TInstrKind::TLoop(VoidBlockType, body) =>
              match rub_try_rebase_labels_in_tinstruction(single, -1) {
                Some(next_single) => (next_single, true)
                None =>
                  if !allow_removed_scope_sink ||
                    !rub_loop_body_sink_has_safe_terminal_flow(body) {
                    (instr, false)
                  } else {
                    match rub_is_single_tinstr(body) {
                      Some({ kind: TInstrKind::TBlock(VoidBlockType, _), .. }) =>
                        (
                          TInstr::loop_(
                            BlockType::void_(),
                            rub_wrap_sinked_loop_body(body),
                          ),
                          true,
                        )
                      Some({ kind: TInstrKind::TBrIf(label, _, []), .. }) =>
                        if rub_is_label_zero(label) {
                          (instr, false)
                        } else {
                          (TInstr::loop_(BlockType::void_(), body), true)
                        }
                      Some(_) => (instr, false)
                      None =>
                        (
                          TInstr::loop_(
                            BlockType::void_(),
                            rub_wrap_sinked_loop_body(body),
                          ),
                          true,
                        )
                    }
                  }
              }
            _ => (instr, false)
          }
        None => (instr, false)
      }
    _ => (instr, false)
  }
}

///|
fn rub_optimize_jump_thread_block_wrapper(instr : TInstr) -> (TInstr, Bool) {
  match instr.kind {
    TInstrKind::TBlock(VoidBlockType, body) =>
      match rub_single_non_nop_tinstr(body) {
        Some({ kind: TInstrKind::TUnreachable, .. }) =>
          (TInstr::unreachable_(), true)
        Some({ kind: TInstrKind::TReturn([]), .. }) =>
          (TInstr::return_([]), true)
        Some({ kind: TInstrKind::TBr(label, []), .. }) =>
          if rub_is_label_zero(label) {
            (TInstr::nop(), true)
          } else {
            (
              TInstr::br(rub_label_from_int(rub_label_to_int(label) - 1), []),
              true,
            )
          }
        Some({ kind: TInstrKind::TBrIf(label, cond, []), .. }) =>
          if rub_is_label_zero(label) {
            (TInstr::drop(cond), true)
          } else {
            (
              TInstr::br_if(
                rub_label_from_int(rub_label_to_int(label) - 1),
                cond,
                [],
              ),
              true,
            )
          }
        _ => (instr, false)
      }
    _ => (instr, false)
  }
}

///|
fn rub_collect_top_level_void_block_sites(instrs : Array[TInstr]) -> Array[Int] {
  let sites : Array[Int] = []
  let mut i = 0
  while i < instrs.length() {
    match instrs[i].kind {
      TInstrKind::TBlock(VoidBlockType, _) => sites.push(i)
      _ => ()
    }
    i += 1
  }
  sites
}

///|
fn rub_optimize_jump_thread_child_block_following_br(
  instrs : Array[TInstr],
  candidate_sites : Array[Int],
  trace_state? : RUBRoundTraceState? = None,
) -> Bool {
  if instrs.length() < 2 {
    return false
  }
  rub_trace_log_helper_event(
    trace_state,
    "jump_thread_br",
    "start",
    "instrs=\{instrs.length()}",
  )
  let mut changed = false
  for i in candidate_sites {
    if i + 1 >= instrs.length() {
      continue
    }
    rub_trace_log_helper_event(
      trace_state,
      "jump_thread_br",
      "scan_site",
      "site=\{i}",
    )
    match instrs[i].kind {
      TInstrKind::TBlock(VoidBlockType, body) => {
        let mut j = i + 1
        while j < instrs.length() && instrs[j].kind is TInstrKind::TNop {
          j += 1
        }
        if j < instrs.length() {
          match instrs[j].kind {
            TInstrKind::TBr(fallthrough_label, []) => {
              rub_trace_log_helper_event(
                trace_state,
                "jump_thread_br",
                "candidate",
                "site=\{i} body_instrs=\{body.instrs.length()} fallthrough_site=\{j}",
              )
              let body_scan_start_ms = sl_trace_now_ms()
              let body_scan_result = rub_has_top_level_child_scope_branch_with_budget(
                body,
                RUB_JUMP_THREAD_BR_CHILD_SCOPE_SCAN_VISIT_BUDGET,
                trace_state~,
              )
              rub_trace_log_helper_step_done(
                trace_state,
                "jump_thread_br",
                "scan_body",
                sl_trace_elapsed_ms(body_scan_start_ms),
                "site=\{i} body_instrs=\{body.instrs.length()} result=\{rub_child_scope_branch_scan_result_name(body_scan_result)}",
              )
              match body_scan_result {
                ScanNotFound => continue
                ScanAborted => {
                  rub_trace_log_helper_event(
                    trace_state,
                    "jump_thread_br",
                    "scan_body_abort",
                    "site=\{i} body_instrs=\{body.instrs.length()}",
                  )
                  continue
                }
                ScanFound => ()
              }
              let (next_body, body_changed) = rub_redirect_simple_child_scope_branches(
                body,
                fallthrough_label,
                trace_state~,
              )
              if body_changed {
                instrs[i] = TInstr::block(BlockType::void_(), next_body)
                changed = true
              }
            }
            _ =>
              rub_trace_log_helper_event(
                trace_state,
                "jump_thread_br",
                "scan_site_skip",
                "site=\{i} reason=next_not_br next_site=\{j} kind=\{rub_instr_kind_name(instrs[j])}",
              )
          }
        } else {
          rub_trace_log_helper_event(
            trace_state,
            "jump_thread_br",
            "scan_site_skip",
            "site=\{i} reason=no_fallthrough_after_block body_instrs=\{body.instrs.length()}",
          )
        }
      }
      _ =>
        rub_trace_log_helper_event(
          trace_state,
          "jump_thread_br",
          "scan_site_skip",
          "site=\{i} reason=not_void_block kind=\{rub_instr_kind_name(instrs[i])}",
        )
    }
  }
  changed
}

///|
fn rub_optimize_jump_thread_child_block_following_br_if(
  instrs : Array[TInstr],
  candidate_sites : Array[Int],
  trace_state? : RUBRoundTraceState? = None,
) -> Bool {
  rub_optimize_jump_thread_child_block_following_br_if_with_budgets(
    instrs,
    candidate_sites,
    RUB_JUMP_THREAD_BR_CHILD_SCOPE_SCAN_VISIT_BUDGET,
    RUB_JUMP_THREAD_BR_CHILD_SCOPE_REWRITE_VISIT_BUDGET,
    trace_state~,
  )
}

///|
fn rub_optimize_jump_thread_child_block_following_br_if_with_budgets(
  instrs : Array[TInstr],
  candidate_sites : Array[Int],
  scan_visit_budget : Int,
  rewrite_visit_budget : Int,
  trace_state? : RUBRoundTraceState? = None,
) -> Bool {
  if instrs.length() < 3 {
    return false
  }
  rub_trace_log_helper_event(
    trace_state,
    "jump_thread_br_if",
    "start",
    "instrs=\{instrs.length()}",
  )
  for i in candidate_sites {
    if i + 2 >= instrs.length() {
      continue
    }
    rub_trace_log_helper_event(
      trace_state,
      "jump_thread_br_if",
      "scan_site",
      "site=\{i}",
    )
    let body = match instrs[i].kind {
      TInstrKind::TBlock(VoidBlockType, body) => body
      _ => {
        rub_trace_log_helper_event(
          trace_state,
          "jump_thread_br_if",
          "scan_site_skip",
          "site=\{i} reason=not_void_block kind=\{rub_instr_kind_name(instrs[i])}",
        )
        continue
      }
    }
    let mut j = i + 1
    while j < instrs.length() && instrs[j].kind is TInstrKind::TNop {
      j += 1
    }
    if j >= instrs.length() {
      rub_trace_log_helper_event(
        trace_state,
        "jump_thread_br_if",
        "scan_site_stop",
        "site=\{i} reason=no_branch_after_block body_instrs=\{body.instrs.length()}",
      )
      break
    }
    let (target_label, cond) = match instrs[j].kind {
      TInstrKind::TBrIf(target_label, cond, []) => (target_label, cond)
      _ => {
        rub_trace_log_helper_event(
          trace_state,
          "jump_thread_br_if",
          "scan_site_skip",
          "site=\{i} reason=next_not_br_if next_site=\{j} kind=\{rub_instr_kind_name(instrs[j])}",
        )
        continue
      }
    }
    let mut k = j + 1
    while k < instrs.length() && instrs[k].kind is TInstrKind::TNop {
      k += 1
    }
    if k >= instrs.length() {
      rub_trace_log_helper_event(
        trace_state,
        "jump_thread_br_if",
        "scan_site_skip",
        "site=\{i} reason=no_default_br branch_site=\{j} body_instrs=\{body.instrs.length()}",
      )
      continue
    }
    let default_label = match instrs[k].kind {
      TInstrKind::TBr(default_label, []) => default_label
      _ => {
        rub_trace_log_helper_event(
          trace_state,
          "jump_thread_br_if",
          "scan_site_skip",
          "site=\{i} reason=default_not_br default_site=\{k} kind=\{rub_instr_kind_name(instrs[k])}",
        )
        continue
      }
    }
    let mut tail = k + 1
    let mut only_tail_nops = true
    while tail < instrs.length() {
      if !(instrs[tail].kind is TInstrKind::TNop) {
        only_tail_nops = false
        break
      }
      tail += 1
    }
    // Keep this conservative and non-oscillatory: only thread the exact
    // two-target tail form with a branch-free condition and a single top-level
    // child-scope `br_if 0` in the child block.
    let is_two_target_tail = (
        !rub_is_label_zero(target_label) && rub_is_label_zero(default_label)
      ) ||
      (rub_is_label_zero(target_label) && !rub_is_label_zero(default_label))
    rub_trace_log_helper_event(
      trace_state,
      "jump_thread_br_if",
      "candidate",
      "site=\{i} body_instrs=\{body.instrs.length()} branch_site=\{j} default_site=\{k} tail_nops_only=\{only_tail_nops} two_target_tail=\{is_two_target_tail} cond_kind=\{rub_instr_kind_name(cond)}",
    )
    if !only_tail_nops || !is_two_target_tail {
      rub_trace_log_helper_event(
        trace_state,
        "jump_thread_br_if",
        "candidate_reject",
        "site=\{i} reason=tail_shape tail_nops_only=\{only_tail_nops} two_target_tail=\{is_two_target_tail}",
      )
      continue
    }
    let cond_scan_start_ms = sl_trace_now_ms()
    rub_trace_log_helper_event(
      trace_state,
      "jump_thread_br_if",
      "cond_has_branch:start",
      "site=\{i} cond_kind=\{rub_instr_kind_name(cond)}",
    )
    let cond_has_branch = rub_instr_has_branch(cond)
    rub_trace_log_helper_event(
      trace_state,
      "jump_thread_br_if",
      "cond_has_branch:done",
      "elapsed_ms=\{sl_trace_elapsed_ms(cond_scan_start_ms)} site=\{i} cond_kind=\{rub_instr_kind_name(cond)} result=\{cond_has_branch}",
    )
    if cond_has_branch {
      rub_trace_log_helper_event(
        trace_state,
        "jump_thread_br_if",
        "candidate_reject",
        "site=\{i} reason=cond_has_branch",
      )
      continue
    }
    let body_scan_start_ms = sl_trace_now_ms()
    let body_scan_result = rub_has_single_top_level_child_scope_br_if_with_budget(
      body,
      scan_visit_budget,
      trace_state~,
    )
    rub_trace_log_helper_event(
      trace_state,
      "jump_thread_br_if",
      "scan_body:done",
      "elapsed_ms=\{sl_trace_elapsed_ms(body_scan_start_ms)} site=\{i} body_instrs=\{body.instrs.length()} result=\{rub_child_scope_branch_scan_result_name(body_scan_result)}",
    )
    match body_scan_result {
      ScanNotFound => continue
      ScanAborted => {
        rub_trace_log_helper_event(
          trace_state,
          "jump_thread_br_if",
          "scan_body_abort",
          "site=\{i} body_instrs=\{body.instrs.length()}",
        )
        continue
      }
      ScanFound => ()
    }
    let (next_body, body_changed) = rub_redirect_simple_child_scope_branches_with_branch_pair_with_budget(
      body,
      target_label,
      cond,
      default_label,
      rewrite_visit_budget,
      trace_state~,
    )
    if body_changed {
      instrs[i] = TInstr::block(BlockType::void_(), next_body)
      rub_trace_log_helper_event(
        trace_state,
        "jump_thread_br_if",
        "rewrite",
        "site=\{i}",
      )
      return true
    }
  }
  false
}

///|
fn rub_optimize_jump_thread_child_block_following_unreachable(
  instrs : Array[TInstr],
  candidate_sites : Array[Int],
  trace_state? : RUBRoundTraceState? = None,
) -> Bool {
  rub_optimize_jump_thread_child_block_following_unreachable_with_budgets(
    instrs,
    candidate_sites,
    RUB_JUMP_THREAD_BR_CHILD_SCOPE_SCAN_VISIT_BUDGET,
    RUB_JUMP_THREAD_BR_CHILD_SCOPE_REWRITE_VISIT_BUDGET,
    trace_state~,
  )
}

///|
fn rub_optimize_jump_thread_child_block_following_unreachable_with_budgets(
  instrs : Array[TInstr],
  candidate_sites : Array[Int],
  scan_visit_budget : Int,
  rewrite_visit_budget : Int,
  trace_state? : RUBRoundTraceState? = None,
) -> Bool {
  if instrs.length() < 2 {
    return false
  }
  rub_trace_log_helper_event(
    trace_state,
    "jump_thread_unreachable",
    "start",
    "instrs=\{instrs.length()}",
  )
  let mut changed = false
  for i in candidate_sites {
    if i + 1 >= instrs.length() {
      continue
    }
    rub_trace_log_helper_event(
      trace_state,
      "jump_thread_unreachable",
      "scan_site",
      "site=\{i}",
    )
    match instrs[i].kind {
      TInstrKind::TBlock(VoidBlockType, body) => {
        let mut j = i + 1
        while j < instrs.length() && instrs[j].kind is TInstrKind::TNop {
          j += 1
        }
        if j < instrs.length() {
          match instrs[j].kind {
            TInstrKind::TUnreachable => {
              rub_trace_log_helper_event(
                trace_state,
                "jump_thread_unreachable",
                "candidate",
                "site=\{i} body_instrs=\{body.instrs.length()} unreachable_site=\{j}",
              )
              let body_scan_start_ms = sl_trace_now_ms()
              let body_scan_result = rub_has_top_level_child_scope_branch_with_budget(
                body,
                scan_visit_budget,
                trace_state~,
              )
              rub_trace_log_helper_step_done(
                trace_state,
                "jump_thread_unreachable",
                "scan_body",
                sl_trace_elapsed_ms(body_scan_start_ms),
                "site=\{i} body_instrs=\{body.instrs.length()} result=\{rub_child_scope_branch_scan_result_name(body_scan_result)}",
              )
              match body_scan_result {
                ScanNotFound => {
                  rub_trace_log_helper_event(
                    trace_state,
                    "jump_thread_unreachable",
                    "candidate_reject",
                    "site=\{i} reason=no_child_scope_branch",
                  )
                  continue
                }
                ScanAborted => {
                  rub_trace_log_helper_event(
                    trace_state,
                    "jump_thread_unreachable",
                    "scan_body_abort",
                    "site=\{i} body_instrs=\{body.instrs.length()}",
                  )
                  continue
                }
                ScanFound => ()
              }
              let (next_body, body_changed) = rub_redirect_simple_child_scope_branches_to_unreachable_with_budget(
                body,
                rewrite_visit_budget,
                trace_state~,
              )
              if !body_changed {
                rub_trace_log_helper_event(
                  trace_state,
                  "jump_thread_unreachable",
                  "candidate_reject",
                  "site=\{i} reason=rewrite_no_change",
                )
              } else {
                instrs[i] = TInstr::block(BlockType::void_(), next_body)
                changed = true
              }
            }
            _ =>
              rub_trace_log_helper_event(
                trace_state,
                "jump_thread_unreachable",
                "scan_site_skip",
                "site=\{i} reason=next_not_unreachable next_site=\{j} kind=\{rub_instr_kind_name(instrs[j])}",
              )
          }
        } else {
          rub_trace_log_helper_event(
            trace_state,
            "jump_thread_unreachable",
            "scan_site_skip",
            "site=\{i} reason=no_next_after_block body_instrs=\{body.instrs.length()}",
          )
        }
      }
      _ =>
        rub_trace_log_helper_event(
          trace_state,
          "jump_thread_unreachable",
          "scan_site_skip",
          "site=\{i} reason=not_void_block kind=\{rub_instr_kind_name(instrs[i])}",
        )
    }
  }
  changed
}

///|
fn rub_optimize_jump_thread_child_block_following_return(
  instrs : Array[TInstr],
  candidate_sites : Array[Int],
  trace_state? : RUBRoundTraceState? = None,
) -> Bool {
  rub_optimize_jump_thread_child_block_following_return_with_budgets(
    instrs,
    candidate_sites,
    RUB_JUMP_THREAD_BR_CHILD_SCOPE_SCAN_VISIT_BUDGET,
    RUB_JUMP_THREAD_BR_CHILD_SCOPE_REWRITE_VISIT_BUDGET,
    trace_state~,
  )
}

///|
fn rub_optimize_jump_thread_child_block_following_return_with_budgets(
  instrs : Array[TInstr],
  candidate_sites : Array[Int],
  scan_visit_budget : Int,
  rewrite_visit_budget : Int,
  trace_state? : RUBRoundTraceState? = None,
) -> Bool {
  if instrs.length() < 2 {
    return false
  }
  rub_trace_log_helper_event(
    trace_state,
    "jump_thread_return",
    "start",
    "instrs=\{instrs.length()}",
  )
  let mut changed = false
  for i in candidate_sites {
    if i + 1 >= instrs.length() {
      continue
    }
    rub_trace_log_helper_event(
      trace_state,
      "jump_thread_return",
      "scan_site",
      "site=\{i}",
    )
    match instrs[i].kind {
      TInstrKind::TBlock(VoidBlockType, body) => {
        let mut j = i + 1
        while j < instrs.length() && instrs[j].kind is TInstrKind::TNop {
          j += 1
        }
        if j < instrs.length() {
          match instrs[j].kind {
            TInstrKind::TReturn([]) => {
              rub_trace_log_helper_event(
                trace_state,
                "jump_thread_return",
                "candidate",
                "site=\{i} body_instrs=\{body.instrs.length()} return_site=\{j}",
              )
              let body_scan_start_ms = sl_trace_now_ms()
              let body_scan_result = rub_has_top_level_child_scope_branch_with_budget(
                body,
                scan_visit_budget,
                trace_state~,
              )
              rub_trace_log_helper_step_done(
                trace_state,
                "jump_thread_return",
                "scan_body",
                sl_trace_elapsed_ms(body_scan_start_ms),
                "site=\{i} body_instrs=\{body.instrs.length()} result=\{rub_child_scope_branch_scan_result_name(body_scan_result)}",
              )
              match body_scan_result {
                ScanNotFound => {
                  rub_trace_log_helper_event(
                    trace_state,
                    "jump_thread_return",
                    "candidate_reject",
                    "site=\{i} reason=no_child_scope_branch",
                  )
                  continue
                }
                ScanAborted => {
                  rub_trace_log_helper_event(
                    trace_state,
                    "jump_thread_return",
                    "scan_body_abort",
                    "site=\{i} body_instrs=\{body.instrs.length()}",
                  )
                  continue
                }
                ScanFound => ()
              }
              let (next_body, body_changed) = rub_redirect_simple_child_scope_branches_to_return_with_budget(
                body,
                rewrite_visit_budget,
                trace_state~,
              )
              if !body_changed {
                rub_trace_log_helper_event(
                  trace_state,
                  "jump_thread_return",
                  "candidate_reject",
                  "site=\{i} reason=rewrite_no_change",
                )
              } else {
                instrs[i] = TInstr::block(BlockType::void_(), next_body)
                changed = true
              }
            }
            _ =>
              rub_trace_log_helper_event(
                trace_state,
                "jump_thread_return",
                "scan_site_skip",
                "site=\{i} reason=next_not_return next_site=\{j} kind=\{rub_instr_kind_name(instrs[j])}",
              )
          }
        } else {
          rub_trace_log_helper_event(
            trace_state,
            "jump_thread_return",
            "scan_site_skip",
            "site=\{i} reason=no_next_after_block body_instrs=\{body.instrs.length()}",
          )
        }
      }
      _ =>
        rub_trace_log_helper_event(
          trace_state,
          "jump_thread_return",
          "scan_site_skip",
          "site=\{i} reason=not_void_block kind=\{rub_instr_kind_name(instrs[i])}",
        )
    }
  }
  changed
}

///|
priv enum RUBTryTableThrowMatch {
  NoMatch
  MatchCatch(LabelIdx)
  MatchCatchAll(LabelIdx)
  MatchCatchRef(LabelIdx)
  MatchCatchAllRef(LabelIdx)
}

///|
priv enum RUBTryTableThrowRefMatch {
  NoMatch
  MatchCatchAll(LabelIdx)
  MatchCatchAllRef(LabelIdx)
  MatchUnknown
}

///|
priv enum RUBTryTableStaticTagMatch {
  NoMatch
  MatchCatch(LabelIdx)
  MatchCatchRef(LabelIdx)
  MatchCatchAll(LabelIdx)
  MatchCatchAllRef(LabelIdx)
}

///|
fn rub_try_table_throw_match(
  catches : Array[Catch],
  thrown_tag : TagIdx,
) -> RUBTryTableThrowMatch {
  for catch_ in catches {
    match catch_ {
      Catch(catch_tag, label) =>
        if catch_tag == thrown_tag {
          return MatchCatch(label)
        }
      CatchRef(catch_tag, label) =>
        if catch_tag == thrown_tag {
          return MatchCatchRef(label)
        }
      CatchAll(label) => return MatchCatchAll(label)
      CatchAllRef(label) => return MatchCatchAllRef(label)
    }
  }
  NoMatch
}

///|
fn rub_try_table_throw_ref_match(
  catches : Array[Catch],
) -> RUBTryTableThrowRefMatch {
  for catch_ in catches {
    match catch_ {
      Catch(_, _) | CatchRef(_, _) =>
        // `throw_ref` carries only an exnref. Without static tag identity we
        // cannot prove whether a tag-specific catch intercepts here.
        return MatchUnknown
      CatchAll(label) => return MatchCatchAll(label)
      CatchAllRef(label) => return MatchCatchAllRef(label)
    }
  }
  NoMatch
}

///|
fn rub_try_table_match_static_tag(
  catches : Array[Catch],
  thrown_tag : TagIdx,
) -> RUBTryTableStaticTagMatch {
  for catch_ in catches {
    match catch_ {
      Catch(catch_tag, label) =>
        if catch_tag == thrown_tag {
          return MatchCatch(label)
        }
      CatchRef(catch_tag, label) =>
        if catch_tag == thrown_tag {
          return MatchCatchRef(label)
        }
      CatchAll(label) => return MatchCatchAll(label)
      CatchAllRef(label) => return MatchCatchAllRef(label)
    }
  }
  NoMatch
}

///|
fn rub_branch_after_dropping_values(
  label : LabelIdx,
  values : Array[TInstr],
) -> TInstr {
  if values.length() == 0 {
    return TInstr::br(label, [])
  }
  let items : Array[TInstr] = []
  for value in values {
    items.push(TInstr::drop(value))
  }
  items.push(TInstr::br(label, []))
  TInstr::block(BlockType::void_(), TExpr::new(items))
}

///|
fn rub_non_null_exnref_type() -> ValType {
  ValType::ref_type(RefType::new(false, HeapType::abs(AbsHeapType::exn())))
}

///|
fn rub_is_internal_exnref_materializer_catches(catches : Array[Catch]) -> Bool {
  match catches {
    [CatchAllRef(LabelIdx(2U))] => true
    _ => false
  }
}

///|
fn rub_materialize_exnref_from_throw(
  thrown_tag : TagIdx,
  values : Array[TInstr],
) -> TInstr {
  TInstr::block(
    BlockType::val_type(rub_non_null_exnref_type()),
    TExpr::new([
      TInstr::block(
        BlockType::void_(),
        TExpr::new([
          TInstr::try_table(
            BlockType::void_(),
            [Catch::all_ref(LabelIdx::new(2))],
            TExpr::new([TInstr::throw_(thrown_tag, values)]),
          ),
          TInstr::unreachable_(),
        ]),
      ),
      TInstr::unreachable_(),
    ]),
  )
}

///|
fn rub_extract_materialized_throw_exnref(
  value : TInstr,
) -> (TagIdx, Array[TInstr])? {
  match value.kind {
    TInstrKind::TBlock(
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              VoidBlockType,
              {
                instrs: [
                  {
                    kind: TInstrKind::TTryTable(
                      VoidBlockType,
                      catches,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TThrow(thrown_tag, thrown_values),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                  { kind: TInstrKind::TUnreachable, .. },
                ],
                ..,
              }
            ),
            ..,
          },
          { kind: TInstrKind::TUnreachable, .. },
        ],
        ..,
      }
    ) =>
      if rub_is_internal_exnref_materializer_catches(catches) {
        Some((thrown_tag, thrown_values))
      } else {
        None
      }
    _ => None
  }
}

///|
fn rub_alloc_scratch_local(state : RUBWalkState, ty : ValType) -> LocalIdx {
  let idx = state.local_base_count + state.scratch_locals.val.length()
  if idx < 0 {
    abort("remove_unused_brs scratch local index underflow")
  }
  state.scratch_locals.val.push(ty)
  LocalIdx::new(idx.reinterpret_as_uint())
}

///|
fn rub_try_build_throw_to_catch_ref_branch(
  state : RUBWalkState,
  label : LabelIdx,
  thrown_tag : TagIdx,
  values : Array[TInstr],
) -> TInstr? {
  if values.length() == 0 {
    return Some(
      TInstr::br(label, [rub_materialize_exnref_from_throw(thrown_tag, [])]),
    )
  }
  let payload_types = match state.tag_payload_types.get(thrown_tag) {
    Some(payload_types) => payload_types
    None => return None
  }
  if payload_types.length() != values.length() {
    return None
  }
  let br_values : Array[TInstr] = []
  let materialize_values : Array[TInstr] = []
  let mut i = 0
  while i < values.length() {
    let local_idx = rub_alloc_scratch_local(state, payload_types[i])
    br_values.push(TInstr::local_tee(local_idx, values[i]))
    materialize_values.push(TInstr::local_get(local_idx))
    i += 1
  }
  br_values.push(
    rub_materialize_exnref_from_throw(thrown_tag, materialize_values),
  )
  Some(TInstr::br(label, br_values))
}

///|
fn rub_rebase_try_table_throw_label(
  label : LabelIdx,
  throw_depth : Int,
  catcher_depth : Int,
) -> LabelIdx {
  let shift = throw_depth - (catcher_depth + 1)
  if shift <= 0 {
    label
  } else {
    rub_label_from_int(rub_label_to_int(label) + shift)
  }
}

///|
fn rub_optimize_throw_to_branch(
  instr : TInstr,
  state : RUBWalkState,
) -> (TInstr, Bool) {
  match instr.kind {
    TInstrKind::TThrow(thrown_tag, values) => {
      if state.catchers.length() > 0 &&
        rub_is_internal_exnref_materializer_catches(
          state.catchers[state.catchers.length() - 1].catches,
        ) {
        return (instr, false)
      }
      let mut i = state.catchers.length()
      while i > 0 {
        i -= 1
        let catcher = state.catchers[i]
        match rub_try_table_throw_match(catcher.catches, thrown_tag) {
          MatchCatch(label) => {
            let next_label = rub_rebase_try_table_throw_label(
              label,
              state.label_depth,
              catcher.depth,
            )
            return (TInstr::br(next_label, values), true)
          }
          MatchCatchAll(label) => {
            let next_label = rub_rebase_try_table_throw_label(
              label,
              state.label_depth,
              catcher.depth,
            )
            return (rub_branch_after_dropping_values(next_label, values), true)
          }
          MatchCatchRef(label) => {
            let next_label = rub_rebase_try_table_throw_label(
              label,
              state.label_depth,
              catcher.depth,
            )
            match
              rub_try_build_throw_to_catch_ref_branch(
                state, next_label, thrown_tag, values,
              ) {
              Some(rewrite) => return (rewrite, true)
              None => return (instr, false)
            }
          }
          MatchCatchAllRef(label) => {
            let next_label = rub_rebase_try_table_throw_label(
              label,
              state.label_depth,
              catcher.depth,
            )
            return (
              TInstr::br(next_label, [
                rub_materialize_exnref_from_throw(thrown_tag, values),
              ]),
              true,
            )
          }
          NoMatch => ()
        }
      }
      (instr, false)
    }
    TInstrKind::TThrowRef(value) => {
      let static_throw = rub_extract_materialized_throw_exnref(value)
      let mut i = state.catchers.length()
      while i > 0 {
        i -= 1
        let catcher = state.catchers[i]
        match static_throw {
          Some((static_tag, static_values)) =>
            match rub_try_table_match_static_tag(catcher.catches, static_tag) {
              MatchCatch(label) => {
                let next_label = rub_rebase_try_table_throw_label(
                  label,
                  state.label_depth,
                  catcher.depth,
                )
                return (TInstr::br(next_label, static_values), true)
              }
              MatchCatchRef(label) => {
                let next_label = rub_rebase_try_table_throw_label(
                  label,
                  state.label_depth,
                  catcher.depth,
                )
                match
                  rub_try_build_throw_to_catch_ref_branch(
                    state, next_label, static_tag, static_values,
                  ) {
                  Some(rewrite) => return (rewrite, true)
                  None => return (instr, false)
                }
              }
              MatchCatchAll(label) => {
                let next_label = rub_rebase_try_table_throw_label(
                  label,
                  state.label_depth,
                  catcher.depth,
                )
                return (
                  rub_branch_after_dropping_values(next_label, [value]),
                  true,
                )
              }
              MatchCatchAllRef(label) => {
                let next_label = rub_rebase_try_table_throw_label(
                  label,
                  state.label_depth,
                  catcher.depth,
                )
                return (TInstr::br(next_label, [value]), true)
              }
              NoMatch => continue
            }
          None => ()
        }
        match rub_try_table_throw_ref_match(catcher.catches) {
          MatchCatchAll(label) => {
            let next_label = rub_rebase_try_table_throw_label(
              label,
              state.label_depth,
              catcher.depth,
            )
            return (rub_branch_after_dropping_values(next_label, [value]), true)
          }
          MatchCatchAllRef(label) => {
            let next_label = rub_rebase_try_table_throw_label(
              label,
              state.label_depth,
              catcher.depth,
            )
            return (TInstr::br(next_label, [value]), true)
          }
          MatchUnknown => return (instr, false)
          NoMatch => ()
        }
      }
      (instr, false)
    }
    _ => (instr, false)
  }
}

///|
fn rub_optimize_try_table_throw_to_branch(
  instr : TInstr,
  state : RUBWalkState,
) -> (TInstr, Bool) {
  match instr.kind {
    TInstrKind::TTryTable(bt, catches, { instrs: [single], .. }) =>
      if rub_is_internal_exnref_materializer_catches(catches) {
        (instr, false)
      } else {
        match single.kind {
          TInstrKind::TThrow(thrown_tag, values) =>
            match rub_try_table_throw_match(catches, thrown_tag) {
              MatchCatch(label) =>
                (
                  TInstr::try_table(
                    bt,
                    catches,
                    TExpr::new([TInstr::br(label, values)]),
                  ),
                  true,
                )
              MatchCatchAll(label) =>
                (
                  TInstr::try_table(
                    bt,
                    catches,
                    TExpr::new([rub_branch_after_dropping_values(label, values)]),
                  ),
                  true,
                )
              MatchCatchRef(label) =>
                match
                  rub_try_build_throw_to_catch_ref_branch(
                    state, label, thrown_tag, values,
                  ) {
                  Some(rewrite) =>
                    (
                      TInstr::try_table(bt, catches, TExpr::new([rewrite])),
                      true,
                    )
                  None => (instr, false)
                }
              MatchCatchAllRef(label) =>
                (
                  TInstr::try_table(
                    bt,
                    catches,
                    TExpr::new([
                      TInstr::br(label, [
                        rub_materialize_exnref_from_throw(thrown_tag, values),
                      ]),
                    ]),
                  ),
                  true,
                )
              NoMatch => (instr, false)
            }
          TInstrKind::TThrowRef(value) =>
            match rub_extract_materialized_throw_exnref(value) {
              Some((static_tag, static_values)) =>
                match rub_try_table_match_static_tag(catches, static_tag) {
                  MatchCatch(label) =>
                    (
                      TInstr::try_table(
                        bt,
                        catches,
                        TExpr::new([TInstr::br(label, static_values)]),
                      ),
                      true,
                    )
                  MatchCatchRef(label) =>
                    match
                      rub_try_build_throw_to_catch_ref_branch(
                        state, label, static_tag, static_values,
                      ) {
                      Some(rewrite) =>
                        (
                          TInstr::try_table(bt, catches, TExpr::new([rewrite])),
                          true,
                        )
                      None => (instr, false)
                    }
                  MatchCatchAll(label) =>
                    (
                      TInstr::try_table(
                        bt,
                        catches,
                        TExpr::new([
                          rub_branch_after_dropping_values(label, [value]),
                        ]),
                      ),
                      true,
                    )
                  MatchCatchAllRef(label) =>
                    (
                      TInstr::try_table(
                        bt,
                        catches,
                        TExpr::new([TInstr::br(label, [value])]),
                      ),
                      true,
                    )
                  NoMatch => (instr, false)
                }
              None =>
                match rub_try_table_throw_ref_match(catches) {
                  MatchCatchAll(label) =>
                    (
                      TInstr::try_table(
                        bt,
                        catches,
                        TExpr::new([
                          rub_branch_after_dropping_values(label, [value]),
                        ]),
                      ),
                      true,
                    )
                  MatchCatchAllRef(label) =>
                    (
                      TInstr::try_table(
                        bt,
                        catches,
                        TExpr::new([TInstr::br(label, [value])]),
                      ),
                      true,
                    )
                  MatchUnknown | NoMatch => (instr, false)
                }
            }
          _ => (instr, false)
        }
      }
    _ => (instr, false)
  }
}

///|
fn rub_remove_trailing_nops(instrs : Array[TInstr]) -> Bool {
  let mut changed = false
  while instrs.length() > 0 {
    match instrs[instrs.length() - 1].kind {
      TInstrKind::TNop => {
        ignore(instrs.pop())
        changed = true
      }
      _ => return changed
    }
  }
  changed
}

///|
priv struct RUBStackSig {
  required : Int
  produced : Int
  reachable : Bool
}

///|
fn rub_stack_sig(
  required : Int,
  produced : Int,
  reachable : Bool,
) -> RUBStackSig {
  { required, produced, reachable }
}

///|
fn rub_stack_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn rub_stack_nonneg_int(i : Int) -> Int {
  if i > 0 {
    i
  } else {
    0
  }
}

///|
fn rub_stack_sig_seq(a : RUBStackSig, b : RUBStackSig) -> RUBStackSig {
  if !a.reachable {
    a
  } else {
    let required = rub_stack_max_int(
      a.required,
      rub_stack_nonneg_int(b.required - a.produced),
    )
    if !b.reachable {
      rub_stack_sig(required, 0, false)
    } else {
      rub_stack_sig(required, a.produced + b.produced, true)
    }
  }
}

///|
fn rub_stack_sig_pop_push(
  child_sig : RUBStackSig,
  pop_count : Int,
  push_count : Int,
) -> RUBStackSig {
  if !child_sig.reachable {
    child_sig
  } else {
    rub_stack_sig(
      rub_stack_max_int(
        child_sig.required,
        rub_stack_nonneg_int(pop_count - child_sig.produced),
      ),
      child_sig.produced - pop_count + push_count,
      true,
    )
  }
}

///|
fn rub_stack_sig_terminate(
  child_sig : RUBStackSig,
  pop_count : Int,
) -> RUBStackSig {
  if !child_sig.reachable {
    child_sig
  } else {
    rub_stack_sig(
      rub_stack_max_int(
        child_sig.required,
        rub_stack_nonneg_int(pop_count - child_sig.produced),
      ),
      0,
      false,
    )
  }
}

///|
fn rub_stack_sig_list(items : Array[TInstr]) -> RUBStackSig? {
  let mut acc = rub_stack_sig(0, 0, true)
  for item in items {
    match rub_stack_sig_instr(item) {
      Some(sig) => {
        acc = rub_stack_sig_seq(acc, sig)
        if !acc.reachable {
          break
        }
      }
      None => return None
    }
  }
  Some(acc)
}

///|
fn rub_stack_sig_if(
  cond_sig : RUBStackSig,
  then_sig : RUBStackSig,
  else_sig : RUBStackSig,
) -> RUBStackSig {
  if !cond_sig.reachable {
    return cond_sig
  }
  let branch_required = rub_stack_max_int(then_sig.required, else_sig.required)
  let branch_reachable = then_sig.reachable || else_sig.reachable
  let branch_produced = if then_sig.reachable && else_sig.reachable {
    if then_sig.produced < else_sig.produced {
      then_sig.produced
    } else {
      else_sig.produced
    }
  } else if then_sig.reachable {
    then_sig.produced
  } else if else_sig.reachable {
    else_sig.produced
  } else {
    0
  }
  let need_after_cond = 1 + branch_required
  rub_stack_sig(
    rub_stack_max_int(
      cond_sig.required,
      rub_stack_nonneg_int(need_after_cond - cond_sig.produced),
    ),
    branch_produced,
    branch_reachable,
  )
}

///|
fn rub_stack_sig_instr(instr : TInstr) -> RUBStackSig? {
  match instr.kind {
    TInstrKind::TNop => Some(rub_stack_sig(0, 0, true))
    TInstrKind::TUnreachable => Some(rub_stack_sig(0, 0, false))
    TInstrKind::TLocalGet(_)
    | TInstrKind::TGlobalGet(_)
    | TInstrKind::TI32Const(_)
    | TInstrKind::TI64Const(_)
    | TInstrKind::TF32Const(_)
    | TInstrKind::TF64Const(_)
    | TInstrKind::TRefNull(_)
    | TInstrKind::TRefFunc(_)
    | TInstrKind::TMemorySize(_)
    | TInstrKind::TTableSize(_) => Some(rub_stack_sig(0, 1, true))
    TInstrKind::TDrop(value)
    | TInstrKind::TLocalSet(_, value)
    | TInstrKind::TGlobalSet(_, value) =>
      rub_stack_sig_instr(value).map(fn(sig) {
        rub_stack_sig_pop_push(sig, 1, 0)
      })
    TInstrKind::TLocalTee(_, value) =>
      rub_stack_sig_instr(value).map(fn(sig) {
        rub_stack_sig_pop_push(sig, 1, 1)
      })
    TInstrKind::TUnary(_, value)
    | TInstrKind::TLoad(_, _, value)
    | TInstrKind::TRefIsNull(value)
    | TInstrKind::TRefAsNonNull(value)
    | TInstrKind::TAnyConvertExtern(value)
    | TInstrKind::TExternConvertAny(value)
    | TInstrKind::TI31GetS(value)
    | TInstrKind::TI31GetU(value)
    | TInstrKind::TArrayLen(value) =>
      rub_stack_sig_instr(value).map(fn(sig) {
        rub_stack_sig_pop_push(sig, 1, 1)
      })
    TInstrKind::TBinary(_, left, right) | TInstrKind::TRefEq(left, right) =>
      rub_stack_sig_list([left, right]).map(fn(sig) {
        rub_stack_sig_pop_push(sig, 2, 1)
      })
    TInstrKind::TStore(_, _, addr, value)
    | TInstrKind::TTableSet(_, addr, value) =>
      rub_stack_sig_list([addr, value]).map(fn(sig) {
        rub_stack_sig_pop_push(sig, 2, 0)
      })
    TInstrKind::TSelect(_, cond, if_true, if_false) =>
      rub_stack_sig_list([if_true, if_false, cond]).map(fn(sig) {
        rub_stack_sig_pop_push(sig, 3, 1)
      })
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) => rub_stack_sig_list(body.instrs)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      let else_sig = match else_body {
        Some(other) => rub_stack_sig_list(other.instrs)
        None => Some(rub_stack_sig(0, 0, true))
      }
      match
        (
          rub_stack_sig_instr(cond),
          rub_stack_sig_list(then_body.instrs),
          else_sig,
        ) {
        (Some(cond_sig), Some(then_sig), Some(other_sig)) =>
          Some(rub_stack_sig_if(cond_sig, then_sig, other_sig))
        _ => None
      }
    }
    TInstrKind::TBr(_, values) | TInstrKind::TReturn(values) =>
      rub_stack_sig_list(values).map(fn(sig) { rub_stack_sig_terminate(sig, 0) })
    TInstrKind::TBrIf(_, cond, values) =>
      rub_stack_sig_list(values + [cond]).map(fn(sig) {
        rub_stack_sig_pop_push(sig, 1, 0)
      })
    TInstrKind::TBrTable(_, _, index, values) =>
      rub_stack_sig_list(values + [index]).map(fn(sig) {
        rub_stack_sig_terminate(sig, 1)
      })
    TInstrKind::TThrow(_, values) =>
      rub_stack_sig_list(values).map(fn(sig) { rub_stack_sig_terminate(sig, 0) })
    TInstrKind::TThrowRef(value) =>
      rub_stack_sig_instr(value).map(fn(sig) { rub_stack_sig_terminate(sig, 1) })
    _ => None
  }
}

///|
fn rub_prefix_preserves_stack_height(
  instrs : Array[TInstr],
  end_exclusive : Int,
) -> Bool {
  if end_exclusive <= 0 {
    return true
  }
  let prefix : Array[TInstr] = []
  for i in 0..<end_exclusive {
    prefix.push(instrs[i])
  }
  match rub_stack_sig_list(prefix) {
    Some(sig) =>
      if !sig.reachable {
        // Unreachable prefixes are polymorphic; keep explicit trailing flow breaks
        // to preserve conservative stack-reset behavior at scope boundaries.
        false
      } else {
        sig.required == sig.produced
      }
    None => false
  }
}

///|
fn rub_remove_trailing_flow_break(instrs : Array[TInstr]) -> Bool {
  if instrs.length() == 0 {
    return false
  }
  let idx = instrs.length() - 1
  match instrs[idx].kind {
    TInstrKind::TBr(label, values) => {
      if !rub_is_label_zero(label) {
        return false
      }
      if !rub_prefix_preserves_stack_height(instrs, idx) {
        return false
      }
      match values {
        [] => {
          ignore(instrs.pop())
          true
        }
        [single] => {
          instrs[idx] = single
          true
        }
        _ => false
      }
    }
    _ => false
  }
}

///|
fn rub_remove_trailing_return(instrs : Array[TInstr]) -> Bool {
  if instrs.length() == 0 {
    return false
  }
  let idx = instrs.length() - 1
  match instrs[idx].kind {
    TInstrKind::TReturn(values) =>
      match values {
        [] => {
          ignore(instrs.pop())
          true
        }
        [single] => {
          instrs[idx] = single
          true
        }
        _ => false
      }
    _ => false
  }
}

///|
fn rub_is_explicit_flow_terminator(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TBr(_, _)
    | TInstrKind::TBrTable(_, _, _, _)
    | TInstrKind::TReturn(_)
    | TInstrKind::TReturnCall(_, _)
    | TInstrKind::TReturnCallIndirect(_, _, _, _)
    | TInstrKind::TReturnCallRef(_, _, _)
    | TInstrKind::TThrow(_, _)
    | TInstrKind::TThrowRef(_) => true
    _ => false
  }
}

///|
fn rub_trim_dead_tail_after_terminator(instrs : Array[TInstr]) -> Bool {
  if instrs.length() < 2 {
    return false
  }
  let mut i = 0
  while i + 1 < instrs.length() {
    if rub_is_explicit_flow_terminator(instrs[i]) {
      let keep_existing_sentinel = instrs[i + 1].kind
        is TInstrKind::TUnreachable
      let keep_len = if keep_existing_sentinel { i + 2 } else { i + 1 }
      let mut changed = keep_len < instrs.length()
      while instrs.length() > keep_len {
        ignore(instrs.pop())
      }
      if !keep_existing_sentinel {
        instrs.push(TInstr::unreachable_())
        changed = true
      }
      return changed
    }
    i += 1
  }
  false
}

///|
fn rub_optimize_adjacent_breaks(
  instrs : Array[TInstr],
  options : OptimizeOptions,
) -> Bool {
  let mut changed = false
  let mut i = 0
  while i + 1 < instrs.length() {
    match instrs[i].kind {
      TInstrKind::TBrIf(label1, cond1, values1) =>
        if values1.length() == 0 {
          match instrs[i + 1].kind {
            TInstrKind::TBr(label2, values2) =>
              if label1 == label2 && values2.length() == 0 {
                instrs[i] = TInstr::drop(cond1)
                changed = true
              }
            TInstrKind::TBrIf(label2, cond2, values2) =>
              if label1 == label2 &&
                values2.length() == 0 &&
                options.shrink_level > 0 &&
                !rub_has_side_effects(cond2) {
                instrs[i] = TInstr::br_if(
                  label1,
                  TInstr::binary(BinaryOp::i32_or(), cond1, cond2),
                  [],
                )
                instrs[i + 1] = TInstr::nop()
                changed = true
              }
            _ => ()
          }
        }
      _ => ()
    }
    i += 1
  }
  changed
}

///|
fn rub_optimize_if_else_block_tail(
  instrs : Array[TInstr],
  options : OptimizeOptions,
  allow_list_splicing : Bool,
  trace_state? : RUBRoundTraceState? = None,
) -> Bool {
  if !allow_list_splicing {
    return false
  }
  let mut changed = false
  let mut i = 0
  while i < instrs.length() {
    match instrs[i].kind {
      TInstrKind::TIf(VoidBlockType, cond, then_body, Some(else_body)) => {
        rub_trace_log_helper_event(
          trace_state,
          "if_else_tail",
          "candidate",
          "site=\{i} then_instrs=\{then_body.instrs.length()} else_instrs=\{else_body.instrs.length()} cond_kind=\{rub_instr_kind_name(cond)}",
        )
        let mut applied = false
        match
          (rub_is_single_tinstr(then_body), rub_is_single_tinstr(else_body)) {
          (Some(single_then), Some(single_else)) =>
            match (single_then.kind, single_else.kind) {
              (TInstrKind::TBr(_, then_values), TInstrKind::TBr(_, else_values)) => {
                let can_hoist_then = rub_can_turn_if_into_br_if(
                  cond, then_values, options,
                )
                let can_hoist_else = rub_can_turn_if_into_br_if(
                  cond, else_values, options,
                )
                if can_hoist_then || can_hoist_else {
                  let next_single_then = rub_try_rebase_labels_in_tinstruction(
                    single_then, -1,
                  )
                  let next_single_else = rub_try_rebase_labels_in_tinstruction(
                    single_else, -1,
                  )
                  match (next_single_then, next_single_else) {
                    (
                      Some(
                        { kind: TInstrKind::TBr(then_label, then_values), .. }
                      ),
                      Some(
                        { kind: TInstrKind::TBr(else_label, else_values), .. }
                      ),
                    ) =>
                      if rub_is_label_zero(then_label) ||
                        rub_is_label_zero(else_label) {
                        ()
                      } else {
                        let hoisted_label = if can_hoist_then {
                          then_label
                        } else {
                          else_label
                        }
                        let hoisted_cond = if can_hoist_then {
                          cond
                        } else {
                          TInstr::unary(UnaryOp::i32_eqz(), cond)
                        }
                        let hoisted_values = if can_hoist_then {
                          then_values
                        } else {
                          else_values
                        }
                        let tail_label = if can_hoist_then {
                          else_label
                        } else {
                          then_label
                        }
                        let tail_values = if can_hoist_then {
                          else_values
                        } else {
                          then_values
                        }
                        instrs[i] = TInstr::br_if(
                          hoisted_label, hoisted_cond, hoisted_values,
                        )
                        let next : Array[TInstr] = []
                        for j in 0..<instrs.length() {
                          next.push(instrs[j])
                          if j == i {
                            next.push(TInstr::br(tail_label, tail_values))
                          }
                        }
                        instrs.clear()
                        for item in next {
                          instrs.push(item)
                        }
                        changed = true
                        applied = true
                        i += 1
                        rub_trace_log_helper_event(
                          trace_state,
                          "if_else_tail",
                          "both_branch_rewrite",
                          "site=\{i}",
                        )
                      }
                    _ => ()
                  }
                }
              }
              _ => ()
            }
          _ => ()
        }
        if !applied {
          match rub_is_single_tinstr(then_body) {
            Some(single_then) => {
              rub_trace_log_helper_event(
                trace_state,
                "if_else_tail",
                "then_path:start",
                "site=\{i} kind=\{rub_instr_kind_name(single_then)}",
              )
              match single_then.kind {
                TInstrKind::TBr(_, values) => {
                  rub_trace_log_helper_event(
                    trace_state,
                    "if_else_tail",
                    "then_branch_scan:start",
                    "site=\{i}",
                  )
                  let then_branch_scan_start_ms = sl_trace_now_ms()
                  let else_has_branch = rub_texpr_has_branch(else_body)
                  rub_trace_log_helper_step_done(
                    trace_state,
                    "if_else_tail",
                    "then_branch_scan",
                    sl_trace_elapsed_ms(then_branch_scan_start_ms),
                    "site=\{i} has_branch=\{else_has_branch} stack_neutral=\{rub_texpr_is_reachable_and_stack_neutral(else_body)}",
                  )
                  if !else_has_branch &&
                    rub_texpr_is_reachable_and_stack_neutral(else_body) {
                    rub_trace_log_helper_event(
                      trace_state,
                      "if_else_tail",
                      "then_hoist_check:start",
                      "site=\{i} values=\{values.length()}",
                    )
                    let then_hoist_check_start_ms = sl_trace_now_ms()
                    let can_hoist = rub_can_turn_if_into_br_if(
                      cond, values, options,
                    )
                    rub_trace_log_helper_step_done(
                      trace_state,
                      "if_else_tail",
                      "then_hoist_check",
                      sl_trace_elapsed_ms(then_hoist_check_start_ms),
                      "site=\{i} can_hoist=\{can_hoist}",
                    )
                    if can_hoist {
                      let then_rebase_instr_start_ms = sl_trace_now_ms()
                      let next_single_then = rub_try_rebase_labels_in_tinstruction(
                        single_then, -1,
                      )
                      rub_trace_log_helper_step_done(
                        trace_state,
                        "if_else_tail",
                        "then_rebase_instr",
                        sl_trace_elapsed_ms(then_rebase_instr_start_ms),
                        "site=\{i} success=\{next_single_then is Some(_)}",
                      )
                      let then_rebase_else_start_ms = sl_trace_now_ms()
                      let next_else_body = rub_try_rebase_labels_in_texpr(
                        else_body, -1,
                      )
                      rub_trace_log_helper_step_done(
                        trace_state,
                        "if_else_tail",
                        "then_rebase_else",
                        sl_trace_elapsed_ms(then_rebase_else_start_ms),
                        "site=\{i} success=\{next_else_body is Some(_)}",
                      )
                      match (next_single_then, next_else_body) {
                        (
                          Some({ kind: TInstrKind::TBr(label, values), .. }),
                          Some(next_else_body),
                        ) => {
                          instrs[i] = TInstr::br_if(label, cond, values)
                          let next : Array[TInstr] = []
                          for j in 0..<instrs.length() {
                            next.push(instrs[j])
                            if j == i {
                              for item in next_else_body.instrs {
                                next.push(item)
                              }
                            }
                          }
                          instrs.clear()
                          for item in next {
                            instrs.push(item)
                          }
                          changed = true
                          i += next_else_body.instrs.length()
                          applied = true
                          rub_trace_log_helper_event(
                            trace_state,
                            "if_else_tail",
                            "then_rewrite",
                            "site=\{i} splice_instrs=\{next_else_body.instrs.length()}",
                          )
                        }
                        _ => ()
                      }
                    }
                  }
                }
                _ => ()
              }
            }
            None => ()
          }
        }
        if !applied {
          match rub_is_single_tinstr(else_body) {
            Some(single_else) => {
              rub_trace_log_helper_event(
                trace_state,
                "if_else_tail",
                "else_path:start",
                "site=\{i} kind=\{rub_instr_kind_name(single_else)}",
              )
              match single_else.kind {
                TInstrKind::TBr(_, values) => {
                  rub_trace_log_helper_event(
                    trace_state,
                    "if_else_tail",
                    "else_branch_scan:start",
                    "site=\{i}",
                  )
                  let else_branch_scan_start_ms = sl_trace_now_ms()
                  let then_has_branch = rub_texpr_has_branch(then_body)
                  rub_trace_log_helper_step_done(
                    trace_state,
                    "if_else_tail",
                    "else_branch_scan",
                    sl_trace_elapsed_ms(else_branch_scan_start_ms),
                    "site=\{i} has_branch=\{then_has_branch} stack_neutral=\{rub_texpr_is_reachable_and_stack_neutral(then_body)}",
                  )
                  if !then_has_branch &&
                    rub_texpr_is_reachable_and_stack_neutral(then_body) {
                    rub_trace_log_helper_event(
                      trace_state,
                      "if_else_tail",
                      "else_hoist_check:start",
                      "site=\{i} values=\{values.length()}",
                    )
                    let else_hoist_check_start_ms = sl_trace_now_ms()
                    let can_hoist = rub_can_turn_if_into_br_if(
                      cond, values, options,
                    )
                    rub_trace_log_helper_step_done(
                      trace_state,
                      "if_else_tail",
                      "else_hoist_check",
                      sl_trace_elapsed_ms(else_hoist_check_start_ms),
                      "site=\{i} can_hoist=\{can_hoist}",
                    )
                    if can_hoist {
                      let else_rebase_instr_start_ms = sl_trace_now_ms()
                      let next_single_else = rub_try_rebase_labels_in_tinstruction(
                        single_else, -1,
                      )
                      rub_trace_log_helper_step_done(
                        trace_state,
                        "if_else_tail",
                        "else_rebase_instr",
                        sl_trace_elapsed_ms(else_rebase_instr_start_ms),
                        "site=\{i} success=\{next_single_else is Some(_)}",
                      )
                      let else_rebase_then_start_ms = sl_trace_now_ms()
                      let next_then_body = rub_try_rebase_labels_in_texpr(
                        then_body, -1,
                      )
                      rub_trace_log_helper_step_done(
                        trace_state,
                        "if_else_tail",
                        "else_rebase_then",
                        sl_trace_elapsed_ms(else_rebase_then_start_ms),
                        "site=\{i} success=\{next_then_body is Some(_)}",
                      )
                      match (next_single_else, next_then_body) {
                        (
                          Some({ kind: TInstrKind::TBr(label, values), .. }),
                          Some(next_then_body),
                        ) => {
                          instrs[i] = TInstr::br_if(
                            label,
                            TInstr::unary(UnaryOp::i32_eqz(), cond),
                            values,
                          )
                          let next : Array[TInstr] = []
                          for j in 0..<instrs.length() {
                            next.push(instrs[j])
                            if j == i {
                              for item in next_then_body.instrs {
                                next.push(item)
                              }
                            }
                          }
                          instrs.clear()
                          for item in next {
                            instrs.push(item)
                          }
                          changed = true
                          i += next_then_body.instrs.length()
                          applied = true
                          rub_trace_log_helper_event(
                            trace_state,
                            "if_else_tail",
                            "else_rewrite",
                            "site=\{i} splice_instrs=\{next_then_body.instrs.length()}",
                          )
                        }
                        _ => ()
                      }
                    }
                  }
                }
                _ => ()
              }
            }
            None => ()
          }
        }
      }
      _ => ()
    }
    i += 1
  }
  changed
}

///|
fn rub_if_arm_set_values_are_selectifiable(
  cond : TInstr,
  then_value : TInstr,
  else_value : TInstr,
  options : OptimizeOptions,
) -> Bool {
  if rub_has_side_effects(then_value) || rub_has_side_effects(else_value) {
    return false
  }
  if rub_too_costly_to_run_unconditionally(
      options,
      rub_values_cost([then_value, else_value]),
    ) {
    return false
  }
  let cond_effects = lcs_collect_effects(cond)
  let value_effects = rub_instr_list_effects([then_value, else_value])
  !cond_effects.invalidates(value_effects) &&
  !value_effects.invalidates(cond_effects)
}

///|
fn rub_optimize_if_arm_local_set_get_tail(
  instrs : Array[TInstr],
  options : OptimizeOptions,
) -> Bool {
  if instrs.length() == 0 {
    return false
  }
  let mut changed = false
  let mut i = 0
  while i < instrs.length() {
    match instrs[i].kind {
      TInstrKind::TIf(VoidBlockType, cond, then_body, Some(else_body)) =>
        match
          (rub_is_single_tinstr(then_body), rub_is_single_tinstr(else_body)) {
          (
            Some({ kind: TInstrKind::TLocalSet(then_idx, then_value), .. }),
            Some({ kind: TInstrKind::TLocalSet(else_idx, else_value), .. }),
          ) =>
            if then_idx == else_idx &&
              rub_if_arm_set_values_are_selectifiable(
                cond, then_value, else_value, options,
              ) {
              let next_then = rub_try_rebase_labels_in_tinstruction(
                then_value, -1,
              )
              let next_else = rub_try_rebase_labels_in_tinstruction(
                else_value, -1,
              )
              match (next_then, next_else) {
                (Some(next_then), Some(next_else)) => {
                  let set_value = TInstr::select(
                    None,
                    cond,
                    next_then,
                    next_else,
                  )
                  if i + 1 < instrs.length() {
                    match instrs[i + 1].kind {
                      TInstrKind::TLocalGet(get_idx) if get_idx == then_idx => {
                        instrs[i] = TInstr::local_tee(then_idx, set_value)
                        instrs[i + 1] = TInstr::nop()
                        changed = true
                        i += 1
                      }
                      _ => {
                        instrs[i] = TInstr::local_set(then_idx, set_value)
                        changed = true
                      }
                    }
                  } else {
                    instrs[i] = TInstr::local_set(then_idx, set_value)
                    changed = true
                  }
                }
                _ => ()
              }
            }
          _ => ()
        }
      _ => ()
    }
    i += 1
  }
  changed
}

///|
fn rub_optimize_redundant_dropped_br_if_tail(instrs : Array[TInstr]) -> Bool {
  if instrs.length() < 2 {
    return false
  }
  let second_last_i = instrs.length() - 2
  let last_i = instrs.length() - 1
  match instrs[second_last_i].kind {
    TInstrKind::TDrop({ kind: TInstrKind::TBrIf(label, cond, [value]), .. }) =>
      if rub_is_label_zero(label) && value == instrs[last_i] {
        let value_effects = lcs_collect_effects(value)
        if value_effects.has_unremovable_side_effects() {
          return false
        }
        let cond_effects = lcs_collect_effects(cond)
        if cond_effects.invalidates(value_effects) {
          return false
        }
        instrs[second_last_i] = TInstr::drop(cond)
        true
      } else {
        false
      }
    _ => false
  }
}

///|
fn rub_optimize_instr_list(
  instrs : Array[TInstr],
  options : OptimizeOptions,
  in_function_body : Bool,
  allow_list_splicing : Bool,
  zero_break_is_fallthrough : Bool,
  trace_state? : RUBRoundTraceState? = None,
) -> Bool {
  let mut changed = false
  if rub_optimize_loop_tail_branches(instrs, zero_break_is_fallthrough) {
    changed = true
  }
  if rub_remove_trailing_fallthrough_br_if(instrs, zero_break_is_fallthrough) {
    changed = true
  }
  if rub_remove_trailing_nops(instrs) {
    changed = true
  }
  if zero_break_is_fallthrough && rub_remove_trailing_flow_break(instrs) {
    changed = true
  }
  if in_function_body && rub_remove_trailing_return(instrs) {
    changed = true
  }
  if rub_optimize_terminal_if_flow(
      instrs, in_function_body, zero_break_is_fallthrough,
    ) {
    changed = true
  }
  let if_else_tail_start_ms = sl_trace_now_ms()
  if rub_optimize_if_else_block_tail(
      instrs,
      options,
      allow_list_splicing,
      trace_state~,
    ) {
    changed = true
  }
  rub_trace_log_slow_helper(
    trace_state,
    "if_else_tail",
    sl_trace_elapsed_ms(if_else_tail_start_ms),
    instrs.length(),
  )
  let set_get_tail_start_ms = sl_trace_now_ms()
  if rub_optimize_if_arm_local_set_get_tail(instrs, options) {
    changed = true
  }
  rub_trace_log_slow_helper(
    trace_state,
    "if_set_get_tail",
    sl_trace_elapsed_ms(set_get_tail_start_ms),
    instrs.length(),
  )
  let adjacent_breaks_start_ms = sl_trace_now_ms()
  if rub_optimize_adjacent_breaks(instrs, options) {
    changed = true
  }
  rub_trace_log_slow_helper(
    trace_state,
    "adjacent_breaks",
    sl_trace_elapsed_ms(adjacent_breaks_start_ms),
    instrs.length(),
  )
  let jump_thread_sites = rub_collect_top_level_void_block_sites(instrs)
  let jump_thread_br_if_start_ms = sl_trace_now_ms()
  if rub_optimize_jump_thread_child_block_following_br_if(
      instrs,
      jump_thread_sites,
      trace_state~,
    ) {
    changed = true
  }
  rub_trace_log_slow_helper(
    trace_state,
    "jump_thread_br_if",
    sl_trace_elapsed_ms(jump_thread_br_if_start_ms),
    instrs.length(),
  )
  let jump_thread_br_start_ms = sl_trace_now_ms()
  if rub_optimize_jump_thread_child_block_following_br(
      instrs,
      jump_thread_sites,
      trace_state~,
    ) {
    changed = true
  }
  rub_trace_log_slow_helper(
    trace_state,
    "jump_thread_br",
    sl_trace_elapsed_ms(jump_thread_br_start_ms),
    instrs.length(),
  )
  let jump_thread_unreachable_start_ms = sl_trace_now_ms()
  if rub_optimize_jump_thread_child_block_following_unreachable(
      instrs,
      jump_thread_sites,
      trace_state~,
    ) {
    changed = true
  }
  rub_trace_log_slow_helper(
    trace_state,
    "jump_thread_unreachable",
    sl_trace_elapsed_ms(jump_thread_unreachable_start_ms),
    instrs.length(),
  )
  let jump_thread_return_start_ms = sl_trace_now_ms()
  if rub_optimize_jump_thread_child_block_following_return(
      instrs,
      jump_thread_sites,
      trace_state~,
    ) {
    changed = true
  }
  rub_trace_log_slow_helper(
    trace_state,
    "jump_thread_return",
    sl_trace_elapsed_ms(jump_thread_return_start_ms),
    instrs.length(),
  )
  if zero_break_is_fallthrough {
    let dropped_tail_start_ms = sl_trace_now_ms()
    if rub_optimize_redundant_dropped_br_if_tail(instrs) {
      changed = true
    }
    rub_trace_log_slow_helper(
      trace_state,
      "dropped_br_if_tail",
      sl_trace_elapsed_ms(dropped_tail_start_ms),
      instrs.length(),
    )
  }
  if rub_trim_dead_tail_after_terminator(instrs) {
    changed = true
  }
  if rub_remove_trailing_nops(instrs) {
    changed = true
  }
  if zero_break_is_fallthrough && rub_remove_trailing_flow_break(instrs) {
    changed = true
  }
  if in_function_body && rub_remove_trailing_return(instrs) {
    changed = true
  }
  changed
}

///|
fn remove_unused_brs_pass(
  options : OptimizeOptions,
  trace_state? : RUBRoundTraceState? = None,
) -> ModuleTransformer[RUBWalkState, String] {
  ModuleTransformer::new()
  .on_func_evt(fn(self, state, func) {
    match func {
      TFunc(params, locals, body) => {
        let new_body = match
          self.walk_texpr(rub_walk_function_body_state(state), body) {
          Ok((walked, _)) => walked
          Err(e) => return error(e)
        }
        if new_body != body {
          change(state, Func::t_func(params, locals, new_body))
        } else {
          unchanged()
        }
      }
      _ => unchanged()
    }
  })
  .on_texpr_evt(fn(self, state, expr) {
    match rub_trace_note_expr(trace_state, "walk:expr") {
      Ok(_) => ()
      Err(e) => return error(e)
    }
    let out : Array[TInstr] = []
    let mut changed = false
    for instr in expr.instrs {
      let next_instr = match self.walk_tinstruction(state, instr) {
        Ok((walked, _)) => walked
        Err(e) => return error(e)
      }
      if next_instr != instr {
        changed = true
      }
      out.push(next_instr)
    }
    if rub_optimize_instr_list(
        out,
        options,
        state.in_function_body,
        state.allow_list_splicing,
        state.zero_break_is_fallthrough,
        trace_state~,
      ) {
      changed = true
      match rub_trace_note_rewrite(trace_state, "rewrite:expr") {
        Ok(_) => ()
        Err(e) => return error(e)
      }
    }
    if changed {
      change(state, TExpr::new(out))
    } else {
      // We already walked children; return the original node to avoid a second default walk.
      change(state, expr)
    }
  })
  .on_tinstruction_evt(fn(self, state, instr) {
    match rub_trace_note_instr(trace_state, "walk:instr") {
      Ok(_) => ()
      Err(e) => return error(e)
    }
    let walked_start_ms = sl_trace_now_ms()
    let walked = match instr.kind {
      TInstrKind::TBlock(bt, body) => {
        let next_bt = match self.rub_walk_blocktype_result(state, bt) {
          Ok(next_bt) => next_bt
          Err(e) => return error(e)
        }
        let next_body = match
          self.rub_walk_texpr_result(
            rub_walk_nested_texpr_state(state, next_bt, true),
            body,
          ) {
          Ok(next_body) => next_body
          Err(e) => return error(e)
        }
        if next_bt == bt && next_body == body {
          instr
        } else {
          TInstr::block(next_bt, next_body)
        }
      }
      TInstrKind::TLoop(bt, body) => {
        let next_bt = match self.rub_walk_blocktype_result(state, bt) {
          Ok(next_bt) => next_bt
          Err(e) => return error(e)
        }
        let next_body = match
          self.rub_walk_texpr_result(
            rub_walk_nested_texpr_state(state, next_bt, false),
            body,
          ) {
          Ok(next_body) => next_body
          Err(e) => return error(e)
        }
        if next_bt == bt && next_body == body {
          instr
        } else {
          TInstr::loop_(next_bt, next_body)
        }
      }
      TInstrKind::TIf(bt, cond, then_body, else_body) => {
        let next_bt = match self.rub_walk_blocktype_result(state, bt) {
          Ok(next_bt) => next_bt
          Err(e) => return error(e)
        }
        let next_cond = match self.rub_walk_tinstruction_result(state, cond) {
          Ok(next_cond) => next_cond
          Err(e) => return error(e)
        }
        let branch_state = rub_walk_nested_texpr_state(state, next_bt, true)
        let next_then = match
          self.rub_walk_texpr_result(branch_state, then_body) {
          Ok(next_then) => next_then
          Err(e) => return error(e)
        }
        let next_else = match else_body {
          Some(other) =>
            match self.rub_walk_texpr_result(branch_state, other) {
              Ok(next_other) => Some(next_other)
              Err(e) => return error(e)
            }
          None => None
        }
        if next_bt == bt &&
          next_cond == cond &&
          next_then == then_body &&
          next_else == else_body {
          instr
        } else {
          TInstr::if_(next_bt, next_cond, next_then, next_else)
        }
      }
      TInstrKind::TTryTable(bt, catches, body) => {
        let next_bt = match self.rub_walk_blocktype_result(state, bt) {
          Ok(next_bt) => next_bt
          Err(e) => return error(e)
        }
        let next_catches = match self.rub_walk_catches_result(state, catches) {
          Ok(next_catches) => next_catches
          Err(e) => return error(e)
        }
        let catcher_state = rub_push_try_table_catcher(state, next_catches)
        let next_body = match
          self.rub_walk_texpr_result(
            rub_walk_nested_texpr_state(catcher_state, next_bt, true),
            body,
          ) {
          Ok(next_body) => next_body
          Err(e) => return error(e)
        }
        if next_bt == bt && next_catches == catches && next_body == body {
          instr
        } else {
          TInstr::try_table(next_bt, next_catches, next_body)
        }
      }
      _ => {
        let default_walk_start_ms = sl_trace_now_ms()
        let out = match self.walk_tinstruction_default(state, instr) {
          Ok((updated, _)) => updated
          Err(e) => return error(e)
        }
        rub_trace_log_slow_instr(
          trace_state,
          "walk:default",
          instr,
          sl_trace_elapsed_ms(default_walk_start_ms),
        )
        out
      }
    }
    rub_trace_log_slow_instr(
      trace_state,
      "walk:instr",
      instr,
      sl_trace_elapsed_ms(walked_start_ms),
    )
    let (after_throw_to_branch, changed_throw_to_branch) = rub_optimize_throw_to_branch(
      walked, state,
    )
    let (after_if, changed_if) = rub_optimize_if(after_throw_to_branch, options)
    let (after_br_table, changed_switch) = rub_optimize_br_table(after_if)
    let (after_br_if, changed_br_if) = rub_optimize_br_if(after_br_table)
    let (after_gc_branch, changed_gc_branch) = rub_optimize_gc_branch(
      after_br_if,
    )
    let (after_sink_block, changed_sink_block) = rub_optimize_single_if_void_block_wrapper(
      after_gc_branch,
      state.allow_list_splicing,
    )
    let (after_jump_thread, changed_jump_thread) = rub_optimize_jump_thread_block_wrapper(
      after_sink_block,
    )
    let (after_try_table_throw, changed_try_table_throw) = rub_optimize_try_table_throw_to_branch(
      after_jump_thread, state,
    )
    if changed_throw_to_branch ||
      changed_if ||
      changed_switch ||
      changed_br_if ||
      changed_gc_branch ||
      changed_sink_block ||
      changed_jump_thread ||
      changed_try_table_throw {
      match rub_trace_note_rewrite(trace_state, "rewrite:instr") {
        Ok(_) => ()
        Err(e) => return error(e)
      }
    }
    if changed_throw_to_branch ||
      changed_if ||
      changed_switch ||
      changed_br_if ||
      changed_gc_branch ||
      changed_sink_block ||
      changed_jump_thread ||
      changed_try_table_throw ||
      after_try_table_throw != instr {
      change(state, after_try_table_throw)
    } else {
      // Children were already traversed above; avoid default re-traversal.
      change(state, instr)
    }
  })
}

///|
fn rub_collect_tag_payload_types(mod : Module) -> Map[TagIdx, Array[ValType]] {
  let out : Map[TagIdx, Array[ValType]] = Map::new()
  let env = Env::new().with_module(mod)
  let mut total_tags = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, TagExternType(_)) => total_tags += 1
          _ => ()
        }
      }
    None => ()
  }
  match mod.tag_sec {
    Some(TagSec(tags)) => total_tags += tags.length()
    None => ()
  }
  let mut i = 0
  while i < total_tags {
    let tag = TagIdx::new(i.reinterpret_as_uint())
    match env.resolve_tag_functype(tag) {
      Some(FuncType(params, _)) => out.set(tag, params)
      None => ()
    }
    i += 1
  }
  out
}

///|
fn rub_append_scratch_locals_to_func(
  func : Func,
  scratch_locals : Array[ValType],
) -> Func {
  if scratch_locals.length() == 0 {
    return func
  }
  match func {
    TFunc(params, locals, body) => {
      let next_locals = locals.copy()
      for ty in scratch_locals {
        next_locals.push(ty)
      }
      Func::t_func(params, next_locals, body)
    }
    _ => func
  }
}

///|
fn rub_optimize_func_fixpoint(
  func : Func,
  options : OptimizeOptions,
  trace? : (String) -> Unit = rub_trace_noop,
  ordinal? : Int = 0,
  trace_all_funcs? : Bool = false,
  tag_payload_types? : Map[TagIdx, Array[ValType]] = Map::new(),
) -> Result[Func, String] {
  let log_func = rub_trace_should_log_func(ordinal, trace_all_funcs)
  match func {
    TFunc(_, locals, body) => {
      let start_top_instrs = body.instrs.length()
      let func_start_ms = sl_trace_now_ms()
      if log_func {
        trace(
          "func[\{ordinal}] phase=fixpoint:start locals=\{locals.length()} top_instrs=\{start_top_instrs}",
        )
        trace(
          "func[\{ordinal}] start locals=\{locals.length()} top_instrs=\{start_top_instrs}",
        )
      }
      let mut curr = func
      let mut rounds = 0
      let mut hit_round_limit = true
      let mut stalled_reason : String? = None
      while rounds < 16 {
        rounds += 1
        let round_start_top_instrs = match curr {
          TFunc(_, _, curr_body) => curr_body.instrs.length()
          _ => 0
        }
        let round_trace = rub_round_trace_state(
          log_func, trace, ordinal, rounds, func_start_ms,
        )
        rub_trace_emit_round_start(round_trace, round_start_top_instrs)
        let pass = remove_unused_brs_pass(
          options,
          trace_state=Some(round_trace),
        )
        let round_scratch_locals : Ref[Array[ValType]] = Ref::new([])
        let round_local_base_count = match curr {
          TFunc(params, locals, _) => params.length() + locals.length()
          _ => 0
        }
        if log_func {
          trace(
            "func[\{ordinal}] round[\{rounds}] phase=walk_func:start top_instrs=\{round_start_top_instrs} local_base=\{round_local_base_count}",
          )
        }
        match
          pass.walk_func(
            rub_walk_state(
              false,
              false,
              true,
              tag_payload_types~,
              local_base_count=round_local_base_count,
              scratch_locals=round_scratch_locals,
            ),
            curr,
          ) {
          Ok((next_func0, _)) => {
            let next_func = rub_append_scratch_locals_to_func(
              next_func0,
              round_scratch_locals.val,
            )
            let next_top_instrs = match next_func {
              TFunc(_, _, next_body) => next_body.instrs.length()
              _ => round_start_top_instrs
            }
            if log_func {
              trace(
                "func[\{ordinal}] round[\{rounds}] phase=walk_func:done elapsed_ms=\{sl_trace_elapsed_ms(round_trace.round_start_ms)} changed=\{next_func != curr} top_instrs=\{round_start_top_instrs}->\{next_top_instrs} scratch_locals=\{round_scratch_locals.val.length()} exprs=\{round_trace.expr_visits.val} instrs=\{round_trace.instr_visits.val} rewrites=\{round_trace.rewrites.val}",
              )
              trace(
                "func[\{ordinal}] round[\{rounds}] walk:done elapsed_ms=\{sl_trace_elapsed_ms(round_trace.round_start_ms)} changed=\{next_func != curr} top_instrs=\{round_start_top_instrs}->\{next_top_instrs} exprs=\{round_trace.expr_visits.val} instrs=\{round_trace.instr_visits.val} rewrites=\{round_trace.rewrites.val}",
              )
            }
            if round_trace.rewrites.val == 0 {
              curr = next_func
              hit_round_limit = false
              stalled_reason = Some("no_rewrites")
              break
            }
            if next_func == curr {
              hit_round_limit = false
              break
            }
            curr = next_func
          }
          Err(e) => {
            if e == RUB_NO_PROGRESS_TIMEOUT {
              if log_func {
                trace(
                  "func[\{ordinal}] round[\{rounds}] phase=walk_func:stalled reason=no_progress_timeout elapsed_ms=\{sl_trace_elapsed_ms(round_trace.round_start_ms)} exprs=\{round_trace.expr_visits.val} instrs=\{round_trace.instr_visits.val} rewrites=\{round_trace.rewrites.val}",
                )
              }
              hit_round_limit = false
              stalled_reason = Some("no_progress_timeout")
              break
            }
            if log_func {
              trace(
                "func[\{ordinal}] round[\{rounds}] phase=walk_func:error elapsed_ms=\{sl_trace_elapsed_ms(round_trace.round_start_ms)} exprs=\{round_trace.expr_visits.val} instrs=\{round_trace.instr_visits.val} rewrites=\{round_trace.rewrites.val} \{e}",
              )
              trace(
                "func[\{ordinal}] round[\{rounds}] walk:error elapsed_ms=\{sl_trace_elapsed_ms(round_trace.round_start_ms)} exprs=\{round_trace.expr_visits.val} instrs=\{round_trace.instr_visits.val} rewrites=\{round_trace.rewrites.val} \{e}",
              )
            }
            return Err(e)
          }
        }
      }
      if log_func {
        let end_top_instrs = match curr {
          TFunc(_, _, curr_body) => curr_body.instrs.length()
          _ => start_top_instrs
        }
        trace(
          "func[\{ordinal}] phase=fixpoint:done elapsed_ms=\{sl_trace_elapsed_ms(func_start_ms)} changed=\{curr != func} rounds=\{rounds} top_instrs=\{start_top_instrs}->\{end_top_instrs} locals=\{locals.length()}",
        )
        trace(
          "func[\{ordinal}] done elapsed_ms=\{sl_trace_elapsed_ms(func_start_ms)} changed=\{curr != func} rounds=\{rounds} top_instrs=\{start_top_instrs}->\{end_top_instrs} locals=\{locals.length()} round_limit_hit=\{hit_round_limit}",
        )
        match stalled_reason {
          Some(reason) =>
            trace(
              "func[\{ordinal}] stalled reason=\{reason} rounds=\{rounds} top_instrs=\{end_top_instrs}",
            )
          None =>
            if hit_round_limit {
              trace(
                "func[\{ordinal}] stalled reason=round_limit rounds=\{rounds} top_instrs=\{end_top_instrs}",
              )
            }
        }
      }
      Ok(curr)
    }
    _ => {
      if log_func {
        trace("func[\{ordinal}] skip non-typed-func")
      }
      Ok(func)
    }
  }
}

///|
fn rub_refinalize_changed_func(func : Func, mod : Module) -> Func {
  match func {
    TFunc(params, locals, body) => {
      let env = Env::new()
        .with_module(mod)
        .with_locals(FunctionLocals::new(params, locals).all_locals())
      let next_body = mb_refinalize_texpr(body, env)
      if next_body == body {
        func
      } else {
        Func::t_func(params, locals, next_body)
      }
    }
    _ => func
  }
}

///|
fn rub_validate_remove_unused_brs_output(mod : Module) -> Result[Unit, String] {
  match validate_module(mod) {
    Ok(_) => Ok(())
    Err(e) => Err("\{e}")
  }
}

///|
fn remove_unused_brs(
  mod : Module,
  options? : OptimizeOptions = OptimizeOptions::new(),
  trace? : (String) -> Unit = rub_trace_noop,
  trace_all_funcs? : Bool = false,
  validate_output? : (Module) -> Result[Unit, String] = rub_validate_remove_unused_brs_output,
  fallback_to_input_on_validation_failure? : Bool = true,
) -> Result[Module, String] {
  let pass_start_ms = sl_trace_now_ms()
  let collect_tags_start_ms = sl_trace_now_ms()
  trace("phase=module:collect_tag_payload_types:start")
  let tag_payload_types = rub_collect_tag_payload_types(mod)
  trace(
    "phase=module:collect_tag_payload_types:done elapsed_ms=\{sl_trace_elapsed_ms(collect_tags_start_ms)} tags=\{tag_payload_types.length()}",
  )
  let next_ordinal = Ref::new(0)
  trace("phase=module:walk_funcs:start")
  let walk_start_ms = sl_trace_now_ms()
  let pass = ModuleTransformer::new().on_func_evt(fn(_, state, func) {
    next_ordinal.val += 1
    let ordinal = next_ordinal.val
    let log_func = rub_trace_should_log_func(ordinal, trace_all_funcs)
    if log_func {
      trace("func[\{ordinal}] phase=function_pipeline:start")
    }
    match
      rub_optimize_func_fixpoint(
        func,
        options,
        trace~,
        ordinal~,
        trace_all_funcs~,
        tag_payload_types~,
      ) {
      Ok(next_func) => {
        if log_func {
          trace(
            "func[\{ordinal}] phase=function_pipeline:fixpoint_done changed=\{next_func != func}",
          )
        }
        let finalized_func = if next_func == func {
          if log_func {
            trace("func[\{ordinal}] phase=refinalize:skip reason=unchanged")
          }
          next_func
        } else {
          let refinalize_start_ms = sl_trace_now_ms()
          if log_func {
            trace("func[\{ordinal}] phase=refinalize:start")
          }
          let finalized = rub_refinalize_changed_func(next_func, mod)
          if log_func {
            trace(
              "func[\{ordinal}] phase=refinalize:done elapsed_ms=\{sl_trace_elapsed_ms(refinalize_start_ms)} changed=\{finalized != next_func}",
            )
          }
          finalized
        }
        if log_func {
          trace("func[\{ordinal}] phase=function_pipeline:done")
        }
        if finalized_func == func {
          unchanged()
        } else {
          change(state, finalized_func)
        }
      }
      Err(e) => {
        if log_func {
          trace("func[\{ordinal}] phase=function_pipeline:error \{e}")
        }
        error(e)
      }
    }
  })
  let out = match pass.walk_module(rub_walk_state(false, false, true), mod) {
    Ok((out, _)) => out
    Err(e) => return Err(e)
  }
  trace(
    "phase=module:walk_funcs:done elapsed_ms=\{sl_trace_elapsed_ms(walk_start_ms)} funcs=\{next_ordinal.val} changed=\{out != mod}",
  )
  let final_out = if out == mod {
    trace("phase=module:validate_output:skip reason=unchanged")
    out
  } else {
    let validate_start_ms = sl_trace_now_ms()
    trace("phase=module:validate_output:start")
    match validate_output(out) {
      Ok(_) => {
        trace(
          "phase=module:validate_output:done elapsed_ms=\{sl_trace_elapsed_ms(validate_start_ms)}",
        )
        out
      }
      Err(e) => {
        trace(
          "phase=module:validate_output:failed elapsed_ms=\{sl_trace_elapsed_ms(validate_start_ms)} \{e}",
        )
        if fallback_to_input_on_validation_failure {
          trace(
            "phase=module:validate_output:fallback_to_input reason=validation_failure",
          )
          mod
        } else {
          trace(
            "phase=module:validate_output:keeping_rewritten_output reason=fallback_disabled",
          )
          out
        }
      }
    }
  }
  trace(
    "phase=module:done elapsed_ms=\{sl_trace_elapsed_ms(pass_start_ms)} funcs=\{next_ordinal.val} changed=\{final_out != mod}",
  )
  Ok(final_out)
}

///|
fn rub_run(
  mod : Module,
  options? : OptimizeOptions = OptimizeOptions::new(),
) -> Module {
  match remove_unused_brs(mod, options~) {
    Ok(next_mod) => next_mod
    Err(e) => abort("remove_unused_brs failed: \{e}")
  }
}

///|
fn rub_single_func(mod : Module) -> Func {
  match mod.code_sec {
    Some(CodeSec([func])) => func
    _ => abort("expected exactly one function")
  }
}

///|
fn rub_single_typed_func_module(
  params : Array[ValType],
  results : Array[ValType],
  body : TExpr,
  locals? : Array[ValType] = [],
) -> Module {
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(SubType::comp_type(CompType::func(params, results))),
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  .with_code_sec(CodeSec::new([Func::t_func(params, locals, body)]))
}

///|
fn rub_single_void_func_module(
  params : Array[ValType],
  body : TExpr,
  locals? : Array[ValType] = [],
) -> Module {
  rub_single_typed_func_module(params, [], body, locals~)
}

///|
fn rub_single_void_func_module_with_tags(
  params : Array[ValType],
  body : TExpr,
  tag_params : Array[Array[ValType]],
  locals? : Array[ValType] = [],
) -> Module {
  let types : Array[RecType] = [
    RecType::new(SubType::comp_type(CompType::func(params, []))),
  ]
  let tags : Array[TagType] = []
  for param_types in tag_params {
    types.push(
      RecType::new(SubType::comp_type(CompType::func(param_types, []))),
    )
    tags.push(
      TagType::new(TypeIdx::new((types.length() - 1).reinterpret_as_uint())),
    )
  }
  Module::new()
  .with_type_sec(TypeSec::new(types))
  .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  .with_code_sec(CodeSec::new([Func::t_func(params, locals, body)]))
  .with_tag_sec(TagSec::new(tags))
}

///|
fn rub_assert_valid_module(mod : Module) -> Unit {
  match validate_module(mod) {
    Ok(_) => ()
    Err(e) => abort("expected module to validate: \{e}")
  }
}

///|
test "remove_unused_brs falls back to input when rewritten output fails validation" {
  let trace_logs : Array[String] = []
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([TInstr::br(LabelIdx::new(0), [])]),
    ),
  ])
  let mod = rub_single_void_func_module([], body)
  let out = match
    remove_unused_brs(mod, trace=fn(msg) { trace_logs.push(msg) }, validate_output=fn(
      next,
    ) {
      if next == mod {
        Ok(())
      } else {
        Err("synthetic validation failure")
      }
    }) {
    Ok(next_mod) => next_mod
    Err(e) => fail("unexpected remove_unused_brs error: \{e}")
  }
  assert_eq(out, mod)
  let mut saw_validation_failure = false
  for msg in trace_logs {
    if msg.contains("phase=module:validate_output:failed") {
      saw_validation_failure = true
    }
  }
  assert_true(saw_validation_failure)
}

///|
test "remove_unused_brs returns rewritten output when fallback is disabled and validation fails" {
  let trace_logs : Array[String] = []
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([TInstr::br(LabelIdx::new(0), [])]),
    ),
  ])
  let mod = rub_single_void_func_module([], body)
  let out = match
    remove_unused_brs(
      mod,
      trace=fn(msg) { trace_logs.push(msg) },
      validate_output=fn(next) {
        if next == mod {
          Ok(())
        } else {
          Err("synthetic validation failure")
        }
      },
      fallback_to_input_on_validation_failure=false,
    ) {
    Ok(next_mod) => next_mod
    Err(e) => fail("unexpected remove_unused_brs error: \{e}")
  }
  assert_true(out != mod)
  let mut saw_validation_failure = false
  for msg in trace_logs {
    if msg.contains("phase=module:validate_output:failed") {
      saw_validation_failure = true
    }
  }
  assert_true(saw_validation_failure)
}

///|
test "remove_unused_brs removes trailing br 0 in block" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::drop(TInstr::i32_const(I32(1))),
        TInstr::br(LabelIdx::new(0), []),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TDrop(
                      { kind: TInstrKind::TI32Const(I32(1)), .. }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected trailing br 0 to be removed")
  }
}

///|
test "remove_unused_brs keeps trailing br 0 when it clears ambient stack values" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(31856)),
        TInstr::br(LabelIdx::new(0), []),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                  { kind: TInstrKind::TI32Const(I32(31856)), .. },
                  { kind: TInstrKind::TBr(label, []), .. },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(label, LabelIdx::new(0))
    _ =>
      fail("expected trailing br 0 to remain when it clears stack-fed values")
  }
}

///|
test "remove_unused_brs keeps trailing br 0 when block prefix is unreachable" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::unreachable_(),
        TInstr::i32_const(I32(32384)),
        TInstr::br(LabelIdx::new(0), []),
      ]),
    ),
    TInstr::return_([]),
  ])
  let mod = rub_single_void_func_module([], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(_, _, body_expr) => {
      if body_expr.instrs.length() == 0 {
        fail(
          "expected output function body to retain a block with trailing br 0",
        )
      }
      match body_expr.instrs[0].kind {
        TInstrKind::TBlock(
          _,
          {
            instrs: [
              { kind: TInstrKind::TUnreachable, .. },
              { kind: TInstrKind::TI32Const(I32(32384)), .. },
              { kind: TInstrKind::TBr(label, []), .. },
            ],
            ..,
          }
        ) => assert_eq(label, LabelIdx::new(0))
        _ =>
          fail(
            "expected first instruction block to retain trailing br 0 after unreachable prefix",
          )
      }
    }
    _ =>
      fail(
        "expected trailing br 0 to remain when preceding block flow is unreachable",
      )
  }
}

///|
test "remove_unused_brs keeps trailing br 0 in loop bodies" {
  let body = TExpr::new([
    TInstr::loop_(
      BlockType::void_(),
      TExpr::new([TInstr::br(LabelIdx::new(0), [])]),
    ),
  ])
  let mod = rub_single_void_func_module([], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TLoop(
              _,
              { instrs: [{ kind: TInstrKind::TBr(label, []), .. }], .. }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(label, LabelIdx::new(0))
    _ => fail("expected loop-tail br 0 to remain intact")
  }
}

///|
test "remove_unused_brs forwards trailing br value in block" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::val_type(ValType::i32()),
      TExpr::new([TInstr::br(LabelIdx::new(0), [TInstr::i32_const(I32(7))])]),
    ),
  ])
  let mod = rub_single_typed_func_module([], [ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              { instrs: [{ kind: TInstrKind::TI32Const(I32(7)), .. }], .. }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected trailing br value to be forwarded")
  }
}

///|
test "remove_unused_brs trims trailing nops from block body" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::drop(TInstr::i32_const(I32(1))),
        TInstr::nop(),
        TInstr::nop(),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TDrop(
                      { kind: TInstrKind::TI32Const(I32(1)), .. }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected trailing nops to be trimmed")
  }
}

///|
test "remove_unused_brs turns one-armed if with break into br_if" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::if_(
          BlockType::void_(),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([TInstr::br(LabelIdx::new(1), [])]),
          None,
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBrIf(
                      label,
                      { kind: TInstrKind::TLocalGet(_), .. },
                      []
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(label, LabelIdx::new(0))
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TDrop(
              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TDrop(
                      { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected if( cond ) br to become br_if")
  }
}

///|
test "remove_unused_brs rejects one-armed if rewrite when break targets removed if scope" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::if_(
          BlockType::void_(),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([TInstr::br(LabelIdx::new(0), [])]),
          None,
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              { instrs: [{ kind: TInstrKind::TIf(_, _, _, None), .. }], .. }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected br 0 in one-armed if to remain structured")
  }
}

///|
test "remove_unused_brs combines nested one-armed if conditions" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::if_(
          BlockType::void_(),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(1)),
              TExpr::new([TInstr::br(LabelIdx::new(1), [])]),
              None,
            ),
          ]),
          None,
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32(), ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TIf(
                      _,
                      { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TDrop(
                              { kind: TInstrKind::TLocalGet(LocalIdx(1U)), .. }
                            ),
                            ..,
                          },
                        ],
                        ..,
                      },
                      None
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected nested one-armed if to reduce the rebased fallthrough branch to a dropped inner condition",
      )
  }
}

///|
test "remove_unused_brs rebases nested if body branches when hoisting" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::if_(
          BlockType::void_(),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(1)),
              TExpr::new([TInstr::br(LabelIdx::new(2), [])]),
              None,
            ),
          ]),
          None,
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32(), ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBrIf(
                      label,
                      {
                        kind: TInstrKind::TSelect(
                          _,
                          { kind: TInstrKind::TLocalGet(_), .. },
                          { kind: TInstrKind::TLocalGet(_), .. },
                          { kind: TInstrKind::TI32Const(I32(0)), .. }
                        ),
                        ..,
                      },
                      []
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(label, LabelIdx::new(0))
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TDrop(
              {
                kind: TInstrKind::TSelect(
                  _,
                  { kind: TInstrKind::TLocalGet(_), .. },
                  { kind: TInstrKind::TLocalGet(_), .. },
                  { kind: TInstrKind::TI32Const(I32(0)), .. }
                ),
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TDrop(
                      {
                        kind: TInstrKind::TSelect(
                          _,
                          { kind: TInstrKind::TLocalGet(_), .. },
                          { kind: TInstrKind::TLocalGet(_), .. },
                          { kind: TInstrKind::TI32Const(I32(0)), .. }
                        ),
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected nested-if hoist to rebase the inner branch target")
  }
}

///|
test "remove_unused_brs trims trailing br_table defaults and simplifies" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::br_table(
          [LabelIdx::new(0), LabelIdx::new(1), LabelIdx::new(1)],
          LabelIdx::new(1),
          TInstr::local_get(LocalIdx::new(0)),
          [],
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TIf(
                      _,
                      { kind: TInstrKind::TLocalGet(_), .. },
                      {
                        instrs: [{ kind: TInstrKind::TBr(then_label, []), .. }],
                        ..,
                      },
                      Some(
                        {
                          instrs: [
                            { kind: TInstrKind::TBr(else_label, []), .. },
                          ],
                          ..,
                        }
                      )
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => {
      assert_eq(then_label, LabelIdx::new(2))
      assert_eq(else_label, LabelIdx::new(1))
    }
    _ =>
      fail(
        "expected trailing-default br_table to simplify to rebased if branches",
      )
  }
}

///|
test "remove_unused_brs rebases default-only br_table wrapper labels" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([
            TInstr::br_table(
              [],
              LabelIdx::new(1),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBlock(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TBlock(
                              _,
                              {
                                instrs: [
                                  { kind: TInstrKind::TDrop(_), .. },
                                  { kind: TInstrKind::TBr(label, []), .. },
                                ],
                                ..,
                              }
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(label, LabelIdx::new(2))
    _ =>
      fail(
        "expected default-only br_table wrapper to rebase outer branch depth",
      )
  }
}

///|
test "remove_unused_brs rewrites default-only br_table to drop+br" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::br_table(
          [],
          LabelIdx::new(0),
          TInstr::local_get(LocalIdx::new(0)),
          [],
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  { kind: TInstrKind::TBlock(_, { instrs: items, .. }), .. },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) =>
      match items {
        [{ kind: TInstrKind::TDrop(_), .. }]
        | [
          { kind: TInstrKind::TDrop(_), .. },
          { kind: TInstrKind::TBr(_, _), .. },
        ] => ()
        _ =>
          fail(
            "expected default-only br_table to rewrite to drop(cond) with optional br",
          )
      }
    _ =>
      fail(
        "expected default-only br_table to rewrite to nested block(drop(cond), br?)",
      )
  }
}

///|
test "remove_unused_brs rebases single-target br_table branch labels" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([
            TInstr::br_table(
              [LabelIdx::new(1)],
              LabelIdx::new(0),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBlock(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TIf(
                              _,
                              _,
                              {
                                instrs: [
                                  { kind: TInstrKind::TBr(then_label, []), .. },
                                ],
                                ..,
                              },
                              Some(
                                {
                                  instrs: [
                                    {
                                      kind: TInstrKind::TBr(else_label, []),
                                      ..,
                                    },
                                  ],
                                  ..,
                                }
                              )
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => {
      assert_eq(then_label, LabelIdx::new(1))
      assert_eq(else_label, LabelIdx::new(2))
    }
    _ =>
      fail(
        "expected single-target br_table rewrite to rebase both branch labels",
      )
  }
}

///|
test "remove_unused_brs rewrites single-target br_table to if+brs" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::br_table(
          [LabelIdx::new(0)],
          LabelIdx::new(0),
          TInstr::local_get(LocalIdx::new(0)),
          [],
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [{ kind: TInstrKind::TBlock(_, { instrs: items, .. }), .. }],
        ..,
      }
    ) =>
      match items {
        [{ kind: TInstrKind::TIf(_, _, _, _), .. }]
        | [{ kind: TInstrKind::TDrop(_), .. }]
        | [{ kind: TInstrKind::TBlock(_, _), .. }] => ()
        _ => fail("expected single-target br_table to be simplified")
      }
    _ => fail("expected single-target br_table to become if")
  }
}

///|
test "remove_unused_brs folds constant-index br_table to direct br target" {
  let instr = TInstr::br_table(
    [LabelIdx::new(2), LabelIdx::new(1)],
    LabelIdx::new(0),
    TInstr::i32_const(I32(1)),
    [],
  )
  let (out, changed) = rub_optimize_br_table(instr)
  assert_true(changed)
  match out.kind {
    TInstrKind::TBr(label, []) => assert_eq(label, LabelIdx::new(1))
    _ => fail("expected constant-index br_table to fold to direct br target")
  }
}

///|
test "remove_unused_brs folds out-of-range constant-index br_table to default br" {
  let instr = TInstr::br_table(
    [LabelIdx::new(2), LabelIdx::new(1)],
    LabelIdx::new(0),
    TInstr::i32_const(I32(-1)),
    [],
  )
  let (out, changed) = rub_optimize_br_table(instr)
  assert_true(changed)
  match out.kind {
    TInstrKind::TBr(label, []) => assert_eq(label, LabelIdx::new(0))
    _ =>
      fail(
        "expected out-of-range constant-index br_table to fold to default br",
      )
  }
}

///|
test "remove_unused_brs rewrites single-target br_table with values when reorderable" {
  let instr = TInstr::br_table(
    [LabelIdx::new(1)],
    LabelIdx::new(1),
    TInstr::local_get(LocalIdx::new(0)),
    [TInstr::i32_const(I32(7))],
  )
  let (out, changed) = rub_optimize_br_table(instr)
  assert_true(changed)
  match out.kind {
    TInstrKind::TBlock(
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TDrop(
              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. }
            ),
            ..,
          },
          {
            kind: TInstrKind::TBr(
              label,
              [{ kind: TInstrKind::TI32Const(I32(7)), .. }]
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(label, LabelIdx::new(2))
    _ =>
      fail(
        "expected single-target br_table with values to rewrite to drop(cond)+br",
      )
  }
}

///|
test "remove_unused_brs keeps single-target br_table with values when reorder is unsafe" {
  let instr = TInstr::br_table(
    [LabelIdx::new(1)],
    LabelIdx::new(1),
    TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(1))),
    [TInstr::local_get(LocalIdx::new(0))],
  )
  let (out, changed) = rub_optimize_br_table(instr)
  assert_true(changed)
  match out.kind {
    TInstrKind::TBrTable(_, _, _, _) => ()
    _ =>
      fail(
        "expected unsafe-reorder single-target br_table with values to remain a br_table",
      )
  }
}

///|
test "remove_unused_brs folds dropped br_on_null with ref.null to br" {
  let instr = TInstr::drop(
    TInstr::br_on_null(
      LabelIdx::new(2),
      TInstr::ref_null(HeapType::abs(AbsHeapType::any())),
      [],
    ),
  )
  let (out, changed) = rub_optimize_gc_branch(instr)
  assert_true(changed)
  match out.kind {
    TInstrKind::TBr(label, []) => assert_eq(label, LabelIdx::new(2))
    _ => fail("expected dropped br_on_null(ref.null) to fold to direct br")
  }
}

///|
test "remove_unused_brs folds dropped br_on_non_null with ref.func to br" {
  let instr = TInstr::drop(
    TInstr::br_on_non_null(
      LabelIdx::new(1),
      TInstr::ref_func(FuncIdx::new(0)),
      [],
    ),
  )
  let (out, changed) = rub_optimize_gc_branch(instr)
  assert_true(changed)
  match out.kind {
    TInstrKind::TBr(label, []) => assert_eq(label, LabelIdx::new(1))
    _ => fail("expected dropped br_on_non_null(ref.func) to fold to direct br")
  }
}

///|
test "remove_unused_brs folds dropped br_on_null with ref.func to drop(ref)" {
  let ref_ = TInstr::ref_func(FuncIdx::new(0))
  let instr = TInstr::drop(TInstr::br_on_null(LabelIdx::new(1), ref_, []))
  let (out, changed) = rub_optimize_gc_branch(instr)
  assert_true(changed)
  match out.kind {
    TInstrKind::TDrop({ kind: TInstrKind::TRefFunc(FuncIdx(0U)), .. }) => ()
    _ => fail("expected dropped br_on_null(ref.func) to fold to drop(ref.func)")
  }
}

///|
test "remove_unused_brs merges br_if followed by br to same target" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::br_if(LabelIdx::new(0), TInstr::local_get(LocalIdx::new(0)), []),
        TInstr::br(LabelIdx::new(0), []),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBrIf(
                      label,
                      { kind: TInstrKind::TLocalGet(_), .. },
                      []
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(label, LabelIdx::new(0))
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TDrop(
              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TDrop(
                      { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail("expected br_if + br to same target to simplify to a single br_if")
  }
}

///|
test "remove_unused_brs loop optimization inverts tail br_if + br" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::br_if(
              LabelIdx::new(1),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
            TInstr::br(LabelIdx::new(0), []),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TBrIf(
                              loop_label,
                              {
                                kind: TInstrKind::TUnary(
                                  I32EqzOp,
                                  { kind: TInstrKind::TLocalGet(_), .. }
                                ),
                                ..,
                              },
                              []
                            ),
                            ..,
                          },
                          { kind: TInstrKind::TBr(exit_label, []), .. },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => {
      assert_eq(loop_label, LabelIdx::new(0))
      assert_eq(exit_label, LabelIdx::new(1))
    }
    _ =>
      fail(
        "expected loop-tail br_if+br pattern to invert condition and retarget loop break",
      )
  }
}

///|
test "remove_unused_brs loop optimization inverts tail br_if + nop + br" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::br_if(
              LabelIdx::new(1),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
            TInstr::nop(),
            TInstr::br(LabelIdx::new(0), []),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TBrIf(
                              loop_label,
                              {
                                kind: TInstrKind::TUnary(
                                  I32EqzOp,
                                  { kind: TInstrKind::TLocalGet(_), .. }
                                ),
                                ..,
                              },
                              []
                            ),
                            ..,
                          },
                          { kind: TInstrKind::TNop, .. },
                          { kind: TInstrKind::TBr(exit_label, []), .. },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => {
      assert_eq(loop_label, LabelIdx::new(0))
      assert_eq(exit_label, LabelIdx::new(1))
    }
    _ =>
      fail(
        "expected loop-tail br_if+nop+br pattern to invert condition and retarget loop break",
      )
  }
}

///|
test "remove_unused_brs loop optimization drops redundant tail br_if 0 before nop + br" {
  let body = TExpr::new([
    TInstr::loop_(
      BlockType::void_(),
      TExpr::new([
        TInstr::br_if(LabelIdx::new(0), TInstr::local_get(LocalIdx::new(0)), []),
        TInstr::nop(),
        TInstr::br(LabelIdx::new(0), []),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TLoop(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TDrop(
                      { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. }
                    ),
                    ..,
                  },
                  { kind: TInstrKind::TNop, .. },
                  { kind: TInstrKind::TBr(LabelIdx(0U), []), .. },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected redundant loop-tail br_if 0 before nop + br to canonicalize to drop(cond)",
      )
  }
}

///|
test "remove_unused_brs loop optimization drops redundant tail br_if 0 before nop + br with prefix" {
  let body = TExpr::new([
    TInstr::loop_(
      BlockType::void_(),
      TExpr::new([
        TInstr::drop(TInstr::i32_const(I32(8))),
        TInstr::br_if(LabelIdx::new(0), TInstr::local_get(LocalIdx::new(0)), []),
        TInstr::nop(),
        TInstr::br(LabelIdx::new(0), []),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TLoop(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TDrop(
                      { kind: TInstrKind::TI32Const(I32(8)), .. }
                    ),
                    ..,
                  },
                  {
                    kind: TInstrKind::TDrop(
                      { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. }
                    ),
                    ..,
                  },
                  { kind: TInstrKind::TNop, .. },
                  { kind: TInstrKind::TBr(LabelIdx(0U), []), .. },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected redundant tail br_if 0 before nop + br to canonicalize even with a loop prefix",
      )
  }
}

///|
test "remove_unused_brs loop optimization lowers tail if-else branch pair" {
  let body = TExpr::new([
    TInstr::loop_(
      BlockType::void_(),
      TExpr::new([
        TInstr::if_(
          BlockType::void_(),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([TInstr::br(LabelIdx::new(2), [])]),
          Some(TExpr::new([TInstr::br(LabelIdx::new(1), [])])),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TLoop(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBrIf(
                      LabelIdx(0U),
                      { kind: TInstrKind::TUnary(I32EqzOp, _), .. },
                      []
                    ),
                    ..,
                  },
                  { kind: TInstrKind::TBr(label, []), .. },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(label, LabelIdx::new(1))
    _ =>
      fail(
        "expected loop-tail if(br exit, br loop) to lower to inverted br_if + exit br",
      )
  }
}

///|
test "remove_unused_brs loop optimization drops redundant continue arm after tail if-else" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([TInstr::br(LabelIdx::new(2), [])]),
              Some(TExpr::new([TInstr::br(LabelIdx::new(1), [])])),
            ),
            TInstr::br(LabelIdx::new(0), []),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TBrIf(
                              LabelIdx(0U),
                              {
                                kind: TInstrKind::TUnary(
                                  I32EqzOp,
                                  {
                                    kind: TInstrKind::TLocalGet(LocalIdx(0U)),
                                    ..,
                                  }
                                ),
                                ..,
                              },
                              []
                            ),
                            ..,
                          },
                          { kind: TInstrKind::TBr(LabelIdx(1U), []), .. },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected loop-tail if(br exit, br loop); br loop to reach canonical inverted br_if + exit br form",
      )
  }
}

///|
test "remove_unused_brs loop optimization drops redundant continue arm after tail if-else with intervening nop" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([TInstr::br(LabelIdx::new(2), [])]),
              Some(TExpr::new([TInstr::br(LabelIdx::new(1), [])])),
            ),
            TInstr::nop(),
            TInstr::br(LabelIdx::new(0), []),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TBrIf(
                              LabelIdx(0U),
                              {
                                kind: TInstrKind::TUnary(
                                  I32EqzOp,
                                  {
                                    kind: TInstrKind::TLocalGet(LocalIdx(0U)),
                                    ..,
                                  }
                                ),
                                ..,
                              },
                              []
                            ),
                            ..,
                          },
                          { kind: TInstrKind::TNop, .. },
                          { kind: TInstrKind::TBr(LabelIdx(1U), []), .. },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected loop-tail if(br exit, br loop); nop; br loop to reach canonical inverted br_if + nop + exit br form",
      )
  }
}

///|
test "remove_unused_brs loop optimization inverts redundant continue arm after tail if-else" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([TInstr::br(LabelIdx::new(1), [])]),
              Some(TExpr::new([TInstr::br(LabelIdx::new(2), [])])),
            ),
            TInstr::br(LabelIdx::new(0), []),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TBrIf(
                              LabelIdx(0U),
                              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                              []
                            ),
                            ..,
                          },
                          { kind: TInstrKind::TBr(LabelIdx(1U), []), .. },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected loop-tail if(br loop, br exit); br loop to reach canonical br_if + exit br form",
      )
  }
}

///|
test "remove_unused_brs loop optimization lowers one-armed tail if dead end into if-else" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([TInstr::br(LabelIdx::new(2), [])]),
              None,
            ),
            TInstr::drop(TInstr::i32_const(I32(1))),
            TInstr::br(LabelIdx::new(0), []),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TIf(
                              _,
                              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                              {
                                instrs: [
                                  {
                                    kind: TInstrKind::TBr(LabelIdx(2U), []),
                                    ..,
                                  },
                                ],
                                ..,
                              },
                              Some(
                                {
                                  instrs: [
                                    {
                                      kind: TInstrKind::TDrop(
                                        {
                                          kind: TInstrKind::TI32Const(I32(1)),
                                          ..,
                                        }
                                      ),
                                      ..,
                                    },
                                    {
                                      kind: TInstrKind::TBr(LabelIdx(1U), []),
                                      ..,
                                    },
                                  ],
                                  ..,
                                }
                              )
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected one-armed loop-tail if dead end to become if(cond, br exit, tail+br loop)",
      )
  }
}

///|
test "remove_unused_brs loop optimization sinks trailing loop tail into reachable if-else arm" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([TInstr::br(LabelIdx::new(2), [])]),
              Some(TExpr::new([TInstr::drop(TInstr::i32_const(I32(1)))])),
            ),
            TInstr::drop(TInstr::i32_const(I32(2))),
            TInstr::br(LabelIdx::new(0), []),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TIf(
                              _,
                              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                              {
                                instrs: [
                                  {
                                    kind: TInstrKind::TBr(LabelIdx(2U), []),
                                    ..,
                                  },
                                ],
                                ..,
                              },
                              Some(
                                {
                                  instrs: [
                                    {
                                      kind: TInstrKind::TDrop(
                                        {
                                          kind: TInstrKind::TI32Const(I32(1)),
                                          ..,
                                        }
                                      ),
                                      ..,
                                    },
                                    {
                                      kind: TInstrKind::TDrop(
                                        {
                                          kind: TInstrKind::TI32Const(I32(2)),
                                          ..,
                                        }
                                      ),
                                      ..,
                                    },
                                    {
                                      kind: TInstrKind::TBr(LabelIdx(1U), []),
                                      ..,
                                    },
                                  ],
                                  ..,
                                }
                              )
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected reachable if-else arm to absorb trailing loop tail and rebased br 0",
      )
  }
}

///|
test "remove_unused_brs loop optimization sinks trailing loop tail into reachable then arm" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([TInstr::drop(TInstr::i32_const(I32(1)))]),
              Some(TExpr::new([TInstr::br(LabelIdx::new(2), [])])),
            ),
            TInstr::drop(TInstr::i32_const(I32(2))),
            TInstr::br(LabelIdx::new(0), []),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TIf(
                              _,
                              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                              {
                                instrs: [
                                  {
                                    kind: TInstrKind::TDrop(
                                      {
                                        kind: TInstrKind::TI32Const(I32(1)),
                                        ..,
                                      }
                                    ),
                                    ..,
                                  },
                                  {
                                    kind: TInstrKind::TDrop(
                                      {
                                        kind: TInstrKind::TI32Const(I32(2)),
                                        ..,
                                      }
                                    ),
                                    ..,
                                  },
                                  {
                                    kind: TInstrKind::TBr(LabelIdx(1U), []),
                                    ..,
                                  },
                                ],
                                ..,
                              },
                              Some(
                                {
                                  instrs: [
                                    {
                                      kind: TInstrKind::TBr(LabelIdx(2U), []),
                                      ..,
                                    },
                                  ],
                                  ..,
                                }
                              )
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected reachable then arm case to absorb the loop tail into the reachable arm",
      )
  }
}

///|
test "remove_unused_brs loop optimization sinks trailing loop tail past one-armed unreachable if" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([TInstr::unreachable_()]),
              None,
            ),
            TInstr::drop(TInstr::i32_const(I32(2))),
            TInstr::br(LabelIdx::new(0), []),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TIf(
                              _,
                              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                              {
                                instrs: [{ kind: TInstrKind::TUnreachable, .. }],
                                ..,
                              },
                              Some(
                                {
                                  instrs: [
                                    {
                                      kind: TInstrKind::TDrop(
                                        {
                                          kind: TInstrKind::TI32Const(I32(2)),
                                          ..,
                                        }
                                      ),
                                      ..,
                                    },
                                    {
                                      kind: TInstrKind::TBr(LabelIdx(1U), []),
                                      ..,
                                    },
                                  ],
                                  ..,
                                }
                              )
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected one-armed unreachable if to absorb the trailing loop tail into a synthesized else arm",
      )
  }
}

///|
test "remove_unused_brs loop optimization sinks trailing loop tail past unreachable else arm" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([TInstr::drop(TInstr::i32_const(I32(1)))]),
              Some(TExpr::new([TInstr::unreachable_()])),
            ),
            TInstr::drop(TInstr::i32_const(I32(2))),
            TInstr::br(LabelIdx::new(0), []),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TIf(
                              _,
                              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                              {
                                instrs: [
                                  {
                                    kind: TInstrKind::TDrop(
                                      {
                                        kind: TInstrKind::TI32Const(I32(1)),
                                        ..,
                                      }
                                    ),
                                    ..,
                                  },
                                  {
                                    kind: TInstrKind::TDrop(
                                      {
                                        kind: TInstrKind::TI32Const(I32(2)),
                                        ..,
                                      }
                                    ),
                                    ..,
                                  },
                                  {
                                    kind: TInstrKind::TBr(LabelIdx(1U), []),
                                    ..,
                                  },
                                ],
                                ..,
                              },
                              Some(
                                {
                                  instrs: [
                                    { kind: TInstrKind::TUnreachable, .. },
                                  ],
                                  ..,
                                }
                              )
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected unreachable else arm to absorb the trailing loop tail into the reachable arm",
      )
  }
}

///|
test "remove_unused_brs loop optimization sinks trailing loop tail past one-armed return if" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([TInstr::return_([])]),
              None,
            ),
            TInstr::drop(TInstr::i32_const(I32(2))),
            TInstr::br(LabelIdx::new(0), []),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TIf(
                              _,
                              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                              {
                                instrs: [{ kind: TInstrKind::TReturn([]), .. }],
                                ..,
                              },
                              Some(
                                {
                                  instrs: [
                                    {
                                      kind: TInstrKind::TDrop(
                                        {
                                          kind: TInstrKind::TI32Const(I32(2)),
                                          ..,
                                        }
                                      ),
                                      ..,
                                    },
                                    {
                                      kind: TInstrKind::TBr(LabelIdx(1U), []),
                                      ..,
                                    },
                                  ],
                                  ..,
                                }
                              )
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected one-armed return if to absorb the trailing loop tail into a synthesized else arm",
      )
  }
}

///|
test "remove_unused_brs loop optimization sinks trailing loop tail past return else arm" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([TInstr::drop(TInstr::i32_const(I32(1)))]),
              Some(TExpr::new([TInstr::return_([])])),
            ),
            TInstr::drop(TInstr::i32_const(I32(2))),
            TInstr::br(LabelIdx::new(0), []),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TIf(
                              _,
                              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                              {
                                instrs: [
                                  {
                                    kind: TInstrKind::TDrop(
                                      {
                                        kind: TInstrKind::TI32Const(I32(1)),
                                        ..,
                                      }
                                    ),
                                    ..,
                                  },
                                  {
                                    kind: TInstrKind::TDrop(
                                      {
                                        kind: TInstrKind::TI32Const(I32(2)),
                                        ..,
                                      }
                                    ),
                                    ..,
                                  },
                                  {
                                    kind: TInstrKind::TBr(LabelIdx(1U), []),
                                    ..,
                                  },
                                ],
                                ..,
                              },
                              Some(
                                {
                                  instrs: [
                                    { kind: TInstrKind::TReturn([]), .. },
                                  ],
                                  ..,
                                }
                              )
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected return else arm to absorb the trailing loop tail into the reachable arm",
      )
  }
}

///|
test "remove_unused_brs loop optimization sinks trailing loop tail past structured unreachable if" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([
                TInstr::if_(
                  BlockType::void_(),
                  TInstr::local_get(LocalIdx::new(1)),
                  TExpr::new([TInstr::unreachable_()]),
                  Some(TExpr::new([TInstr::unreachable_()])),
                ),
              ]),
              None,
            ),
            TInstr::drop(TInstr::i32_const(I32(2))),
            TInstr::br(LabelIdx::new(0), []),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32(), ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TIf(
                              _,
                              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                              {
                                instrs: [
                                  {
                                    kind: TInstrKind::TIf(
                                      _,
                                      {
                                        kind: TInstrKind::TLocalGet(
                                          LocalIdx(1U)
                                        ),
                                        ..,
                                      },
                                      {
                                        instrs: [
                                          { kind: TInstrKind::TUnreachable, .. },
                                        ],
                                        ..,
                                      },
                                      Some(
                                        {
                                          instrs: [
                                            {
                                              kind: TInstrKind::TUnreachable,
                                              ..,
                                            },
                                          ],
                                          ..,
                                        }
                                      )
                                    ),
                                    ..,
                                  },
                                ],
                                ..,
                              },
                              Some(
                                {
                                  instrs: [
                                    {
                                      kind: TInstrKind::TDrop(
                                        {
                                          kind: TInstrKind::TI32Const(I32(2)),
                                          ..,
                                        }
                                      ),
                                      ..,
                                    },
                                    {
                                      kind: TInstrKind::TBr(LabelIdx(1U), []),
                                      ..,
                                    },
                                  ],
                                  ..,
                                }
                              )
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected structured unreachable then arm to absorb the trailing loop tail into a synthesized else arm",
      )
  }
}

///|
test "remove_unused_brs loop optimization sinks trailing loop tail past structured return if" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([
                TInstr::if_(
                  BlockType::void_(),
                  TInstr::local_get(LocalIdx::new(1)),
                  TExpr::new([TInstr::return_([])]),
                  Some(TExpr::new([TInstr::return_([])])),
                ),
              ]),
              None,
            ),
            TInstr::drop(TInstr::i32_const(I32(2))),
            TInstr::br(LabelIdx::new(0), []),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32(), ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TIf(
                              _,
                              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                              {
                                instrs: [
                                  {
                                    kind: TInstrKind::TIf(
                                      _,
                                      {
                                        kind: TInstrKind::TLocalGet(
                                          LocalIdx(1U)
                                        ),
                                        ..,
                                      },
                                      {
                                        instrs: [
                                          { kind: TInstrKind::TReturn([]), .. },
                                        ],
                                        ..,
                                      },
                                      Some(
                                        {
                                          instrs: [
                                            {
                                              kind: TInstrKind::TReturn([]),
                                              ..,
                                            },
                                          ],
                                          ..,
                                        }
                                      )
                                    ),
                                    ..,
                                  },
                                ],
                                ..,
                              },
                              Some(
                                {
                                  instrs: [
                                    {
                                      kind: TInstrKind::TDrop(
                                        {
                                          kind: TInstrKind::TI32Const(I32(2)),
                                          ..,
                                        }
                                      ),
                                      ..,
                                    },
                                    {
                                      kind: TInstrKind::TBr(LabelIdx(1U), []),
                                      ..,
                                    },
                                  ],
                                  ..,
                                }
                              )
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected structured return then arm to absorb the trailing loop tail into a synthesized else arm",
      )
  }
}

///|
test "remove_unused_brs loop optimization sinks trailing loop tail past structured return else arm" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([TInstr::drop(TInstr::i32_const(I32(1)))]),
              Some(
                TExpr::new([
                  TInstr::if_(
                    BlockType::void_(),
                    TInstr::local_get(LocalIdx::new(1)),
                    TExpr::new([TInstr::return_([])]),
                    Some(TExpr::new([TInstr::return_([])])),
                  ),
                ]),
              ),
            ),
            TInstr::drop(TInstr::i32_const(I32(2))),
            TInstr::br(LabelIdx::new(0), []),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32(), ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TIf(
                              _,
                              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                              {
                                instrs: [
                                  {
                                    kind: TInstrKind::TDrop(
                                      {
                                        kind: TInstrKind::TI32Const(I32(1)),
                                        ..,
                                      }
                                    ),
                                    ..,
                                  },
                                  {
                                    kind: TInstrKind::TDrop(
                                      {
                                        kind: TInstrKind::TI32Const(I32(2)),
                                        ..,
                                      }
                                    ),
                                    ..,
                                  },
                                  {
                                    kind: TInstrKind::TBr(LabelIdx(1U), []),
                                    ..,
                                  },
                                ],
                                ..,
                              },
                              Some(
                                {
                                  instrs: [
                                    {
                                      kind: TInstrKind::TIf(
                                        _,
                                        {
                                          kind: TInstrKind::TLocalGet(
                                            LocalIdx(1U)
                                          ),
                                          ..,
                                        },
                                        {
                                          instrs: [
                                            {
                                              kind: TInstrKind::TReturn([]),
                                              ..,
                                            },
                                          ],
                                          ..,
                                        },
                                        Some(
                                          {
                                            instrs: [
                                              {
                                                kind: TInstrKind::TReturn([]),
                                                ..,
                                              },
                                            ],
                                            ..,
                                          }
                                        )
                                      ),
                                      ..,
                                    },
                                  ],
                                  ..,
                                }
                              )
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected structured return else arm to absorb the trailing loop tail into the reachable arm",
      )
  }
}

///|
test "remove_unused_brs loop optimization sinks trailing loop tail past mixed dead-end if" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([
                TInstr::if_(
                  BlockType::void_(),
                  TInstr::local_get(LocalIdx::new(1)),
                  TExpr::new([TInstr::unreachable_()]),
                  Some(TExpr::new([TInstr::return_([])])),
                ),
              ]),
              None,
            ),
            TInstr::drop(TInstr::i32_const(I32(2))),
            TInstr::br(LabelIdx::new(0), []),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32(), ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TIf(
                              _,
                              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                              _,
                              Some(
                                {
                                  instrs: [
                                    {
                                      kind: TInstrKind::TDrop(
                                        {
                                          kind: TInstrKind::TI32Const(I32(2)),
                                          ..,
                                        }
                                      ),
                                      ..,
                                    },
                                    {
                                      kind: TInstrKind::TBr(LabelIdx(1U), []),
                                      ..,
                                    },
                                  ],
                                  ..,
                                }
                              )
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected mixed dead-end then arm to absorb the trailing loop tail into a synthesized else arm",
      )
  }
}

///|
test "remove_unused_brs loop optimization sinks trailing loop tail past swapped mixed dead-end if" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([
                TInstr::if_(
                  BlockType::void_(),
                  TInstr::local_get(LocalIdx::new(1)),
                  TExpr::new([TInstr::return_([])]),
                  Some(TExpr::new([TInstr::unreachable_()])),
                ),
              ]),
              None,
            ),
            TInstr::drop(TInstr::i32_const(I32(2))),
            TInstr::br(LabelIdx::new(0), []),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32(), ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TIf(
                              _,
                              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                              _,
                              Some(
                                {
                                  instrs: [
                                    {
                                      kind: TInstrKind::TDrop(
                                        {
                                          kind: TInstrKind::TI32Const(I32(2)),
                                          ..,
                                        }
                                      ),
                                      ..,
                                    },
                                    {
                                      kind: TInstrKind::TBr(LabelIdx(1U), []),
                                      ..,
                                    },
                                  ],
                                  ..,
                                }
                              )
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected swapped mixed dead-end then arm to absorb the trailing loop tail into a synthesized else arm",
      )
  }
}

///|
test "remove_unused_brs loop optimization sinks trailing loop tail past mixed dead-end else arm" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([TInstr::drop(TInstr::i32_const(I32(1)))]),
              Some(
                TExpr::new([
                  TInstr::if_(
                    BlockType::void_(),
                    TInstr::local_get(LocalIdx::new(1)),
                    TExpr::new([TInstr::unreachable_()]),
                    Some(TExpr::new([TInstr::return_([])])),
                  ),
                ]),
              ),
            ),
            TInstr::drop(TInstr::i32_const(I32(2))),
            TInstr::br(LabelIdx::new(0), []),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32(), ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TIf(
                              _,
                              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                              {
                                instrs: [
                                  {
                                    kind: TInstrKind::TDrop(
                                      {
                                        kind: TInstrKind::TI32Const(I32(1)),
                                        ..,
                                      }
                                    ),
                                    ..,
                                  },
                                  {
                                    kind: TInstrKind::TDrop(
                                      {
                                        kind: TInstrKind::TI32Const(I32(2)),
                                        ..,
                                      }
                                    ),
                                    ..,
                                  },
                                  {
                                    kind: TInstrKind::TBr(LabelIdx(1U), []),
                                    ..,
                                  },
                                ],
                                ..,
                              },
                              Some(_)
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected mixed dead-end else arm to absorb the trailing loop tail into the reachable arm",
      )
  }
}

///|
test "remove_unused_brs loop optimization lowers non-adjacent tail br_if into if-else" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::br_if(
              LabelIdx::new(1),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
            TInstr::drop(TInstr::i32_const(I32(1))),
            TInstr::br(LabelIdx::new(0), []),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TIf(
                              _,
                              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                              {
                                instrs: [
                                  {
                                    kind: TInstrKind::TBr(LabelIdx(2U), []),
                                    ..,
                                  },
                                ],
                                ..,
                              },
                              Some(
                                {
                                  instrs: [
                                    {
                                      kind: TInstrKind::TDrop(
                                        {
                                          kind: TInstrKind::TI32Const(I32(1)),
                                          ..,
                                        }
                                      ),
                                      ..,
                                    },
                                    {
                                      kind: TInstrKind::TBr(LabelIdx(1U), []),
                                      ..,
                                    },
                                  ],
                                  ..,
                                }
                              )
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected non-adjacent loop-tail br_if to become if(cond, br exit, tail+br loop)",
      )
  }
}

///|
test "remove_unused_brs merges adjacent br_ifs in shrink mode" {
  let body = TExpr::new([
    TInstr::br_if(LabelIdx::new(0), TInstr::local_get(LocalIdx::new(0)), []),
    TInstr::br_if(LabelIdx::new(0), TInstr::local_get(LocalIdx::new(1)), []),
  ])
  let mod = rub_single_void_func_module([ValType::i32(), ValType::i32()], body)
  let out = rub_run(mod, options=OptimizeOptions::new(shrink_level=1))
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBrIf(
              _,
              { kind: TInstrKind::TBinary(I32OrOp, _, _), .. },
              []
            )
            | TInstrKind::TDrop(
              { kind: TInstrKind::TBinary(I32OrOp, _, _), .. }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBrIf(
              LabelIdx(0U),
              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
              []
            ),
            ..,
          },
          {
            kind: TInstrKind::TDrop(
              { kind: TInstrKind::TLocalGet(LocalIdx(1U)), .. }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected adjacent br_ifs to merge in shrink mode")
  }
}

///|
test "remove_unused_brs drops trailing br_if 0 in block" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::br_if(LabelIdx::new(0), TInstr::local_get(LocalIdx::new(0)), []),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TDrop(
                      { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected trailing br_if 0 in block to become drop(condition)")
  }
}

///|
test "remove_unused_brs drops trailing br_if 0 after prefix in block" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::drop(TInstr::i32_const(I32(1))),
        TInstr::br_if(LabelIdx::new(0), TInstr::local_get(LocalIdx::new(0)), []),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TDrop(
                      { kind: TInstrKind::TI32Const(I32(1)), .. }
                    ),
                    ..,
                  },
                  {
                    kind: TInstrKind::TDrop(
                      { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected trailing br_if 0 after a prefix in block to become drop(condition)",
      )
  }
}

///|
test "remove_unused_brs keeps trailing br_if 0 in loop body" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::br_if(
              LabelIdx::new(0),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TBrIf(
                              LabelIdx(0U),
                              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                              []
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected trailing br_if 0 in loop body to remain")
  }
}

///|
test "remove_unused_brs folds br_if with constant true condition" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::br_if(LabelIdx::new(0), rub_one_i32(), []),
        TInstr::i32_const(I32(2)),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  { kind: TInstrKind::TBr(label, []), .. },
                  { kind: TInstrKind::TUnreachable, .. },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(label, LabelIdx::new(0))
    _ => fail("expected br_if true to become br")
  }
}

///|
test "remove_unused_brs folds br_if with constant false condition" {
  let body = TExpr::new([TInstr::br_if(LabelIdx::new(0), rub_zero_i32(), [])])
  let mod = rub_single_void_func_module([], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TDrop({ kind: TInstrKind::TI32Const(I32(0)), .. }),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected br_if false to become drop(condition)")
  }
}

///|
test "remove_unused_brs folds br_if false with value into drops" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::br_if(LabelIdx::new(0), rub_zero_i32(), [
          TInstr::i32_const(I32(7)),
        ]),
      ]),
    ),
  ])
  let mod = rub_single_typed_func_module([], [], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBlock(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TDrop(
                              { kind: TInstrKind::TI32Const(I32(7)), .. }
                            ),
                            ..,
                          },
                          {
                            kind: TInstrKind::TDrop(
                              { kind: TInstrKind::TI32Const(I32(0)), .. }
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected br_if(false, value) to become drops in a void block")
  }
}

///|
test "remove_unused_brs rebases branch labels inside folded br_if false values" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::val_type(ValType::i32()),
      TExpr::new([
        TInstr::br_if(LabelIdx::new(0), rub_zero_i32(), [
          TInstr::block(
            BlockType::val_type(ValType::i32()),
            TExpr::new([
              TInstr::br(LabelIdx::new(1), [TInstr::i32_const(I32(7))]),
            ]),
          ),
        ]),
        TInstr::i32_const(I32(5)),
      ]),
    ),
  ])
  let mod = rub_single_typed_func_module([], [ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              ValTypeBlockType(_),
              {
                instrs: [
                  {
                    kind: TInstrKind::TBlock(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TDrop(
                              {
                                kind: TInstrKind::TBlock(
                                  _,
                                  {
                                    instrs: [
                                      {
                                        kind: TInstrKind::TBr(
                                          label,
                                          [
                                            {
                                              kind: TInstrKind::TI32Const(
                                                I32(7)
                                              ),
                                              ..,
                                            },
                                          ]
                                        ),
                                        ..,
                                      },
                                    ],
                                    ..,
                                  }
                                ),
                                ..,
                              }
                            ),
                            ..,
                          },
                          { kind: TInstrKind::TDrop(_), .. },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                  { kind: TInstrKind::TI32Const(I32(5)), .. },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(label, LabelIdx::new(2))
    _ =>
      fail(
        "expected folded br_if(false, [value]) wrapper to rebase labels inside the value subtree",
      )
  }
}

///|
test "remove_unused_brs removes redundant dropped br_if tail value copy" {
  let value = TInstr::i32_const(I32(9))
  let body = TExpr::new([
    TInstr::block(
      BlockType::val_type(ValType::i32()),
      TExpr::new([
        TInstr::drop(
          TInstr::br_if(LabelIdx::new(0), TInstr::local_get(LocalIdx::new(0)), [
            value,
          ]),
        ),
        value,
      ]),
    ),
  ])
  let mod = rub_single_typed_func_module(
    [ValType::i32()],
    [ValType::i32()],
    body,
  )
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TDrop(
                      { kind: TInstrKind::TLocalGet(_), .. }
                    ),
                    ..,
                  },
                  { kind: TInstrKind::TI32Const(I32(9)), .. },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected dropped br_if tail-value pattern to be optimized")
  }
}

///|
test "remove_unused_brs keeps redundant dropped br_if tail pattern in loops" {
  let value = TInstr::i32_const(I32(9))
  let body = TExpr::new([
    TInstr::loop_(
      BlockType::val_type(ValType::i32()),
      TExpr::new([
        TInstr::drop(
          TInstr::br_if(LabelIdx::new(0), TInstr::local_get(LocalIdx::new(0)), [
            value,
          ]),
        ),
        value,
      ]),
    ),
  ])
  let mod = rub_single_typed_func_module(
    [ValType::i32()],
    [ValType::i32()],
    body,
  )
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TLoop(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TDrop(
                      { kind: TInstrKind::TBrIf(label, _, [_]), .. }
                    ),
                    ..,
                  },
                  { kind: TInstrKind::TI32Const(I32(9)), .. },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(label, LabelIdx::new(0))
    _ => fail("expected loop-tail dropped br_if pattern to remain structured")
  }
}

///|
test "remove_unused_brs removes trailing return with no value in function body" {
  let body = TExpr::new([
    TInstr::drop(TInstr::i32_const(I32(1))),
    TInstr::return_([]),
  ])
  let mod = rub_single_void_func_module([], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TDrop({ kind: TInstrKind::TI32Const(I32(1)), .. }),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected trailing return to be removed")
  }
}

///|
test "remove_unused_brs rewrites if arm local.set + local.get tail to local.tee select" {
  let body = TExpr::new([
    TInstr::if_(
      BlockType::void_(),
      TInstr::local_get(LocalIdx::new(0)),
      TExpr::new([
        TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(11))),
      ]),
      Some(
        TExpr::new([
          TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(22))),
        ]),
      ),
    ),
    TInstr::local_get(LocalIdx::new(1)),
  ])
  let mod = rub_single_typed_func_module(
    [ValType::i32()],
    [ValType::i32()],
    body,
    locals=[ValType::i32()],
  )
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TLocalTee(
              LocalIdx(1U),
              {
                kind: TInstrKind::TSelect(
                  _,
                  { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                  { kind: TInstrKind::TI32Const(I32(11)), .. },
                  { kind: TInstrKind::TI32Const(I32(22)), .. }
                ),
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected if(local.set/local.set)+local.get tail to fold into local.tee(select)",
      )
  }
}

///|
test "remove_unused_brs keeps if arm local.set + local.get tail when arm value traps" {
  let body = TExpr::new([
    TInstr::if_(
      BlockType::void_(),
      TInstr::local_get(LocalIdx::new(0)),
      TExpr::new([
        TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(11))),
      ]),
      Some(
        TExpr::new([TInstr::local_set(LocalIdx::new(1), TInstr::unreachable_())]),
      ),
    ),
    TInstr::local_get(LocalIdx::new(1)),
  ])
  let mod = rub_single_typed_func_module(
    [ValType::i32()],
    [ValType::i32()],
    body,
    locals=[ValType::i32()],
  )
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          { kind: TInstrKind::TIf(VoidBlockType, _, _, Some(_)), .. },
          { kind: TInstrKind::TLocalGet(LocalIdx(1U)), .. },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected trapping if-arm local.set pattern to remain structured")
  }
}

///|
test "remove_unused_brs rewrites if arm local.set pair to local.set select" {
  let body = TExpr::new([
    TInstr::if_(
      BlockType::void_(),
      TInstr::local_get(LocalIdx::new(0)),
      TExpr::new([
        TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(11))),
      ]),
      Some(
        TExpr::new([
          TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(22))),
        ]),
      ),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body, locals=[
    ValType::i32(),
  ])
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TLocalSet(
              LocalIdx(1U),
              {
                kind: TInstrKind::TSelect(
                  _,
                  { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                  { kind: TInstrKind::TI32Const(I32(11)), .. },
                  { kind: TInstrKind::TI32Const(I32(22)), .. }
                ),
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected if(local.set/local.set) to fold into local.set(select)")
  }
}

///|
test "remove_unused_brs forwards trailing return value in function body" {
  let body = TExpr::new([TInstr::return_([TInstr::i32_const(I32(77))])])
  let mod = rub_single_typed_func_module([], [ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(_, _, { instrs: [{ kind: TInstrKind::TI32Const(I32(77)), .. }], .. }) =>
      ()
    _ => fail("expected trailing return value to be forwarded")
  }
}

///|
test "remove_unused_brs removes tail if when both arms return in function body" {
  let body = TExpr::new([
    TInstr::if_(
      BlockType::void_(),
      TInstr::local_get(LocalIdx::new(0)),
      TExpr::new([TInstr::return_([])]),
      Some(TExpr::new([TInstr::return_([])])),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TDrop(
              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected if(return, return) tail to become drop(condition)")
  }
}

///|
test "remove_unused_brs removes tail if when both arms break to block tail" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::if_(
          BlockType::void_(),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([TInstr::br(LabelIdx::new(1), [])]),
          Some(TExpr::new([TInstr::br(LabelIdx::new(1), [])])),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TDrop(
                      { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected if(br 0, br 0) block tail to become drop(condition)")
  }
}

///|
test "remove_unused_brs keeps tail if when branch arms have side effects before break" {
  let instrs : Array[TInstr] = [
    TInstr::if_(
      BlockType::void_(),
      TInstr::local_get(LocalIdx::new(0)),
      TExpr::new([
        TInstr::drop(TInstr::i32_const(I32(1))),
        TInstr::br(LabelIdx::new(1), []),
      ]),
      Some(
        TExpr::new([
          TInstr::drop(TInstr::i32_const(I32(2))),
          TInstr::br(LabelIdx::new(1), []),
        ]),
      ),
    ),
  ]
  let changed = rub_optimize_terminal_if_flow(instrs, false, true)
  assert_false(changed)
  match instrs {
    [{ kind: TInstrKind::TIf(VoidBlockType, _, _, Some(_)), .. }] => ()
    _ => fail("expected tail if with side-effecting arms to remain structured")
  }
}

///|
test "remove_unused_brs lowers if with distinct branch arms into br_if plus br" {
  let instrs : Array[TInstr] = [
    TInstr::if_(
      BlockType::void_(),
      TInstr::local_get(LocalIdx::new(0)),
      TExpr::new([TInstr::br(LabelIdx::new(4), [])]),
      Some(TExpr::new([TInstr::br(LabelIdx::new(3), [])])),
    ),
  ]
  let changed = rub_optimize_if_else_block_tail(
    instrs,
    OptimizeOptions::new(),
    true,
  )
  assert_true(changed)
  match instrs {
    [
      {
        kind: TInstrKind::TBrIf(
          LabelIdx(3U),
          { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
          []
        ),
        ..,
      },
      { kind: TInstrKind::TBr(LabelIdx(2U), []), .. },
    ] => ()
    _ =>
      fail(
        "expected if(br, br) to rewrite to br_if plus trailing br with rebased labels",
      )
  }
}

///|
test "remove_unused_brs keeps tail if when non-branch arm is unreachable" {
  let instrs : Array[TInstr] = [
    TInstr::if_(
      BlockType::void_(),
      TInstr::local_get(LocalIdx::new(0)),
      TExpr::new([TInstr::br(LabelIdx::new(2), [])]),
      Some(TExpr::new([TInstr::unreachable_(), TInstr::i32_const(I32(0))])),
    ),
  ]
  let changed = rub_optimize_if_else_block_tail(
    instrs,
    OptimizeOptions::new(),
    true,
  )
  assert_false(changed)
  match instrs {
    [{ kind: TInstrKind::TIf(VoidBlockType, _, _, Some(_)), .. }] => ()
    _ =>
      fail(
        "expected if-else tail with unreachable non-branch arm to remain structured",
      )
  }
}

///|
test "remove_unused_brs sinks single-if void block wrapper when labels rebase" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::if_(
          BlockType::void_(),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([TInstr::drop(TInstr::i32_const(I32(1)))]),
          Some(TExpr::new([TInstr::drop(TInstr::i32_const(I32(2)))])),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      { instrs: [{ kind: TInstrKind::TIf(_, _, _, Some(_)), .. }], .. }
    ) => ()
    _ => fail("expected single-if void block wrapper to be removed")
  }
}

///|
test "remove_unused_brs sinks single-if void block wrapper with leading nop when labels rebase" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::nop(),
        TInstr::if_(
          BlockType::void_(),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([TInstr::drop(TInstr::i32_const(I32(1)))]),
          Some(TExpr::new([TInstr::drop(TInstr::i32_const(I32(2)))])),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      { instrs: [{ kind: TInstrKind::TIf(_, _, _, Some(_)), .. }], .. }
    ) => ()
    _ =>
      fail(
        "expected single-if void block wrapper with leading nop to be removed",
      )
  }
}

///|
test "remove_unused_brs sinks single-loop void block wrapper when labels rebase" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([TInstr::drop(TInstr::i32_const(I32(1)))]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(_, _, { instrs: [{ kind: TInstrKind::TLoop(_, _), .. }], .. }) => ()
    _ => fail("expected single-loop void block wrapper to be removed")
  }
}

///|
test "remove_unused_brs sinks single-loop void block wrapper with leading nop when labels rebase" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::nop(),
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([TInstr::drop(TInstr::i32_const(I32(1)))]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(_, _, { instrs: [{ kind: TInstrKind::TLoop(_, _), .. }], .. }) => ()
    _ =>
      fail(
        "expected single-loop void block wrapper with leading nop to be removed",
      )
  }
}

///|
test "remove_unused_brs keeps single-loop block wrapper when removed scope is targeted" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([TInstr::br(LabelIdx::new(1), [])]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              { instrs: [{ kind: TInstrKind::TLoop(_, _), .. }], .. }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected single-loop block wrapper to remain when targeted by branch",
      )
  }
}

///|
test "remove_unused_brs keeps single-loop block wrapper when loop body targets removed scope" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::br_if(
              LabelIdx::new(1),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
            TInstr::drop(TInstr::i32_const(I32(9))),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [{ kind: TInstrKind::TBrIf(_, _, []), .. }, _],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected single-loop block wrapper to remain when loop body targets removed scope",
      )
  }
}

///|
test "remove_unused_brs keeps single-loop block wrapper with single-instr loop body targeting removed scope" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::br_if(
                  LabelIdx::new(2),
                  TInstr::local_get(LocalIdx::new(0)),
                  [],
                ),
                TInstr::drop(TInstr::i32_const(I32(1))),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      { instrs: [{ kind: TInstrKind::TBlock(_, _), .. }], .. }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected single-loop block wrapper to remain for single-instr loop body targeting removed scope",
      )
  }
}

///|
test "remove_unused_brs keeps single-loop block wrapper with single-instr br_if loop body targeting removed scope" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::br_if(
              LabelIdx::new(1),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [{ kind: TInstrKind::TBrIf(_, _, []), .. }],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected single-loop block wrapper to remain for single-instr br_if loop body targeting removed scope",
      )
  }
}

///|
test "remove_unused_brs sinks single-loop block wrapper in nested void context when removed scope is targeted" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([
            TInstr::loop_(
              BlockType::void_(),
              TExpr::new([
                TInstr::br_if(
                  LabelIdx::new(1),
                  TInstr::local_get(LocalIdx::new(0)),
                  [],
                ),
                TInstr::drop(TInstr::i32_const(I32(9))),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      { instrs: [{ kind: TInstrKind::TBlock(_, _), .. }], .. }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected nested single-loop block wrapper to sink in void parent context",
      )
  }
}

///|
test "remove_unused_brs keeps single-if block wrapper when removed scope is targeted" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::if_(
          BlockType::void_(),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([
            TInstr::br(LabelIdx::new(0), []),
            TInstr::drop(TInstr::i32_const(I32(9))),
          ]),
          Some(TExpr::new([TInstr::nop()])),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              { instrs: [{ kind: TInstrKind::TIf(_, _, _, Some(_)), .. }], .. }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail("expected single-if block wrapper to remain when targeted by branch")
  }
}

///|
test "remove_unused_brs sinks single-if block wrapper into targeted then arm" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::if_(
          BlockType::void_(),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([
            TInstr::br_if(
              LabelIdx::new(1),
              TInstr::local_get(LocalIdx::new(1)),
              [],
            ),
            TInstr::drop(TInstr::i32_const(I32(9))),
          ]),
          None,
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32(), ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TIf(
              _,
              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
              {
                instrs: [
                  {
                    kind: TInstrKind::TBlock(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TBrIf(
                              LabelIdx(0U),
                              { kind: TInstrKind::TLocalGet(LocalIdx(1U)), .. },
                              []
                            ),
                            ..,
                          },
                          {
                            kind: TInstrKind::TDrop(
                              { kind: TInstrKind::TI32Const(I32(9)), .. }
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              },
              None
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected single-if block wrapper to sink into the then arm with rebased branch labels",
      )
  }
}

///|
test "remove_unused_brs sinks single-if block wrapper into targeted then arm with else" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::if_(
          BlockType::void_(),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([
            TInstr::br_if(
              LabelIdx::new(1),
              TInstr::local_get(LocalIdx::new(1)),
              [],
            ),
            TInstr::drop(TInstr::i32_const(I32(9))),
          ]),
          Some(TExpr::new([TInstr::drop(TInstr::i32_const(I32(3)))])),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32(), ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TIf(
              _,
              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
              {
                instrs: [
                  {
                    kind: TInstrKind::TBlock(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TBrIf(
                              LabelIdx(0U),
                              { kind: TInstrKind::TLocalGet(LocalIdx(1U)), .. },
                              []
                            ),
                            ..,
                          },
                          {
                            kind: TInstrKind::TDrop(
                              { kind: TInstrKind::TI32Const(I32(9)), .. }
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              },
              Some(
                {
                  instrs: [
                    {
                      kind: TInstrKind::TDrop(
                        { kind: TInstrKind::TI32Const(I32(3)), .. }
                      ),
                      ..,
                    },
                  ],
                  ..,
                }
              )
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected single-if block wrapper to sink into the then arm while preserving the else arm",
      )
  }
}

///|
test "remove_unused_brs sinks single-if block wrapper into targeted then arm when else has internal non-crossing branch" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::if_(
          BlockType::void_(),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([
            TInstr::br_if(
              LabelIdx::new(1),
              TInstr::local_get(LocalIdx::new(1)),
              [],
            ),
            TInstr::drop(TInstr::i32_const(I32(9))),
          ]),
          Some(
            TExpr::new([
              TInstr::block(
                BlockType::void_(),
                TExpr::new([TInstr::br(LabelIdx::new(0), [])]),
              ),
              TInstr::drop(TInstr::i32_const(I32(3))),
            ]),
          ),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32(), ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TIf(
              _,
              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
              {
                instrs: [
                  {
                    kind: TInstrKind::TBlock(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TBrIf(
                              LabelIdx(0U),
                              { kind: TInstrKind::TLocalGet(LocalIdx(1U)), .. },
                              []
                            ),
                            ..,
                          },
                          {
                            kind: TInstrKind::TDrop(
                              { kind: TInstrKind::TI32Const(I32(9)), .. }
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              },
              Some(_)
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected single-if block wrapper to sink into targeted then arm when else branches only within its own internal block scope",
      )
  }
}

///|
test "remove_unused_brs sinks single-if block wrapper into single-instr targeted then arm with else" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::if_(
          BlockType::void_(),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([
            TInstr::br_if(
              LabelIdx::new(1),
              TInstr::local_get(LocalIdx::new(1)),
              [],
            ),
          ]),
          Some(TExpr::new([TInstr::drop(TInstr::i32_const(I32(3)))])),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32(), ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TIf(
              _,
              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
              {
                instrs: [
                  {
                    kind: TInstrKind::TBlock(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TDrop(
                              { kind: TInstrKind::TLocalGet(LocalIdx(1U)), .. }
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              },
              Some(
                {
                  instrs: [
                    {
                      kind: TInstrKind::TDrop(
                        { kind: TInstrKind::TI32Const(I32(3)), .. }
                      ),
                      ..,
                    },
                  ],
                  ..,
                }
              )
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected single-if block wrapper to sink into single-instr then arm when only that arm targets the removed scope",
      )
  }
}

///|
test "remove_unused_brs sinks single-if block wrapper into targeted else arm with else" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::if_(
          BlockType::void_(),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([TInstr::drop(TInstr::i32_const(I32(3)))]),
          Some(
            TExpr::new([
              TInstr::br_if(
                LabelIdx::new(1),
                TInstr::local_get(LocalIdx::new(1)),
                [],
              ),
              TInstr::drop(TInstr::i32_const(I32(9))),
            ]),
          ),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32(), ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TIf(
              _,
              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
              {
                instrs: [
                  {
                    kind: TInstrKind::TDrop(
                      { kind: TInstrKind::TI32Const(I32(3)), .. }
                    ),
                    ..,
                  },
                ],
                ..,
              },
              Some(
                {
                  instrs: [
                    {
                      kind: TInstrKind::TBlock(
                        _,
                        {
                          instrs: [
                            {
                              kind: TInstrKind::TBrIf(
                                LabelIdx(0U),
                                {
                                  kind: TInstrKind::TLocalGet(LocalIdx(1U)),
                                  ..,
                                },
                                []
                              ),
                              ..,
                            },
                            {
                              kind: TInstrKind::TDrop(
                                { kind: TInstrKind::TI32Const(I32(9)), .. }
                              ),
                              ..,
                            },
                          ],
                          ..,
                        }
                      ),
                      ..,
                    },
                  ],
                  ..,
                }
              )
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected single-if block wrapper to sink into the else arm while preserving the then arm",
      )
  }
}

///|
test "remove_unused_brs jump threads single-br block wrappers" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([TInstr::br(LabelIdx::new(1), [])]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      { instrs: [{ kind: TInstrKind::TBlock(_, { instrs: [], .. }), .. }], .. }
    ) => ()
    _ =>
      fail("expected nested single-br block wrappers to thread and disappear")
  }
}

///|
test "remove_unused_brs jump threads single-br block wrappers with leading nop" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([TInstr::nop(), TInstr::br(LabelIdx::new(1), [])]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      { instrs: [{ kind: TInstrKind::TBlock(_, { instrs: [], .. }), .. }], .. }
    ) => ()
    _ =>
      fail(
        "expected nested single-br wrappers with a leading nop to thread and disappear",
      )
  }
}

///|
test "remove_unused_brs jump_thread_br skips oversized child-block rewrite" {
  let large_body : Array[TInstr] = []
  for _ in 0..<25000 {
    large_body.push(TInstr::nop())
  }
  large_body.push(TInstr::br(LabelIdx::new(0), []))

  let instrs : Array[TInstr] = [
    TInstr::block(BlockType::void_(), TExpr::new(large_body)),
    TInstr::br(LabelIdx::new(0), []),
  ]
  let changed = rub_optimize_jump_thread_child_block_following_br(
    instrs,
    rub_collect_top_level_void_block_sites(instrs),
  )
  assert_false(changed)
}

///|
test "remove_unused_brs jump_thread_unreachable skips when child-body scan budget is exhausted" {
  let large_body : Array[TInstr] = []
  for _ in 0..<25000 {
    large_body.push(TInstr::nop())
  }
  large_body.push(TInstr::br(LabelIdx::new(0), []))
  let instrs : Array[TInstr] = [
    TInstr::block(BlockType::void_(), TExpr::new(large_body)),
    TInstr::unreachable_(),
  ]
  let original_instrs = instrs.copy()
  let changed = rub_optimize_jump_thread_child_block_following_unreachable_with_budgets(
    instrs,
    rub_collect_top_level_void_block_sites(instrs),
    0,
    64,
  )
  assert_false(changed)
  assert_eq(instrs, original_instrs)
}

///|
test "remove_unused_brs jump_thread_unreachable skips when child-body rewrite budget is exhausted" {
  let instrs : Array[TInstr] = [
    TInstr::block(
      BlockType::void_(),
      TExpr::new([TInstr::br(LabelIdx::new(0), [])]),
    ),
    TInstr::unreachable_(),
  ]
  let original_instrs = instrs.copy()
  let changed = rub_optimize_jump_thread_child_block_following_unreachable_with_budgets(
    instrs,
    rub_collect_top_level_void_block_sites(instrs),
    64,
    0,
  )
  assert_false(changed)
  assert_eq(instrs, original_instrs)
}

///|
test "remove_unused_brs jump_thread_return skips when child-body scan budget is exhausted" {
  let large_body : Array[TInstr] = []
  for _ in 0..<25000 {
    large_body.push(TInstr::nop())
  }
  large_body.push(TInstr::br(LabelIdx::new(0), []))
  let instrs : Array[TInstr] = [
    TInstr::block(BlockType::void_(), TExpr::new(large_body)),
    TInstr::return_([]),
  ]
  let original_instrs = instrs.copy()
  let changed = rub_optimize_jump_thread_child_block_following_return_with_budgets(
    instrs,
    rub_collect_top_level_void_block_sites(instrs),
    0,
    64,
  )
  assert_false(changed)
  assert_eq(instrs, original_instrs)
}

///|
test "remove_unused_brs jump_thread_return skips when child-body rewrite budget is exhausted" {
  let instrs : Array[TInstr] = [
    TInstr::block(
      BlockType::void_(),
      TExpr::new([TInstr::br(LabelIdx::new(0), [])]),
    ),
    TInstr::return_([]),
  ]
  let original_instrs = instrs.copy()
  let changed = rub_optimize_jump_thread_child_block_following_return_with_budgets(
    instrs,
    rub_collect_top_level_void_block_sites(instrs),
    64,
    0,
  )
  assert_false(changed)
  assert_eq(instrs, original_instrs)
}

///|
test "remove_unused_brs jump threads single-br_if block wrappers" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([
            TInstr::br_if(
              LabelIdx::new(1),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TDrop(
                      { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected single-br_if block wrapper to thread and canonicalize")
  }
}

///|
test "remove_unused_brs jump threads child block branch through following wrapped loop continue with leading nop" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::if_(
                  BlockType::void_(),
                  TInstr::local_get(LocalIdx::new(0)),
                  TExpr::new([TInstr::br(LabelIdx::new(1), [])]),
                  None,
                ),
                TInstr::drop(TInstr::i32_const(I32(1))),
              ]),
            ),
            TInstr::block(
              BlockType::void_(),
              TExpr::new([TInstr::nop(), TInstr::br(LabelIdx::new(1), [])]),
            ),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TBlock(
                              _,
                              {
                                instrs: [
                                  {
                                    kind: TInstrKind::TBrIf(
                                      LabelIdx(1U),
                                      {
                                        kind: TInstrKind::TLocalGet(
                                          LocalIdx(0U)
                                        ),
                                        ..,
                                      },
                                      []
                                    ),
                                    ..,
                                  },
                                  {
                                    kind: TInstrKind::TDrop(
                                      {
                                        kind: TInstrKind::TI32Const(I32(1)),
                                        ..,
                                      }
                                    ),
                                    ..,
                                  },
                                ],
                                ..,
                              }
                            ),
                            ..,
                          },
                          { kind: TInstrKind::TBr(LabelIdx(0U), []), .. },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected child block branch to thread through wrapped loop continue that starts with nop",
      )
  }
}

///|
test "remove_unused_brs jump threads single-br_if label zero wrapper to drop" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([
            TInstr::br_if(
              LabelIdx::new(0),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBlock(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TDrop(
                              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. }
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail("expected single-br_if label0 wrapper to thread to drop(condition)")
  }
}

///|
test "remove_unused_brs jump threads child block branch through following loop continue" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::if_(
                  BlockType::void_(),
                  TInstr::local_get(LocalIdx::new(0)),
                  TExpr::new([TInstr::br(LabelIdx::new(1), [])]),
                  None,
                ),
                TInstr::drop(TInstr::i32_const(I32(1))),
              ]),
            ),
            TInstr::br(LabelIdx::new(0), []),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TBlock(
                              _,
                              {
                                instrs: [
                                  {
                                    kind: TInstrKind::TBrIf(
                                      LabelIdx(1U),
                                      {
                                        kind: TInstrKind::TLocalGet(
                                          LocalIdx(0U)
                                        ),
                                        ..,
                                      },
                                      []
                                    ),
                                    ..,
                                  },
                                  {
                                    kind: TInstrKind::TDrop(
                                      {
                                        kind: TInstrKind::TI32Const(I32(1)),
                                        ..,
                                      }
                                    ),
                                    ..,
                                  },
                                ],
                                ..,
                              }
                            ),
                            ..,
                          },
                          { kind: TInstrKind::TBr(LabelIdx(0U), []), .. },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected child block branch to retarget through the following loop continue",
      )
  }
}

///|
test "remove_unused_brs jump threads child block br_if through following loop continue" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::br_if(
                  LabelIdx::new(0),
                  TInstr::local_get(LocalIdx::new(0)),
                  [],
                ),
                TInstr::drop(TInstr::i32_const(I32(1))),
              ]),
            ),
            TInstr::br(LabelIdx::new(0), []),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TBlock(
                              _,
                              {
                                instrs: [
                                  {
                                    kind: TInstrKind::TBrIf(
                                      LabelIdx(1U),
                                      {
                                        kind: TInstrKind::TLocalGet(
                                          LocalIdx(0U)
                                        ),
                                        ..,
                                      },
                                      []
                                    ),
                                    ..,
                                  },
                                  {
                                    kind: TInstrKind::TDrop(
                                      {
                                        kind: TInstrKind::TI32Const(I32(1)),
                                        ..,
                                      }
                                    ),
                                    ..,
                                  },
                                ],
                                ..,
                              }
                            ),
                            ..,
                          },
                          { kind: TInstrKind::TBr(LabelIdx(0U), []), .. },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected child block br_if to retarget through the following loop continue",
      )
  }
}

///|
test "remove_unused_brs jump threads child block br_if through following nop then loop continue" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::br_if(
                  LabelIdx::new(0),
                  TInstr::local_get(LocalIdx::new(0)),
                  [],
                ),
                TInstr::drop(TInstr::i32_const(I32(1))),
              ]),
            ),
            TInstr::nop(),
            TInstr::br(LabelIdx::new(0), []),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TBlock(
                              _,
                              {
                                instrs: [
                                  {
                                    kind: TInstrKind::TBrIf(
                                      LabelIdx(1U),
                                      {
                                        kind: TInstrKind::TLocalGet(
                                          LocalIdx(0U)
                                        ),
                                        ..,
                                      },
                                      []
                                    ),
                                    ..,
                                  },
                                  {
                                    kind: TInstrKind::TDrop(
                                      {
                                        kind: TInstrKind::TI32Const(I32(1)),
                                        ..,
                                      }
                                    ),
                                    ..,
                                  },
                                ],
                                ..,
                              }
                            ),
                            ..,
                          },
                          { kind: TInstrKind::TNop, .. },
                          { kind: TInstrKind::TBr(LabelIdx(0U), []), .. },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected child block br_if to retarget through an intervening nop before loop continue",
      )
  }
}

///|
test "remove_unused_brs jump threads child block branch through following unreachable" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([TInstr::br(LabelIdx::new(1), [])]),
              None,
            ),
            TInstr::drop(TInstr::i32_const(I32(1))),
          ]),
        ),
        TInstr::unreachable_(),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBlock(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TIf(
                              _,
                              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                              {
                                instrs: [{ kind: TInstrKind::TUnreachable, .. }],
                                ..,
                              },
                              None
                            ),
                            ..,
                          },
                          {
                            kind: TInstrKind::TDrop(
                              { kind: TInstrKind::TI32Const(I32(1)), .. }
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                  { kind: TInstrKind::TUnreachable, .. },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected child block branch to thread to unreachable when the following instruction traps",
      )
  }
}

///|
test "remove_unused_brs jump threads child block br_if through following unreachable" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([
            TInstr::br_if(
              LabelIdx::new(0),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
            TInstr::drop(TInstr::i32_const(I32(1))),
          ]),
        ),
        TInstr::unreachable_(),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBlock(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TIf(
                              _,
                              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                              {
                                instrs: [{ kind: TInstrKind::TUnreachable, .. }],
                                ..,
                              },
                              None
                            ),
                            ..,
                          },
                          {
                            kind: TInstrKind::TDrop(
                              { kind: TInstrKind::TI32Const(I32(1)), .. }
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                  { kind: TInstrKind::TUnreachable, .. },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected child block br_if to thread to unreachable when the following instruction traps",
      )
  }
}

///|
test "remove_unused_brs jump threads child block br_if through following nop then unreachable" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([
            TInstr::br_if(
              LabelIdx::new(0),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
            TInstr::drop(TInstr::i32_const(I32(1))),
          ]),
        ),
        TInstr::nop(),
        TInstr::unreachable_(),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBlock(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TIf(
                              _,
                              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                              {
                                instrs: [{ kind: TInstrKind::TUnreachable, .. }],
                                ..,
                              },
                              None
                            ),
                            ..,
                          },
                          {
                            kind: TInstrKind::TDrop(
                              { kind: TInstrKind::TI32Const(I32(1)), .. }
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                  { kind: TInstrKind::TNop, .. },
                  { kind: TInstrKind::TUnreachable, .. },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected child block br_if to thread through an intervening nop before unreachable",
      )
  }
}

///|
test "remove_unused_brs jump threads child block branch through following return" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([TInstr::br(LabelIdx::new(1), [])]),
              None,
            ),
            TInstr::drop(TInstr::i32_const(I32(1))),
          ]),
        ),
        TInstr::return_([]),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBlock(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TIf(
                              _,
                              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                              {
                                instrs: [{ kind: TInstrKind::TReturn([]), .. }],
                                ..,
                              },
                              None
                            ),
                            ..,
                          },
                          {
                            kind: TInstrKind::TDrop(
                              { kind: TInstrKind::TI32Const(I32(1)), .. }
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                  { kind: TInstrKind::TReturn([]), .. },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected child block branch to thread to return when the following instruction returns",
      )
  }
}

///|
test "remove_unused_brs jump threads child block br_if through following nop then return" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([
            TInstr::br_if(
              LabelIdx::new(0),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
            TInstr::drop(TInstr::i32_const(I32(1))),
          ]),
        ),
        TInstr::nop(),
        TInstr::return_([]),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBlock(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TIf(
                              _,
                              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                              {
                                instrs: [{ kind: TInstrKind::TReturn([]), .. }],
                                ..,
                              },
                              None
                            ),
                            ..,
                          },
                          {
                            kind: TInstrKind::TDrop(
                              { kind: TInstrKind::TI32Const(I32(1)), .. }
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                  { kind: TInstrKind::TNop, .. },
                  { kind: TInstrKind::TReturn([]), .. },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected child block br_if to thread through an intervening nop before return",
      )
  }
}

///|
test "remove_unused_brs jump threads child block br_if through following return" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([
            TInstr::br_if(
              LabelIdx::new(0),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
            TInstr::drop(TInstr::i32_const(I32(1))),
          ]),
        ),
        TInstr::return_([]),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBlock(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TIf(
                              _,
                              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                              {
                                instrs: [{ kind: TInstrKind::TReturn([]), .. }],
                                ..,
                              },
                              None
                            ),
                            ..,
                          },
                          {
                            kind: TInstrKind::TDrop(
                              { kind: TInstrKind::TI32Const(I32(1)), .. }
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                  { kind: TInstrKind::TReturn([]), .. },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected child block br_if to thread to return when the following instruction returns",
      )
  }
}

///|
test "remove_unused_brs jump threads child block branch through following wrapped unreachable" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([TInstr::br(LabelIdx::new(1), [])]),
              None,
            ),
            TInstr::drop(TInstr::i32_const(I32(1))),
          ]),
        ),
        TInstr::block(BlockType::void_(), TExpr::new([TInstr::unreachable_()])),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBlock(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TIf(
                              _,
                              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                              {
                                instrs: [{ kind: TInstrKind::TUnreachable, .. }],
                                ..,
                              },
                              None
                            ),
                            ..,
                          },
                          {
                            kind: TInstrKind::TDrop(
                              { kind: TInstrKind::TI32Const(I32(1)), .. }
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                  { kind: TInstrKind::TUnreachable, .. },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected child block branch to thread through a wrapped unreachable target",
      )
  }
}

///|
test "remove_unused_brs jump threads child block br_if through following wrapped return" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([
            TInstr::br_if(
              LabelIdx::new(0),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
            TInstr::drop(TInstr::i32_const(I32(1))),
          ]),
        ),
        TInstr::block(BlockType::void_(), TExpr::new([TInstr::return_([])])),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBlock(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TIf(
                              _,
                              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                              {
                                instrs: [{ kind: TInstrKind::TReturn([]), .. }],
                                ..,
                              },
                              None
                            ),
                            ..,
                          },
                          {
                            kind: TInstrKind::TDrop(
                              { kind: TInstrKind::TI32Const(I32(1)), .. }
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                  { kind: TInstrKind::TReturn([]), .. },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected child block br_if to thread through a wrapped return target",
      )
  }
}

///|
test "remove_unused_brs keeps child block br_if before following br_if for safety" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([
            TInstr::br_if(
              LabelIdx::new(0),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
            TInstr::drop(TInstr::i32_const(I32(1))),
          ]),
        ),
        TInstr::br_if(LabelIdx::new(0), TInstr::local_get(LocalIdx::new(1)), []),
        TInstr::drop(TInstr::i32_const(I32(9))),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32(), ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBlock(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TBrIf(
                              LabelIdx(0U),
                              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                              []
                            ),
                            ..,
                          },
                          {
                            kind: TInstrKind::TDrop(
                              { kind: TInstrKind::TI32Const(I32(1)), .. }
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                  {
                    kind: TInstrKind::TBrIf(
                      LabelIdx(0U),
                      { kind: TInstrKind::TLocalGet(LocalIdx(1U)), .. },
                      []
                    ),
                    ..,
                  },
                  {
                    kind: TInstrKind::TDrop(
                      { kind: TInstrKind::TI32Const(I32(9)), .. }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected child block br_if before following br_if to stay conservative",
      )
  }
}

///|
test "remove_unused_brs detects top-level child-scope branch patterns" {
  let with_branch = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::br_if(LabelIdx::new(1), TInstr::local_get(LocalIdx::new(0)), []),
      ]),
    ),
  ])
  assert_true(rub_has_top_level_child_scope_branch(with_branch))

  let without_branch = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(1))),
        TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
      ]),
    ),
  ])
  assert_false(rub_has_top_level_child_scope_branch(without_branch))
}

///|
test "remove_unused_brs collects top-level void block sites" {
  let instrs : Array[TInstr] = [
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(1))),
    TInstr::block(BlockType::void_(), TExpr::new([TInstr::nop()])),
    TInstr::block(
      BlockType::val_type(ValType::i32()),
      TExpr::new([TInstr::i32_const(I32(7))]),
    ),
    TInstr::drop(TInstr::i32_const(I32(2))),
    TInstr::block(BlockType::void_(), TExpr::new([TInstr::nop()])),
  ]
  assert_eq(rub_collect_top_level_void_block_sites(instrs), [1, 4])
}

///|
test "remove_unused_brs collects no void block sites for flat list" {
  let instrs : Array[TInstr] = [
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(1))),
    TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
    TInstr::block(
      BlockType::val_type(ValType::i32()),
      TExpr::new([TInstr::i32_const(I32(3))]),
    ),
  ]
  assert_eq(rub_collect_top_level_void_block_sites(instrs), [])
}

///|
test "remove_unused_brs jump threads child block br_if through following br_if plus default branch" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::br_if(
                  LabelIdx::new(0),
                  TInstr::local_get(LocalIdx::new(0)),
                  [],
                ),
                TInstr::drop(TInstr::i32_const(I32(1))),
              ]),
            ),
            TInstr::br_if(
              LabelIdx::new(1),
              TInstr::local_get(LocalIdx::new(1)),
              [],
            ),
            TInstr::br(LabelIdx::new(0), []),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32(), ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TBlock(
                              _,
                              { instrs: [threaded, _], .. }
                            ),
                            ..,
                          },
                          _,
                          _,
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) =>
      match threaded.kind {
        TInstrKind::TIf(
          _,
          { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
          _,
          None
        ) => ()
        _ =>
          fail(
            "expected child block br_if to thread into a one-armed if before the following branch pair",
          )
      }
    _ =>
      fail(
        "expected child block br_if to thread through following br_if with explicit default branch target",
      )
  }
}

///|
test "remove_unused_brs jump threads child block br_if through following br_if plus default branch after leading nop" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::nop(),
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::br_if(
                  LabelIdx::new(0),
                  TInstr::local_get(LocalIdx::new(0)),
                  [],
                ),
                TInstr::drop(TInstr::i32_const(I32(1))),
              ]),
            ),
            TInstr::br_if(
              LabelIdx::new(1),
              TInstr::local_get(LocalIdx::new(1)),
              [],
            ),
            TInstr::br(LabelIdx::new(0), []),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32(), ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [
                          { kind: TInstrKind::TNop, .. },
                          {
                            kind: TInstrKind::TBlock(
                              _,
                              { instrs: [threaded, _], .. }
                            ),
                            ..,
                          },
                          _,
                          _,
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) =>
      match threaded.kind {
        TInstrKind::TIf(
          _,
          { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
          _,
          None
        ) => ()
        _ =>
          fail(
            "expected child block br_if to thread through following branch pair even with a leading nop",
          )
      }
    _ =>
      fail(
        "expected child block br_if threading through following br_if+br pair after a leading nop",
      )
  }
}

///|
test "remove_unused_brs jump_thread_br_if skips body scan when tail is not terminal branch pair" {
  let trace_logs : Array[String] = []
  let instrs : Array[TInstr] = [
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::br_if(LabelIdx::new(0), TInstr::local_get(LocalIdx::new(0)), []),
        TInstr::drop(TInstr::i32_const(I32(1))),
      ]),
    ),
    TInstr::br_if(LabelIdx::new(1), TInstr::local_get(LocalIdx::new(1)), []),
    TInstr::br(LabelIdx::new(0), []),
    TInstr::drop(TInstr::i32_const(I32(9))),
  ]
  let trace_state = rub_round_trace_state(
    true,
    fn(msg) { trace_logs.push(msg) },
    1,
    1,
    sl_trace_now_ms(),
  )
  let changed = rub_optimize_jump_thread_child_block_following_br_if(
    instrs,
    rub_collect_top_level_void_block_sites(instrs),
    trace_state=Some(trace_state),
  )
  assert_false(changed)

  let mut saw_jump_thread_site = false
  let mut saw_jump_thread_body_scan = false
  for msg in trace_logs {
    if msg.contains("helper=jump_thread_br_if step=scan_site") {
      saw_jump_thread_site = true
    }
    if msg.contains("helper=jump_thread_br_if step=scan_body:done") {
      saw_jump_thread_body_scan = true
    }
  }
  assert_true(saw_jump_thread_site)
  assert_false(saw_jump_thread_body_scan)
}

///|
test "remove_unused_brs jump threads nested child block br_if through following br_if plus default branch" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::block(
                  BlockType::void_(),
                  TExpr::new([
                    TInstr::br_if(
                      LabelIdx::new(1),
                      TInstr::local_get(LocalIdx::new(0)),
                      [],
                    ),
                  ]),
                ),
                TInstr::drop(TInstr::i32_const(I32(1))),
              ]),
            ),
            TInstr::br_if(
              LabelIdx::new(1),
              TInstr::local_get(LocalIdx::new(1)),
              [],
            ),
            TInstr::br(LabelIdx::new(0), []),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32(), ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TLoop(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TBlock(
                              _,
                              { instrs: [{ kind: threaded_kind, .. }, _], .. }
                            ),
                            ..,
                          },
                          _,
                          _,
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) =>
      match threaded_kind {
        TInstrKind::TIf(
          _,
          { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
          _,
          None
        ) => ()
        TInstrKind::TBlock(
          _,
          {
            instrs: [
              {
                kind: TInstrKind::TIf(
                  _,
                  { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
                  _,
                  None
                ),
                ..,
              },
            ],
            ..,
          }
        ) => ()
        _ =>
          fail(
            "expected nested child-scope br_if to thread into a one-armed if before the following branch pair",
          )
      }
    _ =>
      fail(
        "expected nested child block br_if to thread through following br_if with explicit default branch target",
      )
  }
}

///|
test "remove_unused_brs jump threads child block br_if inside dropped value block without underflow" {
  let body = TExpr::new([
    TInstr::drop(
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::block(
            BlockType::void_(),
            TExpr::new([
              TInstr::loop_(
                BlockType::void_(),
                TExpr::new([
                  TInstr::block(
                    BlockType::void_(),
                    TExpr::new([
                      TInstr::br_if(
                        LabelIdx::new(0),
                        TInstr::local_get(LocalIdx::new(0)),
                        [],
                      ),
                      TInstr::drop(TInstr::i32_const(I32(1))),
                    ]),
                  ),
                  TInstr::br_if(
                    LabelIdx::new(1),
                    TInstr::local_get(LocalIdx::new(1)),
                    [],
                  ),
                  TInstr::br(LabelIdx::new(0), []),
                ]),
              ),
            ]),
          ),
          TInstr::i32_const(I32(0)),
        ]),
      ),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32(), ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
}

///|
test "remove_unused_brs rewrites try_table throw to branch for matching catch" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::try_table(
          BlockType::void_(),
          [Catch::new(TagIdx::new(0), LabelIdx::new(1))],
          TExpr::new([TInstr::throw_(TagIdx::new(0), [])]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module_with_tags([], body, [[]])
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TTryTable(
                      _,
                      _,
                      { instrs: [{ kind: TInstrKind::TBr(label, []), .. }], .. }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(label, LabelIdx::new(1))
    _ => fail("expected matching try_table throw to rewrite to direct branch")
  }
}

///|
test "remove_unused_brs rewrites try_table throw to branch for catch_all" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::try_table(
          BlockType::void_(),
          [Catch::all(LabelIdx::new(1))],
          TExpr::new([TInstr::throw_(TagIdx::new(0), [])]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module_with_tags([], body, [[]])
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TTryTable(
                      _,
                      _,
                      { instrs: [{ kind: TInstrKind::TBr(label, []), .. }], .. }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(label, LabelIdx::new(1))
    _ => fail("expected catch_all try_table throw to rewrite to direct branch")
  }
}

///|
test "remove_unused_brs rewrites try_table throw to branch for catch_all_ref via exnref materialization in typed result fixture" {
  let tag_type = RecType::new(SubType::comp_type(CompType::func([], [])))
  let exnref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::exn())),
  )
  let main_type = RecType::new(SubType::comp_type(CompType::func([], [exnref])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([tag_type, main_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(0))]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::try_table(
              BlockType::type_idx(TypeIdx::new(1)),
              [Catch::all_ref(LabelIdx::new(1))],
              TExpr::new([TInstr::throw_(TagIdx::new(0), [])]),
            ),
          ]),
        ),
      ]),
    )
  let out = rub_run(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) => fail("expected rewritten catch_all_ref module to validate: \{e}")
  }
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TTryTable(
              _,
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBr(
                      LabelIdx(1U),
                      [{ kind: TInstrKind::TBlock(_, _), .. }]
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected catch_all_ref try_table throw to rewrite to branch carrying a materialized exnref",
      )
  }
}

///|
test "remove_unused_brs rewrites catch_all throw values to drops then branch" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::try_table(
          BlockType::void_(),
          [Catch::all(LabelIdx::new(1))],
          TExpr::new([
            TInstr::throw_(TagIdx::new(0), [
              TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(7))),
            ]),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module_with_tags(
    [],
    body,
    [[ValType::i32()]],
    locals=[ValType::i32()],
  )
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TTryTable(
                      _,
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TBlock(
                              _,
                              {
                                instrs: [
                                  {
                                    kind: TInstrKind::TDrop(
                                      {
                                        kind: TInstrKind::TLocalTee(
                                          LocalIdx(0U),
                                          {
                                            kind: TInstrKind::TI32Const(I32(7)),
                                            ..,
                                          }
                                        ),
                                        ..,
                                      }
                                    ),
                                    ..,
                                  },
                                  { kind: TInstrKind::TBr(label, []), .. },
                                ],
                                ..,
                              }
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(label, LabelIdx::new(1))
    _ =>
      fail(
        "expected catch_all throw values to be dropped before branching to catch",
      )
  }
}

///|
test "remove_unused_brs rewrites try_table throw_ref to branch for catch_all_ref" {
  let exnref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::exn())),
  )
  let body = TExpr::new([
    TInstr::try_table(
      BlockType::val_type(exnref),
      [Catch::all_ref(LabelIdx::new(1))],
      TExpr::new([TInstr::throw_ref(TInstr::local_get(LocalIdx::new(0)))]),
    ),
  ])
  let mod = rub_single_typed_func_module([exnref], [exnref], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TTryTable(
              _,
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBr(
                      LabelIdx(1U),
                      [{ kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. }]
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected catch_all_ref try_table throw_ref to rewrite to direct branch carrying exnref",
      )
  }
}

///|
test "remove_unused_brs rewrites try_table throw_ref to drops then branch for catch_all" {
  let exnref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::exn())),
  )
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::try_table(
          BlockType::void_(),
          [Catch::all(LabelIdx::new(1))],
          TExpr::new([TInstr::throw_ref(TInstr::local_get(LocalIdx::new(0)))]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([exnref], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TTryTable(
                      _,
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TBlock(
                              _,
                              {
                                instrs: [
                                  {
                                    kind: TInstrKind::TDrop(
                                      {
                                        kind: TInstrKind::TLocalGet(
                                          LocalIdx(0U)
                                        ),
                                        ..,
                                      }
                                    ),
                                    ..,
                                  },
                                  {
                                    kind: TInstrKind::TBr(LabelIdx(1U), []),
                                    ..,
                                  },
                                ],
                                ..,
                              }
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected catch_all try_table throw_ref to drop exnref and rewrite to branch",
      )
  }
}

///|
test "remove_unused_brs keeps try_table throw_ref when leading catch_ref blocks static match" {
  let tag_type = RecType::new(SubType::comp_type(CompType::func([], [])))
  let exnref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::exn())),
  )
  let main_type = RecType::new(
    SubType::comp_type(CompType::func([exnref], [exnref])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([tag_type, main_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(0))]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [exnref],
          [],
          TExpr::new([
            TInstr::try_table(
              BlockType::val_type(exnref),
              [
                Catch::ref_(TagIdx::new(0), LabelIdx::new(1)),
                Catch::all_ref(LabelIdx::new(1)),
              ],
              TExpr::new([
                TInstr::throw_ref(TInstr::local_get(LocalIdx::new(0))),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TTryTable(
              _,
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TThrowRef(
                      { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected throw_ref to stay when leading catch_ref can intercept before catch_all_ref",
      )
  }
}

///|
test "remove_unused_brs rewrites nested throw to branch via enclosing try_table" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::try_table(
          BlockType::void_(),
          [Catch::new(TagIdx::new(0), LabelIdx::new(1))],
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([TInstr::throw_(TagIdx::new(0), [])]),
            ),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module_with_tags([], body, [[]])
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TTryTable(
                      _,
                      _,
                      { instrs: [{ kind: TInstrKind::TBr(label, []), .. }], .. }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(label, LabelIdx::new(1))
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TTryTable(
                      _,
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TBlock(
                              _,
                              {
                                instrs: [
                                  { kind: TInstrKind::TBr(label, []), .. },
                                ],
                                ..,
                              }
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(label, LabelIdx::new(2))
    _ =>
      fail(
        "expected nested throw in try_table body to rewrite to a correctly rebased branch",
      )
  }
}

///|
test "remove_unused_brs rewrites nested throw under catch_ref to branch with materialized exnref when payload empty" {
  let tag_type = RecType::new(SubType::comp_type(CompType::func([], [])))
  let exnref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::exn())),
  )
  let main_type = RecType::new(SubType::comp_type(CompType::func([], [exnref])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([tag_type, main_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(0))]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::try_table(
              BlockType::type_idx(TypeIdx::new(1)),
              [Catch::ref_(TagIdx::new(0), LabelIdx::new(1))],
              TExpr::new([
                TInstr::block(
                  BlockType::val_type(exnref),
                  TExpr::new([TInstr::throw_(TagIdx::new(0), [])]),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TTryTable(
              _,
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBlock(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TBr(
                              _,
                              [{ kind: TInstrKind::TBlock(_, _), .. }]
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected nested throw under catch_ref to rewrite to branch carrying materialized exnref when payload is empty",
      )
  }
}

///|
test "remove_unused_brs rewrites nested throw under catch_all_ref to branch with materialized exnref" {
  let tag_type = RecType::new(SubType::comp_type(CompType::func([], [])))
  let exnref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::exn())),
  )
  let main_type = RecType::new(SubType::comp_type(CompType::func([], [exnref])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([tag_type, main_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(0))]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::try_table(
              BlockType::type_idx(TypeIdx::new(1)),
              [Catch::all_ref(LabelIdx::new(1))],
              TExpr::new([
                TInstr::block(
                  BlockType::val_type(exnref),
                  TExpr::new([TInstr::throw_(TagIdx::new(0), [])]),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TTryTable(
              _,
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBlock(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TBr(
                              _,
                              [{ kind: TInstrKind::TBlock(_, _), .. }]
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected nested throw under catch_all_ref to rewrite to branch carrying materialized exnref",
      )
  }
}

///|
test "remove_unused_brs keeps try_table throw when catch tag differs" {
  let body = TExpr::new([
    TInstr::try_table(
      BlockType::void_(),
      [Catch::new(TagIdx::new(1), LabelIdx::new(0))],
      TExpr::new([TInstr::throw_(TagIdx::new(0), [])]),
    ),
  ])
  let mod = rub_single_void_func_module_with_tags([], body, [[], []])
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TTryTable(
              _,
              _,
              { instrs: [{ kind: TInstrKind::TThrow(TagIdx(0U), []), .. }], .. }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected mismatched try_table catch to preserve throw")
  }
}

///|
test "remove_unused_brs rewrites try_table throw to branch for catch_ref when payload empty" {
  let tag_type = RecType::new(SubType::comp_type(CompType::func([], [])))
  let exnref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::exn())),
  )
  let main_type = RecType::new(SubType::comp_type(CompType::func([], [exnref])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([tag_type, main_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(0))]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::try_table(
              BlockType::type_idx(TypeIdx::new(1)),
              [Catch::ref_(TagIdx::new(0), LabelIdx::new(1))],
              TExpr::new([TInstr::throw_(TagIdx::new(0), [])]),
            ),
          ]),
        ),
      ]),
    )
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TTryTable(
              _,
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBr(
                      _,
                      [{ kind: TInstrKind::TBlock(_, _), .. }]
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected catch_ref try_table throw to rewrite to branch carrying materialized exnref when payload is empty",
      )
  }
}

///|
test "remove_unused_brs rewrites try_table throw to branch for catch_ref with payload values via local_tee" {
  let tag_type = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let exnref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::exn())),
  )
  let main_type = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32(), exnref])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([tag_type, main_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(0))]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::try_table(
              BlockType::type_idx(TypeIdx::new(1)),
              [Catch::ref_(TagIdx::new(0), LabelIdx::new(1))],
              TExpr::new([
                TInstr::throw_(TagIdx::new(0), [TInstr::i32_const(I32(9))]),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      locals,
      {
        instrs: [
          {
            kind: TInstrKind::TTryTable(
              _,
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBr(
                      _,
                      [
                        {
                          kind: TInstrKind::TLocalTee(
                            LocalIdx(0U),
                            { kind: TInstrKind::TI32Const(I32(9)), .. }
                          ),
                          ..,
                        },
                        { kind: TInstrKind::TBlock(_, _), .. },
                      ]
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(locals, [ValType::i32()])
    _ =>
      fail(
        "expected catch_ref try_table throw with payload to rewrite to a branch carrying payload+materialized exnref",
      )
  }
}

///|
test "remove_unused_brs rewrites multi-instr throw under catch_ref with payload values via local_tee" {
  let tag_type = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let exnref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::exn())),
  )
  let main_type = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32(), exnref])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([tag_type, main_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(0))]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::try_table(
              BlockType::type_idx(TypeIdx::new(1)),
              [Catch::ref_(TagIdx::new(0), LabelIdx::new(1))],
              TExpr::new([
                TInstr::drop(TInstr::i32_const(I32(1))),
                TInstr::throw_(TagIdx::new(0), [TInstr::i32_const(I32(5))]),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      locals,
      {
        instrs: [
          {
            kind: TInstrKind::TTryTable(
              _,
              _,
              {
                instrs: [
                  _,
                  {
                    kind: TInstrKind::TBr(
                      _,
                      [
                        {
                          kind: TInstrKind::TLocalTee(
                            LocalIdx(0U),
                            { kind: TInstrKind::TI32Const(I32(5)), .. }
                          ),
                          ..,
                        },
                        { kind: TInstrKind::TBlock(_, _), .. },
                      ]
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(locals, [ValType::i32()])
    _ =>
      fail(
        "expected multi-instr throw under catch_ref with payload to rewrite to payload+materialized-exnref branch",
      )
  }
}

///|
test "remove_unused_brs rewrites try_table throw to branch for catch_all_ref via exnref materialization" {
  let tag_type = RecType::new(SubType::comp_type(CompType::func([], [])))
  let exnref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::exn())),
  )
  let main_type = RecType::new(SubType::comp_type(CompType::func([], [exnref])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([tag_type, main_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(0))]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::try_table(
              BlockType::type_idx(TypeIdx::new(1)),
              [Catch::all_ref(LabelIdx::new(1))],
              TExpr::new([TInstr::throw_(TagIdx::new(0), [])]),
            ),
          ]),
        ),
      ]),
    )
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TTryTable(
              _,
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBr(
                      _,
                      [{ kind: TInstrKind::TBlock(_, _), .. }]
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected catch_all_ref try_table throw to rewrite to branch carrying materialized exnref",
      )
  }
}

///|
test "remove_unused_brs rewrites throw_ref under catch_ref when exnref is statically materialized from matching throw" {
  let tag_type = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let exnref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::exn())),
  )
  let main_type = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32(), exnref])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([tag_type, main_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(0))]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::try_table(
              BlockType::type_idx(TypeIdx::new(1)),
              [Catch::ref_(TagIdx::new(0), LabelIdx::new(1))],
              TExpr::new([
                TInstr::throw_ref(
                  rub_materialize_exnref_from_throw(TagIdx::new(0), [
                    TInstr::i32_const(I32(11)),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      locals,
      {
        instrs: [
          {
            kind: TInstrKind::TTryTable(
              _,
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBr(
                      _,
                      [
                        {
                          kind: TInstrKind::TLocalTee(
                            LocalIdx(0U),
                            { kind: TInstrKind::TI32Const(I32(11)), .. }
                          ),
                          ..,
                        },
                        { kind: TInstrKind::TBlock(_, _), .. },
                      ]
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(locals, [ValType::i32()])
    _ =>
      fail(
        "expected throw_ref with statically-materialized matching exnref to rewrite through catch_ref",
      )
  }
}

///|
test "remove_unused_brs rewrites multi-instr throw when enclosing catcher is catch_ref and payload empty" {
  let tag_type = RecType::new(SubType::comp_type(CompType::func([], [])))
  let exnref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::exn())),
  )
  let main_type = RecType::new(SubType::comp_type(CompType::func([], [exnref])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([tag_type, main_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(0))]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::try_table(
              BlockType::type_idx(TypeIdx::new(1)),
              [Catch::ref_(TagIdx::new(0), LabelIdx::new(1))],
              TExpr::new([
                TInstr::drop(TInstr::i32_const(I32(1))),
                TInstr::throw_(TagIdx::new(0), []),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TTryTable(
              _,
              _,
              {
                instrs: [
                  _,
                  {
                    kind: TInstrKind::TBr(
                      _,
                      [{ kind: TInstrKind::TBlock(_, _), .. }]
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected multi-instr throw under catch_ref to rewrite to branch carrying materialized exnref when payload is empty",
      )
  }
}

///|
test "remove_unused_brs rewrites multi-instr throw when enclosing catcher is catch_all_ref" {
  let tag_type = RecType::new(SubType::comp_type(CompType::func([], [])))
  let exnref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::exn())),
  )
  let main_type = RecType::new(SubType::comp_type(CompType::func([], [exnref])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([tag_type, main_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(0))]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::try_table(
              BlockType::type_idx(TypeIdx::new(1)),
              [Catch::all_ref(LabelIdx::new(1))],
              TExpr::new([
                TInstr::drop(TInstr::i32_const(I32(1))),
                TInstr::throw_(TagIdx::new(0), []),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TTryTable(
              _,
              _,
              {
                instrs: [
                  _,
                  {
                    kind: TInstrKind::TBr(
                      _,
                      [{ kind: TInstrKind::TBlock(_, _), .. }]
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected multi-instr throw under catch_all_ref to rewrite to branch carrying materialized exnref",
      )
  }
}

///|
test "remove_unused_brs is idempotent" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::if_(
          BlockType::void_(),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([TInstr::br(LabelIdx::new(1), [])]),
          None,
        ),
        TInstr::nop(),
      ]),
    ),
  ])
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], [ValType::i32()], body)]),
  )
  let once = rub_run(mod)
  let twice = rub_run(once)
  assert_eq(once, twice)
}

///|
test "remove_unused_brs does not splice value-typed if with else br" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::val_type(ValType::i32()),
      TExpr::new([
        TInstr::if_(
          BlockType::val_type(ValType::i32()),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([TInstr::i32_const(I32(1))]),
          Some(
            TExpr::new([
              TInstr::br(LabelIdx::new(0), [TInstr::i32_const(I32(2))]),
            ]),
          ),
        ),
      ]),
    ),
  ])
  let mod = rub_single_typed_func_module(
    [ValType::i32()],
    [ValType::i32()],
    body,
  )
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              ValTypeBlockType(_),
              {
                instrs: [
                  {
                    kind: TInstrKind::TIf(ValTypeBlockType(_), _, _, Some(_)),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected value-typed if with else br to remain structured")
  }
}

///|
test "remove_unused_brs does not splice void if in value-typed block body" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::val_type(ValType::i32()),
      TExpr::new([
        TInstr::if_(
          BlockType::void_(),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([TInstr::nop()]),
          Some(
            TExpr::new([
              TInstr::br(LabelIdx::new(1), [TInstr::i32_const(I32(2))]),
            ]),
          ),
        ),
        TInstr::i32_const(I32(1)),
      ]),
    ),
  ])
  let mod = rub_single_typed_func_module(
    [ValType::i32()],
    [ValType::i32()],
    body,
  )
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              ValTypeBlockType(_),
              {
                instrs: [
                  { kind: TInstrKind::TIf(VoidBlockType, _, _, Some(_)), .. },
                  { kind: TInstrKind::TI32Const(I32(1)), .. },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected void if in value-typed block body to remain structured")
  }
}

///|
test "remove_unused_brs does not splice value-typed if with then br" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::val_type(ValType::i32()),
      TExpr::new([
        TInstr::if_(
          BlockType::val_type(ValType::i32()),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([TInstr::br(LabelIdx::new(0), [TInstr::i32_const(I32(1))])]),
          Some(TExpr::new([TInstr::i32_const(I32(2))])),
        ),
      ]),
    ),
  ])
  let mod = rub_single_typed_func_module(
    [ValType::i32()],
    [ValType::i32()],
    body,
  )
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              ValTypeBlockType(_),
              {
                instrs: [
                  {
                    kind: TInstrKind::TIf(ValTypeBlockType(_), _, _, Some(_)),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected value-typed if with then br to remain structured")
  }
}

///|
test "remove_unused_brs is idempotent for value-typed if with else br" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::val_type(ValType::i32()),
      TExpr::new([
        TInstr::if_(
          BlockType::val_type(ValType::i32()),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([TInstr::i32_const(I32(1))]),
          Some(
            TExpr::new([
              TInstr::br(LabelIdx::new(0), [TInstr::i32_const(I32(2))]),
            ]),
          ),
        ),
      ]),
    ),
  ])
  let mod = rub_single_typed_func_module(
    [ValType::i32()],
    [ValType::i32()],
    body,
  )
  let once = rub_run(mod)
  let twice = rub_run(once)
  rub_assert_valid_module(twice)
  assert_eq(once, twice)
}
