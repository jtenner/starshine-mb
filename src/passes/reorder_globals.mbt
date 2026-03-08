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
fn rg_trace_noop(_ : String) -> Unit {
  ()
}

///|
const RG_TRACE_PROGRESS_INTERVAL : Int = 50000

///|
const RG_TRACE_HEARTBEAT_MS : UInt64 = 1000UL

///|
const RG_TRACE_SLOW_WALK_MS : UInt64 = 50UL

///|
const RG_TRACE_HEARTBEAT_CHECK_INTERVAL : Int = 8192

///|
fn rg_trace_normalize_env_now_ms(raw : UInt64) -> UInt64 {
  if raw >= 100000000000000000UL {
    raw / 1000000UL
  } else if raw >= 100000000000000UL {
    raw / 1000UL
  } else {
    raw
  }
}

///|
fn rg_trace_now_ms() -> UInt64 {
  rg_trace_normalize_env_now_ms(@env.now())
}

///|
fn rg_trace_elapsed_ms(start_ms : UInt64) -> UInt64 {
  let end_ms = rg_trace_now_ms()
  if end_ms >= start_ms {
    end_ms - start_ms
  } else {
    0UL
  }
}

///|
fn rg_trace_should_log_func(ordinal : Int, trace_all_funcs : Bool) -> Bool {
  trace_all_funcs || ordinal <= 5 || ordinal % 500 == 0
}

///|
priv struct RGLegacyScanSummary {
  visited : Int
  global_gets : Int
  global_sets : Int
  walk_ms : UInt64
  slow_walks : Int
  max_walk_ms : UInt64
}

///|
fn rg_scan_legacy_func_for_globals(
  body : Expr,
  imported_globals : Int,
  counts : Array[Double],
  trace : (String) -> Unit,
  ordinal : Int,
  log_func : Bool,
) -> RGLegacyScanSummary {
  let Expr(root_instrs) = body
  let stack_instrs : Array[Array[Instruction]] = [root_instrs]
  let stack_next_idx : Array[Int] = [0]
  let scan_start_ms = if log_func { rg_trace_now_ms() } else { 0UL }
  let mut last_progress_ms = scan_start_ms
  let mut next_progress_at = RG_TRACE_PROGRESS_INTERVAL
  let mut visited = 0
  let mut global_gets = 0
  let mut global_sets = 0
  while !stack_instrs.is_empty() {
    let top = stack_instrs.length() - 1
    let curr_instrs = stack_instrs[top]
    let curr_idx = stack_next_idx[top]
    if curr_idx >= curr_instrs.length() {
      ignore(stack_instrs.pop())
      ignore(stack_next_idx.pop())
      continue
    }
    stack_next_idx[top] = curr_idx + 1
    visited += 1
    let instr = curr_instrs[curr_idx]
    match instr {
      GlobalGet(idx) => {
        global_gets += 1
        rg_bump_count(counts, imported_globals, idx)
      }
      GlobalSet(idx) => {
        global_sets += 1
        rg_bump_count(counts, imported_globals, idx)
      }
      Block(_, Expr(items))
      | Loop(_, Expr(items))
      | TryTable(_, _, Expr(items)) => {
        stack_instrs.push(items)
        stack_next_idx.push(0)
      }
      If(_, then_items, else_items) => {
        match else_items {
          Some(other) => {
            stack_instrs.push(other)
            stack_next_idx.push(0)
          }
          None => ()
        }
        stack_instrs.push(then_items)
        stack_next_idx.push(0)
      }
      _ => ()
    }
    if log_func && visited >= next_progress_at {
      let elapsed_ms = rg_trace_elapsed_ms(scan_start_ms)
      trace(
        "phase=collect_use_counts func[\{ordinal}] event=legacy_scan progress elapsed_ms=\{elapsed_ms} visited=\{visited} global_gets=\{global_gets} global_sets=\{global_sets}",
      )
      next_progress_at += RG_TRACE_PROGRESS_INTERVAL
      last_progress_ms = rg_trace_now_ms()
    } else if log_func &&
      visited % RG_TRACE_HEARTBEAT_CHECK_INTERVAL == 0 &&
      rg_trace_elapsed_ms(last_progress_ms) >= RG_TRACE_HEARTBEAT_MS {
      trace(
        "phase=collect_use_counts func[\{ordinal}] event=legacy_scan heartbeat elapsed_ms=\{rg_trace_elapsed_ms(scan_start_ms)} visited=\{visited} global_gets=\{global_gets} global_sets=\{global_sets}",
      )
      last_progress_ms = rg_trace_now_ms()
    }
  }
  let elapsed_ms = if log_func {
    rg_trace_elapsed_ms(scan_start_ms)
  } else {
    0UL
  }
  {
    visited,
    global_gets,
    global_sets,
    walk_ms: elapsed_ms,
    slow_walks: 0,
    max_walk_ms: elapsed_ms,
  }
}

