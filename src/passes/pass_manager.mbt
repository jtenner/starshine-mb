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
  closed_world : Bool
  trace : (String) -> Unit
  perf : HotPerfSession?
}

///|
pub fn HotPipelineOptions::new(
  verify_policy? : HotPipelineVerifyPolicy = HotPipelineVerifyPolicy::final_module_only(),
  validate_final_module? : Bool = true,
  closed_world? : Bool = false,
  trace? : ((String) -> Unit)? = None,
  perf? : HotPerfSession? = None,
) -> HotPipelineOptions {
  {
    verify_policy,
    validate_final_module,
    closed_world,
    trace: match trace {
      Some(cb) => cb
      None => hot_pipeline_trace_noop
    },
    perf,
  }
}

///|
pub struct HotPassContext {
  descriptor : @ir.HotPassDescriptor
  cache : @ir.HotAnalysisCache
  verify_policy : HotPipelineVerifyPolicy
  closed_world : Bool
  trace : (String) -> Unit
  perf : HotPerfSession?
}

///|
pub fn HotPassContext::new(
  descriptor : @ir.HotPassDescriptor,
  cache : @ir.HotAnalysisCache,
  verify_policy : HotPipelineVerifyPolicy,
  closed_world : Bool,
  trace : (String) -> Unit,
  perf? : HotPerfSession? = None,
) -> HotPassContext {
  { descriptor, cache, verify_policy, closed_world, trace, perf }
}

///|
fn perf_start_timer_opt(perf : HotPerfSession?, name : String) -> UInt64 {
  match perf {
    Some(session) => perf_start_timer(session, name)
    None => 0UL
  }
}

///|
fn perf_stop_timer_opt(
  perf : HotPerfSession?,
  name : String,
  start_us : UInt64,
) -> Unit {
  match perf {
    Some(session) => perf_stop_timer(session, name, start_us)
    None => ()
  }
}

///|
fn perf_validation_checkpoint_opt(
  perf : HotPerfSession?,
  name : String,
) -> Unit {
  match perf {
    Some(session) => perf_validation_checkpoint(session, name)
    None => ()
  }
}

///|
fn perf_dump_hot_func_opt(
  perf : HotPerfSession?,
  func : @ir.HotFunc,
  label : String,
) -> Unit {
  match perf {
    Some(session) => perf_dump_hot_func(session, func, label)
    None => ()
  }
}

///|
fn perf_emit_counters_opt(perf : HotPerfSession?, label : String) -> Unit {
  match perf {
    Some(session) => perf_emit_counters(session, label)
    None => ()
  }
}

///|
fn pipeline_verify_checkpoint_with_perf(
  perf : HotPerfSession?,
  policy : HotPipelineVerifyPolicy,
  label : String,
  target : HotPipelineVerifyTarget,
  timer_name : String,
) -> Result[Unit, String] {
  let start_us = perf_start_timer_opt(perf, timer_name)
  let result = pipeline_verify_checkpoint(policy, label, target)
  perf_stop_timer_opt(perf, timer_name, start_us)
  match result {
    Ok(_) => {
      perf_validation_checkpoint_opt(perf, label)
      Ok(())
    }
    Err(err) => Err(err)
  }
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
fn pass_manager_debug_node_tag(func : @ir.HotFunc, node_id : Int) -> String {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet | @ir.HotOp::LocalSet | @ir.HotOp::LocalTee =>
      "\{node.op}(\{node.imm0})#\{node_id}"
    _ => "\{node.op}#\{node_id}"
  }
}

