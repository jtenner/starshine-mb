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
/// Code Folding Pass
///
/// Folds duplicate code together, saving space (and possibly phis in
/// the wasm VM, which can save time).
///
/// We fold tails of code where they merge and moving the code
/// to the merge point is helpful. There are two cases here:
/// (1) expressions, in which we merge to right after the expression itself:
///   * blocks: we merge the fallthrough + the breaks
///   * if-else: we merge the arms
/// (2) the function body as a whole, in which we can merge returns or
///     unreachables, putting the merged code at the end of the function body.
///
/// For example, with an if-else, we might merge this:
///   (if (condition)
///     (block A C)
///     (block B C)
///   )
/// to:
///   (if (condition)
///     (block A)
///     (block B)
///   )
///   C

///|
const WORTH_ADDING_BLOCK_TO_REMOVE_THIS_MUCH : Int = 3

///|
/// Minimum savings required before we add overhead for terminating tails
const MIN_TERMINATING_TAIL_SAVINGS : Int = 2

///|
/// Skip expression folding when the structured-control surface is too large.
const CF_EXPR_SITE_LIMIT : Int = 1024

///|
/// Skip expression folding walk when the tail-collection traversal is already too large.
const CF_COLLECT_BODY_LIMIT : Int = 512

///|
/// Skip expensive terminating-tail rewrites when both the candidate set and
/// control-surface traversal are already very large.
const CF_TERMINATING_TAIL_COUNT_LIMIT : Int = 64

///|
/// Tail-collection body visits beyond this point indicate large control-heavy
/// functions where terminating-tail scans are often not profitable.
const CF_TERMINATING_COLLECT_BODY_LIMIT : Int = 256

///|
/// Expression tail folding is enabled for self-contained suffixes that can be
/// rebuilt as wrapper blocks without changing stack requirements.
const CF_ENABLE_EXPRESSION_FOLDING : Bool = true

///|
/// Skip block-tail folding when the candidate cross-product gets too large.
const CF_BLOCK_FANOUT_LIMIT : Int = 4096

///|
/// For tiny leaf-only functions, code folding cannot make progress, so skip the round setup.
const CF_TRIVIAL_FUNC_FAST_SKIP_TOP_INSTR_LIMIT : Int = 4

///|
/// Emit progress logs from long-running expression tail folds at this cadence.
const CF_EXPR_PROGRESS_LOG_INTERVAL_US : UInt64 = 250000UL

///|
priv struct CodeFoldingRoundTraceStats {
  mut enabled : Bool
  mut collect_calls : Int
  mut collect_instrs : Int
  mut collect_us : UInt64
  mut return_phase_calls : Int
  mut return_phase_successes : Int
  mut return_phase_tails : Int
  mut return_phase_us : UInt64
  mut unreachable_phase_calls : Int
  mut unreachable_phase_successes : Int
  mut unreachable_phase_tails : Int
  mut unreachable_phase_us : UInt64
  mut terminating_group_pair_checks : Int
  mut block_visits : Int
  mut block_successes : Int
  mut if_visits : Int
  mut if_successes : Int
  mut expr_calls : Int
  mut expr_successes : Int
  mut expr_tail_count : Int
  mut expr_merged_instrs : Int
  mut expr_saved : Int
  mut expr_us : UInt64
  mut expr_match_us : UInt64
  mut expr_can_move_us : UInt64
  mut expr_measure_us : UInt64
  mut measure_calls : Int
  mut measure_nodes : Int
  mut measure_us : UInt64
  mut branch_target_calls : Int
  mut branch_target_us : UInt64
  mut can_move_calls : Int
  mut can_move_us : UInt64
  mut walk_us : UInt64
}

///|
priv struct CodeFoldingBreakTailTraceStats {
  label_count : Int
  tail_count : Int
  max_label_tails : Int
}

///|
priv struct CodeFoldingExprTraceCtx {
  enabled : Bool
  trace : (String) -> Unit
  func_ordinal : Int
  round : Int
  site_kind : String
}

///|
fn cf_round_trace_stats_new() -> CodeFoldingRoundTraceStats {
  {
    enabled: false,
    collect_calls: 0,
    collect_instrs: 0,
    collect_us: 0UL,
    return_phase_calls: 0,
    return_phase_successes: 0,
    return_phase_tails: 0,
    return_phase_us: 0UL,
    unreachable_phase_calls: 0,
    unreachable_phase_successes: 0,
    unreachable_phase_tails: 0,
    unreachable_phase_us: 0UL,
    terminating_group_pair_checks: 0,
    block_visits: 0,
    block_successes: 0,
    if_visits: 0,
    if_successes: 0,
    expr_calls: 0,
    expr_successes: 0,
    expr_tail_count: 0,
    expr_merged_instrs: 0,
    expr_saved: 0,
    expr_us: 0UL,
    expr_match_us: 0UL,
    expr_can_move_us: 0UL,
    expr_measure_us: 0UL,
    measure_calls: 0,
    measure_nodes: 0,
    measure_us: 0UL,
    branch_target_calls: 0,
    branch_target_us: 0UL,
    can_move_calls: 0,
    can_move_us: 0UL,
    walk_us: 0UL,
  }
}

///|
fn CodeFoldingRoundTraceStats::clear(self : CodeFoldingRoundTraceStats) -> Unit {
  self.collect_calls = 0
  self.collect_instrs = 0
  self.collect_us = 0UL
  self.return_phase_calls = 0
  self.return_phase_successes = 0
  self.return_phase_tails = 0
  self.return_phase_us = 0UL
  self.unreachable_phase_calls = 0
  self.unreachable_phase_successes = 0
  self.unreachable_phase_tails = 0
  self.unreachable_phase_us = 0UL
  self.terminating_group_pair_checks = 0
  self.block_visits = 0
  self.block_successes = 0
  self.if_visits = 0
  self.if_successes = 0
  self.expr_calls = 0
  self.expr_successes = 0
  self.expr_tail_count = 0
  self.expr_merged_instrs = 0
  self.expr_saved = 0
  self.expr_us = 0UL
  self.expr_match_us = 0UL
  self.expr_can_move_us = 0UL
  self.expr_measure_us = 0UL
  self.measure_calls = 0
  self.measure_nodes = 0
  self.measure_us = 0UL
  self.branch_target_calls = 0
  self.branch_target_us = 0UL
  self.can_move_calls = 0
  self.can_move_us = 0UL
  self.walk_us = 0UL
}

///|
fn CodeFoldingRoundTraceStats::merge_from(
  self : CodeFoldingRoundTraceStats,
  other : CodeFoldingRoundTraceStats,
) -> Unit {
  self.collect_calls += other.collect_calls
  self.collect_instrs += other.collect_instrs
  self.collect_us = self.collect_us + other.collect_us
  self.return_phase_calls += other.return_phase_calls
  self.return_phase_successes += other.return_phase_successes
  self.return_phase_tails += other.return_phase_tails
  self.return_phase_us = self.return_phase_us + other.return_phase_us
  self.unreachable_phase_calls += other.unreachable_phase_calls
  self.unreachable_phase_successes += other.unreachable_phase_successes
  self.unreachable_phase_tails += other.unreachable_phase_tails
  self.unreachable_phase_us = self.unreachable_phase_us +
    other.unreachable_phase_us
  self.terminating_group_pair_checks += other.terminating_group_pair_checks
  self.block_visits += other.block_visits
  self.block_successes += other.block_successes
  self.if_visits += other.if_visits
  self.if_successes += other.if_successes
  self.expr_calls += other.expr_calls
  self.expr_successes += other.expr_successes
  self.expr_tail_count += other.expr_tail_count
  self.expr_merged_instrs += other.expr_merged_instrs
  self.expr_saved += other.expr_saved
  self.expr_us = self.expr_us + other.expr_us
  self.expr_match_us = self.expr_match_us + other.expr_match_us
  self.expr_can_move_us = self.expr_can_move_us + other.expr_can_move_us
  self.expr_measure_us = self.expr_measure_us + other.expr_measure_us
  self.measure_calls += other.measure_calls
  self.measure_nodes += other.measure_nodes
  self.measure_us = self.measure_us + other.measure_us
  self.branch_target_calls += other.branch_target_calls
  self.branch_target_us = self.branch_target_us + other.branch_target_us
  self.can_move_calls += other.can_move_calls
  self.can_move_us = self.can_move_us + other.can_move_us
  self.walk_us = self.walk_us + other.walk_us
}

///|
fn CodeFoldingRoundTraceStats::set_enabled(
  self : CodeFoldingRoundTraceStats,
  enabled : Bool,
) -> Unit {
  self.enabled = enabled
}

///|
fn cf_trace_stats_enabled(trace_stats : CodeFoldingRoundTraceStats) -> Bool {
  trace_stats.enabled
}

///|
fn cf_trace_noop(_ : String) -> Unit {
  ()
}

///|
fn cf_trace_delta_us_to_ms(delta_us : UInt64) -> UInt64 {
  pass_trace_delta_us_to_ms(delta_us)
}

///|
fn cf_trace_now_us() -> UInt64 {
  pass_trace_now_us()
}

///|
fn cf_trace_elapsed_us_since(start_us : UInt64) -> UInt64 {
  pass_trace_elapsed_us_since(start_us)
}

///|
/// Information about a "tail" - code that reaches a point that we can merge
struct Tail {
  instr : TInstr? // None if this is a fallthrough
  block_instrs : Array[TInstr] // immutable snapshot of the enclosing block body
  exact_only : Bool
} derive(Eq)

///|
priv struct ExprFoldPlan {
  merged_instrs : Array[TInstr]
  saved : Int
}

///|
priv enum BlockTailPathStep {
  BlockBody(Int)
  LoopBody(Int)
  IfThen(Int)
  IfElse(Int)
  TryBody(Int)
} derive(Eq)

///|
priv struct ScopedTail {
  tail : Tail
  path : Array[BlockTailPathStep]
  exact_index : Int?
}

///|
priv struct CodeFoldingTempLocal {
  local_idx : LocalIdx
  value_instr : TInstr
}

///|
fn cf_copy_instrs(instrs : Array[TInstr]) -> Array[TInstr] {
  let out : Array[TInstr] = []
  for instr in instrs {
    out.push(instr)
  }
  out
}

///|
fn Tail::fallthrough(block_instrs : Array[TInstr]) -> Tail {
  Tail::{
    instr: None,
    block_instrs: cf_copy_instrs(block_instrs),
    exact_only: false,
  }
}

///|
fn Tail::branch(instr : TInstr, block_instrs : Array[TInstr]) -> Tail {
  Tail::{
    instr: Some(instr),
    block_instrs: cf_copy_instrs(block_instrs),
    exact_only: false,
  }
}

///|
fn Tail::exact(instr : TInstr, block_instrs : Array[TInstr]) -> Tail {
  Tail::{
    instr: Some(instr),
    block_instrs: cf_copy_instrs(block_instrs),
    exact_only: true,
  }
}

///|
fn Tail::is_fallthrough(self : Tail) -> Bool {
  self.instr is None
}

///|
fn Tail::is_exact_only(self : Tail) -> Bool {
  self.exact_only
}

///|
/// State for the code folding pass
priv struct CodeFoldingState {
  mut another_pass : Bool
  mut env : Env
  param_types : Array[ValType]
  mut func_locals : Array[ValType]
  break_tails : Map[LabelIdx, Array[Tail]]
  unreachable_tails : Array[ScopedTail]
  return_tails : Array[ScopedTail]
  unoptimizables : Set[LabelIdx]
  modifieds : Set[TInstr]
  mut block_sites : Int
  mut if_else_sites : Int
  parent_is_block : Bool
}

///|
fn CodeFoldingState::new(
  env? : Env = Env::new(),
  param_types? : Array[ValType] = [],
  func_locals? : Array[ValType] = [],
) -> CodeFoldingState {
  let initial_env = if func_locals.is_empty() {
    env
  } else {
    env.with_locals(func_locals)
  }
  CodeFoldingState::{
    another_pass: true,
    env: initial_env,
    param_types,
    func_locals,
    break_tails: Map::new(),
    unreachable_tails: [],
    return_tails: [],
    unoptimizables: Set::new(),
    modifieds: Set::new(),
    block_sites: 0,
    if_else_sites: 0,
    parent_is_block: false,
  }
}

///|
fn CodeFoldingState::clear(self : CodeFoldingState) -> Unit {
  self.break_tails.clear()
  self.unreachable_tails.clear()
  self.return_tails.clear()
  self.unoptimizables.clear()
  self.modifieds.clear()
  self.block_sites = 0
  self.if_else_sites = 0
}

///|
fn CodeFoldingState::prepare_func(
  self : CodeFoldingState,
  locals : Array[ValType],
) -> Unit {
  self.func_locals = locals.copy()
  self.env = self.env.with_locals(self.func_locals)
}

///|
fn cf_non_param_locals(
  full_locals : Array[ValType],
  param_count : Int,
) -> Array[ValType] {
  let out : Array[ValType] = []
  let mut i = if param_count < 0 { 0 } else { param_count }
  while i < full_locals.length() {
    out.push(full_locals[i])
    i += 1
  }
  out
}

///|
fn cf_build_tfunc(
  params : Array[ValType],
  full_locals : Array[ValType],
  body : TExpr,
) -> Func {
  Func::t_func(params, cf_non_param_locals(full_locals, params.length()), body)
}

///|
fn CodeFoldingState::preview_appended_local(
  self : CodeFoldingState,
  ty : ValType,
) -> (LocalIdx, Array[ValType], Env) {
  let next_locals = self.func_locals.copy()
  next_locals.push(ty)
  let idx = LocalIdx::new(self.func_locals.length().reinterpret_as_uint())
  (idx, next_locals, self.env.with_locals(next_locals))
}

///|
fn CodeFoldingState::append_local(
  self : CodeFoldingState,
  ty : ValType,
) -> LocalIdx {
  let (idx, next_locals, next_env) = self.preview_appended_local(ty)
  self.func_locals = next_locals
  self.env = next_env
  idx
}

///|
fn cf_instr_has_control_surface(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TBlock(_, _)
    | TInstrKind::TLoop(_, _)
    | TInstrKind::TIf(_, _, _, _)
    | TInstrKind::TTryTable(_, _, _) => true
    _ => {
      for child in eval_children(instr) {
        if cf_instr_has_control_surface(child) {
          return true
        }
      }
      false
    }
  }
}

///|
fn cf_texpr_has_control_surface(expr : TExpr) -> Bool {
  for instr in expr.instrs {
    if cf_instr_has_control_surface(instr) {
      return true
    }
  }
  false
}

///|
fn cf_can_fast_skip_func_body(body : TExpr) -> Bool {
  let top_instrs = body.instrs.length()
  if top_instrs > CF_TRIVIAL_FUNC_FAST_SKIP_TOP_INSTR_LIMIT {
    return false
  }
  !cf_texpr_has_control_surface(body)
}

///|
fn cf_should_skip_terminating_tail_phase(
  tail_count : Int,
  collect_calls : Int,
) -> Bool {
  tail_count >= CF_TERMINATING_TAIL_COUNT_LIMIT &&
  collect_calls > CF_TERMINATING_COLLECT_BODY_LIMIT
}

///|
/// Check if an instruction terminates control flow (unreachable or return)
fn is_terminating(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TUnreachable => true
    TInstrKind::TReturn(_) => true
    TInstrKind::TReturnCall(_, _) => true
    TInstrKind::TReturnCallIndirect(_, _, _, _) => true
    TInstrKind::TReturnCallRef(_, _, _) => true
    TInstrKind::TThrow(_, _) => true
    TInstrKind::TThrowRef(_) => true
    _ => false
  }
}

///|
/// Check if an instruction is a branch (br, br_if, br_table)
fn is_branch(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TBr(_, _) => true
    TInstrKind::TBrIf(_, _, _) => true
    TInstrKind::TBrTable(_, _, _, _) => true
    TInstrKind::TBrOnNull(_, _, _) => true
    TInstrKind::TBrOnNonNull(_, _, _) => true
    TInstrKind::TBrOnCast(_, _, _, _, _, _) => true
    TInstrKind::TBrOnCastFail(_, _, _, _, _, _) => true
    _ => false
  }
}

///|
/// Measure the size/cost of a TInstr for optimization decisions
fn measure_with_trace(
  instr : TInstr,
  trace_stats : CodeFoldingRoundTraceStats,
) -> Int {
  let trace_enabled = cf_trace_stats_enabled(trace_stats)
  let start_us = if trace_enabled { cf_trace_now_us() } else { 0UL }
  if trace_enabled {
    trace_stats.measure_calls += 1
  }
  // Simple heuristic: count 1 for each instruction node
  // This is a simplified version of Binaryen's Measurer
  let mut count = 1
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      c,
      i : TInstr,
    ) {
      count += 1
      from_walk(self.walk_tinstruction_default(c, i))
    },
  )
  ignore(walker.walk_tinstruction((), instr))
  if trace_enabled {
    trace_stats.measure_nodes += count
    trace_stats.measure_us = trace_stats.measure_us +
      cf_trace_elapsed_us_since(start_us)
  }
  count
}

///|
/// Measure total size of an array of instructions
fn measure(instr : TInstr) -> Int {
  measure_with_trace(instr, cf_round_trace_stats_new())
}

///|
/// Measure total size of an array of instructions
fn measure_all_with_trace(
  instrs : Array[TInstr],
  trace_stats : CodeFoldingRoundTraceStats,
) -> Int {
  let mut total = 0
  for instr in instrs {
    total += measure_with_trace(instr, trace_stats)
  }
  total
}

///|
/// Get all branch targets (labels) that appear in an instruction
fn measure_all(instrs : Array[TInstr]) -> Int {
  measure_all_with_trace(instrs, cf_round_trace_stats_new())
}

///|
/// Get all branch targets (labels) that appear in an instruction
fn get_branch_targets_with_trace(
  instr : TInstr,
  trace_stats : CodeFoldingRoundTraceStats,
) -> Set[LabelIdx] {
  let trace_enabled = cf_trace_stats_enabled(trace_stats)
  let start_us = if trace_enabled { cf_trace_now_us() } else { 0UL }
  if trace_enabled {
    trace_stats.branch_target_calls += 1
  }
  let targets = Set::new()
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      i : TInstr,
    ) {
      match i.kind {
        TInstrKind::TBr(label, _) => targets.add(label)
        TInstrKind::TBrIf(label, _, _) => targets.add(label)
        TInstrKind::TBrTable(labels, default, _, _) => {
          for label in labels {
            targets.add(label)
          }
          targets.add(default)
        }
        TInstrKind::TBrOnNull(label, _, _) => targets.add(label)
        TInstrKind::TBrOnNonNull(label, _, _) => targets.add(label)
        TInstrKind::TBrOnCast(label, _, _, _, _, _) => targets.add(label)
        TInstrKind::TBrOnCastFail(label, _, _, _, _, _) => targets.add(label)
        _ => ()
      }
      from_walk(self.walk_tinstruction_default((), i))
    },
  )
  ignore(walker.walk_tinstruction((), instr))
  if trace_enabled {
    trace_stats.branch_target_us = trace_stats.branch_target_us +
      cf_trace_elapsed_us_since(start_us)
  }
  targets
}

///|
/// Get branch targets that exit the given instruction (branch to outside)
fn get_branch_targets(instr : TInstr) -> Set[LabelIdx] {
  get_branch_targets_with_trace(instr, cf_round_trace_stats_new())
}

///|
fn cf_label_depth(label : LabelIdx) -> Int {
  let LabelIdx(raw) = label
  raw.reinterpret_as_int()
}

///|
fn cf_next_label_uid(next_uid : Ref[Int]) -> Int {
  let uid = next_uid.val
  next_uid.val = uid + 1
  uid
}

///|
fn cf_push_label_uid(label_uids : Array[Int], uid : Int) -> Array[Int] {
  let next = label_uids.copy()
  next.push(uid)
  next
}

///|
fn cf_resolve_label_uid(label_uids : Array[Int], label : LabelIdx) -> Int? {
  let depth = cf_label_depth(label)
  let idx = label_uids.length() - 1 - depth
  if idx < 0 || idx >= label_uids.length() {
    None
  } else {
    Some(label_uids[idx])
  }
}

///|
fn cf_add_uid_to_sets(
  target_uid : Int,
  all_targets : Set[Int],
  active_focuses : Array[Int],
  focus_targets : Array[Set[Int]],
) -> Unit {
  all_targets.add(target_uid)
  for focus_idx in active_focuses {
    focus_targets[focus_idx].add(target_uid)
  }
}

///|
/// Sentinel target uid used when a branch exits the analyzed container.
const CF_EXTERNAL_TARGET_UID : Int = 0

///|
fn cf_add_label_target_uid(
  label_uids : Array[Int],
  label : LabelIdx,
  all_targets : Set[Int],
  active_focuses : Array[Int],
  focus_targets : Array[Set[Int]],
) -> Unit {
  match cf_resolve_label_uid(label_uids, label) {
    Some(target_uid) =>
      cf_add_uid_to_sets(target_uid, all_targets, active_focuses, focus_targets)
    None =>
      cf_add_uid_to_sets(
        CF_EXTERNAL_TARGET_UID,
        all_targets,
        active_focuses,
        focus_targets,
      )
  }
}

///|
fn cf_walk_branch_targets_with_focus(
  instr : TInstr,
  label_uids : Array[Int],
  next_uid : Ref[Int],
  all_targets : Set[Int],
  focus_items : Array[TInstr],
  focus_targets : Array[Set[Int]],
  focus_labels : Array[Set[Int]],
  active_focuses : Array[Int],
) -> Unit {
  let next_focuses = active_focuses.copy()
  let mut focus_idx = 0
  while focus_idx < focus_items.length() {
    if instr == focus_items[focus_idx] {
      next_focuses.push(focus_idx)
    }
    focus_idx += 1
  }

  match instr.kind {
    TInstrKind::TBr(label, _) =>
      cf_add_label_target_uid(
        label_uids, label, all_targets, next_focuses, focus_targets,
      )
    TInstrKind::TBrIf(label, cond, values) => {
      cf_walk_branch_targets_with_focus(
        cond, label_uids, next_uid, all_targets, focus_items, focus_targets, focus_labels,
        next_focuses,
      )
      for value in values {
        cf_walk_branch_targets_with_focus(
          value, label_uids, next_uid, all_targets, focus_items, focus_targets, focus_labels,
          next_focuses,
        )
      }
      cf_add_label_target_uid(
        label_uids, label, all_targets, next_focuses, focus_targets,
      )
    }
    TInstrKind::TBrTable(labels, default, index, values) => {
      cf_walk_branch_targets_with_focus(
        index, label_uids, next_uid, all_targets, focus_items, focus_targets, focus_labels,
        next_focuses,
      )
      for value in values {
        cf_walk_branch_targets_with_focus(
          value, label_uids, next_uid, all_targets, focus_items, focus_targets, focus_labels,
          next_focuses,
        )
      }
      for label in labels {
        cf_add_label_target_uid(
          label_uids, label, all_targets, next_focuses, focus_targets,
        )
      }
      cf_add_label_target_uid(
        label_uids, default, all_targets, next_focuses, focus_targets,
      )
    }
    TInstrKind::TBrOnNull(label, ref_, values) => {
      cf_walk_branch_targets_with_focus(
        ref_, label_uids, next_uid, all_targets, focus_items, focus_targets, focus_labels,
        next_focuses,
      )
      for value in values {
        cf_walk_branch_targets_with_focus(
          value, label_uids, next_uid, all_targets, focus_items, focus_targets, focus_labels,
          next_focuses,
        )
      }
      cf_add_label_target_uid(
        label_uids, label, all_targets, next_focuses, focus_targets,
      )
    }
    TInstrKind::TBrOnNonNull(label, ref_, values) => {
      cf_walk_branch_targets_with_focus(
        ref_, label_uids, next_uid, all_targets, focus_items, focus_targets, focus_labels,
        next_focuses,
      )
      for value in values {
        cf_walk_branch_targets_with_focus(
          value, label_uids, next_uid, all_targets, focus_items, focus_targets, focus_labels,
          next_focuses,
        )
      }
      cf_add_label_target_uid(
        label_uids, label, all_targets, next_focuses, focus_targets,
      )
    }
    TInstrKind::TBrOnCast(label, cast_op, source_ht, target_ht, ref_, values) => {
      ignore(cast_op)
      ignore(source_ht)
      ignore(target_ht)
      cf_walk_branch_targets_with_focus(
        ref_, label_uids, next_uid, all_targets, focus_items, focus_targets, focus_labels,
        next_focuses,
      )
      for value in values {
        cf_walk_branch_targets_with_focus(
          value, label_uids, next_uid, all_targets, focus_items, focus_targets, focus_labels,
          next_focuses,
        )
      }
      cf_add_label_target_uid(
        label_uids, label, all_targets, next_focuses, focus_targets,
      )
    }
    TInstrKind::TBrOnCastFail(
      label,
      cast_op,
      source_ht,
      target_ht,
      ref_,
      values
    ) => {
      ignore(cast_op)
      ignore(source_ht)
      ignore(target_ht)
      cf_walk_branch_targets_with_focus(
        ref_, label_uids, next_uid, all_targets, focus_items, focus_targets, focus_labels,
        next_focuses,
      )
      for value in values {
        cf_walk_branch_targets_with_focus(
          value, label_uids, next_uid, all_targets, focus_items, focus_targets, focus_labels,
          next_focuses,
        )
      }
      cf_add_label_target_uid(
        label_uids, label, all_targets, next_focuses, focus_targets,
      )
    }
    TInstrKind::TBlock(bt, body) => {
      ignore(bt)
      let uid = cf_next_label_uid(next_uid)
      for focus_idx in next_focuses {
        focus_labels[focus_idx].add(uid)
      }
      let body_uids = cf_push_label_uid(label_uids, uid)
      for child in body.instrs {
        cf_walk_branch_targets_with_focus(
          child, body_uids, next_uid, all_targets, focus_items, focus_targets, focus_labels,
          next_focuses,
        )
      }
    }
    TInstrKind::TLoop(bt, body) => {
      ignore(bt)
      let uid = cf_next_label_uid(next_uid)
      for focus_idx in next_focuses {
        focus_labels[focus_idx].add(uid)
      }
      let body_uids = cf_push_label_uid(label_uids, uid)
      for child in body.instrs {
        cf_walk_branch_targets_with_focus(
          child, body_uids, next_uid, all_targets, focus_items, focus_targets, focus_labels,
          next_focuses,
        )
      }
    }
    TInstrKind::TIf(bt, cond, then_body, else_body) => {
      ignore(bt)
      cf_walk_branch_targets_with_focus(
        cond, label_uids, next_uid, all_targets, focus_items, focus_targets, focus_labels,
        next_focuses,
      )
      let uid = cf_next_label_uid(next_uid)
      for focus_idx in next_focuses {
        focus_labels[focus_idx].add(uid)
      }
      let branch_uids = cf_push_label_uid(label_uids, uid)
      for child in then_body.instrs {
        cf_walk_branch_targets_with_focus(
          child, branch_uids, next_uid, all_targets, focus_items, focus_targets,
          focus_labels, next_focuses,
        )
      }
      match else_body {
        Some(body) =>
          for child in body.instrs {
            cf_walk_branch_targets_with_focus(
              child, branch_uids, next_uid, all_targets, focus_items, focus_targets,
              focus_labels, next_focuses,
            )
          }
        None => ()
      }
    }
    TInstrKind::TTryTable(bt, catches, body) => {
      ignore(bt)
      ignore(catches)
      let uid = cf_next_label_uid(next_uid)
      for focus_idx in next_focuses {
        focus_labels[focus_idx].add(uid)
      }
      let body_uids = cf_push_label_uid(label_uids, uid)
      for child in body.instrs {
        cf_walk_branch_targets_with_focus(
          child, body_uids, next_uid, all_targets, focus_items, focus_targets, focus_labels,
          next_focuses,
        )
      }
    }
    _ =>
      for child in eval_children(instr) {
        cf_walk_branch_targets_with_focus(
          child, label_uids, next_uid, all_targets, focus_items, focus_targets, focus_labels,
          next_focuses,
        )
      }
  }
}

