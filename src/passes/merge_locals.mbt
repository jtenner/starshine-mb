///|
pub fn merge_locals_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new(
    "merge-locals",
    requires=[@ir.HotAnalysis::cfg()],
    invalidates=[
      @ir.HotAnalysis::cfg(),
      @ir.HotAnalysis::dominance(),
      @ir.HotAnalysis::liveness(),
      @ir.HotAnalysis::use_def(),
      @ir.HotAnalysis::effects(),
      @ir.HotAnalysis::loop_info(),
      @ir.HotAnalysis::ssa(),
    ],
  )
}

///|
pub fn merge_locals_summary() -> String {
  "Balance copy-shaped local live ranges with CFG-backed bidirectional retargeting and rollback."
}

///|
priv struct MergeLocalsCopy {
  copy_id : @ir.NodeId
  trivial_id : @ir.NodeId
  source_local : @ir.LocalId
  target_local : @ir.LocalId
}

///|
priv enum MergeLocalsOrientation {
  ToCopy
  ToTrivial
}

///|
priv struct MergeLocalsOptimizedCopy {
  copy : MergeLocalsCopy
  orientation : MergeLocalsOrientation
  influenced_gets : Array[@ir.NodeId]
}

///|
fn merge_locals_get_has_only_source(
  graph : @ir.HotLocalGraph,
  get_id : @ir.NodeId,
  write_id : @ir.NodeId,
) -> Bool {
  let sources = @ir.local_graph_reaching_sources_for_get(graph, get_id)
  if sources.length() != 1 {
    return false
  }
  match sources[0] {
    @ir.HotLocalGraphSource::SetSource(found) => found == write_id
    _ => false
  }
}

///|
fn merge_locals_get_value_type(
  func : @ir.HotFunc,
  get_id : @ir.NodeId,
) -> @lib.ValType? {
  if get_id < 0 || !@ir.hot_node_is_live(func, get_id) {
    return None
  }
  let node = @ir.hot_node_get(func, get_id)
  match node.op {
    @ir.HotOp::LocalGet =>
      match @ir.hot_type_get(func, node.ty) {
        @ir.HotTypeInfo::Value(ty) => Some(ty)
        _ => None
      }
    _ => None
  }
}

///|
fn merge_locals_gets_match_target_type(
  func : @ir.HotFunc,
  gets : Array[@ir.NodeId],
  target_local : @ir.LocalId,
) -> Bool {
  let target_type = match @ir.hot_local_type(func, target_local) {
    Some(ty) => ty
    None => return false
  }
  for get_id in gets {
    match merge_locals_get_value_type(func, get_id) {
      Some(ty) => if ty != target_type { return false }
      None => return false
    }
  }
  true
}

///|
fn merge_locals_gets_are_single_source(
  graph : @ir.HotLocalGraph,
  gets : Array[@ir.NodeId],
  write_id : @ir.NodeId,
) -> Bool {
  for get_id in gets {
    if !merge_locals_get_has_only_source(graph, get_id, write_id) {
      return false
    }
  }
  true
}

///|
fn merge_locals_retarget_get(
  func : @ir.HotFunc,
  get_id : @ir.NodeId,
  local_id : @ir.LocalId,
) -> Unit {
  match @ir.hot_node_get(func, get_id).op {
    @ir.HotOp::LocalGet => @ir.hot_local_node_id_set(func, get_id, local_id)
    _ => abort("merge-locals expected an influenced local.get")
  }
}

///|
fn merge_locals_retarget_gets(
  func : @ir.HotFunc,
  gets : Array[@ir.NodeId],
  local_id : @ir.LocalId,
) -> Unit {
  for get_id in gets {
    merge_locals_retarget_get(func, get_id, local_id)
  }
}

///|
fn merge_locals_instrument_copies(func : @ir.HotFunc) -> Array[MergeLocalsCopy] {
  let copies : Array[MergeLocalsCopy] = []
  let original_node_count = @ir.hot_node_count(func)
  for copy_id = 0; copy_id < original_node_count; copy_id = copy_id + 1 {
    if !@ir.hot_node_is_live(func, copy_id) {
      continue
    }
    let copy = @ir.hot_node_get(func, copy_id)
    match copy.op {
      @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => {
        if @ir.hot_child_count(func, copy_id) != 1 {
          continue
        }
        let value_id = @ir.hot_child_get(func, copy_id, 0)
        if value_id < 0 || !@ir.hot_node_is_live(func, value_id) {
          continue
        }
        let value = @ir.hot_node_get(func, value_id)
        match value.op {
          @ir.HotOp::LocalGet if value.imm0 != copy.imm0 => {
            let trivial_id = @ir.hot_build_local_tee(func, value.imm0, value_id)
            @ir.hot_child_set(func, copy_id, 0, trivial_id)
            copies.push({
              copy_id,
              trivial_id,
              source_local: value.imm0,
              target_local: copy.imm0,
            })
          }
          _ => ()
        }
      }
      _ => ()
    }
  }
  copies
}

