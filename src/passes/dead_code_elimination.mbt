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
const DCE_PROGRESS_LOG_INTERVAL_US : UInt64 = 250000UL

///|
priv struct DCEPassTraceState {
  enabled : Bool
  trace : (String) -> Unit
  trace_all_funcs : Bool
  func_ordinal : Ref[Int]
  func_locals : Ref[Int]
  func_top_instrs : Ref[Int]
  func_start_us : Ref[UInt64]
  last_progress_us : Ref[UInt64]
  expr_visits : Ref[Int]
  instr_visits : Ref[Int]
  break_checks : Ref[Int]
  unreachable_checks : Ref[Int]
  budget_hits : Ref[Int]
  rewrites : Ref[Int]
}

///|
fn dead_code_elimination_trace_noop(_ : String) -> Unit {
  ()
}

///|
fn dce_trace_state_new(
  trace : (String) -> Unit,
  trace_all_funcs : Bool,
) -> DCEPassTraceState {
  {
    enabled: true,
    trace,
    trace_all_funcs,
    func_ordinal: Ref::new(0),
    func_locals: Ref::new(0),
    func_top_instrs: Ref::new(0),
    func_start_us: Ref::new(0UL),
    last_progress_us: Ref::new(0UL),
    expr_visits: Ref::new(0),
    instr_visits: Ref::new(0),
    break_checks: Ref::new(0),
    unreachable_checks: Ref::new(0),
    budget_hits: Ref::new(0),
    rewrites: Ref::new(0),
  }
}

///|
fn dce_trace_state_noop() -> DCEPassTraceState {
  {
    enabled: false,
    trace: dead_code_elimination_trace_noop,
    trace_all_funcs: false,
    func_ordinal: Ref::new(0),
    func_locals: Ref::new(0),
    func_top_instrs: Ref::new(0),
    func_start_us: Ref::new(0UL),
    last_progress_us: Ref::new(0UL),
    expr_visits: Ref::new(0),
    instr_visits: Ref::new(0),
    break_checks: Ref::new(0),
    unreachable_checks: Ref::new(0),
    budget_hits: Ref::new(0),
    rewrites: Ref::new(0),
  }
}

///|
fn dce_trace_delta_us_to_ms(delta_us : UInt64) -> UInt64 {
  delta_us / 1000UL
}

///|
#cfg(target="native")
#borrow(tv)
extern "c" fn dce_native_gettimeofday(tv : Bytes, tz : UInt64) -> Int = "gettimeofday"

///|
#cfg(target="native")
fn dce_trace_read_u64_le(bytes : Bytes, start : Int) -> UInt64 {
  let mut out = 0UL
  let mut i = 0
  while i < 8 {
    out = out | (bytes[start + i].to_uint64() << (i * 8))
    i += 1
  }
  out
}

///|
#cfg(target="native")
fn dce_trace_now_us() -> UInt64 {
  let tv = Bytes::new(16)
  if dce_native_gettimeofday(tv, 0UL) != 0 {
    return @env.now() * 1000UL
  }
  let sec = dce_trace_read_u64_le(tv, 0)
  let usec = dce_trace_read_u64_le(tv, 8)
  sec * 1000000UL + usec
}

///|
#cfg(target="wasm-gc")
fn dce_trace_now_us() -> UInt64 {
  @env.now() * 1000UL
}

///|
#cfg(target="wasm")
fn dce_trace_now_us() -> UInt64 {
  @env.now() * 1000UL
}

///|
#cfg(target="js")
fn dce_trace_now_us() -> UInt64 {
  @env.now() * 1000UL
}

///|
#cfg(target="llvm")
fn dce_trace_now_us() -> UInt64 {
  @env.now() * 1000UL
}

///|
fn dce_trace_elapsed_us_since(start_us : UInt64) -> UInt64 {
  let end_us = dce_trace_now_us()
  if end_us >= start_us {
    end_us - start_us
  } else {
    0UL
  }
}

///|
fn dce_trace_should_log_func(trace_state : DCEPassTraceState) -> Bool {
  trace_state.enabled &&
  (
    trace_state.trace_all_funcs ||
    trace_state.func_ordinal.val <= 5 ||
    trace_state.func_ordinal.val % 250 == 0
  )
}

///|
fn dce_trace_start_func(
  trace_state : DCEPassTraceState,
  locals : Int,
  top_instrs : Int,
  skip : Bool,
  break_scan_budget : Ref[Int],
) -> Unit {
  trace_state.func_ordinal.val += 1
  trace_state.func_locals.val = locals
  trace_state.func_top_instrs.val = top_instrs
  trace_state.func_start_us.val = dce_trace_now_us()

  // Sentinel meaning "no progress emitted yet".
  trace_state.last_progress_us.val = 0UL

  trace_state.expr_visits.val = 0
  trace_state.instr_visits.val = 0
  trace_state.break_checks.val = 0
  trace_state.unreachable_checks.val = 0
  trace_state.budget_hits.val = 0
  trace_state.rewrites.val = 0

  // Reset analysis budget per function. If we skip, budget is 0.
  if skip {
    break_scan_budget.val = 0
  } else {
    let base = 100_000
    let scaled = base + top_instrs * 2
    let capped = if scaled > 3_000_000 { 3_000_000 } else { scaled }
    break_scan_budget.val = capped
  }

  if dce_trace_should_log_func(trace_state) {
    // Start log
    (trace_state.trace)(
      "func[\{trace_state.func_ordinal.val}]:start locals=\{locals} top_instrs=\{top_instrs} skip=\{skip} budget=\{break_scan_budget.val}",
    )

    // Deterministic first progress log (important for wasm-gc where time may not advance).
    let now_us = dce_trace_now_us()
    (trace_state.trace)(
      "func[\{trace_state.func_ordinal.val}]:progress phase=start elapsed_ms=\{dce_trace_delta_us_to_ms(dce_trace_elapsed_us_since(trace_state.func_start_us.val))} exprs=\{trace_state.expr_visits.val} instrs=\{trace_state.instr_visits.val} unreachable_checks=\{trace_state.unreachable_checks.val} break_checks=\{trace_state.break_checks.val} rewrites=\{trace_state.rewrites.val} budget=\{break_scan_budget.val} budget_hits=\{trace_state.budget_hits.val}",
    )
    trace_state.last_progress_us.val = now_us
  }
}

