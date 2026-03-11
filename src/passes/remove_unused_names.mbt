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
fn run_trace_noop(_ : String) -> Unit {
  ()
}

///|
priv struct RUNHelperTimingSnapshot {
  walk_once_us : UInt64
  walk_once_calls : Int
  peel_same_blocks_us : UInt64
  peel_same_blocks_calls : Int
  rebase_labels_us : UInt64
  rebase_labels_calls : Int
  branch_scope_scan_us : UInt64
  branch_scope_scan_calls : Int
}

///|
priv struct RUNHotspotEntry {
  ordinal : Int
  walk_ticks : UInt64
  rebase_ticks : UInt64
  locals : Int
  top_instrs : Int
}

///|
const RUN_HOTSPOT_SUMMARY_LIMIT : Int = 8

///|
let run_helper_timing_walk_once_us : Ref[UInt64] = Ref::new(0UL)

///|
let run_helper_timing_walk_once_calls : Ref[Int] = Ref::new(0)

///|
let run_helper_timing_peel_same_blocks_us : Ref[UInt64] = Ref::new(0UL)

///|
let run_helper_timing_peel_same_blocks_calls : Ref[Int] = Ref::new(0)

///|
let run_helper_timing_rebase_labels_us : Ref[UInt64] = Ref::new(0UL)

///|
let run_helper_timing_rebase_labels_calls : Ref[Int] = Ref::new(0)

///|
let run_helper_timing_branch_scope_scan_us : Ref[UInt64] = Ref::new(0UL)

///|
let run_helper_timing_branch_scope_scan_calls : Ref[Int] = Ref::new(0)

///|
let run_hotspot_entries : Ref[Array[RUNHotspotEntry]] = Ref::new([])

///|
let run_phase_totals_ms : Ref[Map[String, UInt64]] = Ref::new(Map::new())

///|
let run_phase_totals_calls : Ref[Map[String, Int]] = Ref::new(Map::new())

///|
fn run_trace_now_us() -> UInt64 {
  pass_trace_now_us()
}

///|
fn run_trace_now_ms() -> UInt64 {
  pass_trace_now_ms()
}

///|
fn run_trace_elapsed_ms(start_ms : UInt64) -> UInt64 {
  pass_trace_elapsed_ms(start_ms)
}

///|
fn run_trace_elapsed_us_since(start_us : UInt64) -> UInt64 {
  pass_trace_elapsed_us_since(start_us)
}

///|
fn run_trace_delta_us_to_ms(delta_us : UInt64) -> UInt64 {
  pass_trace_delta_us_to_ms(delta_us)
}

///|
fn run_phase_timing_reset() -> Unit {
  run_phase_totals_ms.val = Map::new()
  run_phase_totals_calls.val = Map::new()
}

///|
fn run_phase_timing_commit(phase : String, elapsed_ms : UInt64) -> Unit {
  let totals_ms = run_phase_totals_ms.val
  let totals_calls = run_phase_totals_calls.val
  let current_ms = totals_ms.get(phase).unwrap_or(0UL)
  let current_calls = totals_calls.get(phase).unwrap_or(0)
  totals_ms.set(phase, current_ms + elapsed_ms)
  totals_calls.set(phase, current_calls + 1)
}

///|
fn run_phase_timing_total_ms(phase : String) -> UInt64 {
  run_phase_totals_ms.val.get(phase).unwrap_or(0UL)
}

///|
fn run_phase_timing_total_calls(phase : String) -> Int {
  run_phase_totals_calls.val.get(phase).unwrap_or(0)
}

///|
fn run_trace_phase_start(
  trace : (String) -> Unit,
  phase : String,
  enabled : Bool,
) -> UInt64 {
  if !enabled {
    return 0UL
  }
  let start_ms = run_trace_now_ms()
  trace("phase=\{phase}:start")
  start_ms
}

