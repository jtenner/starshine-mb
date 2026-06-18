///|
pub fn pass_compute_label_used(func : @ir.HotFunc) -> @bitset.BitSet {
  let label_used = @bitset.BitSet::new(func.labels.length())
  let mark_label = fn(label_id : Int) {
    if label_id >= 0 && label_id < label_used.length() {
      label_used[label_id] = true
    }
  }
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Br
      | @ir.HotOp::BrIf
      | @ir.HotOp::BrOnNull
      | @ir.HotOp::BrOnNonNull
      | @ir.HotOp::BrOnCast
      | @ir.HotOp::BrOnCastFail
      | @ir.HotOp::Delegate => mark_label(node.imm0)
      @ir.HotOp::BrTable => {
        mark_label(@ir.hot_branch_table_default_target(func, node.imm0))
        for label_id in @ir.hot_branch_table_targets(func, node.imm0) {
          mark_label(label_id)
        }
      }
      @ir.HotOp::TryTable => {
        let info = @ir.hot_catch_info_get(func, node.imm1)
        for catch_ in info.catches {
          let label_id = match catch_ {
            @ir.HotCatchArm::CatchArm(_, label_id)
            | @ir.HotCatchArm::CatchRefArm(_, label_id)
            | @ir.HotCatchArm::CatchAllArm(label_id)
            | @ir.HotCatchArm::CatchAllRefArm(label_id) => label_id
            @ir.HotCatchArm::LegacyCatchArm(_, _)
            | @ir.HotCatchArm::LegacyCatchAllArm(_) => continue
          }
          mark_label(label_id)
        }
      }
      _ => ()
    }
  }
  label_used
}

///|
pub fn pass_label_is_used(label_id : Int, label_used : @bitset.BitSet) -> Bool {
  label_id >= 0 && label_id < label_used.length() && label_used[label_id]
}

///|
pub fn pass_rewrite_structured_instr(
  instr : @lib.Instruction,
  rewrite_instrs : (Array[@lib.Instruction]) -> (Array[@lib.Instruction], Bool),
) -> (@lib.Instruction, Bool) {
  match instr {
    @lib.Block(block_type, @lib.Expr(body)) => {
      let (next_body, changed) = rewrite_instrs(body)
      if changed {
        (@lib.Instruction::block(block_type, @lib.Expr::new(next_body)), true)
      } else {
        (instr, false)
      }
    }
    @lib.Loop(block_type, @lib.Expr(body)) => {
      let (next_body, changed) = rewrite_instrs(body)
      if changed {
        (@lib.Instruction::loop_(block_type, @lib.Expr::new(next_body)), true)
      } else {
        (instr, false)
      }
    }
    @lib.If(block_type, then_body, else_body) => {
      let (next_then, then_changed) = rewrite_instrs(then_body)
      let (next_else, else_changed) = match else_body {
        Some(body) => {
          let (next, changed) = rewrite_instrs(body)
          (Some(next), changed)
        }
        None => (None, false)
      }
      if then_changed || else_changed {
        (@lib.Instruction::if_(block_type, next_then, next_else), true)
      } else {
        (instr, false)
      }
    }
    @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
      let (next_body, changed) = rewrite_instrs(body)
      if changed {
        (
          @lib.Instruction::try_table(
            block_type,
            catches,
            @lib.Expr::new(next_body),
          ),
          true,
        )
      } else {
        (instr, false)
      }
    }
    _ => (instr, false)
  }
}

///|
pub fn pass_raw_instr_is_branch_control(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Instruction::Br(_)
    | @lib.Instruction::BrIf(_)
    | @lib.Instruction::BrTable(_, _)
    | @lib.Instruction::BrOnNull(_)
    | @lib.Instruction::BrOnNonNull(_)
    | @lib.Instruction::BrOnCast(_, _, _, _)
    | @lib.Instruction::BrOnCastFail(_, _, _, _)
    | @lib.Instruction::Return
    | @lib.Instruction::ReturnCall(_)
    | @lib.Instruction::ReturnCallIndirect(_, _)
    | @lib.Instruction::ReturnCallRef(_) => true
    _ => false
  }
}

