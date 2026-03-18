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
fn optimize_tfunc_with_ssa(
  ctx : IRContext,
  mod : Module,
  params : Array[ValType],
  locals : Locals,
  body : TExpr,
  trace? : (String) -> Unit = fn(_) { () },
) -> (Locals, TExpr)? {
  let function_locals = FunctionLocals::new(params, locals)
  ctx.set_mod(mod)
  ctx.set_locals(
    function_locals.all_locals(),
    param_count=function_locals.param_count(),
  )
  ctx.set_body(body)
  ctx.optimize_body_with_ssa_trace_with_locals(trace)
}

///|
priv enum SSANoMergeReachState {
  Empty
  InitOnly
  SetOnly(Int)
  Multiple
} derive(Eq)

///|
priv struct SSANoMergeReachQueryKey {
  block_id : Int
  idx : LocalIdx
} derive(Eq, Hash)

///|
priv struct SSANoMergeGetNode {
  idx : LocalIdx
}

///|
priv struct SSANoMergeSetNode {
  idx : LocalIdx
}

///|
priv enum SSANoMergeAction {
  Get(LocalIdx, Int)
  Set(LocalIdx, Int)
}

///|
priv struct SSANoMergeGraphBlock {
  preds : Array[Int]
  actions : Array[SSANoMergeAction]
  last_sets : Map[LocalIdx, Int]
}

///|
priv struct SSANoMergeGraphState {
  blocks : Array[SSANoMergeGraphBlock]
  get_nodes : Array[SSANoMergeGetNode]
  set_nodes : Array[SSANoMergeSetNode]
}

///|
priv struct SSANoMergeAnalysis {
  get_reaches : Array[SSANoMergeReachState]
  get_nodes : Array[SSANoMergeGetNode]
  set_nodes : Array[SSANoMergeSetNode]
  set_influences : Array[Array[Int]]
}

///|
priv struct SSANoMergeAnalysisStateCounts {
  single_set_gets : Int
  multi_reaching_gets : Int
  init_only_gets : Int
}

///|
priv enum SSANoMergeGetRewrite {
  Local(LocalIdx)
  ConstInstr(TInstr)
}

///|
priv enum DataflowNormalizedFunc {
  TFuncBody(Array[ValType], Locals, TExpr)
  PlainFunc(Func)
}

///|
fn ssa_nomerge_graph_new_state() -> SSANoMergeGraphState {
  { blocks: [], get_nodes: [], set_nodes: [] }
}

///|
fn ssa_nomerge_graph_new_block(
  state : SSANoMergeGraphState,
  preds : Array[Int],
) -> Int {
  let id = state.blocks.length()
  state.blocks.push(SSANoMergeGraphBlock::{
    preds,
    actions: [],
    last_sets: Map::new(),
  })
  id
}

///|
fn ssa_nomerge_graph_add_pred(
  state : SSANoMergeGraphState,
  block_id : Int,
  pred_id : Int,
) -> Unit {
  let block = state.blocks.get(block_id).unwrap()
  if !block.preds.contains(pred_id) {
    block.preds.push(pred_id)
  }
}

///|
fn ssa_nomerge_graph_add_get(
  state : SSANoMergeGraphState,
  block_id : Int,
  idx : LocalIdx,
) -> Unit {
  let get_id = state.get_nodes.length()
  state.get_nodes.push(SSANoMergeGetNode::{ idx, })
  let block = state.blocks.get(block_id).unwrap()
  block.actions.push(SSANoMergeAction::Get(idx, get_id))
}

///|
fn ssa_nomerge_graph_add_set(
  state : SSANoMergeGraphState,
  block_id : Int,
  idx : LocalIdx,
) -> Unit {
  let set_id = state.set_nodes.length()
  state.set_nodes.push(SSANoMergeSetNode::{ idx, })
  let block = state.blocks.get(block_id).unwrap()
  block.actions.push(SSANoMergeAction::Set(idx, set_id))
  block.last_sets[idx] = set_id
}

///|
fn ssa_nomerge_graph_lower_texpr(
  expr : TExpr,
  block_id : Int,
  state : SSANoMergeGraphState,
) -> Int {
  let mut curr_block = block_id
  for instr in expr.instrs {
    curr_block = ssa_nomerge_graph_lower_tinstruction(instr, curr_block, state)
  }
  curr_block
}

