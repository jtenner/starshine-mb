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
fn cf_trace_noop(_ : String) -> Unit {
  ()
}

///|
fn cf_trace_delta_us_to_ms(delta_us : UInt64) -> UInt64 {
  delta_us / 1000UL
}

///|
#cfg(target="native")
#borrow(tv)
extern "c" fn cf_native_gettimeofday(tv : Bytes, tz : UInt64) -> Int = "gettimeofday"

///|
#cfg(target="native")
fn cf_trace_read_u64_le(bytes : Bytes, start : Int) -> UInt64 {
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
fn cf_trace_now_us() -> UInt64 {
  let tv = Bytes::new(16)
  if cf_native_gettimeofday(tv, 0UL) != 0 {
    return @env.now() * 1000UL
  }
  let sec = cf_trace_read_u64_le(tv, 0)
  let usec = cf_trace_read_u64_le(tv, 8)
  sec * 1000000UL + usec
}

///|
#cfg(target="wasm-gc")
fn cf_trace_now_us() -> UInt64 {
  @env.now() * 1000UL
}

///|
#cfg(target="wasm")
fn cf_trace_now_us() -> UInt64 {
  @env.now() * 1000UL
}

///|
#cfg(target="js")
fn cf_trace_now_us() -> UInt64 {
  @env.now() * 1000UL
}

///|
#cfg(target="llvm")
fn cf_trace_now_us() -> UInt64 {
  @env.now() * 1000UL
}

///|
fn cf_trace_elapsed_us_since(start_us : UInt64) -> UInt64 {
  let end_us = cf_trace_now_us()
  if end_us >= start_us {
    end_us - start_us
  } else {
    0UL
  }
}

///|
/// Information about a "tail" - code that reaches a point that we can merge
struct Tail {
  instr : TInstr? // None if this is a fallthrough
  block_instrs : Array[TInstr] // the enclosing block of code we hope to merge at its tail
} derive(Eq)

///|
fn Tail::fallthrough(block_instrs : Array[TInstr]) -> Tail {
  Tail::{ instr: None, block_instrs }
}

///|
fn Tail::branch(instr : TInstr, block_instrs : Array[TInstr]) -> Tail {
  Tail::{ instr: Some(instr), block_instrs }
}

///|
fn Tail::is_fallthrough(self : Tail) -> Bool {
  self.instr is None
}

///|
/// State for the code folding pass
priv struct CodeFoldingState {
  mut another_pass : Bool
  break_tails : Map[LabelIdx, Array[Tail]]
  unreachable_tails : Array[Tail]
  return_tails : Array[Tail]
  unoptimizables : Set[LabelIdx]
  modifieds : Set[TInstr]
  mut block_sites : Int
  mut if_else_sites : Int
}

///|
fn CodeFoldingState::new() -> CodeFoldingState {
  CodeFoldingState::{
    another_pass: true,
    break_tails: Map::new(),
    unreachable_tails: [],
    return_tails: [],
    unoptimizables: Set::new(),
    modifieds: Set::new(),
    block_sites: 0,
    if_else_sites: 0,
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
  let start_us = cf_trace_now_us()
  trace_stats.measure_calls += 1
  // Simple heuristic: count 1 for each instruction node
  // This is a simplified version of Binaryen's Measurer
  let mut count = 1
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, c, i) {
    count += 1
    self.walk_tinstruction_default(c, i)
  })
  ignore(walker.walk_tinstruction((), instr))
  trace_stats.measure_nodes += count
  trace_stats.measure_us = trace_stats.measure_us +
    cf_trace_elapsed_us_since(start_us)
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
  let start_us = cf_trace_now_us()
  trace_stats.branch_target_calls += 1
  let targets = Set::new()
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, i) {
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
    self.walk_tinstruction_default((), i)
  })
  ignore(walker.walk_tinstruction((), instr))
  trace_stats.branch_target_us = trace_stats.branch_target_us +
    cf_trace_elapsed_us_since(start_us)
  targets
}

