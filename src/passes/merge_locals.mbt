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
priv struct MLCopySite {
  copy_set_id : Int
  trivial_set_id : Int
  copy_idx : LocalIdx
  trivial_idx : LocalIdx
}

///|
priv enum MLSSetRef {
  InitValue
  Set(Int)
} derive(Eq, Hash)

///|
priv struct MLGetNode {
  idx : LocalIdx
}

///|
type MLFlowState = Map[LocalIdx, Set[MLSSetRef]]

///|
priv struct MLAnalyzeState {
  mut next_get_id : Int
  mut next_set_id : Int
  mut over_budget : Bool
  get_sets : Map[Int, Set[MLSSetRef]]
  get_nodes : Map[Int, MLGetNode]
  copies : Array[MLCopySite]
}

///|
priv struct MLRewriteRecord {
  copy_set_id : Int
  trivial_set_id : Int
  get_ids : Array[Int]
}

///|
priv struct MLLocalGraphSnapshot {
  aborted : Bool
  get_sets : Map[Int, Set[MLSSetRef]]
  mut set_influences : Map[Int, Array[Int]]
  get_nodes : Map[Int, MLGetNode]
  copies : Array[MLCopySite]
  get_count : Int
}

///|
fn ml_analysis_budget_limit() -> Int {
  16000
}

///|
fn ml_module_func_limit() -> Int {
  400
}

///|
fn ml_module_top_instr_limit() -> Int {
  50000
}

///|
fn ml_mark_over_budget_if_needed(state : MLAnalyzeState) -> Unit {
  if state.next_get_id + state.next_set_id > ml_analysis_budget_limit() {
    state.over_budget = true
  }
}

///|
fn ml_should_skip_module(mod : Module) -> Bool {
  match mod.code_sec {
    Some(CodeSec(funcs)) => {
      if funcs.length() > ml_module_func_limit() {
        return true
      }
      let mut top_instrs = 0
      for func in funcs {
        match func {
          TFunc(_, body) => {
            top_instrs += body.instrs.length()
            if top_instrs > ml_module_top_instr_limit() {
              return true
            }
          }
          _ => ()
        }
      }
      false
    }
    None => false
  }
}