///|
fn ssa_nomerge_graph_lower_tinstruction(
  instr : TInstr,
  block_id : Int,
  state : SSANoMergeGraphState,
) -> Int {
  match instr.kind {
    TInstrKind::TLocalGet(idx) => {
      ssa_nomerge_graph_add_get(state, block_id, idx)
      block_id
    }
    TInstrKind::TLocalTee(idx, value) => {
      let block_id = ssa_nomerge_graph_lower_tinstruction(
        value, block_id, state,
      )
      ssa_nomerge_graph_add_set(state, block_id, idx)
      block_id
    }
    TInstrKind::TLocalSet(idx, value) => {
      let block_id = ssa_nomerge_graph_lower_tinstruction(
        value, block_id, state,
      )
      ssa_nomerge_graph_add_set(state, block_id, idx)
      block_id
    }
    TInstrKind::TIf(_, cond, then_, else_) => {
      let block_id = ssa_nomerge_graph_lower_tinstruction(cond, block_id, state)
      let then_entry = ssa_nomerge_graph_new_block(state, [block_id])
      let then_exit = ssa_nomerge_graph_lower_texpr(then_, then_entry, state)
      let else_entry = ssa_nomerge_graph_new_block(state, [block_id])
      let else_exit = match else_ {
        Some(else_expr) =>
          ssa_nomerge_graph_lower_texpr(else_expr, else_entry, state)
        None => else_entry
      }
      ssa_nomerge_graph_new_block(state, [then_exit, else_exit])
    }
    TInstrKind::TBlock(_, body) =>
      ssa_nomerge_graph_lower_texpr(body, block_id, state)
    TInstrKind::TLoop(_, body) => {
      let loop_entry = ssa_nomerge_graph_new_block(state, [block_id])
      let body_exit = ssa_nomerge_graph_lower_texpr(body, loop_entry, state)
      // Model loop carry conservatively without re-scanning the entire body.
      // This over-approximates possible reaching sets in the safe direction and
      // avoids the pathological subtree rescans that caused severe slowdowns on
      // nested self-opt functions.
      ssa_nomerge_graph_add_pred(state, loop_entry, body_exit)
      ssa_nomerge_graph_new_block(state, [body_exit])
    }
    TInstrKind::TTryTable(_, _, body) => {
      let body_entry = ssa_nomerge_graph_new_block(state, [block_id])
      let body_exit = ssa_nomerge_graph_lower_texpr(body, body_entry, state)
      ssa_nomerge_graph_new_block(state, [block_id, body_exit])
    }
    _ => {
      let mut curr_block = block_id
      for child in eval_children(instr) {
        curr_block = ssa_nomerge_graph_lower_tinstruction(
          child, curr_block, state,
        )
      }
      curr_block
    }
  }
}

///|
fn ssa_nomerge_build_sparse_analysis(body : TExpr) -> SSANoMergeAnalysis {
  let state = ssa_nomerge_graph_new_state()
  let entry = ssa_nomerge_graph_new_block(state, [])
  ignore(ssa_nomerge_graph_lower_texpr(body, entry, state))
  let get_reaches = Array::make(
    state.get_nodes.length(),
    SSANoMergeReachState::Empty,
  )
  let has_set : Set[LocalIdx] = Set::new()
  for node in state.set_nodes {
    has_set.add(node.idx)
  }
  let reach_cache : Map[SSANoMergeReachQueryKey, SSANoMergeReachState] = Map::new()
  let active_queries : Set[SSANoMergeReachQueryKey] = Set::new()
  fn merge_reaches(
    lhs : SSANoMergeReachState,
    rhs : SSANoMergeReachState,
  ) -> SSANoMergeReachState {
    match (lhs, rhs) {
      (SSANoMergeReachState::Empty, other) => other
      (other, SSANoMergeReachState::Empty) => other
      (SSANoMergeReachState::Multiple, _)
      | (_, SSANoMergeReachState::Multiple) => SSANoMergeReachState::Multiple
      (SSANoMergeReachState::InitOnly, SSANoMergeReachState::InitOnly) =>
        SSANoMergeReachState::InitOnly
      (
        SSANoMergeReachState::SetOnly(lhs_id),
        SSANoMergeReachState::SetOnly(rhs_id),
      ) =>
        if lhs_id == rhs_id {
          SSANoMergeReachState::SetOnly(lhs_id)
        } else {
          SSANoMergeReachState::Multiple
        }
      _ => SSANoMergeReachState::Multiple
    }
  }
  fn block_entry_reach(block_id : Int, idx : LocalIdx) -> SSANoMergeReachState {
    let key = SSANoMergeReachQueryKey::{ block_id, idx }
    match reach_cache.get(key) {
      Some(cached) => return cached
      None => ()
    }
    if active_queries.contains(key) {
      return SSANoMergeReachState::Empty
    }
    active_queries.add(key)
    let block = state.blocks.get(block_id).unwrap()
    let mut reach = SSANoMergeReachState::Empty
    if block.preds.is_empty() {
      if block_id == entry {
        reach = SSANoMergeReachState::InitOnly
      }
    } else {
      for pred in block.preds {
        let pred_block = state.blocks.get(pred).unwrap()
        let pred_reach = match pred_block.last_sets.get(idx) {
          Some(set_id) => SSANoMergeReachState::SetOnly(set_id)
          None => block_entry_reach(pred, idx)
        }
        reach = merge_reaches(reach, pred_reach)
        if reach == SSANoMergeReachState::Multiple {
          break
        }
      }
    }
    active_queries.remove(key)
    reach_cache[key] = reach
    reach
  }
  fn note_reach_for_gets(
    get_ids : Array[Int],
    reach : SSANoMergeReachState,
  ) -> Unit {
    for get_id in get_ids {
      get_reaches[get_id] = merge_reaches(get_reaches[get_id], reach)
    }
  }
  let mut block_id = 0
  while block_id < state.blocks.length() {
    let block = state.blocks.get(block_id).unwrap()
    let pending_gets : Map[LocalIdx, Array[Int]] = Map::new()
    let mut action_idx = block.actions.length() - 1
    while action_idx >= 0 {
      match block.actions[action_idx] {
        SSANoMergeAction::Get(idx, get_id) => {
          let gets = pending_gets.get(idx).unwrap_or([])
          gets.push(get_id)
          pending_gets[idx] = gets
        }
        SSANoMergeAction::Set(idx, set_id) =>
          match pending_gets.get(idx) {
            Some(get_ids) => {
              note_reach_for_gets(
                get_ids,
                SSANoMergeReachState::SetOnly(set_id),
              )
              pending_gets.remove(idx)
            }
            None => ()
          }
      }
      if action_idx == 0 {
        break
      }
      action_idx = action_idx - 1
    }
    for entry_ in pending_gets {
      let (idx, get_ids) = entry_
      if get_ids.is_empty() {
        continue
      }
      if !has_set.contains(idx) {
        note_reach_for_gets(get_ids, SSANoMergeReachState::InitOnly)
      } else {
        note_reach_for_gets(get_ids, block_entry_reach(block_id, idx))
      }
    }
    block_id += 1
  }
  let set_influences : Array[Array[Int]] = []
  for _ in 0..<state.set_nodes.length() {
    set_influences.push([])
  }
  for get_id in 0..<get_reaches.length() {
    match get_reaches[get_id] {
      SSANoMergeReachState::SetOnly(set_id) =>
        set_influences[set_id].push(get_id)
      _ => ()
    }
  }
  {
    get_reaches,
    get_nodes: state.get_nodes,
    set_nodes: state.set_nodes,
    set_influences,
  }
}

