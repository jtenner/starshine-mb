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
priv struct RSEBlockId(Int) derive(Eq, Hash)

///|
priv struct RSEBlock {
  events : Array[Int]
  succs : Array[RSEBlockId]
}

///|
priv enum RSEEventKind {
  LocalGet(LocalIdx)
  LocalSet(LocalIdx, TInstr)
}

///|
priv struct RSECFG {
  entry : RSEBlockId
  blocks : Map[RSEBlockId, RSEBlock]
  preds : Map[RSEBlockId, Array[RSEBlockId]]
  events : Map[Int, RSEEventKind]
}

///|
priv struct RSEBuildState {
  mut next_block : Int
  mut next_event : Int
  blocks : Map[RSEBlockId, RSEBlock]
  preds : Map[RSEBlockId, Array[RSEBlockId]]
  events : Map[Int, RSEEventKind]
}

///|
type RSELocalValues = Array[Int]

///|
priv struct RSEValueNumbering {
  mut next_value : Int
  expr_values : Map[TInstr, Int]
  block_merge_values : Map[RSEBlockId, Map[Int, Int]]
  unseen_value : Int
}

///|
priv struct RSEFlowState {
  start_values : Map[RSEBlockId, RSELocalValues]
}

///|
priv struct RSEActions {
  remove_sets : Set[Int]
  replace_gets : Map[Int, LocalIdx]
}

///|
priv struct RSERewriteState {
  remove_sets : Set[Int]
  replace_gets : Map[Int, LocalIdx]
  mut next_event : Int
  mut changed : Bool
}

///|
priv struct RSEWorkQueue {
  queue : Array[RSEBlockId]
  in_queue : Set[RSEBlockId]
  mut head : Int
}

///|
fn RSEBuildState::new() -> RSEBuildState {
  {
    next_block: 0,
    next_event: 0,
    blocks: Map::new(),
    preds: Map::new(),
    events: Map::new(),
  }
}

///|
fn RSEValueNumbering::new() -> RSEValueNumbering {
  {
    next_value: 1,
    expr_values: Map::new(),
    block_merge_values: Map::new(),
    unseen_value: 0,
  }
}

///|
fn RSEActions::new() -> RSEActions {
  { remove_sets: Set::new(), replace_gets: Map::new() }
}

///|
fn RSERewriteState::new(actions : RSEActions) -> RSERewriteState {
  {
    remove_sets: actions.remove_sets,
    replace_gets: actions.replace_gets,
    next_event: 0,
    changed: false,
  }
}

///|
fn RSEWorkQueue::new() -> RSEWorkQueue {
  { queue: [], in_queue: Set::new(), head: 0 }
}