///|
fn cf_collect_move_target_uids(
  items : Array[TInstr],
  container : TInstr,
  trace_stats : CodeFoldingRoundTraceStats,
) -> (Set[Int], Array[Set[Int]], Array[Set[Int]]) {
  let trace_enabled = cf_trace_stats_enabled(trace_stats)
  let start_us = if trace_enabled { cf_trace_now_us() } else { 0UL }
  if trace_enabled {
    trace_stats.can_move_calls += 1
  }
  let all_targets = Set::new()
  let focus_targets : Array[Set[Int]] = []
  let focus_labels : Array[Set[Int]] = []
  for _ in items {
    focus_targets.push(Set::new())
    focus_labels.push(Set::new())
  }
  let next_uid = Ref::new(1)
  cf_walk_branch_targets_with_focus(
    container,
    [],
    next_uid,
    all_targets,
    items,
    focus_targets,
    focus_labels,
    [],
  )
  if trace_enabled {
    trace_stats.can_move_us = trace_stats.can_move_us +
      cf_trace_elapsed_us_since(start_us)
  }
  (all_targets, focus_targets, focus_labels)
}

///|
fn cf_instr_has_try_table(instr : TInstr) -> Bool {
  let mut found = false
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      curr : TInstr,
    ) {
      if found {
        return unchanged()
      }
      match curr.kind {
        TInstrKind::TTryTable(_, _, _) => {
          found = true
          unchanged()
        }
        _ => from_walk(self.walk_tinstruction_default((), curr))
      }
    },
  )
  ignore(walker.walk_tinstruction((), instr))
  found
}

///|
fn cf_instr_may_throw(instr : TInstr) -> Bool {
  let mut may_throw = false
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      curr : TInstr,
    ) {
      if may_throw {
        return unchanged()
      }
      match curr.kind {
        TInstrKind::TThrow(_, _)
        | TInstrKind::TThrowRef(_)
        | TInstrKind::TCall(_, _)
        | TInstrKind::TCallIndirect(_, _, _, _)
        | TInstrKind::TCallRef(_, _, _)
        | TInstrKind::TReturnCall(_, _)
        | TInstrKind::TReturnCallIndirect(_, _, _, _)
        | TInstrKind::TReturnCallRef(_, _, _) => {
          may_throw = true
          unchanged()
        }
        _ => from_walk(self.walk_tinstruction_default((), curr))
      }
    },
  )
  ignore(walker.walk_tinstruction((), instr))
  may_throw
}

///|
fn cf_items_may_throw(items : Array[TInstr]) -> Bool {
  for item in items {
    if cf_instr_may_throw(item) {
      return true
    }
  }
  false
}

///|
fn can_move_with_trace(
  items : Array[TInstr],
  container : TInstr,
  trace_stats : CodeFoldingRoundTraceStats,
  allow_throw_across_try_table? : Bool = false,
) -> Bool {
  let (all_targets, focus_targets, focus_labels) = cf_collect_move_target_uids(
    items, container, trace_stats,
  )
  let has_try_table = cf_instr_has_try_table(container)
  let mut i = 0
  while i < items.length() {
    for target_uid in focus_targets[i] {
      if all_targets.contains(target_uid) &&
        !focus_labels[i].contains(target_uid) {
        return false
      }
    }
    if has_try_table &&
      !allow_throw_across_try_table &&
      cf_instr_may_throw(items[i]) {
      return false
    }
    i += 1
  }
  true
}

///|
fn can_move(items : Array[TInstr], container : TInstr) -> Bool {
  can_move_with_trace(items, container, cf_round_trace_stats_new())
}

///|
fn cf_break_tail_trace_stats(
  state : CodeFoldingState,
) -> CodeFoldingBreakTailTraceStats {
  let mut label_count = 0
  let mut tail_count = 0
  let mut max_label_tails = 0
  for label in state.break_tails.keys() {
    label_count += 1
    let len = state.break_tails.get(label).unwrap_or([]).length()
    tail_count += len
    if len > max_label_tails {
      max_label_tails = len
    }
  }
  { label_count, tail_count, max_label_tails }
}

///|
fn cf_trace_expr_progress(
  trace_ctx : CodeFoldingExprTraceCtx,
  tails : Array[Tail],
  checked_depth : Int,
  mergeable_count : Int,
  saved : Int,
  elapsed_us : UInt64,
  match_us : UInt64,
  can_move_us : UInt64,
  measure_us : UInt64,
) -> Unit {
  if !trace_ctx.enabled {
    return
  }
  (trace_ctx.trace)(
    "func[\{trace_ctx.func_ordinal}] round[\{trace_ctx.round}] expr_progress site=\{trace_ctx.site_kind} tails=\{tails.length()} checked_depth=\{checked_depth} merged=\{mergeable_count} saved=\{saved} elapsed_ms=\{cf_trace_delta_us_to_ms(elapsed_us)} elapsed_us=\{elapsed_us} match_ms=\{cf_trace_delta_us_to_ms(match_us)} can_move_ms=\{cf_trace_delta_us_to_ms(can_move_us)} measure_ms=\{cf_trace_delta_us_to_ms(measure_us)}",
  )
}

///|
fn cf_typecheck_texpr_stack(
  expr : TExpr,
  env : Env,
  stack : Array[ValType],
) -> Array[ValType]? {
  match Typecheck::typecheck(expr, make_state(env, stack)) {
    Ok(st) => Some(st.stack)
    Err(_) => None
  }
}

///|
fn cf_typecheck_tinstr_stack(
  instr : TInstr,
  env : Env,
  stack : Array[ValType],
) -> Array[ValType]? {
  match Typecheck::typecheck(instr, make_state(env, stack)) {
    Ok(st) => Some(st.stack)
    Err(_) => None
  }
}

///|
fn cf_empty_param_block_results(bt : BlockType, env : Env) -> Array[ValType]? {
  match env.expand_blocktype(bt) {
    Ok((params, results)) =>
      if params.is_empty() {
        Some(results)
      } else {
        None
      }
    Err(_) => None
  }
}

///|
fn cf_take_instr_prefix(
  instrs : Array[TInstr],
  keep_len : Int,
) -> Array[TInstr] {
  let out : Array[TInstr] = []
  let mut i = 0
  while i < keep_len {
    out.push(instrs[i])
    i += 1
  }
  out
}

///|
fn cf_concat_instrs(lhs : Array[TInstr], rhs : Array[TInstr]) -> Array[TInstr] {
  let out : Array[TInstr] = []
  for instr in lhs {
    out.push(instr)
  }
  for instr in rhs {
    out.push(instr)
  }
  out
}

///|
fn cf_path_append(
  path : Array[BlockTailPathStep],
  step : BlockTailPathStep,
) -> Array[BlockTailPathStep] {
  let out = path.copy()
  out.push(step)
  out
}

///|
fn cf_path_eq(
  lhs : Array[BlockTailPathStep],
  rhs : Array[BlockTailPathStep],
) -> Bool {
  if lhs.length() != rhs.length() {
    return false
  }
  let mut i = 0
  while i < lhs.length() {
    if lhs[i] != rhs[i] {
      return false
    }
    i += 1
  }
  true
}

///|
fn cf_find_scoped_suffix_tail(
  tails : Array[ScopedTail],
  path : Array[BlockTailPathStep],
) -> ScopedTail? {
  for tail in tails {
    if tail.exact_index is None && cf_path_eq(tail.path, path) {
      return Some(tail)
    }
  }
  None
}

///|
fn cf_find_exact_scoped_tail(
  tails : Array[ScopedTail],
  path : Array[BlockTailPathStep],
  index : Int,
) -> ScopedTail? {
  for tail in tails {
    if cf_path_eq(tail.path, path) {
      match tail.exact_index {
        Some(curr_index) if curr_index == index => return Some(tail)
        _ => ()
      }
    }
  }
  None
}

///|
/// When a folded tail carries a branch result, stash it in a temp local so
/// the merged suffix can re-materialize the value after the join.
fn cf_rewrite_branch_tail_instrs(
  instrs : Array[TInstr],
  branch : TInstr,
  merge_count : Int,
  temp_local? : CodeFoldingTempLocal? = None,
) -> Array[TInstr]? {
  match branch.kind {
    TInstrKind::TBr(label, values) => {
      if instrs.is_empty() {
        return None
      }
      let mut remaining = merge_count
      let mut temp_set_instr : TInstr? = None
      let new_values = if !values.is_empty() {
        if remaining == 0 {
          values
        } else {
          remaining -= 1
          match temp_local {
            Some({ local_idx, value_instr }) => {
              temp_set_instr = Some(TInstr::local_set(local_idx, value_instr))
              []
            }
            None => []
          }
        }
      } else {
        []
      }
      let keep_len = instrs.length() - 1 - remaining
      if keep_len < 0 {
        return None
      }
      let out : Array[TInstr] = []
      for instr in cf_take_instr_prefix(instrs, keep_len) {
        out.push(instr)
      }
      match temp_set_instr {
        Some(set_instr) => out.push(set_instr)
        None => ()
      }
      out.push(TInstr::br(label, new_values))
      Some(out)
    }
    _ => None
  }
}

///|
fn cf_block_tail_values_supported(
  tails : Array[ScopedTail],
  result_count : Int,
) -> Bool {
  for scoped_tail in tails {
    match scoped_tail.tail.instr {
      Some({ kind: TInstrKind::TBr(_, values), .. }) =>
        if values.length() > 1 || (values.length() == 1 && result_count != 1) {
          return false
        }
      _ => ()
    }
  }
  true
}

///|
fn cf_rewrite_block_fold_instr(
  instr : TInstr,
  path : Array[BlockTailPathStep],
  index : Int,
  tails : Array[ScopedTail],
  merge_count : Int,
  temp_local? : CodeFoldingTempLocal? = None,
) -> TInstr {
  match instr.kind {
    TInstrKind::TBlock(bt, body) =>
      TInstr::block(
        bt,
        TExpr::new(
          cf_rewrite_block_fold_instrs(
            body.instrs,
            cf_path_append(path, BlockBody(index)),
            tails,
            merge_count,
            temp_local~,
          ),
        ),
      )
    TInstrKind::TLoop(bt, body) =>
      TInstr::loop_(
        bt,
        TExpr::new(
          cf_rewrite_block_fold_instrs(
            body.instrs,
            cf_path_append(path, LoopBody(index)),
            tails,
            merge_count,
            temp_local~,
          ),
        ),
      )
    TInstrKind::TIf(bt, cond, then_body, else_body) =>
      TInstr::if_(
        bt,
        cond,
        TExpr::new(
          cf_rewrite_block_fold_instrs(
            then_body.instrs,
            cf_path_append(path, IfThen(index)),
            tails,
            merge_count,
            temp_local~,
          ),
        ),
        match else_body {
          Some(body) =>
            Some(
              TExpr::new(
                cf_rewrite_block_fold_instrs(
                  body.instrs,
                  cf_path_append(path, IfElse(index)),
                  tails,
                  merge_count,
                  temp_local~,
                ),
              ),
            )
          None => None
        },
      )
    TInstrKind::TTryTable(bt, catches, body) =>
      TInstr::try_table(
        bt,
        catches,
        TExpr::new(
          cf_rewrite_block_fold_instrs(
            body.instrs,
            cf_path_append(path, TryBody(index)),
            tails,
            merge_count,
            temp_local~,
          ),
        ),
      )
    _ => instr
  }
}

///|
fn cf_rewrite_block_fold_instrs(
  instrs : Array[TInstr],
  path : Array[BlockTailPathStep],
  tails : Array[ScopedTail],
  merge_count : Int,
  temp_local? : CodeFoldingTempLocal? = None,
) -> Array[TInstr] {
  let exact_tail = cf_find_scoped_suffix_tail(tails, path)
  let mut iter_instrs = instrs
  let mut iter_len = instrs.length()
  let mut rewritten_branch : TInstr? = None
  let mut fallthrough_temp_instr : TInstr? = None
  match exact_tail {
    Some({ tail: { instr: None, .. }, .. }) => {
      iter_len -= merge_count
      match temp_local {
        Some({ local_idx, value_instr }) =>
          fallthrough_temp_instr = Some(
            TInstr::local_set(local_idx, value_instr),
          )
        None => ()
      }
    }
    Some({ tail: { instr: Some(branch), .. }, .. }) =>
      match
        cf_rewrite_branch_tail_instrs(instrs, branch, merge_count, temp_local~) {
        Some(rewritten) =>
          if rewritten.is_empty() {
            iter_instrs = rewritten
            iter_len = 0
          } else {
            iter_instrs = rewritten
            iter_len = rewritten.length() - 1
            rewritten_branch = Some(rewritten[rewritten.length() - 1])
          }
        None => ()
      }
    None => ()
  }
  let out : Array[TInstr] = []
  let mut i = 0
  while i < iter_len {
    out.push(
      cf_rewrite_block_fold_instr(
        iter_instrs[i],
        path,
        i,
        tails,
        merge_count,
        temp_local~,
      ),
    )
    i += 1
  }
  match fallthrough_temp_instr {
    Some(instr) => out.push(instr)
    None => ()
  }
  match rewritten_branch {
    Some(branch) => out.push(branch)
    None => ()
  }
  out
}

///|
fn cf_rewrite_terminating_tail_instr(
  instr : TInstr,
  path : Array[BlockTailPathStep],
  index : Int,
  tails : Array[ScopedTail],
  merge_count : Int,
  temp_locals : Array[LocalIdx],
) -> TInstr? {
  match instr.kind {
    TInstrKind::TBlock(bt, body) =>
      match
        cf_rewrite_terminating_tail_instrs(
          body.instrs,
          cf_path_append(path, BlockBody(index)),
          tails,
          merge_count,
          temp_locals,
        ) {
        Some(rewritten) => Some(TInstr::block(bt, TExpr::new(rewritten)))
        None => None
      }
    TInstrKind::TLoop(bt, body) =>
      match
        cf_rewrite_terminating_tail_instrs(
          body.instrs,
          cf_path_append(path, LoopBody(index)),
          tails,
          merge_count,
          temp_locals,
        ) {
        Some(rewritten) => Some(TInstr::loop_(bt, TExpr::new(rewritten)))
        None => None
      }
    TInstrKind::TIf(bt, cond, then_body, else_body) =>
      match
        cf_rewrite_terminating_tail_instrs(
          then_body.instrs,
          cf_path_append(path, IfThen(index)),
          tails,
          merge_count,
          temp_locals,
        ) {
        Some(rewritten_then) => {
          let rewritten_else = match else_body {
            Some(body) =>
              match
                cf_rewrite_terminating_tail_instrs(
                  body.instrs,
                  cf_path_append(path, IfElse(index)),
                  tails,
                  merge_count,
                  temp_locals,
                ) {
                Some(rewritten_else) => Some(TExpr::new(rewritten_else))
                None => return None
              }
            None => None
          }
          Some(
            TInstr::if_(bt, cond, TExpr::new(rewritten_then), rewritten_else),
          )
        }
        None => None
      }
    TInstrKind::TTryTable(bt, catches, body) =>
      match
        cf_rewrite_terminating_tail_instrs(
          body.instrs,
          cf_path_append(path, TryBody(index)),
          tails,
          merge_count,
          temp_locals,
        ) {
        Some(rewritten) =>
          Some(TInstr::try_table(bt, catches, TExpr::new(rewritten)))
        None => None
      }
    _ => Some(instr)
  }
}

///|
fn cf_rewrite_exact_terminating_tail(
  tail : ScopedTail,
  depth : Int,
  temp_locals : Array[LocalIdx],
) -> Array[TInstr]? {
  match tail.tail.instr {
    Some({ kind: TInstrKind::TReturn(values), .. }) => {
      if values.length() != temp_locals.length() && !temp_locals.is_empty() {
        return None
      }
      let out : Array[TInstr] = []
      let mut j = 0
      while j < temp_locals.length() {
        out.push(TInstr::local_set(temp_locals[j], values[j]))
        j += 1
      }
      out.push(TInstr::br(LabelIdx::new(depth.reinterpret_as_uint()), []))
      Some(out)
    }
    Some({ kind: TInstrKind::TThrow(_, values), .. }) => {
      if values.length() != temp_locals.length() && !temp_locals.is_empty() {
        return None
      }
      let out : Array[TInstr] = []
      let mut j = 0
      while j < temp_locals.length() {
        out.push(TInstr::local_set(temp_locals[j], values[j]))
        j += 1
      }
      out.push(TInstr::br(LabelIdx::new(depth.reinterpret_as_uint()), []))
      Some(out)
    }
    Some({ kind: TInstrKind::TThrowRef(value), .. }) => {
      if temp_locals.length() > 1 {
        return None
      }
      let out : Array[TInstr] = []
      if temp_locals.length() == 1 {
        out.push(TInstr::local_set(temp_locals[0], value))
      }
      out.push(TInstr::br(LabelIdx::new(depth.reinterpret_as_uint()), []))
      Some(out)
    }
    Some(_) => {
      if !temp_locals.is_empty() {
        return None
      }
      Some([TInstr::br(LabelIdx::new(depth.reinterpret_as_uint()), [])])
    }
    None => None
  }
}

///|
fn cf_preview_temp_locals(
  state : CodeFoldingState,
  tys : Array[ValType],
) -> Array[LocalIdx] {
  let out : Array[LocalIdx] = []
  let base = state.func_locals.length()
  let mut i = 0
  while i < tys.length() {
    out.push(LocalIdx::new((base + i).reinterpret_as_uint()))
    i += 1
  }
  out
}

///|
fn cf_shared_terminator_measure(
  terminator : TInstr,
  trace_stats : CodeFoldingRoundTraceStats,
) -> Int {
  let base = measure_with_trace(terminator, trace_stats)
  match terminator.kind {
    TInstrKind::TReturn(_) | TInstrKind::TUnreachable => base + 1
    _ => base
  }
}

///|
fn cf_original_terminator_measure(
  tail : ScopedTail,
  trace_stats : CodeFoldingRoundTraceStats,
) -> Int {
  match tail.tail.instr {
    Some(instr) => measure_with_trace(instr, trace_stats)
    None => 0
  }
}

///|
fn cf_pre_terminator_mergeable(tail : Tail, num : Int) -> TInstr? {
  if tail.is_exact_only() {
    return None
  }
  if tail.block_instrs.length() <= num + 1 {
    return None
  }
  Some(tail.block_instrs[tail.block_instrs.length() - num - 2])
}

///|
fn cf_terminators_compatible(tails : Array[ScopedTail]) -> Bool {
  let first = match tails[0].tail.instr {
    Some(instr) => instr
    None => return false
  }
  for scoped_tail in tails {
    let terminator = match scoped_tail.tail.instr {
      Some(instr) => instr
      None => return false
    }
    match first.kind {
      TInstrKind::TReturn(_) =>
        if !(terminator.kind is TInstrKind::TReturn(_)) {
          return false
        }
      TInstrKind::TThrow(first_tag, _) =>
        match terminator.kind {
          TInstrKind::TThrow(tag, _) if tag == first_tag => ()
          _ => return false
        }
      TInstrKind::TThrowRef(_) =>
        if !(terminator.kind is TInstrKind::TThrowRef(_)) {
          return false
        }
      TInstrKind::TUnreachable =>
        if !(terminator.kind is TInstrKind::TUnreachable) {
          return false
        }
      _ => if terminator != first { return false }
    }
  }
  true
}

///|
fn cf_return_tails_can_spill(
  tails : Array[ScopedTail],
  results : Array[ValType],
) -> Bool {
  for scoped_tail in tails {
    match scoped_tail.tail.instr {
      Some({ kind: TInstrKind::TReturn(values), .. }) =>
        if values.length() != results.length() {
          return false
        }
      _ => return false
    }
  }
  true
}

///|
fn cf_throw_tails_can_spill(
  tails : Array[ScopedTail],
  tag : TagIdx,
  payload_tys : Array[ValType],
) -> Bool {
  for scoped_tail in tails {
    match scoped_tail.tail.instr {
      Some({ kind: TInstrKind::TThrow(curr_tag, values), .. }) =>
        if curr_tag != tag || values.length() != payload_tys.length() {
          return false
        }
      _ => return false
    }
  }
  true
}

///|
fn cf_throw_ref_tails_can_spill(tails : Array[ScopedTail]) -> Bool {
  for scoped_tail in tails {
    match scoped_tail.tail.instr {
      Some({ kind: TInstrKind::TThrowRef(_), .. }) => ()
      _ => return false
    }
  }
  true
}

///|
fn cf_infer_value_type(env : Env, value : TInstr) -> ValType? {
  match cf_typecheck_tinstr_stack(value, env, []) {
    Some(stack) => if stack.length() == 1 { Some(stack[0]) } else { None }
    None => None
  }
}

///|
fn cf_infer_throw_payload_types(
  env : Env,
  values : Array[TInstr],
) -> Array[ValType]? {
  let payload_tys : Array[ValType] = []
  for value in values {
    match cf_infer_value_type(env, value) {
      Some(ty) => payload_tys.push(ty)
      None => return None
    }
  }
  Some(payload_tys)
}

///|
priv struct CfTerminatingTailPlan {
  merge_count : Int
  shared_tail_instrs : Array[TInstr]
  temp_locals : Array[LocalIdx]
  temp_local_types : Array[ValType]
}

///|
priv enum CfTerminatingTailGroupKey {
  Return_
  Unreachable_
  Throw_(TagIdx, Int)
  ThrowRef_
  Exact(TInstr)
} derive(Eq, Hash)

///|
fn cf_terminating_tail_group_key(instr : TInstr) -> CfTerminatingTailGroupKey {
  match instr.kind {
    TInstrKind::TReturn(_) => CfTerminatingTailGroupKey::Return_
    TInstrKind::TUnreachable => CfTerminatingTailGroupKey::Unreachable_
    TInstrKind::TThrow(tag, values) =>
      CfTerminatingTailGroupKey::Throw_(tag, values.length())
    TInstrKind::TThrowRef(_) => CfTerminatingTailGroupKey::ThrowRef_
    _ => CfTerminatingTailGroupKey::Exact(instr)
  }
}

///|
fn cf_terminating_tail_item(tail : ScopedTail, depth : Int) -> TInstr? {
  if depth == 0 {
    tail.tail.instr
  } else {
    cf_pre_terminator_mergeable(tail.tail, depth - 1)
  }
}