///|
fn rg_scan_typed_func_for_globals(
  body : TExpr,
  imported_globals : Int,
  counts : Array[Double],
  trace : (String) -> Unit,
  ordinal : Int,
  log_func : Bool,
) -> RGLegacyScanSummary {
  let stack_instrs : Array[Array[TInstr]] = [body.instrs]
  let stack_next_idx : Array[Int] = [0]
  let scan_start_ms = if log_func { rg_trace_now_ms() } else { 0UL }
  let mut last_progress_ms = scan_start_ms
  let mut next_progress_at = RG_TRACE_PROGRESS_INTERVAL
  let mut visited = 0
  let mut global_gets = 0
  let mut global_sets = 0
  while !stack_instrs.is_empty() {
    let top = stack_instrs.length() - 1
    let curr_instrs = stack_instrs[top]
    let curr_idx = stack_next_idx[top]
    if curr_idx >= curr_instrs.length() {
      ignore(stack_instrs.pop())
      ignore(stack_next_idx.pop())
      continue
    }
    stack_next_idx[top] = curr_idx + 1
    visited += 1
    let instr = curr_instrs[curr_idx]
    match instr.kind {
      TInstrKind::TGlobalGet(idx) => {
        global_gets += 1
        rg_bump_count(counts, imported_globals, idx)
      }
      TInstrKind::TGlobalSet(idx, _) => {
        global_sets += 1
        rg_bump_count(counts, imported_globals, idx)
      }
      TInstrKind::TBlock(_, body)
      | TInstrKind::TLoop(_, body)
      | TInstrKind::TTryTable(_, _, body) => {
        stack_instrs.push(body.instrs)
        stack_next_idx.push(0)
      }
      TInstrKind::TIf(_, cond, then_body, else_body) => {
        match else_body {
          Some(other) => {
            stack_instrs.push(other.instrs)
            stack_next_idx.push(0)
          }
          None => ()
        }
        stack_instrs.push(then_body.instrs)
        stack_next_idx.push(0)
        stack_instrs.push([cond])
        stack_next_idx.push(0)
      }
      _ => {
        let children = eval_children(instr)
        if !children.is_empty() {
          stack_instrs.push(children)
          stack_next_idx.push(0)
        }
      }
    }
    if log_func && visited >= next_progress_at {
      let elapsed_ms = rg_trace_elapsed_ms(scan_start_ms)
      trace(
        "phase=collect_use_counts func[\{ordinal}] event=typed_scan progress elapsed_ms=\{elapsed_ms} visited=\{visited} global_gets=\{global_gets} global_sets=\{global_sets}",
      )
      next_progress_at += RG_TRACE_PROGRESS_INTERVAL
      last_progress_ms = rg_trace_now_ms()
    } else if log_func &&
      visited % RG_TRACE_HEARTBEAT_CHECK_INTERVAL == 0 &&
      rg_trace_elapsed_ms(last_progress_ms) >= RG_TRACE_HEARTBEAT_MS {
      trace(
        "phase=collect_use_counts func[\{ordinal}] event=typed_scan heartbeat elapsed_ms=\{rg_trace_elapsed_ms(scan_start_ms)} visited=\{visited} global_gets=\{global_gets} global_sets=\{global_sets}",
      )
      last_progress_ms = rg_trace_now_ms()
    }
  }
  let elapsed_ms = if log_func {
    rg_trace_elapsed_ms(scan_start_ms)
  } else {
    0UL
  }
  {
    visited,
    global_gets,
    global_sets,
    walk_ms: elapsed_ms,
    slow_walks: 0,
    max_walk_ms: elapsed_ms,
  }
}

///|
fn rg_count_imported_globals(mod : Module) -> Int {
  let mut n = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, GlobalExternType(_)) => n += 1
          _ => ()
        }
      }
    None => ()
  }
  n
}