///|
fn rse_local_idx_to_int(idx : LocalIdx) -> Int {
  let LocalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn rse_int_to_local_idx(i : Int) -> LocalIdx {
  LocalIdx::new(i.reinterpret_as_uint())
}

///|
fn rse_make_block(state : RSEBuildState) -> RSEBlockId {
  let id = RSEBlockId(state.next_block)
  state.next_block += 1
  state.blocks[id] = { events: [], succs: [] }
  id
}

///|
fn rse_add_edge(
  state : RSEBuildState,
  from : RSEBlockId,
  to : RSEBlockId,
) -> Unit {
  state.blocks[from].succs.push(to)
  state.preds.get_or_init(to, fn() { [] }).push(from)
}

///|
fn rse_add_event(
  state : RSEBuildState,
  block_id : RSEBlockId,
  event : RSEEventKind,
) -> Unit {
  let id = state.next_event
  state.next_event += 1
  state.events[id] = event
  state.blocks[block_id].events.push(id)
}

///|
fn rse_collect_instr_events(
  state : RSEBuildState,
  block_id : RSEBlockId,
  instr : TInstr,
) -> Unit {
  match instr {
    TLocalGet(idx) =>
      rse_add_event(state, block_id, RSEEventKind::LocalGet(idx))
    TLocalSet(idx, value) => {
      rse_collect_instr_events(state, block_id, value)
      rse_add_event(state, block_id, RSEEventKind::LocalSet(idx, value))
    }
    TLocalTee(idx, value) => {
      rse_collect_instr_events(state, block_id, value)
      rse_add_event(state, block_id, RSEEventKind::LocalSet(idx, value))
    }
    TIf(_, cond, _, _) => rse_collect_instr_events(state, block_id, cond)
    TBlock(_, _) | TLoop(_, _) | TTryTable(_, _, _) => ()
    _ =>
      for child in eval_children(instr) {
        rse_collect_instr_events(state, block_id, child)
      }
  }
}

///|
fn rse_lower_texpr(
  body : TExpr,
  current : RSEBlockId,
  state : RSEBuildState,
) -> RSEBlockId {
  let mut current = current
  for instr in body.0 {
    match instr {
      TIf(_, cond, then_body, else_body) => {
        rse_collect_instr_events(state, current, cond)
        let then_block = rse_make_block(state)
        let else_block = rse_make_block(state)
        let merge_block = rse_make_block(state)
        rse_add_edge(state, current, then_block)
        rse_add_edge(state, current, else_block)
        let then_end = rse_lower_texpr(then_body, then_block, state)
        rse_add_edge(state, then_end, merge_block)
        match else_body {
          Some(other) => {
            let else_end = rse_lower_texpr(other, else_block, state)
            rse_add_edge(state, else_end, merge_block)
          }
          None => rse_add_edge(state, else_block, merge_block)
        }
        current = merge_block
      }
      TReturn(values) => {
        for value in values {
          rse_collect_instr_events(state, current, value)
        }
        return current
      }
      _ => {
        rse_collect_instr_events(state, current, instr)
        if is_unreachable_instr(instr) {
          return current
        }
      }
    }
  }
  current
}

///|
fn rse_build_cfg(body : TExpr) -> RSECFG {
  let state = RSEBuildState::new()
  let entry = rse_make_block(state)
  ignore(rse_lower_texpr(body, entry, state))
  { entry, blocks: state.blocks, preds: state.preds, events: state.events }
}

///|
fn rse_compute_rpo(cfg : RSECFG) -> Array[RSEBlockId] {
  let visited : Set[RSEBlockId] = Set::new()
  let order : Array[RSEBlockId] = []
  fn dfs(id : RSEBlockId) -> Unit {
    if visited.contains(id) {
      return
    }
    visited.add(id)
    for succ in cfg.blocks.get(id).unwrap().succs {
      dfs(succ)
    }
    order.push(id)
  }

  dfs(cfg.entry)
  order.rev_in_place()
  order
}

///|
fn RSEWorkQueue::push(self : RSEWorkQueue, block_id : RSEBlockId) -> Unit {
  if self.in_queue.contains(block_id) {
    return
  }
  self.in_queue.add(block_id)
  self.queue.push(block_id)
}

///|
fn RSEWorkQueue::is_empty(self : RSEWorkQueue) -> Bool {
  self.head >= self.queue.length()
}

///|
fn RSEWorkQueue::pop(self : RSEWorkQueue) -> RSEBlockId {
  let id = self.queue[self.head]
  self.head += 1
  self.in_queue.remove(id)
  id
}

///|
fn RSEValueNumbering::unique(self : RSEValueNumbering) -> Int {
  let value = self.next_value
  self.next_value += 1
  value
}

///|
fn RSEValueNumbering::value_for_expr(
  self : RSEValueNumbering,
  expr : TInstr,
) -> Int {
  match self.expr_values.get(expr) {
    Some(value) => value
    None => {
      let value = self.unique()
      self.expr_values[expr] = value
      value
    }
  }
}

///|
fn RSEValueNumbering::get_block_merge_value(
  self : RSEValueNumbering,
  block_id : RSEBlockId,
  local_index : Int,
) -> Int {
  let per_block = self.block_merge_values.get_or_init(block_id, fn() {
    Map::new()
  })
  match per_block.get(local_index) {
    Some(value) => value
    None => {
      let value = self.unique()
      per_block[local_index] = value
      value
    }
  }
}

///|
fn RSEValueNumbering::is_block_merge_value(
  self : RSEValueNumbering,
  block_id : RSEBlockId,
  local_index : Int,
  value : Int,
) -> Bool {
  match self.block_merge_values.get(block_id) {
    Some(per_block) => per_block.get(local_index) == Some(value)
    None => false
  }
}

///|
fn rse_zero_tinstr(vt : ValType) -> TInstr? {
  match vt {
    NumTypeValType(nt) =>
      match nt {
        I32NumType => Some(TInstr::i32_const(I32(0)))
        I64NumType => Some(TInstr::i64_const(I64(0L)))
        F32NumType => Some(TInstr::f32_const(F32(0.0)))
        F64NumType => Some(TInstr::f64_const(F64(0.0)))
      }
    VecTypeValType =>
      Some(TInstr::v128_const(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    RefTypeValType(rt) =>
      if rt.is_nullable() {
        Some(TInstr::ref_null(rt.get_heap_type()))
      } else {
        None
      }
    BotValType => None
  }
}

///|
fn rse_get_fallthrough(instr : TInstr) -> TInstr {
  match instr {
    TBlock(_, TExpr(instrs)) if instrs.length() > 0 =>
      rse_get_fallthrough(instrs[instrs.length() - 1])
    _ => instr
  }
}

///|
fn rse_value_of(
  analyzer : RSEValueNumbering,
  instr : TInstr,
  curr_values : RSELocalValues,
) -> Int {
  match instr {
    TLocalGet(idx) => curr_values[rse_local_idx_to_int(idx)]
    _ => analyzer.value_for_expr(instr)
  }
}

///|
fn rse_compute_initial_start(
  locals : Array[ValType],
  param_count : Int,
  analyzer : RSEValueNumbering,
) -> RSELocalValues {
  let start : RSELocalValues = []
  for i in 0..<locals.length() {
    if i < param_count {
      start.push(analyzer.unique())
    } else {
      match rse_zero_tinstr(locals[i]) {
        Some(zero) => start.push(analyzer.value_for_expr(zero))
        None => start.push(analyzer.unique())
      }
    }
  }
  start
}

///|
fn rse_flow_values(
  cfg : RSECFG,
  locals : Array[ValType],
  param_count : Int,
  analyzer : RSEValueNumbering,
) -> RSEFlowState {
  let start_values : Map[RSEBlockId, RSELocalValues] = Map::new()
  let end_values : Map[RSEBlockId, RSELocalValues] = Map::new()

  let unseen = analyzer.unseen_value
  let init_start = rse_compute_initial_start(locals, param_count, analyzer)

  for entry in cfg.blocks {
    let (block_id, _) = entry
    if block_id == cfg.entry {
      start_values[block_id] = init_start.copy()
    } else {
      let unseen_values : RSELocalValues = []
      for _ in 0..<locals.length() {
        unseen_values.push(unseen)
      }
      start_values[block_id] = unseen_values
    }
    let unseen_end : RSELocalValues = []
    for _ in 0..<locals.length() {
      unseen_end.push(unseen)
    }
    end_values[block_id] = unseen_end
  }

  let work = RSEWorkQueue::new()
  work.push(cfg.entry)

  while !work.is_empty() {
    let block_id = work.pop()
    let preds = cfg.preds.get(block_id).unwrap_or([])
    if preds.length() > 0 {
      if preds.length() == 1 {
        start_values[block_id] = end_values[preds[0]].copy()
      } else {
        let merged = start_values[block_id]
        for local_i in 0..<locals.length() {
          let old = merged[local_i]
          if analyzer.is_block_merge_value(block_id, local_i, old) {
            continue
          }
          let mut value = end_values[preds[0]][local_i]
          for pred in preds.op_as_view(start=1, end=preds.length()) {
            let other = end_values[pred][local_i]
            if value == unseen {
              value = other
            } else if other == unseen {
              ()
            } else if value != other {
              value = analyzer.get_block_merge_value(block_id, local_i)
              break
            }
          }
          merged[local_i] = value
        }
      }
    }

    let curr = start_values[block_id].copy()
    for event_id in cfg.blocks[block_id].events {
      match cfg.events[event_id] {
        LocalSet(idx, value) => {
          let local_i = rse_local_idx_to_int(idx)
          let value_num = rse_value_of(
            analyzer,
            rse_get_fallthrough(value),
            curr,
          )
          curr[local_i] = value_num
        }
        _ => ()
      }
    }

    if curr != end_values[block_id] {
      end_values[block_id] = curr
      for succ in cfg.blocks[block_id].succs {
        work.push(succ)
      }
    }
  }

  { start_values, }
}

///|
fn rse_refinable_locals(locals : Array[ValType]) -> Array[Bool] {
  let out : Array[Bool] = []
  for local_ty in locals {
    match local_ty {
      RefTypeValType(_) => out.push(true)
      _ => out.push(false)
    }
  }
  out
}

///|
fn rse_find_best_refinement(
  env : Env,
  locals : Array[ValType],
  refinable : Array[Bool],
  curr_values : RSELocalValues,
  get_idx : LocalIdx,
) -> LocalIdx? {
  let get_i = rse_local_idx_to_int(get_idx)
  if !refinable[get_i] {
    return None
  }

  let curr_ty = locals[get_i]
  let target_value = curr_values[get_i]
  let mut best_i : Int? = None

  for i in 0..<locals.length() {
    if i == get_i || !refinable[i] || curr_values[i] != target_value {
      continue
    }

    let possible_ty = locals[i]
    if possible_ty == curr_ty || !Match::matches(possible_ty, curr_ty, env) {
      continue
    }

    match best_i {
      None => best_i = Some(i)
      Some(existing) => {
        let existing_ty = locals[existing]
        if possible_ty != existing_ty &&
          Match::matches(possible_ty, existing_ty, env) {
          best_i = Some(i)
        }
      }
    }
  }

  match best_i {
    Some(i) => Some(rse_int_to_local_idx(i))
    None => None
  }
}

///|
fn rse_collect_actions(
  cfg : RSECFG,
  locals : Array[ValType],
  env : Env,
  flow : RSEFlowState,
  analyzer : RSEValueNumbering,
) -> RSEActions {
  let actions = RSEActions::new()
  let refinable = rse_refinable_locals(locals)

  for block_id in rse_compute_rpo(cfg) {
    let curr_values = flow.start_values[block_id].copy()
    for event_id in cfg.blocks[block_id].events {
      match cfg.events[event_id] {
        LocalSet(idx, value) => {
          let local_i = rse_local_idx_to_int(idx)
          let old_value = curr_values[local_i]
          let new_value = rse_value_of(
            analyzer,
            rse_get_fallthrough(value),
            curr_values,
          )
          if new_value == old_value {
            actions.remove_sets.add(event_id)
          } else {
            curr_values[local_i] = new_value
          }
        }
        LocalGet(idx) =>
          match
            rse_find_best_refinement(env, locals, refinable, curr_values, idx) {
            Some(new_idx) =>
              if new_idx != idx {
                actions.replace_gets[event_id] = new_idx
              }
            None => ()
          }
      }
    }
  }

  actions
}

///|
fn rse_rewrite_children(
  state : RSERewriteState,
  children : Array[TInstr],
) -> (Array[TInstr], Bool) {
  let out : Array[TInstr] = []
  let mut changed = false
  for child in children {
    let next_child = rse_rewrite_instr(state, child)
    if next_child != child {
      changed = true
    }
    out.push(next_child)
  }
  (out, changed)
}

///|
fn rse_rewrite_instr(state : RSERewriteState, instr : TInstr) -> TInstr {
  match instr {
    TLocalGet(idx) => {
      let event_id = state.next_event
      state.next_event += 1
      match state.replace_gets.get(event_id) {
        Some(new_idx) =>
          if new_idx != idx {
            state.changed = true
            TInstr::local_get(new_idx)
          } else {
            instr
          }
        None => instr
      }
    }
    TLocalSet(idx, value) => {
      let next_value = rse_rewrite_instr(state, value)
      let event_id = state.next_event
      state.next_event += 1
      if state.remove_sets.contains(event_id) {
        state.changed = true
        TInstr::drop(next_value)
      } else if next_value != value {
        TInstr::local_set(idx, next_value)
      } else {
        instr
      }
    }
    TLocalTee(idx, value) => {
      let next_value = rse_rewrite_instr(state, value)
      let event_id = state.next_event
      state.next_event += 1
      if state.remove_sets.contains(event_id) {
        state.changed = true
        next_value
      } else if next_value != value {
        TInstr::local_tee(idx, next_value)
      } else {
        instr
      }
    }
    TIf(bt, cond, then_body, else_body) => {
      let next_cond = rse_rewrite_instr(state, cond)
      if next_cond == cond {
        instr
      } else {
        TInstr::if_(bt, next_cond, then_body, else_body)
      }
    }
    TBlock(_, _) | TLoop(_, _) | TTryTable(_, _, _) => instr
    _ => {
      let children = eval_children(instr)
      if children.is_empty() {
        return instr
      }
      let (next_children, changed) = rse_rewrite_children(state, children)
      if !changed {
        instr
      } else {
        mb_rebuild_non_control(instr, next_children)
      }
    }
  }
}

///|
fn rse_rewrite_texpr(state : RSERewriteState, body : TExpr) -> TExpr {
  let out : Array[TInstr] = []
  for instr in body.0 {
    match instr {
      TIf(bt, cond, then_body, else_body) => {
        let next_cond = rse_rewrite_instr(state, cond)
        let next_then = rse_rewrite_texpr(state, then_body)
        let next_else = else_body.map(fn(e) { rse_rewrite_texpr(state, e) })
        if next_cond != cond || next_then != then_body || next_else != else_body {
          state.changed = true
        }
        out.push(TInstr::if_(bt, next_cond, next_then, next_else))
      }
      TReturn(values) => {
        let (next_values, changed) = rse_rewrite_children(state, values)
        if changed {
          state.changed = true
          out.push(TInstr::return_(next_values))
        } else {
          out.push(instr)
        }
        return TExpr::new(out)
      }
      _ => {
        let next_instr = rse_rewrite_instr(state, instr)
        out.push(next_instr)
        if is_unreachable_instr(instr) {
          return TExpr::new(out)
        }
      }
    }
  }
  TExpr::new(out)
}

///|
fn rse_collect_param_counts(mod : Module) -> Array[Int] {
  let out : Array[Int] = []
  let env = Env::new().with_module(mod)
  match mod.func_sec {
    Some(FuncSec(type_idxs)) =>
      for tidx in type_idxs {
        match env.resolve_functype(tidx) {
          Some(FuncType(params, _)) => out.push(params.length())
          None => out.push(0)
        }
      }
    None => ()
  }
  out
}

///|
fn rse_optimize_function(
  func : Func,
  env_base : Env,
  param_count : Int,
) -> (Func, Bool) {
  match func {
    TFunc(locals, body) => {
      if locals.length() == 0 {
        return (func, false)
      }

      let cfg = rse_build_cfg(body)
      if cfg.events.length() == 0 {
        return (func, false)
      }

      let analyzer = RSEValueNumbering::new()
      let bounded_param_count = if param_count < locals.length() {
        param_count
      } else {
        locals.length()
      }
      let flow = rse_flow_values(cfg, locals, bounded_param_count, analyzer)
      let env = env_base.with_locals(locals)
      let actions = rse_collect_actions(cfg, locals, env, flow, analyzer)
      if actions.remove_sets.is_empty() && actions.replace_gets.is_empty() {
        return (func, false)
      }

      let rewrite_state = RSERewriteState::new(actions)
      let next_body = rse_rewrite_texpr(rewrite_state, body)
      if rewrite_state.next_event != cfg.events.length() {
        return (func, false)
      }
      if !rewrite_state.changed {
        return (func, false)
      }
      (Func::t_func(locals, next_body), true)
    }
    _ => (func, false)
  }
}

///|
fn redundant_set_elimination_ir_pass(
  mod : Module,
) -> ModuleTransformer[IRContext] {
  let env_base = Env::new().with_module(mod)
  let param_counts = rse_collect_param_counts(mod)
  let next_def_idx = Ref::new(0)
  ModuleTransformer::new().on_func_evt(fn(_, ctx, func) {
    let def_idx = next_def_idx.val
    next_def_idx.update(fn(i) { i + 1 })
    let param_count = param_counts.get(def_idx).unwrap_or(0)
    let (next_func, changed) = rse_optimize_function(
      func, env_base, param_count,
    )
    if changed {
      change(ctx, next_func)
    } else {
      unchanged()
    }
  })
}

///|
fn run_redundant_set_elimination(mod : Module) -> Module {
  let pass = redundant_set_elimination_ir_pass(mod)
  match pass.walk_module(IRContext::new(), mod) {
    Ok(Some((_, out))) => out
    _ => mod
  }
}

///|
fn rse_type(params : Array[ValType], results : Array[ValType]) -> RecType {
  single_rec_type(comp_type_sub_type(func_comp_type(params, results)))
}

///|
fn rse_first_body(mod : Module) -> TExpr raise {
  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      match funcs.get(0) {
        Some(TFunc(_, body)) => body
        _ => fail("expected first function body")
      }
    _ => fail("expected code section")
  }
}

///|
fn rse_run(mod : Module) -> Module {
  run_redundant_set_elimination(mod)
}

///|
fn rse_count_instr(body : TExpr, pred : (TInstr) -> Bool) -> Int {
  let mut count = 0
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    if pred(instr) {
      count += 1
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  count
}

///|
test "redundant_set_elimination removes redundant local.set in straight line" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::i32()],
        TExpr::new([
          TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(7))),
          TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(7))),
          TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
        ]),
      ),
    ]),
  )
  let out = rse_run(mod)
  match rse_first_body(out).0 {
    [
      TLocalSet(_, TI32Const(I32(7))),
      TDrop(TI32Const(I32(7))),
      TDrop(TLocalGet(_)),
    ] => ()
    _ => fail("expected second local.set to be converted into drop(value)")
  }
}