///|
fn run_trace_phase_done(
  trace : (String) -> Unit,
  phase : String,
  start_ms : UInt64,
  enabled : Bool,
) -> Unit {
  if !enabled {
    return
  }
  let elapsed_ms = run_trace_elapsed_ms(start_ms)
  run_phase_timing_commit(phase, elapsed_ms)
  trace("phase=\{phase}:done elapsed_ms=\{elapsed_ms}")
}

///|
fn run_phase_totals_line() -> String {
  let phases = ["walk_funcs"]
  let out = StringBuilder::new()
  out.write_string("phase_totals")
  for phase in phases {
    let calls = run_phase_timing_total_calls(phase)
    if calls > 0 {
      out.write_string(
        " \{phase}_ms=\{run_phase_timing_total_ms(phase)} \{phase}_calls=\{calls}",
      )
    }
  }
  out.to_string()
}

///|
fn run_helper_timing_reset() -> Unit {
  run_helper_timing_walk_once_us.val = 0UL
  run_helper_timing_walk_once_calls.val = 0
  run_helper_timing_peel_same_blocks_us.val = 0UL
  run_helper_timing_peel_same_blocks_calls.val = 0
  run_helper_timing_rebase_labels_us.val = 0UL
  run_helper_timing_rebase_labels_calls.val = 0
  run_helper_timing_branch_scope_scan_us.val = 0UL
  run_helper_timing_branch_scope_scan_calls.val = 0
}

///|
fn run_helper_timing_commit(
  enabled : Bool,
  elapsed_us : Ref[UInt64],
  calls : Ref[Int],
  start_us : UInt64,
) -> Unit {
  if !enabled {
    return
  }
  elapsed_us.val = elapsed_us.val + run_trace_elapsed_us_since(start_us)
  calls.val = calls.val + 1
}

///|
fn run_helper_timing_snapshot() -> RUNHelperTimingSnapshot {
  {
    walk_once_us: run_helper_timing_walk_once_us.val,
    walk_once_calls: run_helper_timing_walk_once_calls.val,
    peel_same_blocks_us: run_helper_timing_peel_same_blocks_us.val,
    peel_same_blocks_calls: run_helper_timing_peel_same_blocks_calls.val,
    rebase_labels_us: run_helper_timing_rebase_labels_us.val,
    rebase_labels_calls: run_helper_timing_rebase_labels_calls.val,
    branch_scope_scan_us: run_helper_timing_branch_scope_scan_us.val,
    branch_scope_scan_calls: run_helper_timing_branch_scope_scan_calls.val,
  }
}

///|
fn run_helper_timing_zero() -> RUNHelperTimingSnapshot {
  {
    walk_once_us: 0UL,
    walk_once_calls: 0,
    peel_same_blocks_us: 0UL,
    peel_same_blocks_calls: 0,
    rebase_labels_us: 0UL,
    rebase_labels_calls: 0,
    branch_scope_scan_us: 0UL,
    branch_scope_scan_calls: 0,
  }
}

///|
fn run_helper_timing_delta_u64(after : UInt64, before : UInt64) -> UInt64 {
  if after >= before {
    after - before
  } else {
    0UL
  }
}

///|
fn run_helper_timing_diff(
  after : RUNHelperTimingSnapshot,
  before : RUNHelperTimingSnapshot,
) -> RUNHelperTimingSnapshot {
  {
    walk_once_us: run_helper_timing_delta_u64(
      after.walk_once_us,
      before.walk_once_us,
    ),
    walk_once_calls: after.walk_once_calls - before.walk_once_calls,
    peel_same_blocks_us: run_helper_timing_delta_u64(
      after.peel_same_blocks_us,
      before.peel_same_blocks_us,
    ),
    peel_same_blocks_calls: after.peel_same_blocks_calls -
    before.peel_same_blocks_calls,
    rebase_labels_us: run_helper_timing_delta_u64(
      after.rebase_labels_us,
      before.rebase_labels_us,
    ),
    rebase_labels_calls: after.rebase_labels_calls - before.rebase_labels_calls,
    branch_scope_scan_us: run_helper_timing_delta_u64(
      after.branch_scope_scan_us,
      before.branch_scope_scan_us,
    ),
    branch_scope_scan_calls: after.branch_scope_scan_calls -
    before.branch_scope_scan_calls,
  }
}