///|
fn cf_group_terminating_tails(
  tails : Array[ScopedTail],
  depth : Int,
  trace_stats : CodeFoldingRoundTraceStats,
) -> Array[Array[ScopedTail]] {
  let groups : Array[Array[ScopedTail]] = []
  if depth == 0 {
    let key_order : Array[CfTerminatingTailGroupKey] = []
    let keyed : Map[CfTerminatingTailGroupKey, Array[ScopedTail]] = Map::new()
    for tail in tails {
      trace_stats.terminating_group_pair_checks += 1
      match cf_terminating_tail_item(tail, depth) {
        Some(item) => {
          let key = cf_terminating_tail_group_key(item)
          match keyed.get(key) {
            Some(group) => {
              group.push(tail)
              keyed.set(key, group)
            }
            None => {
              key_order.push(key)
              keyed.set(key, [tail])
            }
          }
        }
        None => ()
      }
    }
    for key in key_order {
      let group = keyed.get(key).unwrap_or([])
      if group.length() >= 2 {
        groups.push(group)
      }
    }
    return groups
  }
  let item_order : Array[TInstr] = []
  let keyed : Map[TInstr, Array[ScopedTail]] = Map::new()
  for tail in tails {
    trace_stats.terminating_group_pair_checks += 1
    match cf_terminating_tail_item(tail, depth) {
      Some(item) =>
        match keyed.get(item) {
          Some(group) => {
            group.push(tail)
            keyed.set(item, group)
          }
          None => {
            item_order.push(item)
            keyed.set(item, [tail])
          }
        }
      None => ()
    }
  }
  for item in item_order {
    let group = keyed.get(item).unwrap_or([])
    if group.length() >= 2 {
      groups.push(group)
    }
  }
  groups
}

///|
fn cf_build_terminating_tail_plan(
  state : CodeFoldingState,
  tails : Array[ScopedTail],
  trace_stats : CodeFoldingRoundTraceStats,
) -> CfTerminatingTailPlan? {
  if !cf_terminators_compatible(tails) {
    return None
  }
  let first_terminator = match tails[0].tail.instr {
    Some(instr) => instr
    None => return None
  }

  let mergeable : Array[TInstr] = []
  let mut num = 0
  while true {
    match cf_pre_terminator_mergeable(tails[0].tail, num) {
      None => break
      Some(item) => {
        let mut all_match = true
        for i = 1; i < tails.length(); i = i + 1 {
          match cf_pre_terminator_mergeable(tails[i].tail, num) {
            Some(other) if other == item => ()
            _ => {
              all_match = false
              break
            }
          }
        }
        if !all_match {
          break
        }
        mergeable.push(item)
        num += 1
      }
    }
  }

  let merged_prefix : Array[TInstr] = []
  let mut j = mergeable.length() - 1
  while j >= 0 {
    merged_prefix.push(mergeable[j])
    j -= 1
  }

  let mut temp_locals : Array[LocalIdx] = []
  let mut temp_local_types : Array[ValType] = []
  let shared_terminator = match first_terminator.kind {
    TInstrKind::TReturn(_) => {
      let mut all_equal = true
      for scoped_tail in tails {
        match scoped_tail.tail.instr {
          Some(instr) if instr == first_terminator => ()
          _ => {
            all_equal = false
            break
          }
        }
      }
      if all_equal {
        first_terminator
      } else {
        let results = match state.env.return_type {
          Some(results) => results
          None => return None
        }
        if !cf_return_tails_can_spill(tails, results) {
          return None
        }
        temp_local_types = results.copy()
        temp_locals = cf_preview_temp_locals(state, results)
        let temp_values : Array[TInstr] = []
        for local_idx in temp_locals {
          temp_values.push(TInstr::local_get(local_idx))
        }
        TInstr::return_(temp_values)
      }
    }
    TInstrKind::TThrow(tag, first_values) => {
      let mut all_equal = true
      for scoped_tail in tails {
        match scoped_tail.tail.instr {
          Some(instr) if instr == first_terminator => ()
          _ => {
            all_equal = false
            break
          }
        }
      }
      if all_equal {
        first_terminator
      } else {
        let payload_tys = match state.env.resolve_tag_functype(tag) {
          Some(FuncType(params, _)) => params
          _ =>
            match cf_infer_throw_payload_types(state.env, first_values) {
              Some(inferred) => inferred
              None => return None
            }
        }
        if !cf_throw_tails_can_spill(tails, tag, payload_tys) {
          return None
        }
        temp_local_types = payload_tys.copy()
        temp_locals = cf_preview_temp_locals(state, payload_tys)
        let temp_values : Array[TInstr] = []
        for local_idx in temp_locals {
          temp_values.push(TInstr::local_get(local_idx))
        }
        TInstr::throw_(tag, temp_values)
      }
    }
    TInstrKind::TThrowRef(_) => {
      let mut all_equal = true
      for scoped_tail in tails {
        match scoped_tail.tail.instr {
          Some(instr) if instr == first_terminator => ()
          _ => {
            all_equal = false
            break
          }
        }
      }
      if all_equal {
        first_terminator
      } else {
        if !cf_throw_ref_tails_can_spill(tails) {
          return None
        }
        temp_local_types = [ValType::ref_null_exn()]
        temp_locals = cf_preview_temp_locals(state, temp_local_types)
        TInstr::throw_ref(TInstr::local_get(temp_locals[0]))
      }
    }
    _ => first_terminator
  }
  let shared_tail_instrs = cf_concat_instrs(merged_prefix, [shared_terminator])
  let mut saved = 0
  for instr in merged_prefix {
    saved += measure_with_trace(instr, trace_stats) * (tails.length() - 1)
  }
  let mut min_terminator_measure = -1
  for tail in tails {
    let curr_measure = cf_original_terminator_measure(tail, trace_stats)
    if min_terminator_measure < 0 || curr_measure < min_terminator_measure {
      min_terminator_measure = curr_measure
    }
  }
  let terminator_measure = if min_terminator_measure >= 0 {
    min_terminator_measure
  } else {
    cf_shared_terminator_measure(shared_terminator, trace_stats)
  }
  saved += terminator_measure * (tails.length() - 1)
  let cost = tails.length() + WORTH_ADDING_BLOCK_TO_REMOVE_THIS_MUCH
  if saved < cost || saved < MIN_TERMINATING_TAIL_SAVINGS {
    return None
  }
  Some({
    merge_count: mergeable.length(),
    shared_tail_instrs,
    temp_locals,
    temp_local_types,
  })
}

///|
fn cf_rewrite_terminating_tail_instrs(
  instrs : Array[TInstr],
  path : Array[BlockTailPathStep],
  tails : Array[ScopedTail],
  merge_count : Int,
  temp_locals : Array[LocalIdx],
) -> Array[TInstr]? {
  let suffix_tail = cf_find_scoped_suffix_tail(tails, path)
  let out : Array[TInstr] = []
  let keep_len = match suffix_tail {
    Some(_) => {
      let len = instrs.length() - merge_count - 1
      if len < 0 {
        return None
      }
      len
    }
    None => instrs.length()
  }
  let mut i = 0
  while i < keep_len {
    match cf_find_exact_scoped_tail(tails, path, i) {
      Some(exact_tail) =>
        match
          cf_rewrite_exact_terminating_tail(
            exact_tail,
            path.length(),
            temp_locals,
          ) {
          Some(rewritten) =>
            for instr in rewritten {
              out.push(instr)
            }
          None => return None
        }
      None =>
        match
          cf_rewrite_terminating_tail_instr(
            instrs[i],
            path,
            i,
            tails,
            merge_count,
            temp_locals,
          ) {
          Some(rewritten) => out.push(rewritten)
          None => return None
        }
    }
    i += 1
  }
  match suffix_tail {
    Some(tail) =>
      match
        cf_rewrite_exact_terminating_tail(tail, path.length(), temp_locals) {
        Some(rewritten) => {
          for instr in rewritten {
            out.push(instr)
          }
          Some(out)
        }
        None => None
      }
    None => Some(out)
  }
}

///|
fn cf_collect_scoped_block_tails(
  instrs : Array[TInstr],
  path : Array[BlockTailPathStep],
  target_depth : Int,
  tails : Array[ScopedTail],
  blocked : Ref[Bool],
) -> Unit {
  for i = 0; i < instrs.length(); i = i + 1 {
    let instr = instrs[i]
    match instr.kind {
      TInstrKind::TBr(label, _) if i == instrs.length() - 1 => {
        let LabelIdx(label_depth) = label
        if label_depth.reinterpret_as_int() == target_depth {
          tails.push({
            tail: Tail::branch(instr, instrs),
            path,
            exact_index: None,
          })
        }
      }
      TInstrKind::TBrIf(label, _, _) => {
        let LabelIdx(label_depth) = label
        if label_depth.reinterpret_as_int() == target_depth {
          blocked.val = true
        }
      }
      TInstrKind::TBrTable(labels, default, _, _) => {
        for label in labels {
          let LabelIdx(label_depth) = label
          if label_depth.reinterpret_as_int() == target_depth {
            blocked.val = true
          }
        }
        let LabelIdx(default_depth) = default
        if default_depth.reinterpret_as_int() == target_depth {
          blocked.val = true
        }
      }
      TInstrKind::TBrOnNull(label, _, _) => {
        let LabelIdx(label_depth) = label
        if label_depth.reinterpret_as_int() == target_depth {
          blocked.val = true
        }
      }
      TInstrKind::TBrOnNonNull(label, _, _) => {
        let LabelIdx(label_depth) = label
        if label_depth.reinterpret_as_int() == target_depth {
          blocked.val = true
        }
      }
      TInstrKind::TBrOnCast(label, _, _, _, _, _) => {
        let LabelIdx(label_depth) = label
        if label_depth.reinterpret_as_int() == target_depth {
          blocked.val = true
        }
      }
      TInstrKind::TBrOnCastFail(label, _, _, _, _, _) => {
        let LabelIdx(label_depth) = label
        if label_depth.reinterpret_as_int() == target_depth {
          blocked.val = true
        }
      }
      TInstrKind::TBlock(_, body) =>
        cf_collect_scoped_block_tails(
          body.instrs,
          cf_path_append(path, BlockBody(i)),
          target_depth + 1,
          tails,
          blocked,
        )
      TInstrKind::TLoop(_, body) =>
        cf_collect_scoped_block_tails(
          body.instrs,
          cf_path_append(path, LoopBody(i)),
          target_depth + 1,
          tails,
          blocked,
        )
      TInstrKind::TIf(_, _, then_body, else_body) => {
        cf_collect_scoped_block_tails(
          then_body.instrs,
          cf_path_append(path, IfThen(i)),
          target_depth + 1,
          tails,
          blocked,
        )
        match else_body {
          Some(body) =>
            cf_collect_scoped_block_tails(
              body.instrs,
              cf_path_append(path, IfElse(i)),
              target_depth + 1,
              tails,
              blocked,
            )
          None => ()
        }
      }
      TInstrKind::TTryTable(_, _, body) =>
        cf_collect_scoped_block_tails(
          body.instrs,
          cf_path_append(path, TryBody(i)),
          target_depth + 1,
          tails,
          blocked,
        )
      _ => ()
    }
  }
}

///|
fn cf_collect_local_block_tails(
  instrs : Array[TInstr],
) -> (Array[ScopedTail], Bool) {
  let tails : Array[ScopedTail] = []
  let blocked : Ref[Bool] = { val: false }
  cf_collect_scoped_block_tails(instrs, [], 0, tails, blocked)
  (tails, blocked.val)
}

///|
priv struct CfLabelShiftCtx {
  control_depth : Int
  in_cond : Bool
}

///|
fn cf_shift_outer_label(label : LabelIdx, control_depth : Int) -> LabelIdx {
  let LabelIdx(label_depth) = label
  if label_depth.reinterpret_as_int() <= control_depth {
    label
  } else {
    LabelIdx::new(label_depth + 1U)
  }
}

///|
fn cf_shift_cond_outer_label(label : LabelIdx, control_depth : Int) -> LabelIdx {
  let LabelIdx(label_depth) = label
  if label_depth.reinterpret_as_int() < control_depth {
    label
  } else {
    LabelIdx::new(label_depth + 1U)
  }
}

///|
/// Rebase labels when a folded block body is wrapped in an additional block.
fn cf_shift_outer_labels_with(
  instr : TInstr,
  shift_label : (LabelIdx, Int) -> LabelIdx,
  shift_cond_label : (LabelIdx, Int) -> LabelIdx,
  root_in_cond? : Bool = false,
) -> TInstr {
  let walker : ModuleTransformer[CfLabelShiftCtx, Unit] = ModuleTransformer::new()
    .on_labelidx_evt(fn(_, ctx : CfLabelShiftCtx, label : LabelIdx) {
      let shifted = if ctx.in_cond {
        shift_cond_label(label, ctx.control_depth)
      } else {
        shift_label(label, ctx.control_depth)
      }
      if shifted == label {
        unchanged()
      } else {
        change(ctx, shifted)
      }
    })
    .on_tinstruction_evt(fn(self, ctx : CfLabelShiftCtx, instr : TInstr) {
      match instr.kind {
        TInstrKind::TBlock(bt, body) => {
          let body_ctx = { ..ctx, control_depth: ctx.control_depth + 1 }
          let body = match self.walk_texpr(body_ctx, body) {
            Ok((body, _)) => body
            Err(_) => return unchanged()
          }
          change(ctx, TInstr::block(bt, body))
        }
        TInstrKind::TLoop(bt, body) => {
          let body_ctx = { ..ctx, control_depth: ctx.control_depth + 1 }
          let body = match self.walk_texpr(body_ctx, body) {
            Ok((body, _)) => body
            Err(_) => return unchanged()
          }
          change(ctx, TInstr::loop_(bt, body))
        }
        TInstrKind::TIf(bt, cond, then_body, else_body) => {
          let cond = match
            self.walk_tinstruction(
              CfLabelShiftCtx::{ ..ctx, in_cond: true },
              cond,
            ) {
            Ok((cond, _)) => cond
            Err(_) => return unchanged()
          }
          let branch_ctx = CfLabelShiftCtx::{
            control_depth: ctx.control_depth + 1,
            in_cond: ctx.in_cond,
          }
          let then_body = match self.walk_texpr(branch_ctx, then_body) {
            Ok((then_body, _)) => then_body
            Err(_) => return unchanged()
          }
          let else_body = match else_body {
            Some(else_body) =>
              match self.walk_texpr(branch_ctx, else_body) {
                Ok((else_body, _)) => Some(else_body)
                Err(_) => return unchanged()
              }
            None => None
          }
          change(ctx, TInstr::if_(bt, cond, then_body, else_body))
        }
        TInstrKind::TTryTable(bt, catches, body) => {
          let catches = match
            self.walk_array(ctx, ModuleTransformer::walk_catch, catches) {
            Ok((catches, _)) => catches
            Err(_) => return unchanged()
          }
          let body_ctx = { ..ctx, control_depth: ctx.control_depth + 1 }
          let body = match self.walk_texpr(body_ctx, body) {
            Ok((body, _)) => body
            Err(_) => return unchanged()
          }
          change(ctx, TInstr::try_table(bt, catches, body))
        }
        _ => from_walk(self.walk_tinstruction_default(ctx, instr))
      }
    })
  match
    walker.walk_tinstruction(
      CfLabelShiftCtx::{ control_depth: 0, in_cond: root_in_cond },
      instr,
    ) {
    Ok((rewritten, _)) => rewritten
    Err(_) => instr
  }
}

///|
fn cf_shift_outer_labels(instr : TInstr) -> TInstr {
  cf_shift_outer_labels_with(
    instr, cf_shift_outer_label, cf_shift_cond_outer_label,
  )
}

///|
fn cf_shift_cond_outer_labels(instr : TInstr) -> TInstr {
  cf_shift_outer_labels_with(
    instr,
    cf_shift_outer_label,
    cf_shift_cond_outer_label,
    root_in_cond=true,
  )
}

///|
fn cf_shift_outer_labels_instrs(instrs : Array[TInstr]) -> Array[TInstr] {
  let shifted : Array[TInstr] = []
  for instr in instrs {
    shifted.push(cf_shift_outer_labels(instr))
  }
  shifted
}

///|
/// Get the mergeable item from a tail at a given depth
fn get_mergeable(tail : Tail, num : Int) -> TInstr? {
  if not(tail.is_fallthrough()) {
    // If there is a branch value, it is the first mergeable item
    match tail.instr {
      Some({ kind: TInstrKind::TBr(_, values), .. }) =>
        if values.length() > 0 && num == 0 {
          return Some(values[0])
        } else if values.is_empty() {
          // Skip the branch instruction at the end; it is not part of the merged tail
          let adjusted_num = num + 1
          if adjusted_num >= tail.block_instrs.length() {
            return None
          }
          return Some(
            tail.block_instrs[tail.block_instrs.length() - adjusted_num - 1],
          )
        }
      _ => ()
    }
  }
  if num >= tail.block_instrs.length() {
    return None
  }
  Some(tail.block_instrs[tail.block_instrs.length() - num - 1])
}

///|

///|
/// Find a common self-contained expression suffix to move after the current
/// expression. The actual rebuild happens in the caller so we can preserve
/// stack types.
fn find_expression_fold_plan(
  state : CodeFoldingState,
  tails : Array[Tail],
  curr : TInstr,
  trace_stats : CodeFoldingRoundTraceStats,
  trace_ctx : CodeFoldingExprTraceCtx,
  allow_branch_tails? : Bool = false,
  parent_can_absorb_wrapper? : Bool = false,
) -> ExprFoldPlan? {
  if !CF_ENABLE_EXPRESSION_FOLDING {
    return None
  }
  let trace_enabled = cf_trace_stats_enabled(trace_stats)
  let start_us = if trace_enabled { cf_trace_now_us() } else { 0UL }
  trace_stats.expr_calls += 1
  trace_stats.expr_tail_count += tails.length()
  if tails.length() < 2 {
    if trace_enabled {
      trace_stats.expr_us = trace_stats.expr_us +
        cf_trace_elapsed_us_since(start_us)
    }
    return None
  }

  // Check if anything is untoward
  for tail in tails {
    match tail.instr {
      Some(i) if state.modifieds.contains(i) => {
        if trace_enabled {
          trace_stats.expr_us = trace_stats.expr_us +
            cf_trace_elapsed_us_since(start_us)
        }
        return None
      }
      Some(_) if !allow_branch_tails => {
        if trace_enabled {
          trace_stats.expr_us = trace_stats.expr_us +
            cf_trace_elapsed_us_since(start_us)
        }
        return None
      }
      _ => ()
    }
  }

  // Find mergeable items
  let mergeable : Array[TInstr] = []
  let mut saved = 0
  let mut num = 0
  let mut local_match_us = 0UL
  let mut local_can_move_us = 0UL
  let mut local_measure_us = 0UL
  let mut next_progress_us = CF_EXPR_PROGRESS_LOG_INTERVAL_US
  while true {
    match get_mergeable(tails[0], num) {
      None => break
      Some(item) => {
        // Check if all tails have matching items
        let match_start_us = if trace_enabled { cf_trace_now_us() } else { 0UL }
        let mut all_match = true
        for i = 1; i < tails.length(); i = i + 1 {
          match get_mergeable(tails[i], num) {
            None => {
              all_match = false
              break
            }
            Some(other) =>
              if item != other {
                all_match = false
                break
              }
          }
        }
        let match_elapsed_us = if trace_enabled {
          cf_trace_elapsed_us_since(match_start_us)
        } else {
          0UL
        }
        if trace_enabled {
          local_match_us = local_match_us + match_elapsed_us
          trace_stats.expr_match_us = trace_stats.expr_match_us +
            match_elapsed_us
        }
        if not(all_match) {
          let total_elapsed_us = if trace_enabled {
            cf_trace_elapsed_us_since(start_us)
          } else {
            0UL
          }
          if total_elapsed_us >= next_progress_us {
            cf_trace_expr_progress(
              trace_ctx,
              tails,
              num + 1,
              mergeable.length(),
              saved,
              total_elapsed_us,
              local_match_us,
              local_can_move_us,
              local_measure_us,
            )
            next_progress_us = total_elapsed_us +
              CF_EXPR_PROGRESS_LOG_INTERVAL_US
          }
          break
        }

        // Check if we can move it
        let can_move_start_us = if trace_enabled {
          cf_trace_now_us()
        } else {
          0UL
        }
        let can_move_result = can_move_with_trace([item], curr, trace_stats)
        let can_move_elapsed_us = if trace_enabled {
          cf_trace_elapsed_us_since(can_move_start_us)
        } else {
          0UL
        }
        if trace_enabled {
          local_can_move_us = local_can_move_us + can_move_elapsed_us
          trace_stats.expr_can_move_us = trace_stats.expr_can_move_us +
            can_move_elapsed_us
        }
        if not(can_move_result) {
          let total_elapsed_us = if trace_enabled {
            cf_trace_elapsed_us_since(start_us)
          } else {
            0UL
          }
          if total_elapsed_us >= next_progress_us {
            cf_trace_expr_progress(
              trace_ctx,
              tails,
              num + 1,
              mergeable.length(),
              saved,
              total_elapsed_us,
              local_match_us,
              local_can_move_us,
              local_measure_us,
            )
            next_progress_us = total_elapsed_us +
              CF_EXPR_PROGRESS_LOG_INTERVAL_US
          }
          break
        }

        // We found another one we can merge
        mergeable.push(item)
        let measure_start_us = if trace_enabled {
          cf_trace_now_us()
        } else {
          0UL
        }
        let item_measure = measure_with_trace(item, trace_stats)
        let measure_elapsed_us = if trace_enabled {
          cf_trace_elapsed_us_since(measure_start_us)
        } else {
          0UL
        }
        if trace_enabled {
          local_measure_us = local_measure_us + measure_elapsed_us
          trace_stats.expr_measure_us = trace_stats.expr_measure_us +
            measure_elapsed_us
        }
        saved += item_measure
        num += 1
        let total_elapsed_us = if trace_enabled {
          cf_trace_elapsed_us_since(start_us)
        } else {
          0UL
        }
        if total_elapsed_us >= next_progress_us {
          cf_trace_expr_progress(
            trace_ctx,
            tails,
            num,
            mergeable.length(),
            saved,
            total_elapsed_us,
            local_match_us,
            local_can_move_us,
            local_measure_us,
          )
          next_progress_us = total_elapsed_us + CF_EXPR_PROGRESS_LOG_INTERVAL_US
        }
      }
    }
  }
  if saved == 0 {
    if trace_enabled {
      trace_stats.expr_us = trace_stats.expr_us +
        cf_trace_elapsed_us_since(start_us)
    }
    return None
  }

  // Check if it's worth it
  if saved < WORTH_ADDING_BLOCK_TO_REMOVE_THIS_MUCH {
    // See if we get rid of a block
    let mut will_empty_block = false
    for tail in tails {
      if mergeable.length() >= tail.block_instrs.length() - 1 {
        will_empty_block = true
        break
      }
    }
    if not(will_empty_block) && !parent_can_absorb_wrapper {
      if trace_enabled {
        trace_stats.expr_us = trace_stats.expr_us +
          cf_trace_elapsed_us_since(start_us)
      }
      return None
    }
  }

  if trace_enabled {
    trace_stats.expr_us = trace_stats.expr_us +
      cf_trace_elapsed_us_since(start_us)
  }
  let merged_instrs : Array[TInstr] = []
  let mut i = mergeable.length() - 1
  while i >= 0 {
    merged_instrs.push(mergeable[i])
    i -= 1
  }
  Some({ merged_instrs, saved })
}

///|
/// Optimize terminating tails (returns/unreachables) at function body level
/// This moves common code before return/unreachable instructions to the end of function.
/// The shared tail must remain explicitly terminating; trimming original
/// terminators without replacing them with a branch to the shared tail can make
/// previously-dead paths reachable and trigger stack underflow during validation.
fn optimize_terminating_tails(
  state : CodeFoldingState,
  tails : Array[ScopedTail],
  func_body : Array[TInstr],
  trace_stats : CodeFoldingRoundTraceStats,
) -> Array[TInstr]? {
  let active_tails : Array[ScopedTail] = []
  for tail in tails {
    match tail.tail.instr {
      Some(i) if state.modifieds.contains(i) => ()
      _ => active_tails.push(tail)
    }
  }
  cf_optimize_terminating_tails_at_depth(
    state, active_tails, func_body, trace_stats, 0,
  )
}

///|
fn cf_step_path_instrs(
  instrs : Array[TInstr],
  step : BlockTailPathStep,
) -> Array[TInstr]? {
  match step {
    BlockBody(idx) =>
      if idx < 0 || idx >= instrs.length() {
        None
      } else {
        match instrs[idx].kind {
          TInstrKind::TBlock(_, body) => Some(body.instrs)
          _ => None
        }
      }
    LoopBody(idx) =>
      if idx < 0 || idx >= instrs.length() {
        None
      } else {
        match instrs[idx].kind {
          TInstrKind::TLoop(_, body) => Some(body.instrs)
          _ => None
        }
      }
    IfThen(idx) =>
      if idx < 0 || idx >= instrs.length() {
        None
      } else {
        match instrs[idx].kind {
          TInstrKind::TIf(_, _, then_body, _) => Some(then_body.instrs)
          _ => None
        }
      }
    IfElse(idx) =>
      if idx < 0 || idx >= instrs.length() {
        None
      } else {
        match instrs[idx].kind {
          TInstrKind::TIf(_, _, _, Some(else_body)) => Some(else_body.instrs)
          _ => None
        }
      }
    TryBody(idx) =>
      if idx < 0 || idx >= instrs.length() {
        None
      } else {
        match instrs[idx].kind {
          TInstrKind::TTryTable(_, _, body) => Some(body.instrs)
          _ => None
        }
      }
  }
}

