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
priv struct SLLocalStats {
  mut sets : Int
  mut tees : Int
  mut gets : Int
}

///|
fn SLLocalStats::new() -> SLLocalStats {
  { sets: 0, tees: 0, gets: 0 }
}

///|
priv struct SLPerfSnapshot {
  effect_collect_calls : Int
  invalidation_entry_checks : Int
  get_count_scans : Int
  late_state_clones : Int
}

///|
priv struct SLHelperTimingSnapshot {
  collect_get_counts_texpr_us : UInt64
  collect_get_counts_texpr_calls : Int
  simplify_texpr_main_us : UInt64
  simplify_texpr_main_calls : Int
  remove_unneeded_sets_texpr_us : UInt64
  remove_unneeded_sets_texpr_calls : Int
  strip_nops_texpr_us : UInt64
  strip_nops_texpr_calls : Int
  run_late_optimizations_us : UInt64
  run_late_optimizations_calls : Int
  run_main_phase_us : UInt64
  run_main_phase_calls : Int
  run_cleanup_phase_us : UInt64
  run_cleanup_phase_calls : Int
}

///|
priv struct SLMainRewriteHelperSnapshot {
  simplify_texpr_calls : Int
  simplify_texpr_us : UInt64
  rewrite_instr_calls : Int
  rewrite_instr_us : UInt64
  try_sink_local_get_calls : Int
  try_sink_local_get_us : UInt64
  invalidate_sinkables_calls : Int
  invalidate_sinkables_us : UInt64
  collect_effects_cached_calls : Int
  collect_effects_cached_us : UInt64
  collect_effects_cached_hits : Int
  collect_effects_cached_misses : Int
  texpr_instrs_seen : Int
  texpr_depth_max : Int
  texpr_single_instr_calls : Int
  block_instr_calls : Int
  loop_instr_calls : Int
  if_instr_calls : Int
  try_table_instr_calls : Int
  max_sinkables : Int
  progress_logs_emitted : Int
}

///|
priv struct SLHotspotEntry {
  ordinal : Int
  main_ticks : UInt64
  rewrite_ticks : UInt64
  locals : Int
  top_instrs : Int
}

///|
const SL_PATHOLOGICAL_FASTPATH_MIN_LOCALS : Int = 2048

///|
const SL_PATHOLOGICAL_FASTPATH_MAX_INSTRS : Int = 64

///|
const SL_PATHOLOGICAL_FUNC_TICK_BUDGET : UInt64 = 8000UL

///|
const SL_HOTSPOT_SUMMARY_LIMIT : Int = 8

///|
const SL_WIDE_LOCALS_NO_NESTING_MIN_LOCALS : Int = 512

///|
const SL_WIDE_LOCALS_NO_NESTING_MAX_INSTRS : Int = 24

///|
const SL_MAIN_REWRITE_PROGRESS_INITIAL_REWRITE_CALLS : Int = 1

///|
const SL_MAIN_REWRITE_PROGRESS_INITIAL_TEXPR_CALLS : Int = 1

///|
const SL_MAIN_REWRITE_PROGRESS_INITIAL_DEPTH : Int = 1

///|
const SL_MAIN_REWRITE_DEEP_CONTROL_MIN_DEPTH : Int = 96

///|
const SL_MAIN_REWRITE_DEEP_CONTROL_MIN_CONTROL_NODES : Int = 96

///|
const SL_MAIN_REWRITE_DEEP_CONTROL_MAX_TOP_INSTRS : Int = 2

///|
const SL_MAIN_REWRITE_DEEP_CONTROL_MAX_LOCALS : Int = 16

///|
const SL_MAIN_REWRITE_DEEP_CONTROL_WIDE_LOCALS_MIN_DEPTH : Int = 192

///|
const SL_MAIN_REWRITE_DEEP_CONTROL_WIDE_LOCALS_MIN_CONTROL_NODES : Int = 192

///|
const SL_MAIN_REWRITE_DEEP_CONTROL_WIDE_LOCALS_MAX_TOP_INSTRS : Int = 8

///|
const SL_MAIN_REWRITE_DEEP_CONTROL_WIDE_LOCALS_MIN_LOCALS : Int = 64

///|
priv struct SLRewriteValidationSnapshot {
  raw_candidates_attempted : Int
  candidates_accepted : Int
  candidates_rejected_local_validation : Int
  rejection_reason_buckets : Map[String, Int]
}

///|
let sl_perf_effect_collect_calls : Ref[Int] = Ref::new(0)

///|
let sl_perf_invalidation_entry_checks : Ref[Int] = Ref::new(0)

///|
let sl_perf_get_count_scans : Ref[Int] = Ref::new(0)

///|
let sl_perf_late_state_clones : Ref[Int] = Ref::new(0)

///|
let sl_helper_timing_collect_get_counts_texpr_us : Ref[UInt64] = Ref::new(0UL)

///|
let sl_helper_timing_collect_get_counts_texpr_calls : Ref[Int] = Ref::new(0)

///|
let sl_helper_timing_simplify_texpr_main_us : Ref[UInt64] = Ref::new(0UL)

///|
let sl_helper_timing_simplify_texpr_main_calls : Ref[Int] = Ref::new(0)

///|
let sl_helper_timing_remove_unneeded_sets_texpr_us : Ref[UInt64] = Ref::new(0UL)

///|
let sl_helper_timing_remove_unneeded_sets_texpr_calls : Ref[Int] = Ref::new(0)

///|
let sl_helper_timing_strip_nops_texpr_us : Ref[UInt64] = Ref::new(0UL)

///|
let sl_helper_timing_strip_nops_texpr_calls : Ref[Int] = Ref::new(0)

///|
let sl_helper_timing_run_late_optimizations_us : Ref[UInt64] = Ref::new(0UL)

///|
let sl_helper_timing_run_late_optimizations_calls : Ref[Int] = Ref::new(0)

///|
let sl_helper_timing_run_main_phase_us : Ref[UInt64] = Ref::new(0UL)

///|
let sl_helper_timing_run_main_phase_calls : Ref[Int] = Ref::new(0)

///|
let sl_helper_timing_run_cleanup_phase_us : Ref[UInt64] = Ref::new(0UL)

///|
let sl_helper_timing_run_cleanup_phase_calls : Ref[Int] = Ref::new(0)

///|
let sl_main_rewrite_helper_trace_enabled : Ref[Bool] = Ref::new(false)

///|
let sl_main_rewrite_helper_simplify_texpr_calls : Ref[Int] = Ref::new(0)

///|
let sl_main_rewrite_helper_simplify_texpr_us : Ref[UInt64] = Ref::new(0UL)

///|
let sl_main_rewrite_helper_rewrite_instr_calls : Ref[Int] = Ref::new(0)

///|
let sl_main_rewrite_helper_rewrite_instr_us : Ref[UInt64] = Ref::new(0UL)

///|
let sl_main_rewrite_helper_try_sink_local_get_calls : Ref[Int] = Ref::new(0)

///|
let sl_main_rewrite_helper_try_sink_local_get_us : Ref[UInt64] = Ref::new(0UL)

///|
let sl_main_rewrite_helper_invalidate_sinkables_calls : Ref[Int] = Ref::new(0)

///|
let sl_main_rewrite_helper_invalidate_sinkables_us : Ref[UInt64] = Ref::new(0UL)

///|
let sl_main_rewrite_helper_collect_effects_cached_calls : Ref[Int] = Ref::new(0)

///|
let sl_main_rewrite_helper_collect_effects_cached_us : Ref[UInt64] = Ref::new(
  0UL,
)

///|
let sl_main_rewrite_helper_collect_effects_cached_hits : Ref[Int] = Ref::new(0)

///|
let sl_main_rewrite_helper_collect_effects_cached_misses : Ref[Int] = Ref::new(
  0,
)

///|
let sl_main_rewrite_helper_texpr_instrs_seen : Ref[Int] = Ref::new(0)

///|
let sl_main_rewrite_helper_texpr_depth_current : Ref[Int] = Ref::new(0)

///|
let sl_main_rewrite_helper_texpr_depth_max : Ref[Int] = Ref::new(0)

///|
let sl_main_rewrite_helper_texpr_single_instr_calls : Ref[Int] = Ref::new(0)

///|
let sl_main_rewrite_helper_block_instr_calls : Ref[Int] = Ref::new(0)

///|
let sl_main_rewrite_helper_loop_instr_calls : Ref[Int] = Ref::new(0)

///|
let sl_main_rewrite_helper_if_instr_calls : Ref[Int] = Ref::new(0)

///|
let sl_main_rewrite_helper_try_table_instr_calls : Ref[Int] = Ref::new(0)

///|
let sl_main_rewrite_helper_max_sinkables : Ref[Int] = Ref::new(0)

///|
let sl_main_rewrite_helper_progress_trace : Ref[(String) -> Unit] = Ref::new(fn(
  _ : String,
) {
  ()
})

///|
let sl_main_rewrite_helper_progress_next_rewrite_calls : Ref[Int] = Ref::new(
  SL_MAIN_REWRITE_PROGRESS_INITIAL_REWRITE_CALLS,
)

///|
let sl_main_rewrite_helper_progress_next_texpr_calls : Ref[Int] = Ref::new(
  SL_MAIN_REWRITE_PROGRESS_INITIAL_TEXPR_CALLS,
)

///|
let sl_main_rewrite_helper_progress_next_depth : Ref[Int] = Ref::new(
  SL_MAIN_REWRITE_PROGRESS_INITIAL_DEPTH,
)

///|
let sl_main_rewrite_helper_progress_emits : Ref[Int] = Ref::new(0)

///|
let sl_hotspot_entries : Ref[Array[SLHotspotEntry]] = Ref::new([])

///|
let sl_rewrite_validation_raw_candidates_attempted : Ref[Int] = Ref::new(0)

///|
let sl_rewrite_validation_candidates_accepted : Ref[Int] = Ref::new(0)

///|
let sl_rewrite_validation_candidates_rejected_local_validation : Ref[Int] = Ref::new(
  0,
)

///|
let sl_rewrite_validation_rejection_reason_buckets : Ref[Map[String, Int]] = Ref::new(
  Map::new(),
)

///|
let sl_rewrite_validation_rejection_trace_limit = 3

///|
let sl_rewrite_validation_rejection_trace_count : Ref[Int] = Ref::new(0)

///|
let sl_rewrite_validation_rejection_trace_suppressed : Ref[Bool] = Ref::new(
  false,
)

///|
fn sl_perf_reset() -> Unit {
  sl_perf_effect_collect_calls.val = 0
  sl_perf_invalidation_entry_checks.val = 0
  sl_perf_get_count_scans.val = 0
  sl_perf_late_state_clones.val = 0
  sl_helper_timing_collect_get_counts_texpr_us.val = 0UL
  sl_helper_timing_collect_get_counts_texpr_calls.val = 0
  sl_helper_timing_simplify_texpr_main_us.val = 0UL
  sl_helper_timing_simplify_texpr_main_calls.val = 0
  sl_helper_timing_remove_unneeded_sets_texpr_us.val = 0UL
  sl_helper_timing_remove_unneeded_sets_texpr_calls.val = 0
  sl_helper_timing_strip_nops_texpr_us.val = 0UL
  sl_helper_timing_strip_nops_texpr_calls.val = 0
  sl_helper_timing_run_late_optimizations_us.val = 0UL
  sl_helper_timing_run_late_optimizations_calls.val = 0
  sl_helper_timing_run_main_phase_us.val = 0UL
  sl_helper_timing_run_main_phase_calls.val = 0
  sl_helper_timing_run_cleanup_phase_us.val = 0UL
  sl_helper_timing_run_cleanup_phase_calls.val = 0
  sl_main_rewrite_helper_trace_enabled.val = false
  sl_main_rewrite_helper_simplify_texpr_calls.val = 0
  sl_main_rewrite_helper_simplify_texpr_us.val = 0UL
  sl_main_rewrite_helper_rewrite_instr_calls.val = 0
  sl_main_rewrite_helper_rewrite_instr_us.val = 0UL
  sl_main_rewrite_helper_try_sink_local_get_calls.val = 0
  sl_main_rewrite_helper_try_sink_local_get_us.val = 0UL
  sl_main_rewrite_helper_invalidate_sinkables_calls.val = 0
  sl_main_rewrite_helper_invalidate_sinkables_us.val = 0UL
  sl_main_rewrite_helper_collect_effects_cached_calls.val = 0
  sl_main_rewrite_helper_collect_effects_cached_us.val = 0UL
  sl_main_rewrite_helper_collect_effects_cached_hits.val = 0
  sl_main_rewrite_helper_collect_effects_cached_misses.val = 0
  sl_main_rewrite_helper_texpr_instrs_seen.val = 0
  sl_main_rewrite_helper_texpr_depth_current.val = 0
  sl_main_rewrite_helper_texpr_depth_max.val = 0
  sl_main_rewrite_helper_texpr_single_instr_calls.val = 0
  sl_main_rewrite_helper_block_instr_calls.val = 0
  sl_main_rewrite_helper_loop_instr_calls.val = 0
  sl_main_rewrite_helper_if_instr_calls.val = 0
  sl_main_rewrite_helper_try_table_instr_calls.val = 0
  sl_main_rewrite_helper_max_sinkables.val = 0
  sl_main_rewrite_helper_progress_trace.val = fn(_ : String) { () }
  sl_main_rewrite_helper_progress_next_rewrite_calls.val = SL_MAIN_REWRITE_PROGRESS_INITIAL_REWRITE_CALLS
  sl_main_rewrite_helper_progress_next_texpr_calls.val = SL_MAIN_REWRITE_PROGRESS_INITIAL_TEXPR_CALLS
  sl_main_rewrite_helper_progress_next_depth.val = SL_MAIN_REWRITE_PROGRESS_INITIAL_DEPTH
  sl_main_rewrite_helper_progress_emits.val = 0
}

///|
fn sl_perf_snapshot() -> SLPerfSnapshot {
  {
    effect_collect_calls: sl_perf_effect_collect_calls.val,
    invalidation_entry_checks: sl_perf_invalidation_entry_checks.val,
    get_count_scans: sl_perf_get_count_scans.val,
    late_state_clones: sl_perf_late_state_clones.val,
  }
}

///|
fn sl_helper_timing_snapshot() -> SLHelperTimingSnapshot {
  {
    collect_get_counts_texpr_us: sl_helper_timing_collect_get_counts_texpr_us.val,
    collect_get_counts_texpr_calls: sl_helper_timing_collect_get_counts_texpr_calls.val,
    simplify_texpr_main_us: sl_helper_timing_simplify_texpr_main_us.val,
    simplify_texpr_main_calls: sl_helper_timing_simplify_texpr_main_calls.val,
    remove_unneeded_sets_texpr_us: sl_helper_timing_remove_unneeded_sets_texpr_us.val,
    remove_unneeded_sets_texpr_calls: sl_helper_timing_remove_unneeded_sets_texpr_calls.val,
    strip_nops_texpr_us: sl_helper_timing_strip_nops_texpr_us.val,
    strip_nops_texpr_calls: sl_helper_timing_strip_nops_texpr_calls.val,
    run_late_optimizations_us: sl_helper_timing_run_late_optimizations_us.val,
    run_late_optimizations_calls: sl_helper_timing_run_late_optimizations_calls.val,
    run_main_phase_us: sl_helper_timing_run_main_phase_us.val,
    run_main_phase_calls: sl_helper_timing_run_main_phase_calls.val,
    run_cleanup_phase_us: sl_helper_timing_run_cleanup_phase_us.val,
    run_cleanup_phase_calls: sl_helper_timing_run_cleanup_phase_calls.val,
  }
}

///|
fn sl_helper_timing_zero() -> SLHelperTimingSnapshot {
  {
    collect_get_counts_texpr_us: 0UL,
    collect_get_counts_texpr_calls: 0,
    simplify_texpr_main_us: 0UL,
    simplify_texpr_main_calls: 0,
    remove_unneeded_sets_texpr_us: 0UL,
    remove_unneeded_sets_texpr_calls: 0,
    strip_nops_texpr_us: 0UL,
    strip_nops_texpr_calls: 0,
    run_late_optimizations_us: 0UL,
    run_late_optimizations_calls: 0,
    run_main_phase_us: 0UL,
    run_main_phase_calls: 0,
    run_cleanup_phase_us: 0UL,
    run_cleanup_phase_calls: 0,
  }
}

///|
fn sl_helper_timing_delta_u64(after : UInt64, before : UInt64) -> UInt64 {
  if after >= before {
    after - before
  } else {
    0UL
  }
}

///|
fn sl_helper_timing_diff(
  after : SLHelperTimingSnapshot,
  before : SLHelperTimingSnapshot,
) -> SLHelperTimingSnapshot {
  {
    collect_get_counts_texpr_us: sl_helper_timing_delta_u64(
      after.collect_get_counts_texpr_us,
      before.collect_get_counts_texpr_us,
    ),
    collect_get_counts_texpr_calls: after.collect_get_counts_texpr_calls -
    before.collect_get_counts_texpr_calls,
    simplify_texpr_main_us: sl_helper_timing_delta_u64(
      after.simplify_texpr_main_us,
      before.simplify_texpr_main_us,
    ),
    simplify_texpr_main_calls: after.simplify_texpr_main_calls -
    before.simplify_texpr_main_calls,
    remove_unneeded_sets_texpr_us: sl_helper_timing_delta_u64(
      after.remove_unneeded_sets_texpr_us,
      before.remove_unneeded_sets_texpr_us,
    ),
    remove_unneeded_sets_texpr_calls: after.remove_unneeded_sets_texpr_calls -
    before.remove_unneeded_sets_texpr_calls,
    strip_nops_texpr_us: sl_helper_timing_delta_u64(
      after.strip_nops_texpr_us,
      before.strip_nops_texpr_us,
    ),
    strip_nops_texpr_calls: after.strip_nops_texpr_calls -
    before.strip_nops_texpr_calls,
    run_late_optimizations_us: sl_helper_timing_delta_u64(
      after.run_late_optimizations_us,
      before.run_late_optimizations_us,
    ),
    run_late_optimizations_calls: after.run_late_optimizations_calls -
    before.run_late_optimizations_calls,
    run_main_phase_us: sl_helper_timing_delta_u64(
      after.run_main_phase_us,
      before.run_main_phase_us,
    ),
    run_main_phase_calls: after.run_main_phase_calls -
    before.run_main_phase_calls,
    run_cleanup_phase_us: sl_helper_timing_delta_u64(
      after.run_cleanup_phase_us,
      before.run_cleanup_phase_us,
    ),
    run_cleanup_phase_calls: after.run_cleanup_phase_calls -
    before.run_cleanup_phase_calls,
  }
}

///|
fn sl_helper_timing_has_nonzero(snapshot : SLHelperTimingSnapshot) -> Bool {
  snapshot.collect_get_counts_texpr_calls > 0 ||
  snapshot.simplify_texpr_main_calls > 0 ||
  snapshot.remove_unneeded_sets_texpr_calls > 0 ||
  snapshot.strip_nops_texpr_calls > 0 ||
  snapshot.run_late_optimizations_calls > 0 ||
  snapshot.run_main_phase_calls > 0 ||
  snapshot.run_cleanup_phase_calls > 0
}

///|
fn sl_main_rewrite_helper_trace_reset() -> Unit {
  sl_main_rewrite_helper_simplify_texpr_calls.val = 0
  sl_main_rewrite_helper_simplify_texpr_us.val = 0UL
  sl_main_rewrite_helper_rewrite_instr_calls.val = 0
  sl_main_rewrite_helper_rewrite_instr_us.val = 0UL
  sl_main_rewrite_helper_try_sink_local_get_calls.val = 0
  sl_main_rewrite_helper_try_sink_local_get_us.val = 0UL
  sl_main_rewrite_helper_invalidate_sinkables_calls.val = 0
  sl_main_rewrite_helper_invalidate_sinkables_us.val = 0UL
  sl_main_rewrite_helper_collect_effects_cached_calls.val = 0
  sl_main_rewrite_helper_collect_effects_cached_us.val = 0UL
  sl_main_rewrite_helper_collect_effects_cached_hits.val = 0
  sl_main_rewrite_helper_collect_effects_cached_misses.val = 0
  sl_main_rewrite_helper_texpr_instrs_seen.val = 0
  sl_main_rewrite_helper_texpr_depth_current.val = 0
  sl_main_rewrite_helper_texpr_depth_max.val = 0
  sl_main_rewrite_helper_texpr_single_instr_calls.val = 0
  sl_main_rewrite_helper_block_instr_calls.val = 0
  sl_main_rewrite_helper_loop_instr_calls.val = 0
  sl_main_rewrite_helper_if_instr_calls.val = 0
  sl_main_rewrite_helper_try_table_instr_calls.val = 0
  sl_main_rewrite_helper_max_sinkables.val = 0
  sl_main_rewrite_helper_progress_next_rewrite_calls.val = SL_MAIN_REWRITE_PROGRESS_INITIAL_REWRITE_CALLS
  sl_main_rewrite_helper_progress_next_texpr_calls.val = SL_MAIN_REWRITE_PROGRESS_INITIAL_TEXPR_CALLS
  sl_main_rewrite_helper_progress_next_depth.val = SL_MAIN_REWRITE_PROGRESS_INITIAL_DEPTH
  sl_main_rewrite_helper_progress_emits.val = 0
}

///|
fn sl_main_rewrite_helper_trace_snapshot() -> SLMainRewriteHelperSnapshot {
  {
    simplify_texpr_calls: sl_main_rewrite_helper_simplify_texpr_calls.val,
    simplify_texpr_us: sl_main_rewrite_helper_simplify_texpr_us.val,
    rewrite_instr_calls: sl_main_rewrite_helper_rewrite_instr_calls.val,
    rewrite_instr_us: sl_main_rewrite_helper_rewrite_instr_us.val,
    try_sink_local_get_calls: sl_main_rewrite_helper_try_sink_local_get_calls.val,
    try_sink_local_get_us: sl_main_rewrite_helper_try_sink_local_get_us.val,
    invalidate_sinkables_calls: sl_main_rewrite_helper_invalidate_sinkables_calls.val,
    invalidate_sinkables_us: sl_main_rewrite_helper_invalidate_sinkables_us.val,
    collect_effects_cached_calls: sl_main_rewrite_helper_collect_effects_cached_calls.val,
    collect_effects_cached_us: sl_main_rewrite_helper_collect_effects_cached_us.val,
    collect_effects_cached_hits: sl_main_rewrite_helper_collect_effects_cached_hits.val,
    collect_effects_cached_misses: sl_main_rewrite_helper_collect_effects_cached_misses.val,
    texpr_instrs_seen: sl_main_rewrite_helper_texpr_instrs_seen.val,
    texpr_depth_max: sl_main_rewrite_helper_texpr_depth_max.val,
    texpr_single_instr_calls: sl_main_rewrite_helper_texpr_single_instr_calls.val,
    block_instr_calls: sl_main_rewrite_helper_block_instr_calls.val,
    loop_instr_calls: sl_main_rewrite_helper_loop_instr_calls.val,
    if_instr_calls: sl_main_rewrite_helper_if_instr_calls.val,
    try_table_instr_calls: sl_main_rewrite_helper_try_table_instr_calls.val,
    max_sinkables: sl_main_rewrite_helper_max_sinkables.val,
    progress_logs_emitted: sl_main_rewrite_helper_progress_emits.val,
  }
}

///|
fn sl_main_rewrite_helper_trace_has_nonzero(
  snapshot : SLMainRewriteHelperSnapshot,
) -> Bool {
  snapshot.simplify_texpr_calls > 0 ||
  snapshot.rewrite_instr_calls > 0 ||
  snapshot.try_sink_local_get_calls > 0 ||
  snapshot.invalidate_sinkables_calls > 0 ||
  snapshot.collect_effects_cached_calls > 0
}

///|
fn sl_main_rewrite_helper_trace_note_sinkables(count : Int) -> Unit {
  if !sl_main_rewrite_helper_trace_enabled.val {
    return
  }
  if count > sl_main_rewrite_helper_max_sinkables.val {
    sl_main_rewrite_helper_max_sinkables.val = count
  }
}

///|
fn sl_main_rewrite_helper_trace_next_threshold(current : Int) -> Int {
  if current < 1 {
    1
  } else {
    current + 1
  }
}

///|
fn sl_main_rewrite_helper_trace_progress_reset(
  trace : (String) -> Unit,
) -> Unit {
  sl_main_rewrite_helper_progress_trace.val = trace
  sl_main_rewrite_helper_progress_next_rewrite_calls.val = SL_MAIN_REWRITE_PROGRESS_INITIAL_REWRITE_CALLS
  sl_main_rewrite_helper_progress_next_texpr_calls.val = SL_MAIN_REWRITE_PROGRESS_INITIAL_TEXPR_CALLS
  sl_main_rewrite_helper_progress_next_depth.val = SL_MAIN_REWRITE_PROGRESS_INITIAL_DEPTH
  sl_main_rewrite_helper_progress_emits.val = 0
}

///|
fn sl_main_rewrite_helper_trace_progress_disable() -> Unit {
  sl_main_rewrite_helper_progress_trace.val = fn(_ : String) { () }
}

///|
fn sl_main_rewrite_helper_trace_progress_maybe_emit(trigger : String) -> Unit {
  if !sl_main_rewrite_helper_trace_enabled.val {
    return
  }
  let rewrite_calls = sl_main_rewrite_helper_rewrite_instr_calls.val
  let texpr_calls = sl_main_rewrite_helper_simplify_texpr_calls.val
  let depth_max = sl_main_rewrite_helper_texpr_depth_max.val
  let mut should_emit = false
  while rewrite_calls >= sl_main_rewrite_helper_progress_next_rewrite_calls.val {
    should_emit = true
    sl_main_rewrite_helper_progress_next_rewrite_calls.val = sl_main_rewrite_helper_trace_next_threshold(
      sl_main_rewrite_helper_progress_next_rewrite_calls.val,
    )
  }
  while texpr_calls >= sl_main_rewrite_helper_progress_next_texpr_calls.val {
    should_emit = true
    sl_main_rewrite_helper_progress_next_texpr_calls.val = sl_main_rewrite_helper_trace_next_threshold(
      sl_main_rewrite_helper_progress_next_texpr_calls.val,
    )
  }
  while depth_max >= sl_main_rewrite_helper_progress_next_depth.val {
    should_emit = true
    sl_main_rewrite_helper_progress_next_depth.val = sl_main_rewrite_helper_trace_next_threshold(
      sl_main_rewrite_helper_progress_next_depth.val,
    )
  }
  if !should_emit {
    return
  }
  sl_main_rewrite_helper_progress_emits.val = sl_main_rewrite_helper_progress_emits.val +
    1
  (sl_main_rewrite_helper_progress_trace.val)(
    "phase=main:rewrite:progress trigger=\{trigger} rewrite_instr_calls=\{rewrite_calls} texpr_calls=\{texpr_calls} texpr_depth_max=\{depth_max} single_instr_texprs=\{sl_main_rewrite_helper_texpr_single_instr_calls.val} control_blocks=\{sl_main_rewrite_helper_block_instr_calls.val} control_loops=\{sl_main_rewrite_helper_loop_instr_calls.val} control_ifs=\{sl_main_rewrite_helper_if_instr_calls.val} control_try_tables=\{sl_main_rewrite_helper_try_table_instr_calls.val} emits=\{sl_main_rewrite_helper_progress_emits.val}",
  )
}

///|
fn sl_main_rewrite_helper_trace_note_instr_kind(instr : TInstr) -> Unit {
  if !sl_main_rewrite_helper_trace_enabled.val {
    return
  }
  match instr.kind {
    TInstrKind::TBlock(_, _) =>
      sl_main_rewrite_helper_block_instr_calls.val = sl_main_rewrite_helper_block_instr_calls.val +
        1
    TInstrKind::TLoop(_, _) =>
      sl_main_rewrite_helper_loop_instr_calls.val = sl_main_rewrite_helper_loop_instr_calls.val +
        1
    TInstrKind::TIf(_, _, _, _) =>
      sl_main_rewrite_helper_if_instr_calls.val = sl_main_rewrite_helper_if_instr_calls.val +
        1
    TInstrKind::TTryTable(_, _, _) =>
      sl_main_rewrite_helper_try_table_instr_calls.val = sl_main_rewrite_helper_try_table_instr_calls.val +
        1
    _ => ()
  }
}

///|
fn sl_main_rewrite_helper_trace_note_texpr_enter(expr : TExpr) -> Unit {
  if !sl_main_rewrite_helper_trace_enabled.val {
    return
  }
  sl_main_rewrite_helper_texpr_depth_current.val = sl_main_rewrite_helper_texpr_depth_current.val +
    1
  let depth = sl_main_rewrite_helper_texpr_depth_current.val
  if depth > sl_main_rewrite_helper_texpr_depth_max.val {
    sl_main_rewrite_helper_texpr_depth_max.val = depth
  }
  if expr.instrs.length() == 1 {
    sl_main_rewrite_helper_texpr_single_instr_calls.val = sl_main_rewrite_helper_texpr_single_instr_calls.val +
      1
  }
}

