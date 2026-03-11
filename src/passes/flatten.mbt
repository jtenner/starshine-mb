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
priv struct FLBreakTempKey {
  label_uid : Int
  val_type : ValType
} derive(Eq, Hash)

///|
const FL_TRACE_PROGRESS_INTERVAL : Int = 2048

///|
const FL_TRACE_PROGRESS_INTERVAL_MS : UInt64 = 250UL

///|
const FL_UNSUPPORTED_BRANCH_SCAN_PROGRESS_INTERVAL : Int = 1024

///|
const FL_UNSUPPORTED_BRANCH_SCAN_PROGRESS_INTERVAL_MS : UInt64 = 250UL

///|
const FL_REWRITE_LABEL_FLOW_PROGRESS_INTERVAL : Int = 1024

///|
const FL_REWRITE_LABEL_FLOW_PROGRESS_INTERVAL_MS : UInt64 = 250UL

///|
fn fl_trace_noop(_ : String) -> Unit {
  ()
}

///|
fn fl_trace_should_log_func(ordinal : Int, trace_all_funcs : Bool) -> Bool {
  pass_trace_log_enabled(ordinal, trace_all_funcs)
}

///|
fn fl_trace_now_ms() -> UInt64 {
  pass_trace_now_ms()
}

///|
fn fl_trace_elapsed_ms(start_ms : UInt64) -> UInt64 {
  pass_trace_elapsed_ms(start_ms)
}

///|
fn fl_trace_now_us() -> UInt64 {
  pass_trace_now_us()
}

///|
fn fl_trace_elapsed_us_since(start_us : UInt64) -> UInt64 {
  pass_trace_elapsed_us_since(start_us)
}

///|
fn fl_trace_delta_us_to_ms(delta_us : UInt64) -> UInt64 {
  pass_trace_delta_us_to_ms(delta_us)
}

///|
priv struct FLHelperTimingSnapshot {
  flatten_texpr_us : UInt64
  flatten_texpr_calls : Int
  flatten_non_control_children_us : UInt64
  flatten_non_control_children_calls : Int
  scan_targeting_branch_us : UInt64
  scan_targeting_branch_calls : Int
  rewrite_label_flow_us : UInt64
  rewrite_label_flow_calls : Int
}

///|
priv struct FLHotspotEntry {
  ordinal : Int
  flatten_ticks : UInt64
  rewrite_ticks : UInt64
  locals : Int
  top_instrs : Int
}

///|
const FL_HOTSPOT_SUMMARY_LIMIT : Int = 8

///|
let fl_helper_timing_flatten_texpr_us : Ref[UInt64] = Ref::new(0UL)

///|
let fl_helper_timing_flatten_texpr_calls : Ref[Int] = Ref::new(0)

///|
let fl_helper_timing_flatten_non_control_children_us : Ref[UInt64] = Ref::new(
  0UL,
)

///|
let fl_helper_timing_flatten_non_control_children_calls : Ref[Int] = Ref::new(0)

///|
let fl_helper_timing_scan_targeting_branch_us : Ref[UInt64] = Ref::new(0UL)

///|
let fl_helper_timing_scan_targeting_branch_calls : Ref[Int] = Ref::new(0)

///|
let fl_helper_timing_rewrite_label_flow_us : Ref[UInt64] = Ref::new(0UL)

///|
let fl_helper_timing_rewrite_label_flow_calls : Ref[Int] = Ref::new(0)

///|
let fl_hotspot_entries : Ref[Array[FLHotspotEntry]] = Ref::new([])

///|
let fl_phase_totals_ms : Ref[Map[String, UInt64]] = Ref::new(Map::new())

///|
let fl_phase_totals_calls : Ref[Map[String, Int]] = Ref::new(Map::new())

///|
fn fl_phase_timing_reset() -> Unit {
  fl_phase_totals_ms.val = Map::new()
  fl_phase_totals_calls.val = Map::new()
}

///|
fn fl_phase_timing_commit(phase : String, elapsed_ms : UInt64) -> Unit {
  let totals_ms = fl_phase_totals_ms.val
  let totals_calls = fl_phase_totals_calls.val
  let current_ms = totals_ms.get(phase).unwrap_or(0UL)
  let current_calls = totals_calls.get(phase).unwrap_or(0)
  totals_ms.set(phase, current_ms + elapsed_ms)
  totals_calls.set(phase, current_calls + 1)
}

///|
fn fl_phase_timing_total_ms(phase : String) -> UInt64 {
  fl_phase_totals_ms.val.get(phase).unwrap_or(0UL)
}

///|
fn fl_phase_timing_total_calls(phase : String) -> Int {
  fl_phase_totals_calls.val.get(phase).unwrap_or(0)
}

///|
fn fl_phase_totals_line() -> String {
  let phases = ["collect_param_types", "walk_funcs", "validate_output"]
  let out = StringBuilder::new()
  out.write_string("phase_totals")
  for phase in phases {
    let calls = fl_phase_timing_total_calls(phase)
    if calls > 0 {
      out.write_string(
        " \{phase}_ms=\{fl_phase_timing_total_ms(phase)} \{phase}_calls=\{calls}",
      )
    }
  }
  out.to_string()
}

///|
fn fl_helper_timing_reset() -> Unit {
  fl_helper_timing_flatten_texpr_us.val = 0UL
  fl_helper_timing_flatten_texpr_calls.val = 0
  fl_helper_timing_flatten_non_control_children_us.val = 0UL
  fl_helper_timing_flatten_non_control_children_calls.val = 0
  fl_helper_timing_scan_targeting_branch_us.val = 0UL
  fl_helper_timing_scan_targeting_branch_calls.val = 0
  fl_helper_timing_rewrite_label_flow_us.val = 0UL
  fl_helper_timing_rewrite_label_flow_calls.val = 0
}

///|
fn fl_helper_timing_commit(
  enabled : Bool,
  helper : String,
  start_us : UInt64,
) -> Unit {
  if !enabled || start_us == 0UL {
    return
  }
  let elapsed_us = fl_trace_elapsed_us_since(start_us)
  match helper {
    "fl_flatten_texpr" => {
      fl_helper_timing_flatten_texpr_us.val = fl_helper_timing_flatten_texpr_us.val +
        elapsed_us
      fl_helper_timing_flatten_texpr_calls.val = fl_helper_timing_flatten_texpr_calls.val +
        1
    }
    "fl_flatten_non_control_children" => {
      fl_helper_timing_flatten_non_control_children_us.val = fl_helper_timing_flatten_non_control_children_us.val +
        elapsed_us
      fl_helper_timing_flatten_non_control_children_calls.val = fl_helper_timing_flatten_non_control_children_calls.val +
        1
    }
    "fl_has_unsupported_targeting_branch_in_texpr" => {
      fl_helper_timing_scan_targeting_branch_us.val = fl_helper_timing_scan_targeting_branch_us.val +
        elapsed_us
      fl_helper_timing_scan_targeting_branch_calls.val = fl_helper_timing_scan_targeting_branch_calls.val +
        1
    }
    "fl_rewrite_label_value_flow_in_texpr" => {
      fl_helper_timing_rewrite_label_flow_us.val = fl_helper_timing_rewrite_label_flow_us.val +
        elapsed_us
      fl_helper_timing_rewrite_label_flow_calls.val = fl_helper_timing_rewrite_label_flow_calls.val +
        1
    }
    _ => ()
  }
}

///|
fn fl_helper_timing_snapshot() -> FLHelperTimingSnapshot {
  {
    flatten_texpr_us: fl_helper_timing_flatten_texpr_us.val,
    flatten_texpr_calls: fl_helper_timing_flatten_texpr_calls.val,
    flatten_non_control_children_us: fl_helper_timing_flatten_non_control_children_us.val,
    flatten_non_control_children_calls: fl_helper_timing_flatten_non_control_children_calls.val,
    scan_targeting_branch_us: fl_helper_timing_scan_targeting_branch_us.val,
    scan_targeting_branch_calls: fl_helper_timing_scan_targeting_branch_calls.val,
    rewrite_label_flow_us: fl_helper_timing_rewrite_label_flow_us.val,
    rewrite_label_flow_calls: fl_helper_timing_rewrite_label_flow_calls.val,
  }
}

///|
fn fl_helper_timing_zero() -> FLHelperTimingSnapshot {
  {
    flatten_texpr_us: 0UL,
    flatten_texpr_calls: 0,
    flatten_non_control_children_us: 0UL,
    flatten_non_control_children_calls: 0,
    scan_targeting_branch_us: 0UL,
    scan_targeting_branch_calls: 0,
    rewrite_label_flow_us: 0UL,
    rewrite_label_flow_calls: 0,
  }
}

///|
fn fl_helper_timing_delta_u64(after : UInt64, before : UInt64) -> UInt64 {
  if after >= before {
    after - before
  } else {
    0UL
  }
}

///|
fn fl_helper_timing_diff(
  after : FLHelperTimingSnapshot,
  before : FLHelperTimingSnapshot,
) -> FLHelperTimingSnapshot {
  {
    flatten_texpr_us: fl_helper_timing_delta_u64(
      after.flatten_texpr_us,
      before.flatten_texpr_us,
    ),
    flatten_texpr_calls: after.flatten_texpr_calls - before.flatten_texpr_calls,
    flatten_non_control_children_us: fl_helper_timing_delta_u64(
      after.flatten_non_control_children_us,
      before.flatten_non_control_children_us,
    ),
    flatten_non_control_children_calls: after.flatten_non_control_children_calls -
    before.flatten_non_control_children_calls,
    scan_targeting_branch_us: fl_helper_timing_delta_u64(
      after.scan_targeting_branch_us,
      before.scan_targeting_branch_us,
    ),
    scan_targeting_branch_calls: after.scan_targeting_branch_calls -
    before.scan_targeting_branch_calls,
    rewrite_label_flow_us: fl_helper_timing_delta_u64(
      after.rewrite_label_flow_us,
      before.rewrite_label_flow_us,
    ),
    rewrite_label_flow_calls: after.rewrite_label_flow_calls -
    before.rewrite_label_flow_calls,
  }
}

///|
fn fl_helper_timing_has_nonzero(snapshot : FLHelperTimingSnapshot) -> Bool {
  snapshot.flatten_texpr_calls > 0 ||
  snapshot.flatten_non_control_children_calls > 0 ||
  snapshot.scan_targeting_branch_calls > 0 ||
  snapshot.rewrite_label_flow_calls > 0
}

///|
fn fl_trace_emit_helper_timing(
  trace : (String) -> Unit,
  ordinal : Int,
  timing : FLHelperTimingSnapshot,
) -> Unit {
  if !fl_helper_timing_has_nonzero(timing) {
    return
  }
  trace(
    "func[\{ordinal}] helper_timing flatten_texpr_ms=\{fl_trace_delta_us_to_ms(timing.flatten_texpr_us)} flatten_texpr_calls=\{timing.flatten_texpr_calls} non_control_children_ms=\{fl_trace_delta_us_to_ms(timing.flatten_non_control_children_us)} non_control_children_calls=\{timing.flatten_non_control_children_calls} scan_targeting_branch_ms=\{fl_trace_delta_us_to_ms(timing.scan_targeting_branch_us)} scan_targeting_branch_calls=\{timing.scan_targeting_branch_calls} rewrite_label_flow_ms=\{fl_trace_delta_us_to_ms(timing.rewrite_label_flow_us)} rewrite_label_flow_calls=\{timing.rewrite_label_flow_calls}",
  )
}

///|
fn fl_helper_totals_line() -> String {
  "helper_totals flatten_texpr_ms=\{fl_trace_delta_us_to_ms(fl_helper_timing_flatten_texpr_us.val)} flatten_texpr_calls=\{fl_helper_timing_flatten_texpr_calls.val} non_control_children_ms=\{fl_trace_delta_us_to_ms(fl_helper_timing_flatten_non_control_children_us.val)} non_control_children_calls=\{fl_helper_timing_flatten_non_control_children_calls.val} scan_targeting_branch_ms=\{fl_trace_delta_us_to_ms(fl_helper_timing_scan_targeting_branch_us.val)} scan_targeting_branch_calls=\{fl_helper_timing_scan_targeting_branch_calls.val} rewrite_label_flow_ms=\{fl_trace_delta_us_to_ms(fl_helper_timing_rewrite_label_flow_us.val)} rewrite_label_flow_calls=\{fl_helper_timing_rewrite_label_flow_calls.val}"
}

///|
fn fl_trace_emit_totals(trace : (String) -> Unit) -> Unit {
  trace(fl_phase_totals_line())
  trace(fl_helper_totals_line())
}

///|
fn fl_hotspot_reset() -> Unit {
  fl_hotspot_entries.val = []
}

