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
priv struct VQFuncSig {
  params : Array[ValType]
  results : Array[ValType]
}

///|
fn VQFuncSig::new(
  params : Array[ValType],
  results : Array[ValType],
) -> VQFuncSig {
  { params, results }
}

///|
priv struct VQPassOptions {
  traps_never_happen : Bool
}

///|
fn VQPassOptions::new(traps_never_happen? : Bool = false) -> VQPassOptions {
  { traps_never_happen, }
}

///|
fn vacuum_trace_now_ms() -> UInt64 {
  pass_trace_now_ms()
}

///|
fn vacuum_trace_elapsed_ms(start_ms : UInt64) -> UInt64 {
  pass_trace_elapsed_ms(start_ms)
}

///|
fn vacuum_trace_now_us() -> UInt64 {
  pass_trace_now_us()
}

///|
fn vacuum_trace_elapsed_us_since(start_us : UInt64) -> UInt64 {
  pass_trace_elapsed_us_since(start_us)
}

///|
fn vacuum_trace_delta_us_to_ms(delta_us : UInt64) -> UInt64 {
  pass_trace_delta_us_to_ms(delta_us)
}

///|
priv struct VQHotspotEntry {
  ordinal : Int
  elapsed_ms : UInt64
  total_instrs : Int
  max_depth : Int
  score : Int
}

///|
priv struct VQRunStats {
  type_cache_hits : Ref[Int]
  type_cache_misses : Ref[Int]
  effect_cache_hits : Ref[Int]
  effect_cache_misses : Ref[Int]
  shallow_effect_cache_hits : Ref[Int]
  shallow_effect_cache_misses : Ref[Int]
  stack_sig_calls : Ref[Int]
  stack_sig_cache_hits : Ref[Int]
  stack_sig_cache_misses : Ref[Int]
  control_transfer_scans : Ref[Int]
  control_transfer_cache_hits : Ref[Int]
  control_transfer_cache_misses : Ref[Int]
  fast_skips : Ref[Int]
  degraded_funcs : Ref[Int]
  shape_degraded_funcs : Ref[Int]
  seed_budget_exhaustions : Ref[Int]
  tier_fallback_calls : Ref[Int]
  tier_fallback_changes : Ref[Int]
  shape_scan_ms : Ref[UInt64]
  shape_scan_calls : Ref[Int]
  seed_ms : Ref[UInt64]
  seed_calls : Ref[Int]
  optimize_ms : Ref[UInt64]
  optimize_calls : Ref[Int]
  final_check_ms : Ref[UInt64]
  final_check_calls : Ref[Int]
  seed_texpr_us : Ref[UInt64]
  seed_texpr_calls : Ref[Int]
  seed_instr_us : Ref[UInt64]
  seed_instr_calls : Ref[Int]
  simplify_block_us : Ref[UInt64]
  simplify_block_calls : Ref[Int]
  rebase_labels_us : Ref[UInt64]
  rebase_labels_calls : Ref[Int]
  value_break_lub_us : Ref[UInt64]
  value_break_lub_calls : Ref[Int]
  rewrite_type_stack_us : Ref[UInt64]
  rewrite_type_stack_calls : Ref[Int]
  rewrite_stack_us : Ref[UInt64]
  rewrite_stack_calls : Ref[Int]
  collect_effects_us : Ref[UInt64]
  collect_effects_calls : Ref[Int]
  infer_type_us : Ref[UInt64]
  infer_type_calls : Ref[Int]
  break_scan_us : Ref[UInt64]
  break_scan_calls : Ref[Int]
  rebase_score_us : Ref[UInt64]
  rebase_score_calls : Ref[Int]
  instr_cache_entries : Ref[Int]
  expr_cache_entries : Ref[Int]
  hotspots : Ref[Array[VQHotspotEntry]]
  changed_funcs : Ref[Int]
}

///|
fn VQRunStats::new() -> VQRunStats {
  {
    type_cache_hits: Ref::new(0),
    type_cache_misses: Ref::new(0),
    effect_cache_hits: Ref::new(0),
    effect_cache_misses: Ref::new(0),
    shallow_effect_cache_hits: Ref::new(0),
    shallow_effect_cache_misses: Ref::new(0),
    stack_sig_calls: Ref::new(0),
    stack_sig_cache_hits: Ref::new(0),
    stack_sig_cache_misses: Ref::new(0),
    control_transfer_scans: Ref::new(0),
    control_transfer_cache_hits: Ref::new(0),
    control_transfer_cache_misses: Ref::new(0),
    fast_skips: Ref::new(0),
    degraded_funcs: Ref::new(0),
    shape_degraded_funcs: Ref::new(0),
    seed_budget_exhaustions: Ref::new(0),
    tier_fallback_calls: Ref::new(0),
    tier_fallback_changes: Ref::new(0),
    shape_scan_ms: Ref::new(0UL),
    shape_scan_calls: Ref::new(0),
    seed_ms: Ref::new(0UL),
    seed_calls: Ref::new(0),
    optimize_ms: Ref::new(0UL),
    optimize_calls: Ref::new(0),
    final_check_ms: Ref::new(0UL),
    final_check_calls: Ref::new(0),
    seed_texpr_us: Ref::new(0UL),
    seed_texpr_calls: Ref::new(0),
    seed_instr_us: Ref::new(0UL),
    seed_instr_calls: Ref::new(0),
    simplify_block_us: Ref::new(0UL),
    simplify_block_calls: Ref::new(0),
    rebase_labels_us: Ref::new(0UL),
    rebase_labels_calls: Ref::new(0),
    value_break_lub_us: Ref::new(0UL),
    value_break_lub_calls: Ref::new(0),
    rewrite_type_stack_us: Ref::new(0UL),
    rewrite_type_stack_calls: Ref::new(0),
    rewrite_stack_us: Ref::new(0UL),
    rewrite_stack_calls: Ref::new(0),
    collect_effects_us: Ref::new(0UL),
    collect_effects_calls: Ref::new(0),
    infer_type_us: Ref::new(0UL),
    infer_type_calls: Ref::new(0),
    break_scan_us: Ref::new(0UL),
    break_scan_calls: Ref::new(0),
    rebase_score_us: Ref::new(0UL),
    rebase_score_calls: Ref::new(0),
    instr_cache_entries: Ref::new(0),
    expr_cache_entries: Ref::new(0),
    hotspots: Ref::new([]),
    changed_funcs: Ref::new(0),
  }
}

///|
let vq_active_stats : Ref[VQRunStats?] = Ref::new(None)

///|
fn vq_run_stats_render(stats : VQRunStats, total_funcs : Int) -> String {
  "metrics funcs=\{total_funcs} changed_funcs=\{stats.changed_funcs.val} " +
  "fast_skips=\{stats.fast_skips.val} " +
  "degraded_funcs=\{stats.degraded_funcs.val} " +
  "shape_degraded_funcs=\{stats.shape_degraded_funcs.val} " +
  "seed_budget_exhaustions=\{stats.seed_budget_exhaustions.val} " +
  "tier_fallback_calls=\{stats.tier_fallback_calls.val} " +
  "tier_fallback_changes=\{stats.tier_fallback_changes.val} " +
  "type_cache_hits=\{stats.type_cache_hits.val} " +
  "type_cache_misses=\{stats.type_cache_misses.val} " +
  "effect_cache_hits=\{stats.effect_cache_hits.val} " +
  "effect_cache_misses=\{stats.effect_cache_misses.val} " +
  "shallow_effect_cache_hits=\{stats.shallow_effect_cache_hits.val} " +
  "shallow_effect_cache_misses=\{stats.shallow_effect_cache_misses.val} " +
  "stack_sig_calls=\{stats.stack_sig_calls.val} " +
  "stack_sig_cache_hits=\{stats.stack_sig_cache_hits.val} " +
  "stack_sig_cache_misses=\{stats.stack_sig_cache_misses.val} " +
  "control_transfer_scans=\{stats.control_transfer_scans.val} " +
  "control_transfer_cache_hits=\{stats.control_transfer_cache_hits.val} " +
  "control_transfer_cache_misses=\{stats.control_transfer_cache_misses.val} " +
  "instr_cache_entries=\{stats.instr_cache_entries.val} " +
  "expr_cache_entries=\{stats.expr_cache_entries.val}"
}

///|
fn vq_phase_totals_line(stats : VQRunStats) -> String {
  "phase_totals shape_scan_ms=\{stats.shape_scan_ms.val} shape_scan_calls=\{stats.shape_scan_calls.val} " +
  "seed_ms=\{stats.seed_ms.val} seed_calls=\{stats.seed_calls.val} " +
  "optimize_ms=\{stats.optimize_ms.val} optimize_calls=\{stats.optimize_calls.val} " +
  "final_check_ms=\{stats.final_check_ms.val} final_check_calls=\{stats.final_check_calls.val}"
}

///|
fn vq_helper_totals_line(stats : VQRunStats) -> String {
  "helper_totals seed_texpr_ms=\{vacuum_trace_delta_us_to_ms(stats.seed_texpr_us.val)} seed_texpr_calls=\{stats.seed_texpr_calls.val} " +
  "seed_instr_ms=\{vacuum_trace_delta_us_to_ms(stats.seed_instr_us.val)} seed_instr_calls=\{stats.seed_instr_calls.val} " +
  "simplify_block_ms=\{vacuum_trace_delta_us_to_ms(stats.simplify_block_us.val)} simplify_block_calls=\{stats.simplify_block_calls.val} " +
  "rebase_labels_ms=\{vacuum_trace_delta_us_to_ms(stats.rebase_labels_us.val)} rebase_labels_calls=\{stats.rebase_labels_calls.val} " +
  "value_break_lub_ms=\{vacuum_trace_delta_us_to_ms(stats.value_break_lub_us.val)} value_break_lub_calls=\{stats.value_break_lub_calls.val} " +
  "rewrite_type_stack_ms=\{vacuum_trace_delta_us_to_ms(stats.rewrite_type_stack_us.val)} rewrite_type_stack_calls=\{stats.rewrite_type_stack_calls.val} " +
  "rewrite_stack_ms=\{vacuum_trace_delta_us_to_ms(stats.rewrite_stack_us.val)} rewrite_stack_calls=\{stats.rewrite_stack_calls.val} " +
  "collect_effects_ms=\{vacuum_trace_delta_us_to_ms(stats.collect_effects_us.val)} collect_effects_calls=\{stats.collect_effects_calls.val} " +
  "infer_type_ms=\{vacuum_trace_delta_us_to_ms(stats.infer_type_us.val)} infer_type_calls=\{stats.infer_type_calls.val} " +
  "break_scan_ms=\{vacuum_trace_delta_us_to_ms(stats.break_scan_us.val)} break_scan_calls=\{stats.break_scan_calls.val} " +
  "rebase_score_ms=\{vacuum_trace_delta_us_to_ms(stats.rebase_score_us.val)} rebase_score_calls=\{stats.rebase_score_calls.val}"
}

///|
fn vq_hotspot_record(
  stats : VQRunStats,
  ordinal : Int,
  elapsed_ms : UInt64,
  shape : VQShapeMetrics,
) -> Unit {
  let entries = stats.hotspots.val
  entries.push({
    ordinal,
    elapsed_ms,
    total_instrs: shape.total_instrs,
    max_depth: shape.max_depth,
    score: vq_shape_score(shape),
  })
  if entries.length() <= 8 {
    return
  }
  let mut min_idx = 0
  let mut min_elapsed = entries[0].elapsed_ms
  for i = 1; i < entries.length(); i = i + 1 {
    if entries[i].elapsed_ms < min_elapsed {
      min_idx = i
      min_elapsed = entries[i].elapsed_ms
    }
  }
  let trimmed : Array[VQHotspotEntry] = []
  for i = 0; i < entries.length(); i = i + 1 {
    if i != min_idx {
      trimmed.push(entries[i])
    }
  }
  stats.hotspots.val = trimmed
}

///|
fn vq_hotspot_summary_line(stats : VQRunStats) -> String? {
  let entries = stats.hotspots.val
  if entries.is_empty() {
    return None
  }
  let ordered = entries.copy()
  let mut i = 0
  while i < ordered.length() {
    let mut best = i
    let mut j = i + 1
    while j < ordered.length() {
      if ordered[j].elapsed_ms > ordered[best].elapsed_ms {
        best = j
      }
      j += 1
    }
    if best != i {
      let tmp = ordered[i]
      ordered[i] = ordered[best]
      ordered[best] = tmp
    }
    i += 1
  }
  let out = StringBuilder::new()
  out.write_string("hotspots")
  for entry in ordered {
    out.write_string(
      " func[\{entry.ordinal}]=\{entry.elapsed_ms}ms/\{entry.total_instrs}instrs/depth\{entry.max_depth}/score\{entry.score}",
    )
  }
  Some(out.to_string())
}

///|
fn vq_trace_emit_run_summaries(
  trace : (String) -> Unit,
  stats : VQRunStats,
  total_funcs : Int,
) -> Unit {
  trace(vq_run_stats_render(stats, total_funcs))
  trace(vq_phase_totals_line(stats))
  trace(vq_helper_totals_line(stats))
  match vq_hotspot_summary_line(stats) {
    Some(line) => trace(line)
    None => ()
  }
}

///|
fn vq_commit_phase_timing(
  elapsed_ms : Ref[UInt64],
  calls : Ref[Int],
  start_ms : UInt64,
) -> UInt64 {
  let delta = vacuum_trace_elapsed_ms(start_ms)
  elapsed_ms.val = elapsed_ms.val + delta
  calls.val = calls.val + 1
  delta
}

///|
fn vq_commit_helper_timing(
  elapsed_us : Ref[UInt64],
  calls : Ref[Int],
  start_us : UInt64,
) -> UInt64 {
  let delta = vacuum_trace_elapsed_us_since(start_us)
  elapsed_us.val = elapsed_us.val + delta
  calls.val = calls.val + 1
  delta
}

///|
fn vq_commit_active_helper(
  start_us : UInt64,
  elapsed_us : (VQRunStats) -> Ref[UInt64],
  calls : (VQRunStats) -> Ref[Int],
) -> Unit {
  match vq_active_stats.val {
    Some(stats) =>
      ignore(vq_commit_helper_timing(elapsed_us(stats), calls(stats), start_us))
    None => ()
  }
}

///|
priv struct VQShapeMetrics {
  total_instrs : Int
  max_depth : Int
  block_count : Int
  if_count : Int
  drop_count : Int
  single_item_block_count : Int
  result_block_count : Int
}

///|
fn VQShapeMetrics::new(
  total_instrs : Int,
  max_depth : Int,
  block_count : Int,
  if_count : Int,
  drop_count : Int,
  single_item_block_count : Int,
  result_block_count : Int,
) -> VQShapeMetrics {
  {
    total_instrs,
    max_depth,
    block_count,
    if_count,
    drop_count,
    single_item_block_count,
    result_block_count,
  }
}

///|
priv struct VQShapeAccumulator {
  total_instrs : Ref[Int]
  max_depth : Ref[Int]
  block_count : Ref[Int]
  if_count : Ref[Int]
  drop_count : Ref[Int]
  single_item_block_count : Ref[Int]
  result_block_count : Ref[Int]
}

///|
fn VQShapeAccumulator::new() -> VQShapeAccumulator {
  {
    total_instrs: Ref::new(0),
    max_depth: Ref::new(0),
    block_count: Ref::new(0),
    if_count: Ref::new(0),
    drop_count: Ref::new(0),
    single_item_block_count: Ref::new(0),
    result_block_count: Ref::new(0),
  }
}

///|
fn vq_measure_texpr_shape_visit_expr(
  expr : TExpr,
  env : Env,
  acc : VQShapeAccumulator,
  depth : Int,
) -> Unit {
  if depth > acc.max_depth.val {
    acc.max_depth.val = depth
  }
  for instr in expr.instrs {
    vq_measure_texpr_shape_visit_instr(instr, env, acc, depth)
  }
}

///|
fn vq_measure_texpr_shape_visit_instr(
  instr : TInstr,
  env : Env,
  acc : VQShapeAccumulator,
  depth : Int,
) -> Unit {
  acc.total_instrs.val += 1
  if depth > acc.max_depth.val {
    acc.max_depth.val = depth
  }
  for child in eval_children(instr) {
    if child != instr {
      vq_measure_texpr_shape_visit_instr(child, env, acc, depth + 1)
    }
  }
  match instr.kind {
    TInstrKind::TBlock(bt, body) => {
      acc.block_count.val += 1
      if body.instrs.length() == 1 {
        acc.single_item_block_count.val += 1
      }
      if !vq_block_result_types(bt, env).is_empty() {
        acc.result_block_count.val += 1
      }
      vq_measure_texpr_shape_visit_expr(body, env, acc, depth + 1)
    }
    TInstrKind::TLoop(_, body) | TInstrKind::TTryTable(_, _, body) =>
      vq_measure_texpr_shape_visit_expr(body, env, acc, depth + 1)
    TInstrKind::TIf(_, _, then_body, else_body) => {
      acc.if_count.val += 1
      vq_measure_texpr_shape_visit_expr(then_body, env, acc, depth + 1)
      match else_body {
        Some(other) =>
          vq_measure_texpr_shape_visit_expr(other, env, acc, depth + 1)
        None => ()
      }
    }
    TInstrKind::TDrop(_) => acc.drop_count.val += 1
    _ => ()
  }
}

///|
fn vq_measure_texpr_shape(expr : TExpr, env : Env) -> VQShapeMetrics {
  let acc = VQShapeAccumulator::new()
  vq_measure_texpr_shape_visit_expr(expr, env, acc, 0)

  VQShapeMetrics::new(
    acc.total_instrs.val,
    acc.max_depth.val,
    acc.block_count.val,
    acc.if_count.val,
    acc.drop_count.val,
    acc.single_item_block_count.val,
    acc.result_block_count.val,
  )
}

///|
fn vq_shape_score(shape : VQShapeMetrics) -> Int {
  shape.total_instrs +
  shape.max_depth * 32 +
  shape.block_count * 4 +
  shape.single_item_block_count * 16 +
  shape.result_block_count * 24 +
  shape.if_count * 8 +
  shape.drop_count * 4
}

///|
fn vq_shape_requires_degraded_mode(shape : VQShapeMetrics) -> Bool {
  shape.max_depth >= 48 ||
  shape.total_instrs >= 4000 ||
  shape.single_item_block_count >= 32 ||
  vq_shape_score(shape) >= 6000
}

///|
fn vq_shape_seed_budget(shape : VQShapeMetrics) -> Int {
  let score = vq_shape_score(shape)
  if score >= 4000 {
    12000
  } else if score >= 1500 {
    6000
  } else {
    3000
  }
}

///|
fn vq_shape_full_budget(shape : VQShapeMetrics) -> Int {
  if vq_shape_score(shape) >= 2000 {
    80000
  } else {
    12000
  }
}

///|
fn vq_shape_degraded_budget(shape : VQShapeMetrics) -> Int {
  let budget = shape.total_instrs + shape.max_depth * 8 + 1024
  if budget < 4000 {
    4000
  } else if budget > 20000 {
    20000
  } else {
    budget
  }
}

///|
fn vq_collect_func_sigs(mod : Module) -> Array[VQFuncSig] {
  let out : Array[VQFuncSig] = []
  let env = Env::new().with_module(mod)
  match mod.func_sec {
    Some(FuncSec(type_idxs)) =>
      for tidx in type_idxs {
        match env.resolve_functype(tidx) {
          Some(FuncType(params, results)) =>
            out.push(VQFuncSig::new(params, results))
          None => out.push(VQFuncSig::new([], []))
        }
      }
    None => ()
  }
  out
}

///|
fn vq_type_of_timed(instr : TInstr, env : Env, stats : VQRunStats) -> ValType? {
  let start_us = vacuum_trace_now_us()
  let out = lcs_infer_tinstr_type(instr, env)
  ignore(
    vq_commit_helper_timing(
      stats.infer_type_us,
      stats.infer_type_calls,
      start_us,
    ),
  )
  out
}

///|
fn vq_collect_effects_timed(instr : TInstr, stats : VQRunStats) -> LCSEffects {
  let start_us = vacuum_trace_now_us()
  let out = lcs_collect_effects(instr)
  ignore(
    vq_commit_helper_timing(
      stats.collect_effects_us,
      stats.collect_effects_calls,
      start_us,
    ),
  )
  out
}

///|
fn vq_has_break_to_depth_in_texpr_timed(
  expr : TExpr,
  depth : Int,
  stats : VQRunStats,
) -> Bool {
  let start_us = vacuum_trace_now_us()
  let out = has_break_to_depth_in_texpr(expr, depth)
  ignore(
    vq_commit_helper_timing(
      stats.break_scan_us,
      stats.break_scan_calls,
      start_us,
    ),
  )
  out
}

///|
fn vq_name_to_string(name : Name) -> String {
  let Name(sv) = name
  sv.to_string()
}

///|
fn vq_collect_call_without_effects_intrinsics(mod : Module) -> Array[Bool] {
  let flags : Array[Bool] = []
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(module_name, base_name, FuncExternType(_)) => {
            let module_s = vq_name_to_string(module_name)
            let base_s = vq_name_to_string(base_name)
            flags.push(
              base_s == "call.without.effects" &&
              (
                module_s == "binaryen-intrinsics" ||
                module_s == "binaryen-intrinsics-optimized"
              ),
            )
          }
          Import(_, _, _) => ()
        }
      }
    None => ()
  }
  match mod.func_sec {
    Some(FuncSec(type_idxs)) =>
      for _ in type_idxs {
        flags.push(false)
      }
    None => ()
  }
  flags
}

///|
fn vq_is_removable_if_unused_intrinsic_call(
  func_idx : FuncIdx,
  call_without_effects_intrinsics : Array[Bool],
) -> Bool {
  let FuncIdx(raw) = func_idx
  let idx = raw.reinterpret_as_int()
  call_without_effects_intrinsics.get(idx).unwrap_or(false)
}

///|
fn vq_type_of_cached(
  instr : TInstr,
  env : Env,
  analysis_cache : VQAnalysisCache,
  instr_id? : Int? = None,
) -> ValType? {
  match vq_indexed_instr_node(analysis_cache, instr_id) {
    Some(node) => {
      analysis_cache.stats.type_cache_hits.val += 1
      return node.type_
    }
    None => ()
  }
  analysis_cache.stats.type_cache_misses.val += 1
  match instr.kind {
    TInstrKind::TLocalGet(idx) => return env.get_local_type(idx)
    TInstrKind::TGlobalGet(idx) =>
      return match env.get_global_type(idx) {
        Some(GlobalType(vt, _)) => Some(vt)
        None => None
      }
    TInstrKind::TI32Const(_) => return Some(ValType::i32())
    TInstrKind::TI64Const(_) => return Some(ValType::i64())
    TInstrKind::TF32Const(_) => return Some(ValType::f32())
    TInstrKind::TF64Const(_) => return Some(ValType::f64())
    TInstrKind::TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      return Some(ValType::v128())
    TInstrKind::TRefNull(ht) =>
      return Some(ValType::ref_type(RefType::new(true, ht)))
    TInstrKind::TRefFunc(_) => return Some(ValType::funcref())
    _ => ()
  }
  vq_type_of_timed(instr, env, analysis_cache.stats)
}

///|
fn vq_is_pure_leaf_no_effects(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TNop
    | TInstrKind::TLocalGet(_)
    | TInstrKind::TGlobalGet(_)
    | TInstrKind::TI32Const(_)
    | TInstrKind::TI64Const(_)
    | TInstrKind::TF32Const(_)
    | TInstrKind::TF64Const(_)
    | TInstrKind::TRefNull(_)
    | TInstrKind::TRefFunc(_) => true
    _ => false
  }
}

///|
fn vq_has_unremovable_effects_cached(
  instr : TInstr,
  analysis_cache : VQAnalysisCache,
  instr_id? : Int? = None,
) -> Bool {
  match vq_indexed_instr_node(analysis_cache, instr_id) {
    Some(node) => {
      analysis_cache.stats.effect_cache_hits.val += 1
      return node.has_unremovable_effects
    }
    None => ()
  }
  if vq_is_pure_leaf_no_effects(instr) {
    return false
  }
  analysis_cache.stats.effect_cache_misses.val += 1
  vq_collect_effects_timed(instr, analysis_cache.stats).has_unremovable_side_effects()
}

///|
fn vq_has_unremovable_shallow_effects_cached(
  instr : TInstr,
  analysis_cache : VQAnalysisCache,
  instr_id? : Int? = None,
) -> Bool {
  match vq_indexed_instr_node(analysis_cache, instr_id) {
    Some(node) => {
      analysis_cache.stats.shallow_effect_cache_hits.val += 1
      return node.shallow_has_unremovable_effects
    }
    None => ()
  }
  if vq_is_pure_leaf_no_effects(instr) {
    return false
  }
  analysis_cache.stats.shallow_effect_cache_misses.val += 1
  lcs_collect_shallow_effects(instr).has_unremovable_side_effects()
}

///|
fn vq_instr_has_calls_cached(
  instr : TInstr,
  analysis_cache : VQAnalysisCache,
  instr_id? : Int? = None,
) -> Bool {
  match vq_indexed_instr_node(analysis_cache, instr_id) {
    Some(node) => return node.has_calls
    None => ()
  }
  if vq_is_pure_leaf_no_effects(instr) {
    return false
  }
  vq_collect_effects_timed(instr, analysis_cache.stats).calls
}

///|
fn vq_instr_effect_transfers_control_flow_cached(
  instr : TInstr,
  analysis_cache : VQAnalysisCache,
  instr_id? : Int? = None,
) -> Bool {
  match vq_indexed_instr_node(analysis_cache, instr_id) {
    Some(node) => return node.effect_transfers_control_flow
    None => ()
  }
  if vq_is_pure_leaf_no_effects(instr) {
    return false
  }
  vq_collect_effects_timed(instr, analysis_cache.stats).transfers_control_flow()
}

///|
fn vq_instr_has_control_transfer_cached(
  instr : TInstr,
  analysis_cache : VQAnalysisCache,
  instr_id? : Int? = None,
) -> Bool {
  match vq_indexed_instr_node(analysis_cache, instr_id) {
    Some(node) => return node.has_control_transfer
    None => ()
  }
  vq_instr_has_control_transfer(instr)
}

///|
fn vq_same_type(a : ValType?, b : ValType?) -> Bool {
  match (a, b) {
    (Some(x), Some(y)) => x == y
    (None, None) => true
    _ => false
  }
}

///|
fn vq_block_result_types(bt : BlockType, env : Env) -> Array[ValType] {
  match env.expand_blocktype(bt) {
    Ok((_, results)) => results
    Err(_) => []
  }
}

///|
fn vq_block_result_type(bt : BlockType, env : Env) -> ValType? {
  match vq_block_result_types(bt, env) {
    [vt] => Some(vt)
    _ => None
  }
}

///|
fn vq_label_to_int(label : LabelIdx) -> Int {
  let LabelIdx(raw) = label
  raw.reinterpret_as_int()
}

///|
fn vq_label_from_int(idx : Int) -> LabelIdx {
  LabelIdx::new(idx.reinterpret_as_uint())
}

///|
fn vq_adjust_label_for_collapsed_wrapper(
  label : LabelIdx,
  depth : Int,
) -> LabelIdx {
  let curr = vq_label_to_int(label)
  if curr >= depth {
    vq_label_from_int(curr - 1)
  } else {
    label
  }
}

///|
fn vq_no_label_score() -> Int {
  -1_000_000
}

///|
fn vq_catch_label(c : Catch) -> LabelIdx {
  match c {
    Catch(_, label)
    | CatchRef(_, label)
    | CatchAll(label)
    | CatchAllRef(label) => label
  }
}

///|
fn vq_local_rebase_label_score(instr : TInstr) -> Int {
  let mut score = vq_no_label_score()
  match instr.kind {
    TInstrKind::TBr(label, _)
    | TInstrKind::TBrIf(label, _, _)
    | TInstrKind::TBrOnNull(label, _, _)
    | TInstrKind::TBrOnNonNull(label, _, _)
    | TInstrKind::TBrOnCast(label, _, _, _, _, _)
    | TInstrKind::TBrOnCastFail(label, _, _, _, _, _) =>
      score = vq_max_int(score, vq_label_to_int(label))
    TInstrKind::TBrTable(labels, default, _, _) => {
      for label in labels {
        score = vq_max_int(score, vq_label_to_int(label))
      }
      score = vq_max_int(score, vq_label_to_int(default))
    }
    TInstrKind::TTryTable(_, catches, _) =>
      for item in catches {
        score = vq_max_int(score, vq_label_to_int(vq_catch_label(item)) - 1)
      }
    _ => ()
  }
  score
}

///|
fn vq_instr_rebase_label_score_timed(instr : TInstr, stats : VQRunStats) -> Int {
  let start_us = vacuum_trace_now_us()
  let out = vq_instr_rebase_label_score(instr)
  ignore(
    vq_commit_helper_timing(
      stats.rebase_score_us,
      stats.rebase_score_calls,
      start_us,
    ),
  )
  out
}

///|
fn vq_texpr_rebase_label_score_timed(expr : TExpr, stats : VQRunStats) -> Int {
  let start_us = vacuum_trace_now_us()
  let out = vq_texpr_rebase_label_score(expr)
  ignore(
    vq_commit_helper_timing(
      stats.rebase_score_us,
      stats.rebase_score_calls,
      start_us,
    ),
  )
  out
}

///|
fn vq_texpr_rebase_label_score(expr : TExpr) -> Int {
  let mut score = vq_no_label_score()
  for instr in expr.instrs {
    score = vq_max_int(score, vq_instr_rebase_label_score(instr))
  }
  score
}

///|
fn vq_instr_rebase_label_score(instr : TInstr) -> Int {
  let mut score = vq_local_rebase_label_score(instr)
  for child in eval_children(instr) {
    if child == instr {
      continue
    }
    score = vq_max_int(score, vq_instr_rebase_label_score(child))
  }
  match instr.kind {
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) =>
      score = vq_max_int(score, vq_texpr_rebase_label_score(body) - 1)
    TInstrKind::TIf(_, _, then_body, else_body) => {
      score = vq_max_int(score, vq_texpr_rebase_label_score(then_body) - 1)
      match else_body {
        Some(other) =>
          score = vq_max_int(score, vq_texpr_rebase_label_score(other) - 1)
        None => ()
      }
    }
    _ => ()
  }
  score
}

///|
fn vq_rebase_labels_for_collapsed_wrapper_catch(
  catch_ : Catch,
  depth : Int,
) -> (Catch, Bool) {
  let curr_label = vq_catch_label(catch_)
  let next_label = vq_adjust_label_for_collapsed_wrapper(curr_label, depth)
  if next_label == curr_label {
    return (catch_, false)
  }
  (
    match catch_ {
      Catch(tag_idx, _) => Catch::new(tag_idx, next_label)
      CatchRef(tag_idx, _) => Catch::ref_(tag_idx, next_label)
      CatchAll(_) => Catch::all(next_label)
      CatchAllRef(_) => Catch::all_ref(next_label)
    },
    true,
  )
}

///|
fn vq_rebase_labels_for_collapsed_wrapper_catches(
  catches : Array[Catch],
  depth : Int,
) -> (Array[Catch], Bool) {
  let next_catches : Array[Catch] = []
  let mut changed = false
  for catch_ in catches {
    let (next_catch, catch_changed) = vq_rebase_labels_for_collapsed_wrapper_catch(
      catch_, depth,
    )
    if catch_changed {
      changed = true
    }
    next_catches.push(next_catch)
  }
  if changed {
    (next_catches, true)
  } else {
    (catches, false)
  }
}

///|
fn vq_rebase_labels_for_collapsed_wrapper_instr_with_depth(
  instr : TInstr,
  depth : Int,
) -> (TInstr, Bool) {
  fn rewrite_instrs(
    items : Array[TInstr],
    depth : Int,
  ) -> (Array[TInstr], Bool) {
    let next_items : Array[TInstr] = []
    let mut changed = false
    for item in items {
      let (next_item, item_changed) = vq_rebase_labels_for_collapsed_wrapper_instr_with_depth(
        item, depth,
      )
      if item_changed {
        changed = true
      }
      next_items.push(next_item)
    }
    if changed {
      (next_items, true)
    } else {
      (items, false)
    }
  }

  fn rewrite_texpr(expr : TExpr, depth : Int) -> (TExpr, Bool) {
    let (next_items, changed) = rewrite_instrs(expr.instrs, depth)
    if changed {
      (TExpr::new(next_items), true)
    } else {
      (expr, false)
    }
  }

  match instr.kind {
    TInstrKind::TBr(label, values) => {
      let next_label = vq_adjust_label_for_collapsed_wrapper(label, depth)
      let (next_values, values_changed) = rewrite_instrs(values, depth)
      if next_label == label && !values_changed {
        (instr, false)
      } else {
        (TInstr::br(next_label, next_values), true)
      }
    }
    TInstrKind::TBrIf(label, cond, values) => {
      let next_label = vq_adjust_label_for_collapsed_wrapper(label, depth)
      let (next_cond, cond_changed) = vq_rebase_labels_for_collapsed_wrapper_instr_with_depth(
        cond, depth,
      )
      let (next_values, values_changed) = rewrite_instrs(values, depth)
      if next_label == label && !cond_changed && !values_changed {
        (instr, false)
      } else {
        (TInstr::br_if(next_label, next_cond, next_values), true)
      }
    }
    TInstrKind::TBrTable(labels, default, index, values) => {
      let next_labels : Array[LabelIdx] = []
      let mut labels_changed = false
      for target in labels {
        let next_target = vq_adjust_label_for_collapsed_wrapper(target, depth)
        if next_target != target {
          labels_changed = true
        }
        next_labels.push(next_target)
      }
      let next_default = vq_adjust_label_for_collapsed_wrapper(default, depth)
      let (next_index, index_changed) = vq_rebase_labels_for_collapsed_wrapper_instr_with_depth(
        index, depth,
      )
      let (next_values, values_changed) = rewrite_instrs(values, depth)
      if !labels_changed &&
        next_default == default &&
        !index_changed &&
        !values_changed {
        (instr, false)
      } else {
        (
          TInstr::br_table(next_labels, next_default, next_index, next_values),
          true,
        )
      }
    }
    TInstrKind::TBrOnNull(label, ref_, values) => {
      let next_label = vq_adjust_label_for_collapsed_wrapper(label, depth)
      let (next_ref, ref_changed) = vq_rebase_labels_for_collapsed_wrapper_instr_with_depth(
        ref_, depth,
      )
      let (next_values, values_changed) = rewrite_instrs(values, depth)
      if next_label == label && !ref_changed && !values_changed {
        (instr, false)
      } else {
        (TInstr::br_on_null(next_label, next_ref, next_values), true)
      }
    }
    TInstrKind::TBrOnNonNull(label, ref_, values) => {
      let next_label = vq_adjust_label_for_collapsed_wrapper(label, depth)
      let (next_ref, ref_changed) = vq_rebase_labels_for_collapsed_wrapper_instr_with_depth(
        ref_, depth,
      )
      let (next_values, values_changed) = rewrite_instrs(values, depth)
      if next_label == label && !ref_changed && !values_changed {
        (instr, false)
      } else {
        (TInstr::br_on_non_null(next_label, next_ref, next_values), true)
      }
    }
    TInstrKind::TBrOnCast(
      label,
      CastOp(src_null, target_null),
      ht0,
      ht1,
      ref_,
      values
    ) => {
      let next_label = vq_adjust_label_for_collapsed_wrapper(label, depth)
      let (next_ref, ref_changed) = vq_rebase_labels_for_collapsed_wrapper_instr_with_depth(
        ref_, depth,
      )
      let (next_values, values_changed) = rewrite_instrs(values, depth)
      if next_label == label && !ref_changed && !values_changed {
        (instr, false)
      } else {
        (
          TInstr::br_on_cast(
            next_label, src_null, ht0, target_null, ht1, next_ref, next_values,
          ),
          true,
        )
      }
    }
    TInstrKind::TBrOnCastFail(
      label,
      CastOp(src_null, target_null),
      ht0,
      ht1,
      ref_,
      values
    ) => {
      let next_label = vq_adjust_label_for_collapsed_wrapper(label, depth)
      let (next_ref, ref_changed) = vq_rebase_labels_for_collapsed_wrapper_instr_with_depth(
        ref_, depth,
      )
      let (next_values, values_changed) = rewrite_instrs(values, depth)
      if next_label == label && !ref_changed && !values_changed {
        (instr, false)
      } else {
        (
          TInstr::br_on_cast_fail(
            next_label, src_null, ht0, target_null, ht1, next_ref, next_values,
          ),
          true,
        )
      }
    }
    TInstrKind::TBlock(bt, body) => {
      let (next_body, body_changed) = rewrite_texpr(body, depth + 1)
      if body_changed {
        (TInstr::block(bt, next_body), true)
      } else {
        (instr, false)
      }
    }
    TInstrKind::TLoop(bt, body) => {
      let (next_body, body_changed) = rewrite_texpr(body, depth + 1)
      if body_changed {
        (TInstr::loop_(bt, next_body), true)
      } else {
        (instr, false)
      }
    }
    TInstrKind::TIf(bt, cond, then_body, else_body) => {
      let (next_cond, cond_changed) = vq_rebase_labels_for_collapsed_wrapper_instr_with_depth(
        cond, depth,
      )
      let (next_then, then_changed) = rewrite_texpr(then_body, depth + 1)
      let (next_else, else_changed) = match else_body {
        Some(other) => {
          let (next, changed) = rewrite_texpr(other, depth + 1)
          (Some(next), changed)
        }
        None => (None, false)
      }
      if cond_changed || then_changed || else_changed {
        (TInstr::if_(bt, next_cond, next_then, next_else), true)
      } else {
        (instr, false)
      }
    }
    TInstrKind::TTryTable(bt, catches, body) => {
      let (next_catches, catches_changed) = vq_rebase_labels_for_collapsed_wrapper_catches(
        catches,
        depth + 1,
      )
      let (next_body, body_changed) = rewrite_texpr(body, depth + 1)
      if catches_changed || body_changed {
        (TInstr::try_table(bt, next_catches, next_body), true)
      } else {
        (instr, false)
      }
    }
    _ => {
      let children : Array[TInstr] = []
      let mut changed = false
      for child in eval_children(instr) {
        let (next_child, child_changed) = vq_rebase_labels_for_collapsed_wrapper_instr_with_depth(
          child, depth,
        )
        if child_changed {
          changed = true
        }
        children.push(next_child)
      }
      if changed {
        (mb_rebuild_non_control(instr, children), true)
      } else {
        (instr, false)
      }
    }
  }
}