///|
fn dce_trace_maybe_emit_progress(
  trace_state : DCEPassTraceState,
  phase : String,
  break_scan_budget : Ref[Int],
) -> Unit {
  if !dce_trace_should_log_func(trace_state) {
    return
  }

  let now_us = dce_trace_now_us()

  let expr_visits = trace_state.expr_visits.val
  let instr_visits = trace_state.instr_visits.val
  let break_checks = trace_state.break_checks.val
  let unreachable_checks = trace_state.unreachable_checks.val

  let did_some_work = expr_visits +
    instr_visits +
    break_checks +
    unreachable_checks

  // last_progress_us == 0UL means "haven't emitted progress yet"
  let has_emitted_progress = trace_state.last_progress_us.val != 0UL

  let since_last_us = if has_emitted_progress &&
    now_us >= trace_state.last_progress_us.val {
    now_us - trace_state.last_progress_us.val
  } else {
    0UL
  }

  // Emit *one* early progress line once we’ve done a bit of work,
  // even if the clock hasn't advanced (important for wasm-gc).
  let should_emit_first = !has_emitted_progress && did_some_work >= 16

  let should_emit_periodic = (
      expr_visits > 0 &&
      ((expr_visits <= 128 && expr_visits % 32 == 0) || expr_visits % 1024 == 0)
    ) ||
    (
      instr_visits > 0 &&
      (
        (instr_visits <= 256 && instr_visits % 64 == 0) ||
        instr_visits % 2048 == 0
      )
    ) ||
    (
      break_checks > 0 &&
      (
        (break_checks <= 256 && break_checks % 64 == 0) ||
        break_checks % 4096 == 0
      )
    )

  let should_emit_time = has_emitted_progress &&
    since_last_us >= DCE_PROGRESS_LOG_INTERVAL_US

  if !(should_emit_first || should_emit_periodic || should_emit_time) {
    return
  }

  (trace_state.trace)(
    "func[\{trace_state.func_ordinal.val}]:progress phase=\{phase} elapsed_ms=\{dce_trace_delta_us_to_ms(dce_trace_elapsed_us_since(trace_state.func_start_us.val))} exprs=\{expr_visits} instrs=\{instr_visits} unreachable_checks=\{unreachable_checks} break_checks=\{break_checks} rewrites=\{trace_state.rewrites.val} budget=\{break_scan_budget.val} budget_hits=\{trace_state.budget_hits.val}",
  )

  trace_state.last_progress_us.val = now_us
}

///|
fn dce_trace_record_rewrite(
  trace_state : DCEPassTraceState,
  phase : String,
  break_scan_budget : Ref[Int],
) -> Unit {
  if !dce_trace_should_log_func(trace_state) {
    return
  }
  trace_state.rewrites.val += 1
  if trace_state.trace_all_funcs ||
    trace_state.rewrites.val <= 5 ||
    trace_state.rewrites.val % 32 == 0 {
    (trace_state.trace)(
      "func[\{trace_state.func_ordinal.val}]:rewrite phase=\{phase} count=\{trace_state.rewrites.val} instrs=\{trace_state.instr_visits.val} break_checks=\{trace_state.break_checks.val} budget=\{break_scan_budget.val}",
    )
    trace_state.last_progress_us.val = dce_trace_now_us()
  }
}

///|
fn dead_code_elimination_pass_with_trace(
  trace? : (String) -> Unit = dead_code_elimination_trace_noop,
  trace_all_funcs? : Bool = false,
) -> ModuleTransformer[Unit] {
  // Shared per-function budget ref (reset at func start).
  let break_scan_budget = Ref::new(200_000)
  let skip_current_func = Ref::new(false)
  let trace_state = dce_trace_state_new(trace, trace_all_funcs)

  ModuleTransformer::new()
  .on_func_evt(fn(_, ctx, func) {
    match func {
      TFunc(locals, body) => {
        // Compute a capped nested-size estimate once.
        let nested = dce_count_instrs_capped(body, 250_000)

        // Skip giant functions early: DCE is not worth it and will thrash.
        // Tune thresholds to your workload.
        skip_current_func.val = locals.length() > 256 || nested > 250_000

        // Pass "nested" as top_instrs for budgeting/logging (not body.instrs.length()).
        dce_trace_start_func(
          trace_state,
          locals.length(),
          nested,
          skip_current_func.val,
          break_scan_budget,
        )
      }
      _ => {
        skip_current_func.val = false
        dce_trace_start_func(trace_state, 0, 0, false, break_scan_budget)
      }
    }

    if skip_current_func.val {
      change(ctx, func)
    } else {
      unchanged()
    }
  })
  .on_texpr_evt(fn(transformer, ctx, expr) {
    if skip_current_func.val {
      unchanged()
    } else {
      dce_texpr(transformer, ctx, expr, break_scan_budget, trace_state)
    }
  })
  .on_tinstruction_evt(fn(transformer, ctx, instr) {
    if skip_current_func.val {
      unchanged()
    } else {
      dce_tinstr(transformer, ctx, instr, break_scan_budget, trace_state)
    }
  })
}