///|
fn ssa_nomerge_build_analysis(body : TExpr) -> SSANoMergeAnalysis {
  // Binaryen's ssa-nomerge is built on LocalGraph rather than a dense
  // per-local flow-state clone at each control edge. Mirror that shape here:
  // build a sparse block/action graph, then answer get->set queries by
  // flowing backward only for the queried local.
  ssa_nomerge_build_sparse_analysis(body)
}

///|
fn ssa_nomerge_analysis_state_counts(
  body : TExpr,
) -> SSANoMergeAnalysisStateCounts {
  let analysis = ssa_nomerge_build_analysis(body)
  let mut single_set_gets = 0
  let mut multi_reaching_gets = 0
  let mut init_only_gets = 0
  for reach in analysis.get_reaches {
    match reach {
      SSANoMergeReachState::SetOnly(_) => single_set_gets += 1
      SSANoMergeReachState::Multiple => multi_reaching_gets += 1
      SSANoMergeReachState::InitOnly => init_only_gets += 1
      SSANoMergeReachState::Empty => ()
    }
  }
  { single_set_gets, multi_reaching_gets, init_only_gets }
}

///|
fn ssa_nomerge_local_idx_to_int(idx : LocalIdx) -> Int {
  let LocalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn ssa_nomerge_default_constant(vt : ValType) -> TInstr? {
  match vt {
    NumTypeValType(nt) =>
      match nt {
        I32NumType => Some(TInstr::i32_const(I32(0)))
        I64NumType => Some(TInstr::i64_const(I64(0L)))
        F32NumType => Some(TInstr::f32_const(F32(0.0)))
        F64NumType => Some(TInstr::f64_const(F64(0.0)))
      }
    RefTypeValType(rt) if rt.is_nullable() =>
      Some(TInstr::ref_null(rt.get_heap_type()))
    _ => None
  }
}

///|
fn ssa_nomerge_apply_rewrites(
  body : TExpr,
  get_rewrites : Map[Int, SSANoMergeGetRewrite],
  set_rewrites : Map[Int, LocalIdx],
) -> (TExpr, Bool) {
  if get_rewrites.is_empty() && set_rewrites.is_empty() {
    return (body, false)
  }
  let get_id = Ref::new(0)
  let set_id = Ref::new(0)
  let changed = Ref::new(false)
  let walker : ModuleTransformer[Unit, String] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      instr : TInstr,
    ) {
      match instr.kind {
        TInstrKind::TLocalGet(curr_idx) => {
          let id = get_id.val
          get_id.update(fn(n) { n + 1 })
          match get_rewrites.get(id) {
            Some(SSANoMergeGetRewrite::Local(next_idx)) if next_idx != curr_idx => {
              changed.update(fn(_) { true })
              change((), TInstr::local_get(next_idx))
            }
            Some(SSANoMergeGetRewrite::ConstInstr(replacement)) => {
              changed.update(fn(_) { true })
              change((), replacement)
            }
            _ => unchanged()
          }
        }
        TInstrKind::TLocalTee(curr_idx, value) => {
          let next_value = match self.walk_tinstruction((), value) {
            Ok((next_value, _)) => next_value
            Err(e) => return error(e)
          }
          let id = set_id.val
          set_id.update(fn(n) { n + 1 })
          let next_idx = set_rewrites.get(id).unwrap_or(curr_idx)
          if next_idx != curr_idx || next_value != value {
            changed.update(fn(_) { true })
          }
          // We've already walked `value`; returning `unchanged()` here would
          // make the transformer descend into it a second time and skew the
          // analysis-vs-rewrite get/set numbering.
          change((), TInstr::local_tee(next_idx, next_value))
        }
        TInstrKind::TLocalSet(curr_idx, value) => {
          let next_value = match self.walk_tinstruction((), value) {
            Ok((next_value, _)) => next_value
            Err(e) => return error(e)
          }
          let id = set_id.val
          set_id.update(fn(n) { n + 1 })
          let next_idx = set_rewrites.get(id).unwrap_or(curr_idx)
          if next_idx != curr_idx || next_value != value {
            changed.update(fn(_) { true })
          }
          // Avoid a second walk of `value`; see the tee case above.
          change((), TInstr::local_set(next_idx, next_value))
        }
        _ => from_walk(self.walk_tinstruction_default((), instr))
      }
    },
  )
  match walker.walk_texpr((), body) {
    Ok((out, _)) => (out, changed.val)
    Err(_) => (body, false)
  }
}