///|
fn sl_main_rewrite_helper_trace_note_texpr_exit() -> Unit {
  if !sl_main_rewrite_helper_trace_enabled.val {
    return
  }
  if sl_main_rewrite_helper_texpr_depth_current.val > 0 {
    sl_main_rewrite_helper_texpr_depth_current.val = sl_main_rewrite_helper_texpr_depth_current.val -
      1
  }
}

///|
fn sl_is_pathological_fastpath_candidate(
  local_count : Int,
  top_instrs : Int,
) -> Bool {
  local_count >= SL_PATHOLOGICAL_FASTPATH_MIN_LOCALS &&
  top_instrs <= SL_PATHOLOGICAL_FASTPATH_MAX_INSTRS
}

///|
fn sl_is_wide_locals_no_nesting_candidate(
  local_count : Int,
  top_instrs : Int,
) -> Bool {
  local_count >= SL_WIDE_LOCALS_NO_NESTING_MIN_LOCALS &&
  top_instrs <= SL_WIDE_LOCALS_NO_NESTING_MAX_INSTRS
}

///|
fn sl_pathological_budget_exceeded(start_tick : UInt64) -> Bool {
  sl_trace_elapsed_us_since(start_tick) >= SL_PATHOLOGICAL_FUNC_TICK_BUDGET
}

///|
fn sl_hotspot_reset() -> Unit {
  sl_hotspot_entries.val = []
}

///|
fn sl_hotspot_record(
  ordinal : Int,
  main_ticks : UInt64,
  rewrite_ticks : UInt64,
  locals : Int,
  top_instrs : Int,
) -> Unit {
  if main_ticks == 0UL && rewrite_ticks == 0UL {
    return
  }
  let entries = sl_hotspot_entries.val
  entries.push({ ordinal, main_ticks, rewrite_ticks, locals, top_instrs })
  if entries.length() <= SL_HOTSPOT_SUMMARY_LIMIT {
    sl_hotspot_entries.val = entries
    return
  }
  let mut min_idx = 0
  let mut min_ticks = entries[0].main_ticks
  for i = 1; i < entries.length(); i = i + 1 {
    if entries[i].main_ticks < min_ticks {
      min_idx = i
      min_ticks = entries[i].main_ticks
    }
  }
  let trimmed : Array[SLHotspotEntry] = []
  for i = 0; i < entries.length(); i = i + 1 {
    if i != min_idx {
      trimmed.push(entries[i])
    }
  }
  sl_hotspot_entries.val = trimmed
}

///|
fn sl_hotspot_summary_line() -> String? {
  let entries = sl_hotspot_entries.val
  if entries.is_empty() {
    return None
  }
  let ordered = entries.copy()
  let mut i = 0
  while i < ordered.length() {
    let mut j = i + 1
    while j < ordered.length() {
      if ordered[j].main_ticks > ordered[i].main_ticks {
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
      "f\{entry.ordinal}:main=\{entry.main_ticks}:rewrite=\{entry.rewrite_ticks}:locals=\{entry.locals}:top=\{entry.top_instrs}",
    )
    idx += 1
  }
  Some(out.to_string())
}

///|
fn sl_rewrite_validation_bucket_for_error(err : String) -> String {
  if err.contains("invalid local index") {
    return "invalid_local_index"
  }
  if err.contains("result type mismatch") {
    return "result_type_mismatch"
  }
  if err.contains("wrong result arity") {
    return "result_arity_mismatch"
  }
  if err.contains("FunctionLocals::from_typed_func") ||
    err.contains("typed locals") {
    return "typed_locals_mismatch"
  }
  "other"
}

///|
fn sl_rewrite_validation_record_rejection_reason(err : String) -> Unit {
  let bucket = sl_rewrite_validation_bucket_for_error(err)
  let buckets = sl_rewrite_validation_rejection_reason_buckets.val
  match buckets.get(bucket) {
    Some(count) => buckets[bucket] = count + 1
    None => buckets[bucket] = 1
  }
  sl_rewrite_validation_rejection_reason_buckets.val = buckets
}

///|
fn sl_rewrite_validation_reset() -> Unit {
  sl_rewrite_validation_raw_candidates_attempted.val = 0
  sl_rewrite_validation_candidates_accepted.val = 0
  sl_rewrite_validation_candidates_rejected_local_validation.val = 0
  sl_rewrite_validation_rejection_reason_buckets.val = Map::new()
  sl_rewrite_validation_rejection_trace_count.val = 0
  sl_rewrite_validation_rejection_trace_suppressed.val = false
}

///|
fn sl_trace_rewrite_validation_failure(
  trace : (String) -> Unit,
  msg : String,
) -> Unit {
  if sl_rewrite_validation_rejection_trace_count.val <
    sl_rewrite_validation_rejection_trace_limit {
    sl_rewrite_validation_rejection_trace_count.val = sl_rewrite_validation_rejection_trace_count.val +
      1
    trace(msg)
    return
  }
  if !sl_rewrite_validation_rejection_trace_suppressed.val {
    sl_rewrite_validation_rejection_trace_suppressed.val = true
    trace("additional rewrite rejection logs suppressed")
  }
}

///|
fn sl_rewrite_validation_snapshot() -> SLRewriteValidationSnapshot {
  {
    raw_candidates_attempted: sl_rewrite_validation_raw_candidates_attempted.val,
    candidates_accepted: sl_rewrite_validation_candidates_accepted.val,
    candidates_rejected_local_validation: sl_rewrite_validation_candidates_rejected_local_validation.val,
    rejection_reason_buckets: sl_rewrite_validation_rejection_reason_buckets.val.copy(),
  }
}

///|
fn sl_collect_effects_counted(instr : TInstr) -> LCSEffects {
  sl_perf_effect_collect_calls.val = sl_perf_effect_collect_calls.val + 1
  lcs_collect_effects(instr)
}

///|
fn sl_collect_effects_cached(
  instr : TInstr,
  effects_cache : Map[TInstr, LCSEffects],
) -> LCSEffects {
  let trace_main_rewrite = sl_main_rewrite_helper_trace_enabled.val
  let start_us = if trace_main_rewrite { sl_trace_now_us() } else { 0UL }
  if trace_main_rewrite {
    sl_main_rewrite_helper_collect_effects_cached_calls.val = sl_main_rewrite_helper_collect_effects_cached_calls.val +
      1
  }
  let effects = match effects_cache.get(instr) {
    Some(cached) => {
      if trace_main_rewrite {
        sl_main_rewrite_helper_collect_effects_cached_hits.val = sl_main_rewrite_helper_collect_effects_cached_hits.val +
          1
      }
      cached
    }
    None => {
      if trace_main_rewrite {
        sl_main_rewrite_helper_collect_effects_cached_misses.val = sl_main_rewrite_helper_collect_effects_cached_misses.val +
          1
      }
      let computed = sl_collect_effects_counted(instr)
      effects_cache[instr] = computed
      computed
    }
  }
  if trace_main_rewrite {
    sl_main_rewrite_helper_collect_effects_cached_us.val = sl_main_rewrite_helper_collect_effects_cached_us.val +
      sl_trace_elapsed_us_since(start_us)
  }
  effects
}

///|
fn sl_trace_noop(_ : String) -> Unit {
  ()
}

///|
fn sl_trace_now_ms() -> UInt64 {
  pass_trace_now_ms()
}

///|
fn sl_trace_now_us() -> UInt64 {
  pass_trace_now_us()
}

///|
fn sl_trace_elapsed_ms(start_ms : UInt64) -> UInt64 {
  pass_trace_elapsed_ms(start_ms)
}

///|
fn sl_trace_elapsed_us_since(start_us : UInt64) -> UInt64 {
  pass_trace_elapsed_us_since(start_us)
}

///|
fn sl_trace_delta_us_to_ms(delta_us : UInt64) -> UInt64 {
  pass_trace_delta_us_to_ms(delta_us)
}

///|
fn sl_helper_timing_commit(
  enabled : Bool,
  elapsed_us : Ref[UInt64],
  calls : Ref[Int],
  start_us : UInt64,
) -> Unit {
  if !enabled {
    return
  }
  elapsed_us.val = elapsed_us.val + sl_trace_elapsed_us_since(start_us)
  calls.val = calls.val + 1
}

///|
fn sl_trace_emit_helper_timing(
  trace : (String) -> Unit,
  ordinal : Int,
  timing : SLHelperTimingSnapshot,
) -> Unit {
  if !sl_helper_timing_has_nonzero(timing) {
    return
  }
  trace(
    "func[\{ordinal}] helper_timing count_gets_ms=\{sl_trace_delta_us_to_ms(timing.collect_get_counts_texpr_us)} count_gets_calls=\{timing.collect_get_counts_texpr_calls} rewrite_ms=\{sl_trace_delta_us_to_ms(timing.simplify_texpr_main_us)} rewrite_calls=\{timing.simplify_texpr_main_calls} remove_sets_ms=\{sl_trace_delta_us_to_ms(timing.remove_unneeded_sets_texpr_us)} remove_sets_calls=\{timing.remove_unneeded_sets_texpr_calls} strip_nops_ms=\{sl_trace_delta_us_to_ms(timing.strip_nops_texpr_us)} strip_nops_calls=\{timing.strip_nops_texpr_calls} late_ms=\{sl_trace_delta_us_to_ms(timing.run_late_optimizations_us)} late_calls=\{timing.run_late_optimizations_calls} main_phase_ms=\{sl_trace_delta_us_to_ms(timing.run_main_phase_us)} main_phase_calls=\{timing.run_main_phase_calls} cleanup_phase_ms=\{sl_trace_delta_us_to_ms(timing.run_cleanup_phase_us)} cleanup_phase_calls=\{timing.run_cleanup_phase_calls}",
  )
}

///|
fn sl_trace_emit_main_rewrite_helper_timing(
  trace : (String) -> Unit,
  snapshot : SLMainRewriteHelperSnapshot,
) -> Unit {
  if !sl_main_rewrite_helper_trace_has_nonzero(snapshot) {
    return
  }
  trace(
    "phase=main:rewrite:helpers texpr_ms=\{sl_trace_delta_us_to_ms(snapshot.simplify_texpr_us)} texpr_calls=\{snapshot.simplify_texpr_calls} texpr_instrs=\{snapshot.texpr_instrs_seen} texpr_depth_max=\{snapshot.texpr_depth_max} texpr_single_instr_calls=\{snapshot.texpr_single_instr_calls} rewrite_instr_ms=\{sl_trace_delta_us_to_ms(snapshot.rewrite_instr_us)} rewrite_instr_calls=\{snapshot.rewrite_instr_calls} control_blocks=\{snapshot.block_instr_calls} control_loops=\{snapshot.loop_instr_calls} control_ifs=\{snapshot.if_instr_calls} control_try_tables=\{snapshot.try_table_instr_calls} sink_get_ms=\{sl_trace_delta_us_to_ms(snapshot.try_sink_local_get_us)} sink_get_calls=\{snapshot.try_sink_local_get_calls} invalidate_ms=\{sl_trace_delta_us_to_ms(snapshot.invalidate_sinkables_us)} invalidate_calls=\{snapshot.invalidate_sinkables_calls} effects_cached_ms=\{sl_trace_delta_us_to_ms(snapshot.collect_effects_cached_us)} effects_cached_calls=\{snapshot.collect_effects_cached_calls} effects_hits=\{snapshot.collect_effects_cached_hits} effects_misses=\{snapshot.collect_effects_cached_misses} max_sinkables=\{snapshot.max_sinkables} progress_logs=\{snapshot.progress_logs_emitted}",
  )
}

///|
fn sl_collect_local_stats_instr(instr : TInstr, stats : SLLocalStats) -> Unit {
  match instr.kind {
    TInstrKind::TLocalSet(_, value) => {
      stats.sets += 1
      sl_collect_local_stats_instr(value, stats)
    }
    TInstrKind::TLocalTee(_, value) => {
      stats.tees += 1
      sl_collect_local_stats_instr(value, stats)
    }
    TInstrKind::TLocalGet(_) => stats.gets += 1
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) =>
      sl_collect_local_stats_texpr(body, stats)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      sl_collect_local_stats_instr(cond, stats)
      sl_collect_local_stats_texpr(then_body, stats)
      match else_body {
        Some(other) => sl_collect_local_stats_texpr(other, stats)
        None => ()
      }
    }
    _ =>
      for child in eval_children(instr) {
        sl_collect_local_stats_instr(child, stats)
      }
  }
}

///|
fn sl_collect_local_stats_texpr(expr : TExpr, stats : SLLocalStats) -> Unit {
  for instr in expr.instrs {
    sl_collect_local_stats_instr(instr, stats)
  }
}

///|
fn sl_count_local_tees_texpr(expr : TExpr) -> Int {
  let stats = SLLocalStats::new()
  sl_collect_local_stats_texpr(expr, stats)
  stats.tees
}

///|
fn sl_count_all_instrs_instr(instr : TInstr) -> Int {
  let mut total = 1
  for child in eval_children(instr) {
    total += sl_count_all_instrs_instr(child)
  }
  total
}

///|
fn sl_count_all_instrs_texpr(expr : TExpr) -> Int {
  let mut total = 0
  for instr in expr.instrs {
    total += sl_count_all_instrs_instr(instr)
  }
  total
}

///|
fn sl_has_result_if_instr(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TIf(ValTypeBlockType(_), _, _, _) => true
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) => sl_has_result_if_texpr(body)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      if sl_has_result_if_instr(cond) || sl_has_result_if_texpr(then_body) {
        return true
      }
      match else_body {
        Some(other) => sl_has_result_if_texpr(other)
        None => false
      }
    }
    _ => {
      for child in eval_children(instr) {
        if sl_has_result_if_instr(child) {
          return true
        }
      }
      false
    }
  }
}

///|
fn sl_has_result_if_texpr(expr : TExpr) -> Bool {
  for instr in expr.instrs {
    if sl_has_result_if_instr(instr) {
      return true
    }
  }
  false
}

///|
fn sl_count_local_gets_for_idx_instr(instr : TInstr, idx : Int) -> Int {
  let mut total = 0
  match instr.kind {
    TInstrKind::TLocalGet(local_idx) =>
      if sl_localidx_to_int(local_idx) == idx {
        total += 1
      }
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) =>
      total += sl_count_local_gets_for_idx_texpr(body, idx)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      total += sl_count_local_gets_for_idx_instr(cond, idx)
      total += sl_count_local_gets_for_idx_texpr(then_body, idx)
      match else_body {
        Some(other) => total += sl_count_local_gets_for_idx_texpr(other, idx)
        None => ()
      }
    }
    _ =>
      for child in eval_children(instr) {
        total += sl_count_local_gets_for_idx_instr(child, idx)
      }
  }
  total
}

///|
fn sl_count_local_gets_for_idx_texpr(expr : TExpr, idx : Int) -> Int {
  let mut total = 0
  for instr in expr.instrs {
    total += sl_count_local_gets_for_idx_instr(instr, idx)
  }
  total
}

///|
fn sl_has_local_set_for_idx_instr(instr : TInstr, idx : Int) -> Bool {
  match instr.kind {
    TInstrKind::TLocalSet(local_idx, value)
    | TInstrKind::TLocalTee(local_idx, value) => {
      if sl_localidx_to_int(local_idx) == idx {
        return true
      }
      sl_has_local_set_for_idx_instr(value, idx)
    }
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) =>
      sl_has_local_set_for_idx_texpr(body, idx)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      if sl_has_local_set_for_idx_instr(cond, idx) ||
        sl_has_local_set_for_idx_texpr(then_body, idx) {
        return true
      }
      match else_body {
        Some(other) => sl_has_local_set_for_idx_texpr(other, idx)
        None => false
      }
    }
    _ => {
      for child in eval_children(instr) {
        if sl_has_local_set_for_idx_instr(child, idx) {
          return true
        }
      }
      false
    }
  }
}

///|
fn sl_has_local_set_for_idx_texpr(expr : TExpr, idx : Int) -> Bool {
  for instr in expr.instrs {
    if sl_has_local_set_for_idx_instr(instr, idx) {
      return true
    }
  }
  false
}

///|
fn sl_count_local_sets_for_idx_instr(instr : TInstr, idx : Int) -> Int {
  let mut total = 0
  match instr.kind {
    TInstrKind::TLocalSet(local_idx, value)
    | TInstrKind::TLocalTee(local_idx, value) => {
      if sl_localidx_to_int(local_idx) == idx {
        total += 1
      }
      total += sl_count_local_sets_for_idx_instr(value, idx)
    }
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) =>
      total += sl_count_local_sets_for_idx_texpr(body, idx)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      total += sl_count_local_sets_for_idx_instr(cond, idx)
      total += sl_count_local_sets_for_idx_texpr(then_body, idx)
      match else_body {
        Some(other) => total += sl_count_local_sets_for_idx_texpr(other, idx)
        None => ()
      }
    }
    _ =>
      for child in eval_children(instr) {
        total += sl_count_local_sets_for_idx_instr(child, idx)
      }
  }
  total
}

///|
fn sl_count_local_sets_for_idx_texpr(expr : TExpr, idx : Int) -> Int {
  let mut total = 0
  for instr in expr.instrs {
    total += sl_count_local_sets_for_idx_instr(instr, idx)
  }
  total
}

///|
fn sl_has_result_block_instr(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TBlock(ValTypeBlockType(_), _) => true
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) => sl_has_result_block_texpr(body)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      if sl_has_result_block_instr(cond) || sl_has_result_block_texpr(then_body) {
        return true
      }
      match else_body {
        Some(other) => sl_has_result_block_texpr(other)
        None => false
      }
    }
    _ => {
      for child in eval_children(instr) {
        if sl_has_result_block_instr(child) {
          return true
        }
      }
      false
    }
  }
}

///|
fn sl_has_result_block_texpr(expr : TExpr) -> Bool {
  for instr in expr.instrs {
    if sl_has_result_block_instr(instr) {
      return true
    }
  }
  false
}

///|
fn sl_has_result_loop_instr(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TLoop(ValTypeBlockType(_), _) => true
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) => sl_has_result_loop_texpr(body)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      if sl_has_result_loop_instr(cond) || sl_has_result_loop_texpr(then_body) {
        return true
      }
      match else_body {
        Some(other) => sl_has_result_loop_texpr(other)
        None => false
      }
    }
    _ => {
      for child in eval_children(instr) {
        if sl_has_result_loop_instr(child) {
          return true
        }
      }
      false
    }
  }
}

///|
fn sl_has_result_loop_texpr(expr : TExpr) -> Bool {
  for instr in expr.instrs {
    if sl_has_result_loop_instr(instr) {
      return true
    }
  }
  false
}

///|
fn sl_has_br_if_with_tee_value_instr(instr : TInstr, idx : Int) -> Bool {
  match instr.kind {
    TInstrKind::TBrIf(_, _, [{ kind: TInstrKind::TLocalTee(local_idx, _), .. }]) =>
      sl_localidx_to_int(local_idx) == idx
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) =>
      sl_has_br_if_with_tee_value_texpr(body, idx)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      if sl_has_br_if_with_tee_value_instr(cond, idx) ||
        sl_has_br_if_with_tee_value_texpr(then_body, idx) {
        return true
      }
      match else_body {
        Some(other) => sl_has_br_if_with_tee_value_texpr(other, idx)
        None => false
      }
    }
    _ => {
      for child in eval_children(instr) {
        if sl_has_br_if_with_tee_value_instr(child, idx) {
          return true
        }
      }
      false
    }
  }
}

///|
fn sl_has_br_if_with_tee_value_texpr(expr : TExpr, idx : Int) -> Bool {
  for instr in expr.instrs {
    if sl_has_br_if_with_tee_value_instr(instr, idx) {
      return true
    }
  }
  false
}

///|
fn sl_has_any_br_if_with_tee_value_instr(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TBrIf(_, _, [{ kind: TInstrKind::TLocalTee(_, _), .. }]) => true
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) =>
      sl_has_any_br_if_with_tee_value_texpr(body)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      if sl_has_any_br_if_with_tee_value_instr(cond) ||
        sl_has_any_br_if_with_tee_value_texpr(then_body) {
        return true
      }
      match else_body {
        Some(other) => sl_has_any_br_if_with_tee_value_texpr(other)
        None => false
      }
    }
    _ => {
      for child in eval_children(instr) {
        if sl_has_any_br_if_with_tee_value_instr(child) {
          return true
        }
      }
      false
    }
  }
}

///|
fn sl_has_any_br_if_with_tee_value_texpr(expr : TExpr) -> Bool {
  for instr in expr.instrs {
    if sl_has_any_br_if_with_tee_value_instr(instr) {
      return true
    }
  }
  false
}

///|
priv struct SLSimplifyOptions {
  allow_tee : Bool
  allow_structure : Bool
  allow_nesting : Bool
}

///|
priv struct SLDeepControlShapeStats {
  mut max_depth : Int
  mut control_nodes : Int
}

///|
fn SLDeepControlShapeStats::new() -> SLDeepControlShapeStats {
  { max_depth: 0, control_nodes: 0 }
}

///|
fn sl_collect_deep_control_shape_stats_instr(
  instr : TInstr,
  depth : Int,
  stats : SLDeepControlShapeStats,
) -> Unit {
  if depth > stats.max_depth {
    stats.max_depth = depth
  }
  match instr.kind {
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) => {
      stats.control_nodes += 1
      sl_collect_deep_control_shape_stats_texpr(body, depth + 1, stats)
    }
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      stats.control_nodes += 1
      sl_collect_deep_control_shape_stats_instr(cond, depth + 1, stats)
      sl_collect_deep_control_shape_stats_texpr(then_body, depth + 1, stats)
      match else_body {
        Some(other) =>
          sl_collect_deep_control_shape_stats_texpr(other, depth + 1, stats)
        None => ()
      }
    }
    _ =>
      for child in eval_children(instr) {
        sl_collect_deep_control_shape_stats_instr(child, depth, stats)
      }
  }
}

///|
fn sl_collect_deep_control_shape_stats_texpr(
  expr : TExpr,
  depth : Int,
  stats : SLDeepControlShapeStats,
) -> Unit {
  for instr in expr.instrs {
    sl_collect_deep_control_shape_stats_instr(instr, depth, stats)
  }
}

///|
fn sl_main_is_pathological_deep_control_candidate(
  body : TExpr,
  local_count : Int,
  options : SLSimplifyOptions,
) -> (Bool, Int, Int) {
  if options.allow_tee || options.allow_structure || !options.allow_nesting {
    return (false, 0, 0)
  }
  let top_instrs = body.instrs.length()
  let narrow_shape = top_instrs <= SL_MAIN_REWRITE_DEEP_CONTROL_MAX_TOP_INSTRS &&
    local_count <= SL_MAIN_REWRITE_DEEP_CONTROL_MAX_LOCALS
  let wide_shape = top_instrs <=
    SL_MAIN_REWRITE_DEEP_CONTROL_WIDE_LOCALS_MAX_TOP_INSTRS &&
    local_count >= SL_MAIN_REWRITE_DEEP_CONTROL_WIDE_LOCALS_MIN_LOCALS
  if !narrow_shape && !wide_shape {
    return (false, 0, 0)
  }
  let stats = SLDeepControlShapeStats::new()
  sl_collect_deep_control_shape_stats_texpr(body, 0, stats)
  let narrow_pathological = narrow_shape &&
    stats.max_depth >= SL_MAIN_REWRITE_DEEP_CONTROL_MIN_DEPTH &&
    stats.control_nodes >= SL_MAIN_REWRITE_DEEP_CONTROL_MIN_CONTROL_NODES
  let wide_pathological = wide_shape &&
    stats.max_depth >= SL_MAIN_REWRITE_DEEP_CONTROL_WIDE_LOCALS_MIN_DEPTH &&
    stats.control_nodes >=
    SL_MAIN_REWRITE_DEEP_CONTROL_WIDE_LOCALS_MIN_CONTROL_NODES
  (
    narrow_pathological || wide_pathological,
    stats.max_depth,
    stats.control_nodes,
  )
}

///|
priv enum SLMainGetCountsStorage {
  Dense(Array[Int])
  Sparse(Map[Int, Int])
}

///|
priv struct SLMainGetCounts {
  local_count : Int
  storage : SLMainGetCountsStorage
}

///|
fn sl_main_get_counts_new(local_count : Int, sparse : Bool) -> SLMainGetCounts {
  if sparse {
    { local_count, storage: Sparse(Map::new()) }
  } else {
    { local_count, storage: Dense(Array::make(local_count, 0)) }
  }
}

///|
fn sl_main_get_counts_get(counts : SLMainGetCounts, idx : Int) -> Int {
  if idx < 0 || idx >= counts.local_count {
    return 0
  }
  match counts.storage {
    Dense(values) => values[idx]
    Sparse(values) =>
      match values.get(idx) {
        Some(v) => v
        None => 0
      }
  }
}

///|
fn sl_main_get_counts_has_any(counts : SLMainGetCounts) -> Bool {
  match counts.storage {
    Dense(values) =>
      for v in values {
        if v > 0 {
          return true
        }
      }
    Sparse(values) => return values.length() > 0
  }
  false
}

///|
fn sl_main_get_counts_adjust_idx(
  counts : SLMainGetCounts,
  idx : LocalIdx,
  delta : Int,
) -> Unit {
  let i = sl_localidx_to_int(idx)
  if i < 0 || i >= counts.local_count {
    return
  }
  match counts.storage {
    Dense(values) => {
      let next = values[i] + delta
      values[i] = if next < 0 { 0 } else { next }
    }
    Sparse(values) => {
      let curr = match values.get(i) {
        Some(v) => v
        None => 0
      }
      let next = curr + delta
      if next <= 0 {
        values.remove(i)
      } else {
        values[i] = next
      }
    }
  }
}

///|
fn sl_main_collect_get_counts_instr(
  instr : TInstr,
  counts : SLMainGetCounts,
) -> Unit {
  match instr.kind {
    TInstrKind::TLocalGet(idx) => sl_main_get_counts_adjust_idx(counts, idx, 1)
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) =>
      sl_main_collect_get_counts_texpr(body, counts)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      sl_main_collect_get_counts_instr(cond, counts)
      sl_main_collect_get_counts_texpr(then_body, counts)
      match else_body {
        Some(other) => sl_main_collect_get_counts_texpr(other, counts)
        None => ()
      }
    }
    _ =>
      for child in eval_children(instr) {
        sl_main_collect_get_counts_instr(child, counts)
      }
  }
}

///|
fn sl_main_collect_get_counts_texpr(
  expr : TExpr,
  counts : SLMainGetCounts,
) -> Unit {
  sl_perf_get_count_scans.val = sl_perf_get_count_scans.val + 1
  for instr in expr.instrs {
    sl_main_collect_get_counts_instr(instr, counts)
  }
}

///|
fn sl_main_collect_no_tee_rewrite_opportunity_instr(
  instr : TInstr,
  get_counts : SLMainGetCounts,
  saw_single_use_set : Ref[Bool],
  saw_drop_local_tee : Ref[Bool],
) -> Unit {
  if saw_single_use_set.val && saw_drop_local_tee.val {
    return
  }
  match instr.kind {
    TInstrKind::TLocalSet(idx, value) | TInstrKind::TLocalTee(idx, value) => {
      if !saw_single_use_set.val {
        let key = sl_localidx_to_int(idx)
        if key >= 0 &&
          key < get_counts.local_count &&
          sl_main_get_counts_get(get_counts, key) == 1 {
          saw_single_use_set.val = true
        }
      }
      sl_main_collect_no_tee_rewrite_opportunity_instr(
        value, get_counts, saw_single_use_set, saw_drop_local_tee,
      )
    }
    TInstrKind::TDrop(value) => {
      if !saw_drop_local_tee.val {
        match value.kind {
          TInstrKind::TLocalTee(_, _) => saw_drop_local_tee.val = true
          _ => ()
        }
      }
      sl_main_collect_no_tee_rewrite_opportunity_instr(
        value, get_counts, saw_single_use_set, saw_drop_local_tee,
      )
    }
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) =>
      sl_main_collect_no_tee_rewrite_opportunity_texpr(
        body, get_counts, saw_single_use_set, saw_drop_local_tee,
      )
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      sl_main_collect_no_tee_rewrite_opportunity_instr(
        cond, get_counts, saw_single_use_set, saw_drop_local_tee,
      )
      sl_main_collect_no_tee_rewrite_opportunity_texpr(
        then_body, get_counts, saw_single_use_set, saw_drop_local_tee,
      )
      match else_body {
        Some(other) =>
          sl_main_collect_no_tee_rewrite_opportunity_texpr(
            other, get_counts, saw_single_use_set, saw_drop_local_tee,
          )
        None => ()
      }
    }
    _ =>
      for child in eval_children(instr) {
        sl_main_collect_no_tee_rewrite_opportunity_instr(
          child, get_counts, saw_single_use_set, saw_drop_local_tee,
        )
      }
  }
}