///|
/// Get branch targets that exit the given instruction (branch to outside)
fn get_branch_targets(instr : TInstr) -> Set[LabelIdx] {
  get_branch_targets_with_trace(instr, cf_round_trace_stats_new())
}

///|
/// Get branch targets that exit the given instruction (branch to outside)
fn get_exiting_branches_with_trace(
  instr : TInstr,
  trace_stats : CodeFoldingRoundTraceStats,
) -> Set[LabelIdx] {
  // For simplicity, we collect all branch targets
  // A more sophisticated implementation would track scope
  get_branch_targets_with_trace(instr, trace_stats)
}

///|
/// Check if we can move items out of a container
/// We can't do so if one of the items has a branch to something inside the container
fn can_move_against_targets_with_trace(
  items : Array[TInstr],
  container_targets : Set[LabelIdx],
  trace_stats : CodeFoldingRoundTraceStats,
) -> Bool {
  let start_us = cf_trace_now_us()
  trace_stats.can_move_calls += 1
  for item in items {
    let exiting = get_exiting_branches_with_trace(item, trace_stats)
    // Check if there's any intersection
    for target in exiting.iter() {
      if container_targets.contains(target) {
        trace_stats.can_move_us = trace_stats.can_move_us +
          cf_trace_elapsed_us_since(start_us)
        return false
      }
    }
  }
  trace_stats.can_move_us = trace_stats.can_move_us +
    cf_trace_elapsed_us_since(start_us)
  true
}