///|
fn merge_locals_optimize_copies(
  func : @ir.HotFunc,
  graph : @ir.HotLocalGraph,
  copies : Array[MergeLocalsCopy],
) -> Array[MergeLocalsOptimizedCopy] {
  let optimized : Array[MergeLocalsOptimizedCopy] = []
  for copy in copies {
    let trivial_influences = @ir.local_graph_influenced_gets_for_write(
      graph,
      copy.trivial_id,
    )
    let can_optimize_to_copy = trivial_influences.length() > 0 &&
      merge_locals_gets_are_single_source(
        graph,
        trivial_influences,
        copy.trivial_id,
      ) &&
      merge_locals_gets_match_target_type(
        func,
        trivial_influences,
        copy.target_local,
      )
    if can_optimize_to_copy {
      merge_locals_retarget_gets(func, trivial_influences, copy.target_local)
      optimized.push({
        copy,
        orientation: MergeLocalsOrientation::ToCopy,
        influenced_gets: trivial_influences,
      })
      continue
    }

    if trivial_influences.length() == 0 {
      continue
    }
    let copy_influences = @ir.local_graph_influenced_gets_for_write(
      graph,
      copy.copy_id,
    )
    let can_optimize_to_trivial = copy_influences.length() > 0 &&
      merge_locals_gets_are_single_source(graph, copy_influences, copy.copy_id) &&
      merge_locals_gets_match_target_type(
        func,
        copy_influences,
        copy.source_local,
      )
    if can_optimize_to_trivial {
      merge_locals_retarget_gets(func, copy_influences, copy.source_local)
      optimized.push({
        copy,
        orientation: MergeLocalsOrientation::ToTrivial,
        influenced_gets: copy_influences,
      })
    }
  }
  optimized
}

///|
fn merge_locals_verify_and_rollback(
  func : @ir.HotFunc,
  post_graph : @ir.HotLocalGraph,
  optimized : Array[MergeLocalsOptimizedCopy],
) -> Int {
  let mut kept = 0
  for rewrite in optimized {
    let expected_write = match rewrite.orientation {
      MergeLocalsOrientation::ToCopy => rewrite.copy.copy_id
      MergeLocalsOrientation::ToTrivial => rewrite.copy.trivial_id
    }
    let mut valid = true
    for get_id in rewrite.influenced_gets {
      if !merge_locals_get_has_only_source(post_graph, get_id, expected_write) {
        valid = false
        break
      }
    }
    if valid {
      kept += 1
    } else {
      let original_local = match rewrite.orientation {
        MergeLocalsOrientation::ToCopy => rewrite.copy.source_local
        MergeLocalsOrientation::ToTrivial => rewrite.copy.target_local
      }
      merge_locals_retarget_gets(func, rewrite.influenced_gets, original_local)
    }
  }
  kept
}

///|
fn merge_locals_remove_instrumentation(
  func : @ir.HotFunc,
  copies : Array[MergeLocalsCopy],
) -> Unit {
  for copy in copies {
    if !@ir.hot_node_is_live(func, copy.copy_id) ||
      !@ir.hot_node_is_live(func, copy.trivial_id) {
      continue
    }
    let original_get = @ir.hot_child_get(func, copy.trivial_id, 0)
    @ir.hot_child_set(func, copy.copy_id, 0, original_get)
    @ir.hot_delete_node(func, copy.trivial_id)
  }
}

///|
priv struct MergeLocalsRawCandidate {
  set_idx : Int
  source_local : Int
  target_local : Int
  virtual_source : Int
  copy_source : Int
}

///|
priv struct MergeLocalsRawRewrite {
  supported : Bool
  func : @lib.Func
  changed : Bool
}