///|
fn sl_main_collect_no_tee_rewrite_opportunity_texpr(
  expr : TExpr,
  get_counts : SLMainGetCounts,
  saw_single_use_set : Ref[Bool],
  saw_drop_local_tee : Ref[Bool],
) -> Unit {
  if saw_single_use_set.val && saw_drop_local_tee.val {
    return
  }
  for instr in expr.instrs {
    sl_main_collect_no_tee_rewrite_opportunity_instr(
      instr, get_counts, saw_single_use_set, saw_drop_local_tee,
    )
    if saw_single_use_set.val && saw_drop_local_tee.val {
      return
    }
  }
}

///|
fn sl_main_has_no_tee_rewrite_opportunity(
  expr : TExpr,
  get_counts : SLMainGetCounts,
) -> (Bool, Bool, Bool) {
  let saw_single_use_set = Ref::new(false)
  let saw_drop_local_tee = Ref::new(false)
  sl_main_collect_no_tee_rewrite_opportunity_texpr(
    expr, get_counts, saw_single_use_set, saw_drop_local_tee,
  )
  (
    saw_single_use_set.val || saw_drop_local_tee.val,
    saw_single_use_set.val,
    saw_drop_local_tee.val,
  )
}

///|
priv struct SLSinkableInfo {
  out_index : Int
  value : TInstr
  effects : LCSEffects
}

///|
priv struct SLSinkableIndexes {
  reads_by_local : Map[Int, Set[Int]]
  writes_by_local : Map[Int, Set[Int]]
}

///|
fn sl_sinkable_indexes_new() -> SLSinkableIndexes {
  { reads_by_local: Map::new(), writes_by_local: Map::new() }
}

///|
fn sl_sinkable_index_add(
  index : Map[Int, Set[Int]],
  local_i : Int,
  sinkable_i : Int,
) -> Unit {
  if local_i < 0 {
    return
  }
  match index.get(local_i) {
    Some(existing) => {
      existing.add(sinkable_i)
      index[local_i] = existing
    }
    None => {
      let created = Set::new()
      created.add(sinkable_i)
      index[local_i] = created
    }
  }
}

///|
fn sl_sinkable_index_remove(
  index : Map[Int, Set[Int]],
  local_i : Int,
  sinkable_i : Int,
) -> Unit {
  if local_i < 0 {
    return
  }
  match index.get(local_i) {
    Some(existing) => {
      existing.remove(sinkable_i)
      if existing.length() == 0 {
        index.remove(local_i)
      } else {
        index[local_i] = existing
      }
    }
    None => ()
  }
}

///|
fn sl_sinkables_add(
  sinkables : Map[Int, SLSinkableInfo],
  indexes : SLSinkableIndexes,
  sinkable_i : Int,
  info : SLSinkableInfo,
) -> Unit {
  sinkables[sinkable_i] = info
  for local_idx in info.effects.locals_read {
    sl_sinkable_index_add(
      indexes.reads_by_local,
      sl_localidx_to_int(local_idx),
      sinkable_i,
    )
  }
  for local_idx in info.effects.locals_written {
    sl_sinkable_index_add(
      indexes.writes_by_local,
      sl_localidx_to_int(local_idx),
      sinkable_i,
    )
  }
}

///|
fn sl_sinkables_remove(
  sinkables : Map[Int, SLSinkableInfo],
  indexes : SLSinkableIndexes,
  sinkable_i : Int,
) -> Unit {
  match sinkables.get(sinkable_i) {
    Some(info) => {
      for local_idx in info.effects.locals_read {
        sl_sinkable_index_remove(
          indexes.reads_by_local,
          sl_localidx_to_int(local_idx),
          sinkable_i,
        )
      }
      for local_idx in info.effects.locals_written {
        sl_sinkable_index_remove(
          indexes.writes_by_local,
          sl_localidx_to_int(local_idx),
          sinkable_i,
        )
      }
      sinkables.remove(sinkable_i)
    }
    None => ()
  }
}

///|
fn sl_localidx_to_int(idx : LocalIdx) -> Int {
  let LocalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn sl_localidx_from_int(idx : Int) -> LocalIdx {
  LocalIdx::new(idx.reinterpret_as_uint())
}

///|
fn sl_instr_is_direct_local_set_for_idx(instr : TInstr, idx : Int) -> Bool {
  match instr.kind {
    TInstrKind::TLocalSet(local_idx, _) => sl_localidx_to_int(local_idx) == idx
    _ => false
  }
}

///|
fn sl_labelidx_to_int(label : LabelIdx) -> Int {
  let LabelIdx(raw) = label
  raw.reinterpret_as_int()
}

///|
fn sl_collect_param_types(mod : Module) -> Array[Array[ValType]] {
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
fn sl_require_typed_function_locals(
  declared_params : Array[ValType],
  typed_params : Array[ValType],
  typed_body_locals : Array[ValType],
  context : String,
) -> FunctionLocals {
  match
    FunctionLocals::from_typed_func(
      declared_params, typed_params, typed_body_locals,
    ) {
    Ok(locals) => locals
    Err(e) => abort("simplify_locals \{context}: \{e}")
  }
}

///|
fn sl_is_defaultable(vt : ValType) -> Bool {
  match vt {
    RefTypeValType(rt) => rt.is_defaultable()
    _ => true
  }
}

///|
fn sl_block_results(env : Env, bt : BlockType) -> Array[ValType] {
  match env.expand_blocktype(bt) {
    Ok((_, results)) => results
    Err(_) => []
  }
}

///|
fn sl_loop_params(env : Env, bt : BlockType) -> Array[ValType] {
  match env.expand_blocktype(bt) {
    Ok((params, _)) => params
    Err(_) => []
  }
}

///|
fn sl_block_body_env(env : Env, bt : BlockType) -> Env {
  env.with_label(sl_block_results(env, bt))
}

///|
fn sl_loop_body_env(env : Env, bt : BlockType) -> Env {
  env.with_label(sl_loop_params(env, bt))
}

///|
fn sl_typecheck_instr_empty_stack(
  instr : TInstr,
  env : Env,
) -> Result[TcState, String] {
  Typecheck::typecheck(instr, make_state(env, []))
}

///|
fn sl_can_emit_rewritten_instr(instr : TInstr, env : Env) -> Bool {
  match sl_typecheck_instr_empty_stack(instr, env) {
    Ok(state) => state.stack.is_empty()
    Err(_) => false
  }
}

///|
fn sl_sink_value_preserves_local_get_type(
  value : TInstr,
  env : Env,
  local_type : ValType,
) -> Bool {
  match
    (
      sl_typecheck_instr_empty_stack(value, env),
      lcs_infer_tinstr_type(value, env),
    ) {
    (Ok(state), Some(vt)) =>
      state.reachable &&
      state.stack.length() == 1 &&
      (vt == local_type || Match::matches(vt, local_type, env))
    _ => false
  }
}

///|
fn sl_can_emit_typed_local_set(
  idx : LocalIdx,
  local_type : ValType,
  value : TInstr,
  env : Env,
) -> Bool {
  match (env.get_local_type(idx), lcs_infer_tinstr_type(value, env)) {
    (Some(dest_type), Some(value_type)) =>
      dest_type == local_type &&
      value_type == local_type &&
      sl_can_emit_rewritten_instr(TInstr::local_set(idx, value), env)
    _ => false
  }
}

///|
fn sl_can_emit_typed_local_tee(
  idx : LocalIdx,
  local_type : ValType,
  value : TInstr,
  env : Env,
) -> Bool {
  match env.get_local_type(idx) {
    Some(dest_type) =>
      dest_type == local_type &&
      sl_sink_value_preserves_local_get_type(value, env, local_type)
    _ => false
  }
}

///|
fn sl_collect_sinkable_effects(idx : LocalIdx, value : TInstr) -> LCSEffects {
  sl_collect_effects_counted(TInstr::local_set(idx, value))
}

///|
fn sl_adjust_get_count_for_idx(
  counts : Array[Int],
  idx : LocalIdx,
  delta : Int,
) -> Unit {
  let i = sl_localidx_to_int(idx)
  if i < 0 || i >= counts.length() {
    return
  }
  let next = counts[i] + delta
  counts[i] = if next < 0 { 0 } else { next }
}

///|
fn sl_adjust_get_counts_instr(
  instr : TInstr,
  counts : Array[Int],
  delta : Int,
) -> Unit {
  match instr.kind {
    TInstrKind::TLocalGet(idx) =>
      sl_adjust_get_count_for_idx(counts, idx, delta)
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) =>
      sl_adjust_get_counts_texpr(body, counts, delta)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      sl_adjust_get_counts_instr(cond, counts, delta)
      sl_adjust_get_counts_texpr(then_body, counts, delta)
      match else_body {
        Some(other) => sl_adjust_get_counts_texpr(other, counts, delta)
        None => ()
      }
    }
    _ =>
      for child in eval_children(instr) {
        sl_adjust_get_counts_instr(child, counts, delta)
      }
  }
}

///|
fn sl_adjust_get_counts_texpr(
  expr : TExpr,
  counts : Array[Int],
  delta : Int,
) -> Unit {
  for instr in expr.instrs {
    sl_adjust_get_counts_instr(instr, counts, delta)
  }
}

///|
fn sl_collect_get_counts_instr(instr : TInstr, counts : Array[Int]) -> Unit {
  match instr.kind {
    TInstrKind::TLocalGet(idx) => {
      let i = sl_localidx_to_int(idx)
      if i >= 0 && i < counts.length() {
        counts[i] += 1
      }
    }
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) =>
      sl_collect_get_counts_texpr(body, counts)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      sl_collect_get_counts_instr(cond, counts)
      sl_collect_get_counts_texpr(then_body, counts)
      match else_body {
        Some(other) => sl_collect_get_counts_texpr(other, counts)
        None => ()
      }
    }
    _ =>
      for child in eval_children(instr) {
        sl_collect_get_counts_instr(child, counts)
      }
  }
}

///|
fn sl_collect_get_counts_texpr(expr : TExpr, counts : Array[Int]) -> Unit {
  sl_perf_get_count_scans.val = sl_perf_get_count_scans.val + 1
  for instr in expr.instrs {
    sl_collect_get_counts_instr(instr, counts)
  }
}

///|
fn sl_collect_get_counts_and_late_candidate_instr(
  instr : TInstr,
  counts : Array[Int],
  saw_late_candidate : Ref[Bool],
) -> Unit {
  match instr.kind {
    TInstrKind::TLocalSet(_, value) | TInstrKind::TLocalTee(_, value) => {
      match sl_get_fallthrough(value).kind {
        TInstrKind::TLocalGet(_) => saw_late_candidate.val = true
        _ => ()
      }
      sl_collect_get_counts_and_late_candidate_instr(
        value, counts, saw_late_candidate,
      )
    }
    TInstrKind::TLocalGet(idx) => {
      let i = sl_localidx_to_int(idx)
      if i >= 0 && i < counts.length() {
        counts[i] += 1
      }
    }
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) =>
      sl_collect_get_counts_and_late_candidate_texpr(
        body, counts, saw_late_candidate,
      )
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      sl_collect_get_counts_and_late_candidate_instr(
        cond, counts, saw_late_candidate,
      )
      sl_collect_get_counts_and_late_candidate_texpr(
        then_body, counts, saw_late_candidate,
      )
      match else_body {
        Some(other) =>
          sl_collect_get_counts_and_late_candidate_texpr(
            other, counts, saw_late_candidate,
          )
        None => ()
      }
    }
    _ =>
      for child in eval_children(instr) {
        sl_collect_get_counts_and_late_candidate_instr(
          child, counts, saw_late_candidate,
        )
      }
  }
}

///|
fn sl_collect_get_counts_and_late_candidate_texpr(
  expr : TExpr,
  counts : Array[Int],
  saw_late_candidate : Ref[Bool],
) -> Unit {
  sl_perf_get_count_scans.val = sl_perf_get_count_scans.val + 1
  for instr in expr.instrs {
    sl_collect_get_counts_and_late_candidate_instr(
      instr, counts, saw_late_candidate,
    )
  }
}

///|
fn sl_try_sink_local_get(
  idx : LocalIdx,
  env : Env,
  sinkables : Map[Int, SLSinkableInfo],
  sinkable_indexes : SLSinkableIndexes,
  out : Array[TInstr],
  get_counts : SLMainGetCounts,
  local_types : Array[ValType],
  options : SLSimplifyOptions,
  in_value_position : Bool,
  changed : Ref[Bool],
) -> TInstr {
  if !options.allow_nesting {
    return TInstr::local_get(idx)
  }
  let key = sl_localidx_to_int(idx)
  if key < 0 || key >= get_counts.local_count {
    return TInstr::local_get(idx)
  }
  match sinkables.get(key) {
    None => TInstr::local_get(idx)
    Some(info) => {
      let one_use = sl_main_get_counts_get(get_counts, key) == 1
      let sink_value = info.value
      let sink_is_get = match sink_value.kind {
        TInstrKind::TLocalGet(_) => true
        _ => false
      }
      let sink_is_control = match sink_value.kind {
        TInstrKind::TBlock(_, _)
        | TInstrKind::TLoop(_, _)
        | TInstrKind::TTryTable(_, _, _)
        | TInstrKind::TIf(_, _, _, _) => true
        _ => false
      }
      if in_value_position && sink_is_control {
        return TInstr::local_get(idx)
      }
      if !options.allow_nesting && !sink_is_get && in_value_position {
        return TInstr::local_get(idx)
      }
      if !one_use && !options.allow_tee {
        match sink_value.kind {
          TInstrKind::TLocalGet(other) =>
            if options.allow_nesting {
              TInstr::local_get(idx)
            } else {
              let other_i = sl_localidx_to_int(other)
              if other_i >= 0 &&
                other_i < local_types.length() &&
                Match::matches(local_types[other_i], local_types[key], env) {
                sl_main_get_counts_adjust_idx(get_counts, idx, -1)
                sl_main_get_counts_adjust_idx(get_counts, other, 1)
                changed.val = true
                TInstr::local_get(other)
              } else {
                TInstr::local_get(idx)
              }
            }
          _ => TInstr::local_get(idx)
        }
      } else if one_use {
        if !sl_sink_value_preserves_local_get_type(
            sink_value,
            env,
            local_types[key],
          ) {
          return TInstr::local_get(idx)
        }
        if info.out_index >= 0 && info.out_index < out.length() {
          out[info.out_index] = TInstr::nop()
        }
        sl_sinkables_remove(sinkables, sinkable_indexes, key)
        sl_main_get_counts_adjust_idx(get_counts, idx, -1)
        changed.val = true
        sink_value
      } else {
        if !sl_can_emit_typed_local_tee(idx, local_types[key], sink_value, env) {
          return TInstr::local_get(idx)
        }
        if info.out_index >= 0 && info.out_index < out.length() {
          out[info.out_index] = TInstr::nop()
        }
        sl_sinkables_remove(sinkables, sinkable_indexes, key)
        sl_main_get_counts_adjust_idx(get_counts, idx, -1)
        changed.val = true
        TInstr::local_tee(idx, sink_value)
      }
    }
  }
}

///|
fn sl_try_sink_local_get_traced(
  idx : LocalIdx,
  env : Env,
  sinkables : Map[Int, SLSinkableInfo],
  sinkable_indexes : SLSinkableIndexes,
  out : Array[TInstr],
  get_counts : SLMainGetCounts,
  local_types : Array[ValType],
  options : SLSimplifyOptions,
  in_value_position : Bool,
  changed : Ref[Bool],
) -> TInstr {
  let trace_main_rewrite = sl_main_rewrite_helper_trace_enabled.val
  let start_us = if trace_main_rewrite { sl_trace_now_us() } else { 0UL }
  if trace_main_rewrite {
    sl_main_rewrite_helper_try_sink_local_get_calls.val = sl_main_rewrite_helper_try_sink_local_get_calls.val +
      1
  }
  let rewritten = sl_try_sink_local_get(
    idx, env, sinkables, sinkable_indexes, out, get_counts, local_types, options,
    in_value_position, changed,
  )
  if trace_main_rewrite {
    sl_main_rewrite_helper_try_sink_local_get_us.val = sl_main_rewrite_helper_try_sink_local_get_us.val +
      sl_trace_elapsed_us_since(start_us)
  }
  rewritten
}

///|
fn sl_invalidate_sinkables(
  sinkables : Map[Int, SLSinkableInfo],
  sinkable_indexes : SLSinkableIndexes,
  effects : LCSEffects,
) -> Unit {
  let to_remove : Array[Int] = []
  let full_scan = effects.reads_memory ||
    effects.writes_memory ||
    effects.reads_globals ||
    effects.writes_globals ||
    effects.calls ||
    effects.branches ||
    effects.traps ||
    effects.throws
  if full_scan {
    for entry in sinkables {
      sl_perf_invalidation_entry_checks.val = sl_perf_invalidation_entry_checks.val +
        1
      let (idx, info) = entry
      if effects.invalidates(info.effects) {
        to_remove.push(idx)
      }
    }
  } else {
    let candidates = Set::new()
    for local_idx in effects.locals_written {
      let local_i = sl_localidx_to_int(local_idx)
      match sinkable_indexes.reads_by_local.get(local_i) {
        Some(bucket) =>
          for idx in bucket {
            candidates.add(idx)
          }
        None => ()
      }
      match sinkable_indexes.writes_by_local.get(local_i) {
        Some(bucket) =>
          for idx in bucket {
            candidates.add(idx)
          }
        None => ()
      }
    }
    for local_idx in effects.locals_read {
      let local_i = sl_localidx_to_int(local_idx)
      match sinkable_indexes.writes_by_local.get(local_i) {
        Some(bucket) =>
          for idx in bucket {
            candidates.add(idx)
          }
        None => ()
      }
    }
    for idx in candidates {
      sl_perf_invalidation_entry_checks.val = sl_perf_invalidation_entry_checks.val +
        1
      match sinkables.get(idx) {
        Some(info) =>
          if effects.invalidates(info.effects) {
            to_remove.push(idx)
          }
        None => ()
      }
    }
  }
  for idx in to_remove {
    sl_sinkables_remove(sinkables, sinkable_indexes, idx)
  }
}

///|
fn sl_invalidate_sinkables_traced(
  sinkables : Map[Int, SLSinkableInfo],
  sinkable_indexes : SLSinkableIndexes,
  effects : LCSEffects,
) -> Unit {
  let trace_main_rewrite = sl_main_rewrite_helper_trace_enabled.val
  let start_us = if trace_main_rewrite { sl_trace_now_us() } else { 0UL }
  if trace_main_rewrite {
    sl_main_rewrite_helper_invalidate_sinkables_calls.val = sl_main_rewrite_helper_invalidate_sinkables_calls.val +
      1
  }
  sl_invalidate_sinkables(sinkables, sinkable_indexes, effects)
  if trace_main_rewrite {
    sl_main_rewrite_helper_invalidate_sinkables_us.val = sl_main_rewrite_helper_invalidate_sinkables_us.val +
      sl_trace_elapsed_us_since(start_us)
  }
}

///|
fn sl_take_terminal_local_set(
  body : TExpr,
) -> (Array[TInstr], LocalIdx, TInstr)? {
  let n = body.instrs.length()
  if n == 0 {
    return None
  }
  let mut end = n - 1
  while end >= 0 && body.instrs[end] == TInstr::nop() {
    end -= 1
  }
  if end < 0 {
    return None
  }
  let terminal = body.instrs[end]
  let extracted = match terminal.kind {
    TInstrKind::TLocalSet(idx, value) => {
      let no_prefix : Array[TInstr] = []
      Some((no_prefix, idx, value))
    }
    TInstrKind::TBlock(VoidBlockType, nested) => {
      let effects = sl_collect_effects_counted(terminal)
      if effects.branches {
        None
      } else {
        sl_take_terminal_local_set(nested)
      }
    }
    _ => None
  }
  match extracted {
    Some((inner_prefix, idx, value)) => {
      let prefix : Array[TInstr] = []
      for i = 0; i < end; i = i + 1 {
        prefix.push(body.instrs[i])
      }
      for instr in inner_prefix {
        prefix.push(instr)
      }
      Some((prefix, idx, value))
    }
    None => None
  }
}

///|
fn sl_catch_targets_depth(catch_ : Catch, depth : Int) -> Bool {
  match catch_ {
    Catch(_, label)
    | CatchRef(_, label)
    | CatchAll(label)
    | CatchAllRef(label) => sl_labelidx_to_int(label) == depth
  }
}

///|
fn sl_has_branch_to_depth_instr(instr : TInstr, depth : Int) -> Bool {
  match instr.kind {
    TInstrKind::TBr(label, _) | TInstrKind::TBrIf(label, _, _) =>
      sl_labelidx_to_int(label) == depth
    TInstrKind::TBrTable(labels, default_, _, _) => {
      if sl_labelidx_to_int(default_) == depth {
        return true
      }
      for label in labels {
        if sl_labelidx_to_int(label) == depth {
          return true
        }
      }
      false
    }
    TInstrKind::TBrOnNull(label, _, _)
    | TInstrKind::TBrOnNonNull(label, _, _)
    | TInstrKind::TBrOnCast(label, _, _, _, _, _)
    | TInstrKind::TBrOnCastFail(label, _, _, _, _, _) =>
      sl_labelidx_to_int(label) == depth
    TInstrKind::TBlock(_, body) | TInstrKind::TLoop(_, body) =>
      sl_has_branch_to_depth_texpr(body, depth + 1)
    TInstrKind::TTryTable(_, catches, body) => {
      for catch_ in catches {
        if sl_catch_targets_depth(catch_, depth + 1) {
          return true
        }
      }
      sl_has_branch_to_depth_texpr(body, depth + 1)
    }
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      if sl_has_branch_to_depth_instr(cond, depth) ||
        sl_has_branch_to_depth_texpr(then_body, depth + 1) {
        return true
      }
      match else_body {
        Some(other) => sl_has_branch_to_depth_texpr(other, depth + 1)
        None => false
      }
    }
    _ => {
      for child in eval_children(instr) {
        if sl_has_branch_to_depth_instr(child, depth) {
          return true
        }
      }
      false
    }
  }
}

///|
fn sl_has_branch_to_depth_texpr(expr : TExpr, depth : Int) -> Bool {
  for instr in expr.instrs {
    if sl_has_branch_to_depth_instr(instr, depth) {
      return true
    }
  }
  false
}

///|
fn sl_texpr_is_unreachable(body : TExpr) -> Bool {
  if body.instrs.is_empty() {
    return false
  }
  is_unreachable_instr(body.instrs[body.instrs.length() - 1])
}

///|
priv struct SLBlockCollectState {
  mut shared_idx : Int?
  mut saw_exit : Bool
  mut unoptimizable : Bool
}

///|
fn SLBlockCollectState::new() -> SLBlockCollectState {
  { shared_idx: None, saw_exit: false, unoptimizable: false }
}

///|
fn sl_collect_shared_idx(state : SLBlockCollectState, idx : Int) -> Unit {
  match state.shared_idx {
    None => state.shared_idx = Some(idx)
    Some(prev) => if prev != idx { state.unoptimizable = true }
  }
}

///|
fn sl_branch_value_candidate_idx(values : Array[TInstr]) -> Int? {
  if values.length() != 1 {
    return None
  }
  match values[0].kind {
    TInstrKind::TLocalSet(idx, _) | TInstrKind::TLocalTee(idx, _) =>
      Some(sl_localidx_to_int(idx))
    _ => None
  }
}

///|
fn sl_br_table_target_profile(
  labels : Array[LabelIdx],
  default_ : LabelIdx,
  target_depth : Int,
) -> (Bool, Bool) {
  let default_hits = sl_labelidx_to_int(default_) == target_depth
  let mut hits_target = default_hits
  let mut all_targets_are_target_depth = default_hits
  for label in labels {
    let hit = sl_labelidx_to_int(label) == target_depth
    if hit {
      hits_target = true
    }
    all_targets_are_target_depth = all_targets_are_target_depth && hit
  }
  (hits_target, all_targets_are_target_depth)
}

///|
priv struct SLCondCarriedValueInfo {
  idx : Int
  value : TInstr
  next_cond : TInstr
}

///|
fn sl_cond_carried_value_move_is_safe(
  shared_idx : LocalIdx,
  value : TInstr,
  next_cond : TInstr,
) -> Bool {
  let value_effects = sl_collect_effects_counted(value)
  let cond_effects = sl_collect_effects_counted(next_cond)
  if cond_effects.locals_written.contains(shared_idx) {
    return false
  }
  !cond_effects.invalidates(value_effects)
}

