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
  for instr in expr.instrs {
    sl_collect_get_counts_and_late_candidate_instr(
      instr, counts, saw_late_candidate,
    )
  }
}

///|
fn sl_try_sink_local_get(
  idx : LocalIdx,
  sinkables : Map[Int, SLSinkableInfo],
  out : Array[TInstr],
  get_counts : Array[Int],
  local_types : Array[ValType],
  options : SLSimplifyOptions,
  parent_is_set_value : Bool,
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
      if !options.allow_nesting && !sink_is_get && !parent_is_set_value {
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
                local_types[other_i] == local_types[key] {
                changed.val = true
                TInstr::local_get(other)
              } else {
                TInstr::local_get(idx)
              }
            }
          _ => TInstr::local_get(idx)
        }
      } else if one_use {
        if info.out_index >= 0 && info.out_index < out.length() {
          out[info.out_index] = TInstr::nop()
        }
        sinkables.remove(key)
        changed.val = true
        sink_value
      } else {
        if info.out_index >= 0 && info.out_index < out.length() {
          out[info.out_index] = TInstr::nop()
        }
        sinkables.remove(key)
        changed.val = true
        TInstr::local_tee(idx, sink_value)
      }
    }
  }
}

///|
fn sl_invalidate_sinkables(
  sinkables : Map[Int, SLSinkableInfo],
  effects : LCSEffects,
) -> Unit {
  let to_remove : Array[Int] = []
  for entry in sinkables {
    let (idx, info) = entry
    if effects.invalidates(info.effects) {
      to_remove.push(idx)
    }
  }
  for idx in to_remove {
    sinkables.remove(idx)
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
  changed : Ref[Bool],
) -> TInstr {
  if !options.allow_structure {
    return instr
  }
  ignore(env)
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
                let candidate = TInstr::local_set(
                  shared_idx,
                  TInstr::block(
                    BlockType::val_type(local_type),
                    TExpr::new(body_result),
                  ),
                )
                changed.val = changed.val ||
                  block_changed.val ||
                  candidate != instr
                candidate
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
  sinkables : Map[Int, SLSinkableInfo],
  out : Array[TInstr],
  local_types : Array[ValType],
  options : SLSimplifyOptions,
  changed : Ref[Bool],
) -> TInstr {
  ignore(sinkables)
  ignore(out)
  ignore(local_types)
  ignore(options)
  ignore(changed)
  // Disabled until loop result conversion proves every exit and continue path.
  instr
}

///|
fn sl_try_structure_if(
  instr : TInstr,
  env : Env,
  local_types : Array[ValType],
  options : SLSimplifyOptions,
  changed : Ref[Bool],
) -> TInstr {
  if !options.allow_structure {
    return instr
  }
  ignore(env)
  match instr.kind {
    TInstrKind::TIf(VoidBlockType, cond, then_body, else_body) =>
      match else_body {
        Some(other) => {
          if sl_has_branch_to_depth_texpr(then_body, 0) ||
            sl_has_branch_to_depth_texpr(other, 0) {
            return instr
          }
          let then_set = sl_take_terminal_local_set(then_body)
          let else_set = sl_take_terminal_local_set(other)
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
                    let candidate = TInstr::local_set(
                      then_idx,
                      TInstr::if_(
                        BlockType::val_type(local_type),
                        cond,
                        TExpr::new(next_then),
                        Some(TExpr::new(next_else)),
                      ),
                    )
                    changed.val = true
                    candidate
                  }
                  None => instr
                }
              } else {
                instr
              }
            _ => instr
          }
        }
        None =>
          match sl_take_terminal_local_set(then_body) {
            Some((then_prefix, then_idx, then_value)) => {
              if sl_has_branch_to_depth_texpr(then_body, 0) {
                return instr
              }
              let idx_i = sl_localidx_to_int(then_idx)
              match local_types.get(idx_i) {
                Some(local_type) =>
                  if sl_is_defaultable(local_type) {
                    let next_then = then_prefix.copy()
                    next_then.push(then_value)
                    let candidate = TInstr::local_set(
                      then_idx,
                      TInstr::if_(
                        BlockType::val_type(local_type),
                        cond,
                        TExpr::new(next_then),
                        Some(TExpr::new([TInstr::local_get(then_idx)])),
                      ),
                    )
                    changed.val = true
                    candidate
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
  out : Array[TInstr],
  local_types : Array[ValType],
  get_counts : Array[Int],
  options : SLSimplifyOptions,
  parent_is_set_value : Bool,
  changed : Ref[Bool],
) -> TInstr {
  match instr.kind {
    TInstrKind::TLocalGet(idx) =>
      sl_try_sink_local_get(
        idx, sinkables, out, get_counts, local_types, options, parent_is_set_value,
        changed,
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
        cond, env, sinkables, out, local_types, get_counts, options, false, changed,
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
      sl_try_structure_if(rebuilt, env, local_types, options, changed)
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
        let child_parent_is_set = match instr.kind {
          TInstrKind::TLocalSet(_, _) | TInstrKind::TLocalTee(_, _) => i == 0
          _ => false
        }
        let next_child = sl_rewrite_instr_main(
          child, env, sinkables, out, local_types, get_counts, options, child_parent_is_set,
          changed,
        )
        next_children.push(next_child)
        if next_child != child {
          any = true
        }
        sl_invalidate_sinkables(sinkables, lcs_collect_effects(next_child))
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
  let changed = Ref::new(false)

  for instr in expr.instrs {
    let rewritten = sl_rewrite_instr_main(
      instr, env, sinkables, out, local_types, get_counts, options, false, changed,
    )
    let curr = match rewritten.kind {
      TInstrKind::TDrop({ kind: TInstrKind::TLocalTee(idx, value), .. }) => {
        changed.val = true
        TInstr::local_set(idx, value)
      }
      _ => rewritten
    }
    let curr = sl_try_structure_loop_sink(
      curr, sinkables, out, local_types, options, changed,
    )
    let curr_effects = lcs_collect_effects(curr)
    sl_invalidate_sinkables(sinkables, curr_effects)
    match curr.kind {
      TInstrKind::TLocalSet(idx, value) => {
        let key = sl_localidx_to_int(idx)
        if key >= 0 && key < get_counts.length() {
          match sinkables.get(key) {
            Some(previous) => {
              if previous.out_index >= 0 && previous.out_index < out.length() {
                out[previous.out_index] = TInstr::drop(previous.value)
              }
              sinkables.remove(key)
              changed.val = true
            }
            None => ()
          }
          let uses = get_counts[key]
          if uses > 0 && (options.allow_tee || uses == 1) {
            sinkables[key] = {
              out_index: out.length(),
              value,
              effects: lcs_collect_effects(value),
            }
          }
        }
      }
      _ => ()
    }
    out.push(curr)
    if lcs_is_non_linear_boundary(curr) || is_unreachable_instr(curr) {
      sinkables.clear()
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
) -> TInstr {
  match instr.kind {
    TInstrKind::TLocalSet(idx, value) => {
      let next_value = sl_remove_unneeded_sets_instr(value, get_counts, changed)
      let key = sl_localidx_to_int(idx)
      if key >= 0 && key < get_counts.length() && get_counts[key] == 0 {
        changed.val = true
        TInstr::drop(next_value)
      } else if next_value != value {
        changed.val = true
        TInstr::local_set(idx, next_value)
      } else {
        instr
      }
    }
    TInstrKind::TLocalTee(idx, value) => {
      let next_value = sl_remove_unneeded_sets_instr(value, get_counts, changed)
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
      let next_cond = sl_remove_unneeded_sets_instr(cond, get_counts, changed)
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
          child, get_counts, changed,
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
    out.push(sl_remove_unneeded_sets_instr(instr, get_counts, changed))
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
  local_types : Array[ValType]
  get_counts : Array[Int]
  remove_equivalent_sets : Bool
  changed : Ref[Bool]
}

///|
fn sl_late_state_new(
  local_types : Array[ValType],
  get_counts : Array[Int],
  remove_equivalent_sets : Bool,
  changed : Ref[Bool],
) -> SLLateState {
  let local_count = local_types.length()
  let rep_of : Array[Int] = []
  let members : Array[Array[Int]] = []
  for i = 0; i < local_count; i = i + 1 {
    rep_of.push(i)
    members.push([i])
  }
  { rep_of, members, local_types, get_counts, remove_equivalent_sets, changed }
}

///|
fn sl_late_clear(state : SLLateState) -> Unit {
  for i = 0; i < state.rep_of.length(); i = i + 1 {
    state.rep_of[i] = i
    state.members[i] = [i]
  }
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
    if class_members.length() > 1 {
      let next_rep = if class_members[0] == idx {
        class_members[1]
      } else {
        class_members[0]
      }
      let next_members : Array[Int] = []
      for class_idx in class_members {
        if class_idx != idx {
          next_members.push(class_idx)
        }
      }
      for class_idx in next_members {
        state.rep_of[class_idx] = next_rep
      }
      state.members[next_rep] = next_members
    }
  } else {
    let next_members : Array[Int] = []
    for class_idx in state.members[rep] {
      if class_idx != idx {
        next_members.push(class_idx)
      }
    }
    state.members[rep] = next_members
  }
  state.rep_of[idx] = idx
  state.members[idx] = [idx]
}

///|
fn sl_late_add_equivalence(state : SLLateState, a : Int, b : Int) -> Unit {
  if a < 0 || b < 0 || a >= state.rep_of.length() || b >= state.rep_of.length() {
    return
  }
  if state.local_types[a] != state.local_types[b] {
    return
  }
  let mut rep_a = state.rep_of[a]
  let mut rep_b = state.rep_of[b]
  if rep_a == rep_b {
    return
  }
  if state.members[rep_a].length() < state.members[rep_b].length() {
    let tmp = rep_a
    rep_a = rep_b
    rep_b = tmp
  }
  let merged = state.members[rep_a].copy()
  for idx in state.members[rep_b] {
    merged.push(idx)
    state.rep_of[idx] = rep_a
  }
  state.members[rep_a] = merged
  state.members[rep_b] = []
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
fn sl_late_rewrite_instr(instr : TInstr, state : SLLateState) -> TInstr {
  match instr.kind {
    TInstrKind::TLocalSet(idx, value) => {
      let next_value = sl_late_rewrite_instr(value, state)
      let idx_i = sl_localidx_to_int(idx)
      match sl_get_fallthrough(next_value).kind {
        TInstrKind::TLocalGet(src_idx) => {
          let src_i = sl_localidx_to_int(src_idx)
          if sl_late_is_equivalent(state, idx_i, src_i) {
            if state.remove_equivalent_sets {
              state.changed.val = true
              TInstr::drop(next_value)
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
      let next_value = sl_late_rewrite_instr(value, state)
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
      for candidate in state.members[rep] {
        if candidate == best {
          continue
        }
        let cand_count = sl_late_get_count_ignoring_curr(
          state, candidate, idx_i,
        )
        let best_count = sl_late_get_count_ignoring_curr(state, best, idx_i)
        if cand_count > best_count {
          best = candidate
        }
      }
      if best != idx_i &&
        sl_late_get_count_ignoring_curr(state, best, idx_i) >
        sl_late_get_count_ignoring_curr(state, idx_i, idx_i) {
        state.get_counts[best] = state.get_counts[best] + 1
        if state.get_counts[idx_i] > 0 {
          state.get_counts[idx_i] = state.get_counts[idx_i] - 1
        }
        state.changed.val = true
        TInstr::local_get(sl_localidx_from_int(best))
      } else {
        instr
      }
    }
    TInstrKind::TBlock(bt, body) => {
      let child = sl_late_state_new(
        state.local_types,
        state.get_counts,
        state.remove_equivalent_sets,
        state.changed,
      )
      let next_body = sl_late_rewrite_texpr(body, child)
      if next_body != body {
        state.changed.val = true
        TInstr::block(bt, next_body)
      } else {
        instr
      }
    }
    TInstrKind::TLoop(bt, body) => {
      let child = sl_late_state_new(
        state.local_types,
        state.get_counts,
        state.remove_equivalent_sets,
        state.changed,
      )
      let next_body = sl_late_rewrite_texpr(body, child)
      if next_body != body {
        state.changed.val = true
        TInstr::loop_(bt, next_body)
      } else {
        instr
      }
    }
    TInstrKind::TTryTable(bt, catches, body) => {
      let child = sl_late_state_new(
        state.local_types,
        state.get_counts,
        state.remove_equivalent_sets,
        state.changed,
      )
      let next_body = sl_late_rewrite_texpr(body, child)
      if next_body != body {
        state.changed.val = true
        TInstr::try_table(bt, catches, next_body)
      } else {
        instr
      }
    }
    TInstrKind::TIf(bt, cond, then_body, else_body) => {
      let next_cond = sl_late_rewrite_instr(cond, state)
      let then_state = sl_late_state_new(
        state.local_types,
        state.get_counts,
        state.remove_equivalent_sets,
        state.changed,
      )
      let next_then = sl_late_rewrite_texpr(then_body, then_state)
      let next_else = else_body.map(fn(other) {
        let else_state = sl_late_state_new(
          state.local_types,
          state.get_counts,
          state.remove_equivalent_sets,
          state.changed,
        )
        sl_late_rewrite_texpr(other, else_state)
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
        let next_child = sl_late_rewrite_instr(child, state)
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
    let next = sl_late_rewrite_instr(instr, state)
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
  let late_local_limit = if remove_equivalent_sets { 256 } else { 128 }
  if local_count > late_local_limit {
    return (body, false)
  }
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
    local_types, get_counts, remove_equivalent_sets, changed,
  )
  let next = sl_late_rewrite_texpr(body, state)
  (next, changed.val)
}

///|
fn sl_has_multi_use_locals(get_counts : Array[Int]) -> Bool {
  for count in get_counts {
    if count > 1 {
      return true
    }
  }
  false
}

///|
fn sl_run_main_phase(
  body : TExpr,
  env : Env,
  local_types : Array[ValType],
  options : SLSimplifyOptions,
  measure_for_tee : Bool,
) -> (TExpr, Bool, Bool, Array[Int]) {
  let get_counts = Array::make(local_types.length(), 0)
  sl_collect_get_counts_texpr(body, get_counts)
  let (next_body, changed) = sl_simplify_texpr_main(
    body, env, local_types, get_counts, options,
  )
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
) -> (TExpr, Bool) {
  let removed_changed = Ref::new(false)
  let strip_changed = Ref::new(false)
  let after_strip = if had_prior_changes {
    let get_counts = Array::make(local_types.length(), 0)
    sl_collect_get_counts_texpr(body, get_counts)
    let after_removed = sl_remove_unneeded_sets_texpr(
      body, get_counts, removed_changed,
    )
    sl_strip_nops_texpr(after_removed, strip_changed)
  } else {
    body
  }
  let (after_late, late_changed) = sl_run_late_optimizations(
    after_strip, local_types, remove_equivalent_sets,
  )
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
fn sl_simplify_function(
  func : Func,
  env : Env,
  param_types : Array[ValType],
  options : SLSimplifyOptions,
) -> (Func, Bool) {
  match func {
    TFunc(locals, body) => {
      let local_types = param_types.copy()
      for local_ in locals {
        local_types.push(local_)
      }
      if local_types.length() == 0 {
        return (func, false)
      }
      let mut body = body
      let mut changed_any = false
      let (after_no_tee, changed_no_tee, shrank_no_tee, get_counts) = sl_run_main_phase(
        body,
        env,
        local_types,
        {
          allow_tee: false,
          allow_structure: options.allow_structure,
          allow_nesting: options.allow_nesting,
        },
        options.allow_tee,
      )
      body = after_no_tee
      if changed_no_tee {
        changed_any = true
      }

      if options.allow_tee &&
        (sl_has_multi_use_locals(get_counts) || shrank_no_tee) {
        let (after_tee, changed_tee, _, _) = sl_run_main_phase(
          body, env, local_types, options, false,
        )
        body = after_tee
        if changed_tee {
          changed_any = true
        }
      }

      let (after_cleanup, cleanup_changed) = sl_run_cleanup_phase(
        body,
        local_types,
        options.allow_structure,
        changed_any,
      )
      body = after_cleanup
      if cleanup_changed {
        changed_any = true
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
    let log_func = trace_all_funcs || ordinal <= 5 || ordinal % 500 == 0
    let func_start_ms = sl_trace_now_ms()
    let params = param_types.get(def_idx).unwrap_or([])
    let func_env = match func {
      TFunc(locals, _) => base_env.with_locals(params + locals)
      _ => base_env
    }
    if log_func {
      match func {
        TFunc(locals, body) =>
          trace(
            "func[\{ordinal}] start locals=\{locals.length()} top_instrs=\{body.instrs.length()} allow_tee=\{allow_tee} allow_structure=\{allow_structure} allow_nesting=\{allow_nesting} validate=\{validate_each_rewrite && can_validate_rewrites}",
          )
        _ => trace("func[\{ordinal}] skip non-typed-func")
      }
    }
    let (next_func, changed) = sl_simplify_function(
      func, func_env, params, options,
    )
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
    allow_tee=false,
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
  let out : Array[TInstr] = []
  let changed = Ref::new(false)
  let next = sl_rewrite_instr_main(
    block,
    sl_test_env([ValType::i32(), ValType::i32()]),
    sinkables,
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
      assert_false(sl_has_result_loop_texpr(body))
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
test "simplify_locals sink helper keeps multi-use local.get when local types differ" {
  let sinkables : Map[Int, SLSinkableInfo] = Map::new()
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
    sinkables,
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
test "simplify_locals late canonicalization does not rewrite non-null refs to nullable equivalents" {
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
  assert_false(changed)
  assert_eq(sl_count_local_gets_for_idx_texpr(rewritten, 0), 2)
  assert_eq(sl_count_local_gets_for_idx_texpr(rewritten, 1), 2)
}

///|
test "simplify_locals skips result-if rewrite when branch exits would invalidate result typing" {
  let x = LocalIdx::new(0)
  let cond = LocalIdx::new(1)
  let mod = Module::new().with_code_sec(
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
            Some(TExpr::new([TInstr::local_set(x, TInstr::i32_const(I32(2)))])),
          ),
          TInstr::drop(TInstr::local_get(x)),
        ]),
      ),
    ]),
  )
  let out = sl_run_simplify_locals(mod, allow_tee=false, allow_structure=true)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) =>
      assert_false(sl_has_result_if_texpr(body))
    _ => fail("expected one typed function")
  }
}
