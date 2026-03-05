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
priv struct RUNTraceStats {
  mut budget_exhausted_count : Int
  mut peeled_candidates : Int
  mut label_shift_attempts : Int
  mut loops_rewritten : Int
  mut loop_branch_unknown : Int
  mut final_budget_remaining : Int
  mut walk_no_progress_aborted : Bool
  mut final_visit_count : Int
}

///|
fn RUNTraceStats::new() -> RUNTraceStats {
  {
    budget_exhausted_count: 0,
    peeled_candidates: 0,
    label_shift_attempts: 0,
    loops_rewritten: 0,
    loop_branch_unknown: 0,
    final_budget_remaining: RUN_RESCAN_BUDGET_PER_FUNC,
    walk_no_progress_aborted: false,
    final_visit_count: 0,
  }
}

///|
fn remove_unused_names_ir_pass(
  _mod : Module,
  trace? : (String) -> Unit = run_trace_noop,
  trace_all_funcs? : Bool = false,
  trace_budget? : Bool = true,
) -> ModuleTransformer[IRContext] {
  let next_def_idx = Ref::new(0)
  ModuleTransformer::new().on_func_evt(fn(_, ctx, func) {
    let def_idx = next_def_idx.val
    next_def_idx.update(fn(i) { i + 1 })
    let ordinal = def_idx + 1
    let log_func = trace_all_funcs || ordinal <= 5 || ordinal % 500 == 0
    match func {
      TFunc(_, locals, body) => {
        let func_start_ms = sl_trace_now_ms()
        if log_func {
          trace(
            "func[\{ordinal}] start locals=\{locals.length()} top_instrs=\{body.instrs.length()} budget=\{RUN_RESCAN_BUDGET_PER_FUNC}",
          )
        }
        match
          run_remove_unused_names_once(
            body,
            trace~,
            ordinal~,
            trace_budget=trace_budget && log_func,
          ) {
          Ok((next_body, changed, stats)) =>
            if next_body == body {
              if log_func {
                let elapsed_ms = sl_trace_elapsed_ms(func_start_ms)
                trace(
                  "func[\{ordinal}] done elapsed_ms=\{elapsed_ms} changed=\{changed} top_instrs=\{body.instrs.length()}->\{body.instrs.length()} locals=\{locals.length()} budget_remaining=\{stats.final_budget_remaining} budget_exhausted=\{stats.budget_exhausted_count > 0} peeled=\{stats.peeled_candidates} shift_attempts=\{stats.label_shift_attempts} loop_rewrites=\{stats.loops_rewritten} visits=\{stats.final_visit_count} no_progress_abort=\{stats.walk_no_progress_aborted}",
                )
              }
              unchanged()
            } else {
              if log_func {
                let elapsed_ms = sl_trace_elapsed_ms(func_start_ms)
                trace(
                  "func[\{ordinal}] done elapsed_ms=\{elapsed_ms} changed=\{changed} top_instrs=\{body.instrs.length()}->\{next_body.instrs.length()} locals=\{locals.length()} budget_remaining=\{stats.final_budget_remaining} budget_exhausted=\{stats.budget_exhausted_count > 0} peeled=\{stats.peeled_candidates} shift_attempts=\{stats.label_shift_attempts} loop_rewrites=\{stats.loops_rewritten} visits=\{stats.final_visit_count} no_progress_abort=\{stats.walk_no_progress_aborted}",
                )
              }
              change(ctx, Func::t_func([], locals, next_body))
            }
          Err(e) => Err(e)
        }
      }
      _ => unchanged()
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
  let pass = remove_unused_names_ir_pass(
    mod,
    trace~,
    trace_all_funcs~,
    trace_budget~,
  )
  match pass.walk_module(IRContext::new(), mod) {
    Ok(Some((_, out))) => out
    Ok(None) => mod
    Err(e) => abort("remove_unused_names_ir_pass failed: \{e}")
  }
}

///|
const RUN_RESCAN_BUDGET_PER_FUNC : Int = 200000

///|
const RUN_RESCAN_BUDGET_EXHAUSTED : String = "__remove_unused_names_rescan_budget_exhausted__"

///|
const RUN_BRANCH_TO_SCOPE_FOUND : String = "__remove_unused_names_branch_to_scope_found__"

///|
const RUN_TRACE_HEARTBEAT_INTERVAL : Int = 1000

///|
const RUN_TRACE_SLOW_WALK_MS : UInt64 = 10UL

///|
const RUN_ANALYSIS_VISIT_LIMIT_PER_FUNC : Int = 50000

///|
const RUN_ANALYSIS_VISIT_LIMIT_EXHAUSTED : String = "__remove_unused_names_analysis_visit_limit_exhausted__"

///|
const RUN_NO_PROGRESS_VISIT_BUDGET_PER_FUNC : Int = 300000

///|
const RUN_NO_PROGRESS_VISIT_BUDGET_EXHAUSTED : String = "__remove_unused_names_no_progress_visit_budget_exhausted__"

///|
fn run_label_to_int(label : LabelIdx) -> Int {
  let LabelIdx(raw) = label
  raw.reinterpret_as_int()
}

///|
fn run_instr_kind_name(instr : TInstr) -> String {
  match instr.kind {
    TInstrKind::TBlock(_, _) => "block"
    TInstrKind::TLoop(_, _) => "loop"
    TInstrKind::TIf(_, _, _, _) => "if"
    TInstrKind::TTryTable(_, _, _) => "try_table"
    TInstrKind::TBr(_, _) => "br"
    TInstrKind::TBrIf(_, _, _) => "br_if"
    TInstrKind::TBrTable(_, _, _, _) => "br_table"
    TInstrKind::TReturn(_) => "return"
    TInstrKind::TCall(_, _) => "call"
    TInstrKind::TCallIndirect(_, _, _, _) => "call_indirect"
    TInstrKind::TLocalGet(_) => "local.get"
    TInstrKind::TLocalSet(_, _) => "local.set"
    TInstrKind::TLocalTee(_, _) => "local.tee"
    _ => "other"
  }
}

///|
fn run_measure_instr(instr : TInstr) -> Int {
  lcs_measure_texpr(TExpr::new([instr]))
}

///|
fn run_measure_texpr(body : TExpr) -> Int {
  lcs_measure_texpr(body)
}

///|
fn run_slow_walk_detail(instr : TInstr) -> String {
  let instr_m = run_measure_instr(instr)
  match instr.kind {
    TInstrKind::TIf(_, _, then_body, else_body) => {
      let then_m = run_measure_texpr(then_body)
      let else_m = match else_body {
        Some(other) => run_measure_texpr(other)
        None => 0
      }
      " instr_m=\{instr_m} then_m=\{then_m} else_m=\{else_m}"
    }
    TInstrKind::TBlock(_, body) | TInstrKind::TLoop(_, body) =>
      " instr_m=\{instr_m} body_m=\{run_measure_texpr(body)}"
    TInstrKind::TTryTable(_, _, body) =>
      " instr_m=\{instr_m} body_m=\{run_measure_texpr(body)}"
    _ => " instr_m=\{instr_m}"
  }
}

///|
fn run_label_from_int(idx : Int) -> LabelIdx {
  LabelIdx::new(idx.reinterpret_as_uint())
}

///|
fn run_adjust_label_for_removed_scopes(
  label : LabelIdx,
  depth : Int,
  removed_scopes : Int,
) -> LabelIdx {
  let curr = run_label_to_int(label)
  if curr > depth {
    let lowered = curr - removed_scopes
    if lowered < depth {
      run_label_from_int(depth)
    } else {
      run_label_from_int(lowered)
    }
  } else {
    label
  }
}

///|
fn run_walk_tinstruction_with_depth(
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
fn run_take_rescan_budget(budget : Ref[Int]) -> Bool {
  let remaining = budget.val
  if remaining <= 0 {
    false
  } else {
    budget.update(fn(i) { i - 1 })
    true
  }
}

///|
fn run_shift_labels_for_removed_scopes(
  body : TExpr,
  removed_scopes : Int,
  budget : Ref[Int],
) -> Result[TExpr?, String] {
  if removed_scopes <= 0 {
    return Ok(Some(body))
  }
  if budget.val <= 0 {
    return Ok(None)
  }
  let pass = ModuleTransformer::new()
    .on_labelidx_evt(fn(_, depth, label) {
      let next = run_adjust_label_for_removed_scopes(
        label, depth, removed_scopes,
      )
      if next == label {
        unchanged()
      } else {
        change(depth, next)
      }
    })
    .on_tinstruction_evt(fn(self, depth, instr) {
      if !run_take_rescan_budget(budget) {
        return Err(RUN_RESCAN_BUDGET_EXHAUSTED)
      }
      run_walk_tinstruction_with_depth(self, depth, instr)
    })
  match pass.walk_texpr(0, body) {
    Ok(Some((_, out))) => Ok(Some(out))
    Ok(None) => Ok(Some(body))
    Err(e) => if e == RUN_RESCAN_BUDGET_EXHAUSTED { Ok(None) } else { Err(e) }
  }
}

///|
fn run_peel_single_child_same_blocks(
  bt : BlockType,
  body : TExpr,
) -> (Int, TExpr) {
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
  (removed, curr)
}

///|
fn run_has_branch_to_current_scope(
  body : TExpr,
  budget : Ref[Int],
) -> Result[Bool?, String] {
  if budget.val <= 0 {
    return Ok(None)
  }
  let pass = ModuleTransformer::new()
    .on_labelidx_evt(fn(_, depth, label) {
      if run_label_to_int(label) == depth {
        return Err(RUN_BRANCH_TO_SCOPE_FOUND)
      }
      unchanged()
    })
    .on_tinstruction_evt(fn(self, depth, instr) {
      if !run_take_rescan_budget(budget) {
        return Err(RUN_RESCAN_BUDGET_EXHAUSTED)
      }
      run_walk_tinstruction_with_depth(self, depth, instr)
    })
  match pass.walk_texpr(0, body) {
    Ok(_) => Ok(Some(false))
    Err(e) =>
      if e == RUN_BRANCH_TO_SCOPE_FOUND {
        Ok(Some(true))
      } else if e == RUN_RESCAN_BUDGET_EXHAUSTED {
        Ok(None)
      } else {
        Err(e)
      }
  }
}

///|
priv struct RUNCandidateScan {
  has_block_candidate : Bool
  has_loop_candidate : Bool
  visited_instrs : Int
  skipped_large_func : Bool
}

///|
fn run_scan_remove_unused_names_candidates(
  body : TExpr,
  visit_limit? : Int = RUN_ANALYSIS_VISIT_LIMIT_PER_FUNC,
) -> Result[RUNCandidateScan, String] {
  let visited = Ref::new(0)
  let saw_block_candidate = Ref::new(false)
  let saw_loop_candidate = Ref::new(false)
  let pass = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    visited.update(fn(i) { i + 1 })
    if visited.val > visit_limit {
      return Err(RUN_ANALYSIS_VISIT_LIMIT_EXHAUSTED)
    }
    match instr.kind {
      TInstrKind::TBlock(
        bt,
        { instrs: [{ kind: TInstrKind::TBlock(child_bt, _), .. }], .. }
      ) => if child_bt == bt { saw_block_candidate.update(fn(_) { true }) }
      TInstrKind::TLoop(bt, _) =>
        if bt == BlockType::void_() {
          saw_loop_candidate.update(fn(_) { true })
        }
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  match pass.walk_texpr((), body) {
    Ok(_) =>
      Ok({
        has_block_candidate: saw_block_candidate.val,
        has_loop_candidate: saw_loop_candidate.val,
        visited_instrs: visited.val,
        skipped_large_func: false,
      })
    Err(e) =>
      if e == RUN_ANALYSIS_VISIT_LIMIT_EXHAUSTED {
        Ok({
          has_block_candidate: saw_block_candidate.val,
          has_loop_candidate: saw_loop_candidate.val,
          visited_instrs: visited.val,
          skipped_large_func: true,
        })
      } else {
        Err(e)
      }
  }
}

///|
fn run_remove_unused_names_once(
  body : TExpr,
  trace? : (String) -> Unit = run_trace_noop,
  ordinal? : Int = 0,
  trace_budget? : Bool = true,
) -> Result[(TExpr, Bool, RUNTraceStats), String] {
  let stats = RUNTraceStats::new()
  let visit_count = Ref::new(0)
  let candidate_scan = match run_scan_remove_unused_names_candidates(body) {
    Ok(found) => found
    Err(e) => return Err(e)
  }
  let candidate_found = candidate_scan.has_block_candidate ||
    candidate_scan.has_loop_candidate
  if trace_budget {
    trace(
      "func[\{ordinal}] candidate_scan candidate_found=\{candidate_found} block_candidate=\{candidate_scan.has_block_candidate} loop_candidate=\{candidate_scan.has_loop_candidate} scan_visits=\{candidate_scan.visited_instrs} skipped_large_func=\{candidate_scan.skipped_large_func} top_instrs=\{body.instrs.length()}",
    )
  }
  if !candidate_found {
    return Ok((body, false, stats))
  }
  if candidate_scan.skipped_large_func {
    if trace_budget {
      trace(
        "func[\{ordinal}] skip reason=analysis_visit_limit scan_visits=\{candidate_scan.visited_instrs} limit=\{RUN_ANALYSIS_VISIT_LIMIT_PER_FUNC} block_candidate=\{candidate_scan.has_block_candidate} loop_candidate=\{candidate_scan.has_loop_candidate}",
      )
    }
    return Ok((body, false, stats))
  }
  let start_budget = RUN_RESCAN_BUDGET_PER_FUNC
  let rescan_budget = Ref::new(start_budget)
  let note_budget_exhausted = fn() { stats.budget_exhausted_count += 1 }
  let remaining_budget = fn() {
    let remaining = rescan_budget.val
    if remaining > 0 {
      remaining
    } else {
      0
    }
  }
  let note_visit = fn(instr : TInstr) {
    visit_count.update(fn(i) { i + 1 })
    let visit = visit_count.val
    if trace_budget && visit % RUN_TRACE_HEARTBEAT_INTERVAL == 0 {
      trace(
        "func[\{ordinal}] heartbeat visits=\{visit} kind=\{run_instr_kind_name(instr)} remaining_budget=\{remaining_budget()}",
      )
    }
    visit
  }
  let mut changed = false
  let pass = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    let visit = note_visit(instr)
    if !changed && visit > RUN_NO_PROGRESS_VISIT_BUDGET_PER_FUNC {
      stats.walk_no_progress_aborted = true
      if trace_budget {
        trace(
          "func[\{ordinal}] visit=\{visit} kind=\{run_instr_kind_name(instr)} no_progress_abort budget=\{RUN_NO_PROGRESS_VISIT_BUDGET_PER_FUNC} remaining_budget=\{remaining_budget()}",
        )
      }
      return Err(RUN_NO_PROGRESS_VISIT_BUDGET_EXHAUSTED)
    }
    let mut seed = instr
    match instr.kind {
      TInstrKind::TBlock(bt, body) => {
        let (removed, peeled) = run_peel_single_child_same_blocks(bt, body)
        if removed > 0 {
          stats.peeled_candidates += 1
          stats.label_shift_attempts += 1
          let shift_start_ms = sl_trace_now_ms()
          if trace_budget {
            trace(
              "func[\{ordinal}] visit=\{visit} kind=block shift:start removed=\{removed} remaining_budget=\{remaining_budget()}",
            )
          }
          let shifted = match
            run_shift_labels_for_removed_scopes(peeled, removed, rescan_budget) {
            Ok(Some(out)) => {
              if trace_budget {
                let elapsed_ms = sl_trace_elapsed_ms(shift_start_ms)
                trace(
                  "func[\{ordinal}] visit=\{visit} kind=block shift:done removed=\{removed} applied=true elapsed_ms=\{elapsed_ms} remaining_budget=\{remaining_budget()}",
                )
              }
              Some(out)
            }
            Ok(None) => {
              note_budget_exhausted()
              if trace_budget {
                let elapsed_ms = sl_trace_elapsed_ms(shift_start_ms)
                trace(
                  "func[\{ordinal}] visit=\{visit} kind=block shift:done removed=\{removed} applied=false skipped=budget elapsed_ms=\{elapsed_ms} remaining_budget=\{remaining_budget()}",
                )
              }
              None
            }
            Err(e) => return Err(e)
          }
          match shifted {
            Some(next_body) => {
              let next_seed = TInstr::block(bt, next_body)
              if next_seed != instr {
                changed = true
              }
              seed = next_seed
            }
            None => ()
          }
        }
      }
      _ => ()
    }

    let walk_start_ms = sl_trace_now_ms()
    let walked = match self.walk_tinstruction_default((), seed) {
      Ok(Some((_, out))) => out
      Ok(None) => seed
      Err(e) => return Err(e)
    }
    let elapsed_ms = sl_trace_elapsed_ms(walk_start_ms)
    if trace_budget && elapsed_ms >= RUN_TRACE_SLOW_WALK_MS {
      trace(
        "func[\{ordinal}] visit=\{visit} kind=\{run_instr_kind_name(seed)} walk_default:slow elapsed_ms=\{elapsed_ms} remaining_budget=\{remaining_budget()}\{run_slow_walk_detail(seed)}",
      )
    }
    let rewritten = match walked.kind {
      TInstrKind::TBlock(bt, body) => {
        let (removed, peeled) = run_peel_single_child_same_blocks(bt, body)
        if removed <= 0 {
          walked
        } else {
          stats.peeled_candidates += 1
          stats.label_shift_attempts += 1
          let shift_start_ms = sl_trace_now_ms()
          if trace_budget {
            trace(
              "func[\{ordinal}] visit=\{visit} kind=block post_walk_shift:start removed=\{removed} remaining_budget=\{remaining_budget()}",
            )
          }
          match
            run_shift_labels_for_removed_scopes(peeled, removed, rescan_budget) {
            Ok(Some(next_body)) => {
              if trace_budget {
                let elapsed_ms = sl_trace_elapsed_ms(shift_start_ms)
                trace(
                  "func[\{ordinal}] visit=\{visit} kind=block post_walk_shift:done removed=\{removed} applied=true elapsed_ms=\{elapsed_ms} remaining_budget=\{remaining_budget()}",
                )
              }
              let next = TInstr::block(bt, next_body)
              if next != walked {
                changed = true
              }
              next
            }
            Ok(None) => {
              note_budget_exhausted()
              if trace_budget {
                let elapsed_ms = sl_trace_elapsed_ms(shift_start_ms)
                trace(
                  "func[\{ordinal}] visit=\{visit} kind=block post_walk_shift:done removed=\{removed} applied=false skipped=budget elapsed_ms=\{elapsed_ms} remaining_budget=\{remaining_budget()}",
                )
              }
              walked
            }
            Err(e) => return Err(e)
          }
        }
      }
      TInstrKind::TLoop(bt, loop_body) =>
        if bt == BlockType::void_() {
          let branch_start_ms = sl_trace_now_ms()
          if trace_budget {
            trace(
              "func[\{ordinal}] visit=\{visit} kind=loop branch_check:start remaining_budget=\{remaining_budget()}",
            )
          }
          let has_branch = match
            run_has_branch_to_current_scope(loop_body, rescan_budget) {
            Ok(Some(found)) => {
              if trace_budget {
                let elapsed_ms = sl_trace_elapsed_ms(branch_start_ms)
                trace(
                  "func[\{ordinal}] visit=\{visit} kind=loop branch_check:done found=\{found} elapsed_ms=\{elapsed_ms} remaining_budget=\{remaining_budget()}",
                )
              }
              found
            }
            Ok(None) => {
              note_budget_exhausted()
              stats.loop_branch_unknown += 1
              if trace_budget {
                let elapsed_ms = sl_trace_elapsed_ms(branch_start_ms)
                trace(
                  "func[\{ordinal}] visit=\{visit} kind=loop branch_check:done found=unknown skipped=budget elapsed_ms=\{elapsed_ms} remaining_budget=\{remaining_budget()}",
                )
              }
              true
            }
            Err(e) => return Err(e)
          }
          if has_branch {
            walked
          } else {
            changed = true
            stats.loops_rewritten += 1
            TInstr::block(bt, loop_body)
          }
        } else {
          walked
        }
      _ => walked
    }
    if rewritten == instr {
      unchanged()
    } else {
      change((), rewritten)
    }
  })
  let final_result = match pass.walk_texpr((), body) {
    Ok(Some((_, out))) => Ok((out, changed, stats))
    Ok(None) => Ok((body, changed, stats))
    Err(e) =>
      if e == RUN_NO_PROGRESS_VISIT_BUDGET_EXHAUSTED {
        Ok((body, false, stats))
      } else {
        return Err(e)
      }
  }
  match final_result {
    Ok((out, changed, stats)) => {
      let budget_remaining = remaining_budget()
      stats.final_budget_remaining = budget_remaining
      stats.final_visit_count = visit_count.val
      if trace_budget {
        trace(
          "func[\{ordinal}] summary candidate_found=\{candidate_found} changed=\{changed} out_eq_input=\{out == body} budget_remaining=\{budget_remaining} budget_exhausted_count=\{stats.budget_exhausted_count} peeled=\{stats.peeled_candidates} shift_attempts=\{stats.label_shift_attempts} loop_rewrites=\{stats.loops_rewritten} loop_branch_unknown=\{stats.loop_branch_unknown} visits=\{stats.final_visit_count} no_progress_abort=\{stats.walk_no_progress_aborted}",
        )
      }
      if trace_budget && candidate_found && !changed && budget_remaining == 0 {
        trace(
          "func[\{ordinal}] stalled candidate_found=true changed=false budget_remaining=0",
        )
      }
      if trace_budget && stats.walk_no_progress_aborted {
        trace(
          "func[\{ordinal}] stalled candidate_found=\{candidate_found} changed=false reason=no_progress_visit_budget visits=\{stats.final_visit_count}",
        )
      }
      Ok((out, changed, stats))
    }
    Err(e) => Err(e)
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
test "remove_unused_names analysis skips large funcs even with early block candidate" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([TInstr::i32_const(I32(1))]),
        ),
      ]),
    ),
  ])
  match run_scan_remove_unused_names_candidates(body, visit_limit=1) {
    Ok(scan) => {
      assert_true(scan.has_block_candidate)
      assert_false(scan.has_loop_candidate)
      assert_true(scan.skipped_large_func)
    }
    Err(e) => fail("unexpected candidate scan error: \{e}")
  }
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