///|
fn vq_rebase_labels_for_collapsed_wrapper(instr : TInstr) -> TInstr {
  let start_us = vacuum_trace_now_us()
  let (out, _) = vq_rebase_labels_for_collapsed_wrapper_instr_with_depth(
    instr, 0,
  )
  vq_commit_active_helper(start_us, fn(stats) { stats.rebase_labels_us }, fn(
    stats,
  ) {
    stats.rebase_labels_calls
  })
  out
}

///|
fn vq_rebase_labels_for_collapsed_wrapper_if_needed(
  instr : TInstr,
  analysis_cache : VQAnalysisCache,
  instr_id? : Int? = None,
  rebase_label_score? : Int? = None,
) -> TInstr {
  let needs_rebase = match vq_indexed_instr_node(analysis_cache, instr_id) {
    Some(node) => node.has_any_labelidx && node.max_rebase_label_score >= 0
    None =>
      match rebase_label_score {
        Some(score) => score >= 0
        None =>
          vq_instr_rebase_label_score_timed(instr, analysis_cache.stats) >= 0
      }
  }
  if needs_rebase {
    vq_rebase_labels_for_collapsed_wrapper(instr)
  } else {
    instr
  }
}

///|
fn vq_has_break_to_depth0_cached(
  expr : TExpr,
  analysis_cache : VQAnalysisCache,
  expr_id? : Int? = None,
  single_instr_rebase_label_score? : Int? = None,
) -> Bool {
  match vq_indexed_expr_node(analysis_cache, expr_id) {
    Some(_) => vq_indexed_expr_has_break_to_depth0(analysis_cache, expr_id)
    None => {
      let score = if expr.instrs.length() == 1 {
        match single_instr_rebase_label_score {
          Some(cached) => cached
          None =>
            vq_instr_rebase_label_score_timed(
              expr.instrs[0],
              analysis_cache.stats,
            )
        }
      } else {
        vq_texpr_rebase_label_score_timed(expr, analysis_cache.stats)
      }
      if score < 0 {
        return false
      }
      vq_has_break_to_depth_in_texpr_timed(expr, 0, analysis_cache.stats)
    }
  }
}

///|
fn vq_has_value_break_lub_depth0_cached(
  expr : TExpr,
  env : Env,
  analysis_cache : VQAnalysisCache,
  expr_id? : Int? = None,
  single_instr_rebase_label_score? : Int? = None,
) -> Bool {
  match vq_indexed_expr_value_break_lub_depth0(analysis_cache, expr_id) {
    Some(cached) => cached
    None => {
      let score = if expr.instrs.length() == 1 {
        match single_instr_rebase_label_score {
          Some(cached_score) => cached_score
          None =>
            vq_instr_rebase_label_score_timed(
              expr.instrs[0],
              analysis_cache.stats,
            )
        }
      } else {
        vq_texpr_rebase_label_score_timed(expr, analysis_cache.stats)
      }
      if score < 0 {
        return false
      }
      vq_value_break_to_depth_has_lub(expr, 0, env, analysis_cache)
    }
  }
}

///|
fn vq_only_original_instr_id(
  body : TExpr,
  analysis_cache : VQAnalysisCache,
  expr_id? : Int? = None,
) -> Int? {
  if body.instrs.length() != 1 {
    return None
  }
  match vq_indexed_expr_node(analysis_cache, expr_id) {
    Some(node) if node.instr_ids.length() == 1 => Some(node.instr_ids[0])
    _ => None
  }
}

///|
fn vq_texpr_result_type(
  expr : TExpr,
  env : Env,
  analysis_cache : VQAnalysisCache,
  expr_id? : Int? = None,
) -> ValType? {
  match vq_indexed_expr_node(analysis_cache, expr_id) {
    Some(node) =>
      if node.instr_ids.is_empty() {
        None
      } else {
        let last_id = node.instr_ids[node.instr_ids.length() - 1]
        vq_type_of_cached(
          expr.instrs[expr.instrs.length() - 1],
          env,
          analysis_cache,
          instr_id=Some(last_id),
        )
      }
    None => {
      let { instrs: items, .. } = expr
      if items.is_empty() {
        None
      } else {
        vq_type_of_cached(items[items.length() - 1], env, analysis_cache)
      }
    }
  }
}

///|
fn vq_is_nop_texpr(expr : TExpr) -> Bool {
  let { instrs: items, .. } = expr
  if items.is_empty() {
    return true
  }
  for item in items {
    match item.kind {
      TInstrKind::TNop => ()
      _ => return false
    }
  }
  true
}

///|
fn vq_texpr_is_unreachable(expr : TExpr) -> Bool {
  let { instrs: items, .. } = expr
  for item in items {
    if is_unreachable_instr(item) {
      return true
    }
  }
  false
}

///|
fn vq_is_explicit_unreachable_instr(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TUnreachable => true
    _ => false
  }
}

///|
fn vq_wrap_texpr(
  expr : TExpr,
  env : Env,
  analysis_cache : VQAnalysisCache,
  expr_id? : Int? = None,
) -> TInstr {
  let { instrs: items, .. } = expr
  if items.length() == 0 {
    return TInstr::nop()
  }
  if items.length() == 1 {
    return items[0]
  }
  match vq_texpr_result_type(expr, env, analysis_cache, expr_id~) {
    Some(vt) => TInstr::block(BlockType::val_type(vt), expr)
    None => TInstr::block(BlockType::void_(), expr)
  }
}

///|
fn vq_drop_texpr_value(
  expr : TExpr,
  env : Env,
  analysis_cache : VQAnalysisCache,
  expr_id? : Int? = None,
) -> TExpr {
  match vq_texpr_result_type(expr, env, analysis_cache, expr_id~) {
    Some(_) => {
      let items = expr.instrs
      if items.length() == 1 {
        return TExpr::new([TInstr::drop(items[0])])
      }
      if items.length() > 1 &&
        !vq_texpr_has_control_transfer_cached(expr, analysis_cache, expr_id~) {
        let out_items = items.copy()
        let last = out_items[out_items.length() - 1]
        ignore(out_items.pop())
        out_items.push(TInstr::drop(last))
        return TExpr::new(out_items)
      }
      let wrapped = vq_wrap_texpr(expr, env, analysis_cache, expr_id~)
      TExpr::new([TInstr::drop(wrapped)])
    }
    None => {
      let wrapped = vq_wrap_texpr(expr, env, analysis_cache, expr_id~)
      TExpr::new([wrapped])
    }
  }
}

///|
fn vq_must_keep_unused_parent(
  curr : TInstr,
  analysis_cache : VQAnalysisCache,
  instr_id? : Int? = None,
) -> Bool {
  match curr.kind {
    TInstrKind::TCall(func_idx, _) =>
      if vq_is_removable_if_unused_intrinsic_call(
          func_idx,
          analysis_cache.call_without_effects_intrinsics,
        ) {
        return false
      }
    _ => ()
  }
  vq_has_unremovable_shallow_effects_cached(curr, analysis_cache, instr_id~)
}

///|
fn vq_get_dropped_children_and_append_from_children(
  children_with_effects : Array[TInstr],
  env : Env,
  dummy : TInstr,
  analysis_cache : VQAnalysisCache,
) -> TInstr {
  let items : Array[TInstr] = []
  for child in children_with_effects {
    match vq_type_of_cached(child, env, analysis_cache) {
      Some(_) => items.push(TInstr::drop(child))
      None => items.push(child)
    }
  }
  items.push(dummy)
  match vq_type_of_cached(dummy, env, analysis_cache) {
    Some(vt) => TInstr::block(BlockType::val_type(vt), TExpr::new(items))
    None => TInstr::block(BlockType::void_(), TExpr::new(items))
  }
}

///|
fn vq_take_budget(budget : Ref[Int]) -> Bool {
  let remaining = budget.val
  if remaining <= 0 {
    false
  } else {
    budget.update(fn(i) { i - 1 })
    true
  }
}

///|
fn vq_optimize(
  instr : TInstr,
  result_used : Bool,
  type_matters : Bool,
  env : Env,
  budget : Ref[Int],
  analysis_cache : VQAnalysisCache,
  pass_options : VQPassOptions,
  instr_id? : Int? = None,
) -> TInstr? {
  if !vq_take_budget(budget) {
    return vq_try_midpass_degraded_fallback(
      instr, env, result_used, analysis_cache, pass_options,
    )
  }
  let initial_type = vq_type_of_cached(instr, env, analysis_cache, instr_id~)
  let mut type_matters = type_matters
  if initial_type is None {
    type_matters = true
  }
  if is_unreachable_instr(instr) {
    return Some(instr)
  }
  if result_used {
    return Some(instr)
  }

  let mut prev = instr
  let mut curr = instr
  for _ in 0..<64 {
    let curr_type = if curr == instr {
      vq_type_of_cached(curr, env, analysis_cache, instr_id~)
    } else {
      vq_type_of_cached(curr, env, analysis_cache)
    }
    if type_matters && !vq_same_type(curr_type, initial_type) {
      return Some(prev)
    }
    prev = curr
    match curr.kind {
      TInstrKind::TDrop(_)
      | TInstrKind::TBlock(_, _)
      | TInstrKind::TIf(_, _, _, _)
      | TInstrKind::TLoop(_, _)
      | TInstrKind::TTryTable(_, _, _) => return Some(curr)
      _ => ()
    }
    if curr == instr &&
      vq_must_keep_unused_parent(curr, analysis_cache, instr_id~) {
      return Some(curr)
    }
    if curr != instr && vq_must_keep_unused_parent(curr, analysis_cache) {
      return Some(curr)
    }
    let mut first_effectful_child : TInstr? = None
    let mut many_effectful_children : Array[TInstr]? = None
    for child in eval_children(curr) {
      if !vq_has_unremovable_effects_cached(child, analysis_cache) {
        continue
      }
      match first_effectful_child {
        None => first_effectful_child = Some(child)
        Some(existing) =>
          match many_effectful_children {
            None => many_effectful_children = Some([existing, child])
            Some(collected) => collected.push(child)
          }
      }
    }
    if first_effectful_child is None {
      return None
    }
    if many_effectful_children is None {
      curr = first_effectful_child.unwrap()
      if is_unreachable_instr(curr) {
        return Some(curr)
      }
      continue
    }
    match curr_type {
      Some(vt) =>
        match af_make_zero(vt) {
          Some(dummy) =>
            return Some(
              vq_get_dropped_children_and_append_from_children(
                many_effectful_children.unwrap(),
                env,
                dummy,
                analysis_cache,
              ),
            )
          None => return Some(curr)
        }
      None => return Some(curr)
    }
  }
  Some(curr)
}

///|
priv struct VQSequenceResult {
  items : Array[TInstr]
  changed : Bool
}

///|
fn VQSequenceResult::new(
  items : Array[TInstr],
  changed : Bool,
) -> VQSequenceResult {
  { items, changed }
}

///|
priv struct VQStackSig {
  required : Int
  produced : Int
  reachable : Bool
}

///|
fn VQStackSig::new(
  required : Int,
  produced : Int,
  reachable : Bool,
) -> VQStackSig {
  { required, produced, reachable }
}

///|
priv struct VQIndexedInstrNode {
  eval_child_ids : Array[Int]
  body_expr_id : Int?
  then_expr_id : Int?
  else_expr_id : Int?
  has_any_labelidx : Bool
  max_rebase_label_score : Int
  type_ : ValType?
  shallow_has_unremovable_effects : Bool
  has_unremovable_effects : Bool
  has_calls : Bool
  effect_transfers_control_flow : Bool
  has_control_transfer : Bool
  throws : Bool
  explicit_unreachable : Bool
  may_not_return : Bool
  stack_sig : VQStackSig?
}

///|
fn VQIndexedInstrNode::new(
  eval_child_ids : Array[Int],
  body_expr_id : Int?,
  then_expr_id : Int?,
  else_expr_id : Int?,
  has_any_labelidx : Bool,
  max_rebase_label_score : Int,
  type_ : ValType?,
  shallow_has_unremovable_effects : Bool,
  has_unremovable_effects : Bool,
  has_calls : Bool,
  effect_transfers_control_flow : Bool,
  has_control_transfer : Bool,
  throws : Bool,
  explicit_unreachable : Bool,
  may_not_return : Bool,
  stack_sig : VQStackSig?,
) -> VQIndexedInstrNode {
  {
    eval_child_ids,
    body_expr_id,
    then_expr_id,
    else_expr_id,
    has_any_labelidx,
    max_rebase_label_score,
    type_,
    shallow_has_unremovable_effects,
    has_unremovable_effects,
    has_calls,
    effect_transfers_control_flow,
    has_control_transfer,
    throws,
    explicit_unreachable,
    may_not_return,
    stack_sig,
  }
}

///|
priv struct VQIndexedExprNode {
  instr_ids : Array[Int]
  has_control_transfer : Bool
  throws : Bool
  explicit_unreachable : Bool
  max_rebase_label_score : Int
  mut has_break_to_depth0 : Bool
  value_break_types : Array[ValType]
  mut has_unknown_value_break_type : Bool
  mut has_unsupported_multivalue_break : Bool
  mut value_break_lub_depth0 : Bool?
}

///|
fn VQIndexedExprNode::new(
  instr_ids : Array[Int],
  has_control_transfer : Bool,
  throws : Bool,
  explicit_unreachable : Bool,
  max_rebase_label_score : Int,
) -> VQIndexedExprNode {
  {
    instr_ids,
    has_control_transfer,
    throws,
    explicit_unreachable,
    max_rebase_label_score,
    has_break_to_depth0: false,
    value_break_types: [],
    has_unknown_value_break_type: false,
    has_unsupported_multivalue_break: false,
    value_break_lub_depth0: None,
  }
}

///|
priv struct VQAnalysisCache {
  indexed_instr_nodes : Array[VQIndexedInstrNode]
  indexed_expr_nodes : Array[VQIndexedExprNode]
  mut indexed_root_expr_id : Int?
  mut midpass_degraded_budget : Ref[Int]?
  call_without_effects_intrinsics : Array[Bool]
  stats : VQRunStats
}

///|
fn VQAnalysisCache::new(
  call_without_effects_intrinsics : Array[Bool],
  stats : VQRunStats,
) -> VQAnalysisCache {
  {
    indexed_instr_nodes: [],
    indexed_expr_nodes: [],
    indexed_root_expr_id: None,
    midpass_degraded_budget: None,
    call_without_effects_intrinsics,
    stats,
  }
}

///|
fn vq_analysis_cache_instr_entry_count(cache : VQAnalysisCache) -> Int {
  cache.indexed_instr_nodes.length()
}

///|
fn vq_analysis_cache_expr_entry_count(cache : VQAnalysisCache) -> Int {
  cache.indexed_expr_nodes.length()
}

///|
fn vq_indexed_instr_node(
  analysis_cache : VQAnalysisCache,
  instr_id : Int?,
) -> VQIndexedInstrNode? {
  match instr_id {
    Some(id) => analysis_cache.indexed_instr_nodes.get(id)
    None => None
  }
}

///|
fn vq_indexed_expr_node(
  analysis_cache : VQAnalysisCache,
  expr_id : Int?,
) -> VQIndexedExprNode? {
  match expr_id {
    Some(id) => analysis_cache.indexed_expr_nodes.get(id)
    None => None
  }
}

///|
fn vq_indexed_expr_instr_id(expr_node : VQIndexedExprNode?, idx : Int) -> Int? {
  match expr_node {
    Some(node) => node.instr_ids.get(idx)
    None => None
  }
}

///|
fn vq_indexed_eval_child_id(
  instr_node : VQIndexedInstrNode?,
  idx : Int,
) -> Int? {
  match instr_node {
    Some(node) => node.eval_child_ids.get(idx)
    None => None
  }
}

///|
fn vq_last_original_instr_id(
  body : TExpr,
  analysis_cache : VQAnalysisCache,
  expr_id? : Int? = None,
) -> Int? {
  if body.instrs.is_empty() {
    return None
  }
  match vq_indexed_expr_node(analysis_cache, expr_id) {
    Some(node) if node.instr_ids.length() == body.instrs.length() =>
      Some(node.instr_ids[node.instr_ids.length() - 1])
    _ => None
  }
}

///|
fn vq_only_original_eval_child_id(
  body : TExpr,
  analysis_cache : VQAnalysisCache,
  child_idx : Int,
  expr_id? : Int? = None,
) -> Int? {
  match vq_only_original_instr_id(body, analysis_cache, expr_id~) {
    Some(instr_id) =>
      vq_indexed_eval_child_id(
        vq_indexed_instr_node(analysis_cache, Some(instr_id)),
        child_idx,
      )
    None => None
  }
}

///|
fn vq_can_reuse_original_expr_control_metadata(
  original : TExpr,
  next : TExpr,
  analysis_cache : VQAnalysisCache,
  expr_id? : Int? = None,
) -> Bool {
  if original.instrs.length() != next.instrs.length() {
    return false
  }
  match vq_indexed_expr_node(analysis_cache, expr_id) {
    Some(node) if node.instr_ids.length() == original.instrs.length() => {
      for i = 0; i < original.instrs.length(); i = i + 1 {
        if physical_equal(original.instrs[i], next.instrs[i]) {
          continue
        }
        match analysis_cache.indexed_instr_nodes.get(node.instr_ids[i]) {
          Some(instr_node) =>
            if instr_node.has_control_transfer || instr_node.has_any_labelidx {
              return false
            }
          None => return false
        }
      }
      true
    }
    _ => false
  }
}

///|
fn vq_preserve_original_if_unchanged(
  original : TInstr,
  original_condition : TInstr,
  original_then : TExpr,
  original_else : TExpr?,
  bt : BlockType,
  next_condition : TInstr,
  next_then : TExpr,
  next_else : TExpr?,
) -> TInstr {
  let unchanged_else = match (next_else, original_else) {
    (Some(next), Some(curr)) => physical_equal(next, curr)
    (None, None) => true
    _ => false
  }
  if physical_equal(next_condition, original_condition) &&
    physical_equal(next_then, original_then) &&
    unchanged_else {
    original
  } else {
    TInstr::if_(bt, next_condition, next_then, next_else)
  }
}

///|
fn vq_stack_sig_list_indexed(
  item_ids : Array[Int],
  analysis_cache : VQAnalysisCache,
) -> VQStackSig? {
  let mut acc = VQStackSig::new(0, 0, true)
  for item_id in item_ids {
    match analysis_cache.indexed_instr_nodes[item_id].stack_sig {
      Some(sig) => {
        acc = vq_stack_seq(acc, sig)
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
fn vq_stack_sig_expr_indexed(
  expr_id : Int,
  analysis_cache : VQAnalysisCache,
) -> VQStackSig? {
  vq_stack_sig_list_indexed(
    analysis_cache.indexed_expr_nodes[expr_id].instr_ids,
    analysis_cache,
  )
}

///|
fn vq_indexed_expr_any_instr(
  expr_id : Int?,
  analysis_cache : VQAnalysisCache,
  pred : (VQIndexedInstrNode) -> Bool,
) -> Bool {
  match expr_id {
    Some(id) =>
      for instr_id in analysis_cache.indexed_expr_nodes[id].instr_ids {
        if pred(analysis_cache.indexed_instr_nodes[instr_id]) {
          return true
        }
      }
    None => ()
  }
  false
}

///|
fn vq_indexed_child_any(
  child_ids : Array[Int],
  analysis_cache : VQAnalysisCache,
  pred : (VQIndexedInstrNode) -> Bool,
) -> Bool {
  for child_id in child_ids {
    if pred(analysis_cache.indexed_instr_nodes[child_id]) {
      return true
    }
  }
  false
}

///|
fn vq_indexed_expr_has_break_to_depth0(
  analysis_cache : VQAnalysisCache,
  expr_id : Int?,
) -> Bool {
  match vq_indexed_expr_node(analysis_cache, expr_id) {
    Some(node) => node.has_break_to_depth0
    None => false
  }
}

///|
fn vq_indexed_expr_value_break_lub_depth0(
  analysis_cache : VQAnalysisCache,
  expr_id : Int?,
) -> Bool? {
  match vq_indexed_expr_node(analysis_cache, expr_id) {
    Some(node) => node.value_break_lub_depth0
    None => None
  }
}

///|
fn vq_stack_sig_instr_indexed(
  instr : TInstr,
  env : Env,
  analysis_cache : VQAnalysisCache,
  eval_child_ids : Array[Int],
  body_expr_id : Int?,
  then_expr_id : Int?,
  else_expr_id : Int?,
) -> VQStackSig? {
  match instr.kind {
    TInstrKind::TNop => Some(VQStackSig::new(0, 0, true))
    TInstrKind::TUnreachable => Some(VQStackSig::new(0, 0, false))
    TInstrKind::TLocalGet(_)
    | TInstrKind::TGlobalGet(_)
    | TInstrKind::TI32Const(_)
    | TInstrKind::TI64Const(_)
    | TInstrKind::TF32Const(_)
    | TInstrKind::TF64Const(_)
    | TInstrKind::TRefNull(_)
    | TInstrKind::TRefFunc(_) => Some(VQStackSig::new(0, 1, true))
    TInstrKind::TDrop(_)
    | TInstrKind::TLocalSet(_, _)
    | TInstrKind::TGlobalSet(_, _) =>
      vq_stack_sig_list_indexed(eval_child_ids, analysis_cache).map(fn(sig) {
        vq_stack_sig_pop_push(sig, 1, 0)
      })
    TInstrKind::TLocalTee(_, _) =>
      vq_stack_sig_list_indexed(eval_child_ids, analysis_cache).map(fn(sig) {
        vq_stack_sig_pop_push(sig, 1, 1)
      })
    TInstrKind::TUnary(_, _)
    | TInstrKind::TLoad(_, _, _)
    | TInstrKind::TRefIsNull(_)
    | TInstrKind::TRefAsNonNull(_)
    | TInstrKind::TAnyConvertExtern(_)
    | TInstrKind::TExternConvertAny(_)
    | TInstrKind::TI31GetS(_)
    | TInstrKind::TI31GetU(_)
    | TInstrKind::TArrayLen(_) =>
      vq_stack_sig_list_indexed(eval_child_ids, analysis_cache).map(fn(sig) {
        vq_stack_sig_pop_push(sig, 1, 1)
      })
    TInstrKind::TBinary(_, _, _) | TInstrKind::TRefEq(_, _) =>
      vq_stack_sig_list_indexed(eval_child_ids, analysis_cache).map(fn(sig) {
        vq_stack_sig_pop_push(sig, 2, 1)
      })
    TInstrKind::TStore(_, _, _, _) =>
      vq_stack_sig_list_indexed(eval_child_ids, analysis_cache).map(fn(sig) {
        vq_stack_sig_pop_push(sig, 2, 0)
      })
    TInstrKind::TSelect(_, _, _, _) =>
      vq_stack_sig_list_indexed(eval_child_ids, analysis_cache).map(fn(sig) {
        vq_stack_sig_pop_push(sig, 3, 1)
      })
    TInstrKind::TBlock(_, _)
    | TInstrKind::TLoop(_, _)
    | TInstrKind::TTryTable(_, _, _) =>
      match body_expr_id {
        Some(id) => vq_stack_sig_expr_indexed(id, analysis_cache)
        None => None
      }
    TInstrKind::TIf(_, _, _, _) => {
      let else_sig = match else_expr_id {
        Some(id) => vq_stack_sig_expr_indexed(id, analysis_cache)
        None => Some(VQStackSig::new(0, 0, true))
      }
      match
        (
          vq_stack_sig_list_indexed(eval_child_ids, analysis_cache),
          then_expr_id.bind(fn(id) {
            vq_stack_sig_expr_indexed(id, analysis_cache)
          }),
          else_sig,
        ) {
        (Some(cond_sig), Some(then_sig), Some(other_sig)) =>
          Some(vq_stack_sig_if(cond_sig, then_sig, other_sig))
        _ => None
      }
    }
    TInstrKind::TCall(func_idx, _) =>
      match
        (
          vq_stack_sig_list_indexed(eval_child_ids, analysis_cache),
          env.get_functype_by_funcidx(func_idx),
        ) {
        (Some(sig), Some(FuncType(params, results))) =>
          Some(vq_stack_sig_pop_push(sig, params.length(), results.length()))
        _ => None
      }
    TInstrKind::TCallIndirect(type_idx, _, _, _)
    | TInstrKind::TCallRef(type_idx, _, _) =>
      match
        (
          vq_stack_sig_list_indexed(eval_child_ids, analysis_cache),
          env.resolve_functype(type_idx),
        ) {
        (Some(sig), Some(FuncType(params, results))) =>
          Some(
            vq_stack_sig_pop_push(sig, params.length() + 1, results.length()),
          )
        _ => None
      }
    TInstrKind::TReturn(_) | TInstrKind::TThrow(_, _) =>
      vq_stack_sig_list_indexed(eval_child_ids, analysis_cache).map(fn(sig) {
        vq_stack_sig_terminate(sig, 0)
      })
    TInstrKind::TThrowRef(_) =>
      vq_stack_sig_list_indexed(eval_child_ids, analysis_cache).map(fn(sig) {
        vq_stack_sig_terminate(sig, 1)
      })
    TInstrKind::TBr(_, _) =>
      vq_stack_sig_list_indexed(eval_child_ids, analysis_cache).map(fn(sig) {
        vq_stack_sig_terminate(sig, 0)
      })
    TInstrKind::TBrIf(_, _, _) =>
      vq_stack_sig_list_indexed(eval_child_ids, analysis_cache).map(fn(sig) {
        vq_stack_sig_pop_push(sig, 1, 0)
      })
    TInstrKind::TBrTable(_, _, _, _) =>
      vq_stack_sig_list_indexed(eval_child_ids, analysis_cache).map(fn(sig) {
        vq_stack_sig_terminate(sig, 1)
      })
    TInstrKind::TReturnCall(func_idx, _) =>
      match
        (
          vq_stack_sig_list_indexed(eval_child_ids, analysis_cache),
          env.get_functype_by_funcidx(func_idx),
        ) {
        (Some(sig), Some(FuncType(params, _))) =>
          Some(vq_stack_sig_terminate(sig, params.length()))
        _ => None
      }
    TInstrKind::TReturnCallIndirect(type_idx, _, _, _)
    | TInstrKind::TReturnCallRef(type_idx, _, _) =>
      match
        (
          vq_stack_sig_list_indexed(eval_child_ids, analysis_cache),
          env.resolve_functype(type_idx),
        ) {
        (Some(sig), Some(FuncType(params, _))) =>
          Some(vq_stack_sig_terminate(sig, params.length() + 1))
        _ => None
      }
    _ => None
  }
}

///|
fn vq_build_indexed_instr_analysis_bounded(
  instr : TInstr,
  env : Env,
  analysis_cache : VQAnalysisCache,
  budget : Ref[Int],
) -> Int? {
  let start_us = vacuum_trace_now_us()
  if !vq_take_budget(budget) {
    ignore(
      vq_commit_helper_timing(
        analysis_cache.stats.seed_instr_us,
        analysis_cache.stats.seed_instr_calls,
        start_us,
      ),
    )
    return None
  }
  let eval_child_ids : Array[Int] = []
  for child in eval_children(instr) {
    match
      vq_build_indexed_instr_analysis_bounded(
        child, env, analysis_cache, budget,
      ) {
      Some(id) => eval_child_ids.push(id)
      None => return None
    }
  }
  let body_expr_id = match instr.kind {
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) =>
      vq_build_indexed_expr_analysis_bounded(body, env, analysis_cache, budget)
    _ => None
  }
  match instr.kind {
    TInstrKind::TBlock(_, _)
    | TInstrKind::TLoop(_, _)
    | TInstrKind::TTryTable(_, _, _) => if body_expr_id is None { return None }
    _ => ()
  }
  let then_expr_id = match instr.kind {
    TInstrKind::TIf(_, _, then_body, _) =>
      vq_build_indexed_expr_analysis_bounded(
        then_body, env, analysis_cache, budget,
      )
    _ => None
  }
  match instr.kind {
    TInstrKind::TIf(_, _, _, _) if then_expr_id is None => return None
    _ => ()
  }
  let else_expr_id = match instr.kind {
    TInstrKind::TIf(_, _, _, Some(other)) =>
      vq_build_indexed_expr_analysis_bounded(other, env, analysis_cache, budget)
    _ => None
  }
  let shallow_effects = lcs_collect_shallow_effects(instr)
  let shallow_has_unremovable = shallow_effects.has_unremovable_side_effects()
  let mut has_unremovable_effects = shallow_has_unremovable
  let mut has_calls = shallow_effects.calls
  let mut effect_transfers_control_flow = shallow_effects.transfers_control_flow()
  for child_id in eval_child_ids {
    let child = analysis_cache.indexed_instr_nodes[child_id]
    has_unremovable_effects = has_unremovable_effects ||
      child.has_unremovable_effects
    has_calls = has_calls || child.has_calls
    effect_transfers_control_flow = effect_transfers_control_flow ||
      child.effect_transfers_control_flow
  }
  has_unremovable_effects = has_unremovable_effects ||
    vq_indexed_expr_any_instr(body_expr_id, analysis_cache, fn(node) {
      node.has_unremovable_effects
    }) ||
    vq_indexed_expr_any_instr(then_expr_id, analysis_cache, fn(node) {
      node.has_unremovable_effects
    }) ||
    vq_indexed_expr_any_instr(else_expr_id, analysis_cache, fn(node) {
      node.has_unremovable_effects
    })
  has_calls = has_calls ||
    vq_indexed_expr_any_instr(body_expr_id, analysis_cache, fn(node) {
      node.has_calls
    }) ||
    vq_indexed_expr_any_instr(then_expr_id, analysis_cache, fn(node) {
      node.has_calls
    }) ||
    vq_indexed_expr_any_instr(else_expr_id, analysis_cache, fn(node) {
      node.has_calls
    })
  effect_transfers_control_flow = effect_transfers_control_flow ||
    vq_indexed_expr_any_instr(body_expr_id, analysis_cache, fn(node) {
      node.effect_transfers_control_flow
    }) ||
    vq_indexed_expr_any_instr(then_expr_id, analysis_cache, fn(node) {
      node.effect_transfers_control_flow
    }) ||
    vq_indexed_expr_any_instr(else_expr_id, analysis_cache, fn(node) {
      node.effect_transfers_control_flow
    })
  let body_throws = match body_expr_id {
    Some(id) => analysis_cache.indexed_expr_nodes[id].throws
    None => false
  }
  let then_throws = match then_expr_id {
    Some(id) => analysis_cache.indexed_expr_nodes[id].throws
    None => false
  }
  let else_throws = match else_expr_id {
    Some(id) => analysis_cache.indexed_expr_nodes[id].throws
    None => false
  }
  let body_explicit_unreachable = match body_expr_id {
    Some(id) => analysis_cache.indexed_expr_nodes[id].explicit_unreachable
    None => false
  }
  let then_explicit_unreachable = match then_expr_id {
    Some(id) => analysis_cache.indexed_expr_nodes[id].explicit_unreachable
    None => false
  }
  let else_explicit_unreachable = match else_expr_id {
    Some(id) => analysis_cache.indexed_expr_nodes[id].explicit_unreachable
    None => false
  }
  let local_has_labelidx = match instr.kind {
    TInstrKind::TBr(_, _)
    | TInstrKind::TBrIf(_, _, _)
    | TInstrKind::TBrTable(_, _, _, _)
    | TInstrKind::TBrOnNull(_, _, _)
    | TInstrKind::TBrOnNonNull(_, _, _)
    | TInstrKind::TBrOnCast(_, _, _, _, _, _)
    | TInstrKind::TBrOnCastFail(_, _, _, _, _, _) => true
    TInstrKind::TTryTable(_, catches, _) => !catches.is_empty()
    _ => false
  }
  let has_any_labelidx = local_has_labelidx ||
    vq_indexed_child_any(eval_child_ids, analysis_cache, fn(node) {
      node.has_any_labelidx
    }) ||
    vq_indexed_expr_any_instr(body_expr_id, analysis_cache, fn(node) {
      node.has_any_labelidx
    }) ||
    vq_indexed_expr_any_instr(then_expr_id, analysis_cache, fn(node) {
      node.has_any_labelidx
    }) ||
    vq_indexed_expr_any_instr(else_expr_id, analysis_cache, fn(node) {
      node.has_any_labelidx
    })
  let mut max_rebase_label_score = vq_local_rebase_label_score(instr)
  for child_id in eval_child_ids {
    max_rebase_label_score = vq_max_int(
      max_rebase_label_score,
      analysis_cache.indexed_instr_nodes[child_id].max_rebase_label_score,
    )
  }
  match body_expr_id {
    Some(id) =>
      max_rebase_label_score = vq_max_int(
        max_rebase_label_score,
        analysis_cache.indexed_expr_nodes[id].max_rebase_label_score - 1,
      )
    None => ()
  }
  match then_expr_id {
    Some(id) =>
      max_rebase_label_score = vq_max_int(
        max_rebase_label_score,
        analysis_cache.indexed_expr_nodes[id].max_rebase_label_score - 1,
      )
    None => ()
  }
  match else_expr_id {
    Some(id) =>
      max_rebase_label_score = vq_max_int(
        max_rebase_label_score,
        analysis_cache.indexed_expr_nodes[id].max_rebase_label_score - 1,
      )
    None => ()
  }
  let has_control_transfer = effect_transfers_control_flow ||
    vq_instr_has_control_transfer_local(instr)
  let throws = vq_instr_throws_local(instr) ||
    body_throws ||
    then_throws ||
    else_throws ||
    vq_indexed_child_any(eval_child_ids, analysis_cache, fn(node) {
      node.throws
    })
  let explicit_unreachable = vq_is_explicit_unreachable_instr(instr) ||
    body_explicit_unreachable ||
    then_explicit_unreachable ||
    else_explicit_unreachable ||
    vq_indexed_child_any(eval_child_ids, analysis_cache, fn(node) {
      node.explicit_unreachable
    })
  let may_not_return = vq_instr_may_not_return_local(instr) ||
    vq_indexed_expr_any_instr(body_expr_id, analysis_cache, fn(node) {
      node.may_not_return
    }) ||
    vq_indexed_expr_any_instr(then_expr_id, analysis_cache, fn(node) {
      node.may_not_return
    }) ||
    vq_indexed_expr_any_instr(else_expr_id, analysis_cache, fn(node) {
      node.may_not_return
    }) ||
    vq_indexed_child_any(eval_child_ids, analysis_cache, fn(node) {
      node.may_not_return
    })
  let type_ = vq_type_of_timed(instr, env, analysis_cache.stats)
  let stack_sig = vq_stack_sig_instr_indexed(
    instr, env, analysis_cache, eval_child_ids, body_expr_id, then_expr_id, else_expr_id,
  )
  let instr_id = analysis_cache.indexed_instr_nodes.length()
  analysis_cache.indexed_instr_nodes.push(
    VQIndexedInstrNode::new(
      eval_child_ids, body_expr_id, then_expr_id, else_expr_id, has_any_labelidx,
      max_rebase_label_score, type_, shallow_has_unremovable, has_unremovable_effects,
      has_calls, effect_transfers_control_flow, has_control_transfer, throws, explicit_unreachable,
      may_not_return, stack_sig,
    ),
  )
  ignore(
    vq_commit_helper_timing(
      analysis_cache.stats.seed_instr_us,
      analysis_cache.stats.seed_instr_calls,
      start_us,
    ),
  )
  Some(instr_id)
}

///|
fn vq_build_indexed_expr_analysis_bounded(
  expr : TExpr,
  env : Env,
  analysis_cache : VQAnalysisCache,
  budget : Ref[Int],
) -> Int? {
  let start_us = vacuum_trace_now_us()
  if !vq_take_budget(budget) {
    ignore(
      vq_commit_helper_timing(
        analysis_cache.stats.seed_texpr_us,
        analysis_cache.stats.seed_texpr_calls,
        start_us,
      ),
    )
    return None
  }
  let instr_ids : Array[Int] = []
  let mut has_control_transfer = false
  let mut throws = false
  let mut explicit_unreachable = false
  let mut max_rebase_label_score = vq_no_label_score()
  for instr in expr.instrs {
    match
      vq_build_indexed_instr_analysis_bounded(
        instr, env, analysis_cache, budget,
      ) {
      Some(id) => {
        instr_ids.push(id)
        let node = analysis_cache.indexed_instr_nodes[id]
        has_control_transfer = has_control_transfer || node.has_control_transfer
        throws = throws || node.throws
        explicit_unreachable = explicit_unreachable || node.explicit_unreachable
        max_rebase_label_score = vq_max_int(
          max_rebase_label_score,
          node.max_rebase_label_score,
        )
      }
      None => return None
    }
  }
  let expr_id = analysis_cache.indexed_expr_nodes.length()
  analysis_cache.indexed_expr_nodes.push(
    VQIndexedExprNode::new(
      instr_ids, has_control_transfer, throws, explicit_unreachable, max_rebase_label_score,
    ),
  )
  ignore(
    vq_commit_helper_timing(
      analysis_cache.stats.seed_texpr_us,
      analysis_cache.stats.seed_texpr_calls,
      start_us,
    ),
  )
  Some(expr_id)
}

///|
fn vq_indexed_target_expr_id(expr_stack : Array[Int], label : LabelIdx) -> Int? {
  let idx = expr_stack.length() - 1 - vq_label_to_int(label)
  if idx < 0 || idx >= expr_stack.length() {
    None
  } else {
    Some(expr_stack[idx])
  }
}

///|
fn vq_record_indexed_value_break_target(
  target_expr_id : Int,
  values : Array[TInstr],
  value_ids : Array[Int],
  env : Env,
  analysis_cache : VQAnalysisCache,
) -> Unit {
  let target = analysis_cache.indexed_expr_nodes[target_expr_id]
  target.has_break_to_depth0 = true
  if values.is_empty() {
    return
  }
  if values.length() != 1 || value_ids.length() != 1 {
    target.has_unsupported_multivalue_break = true
    return
  }
  match
    vq_type_of_cached(
      values[0],
      env,
      analysis_cache,
      instr_id=Some(value_ids[0]),
    ) {
    Some(vt) => target.value_break_types.push(vt)
    None => target.has_unknown_value_break_type = true
  }
}

///|
fn vq_indexed_collect_branch_targets(
  labels : Array[LabelIdx],
  values : Array[TInstr],
  value_ids : Array[Int],
  env : Env,
  analysis_cache : VQAnalysisCache,
  expr_stack : Array[Int],
) -> Unit {
  let seen_expr_ids : Array[Int] = []
  for label in labels {
    match vq_indexed_target_expr_id(expr_stack, label) {
      Some(target_expr_id) => {
        let mut seen = false
        for existing in seen_expr_ids {
          if existing == target_expr_id {
            seen = true
            break
          }
        }
        if seen {
          continue
        }
        seen_expr_ids.push(target_expr_id)
        vq_record_indexed_value_break_target(
          target_expr_id, values, value_ids, env, analysis_cache,
        )
      }
      None => ()
    }
  }
}

///|
fn vq_indexed_branch_value_ids(
  instr : TInstr,
  instr_node : VQIndexedInstrNode,
) -> Array[Int] {
  match instr.kind {
    TInstrKind::TBr(_, _) => instr_node.eval_child_ids
    TInstrKind::TBrIf(_, _, values)
    | TInstrKind::TBrTable(_, _, _, values)
    | TInstrKind::TBrOnNull(_, _, values)
    | TInstrKind::TBrOnNonNull(_, _, values)
    | TInstrKind::TBrOnCast(_, _, _, _, _, values)
    | TInstrKind::TBrOnCastFail(_, _, _, _, _, values) => {
      let ids : Array[Int] = []
      for i = 0; i < values.length(); i = i + 1 {
        ids.push(instr_node.eval_child_ids[i])
      }
      ids
    }
    _ => []
  }
}

///|
fn vq_collect_indexed_control_metadata_for_instr(
  instr : TInstr,
  instr_id : Int,
  env : Env,
  analysis_cache : VQAnalysisCache,
  expr_stack : Array[Int],
) -> Unit {
  let instr_node = analysis_cache.indexed_instr_nodes[instr_id]
  match instr.kind {
    TInstrKind::TBr(label, values) =>
      vq_indexed_collect_branch_targets(
        [label],
        values,
        vq_indexed_branch_value_ids(instr, instr_node),
        env,
        analysis_cache,
        expr_stack,
      )
    TInstrKind::TBrIf(label, _, values) =>
      vq_indexed_collect_branch_targets(
        [label],
        values,
        vq_indexed_branch_value_ids(instr, instr_node),
        env,
        analysis_cache,
        expr_stack,
      )
    TInstrKind::TBrTable(labels, default, _, values) =>
      vq_indexed_collect_branch_targets(
        labels + [default],
        values,
        vq_indexed_branch_value_ids(instr, instr_node),
        env,
        analysis_cache,
        expr_stack,
      )
    TInstrKind::TBrOnNull(label, _, values)
    | TInstrKind::TBrOnNonNull(label, _, values)
    | TInstrKind::TBrOnCast(label, _, _, _, _, values)
    | TInstrKind::TBrOnCastFail(label, _, _, _, _, values) =>
      vq_indexed_collect_branch_targets(
        [label],
        values,
        vq_indexed_branch_value_ids(instr, instr_node),
        env,
        analysis_cache,
        expr_stack,
      )
    _ => ()
  }

  let mut child_idx = 0
  for child in eval_children(instr) {
    vq_collect_indexed_control_metadata_for_instr(
      child,
      instr_node.eval_child_ids[child_idx],
      env,
      analysis_cache,
      expr_stack,
    )
    child_idx += 1
  }

  match instr.kind {
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) =>
      match instr_node.body_expr_id {
        Some(body_expr_id) =>
          vq_collect_indexed_control_metadata_for_expr(
            body, body_expr_id, env, analysis_cache, expr_stack,
          )
        None => ()
      }
    TInstrKind::TIf(_, _, then_body, else_body) => {
      match instr_node.then_expr_id {
        Some(then_expr_id) =>
          vq_collect_indexed_control_metadata_for_expr(
            then_body, then_expr_id, env, analysis_cache, expr_stack,
          )
        None => ()
      }
      match (else_body, instr_node.else_expr_id) {
        (Some(other), Some(other_expr_id)) =>
          vq_collect_indexed_control_metadata_for_expr(
            other, other_expr_id, env, analysis_cache, expr_stack,
          )
        _ => ()
      }
    }
    _ => ()
  }
}

///|
fn vq_collect_indexed_control_metadata_for_expr(
  expr : TExpr,
  expr_id : Int,
  env : Env,
  analysis_cache : VQAnalysisCache,
  expr_stack : Array[Int],
) -> Unit {
  expr_stack.push(expr_id)
  let expr_node = analysis_cache.indexed_expr_nodes[expr_id]
  for i = 0; i < expr.instrs.length(); i = i + 1 {
    vq_collect_indexed_control_metadata_for_instr(
      expr.instrs[i],
      expr_node.instr_ids[i],
      env,
      analysis_cache,
      expr_stack,
    )
  }
  ignore(expr_stack.pop())
}

///|
fn vq_finalize_indexed_control_metadata(
  env : Env,
  analysis_cache : VQAnalysisCache,
) -> Unit {
  for expr_node in analysis_cache.indexed_expr_nodes {
    let has_lub = if expr_node.has_unsupported_multivalue_break ||
      expr_node.has_unknown_value_break_type {
      true
    } else if expr_node.value_break_types.is_empty() {
      false
    } else {
      let mut candidate : ValType? = Some(expr_node.value_break_types[0])
      for i = 1; i < expr_node.value_break_types.length(); i = i + 1 {
        match candidate {
          Some(prev) =>
            candidate = vq_common_val_supertype(
              prev,
              expr_node.value_break_types[i],
              env,
            )
          None => ()
        }
      }
      candidate is Some(_)
    }
    expr_node.value_break_lub_depth0 = Some(has_lub)
  }
}

///|
fn vq_populate_indexed_control_metadata(
  expr : TExpr,
  expr_id : Int,
  env : Env,
  analysis_cache : VQAnalysisCache,
) -> Unit {
  let expr_stack : Array[Int] = []
  vq_collect_indexed_control_metadata_for_expr(
    expr, expr_id, env, analysis_cache, expr_stack,
  )
  vq_finalize_indexed_control_metadata(env, analysis_cache)
}

///|
fn vq_instr_has_control_transfer_local(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TBr(_, _)
    | TInstrKind::TBrIf(_, _, _)
    | TInstrKind::TBrTable(_, _, _, _)
    | TInstrKind::TReturn(_)
    | TInstrKind::TReturnCall(_, _)
    | TInstrKind::TReturnCallIndirect(_, _, _, _)
    | TInstrKind::TReturnCallRef(_, _, _)
    | TInstrKind::TThrow(_, _)
    | TInstrKind::TThrowRef(_)
    | TInstrKind::TUnreachable => true
    _ => false
  }
}

///|
fn vq_instr_throws_local(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TThrow(_, _)
    | TInstrKind::TThrowRef(_)
    | TInstrKind::TCall(_, _)
    | TInstrKind::TCallIndirect(_, _, _, _)
    | TInstrKind::TCallRef(_, _, _)
    | TInstrKind::TReturnCall(_, _)
    | TInstrKind::TReturnCallIndirect(_, _, _, _)
    | TInstrKind::TReturnCallRef(_, _, _) => true
    _ => false
  }
}