///|
fn run_helper_timing_has_nonzero(snapshot : RUNHelperTimingSnapshot) -> Bool {
  snapshot.walk_once_calls > 0 ||
  snapshot.peel_same_blocks_calls > 0 ||
  snapshot.rebase_labels_calls > 0 ||
  snapshot.branch_scope_scan_calls > 0
}

///|
fn run_trace_emit_helper_timing(
  trace : (String) -> Unit,
  ordinal : Int,
  timing : RUNHelperTimingSnapshot,
) -> Unit {
  if !run_helper_timing_has_nonzero(timing) {
    return
  }
  trace(
    "func[\{ordinal}] helper_timing walk_once_ms=\{run_trace_delta_us_to_ms(timing.walk_once_us)} walk_once_calls=\{timing.walk_once_calls} peel_ms=\{run_trace_delta_us_to_ms(timing.peel_same_blocks_us)} peel_calls=\{timing.peel_same_blocks_calls} rebase_ms=\{run_trace_delta_us_to_ms(timing.rebase_labels_us)} rebase_calls=\{timing.rebase_labels_calls} branch_scan_ms=\{run_trace_delta_us_to_ms(timing.branch_scope_scan_us)} branch_scan_calls=\{timing.branch_scope_scan_calls}",
  )
}

///|
fn run_helper_totals_line() -> String {
  "helper_totals walk_once_ms=\{run_trace_delta_us_to_ms(run_helper_timing_walk_once_us.val)} walk_once_calls=\{run_helper_timing_walk_once_calls.val} peel_ms=\{run_trace_delta_us_to_ms(run_helper_timing_peel_same_blocks_us.val)} peel_calls=\{run_helper_timing_peel_same_blocks_calls.val} rebase_ms=\{run_trace_delta_us_to_ms(run_helper_timing_rebase_labels_us.val)} rebase_calls=\{run_helper_timing_rebase_labels_calls.val} branch_scan_ms=\{run_trace_delta_us_to_ms(run_helper_timing_branch_scope_scan_us.val)} branch_scan_calls=\{run_helper_timing_branch_scope_scan_calls.val}"
}

///|
fn run_trace_emit_totals(trace : (String) -> Unit) -> Unit {
  trace(run_phase_totals_line())
  trace(run_helper_totals_line())
}

///|
fn run_hotspot_reset() -> Unit {
  run_hotspot_entries.val = []
}

///|
fn run_hotspot_record(
  ordinal : Int,
  walk_ticks : UInt64,
  rebase_ticks : UInt64,
  locals : Int,
  top_instrs : Int,
) -> Unit {
  let entries = run_hotspot_entries.val
  entries.push({ ordinal, walk_ticks, rebase_ticks, locals, top_instrs })
  if entries.length() <= RUN_HOTSPOT_SUMMARY_LIMIT {
    run_hotspot_entries.val = entries
    return
  }
  let mut min_idx = 0
  let mut min_ticks = entries[0].walk_ticks
  for i = 1; i < entries.length(); i = i + 1 {
    if entries[i].walk_ticks < min_ticks {
      min_idx = i
      min_ticks = entries[i].walk_ticks
    }
  }
  let trimmed : Array[RUNHotspotEntry] = []
  for i = 0; i < entries.length(); i = i + 1 {
    if i != min_idx {
      trimmed.push(entries[i])
    }
  }
  run_hotspot_entries.val = trimmed
}