///|
pub fn pass_raw_instrs_have_branch_control(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    if pass_raw_instr_is_branch_control(instr) {
      return true
    }
    match instr {
      @lib.Instruction::Block(_, @lib.Expr(body))
      | @lib.Instruction::Loop(_, @lib.Expr(body)) =>
        if pass_raw_instrs_have_branch_control(body) {
          return true
        }
      @lib.Instruction::If(_, then_body, Some(else_body)) =>
        if pass_raw_instrs_have_branch_control(then_body) ||
          pass_raw_instrs_have_branch_control(else_body) {
          return true
        }
      @lib.Instruction::If(_, then_body, None) =>
        if pass_raw_instrs_have_branch_control(then_body) {
          return true
        }
      @lib.Instruction::TryTable(_, _, @lib.Expr(body)) =>
        if pass_raw_instrs_have_branch_control(body) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
pub fn pass_raw_instrs_end_in_unreachable(
  instrs : Array[@lib.Instruction],
) -> Bool {
  if instrs.length() == 0 {
    return false
  }
  match instrs[instrs.length() - 1] {
    @lib.Instruction::Unreachable => true
    _ => false
  }
}

///|
pub fn pass_raw_dropped_block_has_unreachable_tail(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.Instruction::Block(_, @lib.Expr(body)) =>
      pass_raw_instrs_end_in_unreachable(body) &&
      !pass_raw_instrs_have_branch_control(body)
    _ => false
  }
}

///|
pub fn pass_raw_void_block_can_inline_before_unreachable(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.Instruction::Block(_, @lib.Expr(body)) =>
      !pass_raw_instrs_have_branch_control(body)
    _ => false
  }
}

///|
pub fn pass_raw_collapse_trailing_unreachable_run(
  instrs : Array[@lib.Instruction],
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  let mut end = instrs.length()
  while end > 0 {
    match instrs[end - 1] {
      @lib.Instruction::Unreachable => end -= 1
      _ => break
    }
  }
  if end == instrs.length() {
    for instr in instrs {
      out.push(instr)
    }
    return out
  }
  for idx = 0; idx < end; idx = idx + 1 {
    out.push(instrs[idx])
  }
  out.push(@lib.Instruction::unreachable_())
  out
}

///|
pub fn pass_raw_remove_dropped_unreachable_debris(
  instrs : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Bool) {
  let out : Array[@lib.Instruction] = []
  let mut changed = false
  let mut i = 0
  while i < instrs.length() {
    match instrs[i] {
      @lib.Instruction::Unreachable | @lib.Instruction::Block(_, _) => {
        let mut j = i + 1
        while j < instrs.length() {
          match instrs[j] {
            @lib.Instruction::Drop => j += 1
            _ => break
          }
        }
        if j < instrs.length() {
          match instrs[j] {
            @lib.Instruction::Unreachable =>
              match instrs[i] {
                @lib.Instruction::Unreachable => {
                  changed = true
                  i = j
                  continue
                }
                @lib.Instruction::Block(_, @lib.Expr(body)) =>
                  if pass_raw_dropped_block_has_unreachable_tail(instrs[i]) {
                    let collapsed = pass_raw_collapse_trailing_unreachable_run(
                      body,
                    )
                    let (cleaned_body, _) = pass_raw_remove_dropped_unreachable_debris(
                      collapsed,
                    )
                    for body_instr in cleaned_body {
                      out.push(body_instr)
                    }
                    changed = true
                    i = j + 1
                    continue
                  } else if pass_raw_void_block_can_inline_before_unreachable(
                      instrs[i],
                    ) {
                    let (cleaned_body, _) = pass_raw_remove_dropped_unreachable_debris(
                      body,
                    )
                    for body_instr in cleaned_body {
                      out.push(body_instr)
                    }
                    changed = true
                    i += 1
                    continue
                  }
                _ => ()
              }
            _ => ()
          }
        }
      }
      _ => ()
    }
    let rewritten_instr = match instrs[i] {
      @lib.Instruction::Block(block_type, @lib.Expr(body)) => {
        let (next_body, body_changed) = pass_raw_remove_dropped_unreachable_debris(
          body,
        )
        if body_changed {
          changed = true
        }
        @lib.Instruction::block(block_type, @lib.Expr::new(next_body))
      }
      @lib.Instruction::Loop(block_type, @lib.Expr(body)) => {
        let (next_body, body_changed) = pass_raw_remove_dropped_unreachable_debris(
          body,
        )
        if body_changed {
          changed = true
        }
        @lib.Instruction::loop_(block_type, @lib.Expr::new(next_body))
      }
      @lib.Instruction::If(block_type, then_body, else_body) => {
        let (next_then, then_changed) = pass_raw_remove_dropped_unreachable_debris(
          then_body,
        )
        let (next_else, else_changed) = match else_body {
          Some(body) => {
            let (body2, changed2) = pass_raw_remove_dropped_unreachable_debris(
              body,
            )
            (Some(body2), changed2)
          }
          None => (None, false)
        }
        if then_changed || else_changed {
          changed = true
        }
        @lib.Instruction::if_(block_type, next_then, next_else)
      }
      @lib.Instruction::TryTable(block_type, catches, @lib.Expr(body)) => {
        let (next_body, body_changed) = pass_raw_remove_dropped_unreachable_debris(
          body,
        )
        if body_changed {
          changed = true
        }
        @lib.Instruction::try_table(
          block_type,
          catches,
          @lib.Expr::new(next_body),
        )
      }
      other => other
    }
    out.push(rewritten_instr)
    i += 1
  }
  (out, changed)
}