///|
fn vq_instr_may_not_return_local(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TLoop(_, _)
    | TInstrKind::TCall(_, _)
    | TInstrKind::TCallIndirect(_, _, _, _)
    | TInstrKind::TCallRef(_, _, _)
    | TInstrKind::TReturnCall(_, _)
    | TInstrKind::TReturnCallIndirect(_, _, _, _)
    | TInstrKind::TReturnCallRef(_, _, _) => true
    _ => false
  }
}

///|
fn vq_visit_instr_recursive_children(
  instr : TInstr,
  visit : (TInstr) -> Unit,
) -> Unit {
  for child in eval_children(instr) {
    if child != instr {
      visit(child)
    }
  }
  match instr.kind {
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) =>
      for child in body.instrs {
        visit(child)
      }
    TInstrKind::TIf(_, _, then_body, else_body) => {
      for child in then_body.instrs {
        visit(child)
      }
      match else_body {
        Some(other) =>
          for child in other.instrs {
            visit(child)
          }
        None => ()
      }
    }
    _ => ()
  }
}

///|
fn vq_seed_texpr_facts_bounded(
  expr : TExpr,
  env : Env,
  analysis_cache : VQAnalysisCache,
  budget : Ref[Int],
) -> Bool {
  match
    vq_build_indexed_expr_analysis_bounded(expr, env, analysis_cache, budget) {
    Some(expr_id) => {
      analysis_cache.indexed_root_expr_id = Some(expr_id)
      vq_populate_indexed_control_metadata(expr, expr_id, env, analysis_cache)
      true
    }
    None => false
  }
}

///|
fn vq_same_stack_sig(a : VQStackSig, b : VQStackSig) -> Bool {
  a.required == b.required &&
  a.produced == b.produced &&
  a.reachable == b.reachable
}

///|
fn vq_rewrite_preserves_stack_sig_cached(
  before : TInstr,
  after : TInstr,
  env : Env,
  analysis_cache : VQAnalysisCache,
  before_id? : Int? = None,
) -> Bool {
  let start_us = vacuum_trace_now_us()
  let before_sig = vq_stack_sig_instr_cached(
    before,
    env,
    analysis_cache,
    instr_id=before_id,
  )
  let after_sig = vq_stack_sig_instr_cached(after, env, analysis_cache)
  let out = match (before_sig, after_sig) {
    (Some(before_cached), Some(after_cached)) =>
      if vq_same_stack_sig(before_cached, after_cached) {
        true
      } else {
        match before_id {
          // Indexed stack signatures can be conservative on some transformed
          // control shapes; verify mismatches with direct formulas before
          // rejecting an otherwise safe rewrite.
          Some(_) =>
            match
              (vq_stack_sig_instr(before, env), vq_stack_sig_instr(after, env)) {
              (Some(before_direct), Some(after_direct)) =>
                vq_same_stack_sig(before_direct, after_direct)
              _ => false
            }
          None => false
        }
      }
    _ => true
  }
  ignore(
    vq_commit_helper_timing(
      analysis_cache.stats.rewrite_stack_us,
      analysis_cache.stats.rewrite_stack_calls,
      start_us,
    ),
  )
  out
}

///|
fn vq_drop_stack_sig_from_child_sig(child_sig : VQStackSig) -> VQStackSig {
  vq_stack_sig_pop_push(child_sig, 1, 0)
}

///|
fn vq_drop_rewrite_preserves_stack_sig_from_children(
  before_child : TInstr,
  after_child : TInstr,
  env : Env,
  analysis_cache : VQAnalysisCache,
  before_child_id? : Int? = None,
  after_child_id? : Int? = None,
) -> Bool {
  let before_child_sig = vq_stack_sig_instr_cached(
    before_child,
    env,
    analysis_cache,
    instr_id=before_child_id,
  )
  let after_child_sig = vq_stack_sig_instr_cached(
    after_child,
    env,
    analysis_cache,
    instr_id=after_child_id,
  )
  match (before_child_sig, after_child_sig) {
    (Some(before_sig), Some(after_sig)) =>
      vq_same_stack_sig(
        vq_drop_stack_sig_from_child_sig(before_sig),
        vq_drop_stack_sig_from_child_sig(after_sig),
      )
    _ => true
  }
}

///|
fn vq_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn vq_nonneg_int(i : Int) -> Int {
  if i > 0 {
    i
  } else {
    0
  }
}

///|
fn vq_stack_need_before(effect : VQStackSig, need_after : Int) -> Int {
  if !effect.reachable {
    effect.required
  } else {
    vq_max_int(effect.required, vq_nonneg_int(need_after - effect.produced))
  }
}

///|
fn vq_stack_seq(a : VQStackSig, b : VQStackSig) -> VQStackSig {
  if !a.reachable {
    a
  } else {
    let required = vq_max_int(
      a.required,
      vq_nonneg_int(b.required - a.produced),
    )
    if !b.reachable {
      VQStackSig::new(required, 0, false)
    } else {
      VQStackSig::new(required, a.produced + b.produced, true)
    }
  }
}

///|
fn vq_stack_sig_pop_push(
  child_sig : VQStackSig,
  pop_count : Int,
  push_count : Int,
) -> VQStackSig {
  if !child_sig.reachable {
    child_sig
  } else {
    VQStackSig::new(
      vq_max_int(
        child_sig.required,
        vq_nonneg_int(pop_count - child_sig.produced),
      ),
      child_sig.produced - pop_count + push_count,
      true,
    )
  }
}

///|
fn vq_stack_sig_terminate(
  child_sig : VQStackSig,
  pop_count : Int,
) -> VQStackSig {
  if !child_sig.reachable {
    child_sig
  } else {
    VQStackSig::new(
      vq_max_int(
        child_sig.required,
        vq_nonneg_int(pop_count - child_sig.produced),
      ),
      0,
      false,
    )
  }
}