///|
fn fl_hotspot_record(
  ordinal : Int,
  flatten_ticks : UInt64,
  rewrite_ticks : UInt64,
  locals : Int,
  top_instrs : Int,
) -> Unit {
  let entries = fl_hotspot_entries.val
  entries.push({ ordinal, flatten_ticks, rewrite_ticks, locals, top_instrs })
  if entries.length() <= FL_HOTSPOT_SUMMARY_LIMIT {
    fl_hotspot_entries.val = entries
    return
  }
  let mut min_idx = 0
  let mut min_ticks = entries[0].flatten_ticks
  for i = 1; i < entries.length(); i = i + 1 {
    if entries[i].flatten_ticks < min_ticks {
      min_idx = i
      min_ticks = entries[i].flatten_ticks
    }
  }
  let trimmed : Array[FLHotspotEntry] = []
  for i = 0; i < entries.length(); i = i + 1 {
    if i != min_idx {
      trimmed.push(entries[i])
    }
  }
  fl_hotspot_entries.val = trimmed
}

///|
fn fl_hotspot_summary_line() -> String? {
  let entries = fl_hotspot_entries.val
  if entries.is_empty() {
    return None
  }
  let ordered = entries.copy()
  let mut i = 0
  while i < ordered.length() {
    let mut j = i + 1
    while j < ordered.length() {
      if ordered[j].flatten_ticks > ordered[i].flatten_ticks {
        let tmp = ordered[i]
        ordered[i] = ordered[j]
        ordered[j] = tmp
      }
      j += 1
    }
    i += 1
  }
  let out = StringBuilder::new()
  out.write_string("hotspots ")
  let mut idx = 0
  while idx < ordered.length() {
    if idx > 0 {
      out.write_string(" ")
    }
    let entry = ordered[idx]
    out.write_string(
      "f\{entry.ordinal}:flatten=\{entry.flatten_ticks}:rewrite=\{entry.rewrite_ticks}:locals=\{entry.locals}:top=\{entry.top_instrs}",
    )
    idx += 1
  }
  Some(out.to_string())
}

///|
priv struct FLFuncTraceState {
  trace : (String) -> Unit
  log_func : Bool
  helper_timing_enabled : Bool
  ordinal : Int
  func_start_ms : UInt64
  last_progress_ms : Ref[UInt64]
  expr_visits : Ref[Int]
  instr_visits : Ref[Int]
  rewrites : Ref[Int]
}

///|
fn FLFuncTraceState::new(
  trace : (String) -> Unit,
  log_func : Bool,
  helper_timing_enabled : Bool,
  ordinal : Int,
  func_start_ms : UInt64,
) -> FLFuncTraceState {
  {
    trace,
    log_func,
    helper_timing_enabled,
    ordinal,
    func_start_ms,
    last_progress_ms: Ref::new(0UL),
    expr_visits: Ref::new(0),
    instr_visits: Ref::new(0),
    rewrites: Ref::new(0),
  }
}

///|
priv struct FLFuncState {
  mut env : Env
  locals : Array[ValType]
  break_temps : Map[FLBreakTempKey, LocalIdx]
  mut changed : Bool
  localize_branch_values : Bool

  // Label identity stack: each control construct with a label gets a unique uid.
  label_uids : Array[Int]
  next_label_uid : Ref[Int]
  trace_state : FLFuncTraceState?
}

///|
fn FLFuncState::new(
  env : Env,
  locals : Array[ValType],
  localize_branch_values? : Bool = false,
  trace_state? : FLFuncTraceState? = None,
) -> FLFuncState {
  {
    env,
    locals,
    break_temps: Map::new(),
    changed: false,
    localize_branch_values,
    label_uids: [],
    next_label_uid: Ref::new(1),
    trace_state,
  }
}

///|
fn fl_instr_kind_name(instr : TInstr) -> String {
  match instr.kind {
    TInstrKind::TBlock(_, _) => "block"
    TInstrKind::TLoop(_, _) => "loop"
    TInstrKind::TTryTable(_, _, _) => "try_table"
    TInstrKind::TIf(_, _, _, _) => "if"
    TInstrKind::TBr(_, _) => "br"
    TInstrKind::TBrIf(_, _, _) => "br_if"
    TInstrKind::TBrTable(_, _, _, _) => "br_table"
    TInstrKind::TBrOnNull(_, _, _) => "br_on_null"
    TInstrKind::TBrOnNonNull(_, _, _) => "br_on_non_null"
    TInstrKind::TBrOnCast(_, _, _, _, _, _) => "br_on_cast"
    TInstrKind::TBrOnCastFail(_, _, _, _, _, _) => "br_on_cast_fail"
    TInstrKind::TLocalSet(_, _) => "local.set"
    TInstrKind::TLocalTee(_, _) => "local.tee"
    TInstrKind::TLocalGet(_) => "local.get"
    TInstrKind::TDrop(_) => "drop"
    TInstrKind::TCall(_, _) => "call"
    TInstrKind::TCallIndirect(_, _, _, _) => "call_indirect"
    TInstrKind::TCallRef(_, _, _) => "call_ref"
    TInstrKind::TReturn(_) => "return"
    TInstrKind::TSelect(_, _, _, _) => "select"
    _ => "other"
  }
}

///|
fn fl_trace_maybe_emit_progress(
  state : FLFuncState,
  phase : String,
  detail : String,
) -> Unit {
  match state.trace_state {
    Some(ts) => {
      if !ts.log_func {
        return
      }
      let now_ms = fl_trace_now_ms()
      let expr_visits = ts.expr_visits.val
      let instr_visits = ts.instr_visits.val
      let rewrites = ts.rewrites.val
      let work_done = expr_visits + instr_visits + rewrites
      let has_emitted_progress = ts.last_progress_ms.val != 0UL
      let since_last_ms = if has_emitted_progress &&
        now_ms >= ts.last_progress_ms.val {
        now_ms - ts.last_progress_ms.val
      } else {
        0UL
      }
      let should_emit_first = !has_emitted_progress && work_done >= 32
      let should_emit_periodic = (
          expr_visits > 0 &&
          (
            (expr_visits <= 256 && expr_visits % 64 == 0) ||
            expr_visits % FL_TRACE_PROGRESS_INTERVAL == 0
          )
        ) ||
        (
          instr_visits > 0 &&
          (
            (instr_visits <= 512 && instr_visits % 128 == 0) ||
            instr_visits % FL_TRACE_PROGRESS_INTERVAL == 0
          )
        ) ||
        (rewrites > 0 && rewrites % 32 == 0)
      let should_emit_timed = since_last_ms >= FL_TRACE_PROGRESS_INTERVAL_MS
      if !(should_emit_first || should_emit_periodic || should_emit_timed) {
        return
      }
      (ts.trace)(
        "func[\{ts.ordinal}] progress phase=\{phase} elapsed_ms=\{fl_trace_elapsed_ms(ts.func_start_ms)} exprs=\{expr_visits} instrs=\{instr_visits} rewrites=\{rewrites} \{detail}",
      )
      ts.last_progress_ms.val = now_ms
    }
    None => ()
  }
}

///|
fn fl_trace_note_expr_visit(
  state : FLFuncState,
  phase : String,
  detail : String,
) -> Unit {
  match state.trace_state {
    Some(ts) => if ts.log_func { ts.expr_visits.val = ts.expr_visits.val + 1 }
    None => ()
  }
  fl_trace_maybe_emit_progress(state, phase, detail)
}

///|
fn fl_trace_note_instr_visit(
  state : FLFuncState,
  phase : String,
  detail : String,
) -> Unit {
  match state.trace_state {
    Some(ts) => if ts.log_func { ts.instr_visits.val = ts.instr_visits.val + 1 }
    None => ()
  }
  fl_trace_maybe_emit_progress(state, phase, detail)
}

///|
fn fl_trace_helper_start(
  state : FLFuncState,
  helper : String,
  detail : String,
) -> UInt64 {
  ignore(helper)
  ignore(detail)
  match state.trace_state {
    Some(ts) => if ts.helper_timing_enabled { fl_trace_now_us() } else { 0UL }
    None => 0UL
  }
}

///|
fn fl_trace_helper_done(
  state : FLFuncState,
  helper : String,
  start_us : UInt64,
  detail : String,
) -> Unit {
  ignore(detail)
  match state.trace_state {
    Some(ts) =>
      fl_helper_timing_commit(ts.helper_timing_enabled, helper, start_us)
    None => ()
  }
}

///|
fn fl_trace_helper_event(
  state : FLFuncState,
  helper : String,
  step : String,
  detail : String,
) -> Unit {
  match state.trace_state {
    Some(ts) =>
      if ts.log_func && step == "progress" {
        (ts.trace)(
          "func[\{ts.ordinal}] helper=\{helper} step=\{step} elapsed_ms=\{fl_trace_elapsed_ms(ts.func_start_ms)} \{detail}",
        )
      }
    None => ()
  }
}

///|
fn fl_trace_mark_rewrite(
  state : FLFuncState,
  helper : String,
  detail : String,
) -> Unit {
  state.changed = true
  match state.trace_state {
    Some(ts) => ts.rewrites.val = ts.rewrites.val + 1
    None => ()
  }
  fl_trace_maybe_emit_progress(state, helper, detail)
}

///|
fn fl_rewrite_counter(state : FLFuncState) -> Int? {
  match state.trace_state {
    Some(ts) => Some(ts.rewrites.val)
    None => None
  }
}

///|
fn fl_rewrite_counter_changed(state : FLFuncState, before : Int?) -> Bool? {
  match before {
    Some(prev) =>
      match state.trace_state {
        Some(ts) => Some(ts.rewrites.val != prev)
        None => None
      }
    None => None
  }
}

///|
fn fl_label_depth(label : LabelIdx) -> Int {
  let LabelIdx(raw) = label
  raw.reinterpret_as_int()
}

///|
fn fl_bump_label(label : LabelIdx, delta : Int) -> LabelIdx {
  LabelIdx::new((fl_label_depth(label) + delta).reinterpret_as_uint())
}

///|
fn fl_push_label(state : FLFuncState) -> Int {
  let uid = state.next_label_uid.val
  state.next_label_uid.update(fn(i) { i + 1 })
  state.label_uids.push(uid)
  uid
}

///|
fn fl_pop_label(state : FLFuncState) -> Unit {
  if state.label_uids.length() > 0 {
    ignore(state.label_uids.pop())
  }
}

///|
fn fl_resolve_label_uid(state : FLFuncState, label : LabelIdx) -> Int? {
  let depth = fl_label_depth(label)
  let n = state.label_uids.length()
  // LabelIdx(0) refers to innermost enclosing label => last element.
  let idx = n - 1 - depth
  if idx < 0 || idx >= n {
    None
  } else {
    Some(state.label_uids[idx])
  }
}

///|
fn fl_add_temp_local(state : FLFuncState, ty : ValType) -> LocalIdx {
  let idx = LocalIdx::new(state.locals.length().reinterpret_as_uint())
  state.locals.push(ty)
  state.env = state.env.with_locals(state.locals)
  fl_trace_mark_rewrite(state, "fl_add_temp_local", "new_local=\{idx}")
  idx
}

///|
fn fl_get_break_temp(
  state : FLFuncState,
  label : LabelIdx,
  ty : ValType,
) -> LocalIdx {
  // IMPORTANT: resolve to stable label uid, not raw LabelIdx depth
  let uid = match fl_resolve_label_uid(state, label) {
    Some(u) => u
    None =>
      // Fallback: if something is malformed, still avoid crashing.
      // Use an impossible uid derived from depth (still better than conflating everything).
      // You may prefer to return an Err instead, but this keeps the signature.
      -1000000 - fl_label_depth(label)
  }
  let key = { label_uid: uid, val_type: ty }
  match state.break_temps.get(key) {
    Some(idx) => idx
    None => {
      let idx = fl_add_temp_local(state, ty)
      state.break_temps[key] = idx
      fl_trace_helper_event(
        state,
        "fl_get_break_temp",
        "allocate",
        "label_uid=\{uid} val_type=\{ty}",
      )
      idx
    }
  }
}

///|
fn fl_instr_type(instr : TInstr, env : Env) -> ValType? {
  lcs_infer_tinstr_type(instr, env)
}

///|
fn fl_lowerable_single_result_blocktype(bt : BlockType, env : Env) -> ValType? {
  match env.expand_blocktype(bt) {
    Ok((params, [vt])) if params.is_empty() => Some(vt)
    _ => None
  }
}

///|
priv enum FLPosition {
  ValuePos
  StatementPos
}

///|
fn fl_can_emit_statement_preludes(pos : FLPosition) -> Bool {
  match pos {
    StatementPos => true
    ValuePos => false
  }
}

///|
/// Atomic leaves for flattening/idempotence.
/// These should not be wrapped into temp locals repeatedly.

