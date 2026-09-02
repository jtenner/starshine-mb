///|
pub fn ssa_full_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new("ssa", requires=[@ir.HotAnalysis::cfg()], invalidates=[
    @ir.HotAnalysis::cfg(),
    @ir.HotAnalysis::dominance(),
    @ir.HotAnalysis::liveness(),
    @ir.HotAnalysis::use_def(),
    @ir.HotAnalysis::effects(),
    @ir.HotAnalysis::loop_info(),
    @ir.HotAnalysis::ssa(),
  ])
}

///|
pub fn ssa_full_summary() -> String {
  "SSA-ify local traffic with Binaryen-style fresh definitions, explicit defaults, merge locals, incoming tees, and parameter-entry prepends."
}

///|
pub(all) enum SsaFullWriteDecision {
  Freshen(@ir.LocalId)
  KeepCanonical
} derive(Eq, Debug)

///|
pub(all) struct SsaFullWriteRewrite {
  write_id : @ir.NodeId
  original_local : @ir.LocalId
  decision : SsaFullWriteDecision
} derive(Eq, Debug)

///|
pub(all) enum SsaFullGetDecision {
  Retarget(@ir.LocalId)
  MaterializeDefault
  Merge(@ir.LocalId)
  KeepCanonical
} derive(Eq, Debug)

///|
pub(all) struct SsaFullGetRewrite {
  get_id : @ir.NodeId
  original_local : @ir.LocalId
  decision : SsaFullGetDecision
} derive(Eq, Debug)

///|
pub(all) enum SsaFullMergeInput {
  ExplicitWrite(@ir.NodeId)
  ParamEntry(@ir.LocalId)
  DefaultEntry(@ir.LocalId)
} derive(Eq, Debug)

///|
pub(all) struct SsaFullMergeGetRewrite {
  get_id : @ir.NodeId
  original_local : @ir.LocalId
  merge_local : @ir.LocalId
  inputs : Array[SsaFullMergeInput]
} derive(Eq, Debug)

///|
pub(all) struct SsaFullRewritePlan {
  write_rewrites : Array[SsaFullWriteRewrite]
  get_rewrites : Array[SsaFullGetRewrite]
  merge_gets : Array[SsaFullMergeGetRewrite]
} derive(Eq, Debug)

///|
fn ssa_full_write_target_local(
  writes : Array[SsaFullWriteRewrite],
  write_id : @ir.NodeId,
) -> @ir.LocalId? {
  for rewrite in writes {
    if rewrite.write_id == write_id {
      return Some(
        match rewrite.decision {
          SsaFullWriteDecision::Freshen(local_id) => local_id
          SsaFullWriteDecision::KeepCanonical => rewrite.original_local
        },
      )
    }
  }
  None
}

///|
fn ssa_full_source_to_merge_input(
  graph : @ir.HotLocalGraph,
  source : @ir.HotLocalGraphSource,
) -> SsaFullMergeInput? {
  match source {
    @ir.HotLocalGraphSource::SetSource(node_id) =>
      Some(SsaFullMergeInput::ExplicitWrite(node_id))
    @ir.HotLocalGraphSource::EntrySource(local_id) =>
      if @ir.local_graph_entry_source_is_param(graph, local_id) {
        Some(SsaFullMergeInput::ParamEntry(local_id))
      } else if @ir.local_graph_entry_source_has_legal_default(graph, local_id) {
        Some(SsaFullMergeInput::DefaultEntry(local_id))
      } else {
        None
      }
  }
}

///|
fn ssa_full_build_inputs_for_merge_get(
  graph : @ir.HotLocalGraph,
  get_id : @ir.NodeId,
) -> Array[SsaFullMergeInput]? {
  let inputs : Array[SsaFullMergeInput] = []
  for source in @ir.local_graph_reaching_sources_for_get(graph, get_id) {
    match ssa_full_source_to_merge_input(graph, source) {
      Some(input) => inputs.push(input)
      None => return None
    }
  }
  Some(inputs)
}