///|
fn run_hotspot_summary_line() -> String? {
  let entries = run_hotspot_entries.val
  if entries.is_empty() {
    return None
  }
  let ordered = entries.copy()
  let mut i = 0
  while i < ordered.length() {
    let mut j = i + 1
    while j < ordered.length() {
      if ordered[j].walk_ticks > ordered[i].walk_ticks {
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
      "f\{entry.ordinal}:walk=\{entry.walk_ticks}:rebase=\{entry.rebase_ticks}:locals=\{entry.locals}:top=\{entry.top_instrs}",
    )
    idx += 1
  }
  Some(out.to_string())
}

///|
fn run_label_to_int(label : LabelIdx) -> Int {
  let LabelIdx(raw) = label
  raw.reinterpret_as_int()
}

///|
fn run_label_from_int(idx : Int) -> LabelIdx {
  LabelIdx::new(idx.reinterpret_as_uint())
}

///|
fn run_walk_tinstruction_with_depth(
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
fn run_rebase_label_for_removed_scopes(
  label : LabelIdx,
  depth : Int,
  removed_scopes : Int,
) -> LabelIdx {
  if removed_scopes <= 0 {
    return label
  }
  let curr = run_label_to_int(label)
  if curr < depth {
    label
  } else if curr <= depth + removed_scopes {
    run_label_from_int(depth)
  } else {
    run_label_from_int(curr - removed_scopes)
  }
}

///|
fn run_rebase_labels_for_removed_scopes(
  body : TExpr,
  removed_scopes : Int,
  helper_timing_enabled? : Bool = false,
) -> Result[TExpr, String] {
  let helper_start_us = if helper_timing_enabled {
    run_trace_now_us()
  } else {
    0UL
  }
  let out = if removed_scopes <= 0 {
    Ok(body)
  } else {
    let pass = ModuleTransformer::new()
      .on_labelidx_evt(fn(_, depth, label) {
        let next = run_rebase_label_for_removed_scopes(
          label, depth, removed_scopes,
        )
        if next == label {
          unchanged()
        } else {
          change(depth, next)
        }
      })
      .on_tinstruction_evt(fn(self, depth, instr) {
        run_walk_tinstruction_with_depth(self, depth, instr)
      })
    match pass.walk_texpr(0, body) {
      Ok((rewritten, _)) => Ok(rewritten)
      Err(e) => Err(e)
    }
  }
  run_helper_timing_commit(
    helper_timing_enabled, run_helper_timing_rebase_labels_us, run_helper_timing_rebase_labels_calls,
    helper_start_us,
  )
  out
}

///|
fn run_peel_single_child_same_blocks(
  bt : BlockType,
  body : TExpr,
  helper_timing_enabled? : Bool = false,
) -> (Int, TExpr) {
  let helper_start_us = if helper_timing_enabled {
    run_trace_now_us()
  } else {
    0UL
  }
  let mut removed = 0
  let mut curr = body
  while true {
    match curr {
      { instrs: [{ kind: TInstrKind::TBlock(child_bt, child_body), .. }], .. } =>
        if child_bt == bt {
          removed += 1
          curr = child_body
        } else {
          break
        }
      _ => break
    }
  }
  run_helper_timing_commit(
    helper_timing_enabled, run_helper_timing_peel_same_blocks_us, run_helper_timing_peel_same_blocks_calls,
    helper_start_us,
  )
  (removed, curr)
}

///|
fn run_label_matches_depth(label : LabelIdx, depth : Int) -> Bool {
  run_label_to_int(label) == depth
}

///|
fn run_catch_targets_depth(c : Catch, depth : Int) -> Bool {
  match c {
    Catch(_, label)
    | CatchRef(_, label)
    | CatchAll(label)
    | CatchAllRef(label) => run_label_matches_depth(label, depth)
  }
}

///|
fn run_has_branch_to_depth_in_instr(instr : TInstr, depth : Int) -> Bool {
  match instr.kind {
    TInstrKind::TBlock(_, body) | TInstrKind::TLoop(_, body) =>
      run_has_branch_to_depth_in_texpr(body, depth + 1)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      if run_has_branch_to_depth_in_instr(cond, depth) {
        return true
      }
      if run_has_branch_to_depth_in_texpr(then_body, depth + 1) {
        return true
      }
      match else_body {
        Some(other) => run_has_branch_to_depth_in_texpr(other, depth + 1)
        None => false
      }
    }
    TInstrKind::TTryTable(_, catches, body) => {
      for c in catches {
        if run_catch_targets_depth(c, depth + 1) {
          return true
        }
      }
      run_has_branch_to_depth_in_texpr(body, depth + 1)
    }
    TInstrKind::TBr(label, values) => {
      if run_label_matches_depth(label, depth) {
        return true
      }
      for value in values {
        if run_has_branch_to_depth_in_instr(value, depth) {
          return true
        }
      }
      false
    }
    TInstrKind::TBrIf(label, cond, values) => {
      if run_label_matches_depth(label, depth) {
        return true
      }
      for value in values {
        if run_has_branch_to_depth_in_instr(value, depth) {
          return true
        }
      }
      run_has_branch_to_depth_in_instr(cond, depth)
    }
    TInstrKind::TBrTable(labels, default_label, index, values) => {
      for label in labels {
        if run_label_matches_depth(label, depth) {
          return true
        }
      }
      if run_label_matches_depth(default_label, depth) {
        return true
      }
      for value in values {
        if run_has_branch_to_depth_in_instr(value, depth) {
          return true
        }
      }
      run_has_branch_to_depth_in_instr(index, depth)
    }
    TInstrKind::TBrOnNull(label, ref_, values)
    | TInstrKind::TBrOnNonNull(label, ref_, values)
    | TInstrKind::TBrOnCast(label, _, _, _, ref_, values)
    | TInstrKind::TBrOnCastFail(label, _, _, _, ref_, values) => {
      if run_label_matches_depth(label, depth) {
        return true
      }
      for value in values {
        if run_has_branch_to_depth_in_instr(value, depth) {
          return true
        }
      }
      run_has_branch_to_depth_in_instr(ref_, depth)
    }
    _ => {
      let mut found = false
      oi_for_each_non_control_child(instr, fn(child) {
        if found {
          return
        }
        if run_has_branch_to_depth_in_instr(child, depth) {
          found = true
        }
      })
      found
    }
  }
}

///|
fn run_has_branch_to_depth_in_texpr(body : TExpr, depth : Int) -> Bool {
  for instr in body.instrs {
    if run_has_branch_to_depth_in_instr(instr, depth) {
      return true
    }
  }
  false
}

///|
fn run_has_branch_to_current_scope(
  body : TExpr,
  helper_timing_enabled? : Bool = false,
) -> Result[Bool, String] {
  let helper_start_us = if helper_timing_enabled {
    run_trace_now_us()
  } else {
    0UL
  }
  let out = Ok(run_has_branch_to_depth_in_texpr(body, 0))
  run_helper_timing_commit(
    helper_timing_enabled, run_helper_timing_branch_scope_scan_us, run_helper_timing_branch_scope_scan_calls,
    helper_start_us,
  )
  out
}

///|
fn run_remove_unused_names_once(
  body : TExpr,
  helper_timing_enabled? : Bool = false,
) -> Result[(TExpr, Bool), String] {
  let helper_start_us = if helper_timing_enabled {
    run_trace_now_us()
  } else {
    0UL
  }
  let pass = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    let walked = match self.walk_tinstruction_default((), instr) {
      Ok((out, _)) => out
      Err(e) => return error(e)
    }

    let rewritten = match walked.kind {
      TInstrKind::TBlock(bt, block_body) => {
        let (removed, peeled) = run_peel_single_child_same_blocks(
          bt,
          block_body,
          helper_timing_enabled~,
        )
        if removed > 0 {
          match
            run_rebase_labels_for_removed_scopes(
              peeled,
              removed,
              helper_timing_enabled~,
            ) {
            Ok(rebased) => TInstr::block(bt, rebased)
            Err(e) => return error(e)
          }
        } else {
          walked
        }
      }
      TInstrKind::TLoop(bt, loop_body) =>
        match
          run_has_branch_to_current_scope(loop_body, helper_timing_enabled~) {
          Ok(true) => walked
          Ok(false) => TInstr::block(bt, loop_body)
          Err(e) => return error(e)
        }
      _ => walked
    }

    if rewritten == instr {
      unchanged()
    } else {
      change((), rewritten)
    }
  })

  let out = match pass.walk_texpr((), body) {
    Ok((out, _)) => Ok((out, out != body))
    Err(e) => Err(e)
  }
  run_helper_timing_commit(
    helper_timing_enabled, run_helper_timing_walk_once_us, run_helper_timing_walk_once_calls,
    helper_start_us,
  )
  out
}