///|
fn fl_is_leaf_constant_or_nop(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TI32Const(_)
    | TInstrKind::TI64Const(_)
    | TInstrKind::TF32Const(_)
    | TInstrKind::TF64Const(_)
    | TInstrKind::TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | TInstrKind::TRefNull(_)
    | TInstrKind::TRefFunc(_)
    | TInstrKind::TLocalGet(_)
    | TInstrKind::TGlobalGet(_)
    | TInstrKind::TNop => true
    _ => false
  }
}

///|
fn fl_is_known_void_statement(instr : TInstr) -> Bool {
  match instr.kind {
    // These opcodes are guaranteed to produce no stack result.
    // Fast-pathing them avoids expensive recursive type inference on deep
    // expression trees when flattening statement-position nodes.
    TInstrKind::TLocalSet(_, _)
    | TInstrKind::TGlobalSet(_, _)
    | TInstrKind::TDrop(_)
    | TInstrKind::TBr(_, _)
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
    _ => false
  }
}

///|
/// Main flattening entry for expressions: unchanged signature.
fn fl_flatten_texpr(body : TExpr, state : FLFuncState) -> Result[TExpr, String] {
  let helper_start_us = fl_trace_helper_start(
    state,
    "fl_flatten_texpr",
    "instrs=\{body.instrs.length()}",
  )
  fl_trace_note_expr_visit(
    state,
    "helper=fl_flatten_texpr:start",
    "instrs=\{body.instrs.length()}",
  )
  let out : Array[TInstr] = []
  for instr in body.instrs {
    let (next_instr, preludes) = match
      fl_flatten_instr(instr, state, StatementPos) {
      Ok(v) => v
      Err(e) => {
        fl_trace_helper_done(
          state,
          "fl_flatten_texpr",
          helper_start_us,
          "instrs=\{body.instrs.length()} out_instrs=\{out.length()} error=true",
        )
        return Err(e)
      }
    }
    for prelude in preludes {
      out.push(prelude)
      fl_trace_mark_rewrite(
        state,
        "fl_flatten_texpr",
        "insert_prelude kind=\{fl_instr_kind_name(prelude)}",
      )
    }
    out.push(next_instr)
  }
  fl_trace_helper_done(
    state,
    "fl_flatten_texpr",
    helper_start_us,
    "instrs=\{body.instrs.length()} out_instrs=\{out.length()}",
  )
  Ok(TExpr::new(out))
}

///|
fn fl_flatten_non_control_children(
  instr : TInstr,
  state : FLFuncState,
) -> Result[(TInstr, Array[TInstr]), String] {
  let helper_kind = fl_instr_kind_name(instr)
  let child_count = eval_children_len(instr)
  if child_count == 0 {
    return Ok((instr, []))
  }
  let helper_start_us = fl_trace_helper_start(
    state,
    "fl_flatten_non_control_children",
    "kind=\{helper_kind} children=\{child_count}",
  )
  let rebuilt_children : Array[TInstr] = []
  let preludes : Array[TInstr] = []
  let mut any_child_change = false
  for child in eval_children(instr) {
    let rewrite_before = fl_rewrite_counter(state)
    let (next_child, child_preludes) = match
      fl_flatten_instr(child, state, ValuePos) {
      Ok(v) => v
      Err(e) => {
        fl_trace_helper_done(
          state,
          "fl_flatten_non_control_children",
          helper_start_us,
          "kind=\{helper_kind} children=\{child_count} error=true",
        )
        return Err(e)
      }
    }
    if !child_preludes.is_empty() {
      fl_trace_helper_done(
        state,
        "fl_flatten_non_control_children",
        helper_start_us,
        "kind=\{helper_kind} children=\{child_count} error=value_position_prelude",
      )
      return Err(
        "flatten: value-position rewrite attempted statement extraction",
      )
    }
    for p in child_preludes {
      preludes.push(p)
    }
    match fl_rewrite_counter_changed(state, rewrite_before) {
      // Use rewrite-counter deltas to detect child changes without deep structural equality.
      // Deep `next_child != child` checks are pathological on huge unchanged expression trees.
      Some(changed) => if changed { any_child_change = true }
      None =>
        // Fallback keeps correctness when no trace state is attached.
        if next_child != child {
          any_child_change = true
        }
    }
    rebuilt_children.push(next_child)
  }
  if any_child_change {
    fl_trace_mark_rewrite(
      state,
      "fl_flatten_non_control_children",
      "kind=\{helper_kind} children=\{child_count}",
    )
    fl_trace_helper_done(
      state,
      "fl_flatten_non_control_children",
      helper_start_us,
      "kind=\{helper_kind} children=\{child_count} changed=true preludes=\{preludes.length()}",
    )
    Ok((mb_rebuild_non_control(instr, rebuilt_children), preludes))
  } else {
    fl_trace_helper_done(
      state,
      "fl_flatten_non_control_children",
      helper_start_us,
      "kind=\{helper_kind} children=\{child_count} changed=false preludes=\{preludes.length()}",
    )
    Ok((instr, preludes))
  }
}

///|
fn fl_flatten_instr(
  instr : TInstr,
  state : FLFuncState,
  pos : FLPosition,
) -> Result[(TInstr, Array[TInstr]), String] {
  fl_trace_note_instr_visit(
    state,
    "helper=fl_flatten_instr",
    "kind=\{fl_instr_kind_name(instr)}",
  )
  if fl_is_leaf_constant_or_nop(instr) {
    return Ok((instr, []))
  }

  let mut curr = instr
  let preludes : Array[TInstr] = []

  match curr.kind {
    TInstrKind::TBlock(bt, body) => {
      // Enter label scope
      let my_uid = fl_push_label(state)

      let next_body = match fl_flatten_texpr(body, state) {
        Ok(v) => v
        Err(e) => {
          fl_pop_label(state)
          return Err(e)
        }
      }

      // If this block produces a value, lower it correctly:
      // - allocate temp
      // - rewrite all branches targeting this block (by uid) to store + branch with no values
      // - rewrite fallthrough value to store
      // - emit void block as a prelude, return local.get(temp)
      if !fl_can_emit_statement_preludes(pos) {
        curr = TInstr::block(bt, next_body)
      } else {
        match bt {
          VoidBlockType => curr = TInstr::block(bt, next_body)
          _ => {
            // block has a result type (possibly val_type or type index); we only support single ValType here
            let branch_scan = fl_scan_unsupported_targeting_branch_in_texpr(
              next_body, state, my_uid,
            )
            if branch_scan.blocked {
              curr = TInstr::block(bt, next_body)
            } else {
              match fl_lowerable_single_result_blocktype(bt, state.env) {
                Some(vt) => {
                  let temp = fl_add_temp_local(state, vt)

                  // Only run the full rewrite walk if there are actually target branches to rewrite.
                  let rewritten1 = if branch_scan.rewritable_targeting_branches >
                    0 {
                    fl_rewrite_label_value_flow_in_texpr(
                      next_body, state, my_uid, temp,
                    )
                  } else {
                    next_body
                  }

                  // Handle fallthrough result
                  let rewritten2 = fl_rewrite_fallthrough_value_to_set(
                    rewritten1,
                    temp,
                    state.env,
                  )

                  preludes.push(TInstr::block(BlockType::void_(), rewritten2))
                  curr = TInstr::local_get(temp)
                  fl_trace_mark_rewrite(
                    state, "fl_flatten_instr", "lower_result_block kind=block",
                  )
                }
                None =>
                  // unexpected, but keep structure
                  curr = TInstr::block(bt, next_body)
              }
            }
          }
        }
      }

      // Leave label scope
      fl_pop_label(state)
    }
    TInstrKind::TLoop(bt, body) => {
      let my_uid = fl_push_label(state)

      let next_body = match fl_flatten_texpr(body, state) {
        Ok(v) => v
        Err(e) => {
          fl_pop_label(state)
          return Err(e)
        }
      }

      if !fl_can_emit_statement_preludes(pos) {
        curr = TInstr::loop_(bt, next_body)
      } else {
        match bt {
          VoidBlockType => curr = TInstr::loop_(bt, next_body)
          _ => {
            let branch_scan = fl_scan_unsupported_targeting_branch_in_texpr(
              next_body, state, my_uid,
            )
            if branch_scan.blocked {
              curr = TInstr::loop_(bt, next_body)
            } else {
              match fl_lowerable_single_result_blocktype(bt, state.env) {
                Some(vt) => {
                  let temp = fl_add_temp_local(state, vt)
                  let rewritten1 = if branch_scan.rewritable_targeting_branches >
                    0 {
                    fl_rewrite_label_value_flow_in_texpr(
                      next_body, state, my_uid, temp,
                    )
                  } else {
                    next_body
                  }
                  let rewritten2 = fl_rewrite_fallthrough_value_to_set(
                    rewritten1,
                    temp,
                    state.env,
                  )

                  preludes.push(TInstr::loop_(BlockType::void_(), rewritten2))
                  curr = TInstr::local_get(temp)
                  fl_trace_mark_rewrite(
                    state, "fl_flatten_instr", "lower_result_block kind=loop",
                  )
                }
                None => curr = TInstr::loop_(bt, next_body)
              }
            }
          }
        }
      }

      fl_pop_label(state)
    }
    TInstrKind::TTryTable(bt, catches, body) => {
      let my_uid = fl_push_label(state)

      let next_body = match fl_flatten_texpr(body, state) {
        Ok(v) => v
        Err(e) => {
          fl_pop_label(state)
          return Err(e)
        }
      }

      if !fl_can_emit_statement_preludes(pos) {
        curr = TInstr::try_table(bt, catches, next_body)
      } else {
        match bt {
          VoidBlockType => curr = TInstr::try_table(bt, catches, next_body)
          _ => {
            let branch_scan = fl_scan_unsupported_targeting_branch_in_texpr(
              next_body, state, my_uid,
            )
            if branch_scan.blocked {
              curr = TInstr::try_table(bt, catches, next_body)
            } else {
              match fl_lowerable_single_result_blocktype(bt, state.env) {
                Some(vt) => {
                  let temp = fl_add_temp_local(state, vt)
                  let rewritten1 = if branch_scan.rewritable_targeting_branches >
                    0 {
                    fl_rewrite_label_value_flow_in_texpr(
                      next_body, state, my_uid, temp,
                    )
                  } else {
                    next_body
                  }
                  let rewritten2 = fl_rewrite_fallthrough_value_to_set(
                    rewritten1,
                    temp,
                    state.env,
                  )

                  preludes.push(
                    TInstr::try_table(BlockType::void_(), catches, rewritten2),
                  )
                  curr = TInstr::local_get(temp)
                  fl_trace_mark_rewrite(
                    state, "fl_flatten_instr", "lower_result_block kind=try_table",
                  )
                }
                None => curr = TInstr::try_table(bt, catches, next_body)
              }
            }
          }
        }
      }

      fl_pop_label(state)
    }
    TInstrKind::TIf(bt, cond, then_body, else_body) => {
      // Flatten condition first
      let (next_cond, cond_preludes) = match
        fl_flatten_instr(cond, state, ValuePos) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      if !cond_preludes.is_empty() {
        return Err(
          "flatten: value-position rewrite attempted statement extraction",
        )
      }
      for p in cond_preludes {
        preludes.push(p)
      }

      // Enter the if label scope for then/else bodies (br 0 targets end of if)
      let my_uid = fl_push_label(state)

      let next_then = match fl_flatten_texpr(then_body, state) {
        Ok(v) => v
        Err(e) => {
          fl_pop_label(state)
          return Err(e)
        }
      }
      let next_else = match else_body {
        Some(b) =>
          match fl_flatten_texpr(b, state) {
            Ok(v) => Some(v)
            Err(e) => {
              fl_pop_label(state)
              return Err(e)
            }
          }
        None => None
      }

      let mut rewritten_if = TInstr::if_(bt, next_cond, next_then, next_else)

      // Lower if result properly if it has a value:
      let then_branch_scan = fl_scan_unsupported_targeting_branch_in_texpr(
        next_then, state, my_uid,
      )
      let else_branch_scan = match next_else {
        Some(body) =>
          Some(
            fl_scan_unsupported_targeting_branch_in_texpr(body, state, my_uid),
          )
        None => None
      }
      let else_has_unsupported_if_target = match else_branch_scan {
        Some(scan) => scan.blocked
        None => false
      }
      let has_unsupported_if_target = then_branch_scan.blocked ||
        else_has_unsupported_if_target
      if !fl_can_emit_statement_preludes(pos) || has_unsupported_if_target {
        curr = rewritten_if
      } else {
        match fl_lowerable_single_result_blocktype(bt, state.env) {
          Some(vt) => {
            let temp = fl_add_temp_local(state, vt)
            let then1 = if then_branch_scan.rewritable_targeting_branches > 0 {
              fl_rewrite_label_value_flow_in_texpr(
                next_then, state, my_uid, temp,
              )
            } else {
              next_then
            }
            let then2 = fl_rewrite_fallthrough_value_to_set(
              then1,
              temp,
              state.env,
            )

            let else2 = match next_else {
              Some(b) => {
                let else1 = match else_branch_scan {
                  Some(scan) =>
                    if scan.rewritable_targeting_branches > 0 {
                      fl_rewrite_label_value_flow_in_texpr(
                        b, state, my_uid, temp,
                      )
                    } else {
                      b
                    }
                  _ => b
                }
                fl_rewrite_fallthrough_value_to_set(else1, temp, state.env)
              }
              None =>
                return Err(
                  "flatten: if with concrete result requires an else branch",
                )
            }

            rewritten_if = TInstr::if_(
              BlockType::void_(),
              next_cond,
              then2,
              Some(else2),
            )
            preludes.push(rewritten_if)
            curr = TInstr::local_get(temp)
            fl_trace_mark_rewrite(
              state, "fl_flatten_instr", "lower_result_block kind=if",
            )
          }
          None => curr = rewritten_if
        }
      }

      fl_pop_label(state)
    }
    _ => {
      // Non-control: flatten children
      let (rebuilt, child_preludes) = match
        fl_flatten_non_control_children(curr, state) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      curr = rebuilt
      for p in child_preludes {
        preludes.push(p)
      }

      // Branch value localization (stable label identity now)
      if fl_can_emit_statement_preludes(pos) {
        match curr.kind {
          TInstrKind::TBr(label, values) =>
            if state.localize_branch_values && values.length() == 1 {
              match fl_instr_type(values[0], state.env) {
                Some(vt) => {
                  let temp = fl_get_break_temp(state, label, vt)
                  preludes.push(TInstr::local_set(temp, values[0]))
                  curr = TInstr::br(label, [TInstr::local_get(temp)])
                  fl_trace_mark_rewrite(
                    state, "fl_flatten_instr", "localize_branch_value kind=br",
                  )
                }
                None => ()
              }
            }
          TInstrKind::TBrIf(label, cond, values) =>
            if state.localize_branch_values && values.length() == 1 {
              match fl_instr_type(values[0], state.env) {
                Some(vt) => {
                  let temp = fl_get_break_temp(state, label, vt)
                  preludes.push(TInstr::local_set(temp, values[0]))
                  curr = TInstr::br_if(label, cond, [TInstr::local_get(temp)])
                  fl_trace_mark_rewrite(
                    state, "fl_flatten_instr", "localize_branch_value kind=br_if",
                  )
                }
                None => ()
              }
            }
          TInstrKind::TBrOnNull(label, ref_, values) =>
            if state.localize_branch_values && values.length() == 1 {
              match fl_instr_type(values[0], state.env) {
                Some(vt) => {
                  let temp = fl_get_break_temp(state, label, vt)
                  preludes.push(TInstr::local_set(temp, values[0]))
                  curr = TInstr::br_on_null(label, ref_, [
                    TInstr::local_get(temp),
                  ])
                  fl_trace_mark_rewrite(
                    state, "fl_flatten_instr", "localize_branch_value kind=br_on_null",
                  )
                }
                None => ()
              }
            }
          TInstrKind::TBrOnNonNull(label, ref_, values) =>
            if state.localize_branch_values && values.length() == 1 {
              match fl_instr_type(values[0], state.env) {
                Some(vt) => {
                  let temp = fl_get_break_temp(state, label, vt)
                  preludes.push(TInstr::local_set(temp, values[0]))
                  curr = TInstr::br_on_non_null(label, ref_, [
                    TInstr::local_get(temp),
                  ])
                  fl_trace_mark_rewrite(
                    state, "fl_flatten_instr", "localize_branch_value kind=br_on_non_null",
                  )
                }
                None => ()
              }
            }
          TInstrKind::TBrOnCast(label, castop, ht1, ht2, ref_, values) =>
            if state.localize_branch_values && values.length() == 1 {
              match fl_instr_type(values[0], state.env) {
                Some(vt) => {
                  let temp = fl_get_break_temp(state, label, vt)
                  preludes.push(TInstr::local_set(temp, values[0]))
                  curr = TInstr::br_on_cast(
                    label,
                    castop.0,
                    ht1,
                    castop.1,
                    ht2,
                    ref_,
                    [TInstr::local_get(temp)],
                  )
                  fl_trace_mark_rewrite(
                    state, "fl_flatten_instr", "localize_branch_value kind=br_on_cast",
                  )
                }
                None => ()
              }
            }
          TInstrKind::TBrOnCastFail(label, castop, ht1, ht2, ref_, values) =>
            if state.localize_branch_values && values.length() == 1 {
              match fl_instr_type(values[0], state.env) {
                Some(vt) => {
                  let temp = fl_get_break_temp(state, label, vt)
                  preludes.push(TInstr::local_set(temp, values[0]))
                  curr = TInstr::br_on_cast_fail(
                    label,
                    castop.0,
                    ht1,
                    castop.1,
                    ht2,
                    ref_,
                    [TInstr::local_get(temp)],
                  )
                  fl_trace_mark_rewrite(
                    state, "fl_flatten_instr", "localize_branch_value kind=br_on_cast_fail",
                  )
                }
                None => ()
              }
            }
          _ => ()
        }
      }
    }
  }

  if !fl_can_emit_statement_preludes(pos) && !preludes.is_empty() {
    return Err("flatten: value-position rewrite attempted statement extraction")
  }

  // In value position we cannot emit statement preludes, so unreachable lifting
  // and temp-wrapping are both inapplicable. Returning here avoids expensive
  // recursive unreachable/type analysis on deep expression trees.
  if !fl_can_emit_statement_preludes(pos) {
    return Ok((curr, preludes))
  }

  // local.set/global.set/drop are statement-only and already handled above for
  // branch-value localization. Returning early avoids expensive recursive
  // unreachable/type scans on deep child trees in pathological functions.
  if fl_is_known_void_statement(curr) {
    return Ok((curr, preludes))
  }

  // Preserve unreachable handling
  if is_unreachable_instr(curr) {
    if fl_can_emit_statement_preludes(pos) {
      preludes.push(curr)
      fl_trace_mark_rewrite(
        state, "fl_flatten_instr", "unreachable_lifted_to_prelude",
      )
      return Ok((TInstr::unreachable_(), preludes))
    }
    return Ok((curr, preludes))
  }

  // Final "wrap typed expr into temp" rule is statement-only.
  match fl_instr_type(curr, state.env) {
    Some(vt) =>
      if !fl_is_leaf_constant_or_nop(curr) {
        let temp = fl_add_temp_local(state, vt)
        preludes.push(TInstr::local_set(temp, curr))
        fl_trace_mark_rewrite(
          state,
          "fl_flatten_instr",
          "wrap_typed_expr_in_temp kind=\{fl_instr_kind_name(curr)}",
        )
        Ok((TInstr::local_get(temp), preludes))
      } else {
        Ok((curr, preludes))
      }
    None => Ok((curr, preludes))
  }
}

