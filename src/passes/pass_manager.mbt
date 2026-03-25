///|
pub enum HotPipelineVerifyPolicy {
  FinalModuleOnly
  AfterEachPass
} derive(Eq, Show, Debug)

///|
pub fn HotPipelineVerifyPolicy::final_module_only() -> HotPipelineVerifyPolicy {
  FinalModuleOnly
}

///|
pub fn HotPipelineVerifyPolicy::after_each_pass() -> HotPipelineVerifyPolicy {
  AfterEachPass
}

///|
fn hot_pipeline_trace_noop(_ : String) -> Unit {
  ()
}

///|
pub struct HotPipelineOptions {
  verify_policy : HotPipelineVerifyPolicy
  validate_final_module : Bool
  trace : (String) -> Unit
}

///|
pub fn HotPipelineOptions::new(
  verify_policy? : HotPipelineVerifyPolicy = HotPipelineVerifyPolicy::final_module_only(),
  validate_final_module? : Bool = true,
  trace? : ((String) -> Unit)? = None,
) -> HotPipelineOptions {
  {
    verify_policy,
    validate_final_module,
    trace: match trace {
      Some(cb) => cb
      None => hot_pipeline_trace_noop
    },
  }
}

///|
pub struct HotPassContext {
  descriptor : @ir.HotPassDescriptor
  cache : @ir.HotAnalysisCache
  verify_policy : HotPipelineVerifyPolicy
  trace : (String) -> Unit
}

///|
pub fn HotPassContext::new(
  descriptor : @ir.HotPassDescriptor,
  cache : @ir.HotAnalysisCache,
  verify_policy : HotPipelineVerifyPolicy,
  trace : (String) -> Unit,
) -> HotPassContext {
  { descriptor, cache, verify_policy, trace }
}

///|
pub struct HotPassResult {
  changed : Bool
} derive(Eq, Show, Debug)

///|
pub fn HotPassResult::unchanged() -> HotPassResult {
  { changed: false }
}

///|
pub fn HotPassResult::changed() -> HotPassResult {
  { changed: true }
}

///|
pub fn pipeline_trace_hook(
  trace : (String) -> Unit,
  pass_name : String,
  event : String,
  payload? : String = "",
) -> Unit {
  let suffix = if payload == "" { "" } else { " \{payload}" }
  trace("pass[\{pass_name}]:\{event}\{suffix}")
}

///|
pub enum HotPipelineVerifyTarget {
  HotFuncTarget(@ir.HotFunc)
  ModuleTarget(@lib.Module)
}

///|
pub fn pipeline_verify_checkpoint(
  policy : HotPipelineVerifyPolicy,
  label : String,
  target : HotPipelineVerifyTarget,
) -> Result[Unit, String] {
  match policy {
    HotPipelineVerifyPolicy::FinalModuleOnly =>
      match target {
        HotPipelineVerifyTarget::ModuleTarget(mod_) =>
          match @validate.validate_module(mod_) {
            Ok(_) => Ok(())
            Err(err) => Err("\{label}: \{err}")
          }
        HotPipelineVerifyTarget::HotFuncTarget(_) => Ok(())
      }
    HotPipelineVerifyPolicy::AfterEachPass =>
      match target {
        HotPipelineVerifyTarget::HotFuncTarget(func) => {
          match @ir.hot_verify_core(func) {
            Ok(_) => ()
            Err(err) => return Err("\{label}: \{err}")
          }
          match @ir.hot_verify_control(func) {
            Ok(_) => Ok(())
            Err(err) => Err("\{label}: \{err}")
          }
        }
        HotPipelineVerifyTarget::ModuleTarget(mod_) =>
          match @validate.validate_module(mod_) {
            Ok(_) => Ok(())
            Err(err) => Err("\{label}: \{err}")
          }
      }
  }
}