///|
fn vq_stack_sig_list(items : Array[TInstr], env : Env) -> VQStackSig? {
  let mut acc = VQStackSig::new(0, 0, true)
  for item in items {
    match vq_stack_sig_instr(item, env) {
      Some(sig) => {
        acc = vq_stack_seq(acc, sig)
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
fn vq_stack_sig_list_seeded(
  items : Array[TInstr],
  env : Env,
  analysis_cache : VQAnalysisCache,
) -> VQStackSig? {
  let mut acc = VQStackSig::new(0, 0, true)
  for item in items {
    match vq_stack_sig_instr_seeded(item, env, analysis_cache) {
      Some(sig) => {
        acc = vq_stack_seq(acc, sig)
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
fn vq_stack_sig_if(
  cond_sig : VQStackSig,
  then_sig : VQStackSig,
  else_sig : VQStackSig,
) -> VQStackSig {
  if !cond_sig.reachable {
    return cond_sig
  }
  let branch_required = vq_max_int(then_sig.required, else_sig.required)
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
  VQStackSig::new(
    vq_max_int(
      cond_sig.required,
      vq_nonneg_int(need_after_cond - cond_sig.produced),
    ),
    branch_produced,
    branch_reachable,
  )
}

///|
fn vq_stack_sig_instr_seeded(
  instr : TInstr,
  env : Env,
  analysis_cache : VQAnalysisCache,
) -> VQStackSig? {
  match instr.kind {
    TInstrKind::TNop => Some(VQStackSig::new(0, 0, true))
    TInstrKind::TUnreachable => Some(VQStackSig::new(0, 0, false))
    TInstrKind::TLocalGet(_)
    | TInstrKind::TGlobalGet(_)
    | TInstrKind::TI32Const(_)
    | TInstrKind::TI64Const(_)
    | TInstrKind::TF32Const(_)
    | TInstrKind::TF64Const(_)
    | TInstrKind::TRefNull(_)
    | TInstrKind::TRefFunc(_) => Some(VQStackSig::new(0, 1, true))
    TInstrKind::TDrop(value)
    | TInstrKind::TLocalSet(_, value)
    | TInstrKind::TGlobalSet(_, value) =>
      vq_stack_sig_instr_seeded(value, env, analysis_cache).map(fn(sig) {
        vq_stack_sig_pop_push(sig, 1, 0)
      })
    TInstrKind::TLocalTee(_, value) =>
      vq_stack_sig_instr_seeded(value, env, analysis_cache).map(fn(sig) {
        vq_stack_sig_pop_push(sig, 1, 1)
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
      vq_stack_sig_instr_seeded(value, env, analysis_cache).map(fn(sig) {
        vq_stack_sig_pop_push(sig, 1, 1)
      })
    TInstrKind::TBinary(_, left, right) | TInstrKind::TRefEq(left, right) =>
      vq_stack_sig_list_seeded([left, right], env, analysis_cache).map(fn(sig) {
        vq_stack_sig_pop_push(sig, 2, 1)
      })
    TInstrKind::TStore(_, _, addr, value) =>
      vq_stack_sig_list_seeded([addr, value], env, analysis_cache).map(fn(sig) {
        vq_stack_sig_pop_push(sig, 2, 0)
      })
    TInstrKind::TSelect(_, cond, if_true, if_false) =>
      vq_stack_sig_list_seeded([if_true, if_false, cond], env, analysis_cache).map(fn(
          sig,
        ) {
          vq_stack_sig_pop_push(sig, 3, 1)
        },
      )
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) =>
      vq_stack_sig_list_seeded(body.instrs, env, analysis_cache)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      let else_sig = match else_body {
        Some(other) =>
          vq_stack_sig_list_seeded(other.instrs, env, analysis_cache)
        None => Some(VQStackSig::new(0, 0, true))
      }
      match
        (
          vq_stack_sig_instr_seeded(cond, env, analysis_cache),
          vq_stack_sig_list_seeded(then_body.instrs, env, analysis_cache),
          else_sig,
        ) {
        (Some(cond_sig), Some(then_sig), Some(other_sig)) =>
          Some(vq_stack_sig_if(cond_sig, then_sig, other_sig))
        _ => None
      }
    }
    TInstrKind::TCall(func_idx, args) =>
      match
        (
          vq_stack_sig_list_seeded(args, env, analysis_cache),
          env.get_functype_by_funcidx(func_idx),
        ) {
        (Some(sig), Some(FuncType(params, results))) =>
          Some(vq_stack_sig_pop_push(sig, params.length(), results.length()))
        _ => None
      }
    TInstrKind::TCallIndirect(type_idx, _, args, callee)
    | TInstrKind::TCallRef(type_idx, args, callee) =>
      match
        (
          vq_stack_sig_list_seeded(args + [callee], env, analysis_cache),
          env.resolve_functype(type_idx),
        ) {
        (Some(sig), Some(FuncType(params, results))) =>
          Some(
            vq_stack_sig_pop_push(sig, params.length() + 1, results.length()),
          )
        _ => None
      }
    TInstrKind::TReturn(values) | TInstrKind::TThrow(_, values) =>
      vq_stack_sig_list_seeded(values, env, analysis_cache).map(fn(sig) {
        vq_stack_sig_terminate(sig, 0)
      })
    TInstrKind::TThrowRef(value) =>
      vq_stack_sig_instr_seeded(value, env, analysis_cache).map(fn(sig) {
        vq_stack_sig_terminate(sig, 1)
      })
    TInstrKind::TBr(_, values) =>
      vq_stack_sig_list_seeded(values, env, analysis_cache).map(fn(sig) {
        vq_stack_sig_terminate(sig, 0)
      })
    TInstrKind::TBrIf(_, cond, values) =>
      vq_stack_sig_list_seeded(values + [cond], env, analysis_cache).map(fn(
        sig,
      ) {
        vq_stack_sig_pop_push(sig, 1, 0)
      })
    TInstrKind::TBrTable(_, _, index, values) =>
      vq_stack_sig_list_seeded(values + [index], env, analysis_cache).map(fn(
        sig,
      ) {
        vq_stack_sig_terminate(sig, 1)
      })
    TInstrKind::TReturnCall(func_idx, args) =>
      match
        (
          vq_stack_sig_list_seeded(args, env, analysis_cache),
          env.get_functype_by_funcidx(func_idx),
        ) {
        (Some(sig), Some(FuncType(params, _))) =>
          Some(vq_stack_sig_terminate(sig, params.length()))
        _ => None
      }
    TInstrKind::TReturnCallIndirect(type_idx, _, args, callee)
    | TInstrKind::TReturnCallRef(type_idx, args, callee) =>
      match
        (
          vq_stack_sig_list_seeded(args + [callee], env, analysis_cache),
          env.resolve_functype(type_idx),
        ) {
        (Some(sig), Some(FuncType(params, _))) =>
          Some(vq_stack_sig_terminate(sig, params.length() + 1))
        _ => None
      }
    _ => None
  }
}

///|
fn vq_stack_sig_instr(instr : TInstr, env : Env) -> VQStackSig? {
  match instr.kind {
    TInstrKind::TNop => Some(VQStackSig::new(0, 0, true))
    TInstrKind::TUnreachable => Some(VQStackSig::new(0, 0, false))
    TInstrKind::TLocalGet(_)
    | TInstrKind::TGlobalGet(_)
    | TInstrKind::TI32Const(_)
    | TInstrKind::TI64Const(_)
    | TInstrKind::TF32Const(_)
    | TInstrKind::TF64Const(_)
    | TInstrKind::TRefNull(_)
    | TInstrKind::TRefFunc(_) => Some(VQStackSig::new(0, 1, true))
    TInstrKind::TDrop(value)
    | TInstrKind::TLocalSet(_, value)
    | TInstrKind::TGlobalSet(_, value) =>
      vq_stack_sig_instr(value, env).map(fn(sig) {
        vq_stack_sig_pop_push(sig, 1, 0)
      })
    TInstrKind::TLocalTee(_, value) =>
      vq_stack_sig_instr(value, env).map(fn(sig) {
        vq_stack_sig_pop_push(sig, 1, 1)
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
      vq_stack_sig_instr(value, env).map(fn(sig) {
        vq_stack_sig_pop_push(sig, 1, 1)
      })
    TInstrKind::TBinary(_, left, right) | TInstrKind::TRefEq(left, right) =>
      vq_stack_sig_list([left, right], env).map(fn(sig) {
        vq_stack_sig_pop_push(sig, 2, 1)
      })
    TInstrKind::TStore(_, _, addr, value) =>
      vq_stack_sig_list([addr, value], env).map(fn(sig) {
        vq_stack_sig_pop_push(sig, 2, 0)
      })
    TInstrKind::TSelect(_, cond, if_true, if_false) =>
      vq_stack_sig_list([if_true, if_false, cond], env).map(fn(sig) {
        vq_stack_sig_pop_push(sig, 3, 1)
      })
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) => vq_stack_sig_list(body.instrs, env)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      let else_sig = match else_body {
        Some(other) => vq_stack_sig_list(other.instrs, env)
        None => Some(VQStackSig::new(0, 0, true))
      }
      match
        (
          vq_stack_sig_instr(cond, env),
          vq_stack_sig_list(then_body.instrs, env),
          else_sig,
        ) {
        (Some(cond_sig), Some(then_sig), Some(other_sig)) =>
          Some(vq_stack_sig_if(cond_sig, then_sig, other_sig))
        _ => None
      }
    }
    TInstrKind::TCall(func_idx, args) =>
      match
        (vq_stack_sig_list(args, env), env.get_functype_by_funcidx(func_idx)) {
        (Some(sig), Some(FuncType(params, results))) =>
          Some(vq_stack_sig_pop_push(sig, params.length(), results.length()))
        _ => None
      }
    TInstrKind::TCallIndirect(type_idx, _, args, callee)
    | TInstrKind::TCallRef(type_idx, args, callee) =>
      match
        (
          vq_stack_sig_list(args + [callee], env),
          env.resolve_functype(type_idx),
        ) {
        (Some(sig), Some(FuncType(params, results))) =>
          Some(
            vq_stack_sig_pop_push(sig, params.length() + 1, results.length()),
          )
        _ => None
      }
    TInstrKind::TReturn(values) | TInstrKind::TThrow(_, values) =>
      vq_stack_sig_list(values, env).map(fn(sig) {
        vq_stack_sig_terminate(sig, 0)
      })
    TInstrKind::TThrowRef(value) =>
      vq_stack_sig_instr(value, env).map(fn(sig) {
        vq_stack_sig_terminate(sig, 1)
      })
    TInstrKind::TBr(_, values) =>
      vq_stack_sig_list(values, env).map(fn(sig) {
        vq_stack_sig_terminate(sig, 0)
      })
    TInstrKind::TBrIf(_, cond, values) =>
      vq_stack_sig_list(values + [cond], env).map(fn(sig) {
        vq_stack_sig_pop_push(sig, 1, 0)
      })
    TInstrKind::TBrTable(_, _, index, values) =>
      vq_stack_sig_list(values + [index], env).map(fn(sig) {
        vq_stack_sig_terminate(sig, 1)
      })
    TInstrKind::TReturnCall(func_idx, args) =>
      match
        (vq_stack_sig_list(args, env), env.get_functype_by_funcidx(func_idx)) {
        (Some(sig), Some(FuncType(params, _))) =>
          Some(vq_stack_sig_terminate(sig, params.length()))
        _ => None
      }
    TInstrKind::TReturnCallIndirect(type_idx, _, args, callee)
    | TInstrKind::TReturnCallRef(type_idx, args, callee) =>
      match
        (
          vq_stack_sig_list(args + [callee], env),
          env.resolve_functype(type_idx),
        ) {
        (Some(sig), Some(FuncType(params, _))) =>
          Some(vq_stack_sig_terminate(sig, params.length() + 1))
        _ => None
      }
    _ => None
  }
}

///|
fn vq_stack_sig_instr_cached(
  instr : TInstr,
  env : Env,
  analysis_cache : VQAnalysisCache,
  instr_id? : Int? = None,
) -> VQStackSig? {
  analysis_cache.stats.stack_sig_calls.val += 1
  match vq_indexed_instr_node(analysis_cache, instr_id) {
    Some(node) => {
      analysis_cache.stats.stack_sig_cache_hits.val += 1
      return node.stack_sig
    }
    None => ()
  }
  analysis_cache.stats.stack_sig_cache_misses.val += 1
  vq_stack_sig_instr_seeded(instr, env, analysis_cache)
}

///|
fn vq_texpr_has_control_transfer_cached(
  expr : TExpr,
  analysis_cache : VQAnalysisCache,
  expr_id? : Int? = None,
) -> Bool {
  match vq_indexed_expr_node(analysis_cache, expr_id) {
    Some(node) => {
      analysis_cache.stats.control_transfer_cache_hits.val += 1
      return node.has_control_transfer
    }
    None => ()
  }
  analysis_cache.stats.control_transfer_cache_misses.val += 1
  analysis_cache.stats.control_transfer_scans.val += 1
  vq_texpr_has_control_transfer(expr)
}

///|
fn vq_required_prefixes(
  items : Array[TInstr],
  env : Env,
  terminal_need : Int,
  analysis_cache : VQAnalysisCache,
  item_ids? : Array[Int]? = None,
) -> Array[Int?] {
  let size = items.length()
  let needs : Array[Int?] = []
  for _ in 0..<=size {
    needs.push(None)
  }
  needs[size] = Some(terminal_need)
  if size == 0 {
    return needs
  }
  for i = size - 1; i >= 0; i = i - 1 {
    let item_id = match item_ids {
      Some(ids) => ids.get(i)
      None => None
    }
    match
      (
        vq_stack_sig_instr_cached(
          items[i],
          env,
          analysis_cache,
          instr_id=item_id,
        ),
        needs[i + 1],
      ) {
      (Some(sig), Some(need_after)) =>
        needs[i] = Some(vq_stack_need_before(sig, need_after))
      _ => needs[i] = None
    }
  }
  needs
}

///|
fn vq_has_ambient_stack_terminator(items : Array[TInstr]) -> Bool {
  for item in items {
    match item.kind {
      TInstrKind::TBr(_, _)
      | TInstrKind::TBrIf(_, _, _)
      | TInstrKind::TBrTable(_, _, _, _)
      | TInstrKind::TReturn(_)
      | TInstrKind::TThrow(_, _)
      | TInstrKind::TThrowRef(_) => return true
      _ => ()
    }
  }
  false
}

///|
fn vq_optimize_sequence(
  items : Array[TInstr],
  env : Env,
  result_types : Array[ValType],
  result_used : Bool,
  budget : Ref[Int],
  analysis_cache : VQAnalysisCache,
  pass_options : VQPassOptions,
  expr_id? : Int? = None,
) -> VQSequenceResult {
  let out : Array[TInstr] = []
  let mut changed = false
  let mut preserve_next_unreachable = false
  let size = items.length()
  let multi_value_results = result_types.length() > 1
  let has_ambient_stack_terminator = vq_has_ambient_stack_terminator(items)
  let mut has_sequence_control_transfer_opt : Bool? = None
  let mut prefix_needs_opt : Array[Int?]? = None
  let expr_node = vq_indexed_expr_node(analysis_cache, expr_id)
  for i = 0; i < size; i = i + 1 {
    if budget.val <= 0 {
      match analysis_cache.midpass_degraded_budget {
        Some(fallback_budget) => {
          analysis_cache.stats.tier_fallback_calls.val += 1
          let remaining : Array[TInstr] = []
          for j = i; j < size; j = j + 1 {
            remaining.push(items[j])
          }
          let fallback_sequence = vq_optimize_sequence_degraded(
            remaining, env, result_types, result_used, fallback_budget, analysis_cache,
            pass_options,
          )
          if fallback_sequence.changed {
            analysis_cache.stats.tier_fallback_changes.val += 1
            changed = true
          }
          for item in fallback_sequence.items {
            out.push(item)
          }
          break
        }
        None => ()
      }
    }
    let child = items[i]
    let child_id = vq_indexed_expr_instr_id(expr_node, i)
    if preserve_next_unreachable {
      preserve_next_unreachable = false
      if vq_is_explicit_unreachable_instr(child) {
        out.push(child)
        if i + 1 < size {
          changed = true
        }
        break
      }
    }
    let keeps_sequence_result = i == size - 1 && result_types.length() > 0
    let used = if multi_value_results {
      true
    } else {
      i == size - 1 && result_used
    }
    let mut optimized = vq_process_instr(
      child,
      env,
      used,
      true,
      budget,
      analysis_cache,
      pass_options,
      instr_id=child_id,
    )
    if optimized is None {
      if multi_value_results {
        optimized = Some(child)
      } else if keeps_sequence_result {
        match result_types {
          [vt] =>
            match af_make_zero(vt) {
              Some(zero) => optimized = Some(zero)
              None => optimized = Some(child)
            }
          _ => ()
        }
      } else if is_unreachable_instr(child) {
        optimized = Some(child)
      }
    }
    match optimized {
      None =>
        if has_ambient_stack_terminator {
          match
            (
              vq_type_of_cached(child, env, analysis_cache, instr_id=child_id),
              vq_stack_sig_instr_cached(
                child,
                env,
                analysis_cache,
                instr_id=child_id,
              ),
            ) {
            (Some(_), _) => out.push(child)
            (_, Some(sig)) if !sig.reachable => out.push(child)
            _ => changed = true
          }
        } else {
          let prefix_needs = match prefix_needs_opt {
            Some(cached) => cached
            None => {
              let computed = vq_required_prefixes(
                items,
                env,
                if result_used {
                  result_types.length()
                } else {
                  0
                },
                analysis_cache,
                item_ids=match expr_node {
                  Some(node) => Some(node.instr_ids)
                  None => None
                },
              )
              prefix_needs_opt = Some(computed)
              computed
            }
          }
          match
            (
              vq_stack_sig_instr_cached(
                child,
                env,
                analysis_cache,
                instr_id=child_id,
              ),
              prefix_needs[i],
              prefix_needs[i + 1],
            ) {
            (Some(sig), Some(need_before), Some(need_after)) =>
              if !sig.reachable || need_before < need_after {
                out.push(child)
              } else {
                changed = true
              }
            _ =>
              match
                (
                  vq_type_of_cached(
                    child,
                    env,
                    analysis_cache,
                    instr_id=child_id,
                  ),
                  vq_stack_sig_instr_cached(
                    child,
                    env,
                    analysis_cache,
                    instr_id=child_id,
                  ),
                ) {
                (Some(_), _) => out.push(child)
                (_, Some(sig)) if !sig.reachable => out.push(child)
                _ => changed = true
              }
          }
        }
      Some(next) => {
        if next != child {
          let has_sequence_control_transfer = match
            has_sequence_control_transfer_opt {
            Some(cached) => cached
            None => {
              let mut computed = has_ambient_stack_terminator
              if !computed {
                for j = 0; j < items.length(); j = j + 1 {
                  if vq_instr_has_control_transfer_cached(
                      items[j],
                      analysis_cache,
                      instr_id=vq_indexed_expr_instr_id(expr_node, j),
                    ) {
                    computed = true
                    break
                  }
                }
              }
              has_sequence_control_transfer_opt = Some(computed)
              computed
            }
          }
          if has_sequence_control_transfer &&
            child.kind is TInstrKind::TDrop(_) &&
            next.kind is TInstrKind::TNop {
            out.push(child)
            continue
          }
          if has_ambient_stack_terminator {
            let mut preserves_stack_shape = true
            match
              (
                vq_stack_sig_instr_cached(
                  child,
                  env,
                  analysis_cache,
                  instr_id=child_id,
                ),
                vq_stack_sig_instr_cached(next, env, analysis_cache),
              ) {
              (Some(before), Some(after)) =>
                if !vq_same_stack_sig(before, after) {
                  preserves_stack_shape = false
                }
              _ => ()
            }
            let preserves_type = vq_same_type(
              vq_type_of_cached(child, env, analysis_cache, instr_id=child_id),
              vq_type_of_cached(next, env, analysis_cache),
            )
            if !preserves_stack_shape || !preserves_type {
              out.push(child)
              continue
            }
          }
          changed = true
        }
        out.push(next)
        if is_unreachable_instr(next) {
          if i + 1 < size && vq_is_explicit_unreachable_instr(items[i + 1]) {
            preserve_next_unreachable = true
            continue
          }
          if i + 1 < size {
            changed = true
          }
          break
        }
      }
    }
  }
  VQSequenceResult::new(out, changed)
}

///|
fn vq_optimize_texpr(
  expr : TExpr,
  env : Env,
  result_types : Array[ValType],
  result_used : Bool,
  budget : Ref[Int],
  analysis_cache : VQAnalysisCache,
  pass_options : VQPassOptions,
  expr_id? : Int? = None,
) -> TExpr {
  let { instrs: items, .. } = expr
  let sequence = vq_optimize_sequence(
    items,
    env,
    result_types,
    result_used,
    budget,
    analysis_cache,
    pass_options,
    expr_id~,
  )
  if sequence.changed {
    TExpr::new(sequence.items)
  } else {
    expr
  }
}

///|
fn vq_simplify_block_to_contents(
  bt : BlockType,
  body : TExpr,
  env : Env,
  analysis_cache : VQAnalysisCache,
  expr_id? : Int? = None,
) -> TInstr {
  let start_us = vacuum_trace_now_us()
  let result_types = vq_block_result_types(bt, env)
  let { instrs: items, .. } = body
  if items.length() == 0 {
    if !result_types.is_empty() {
      let out = TInstr::block(bt, body)
      ignore(
        vq_commit_helper_timing(
          analysis_cache.stats.simplify_block_us,
          analysis_cache.stats.simplify_block_calls,
          start_us,
        ),
      )
      return out
    }
    let out = TInstr::nop()
    ignore(
      vq_commit_helper_timing(
        analysis_cache.stats.simplify_block_us,
        analysis_cache.stats.simplify_block_calls,
        start_us,
      ),
    )
    return out
  }
  if items.length() != 1 {
    let out = TInstr::block(bt, body)
    ignore(
      vq_commit_helper_timing(
        analysis_cache.stats.simplify_block_us,
        analysis_cache.stats.simplify_block_calls,
        start_us,
      ),
    )
    return out
  }
  let only = items[0]
  let only_id = vq_only_original_instr_id(body, analysis_cache, expr_id~)
  let only_rebase_label_score = match
    vq_indexed_instr_node(analysis_cache, only_id) {
    Some(node) => Some(node.max_rebase_label_score)
    None => Some(vq_instr_rebase_label_score_timed(only, analysis_cache.stats))
  }
  if vq_has_break_to_depth0_cached(
      body,
      analysis_cache,
      expr_id~,
      single_instr_rebase_label_score=only_rebase_label_score,
    ) {
    let out = TInstr::block(bt, body)
    ignore(
      vq_commit_helper_timing(
        analysis_cache.stats.simplify_block_us,
        analysis_cache.stats.simplify_block_calls,
        start_us,
      ),
    )
    return out
  }
  match result_types {
    [vt] =>
      match vq_type_of_cached(only, env, analysis_cache, instr_id=only_id) {
        Some(t) if t == vt => {
          let out = vq_rebase_labels_for_collapsed_wrapper_if_needed(
            only,
            analysis_cache,
            instr_id=only_id,
            rebase_label_score=only_rebase_label_score,
          )
          ignore(
            vq_commit_helper_timing(
              analysis_cache.stats.simplify_block_us,
              analysis_cache.stats.simplify_block_calls,
              start_us,
            ),
          )
          return out
        }
        _ => ()
      }
    [] =>
      if vq_type_of_cached(only, env, analysis_cache, instr_id=only_id) is None ||
        is_unreachable_instr(only) {
        let out = vq_rebase_labels_for_collapsed_wrapper_if_needed(
          only,
          analysis_cache,
          instr_id=only_id,
          rebase_label_score=only_rebase_label_score,
        )
        ignore(
          vq_commit_helper_timing(
            analysis_cache.stats.simplify_block_us,
            analysis_cache.stats.simplify_block_calls,
            start_us,
          ),
        )
        return out
      }
    _ =>
      if is_unreachable_instr(only) {
        let out = vq_rebase_labels_for_collapsed_wrapper_if_needed(
          only,
          analysis_cache,
          instr_id=only_id,
          rebase_label_score=only_rebase_label_score,
        )
        ignore(
          vq_commit_helper_timing(
            analysis_cache.stats.simplify_block_us,
            analysis_cache.stats.simplify_block_calls,
            start_us,
          ),
        )
        return out
      }
  }
  let out = TInstr::block(bt, body)
  ignore(
    vq_commit_helper_timing(
      analysis_cache.stats.simplify_block_us,
      analysis_cache.stats.simplify_block_calls,
      start_us,
    ),
  )
  out
}

///|
fn vq_texpr_throws(expr : TExpr) -> Bool {
  for instr in expr.instrs {
    if vq_instr_throws(instr) {
      return true
    }
  }
  false
}

///|
fn vq_texpr_throws_cached(
  expr : TExpr,
  analysis_cache : VQAnalysisCache,
  expr_id? : Int? = None,
) -> Bool {
  match vq_indexed_expr_node(analysis_cache, expr_id) {
    Some(node) => return node.throws
    None => ()
  }
  vq_texpr_throws(expr)
}

///|
fn vq_instr_throws(instr : TInstr) -> Bool {
  if vq_instr_throws_local(instr) {
    return true
  }
  let found = Ref::new(false)
  vq_visit_instr_recursive_children(instr, fn(child) {
    if !found.val && vq_instr_throws(child) {
      found.val = true
    }
  })
  if found.val {
    return true
  }
  false
}

///|
fn vq_instr_has_any_labelidx_local(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TBr(_, _)
    | TInstrKind::TBrIf(_, _, _)
    | TInstrKind::TBrTable(_, _, _, _)
    | TInstrKind::TBrOnNull(_, _, _)
    | TInstrKind::TBrOnNonNull(_, _, _)
    | TInstrKind::TBrOnCast(_, _, _, _, _, _)
    | TInstrKind::TBrOnCastFail(_, _, _, _, _, _) => true
    TInstrKind::TTryTable(_, catches, _) => !catches.is_empty()
    _ => false
  }
}

///|
fn vq_instr_has_any_labelidx(instr : TInstr) -> Bool {
  if vq_instr_has_any_labelidx_local(instr) {
    return true
  }
  let found = Ref::new(false)
  vq_visit_instr_recursive_children(instr, fn(child) {
    if !found.val && vq_instr_has_any_labelidx(child) {
      found.val = true
    }
  })
  found.val
}

///|
fn vq_texpr_has_control_transfer(expr : TExpr) -> Bool {
  for instr in expr.instrs {
    if vq_instr_has_control_transfer(instr) {
      return true
    }
  }
  false
}

///|
fn vq_texpr_has_unremovable_side_effects(
  expr : TExpr,
  analysis_cache : VQAnalysisCache,
) -> Bool {
  let { instrs: items, .. } = expr
  for item in items {
    if vq_has_unremovable_effects_cached(item, analysis_cache) {
      return true
    }
  }
  false
}

///|
fn vq_process_child_preserving_stack_sig(
  child : TInstr,
  env : Env,
  budget : Ref[Int],
  analysis_cache : VQAnalysisCache,
  pass_options : VQPassOptions,
  child_id? : Int? = None,
) -> TInstr {
  let next_child = match
    vq_process_instr(
      child,
      env,
      true,
      true,
      budget,
      analysis_cache,
      pass_options,
      instr_id=child_id,
    ) {
    Some(next) => next
    None => return child
  }
  if next_child == child {
    return child
  }
  match
    (
      vq_stack_sig_instr_cached(child, env, analysis_cache, instr_id=child_id),
      vq_stack_sig_instr_cached(next_child, env, analysis_cache),
    ) {
    (Some(before), Some(after)) if vq_same_stack_sig(before, after) =>
      next_child
    _ => child
  }
}

///|
fn vq_is_single_explicit_unreachable_texpr(expr : TExpr) -> Bool {
  match expr.instrs {
    [{ kind: TInstrKind::TUnreachable, .. }] => true
    _ => false
  }
}

///|
fn vq_instr_has_control_transfer(instr : TInstr) -> Bool {
  if vq_instr_has_control_transfer_local(instr) {
    return true
  }
  let found = Ref::new(false)
  vq_visit_instr_recursive_children(instr, fn(child) {
    if !found.val && vq_instr_has_control_transfer(child) {
      found.val = true
    }
  })
  if found.val {
    return true
  }
  false
}

///|
fn vq_instr_may_not_return(instr : TInstr) -> Bool {
  if vq_instr_may_not_return_local(instr) {
    return true
  }
  let found = Ref::new(false)
  vq_visit_instr_recursive_children(instr, fn(child) {
    if !found.val && vq_instr_may_not_return(child) {
      found.val = true
    }
  })
  if found.val {
    return true
  }
  false
}

///|
fn vq_instr_may_not_return_cached(
  instr : TInstr,
  analysis_cache : VQAnalysisCache,
  instr_id? : Int? = None,
) -> Bool {
  match vq_indexed_instr_node(analysis_cache, instr_id) {
    Some(node) => return node.may_not_return
    None => ()
  }
  vq_instr_may_not_return(instr)
}

///|
fn vq_tnh_cleanup_block_items(
  items : Array[TInstr],
  env : Env,
  analysis_cache : VQAnalysisCache,
) -> VQSequenceResult {
  if items.length() < 2 {
    return VQSequenceResult::new(items, false)
  }
  let next_items = items.copy()
  let mut changed = false
  let mut heading_to_explicit_trap = false
  for i = next_items.length() - 1; i >= 0; i = i - 1 {
    let curr = next_items[i]
    if vq_is_explicit_unreachable_instr(curr) {
      heading_to_explicit_trap = true
      continue
    }
    if !heading_to_explicit_trap {
      continue
    }
    if vq_instr_effect_transfers_control_flow_cached(curr, analysis_cache) ||
      vq_instr_has_calls_cached(curr, analysis_cache) ||
      vq_instr_may_not_return_cached(curr, analysis_cache) {
      heading_to_explicit_trap = false
      continue
    }
    match vq_stack_sig_instr_cached(curr, env, analysis_cache) {
      Some(sig) if sig.required == 0 && sig.produced == 0 => {
        next_items[i] = TInstr::nop()
        changed = true
      }
      _ => heading_to_explicit_trap = false
    }
  }
  VQSequenceResult::new(next_items, changed)
}

///|
fn vq_texpr_has_explicit_unreachable(expr : TExpr) -> Bool {
  for instr in expr.instrs {
    if vq_instr_has_explicit_unreachable(instr) {
      return true
    }
  }
  false
}

///|
fn vq_texpr_has_explicit_unreachable_cached(
  expr : TExpr,
  analysis_cache : VQAnalysisCache,
  expr_id? : Int? = None,
) -> Bool {
  match vq_indexed_expr_node(analysis_cache, expr_id) {
    Some(node) => return node.explicit_unreachable
    None => ()
  }
  vq_texpr_has_explicit_unreachable(expr)
}

///|
fn vq_instr_has_explicit_unreachable(instr : TInstr) -> Bool {
  if vq_is_explicit_unreachable_instr(instr) {
    return true
  }
  let found = Ref::new(false)
  vq_visit_instr_recursive_children(instr, fn(child) {
    if !found.val && vq_instr_has_explicit_unreachable(child) {
      found.val = true
    }
  })
  if found.val {
    return true
  }
  false
}

///|
fn vq_sequence_to_instr(items : Array[TInstr]) -> TInstr {
  match items {
    [single] => single
    _ => TInstr::block(BlockType::void_(), TExpr::new(items))
  }
}

///|
fn vq_instr_has_eval_children(instr : TInstr) -> Bool {
  for _ in eval_children(instr) {
    return true
  }
  false
}

///|
fn vq_degraded_can_remove_unused_instr(
  instr : TInstr,
  analysis_cache : VQAnalysisCache,
) -> Bool {
  match instr.kind {
    TInstrKind::TBlock(_, _)
    | TInstrKind::TLoop(_, _)
    | TInstrKind::TIf(_, _, _, _)
    | TInstrKind::TTryTable(_, _, _) => false
    _ =>
      !is_unreachable_instr(instr) &&
      !vq_instr_has_eval_children(instr) &&
      !vq_has_unremovable_shallow_effects_cached(instr, analysis_cache)
  }
}

///|
fn vq_optimize_sequence_degraded(
  items : Array[TInstr],
  env : Env,
  result_types : Array[ValType],
  result_used : Bool,
  budget : Ref[Int],
  analysis_cache : VQAnalysisCache,
  pass_options : VQPassOptions,
) -> VQSequenceResult {
  let out : Array[TInstr] = []
  let mut changed = false
  let size = items.length()
  let multi_value_results = result_types.length() > 1
  for i = 0; i < size; i = i + 1 {
    let child = items[i]
    let keeps_sequence_result = i == size - 1 && result_types.length() > 0
    let used = if multi_value_results {
      true
    } else {
      i == size - 1 && result_used
    }
    let mut optimized = vq_process_instr_degraded(
      child, env, used, budget, analysis_cache, pass_options,
    )
    if optimized is None {
      if multi_value_results ||
        keeps_sequence_result ||
        is_unreachable_instr(child) {
        optimized = Some(child)
      }
    }
    match optimized {
      Some(next) => {
        if next != child {
          changed = true
        }
        out.push(next)
        if is_unreachable_instr(next) {
          if i + 1 < size {
            changed = true
          }
          break
        }
      }
      None => changed = true
    }
  }
  VQSequenceResult::new(out, changed)
}

///|
fn vq_optimize_texpr_degraded(
  expr : TExpr,
  env : Env,
  result_types : Array[ValType],
  result_used : Bool,
  budget : Ref[Int],
  analysis_cache : VQAnalysisCache,
  pass_options : VQPassOptions,
) -> TExpr {
  let { instrs: items, .. } = expr
  let sequence = vq_optimize_sequence_degraded(
    items, env, result_types, result_used, budget, analysis_cache, pass_options,
  )
  TExpr::new(sequence.items)
}

///|
fn vq_degraded_fold_constant_if(
  bt : BlockType,
  arm_result_types : Array[ValType],
  chosen_body : TExpr,
) -> TInstr {
  if arm_result_types.is_empty() && vq_is_nop_texpr(chosen_body) {
    TInstr::nop()
  } else {
    // Keep a block wrapper so depth-0 branches inside the chosen arm still
    // target the original if-equivalent label in degraded mode.
    TInstr::block(bt, chosen_body)
  }
}

///|
fn vq_degraded_sequence_dropped_values(
  values : Array[TInstr],
  analysis_cache : VQAnalysisCache,
) -> TInstr {
  let kept : Array[TInstr] = []
  for value in values {
    let next = vq_degraded_simplify_drop_value(value, analysis_cache)
    if next.kind is TInstrKind::TNop {
      continue
    }
    kept.push(next)
  }
  match kept {
    [] => TInstr::nop()
    _ => vq_sequence_to_instr(kept)
  }
}

///|
fn vq_degraded_binary_is_non_trapping(op : BinaryOp) -> Bool {
  match op {
    I32DivSOp
    | I32DivUOp
    | I32RemSOp
    | I32RemUOp
    | I64DivSOp
    | I64DivUOp
    | I64RemSOp
    | I64RemUOp => false
    _ => true
  }
}

///|
fn vq_degraded_simplify_drop_value(
  value : TInstr,
  analysis_cache : VQAnalysisCache,
) -> TInstr {
  match value.kind {
    TInstrKind::TDrop(inner) =>
      vq_degraded_simplify_drop_value(inner, analysis_cache)
    // Numeric unary wrappers, ref.is_null, ref.i31, ref.get_desc, the i31
    // projections, and the GC extern/any reference conversions are pure 1-to-1
    // stack shuffles; ref.test predicates and SIMD splats/extract_lane wrappers
    // are total child-only wrappers; non-trapping binary ops and ref.eq are
    // pure non-trapping computations. When their result is immediately dropped
    // we can peel them cheaply in degraded mode while preserving child
    // evaluation order.
    TInstrKind::TUnary(_, inner) =>
      vq_degraded_simplify_drop_value(inner, analysis_cache)
    TInstrKind::TRefIsNull(inner) =>
      vq_degraded_simplify_drop_value(inner, analysis_cache)
    TInstrKind::TRefI31(inner) =>
      vq_degraded_simplify_drop_value(inner, analysis_cache)
    TInstrKind::TRefGetDesc(inner) =>
      vq_degraded_simplify_drop_value(inner, analysis_cache)
    TInstrKind::TI31GetS(inner) =>
      vq_degraded_simplify_drop_value(inner, analysis_cache)
    TInstrKind::TI31GetU(inner) =>
      vq_degraded_simplify_drop_value(inner, analysis_cache)
    TInstrKind::TRefTest(_, _, inner) =>
      vq_degraded_simplify_drop_value(inner, analysis_cache)
    TInstrKind::TRefTestDesc(_, _, inner) =>
      vq_degraded_simplify_drop_value(inner, analysis_cache)
    TInstrKind::TAnyConvertExtern(inner) =>
      vq_degraded_simplify_drop_value(inner, analysis_cache)
    TInstrKind::TExternConvertAny(inner) =>
      vq_degraded_simplify_drop_value(inner, analysis_cache)
    TInstrKind::TI8x16Splat(inner)
    | TInstrKind::TI16x8Splat(inner)
    | TInstrKind::TI32x4Splat(inner)
    | TInstrKind::TI64x2Splat(inner)
    | TInstrKind::TF32x4Splat(inner)
    | TInstrKind::TF64x2Splat(inner) =>
      vq_degraded_simplify_drop_value(inner, analysis_cache)
    TInstrKind::TBinary(op, left, right) =>
      if vq_degraded_binary_is_non_trapping(op) {
        vq_degraded_sequence_dropped_values([left, right], analysis_cache)
      } else {
        TInstr::drop(value)
      }
    TInstrKind::TRefEq(left, right) =>
      vq_degraded_sequence_dropped_values([left, right], analysis_cache)
    TInstrKind::TSelect(_, cond, if_true, if_false) =>
      vq_degraded_sequence_dropped_values(
        [if_true, if_false, cond],
        analysis_cache,
      )
    TInstrKind::TExtractLane(_, _, inner) =>
      vq_degraded_simplify_drop_value(inner, analysis_cache)
    TInstrKind::TLocalTee(idx, inner) => TInstr::local_set(idx, inner)
    _ if vq_degraded_can_remove_unused_instr(value, analysis_cache) =>
      TInstr::nop()
    _ => TInstr::drop(value)
  }
}

///|
fn vq_degraded_rebuild_if_without_else(
  bt : BlockType,
  condition : TInstr,
  then_body : TExpr,
  env : Env,
  analysis_cache : VQAnalysisCache,
) -> TInstr {
  if vq_is_nop_texpr(then_body) {
    match vq_type_of_cached(condition, env, analysis_cache) {
      Some(_) => vq_degraded_simplify_drop_value(condition, analysis_cache)
      None => TInstr::if_(bt, condition, then_body, None)
    }
  } else {
    TInstr::if_(bt, condition, then_body, None)
  }
}

///|
fn vq_process_instr_degraded(
  instr : TInstr,
  env : Env,
  result_used : Bool,
  budget : Ref[Int],
  analysis_cache : VQAnalysisCache,
  pass_options : VQPassOptions,
) -> TInstr? {
  if !vq_take_budget(budget) {
    return Some(instr)
  }
  match instr.kind {
    TInstrKind::TBlock(bt, body) => {
      let result_types = vq_block_result_types(bt, env)
      let next_body = vq_optimize_texpr_degraded(
        body,
        env,
        result_types,
        !result_types.is_empty(),
        budget,
        analysis_cache,
        pass_options,
      )
      if result_types.is_empty() && vq_is_nop_texpr(next_body) {
        Some(TInstr::nop())
      } else {
        Some(TInstr::block(bt, next_body))
      }
    }
    TInstrKind::TIf(bt, condition, then_body, else_body) => {
      let next_condition = match
        vq_process_instr_degraded(
          condition, env, true, budget, analysis_cache, pass_options,
        ) {
        Some(next) => next
        None => condition
      }
      let arm_result_types = vq_block_result_types(bt, env)
      let next_then = vq_optimize_texpr_degraded(
        then_body,
        env,
        arm_result_types,
        !arm_result_types.is_empty(),
        budget,
        analysis_cache,
        pass_options,
      )
      let next_else = match else_body {
        Some(other) =>
          Some(
            vq_optimize_texpr_degraded(
              other,
              env,
              arm_result_types,
              !arm_result_types.is_empty(),
              budget,
              analysis_cache,
              pass_options,
            ),
          )
        None => None
      }

      match next_condition.kind {
        TInstrKind::TI32Const(I32(v)) =>
          if v != 0 {
            return Some(
              vq_degraded_fold_constant_if(bt, arm_result_types, next_then),
            )
          } else {
            return Some(
              match next_else {
                Some(other) =>
                  vq_degraded_fold_constant_if(bt, arm_result_types, other)
                None => TInstr::nop()
              },
            )
          }
        TInstrKind::TI64Const(I64(v)) =>
          if v != 0L {
            return Some(
              vq_degraded_fold_constant_if(bt, arm_result_types, next_then),
            )
          } else {
            return Some(
              match next_else {
                Some(other) =>
                  vq_degraded_fold_constant_if(bt, arm_result_types, other)
                None => TInstr::nop()
              },
            )
          }
        _ => ()
      }

      if pass_options.traps_never_happen {
        match next_else {
          Some(other) =>
            if vq_is_single_explicit_unreachable_texpr(next_then) {
              return Some(
                vq_tnh_rewrite_unreachable_if_arm(
                  bt, next_condition, other, env, analysis_cache,
                ),
              )
            } else if vq_is_single_explicit_unreachable_texpr(other) {
              return Some(
                vq_tnh_rewrite_unreachable_if_arm(
                  bt, next_condition, next_then, env, analysis_cache,
                ),
              )
            }
          None => ()
        }
      }

      match next_else {
        Some(other) =>
          if arm_result_types.is_empty() && vq_is_nop_texpr(other) {
            Some(
              vq_degraded_rebuild_if_without_else(
                bt, next_condition, next_then, env, analysis_cache,
              ),
            )
          } else {
            Some(TInstr::if_(bt, next_condition, next_then, Some(other)))
          }
        None =>
          if arm_result_types.is_empty() && vq_is_nop_texpr(next_then) {
            Some(
              vq_degraded_rebuild_if_without_else(
                bt, next_condition, next_then, env, analysis_cache,
              ),
            )
          } else {
            Some(TInstr::if_(bt, next_condition, next_then, None))
          }
      }
    }
    TInstrKind::TLoop(bt, body) => {
      let result_types = vq_block_result_types(bt, env)
      let next_body = vq_optimize_texpr_degraded(
        body,
        env,
        result_types,
        !result_types.is_empty(),
        budget,
        analysis_cache,
        pass_options,
      )
      if result_types.is_empty() && vq_is_nop_texpr(next_body) {
        Some(TInstr::nop())
      } else {
        Some(TInstr::loop_(bt, next_body))
      }
    }
    TInstrKind::TDrop(value) => {
      let next_value = match
        vq_process_instr_degraded(
          value, env, true, budget, analysis_cache, pass_options,
        ) {
        Some(next) => next
        None => value
      }
      Some(vq_degraded_simplify_drop_value(next_value, analysis_cache))
    }
    TInstrKind::TTryTable(bt, catches, body) => {
      let result_types = vq_block_result_types(bt, env)
      let next_body = vq_optimize_texpr_degraded(
        body,
        env,
        result_types,
        !result_types.is_empty(),
        budget,
        analysis_cache,
        pass_options,
      )
      if result_types.is_empty() && vq_is_nop_texpr(next_body) {
        Some(TInstr::nop())
      } else {
        Some(TInstr::try_table(bt, catches, next_body))
      }
    }
    _ => {
      let next_children : Array[TInstr] = []
      let mut changed_child = false
      for child in eval_children(instr) {
        let next_child = match
          vq_process_instr_degraded(
            child, env, true, budget, analysis_cache, pass_options,
          ) {
          Some(next) => next
          None => child
        }
        if next_child != child {
          changed_child = true
        }
        next_children.push(next_child)
      }
      let rebuilt = if changed_child {
        mb_rebuild_non_control(instr, next_children)
      } else {
        instr
      }
      if result_used ||
        !vq_degraded_can_remove_unused_instr(rebuilt, analysis_cache) {
        Some(rebuilt)
      } else {
        None
      }
    }
  }
}

///|
fn vq_tnh_rewrite_unreachable_if_arm(
  bt : BlockType,
  condition : TInstr,
  live_arm : TExpr,
  env : Env,
  analysis_cache : VQAnalysisCache,
  live_arm_expr_id? : Int? = None,
) -> TInstr {
  let seq_items = [TInstr::drop(condition)] + live_arm.instrs
  let result_types = vq_block_result_types(bt, env)
  if result_types.is_empty() {
    vq_sequence_to_instr(seq_items)
  } else {
    vq_simplify_block_to_contents(
      bt,
      TExpr::new(seq_items),
      env,
      analysis_cache,
      expr_id=live_arm_expr_id,
    )
  }
}

///|
fn vq_common_ref_heap_supertype(
  a : HeapType,
  b : HeapType,
  env : Env,
) -> HeapType? {
  fn is_func_heap(ht : HeapType) -> Bool {
    match ht {
      AbsHeapTypeHeapType(FuncAbsHeapType) => true
      HeapType(tidx) =>
        match env.resolve_comptype(tidx) {
          Some(FuncCompType(_, _)) => true
          _ => false
        }
      _ => false
    }
  }
  if Match::matches(a, b, env) {
    return Some(b)
  }
  if Match::matches(b, a, env) {
    return Some(a)
  }
  let candidates = [
    AbsHeapType::i31(),
    AbsHeapType::struct_(),
    AbsHeapType::array(),
    AbsHeapType::eq(),
    AbsHeapType::func(),
    AbsHeapType::extern_(),
    AbsHeapType::exn(),
    AbsHeapType::any(),
  ]
  for abs in candidates {
    let super_ht = HeapType::abs(abs)
    if Match::matches(a, super_ht, env) && Match::matches(b, super_ht, env) {
      return Some(super_ht)
    }
  }
  if is_func_heap(a) && is_func_heap(b) {
    return Some(HeapType::abs(AbsHeapType::func()))
  }
  None
}

///|
fn vq_common_ref_type_supertype(
  a : RefType,
  b : RefType,
  env : Env,
) -> RefType? {
  if Match::matches(a, b, env) {
    return Some(b)
  }
  if Match::matches(b, a, env) {
    return Some(a)
  }
  match
    vq_common_ref_heap_supertype(a.get_heap_type(), b.get_heap_type(), env) {
    Some(ht) => Some(RefType::new(a.is_nullable() || b.is_nullable(), ht))
    None => None
  }
}

///|
fn vq_common_val_supertype(a : ValType, b : ValType, env : Env) -> ValType? {
  if Match::matches(a, b, env) {
    return Some(b)
  }
  if Match::matches(b, a, env) {
    return Some(a)
  }
  match (a, b) {
    (RefTypeValType(r0), RefTypeValType(r1)) =>
      match vq_common_ref_type_supertype(r0, r1, env) {
        Some(rt) => Some(ValType::ref_type(rt))
        None => None
      }
    _ => None
  }
}

///|
fn vq_collect_value_break_types_to_depth_in_texpr(
  expr : TExpr,
  depth : Int,
  env : Env,
  analysis_cache : VQAnalysisCache,
  collected_types : Array[ValType],
  found_value_break : Ref[Bool],
  has_unknown_value_type : Ref[Bool],
  has_unsupported_multivalue_break : Ref[Bool],
) -> Unit {
  for instr in expr.instrs {
    vq_collect_value_break_types_to_depth(
      instr, depth, env, analysis_cache, collected_types, found_value_break, has_unknown_value_type,
      has_unsupported_multivalue_break,
    )
  }
}

///|
fn vq_collect_break_value_types(
  target_matches_depth : Bool,
  values : Array[TInstr],
  env : Env,
  analysis_cache : VQAnalysisCache,
  collected_types : Array[ValType],
  found_value_break : Ref[Bool],
  has_unknown_value_type : Ref[Bool],
  has_unsupported_multivalue_break : Ref[Bool],
) -> Unit {
  if target_matches_depth && !values.is_empty() {
    found_value_break.val = true
    if values.length() != 1 {
      has_unsupported_multivalue_break.val = true
    } else {
      match vq_type_of_cached(values[0], env, analysis_cache) {
        Some(vt) => collected_types.push(vt)
        None => has_unknown_value_type.val = true
      }
    }
  }
}

///|
fn vq_collect_value_break_types_to_depth(
  instr : TInstr,
  depth : Int,
  env : Env,
  analysis_cache : VQAnalysisCache,
  collected_types : Array[ValType],
  found_value_break : Ref[Bool],
  has_unknown_value_type : Ref[Bool],
  has_unsupported_multivalue_break : Ref[Bool],
) -> Unit {
  match instr.kind {
    TInstrKind::TBr(label, values) => {
      vq_collect_break_value_types(
        vq_label_to_int(label) == depth,
        values,
        env,
        analysis_cache,
        collected_types,
        found_value_break,
        has_unknown_value_type,
        has_unsupported_multivalue_break,
      )
      for value in values {
        vq_collect_value_break_types_to_depth(
          value, depth, env, analysis_cache, collected_types, found_value_break,
          has_unknown_value_type, has_unsupported_multivalue_break,
        )
      }
    }
    TInstrKind::TBrIf(label, cond, values) => {
      vq_collect_break_value_types(
        vq_label_to_int(label) == depth,
        values,
        env,
        analysis_cache,
        collected_types,
        found_value_break,
        has_unknown_value_type,
        has_unsupported_multivalue_break,
      )
      vq_collect_value_break_types_to_depth(
        cond, depth, env, analysis_cache, collected_types, found_value_break, has_unknown_value_type,
        has_unsupported_multivalue_break,
      )
      for value in values {
        vq_collect_value_break_types_to_depth(
          value, depth, env, analysis_cache, collected_types, found_value_break,
          has_unknown_value_type, has_unsupported_multivalue_break,
        )
      }
    }
    TInstrKind::TBrTable(labels, default, index, values) => {
      let mut target_matches_depth = vq_label_to_int(default) == depth
      for label in labels {
        if vq_label_to_int(label) == depth {
          target_matches_depth = true
        }
      }
      vq_collect_break_value_types(
        target_matches_depth, values, env, analysis_cache, collected_types, found_value_break,
        has_unknown_value_type, has_unsupported_multivalue_break,
      )
      vq_collect_value_break_types_to_depth(
        index, depth, env, analysis_cache, collected_types, found_value_break, has_unknown_value_type,
        has_unsupported_multivalue_break,
      )
      for value in values {
        vq_collect_value_break_types_to_depth(
          value, depth, env, analysis_cache, collected_types, found_value_break,
          has_unknown_value_type, has_unsupported_multivalue_break,
        )
      }
    }
    TInstrKind::TBrOnNull(label, ref_, values)
    | TInstrKind::TBrOnNonNull(label, ref_, values)
    | TInstrKind::TBrOnCast(label, _, _, _, ref_, values)
    | TInstrKind::TBrOnCastFail(label, _, _, _, ref_, values) => {
      vq_collect_break_value_types(
        vq_label_to_int(label) == depth,
        values,
        env,
        analysis_cache,
        collected_types,
        found_value_break,
        has_unknown_value_type,
        has_unsupported_multivalue_break,
      )
      vq_collect_value_break_types_to_depth(
        ref_, depth, env, analysis_cache, collected_types, found_value_break, has_unknown_value_type,
        has_unsupported_multivalue_break,
      )
      for value in values {
        vq_collect_value_break_types_to_depth(
          value, depth, env, analysis_cache, collected_types, found_value_break,
          has_unknown_value_type, has_unsupported_multivalue_break,
        )
      }
    }
    TInstrKind::TBlock(_, body) | TInstrKind::TLoop(_, body) =>
      vq_collect_value_break_types_to_depth_in_texpr(
        body,
        depth + 1,
        env,
        analysis_cache,
        collected_types,
        found_value_break,
        has_unknown_value_type,
        has_unsupported_multivalue_break,
      )
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      vq_collect_value_break_types_to_depth(
        cond, depth, env, analysis_cache, collected_types, found_value_break, has_unknown_value_type,
        has_unsupported_multivalue_break,
      )
      vq_collect_value_break_types_to_depth_in_texpr(
        then_body,
        depth + 1,
        env,
        analysis_cache,
        collected_types,
        found_value_break,
        has_unknown_value_type,
        has_unsupported_multivalue_break,
      )
      match else_body {
        Some(other) =>
          vq_collect_value_break_types_to_depth_in_texpr(
            other,
            depth + 1,
            env,
            analysis_cache,
            collected_types,
            found_value_break,
            has_unknown_value_type,
            has_unsupported_multivalue_break,
          )
        None => ()
      }
    }
    TInstrKind::TTryTable(_, _, body) =>
      vq_collect_value_break_types_to_depth_in_texpr(
        body,
        depth + 1,
        env,
        analysis_cache,
        collected_types,
        found_value_break,
        has_unknown_value_type,
        has_unsupported_multivalue_break,
      )
    _ =>
      vq_visit_instr_recursive_children(instr, fn(child) {
        vq_collect_value_break_types_to_depth(
          child, depth, env, analysis_cache, collected_types, found_value_break,
          has_unknown_value_type, has_unsupported_multivalue_break,
        )
      })
  }
}

///|
fn vq_value_break_to_depth_has_lub(
  expr : TExpr,
  depth : Int,
  env : Env,
  analysis_cache : VQAnalysisCache,
  expr_id? : Int? = None,
) -> Bool {
  let start_us = vacuum_trace_now_us()
  if depth == 0 {
    match vq_indexed_expr_value_break_lub_depth0(analysis_cache, expr_id) {
      Some(cached) => {
        ignore(
          vq_commit_helper_timing(
            analysis_cache.stats.value_break_lub_us,
            analysis_cache.stats.value_break_lub_calls,
            start_us,
          ),
        )
        return cached
      }
      None => ()
    }
  }
  let collected_types : Array[ValType] = []
  let found_value_break = Ref::new(false)
  let has_unknown_value_type = Ref::new(false)
  let has_unsupported_multivalue_break = Ref::new(false)
  vq_collect_value_break_types_to_depth_in_texpr(
    expr, depth, env, analysis_cache, collected_types, found_value_break, has_unknown_value_type,
    has_unsupported_multivalue_break,
  )
  let has_lub = if !found_value_break.val {
    false
  } else if has_unsupported_multivalue_break.val || has_unknown_value_type.val {
    true
  } else if collected_types.is_empty() {
    false
  } else {
    let mut candidate : ValType? = Some(collected_types[0])
    for i = 1; i < collected_types.length(); i = i + 1 {
      match candidate {
        Some(prev) =>
          candidate = vq_common_val_supertype(prev, collected_types[i], env)
        None => ()
      }
    }
    candidate is Some(_)
  }
  ignore(
    vq_commit_helper_timing(
      analysis_cache.stats.value_break_lub_us,
      analysis_cache.stats.value_break_lub_calls,
      start_us,
    ),
  )
  has_lub
}

///|
fn vq_try_midpass_degraded_fallback(
  instr : TInstr,
  env : Env,
  result_used : Bool,
  analysis_cache : VQAnalysisCache,
  pass_options : VQPassOptions,
) -> TInstr? {
  match analysis_cache.midpass_degraded_budget {
    Some(fallback_budget) => {
      analysis_cache.stats.tier_fallback_calls.val += 1
      let out = vq_process_instr_degraded(
        instr, env, result_used, fallback_budget, analysis_cache, pass_options,
      )
      match out {
        Some(next) =>
          if next != instr {
            analysis_cache.stats.tier_fallback_changes.val += 1
          }
        None => analysis_cache.stats.tier_fallback_changes.val += 1
      }
      out
    }
    None => Some(instr)
  }
}

///|
fn vq_process_instr(
  instr : TInstr,
  env : Env,
  result_used : Bool,
  type_matters : Bool,
  budget : Ref[Int],
  analysis_cache : VQAnalysisCache,
  pass_options : VQPassOptions,
  instr_id? : Int? = None,
) -> TInstr? {
  if !vq_take_budget(budget) {
    return vq_try_midpass_degraded_fallback(
      instr, env, result_used, analysis_cache, pass_options,
    )
  }
  let instr_node = vq_indexed_instr_node(analysis_cache, instr_id)
  match instr.kind {
    TInstrKind::TBlock(bt, body) => {
      let result_types = vq_block_result_types(bt, env)
      let original_body_expr_id = match instr_node {
        Some(node) => node.body_expr_id
        None => None
      }
      let mut next_body = vq_optimize_texpr(
        body,
        env,
        result_types,
        !result_types.is_empty(),
        budget,
        analysis_cache,
        pass_options,
        expr_id=original_body_expr_id,
      )
      if pass_options.traps_never_happen {
        let tnh_cleanup = vq_tnh_cleanup_block_items(
          next_body.instrs,
          env,
          analysis_cache,
        )
        if tnh_cleanup.changed {
          let cleaned = vq_optimize_sequence(
            tnh_cleanup.items,
            env,
            result_types,
            !result_types.is_empty(),
            budget,
            analysis_cache,
            pass_options,
          )
          next_body = if cleaned.changed {
            TExpr::new(cleaned.items)
          } else {
            next_body
          }
        }
      }
      let simplified = vq_simplify_block_to_contents(
        bt,
        next_body,
        env,
        analysis_cache,
        expr_id=if physical_equal(next_body, body) {
          original_body_expr_id
        } else if vq_can_reuse_original_expr_control_metadata(
            body,
            next_body,
            analysis_cache,
            expr_id=original_body_expr_id,
          ) {
          original_body_expr_id
        } else {
          None
        },
      )
      Some(
        match simplified.kind {
          TInstrKind::TBlock(next_bt, next_body) =>
            if bt == next_bt && physical_equal(next_body, body) {
              instr
            } else {
              simplified
            }
          _ => simplified
        },
      )
    }
    TInstrKind::TIf(bt, condition, then_body, else_body) => {
      let original_then_expr_id = match instr_node {
        Some(node) => node.then_expr_id
        None => None
      }
      let original_else_expr_id = match instr_node {
        Some(node) => node.else_expr_id
        None => None
      }
      let next_condition = vq_process_child_preserving_stack_sig(
        condition,
        env,
        budget,
        analysis_cache,
        pass_options,
        child_id=vq_indexed_eval_child_id(instr_node, 0),
      )
      let arm_result_types = vq_block_result_types(bt, env)
      let next_then = vq_optimize_texpr(
        then_body,
        env,
        arm_result_types,
        !arm_result_types.is_empty(),
        budget,
        analysis_cache,
        pass_options,
        expr_id=original_then_expr_id,
      )
      let next_else = match else_body {
        Some(other) =>
          Some(
            vq_optimize_texpr(
              other,
              env,
              arm_result_types,
              !arm_result_types.is_empty(),
              budget,
              analysis_cache,
              pass_options,
              expr_id=original_else_expr_id,
            ),
          )
        None => None
      }
      let then_simplify_expr_id = if physical_equal(next_then, then_body) ||
        vq_can_reuse_original_expr_control_metadata(
          then_body,
          next_then,
          analysis_cache,
          expr_id=original_then_expr_id,
        ) {
        original_then_expr_id
      } else {
        None
      }
      let else_simplify_expr_id = match (next_else, else_body) {
        (Some(other), Some(original_other)) =>
          if physical_equal(other, original_other) ||
            vq_can_reuse_original_expr_control_metadata(
              original_other,
              other,
              analysis_cache,
              expr_id=original_else_expr_id,
            ) {
            original_else_expr_id
          } else {
            None
          }
        _ => None
      }
      let condition_instr_id = if physical_equal(next_condition, condition) {
        vq_indexed_eval_child_id(instr_node, 0)
      } else {
        None
      }
      let tnh_condition_has_control_transfer = vq_instr_has_control_transfer_cached(
        next_condition,
        analysis_cache,
        instr_id=condition_instr_id,
      )
      let tnh_condition_has_any_labelidx = match
        vq_indexed_instr_node(analysis_cache, condition_instr_id) {
        Some(node) => node.has_any_labelidx
        None => vq_instr_has_any_labelidx(next_condition)
      }
      let tnh_can_reuse_live_arm_expr_id = !tnh_condition_has_control_transfer &&
        !tnh_condition_has_any_labelidx

      match next_condition.kind {
        TInstrKind::TI32Const(I32(v)) =>
          if v != 0 {
            return Some(
              vq_simplify_block_to_contents(
                bt,
                next_then,
                env,
                analysis_cache,
                expr_id=then_simplify_expr_id,
              ),
            )
          } else {
            return Some(
              match (next_else, else_body) {
                (Some(other), Some(_)) =>
                  vq_simplify_block_to_contents(
                    bt,
                    other,
                    env,
                    analysis_cache,
                    expr_id=else_simplify_expr_id,
                  )
                _ => TInstr::nop()
              },
            )
          }
        TInstrKind::TI64Const(I64(v)) =>
          if v != 0L {
            return Some(
              vq_simplify_block_to_contents(
                bt,
                next_then,
                env,
                analysis_cache,
                expr_id=then_simplify_expr_id,
              ),
            )
          } else {
            return Some(
              match (next_else, else_body) {
                (Some(other), Some(_)) =>
                  vq_simplify_block_to_contents(
                    bt,
                    other,
                    env,
                    analysis_cache,
                    expr_id=else_simplify_expr_id,
                  )
                _ => TInstr::nop()
              },
            )
          }
        _ => ()
      }

      if is_unreachable_instr(next_condition) {
        return Some(next_condition)
      }
      if pass_options.traps_never_happen {
        match next_else {
          Some(other) =>
            if vq_is_single_explicit_unreachable_texpr(next_then) {
              return Some(
                vq_tnh_rewrite_unreachable_if_arm(
                  bt,
                  next_condition,
                  other,
                  env,
                  analysis_cache,
                  live_arm_expr_id=if tnh_can_reuse_live_arm_expr_id {
                    else_simplify_expr_id
                  } else {
                    None
                  },
                ),
              )
            } else if vq_is_single_explicit_unreachable_texpr(other) {
              return Some(
                vq_tnh_rewrite_unreachable_if_arm(
                  bt,
                  next_condition,
                  next_then,
                  env,
                  analysis_cache,
                  live_arm_expr_id=if tnh_can_reuse_live_arm_expr_id {
                    then_simplify_expr_id
                  } else {
                    None
                  },
                ),
              )
            }
          None => ()
        }
      }

      match next_else {
        Some(other) => {
          if arm_result_types.is_empty() && vq_is_nop_texpr(other) {
            return Some(TInstr::if_(bt, next_condition, next_then, None))
          }
          let other_expr_id = else_simplify_expr_id
          if arm_result_types.is_empty() &&
            vq_is_nop_texpr(next_then) &&
            !vq_texpr_has_control_transfer_cached(
              other,
              analysis_cache,
              expr_id=other_expr_id,
            ) {
            let before = vq_preserve_original_if_unchanged(
              instr,
              condition,
              then_body,
              else_body,
              bt,
              next_condition,
              next_then,
              Some(other),
            )
            match
              vq_type_of_cached(
                next_condition,
                env,
                analysis_cache,
                instr_id=condition_instr_id,
              ) {
              Some(vt) if vt == ValType::i32() => {
                let after = TInstr::if_(
                  bt,
                  TInstr::unary(UnaryOp::i32_eqz(), next_condition),
                  other,
                  None,
                )
                return Some(after)
              }
              _ => ()
            }
            return Some(before)
          }
          match (next_then.instrs, other.instrs) {
            (
              [{ kind: TInstrKind::TDrop(left), .. }],
              [{ kind: TInstrKind::TDrop(right), .. }],
            ) => {
              let left_instr_id = vq_only_original_eval_child_id(
                next_then,
                analysis_cache,
                0,
                expr_id=then_simplify_expr_id,
              )
              let right_instr_id = vq_only_original_eval_child_id(
                other,
                analysis_cache,
                0,
                expr_id=other_expr_id,
              )
              match
                (
                  vq_type_of_cached(
                    left,
                    env,
                    analysis_cache,
                    instr_id=left_instr_id,
                  ),
                  vq_type_of_cached(
                    right,
                    env,
                    analysis_cache,
                    instr_id=right_instr_id,
                  ),
                ) {
                (Some(lt), Some(rt)) if lt == rt =>
                  Some(
                    TInstr::drop(
                      TInstr::if_(
                        BlockType::val_type(lt),
                        next_condition,
                        TExpr::new([left]),
                        Some(TExpr::new([right])),
                      ),
                    ),
                  )
                _ =>
                  Some(
                    vq_preserve_original_if_unchanged(
                      instr,
                      condition,
                      then_body,
                      else_body,
                      bt,
                      next_condition,
                      next_then,
                      Some(other),
                    ),
                  )
              }
            }
            _ =>
              Some(
                vq_preserve_original_if_unchanged(
                  instr,
                  condition,
                  then_body,
                  else_body,
                  bt,
                  next_condition,
                  next_then,
                  Some(other),
                ),
              )
          }
        }
        None =>
          if vq_is_nop_texpr(next_then) {
            Some(TInstr::drop(next_condition))
          } else {
            Some(
              vq_preserve_original_if_unchanged(
                instr,
                condition,
                then_body,
                else_body,
                bt,
                next_condition,
                next_then,
                None,
              ),
            )
          }
      }
    }
    TInstrKind::TLoop(bt, body) => {
      let result_types = vq_block_result_types(bt, env)
      let next_body = vq_optimize_texpr(
        body,
        env,
        result_types,
        !result_types.is_empty(),
        budget,
        analysis_cache,
        pass_options,
        expr_id=match instr_node {
          Some(node) => node.body_expr_id
          None => None
        },
      )
      if result_types.is_empty() && vq_is_nop_texpr(next_body) {
        Some(TInstr::nop())
      } else {
        Some(TInstr::loop_(bt, next_body))
      }
    }
    TInstrKind::TDrop(value) => {
      let next_value = match
        vq_process_instr(
          value,
          env,
          false,
          false,
          budget,
          analysis_cache,
          pass_options,
          instr_id=vq_indexed_eval_child_id(instr_node, 0),
        ) {
        Some(v) => v
        None => return Some(TInstr::nop())
      }
      let original_value_instr_id = vq_indexed_eval_child_id(instr_node, 0)
      let original_value_instr_node = vq_indexed_instr_node(
        analysis_cache, original_value_instr_id,
      )
      let value_instr_id = if physical_equal(next_value, value) {
        original_value_instr_id
      } else {
        None
      }
      let value_instr_node = vq_indexed_instr_node(
        analysis_cache, value_instr_id,
      )
      let dropped = if physical_equal(next_value, value) {
        instr
      } else {
        TInstr::drop(next_value)
      }
      if !physical_equal(dropped, instr) &&
        !vq_drop_rewrite_preserves_stack_sig_from_children(
          value,
          next_value,
          env,
          analysis_cache,
          before_child_id=original_value_instr_id,
          after_child_id=value_instr_id,
        ) &&
        !vq_rewrite_preserves_stack_sig_cached(
          instr,
          dropped,
          env,
          analysis_cache,
          before_id=instr_id,
        ) {
        return Some(instr)
      }
      match next_value.kind {
        TInstrKind::TDrop(inner) => {
          let rewrite = TInstr::drop(inner)
          if vq_drop_rewrite_preserves_stack_sig_from_children(
              value,
              inner,
              env,
              analysis_cache,
              before_child_id=original_value_instr_id,
              after_child_id=vq_indexed_eval_child_id(value_instr_node, 0),
            ) {
            return Some(rewrite)
          } else if vq_rewrite_preserves_stack_sig_cached(
              instr,
              rewrite,
              env,
              analysis_cache,
              before_id=instr_id,
            ) {
            return Some(rewrite)
          }
          return Some(dropped)
        }
        TInstrKind::TLocalTee(idx, inner) => {
          let rewrite = TInstr::local_set(idx, inner)
          if vq_drop_rewrite_preserves_stack_sig_from_children(
              value,
              inner,
              env,
              analysis_cache,
              before_child_id=original_value_instr_id,
              after_child_id=vq_indexed_eval_child_id(value_instr_node, 0),
            ) {
            return Some(rewrite)
          } else if vq_rewrite_preserves_stack_sig_cached(
              instr,
              rewrite,
              env,
              analysis_cache,
              before_id=instr_id,
            ) {
            return Some(rewrite)
          }
          return Some(dropped)
        }
        _ => ()
      }
      if !vq_has_unremovable_effects_cached(dropped, analysis_cache) {
        return Some(TInstr::nop())
      }
      match next_value.kind {
        TInstrKind::TBlock(bt, body) => {
          let { instrs: items, .. } = body
          let original_body_expr_id = match
            vq_indexed_instr_node(
              analysis_cache,
              vq_indexed_eval_child_id(instr_node, 0),
            ) {
            Some(node) => node.body_expr_id
            None => None
          }
          let body_expr_id = match value.kind {
            TInstrKind::TBlock(original_bt, original_body) =>
              if bt == original_bt &&
                (
                  physical_equal(body, original_body) ||
                  vq_can_reuse_original_expr_control_metadata(
                    original_body,
                    body,
                    analysis_cache,
                    expr_id=original_body_expr_id,
                  )
                ) {
                original_body_expr_id
              } else {
                None
              }
            _ => None
          }
          if items.length() > 0 {
            let last = items[items.length() - 1]
            let last_instr_id = vq_last_original_instr_id(
              body,
              analysis_cache,
              expr_id=body_expr_id,
            )
            match
              (
                vq_block_result_type(bt, env),
                vq_type_of_cached(
                  last,
                  env,
                  analysis_cache,
                  instr_id=last_instr_id,
                ),
              ) {
              (Some(block_vt), Some(last_vt)) if block_vt == last_vt =>
                match
                  vq_optimize(
                    last,
                    false,
                    false,
                    env,
                    budget,
                    analysis_cache,
                    pass_options,
                    instr_id=last_instr_id,
                  ) {
                  None =>
                    if !vq_has_value_break_lub_depth0_cached(
                        body,
                        env,
                        analysis_cache,
                        expr_id=body_expr_id,
                      ) {
                      let next_items = items.copy()
                      ignore(next_items.pop())
                      if next_items.length() > 1 {
                        return Some(
                          TInstr::block(
                            BlockType::void_(),
                            TExpr::new(next_items),
                          ),
                        )
                      }
                      if next_items.length() == 1 {
                        let next_item_id = match body_expr_id {
                          Some(id) =>
                            match
                              vq_indexed_expr_node(analysis_cache, Some(id)) {
                              Some(node) => node.instr_ids.get(0)
                              None => None
                            }
                          None => None
                        }
                        return Some(
                          vq_rebase_labels_for_collapsed_wrapper_if_needed(
                            next_items[0],
                            analysis_cache,
                            instr_id=next_item_id,
                          ),
                        )
                      }
                      return Some(TInstr::nop())
                    }
                  Some(_) => ()
                }
              _ => ()
            }
          }
        }
        _ => ()
      }

      match next_value.kind {
        TInstrKind::TIf(bt, cond, then_body, Some(other_body)) => {
          let if_type = vq_block_result_type(bt, env)
          let fallback_then_expr_id = match value_instr_node {
            Some(node) => node.then_expr_id
            None => None
          }
          let fallback_other_expr_id = match value_instr_node {
            Some(node) => node.else_expr_id
            None => None
          }
          let original_then_expr_id = match original_value_instr_node {
            Some(node) => node.then_expr_id
            None => None
          }
          let original_other_expr_id = match original_value_instr_node {
            Some(node) => node.else_expr_id
            None => None
          }
          let (then_expr_id, other_expr_id) = match value.kind {
            TInstrKind::TIf(original_bt, _, original_then, Some(original_other)) =>
              if bt == original_bt {
                (
                  if physical_equal(then_body, original_then) ||
                    vq_can_reuse_original_expr_control_metadata(
                      original_then,
                      then_body,
                      analysis_cache,
                      expr_id=original_then_expr_id,
                    ) {
                    original_then_expr_id
                  } else {
                    None
                  },
                  if physical_equal(other_body, original_other) ||
                    vq_can_reuse_original_expr_control_metadata(
                      original_other,
                      other_body,
                      analysis_cache,
                      expr_id=original_other_expr_id,
                    ) {
                    original_other_expr_id
                  } else {
                    None
                  },
                )
              } else {
                (fallback_then_expr_id, fallback_other_expr_id)
              }
            _ => (fallback_then_expr_id, fallback_other_expr_id)
          }
          match if_type {
            Some(_) =>
              if vq_texpr_is_unreachable(then_body) &&
                vq_texpr_result_type(
                  other_body,
                  env,
                  analysis_cache,
                  expr_id=other_expr_id,
                )
                is Some(_) {
                return Some(
                  TInstr::if_(
                    BlockType::void_(),
                    cond,
                    then_body,
                    Some(
                      vq_drop_texpr_value(
                        other_body,
                        env,
                        analysis_cache,
                        expr_id=other_expr_id,
                      ),
                    ),
                  ),
                )
              } else if vq_texpr_is_unreachable(other_body) &&
                vq_texpr_result_type(
                  then_body,
                  env,
                  analysis_cache,
                  expr_id=then_expr_id,
                )
                is Some(_) {
                return Some(
                  TInstr::if_(
                    BlockType::void_(),
                    cond,
                    vq_drop_texpr_value(
                      then_body,
                      env,
                      analysis_cache,
                      expr_id=then_expr_id,
                    ),
                    Some(other_body),
                  ),
                )
              }
            None => ()
          }
        }
        _ => ()
      }
      Some(dropped)
    }
    TInstrKind::TTryTable(bt, catches, body) => {
      let result_types = vq_block_result_types(bt, env)
      let original_body_expr_id = match instr_node {
        Some(node) => node.body_expr_id
        None => None
      }
      let next_body = vq_optimize_texpr(
        body,
        env,
        result_types,
        !result_types.is_empty(),
        budget,
        analysis_cache,
        pass_options,
        expr_id=original_body_expr_id,
      )
      let body_expr_id = if physical_equal(next_body, body) {
        original_body_expr_id
      } else if vq_can_reuse_original_expr_control_metadata(
          body,
          next_body,
          analysis_cache,
          expr_id=original_body_expr_id,
        ) {
        original_body_expr_id
      } else {
        None
      }
      if !vq_texpr_throws_cached(
          next_body,
          analysis_cache,
          expr_id=body_expr_id,
        ) {
        Some(
          vq_simplify_block_to_contents(
            bt,
            next_body,
            env,
            analysis_cache,
            expr_id=body_expr_id,
          ),
        )
      } else {
        Some(TInstr::try_table(bt, catches, next_body))
      }
    }
    _ => {
      let next_children : Array[TInstr] = []
      let mut changed_child = false
      for child in eval_children(instr) {
        let next_child = vq_process_child_preserving_stack_sig(
          child,
          env,
          budget,
          analysis_cache,
          pass_options,
          child_id=vq_indexed_eval_child_id(instr_node, next_children.length()),
        )
        if next_child != child {
          changed_child = true
        }
        next_children.push(next_child)
      }
      if next_children.is_empty() {
        return vq_optimize(
          instr,
          result_used,
          type_matters,
          env,
          budget,
          analysis_cache,
          pass_options,
          instr_id~,
        )
      }
      let rebuilt = if changed_child {
        mb_rebuild_non_control(instr, next_children)
      } else {
        instr
      }
      vq_optimize(
        rebuilt,
        result_used,
        type_matters,
        env,
        budget,
        analysis_cache,
        pass_options,
        instr_id=if changed_child { None } else { instr_id },
      )
    }
  }
}

///|
fn vq_should_fast_skip_function(
  body : TExpr,
  sig : VQFuncSig,
  env : Env,
  analysis_cache : VQAnalysisCache,
) -> Bool {
  match body.instrs {
    [{ kind: TInstrKind::TNop, .. }] if sig.results.length() == 0 => true
    [single] =>
      match single.kind {
        TInstrKind::TI32Const(_)
        | TInstrKind::TI64Const(_)
        | TInstrKind::TF32Const(_)
        | TInstrKind::TF64Const(_)
        | TInstrKind::TRefNull(_)
        | TInstrKind::TRefFunc(_)
        | TInstrKind::TLocalGet(_)
        | TInstrKind::TGlobalGet(_) =>
          match sig.results {
            [result_vt] =>
              match vq_type_of_cached(single, env, analysis_cache) {
                Some(vt) if vt == result_vt => true
                _ => false
              }
            _ => false
          }
        _ => false
      }
    _ => false
  }
}

///|
fn vq_optimize_function(
  mod : Module,
  func : Func,
  sig : VQFuncSig,
  ordinal : Int,
  trace : (String) -> Unit,
  trace_all_funcs : Bool,
  pass_options : VQPassOptions,
  stats : VQRunStats,
  call_without_effects_intrinsics : Array[Bool],
) -> (Func, Bool) {
  match func {
    Func(_) => {
      if trace_all_funcs {
        trace("func[\{ordinal}] vacuum skip non-typed-func")
      }
      (func, false)
    }
    TFunc(tfunc_params, locals, body) => {
      vq_active_stats.val = Some(stats)
      let func_start_ms = vacuum_trace_now_ms()
      let function_locals = match
        FunctionLocals::from_typed_func_for_pass(
          sig.params,
          tfunc_params,
          locals,
        ) {
        Ok(ls) => ls
        Err(e) => abort("vacuum vq_optimize_function: \{e}")
      }
      let all_locals = function_locals.all_locals()
      let top_instrs = body.instrs.length()
      let num_locals = all_locals.length()

      let env = Env::new().with_module(mod).with_locals(all_locals)
      let analysis_cache = VQAnalysisCache::new(
        call_without_effects_intrinsics, stats,
      )
      if vq_should_fast_skip_function(body, sig, env, analysis_cache) {
        stats.fast_skips.val += 1
        if trace_all_funcs {
          trace("func[\{ordinal}] vacuum fast_skip=true")
        }
        vq_active_stats.val = None
        return (func, false)
      }
      let shape_start_ms = vacuum_trace_now_ms()
      let shape = vq_measure_texpr_shape(body, env)
      let shape_elapsed_ms = vq_commit_phase_timing(
        stats.shape_scan_ms,
        stats.shape_scan_calls,
        shape_start_ms,
      )

      if trace_all_funcs {
        trace(
          "func[\{ordinal}] vacuum start instrs=\{top_instrs} total_instrs=\{shape.total_instrs} depth=\{shape.max_depth} blocks=\{shape.block_count} ifs=\{shape.if_count} drops=\{shape.drop_count} wrappers=\{shape.single_item_block_count} result_blocks=\{shape.result_block_count} shape_ms=\{shape_elapsed_ms} locals=\{num_locals}",
        )
      }

      let budget = Ref::new(vq_shape_full_budget(shape))
      let full_tier_fallback_budget = Ref::new(0)
      let mut degraded_reason : String? = None
      let seed_elapsed_ms = if vq_shape_requires_degraded_mode(shape) {
        stats.degraded_funcs.val += 1
        stats.shape_degraded_funcs.val += 1
        degraded_reason = Some("pathological_shape")
        budget.val = vq_shape_degraded_budget(shape)
        0UL
      } else {
        let seed_start_ms = vacuum_trace_now_ms()
        let seed_budget = Ref::new(vq_shape_seed_budget(shape))
        if vq_seed_texpr_facts_bounded(body, env, analysis_cache, seed_budget) {
          vq_commit_phase_timing(stats.seed_ms, stats.seed_calls, seed_start_ms)
        } else {
          stats.degraded_funcs.val += 1
          stats.seed_budget_exhaustions.val += 1
          degraded_reason = Some("seed_budget_exhausted")
          budget.val = vq_shape_degraded_budget(shape)
          if trace_all_funcs {
            trace(
              "func[\{ordinal}] vacuum seed_exhausted=true seed_budget=\{vq_shape_seed_budget(shape)}",
            )
          }
          vq_commit_phase_timing(stats.seed_ms, stats.seed_calls, seed_start_ms)
        }
      }

      let optimize_start_ms = vacuum_trace_now_ms()
      let fallback_calls_before = stats.tier_fallback_calls.val
      let fallback_changes_before = stats.tier_fallback_changes.val
      let sequence = if degraded_reason is Some(_) {
        vq_optimize_sequence_degraded(
          body.instrs,
          env,
          sig.results,
          sig.results.length() > 0,
          budget,
          analysis_cache,
          pass_options,
        )
      } else {
        full_tier_fallback_budget.val = vq_shape_degraded_budget(shape)
        analysis_cache.midpass_degraded_budget = Some(full_tier_fallback_budget)
        let out = vq_optimize_sequence(
          body.instrs,
          env,
          sig.results,
          sig.results.length() > 0,
          budget,
          analysis_cache,
          pass_options,
          expr_id=analysis_cache.indexed_root_expr_id,
        )
        analysis_cache.midpass_degraded_budget = None
        out
      }
      let fallback_calls_delta = stats.tier_fallback_calls.val -
        fallback_calls_before
      let fallback_changes_delta = stats.tier_fallback_changes.val -
        fallback_changes_before
      let optimize_elapsed_ms = vq_commit_phase_timing(
        stats.optimize_ms,
        stats.optimize_calls,
        optimize_start_ms,
      )

      let next_items = sequence.items
      if next_items.is_empty() {
        next_items.push(TInstr::nop())
      }
      let next_body = TExpr::new(next_items)

      let final_start_ms = vacuum_trace_now_ms()
      let mut changed = sequence.changed
      let mut can_nop_body = false
      if degraded_reason is None && sig.results.length() == 0 {
        if !vq_texpr_has_unremovable_side_effects(next_body, analysis_cache) {
          can_nop_body = true
        } else if pass_options.traps_never_happen &&
          !lcs_has_unremovable_nontrap_side_effects(
            TInstr::block(BlockType::void_(), next_body),
          ) &&
          !vq_texpr_has_explicit_unreachable_cached(next_body, analysis_cache) {
          can_nop_body = true
        }
      }
      let final_elapsed_ms = vq_commit_phase_timing(
        stats.final_check_ms,
        stats.final_check_calls,
        final_start_ms,
      )
      stats.instr_cache_entries.val += vq_analysis_cache_instr_entry_count(
        analysis_cache,
      )
      stats.expr_cache_entries.val += vq_analysis_cache_expr_entry_count(
        analysis_cache,
      )
      let total_elapsed_ms = vacuum_trace_elapsed_ms(func_start_ms)
      vq_hotspot_record(stats, ordinal, total_elapsed_ms, shape)
      if can_nop_body {
        let nopped = Func::t_func(
          tfunc_params,
          locals,
          TExpr::new([TInstr::nop()]),
        )
        changed = true
        if trace_all_funcs {
          let mode = match degraded_reason {
            Some(_) => "degraded"
            None => "full"
          }
          trace(
            "func[\{ordinal}] vacuum nopped=true budget_left=\{budget.val} fallback_budget_left=\{full_tier_fallback_budget.val} mode=\{mode} fallback_calls=\{fallback_calls_delta} fallback_changes=\{fallback_changes_delta} seed_ms=\{seed_elapsed_ms} optimize_ms=\{optimize_elapsed_ms} final_ms=\{final_elapsed_ms} elapsed_ms=\{total_elapsed_ms}",
          )
        }
        vq_active_stats.val = None
        (nopped, changed)
      } else {
        let next_func = Func::t_func(tfunc_params, locals, next_body)
        if trace_all_funcs {
          match degraded_reason {
            Some(reason) =>
              trace(
                "func[\{ordinal}] vacuum done changed=\{changed} budget_left=\{budget.val} fallback_budget_left=\{full_tier_fallback_budget.val} mode=degraded reason=\{reason} fallback_calls=\{fallback_calls_delta} fallback_changes=\{fallback_changes_delta} seed_ms=\{seed_elapsed_ms} optimize_ms=\{optimize_elapsed_ms} final_ms=\{final_elapsed_ms} elapsed_ms=\{total_elapsed_ms}",
              )
            None =>
              trace(
                "func[\{ordinal}] vacuum done changed=\{changed} budget_left=\{budget.val} fallback_budget_left=\{full_tier_fallback_budget.val} mode=full fallback_calls=\{fallback_calls_delta} fallback_changes=\{fallback_changes_delta} seed_ms=\{seed_elapsed_ms} optimize_ms=\{optimize_elapsed_ms} final_ms=\{final_elapsed_ms} elapsed_ms=\{total_elapsed_ms}",
              )
          }
        }
        vq_active_stats.val = None
        (next_func, changed)
      }
    }
  }
}

///|
fn vacuum_trace_noop(_ : String) -> Unit {
  ()
}

///|
fn vacuum_ir_pass_with_trace(
  mod : Module,
  trace : (String) -> Unit,
  trace_all_funcs? : Bool = false,
  traps_never_happen? : Bool = false,
) -> ModuleTransformer[IRContext, String] {
  let pass_options = VQPassOptions::new(traps_never_happen~)
  let sigs = vq_collect_func_sigs(mod)
  let total_funcs = match mod.code_sec {
    Some(CodeSec(funcs)) => funcs.length()
    None => 0
  }
  let call_without_effects_intrinsics = vq_collect_call_without_effects_intrinsics(
    mod,
  )
  let stats = VQRunStats::new()
  let next_def_idx = Ref::new(0)
  ModuleTransformer::new().on_func_evt(fn(_, ctx, func : Func) {
    let def_idx = next_def_idx.val
    next_def_idx.update(fn(i) { i + 1 })
    let ordinal = def_idx + 1
    let log_func = pass_trace_log_enabled(ordinal, trace_all_funcs)
    let start_instrs = match func {
      TFunc(_, _, body) => body.instrs.length()
      _ => 0
    }
    if log_func {
      trace("func[\{ordinal}] start instrs=\{start_instrs}")
    }
    let sig = sigs.get(def_idx).unwrap_or(VQFuncSig::new([], []))
    let (next_func, changed) = vq_optimize_function(
      mod, func, sig, ordinal, trace, trace_all_funcs, pass_options, stats, call_without_effects_intrinsics,
    )
    if changed {
      stats.changed_funcs.val += 1
    }
    let end_instrs = match next_func {
      TFunc(_, _, body) => body.instrs.length()
      _ => 0
    }
    if log_func {
      trace(
        "func[\{ordinal}] done changed=\{changed} instrs=\{start_instrs}->\{end_instrs}",
      )
    }
    if changed {
      let result = change(ctx, next_func)
      if ordinal == total_funcs {
        vq_trace_emit_run_summaries(trace, stats, total_funcs)
      }
      result
    } else {
      let result = unchanged()
      if ordinal == total_funcs {
        vq_trace_emit_run_summaries(trace, stats, total_funcs)
      }
      result
    }
  })
}

///|
fn vacuum_ir_pass(mod : Module) -> ModuleTransformer[IRContext, String] {
  vacuum_ir_pass_with_trace(mod, vacuum_trace_noop)
}

///|
fn run_vacuum(mod : Module) -> Module {
  let pass = vacuum_ir_pass(mod)
  match pass.walk_module(IRContext::new(), mod) {
    Ok((out, _)) => out
    Err(e) => abort("vacuum pass failed: \{e}")
  }
}

///|
fn run_vacuum_with_options(
  mod : Module,
  traps_never_happen : Bool,
) -> Module raise {
  let options = OptimizeOptions::new(traps_never_happen~)
  match optimize_module_with_options(mod, [Vacuum], options) {
    Ok(out) => out
    Err(e) => fail("unexpected optimize_module_with_options error: \{e}")
  }
}

///|
fn vq_first_func_body(mod : Module) -> TExpr {
  match mod.code_sec {
    Some(CodeSec([TFunc(_, _, body), ..])) => body
    _ => abort("expected first typed function body")
  }
}

///|
fn vq_make_nested_void_blocks(depth : Int, inner : TInstr) -> TInstr {
  let mut curr = inner
  let mut remaining = depth
  while remaining > 0 {
    curr = TInstr::block(BlockType::void_(), TExpr::new([curr]))
    remaining -= 1
  }
  curr
}

///|
fn vq_nested_void_block_depth_to_local_set(instr : TInstr) -> Int? {
  match instr.kind {
    TInstrKind::TLocalSet(_, _) => Some(0)
    TInstrKind::TBlock(VoidBlockType, { instrs: [inner], .. }) =>
      match vq_nested_void_block_depth_to_local_set(inner) {
        Some(depth) => Some(depth + 1)
        None => None
      }
    _ => None
  }
}

///|
fn vq_nested_void_block_depth_to_dropped_call(instr : TInstr) -> Int? {
  match instr.kind {
    TInstrKind::TDrop({ kind: TInstrKind::TCall(_, []), .. }) => Some(0)
    TInstrKind::TBlock(VoidBlockType, { instrs: [inner], .. }) =>
      match vq_nested_void_block_depth_to_dropped_call(inner) {
        Some(depth) => Some(depth + 1)
        None => None
      }
    _ => None
  }
}

///|
test "vacuum shape scan flags deep single-item block chain for degraded mode" {
  let body = TExpr::new([
    vq_make_nested_void_blocks(
      48,
      TInstr::drop(
        TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(9))),
      ),
    ),
  ])
  let env = Env::new().with_module(Module::new()).with_locals([ValType::i32()])
  let shape = vq_measure_texpr_shape(body, env)
  assert_true(shape.total_instrs >= 49)
  assert_true(shape.max_depth >= 48)
  assert_true(vq_shape_requires_degraded_mode(shape))
}

///|
test "vacuum bounded seed phase reports exhaustion without failing" {
  let body = TExpr::new([
    vq_make_nested_void_blocks(
      8,
      TInstr::drop(
        TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(9))),
      ),
    ),
  ])
  let env = Env::new().with_module(Module::new()).with_locals([ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(4)
  assert_false(vq_seed_texpr_facts_bounded(body, env, cache, budget))
}

///|
test "vacuum indexed analysis keeps duplicate subtree occurrences distinct" {
  let body = TExpr::new([
    TInstr::drop(TInstr::i32_const(I32(1))),
    TInstr::drop(TInstr::i32_const(I32(1))),
  ])
  let env = Env::new().with_module(Module::new())
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(128)
  let expr_id = match
    vq_build_indexed_expr_analysis_bounded(body, env, cache, budget) {
    Some(id) => id
    None => fail("expected indexed analysis to succeed")
  }
  let expr_node = cache.indexed_expr_nodes[expr_id]
  assert_eq(expr_node.instr_ids.length(), 2)
  assert_true(expr_node.instr_ids[0] != expr_node.instr_ids[1])
  let left = cache.indexed_instr_nodes[expr_node.instr_ids[0]]
  let right = cache.indexed_instr_nodes[expr_node.instr_ids[1]]
  match (left.eval_child_ids, right.eval_child_ids) {
    ([left_child], [right_child]) => assert_true(left_child != right_child)
    _ => fail("expected both drop nodes to keep distinct child ids")
  }
}

///|
test "vacuum indexed lookup does not populate fallback type cache for original nodes" {
  let body = TExpr::new([TInstr::local_get(LocalIdx::new(0))])
  let env = Env::new().with_module(Module::new()).with_locals([ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let expr_id = match
    vq_build_indexed_expr_analysis_bounded(body, env, cache, budget) {
    Some(id) => id
    None => fail("expected indexed analysis to succeed")
  }
  let instr_id = cache.indexed_expr_nodes[expr_id].instr_ids[0]
  let instr_entries_before = vq_analysis_cache_instr_entry_count(cache)
  assert_eq(
    vq_type_of_cached(body.instrs[0], env, cache, instr_id=Some(instr_id)),
    Some(ValType::i32()),
  )
  assert_eq(vq_analysis_cache_instr_entry_count(cache), instr_entries_before)
}

///|
test "vacuum indexed control metadata marks only the targeted depth-0 wrapper" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([TInstr::br(LabelIdx::new(1), [])]),
    ),
  ])
  let env = Env::new().with_module(Module::new())
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(128)
  assert_true(vq_seed_texpr_facts_bounded(body, env, cache, budget))
  let root_expr_id = match cache.indexed_root_expr_id {
    Some(id) => id
    None => fail("expected root expr id")
  }
  let root_instr_id = cache.indexed_expr_nodes[root_expr_id].instr_ids[0]
  let inner_expr_id = match
    cache.indexed_instr_nodes[root_instr_id].body_expr_id {
    Some(id) => id
    None => fail("expected inner block body id")
  }
  assert_false(vq_indexed_expr_has_break_to_depth0(cache, Some(inner_expr_id)))
  assert_true(vq_indexed_expr_has_break_to_depth0(cache, Some(root_expr_id)))
}

///|
test "vacuum simplify_block uses indexed metadata to skip break scan and label rebase" {
  let body = TExpr::new([TInstr::i32_const(I32(7))])
  let env = Env::new().with_module(Module::new())
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(128)
  assert_true(vq_seed_texpr_facts_bounded(body, env, cache, budget))
  let root_expr_id = match cache.indexed_root_expr_id {
    Some(id) => id
    None => fail("expected root expr id")
  }
  let out = vq_simplify_block_to_contents(
    BlockType::val_type(ValType::i32()),
    body,
    env,
    cache,
    expr_id=Some(root_expr_id),
  )
  assert_eq(out, TInstr::i32_const(I32(7)))
  assert_eq(cache.stats.break_scan_calls.val, 0)
  assert_eq(cache.stats.rebase_labels_calls.val, 0)
  assert_eq(
    vq_analysis_cache_instr_entry_count(cache),
    cache.indexed_instr_nodes.length(),
  )
}

///|
test "vacuum simplify_block skips no-op label rebasing for depth-local loop branch" {
  let inner = TInstr::block(
    BlockType::void_(),
    TExpr::new([
      TInstr::loop_(
        BlockType::void_(),
        TExpr::new([TInstr::br(LabelIdx::new(0), [])]),
      ),
    ]),
  )
  let body = TExpr::new([inner])
  let env = Env::new().with_module(Module::new())
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(128)
  assert_true(vq_seed_texpr_facts_bounded(body, env, cache, budget))
  let root_expr_id = match cache.indexed_root_expr_id {
    Some(id) => id
    None => fail("expected root expr id")
  }
  vq_active_stats.val = Some(cache.stats)
  let out = vq_simplify_block_to_contents(
    BlockType::void_(),
    body,
    env,
    cache,
    expr_id=Some(root_expr_id),
  )
  vq_active_stats.val = None
  assert_eq(out, inner)
  assert_eq(cache.stats.rebase_labels_calls.val, 0)
  assert_eq(cache.stats.break_scan_calls.val, 0)
}

///|
test "vacuum simplify_block skips label rebasing for unindexed label-free body" {
  let body = TExpr::new([TInstr::i32_const(I32(3))])
  let env = Env::new().with_module(Module::new())
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  vq_active_stats.val = Some(cache.stats)
  let out = vq_simplify_block_to_contents(
    BlockType::val_type(ValType::i32()),
    body,
    env,
    cache,
  )
  vq_active_stats.val = None
  assert_eq(out, TInstr::i32_const(I32(3)))
  assert_eq(cache.stats.break_scan_calls.val, 0)
  assert_eq(cache.stats.rebase_score_calls.val, 1)
  assert_eq(cache.stats.rebase_labels_calls.val, 0)
}

///|
test "vacuum simplify_block skips label rebasing for unindexed depth-local branch" {
  let inner = TInstr::loop_(
    BlockType::void_(),
    TExpr::new([TInstr::br(LabelIdx::new(0), [])]),
  )
  let body = TExpr::new([inner])
  let env = Env::new().with_module(Module::new())
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  vq_active_stats.val = Some(cache.stats)
  let out = vq_simplify_block_to_contents(BlockType::void_(), body, env, cache)
  vq_active_stats.val = None
  assert_eq(out, inner)
  assert_eq(cache.stats.break_scan_calls.val, 0)
  assert_eq(cache.stats.rebase_score_calls.val, 1)
  assert_eq(cache.stats.rebase_labels_calls.val, 0)
}

///|
test "vacuum simplify_block skips break scan for unindexed multi-item body" {
  let body = TExpr::new([TInstr::nop(), TInstr::nop()])
  let env = Env::new().with_module(Module::new())
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  vq_active_stats.val = Some(cache.stats)
  let out = vq_simplify_block_to_contents(BlockType::void_(), body, env, cache)
  vq_active_stats.val = None
  assert_eq(out, TInstr::block(BlockType::void_(), body))
  assert_eq(cache.stats.break_scan_calls.val, 0)
  assert_eq(cache.stats.rebase_labels_calls.val, 0)
}

///|
test "vacuum indexed drop(local.tee) rewrite avoids generic stack-preservation helper" {
  let instr = TInstr::drop(
    TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(9))),
  )
  let body = TExpr::new([instr])
  let env = Env::new().with_module(Module::new()).with_locals([ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let seed_budget = Ref::new(64)
  assert_true(vq_seed_texpr_facts_bounded(body, env, cache, seed_budget))
  let expr_id = match cache.indexed_root_expr_id {
    Some(id) => id
    None => fail("expected root expr id")
  }
  let instr_id = cache.indexed_expr_nodes[expr_id].instr_ids[0]
  let process_budget = Ref::new(64)
  vq_active_stats.val = Some(cache.stats)
  let out = match
    vq_process_instr(
      instr,
      env,
      false,
      false,
      process_budget,
      cache,
      VQPassOptions::new(),
      instr_id=Some(instr_id),
    ) {
    Some(next) => next
    None => fail("expected drop(local.tee) rewrite result")
  }
  vq_active_stats.val = None
  match out.kind {
    TInstrKind::TLocalSet(
      LocalIdx(i),
      { kind: TInstrKind::TI32Const(I32(v)), .. }
    ) => {
      assert_eq(i, 0U)
      assert_eq(v, 9)
    }
    _ => fail("expected drop(local.tee) to rewrite to local.set")
  }
  assert_eq(cache.stats.rewrite_stack_calls.val, 0)
}

///|
test "vacuum unindexed drop(local.tee) rewrite avoids generic stack-preservation helper" {
  let instr = TInstr::drop(
    TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(9))),
  )
  let env = Env::new().with_module(Module::new()).with_locals([ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let process_budget = Ref::new(64)
  let out = match
    vq_process_instr(
      instr,
      env,
      false,
      false,
      process_budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected drop(local.tee) rewrite result")
  }
  match out.kind {
    TInstrKind::TLocalSet(
      LocalIdx(i),
      { kind: TInstrKind::TI32Const(I32(v)), .. }
    ) => {
      assert_eq(i, 0U)
      assert_eq(v, 9)
    }
    _ => fail("expected drop(local.tee) to rewrite to local.set")
  }
  assert_eq(cache.stats.rewrite_stack_calls.val, 0)
}

///|
test "vacuum changed block body reuses indexed break metadata when control-flow is unchanged" {
  let instr = TInstr::block(
    BlockType::void_(),
    TExpr::new([
      TInstr::drop(
        TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(9))),
      ),
    ]),
  )
  let body = TExpr::new([instr])
  let env = Env::new().with_module(Module::new()).with_locals([ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let seed_budget = Ref::new(64)
  assert_true(vq_seed_texpr_facts_bounded(body, env, cache, seed_budget))
  let expr_id = match cache.indexed_root_expr_id {
    Some(id) => id
    None => fail("expected root expr id")
  }
  let instr_id = cache.indexed_expr_nodes[expr_id].instr_ids[0]
  let process_budget = Ref::new(64)
  let out = match
    vq_process_instr(
      instr,
      env,
      false,
      false,
      process_budget,
      cache,
      VQPassOptions::new(),
      instr_id=Some(instr_id),
    ) {
    Some(next) => next
    None => fail("expected rewritten block result")
  }
  assert_eq(out, TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(9))))
  assert_eq(cache.stats.break_scan_calls.val, 0)
}