///|
fn rg_globalidx_to_int(idx : GlobalIdx) -> Int {
  let GlobalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn rg_globalidx_from_int(idx : Int) -> GlobalIdx {
  GlobalIdx::new(idx.reinterpret_as_uint())
}

///|
fn rg_defined_index(
  imported_globals : Int,
  defined_count : Int,
  idx : GlobalIdx,
) -> Int? {
  let abs = rg_globalidx_to_int(idx)
  let def = abs - imported_globals
  if def >= 0 && def < defined_count {
    Some(def)
  } else {
    None
  }
}

///|
fn rg_bump_count(
  counts : Array[Double],
  imported_globals : Int,
  idx : GlobalIdx,
) -> Unit {
  match rg_defined_index(imported_globals, counts.length(), idx) {
    Some(def_idx) => counts[def_idx] = counts[def_idx] + 1.0
    None => ()
  }
}

///|
fn rg_collect_use_counts(
  mod : Module,
  imported_globals : Int,
  defined_count : Int,
  trace? : (String) -> Unit = rg_trace_noop,
  trace_all_funcs? : Bool = false,
) -> Result[Array[Double], String] {
  let counts = Array::make(defined_count, 0.0)
  let mut func_ordinal = 0
  let active_func_ordinal = 0
  let func_log_enabled : Array[Bool] = []
  let func_is_typed : Array[Bool] = []
  let func_top_instrs : Array[Int] = []
  let func_locals : Array[Int] = []
  let func_start_ms : Array[UInt64] = []
  let func_last_progress_ms : Array[UInt64] = []
  let func_next_progress_at : Array[Int] = []
  let func_tinstr_visited : Array[Int] = []
  let func_instr_visited : Array[Int] = []
  let func_global_gets : Array[Int] = []
  let func_global_sets : Array[Int] = []
  let func_walk_ms : Array[UInt64] = []
  let func_slow_walks : Array[Int] = []
  let func_max_walk_ms : Array[UInt64] = []

  let rg_trace_collect_progress = fn(event_kind : String) {
    if active_func_ordinal <= 0 ||
      active_func_ordinal > func_log_enabled.length() {
      return
    }
    let slot = active_func_ordinal - 1
    if !func_log_enabled[slot] {
      return
    }
    let visited = func_tinstr_visited[slot] + func_instr_visited[slot]
    let mut should_emit = false
    if visited >= func_next_progress_at[slot] {
      should_emit = true
      func_next_progress_at[slot] = func_next_progress_at[slot] +
        RG_TRACE_PROGRESS_INTERVAL
    }
    let heartbeat_ms = rg_trace_elapsed_ms(func_last_progress_ms[slot])
    if heartbeat_ms >= RG_TRACE_HEARTBEAT_MS {
      should_emit = true
    }
    if !should_emit {
      return
    }
    trace(
      "phase=collect_use_counts func[\{active_func_ordinal}] event=\{event_kind} progress elapsed_ms=\{rg_trace_elapsed_ms(func_start_ms[slot])} heartbeat_ms=\{heartbeat_ms} visited=\{visited} tinstr_visited=\{func_tinstr_visited[slot]} instr_visited=\{func_instr_visited[slot]} global_gets=\{func_global_gets[slot]} global_sets=\{func_global_sets[slot]} walk_ms=\{func_walk_ms[slot]} slow_walks=\{func_slow_walks[slot]}",
    )
    func_last_progress_ms[slot] = rg_trace_now_ms()
  }

  let walker = ModuleTransformer::new()
    .on_tinstruction_evt(fn(self, _, instr) {
      if active_func_ordinal > 0 &&
        active_func_ordinal <= func_tinstr_visited.length() {
        let slot = active_func_ordinal - 1
        func_tinstr_visited[slot] = func_tinstr_visited[slot] + 1
      }
      rg_trace_collect_progress("tinstr")
      match instr.kind {
        TInstrKind::TGlobalGet(idx) => {
          if active_func_ordinal > 0 &&
            active_func_ordinal <= func_global_gets.length() {
            let slot = active_func_ordinal - 1
            func_global_gets[slot] = func_global_gets[slot] + 1
          }
          rg_bump_count(counts, imported_globals, idx)
        }
        TInstrKind::TGlobalSet(idx, _) => {
          if active_func_ordinal > 0 &&
            active_func_ordinal <= func_global_sets.length() {
            let slot = active_func_ordinal - 1
            func_global_sets[slot] = func_global_sets[slot] + 1
          }
          rg_bump_count(counts, imported_globals, idx)
        }
        _ => ()
      }
      let should_time_walk = active_func_ordinal > 0 &&
        active_func_ordinal <= func_log_enabled.length() &&
        func_log_enabled[active_func_ordinal - 1]
      let walk_start_ms = if should_time_walk { rg_trace_now_ms() } else { 0UL }
      let walked = self.walk_tinstruction_default((), instr)
      if should_time_walk {
        let slot = active_func_ordinal - 1
        let walk_elapsed_ms = rg_trace_elapsed_ms(walk_start_ms)
        func_walk_ms[slot] = func_walk_ms[slot] + walk_elapsed_ms
        if walk_elapsed_ms > func_max_walk_ms[slot] {
          func_max_walk_ms[slot] = walk_elapsed_ms
        }
        if walk_elapsed_ms >= RG_TRACE_SLOW_WALK_MS {
          func_slow_walks[slot] = func_slow_walks[slot] + 1
          trace(
            "phase=collect_use_counts func[\{active_func_ordinal}] event=tinstr slow_walk elapsed_ms=\{walk_elapsed_ms} total_elapsed_ms=\{rg_trace_elapsed_ms(func_start_ms[slot])} visited=\{func_tinstr_visited[slot] + func_instr_visited[slot]}",
          )
        }
      }
      walked
    })
    .on_instruction_evt(fn(self, _, instr) {
      if active_func_ordinal > 0 &&
        active_func_ordinal <= func_instr_visited.length() {
        let slot = active_func_ordinal - 1
        func_instr_visited[slot] = func_instr_visited[slot] + 1
      }
      rg_trace_collect_progress("instr")
      match instr {
        GlobalGet(idx) => {
          if active_func_ordinal > 0 &&
            active_func_ordinal <= func_global_gets.length() {
            let slot = active_func_ordinal - 1
            func_global_gets[slot] = func_global_gets[slot] + 1
          }
          rg_bump_count(counts, imported_globals, idx)
        }
        GlobalSet(idx) => {
          if active_func_ordinal > 0 &&
            active_func_ordinal <= func_global_sets.length() {
            let slot = active_func_ordinal - 1
            func_global_sets[slot] = func_global_sets[slot] + 1
          }
          rg_bump_count(counts, imported_globals, idx)
        }
        _ => ()
      }
      let should_time_walk = active_func_ordinal > 0 &&
        active_func_ordinal <= func_log_enabled.length() &&
        func_log_enabled[active_func_ordinal - 1]
      let walk_start_ms = if should_time_walk { rg_trace_now_ms() } else { 0UL }
      let walked = self.walk_instruction_default((), instr)
      if should_time_walk {
        let slot = active_func_ordinal - 1
        let walk_elapsed_ms = rg_trace_elapsed_ms(walk_start_ms)
        func_walk_ms[slot] = func_walk_ms[slot] + walk_elapsed_ms
        if walk_elapsed_ms > func_max_walk_ms[slot] {
          func_max_walk_ms[slot] = walk_elapsed_ms
        }
        if walk_elapsed_ms >= RG_TRACE_SLOW_WALK_MS {
          func_slow_walks[slot] = func_slow_walks[slot] + 1
          trace(
            "phase=collect_use_counts func[\{active_func_ordinal}] event=instr slow_walk elapsed_ms=\{walk_elapsed_ms} total_elapsed_ms=\{rg_trace_elapsed_ms(func_start_ms[slot])} visited=\{func_tinstr_visited[slot] + func_instr_visited[slot]}",
          )
        }
      }
      walked
    })
    .on_func_evt(fn(_, _, func) {
      func_ordinal += 1
      let ordinal = func_ordinal
      let log_func = rg_trace_should_log_func(ordinal, trace_all_funcs)
      func_log_enabled.push(log_func)
      func_is_typed.push(false)
      func_top_instrs.push(0)
      func_locals.push(0)
      func_start_ms.push(0UL)
      func_last_progress_ms.push(0UL)
      func_next_progress_at.push(RG_TRACE_PROGRESS_INTERVAL)
      func_tinstr_visited.push(0)
      func_instr_visited.push(0)
      func_global_gets.push(0)
      func_global_sets.push(0)
      func_walk_ms.push(0UL)
      func_slow_walks.push(0)
      func_max_walk_ms.push(0UL)
      let slot = ordinal - 1
      match func {
        TFunc(_, locals, body) => {
          func_is_typed[slot] = true
          func_top_instrs[slot] = body.instrs.length()
          func_locals[slot] = locals.length()
        }
        Func(_, Expr(instrs)) => func_top_instrs[slot] = instrs.length()
      }
      if log_func {
        func_start_ms[slot] = rg_trace_now_ms()
        func_last_progress_ms[slot] = func_start_ms[slot]
        if func_is_typed[slot] {
          trace(
            "phase=collect_use_counts func[\{ordinal}] start kind=typed top_instrs=\{func_top_instrs[slot]} locals=\{func_locals[slot]}",
          )
        } else {
          trace(
            "phase=collect_use_counts func[\{ordinal}] start kind=legacy top_instrs=\{func_top_instrs[slot]}",
          )
        }
      }
      match func {
        TFunc(_, _, body) => {
          let summary = rg_scan_typed_func_for_globals(
            body, imported_globals, counts, trace, ordinal, log_func,
          )
          func_tinstr_visited[slot] = summary.visited
          func_global_gets[slot] = summary.global_gets
          func_global_sets[slot] = summary.global_sets
          func_walk_ms[slot] = summary.walk_ms
          func_slow_walks[slot] = summary.slow_walks
          func_max_walk_ms[slot] = summary.max_walk_ms
          if log_func {
            trace(
              "phase=collect_use_counts func[\{ordinal}] done elapsed_ms=\{rg_trace_elapsed_ms(func_start_ms[slot])} tinstr_visited=\{func_tinstr_visited[slot]} instr_visited=\{func_instr_visited[slot]} global_gets=\{func_global_gets[slot]} global_sets=\{func_global_sets[slot]} walk_ms=\{func_walk_ms[slot]} slow_walks=\{func_slow_walks[slot]} max_walk_ms=\{func_max_walk_ms[slot]} mode=typed_scan",
            )
          }
        }
        Func(_, body) => {
          let summary = rg_scan_legacy_func_for_globals(
            body, imported_globals, counts, trace, ordinal, log_func,
          )
          func_instr_visited[slot] = summary.visited
          func_global_gets[slot] = summary.global_gets
          func_global_sets[slot] = summary.global_sets
          func_walk_ms[slot] = summary.walk_ms
          func_slow_walks[slot] = summary.slow_walks
          func_max_walk_ms[slot] = summary.max_walk_ms
          if log_func {
            trace(
              "phase=collect_use_counts func[\{ordinal}] done elapsed_ms=\{rg_trace_elapsed_ms(func_start_ms[slot])} tinstr_visited=\{func_tinstr_visited[slot]} instr_visited=\{func_instr_visited[slot]} global_gets=\{func_global_gets[slot]} global_sets=\{func_global_sets[slot]} walk_ms=\{func_walk_ms[slot]} slow_walks=\{func_slow_walks[slot]} max_walk_ms=\{func_max_walk_ms[slot]} mode=legacy_scan",
            )
          }
        }
      }
      change((), func)
    })
  match walker.walk_module((), mod) {
    Ok(_) => Ok(counts)
    Err(e) => Err(e)
  }
}

///|
fn rg_collect_dependencies(
  globals : Array[Global],
  imported_globals : Int,
  trace? : (String) -> Unit = rg_trace_noop,
  trace_all_funcs? : Bool = false,
) -> Result[Array[Array[Int]], String] {
  let dep_sets : Array[Set[Int]] = []
  for _ in globals {
    dep_sets.push(Set::new())
  }
  for i = 0; i < globals.length(); i = i + 1 {
    let Global(_, init) = globals[i]
    let log_global = rg_trace_should_log_func(i + 1, trace_all_funcs)
    let global_start_ms = if log_global { rg_trace_now_ms() } else { 0UL }
    let mut visited = 0
    let mut get_edges = 0
    let mut walk_ms = 0UL
    let mut slow_walks = 0
    let mut max_walk_ms = 0UL
    if log_global {
      let Expr(init_instrs) = init
      trace(
        "phase=collect_dependencies global[\{i}] start init_instrs=\{init_instrs.length()}",
      )
    }
    let walker = ModuleTransformer::new().on_instruction_evt(fn(
      self,
      _,
      instr,
    ) {
      visited += 1
      match instr {
        GlobalGet(idx) =>
          match rg_defined_index(imported_globals, globals.length(), idx) {
            Some(dep_idx) => {
              dep_sets[dep_idx].add(i)
              get_edges += 1
            }
            None => ()
          }
        _ => ()
      }
      let walk_start_ms = if log_global { rg_trace_now_ms() } else { 0UL }
      let walked = self.walk_instruction_default((), instr)
      if log_global {
        let walk_elapsed_ms = rg_trace_elapsed_ms(walk_start_ms)
        walk_ms = walk_ms + walk_elapsed_ms
        if walk_elapsed_ms > max_walk_ms {
          max_walk_ms = walk_elapsed_ms
        }
        if walk_elapsed_ms >= RG_TRACE_SLOW_WALK_MS {
          slow_walks += 1
          trace(
            "phase=collect_dependencies global[\{i}] event=instr slow_walk elapsed_ms=\{walk_elapsed_ms} visited=\{visited}",
          )
        }
        if visited % RG_TRACE_PROGRESS_INTERVAL == 0 {
          trace(
            "phase=collect_dependencies global[\{i}] event=instr progress elapsed_ms=\{rg_trace_elapsed_ms(global_start_ms)} visited=\{visited} get_edges=\{get_edges} walk_ms=\{walk_ms} slow_walks=\{slow_walks}",
          )
        }
      }
      walked
    })
    match walker.walk_expr((), init) {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
    if log_global {
      trace(
        "phase=collect_dependencies global[\{i}] done elapsed_ms=\{rg_trace_elapsed_ms(global_start_ms)} visited=\{visited} get_edges=\{get_edges} walk_ms=\{walk_ms} slow_walks=\{slow_walks} max_walk_ms=\{max_walk_ms}",
      )
    }
  }
  let deps : Array[Array[Int]] = []
  for dep_set in dep_sets {
    let items : Array[Int] = []
    for item in dep_set {
      items.push(item)
    }
    items.sort()
    deps.push(items)
  }
  Ok(deps)
}

///|
fn rg_topological_sort(deps : Array[Array[Int]]) -> Array[Int] {
  let n = deps.length()
  let indegree = Array::make(n, 0)
  for src = 0; src < n; src = src + 1 {
    for dst in deps[src] {
      indegree[dst] = indegree[dst] + 1
    }
  }
  let queue : Array[Int] = []
  for i = 0; i < n; i = i + 1 {
    if indegree[i] == 0 {
      queue.push(i)
    }
  }
  let out : Array[Int] = []
  let mut qi = 0
  while qi < queue.length() {
    let curr = queue[qi]
    qi = qi + 1
    out.push(curr)
    for dep in deps[curr] {
      indegree[dep] = indegree[dep] - 1
      if indegree[dep] == 0 {
        queue.push(dep)
      }
    }
  }
  if out.length() == n {
    return out
  }
  let seen = Array::make(n, false)
  for idx in out {
    seen[idx] = true
  }
  for i = 0; i < n; i = i + 1 {
    if !seen[i] {
      out.push(i)
    }
  }
  out
}

///|
fn rg_min_topological_sort(
  deps : Array[Array[Int]],
  prefer_before : (Int, Int) -> Bool,
) -> Array[Int] {
  let n = deps.length()
  let indegree = Array::make(n, 0)
  for src = 0; src < n; src = src + 1 {
    for dst in deps[src] {
      indegree[dst] = indegree[dst] + 1
    }
  }
  let emitted = Array::make(n, false)
  let available : Array[Int] = []
  for i = 0; i < n; i = i + 1 {
    if indegree[i] == 0 {
      available.push(i)
    }
  }
  let out : Array[Int] = []
  while out.length() < n {
    if available.is_empty() {
      for i = 0; i < n; i = i + 1 {
        if !emitted[i] {
          available.push(i)
          break
        }
      }
    }
    let mut best_pos = 0
    let mut best = available[0]
    for pos = 1; pos < available.length(); pos = pos + 1 {
      let candidate = available[pos]
      if prefer_before(candidate, best) {
        best = candidate
        best_pos = pos
      }
    }
    let last = available.pop().unwrap()
    if best_pos < available.length() {
      available[best_pos] = last
    }
    if emitted[best] {
      continue
    }
    emitted[best] = true
    out.push(best)
    for dep in deps[best] {
      indegree[dep] = indegree[dep] - 1
      if indegree[dep] == 0 && !emitted[dep] {
        available.push(dep)
      }
    }
  }
  out
}

///|
fn rg_do_sort(counts : Array[Double], deps : Array[Array[Int]]) -> Array[Int] {
  rg_min_topological_sort(deps, fn(a, b) {
    let ca = counts[a]
    let cb = counts[b]
    if ca != cb {
      ca > cb
    } else {
      a < b
    }
  })
}

///|
fn rg_uleb_bytes(v : Int) -> Int {
  let mut bytes = 1
  let mut x = v.to_uint64()
  while x >= 128UL {
    bytes += 1
    x = x >> 7
  }
  bytes
}

///|
fn rg_compute_size(
  indices : Array[Int],
  counts : Array[Double],
  always : Bool,
) -> Double {
  if always {
    let mut total = 0.0
    for i = 0; i < indices.length(); i = i + 1 {
      total = total + counts[indices[i]] * (1.0 + i.to_double() / 128.0)
    }
    return total
  }
  let mut total = 0.0
  for i = 0; i < indices.length(); i = i + 1 {
    total = total + counts[indices[i]] * rg_uleb_bytes(i).to_double()
  }
  total
}

///|
fn rg_remap_global_indices(
  mod : Module,
  remap : Map[GlobalIdx, GlobalIdx],
) -> Result[Module, String] {
  if remap.is_empty() {
    return Ok(mod)
  }
  let pass = ModuleTransformer::new().on_globalidx_evt(fn(_, _, idx) {
    match remap.get(idx) {
      Some(next) => if next == idx { unchanged() } else { change((), next) }
      None => unchanged()
    }
  })
  match pass.walk_module((), mod) {
    Ok(Some((_, out))) => Ok(out)
    Ok(None) => Ok(mod)
    Err(e) => Err(e)
  }
}

///|
fn reorder_globals_impl(
  mod : Module,
  always : Bool,
  trace? : (String) -> Unit = rg_trace_noop,
  trace_all_funcs? : Bool = false,
) -> Result[Module, String] {
  let pass_start_ms = rg_trace_now_ms()
  let globals = match mod.global_sec {
    Some(GlobalSec(items)) => items
    None => return Ok(mod)
  }
  trace("phase=start always=\{always} globals=\{globals.length()}")
  if globals.length() <= 1 {
    trace("phase=early_exit reason=global_count<=1")
    return Ok(mod)
  }
  if globals.length() < 128 && !always {
    trace(
      "phase=early_exit reason=small_module threshold=128 globals=\{globals.length()}",
    )
    return Ok(mod)
  }
  let imported_globals = rg_count_imported_globals(mod)
  trace("phase=collect_use_counts:start imported_globals=\{imported_globals}")
  let counts_start_ms = rg_trace_now_ms()
  let counts = match
    rg_collect_use_counts(
      mod,
      imported_globals,
      globals.length(),
      trace~,
      trace_all_funcs~,
    ) {
    Ok(out) => out
    Err(e) => return Err(e)
  }
  trace(
    "phase=collect_use_counts:done elapsed_ms=\{rg_trace_elapsed_ms(counts_start_ms)}",
  )
  trace("phase=collect_dependencies:start")
  let deps_start_ms = rg_trace_now_ms()
  let deps = match
    rg_collect_dependencies(globals, imported_globals, trace~, trace_all_funcs~) {
    Ok(out) => out
    Err(e) => return Err(e)
  }
  trace(
    "phase=collect_dependencies:done elapsed_ms=\{rg_trace_elapsed_ms(deps_start_ms)}",
  )
  let options : Array[(Array[Int], Double)] = []
  let mut option_index = 0
  let add_option = fn(custom_counts : Array[Double]) {
    option_index += 1
    let option_start_ms = rg_trace_now_ms()
    let order = rg_do_sort(custom_counts, deps)
    let size = rg_compute_size(order, counts, always)
    options.push((order, size))
    trace(
      "phase=score_options option[\{option_index}] done elapsed_ms=\{rg_trace_elapsed_ms(option_start_ms)} size=\{size}",
    )
  }
  trace("phase=score_options:start")
  add_option(Array::make(globals.length(), 0.0))
  add_option(counts)
  let topo_start_ms = rg_trace_now_ms()
  let topo = rg_topological_sort(deps)
  trace(
    "phase=topological_sort:done elapsed_ms=\{rg_trace_elapsed_ms(topo_start_ms)} topo_len=\{topo.length()}",
  )
  let sum_counts = Array::make(globals.length(), 0.0)
  let exp_counts = Array::make(globals.length(), 0.0)
  let exp_factor = 0.095
  let propagate_start_ms = rg_trace_now_ms()
  for rev = topo.length() - 1; rev >= 0; rev = rev - 1 {
    let g = topo[rev]
    sum_counts[g] = counts[g]
    exp_counts[g] = counts[g]
    for dep in deps[g] {
      sum_counts[g] = sum_counts[g] + sum_counts[dep]
      exp_counts[g] = exp_counts[g] + exp_factor * exp_counts[dep]
    }
    if rev == 0 {
      break
    }
  }
  trace(
    "phase=score_option_inputs:done elapsed_ms=\{rg_trace_elapsed_ms(propagate_start_ms)}",
  )
  add_option(sum_counts)
  add_option(exp_counts)
  trace("phase=score_options:done total_options=\{options.length()}")
  if options.is_empty() {
    return Ok(mod)
  }
  let select_start_ms = rg_trace_now_ms()
  let mut best_order = options[0].0
  let mut best_size = options[0].1
  for i = 1; i < options.length(); i = i + 1 {
    let candidate = options[i]
    if candidate.1 < best_size {
      best_order = candidate.0
      best_size = candidate.1
    }
  }
  trace(
    "phase=select_best:done elapsed_ms=\{rg_trace_elapsed_ms(select_start_ms)} best_size=\{best_size}",
  )
  let mut changed = false
  for i = 0; i < best_order.length(); i = i + 1 {
    if best_order[i] != i {
      changed = true
      break
    }
  }
  if !changed {
    trace(
      "phase=done changed=false elapsed_ms=\{rg_trace_elapsed_ms(pass_start_ms)}",
    )
    return Ok(mod)
  }
  trace("phase=materialize_reorder:start")
  let materialize_start_ms = rg_trace_now_ms()
  let reordered_globals : Array[Global] = []
  let old_to_new = Array::make(globals.length(), 0)
  for new_idx = 0; new_idx < best_order.length(); new_idx = new_idx + 1 {
    let old_idx = best_order[new_idx]
    reordered_globals.push(globals[old_idx])
    old_to_new[old_idx] = new_idx
  }
  trace(
    "phase=materialize_reorder:done elapsed_ms=\{rg_trace_elapsed_ms(materialize_start_ms)}",
  )
  trace("phase=build_remap:start")
  let remap_start_ms = rg_trace_now_ms()
  let remap : Map[GlobalIdx, GlobalIdx] = Map::new()
  for i = 0; i < imported_globals; i = i + 1 {
    let idx = rg_globalidx_from_int(i)
    remap[idx] = idx
  }
  for old_idx = 0; old_idx < globals.length(); old_idx = old_idx + 1 {
    let old_abs = imported_globals + old_idx
    let new_abs = imported_globals + old_to_new[old_idx]
    remap[rg_globalidx_from_int(old_abs)] = rg_globalidx_from_int(new_abs)
  }
  trace(
    "phase=build_remap:done elapsed_ms=\{rg_trace_elapsed_ms(remap_start_ms)} remap_size=\{remap.length()}",
  )
  let reordered_mod = mod.with_global_sec(GlobalSec::new(reordered_globals))
  trace("phase=apply_remap:start")
  let apply_start_ms = rg_trace_now_ms()
  let out = rg_remap_global_indices(reordered_mod, remap)
  match out {
    Ok(next) => {
      trace(
        "phase=apply_remap:done elapsed_ms=\{rg_trace_elapsed_ms(apply_start_ms)}",
      )
      trace(
        "phase=done changed=true elapsed_ms=\{rg_trace_elapsed_ms(pass_start_ms)}",
      )
      Ok(next)
    }
    Err(e) => Err(e)
  }
}

///|
fn reorder_globals_ir_pass(
  _mod : Module,
  always : Bool,
  trace? : (String) -> Unit = rg_trace_noop,
  trace_all_funcs? : Bool = false,
) -> ModuleTransformer[IRContext] {
  ModuleTransformer::new().on_module_evt(fn(_, ctx, mod) {
    match reorder_globals_impl(mod, always, trace~, trace_all_funcs~) {
      Ok(next) => change(ctx, next)
      Err(e) => Err(e)
    }
  })
}

///|
fn rg_run_reorder_globals(mod : Module, always : Bool) -> Module {
  let pass = reorder_globals_ir_pass(mod, always)
  match pass.walk_module(IRContext::new(), mod) {
    Ok(Some((_, out))) => out
    Ok(None) => mod
    Err(e) => abort("reorder_globals pass failed: \{e}")
  }
}

///|
test "reorder_globals_always reorders globals by use count while preserving dependencies" {
  let imported = Import::new(
    Name::new("env"),
    Name::new("gimp"),
    ExternType::global(GlobalType::new(ValType::i32(), true)),
  )
  let g0 = Global::new(
    GlobalType::new(ValType::i32(), true),
    Expr::new([Instruction::i32_const(I32(1))]),
  )
  let g1 = Global::new(
    GlobalType::new(ValType::i32(), true),
    Expr::new([Instruction::global_get(GlobalIdx::new(1))]),
  )
  let g2 = Global::new(
    GlobalType::new(ValType::i32(), true),
    Expr::new([Instruction::i32_const(I32(2))]),
  )
  let body = TExpr::new([
    TInstr::drop(TInstr::global_get(GlobalIdx::new(3))),
    TInstr::drop(TInstr::global_get(GlobalIdx::new(3))),
    TInstr::global_set(GlobalIdx::new(2), TInstr::i32_const(I32(9))),
  ])
  let mod = Module::new()
    .with_import_sec(ImportSec::new([imported]))
    .with_global_sec(GlobalSec::new([g0, g1, g2]))
    .with_code_sec(CodeSec::new([Func::t_func([], [], body)]))
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("g1"), ExternIdx::global(GlobalIdx::new(2))),
      ]),
    )
  let out = rg_run_reorder_globals(mod, true)
  match out.global_sec {
    Some(GlobalSec(globals)) => {
      assert_eq(globals.length(), 3)
      match globals[0] {
        Global(_, Expr([I32Const(I32(v))])) => assert_eq(v, 2)
        _ => fail("expected first reordered global init to be i32.const 2")
      }
      match globals[1] {
        Global(_, Expr([I32Const(I32(v))])) => assert_eq(v, 1)
        _ => fail("expected second reordered global init to be i32.const 1")
      }
      match globals[2] {
        Global(_, Expr([GlobalGet(GlobalIdx(i))])) => assert_eq(i, 2U)
        _ =>
          fail("expected third reordered global init to depend on remapped g0")
      }
    }
    _ =>
      fail("expected globals reordered to [g2, g0, g1] with remapped init dep")
  }
  match out.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            [],
            _,
            {
              instrs: [
                {
                  kind: TInstrKind::TDrop(
                    { kind: TInstrKind::TGlobalGet(GlobalIdx(g0)), .. }
                  ),
                  ..,
                },
                {
                  kind: TInstrKind::TDrop(
                    { kind: TInstrKind::TGlobalGet(GlobalIdx(g1)), .. }
                  ),
                  ..,
                },
                { kind: TInstrKind::TGlobalSet(GlobalIdx(g2), _), .. },
              ],
              ..,
            }
          ),
        ]
      )
    ) => {
      assert_eq(g0, 1U)
      assert_eq(g1, 1U)
      assert_eq(g2, 3U)
    }
    _ => fail("expected global indices remapped in code")
  }
  match out.export_sec {
    Some(ExportSec([Export(_, GlobalExternIdx(GlobalIdx(i)))])) =>
      assert_eq(i, 3U)
    _ => fail("expected remapped exported global index")
  }
}