///|
fn fl_collect_param_types(mod : Module) -> Array[Array[ValType]] {
  let out : Array[Array[ValType]] = []
  let env = Env::new().with_module(mod)
  match mod.func_sec {
    Some(FuncSec(type_idxs)) =>
      for tidx in type_idxs {
        match env.resolve_functype(tidx) {
          Some(FuncType(params, _)) => out.push(params)
          None => out.push([])
        }
      }
    None => ()
  }
  out
}

///|
fn fl_defined_func_count(mod : Module) -> Int {
  match mod.code_sec {
    Some(CodeSec(funcs)) => funcs.length()
    None => 0
  }
}

///|
fn fl_run_flatten_module_with_trace(
  mod : Module,
  trace : (String) -> Unit,
  trace_all_funcs : Bool,
  localize_branch_values : Bool,
  validate_output : Bool,
  trace_enabled : Bool,
) -> Result[Module, String] {
  let funcs = fl_defined_func_count(mod)
  let pass_start_ms = if trace_enabled { fl_trace_now_ms() } else { 0UL }
  if trace_enabled {
    fl_helper_timing_reset()
    fl_phase_timing_reset()
    fl_hotspot_reset()
    trace(
      "pass[flatten]:start funcs=\{funcs} trace_all_funcs=\{trace_all_funcs}",
    )
  }

  let collect_start_ms = if trace_enabled {
    trace("phase=collect_param_types:start")
    fl_trace_now_ms()
  } else {
    0UL
  }
  let param_types = fl_collect_param_types(mod)
  if trace_enabled {
    let collect_elapsed_ms = fl_trace_elapsed_ms(collect_start_ms)
    fl_phase_timing_commit("collect_param_types", collect_elapsed_ms)
    trace(
      "phase=collect_param_types:done elapsed_ms=\{collect_elapsed_ms} funcs=\{param_types.length()}",
    )
  }

  let base_env = Env::new().with_module(mod)
  let walk_start_ms = if trace_enabled {
    trace("phase=walk_funcs:start funcs=\{funcs}")
    fl_trace_now_ms()
  } else {
    0UL
  }

  let transformed = match mod.code_sec {
    Some(CodeSec(curr_funcs)) => {
      let next_funcs : Array[Func] = []
      let mut changed = false
      for i = 0; i < curr_funcs.length(); i = i + 1 {
        let def_idx = i
        let ordinal = def_idx + 1
        let log_func = trace_enabled &&
          fl_trace_should_log_func(ordinal, trace_all_funcs)
        let func_trace = if log_func {
          fn(msg) { trace("func[\{ordinal}] \{msg}") }
        } else {
          fl_trace_noop
        }
        let curr = curr_funcs[i]
        match curr {
          TFunc(tfunc_params, locals, body) => {
            let start_top_instrs = body.instrs.length()
            let locals_count = locals.length()
            let func_start_ms = if log_func { fl_trace_now_ms() } else { 0UL }
            let helper_timing_start = if log_func {
              fl_helper_timing_snapshot()
            } else {
              fl_helper_timing_zero()
            }

            func_trace(
              "start params=\{tfunc_params.length()} locals=\{locals_count} top_instrs=\{start_top_instrs}",
            )

            let params = param_types.get(def_idx).unwrap_or([])
            let all_locals = match
              FunctionLocals::from_typed_func_for_pass(
                params, tfunc_params, locals,
              ) {
              Ok(function_locals) => function_locals.all_locals()
              Err(e) => {
                if log_func {
                  let helper_timing_delta = fl_helper_timing_diff(
                    fl_helper_timing_snapshot(),
                    helper_timing_start,
                  )
                  fl_hotspot_record(
                    ordinal,
                    helper_timing_delta.flatten_texpr_us,
                    helper_timing_delta.rewrite_label_flow_us,
                    locals_count,
                    start_top_instrs,
                  )
                  fl_trace_emit_helper_timing(
                    trace, ordinal, helper_timing_delta,
                  )
                  func_trace(
                    "phase=locals:error elapsed_ms=\{fl_trace_elapsed_ms(func_start_ms)} \{e}",
                  )
                  func_trace(
                    "done elapsed_ms=\{fl_trace_elapsed_ms(func_start_ms)} changed=false error=true",
                  )
                }
                return Err("flatten: malformed typed function locals: \{e}")
              }
            }

            func_trace(
              "phase=locals:done elapsed_ms=\{fl_trace_elapsed_ms(func_start_ms)} all_locals=\{all_locals.length()}",
            )

            let state = FLFuncState::new(
              base_env.with_locals(all_locals),
              all_locals,
              localize_branch_values~,
              trace_state=Some(
                FLFuncTraceState::new(
                  trace, log_func, trace_enabled, ordinal, func_start_ms,
                ),
              ),
            )

            let flatten_start_ms = if log_func {
              fl_trace_now_ms()
            } else {
              0UL
            }
            func_trace(
              "phase=flatten_body:start top_instrs=\{start_top_instrs}",
            )

            let next_body = match fl_flatten_texpr(body, state) {
              Ok(v) => v
              Err(e) => {
                if log_func {
                  let helper_timing_delta = fl_helper_timing_diff(
                    fl_helper_timing_snapshot(),
                    helper_timing_start,
                  )
                  fl_hotspot_record(
                    ordinal,
                    helper_timing_delta.flatten_texpr_us,
                    helper_timing_delta.rewrite_label_flow_us,
                    locals_count,
                    start_top_instrs,
                  )
                  fl_trace_emit_helper_timing(
                    trace, ordinal, helper_timing_delta,
                  )
                  func_trace(
                    "phase=flatten_body:error elapsed_ms=\{fl_trace_elapsed_ms(flatten_start_ms)} \{e}",
                  )
                  func_trace(
                    "done elapsed_ms=\{fl_trace_elapsed_ms(func_start_ms)} changed=false error=true",
                  )
                }
                return Err(e)
              }
            }

            let end_top_instrs = next_body.instrs.length()
            func_trace(
              "phase=flatten_body:done elapsed_ms=\{fl_trace_elapsed_ms(flatten_start_ms)} top_instrs=\{start_top_instrs}->\{end_top_instrs}",
            )

            let next_non_param_locals : Array[ValType] = []
            for local_idx in params.length()..<state.locals.length() {
              next_non_param_locals.push(state.locals[local_idx])
            }
            let func_changed = state.changed ||
              next_non_param_locals.length() != locals.length()
            let next_func = Func::t_func(
              params, next_non_param_locals, next_body,
            )

            if log_func {
              let helper_timing_delta = fl_helper_timing_diff(
                fl_helper_timing_snapshot(),
                helper_timing_start,
              )
              fl_hotspot_record(
                ordinal,
                helper_timing_delta.flatten_texpr_us,
                helper_timing_delta.rewrite_label_flow_us,
                locals_count,
                start_top_instrs,
              )
              fl_trace_emit_helper_timing(trace, ordinal, helper_timing_delta)
              match state.trace_state {
                Some(ts) =>
                  func_trace(
                    "done elapsed_ms=\{fl_trace_elapsed_ms(func_start_ms)} changed=\{func_changed} top_instrs=\{start_top_instrs}->\{end_top_instrs} locals=\{locals.length()}->\{next_non_param_locals.length()} exprs=\{ts.expr_visits.val} instrs=\{ts.instr_visits.val} rewrites=\{ts.rewrites.val}",
                  )
                None => ()
              }
            }

            if func_changed {
              changed = true
              next_funcs.push(next_func)
            } else {
              next_funcs.push(curr)
            }
          }
          _ => {
            func_trace("skip reason=non-typed-func")
            next_funcs.push(curr)
          }
        }
      }
      Ok(
        if changed {
          (mod.with_code_sec(CodeSec::new(next_funcs)), true)
        } else {
          (mod, false)
        },
      )
    }
    None => Ok((mod, false))
  }

  let (next_mod, changed) = match transformed {
    Ok(v) => v
    Err(e) => {
      if trace_enabled {
        let walk_elapsed_ms = fl_trace_elapsed_ms(walk_start_ms)
        fl_phase_timing_commit("walk_funcs", walk_elapsed_ms)
        trace("phase=walk_funcs:error elapsed_ms=\{walk_elapsed_ms} \{e}")
        if trace_all_funcs {
          match fl_hotspot_summary_line() {
            Some(summary) => trace(summary)
            None => ()
          }
        }
        fl_trace_emit_totals(trace)
        trace(
          "pass[flatten]:error elapsed_ms=\{fl_trace_elapsed_ms(pass_start_ms)} \{e}",
        )
      }
      return Err(e)
    }
  }

  if trace_enabled {
    let walk_elapsed_ms = fl_trace_elapsed_ms(walk_start_ms)
    fl_phase_timing_commit("walk_funcs", walk_elapsed_ms)
    trace(
      "phase=walk_funcs:done elapsed_ms=\{walk_elapsed_ms} changed=\{changed}",
    )
  }

  if validate_output {
    let validate_start_ms = if trace_enabled {
      trace("phase=validate_output:start")
      fl_trace_now_ms()
    } else {
      0UL
    }
    match validate_module(next_mod) {
      Ok(_) =>
        if trace_enabled {
          let validate_elapsed_ms = fl_trace_elapsed_ms(validate_start_ms)
          fl_phase_timing_commit("validate_output", validate_elapsed_ms)
          trace("phase=validate_output:done elapsed_ms=\{validate_elapsed_ms}")
        }
      Err(e) => {
        let err = "flatten: output module failed validation: \{e}"
        if trace_enabled {
          let validate_elapsed_ms = fl_trace_elapsed_ms(validate_start_ms)
          fl_phase_timing_commit("validate_output", validate_elapsed_ms)
          trace(
            "phase=validate_output:error elapsed_ms=\{validate_elapsed_ms} \{e}",
          )
          if trace_all_funcs {
            match fl_hotspot_summary_line() {
              Some(summary) => trace(summary)
              None => ()
            }
          }
          fl_trace_emit_totals(trace)
          trace(
            "pass[flatten]:error elapsed_ms=\{fl_trace_elapsed_ms(pass_start_ms)} \{err}",
          )
        }
        return Err(err)
      }
    }
  }

  if trace_enabled {
    if trace_all_funcs {
      match fl_hotspot_summary_line() {
        Some(summary) => trace(summary)
        None => ()
      }
    }
    fl_trace_emit_totals(trace)
    trace(
      "pass[flatten]:done elapsed_ms=\{fl_trace_elapsed_ms(pass_start_ms)} changed=\{changed}",
    )
  }

  Ok(next_mod)
}

