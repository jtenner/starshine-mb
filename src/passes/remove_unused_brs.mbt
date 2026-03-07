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
fn rub_trace_noop(_ : String) -> Unit {
  ()
}

///|
fn rub_trace_should_log_func(ordinal : Int, trace_all_funcs : Bool) -> Bool {
  trace_all_funcs || ordinal <= 5 || ordinal % 250 == 0
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
  if !trace_state.log_func {
    return
  }
  (trace_state.trace)(
    "func[\{trace_state.ordinal}] round[\{trace_state.round}] walk:start top_instrs=\{top_instrs}",
  )
  (trace_state.trace)(
    "func[\{trace_state.ordinal}] round[\{trace_state.round}] progress phase=walk:start elapsed_ms=\{sl_trace_elapsed_ms(trace_state.func_start_ms)} round_ms=\{sl_trace_elapsed_ms(trace_state.round_start_ms)} exprs=0 instrs=0 rewrites=0",
  )
  let now_ms = sl_trace_now_ms()
  trace_state.last_progress_ms.val = now_ms
  trace_state.no_progress_deadline_ms.val = now_ms +
    RUB_TRACE_NO_PROGRESS_TIMEOUT_MS
}

///|
fn rub_trace_maybe_emit_progress(
  trace_state : RUBRoundTraceState,
  phase : String,
) -> Unit {
  if !trace_state.log_func {
    return
  }

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

  (trace_state.trace)(
    "func[\{trace_state.ordinal}] round[\{trace_state.round}] progress phase=\{phase} elapsed_ms=\{sl_trace_elapsed_ms(trace_state.func_start_ms)} round_ms=\{sl_trace_elapsed_ms(trace_state.round_start_ms)} exprs=\{expr_visits} instrs=\{instr_visits} rewrites=\{rewrites}",
  )
  trace_state.last_progress_ms.val = now_ms
  trace_state.no_progress_deadline_ms.val = now_ms +
    RUB_TRACE_NO_PROGRESS_TIMEOUT_MS
}