///|
fn pass_manager_debug_dump_target_regions_visit(
  trace : (String) -> Unit,
  func : @ir.HotFunc,
  stage : String,
  region_ref : @ir.HotRegionRef,
) -> Unit {
  let roots : Array[String] = []
  let mut saw_target = false
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    let tag = pass_manager_debug_node_tag(func, node_id)
    roots.push(tag)
    if tag.contains("(35)") || tag.contains("(36)") || tag.contains("(37)") ||
      tag.contains("(38)") || tag.contains("(39)") || tag.contains("(40)") ||
      tag.contains("(97)") || tag.contains("(98)") || tag.contains("(99)") {
      saw_target = true
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Block | @ir.HotOp::Loop =>
        pass_manager_debug_dump_target_regions_visit(
          trace,
          func,
          stage,
          @ir.hot_region_body_ref(func, node_id),
        )
      @ir.HotOp::If => {
        pass_manager_debug_dump_target_regions_visit(
          trace,
          func,
          stage,
          @ir.hot_region_then_ref(func, node_id),
        )
        match @ir.hot_region_else_ref(func, node_id) {
          Some(else_region) =>
            pass_manager_debug_dump_target_regions_visit(
              trace,
              func,
              stage,
              else_region,
            )
          None => ()
        }
      }
      @ir.HotOp::Try => {
        pass_manager_debug_dump_target_regions_visit(
          trace,
          func,
          stage,
          @ir.hot_region_body_ref(func, node_id),
        )
        match @ir.hot_region_catch_ref(func, node_id) {
          Some(catch_region) =>
            pass_manager_debug_dump_target_regions_visit(
              trace,
              func,
              stage,
              catch_region,
            )
          None => ()
        }
      }
      @ir.HotOp::TryTable => {
        pass_manager_debug_dump_target_regions_visit(
          trace,
          func,
          stage,
          @ir.hot_region_body_ref(func, node_id),
        )
        pass_manager_debug_dump_target_regions_visit(
          trace,
          func,
          stage,
          @ir.hot_region_catch_list_ref(func, node_id),
        )
      }
      _ => ()
    }
  }
  if saw_target {
    let region_label = if region_ref == @ir.HotRegionRef::root() {
      "root"
    } else {
      "holder=\{region_ref.holder}"
    }
    trace("debug[\{stage}]:region \{region_label} roots=\{roots}")
  }
}

///|
fn pass_manager_debug_dump_target_regions(
  trace : (String) -> Unit,
  func : @ir.HotFunc,
  stage : String,
) -> Unit {
  pass_manager_debug_dump_target_regions_visit(
    trace,
    func,
    stage,
    @ir.HotRegionRef::root(),
  )
}

///|
fn pass_manager_debug_dump_node(
  trace : (String) -> Unit,
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  stage : String,
  node_id : Int,
) -> Unit {
  if !@ir.hot_node_is_live(func, node_id) {
    trace("debug[\{stage}]:node \{node_id} dead")
    return
  }
  let node = @ir.hot_node_get(func, node_id)
  let children : Array[String] = []
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    let child_id = @ir.hot_child_get(func, node_id, slot)
    children.push("\{slot}=\{child_id}")
  }
  trace(
    "debug[\{stage}]:node \{node_id} tag=\{pass_manager_debug_node_tag(func, node_id)} ty=\{node.ty} children=\{children} uses=\{@ir.node_use_count(use_def, node_id)}",
  )
}

///|
fn pass_manager_debug_dump_matching_nodes(
  trace : (String) -> Unit,
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  stage : String,
) -> Unit {
  for node_id = 0; node_id < func.nodes.length(); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let tag = pass_manager_debug_node_tag(func, node_id)
    if tag.contains("LocalSet(35)") || tag.contains("LocalSet(36)") ||
      tag.contains("LocalSet(37)") {
      pass_manager_debug_dump_node(trace, func, use_def, stage, node_id)
    }
  }
}