///|
test "vacuum indexed if-arm inversion avoids generic type-and-stack helper" {
  let original_condition = TInstr::local_get(LocalIdx::new(0))
  let original_else = TExpr::new([
    TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(9))),
  ])
  let instr = TInstr::if_(
    BlockType::void_(),
    original_condition,
    TExpr::new([TInstr::nop()]),
    Some(original_else),
  )
  let body = TExpr::new([instr])
  let env = Env::new()
    .with_module(Module::new())
    .with_locals([ValType::i32(), ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let seed_budget = Ref::new(64)
  assert_true(vq_seed_texpr_facts_bounded(body, env, cache, seed_budget))
  let expr_id = match cache.indexed_root_expr_id {
    Some(id) => id
    None => fail("expected root expr id")
  }
  let instr_id = cache.indexed_expr_nodes[expr_id].instr_ids[0]
  let process_budget = Ref::new(64)
  vq_active_stats.val = Some(cache.stats)
  let out = match
    vq_process_instr(
      instr,
      env,
      false,
      false,
      process_budget,
      cache,
      VQPassOptions::new(),
      instr_id=Some(instr_id),
    ) {
    Some(next) => next
    None => fail("expected if-arm inversion rewrite result")
  }
  vq_active_stats.val = None
  match out.kind {
    TInstrKind::TIf(bt, cond, then_body, None) => {
      assert_eq(bt, BlockType::void_())
      assert_eq(
        cond,
        TInstr::unary(UnaryOp::i32_eqz(), TInstr::local_get(LocalIdx::new(0))),
      )
      assert_eq(then_body, original_else)
    }
    _ => fail("expected if-arm inversion rewrite result")
  }
  assert_eq(cache.stats.rewrite_type_stack_calls.val, 0)
  assert_eq(cache.stats.control_transfer_scans.val, 0)
}

///|
test "vacuum changed if-else arm reuses indexed control metadata for inversion guard" {
  let original_condition = TInstr::local_get(LocalIdx::new(0))
  let original_else = TExpr::new([
    TInstr::drop(TInstr::local_tee(LocalIdx::new(1), TInstr::i32_const(I32(9)))),
  ])
  let instr = TInstr::if_(
    BlockType::void_(),
    original_condition,
    TExpr::new([TInstr::nop()]),
    Some(original_else),
  )
  let body = TExpr::new([instr])
  let env = Env::new()
    .with_module(Module::new())
    .with_locals([ValType::i32(), ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let seed_budget = Ref::new(96)
  assert_true(vq_seed_texpr_facts_bounded(body, env, cache, seed_budget))
  let expr_id = match cache.indexed_root_expr_id {
    Some(id) => id
    None => fail("expected root expr id")
  }
  let instr_id = cache.indexed_expr_nodes[expr_id].instr_ids[0]
  let process_budget = Ref::new(96)
  vq_active_stats.val = Some(cache.stats)
  let out = match
    vq_process_instr(
      instr,
      env,
      false,
      false,
      process_budget,
      cache,
      VQPassOptions::new(),
      instr_id=Some(instr_id),
    ) {
    Some(next) => next
    None => fail("expected if-arm inversion rewrite result")
  }
  vq_active_stats.val = None
  match out.kind {
    TInstrKind::TIf(
      VoidBlockType,
      {
        kind: TInstrKind::TUnary(
          I32EqzOp,
          { kind: TInstrKind::TLocalGet(LocalIdx(cond_idx)), .. }
        ),
        ..,
      },
      then_body,
      None
    ) => {
      assert_eq(cond_idx, 0U)
      match then_body.instrs {
        [
          {
            kind: TInstrKind::TLocalSet(
              LocalIdx(set_idx),
              { kind: TInstrKind::TI32Const(I32(v)), .. }
            ),
            ..,
          },
        ] => {
          assert_eq(set_idx, 1U)
          assert_eq(v, 9)
        }
        _ => fail("expected rewritten else arm to invert as local.set body")
      }
    }
    _ => fail("expected if-arm inversion result with rewritten else arm")
  }
  assert_eq(cache.stats.control_transfer_scans.val, 0)
}

///|
test "vacuum changed constant-if chosen arm reuses indexed break metadata" {
  let instr = TInstr::if_(
    BlockType::void_(),
    TInstr::i32_const(I32(1)),
    TExpr::new([
      TInstr::drop(
        TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(9))),
      ),
    ]),
    Some(TExpr::new([TInstr::nop()])),
  )
  let body = TExpr::new([instr])
  let env = Env::new().with_module(Module::new()).with_locals([ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let seed_budget = Ref::new(96)
  assert_true(vq_seed_texpr_facts_bounded(body, env, cache, seed_budget))
  let expr_id = match cache.indexed_root_expr_id {
    Some(id) => id
    None => fail("expected root expr id")
  }
  let instr_id = cache.indexed_expr_nodes[expr_id].instr_ids[0]
  let process_budget = Ref::new(96)
  let out = match
    vq_process_instr(
      instr,
      env,
      false,
      false,
      process_budget,
      cache,
      VQPassOptions::new(),
      instr_id=Some(instr_id),
    ) {
    Some(next) => next
    None => fail("expected constant-if simplification result")
  }
  assert_eq(out, TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(9))))
  assert_eq(cache.stats.break_scan_calls.val, 0)
}

///|
test "vacuum traps-never-happen unreachable-arm rewrite reuses indexed break metadata" {
  let instr = TInstr::if_(
    BlockType::val_type(ValType::i32()),
    TInstr::local_get(LocalIdx::new(0)),
    TExpr::new([TInstr::unreachable_()]),
    Some(TExpr::new([TInstr::i32_const(I32(7))])),
  )
  let body = TExpr::new([instr])
  let env = Env::new().with_module(Module::new()).with_locals([ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let seed_budget = Ref::new(96)
  assert_true(vq_seed_texpr_facts_bounded(body, env, cache, seed_budget))
  let expr_id = match cache.indexed_root_expr_id {
    Some(id) => id
    None => fail("expected root expr id")
  }
  let instr_id = cache.indexed_expr_nodes[expr_id].instr_ids[0]
  let process_budget = Ref::new(96)
  let out = match
    vq_process_instr(
      instr,
      env,
      true,
      true,
      process_budget,
      cache,
      VQPassOptions::new(traps_never_happen=true),
      instr_id=Some(instr_id),
    ) {
    Some(next) => next
    None => fail("expected traps-never-happen rewrite result")
  }
  match out.kind {
    TInstrKind::TBlock(
      ValTypeBlockType(NumTypeValType(I32NumType)),
      {
        instrs: [
          {
            kind: TInstrKind::TDrop(
              { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. }
            ),
            ..,
          },
          { kind: TInstrKind::TI32Const(I32(7)), .. },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail(
        "expected value block from traps-never-happen unreachable-arm rewrite: \{out}",
      )
  }
  assert_eq(cache.stats.break_scan_calls.val, 0)
}

///|
test "vacuum indexed dropped-result block avoids generic value-break helper" {
  let original_last = TInstr::binary(
    BinaryOp::i32_add(),
    TInstr::i32_const(I32(1)),
    TInstr::i32_const(I32(2)),
  )
  let instr = TInstr::drop(
    TInstr::block(
      BlockType::val_type(ValType::i32()),
      TExpr::new([
        TInstr::br_if(LabelIdx::new(0), TInstr::local_get(LocalIdx::new(0)), [
          TInstr::i32_const(I32(2)),
        ]),
        original_last,
      ]),
    ),
  )
  let body = TExpr::new([instr])
  let env = Env::new().with_module(Module::new()).with_locals([ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let seed_budget = Ref::new(64)
  assert_true(vq_seed_texpr_facts_bounded(body, env, cache, seed_budget))
  let expr_id = match cache.indexed_root_expr_id {
    Some(id) => id
    None => fail("expected root expr id")
  }
  let instr_id = cache.indexed_expr_nodes[expr_id].instr_ids[0]
  let process_budget = Ref::new(64)
  let instr_entries_before = vq_analysis_cache_instr_entry_count(cache)
  let out = match
    vq_process_instr(
      instr,
      env,
      false,
      false,
      process_budget,
      cache,
      VQPassOptions::new(),
      instr_id=Some(instr_id),
    ) {
    Some(next) => next
    None => fail("expected dropped result block rewrite result")
  }
  match out.kind {
    TInstrKind::TDrop(
      {
        kind: TInstrKind::TBlock(
          ValTypeBlockType(NumTypeValType(I32NumType)),
          {
            instrs: [
              {
                kind: TInstrKind::TBrIf(
                  LabelIdx(depth),
                  { kind: TInstrKind::TLocalGet(LocalIdx(local_idx)), .. },
                  [{ kind: TInstrKind::TI32Const(I32(v)), .. }]
                ),
                ..,
              },
              {
                kind: TInstrKind::TBinary(
                  I32AddOp,
                  { kind: TInstrKind::TI32Const(I32(left)), .. },
                  { kind: TInstrKind::TI32Const(I32(right)), .. }
                ),
                ..,
              },
            ],
            ..,
          }
        ),
        ..,
      }
    ) => {
      assert_eq(depth, 0U)
      assert_eq(local_idx, 0U)
      assert_eq(v, 2)
      assert_eq(left, 1)
      assert_eq(right, 2)
    }
    _ =>
      fail(
        "expected dropped result block with value break to remain intact: \{out}",
      )
  }
  assert_eq(cache.stats.value_break_lub_calls.val, 0)
  assert_eq(vq_analysis_cache_instr_entry_count(cache), instr_entries_before)
}

///|
test "vacuum indexed dropped-if arm result check avoids generic type cache" {
  let original_else_value = TInstr::local_tee(
    LocalIdx::new(1),
    TInstr::i32_const(I32(9)),
  )
  let instr = TInstr::drop(
    TInstr::if_(
      BlockType::val_type(ValType::i32()),
      TInstr::local_get(LocalIdx::new(0)),
      TExpr::new([TInstr::unreachable_()]),
      Some(TExpr::new([original_else_value])),
    ),
  )
  let body = TExpr::new([instr])
  let env = Env::new()
    .with_module(Module::new())
    .with_locals([ValType::i32(), ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let seed_budget = Ref::new(96)
  assert_true(vq_seed_texpr_facts_bounded(body, env, cache, seed_budget))
  let expr_id = match cache.indexed_root_expr_id {
    Some(id) => id
    None => fail("expected root expr id")
  }
  let instr_id = cache.indexed_expr_nodes[expr_id].instr_ids[0]
  let process_budget = Ref::new(96)
  let instr_entries_before = vq_analysis_cache_instr_entry_count(cache)
  let out = match
    vq_process_instr(
      instr,
      env,
      false,
      false,
      process_budget,
      cache,
      VQPassOptions::new(),
      instr_id=Some(instr_id),
    ) {
    Some(next) => next
    None => fail("expected dropped if rewrite result")
  }
  match out.kind {
    TInstrKind::TIf(VoidBlockType, cond, then_body, Some(other_body)) => {
      assert_eq(cond, TInstr::local_get(LocalIdx::new(0)))
      assert_eq(then_body, TExpr::new([TInstr::unreachable_()]))
      assert_eq(other_body, TExpr::new([TInstr::drop(original_else_value)]))
    }
    _ =>
      fail(
        "expected dropped-if rewrite to move drop into reachable arm: \{out}",
      )
  }
  assert_eq(vq_analysis_cache_instr_entry_count(cache), instr_entries_before)
}

///|
test "vacuum changed dropped-if arm result check reuses indexed arm metadata" {
  let original_else_prefix = TInstr::drop(
    TInstr::local_tee(LocalIdx::new(1), TInstr::i32_const(I32(9))),
  )
  let original_else_tail = TInstr::i32_const(I32(11))
  let instr = TInstr::drop(
    TInstr::if_(
      BlockType::val_type(ValType::i32()),
      TInstr::local_get(LocalIdx::new(0)),
      TExpr::new([TInstr::unreachable_()]),
      Some(TExpr::new([original_else_prefix, original_else_tail])),
    ),
  )
  let body = TExpr::new([instr])
  let env = Env::new()
    .with_module(Module::new())
    .with_locals([ValType::i32(), ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let seed_budget = Ref::new(128)
  assert_true(vq_seed_texpr_facts_bounded(body, env, cache, seed_budget))
  let expr_id = match cache.indexed_root_expr_id {
    Some(id) => id
    None => fail("expected root expr id")
  }
  let instr_id = cache.indexed_expr_nodes[expr_id].instr_ids[0]
  let process_budget = Ref::new(128)
  let instr_entries_before = vq_analysis_cache_instr_entry_count(cache)
  let out = match
    vq_process_instr(
      instr,
      env,
      false,
      false,
      process_budget,
      cache,
      VQPassOptions::new(),
      instr_id=Some(instr_id),
    ) {
    Some(next) => next
    None => fail("expected dropped if rewrite result")
  }
  match out.kind {
    TInstrKind::TIf(VoidBlockType, cond, then_body, Some(other_body)) => {
      assert_eq(cond, TInstr::local_get(LocalIdx::new(0)))
      assert_eq(then_body, TExpr::new([TInstr::unreachable_()]))
      assert_eq(
        other_body,
        TExpr::new([
          TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(9))),
          TInstr::drop(TInstr::i32_const(I32(11))),
        ]),
      )
    }
    _ =>
      fail(
        "expected dropped-if rewrite to keep unreachable then and drop rewritten else value: \{out}",
      )
  }
  assert_eq(vq_analysis_cache_instr_entry_count(cache), instr_entries_before)
}

///|
test "vacuum indexed merged drop-if arms avoid generic type cache" {
  let t_i32 = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("left"),
          ExternType::func(TypeIdx::new(0)),
        ),
        Import::new(
          Name::new("env"),
          Name::new("right"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
  let original_left = TInstr::call(FuncIdx::new(0), [])
  let original_right = TInstr::call(FuncIdx::new(1), [])
  let instr = TInstr::if_(
    BlockType::void_(),
    TInstr::local_get(LocalIdx::new(0)),
    TExpr::new([TInstr::drop(original_left)]),
    Some(TExpr::new([TInstr::drop(original_right)])),
  )
  let body = TExpr::new([instr])
  let env = Env::new().with_module(mod).with_locals([ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let seed_budget = Ref::new(96)
  assert_true(vq_seed_texpr_facts_bounded(body, env, cache, seed_budget))
  let expr_id = match cache.indexed_root_expr_id {
    Some(id) => id
    None => fail("expected root expr id")
  }
  let instr_id = cache.indexed_expr_nodes[expr_id].instr_ids[0]
  let process_budget = Ref::new(96)
  let instr_entries_before = vq_analysis_cache_instr_entry_count(cache)
  let out = match
    vq_process_instr(
      instr,
      env,
      false,
      false,
      process_budget,
      cache,
      VQPassOptions::new(),
      instr_id=Some(instr_id),
    ) {
    Some(next) => next
    None => fail("expected merged dropped if rewrite result")
  }
  assert_eq(
    out,
    TInstr::drop(
      TInstr::if_(
        BlockType::val_type(ValType::i32()),
        TInstr::local_get(LocalIdx::new(0)),
        TExpr::new([original_left]),
        Some(TExpr::new([original_right])),
      ),
    ),
  )
  assert_eq(vq_analysis_cache_instr_entry_count(cache), instr_entries_before)
}

///|
test "vacuum changed dropped-result block reuses indexed value-break metadata when control-flow is unchanged" {
  let instr = TInstr::drop(
    TInstr::block(
      BlockType::val_type(ValType::i32()),
      TExpr::new([
        TInstr::drop(
          TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(1))),
        ),
        TInstr::br_if(LabelIdx::new(0), TInstr::local_get(LocalIdx::new(1)), [
          TInstr::i32_const(I32(2)),
        ]),
        TInstr::i32_const(I32(3)),
      ]),
    ),
  )
  let body = TExpr::new([instr])
  let env = Env::new()
    .with_module(Module::new())
    .with_locals([ValType::i32(), ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let seed_budget = Ref::new(96)
  assert_true(vq_seed_texpr_facts_bounded(body, env, cache, seed_budget))
  let expr_id = match cache.indexed_root_expr_id {
    Some(id) => id
    None => fail("expected root expr id")
  }
  let instr_id = cache.indexed_expr_nodes[expr_id].instr_ids[0]
  let process_budget = Ref::new(96)
  let out = match
    vq_process_instr(
      instr,
      env,
      false,
      false,
      process_budget,
      cache,
      VQPassOptions::new(),
      instr_id=Some(instr_id),
    ) {
    Some(next) => next
    None => fail("expected dropped result block rewrite result")
  }
  match out.kind {
    TInstrKind::TDrop(
      {
        kind: TInstrKind::TBlock(
          ValTypeBlockType(NumTypeValType(I32NumType)),
          {
            instrs: [
              {
                kind: TInstrKind::TLocalSet(
                  LocalIdx(local_idx),
                  { kind: TInstrKind::TI32Const(I32(set_v)), .. }
                ),
                ..,
              },
              {
                kind: TInstrKind::TBrIf(
                  LabelIdx(depth),
                  { kind: TInstrKind::TLocalGet(LocalIdx(cond_idx)), .. },
                  [{ kind: TInstrKind::TI32Const(I32(br_v)), .. }]
                ),
                ..,
              },
              { kind: TInstrKind::TI32Const(I32(last)), .. },
            ],
            ..,
          }
        ),
        ..,
      }
    ) => {
      assert_eq(local_idx, 0U)
      assert_eq(set_v, 1)
      assert_eq(depth, 0U)
      assert_eq(cond_idx, 1U)
      assert_eq(br_v, 2)
      assert_eq(last, 3)
    }
    _ =>
      fail(
        "expected dropped result block fallback path to keep block and rewrite inner tee: \{out}",
      )
  }
  assert_eq(cache.stats.value_break_lub_calls.val, 0)
}

///|
test "vacuum indexed try_table removal avoids generic throws cache" {
  let original_body = TExpr::new([TInstr::i32_const(I32(77))])
  let instr = TInstr::try_table(
    BlockType::val_type(ValType::i32()),
    [Catch::all(LabelIdx::new(0))],
    original_body,
  )
  let body = TExpr::new([instr])
  let env = Env::new().with_module(Module::new())
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let seed_budget = Ref::new(64)
  assert_true(vq_seed_texpr_facts_bounded(body, env, cache, seed_budget))
  let expr_id = match cache.indexed_root_expr_id {
    Some(id) => id
    None => fail("expected root expr id")
  }
  let instr_id = cache.indexed_expr_nodes[expr_id].instr_ids[0]
  let process_budget = Ref::new(64)
  let out = match
    vq_process_instr(
      instr,
      env,
      true,
      true,
      process_budget,
      cache,
      VQPassOptions::new(),
      instr_id=Some(instr_id),
    ) {
    Some(next) => next
    None => fail("expected try_table rewrite result")
  }
  assert_eq(out, TInstr::i32_const(I32(77)))
}

///|
test "vacuum changed try_table body reuses indexed metadata for throws and break checks" {
  let original_body = TExpr::new([
    TInstr::drop(TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(9)))),
    TInstr::i32_const(I32(77)),
  ])
  let instr = TInstr::try_table(
    BlockType::val_type(ValType::i32()),
    [Catch::all(LabelIdx::new(0))],
    original_body,
  )
  let body = TExpr::new([instr])
  let env = Env::new().with_module(Module::new()).with_locals([ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let seed_budget = Ref::new(96)
  assert_true(vq_seed_texpr_facts_bounded(body, env, cache, seed_budget))
  let expr_id = match cache.indexed_root_expr_id {
    Some(id) => id
    None => fail("expected root expr id")
  }
  let instr_id = cache.indexed_expr_nodes[expr_id].instr_ids[0]
  let process_budget = Ref::new(96)
  let out = match
    vq_process_instr(
      instr,
      env,
      true,
      true,
      process_budget,
      cache,
      VQPassOptions::new(),
      instr_id=Some(instr_id),
    ) {
    Some(next) => next
    None => fail("expected try_table rewrite result")
  }
  match out.kind {
    TInstrKind::TBlock(
      ValTypeBlockType(NumTypeValType(I32NumType)),
      {
        instrs: [
          {
            kind: TInstrKind::TLocalSet(
              LocalIdx(local_idx),
              { kind: TInstrKind::TI32Const(I32(set_v)), .. }
            ),
            ..,
          },
          { kind: TInstrKind::TI32Const(I32(last_v)), .. },
        ],
        ..,
      }
    ) => {
      assert_eq(local_idx, 0U)
      assert_eq(set_v, 9)
      assert_eq(last_v, 77)
    }
    _ =>
      fail(
        "expected changed try_table body to simplify to value block with rewritten local.set: \{out}",
      )
  }
  assert_eq(cache.stats.break_scan_calls.val, 0)
}

///|
test "vacuum full-tier budget exhaustion falls back to degraded local.tee drop rewrite" {
  let instr = TInstr::drop(
    TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(9))),
  )
  let env = Env::new().with_module(Module::new()).with_locals([ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  cache.midpass_degraded_budget = Some(Ref::new(16))
  let budget = Ref::new(0)
  let out = match
    vq_process_instr(
      instr,
      env,
      false,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected tier-fallback rewrite result")
  }
  assert_eq(out, TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(9))))
  assert_eq(cache.stats.tier_fallback_calls.val, 1)
  assert_eq(cache.stats.tier_fallback_changes.val, 1)
}

///|
test "vacuum full-tier fallback remains bounded when cheap-tier budget is exhausted" {
  let instr = TInstr::drop(
    TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(9))),
  )
  let env = Env::new().with_module(Module::new()).with_locals([ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  cache.midpass_degraded_budget = Some(Ref::new(0))
  let budget = Ref::new(0)
  let out = match
    vq_process_instr(
      instr,
      env,
      false,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected bounded tier-fallback result")
  }
  assert_eq(out, instr)
  assert_eq(cache.stats.tier_fallback_calls.val, 1)
  assert_eq(cache.stats.tier_fallback_changes.val, 0)
}

///|
test "vacuum sequence uses cheap-tier fallback for remaining items after full budget depletes" {
  let items = [
    TInstr::drop(TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(1)))),
    TInstr::drop(TInstr::local_tee(LocalIdx::new(1), TInstr::i32_const(I32(2)))),
  ]
  let env = Env::new()
    .with_module(Module::new())
    .with_locals([ValType::i32(), ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  cache.midpass_degraded_budget = Some(Ref::new(16))
  let budget = Ref::new(1)
  let seq = vq_optimize_sequence(
    items,
    env,
    [],
    false,
    budget,
    cache,
    VQPassOptions::new(),
  )
  assert_eq(seq.items, [
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(1))),
    TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(2))),
  ])
  assert_true(seq.changed)
  assert_true(cache.stats.tier_fallback_calls.val >= 1)
  assert_true(cache.stats.tier_fallback_changes.val >= 1)
}

///|
test "vacuum sequence switches once to cheap-tier for remaining suffix" {
  let items = [
    TInstr::drop(TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(1)))),
    TInstr::drop(TInstr::local_tee(LocalIdx::new(1), TInstr::i32_const(I32(2)))),
  ]
  let env = Env::new()
    .with_module(Module::new())
    .with_locals([ValType::i32(), ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  cache.midpass_degraded_budget = Some(Ref::new(16))
  let budget = Ref::new(0)
  let seq = vq_optimize_sequence(
    items,
    env,
    [],
    false,
    budget,
    cache,
    VQPassOptions::new(),
  )
  assert_eq(seq.items, [
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(1))),
    TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(2))),
  ])
  assert_true(seq.changed)
  assert_eq(cache.stats.tier_fallback_calls.val, 1)
  assert_eq(cache.stats.tier_fallback_changes.val, 1)
}

///|
test "vacuum vq_optimize budget exhaustion falls back to cheap-tier rewrite" {
  let instr = TInstr::drop(
    TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(11))),
  )
  let env = Env::new().with_module(Module::new()).with_locals([ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  cache.midpass_degraded_budget = Some(Ref::new(8))
  let budget = Ref::new(0)
  let out = match
    vq_optimize(instr, false, false, env, budget, cache, VQPassOptions::new()) {
    Some(next) => next
    None => fail("expected fallback optimize result")
  }
  assert_eq(
    out,
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(11))),
  )
  assert_eq(cache.stats.tier_fallback_calls.val, 1)
  assert_eq(cache.stats.tier_fallback_changes.val, 1)
}

///|
test "vacuum degraded mode traps-never-happen rewrites unreachable if arm" {
  let t_i32 = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], [], TExpr::new([TInstr::i32_const(I32(7))])),
      ]),
    )
  let cond = TInstr::local_get(LocalIdx::new(0))
  let live = TInstr::drop(TInstr::call(FuncIdx::new(0), []))
  let instr = TInstr::if_(
    BlockType::void_(),
    cond,
    TExpr::new([TInstr::unreachable_()]),
    Some(TExpr::new([live])),
  )
  let env = Env::new().with_module(mod).with_locals([ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(128)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(traps_never_happen=true),
    ) {
    Some(next) => next
    None => fail("expected degraded traps-never-happen rewrite result")
  }
  assert_eq(
    out,
    TInstr::block(BlockType::void_(), TExpr::new([TInstr::drop(cond), live])),
  )
}