///|
fn ssa_nomerge_tfunc(
  params : Array[ValType],
  locals : Locals,
  body : TExpr,
) -> (Locals, TExpr, Bool) {
  let function_locals = FunctionLocals::new(params, locals)
  let all_locals = function_locals.all_locals()
  let analysis = ssa_nomerge_build_analysis(body)
  let local_set_counts : Map[LocalIdx, Int] = Map::new()
  for node in analysis.set_nodes {
    local_set_counts[node.idx] = local_set_counts.get(node.idx).unwrap_or(0) + 1
  }
  let next_body_locals = locals.copy()
  let get_rewrites = Map::new()
  let set_rewrites = Map::new()
  let next_all_locals = all_locals.copy()
  for set_id in 0..<analysis.set_nodes.length() {
    let node = analysis.set_nodes[set_id]
    if local_set_counts.get(node.idx).unwrap_or(0) <= 1 {
      continue
    }
    let influenced_gets = analysis.set_influences[set_id]
    if influenced_gets.is_empty() {
      continue
    }
    let mut can_rename = true
    for get_id in influenced_gets {
      if analysis.get_reaches[get_id] != SSANoMergeReachState::SetOnly(set_id) {
        can_rename = false
        break
      }
    }
    if !can_rename {
      continue
    }
    let local_ty = match function_locals.local_type(node.idx) {
      Some(vt) => vt
      None => continue
    }
    let next_idx = LocalIdx::new(next_all_locals.length().reinterpret_as_uint())
    next_all_locals.push(local_ty)
    next_body_locals.push(local_ty)
    set_rewrites[set_id] = next_idx
    for get_id in influenced_gets {
      get_rewrites[get_id] = SSANoMergeGetRewrite::Local(next_idx)
    }
  }
  for get_id in 0..<analysis.get_reaches.length() {
    if get_rewrites.get(get_id) is Some(_) {
      continue
    }
    if analysis.get_reaches[get_id] != SSANoMergeReachState::InitOnly {
      continue
    }
    let get_node = analysis.get_nodes[get_id]
    if ssa_nomerge_local_idx_to_int(get_node.idx) < params.length() {
      continue
    }
    match function_locals.local_type(get_node.idx) {
      Some(vt) =>
        match ssa_nomerge_default_constant(vt) {
          Some(constant) =>
            get_rewrites[get_id] = SSANoMergeGetRewrite::ConstInstr(constant)
          None => ()
        }
      None => ()
    }
  }
  let (next_body, changed) = ssa_nomerge_apply_rewrites(
    body, get_rewrites, set_rewrites,
  )
  (next_body_locals, next_body, changed || next_body_locals != locals)
}

///|
fn dataflow_instrs_have_parametric_blocktypes(
  instrs : Array[Instruction],
  env : Env,
) -> Bool {
  for instr in instrs {
    if dataflow_instr_has_parametric_blocktype(instr, env) {
      return true
    }
  }
  false
}

///|
fn dataflow_instr_has_parametric_blocktype(
  instr : Instruction,
  env : Env,
) -> Bool {
  match instr {
    Block(bt, Expr(body)) | Loop(bt, Expr(body)) =>
      match env.expand_blocktype(bt) {
        Ok((params, _)) =>
          !params.is_empty() ||
          dataflow_instrs_have_parametric_blocktypes(body, env)
        Err(_) => dataflow_instrs_have_parametric_blocktypes(body, env)
      }
    If(bt, then_body, else_body_opt) => {
      let has_param_input = match env.expand_blocktype(bt) {
        Ok((params, _)) => !params.is_empty()
        Err(_) => false
      }
      if has_param_input {
        return true
      }
      if dataflow_instrs_have_parametric_blocktypes(then_body, env) {
        return true
      }
      match else_body_opt {
        Some(else_body) =>
          dataflow_instrs_have_parametric_blocktypes(else_body, env)
        None => false
      }
    }
    TryTable(bt, _, Expr(body)) =>
      match env.expand_blocktype(bt) {
        Ok((params, _)) =>
          !params.is_empty() ||
          dataflow_instrs_have_parametric_blocktypes(body, env)
        Err(_) => dataflow_instrs_have_parametric_blocktypes(body, env)
      }
    _ => false
  }
}