///|
fn rub_trace_check_no_progress(
  trace_state : RUBRoundTraceState?,
  phase : String,
) -> Result[Unit, String] {
  match trace_state {
    Some(trace_state) => {
      if !trace_state.log_func {
        return Ok(())
      }
      let now_ms = sl_trace_now_ms()
      if now_ms <= trace_state.no_progress_deadline_ms.val {
        return Ok(())
      }
      (trace_state.trace)(
        "func[\{trace_state.ordinal}] round[\{trace_state.round}] abort reason=no_progress_timeout phase=\{phase} elapsed_ms=\{sl_trace_elapsed_ms(trace_state.func_start_ms)} round_ms=\{sl_trace_elapsed_ms(trace_state.round_start_ms)} exprs=\{trace_state.expr_visits.val} instrs=\{trace_state.instr_visits.val} rewrites=\{trace_state.rewrites.val}",
      )
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
      if !trace_state.log_func {
        return Ok(())
      }
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
      if !trace_state.log_func {
        return Ok(())
      }
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
      if !trace_state.log_func {
        return Ok(())
      }
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
}

///|
fn rub_walk_state(
  in_function_body : Bool,
  allow_list_splicing : Bool,
  zero_break_is_fallthrough : Bool,
  label_depth? : Int = 0,
  catchers? : Array[RUBTryTableCatcher] = [],
) -> RUBWalkState {
  {
    in_function_body,
    allow_list_splicing,
    zero_break_is_fallthrough,
    label_depth,
    catchers,
  }
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
      )
    _ =>
      rub_walk_state(
        false,
        false,
        zero_break_is_fallthrough,
        label_depth=parent.label_depth + 1,
        catchers=parent.catchers,
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
  )
}

///|
fn ModuleTransformer::rub_walk_tinstruction_result(
  self : ModuleTransformer[RUBWalkState],
  state : RUBWalkState,
  instr : TInstr,
) -> Result[TInstr, String] {
  match self.walk_tinstruction(state, instr) {
    Ok(Some((_, next_instr))) => Ok(next_instr)
    Ok(None) => Ok(instr)
    Err(e) => Err(e)
  }
}

///|
fn ModuleTransformer::rub_walk_texpr_result(
  self : ModuleTransformer[RUBWalkState],
  state : RUBWalkState,
  expr : TExpr,
) -> Result[TExpr, String] {
  match self.walk_texpr(state, expr) {
    Ok(Some((_, next_expr))) => Ok(next_expr)
    Ok(None) => Ok(expr)
    Err(e) => Err(e)
  }
}

///|
fn ModuleTransformer::rub_walk_blocktype_result(
  self : ModuleTransformer[RUBWalkState],
  state : RUBWalkState,
  bt : BlockType,
) -> Result[BlockType, String] {
  match self.walk_blocktype(state, bt) {
    Ok(Some((_, next_bt))) => Ok(next_bt)
    Ok(None) => Ok(bt)
    Err(e) => Err(e)
  }
}

///|
fn ModuleTransformer::rub_walk_catches_result(
  self : ModuleTransformer[RUBWalkState],
  state : RUBWalkState,
  catches : Array[Catch],
) -> Result[Array[Catch], String] {
  match self.walk_array(state, ModuleTransformer::walk_catch, catches) {
    Ok(Some((_, next_catches))) => Ok(next_catches)
    Ok(None) => Ok(catches)
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
  transformer : ModuleTransformer[Int],
  depth : Int,
  instr : TInstr,
) -> TransformerResult[Int, TInstr] {
  match instr.kind {
    TInstrKind::TBlock(bt, body) => {
      let next_body = match transformer.walk_texpr(depth + 1, body) {
        Ok(Some((_, out))) => out
        Ok(None) => body
        Err(e) => return Err(e)
      }
      if next_body == body {
        unchanged()
      } else {
        change(depth, TInstr::block(bt, next_body))
      }
    }
    TInstrKind::TLoop(bt, body) => {
      let next_body = match transformer.walk_texpr(depth + 1, body) {
        Ok(Some((_, out))) => out
        Ok(None) => body
        Err(e) => return Err(e)
      }
      if next_body == body {
        unchanged()
      } else {
        change(depth, TInstr::loop_(bt, next_body))
      }
    }
    TInstrKind::TIf(bt, cond, then_body, else_body) => {
      let next_cond = match transformer.walk_tinstruction(depth, cond) {
        Ok(Some((_, out))) => out
        Ok(None) => cond
        Err(e) => return Err(e)
      }
      let next_then = match transformer.walk_texpr(depth + 1, then_body) {
        Ok(Some((_, out))) => out
        Ok(None) => then_body
        Err(e) => return Err(e)
      }
      let next_else = match else_body {
        Some(other) =>
          match transformer.walk_texpr(depth + 1, other) {
            Ok(Some((_, out))) => Some(out)
            Ok(None) => Some(other)
            Err(e) => return Err(e)
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
        Ok(Some((_, out))) => out
        Ok(None) => catches
        Err(e) => return Err(e)
      }
      let next_body = match transformer.walk_texpr(depth + 1, body) {
        Ok(Some((_, out))) => out
        Ok(None) => body
        Err(e) => return Err(e)
      }
      let next_instr = TInstr::try_table(bt, next_catches, next_body)
      if next_instr == instr {
        unchanged()
      } else {
        change(depth, next_instr)
      }
    }
    _ => transformer.walk_tinstruction_default(depth, instr)
  }
}

///|
fn rub_rebase_labels_in_texpr_result(
  expr : TExpr,
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
        Err(e) => Err(e)
      }
    })
    .on_tinstruction_evt(fn(self, depth, instr) {
      rub_walk_tinstruction_with_depth(self, depth, instr)
    })
  match pass.walk_texpr(0, expr) {
    Ok(Some((_, out))) => Ok(out)
    Ok(None) => Ok(expr)
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
        Err(e) => Err(e)
      }
    })
    .on_tinstruction_evt(fn(self, depth, curr) {
      rub_walk_tinstruction_with_depth(self, depth, curr)
    })
  match pass.walk_tinstruction(0, instr) {
    Ok(Some((_, out))) => Ok(out)
    Ok(None) => Ok(instr)
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
    TInstrKind::TIf(VoidBlockType, cond, _, Some(_)) => {
      let merged_flow = rub_terminal_flow_of_instr(instrs[idx])
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
fn rub_optimize_loop_tail_branches(
  instrs : Array[TInstr],
  zero_break_is_fallthrough : Bool,
) -> Bool {
  // Loop bodies are the only places where `br 0` is not fallthrough.
  if zero_break_is_fallthrough || instrs.length() == 0 {
    return false
  }
  if instrs.length() >= 2 {
    let second_last_i = instrs.length() - 2
    let last_i = instrs.length() - 1
    match (instrs[second_last_i].kind, instrs[last_i].kind) {
      (TInstrKind::TBrIf(exit_label, cond, []), TInstrKind::TBr(loop_label, [])) =>
        if rub_is_label_zero(loop_label) && !rub_is_label_zero(exit_label) {
          instrs[second_last_i] = TInstr::br_if(
            LabelIdx::new(0),
            TInstr::unary(UnaryOp::i32_eqz(), cond),
            [],
          )
          instrs[last_i] = TInstr::br(exit_label, [])
          return true
        }
      _ => ()
    }
  }

  let last_i = instrs.length() - 1
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
fn rub_optimize_single_if_void_block_wrapper(instr : TInstr) -> (TInstr, Bool) {
  match instr.kind {
    TInstrKind::TBlock(VoidBlockType, { instrs: [single], .. }) =>
      match single.kind {
        TInstrKind::TIf(VoidBlockType, _, _, Some(_))
        | TInstrKind::TLoop(VoidBlockType, _) =>
          match rub_try_rebase_labels_in_tinstruction(single, -1) {
            Some(next_single) => (next_single, true)
            None => (instr, false)
          }
        _ => (instr, false)
      }
    _ => (instr, false)
  }
}

///|
fn rub_optimize_jump_thread_block_wrapper(instr : TInstr) -> (TInstr, Bool) {
  match instr.kind {
    TInstrKind::TBlock(
      VoidBlockType,
      { instrs: [{ kind: TInstrKind::TBr(label, []), .. }], .. }
    ) =>
      if rub_is_label_zero(label) {
        (TInstr::nop(), true)
      } else {
        (TInstr::br(rub_label_from_int(rub_label_to_int(label) - 1), []), true)
      }
    TInstrKind::TBlock(
      VoidBlockType,
      { instrs: [{ kind: TInstrKind::TBrIf(label, cond, []), .. }], .. }
    ) =>
      if rub_is_label_zero(label) {
        (TInstr::drop(cond), true)
      } else {
        (
          TInstr::br_if(rub_label_from_int(rub_label_to_int(label) - 1), cond, []),
          true,
        )
      }
    _ => (instr, false)
  }
}

///|
priv enum RUBTryTableThrowMatch {
  NoMatch
  MatchCatch(LabelIdx)
  MatchCatchAll(LabelIdx)
  MatchRef
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
      CatchRef(catch_tag, _) => if catch_tag == thrown_tag { return MatchRef }
      CatchAll(label) => return MatchCatchAll(label)
      CatchAllRef(_) => return MatchRef
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
          MatchRef =>
            // TODO(binaryen-parity): throw->branch for catch_ref/catch_all_ref
            // needs explicit exnref payload construction in this IR path.
            return (instr, false)
          NoMatch => ()
        }
      }
      (instr, false)
    }
    _ => (instr, false)
  }
}