///|
fn ml_local_idx_to_int(idx : LocalIdx) -> Int {
  let LocalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn ml_copy_set(src : Set[MLSSetRef]) -> Set[MLSSetRef] {
  let out = Set::new()
  for item in src {
    out.add(item)
  }
  out
}

///|
fn ml_default_reaching() -> Set[MLSSetRef] {
  let out = Set::new()
  out.add(MLSSetRef::InitValue)
  out
}

///|
fn ml_get_reaching(flow : MLFlowState, idx : LocalIdx) -> Set[MLSSetRef] {
  match flow.get(idx) {
    Some(sets) => ml_copy_set(sets)
    None => ml_default_reaching()
  }
}

///|
fn ml_copy_flow_state(flow : MLFlowState) -> MLFlowState {
  let out = Map::new()
  for entry in flow {
    let (idx, sets) = entry
    out[idx] = ml_copy_set(sets)
  }
  out
}

///|
fn ml_merge_flow_states(a : MLFlowState, b : MLFlowState) -> MLFlowState {
  let out = ml_copy_flow_state(a)
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
fn visit_local_set(curr : TInstr) -> (TInstr, Bool) {
  match curr.kind {
    TInstrKind::TLocalSet(dst, { kind: TInstrKind::TLocalGet(src), .. }) if dst !=
      src =>
      (
        TInstr::local_set(dst, TInstr::local_tee(src, TInstr::local_get(src))),
        true,
      )
    _ => (curr, false)
  }
}

///|
fn ml_instrument_copies(body : TExpr) -> (TExpr, Bool) {
  let changed = Ref::new(false)
  let transformer = ModuleTransformer::new().on_tinstruction_evt(fn(
    self,
    _,
    instr : TInstr,
  ) {
    match instr.kind {
      TInstrKind::TLocalSet(_, _) => {
        let (next, did_change) = visit_local_set(instr)
        if did_change {
          changed.update(fn(_) { true })
          change((), next)
        } else {
          self.walk_tinstruction_default((), instr)
        }
      }
      _ => self.walk_tinstruction_default((), instr)
    }
  })
  match transformer.walk_texpr((), body) {
    Ok(Some((_, out))) => (out, changed.val)
    Ok(None) => (body, changed.val)
    Err(_) => (body, false)
  }
}

///|
fn ml_eval_children(instr : TInstr) -> Array[TInstr] {
  match instr.kind {
    TInstrKind::TI32Const(_)
    | TInstrKind::TI64Const(_)
    | TInstrKind::TF32Const(_)
    | TInstrKind::TF64Const(_)
    | TInstrKind::TRefNull(_)
    | TInstrKind::TRefFunc(_)
    | TInstrKind::TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | TInstrKind::TUnreachable
    | TInstrKind::TNop
    | TInstrKind::TLocalGet(_)
    | TInstrKind::TGlobalGet(_)
    | TInstrKind::TMemorySize(_)
    | TInstrKind::TAtomicFence
    | TInstrKind::TTableSize(_)
    | TInstrKind::TDataDrop(_)
    | TInstrKind::TElemDrop(_)
    | TInstrKind::TStructNewDefault(_) => []
    TInstrKind::TUnary(_, child)
    | TInstrKind::TDrop(child)
    | TInstrKind::TLocalSet(_, child)
    | TInstrKind::TLocalTee(_, child)
    | TInstrKind::TGlobalSet(_, child)
    | TInstrKind::TRefIsNull(child)
    | TInstrKind::TRefAsNonNull(child)
    | TInstrKind::TI31GetS(child)
    | TInstrKind::TI31GetU(child)
    | TInstrKind::TRefI31(child)
    | TInstrKind::TArrayLen(child)
    | TInstrKind::TAnyConvertExtern(child)
    | TInstrKind::TExternConvertAny(child)
    | TInstrKind::TThrowRef(child)
    | TInstrKind::TMemoryGrow(_, child)
    | TInstrKind::TTableGet(_, child)
    | TInstrKind::TLoad(_, _, child)
    | TInstrKind::TArrayNewDefault(_, child)
    | TInstrKind::TStructGet(_, _, child)
    | TInstrKind::TStructGetS(_, _, child)
    | TInstrKind::TStructGetU(_, _, child)
    | TInstrKind::TI8x16Splat(child)
    | TInstrKind::TI16x8Splat(child)
    | TInstrKind::TI32x4Splat(child)
    | TInstrKind::TI64x2Splat(child)
    | TInstrKind::TF32x4Splat(child)
    | TInstrKind::TF64x2Splat(child)
    | TInstrKind::TExtractLane(_, _, child)
    | TInstrKind::TRefTest(_, _, child)
    | TInstrKind::TRefCast(_, _, child)
    | TInstrKind::TRefGetDesc(child)
    | TInstrKind::TRefTestDesc(_, _, child)
    | TInstrKind::TRefCastDescEq(_, _, child) => [child]
    TInstrKind::TBinary(_, left, right)
    | TInstrKind::TRefEq(left, right)
    | TInstrKind::TStore(_, _, left, right)
    | TInstrKind::TMemoryAtomicNotify(_, left, right)
    | TInstrKind::TAtomicRmw(_, _, left, right)
    | TInstrKind::TTableSet(_, left, right)
    | TInstrKind::TTableGrow(_, left, right)
    | TInstrKind::TStructSet(_, _, left, right)
    | TInstrKind::TArrayNew(_, left, right)
    | TInstrKind::TArrayNewData(_, _, left, right)
    | TInstrKind::TArrayNewElem(_, _, left, right)
    | TInstrKind::TArrayGet(_, left, right)
    | TInstrKind::TArrayGetS(_, left, right)
    | TInstrKind::TArrayGetU(_, left, right)
    | TInstrKind::TReplaceLane(_, _, left, right)
    | TInstrKind::TI8x16Swizzle(left, right)
    | TInstrKind::TI8x16RelaxedSwizzle(left, right)
    | TInstrKind::TV128Shift(_, left, right)
    | TInstrKind::TV128LoadLane(_, _, _, left, right)
    | TInstrKind::TV128StoreLane(_, _, _, left, right) => [left, right]
    TInstrKind::TMemoryFill(_, a, b, c)
    | TInstrKind::TMemoryCopy(_, _, a, b, c)
    | TInstrKind::TMemoryInit(_, _, a, b, c)
    | TInstrKind::TMemoryAtomicWait32(_, a, b, c)
    | TInstrKind::TMemoryAtomicWait64(_, a, b, c)
    | TInstrKind::TAtomicCmpxchg(_, _, a, b, c)
    | TInstrKind::TTableFill(_, a, b, c)
    | TInstrKind::TTableCopy(_, _, a, b, c)
    | TInstrKind::TTableInit(_, _, a, b, c)
    | TInstrKind::TSelect(_, c, a, b)
    | TInstrKind::TV128Ternary(_, a, b, c) => [a, b, c]
    TInstrKind::TCall(_, args)
    | TInstrKind::TReturnCall(_, args)
    | TInstrKind::TThrow(_, args)
    | TInstrKind::TBr(_, args)
    | TInstrKind::TReturn(args)
    | TInstrKind::TStructNew(_, args)
    | TInstrKind::TArrayNewFixed(_, args) => args.copy()
    TInstrKind::TCallIndirect(_, _, args, index)
    | TInstrKind::TReturnCallIndirect(_, _, args, index) => {
      let out = args.copy()
      out.push(index)
      out
    }
    TInstrKind::TCallRef(_, args, ref_)
    | TInstrKind::TReturnCallRef(_, args, ref_) => {
      let out = args.copy()
      out.push(ref_)
      out
    }
    TInstrKind::TBrIf(_, cond, values) => {
      let out = values.copy()
      out.push(cond)
      out
    }
    TInstrKind::TBrTable(_, _, index, values) => {
      let out = values.copy()
      out.push(index)
      out
    }
    TInstrKind::TBrOnNull(_, ref_, values)
    | TInstrKind::TBrOnNonNull(_, ref_, values)
    | TInstrKind::TBrOnCast(_, _, _, _, ref_, values)
    | TInstrKind::TBrOnCastFail(_, _, _, _, ref_, values) => {
      let out = values.copy()
      out.push(ref_)
      out
    }
    TInstrKind::TArraySet(_, a, b, c) => [a, b, c]
    TInstrKind::TArrayFill(_, a, b, c, d) => [a, b, c, d]
    TInstrKind::TArrayCopy(_, _, a, b, c, d, e) => [a, b, c, d, e]
    TInstrKind::TArrayInitData(_, _, a, b, c, d) => [a, b, c, d]
    TInstrKind::TArrayInitElem(_, _, a, b, c, d) => [a, b, c, d]
    TInstrKind::TI8x16Shuffle(
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      left,
      right
    ) => [left, right]
    TInstrKind::TBlock(_, _)
    | TInstrKind::TLoop(_, _)
    | TInstrKind::TIf(_, _, _, _)
    | TInstrKind::TTryTable(_, _, _) => []
  }
}

///|
fn ml_analyze_texpr(
  expr : TExpr,
  in_flow : MLFlowState,
  state : MLAnalyzeState,
) -> MLFlowState {
  let mut flow = in_flow
  for instr in expr.instrs {
    if state.over_budget {
      return flow
    }
    flow = ml_analyze_tinstruction(instr, flow, state)
  }
  flow
}

///|
fn ml_analyze_tinstruction(
  instr : TInstr,
  in_flow : MLFlowState,
  state : MLAnalyzeState,
) -> MLFlowState {
  if state.over_budget {
    return in_flow
  }
  match instr.kind {
    TInstrKind::TLocalGet(idx) => {
      let get_id = state.next_get_id
      state.next_get_id = get_id + 1
      ml_mark_over_budget_if_needed(state)
      state.get_nodes[get_id] = MLGetNode::{ idx, }
      state.get_sets[get_id] = ml_get_reaching(in_flow, idx)
      in_flow
    }
    TInstrKind::TLocalTee(idx, value) => {
      let out_flow = ml_analyze_tinstruction(value, in_flow, state)
      let set_id = state.next_set_id
      state.next_set_id = set_id + 1
      ml_mark_over_budget_if_needed(state)
      let reaching = Set::new()
      reaching.add(MLSSetRef::Set(set_id))
      out_flow[idx] = reaching
      out_flow
    }
    TInstrKind::TLocalSet(idx, value) => {
      let out_flow = ml_analyze_tinstruction(value, in_flow, state)
      let mut trivial_set_id : Int? = None
      let mut copy_src_idx : LocalIdx? = None
      match value.kind {
        TInstrKind::TLocalTee(src, { kind: TInstrKind::TLocalGet(src_get), .. }) if src ==
          src_get &&
          idx != src => {
          trivial_set_id = Some(state.next_set_id - 1)
          copy_src_idx = Some(src)
        }
        _ => ()
      }
      let set_id = state.next_set_id
      state.next_set_id = set_id + 1
      ml_mark_over_budget_if_needed(state)
      let reaching = Set::new()
      reaching.add(MLSSetRef::Set(set_id))
      out_flow[idx] = reaching
      if trivial_set_id is Some(tid) && copy_src_idx is Some(src) {
        state.copies.push(MLCopySite::{
          copy_set_id: set_id,
          trivial_set_id: tid,
          copy_idx: idx,
          trivial_idx: src,
        })
      }
      out_flow
    }
    TInstrKind::TIf(_, cond, then_, else_) => {
      let flow_after_cond = ml_analyze_tinstruction(cond, in_flow, state)
      let then_flow = ml_analyze_texpr(
        then_,
        ml_copy_flow_state(flow_after_cond),
        state,
      )
      let else_flow = match else_ {
        Some(else_expr) =>
          ml_analyze_texpr(
            else_expr,
            ml_copy_flow_state(flow_after_cond),
            state,
          )
        None => ml_copy_flow_state(flow_after_cond)
      }
      ml_merge_flow_states(then_flow, else_flow)
    }
    TInstrKind::TBlock(_, body) => ml_analyze_texpr(body, in_flow, state)
    TInstrKind::TLoop(_, body) => {
      let one_iter = ml_analyze_texpr(body, ml_copy_flow_state(in_flow), state)
      ml_merge_flow_states(in_flow, one_iter)
    }
    TInstrKind::TTryTable(_, _, body) => {
      let body_flow = ml_analyze_texpr(body, ml_copy_flow_state(in_flow), state)
      ml_merge_flow_states(in_flow, body_flow)
    }
    _ => {
      let mut flow = in_flow
      for child in ml_eval_children(instr) {
        flow = ml_analyze_tinstruction(child, flow, state)
      }
      flow
    }
  }
}

///|
fn build_local_graph_snapshot(func : Func) -> MLLocalGraphSnapshot {
  match func {
    TFunc(_, body) => {
      let state = MLAnalyzeState::{
        next_get_id: 0,
        next_set_id: 0,
        over_budget: false,
        get_sets: Map::new(),
        get_nodes: Map::new(),
        copies: [],
      }
      ignore(ml_analyze_texpr(body, Map::new(), state))
      {
        aborted: state.over_budget,
        get_sets: state.get_sets,
        set_influences: Map::new(),
        get_nodes: state.get_nodes,
        copies: state.copies,
        get_count: state.next_get_id,
      }
    }
    _ =>
      {
        aborted: false,
        get_sets: Map::new(),
        set_influences: Map::new(),
        get_nodes: Map::new(),
        copies: [],
        get_count: 0,
      }
  }
}

///|
fn compute_set_influences(graph : MLLocalGraphSnapshot) -> Unit {
  let out = Map::new()
  for get_id in 0..<graph.get_count {
    let sets = graph.get_sets.get(get_id).unwrap_or(Set::new())
    for set_ref in sets {
      match set_ref {
        MLSSetRef::Set(set_id) => {
          let arr = out.get(set_id).unwrap_or([])
          arr.push(get_id)
          out[set_id] = arr
        }
        MLSSetRef::InitValue => ()
      }
    }
  }
  graph.set_influences = out
}

///|
fn get_set_influences(
  graph : MLLocalGraphSnapshot,
  set_node : Int,
) -> Array[Int] {
  graph.set_influences.get(set_node).unwrap_or([])
}

///|
fn get_sets(graph : MLLocalGraphSnapshot, local_get : Int) -> Set[MLSSetRef] {
  graph.get_sets.get(local_get).unwrap_or(Set::new())
}

///|
fn ml_sets_exactly_set_id(sets : Set[MLSSetRef], set_id : Int) -> Bool {
  sets.length() == 1 && sets.contains(MLSSetRef::Set(set_id))
}

///|
fn ml_local_type(locals : Array[ValType], idx : LocalIdx) -> ValType? {
  let i = ml_local_idx_to_int(idx)
  if i < 0 || i >= locals.length() {
    None
  } else {
    Some(locals[i])
  }
}

///|
fn ml_local_types_equal(
  locals : Array[ValType],
  a : LocalIdx,
  b : LocalIdx,
) -> Bool {
  match (ml_local_type(locals, a), ml_local_type(locals, b)) {
    (Some(ta), Some(tb)) => ta == tb
    _ => false
  }
}

///|
fn ml_can_rewrite_gets(
  graph : MLLocalGraphSnapshot,
  get_ids : Array[Int],
  required_set_id : Int,
  locals : Array[ValType],
  target_local_idx : LocalIdx,
  planned_rewrites : Map[Int, LocalIdx],
) -> Bool {
  for get_id in get_ids {
    if !ml_sets_exactly_set_id(get_sets(graph, get_id), required_set_id) {
      return false
    }
    let get_node = match graph.get_nodes.get(get_id) {
      Some(node) => node
      None => return false
    }
    if !ml_local_types_equal(locals, target_local_idx, get_node.idx) {
      return false
    }
    if planned_rewrites.get(get_id) is Some(existing) &&
      existing != target_local_idx {
      return false
    }
  }
  true
}

///|
fn ml_rewrite_get_indices(
  body : TExpr,
  rewrites : Map[Int, LocalIdx],
) -> (TExpr, Bool) {
  if rewrites.is_empty() {
    return (body, false)
  }
  let get_id = Ref::new(0)
  let changed = Ref::new(false)
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr.kind {
      TInstrKind::TLocalGet(curr_idx) => {
        let id = get_id.val
        get_id.update(fn(n) { n + 1 })
        match rewrites.get(id) {
          Some(next_idx) if next_idx != curr_idx => {
            changed.update(fn(_) { true })
            change((), TInstr::local_get(next_idx))
          }
          _ => unchanged()
        }
      }
      _ => self.walk_tinstruction_default((), instr)
    }
  })
  match walker.walk_texpr((), body) {
    Ok(Some((_, out))) => (out, changed.val)
    Ok(None) => (body, false)
    Err(_) => (body, false)
  }
}