///|
fn dataflow_normalize_func_to_tfunc(
  env : Env,
  abs_idx : Int,
  func : Func,
) -> Result[DataflowNormalizedFunc, String] {
  let func_idx = FuncIdx::new(abs_idx.reinterpret_as_uint())
  let (params, results) = match env.get_functype_by_funcidx(func_idx) {
    Some(FuncType(ps, rs)) => (ps, rs)
    None => ([], [])
  }
  match func {
    TFunc(tfunc_params, locals, body) =>
      match
        FunctionLocals::from_typed_func_for_pass(params, tfunc_params, locals) {
        Ok(function_locals) =>
          Ok(
            DataflowNormalizedFunc::TFuncBody(
              function_locals.params(),
              function_locals.body_locals(),
              body,
            ),
          )
        Err(e) =>
          Err(
            "dataflow_optimization_pass: malformed typed function locals for function \{abs_idx}: \{e}",
          )
      }
    Func(grouped_locals, expr_body) =>
      match FunctionLocals::from_local_decls(params, grouped_locals) {
        Ok(function_locals) => {
          let locals = function_locals.body_locals()
          let all_locals = function_locals.all_locals()
          let func_env = env
            .with_locals(all_locals)
            .with_labels([results])
            .with_return_type(Some(results))
          let Expr(body_instrs) = expr_body
          if dataflow_instrs_have_parametric_blocktypes(body_instrs, func_env) {
            return Ok(
              DataflowNormalizedFunc::PlainFunc(
                Func::new(grouped_locals, Expr::new(body_instrs)),
              ),
            )
          }
          match to_texpr(expr_body, func_env) {
            Ok(body) =>
              Ok(DataflowNormalizedFunc::TFuncBody(params, locals, body))
            Err(_) =>
              Ok(
                DataflowNormalizedFunc::PlainFunc(
                  Func::new(grouped_locals, expr_body),
                ),
              )
          }
        }
        Err(e) =>
          Err(
            "dataflow_optimization_pass: expand_locals failed for function \{abs_idx}: \{e}",
          )
      }
  }
}

///|
fn dataflow_count_imported_funcs(mod : Module) -> Int {
  let mut n = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, FuncExternType(_)) => n += 1
          _ => ()
        }
      }
    None => ()
  }
  n
}

///|
fn dataflow_now_ms() -> UInt64 {
  pass_trace_now_ms()
}

///|
fn dataflow_elapsed_ms(start_ms : UInt64) -> UInt64 {
  pass_trace_elapsed_ms(start_ms)
}

///|
fn ssa_nomerge_pass(
  mod : Module,
  trace? : (String) -> Unit = fn(_) { () },
  trace_all_funcs? : Bool = false,
) -> ModuleTransformer[Unit, String] {
  let env = Env::new().with_module(mod)
  let imported_funcs = dataflow_count_imported_funcs(mod)
  let mut seen_funcs = 0
  ModuleTransformer::new().on_func_evt(fn(
    _self : ModuleTransformer[Unit, String],
    _ctx : Unit,
    func : Func,
  ) -> VisitAction[Unit, Func, String] {
    seen_funcs += 1
    let ordinal = seen_funcs
    let log_func = pass_trace_log_enabled(ordinal, trace_all_funcs)
    let abs_idx = imported_funcs + ordinal - 1
    let was_plain_func = func is Func(_, _)
    let normalized = match
      dataflow_normalize_func_to_tfunc(env, abs_idx, func) {
      Ok(out) => out
      Err(e) => return error(e)
    }
    let (params, locals, body) = match normalized {
      DataflowNormalizedFunc::TFuncBody(params, locals, body) =>
        (params, locals, body)
      DataflowNormalizedFunc::PlainFunc(next_func) => {
        if log_func {
          trace("func[\{ordinal}] skip reason=non_liftable_expr")
        }
        return change((), next_func)
      }
    }
    if log_func {
      trace(
        "func[\{ordinal}] start locals=\{locals.length()} top_instrs=\{body.instrs.length()}",
      )
      if was_plain_func {
        trace("func[\{ordinal}] normalized_from=Func")
      }
    }
    let pass_start = dataflow_now_ms()
    let (next_locals, next_body, changed) = ssa_nomerge_tfunc(
      params, locals, body,
    )
    let elapsed = dataflow_elapsed_ms(pass_start)
    if log_func {
      trace(
        "func[\{ordinal}] done elapsed_ms=\{elapsed} changed=\{changed} locals=\{locals.length()}->\{next_locals.length()}",
      )
    }
    change((), Func::t_func(params, next_locals, next_body))
  })
}

///|
fn dataflow_optimization_pass(
  mod : Module,
  trace? : (String) -> Unit = fn(_) { () },
  trace_all_funcs? : Bool = false,
) -> ModuleTransformer[IRContext, String] {
  let env = Env::new().with_module(mod)
  let imported_funcs = dataflow_count_imported_funcs(mod)
  let mut seen_funcs = 0
  ModuleTransformer::new().on_func_evt(fn(
    _self : ModuleTransformer[IRContext, String],
    ctx : IRContext,
    func : Func,
  ) -> VisitAction[IRContext, Func, String] {
    seen_funcs += 1
    let ordinal = seen_funcs
    let log_func = pass_trace_log_enabled(ordinal, trace_all_funcs)
    let abs_idx = imported_funcs + ordinal - 1
    let was_plain_func = func is Func(_, _)
    let normalized = match
      dataflow_normalize_func_to_tfunc(env, abs_idx, func) {
      Ok(out) => out
      Err(e) => return error(e)
    }
    let (params, locals, body) = match normalized {
      DataflowNormalizedFunc::TFuncBody(params, locals, body) =>
        (params, locals, body)
      DataflowNormalizedFunc::PlainFunc(next_func) => {
        if log_func {
          trace("func[\{ordinal}] skip reason=non_liftable_expr")
        }
        return change(ctx, next_func)
      }
    }
    if log_func {
      trace(
        "func[\{ordinal}] start locals=\{locals.length()} top_instrs=\{body.instrs.length()}",
      )
      if was_plain_func {
        trace("func[\{ordinal}] normalized_from=Func")
      }
    }
    let opt_start = dataflow_now_ms()
    let new_func = optimize_tfunc_with_ssa(ctx, mod, params, locals, body, trace=fn(
      msg,
    ) {
      if log_func {
        trace("func[\{ordinal}] \{msg}")
      }
    })
    let elapsed = dataflow_elapsed_ms(opt_start)
    if log_func {
      trace(
        "func[\{ordinal}] done elapsed_ms=\{elapsed} lowered=\{new_func is Some(_)}",
      )
    }
    match new_func {
      Some((next_locals, next_body)) =>
        change(ctx, Func::t_func(params, next_locals, next_body))
      // Returning `unchanged()` here would trigger `walk_func_default`,
      // causing a second full traversal of this function.
      _ => change(ctx, Func::t_func(params, locals, body))
    }
  })
}