///|
fn dead_code_elimination_pass() -> ModuleTransformer[Unit] {
  dead_code_elimination_pass_with_trace()
}

///|
fn dead_code_elimination_ir_pass(_mod : Module) -> ModuleTransformer[IRContext] {
  wrap_unit_func_pass(dead_code_elimination_pass())
}

///|
fn dce_texpr(
  transformer : ModuleTransformer[Unit],
  _ctx : Unit,
  expr : TExpr,
  break_scan_budget : Ref[Int],
  trace_state : DCEPassTraceState,
) -> TransformerResult[Unit, TExpr] {
  trace_state.expr_visits.val += 1
  dce_trace_maybe_emit_progress(trace_state, "texpr", break_scan_budget)

  // HARD BAIL: once the per-function analysis budget is exhausted,
  // do not traverse any deeper.
  if break_scan_budget.val <= 0 {
    return unchanged()
  }

  let { instrs, .. } = expr
  let out : Array[TInstr] = []
  let mut changed = false

  // "reachable" means the next instruction in this *sequence* is reachable
  // on at least one path (i.e., we haven't hit an unconditional terminator).
  let mut reachable = true

  for instr in instrs {
    if !reachable {
      changed = true
      continue
    }

    let new_instr = match transformer.walk_tinstruction((), instr) {
      Err(e) => return Err(e)
      Ok(None) => instr
      Ok(Some((_, updated))) => updated
    }

    if new_instr != instr {
      changed = true
    }
    out.push(new_instr)

    // After emitting this instruction, decide if the *sequence* can continue.
    // Important: this is about fallthrough to the *next instruction in the same TExpr*.
    let local_budget = dce_alloc_break_budget(break_scan_budget, 512)
    if dce_is_unreachable_instr(new_instr, local_budget, trace_state) {
      reachable = false
    }

    if break_scan_budget.val <= 0 {
      return if changed { change((), TExpr::new(out)) } else { unchanged() }
    }
  }

  if !changed {
    unchanged()
  } else {
    change((), TExpr::new(out))
  }
}

///|
fn dce_tinstr(
  transformer : ModuleTransformer[Unit],
  _ctx : Unit,
  instr : TInstr,
  break_scan_budget : Ref[Int],
  trace_state : DCEPassTraceState,
) -> TransformerResult[Unit, TInstr] {
  trace_state.instr_visits.val += 1
  dce_trace_maybe_emit_progress(trace_state, "instr", break_scan_budget)

  // HARD BAIL: once budget is exhausted, do not recurse.
  // This is the key fix: if we call walk_tinstruction_default here,
  // we keep descending forever with rewrites=0.
  if break_scan_budget.val <= 0 {
    return unchanged()
  }

  let walked = match transformer.walk_tinstruction_default((), instr) {
    Err(e) => return Err(e)
    Ok(None) => instr
    Ok(Some((_, updated))) => updated
  }

  let mut rewritten = walked

  // Control-flow-structure rewrites that need explicit handling.
  rewritten = match rewritten.kind {
    TInstrKind::TBlock(_, body) if is_single_unreachable_texpr(body) =>
      TInstr::unreachable_()
    TInstrKind::TIf(_, cond, _, _) => {
      let cond_budget = dce_alloc_break_budget(break_scan_budget, 512)
      if dce_is_unreachable_instr(cond, cond_budget, trace_state) {
        cond
      } else {
        rewritten
      }
    }
    TInstrKind::TLoop(_, body) if is_single_unreachable_texpr(body) =>
      TInstr::unreachable_()
    _ => rewritten
  }

  // Non-control unreachable operand rewrite (budgeted).
  if !is_control_flow_structure(rewritten) {
    let reach_budget = dce_alloc_break_budget(break_scan_budget, 512)
    let child_budget = dce_alloc_break_budget(break_scan_budget, 512)
    if dce_is_unreachable_instr(rewritten, reach_budget, trace_state) &&
      dce_has_unreachable_child(rewritten, child_budget, trace_state) {
      let rewrite_budget = dce_alloc_break_budget(break_scan_budget, 1024)
      rewritten = dce_rewrite_non_control_unreachable(
        rewritten, rewrite_budget, trace_state,
      )
    }
  }

  if rewritten == instr {
    unchanged()
  } else {
    dce_trace_record_rewrite(trace_state, "instr", break_scan_budget)
    change((), rewritten)
  }
}

///|
fn is_control_flow_structure(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TBlock(_, _)
    | TInstrKind::TLoop(_, _)
    | TInstrKind::TIf(_, _, _, _)
    | TInstrKind::TTryTable(_, _, _) => true
    _ => false
  }
}