///|
fn merge_locals_raw_idx(idx : @lib.LocalIdx) -> Int {
  let @lib.LocalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn merge_locals_raw_local_idx(idx : Int) -> @lib.LocalIdx {
  @lib.LocalIdx::new(idx.reinterpret_as_uint())
}

///|
fn merge_locals_raw_local_types(
  params : Array[@lib.ValType],
  locals : @lib.Locals,
) -> Array[@lib.ValType] {
  let out = params.copy()
  for run in locals.runs() {
    for _ in 0..<run.count().reinterpret_as_int() {
      out.push(run.val_type())
    }
  }
  out
}

///|
fn merge_locals_raw_is_straight_line(instrs : Array[@lib.Instruction]) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Block(_, _)
      | @lib.Loop(_, _)
      | @lib.If(_, _, _)
      | @lib.TryTable(_, _, _)
      | @lib.Br(_)
      | @lib.BrIf(_)
      | @lib.BrTable(_, _)
      | @lib.BrOnNull(_)
      | @lib.BrOnNonNull(_)
      | @lib.BrOnCast(_, _, _, _)
      | @lib.BrOnCastFail(_, _, _, _)
      | @lib.Return
      | @lib.ReturnCall(_)
      | @lib.ReturnCallIndirect(_, _)
      | @lib.ReturnCallRef(_)
      | @lib.Throw(_)
      | @lib.ThrowRef => return false
      _ => ()
    }
  }
  true
}

///|
fn merge_locals_raw_candidates(
  instrs : Array[@lib.Instruction],
  local_count : Int,
) -> Array[MergeLocalsRawCandidate] {
  let out : Array[MergeLocalsRawCandidate] = []
  for idx = 1; idx < instrs.length(); idx = idx + 1 {
    match (instrs[idx - 1], instrs[idx]) {
      (
        @lib.LocalGet(source_idx),
        @lib.LocalSet(target_idx)
        | @lib.LocalTee(target_idx),
      ) => {
        let source = merge_locals_raw_idx(source_idx)
        let target = merge_locals_raw_idx(target_idx)
        if source != target {
          out.push({
            set_idx: idx,
            source_local: source,
            target_local: target,
            virtual_source: local_count + idx * 2,
            copy_source: local_count + idx * 2 + 1,
          })
        }
      }
      _ => ()
    }
  }
  out
}

///|
fn merge_locals_raw_candidate_map(
  candidates : Array[MergeLocalsRawCandidate],
  instr_count : Int,
) -> Array[Int] {
  let map = Array::make(instr_count, -1)
  for idx = 0; idx < candidates.length(); idx = idx + 1 {
    let set_idx = candidates[idx].set_idx
    if set_idx >= 0 && set_idx < map.length() {
      map[set_idx] = idx
    }
  }
  map
}

///|
fn merge_locals_raw_build_influences(
  instrs : Array[@lib.Instruction],
  local_count : Int,
  candidates : Array[MergeLocalsRawCandidate],
) -> Array[Array[Int]] {
  let source_count = local_count + instrs.length() * 2 + 2
  let influences : Array[Array[Int]] = []
  for _ in 0..<source_count {
    influences.push([])
  }
  let current : Array[Int] = []
  for local_id = 0; local_id < local_count; local_id = local_id + 1 {
    current.push(local_id)
  }
  let candidate_map = merge_locals_raw_candidate_map(
    candidates,
    instrs.length(),
  )
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    let candidate_idx = candidate_map[idx]
    if candidate_idx >= 0 {
      let candidate = candidates[candidate_idx]
      current[candidate.source_local] = candidate.virtual_source
    }
    match instrs[idx] {
      @lib.LocalGet(local_idx) => {
        let local_id = merge_locals_raw_idx(local_idx)
        if local_id >= 0 && local_id < current.length() {
          influences[current[local_id]].push(idx)
        }
      }
      @lib.LocalSet(local_idx) | @lib.LocalTee(local_idx) => {
        let local_id = merge_locals_raw_idx(local_idx)
        if local_id >= 0 && local_id < current.length() {
          current[local_id] = local_count + idx * 2 + 1
        }
      }
      _ => ()
    }
  }
  influences
}

///|
fn merge_locals_raw_retarget_gets(
  instrs : Array[@lib.Instruction],
  get_indices : Array[Int],
  local_id : Int,
) -> Unit {
  for idx in get_indices {
    instrs[idx] = @lib.Instruction::local_get(
      merge_locals_raw_local_idx(local_id),
    )
  }
}