///|
fn cf_tail_try_paths_allow_throw_move(
  func_body : Array[TInstr],
  tail : ScopedTail,
  uncaught_throw_tag? : TagIdx? = None,
) -> Bool {
  let mut current_instrs = func_body
  for step in tail.path {
    match step {
      TryBody(idx) =>
        if idx < 0 || idx >= current_instrs.length() {
          return false
        } else {
          match current_instrs[idx].kind {
            TInstrKind::TTryTable(_, catches, body) =>
              if catches.is_empty() {
                current_instrs = body.instrs
              } else {
                let tag = match uncaught_throw_tag {
                  Some(tag) => tag
                  None => return false
                }
                if cf_try_table_catches_throw_tag(catches, tag) {
                  return false
                }
                current_instrs = body.instrs
              }
            _ => return false
          }
        }
      _ =>
        match cf_step_path_instrs(current_instrs, step) {
          Some(next_instrs) => current_instrs = next_instrs
          None => return false
        }
    }
  }
  true
}

///|
fn cf_try_table_catches_throw_tag(catches : Array[Catch], tag : TagIdx) -> Bool {
  for catch_ in catches {
    match catch_ {
      Catch(curr_tag, _) | CatchRef(curr_tag, _) =>
        if curr_tag == tag {
          return true
        }
      CatchAll(_) | CatchAllRef(_) => return true
    }
  }
  false
}

///|
fn cf_shared_tail_uncaught_throw_tag(
  shared_tail_instrs : Array[TInstr],
) -> TagIdx? {
  if shared_tail_instrs.is_empty() {
    return None
  }
  let last = shared_tail_instrs[shared_tail_instrs.length() - 1]
  let tag = match last.kind {
    TInstrKind::TThrow(tag, values) => {
      for value in values {
        if cf_instr_may_throw(value) {
          return None
        }
      }
      tag
    }
    _ => return None
  }
  let mut i = 0
  while i < shared_tail_instrs.length() - 1 {
    if cf_instr_may_throw(shared_tail_instrs[i]) {
      return None
    }
    i += 1
  }
  Some(tag)
}

///|
fn cf_try_table_throw_move_safe(
  func_body : Array[TInstr],
  tails : Array[ScopedTail],
  uncaught_throw_tag? : TagIdx? = None,
) -> Bool {
  for tail in tails {
    if !cf_tail_try_paths_allow_throw_move(func_body, tail, uncaught_throw_tag~) {
      return false
    }
  }
  true
}

///|
fn cf_scoped_tail_is_live_in_body(
  func_body : Array[TInstr],
  tail : ScopedTail,
) -> Bool {
  let mut current_instrs = func_body
  for step in tail.path {
    match cf_step_path_instrs(current_instrs, step) {
      Some(next_instrs) => current_instrs = next_instrs
      None => return false
    }
  }
  match tail.exact_index {
    Some(index) => {
      if index < 0 || index >= current_instrs.length() {
        return false
      }
      match tail.tail.instr {
        Some(instr) => current_instrs[index] == instr
        None => false
      }
    }
    None =>
      match tail.tail.instr {
        Some(instr) =>
          !current_instrs.is_empty() &&
          current_instrs[current_instrs.length() - 1] == instr
        None => false
      }
  }
}

///|
fn cf_optimize_terminating_tails_at_depth(
  state : CodeFoldingState,
  tails : Array[ScopedTail],
  func_body : Array[TInstr],
  trace_stats : CodeFoldingRoundTraceStats,
  depth : Int,
) -> Array[TInstr]? {
  let live_tails : Array[ScopedTail] = []
  for tail in tails {
    if cf_scoped_tail_is_live_in_body(func_body, tail) {
      live_tails.push(tail)
    }
  }
  if live_tails.length() < 2 {
    return None
  }

  for group in cf_group_terminating_tails(live_tails, depth, trace_stats) {
    match
      cf_optimize_terminating_tails_at_depth(
        state,
        group,
        func_body,
        trace_stats,
        depth + 1,
      ) {
      Some(result) => return Some(result)
      None => ()
    }
  }

  if depth == 0 {
    return None
  }

  let plan = match
    cf_build_terminating_tail_plan(state, live_tails, trace_stats) {
    Some(plan) => plan
    None => return None
  }
  let move_container = TInstr::block(
    BlockType::void_(),
    TExpr::new(cf_copy_instrs(func_body)),
  )
  let uncaught_throw_tag = cf_shared_tail_uncaught_throw_tag(
    plan.shared_tail_instrs,
  )
  let allow_throw_across_try_table = cf_items_may_throw(plan.shared_tail_instrs) &&
    cf_instr_has_try_table(move_container) &&
    cf_try_table_throw_move_safe(func_body, live_tails, uncaught_throw_tag~)
  if !can_move_with_trace(
      plan.shared_tail_instrs,
      move_container,
      trace_stats,
      allow_throw_across_try_table~,
    ) {
    return None
  }

  let rewritten_body = match
    cf_rewrite_terminating_tail_instrs(
      func_body,
      [],
      live_tails,
      plan.merge_count,
      plan.temp_locals,
    ) {
    Some(rewritten_body) => rewritten_body
    None => return None
  }

  let result : Array[TInstr] = []
  result.push(TInstr::block(BlockType::void_(), TExpr::new(rewritten_body)))
  for instr in plan.shared_tail_instrs {
    result.push(instr)
  }

  let next_locals = state.func_locals.copy()
  for ty in plan.temp_local_types {
    next_locals.push(ty)
  }
  let check_env = state.env.with_locals(next_locals)
  match Typecheck::typecheck(TExpr::new(result), make_state(check_env, [])) {
    Ok(_) => ()
    Err(_) => return None
  }

  for ty in plan.temp_local_types {
    ignore(state.append_local(ty))
  }
  for tail in live_tails {
    match tail.tail.instr {
      Some(i) => state.modifieds.add(i)
      None => ()
    }
  }
  state.another_pass = true
  Some(result)
}

///|
/// Collect tails from a block's instructions
fn collect_block_tails(
  state : CodeFoldingState,
  instrs : Array[TInstr],
  trace_stats : CodeFoldingRoundTraceStats,
  path? : Array[BlockTailPathStep] = [],
) -> Unit {
  trace_stats.collect_calls += 1
  trace_stats.collect_instrs += instrs.length()
  for i = 0; i < instrs.length(); i = i + 1 {
    let instr = instrs[i]
    match instr.kind {
      // Unconditional branch at end of block
      TInstrKind::TBr(label, _) if i == instrs.length() - 1 => {
        let tails = state.break_tails.get(label).unwrap_or([])
        tails.push(Tail::branch(instr, instrs))
        state.break_tails.set(label, tails)
      }

      // Conditional branches are not optimizable
      TInstrKind::TBrIf(label, _, _) => state.unoptimizables.add(label)
      TInstrKind::TBrTable(labels, default, _, _) => {
        for label in labels {
          state.unoptimizables.add(label)
        }
        state.unoptimizables.add(default)
      }
      TInstrKind::TBrOnNull(label, _, _) => state.unoptimizables.add(label)
      TInstrKind::TBrOnNonNull(label, _, _) => state.unoptimizables.add(label)
      TInstrKind::TBrOnCast(label, _, _, _, _, _) =>
        state.unoptimizables.add(label)
      TInstrKind::TBrOnCastFail(label, _, _, _, _, _) =>
        state.unoptimizables.add(label)

      // Unreachable at end of block
      TInstrKind::TUnreachable if i == instrs.length() - 1 =>
        state.unreachable_tails.push({
          tail: Tail::branch(instr, instrs),
          path,
          exact_index: None,
        })

      // Return at end of block
      TInstrKind::TReturn(_) =>
        state.return_tails.push({
          tail: if i == instrs.length() - 1 {
            Tail::branch(instr, instrs)
          } else {
            Tail::exact(instr, instrs)
          },
          path,
          exact_index: if i == instrs.length() - 1 {
            None
          } else {
            Some(i)
          },
        })

      // Return calls
      TInstrKind::TReturnCall(_, _)
      | TInstrKind::TReturnCallIndirect(_, _, _, _)
      | TInstrKind::TReturnCallRef(_, _, _) =>
        state.return_tails.push({
          tail: if i == instrs.length() - 1 {
            Tail::branch(instr, instrs)
          } else {
            Tail::exact(instr, instrs)
          },
          path,
          exact_index: if i == instrs.length() - 1 {
            None
          } else {
            Some(i)
          },
        })

      // Throw instructions terminate control flow similarly to unreachable.
      TInstrKind::TThrow(_, _) | TInstrKind::TThrowRef(_) =>
        state.unreachable_tails.push({
          tail: if i == instrs.length() - 1 {
            Tail::branch(instr, instrs)
          } else {
            Tail::exact(instr, instrs)
          },
          path,
          exact_index: if i == instrs.length() - 1 {
            None
          } else {
            Some(i)
          },
        })

      // Recursively process nested blocks
      TInstrKind::TBlock(_, body) => {
        state.block_sites += 1
        collect_block_tails(
          state,
          body.instrs,
          trace_stats,
          path=cf_path_append(path, BlockBody(i)),
        )
      }
      TInstrKind::TLoop(_, body) =>
        collect_block_tails(
          state,
          body.instrs,
          trace_stats,
          path=cf_path_append(path, LoopBody(i)),
        )
      TInstrKind::TIf(_, _, then_body, else_body) => {
        if else_body is Some(_) {
          state.if_else_sites += 1
        }
        collect_block_tails(
          state,
          then_body.instrs,
          trace_stats,
          path=cf_path_append(path, IfThen(i)),
        )
        match else_body {
          Some(body) =>
            collect_block_tails(
              state,
              body.instrs,
              trace_stats,
              path=cf_path_append(path, IfElse(i)),
            )
          None => ()
        }
      }
      TInstrKind::TTryTable(_, _, body) =>
        collect_block_tails(
          state,
          body.instrs,
          trace_stats,
          path=cf_path_append(path, TryBody(i)),
        )
      _ => ()
    }
  }
}

///|
fn cf_find_block_tail_value(tails : Array[ScopedTail]) -> TInstr? {
  for scoped_tail in tails {
    match scoped_tail.tail.instr {
      Some({ kind: TInstrKind::TBr(_, values), .. }) if !values.is_empty() =>
        return Some(values[0])
      _ => ()
    }
  }
  None
}

///|
fn cf_rewrite_merged_instrs_with_temp_local(
  merged_instrs : Array[TInstr],
  temp_local? : CodeFoldingTempLocal? = None,
) -> Array[TInstr] {
  let out : Array[TInstr] = []
  let mut i = 0
  while i < merged_instrs.length() {
    match temp_local {
      Some({ local_idx, .. }) if i == merged_instrs.length() - 1 =>
        out.push(TInstr::local_get(local_idx))
      _ => out.push(merged_instrs[i])
    }
    i += 1
  }
  out
}

///|
fn cf_preview_block_temp_local(
  state : CodeFoldingState,
  tails : Array[ScopedTail],
  merged_instrs : Array[TInstr],
  results : Array[ValType],
) -> (CodeFoldingTempLocal, Array[ValType], Env)? {
  let value_instr = match cf_find_block_tail_value(tails) {
    Some(value_instr) => value_instr
    None => return None
  }
  if merged_instrs.is_empty() || results.length() != 1 {
    return None
  }
  if merged_instrs[merged_instrs.length() - 1] != value_instr {
    return None
  }
  let (local_idx, preview_locals, preview_env) = state.preview_appended_local(
    results[0],
  )
  Some(({ local_idx, value_instr }, preview_locals, preview_env))
}

///|
/// Process a block instruction for code folding
fn process_block(
  state : CodeFoldingState,
  bt : BlockType,
  label : LabelIdx,
  instrs : Array[TInstr],
  trace_stats : CodeFoldingRoundTraceStats,
  trace_ctx : CodeFoldingExprTraceCtx,
) -> (TInstr, Array[ValType]?)? {
  trace_stats.block_visits += 1
  ignore(label)
  if instrs.is_empty() {
    return None
  }
  let results = match cf_empty_param_block_results(bt, state.env) {
    Some(results) => results
    None => return None
  }
  let (scoped_tails, blocked) = cf_collect_local_block_tails(instrs)
  if blocked {
    return None
  }
  if !cf_block_tail_values_supported(scoped_tails, results.length()) {
    return None
  }
  let all_tails : Array[Tail] = []
  for scoped_tail in scoped_tails {
    all_tails.push(scoped_tail.tail)
  }
  let rewrite_tails = scoped_tails.copy()
  let last = instrs[instrs.length() - 1]
  if !is_branch(last) && !is_terminating(last) {
    all_tails.push(Tail::fallthrough(instrs))
    rewrite_tails.push({
      tail: Tail::fallthrough(instrs),
      path: [],
      exact_index: None,
    })
  }
  if all_tails.length() < 2 {
    return None
  }
  let curr = TInstr::block(bt, TExpr::new(instrs))
  match
    find_expression_fold_plan(
      state,
      all_tails,
      curr,
      trace_stats,
      { ..trace_ctx, site_kind: "block" },
      allow_branch_tails=true,
      parent_can_absorb_wrapper=state.parent_is_block,
    ) {
    Some(plan) => {
      let empty_stack : Array[ValType] = []
      let (temp_local, committed_locals, local_env) = match
        cf_preview_block_temp_local(
          state,
          rewrite_tails,
          plan.merged_instrs,
          results,
        ) {
        Some((temp_local, preview_locals, local_env)) =>
          (Some(temp_local), Some(preview_locals), local_env)
        None => (None, None, state.env)
      }
      let wrapper_env = local_env.with_label(results)
      let merged_instrs = cf_rewrite_merged_instrs_with_temp_local(
        plan.merged_instrs,
        temp_local~,
      )
      let merged_expr = TExpr::new(merged_instrs)
      let merged_stack = match
        cf_typecheck_texpr_stack(merged_expr, local_env, empty_stack) {
        Some(stack) => stack
        None => return None
      }
      if merged_stack != results {
        return None
      }
      let rewritten_body = cf_rewrite_block_fold_instrs(
        instrs,
        [],
        rewrite_tails,
        plan.merged_instrs.length(),
        temp_local~,
      )
      let rewritten_body = cf_shift_outer_labels_instrs(rewritten_body)
      let inner_block = TInstr::block(
        BlockType::void_(),
        TExpr::new(rewritten_body),
      )
      let inner_stack = match
        cf_typecheck_tinstr_stack(inner_block, wrapper_env, empty_stack) {
        Some(stack) => stack
        None => return None
      }
      if inner_stack != empty_stack {
        return None
      }
      let wrapper = TInstr::block(
        bt,
        TExpr::new(cf_concat_instrs([inner_block], merged_instrs)),
      )
      let wrapper_stack = match
        cf_typecheck_tinstr_stack(wrapper, local_env, empty_stack) {
        Some(stack) => stack
        None => return None
      }
      if wrapper_stack != results {
        return None
      }
      trace_stats.expr_successes += 1
      trace_stats.expr_merged_instrs += plan.merged_instrs.length()
      trace_stats.expr_saved += plan.saved
      trace_stats.block_successes += 1
      Some((wrapper, committed_locals))
    }
    None => None
  }
}

///|
/// Process an if instruction for code folding
fn process_if(
  state : CodeFoldingState,
  bt : BlockType,
  cond : TInstr,
  then_body : TExpr,
  else_body : TExpr?,
  trace_stats : CodeFoldingRoundTraceStats,
  trace_ctx : CodeFoldingExprTraceCtx,
) -> TInstr? {
  trace_stats.if_visits += 1
  match else_body {
    None => None
    Some(else_expr) => {
      let results = match cf_empty_param_block_results(bt, state.env) {
        Some(results) => results
        None => return None
      }
      let wrapper_env = state.env.with_label(results)
      let empty_stack : Array[ValType] = []
      let tails = [
        Tail::fallthrough(then_body.instrs),
        Tail::fallthrough(else_expr.instrs),
      ]
      match
        find_expression_fold_plan(
          state,
          tails,
          TInstr::if_(bt, cond, then_body, Some(else_expr)),
          trace_stats,
          { ..trace_ctx, site_kind: "if" },
          parent_can_absorb_wrapper=state.parent_is_block,
        ) {
        Some(plan) => {
          let merged_expr = TExpr::new(plan.merged_instrs)
          let merged_stack = match
            cf_typecheck_texpr_stack(merged_expr, state.env, empty_stack) {
            Some(stack) => stack
            None => return None
          }
          if merged_stack != results {
            return None
          }
          let merge_count = plan.merged_instrs.length()
          if merge_count > then_body.instrs.length() ||
            merge_count > else_expr.instrs.length() {
            return None
          }
          let new_then = TExpr::new(
            cf_shift_outer_labels_instrs(
              cf_take_instr_prefix(
                then_body.instrs,
                then_body.instrs.length() - merge_count,
              ),
            ),
          )
          let new_else = TExpr::new(
            cf_shift_outer_labels_instrs(
              cf_take_instr_prefix(
                else_expr.instrs,
                else_expr.instrs.length() - merge_count,
              ),
            ),
          )
          let new_cond = cf_shift_cond_outer_labels(cond)
          let arms_empty = new_then.instrs.is_empty() &&
            new_else.instrs.is_empty()
          let prefix_instr = if arms_empty {
            TInstr::drop(new_cond)
          } else {
            let inner_if = TInstr::if_(
              BlockType::void_(),
              new_cond,
              new_then,
              Some(new_else),
            )
            let inner_stack = match
              cf_typecheck_tinstr_stack(inner_if, wrapper_env, empty_stack) {
              Some(stack) => stack
              None => return None
            }
            if inner_stack != empty_stack {
              return None
            }
            inner_if
          }
          let wrapper = TInstr::block(
            bt,
            TExpr::new(cf_concat_instrs([prefix_instr], plan.merged_instrs)),
          )
          let wrapper_stack = match
            cf_typecheck_tinstr_stack(wrapper, state.env, empty_stack) {
            Some(stack) => stack
            None => return None
          }
          if wrapper_stack != results {
            return None
          }
          state.another_pass = true
          trace_stats.expr_successes += 1
          trace_stats.expr_merged_instrs += merge_count
          trace_stats.expr_saved += plan.saved
          trace_stats.if_successes += 1
          Some(wrapper)
        }
        None => None
      }
    }
  }
}

///|
fn cf_block_body_env(env : Env, bt : BlockType) -> Env {
  match env.expand_blocktype(bt) {
    Ok((_, results)) => env.with_label(results)
    Err(_) => env
  }
}

///|
fn cf_loop_body_env(env : Env, bt : BlockType) -> Env {
  match env.expand_blocktype(bt) {
    Ok((params, _)) => env.with_label(params)
    Err(_) => env
  }
}

///|
fn cf_restore_state_env(
  state : CodeFoldingState,
  env : Env,
  parent_is_block? : Bool = state.parent_is_block,
) -> CodeFoldingState {
  CodeFoldingState::{
    ..state,
    env: env.with_locals(state.func_locals),
    parent_is_block,
  }
}