///|
test "dataflow optimization pass folds simple constants via SSA" {
  let body = TExpr::new([
    TInstr::local_set(
      LocalIdx::new(0),
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::i32_const(I32(40)),
        TInstr::i32_const(I32(2)),
      ),
    ),
    TInstr::return_([TInstr::local_get(LocalIdx::new(0))]),
  ])
  let func = Func::t_func([], Locals::from_types([ValType::i32()]), body)
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let pass = dataflow_optimization_pass(mod)
  let ctx = IRContext::new()
  let result = pass.walk_module(ctx, mod)
  match result {
    Ok((new_mod, _)) => assert_true(new_mod.code_sec is Some(_))
    Err(e) => fail("Unexpected error: \{e}")
  }
}

///|
test "dataflow optimization pass simplifies const multi-block if" {
  let body = TExpr::new([
    TInstr::if_(
      BlockType::void_(),
      TInstr::i32_const(I32(1)),
      TExpr::new([TInstr::return_([TInstr::i32_const(I32(7))])]),
      Some(TExpr::new([TInstr::return_([TInstr::i32_const(I32(9))])])),
    ),
  ])
  let func = Func::t_func([], Locals::empty(), body)
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let pass = dataflow_optimization_pass(mod)
  let ctx = IRContext::new()
  let result = pass.walk_module(ctx, mod)
  match result {
    Ok((new_mod, _)) => assert_true(new_mod.code_sec is Some(_))
    Err(e) => fail("Unexpected error: \{e}")
  }
}

///|
test "dataflow optimization pass normalizes non-texpr Func bodies" {
  let func_type = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([func_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([Func::new(Locals::empty(), Expr::new([Instruction::nop()]))]),
    )
  let pass = dataflow_optimization_pass(mod)
  let ctx = IRContext::new()
  let result = pass.walk_module(ctx, mod)
  match result {
    Ok((out, _)) =>
      match out.code_sec {
        Some(CodeSec([TFunc(_, _, _)])) => ()
        _ => fail("expected dataflow to rewrite Func input into TFunc")
      }
    Err(e) => fail("Unexpected error: \{e}")
  }
}

///|
test "dataflow optimization pass skips non-liftable Func bodies without failing" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::new(Locals::empty(), Expr::new([Instruction::i32_add()])),
    ]),
  )
  let pass = dataflow_optimization_pass(mod)
  let ctx = IRContext::new()
  let result = pass.walk_module(ctx, mod)
  match result {
    Ok((out, _)) =>
      match out.code_sec {
        Some(CodeSec([Func(_, _)])) => ()
        _ => fail("expected non-liftable Func to remain unchanged")
      }
    Err(e) => fail("Unexpected error: \{e}")
  }
}

///|
test "dataflow optimization preserves valid locals for parameterized functions" {
  let func_type = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
  )
  let body = TExpr::new([
    TInstr::if_(
      BlockType::void_(),
      TInstr::local_get(LocalIdx::new(0)),
      TExpr::new([
        TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(11))),
      ]),
      Some(
        TExpr::new([
          TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(22))),
        ]),
      ),
    ),
    TInstr::return_([TInstr::local_get(LocalIdx::new(1))]),
  ])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([func_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], Locals::from_types([ValType::i32()]), body),
      ]),
    )
  let pass = dataflow_optimization_pass(mod)
  let ctx = IRContext::new()
  let result = pass.walk_module(ctx, mod)
  match result {
    Ok((out, _)) => {
      assert_eq(validate_module(out), Ok(()))
      assert_true(out.code_sec is Some(_))
    }
    Err(e) => fail("Unexpected error: \{e}")
  }
}

///|
test "ssa no-merge renames single-reaching sets without merge gets" {
  let body = TExpr::new([
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(1))),
    TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(2))),
    TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
  ])
  let func = Func::t_func([], Locals::from_types([ValType::i32()]), body)
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let pass = ssa_nomerge_pass(mod)
  let result = pass.walk_module((), mod)
  match result {
    Ok((out, _)) =>
      match out.code_sec {
        Some(CodeSec([TFunc(_, locals, out_body)])) => {
          assert_eq(locals.length(), 3)
          match out_body.instrs {
            [
              { kind: TInstrKind::TLocalSet(idx0, _), .. },
              {
                kind: TInstrKind::TDrop(
                  { kind: TInstrKind::TLocalGet(get0), .. }
                ),
                ..,
              },
              { kind: TInstrKind::TLocalSet(idx1, _), .. },
              {
                kind: TInstrKind::TDrop(
                  { kind: TInstrKind::TLocalGet(get1), .. }
                ),
                ..,
              },
            ] => {
              assert_true(idx0 != LocalIdx::new(0))
              assert_true(idx1 != LocalIdx::new(0))
              assert_eq(get0, idx0)
              assert_eq(get1, idx1)
            }
            _ => fail("expected rewritten local set/get pairs")
          }
        }
        _ => fail("expected typed function after ssa no-merge")
      }
    Err(e) => fail("Unexpected error: \{e}")
  }
}