///|
fn is_single_unreachable_texpr(expr : TExpr) -> Bool {
  let { instrs, .. } = expr
  match instrs {
    [{ kind: TInstrKind::TUnreachable, .. }] => true
    _ => false
  }
}

///|
fn dce_texpr_is_unreachable(
  expr : TExpr,
  break_scan_budget : Ref[Int],
  trace_state : DCEPassTraceState,
) -> Bool {
  // A sequence (TExpr) is "unreachable" in the sense we need here iff
  // execution cannot fall through past the end of the instruction list.
  //
  // For a straight-line list, that means: if any instruction in order is a
  // terminator for the current continuation, then the sequence as a whole
  // cannot reach its end.
  //
  // NOTE: This is deliberately stronger than "contains unreachable code".
  // It answers: "can this list fall through?"
  let { instrs, .. } = expr

  for instr in instrs {
    let local_budget = dce_alloc_break_budget(break_scan_budget, 512)
    if dce_is_unreachable_instr(instr, local_budget, trace_state) {
      return true
    }
  }

  false
}

///|
fn label_matches_depth(label : LabelIdx, depth : Int) -> Bool {
  let LabelIdx(raw) = label
  raw.reinterpret_as_int() == depth
}

///|
fn catch_targets_depth(catch_ : Catch, depth : Int) -> Bool {
  match catch_ {
    Catch(_, label)
    | CatchRef(_, label)
    | CatchAll(label)
    | CatchAllRef(label) => label_matches_depth(label, depth)
  }
}

///|
fn dce_has_break_to_depth_in_texpr(
  expr : TExpr,
  depth : Int,
  break_scan_budget : Ref[Int],
  trace_state : DCEPassTraceState,
) -> Bool {
  let { instrs, .. } = expr
  for instr in instrs {
    let local_budget = dce_alloc_break_budget(break_scan_budget, 1024)
    if dce_has_break_to_depth(instr, depth, local_budget, trace_state) {
      return true
    }
  }
  false
}

///|
fn dce_take_break_budget(
  break_scan_budget : Ref[Int],
  trace_state : DCEPassTraceState,
) -> Bool {
  trace_state.break_checks.val += 1

  if break_scan_budget.val <= 0 {
    trace_state.budget_hits.val += 1

    // Avoid spending time logging on every single exhausted check.
    // Emit on first hit and then occasionally.
    if trace_state.budget_hits.val == 1 ||
      trace_state.budget_hits.val % 4096 == 0 {
      dce_trace_maybe_emit_progress(
        trace_state, "budget_exhausted", break_scan_budget,
      )
    }

    true
  } else {
    break_scan_budget.val = break_scan_budget.val - 1
    false
  }
}

///|
fn dce_has_break_to_depth(
  instr : TInstr,
  depth : Int,
  break_scan_budget : Ref[Int],
  trace_state : DCEPassTraceState,
) -> Bool {
  // Conservatively assume a matching break when analysis budget is exhausted.
  if dce_take_break_budget(break_scan_budget, trace_state) {
    return true
  }
  match instr.kind {
    TInstrKind::TBr(label, _) => label_matches_depth(label, depth)
    TInstrKind::TBrIf(label, _, _) => label_matches_depth(label, depth)
    TInstrKind::TBrTable(labels, default, _, _) => {
      if label_matches_depth(default, depth) {
        return true
      }
      for label in labels {
        if label_matches_depth(label, depth) {
          return true
        }
      }
      false
    }
    TInstrKind::TBrOnNull(label, _, _)
    | TInstrKind::TBrOnNonNull(label, _, _)
    | TInstrKind::TBrOnCast(label, _, _, _, _, _)
    | TInstrKind::TBrOnCastFail(label, _, _, _, _, _) =>
      label_matches_depth(label, depth)
    TInstrKind::TBlock(_, body) | TInstrKind::TLoop(_, body) =>
      dce_has_break_to_depth_in_texpr(
        body,
        depth + 1,
        break_scan_budget,
        trace_state,
      )
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      if dce_has_break_to_depth(cond, depth, break_scan_budget, trace_state) {
        return true
      }
      if dce_has_break_to_depth_in_texpr(
          then_body,
          depth + 1,
          break_scan_budget,
          trace_state,
        ) {
        return true
      }
      match else_body {
        Some(body) =>
          dce_has_break_to_depth_in_texpr(
            body,
            depth + 1,
            break_scan_budget,
            trace_state,
          )
        None => false
      }
    }
    TInstrKind::TTryTable(_, catches, body) => {
      for catch_ in catches {
        if catch_targets_depth(catch_, depth + 1) {
          return true
        }
      }
      dce_has_break_to_depth_in_texpr(
        body,
        depth + 1,
        break_scan_budget,
        trace_state,
      )
    }
    _ => {
      for child in eval_children(instr) {
        if dce_has_break_to_depth(child, depth, break_scan_budget, trace_state) {
          return true
        }
      }
      false
    }
  }
}