///|
/// Check if we can move items out of a container
/// We can't do so if one of the items has a branch to something inside the container
fn can_move_with_trace(
  items : Array[TInstr],
  container : TInstr,
  trace_stats : CodeFoldingRoundTraceStats,
) -> Bool {
  let all_targets = get_branch_targets_with_trace(container, trace_stats)
  can_move_against_targets_with_trace(items, all_targets, trace_stats)
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
/// Optimize expression tails (for blocks and if-else)
fn optimize_expression_tails(
  state : CodeFoldingState,
  tails : Array[Tail],
  curr : TInstr,
  trace_stats : CodeFoldingRoundTraceStats,
  trace_ctx : CodeFoldingExprTraceCtx,
) -> TInstr? {
  let start_us = cf_trace_now_us()
  trace_stats.expr_calls += 1
  trace_stats.expr_tail_count += tails.length()
  if tails.length() < 2 {
    trace_stats.expr_us = trace_stats.expr_us +
      cf_trace_elapsed_us_since(start_us)
    return None
  }

  // Check if anything is untoward
  for tail in tails {
    match tail.instr {
      Some(i) if state.modifieds.contains(i) => {
        trace_stats.expr_us = trace_stats.expr_us +
          cf_trace_elapsed_us_since(start_us)
        return None
      }
      _ => ()
    }
  }

  // Find mergeable items
  let curr_targets = get_branch_targets_with_trace(curr, trace_stats)
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
        let match_start_us = cf_trace_now_us()
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
        let match_elapsed_us = cf_trace_elapsed_us_since(match_start_us)
        local_match_us = local_match_us + match_elapsed_us
        trace_stats.expr_match_us = trace_stats.expr_match_us + match_elapsed_us
        if not(all_match) {
          let total_elapsed_us = cf_trace_elapsed_us_since(start_us)
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
        let can_move_start_us = cf_trace_now_us()
        let can_move_result = can_move_against_targets_with_trace(
          [item],
          curr_targets,
          trace_stats,
        )
        let can_move_elapsed_us = cf_trace_elapsed_us_since(can_move_start_us)
        local_can_move_us = local_can_move_us + can_move_elapsed_us
        trace_stats.expr_can_move_us = trace_stats.expr_can_move_us +
          can_move_elapsed_us
        if not(can_move_result) {
          let total_elapsed_us = cf_trace_elapsed_us_since(start_us)
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
        let measure_start_us = cf_trace_now_us()
        let item_measure = measure_with_trace(item, trace_stats)
        let measure_elapsed_us = cf_trace_elapsed_us_since(measure_start_us)
        local_measure_us = local_measure_us + measure_elapsed_us
        trace_stats.expr_measure_us = trace_stats.expr_measure_us +
          measure_elapsed_us
        saved += item_measure
        num += 1
        let total_elapsed_us = cf_trace_elapsed_us_since(start_us)
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
    trace_stats.expr_us = trace_stats.expr_us +
      cf_trace_elapsed_us_since(start_us)
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
    if not(will_empty_block) {
      trace_stats.expr_us = trace_stats.expr_us +
        cf_trace_elapsed_us_since(start_us)
      return None
    }
  }

  // Do the optimization - remove merged items from each tail
  state.another_pass = true
  let merge_count = mergeable.length()

  // Remove items from each tail's block
  for tail in tails {
    let block = tail.block_instrs
    // How many to remove from this block
    let to_remove = merge_count
    // Remove from the end
    let mut removed = 0
    while removed < to_remove && block.length() > 0 {
      ignore(block.pop())
      removed += 1
    }
    // Mark the tail's branch instruction as modified if present
    match tail.instr {
      Some(i) => state.modifieds.add(i)
      None => ()
    }
  }

  // Return the merged items in correct order (they were collected in reverse)
  // The caller will need to append these after the current instruction
  trace_stats.expr_successes += 1
  trace_stats.expr_merged_instrs += mergeable.length()
  trace_stats.expr_saved += saved
  trace_stats.expr_us = trace_stats.expr_us +
    cf_trace_elapsed_us_since(start_us)
  Some(mergeable[0]) // Return first merged item as indicator of change
}

///|
/// Optimize terminating tails (returns/unreachables) at function body level
/// This moves common code before return/unreachable instructions to the end of function
fn optimize_terminating_tails(
  state : CodeFoldingState,
  tails : Array[Tail],
  func_body : Array[TInstr],
  trace_stats : CodeFoldingRoundTraceStats,
) -> Array[TInstr]? {
  if tails.length() < 2 {
    return None
  }

  // Check if anything is modified
  for tail in tails {
    match tail.instr {
      Some(i) if state.modifieds.contains(i) => return None
      _ => ()
    }
  }

  // Find mergeable items from the tails
  let mergeable : Array[TInstr] = []
  let mut saved = 0
  let mut num = 0
  while true {
    match get_mergeable(tails[0], num) {
      None => break
      Some(item) => {
        // Check if all tails have matching items
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
        if not(all_match) {
          break
        }

        // We found another one we can merge
        mergeable.push(item)
        saved += measure_with_trace(item, trace_stats)
        num += 1
      }
    }
  }
  if saved < MIN_TERMINATING_TAIL_SAVINGS {
    return None
  }

  // Do the optimization
  state.another_pass = true
  let merge_count = mergeable.length()

  // Remove merged items from each tail
  for tail in tails {
    let block = tail.block_instrs
    let mut removed = 0
    while removed < merge_count && block.length() > 0 {
      ignore(block.pop())
      removed += 1
    }
    match tail.instr {
      Some(i) => state.modifieds.add(i)
      None => ()
    }
  }

  // Build new function body with merged items at the end
  // The merged items should go before a final return/unreachable
  let result : Array[TInstr] = []
  for instr in func_body {
    result.push(instr)
  }
  // Add merged items in reverse order (they were collected from end to start)
  let mut j = merge_count - 1
  while j >= 0 {
    result.push(mergeable[j])
    j -= 1
  }
  Some(result)
}

///|
/// Collect tails from a block's instructions
fn collect_block_tails(
  state : CodeFoldingState,
  instrs : Array[TInstr],
  trace_stats : CodeFoldingRoundTraceStats,
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
        state.unreachable_tails.push(Tail::branch(instr, instrs))

      // Return at end of block
      TInstrKind::TReturn(_) if i == instrs.length() - 1 =>
        state.return_tails.push(Tail::branch(instr, instrs))

      // Return calls
      TInstrKind::TReturnCall(_, _) if i == instrs.length() - 1 =>
        state.return_tails.push(Tail::branch(instr, instrs))
      TInstrKind::TReturnCallIndirect(_, _, _, _) if i == instrs.length() - 1 =>
        state.return_tails.push(Tail::branch(instr, instrs))
      TInstrKind::TReturnCallRef(_, _, _) if i == instrs.length() - 1 =>
        state.return_tails.push(Tail::branch(instr, instrs))

      // Recursively process nested blocks
      TInstrKind::TBlock(_, body) => {
        state.block_sites += 1
        collect_block_tails(state, body.instrs, trace_stats)
      }
      TInstrKind::TLoop(_, body) =>
        collect_block_tails(state, body.instrs, trace_stats)
      TInstrKind::TIf(_, _, then_body, else_body) => {
        if else_body is Some(_) {
          state.if_else_sites += 1
        }
        collect_block_tails(state, then_body.instrs, trace_stats)
        match else_body {
          Some(body) => collect_block_tails(state, body.instrs, trace_stats)
          None => ()
        }
      }
      TInstrKind::TTryTable(_, _, body) =>
        collect_block_tails(state, body.instrs, trace_stats)
      _ => ()
    }
  }
}