///|
test "ssa no-merge preserves merge-reaching gets" {
  let body = TExpr::new([
    TInstr::if_(
      BlockType::void_(),
      TInstr::i32_const(I32(1)),
      TExpr::new([
        TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(11))),
      ]),
      Some(
        TExpr::new([
          TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(22))),
        ]),
      ),
    ),
    TInstr::return_([TInstr::local_get(LocalIdx::new(0))]),
  ])
  let func = Func::t_func([], Locals::from_types([ValType::i32()]), body)
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let pass = ssa_nomerge_pass(mod)
  let result = pass.walk_module((), mod)
  match result {
    Ok((out, _)) =>
      match out.code_sec {
        Some(CodeSec([TFunc(_, locals, out_body)])) => {
          assert_eq(locals.length(), 1)
          match out_body.instrs[out_body.instrs.length() - 1].kind {
            TInstrKind::TReturn([{ kind: TInstrKind::TLocalGet(idx), .. }]) =>
              assert_eq(idx, LocalIdx::new(0))
            _ =>
              fail(
                "expected merged return local.get to remain on the original local",
              )
          }
        }
        _ => fail("expected typed function after ssa no-merge")
      }
    Err(e) => fail("Unexpected error: \{e}")
  }
}

///|
test "ssa no-merge preserves loop-carried gets" {
  let body = TExpr::new([
    TInstr::loop_(
      BlockType::void_(),
      TExpr::new([
        TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
        TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(1))),
        TInstr::br(LabelIdx::new(0), []),
      ]),
    ),
  ])
  let func = Func::t_func([], Locals::from_types([ValType::i32()]), body)
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let pass = ssa_nomerge_pass(mod)
  let result = pass.walk_module((), mod)
  match result {
    Ok((out, _)) =>
      match out.code_sec {
        Some(CodeSec([TFunc(_, _, out_body)])) =>
          match out_body.instrs {
            [
              {
                kind: TInstrKind::TLoop(
                  _,
                  {
                    instrs: [
                      {
                        kind: TInstrKind::TDrop(
                          { kind: TInstrKind::TLocalGet(idx), .. }
                        ),
                        ..,
                      },
                      ..,
                    ],
                    ..,
                  }
                ),
                ..,
              },
            ] => assert_eq(idx, LocalIdx::new(0))
            _ => fail("expected loop-carried local.get to remain unchanged")
          }
        _ => fail("expected typed function after ssa no-merge")
      }
    Err(e) => fail("Unexpected error: \{e}")
  }
}

///|
test "ssa no-merge analysis summarizes branch-heavy reaching states" {
  let instrs : Array[TInstr] = []
  for i in 0..<32 {
    instrs.push(TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(i))))
    instrs.push(TInstr::drop(TInstr::local_get(LocalIdx::new(0))))
    instrs.push(
      TInstr::if_(
        BlockType::void_(),
        TInstr::i32_const(I32(1)),
        TExpr::new([
          TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(i + 1))),
        ]),
        Some(
          TExpr::new([
            TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(i + 101))),
          ]),
        ),
      ),
    )
    instrs.push(TInstr::drop(TInstr::local_get(LocalIdx::new(0))))
  }
  let summary = ssa_nomerge_analysis_state_counts(TExpr::new(instrs))
  assert_eq(summary.single_set_gets, 32)
  assert_eq(summary.multi_reaching_gets, 32)
  assert_eq(summary.init_only_gets, 0)
}