///|
fn merge_locals_raw_build_get_sources(
  instrs : Array[@lib.Instruction],
  local_count : Int,
  candidates : Array[MergeLocalsRawCandidate],
) -> Array[Int] {
  let get_sources = Array::make(instrs.length(), -1)
  let current : Array[Int] = []
  for local_id = 0; local_id < local_count; local_id = local_id + 1 {
    current.push(local_id)
  }
  let candidate_map = merge_locals_raw_candidate_map(
    candidates,
    instrs.length(),
  )
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    let candidate_idx = candidate_map[idx]
    if candidate_idx >= 0 {
      let candidate = candidates[candidate_idx]
      current[candidate.source_local] = candidate.virtual_source
    }
    match instrs[idx] {
      @lib.LocalGet(local_idx) => {
        let local_id = merge_locals_raw_idx(local_idx)
        if local_id >= 0 && local_id < current.length() {
          get_sources[idx] = current[local_id]
        }
      }
      @lib.LocalSet(local_idx) | @lib.LocalTee(local_idx) => {
        let local_id = merge_locals_raw_idx(local_idx)
        if local_id >= 0 && local_id < current.length() {
          current[local_id] = local_count + idx * 2 + 1
        }
      }
      _ => ()
    }
  }
  get_sources
}

///|
fn merge_locals_run_raw_straight_line_func(
  func : @lib.Func,
  params : Array[@lib.ValType],
) -> MergeLocalsRawRewrite {
  let @lib.Func(locals, @lib.Expr(original)) = func
  if !merge_locals_raw_is_straight_line(original) {
    return { supported: false, func, changed: false }
  }
  let local_types = merge_locals_raw_local_types(params, locals)
  let candidates = merge_locals_raw_candidates(original, local_types.length())
  if candidates.is_empty() {
    return { supported: true, func, changed: false }
  }
  let influences = merge_locals_raw_build_influences(
    original,
    local_types.length(),
    candidates,
  )
  let rewritten = original.copy()
  let orientations = Array::make(candidates.length(), 0)
  let rewrite_gets : Array[Array[Int]] = []
  for candidate_idx = 0
      candidate_idx < candidates.length()
      candidate_idx = candidate_idx + 1 {
    let candidate = candidates[candidate_idx]
    let trivial_gets = influences[candidate.virtual_source]
    let same_type = candidate.source_local >= 0 &&
      candidate.target_local >= 0 &&
      candidate.source_local < local_types.length() &&
      candidate.target_local < local_types.length() &&
      local_types[candidate.source_local] == local_types[candidate.target_local]
    if same_type && !trivial_gets.is_empty() {
      merge_locals_raw_retarget_gets(
        rewritten,
        trivial_gets,
        candidate.target_local,
      )
      orientations[candidate_idx] = 1
      rewrite_gets.push(trivial_gets)
    } else {
      rewrite_gets.push([])
    }
  }
  let post_sources = merge_locals_raw_build_get_sources(
    rewritten,
    local_types.length(),
    candidates,
  )
  let mut kept = 0
  for candidate_idx = 0
      candidate_idx < candidates.length()
      candidate_idx = candidate_idx + 1 {
    let orientation = orientations[candidate_idx]
    if orientation == 0 {
      continue
    }
    let candidate = candidates[candidate_idx]
    let expected = candidate.copy_source
    let mut valid = true
    for get_idx in rewrite_gets[candidate_idx] {
      if get_idx < 0 ||
        get_idx >= post_sources.length() ||
        post_sources[get_idx] != expected {
        valid = false
        break
      }
    }
    if valid {
      kept += 1
    } else {
      merge_locals_raw_retarget_gets(
        rewritten,
        rewrite_gets[candidate_idx],
        candidate.source_local,
      )
    }
  }
  if kept == 0 {
    { supported: true, func, changed: false }
  } else {
    {
      supported: true,
      func: @lib.Func::new(locals, @lib.Expr::new(rewritten)),
      changed: true,
    }
  }
}

///|
fn merge_locals_run(ctx : HotPassContext, func : @ir.HotFunc) -> HotPassResult {
  let copies = merge_locals_instrument_copies(func)
  if copies.is_empty() {
    return HotPassResult::unchanged()
  }

  let pre_graph = @ir.local_graph_build(func, pass_require_cfg(ctx, func))
  let optimized = merge_locals_optimize_copies(func, pre_graph, copies)
  let kept = if optimized.is_empty() {
    0
  } else {
    let post_graph = @ir.local_graph_build(func, pass_require_cfg(ctx, func))
    merge_locals_verify_and_rollback(func, post_graph, optimized)
  }
  merge_locals_remove_instrumentation(func, copies)
  pass_mark_mutated(ctx, func)
  if kept > 0 {
    HotPassResult::changed()
  } else {
    HotPassResult::unchanged()
  }
}