///|
test "reorder_globals non-always keeps modules with fewer than 128 globals unchanged" {
  let g0 = Global::new(
    GlobalType::new(ValType::i32(), true),
    Expr::new([Instruction::i32_const(I32(1))]),
  )
  let g1 = Global::new(
    GlobalType::new(ValType::i32(), true),
    Expr::new([Instruction::i32_const(I32(2))]),
  )
  let body = TExpr::new([
    TInstr::drop(TInstr::global_get(GlobalIdx::new(1))),
    TInstr::drop(TInstr::global_get(GlobalIdx::new(1))),
  ])
  let mod = Module::new()
    .with_global_sec(GlobalSec::new([g0, g1]))
    .with_code_sec(CodeSec::new([Func::t_func([], [], body)]))
  let out = rg_run_reorder_globals(mod, false)
  assert_eq(out, mod)
}

///|
test "rg_do_sort prefers higher-count available globals while honoring deps" {
  let deps = [[1], [], []]
  let counts = [1.0, 1.0, 2.0]
  let order = rg_do_sort(counts, deps)
  assert_eq(order, [2, 0, 1])
}

///|
test "rg_collect_use_counts counts global.get and global.set over module and code" {
  let imported = Import::new(
    Name::new("env"),
    Name::new("gimp"),
    ExternType::global(GlobalType::new(ValType::i32(), true)),
  )
  let g0 = Global::new(
    GlobalType::new(ValType::i32(), true),
    Expr::new([Instruction::i32_const(I32(1))]),
  )
  let g1 = Global::new(
    GlobalType::new(ValType::i32(), true),
    Expr::new([Instruction::global_get(GlobalIdx::new(1))]),
  )
  let g2 = Global::new(
    GlobalType::new(ValType::i32(), true),
    Expr::new([Instruction::i32_const(I32(2))]),
  )
  let body = TExpr::new([
    TInstr::drop(TInstr::global_get(GlobalIdx::new(3))),
    TInstr::drop(TInstr::global_get(GlobalIdx::new(3))),
    TInstr::global_set(GlobalIdx::new(2), TInstr::i32_const(I32(9))),
  ])
  let mod = Module::new()
    .with_import_sec(ImportSec::new([imported]))
    .with_global_sec(GlobalSec::new([g0, g1, g2]))
    .with_code_sec(CodeSec::new([Func::t_func([], [], body)]))
  let counts = match rg_collect_use_counts(mod, 1, 3) {
    Ok(out) => out
    Err(e) => fail("unexpected count collection failure: \{e}")
  }
  assert_eq(counts, [1.0, 1.0, 2.0])
}

///|
test "rg_compute_size in always mode prefers front-loading high-count globals" {
  let counts = [1.0, 1.0, 2.0]
  let id_size = rg_compute_size([0, 1, 2], counts, true)
  let reordered_size = rg_compute_size([2, 0, 1], counts, true)
  assert_true(reordered_size < id_size)
}