///|
fn run_remove_unused_names_module(
  mod : Module,
  trace? : (String) -> Unit = run_trace_noop,
  trace_all_funcs? : Bool = false,
  trace_budget? : Bool = true,
) -> Result[Module, String] {
  let trace_enabled = trace_budget
  if trace_enabled {
    run_helper_timing_reset()
    run_phase_timing_reset()
    run_hotspot_reset()
  }
  let funcs = match mod.code_sec {
    Some(CodeSec(bodies)) => bodies.length()
    None => 0
  }
  let pass_start_ms = if trace_enabled { run_trace_now_ms() } else { 0UL }
  if trace_enabled {
    trace("pass[remove_unused_names]:start funcs=\{funcs}")
  }
  let walk_start_ms = run_trace_phase_start(trace, "walk_funcs", trace_enabled)
  let out = match mod.code_sec {
    Some(CodeSec(curr_funcs)) => {
      let next_funcs : Array[Func] = []
      let mut changed = false
      for i = 0; i < curr_funcs.length(); i = i + 1 {
        let ordinal = i + 1
        let log_func = trace_enabled &&
          pass_trace_log_enabled(ordinal, trace_all_funcs)
        let func_trace = if log_func {
          fn(msg) { trace("func[\{ordinal}] \{msg}") }
        } else {
          run_trace_noop
        }
        let curr = curr_funcs[i]
        match curr {
          TFunc(params, locals, body) => {
            let func_start_ms = if log_func { run_trace_now_ms() } else { 0UL }
            let helper_timing_start = if log_func {
              run_helper_timing_snapshot()
            } else {
              run_helper_timing_zero()
            }
            let start_top_instrs = body.instrs.length()
            let locals_count = locals.length()
            func_trace(
              "start locals=\{locals_count} top_instrs=\{start_top_instrs}",
            )
            let walk_once_start_ms = if log_func {
              run_trace_now_ms()
            } else {
              0UL
            }
            func_trace("phase=walk_once:start")
            match
              run_remove_unused_names_once(
                body,
                helper_timing_enabled=trace_enabled,
              ) {
              Ok((next_body, func_changed)) => {
                let end_top_instrs = next_body.instrs.length()
                func_trace(
                  "phase=walk_once:done elapsed_ms=\{run_trace_elapsed_ms(walk_once_start_ms)} changed=\{func_changed} top_instrs=\{start_top_instrs}->\{end_top_instrs}",
                )
                if log_func {
                  let helper_timing_delta = run_helper_timing_diff(
                    run_helper_timing_snapshot(),
                    helper_timing_start,
                  )
                  run_hotspot_record(
                    ordinal,
                    helper_timing_delta.walk_once_us,
                    helper_timing_delta.rebase_labels_us,
                    locals_count,
                    start_top_instrs,
                  )
                  run_trace_emit_helper_timing(
                    trace, ordinal, helper_timing_delta,
                  )
                }
                func_trace(
                  "done elapsed_ms=\{run_trace_elapsed_ms(func_start_ms)} changed=\{func_changed} top_instrs=\{start_top_instrs}->\{end_top_instrs} locals=\{locals_count}",
                )
                if func_changed {
                  changed = true
                  next_funcs.push(Func::t_func(params, locals, next_body))
                } else {
                  next_funcs.push(curr)
                }
              }
              Err(e) => {
                if log_func {
                  let helper_timing_delta = run_helper_timing_diff(
                    run_helper_timing_snapshot(),
                    helper_timing_start,
                  )
                  run_hotspot_record(
                    ordinal,
                    helper_timing_delta.walk_once_us,
                    helper_timing_delta.rebase_labels_us,
                    locals_count,
                    start_top_instrs,
                  )
                  run_trace_emit_helper_timing(
                    trace, ordinal, helper_timing_delta,
                  )
                }
                func_trace(
                  "phase=walk_once:error elapsed_ms=\{run_trace_elapsed_ms(walk_once_start_ms)} \{e}",
                )
                func_trace(
                  "done elapsed_ms=\{run_trace_elapsed_ms(func_start_ms)} changed=false error=true",
                )
                return Err(e)
              }
            }
          }
          _ => {
            func_trace("skip non-typed-func")
            next_funcs.push(curr)
          }
        }
      }
      Ok(
        if changed {
          mod.with_code_sec(CodeSec::new(next_funcs))
        } else {
          mod
        },
      )
    }
    None => Ok(mod)
  }
  match out {
    Ok(next_mod) => {
      run_trace_phase_done(trace, "walk_funcs", walk_start_ms, trace_enabled)
      if trace_enabled {
        if trace_all_funcs {
          match run_hotspot_summary_line() {
            Some(summary) => trace(summary)
            None => ()
          }
        }
        run_trace_emit_totals(trace)
        trace(
          "pass[remove_unused_names]:done elapsed_ms=\{run_trace_elapsed_ms(pass_start_ms)}",
        )
      }
      Ok(next_mod)
    }
    Err(e) => {
      if trace_enabled {
        let phase_elapsed_ms = run_trace_elapsed_ms(walk_start_ms)
        run_phase_timing_commit("walk_funcs", phase_elapsed_ms)
        trace("phase=walk_funcs:error elapsed_ms=\{phase_elapsed_ms} \{e}")
        if trace_all_funcs {
          match run_hotspot_summary_line() {
            Some(summary) => trace(summary)
            None => ()
          }
        }
        run_trace_emit_totals(trace)
        trace(
          "pass[remove_unused_names]:error elapsed_ms=\{run_trace_elapsed_ms(pass_start_ms)} \{e}",
        )
      }
      Err(e)
    }
  }
}