///|
test "vacuum vq_optimize fallback forwards traps-never-happen options" {
  let t_i32 = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], [], TExpr::new([TInstr::i32_const(I32(7))])),
      ]),
    )
  let cond = TInstr::local_get(LocalIdx::new(0))
  let live = TInstr::drop(TInstr::call(FuncIdx::new(0), []))
  let instr = TInstr::if_(
    BlockType::void_(),
    cond,
    TExpr::new([TInstr::unreachable_()]),
    Some(TExpr::new([live])),
  )
  let env = Env::new().with_module(mod).with_locals([ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  cache.midpass_degraded_budget = Some(Ref::new(64))
  let budget = Ref::new(0)
  let out = match
    vq_optimize(
      instr,
      false,
      false,
      env,
      budget,
      cache,
      VQPassOptions::new(traps_never_happen=true),
    ) {
    Some(next) => next
    None => fail("expected traps-never-happen fallback optimize result")
  }
  assert_eq(
    out,
    TInstr::block(BlockType::void_(), TExpr::new([TInstr::drop(cond), live])),
  )
}

///|
test "vacuum degraded mode keeps deep wrapper blocks while still rewriting local.tee drop" {
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [ValType::i32()],
          TExpr::new([
            vq_make_nested_void_blocks(
              48,
              TInstr::drop(
                TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(9))),
              ),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  assert_eq(validate_module(out), Ok(()))
  match vq_first_func_body(out).instrs {
    [single] =>
      match vq_nested_void_block_depth_to_local_set(single) {
        Some(depth) => assert_true(depth >= 24)
        None =>
          fail(
            "expected degraded vacuum to preserve deep wrapper blocks around rewritten local.set",
          )
      }
    _ =>
      fail("expected degraded vacuum output to keep a single deep wrapper tree")
  }
}

///|
test "vacuum degraded mode folds constant true if into chosen then arm" {
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [ValType::i32()],
          TExpr::new([
            vq_make_nested_void_blocks(
              48,
              TInstr::if_(
                BlockType::void_(),
                TInstr::i32_const(I32(1)),
                TExpr::new([
                  TInstr::drop(
                    TInstr::local_tee(
                      LocalIdx::new(0),
                      TInstr::i32_const(I32(9)),
                    ),
                  ),
                ]),
                None,
              ),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  assert_eq(validate_module(out), Ok(()))
  match vq_first_func_body(out).instrs {
    [single] =>
      match vq_nested_void_block_depth_to_local_set(single) {
        Some(depth) => assert_true(depth >= 24)
        None =>
          fail(
            "expected degraded vacuum to fold constant true if down to rewritten local.set",
          )
      }
    _ =>
      fail(
        "expected degraded constant-true output to keep a single deep wrapper tree",
      )
  }
}

///|
test "vacuum degraded mode folds constant false if into chosen else arm" {
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [ValType::i32()],
          TExpr::new([
            vq_make_nested_void_blocks(
              48,
              TInstr::if_(
                BlockType::void_(),
                TInstr::i32_const(I32(0)),
                TExpr::new([TInstr::drop(TInstr::i32_const(I32(1)))]),
                Some(
                  TExpr::new([
                    TInstr::drop(
                      TInstr::local_tee(
                        LocalIdx::new(0),
                        TInstr::i32_const(I32(9)),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  assert_eq(validate_module(out), Ok(()))
  match vq_first_func_body(out).instrs {
    [single] =>
      match vq_nested_void_block_depth_to_local_set(single) {
        Some(depth) => assert_true(depth >= 24)
        None =>
          fail(
            "expected degraded vacuum to fold constant false if down to rewritten local.set",
          )
      }
    _ =>
      fail(
        "expected degraded constant-false output to keep a single deep wrapper tree",
      )
  }
}

///|
test "vacuum degraded mode peels dropped unary wrappers around calls" {
  let t_i32 = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], [], TExpr::new([TInstr::i32_const(I32(7))])),
      ]),
    )
  let instr = vq_make_nested_void_blocks(
    32,
    TInstr::drop(
      TInstr::unary(UnaryOp::i32_eqz(), TInstr::call(FuncIdx::new(0), [])),
    ),
  )
  let env = Env::new().with_module(mod)
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(512)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded dropped-unary rewrite result")
  }
  match vq_nested_void_block_depth_to_dropped_call(out) {
    Some(depth) => assert_true(depth >= 16)
    None =>
      fail(
        "expected degraded vacuum to peel dropped unary wrapper down to dropped call",
      )
  }
}

///|
test "vacuum degraded mode collapses nested dropped call wrappers" {
  let t_i32 = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], [], TExpr::new([TInstr::i32_const(I32(7))])),
      ]),
    )
  let call = TInstr::call(FuncIdx::new(0), [])
  let instr = TInstr::drop(TInstr::drop(call))
  let env = Env::new().with_module(mod)
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded nested drop rewrite result")
  }
  assert_eq(out, TInstr::drop(call))
}

///|
test "vacuum degraded mode removes try_table with empty optimized void body" {
  let instr = TInstr::try_table(
    BlockType::void_(),
    [Catch::all(LabelIdx::new(0))],
    TExpr::new([TInstr::i32_const(I32(7))]),
  )
  let env = Env::new().with_module(Module::new())
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded try_table rewrite result")
  }
  assert_eq(out, TInstr::nop())
}

///|
test "vacuum degraded mode nops pure typed condition when both if arms optimize to nop" {
  let instr = TInstr::if_(
    BlockType::void_(),
    TInstr::local_get(LocalIdx::new(0)),
    TExpr::new([TInstr::nop()]),
    Some(TExpr::new([TInstr::drop(TInstr::i32_const(I32(7)))])),
  )
  let env = Env::new().with_module(Module::new()).with_locals([ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded if cleanup result")
  }
  assert_eq(out, TInstr::nop())
}

///|
test "vacuum degraded mode keeps drop around effectful typed condition when both if arms optimize to nop" {
  let t_i32 = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], [], TExpr::new([TInstr::i32_const(I32(7))])),
      ]),
    )
  let condition = TInstr::call(FuncIdx::new(0), [])
  let instr = TInstr::if_(
    BlockType::void_(),
    condition,
    TExpr::new([TInstr::nop()]),
    Some(TExpr::new([TInstr::drop(TInstr::i32_const(I32(7)))])),
  )
  let env = Env::new().with_module(mod)
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded if cleanup result")
  }
  assert_eq(out, TInstr::drop(condition))
}

