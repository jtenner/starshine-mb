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
let sl_perf_effect_collect_calls : Ref[Int] = Ref::new(0)

///|
let sl_perf_invalidation_entry_checks : Ref[Int] = Ref::new(0)

///|
let sl_perf_get_count_scans : Ref[Int] = Ref::new(0)

///|
let sl_perf_late_state_clones : Ref[Int] = Ref::new(0)

///|
fn sl_perf_reset() -> Unit {
  sl_perf_effect_collect_calls.val = 0
  sl_perf_invalidation_entry_checks.val = 0
  sl_perf_get_count_scans.val = 0
  sl_perf_late_state_clones.val = 0
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
fn sl_collect_effects_counted(instr : TInstr) -> LCSEffects {
  sl_perf_effect_collect_calls.val = sl_perf_effect_collect_calls.val + 1
  lcs_collect_effects(instr)
}

///|
fn sl_collect_effects_cached(
  instr : TInstr,
  effects_cache : Map[TInstr, LCSEffects],
) -> LCSEffects {
  match effects_cache.get(instr) {
    Some(cached) => cached
    None => {
      let effects = sl_collect_effects_counted(instr)
      effects_cache[instr] = effects
      effects
    }
  }
}

///|
fn sl_trace_noop(_ : String) -> Unit {
  ()
}

///|
fn sl_trace_normalize_env_now_ms(raw : UInt64) -> UInt64 {
  if raw >= 100000000000000000UL {
    raw / 1000000UL
  } else if raw >= 100000000000000UL {
    raw / 1000UL
  } else {
    raw
  }
}

///|
#cfg(target="wasm-gc")
fn sl_trace_now_ms() -> UInt64 {
  sl_trace_normalize_env_now_ms(@env.now())
}

///|
#cfg(target="wasm")
fn sl_trace_now_ms() -> UInt64 {
  sl_trace_normalize_env_now_ms(@env.now())
}

///|
#cfg(target="js")
fn sl_trace_now_ms() -> UInt64 {
  sl_trace_normalize_env_now_ms(@env.now())
}

///|
#cfg(target="llvm")
fn sl_trace_now_ms() -> UInt64 {
  sl_trace_normalize_env_now_ms(@env.now())
}

///|
#cfg(target="native")
fn sl_trace_now_ms() -> UInt64 {
  sl_trace_normalize_env_now_ms(@env.now())
}

///|
fn sl_trace_elapsed_ms(start_ms : UInt64) -> UInt64 {
  let end_ms = sl_trace_now_ms()
  if end_ms >= start_ms {
    end_ms - start_ms
  } else {
    0UL
  }
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
priv struct SLSimplifyOptions {
  allow_tee : Bool
  allow_structure : Bool
  allow_nesting : Bool
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
fn sl_locals_have_param_prefix(
  locals : Array[ValType],
  params : Array[ValType],
) -> Bool {
  if params.length() > locals.length() {
    return false
  }
  for i = 0; i < params.length(); i = i + 1 {
    if locals[i] != params[i] {
      return false
    }
  }
  true
}

///|
fn sl_canonical_tfunc_locals(
  params : Array[ValType],
  locals : Array[ValType],
) -> Array[ValType] {
  if sl_locals_have_param_prefix(locals, params) {
    locals.copy()
  } else {
    params + locals
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
  match lcs_infer_tinstr_type(value, env) {
    Some(vt) => vt == local_type || Match::matches(vt, local_type, env)
    None => false
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
  get_counts : Array[Int],
  local_types : Array[ValType],
  options : SLSimplifyOptions,
  in_value_position : Bool,
  changed : Ref[Bool],
) -> TInstr {
  let key = sl_localidx_to_int(idx)
  if key < 0 || key >= get_counts.length() {
    return TInstr::local_get(idx)
  }
  match sinkables.get(key) {
    None => TInstr::local_get(idx)
    Some(info) => {
      let one_use = get_counts[key] == 1
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
                sl_adjust_get_count_for_idx(get_counts, idx, -1)
                sl_adjust_get_count_for_idx(get_counts, other, 1)
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
        sl_adjust_get_count_for_idx(get_counts, idx, -1)
        changed.val = true
        sink_value
      } else {
        if info.out_index >= 0 && info.out_index < out.length() {
          out[info.out_index] = TInstr::nop()
        }
        sl_sinkables_remove(sinkables, sinkable_indexes, key)
        sl_adjust_get_count_for_idx(get_counts, idx, -1)
        changed.val = true
        TInstr::local_tee(idx, sink_value)
      }
    }
  }
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
fn sl_take_terminal_local_set(
  body : TExpr,
) -> (Array[TInstr], LocalIdx, TInstr)? {
  let n = body.instrs.length()
  if n == 0 {
    return None
  }
  match body.instrs[n - 1].kind {
    TInstrKind::TLocalSet(idx, value) => {
      let prefix : Array[TInstr] = []
      for i = 0; i < n - 1; i = i + 1 {
        prefix.push(body.instrs[i])
      }
      Some((prefix, idx, value))
    }
    _ => None
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
                  _ => state.unoptimizable = true
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
        let mut hits_target = sl_labelidx_to_int(default_) == target_depth
        for label in labels {
          if sl_labelidx_to_int(label) == target_depth {
            hits_target = true
          }
        }
        if hits_target {
          state.saw_exit = true
          state.unoptimizable = true
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
                  TInstr::br_if(label, cond, [
                    TInstr::local_tee(shared_local, value),
                  ])
                }
                TInstrKind::TLocalTee(_, value) => {
                  changed.val = true
                  TInstr::br_if(label, cond, [
                    TInstr::local_tee(shared_local, value),
                  ])
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
                    TInstr::br_if(label, cond, [
                      TInstr::local_tee(shared_local, value),
                    ])
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
  get_counts : Array[Int],
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
                      sl_adjust_get_count_for_idx(get_counts, then_idx, 1)
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
  get_counts : Array[Int],
  options : SLSimplifyOptions,
  in_value_position : Bool,
  changed : Ref[Bool],
) -> TInstr {
  match instr.kind {
    TInstrKind::TLocalGet(idx) =>
      sl_try_sink_local_get(
        idx, env, sinkables, sinkable_indexes, out, get_counts, local_types, options,
        in_value_position, changed,
      )
    TInstrKind::TBlock(bt, body) => {
      let body_env = sl_block_body_env(env, bt)
      let (next_body, body_changed) = sl_simplify_texpr_main(
        body, body_env, local_types, get_counts, options,
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
        body, body_env, local_types, get_counts, options,
      )
      if body_changed {
        changed.val = true
      }
      TInstr::loop_(bt, next_body)
    }
    TInstrKind::TTryTable(bt, catches, body) => {
      let body_env = sl_block_body_env(env, bt)
      let (next_body, body_changed) = sl_simplify_texpr_main(
        body, body_env, local_types, get_counts, options,
      )
      if body_changed {
        changed.val = true
      }
      TInstr::try_table(bt, catches, next_body)
    }
    TInstrKind::TIf(bt, cond, then_body, else_body) => {
      let branch_env = sl_block_body_env(env, bt)
      let next_cond = sl_rewrite_instr_main(
        cond, env, sinkables, sinkable_indexes, effects_cache, out, local_types,
        get_counts, options, true, changed,
      )
      let (next_then, then_changed) = sl_simplify_texpr_main(
        then_body, branch_env, local_types, get_counts, options,
      )
      let mut branch_changed = then_changed
      let next_else = match else_body {
        Some(other) => {
          let (rewritten, else_changed) = sl_simplify_texpr_main(
            other, branch_env, local_types, get_counts, options,
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
      let children = eval_children(instr)
      if children.is_empty() {
        return instr
      }
      let next_children : Array[TInstr] = []
      let mut any = false
      for i = 0; i < children.length(); i = i + 1 {
        let child = children[i]
        let next_child = sl_rewrite_instr_main(
          child, env, sinkables, sinkable_indexes, effects_cache, out, local_types,
          get_counts, options, true, changed,
        )
        next_children.push(next_child)
        if next_child != child {
          any = true
        }
        if !sinkables.is_empty() {
          sl_invalidate_sinkables(
            sinkables,
            sinkable_indexes,
            sl_collect_effects_cached(next_child, effects_cache),
          )
        }
      }
      if any {
        changed.val = true
        mb_rebuild_non_control(instr, next_children)
      } else {
        instr
      }
    }
  }
}

///|
fn sl_simplify_texpr_main(
  expr : TExpr,
  env : Env,
  local_types : Array[ValType],
  get_counts : Array[Int],
  options : SLSimplifyOptions,
) -> (TExpr, Bool) {
  let out : Array[TInstr] = []
  let sinkables : Map[Int, SLSinkableInfo] = Map::new()
  let sinkable_indexes = sl_sinkable_indexes_new()
  let effects_cache : Map[TInstr, LCSEffects] = Map::new()
  let changed = Ref::new(false)

  for instr in expr.instrs {
    let rewritten = sl_rewrite_instr_main(
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
    let curr = sl_try_structure_loop_sink(
      curr, env, sinkables, sinkable_indexes, out, local_types, options, changed,
    )
    if !sinkables.is_empty() {
      let curr_effects = sl_collect_effects_cached(curr, effects_cache)
      sl_invalidate_sinkables(sinkables, sinkable_indexes, curr_effects)
    }
    match curr.kind {
      TInstrKind::TLocalSet(idx, value) => {
        let key = sl_localidx_to_int(idx)
        if key >= 0 && key < get_counts.length() {
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
          let uses = get_counts[key]
          if uses > 0 && (options.allow_tee || uses == 1) {
            sl_sinkables_add(sinkables, sinkable_indexes, key, {
              out_index: out.length(),
              value,
              effects: sl_collect_effects_cached(
                TInstr::local_set(idx, value),
                effects_cache,
              ),
            })
          }
        }
      }
      _ => ()
    }
    out.push(curr)
    if lcs_is_non_linear_boundary(curr) || is_unreachable_instr(curr) {
      sinkables.clear()
      sinkable_indexes.reads_by_local.clear()
      sinkable_indexes.writes_by_local.clear()
    }
    if is_unreachable_instr(curr) {
      break
    }
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
      let children = eval_children(instr)
      if children.is_empty() {
        return instr
      }
      let next_children : Array[TInstr] = []
      let mut any = false
      for child in children {
        let next_child = sl_remove_unneeded_sets_instr(
          child, get_counts, changed, true,
        )
        if next_child != child {
          any = true
        }
        next_children.push(next_child)
      }
      if any {
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
      let children = eval_children(instr)
      if children.is_empty() {
        return instr
      }
      let next_children : Array[TInstr] = []
      let mut any = false
      for child in children {
        let next_child = sl_strip_nops_instr(child, changed)
        if next_child != child {
          any = true
        }
        next_children.push(next_child)
      }
      if any {
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
      let children = eval_children(instr)
      if children.is_empty() {
        return instr
      }
      let next_children : Array[TInstr] = []
      let mut changed_children = false
      for child in children {
        let next_child = sl_late_rewrite_instr(child, state, true)
        if next_child != child {
          changed_children = true
        }
        next_children.push(next_child)
      }
      if changed_children {
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
fn sl_run_main_phase(
  body : TExpr,
  env : Env,
  local_types : Array[ValType],
  options : SLSimplifyOptions,
  measure_for_tee : Bool,
  initial_get_counts? : Array[Int]? = None,
  trace? : (String) -> Unit = sl_trace_noop,
  trace_verbose? : Bool = false,
) -> (TExpr, Bool, Bool, Array[Int]) {
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
      let fresh = Array::make(local_types.length(), 0)
      sl_collect_get_counts_texpr(body, fresh)
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
    let mut has_any_get = false
    for n in get_counts {
      if n > 0 {
        has_any_get = true
        break
      }
    }
    if !has_any_get {
      if trace_verbose {
        trace("phase=main:rewrite:skip reason=no_local_gets")
      }
      return (body, false, false, get_counts)
    }
  }
  if trace_verbose {
    trace("phase=main:rewrite:start top_instrs=\{body.instrs.length()}")
  }
  let (next_body, changed) = sl_simplify_texpr_main(
    body, env, local_types, get_counts, options,
  )
  if trace_verbose {
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
    let after_removed = sl_remove_unneeded_sets_texpr(
      body, pre_counts, removed_changed,
    )
    sl_strip_nops_texpr(after_removed, strip_changed)
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
    TFunc(local_vals, body) => {
      let all_locals = sl_canonical_tfunc_locals(params, local_vals)
      let env1 = env
        .with_locals(all_locals)
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
fn sl_keep_validated_rewrite(
  env : Env,
  abs_func_idx : FuncIdx,
  original : Func,
  candidate : Func,
  trace : (String) -> Unit,
) -> (Func, Bool) {
  match sl_validate_typed_function_candidate(env, abs_func_idx, candidate) {
    Ok(_) => (candidate, true)
    Err(err) => {
      trace(
        "func_idx=\{abs_func_idx.to_string()} rewrite rejected after local validation: \{err}",
      )
      (original, false)
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
    TFunc(locals, body) => {
      let local_types = sl_canonical_tfunc_locals(param_types, locals)
      if local_types.length() == 0 {
        return (func, false)
      }
      let mut body = body
      let mut changed_any = false
      let mut first_cycle = true
      let mut continue_cycles = true
      let mut reusable_get_counts : Array[Int]? = None
      let mut cycle = 0
      while continue_cycles {
        cycle += 1
        if trace_verbose {
          trace(
            "cycle=\{cycle} phase=main:start first_cycle=\{first_cycle} top_instrs=\{body.instrs.length()}",
          )
        }
        let cycle_options = if first_cycle {
          {
            allow_tee: false,
            allow_structure: options.allow_structure,
            allow_nesting: options.allow_nesting,
          }
        } else {
          options
        }
        let (after_main, main_changed, _, next_get_counts) = sl_run_main_phase(
          body,
          env,
          local_types,
          cycle_options,
          false,
          initial_get_counts=reusable_get_counts,
          trace~,
          trace_verbose~,
        )
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
            trace("cycle=\{cycle} phase=first_cycle:advance")
          }
          first_cycle = false
          continue
        }
        if main_changed {
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
        let (after_cleanup, cleanup_changed) = sl_run_cleanup_phase(
          body,
          local_types,
          options.allow_structure,
          true,
          trace~,
          trace_verbose~,
        )
        if trace_verbose {
          trace(
            "cycle=\{cycle} phase=cleanup:done changed=\{cleanup_changed} top_instrs=\{after_cleanup.instrs.length()}",
          )
        }
        body = after_cleanup
        if cleanup_changed {
          changed_any = true
          reusable_get_counts = None
          if trace_verbose {
            trace(
              "cycle=\{cycle} phase=late_main:start top_instrs=\{body.instrs.length()}",
            )
          }
          let (after_late_main, late_main_changed, _, late_get_counts) = sl_run_main_phase(
            body,
            env,
            local_types,
            options,
            false,
            trace~,
            trace_verbose~,
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
      if changed_any {
        (Func::t_func(locals, body), true)
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
) -> ModuleTransformer[IRContext] {
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
    let params = param_types.get(def_idx).unwrap_or([])
    let abs_func_idx = FuncIdx::new(
      (imported_func_count + def_idx).reinterpret_as_uint(),
    )
    let func_env = match func {
      TFunc(locals, _) =>
        base_env.with_locals(sl_canonical_tfunc_locals(params, locals))
      _ => base_env
    }
    let func_trace = if log_func {
      fn(msg) { trace("func[\{ordinal}] \{msg}") }
    } else {
      sl_trace_noop
    }
    if log_func {
      match func {
        TFunc(locals, body) =>
          trace(
            "func[\{ordinal}] start locals=\{locals.length()} top_instrs=\{body.instrs.length()} instrs=\{sl_count_all_instrs_texpr(body)} allow_tee=\{allow_tee} allow_structure=\{allow_structure} allow_nesting=\{allow_nesting} validate=\{validate_each_rewrite && can_validate_rewrites}",
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
    let (next_func, changed) = if raw_changed {
      sl_keep_validated_rewrite(
        base_env, abs_func_idx, func, raw_next_func, trace,
      )
    } else {
      (raw_next_func, false)
    }
    if changed {
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
        let elapsed_ms = sl_trace_elapsed_ms(func_start_ms)
        match (func, next_func) {
          (TFunc(locals, body), TFunc(_, next_body)) =>
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
        let elapsed_ms = sl_trace_elapsed_ms(func_start_ms)
        match func {
          TFunc(locals, body) =>
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
    Ok(Some((_, out))) => out
    Ok(None) => mod
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
    Some(CodeSec([TFunc(_, body)])) => {
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
    Some(CodeSec([TFunc(_, body)])) => {
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
    Some(CodeSec([TFunc(_, body)])) => {
      let stats = SLLocalStats::new()
      sl_collect_local_stats_texpr(body, stats)
      assert_true(stats.sets >= 1)
      assert_eq(stats.tees, 0)
    }
    _ => fail("expected one typed function")
  }
}

///|
test "simplify_locals structure mode creates result if from branch-local sets" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
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
    Some(CodeSec([TFunc(_, body)])) => assert_true(sl_has_result_if_texpr(body))
    _ => fail("expected one typed function")
  }
}

///|
test "simplify_locals no-nesting mode avoids sinking non-get values into get sites" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
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
    Some(CodeSec([TFunc(_, body)])) => {
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
    Some(CodeSec([TFunc(_, body)])) => {
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
    Some(CodeSec([TFunc(_, body)])) => {
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
    TFunc(_, body) => assert_true(sl_has_result_block_texpr(body))
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
  let counts = Array::make(2, 0)
  sl_collect_get_counts_texpr(body, counts)
  let (next_body, changed) = sl_simplify_texpr_main(
    body,
    sl_test_env([ValType::i32(), ValType::i32()]),
    [ValType::i32(), ValType::i32()],
    counts,
    { allow_tee: false, allow_structure: true, allow_nesting: true },
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
    [2, 1],
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
    Some(CodeSec([TFunc(_, body)])) =>
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
    Some(CodeSec([TFunc(_, body)])) =>
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
    Some(CodeSec([TFunc(_, body)])) =>
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
    Some(CodeSec([TFunc(_, body)])) => {
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
      TypeSec::new([single_rec_type(comp_type_sub_type(func_comp_type([], [])))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([Func::t_func(local_types, rewritten)]))
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
      TypeSec::new([single_rec_type(comp_type_sub_type(func_comp_type([], [])))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
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
        [TFunc(_, { instrs: [{ kind: TInstrKind::TBlock(_, body), .. }], .. })]
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
  let rewritten = sl_try_sink_local_get(
    LocalIdx::new(0),
    sl_test_env([
      ValType::ref_type(RefType::new(false, HeapType::abs(AbsHeapType::func()))),
      ValType::funcref(),
    ]),
    sinkables,
    sinkable_indexes,
    out,
    [2, 1],
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
  let rewritten = sl_try_sink_local_get(
    LocalIdx::new(0),
    sl_test_env([ValType::funcref()]),
    sinkables,
    sinkable_indexes,
    out,
    [1],
    [ValType::funcref()],
    { allow_tee: false, allow_structure: false, allow_nesting: true },
    false,
    changed,
  )
  assert_eq(rewritten, TInstr::ref_func(FuncIdx::new(0)))
  assert_true(changed.val)
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
      TypeSec::new([single_rec_type(comp_type_sub_type(func_comp_type([], [])))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
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
  let out = sl_run_simplify_locals(
    mod,
    allow_tee=false,
    allow_structure=false,
    allow_nesting=true,
  )
  assert_eq(validate_module(out), Ok(()))
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) =>
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
      TypeSec::new([single_rec_type(comp_type_sub_type(func_comp_type([], [])))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
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
    Some(CodeSec([TFunc(_, body)])) =>
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
test "simplify_locals typed function validator rejects local.set result type mismatch" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([single_rec_type(comp_type_sub_type(func_comp_type([], [])))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  let env = Env::new().with_module(mod)
  let candidate = Func::t_func(
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
test "simplify_locals typed function validator accepts canonical locals including params" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        single_rec_type(comp_type_sub_type(func_comp_type([ValType::i32()], []))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  let env = Env::new().with_module(mod)
  let candidate = Func::t_func(
    [ValType::i32(), ValType::i64()],
    TExpr::new([
      TInstr::local_set(LocalIdx::new(1), TInstr::i64_const(I64(7))),
    ]),
  )
  match sl_validate_typed_function_candidate(env, FuncIdx::new(0), candidate) {
    Ok(_) => ()
    Err(e) => fail("expected canonical locals to validate, got: " + e)
  }
}

///|
test "simplify_locals rewrite finalizer keeps original invalid candidate out" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([single_rec_type(comp_type_sub_type(func_comp_type([], [])))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  let env = Env::new().with_module(mod)
  let original = Func::t_func([ValType::i64()], TExpr::new([]))
  let invalid_candidate = Func::t_func(
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
test "simplify_locals keeps nested branchy result-if pattern valid" {
  let x = LocalIdx::new(0)
  let cond0 = LocalIdx::new(1)
  let cond1 = LocalIdx::new(2)
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([single_rec_type(comp_type_sub_type(func_comp_type([], [])))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
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
    Some(CodeSec([TFunc(_, body)])) => {
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
  let counts = Array::make(1, 0)
  sl_collect_get_counts_texpr(body, counts)
  let (next_body, changed) = sl_simplify_texpr_main(
    body,
    sl_test_env([ValType::i32()]),
    [ValType::i32()],
    counts,
    { allow_tee: false, allow_structure: true, allow_nesting: false },
  )
  assert_true(changed)
  let actual = Array::make(1, 0)
  sl_collect_get_counts_texpr(next_body, actual)
  assert_eq(counts[0], actual[0])
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
    [0],
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
    TFunc(_, body) => assert_eq(sl_count_local_sets_for_idx_texpr(body, 0), 0)
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
      TypeSec::new([single_rec_type(comp_type_sub_type(func_comp_type([], [])))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::funcref()],
          TExpr::new([
            TInstr::local_set(x, TInstr::ref_func(FuncIdx::new(0))),
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
  assert_eq(validate_module(out), Ok(()))
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => {
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
      Func::t_func(locals, TExpr::new(body_instrs)),
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
      Func::t_func(locals, TExpr::new(body_instrs)),
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
      Func::t_func(locals, TExpr::new(body_instrs)),
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