///|
fn sl_extract_br_if_cond_carried_value(
  cond : TInstr,
) -> SLCondCarriedValueInfo? {
  match cond.kind {
    TInstrKind::TLocalTee(idx, value) => {
      let next_cond = TInstr::local_get(idx)
      if sl_cond_carried_value_move_is_safe(idx, value, next_cond) {
        Some({ idx: sl_localidx_to_int(idx), value, next_cond })
      } else {
        None
      }
    }
    TInstrKind::TBlock(bt, body) =>
      match bt {
        ValTypeBlockType(_) =>
          if body.instrs.length() >= 2 {
            match body.instrs[0].kind {
              TInstrKind::TLocalSet(idx, value) => {
                let next_instrs : Array[TInstr] = []
                for i = 1; i < body.instrs.length(); i = i + 1 {
                  next_instrs.push(body.instrs[i])
                }
                let next_cond = TInstr::block(bt, TExpr::new(next_instrs))
                if sl_cond_carried_value_move_is_safe(idx, value, next_cond) {
                  Some({ idx: sl_localidx_to_int(idx), value, next_cond })
                } else {
                  None
                }
              }
              _ => None
            }
          } else {
            None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn sl_collect_block_exit_candidates_texpr(
  body : TExpr,
  target_depth : Int,
  allow_tee : Bool,
  state : SLBlockCollectState,
) -> Unit {
  for i = 0; i < body.instrs.length(); i = i + 1 {
    let curr = body.instrs[i]
    let prev = if i > 0 { Some(body.instrs[i - 1]) } else { None }
    match curr.kind {
      TInstrKind::TBr(label, values) =>
        if sl_labelidx_to_int(label) == target_depth {
          state.saw_exit = true
          match sl_branch_value_candidate_idx(values) {
            Some(idx) => sl_collect_shared_idx(state, idx)
            None =>
              match prev {
                Some({ kind: TInstrKind::TLocalSet(prev_idx, _), .. }) if values.length() ==
                  0 =>
                  sl_collect_shared_idx(state, sl_localidx_to_int(prev_idx))
                _ => state.unoptimizable = true
              }
          }
        }
      TInstrKind::TBrIf(label, cond, values) => {
        sl_collect_block_exit_candidates_texpr(
          TExpr::new([cond]),
          target_depth,
          allow_tee,
          state,
        )
        if sl_labelidx_to_int(label) == target_depth {
          state.saw_exit = true
          if !allow_tee {
            state.unoptimizable = true
          } else {
            match sl_branch_value_candidate_idx(values) {
              Some(idx) => sl_collect_shared_idx(state, idx)
              None =>
                match prev {
                  Some({ kind: TInstrKind::TLocalSet(prev_idx, _), .. }) if values.length() ==
                    0 =>
                    sl_collect_shared_idx(state, sl_localidx_to_int(prev_idx))
                  _ =>
                    if values.length() == 0 {
                      match sl_extract_br_if_cond_carried_value(cond) {
                        Some(info) => sl_collect_shared_idx(state, info.idx)
                        None => state.unoptimizable = true
                      }
                    } else {
                      state.unoptimizable = true
                    }
                }
            }
          }
        }
      }
      TInstrKind::TBrTable(labels, default_, idx, values) => {
        sl_collect_block_exit_candidates_texpr(
          TExpr::new([idx]),
          target_depth,
          allow_tee,
          state,
        )
        for value in values {
          sl_collect_block_exit_candidates_texpr(
            TExpr::new([value]),
            target_depth,
            allow_tee,
            state,
          )
        }
        let (hits_target, all_targets_are_target_depth) = sl_br_table_target_profile(
          labels, default_, target_depth,
        )
        if hits_target {
          state.saw_exit = true
          if !all_targets_are_target_depth {
            state.unoptimizable = true
          } else {
            match sl_branch_value_candidate_idx(values) {
              Some(idx) => sl_collect_shared_idx(state, idx)
              None =>
                match prev {
                  Some({ kind: TInstrKind::TLocalSet(prev_idx, _), .. }) if values.length() ==
                    0 =>
                    sl_collect_shared_idx(state, sl_localidx_to_int(prev_idx))
                  _ => state.unoptimizable = true
                }
            }
          }
        }
      }
      TInstrKind::TBrOnNull(label, ref_, values)
      | TInstrKind::TBrOnNonNull(label, ref_, values) => {
        sl_collect_block_exit_candidates_texpr(
          TExpr::new([ref_]),
          target_depth,
          allow_tee,
          state,
        )
        for value in values {
          sl_collect_block_exit_candidates_texpr(
            TExpr::new([value]),
            target_depth,
            allow_tee,
            state,
          )
        }
        if sl_labelidx_to_int(label) == target_depth {
          state.saw_exit = true
          state.unoptimizable = true
        }
      }
      TInstrKind::TBrOnCast(label, _, _, _, ref_, values)
      | TInstrKind::TBrOnCastFail(label, _, _, _, ref_, values) => {
        sl_collect_block_exit_candidates_texpr(
          TExpr::new([ref_]),
          target_depth,
          allow_tee,
          state,
        )
        for value in values {
          sl_collect_block_exit_candidates_texpr(
            TExpr::new([value]),
            target_depth,
            allow_tee,
            state,
          )
        }
        if sl_labelidx_to_int(label) == target_depth {
          state.saw_exit = true
          state.unoptimizable = true
        }
      }
      TInstrKind::TBlock(_, nested)
      | TInstrKind::TLoop(_, nested)
      | TInstrKind::TTryTable(_, _, nested) =>
        sl_collect_block_exit_candidates_texpr(
          nested,
          target_depth + 1,
          allow_tee,
          state,
        )
      TInstrKind::TIf(_, cond, then_body, else_body) => {
        sl_collect_block_exit_candidates_texpr(
          TExpr::new([cond]),
          target_depth,
          allow_tee,
          state,
        )
        sl_collect_block_exit_candidates_texpr(
          then_body,
          target_depth + 1,
          allow_tee,
          state,
        )
        match else_body {
          Some(other) =>
            sl_collect_block_exit_candidates_texpr(
              other,
              target_depth + 1,
              allow_tee,
              state,
            )
          None => ()
        }
      }
      _ =>
        for child in eval_children(curr) {
          sl_collect_block_exit_candidates_texpr(
            TExpr::new([child]),
            target_depth,
            allow_tee,
            state,
          )
        }
    }
  }
}

///|
fn sl_rewrite_block_exits_texpr(
  body : TExpr,
  target_depth : Int,
  shared_idx : Int,
  allow_tee : Bool,
  changed : Ref[Bool],
) -> TExpr {
  let out : Array[TInstr] = []
  let shared_local = sl_localidx_from_int(shared_idx)
  for i = 0; i < body.instrs.length(); i = i + 1 {
    let curr = body.instrs[i]
    let next = match curr.kind {
      TInstrKind::TBr(label, values) =>
        if sl_labelidx_to_int(label) == target_depth {
          match sl_branch_value_candidate_idx(values) {
            Some(idx) if idx == shared_idx =>
              match values[0].kind {
                TInstrKind::TLocalSet(_, value)
                | TInstrKind::TLocalTee(_, value) => {
                  changed.val = true
                  TInstr::br(label, [value])
                }
                _ => curr
              }
            _ =>
              if values.length() == 0 &&
                out.length() > 0 &&
                sl_instr_is_direct_local_set_for_idx(
                  out[out.length() - 1],
                  shared_idx,
                ) {
                match out[out.length() - 1].kind {
                  TInstrKind::TLocalSet(_, value) => {
                    out[out.length() - 1] = TInstr::nop()
                    changed.val = true
                    TInstr::br(label, [value])
                  }
                  _ => curr
                }
              } else {
                curr
              }
          }
        } else {
          curr
        }
      TInstrKind::TBrIf(label, cond, values) =>
        if sl_labelidx_to_int(label) == target_depth && allow_tee {
          match sl_branch_value_candidate_idx(values) {
            Some(idx) if idx == shared_idx =>
              match values[0].kind {
                TInstrKind::TLocalSet(_, value) => {
                  changed.val = true
                  TInstr::drop(
                    TInstr::br_if(label, cond, [
                      TInstr::local_tee(shared_local, value),
                    ]),
                  )
                }
                TInstrKind::TLocalTee(_, value) => {
                  changed.val = true
                  TInstr::drop(
                    TInstr::br_if(label, cond, [
                      TInstr::local_tee(shared_local, value),
                    ]),
                  )
                }
                _ => curr
              }
            _ =>
              if values.length() == 0 &&
                out.length() > 0 &&
                sl_instr_is_direct_local_set_for_idx(
                  out[out.length() - 1],
                  shared_idx,
                ) {
                match out[out.length() - 1].kind {
                  TInstrKind::TLocalSet(_, value) => {
                    out[out.length() - 1] = TInstr::nop()
                    changed.val = true
                    TInstr::drop(
                      TInstr::br_if(label, cond, [
                        TInstr::local_tee(shared_local, value),
                      ]),
                    )
                  }
                  _ => curr
                }
              } else if values.length() == 0 {
                match sl_extract_br_if_cond_carried_value(cond) {
                  Some(info) if info.idx == shared_idx => {
                    changed.val = true
                    TInstr::drop(
                      TInstr::br_if(label, info.next_cond, [
                        TInstr::local_tee(shared_local, info.value),
                      ]),
                    )
                  }
                  _ => curr
                }
              } else {
                curr
              }
          }
        } else {
          curr
        }
      TInstrKind::TBrTable(labels, default_, idx, values) => {
        let (hits_target, all_targets_are_target_depth) = sl_br_table_target_profile(
          labels, default_, target_depth,
        )
        if hits_target && all_targets_are_target_depth {
          match sl_branch_value_candidate_idx(values) {
            Some(value_idx) if value_idx == shared_idx =>
              match values[0].kind {
                TInstrKind::TLocalSet(_, value)
                | TInstrKind::TLocalTee(_, value) => {
                  changed.val = true
                  TInstr::br_table(labels, default_, idx, [value])
                }
                _ => curr
              }
            _ =>
              if values.length() == 0 &&
                out.length() > 0 &&
                sl_instr_is_direct_local_set_for_idx(
                  out[out.length() - 1],
                  shared_idx,
                ) {
                match out[out.length() - 1].kind {
                  TInstrKind::TLocalSet(_, value) => {
                    out[out.length() - 1] = TInstr::nop()
                    changed.val = true
                    TInstr::br_table(labels, default_, idx, [value])
                  }
                  _ => curr
                }
              } else {
                curr
              }
          }
        } else {
          curr
        }
      }
      TInstrKind::TBlock(bt, nested) =>
        TInstr::block(
          bt,
          sl_rewrite_block_exits_texpr(
            nested,
            target_depth + 1,
            shared_idx,
            allow_tee,
            changed,
          ),
        )
      TInstrKind::TLoop(bt, nested) =>
        TInstr::loop_(
          bt,
          sl_rewrite_block_exits_texpr(
            nested,
            target_depth + 1,
            shared_idx,
            allow_tee,
            changed,
          ),
        )
      TInstrKind::TTryTable(bt, catches, nested) =>
        TInstr::try_table(
          bt,
          catches,
          sl_rewrite_block_exits_texpr(
            nested,
            target_depth + 1,
            shared_idx,
            allow_tee,
            changed,
          ),
        )
      TInstrKind::TIf(bt, cond, then_body, else_body) =>
        TInstr::if_(
          bt,
          sl_rewrite_block_exits_texpr(
            TExpr::new([cond]),
            target_depth,
            shared_idx,
            allow_tee,
            changed,
          ).instrs[0],
          sl_rewrite_block_exits_texpr(
            then_body,
            target_depth + 1,
            shared_idx,
            allow_tee,
            changed,
          ),
          else_body.map(fn(other) {
            sl_rewrite_block_exits_texpr(
              other,
              target_depth + 1,
              shared_idx,
              allow_tee,
              changed,
            )
          }),
        )
      _ => curr
    }
    out.push(next)
  }
  TExpr::new(out)
}

///|
fn sl_try_structure_block(
  instr : TInstr,
  env : Env,
  local_types : Array[ValType],
  options : SLSimplifyOptions,
  in_value_position : Bool,
  changed : Ref[Bool],
) -> TInstr {
  if !options.allow_structure || in_value_position {
    return instr
  }
  match instr.kind {
    TInstrKind::TBlock(VoidBlockType, body) =>
      match sl_take_terminal_local_set(body) {
        Some((_, fall_idx, _)) => {
          let fall_raw = sl_localidx_to_int(fall_idx)
          let collect = SLBlockCollectState::new()
          sl_collect_block_exit_candidates_texpr(
            body,
            0,
            options.allow_tee,
            collect,
          )
          if collect.unoptimizable || !collect.saw_exit {
            return instr
          }
          let shared_raw = match collect.shared_idx {
            Some(i) => i
            None => return instr
          }
          if shared_raw != fall_raw {
            return instr
          }
          let local_type = match local_types.get(shared_raw) {
            Some(vt) => vt
            None => return instr
          }
          let block_changed = Ref::new(false)
          let next_body = sl_rewrite_block_exits_texpr(
            body,
            0,
            shared_raw,
            options.allow_tee,
            block_changed,
          )
          match sl_take_terminal_local_set(next_body) {
            Some((prefix, shared_idx, value)) =>
              if sl_localidx_to_int(shared_idx) == shared_raw {
                let body_result = prefix.copy()
                body_result.push(value)
                let result_value = TInstr::block(
                  BlockType::val_type(local_type),
                  TExpr::new(body_result),
                )
                if sl_can_emit_typed_local_set(
                    shared_idx, local_type, result_value, env,
                  ) {
                  let candidate = TInstr::local_set(shared_idx, result_value)
                  changed.val = changed.val ||
                    block_changed.val ||
                    candidate != instr
                  candidate
                } else {
                  instr
                }
              } else {
                instr
              }
            None => instr
          }
        }
        None => instr
      }
    _ => instr
  }
}

///|
fn sl_try_structure_loop_sink(
  instr : TInstr,
  env : Env,
  sinkables : Map[Int, SLSinkableInfo],
  sinkable_indexes : SLSinkableIndexes,
  out : Array[TInstr],
  local_types : Array[ValType],
  options : SLSimplifyOptions,
  changed : Ref[Bool],
) -> TInstr {
  if !options.allow_structure {
    return instr
  }
  match instr.kind {
    TInstrKind::TLoop(VoidBlockType, body) =>
      if sinkables.is_empty() || sl_has_branch_to_depth_texpr(body, 0) {
        instr
      } else {
        let mut good_idx = -1
        for entry in sinkables {
          let (idx, _) = entry
          good_idx = idx
          break
        }
        if good_idx < 0 {
          return instr
        }
        let good_local = sl_localidx_from_int(good_idx)
        let local_type = match local_types.get(good_idx) {
          Some(vt) => vt
          None => return instr
        }
        match sinkables.get(good_idx) {
          Some(info) => {
            let body_with_slot = if body.instrs.is_empty() ||
              body.instrs[body.instrs.length() - 1] != TInstr::nop() {
              let grown = body.instrs.copy()
              grown.push(TInstr::nop())
              TExpr::new(grown)
            } else {
              body
            }
            let next_instrs = body_with_slot.instrs.copy()
            next_instrs[next_instrs.length() - 1] = info.value
            let next_loop = TInstr::loop_(
              BlockType::val_type(local_type),
              TExpr::new(next_instrs),
            )
            let candidate = TInstr::local_set(good_local, next_loop)
            if !sl_can_emit_typed_local_set(
                good_local, local_type, next_loop, env,
              ) {
              instr
            } else {
              if info.out_index >= 0 && info.out_index < out.length() {
                out[info.out_index] = TInstr::nop()
              }
              sl_sinkables_remove(sinkables, sinkable_indexes, good_idx)
              changed.val = true
              candidate
            }
          }
          None => instr
        }
      }
    _ => instr
  }
}

///|
fn sl_try_structure_if(
  instr : TInstr,
  env : Env,
  local_types : Array[ValType],
  get_counts : SLMainGetCounts,
  options : SLSimplifyOptions,
  in_value_position : Bool,
  changed : Ref[Bool],
) -> TInstr {
  if !options.allow_structure || in_value_position {
    return instr
  }
  match instr.kind {
    TInstrKind::TIf(VoidBlockType, cond, then_body, else_body) =>
      match else_body {
        Some(other) => {
          let then_set = sl_take_terminal_local_set(then_body)
          let else_set = sl_take_terminal_local_set(other)
          let then_unreachable = sl_texpr_is_unreachable(then_body)
          let else_unreachable = sl_texpr_is_unreachable(other)
          match (then_set, else_set) {
            (
              Some((then_prefix, then_idx, then_value)),
              Some((else_prefix, else_idx, else_value)),
            ) =>
              if then_idx == else_idx {
                let idx_i = sl_localidx_to_int(then_idx)
                match local_types.get(idx_i) {
                  Some(local_type) => {
                    let next_then = then_prefix.copy()
                    next_then.push(then_value)
                    let next_else = else_prefix.copy()
                    next_else.push(else_value)
                    let result_value = TInstr::if_(
                      BlockType::val_type(local_type),
                      cond,
                      TExpr::new(next_then),
                      Some(TExpr::new(next_else)),
                    )
                    if sl_can_emit_typed_local_set(
                        then_idx, local_type, result_value, env,
                      ) {
                      let candidate = TInstr::local_set(then_idx, result_value)
                      changed.val = true
                      candidate
                    } else {
                      instr
                    }
                  }
                  None => instr
                }
              } else {
                instr
              }
            _ =>
              if else_unreachable {
                match then_set {
                  Some((then_prefix, then_idx, then_value)) => {
                    let idx_i = sl_localidx_to_int(then_idx)
                    match local_types.get(idx_i) {
                      Some(local_type) => {
                        let next_then = then_prefix.copy()
                        next_then.push(then_value)
                        let result_value = TInstr::if_(
                          BlockType::val_type(local_type),
                          cond,
                          TExpr::new(next_then),
                          Some(other),
                        )
                        if sl_can_emit_typed_local_set(
                            then_idx, local_type, result_value, env,
                          ) {
                          let candidate = TInstr::local_set(
                            then_idx, result_value,
                          )
                          changed.val = true
                          candidate
                        } else {
                          instr
                        }
                      }
                      None => instr
                    }
                  }
                  None => instr
                }
              } else if then_unreachable {
                match else_set {
                  Some((else_prefix, else_idx, else_value)) => {
                    let idx_i = sl_localidx_to_int(else_idx)
                    match local_types.get(idx_i) {
                      Some(local_type) => {
                        let next_else = else_prefix.copy()
                        next_else.push(else_value)
                        let result_value = TInstr::if_(
                          BlockType::val_type(local_type),
                          cond,
                          then_body,
                          Some(TExpr::new(next_else)),
                        )
                        if sl_can_emit_typed_local_set(
                            else_idx, local_type, result_value, env,
                          ) {
                          let candidate = TInstr::local_set(
                            else_idx, result_value,
                          )
                          changed.val = true
                          candidate
                        } else {
                          instr
                        }
                      }
                      None => instr
                    }
                  }
                  None => instr
                }
              } else {
                instr
              }
          }
        }
        None =>
          match sl_take_terminal_local_set(then_body) {
            Some((then_prefix, then_idx, then_value)) => {
              let idx_i = sl_localidx_to_int(then_idx)
              match local_types.get(idx_i) {
                Some(local_type) =>
                  if sl_is_defaultable(local_type) {
                    let next_then = then_prefix.copy()
                    next_then.push(then_value)
                    let result_value = TInstr::if_(
                      BlockType::val_type(local_type),
                      cond,
                      TExpr::new(next_then),
                      Some(TExpr::new([TInstr::local_get(then_idx)])),
                    )
                    if sl_can_emit_typed_local_set(
                        then_idx, local_type, result_value, env,
                      ) {
                      let candidate = TInstr::local_set(then_idx, result_value)
                      sl_main_get_counts_adjust_idx(get_counts, then_idx, 1)
                      changed.val = true
                      candidate
                    } else {
                      instr
                    }
                  } else {
                    instr
                  }
                None => instr
              }
            }
            _ => instr
          }
      }
    _ => instr
  }
}

///|
fn sl_rewrite_instr_main(
  instr : TInstr,
  env : Env,
  sinkables : Map[Int, SLSinkableInfo],
  sinkable_indexes : SLSinkableIndexes,
  effects_cache : Map[TInstr, LCSEffects],
  out : Array[TInstr],
  local_types : Array[ValType],
  get_counts : SLMainGetCounts,
  options : SLSimplifyOptions,
  in_value_position : Bool,
  changed : Ref[Bool],
) -> TInstr {
  if in_value_position && !options.allow_nesting {
    return instr
  }
  match instr.kind {
    TInstrKind::TLocalGet(idx) =>
      sl_try_sink_local_get_traced(
        idx, env, sinkables, sinkable_indexes, out, get_counts, local_types, options,
        in_value_position, changed,
      )
    TInstrKind::TBlock(bt, body) => {
      let body_env = sl_block_body_env(env, bt)
      let (next_body, body_changed) = sl_simplify_texpr_main(
        body, body_env, local_types, get_counts, options, effects_cache,
      )
      if body_changed {
        changed.val = true
      }
      sl_try_structure_block(
        TInstr::block(bt, next_body),
        env,
        local_types,
        options,
        in_value_position,
        changed,
      )
    }
    TInstrKind::TLoop(bt, body) => {
      let body_env = sl_loop_body_env(env, bt)
      let (next_body, body_changed) = sl_simplify_texpr_main(
        body, body_env, local_types, get_counts, options, effects_cache,
      )
      if body_changed {
        changed.val = true
      }
      TInstr::loop_(bt, next_body)
    }
    TInstrKind::TTryTable(bt, catches, body) => {
      let body_env = sl_block_body_env(env, bt)
      let (next_body, body_changed) = sl_simplify_texpr_main(
        body, body_env, local_types, get_counts, options, effects_cache,
      )
      if body_changed {
        changed.val = true
      }
      TInstr::try_table(bt, catches, next_body)
    }
    TInstrKind::TIf(bt, cond, then_body, else_body) => {
      let branch_env = sl_block_body_env(env, bt)
      let next_cond = sl_rewrite_instr_main_traced(
        cond, env, sinkables, sinkable_indexes, effects_cache, out, local_types,
        get_counts, options, true, changed,
      )
      let (next_then, then_changed) = sl_simplify_texpr_main(
        then_body, branch_env, local_types, get_counts, options, effects_cache,
      )
      let mut branch_changed = then_changed
      let next_else = match else_body {
        Some(other) => {
          let (rewritten, else_changed) = sl_simplify_texpr_main(
            other, branch_env, local_types, get_counts, options, effects_cache,
          )
          branch_changed = branch_changed || else_changed
          Some(rewritten)
        }
        None => None
      }
      let rebuilt = TInstr::if_(bt, next_cond, next_then, next_else)
      if branch_changed || next_cond != cond {
        changed.val = true
      }
      sl_try_structure_if(
        rebuilt, env, local_types, get_counts, options, in_value_position, changed,
      )
    }
    _ => {
      let next_children : Array[TInstr] = []
      let mut any = false
      for child in eval_children(instr) {
        let next_child = sl_rewrite_instr_main_traced(
          child, env, sinkables, sinkable_indexes, effects_cache, out, local_types,
          get_counts, options, true, changed,
        )
        next_children.push(next_child)
        if next_child != child {
          any = true
        }
        if !sinkables.is_empty() {
          sl_invalidate_sinkables_traced(
            sinkables,
            sinkable_indexes,
            sl_collect_effects_cached(next_child, effects_cache),
          )
        }
      }
      if next_children.is_empty() {
        instr
      } else if any {
        changed.val = true
        mb_rebuild_non_control(instr, next_children)
      } else {
        instr
      }
    }
  }
}

///|
fn sl_rewrite_instr_main_traced(
  instr : TInstr,
  env : Env,
  sinkables : Map[Int, SLSinkableInfo],
  sinkable_indexes : SLSinkableIndexes,
  effects_cache : Map[TInstr, LCSEffects],
  out : Array[TInstr],
  local_types : Array[ValType],
  get_counts : SLMainGetCounts,
  options : SLSimplifyOptions,
  in_value_position : Bool,
  changed : Ref[Bool],
) -> TInstr {
  let trace_main_rewrite = sl_main_rewrite_helper_trace_enabled.val
  let start_us = if trace_main_rewrite { sl_trace_now_us() } else { 0UL }
  if trace_main_rewrite {
    sl_main_rewrite_helper_rewrite_instr_calls.val = sl_main_rewrite_helper_rewrite_instr_calls.val +
      1
    sl_main_rewrite_helper_trace_note_instr_kind(instr)
    sl_main_rewrite_helper_trace_progress_maybe_emit("rewrite_instr")
  }
  let rewritten = sl_rewrite_instr_main(
    instr, env, sinkables, sinkable_indexes, effects_cache, out, local_types, get_counts,
    options, in_value_position, changed,
  )
  if trace_main_rewrite {
    sl_main_rewrite_helper_rewrite_instr_us.val = sl_main_rewrite_helper_rewrite_instr_us.val +
      sl_trace_elapsed_us_since(start_us)
  }
  rewritten
}

///|
fn sl_simplify_texpr_main(
  expr : TExpr,
  env : Env,
  local_types : Array[ValType],
  get_counts : SLMainGetCounts,
  options : SLSimplifyOptions,
  effects_cache : Map[TInstr, LCSEffects],
) -> (TExpr, Bool) {
  let trace_main_rewrite = sl_main_rewrite_helper_trace_enabled.val
  let start_us = if trace_main_rewrite { sl_trace_now_us() } else { 0UL }
  if trace_main_rewrite {
    sl_main_rewrite_helper_simplify_texpr_calls.val = sl_main_rewrite_helper_simplify_texpr_calls.val +
      1
    sl_main_rewrite_helper_texpr_instrs_seen.val = sl_main_rewrite_helper_texpr_instrs_seen.val +
      expr.instrs.length()
    sl_main_rewrite_helper_trace_note_texpr_enter(expr)
    sl_main_rewrite_helper_trace_progress_maybe_emit("texpr_enter")
  }
  let out : Array[TInstr] = []
  let sinkables : Map[Int, SLSinkableInfo] = Map::new()
  let sinkable_indexes = sl_sinkable_indexes_new()
  let changed = Ref::new(false)
  let enable_sinking = options.allow_nesting

  for instr in expr.instrs {
    let rewritten = sl_rewrite_instr_main_traced(
      instr, env, sinkables, sinkable_indexes, effects_cache, out, local_types, get_counts,
      options, false, changed,
    )
    let curr = match rewritten.kind {
      TInstrKind::TDrop({ kind: TInstrKind::TLocalTee(idx, value), .. }) => {
        changed.val = true
        TInstr::local_set(idx, value)
      }
      _ => rewritten
    }
    let curr = if enable_sinking {
      sl_try_structure_loop_sink(
        curr, env, sinkables, sinkable_indexes, out, local_types, options, changed,
      )
    } else {
      curr
    }
    if enable_sinking && !sinkables.is_empty() {
      let curr_effects = sl_collect_effects_cached(curr, effects_cache)
      sl_invalidate_sinkables_traced(sinkables, sinkable_indexes, curr_effects)
    }
    match curr.kind {
      TInstrKind::TLocalSet(idx, value) => {
        let key = sl_localidx_to_int(idx)
        if enable_sinking && key >= 0 && key < get_counts.local_count {
          match sinkables.get(key) {
            Some(previous) => {
              if previous.out_index >= 0 && previous.out_index < out.length() {
                out[previous.out_index] = TInstr::drop(previous.value)
              }
              sl_sinkables_remove(sinkables, sinkable_indexes, key)
              changed.val = true
            }
            None => ()
          }
          sl_main_rewrite_helper_trace_note_sinkables(sinkables.length())
          let uses = sl_main_get_counts_get(get_counts, key)
          if uses > 0 && (options.allow_tee || uses == 1) {
            sl_sinkables_add(sinkables, sinkable_indexes, key, {
              out_index: out.length(),
              value,
              effects: sl_collect_effects_cached(
                TInstr::local_set(idx, value),
                effects_cache,
              ),
            })
            sl_main_rewrite_helper_trace_note_sinkables(sinkables.length())
          }
        }
      }
      _ => ()
    }
    out.push(curr)
    let reached_unreachable = is_unreachable_instr(curr)
    let reached_non_linear_boundary = lcs_is_non_linear_boundary(curr)
    let keep_sinkables_across_boundary = if enable_sinking &&
      reached_non_linear_boundary &&
      !reached_unreachable {
      match curr.kind {
        TInstrKind::TBlock(VoidBlockType, _) => {
          let effects = sl_collect_effects_cached(curr, effects_cache)
          !effects.branches &&
          !effects.calls &&
          !effects.traps &&
          !effects.throws &&
          !effects.reads_memory &&
          !effects.writes_memory &&
          !effects.reads_globals &&
          !effects.writes_globals
        }
        _ => false
      }
    } else {
      false
    }
    if enable_sinking &&
      (
        reached_unreachable ||
        (reached_non_linear_boundary && !keep_sinkables_across_boundary)
      ) {
      sinkables.clear()
      sinkable_indexes.reads_by_local.clear()
      sinkable_indexes.writes_by_local.clear()
      sl_main_rewrite_helper_trace_note_sinkables(0)
    }
    if reached_unreachable {
      break
    }
  }
  if trace_main_rewrite {
    sl_main_rewrite_helper_simplify_texpr_us.val = sl_main_rewrite_helper_simplify_texpr_us.val +
      sl_trace_elapsed_us_since(start_us)
    sl_main_rewrite_helper_trace_note_texpr_exit()
  }
  (TExpr::new(out), changed.val)
}

///|
fn sl_remove_unneeded_sets_instr(
  instr : TInstr,
  get_counts : Array[Int],
  changed : Ref[Bool],
  in_value_position : Bool,
) -> TInstr {
  match instr.kind {
    TInstrKind::TLocalSet(idx, value) => {
      let next_value = sl_remove_unneeded_sets_instr(
        value, get_counts, changed, true,
      )
      let key = sl_localidx_to_int(idx)
      if key >= 0 && key < get_counts.length() && get_counts[key] == 0 {
        if in_value_position {
          if next_value != value {
            changed.val = true
            TInstr::local_set(idx, next_value)
          } else {
            instr
          }
        } else {
          changed.val = true
          TInstr::drop(next_value)
        }
      } else if next_value != value {
        changed.val = true
        TInstr::local_set(idx, next_value)
      } else {
        instr
      }
    }
    TInstrKind::TLocalTee(idx, value) => {
      let next_value = sl_remove_unneeded_sets_instr(
        value, get_counts, changed, true,
      )
      let key = sl_localidx_to_int(idx)
      if key >= 0 && key < get_counts.length() && get_counts[key] == 0 {
        changed.val = true
        next_value
      } else if next_value != value {
        changed.val = true
        TInstr::local_tee(idx, next_value)
      } else {
        instr
      }
    }
    TInstrKind::TBlock(bt, body) => {
      let next_body = sl_remove_unneeded_sets_texpr(body, get_counts, changed)
      if next_body != body {
        changed.val = true
        TInstr::block(bt, next_body)
      } else {
        instr
      }
    }
    TInstrKind::TLoop(bt, body) => {
      let next_body = sl_remove_unneeded_sets_texpr(body, get_counts, changed)
      if next_body != body {
        changed.val = true
        TInstr::loop_(bt, next_body)
      } else {
        instr
      }
    }
    TInstrKind::TTryTable(bt, catches, body) => {
      let next_body = sl_remove_unneeded_sets_texpr(body, get_counts, changed)
      if next_body != body {
        changed.val = true
        TInstr::try_table(bt, catches, next_body)
      } else {
        instr
      }
    }
    TInstrKind::TIf(bt, cond, then_body, else_body) => {
      let next_cond = sl_remove_unneeded_sets_instr(
        cond, get_counts, changed, true,
      )
      let next_then = sl_remove_unneeded_sets_texpr(
        then_body, get_counts, changed,
      )
      let next_else = else_body.map(fn(e) {
        sl_remove_unneeded_sets_texpr(e, get_counts, changed)
      })
      if next_cond != cond || next_then != then_body || next_else != else_body {
        changed.val = true
        TInstr::if_(bt, next_cond, next_then, next_else)
      } else {
        instr
      }
    }
    _ => {
      let next_children : Array[TInstr] = []
      let mut any = false
      for child in eval_children(instr) {
        let next_child = sl_remove_unneeded_sets_instr(
          child, get_counts, changed, true,
        )
        if next_child != child {
          any = true
        }
        next_children.push(next_child)
      }
      if next_children.is_empty() {
        instr
      } else if any {
        changed.val = true
        mb_rebuild_non_control(instr, next_children)
      } else {
        instr
      }
    }
  }
}

///|
fn sl_remove_unneeded_sets_texpr(
  expr : TExpr,
  get_counts : Array[Int],
  changed : Ref[Bool],
) -> TExpr {
  let out : Array[TInstr] = []
  for instr in expr.instrs {
    out.push(sl_remove_unneeded_sets_instr(instr, get_counts, changed, false))
  }
  TExpr::new(out)
}

///|
fn sl_strip_nops_instr(instr : TInstr, changed : Ref[Bool]) -> TInstr {
  match instr.kind {
    TInstrKind::TBlock(bt, body) => {
      let next_body = sl_strip_nops_texpr(body, changed)
      if next_body != body {
        changed.val = true
        TInstr::block(bt, next_body)
      } else {
        instr
      }
    }
    TInstrKind::TLoop(bt, body) => {
      let next_body = sl_strip_nops_texpr(body, changed)
      if next_body != body {
        changed.val = true
        TInstr::loop_(bt, next_body)
      } else {
        instr
      }
    }
    TInstrKind::TTryTable(bt, catches, body) => {
      let next_body = sl_strip_nops_texpr(body, changed)
      if next_body != body {
        changed.val = true
        TInstr::try_table(bt, catches, next_body)
      } else {
        instr
      }
    }
    TInstrKind::TIf(bt, cond, then_body, else_body) => {
      let next_cond = sl_strip_nops_instr(cond, changed)
      let next_then = sl_strip_nops_texpr(then_body, changed)
      let next_else = else_body.map(fn(e) { sl_strip_nops_texpr(e, changed) })
      if next_cond != cond || next_then != then_body || next_else != else_body {
        changed.val = true
        TInstr::if_(bt, next_cond, next_then, next_else)
      } else {
        instr
      }
    }
    _ => {
      let next_children : Array[TInstr] = []
      let mut any = false
      for child in eval_children(instr) {
        let next_child = sl_strip_nops_instr(child, changed)
        if next_child != child {
          any = true
        }
        next_children.push(next_child)
      }
      if next_children.is_empty() {
        instr
      } else if any {
        changed.val = true
        mb_rebuild_non_control(instr, next_children)
      } else {
        instr
      }
    }
  }
}

///|
fn sl_strip_nops_texpr(expr : TExpr, changed : Ref[Bool]) -> TExpr {
  let out : Array[TInstr] = []
  for instr in expr.instrs {
    if instr == TInstr::nop() {
      changed.val = true
      continue
    }
    out.push(sl_strip_nops_instr(instr, changed))
  }
  TExpr::new(out)
}

///|
priv struct SLLateState {
  rep_of : Array[Int]
  members : Array[Array[Int]]
  rep_dirty_flags : Array[Bool]
  members_dirty_flags : Array[Bool]
  dirty_rep_idxs : Array[Int]
  dirty_member_idxs : Array[Int]
  local_types : Array[ValType]
  get_counts : Array[Int]
  env : Env
  remove_equivalent_sets : Bool
  changed : Ref[Bool]
}

///|
fn sl_late_state_new(
  local_types : Array[ValType],
  get_counts : Array[Int],
  env : Env,
  remove_equivalent_sets : Bool,
  changed : Ref[Bool],
) -> SLLateState {
  sl_perf_late_state_clones.val = sl_perf_late_state_clones.val + 1
  let local_count = local_types.length()
  let rep_of : Array[Int] = []
  let members : Array[Array[Int]] = []
  let rep_dirty_flags : Array[Bool] = []
  let members_dirty_flags : Array[Bool] = []
  for i = 0; i < local_count; i = i + 1 {
    rep_of.push(i)
    // Singletons are implicit: class rep contains itself plus `members[rep]`.
    members.push([])
    rep_dirty_flags.push(false)
    members_dirty_flags.push(false)
  }
  {
    rep_of,
    members,
    rep_dirty_flags,
    members_dirty_flags,
    dirty_rep_idxs: [],
    dirty_member_idxs: [],
    local_types,
    get_counts,
    env,
    remove_equivalent_sets,
    changed,
  }
}

///|
fn sl_late_mark_rep_dirty(state : SLLateState, idx : Int) -> Unit {
  if idx < 0 || idx >= state.rep_dirty_flags.length() {
    return
  }
  if !state.rep_dirty_flags[idx] {
    state.rep_dirty_flags[idx] = true
    state.dirty_rep_idxs.push(idx)
  }
}

///|
fn sl_late_mark_members_dirty(state : SLLateState, idx : Int) -> Unit {
  if idx < 0 || idx >= state.members_dirty_flags.length() {
    return
  }
  if !state.members_dirty_flags[idx] {
    state.members_dirty_flags[idx] = true
    state.dirty_member_idxs.push(idx)
  }
}

///|
fn sl_late_clear(state : SLLateState) -> Unit {
  for idx in state.dirty_rep_idxs {
    state.rep_of[idx] = idx
    state.rep_dirty_flags[idx] = false
  }
  state.dirty_rep_idxs.clear()
  for idx in state.dirty_member_idxs {
    if state.members[idx].length() > 0 {
      state.members[idx] = []
    }
    state.members_dirty_flags[idx] = false
  }
  state.dirty_member_idxs.clear()
}

///|
fn sl_late_is_subtype(state : SLLateState, a : Int, b : Int) -> Bool {
  if a < 0 ||
    b < 0 ||
    a >= state.local_types.length() ||
    b >= state.local_types.length() {
    return false
  }
  Match::matches(state.local_types[a], state.local_types[b], state.env)
}

///|
fn sl_late_is_equivalent(state : SLLateState, a : Int, b : Int) -> Bool {
  if a == b {
    return true
  }
  if a < 0 || b < 0 || a >= state.rep_of.length() || b >= state.rep_of.length() {
    return false
  }
  state.rep_of[a] == state.rep_of[b]
}

///|
fn sl_late_reset_local(state : SLLateState, idx : Int) -> Unit {
  if idx < 0 || idx >= state.rep_of.length() {
    return
  }
  let rep = state.rep_of[idx]
  if rep == idx {
    let class_members = state.members[rep]
    // members[rep] excludes `rep`; when non-empty we must pick a new rep.
    if class_members.length() > 0 {
      let next_rep = class_members[0]
      let next_members : Array[Int] = []
      state.rep_of[next_rep] = next_rep
      for i = 1; i < class_members.length(); i = i + 1 {
        let class_idx = class_members[i]
        next_members.push(class_idx)
        state.rep_of[class_idx] = next_rep
        sl_late_mark_rep_dirty(state, class_idx)
      }
      state.members[next_rep] = next_members
      sl_late_mark_members_dirty(state, next_rep)
    }
  } else {
    let next_members : Array[Int] = []
    for class_idx in state.members[rep] {
      if class_idx != idx {
        next_members.push(class_idx)
      }
    }
    state.members[rep] = next_members
    sl_late_mark_members_dirty(state, rep)
  }
  state.rep_of[idx] = idx
  state.members[idx] = []
  sl_late_mark_members_dirty(state, idx)
}

///|
fn sl_late_add_equivalence(state : SLLateState, a : Int, b : Int) -> Unit {
  if a < 0 || b < 0 || a >= state.rep_of.length() || b >= state.rep_of.length() {
    return
  }
  if !sl_late_is_subtype(state, a, b) && !sl_late_is_subtype(state, b, a) {
    return
  }
  let mut rep_a = state.rep_of[a]
  let mut rep_b = state.rep_of[b]
  if rep_a == rep_b {
    return
  }
  let size_a = 1 + state.members[rep_a].length()
  let size_b = 1 + state.members[rep_b].length()
  if size_a < size_b {
    let tmp = rep_a
    rep_a = rep_b
    rep_b = tmp
  }
  let merged = state.members[rep_a].copy()
  // rep_b itself is a class member now that rep_a remains the representative.
  merged.push(rep_b)
  state.rep_of[rep_b] = rep_a
  sl_late_mark_rep_dirty(state, rep_b)
  for idx in state.members[rep_b] {
    merged.push(idx)
    state.rep_of[idx] = rep_a
    sl_late_mark_rep_dirty(state, idx)
  }
  state.members[rep_a] = merged
  state.members[rep_b] = []
  sl_late_mark_members_dirty(state, rep_a)
  sl_late_mark_members_dirty(state, rep_b)
}

///|
fn sl_get_fallthrough(instr : TInstr) -> TInstr {
  match instr.kind {
    TInstrKind::TBlock(_, { instrs, .. }) if instrs.length() > 0 =>
      sl_get_fallthrough(instrs[instrs.length() - 1])
    _ => instr
  }
}

///|
fn sl_late_get_count_ignoring_curr(
  state : SLLateState,
  idx : Int,
  curr : Int,
) -> Int {
  if idx < 0 || idx >= state.get_counts.length() {
    return 0
  }
  let mut out = state.get_counts[idx]
  if idx == curr && out > 0 {
    out -= 1
  }
  out
}

///|
fn sl_late_rewrite_instr(
  instr : TInstr,
  state : SLLateState,
  in_value_position : Bool,
) -> TInstr {
  match instr.kind {
    TInstrKind::TLocalSet(idx, value) => {
      let next_value = sl_late_rewrite_instr(value, state, true)
      let idx_i = sl_localidx_to_int(idx)
      match sl_get_fallthrough(next_value).kind {
        TInstrKind::TLocalGet(src_idx) => {
          let src_i = sl_localidx_to_int(src_idx)
          if sl_late_is_equivalent(state, idx_i, src_i) {
            if state.remove_equivalent_sets {
              if in_value_position {
                if next_value != value {
                  state.changed.val = true
                  TInstr::local_set(idx, next_value)
                } else {
                  instr
                }
              } else {
                state.changed.val = true
                TInstr::drop(next_value)
              }
            } else if next_value != value {
              state.changed.val = true
              TInstr::local_set(idx, next_value)
            } else {
              instr
            }
          } else {
            sl_late_reset_local(state, idx_i)
            sl_late_add_equivalence(state, idx_i, src_i)
            if next_value != value {
              state.changed.val = true
              TInstr::local_set(idx, next_value)
            } else {
              instr
            }
          }
        }
        _ => {
          sl_late_reset_local(state, idx_i)
          if next_value != value {
            state.changed.val = true
            TInstr::local_set(idx, next_value)
          } else {
            instr
          }
        }
      }
    }
    TInstrKind::TLocalTee(idx, value) => {
      let next_value = sl_late_rewrite_instr(value, state, true)
      let idx_i = sl_localidx_to_int(idx)
      match sl_get_fallthrough(next_value).kind {
        TInstrKind::TLocalGet(src_idx) => {
          let src_i = sl_localidx_to_int(src_idx)
          if sl_late_is_equivalent(state, idx_i, src_i) {
            if state.remove_equivalent_sets {
              state.changed.val = true
              next_value
            } else if next_value != value {
              state.changed.val = true
              TInstr::local_tee(idx, next_value)
            } else {
              instr
            }
          } else {
            sl_late_reset_local(state, idx_i)
            sl_late_add_equivalence(state, idx_i, src_i)
            if next_value != value {
              state.changed.val = true
              TInstr::local_tee(idx, next_value)
            } else {
              instr
            }
          }
        }
        _ => {
          sl_late_reset_local(state, idx_i)
          if next_value != value {
            state.changed.val = true
            TInstr::local_tee(idx, next_value)
          } else {
            instr
          }
        }
      }
    }
    TInstrKind::TLocalGet(idx) => {
      let idx_i = sl_localidx_to_int(idx)
      if idx_i < 0 || idx_i >= state.rep_of.length() {
        return instr
      }
      let rep = state.rep_of[idx_i]
      let mut best = idx_i
      let consider_candidate = fn(candidate : Int) -> Unit {
        if candidate == best {
          return
        }
        if !sl_late_is_subtype(state, candidate, best) {
          return
        }
        let cand_count = sl_late_get_count_ignoring_curr(
          state, candidate, idx_i,
        )
        let best_count = sl_late_get_count_ignoring_curr(state, best, idx_i)
        if state.local_types[candidate] != state.local_types[best] ||
          cand_count > best_count {
          best = candidate
        }
      }
      // Include the representative, which is not stored in members[rep].
      consider_candidate(rep)
      for candidate in state.members[rep] {
        consider_candidate(candidate)
      }
      if best != idx_i && sl_late_is_subtype(state, best, idx_i) {
        let has_more_gets = sl_late_get_count_ignoring_curr(state, best, idx_i) >
          sl_late_get_count_ignoring_curr(state, idx_i, idx_i)
        let best_type = state.local_types[best]
        let old_type = state.local_types[idx_i]
        if has_more_gets || best_type != old_type {
          state.get_counts[best] = state.get_counts[best] + 1
          if state.get_counts[idx_i] > 0 {
            state.get_counts[idx_i] = state.get_counts[idx_i] - 1
          }
          state.changed.val = true
          TInstr::local_get(sl_localidx_from_int(best))
        } else {
          instr
        }
      } else {
        instr
      }
    }
    TInstrKind::TBlock(bt, body) => {
      sl_late_clear(state)
      let next_body = sl_late_rewrite_texpr(body, state)
      sl_late_clear(state)
      if next_body != body {
        state.changed.val = true
        TInstr::block(bt, next_body)
      } else {
        instr
      }
    }
    TInstrKind::TLoop(bt, body) => {
      sl_late_clear(state)
      let next_body = sl_late_rewrite_texpr(body, state)
      sl_late_clear(state)
      if next_body != body {
        state.changed.val = true
        TInstr::loop_(bt, next_body)
      } else {
        instr
      }
    }
    TInstrKind::TTryTable(bt, catches, body) => {
      sl_late_clear(state)
      let next_body = sl_late_rewrite_texpr(body, state)
      sl_late_clear(state)
      if next_body != body {
        state.changed.val = true
        TInstr::try_table(bt, catches, next_body)
      } else {
        instr
      }
    }
    TInstrKind::TIf(bt, cond, then_body, else_body) => {
      let next_cond = sl_late_rewrite_instr(cond, state, true)
      sl_late_clear(state)
      let next_then = sl_late_rewrite_texpr(then_body, state)
      sl_late_clear(state)
      let next_else = else_body.map(fn(other) {
        let rewritten = sl_late_rewrite_texpr(other, state)
        sl_late_clear(state)
        rewritten
      })
      if next_cond != cond || next_then != then_body || next_else != else_body {
        state.changed.val = true
        TInstr::if_(bt, next_cond, next_then, next_else)
      } else {
        instr
      }
    }
    _ => {
      let next_children : Array[TInstr] = []
      let mut changed_children = false
      for child in eval_children(instr) {
        let next_child = sl_late_rewrite_instr(child, state, true)
        if next_child != child {
          changed_children = true
        }
        next_children.push(next_child)
      }
      if next_children.is_empty() {
        instr
      } else if changed_children {
        state.changed.val = true
        mb_rebuild_non_control(instr, next_children)
      } else {
        instr
      }
    }
  }
}

///|
fn sl_late_rewrite_texpr(body : TExpr, state : SLLateState) -> TExpr {
  let out : Array[TInstr] = []
  for instr in body.instrs {
    let next = sl_late_rewrite_instr(instr, state, false)
    out.push(next)
    if lcs_is_non_linear_boundary(next) || is_unreachable_instr(next) {
      sl_late_clear(state)
    }
  }
  TExpr::new(out)
}

///|
fn sl_has_late_candidate_instr(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TLocalSet(_, value) | TInstrKind::TLocalTee(_, value) =>
      match sl_get_fallthrough(value).kind {
        TInstrKind::TLocalGet(_) => true
        _ => sl_has_late_candidate_instr(value)
      }
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) => sl_has_late_candidate_texpr(body)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      if sl_has_late_candidate_instr(cond) ||
        sl_has_late_candidate_texpr(then_body) {
        return true
      }
      match else_body {
        Some(other) => sl_has_late_candidate_texpr(other)
        None => false
      }
    }
    _ => {
      for child in eval_children(instr) {
        if sl_has_late_candidate_instr(child) {
          return true
        }
      }
      false
    }
  }
}

///|
fn sl_has_late_candidate_texpr(body : TExpr) -> Bool {
  for instr in body.instrs {
    if sl_has_late_candidate_instr(instr) {
      return true
    }
  }
  false
}

///|
fn sl_run_late_optimizations(
  body : TExpr,
  local_types : Array[ValType],
  remove_equivalent_sets : Bool,
) -> (TExpr, Bool) {
  let local_count = local_types.length()
  let get_counts = Array::make(local_count, 0)
  let saw_late_candidate = Ref::new(false)
  sl_collect_get_counts_and_late_candidate_texpr(
    body, get_counts, saw_late_candidate,
  )
  if !saw_late_candidate.val {
    return (body, false)
  }
  let changed = Ref::new(false)
  let state = sl_late_state_new(
    local_types,
    get_counts,
    sl_test_env(local_types),
    remove_equivalent_sets,
    changed,
  )
  let next = sl_late_rewrite_texpr(body, state)
  (next, changed.val)
}

///|
fn sl_run_late_optimizations_with_counts(
  body : TExpr,
  local_types : Array[ValType],
  get_counts : Array[Int],
  saw_late_candidate : Bool,
  remove_equivalent_sets : Bool,
) -> (TExpr, Bool) {
  if !saw_late_candidate {
    return (body, false)
  }
  let changed = Ref::new(false)
  let state = sl_late_state_new(
    local_types,
    get_counts,
    sl_test_env(local_types),
    remove_equivalent_sets,
    changed,
  )
  let next = sl_late_rewrite_texpr(body, state)
  (next, changed.val)
}

///|
fn sl_tee_required_by_structure_path(
  tee_body : TExpr,
  no_tee_body : TExpr,
  no_tee_changed : Bool,
) -> Bool {
  if !sl_has_any_br_if_with_tee_value_texpr(tee_body) {
    return false
  }
  let tee_has_structure = sl_has_result_block_texpr(tee_body) ||
    sl_has_result_if_texpr(tee_body)
  if !tee_has_structure {
    return false
  }
  if !no_tee_changed {
    return true
  }
  let no_tee_has_structure = sl_has_result_block_texpr(no_tee_body) ||
    sl_has_result_if_texpr(no_tee_body)
  !no_tee_has_structure
}

///|
fn sl_should_keep_tee_candidate(
  tee_changed : Bool,
  tee_shrank : Bool,
  no_tee_changed : Bool,
  tee_required_by_structure : Bool,
) -> Bool {
  if !tee_changed {
    return false
  }
  if tee_shrank {
    return true
  }
  tee_required_by_structure && !no_tee_changed
}

///|
fn sl_run_main_phase(
  body : TExpr,
  env : Env,
  local_types : Array[ValType],
  options : SLSimplifyOptions,
  measure_for_tee : Bool,
  initial_get_counts? : SLMainGetCounts? = None,
  effects_cache? : Map[TInstr, LCSEffects]? = None,
  force_sparse_counts? : Bool = false,
  trace? : (String) -> Unit = sl_trace_noop,
  trace_verbose? : Bool = false,
) -> (TExpr, Bool, Bool, SLMainGetCounts) {
  let helper_timing_enabled = trace_verbose
  let shared_effects_cache = match effects_cache {
    Some(cache) => cache
    None => Map::new()
  }
  let count_start_ms = sl_trace_now_ms()
  let get_counts = match initial_get_counts {
    Some(existing) => {
      if trace_verbose {
        trace(
          "phase=main:count:reuse locals=\{local_types.length()} elapsed_ms=\{sl_trace_elapsed_ms(count_start_ms)}",
        )
      }
      existing
    }
    None => {
      if trace_verbose {
        trace("phase=main:count:start locals=\{local_types.length()}")
      }
      let fresh = sl_main_get_counts_new(
        local_types.length(),
        force_sparse_counts,
      )
      let collect_gets_start_us = if helper_timing_enabled {
        sl_trace_now_us()
      } else {
        0UL
      }
      sl_main_collect_get_counts_texpr(body, fresh)
      sl_helper_timing_commit(
        helper_timing_enabled, sl_helper_timing_collect_get_counts_texpr_us, sl_helper_timing_collect_get_counts_texpr_calls,
        collect_gets_start_us,
      )
      if trace_verbose {
        trace(
          "phase=main:count:done locals=\{local_types.length()} elapsed_ms=\{sl_trace_elapsed_ms(count_start_ms)}",
        )
      }
      fresh
    }
  }
  let rewrite_start_ms = sl_trace_now_ms()
  if !options.allow_structure {
    if !sl_main_get_counts_has_any(get_counts) {
      if trace_verbose {
        trace("phase=main:rewrite:skip reason=no_local_gets")
      }
      return (body, false, false, get_counts)
    }
  }
  if !options.allow_tee && !options.allow_structure {
    let precheck_start_ms = sl_trace_now_ms()
    let (has_no_tee_opportunity, saw_single_use_set, saw_drop_local_tee) = sl_main_has_no_tee_rewrite_opportunity(
      body, get_counts,
    )
    if trace_verbose {
      trace(
        "phase=main:rewrite:precheck mode=no_tee_no_structure opportunity=\{has_no_tee_opportunity} single_use_set=\{saw_single_use_set} drop_local_tee=\{saw_drop_local_tee} elapsed_ms=\{sl_trace_elapsed_ms(precheck_start_ms)}",
      )
    }
    if !has_no_tee_opportunity {
      if trace_verbose {
        trace("phase=main:rewrite:skip reason=no_tee_opportunity")
      }
      return (body, false, false, get_counts)
    }
    let (pathological_deep_control, max_depth, control_nodes) = sl_main_is_pathological_deep_control_candidate(
      body,
      local_types.length(),
      options,
    )
    if pathological_deep_control {
      if trace_verbose {
        trace(
          "phase=main:rewrite:skip reason=pathological_deep_control max_depth=\{max_depth} control_nodes=\{control_nodes} top_instrs=\{body.instrs.length()} locals=\{local_types.length()}",
        )
      }
      return (body, false, false, get_counts)
    }
  }
  if trace_verbose {
    trace("phase=main:rewrite:start top_instrs=\{body.instrs.length()}")
  }
  let rewrite_start_us = if helper_timing_enabled {
    sl_trace_now_us()
  } else {
    0UL
  }
  if trace_verbose {
    sl_main_rewrite_helper_trace_reset()
    sl_main_rewrite_helper_trace_enabled.val = true
    sl_main_rewrite_helper_trace_progress_reset(trace)
  }
  let (next_body, changed) = sl_simplify_texpr_main(
    body, env, local_types, get_counts, options, shared_effects_cache,
  )
  if trace_verbose {
    sl_main_rewrite_helper_trace_enabled.val = false
    sl_main_rewrite_helper_trace_progress_disable()
  }
  sl_helper_timing_commit(
    helper_timing_enabled, sl_helper_timing_simplify_texpr_main_us, sl_helper_timing_simplify_texpr_main_calls,
    rewrite_start_us,
  )
  if trace_verbose {
    sl_trace_emit_main_rewrite_helper_timing(
      trace,
      sl_main_rewrite_helper_trace_snapshot(),
    )
    trace(
      "phase=main:rewrite:done changed=\{changed} top_instrs=\{next_body.instrs.length()} elapsed_ms=\{sl_trace_elapsed_ms(rewrite_start_ms)}",
    )
  }
  let shrank = if measure_for_tee && changed {
    lcs_measure_texpr(next_body) < lcs_measure_texpr(body)
  } else {
    false
  }
  (next_body, changed, shrank, get_counts)
}

///|
fn sl_run_cleanup_phase(
  body : TExpr,
  local_types : Array[ValType],
  remove_equivalent_sets : Bool,
  had_prior_changes : Bool,
  trace? : (String) -> Unit = sl_trace_noop,
  trace_verbose? : Bool = false,
) -> (TExpr, Bool) {
  let helper_timing_enabled = trace_verbose
  let removed_changed = Ref::new(false)
  let strip_changed = Ref::new(false)
  let pre_counts = Array::make(local_types.length(), 0)
  let pre_saw_late_candidate = Ref::new(false)
  let cleanup_main_start_ms = sl_trace_now_ms()
  if trace_verbose {
    trace(
      "phase=cleanup:remove_strip:start top_instrs=\{body.instrs.length()} locals=\{local_types.length()}",
    )
  }
  let after_strip = if had_prior_changes {
    sl_collect_get_counts_and_late_candidate_texpr(
      body, pre_counts, pre_saw_late_candidate,
    )
    let remove_sets_start_us = if helper_timing_enabled {
      sl_trace_now_us()
    } else {
      0UL
    }
    let after_removed = sl_remove_unneeded_sets_texpr(
      body, pre_counts, removed_changed,
    )
    sl_helper_timing_commit(
      helper_timing_enabled, sl_helper_timing_remove_unneeded_sets_texpr_us, sl_helper_timing_remove_unneeded_sets_texpr_calls,
      remove_sets_start_us,
    )
    let strip_nops_start_us = if helper_timing_enabled {
      sl_trace_now_us()
    } else {
      0UL
    }
    let after_stripped = sl_strip_nops_texpr(after_removed, strip_changed)
    sl_helper_timing_commit(
      helper_timing_enabled, sl_helper_timing_strip_nops_texpr_us, sl_helper_timing_strip_nops_texpr_calls,
      strip_nops_start_us,
    )
    after_stripped
  } else {
    body
  }
  if trace_verbose {
    trace(
      "phase=cleanup:remove_strip:done changed=\{removed_changed.val || strip_changed.val} top_instrs=\{after_strip.instrs.length()} elapsed_ms=\{sl_trace_elapsed_ms(cleanup_main_start_ms)}",
    )
  }
  let late_start_ms = sl_trace_now_ms()
  if trace_verbose {
    trace("phase=cleanup:late:start top_instrs=\{after_strip.instrs.length()}")
  }
  let late_start_us = if helper_timing_enabled {
    sl_trace_now_us()
  } else {
    0UL
  }
  let (after_late, late_changed) = if had_prior_changes && after_strip == body {
    sl_run_late_optimizations_with_counts(
      after_strip,
      local_types,
      pre_counts,
      pre_saw_late_candidate.val,
      remove_equivalent_sets,
    )
  } else {
    sl_run_late_optimizations(after_strip, local_types, remove_equivalent_sets)
  }
  sl_helper_timing_commit(
    helper_timing_enabled, sl_helper_timing_run_late_optimizations_us, sl_helper_timing_run_late_optimizations_calls,
    late_start_us,
  )
  if trace_verbose {
    trace(
      "phase=cleanup:late:done changed=\{late_changed} top_instrs=\{after_late.instrs.length()} elapsed_ms=\{sl_trace_elapsed_ms(late_start_ms)}",
    )
  }
  let next = if late_changed { after_late } else { after_strip }
  (next, removed_changed.val || strip_changed.val || late_changed)
}

///|
fn sl_count_imported_funcs(mod : Module) -> Int {
  let mut count = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, FuncExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn sl_validate_rewritten_function(
  mod : Module,
  current_funcs : Array[Func],
  imported_func_count : Int,
  def_idx : Int,
  prev_func : Func,
  next_func : Func,
) -> Unit {
  let candidate_mod = mod.with_code_sec(CodeSec::new(current_funcs.copy()))
  match validate_module(candidate_mod) {
    Ok(_) => ()
    Err(e) =>
      abort(
        "simplify_locals validation failed for defined func \{def_idx} (func idx \{imported_func_count + def_idx}): \{e}\nBefore:\n\{prev_func}\nAfter:\n\{next_func}",
      )
  }
}

///|
fn sl_can_validate_rewritten_functions(mod : Module) -> Bool {
  match (mod.func_sec, mod.code_sec) {
    (Some(FuncSec(type_idxs)), Some(CodeSec(funcs))) =>
      type_idxs.length() == funcs.length()
    _ => false
  }
}

///|
fn sl_validate_typed_function_candidate(
  env : Env,
  abs_func_idx : FuncIdx,
  func : Func,
) -> Result[Unit, String] {
  let FuncType(params, results) = match
    env.get_functype_by_funcidx(abs_func_idx) {
    Some(ft) => ft
    None => return Ok(())
  }
  match func {
    TFunc(tfunc_params, local_vals, body) => {
      let locals = match
        FunctionLocals::from_typed_func(params, tfunc_params, local_vals) {
        Ok(ls) => ls
        Err(e) => return Err(e)
      }
      let env1 = env
        .with_locals(locals.all_locals())
        .with_label(results)
        .with_return_type(Some(results))
      let st1 = match Typecheck::typecheck(body, make_state(env1, [])) {
        Ok(st) => st
        Err(e) => return Err(e)
      }
      if !st1.reachable {
        return Ok(())
      }
      if st1.stack.length() != results.length() {
        return Err(
          "typed function body has wrong result arity: stack=\{st1.stack} results=\{results}",
        )
      }
      for i in 0..<results.length() {
        if !Match::matches(st1.stack[i], results[i], env1) {
          return Err("typed function body result type mismatch")
        }
      }
      Ok(())
    }
    _ => Ok(())
  }
}

///|
fn sl_try_repair_duplicated_param_prefix_locals(
  env : Env,
  abs_func_idx : FuncIdx,
  original : Func,
  candidate : Func,
) -> Func? {
  let FuncType(declared_params, _) = match
    env.get_functype_by_funcidx(abs_func_idx) {
    Some(ft) => ft
    None => return None
  }
  let (original_params, original_local_vals) = match original {
    TFunc(params, local_vals, _) => (params, local_vals)
    _ => return None
  }
  match candidate {
    TFunc(tfunc_params, local_vals, body) =>
      if tfunc_params != declared_params ||
        tfunc_params != original_params ||
        local_vals.length() !=
        declared_params.length() + original_local_vals.length() {
        None
      } else {
        for i = 0; i < declared_params.length(); i = i + 1 {
          if local_vals[i] != declared_params[i] {
            return None
          }
        }
        for i = 0; i < original_local_vals.length(); i = i + 1 {
          if local_vals[declared_params.length() + i] != original_local_vals[i] {
            return None
          }
        }
        let repaired_locals = original_local_vals.copy()
        Some(Func::t_func(tfunc_params, repaired_locals, body))
      }
    _ => None
  }
}

///|
fn sl_try_salvage_typed_candidate(
  env : Env,
  abs_func_idx : FuncIdx,
  original : Func,
  candidate : Func,
  trace : (String) -> Unit,
) -> Func? {
  match
    sl_try_repair_duplicated_param_prefix_locals(
      env, abs_func_idx, original, candidate,
    ) {
    Some(repaired) =>
      if repaired == candidate {
        None
      } else {
        match
          sl_validate_typed_function_candidate(env, abs_func_idx, repaired) {
          Ok(_) => {
            trace(
              "func_idx=\{abs_func_idx.to_string()} rewrite accepted after duplicated param-prefix local repair",
            )
            Some(repaired)
          }
          Err(err) => {
            sl_trace_rewrite_validation_failure(
              trace,
              "func_idx=\{abs_func_idx.to_string()} rewrite repair attempt failed local validation: \{err}",
            )
            None
          }
        }
      }
    None => None
  }
}

///|
fn sl_keep_validated_rewrite(
  env : Env,
  abs_func_idx : FuncIdx,
  original : Func,
  candidate : Func,
  trace : (String) -> Unit,
) -> (Func, Bool) {
  sl_rewrite_validation_raw_candidates_attempted.val = sl_rewrite_validation_raw_candidates_attempted.val +
    1
  match sl_validate_typed_function_candidate(env, abs_func_idx, candidate) {
    Ok(_) => {
      sl_rewrite_validation_candidates_accepted.val = sl_rewrite_validation_candidates_accepted.val +
        1
      (candidate, true)
    }
    Err(err) =>
      match
        sl_try_salvage_typed_candidate(
          env, abs_func_idx, original, candidate, trace,
        ) {
        Some(repaired) => {
          sl_rewrite_validation_candidates_accepted.val = sl_rewrite_validation_candidates_accepted.val +
            1
          (repaired, true)
        }
        None => {
          sl_rewrite_validation_candidates_rejected_local_validation.val = sl_rewrite_validation_candidates_rejected_local_validation.val +
            1
          sl_rewrite_validation_record_rejection_reason(err)
          sl_trace_rewrite_validation_failure(
            trace,
            "func_idx=\{abs_func_idx.to_string()} rewrite rejected after local validation: \{err}",
          )
          (original, false)
        }
      }
  }
}

///|
fn sl_simplify_function(
  func : Func,
  env : Env,
  param_types : Array[ValType],
  options : SLSimplifyOptions,
  trace? : (String) -> Unit = sl_trace_noop,
  trace_verbose? : Bool = false,
) -> (Func, Bool) {
  match func {
    TFunc(tfunc_params, locals, body) => {
      let local_types = sl_require_typed_function_locals(
        param_types, tfunc_params, locals, "sl_simplify_function",
      ).all_locals()
      if local_types.length() == 0 {
        return (func, false)
      }
      let pathological_profile = sl_is_pathological_fastpath_candidate(
        local_types.length(),
        body.instrs.length(),
      )
      let disable_nesting_profile = sl_is_wide_locals_no_nesting_candidate(
        local_types.length(),
        body.instrs.length(),
      )
      let func_tick_start = sl_trace_now_us()
      let shared_effects_cache : Map[TInstr, LCSEffects] = Map::new()
      let mut body = body
      let mut changed_any = false
      let mut first_cycle = true
      let mut continue_cycles = true
      let mut reusable_get_counts : SLMainGetCounts? = None
      let mut cycle = 0
      while continue_cycles {
        if pathological_profile &&
          sl_pathological_budget_exceeded(func_tick_start) {
          if trace_verbose {
            trace(
              "summary cycles=\{cycle} changed_any=\{changed_any} final_top_instrs=\{body.instrs.length()} budget_exceeded=true action=revert_original budget_ticks=\{SL_PATHOLOGICAL_FUNC_TICK_BUDGET}",
            )
          }
          return (func, false)
        }
        cycle += 1
        if trace_verbose {
          trace(
            "cycle=\{cycle} phase=main:start first_cycle=\{first_cycle} top_instrs=\{body.instrs.length()}",
          )
        }
        let cycle_options = if first_cycle || pathological_profile {
          {
            allow_tee: false,
            allow_structure: options.allow_structure,
            allow_nesting: if disable_nesting_profile {
              false
            } else {
              options.allow_nesting
            },
          }
        } else {
          {
            allow_tee: options.allow_tee,
            allow_structure: options.allow_structure,
            allow_nesting: if disable_nesting_profile {
              false
            } else {
              options.allow_nesting
            },
          }
        }
        let measure_for_tee = cycle_options.allow_tee
        let main_phase_start_us = if trace_verbose {
          sl_trace_now_us()
        } else {
          0UL
        }
        let (raw_after_main, raw_main_changed, raw_shrank, raw_get_counts) = sl_run_main_phase(
          body,
          env,
          local_types,
          cycle_options,
          measure_for_tee,
          initial_get_counts=reusable_get_counts,
          effects_cache=Some(shared_effects_cache),
          force_sparse_counts=pathological_profile,
          trace~,
          trace_verbose~,
        )
        sl_helper_timing_commit(
          trace_verbose, sl_helper_timing_run_main_phase_us, sl_helper_timing_run_main_phase_calls,
          main_phase_start_us,
        )
        if pathological_profile &&
          sl_pathological_budget_exceeded(func_tick_start) {
          if trace_verbose {
            trace(
              "summary cycles=\{cycle} changed_any=\{changed_any} final_top_instrs=\{body.instrs.length()} budget_exceeded=true action=revert_original budget_ticks=\{SL_PATHOLOGICAL_FUNC_TICK_BUDGET}",
            )
          }
          return (func, false)
        }
        let mut after_main = raw_after_main
        let mut main_changed = raw_main_changed
        let mut next_get_counts = raw_get_counts
        let should_compare_no_tee = cycle_options.allow_tee &&
          raw_main_changed &&
          !raw_shrank
        let should_run_no_tee = if should_compare_no_tee {
          sl_count_local_tees_texpr(raw_after_main) >
          sl_count_local_tees_texpr(body)
        } else {
          false
        }
        if should_compare_no_tee && !should_run_no_tee && trace_verbose {
          trace(
            "cycle=\{cycle} phase=main:tee_policy action=skip_no_tee_compare reason=no_new_tee",
          )
        }
        if should_run_no_tee {
          let no_tee_options = {
            allow_tee: false,
            allow_structure: cycle_options.allow_structure,
            allow_nesting: cycle_options.allow_nesting,
          }
          let no_tee_main_phase_start_us = if trace_verbose {
            sl_trace_now_us()
          } else {
            0UL
          }
          let (no_tee_body, no_tee_changed, _, no_tee_get_counts) = sl_run_main_phase(
            body,
            env,
            local_types,
            no_tee_options,
            false,
            initial_get_counts=reusable_get_counts,
            effects_cache=Some(shared_effects_cache),
            force_sparse_counts=pathological_profile,
            trace~,
            trace_verbose~,
          )
          sl_helper_timing_commit(
            trace_verbose, sl_helper_timing_run_main_phase_us, sl_helper_timing_run_main_phase_calls,
            no_tee_main_phase_start_us,
          )
          let tee_required_by_structure = sl_tee_required_by_structure_path(
            raw_after_main, no_tee_body, no_tee_changed,
          )
          if !sl_should_keep_tee_candidate(
              raw_main_changed, raw_shrank, no_tee_changed, tee_required_by_structure,
            ) {
            after_main = no_tee_body
            main_changed = no_tee_changed
            next_get_counts = no_tee_get_counts
            if trace_verbose {
              trace(
                "cycle=\{cycle} phase=main:tee_policy action=prefer_no_tee shrank=\{raw_shrank} no_tee_changed=\{no_tee_changed} structure_win=\{tee_required_by_structure}",
              )
            }
          } else if trace_verbose && tee_required_by_structure {
            trace(
              "cycle=\{cycle} phase=main:tee_policy action=keep_tee shrank=\{raw_shrank} structure_win=\{tee_required_by_structure}",
            )
          }
        }
        if trace_verbose {
          trace(
            "cycle=\{cycle} phase=main:done changed=\{main_changed} top_instrs=\{after_main.instrs.length()}",
          )
        }
        body = after_main
        reusable_get_counts = Some(next_get_counts)
        if main_changed {
          changed_any = true
        }
        if first_cycle {
          if trace_verbose {
            trace(
              "cycle=\{cycle} phase=first_cycle:advance allow_tee_next=\{options.allow_tee && !pathological_profile}",
            )
          }
          first_cycle = false
          if options.allow_tee && !pathological_profile {
            continue
          }
        }
        if main_changed && !pathological_profile {
          if trace_verbose {
            trace("cycle=\{cycle} phase=main:repeat reason=changed")
          }
          continue
        }
        if trace_verbose {
          trace(
            "cycle=\{cycle} phase=cleanup:start top_instrs=\{body.instrs.length()}",
          )
        }
        let cleanup_phase_start_us = if trace_verbose {
          sl_trace_now_us()
        } else {
          0UL
        }
        let (after_cleanup, cleanup_changed) = sl_run_cleanup_phase(
          body,
          local_types,
          options.allow_structure,
          true,
          trace~,
          trace_verbose~,
        )
        sl_helper_timing_commit(
          trace_verbose, sl_helper_timing_run_cleanup_phase_us, sl_helper_timing_run_cleanup_phase_calls,
          cleanup_phase_start_us,
        )
        if pathological_profile &&
          sl_pathological_budget_exceeded(func_tick_start) {
          if trace_verbose {
            trace(
              "summary cycles=\{cycle} changed_any=\{changed_any} final_top_instrs=\{body.instrs.length()} budget_exceeded=true action=revert_original budget_ticks=\{SL_PATHOLOGICAL_FUNC_TICK_BUDGET}",
            )
          }
          return (func, false)
        }
        if trace_verbose {
          trace(
            "cycle=\{cycle} phase=cleanup:done changed=\{cleanup_changed} top_instrs=\{after_cleanup.instrs.length()}",
          )
        }
        body = after_cleanup
        if cleanup_changed {
          changed_any = true
          reusable_get_counts = None
          if pathological_profile {
            if trace_verbose {
              trace(
                "cycle=\{cycle} phase=done reason=pathological_single_cycle",
              )
            }
            continue_cycles = false
            continue
          }
          if trace_verbose {
            trace(
              "cycle=\{cycle} phase=late_main:start top_instrs=\{body.instrs.length()}",
            )
          }
          let late_main_phase_start_us = if trace_verbose {
            sl_trace_now_us()
          } else {
            0UL
          }
          let (after_late_main, late_main_changed, _, late_get_counts) = sl_run_main_phase(
            body,
            env,
            local_types,
            {
              allow_tee: options.allow_tee,
              allow_structure: options.allow_structure,
              allow_nesting: if disable_nesting_profile {
                false
              } else {
                options.allow_nesting
              },
            },
            false,
            effects_cache=Some(shared_effects_cache),
            force_sparse_counts=pathological_profile,
            trace~,
            trace_verbose~,
          )
          sl_helper_timing_commit(
            trace_verbose, sl_helper_timing_run_main_phase_us, sl_helper_timing_run_main_phase_calls,
            late_main_phase_start_us,
          )
          if trace_verbose {
            trace(
              "cycle=\{cycle} phase=late_main:done changed=\{late_main_changed} top_instrs=\{after_late_main.instrs.length()}",
            )
          }
          body = after_late_main
          reusable_get_counts = Some(late_get_counts)
          if late_main_changed {
            changed_any = true
          } else {
            if trace_verbose {
              trace("cycle=\{cycle} phase=done reason=late_main_stable")
            }
            continue_cycles = false
          }
        } else {
          if trace_verbose {
            trace("cycle=\{cycle} phase=done reason=cleanup_stable")
          }
          continue_cycles = false
        }
      }
      if trace_verbose {
        trace(
          "summary cycles=\{cycle} changed_any=\{changed_any} final_top_instrs=\{body.instrs.length()}",
        )
      }
      let final_func = Func::t_func(tfunc_params, locals, body)
      if changed_any && final_func != func {
        (final_func, true)
      } else {
        (func, false)
      }
    }
    _ => (func, false)
  }
}

///|
fn simplify_locals_ir_pass(
  mod : Module,
  allow_tee : Bool,
  allow_structure : Bool,
  allow_nesting : Bool,
  validate_each_rewrite? : Bool = false,
  trace? : (String) -> Unit = sl_trace_noop,
  trace_all_funcs? : Bool = false,
) -> ModuleTransformer[IRContext, String] {
  sl_rewrite_validation_reset()
  sl_hotspot_reset()
  let options = { allow_tee, allow_structure, allow_nesting }
  let param_types = sl_collect_param_types(mod)
  let base_env = Env::new().with_module(mod)
  let imported_func_count = sl_count_imported_funcs(mod)
  let can_validate_rewrites = sl_can_validate_rewritten_functions(mod)
  let current_funcs = match mod.code_sec {
    Some(CodeSec(funcs)) => funcs.copy()
    None => []
  }
  let next_def_idx = Ref::new(0)
  ModuleTransformer::new().on_func_evt(fn(_, ctx, func) {
    let def_idx = next_def_idx.val
    next_def_idx.update(fn(i) { i + 1 })
    let ordinal = def_idx + 1
    let log_func = trace_all_funcs
    let func_start_ms = sl_trace_now_ms()
    let func_locals = match func {
      TFunc(_, locals, _) => locals.length()
      _ => 0
    }
    let func_top_instrs = match func {
      TFunc(_, _, body) => body.instrs.length()
      _ => 0
    }
    let helper_timing_start = if log_func {
      sl_helper_timing_snapshot()
    } else {
      sl_helper_timing_zero()
    }
    let params = param_types.get(def_idx).unwrap_or([])
    let abs_func_idx = FuncIdx::new(
      (imported_func_count + def_idx).reinterpret_as_uint(),
    )
    let func_env = match func {
      TFunc(tfunc_params, locals, _) =>
        base_env.with_locals(
          sl_require_typed_function_locals(
            params, tfunc_params, locals, "simplify_locals_ir_pass",
          ).all_locals(),
        )
      _ => base_env
    }
    let func_trace = if log_func {
      fn(msg) { trace("func[\{ordinal}] \{msg}") }
    } else {
      sl_trace_noop
    }
    if log_func {
      match func {
        TFunc(_, _, body) =>
          trace(
            "func[\{ordinal}] start locals=\{func_locals} top_instrs=\{body.instrs.length()} instrs=\{sl_count_all_instrs_texpr(body)} allow_tee=\{allow_tee} allow_structure=\{allow_structure} allow_nesting=\{allow_nesting} validate=\{validate_each_rewrite && can_validate_rewrites}",
          )
        _ => trace("func[\{ordinal}] skip non-typed-func")
      }
    }
    let (raw_next_func, raw_changed) = sl_simplify_function(
      func,
      func_env,
      params,
      options,
      trace=func_trace,
      trace_verbose=log_func,
    )
    let (next_func, changed) = if raw_changed && raw_next_func != func {
      sl_keep_validated_rewrite(
        base_env, abs_func_idx, func, raw_next_func, trace,
      )
    } else {
      (raw_next_func, false)
    }
    let helper_timing_delta = if log_func {
      Some(
        sl_helper_timing_diff(sl_helper_timing_snapshot(), helper_timing_start),
      )
    } else {
      None
    }
    match helper_timing_delta {
      Some(timing) =>
        sl_hotspot_record(
          ordinal,
          timing.run_main_phase_us,
          timing.simplify_texpr_main_us,
          func_locals,
          func_top_instrs,
        )
      None => ()
    }
    let action = if changed {
      if validate_each_rewrite &&
        can_validate_rewrites &&
        def_idx >= 0 &&
        def_idx < current_funcs.length() {
        current_funcs[def_idx] = next_func
        if log_func {
          trace(
            "func[\{ordinal}] validate start func_idx=\{imported_func_count + def_idx}",
          )
        }
        sl_validate_rewritten_function(
          mod, current_funcs, imported_func_count, def_idx, func, next_func,
        )
        if log_func {
          trace(
            "func[\{ordinal}] validate done func_idx=\{imported_func_count + def_idx}",
          )
        }
      }
      if log_func {
        match helper_timing_delta {
          Some(timing) => sl_trace_emit_helper_timing(trace, ordinal, timing)
          None => ()
        }
        let elapsed_ms = sl_trace_elapsed_ms(func_start_ms)
        match (func, next_func) {
          (TFunc(_, locals, body), TFunc(_, _, next_body)) =>
            trace(
              "func[\{ordinal}] done elapsed_ms=\{elapsed_ms} changed=true top_instrs=\{body.instrs.length()}->\{next_body.instrs.length()} locals=\{locals.length()}",
            )
          _ =>
            trace("func[\{ordinal}] done elapsed_ms=\{elapsed_ms} changed=true")
        }
      }
      change(ctx, next_func)
    } else {
      if log_func {
        match helper_timing_delta {
          Some(timing) => sl_trace_emit_helper_timing(trace, ordinal, timing)
          None => ()
        }
        let elapsed_ms = sl_trace_elapsed_ms(func_start_ms)
        match func {
          TFunc(_, locals, body) =>
            trace(
              "func[\{ordinal}] done elapsed_ms=\{elapsed_ms} changed=false top_instrs=\{body.instrs.length()}->\{body.instrs.length()} locals=\{locals.length()}",
            )
          _ =>
            trace(
              "func[\{ordinal}] done elapsed_ms=\{elapsed_ms} changed=false",
            )
        }
      }
      unchanged()
    }
    if log_func && def_idx + 1 >= current_funcs.length() {
      match sl_hotspot_summary_line() {
        Some(summary) => trace(summary)
        None => ()
      }
    }
    action
  })
}

///|
fn sl_run_simplify_locals(
  mod : Module,
  allow_tee? : Bool = true,
  allow_structure? : Bool = true,
  allow_nesting? : Bool = true,
  validate_each_rewrite? : Bool = false,
) -> Module {
  let pass = simplify_locals_ir_pass(
    mod,
    allow_tee,
    allow_structure,
    allow_nesting,
    validate_each_rewrite~,
  )
  match pass.walk_module(IRContext::new(), mod) {
    Ok((out, _)) => out
    Err(e) => abort("simplify_locals pass failed: \{e}")
  }
}

///|
fn sl_test_env(local_types : Array[ValType]) -> Env {
  Env::new().with_locals(local_types)
}

///|
test "simplify_locals sinks a single-use local.set into local.get" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [ValType::i32()],
        TExpr::new([
          TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(7))),
          TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
        ]),
      ),
    ]),
  )
  let out = sl_run_simplify_locals(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) => {
      let stats = SLLocalStats::new()
      sl_collect_local_stats_texpr(body, stats)
      assert_eq(stats.sets, 0)
      assert_eq(stats.gets, 0)
      match body.instrs {
        [
          {
            kind: TInstrKind::TDrop({ kind: TInstrKind::TI32Const(I32(v)), .. }),
            ..,
          },
        ] => assert_eq(v, 7)
        _ => fail("expected sunk local to become drop(i32.const 7)")
      }
    }
    _ => fail("expected one typed function")
  }
}