///|
fn rub_optimize_try_table_throw_to_branch(instr : TInstr) -> (TInstr, Bool) {
  match instr.kind {
    TInstrKind::TTryTable(bt, catches, { instrs: [single], .. }) =>
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
            MatchRef | NoMatch =>
              // TODO(binaryen-parity): same exnref payload blocker as above.
              (instr, false)
          }
        _ => (instr, false)
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
        true
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
                    "site=\{i} has_branch=\{else_has_branch}",
                  )
                  if !else_has_branch {
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
                    "site=\{i} has_branch=\{then_has_branch}",
                  )
                  if !then_has_branch {
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
) -> ModuleTransformer[RUBWalkState] {
  ModuleTransformer::new()
  .on_func_evt(fn(self, state, func) {
    match func {
      TFunc(params, locals, body) => {
        let new_body = match
          self.walk_texpr(rub_walk_state(true, false, true), body) {
          Ok(Some((_, walked))) => walked
          Ok(None) => body
          Err(e) => return Err(e)
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
      Err(e) => return Err(e)
    }
    let out : Array[TInstr] = []
    let mut changed = false
    for instr in expr.instrs {
      let next_instr = match self.walk_tinstruction(state, instr) {
        Ok(Some((_, walked))) => walked
        Ok(None) => instr
        Err(e) => return Err(e)
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
        Err(e) => return Err(e)
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
      Err(e) => return Err(e)
    }
    let walked_start_ms = sl_trace_now_ms()
    let walked = match instr.kind {
      TInstrKind::TBlock(bt, body) => {
        let next_bt = match self.rub_walk_blocktype_result(state, bt) {
          Ok(next_bt) => next_bt
          Err(e) => return Err(e)
        }
        let next_body = match
          self.rub_walk_texpr_result(
            rub_walk_nested_texpr_state(state, next_bt, true),
            body,
          ) {
          Ok(next_body) => next_body
          Err(e) => return Err(e)
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
          Err(e) => return Err(e)
        }
        let next_body = match
          self.rub_walk_texpr_result(
            rub_walk_nested_texpr_state(state, next_bt, false),
            body,
          ) {
          Ok(next_body) => next_body
          Err(e) => return Err(e)
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
          Err(e) => return Err(e)
        }
        let next_cond = match self.rub_walk_tinstruction_result(state, cond) {
          Ok(next_cond) => next_cond
          Err(e) => return Err(e)
        }
        let branch_state = rub_walk_nested_texpr_state(state, next_bt, true)
        let next_then = match
          self.rub_walk_texpr_result(branch_state, then_body) {
          Ok(next_then) => next_then
          Err(e) => return Err(e)
        }
        let next_else = match else_body {
          Some(other) =>
            match self.rub_walk_texpr_result(branch_state, other) {
              Ok(next_other) => Some(next_other)
              Err(e) => return Err(e)
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
          Err(e) => return Err(e)
        }
        let next_catches = match self.rub_walk_catches_result(state, catches) {
          Ok(next_catches) => next_catches
          Err(e) => return Err(e)
        }
        let catcher_state = rub_push_try_table_catcher(state, next_catches)
        let next_body = match
          self.rub_walk_texpr_result(
            rub_walk_nested_texpr_state(catcher_state, next_bt, true),
            body,
          ) {
          Ok(next_body) => next_body
          Err(e) => return Err(e)
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
          Ok(Some((_, updated))) => updated
          Ok(None) => instr
          Err(e) => return Err(e)
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
    )
    let (after_jump_thread, changed_jump_thread) = rub_optimize_jump_thread_block_wrapper(
      after_sink_block,
    )
    let (after_try_table_throw, changed_try_table_throw) = rub_optimize_try_table_throw_to_branch(
      after_jump_thread,
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
        Err(e) => return Err(e)
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
fn rub_optimize_func_fixpoint(
  func : Func,
  options : OptimizeOptions,
  trace? : (String) -> Unit = rub_trace_noop,
  ordinal? : Int = 0,
  trace_all_funcs? : Bool = false,
) -> Result[Func, String] {
  let log_func = rub_trace_should_log_func(ordinal, trace_all_funcs)
  match func {
    TFunc(_, locals, body) => {
      let start_top_instrs = body.instrs.length()
      let func_start_ms = sl_trace_now_ms()
      if log_func {
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
        match pass.walk_func(rub_walk_state(false, false, true), curr) {
          Ok(Some((_, next_func))) => {
            let next_top_instrs = match next_func {
              TFunc(_, _, next_body) => next_body.instrs.length()
              _ => round_start_top_instrs
            }
            if log_func {
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
          Ok(None) => {
            if log_func {
              trace(
                "func[\{ordinal}] round[\{rounds}] walk:done elapsed_ms=\{sl_trace_elapsed_ms(round_trace.round_start_ms)} changed=false top_instrs=\{round_start_top_instrs}->\{round_start_top_instrs} exprs=\{round_trace.expr_visits.val} instrs=\{round_trace.instr_visits.val} rewrites=\{round_trace.rewrites.val}",
              )
            }
            hit_round_limit = false
            break
          }
          Err(e) => {
            if e == RUB_NO_PROGRESS_TIMEOUT {
              hit_round_limit = false
              stalled_reason = Some("no_progress_timeout")
              break
            }
            if log_func {
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
      let env = Env::new().with_module(mod).with_locals(locals)
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
fn remove_unused_brs(
  mod : Module,
  options? : OptimizeOptions = OptimizeOptions::new(),
  trace? : (String) -> Unit = rub_trace_noop,
  trace_all_funcs? : Bool = false,
) -> Result[Module, String] {
  let next_ordinal = Ref::new(0)
  let pass = ModuleTransformer::new().on_func_evt(fn(_, state, func) {
    next_ordinal.val += 1
    let ordinal = next_ordinal.val
    match
      rub_optimize_func_fixpoint(
        func,
        options,
        trace~,
        ordinal~,
        trace_all_funcs~,
      ) {
      Ok(next_func) => {
        let finalized_func = if next_func == func {
          next_func
        } else {
          rub_refinalize_changed_func(next_func, mod)
        }
        if finalized_func == func {
          unchanged()
        } else {
          change(state, finalized_func)
        }
      }
      Err(e) => Err(e)
    }
  })
  let out = match pass.walk_module(rub_walk_state(false, false, true), mod) {
    Ok(Some((_, out))) => out
    Ok(None) => mod
    Err(e) => return Err(e)
  }
  Ok(out)
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
test "remove_unused_brs traces function phases and rounds" {
  let trace_logs : Array[String] = []
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([TInstr::br(LabelIdx::new(0), [])]),
    ),
  ])
  let mod = rub_single_void_func_module([], body)
  match
    remove_unused_brs(
      mod,
      trace=fn(msg) { trace_logs.push(msg) },
      trace_all_funcs=true,
    ) {
    Ok(_) => ()
    Err(e) => fail("unexpected remove_unused_brs trace error: \{e}")
  }

  let mut saw_func_start = false
  let mut saw_candidate_scan = false
  let mut saw_round_start = false
  let mut saw_round_progress = false
  let mut saw_round_done = false
  let mut saw_func_done = false
  for msg in trace_logs {
    if msg.contains("func[1] start") {
      saw_func_start = true
    }
    if msg.contains("func[1] phase=candidate_scan done") {
      saw_candidate_scan = true
    }
    if msg.contains("func[1] round[1] walk:start") {
      saw_round_start = true
    }
    if msg.contains("func[1] round[1] progress phase=walk:start") {
      saw_round_progress = true
    }
    if msg.contains("func[1] round[1] walk:done") {
      saw_round_done = true
    }
    if msg.contains("func[1] done") {
      saw_func_done = true
    }
  }
  assert_true(saw_func_start)
  assert_false(saw_candidate_scan)
  assert_true(saw_round_start)
  assert_true(saw_round_progress)
  assert_true(saw_round_done)
  assert_true(saw_func_done)
}

///|
test "remove_unused_brs skips trace callbacks for non-logged function ordinals" {
  let trace_logs : Array[String] = []
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::if_(
          BlockType::void_(),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([TInstr::br(LabelIdx::new(0), [])]),
          Some(TExpr::new([TInstr::nop()])),
        ),
      ]),
    ),
  ])
  let func = Func::t_func([ValType::i32()], [], body)
  match
    rub_optimize_func_fixpoint(
      func,
      OptimizeOptions::new(),
      trace=fn(msg) { trace_logs.push(msg) },
      ordinal=6,
      trace_all_funcs=false,
    ) {
    Ok(_) => ()
    Err(e) => fail("unexpected remove_unused_brs trace gate error: \{e}")
  }
  assert_eq(trace_logs.length(), 0)
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
                      { kind: TInstrKind::TLocalGet(_), .. },
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
    ) => assert_eq(label, LabelIdx::new(0))
    _ =>
      fail(
        "expected nested one-armed if to keep a valid rebased inner br_if when the outer-scope branch cannot be hoisted",
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
                  { kind: TInstrKind::TI32Const(I32(2)), .. },
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
            kind: TInstrKind::TDrop(
              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. }
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
      fail("expected single-br_if label0 wrapper to thread to drop(condition)")
  }
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
test "remove_unused_brs keeps try_table throw when matching catcher is catch_ref" {
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
              { instrs: [{ kind: TInstrKind::TThrow(TagIdx(0U), []), .. }], .. }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected catch_ref try_table to preserve throw (rewriting requires exnref payload synthesis)",
      )
  }
}

///|
test "remove_unused_brs keeps try_table throw when matching catcher is catch_all_ref" {
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
              { instrs: [{ kind: TInstrKind::TThrow(TagIdx(0U), []), .. }], .. }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected catch_all_ref try_table to preserve throw (rewriting requires exnref payload synthesis)",
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