///|
fn ssa_full_plan_single_get(
  graph : @ir.HotLocalGraph,
  writes : Array[SsaFullWriteRewrite],
  get_id : @ir.NodeId,
) -> SsaFullGetDecision {
  let sources = @ir.local_graph_reaching_sources_for_get(graph, get_id)
  if sources.length() != 1 {
    return SsaFullGetDecision::KeepCanonical
  }
  match sources[0] {
    @ir.HotLocalGraphSource::SetSource(write_id) =>
      match ssa_full_write_target_local(writes, write_id) {
        Some(local_id) => SsaFullGetDecision::Retarget(local_id)
        None => SsaFullGetDecision::KeepCanonical
      }
    @ir.HotLocalGraphSource::EntrySource(local_id) =>
      if @ir.local_graph_entry_source_is_param(graph, local_id) {
        SsaFullGetDecision::KeepCanonical
      } else if @ir.local_graph_entry_source_has_legal_default(graph, local_id) {
        SsaFullGetDecision::MaterializeDefault
      } else {
        SsaFullGetDecision::KeepCanonical
      }
  }
}

///|
pub fn ssa_full_build_merge_rewrite_plan(
  func : @ir.HotFunc,
  graph : @ir.HotLocalGraph,
) -> SsaFullRewritePlan {
  let write_rewrites : Array[SsaFullWriteRewrite] = []
  let mut next_local = @ir.hot_local_count(func)
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) ||
      !@ir.local_graph_node_is_write(graph, node_id) {
      continue
    }
    let original_local = @ir.local_graph_write_local_id(graph, node_id)
    let decision = if @ir.local_graph_local_is_already_ssa(
        graph, original_local,
      ) {
      SsaFullWriteDecision::KeepCanonical
    } else {
      let fresh_local = next_local
      next_local += 1
      SsaFullWriteDecision::Freshen(fresh_local)
    }
    write_rewrites.push({ write_id: node_id, original_local, decision, })
  }

  let get_rewrites : Array[SsaFullGetRewrite] = []
  let merge_gets : Array[SsaFullMergeGetRewrite] = []
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::LocalGet => {
        let sources = @ir.local_graph_reaching_sources_for_get(graph, node_id)
        if sources.length() > 1 {
          match ssa_full_build_inputs_for_merge_get(graph, node_id) {
            Some(inputs) => {
              get_rewrites.push({
                get_id: node_id,
                original_local: node.imm0,
                decision: SsaFullGetDecision::Merge(next_local),
              })
              merge_gets.push({
                get_id: node_id,
                original_local: node.imm0,
                merge_local: next_local,
                inputs,
              })
              next_local += 1
            }
            None =>
              get_rewrites.push({
                get_id: node_id,
                original_local: node.imm0,
                decision: SsaFullGetDecision::KeepCanonical,
              })
          }
        } else {
          get_rewrites.push({
            get_id: node_id,
            original_local: node.imm0,
            decision: ssa_full_plan_single_get(graph, write_rewrites, node_id),
          })
        }
      }
      _ => ()
    }
  }
  { write_rewrites, get_rewrites, merge_gets, }
}

///|
fn ssa_full_build_default_value(
  func : @ir.HotFunc,
  local_id : @ir.LocalId,
) -> @ir.NodeId? {
  match @ir.hot_local_type(func, local_id) {
    Some(@lib.NumTypeValType(@lib.I32NumType)) =>
      Some(@ir.hot_build_const_i32(func, @lib.I32(0)))
    Some(@lib.NumTypeValType(@lib.I64NumType)) =>
      Some(@ir.hot_build_const_i64(func, @lib.I64(0L)))
    Some(@lib.NumTypeValType(@lib.F32NumType)) =>
      Some(@ir.hot_build_const_f32(func, @lib.F32(0.0)))
    Some(@lib.NumTypeValType(@lib.F64NumType)) =>
      Some(@ir.hot_build_const_f64(func, @lib.F64(0.0)))
    Some(@lib.VecTypeValType) => Some(@ir.hot_build_const_v128_zero(func))
    Some(@lib.RefTypeValType(ref_type)) if ref_type.is_nullable() =>
      Some(@ir.hot_build_ref_null(func, ref_type))
    _ => None
  }
}