///|
test "simplify_locals tee mode can eliminate multi-use local chain" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [ValType::i32()],
        TExpr::new([
          TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(9))),
          TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
          TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
        ]),
      ),
    ]),
  )
  let out = sl_run_simplify_locals(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) => {
      let stats = SLLocalStats::new()
      sl_collect_local_stats_texpr(body, stats)
      assert_eq(stats.sets, 0)
      assert_true(stats.gets <= 1)
    }
    _ => fail("expected one typed function")
  }
}

///|
test "simplify_locals no-tee mode keeps original set for multi-use local" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [ValType::i32()],
        TExpr::new([
          TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(11))),
          TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
          TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
        ]),
      ),
    ]),
  )
  let out = sl_run_simplify_locals(mod, allow_tee=false)
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) => {
      let stats = SLLocalStats::new()
      sl_collect_local_stats_texpr(body, stats)
      assert_true(stats.sets >= 1)
      assert_eq(stats.tees, 0)
    }
    _ => fail("expected one typed function")
  }
}

///|
test "simplify_locals tee profitability keeps shrinking tee rewrites" {
  let body = TExpr::new([
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(9))),
    TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
    TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
  ])
  let (rewritten, changed, shrank, _) = sl_run_main_phase(
    body,
    sl_test_env([ValType::i32()]),
    [ValType::i32()],
    { allow_tee: true, allow_structure: false, allow_nesting: true },
    true,
  )
  ignore(rewritten)
  assert_true(changed)
  assert_true(shrank)
  assert_true(sl_should_keep_tee_candidate(changed, shrank, false, false))
}