///|
fn dce_has_unreachable_child(
  instr : TInstr,
  break_scan_budget : Ref[Int],
  trace_state : DCEPassTraceState,
) -> Bool {
  let children = eval_children(instr)

  // Fast path: syntactic terminators in children require no analysis budget.
  for child in children {
    match child.kind {
      TInstrKind::TUnreachable
      | TInstrKind::TBr(_, _)
      | TInstrKind::TBrTable(_, _, _, _)
      | TInstrKind::TReturn(_)
      | TInstrKind::TReturnCall(_, _)
      | TInstrKind::TReturnCallIndirect(_, _, _, _)
      | TInstrKind::TReturnCallRef(_, _, _)
      | TInstrKind::TThrow(_, _)
      | TInstrKind::TThrowRef(_) => return true
      _ => ()
    }
  }

  // Budgeted path: ensure we don't starve later children.
  // Use a small per-child slice so we can examine multiple children even when
  // the caller gave us a small budget.
  for child in children {
    let local_budget = dce_alloc_break_budget(break_scan_budget, 32)
    if dce_is_unreachable_instr(child, local_budget, trace_state) {
      return true
    }
  }

  false
}

///|
/// Allocate a small local budget from a shared parent budget.
/// This bounds the work per query while still preventing infinite work overall.
fn dce_alloc_break_budget(parent : Ref[Int], slice : Int) -> Ref[Int] {
  if slice <= 0 {
    return Ref::new(0)
  }
  if parent.val <= 0 {
    return Ref::new(0)
  }
  let taken = if parent.val >= slice { slice } else { parent.val }
  parent.val = parent.val - taken
  Ref::new(taken)
}

///|
fn dce_is_unreachable_instr(
  instr : TInstr,
  break_scan_budget : Ref[Int],
  trace_state : DCEPassTraceState,
) -> Bool {
  trace_state.unreachable_checks.val += 1

  // When the analysis budget is exhausted, fall back to conservative behavior:
  // "do not claim unreachable" (so we don't incorrectly truncate).
  if dce_take_break_budget(break_scan_budget, trace_state) {
    return false
  }

  match instr.kind {
    // Immediate terminators of the current sequence.
    TInstrKind::TUnreachable => true

    // These always terminate the current sequence (no fallthrough).
    //
    // Note: This is sequence-local: regardless of which label is targeted,
    // an unconditional branch does not fall through to the *next instruction*
    // in the same instruction list.
    TInstrKind::TBr(_, _)
    | TInstrKind::TBrTable(_, _, _, _)
    | TInstrKind::TReturn(_)
    | TInstrKind::TReturnCall(_, _)
    | TInstrKind::TReturnCallIndirect(_, _, _, _)
    | TInstrKind::TReturnCallRef(_, _, _)
    | TInstrKind::TThrow(_, _)
    | TInstrKind::TThrowRef(_) => true

    // A block instruction itself is a terminator iff it cannot "complete"
    // back to its own continuation.
    //
    // A block *can* complete if:
    //   (1) its body can fall through normally, OR
    //   (2) there exists a break targeting the block itself (br depth 0 w.r.t the block).
    //
    // If neither is true, then executing the block transfers control away
    // (e.g., via br to an enclosing label / return / throw / unreachable),
    // so the *instruction* does not fall through.
    TInstrKind::TBlock(_, body) => {
      let body_unreachable = dce_texpr_is_unreachable(
        body, break_scan_budget, trace_state,
      )
      if !body_unreachable {
        return false
      }

      // If there is a break to the block's own label, it can still complete.
      // (This is what preserves outer continuation for br 0, and similar.)
      let has_break_to_self = dce_has_break_to_depth_in_texpr(
        body, 0, break_scan_budget, trace_state,
      )

      // If body is unreachable AND there is NO break-to-self, then the block
      // instruction cannot fall through.
      !has_break_to_self
    }

    // If is a terminator only if:
    //   - condition is unreachable (then it becomes unreachable), OR
    //   - both branches cannot fall through.
    //
    // If there's no else branch, then the "else" path is empty and falls through.
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      if dce_is_unreachable_instr(cond, break_scan_budget, trace_state) {
        return true
      }
      let then_unreachable = dce_texpr_is_unreachable(
        then_body, break_scan_budget, trace_state,
      )
      match else_body {
        Some(other) => {
          let else_unreachable = dce_texpr_is_unreachable(
            other, break_scan_budget, trace_state,
          )
          then_unreachable && else_unreachable
        }
        None => false
      }
    }

    // Loop falls through only if its body can fall through normally.
    // (br 0 in a loop is a continue, not a fallthrough.)
    TInstrKind::TLoop(_, body) =>
      dce_texpr_is_unreachable(body, break_scan_budget, trace_state)

    // try_table: treat like a control structure that only falls through if
    // its body can fall through normally.
    //
    // (You *can* extend this later to model "caught exceptions resume here"
    // if your IR encodes that, but this matches your current intent/tests.)
    TInstrKind::TTryTable(_, _, body) =>
      dce_texpr_is_unreachable(body, break_scan_budget, trace_state)

    // For non-control ops, any unreachable child makes the parent unreachable.
    _ => dce_has_unreachable_child(instr, break_scan_budget, trace_state)
  }
}