///|
fn ssa_full_validate_write_rewrite(
  func : @ir.HotFunc,
  rewrite : SsaFullWriteRewrite,
  next_local : Int,
) -> Int? {
  if rewrite.write_id < 0 ||
    !@ir.hot_node_is_live(func, rewrite.write_id) ||
    @ir.hot_child_count(func, rewrite.write_id) != 1 {
    return None
  }
  let node = @ir.hot_node_get(func, rewrite.write_id)
  match node.op {
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => ()
    _ => return None
  }
  if node.imm0 != rewrite.original_local ||
    @ir.hot_local_type(func, rewrite.original_local) is None {
    return None
  }
  match rewrite.decision {
    SsaFullWriteDecision::Freshen(local_id) =>
      if local_id == next_local {
        Some(next_local + 1)
      } else {
        None
      }
    SsaFullWriteDecision::KeepCanonical => Some(next_local)
  }
}

///|
fn ssa_full_validate_get_rewrite(
  func : @ir.HotFunc,
  rewrite : SsaFullGetRewrite,
) -> Bool {
  if rewrite.get_id < 0 ||
    !@ir.hot_node_is_live(func, rewrite.get_id) ||
    !(@ir.hot_node_get(func, rewrite.get_id).op is @ir.HotOp::LocalGet) ||
    @ir.hot_node_get(func, rewrite.get_id).imm0 != rewrite.original_local {
    return false
  }
  match rewrite.decision {
    SsaFullGetDecision::Retarget(local_id) => local_id >= 0
    SsaFullGetDecision::MaterializeDefault =>
      match @ir.hot_local_type(func, rewrite.original_local) {
        Some(ty) => @lib.has_default(ty)
        None => false
      }
    SsaFullGetDecision::Merge(local_id) => local_id >= 0
    SsaFullGetDecision::KeepCanonical => true
  }
}

///|
fn ssa_full_validate_merge_rewrite(
  func : @ir.HotFunc,
  rewrite : SsaFullMergeGetRewrite,
  next_local : Int,
) -> Int? {
  if rewrite.merge_local != next_local ||
    rewrite.inputs.length() < 2 ||
    rewrite.get_id < 0 ||
    !@ir.hot_node_is_live(func, rewrite.get_id) ||
    !(@ir.hot_node_get(func, rewrite.get_id).op is @ir.HotOp::LocalGet) ||
    @ir.hot_node_get(func, rewrite.get_id).imm0 != rewrite.original_local ||
    @ir.hot_local_type(func, rewrite.original_local) is None {
    return None
  }
  for input in rewrite.inputs {
    match input {
      SsaFullMergeInput::ExplicitWrite(write_id) => {
        if write_id < 0 ||
          !@ir.hot_node_is_live(func, write_id) ||
          @ir.hot_child_count(func, write_id) != 1 {
          return None
        }
        let write = @ir.hot_node_get(func, write_id)
        match write.op {
          @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => ()
          _ => return None
        }
      }
      SsaFullMergeInput::ParamEntry(local_id) =>
        if local_id < 0 || local_id >= @ir.hot_param_count(func) {
          return None
        }
      SsaFullMergeInput::DefaultEntry(local_id) =>
        match @ir.hot_local_type(func, local_id) {
          Some(ty) =>
            if local_id < @ir.hot_param_count(func) || !@lib.has_default(ty) {
              return None
            }
          None => return None
        }
    }
  }
  Some(next_local + 1)
}