///|
test "simplify_locals tee profitability skips non-shrinking tee rewrites without structure win" {
  assert_false(sl_should_keep_tee_candidate(true, false, false, false))
}

///|
test "simplify_locals tee profitability does not affect no-tee simplification path" {
  let func = Func::t_func(
    [],
    [ValType::i32()],
    TExpr::new([
      TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(11))),
      TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
      TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
    ]),
  )
  let (next_func, changed) = sl_simplify_function(
    func,
    sl_test_env([ValType::i32()]),
    [],
    { allow_tee: false, allow_structure: false, allow_nesting: true },
  )
  assert_false(changed)
  match next_func {
    TFunc(_, _, body) => {
      let stats = SLLocalStats::new()
      sl_collect_local_stats_texpr(body, stats)
      assert_true(stats.sets >= 1)
      assert_eq(stats.tees, 0)
    }
    _ => fail("expected typed function")
  }
}

///|
test "simplify_locals structure mode creates result if from branch-local sets" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [ValType::i32()],
        TExpr::new([
          TInstr::if_(
            BlockType::void_(),
            TInstr::i32_const(I32(1)),
            TExpr::new([
              TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(3))),
            ]),
            Some(
              TExpr::new([
                TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(5))),
              ]),
            ),
          ),
          TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
        ]),
      ),
    ]),
  )
  let out = sl_run_simplify_locals(mod, allow_tee=false, allow_structure=true)
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) =>
      assert_true(sl_has_result_if_texpr(body))
    _ => fail("expected one typed function")
  }
}

///|
test "simplify_locals structures if when terminal local.set is wrapped with trailing nops" {
  let x = LocalIdx::new(0)
  let instr = TInstr::if_(
    BlockType::void_(),
    TInstr::i32_const(I32(1)),
    TExpr::new([
      TInstr::block(
        BlockType::void_(),
        TExpr::new([
          TInstr::nop(),
          TInstr::local_set(x, TInstr::i32_const(I32(3))),
          TInstr::nop(),
        ]),
      ),
      TInstr::nop(),
    ]),
    Some(
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([
            TInstr::local_set(x, TInstr::i32_const(I32(5))),
            TInstr::nop(),
          ]),
        ),
      ]),
    ),
  )
  let changed = Ref::new(false)
  let out = sl_try_structure_if(
    instr,
    sl_test_env([ValType::i32()]),
    [ValType::i32()],
    sl_main_get_counts_new(1, false),
    { allow_tee: false, allow_structure: true, allow_nesting: true },
    false,
    changed,
  )
  assert_true(changed.val)
  match out.kind {
    TInstrKind::TLocalSet(
      _,
      { kind: TInstrKind::TIf(ValTypeBlockType(_), _, _, _), .. }
    ) => ()
    _ => fail("expected wrapped terminal local.set form to structure")
  }
}

///|
test "simplify_locals keeps if unstructured when trailing effectful instruction follows local.set" {
  let x = LocalIdx::new(0)
  let instr = TInstr::if_(
    BlockType::void_(),
    TInstr::i32_const(I32(1)),
    TExpr::new([
      TInstr::local_set(x, TInstr::i32_const(I32(3))),
      TInstr::drop(TInstr::i32_const(I32(0))),
    ]),
    Some(TExpr::new([TInstr::local_set(x, TInstr::i32_const(I32(5)))])),
  )
  let changed = Ref::new(false)
  let out = sl_try_structure_if(
    instr,
    sl_test_env([ValType::i32()]),
    [ValType::i32()],
    sl_main_get_counts_new(1, false),
    { allow_tee: false, allow_structure: true, allow_nesting: true },
    false,
    changed,
  )
  assert_false(changed.val)
  assert_eq(out, instr)
}

///|
test "simplify_locals still structures plain terminal local.set branches" {
  let x = LocalIdx::new(0)
  let instr = TInstr::if_(
    BlockType::void_(),
    TInstr::i32_const(I32(1)),
    TExpr::new([TInstr::local_set(x, TInstr::i32_const(I32(3)))]),
    Some(TExpr::new([TInstr::local_set(x, TInstr::i32_const(I32(5)))])),
  )
  let changed = Ref::new(false)
  let out = sl_try_structure_if(
    instr,
    sl_test_env([ValType::i32()]),
    [ValType::i32()],
    sl_main_get_counts_new(1, false),
    { allow_tee: false, allow_structure: true, allow_nesting: true },
    false,
    changed,
  )
  assert_true(changed.val)
  match out.kind {
    TInstrKind::TLocalSet(
      _,
      { kind: TInstrKind::TIf(ValTypeBlockType(_), _, _, _), .. }
    ) => ()
    _ => fail("expected plain terminal local.set pattern to keep structuring")
  }
}

///|
test "simplify_locals sinks across adjacent transparent block boundary" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [ValType::i32()],
        TExpr::new([
          TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(7))),
          TInstr::block(BlockType::void_(), TExpr::new([TInstr::nop()])),
          TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
        ]),
      ),
    ]),
  )
  let out = sl_run_simplify_locals(
    mod,
    allow_tee=false,
    allow_structure=false,
    allow_nesting=true,
  )
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) => {
      let stats = SLLocalStats::new()
      sl_collect_local_stats_texpr(body, stats)
      assert_eq(stats.sets, 0)
      assert_eq(stats.gets, 0)
    }
    _ => fail("expected one typed function")
  }
}

///|
test "simplify_locals keeps sink boundary clear across branchy block" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [ValType::i32()],
        TExpr::new([
          TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(7))),
          TInstr::block(
            BlockType::void_(),
            TExpr::new([TInstr::br(LabelIdx::new(0), [])]),
          ),
          TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
        ]),
      ),
    ]),
  )
  let out = sl_run_simplify_locals(
    mod,
    allow_tee=false,
    allow_structure=false,
    allow_nesting=true,
  )
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) => {
      let stats = SLLocalStats::new()
      sl_collect_local_stats_texpr(body, stats)
      assert_true(stats.sets >= 1)
    }
    _ => fail("expected one typed function")
  }
}

///|
test "simplify_locals adjacent-boundary merge converges without rewrite oscillation" {
  let base = Func::t_func(
    [],
    [ValType::i32()],
    TExpr::new([
      TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(7))),
      TInstr::block(BlockType::void_(), TExpr::new([TInstr::nop()])),
      TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
    ]),
  )
  let (once, changed_once) = sl_simplify_function(
    base,
    sl_test_env([ValType::i32()]),
    [],
    { allow_tee: false, allow_structure: false, allow_nesting: true },
  )
  assert_true(changed_once)
  let (twice, changed_twice) = sl_simplify_function(
    once,
    sl_test_env([ValType::i32()]),
    [],
    { allow_tee: false, allow_structure: false, allow_nesting: true },
  )
  assert_false(changed_twice)
  assert_eq(twice, once)
}

///|
test "simplify_locals no-nesting mode avoids sinking non-get values into get sites" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [ValType::i32()],
        TExpr::new([
          TInstr::local_set(
            LocalIdx::new(0),
            TInstr::binary(
              BinaryOp::i32_add(),
              TInstr::i32_const(I32(1)),
              TInstr::i32_const(I32(2)),
            ),
          ),
          TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
        ]),
      ),
    ]),
  )
  let out = sl_run_simplify_locals(
    mod,
    allow_tee=true,
    allow_structure=false,
    allow_nesting=false,
  )
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) => {
      let stats = SLLocalStats::new()
      sl_collect_local_stats_texpr(body, stats)
      assert_true(stats.sets >= 1)
      assert_true(stats.gets >= 1)
    }
    _ => fail("expected one typed function")
  }
}