///|
fn hot_pass_prepare_analyses(
  cache : @ir.HotAnalysisCache,
  func : @ir.HotFunc,
  descriptor : @ir.HotPassDescriptor,
) -> Unit {
  for analysis in @ir.hot_pass_requires(descriptor) {
    match analysis {
      @ir.HotAnalysis::Cfg => ignore(@ir.cache_get_or_build_cfg(cache, func))
      @ir.HotAnalysis::Dominance =>
        ignore(@ir.cache_get_or_build_dom(cache, func))
      @ir.HotAnalysis::Liveness =>
        ignore(@ir.cache_get_or_build_liveness(cache, func))
      @ir.HotAnalysis::UseDef =>
        ignore(@ir.cache_get_or_build_use_def(cache, func))
      @ir.HotAnalysis::Effects =>
        ignore(@ir.cache_get_or_build_effects(cache, func))
      @ir.HotAnalysis::LoopInfo =>
        ignore(@ir.cache_get_or_build_loop_info(cache, func))
      @ir.HotAnalysis::Ssa => ignore(@ir.cache_get_or_build_ssa(cache, func))
    }
  }
}

///|
fn hot_pass_remove_region_nops(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let mut changed = false
  let mut idx = 0
  while idx < @ir.hot_region_root_count(func, region_ref) {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Nop => {
        let removed = @ir.hot_region_remove(func, region_ref, idx, 1)
        for removed_id in removed {
          @ir.hot_delete_node(func, removed_id)
        }
        changed = true
        continue
      }
      @ir.HotOp::Block | @ir.HotOp::Loop =>
        changed = hot_pass_remove_region_nops(
            func,
            @ir.hot_region_body_ref(func, node_id),
          ) ||
          changed
      @ir.HotOp::If => {
        changed = hot_pass_remove_region_nops(
            func,
            @ir.hot_region_then_ref(func, node_id),
          ) ||
          changed
        match @ir.hot_region_else_ref(func, node_id) {
          Some(else_region) =>
            changed = hot_pass_remove_region_nops(func, else_region) || changed
          None => ()
        }
      }
      @ir.HotOp::Try => {
        changed = hot_pass_remove_region_nops(
            func,
            @ir.hot_region_body_ref(func, node_id),
          ) ||
          changed
        match @ir.hot_region_catch_ref(func, node_id) {
          Some(catch_region) =>
            changed = hot_pass_remove_region_nops(func, catch_region) || changed
          None => ()
        }
      }
      @ir.HotOp::TryTable => {
        changed = hot_pass_remove_region_nops(
            func,
            @ir.hot_region_body_ref(func, node_id),
          ) ||
          changed
        changed = hot_pass_remove_region_nops(
            func,
            @ir.hot_region_catch_list_ref(func, node_id),
          ) ||
          changed
      }
      _ => ()
    }
    idx += 1
  }
  changed
}

///|
pub fn hot_pass_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> Result[HotPassResult, String] {
  let descriptor = ctx.descriptor
  hot_pass_prepare_analyses(ctx.cache, func, descriptor)
  pipeline_trace_hook(ctx.trace, descriptor.name, "start")
  let before_revision = @ir.hot_revision_current(func)
  let result = match descriptor.name {
    "vacuum" =>
      if hot_pass_remove_region_nops(func, @ir.HotRegionRef::root()) {
        HotPassResult::changed()
      } else {
        HotPassResult::unchanged()
      }
    _ => return Err("unsupported hot pass \{descriptor.name}")
  }
  if @ir.hot_revision_current(func) != before_revision {
    @ir.cache_invalidate_all(ctx.cache)
  }
  match
    pipeline_verify_checkpoint(
      ctx.verify_policy,
      "verify after \{descriptor.name}",
      HotPipelineVerifyTarget::HotFuncTarget(func),
    ) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  pipeline_trace_hook(
    ctx.trace,
    descriptor.name,
    "done",
    payload="changed=\{result.changed}",
  )
  Ok(result)
}