///|
/// Fast(ish) nested instruction counter with a hard cap.
/// Returns a count >= limit+1 when it exceeds the limit.
///
/// NOTE: This does allocate via eval_children for non-control instructions,
/// but runs only once per function, and is massively cheaper than 20M+ visits.
fn dce_count_instrs_capped(body : TExpr, limit : Int) -> Int {
  let mut count = 0
  let stack : Array[TInstr] = body.instrs.copy()

  while !stack.is_empty() {
    let instr = stack.pop().unwrap()

    count += 1
    if count > limit {
      return count
    }

    match instr.kind {
      TInstrKind::TBlock(_, b)
      | TInstrKind::TLoop(_, b)
      | TInstrKind::TTryTable(_, _, b) =>
        // push body instrs
        for item in b.instrs {
          stack.push(item)
        }
      TInstrKind::TIf(_, cond, then_body, else_body) => {
        stack.push(cond)
        for item in then_body.instrs {
          stack.push(item)
        }
        match else_body {
          Some(other) =>
            for item in other.instrs {
              stack.push(item)
            }
          None => ()
        }
      }
      _ =>
        // non-control children
        for child in eval_children(instr) {
          stack.push(child)
        }
    }
  }

  count
}

///|
fn dce_rewrite_non_control_unreachable(
  instr : TInstr,
  break_scan_budget : Ref[Int],
  trace_state : DCEPassTraceState,
) -> TInstr {
  let children = eval_children(instr)
  let remaining : Array[TInstr] = []
  let mut after_unreachable = false

  for child in children {
    if after_unreachable {
      continue
    }

    let local_budget = dce_alloc_break_budget(break_scan_budget, 512)
    if dce_is_unreachable_instr(child, local_budget, trace_state) {
      remaining.push(child)
      after_unreachable = true
    } else {
      remaining.push(TInstr::drop(child))
    }
  }

  match remaining {
    [single] => single
    _ => TInstr::block(BlockType::void_(), TExpr::new(remaining))
  }
}

///|
fn has_break_to_depth_in_texpr(expr : TExpr, depth : Int) -> Bool {
  dce_has_break_to_depth_in_texpr(
    expr,
    depth,
    Ref::new(200_000),
    dce_trace_state_noop(),
  )
}

///|
fn is_unreachable_instr(instr : TInstr) -> Bool {
  dce_is_unreachable_instr(instr, Ref::new(200_000), dce_trace_state_noop())
}

