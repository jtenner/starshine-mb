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
fn sl_collect_local_stats_instr(instr : TInstr, stats : SLLocalStats) -> Unit {
  match instr {
    TLocalSet(_, value) => {
      stats.sets += 1
      sl_collect_local_stats_instr(value, stats)
    }
    TLocalTee(_, value) => {
      stats.tees += 1
      sl_collect_local_stats_instr(value, stats)
    }
    TLocalGet(_) => stats.gets += 1
    TBlock(_, body) | TLoop(_, body) | TTryTable(_, _, body) =>
      sl_collect_local_stats_texpr(body, stats)
    TIf(_, cond, then_body, else_body) => {
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
  for instr in expr.0 {
    sl_collect_local_stats_instr(instr, stats)
  }
}

///|
fn sl_has_result_if_instr(instr : TInstr) -> Bool {
  match instr {
    TIf(ValTypeBlockType(_), _, _, _) => true
    TBlock(_, body) | TLoop(_, body) | TTryTable(_, _, body) =>
      sl_has_result_if_texpr(body)
    TIf(_, cond, then_body, else_body) => {
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
  for instr in expr.0 {
    if sl_has_result_if_instr(instr) {
      return true
    }
  }
  false
}

///|
fn sl_count_local_gets_for_idx_instr(instr : TInstr, idx : Int) -> Int {
  let mut total = 0
  match instr {
    TLocalGet(local_idx) =>
      if sl_localidx_to_int(local_idx) == idx {
        total += 1
      }
    TBlock(_, body) | TLoop(_, body) | TTryTable(_, _, body) =>
      total += sl_count_local_gets_for_idx_texpr(body, idx)
    TIf(_, cond, then_body, else_body) => {
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
  for instr in expr.0 {
    total += sl_count_local_gets_for_idx_instr(instr, idx)
  }
  total
}

///|
fn sl_has_local_set_for_idx_instr(instr : TInstr, idx : Int) -> Bool {
  match instr {
    TLocalSet(local_idx, value) | TLocalTee(local_idx, value) => {
      if sl_localidx_to_int(local_idx) == idx {
        return true
      }
      sl_has_local_set_for_idx_instr(value, idx)
    }
    TBlock(_, body) | TLoop(_, body) | TTryTable(_, _, body) =>
      sl_has_local_set_for_idx_texpr(body, idx)
    TIf(_, cond, then_body, else_body) => {
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
  for instr in expr.0 {
    if sl_has_local_set_for_idx_instr(instr, idx) {
      return true
    }
  }
  false
}

///|
fn sl_count_local_sets_for_idx_instr(instr : TInstr, idx : Int) -> Int {
  let mut total = 0
  match instr {
    TLocalSet(local_idx, value) | TLocalTee(local_idx, value) => {
      if sl_localidx_to_int(local_idx) == idx {
        total += 1
      }
      total += sl_count_local_sets_for_idx_instr(value, idx)
    }
    TBlock(_, body) | TLoop(_, body) | TTryTable(_, _, body) =>
      total += sl_count_local_sets_for_idx_texpr(body, idx)
    TIf(_, cond, then_body, else_body) => {
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
  for instr in expr.0 {
    total += sl_count_local_sets_for_idx_instr(instr, idx)
  }
  total
}

///|
fn sl_has_result_block_instr(instr : TInstr) -> Bool {
  match instr {
    TBlock(ValTypeBlockType(_), _) => true
    TBlock(_, body) | TLoop(_, body) | TTryTable(_, _, body) =>
      sl_has_result_block_texpr(body)
    TIf(_, cond, then_body, else_body) => {
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
  for instr in expr.0 {
    if sl_has_result_block_instr(instr) {
      return true
    }
  }
  false
}

///|
fn sl_has_result_loop_instr(instr : TInstr) -> Bool {
  match instr {
    TLoop(ValTypeBlockType(_), _) => true
    TBlock(_, body) | TLoop(_, body) | TTryTable(_, _, body) =>
      sl_has_result_loop_texpr(body)
    TIf(_, cond, then_body, else_body) => {
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
  for instr in expr.0 {
    if sl_has_result_loop_instr(instr) {
      return true
    }
  }
  false
}

///|
fn sl_has_br_if_with_tee_value_instr(instr : TInstr, idx : Int) -> Bool {
  match instr {
    TBrIf(_, _, [TLocalTee(local_idx, _)]) =>
      sl_localidx_to_int(local_idx) == idx
    TBlock(_, body) | TLoop(_, body) | TTryTable(_, _, body) =>
      sl_has_br_if_with_tee_value_texpr(body, idx)
    TIf(_, cond, then_body, else_body) => {
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
  for instr in expr.0 {
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
  match instr {
    TLocalSet(local_idx, _) => sl_localidx_to_int(local_idx) == idx
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
fn sl_collect_get_counts_instr(instr : TInstr, counts : Array[Int]) -> Unit {
  match instr {
    TLocalGet(idx) => {
      let i = sl_localidx_to_int(idx)
      if i >= 0 && i < counts.length() {
        counts[i] += 1
      }
    }
    TBlock(_, body) | TLoop(_, body) | TTryTable(_, _, body) =>
      sl_collect_get_counts_texpr(body, counts)
    TIf(_, cond, then_body, else_body) => {
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
  for instr in expr.0 {
    sl_collect_get_counts_instr(instr, counts)
  }
}

///|
fn sl_try_sink_local_get(
  idx : LocalIdx,
  sinkables : Map[Int, SLSinkableInfo],
  out : Array[TInstr],
  get_counts : Array[Int],
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
      let sink_is_get = match sink_value {
        TLocalGet(_) => true
        _ => false
      }
      if !options.allow_nesting && !sink_is_get && !parent_is_set_value {
        return TInstr::local_get(idx)
      }
      if !one_use && !options.allow_tee {
        match sink_value {
          TLocalGet(other) =>
            if options.allow_nesting {
              TInstr::local_get(idx)
            } else {
              changed.val = true
              TInstr::local_get(other)
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
  let n = body.0.length()
  if n == 0 {
    return None
  }
  match body.0[n - 1] {
    TLocalSet(idx, value) => {
      let prefix : Array[TInstr] = []
      for i = 0; i < n - 1; i = i + 1 {
        prefix.push(body.0[i])
      }
      Some((prefix, idx, value))
    }
    _ => None
  }
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
  match values[0] {
    TLocalSet(idx, _) | TLocalTee(idx, _) => Some(sl_localidx_to_int(idx))
    _ => None
  }
}

///|
fn sl_collect_block_exit_candidates_texpr(
  body : TExpr,
  target_depth : Int,
  state : SLBlockCollectState,
) -> Unit {
  for i = 0; i < body.0.length(); i = i + 1 {
    let curr = body.0[i]
    let prev = if i > 0 { Some(body.0[i - 1]) } else { None }
    match curr {
      TBr(label, values) =>
        if sl_labelidx_to_int(label) == target_depth {
          state.saw_exit = true
          match sl_branch_value_candidate_idx(values) {
            Some(idx) => sl_collect_shared_idx(state, idx)
            None =>
              match prev {
                Some(TLocalSet(prev_idx, _)) if values.length() == 0 =>
                  sl_collect_shared_idx(state, sl_localidx_to_int(prev_idx))
                _ => state.unoptimizable = true
              }
          }
        }
      TBrIf(label, cond, values) => {
        sl_collect_block_exit_candidates_texpr(
          TExpr::new([cond]),
          target_depth,
          state,
        )
        if sl_labelidx_to_int(label) == target_depth {
          state.saw_exit = true
          match sl_branch_value_candidate_idx(values) {
            Some(idx) => sl_collect_shared_idx(state, idx)
            None =>
              match prev {
                Some(TLocalSet(prev_idx, _)) if values.length() == 0 =>
                  sl_collect_shared_idx(state, sl_localidx_to_int(prev_idx))
                _ => state.unoptimizable = true
              }
          }
        }
      }
      TBrTable(labels, default_, idx, values) => {
        sl_collect_block_exit_candidates_texpr(
          TExpr::new([idx]),
          target_depth,
          state,
        )
        for value in values {
          sl_collect_block_exit_candidates_texpr(
            TExpr::new([value]),
            target_depth,
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
      TBrOnNull(label, ref_, values) | TBrOnNonNull(label, ref_, values) => {
        sl_collect_block_exit_candidates_texpr(
          TExpr::new([ref_]),
          target_depth,
          state,
        )
        for value in values {
          sl_collect_block_exit_candidates_texpr(
            TExpr::new([value]),
            target_depth,
            state,
          )
        }
        if sl_labelidx_to_int(label) == target_depth {
          state.saw_exit = true
          state.unoptimizable = true
        }
      }
      TBrOnCast(label, _, _, _, ref_, values)
      | TBrOnCastFail(label, _, _, _, ref_, values) => {
        sl_collect_block_exit_candidates_texpr(
          TExpr::new([ref_]),
          target_depth,
          state,
        )
        for value in values {
          sl_collect_block_exit_candidates_texpr(
            TExpr::new([value]),
            target_depth,
            state,
          )
        }
        if sl_labelidx_to_int(label) == target_depth {
          state.saw_exit = true
          state.unoptimizable = true
        }
      }
      TBlock(_, nested) | TLoop(_, nested) | TTryTable(_, _, nested) =>
        sl_collect_block_exit_candidates_texpr(nested, target_depth + 1, state)
      TIf(_, cond, then_body, else_body) => {
        sl_collect_block_exit_candidates_texpr(
          TExpr::new([cond]),
          target_depth,
          state,
        )
        sl_collect_block_exit_candidates_texpr(
          then_body,
          target_depth + 1,
          state,
        )
        match else_body {
          Some(other) =>
            sl_collect_block_exit_candidates_texpr(
              other,
              target_depth + 1,
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
  changed : Ref[Bool],
) -> TExpr {
  let out : Array[TInstr] = []
  let shared_local = sl_localidx_from_int(shared_idx)
  for i = 0; i < body.0.length(); i = i + 1 {
    let curr = body.0[i]
    let next = match curr {
      TBr(label, values) =>
        if sl_labelidx_to_int(label) == target_depth {
          match sl_branch_value_candidate_idx(values) {
            Some(idx) if idx == shared_idx =>
              match values[0] {
                TLocalSet(_, value) | TLocalTee(_, value) => {
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
                match out[out.length() - 1] {
                  TLocalSet(_, value) => {
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
      TBrIf(label, cond, values) =>
        if sl_labelidx_to_int(label) == target_depth {
          match sl_branch_value_candidate_idx(values) {
            Some(idx) if idx == shared_idx =>
              match values[0] {
                TLocalSet(_, value) => {
                  changed.val = true
                  TInstr::br_if(label, cond, [
                    TInstr::local_tee(shared_local, value),
                  ])
                }
                TLocalTee(_, value) => {
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
                match out[out.length() - 1] {
                  TLocalSet(_, value) => {
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
      TBlock(bt, nested) =>
        TInstr::block(
          bt,
          sl_rewrite_block_exits_texpr(
            nested,
            target_depth + 1,
            shared_idx,
            changed,
          ),
        )
      TLoop(bt, nested) =>
        TInstr::loop_(
          bt,
          sl_rewrite_block_exits_texpr(
            nested,
            target_depth + 1,
            shared_idx,
            changed,
          ),
        )
      TTryTable(bt, catches, nested) =>
        TInstr::try_table(
          bt,
          catches,
          sl_rewrite_block_exits_texpr(
            nested,
            target_depth + 1,
            shared_idx,
            changed,
          ),
        )
      TIf(bt, cond, then_body, else_body) =>
        TInstr::if_(
          bt,
          sl_rewrite_block_exits_texpr(
            TExpr::new([cond]),
            target_depth,
            shared_idx,
            changed,
          ).0[0],
          sl_rewrite_block_exits_texpr(
            then_body,
            target_depth + 1,
            shared_idx,
            changed,
          ),
          else_body.map(fn(other) {
            sl_rewrite_block_exits_texpr(
              other,
              target_depth + 1,
              shared_idx,
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
  local_types : Array[ValType],
  options : SLSimplifyOptions,
  changed : Ref[Bool],
) -> TInstr {
  if !options.allow_structure {
    return instr
  }
  match instr {
    TBlock(VoidBlockType, body) =>
      match sl_take_terminal_local_set(body) {
        Some((_, fall_idx, _)) => {
          let fall_raw = sl_localidx_to_int(fall_idx)
          let collect = SLBlockCollectState::new()
          sl_collect_block_exit_candidates_texpr(body, 0, collect)
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
          let next_body = sl_rewrite_block_exits_texpr(
            body, 0, shared_raw, changed,
          )
          match sl_take_terminal_local_set(next_body) {
            Some((prefix, shared_idx, value)) =>
              if sl_localidx_to_int(shared_idx) == shared_raw {
                let body_result = prefix.copy()
                body_result.push(value)
                changed.val = true
                TInstr::local_set(
                  shared_idx,
                  TInstr::block(
                    BlockType::val_type(local_type),
                    TExpr::new(body_result),
                  ),
                )
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
  if !options.allow_structure {
    return instr
  }
  match instr {
    TLoop(VoidBlockType, body) => {
      if sinkables.is_empty() {
        return instr
      }
      let mut picked_idx = -1
      let mut picked_info : SLSinkableInfo? = None
      for entry in sinkables {
        let (idx, info) = entry
        picked_idx = idx
        picked_info = Some(info)
        break
      }
      if picked_idx < 0 {
        return instr
      }
      let info = match picked_info {
        Some(i) => i
        None => return instr
      }
      let local_type = match local_types.get(picked_idx) {
        Some(vt) => vt
        None => return instr
      }
      let body_instrs = body.0.copy()
      if body_instrs.is_empty() ||
        body_instrs[body_instrs.length() - 1] != TInstr::nop() {
        body_instrs.push(TInstr::nop())
      }
      body_instrs[body_instrs.length() - 1] = info.value
      if info.out_index >= 0 && info.out_index < out.length() {
        out[info.out_index] = TInstr::nop()
      }
      sinkables.clear()
      changed.val = true
      TInstr::local_set(
        sl_localidx_from_int(picked_idx),
        TInstr::loop_(BlockType::val_type(local_type), TExpr::new(body_instrs)),
      )
    }
    _ => instr
  }
}

///|
fn sl_try_structure_if(
  instr : TInstr,
  local_types : Array[ValType],
  options : SLSimplifyOptions,
  changed : Ref[Bool],
) -> TInstr {
  if !options.allow_structure {
    return instr
  }
  match instr {
    TIf(VoidBlockType, cond, then_body, else_body) =>
      match else_body {
        Some(other) => {
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
                    changed.val = true
                    TInstr::local_set(
                      then_idx,
                      TInstr::if_(
                        BlockType::val_type(local_type),
                        cond,
                        TExpr::new(next_then),
                        Some(TExpr::new(next_else)),
                      ),
                    )
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
              let idx_i = sl_localidx_to_int(then_idx)
              match local_types.get(idx_i) {
                Some(local_type) =>
                  if sl_is_defaultable(local_type) {
                    let next_then = then_prefix.copy()
                    next_then.push(then_value)
                    changed.val = true
                    TInstr::local_set(
                      then_idx,
                      TInstr::if_(
                        BlockType::val_type(local_type),
                        cond,
                        TExpr::new(next_then),
                        Some(TExpr::new([TInstr::local_get(then_idx)])),
                      ),
                    )
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
  sinkables : Map[Int, SLSinkableInfo],
  out : Array[TInstr],
  local_types : Array[ValType],
  get_counts : Array[Int],
  options : SLSimplifyOptions,
  parent_is_set_value : Bool,
  changed : Ref[Bool],
) -> TInstr {
  match instr {
    TLocalGet(idx) =>
      sl_try_sink_local_get(
        idx, sinkables, out, get_counts, options, parent_is_set_value, changed,
      )
    TBlock(bt, body) => {
      let (next_body, body_changed) = sl_simplify_texpr_main(
        body, local_types, get_counts, options,
      )
      if body_changed {
        changed.val = true
      }
      sl_try_structure_block(
        TInstr::block(bt, next_body),
        local_types,
        options,
        changed,
      )
    }
    TLoop(bt, body) => {
      let (next_body, body_changed) = sl_simplify_texpr_main(
        body, local_types, get_counts, options,
      )
      if body_changed {
        changed.val = true
      }
      TInstr::loop_(bt, next_body)
    }
    TTryTable(bt, catches, body) => {
      let (next_body, body_changed) = sl_simplify_texpr_main(
        body, local_types, get_counts, options,
      )
      if body_changed {
        changed.val = true
      }
      TInstr::try_table(bt, catches, next_body)
    }
    TIf(bt, cond, then_body, else_body) => {
      let next_cond = sl_rewrite_instr_main(
        cond, sinkables, out, local_types, get_counts, options, false, changed,
      )
      let (next_then, then_changed) = sl_simplify_texpr_main(
        then_body, local_types, get_counts, options,
      )
      let mut branch_changed = then_changed
      let next_else = match else_body {
        Some(other) => {
          let (rewritten, else_changed) = sl_simplify_texpr_main(
            other, local_types, get_counts, options,
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
      sl_try_structure_if(rebuilt, local_types, options, changed)
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
        let child_parent_is_set = match instr {
          TLocalSet(_, _) | TLocalTee(_, _) => i == 0
          _ => false
        }
        let next_child = sl_rewrite_instr_main(
          child, sinkables, out, local_types, get_counts, options, child_parent_is_set,
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
  local_types : Array[ValType],
  get_counts : Array[Int],
  options : SLSimplifyOptions,
) -> (TExpr, Bool) {
  let out : Array[TInstr] = []
  let sinkables : Map[Int, SLSinkableInfo] = Map::new()
  let changed = Ref::new(false)

  for instr in expr.0 {
    let rewritten = sl_rewrite_instr_main(
      instr, sinkables, out, local_types, get_counts, options, false, changed,
    )
    let curr = match rewritten {
      TDrop(TLocalTee(idx, value)) => {
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
    match curr {
      TLocalSet(idx, value) => {
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
              effects: lcs_collect_effects(curr),
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
  match instr {
    TLocalSet(idx, value) => {
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
    TLocalTee(idx, value) => {
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
    TBlock(bt, body) => {
      let next_body = sl_remove_unneeded_sets_texpr(body, get_counts, changed)
      if next_body != body {
        changed.val = true
        TInstr::block(bt, next_body)
      } else {
        instr
      }
    }
    TLoop(bt, body) => {
      let next_body = sl_remove_unneeded_sets_texpr(body, get_counts, changed)
      if next_body != body {
        changed.val = true
        TInstr::loop_(bt, next_body)
      } else {
        instr
      }
    }
    TTryTable(bt, catches, body) => {
      let next_body = sl_remove_unneeded_sets_texpr(body, get_counts, changed)
      if next_body != body {
        changed.val = true
        TInstr::try_table(bt, catches, next_body)
      } else {
        instr
      }
    }
    TIf(bt, cond, then_body, else_body) => {
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
  for instr in expr.0 {
    out.push(sl_remove_unneeded_sets_instr(instr, get_counts, changed))
  }
  TExpr::new(out)
}

///|
fn sl_strip_nops_instr(instr : TInstr, changed : Ref[Bool]) -> TInstr {
  match instr {
    TBlock(bt, body) => {
      let next_body = sl_strip_nops_texpr(body, changed)
      if next_body != body {
        changed.val = true
        TInstr::block(bt, next_body)
      } else {
        instr
      }
    }
    TLoop(bt, body) => {
      let next_body = sl_strip_nops_texpr(body, changed)
      if next_body != body {
        changed.val = true
        TInstr::loop_(bt, next_body)
      } else {
        instr
      }
    }
    TTryTable(bt, catches, body) => {
      let next_body = sl_strip_nops_texpr(body, changed)
      if next_body != body {
        changed.val = true
        TInstr::try_table(bt, catches, next_body)
      } else {
        instr
      }
    }
    TIf(bt, cond, then_body, else_body) => {
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
  for instr in expr.0 {
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
  equivs : Array[Set[Int]]
  get_counts : Array[Int]
  remove_equivalent_sets : Bool
  changed : Ref[Bool]
}

///|
fn sl_late_state_new(
  local_count : Int,
  get_counts : Array[Int],
  remove_equivalent_sets : Bool,
  changed : Ref[Bool],
) -> SLLateState {
  let equivs : Array[Set[Int]] = []
  for i = 0; i < local_count; i = i + 1 {
    let set : Set[Int] = Set::new()
    set.add(i)
    equivs.push(set)
  }
  { equivs, get_counts, remove_equivalent_sets, changed }
}

///|
fn sl_late_clear(state : SLLateState) -> Unit {
  for i = 0; i < state.equivs.length(); i = i + 1 {
    let set : Set[Int] = Set::new()
    set.add(i)
    state.equivs[i] = set
  }
}

///|
fn sl_late_is_equivalent(state : SLLateState, a : Int, b : Int) -> Bool {
  if a == b {
    return true
  }
  if a < 0 || b < 0 || a >= state.equivs.length() || b >= state.equivs.length() {
    return false
  }
  state.equivs[a].contains(b)
}

///|
fn sl_late_reset_local(state : SLLateState, idx : Int) -> Unit {
  if idx < 0 || idx >= state.equivs.length() {
    return
  }
  for i = 0; i < state.equivs.length(); i = i + 1 {
    if i != idx {
      state.equivs[i].remove(idx)
    }
  }
  let own : Set[Int] = Set::new()
  own.add(idx)
  state.equivs[idx] = own
}

///|
fn sl_late_add_equivalence(state : SLLateState, a : Int, b : Int) -> Unit {
  if a < 0 || b < 0 || a >= state.equivs.length() || b >= state.equivs.length() {
    return
  }
  let merged = state.equivs[a].copy()
  for idx in state.equivs[b] {
    merged.add(idx)
  }
  for idx in merged {
    state.equivs[idx] = merged.copy()
  }
}

///|
fn sl_get_fallthrough(instr : TInstr) -> TInstr {
  match instr {
    TBlock(_, TExpr(instrs)) if instrs.length() > 0 =>
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
  match instr {
    TLocalSet(idx, value) => {
      let next_value = sl_late_rewrite_instr(value, state)
      let idx_i = sl_localidx_to_int(idx)
      match sl_get_fallthrough(next_value) {
        TLocalGet(src_idx) => {
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
    TLocalTee(idx, value) => {
      let next_value = sl_late_rewrite_instr(value, state)
      let idx_i = sl_localidx_to_int(idx)
      match sl_get_fallthrough(next_value) {
        TLocalGet(src_idx) => {
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
    TLocalGet(idx) => {
      let idx_i = sl_localidx_to_int(idx)
      if idx_i < 0 || idx_i >= state.equivs.length() {
        return instr
      }
      let mut best = idx_i
      for candidate in state.equivs[idx_i] {
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
    TBlock(bt, body) => {
      let child = sl_late_state_new(
        state.equivs.length(),
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
    TLoop(bt, body) => {
      let child = sl_late_state_new(
        state.equivs.length(),
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
    TTryTable(bt, catches, body) => {
      let child = sl_late_state_new(
        state.equivs.length(),
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
    TIf(bt, cond, then_body, else_body) => {
      let next_cond = sl_late_rewrite_instr(cond, state)
      let then_state = sl_late_state_new(
        state.equivs.length(),
        state.get_counts,
        state.remove_equivalent_sets,
        state.changed,
      )
      let next_then = sl_late_rewrite_texpr(then_body, then_state)
      let next_else = else_body.map(fn(other) {
        let else_state = sl_late_state_new(
          state.equivs.length(),
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
  for instr in body.0 {
    let next = sl_late_rewrite_instr(instr, state)
    out.push(next)
    if lcs_is_non_linear_boundary(next) || is_unreachable_instr(next) {
      sl_late_clear(state)
    }
  }
  TExpr::new(out)
}

///|
fn sl_run_late_optimizations(
  body : TExpr,
  local_count : Int,
  remove_equivalent_sets : Bool,
) -> (TExpr, Bool) {
  // The no-structure mode does not rely on equivalent-set removal.
  // Skip expensive equivalence tracking on very large local sets.
  if !remove_equivalent_sets && local_count > 128 {
    return (body, false)
  }
  let get_counts = Array::make(local_count, 0)
  sl_collect_get_counts_texpr(body, get_counts)
  let changed = Ref::new(false)
  let state = sl_late_state_new(
    local_count, get_counts, remove_equivalent_sets, changed,
  )
  let next = sl_late_rewrite_texpr(body, state)
  (next, changed.val)
}

///|
fn sl_simplify_function(
  func : Func,
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
      let mut first_cycle = true
      let mut cycles = 0
      while cycles < 12 {
        let get_counts = Array::make(local_types.length(), 0)
        sl_collect_get_counts_texpr(body, get_counts)
        let cycle_options = {
          allow_tee: options.allow_tee && !first_cycle,
          allow_structure: options.allow_structure,
          allow_nesting: options.allow_nesting,
        }
        let (after_main, changed_main) = sl_simplify_texpr_main(
          body, local_types, get_counts, cycle_options,
        )

        let after_counts = Array::make(local_types.length(), 0)
        sl_collect_get_counts_texpr(after_main, after_counts)
        let removed_changed = Ref::new(false)
        let after_removed = sl_remove_unneeded_sets_texpr(
          after_main, after_counts, removed_changed,
        )
        let strip_changed = Ref::new(false)
        let after_strip = sl_strip_nops_texpr(after_removed, strip_changed)

        let mut cycle_changed = changed_main ||
          removed_changed.val ||
          strip_changed.val
        let (after_late, late_changed) = sl_run_late_optimizations(
          after_strip,
          local_types.length(),
          options.allow_structure,
        )
        if late_changed {
          cycle_changed = true
          body = after_late
        } else {
          body = after_strip
        }
        if cycle_changed {
          changed_any = true
        }

        if first_cycle {
          first_cycle = false
          cycles += 1
          continue
        }
        if !cycle_changed {
          break
        }
        cycles += 1
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
) -> ModuleTransformer[IRContext] {
  let options = { allow_tee, allow_structure, allow_nesting }
  let param_types = sl_collect_param_types(mod)
  let next_def_idx = Ref::new(0)
  ModuleTransformer::new().on_func_evt(fn(_, ctx, func) {
    let def_idx = next_def_idx.val
    next_def_idx.update(fn(i) { i + 1 })
    let params = param_types.get(def_idx).unwrap_or([])
    let (next_func, changed) = sl_simplify_function(func, params, options)
    if changed {
      change(ctx, next_func)
    } else {
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
) -> Module {
  let pass = simplify_locals_ir_pass(
    mod, allow_tee, allow_structure, allow_nesting,
  )
  match pass.walk_module(IRContext::new(), mod) {
    Ok(Some((_, out))) => out
    Ok(None) => mod
    Err(e) => abort("simplify_locals pass failed: \{e}")
  }
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
      match body.0 {
        [TDrop(TI32Const(I32(v)))] => assert_eq(v, 7)
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
    [ValType::i32(), ValType::i32()],
    { allow_tee: false, allow_structure: true, allow_nesting: true },
    changed,
  )
  assert_true(changed.val)
  match out {
    TLocalSet(_, TBlock(_, body)) =>
      assert_true(sl_has_br_if_with_tee_value_texpr(body, 0))
    _ =>
      fail("expected local.set(block(...)) after direct conditional coalescing")
  }
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
  sl_collect_block_exit_candidates_texpr(body, 0, st)
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
  sl_collect_block_exit_candidates_texpr(body, 0, st)
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
    [ValType::i32(), ValType::i32()],
    { allow_tee: false, allow_structure: true, allow_nesting: true },
    changed,
  )
  assert_true(changed.val)
  match out {
    TLocalSet(_, TBlock(ValTypeBlockType(_), _)) => ()
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
  let (next_func, changed) = sl_simplify_function(func, [], {
    allow_tee: false,
    allow_structure: true,
    allow_nesting: true,
  })
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
    sinkables,
    out,
    [ValType::i32(), ValType::i32()],
    [2, 1],
    { allow_tee: false, allow_structure: true, allow_nesting: true },
    false,
    changed,
  )
  assert_true(changed.val)
  match next {
    TLocalSet(_, TBlock(ValTypeBlockType(_), _)) => ()
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
      if !sl_has_result_loop_texpr(body) {
        let stats = SLLocalStats::new()
        sl_collect_local_stats_texpr(body, stats)
        fail(
          "expected result loop; sets=\{stats.sets}, tees=\{stats.tees}, gets=\{stats.gets}",
        )
      }
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
  let (with_removal, changed_with) = sl_run_late_optimizations(body, 2, true)
  let (no_removal, changed_without) = sl_run_late_optimizations(body, 2, false)
  assert_true(changed_with)
  ignore(changed_without)
  let with_count = sl_count_local_sets_for_idx_texpr(with_removal, 1)
  let without_count = sl_count_local_sets_for_idx_texpr(no_removal, 1)
  assert_true(with_count < without_count)
}