///|
fn remove_unused_names_ir_pass(
  _mod : Module,
  trace? : (String) -> Unit = run_trace_noop,
  trace_all_funcs? : Bool = false,
  trace_budget? : Bool = true,
) -> ModuleTransformer[IRContext, String] {
  ModuleTransformer::new().on_module_evt(fn(_, ctx, mod) {
    match
      run_remove_unused_names_module(
        mod,
        trace~,
        trace_all_funcs~,
        trace_budget~,
      ) {
      Ok(out) => if out == mod { unchanged() } else { change(ctx, out) }
      Err(e) => error(e)
    }
  })
}

///|
fn run_remove_unused_names(
  mod : Module,
  trace? : (String) -> Unit = run_trace_noop,
  trace_all_funcs? : Bool = false,
  trace_budget? : Bool = true,
) -> Module {
  match
    run_remove_unused_names_module(mod, trace~, trace_all_funcs~, trace_budget~) {
    Ok(out) => out
    Err(e) => abort("remove_unused_names failed: \{e}")
  }
}

///|
fn run_single_func(mod : Module) -> Func {
  match mod.code_sec {
    Some(CodeSec([func])) => func
    _ => abort("expected exactly one function")
  }
}

///|
fn run_trace_has_line(lines : Array[String], needle : String) -> Bool {
  for line in lines {
    if line.contains(needle) {
      return true
    }
  }
  false
}