///|
fn eval_children(instr : TInstr) -> Array[TInstr] {
  match instr.kind {
    // Zero-operand instructions.
    TInstrKind::TI32Const(_)
    | TInstrKind::TI64Const(_)
    | TInstrKind::TF32Const(_)
    | TInstrKind::TF64Const(_)
    | TInstrKind::TRefNull(_)
    | TInstrKind::TRefFunc(_)
    | TInstrKind::TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | TInstrKind::TUnreachable
    | TInstrKind::TNop
    | TInstrKind::TLocalGet(_)
    | TInstrKind::TGlobalGet(_)
    | TInstrKind::TMemorySize(_)
    | TInstrKind::TAtomicFence
    | TInstrKind::TTableSize(_)
    | TInstrKind::TDataDrop(_)
    | TInstrKind::TElemDrop(_)
    | TInstrKind::TStructNewDefault(_) => []

    // Unary operands.
    TInstrKind::TUnary(_, child)
    | TInstrKind::TDrop(child)
    | TInstrKind::TLocalSet(_, child)
    | TInstrKind::TLocalTee(_, child)
    | TInstrKind::TGlobalSet(_, child)
    | TInstrKind::TRefIsNull(child)
    | TInstrKind::TRefAsNonNull(child)
    | TInstrKind::TI31GetS(child)
    | TInstrKind::TI31GetU(child)
    | TInstrKind::TRefI31(child)
    | TInstrKind::TArrayLen(child)
    | TInstrKind::TAnyConvertExtern(child)
    | TInstrKind::TExternConvertAny(child)
    | TInstrKind::TThrowRef(child)
    | TInstrKind::TMemoryGrow(_, child)
    | TInstrKind::TTableGet(_, child)
    | TInstrKind::TLoad(_, _, child)
    | TInstrKind::TArrayNewDefault(_, child)
    | TInstrKind::TStructGet(_, _, child)
    | TInstrKind::TStructGetS(_, _, child)
    | TInstrKind::TStructGetU(_, _, child)
    | TInstrKind::TI8x16Splat(child)
    | TInstrKind::TI16x8Splat(child)
    | TInstrKind::TI32x4Splat(child)
    | TInstrKind::TI64x2Splat(child)
    | TInstrKind::TF32x4Splat(child)
    | TInstrKind::TF64x2Splat(child)
    | TInstrKind::TExtractLane(_, _, child)
    | TInstrKind::TRefTest(_, _, child)
    | TInstrKind::TRefCast(_, _, child)
    | TInstrKind::TRefGetDesc(child)
    | TInstrKind::TRefTestDesc(_, _, child)
    | TInstrKind::TRefCastDescEq(_, _, child) => [child]

    // Two operands.
    TInstrKind::TBinary(_, left, right)
    | TInstrKind::TRefEq(left, right)
    | TInstrKind::TStore(_, _, left, right)
    | TInstrKind::TMemoryAtomicNotify(_, left, right)
    | TInstrKind::TAtomicRmw(_, _, left, right)
    | TInstrKind::TTableSet(_, left, right)
    | TInstrKind::TTableGrow(_, left, right)
    | TInstrKind::TStructSet(_, _, left, right)
    | TInstrKind::TArrayNew(_, left, right)
    | TInstrKind::TArrayNewData(_, _, left, right)
    | TInstrKind::TArrayNewElem(_, _, left, right)
    | TInstrKind::TArrayGet(_, left, right)
    | TInstrKind::TArrayGetS(_, left, right)
    | TInstrKind::TArrayGetU(_, left, right)
    | TInstrKind::TReplaceLane(_, _, left, right)
    | TInstrKind::TI8x16Swizzle(left, right)
    | TInstrKind::TI8x16RelaxedSwizzle(left, right)
    | TInstrKind::TV128Shift(_, left, right)
    | TInstrKind::TV128LoadLane(_, _, _, left, right)
    | TInstrKind::TV128StoreLane(_, _, _, left, right) => [left, right]

    // Three operands.
    TInstrKind::TMemoryFill(_, a, b, c)
    | TInstrKind::TMemoryCopy(_, _, a, b, c)
    | TInstrKind::TMemoryInit(_, _, a, b, c)
    | TInstrKind::TMemoryAtomicWait32(_, a, b, c)
    | TInstrKind::TMemoryAtomicWait64(_, a, b, c)
    | TInstrKind::TAtomicCmpxchg(_, _, a, b, c)
    | TInstrKind::TTableFill(_, a, b, c)
    | TInstrKind::TTableCopy(_, _, a, b, c)
    | TInstrKind::TTableInit(_, _, a, b, c)
    | TInstrKind::TSelect(_, c, a, b)
    | TInstrKind::TV128Ternary(_, a, b, c) => [a, b, c]

    // Variable-length operands.
    TInstrKind::TCall(_, args)
    | TInstrKind::TReturnCall(_, args)
    | TInstrKind::TThrow(_, args)
    | TInstrKind::TBr(_, args)
    | TInstrKind::TReturn(args)
    | TInstrKind::TStructNew(_, args)
    | TInstrKind::TArrayNewFixed(_, args) => args.copy()
    TInstrKind::TCallIndirect(_, _, args, index)
    | TInstrKind::TReturnCallIndirect(_, _, args, index) => {
      let out = args.copy()
      out.push(index)
      out
    }
    TInstrKind::TCallRef(_, args, ref_)
    | TInstrKind::TReturnCallRef(_, args, ref_) => {
      let out = args.copy()
      out.push(ref_)
      out
    }
    TInstrKind::TBrIf(_, cond, values) => {
      let out = values.copy()
      out.push(cond)
      out
    }
    TInstrKind::TBrTable(_, _, index, values) => {
      let out = values.copy()
      out.push(index)
      out
    }
    TInstrKind::TBrOnNull(_, ref_, values)
    | TInstrKind::TBrOnNonNull(_, ref_, values)
    | TInstrKind::TBrOnCast(_, _, _, _, ref_, values)
    | TInstrKind::TBrOnCastFail(_, _, _, _, ref_, values) => {
      let out = values.copy()
      out.push(ref_)
      out
    }
    TInstrKind::TArraySet(_, a, b, c) => [a, b, c]
    TInstrKind::TArrayFill(_, a, b, c, d) => [a, b, c, d]
    TInstrKind::TArrayCopy(_, _, a, b, c, d, e) => [a, b, c, d, e]
    TInstrKind::TArrayInitData(_, _, a, b, c, d) => [a, b, c, d]
    TInstrKind::TArrayInitElem(_, _, a, b, c, d) => [a, b, c, d]
    TInstrKind::TI8x16Shuffle(
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      left,
      right
    ) => [left, right]

    // Control-flow structures are handled directly by control-flow logic.
    TInstrKind::TBlock(_, _)
    | TInstrKind::TLoop(_, _)
    | TInstrKind::TIf(_, _, _, _)
    | TInstrKind::TTryTable(_, _, _) => []
  }
}

///|
fn run_dce_on_texpr(expr : TExpr) -> TExpr {
  let pass = dead_code_elimination_pass()
  match pass.walk_texpr((), expr) {
    Ok(Some((_, out))) => out
    _ => expr
  }
}

///|
test "dead code elim rewrites non-control unreachable operands" {
  let input = TExpr::new([
    TInstr::binary(
      BinaryOp::i32_add(),
      TInstr::i32_const(I32(1)),
      TInstr::unreachable_(),
    ),
  ])
  let out = run_dce_on_texpr(input)
  match out.instrs {
    [
      {
        kind: TInstrKind::TBlock(
          VoidBlockType,
          {
            instrs: [
              {
                kind: TInstrKind::TDrop(
                  { kind: TInstrKind::TI32Const(I32(1)), .. }
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
    ] => ()
    _ => fail("expected add to rewrite to block(drop(const), unreachable)")
  }
}

///|
test "dead code elim truncates block tails after unreachable" {
  let input = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::i32_const(I32(0)),
        TInstr::unreachable_(),
        TInstr::i32_const(I32(1)),
      ]),
    ),
  ])
  let out = run_dce_on_texpr(input)
  match out.instrs {
    [
      {
        kind: TInstrKind::TBlock(
          _,
          {
            instrs: [
              { kind: TInstrKind::TI32Const(I32(0)), .. },
              { kind: TInstrKind::TUnreachable, .. },
            ],
            ..,
          }
        ),
        ..,
      },
    ] => ()
    _ => fail("expected block tail after unreachable to be removed")
  }
}

///|
test "dead code elim simplifies if when condition is unreachable" {
  let input = TExpr::new([
    TInstr::if_(
      BlockType::void_(),
      TInstr::unreachable_(),
      TExpr::new([TInstr::i32_const(I32(1))]),
      Some(TExpr::new([TInstr::i32_const(I32(2))])),
    ),
    TInstr::i32_const(I32(3)),
  ])
  let out = run_dce_on_texpr(input)
  match out.instrs {
    [{ kind: TInstrKind::TUnreachable, .. }] => ()
    _ => fail("expected if(cond=unreachable) to become unreachable")
  }
}

///|
test "dead code elim simplifies loop with unreachable body" {
  let input = TExpr::new([
    TInstr::loop_(
      BlockType::void_(),
      TExpr::new([TInstr::unreachable_(), TInstr::i32_const(I32(1))]),
    ),
    TInstr::i32_const(I32(2)),
  ])
  let out = run_dce_on_texpr(input)
  match out.instrs {
    [{ kind: TInstrKind::TUnreachable, .. }] => ()
    _ => fail("expected loop(unreachable) to become unreachable")
  }
}

///|
test "dead code elim keeps outer continuation when block has break" {
  let input = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([TInstr::br(LabelIdx::new(0), []), TInstr::i32_const(I32(1))]),
    ),
    TInstr::i32_const(I32(2)),
  ])
  let out = run_dce_on_texpr(input)
  match out.instrs {
    [
      {
        kind: TInstrKind::TBlock(
          _,
          { instrs: [{ kind: TInstrKind::TBr(_, _), .. }], .. }
        ),
        ..,
      },
      { kind: TInstrKind::TI32Const(I32(2)), .. },
    ] => ()
    _ => fail("expected block with br 0 to preserve outer continuation")
  }
}