///|
fn pass_manager_debug_dump_root_prefix(
  trace : (String) -> Unit,
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  stage : String,
  count : Int,
) -> Unit {
  let limit = if count < @ir.hot_root_count(func) {
    count
  } else {
    @ir.hot_root_count(func)
  }
  for i = 0; i < limit; i = i + 1 {
    let node_id = @ir.hot_root_get(func, i)
    pass_manager_debug_dump_node(
      trace,
      func,
      use_def,
      "\{stage}:root[\{i}]",
      node_id,
    )
  }
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
fn hot_pass_remove_region_nops(
  ctx : HotPassContext,
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
        let removed = pass_splice_region(ctx, func, region_ref, idx, 1, [])
        pass_delete_detached_nodes(ctx, func, removed)
        changed = true
        continue
      }
      @ir.HotOp::Block | @ir.HotOp::Loop =>
        changed = hot_pass_remove_region_nops(
            ctx,
            func,
            @ir.hot_region_body_ref(func, node_id),
          ) ||
          changed
      @ir.HotOp::If => {
        changed = hot_pass_remove_region_nops(
            ctx,
            func,
            @ir.hot_region_then_ref(func, node_id),
          ) ||
          changed
        match @ir.hot_region_else_ref(func, node_id) {
          Some(else_region) =>
            changed = hot_pass_remove_region_nops(ctx, func, else_region) ||
              changed
          None => ()
        }
      }
      @ir.HotOp::Try => {
        changed = hot_pass_remove_region_nops(
            ctx,
            func,
            @ir.hot_region_body_ref(func, node_id),
          ) ||
          changed
        match @ir.hot_region_catch_ref(func, node_id) {
          Some(catch_region) =>
            changed = hot_pass_remove_region_nops(ctx, func, catch_region) ||
              changed
          None => ()
        }
      }
      @ir.HotOp::TryTable => {
        changed = hot_pass_remove_region_nops(
            ctx,
            func,
            @ir.hot_region_body_ref(func, node_id),
          ) ||
          changed
        changed = hot_pass_remove_region_nops(
            ctx,
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
fn run_hot_pipeline_func(
  mod_ : @lib.Module,
  func_idx : @lib.FuncIdx,
  descriptor : @ir.HotPassDescriptor,
  options : HotPipelineOptions,
) -> Result[@lib.Func, String] {
  pipeline_trace_hook(
    options.trace,
    descriptor.name,
    "func",
    payload="func_idx=\{func_idx}",
  )
  let lift_start_us = perf_start_timer_opt(options.perf, "lift")
  let func = @ir.hot_lift_func(mod_, func_idx)
  if func_idx == @lib.FuncIdx::new(2944U) &&
    (descriptor.name == "vacuum" || descriptor.name == "dead-code-elimination") {
    let use_def = @ir.use_def_build(func)
    pass_manager_debug_dump_root_prefix(
      options.trace,
      func,
      use_def,
      "after-lift:\{descriptor.name}",
      40,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-lift:\{descriptor.name}",
      0,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-lift:\{descriptor.name}",
      181,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-lift:\{descriptor.name}",
      182,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-lift:\{descriptor.name}",
      183,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-lift:\{descriptor.name}",
      557,
    )
    for node_id in [552, 553, 554, 555, 556, 558, 559, 560, 561, 562, 563] {
      pass_manager_debug_dump_node(
        options.trace,
        func,
        use_def,
        "after-lift:\{descriptor.name}",
        node_id,
      )
    }
  }
  if func_idx == @lib.FuncIdx::new(2941U) &&
    (descriptor.name == "vacuum" || descriptor.name == "dead-code-elimination") {
    let use_def = @ir.use_def_build(func)
    pass_manager_debug_dump_target_regions(
      options.trace,
      func,
      "after-lift:\{descriptor.name}",
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-lift:\{descriptor.name}",
      581,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-lift:\{descriptor.name}",
      582,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-lift:\{descriptor.name}",
      1253,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-lift:\{descriptor.name}",
      1254,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-lift:\{descriptor.name}",
      1255,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-lift:\{descriptor.name}",
      1256,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-lift:\{descriptor.name}",
      1257,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-lift:\{descriptor.name}",
      1258,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-lift:\{descriptor.name}",
      1259,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-lift:\{descriptor.name}",
      1260,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-lift:\{descriptor.name}",
      1261,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-lift:\{descriptor.name}",
      1262,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-lift:\{descriptor.name}",
      1263,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-lift:\{descriptor.name}",
      1264,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-lift:\{descriptor.name}",
      1265,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-lift:\{descriptor.name}",
      1266,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-lift:\{descriptor.name}",
      1267,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-lift:\{descriptor.name}",
      1268,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-lift:\{descriptor.name}",
      1269,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-lift:\{descriptor.name}",
      1270,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-lift:\{descriptor.name}",
      1271,
    )
    pass_manager_debug_dump_matching_nodes(
      options.trace,
      func,
      use_def,
      "after-lift:\{descriptor.name}",
    )
  }
  match options.perf {
    Some(perf) => {
      perf_count_hot_alloc_delta(
        perf,
        HotPerfHotSnapshot::empty(),
        perf_snapshot_hot_func(func),
      )
      perf_dump_hot_func(perf, func, "after-lift")
    }
    None => ()
  }
  perf_stop_timer_opt(options.perf, "lift", lift_start_us)
  match
    pipeline_verify_checkpoint_with_perf(
      options.perf,
      HotPipelineVerifyPolicy::AfterEachPass,
      "verify after lift",
      HotPipelineVerifyTarget::HotFuncTarget(func),
      "verify:after-lift",
    ) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  let cache = @ir.HotAnalysisCache::new()
  let ctx = HotPassContext::new(
    descriptor,
    cache,
    options.verify_policy,
    options.closed_world,
    options.trace,
    perf=options.perf,
  )
  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  if func_idx == @lib.FuncIdx::new(2944U) &&
    (descriptor.name == "vacuum" || descriptor.name == "dead-code-elimination") {
    let use_def = @ir.use_def_build(func)
    pass_manager_debug_dump_root_prefix(
      options.trace,
      func,
      use_def,
      "after-pass:\{descriptor.name}",
      40,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-pass:\{descriptor.name}",
      0,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-pass:\{descriptor.name}",
      181,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-pass:\{descriptor.name}",
      182,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-pass:\{descriptor.name}",
      183,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-pass:\{descriptor.name}",
      557,
    )
    for node_id in [552, 553, 554, 555, 556, 558, 559, 560, 561, 562, 563] {
      pass_manager_debug_dump_node(
        options.trace,
        func,
        use_def,
        "after-pass:\{descriptor.name}",
        node_id,
      )
    }
  }
  if func_idx == @lib.FuncIdx::new(2941U) &&
    (descriptor.name == "vacuum" || descriptor.name == "dead-code-elimination") {
    let use_def = @ir.use_def_build(func)
    pass_manager_debug_dump_target_regions(
      options.trace,
      func,
      "after-pass:\{descriptor.name}",
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-pass:\{descriptor.name}",
      581,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-pass:\{descriptor.name}",
      582,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-pass:\{descriptor.name}",
      1253,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-pass:\{descriptor.name}",
      1254,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-pass:\{descriptor.name}",
      1255,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-pass:\{descriptor.name}",
      1256,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-pass:\{descriptor.name}",
      1257,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-pass:\{descriptor.name}",
      1258,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-pass:\{descriptor.name}",
      1259,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-pass:\{descriptor.name}",
      1260,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-pass:\{descriptor.name}",
      1261,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-pass:\{descriptor.name}",
      1262,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-pass:\{descriptor.name}",
      1263,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-pass:\{descriptor.name}",
      1264,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-pass:\{descriptor.name}",
      1265,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-pass:\{descriptor.name}",
      1266,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-pass:\{descriptor.name}",
      1267,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-pass:\{descriptor.name}",
      1268,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-pass:\{descriptor.name}",
      1269,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-pass:\{descriptor.name}",
      1270,
    )
    pass_manager_debug_dump_node(
      options.trace,
      func,
      use_def,
      "after-pass:\{descriptor.name}",
      1271,
    )
    pass_manager_debug_dump_matching_nodes(
      options.trace,
      func,
      use_def,
      "after-pass:\{descriptor.name}",
    )
  }
  match
    pipeline_verify_checkpoint_with_perf(
      options.perf,
      HotPipelineVerifyPolicy::AfterEachPass,
      "verify before lower",
      HotPipelineVerifyTarget::HotFuncTarget(func),
      "verify:before-lower",
    ) {
    Ok(_) => {
      let lower_start_us = perf_start_timer_opt(options.perf, "lower")
      let lowered = @ir.hot_lower_func(func)
      perf_stop_timer_opt(options.perf, "lower", lower_start_us)
      Ok(lowered)
    }
    Err(err) => Err(err)
  }
}

///|
fn run_hot_pipeline_apply_hot_pass(
  mod_ : @lib.Module,
  entry : HotPassRegistryEntry,
  options : HotPipelineOptions,
) -> Result[@lib.Module, String] {
  let descriptor = match entry.descriptor {
    Some(descriptor) => descriptor
    None => return Err("missing hot pass descriptor for \{entry.name}")
  }
  let imported_func_count = run_hot_pipeline_imported_func_count(mod_)
  let next_code_sec = match mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let lowered : Array[@lib.Func] = []
      for code_idx = 0; code_idx < defs.length(); code_idx = code_idx + 1 {
        let func_idx = @lib.FuncIdx::new(
          (imported_func_count + code_idx).reinterpret_as_uint(),
        )
        let lowered_func = match
          run_hot_pipeline_func(mod_, func_idx, descriptor, options) {
          Ok(func) => func
          Err(err) => return Err("func[\{func_idx}]: \{err}")
        }
        lowered.push(lowered_func)
      }
      Some(@lib.CodeSec::new(lowered))
    }
    None => None
  }
  Ok(
    match next_code_sec {
      Some(code_sec) => mod_.with_code_sec(code_sec)
      None => mod_
    },
  )
}

///|
fn run_hot_pipeline_apply_module_pass(
  mod_ : @lib.Module,
  entry : HotPassRegistryEntry,
  options : HotPipelineOptions,
) -> Result[@lib.Module, String] {
  pipeline_trace_hook(options.trace, entry.name, "start")
  let pass_timer_start = perf_start_timer_opt(
    options.perf,
    "pass:\{entry.name}",
  )
  let next = match entry.name {
    "duplicate-function-elimination" =>
      dfe_run_module_pass_with_perf(mod_, options.perf)
    "remove-unused-module-elements" => rume_run_module_pass(mod_)
    "memory-packing" => memory_packing_run_module_pass(mod_)
    "once-reduction" => once_reduction_run_module_pass(mod_)
    "global-refining" => global_refining_run_module_pass(mod_)
    "global-struct-inference" =>
      global_struct_inference_run_module_pass(mod_, options.closed_world)
    _ => return Err("unsupported module pass \{entry.name}")
  }
  perf_stop_timer_opt(options.perf, "pass:\{entry.name}", pass_timer_start)
  match options.verify_policy {
    HotPipelineVerifyPolicy::AfterEachPass =>
      match
        pipeline_verify_checkpoint_with_perf(
          options.perf,
          HotPipelineVerifyPolicy::AfterEachPass,
          "verify after module pass \{entry.name}",
          HotPipelineVerifyTarget::ModuleTarget(next),
          "verify:module-pass:\{entry.name}",
        ) {
        Ok(_) => ()
        Err(err) => return Err(err)
      }
    HotPipelineVerifyPolicy::FinalModuleOnly => ()
  }
  pipeline_trace_hook(options.trace, entry.name, "done")
  Ok(next)
}

///|
pub fn hot_pass_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> Result[HotPassResult, String] {
  let descriptor = ctx.descriptor
  pass_prepare_requirements(ctx, func)
  pipeline_trace_hook(ctx.trace, descriptor.name, "start")
  perf_dump_hot_func_opt(ctx.perf, func, "before-pass:\{descriptor.name}")
  let before_snapshot = perf_snapshot_hot_func(func)
  let before_revision = @ir.hot_revision_current(func)
  let pass_timer_start = perf_start_timer_opt(
    ctx.perf,
    "pass:\{descriptor.name}",
  )
  let result = match descriptor.name {
    "ssa-nomerge" => ssa_nomerge_run(ctx, func)
    "vacuum" =>
      if hot_pass_remove_region_nops(ctx, func, @ir.HotRegionRef::root()) {
        HotPassResult::changed()
      } else {
        HotPassResult::unchanged()
      }
    "dead-code-elimination" => dead_code_elimination_run(ctx, func)
    "optimize-instructions" => optimize_instructions_run(ctx, func)
    "simplify-locals" => simplify_locals_run(ctx, func)
    _ => return Err("unsupported hot pass \{descriptor.name}")
  }
  perf_stop_timer_opt(ctx.perf, "pass:\{descriptor.name}", pass_timer_start)
  match ctx.perf {
    Some(perf) =>
      perf_count_hot_alloc_delta(
        perf,
        before_snapshot,
        perf_snapshot_hot_func(func),
      )
    None => ()
  }
  perf_dump_hot_func_opt(ctx.perf, func, "after-pass:\{descriptor.name}")
  if @ir.hot_revision_current(func) != before_revision {
    @ir.cache_invalidate_all(ctx.cache)
  }
  match pass_verify_before_after(ctx, func) {
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