///|
/// Main code folding pass
fn code_folding_pass_with_trace(
  trace? : (String) -> Unit = cf_trace_noop,
  trace_all_funcs? : Bool = true,
) -> ModuleTransformer[CodeFoldingState, String] {
  let mut seen_funcs = 0
  let round_stats = cf_round_trace_stats_new()
  let total_stats = cf_round_trace_stats_new()
  let mut expr_trace_ctx : CodeFoldingExprTraceCtx = {
    enabled: false,
    trace,
    func_ordinal: 0,
    round: 0,
    site_kind: "",
  }
  ModuleTransformer::new()
  .on_tinstruction_evt(fn(self, state : CodeFoldingState, instr : TInstr) {
    match instr.kind {
      TInstrKind::TBlock(bt, body) => {
        let original_env = state.env
        let (state1, bt1, bt_changed) = match self.walk_blocktype(state, bt) {
          Ok((bt1, state1)) => (state1, bt1, true)
          Err(e) => return error(e)
        }
        let nested_state = cf_restore_state_env(
          state1,
          cf_block_body_env(state1.env, bt1),
          parent_is_block=true,
        )
        let (state2, body1, body_changed) = match
          self.walk_texpr(nested_state, body) {
          Ok((body1, state2)) => (state2, body1, true)
          Err(e) => return error(e)
        }
        let restored_state = cf_restore_state_env(
          state2,
          original_env,
          parent_is_block=state.parent_is_block,
        )
        let rewritten = TInstr::block(bt1, body1)
        match
          process_block(
            restored_state,
            bt1,
            LabelIdx::new(0),
            body1.instrs,
            round_stats,
            expr_trace_ctx,
          ) {
          Some((changed_instr, committed_locals)) => {
            match committed_locals {
              Some(locals) => restored_state.prepare_func(locals)
              None => ()
            }
            restored_state.another_pass = true
            change(restored_state, changed_instr)
          }
          None =>
            if bt_changed || body_changed {
              change(restored_state, rewritten)
            } else {
              unchanged()
            }
        }
      }
      TInstrKind::TLoop(bt, body) => {
        let original_env = state.env
        let (state1, bt1, bt_changed) = match self.walk_blocktype(state, bt) {
          Ok((bt1, state1)) => (state1, bt1, true)
          Err(e) => return error(e)
        }
        let nested_state = cf_restore_state_env(
          state1,
          cf_loop_body_env(state1.env, bt1),
          parent_is_block=false,
        )
        let (state2, body1, body_changed) = match
          self.walk_texpr(nested_state, body) {
          Ok((body1, state2)) => (state2, body1, true)
          Err(e) => return error(e)
        }
        let restored_state = cf_restore_state_env(
          state2,
          original_env,
          parent_is_block=state.parent_is_block,
        )
        let rewritten = TInstr::loop_(bt1, body1)
        if bt_changed || body_changed {
          change(restored_state, rewritten)
        } else {
          unchanged()
        }
      }
      TInstrKind::TIf(bt, cond, then_body, else_body) => {
        let original_env = state.env
        let (state1, bt1, bt_changed) = match self.walk_blocktype(state, bt) {
          Ok((bt1, state1)) => (state1, bt1, true)
          Err(e) => return error(e)
        }
        let (state2, cond1, cond_changed) = match
          self.walk_tinstruction(state1, cond) {
          Ok((cond1, state2)) => (state2, cond1, true)
          Err(e) => return error(e)
        }
        let branch_state = cf_restore_state_env(
          state2,
          cf_block_body_env(state2.env, bt1),
          parent_is_block=false,
        )
        let (state3, then1, then_changed) = match
          self.walk_texpr(branch_state, then_body) {
          Ok((then1, state3)) => (state3, then1, true)
          Err(e) => return error(e)
        }
        let (state4, else1, else_changed) = match else_body {
          Some(else_expr) =>
            match self.walk_texpr(state3, else_expr) {
              Ok((else1, state4)) => (state4, Some(else1), true)
              Err(e) => return error(e)
            }
          None => (state3, else_body, false)
        }
        let restored_state = cf_restore_state_env(
          state4,
          original_env,
          parent_is_block=state.parent_is_block,
        )
        let rewritten = TInstr::if_(bt1, cond1, then1, else1)
        match
          process_if(
            restored_state, bt1, cond1, then1, else1, round_stats, expr_trace_ctx,
          ) {
          Some(changed_instr) => change(restored_state, changed_instr)
          None =>
            if bt_changed || cond_changed || then_changed || else_changed {
              change(restored_state, rewritten)
            } else {
              unchanged()
            }
        }
      }
      TInstrKind::TTryTable(bt, catches, body) => {
        let original_env = state.env
        let (state1, bt1, bt_changed) = match self.walk_blocktype(state, bt) {
          Ok((bt1, state1)) => (state1, bt1, true)
          Err(e) => return error(e)
        }
        let (state2, catches1, catches_changed) = match
          self.walk_array(state1, ModuleTransformer::walk_catch, catches) {
          Ok((catches1, state2)) => (state2, catches1, true)
          Err(e) => return error(e)
        }
        let nested_state = cf_restore_state_env(
          state2,
          cf_block_body_env(state2.env, bt1),
          parent_is_block=false,
        )
        let (state3, body1, body_changed) = match
          self.walk_texpr(nested_state, body) {
          Ok((body1, state3)) => (state3, body1, true)
          Err(e) => return error(e)
        }
        let restored_state = cf_restore_state_env(
          state3,
          original_env,
          parent_is_block=state.parent_is_block,
        )
        let rewritten = TInstr::try_table(bt1, catches1, body1)
        if bt_changed || catches_changed || body_changed {
          change(restored_state, rewritten)
        } else {
          unchanged()
        }
      }
      _ => from_walk(self.walk_tinstruction_default(state, instr))
    }
  })
  .on_func_evt(fn(self, state, func : Func) {
    seen_funcs += 1
    let ordinal = seen_funcs
    let log_func = pass_trace_log_enabled(ordinal, trace_all_funcs)
    match func {
      Func(_) => {
        if log_func {
          trace("func[\{ordinal}] skip non-typed-func")
        }
        unchanged()
      }
      TFunc(func_params, locals, body) => {
        let function_locals = match
          FunctionLocals::from_typed_func_for_pass(
            state.param_types,
            func_params,
            locals,
          ) {
          Ok(ls) => ls
          Err(e) =>
            return error(
              "code_folding: malformed typed function locals for func[\{ordinal}]: \{e}",
            )
        }
        let active_params = function_locals.params()
        let active_body_locals = function_locals.body_locals()
        state.prepare_func(function_locals.all_locals())
        let func_start_us = cf_trace_now_us()
        let start_top_instrs = body.instrs.length()
        if log_func {
          trace(
            "func[\{ordinal}] start top_instrs=\{start_top_instrs} locals=\{state.func_locals.length()}",
          )
        }
        if cf_can_fast_skip_func_body(body) {
          let elapsed_us = cf_trace_elapsed_us_since(func_start_us)
          if log_func {
            trace(
              "func[\{ordinal}] skip reason=no_control_surface top_instrs=\{start_top_instrs}",
            )
            trace(
              "func[\{ordinal}] done elapsed_ms=\{cf_trace_delta_us_to_ms(elapsed_us)} elapsed_us=\{elapsed_us} rounds=0 changed=false top_instrs=\{start_top_instrs}->\{start_top_instrs} collect_ms=0 return_ms=0 unreachable_ms=0 walk_ms=0 return_changed=0 unreachable_changed=0 blocks=0 ifs=0 expr_calls=0 expr_changed=0 expr_saved=0 measure_ms=0 branch_ms=0 can_move_ms=0",
            )
          }
          unchanged()
        } else {
          total_stats.clear()
          total_stats.set_enabled(log_func)

          // Run multiple passes until no more changes
          let mut current_func = Func::t_func(
            active_params, active_body_locals, body,
          )
          let mut current_locals = state.func_locals
          let mut current_body = body
          let mut rounds = 0
          let mut disable_expr_walk_after_terminating = false
          state.another_pass = true
          while state.another_pass {
            rounds += 1
            round_stats.clear()
            round_stats.set_enabled(log_func)
            state.another_pass = false
            state.clear()
            expr_trace_ctx = {
              enabled: log_func,
              trace,
              func_ordinal: ordinal,
              round: rounds,
              site_kind: "",
            }
            if log_func {
              trace(
                "func[\{ordinal}] round[\{rounds}] start top_instrs=\{current_body.instrs.length()}",
              )
            }

            // Collect tails from function body
            let collect_start_us = cf_trace_now_us()
            collect_block_tails(state, current_body.instrs, round_stats)
            let collect_elapsed_us = cf_trace_elapsed_us_since(collect_start_us)
            round_stats.collect_us = round_stats.collect_us + collect_elapsed_us
            if log_func {
              let break_stats = cf_break_tail_trace_stats(state)
              trace(
                "func[\{ordinal}] round[\{rounds}] collect_tails elapsed_ms=\{cf_trace_delta_us_to_ms(collect_elapsed_us)} elapsed_us=\{collect_elapsed_us} bodies=\{round_stats.collect_calls} instrs=\{round_stats.collect_instrs} blocks=\{state.block_sites} if_elses=\{state.if_else_sites} break_labels=\{break_stats.label_count} break_tails=\{break_stats.tail_count} max_break_fanout=\{break_stats.max_label_tails} returns=\{state.return_tails.length()} unreachables=\{state.unreachable_tails.length()} unoptimizable=\{state.unoptimizables.length()}",
              )
            }

            // Try terminating tail optimization (unreachables/returns)
            round_stats.unreachable_phase_calls += 1
            let unreachable_tail_count = state.unreachable_tails.length()
            round_stats.unreachable_phase_tails += unreachable_tail_count
            let skip_unreachable_phase = cf_should_skip_terminating_tail_phase(
              unreachable_tail_count,
              round_stats.collect_calls,
            )
            let unreachable_result = if unreachable_tail_count < 2 {
              None
            } else if skip_unreachable_phase {
              None
            } else {
              let unreachable_start_us = if log_func {
                cf_trace_now_us()
              } else {
                0UL
              }
              let unreachable_result = optimize_terminating_tails(
                state,
                state.unreachable_tails,
                current_body.instrs,
                round_stats,
              )
              if log_func {
                let unreachable_elapsed_us = cf_trace_elapsed_us_since(
                  unreachable_start_us,
                )
                round_stats.unreachable_phase_us = round_stats.unreachable_phase_us +
                  unreachable_elapsed_us
                trace(
                  "func[\{ordinal}] round[\{rounds}] terminating_unreachable elapsed_ms=\{cf_trace_delta_us_to_ms(unreachable_elapsed_us)} elapsed_us=\{unreachable_elapsed_us} tails=\{unreachable_tail_count} changed=\{unreachable_result is Some(_)}",
                )
              }
              unreachable_result
            }
            if unreachable_tail_count < 2 && log_func {
              trace(
                "func[\{ordinal}] round[\{rounds}] terminating_unreachable elapsed_ms=0 elapsed_us=0 tails=\{unreachable_tail_count} changed=false",
              )
            } else if skip_unreachable_phase && log_func {
              trace(
                "func[\{ordinal}] round[\{rounds}] terminating_unreachable elapsed_ms=0 elapsed_us=0 tails=\{unreachable_tail_count} changed=false skipped reason=terminating_budget collect_bodies=\{round_stats.collect_calls} tail_limit=\{CF_TERMINATING_TAIL_COUNT_LIMIT} collect_body_limit=\{CF_TERMINATING_COLLECT_BODY_LIMIT}",
              )
            }
            match unreachable_result {
              Some(new_body_instrs) => {
                round_stats.unreachable_phase_successes += 1
                disable_expr_walk_after_terminating = true
                current_body = TExpr::new(new_body_instrs)
                current_locals = state.func_locals
                current_func = cf_build_tfunc(
                  active_params, current_locals, current_body,
                )
                // Unreachable folding may wrap/rebase paths; refresh tail
                // collections so return folding cannot operate on stale paths.
                state.break_tails.clear()
                state.unreachable_tails.clear()
                state.return_tails.clear()
                state.unoptimizables.clear()
                state.block_sites = 0
                state.if_else_sites = 0
                let recollect_start_us = cf_trace_now_us()
                collect_block_tails(state, current_body.instrs, round_stats)
                let recollect_elapsed_us = cf_trace_elapsed_us_since(
                  recollect_start_us,
                )
                round_stats.collect_us = round_stats.collect_us +
                  recollect_elapsed_us
                if log_func {
                  let break_stats = cf_break_tail_trace_stats(state)
                  trace(
                    "func[\{ordinal}] round[\{rounds}] recollect_tails elapsed_ms=\{cf_trace_delta_us_to_ms(recollect_elapsed_us)} elapsed_us=\{recollect_elapsed_us} bodies=\{round_stats.collect_calls} instrs=\{round_stats.collect_instrs} blocks=\{state.block_sites} if_elses=\{state.if_else_sites} break_labels=\{break_stats.label_count} break_tails=\{break_stats.tail_count} max_break_fanout=\{break_stats.max_label_tails} returns=\{state.return_tails.length()} unreachables=\{state.unreachable_tails.length()} unoptimizable=\{state.unoptimizables.length()}",
                  )
                }
              }
              None => ()
            }

            round_stats.return_phase_calls += 1
            let return_tail_count = state.return_tails.length()
            round_stats.return_phase_tails += return_tail_count
            let skip_return_phase = cf_should_skip_terminating_tail_phase(
              return_tail_count,
              round_stats.collect_calls,
            )
            let return_result = if return_tail_count < 2 {
              None
            } else if skip_return_phase {
              None
            } else {
              let return_start_us = if log_func {
                cf_trace_now_us()
              } else {
                0UL
              }
              let return_result = optimize_terminating_tails(
                state,
                state.return_tails,
                current_body.instrs,
                round_stats,
              )
              if log_func {
                let return_elapsed_us = cf_trace_elapsed_us_since(
                  return_start_us,
                )
                round_stats.return_phase_us = round_stats.return_phase_us +
                  return_elapsed_us
                trace(
                  "func[\{ordinal}] round[\{rounds}] terminating_returns elapsed_ms=\{cf_trace_delta_us_to_ms(return_elapsed_us)} elapsed_us=\{return_elapsed_us} tails=\{return_tail_count} changed=\{return_result is Some(_)}",
                )
              }
              return_result
            }
            if return_tail_count < 2 && log_func {
              trace(
                "func[\{ordinal}] round[\{rounds}] terminating_returns elapsed_ms=0 elapsed_us=0 tails=\{return_tail_count} changed=false",
              )
            } else if skip_return_phase && log_func {
              trace(
                "func[\{ordinal}] round[\{rounds}] terminating_returns elapsed_ms=0 elapsed_us=0 tails=\{return_tail_count} changed=false skipped reason=terminating_budget collect_bodies=\{round_stats.collect_calls} tail_limit=\{CF_TERMINATING_TAIL_COUNT_LIMIT} collect_body_limit=\{CF_TERMINATING_COLLECT_BODY_LIMIT}",
              )
            }
            let mut defer_walk_after_return_rewrite = false
            match return_result {
              Some(new_body_instrs) => {
                round_stats.return_phase_successes += 1
                disable_expr_walk_after_terminating = true
                current_body = TExpr::new(new_body_instrs)
                current_locals = state.func_locals
                current_func = cf_build_tfunc(
                  active_params, current_locals, current_body,
                )
                // Return folding rewrites control paths aggressively; refresh
                // collected tails before we consider expression folding again.
                state.break_tails.clear()
                state.unreachable_tails.clear()
                state.return_tails.clear()
                state.unoptimizables.clear()
                state.block_sites = 0
                state.if_else_sites = 0
                let recollect_start_us = cf_trace_now_us()
                collect_block_tails(state, current_body.instrs, round_stats)
                let recollect_elapsed_us = cf_trace_elapsed_us_since(
                  recollect_start_us,
                )
                round_stats.collect_us = round_stats.collect_us +
                  recollect_elapsed_us
                if log_func {
                  let break_stats = cf_break_tail_trace_stats(state)
                  trace(
                    "func[\{ordinal}] round[\{rounds}] recollect_tails elapsed_ms=\{cf_trace_delta_us_to_ms(recollect_elapsed_us)} elapsed_us=\{recollect_elapsed_us} bodies=\{round_stats.collect_calls} instrs=\{round_stats.collect_instrs} blocks=\{state.block_sites} if_elses=\{state.if_else_sites} break_labels=\{break_stats.label_count} break_tails=\{break_stats.tail_count} max_break_fanout=\{break_stats.max_label_tails} returns=\{state.return_tails.length()} unreachables=\{state.unreachable_tails.length()} unoptimizable=\{state.unoptimizables.length()}",
                  )
                }
                defer_walk_after_return_rewrite = true
              }
              None => ()
            }
            if defer_walk_after_return_rewrite {
              if log_func {
                trace(
                  "func[\{ordinal}] round[\{rounds}] walk deferred reason=terminating_returns_changed continue=\{state.another_pass}",
                )
              }
              total_stats.merge_from(round_stats)
              continue
            }

            // Process the function with collected information
            let label_zero_breaks = match
              state.break_tails.get(LabelIdx::new(0)) {
              Some(tails) => tails.length()
              None => 0
            }
            let expr_site_count = state.block_sites + state.if_else_sites
            let block_fanout = state.block_sites * label_zero_breaks
            let has_expr_candidates = state.if_else_sites > 0 ||
              (state.block_sites > 0 && label_zero_breaks > 0)
            let over_expr_budget = expr_site_count > CF_EXPR_SITE_LIMIT
            let over_collect_budget = round_stats.collect_calls >
              CF_COLLECT_BODY_LIMIT
            let over_block_budget = block_fanout > CF_BLOCK_FANOUT_LIMIT
            if CF_ENABLE_EXPRESSION_FOLDING &&
              has_expr_candidates &&
              !over_expr_budget &&
              !over_collect_budget &&
              !over_block_budget &&
              !disable_expr_walk_after_terminating {
              let walk_start_us = cf_trace_now_us()
              let walk_changed = match
                self.walk_func_default(state, current_func) {
                Ok((new_func, new_state)) => {
                  state.func_locals = new_state.func_locals
                  state.env = new_state.env
                  state.another_pass = new_state.another_pass
                  current_func = new_func
                  match current_func {
                    TFunc(_, _, b) => {
                      current_locals = state.func_locals
                      current_body = b
                      current_func = cf_build_tfunc(
                        active_params, current_locals, current_body,
                      )
                    }
                    _ => ()
                  }
                  true
                }
                Err(e) => {
                  let walk_elapsed_us = cf_trace_elapsed_us_since(walk_start_us)
                  round_stats.walk_us = round_stats.walk_us + walk_elapsed_us
                  if log_func {
                    trace(
                      "func[\{ordinal}] round[\{rounds}] walk error elapsed_ms=\{cf_trace_delta_us_to_ms(walk_elapsed_us)} elapsed_us=\{walk_elapsed_us} \{e}",
                    )
                  }
                  return error(e)
                }
              }
              let walk_elapsed_us = cf_trace_elapsed_us_since(walk_start_us)
              round_stats.walk_us = round_stats.walk_us + walk_elapsed_us
              if log_func {
                trace(
                  "func[\{ordinal}] round[\{rounds}] walk elapsed_ms=\{cf_trace_delta_us_to_ms(walk_elapsed_us)} elapsed_us=\{walk_elapsed_us} changed=\{walk_changed} continue=\{state.another_pass} blocks=\{round_stats.block_visits} block_changed=\{round_stats.block_successes} ifs=\{round_stats.if_visits} if_changed=\{round_stats.if_successes} expr_calls=\{round_stats.expr_calls} expr_changed=\{round_stats.expr_successes} expr_tails=\{round_stats.expr_tail_count} expr_merged=\{round_stats.expr_merged_instrs} expr_saved=\{round_stats.expr_saved} expr_ms=\{cf_trace_delta_us_to_ms(round_stats.expr_us)} expr_match_ms=\{cf_trace_delta_us_to_ms(round_stats.expr_match_us)} expr_can_move_ms=\{cf_trace_delta_us_to_ms(round_stats.expr_can_move_us)} expr_measure_ms=\{cf_trace_delta_us_to_ms(round_stats.expr_measure_us)} term_group_checks=\{round_stats.terminating_group_pair_checks} measure_calls=\{round_stats.measure_calls} measure_nodes=\{round_stats.measure_nodes} measure_ms=\{cf_trace_delta_us_to_ms(round_stats.measure_us)} branch_calls=\{round_stats.branch_target_calls} branch_ms=\{cf_trace_delta_us_to_ms(round_stats.branch_target_us)} can_move_calls=\{round_stats.can_move_calls} can_move_ms=\{cf_trace_delta_us_to_ms(round_stats.can_move_us)}",
                )
              }
            } else if log_func {
              let skip_reason = if !has_expr_candidates {
                "no_expr_candidates"
              } else if disable_expr_walk_after_terminating {
                "terminating_rewrite_guard"
              } else if !CF_ENABLE_EXPRESSION_FOLDING {
                "expression_folding_disabled"
              } else if over_expr_budget {
                "expr_site_budget"
              } else if over_collect_budget {
                "collect_body_budget"
              } else {
                "block_fanout_budget"
              }
              trace(
                "func[\{ordinal}] round[\{rounds}] walk skipped reason=\{skip_reason} continue=\{state.another_pass} collect_bodies=\{round_stats.collect_calls} block_sites=\{state.block_sites} if_elses=\{state.if_else_sites} expr_sites=\{expr_site_count} label0_breaks=\{label_zero_breaks} block_fanout=\{block_fanout}",
              )
            }
            total_stats.merge_from(round_stats)
          }
          let elapsed_us = cf_trace_elapsed_us_since(func_start_us)
          let mut final_state = state
          let mut final_func = match current_func {
            TFunc(_, _, final_body) => {
              current_locals = final_state.func_locals
              current_body = final_body
              cf_build_tfunc(active_params, current_locals, current_body)
            }
            _ => current_func
          }
          // If the custom fixed-point loop made no top-level changes, run one
          // default walk pass so nested value-position control surfaces still
          // get folded while keeping locals in sync with emitted indices.
          if final_func == func {
            match self.walk_func_default(final_state, final_func) {
              Ok((walked_func, walked_state)) => {
                final_state = walked_state
                final_func = match walked_func {
                  TFunc(_, _, walked_body) => {
                    current_locals = final_state.func_locals
                    current_body = walked_body
                    cf_build_tfunc(active_params, current_locals, current_body)
                  }
                  _ => walked_func
                }
              }
              Err(e) => return error(e)
            }
          }
          let final_body = match final_func {
            TFunc(_, _, b) => b
            _ => current_body
          }
          let changed = final_func != func
          if log_func {
            trace(
              "func[\{ordinal}] done elapsed_ms=\{cf_trace_delta_us_to_ms(elapsed_us)} elapsed_us=\{elapsed_us} rounds=\{rounds} changed=\{changed} top_instrs=\{start_top_instrs}->\{final_body.instrs.length()} collect_ms=\{cf_trace_delta_us_to_ms(total_stats.collect_us)} return_ms=\{cf_trace_delta_us_to_ms(total_stats.return_phase_us)} unreachable_ms=\{cf_trace_delta_us_to_ms(total_stats.unreachable_phase_us)} walk_ms=\{cf_trace_delta_us_to_ms(total_stats.walk_us)} return_changed=\{total_stats.return_phase_successes} unreachable_changed=\{total_stats.unreachable_phase_successes} blocks=\{total_stats.block_visits} ifs=\{total_stats.if_visits} expr_calls=\{total_stats.expr_calls} expr_changed=\{total_stats.expr_successes} expr_saved=\{total_stats.expr_saved} expr_match_ms=\{cf_trace_delta_us_to_ms(total_stats.expr_match_us)} expr_can_move_ms=\{cf_trace_delta_us_to_ms(total_stats.expr_can_move_us)} expr_measure_ms=\{cf_trace_delta_us_to_ms(total_stats.expr_measure_us)} term_group_checks=\{total_stats.terminating_group_pair_checks} measure_ms=\{cf_trace_delta_us_to_ms(total_stats.measure_us)} branch_ms=\{cf_trace_delta_us_to_ms(total_stats.branch_target_us)} can_move_ms=\{cf_trace_delta_us_to_ms(total_stats.can_move_us)}",
            )
          }
          change(final_state, final_func)
        }
      }
    }
  })
}

///|
fn code_folding_pass() -> ModuleTransformer[CodeFoldingState, String] {
  code_folding_pass_with_trace()
}

///|
fn code_folding_ir_pass_with_trace(
  _mod : Module,
  trace? : (String) -> Unit = cf_trace_noop,
  trace_all_funcs? : Bool = true,
) -> ModuleTransformer[IRContext, String] {
  let pass = code_folding_pass_with_trace(trace~, trace_all_funcs~)
  let base_env = Env::new().with_module(_mod)
  let func_param_types : Array[Array[ValType]] = []
  let func_result_types : Array[Array[ValType]] = []
  match _mod.func_sec {
    Some(FuncSec(type_idxs)) =>
      for type_idx in type_idxs {
        let (params, results) = match base_env.resolve_functype(type_idx) {
          Some(FuncType(params, results)) => (params, results)
          None => ([], [])
        }
        func_param_types.push(params)
        func_result_types.push(results)
      }
    _ => ()
  }
  let mut defined_func_ordinal = 0
  ModuleTransformer::new().on_func_evt(fn(_, ctx : IRContext, func : Func) {
    let next_params = func_param_types.get(defined_func_ordinal).unwrap_or([])
    let next_results = func_result_types.get(defined_func_ordinal).unwrap_or([])
    defined_func_ordinal += 1
    let param_types = next_params
    let result_types = next_results
    let (resolved_params, func_locals, normalized_func) = match func {
      TFunc(tfunc_params, locals, body) =>
        match
          FunctionLocals::from_typed_func_for_pass(
            param_types, tfunc_params, locals,
          ) {
          Ok(function_locals) => {
            let resolved_params = function_locals.params()
            let resolved_body_locals = function_locals.body_locals()
            (
              resolved_params.copy(),
              function_locals.all_locals(),
              Func::t_func(resolved_params, resolved_body_locals, body),
            )
          }
          Err(e) =>
            return error(
              "code_folding_ir_pass: malformed typed function locals for function ordinal \{defined_func_ordinal}: \{e}",
            )
        }
      _ => (param_types, [], func)
    }
    let func_env = base_env
      .with_locals(func_locals)
      .with_return_type(Some(result_types))
    match
      pass.walk_func(
        CodeFoldingState::new(
          env=func_env,
          param_types=resolved_params,
          func_locals~,
        ),
        normalized_func,
      ) {
      Ok((new_func, _)) => change(ctx, new_func)
      Err(e) => error(e)
    }
  })
}

///|
fn code_folding_ir_pass(_mod : Module) -> ModuleTransformer[IRContext, String] {
  code_folding_ir_pass_with_trace(_mod)
}

///|
test "code_folding_pass can be created" {
  let pass = code_folding_pass()
  let state = CodeFoldingState::{
    ..CodeFoldingState::new(),
    another_pass: false,
  }

  // Simple test: pass through a function
  let func = Func::t_func([], [], TExpr::new([TInstr::i32_const(I32(42))]))
  match pass.walk_func(state, func) {
    Ok(_) => () // Pass completes without error
    Err(e) => fail("Unexpected error: " + e)
  }
}

///|
test "code_folding_pass keeps typed params when state param_types is stale" {
  let pass = code_folding_pass()
  let typed_params = [ValType::i32(), ValType::i32(), ValType::i32()]
  let common = TInstr::local_get(LocalIdx::new(0))
  let func = Func::t_func(
    typed_params,
    [],
    TExpr::new([
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::if_(
            BlockType::void_(),
            TInstr::local_get(LocalIdx::new(1)),
            TExpr::new([TInstr::nop(), TInstr::br(LabelIdx::new(1), [common])]),
            Some(TExpr::new([])),
          ),
          common,
        ]),
      ),
    ]),
  )
  let state = CodeFoldingState::{
    ..CodeFoldingState::new(
      env=Env::new().with_locals(typed_params),
      param_types=[],
      func_locals=typed_params,
    ),
    another_pass: false,
  }
  let folded = match pass.walk_func(state, func) {
    Ok((next, _)) => next
    Err(e) => fail("expected code_folding_pass success, got \{e}")
  }
  match folded {
    TFunc(params, _, _) => assert_eq(params, typed_params)
    _ => fail("expected typed function")
  }
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(
          SubType::comp_type(CompType::func(typed_params, [ValType::i32()])),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([folded]))
  assert_eq(validate_module(mod), Ok(()))
}

///|
test "measure counts instructions" {
  let simple = TInstr::i32_const(I32(42))
  assert_true(measure(simple) >= 1)
  let binary = TInstr::binary(
    BinaryOp::i32_add(),
    TInstr::i32_const(I32(1)),
    TInstr::i32_const(I32(2)),
  )
  assert_true(measure(binary) > measure(simple))
}

///|
test "get_branch_targets finds branches" {
  let br = TInstr::br(LabelIdx::new(0), [])
  let targets = get_branch_targets(br)
  assert_true(targets.contains(LabelIdx::new(0)))
  let no_br = TInstr::i32_const(I32(42))
  let no_targets = get_branch_targets(no_br)
  assert_true(no_targets.is_empty())
}

///|
/// Helper to run the code folding pass on a function
fn run_fold_with_env(f : Func, env? : Env = Env::new()) -> Func raise {
  let pass = code_folding_pass()
  let state = CodeFoldingState::{
    ..CodeFoldingState::new(env~),
    another_pass: false,
  }
  match pass.walk_func(state, f) {
    Ok((new_f, _)) => return new_f
    Err(e) => assert_true(false, msg=e)
  }
  f
}

///|
fn run_fold(f : Func) -> Func raise {
  run_fold_with_env(f)
}

///|
fn cf_run_fold_module(mod : Module) -> Module raise {
  let pass = code_folding_ir_pass_with_trace(mod)
  match pass.walk_module(IRContext::new(), mod) {
    Ok((next_mod, _)) => next_mod
    Err(e) => fail("code folding module pass failed: " + e)
  }
}

///|
fn cf_test_instr_any(instr : TInstr, pred : (TInstr) -> Bool) -> Bool {
  if pred(instr) {
    return true
  }
  match instr.kind {
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) =>
      for child in body.instrs {
        if cf_test_instr_any(child, pred) {
          return true
        }
      }
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      if cf_test_instr_any(cond, pred) {
        return true
      }
      for child in then_body.instrs {
        if cf_test_instr_any(child, pred) {
          return true
        }
      }
      match else_body {
        Some(else_body) =>
          for child in else_body.instrs {
            if cf_test_instr_any(child, pred) {
              return true
            }
          }
        None => ()
      }
    }
    _ =>
      for child in eval_children(instr) {
        if cf_test_instr_any(child, pred) {
          return true
        }
      }
  }
  false
}

///|
fn cf_test_func_any_instr(f : Func, pred : (TInstr) -> Bool) -> Bool {
  match f {
    TFunc(_, _, body) => {
      for instr in body.instrs {
        if cf_test_instr_any(instr, pred) {
          return true
        }
      }
      false
    }
    _ => false
  }
}