///|
fn flatten_ir_pass_with_trace(
  _mod : Module,
  trace? : (String) -> Unit = fl_trace_noop,
  trace_all_funcs? : Bool = false,
  localize_branch_values? : Bool = false,
  trace_enabled? : Bool = true,
) -> ModuleTransformer[IRContext, String] {
  ignore(_mod)
  ModuleTransformer::new().on_module_evt(fn(_, ctx, mod) {
    match
      fl_run_flatten_module_with_trace(
        mod, trace, trace_all_funcs, localize_branch_values, false, trace_enabled,
      ) {
      Ok(out) => if out == mod { unchanged() } else { change(ctx, out) }
      Err(e) => error(e)
    }
  })
}

///|
fn run_flatten_with_trace(
  mod : Module,
  trace? : (String) -> Unit = fl_trace_noop,
  trace_all_funcs? : Bool = false,
  localize_branch_values? : Bool = false,
  trace_enabled? : Bool = true,
) -> Result[Module, String] {
  let validate_output = match validate_module(mod) {
    Ok(_) => true
    Err(_) => false
  }
  fl_run_flatten_module_with_trace(
    mod, trace, trace_all_funcs, localize_branch_values, validate_output, trace_enabled,
  )
}

///|
fn run_flatten(mod : Module) -> Result[Module, String] {
  run_flatten_with_trace(mod, trace_enabled=false)
}

///|
fn fl_count_local_tees(body : TExpr) -> Int {
  let count = Ref::new(0)
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      instr : TInstr,
    ) {
      match instr.kind {
        TInstrKind::TLocalTee(_, _) => count.update(fn(v) { v + 1 })
        _ => ()
      }
      from_walk(self.walk_tinstruction_default((), instr))
    },
  )
  ignore(walker.walk_texpr((), body))
  count.val
}

///|
test "flatten keeps local.tee intact in value positions" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [ValType::i32()],
        TExpr::new([
          TInstr::drop(
            TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(9))),
          ),
        ]),
      ),
    ]),
  )
  let out = run_flatten(mod).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) =>
      assert_true(fl_count_local_tees(body) >= 1)
    _ => fail("expected flattened typed function")
  }
}

///|
test "flatten: nested local.tee call arguments remain valid and idempotent" {
  let callee_sig = RecType::new(
    SubType::comp_type(
      CompType::func([ValType::i32(), ValType::i32()], [ValType::i32()]),
    ),
  )
  let caller_sig = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([callee_sig, caller_sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32(), ValType::i32()],
          [],
          TExpr::new([
            TInstr::binary(
              BinaryOp::i32_add(),
              TInstr::local_get(LocalIdx::new(0)),
              TInstr::local_get(LocalIdx::new(1)),
            ),
          ]),
        ),
        Func::t_func(
          [],
          [ValType::i32(), ValType::i32()],
          TExpr::new([
            TInstr::call(FuncIdx::new(0), [
              TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(9))),
              TInstr::local_tee(
                LocalIdx::new(1),
                TInstr::binary(
                  BinaryOp::i32_add(),
                  TInstr::i32_const(I32(1)),
                  TInstr::i32_const(I32(2)),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    )

  let once = run_flatten(mod).unwrap()
  let twice = run_flatten(once).unwrap()
  assert_eq(once, twice)

  match once.code_sec {
    Some(CodeSec([_, TFunc(_, _, body)])) =>
      assert_true(fl_count_local_tees(body) >= 2)
    _ => fail("expected flattened caller function")
  }
  match validate_module(twice) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected flatten output with nested local.tee call args to validate: \{e}",
      )
  }
}

///|
test "flatten preserves value-position if result form" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [ValType::i32(), ValType::i32()],
        TExpr::new([
          TInstr::drop(
            TInstr::if_(
              BlockType::val_type(ValType::i32()),
              TInstr::binary(
                BinaryOp::i32_eq(),
                TInstr::local_get(LocalIdx::new(0)),
                TInstr::i32_const(I32(1)),
              ),
              TExpr::new([TInstr::i32_const(I32(7))]),
              Some(TExpr::new([TInstr::i32_const(I32(8))])),
            ),
          ),
        ]),
      ),
    ]),
  )
  let out = run_flatten(mod).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, locals, { instrs, .. })])) => {
      assert_true(locals.length() >= 2)
      let mut saw_if_i32 = false
      for instr in instrs {
        match instr.kind {
          TInstrKind::TDrop(
            {
              kind: TInstrKind::TIf(
                ValTypeBlockType(NumTypeValType(I32NumType)),
                _,
                _,
                _
              ),
              ..,
            }
          ) => saw_if_i32 = true
          _ => ()
        }
      }
      assert_true(saw_if_i32)
    }
    _ => fail("expected flattened function output")
  }
}

///|
fn fl_count_br_on_family(body : TExpr) -> Int {
  let count = Ref::new(0)
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      instr : TInstr,
    ) {
      match instr.kind {
        TInstrKind::TBrOnNull(_, _, _)
        | TInstrKind::TBrOnNonNull(_, _, _)
        | TInstrKind::TBrOnCast(_, _, _, _, _, _)
        | TInstrKind::TBrOnCastFail(_, _, _, _, _, _) =>
          count.update(fn(v) { v + 1 })
        _ => ()
      }
      from_walk(self.walk_tinstruction_default((), instr))
    },
  )
  ignore(walker.walk_texpr((), body))
  count.val
}

///|
fn fl_find_try_table_result_blocktype(body : TExpr) -> BlockType? {
  let found = Ref::new(None)
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      instr : TInstr,
    ) {
      match instr.kind {
        TInstrKind::TTryTable(bt, _, _) =>
          match found.val {
            None => found.update(fn(_) { Some(bt) })
            Some(_) => ()
          }
        _ => ()
      }
      from_walk(self.walk_tinstruction_default((), instr))
    },
  )
  ignore(walker.walk_texpr((), body))
  found.val
}

///|
/// Helper: rewrite fallthrough value (if the last instr produces a value) into
/// `local.set(temp, last)` so the surrounding construct can become void.
/// This is *necessary but not sufficient* for correctness; branch rewrites handle the rest.

///|
fn fl_rewrite_fallthrough_value_to_set(
  body : TExpr,
  temp : LocalIdx,
  env : Env,
) -> TExpr {
  let { instrs: items, .. } = body
  if items.length() == 0 {
    return body
  }
  let out = items.copy()
  let last_i = out.length() - 1
  let last = out[last_i]
  match fl_instr_type(last, env) {
    Some(_) => out[last_i] = TInstr::local_set(temp, last)
    None => ()
  }
  TExpr::new(out)
}

///|
/// Rewrite any branch-like instruction that targets `target_uid` and carries exactly
/// one value so that it stores into `temp` and branches with no values.
/// This removes value flow through label parameters after we lower the label to void.
///
/// NOTE: This rewrite is structural and uses the *current* label stack to resolve LabelIdx.
/// That’s why it’s a separate walk that pushes/pops label uids as it descends.

///|
priv struct FLRewriteLabelFlowScanState {
  start_ms : UInt64
  visited_exprs : Ref[Int]
  visited_instrs : Ref[Int]
  max_depth : Ref[Int]
  next_progress_at : Ref[Int]
  last_progress_ms : Ref[UInt64]
}

///|
fn FLRewriteLabelFlowScanState::new(
  start_ms : UInt64,
) -> FLRewriteLabelFlowScanState {
  {
    start_ms,
    visited_exprs: Ref::new(0),
    visited_instrs: Ref::new(0),
    max_depth: Ref::new(0),
    next_progress_at: Ref::new(FL_REWRITE_LABEL_FLOW_PROGRESS_INTERVAL),
    last_progress_ms: Ref::new(start_ms),
  }
}

///|
fn fl_note_rewrite_label_flow_expr_visit(
  scan_state : FLRewriteLabelFlowScanState,
  depth : Int,
) -> Unit {
  scan_state.visited_exprs.val = scan_state.visited_exprs.val + 1
  if depth > scan_state.max_depth.val {
    scan_state.max_depth.val = depth
  }
}