///|
fn ml_cleanup_instrumentation(body : TExpr) -> (TExpr, Bool) {
  let changed = Ref::new(false)
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr.kind {
      TInstrKind::TLocalSet(
        dst,
        {
          kind: TInstrKind::TLocalTee(
            src,
            { kind: TInstrKind::TLocalGet(src_get), .. }
          ),
          ..,
        }
      ) if src == src_get => {
        changed.update(fn(_) { true })
        change((), TInstr::local_set(dst, TInstr::local_get(src)))
      }
      _ => self.walk_tinstruction_default((), instr)
    }
  })
  match walker.walk_texpr((), body) {
    Ok(Some((_, out))) => (out, changed.val)
    Ok(None) => (body, false)
    Err(_) => (body, false)
  }
}

///|
fn ml_verify_direction(
  post_graph : MLLocalGraphSnapshot,
  get_ids : Array[Int],
  required_set_id : Int,
) -> Bool {
  for get_id in get_ids {
    if !ml_sets_exactly_set_id(get_sets(post_graph, get_id), required_set_id) {
      return false
    }
  }
  true
}

///|
fn optimize_copies(func : Func) -> (Func, Bool) {
  match func {
    TFunc(locals, body) => {
      let (instrumented_body, instrumented) = ml_instrument_copies(body)
      if !instrumented {
        return (func, false)
      }
      let instrumented_func = Func::t_func(locals, instrumented_body)
      let pre_graph = build_local_graph_snapshot(instrumented_func)
      if pre_graph.aborted {
        return (func, false)
      }
      compute_set_influences(pre_graph)
      let rewrites : Map[Int, LocalIdx] = Map::new()
      let optimized_to_copy : Array[MLRewriteRecord] = []
      let optimized_to_trivial : Array[MLRewriteRecord] = []
      for copy in pre_graph.copies {
        let trivial_influences = get_set_influences(
          pre_graph,
          copy.trivial_set_id,
        )
        let has_trivial_influences = !trivial_influences.is_empty()
        let copy_influences = get_set_influences(pre_graph, copy.copy_set_id)
        let can_optimize_to_copy = has_trivial_influences &&
          ml_can_rewrite_gets(
            pre_graph,
            trivial_influences,
            copy.trivial_set_id,
            locals,
            copy.copy_idx,
            rewrites,
          )
        let can_optimize_to_trivial = has_trivial_influences &&
          !copy_influences.is_empty() &&
          ml_can_rewrite_gets(
            pre_graph,
            copy_influences,
            copy.copy_set_id,
            locals,
            copy.trivial_idx,
            rewrites,
          )
        if can_optimize_to_copy && can_optimize_to_trivial {
          // Avoid bidirectional oscillation by skipping ambiguous dual-direction copies.
          ()
        } else if can_optimize_to_copy {
          for get_id in trivial_influences {
            rewrites[get_id] = copy.copy_idx
          }
          optimized_to_copy.push(MLRewriteRecord::{
            copy_set_id: copy.copy_set_id,
            trivial_set_id: copy.trivial_set_id,
            get_ids: trivial_influences,
          })
        } else if can_optimize_to_trivial {
          for get_id in copy_influences {
            rewrites[get_id] = copy.trivial_idx
          }
          optimized_to_trivial.push(MLRewriteRecord::{
            copy_set_id: copy.copy_set_id,
            trivial_set_id: copy.trivial_set_id,
            get_ids: copy_influences,
          })
        }
      }
      let optimized_body = if rewrites.is_empty() {
        instrumented_body
      } else {
        let (tentative_body, _) = ml_rewrite_get_indices(
          instrumented_body, rewrites,
        )
        let post_func = Func::t_func(locals, tentative_body)
        let post_graph = build_local_graph_snapshot(post_func)
        if post_graph.aborted {
          return (func, false)
        }
        compute_set_influences(post_graph)
        let verified_rewrites : Map[Int, LocalIdx] = Map::new()
        for entry in rewrites {
          let (get_id, idx) = entry
          verified_rewrites[get_id] = idx
        }
        for record in optimized_to_copy {
          if !ml_verify_direction(
              post_graph,
              record.get_ids,
              record.copy_set_id,
            ) {
            for get_id in record.get_ids {
              ignore(verified_rewrites.remove(get_id))
            }
          }
        }
        for record in optimized_to_trivial {
          if !ml_verify_direction(
              post_graph,
              record.get_ids,
              record.trivial_set_id,
            ) {
            for get_id in record.get_ids {
              ignore(verified_rewrites.remove(get_id))
            }
          }
        }
        if verified_rewrites.length() == rewrites.length() {
          tentative_body
        } else {
          let (rebuilt_body, _) = ml_rewrite_get_indices(
            instrumented_body, verified_rewrites,
          )
          rebuilt_body
        }
      }
      let (cleaned_body, _) = ml_cleanup_instrumentation(optimized_body)
      let changed = cleaned_body != body
      (Func::t_func(locals, cleaned_body), changed)
    }
    _ => (func, false)
  }
}

///|
fn merge_locals_run_on_function(
  func : Func,
  mod_ : Module,
  options : OptimizeOptions,
) -> (Func, Bool) {
  ignore(mod_)
  ignore(options)
  optimize_copies(func)
}

///|
fn merge_locals_ir_pass(
  mod : Module,
  options? : OptimizeOptions = OptimizeOptions::new(),
) -> ModuleTransformer[IRContext] {
  if ml_should_skip_module(mod) {
    return ModuleTransformer::new()
  }
  ModuleTransformer::new().on_func_evt(fn(_, ctx, func) {
    let (next_func, changed) = merge_locals_run_on_function(func, mod, options)
    if changed {
      change(ctx, next_func)
    } else {
      unchanged()
    }
  })
}