///|
test "vacuum degraded mode peels dropped ref.is_null around pure local.get" {
  let instr = TInstr::drop(
    TInstr::ref_is_null(TInstr::local_get(LocalIdx::new(0))),
  )
  let env = Env::new()
    .with_module(Module::new())
    .with_locals([ValType::externref()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded ref.is_null drop result")
  }
  assert_eq(out, TInstr::nop())
}

///|
test "vacuum degraded mode keeps drop around effectful child under ref.is_null" {
  let t_ref = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::externref()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_ref]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([TInstr::ref_null(HeapType::abs(AbsHeapType::extern_()))]),
        ),
      ]),
    )
  let condition = TInstr::call(FuncIdx::new(0), [])
  let instr = TInstr::drop(TInstr::ref_is_null(condition))
  let env = Env::new().with_module(mod)
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded ref.is_null drop result")
  }
  assert_eq(out, TInstr::drop(condition))
}

///|
test "vacuum degraded mode peels dropped any.convert_extern around pure local.get" {
  let instr = TInstr::drop(
    TInstr::any_convert_extern(TInstr::local_get(LocalIdx::new(0))),
  )
  let env = Env::new()
    .with_module(Module::new())
    .with_locals([ValType::externref()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded any.convert_extern drop result")
  }
  assert_eq(out, TInstr::nop())
}

///|
test "vacuum degraded mode keeps drop around effectful child under any.convert_extern" {
  let t_ref = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::externref()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_ref]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([TInstr::ref_null(HeapType::abs(AbsHeapType::extern_()))]),
        ),
      ]),
    )
  let condition = TInstr::call(FuncIdx::new(0), [])
  let instr = TInstr::drop(TInstr::any_convert_extern(condition))
  let env = Env::new().with_module(mod)
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded any.convert_extern drop result")
  }
  assert_eq(out, TInstr::drop(condition))
}

///|
test "vacuum degraded mode peels dropped extern.convert_any around pure local.get" {
  let instr = TInstr::drop(
    TInstr::extern_convert_any(TInstr::local_get(LocalIdx::new(0))),
  )
  let env = Env::new()
    .with_module(Module::new())
    .with_locals([ValType::anyref()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded extern.convert_any drop result")
  }
  assert_eq(out, TInstr::nop())
}

///|
test "vacuum degraded mode keeps drop around effectful child under extern.convert_any" {
  let t_ref = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::anyref()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_ref]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::any_convert_extern(
              TInstr::ref_null(HeapType::abs(AbsHeapType::extern_())),
            ),
          ]),
        ),
      ]),
    )
  let condition = TInstr::call(FuncIdx::new(0), [])
  let instr = TInstr::drop(TInstr::extern_convert_any(condition))
  let env = Env::new().with_module(mod)
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded extern.convert_any drop result")
  }
  assert_eq(out, TInstr::drop(condition))
}

///|
test "vacuum degraded mode peels dropped i8x16.splat around pure local.get" {
  let instr = TInstr::drop(
    TInstr::i8x16_splat(TInstr::local_get(LocalIdx::new(0))),
  )
  let env = Env::new().with_module(Module::new()).with_locals([ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded i8x16.splat drop result")
  }
  assert_eq(out, TInstr::nop())
}

///|
test "vacuum degraded mode keeps drop around effectful child under i8x16.splat" {
  let t_ref = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_ref]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], [], TExpr::new([TInstr::i32_const(I32(0))])),
      ]),
    )
  let condition = TInstr::call(FuncIdx::new(0), [])
  let instr = TInstr::drop(TInstr::i8x16_splat(condition))
  let env = Env::new().with_module(mod)
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded i8x16.splat drop result")
  }
  assert_eq(out, TInstr::drop(condition))
}

///|
test "vacuum degraded mode peels dropped f64x2.splat around pure local.get" {
  let instr = TInstr::drop(
    TInstr::f64x2_splat(TInstr::local_get(LocalIdx::new(0))),
  )
  let env = Env::new().with_module(Module::new()).with_locals([ValType::f64()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded f64x2.splat drop result")
  }
  assert_eq(out, TInstr::nop())
}

///|
test "vacuum degraded mode keeps drop around effectful child under f64x2.splat" {
  let t_ref = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::f64()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_ref]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], [], TExpr::new([TInstr::f64_const(F64(0.0))])),
      ]),
    )
  let condition = TInstr::call(FuncIdx::new(0), [])
  let instr = TInstr::drop(TInstr::f64x2_splat(condition))
  let env = Env::new().with_module(mod)
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded f64x2.splat drop result")
  }
  assert_eq(out, TInstr::drop(condition))
}

///|
test "vacuum degraded mode peels dropped i8x16.extract_lane_u around pure local.get" {
  let instr = TInstr::drop(
    TInstr::extract_lane(
      @lib.ExtractLaneOp::i8x16_extract_lane_u(),
      LaneIdx::new(3),
      TInstr::local_get(LocalIdx::new(0)),
    ),
  )
  let env = Env::new().with_module(Module::new()).with_locals([ValType::v128()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded i8x16.extract_lane_u drop result")
  }
  assert_eq(out, TInstr::nop())
}

///|
test "vacuum degraded mode keeps drop around effectful child under i8x16.extract_lane_u" {
  let t_ref = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::v128()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_ref]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::v128_const(
              0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
            ),
          ]),
        ),
      ]),
    )
  let condition = TInstr::call(FuncIdx::new(0), [])
  let instr = TInstr::drop(
    TInstr::extract_lane(
      @lib.ExtractLaneOp::i8x16_extract_lane_u(),
      LaneIdx::new(3),
      condition,
    ),
  )
  let env = Env::new().with_module(mod)
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded i8x16.extract_lane_u drop result")
  }
  assert_eq(out, TInstr::drop(condition))
}

///|
test "vacuum degraded mode peels dropped f64x2.extract_lane around pure local.get" {
  let instr = TInstr::drop(
    TInstr::extract_lane(
      @lib.ExtractLaneOp::f64x2_extract_lane(),
      LaneIdx::new(1),
      TInstr::local_get(LocalIdx::new(0)),
    ),
  )
  let env = Env::new().with_module(Module::new()).with_locals([ValType::v128()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded f64x2.extract_lane drop result")
  }
  assert_eq(out, TInstr::nop())
}

///|
test "vacuum degraded mode keeps drop around effectful child under f64x2.extract_lane" {
  let t_ref = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::v128()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_ref]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::v128_const(
              0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
            ),
          ]),
        ),
      ]),
    )
  let condition = TInstr::call(FuncIdx::new(0), [])
  let instr = TInstr::drop(
    TInstr::extract_lane(
      @lib.ExtractLaneOp::f64x2_extract_lane(),
      LaneIdx::new(1),
      condition,
    ),
  )
  let env = Env::new().with_module(mod)
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded f64x2.extract_lane drop result")
  }
  assert_eq(out, TInstr::drop(condition))
}

///|
test "vacuum degraded mode peels dropped ref.test around pure local.get" {
  let funcref_nullable = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let instr = TInstr::drop(
    TInstr::ref_test(
      true,
      HeapType::abs(AbsHeapType::func()),
      TInstr::local_get(LocalIdx::new(0)),
    ),
  )
  let env = Env::new()
    .with_module(Module::new())
    .with_locals([funcref_nullable])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded ref.test drop result")
  }
  assert_eq(out, TInstr::nop())
}

///|
test "vacuum degraded mode keeps drop around effectful child under ref.test" {
  let funcref_nullable = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let t_ref = RecType::new(
    SubType::comp_type(CompType::func([], [funcref_nullable])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_ref]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([TInstr::ref_null(HeapType::abs(AbsHeapType::func()))]),
        ),
      ]),
    )
  let condition = TInstr::call(FuncIdx::new(0), [])
  let instr = TInstr::drop(
    TInstr::ref_test(true, HeapType::abs(AbsHeapType::func()), condition),
  )
  let env = Env::new().with_module(mod)
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded ref.test drop result")
  }
  assert_eq(out, TInstr::drop(condition))
}

///|
test "vacuum degraded mode peels dropped ref.test_desc around pure local.get" {
  let funcref_nullable = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let instr = TInstr::drop(
    TInstr::ref_test_desc(
      true,
      HeapType::abs(AbsHeapType::func()),
      TInstr::local_get(LocalIdx::new(0)),
    ),
  )
  let env = Env::new()
    .with_module(Module::new())
    .with_locals([funcref_nullable])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded ref.test_desc drop result")
  }
  assert_eq(out, TInstr::nop())
}

///|
test "vacuum degraded mode keeps drop around effectful child under ref.test_desc" {
  let funcref_nullable = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let t_ref = RecType::new(
    SubType::comp_type(CompType::func([], [funcref_nullable])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_ref]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([TInstr::ref_null(HeapType::abs(AbsHeapType::func()))]),
        ),
      ]),
    )
  let condition = TInstr::call(FuncIdx::new(0), [])
  let instr = TInstr::drop(
    TInstr::ref_test_desc(true, HeapType::abs(AbsHeapType::func()), condition),
  )
  let env = Env::new().with_module(mod)
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded ref.test_desc drop result")
  }
  assert_eq(out, TInstr::drop(condition))
}

///|
test "vacuum degraded mode peels dropped i31.get_s around pure local.get" {
  let instr = TInstr::drop(
    TInstr::i31_get_s(TInstr::local_get(LocalIdx::new(0))),
  )
  let env = Env::new()
    .with_module(Module::new())
    .with_locals([ValType::i31ref_nullable()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded i31.get_s drop result")
  }
  assert_eq(out, TInstr::nop())
}

///|
test "vacuum degraded mode keeps drop around effectful child under i31.get_s" {
  let nullable_i31 = ValType::i31ref_nullable()
  let t_ref = RecType::new(
    SubType::comp_type(CompType::func([], [nullable_i31])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_ref]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([TInstr::ref_null(HeapType::abs(AbsHeapType::i31()))]),
        ),
      ]),
    )
  let condition = TInstr::call(FuncIdx::new(0), [])
  let instr = TInstr::drop(TInstr::i31_get_s(condition))
  let env = Env::new().with_module(mod)
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded i31.get_s drop result")
  }
  assert_eq(out, TInstr::drop(condition))
}

///|
test "vacuum degraded mode peels dropped i31.get_u around pure local.get" {
  let instr = TInstr::drop(
    TInstr::i31_get_u(TInstr::local_get(LocalIdx::new(0))),
  )
  let env = Env::new()
    .with_module(Module::new())
    .with_locals([ValType::i31ref_nullable()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded i31.get_u drop result")
  }
  assert_eq(out, TInstr::nop())
}

///|
test "vacuum degraded mode keeps drop around effectful child under i31.get_u" {
  let nullable_i31 = ValType::i31ref_nullable()
  let t_ref = RecType::new(
    SubType::comp_type(CompType::func([], [nullable_i31])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_ref]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([TInstr::ref_null(HeapType::abs(AbsHeapType::i31()))]),
        ),
      ]),
    )
  let condition = TInstr::call(FuncIdx::new(0), [])
  let instr = TInstr::drop(TInstr::i31_get_u(condition))
  let env = Env::new().with_module(mod)
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded i31.get_u drop result")
  }
  assert_eq(out, TInstr::drop(condition))
}

///|
test "vacuum degraded mode peels dropped ref.i31 around pure local.get" {
  let instr = TInstr::drop(TInstr::ref_i31(TInstr::local_get(LocalIdx::new(0))))
  let env = Env::new().with_module(Module::new()).with_locals([ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded ref.i31 drop result")
  }
  assert_eq(out, TInstr::nop())
}

///|
test "vacuum degraded mode keeps drop around effectful child under ref.i31" {
  let t_ref = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_ref]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([Func::t_func([], [], TExpr::new([TInstr::i32_const(0)]))]),
    )
  let condition = TInstr::call(FuncIdx::new(0), [])
  let instr = TInstr::drop(TInstr::ref_i31(condition))
  let env = Env::new().with_module(mod)
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded ref.i31 drop result")
  }
  assert_eq(out, TInstr::drop(condition))
}

///|
test "vacuum degraded mode peels dropped ref.get_desc around pure local.get" {
  let instr = TInstr::drop(
    TInstr::ref_get_desc(TInstr::local_get(LocalIdx::new(0))),
  )
  let env = Env::new()
    .with_module(Module::new())
    .with_locals([
      ValType::ref_type(RefType::new(true, HeapType::abs(AbsHeapType::func()))),
    ])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded ref.get_desc drop result")
  }
  assert_eq(out, TInstr::nop())
}

///|
test "vacuum degraded mode keeps drop around effectful child under ref.get_desc" {
  let t_ref = RecType::new(
    SubType::comp_type(
      CompType::func([], [
        ValType::ref_type(
          RefType::new(true, HeapType::abs(AbsHeapType::func())),
        ),
      ]),
    ),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_ref]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([TInstr::ref_null(HeapType::abs(AbsHeapType::func()))]),
        ),
      ]),
    )
  let condition = TInstr::call(FuncIdx::new(0), [])
  let instr = TInstr::drop(TInstr::ref_get_desc(condition))
  let env = Env::new().with_module(mod)
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded ref.get_desc drop result")
  }
  assert_eq(out, TInstr::drop(condition))
}

///|
test "vacuum degraded mode nops dropped ref.eq around pure locals" {
  let ref_t = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let instr = TInstr::drop(
    TInstr::ref_eq(
      TInstr::local_get(LocalIdx::new(0)),
      TInstr::local_get(LocalIdx::new(1)),
    ),
  )
  let env = Env::new().with_module(Module::new()).with_locals([ref_t, ref_t])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded ref.eq drop result")
  }
  assert_eq(out, TInstr::nop())
}

///|
test "vacuum degraded mode keeps one dropped effectful ref.eq child" {
  let ref_t = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let t_ref = RecType::new(SubType::comp_type(CompType::func([], [ref_t])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_ref]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([TInstr::ref_null(HeapType::abs(AbsHeapType::func()))]),
        ),
      ]),
    )
  let lhs = TInstr::call(FuncIdx::new(0), [])
  let instr = TInstr::drop(
    TInstr::ref_eq(lhs, TInstr::local_get(LocalIdx::new(0))),
  )
  let env = Env::new().with_module(mod).with_locals([ref_t])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded ref.eq drop result")
  }
  assert_eq(out, TInstr::drop(lhs))
}

///|
test "vacuum degraded mode preserves effectful ref.eq child order" {
  let ref_t = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let t_ref = RecType::new(SubType::comp_type(CompType::func([], [ref_t])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_ref]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([TInstr::ref_null(HeapType::abs(AbsHeapType::func()))]),
        ),
        Func::t_func(
          [],
          [],
          TExpr::new([TInstr::ref_null(HeapType::abs(AbsHeapType::func()))]),
        ),
      ]),
    )
  let lhs = TInstr::call(FuncIdx::new(0), [])
  let rhs = TInstr::call(FuncIdx::new(1), [])
  let instr = TInstr::drop(TInstr::ref_eq(lhs, rhs))
  let env = Env::new().with_module(mod)
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded ref.eq drop result")
  }
  assert_eq(
    out,
    TInstr::block(
      BlockType::void_(),
      TExpr::new([TInstr::drop(lhs), TInstr::drop(rhs)]),
    ),
  )
}

///|
test "vacuum degraded mode nops dropped non-trapping binary around pure locals" {
  let instr = TInstr::drop(
    TInstr::binary(
      BinaryOp::i32_add(),
      TInstr::local_get(LocalIdx::new(0)),
      TInstr::local_get(LocalIdx::new(1)),
    ),
  )
  let env = Env::new()
    .with_module(Module::new())
    .with_locals([ValType::i32(), ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded dropped-binary rewrite result")
  }
  assert_eq(out, TInstr::nop())
}

///|
test "vacuum degraded mode preserves dropped non-trapping binary child order" {
  let t_i32 = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], [], TExpr::new([TInstr::i32_const(I32(10))])),
        Func::t_func([], [], TExpr::new([TInstr::i32_const(I32(20))])),
      ]),
    )
  let lhs = TInstr::call(FuncIdx::new(0), [])
  let rhs = TInstr::call(FuncIdx::new(1), [])
  let instr = TInstr::drop(TInstr::binary(BinaryOp::i32_add(), lhs, rhs))
  let env = Env::new().with_module(mod)
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded dropped-binary rewrite result")
  }
  assert_eq(
    out,
    TInstr::block(
      BlockType::void_(),
      TExpr::new([TInstr::drop(lhs), TInstr::drop(rhs)]),
    ),
  )
}

///|
test "vacuum degraded mode keeps dropped trapping binary intact" {
  let instr = TInstr::drop(
    TInstr::binary(
      BinaryOp::i32_div_s(),
      TInstr::local_get(LocalIdx::new(0)),
      TInstr::local_get(LocalIdx::new(1)),
    ),
  )
  let env = Env::new()
    .with_module(Module::new())
    .with_locals([ValType::i32(), ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded dropped-binary rewrite result")
  }
  assert_eq(out, instr)
}

///|
test "vacuum degraded mode nops dropped select around pure locals" {
  let instr = TInstr::drop(
    TInstr::select(
      None,
      TInstr::local_get(LocalIdx::new(2)),
      TInstr::local_get(LocalIdx::new(0)),
      TInstr::local_get(LocalIdx::new(1)),
    ),
  )
  let env = Env::new()
    .with_module(Module::new())
    .with_locals([ValType::i32(), ValType::i32(), ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded select drop result")
  }
  assert_eq(out, TInstr::nop())
}

///|
test "vacuum degraded mode preserves dropped select child order" {
  let t_i32 = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32]))
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(0), TypeIdx::new(0)]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], [], TExpr::new([TInstr::i32_const(I32(10))])),
        Func::t_func([], [], TExpr::new([TInstr::i32_const(I32(20))])),
        Func::t_func([], [], TExpr::new([TInstr::i32_const(I32(1))])),
      ]),
    )
  let if_true = TInstr::call(FuncIdx::new(0), [])
  let if_false = TInstr::call(FuncIdx::new(1), [])
  let condition = TInstr::call(FuncIdx::new(2), [])
  let instr = TInstr::drop(TInstr::select(None, condition, if_true, if_false))
  let env = Env::new().with_module(mod)
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let budget = Ref::new(64)
  let out = match
    vq_process_instr_degraded(
      instr,
      env,
      false,
      budget,
      cache,
      VQPassOptions::new(),
    ) {
    Some(next) => next
    None => fail("expected degraded select drop result")
  }
  assert_eq(
    out,
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::drop(if_true),
        TInstr::drop(if_false),
        TInstr::drop(condition),
      ]),
    ),
  )
}

///|
test "vacuum rewrites drop(local.tee(...)) to local.set(...)" {
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
  let out = run_vacuum(mod)
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TLocalSet(
          LocalIdx(i),
          { kind: TInstrKind::TI32Const(I32(v)), .. }
        ),
        ..,
      },
    ] => {
      assert_eq(i, 0U)
      assert_eq(v, 9)
    }
    _ => fail("expected drop(local.tee) to rewrite to local.set")
  }
}

///|
test "vacuum removes side-effect-free dropped value" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [],
        TExpr::new([TInstr::drop(TInstr::i32_const(I32(1)))]),
      ),
    ]),
  )
  let out = run_vacuum(mod)
  match vq_first_func_body(out).instrs {
    [{ kind: TInstrKind::TNop, .. }] => ()
    _ => fail("expected pure drop to be removed")
  }
}

///|
test "vacuum keeps ambient-consuming drop when child optimizes away" {
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::i64_const(I64(1)),
            TInstr::drop(TInstr::drop(TInstr::i32_const(I32(2)))),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail("expected ambient-consuming drop to survive vacuum validation: \{e}")
  }
}

///|
test "vacuum keeps ambient-consuming branch value drop with mixed stack types" {
  let t_i64 = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i64()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i64]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::block(
              BlockType::val_type(ValType::i64()),
              TExpr::new([
                TInstr::i64_const(I64(1)),
                TInstr::i32_const(I32(2)),
                TInstr::br(LabelIdx::new(0), [
                  TInstr::drop(TInstr::drop(TInstr::i32_const(I32(3)))),
                ]),
              ]),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected ambient-consuming branch value drop to survive vacuum validation: \{e}",
      )
  }
}

///|
test "vacuum keeps ambient-consuming drop in br_if terminator sequences" {
  let t_i32 = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32]))
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
                TInstr::i64_const(I64(1)),
                TInstr::drop(TInstr::drop(TInstr::i32_const(I32(2)))),
                TInstr::br_if(LabelIdx::new(0), TInstr::i32_const(I32(0)), []),
              ]),
            ),
            TInstr::i32_const(I32(9)),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected ambient-consuming drop in br_if sequence to survive vacuum validation: \{e}",
      )
  }
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TBlock(
          VoidBlockType,
          {
            instrs: [
              { kind: TInstrKind::TI64Const(I64(v0)), .. },
              {
                kind: TInstrKind::TDrop(
                  {
                    kind: TInstrKind::TDrop(
                      { kind: TInstrKind::TI32Const(I32(v1)), .. }
                    ),
                    ..,
                  }
                ),
                ..,
              },
              {
                kind: TInstrKind::TBrIf(
                  LabelIdx(label),
                  { kind: TInstrKind::TI32Const(I32(cond)), .. },
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
      { kind: TInstrKind::TI32Const(I32(v2)), .. },
    ] => {
      assert_eq(v0, 1L)
      assert_eq(v1, 2)
      assert_eq(label, 0U)
      assert_eq(cond, 0)
      assert_eq(v2, 9)
    }
    _ =>
      fail(
        "expected ambient-consuming dropped child to be preserved under br_if terminator sequence",
      )
  }
}

///|
test "vacuum keeps pure drop when sibling contains nested control transfer" {
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [ValType::i32()],
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::block(
                  BlockType::void_(),
                  TExpr::new([
                    TInstr::br(LabelIdx::new(1), []),
                    TInstr::unreachable_(),
                  ]),
                ),
                TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
              ]),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  assert_eq(validate_module(out), Ok(()))
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TBlock(
          VoidBlockType,
          { instrs: [_, { kind: TInstrKind::TDrop(_), .. }], .. }
        ),
        ..,
      },
    ] => ()
    _ => fail("expected nested-control-transfer sibling to preserve pure drop")
  }
}

///|
test "vacuum simplifies dropped unary wrapper around call to dropped call" {
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          [],
          TExpr::new([
            TInstr::drop(
              TInstr::unary(
                UnaryOp::i32_eqz(),
                TInstr::call(FuncIdx::new(1), []),
              ),
            ),
          ]),
        ),
        Func::t_func([], [], TExpr::new([TInstr::nop()])),
      ]),
    )
  let out = run_vacuum(mod)
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TDrop({ kind: TInstrKind::TCall(FuncIdx(i), []), .. }),
        ..,
      },
    ] => assert_eq(i, 1U)
    _ => fail("expected drop(i32.eqz(call)) to become drop(call)")
  }
}

///|
test "vacuum replaces constant if(true) with then arm" {
  let t_i32 = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          [],
          TExpr::new([
            TInstr::if_(
              BlockType::val_type(ValType::i32()),
              TInstr::i32_const(I32(1)),
              TExpr::new([TInstr::i32_const(I32(7))]),
              Some(TExpr::new([TInstr::i32_const(I32(8))])),
            ),
          ]),
        ),
      ]),
    )
  let out = run_vacuum(mod)
  match vq_first_func_body(out).instrs {
    [{ kind: TInstrKind::TI32Const(I32(v)), .. }] => assert_eq(v, 7)
    _ => fail("expected constant-true if to fold to then arm")
  }
}

///|
test "vacuum replaces if with unreachable condition by the condition" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [],
        TExpr::new([
          TInstr::if_(
            BlockType::void_(),
            TInstr::unreachable_(),
            TExpr::new([TInstr::nop()]),
            None,
          ),
        ]),
      ),
    ]),
  )
  let out = run_vacuum(mod)
  match vq_first_func_body(out).instrs {
    [{ kind: TInstrKind::TUnreachable, .. }] => ()
    _ => fail("expected if(unreachable) to fold to unreachable")
  }
}

///|
test "vacuum removes if without else when then arm is nop by dropping condition" {
  let t_i32 = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32, t_void]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("cond"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          [],
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::call(FuncIdx::new(0), []),
              TExpr::new([TInstr::nop()]),
              None,
            ),
          ]),
        ),
      ]),
    )
  let out = run_vacuum(mod)
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TDrop({ kind: TInstrKind::TCall(FuncIdx(i), []), .. }),
        ..,
      },
    ] => assert_eq(i, 0U)
    _ => fail("expected empty if body to become drop(condition)")
  }
}

///|
test "vacuum removes loops with nop body" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [],
        TExpr::new([
          TInstr::loop_(BlockType::void_(), TExpr::new([TInstr::nop()])),
        ]),
      ),
    ]),
  )
  let out = run_vacuum(mod)
  match vq_first_func_body(out).instrs {
    [{ kind: TInstrKind::TNop, .. }] => ()
    _ => fail("expected loop with nop body to become nop")
  }
}