///|
fn fl_note_rewrite_label_flow_instr_visit(
  state : FLFuncState,
  scan_state : FLRewriteLabelFlowScanState,
  target_uid : Int,
  depth : Int,
  instr : TInstr,
) -> Unit {
  scan_state.visited_instrs.val = scan_state.visited_instrs.val + 1
  if depth > scan_state.max_depth.val {
    scan_state.max_depth.val = depth
  }
  match state.trace_state {
    Some(ts) =>
      if ts.log_func {
        let now_ms = fl_trace_now_ms()
        let should_log_count = scan_state.visited_instrs.val >=
          scan_state.next_progress_at.val
        let should_log_time = now_ms >=
          scan_state.last_progress_ms.val +
          FL_REWRITE_LABEL_FLOW_PROGRESS_INTERVAL_MS
        if should_log_count || should_log_time {
          fl_trace_helper_event(
            state,
            "fl_rewrite_label_value_flow_in_texpr",
            "progress",
            "scan_ms=\{fl_trace_elapsed_ms(scan_state.start_ms)} visited_exprs=\{scan_state.visited_exprs.val} visited_instrs=\{scan_state.visited_instrs.val} max_depth=\{scan_state.max_depth.val} depth=\{depth} kind=\{fl_instr_kind_name(instr)} target_uid=\{target_uid}",
          )
          if should_log_count {
            scan_state.next_progress_at.val = scan_state.next_progress_at.val +
              FL_REWRITE_LABEL_FLOW_PROGRESS_INTERVAL
          }
          scan_state.last_progress_ms.val = now_ms
        }
      }
    None => ()
  }
}

///|
fn fl_rewrite_label_value_flow_in_instr_scan(
  instr : TInstr,
  state : FLFuncState,
  target_uid : Int,
  temp : LocalIdx,
  scan_state : FLRewriteLabelFlowScanState,
  depth : Int,
) -> TInstr {
  fl_note_rewrite_label_flow_instr_visit(
    state, scan_state, target_uid, depth, instr,
  )
  // Push labels for control constructs before walking into their bodies, so
  // LabelIdx resolution is correct inside.
  match instr.kind {
    TInstrKind::TBlock(bt, body) => {
      let _uid = fl_push_label(state)
      let next_body = fl_rewrite_label_value_flow_in_texpr_scan(
        body,
        state,
        target_uid,
        temp,
        scan_state,
        depth + 1,
      )
      fl_pop_label(state)
      TInstr::block(bt, next_body)
    }
    TInstrKind::TLoop(bt, body) => {
      let _uid = fl_push_label(state)
      let next_body = fl_rewrite_label_value_flow_in_texpr_scan(
        body,
        state,
        target_uid,
        temp,
        scan_state,
        depth + 1,
      )
      fl_pop_label(state)
      TInstr::loop_(bt, next_body)
    }
    TInstrKind::TTryTable(bt, catches, body) => {
      let _uid = fl_push_label(state)
      let next_body = fl_rewrite_label_value_flow_in_texpr_scan(
        body,
        state,
        target_uid,
        temp,
        scan_state,
        depth + 1,
      )
      fl_pop_label(state)
      TInstr::try_table(bt, catches, next_body)
    }
    TInstrKind::TIf(bt, cond, then_body, else_body) => {
      let next_cond = fl_rewrite_label_value_flow_in_instr_scan(
        cond,
        state,
        target_uid,
        temp,
        scan_state,
        depth + 1,
      )
      let _uid = fl_push_label(state)
      let next_then = fl_rewrite_label_value_flow_in_texpr_scan(
        then_body,
        state,
        target_uid,
        temp,
        scan_state,
        depth + 1,
      )
      let next_else = match else_body {
        Some(b) =>
          Some(
            fl_rewrite_label_value_flow_in_texpr_scan(
              b,
              state,
              target_uid,
              temp,
              scan_state,
              depth + 1,
            ),
          )
        None => None
      }
      fl_pop_label(state)
      TInstr::if_(bt, next_cond, next_then, next_else)
    }
    _ => {
      // First, recursively rewrite children in non-control instructions.
      // (Control instructions are handled above.)
      let rebuilt : Array[TInstr] = []
      for child in eval_children(instr) {
        rebuilt.push(
          fl_rewrite_label_value_flow_in_instr_scan(
            child,
            state,
            target_uid,
            temp,
            scan_state,
            depth + 1,
          ),
        )
      }
      if !rebuilt.is_empty() {
        let instr2 = mb_rebuild_non_control(instr, rebuilt)

        // Now rewrite branch-like forms at this node.
        fl_rewrite_branch_node(instr2, state, target_uid, temp)
      } else {
        fl_rewrite_branch_node(instr, state, target_uid, temp)
      }
    }
  }
}

///|
fn fl_rewrite_label_value_flow_in_texpr_scan(
  body : TExpr,
  state : FLFuncState,
  target_uid : Int,
  temp : LocalIdx,
  scan_state : FLRewriteLabelFlowScanState,
  depth : Int,
) -> TExpr {
  fl_note_rewrite_label_flow_expr_visit(scan_state, depth)
  let out : Array[TInstr] = []
  for instr in body.instrs {
    out.push(
      fl_rewrite_label_value_flow_in_instr_scan(
        instr,
        state,
        target_uid,
        temp,
        scan_state,
        depth + 1,
      ),
    )
  }
  TExpr::new(out)
}

///|
fn fl_rewrite_label_value_flow_in_texpr(
  body : TExpr,
  state : FLFuncState,
  target_uid : Int,
  temp : LocalIdx,
) -> TExpr {
  let helper_start_us = fl_trace_helper_start(
    state,
    "fl_rewrite_label_value_flow_in_texpr",
    "instrs=\{body.instrs.length()} target_uid=\{target_uid}",
  )
  let scan_state = FLRewriteLabelFlowScanState::new(fl_trace_now_ms())
  let out = fl_rewrite_label_value_flow_in_texpr_scan(
    body, state, target_uid, temp, scan_state, 0,
  )
  fl_trace_helper_done(
    state,
    "fl_rewrite_label_value_flow_in_texpr",
    helper_start_us,
    "instrs=\{body.instrs.length()} out_instrs=\{out.instrs.length()} target_uid=\{target_uid} visited_exprs=\{scan_state.visited_exprs.val} visited_instrs=\{scan_state.visited_instrs.val} max_depth=\{scan_state.max_depth.val}",
  )
  out
}

///|
fn fl_label_targets_uid(
  state : FLFuncState,
  label : LabelIdx,
  target_uid : Int,
) -> Bool {
  match fl_resolve_label_uid(state, label) {
    Some(uid) => uid == target_uid
    None => false
  }
}

///|
fn fl_br_table_targets_uid(
  state : FLFuncState,
  labels : Array[LabelIdx],
  default_label : LabelIdx,
  target_uid : Int,
) -> Bool {
  if fl_label_targets_uid(state, default_label, target_uid) {
    return true
  }
  for label in labels {
    if fl_label_targets_uid(state, label, target_uid) {
      return true
    }
  }
  false
}

///|
priv struct FLUnsupportedBranchScanState {
  start_ms : UInt64
  visited_exprs : Ref[Int]
  visited_instrs : Ref[Int]
  max_depth : Ref[Int]
  rewritable_targeting_branches : Ref[Int]
  next_progress_at : Ref[Int]
  last_progress_ms : Ref[UInt64]
}

///|
fn FLUnsupportedBranchScanState::new(
  start_ms : UInt64,
) -> FLUnsupportedBranchScanState {
  {
    start_ms,
    visited_exprs: Ref::new(0),
    visited_instrs: Ref::new(0),
    max_depth: Ref::new(0),
    rewritable_targeting_branches: Ref::new(0),
    next_progress_at: Ref::new(FL_UNSUPPORTED_BRANCH_SCAN_PROGRESS_INTERVAL),
    last_progress_ms: Ref::new(start_ms),
  }
}

///|
priv struct FLUnsupportedBranchScanSummary {
  blocked : Bool
  rewritable_targeting_branches : Int
}

///|
fn fl_note_unsupported_branch_scan_expr_visit(
  scan_state : FLUnsupportedBranchScanState,
  depth : Int,
) -> Unit {
  scan_state.visited_exprs.val = scan_state.visited_exprs.val + 1
  if depth > scan_state.max_depth.val {
    scan_state.max_depth.val = depth
  }
}

///|
fn fl_note_unsupported_branch_scan_instr_visit(
  state : FLFuncState,
  scan_state : FLUnsupportedBranchScanState,
  target_uid : Int,
  depth : Int,
  instr : TInstr,
) -> Unit {
  scan_state.visited_instrs.val = scan_state.visited_instrs.val + 1
  if depth > scan_state.max_depth.val {
    scan_state.max_depth.val = depth
  }
  match state.trace_state {
    Some(ts) =>
      if ts.log_func {
        let now_ms = fl_trace_now_ms()
        let should_log_count = scan_state.visited_instrs.val >=
          scan_state.next_progress_at.val
        let should_log_time = now_ms >=
          scan_state.last_progress_ms.val +
          FL_UNSUPPORTED_BRANCH_SCAN_PROGRESS_INTERVAL_MS
        if should_log_count || should_log_time {
          fl_trace_helper_event(
            state,
            "fl_has_unsupported_targeting_branch_in_texpr",
            "progress",
            "scan_ms=\{fl_trace_elapsed_ms(scan_state.start_ms)} visited_exprs=\{scan_state.visited_exprs.val} visited_instrs=\{scan_state.visited_instrs.val} max_depth=\{scan_state.max_depth.val} depth=\{depth} kind=\{fl_instr_kind_name(instr)} target_uid=\{target_uid}",
          )
          if should_log_count {
            scan_state.next_progress_at.val = scan_state.next_progress_at.val +
              FL_UNSUPPORTED_BRANCH_SCAN_PROGRESS_INTERVAL
          }
          scan_state.last_progress_ms.val = now_ms
        }
      }
    None => ()
  }
}

///|
fn fl_has_unsupported_targeting_branch_in_instr_scan(
  instr : TInstr,
  state : FLFuncState,
  target_uid : Int,
  scan_state : FLUnsupportedBranchScanState,
  depth : Int,
) -> Bool {
  fl_note_unsupported_branch_scan_instr_visit(
    state, scan_state, target_uid, depth, instr,
  )
  match instr.kind {
    TInstrKind::TBlock(_, body) => {
      let _uid = fl_push_label(state)
      let blocked = fl_has_unsupported_targeting_branch_in_texpr_scan(
        body,
        state,
        target_uid,
        scan_state,
        depth + 1,
      )
      fl_pop_label(state)
      blocked
    }
    TInstrKind::TLoop(_, body) => {
      let _uid = fl_push_label(state)
      let blocked = fl_has_unsupported_targeting_branch_in_texpr_scan(
        body,
        state,
        target_uid,
        scan_state,
        depth + 1,
      )
      fl_pop_label(state)
      blocked
    }
    TInstrKind::TTryTable(_, _, body) => {
      let _uid = fl_push_label(state)
      let blocked = fl_has_unsupported_targeting_branch_in_texpr_scan(
        body,
        state,
        target_uid,
        scan_state,
        depth + 1,
      )
      fl_pop_label(state)
      blocked
    }
    TInstrKind::TIf(_, _, then_body, else_body) => {
      let _uid = fl_push_label(state)
      let then_blocked = fl_has_unsupported_targeting_branch_in_texpr_scan(
        then_body,
        state,
        target_uid,
        scan_state,
        depth + 1,
      )
      let else_blocked = match else_body {
        Some(body) =>
          fl_has_unsupported_targeting_branch_in_texpr_scan(
            body,
            state,
            target_uid,
            scan_state,
            depth + 1,
          )
        None => false
      }
      fl_pop_label(state)
      then_blocked || else_blocked
    }
    TInstrKind::TBr(label, values) =>
      if fl_label_targets_uid(state, label, target_uid) {
        if values.length() != 1 {
          true
        } else {
          scan_state.rewritable_targeting_branches.val = scan_state.rewritable_targeting_branches.val +
            1
          false
        }
      } else {
        false
      }
    TInstrKind::TBrIf(label, _, values) =>
      if fl_label_targets_uid(state, label, target_uid) {
        if values.length() != 1 {
          true
        } else {
          scan_state.rewritable_targeting_branches.val = scan_state.rewritable_targeting_branches.val +
            1
          false
        }
      } else {
        false
      }
    TInstrKind::TBrOnNull(label, _, values) =>
      if fl_label_targets_uid(state, label, target_uid) {
        if values.length() != 1 ||
          fl_branch_fallthrough_type(instr, state.env) == None {
          true
        } else {
          scan_state.rewritable_targeting_branches.val = scan_state.rewritable_targeting_branches.val +
            1
          false
        }
      } else {
        false
      }
    TInstrKind::TBrOnNonNull(label, _, values) =>
      if fl_label_targets_uid(state, label, target_uid) {
        if values.length() != 1 {
          true
        } else {
          scan_state.rewritable_targeting_branches.val = scan_state.rewritable_targeting_branches.val +
            1
          false
        }
      } else {
        false
      }
    TInstrKind::TBrOnCast(label, _, _, _, _, values) =>
      if fl_label_targets_uid(state, label, target_uid) {
        if values.length() != 1 ||
          fl_branch_fallthrough_type(instr, state.env) == None {
          true
        } else {
          scan_state.rewritable_targeting_branches.val = scan_state.rewritable_targeting_branches.val +
            1
          false
        }
      } else {
        false
      }
    TInstrKind::TBrOnCastFail(label, _, _, _, _, values) =>
      if fl_label_targets_uid(state, label, target_uid) {
        if values.length() != 1 ||
          fl_branch_fallthrough_type(instr, state.env) == None {
          true
        } else {
          scan_state.rewritable_targeting_branches.val = scan_state.rewritable_targeting_branches.val +
            1
          false
        }
      } else {
        false
      }
    TInstrKind::TBrTable(labels, default_label, _, _) =>
      fl_br_table_targets_uid(state, labels, default_label, target_uid)
    _ => {
      for child in eval_children(instr) {
        if fl_has_unsupported_targeting_branch_in_instr_scan(
            child,
            state,
            target_uid,
            scan_state,
            depth + 1,
          ) {
          return true
        }
      }
      false
    }
  }
}