///|
fn cf_test_func_has_local_set(f : Func, local_idx : LocalIdx) -> Bool {
  cf_test_func_any_instr(f, fn(instr) {
    match instr.kind {
      TInstrKind::TLocalSet(idx, _) => idx == local_idx
      _ => false
    }
  })
}

///|
fn cf_test_func_has_local_get(f : Func, local_idx : LocalIdx) -> Bool {
  cf_test_func_any_instr(f, fn(instr) {
    match instr.kind {
      TInstrKind::TLocalGet(idx) => idx == local_idx
      _ => false
    }
  })
}

///|
fn cf_test_func_has_branch_value(f : Func) -> Bool {
  cf_test_func_any_instr(f, fn(instr) {
    match instr.kind {
      TInstrKind::TBr(_, values) => !values.is_empty()
      _ => false
    }
  })
}

///|
fn cf_test_func_has_branch_target(
  f : Func,
  label : LabelIdx,
  value_count : Int,
) -> Bool {
  cf_test_func_any_instr(f, fn(instr) {
    match instr.kind {
      TInstrKind::TBr(curr_label, values) =>
        curr_label == label && values.length() == value_count
      _ => false
    }
  })
}

///|
fn cf_test_func_count_instrs(f : Func, pred : (TInstr) -> Bool) -> Int {
  let mut count = 0
  ignore(
    cf_test_func_any_instr(f, fn(instr) {
      if pred(instr) {
        count += 1
      }
      false
    }),
  )
  count
}

///|
fn cf_test_module_for_func(f : Func, results : Array[ValType]) -> Module {
  Module::new()
  .with_type_sec(
    TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], results)))]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  .with_code_sec(CodeSec::new([f]))
}

///|
fn cf_assert_value_position_instr(
  instr : TInstr,
  env : Env,
  path : String,
) -> Unit raise {
  match cf_typecheck_tinstr_stack(instr, env, []) {
    Some(stack) =>
      if stack.length() != 1 {
        fail(
          "expected value-producing instruction at \{path}, got stack arity \{stack.length()}: \{instr}",
        )
      }
    None => fail("expected value-producing instruction at \{path}: \{instr}")
  }
  cf_assert_operand_value_positions_instr(instr, env, path)
}

///|
fn cf_assert_operand_value_positions_expr(
  expr : TExpr,
  env : Env,
  path : String,
) -> Unit raise {
  let mut index = 0
  for instr in expr.instrs {
    cf_assert_operand_value_positions_instr(
      instr,
      env,
      "\{path}/instr[\{index}]",
    )
    index += 1
  }
}

///|
fn cf_assert_operand_value_positions_instr(
  instr : TInstr,
  env : Env,
  path : String,
) -> Unit raise {
  match instr.kind {
    TInstrKind::TBlock(bt, body) =>
      cf_assert_operand_value_positions_expr(
        body,
        cf_block_body_env(env, bt),
        "\{path}/block",
      )
    TInstrKind::TLoop(bt, body) =>
      cf_assert_operand_value_positions_expr(
        body,
        cf_loop_body_env(env, bt),
        "\{path}/loop",
      )
    TInstrKind::TIf(bt, cond, then_body, else_body) => {
      cf_assert_value_position_instr(cond, env, "\{path}/if-cond")
      let branch_env = cf_block_body_env(env, bt)
      cf_assert_operand_value_positions_expr(
        then_body,
        branch_env,
        "\{path}/if-then",
      )
      match else_body {
        Some(else_body) =>
          cf_assert_operand_value_positions_expr(
            else_body,
            branch_env,
            "\{path}/if-else",
          )
        None => ()
      }
    }
    TInstrKind::TTryTable(bt, _, body) =>
      cf_assert_operand_value_positions_expr(
        body,
        cf_block_body_env(env, bt),
        "\{path}/try",
      )
    _ =>
      for child in eval_children(instr) {
        cf_assert_value_position_instr(child, env, "\{path}/child")
      }
  }
}

///|
fn cf_assert_func_body_typechecks(
  f : Func,
  results : Array[ValType],
) -> Unit raise {
  match f {
    TFunc(params, locals, body) => {
      let env = Env::new()
        .with_locals(FunctionLocals::new(params, locals).all_locals())
        .with_return_type(Some(results))
      match Typecheck::typecheck(body, make_state(env, [])) {
        Ok(st) =>
          if st.reachable && st.stack != results {
            fail("expected folded body to end with \{results}, got \{st.stack}")
          }
        Err(e) => fail("expected folded body to typecheck: " + e)
      }
    }
    _ => fail("expected TFunc")
  }
}

///|
test "simple function unchanged" {
  let f = Func::t_func([], [], TExpr::new([TInstr::i32_const(I32(42))]))
  let f2 = run_fold(f)
  match f2 {
    TFunc(_, _, { instrs, .. }) => assert_eq(instrs.length(), 1)
    _ => fail("expected TFunc")
  }
}

///|
test "collect_block_tails finds return tails" {
  let state = CodeFoldingState::{
    ..CodeFoldingState::new(),
    another_pass: false,
  }
  let instrs = [
    TInstr::i32_const(I32(1)),
    TInstr::i32_const(I32(2)),
    TInstr::return_([TInstr::i32_const(I32(3))]),
  ]
  collect_block_tails(state, instrs, cf_round_trace_stats_new())
  assert_eq(state.return_tails.length(), 1)
}

///|
test "collect_block_tails finds unreachable tails" {
  let state = CodeFoldingState::{
    ..CodeFoldingState::new(),
    another_pass: false,
  }
  let instrs = [TInstr::i32_const(I32(1)), TInstr::unreachable_()]
  collect_block_tails(state, instrs, cf_round_trace_stats_new())
  assert_eq(state.unreachable_tails.length(), 1)
}

///|
test "collect_block_tails finds throw tails" {
  let state = CodeFoldingState::{
    ..CodeFoldingState::new(),
    another_pass: false,
  }
  let instrs = [
    TInstr::drop(TInstr::i32_const(I32(1))),
    TInstr::throw_(TagIdx::new(0), []),
  ]
  collect_block_tails(state, instrs, cf_round_trace_stats_new())
  assert_eq(state.unreachable_tails.length(), 1)
}

///|
test "collect_block_tails marks br_if as unoptimizable" {
  let state = CodeFoldingState::{
    ..CodeFoldingState::new(),
    another_pass: false,
  }
  let instrs : Array[TInstr] = [
    TInstr::br_if(LabelIdx::new(0), TInstr::i32_const(I32(1)), []),
  ]
  collect_block_tails(state, instrs, cf_round_trace_stats_new())
  assert_true(state.unoptimizables.contains(LabelIdx::new(0)))
}

///|
test "collect_block_tails recurses into blocks" {
  let state = CodeFoldingState::{
    ..CodeFoldingState::new(),
    another_pass: false,
  }
  let inner : Array[TInstr] = [TInstr::return_([TInstr::i32_const(I32(42))])]
  let instrs : Array[TInstr] = [
    TInstr::block(BlockType::void_(), TExpr::new(inner)),
  ]
  collect_block_tails(state, instrs, cf_round_trace_stats_new())
  assert_eq(state.return_tails.length(), 1)
}

///|
test "tail is_fallthrough works" {
  let ft = Tail::fallthrough([TInstr::i32_const(I32(1))])
  assert_true(ft.is_fallthrough())
  let br = Tail::branch(TInstr::br(LabelIdx::new(0), []), [])
  assert_true(not(br.is_fallthrough()))
}

///|
test "get_mergeable returns items from end" {
  let instrs = [
    TInstr::i32_const(I32(1)),
    TInstr::i32_const(I32(2)),
    TInstr::i32_const(I32(3)),
  ]
  let tail = Tail::fallthrough(instrs)

  // First item should be the last instruction
  match get_mergeable(tail, 0) {
    Some({ kind: TInstrKind::TI32Const(I32(3)), .. }) => ()
    _ => fail("expected i32.const 3")
  }

  // Second item should be second-to-last
  match get_mergeable(tail, 1) {
    Some({ kind: TInstrKind::TI32Const(I32(2)), .. }) => ()
    _ => fail("expected i32.const 2")
  }

  // Out of bounds
  match get_mergeable(tail, 10) {
    None => ()
    _ => fail("expected None for out of bounds")
  }
}

///|
test "is_terminating detects terminators" {
  assert_true(is_terminating(TInstr::unreachable_()))
  assert_true(is_terminating(TInstr::return_([])))
  assert_true(is_terminating(TInstr::return_call(FuncIdx::new(0), [])))
  assert_true(not(is_terminating(TInstr::i32_const(I32(42)))))
  assert_true(not(is_terminating(TInstr::nop())))
}

///|
test "is_branch detects branches" {
  assert_true(is_branch(TInstr::br(LabelIdx::new(0), [])))
  assert_true(
    is_branch(TInstr::br_if(LabelIdx::new(0), TInstr::i32_const(I32(1)), [])),
  )
  assert_true(not(is_branch(TInstr::i32_const(I32(42)))))
  assert_true(not(is_branch(TInstr::unreachable_())))
}

///|
test "measure_all sums instruction costs" {
  let instrs = [
    TInstr::i32_const(I32(1)),
    TInstr::i32_const(I32(2)),
    TInstr::i32_const(I32(3)),
  ]
  let total = measure_all(instrs)
  assert_true(total >= 3)
}

///|
test "can_move allows simple instructions" {
  let items = [TInstr::i32_const(I32(42))]
  let container = TInstr::block(BlockType::void_(), TExpr::new([TInstr::nop()]))
  assert_true(can_move(items, container))
}

///|
test "can_move allows branches to labels defined inside moved item" {
  let item = TInstr::block(
    BlockType::void_(),
    TExpr::new([TInstr::br(LabelIdx::new(0), [])]),
  )
  let container = TInstr::block(
    BlockType::void_(),
    TExpr::new([item, TInstr::nop()]),
  )
  assert_true(can_move([item], container))
}

///|
test "can_move rejects branches to container labels outside moved item" {
  let item = TInstr::block(
    BlockType::void_(),
    TExpr::new([TInstr::br(LabelIdx::new(1), [])]),
  )
  let container = TInstr::block(
    BlockType::void_(),
    TExpr::new([item, TInstr::nop()]),
  )
  assert_false(can_move([item], container))
}

///|
test "can_move rejects branches that exit the container entirely" {
  let item = TInstr::br(LabelIdx::new(1), [])
  let container = TInstr::if_(
    BlockType::void_(),
    TInstr::i32_const(I32(1)),
    TExpr::new([item]),
    Some(TExpr::new([TInstr::br(LabelIdx::new(1), [])])),
  )
  assert_false(can_move([item], container))
}

///|
test "can_move rejects moving throwing code across try_table" {
  let item = TInstr::throw_(TagIdx::new(0), [])
  let container = TInstr::try_table(BlockType::void_(), [], TExpr::new([item]))
  assert_false(can_move([item], container))
}

///|
test "cf_shift_outer_labels keeps folded-block targets and shifts outer targets" {
  let original = TInstr::if_(
    BlockType::void_(),
    TInstr::i32_const(I32(1)),
    TExpr::new([
      TInstr::br(LabelIdx::new(0), []),
      TInstr::br(LabelIdx::new(1), []),
      TInstr::br(LabelIdx::new(2), []),
      TInstr::br_table(
        [LabelIdx::new(0), LabelIdx::new(1), LabelIdx::new(2)],
        LabelIdx::new(3),
        TInstr::i32_const(I32(0)),
        [],
      ),
    ]),
    Some(
      TExpr::new([
        TInstr::try_table(
          BlockType::void_(),
          [Catch::all(LabelIdx::new(1)), Catch::all(LabelIdx::new(2))],
          TExpr::new([
            TInstr::br(LabelIdx::new(2), []),
            TInstr::br(LabelIdx::new(3), []),
          ]),
        ),
      ]),
    ),
  )
  let shifted = cf_shift_outer_labels(original)
  let expected = TInstr::if_(
    BlockType::void_(),
    TInstr::i32_const(I32(1)),
    TExpr::new([
      TInstr::br(LabelIdx::new(0), []),
      TInstr::br(LabelIdx::new(1), []),
      TInstr::br(LabelIdx::new(3), []),
      TInstr::br_table(
        [LabelIdx::new(0), LabelIdx::new(1), LabelIdx::new(3)],
        LabelIdx::new(4),
        TInstr::i32_const(I32(0)),
        [],
      ),
    ]),
    Some(
      TExpr::new([
        TInstr::try_table(
          BlockType::void_(),
          [Catch::all(LabelIdx::new(1)), Catch::all(LabelIdx::new(3))],
          TExpr::new([
            TInstr::br(LabelIdx::new(2), []),
            TInstr::br(LabelIdx::new(4), []),
          ]),
        ),
      ]),
    ),
  )
  assert_eq(shifted, expected)
}

// ============================================================
// Advanced Code Folding Tests
// ============================================================

///|
test "code folding: if-else with identical tails" {
  // Test:
  //   (if (condition)
  //     (block A C)
  //     (block B C)
  //   )
  // Should potentially fold C out
  let c_instr = TInstr::i32_const(I32(999)) // Common tail
  let then_body = TExpr::new([
    TInstr::i32_const(I32(1)), // A
    c_instr,
  ])
  let else_body = TExpr::new([
    TInstr::i32_const(I32(2)), // B
    TInstr::i32_const(I32(999)), // Same C (must be equal value)
  ])
  let if_instr = TInstr::if_(
    BlockType::void_(),
    TInstr::i32_const(I32(0)),
    then_body,
    Some(else_body),
  )
  let f = Func::t_func([], [], TExpr::new([if_instr]))
  let f2 = run_fold(f)
  // The pass should run without error
  match f2 {
    TFunc(_, _, { instrs: _, .. }) => ()
    _ => fail("expected TFunc")
  }
}

///|
test "code folding folds small if tails when parent is block" {
  let original = Func::t_func(
    [],
    [],
    TExpr::new([
      TInstr::block(
        BlockType::void_(),
        TExpr::new([
          TInstr::if_(
            BlockType::void_(),
            TInstr::i32_const(I32(0)),
            TExpr::new([
              TInstr::drop(TInstr::i32_const(I32(1))),
              TInstr::drop(TInstr::i32_const(I32(11))),
              TInstr::nop(),
            ]),
            Some(
              TExpr::new([
                TInstr::drop(TInstr::i32_const(I32(2))),
                TInstr::drop(TInstr::i32_const(I32(22))),
                TInstr::nop(),
              ]),
            ),
          ),
        ]),
      ),
    ]),
  )
  let folded = run_fold(original)
  assert_eq(
    cf_test_func_count_instrs(folded, fn(instr) {
      instr.kind is TInstrKind::TNop
    }),
    1,
  )
  cf_assert_func_body_typechecks(folded, [])
  assert_eq(validate_module(cf_test_module_for_func(folded, [])), Ok(()))
}

///|
test "code folding keeps small if tails duplicated at top level" {
  let original = Func::t_func(
    [],
    [],
    TExpr::new([
      TInstr::if_(
        BlockType::void_(),
        TInstr::i32_const(I32(0)),
        TExpr::new([
          TInstr::drop(TInstr::i32_const(I32(1))),
          TInstr::drop(TInstr::i32_const(I32(11))),
          TInstr::nop(),
        ]),
        Some(
          TExpr::new([
            TInstr::drop(TInstr::i32_const(I32(2))),
            TInstr::drop(TInstr::i32_const(I32(22))),
            TInstr::nop(),
          ]),
        ),
      ),
    ]),
  )
  let folded = run_fold(original)
  assert_eq(
    cf_test_func_count_instrs(folded, fn(instr) {
      instr.kind is TInstrKind::TNop
    }),
    2,
  )
  cf_assert_func_body_typechecks(folded, [])
  assert_eq(validate_module(cf_test_module_for_func(folded, [])), Ok(()))
}

///|
test "code folding hoists self-contained value-producing if tail" {
  let common = TInstr::i32_const(I32(999))
  let f = Func::t_func(
    [],
    [],
    TExpr::new([
      TInstr::if_(
        BlockType::val_type(ValType::i32()),
        TInstr::i32_const(I32(0)),
        TExpr::new([TInstr::nop(), common]),
        Some(TExpr::new([TInstr::drop(TInstr::i32_const(I32(1))), common])),
      ),
    ]),
  )
  let f2 = run_fold(f)
  let expected = Func::t_func(
    [],
    [],
    TExpr::new([
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::if_(
            BlockType::void_(),
            TInstr::i32_const(I32(0)),
            TExpr::new([TInstr::nop()]),
            Some(TExpr::new([TInstr::drop(TInstr::i32_const(I32(1)))])),
          ),
          common,
        ]),
      ),
    ]),
  )
  assert_eq(f2, expected)
}

///|
test "code folding hoisted if tail remains module-valid" {
  let common = TInstr::i32_const(I32(999))
  let folded = run_fold(
    Func::t_func(
      [],
      [],
      TExpr::new([
        TInstr::if_(
          BlockType::val_type(ValType::i32()),
          TInstr::i32_const(I32(0)),
          TExpr::new([TInstr::nop(), common]),
          Some(TExpr::new([TInstr::drop(TInstr::i32_const(I32(1))), common])),
        ),
      ]),
    ),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], [ValType::i32()]))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([folded]))
  assert_eq(validate_module(mod), Ok(()))
}

///|
test "code folding collapses empty-arm if to drop of condition" {
  let folded = run_fold(
    Func::t_func(
      [],
      [],
      TExpr::new([
        TInstr::if_(
          BlockType::void_(),
          TInstr::i32_const(I32(0)),
          TExpr::new([TInstr::drop(TInstr::i32_const(I32(9)))]),
          Some(TExpr::new([TInstr::drop(TInstr::i32_const(I32(9)))])),
        ),
      ]),
    ),
  )
  assert_false(
    cf_test_func_any_instr(folded, fn(instr) {
      instr.kind is TInstrKind::TIf(_, _, _, _)
    }),
  )
  assert_true(
    cf_test_func_any_instr(folded, fn(instr) {
      match instr.kind {
        TInstrKind::TDrop({ kind: TInstrKind::TI32Const(I32(0)), .. }) => true
        _ => false
      }
    }),
  )
}

///|
test "code folding keeps typed if valid when collapsing identical branch-only void arms" {
  let local0 = LocalIdx::new(0)
  let original = Func::t_func(
    [],
    [ValType::i32()],
    TExpr::new([
      TInstr::local_set(local0, TInstr::i32_const(I32(1))),
      TInstr::block(
        BlockType::void_(),
        TExpr::new([
          TInstr::block(
            BlockType::void_(),
            TExpr::new([
              TInstr::return_([
                TInstr::if_(
                  BlockType::val_type(ValType::i32()),
                  TInstr::i32_const(I32(0)),
                  TExpr::new([TInstr::i32_const(I32(7))]),
                  Some(
                    TExpr::new([
                      TInstr::if_(
                        BlockType::void_(),
                        TInstr::binary(
                          BinaryOp::i32_eq(),
                          TInstr::local_get(local0),
                          TInstr::i32_const(I32(1)),
                        ),
                        TExpr::new([
                          TInstr::drop(TInstr::local_get(local0)),
                          TInstr::br(LabelIdx::new(3), []),
                        ]),
                        Some(
                          TExpr::new([
                            TInstr::drop(TInstr::local_get(local0)),
                            TInstr::br(LabelIdx::new(3), []),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
      TInstr::i32_const(I32(2)),
    ]),
  )
  assert_eq(
    validate_module(cf_test_module_for_func(original, [ValType::i32()])),
    Ok(()),
  )
  let folded = run_fold_with_env(
    original,
    env=Env::new()
      .with_locals([ValType::i32()])
      .with_return_type(Some([ValType::i32()])),
  )
  cf_assert_func_body_typechecks(folded, [ValType::i32()])
  assert_eq(
    validate_module(cf_test_module_for_func(folded, [ValType::i32()])),
    Ok(()),
  )
}

///|
test "code folding does not collapse empty-arm if when merged tail branches outward" {
  let folded = run_fold(
    Func::t_func(
      [],
      [],
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::i32_const(I32(1)),
              TExpr::new([
                TInstr::drop(TInstr::i32_const(I32(9))),
                TInstr::br(LabelIdx::new(1), []),
              ]),
              Some(
                TExpr::new([
                  TInstr::drop(TInstr::i32_const(I32(9))),
                  TInstr::br(LabelIdx::new(1), []),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    ),
  )
  assert_true(
    cf_test_func_any_instr(folded, fn(instr) {
      instr.kind is TInstrKind::TIf(_, _, _, _)
    }),
  )
  assert_eq(validate_module(cf_test_module_for_func(folded, [])), Ok(()))
}

///|
test "code folding folded operand positions remain value-producing" {
  let common = TInstr::i32_const(I32(999))
  let folded = run_fold(
    Func::t_func(
      [],
      [ValType::i32()],
      TExpr::new([
        TInstr::if_(
          BlockType::val_type(ValType::i32()),
          TInstr::i32_const(I32(0)),
          TExpr::new([
            TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(7))),
            common,
          ]),
          Some(
            TExpr::new([
              TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(7))),
              common,
            ]),
          ),
        ),
      ]),
    ),
  )
  match folded {
    TFunc(params, locals, body) => {
      let env = Env::new()
        .with_locals(FunctionLocals::new(params, locals).all_locals())
        .with_return_type(Some([ValType::i32()]))
      cf_assert_operand_value_positions_expr(body, env, "func")
    }
    _ => fail("expected TFunc")
  }
  assert_eq(
    validate_module(cf_test_module_for_func(folded, [ValType::i32()])),
    Ok(()),
  )
}

///|
test "code folding hoisted void if tail rebases nested outer branches" {
  let common0 = TInstr::nop()
  let common1 = TInstr::drop(TInstr::i32_const(I32(11)))
  let common2 = TInstr::drop(TInstr::i32_const(I32(12)))
  let state = CodeFoldingState::{
    ..CodeFoldingState::new(env=Env::new().with_label([ValType::i32()])),
    another_pass: false,
  }
  let trace_ctx : CodeFoldingExprTraceCtx = {
    enabled: false,
    trace: cf_trace_noop,
    func_ordinal: 0,
    round: 0,
    site_kind: "",
  }
  let rewritten = process_if(
    state,
    BlockType::void_(),
    TInstr::i32_const(I32(1)),
    TExpr::new([
      TInstr::if_(
        BlockType::void_(),
        TInstr::i32_const(I32(1)),
        TExpr::new([TInstr::br(LabelIdx::new(2), [TInstr::i32_const(I32(7))])]),
        Some(TExpr::new([])),
      ),
      common0,
      common1,
      common2,
    ]),
    Some(
      TExpr::new([
        TInstr::drop(TInstr::i32_const(I32(1))),
        common0,
        common1,
        common2,
      ]),
    ),
    cf_round_trace_stats_new(),
    trace_ctx,
  )
  let expected = TInstr::block(
    BlockType::void_(),
    TExpr::new([
      TInstr::if_(
        BlockType::void_(),
        TInstr::i32_const(I32(1)),
        TExpr::new([
          TInstr::if_(
            BlockType::void_(),
            TInstr::i32_const(I32(1)),
            TExpr::new([
              TInstr::br(LabelIdx::new(3), [TInstr::i32_const(I32(7))]),
            ]),
            Some(TExpr::new([])),
          ),
        ]),
        Some(TExpr::new([TInstr::drop(TInstr::i32_const(I32(1)))])),
      ),
      common0,
      common1,
      common2,
    ]),
  )
  assert_eq(rewritten, Some(expected))
}

///|
test "code folding hoisted void if tail remains module-valid with nested outer branches" {
  let state = CodeFoldingState::{
    ..CodeFoldingState::new(env=Env::new().with_label([ValType::i32()])),
    another_pass: false,
  }
  let trace_ctx : CodeFoldingExprTraceCtx = {
    enabled: false,
    trace: cf_trace_noop,
    func_ordinal: 0,
    round: 0,
    site_kind: "",
  }
  let rewritten = match
    process_if(
      state,
      BlockType::void_(),
      TInstr::i32_const(I32(1)),
      TExpr::new([
        TInstr::if_(
          BlockType::void_(),
          TInstr::i32_const(I32(1)),
          TExpr::new([TInstr::br(LabelIdx::new(2), [TInstr::i32_const(I32(7))])]),
          Some(TExpr::new([])),
        ),
        TInstr::nop(),
        TInstr::drop(TInstr::i32_const(I32(11))),
        TInstr::drop(TInstr::i32_const(I32(12))),
      ]),
      Some(
        TExpr::new([
          TInstr::drop(TInstr::i32_const(I32(1))),
          TInstr::nop(),
          TInstr::drop(TInstr::i32_const(I32(11))),
          TInstr::drop(TInstr::i32_const(I32(12))),
        ]),
      ),
      cf_round_trace_stats_new(),
      trace_ctx,
    ) {
    Some(rewritten) => rewritten
    None => fail("expected if tail fold")
  }
  let folded = Func::t_func(
    [],
    [],
    TExpr::new([
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([rewritten, TInstr::i32_const(I32(9))]),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], [ValType::i32()]))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([folded]))
  assert_eq(validate_module(mod), Ok(()))
}

///|
test "code folding hoisted if tail rebases cond outer branches" {
  let common = TInstr::i32_const(I32(9))
  let state = CodeFoldingState::{
    ..CodeFoldingState::new(env=Env::new().with_label([ValType::i32()])),
    another_pass: false,
  }
  let trace_ctx : CodeFoldingExprTraceCtx = {
    enabled: false,
    trace: cf_trace_noop,
    func_ordinal: 0,
    round: 0,
    site_kind: "",
  }
  let rewritten = process_if(
    state,
    BlockType::val_type(ValType::i32()),
    TInstr::block(
      BlockType::val_type(ValType::i32()),
      TExpr::new([TInstr::br(LabelIdx::new(1), [TInstr::i32_const(I32(1))])]),
    ),
    TExpr::new([TInstr::nop(), common]),
    Some(TExpr::new([TInstr::drop(TInstr::i32_const(I32(2))), common])),
    cf_round_trace_stats_new(),
    trace_ctx,
  )
  let expected = TInstr::block(
    BlockType::val_type(ValType::i32()),
    TExpr::new([
      TInstr::if_(
        BlockType::void_(),
        TInstr::block(
          BlockType::val_type(ValType::i32()),
          TExpr::new([TInstr::br(LabelIdx::new(2), [TInstr::i32_const(I32(1))])]),
        ),
        TExpr::new([TInstr::nop()]),
        Some(TExpr::new([TInstr::drop(TInstr::i32_const(I32(2)))])),
      ),
      common,
    ]),
  )
  assert_eq(rewritten, Some(expected))
}

///|
test "code folding hoists block tail targeted by nested br" {
  let common = TInstr::i32_const(I32(999))
  let f = Func::t_func(
    [],
    [],
    TExpr::new([
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::if_(
            BlockType::void_(),
            TInstr::i32_const(I32(1)),
            TExpr::new([TInstr::nop(), TInstr::br(LabelIdx::new(1), [common])]),
            Some(TExpr::new([])),
          ),
          common,
        ]),
      ),
    ]),
  )
  let f2 = run_fold(f)
  match f2 {
    TFunc(_, locals, _) => {
      assert_eq(locals.length(), 1)
      assert_true(cf_test_func_has_local_set(f2, LocalIdx::new(0)))
      assert_true(cf_test_func_has_local_get(f2, LocalIdx::new(0)))
      assert_false(cf_test_func_has_branch_value(f2))
    }
    _ => fail("expected TFunc")
  }
}

///|
test "code folding block hoist remains module-valid" {
  let common = TInstr::i32_const(I32(999))
  let folded = run_fold(
    Func::t_func(
      [],
      [],
      TExpr::new([
        TInstr::block(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::i32_const(I32(1)),
              TExpr::new([TInstr::nop(), TInstr::br(LabelIdx::new(1), [common])]),
              Some(TExpr::new([])),
            ),
            common,
          ]),
        ),
      ]),
    ),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], [ValType::i32()]))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([folded]))
  assert_eq(validate_module(mod), Ok(()))
}

///|
test "code folding nested block hoist remains module-valid with outer labels" {
  let common = TInstr::i32_const(I32(999))
  let folded = run_fold(
    Func::t_func(
      [],
      [],
      TExpr::new([
        TInstr::block(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::block(
              BlockType::val_type(ValType::i32()),
              TExpr::new([
                TInstr::if_(
                  BlockType::void_(),
                  TInstr::i32_const(I32(1)),
                  TExpr::new([
                    TInstr::nop(),
                    TInstr::br(LabelIdx::new(2), [common]),
                  ]),
                  Some(TExpr::new([])),
                ),
                common,
              ]),
            ),
          ]),
        ),
      ]),
    ),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], [ValType::i32()]))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([folded]))
  assert_eq(validate_module(mod), Ok(()))
}