///|
test "ssa no-merge preserves externref table-set values across control-flow rewrites" {
  let memarg0 = MemArg::new(U32(0), None, U64(0))
  let memarg4 = MemArg::new(U32(0), None, U64(4))
  let memarg8 = MemArg::new(U32(0), None, U64(8))
  let externref = ValType::externref()
  let i32_i32 = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
  )
  let externref_i32 = RecType::new(
    SubType::comp_type(CompType::func([externref], [ValType::i32()])),
  )
  let malloc = Func::t_func(
    [ValType::i32()],
    Locals::empty(),
    TExpr::new([TInstr::local_get(LocalIdx::new(0))]),
  )
  let gc_malloc = Func::t_func(
    [ValType::i32()],
    Locals::empty(),
    TExpr::new([TInstr::local_get(LocalIdx::new(0))]),
  )
  let alloc_body = TExpr::new([
    TInstr::if_(
      BlockType::void_(),
      TInstr::binary(
        BinaryOp::i32_lt_s(),
        TInstr::local_tee(
          LocalIdx::new(1),
          TInstr::global_get(GlobalIdx::new(0)),
        ),
        TInstr::i32_const(I32(0)),
      ),
      TExpr::new([
        TInstr::local_set(
          LocalIdx::new(3),
          TInstr::table_size(TableIdx::new(0)),
        ),
        TInstr::local_set(
          LocalIdx::new(5),
          TInstr::if_(
            BlockType::val_type(ValType::i32()),
            TInstr::unary(
              UnaryOp::i32_eqz(),
              TInstr::local_get(LocalIdx::new(3)),
            ),
            TExpr::new([TInstr::i32_const(I32(16))]),
            Some(
              TExpr::new([
                TInstr::binary(
                  BinaryOp::i32_shl(),
                  TInstr::local_get(LocalIdx::new(3)),
                  TInstr::i32_const(I32(1)),
                ),
              ]),
            ),
          ),
        ),
        TInstr::if_(
          BlockType::void_(),
          TInstr::binary(
            BinaryOp::i32_lt_s(),
            TInstr::table_grow(
              TableIdx::new(0),
              TInstr::ref_null(HeapType::abs(AbsHeapType::extern_())),
              TInstr::local_get(LocalIdx::new(5)),
            ),
            TInstr::i32_const(I32(0)),
          ),
          TExpr::new([TInstr::unreachable_()]),
          None,
        ),
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::binary(
                BinaryOp::i32_gt_s(),
                TInstr::local_get(LocalIdx::new(5)),
                TInstr::local_get(LocalIdx::new(3)),
              ),
              TExpr::new([
                TInstr::local_set(
                  LocalIdx::new(5),
                  TInstr::binary(
                    BinaryOp::i32_sub(),
                    TInstr::local_get(LocalIdx::new(5)),
                    TInstr::i32_const(I32(1)),
                  ),
                ),
                TInstr::store(
                  StoreOp::i32_store(),
                  memarg0,
                  TInstr::local_tee(
                    LocalIdx::new(2),
                    TInstr::call(FuncIdx::new(0), [TInstr::i32_const(I32(8))]),
                  ),
                  TInstr::local_get(LocalIdx::new(5)),
                ),
                TInstr::store(
                  StoreOp::i32_store(),
                  memarg4,
                  TInstr::local_get(LocalIdx::new(2)),
                  TInstr::local_get(LocalIdx::new(1)),
                ),
                TInstr::local_set(
                  LocalIdx::new(1),
                  TInstr::local_get(LocalIdx::new(2)),
                ),
                TInstr::br(LabelIdx::new(1), []),
              ]),
              None,
            ),
          ]),
        ),
      ]),
      None,
    ),
    TInstr::global_set(
      GlobalIdx::new(0),
      TInstr::load(
        LoadOp::i32_load(),
        memarg4,
        TInstr::local_get(LocalIdx::new(1)),
      ),
    ),
    TInstr::local_set(
      LocalIdx::new(3),
      TInstr::load(
        LoadOp::i32_load(),
        memarg0,
        TInstr::local_get(LocalIdx::new(1)),
      ),
    ),
    TInstr::table_set(
      TableIdx::new(0),
      TInstr::local_get(LocalIdx::new(3)),
      TInstr::local_get(LocalIdx::new(0)),
    ),
    TInstr::store(
      StoreOp::i32_store(),
      memarg4,
      TInstr::local_tee(
        LocalIdx::new(4),
        TInstr::call(FuncIdx::new(1), [TInstr::i32_const(I32(4))]),
      ),
      TInstr::binary(
        BinaryOp::i32_shl(),
        TInstr::i32_const(I32(3)),
        TInstr::i32_const(I32(30)),
      ),
    ),
    TInstr::store(
      StoreOp::i32_store(),
      memarg8,
      TInstr::local_get(LocalIdx::new(4)),
      TInstr::local_get(LocalIdx::new(3)),
    ),
    TInstr::local_get(LocalIdx::new(4)),
  ])
  let alloc_externref = Func::t_func(
    [externref],
    Locals::from_types([
      ValType::i32(),
      ValType::i32(),
      ValType::i32(),
      ValType::i32(),
      ValType::i32(),
    ]),
    alloc_body,
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([i32_i32, i32_i32, externref_i32]))
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(1), TypeIdx::new(2)]),
    )
    .with_mem_sec(MemSec::new([MemType::new(Limits::i32(1, None))]))
    .with_table_sec(
      TableSec::new([
        Table::new(
          TableType::new(
            RefType::new(true, HeapType::abs(AbsHeapType::extern_())),
            Limits::i32(1, None),
          ),
          None,
        ),
      ]),
    )
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::i32(), true),
          TExpr::new([TInstr::i32_const(I32(-1))]).to_expr(),
        ),
      ]),
    )
    .with_code_sec(CodeSec::new([malloc, gc_malloc, alloc_externref]))
  let pass = ssa_nomerge_pass(mod)
  let result = pass.walk_module((), mod)
  match result {
    Ok((out, _)) => {
      assert_eq(validate_module(out), Ok(()))
      match out.code_sec {
        Some(CodeSec([_, _, TFunc(_, _, body)])) => {
          let mut found = false
          for instr in body.instrs {
            match instr.kind {
              TInstrKind::TTableSet(
                _,
                { kind: TInstrKind::TLocalGet(_), .. },
                { kind: TInstrKind::TLocalGet(ref_idx), .. }
              ) => {
                found = true
                assert_eq(ref_idx, LocalIdx::new(0))
              }
              _ => ()
            }
          }
          assert_true(found)
        }
        _ => fail("expected three typed functions after ssa no-merge")
      }
    }
    Err(e) => fail("Unexpected error: \{e}")
  }
}
