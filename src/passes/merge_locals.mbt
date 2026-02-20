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
  get_sets : Map[Int, Set[MLSSetRef]]
  mut set_influences : Map[Int, Array[Int]]
  get_nodes : Map[Int, MLGetNode]
  copies : Array[MLCopySite]
  get_count : Int
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
  match curr {
    TLocalSet(dst, TLocalGet(src)) if dst != src =>
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
    match instr {
      TLocalSet(_, _) => {
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
  match instr {
    TI32Const(_)
    | TI64Const(_)
    | TF32Const(_)
    | TF64Const(_)
    | TRefNull(_)
    | TRefFunc(_)
    | TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | TUnreachable
    | TNop
    | TLocalGet(_)
    | TGlobalGet(_)
    | TMemorySize(_)
    | TTableSize(_)
    | TDataDrop(_)
    | TElemDrop(_)
    | TStructNewDefault(_) => []
    TUnary(_, child)
    | TDrop(child)
    | TLocalSet(_, child)
    | TLocalTee(_, child)
    | TGlobalSet(_, child)
    | TRefIsNull(child)
    | TRefAsNonNull(child)
    | TI31GetS(child)
    | TI31GetU(child)
    | TRefI31(child)
    | TArrayLen(child)
    | TAnyConvertExtern(child)
    | TExternConvertAny(child)
    | TThrowRef(child)
    | TMemoryGrow(_, child)
    | TTableGet(_, child)
    | TLoad(_, _, child)
    | TArrayNewDefault(_, child)
    | TStructGet(_, _, child)
    | TStructGetS(_, _, child)
    | TStructGetU(_, _, child)
    | TI8x16Splat(child)
    | TI16x8Splat(child)
    | TI32x4Splat(child)
    | TI64x2Splat(child)
    | TF32x4Splat(child)
    | TF64x2Splat(child)
    | TExtractLane(_, _, child)
    | TRefTest(_, _, child)
    | TRefCast(_, _, child)
    | TRefGetDesc(child)
    | TRefTestDesc(_, _, child)
    | TRefCastDescEq(_, _, child) => [child]
    TBinary(_, left, right)
    | TRefEq(left, right)
    | TStore(_, _, left, right)
    | TTableSet(_, left, right)
    | TTableGrow(_, left, right)
    | TStructSet(_, _, left, right)
    | TArrayNew(_, left, right)
    | TArrayNewData(_, _, left, right)
    | TArrayNewElem(_, _, left, right)
    | TArrayGet(_, left, right)
    | TArrayGetS(_, left, right)
    | TArrayGetU(_, left, right)
    | TReplaceLane(_, _, left, right)
    | TI8x16Swizzle(left, right)
    | TI8x16RelaxedSwizzle(left, right)
    | TV128Shift(_, left, right)
    | TV128LoadLane(_, _, _, left, right)
    | TV128StoreLane(_, _, _, left, right) => [left, right]
    TMemoryFill(_, a, b, c)
    | TMemoryCopy(_, _, a, b, c)
    | TMemoryInit(_, _, a, b, c)
    | TTableFill(_, a, b, c)
    | TTableCopy(_, _, a, b, c)
    | TTableInit(_, _, a, b, c)
    | TSelect(_, c, a, b)
    | TV128Ternary(_, a, b, c) => [a, b, c]
    TCall(_, args)
    | TReturnCall(_, args)
    | TThrow(_, args)
    | TBr(_, args)
    | TReturn(args)
    | TStructNew(_, args)
    | TArrayNewFixed(_, args) => args.copy()
    TCallIndirect(_, _, args, index) | TReturnCallIndirect(_, _, args, index) => {
      let out = args.copy()
      out.push(index)
      out
    }
    TCallRef(_, args, ref_) | TReturnCallRef(_, args, ref_) => {
      let out = args.copy()
      out.push(ref_)
      out
    }
    TBrIf(_, cond, values) => {
      let out = values.copy()
      out.push(cond)
      out
    }
    TBrTable(_, _, index, values) => {
      let out = values.copy()
      out.push(index)
      out
    }
    TBrOnNull(_, ref_, values)
    | TBrOnNonNull(_, ref_, values)
    | TBrOnCast(_, _, _, _, ref_, values)
    | TBrOnCastFail(_, _, _, _, ref_, values) => {
      let out = values.copy()
      out.push(ref_)
      out
    }
    TArraySet(_, a, b, c) => [a, b, c]
    TArrayFill(_, a, b, c, d) => [a, b, c, d]
    TArrayCopy(_, _, a, b, c, d, e) => [a, b, c, d, e]
    TArrayInitData(_, _, a, b, c, d) => [a, b, c, d]
    TArrayInitElem(_, _, a, b, c, d) => [a, b, c, d]
    TI8x16Shuffle(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, left, right) =>
      [left, right]
    TBlock(_, _) | TLoop(_, _) | TIf(_, _, _, _) | TTryTable(_, _, _) => []
  }
}

///|
fn ml_analyze_texpr(
  expr : TExpr,
  in_flow : MLFlowState,
  state : MLAnalyzeState,
) -> MLFlowState {
  let mut flow = in_flow
  for instr in expr.0 {
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
  match instr {
    TLocalGet(idx) => {
      let get_id = state.next_get_id
      state.next_get_id = get_id + 1
      state.get_nodes[get_id] = MLGetNode::{ idx, }
      state.get_sets[get_id] = ml_get_reaching(in_flow, idx)
      in_flow
    }
    TLocalTee(idx, value) => {
      let out_flow = ml_analyze_tinstruction(value, in_flow, state)
      let set_id = state.next_set_id
      state.next_set_id = set_id + 1
      let reaching = Set::new()
      reaching.add(MLSSetRef::Set(set_id))
      out_flow[idx] = reaching
      out_flow
    }
    TLocalSet(idx, value) => {
      let out_flow = ml_analyze_tinstruction(value, in_flow, state)
      let mut trivial_set_id : Int? = None
      let mut copy_src_idx : LocalIdx? = None
      match value {
        TLocalTee(src, TLocalGet(src_get)) if src == src_get && idx != src => {
          trivial_set_id = Some(state.next_set_id - 1)
          copy_src_idx = Some(src)
        }
        _ => ()
      }
      let set_id = state.next_set_id
      state.next_set_id = set_id + 1
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
    TIf(_, cond, then_, else_) => {
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
    TBlock(_, body) => ml_analyze_texpr(body, in_flow, state)
    TLoop(_, body) => {
      let one_iter = ml_analyze_texpr(body, ml_copy_flow_state(in_flow), state)
      ml_merge_flow_states(in_flow, one_iter)
    }
    TTryTable(_, _, body) => {
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
fn build_local_graph_snapshot(
  func : Func,
  mod_ : Module,
) -> MLLocalGraphSnapshot {
  ignore(mod_)
  match func {
    TFunc(_, body) => {
      // Build eagerly to avoid IR mutation races with later rewrites.
      ignore(LocalGraph::new(body.0))
      let state = MLAnalyzeState::{
        next_get_id: 0,
        next_set_id: 0,
        get_sets: Map::new(),
        get_nodes: Map::new(),
        copies: [],
      }
      ignore(ml_analyze_texpr(body, Map::new(), state))
      {
        get_sets: state.get_sets,
        set_influences: Map::new(),
        get_nodes: state.get_nodes,
        copies: state.copies,
        get_count: state.next_get_id,
      }
    }
    _ =>
      {
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
    match instr {
      TLocalGet(curr_idx) => {
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
    match instr {
      TLocalSet(dst, TLocalTee(src, TLocalGet(src_get))) if src == src_get => {
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
fn optimize_copies(func : Func, mod_ : Module) -> (Func, Bool) {
  match func {
    TFunc(locals, body) => {
      let (instrumented_body, _) = ml_instrument_copies(body)
      let instrumented_func = Func::t_func(locals, instrumented_body)
      let pre_graph = build_local_graph_snapshot(instrumented_func, mod_)
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
        let post_graph = build_local_graph_snapshot(post_func, mod_)
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
  ignore(options)
  optimize_copies(func, mod_)
}

///|
fn merge_locals_ir_pass(
  mod : Module,
  options? : OptimizeOptions = OptimizeOptions::new(),
) -> ModuleTransformer[IRContext] {
  ModuleTransformer::new().on_func_evt(fn(_, ctx, func) {
    let (next_func, changed) = merge_locals_run_on_function(func, mod, options)
    if changed {
      change(ctx, next_func)
    } else {
      unchanged()
    }
  })
}