///|
test "redundant_set_elimination rewrites redundant local.tee to plain value" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::i32()],
        TExpr::new([
          TInstr::drop(
            TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(3))),
          ),
          TInstr::drop(
            TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(3))),
          ),
        ]),
      ),
    ]),
  )
  let out = rse_run(mod)
  match rse_first_body(out).0 {
    [TDrop(TLocalTee(_, TI32Const(I32(3)))), TDrop(TI32Const(I32(3)))] => ()
    _ => fail("expected redundant tee to be replaced by its value")
  }
}

///|
test "redundant_set_elimination keeps non-redundant local.set" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::i32()],
        TExpr::new([
          TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(1))),
          TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(2))),
        ]),
      ),
    ]),
  )
  let out = rse_run(mod)
  assert_eq(
    rse_count_instr(rse_first_body(out), fn(instr) {
      match instr {
        TLocalSet(_, _) => true
        _ => false
      }
    }),
    2,
  )
}

///|
test "redundant_set_elimination removes zero-init redundant sets for vars" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::i32()],
        TExpr::new([
          TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(0))),
        ]),
      ),
    ]),
  )
  let out = rse_run(mod)
  match rse_first_body(out).0 {
    [TDrop(TI32Const(I32(0)))] => ()
    _ => fail("expected local initialized-to-zero write to be removed")
  }
}