///|
fn ssa_full_validate_plan(
  func : @ir.HotFunc,
  plan : SsaFullRewritePlan,
) -> Bool {
  let mut next_local = @ir.hot_local_count(func)
  for rewrite in plan.write_rewrites {
    match ssa_full_validate_write_rewrite(func, rewrite, next_local) {
      Some(next) => next_local = next
      None => return false
    }
  }
  for rewrite in plan.get_rewrites {
    if !ssa_full_validate_get_rewrite(func, rewrite) {
      return false
    }
  }
  for rewrite in plan.merge_gets {
    match ssa_full_validate_merge_rewrite(func, rewrite, next_local) {
      Some(next) => next_local = next
      None => return false
    }
  }
  true
}

///|
fn ssa_full_replace_get_with_default(
  func : @ir.HotFunc,
  rewrite : SsaFullGetRewrite,
) -> Bool {
  let replacement = match
    ssa_full_build_default_value(func, rewrite.original_local) {
    Some(node_id) => node_id
    None => return false
  }
  @ir.hot_replace_node(
    func,
    rewrite.get_id,
    @ir.hot_node_get(func, replacement),
  )
  @ir.hot_delete_node(func, replacement)
  true
}

///|
fn ssa_full_apply_plan(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  plan : SsaFullRewritePlan,
) -> HotPassResult {
  if !ssa_full_validate_plan(func, plan) {
    return HotPassResult::unchanged()
  }
  let before_revision = @ir.hot_revision_current(func)

  for rewrite in plan.write_rewrites {
    match rewrite.decision {
      SsaFullWriteDecision::Freshen(local_id) => {
        let ty = @ir.hot_local_type(func, rewrite.original_local).unwrap()
        let appended = @ir.hot_append_body_local(func, ty)
        if appended != local_id {
          abort(
            "full ssa fresh-write local allocation order changed after validation",
          )
        }
        @ir.hot_local_node_id_set(func, rewrite.write_id, local_id)
      }
      SsaFullWriteDecision::KeepCanonical => ()
    }
  }

  for rewrite in plan.get_rewrites {
    match rewrite.decision {
      SsaFullGetDecision::Retarget(local_id) =>
        @ir.hot_local_node_id_set(func, rewrite.get_id, local_id)
      SsaFullGetDecision::MaterializeDefault =>
        if !ssa_full_replace_get_with_default(func, rewrite) {
          abort("full ssa default materialization changed after validation")
        }
      SsaFullGetDecision::Merge(_) | SsaFullGetDecision::KeepCanonical => ()
    }
  }

  let prepends : Array[@ir.NodeId] = []
  for rewrite in plan.merge_gets {
    let merge_ty = @ir.hot_local_type(func, rewrite.original_local).unwrap()
    let appended = @ir.hot_append_body_local(func, merge_ty)
    if appended != rewrite.merge_local {
      abort("full ssa merge-local allocation order changed after validation")
    }
    @ir.hot_local_node_id_set(func, rewrite.get_id, rewrite.merge_local)
    for input in rewrite.inputs {
      match input {
        SsaFullMergeInput::ExplicitWrite(write_id) => {
          let value_id = @ir.hot_child_get(func, write_id, 0)
          let tee_id = @ir.hot_build_local_tee(
            func,
            rewrite.merge_local,
            value_id,
          )
          @ir.hot_child_set(func, write_id, 0, tee_id)
        }
        SsaFullMergeInput::ParamEntry(local_id) => {
          let value_id = @ir.hot_build_local_get(func, local_id)
          prepends.push(
            @ir.hot_build_local_set(func, rewrite.merge_local, value_id),
          )
        }
        SsaFullMergeInput::DefaultEntry(_) => ()
      }
    }
  }
  if !prepends.is_empty() {
    @ir.hot_region_insert(func, @ir.HotRegionRef::root(), 0, prepends)
  }

  if @ir.hot_revision_current(func) == before_revision {
    HotPassResult::unchanged()
  } else {
    pass_mark_mutated(ctx, func)
    HotPassResult::changed()
  }
}

///|
priv struct SsaFullRawCursor {
  mut write_cursor : Int
  mut get_cursor : Int
  mut changed : Bool
  mut valid : Bool
  merge_locals_by_write : Array[Array[@ir.LocalId]]
}