///|
test "simplify_locals coalesces block break sets into block result set" {
  let idx = LocalIdx::new(0)
  let cond = LocalIdx::new(1)
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [ValType::i32(), ValType::i32()],
        TExpr::new([
          TInstr::block(
            BlockType::void_(),
            TExpr::new([
              TInstr::if_(
                BlockType::void_(),
                TInstr::local_get(cond),
                TExpr::new([
                  TInstr::local_set(idx, TInstr::i32_const(I32(10))),
                  TInstr::br(LabelIdx::new(1), []),
                ]),
                Some(TExpr::new([TInstr::nop()])),
              ),
              TInstr::local_set(idx, TInstr::i32_const(I32(30))),
            ]),
          ),
          TInstr::drop(TInstr::local_get(idx)),
          TInstr::drop(TInstr::local_get(idx)),
        ]),
      ),
    ]),
  )
  let out = sl_run_simplify_locals(mod, allow_tee=false, allow_structure=true)
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) => {
      let has_result_block = sl_has_result_block_texpr(body)
      if !has_result_block {
        let stats = SLLocalStats::new()
        sl_collect_local_stats_texpr(body, stats)
        fail(
          "expected result block; sets=\{stats.sets}, tees=\{stats.tees}, gets=\{stats.gets}",
        )
      }
      assert_false(
        sl_has_local_set_for_idx_texpr(body, 0) &&
        sl_count_local_gets_for_idx_texpr(body, 0) == 0,
      )
    }
    _ => fail("expected one typed function")
  }
}

///|
test "simplify_locals coalesces conditional break sets using br_if tee value" {
  let x = LocalIdx::new(0)
  let cond_local = LocalIdx::new(1)
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [ValType::i32(), ValType::i32()],
        TExpr::new([
          TInstr::block(
            BlockType::void_(),
            TExpr::new([
              TInstr::local_set(x, TInstr::i32_const(I32(11))),
              TInstr::br_if(LabelIdx::new(0), TInstr::local_get(cond_local), []),
              TInstr::local_set(x, TInstr::i32_const(I32(22))),
            ]),
          ),
          TInstr::drop(TInstr::local_get(x)),
          TInstr::drop(TInstr::local_get(x)),
        ]),
      ),
    ]),
  )
  let out = sl_run_simplify_locals(mod, allow_tee=true, allow_structure=true)
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) => {
      let has_result_block = sl_has_result_block_texpr(body)
      if !has_result_block {
        let stats = SLLocalStats::new()
        sl_collect_local_stats_texpr(body, stats)
        fail(
          "expected block coalescing; sets=\{stats.sets}, tees=\{stats.tees}, gets=\{stats.gets}",
        )
      }
    }
    _ => fail("expected one typed function")
  }
}

///|
test "simplify_locals direct block rewrite uses tee for conditional break value" {
  let x = LocalIdx::new(0)
  let cond_local = LocalIdx::new(1)
  let block = TInstr::block(
    BlockType::void_(),
    TExpr::new([
      TInstr::local_set(x, TInstr::i32_const(I32(11))),
      TInstr::br_if(LabelIdx::new(0), TInstr::local_get(cond_local), []),
      TInstr::local_set(x, TInstr::i32_const(I32(22))),
    ]),
  )
  let changed = Ref::new(false)
  let out = sl_try_structure_block(
    block,
    sl_test_env([ValType::i32(), ValType::i32()]),
    [ValType::i32(), ValType::i32()],
    { allow_tee: true, allow_structure: true, allow_nesting: true },
    false,
    changed,
  )
  assert_true(changed.val)
  match out.kind {
    TInstrKind::TLocalSet(_, { kind: TInstrKind::TBlock(_, body), .. }) =>
      assert_true(sl_has_br_if_with_tee_value_texpr(body, 0))
    _ =>
      fail("expected local.set(block(...)) after direct conditional coalescing")
  }
}

///|
test "simplify_locals block rewrite skips conditional break coalescing when tee disabled" {
  let x = LocalIdx::new(0)
  let cond_local = LocalIdx::new(1)
  let block = TInstr::block(
    BlockType::void_(),
    TExpr::new([
      TInstr::local_set(x, TInstr::i32_const(I32(11))),
      TInstr::br_if(LabelIdx::new(0), TInstr::local_get(cond_local), []),
      TInstr::local_set(x, TInstr::i32_const(I32(22))),
    ]),
  )
  let changed = Ref::new(false)
  let out = sl_try_structure_block(
    block,
    sl_test_env([ValType::i32(), ValType::i32()]),
    [ValType::i32(), ValType::i32()],
    { allow_tee: false, allow_structure: true, allow_nesting: true },
    false,
    changed,
  )
  assert_false(changed.val)
  assert_eq(out, block)
}

///|
test "simplify_locals block-exit collector finds shared local in br_if pattern" {
  let x = LocalIdx::new(0)
  let cond_local = LocalIdx::new(1)
  let body = TExpr::new([
    TInstr::local_set(x, TInstr::i32_const(I32(11))),
    TInstr::br_if(LabelIdx::new(0), TInstr::local_get(cond_local), []),
    TInstr::local_set(x, TInstr::i32_const(I32(22))),
  ])
  let st = SLBlockCollectState::new()
  sl_collect_block_exit_candidates_texpr(body, 0, true, st)
  assert_true(st.saw_exit)
  assert_false(st.unoptimizable)
  assert_eq(st.shared_idx.unwrap_or(-1), 0)
}

///|
test "simplify_locals block-exit collector finds shared local in nested if breaks" {
  let x = LocalIdx::new(0)
  let body = TExpr::new([
    TInstr::if_(
      BlockType::void_(),
      TInstr::i32_const(I32(1)),
      TExpr::new([
        TInstr::local_set(x, TInstr::i32_const(I32(10))),
        TInstr::br(LabelIdx::new(1), []),
      ]),
      Some(
        TExpr::new([
          TInstr::local_set(x, TInstr::i32_const(I32(20))),
          TInstr::br(LabelIdx::new(1), []),
        ]),
      ),
    ),
    TInstr::local_set(x, TInstr::i32_const(I32(30))),
  ])
  let st = SLBlockCollectState::new()
  sl_collect_block_exit_candidates_texpr(body, 0, true, st)
  assert_true(st.saw_exit)
  assert_false(st.unoptimizable)
  assert_eq(st.shared_idx.unwrap_or(-1), 0)
}

///|
test "simplify_locals structures br_if when carried value is contained in condition tee" {
  let x = LocalIdx::new(0)
  let block = TInstr::block(
    BlockType::void_(),
    TExpr::new([
      TInstr::br_if(
        LabelIdx::new(0),
        TInstr::local_tee(x, TInstr::i32_const(I32(11))),
        [],
      ),
      TInstr::local_set(x, TInstr::i32_const(I32(22))),
    ]),
  )
  let changed = Ref::new(false)
  let out = sl_try_structure_block(
    block,
    sl_test_env([ValType::i32()]),
    [ValType::i32()],
    { allow_tee: true, allow_structure: true, allow_nesting: true },
    false,
    changed,
  )
  assert_true(changed.val)
  match out.kind {
    TInstrKind::TLocalSet(_, { kind: TInstrKind::TBlock(_, body), .. }) =>
      assert_true(sl_has_br_if_with_tee_value_texpr(body, 0))
    _ => fail("expected local.set(block(...)) from cond-carried br_if rewrite")
  }
}

///|
test "simplify_locals skips cond-carried br_if rewrite when effect-order proof fails" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let cond = TInstr::block(
    BlockType::val_type(ValType::i32()),
    TExpr::new([
      TInstr::local_set(x, TInstr::local_get(y)),
      TInstr::local_set(y, TInstr::i32_const(I32(5))),
      TInstr::i32_const(I32(1)),
    ]),
  )
  let block = TInstr::block(
    BlockType::void_(),
    TExpr::new([
      TInstr::br_if(LabelIdx::new(0), cond, []),
      TInstr::local_set(x, TInstr::i32_const(I32(22))),
    ]),
  )
  let changed = Ref::new(false)
  let out = sl_try_structure_block(
    block,
    sl_test_env([ValType::i32(), ValType::i32()]),
    [ValType::i32(), ValType::i32()],
    { allow_tee: true, allow_structure: true, allow_nesting: true },
    false,
    changed,
  )
  assert_false(changed.val)
  assert_eq(out, block)
}

///|
test "simplify_locals skips cond-carried br_if rewrite when carried value is type-invalid" {
  let x = LocalIdx::new(0)
  let cond = TInstr::block(
    BlockType::val_type(ValType::i32()),
    TExpr::new([
      TInstr::local_set(x, TInstr::i64_const(I64(7))),
      TInstr::i32_const(I32(1)),
    ]),
  )
  let block = TInstr::block(
    BlockType::void_(),
    TExpr::new([
      TInstr::br_if(LabelIdx::new(0), cond, []),
      TInstr::local_set(x, TInstr::i32_const(I32(22))),
    ]),
  )
  let changed = Ref::new(false)
  let out = sl_try_structure_block(
    block,
    sl_test_env([ValType::i32()]),
    [ValType::i32()],
    { allow_tee: true, allow_structure: true, allow_nesting: true },
    false,
    changed,
  )
  assert_false(changed.val)
  assert_eq(out, block)
}

///|
test "simplify_locals block-exit collector supports single-target br_table subset" {
  let x = LocalIdx::new(0)
  let body = TExpr::new([
    TInstr::local_set(x, TInstr::i32_const(I32(11))),
    TInstr::br_table([], LabelIdx::new(0), TInstr::i32_const(I32(0)), []),
    TInstr::local_set(x, TInstr::i32_const(I32(22))),
  ])
  let st = SLBlockCollectState::new()
  sl_collect_block_exit_candidates_texpr(body, 0, false, st)
  assert_true(st.saw_exit)
  assert_false(st.unoptimizable)
  assert_eq(st.shared_idx.unwrap_or(-1), 0)
}

///|
test "simplify_locals block-exit collector keeps mixed-target br_table unoptimizable" {
  let x = LocalIdx::new(0)
  let body = TExpr::new([
    TInstr::local_set(x, TInstr::i32_const(I32(11))),
    TInstr::br_table(
      [LabelIdx::new(1)],
      LabelIdx::new(0),
      TInstr::i32_const(I32(0)),
      [],
    ),
    TInstr::local_set(x, TInstr::i32_const(I32(22))),
  ])
  let st = SLBlockCollectState::new()
  sl_collect_block_exit_candidates_texpr(body, 0, false, st)
  assert_true(st.saw_exit)
  assert_true(st.unoptimizable)
}

///|
test "simplify_locals block-exit collector keeps br_table value-arity mismatch unoptimizable" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let body = TExpr::new([
    TInstr::br_table([], LabelIdx::new(0), TInstr::i32_const(I32(0)), [
      TInstr::local_set(x, TInstr::i32_const(I32(11))),
      TInstr::local_set(y, TInstr::i32_const(I32(22))),
    ]),
    TInstr::local_set(x, TInstr::i32_const(I32(33))),
  ])
  let st = SLBlockCollectState::new()
  sl_collect_block_exit_candidates_texpr(body, 0, false, st)
  assert_true(st.saw_exit)
  assert_true(st.unoptimizable)
}

///|
test "simplify_locals structures supported single-target br_table subset" {
  let x = LocalIdx::new(0)
  let block = TInstr::block(
    BlockType::void_(),
    TExpr::new([
      TInstr::local_set(x, TInstr::i32_const(I32(11))),
      TInstr::br_table([], LabelIdx::new(0), TInstr::i32_const(I32(0)), []),
      TInstr::local_set(x, TInstr::i32_const(I32(22))),
    ]),
  )
  let changed = Ref::new(false)
  let out = sl_try_structure_block(
    block,
    sl_test_env([ValType::i32()]),
    [ValType::i32()],
    { allow_tee: false, allow_structure: true, allow_nesting: true },
    false,
    changed,
  )
  assert_true(changed.val)
  match out.kind {
    TInstrKind::TLocalSet(
      _,
      { kind: TInstrKind::TBlock(ValTypeBlockType(_), _), .. }
    ) => ()
    _ => fail("expected supported br_table subset to structure")
  }
}

///|
test "simplify_locals direct block structure rewrite emits outer set over result block" {
  let x = LocalIdx::new(0)
  let c = LocalIdx::new(1)
  let block = TInstr::block(
    BlockType::void_(),
    TExpr::new([
      TInstr::if_(
        BlockType::void_(),
        TInstr::local_get(c),
        TExpr::new([
          TInstr::local_set(x, TInstr::i32_const(I32(10))),
          TInstr::br(LabelIdx::new(1), []),
        ]),
        Some(TExpr::new([TInstr::nop()])),
      ),
      TInstr::local_set(x, TInstr::i32_const(I32(30))),
    ]),
  )
  let changed = Ref::new(false)
  let out = sl_try_structure_block(
    block,
    sl_test_env([ValType::i32(), ValType::i32()]),
    [ValType::i32(), ValType::i32()],
    { allow_tee: false, allow_structure: true, allow_nesting: true },
    false,
    changed,
  )
  assert_true(changed.val)
  match out.kind {
    TInstrKind::TLocalSet(
      _,
      { kind: TInstrKind::TBlock(ValTypeBlockType(_), _), .. }
    ) => ()
    _ =>
      fail(
        "expected direct block rewrite to produce local.set(block(result ...))",
      )
  }
}

///|
test "simplify_locals function-level simplifier applies block coalescing pattern" {
  let idx = LocalIdx::new(0)
  let cond = LocalIdx::new(1)
  let func = Func::t_func(
    [],
    [ValType::i32(), ValType::i32()],
    TExpr::new([
      TInstr::block(
        BlockType::void_(),
        TExpr::new([
          TInstr::if_(
            BlockType::void_(),
            TInstr::local_get(cond),
            TExpr::new([
              TInstr::local_set(idx, TInstr::i32_const(I32(10))),
              TInstr::br(LabelIdx::new(1), []),
            ]),
            Some(TExpr::new([TInstr::nop()])),
          ),
          TInstr::local_set(idx, TInstr::i32_const(I32(30))),
        ]),
      ),
      TInstr::drop(TInstr::local_get(idx)),
      TInstr::drop(TInstr::local_get(idx)),
    ]),
  )
  let local_types = [ValType::i32(), ValType::i32()]
  let (next_func, changed) = sl_simplify_function(
    func,
    sl_test_env(local_types),
    [],
    { allow_tee: false, allow_structure: true, allow_nesting: true },
  )
  assert_true(changed)
  match next_func {
    TFunc(_, _, body) => assert_true(sl_has_result_block_texpr(body))
    _ => fail("expected typed function")
  }
}

///|
test "simplify_locals main-step rewrite applies block coalescing pattern" {
  let idx = LocalIdx::new(0)
  let cond = LocalIdx::new(1)
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::if_(
          BlockType::void_(),
          TInstr::local_get(cond),
          TExpr::new([
            TInstr::local_set(idx, TInstr::i32_const(I32(10))),
            TInstr::br(LabelIdx::new(1), []),
          ]),
          Some(TExpr::new([TInstr::nop()])),
        ),
        TInstr::local_set(idx, TInstr::i32_const(I32(30))),
      ]),
    ),
    TInstr::drop(TInstr::local_get(idx)),
    TInstr::drop(TInstr::local_get(idx)),
  ])
  let counts = sl_main_get_counts_new(2, false)
  sl_main_collect_get_counts_texpr(body, counts)
  let (next_body, changed) = sl_simplify_texpr_main(
    body,
    sl_test_env([ValType::i32(), ValType::i32()]),
    [ValType::i32(), ValType::i32()],
    counts,
    { allow_tee: false, allow_structure: true, allow_nesting: true },
    Map::new(),
  )
  assert_true(changed)
  assert_true(sl_has_result_block_texpr(next_body))
}

///|
test "simplify_locals instruction-level rewrite applies block coalescing pattern" {
  let idx = LocalIdx::new(0)
  let cond = LocalIdx::new(1)
  let block = TInstr::block(
    BlockType::void_(),
    TExpr::new([
      TInstr::if_(
        BlockType::void_(),
        TInstr::local_get(cond),
        TExpr::new([
          TInstr::local_set(idx, TInstr::i32_const(I32(10))),
          TInstr::br(LabelIdx::new(1), []),
        ]),
        Some(TExpr::new([TInstr::nop()])),
      ),
      TInstr::local_set(idx, TInstr::i32_const(I32(30))),
    ]),
  )
  let sinkables : Map[Int, SLSinkableInfo] = Map::new()
  let sinkable_indexes = sl_sinkable_indexes_new()
  let effects_cache : Map[TInstr, LCSEffects] = Map::new()
  let out : Array[TInstr] = []
  let changed = Ref::new(false)
  let next = sl_rewrite_instr_main(
    block,
    sl_test_env([ValType::i32(), ValType::i32()]),
    sinkables,
    sinkable_indexes,
    effects_cache,
    out,
    [ValType::i32(), ValType::i32()],
    { local_count: 2, storage: Dense([2, 1]) },
    { allow_tee: false, allow_structure: true, allow_nesting: true },
    false,
    changed,
  )
  assert_true(changed.val)
  match next.kind {
    TInstrKind::TLocalSet(
      _,
      { kind: TInstrKind::TBlock(ValTypeBlockType(_), _), .. }
    ) => ()
    _ =>
      fail(
        "expected instruction rewrite to produce local.set(block(result ...))",
      )
  }
}

///|
test "simplify_locals does not coalesce block returns when branch locals differ" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [ValType::i32(), ValType::i32()],
        TExpr::new([
          TInstr::block(
            BlockType::void_(),
            TExpr::new([
              TInstr::if_(
                BlockType::void_(),
                TInstr::i32_const(I32(1)),
                TExpr::new([
                  TInstr::local_set(x, TInstr::i32_const(I32(7))),
                  TInstr::br(LabelIdx::new(0), []),
                ]),
                Some(
                  TExpr::new([
                    TInstr::local_set(y, TInstr::i32_const(I32(9))),
                    TInstr::br(LabelIdx::new(0), []),
                  ]),
                ),
              ),
              TInstr::local_set(x, TInstr::i32_const(I32(5))),
            ]),
          ),
          TInstr::drop(TInstr::local_get(x)),
          TInstr::drop(TInstr::local_get(x)),
        ]),
      ),
    ]),
  )
  let out = sl_run_simplify_locals(mod, allow_tee=false, allow_structure=true)
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) =>
      assert_false(sl_has_result_block_texpr(body))
    _ => fail("expected one typed function")
  }
}

///|
test "simplify_locals coalesces sinkable set into loop return value" {
  let x = LocalIdx::new(0)
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [ValType::i32()],
        TExpr::new([
          TInstr::local_set(x, TInstr::i32_const(I32(13))),
          TInstr::loop_(BlockType::void_(), TExpr::new([TInstr::nop()])),
          TInstr::drop(TInstr::local_get(x)),
          TInstr::drop(TInstr::local_get(x)),
        ]),
      ),
    ]),
  )
  let out = sl_run_simplify_locals(mod, allow_tee=true, allow_structure=true)
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) =>
      assert_true(sl_has_result_loop_texpr(body))
    _ => fail("expected one typed function")
  }
}

///|
test "simplify_locals does not make loop result when loop has br 0" {
  let x = LocalIdx::new(0)
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [ValType::i32()],
        TExpr::new([
          TInstr::local_set(x, TInstr::i32_const(I32(13))),
          TInstr::loop_(
            BlockType::void_(),
            TExpr::new([TInstr::br(LabelIdx::new(0), [])]),
          ),
          TInstr::drop(TInstr::local_get(x)),
        ]),
      ),
    ]),
  )
  let out = sl_run_simplify_locals(mod, allow_tee=true, allow_structure=true)
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) =>
      assert_false(sl_has_result_loop_texpr(body))
    _ => fail("expected one typed function")
  }
}

///|
test "simplify_locals late canonicalization rewrites equivalent gets to dominant local" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [ValType::i32(), ValType::i32()],
        TExpr::new([
          TInstr::local_set(x, TInstr::i32_const(I32(4))),
          TInstr::local_set(y, TInstr::local_get(x)),
          TInstr::drop(TInstr::local_get(y)),
          TInstr::drop(TInstr::local_get(y)),
          TInstr::drop(TInstr::local_get(x)),
        ]),
      ),
    ]),
  )
  let out = sl_run_simplify_locals(
    mod,
    allow_tee=false,
    allow_structure=false,
    allow_nesting=true,
  )
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) => {
      let x_gets = sl_count_local_gets_for_idx_texpr(body, 0)
      let y_gets = sl_count_local_gets_for_idx_texpr(body, 1)
      assert_true(x_gets >= 2)
      assert_true(y_gets <= 1)
    }
    _ => fail("expected one typed function")
  }
}

///|
test "simplify_locals late equivalent-set removal follows structure option" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let body = TExpr::new([
    TInstr::local_set(x, TInstr::i32_const(I32(17))),
    TInstr::local_set(y, TInstr::local_get(x)),
    TInstr::local_set(y, TInstr::local_get(x)),
    TInstr::drop(TInstr::local_get(y)),
    TInstr::drop(TInstr::local_get(y)),
  ])
  let local_types = [ValType::i32(), ValType::i32()]
  let (with_removal, changed_with) = sl_run_late_optimizations(
    body, local_types, true,
  )
  let (no_removal, changed_without) = sl_run_late_optimizations(
    body, local_types, false,
  )
  assert_true(changed_with)
  ignore(changed_without)
  let with_count = sl_count_local_sets_for_idx_texpr(with_removal, 1)
  let without_count = sl_count_local_sets_for_idx_texpr(no_removal, 1)
  assert_true(with_count < without_count)
}

///|
test "simplify_locals late equivalent-set removal skips nested value-position set" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let z = LocalIdx::new(2)
  let body = TExpr::new([
    TInstr::local_set(x, TInstr::i32_const(I32(17))),
    TInstr::local_set(y, TInstr::local_get(x)),
    TInstr::local_get(x),
    TInstr::drop(
      TInstr::local_tee(z, TInstr::local_set(y, TInstr::local_get(x))),
    ),
  ])
  let local_types = [ValType::i32(), ValType::i32(), ValType::i32()]
  let (rewritten, _) = sl_run_late_optimizations(body, local_types, true)
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([Func::t_func([], local_types, rewritten)]))
  assert_eq(validate_module(mod), Ok(()))
  match rewritten.instrs[3].kind {
    TInstrKind::TDrop(
      {
        kind: TInstrKind::TLocalTee(
          _,
          {
            kind: TInstrKind::TLocalSet(
              _,
              { kind: TInstrKind::TLocalGet(_), .. }
            ),
            ..,
          }
        ),
        ..,
      }
    ) => ()
    other =>
      fail(
        "expected nested value-position local.set to remain intact, got \{other}",
      )
  }
}

///|
test "simplify_locals keeps structured control values out of nested value positions" {
  let x = LocalIdx::new(0)
  let cond = LocalIdx::new(1)
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [ValType::i32(), ValType::i32()],
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::if_(
                  BlockType::void_(),
                  TInstr::local_get(cond),
                  TExpr::new([
                    TInstr::local_set(x, TInstr::i32_const(I32(1))),
                    TInstr::br(LabelIdx::new(1), []),
                  ]),
                  Some(
                    TExpr::new([TInstr::local_set(x, TInstr::i32_const(I32(2)))]),
                  ),
                ),
                TInstr::drop(TInstr::local_get(x)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let out = sl_run_simplify_locals(mod, allow_tee=true, allow_structure=true)
  assert_eq(validate_module(out), Ok(()))
  match out.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            [],
            _,
            { instrs: [{ kind: TInstrKind::TBlock(_, body), .. }], .. }
          ),
        ]
      )
    ) =>
      match body.instrs[body.instrs.length() - 1].kind {
        TInstrKind::TDrop(
          {
            kind: TInstrKind::TLocalTee(
              _,
              { kind: TInstrKind::TIf(ValTypeBlockType(_), _, _, _), .. }
            ),
            ..,
          }
        ) =>
          fail(
            "structured result if must not be sunk into nested value position",
          )
        _ => ()
      }
    _ => fail("expected one typed function with a single top-level block")
  }
}

///|
test "simplify_locals sink helper keeps multi-use local.get when local types differ" {
  let sinkables : Map[Int, SLSinkableInfo] = Map::new()
  let sinkable_indexes = sl_sinkable_indexes_new()
  let out : Array[TInstr] = []
  let changed = Ref::new(false)
  let other = LocalIdx::new(1)
  sinkables[0] = {
    out_index: -1,
    value: TInstr::local_get(other),
    effects: lcs_collect_effects(TInstr::local_get(other)),
  }
  let get_counts = sl_main_get_counts_new(2, false)
  sl_main_get_counts_adjust_idx(get_counts, LocalIdx::new(0), 2)
  sl_main_get_counts_adjust_idx(get_counts, LocalIdx::new(1), 1)
  let rewritten = sl_try_sink_local_get(
    LocalIdx::new(0),
    sl_test_env([
      ValType::ref_type(RefType::new(false, HeapType::abs(AbsHeapType::func()))),
      ValType::funcref(),
    ]),
    sinkables,
    sinkable_indexes,
    out,
    get_counts,
    [
      ValType::ref_type(RefType::new(false, HeapType::abs(AbsHeapType::func()))),
      ValType::funcref(),
    ],
    { allow_tee: false, allow_structure: false, allow_nesting: false },
    false,
    changed,
  )
  assert_eq(rewritten, TInstr::local_get(LocalIdx::new(0)))
  assert_false(changed.val)
}

///|
test "simplify_locals sink helper allows single-use local.get to sink narrowing ref value" {
  let sinkables : Map[Int, SLSinkableInfo] = Map::new()
  let sinkable_indexes = sl_sinkable_indexes_new()
  let out : Array[TInstr] = []
  let changed = Ref::new(false)
  sinkables[0] = {
    out_index: -1,
    value: TInstr::ref_func(FuncIdx::new(0)),
    effects: lcs_collect_effects(TInstr::ref_func(FuncIdx::new(0))),
  }
  let get_counts = sl_main_get_counts_new(1, false)
  sl_main_get_counts_adjust_idx(get_counts, LocalIdx::new(0), 1)
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([Func::t_func([], [], TExpr::new([]))]))
  let rewritten = sl_try_sink_local_get(
    LocalIdx::new(0),
    Env::new().with_module(mod).with_locals([ValType::funcref()]),
    sinkables,
    sinkable_indexes,
    out,
    get_counts,
    [ValType::funcref()],
    { allow_tee: false, allow_structure: false, allow_nesting: true },
    false,
    changed,
  )
  assert_eq(rewritten, TInstr::ref_func(FuncIdx::new(0)))
  assert_true(changed.val)
}

///|
test "simplify_locals sink helper keeps single-use local.get when sink value has no standalone result" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let sinkables : Map[Int, SLSinkableInfo] = Map::new()
  let sinkable_indexes = sl_sinkable_indexes_new()
  let out : Array[TInstr] = []
  let changed = Ref::new(false)
  let sink_value = TInstr::local_set(y, TInstr::i32_const(I32(5)))
  sinkables[0] = {
    out_index: -1,
    value: sink_value,
    effects: lcs_collect_effects(TInstr::local_set(x, sink_value)),
  }
  let get_counts = sl_main_get_counts_new(2, false)
  sl_main_get_counts_adjust_idx(get_counts, x, 1)
  let rewritten = sl_try_sink_local_get(
    x,
    sl_test_env([ValType::i32(), ValType::i32()]),
    sinkables,
    sinkable_indexes,
    out,
    get_counts,
    [ValType::i32(), ValType::i32()],
    { allow_tee: false, allow_structure: false, allow_nesting: true },
    true,
    changed,
  )
  assert_eq(rewritten, TInstr::local_get(x))
  assert_false(changed.val)
}

///|
test "simplify_locals sink helper keeps multi-use local.get when tee sink value has no standalone result" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let sinkables : Map[Int, SLSinkableInfo] = Map::new()
  let sinkable_indexes = sl_sinkable_indexes_new()
  let out : Array[TInstr] = []
  let changed = Ref::new(false)
  let sink_value = TInstr::local_set(y, TInstr::i32_const(I32(5)))
  sinkables[0] = {
    out_index: -1,
    value: sink_value,
    effects: lcs_collect_effects(TInstr::local_set(x, sink_value)),
  }
  let get_counts = sl_main_get_counts_new(2, false)
  sl_main_get_counts_adjust_idx(get_counts, x, 2)
  let rewritten = sl_try_sink_local_get(
    x,
    sl_test_env([ValType::i32(), ValType::i32()]),
    sinkables,
    sinkable_indexes,
    out,
    get_counts,
    [ValType::i32(), ValType::i32()],
    { allow_tee: true, allow_structure: false, allow_nesting: true },
    true,
    changed,
  )
  assert_eq(rewritten, TInstr::local_get(x))
  assert_false(changed.val)
}