///|
test "dead code elim propagates unreachable through try_table" {
  let input = TExpr::new([
    TInstr::try_table(
      BlockType::void_(),
      [],
      TExpr::new([TInstr::unreachable_(), TInstr::i32_const(I32(1))]),
    ),
    TInstr::i32_const(I32(2)),
  ])
  let out = run_dce_on_texpr(input)
  match out.instrs {
    [
      {
        kind: TInstrKind::TTryTable(
          _,
          _,
          { instrs: [{ kind: TInstrKind::TUnreachable, .. }], .. }
        ),
        ..,
      },
    ] => ()
    _ => fail("expected try_table(unreachable body) to make continuation dead")
  }
}

///|
test "dead code elim keeps outer continuation for try_table catch escape" {
  let input = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::try_table(
          BlockType::void_(),
          [Catch::all(LabelIdx::new(1))],
          TExpr::new([TInstr::unreachable_(), TInstr::i32_const(I32(1))]),
        ),
        TInstr::i32_const(I32(9)),
      ]),
    ),
    TInstr::i32_const(I32(2)),
  ])
  let out = run_dce_on_texpr(input)
  match out.instrs {
    [
      {
        kind: TInstrKind::TBlock(
          _,
          {
            instrs: [
              {
                kind: TInstrKind::TTryTable(
                  _,
                  _,
                  { instrs: [{ kind: TInstrKind::TUnreachable, .. }], .. }
                ),
                ..,
              },
            ],
            ..,
          }
        ),
        ..,
      },
      { kind: TInstrKind::TI32Const(I32(2)), .. },
    ] => ()
    _ =>
      fail(
        "expected try_table catch targeting enclosing block to preserve outer continuation",
      )
  }
}

///|
test "dead code elim keeps enclosing block reachable for loop branch escape" {
  let input = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::br(LabelIdx::new(1), []),
            TInstr::i32_const(I32(1)),
          ]),
        ),
        TInstr::i32_const(I32(9)),
      ]),
    ),
    TInstr::i32_const(I32(2)),
  ])
  let out = run_dce_on_texpr(input)
  match out.instrs {
    [
      {
        kind: TInstrKind::TBlock(
          _,
          {
            instrs: [
              {
                kind: TInstrKind::TLoop(
                  _,
                  { instrs: [{ kind: TInstrKind::TBr(_, _), .. }], .. }
                ),
                ..,
              },
            ],
            ..,
          }
        ),
        ..,
      },
      { kind: TInstrKind::TI32Const(I32(2)), .. },
    ] => ()
    _ =>
      fail(
        "expected loop branch to enclosing block to keep continuation after block reachable",
      )
  }
}

///|
test "dce does NOT kill continuation after conditional branch to outer label" {
  let input = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([
            // conditional escape to the *enclosing* block (depth 1)
            // Since the condition is not statically known, inner tail is still reachable.
            TInstr::br_if(
              LabelIdx::new(1),
              TInstr::local_get(LocalIdx::new(0)), // assume a local exists in a real func test; or use a global_get
              [],
            ),
            // MUST stay: reachable if the br_if is not taken
            TInstr::i32_const(I32(999999)),
          ]),
        ),
        // MUST stay: reachable if the br_if is not taken
        TInstr::i32_const(I32(100)),
      ]),
    ),
  ])

  let out = run_dce_on_texpr(input)

  match out.instrs {
    [
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
                      { kind: TInstrKind::TBrIf(_, _, _), .. },
                      { kind: TInstrKind::TI32Const(I32(999999)), .. },
                    ],
                    ..,
                  }
                ),
                ..,
              },
              { kind: TInstrKind::TI32Const(I32(100)), .. },
            ],
            ..,
          }
        ),
        ..,
      },
    ] => ()
    _ =>
      fail(
        "expected both the inner tail (999999) and outer continuation (100) to remain",
      )
  }
}