///|
test "vacuum removes trailing dead code after unreachable in block body" {
  let block = TInstr::block(
    BlockType::void_(),
    TExpr::new([
      TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(1))),
      TInstr::unreachable_(),
      TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(2))),
    ]),
  )
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], [ValType::i32()], TExpr::new([block]))]),
  )
  let out = run_vacuum(mod)
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TBlock(
          _,
          {
            instrs: [
              {
                kind: TInstrKind::TLocalSet(
                  _,
                  { kind: TInstrKind::TI32Const(I32(v)), .. }
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
    ] => assert_eq(v, 1)
    _ => fail("expected unreachable tail in block to be removed")
  }
}

///|
test "vacuum keeps explicit unreachable sentinel after br tail" {
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
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
                TInstr::br(LabelIdx::new(0), []),
                TInstr::unreachable_(),
                TInstr::nop(),
              ]),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  assert_eq(validate_module(out), Ok(()))
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TBlock(
          VoidBlockType,
          {
            instrs: [
              { kind: TInstrKind::TBr(LabelIdx(lbl), []), .. },
              { kind: TInstrKind::TUnreachable, .. },
            ],
            ..,
          }
        ),
        ..,
      },
    ] => assert_eq(lbl, 0U)
    _ => fail("expected explicit unreachable sentinel after br to be preserved")
  }
}

///|
test "vacuum rewrites dropped if-arm drops into value-producing if while preserving stack signature" {
  let t_i32 = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let dropped_if = TInstr::drop(
    TInstr::if_(
      BlockType::void_(),
      TInstr::local_get(LocalIdx::new(0)),
      TExpr::new([TInstr::drop(TInstr::call(FuncIdx::new(0), []))]),
      Some(TExpr::new([TInstr::drop(TInstr::call(FuncIdx::new(1), []))])),
    ),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32, t_void]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("left"),
          ExternType::func(TypeIdx::new(0)),
        ),
        Import::new(
          Name::new("env"),
          Name::new("right"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [ValType::i32()],
          TExpr::new([TInstr::local_get(LocalIdx::new(0)), dropped_if]),
        ),
      ]),
    )
  let out = run_vacuum(mod)
  assert_eq(validate_module(out), Ok(()))
  match vq_first_func_body(out).instrs {
    [
      { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
      { kind: TInstrKind::TDrop(value), .. },
    ] => {
      let (then_, else_) = match value.kind {
        TInstrKind::TIf(
          ValTypeBlockType(NumTypeValType(I32NumType)),
          _,
          then_,
          Some(else_)
        ) => (then_, else_)
        TInstrKind::TDrop(
          {
            kind: TInstrKind::TIf(
              ValTypeBlockType(NumTypeValType(I32NumType)),
              _,
              then_,
              Some(else_)
            ),
            ..,
          }
        ) => (then_, else_)
        _ =>
          fail(
            "expected dropped if to contain value-producing if after rewrite: \{vq_first_func_body(out)}",
          )
      }
      match (then_.instrs, else_.instrs) {
        (
          [{ kind: TInstrKind::TCall(FuncIdx(a), []), .. }],
          [{ kind: TInstrKind::TCall(FuncIdx(b), []), .. }],
        ) => {
          assert_eq(a, 0U)
          assert_eq(b, 1U)
        }
        _ => fail("expected value arms")
      }
    }
    _ =>
      fail(
        "expected dropped-if rewrite output shape to preserve stack signature: \{vq_first_func_body(out)}",
      )
  }
}

///|
test "vacuum safely inverts if with nop then arm" {
  let t_void_with_param = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void_with_param]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          [],
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([TInstr::nop()]),
              Some(
                TExpr::new([
                  TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(1))),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  assert_eq(validate_module(out), Ok(()))
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TIf(
          VoidBlockType,
          {
            kind: TInstrKind::TUnary(
              I32EqzOp,
              { kind: TInstrKind::TLocalGet(LocalIdx(idx)), .. }
            ),
            ..,
          },
          then_body,
          None
        ),
        ..,
      },
    ] => {
      assert_eq(idx, 0U)
      match then_body.instrs {
        [{ kind: TInstrKind::TLocalSet(LocalIdx(set_idx), _), .. }] =>
          assert_eq(set_idx, 0U)
        _ => fail("expected inverted then body to keep local.set side effect")
      }
    }
    _ => fail("expected if with nop then arm to invert into eqz form")
  }
}

///|
test "vacuum regression: inverts dropped-then if when else arm is simple" {
  // This is semantically safe and should still optimize.
  let t_void_with_param = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void_with_param]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          [ValType::i32()],
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([TInstr::drop(TInstr::i32_const(I32(0)))]),
              Some(
                TExpr::new([
                  TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(7))),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  assert_eq(validate_module(out), Ok(()))
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TIf(
          VoidBlockType,
          {
            kind: TInstrKind::TUnary(
              I32EqzOp,
              { kind: TInstrKind::TLocalGet(LocalIdx(cond_idx)), .. }
            ),
            ..,
          },
          then_body,
          None
        ),
        ..,
      },
    ] => {
      assert_eq(cond_idx, 0U)
      match then_body.instrs {
        [{ kind: TInstrKind::TLocalSet(LocalIdx(set_idx), _), .. }] =>
          assert_eq(set_idx, 1U)
        _ =>
          fail("expected simple else side effects to become inverted then arm")
      }
    }
    _ => fail("expected dropped-then if with simple else arm to invert")
  }
}

///|
test "vacuum regression: avoids inversion when moved else has control transfer" {
  // Control-transfer heavy else arms are where local stack-signature checks can
  // miss context-sensitive constraints; keep conservative shape there.
  let t_i32_to_i32 = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32_to_i32]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          [],
          TExpr::new([
            TInstr::block(
              BlockType::val_type(ValType::i32()),
              TExpr::new([
                TInstr::if_(
                  BlockType::void_(),
                  TInstr::local_get(LocalIdx::new(0)),
                  TExpr::new([TInstr::drop(TInstr::i32_const(I32(0)))]),
                  Some(
                    TExpr::new([
                      TInstr::br(LabelIdx::new(0), [TInstr::i32_const(I32(77))]),
                    ]),
                  ),
                ),
                TInstr::i32_const(I32(9)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  assert_eq(validate_module(out), Ok(()))
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TBlock(
          ValTypeBlockType(NumTypeValType(I32NumType)),
          body
        ),
        ..,
      },
    ] =>
      match body.instrs {
        [
          {
            kind: TInstrKind::TIf(
              VoidBlockType,
              { kind: TInstrKind::TLocalGet(LocalIdx(cond_idx)), .. },
              _,
              Some(_)
            ),
            ..,
          },
          _,
        ] => assert_eq(cond_idx, 0U)
        _ => fail("expected non-inverted if when else arm contains branch")
      }
    _ => fail("expected enclosing value block to stay intact")
  }
}

///|
test "vacuum removes try_table when body cannot throw" {
  let t_i32 = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let instr = TInstr::try_table(
    BlockType::val_type(ValType::i32()),
    [Catch::all(LabelIdx::new(0))],
    TExpr::new([TInstr::i32_const(I32(77))]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([Func::t_func([], [], TExpr::new([instr]))]))
  let out = run_vacuum(mod)
  match vq_first_func_body(out).instrs {
    [{ kind: TInstrKind::TI32Const(I32(v)), .. }] => assert_eq(v, 77)
    _ => fail("expected throw-free try_table to fold to body")
  }
}

///|
test "vacuum keeps non-removable try_table body that may throw" {
  let instr = TInstr::try_table(
    BlockType::void_(),
    [Catch::all(LabelIdx::new(0))],
    TExpr::new([TInstr::throw_(TagIdx::new(0), [])]),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
    )
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(0))]))
    .with_code_sec(CodeSec::new([Func::t_func([], [], TExpr::new([instr]))]))
  let out = run_vacuum(mod)
  match vq_first_func_body(out).instrs {
    [{ kind: TInstrKind::TTryTable(_, _, _), .. }] => ()
    _ => fail("expected throwing try_table to remain")
  }
}

///|
test "vacuum nops side-effect-free none-returning function body" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], [], TExpr::new([TInstr::i32_const(I32(1))]))]),
  )
  let out = run_vacuum(mod)
  match vq_first_func_body(out).instrs {
    [{ kind: TInstrKind::TNop, .. }] => ()
    _ => fail("expected side-effect-free function body to become nop")
  }
}

///|
test "vacuum removes dead leading value from result-returning function body and validates" {
  let t_i32 = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([TInstr::i32_const(I32(1)), TInstr::i32_const(I32(2))]),
        ),
      ]),
    )
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) => fail("expected vacuum output to validate: \{e}")
  }
  match vq_first_func_body(out).instrs {
    [{ kind: TInstrKind::TI32Const(I32(v)), .. }] => assert_eq(v, 2)
    _ => fail("expected dead leading value to be removed")
  }
}

///|
test "vacuum removes dead leading arm values in result if and validates" {
  let t_i32 = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::if_(
              BlockType::val_type(ValType::i32()),
              TInstr::i32_const(I32(1)),
              TExpr::new([
                TInstr::i32_const(I32(11)),
                TInstr::i32_const(I32(22)),
              ]),
              Some(
                TExpr::new([
                  TInstr::i32_const(I32(33)),
                  TInstr::i32_const(I32(44)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    )
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) => fail("expected vacuum result-if output to validate: \{e}")
  }
  match vq_first_func_body(out).instrs {
    [{ kind: TInstrKind::TI32Const(I32(v)), .. }] => assert_eq(v, 22)
    _ => fail("expected constant-folded if to keep only live arm result")
  }
}

///|
test "vacuum preserves only final value inside dropped result block and validates" {
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
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
                  TInstr::i32_const(I32(5)),
                  TInstr::i32_const(I32(6)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    )
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) => fail("expected dropped result block output to validate: \{e}")
  }
  match vq_first_func_body(out).instrs {
    [{ kind: TInstrKind::TNop, .. }] => ()
    _ => fail("expected dropped pure result block to become nop")
  }
}

///|
test "vacuum preserves multi-value function body results and validates" {
  let t_pair = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32(), ValType::i64()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_pair]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([TInstr::i32_const(I32(1)), TInstr::i64_const(I64(2L))]),
        ),
      ]),
    )
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) => fail("expected multi-value vacuum output to validate: \{e}")
  }
  match vq_first_func_body(out).instrs {
    [
      { kind: TInstrKind::TI32Const(I32(a)), .. },
      { kind: TInstrKind::TI64Const(I64(b)), .. },
    ] => {
      assert_eq(a, 1)
      assert_eq(b, 2L)
    }
    _ => fail("expected multi-value function results to be preserved")
  }
}

///|
test "vacuum preserves constant-folded multi-value if results and validates" {
  let t_pair = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32(), ValType::i64()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_pair]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::if_(
              BlockType::type_idx(TypeIdx::new(0)),
              TInstr::i32_const(I32(1)),
              TExpr::new([TInstr::i32_const(I32(7)), TInstr::i64_const(I64(8L))]),
              Some(
                TExpr::new([
                  TInstr::i32_const(I32(9)),
                  TInstr::i64_const(I64(10L)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    )
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) => fail("expected multi-value if vacuum output to validate: \{e}")
  }
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TBlock(
          TypeIdxBlockType(TypeIdx(idx)),
          {
            instrs: [
              { kind: TInstrKind::TI32Const(I32(a)), .. },
              { kind: TInstrKind::TI64Const(I64(b)), .. },
            ],
            ..,
          }
        ),
        ..,
      },
    ] => {
      assert_eq(idx, 0U)
      assert_eq(a, 7)
      assert_eq(b, 8L)
    }
    _ =>
      fail("expected constant-folded multi-value if to preserve both results")
  }
}

///|
test "vacuum preserves multi-value block results and validates" {
  let t_pair = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32(), ValType::i64()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_pair]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::block(
              BlockType::type_idx(TypeIdx::new(0)),
              TExpr::new([
                TInstr::i32_const(I32(11)),
                TInstr::i64_const(I64(12L)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) => fail("expected multi-value block vacuum output to validate: \{e}")
  }
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TBlock(
          TypeIdxBlockType(TypeIdx(idx)),
          {
            instrs: [
              { kind: TInstrKind::TI32Const(I32(a)), .. },
              { kind: TInstrKind::TI64Const(I64(b)), .. },
            ],
            ..,
          }
        ),
        ..,
      },
    ] => {
      assert_eq(idx, 0U)
      assert_eq(a, 11)
      assert_eq(b, 12L)
    }
    _ => fail("expected multi-value block results to be preserved")
  }
}

///|
test "vacuum rebases branch labels when simplifying nested result blocks" {
  let t_i32 = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32]))
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
                TInstr::br(LabelIdx::new(1), [
                  TInstr::block(
                    BlockType::val_type(ValType::i32()),
                    TExpr::new([
                      TInstr::br(LabelIdx::new(2), [TInstr::i32_const(I32(42))]),
                    ]),
                  ),
                ]),
              ]),
            ),
            TInstr::i32_const(I32(5)),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)

  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected nested result block labels to stay valid after vacuum: \{e}",
      )
  }

  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TBr(
          LabelIdx(depth0),
          [
            {
              kind: TInstrKind::TBlock(
                ValTypeBlockType(NumTypeValType(I32NumType)),
                {
                  instrs: [
                    {
                      kind: TInstrKind::TBr(
                        LabelIdx(depth1),
                        [{ kind: TInstrKind::TI32Const(I32(42)), .. }]
                      ),
                      ..,
                    },
                  ],
                  ..,
                }
              ),
              ..,
            },
          ]
        ),
        ..,
      },
    ] => {
      assert_eq(depth0, 0U)
      assert_eq(depth1, 1U)
    }
    _ =>
      fail(
        "expected vacuum to keep the nested result block valid after rebasing: \{vq_first_func_body(out)}",
      )
  }
}

///|
test "vacuum preserves nested break-to-wrapper inside branch value tree" {
  let t_i32 = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          [],
          TExpr::new([
            TInstr::block(
              BlockType::val_type(ValType::i32()),
              TExpr::new([
                TInstr::block(
                  BlockType::void_(),
                  TExpr::new([
                    TInstr::br(LabelIdx::new(1), [
                      TInstr::if_(
                        BlockType::val_type(ValType::i32()),
                        TInstr::local_get(LocalIdx::new(0)),
                        TExpr::new([TInstr::i32_const(I32(7))]),
                        Some(TExpr::new([TInstr::br(LabelIdx::new(1), [])])),
                      ),
                    ]),
                  ]),
                ),
                TInstr::i32_const(I32(9)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected nested break-to-wrapper branch value tree to survive vacuum: \{e}",
      )
  }
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TBlock(
          ValTypeBlockType(NumTypeValType(I32NumType)),
          {
            instrs: [
              { kind: TInstrKind::TBlock(VoidBlockType, _), .. },
              { kind: TInstrKind::TI32Const(I32(9)), .. },
            ],
            ..,
          }
        ),
        ..,
      },
    ] => ()
    _ =>
      fail(
        "expected vacuum to keep wrapper block when nested branch-value path targets it",
      )
  }
}

///|
test "vacuum keeps stack-feeding sibling values in block bodies" {
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [ValType::i32(), ValType::i32(), ValType::i32(), ValType::i32()],
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::local_get(LocalIdx::new(0)),
                TInstr::local_set(
                  LocalIdx::new(1),
                  TInstr::local_set(
                    LocalIdx::new(2),
                    TInstr::local_get(LocalIdx::new(3)),
                  ),
                ),
                TInstr::br(LabelIdx::new(0), []),
              ]),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected stack-feeding sibling value to survive vacuum validation: \{e}",
      )
  }
}

///|
test "vacuum keeps mixed-type stack-feeding sibling values in block bodies" {
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [ValType::i64(), ValType::i64(), ValType::i32(), ValType::i32()],
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::local_get(LocalIdx::new(0)),
                TInstr::local_set(
                  LocalIdx::new(1),
                  TInstr::local_set(
                    LocalIdx::new(2),
                    TInstr::local_get(LocalIdx::new(3)),
                  ),
                ),
                TInstr::br(LabelIdx::new(0), []),
              ]),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected mixed-type stack-feeding sibling value to survive vacuum validation: \{e}",
      )
  }
}

///|
test "vacuum does not invert stack-fed if condition with non-i32 condition expression" {
  let t_void = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          [ValType::i64(), ValType::i32()],
          TExpr::new([
            TInstr::local_get(LocalIdx::new(0)),
            TInstr::if_(
              BlockType::void_(),
              TInstr::drop(TInstr::local_get(LocalIdx::new(1))),
              TExpr::new([TInstr::nop()]),
              Some(
                TExpr::new([
                  TInstr::local_set(LocalIdx::new(2), TInstr::i32_const(I32(7))),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected stack-fed non-i32 if condition to survive vacuum validation: \{e}",
      )
  }
  match vq_first_func_body(out).instrs {
    [
      { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
      {
        kind: TInstrKind::TIf(
          VoidBlockType,
          { kind: TInstrKind::TNop, .. },
          then_body,
          Some(other_body)
        ),
        ..,
      },
    ] => {
      match then_body.instrs {
        [] => ()
        [{ kind: TInstrKind::TNop, .. }] => ()
        _ => fail("expected stack-fed if then-arm to stay empty or nop")
      }
      match other_body.instrs {
        [
          {
            kind: TInstrKind::TLocalSet(
              LocalIdx(2U),
              { kind: TInstrKind::TI32Const(I32(7)), .. }
            ),
            ..,
          },
        ] => ()
        _ =>
          fail("expected stack-fed if else-arm to keep local.set side effect")
      }
    }
    _ =>
      fail(
        "expected stack-fed if to keep else-arm form instead of cond eqz inversion",
      )
  }
}

///|
test "vacuum preserves nested drop-drop under local.set with mixed ambient stack types" {
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [ValType::i32(), ValType::i64(), ValType::i32()],
          TExpr::new([
            TInstr::local_get(LocalIdx::new(0)),
            TInstr::local_get(LocalIdx::new(1)),
            TInstr::local_set(
              LocalIdx::new(2),
              TInstr::drop(TInstr::drop(TInstr::local_get(LocalIdx::new(0)))),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected nested drop-drop under local.set to survive vacuum validation: \{e}",
      )
  }
  match vq_first_func_body(out).instrs {
    [
      { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
      { kind: TInstrKind::TLocalGet(LocalIdx(1U)), .. },
      { kind: TInstrKind::TLocalSet(LocalIdx(2U), value), .. },
    ] =>
      match value.kind {
        TInstrKind::TNop =>
          fail("expected local.set value to keep ambient stack consumption")
        _ => ()
      }
    _ => fail("expected ambient-fed local.set shape to be preserved")
  }
}

///|
test "vacuum preserves child stack signatures under local.set" {
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [ValType::i32(), ValType::i32()],
          TExpr::new([
            TInstr::local_get(LocalIdx::new(0)),
            TInstr::local_get(LocalIdx::new(1)),
            TInstr::local_set(
              LocalIdx::new(0),
              TInstr::drop(TInstr::drop(TInstr::i32_const(I32(7)))),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected local.set child stack signature to be preserved after vacuum: \{e}",
      )
  }
}

///|
test "vacuum keeps stack-feeding sibling values with unknown stack signatures" {
  let t_result = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
  )
  let t_void = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_result, t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_mem_sec(MemSec::new([MemType::new(Limits::i32(1, None))]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          [ValType::i32()],
          TExpr::new([
            TInstr::memory_size(MemIdx::new(0)),
            TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(7))),
            TInstr::call(FuncIdx::new(1), [TInstr::local_get(LocalIdx::new(0))]),
          ]),
        ),
        Func::t_func([ValType::i32()], [], TExpr::new([TInstr::nop()])),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected unknown-signature stack feeder to survive vacuum validation: \{e}",
      )
  }
}

///|
test "vacuum keeps typed params and declared locals separated" {
  let t_result = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_result]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          [ValType::i32()],
          TExpr::new([
            TInstr::drop(TInstr::i32_const(I32(1))),
            TInstr::local_get(LocalIdx::new(1)),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(params, locals, _)])) => {
      assert_eq(params, [ValType::i32()])
      assert_eq(locals, [ValType::i32()])
    }
    _ => fail("expected single typed function in output module")
  }
  match validate_module(out) {
    Ok(_) => ()
    Err(e) => fail("expected vacuum output to validate: \{e}")
  }
}

///|
test "vacuum preserves stack-carried table.get result across trailing side effects" {
  let t_extern_result = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::externref()])),
  )
  let t_void_with_i32 = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_extern_result, t_void_with_i32]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_table_sec(
      TableSec::new([
        Table::new(
          TableType::new(
            RefType::new(true, HeapType::abs(AbsHeapType::extern_())),
            Limits::i32(1, Some(1)),
          ),
          None,
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          [],
          TExpr::new([
            TInstr::table_get(TableIdx::new(0), TInstr::i32_const(I32(0))),
            TInstr::call(FuncIdx::new(1), [TInstr::local_get(LocalIdx::new(0))]),
          ]),
        ),
        Func::t_func([ValType::i32()], [], TExpr::new([TInstr::nop()])),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected stack-carried table.get result to survive vacuum validation: \{e}",
      )
  }
}

///|
test "vacuum is stable on nop-only function body across repeated runs" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], [], TExpr::new([TInstr::nop()]))]),
  )
  let once = run_vacuum(mod)
  let twice = run_vacuum(once)
  assert_eq(once, twice)
}

///|
test "vacuum keeps ambient-fed effectful child inside dropped binary" {
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
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
          TExpr::new([
            TInstr::local_get(LocalIdx::new(0)),
            TInstr::local_get(LocalIdx::new(1)),
            TInstr::local_get(LocalIdx::new(2)),
            TInstr::drop(
              TInstr::binary(
                BinaryOp::i32_add(),
                TInstr::local_get(LocalIdx::new(3)),
                TInstr::local_set(
                  LocalIdx::new(4),
                  TInstr::drop(TInstr::drop(TInstr::i32_const(I32(9)))),
                ),
              ),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected ambient-fed effectful child under dropped binary to survive vacuum validation: \{e}",
      )
  }
}

///|
test "vacuum keeps stack-signature when dropping binary with ambient-fed call child" {
  let t_main = RecType::new(SubType::comp_type(CompType::func([], [])))
  let t_callee = RecType::new(
    SubType::comp_type(
      CompType::func([ValType::i32()], [ValType::i32(), ValType::i32()]),
    ),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_main, t_callee]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::drop(
              TInstr::binary(
                BinaryOp::i32_add(),
                TInstr::i32_const(I32(7)),
                TInstr::call(FuncIdx::new(1), [
                  TInstr::drop(TInstr::i32_const(I32(1))),
                ]),
              ),
            ),
          ]),
        ),
        Func::t_func(
          [ValType::i32()],
          [],
          TExpr::new([
            TInstr::local_get(LocalIdx::new(0)),
            TInstr::local_get(LocalIdx::new(0)),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected dropped-binary ambient-fed call child case to validate after vacuum: \{e}",
      )
  }
}

///|
test "vacuum traps-never-happen rewrites unreachable if arm into drop+other-arm sequence" {
  let t_void = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          [ValType::i32()],
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([TInstr::unreachable_()]),
              Some(
                TExpr::new([
                  TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(9))),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum_with_options(mod, true)
  assert_eq(validate_module(out), Ok(()))
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TBlock(
          VoidBlockType,
          {
            instrs: [
              {
                kind: TInstrKind::TDrop(
                  { kind: TInstrKind::TLocalGet(LocalIdx(cond_local)), .. }
                ),
                ..,
              },
              {
                kind: TInstrKind::TLocalSet(
                  LocalIdx(set_local),
                  { kind: TInstrKind::TI32Const(I32(v)), .. }
                ),
                ..,
              },
            ],
            ..,
          }
        ),
        ..,
      },
    ] => {
      assert_eq(cond_local, 0U)
      assert_eq(set_local, 1U)
      assert_eq(v, 9)
    }
    _ =>
      fail(
        "expected TNH if-arm rewrite to drop(condition) then execute surviving arm",
      )
  }
}

///|
test "vacuum traps-never-happen cleans block code that definitely reaches explicit unreachable" {
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [ValType::i32()],
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(1))),
                TInstr::unreachable_(),
              ]),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum_with_options(mod, true)
  assert_eq(validate_module(out), Ok(()))
  match vq_first_func_body(out).instrs {
    [{ kind: TInstrKind::TUnreachable, .. }] => ()
    _ =>
      fail(
        "expected TNH block cleanup to remove side-effecting prefix before explicit unreachable",
      )
  }
}

///|
test "vacuum traps-never-happen nops trap-only none-returning function body" {
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::drop(
              TInstr::binary(
                BinaryOp::i32_div_s(),
                TInstr::i32_const(I32(1)),
                TInstr::i32_const(I32(0)),
              ),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum_with_options(mod, true)
  assert_eq(validate_module(out), Ok(()))
  match vq_first_func_body(out).instrs {
    [{ kind: TInstrKind::TNop, .. }] => ()
    _ => fail("expected TNH trap-only none-returning function body to nop")
  }
}

///|
test "vacuum traps-never-happen keeps explicit unreachable trap propagation in function body" {
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([Func::t_func([], [], TExpr::new([TInstr::unreachable_()]))]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum_with_options(mod, true)
  assert_eq(validate_module(out), Ok(()))
  match vq_first_func_body(out).instrs {
    [{ kind: TInstrKind::TUnreachable, .. }] => ()
    _ =>
      fail(
        "expected explicit unreachable to remain in TNH mode for trap propagation",
      )
  }
}

///|
test "vacuum treats binaryen-intrinsics call.without.effects as removable if unused" {
  let t_intrinsic = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let t_main = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_intrinsic, t_main]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("binaryen-intrinsics"),
          Name::new("call.without.effects"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([TInstr::drop(TInstr::call(FuncIdx::new(0), []))]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  assert_eq(validate_module(out), Ok(()))
  match vq_first_func_body(out).instrs {
    [{ kind: TInstrKind::TNop, .. }] => ()
    _ =>
      fail(
        "expected unused binaryen-intrinsics call.without.effects to be removable in vacuum",
      )
  }
}

///|
test "vacuum traps-never-happen rewrites value-typed unreachable if arm into drop+live-arm value sequence" {
  let t_i32_result = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let t_i32_cond = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32_result, t_i32_cond]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("cond"),
          ExternType::func(TypeIdx::new(1)),
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
            TInstr::if_(
              BlockType::val_type(ValType::i32()),
              TInstr::call(FuncIdx::new(0), []),
              TExpr::new([TInstr::unreachable_()]),
              Some(TExpr::new([TInstr::i32_const(I32(9))])),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum_with_options(mod, true)
  assert_eq(validate_module(out), Ok(()))
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TBlock(
          ValTypeBlockType(NumTypeValType(I32NumType)),
          {
            instrs: [
              {
                kind: TInstrKind::TDrop(
                  { kind: TInstrKind::TCall(FuncIdx(cond_idx), []), .. }
                ),
                ..,
              },
              { kind: TInstrKind::TI32Const(I32(v)), .. },
            ],
            ..,
          }
        ),
        ..,
      },
    ] => {
      assert_eq(cond_idx, 0U)
      assert_eq(v, 9)
    }
    _ =>
      fail(
        "expected TNH value-typed if-arm rewrite to keep drop(condition) and live arm result",
      )
  }
}

///|
test "vacuum preserves nested drop stack signature when inner drop is effectful" {
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let t_i32 = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void, t_i32]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("effectful"),
          ExternType::func(TypeIdx::new(1)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [ValType::i32()],
          TExpr::new([
            TInstr::local_get(LocalIdx::new(0)),
            TInstr::drop(TInstr::drop(TInstr::call(FuncIdx::new(0), []))),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  assert_eq(validate_module(out), Ok(()))
  match vq_first_func_body(out).instrs {
    [
      { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
      {
        kind: TInstrKind::TDrop(
          {
            kind: TInstrKind::TDrop(
              { kind: TInstrKind::TCall(FuncIdx(call_idx), []), .. }
            ),
            ..,
          }
        ),
        ..,
      },
    ] => assert_eq(call_idx, 0U)
    _ =>
      fail(
        "expected nested drop over effectful call to preserve ambient stack-consuming shape",
      )
  }
}

///|
test "vacuum value-break lub detector reports true for compatible break value types" {
  let env = Env::new().with_module(Module::new())
  let analysis_cache = VQAnalysisCache::new([], VQRunStats::new())
  let expr = TExpr::new([
    TInstr::br(LabelIdx::new(0), [TInstr::i32_const(I32(1))]),
    TInstr::br(LabelIdx::new(0), [TInstr::i32_const(I32(2))]),
  ])
  let budget = Ref::new(128)
  assert_true(vq_seed_texpr_facts_bounded(expr, env, analysis_cache, budget))
  let expr_id = match analysis_cache.indexed_root_expr_id {
    Some(id) => id
    None => fail("expected indexed expr id")
  }
  let expr_entries_before = vq_analysis_cache_expr_entry_count(analysis_cache)
  assert_true(
    vq_value_break_to_depth_has_lub(
      expr,
      0,
      env,
      analysis_cache,
      expr_id=Some(expr_id),
    ),
  )
  assert_eq(
    vq_analysis_cache_expr_entry_count(analysis_cache),
    expr_entries_before,
  )
}

///|
test "vacuum fallback expr metadata queries avoid value-keyed expr cache entries" {
  let cache = VQAnalysisCache::new([], VQRunStats::new())

  assert_true(
    vq_texpr_has_control_transfer_cached(
      TExpr::new([TInstr::br(LabelIdx::new(0), [])]),
      cache,
    ),
  )
  assert_true(
    vq_texpr_throws_cached(
      TExpr::new([TInstr::throw_(TagIdx::new(0), [])]),
      cache,
    ),
  )
  assert_true(
    vq_texpr_has_explicit_unreachable_cached(
      TExpr::new([TInstr::unreachable_()]),
      cache,
    ),
  )

  assert_eq(vq_analysis_cache_expr_entry_count(cache), 0)
}

///|
test "vacuum fallback value-break lub query avoids value-keyed expr cache entries" {
  let env = Env::new().with_module(Module::new())
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let expr = TExpr::new([
    TInstr::br(LabelIdx::new(0), [TInstr::i32_const(I32(1))]),
  ])

  assert_true(vq_value_break_to_depth_has_lub(expr, 0, env, cache))
  assert_eq(vq_analysis_cache_expr_entry_count(cache), 0)
}

///|
test "vacuum cached value-break helper skips unindexed label-free fallback scan" {
  let env = Env::new().with_module(Module::new())
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let expr = TExpr::new([TInstr::i32_const(I32(1))])

  assert_false(vq_has_value_break_lub_depth0_cached(expr, env, cache))
  assert_eq(cache.stats.value_break_lub_calls.val, 0)
  assert_eq(cache.stats.rebase_score_calls.val, 1)
}

///|
test "vacuum cached break helper skips unindexed label-free multi-item fallback scan" {
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let expr = TExpr::new([TInstr::i32_const(I32(1)), TInstr::i32_const(I32(2))])

  assert_false(vq_has_break_to_depth0_cached(expr, cache))
  assert_eq(cache.stats.break_scan_calls.val, 0)
  assert_eq(cache.stats.rebase_score_calls.val, 1)
}

///|
test "vacuum cached value-break helper skips unindexed label-free multi-item fallback scan" {
  let env = Env::new().with_module(Module::new())
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let expr = TExpr::new([TInstr::i32_const(I32(1)), TInstr::i32_const(I32(2))])

  assert_false(vq_has_value_break_lub_depth0_cached(expr, env, cache))
  assert_eq(cache.stats.value_break_lub_calls.val, 0)
  assert_eq(cache.stats.rebase_score_calls.val, 1)
}

///|
test "vacuum fallback pure leaf effect metadata skips generic collector" {
  let cache = VQAnalysisCache::new([], VQRunStats::new())
  let leaf = TInstr::i32_const(I32(1))

  assert_false(vq_has_unremovable_effects_cached(leaf, cache))
  assert_false(vq_has_unremovable_shallow_effects_cached(leaf, cache))
  assert_false(vq_instr_has_calls_cached(leaf, cache))
  assert_false(vq_instr_effect_transfers_control_flow_cached(leaf, cache))
  assert_eq(cache.stats.collect_effects_calls.val, 0)
}

///|
test "vacuum fallback pure leaf type metadata skips generic type inference" {
  let env = Env::new().with_module(Module::new()).with_locals([ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())

  assert_eq(
    vq_type_of_cached(TInstr::local_get(LocalIdx::new(0)), env, cache),
    Some(ValType::i32()),
  )
  assert_eq(
    vq_type_of_cached(TInstr::i64_const(I64(7L)), env, cache),
    Some(ValType::i64()),
  )
  assert_eq(cache.stats.infer_type_calls.val, 0)
}

///|
test "vacuum fallback instr metadata queries avoid value-keyed instr cache entries" {
  let env = Env::new().with_module(Module::new()).with_locals([ValType::i32()])
  let cache = VQAnalysisCache::new([], VQRunStats::new())

  let local_get = TInstr::local_get(LocalIdx::new(0))
  let pure_const = TInstr::i32_const(I32(1))
  let br = TInstr::br(LabelIdx::new(0), [])
  let loop_ = TInstr::loop_(BlockType::void_(), TExpr::new([]))

  assert_eq(vq_type_of_cached(local_get, env, cache), Some(ValType::i32()))
  assert_false(vq_has_unremovable_effects_cached(pure_const, cache))
  assert_false(vq_has_unremovable_shallow_effects_cached(pure_const, cache))
  assert_false(vq_instr_has_calls_cached(pure_const, cache))
  assert_true(vq_instr_effect_transfers_control_flow_cached(br, cache))
  assert_true(vq_instr_has_control_transfer_cached(br, cache))
  match vq_stack_sig_instr_cached(local_get, env, cache) {
    Some(sig) => {
      assert_eq(sig.required, 0)
      assert_eq(sig.produced, 1)
      assert_true(sig.reachable)
    }
    None => fail("expected local.get stack signature")
  }
  assert_true(vq_instr_may_not_return_cached(loop_, cache))

  assert_eq(vq_analysis_cache_instr_entry_count(cache), 0)
}

///|
test "vacuum value-break lub detector reports false for incompatible reference break value types" {
  let env = Env::new().with_module(Module::new())
  let analysis_cache = VQAnalysisCache::new([], VQRunStats::new())
  let expr = TExpr::new([
    TInstr::br(LabelIdx::new(0), [
      TInstr::ref_null(HeapType::abs(AbsHeapType::func())),
    ]),
    TInstr::br(LabelIdx::new(0), [
      TInstr::ref_null(HeapType::abs(AbsHeapType::extern_())),
    ]),
  ])
  let budget = Ref::new(128)
  assert_true(vq_seed_texpr_facts_bounded(expr, env, analysis_cache, budget))
  let expr_id = match analysis_cache.indexed_root_expr_id {
    Some(id) => id
    None => fail("expected indexed expr id")
  }
  let expr_entries_before = vq_analysis_cache_expr_entry_count(analysis_cache)
  assert_false(
    vq_value_break_to_depth_has_lub(
      expr,
      0,
      env,
      analysis_cache,
      expr_id=Some(expr_id),
    ),
  )
  assert_eq(
    vq_analysis_cache_expr_entry_count(analysis_cache),
    expr_entries_before,
  )
}