///|
pub fn pass_prepare_requirements(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> Unit {
  for analysis in @ir.hot_pass_requires(ctx.descriptor) {
    match analysis {
      @ir.HotAnalysis::Cfg => ignore(pass_require_cfg(ctx, func))
      @ir.HotAnalysis::Dominance => ignore(pass_require_dom(ctx, func))
      @ir.HotAnalysis::Liveness => ignore(pass_require_liveness(ctx, func))
      @ir.HotAnalysis::UseDef => ignore(pass_require_use_def(ctx, func))
      @ir.HotAnalysis::Effects => ignore(pass_require_effects(ctx, func))
      @ir.HotAnalysis::LoopInfo => ignore(pass_require_loop_info(ctx, func))
      @ir.HotAnalysis::Ssa => ignore(pass_require_ssa(ctx, func))
    }
  }
}

///|
pub fn pass_require_cfg(ctx : HotPassContext, func : @ir.HotFunc) -> @ir.HotCfg {
  let revision = @ir.hot_revision_current(func)
  let is_current = match ctx.cache.cfg {
    Some(entry) => entry.built_at_revision == revision
    None => false
  }
  if is_current {
    return @ir.cache_get_or_build_cfg(ctx.cache, func)
  }
  let start_us = perf_start_timer_opt(ctx.perf, "analysis:cfg")
  let cfg = @ir.cache_get_or_build_cfg(ctx.cache, func)
  perf_stop_timer_opt(ctx.perf, "analysis:cfg", start_us)
  match ctx.perf {
    Some(perf) => {
      perf_count_cfg_build(perf)
      perf_count_traversal_visit(perf, count=@ir.cfg_block_count(cfg))
      perf_dump_cfg(perf, cfg, "analysis:cfg")
    }
    None => ()
  }
  cfg
}

///|
pub fn pass_require_orders(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> @ir.HotCfgOrders {
  let revision = @ir.hot_revision_current(func)
  let is_current = match ctx.cache.orders {
    Some(entry) => entry.built_at_revision == revision
    None => false
  }
  if is_current {
    return @ir.cache_get_or_build_orders(ctx.cache, func)
  }
  let start_us = perf_start_timer_opt(ctx.perf, "analysis:orders")
  let orders = @ir.cache_get_or_build_orders(ctx.cache, func)
  perf_stop_timer_opt(ctx.perf, "analysis:orders", start_us)
  match ctx.perf {
    Some(perf) => {
      perf_count_dataflow_build(perf, "orders")
      perf_count_traversal_visit(perf, count=orders.worklist_seed.length())
    }
    None => ()
  }
  orders
}

///|
pub fn pass_require_dom(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> @ir.HotDominators {
  let revision = @ir.hot_revision_current(func)
  let is_current = match ctx.cache.dom {
    Some(entry) => entry.built_at_revision == revision
    None => false
  }
  if is_current {
    return @ir.cache_get_or_build_dom(ctx.cache, func)
  }
  let start_us = perf_start_timer_opt(ctx.perf, "analysis:dom")
  let dom = @ir.cache_get_or_build_dom(ctx.cache, func)
  perf_stop_timer_opt(ctx.perf, "analysis:dom", start_us)
  match ctx.perf {
    Some(perf) => {
      perf_count_dataflow_build(perf, "dom")
      perf_count_traversal_visit(
        perf,
        count=@ir.cfg_block_count(pass_require_cfg(ctx, func)),
      )
    }
    None => ()
  }
  dom
}

///|
pub fn pass_require_postdom(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> @ir.HotPostDominators {
  let revision = @ir.hot_revision_current(func)
  let is_current = match ctx.cache.postdom {
    Some(entry) => entry.built_at_revision == revision
    None => false
  }
  if is_current {
    return @ir.cache_get_or_build_postdom(ctx.cache, func)
  }
  let start_us = perf_start_timer_opt(ctx.perf, "analysis:postdom")
  let postdom = @ir.cache_get_or_build_postdom(ctx.cache, func)
  perf_stop_timer_opt(ctx.perf, "analysis:postdom", start_us)
  match ctx.perf {
    Some(perf) => {
      perf_count_dataflow_build(perf, "postdom")
      perf_count_traversal_visit(
        perf,
        count=@ir.cfg_block_count(pass_require_cfg(ctx, func)),
      )
    }
    None => ()
  }
  postdom
}

///|
pub fn pass_require_loop_info(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> @ir.HotLoopInfo {
  let revision = @ir.hot_revision_current(func)
  let is_current = match ctx.cache.loop_info {
    Some(entry) => entry.built_at_revision == revision
    None => false
  }
  if is_current {
    return @ir.cache_get_or_build_loop_info(ctx.cache, func)
  }
  let start_us = perf_start_timer_opt(ctx.perf, "analysis:loop-info")
  let loop_info = @ir.cache_get_or_build_loop_info(ctx.cache, func)
  perf_stop_timer_opt(ctx.perf, "analysis:loop-info", start_us)
  match ctx.perf {
    Some(perf) => {
      perf_count_dataflow_build(perf, "loop-info")
      perf_count_traversal_visit(
        perf,
        count=@ir.cfg_block_count(pass_require_cfg(ctx, func)),
      )
    }
    None => ()
  }
  loop_info
}

///|
pub fn pass_require_use_def(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> @ir.HotUseDef {
  let revision = @ir.hot_revision_current(func)
  let is_current = match ctx.cache.use_def {
    Some(entry) => entry.built_at_revision == revision
    None => false
  }
  if is_current {
    return @ir.cache_get_or_build_use_def(ctx.cache, func)
  }
  let start_us = perf_start_timer_opt(ctx.perf, "analysis:use-def")
  let use_def = @ir.cache_get_or_build_use_def(ctx.cache, func)
  perf_stop_timer_opt(ctx.perf, "analysis:use-def", start_us)
  match ctx.perf {
    Some(perf) => {
      perf_count_dataflow_build(perf, "use-def")
      perf_count_traversal_visit(perf, count=@ir.hot_node_count(func))
    }
    None => ()
  }
  use_def
}

///|
pub fn pass_require_liveness(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> @ir.HotLiveness {
  let revision = @ir.hot_revision_current(func)
  let is_current = match ctx.cache.liveness {
    Some(entry) => entry.built_at_revision == revision
    None => false
  }
  if is_current {
    return @ir.cache_get_or_build_liveness(ctx.cache, func)
  }
  let start_us = perf_start_timer_opt(ctx.perf, "analysis:liveness")
  let liveness = @ir.cache_get_or_build_liveness(ctx.cache, func)
  perf_stop_timer_opt(ctx.perf, "analysis:liveness", start_us)
  match ctx.perf {
    Some(perf) => {
      perf_count_dataflow_build(perf, "liveness")
      perf_count_traversal_visit(
        perf,
        count=@ir.cfg_block_count(pass_require_cfg(ctx, func)),
      )
    }
    None => ()
  }
  liveness
}

///|
pub fn pass_require_effects(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> @ir.HotEffectsSummary {
  let revision = @ir.hot_revision_current(func)
  let is_current = match ctx.cache.effects {
    Some(entry) => entry.built_at_revision == revision
    None => false
  }
  if is_current {
    return @ir.cache_get_or_build_effects(ctx.cache, func)
  }
  let start_us = perf_start_timer_opt(ctx.perf, "analysis:effects")
  let effects = @ir.cache_get_or_build_effects(ctx.cache, func)
  perf_stop_timer_opt(ctx.perf, "analysis:effects", start_us)
  match ctx.perf {
    Some(perf) => {
      perf_count_dataflow_build(perf, "effects")
      perf_count_traversal_visit(perf, count=@ir.hot_node_count(func))
    }
    None => ()
  }
  effects
}

///|
pub fn pass_require_ssa(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> @ir.HotLocalSsa {
  let revision = @ir.hot_revision_current(func)
  let is_current = match ctx.cache.ssa {
    Some(entry) => entry.built_at_revision == revision
    None => false
  }
  if is_current {
    return @ir.cache_get_or_build_ssa(ctx.cache, func)
  }
  let start_us = perf_start_timer_opt(ctx.perf, "analysis:ssa")
  let ssa = @ir.cache_get_or_build_ssa(ctx.cache, func)
  perf_stop_timer_opt(ctx.perf, "analysis:ssa", start_us)
  match ctx.perf {
    Some(perf) => {
      perf_count_dataflow_build(perf, "ssa")
      perf_count_traversal_visit(
        perf,
        count=@ir.cfg_block_count(pass_require_cfg(ctx, func)),
      )
    }
    None => ()
  }
  ssa
}

///|
pub fn pass_mark_mutated(ctx : HotPassContext, func : @ir.HotFunc) -> Unit {
  @ir.cache_invalidate_all(ctx.cache)
  pipeline_trace_hook(
    ctx.trace,
    ctx.descriptor.name,
    "mutated",
    payload="revision=\{@ir.hot_revision_current(func)}",
  )
}

///|
pub fn pass_replace_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  new_node : @ir.HotNode,
) -> Unit {
  @ir.hot_replace_node(func, node_id, new_node)
  pass_mark_mutated(ctx, func)
}

///|
pub fn pass_splice_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  remove_count : Int,
  node_ids : Array[Int],
) -> Array[Int] {
  let removed = @ir.hot_region_splice(
    func, region_ref, idx, remove_count, node_ids,
  )
  if remove_count != 0 || !node_ids.is_empty() {
    match ctx.perf {
      Some(perf) => perf_count_region_splice(perf)
      None => ()
    }
    pass_mark_mutated(ctx, func)
  }
  removed
}

///|
pub fn pass_delete_detached_nodes(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_ids : Array[Int],
) -> Unit {
  let mut changed = false
  for node_id in node_ids {
    if @ir.hot_node_is_live(func, node_id) {
      @ir.hot_delete_node(func, node_id)
      changed = true
    }
  }
  if changed {
    pass_mark_mutated(ctx, func)
  }
}

///|
pub fn pass_node_use_count(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Int {
  @ir.node_use_count(pass_require_use_def(ctx, func), node_id)
}

///|
pub fn pass_node_is_unused(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  pass_node_use_count(ctx, func, node_id) == 0
}

///|
pub fn pass_verify_before_after(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> Result[Unit, String] {
  match
    pipeline_verify_checkpoint_with_perf(
      ctx.perf,
      ctx.verify_policy,
      "verify before \{ctx.descriptor.name}",
      HotPipelineVerifyTarget::HotFuncTarget(func),
      "verify:before:\{ctx.descriptor.name}",
    ) {
    Ok(_) =>
      pipeline_verify_checkpoint_with_perf(
        ctx.perf,
        ctx.verify_policy,
        "verify after \{ctx.descriptor.name}",
        HotPipelineVerifyTarget::HotFuncTarget(func),
        "verify:after:\{ctx.descriptor.name}",
      )
    Err(err) => Err(err)
  }
}