///|
test "remove_unused_names emits structured trace contract" {
  let body = TExpr::new([
    TInstr::loop_(BlockType::void_(), TExpr::new([TInstr::i32_const(I32(11))])),
  ])
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], [], body)]),
  )
  let lines : Array[String] = []
  ignore(
    run_remove_unused_names(
      mod,
      trace=fn(msg) { lines.push(msg) },
      trace_all_funcs=true,
    ),
  )
  assert_true(run_trace_has_line(lines, "pass[remove_unused_names]:start"))
  assert_true(run_trace_has_line(lines, "phase=walk_funcs:start"))
  assert_true(run_trace_has_line(lines, "func[1] start locals=0 top_instrs=1"))
  assert_true(run_trace_has_line(lines, "func[1] helper_timing "))
  assert_true(run_trace_has_line(lines, "func[1] done elapsed_ms="))
  assert_true(run_trace_has_line(lines, "phase=walk_funcs:done elapsed_ms="))
  assert_true(run_trace_has_line(lines, "hotspots f1:walk="))
  assert_true(run_trace_has_line(lines, "phase_totals walk_funcs_ms="))
  assert_true(run_trace_has_line(lines, "helper_totals walk_once_ms="))
  assert_true(
    run_trace_has_line(lines, "pass[remove_unused_names]:done elapsed_ms="),
  )
}