///|
/// Process a block instruction for code folding
fn process_block(
  state : CodeFoldingState,
  label : LabelIdx,
  instrs : Array[TInstr],
  trace_stats : CodeFoldingRoundTraceStats,
  trace_ctx : CodeFoldingExprTraceCtx,
) -> TInstr? {
  trace_stats.block_visits += 1
  if instrs.is_empty() {
    return None
  }
  if state.unoptimizables.contains(label) {
    return None
  }
  match state.break_tails.get(label) {
    None => None
    Some(tails) => {
      // Check if the end of the block can be reached
      let mut include_fallthrough = true
      for instr in instrs {
        match instr.kind {
          TInstrKind::TUnreachable => {
            include_fallthrough = false
            break
          }
          _ => ()
        }
      }
      let all_tails = if include_fallthrough {
        let result = tails.copy()
        result.push(Tail::fallthrough(instrs))
        result
      } else {
        tails
      }

      // Try to optimize
      match
        optimize_expression_tails(
          state,
          all_tails,
          TInstr::block(BlockType::void_(), TExpr::new(instrs)),
          trace_stats,
          { ..trace_ctx, site_kind: "block" },
        ) {
        Some(changed_instr) => {
          trace_stats.block_successes += 1
          Some(changed_instr)
        }
        None => None
      }
    }
  }
}

///|
/// Process an if instruction for code folding
fn process_if(
  state : CodeFoldingState,
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
      // Both arms must be present
      let tails = [
        Tail::fallthrough(then_body.instrs),
        Tail::fallthrough(else_expr.instrs),
      ]
      match
        optimize_expression_tails(
          state,
          tails,
          TInstr::if_(BlockType::void_(), cond, then_body, Some(else_expr)),
          trace_stats,
          { ..trace_ctx, site_kind: "if" },
        ) {
        Some(changed_instr) => {
          trace_stats.if_successes += 1
          Some(changed_instr)
        }
        None => None
      }
    }
  }
}