///|
test "code folding block hoist rebases nested cond outer branches" {
  let common = TInstr::i32_const(I32(999))
  let original = Func::t_func(
    [],
    [],
    TExpr::new([
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::if_(
            BlockType::void_(),
            TInstr::block(
              BlockType::val_type(ValType::i32()),
              TExpr::new([
                TInstr::br(LabelIdx::new(1), [TInstr::i32_const(I32(1))]),
              ]),
            ),
            TExpr::new([TInstr::nop(), TInstr::br(LabelIdx::new(1), [common])]),
            Some(TExpr::new([])),
          ),
          common,
        ]),
      ),
    ]),
  )
  let folded = run_fold(original)
  match folded {
    TFunc(_, locals, _) => {
      assert_eq(locals.length(), 1)
      assert_true(cf_test_func_has_local_set(folded, LocalIdx::new(0)))
      assert_true(cf_test_func_has_local_get(folded, LocalIdx::new(0)))
      assert_true(cf_test_func_has_branch_target(folded, LabelIdx::new(3), 1))
    }
    _ => fail("expected TFunc")
  }
}

///|
test "code folding block hoist with nested cond remains module-valid" {
  let common = TInstr::i32_const(I32(999))
  let folded = run_fold(
    Func::t_func(
      [],
      [],
      TExpr::new([
        TInstr::block(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::block(
                BlockType::val_type(ValType::i32()),
                TExpr::new([
                  TInstr::br(LabelIdx::new(1), [TInstr::i32_const(I32(1))]),
                ]),
              ),
              TExpr::new([TInstr::nop(), TInstr::br(LabelIdx::new(1), [common])]),
              Some(TExpr::new([])),
            ),
            common,
          ]),
        ),
      ]),
    ),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], [ValType::i32()]))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([folded]))
  assert_eq(validate_module(mod), Ok(()))
}

///|
test "code folding nested if hoist remains module-valid with outer labels" {
  let folded = run_fold(
    Func::t_func(
      [],
      [],
      TExpr::new([
        TInstr::block(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::i32_const(I32(1)),
              TExpr::new([
                TInstr::if_(
                  BlockType::void_(),
                  TInstr::i32_const(I32(1)),
                  TExpr::new([
                    TInstr::br(LabelIdx::new(2), [TInstr::i32_const(I32(7))]),
                  ]),
                  Some(TExpr::new([])),
                ),
                TInstr::nop(),
                TInstr::drop(TInstr::i32_const(I32(11))),
                TInstr::drop(TInstr::i32_const(I32(12))),
              ]),
              Some(
                TExpr::new([
                  TInstr::drop(TInstr::i32_const(I32(1))),
                  TInstr::nop(),
                  TInstr::drop(TInstr::i32_const(I32(11))),
                  TInstr::drop(TInstr::i32_const(I32(12))),
                ]),
              ),
            ),
            TInstr::i32_const(I32(9)),
          ]),
        ),
      ]),
    ),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], [ValType::i32()]))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([folded]))
  assert_eq(validate_module(mod), Ok(()))
}

///|
test "code folding terminating tails do not mutate shared unreachable arrays" {
  let shared_tail = [
    TInstr::drop(TInstr::i32_const(I32(1))),
    TInstr::unreachable_(),
  ]
  let func_body = [
    TInstr::block(BlockType::void_(), TExpr::new(shared_tail)),
    TInstr::block(BlockType::void_(), TExpr::new(shared_tail)),
  ]
  let tails = [
    {
      tail: Tail::branch(shared_tail[shared_tail.length() - 1], shared_tail),
      path: [BlockBody(0)],
      exact_index: None,
    },
    {
      tail: Tail::branch(shared_tail[shared_tail.length() - 1], shared_tail),
      path: [BlockBody(1)],
      exact_index: None,
    },
  ]
  let result = optimize_terminating_tails(
    CodeFoldingState::new(),
    tails,
    func_body,
    cf_round_trace_stats_new(),
  )
  assert_eq(shared_tail.length(), 2)
  let folded_body = match result {
    Some(body) => body
    None => fail("expected unreachable tails to fold")
  }
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([Func::t_func([], [], TExpr::new(folded_body))]),
    )
  assert_eq(validate_module(mod), Ok(()))
}

///|
test "code folding terminating return tails preserve typed if results" {
  let original = Func::t_func(
    [],
    [],
    TExpr::new([
      TInstr::if_(
        BlockType::val_type(ValType::i32()),
        TInstr::i32_const(I32(0)),
        TExpr::new([TInstr::i32_const(I32(1)), TInstr::return_([])]),
        Some(TExpr::new([TInstr::i32_const(I32(1)), TInstr::return_([])])),
      ),
    ]),
  )
  assert_eq(
    validate_module(cf_test_module_for_func(original, [ValType::i32()])),
    Ok(()),
  )
  let folded = run_fold_with_env(
    original,
    env=Env::new().with_return_type(Some([ValType::i32()])),
  )
  cf_assert_func_body_typechecks(folded, [ValType::i32()])
  assert_eq(
    validate_module(cf_test_module_for_func(folded, [ValType::i32()])),
    Ok(()),
  )
}

///|
test "code folding terminating return tails spill differing values via temps" {
  let original = Func::t_func(
    [],
    [],
    TExpr::new([
      TInstr::if_(
        BlockType::void_(),
        TInstr::i32_const(I32(0)),
        TExpr::new([
          TInstr::drop(TInstr::i32_const(I32(9))),
          TInstr::return_([TInstr::i32_const(I32(1))]),
        ]),
        Some(
          TExpr::new([
            TInstr::drop(TInstr::i32_const(I32(9))),
            TInstr::return_([TInstr::i32_const(I32(2))]),
          ]),
        ),
      ),
    ]),
  )
  assert_eq(
    validate_module(cf_test_module_for_func(original, [ValType::i32()])),
    Ok(()),
  )
  let folded = run_fold_with_env(
    original,
    env=Env::new().with_return_type(Some([ValType::i32()])),
  )
  match folded {
    TFunc(_, locals, _) => {
      assert_eq(locals.length(), 1)
      assert_true(cf_test_func_has_local_set(folded, LocalIdx::new(0)))
      assert_true(cf_test_func_has_local_get(folded, LocalIdx::new(0)))
    }
    _ => fail("expected TFunc")
  }
  cf_assert_func_body_typechecks(folded, [ValType::i32()])
  assert_eq(
    validate_module(cf_test_module_for_func(folded, [ValType::i32()])),
    Ok(()),
  )
}

///|
test "code folding terminating throw tails spill differing payloads for same tag" {
  let tag_payload_ty = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], []))),
        tag_payload_ty,
      ]),
    )
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(1))]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::i32_const(I32(0)),
              TExpr::new([
                TInstr::drop(TInstr::i32_const(I32(9))),
                TInstr::throw_(TagIdx::new(0), [TInstr::i32_const(I32(1))]),
              ]),
              Some(
                TExpr::new([
                  TInstr::drop(TInstr::i32_const(I32(9))),
                  TInstr::throw_(TagIdx::new(0), [TInstr::i32_const(I32(2))]),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let folded = cf_run_fold_module(mod)
  let folded_func = folded.code_sec.unwrap().0[0]
  assert_true(
    cf_test_func_has_local_set(folded_func, LocalIdx::new(0)),
    msg="expected thrown payload to be spilled into temp local",
  )
  assert_true(
    cf_test_func_has_local_get(folded_func, LocalIdx::new(0)),
    msg="expected shared throw tail to reload spilled payload",
  )
  assert_eq(validate_module(folded), Ok(()))
}

///|
test "code folding terminating throw_ref tails spill differing refs via temp" {
  let exn_ht = HeapType::abs(AbsHeapType::exn())
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [ValType::ref_null_exn()],
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::i32_const(I32(0)),
              TExpr::new([
                TInstr::drop(TInstr::i32_const(I32(9))),
                TInstr::throw_ref(TInstr::ref_null(exn_ht)),
              ]),
              Some(
                TExpr::new([
                  TInstr::drop(TInstr::i32_const(I32(9))),
                  TInstr::throw_ref(TInstr::local_get(LocalIdx::new(0))),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let folded = cf_run_fold_module(mod)
  let folded_func = folded.code_sec.unwrap().0[0]
  assert_true(
    cf_test_func_has_local_set(folded_func, LocalIdx::new(1)),
    msg="expected throw_ref payload to spill into temp local",
  )
  assert_true(
    cf_test_func_has_local_get(folded_func, LocalIdx::new(1)),
    msg="expected shared throw_ref tail to reload temp payload",
  )
  assert_eq(validate_module(folded), Ok(()))
}

///|
test "code folding module pass can fold throw then return tails in same round" {
  let tag_payload_ty = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], [ValType::i32()]))),
        tag_payload_ty,
      ]),
    )
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(1))]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::i32_const(I32(0)),
              TExpr::new([
                TInstr::drop(TInstr::i32_const(I32(9))),
                TInstr::drop(TInstr::i32_const(I32(10))),
                TInstr::throw_(TagIdx::new(0), [TInstr::i32_const(I32(1))]),
              ]),
              Some(
                TExpr::new([
                  TInstr::drop(TInstr::i32_const(I32(9))),
                  TInstr::drop(TInstr::i32_const(I32(10))),
                  TInstr::throw_(TagIdx::new(0), [TInstr::i32_const(I32(2))]),
                ]),
              ),
            ),
            TInstr::if_(
              BlockType::void_(),
              TInstr::i32_const(I32(1)),
              TExpr::new([
                TInstr::drop(TInstr::i32_const(I32(3))),
                TInstr::drop(TInstr::i32_const(I32(4))),
                TInstr::return_([TInstr::i32_const(I32(11))]),
              ]),
              Some(
                TExpr::new([
                  TInstr::drop(TInstr::i32_const(I32(3))),
                  TInstr::drop(TInstr::i32_const(I32(4))),
                  TInstr::return_([TInstr::i32_const(I32(12))]),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    )
  let trace_lines = []
  let folded = match
    code_folding_ir_pass_with_trace(mod, trace=fn(msg) { trace_lines.push(msg) }).walk_module(
      IRContext::new(),
      mod,
    ) {
    Ok((next_mod, _)) => next_mod
    Err(e) => fail("code folding module pass failed: " + e)
  }
  assert_true(
    trace_lines.any(fn(msg) {
      msg.contains("round[1] terminating_unreachable") &&
      msg.contains("changed=true")
    }),
    msg="expected unreachable phase change in round 1",
  )
  assert_true(
    trace_lines.any(fn(msg) {
      msg.contains("round[1] terminating_returns") &&
      msg.contains("changed=true")
    }),
    msg="expected return phase change in round 1",
  )
  assert_eq(validate_module(folded), Ok(()))
}

///|
test "code folding terminating throw tails preserve nested branch depths" {
  let tag_payload_ty = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], []))),
        tag_payload_ty,
      ]),
    )
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(1))]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::if_(
                  BlockType::void_(),
                  TInstr::i32_const(I32(0)),
                  TExpr::new([
                    TInstr::drop(TInstr::i32_const(I32(9))),
                    TInstr::block(
                      BlockType::void_(),
                      TExpr::new([TInstr::br(LabelIdx::new(0), [])]),
                    ),
                    TInstr::throw_(TagIdx::new(0), [TInstr::i32_const(I32(1))]),
                  ]),
                  Some(
                    TExpr::new([
                      TInstr::drop(TInstr::i32_const(I32(9))),
                      TInstr::block(
                        BlockType::void_(),
                        TExpr::new([TInstr::br(LabelIdx::new(0), [])]),
                      ),
                      TInstr::throw_(TagIdx::new(0), [TInstr::i32_const(I32(2))]),
                    ]),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let folded = cf_run_fold_module(mod)
  let folded_func = folded.code_sec.unwrap().0[0]
  assert_true(
    cf_test_func_count_instrs(folded_func, fn(instr) {
      match instr.kind {
        TInstrKind::TBr(_, values) => values.is_empty()
        _ => false
      }
    }) >
    0,
  )
  assert_eq(validate_module(folded), Ok(()))
}

///|
test "code folding keeps throw-tail spilling conservative for TryBody tails" {
  let tag_payload_ty = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], []))),
        tag_payload_ty,
      ]),
    )
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(1))]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::try_table(
              BlockType::void_(),
              [Catch::all(LabelIdx::new(0))],
              TExpr::new([
                TInstr::if_(
                  BlockType::void_(),
                  TInstr::i32_const(I32(0)),
                  TExpr::new([
                    TInstr::drop(TInstr::i32_const(I32(9))),
                    TInstr::throw_(TagIdx::new(0), [TInstr::i32_const(I32(1))]),
                  ]),
                  Some(
                    TExpr::new([
                      TInstr::drop(TInstr::i32_const(I32(9))),
                      TInstr::throw_(TagIdx::new(0), [TInstr::i32_const(I32(2))]),
                    ]),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let folded = cf_run_fold_module(mod)
  let folded_func = folded.code_sec.unwrap().0[0]
  assert_eq(
    cf_test_func_count_instrs(folded_func, fn(instr) {
      instr.kind is TInstrKind::TThrow(_, _)
    }),
    2,
  )
  assert_true(not(cf_test_func_has_local_set(folded_func, LocalIdx::new(0))))
  assert_true(not(cf_test_func_has_local_get(folded_func, LocalIdx::new(0))))
  assert_eq(validate_module(folded), Ok(()))
}

///|
test "code folding allows throw-tail spill for TryBody tails with empty catches" {
  let tag_payload_ty = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], []))),
        tag_payload_ty,
      ]),
    )
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(1))]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::try_table(
              BlockType::void_(),
              [],
              TExpr::new([
                TInstr::if_(
                  BlockType::void_(),
                  TInstr::i32_const(I32(0)),
                  TExpr::new([
                    TInstr::drop(TInstr::i32_const(I32(9))),
                    TInstr::throw_(TagIdx::new(0), [TInstr::i32_const(I32(1))]),
                  ]),
                  Some(
                    TExpr::new([
                      TInstr::drop(TInstr::i32_const(I32(9))),
                      TInstr::throw_(TagIdx::new(0), [TInstr::i32_const(I32(2))]),
                    ]),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let folded = cf_run_fold_module(mod)
  let folded_func = folded.code_sec.unwrap().0[0]
  assert_true(cf_test_func_has_local_set(folded_func, LocalIdx::new(0)))
  assert_true(cf_test_func_has_local_get(folded_func, LocalIdx::new(0)))
  assert_eq(validate_module(folded), Ok(()))
}

///|
test "code folding allows TryBody throw folding when catches do not match throw tag" {
  let void_sig = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([void_sig]))
    .with_tag_sec(
      TagSec::new([TagType::new(TypeIdx::new(0)), TagType::new(TypeIdx::new(0))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::try_table(
              BlockType::void_(),
              [Catch::new(TagIdx::new(0), LabelIdx::new(0))],
              TExpr::new([
                TInstr::if_(
                  BlockType::void_(),
                  TInstr::i32_const(I32(0)),
                  TExpr::new([
                    TInstr::drop(TInstr::i32_const(I32(9))),
                    TInstr::drop(TInstr::i32_const(I32(10))),
                    TInstr::drop(TInstr::i32_const(I32(11))),
                    TInstr::throw_(TagIdx::new(1), []),
                  ]),
                  Some(
                    TExpr::new([
                      TInstr::drop(TInstr::i32_const(I32(9))),
                      TInstr::drop(TInstr::i32_const(I32(10))),
                      TInstr::drop(TInstr::i32_const(I32(11))),
                      TInstr::throw_(TagIdx::new(1), []),
                    ]),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let folded = cf_run_fold_module(mod)
  let folded_func = folded.code_sec.unwrap().0[0]
  assert_eq(
    cf_test_func_count_instrs(folded_func, fn(instr) {
      instr.kind is TInstrKind::TThrow(_, _)
    }),
    1,
  )
  assert_true(
    cf_test_func_count_instrs(folded_func, fn(instr) {
      match instr.kind {
        TInstrKind::TBr(_, values) => values.is_empty()
        _ => false
      }
    }) >
    0,
  )
  assert_eq(validate_module(folded), Ok(()))
}

///|
test "code folding allows throw-tail spill when try_table follows throw sites" {
  let tag_payload_ty = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], []))),
        tag_payload_ty,
      ]),
    )
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(1))]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::i32_const(I32(0)),
              TExpr::new([
                TInstr::drop(TInstr::i32_const(I32(9))),
                TInstr::throw_(TagIdx::new(0), [TInstr::i32_const(I32(1))]),
              ]),
              Some(
                TExpr::new([
                  TInstr::drop(TInstr::i32_const(I32(9))),
                  TInstr::throw_(TagIdx::new(0), [TInstr::i32_const(I32(2))]),
                ]),
              ),
            ),
            TInstr::try_table(
              BlockType::void_(),
              [],
              TExpr::new([TInstr::nop()]),
            ),
          ]),
        ),
      ]),
    )
  let folded = cf_run_fold_module(mod)
  let folded_func = folded.code_sec.unwrap().0[0]
  assert_true(cf_test_func_has_local_set(folded_func, LocalIdx::new(0)))
  assert_true(cf_test_func_has_local_get(folded_func, LocalIdx::new(0)))
  assert_eq(validate_module(folded), Ok(()))
}

///|
test "code folding allows throw-tail spill when try_table is before throw sites" {
  let tag_payload_ty = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], []))),
        tag_payload_ty,
      ]),
    )
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(1))]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::try_table(
              BlockType::void_(),
              [],
              TExpr::new([TInstr::nop()]),
            ),
            TInstr::if_(
              BlockType::void_(),
              TInstr::i32_const(I32(0)),
              TExpr::new([
                TInstr::drop(TInstr::i32_const(I32(9))),
                TInstr::throw_(TagIdx::new(0), [TInstr::i32_const(I32(1))]),
              ]),
              Some(
                TExpr::new([
                  TInstr::drop(TInstr::i32_const(I32(9))),
                  TInstr::throw_(TagIdx::new(0), [TInstr::i32_const(I32(2))]),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    )
  let folded = cf_run_fold_module(mod)
  let folded_func = folded.code_sec.unwrap().0[0]
  assert_true(cf_test_func_has_local_set(folded_func, LocalIdx::new(0)))
  assert_true(cf_test_func_has_local_get(folded_func, LocalIdx::new(0)))
  assert_eq(validate_module(folded), Ok(()))
}

///|
test "code folding throw spill planning can infer payload types without tag signature lookup" {
  let body1 = [
    TInstr::drop(TInstr::i32_const(I32(9))),
    TInstr::drop(TInstr::i32_const(I32(10))),
    TInstr::throw_(TagIdx::new(0), [TInstr::i32_const(I32(1))]),
  ]
  let body2 = [
    TInstr::drop(TInstr::i32_const(I32(9))),
    TInstr::drop(TInstr::i32_const(I32(10))),
    TInstr::throw_(TagIdx::new(0), [TInstr::i32_const(I32(2))]),
  ]
  let tails : Array[ScopedTail] = [
    {
      tail: Tail::branch(body1[body1.length() - 1], body1),
      path: [BlockBody(0)],
      exact_index: None,
    },
    {
      tail: Tail::branch(body2[body2.length() - 1], body2),
      path: [BlockBody(1)],
      exact_index: None,
    },
  ]
  let plan = cf_build_terminating_tail_plan(
    CodeFoldingState::new(env=Env::new()),
    tails,
    cf_round_trace_stats_new(),
  )
  match plan {
    Some(plan) => {
      assert_eq(plan.temp_local_types, [ValType::i32()])
      assert_eq(plan.temp_locals.length(), 1)
      assert_true(
        cf_instr_may_throw(
          plan.shared_tail_instrs[plan.shared_tail_instrs.length() - 1],
        ),
      )
    }
    None => fail("expected throw spill plan via inferred payload types")
  }
}

///|
test "code folding groups terminating throw tails by tag and payload arity" {
  let mk_tail = fn(value_count : Int, seed : Int, path_idx : Int) {
    let values : Array[TInstr] = []
    let mut i = 0
    while i < value_count {
      values.push(TInstr::i32_const(I32(seed + i)))
      i += 1
    }
    let body = [
      TInstr::drop(TInstr::i32_const(I32(9))),
      TInstr::throw_(TagIdx::new(0), values),
    ]
    {
      tail: Tail::branch(body[body.length() - 1], body),
      path: [BlockBody(path_idx)],
      exact_index: None,
    }
  }
  let tails : Array[ScopedTail] = [
    mk_tail(1, 1, 0),
    mk_tail(1, 2, 1),
    mk_tail(2, 3, 2),
  ]
  let groups = cf_group_terminating_tails(tails, 0, cf_round_trace_stats_new())
  assert_eq(groups.length(), 1)
  assert_eq(groups[0].length(), 2)
}

///|
test "code folding folds non-tail returns in same body" {
  let shared_value = TInstr::block(
    BlockType::val_type(ValType::i32()),
    TExpr::new([
      TInstr::drop(TInstr::i32_const(I32(9))),
      TInstr::drop(TInstr::i32_const(I32(10))),
      TInstr::i32_const(I32(7)),
    ]),
  )
  let original = Func::t_func(
    [],
    [],
    TExpr::new([
      TInstr::return_([shared_value]),
      TInstr::drop(TInstr::i32_const(I32(3))),
      TInstr::return_([shared_value]),
    ]),
  )
  let folded = run_fold_with_env(
    original,
    env=Env::new().with_return_type(Some([ValType::i32()])),
  )
  assert_eq(
    cf_test_func_count_instrs(folded, fn(instr) {
      instr.kind is TInstrKind::TReturn(_)
    }),
    1,
  )
  assert_true(cf_test_func_has_branch_target(folded, LabelIdx::new(0), 0))
  cf_assert_func_body_typechecks(folded, [ValType::i32()])
  assert_eq(
    validate_module(cf_test_module_for_func(folded, [ValType::i32()])),
    Ok(()),
  )
}

///|
test "code folding keeps temp locals when return folding skips expr walk" {
  let mk_value = fn(seed : Int) {
    TInstr::block(
      BlockType::val_type(ValType::i32()),
      TExpr::new([
        TInstr::drop(TInstr::i32_const(I32(seed))),
        TInstr::drop(TInstr::i32_const(I32(seed + 1))),
        TInstr::i32_const(I32(seed + 2)),
      ]),
    )
  }
  let original = Func::t_func(
    [],
    [],
    TExpr::new([
      TInstr::return_([mk_value(10), mk_value(20)]),
      TInstr::drop(TInstr::i32_const(I32(3))),
      TInstr::return_([mk_value(30), mk_value(40)]),
    ]),
  )
  let folded = run_fold_with_env(
    original,
    env=Env::new().with_return_type(Some([ValType::i32(), ValType::i32()])),
  )
  match folded {
    TFunc(_, locals, _) => assert_eq(locals.length(), 2)
    _ => fail("expected TFunc")
  }
  cf_assert_func_body_typechecks(folded, [ValType::i32(), ValType::i32()])
  assert_eq(
    validate_module(
      cf_test_module_for_func(folded, [ValType::i32(), ValType::i32()]),
    ),
    Ok(()),
  )
}

///|
test "code folding terminating tails finds profitable subsets" {
  let original = Func::t_func(
    [],
    [],
    TExpr::new([
      TInstr::if_(
        BlockType::void_(),
        TInstr::i32_const(I32(0)),
        TExpr::new([
          TInstr::drop(TInstr::i32_const(I32(9))),
          TInstr::return_([TInstr::i32_const(I32(1))]),
        ]),
        Some(
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::i32_const(I32(0)),
              TExpr::new([
                TInstr::drop(TInstr::i32_const(I32(9))),
                TInstr::return_([TInstr::i32_const(I32(2))]),
              ]),
              Some(
                TExpr::new([
                  TInstr::drop(TInstr::i32_const(I32(3))),
                  TInstr::return_([TInstr::i32_const(I32(3))]),
                ]),
              ),
            ),
          ]),
        ),
      ),
    ]),
  )
  let folded = run_fold_with_env(
    original,
    env=Env::new().with_return_type(Some([ValType::i32()])),
  )
  match folded {
    TFunc(_, locals, _) => {
      assert_eq(locals.length(), 1)
      assert_true(cf_test_func_has_local_set(folded, LocalIdx::new(0)))
      assert_true(cf_test_func_has_local_get(folded, LocalIdx::new(0)))
    }
    _ => fail("expected TFunc")
  }
  cf_assert_func_body_typechecks(folded, [ValType::i32()])
  assert_eq(
    validate_module(cf_test_module_for_func(folded, [ValType::i32()])),
    Ok(()),
  )
}

