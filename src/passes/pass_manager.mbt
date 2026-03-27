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
  trace_enabled : Bool
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
    trace_enabled: trace is Some(_),
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
  module_ctx : @ir.HotModuleContext?
}

///|
pub fn HotPassContext::new(
  descriptor : @ir.HotPassDescriptor,
  cache : @ir.HotAnalysisCache,
  verify_policy : HotPipelineVerifyPolicy,
  closed_world : Bool,
  trace : (String) -> Unit,
  perf? : HotPerfSession? = None,
  module_ctx? : @ir.HotModuleContext? = None,
) -> HotPassContext {
  { descriptor, cache, verify_policy, closed_world, trace, perf, module_ctx }
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
pub fn run_hot_pipeline_debug_dump_enabled(
  options : HotPipelineOptions,
  func_idx : @lib.FuncIdx,
  descriptor_name : String,
) -> Bool {
  options.trace_enabled &&
  (descriptor_name == "vacuum" || descriptor_name == "dead-code-elimination") &&
  (func_idx == @lib.FuncIdx::new(2941U) || func_idx == @lib.FuncIdx::new(2944U))
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
    if tag.contains("(35)") ||
      tag.contains("(36)") ||
      tag.contains("(37)") ||
      tag.contains("(38)") ||
      tag.contains("(39)") ||
      tag.contains("(40)") ||
      tag.contains("(97)") ||
      tag.contains("(98)") ||
      tag.contains("(99)") {
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
              trace, func, stage, else_region,
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
              trace, func, stage, catch_region,
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
    if tag.contains("LocalSet(35)") ||
      tag.contains("LocalSet(36)") ||
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
fn run_hot_pipeline_instr_scan(
  instrs : Array[@lib.Instruction],
) -> (Bool, Bool, Bool, Int) {
  let mut has_writes = false
  let mut has_structured_control = false
  let mut has_branches = false
  let mut instr_count = 0
  for instr in instrs {
    instr_count = instr_count + 1
    match instr {
      @lib.LocalSet(_) | @lib.LocalTee(_) => has_writes = true
      @lib.Br(_) | @lib.BrIf(_) | @lib.BrTable(_, _) => has_branches = true
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) => {
        has_structured_control = true
        let (nested_writes, _, nested_branches, nested_instr_count) = run_hot_pipeline_instr_scan(
          body,
        )
        has_writes = has_writes || nested_writes
        has_branches = has_branches || nested_branches
        instr_count = instr_count + nested_instr_count
      }
      @lib.If(_, then_body, else_body) => {
        has_structured_control = true
        let (then_writes, _, then_branches, then_instr_count) = run_hot_pipeline_instr_scan(
          then_body,
        )
        has_writes = has_writes || then_writes
        has_branches = has_branches || then_branches
        instr_count = instr_count + then_instr_count
        match else_body {
          Some(else_body) => {
            let (else_writes, _, else_branches, else_instr_count) = run_hot_pipeline_instr_scan(
              else_body,
            )
            has_writes = has_writes || else_writes
            has_branches = has_branches || else_branches
            instr_count = instr_count + else_instr_count
          }
          None => ()
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) => {
        has_structured_control = true
        let (nested_writes, _, nested_branches, nested_instr_count) = run_hot_pipeline_instr_scan(
          body,
        )
        has_writes = has_writes || nested_writes
        has_branches = has_branches || nested_branches
        instr_count = instr_count + nested_instr_count
      }
      _ => ()
    }
  }
  (has_writes, has_structured_control, has_branches, instr_count)
}

///|
fn run_hot_pipeline_dce_raw_has_early_terminator(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    let is_final = idx + 1 == instrs.length()
    match instrs[idx] {
      @lib.Return
      | @lib.ReturnCall(_)
      | @lib.ReturnCallIndirect(_, _)
      | @lib.ReturnCallRef(_)
      | @lib.Throw(_)
      | @lib.ThrowRef
      | @lib.Unreachable => if !is_final { return true }
      _ => ()
    }
  }
  false
}

///|
fn run_hot_pipeline_dce_raw_instr_may_fallthrough(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.Br(_)
    | @lib.BrTable(_, _)
    | @lib.Return
    | @lib.ReturnCall(_)
    | @lib.ReturnCallIndirect(_, _)
    | @lib.ReturnCallRef(_)
    | @lib.Throw(_)
    | @lib.ThrowRef
    | @lib.Unreachable => false
    @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
      run_hot_pipeline_dce_raw_body_may_fallthrough(body)
    @lib.If(_, then_body, else_body) => {
      let then_may_fallthrough = run_hot_pipeline_dce_raw_body_may_fallthrough(
        then_body,
      )
      let else_may_fallthrough = match else_body {
        Some(else_body) =>
          run_hot_pipeline_dce_raw_body_may_fallthrough(else_body)
        None => true
      }
      then_may_fallthrough || else_may_fallthrough
    }
    @lib.TryTable(_, _, @lib.Expr(body)) =>
      run_hot_pipeline_dce_raw_body_may_fallthrough(body)
    _ => true
  }
}

///|
fn run_hot_pipeline_dce_raw_body_may_fallthrough(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    if !run_hot_pipeline_dce_raw_instr_may_fallthrough(instr) {
      return false
    }
  }
  true
}