///|
/// Main code folding pass
fn code_folding_pass_with_trace(
  trace? : (String) -> Unit = cf_trace_noop,
  trace_all_funcs? : Bool = true,
) -> ModuleTransformer[CodeFoldingState] {
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
  .on_tinstruction_evt(fn(self, state, instr) {
    // Process blocks and ifs for tail merging
    match instr.kind {
      TInstrKind::TBlock(bt, body) =>
        // First recurse into children
        match self.walk_tinstruction_default(state, instr) {
          Ok(Some((new_state, new_instr))) =>
            match new_instr.kind {
              TInstrKind::TBlock(_, new_body) =>
                // Try to optimize the block's tails
                match
                  process_block(
                    new_state,
                    LabelIdx::new(0),
                    new_body.instrs,
                    round_stats,
                    expr_trace_ctx,
                  ) {
                  Some(_) =>
                    // Block was modified
                    change(new_state, TInstr::block(bt, new_body))
                  None => change(new_state, new_instr)
                }
              _ => change(new_state, new_instr)
            }
          Ok(None) =>
            // Try to optimize unchanged block
            match
              process_block(
                state,
                LabelIdx::new(0),
                body.instrs,
                round_stats,
                expr_trace_ctx,
              ) {
              Some(_) => change(state, instr)
              None => unchanged()
            }
          Err(e) => Err(e)
        }
      TInstrKind::TIf(bt, cond, then_body, else_body) =>
        // First recurse into children
        match self.walk_tinstruction_default(state, instr) {
          Ok(Some((new_state, new_instr))) =>
            match new_instr.kind {
              TInstrKind::TIf(_, new_cond, new_then, new_else) =>
                // Try to optimize the if's tails
                match
                  process_if(
                    new_state, new_cond, new_then, new_else, round_stats, expr_trace_ctx,
                  ) {
                  Some(_) =>
                    // If was modified
                    change(
                      new_state,
                      TInstr::if_(bt, new_cond, new_then, new_else),
                    )
                  None => change(new_state, new_instr)
                }
              _ => change(new_state, new_instr)
            }
          Ok(None) =>
            // Try to optimize unchanged if
            match
              process_if(
                state, cond, then_body, else_body, round_stats, expr_trace_ctx,
              ) {
              Some(_) => change(state, instr)
              None => unchanged()
            }
          Err(e) => Err(e)
        }
      _ => self.walk_tinstruction_default(state, instr)
    }
  })
  .on_func_evt(fn(self, state, func) {
    seen_funcs += 1
    let ordinal = seen_funcs
    let log_func = trace_all_funcs || ordinal <= 5 || ordinal % 50 == 0
    match func {
      Func(_) => {
        if log_func {
          trace("func[\{ordinal}] skip non-typed-func")
        }
        unchanged()
      }
      TFunc(locals, body) => {
        let func_start_us = cf_trace_now_us()
        let start_top_instrs = body.instrs.length()
        if log_func {
          trace(
            "func[\{ordinal}] start top_instrs=\{start_top_instrs} locals=\{locals.length()}",
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

          // Run multiple passes until no more changes
          let mut current_func = func
          let mut current_locals = locals
          let mut current_body = body
          let mut rounds = 0
          state.another_pass = true
          while state.another_pass {
            rounds += 1
            round_stats.clear()
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

            // Try terminating tail optimization (returns/unreachables)
            round_stats.return_phase_calls += 1
            let return_tail_count = state.return_tails.length()
            round_stats.return_phase_tails += return_tail_count
            let return_result = if return_tail_count < 2 {
              None
            } else {
              let return_start_us = cf_trace_now_us()
              let return_result = optimize_terminating_tails(
                state,
                state.return_tails,
                current_body.instrs,
                round_stats,
              )
              let return_elapsed_us = cf_trace_elapsed_us_since(return_start_us)
              round_stats.return_phase_us = round_stats.return_phase_us +
                return_elapsed_us
              if log_func {
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
            }
            match return_result {
              Some(new_body_instrs) => {
                round_stats.return_phase_successes += 1
                current_body = TExpr::new(new_body_instrs)
                current_func = Func::t_func(current_locals, current_body)
              }
              None => {
                round_stats.unreachable_phase_calls += 1
                let unreachable_tail_count = state.unreachable_tails.length()
                round_stats.unreachable_phase_tails += unreachable_tail_count
                let unreachable_result = if unreachable_tail_count < 2 {
                  None
                } else {
                  let unreachable_start_us = cf_trace_now_us()
                  let unreachable_result = optimize_terminating_tails(
                    state,
                    state.unreachable_tails,
                    current_body.instrs,
                    round_stats,
                  )
                  let unreachable_elapsed_us = cf_trace_elapsed_us_since(
                    unreachable_start_us,
                  )
                  round_stats.unreachable_phase_us = round_stats.unreachable_phase_us +
                    unreachable_elapsed_us
                  if log_func {
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
                }
                match unreachable_result {
                  Some(new_body_instrs) => {
                    round_stats.unreachable_phase_successes += 1
                    current_body = TExpr::new(new_body_instrs)
                    current_func = Func::t_func(current_locals, current_body)
                  }
                  None => ()
                }
              }
            }
            if log_func && return_result is Some(_) {
              trace(
                "func[\{ordinal}] round[\{rounds}] terminating_unreachable skipped reason=return_fold_changed",
              )
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
            let over_block_budget = block_fanout > CF_BLOCK_FANOUT_LIMIT
            if has_expr_candidates && !over_expr_budget && !over_block_budget {
              let walk_start_us = cf_trace_now_us()
              let walk_changed = match
                self.walk_func_default(state, current_func) {
                Ok(Some((new_state, new_func))) => {
                  state.another_pass = new_state.another_pass
                  current_func = new_func
                  match current_func {
                    TFunc(l, b) => {
                      current_locals = l
                      current_body = b
                    }
                    _ => ()
                  }
                  true
                }
                Ok(None) => false
                Err(e) => {
                  let walk_elapsed_us = cf_trace_elapsed_us_since(walk_start_us)
                  round_stats.walk_us = round_stats.walk_us + walk_elapsed_us
                  if log_func {
                    trace(
                      "func[\{ordinal}] round[\{rounds}] walk error elapsed_ms=\{cf_trace_delta_us_to_ms(walk_elapsed_us)} elapsed_us=\{walk_elapsed_us} \{e}",
                    )
                  }
                  return Err(e)
                }
              }
              let walk_elapsed_us = cf_trace_elapsed_us_since(walk_start_us)
              round_stats.walk_us = round_stats.walk_us + walk_elapsed_us
              if log_func {
                trace(
                  "func[\{ordinal}] round[\{rounds}] walk elapsed_ms=\{cf_trace_delta_us_to_ms(walk_elapsed_us)} elapsed_us=\{walk_elapsed_us} changed=\{walk_changed} continue=\{state.another_pass} blocks=\{round_stats.block_visits} block_changed=\{round_stats.block_successes} ifs=\{round_stats.if_visits} if_changed=\{round_stats.if_successes} expr_calls=\{round_stats.expr_calls} expr_changed=\{round_stats.expr_successes} expr_tails=\{round_stats.expr_tail_count} expr_merged=\{round_stats.expr_merged_instrs} expr_saved=\{round_stats.expr_saved} expr_ms=\{cf_trace_delta_us_to_ms(round_stats.expr_us)} expr_match_ms=\{cf_trace_delta_us_to_ms(round_stats.expr_match_us)} expr_can_move_ms=\{cf_trace_delta_us_to_ms(round_stats.expr_can_move_us)} expr_measure_ms=\{cf_trace_delta_us_to_ms(round_stats.expr_measure_us)} measure_calls=\{round_stats.measure_calls} measure_nodes=\{round_stats.measure_nodes} measure_ms=\{cf_trace_delta_us_to_ms(round_stats.measure_us)} branch_calls=\{round_stats.branch_target_calls} branch_ms=\{cf_trace_delta_us_to_ms(round_stats.branch_target_us)} can_move_calls=\{round_stats.can_move_calls} can_move_ms=\{cf_trace_delta_us_to_ms(round_stats.can_move_us)}",
                )
              }
            } else if log_func {
              let skip_reason = if !has_expr_candidates {
                "no_expr_candidates"
              } else if over_expr_budget {
                "expr_site_budget"
              } else {
                "block_fanout_budget"
              }
              trace(
                "func[\{ordinal}] round[\{rounds}] walk skipped reason=\{skip_reason} continue=\{state.another_pass} block_sites=\{state.block_sites} if_elses=\{state.if_else_sites} expr_sites=\{expr_site_count} label0_breaks=\{label_zero_breaks} block_fanout=\{block_fanout}",
              )
            }
            total_stats.merge_from(round_stats)
          }
          let elapsed_us = cf_trace_elapsed_us_since(func_start_us)
          let changed = current_func != func
          if log_func {
            trace(
              "func[\{ordinal}] done elapsed_ms=\{cf_trace_delta_us_to_ms(elapsed_us)} elapsed_us=\{elapsed_us} rounds=\{rounds} changed=\{changed} top_instrs=\{start_top_instrs}->\{current_body.instrs.length()} collect_ms=\{cf_trace_delta_us_to_ms(total_stats.collect_us)} return_ms=\{cf_trace_delta_us_to_ms(total_stats.return_phase_us)} unreachable_ms=\{cf_trace_delta_us_to_ms(total_stats.unreachable_phase_us)} walk_ms=\{cf_trace_delta_us_to_ms(total_stats.walk_us)} return_changed=\{total_stats.return_phase_successes} unreachable_changed=\{total_stats.unreachable_phase_successes} blocks=\{total_stats.block_visits} ifs=\{total_stats.if_visits} expr_calls=\{total_stats.expr_calls} expr_changed=\{total_stats.expr_successes} expr_saved=\{total_stats.expr_saved} expr_match_ms=\{cf_trace_delta_us_to_ms(total_stats.expr_match_us)} expr_can_move_ms=\{cf_trace_delta_us_to_ms(total_stats.expr_can_move_us)} expr_measure_ms=\{cf_trace_delta_us_to_ms(total_stats.expr_measure_us)} measure_ms=\{cf_trace_delta_us_to_ms(total_stats.measure_us)} branch_ms=\{cf_trace_delta_us_to_ms(total_stats.branch_target_us)} can_move_ms=\{cf_trace_delta_us_to_ms(total_stats.can_move_us)}",
            )
          }
          if current_func == func {
            unchanged()
          } else {
            change(state, current_func)
          }
        }
      }
    }
  })
}

///|
fn code_folding_pass() -> ModuleTransformer[CodeFoldingState] {
  code_folding_pass_with_trace()
}

///|
fn code_folding_ir_pass_with_trace(
  _mod : Module,
  trace? : (String) -> Unit = cf_trace_noop,
  trace_all_funcs? : Bool = true,
) -> ModuleTransformer[IRContext] {
  let pass = code_folding_pass_with_trace(trace~, trace_all_funcs~)
  ModuleTransformer::new().on_func_evt(fn(_, ctx : IRContext, func : Func) {
    match pass.walk_func(CodeFoldingState::new(), func) {
      Ok(Some((_, new_func))) => change(ctx, new_func)
      Ok(None) => unchanged()
      Err(e) => Err(e)
    }
  })
}

///|
fn code_folding_ir_pass(_mod : Module) -> ModuleTransformer[IRContext] {
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
  let func = Func::t_func([], TExpr::new([TInstr::i32_const(I32(42))]))
  match pass.walk_func(state, func) {
    Ok(_) => () // Pass completes without error
    Err(e) => fail("Unexpected error: " + e)
  }
}

///|
test "code_folding_pass_with_trace emits phase logs" {
  let trace_logs : Array[String] = []
  let pass = code_folding_pass_with_trace(trace=fn(msg) { trace_logs.push(msg) })
  let state = CodeFoldingState::{
    ..CodeFoldingState::new(),
    another_pass: false,
  }

  let func = Func::t_func(
    [],
    TExpr::new([
      TInstr::if_(
        BlockType::void_(),
        TInstr::i32_const(I32(0)),
        TExpr::new([TInstr::i32_const(I32(1))]),
        Some(TExpr::new([TInstr::i32_const(I32(2))])),
      ),
    ]),
  )
  match pass.walk_func(state, func) {
    Ok(_) => ()
    Err(e) => fail("Unexpected error: " + e)
  }

  let mut saw_collect = false
  let mut saw_returns = false
  let mut saw_walk = false
  let mut saw_done = false
  let mut saw_expr_breakdown = false
  for msg in trace_logs {
    if msg.contains("collect_tails") {
      saw_collect = true
    }
    if msg.contains("terminating_returns") {
      saw_returns = true
    }
    if msg.contains(" walk ") || msg.contains(" walk elapsed_ms=") {
      saw_walk = true
    }
    if msg.contains(" done elapsed_ms=") {
      saw_done = true
    }
    if msg.contains("expr_match_ms=") &&
      msg.contains("expr_can_move_ms=") &&
      msg.contains("expr_measure_ms=") {
      saw_expr_breakdown = true
    }
  }
  assert_true(saw_collect)
  assert_true(saw_returns)
  assert_true(saw_walk)
  assert_true(saw_done)
  assert_true(saw_expr_breakdown)
}

///|
test "code_folding_pass_with_trace fast skips trivial leaf function" {
  let trace_logs : Array[String] = []
  let pass = code_folding_pass_with_trace(trace=fn(msg) { trace_logs.push(msg) })
  let state = CodeFoldingState::{
    ..CodeFoldingState::new(),
    another_pass: false,
  }

  let func = Func::t_func([], TExpr::new([TInstr::i32_const(I32(42))]))
  match pass.walk_func(state, func) {
    Ok(_) => ()
    Err(e) => fail("Unexpected error: " + e)
  }

  let mut saw_skip = false
  let mut saw_done = false
  for msg in trace_logs {
    if msg.contains("skip reason=no_control_surface") {
      saw_skip = true
    }
    if msg.contains(" done elapsed_ms=") {
      saw_done = true
    }
  }
  assert_true(saw_skip)
  assert_true(saw_done)
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
fn run_fold(f : Func) -> Func raise {
  let pass = code_folding_pass()
  let state = CodeFoldingState::{
    ..CodeFoldingState::new(),
    another_pass: false,
  }
  match pass.walk_func(state, f) {
    Ok(Some((_, new_f))) => return new_f
    Ok(None) => ()
    Err(e) => assert_true(false, msg=e)
  }
  f
}

///|
test "simple function unchanged" {
  let f = Func::t_func([], TExpr::new([TInstr::i32_const(I32(42))]))
  let f2 = run_fold(f)
  match f2 {
    TFunc(_, { instrs, .. }) => assert_eq(instrs.length(), 1)
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
  let f = Func::t_func([], TExpr::new([if_instr]))
  let f2 = run_fold(f)
  // The pass should run without error
  match f2 {
    TFunc(_, { instrs: _, .. }) => ()
    _ => fail("expected TFunc")
  }
}

///|
test "code folding: nested blocks" {
  // Nested block structure
  let inner = TExpr::new([TInstr::i32_const(I32(1)), TInstr::i32_const(I32(2))])
  let outer = TExpr::new([TInstr::block(BlockType::void_(), inner)])
  let f = Func::t_func([], outer)
  let f2 = run_fold(f)
  match f2 {
    TFunc(_, _) => ()
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
  let f = Func::t_func([], TExpr::new([loop_instr]))
  let f2 = run_fold(f)
  match f2 {
    TFunc(_, _) => ()
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
  let f = Func::t_func([], TExpr::new([if_instr]))
  let f2 = run_fold(f)
  match f2 {
    TFunc(_, _) => ()
    _ => fail("expected TFunc")
  }
}

///|
test "code folding: empty function unchanged" {
  let f = Func::t_func([], TExpr::new([]))
  let f2 = run_fold(f)
  match f2 {
    TFunc(_, { instrs, .. }) => assert_eq(instrs.length(), 0)
    _ => fail("expected TFunc")
  }
}

///|
test "code folding: single instruction unchanged" {
  let f = Func::t_func([], TExpr::new([TInstr::nop()]))
  let f2 = run_fold(f)
  match f2 {
    TFunc(_, { instrs, .. }) => {
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
  let f = Func::t_func([ValType::i32(), ValType::i32()], TExpr::new([outer_if]))
  let f2 = run_fold(f)
  match f2 {
    TFunc(locals, _) => assert_eq(locals.length(), 2)
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