///|
test "remove_unused_names merges single-child same-typed nested blocks" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([TInstr::i32_const(I32(7))]),
        ),
      ]),
    ),
  ])
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], [], body)]),
  )
  let out = run_remove_unused_names(mod)
  match run_single_func(out) {
    TFunc(
      [],
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
    _ => fail("expected outer block to merge into child block")
  }
}

///|
test "remove_unused_names retargets branch depth when merging nested blocks" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([TInstr::br(LabelIdx::new(2), [])]),
            ),
          ]),
        ),
      ]),
    ),
  ])
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], [], body)]),
  )
  let out = run_remove_unused_names(mod)
  match run_single_func(out) {
    TFunc(
      [],
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              { instrs: [{ kind: TInstrKind::TBr(LabelIdx(next), _), .. }], .. }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(next.reinterpret_as_int(), 0)
    _ =>
      fail(
        "expected branch depth to be decremented after removing one block scope",
      )
  }
}

///|
test "remove_unused_names preserves typed branch target arity after nested block merge" {
  let body = TExpr::new([
    TInstr::drop(
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::block(
            BlockType::val_type(ValType::i32()),
            TExpr::new([
              TInstr::block(
                BlockType::val_type(ValType::i32()),
                TExpr::new([
                  TInstr::br(LabelIdx::new(2), [TInstr::i32_const(I32(5))]),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ),
  ])
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], [], body)]),
  )
  let out = run_remove_unused_names(mod)
  match run_single_func(out) {
    TFunc(
      [],
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
                          LabelIdx(next),
                          [{ kind: TInstrKind::TI32Const(I32(5)), .. }]
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
        ],
        ..,
      }
    ) => assert_eq(next.reinterpret_as_int(), 0)
    _ => fail("expected typed branch depth to be retargeted to merged parent")
  }
}

///|
test "remove_unused_names rewrites loop to block when no continue branch remains" {
  let body = TExpr::new([
    TInstr::loop_(BlockType::void_(), TExpr::new([TInstr::i32_const(I32(3))])),
  ])
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], [], body)]),
  )
  let out = run_remove_unused_names(mod)
  match run_single_func(out) {
    TFunc(
      [],
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              { instrs: [{ kind: TInstrKind::TI32Const(I32(3)), .. }], .. }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected loop with no continue target to become block")
  }
}

///|
test "remove_unused_names keeps loop when body branches to loop label" {
  let body = TExpr::new([
    TInstr::loop_(
      BlockType::void_(),
      TExpr::new([TInstr::br(LabelIdx::new(0), [])]),
    ),
  ])
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], [], body)]),
  )
  let out = run_remove_unused_names(mod)
  match run_single_func(out) {
    TFunc(_, _, { instrs: [{ kind: TInstrKind::TLoop(_, _), .. }], .. }) => ()
    _ => fail("expected loop with br 0 to remain a loop")
  }
}

///|
test "remove_unused_names rewrites non-void loop to block when no continue branch remains" {
  let body = TExpr::new([
    TInstr::loop_(
      BlockType::val_type(ValType::i32()),
      TExpr::new([TInstr::i32_const(I32(9))]),
    ),
  ])
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], [], body)]),
  )
  let out = run_remove_unused_names(mod)
  match run_single_func(out) {
    TFunc(
      [],
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              { instrs: [{ kind: TInstrKind::TI32Const(I32(9)), .. }], .. }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail("expected non-void loop without continue branches to become block")
  }
}