///|
fn ssa_full_raw_merge_map(
  plan : SsaFullRewritePlan,
) -> Array[Array[@ir.LocalId]] {
  let mut max_write_id = -1
  for rewrite in plan.write_rewrites {
    if rewrite.write_id > max_write_id {
      max_write_id = rewrite.write_id
    }
  }
  let out : Array[Array[@ir.LocalId]] = []
  for _ in 0..<(max_write_id + 1) {
    out.push([])
  }
  for merge in plan.merge_gets {
    for input in merge.inputs {
      match input {
        SsaFullMergeInput::ExplicitWrite(write_id) =>
          if write_id >= 0 && write_id < out.length() {
            out[write_id].push(merge.merge_local)
          }
        _ => ()
      }
    }
  }
  out
}

///|
fn ssa_full_raw_rewrite_body(
  instrs : Array[@lib.Instruction],
  params : Array[@lib.ValType],
  locals : @lib.Locals,
  plan : SsaFullRewritePlan,
  cursor : SsaFullRawCursor,
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    match instr {
      @lib.LocalGet(@lib.LocalIdx(raw)) => {
        if cursor.get_cursor >= plan.get_rewrites.length() {
          cursor.valid = false
          out.push(instr)
          continue
        }
        let rewrite = plan.get_rewrites[cursor.get_cursor]
        cursor.get_cursor += 1
        let original_local = raw.reinterpret_as_int()
        if rewrite.original_local != original_local {
          cursor.valid = false
          out.push(instr)
          continue
        }
        match rewrite.decision {
          SsaFullGetDecision::Retarget(local_id)
          | SsaFullGetDecision::Merge(local_id) => {
            out.push(
              @lib.Instruction::local_get(
                @lib.LocalIdx::new(local_id.reinterpret_as_uint()),
              ),
            )
            if local_id != original_local {
              cursor.changed = true
            }
          }
          SsaFullGetDecision::MaterializeDefault => {
            out.push(
              run_hot_pipeline_raw_default_instr_for_local(
                params, locals, original_local,
              ),
            )
            cursor.changed = true
          }
          SsaFullGetDecision::KeepCanonical => out.push(instr)
        }
      }
      @lib.LocalSet(@lib.LocalIdx(raw)) | @lib.LocalTee(@lib.LocalIdx(raw)) => {
        if cursor.write_cursor >= plan.write_rewrites.length() {
          cursor.valid = false
          out.push(instr)
          continue
        }
        let rewrite = plan.write_rewrites[cursor.write_cursor]
        cursor.write_cursor += 1
        let original_local = raw.reinterpret_as_int()
        if rewrite.original_local != original_local {
          cursor.valid = false
          out.push(instr)
          continue
        }
        let merge_locals = if rewrite.write_id >= 0 &&
          rewrite.write_id < cursor.merge_locals_by_write.length() {
          cursor.merge_locals_by_write[rewrite.write_id]
        } else {
          []
        }
        for merge_local in merge_locals {
          out.push(
            @lib.Instruction::local_tee(
              @lib.LocalIdx::new(merge_local.reinterpret_as_uint()),
            ),
          )
          cursor.changed = true
        }
        let target_local = match rewrite.decision {
          SsaFullWriteDecision::Freshen(local_id) => {
            cursor.changed = true
            local_id
          }
          SsaFullWriteDecision::KeepCanonical => original_local
        }
        let target = @lib.LocalIdx::new(target_local.reinterpret_as_uint())
        match instr {
          @lib.LocalSet(_) => out.push(@lib.Instruction::local_set(target))
          @lib.LocalTee(_) => out.push(@lib.Instruction::local_tee(target))
          _ =>
            abort("full ssa raw local write dispatch lost its instruction kind")
        }
      }
      @lib.Block(block_type, @lib.Expr(body)) =>
        out.push(
          @lib.Instruction::block(
            block_type,
            @lib.Expr::new(
              ssa_full_raw_rewrite_body(body, params, locals, plan, cursor),
            ),
          ),
        )
      @lib.Loop(block_type, @lib.Expr(body)) =>
        out.push(
          @lib.Instruction::loop_(
            block_type,
            @lib.Expr::new(
              ssa_full_raw_rewrite_body(body, params, locals, plan, cursor),
            ),
          ),
        )
      @lib.If(block_type, then_body, else_body) => {
        let rewritten_then = ssa_full_raw_rewrite_body(
          then_body, params, locals, plan, cursor,
        )
        let rewritten_else = match else_body {
          Some(body) =>
            Some(ssa_full_raw_rewrite_body(body, params, locals, plan, cursor))
          None => None
        }
        out.push(
          @lib.Instruction::if_(block_type, rewritten_then, rewritten_else),
        )
      }
      @lib.TryTable(block_type, catches, @lib.Expr(body)) =>
        out.push(
          @lib.Instruction::try_table(
            block_type,
            catches,
            @lib.Expr::new(
              ssa_full_raw_rewrite_body(body, params, locals, plan, cursor),
            ),
          ),
        )
      _ => out.push(instr)
    }
  }
  out
}