///|
test "redundant_set_elimination treats params as unknown initial values" {
  let mod = Module::new()
    .with_type_sec(TypeSec::new([rse_type([ValType::i32()], [])]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          TExpr::new([
            TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(0))),
          ]),
        ),
      ]),
    )
  let out = rse_run(mod)
  match rse_first_body(out).0 {
    [TLocalSet(_, TI32Const(I32(0)))] => ()
    _ => fail("expected set to param-backed local to remain")
  }
}

///|
test "redundant_set_elimination removes redundant post-merge set on equal branches" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::i32(), ValType::i32()],
        TExpr::new([
          TInstr::if_(
            BlockType::void_(),
            TInstr::local_get(LocalIdx::new(1)),
            TExpr::new([
              TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(4))),
            ]),
            Some(
              TExpr::new([
                TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(4))),
              ]),
            ),
          ),
          TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(4))),
        ]),
      ),
    ]),
  )
  let out = rse_run(mod)
  match rse_first_body(out).0 {
    [TIf(_, _, _, _), TDrop(TI32Const(I32(4)))] => ()
    _ => fail("expected post-merge equal-value set to be removed")
  }
}

///|
test "redundant_set_elimination keeps post-merge set on differing branches" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::i32(), ValType::i32()],
        TExpr::new([
          TInstr::if_(
            BlockType::void_(),
            TInstr::local_get(LocalIdx::new(1)),
            TExpr::new([
              TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(4))),
            ]),
            Some(
              TExpr::new([
                TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(5))),
              ]),
            ),
          ),
          TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(4))),
        ]),
      ),
    ]),
  )
  let out = rse_run(mod)
  match rse_first_body(out).0 {
    [TIf(_, _, _, _), TLocalSet(_, TI32Const(I32(4)))] => ()
    _ => fail("expected post-merge set to remain when incoming values differ")
  }
}