///|
fn fl_has_unsupported_targeting_branch_in_texpr_scan(
  body : TExpr,
  state : FLFuncState,
  target_uid : Int,
  scan_state : FLUnsupportedBranchScanState,
  depth : Int,
) -> Bool {
  fl_note_unsupported_branch_scan_expr_visit(scan_state, depth)
  for instr in body.instrs {
    if fl_has_unsupported_targeting_branch_in_instr_scan(
        instr,
        state,
        target_uid,
        scan_state,
        depth + 1,
      ) {
      return true
    }
  }
  false
}

///|
fn fl_scan_unsupported_targeting_branch_in_texpr(
  body : TExpr,
  state : FLFuncState,
  target_uid : Int,
) -> FLUnsupportedBranchScanSummary {
  let helper_start_us = fl_trace_helper_start(
    state,
    "fl_has_unsupported_targeting_branch_in_texpr",
    "instrs=\{body.instrs.length()} target_uid=\{target_uid}",
  )
  let scan_state = FLUnsupportedBranchScanState::new(fl_trace_now_ms())
  let blocked = fl_has_unsupported_targeting_branch_in_texpr_scan(
    body, state, target_uid, scan_state, 0,
  )
  fl_trace_helper_done(
    state,
    "fl_has_unsupported_targeting_branch_in_texpr",
    helper_start_us,
    "blocked=\{blocked} target_uid=\{target_uid} rewritable_targeting_branches=\{scan_state.rewritable_targeting_branches.val} visited_exprs=\{scan_state.visited_exprs.val} visited_instrs=\{scan_state.visited_instrs.val} max_depth=\{scan_state.max_depth.val}",
  )
  {
    blocked,
    rewritable_targeting_branches: scan_state.rewritable_targeting_branches.val,
  }
}

///|
fn fl_branch_fallthrough_type(instr : TInstr, env : Env) -> ValType? {
  match instr.kind {
    TInstrKind::TBrIf(_, _, [value]) => fl_instr_type(value, env)
    TInstrKind::TBrOnNull(_, ref_, _) =>
      match fl_instr_type(ref_, env) {
        Some(RefTypeValType(rt)) =>
          Some(ValType::ref_type(RefType::new(false, rt.get_heap_type())))
        _ => None
      }
    TInstrKind::TBrOnCast(_, castop, ht1, ht2, _, _) => {
      let CastOp(nullable1, nullable2) = castop
      match
        @validate.diff(
          RefType::new(nullable1, ht1),
          RefType::new(nullable2, ht2),
        ) {
        Ok(rt) => Some(ValType::ref_type(rt))
        Err(_) => None
      }
    }
    TInstrKind::TBrOnCastFail(_, castop, _, ht2, _, _) => {
      let CastOp(_, nullable2) = castop
      Some(ValType::ref_type(RefType::new(nullable2, ht2)))
    }
    _ => None
  }
}

///|
/// Rewrite a single branch-like node if it targets `target_uid` and has exactly one value.
///
/// IMPORTANT: the sequencing wrapper introduces a new innermost label, so rewritten
/// branches must target `label + 1` to preserve the original control destination.

///|
fn fl_rewrite_branch_node(
  instr : TInstr,
  state : FLFuncState,
  target_uid : Int,
  temp : LocalIdx,
) -> TInstr {
  match instr.kind {
    TInstrKind::TBr(label, values) =>
      if values.length() == 1 {
        match fl_resolve_label_uid(state, label) {
          Some(uid) if uid == target_uid => {
            let bumped = fl_bump_label(label, 1)
            fl_trace_helper_event(
              state,
              "fl_rewrite_branch_node",
              "rewrite",
              "kind=br label=\{label} target_uid=\{target_uid}",
            )
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::local_set(temp, values[0]),
                TInstr::br(bumped, []),
              ]),
            )
          }
          _ => instr
        }
      } else {
        instr
      }
    TInstrKind::TBrIf(label, cond, values) =>
      if values.length() == 1 {
        match fl_resolve_label_uid(state, label) {
          Some(uid) if uid == target_uid => {
            let bumped = fl_bump_label(label, 1)
            match fl_instr_type(values[0], state.env) {
              Some(vt) => {
                fl_trace_helper_event(
                  state,
                  "fl_rewrite_branch_node",
                  "rewrite",
                  "kind=br_if label=\{label} target_uid=\{target_uid}",
                )
                TInstr::block(
                  BlockType::val_type(vt),
                  TExpr::new([
                    TInstr::local_set(temp, values[0]),
                    TInstr::br_if(bumped, cond, []),
                    TInstr::local_get(temp),
                  ]),
                )
              }
              None => instr
            }
          }
          _ => instr
        }
      } else {
        instr
      }
    TInstrKind::TBrOnNull(label, ref_, values) =>
      if values.length() == 1 {
        match fl_resolve_label_uid(state, label) {
          Some(uid) if uid == target_uid => {
            let bumped = fl_bump_label(label, 1)
            match fl_branch_fallthrough_type(instr, state.env) {
              Some(vt) => {
                fl_trace_helper_event(
                  state,
                  "fl_rewrite_branch_node",
                  "rewrite",
                  "kind=br_on_null label=\{label} target_uid=\{target_uid}",
                )
                TInstr::block(
                  BlockType::val_type(vt),
                  TExpr::new([
                    TInstr::local_set(temp, values[0]),
                    TInstr::br_on_null(bumped, ref_, []),
                  ]),
                )
              }
              None => instr
            }
          }
          _ => instr
        }
      } else {
        instr
      }
    TInstrKind::TBrOnNonNull(label, ref_, values) =>
      if values.length() == 1 {
        match fl_resolve_label_uid(state, label) {
          Some(uid) if uid == target_uid => {
            let bumped = fl_bump_label(label, 1)
            fl_trace_helper_event(
              state,
              "fl_rewrite_branch_node",
              "rewrite",
              "kind=br_on_non_null label=\{label} target_uid=\{target_uid}",
            )
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::local_set(temp, values[0]),
                TInstr::br_on_non_null(bumped, ref_, []),
              ]),
            )
          }
          _ => instr
        }
      } else {
        instr
      }
    TInstrKind::TBrOnCast(label, castop, ht1, ht2, ref_, values) =>
      if values.length() == 1 {
        match fl_resolve_label_uid(state, label) {
          Some(uid) if uid == target_uid => {
            let bumped = fl_bump_label(label, 1)
            match fl_branch_fallthrough_type(instr, state.env) {
              Some(vt) => {
                fl_trace_helper_event(
                  state,
                  "fl_rewrite_branch_node",
                  "rewrite",
                  "kind=br_on_cast label=\{label} target_uid=\{target_uid}",
                )
                TInstr::block(
                  BlockType::val_type(vt),
                  TExpr::new([
                    TInstr::local_set(temp, values[0]),
                    TInstr::br_on_cast(
                      bumped,
                      castop.0,
                      ht1,
                      castop.1,
                      ht2,
                      ref_,
                      [],
                    ),
                  ]),
                )
              }
              None => instr
            }
          }
          _ => instr
        }
      } else {
        instr
      }
    TInstrKind::TBrOnCastFail(label, castop, ht1, ht2, ref_, values) =>
      if values.length() == 1 {
        match fl_resolve_label_uid(state, label) {
          Some(uid) if uid == target_uid => {
            let bumped = fl_bump_label(label, 1)
            match fl_branch_fallthrough_type(instr, state.env) {
              Some(vt) => {
                fl_trace_helper_event(
                  state,
                  "fl_rewrite_branch_node",
                  "rewrite",
                  "kind=br_on_cast_fail label=\{label} target_uid=\{target_uid}",
                )
                TInstr::block(
                  BlockType::val_type(vt),
                  TExpr::new([
                    TInstr::local_set(temp, values[0]),
                    TInstr::br_on_cast_fail(
                      bumped,
                      castop.0,
                      ht1,
                      castop.1,
                      ht2,
                      ref_,
                      [],
                    ),
                  ]),
                )
              }
              None => instr
            }
          }
          _ => instr
        }
      } else {
        instr
      }
    _ => instr
  }
}

///|
test "flatten supports br_on family instructions and keeps them present" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [ValType::funcref()],
        TExpr::new([
          TInstr::drop(
            TInstr::br_on_null(
              LabelIdx::new(0),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
          ),
          TInstr::drop(
            TInstr::br_on_non_null(
              LabelIdx::new(0),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
          ),
          TInstr::drop(
            TInstr::br_on_cast(
              LabelIdx::new(0),
              true,
              HeapType::abs(AbsHeapType::func()),
              false,
              HeapType::abs(AbsHeapType::func()),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
          ),
          TInstr::drop(
            TInstr::br_on_cast_fail(
              LabelIdx::new(0),
              true,
              HeapType::abs(AbsHeapType::func()),
              false,
              HeapType::abs(AbsHeapType::func()),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
          ),
        ]),
      ),
    ]),
  )
  let out = run_flatten(mod).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) =>
      assert_eq(fl_count_br_on_family(body), 4)
    _ => fail("expected flattened function with br_on family instructions")
  }
}

///|
test "flatten keeps br_on value flow in value position" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [ValType::funcref()],
        TExpr::new([
          TInstr::drop(
            TInstr::br_on_null(
              LabelIdx::new(0),
              TInstr::local_get(LocalIdx::new(0)),
              [TInstr::i32_const(I32(17))],
            ),
          ),
        ]),
      ),
    ]),
  )
  let out = run_flatten(mod).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) => {
      let saw_const_value = Ref::new(false)
      let saw_set_of_const = Ref::new(false)
      let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
          self,
          _,
          instr : TInstr,
        ) {
          match instr.kind {
            TInstrKind::TBrOnNull(
              _,
              _,
              [{ kind: TInstrKind::TI32Const(I32(v)), .. }]
            ) if v == 17 => saw_const_value.update(fn(_) { true })
            TInstrKind::TLocalSet(
              _,
              { kind: TInstrKind::TI32Const(I32(v)), .. }
            ) if v == 17 => saw_set_of_const.update(fn(_) { true })
            _ => ()
          }
          from_walk(self.walk_tinstruction_default((), instr))
        },
      )
      ignore(walker.walk_texpr((), body))
      assert_true(saw_const_value.val)
      assert_true(!saw_set_of_const.val)
    }
    _ => fail("expected flattened br_on_null output")
  }
}

