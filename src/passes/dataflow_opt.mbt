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
  locals : Array[ValType],
  body : TExpr,
  trace? : (String) -> Unit = fn(_) { () },
) -> (Array[ValType], TExpr)? {
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
priv enum SSANoMergeSetRef {
  InitValue
  Set(Int)
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
type SSANoMergeFlowState = Map[LocalIdx, Set[SSANoMergeSetRef]]

///|
priv struct SSANoMergeAnalyzeState {
  mut next_get_id : Int
  mut next_set_id : Int
  get_sets : Map[Int, Set[SSANoMergeSetRef]]
  get_nodes : Map[Int, SSANoMergeGetNode]
  set_nodes : Map[Int, SSANoMergeSetNode]
}

///|
priv struct SSANoMergeAnalysis {
  get_sets : Map[Int, Set[SSANoMergeSetRef]]
  get_nodes : Map[Int, SSANoMergeGetNode]
  set_nodes : Map[Int, SSANoMergeSetNode]
  set_influences : Map[Int, Array[Int]]
  get_count : Int
  set_count : Int
}

///|
priv enum SSANoMergeGetRewrite {
  Local(LocalIdx)
  ConstInstr(TInstr)
}

///|
priv enum DataflowNormalizedFunc {
  TFuncBody(Array[ValType], Array[ValType], TExpr)
  PlainFunc(Func)
}

///|
fn ssa_nomerge_copy_set(src : Set[SSANoMergeSetRef]) -> Set[SSANoMergeSetRef] {
  let out = Set::new()
  for item in src {
    out.add(item)
  }
  out
}

///|
fn ssa_nomerge_default_reaching() -> Set[SSANoMergeSetRef] {
  let out = Set::new()
  out.add(SSANoMergeSetRef::InitValue)
  out
}

///|
fn ssa_nomerge_get_reaching(
  flow : SSANoMergeFlowState,
  idx : LocalIdx,
) -> Set[SSANoMergeSetRef] {
  match flow.get(idx) {
    Some(sets) => ssa_nomerge_copy_set(sets)
    None => ssa_nomerge_default_reaching()
  }
}

///|
fn ssa_nomerge_copy_flow_state(
  flow : SSANoMergeFlowState,
) -> SSANoMergeFlowState {
  let out = Map::new()
  for entry in flow {
    let (idx, sets) = entry
    out[idx] = ssa_nomerge_copy_set(sets)
  }
  out
}

///|
fn ssa_nomerge_merge_flow_states(
  a : SSANoMergeFlowState,
  b : SSANoMergeFlowState,
) -> SSANoMergeFlowState {
  let out = ssa_nomerge_copy_flow_state(a)
  for entry in b {
    let (idx, sets) = entry
    let merged = out.get(idx).unwrap_or(Set::new())
    for set_ in sets {
      merged.add(set_)
    }
    out[idx] = merged
  }
  out
}

///|
fn ssa_nomerge_analyze_texpr(
  expr : TExpr,
  in_flow : SSANoMergeFlowState,
  state : SSANoMergeAnalyzeState,
) -> SSANoMergeFlowState {
  let mut flow = in_flow
  for instr in expr.instrs {
    flow = ssa_nomerge_analyze_tinstruction(instr, flow, state)
  }
  flow
}

///|
fn ssa_nomerge_analyze_tinstruction(
  instr : TInstr,
  in_flow : SSANoMergeFlowState,
  state : SSANoMergeAnalyzeState,
) -> SSANoMergeFlowState {
  match instr.kind {
    TInstrKind::TLocalGet(idx) => {
      let get_id = state.next_get_id
      state.next_get_id = get_id + 1
      state.get_nodes[get_id] = SSANoMergeGetNode::{ idx, }
      state.get_sets[get_id] = ssa_nomerge_get_reaching(in_flow, idx)
      in_flow
    }
    TInstrKind::TLocalTee(idx, value) => {
      let out_flow = ssa_nomerge_analyze_tinstruction(value, in_flow, state)
      let set_id = state.next_set_id
      state.next_set_id = set_id + 1
      state.set_nodes[set_id] = SSANoMergeSetNode::{ idx, }
      let reaching = Set::new()
      reaching.add(SSANoMergeSetRef::Set(set_id))
      out_flow[idx] = reaching
      out_flow
    }
    TInstrKind::TLocalSet(idx, value) => {
      let out_flow = ssa_nomerge_analyze_tinstruction(value, in_flow, state)
      let set_id = state.next_set_id
      state.next_set_id = set_id + 1
      state.set_nodes[set_id] = SSANoMergeSetNode::{ idx, }
      let reaching = Set::new()
      reaching.add(SSANoMergeSetRef::Set(set_id))
      out_flow[idx] = reaching
      out_flow
    }
    TInstrKind::TIf(_, cond, then_, else_) => {
      let flow_after_cond = ssa_nomerge_analyze_tinstruction(
        cond, in_flow, state,
      )
      let then_flow = ssa_nomerge_analyze_texpr(
        then_,
        ssa_nomerge_copy_flow_state(flow_after_cond),
        state,
      )
      let else_flow = match else_ {
        Some(else_expr) =>
          ssa_nomerge_analyze_texpr(
            else_expr,
            ssa_nomerge_copy_flow_state(flow_after_cond),
            state,
          )
        None => ssa_nomerge_copy_flow_state(flow_after_cond)
      }
      ssa_nomerge_merge_flow_states(then_flow, else_flow)
    }
    TInstrKind::TBlock(_, body) =>
      ssa_nomerge_analyze_texpr(body, in_flow, state)
    TInstrKind::TLoop(_, body) => {
      let one_iter = ssa_nomerge_analyze_texpr(
        body,
        ssa_nomerge_copy_flow_state(in_flow),
        state,
      )
      ssa_nomerge_merge_flow_states(in_flow, one_iter)
    }
    TInstrKind::TTryTable(_, _, body) => {
      let body_flow = ssa_nomerge_analyze_texpr(
        body,
        ssa_nomerge_copy_flow_state(in_flow),
        state,
      )
      ssa_nomerge_merge_flow_states(in_flow, body_flow)
    }
    _ => {
      let mut flow = in_flow
      for child in eval_children(instr) {
        flow = ssa_nomerge_analyze_tinstruction(child, flow, state)
      }
      flow
    }
  }
}

///|
fn ssa_nomerge_build_analysis(body : TExpr) -> SSANoMergeAnalysis {
  let state = SSANoMergeAnalyzeState::{
    next_get_id: 0,
    next_set_id: 0,
    get_sets: Map::new(),
    get_nodes: Map::new(),
    set_nodes: Map::new(),
  }
  ignore(ssa_nomerge_analyze_texpr(body, Map::new(), state))
  let set_influences = Map::new()
  for get_id in 0..<state.next_get_id {
    let sets = state.get_sets.get(get_id).unwrap_or(Set::new())
    for set_ref in sets {
      match set_ref {
        SSANoMergeSetRef::Set(set_id) => {
          let arr = set_influences.get(set_id).unwrap_or([])
          arr.push(get_id)
          set_influences[set_id] = arr
        }
        SSANoMergeSetRef::InitValue => ()
      }
    }
  }
  {
    get_sets: state.get_sets,
    get_nodes: state.get_nodes,
    set_nodes: state.set_nodes,
    set_influences,
    get_count: state.next_get_id,
    set_count: state.next_set_id,
  }
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
            change((), TInstr::local_tee(next_idx, next_value))
          } else {
            unchanged()
          }
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
            change((), TInstr::local_set(next_idx, next_value))
          } else {
            unchanged()
          }
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
  locals : Array[ValType],
  body : TExpr,
) -> (Array[ValType], TExpr, Bool) {
  let function_locals = FunctionLocals::new(params, locals)
  let all_locals = function_locals.all_locals()
  let analysis = ssa_nomerge_build_analysis(body)
  let local_set_counts : Map[LocalIdx, Int] = Map::new()
  for set_id in 0..<analysis.set_count {
    match analysis.set_nodes.get(set_id) {
      Some(node) =>
        local_set_counts[node.idx] = local_set_counts.get(node.idx).unwrap_or(0) +
          1
      None => ()
    }
  }
  let next_body_locals = locals.copy()
  let get_rewrites = Map::new()
  let set_rewrites = Map::new()
  let next_all_locals = all_locals.copy()
  for set_id in 0..<analysis.set_count {
    let node = match analysis.set_nodes.get(set_id) {
      Some(node) => node
      None => continue
    }
    if local_set_counts.get(node.idx).unwrap_or(0) <= 1 {
      continue
    }
    let influenced_gets = analysis.set_influences.get(set_id).unwrap_or([])
    if influenced_gets.is_empty() {
      continue
    }
    let mut can_rename = true
    for get_id in influenced_gets {
      let sets = analysis.get_sets.get(get_id).unwrap_or(Set::new())
      if sets.length() != 1 || !sets.contains(SSANoMergeSetRef::Set(set_id)) {
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
  for get_id in 0..<analysis.get_count {
    if get_rewrites.get(get_id) is Some(_) {
      continue
    }
    let sets = analysis.get_sets.get(get_id).unwrap_or(Set::new())
    if sets.length() != 1 || !sets.contains(SSANoMergeSetRef::InitValue) {
      continue
    }
    let get_node = match analysis.get_nodes.get(get_id) {
      Some(node) => node
      None => continue
    }
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
  let func = Func::t_func([], [ValType::i32()], body)
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
  let func = Func::t_func([], [], body)
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
      CodeSec::new([Func::new([], Expr::new([Instruction::nop()]))]),
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
    CodeSec::new([Func::new([], Expr::new([Instruction::i32_add()]))]),
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
    .with_code_sec(CodeSec::new([Func::t_func([], [ValType::i32()], body)]))
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
  let func = Func::t_func([], [ValType::i32()], body)
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
  let func = Func::t_func([], [ValType::i32()], body)
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