///|
fn run_hot_pipeline_dce_raw_has_dead_drop_after_nonfallthrough(
  instrs : Array[@lib.Instruction],
) -> Bool {
  let mut prev_may_fallthrough = true
  for instr in instrs {
    if !prev_may_fallthrough {
      match instr {
        @lib.Drop => return true
        _ => ()
      }
    }
    match instr {
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        if run_hot_pipeline_dce_raw_has_dead_drop_after_nonfallthrough(body) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if run_hot_pipeline_dce_raw_has_dead_drop_after_nonfallthrough(
            then_body,
          ) {
          return true
        }
        match else_body {
          Some(else_body) =>
            if run_hot_pipeline_dce_raw_has_dead_drop_after_nonfallthrough(
                else_body,
              ) {
              return true
            }
          None => ()
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        if run_hot_pipeline_dce_raw_has_dead_drop_after_nonfallthrough(body) {
          return true
        }
      _ => ()
    }
    prev_may_fallthrough = run_hot_pipeline_dce_raw_instr_may_fallthrough(instr)
  }
  false
}

///|
fn run_hot_pipeline_dce_raw_requires_lowering_even_if_unchanged(
  original : @lib.Func,
) -> Bool {
  let @lib.Func(_, @lib.Expr(instrs)) = original
  run_hot_pipeline_dce_raw_has_dead_drop_after_nonfallthrough(instrs)
}

///|
fn run_hot_pipeline_dce_raw_instr_is_definitely_void(
  instr : @lib.Instruction,
  module_ctx : @ir.HotModuleContext,
) -> Bool {
  match instr {
    @lib.Nop
    | @lib.Drop
    | @lib.Return
    | @lib.ReturnCall(_)
    | @lib.ReturnCallIndirect(_, _)
    | @lib.ReturnCallRef(_)
    | @lib.Throw(_)
    | @lib.ThrowRef
    | @lib.Unreachable
    | @lib.LocalSet(_)
    | @lib.GlobalSet(_)
    | @lib.TableSet(_)
    | @lib.I32Store(_)
    | @lib.I64Store(_)
    | @lib.F32Store(_)
    | @lib.F64Store(_)
    | @lib.I32Store8(_)
    | @lib.I32Store16(_)
    | @lib.I64Store8(_)
    | @lib.I64Store16(_)
    | @lib.I64Store32(_)
    | @lib.MemoryFill(_)
    | @lib.DataDrop(_)
    | @lib.ElemDrop(_)
    | @lib.AtomicFence => true
    @lib.Call(func_idx) =>
      match @ir.hot_module_resolve_func_type(module_ctx, func_idx) {
        Some(@lib.FuncType(_, results)) => results.is_empty()
        None => false
      }
    @lib.CallIndirect(type_idx, _) | @lib.CallRef(type_idx) =>
      match @ir.hot_module_resolve_type_func_type(module_ctx, type_idx) {
        Some(@lib.FuncType(_, results)) => results.is_empty()
        None => false
      }
    _ => false
  }
}

///|
fn run_hot_pipeline_dce_raw_void_structured_noop(
  instrs : Array[@lib.Instruction],
) -> Bool {
  if run_hot_pipeline_dce_raw_has_early_terminator(instrs) {
    return false
  }
  for instr in instrs {
    match instr {
      @lib.Drop | @lib.Br(_) | @lib.BrIf(_) | @lib.BrTable(_, _) => return false
      @lib.Block(block_type, @lib.Expr(body))
      | @lib.Loop(block_type, @lib.Expr(body)) =>
        if block_type != @lib.BlockType::void_() ||
          !run_hot_pipeline_dce_raw_void_structured_noop(body) {
          return false
        }
      @lib.If(block_type, then_body, else_body) => {
        if block_type != @lib.BlockType::void_() ||
          !run_hot_pipeline_dce_raw_void_structured_noop(then_body) {
          return false
        }
        match else_body {
          Some(else_body) =>
            if !run_hot_pipeline_dce_raw_void_structured_noop(else_body) {
              return false
            }
          None => ()
        }
      }
      @lib.TryTable(block_type, _, @lib.Expr(body)) =>
        if block_type != @lib.BlockType::void_() ||
          !run_hot_pipeline_dce_raw_void_structured_noop(body) {
          return false
        }
      _ => ()
    }
  }
  true
}

///|
fn run_hot_pipeline_dce_raw_straight_line_noop(
  instrs : Array[@lib.Instruction],
) -> Bool {
  if run_hot_pipeline_dce_raw_has_early_terminator(instrs) {
    return false
  }
  for instr in instrs {
    match instr {
      @lib.Drop => return false
      _ => ()
    }
  }
  true
}

///|
fn run_hot_pipeline_dce_can_skip_raw(
  original : @lib.Func,
  module_ctx : @ir.HotModuleContext,
  func_idx : @lib.FuncIdx,
) -> Bool {
  let @lib.Func(_, @lib.Expr(instrs)) = original
  let (_, has_structured_control, has_branches, _) = run_hot_pipeline_instr_scan(
    instrs,
  )
  if has_branches {
    return false
  }
  let straight_line_noop = !has_structured_control &&
    run_hot_pipeline_dce_raw_straight_line_noop(instrs)
  let structured_void_noop = has_structured_control &&
    run_hot_pipeline_dce_raw_void_structured_noop(instrs)
  if !straight_line_noop && !structured_void_noop {
    return false
  }
  match @ir.hot_module_resolve_func_type(module_ctx, func_idx) {
    Some(@lib.FuncType(_, results)) =>
      !results.is_empty() ||
      structured_void_noop ||
      instrs.is_empty() ||
      run_hot_pipeline_dce_raw_instr_is_definitely_void(
        instrs[instrs.length() - 1],
        module_ctx,
      )
    None =>
      abort(
        "hot pipeline raw dead-code-elimination skip requires the function type to resolve",
      )
  }
}

///|
priv struct HsoCandidateScanState {
  mut has_local_writes : Bool
  mut has_struct_alloc : Bool
  mut has_struct_set : Bool
}

///|
priv struct HotPipelineModuleState {
  mut module_ctx : @ir.HotModuleContext?
}

///|
fn run_hot_pipeline_require_module_ctx(
  mod_ : @lib.Module,
  module_state : HotPipelineModuleState,
  options : HotPipelineOptions,
) -> @ir.HotModuleContext {
  match module_state.module_ctx {
    Some(module_ctx) => module_ctx
    None => {
      let start_us = perf_start_timer_opt(
        options.perf,
        "analysis:module-context",
      )
      let module_ctx = @ir.hot_module_context_from_module(mod_)
      perf_stop_timer_opt(options.perf, "analysis:module-context", start_us)
      module_state.module_ctx = Some(module_ctx)
      module_ctx
    }
  }
}

///|
fn run_hot_pipeline_hso_candidate_scan_into(
  instrs : Array[@lib.Instruction],
  state : HsoCandidateScanState,
) -> Unit {
  for instr in instrs {
    if state.has_local_writes && state.has_struct_alloc && state.has_struct_set {
      return
    }
    match instr {
      @lib.LocalSet(_) | @lib.LocalTee(_) => state.has_local_writes = true
      @lib.StructNew(_)
      | @lib.StructNewDefault(_)
      | @lib.StructNewDesc(_)
      | @lib.StructNewDefaultDesc(_) => state.has_struct_alloc = true
      @lib.StructSet(_, _) => state.has_struct_set = true
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        run_hot_pipeline_hso_candidate_scan_into(body, state)
      @lib.If(_, then_body, else_body) => {
        run_hot_pipeline_hso_candidate_scan_into(then_body, state)
        match else_body {
          Some(else_body) =>
            run_hot_pipeline_hso_candidate_scan_into(else_body, state)
          None => ()
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        run_hot_pipeline_hso_candidate_scan_into(body, state)
      _ => ()
    }
  }
}

///|
fn run_hot_pipeline_hso_candidate_scan(
  instrs : Array[@lib.Instruction],
) -> (Bool, Bool, Bool) {
  let state = {
    has_local_writes: false,
    has_struct_alloc: false,
    has_struct_set: false,
  }
  run_hot_pipeline_hso_candidate_scan_into(instrs, state)
  (state.has_local_writes, state.has_struct_alloc, state.has_struct_set)
}

///|
fn run_hot_pipeline_required_func_params(
  module_ctx : @ir.HotModuleContext,
  func_idx : @lib.FuncIdx,
) -> Array[@lib.ValType] {
  match @ir.hot_module_resolve_func_type(module_ctx, func_idx) {
    Some(@lib.FuncType(params, _)) => params
    None =>
      abort(
        "hot pipeline raw ssa-nomerge rewrite requires the function type to resolve",
      )
  }
}

///|
fn run_hot_pipeline_raw_local_type(
  params : Array[@lib.ValType],
  locals : @lib.Locals,
  local_id : Int,
) -> @lib.ValType {
  if local_id < params.length() {
    return params[local_id]
  }
  locals.get(local_id - params.length())
}

///|
fn run_hot_pipeline_raw_aliases_equal(
  lhs : Array[@lib.LocalIdx],
  rhs : Array[@lib.LocalIdx],
) -> Bool {
  if lhs.length() != rhs.length() {
    return false
  }
  for idx = 0; idx < lhs.length(); idx = idx + 1 {
    if lhs[idx] != rhs[idx] {
      return false
    }
  }
  true
}

///|
priv struct RawSsaLabelTarget {
  block_type : @lib.BlockType
  result_types : Array[@lib.ValType]
  is_loop : Bool
}

///|
fn run_hot_pipeline_raw_fresh_local(
  params : Array[@lib.ValType],
  locals : @lib.Locals,
  local_id : Int,
  extra_local_types : Array[@lib.ValType],
) -> @lib.LocalIdx {
  let fresh_local_id = params.length() +
    locals.length() +
    extra_local_types.length()
  extra_local_types.push(
    run_hot_pipeline_raw_local_type(params, locals, local_id),
  )
  @lib.LocalIdx::new(fresh_local_id.reinterpret_as_uint())
}

///|
fn run_hot_pipeline_raw_fresh_typed_local(
  params : Array[@lib.ValType],
  locals : @lib.Locals,
  val_type : @lib.ValType,
  extra_local_types : Array[@lib.ValType],
) -> @lib.LocalIdx {
  let fresh_local_id = params.length() +
    locals.length() +
    extra_local_types.length()
  extra_local_types.push(val_type)
  @lib.LocalIdx::new(fresh_local_id.reinterpret_as_uint())
}

///|
fn run_hot_pipeline_raw_append_alias_merge_copies(
  branch_instrs : Array[@lib.Instruction],
  source_aliases : Array[@lib.LocalIdx],
  target_aliases : Array[@lib.LocalIdx],
  result_types : Array[@lib.ValType],
  params : Array[@lib.ValType],
  locals : @lib.Locals,
  extra_local_types : Array[@lib.ValType],
) -> Array[@lib.Instruction] {
  let out = branch_instrs.copy()
  let result_scratch : Array[@lib.LocalIdx] = []
  for result_type in result_types {
    result_scratch.push(
      run_hot_pipeline_raw_fresh_typed_local(
        params, locals, result_type, extra_local_types,
      ),
    )
  }
  for idx = result_scratch.length() - 1; idx >= 0; idx = idx - 1 {
    out.push(@lib.Instruction::local_set(result_scratch[idx]))
  }
  for local_id = 0; local_id < target_aliases.length(); local_id = local_id + 1 {
    if source_aliases[local_id] == target_aliases[local_id] {
      continue
    }
    out.push(@lib.Instruction::local_get(source_aliases[local_id]))
    out.push(@lib.Instruction::local_set(target_aliases[local_id]))
  }
  for local_idx in result_scratch {
    out.push(@lib.Instruction::local_get(local_idx))
  }
  out
}

///|
fn run_hot_pipeline_raw_append_alias_copies(
  out : Array[@lib.Instruction],
  source_aliases : Array[@lib.LocalIdx],
  target_aliases : Array[@lib.LocalIdx],
) -> Unit {
  for local_id = 0; local_id < target_aliases.length(); local_id = local_id + 1 {
    if source_aliases[local_id] == target_aliases[local_id] {
      continue
    }
    out.push(@lib.Instruction::local_get(source_aliases[local_id]))
    out.push(@lib.Instruction::local_set(target_aliases[local_id]))
  }
}

///|
fn run_hot_pipeline_raw_canonical_aliases(
  base_local_count : Int,
) -> Array[@lib.LocalIdx] {
  let canonical : Array[@lib.LocalIdx] = []
  for local_id = 0; local_id < base_local_count; local_id = local_id + 1 {
    canonical.push(@lib.LocalIdx::new(local_id.reinterpret_as_uint()))
  }
  canonical
}

///|
fn run_hot_pipeline_raw_label_target(
  module_ctx : @ir.HotModuleContext,
  block_type : @lib.BlockType,
  is_loop : Bool,
) -> RawSsaLabelTarget? {
  match @ir.hot_module_resolve_block_results(module_ctx, block_type) {
    Some(result_types) => Some({ block_type, result_types, is_loop })
    None => None
  }
}

///|
fn run_hot_pipeline_raw_push_label_target(
  label_stack : Array[RawSsaLabelTarget],
  label_target : RawSsaLabelTarget,
) -> Array[RawSsaLabelTarget] {
  let nested = label_stack.copy()
  nested.push(label_target)
  nested
}

///|
fn run_hot_pipeline_raw_resolve_label_target(
  label_stack : Array[RawSsaLabelTarget],
  label_idx : @lib.LabelIdx,
) -> RawSsaLabelTarget? {
  let @lib.LabelIdx(raw) = label_idx
  let depth = raw.reinterpret_as_int()
  let stack_idx = label_stack.length() - depth - 1
  if stack_idx < 0 {
    return None
  }
  label_stack.get(stack_idx)
}

///|
fn run_hot_pipeline_raw_label_inc(label_idx : @lib.LabelIdx) -> @lib.LabelIdx {
  let @lib.LabelIdx(raw) = label_idx
  @lib.LabelIdx::new(raw + 1U)
}

///|
fn run_hot_pipeline_raw_empty_exit_depths(
  label_stack : Array[RawSsaLabelTarget],
) -> Array[Bool] {
  let exit_depths : Array[Bool] = []
  for _ in label_stack {
    exit_depths.push(false)
  }
  exit_depths
}

///|
fn run_hot_pipeline_raw_propagate_outer_exits(
  exit_depths : Array[Bool],
  nested_exit_depths : Array[Bool],
) -> Unit {
  for depth = 1; depth < nested_exit_depths.length(); depth = depth + 1 {
    if nested_exit_depths[depth] {
      exit_depths[depth - 1] = true
    }
  }
}

///|
fn run_hot_pipeline_raw_branch_if_block_type(
  module_ctx : @ir.HotModuleContext,
  label_target : RawSsaLabelTarget,
) -> @lib.BlockType? {
  match label_target.block_type {
    @lib.VoidBlockType | @lib.ValTypeBlockType(_) =>
      Some(label_target.block_type)
    @lib.TypeIdxBlockType(type_idx) =>
      match @ir.hot_module_resolve_type_func_type(module_ctx, type_idx) {
        Some(@lib.FuncType(params, _)) =>
          if params.length() == 0 {
            Some(label_target.block_type)
          } else {
            None
          }
        None => None
      }
  }
}

///|
fn run_hot_pipeline_raw_rewrite_br_if(
  module_ctx : @ir.HotModuleContext,
  label_idx : @lib.LabelIdx,
  label_target : RawSsaLabelTarget,
  source_aliases : Array[@lib.LocalIdx],
  canonical_aliases : Array[@lib.LocalIdx],
  params : Array[@lib.ValType],
  locals : @lib.Locals,
  extra_local_types : Array[@lib.ValType],
) -> Array[@lib.Instruction]? {
  let target_label = run_hot_pipeline_raw_label_inc(label_idx)
  if label_target.result_types.length() == 0 {
    let then_body : Array[@lib.Instruction] = []
    run_hot_pipeline_raw_append_alias_copies(
      then_body, source_aliases, canonical_aliases,
    )
    then_body.push(@lib.Instruction::br(target_label))
    return Some([
      @lib.Instruction::if_(@lib.BlockType::void_(), then_body, None),
    ])
  }

  let if_block_type = match
    run_hot_pipeline_raw_branch_if_block_type(module_ctx, label_target) {
    Some(block_type) => block_type
    None => return None
  }
  let cond_local = run_hot_pipeline_raw_fresh_typed_local(
    params,
    locals,
    @lib.ValType::i32(),
    extra_local_types,
  )
  let result_scratch : Array[@lib.LocalIdx] = []
  for result_type in label_target.result_types {
    result_scratch.push(
      run_hot_pipeline_raw_fresh_typed_local(
        params, locals, result_type, extra_local_types,
      ),
    )
  }

  let rewritten : Array[@lib.Instruction] = []
  rewritten.push(@lib.Instruction::local_set(cond_local))
  for idx = result_scratch.length() - 1; idx >= 0; idx = idx - 1 {
    rewritten.push(@lib.Instruction::local_set(result_scratch[idx]))
  }
  rewritten.push(@lib.Instruction::local_get(cond_local))

  let then_body : Array[@lib.Instruction] = []
  run_hot_pipeline_raw_append_alias_copies(
    then_body, source_aliases, canonical_aliases,
  )
  for scratch_local in result_scratch {
    then_body.push(@lib.Instruction::local_get(scratch_local))
  }
  then_body.push(@lib.Instruction::br(target_label))

  let else_body : Array[@lib.Instruction] = []
  for scratch_local in result_scratch {
    else_body.push(@lib.Instruction::local_get(scratch_local))
  }
  rewritten.push(
    @lib.Instruction::if_(if_block_type, then_body, Some(else_body)),
  )
  Some(rewritten)
}

///|
fn run_hot_pipeline_raw_rewrite_instrs(
  instrs : Array[@lib.Instruction],
  module_ctx : @ir.HotModuleContext,
  params : Array[@lib.ValType],
  locals : @lib.Locals,
  local_aliases : Array[@lib.LocalIdx],
  canonical_aliases : Array[@lib.LocalIdx],
  label_stack : Array[RawSsaLabelTarget],
  extra_local_types : Array[@lib.ValType],
) -> (Array[@lib.Instruction], Array[@lib.LocalIdx], Bool, Array[Bool])? {
  let rewritten : Array[@lib.Instruction] = []
  let mut aliases = local_aliases
  let mut fallthrough = true
  let exit_depths = run_hot_pipeline_raw_empty_exit_depths(label_stack)
  for instr in instrs {
    let was_reachable = fallthrough
    match instr {
      @lib.Block(block_type, @lib.Expr(body)) => {
        let label_target = match
          run_hot_pipeline_raw_label_target(module_ctx, block_type, false) {
          Some(label_target) => label_target
          None => return None
        }
        match
          run_hot_pipeline_raw_rewrite_instrs(
            body,
            module_ctx,
            params,
            locals,
            aliases.copy(),
            canonical_aliases,
            run_hot_pipeline_raw_push_label_target(label_stack, label_target),
            extra_local_types,
          ) {
          Some(
            (rewritten_body, body_aliases, body_fallthrough, body_exit_depths)
          ) => {
            let body_exits_current_label = body_exit_depths.length() > 0 &&
              body_exit_depths[0]
            let mut finalized_body = rewritten_body
            if body_fallthrough && body_exits_current_label {
              finalized_body = run_hot_pipeline_raw_append_alias_merge_copies(
                finalized_body,
                body_aliases,
                canonical_aliases,
                label_target.result_types,
                params,
                locals,
                extra_local_types,
              )
            }
            rewritten.push(
              @lib.Instruction::block(
                block_type,
                @lib.Expr::new(finalized_body),
              ),
            )
            if was_reachable {
              run_hot_pipeline_raw_propagate_outer_exits(
                exit_depths, body_exit_depths,
              )
              if body_fallthrough || body_exits_current_label {
                aliases = if body_exits_current_label {
                  canonical_aliases.copy()
                } else {
                  body_aliases
                }
                fallthrough = true
              } else {
                fallthrough = false
              }
            }
          }
          None => return None
        }
      }
      @lib.If(block_type, then_body, else_body) => {
        let label_target = match
          run_hot_pipeline_raw_label_target(module_ctx, block_type, false) {
          Some(label_target) => label_target
          None => return None
        }
        let then_result = match
          run_hot_pipeline_raw_rewrite_instrs(
            then_body,
            module_ctx,
            params,
            locals,
            aliases.copy(),
            canonical_aliases,
            run_hot_pipeline_raw_push_label_target(label_stack, label_target),
            extra_local_types,
          ) {
          Some(result) => result
          None => return None
        }
        let else_result = match else_body {
          Some(body) =>
            match
              run_hot_pipeline_raw_rewrite_instrs(
                body,
                module_ctx,
                params,
                locals,
                aliases.copy(),
                canonical_aliases,
                run_hot_pipeline_raw_push_label_target(
                  label_stack, label_target,
                ),
                extra_local_types,
              ) {
              Some(result) => result
              None => return None
            }
          None =>
            (
              [],
              aliases.copy(),
              true,
              run_hot_pipeline_raw_empty_exit_depths(
                run_hot_pipeline_raw_push_label_target(
                  label_stack, label_target,
                ),
              ),
            )
        }
        let (rewritten_then, then_aliases, then_fallthrough, then_exit_depths) = then_result
        let (rewritten_else, else_aliases, else_fallthrough, else_exit_depths) = else_result
        let then_exits_current_label = then_exit_depths.length() > 0 &&
          then_exit_depths[0]
        let else_exits_current_label = else_exit_depths.length() > 0 &&
          else_exit_depths[0]
        let has_current_label_exits = then_exits_current_label ||
          else_exits_current_label
        let mut finalized_then = rewritten_then
        let mut finalized_else = rewritten_else
        let mut merged_aliases = aliases
        if has_current_label_exits {
          if then_fallthrough {
            finalized_then = run_hot_pipeline_raw_append_alias_merge_copies(
              finalized_then,
              then_aliases,
              canonical_aliases,
              label_target.result_types,
              params,
              locals,
              extra_local_types,
            )
          }
          if else_fallthrough {
            finalized_else = run_hot_pipeline_raw_append_alias_merge_copies(
              finalized_else,
              else_aliases,
              canonical_aliases,
              label_target.result_types,
              params,
              locals,
              extra_local_types,
            )
          }
        } else if then_fallthrough && else_fallthrough {
          if run_hot_pipeline_raw_aliases_equal(then_aliases, else_aliases) {
            merged_aliases = then_aliases
          } else {
            merged_aliases = then_aliases.copy()
            for local_id = 0
                local_id < merged_aliases.length()
                local_id = local_id + 1 {
              if then_aliases[local_id] == else_aliases[local_id] {
                continue
              }
              merged_aliases[local_id] = run_hot_pipeline_raw_fresh_local(
                params, locals, local_id, extra_local_types,
              )
            }
            finalized_then = run_hot_pipeline_raw_append_alias_merge_copies(
              finalized_then,
              then_aliases,
              merged_aliases,
              label_target.result_types,
              params,
              locals,
              extra_local_types,
            )
            finalized_else = run_hot_pipeline_raw_append_alias_merge_copies(
              finalized_else,
              else_aliases,
              merged_aliases,
              label_target.result_types,
              params,
              locals,
              extra_local_types,
            )
          }
        }
        rewritten.push(
          @lib.Instruction::if_(
            block_type,
            finalized_then,
            match else_body {
              Some(_) => Some(finalized_else)
              None =>
                if finalized_else.length() == 0 {
                  None
                } else {
                  Some(finalized_else)
                }
            },
          ),
        )
        if was_reachable {
          run_hot_pipeline_raw_propagate_outer_exits(
            exit_depths, then_exit_depths,
          )
          run_hot_pipeline_raw_propagate_outer_exits(
            exit_depths, else_exit_depths,
          )
          if has_current_label_exits {
            if then_fallthrough ||
              then_exits_current_label ||
              else_fallthrough ||
              else_exits_current_label {
              aliases = canonical_aliases.copy()
              fallthrough = true
            } else {
              fallthrough = false
            }
          } else {
            match (then_fallthrough, else_fallthrough) {
              (true, true) => {
                aliases = merged_aliases
                fallthrough = true
              }
              (true, false) => {
                aliases = then_aliases
                fallthrough = true
              }
              (false, true) => {
                aliases = else_aliases
                fallthrough = true
              }
              (false, false) => fallthrough = false
            }
          }
        }
      }
      @lib.Loop(_, _) | @lib.BrTable(_, _) | @lib.TryTable(_, _, _) =>
        return None
      @lib.Br(label_idx) => {
        let label_target = match
          run_hot_pipeline_raw_resolve_label_target(label_stack, label_idx) {
          Some(label_target) => label_target
          None => return None
        }
        if label_target.is_loop {
          return None
        }
        let branch_instrs = run_hot_pipeline_raw_append_alias_merge_copies(
          [],
          aliases,
          canonical_aliases,
          label_target.result_types,
          params,
          locals,
          extra_local_types,
        )
        branch_instrs.push(@lib.Instruction::br(label_idx))
        rewritten.append(branch_instrs)
        if was_reachable {
          let @lib.LabelIdx(raw) = label_idx
          exit_depths[raw.reinterpret_as_int()] = true
          fallthrough = false
        }
      }
      @lib.BrIf(label_idx) => {
        let label_target = match
          run_hot_pipeline_raw_resolve_label_target(label_stack, label_idx) {
          Some(label_target) => label_target
          None => return None
        }
        if label_target.is_loop {
          return None
        }
        match
          run_hot_pipeline_raw_rewrite_br_if(
            module_ctx, label_idx, label_target, aliases, canonical_aliases, params,
            locals, extra_local_types,
          ) {
          Some(branch_instrs) => rewritten.append(branch_instrs)
          None => return None
        }
        if was_reachable {
          let @lib.LabelIdx(raw) = label_idx
          exit_depths[raw.reinterpret_as_int()] = true
        }
      }
      @lib.LocalGet(@lib.LocalIdx(raw)) =>
        rewritten.push(
          @lib.Instruction::local_get(aliases[raw.reinterpret_as_int()]),
        )
      @lib.LocalSet(@lib.LocalIdx(raw)) => {
        let local_id = raw.reinterpret_as_int()
        let fresh_local = run_hot_pipeline_raw_fresh_local(
          params, locals, local_id, extra_local_types,
        )
        aliases[local_id] = fresh_local
        rewritten.push(@lib.Instruction::local_set(fresh_local))
      }
      @lib.LocalTee(@lib.LocalIdx(raw)) => {
        let local_id = raw.reinterpret_as_int()
        let fresh_local = run_hot_pipeline_raw_fresh_local(
          params, locals, local_id, extra_local_types,
        )
        aliases[local_id] = fresh_local
        rewritten.push(@lib.Instruction::local_tee(fresh_local))
      }
      @lib.Return
      | @lib.ReturnCall(_)
      | @lib.ReturnCallIndirect(_, _)
      | @lib.ReturnCallRef(_)
      | @lib.Throw(_)
      | @lib.ThrowRef
      | @lib.Unreachable => {
        rewritten.push(instr)
        fallthrough = false
      }
      _ => rewritten.push(instr)
    }
  }
  Some((rewritten, aliases, fallthrough, exit_depths))
}

///|
fn run_hot_pipeline_raw_ssa_nomerge_structured(
  func : @lib.Func,
  module_ctx : @ir.HotModuleContext,
  params : Array[@lib.ValType],
) -> @lib.Func? {
  let @lib.Func(locals, @lib.Expr(instrs)) = func
  let base_local_count = params.length() + locals.length()
  let local_aliases = run_hot_pipeline_raw_canonical_aliases(base_local_count)
  let canonical_aliases = local_aliases.copy()
  let extra_local_types : Array[@lib.ValType] = []
  match
    run_hot_pipeline_raw_rewrite_instrs(
      instrs,
      module_ctx,
      params,
      locals,
      local_aliases,
      canonical_aliases,
      [],
      extra_local_types,
    ) {
    Some((rewritten_instrs, _, _, _)) => {
      let rewritten_locals = locals.copy()
      rewritten_locals.append_types(extra_local_types)
      Some(@lib.Func::new(rewritten_locals, @lib.Expr::new(rewritten_instrs)))
    }
    None => None
  }
}

///|
fn run_hot_pipeline_raw_ssa_nomerge_straight_line(
  func : @lib.Func,
  params : Array[@lib.ValType],
) -> @lib.Func {
  let @lib.Func(locals, @lib.Expr(instrs)) = func
  let rewritten_instrs : Array[@lib.Instruction] = []
  let local_aliases : Array[@lib.LocalIdx] = []
  let extra_local_types : Array[@lib.ValType] = []
  let base_local_count = params.length() + locals.length()
  for local_id = 0; local_id < base_local_count; local_id = local_id + 1 {
    local_aliases.push(@lib.LocalIdx::new(local_id.reinterpret_as_uint()))
  }
  for instr in instrs {
    match instr {
      @lib.LocalGet(@lib.LocalIdx(raw)) =>
        rewritten_instrs.push(
          @lib.Instruction::local_get(local_aliases[raw.reinterpret_as_int()]),
        )
      @lib.LocalSet(@lib.LocalIdx(raw)) => {
        let local_id = raw.reinterpret_as_int()
        let fresh_local_id = base_local_count + extra_local_types.length()
        let fresh_local = @lib.LocalIdx::new(
          fresh_local_id.reinterpret_as_uint(),
        )
        extra_local_types.push(
          run_hot_pipeline_raw_local_type(params, locals, local_id),
        )
        local_aliases[local_id] = fresh_local
        rewritten_instrs.push(@lib.Instruction::local_set(fresh_local))
      }
      @lib.LocalTee(@lib.LocalIdx(raw)) => {
        let local_id = raw.reinterpret_as_int()
        let fresh_local_id = base_local_count + extra_local_types.length()
        let fresh_local = @lib.LocalIdx::new(
          fresh_local_id.reinterpret_as_uint(),
        )
        extra_local_types.push(
          run_hot_pipeline_raw_local_type(params, locals, local_id),
        )
        local_aliases[local_id] = fresh_local
        rewritten_instrs.push(@lib.Instruction::local_tee(fresh_local))
      }
      _ => rewritten_instrs.push(instr)
    }
  }
  let rewritten_locals = locals.copy()
  rewritten_locals.append_types(extra_local_types)
  @lib.Func::new(rewritten_locals, @lib.Expr::new(rewritten_instrs))
}

///|
priv struct HotPipelineFuncResult {
  reason : String
  func : @lib.Func
  unchanged_original : Bool
  trace_skip_raw : Bool
}

///|
fn run_hot_pipeline_raw_ssa_nomerge(
  mod_ : @lib.Module,
  func_idx : @lib.FuncIdx,
  module_state : HotPipelineModuleState,
  descriptor : @ir.HotPassDescriptor,
  options : HotPipelineOptions,
) -> HotPipelineFuncResult? {
  let structured_branch_raw_instr_limit = 128
  let structured_branch_raw_local_limit = 64
  let original = run_hot_pipeline_original_func(mod_, func_idx)
  if descriptor.name == "dead-code-elimination" &&
    run_hot_pipeline_dce_can_skip_raw(
      original,
      run_hot_pipeline_require_module_ctx(mod_, module_state, options),
      func_idx,
    ) {
    return Some({
      reason: "no-dce-candidates",
      func: original,
      unchanged_original: true,
    })
  }
  if descriptor.name != "ssa-nomerge" {
    return None
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = original
  let (has_writes, has_structured_control, has_branches, instr_count) = run_hot_pipeline_instr_scan(
    instrs,
  )
  if !has_writes {
    return Some({
      reason: "no-local-writes",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if has_structured_control {
    let module_ctx = run_hot_pipeline_require_module_ctx(
      mod_, module_state, options,
    )
    let params = run_hot_pipeline_required_func_params(module_ctx, func_idx)
    let base_local_count = params.length() + locals.length()
    if has_branches &&
      (
        instr_count > structured_branch_raw_instr_limit ||
        base_local_count > structured_branch_raw_local_limit
      ) {
      return None
    }
    match
      run_hot_pipeline_raw_ssa_nomerge_structured(original, module_ctx, params) {
      Some(rewritten) =>
        Some({
          reason: "structured-local-writes",
          func: rewritten,
          unchanged_original: false,
          trace_skip_raw: true,
        })
      None => None
    }
  } else {
    let module_ctx = run_hot_pipeline_require_module_ctx(
      mod_, module_state, options,
    )
    Some({
      reason: "straight-line-local-writes",
      func: run_hot_pipeline_raw_ssa_nomerge_straight_line(
        original,
        run_hot_pipeline_required_func_params(module_ctx, func_idx),
      ),
      unchanged_original: false,
      trace_skip_raw: true,
    })
  }
}

///|
fn run_hot_pipeline_raw_heap_store_optimization(
  mod_ : @lib.Module,
  func_idx : @lib.FuncIdx,
  descriptor : @ir.HotPassDescriptor,
) -> HotPipelineFuncResult? {
  if descriptor.name != "heap-store-optimization" {
    return None
  }
  let original = run_hot_pipeline_original_func(mod_, func_idx)
  let @lib.Func(_, @lib.Expr(instrs)) = original
  let (has_local_writes, has_struct_alloc, has_struct_set) = run_hot_pipeline_hso_candidate_scan(
    instrs,
  )
  if has_local_writes && has_struct_alloc && has_struct_set {
    return None
  }
  Some({
    reason: "no-heap-store-candidates",
    func: original,
    unchanged_original: true,
    trace_skip_raw: true,
  })
}

///|
fn run_hot_pipeline_func(
  mod_ : @lib.Module,
  func_idx : @lib.FuncIdx,
  descriptor : @ir.HotPassDescriptor,
  module_state : HotPipelineModuleState,
  options : HotPipelineOptions,
) -> Result[HotPipelineFuncResult, String] {
  match
    run_hot_pipeline_raw_ssa_nomerge(
      mod_, func_idx, module_state, descriptor, options,
    ) {
    Some(result) => return Ok(result)
    None => ()
  }
  match
    run_hot_pipeline_raw_heap_store_optimization(mod_, func_idx, descriptor) {
    Some(result) => return Ok(result)
    None => ()
  }
  pipeline_trace_hook(
    options.trace,
    descriptor.name,
    "func",
    payload="func_idx=\{func_idx}",
  )
  let lift_start_us = perf_start_timer_opt(options.perf, "lift")
  let module_ctx = run_hot_pipeline_require_module_ctx(
    mod_, module_state, options,
  )
  let func = @ir.hot_lift_func_with_context_unverified(
    mod_, func_idx, module_ctx,
  )
  let lifted_revision = @ir.hot_revision_current(func)
  if run_hot_pipeline_debug_dump_enabled(options, func_idx, descriptor.name) &&
    func_idx == @lib.FuncIdx::new(2944U) {
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
  if run_hot_pipeline_debug_dump_enabled(options, func_idx, descriptor.name) &&
    func_idx == @lib.FuncIdx::new(2941U) {
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
  match options.verify_policy {
    HotPipelineVerifyPolicy::AfterEachPass =>
      match
        pipeline_verify_checkpoint_with_perf(
          options.perf,
          options.verify_policy,
          "verify after lift",
          HotPipelineVerifyTarget::HotFuncTarget(func),
          "verify:after-lift",
        ) {
        Ok(_) => ()
        Err(err) => return Err(err)
      }
    HotPipelineVerifyPolicy::FinalModuleOnly => ()
  }
  let cache = @ir.HotAnalysisCache::new()
  let ctx = HotPassContext::new(
    descriptor,
    cache,
    options.verify_policy,
    options.closed_world,
    options.trace,
    perf=options.perf,
    module_ctx=Some(module_ctx),
  )
  match hot_pass_run(ctx, func) {
    Ok(result) =>
      if !result.changed &&
        @ir.hot_revision_current(func) == lifted_revision &&
        descriptor.name != "heap-store-optimization" &&
        !(descriptor.name == "dead-code-elimination" &&
        run_hot_pipeline_dce_raw_requires_lowering_even_if_unchanged(
          run_hot_pipeline_original_func(mod_, func_idx),
        )) {
        return Ok({
          reason: "",
          func: run_hot_pipeline_original_func(mod_, func_idx),
          unchanged_original: true,
          trace_skip_raw: false,
        })
      }
      Err(err) => return Err(err)
  }
  if run_hot_pipeline_debug_dump_enabled(options, func_idx, descriptor.name) &&
    func_idx == @lib.FuncIdx::new(2944U) {
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
  if run_hot_pipeline_debug_dump_enabled(options, func_idx, descriptor.name) &&
    func_idx == @lib.FuncIdx::new(2941U) {
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
  match options.verify_policy {
    HotPipelineVerifyPolicy::AfterEachPass =>
      match
        pipeline_verify_checkpoint_with_perf(
          options.perf,
          options.verify_policy,
          "verify before lower",
          HotPipelineVerifyTarget::HotFuncTarget(func),
          "verify:before-lower",
        ) {
        Ok(_) => {
          let lower_start_us = perf_start_timer_opt(options.perf, "lower")
          let lowered = @ir.hot_lower_func(func)
          perf_stop_timer_opt(options.perf, "lower", lower_start_us)
          Ok({
            reason: "",
            func: lowered,
            unchanged_original: false,
            trace_skip_raw: false,
          })
        }
        Err(err) => Err(err)
      }
    HotPipelineVerifyPolicy::FinalModuleOnly => {
      let lower_start_us = perf_start_timer_opt(options.perf, "lower")
      let lowered = @ir.hot_lower_func_unverified(func)
      perf_stop_timer_opt(options.perf, "lower", lower_start_us)
      Ok({
        reason: "",
        func: lowered,
        unchanged_original: false,
        trace_skip_raw: false,
      })
    }
  }
}

///|
fn run_hot_pipeline_original_func(
  mod_ : @lib.Module,
  func_idx : @lib.FuncIdx,
) -> @lib.Func {
  let imported_func_count = run_hot_pipeline_imported_func_count(mod_)
  let @lib.FuncIdx(raw) = func_idx
  let code_idx = raw.reinterpret_as_int() - imported_func_count
  if code_idx < 0 {
    abort("hot pipeline original func lookup requires a defined function index")
  }
  match mod_.code_sec {
    Some(@lib.CodeSec(defs)) =>
      match defs.get(code_idx) {
        Some(def) => def
        None =>
          abort(
            "hot pipeline original func lookup requires an existing code entry",
          )
      }
    None => abort("hot pipeline original func lookup requires a code section")
  }
}

///|
fn run_hot_pipeline_drop_label_names(mod_ : @lib.Module) -> @lib.Module {
  match mod_.name_sec {
    Some(name_sec) => {
      if name_sec.label_names is None {
        return mod_
      }
      mod_.with_name_sec(
        @lib.NameSec::new(
          module_name=name_sec.module_name,
          func_names=name_sec.func_names,
          local_names=name_sec.local_names,
          type_names=name_sec.type_names,
          table_names=name_sec.table_names,
          memory_names=name_sec.memory_names,
          global_names=name_sec.global_names,
          elem_names=name_sec.elem_names,
          data_names=name_sec.data_names,
          field_names=name_sec.field_names,
          tag_names=name_sec.tag_names,
        ),
      )
    }
    None => mod_
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
  if descriptor.name == "pick-load-signs" &&
    !run_hot_pipeline_module_has_memory(mod_) {
    pipeline_trace_hook(options.trace, descriptor.name, "skip-no-memory")
    return Ok(mod_)
  }
  let module_state = { module_ctx: None }
  let imported_func_count = run_hot_pipeline_imported_func_count(mod_)
  let next_code_sec = match mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let mut lowered : Array[@lib.Func]? = None
      let mut hso_raw_skip_count = 0
      for code_idx = 0; code_idx < defs.length(); code_idx = code_idx + 1 {
        let func_idx = @lib.FuncIdx::new(
          (imported_func_count + code_idx).reinterpret_as_uint(),
        )
        let result = match
          run_hot_pipeline_func(
            mod_, func_idx, descriptor, module_state, options,
          ) {
          Ok(result) => result
          Err(err) => return Err("func[\{func_idx}]: \{err}")
        }
        if result.trace_skip_raw {
          if descriptor.name == "heap-store-optimization" &&
            result.reason == "no-heap-store-candidates" {
            hso_raw_skip_count += 1
          } else {
            pipeline_trace_hook(
              options.trace,
              descriptor.name,
              "skip-raw",
              payload="reason=\{result.reason}",
            )
          }
        }
        match lowered {
          Some(defs_copy) => defs_copy[code_idx] = result.func
          None =>
            if !result.unchanged_original {
              let defs_copy = defs.copy()
              defs_copy[code_idx] = result.func
              lowered = Some(defs_copy)
            }
        }
      }
      if hso_raw_skip_count > 0 {
        pipeline_trace_hook(
          options.trace,
          descriptor.name,
          "skip-raw",
          payload="reason=no-heap-store-candidates count=\{hso_raw_skip_count}",
        )
      }
      match lowered {
        Some(lowered) => Some(@lib.CodeSec::new(lowered))
        None => None
      }
    }
    None => None
  }
  Ok(
    match next_code_sec {
      Some(code_sec) =>
        run_hot_pipeline_drop_label_names(mod_.with_code_sec(code_sec))
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
    "remove-unused-names" => remove_unused_names_run(ctx, func)
    "optimize-instructions" => optimize_instructions_run(ctx, func)
    "heap-store-optimization" => heap_store_optimization_run(ctx, func)
    "pick-load-signs" => pick_load_signs_run(ctx, func)
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