///|
test "code folding terminating-tail grouping keeps pathological scans bounded" {
  let tail_count = 64
  let func_body : Array[TInstr] = []
  let tails : Array[ScopedTail] = []
  let mut i = 0
  while i < tail_count {
    let branch_body = [TInstr::i32_const(I32(i)), TInstr::return_([])]
    func_body.push(TInstr::block(BlockType::void_(), TExpr::new(branch_body)))
    tails.push({
      tail: Tail::branch(branch_body[branch_body.length() - 1], branch_body),
      path: [BlockBody(i)],
      exact_index: None,
    })
    i += 1
  }
  let trace_stats = cf_round_trace_stats_new()
  ignore(
    optimize_terminating_tails(
      CodeFoldingState::new(env=Env::new().with_return_type(Some([]))),
      tails,
      func_body,
      trace_stats,
    ),
  )
  assert_true(
    trace_stats.terminating_group_pair_checks <= tail_count * 6,
    msg="expected terminating-tail grouping guard to bound pair checks, got \{trace_stats.terminating_group_pair_checks}",
  )
}

///|
test "code folding terminating return tails preserve nested branch depths" {
  let original = Func::t_func(
    [],
    [],
    TExpr::new([
      TInstr::block(
        BlockType::void_(),
        TExpr::new([
          TInstr::if_(
            BlockType::void_(),
            TInstr::i32_const(I32(0)),
            TExpr::new([
              TInstr::drop(TInstr::i32_const(I32(9))),
              TInstr::return_([TInstr::i32_const(I32(1))]),
            ]),
            Some(
              TExpr::new([
                TInstr::drop(TInstr::i32_const(I32(9))),
                TInstr::return_([TInstr::i32_const(I32(2))]),
              ]),
            ),
          ),
        ]),
      ),
    ]),
  )
  let folded = run_fold_with_env(
    original,
    env=Env::new().with_return_type(Some([ValType::i32()])),
  )
  cf_assert_func_body_typechecks(folded, [ValType::i32()])
  assert_eq(
    validate_module(cf_test_module_for_func(folded, [ValType::i32()])),
    Ok(()),
  )
}

///|
test "code folding hoists branch-value block tails via temp local" {
  let common = TInstr::i32_const(I32(999))
  let folded = run_fold(
    Func::t_func(
      [],
      [],
      TExpr::new([
        TInstr::block(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::i32_const(I32(1)),
              TExpr::new([TInstr::nop(), TInstr::br(LabelIdx::new(1), [common])]),
              Some(TExpr::new([])),
            ),
            common,
          ]),
        ),
      ]),
    ),
  )
  match folded {
    TFunc(_, locals, _) => {
      assert_eq(locals.length(), 1)
      assert_true(cf_test_func_has_local_set(folded, LocalIdx::new(0)))
      assert_true(cf_test_func_has_local_get(folded, LocalIdx::new(0)))
      assert_false(cf_test_func_has_branch_value(folded))
    }
    _ => fail("expected TFunc")
  }
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], [ValType::i32()]))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([folded]))
  assert_eq(validate_module(mod), Ok(()))
}

///|
test "code folding terminating unreachable tails preserve typed if results" {
  let original = Func::t_func(
    [],
    [],
    TExpr::new([
      TInstr::if_(
        BlockType::val_type(ValType::i32()),
        TInstr::i32_const(I32(0)),
        TExpr::new([
          TInstr::drop(TInstr::i32_const(I32(1))),
          TInstr::unreachable_(),
        ]),
        Some(
          TExpr::new([
            TInstr::drop(TInstr::i32_const(I32(1))),
            TInstr::unreachable_(),
          ]),
        ),
      ),
    ]),
  )
  assert_eq(
    validate_module(cf_test_module_for_func(original, [ValType::i32()])),
    Ok(()),
  )
  let folded = run_fold(original)
  cf_assert_func_body_typechecks(folded, [ValType::i32()])
  assert_eq(
    validate_module(cf_test_module_for_func(folded, [ValType::i32()])),
    Ok(()),
  )
}

///|
test "code folding terminating return tails do not mutate shared value arrays" {
  let shared_tail = [
    TInstr::drop(TInstr::i32_const(I32(1))),
    TInstr::drop(TInstr::i32_const(I32(2))),
    TInstr::i32_const(I32(7)),
    TInstr::return_([]),
  ]
  let func_body = [
    TInstr::block(BlockType::void_(), TExpr::new(shared_tail)),
    TInstr::block(BlockType::void_(), TExpr::new(shared_tail)),
  ]
  let tails = [
    {
      tail: Tail::branch(shared_tail[shared_tail.length() - 1], shared_tail),
      path: [BlockBody(0)],
      exact_index: None,
    },
    {
      tail: Tail::branch(shared_tail[shared_tail.length() - 1], shared_tail),
      path: [BlockBody(1)],
      exact_index: None,
    },
  ]
  let result = optimize_terminating_tails(
    CodeFoldingState::new(
      env=Env::new().with_return_type(Some([ValType::i32()])),
    ),
    tails,
    func_body,
    cf_round_trace_stats_new(),
  )
  assert_eq(shared_tail.length(), 4)
  let folded_body = match result {
    Some(body) => body
    None => fail("expected return tails to fold")
  }
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], [ValType::i32()]))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([Func::t_func([], [], TExpr::new(folded_body))]),
    )
  assert_eq(validate_module(mod), Ok(()))
}

///|
test "optimize_terminating_tails rejects stale scoped return tails after body rewrite" {
  let state = CodeFoldingState::new(
    env=Env::new().with_return_type(Some([ValType::i32()])),
  )
  let original_body = [
    TInstr::if_(
      BlockType::void_(),
      TInstr::i32_const(I32(0)),
      TExpr::new([
        TInstr::drop(TInstr::i32_const(I32(10))),
        TInstr::return_([TInstr::i32_const(I32(1))]),
      ]),
      Some(
        TExpr::new([
          TInstr::drop(TInstr::i32_const(I32(10))),
          TInstr::return_([TInstr::i32_const(I32(2))]),
        ]),
      ),
    ),
  ]
  collect_block_tails(state, original_body, cf_round_trace_stats_new())
  let stale_return_tails = state.return_tails.copy()
  let shifted_body = [
    TInstr::block(BlockType::void_(), TExpr::new(original_body)),
    TInstr::unreachable_(),
  ]
  let result = optimize_terminating_tails(
    state,
    stale_return_tails,
    shifted_body,
    cf_round_trace_stats_new(),
  )
  assert_eq(result, None)
}

///|
test "preview_appended_local uses TFunc full-local index space" {
  let params = [ValType::i32(), ValType::i32(), ValType::i32()]
  let func_locals = params + [ValType::i32()]
  let state = CodeFoldingState::new(
    env=Env::new().with_locals(func_locals),
    param_types=params,
    func_locals~,
  )
  let (idx, next_locals, next_env) = state.preview_appended_local(
    ValType::i32(),
  )
  assert_eq(idx, LocalIdx::new(4))
  assert_eq(next_locals.length(), 5)
  assert_eq(next_env.get_local_type(LocalIdx::new(4)), Some(ValType::i32()))
  assert_eq(next_env.get_local_type(LocalIdx::new(5)), None)
}

///|
test "code folding module pass keeps params and locals separated" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(
          SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [ValType::i64()],
          TExpr::new([TInstr::return_([TInstr::local_get(LocalIdx::new(0))])]),
        ),
      ]),
    )
  let folded = cf_run_fold_module(mod)
  match folded.code_sec {
    Some(CodeSec([TFunc(params, locals, _)])) => {
      assert_eq(params, [ValType::i32()])
      assert_eq(locals, [ValType::i64()])
    }
    _ => fail("expected folded module to contain one typed function")
  }
}

///|
test "code folding module pass keeps params-local indexing valid across terminating phases" {
  let body = TExpr::new([
    TInstr::if_(
      BlockType::void_(),
      TInstr::local_get(LocalIdx::new(0)),
      TExpr::new([
        TInstr::drop(TInstr::i32_const(I32(10))),
        TInstr::return_([TInstr::local_get(LocalIdx::new(0))]),
      ]),
      Some(
        TExpr::new([
          TInstr::drop(TInstr::i32_const(I32(10))),
          TInstr::return_([TInstr::local_get(LocalIdx::new(1))]),
        ]),
      ),
    ),
    TInstr::if_(
      BlockType::void_(),
      TInstr::local_get(LocalIdx::new(2)),
      TExpr::new([
        TInstr::drop(TInstr::i32_const(I32(3))),
        TInstr::unreachable_(),
      ]),
      Some(
        TExpr::new([
          TInstr::drop(TInstr::i32_const(I32(3))),
          TInstr::unreachable_(),
        ]),
      ),
    ),
  ])
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(
          SubType::comp_type(
            CompType::func([ValType::i32(), ValType::i32(), ValType::i32()], [
              ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], [ValType::i32(), ValType::i32(), ValType::i32()], body),
      ]),
    )
  let folded = cf_run_fold_module(mod)
  assert_eq(validate_module(folded), Ok(()))
}

///|
test "code folding module pass tracks param arity per function when creating temp locals" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(
          SubType::comp_type(
            CompType::func(
              [
                ValType::i32(),
                ValType::i32(),
                ValType::i32(),
                ValType::i32(),
                ValType::i32(),
              ],
              [ValType::i32()],
            ),
          ),
        ),
        RecType::new(
          SubType::comp_type(
            CompType::func([ValType::i32(), ValType::i32(), ValType::i32()], [
              ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [
            ValType::i32(),
            ValType::i32(),
            ValType::i32(),
            ValType::i32(),
            ValType::i32(),
          ],
          TExpr::new([TInstr::return_([TInstr::local_get(LocalIdx::new(0))])]),
        ),
        Func::t_func(
          [],
          [ValType::i32(), ValType::i32(), ValType::i32()],
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([
                TInstr::drop(TInstr::i32_const(I32(10))),
                TInstr::return_([TInstr::local_get(LocalIdx::new(0))]),
              ]),
              Some(
                TExpr::new([
                  TInstr::drop(TInstr::i32_const(I32(10))),
                  TInstr::return_([TInstr::local_get(LocalIdx::new(1))]),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    )
  let folded = cf_run_fold_module(mod)
  assert_eq(validate_module(folded), Ok(()))
}

///|
test "code folding module pass keeps temp local indices stable with mixed typed and untyped funcs" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], []))),
        RecType::new(
          SubType::comp_type(
            CompType::func(
              [
                ValType::i32(),
                ValType::i32(),
                ValType::i32(),
                ValType::i32(),
                ValType::i32(),
              ],
              [ValType::i32()],
            ),
          ),
        ),
        RecType::new(
          SubType::comp_type(
            CompType::func([ValType::i32(), ValType::i32(), ValType::i32()], [
              ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(1), TypeIdx::new(2)]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::new([], Expr::new([])),
        Func::t_func(
          [],
          [
            ValType::i32(),
            ValType::i32(),
            ValType::i32(),
            ValType::i32(),
            ValType::i32(),
          ],
          TExpr::new([TInstr::return_([TInstr::local_get(LocalIdx::new(0))])]),
        ),
        Func::t_func(
          [],
          [ValType::i32(), ValType::i32(), ValType::i32()],
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(2)),
              TExpr::new([
                TInstr::drop(TInstr::i32_const(I32(10))),
                TInstr::return_([TInstr::local_get(LocalIdx::new(0))]),
              ]),
              Some(
                TExpr::new([
                  TInstr::drop(TInstr::i32_const(I32(10))),
                  TInstr::return_([TInstr::local_get(LocalIdx::new(1))]),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    )
  let folded = cf_run_fold_module(mod)
  assert_eq(validate_module(folded), Ok(()))
}

///|
test "code folding module pass keeps block-hoist temp locals valid with params" {
  let shared = TInstr::local_get(LocalIdx::new(0))
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(
          SubType::comp_type(
            CompType::func([ValType::i32(), ValType::i32(), ValType::i32()], [
              ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::block(
              BlockType::val_type(ValType::i32()),
              TExpr::new([
                TInstr::if_(
                  BlockType::void_(),
                  TInstr::local_get(LocalIdx::new(1)),
                  TExpr::new([
                    TInstr::nop(),
                    TInstr::br(LabelIdx::new(1), [shared]),
                  ]),
                  Some(TExpr::new([])),
                ),
                shared,
              ]),
            ),
          ]),
        ),
      ]),
    )
  let folded = cf_run_fold_module(mod)
  assert_eq(validate_module(folded), Ok(()))
}

///|
test "code folding module pass keeps nested block-hoist temp locals valid with params" {
  let shared = TInstr::local_get(LocalIdx::new(0))
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(
          SubType::comp_type(
            CompType::func([ValType::i32(), ValType::i32(), ValType::i32()], [
              ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::block(
              BlockType::val_type(ValType::i32()),
              TExpr::new([
                TInstr::if_(
                  BlockType::void_(),
                  TInstr::block(
                    BlockType::val_type(ValType::i32()),
                    TExpr::new([
                      TInstr::br(LabelIdx::new(1), [
                        TInstr::local_get(LocalIdx::new(2)),
                      ]),
                    ]),
                  ),
                  TExpr::new([
                    TInstr::nop(),
                    TInstr::br(LabelIdx::new(1), [shared]),
                  ]),
                  Some(TExpr::new([])),
                ),
                shared,
              ]),
            ),
          ]),
        ),
      ]),
    )
  let folded = cf_run_fold_module(mod)
  assert_eq(validate_module(folded), Ok(()))
}

///|
test "code folding module pass declares block-tail temp local in param-only funcs" {
  let shared = TInstr::local_get(LocalIdx::new(0))
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(
          SubType::comp_type(
            CompType::func([ValType::i32(), ValType::i32(), ValType::i32()], [
              ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::drop(
              TInstr::block(
                BlockType::val_type(ValType::i32()),
                TExpr::new([
                  TInstr::if_(
                    BlockType::void_(),
                    TInstr::local_get(LocalIdx::new(1)),
                    TExpr::new([
                      TInstr::nop(),
                      TInstr::br(LabelIdx::new(1), [shared]),
                    ]),
                    Some(TExpr::new([TInstr::drop(TInstr::i32_const(I32(10)))])),
                  ),
                  shared,
                ]),
              ),
            ),
            TInstr::return_([TInstr::local_get(LocalIdx::new(2))]),
          ]),
        ),
      ]),
    )
  let folded = cf_run_fold_module(mod)
  match folded.code_sec {
    Some(CodeSec([folded_func])) => {
      assert_true(cf_test_func_has_local_set(folded_func, LocalIdx::new(3)))
      assert_true(cf_test_func_has_local_get(folded_func, LocalIdx::new(3)))
      match folded_func {
        TFunc(params, locals, _) => {
          assert_eq(params.length(), 3)
          assert_true(locals.length() >= 1)
        }
        _ => fail("expected folded module to contain one typed function")
      }
    }
    _ => fail("expected folded module to contain one typed function")
  }
  assert_eq(validate_module(folded), Ok(()))
}

///|
test "code folding folds nested if tail with outer labels" {
  let original = Func::t_func(
    [],
    [],
    TExpr::new([
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::if_(
            BlockType::void_(),
            TInstr::i32_const(I32(1)),
            TExpr::new([
              TInstr::if_(
                BlockType::void_(),
                TInstr::i32_const(I32(1)),
                TExpr::new([
                  TInstr::br(LabelIdx::new(2), [TInstr::i32_const(I32(7))]),
                ]),
                Some(TExpr::new([])),
              ),
              TInstr::nop(),
              TInstr::drop(TInstr::i32_const(I32(11))),
              TInstr::drop(TInstr::i32_const(I32(12))),
            ]),
            Some(
              TExpr::new([
                TInstr::drop(TInstr::i32_const(I32(1))),
                TInstr::nop(),
                TInstr::drop(TInstr::i32_const(I32(11))),
                TInstr::drop(TInstr::i32_const(I32(12))),
              ]),
            ),
          ),
          TInstr::i32_const(I32(9)),
        ]),
      ),
    ]),
  )
  let expected = Func::t_func(
    [],
    [],
    TExpr::new([
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::block(
            BlockType::void_(),
            TExpr::new([
              TInstr::if_(
                BlockType::void_(),
                TInstr::i32_const(I32(1)),
                TExpr::new([
                  TInstr::if_(
                    BlockType::void_(),
                    TInstr::i32_const(I32(1)),
                    TExpr::new([
                      TInstr::br(LabelIdx::new(3), [TInstr::i32_const(I32(7))]),
                    ]),
                    Some(TExpr::new([])),
                  ),
                ]),
                Some(TExpr::new([TInstr::drop(TInstr::i32_const(I32(1)))])),
              ),
              TInstr::nop(),
              TInstr::drop(TInstr::i32_const(I32(11))),
              TInstr::drop(TInstr::i32_const(I32(12))),
            ]),
          ),
          TInstr::i32_const(I32(9)),
        ]),
      ),
    ]),
  )
  assert_eq(run_fold(original), expected)
}

///|
test "code folding does not treat inner br0 as outer block tail" {
  let f = Func::t_func(
    [],
    [],
    TExpr::new([
      TInstr::block(
        BlockType::void_(),
        TExpr::new([
          TInstr::block(
            BlockType::void_(),
            TExpr::new([TInstr::nop(), TInstr::br(LabelIdx::new(0), [])]),
          ),
          TInstr::nop(),
        ]),
      ),
    ]),
  )
  let f2 = run_fold(f)
  assert_eq(f2, f)
}

///|
test "code folding: nested blocks" {
  // Nested block structure
  let inner = TExpr::new([TInstr::i32_const(I32(1)), TInstr::i32_const(I32(2))])
  let outer = TExpr::new([TInstr::block(BlockType::void_(), inner)])
  let f = Func::t_func([], [], outer)
  let f2 = run_fold(f)
  match f2 {
    TFunc(_, _, _) => ()
    _ => fail("expected TFunc")
  }
}

///|
test "code folding: loop body" {
  let loop_body = TExpr::new([
    TInstr::i32_const(I32(1)),
    TInstr::br(LabelIdx::new(0), []),
  ])
  let loop_instr = TInstr::loop_(BlockType::void_(), loop_body)
  let f = Func::t_func([], [], TExpr::new([loop_instr]))
  let f2 = run_fold(f)
  match f2 {
    TFunc(_, _, _) => ()
    _ => fail("expected TFunc")
  }
}

///|
test "code folding: multiple returns" {
  // Function with multiple return points
  let if_instr = TInstr::if_(
    BlockType::void_(),
    TInstr::i32_const(I32(0)),
    TExpr::new([TInstr::return_([TInstr::i32_const(I32(1))])]),
    Some(TExpr::new([TInstr::return_([TInstr::i32_const(I32(2))])])),
  )
  let f = Func::t_func([], [], TExpr::new([if_instr]))
  let f2 = run_fold(f)
  match f2 {
    TFunc(_, _, _) => ()
    _ => fail("expected TFunc")
  }
}

///|
test "code folding: empty function unchanged" {
  let f = Func::t_func([], [], TExpr::new([]))
  let f2 = run_fold(f)
  match f2 {
    TFunc(_, _, { instrs, .. }) => assert_eq(instrs.length(), 0)
    _ => fail("expected TFunc")
  }
}

///|
test "code folding: single instruction unchanged" {
  let f = Func::t_func([], [], TExpr::new([TInstr::nop()]))
  let f2 = run_fold(f)
  match f2 {
    TFunc(_, _, { instrs, .. }) => {
      assert_eq(instrs.length(), 1)
      assert_true(instrs[0].kind is TInstrKind::TNop)
    }
    _ => fail("expected TFunc")
  }
}

///|
test "code folding: br_table marks all targets unoptimizable" {
  let state = CodeFoldingState::{
    ..CodeFoldingState::new(),
    another_pass: false,
  }
  let br_table = TInstr::br_table(
    [LabelIdx::new(0), LabelIdx::new(1)],
    LabelIdx::new(2),
    TInstr::i32_const(I32(0)),
    [],
  )
  let instrs : Array[TInstr] = [br_table]
  collect_block_tails(state, instrs, cf_round_trace_stats_new())
  assert_true(state.unoptimizables.contains(LabelIdx::new(0)))
  assert_true(state.unoptimizables.contains(LabelIdx::new(1)))
  assert_true(state.unoptimizables.contains(LabelIdx::new(2)))
}

///|
test "code folding: complex nested structure" {
  // Create a complex nested structure
  let inner_if = TInstr::if_(
    BlockType::void_(),
    TInstr::local_get(LocalIdx::new(0)),
    TExpr::new([TInstr::i32_const(I32(1))]),
    Some(TExpr::new([TInstr::i32_const(I32(2))])),
  )
  let block = TInstr::block(BlockType::void_(), TExpr::new([inner_if]))
  let outer_if = TInstr::if_(
    BlockType::void_(),
    TInstr::local_get(LocalIdx::new(1)),
    TExpr::new([block]),
    Some(TExpr::new([TInstr::i32_const(I32(3))])),
  )
  let f = Func::t_func(
    [],
    [ValType::i32(), ValType::i32()],
    TExpr::new([outer_if]),
  )
  let f2 = run_fold(f)
  match f2 {
    TFunc(_, locals, _) => assert_eq(locals.length(), 2)
    _ => fail("expected TFunc")
  }
}

///|
test "get_branch_targets finds br_table targets" {
  let br_table = TInstr::br_table(
    [LabelIdx::new(0), LabelIdx::new(1), LabelIdx::new(2)],
    LabelIdx::new(3),
    TInstr::i32_const(I32(0)),
    [],
  )
  let targets = get_branch_targets(br_table)
  assert_true(targets.contains(LabelIdx::new(0)))
  assert_true(targets.contains(LabelIdx::new(1)))
  assert_true(targets.contains(LabelIdx::new(2)))
  assert_true(targets.contains(LabelIdx::new(3)))
}

///|
test "get_branch_targets finds nested branches" {
  let inner_br = TInstr::br(LabelIdx::new(1), [])
  let block = TInstr::block(
    BlockType::void_(),
    TExpr::new([inner_br, TInstr::br(LabelIdx::new(0), [])]),
  )
  let targets = get_branch_targets(block)
  assert_true(targets.contains(LabelIdx::new(0)))
  assert_true(targets.contains(LabelIdx::new(1)))
}