///|
fn ssa_full_raw_prepends(plan : SsaFullRewritePlan) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  for merge in plan.merge_gets {
    for input in merge.inputs {
      match input {
        SsaFullMergeInput::ParamEntry(local_id) => {
          out.push(
            @lib.Instruction::local_get(
              @lib.LocalIdx::new(local_id.reinterpret_as_uint()),
            ),
          )
          out.push(
            @lib.Instruction::local_set(
              @lib.LocalIdx::new(merge.merge_local.reinterpret_as_uint()),
            ),
          )
        }
        _ => ()
      }
    }
  }
  out
}

///|
fn ssa_full_rewrite_raw_func(
  original : @lib.Func,
  params : Array[@lib.ValType],
  plan : SsaFullRewritePlan,
) -> (@lib.Func, Bool) {
  let @lib.Func(locals, @lib.Expr(instrs)) = original
  let cursor = {
    write_cursor: 0,
    get_cursor: 0,
    changed: false,
    valid: true,
    merge_locals_by_write: ssa_full_raw_merge_map(plan),
  }
  let rewritten_body = ssa_full_raw_rewrite_body(
    instrs, params, locals, plan, cursor,
  )
  if !cursor.valid ||
    cursor.write_cursor != plan.write_rewrites.length() ||
    cursor.get_cursor != plan.get_rewrites.length() {
    return (original, false)
  }

  let extra_local_types : Array[@lib.ValType] = []
  let mut next_local = params.length() + locals.length()
  for rewrite in plan.write_rewrites {
    match rewrite.decision {
      SsaFullWriteDecision::Freshen(local_id) => {
        if local_id != next_local {
          return (original, false)
        }
        extra_local_types.push(
          run_hot_pipeline_raw_local_type(
            params,
            locals,
            rewrite.original_local,
          ),
        )
        next_local += 1
      }
      SsaFullWriteDecision::KeepCanonical => ()
    }
  }
  for merge in plan.merge_gets {
    if merge.merge_local != next_local {
      return (original, false)
    }
    extra_local_types.push(
      run_hot_pipeline_raw_local_type(params, locals, merge.original_local),
    )
    next_local += 1
  }

  let prepends = ssa_full_raw_prepends(plan)
  let final_body = prepends
  final_body.append(rewritten_body)
  let rewritten_locals = locals.copy()
  rewritten_locals.append_types(extra_local_types)
  let changed = cursor.changed ||
    !prepends.is_empty() ||
    !extra_local_types.is_empty()
  if changed {
    (@lib.Func::new(rewritten_locals, @lib.Expr::new(final_body)), true)
  } else {
    (original, false)
  }
}

///|
fn ssa_full_run(ctx : HotPassContext, func : @ir.HotFunc) -> HotPassResult {
  let cfg = pass_require_cfg(ctx, func)
  let graph = @ir.local_graph_build_full_flow(func, cfg)
  let plan = ssa_full_build_merge_rewrite_plan(func, graph)
  ssa_full_apply_plan(ctx, func, plan)
}