///|
test "flatten preserves carried values for br_on variants in value position" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [ValType::funcref()],
        TExpr::new([
          TInstr::drop(
            TInstr::br_on_null(
              LabelIdx::new(0),
              TInstr::local_get(LocalIdx::new(0)),
              [TInstr::i32_const(I32(1))],
            ),
          ),
          TInstr::drop(
            TInstr::br_on_non_null(
              LabelIdx::new(0),
              TInstr::local_get(LocalIdx::new(0)),
              [TInstr::i32_const(I32(2))],
            ),
          ),
          TInstr::drop(
            TInstr::br_on_cast(
              LabelIdx::new(0),
              true,
              HeapType::abs(AbsHeapType::func()),
              false,
              HeapType::abs(AbsHeapType::func()),
              TInstr::local_get(LocalIdx::new(0)),
              [TInstr::i32_const(I32(3))],
            ),
          ),
          TInstr::drop(
            TInstr::br_on_cast_fail(
              LabelIdx::new(0),
              true,
              HeapType::abs(AbsHeapType::func()),
              false,
              HeapType::abs(AbsHeapType::func()),
              TInstr::local_get(LocalIdx::new(0)),
              [TInstr::i32_const(I32(4))],
            ),
          ),
        ]),
      ),
    ]),
  )
  let out = run_flatten(mod).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) => {
      let carried_const_count = Ref::new(0)
      let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
          self,
          _,
          instr : TInstr,
        ) {
          match instr.kind {
            TInstrKind::TBrOnNull(
              _,
              _,
              [{ kind: TInstrKind::TI32Const(I32(_)), .. }]
            )
            | TInstrKind::TBrOnNonNull(
              _,
              _,
              [{ kind: TInstrKind::TI32Const(I32(_)), .. }]
            )
            | TInstrKind::TBrOnCast(
              _,
              _,
              _,
              _,
              _,
              [{ kind: TInstrKind::TI32Const(I32(_)), .. }]
            )
            | TInstrKind::TBrOnCastFail(
              _,
              _,
              _,
              _,
              _,
              [{ kind: TInstrKind::TI32Const(I32(_)), .. }]
            ) => carried_const_count.update(fn(v) { v + 1 })
            _ => ()
          }
          from_walk(self.walk_tinstruction_default((), instr))
        },
      )
      ignore(walker.walk_texpr((), body))
      assert_eq(carried_const_count.val, 4)
    }
    _ => fail("expected flattened br_on family output")
  }
}

///|
test "flatten preserves try_table value result in value position" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [],
        TExpr::new([
          TInstr::drop(
            TInstr::try_table(
              BlockType::val_type(ValType::i32()),
              [Catch::all(LabelIdx::new(0))],
              TExpr::new([TInstr::i32_const(I32(12))]),
            ),
          ),
        ]),
      ),
    ]),
  )
  let out = run_flatten(mod).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) =>
      match fl_find_try_table_result_blocktype(body) {
        Some(ValTypeBlockType(NumTypeValType(I32NumType))) => ()
        Some(_) => fail("expected flattened try_table to keep i32 blocktype")
        None => fail("expected try_table to remain present after flatten")
      }
    _ => fail("expected flattened try_table output")
  }
}

///|
test "flatten output with br_on_null and try_table remains valid and idempotent" {
  let target_sig = RecType::new(SubType::comp_type(CompType::func([], [])))
  let nullable_target_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let main_sig = RecType::new(
    SubType::comp_type(CompType::func([nullable_target_ref], [])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([target_sig, main_sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [nullable_target_ref],
          [],
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::drop(
                  TInstr::br_on_null(
                    LabelIdx::new(0),
                    TInstr::local_get(LocalIdx::new(0)),
                    [],
                  ),
                ),
              ]),
            ),
            TInstr::drop(
              TInstr::try_table(
                BlockType::val_type(ValType::i32()),
                [],
                TExpr::new([TInstr::i32_const(I32(12))]),
              ),
            ),
          ]),
        ),
      ]),
    )
  let once = run_flatten(mod).unwrap()
  let twice = run_flatten(once).unwrap()
  assert_eq(once, twice)
  match validate_module(once) {
    Ok(_) => ()
    Err(e) =>
      fail("expected flattened br_on_null + try_table module to validate: \{e}")
  }
}

///|
fn fl_mk_valid_one_func_module(
  params : Array[ValType],
  results : Array[ValType],
  locals : Array[ValType],
  body : TExpr,
) -> Module {
  // Create a single rec type containing a single func type.
  // This matches the style you already use in the last test.
  let sig = RecType::new(SubType::comp_type(CompType::func(params, results)))

  Module::new()
  .with_type_sec(TypeSec::new([sig]))
  .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  .with_code_sec(CodeSec::new([Func::t_func(params, locals, body)]))
}

///|
test "flatten: block result produced by br value remains valid" {
  let mod = fl_mk_valid_one_func_module(
    [], // params
    [], // results
    [], // locals
    TExpr::new([
      TInstr::drop(
        TInstr::block(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::br(LabelIdx::new(0), [TInstr::i32_const(I32(7))]),
            TInstr::i32_const(I32(0)), // unreachable
          ]),
        ),
      ),
    ]),
  )

  let out = run_flatten(mod).unwrap()
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected flatten to preserve validity for block result via br; got validation error: \{e}",
      )
  }
}

///|
test "flatten: nested block br value remains valid" {
  let mod = fl_mk_valid_one_func_module(
    [],
    [],
    [],
    TExpr::new([
      TInstr::drop(
        TInstr::block(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::br(LabelIdx::new(1), [TInstr::i32_const(I32(42))]),
              ]),
            ),
            TInstr::i32_const(I32(0)), // unreachable
          ]),
        ),
      ),
    ]),
  )

  let out = run_flatten(mod).unwrap()
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected flatten to preserve validity for nested br-to-outer-block-with-value; got: \{e}",
      )
  }
}

///|
test "flatten: idempotent on atomic local.get" {
  let mod = fl_mk_valid_one_func_module(
    [ValType::i32()], // params
    [], // results
    [], // locals
    TExpr::new([TInstr::drop(TInstr::local_get(LocalIdx::new(0)))]),
  )

  let once = run_flatten(mod).unwrap()
  let twice = run_flatten(once).unwrap()
  assert_eq(once, twice)

  match validate_module(twice) {
    Ok(_) => ()
    Err(e) => fail("expected flattened module to validate: \{e}")
  }
}

///|
test "flatten: direct local.get branch value does not allocate temp local" {
  let mod = fl_mk_valid_one_func_module(
    [ValType::i32()],
    [ValType::i32()],
    [],
    TExpr::new([
      TInstr::br(LabelIdx::new(0), [TInstr::local_get(LocalIdx::new(0))]),
      TInstr::i32_const(I32(0)),
    ]),
  )

  let out = run_flatten(mod).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, locals, body)])) => {
      assert_eq(locals.length(), 0)
      let saw_local_set = Ref::new(false)
      let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
          self,
          _,
          instr : TInstr,
        ) {
          match instr.kind {
            TInstrKind::TLocalSet(_, _) => saw_local_set.update(fn(_) { true })
            _ => ()
          }
          from_walk(self.walk_tinstruction_default((), instr))
        },
      )
      ignore(walker.walk_texpr((), body))
      assert_false(saw_local_set.val)
    }
    _ => fail("expected flattened function output")
  }

  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected flatten to keep direct local.get branch value valid without temp locals; got: \{e}",
      )
  }
}

///|
test "flatten: direct local.tee branch value does not allocate temp local" {
  let mod = fl_mk_valid_one_func_module(
    [ValType::i32()],
    [ValType::i32()],
    [],
    TExpr::new([
      TInstr::br(LabelIdx::new(0), [
        TInstr::local_tee(LocalIdx::new(0), TInstr::local_get(LocalIdx::new(0))),
      ]),
      TInstr::i32_const(I32(0)),
    ]),
  )

  let out = run_flatten(mod).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, locals, body)])) => {
      assert_eq(locals.length(), 0)
      let saw_local_set = Ref::new(false)
      let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
          self,
          _,
          instr : TInstr,
        ) {
          match instr.kind {
            TInstrKind::TLocalSet(_, _) => saw_local_set.update(fn(_) { true })
            _ => ()
          }
          from_walk(self.walk_tinstruction_default((), instr))
        },
      )
      ignore(walker.walk_texpr((), body))
      assert_false(saw_local_set.val)
    }
    _ => fail("expected flattened function output")
  }

  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected flatten to keep direct local.tee branch value valid without temp locals; got: \{e}",
      )
  }
}

///|
test "flatten: direct computed branch value does not allocate temp local" {
  let mod = fl_mk_valid_one_func_module(
    [ValType::i32()],
    [ValType::i32()],
    [],
    TExpr::new([
      TInstr::br(LabelIdx::new(0), [
        TInstr::binary(
          BinaryOp::i32_add(),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::i32_const(I32(1)),
        ),
      ]),
      TInstr::i32_const(I32(0)),
    ]),
  )

  let out = run_flatten(mod).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, locals, body)])) => {
      assert_eq(locals.length(), 0)
      let saw_local_set = Ref::new(false)
      let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
          self,
          _,
          instr : TInstr,
        ) {
          match instr.kind {
            TInstrKind::TLocalSet(_, _) => saw_local_set.update(fn(_) { true })
            _ => ()
          }
          from_walk(self.walk_tinstruction_default((), instr))
        },
      )
      ignore(walker.walk_texpr((), body))
      assert_false(saw_local_set.val)
    }
    _ => fail("expected flattened function output")
  }

  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected flatten to keep direct computed branch value valid without temp locals; got: \{e}",
      )
  }
}

///|
test "flatten: result block with br inside if remains valid" {
  let mod = fl_mk_valid_one_func_module(
    [ValType::i32()], // params
    [],
    [],
    TExpr::new([
      TInstr::drop(
        TInstr::block(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([
                TInstr::br(LabelIdx::new(1), [TInstr::i32_const(I32(9))]),
              ]),
              Some(TExpr::new([TInstr::nop()])),
            ),
            TInstr::i32_const(I32(0)),
          ]),
        ),
      ),
    ]),
  )

  let out = run_flatten(mod).unwrap()
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected flatten to preserve validity for br-with-value inside if to outer result block; got: \{e}",
      )
  }
}

///|
test "flatten: dropped br_if targeting result block remains valid" {
  let mod = fl_mk_valid_one_func_module(
    [ValType::i32()],
    [],
    [],
    TExpr::new([
      TInstr::drop(
        TInstr::block(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::drop(
              TInstr::br_if(
                LabelIdx::new(0),
                TInstr::local_get(LocalIdx::new(0)),
                [TInstr::i32_const(I32(7))],
              ),
            ),
            TInstr::i32_const(I32(0)),
          ]),
        ),
      ),
    ]),
  )

  let out = run_flatten(mod).unwrap()
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected flatten to preserve validity for dropped br_if targeting a result block; got: \{e}",
      )
  }
}

///|
test "flatten: br_on_null targeting result block remains valid" {
  let target_sig = RecType::new(SubType::comp_type(CompType::func([], [])))
  let nullable_target_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let main_sig = RecType::new(
    SubType::comp_type(CompType::func([nullable_target_ref], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([target_sig, main_sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [nullable_target_ref],
          [],
          TExpr::new([
            TInstr::block(
              BlockType::val_type(ValType::i32()),
              TExpr::new([
                TInstr::drop(
                  TInstr::br_on_null(
                    LabelIdx::new(0),
                    TInstr::local_get(LocalIdx::new(0)),
                    [TInstr::i32_const(I32(7))],
                  ),
                ),
                TInstr::i32_const(I32(0)),
              ]),
            ),
          ]),
        ),
      ]),
    )

  let out = run_flatten(mod).unwrap()
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected flatten to preserve validity for br_on_null targeting a result block; got: \{e}",
      )
  }
}

///|
test "flatten: br_table value targeting result block remains valid" {
  let mod = fl_mk_valid_one_func_module(
    [],
    [],
    [],
    TExpr::new([
      TInstr::drop(
        TInstr::block(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::br_table([], LabelIdx::new(0), TInstr::i32_const(I32(0)), [
              TInstr::i32_const(I32(7)),
            ]),
            TInstr::i32_const(I32(0)),
          ]),
        ),
      ),
    ]),
  )

  let out = run_flatten(mod).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) => {
      let saw_value_block = Ref::new(false)
      let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
          self,
          _,
          instr : TInstr,
        ) {
          match instr.kind {
            TInstrKind::TBlock(ValTypeBlockType(NumTypeValType(I32NumType)), _) =>
              saw_value_block.update(fn(_) { true })
            _ => ()
          }
          from_walk(self.walk_tinstruction_default((), instr))
        },
      )
      ignore(walker.walk_texpr((), body))
      assert_true(saw_value_block.val)
    }
    _ => fail("expected flattened function output")
  }
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected flatten to preserve validity for br_table targeting a result block; got: \{e}",
      )
  }
}

///|
test "flatten: br_on_non_null targeting ref result block remains valid" {
  let target_sig = RecType::new(SubType::comp_type(CompType::func([], [])))
  let nullable_target_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let non_null_target_ref = ValType::ref_type(
    RefType::new(false, HeapType::new(TypeIdx::new(0))),
  )
  let main_sig = RecType::new(
    SubType::comp_type(CompType::func([nullable_target_ref], [])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([target_sig, main_sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [nullable_target_ref],
          [],
          TExpr::new([
            TInstr::drop(
              TInstr::block(
                BlockType::val_type(non_null_target_ref),
                TExpr::new([
                  TInstr::br_on_non_null(
                    LabelIdx::new(0),
                    TInstr::local_get(LocalIdx::new(0)),
                    [],
                  ),
                  TInstr::unreachable_(),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    )

  let out = run_flatten(mod).unwrap()
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected flatten to preserve validity for br_on_non_null targeting a ref result block; got: \{e}",
      )
  }
}