///|
test "redundant_set_elimination refines local.get to more specific local" {
  let mod = Module::new()
    .with_type_sec(TypeSec::new([rse_type([], [])]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [
            ValType::funcref(),
            ValType::ref_type(
              RefType::new(true, HeapType::abs(AbsHeapType::no_func())),
            ),
          ],
          TExpr::new([
            TInstr::local_set(
              LocalIdx::new(0),
              TInstr::local_get(LocalIdx::new(1)),
            ),
            TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
          ]),
        ),
      ]),
    )
  let out = rse_run(mod)
  match rse_first_body(out).0 {
    [TLocalSet(_, TLocalGet(LocalIdx(i0))), TDrop(TLocalGet(LocalIdx(i1)))] => {
      assert_eq(i0.reinterpret_as_int(), 1)
      assert_eq(i1.reinterpret_as_int(), 1)
    }
    _ => fail("expected get to be retargeted to subtype local")
  }
  match validate_module(out) {
    Ok(_) => ()
    Err(e) => fail("expected refined output to validate: \{e}")
  }
}

///|
test "redundant_set_elimination keeps nested block-local set behavior conservative" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::i32()],
        TExpr::new([
          TInstr::block(
            BlockType::void_(),
            TExpr::new([
              TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(9))),
            ]),
          ),
          TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(9))),
        ]),
      ),
    ]),
  )
  let out = rse_run(mod)
  match rse_first_body(out).0 {
    [TBlock(_, _), TLocalSet(_, TI32Const(I32(9)))] => ()
    _ =>
      fail(
        "expected post-block set to remain; nested block sets are intentionally conservative",
      )
  }
}

///|
test "redundant_set_elimination is idempotent" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::i32()],
        TExpr::new([
          TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(1))),
          TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(1))),
          TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
        ]),
      ),
    ]),
  )
  let once = rse_run(mod)
  let twice = rse_run(once)
  assert_eq(once, twice)
}