///|
test "simplify_locals late canonicalization prefers non-null equivalents over nullable copies" {
  let narrow = LocalIdx::new(0)
  let wide = LocalIdx::new(1)
  let body = TExpr::new([
    TInstr::local_set(wide, TInstr::local_get(narrow)),
    TInstr::drop(TInstr::local_get(wide)),
    TInstr::drop(TInstr::local_get(wide)),
    TInstr::drop(TInstr::local_get(narrow)),
  ])
  let local_types = [
    ValType::ref_type(RefType::new(false, HeapType::abs(AbsHeapType::func()))),
    ValType::funcref(),
  ]
  let (rewritten, changed) = sl_run_late_optimizations(body, local_types, false)
  assert_true(changed)
  assert_true(sl_count_local_gets_for_idx_texpr(rewritten, 0) >= 3)
  assert_true(sl_count_local_gets_for_idx_texpr(rewritten, 1) <= 1)
}

///|
test "simplify_locals no-tee-no-structure preserves exact local type for untyped select" {
  let narrow = LocalIdx::new(0)
  let wide = LocalIdx::new(1)
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [
            ValType::ref_type(
              RefType::new(false, HeapType::abs(AbsHeapType::func())),
            ),
            ValType::funcref(),
          ],
          TExpr::new([
            TInstr::local_set(narrow, TInstr::ref_func(FuncIdx::new(0))),
            TInstr::local_set(wide, TInstr::local_get(narrow)),
            TInstr::drop(
              TInstr::select(
                None,
                TInstr::i32_const(I32(0)),
                TInstr::local_get(wide),
                TInstr::ref_null(HeapType::abs(AbsHeapType::func())),
              ),
            ),
          ]),
        ),
      ]),
    )
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("f"), ExternIdx::func(FuncIdx::new(0))),
      ]),
    )
  let out = sl_run_simplify_locals(
    mod,
    allow_tee=false,
    allow_structure=false,
    allow_nesting=true,
  )
  assert_eq(validate_module(out), Ok(()))
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) =>
      assert_eq(sl_count_local_gets_for_idx_texpr(body, 1), 1)
    _ => fail("expected one typed function")
  }
}

///|
test "simplify_locals skips result-if rewrite when branch exits would invalidate result typing" {
  let x = LocalIdx::new(0)
  let cond = LocalIdx::new(1)
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [ValType::i32(), ValType::i32()],
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(cond),
              TExpr::new([
                TInstr::br(LabelIdx::new(0), []),
                TInstr::local_set(x, TInstr::i32_const(I32(1))),
              ]),
              Some(
                TExpr::new([TInstr::local_set(x, TInstr::i32_const(I32(2)))]),
              ),
            ),
            TInstr::drop(TInstr::local_get(x)),
          ]),
        ),
      ]),
    )
  let out = sl_run_simplify_locals(mod, allow_tee=false, allow_structure=true)
  assert_eq(validate_module(out), Ok(()))
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) =>
      assert_false(sl_has_result_if_texpr(body))
    _ => fail("expected one typed function")
  }
}

///|
test "simplify_locals local checker rejects result-if candidate with void branch break" {
  let x = LocalIdx::new(0)
  let cond = LocalIdx::new(1)
  let candidate = TInstr::local_set(
    x,
    TInstr::if_(
      BlockType::val_type(ValType::i32()),
      TInstr::local_get(cond),
      TExpr::new([TInstr::br(LabelIdx::new(0), []), TInstr::i32_const(I32(1))]),
      Some(TExpr::new([TInstr::i32_const(I32(2))])),
    ),
  )
  assert_false(
    sl_can_emit_rewritten_instr(
      candidate,
      sl_test_env([ValType::i32(), ValType::i32()]),
    ),
  )
}

///|
test "simplify_locals typed local-set guard rejects env/local mismatch for result if" {
  let x = LocalIdx::new(0)
  let cond = LocalIdx::new(1)
  let result_value = TInstr::if_(
    BlockType::val_type(ValType::i64()),
    TInstr::local_get(cond),
    TExpr::new([TInstr::i64_const(I64(1))]),
    Some(TExpr::new([TInstr::i64_const(I64(2))])),
  )
  assert_false(
    sl_can_emit_typed_local_set(
      x,
      ValType::i64(),
      result_value,
      sl_test_env([ValType::i32(), ValType::i32()]),
    ),
  )
}

///|
test "simplify_locals local checker rejects result-block candidate with void branch break" {
  let x = LocalIdx::new(0)
  let candidate = TInstr::local_set(
    x,
    TInstr::block(
      BlockType::val_type(ValType::i32()),
      TExpr::new([TInstr::br(LabelIdx::new(0), []), TInstr::i32_const(I32(1))]),
    ),
  )
  assert_false(
    sl_can_emit_rewritten_instr(candidate, sl_test_env([ValType::i32()])),
  )
}

///|
test "simplify_locals local checker rejects local.tee candidate whose value has no standalone result" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let candidate = TInstr::local_tee(
    x,
    TInstr::local_set(y, TInstr::i32_const(I32(7))),
  )
  assert_false(
    sl_can_emit_rewritten_instr(
      candidate,
      sl_test_env([ValType::i32(), ValType::i32()]),
    ),
  )
}

///|
test "simplify_locals typed function validator rejects local.set result type mismatch" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  let env = Env::new().with_module(mod)
  let candidate = Func::t_func(
    [],
    [ValType::i64()],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::if_(
          BlockType::val_type(ValType::i32()),
          TInstr::i32_const(I32(1)),
          TExpr::new([TInstr::i32_const(I32(2))]),
          Some(TExpr::new([TInstr::i32_const(I32(3))])),
        ),
      ),
    ]),
  )
  match sl_validate_typed_function_candidate(env, FuncIdx::new(0), candidate) {
    Ok(_) => fail("expected validator to reject mismatched local.set candidate")
    Err(_) => ()
  }
}

///|
test "simplify_locals typed function validator rejects duplicated param-prefix locals" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([ValType::i32()], []))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  let env = Env::new().with_module(mod)
  let candidate = Func::t_func(
    [ValType::i32()],
    [ValType::i32(), ValType::i64()],
    TExpr::new([TInstr::local_set(LocalIdx::new(1), TInstr::i64_const(I64(7)))]),
  )
  match sl_validate_typed_function_candidate(env, FuncIdx::new(0), candidate) {
    Ok(_) =>
      fail("expected duplicated param-prefix locals to fail typed validation")
    Err(_) => ()
  }
}

///|
test "simplify_locals typed function validator accepts normalized param/local layout" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([ValType::i32()], []))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  let env = Env::new().with_module(mod)
  let candidate = Func::t_func(
    [ValType::i32()],
    [ValType::i64()],
    TExpr::new([TInstr::local_set(LocalIdx::new(1), TInstr::i64_const(I64(7)))]),
  )
  match sl_validate_typed_function_candidate(env, FuncIdx::new(0), candidate) {
    Ok(_) => ()
    Err(e) => fail("expected normalized typed locals to validate, got: " + e)
  }
}

///|
test "simplify_locals rewrite finalizer keeps original invalid candidate out" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  let env = Env::new().with_module(mod)
  let original = Func::t_func([], [ValType::i64()], TExpr::new([]))
  let invalid_candidate = Func::t_func(
    [],
    [ValType::i64()],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::if_(
          BlockType::val_type(ValType::i32()),
          TInstr::i32_const(I32(1)),
          TExpr::new([TInstr::i32_const(I32(2))]),
          Some(TExpr::new([TInstr::i32_const(I32(3))])),
        ),
      ),
    ]),
  )
  let (kept, changed) = sl_keep_validated_rewrite(
    env,
    FuncIdx::new(0),
    original,
    invalid_candidate,
    fn(_) { () },
  )
  assert_false(changed)
  assert_eq(kept, original)
}

///|
test "simplify_locals rewrite finalizer salvages repairable duplicated param-prefix locals" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([ValType::i32()], []))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  let env = Env::new().with_module(mod)
  let original = Func::t_func(
    [ValType::i32()],
    [ValType::i64()],
    TExpr::new([TInstr::local_set(LocalIdx::new(1), TInstr::i64_const(I64(7)))]),
  )
  let repairable_candidate = Func::t_func(
    [ValType::i32()],
    [ValType::i32(), ValType::i64()],
    TExpr::new([TInstr::local_set(LocalIdx::new(1), TInstr::i64_const(I64(7)))]),
  )
  let (kept, changed) = sl_keep_validated_rewrite(
    env,
    FuncIdx::new(0),
    original,
    repairable_candidate,
    fn(_) { () },
  )
  assert_true(changed)
  match kept {
    TFunc(params, locals, _) => {
      assert_eq(params, [ValType::i32()])
      assert_eq(locals, [ValType::i64()])
    }
    _ => fail("expected typed function after salvage")
  }
}

///|
test "simplify_locals rewrite finalizer keeps original when duplicated param-prefix candidate is irreparable" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([ValType::i32()], []))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  let env = Env::new().with_module(mod)
  let original = Func::t_func([ValType::i32()], [], TExpr::new([]))
  let irreparable_candidate = Func::t_func(
    [ValType::i32()],
    [ValType::i32()],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::if_(
          BlockType::val_type(ValType::i64()),
          TInstr::i32_const(I32(1)),
          TExpr::new([TInstr::i64_const(I64(2))]),
          Some(TExpr::new([TInstr::i64_const(I64(3))])),
        ),
      ),
    ]),
  )
  let (kept, changed) = sl_keep_validated_rewrite(
    env,
    FuncIdx::new(0),
    original,
    irreparable_candidate,
    fn(_) { () },
  )
  assert_false(changed)
  assert_eq(kept, original)
}

///|
test "simplify_locals validation counters record accepted rewrite candidates" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  let env = Env::new().with_module(mod)
  let original = Func::t_func([], [ValType::i32()], TExpr::new([]))
  let candidate = Func::t_func(
    [],
    [ValType::i32()],
    TExpr::new([TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(7)))]),
  )
  sl_rewrite_validation_reset()
  let (_, changed) = sl_keep_validated_rewrite(
    env,
    FuncIdx::new(0),
    original,
    candidate,
    fn(_) { () },
  )
  let stats = sl_rewrite_validation_snapshot()
  assert_true(changed)
  assert_eq(stats.raw_candidates_attempted, 1)
  assert_eq(stats.candidates_accepted, 1)
  assert_eq(stats.candidates_rejected_local_validation, 0)
}

///|
test "simplify_locals validation counters record rejected rewrite candidates with reason bucket" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  let env = Env::new().with_module(mod)
  let original = Func::t_func([], [ValType::i64()], TExpr::new([]))
  let invalid_candidate = Func::t_func(
    [],
    [ValType::i64()],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::if_(
          BlockType::val_type(ValType::i32()),
          TInstr::i32_const(I32(1)),
          TExpr::new([TInstr::i32_const(I32(2))]),
          Some(TExpr::new([TInstr::i32_const(I32(3))])),
        ),
      ),
    ]),
  )
  let expected_bucket = match
    sl_validate_typed_function_candidate(
      env,
      FuncIdx::new(0),
      invalid_candidate,
    ) {
    Ok(_) => fail("expected invalid candidate to fail local validation")
    Err(err) => sl_rewrite_validation_bucket_for_error(err)
  }
  sl_rewrite_validation_reset()
  let (_, changed) = sl_keep_validated_rewrite(
    env,
    FuncIdx::new(0),
    original,
    invalid_candidate,
    fn(_) { () },
  )
  let stats = sl_rewrite_validation_snapshot()
  assert_false(changed)
  assert_eq(stats.raw_candidates_attempted, 1)
  assert_eq(stats.candidates_accepted, 0)
  assert_eq(stats.candidates_rejected_local_validation, 1)
  assert_true(stats.rejection_reason_buckets.get(expected_bucket) != None)
}

///|
test "simplify_locals keeps nested branchy result-if pattern valid" {
  let x = LocalIdx::new(0)
  let cond0 = LocalIdx::new(1)
  let cond1 = LocalIdx::new(2)
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [ValType::i32(), ValType::i32(), ValType::i32()],
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::if_(
                  BlockType::void_(),
                  TInstr::local_get(cond0),
                  TExpr::new([
                    TInstr::if_(
                      BlockType::void_(),
                      TInstr::local_get(cond1),
                      TExpr::new([
                        TInstr::local_set(x, TInstr::i32_const(I32(1))),
                      ]),
                      Some(
                        TExpr::new([
                          TInstr::br(LabelIdx::new(1), []),
                          TInstr::local_set(x, TInstr::i32_const(I32(9))),
                        ]),
                      ),
                    ),
                    TInstr::local_set(x, TInstr::local_get(x)),
                  ]),
                  Some(
                    TExpr::new([TInstr::local_set(x, TInstr::i32_const(I32(2)))]),
                  ),
                ),
                TInstr::drop(TInstr::local_get(x)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let out = sl_run_simplify_locals(mod, allow_tee=true, allow_structure=true)
  assert_eq(validate_module(out), Ok(()))
}

///|
test "simplify_locals ID-C1 keeps prior local.set when intermediate local.get reads it" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [ValType::i32(), ValType::i32()],
        TExpr::new([
          TInstr::local_set(x, TInstr::i32_const(I32(7))),
          TInstr::local_set(y, TInstr::local_get(x)),
          TInstr::local_set(x, TInstr::i32_const(I32(9))),
          TInstr::drop(TInstr::local_get(x)),
          TInstr::drop(TInstr::local_get(y)),
        ]),
      ),
    ]),
  )
  let out = sl_run_simplify_locals(
    mod,
    allow_tee=false,
    allow_structure=false,
    allow_nesting=false,
  )
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) => {
      let sets_x = sl_count_local_sets_for_idx_texpr(body, 0)
      assert_eq(sets_x, 2)
    }
    _ => fail("expected one typed function")
  }
}

///|
test "simplify_locals ID-C1 sinkable effects include destination local write" {
  let idx = LocalIdx::new(0)
  let effects = sl_collect_sinkable_effects(idx, TInstr::i32_const(I32(7)))
  assert_true(effects.locals_written.contains(idx))
}

///|
test "simplify_locals ID-C2 updates get counts after one-sided if introduces new local.get" {
  let x = LocalIdx::new(0)
  let body = TExpr::new([
    TInstr::if_(
      BlockType::void_(),
      TInstr::i32_const(I32(1)),
      TExpr::new([TInstr::local_set(x, TInstr::i32_const(I32(2)))]),
      None,
    ),
    TInstr::drop(TInstr::local_get(x)),
  ])
  let counts = sl_main_get_counts_new(1, false)
  sl_main_collect_get_counts_texpr(body, counts)
  let (next_body, changed) = sl_simplify_texpr_main(
    body,
    sl_test_env([ValType::i32()]),
    [ValType::i32()],
    counts,
    { allow_tee: false, allow_structure: true, allow_nesting: false },
    Map::new(),
  )
  assert_true(changed)
  let actual = Array::make(1, 0)
  sl_collect_get_counts_texpr(next_body, actual)
  assert_eq(sl_main_get_counts_get(counts, 0), actual[0])
  assert_eq(actual[0], 2)
}

///|
test "simplify_locals ID-P1 structures if-else when one arm is unreachable" {
  let x = LocalIdx::new(0)
  let instr = TInstr::if_(
    BlockType::void_(),
    TInstr::i32_const(I32(0)),
    TExpr::new([TInstr::unreachable_()]),
    Some(TExpr::new([TInstr::local_set(x, TInstr::i32_const(I32(9)))])),
  )
  let changed = Ref::new(false)
  let out = sl_try_structure_if(
    instr,
    sl_test_env([ValType::i32()]),
    [ValType::i32()],
    sl_main_get_counts_new(1, false),
    { allow_tee: false, allow_structure: true, allow_nesting: true },
    false,
    changed,
  )
  assert_true(changed.val)
  match out.kind {
    TInstrKind::TLocalSet(
      _,
      { kind: TInstrKind::TIf(ValTypeBlockType(_), _, _, _), .. }
    ) => ()
    _ => fail("expected local.set(if(result ...)) from unreachable-arm rewrite")
  }
}

///|
test "simplify_locals ID-P2 uses fixpoint cycles to unlock second sinking opportunity" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let z = LocalIdx::new(2)
  let func = Func::t_func(
    [],
    [ValType::i32(), ValType::i32(), ValType::i32()],
    TExpr::new([
      TInstr::local_set(x, TInstr::local_get(z)),
      TInstr::local_set(y, TInstr::local_tee(z, TInstr::i32_const(I32(5)))),
      TInstr::drop(TInstr::local_get(x)),
      TInstr::drop(TInstr::local_get(y)),
    ]),
  )
  let (next_func, changed) = sl_simplify_function(
    func,
    sl_test_env([ValType::i32(), ValType::i32(), ValType::i32()]),
    [],
    { allow_tee: false, allow_structure: false, allow_nesting: true },
  )
  assert_true(changed)
  match next_func {
    TFunc(_, _, body) =>
      assert_eq(sl_count_local_sets_for_idx_texpr(body, 0), 0)
    _ => fail("expected typed function")
  }
}

///|
test "simplify_locals ID-P3 structures loop into loop result local.set" {
  let x = LocalIdx::new(0)
  let out : Array[TInstr] = [TInstr::local_set(x, TInstr::i32_const(I32(13)))]
  let sinkables : Map[Int, SLSinkableInfo] = Map::new()
  let sinkable_indexes = sl_sinkable_indexes_new()
  let info : SLSinkableInfo = {
    out_index: 0,
    value: TInstr::i32_const(I32(13)),
    effects: lcs_collect_effects(TInstr::i32_const(I32(13))),
  }
  sl_sinkables_add(sinkables, sinkable_indexes, 0, info)
  let changed = Ref::new(false)
  let rewritten = sl_try_structure_loop_sink(
    TInstr::loop_(BlockType::void_(), TExpr::new([TInstr::nop()])),
    sl_test_env([ValType::i32()]),
    sinkables,
    sinkable_indexes,
    out,
    [ValType::i32()],
    { allow_tee: true, allow_structure: true, allow_nesting: true },
    changed,
  )
  assert_true(changed.val)
  assert_eq(out[0], TInstr::nop())
  match rewritten.kind {
    TInstrKind::TLocalSet(
      _,
      { kind: TInstrKind::TLoop(ValTypeBlockType(_), _), .. }
    ) => ()
    _ => fail("expected local.set(loop(result ...)) after loop structuring")
  }
}

///|
test "simplify_locals ID-P4 allows single-use sink from subtype value into supertype local.get" {
  let x = LocalIdx::new(0)
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [ValType::funcref()],
          TExpr::new([
            TInstr::local_set(x, TInstr::ref_func(FuncIdx::new(0))),
            TInstr::drop(TInstr::local_get(x)),
          ]),
        ),
      ]),
    )
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("f"), ExternIdx::func(FuncIdx::new(0))),
      ]),
    )
  let out = sl_run_simplify_locals(
    mod,
    allow_tee=false,
    allow_structure=false,
    allow_nesting=true,
  )
  assert_eq(validate_module(out), Ok(()))
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) => {
      let stats = SLLocalStats::new()
      sl_collect_local_stats_texpr(body, stats)
      assert_eq(stats.sets, 0)
      assert_eq(stats.gets, 0)
    }
    _ => fail("expected one typed function")
  }
}

///|
test "simplify_locals ID-P5 late canonicalization picks subtype-equivalent local" {
  let narrow = LocalIdx::new(0)
  let wide = LocalIdx::new(1)
  let body = TExpr::new([
    TInstr::local_set(wide, TInstr::local_get(narrow)),
    TInstr::drop(TInstr::local_get(wide)),
    TInstr::drop(TInstr::local_get(wide)),
    TInstr::drop(TInstr::local_get(narrow)),
  ])
  let local_types = [
    ValType::ref_type(RefType::new(false, HeapType::abs(AbsHeapType::func()))),
    ValType::funcref(),
  ]
  let (rewritten, changed) = sl_run_late_optimizations(body, local_types, false)
  assert_true(changed)
  let narrow_gets = sl_count_local_gets_for_idx_texpr(rewritten, 0)
  let wide_gets = sl_count_local_gets_for_idx_texpr(rewritten, 1)
  assert_true(narrow_gets >= 3)
  assert_true(wide_gets <= 1)
}

///|
test "simplify_locals ID-P5 late canonicalization runs for large local arrays" {
  let local_types : Array[ValType] = []
  for _ in 0..<129 {
    local_types.push(ValType::i32())
  }
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let body = TExpr::new([
    TInstr::local_set(x, TInstr::i32_const(I32(1))),
    TInstr::local_set(y, TInstr::local_get(x)),
    TInstr::drop(TInstr::local_get(y)),
    TInstr::drop(TInstr::local_get(y)),
    TInstr::drop(TInstr::local_get(x)),
    TInstr::drop(TInstr::local_get(x)),
  ])
  let (_, changed) = sl_run_late_optimizations(body, local_types, false)
  assert_true(changed)
}

///|
test "simplify_locals ID-F1 avoids excessive effect recomputation in main phase" {
  let locals : Array[ValType] = []
  let body_instrs : Array[TInstr] = []
  for i in 0..<40 {
    locals.push(ValType::i32())
    let idx = LocalIdx::new(i.reinterpret_as_uint())
    body_instrs.push(TInstr::local_set(idx, TInstr::i32_const(I32(i))))
  }
  for i in 0..<40 {
    let idx = LocalIdx::new(i.reinterpret_as_uint())
    body_instrs.push(TInstr::drop(TInstr::local_get(idx)))
  }
  sl_perf_reset()
  ignore(
    sl_simplify_function(
      Func::t_func([], locals, TExpr::new(body_instrs)),
      sl_test_env(locals),
      [],
      { allow_tee: false, allow_structure: false, allow_nesting: true },
    ),
  )
  let perf = sl_perf_snapshot()
  if perf.effect_collect_calls > 300 {
    fail("expected <=300 effect collections, got \{perf.effect_collect_calls}")
  }
}

///|
test "simplify_locals skips no-structure main rewrite when function has no local.get" {
  let locals : Array[ValType] = []
  let body_instrs : Array[TInstr] = []
  for i in 0..<200 {
    locals.push(ValType::i32())
    let idx = LocalIdx::new(i.reinterpret_as_uint())
    body_instrs.push(TInstr::local_set(idx, TInstr::i32_const(I32(i))))
  }
  sl_perf_reset()
  ignore(
    sl_simplify_function(
      Func::t_func([], locals, TExpr::new(body_instrs)),
      sl_test_env(locals),
      [],
      { allow_tee: false, allow_structure: false, allow_nesting: true },
    ),
  )
  let perf = sl_perf_snapshot()
  if perf.effect_collect_calls > 0 {
    fail(
      "expected no effect collection when no-structure main rewrite is skipped; got \{perf.effect_collect_calls}",
    )
  }
}

///|
test "simplify_locals ID-F2 avoids O(active_sinkables) invalidation scans per instruction" {
  let locals : Array[ValType] = []
  let body_instrs : Array[TInstr] = []
  for i in 0..<50 {
    locals.push(ValType::i32())
    let idx = LocalIdx::new(i.reinterpret_as_uint())
    body_instrs.push(TInstr::local_set(idx, TInstr::i32_const(I32(i))))
  }
  for i in 0..<50 {
    let idx = LocalIdx::new(i.reinterpret_as_uint())
    body_instrs.push(TInstr::drop(TInstr::local_get(idx)))
  }
  sl_perf_reset()
  ignore(
    sl_simplify_function(
      Func::t_func([], locals, TExpr::new(body_instrs)),
      sl_test_env(locals),
      [],
      { allow_tee: false, allow_structure: false, allow_nesting: true },
    ),
  )
  let perf = sl_perf_snapshot()
  if perf.invalidation_entry_checks > 700 {
    fail(
      "expected <=700 invalidation entry checks, got \{perf.invalidation_entry_checks}",
    )
  }
}

///|
test "simplify_locals ID-F3 reuses get counts across fixpoint cycles" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let z = LocalIdx::new(2)
  let func = Func::t_func(
    [],
    [ValType::i32(), ValType::i32(), ValType::i32()],
    TExpr::new([
      TInstr::local_set(x, TInstr::local_get(z)),
      TInstr::local_set(y, TInstr::local_tee(z, TInstr::i32_const(I32(5)))),
      TInstr::drop(TInstr::local_get(x)),
      TInstr::drop(TInstr::local_get(y)),
    ]),
  )
  sl_perf_reset()
  ignore(
    sl_simplify_function(
      func,
      sl_test_env([ValType::i32(), ValType::i32(), ValType::i32()]),
      [],
      { allow_tee: false, allow_structure: false, allow_nesting: true },
    ),
  )
  let perf = sl_perf_snapshot()
  if perf.get_count_scans > 4 {
    fail("expected <=4 full get-count scans, got \{perf.get_count_scans}")
  }
}

///|
test "simplify_locals ID-F4 avoids cloning late-phase state for every nested branch" {
  let body = TExpr::new([
    TInstr::if_(
      BlockType::void_(),
      TInstr::i32_const(I32(1)),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::i32_const(I32(0)),
              TExpr::new([
                TInstr::local_set(
                  LocalIdx::new(1),
                  TInstr::local_get(LocalIdx::new(0)),
                ),
              ]),
              Some(
                TExpr::new([
                  TInstr::local_set(
                    LocalIdx::new(1),
                    TInstr::local_get(LocalIdx::new(0)),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ]),
      Some(
        TExpr::new([
          TInstr::block(
            BlockType::void_(),
            TExpr::new([
              TInstr::if_(
                BlockType::void_(),
                TInstr::i32_const(I32(1)),
                TExpr::new([
                  TInstr::local_set(
                    LocalIdx::new(1),
                    TInstr::local_get(LocalIdx::new(0)),
                  ),
                ]),
                Some(
                  TExpr::new([
                    TInstr::local_set(
                      LocalIdx::new(1),
                      TInstr::local_get(LocalIdx::new(0)),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    ),
    TInstr::drop(TInstr::local_get(LocalIdx::new(1))),
  ])
  sl_perf_reset()
  ignore(
    sl_run_late_optimizations(body, [ValType::i32(), ValType::i32()], false),
  )
  let perf = sl_perf_snapshot()
  if perf.late_state_clones > 3 {
    fail("expected <=3 late-state clones, got \{perf.late_state_clones}")
  }
}

///|
test "simplify_locals short-circuits pathological deep-control rewrite in no-tee mode" {
  let mut nested_value = TInstr::local_get(LocalIdx::new(0))
  for _ in 0..<120 {
    nested_value = TInstr::block(
      BlockType::val_type(ValType::i32()),
      TExpr::new([nested_value]),
    )
  }
  let (_, changed, _, _) = sl_run_main_phase(
    TExpr::new([
      TInstr::local_set(LocalIdx::new(1), nested_value),
      TInstr::drop(TInstr::local_get(LocalIdx::new(1))),
    ]),
    sl_test_env([ValType::i32(), ValType::i32()]),
    [ValType::i32(), ValType::i32()],
    { allow_tee: false, allow_structure: false, allow_nesting: true },
    false,
  )
  assert_false(changed)
}

///|
test "simplify_locals detects pathological deep-control with wide locals" {
  let mut nested_value = TInstr::local_get(LocalIdx::new(0))
  for _ in 0..<220 {
    nested_value = TInstr::block(
      BlockType::val_type(ValType::i32()),
      TExpr::new([nested_value]),
    )
  }
  let body = TExpr::new([
    TInstr::local_set(LocalIdx::new(1), nested_value),
    TInstr::drop(TInstr::local_get(LocalIdx::new(1))),
    TInstr::drop(TInstr::i32_const(I32(0))),
    TInstr::drop(TInstr::i32_const(I32(1))),
    TInstr::nop(),
    TInstr::nop(),
  ])
  let (is_pathological, max_depth, control_nodes) = sl_main_is_pathological_deep_control_candidate(
    body,
    245,
    { allow_tee: false, allow_structure: false, allow_nesting: true },
  )
  assert_true(is_pathological)
  assert_true(max_depth >= 192)
  assert_true(control_nodes >= 192)
}

///|
test "simplify_locals rewrite progress thresholds advance one step in verbose mode" {
  assert_eq(sl_main_rewrite_helper_trace_next_threshold(0), 1)
  assert_eq(sl_main_rewrite_helper_trace_next_threshold(1), 2)
  assert_eq(sl_main_rewrite_helper_trace_next_threshold(128), 129)
}

///|
test "simplify_locals rewrite finalizer skips duplicated-prefix salvage when proof is absent" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(
          SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  let env = Env::new().with_module(mod)
  let original = Func::t_func(
    [ValType::i32()],
    [ValType::i32(), ValType::i64()],
    TExpr::new([TInstr::local_get(LocalIdx::new(0))]),
  )
  let invalid_candidate = Func::t_func(
    [ValType::i32()],
    [ValType::i32(), ValType::i64()],
    TExpr::new([]),
  )
  let (kept, changed) = sl_keep_validated_rewrite(
    env,
    FuncIdx::new(0),
    original,
    invalid_candidate,
    fn(_) { () },
  )
  assert_false(changed)
  assert_eq(kept, original)
}
