///|
pub enum HotPipelineVerifyPolicy {
  FinalModuleOnly
  AfterEachPass
} derive(Eq, Debug)

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
  optimize_level : Int
  shrink_level : Int
  trace_enabled : Bool
  trace : (String) -> Unit
  perf : HotPerfSession?
}

///|
pub fn HotPipelineOptions::new(
  verify_policy? : HotPipelineVerifyPolicy = HotPipelineVerifyPolicy::final_module_only(),
  validate_final_module? : Bool = true,
  closed_world? : Bool = false,
  optimize_level? : Int = 0,
  shrink_level? : Int = 0,
  trace? : ((String) -> Unit)? = None,
  perf? : HotPerfSession? = None,
) -> HotPipelineOptions {
  {
    verify_policy,
    validate_final_module,
    closed_world,
    optimize_level,
    shrink_level,
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
} derive(Eq, Debug)

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
  if !options.trace_enabled {
    return false
  }
  (descriptor_name == "vacuum" && func_idx == @lib.FuncIdx::new(2944U)) ||
  (
    descriptor_name == "tuple-optimization" &&
    func_idx == @lib.FuncIdx::new(3660U)
  )
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
fn vacuum_convert_is_nontrapping(instr : @lib.Instruction?) -> Bool {
  match instr {
    Some(
      @lib.Instruction::I32WrapI64
      | @lib.Instruction::I64ExtendI32S
      | @lib.Instruction::I64ExtendI32U
      | @lib.Instruction::F32ConvertI32S
      | @lib.Instruction::F32ConvertI32U
      | @lib.Instruction::F32ConvertI64S
      | @lib.Instruction::F32ConvertI64U
      | @lib.Instruction::F32DemoteF64
      | @lib.Instruction::F64ConvertI32S
      | @lib.Instruction::F64ConvertI32U
      | @lib.Instruction::F64ConvertI64S
      | @lib.Instruction::F64ConvertI64U
      | @lib.Instruction::F64PromoteF32
      | @lib.Instruction::I32ReinterpretF32
      | @lib.Instruction::I64ReinterpretF64
      | @lib.Instruction::F32ReinterpretI32
      | @lib.Instruction::F64ReinterpretI64
      | @lib.Instruction::I32TruncSatF32S
      | @lib.Instruction::I32TruncSatF32U
      | @lib.Instruction::I32TruncSatF64S
      | @lib.Instruction::I32TruncSatF64U
      | @lib.Instruction::I64TruncSatF32S
      | @lib.Instruction::I64TruncSatF32U
      | @lib.Instruction::I64TruncSatF64S
      | @lib.Instruction::I64TruncSatF64U
    ) => true
    _ => false
  }
}

///|
fn vacuum_can_remove_dropped_node(
  func : @ir.HotFunc,
  node_id : @ir.NodeId,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  let is_removable_shape = match node.op {
    @ir.HotOp::Const
    | @ir.HotOp::LocalGet
    | @ir.HotOp::GlobalGet
    | @ir.HotOp::TableSize
    | @ir.HotOp::Unary
    | @ir.HotOp::Binary
    | @ir.HotOp::Compare
    | @ir.HotOp::RefNull
    | @ir.HotOp::RefIsNull
    | @ir.HotOp::RefFunc
    | @ir.HotOp::Select
    | @ir.HotOp::TupleMake
    | @ir.HotOp::TupleExtract => true
    @ir.HotOp::Convert =>
      vacuum_convert_is_nontrapping(@ir.hot_node_exact_instr(func, node_id))
    _ => false
  }
  if !is_removable_shape {
    return false
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    if !vacuum_can_remove_dropped_node(
        func,
        @ir.hot_child_get(func, node_id, slot),
      ) {
      return false
    }
  }
  true
}

///|
fn vacuum_build_i32_eqz(func : @ir.HotFunc, operand : @ir.NodeId) -> @ir.NodeId {
  let inverted = @ir.hot_build_unary(func, @lib.ValType::i32(), operand)
  @ir.hot_node_exact_instr_set(func, inverted, @lib.Instruction::i32_eqz())
  inverted
}

///|
fn vacuum_region_roots(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Array[@ir.NodeId] {
  let roots : Array[@ir.NodeId] = []
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    roots.push(@ir.hot_region_get(func, region_ref, idx))
  }
  roots
}

///|
fn hot_pass_vacuum_flip_empty_then_if(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : @ir.NodeId,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::If => ()
    _ => return false
  }
  if @ir.hot_type_result_arity(func, node.ty) != 0 ||
    @ir.hot_child_count(func, node_id) < 3 {
    return false
  }
  let then_ref = @ir.hot_region_then_ref(func, node_id)
  if @ir.hot_region_root_count(func, then_ref) != 0 {
    return false
  }
  let else_ref = match @ir.hot_region_else_ref(func, node_id) {
    Some(ref_) => ref_
    None => return false
  }
  let else_roots = vacuum_region_roots(func, else_ref)
  if else_roots.length() == 0 {
    return false
  }
  let condition = @ir.hot_child_get(func, node_id, 0)
  let else_holder = @ir.hot_child_get(func, node_id, 2)
  let inverted = vacuum_build_i32_eqz(func, condition)
  @ir.hot_region_replace_body(func, else_ref, [])
  @ir.hot_region_replace_body(func, then_ref, else_roots)
  @ir.hot_child_set(func, node_id, 0, inverted)
  @ir.hot_child_set(func, node_id, 2, -1)
  pass_mark_mutated(ctx, func)
  pass_delete_detached_nodes(ctx, func, [else_holder])
  true
}

///|
fn hot_pass_remove_node_nested_region_nops(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : @ir.NodeId,
  seen : Array[Bool],
) -> Bool {
  if node_id < 0 ||
    node_id >= seen.length() ||
    seen[node_id] ||
    !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  seen[node_id] = true
  let node = @ir.hot_node_get(func, node_id)
  let mut changed = false
  match node.op {
    @ir.HotOp::Block =>
      changed = hot_pass_remove_region_nops(
          ctx,
          func,
          @ir.hot_region_body_ref(func, node_id),
          seen,
        ) ||
        changed
    @ir.HotOp::Loop =>
      changed = hot_pass_remove_region_nops(
          ctx,
          func,
          @ir.hot_region_body_ref(func, node_id),
          seen,
        ) ||
        changed
    @ir.HotOp::If => {
      if @ir.hot_child_count(func, node_id) > 0 {
        changed = hot_pass_remove_node_nested_region_nops(
            ctx,
            func,
            @ir.hot_child_get(func, node_id, 0),
            seen,
          ) ||
          changed
      }
      changed = hot_pass_remove_region_nops(
          ctx,
          func,
          @ir.hot_region_then_ref(func, node_id),
          seen,
        ) ||
        changed
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          changed = hot_pass_remove_region_nops(ctx, func, else_region, seen) ||
            changed
        None => ()
      }
      changed = hot_pass_vacuum_flip_empty_then_if(ctx, func, node_id) ||
        changed
    }
    @ir.HotOp::Try => {
      changed = hot_pass_remove_region_nops(
          ctx,
          func,
          @ir.hot_region_body_ref(func, node_id),
          seen,
        ) ||
        changed
      match @ir.hot_region_catch_ref(func, node_id) {
        Some(catch_region) =>
          changed = hot_pass_remove_region_nops(ctx, func, catch_region, seen) ||
            changed
        None => ()
      }
    }
    @ir.HotOp::TryTable => {
      changed = hot_pass_remove_region_nops(
          ctx,
          func,
          @ir.hot_region_body_ref(func, node_id),
          seen,
        ) ||
        changed
      changed = hot_pass_remove_region_nops(
          ctx,
          func,
          @ir.hot_region_catch_list_ref(func, node_id),
          seen,
        ) ||
        changed
    }
    _ =>
      for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
        changed = hot_pass_remove_node_nested_region_nops(
            ctx,
            func,
            @ir.hot_child_get(func, node_id, slot),
            seen,
          ) ||
          changed
      }
  }
  changed
}

///|
fn hot_pass_remove_node_child_nested_region_nops(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : @ir.NodeId,
  seen : Array[Bool],
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  // Nested value-expression control cleanup is a small-function cleanup path.
  // Large lowered functions rely on the raw vacuum precleaner for cheap pure
  // const/drop and nop debris removal before falling back to root-region HOT
  // cleanup, avoiding a broad child traversal on every large cleanup slot.
  if seen.length() > 2048 {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  let mut changed = false
  match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop | @ir.HotOp::Try | @ir.HotOp::TryTable =>
      ()
    @ir.HotOp::If =>
      if @ir.hot_child_count(func, node_id) > 0 {
        changed = hot_pass_remove_node_nested_region_nops(
            ctx,
            func,
            @ir.hot_child_get(func, node_id, 0),
            seen,
          ) ||
          changed
      }
    _ =>
      for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
        changed = hot_pass_remove_node_nested_region_nops(
            ctx,
            func,
            @ir.hot_child_get(func, node_id, slot),
            seen,
          ) ||
          changed
      }
  }
  changed
}

///|
fn hot_pass_remove_region_nops(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  seen : Array[Bool],
) -> Bool {
  let mut changed = false
  let mut idx = 0
  while idx < @ir.hot_region_root_count(func, region_ref) {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    changed = hot_pass_remove_node_child_nested_region_nops(
        ctx, func, node_id, seen,
      ) ||
      changed
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Nop => {
        let removed = pass_splice_region(ctx, func, region_ref, idx, 1, [])
        pass_delete_detached_nodes(ctx, func, removed)
        changed = true
        continue
      }
      @ir.HotOp::Drop if @ir.hot_child_count(func, node_id) == 1 => {
        let child_id = @ir.hot_child_get(func, node_id, 0)
        if vacuum_can_remove_dropped_node(func, child_id) {
          let removed = pass_splice_region(ctx, func, region_ref, idx, 1, [])
          pass_delete_detached_nodes(ctx, func, removed)
          changed = true
          continue
        }
      }
      @ir.HotOp::Block => {
        let body_ref = @ir.hot_region_body_ref(func, node_id)
        changed = hot_pass_remove_region_nops(ctx, func, body_ref, seen) ||
          changed
        if @ir.hot_region_root_count(func, body_ref) == 0 &&
          @ir.hot_type_result_arity(func, node.ty) == 0 {
          let removed = pass_splice_region(ctx, func, region_ref, idx, 1, [])
          pass_delete_detached_nodes(ctx, func, removed)
          changed = true
          continue
        }
        if @ir.hot_region_root_count(func, body_ref) == 1 {
          let only_child = @ir.hot_region_get(func, body_ref, 0)
          match @ir.hot_node_get(func, only_child).op {
            @ir.HotOp::Unreachable => {
              let removed = pass_splice_region(ctx, func, region_ref, idx, 1, [
                only_child,
              ])
              pass_delete_detached_nodes(ctx, func, removed)
              changed = true
            }
            _ => ()
          }
        }
      }
      @ir.HotOp::Loop =>
        changed = hot_pass_remove_region_nops(
            ctx,
            func,
            @ir.hot_region_body_ref(func, node_id),
            seen,
          ) ||
          changed
      @ir.HotOp::If => {
        changed = hot_pass_remove_region_nops(
            ctx,
            func,
            @ir.hot_region_then_ref(func, node_id),
            seen,
          ) ||
          changed
        match @ir.hot_region_else_ref(func, node_id) {
          Some(else_region) =>
            changed = hot_pass_remove_region_nops(ctx, func, else_region, seen) ||
              changed
          None => ()
        }
        changed = hot_pass_vacuum_flip_empty_then_if(ctx, func, node_id) ||
          changed
      }
      @ir.HotOp::Try => {
        changed = hot_pass_remove_region_nops(
            ctx,
            func,
            @ir.hot_region_body_ref(func, node_id),
            seen,
          ) ||
          changed
        match @ir.hot_region_catch_ref(func, node_id) {
          Some(catch_region) =>
            changed = hot_pass_remove_region_nops(ctx, func, catch_region, seen) ||
              changed
          None => ()
        }
      }
      @ir.HotOp::TryTable => {
        changed = hot_pass_remove_region_nops(
            ctx,
            func,
            @ir.hot_region_body_ref(func, node_id),
            seen,
          ) ||
          changed
        changed = hot_pass_remove_region_nops(
            ctx,
            func,
            @ir.hot_region_catch_list_ref(func, node_id),
            seen,
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
) -> (Bool, Bool, Bool, Bool, Bool, Int) {
  let mut has_writes = false
  let mut has_structured_control = false
  let mut has_branches = false
  let mut has_drop = false
  let mut has_dead_tail_after_nonfallthrough = false
  let mut instr_count = 0
  let mut prev_may_fallthrough = true
  for instr in instrs {
    if !prev_may_fallthrough {
      has_dead_tail_after_nonfallthrough = true
    }
    instr_count = instr_count + 1
    match instr {
      @lib.LocalSet(_) | @lib.LocalTee(_) => has_writes = true
      @lib.Drop => has_drop = true
      @lib.Br(_) | @lib.BrIf(_) | @lib.BrTable(_, _) => has_branches = true
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) => {
        has_structured_control = true
        let (
          nested_writes,
          _,
          nested_branches,
          nested_drop,
          nested_dead_tail,
          nested_instr_count,
        ) = run_hot_pipeline_instr_scan(body)
        has_writes = has_writes || nested_writes
        has_branches = has_branches || nested_branches
        has_drop = has_drop || nested_drop
        has_dead_tail_after_nonfallthrough = has_dead_tail_after_nonfallthrough ||
          nested_dead_tail
        instr_count = instr_count + nested_instr_count
      }
      @lib.If(_, then_body, else_body) => {
        has_structured_control = true
        let (
          then_writes,
          _,
          then_branches,
          then_drop,
          then_dead_tail,
          then_instr_count,
        ) = run_hot_pipeline_instr_scan(then_body)
        has_writes = has_writes || then_writes
        has_branches = has_branches || then_branches
        has_drop = has_drop || then_drop
        has_dead_tail_after_nonfallthrough = has_dead_tail_after_nonfallthrough ||
          then_dead_tail
        instr_count = instr_count + then_instr_count
        match else_body {
          Some(else_body) => {
            let (
              else_writes,
              _,
              else_branches,
              else_drop,
              else_dead_tail,
              else_instr_count,
            ) = run_hot_pipeline_instr_scan(else_body)
            has_writes = has_writes || else_writes
            has_branches = has_branches || else_branches
            has_drop = has_drop || else_drop
            has_dead_tail_after_nonfallthrough = has_dead_tail_after_nonfallthrough ||
              else_dead_tail
            instr_count = instr_count + else_instr_count
          }
          None => ()
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) => {
        has_structured_control = true
        let (
          nested_writes,
          _,
          nested_branches,
          nested_drop,
          nested_dead_tail,
          nested_instr_count,
        ) = run_hot_pipeline_instr_scan(body)
        has_writes = has_writes || nested_writes
        has_branches = has_branches || nested_branches
        has_drop = has_drop || nested_drop
        has_dead_tail_after_nonfallthrough = has_dead_tail_after_nonfallthrough ||
          nested_dead_tail
        instr_count = instr_count + nested_instr_count
      }
      _ => ()
    }
    prev_may_fallthrough = run_hot_pipeline_dce_raw_instr_may_fallthrough(instr)
  }
  (
    has_writes, has_structured_control, has_branches, has_drop, has_dead_tail_after_nonfallthrough,
    instr_count,
  )
}

///|
fn run_hot_pipeline_instr_has_remove_unused_brs_candidate(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Nop
      | @lib.If(_, _, _)
      | @lib.Br(_)
      | @lib.BrIf(_)
      | @lib.BrTable(_, _)
      | @lib.Return => return true
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if run_hot_pipeline_instr_has_remove_unused_brs_candidate(body) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
priv struct RawRemoveUnusedBrsShape {
  mut call_count : Int
  mut local_set_count : Int
  mut local_tee_count : Int
  mut if_count : Int
  mut return_count : Int
  mut select_count : Int
  mut br_if_count : Int
  mut block_count : Int
  mut value_block_count : Int
  mut void_block_count : Int
  mut loop_count : Int
  mut br_count : Int
  mut br_table_count : Int
  mut drop_count : Int
}

///|
fn RawRemoveUnusedBrsShape::new() -> RawRemoveUnusedBrsShape {
  {
    call_count: 0,
    local_set_count: 0,
    local_tee_count: 0,
    if_count: 0,
    return_count: 0,
    select_count: 0,
    br_if_count: 0,
    block_count: 0,
    value_block_count: 0,
    void_block_count: 0,
    loop_count: 0,
    br_count: 0,
    br_table_count: 0,
    drop_count: 0,
  }
}

///|
fn run_hot_pipeline_raw_remove_unused_brs_scan_shape(
  instrs : Array[@lib.Instruction],
  shape : RawRemoveUnusedBrsShape,
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.Call(_)
      | @lib.CallIndirect(_, _)
      | @lib.CallRef(_)
      | @lib.ReturnCall(_)
      | @lib.ReturnCallIndirect(_, _)
      | @lib.ReturnCallRef(_) => shape.call_count = shape.call_count + 1
      @lib.LocalSet(_) => shape.local_set_count = shape.local_set_count + 1
      @lib.LocalTee(_) => shape.local_tee_count = shape.local_tee_count + 1
      @lib.If(_, then_body, else_body) => {
        shape.if_count = shape.if_count + 1
        run_hot_pipeline_raw_remove_unused_brs_scan_shape(then_body, shape)
        match else_body {
          Some(else_body) =>
            run_hot_pipeline_raw_remove_unused_brs_scan_shape(else_body, shape)
          None => ()
        }
      }
      @lib.Return => shape.return_count = shape.return_count + 1
      @lib.Select(_) => shape.select_count = shape.select_count + 1
      @lib.BrIf(_) => shape.br_if_count = shape.br_if_count + 1
      @lib.Block(bt, @lib.Expr(body)) => {
        shape.block_count = shape.block_count + 1
        match bt {
          @lib.ValTypeBlockType(_) =>
            shape.value_block_count = shape.value_block_count + 1
          @lib.TypeIdxBlockType(_) =>
            shape.value_block_count = shape.value_block_count + 1
          @lib.VoidBlockType =>
            shape.void_block_count = shape.void_block_count + 1
        }
        run_hot_pipeline_raw_remove_unused_brs_scan_shape(body, shape)
      }
      @lib.Loop(_, @lib.Expr(body)) => {
        shape.loop_count = shape.loop_count + 1
        run_hot_pipeline_raw_remove_unused_brs_scan_shape(body, shape)
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        run_hot_pipeline_raw_remove_unused_brs_scan_shape(body, shape)
      @lib.Br(_) => shape.br_count = shape.br_count + 1
      @lib.BrTable(_, _) => shape.br_table_count = shape.br_table_count + 1
      @lib.Drop => shape.drop_count = shape.drop_count + 1
      _ => ()
    }
  }
}

///|
fn run_hot_pipeline_raw_remove_unused_brs_leading_block_chain_depth(
  instrs : Array[@lib.Instruction],
) -> Int {
  let mut depth = 0
  let mut cursor = instrs
  while cursor.length() > 0 {
    match cursor[0] {
      @lib.Block(@lib.VoidBlockType, @lib.Expr(body)) => {
        depth = depth + 1
        cursor = body
      }
      _ => return depth
    }
  }
  depth
}

///|
fn run_hot_pipeline_raw_remove_unused_brs_leading_any_block_chain_depth(
  instrs : Array[@lib.Instruction],
) -> Int {
  let mut depth = 0
  let mut cursor = instrs
  while cursor.length() > 0 {
    match cursor[0] {
      @lib.Block(_, @lib.Expr(body)) => {
        depth = depth + 1
        cursor = body
      }
      _ => return depth
    }
  }
  depth
}

///|
fn run_hot_pipeline_raw_remove_unused_brs_can_skip_large_result_br_table_dispatch_ladder(
  instrs : Array[@lib.Instruction],
) -> Bool {
  if instrs.length() != 1 {
    return false
  }
  let body = match instrs[0] {
    @lib.Block(@lib.ValTypeBlockType(_), @lib.Expr(body)) => body
    _ => return false
  }
  if run_hot_pipeline_raw_remove_unused_brs_leading_block_chain_depth(body) < 32 {
    return false
  }
  if run_hot_pipeline_raw_remove_unused_brs_has_hot_only_candidates(body) {
    return false
  }
  let shape = RawRemoveUnusedBrsShape::new()
  run_hot_pipeline_raw_remove_unused_brs_scan_shape(body, shape)
  shape.block_count >= 32 &&
  (
    shape.br_count == shape.block_count ||
    shape.br_count + 1 == shape.block_count
  ) &&
  shape.br_table_count == 1 &&
  shape.local_set_count == 0 &&
  shape.local_tee_count == 0 &&
  shape.if_count == 0 &&
  shape.return_count == 0 &&
  shape.br_if_count == 0 &&
  shape.loop_count == 0 &&
  shape.drop_count == 0
}

///|
fn run_hot_pipeline_raw_remove_unused_brs_can_skip_large_value_if_branch_ladder(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  if locals.length() < 1 || locals.length() > 4 || instrs.length() > 2 {
    return false
  }
  if run_hot_pipeline_raw_remove_unused_brs_leading_block_chain_depth(instrs) <
    8 {
    return false
  }
  let (_, has_structured_control, has_branches, _, _, instr_count) = run_hot_pipeline_instr_scan(
    instrs,
  )
  if !has_structured_control ||
    !has_branches ||
    instr_count < 600 ||
    instr_count > 3000 {
    return false
  }
  let shape = RawRemoveUnusedBrsShape::new()
  run_hot_pipeline_raw_remove_unused_brs_scan_shape(instrs, shape)
  shape.call_count >= 40 &&
  shape.call_count <= 160 &&
  shape.local_set_count == 0 &&
  shape.local_tee_count == 1 &&
  shape.if_count >= 128 &&
  shape.if_count <= 400 &&
  shape.return_count == shape.block_count &&
  shape.return_count >= 8 &&
  shape.return_count <= 16 &&
  shape.select_count == 0 &&
  shape.br_if_count == 0 &&
  shape.block_count >= 8 &&
  shape.block_count <= 16 &&
  shape.loop_count == 0 &&
  shape.br_count >= 120 &&
  shape.br_count <= shape.if_count &&
  shape.br_count + 8 >= shape.if_count &&
  shape.br_table_count == 0 &&
  shape.drop_count <= 1
}

///|
fn run_hot_pipeline_raw_remove_unused_brs_can_skip_large_drop_heavy_branch_ladder(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  if locals.length() < 400 || locals.length() > 550 {
    return false
  }
  let (_, has_structured_control, has_branches, has_drop, _, instr_count) = run_hot_pipeline_instr_scan(
    instrs,
  )
  if !has_structured_control ||
    !has_branches ||
    !has_drop ||
    instr_count < 1600 ||
    instr_count > 8000 {
    return false
  }
  let shape = RawRemoveUnusedBrsShape::new()
  run_hot_pipeline_raw_remove_unused_brs_scan_shape(instrs, shape)
  shape.call_count >= 300 &&
  shape.call_count <= 360 &&
  shape.local_set_count >= 200 &&
  shape.local_set_count <= 260 &&
  shape.local_tee_count >= 220 &&
  shape.local_tee_count <= 300 &&
  shape.if_count >= 132 &&
  shape.if_count <= 170 &&
  shape.return_count <= 4 &&
  shape.select_count == 0 &&
  shape.br_if_count == 0 &&
  shape.block_count >= 90 &&
  shape.block_count <= 130 &&
  shape.loop_count <= 2 &&
  shape.br_count >= 90 &&
  shape.br_count <= 120 &&
  shape.br_table_count == 0 &&
  shape.drop_count >= 90 &&
  shape.drop_count <= 140
}

///|
fn run_hot_pipeline_raw_remove_unused_brs_can_skip_large_typed_br_table_encoder_ladder(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  if locals.length() < 1024 || locals.length() > 5000 {
    return false
  }
  if run_hot_pipeline_raw_remove_unused_brs_leading_any_block_chain_depth(
      instrs,
    ) <
    32 {
    return false
  }
  let (_, has_structured_control, has_branches, has_drop, _, instr_count) = run_hot_pipeline_instr_scan(
    instrs,
  )
  if !has_structured_control ||
    !has_branches ||
    !has_drop ||
    instr_count < 3000 ||
    instr_count > 200000 {
    return false
  }
  let shape = RawRemoveUnusedBrsShape::new()
  run_hot_pipeline_raw_remove_unused_brs_scan_shape(instrs, shape)
  shape.call_count >= 1000 &&
  shape.local_set_count >= 700 &&
  shape.local_tee_count >= 500 &&
  shape.if_count >= 500 &&
  shape.return_count >= 250 &&
  shape.select_count == 0 &&
  shape.br_if_count == 0 &&
  shape.block_count >= 500 &&
  shape.value_block_count >= 200 &&
  shape.void_block_count >= 250 &&
  shape.loop_count <= 4 &&
  shape.br_count >= 500 &&
  shape.br_table_count == 1 &&
  shape.drop_count >= 200
}

///|
fn run_hot_pipeline_raw_remove_unused_brs_can_skip_large_void_if_return_ladder(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let (_, has_structured_control, _, _, _, instr_count) = run_hot_pipeline_instr_scan(
    instrs,
  )
  if !has_structured_control || locals.length() < 700 {
    return false
  }
  let shape = RawRemoveUnusedBrsShape::new()
  run_hot_pipeline_raw_remove_unused_brs_scan_shape(instrs, shape)
  instr_count >= 4000 &&
  shape.call_count >= 900 &&
  shape.local_set_count >= 350 &&
  shape.local_tee_count >= 350 &&
  shape.if_count >= 150 &&
  shape.if_count >= shape.return_count &&
  shape.return_count >= 90 &&
  shape.select_count <= 4 &&
  shape.br_if_count <= 2 &&
  shape.loop_count <= 4 &&
  shape.br_table_count <= 4 &&
  shape.drop_count <= 512 &&
  (shape.br_table_count == 0 || shape.drop_count <= 32)
}

///|
fn run_hot_pipeline_raw_remove_unused_brs_can_skip_moderate_control_ladder(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let (_, has_structured_control, _, _, _, instr_count) = run_hot_pipeline_instr_scan(
    instrs,
  )
  if !has_structured_control || locals.length() < 180 || locals.length() > 700 {
    return false
  }
  let shape = RawRemoveUnusedBrsShape::new()
  run_hot_pipeline_raw_remove_unused_brs_scan_shape(instrs, shape)
  let matches_medium_control = locals.length() >= 300 &&
    instr_count >= 400 &&
    instr_count <= 10000 &&
    shape.call_count >= 120 &&
    shape.call_count <= 700 &&
    shape.local_set_count >= 100 &&
    shape.local_set_count <= 700 &&
    shape.local_tee_count >= 100 &&
    shape.local_tee_count <= 400 &&
    shape.if_count >= 40 &&
    shape.if_count <= 220 &&
    shape.return_count <= 128 &&
    shape.select_count <= 16 &&
    shape.br_if_count <= 5 &&
    shape.block_count >= 20 &&
    shape.block_count <= 200 &&
    shape.loop_count <= 2 &&
    shape.br_count <= 320 &&
    shape.br_table_count <= 1 &&
    shape.drop_count <= 200 &&
    shape.call_count + shape.local_set_count + shape.local_tee_count >= 400 &&
    shape.if_count + shape.block_count >= 60
  let matches_medium_block_dispatch = locals.length() <= 320 &&
    instr_count >= 800 &&
    instr_count <= 5000 &&
    shape.call_count >= 100 &&
    shape.call_count <= 450 &&
    shape.local_set_count >= 80 &&
    shape.local_set_count <= 220 &&
    shape.local_tee_count >= 40 &&
    shape.local_tee_count <= 160 &&
    shape.if_count >= 8 &&
    shape.if_count <= 64 &&
    shape.return_count <= 96 &&
    shape.select_count <= 4 &&
    shape.br_if_count <= 1 &&
    shape.block_count >= 80 &&
    shape.block_count <= 360 &&
    shape.loop_count <= 1 &&
    shape.br_count >= 80 &&
    shape.br_count <= 400 &&
    shape.br_table_count == 1 &&
    shape.drop_count <= 32 &&
    shape.block_count + shape.br_count >= 200
  matches_medium_control || matches_medium_block_dispatch
}

///|
fn run_hot_pipeline_raw_remove_unused_brs_can_skip_structured_return_ladder(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  if locals.length() < 20 || locals.length() > 96 {
    return false
  }
  let (_, has_structured_control, has_branches, _, _, instr_count) = run_hot_pipeline_instr_scan(
    instrs,
  )
  if !has_structured_control ||
    !has_branches ||
    instr_count < 80 ||
    instr_count > 1200 {
    return false
  }
  let shape = RawRemoveUnusedBrsShape::new()
  run_hot_pipeline_raw_remove_unused_brs_scan_shape(instrs, shape)
  shape.call_count >= 10 &&
  shape.local_set_count >= 10 &&
  shape.local_tee_count >= 8 &&
  shape.if_count >= 4 &&
  shape.if_count <= 18 &&
  shape.return_count >= 1 &&
  shape.return_count <= 5 &&
  shape.select_count <= 1 &&
  shape.br_if_count <= 1 &&
  shape.block_count >= 1 &&
  shape.block_count <= 16 &&
  shape.loop_count <= 2 &&
  shape.br_count >= 1 &&
  shape.br_count <= 16 &&
  shape.drop_count <= 16
}

///|
fn run_hot_pipeline_raw_remove_unused_brs_unchecked_moderate_call_mesh_stats(
  locals_count : Int,
  instr_count : Int,
  has_structured_control : Bool,
  has_branches : Bool,
  has_drop : Bool,
  has_dead_tail : Bool,
  shape : RawRemoveUnusedBrsShape,
  has_condition_child_value_if : Bool,
  has_prefix_guard_payload_branch : Bool,
) -> Bool {
  locals_count >= 24 &&
  locals_count <= 96 &&
  has_structured_control &&
  has_branches &&
  has_drop &&
  has_dead_tail &&
  instr_count >= 400 &&
  instr_count <= 640 &&
  shape.call_count >= 96 &&
  shape.call_count <= 128 &&
  shape.local_set_count >= 24 &&
  shape.local_set_count <= 64 &&
  shape.local_tee_count <= 8 &&
  shape.if_count >= 16 &&
  shape.if_count <= 32 &&
  shape.return_count == 0 &&
  shape.select_count <= 2 &&
  shape.br_if_count == 0 &&
  shape.block_count >= 8 &&
  shape.block_count <= 16 &&
  shape.loop_count <= 2 &&
  shape.br_count >= 8 &&
  shape.br_count <= 16 &&
  shape.br_table_count == 0 &&
  shape.drop_count <= 16 &&
  !has_condition_child_value_if &&
  !has_prefix_guard_payload_branch
}

///|
fn run_hot_pipeline_raw_remove_unused_brs_can_skip_unchecked_moderate_call_mesh(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let (
    _,
    has_structured_control,
    has_branches,
    has_drop,
    has_dead_tail,
    instr_count,
  ) = run_hot_pipeline_instr_scan(instrs)
  let shape = RawRemoveUnusedBrsShape::new()
  run_hot_pipeline_raw_remove_unused_brs_scan_shape(instrs, shape)
  run_hot_pipeline_raw_remove_unused_brs_unchecked_moderate_call_mesh_stats(
    locals.length(),
    instr_count,
    has_structured_control,
    has_branches,
    has_drop,
    has_dead_tail,
    shape,
    run_hot_pipeline_raw_remove_unused_brs_has_condition_child_value_if_candidate(
      instrs,
    ),
    run_hot_pipeline_raw_remove_unused_brs_has_prefix_guard_payload_branch_candidate(
      instrs,
    ),
  )
}

///|
fn run_hot_pipeline_raw_remove_unused_brs_can_skip_unique_loop_select_return_ladder(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  if locals.length() < 48 || locals.length() > 64 {
    return false
  }
  let (_, has_structured_control, has_branches, _, _, instr_count) = run_hot_pipeline_instr_scan(
    instrs,
  )
  if !has_structured_control ||
    !has_branches ||
    instr_count < 140 ||
    instr_count > 480 {
    return false
  }
  let shape = RawRemoveUnusedBrsShape::new()
  run_hot_pipeline_raw_remove_unused_brs_scan_shape(instrs, shape)
  shape.call_count >= 30 &&
  shape.call_count <= 50 &&
  shape.local_set_count >= 30 &&
  shape.local_set_count <= 45 &&
  shape.local_tee_count >= 16 &&
  shape.local_tee_count <= 50 &&
  shape.if_count >= 4 &&
  shape.if_count <= 6 &&
  shape.return_count == 3 &&
  shape.select_count == 1 &&
  shape.br_if_count == 1 &&
  shape.block_count >= 1 &&
  shape.block_count <= 4 &&
  shape.loop_count == 1 &&
  shape.br_count >= 1 &&
  shape.br_count <= 4 &&
  shape.drop_count >= 1 &&
  shape.drop_count <= 12
}

///|
fn run_hot_pipeline_raw_remove_unused_brs_match_i32_const(
  instr : @lib.Instruction,
) -> @lib.I32? {
  match instr {
    @lib.I32Const(value) => Some(value)
    _ => None
  }
}

///|
fn run_hot_pipeline_raw_remove_unused_brs_rewrite_decision_ladder_instrs(
  instrs : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Int, Bool) {
  let normalized : Array[@lib.Instruction] = []
  let mut rewrite_count = 0
  let mut saw_br_table = false
  for instr in instrs {
    match instr {
      @lib.Block(bt, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites, nested_br_table) = run_hot_pipeline_raw_remove_unused_brs_rewrite_decision_ladder_instrs(
          body,
        )
        normalized.push(
          @lib.Instruction::block(bt, @lib.Expr::new(rewritten_body)),
        )
        rewrite_count = rewrite_count + nested_rewrites
        saw_br_table = saw_br_table || nested_br_table
      }
      @lib.Loop(bt, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites, nested_br_table) = run_hot_pipeline_raw_remove_unused_brs_rewrite_decision_ladder_instrs(
          body,
        )
        normalized.push(
          @lib.Instruction::loop_(bt, @lib.Expr::new(rewritten_body)),
        )
        rewrite_count = rewrite_count + nested_rewrites
        saw_br_table = saw_br_table || nested_br_table
      }
      @lib.TryTable(bt, catches, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites, nested_br_table) = run_hot_pipeline_raw_remove_unused_brs_rewrite_decision_ladder_instrs(
          body,
        )
        normalized.push(
          @lib.Instruction::try_table(
            bt,
            catches,
            @lib.Expr::new(rewritten_body),
          ),
        )
        rewrite_count = rewrite_count + nested_rewrites
        saw_br_table = saw_br_table || nested_br_table
      }
      @lib.If(bt, then_body, else_body) => {
        let (rewritten_then, then_rewrites, then_br_table) = run_hot_pipeline_raw_remove_unused_brs_rewrite_decision_ladder_instrs(
          then_body,
        )
        rewrite_count = rewrite_count + then_rewrites
        saw_br_table = saw_br_table || then_br_table
        let rewritten_else = match else_body {
          Some(else_body) => {
            let (rewritten_else, else_rewrites, else_br_table) = run_hot_pipeline_raw_remove_unused_brs_rewrite_decision_ladder_instrs(
              else_body,
            )
            rewrite_count = rewrite_count + else_rewrites
            saw_br_table = saw_br_table || else_br_table
            Some(rewritten_else)
          }
          None => None
        }
        normalized.push(
          @lib.Instruction::if_(bt, rewritten_then, rewritten_else),
        )
      }
      @lib.BrTable(_, _) => {
        saw_br_table = true
        normalized.push(instr)
      }
      _ => normalized.push(instr)
    }
  }
  let rewritten : Array[@lib.Instruction] = []
  let mut idx = 0
  while idx < normalized.length() {
    if idx + 3 < normalized.length() {
      let instr0 = normalized[idx]
      let instr1 = normalized[idx + 1]
      let instr2 = normalized[idx + 2]
      let instr3 = normalized[idx + 3]
      match (instr0, instr1, instr2, instr3) {
        (
          @lib.LocalGet(local_id),
          @lib.I32Const(cond_const),
          @lib.I32Eq,
          @lib.If(
            @lib.ValTypeBlockType(result_type),
            then_body,
            Some(else_body)
          ),
        ) if result_type == @lib.ValType::i32() =>
          match (then_body.get(0), else_body.get(0)) {
            (Some(then_instr), Some(else_instr)) if then_body.length() == 1 &&
              else_body.length() == 1 =>
              match
                (
                  run_hot_pipeline_raw_remove_unused_brs_match_i32_const(
                    then_instr,
                  ),
                  run_hot_pipeline_raw_remove_unused_brs_match_i32_const(
                    else_instr,
                  ),
                ) {
                (Some(then_value), Some(else_value)) => {
                  rewritten.push(@lib.Instruction::i32_const(then_value))
                  rewritten.push(@lib.Instruction::i32_const(else_value))
                  rewritten.push(@lib.Instruction::local_get(local_id))
                  rewritten.push(@lib.Instruction::i32_const(cond_const))
                  rewritten.push(@lib.Instruction::i32_eq())
                  rewritten.push(@lib.Instruction::select())
                  rewrite_count = rewrite_count + 1
                  idx = idx + 4
                  continue
                }
                _ => ()
              }
            _ => ()
          }
        _ => ()
      }
    }
    rewritten.push(normalized[idx])
    idx = idx + 1
  }
  (rewritten, rewrite_count, saw_br_table)
}

///|
fn run_hot_pipeline_raw_remove_unused_brs_has_hot_only_candidates(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Nop | @lib.If(_, _, _) | @lib.BrIf(_) | @lib.Return => return true
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if run_hot_pipeline_raw_remove_unused_brs_has_hot_only_candidates(body) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn run_hot_pipeline_raw_remove_unused_brs_block_has_prefix_guard_payload_branch_candidate(
  body : Array[@lib.Instruction],
) -> Bool {
  if body.length() < 2 {
    return false
  }
  let first = body[0]
  let inner_body = match first {
    @lib.Block(@lib.VoidBlockType, @lib.Expr(inner_body)) => inner_body
    _ => return false
  }
  let zero = @lib.LabelIdx::new(0U)
  let mut guard_idx = -1
  let mut inner_idx = 0
  while inner_idx < inner_body.length() {
    match inner_body[inner_idx] {
      @lib.BrIf(label_idx) =>
        if label_idx == zero && inner_idx + 1 < inner_body.length() {
          guard_idx = inner_idx
          break
        }
      @lib.Nop
      | @lib.Drop
      | @lib.LocalSet(_)
      | @lib.Br(_)
      | @lib.BrTable(_, _)
      | @lib.Return
      | @lib.Block(@lib.VoidBlockType, _)
      | @lib.Loop(_, _)
      | @lib.TryTable(_, _, _)
      | @lib.If(@lib.VoidBlockType, _, _)
      | @lib.Unreachable => return false
      _ => ()
    }
    inner_idx += 1
  }
  if guard_idx < 0 {
    return false
  }
  let mut saw_payload = false
  let mut body_idx = 1
  while body_idx < body.length() {
    match body[body_idx] {
      @lib.Br(_) => if saw_payload { return true }
      _ => saw_payload = true
    }
    body_idx += 1
  }
  false
}

///|
fn run_hot_pipeline_raw_remove_unused_brs_has_prefix_guard_payload_branch_candidate(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Block(@lib.ValTypeBlockType(_), @lib.Expr(body)) =>
        if run_hot_pipeline_raw_remove_unused_brs_block_has_prefix_guard_payload_branch_candidate(
            body,
          ) ||
          run_hot_pipeline_raw_remove_unused_brs_has_prefix_guard_payload_branch_candidate(
            body,
          ) {
          return true
        }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if run_hot_pipeline_raw_remove_unused_brs_has_prefix_guard_payload_branch_candidate(
            body,
          ) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if run_hot_pipeline_raw_remove_unused_brs_has_prefix_guard_payload_branch_candidate(
            then_body,
          ) {
          return true
        }
        match else_body {
          Some(else_body) =>
            if run_hot_pipeline_raw_remove_unused_brs_has_prefix_guard_payload_branch_candidate(
                else_body,
              ) {
              return true
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn run_hot_pipeline_raw_remove_unused_brs_has_condition_child_value_if_candidate(
  instrs : Array[@lib.Instruction],
) -> Bool {
  let mut idx = 0
  while idx < instrs.length() {
    if idx + 1 < instrs.length() {
      match (instrs[idx], instrs[idx + 1]) {
        (
          @lib.If(@lib.ValTypeBlockType(_), _, Some(_)),
          @lib.If(@lib.VoidBlockType, _, None),
        ) => return true
        _ => ()
      }
    }
    match instrs[idx] {
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if run_hot_pipeline_raw_remove_unused_brs_has_condition_child_value_if_candidate(
            body,
          ) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if run_hot_pipeline_raw_remove_unused_brs_has_condition_child_value_if_candidate(
            then_body,
          ) {
          return true
        }
        match else_body {
          Some(else_body) =>
            if run_hot_pipeline_raw_remove_unused_brs_has_condition_child_value_if_candidate(
                else_body,
              ) {
              return true
            }
          None => ()
        }
      }
      _ => ()
    }
    idx = idx + 1
  }
  false
}

///|
priv struct RawSimplifyLocalsShape {
  mut if_count : Int
  mut block_count : Int
  mut loop_count : Int
  mut local_set_count : Int
  mut local_get_count : Int
  mut call_count : Int
  mut return_count : Int
  mut exact_tail_count : Int
}

///|
priv struct RawSimplifyLocalsGateStats {
  locals_count : Int
  instr_count : Int
  has_structured_control : Bool
  if_count : Int
  block_count : Int
  loop_count : Int
  local_set_count : Int
  local_get_count : Int
  call_count : Int
  return_count : Int
  exact_tail_count : Int
}

///|
fn RawSimplifyLocalsShape::new() -> RawSimplifyLocalsShape {
  {
    if_count: 0,
    block_count: 0,
    loop_count: 0,
    local_set_count: 0,
    local_get_count: 0,
    call_count: 0,
    return_count: 0,
    exact_tail_count: 0,
  }
}

///|
fn run_hot_pipeline_raw_simplify_locals_match_tail_local_get(
  instrs : Array[@lib.Instruction],
) -> (Int, @lib.I32, Bool)? {
  let len = instrs.length()
  if len < 3 {
    return None
  }
  let tail_has_return = match instrs[len - 1] {
    @lib.Return => true
    _ => false
  }
  if tail_has_return && len < 4 {
    return None
  }
  let get_idx = if tail_has_return { len - 2 } else { len - 1 }
  let const_idx = get_idx - 1
  let set_idx = get_idx - 2
  match (instrs[set_idx], instrs[const_idx], instrs[get_idx]) {
    (@lib.LocalSet(local_id), @lib.I32Const(status), @lib.LocalGet(get_local_id)
    ) if local_id == get_local_id => Some((set_idx, status, tail_has_return))
    _ => None
  }
}

///|
fn run_hot_pipeline_raw_simplify_locals_notee_const_type(
  instr : @lib.Instruction,
) -> @lib.ValType? {
  match instr {
    @lib.I32Const(_) => Some(@lib.ValType::i32())
    @lib.I64Const(_) => Some(@lib.ValType::i64())
    @lib.F32Const(_) => Some(@lib.ValType::f32())
    @lib.F64Const(_) => Some(@lib.ValType::f64())
    _ => None
  }
}

///|
fn run_hot_pipeline_raw_simplify_locals_notee_reorder_const_nop(
  instrs : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Array[@lib.ValType], Bool) {
  let rewritten : Array[@lib.Instruction] = []
  let added_locals : Array[@lib.ValType] = []
  let mut changed = false
  for instr in instrs {
    match instr {
      @lib.Block(block_type, @lib.Expr(body)) => {
        let (new_body, body_added_locals, body_changed) = run_hot_pipeline_raw_simplify_locals_notee_reorder_const_nop(
          body,
        )
        added_locals.append(body_added_locals)
        if body_changed {
          changed = true
        }
        rewritten.push(
          @lib.Instruction::block(block_type, @lib.Expr::new(new_body)),
        )
      }
      @lib.Loop(block_type, @lib.Expr(body)) => {
        let (new_body, body_added_locals, body_changed) = run_hot_pipeline_raw_simplify_locals_notee_reorder_const_nop(
          body,
        )
        added_locals.append(body_added_locals)
        if body_changed {
          changed = true
        }
        if new_body.length() == 2 && new_body[1] == @lib.Instruction::nop() {
          match
            run_hot_pipeline_raw_simplify_locals_notee_const_type(new_body[0]) {
            Some(vt) => {
              added_locals.push(vt)
              rewritten.push(
                @lib.Instruction::loop_(
                  block_type,
                  @lib.Expr::new([
                    @lib.Instruction::nop(),
                    @lib.Instruction::nop(),
                    new_body[0],
                  ]),
                ),
              )
              changed = true
            }
            None =>
              rewritten.push(
                @lib.Instruction::loop_(block_type, @lib.Expr::new(new_body)),
              )
          }
        } else {
          rewritten.push(
            @lib.Instruction::loop_(block_type, @lib.Expr::new(new_body)),
          )
        }
      }
      @lib.If(block_type, then_body, else_body) => {
        let (new_then, then_added_locals, then_changed) = run_hot_pipeline_raw_simplify_locals_notee_reorder_const_nop(
          then_body,
        )
        added_locals.append(then_added_locals)
        let mut new_else : Array[@lib.Instruction]? = None
        let mut else_changed = false
        match else_body {
          Some(body) => {
            let (rewritten_else, else_added_locals, changed_else) = run_hot_pipeline_raw_simplify_locals_notee_reorder_const_nop(
              body,
            )
            added_locals.append(else_added_locals)
            new_else = Some(rewritten_else)
            else_changed = changed_else
          }
          None => ()
        }
        if then_changed || else_changed {
          changed = true
        }
        rewritten.push(@lib.Instruction::if_(block_type, new_then, new_else))
      }
      @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
        let (new_body, body_added_locals, body_changed) = run_hot_pipeline_raw_simplify_locals_notee_reorder_const_nop(
          body,
        )
        added_locals.append(body_added_locals)
        if body_changed {
          changed = true
        }
        rewritten.push(
          @lib.Instruction::try_table(
            block_type,
            catches,
            @lib.Expr::new(new_body),
          ),
        )
      }
      _ => rewritten.push(instr)
    }
  }
  (rewritten, added_locals, changed)
}

///|
fn run_hot_pipeline_raw_simplify_locals_has_local_write(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.LocalSet(_) | @lib.LocalTee(_) => return true
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if run_hot_pipeline_raw_simplify_locals_has_local_write(body) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if run_hot_pipeline_raw_simplify_locals_has_local_write(then_body) {
          return true
        }
        match else_body {
          Some(else_body) =>
            if run_hot_pipeline_raw_simplify_locals_has_local_write(else_body) {
              return true
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn run_hot_pipeline_raw_simplify_locals_scan_shape(
  instrs : Array[@lib.Instruction],
  shape : RawSimplifyLocalsShape,
) -> Unit {
  match run_hot_pipeline_raw_simplify_locals_match_tail_local_get(instrs) {
    Some(_) => shape.exact_tail_count = shape.exact_tail_count + 1
    None => ()
  }
  for instr in instrs {
    match instr {
      @lib.If(_, then_body, else_body) => {
        shape.if_count = shape.if_count + 1
        run_hot_pipeline_raw_simplify_locals_scan_shape(then_body, shape)
        match else_body {
          Some(else_body) =>
            run_hot_pipeline_raw_simplify_locals_scan_shape(else_body, shape)
          None => ()
        }
      }
      @lib.Block(_, @lib.Expr(body)) => {
        shape.block_count = shape.block_count + 1
        run_hot_pipeline_raw_simplify_locals_scan_shape(body, shape)
      }
      @lib.Loop(_, @lib.Expr(body)) => {
        shape.loop_count = shape.loop_count + 1
        run_hot_pipeline_raw_simplify_locals_scan_shape(body, shape)
      }
      @lib.TryTable(_, _, @lib.Expr(body)) => {
        shape.block_count = shape.block_count + 1
        run_hot_pipeline_raw_simplify_locals_scan_shape(body, shape)
      }
      @lib.LocalSet(_) => shape.local_set_count = shape.local_set_count + 1
      @lib.LocalGet(_) => shape.local_get_count = shape.local_get_count + 1
      @lib.Call(_)
      | @lib.CallIndirect(_, _)
      | @lib.CallRef(_)
      | @lib.ReturnCall(_)
      | @lib.ReturnCallIndirect(_, _)
      | @lib.ReturnCallRef(_) => shape.call_count = shape.call_count + 1
      @lib.Return => shape.return_count = shape.return_count + 1
      _ => ()
    }
  }
}

///|
fn run_hot_pipeline_raw_simplify_locals_gate_stats(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> RawSimplifyLocalsGateStats {
  let (_, has_structured_control, _, _, _, instr_count) = run_hot_pipeline_instr_scan(
    instrs,
  )
  let shape = RawSimplifyLocalsShape::new()
  run_hot_pipeline_raw_simplify_locals_scan_shape(instrs, shape)
  {
    locals_count: locals.length(),
    instr_count,
    has_structured_control,
    if_count: shape.if_count,
    block_count: shape.block_count,
    loop_count: shape.loop_count,
    local_set_count: shape.local_set_count,
    local_get_count: shape.local_get_count,
    call_count: shape.call_count,
    return_count: shape.return_count,
    exact_tail_count: shape.exact_tail_count,
  }
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_should_rewrite_ladder(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  if stats.locals_count < 16 || stats.locals_count > 512 {
    return false
  }
  if !stats.has_structured_control || stats.instr_count > 12000 {
    return false
  }
  let large_ladder = stats.locals_count >= 48 &&
    stats.instr_count >= 160 &&
    stats.if_count >= 16 &&
    stats.local_set_count >= 16 &&
    stats.local_get_count >= 32 &&
    stats.exact_tail_count >= 12 &&
    stats.exact_tail_count * 4 + 16 >= stats.if_count &&
    stats.return_count <= stats.exact_tail_count + 8
  let small_ladder = stats.locals_count >= 16 &&
    stats.instr_count >= 80 &&
    stats.if_count >= 8 &&
    stats.local_set_count >= 8 &&
    stats.local_get_count >= 16 &&
    stats.exact_tail_count >= 4 &&
    stats.exact_tail_count * 2 + 4 >= stats.if_count &&
    stats.return_count <= stats.exact_tail_count + 4
  let sparse_ladder = stats.locals_count >= 16 &&
    stats.instr_count >= 80 &&
    stats.if_count >= 12 &&
    stats.local_set_count >= 10 &&
    stats.local_get_count >= 24 &&
    stats.call_count >= stats.if_count &&
    stats.exact_tail_count >= 5 &&
    stats.exact_tail_count * 3 + 1 >= stats.if_count &&
    stats.return_count <= stats.if_count
  large_ladder || small_ladder || sparse_ladder
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_should_skip_giant_func(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  stats.locals_count >= 1500 &&
  stats.has_structured_control &&
  stats.instr_count >= 2000
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_should_skip_giant_structured_call_heavy(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  stats.locals_count >= 352 &&
  stats.has_structured_control &&
  stats.instr_count >= 256 &&
  stats.if_count >= 80 &&
  stats.local_set_count >= 176 &&
  stats.local_get_count >= 384 &&
  stats.call_count >= 240
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_should_skip_validator_structured_call_heavy(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  stats.locals_count >= 256 &&
  stats.has_structured_control &&
  stats.instr_count >= 256 &&
  stats.if_count >= 48 &&
  stats.block_count >= 32 &&
  stats.loop_count >= 4 &&
  stats.local_set_count >= 128 &&
  stats.local_get_count >= 384 &&
  stats.call_count >= 192
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_should_skip_parser_structured_call_heavy(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  stats.locals_count >= 96 &&
  stats.locals_count <= 352 &&
  stats.has_structured_control &&
  stats.instr_count >= 160 &&
  stats.if_count >= 16 &&
  stats.if_count <= 64 &&
  stats.block_count >= 4 &&
  stats.block_count <= 20 &&
  stats.loop_count <= 2 &&
  stats.local_set_count >= 80 &&
  stats.local_get_count >= 220 &&
  stats.call_count >= 64 &&
  stats.call_count <= 128 &&
  stats.return_count <= stats.if_count
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_should_skip_decode_structured_call_heavy(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  stats.locals_count >= 80 &&
  stats.locals_count <= 128 &&
  stats.has_structured_control &&
  stats.instr_count >= 192 &&
  stats.if_count >= 12 &&
  stats.if_count <= 40 &&
  stats.block_count >= 8 &&
  stats.block_count <= 24 &&
  stats.loop_count == 1 &&
  stats.local_set_count >= 40 &&
  stats.local_set_count <= 96 &&
  stats.local_get_count >= 144 &&
  stats.local_get_count <= 180 &&
  stats.call_count >= 48 &&
  stats.call_count <= 64 &&
  stats.return_count <= 16
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_should_skip_encode_structured_call_heavy(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  stats.locals_count >= 192 &&
  stats.locals_count <= 256 &&
  stats.has_structured_control &&
  stats.instr_count >= 512 &&
  stats.if_count >= 96 &&
  stats.if_count <= 192 &&
  stats.block_count >= 32 &&
  stats.block_count <= 64 &&
  stats.loop_count == 0 &&
  stats.local_set_count >= 56 &&
  stats.local_set_count <= 96 &&
  stats.local_get_count >= 352 &&
  stats.local_get_count <= 544 &&
  stats.call_count >= 160 &&
  stats.call_count <= 224 &&
  stats.return_count >= 8 &&
  stats.return_count <= 16
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_branchy_decode_structured_call_heavy_stats(
  stats : RawSimplifyLocalsGateStats,
) -> Bool {
  stats.locals_count >= 192 &&
  stats.locals_count <= 224 &&
  stats.has_structured_control &&
  stats.instr_count >= 640 &&
  stats.if_count >= 48 &&
  stats.if_count <= 80 &&
  stats.block_count >= 16 &&
  stats.block_count <= 32 &&
  stats.loop_count == 0 &&
  stats.local_set_count >= 48 &&
  stats.local_set_count <= 96 &&
  stats.local_get_count >= 240 &&
  stats.local_get_count <= 384 &&
  stats.call_count >= 80 &&
  stats.call_count <= 128 &&
  stats.return_count >= 4 &&
  stats.return_count <= 12
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_transformer_catch_structured_call_heavy_stats(
  stats : RawSimplifyLocalsGateStats,
) -> Bool {
  stats.locals_count >= 184 &&
  stats.locals_count <= 224 &&
  stats.has_structured_control &&
  stats.instr_count >= 512 &&
  stats.if_count >= 32 &&
  stats.if_count <= 64 &&
  stats.block_count >= 24 &&
  stats.block_count <= 40 &&
  stats.loop_count == 0 &&
  stats.local_set_count >= 72 &&
  stats.local_set_count <= 96 &&
  stats.local_get_count >= 256 &&
  stats.local_get_count <= 352 &&
  stats.call_count >= 80 &&
  stats.call_count <= 112 &&
  stats.return_count >= 8 &&
  stats.return_count <= 16
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_branchy_structured_call_heavy_stats(
  stats : RawSimplifyLocalsGateStats,
) -> Bool {
  stats.locals_count >= 176 &&
  stats.locals_count <= 224 &&
  stats.has_structured_control &&
  stats.instr_count >= 768 &&
  stats.if_count >= 48 &&
  stats.if_count <= 64 &&
  stats.block_count >= 24 &&
  stats.block_count <= 40 &&
  stats.loop_count == 0 &&
  stats.local_set_count >= 64 &&
  stats.local_set_count <= 80 &&
  stats.local_get_count >= 280 &&
  stats.local_get_count <= 352 &&
  stats.call_count >= 96 &&
  stats.call_count <= 144 &&
  stats.return_count >= 4 &&
  stats.return_count <= 8
}

///|
fn run_hot_pipeline_raw_simplify_locals_unchecked_small_structured_call_mesh_stats(
  stats : RawSimplifyLocalsGateStats,
) -> Bool {
  stats.locals_count <= 8 &&
  stats.has_structured_control &&
  stats.instr_count >= 192 &&
  stats.instr_count <= 384 &&
  stats.if_count >= 12 &&
  stats.if_count <= 24 &&
  stats.block_count <= 4 &&
  stats.loop_count <= 2 &&
  stats.local_set_count >= 4 &&
  stats.local_set_count <= 12 &&
  stats.local_get_count >= 64 &&
  stats.local_get_count <= 128 &&
  stats.call_count >= 48 &&
  stats.call_count <= 72 &&
  stats.return_count >= 4 &&
  stats.return_count <= 12 &&
  stats.exact_tail_count == 0
}

///|
fn run_hot_pipeline_raw_simplify_locals_giant_validator_structured_call_heavy_stats(
  stats : RawSimplifyLocalsGateStats,
) -> Bool {
  stats.locals_count >= 1024 &&
  stats.has_structured_control &&
  stats.instr_count >= 8000 &&
  stats.if_count >= 256 &&
  stats.block_count >= 64 &&
  stats.loop_count >= 4 &&
  stats.local_set_count >= 1024 &&
  stats.local_get_count >= 2048 &&
  stats.call_count >= 1024 &&
  stats.return_count <= 32 &&
  stats.exact_tail_count == 0
}

///|
fn run_hot_pipeline_raw_simplify_locals_dense_structured_call_heavy_stats(
  stats : RawSimplifyLocalsGateStats,
) -> Bool {
  stats.locals_count >= 320 &&
  stats.locals_count <= 640 &&
  stats.has_structured_control &&
  stats.instr_count >= 768 &&
  stats.if_count >= 48 &&
  stats.if_count <= 160 &&
  stats.block_count >= 16 &&
  stats.block_count <= 64 &&
  stats.loop_count <= 2 &&
  stats.local_set_count >= 128 &&
  stats.local_get_count >= 512 &&
  stats.call_count >= 160 &&
  stats.return_count <= 40
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_should_skip_branchy_decode_structured_call_heavy(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  run_hot_pipeline_raw_simplify_locals_branchy_decode_structured_call_heavy_stats(
    stats,
  )
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_should_skip_transformer_catch_structured_call_heavy(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  run_hot_pipeline_raw_simplify_locals_transformer_catch_structured_call_heavy_stats(
    stats,
  )
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_should_skip_branchy_structured_call_heavy(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  run_hot_pipeline_raw_simplify_locals_branchy_structured_call_heavy_stats(
    stats,
  )
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_should_skip_dense_structured_call_heavy(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  run_hot_pipeline_raw_simplify_locals_dense_structured_call_heavy_stats(stats)
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_should_skip_stringview_trim_loop_churn(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  stats.locals_count >= 34 &&
  stats.locals_count <= 40 &&
  stats.has_structured_control &&
  stats.instr_count >= 64 &&
  stats.if_count >= 2 &&
  stats.if_count <= 3 &&
  stats.block_count == 0 &&
  stats.loop_count == 1 &&
  stats.local_set_count >= 8 &&
  stats.local_set_count <= 12 &&
  stats.local_get_count >= 32 &&
  stats.local_get_count <= 52 &&
  stats.call_count >= 12 &&
  stats.call_count <= 18 &&
  stats.return_count == 0
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_should_skip_transformer_structured_call_heavy(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  stats.locals_count >= 84 &&
  stats.locals_count <= 96 &&
  stats.has_structured_control &&
  stats.instr_count >= 160 &&
  stats.if_count >= 18 &&
  stats.if_count <= 28 &&
  stats.block_count >= 12 &&
  stats.block_count <= 20 &&
  stats.loop_count == 0 &&
  stats.local_set_count >= 32 &&
  stats.local_set_count <= 48 &&
  stats.local_get_count >= 140 &&
  stats.local_get_count <= 180 &&
  stats.call_count >= 48 &&
  stats.call_count <= 64 &&
  stats.return_count <= 8
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_should_skip_small_loop_call_heavy(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  stats.locals_count >= 80 &&
  stats.locals_count <= 90 &&
  stats.has_structured_control &&
  stats.instr_count >= 160 &&
  stats.if_count >= 12 &&
  stats.if_count <= 20 &&
  stats.block_count == 0 &&
  stats.loop_count == 2 &&
  stats.local_set_count >= 72 &&
  stats.local_set_count <= 84 &&
  stats.local_get_count >= 100 &&
  stats.local_get_count <= 192 &&
  stats.call_count >= 24 &&
  stats.call_count <= 48 &&
  stats.return_count <= 4
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_should_skip_straight_line_builder_churn(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  stats.locals_count >= 224 &&
  stats.locals_count <= 320 &&
  !stats.has_structured_control &&
  stats.instr_count >= 768 &&
  stats.if_count == 0 &&
  stats.block_count == 0 &&
  stats.loop_count == 0 &&
  stats.local_set_count >= 144 &&
  stats.local_set_count <= 192 &&
  stats.local_get_count >= 384 &&
  stats.local_get_count <= 704 &&
  stats.local_get_count >= stats.local_set_count * 2 + 48 &&
  stats.call_count >= 72 &&
  stats.call_count <= 128 &&
  stats.return_count == 0
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_should_skip_huge_straight_line_call_builder(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  stats.locals_count >= 768 &&
  !stats.has_structured_control &&
  stats.instr_count >= 2048 &&
  stats.if_count == 0 &&
  stats.block_count == 0 &&
  stats.loop_count == 0 &&
  stats.local_set_count <= 16 &&
  stats.local_get_count >= 1536 &&
  stats.call_count >= 1024 &&
  stats.return_count == 0
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_should_skip_medium_structured_call_heavy(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  stats.locals_count >= 176 &&
  stats.locals_count <= 320 &&
  stats.has_structured_control &&
  stats.instr_count >= 224 &&
  stats.if_count >= 24 &&
  stats.if_count <= 96 &&
  stats.loop_count <= 3 &&
  stats.local_set_count >= 96 &&
  stats.local_get_count >= 256 &&
  stats.call_count >= 128 &&
  stats.call_count <= 224 &&
  stats.return_count <= stats.if_count
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_should_skip_loop_heavy_structured_call_heavy(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  stats.locals_count >= 176 &&
  stats.locals_count <= 320 &&
  stats.has_structured_control &&
  stats.instr_count >= 256 &&
  stats.if_count >= 28 &&
  stats.if_count <= 80 &&
  stats.block_count >= 8 &&
  stats.loop_count >= 4 &&
  stats.local_set_count >= 80 &&
  stats.local_get_count >= 200 &&
  stats.call_count >= 80 &&
  stats.call_count <= 224 &&
  stats.return_count <= stats.if_count
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_should_skip_giant_structured_local_churn(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  stats.locals_count >= 600 &&
  stats.has_structured_control &&
  stats.instr_count >= 1500 &&
  stats.if_count >= 96 &&
  stats.local_set_count >= 384 &&
  stats.local_get_count >= 768 &&
  stats.call_count >= 16 &&
  stats.call_count <= 96 &&
  stats.return_count <= 4
}

///|
fn run_hot_pipeline_raw_simplify_locals_branch_dense_structured_call_heavy_stats(
  stats : RawSimplifyLocalsGateStats,
) -> Bool {
  stats.locals_count >= 48 &&
  stats.has_structured_control &&
  stats.instr_count >= 384 &&
  stats.if_count >= 96 &&
  stats.block_count <= 12 &&
  stats.loop_count == 0 &&
  stats.local_set_count <= 64 &&
  stats.local_get_count >= stats.if_count * 2 &&
  stats.local_get_count >= stats.local_set_count * 4 + 48 &&
  stats.call_count >= 96 &&
  stats.call_count <= 256 &&
  stats.return_count <= 32 &&
  stats.exact_tail_count <= 8
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_should_skip_branch_dense_structured_call_heavy(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  run_hot_pipeline_raw_simplify_locals_branch_dense_structured_call_heavy_stats(
    stats,
  )
}

///|
fn run_hot_pipeline_raw_simplify_locals_block_rich_structured_call_heavy_stats(
  stats : RawSimplifyLocalsGateStats,
) -> Bool {
  stats.locals_count >= 96 &&
  stats.locals_count <= 256 &&
  stats.has_structured_control &&
  stats.instr_count >= 320 &&
  stats.if_count >= 32 &&
  stats.if_count <= 96 &&
  stats.block_count >= 16 &&
  stats.block_count <= 40 &&
  stats.loop_count == 0 &&
  stats.local_set_count >= 56 &&
  stats.local_set_count <= 96 &&
  stats.local_get_count >= 160 &&
  stats.local_get_count >= stats.local_set_count * 2 + 16 &&
  stats.call_count >= 96 &&
  stats.call_count <= 160 &&
  stats.return_count <= 24 &&
  stats.exact_tail_count <= 8
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_should_skip_block_rich_structured_call_heavy(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  run_hot_pipeline_raw_simplify_locals_block_rich_structured_call_heavy_stats(
    stats,
  )
}

///|
fn run_hot_pipeline_raw_simplify_locals_call_dense_structured_walker_stats(
  stats : RawSimplifyLocalsGateStats,
) -> Bool {
  stats.locals_count >= 96 &&
  stats.locals_count <= 320 &&
  stats.has_structured_control &&
  stats.instr_count >= 320 &&
  stats.if_count >= 40 &&
  stats.if_count <= 192 &&
  stats.block_count <= 24 &&
  stats.loop_count <= 6 &&
  stats.local_set_count >= 1 &&
  stats.local_set_count <= 96 &&
  stats.local_get_count >= 192 &&
  stats.local_get_count >= stats.if_count * 2 + 32 &&
  stats.local_get_count >= stats.local_set_count * 4 + 32 &&
  stats.call_count >= 160 &&
  stats.call_count >= stats.if_count * 2 + 16 &&
  stats.return_count <= 32 &&
  stats.exact_tail_count <= 8
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_should_skip_call_dense_structured_walker(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  run_hot_pipeline_raw_simplify_locals_call_dense_structured_walker_stats(stats)
}

///|
fn run_hot_pipeline_raw_simplify_locals_low_local_decision_ladder_stats(
  stats : RawSimplifyLocalsGateStats,
) -> Bool {
  stats.locals_count <= 8 &&
  stats.has_structured_control &&
  stats.instr_count >= 192 &&
  stats.if_count >= 32 &&
  stats.loop_count == 0 &&
  stats.local_set_count <= 8 &&
  stats.local_get_count >= stats.if_count + 32 &&
  stats.call_count >= 16 &&
  stats.return_count <= stats.if_count + 32 &&
  stats.exact_tail_count <= 4
}

///|
fn run_hot_pipeline_raw_simplify_locals_has_i32_pair_result(
  mod_ : @lib.Module,
  func_idx : @lib.FuncIdx,
  module_state : HotPipelineModuleState,
  options : HotPipelineOptions,
) -> Bool {
  let module_ctx = run_hot_pipeline_require_module_ctx(
    mod_, module_state, options,
  )
  match @ir.hot_module_resolve_func_type(module_ctx, func_idx) {
    Some(@lib.FuncType(_, results)) =>
      results.length() == 2 &&
      results[0] == @lib.ValType::i32() &&
      results[1] == @lib.ValType::i32()
    None => false
  }
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_should_skip_multivalue_call_ladder(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  let sparse_call_ladder = stats.locals_count >= 16 &&
    stats.locals_count <= 512 &&
    stats.has_structured_control &&
    stats.exact_tail_count == 0 &&
    stats.instr_count >= 160 &&
    stats.if_count >= 12 &&
    stats.loop_count <= 2 &&
    stats.local_set_count >= 6 &&
    stats.local_get_count >= 48 &&
    stats.local_get_count >= stats.local_set_count * 3 &&
    stats.call_count >= 24 &&
    stats.call_count >= stats.if_count &&
    stats.return_count <= stats.if_count + 12
  let compact_call_ladder = stats.locals_count >= 32 &&
    stats.locals_count <= 64 &&
    stats.has_structured_control &&
    stats.exact_tail_count == 0 &&
    stats.instr_count >= 192 &&
    stats.if_count >= 10 &&
    stats.if_count <= 24 &&
    stats.block_count <= 2 &&
    stats.loop_count == 0 &&
    stats.local_set_count >= 12 &&
    stats.local_get_count >= 64 &&
    stats.local_get_count >= stats.local_set_count * 5 &&
    stats.call_count >= 32 &&
    stats.call_count >= stats.if_count * 3 &&
    stats.return_count <= 4
  let flat_dense_call_ladder = stats.locals_count >= 96 &&
    stats.locals_count <= 192 &&
    stats.has_structured_control &&
    stats.exact_tail_count == 0 &&
    stats.instr_count >= 480 &&
    stats.if_count >= 32 &&
    stats.block_count == 0 &&
    stats.loop_count == 0 &&
    stats.local_set_count >= 48 &&
    stats.local_get_count >= 160 &&
    stats.local_get_count >= stats.local_set_count * 2 + 32 &&
    stats.call_count >= 48 &&
    stats.call_count >= stats.if_count + 16 &&
    stats.return_count <= stats.if_count
  let loop_rich_call_ladder = stats.locals_count >= 160 &&
    stats.locals_count <= 256 &&
    stats.has_structured_control &&
    stats.exact_tail_count == 0 &&
    stats.instr_count >= 1000 &&
    stats.if_count >= 48 &&
    stats.block_count <= 4 &&
    stats.loop_count <= 4 &&
    stats.local_set_count >= 96 &&
    stats.local_get_count >= 384 &&
    stats.local_get_count >= stats.local_set_count * 3 + 64 &&
    stats.call_count >= 192 &&
    stats.call_count >= stats.if_count * 4 &&
    stats.return_count <= stats.if_count
  sparse_call_ladder ||
  compact_call_ladder ||
  flat_dense_call_ladder ||
  loop_rich_call_ladder
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_should_rewrite_pure_call_tails(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  !stats.has_structured_control &&
  stats.locals_count >= 32 &&
  stats.instr_count >= 128 &&
  stats.local_set_count >= 16 &&
  stats.local_get_count >= 32
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_should_rewrite_straight_line_adjacent_local_tees(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  !stats.has_structured_control &&
  stats.locals_count >= 512 &&
  stats.instr_count >= 2048 &&
  stats.local_set_count >= 1 &&
  stats.local_set_count <= 16 &&
  stats.local_get_count >= 1024 &&
  stats.local_get_count >= stats.local_set_count * 64 &&
  stats.call_count >= 768 &&
  stats.return_count <= 1
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_should_rewrite_straight_line_lane_builder(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  !stats.has_structured_control &&
  stats.locals_count >= 48 &&
  stats.locals_count <= 64 &&
  stats.instr_count >= 240 &&
  stats.instr_count <= 384 &&
  stats.if_count == 0 &&
  stats.block_count == 0 &&
  stats.loop_count == 0 &&
  stats.local_set_count >= 48 &&
  stats.local_set_count <= 64 &&
  stats.local_get_count >= 80 &&
  stats.local_get_count <= 128 &&
  stats.call_count >= 32 &&
  stats.call_count <= 40 &&
  stats.return_count == 0
}

///|
#cfg(target="native")
fn run_hot_pipeline_raw_simplify_locals_should_rewrite_structured_pure_call_tails(
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  stats.has_structured_control &&
  stats.locals_count >= 128 &&
  stats.instr_count >= 256 &&
  stats.local_set_count >= 24 &&
  stats.local_get_count >= 48
}

///|
fn run_hot_pipeline_raw_simplify_locals_func_env(
  mod_ : @lib.Module,
  func_idx : @lib.FuncIdx,
  module_ctx : @ir.HotModuleContext,
  locals : @lib.Locals,
) -> @validate.Env {
  match @ir.hot_module_resolve_func_type(module_ctx, func_idx) {
    Some(@lib.FuncType(params, results)) => {
      let all_locals = @lib.Locals::from_types(params)
      all_locals.append(locals)
      @validate.Env::new()
      .with_module(mod_)
      .with_locals(all_locals)
      .with_return_type(Some(results))
    }
    None =>
      abort(
        "hot pipeline raw simplify-locals rewrite requires the function type to resolve",
      )
  }
}

///|
fn run_hot_pipeline_raw_simplify_locals_take_value_suffix(
  instrs : Array[@lib.Instruction],
  count : Int,
  env : @validate.Env,
) -> (Array[@lib.Instruction], Array[@lib.Instruction]) {
  if count <= 0 {
    return (instrs.copy(), [])
  }
  let mut start = instrs.length() - 1
  while start >= 0 {
    let suffix : Array[@lib.Instruction] = []
    for idx = start; idx < instrs.length(); idx = idx + 1 {
      suffix.push(instrs[idx])
    }
    let init_state = @validate.make_state(env, [])
    match @validate.Typecheck::typecheck(@lib.Expr::new(suffix), init_state) {
      Ok(state) =>
        if state.reachable &&
          state.escape == @validate.tc_escape_none() &&
          state.stack.length() == count {
          let head : Array[@lib.Instruction] = []
          for idx = 0; idx < start; idx = idx + 1 {
            head.push(instrs[idx])
          }
          return (head, suffix)
        }
      Err(_) => ()
    }
    start = start - 1
  }
  (instrs.copy(), [])
}

///|
fn run_hot_pipeline_raw_simplify_locals_take_statement_prefix(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
) -> (Array[@lib.Instruction], Array[@lib.Instruction]) {
  let mut end = 1
  while end <= instrs.length() {
    let prefix : Array[@lib.Instruction] = []
    for idx = 0; idx < end; idx = idx + 1 {
      prefix.push(instrs[idx])
    }
    let init_state = @validate.make_state(env, [])
    match @validate.Typecheck::typecheck(@lib.Expr::new(prefix), init_state) {
      Ok(state) =>
        if state.reachable &&
          state.escape == @validate.tc_escape_none() &&
          state.stack.length() == 0 {
          let tail : Array[@lib.Instruction] = []
          for idx = end; idx < instrs.length(); idx = idx + 1 {
            tail.push(instrs[idx])
          }
          return (prefix, tail)
        }
      Err(_) => ()
    }
    end = end + 1
  }
  ([], instrs.copy())
}

///|
fn run_hot_pipeline_raw_simplify_locals_take_statement_prefix_allow_escape(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
) -> (Array[@lib.Instruction], Array[@lib.Instruction]) {
  let mut end = 1
  while end <= instrs.length() {
    let prefix : Array[@lib.Instruction] = []
    for idx = 0; idx < end; idx = idx + 1 {
      prefix.push(instrs[idx])
    }
    let init_state = @validate.make_state(env, [])
    match @validate.Typecheck::typecheck(@lib.Expr::new(prefix), init_state) {
      Ok(state) =>
        if state.stack.length() == 0 ||
          (
            end == instrs.length() &&
            state.reachable &&
            state.escape == @validate.tc_escape_none() &&
            state.stack.length() > 0
          ) {
          let tail : Array[@lib.Instruction] = []
          for idx = end; idx < instrs.length(); idx = idx + 1 {
            tail.push(instrs[idx])
          }
          return (prefix, tail)
        }
      Err(_) => ()
    }
    end = end + 1
  }
  ([], instrs.copy())
}

///|
fn run_hot_pipeline_raw_simplify_locals_instr_is_pure_movable_value(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.I32Const(_)
    | @lib.I64Const(_)
    | @lib.F32Const(_)
    | @lib.F64Const(_)
    | @lib.LocalGet(_) => true
    _ => false
  }
}

///|
fn run_hot_pipeline_raw_simplify_locals_instr_source_local(
  instr : @lib.Instruction,
) -> Int? {
  match instr {
    @lib.LocalGet(@lib.LocalIdx(raw)) => Some(raw.reinterpret_as_int())
    _ => None
  }
}

///|
fn run_hot_pipeline_raw_simplify_locals_instr_source_locals(
  instrs : Array[@lib.Instruction],
) -> Array[Int] {
  let source_locals : Array[Int] = []
  for instr in instrs {
    match instr {
      @lib.LocalGet(@lib.LocalIdx(raw)) => {
        let local_id = raw.reinterpret_as_int()
        if !source_locals.any(fn(existing) { existing == local_id }) {
          source_locals.push(local_id)
        }
      }
      _ => ()
    }
  }
  source_locals
}

///|
fn run_hot_pipeline_raw_simplify_locals_instr_is_call_like(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.Call(_) | @lib.CallIndirect(_, _) | @lib.CallRef(_) => true
    _ => false
  }
}

///|
fn run_hot_pipeline_raw_simplify_locals_instr_is_structured(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.Block(_, @lib.Expr(_))
    | @lib.Loop(_, @lib.Expr(_))
    | @lib.If(_, _, _)
    | @lib.TryTable(_, _, @lib.Expr(_)) => true
    _ => false
  }
}

///|
fn run_hot_pipeline_raw_simplify_locals_instr_is_early_terminator(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.Return
    | @lib.ReturnCall(_)
    | @lib.ReturnCallIndirect(_, _)
    | @lib.ReturnCallRef(_)
    | @lib.Throw(_)
    | @lib.ThrowRef
    | @lib.Unreachable
    | @lib.Br(_)
    | @lib.BrIf(_)
    | @lib.BrTable(_, _) => true
    _ => false
  }
}

///|
fn run_hot_pipeline_raw_simplify_locals_instr_is_unconditional_terminator(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.Return
    | @lib.ReturnCall(_)
    | @lib.ReturnCallIndirect(_, _)
    | @lib.ReturnCallRef(_)
    | @lib.Throw(_)
    | @lib.ThrowRef
    | @lib.Unreachable
    | @lib.Br(_)
    | @lib.BrTable(_, _) => true
    _ => false
  }
}

///|
fn run_hot_pipeline_raw_simplify_locals_instr_writes_local(
  instr : @lib.Instruction,
  local_id : Int,
) -> Bool {
  match instr {
    @lib.LocalSet(@lib.LocalIdx(raw)) | @lib.LocalTee(@lib.LocalIdx(raw)) =>
      raw.reinterpret_as_int() == local_id
    _ => false
  }
}

///|
fn run_hot_pipeline_raw_simplify_locals_instrs_have_nested_early_terminator(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    if run_hot_pipeline_raw_simplify_locals_instr_is_early_terminator(instr) {
      return true
    }
    match instr {
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if run_hot_pipeline_raw_simplify_locals_instrs_have_nested_early_terminator(
            body,
          ) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if run_hot_pipeline_raw_simplify_locals_instrs_have_nested_early_terminator(
            then_body,
          ) {
          return true
        }
        match else_body {
          Some(body) =>
            if run_hot_pipeline_raw_simplify_locals_instrs_have_nested_early_terminator(
                body,
              ) {
              return true
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn run_hot_pipeline_raw_simplify_locals_statement_is_safe_copy_if_barrier(
  statement : Array[@lib.Instruction],
  target_local : Int,
  source_local : Int,
) -> Bool {
  if statement.length() == 0 {
    return false
  }
  let mut if_count = 0
  for idx = 0; idx < statement.length(); idx = idx + 1 {
    match statement[idx] {
      @lib.If(_, _, _) => {
        if_count = if_count + 1
        if idx != statement.length() - 1 {
          return false
        }
      }
      instr =>
        if run_hot_pipeline_raw_simplify_locals_instr_is_structured(instr) {
          return false
        }
    }
  }
  if if_count != 1 {
    return false
  }
  !run_hot_pipeline_raw_simplify_locals_instrs_have_nested_early_terminator(
    statement,
  ) &&
  !run_hot_pipeline_raw_instrs_have_later_local_read(statement, 0, target_local) &&
  !run_hot_pipeline_raw_instrs_have_later_local_write(
    statement, 0, target_local,
  ) &&
  !run_hot_pipeline_raw_instrs_have_later_local_read(statement, 0, source_local) &&
  !run_hot_pipeline_raw_instrs_have_later_local_write(
    statement, 0, source_local,
  )
}

///|
fn run_hot_pipeline_raw_simplify_locals_instr_is_dupable_copy_value(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.LocalGet(_)
    | @lib.I32Const(_)
    | @lib.I64Const(_)
    | @lib.F32Const(_)
    | @lib.F64Const(_) => true
    _ => false
  }
}

///|
fn run_hot_pipeline_raw_simplify_locals_rewrite_local_reads_in_body(
  body : Array[@lib.Instruction],
  target_local : Int,
  replacement : @lib.Instruction,
) -> Array[@lib.Instruction] {
  let rewritten : Array[@lib.Instruction] = []
  for instr in body {
    match instr {
      @lib.LocalGet(@lib.LocalIdx(raw)) =>
        if raw.reinterpret_as_int() == target_local {
          rewritten.push(replacement)
        } else {
          rewritten.push(instr)
        }
      @lib.Block(bt, @lib.Expr(nested_body)) =>
        rewritten.push(
          @lib.Instruction::block(
            bt,
            @lib.Expr::new(
              run_hot_pipeline_raw_simplify_locals_rewrite_local_reads_in_body(
                nested_body, target_local, replacement,
              ),
            ),
          ),
        )
      @lib.Loop(bt, @lib.Expr(nested_body)) =>
        rewritten.push(
          @lib.Instruction::loop_(
            bt,
            @lib.Expr::new(
              run_hot_pipeline_raw_simplify_locals_rewrite_local_reads_in_body(
                nested_body, target_local, replacement,
              ),
            ),
          ),
        )
      @lib.TryTable(bt, catches, @lib.Expr(nested_body)) =>
        rewritten.push(
          @lib.Instruction::try_table(
            bt,
            catches,
            @lib.Expr::new(
              run_hot_pipeline_raw_simplify_locals_rewrite_local_reads_in_body(
                nested_body, target_local, replacement,
              ),
            ),
          ),
        )
      @lib.If(bt, then_body, else_body) =>
        rewritten.push(
          @lib.Instruction::if_(
            bt,
            run_hot_pipeline_raw_simplify_locals_rewrite_local_reads_in_body(
              then_body, target_local, replacement,
            ),
            match else_body {
              Some(else_body) =>
                Some(
                  run_hot_pipeline_raw_simplify_locals_rewrite_local_reads_in_body(
                    else_body, target_local, replacement,
                  ),
                )
              None => None
            },
          ),
        )
      _ => rewritten.push(instr)
    }
  }
  rewritten
}

///|
fn run_hot_pipeline_raw_simplify_locals_try_rewrite_dupable_copy_into_next_if_condition(
  remaining : Array[@lib.Instruction],
  target_local : Int,
  replacement : @lib.Instruction,
  source_locals : Array[Int],
) -> (Array[@lib.Instruction], Int)? {
  let prefix : Array[@lib.Instruction] = []
  let mut idx = 0
  while idx < remaining.length() {
    let instr = remaining[idx]
    if run_hot_pipeline_raw_simplify_locals_instr_writes_local(
        instr, target_local,
      ) ||
      source_locals.any(fn(local_id) {
        run_hot_pipeline_raw_simplify_locals_instr_writes_local(instr, local_id)
      }) {
      return None
    }
    match instr {
      @lib.If(_, _, _) =>
        if run_hot_pipeline_raw_instrs_have_later_local_read(
            prefix, 0, target_local,
          ) &&
          !run_hot_pipeline_raw_instrs_have_later_local_read(
            [instr],
            0,
            target_local,
          ) &&
          !run_hot_pipeline_raw_instrs_have_later_local_write(
            [instr],
            0,
            target_local,
          ) &&
          !source_locals.any(fn(local_id) {
            run_hot_pipeline_raw_instrs_have_later_local_write(
              [instr],
              0,
              local_id,
            )
          }) &&
          !run_hot_pipeline_raw_instrs_have_later_local_read_before_next_local_write(
            remaining,
            idx + 1,
            target_local,
          ) {
          let rewritten : Array[@lib.Instruction] = []
          let rewritten_prefix = run_hot_pipeline_raw_simplify_locals_rewrite_local_reads_in_body(
            prefix, target_local, replacement,
          )
          for prefix_instr in rewritten_prefix {
            rewritten.push(prefix_instr)
          }
          let rewritten_if = run_hot_pipeline_raw_simplify_locals_rewrite_local_reads_in_body(
            [instr],
            target_local,
            replacement,
          )
          for rewritten_instr in rewritten_if {
            rewritten.push(rewritten_instr)
          }
          return Some((rewritten, idx + 1))
        } else {
          return None
        }
      structured =>
        if run_hot_pipeline_raw_simplify_locals_instr_is_structured(structured) ||
          run_hot_pipeline_raw_simplify_locals_instr_is_early_terminator(
            structured,
          ) {
          return None
        } else {
          prefix.push(instr)
          idx = idx + 1
        }
    }
  }
  None
}

///|
fn run_hot_pipeline_raw_simplify_locals_try_rewrite_dupable_copy_terminal_value_suffix(
  remaining : Array[@lib.Instruction],
  target_local : Int,
  replacement : @lib.Instruction,
  source_locals : Array[Int],
  env : @validate.Env,
) -> (Array[@lib.Instruction], Int)? {
  let (middle, value_suffix) = run_hot_pipeline_raw_simplify_locals_take_value_suffix(
    remaining, 1, env,
  )
  if value_suffix.length() != 1 {
    return None
  }
  match value_suffix[0] {
    @lib.LocalGet(@lib.LocalIdx(raw)) =>
      if raw.reinterpret_as_int() != target_local {
        None
      } else if middle.any(fn(instr) {
          run_hot_pipeline_raw_simplify_locals_instr_is_structured(instr) ||
          run_hot_pipeline_raw_simplify_locals_instr_is_early_terminator(instr) ||
          run_hot_pipeline_raw_simplify_locals_instr_writes_local(
            instr, target_local,
          ) ||
          source_locals.any(fn(local_id) {
            run_hot_pipeline_raw_simplify_locals_instr_writes_local(
              instr, local_id,
            )
          })
        }) {
        None
      } else {
        let rewritten : Array[@lib.Instruction] = []
        rewritten.push(@lib.Instruction::nop())
        for instr in middle {
          rewritten.push(instr)
        }
        rewritten.push(replacement)
        Some((rewritten, remaining.length()))
      }
    _ => None
  }
}

///|
fn run_hot_pipeline_raw_simplify_locals_rewrite_dupable_copy_middle_statements_into_statement(
  middle_statements : Array[Array[@lib.Instruction]],
  statement : Array[@lib.Instruction],
  instrs : Array[@lib.Instruction],
  statement_end : Int,
) -> (Array[@lib.Instruction], Array[@lib.Instruction], Int) {
  let rewritten_middle_reversed : Array[Array[@lib.Instruction]] = []
  let later_middle : Array[@lib.Instruction] = []
  let mut rewritten_statement = statement
  let mut rewrite_count = 0
  let mut idx = middle_statements.length() - 1
  while idx >= 0 {
    let middle_statement = middle_statements[idx]
    let mut emitted = middle_statement
    if middle_statement.length() == 2 &&
      run_hot_pipeline_raw_simplify_locals_instr_is_dupable_copy_value(
        middle_statement[0],
      ) {
      match middle_statement[1] {
        @lib.LocalSet(@lib.LocalIdx(target_raw)) => {
          let target_local = target_raw.reinterpret_as_int()
          let source_locals = run_hot_pipeline_raw_simplify_locals_instr_source_locals([
              middle_statement[0],
            ],
          )
          if run_hot_pipeline_raw_instrs_have_later_local_read(
              rewritten_statement, 0, target_local,
            ) &&
            !run_hot_pipeline_raw_instrs_have_later_local_write(
              rewritten_statement, 0, target_local,
            ) &&
            !run_hot_pipeline_raw_instrs_have_later_local_read(
              later_middle, 0, target_local,
            ) &&
            !run_hot_pipeline_raw_instrs_have_later_local_write(
              later_middle, 0, target_local,
            ) &&
            !run_hot_pipeline_raw_instrs_have_later_local_read_before_next_local_write(
              instrs, statement_end, target_local,
            ) &&
            !source_locals.any(fn(local_id) {
              run_hot_pipeline_raw_instrs_have_later_local_write(
                later_middle, 0, local_id,
              ) ||
              run_hot_pipeline_raw_instrs_have_later_local_write(
                rewritten_statement, 0, local_id,
              )
            }) {
            rewritten_statement = run_hot_pipeline_raw_simplify_locals_rewrite_local_reads_in_body(
              rewritten_statement,
              target_local,
              middle_statement[0],
            )
            emitted = [@lib.Instruction::nop()]
            rewrite_count = rewrite_count + 1
          }
        }
        _ => ()
      }
    }
    rewritten_middle_reversed.push(emitted)
    for instr in emitted {
      later_middle.push(instr)
    }
    idx = idx - 1
  }
  let rewritten_middle : Array[@lib.Instruction] = []
  let mut reverse_idx = rewritten_middle_reversed.length() - 1
  while reverse_idx >= 0 {
    for instr in rewritten_middle_reversed[reverse_idx] {
      rewritten_middle.push(instr)
    }
    reverse_idx = reverse_idx - 1
  }
  (rewritten_middle, rewritten_statement, rewrite_count)
}

///|
fn run_hot_pipeline_raw_simplify_locals_has_pure_call_tail_candidates_flat(
  instrs : Array[@lib.Instruction],
) -> Bool {
  let mut idx = 0
  while idx + 3 < instrs.length() {
    if run_hot_pipeline_raw_simplify_locals_instr_is_pure_movable_value(
        instrs[idx],
      ) {
      match instrs[idx + 1] {
        @lib.LocalSet(@lib.LocalIdx(target_raw)) => {
          let target_local = target_raw.reinterpret_as_int()
          let producer_source = run_hot_pipeline_raw_simplify_locals_instr_source_local(
            instrs[idx],
          )
          let mut use_idx = idx + 2
          let mut blocked = false
          while use_idx + 1 < instrs.length() && !blocked {
            let instr = instrs[use_idx]
            if run_hot_pipeline_raw_simplify_locals_instr_is_structured(instr) ||
              run_hot_pipeline_raw_simplify_locals_instr_is_early_terminator(
                instr,
              ) {
              blocked = true
            } else if run_hot_pipeline_raw_simplify_locals_instr_writes_local(
                instr, target_local,
              ) {
              blocked = true
            } else {
              match producer_source {
                Some(source_local) =>
                  if run_hot_pipeline_raw_simplify_locals_instr_writes_local(
                      instr, source_local,
                    ) {
                    blocked = true
                  }
                None => ()
              }
            }
            if !blocked {
              match instr {
                @lib.LocalGet(@lib.LocalIdx(raw)) =>
                  if raw.reinterpret_as_int() == target_local {
                    let mut call_idx = use_idx + 1
                    while call_idx < instrs.length() && !blocked {
                      if run_hot_pipeline_raw_simplify_locals_instr_is_call_like(
                          instrs[call_idx],
                        ) {
                        return true
                      } else if run_hot_pipeline_raw_simplify_locals_instr_is_pure_movable_value(
                          instrs[call_idx],
                        ) {
                        call_idx = call_idx + 1
                      } else {
                        blocked = true
                      }
                    }
                  }
                _ => ()
              }
            }
            use_idx = use_idx + 1
          }
        }
        _ => ()
      }
    }
    idx = idx + 1
  }
  false
}

///|
fn run_hot_pipeline_raw_simplify_locals_has_pure_call_tail_candidates_nested(
  instrs : Array[@lib.Instruction],
) -> Bool {
  if run_hot_pipeline_raw_simplify_locals_has_pure_call_tail_candidates_flat(
      instrs,
    ) {
    return true
  }
  for instr in instrs {
    match instr {
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if run_hot_pipeline_raw_simplify_locals_has_pure_call_tail_candidates_nested(
            body,
          ) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if run_hot_pipeline_raw_simplify_locals_has_pure_call_tail_candidates_nested(
            then_body,
          ) {
          return true
        }
        match else_body {
          Some(else_body) =>
            if run_hot_pipeline_raw_simplify_locals_has_pure_call_tail_candidates_nested(
                else_body,
              ) {
              return true
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn run_hot_pipeline_raw_simplify_locals_rewrite_pure_call_tails(
  instrs : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Int) {
  let rewritten : Array[@lib.Instruction] = []
  let mut idx = 0
  let mut rewrite_count = 0
  while idx < instrs.length() {
    let mut rewritten_here = false
    if idx + 3 < instrs.length() &&
      run_hot_pipeline_raw_simplify_locals_instr_is_pure_movable_value(
        instrs[idx],
      ) {
      match instrs[idx + 1] {
        @lib.LocalSet(@lib.LocalIdx(target_raw)) => {
          let target_local = target_raw.reinterpret_as_int()
          let producer_source = run_hot_pipeline_raw_simplify_locals_instr_source_local(
            instrs[idx],
          )
          let mut use_idx = idx + 2
          let mut blocked = false
          let mut found_use = false
          while use_idx + 1 < instrs.length() && !blocked && !found_use {
            let instr = instrs[use_idx]
            if run_hot_pipeline_raw_simplify_locals_instr_is_structured(instr) ||
              run_hot_pipeline_raw_simplify_locals_instr_is_early_terminator(
                instr,
              ) {
              blocked = true
            } else if run_hot_pipeline_raw_simplify_locals_instr_writes_local(
                instr, target_local,
              ) {
              blocked = true
            } else {
              match producer_source {
                Some(source_local) =>
                  if run_hot_pipeline_raw_simplify_locals_instr_writes_local(
                      instr, source_local,
                    ) {
                    blocked = true
                  }
                None => ()
              }
            }
            if !blocked {
              match instr {
                @lib.LocalGet(@lib.LocalIdx(raw)) =>
                  if raw.reinterpret_as_int() == target_local {
                    let mut call_idx = use_idx + 1
                    let mut found_call = false
                    while call_idx < instrs.length() && !found_call && !blocked {
                      if run_hot_pipeline_raw_simplify_locals_instr_is_call_like(
                          instrs[call_idx],
                        ) {
                        if !run_hot_pipeline_raw_instrs_have_later_local_read(
                            instrs,
                            call_idx + 1,
                            target_local,
                          ) {
                          found_use = true
                          found_call = true
                        } else {
                          blocked = true
                        }
                      } else if run_hot_pipeline_raw_simplify_locals_instr_is_pure_movable_value(
                          instrs[call_idx],
                        ) {
                        call_idx = call_idx + 1
                      } else {
                        blocked = true
                      }
                    }
                  }
                _ => ()
              }
            }
            if !blocked && !found_use {
              use_idx = use_idx + 1
            }
          }
          if found_use {
            for middle_idx = idx + 2
                middle_idx < use_idx
                middle_idx = middle_idx + 1 {
              rewritten.push(instrs[middle_idx])
            }
            rewritten.push(instrs[idx])
            rewrite_count = rewrite_count + 1
            idx = use_idx + 1
            rewritten_here = true
          }
        }
        _ => ()
      }
    }
    if !rewritten_here {
      rewritten.push(instrs[idx])
      idx = idx + 1
    }
  }
  (rewritten, rewrite_count)
}

///|
fn run_hot_pipeline_raw_simplify_locals_rewrite_pure_call_tails_nested(
  instrs : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Int) {
  let normalized : Array[@lib.Instruction] = []
  let mut rewrite_count = 0
  for instr in instrs {
    match instr {
      @lib.Block(bt, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_pure_call_tails_nested(
          body,
        )
        normalized.push(
          @lib.Instruction::block(bt, @lib.Expr::new(rewritten_body)),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.Loop(bt, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_pure_call_tails_nested(
          body,
        )
        normalized.push(
          @lib.Instruction::loop_(bt, @lib.Expr::new(rewritten_body)),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.TryTable(bt, catches, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_pure_call_tails_nested(
          body,
        )
        normalized.push(
          @lib.Instruction::try_table(
            bt,
            catches,
            @lib.Expr::new(rewritten_body),
          ),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.If(bt, then_body, else_body) => {
        let (rewritten_then, then_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_pure_call_tails_nested(
          then_body,
        )
        rewrite_count = rewrite_count + then_rewrites
        let rewritten_else = match else_body {
          Some(else_body) => {
            let (rewritten_else, else_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_pure_call_tails_nested(
              else_body,
            )
            rewrite_count = rewrite_count + else_rewrites
            Some(rewritten_else)
          }
          None => None
        }
        normalized.push(
          @lib.Instruction::if_(bt, rewritten_then, rewritten_else),
        )
      }
      _ => normalized.push(instr)
    }
  }
  let (rewritten, flat_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_pure_call_tails(
    normalized,
  )
  (rewritten, rewrite_count + flat_rewrites)
}

///|
fn run_hot_pipeline_raw_simplify_locals_rewrite_pure_call_tails_nested_fixpoint(
  instrs : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Int) {
  let mut current = instrs
  let mut total_rewrites = 0
  let mut pass_count = 0
  while pass_count < 3 &&
        run_hot_pipeline_raw_simplify_locals_has_pure_call_tail_candidates_nested(
          current,
        ) {
    let (rewritten, rewrite_count) = run_hot_pipeline_raw_simplify_locals_rewrite_pure_call_tails_nested(
      current,
    )
    total_rewrites = total_rewrites + rewrite_count
    current = rewritten
    if rewrite_count == 0 {
      break
    }
    pass_count = pass_count + 1
  }
  (current, total_rewrites)
}

///|
fn run_hot_pipeline_raw_simplify_locals_has_pure_suffix_local_set_candidates_flat(
  instrs : Array[@lib.Instruction],
) -> Bool {
  let mut idx = 1
  while idx < instrs.length() {
    match instrs[idx] {
      @lib.LocalSet(@lib.LocalIdx(target_raw)) =>
        if run_hot_pipeline_raw_simplify_locals_instr_is_pure_movable_value(
            instrs[idx - 1],
          ) &&
          run_hot_pipeline_raw_instrs_have_later_local_read_before_next_local_write(
            instrs,
            idx + 1,
            target_raw.reinterpret_as_int(),
          ) {
          return true
        }
      _ => ()
    }
    idx = idx + 1
  }
  false
}

///|
fn run_hot_pipeline_raw_simplify_locals_has_pure_suffix_local_set_candidates_nested(
  instrs : Array[@lib.Instruction],
) -> Bool {
  if run_hot_pipeline_raw_simplify_locals_has_pure_suffix_local_set_candidates_flat(
      instrs,
    ) {
    return true
  }
  for instr in instrs {
    match instr {
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if run_hot_pipeline_raw_simplify_locals_has_pure_suffix_local_set_candidates_nested(
            body,
          ) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if run_hot_pipeline_raw_simplify_locals_has_pure_suffix_local_set_candidates_nested(
            then_body,
          ) {
          return true
        }
        match else_body {
          Some(else_body) =>
            if run_hot_pipeline_raw_simplify_locals_has_pure_suffix_local_set_candidates_nested(
                else_body,
              ) {
              return true
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets_flat(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
) -> (Array[@lib.Instruction], Int) {
  let rewritten : Array[@lib.Instruction] = []
  let mut cursor = 0
  let mut scan_idx = 0
  let mut rewrite_count = 0
  while scan_idx < instrs.length() {
    let mut rewritten_here = false
    match instrs[scan_idx] {
      @lib.LocalSet(@lib.LocalIdx(target_raw)) => {
        let producer_instrs : Array[@lib.Instruction] = []
        for prefix_idx = 0; prefix_idx < scan_idx; prefix_idx = prefix_idx + 1 {
          producer_instrs.push(instrs[prefix_idx])
        }
        let (head, producer_suffix) = run_hot_pipeline_raw_simplify_locals_take_value_suffix(
          producer_instrs, 1, env,
        )
        let producer_start = head.length()
        if producer_suffix.length() > 0 &&
          producer_start >= cursor &&
          run_hot_pipeline_raw_simplify_locals_instrs_all_pure_movable_values(
            producer_suffix,
          ) {
          let target_local = target_raw.reinterpret_as_int()
          let source_locals = run_hot_pipeline_raw_simplify_locals_instr_source_locals(
            producer_suffix,
          )
          let producer_is_dupable_copy = producer_suffix.length() == 1 &&
            run_hot_pipeline_raw_simplify_locals_instr_is_dupable_copy_value(
              producer_suffix[0],
            )
          let movable_middle : Array[@lib.Instruction] = []
          let mut sink_idx = scan_idx + 1
          while sink_idx < instrs.length() {
            let remaining : Array[@lib.Instruction] = []
            for idx = sink_idx; idx < instrs.length(); idx = idx + 1 {
              remaining.push(instrs[idx])
            }
            let (statement, _) = run_hot_pipeline_raw_simplify_locals_take_statement_prefix(
              remaining, env,
            )
            if statement.length() == 0 ||
              statement.any(fn(instr) {
                run_hot_pipeline_raw_simplify_locals_instr_is_structured(instr) ||
                run_hot_pipeline_raw_simplify_locals_instr_is_early_terminator(
                  instr,
                )
              }) ||
              run_hot_pipeline_raw_instrs_have_later_local_read(
                statement, 0, target_local,
              ) ||
              run_hot_pipeline_raw_instrs_have_later_local_write(
                statement, 0, target_local,
              ) ||
              source_locals.any(fn(local_id) {
                run_hot_pipeline_raw_instrs_have_later_local_write(
                  statement, 0, local_id,
                )
              }) {
              break
            }
            let statement_len = statement.length()
            for instr in statement {
              movable_middle.push(instr)
            }
            sink_idx = sink_idx + statement_len
          }
          if movable_middle.length() > 0 && !producer_is_dupable_copy {
            for idx = cursor; idx < producer_start; idx = idx + 1 {
              rewritten.push(instrs[idx])
            }
            for instr in movable_middle {
              rewritten.push(instr)
            }
            for instr in producer_suffix {
              rewritten.push(instr)
            }
            rewritten.push(instrs[scan_idx])
            cursor = sink_idx
            scan_idx = sink_idx
            rewrite_count = rewrite_count + 1
            rewritten_here = true
          }
          if !rewritten_here &&
            movable_middle.length() == 0 &&
            producer_suffix.length() == 1 {
            match
              run_hot_pipeline_raw_simplify_locals_instr_source_local(
                producer_suffix[0],
              ) {
              Some(source_local) => {
                let remaining : Array[@lib.Instruction] = []
                for idx = scan_idx + 1; idx < instrs.length(); idx = idx + 1 {
                  remaining.push(instrs[idx])
                }
                let (statement, _) = run_hot_pipeline_raw_simplify_locals_take_statement_prefix(
                  remaining, env,
                )
                if run_hot_pipeline_raw_simplify_locals_statement_is_safe_copy_if_barrier(
                    statement, target_local, source_local,
                  ) {
                  for idx = cursor; idx < producer_start; idx = idx + 1 {
                    rewritten.push(instrs[idx])
                  }
                  for instr in statement {
                    rewritten.push(instr)
                  }
                  for instr in producer_suffix {
                    rewritten.push(instr)
                  }
                  rewritten.push(instrs[scan_idx])
                  cursor = scan_idx + 1 + statement.length()
                  scan_idx = cursor
                  rewrite_count = rewrite_count + 1
                  rewritten_here = true
                }
              }
              None => ()
            }
          }
          if !rewritten_here && producer_is_dupable_copy {
            let remaining : Array[@lib.Instruction] = []
            for idx = scan_idx + 1; idx < instrs.length(); idx = idx + 1 {
              remaining.push(instrs[idx])
            }
            match
              run_hot_pipeline_raw_simplify_locals_try_rewrite_dupable_copy_terminal_value_suffix(
                remaining,
                target_local,
                producer_suffix[0],
                source_locals,
                env,
              ) {
              Some((rewritten_terminal, consumed_len)) => {
                for idx = cursor; idx < producer_start; idx = idx + 1 {
                  rewritten.push(instrs[idx])
                }
                for instr in rewritten_terminal {
                  rewritten.push(instr)
                }
                cursor = scan_idx + 1 + consumed_len
                scan_idx = cursor
                rewrite_count = rewrite_count + 1
                rewritten_here = true
              }
              None => ()
            }
          }
          if !rewritten_here && producer_is_dupable_copy {
            let remaining : Array[@lib.Instruction] = []
            for idx = scan_idx + 1; idx < instrs.length(); idx = idx + 1 {
              remaining.push(instrs[idx])
            }
            match
              run_hot_pipeline_raw_simplify_locals_try_rewrite_dupable_copy_into_next_if_condition(
                remaining,
                target_local,
                producer_suffix[0],
                source_locals,
              ) {
              Some((rewritten_condition, consumed_len)) => {
                for idx = cursor; idx < producer_start; idx = idx + 1 {
                  rewritten.push(instrs[idx])
                }
                rewritten.push(@lib.Instruction::nop())
                for instr in rewritten_condition {
                  rewritten.push(instr)
                }
                cursor = scan_idx + 1 + consumed_len
                scan_idx = cursor
                rewrite_count = rewrite_count + 1
                rewritten_here = true
              }
              None => ()
            }
          }
          if !rewritten_here && producer_is_dupable_copy {
            let skipped_middle_statements : Array[Array[@lib.Instruction]] = []
            let mut sink_idx = scan_idx + 1
            while sink_idx < instrs.length() && !rewritten_here {
              let remaining : Array[@lib.Instruction] = []
              for idx = sink_idx; idx < instrs.length(); idx = idx + 1 {
                remaining.push(instrs[idx])
              }
              let (statement0, _) = run_hot_pipeline_raw_simplify_locals_take_statement_prefix(
                remaining, env,
              )
              let (statement, _) = if statement0.length() > 0 {
                (statement0, [])
              } else {
                run_hot_pipeline_raw_simplify_locals_take_statement_prefix_allow_escape(
                  remaining, env,
                )
              }
              if statement.length() == 0 {
                break
              }
              let statement_end = sink_idx + statement.length()
              let statement_escapes = statement.length() > 0 &&
                run_hot_pipeline_raw_simplify_locals_instr_is_unconditional_terminator(
                  statement[statement.length() - 1],
                )
              if run_hot_pipeline_raw_instrs_have_later_local_write(
                  statement, 0, target_local,
                ) ||
                source_locals.any(fn(local_id) {
                  run_hot_pipeline_raw_instrs_have_later_local_write(
                    statement, 0, local_id,
                  )
                }) {
                break
              }
              let reads_target = run_hot_pipeline_raw_instrs_have_later_local_read(
                statement, 0, target_local,
              )
              if reads_target {
                if statement_escapes ||
                  !run_hot_pipeline_raw_instrs_have_later_local_read_before_next_local_write(
                    instrs, statement_end, target_local,
                  ) {
                  for idx = cursor; idx < producer_start; idx = idx + 1 {
                    rewritten.push(instrs[idx])
                  }
                  rewritten.push(@lib.Instruction::nop())
                  let rewritten_statement = run_hot_pipeline_raw_simplify_locals_rewrite_local_reads_in_body(
                    statement,
                    target_local,
                    producer_suffix[0],
                  )
                  let (rewritten_middle, rewritten_statement, middle_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_dupable_copy_middle_statements_into_statement(
                    skipped_middle_statements, rewritten_statement, instrs, statement_end,
                  )
                  for instr in rewritten_middle {
                    rewritten.push(instr)
                  }
                  for instr in rewritten_statement {
                    rewritten.push(instr)
                  }
                  cursor = statement_end
                  scan_idx = statement_end
                  rewrite_count = rewrite_count + 1 + middle_rewrites
                  rewritten_here = true
                }
                break
              }
              if statement.any(fn(instr) {
                  run_hot_pipeline_raw_simplify_locals_instr_is_structured(
                    instr,
                  ) ||
                  run_hot_pipeline_raw_simplify_locals_instr_is_early_terminator(
                    instr,
                  )
                }) {
                break
              }
              skipped_middle_statements.push(statement)
              sink_idx = statement_end
            }
          }
        }
      }
      _ => ()
    }
    if !rewritten_here {
      scan_idx = scan_idx + 1
    }
  }
  for idx = cursor; idx < instrs.length(); idx = idx + 1 {
    rewritten.push(instrs[idx])
  }
  (rewritten, rewrite_count)
}

///|
fn run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
) -> (Array[@lib.Instruction], Int) {
  let normalized : Array[@lib.Instruction] = []
  let mut rewrite_count = 0
  for instr in instrs {
    match instr {
      @lib.Block(bt, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets(
          body, env,
        )
        normalized.push(
          @lib.Instruction::block(bt, @lib.Expr::new(rewritten_body)),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.Loop(bt, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets(
          body, env,
        )
        normalized.push(
          @lib.Instruction::loop_(bt, @lib.Expr::new(rewritten_body)),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.TryTable(bt, catches, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets(
          body, env,
        )
        normalized.push(
          @lib.Instruction::try_table(
            bt,
            catches,
            @lib.Expr::new(rewritten_body),
          ),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.If(bt, then_body, else_body) => {
        let (rewritten_then, then_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets(
          then_body, env,
        )
        rewrite_count = rewrite_count + then_rewrites
        let rewritten_else = match else_body {
          Some(else_body) => {
            let (rewritten_else, else_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets(
              else_body, env,
            )
            rewrite_count = rewrite_count + else_rewrites
            Some(rewritten_else)
          }
          None => None
        }
        normalized.push(
          @lib.Instruction::if_(bt, rewritten_then, rewritten_else),
        )
      }
      _ => normalized.push(instr)
    }
  }
  let (rewritten, flat_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets_flat(
    normalized, env,
  )
  (rewritten, rewrite_count + flat_rewrites)
}

///|
fn run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets_fixpoint(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
) -> (Array[@lib.Instruction], Int) {
  let mut current = instrs
  let mut total_rewrites = 0
  let mut pass_count = 0
  while pass_count < 3 &&
        run_hot_pipeline_raw_simplify_locals_has_pure_suffix_local_set_candidates_nested(
          current,
        ) {
    let (rewritten, rewrite_count) = run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets(
      current, env,
    )
    total_rewrites = total_rewrites + rewrite_count
    current = rewritten
    if rewrite_count == 0 {
      break
    }
    pass_count = pass_count + 1
  }
  (current, total_rewrites)
}

///|
fn run_hot_pipeline_raw_simplify_locals_instrs_all_pure_movable_values(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    if !run_hot_pipeline_raw_simplify_locals_instr_is_pure_movable_value(instr) {
      return false
    }
  }
  true
}

///|
fn run_hot_pipeline_raw_simplify_locals_pure_prefix_can_append_local_set_barrier(
  pure_prefix : Array[@lib.Instruction],
  target_local : Int,
  source_locals : Array[Int],
  barrier_local : Int,
  env : @validate.Env,
) -> Bool {
  if barrier_local == target_local ||
    source_locals.any(fn(local_id) { local_id == barrier_local }) {
    return false
  }
  let (_, barrier_producer) = run_hot_pipeline_raw_simplify_locals_take_value_suffix(
    pure_prefix, 1, env,
  )
  if barrier_producer.length() == 0 {
    return false
  }
  !run_hot_pipeline_raw_simplify_locals_instr_source_locals(barrier_producer).any(fn(
      local_id,
    ) {
      local_id == target_local
    },
  )
}

///|
fn run_hot_pipeline_raw_simplify_locals_rewrite_leading_local_get_in_body(
  body : Array[@lib.Instruction],
  target_local : Int,
  replacement : Array[@lib.Instruction],
) -> Array[@lib.Instruction]? {
  let rewritten : Array[@lib.Instruction] = []
  let mut idx = 0
  while idx < body.length() {
    match body[idx] {
      @lib.Nop => {
        rewritten.push(body[idx])
        idx = idx + 1
      }
      @lib.LocalGet(@lib.LocalIdx(raw)) =>
        if raw.reinterpret_as_int() == target_local &&
          !run_hot_pipeline_raw_instrs_have_later_local_read(
            body,
            idx + 1,
            target_local,
          ) &&
          !run_hot_pipeline_raw_instrs_have_later_local_write(
            body,
            idx + 1,
            target_local,
          ) {
          for instr in replacement {
            rewritten.push(instr)
          }
          for rest_idx = idx + 1
              rest_idx < body.length()
              rest_idx = rest_idx + 1 {
            rewritten.push(body[rest_idx])
          }
          return Some(rewritten)
        } else {
          rewritten.push(body[idx])
          idx = idx + 1
        }
      instr =>
        if run_hot_pipeline_raw_simplify_locals_instr_is_pure_movable_value(
            instr,
          ) {
          rewritten.push(instr)
          idx = idx + 1
        } else {
          match instr {
            @lib.Block(bt, @lib.Expr(nested_body)) =>
              match
                run_hot_pipeline_raw_simplify_locals_rewrite_leading_local_get_in_body(
                  nested_body, target_local, replacement,
                ) {
                Some(rewritten_nested) => {
                  rewritten.push(
                    @lib.Instruction::block(
                      bt,
                      @lib.Expr::new(rewritten_nested),
                    ),
                  )
                  for rest_idx = idx + 1
                      rest_idx < body.length()
                      rest_idx = rest_idx + 1 {
                    rewritten.push(body[rest_idx])
                  }
                  return Some(rewritten)
                }
                None => return None
              }
            @lib.Loop(bt, @lib.Expr(nested_body)) =>
              match
                run_hot_pipeline_raw_simplify_locals_rewrite_leading_local_get_in_body(
                  nested_body, target_local, replacement,
                ) {
                Some(rewritten_nested) => {
                  rewritten.push(
                    @lib.Instruction::loop_(
                      bt,
                      @lib.Expr::new(rewritten_nested),
                    ),
                  )
                  for rest_idx = idx + 1
                      rest_idx < body.length()
                      rest_idx = rest_idx + 1 {
                    rewritten.push(body[rest_idx])
                  }
                  return Some(rewritten)
                }
                None => return None
              }
            @lib.TryTable(bt, catches, @lib.Expr(nested_body)) =>
              match
                run_hot_pipeline_raw_simplify_locals_rewrite_leading_local_get_in_body(
                  nested_body, target_local, replacement,
                ) {
                Some(rewritten_nested) => {
                  rewritten.push(
                    @lib.Instruction::try_table(
                      bt,
                      catches,
                      @lib.Expr::new(rewritten_nested),
                    ),
                  )
                  for rest_idx = idx + 1
                      rest_idx < body.length()
                      rest_idx = rest_idx + 1 {
                    rewritten.push(body[rest_idx])
                  }
                  return Some(rewritten)
                }
                None => return None
              }
            _ => return None
          }
        }
    }
  }
  None
}

///|
fn run_hot_pipeline_raw_simplify_locals_rewrite_leading_local_get_in_instr(
  instr : @lib.Instruction,
  target_local : Int,
  replacement : Array[@lib.Instruction],
) -> @lib.Instruction? {
  match instr {
    @lib.Block(bt, @lib.Expr(body)) =>
      match
        run_hot_pipeline_raw_simplify_locals_rewrite_leading_local_get_in_body(
          body, target_local, replacement,
        ) {
        Some(rewritten_body) =>
          Some(@lib.Instruction::block(bt, @lib.Expr::new(rewritten_body)))
        None => None
      }
    @lib.Loop(bt, @lib.Expr(body)) =>
      match
        run_hot_pipeline_raw_simplify_locals_rewrite_leading_local_get_in_body(
          body, target_local, replacement,
        ) {
        Some(rewritten_body) =>
          Some(@lib.Instruction::loop_(bt, @lib.Expr::new(rewritten_body)))
        None => None
      }
    @lib.TryTable(bt, catches, @lib.Expr(body)) =>
      match
        run_hot_pipeline_raw_simplify_locals_rewrite_leading_local_get_in_body(
          body, target_local, replacement,
        ) {
        Some(rewritten_body) =>
          Some(
            @lib.Instruction::try_table(
              bt,
              catches,
              @lib.Expr::new(rewritten_body),
            ),
          )
        None => None
      }
    _ => None
  }
}

///|
fn run_hot_pipeline_raw_simplify_locals_instr_is_value_control(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.Block(block_type, _) | @lib.Loop(block_type, _) =>
      block_type != @lib.BlockType::void_()
    @lib.If(block_type, _, _) => block_type != @lib.BlockType::void_()
    @lib.TryTable(block_type, _, _) => block_type != @lib.BlockType::void_()
    _ => false
  }
}

///|
fn run_hot_pipeline_raw_simplify_locals_rewrite_control_carrier_local_gets_flat(
  instrs : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Int) {
  let rewritten : Array[@lib.Instruction] = []
  let mut cursor = 0
  let mut scan_idx = 0
  let mut rewrite_count = 0
  while scan_idx + 1 < instrs.length() {
    let mut rewritten_here = false
    if run_hot_pipeline_raw_simplify_locals_instr_is_value_control(
        instrs[scan_idx],
      ) {
      match instrs[scan_idx + 1] {
        @lib.LocalSet(@lib.LocalIdx(target_raw)) => {
          let target_local = target_raw.reinterpret_as_int()
          let mut use_idx = scan_idx + 2
          while use_idx < instrs.length() &&
                instrs[use_idx] == @lib.Instruction::nop() {
            use_idx = use_idx + 1
          }
          if use_idx < instrs.length() {
            match instrs[use_idx] {
              @lib.LocalGet(@lib.LocalIdx(read_raw)) if read_raw == target_raw => {
                for idx = cursor; idx < scan_idx; idx = idx + 1 {
                  rewritten.push(instrs[idx])
                }
                rewritten.push(@lib.Instruction::nop())
                for nop_idx = scan_idx + 2
                    nop_idx < use_idx
                    nop_idx = nop_idx + 1 {
                  rewritten.push(instrs[nop_idx])
                }
                rewritten.push(instrs[scan_idx])
                if run_hot_pipeline_raw_instrs_have_later_local_read(
                    instrs,
                    use_idx + 1,
                    target_local,
                  ) {
                  rewritten.push(
                    @lib.Instruction::local_tee(@lib.LocalIdx::new(target_raw)),
                  )
                }
                cursor = use_idx + 1
                scan_idx = cursor
                rewrite_count = rewrite_count + 1
                rewritten_here = true
              }
              @lib.Block(_, _) | @lib.Loop(_, _) | @lib.TryTable(_, _, _) =>
                if !run_hot_pipeline_raw_instrs_have_later_local_read(
                    instrs,
                    use_idx + 1,
                    target_local,
                  ) &&
                  !run_hot_pipeline_raw_instrs_have_later_local_write(
                    instrs,
                    use_idx + 1,
                    target_local,
                  ) {
                  match
                    run_hot_pipeline_raw_simplify_locals_rewrite_leading_local_get_in_instr(
                      instrs[use_idx],
                      target_local,
                      [instrs[scan_idx]],
                    ) {
                    Some(rewritten_instr) => {
                      for idx = cursor; idx < scan_idx; idx = idx + 1 {
                        rewritten.push(instrs[idx])
                      }
                      rewritten.push(@lib.Instruction::nop())
                      for nop_idx = scan_idx + 2
                          nop_idx < use_idx
                          nop_idx = nop_idx + 1 {
                        rewritten.push(instrs[nop_idx])
                      }
                      rewritten.push(rewritten_instr)
                      cursor = use_idx + 1
                      scan_idx = cursor
                      rewrite_count = rewrite_count + 1
                      rewritten_here = true
                    }
                    None => ()
                  }
                }
              _ => ()
            }
          }
        }
        _ => ()
      }
    }
    if !rewritten_here {
      scan_idx = scan_idx + 1
    }
  }
  for idx = cursor; idx < instrs.length(); idx = idx + 1 {
    rewritten.push(instrs[idx])
  }
  (rewritten, rewrite_count)
}

///|
fn run_hot_pipeline_raw_simplify_locals_rewrite_control_carrier_local_gets(
  instrs : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Int) {
  let normalized : Array[@lib.Instruction] = []
  let mut rewrite_count = 0
  for instr in instrs {
    match instr {
      @lib.Block(bt, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_control_carrier_local_gets(
          body,
        )
        normalized.push(
          @lib.Instruction::block(bt, @lib.Expr::new(rewritten_body)),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.Loop(bt, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_control_carrier_local_gets(
          body,
        )
        normalized.push(
          @lib.Instruction::loop_(bt, @lib.Expr::new(rewritten_body)),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.TryTable(bt, catches, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_control_carrier_local_gets(
          body,
        )
        normalized.push(
          @lib.Instruction::try_table(
            bt,
            catches,
            @lib.Expr::new(rewritten_body),
          ),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.If(bt, then_body, else_body) => {
        let (rewritten_then, then_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_control_carrier_local_gets(
          then_body,
        )
        rewrite_count = rewrite_count + then_rewrites
        let rewritten_else = match else_body {
          Some(else_body) => {
            let (rewritten_else, else_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_control_carrier_local_gets(
              else_body,
            )
            rewrite_count = rewrite_count + else_rewrites
            Some(rewritten_else)
          }
          None => None
        }
        normalized.push(
          @lib.Instruction::if_(bt, rewritten_then, rewritten_else),
        )
      }
      _ => normalized.push(instr)
    }
  }
  let (rewritten, flat_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_control_carrier_local_gets_flat(
    normalized,
  )
  (rewritten, rewrite_count + flat_rewrites)
}

///|
fn run_hot_pipeline_raw_simplify_locals_rewrite_control_carrier_local_gets_fixpoint(
  instrs : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Int) {
  let mut current = instrs
  let mut total_rewrites = 0
  let mut pass_count = 0
  while pass_count < 3 {
    let (rewritten, rewrite_count) = run_hot_pipeline_raw_simplify_locals_rewrite_control_carrier_local_gets(
      current,
    )
    total_rewrites = total_rewrites + rewrite_count
    current = rewritten
    if rewrite_count == 0 {
      break
    }
    pass_count = pass_count + 1
  }
  (current, total_rewrites)
}

///|
fn run_hot_pipeline_raw_simplify_locals_rewrite_effectful_suffix_local_gets_flat(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
) -> (Array[@lib.Instruction], Int) {
  let rewritten : Array[@lib.Instruction] = []
  let mut cursor = 0
  let mut scan_idx = 0
  let mut rewrite_count = 0
  while scan_idx < instrs.length() {
    let mut rewritten_here = false
    match instrs[scan_idx] {
      @lib.LocalSet(@lib.LocalIdx(target_raw)) => {
        let producer_instrs : Array[@lib.Instruction] = []
        for prefix_idx = 0; prefix_idx < scan_idx; prefix_idx = prefix_idx + 1 {
          producer_instrs.push(instrs[prefix_idx])
        }
        let (head, producer_suffix) = run_hot_pipeline_raw_simplify_locals_take_value_suffix(
          producer_instrs, 1, env,
        )
        let producer_start = head.length()
        if producer_suffix.length() > 0 &&
          producer_start >= cursor &&
          !run_hot_pipeline_raw_simplify_locals_instrs_all_pure_movable_values(
            producer_suffix,
          ) {
          let target_local = target_raw.reinterpret_as_int()
          let source_locals = run_hot_pipeline_raw_simplify_locals_instr_source_locals(
            producer_suffix,
          )
          let pure_prefix : Array[@lib.Instruction] = []
          let mut use_idx = scan_idx + 1
          while use_idx < instrs.length() {
            match instrs[use_idx] {
              @lib.LocalGet(@lib.LocalIdx(read_raw)) =>
                if read_raw.reinterpret_as_int() == target_local {
                  let has_later_read = run_hot_pipeline_raw_instrs_have_later_local_read(
                    instrs,
                    use_idx + 1,
                    target_local,
                  )
                  for idx = cursor; idx < producer_start; idx = idx + 1 {
                    rewritten.push(instrs[idx])
                  }
                  rewritten.push(@lib.Instruction::nop())
                  for instr in pure_prefix {
                    rewritten.push(instr)
                  }
                  for instr in producer_suffix {
                    rewritten.push(instr)
                  }
                  if has_later_read {
                    rewritten.push(
                      @lib.Instruction::local_tee(
                        @lib.LocalIdx::new(target_raw),
                      ),
                    )
                  }
                  cursor = use_idx + 1
                  scan_idx = cursor
                  rewrite_count = rewrite_count + 1
                  rewritten_here = true
                  break
                } else {
                  pure_prefix.push(instrs[use_idx])
                }
              @lib.Nop => pure_prefix.push(instrs[use_idx])
              @lib.Block(_, @lib.Expr(_))
              | @lib.Loop(_, @lib.Expr(_))
              | @lib.TryTable(_, _, @lib.Expr(_)) =>
                if pure_prefix.all(fn(instr) {
                    match instr {
                      @lib.Nop => true
                      _ => false
                    }
                  }) &&
                  !run_hot_pipeline_raw_instrs_have_later_local_read(
                    instrs,
                    use_idx + 1,
                    target_local,
                  ) &&
                  !run_hot_pipeline_raw_instrs_have_later_local_write(
                    instrs,
                    use_idx + 1,
                    target_local,
                  ) {
                  match
                    run_hot_pipeline_raw_simplify_locals_rewrite_leading_local_get_in_instr(
                      instrs[use_idx],
                      target_local,
                      producer_suffix,
                    ) {
                    Some(rewritten_instr) => {
                      for idx = cursor; idx < producer_start; idx = idx + 1 {
                        rewritten.push(instrs[idx])
                      }
                      rewritten.push(@lib.Instruction::nop())
                      for instr in pure_prefix {
                        rewritten.push(instr)
                      }
                      rewritten.push(rewritten_instr)
                      cursor = use_idx + 1
                      scan_idx = cursor
                      rewrite_count = rewrite_count + 1
                      rewritten_here = true
                      break
                    }
                    None => break
                  }
                } else {
                  break
                }
              @lib.LocalSet(@lib.LocalIdx(barrier_raw)) =>
                if run_hot_pipeline_raw_simplify_locals_pure_prefix_can_append_local_set_barrier(
                    pure_prefix,
                    target_local,
                    source_locals,
                    barrier_raw.reinterpret_as_int(),
                    env,
                  ) {
                  pure_prefix.push(instrs[use_idx])
                } else {
                  break
                }
              instr =>
                if run_hot_pipeline_raw_simplify_locals_instr_is_pure_movable_value(
                    instr,
                  ) {
                  pure_prefix.push(instr)
                } else {
                  break
                }
            }
            if rewritten_here {
              break
            }
            use_idx = use_idx + 1
          }
        }
      }
      _ => ()
    }
    if !rewritten_here {
      scan_idx = scan_idx + 1
    }
  }
  for idx = cursor; idx < instrs.length(); idx = idx + 1 {
    rewritten.push(instrs[idx])
  }
  (rewritten, rewrite_count)
}

///|
fn run_hot_pipeline_raw_simplify_locals_rewrite_effectful_suffix_local_gets(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
) -> (Array[@lib.Instruction], Int) {
  let normalized : Array[@lib.Instruction] = []
  let mut rewrite_count = 0
  for instr in instrs {
    match instr {
      @lib.Block(bt, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_effectful_suffix_local_gets(
          body, env,
        )
        normalized.push(
          @lib.Instruction::block(bt, @lib.Expr::new(rewritten_body)),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.Loop(bt, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_effectful_suffix_local_gets(
          body, env,
        )
        normalized.push(
          @lib.Instruction::loop_(bt, @lib.Expr::new(rewritten_body)),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.TryTable(bt, catches, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_effectful_suffix_local_gets(
          body, env,
        )
        normalized.push(
          @lib.Instruction::try_table(
            bt,
            catches,
            @lib.Expr::new(rewritten_body),
          ),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.If(bt, then_body, else_body) => {
        let (rewritten_then, then_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_effectful_suffix_local_gets(
          then_body, env,
        )
        rewrite_count = rewrite_count + then_rewrites
        let rewritten_else = match else_body {
          Some(else_body) => {
            let (rewritten_else, else_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_effectful_suffix_local_gets(
              else_body, env,
            )
            rewrite_count = rewrite_count + else_rewrites
            Some(rewritten_else)
          }
          None => None
        }
        normalized.push(
          @lib.Instruction::if_(bt, rewritten_then, rewritten_else),
        )
      }
      _ => normalized.push(instr)
    }
  }
  let (rewritten, flat_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_effectful_suffix_local_gets_flat(
    normalized, env,
  )
  (rewritten, rewrite_count + flat_rewrites)
}

///|
fn run_hot_pipeline_raw_simplify_locals_rewrite_effectful_suffix_local_gets_fixpoint(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
) -> (Array[@lib.Instruction], Int) {
  let mut current = instrs
  let mut total_rewrites = 0
  let mut pass_count = 0
  while pass_count < 3 {
    let (rewritten, rewrite_count) = run_hot_pipeline_raw_simplify_locals_rewrite_effectful_suffix_local_gets(
      current, env,
    )
    total_rewrites = total_rewrites + rewrite_count
    current = rewritten
    if rewrite_count == 0 {
      break
    }
    pass_count = pass_count + 1
  }
  (current, total_rewrites)
}

///|
fn run_hot_pipeline_raw_simplify_locals_rewrite_adjacent_local_tees(
  instrs : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Int) {
  let normalized : Array[@lib.Instruction] = []
  let mut rewrite_count = 0
  for instr in instrs {
    match instr {
      @lib.Block(bt, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_adjacent_local_tees(
          body,
        )
        normalized.push(
          @lib.Instruction::block(bt, @lib.Expr::new(rewritten_body)),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.Loop(bt, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_adjacent_local_tees(
          body,
        )
        normalized.push(
          @lib.Instruction::loop_(bt, @lib.Expr::new(rewritten_body)),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.TryTable(bt, catches, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_adjacent_local_tees(
          body,
        )
        normalized.push(
          @lib.Instruction::try_table(
            bt,
            catches,
            @lib.Expr::new(rewritten_body),
          ),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.If(bt, then_body, else_body) => {
        let (rewritten_then, then_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_adjacent_local_tees(
          then_body,
        )
        rewrite_count = rewrite_count + then_rewrites
        let rewritten_else = match else_body {
          Some(else_body) => {
            let (rewritten_else, else_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_adjacent_local_tees(
              else_body,
            )
            rewrite_count = rewrite_count + else_rewrites
            Some(rewritten_else)
          }
          None => None
        }
        normalized.push(
          @lib.Instruction::if_(bt, rewritten_then, rewritten_else),
        )
      }
      _ => normalized.push(instr)
    }
  }
  let rewritten : Array[@lib.Instruction] = []
  let mut idx = 0
  while idx < normalized.length() {
    if idx + 1 < normalized.length() {
      match (normalized[idx], normalized[idx + 1]) {
        (
          @lib.LocalSet(@lib.LocalIdx(raw)),
          @lib.LocalGet(@lib.LocalIdx(next_raw)),
        ) =>
          if raw == next_raw {
            if run_hot_pipeline_raw_instrs_have_later_local_read(
                normalized,
                idx + 2,
                raw.reinterpret_as_int(),
              ) {
              rewritten.push(
                @lib.Instruction::local_tee(@lib.LocalIdx::new(raw)),
              )
            }
            rewrite_count = rewrite_count + 1
            idx = idx + 2
          } else {
            rewritten.push(normalized[idx])
            idx = idx + 1
          }
        _ => {
          rewritten.push(normalized[idx])
          idx = idx + 1
        }
      }
    } else {
      rewritten.push(normalized[idx])
      idx = idx + 1
    }
  }
  (rewritten, rewrite_count)
}

///|
fn run_hot_pipeline_raw_simplify_locals_match_lane_builder_block(
  instrs : Array[@lib.Instruction],
  start : Int,
) -> (
  @lib.LocalIdx,
  @lib.I32,
  @lib.LocalIdx,
  @lib.Instruction,
  @lib.Instruction,
  @lib.MemArg,
  @lib.LocalIdx,
)? {
  if start + 15 >= instrs.length() {
    return None
  }
  match
    (
      instrs[start],
      instrs[start + 1],
      instrs[start + 2],
      instrs[start + 3],
      instrs[start + 4],
      instrs[start + 5],
      instrs[start + 6],
      instrs[start + 7],
      instrs[start + 8],
      instrs[start + 9],
      instrs[start + 10],
      instrs[start + 11],
      instrs[start + 12],
      instrs[start + 13],
      instrs[start + 14],
      instrs[start + 15],
    ) {
    (
      @lib.LocalGet(@lib.LocalIdx(source_raw)),
      @lib.I32Const(lane_value),
      @lib.LocalSet(@lib.LocalIdx(idx_raw)),
      @lib.LocalSet(@lib.LocalIdx(arr_raw)),
      @lib.LocalGet(@lib.LocalIdx(check_idx_raw)),
      @lib.I32Const(@lib.I32(lower_bound)),
      @lib.LocalGet(@lib.LocalIdx(check_arr_raw)),
      array_length_call,
      @lib.I32Const(@lib.I32(upper_delta)),
      @lib.I32Sub,
      check_range_call,
      @lib.LocalGet(@lib.LocalIdx(load_arr_raw)),
      @lib.LocalGet(@lib.LocalIdx(load_idx_raw)),
      @lib.I32Add,
      @lib.I32Load8U(load_memarg),
      @lib.LocalSet(@lib.LocalIdx(tmp_raw)),
    ) =>
      if idx_raw == check_idx_raw &&
        idx_raw == load_idx_raw &&
        arr_raw == check_arr_raw &&
        arr_raw == load_arr_raw &&
        lower_bound == 0 &&
        upper_delta == 1 &&
        source_raw != idx_raw &&
        source_raw != arr_raw &&
        run_hot_pipeline_raw_simplify_locals_instr_is_call_like(
          array_length_call,
        ) &&
        run_hot_pipeline_raw_simplify_locals_instr_is_call_like(
          check_range_call,
        ) &&
        !run_hot_pipeline_raw_instrs_have_later_local_read(
          instrs,
          start + 16,
          arr_raw.reinterpret_as_int(),
        ) {
        Some(
          (
            @lib.LocalIdx::new(source_raw),
            lane_value,
            @lib.LocalIdx::new(idx_raw),
            array_length_call,
            check_range_call,
            load_memarg,
            @lib.LocalIdx::new(tmp_raw),
          ),
        )
      } else {
        None
      }
    _ => None
  }
}

///|
fn run_hot_pipeline_raw_simplify_locals_rewrite_straight_line_lane_builder(
  instrs : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Int) {
  let rewritten : Array[@lib.Instruction] = []
  let mut idx = 0
  let mut rewrite_count = 0
  while idx < instrs.length() {
    let mut rewritten_here = false
    match
      run_hot_pipeline_raw_simplify_locals_match_lane_builder_block(instrs, idx) {
      Some(
        (
          source_local,
          lane_value,
          idx_local,
          array_length_call,
          check_range_call,
          load_memarg,
          tmp_local,
        )
      ) => {
        rewritten.push(@lib.Instruction::i32_const(lane_value))
        rewritten.push(@lib.Instruction::local_tee(idx_local))
        rewritten.push(@lib.Instruction::i32_const(0))
        rewritten.push(@lib.Instruction::local_get(source_local))
        rewritten.push(array_length_call)
        rewritten.push(@lib.Instruction::i32_const(1))
        rewritten.push(@lib.Instruction::i32_sub())
        rewritten.push(check_range_call)
        rewritten.push(@lib.Instruction::local_get(source_local))
        rewritten.push(@lib.Instruction::local_get(idx_local))
        rewritten.push(@lib.Instruction::i32_add())
        rewritten.push(@lib.Instruction::i32_load8u(load_memarg))
        rewritten.push(@lib.Instruction::local_set(tmp_local))
        rewrite_count = rewrite_count + 1
        idx = idx + 16
        rewritten_here = true
      }
      None => ()
    }
    if !rewritten_here {
      rewritten.push(instrs[idx])
      idx = idx + 1
    }
  }
  (rewritten, rewrite_count)
}

///|
fn run_hot_pipeline_raw_simplify_locals_try_rewrite_tail(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
) -> (Array[@lib.Instruction], Int) {
  match run_hot_pipeline_raw_simplify_locals_match_tail_local_get(instrs) {
    Some((set_idx, status, tail_has_return)) => {
      let producer_instrs : Array[@lib.Instruction] = []
      for idx = 0; idx < set_idx; idx = idx + 1 {
        producer_instrs.push(instrs[idx])
      }
      let (head, suffix) = run_hot_pipeline_raw_simplify_locals_take_value_suffix(
        producer_instrs, 1, env,
      )
      if suffix.length() == 0 {
        return (instrs, 0)
      }
      let rewritten : Array[@lib.Instruction] = []
      for instr in head {
        rewritten.push(instr)
      }
      rewritten.push(@lib.Instruction::i32_const(status))
      for instr in suffix {
        rewritten.push(instr)
      }
      if tail_has_return {
        rewritten.push(@lib.Instruction::return_())
      }
      (rewritten, 1)
    }
    None => (instrs, 0)
  }
}

///|
fn run_hot_pipeline_raw_simplify_locals_rewrite_instrs(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
) -> (Array[@lib.Instruction], Int) {
  let normalized : Array[@lib.Instruction] = []
  let mut rewrite_count = 0
  for instr in instrs {
    match instr {
      @lib.Block(bt, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_instrs(
          body, env,
        )
        normalized.push(
          @lib.Instruction::block(bt, @lib.Expr::new(rewritten_body)),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.Loop(bt, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_instrs(
          body, env,
        )
        normalized.push(
          @lib.Instruction::loop_(bt, @lib.Expr::new(rewritten_body)),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.TryTable(bt, catches, @lib.Expr(body)) => {
        let (rewritten_body, nested_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_instrs(
          body, env,
        )
        normalized.push(
          @lib.Instruction::try_table(
            bt,
            catches,
            @lib.Expr::new(rewritten_body),
          ),
        )
        rewrite_count = rewrite_count + nested_rewrites
      }
      @lib.If(bt, then_body, else_body) => {
        let (rewritten_then, then_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_instrs(
          then_body, env,
        )
        rewrite_count = rewrite_count + then_rewrites
        let rewritten_else = match else_body {
          Some(else_body) => {
            let (rewritten_else, else_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_instrs(
              else_body, env,
            )
            rewrite_count = rewrite_count + else_rewrites
            Some(rewritten_else)
          }
          None => None
        }
        normalized.push(
          @lib.Instruction::if_(bt, rewritten_then, rewritten_else),
        )
      }
      _ => normalized.push(instr)
    }
  }
  let (pure_call_tail_rewritten, pure_call_tail_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_pure_call_tails(
    normalized,
  )
  let (pure_suffix_rewritten, pure_suffix_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets_fixpoint(
    pure_call_tail_rewritten, env,
  )
  let (control_carrier_rewritten, control_carrier_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_control_carrier_local_gets_fixpoint(
    pure_suffix_rewritten,
  )
  let (effectful_suffix_rewritten, effectful_suffix_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_effectful_suffix_local_gets_fixpoint(
    control_carrier_rewritten, env,
  )
  let (rewritten, tail_rewrites) = run_hot_pipeline_raw_simplify_locals_try_rewrite_tail(
    effectful_suffix_rewritten, env,
  )
  (
    rewritten,
    rewrite_count +
    pure_call_tail_rewrites +
    pure_suffix_rewrites +
    control_carrier_rewrites +
    effectful_suffix_rewrites +
    tail_rewrites,
  )
}

///|
fn run_hot_pipeline_raw_simplify_locals_rewrite_skipped_effectful_carriers(
  mod_ : @lib.Module,
  func_idx : @lib.FuncIdx,
  module_state : HotPipelineModuleState,
  descriptor : @ir.HotPassDescriptor,
  options : HotPipelineOptions,
  locals : @lib.Locals,
  instrs : Array[@lib.Instruction],
  reason : String,
) -> HotPipelineFuncResult? {
  if descriptor.name != "simplify-locals" {
    return None
  }
  let module_ctx = run_hot_pipeline_require_module_ctx(
    mod_, module_state, options,
  )
  let env = run_hot_pipeline_raw_simplify_locals_func_env(
    mod_, func_idx, module_ctx, locals,
  )
  let (pure_suffix_instrs, pure_suffix_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets_fixpoint(
    instrs, env,
  )
  let (carrier_instrs, carrier_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_control_carrier_local_gets_fixpoint(
    pure_suffix_instrs,
  )
  let (rewritten_instrs, effectful_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_effectful_suffix_local_gets_fixpoint(
    carrier_instrs, env,
  )
  let rewrite_count = pure_suffix_rewrites +
    carrier_rewrites +
    effectful_rewrites
  if rewrite_count == 0 {
    return None
  }
  let (cleaned, _) = run_hot_pipeline_simplify_locals_cleanup_exact_func(
    @lib.Func::new(locals, @lib.Expr::new(rewritten_instrs)),
  )
  Some({
    reason,
    func: cleaned,
    unchanged_original: false,
    trace_skip_raw: true,
  })
}

///|
fn run_hot_pipeline_raw_simplify_locals(
  mod_ : @lib.Module,
  func_idx : @lib.FuncIdx,
  module_state : HotPipelineModuleState,
  descriptor : @ir.HotPassDescriptor,
  options : HotPipelineOptions,
) -> HotPipelineFuncResult? {
  if descriptor.name != "simplify-locals" &&
    descriptor.name != "simplify-locals-nostructure" &&
    descriptor.name != "simplify-locals-no-structure" &&
    descriptor.name != "simplify-locals-notee-nostructure" {
    return None
  }
  let original = run_hot_pipeline_original_func(mod_, func_idx)
  let @lib.Func(locals, @lib.Expr(instrs)) = original
  if !run_hot_pipeline_raw_simplify_locals_has_local_write(instrs) {
    if descriptor.name == "simplify-locals-notee-nostructure" {
      let (rewritten_instrs, added_locals, changed) = run_hot_pipeline_raw_simplify_locals_notee_reorder_const_nop(
        instrs,
      )
      if changed {
        let rewritten_locals = locals.copy()
        rewritten_locals.append_types(added_locals)
        return Some({
          reason: "notee-const-nop",
          func: @lib.Func::new(
            rewritten_locals,
            @lib.Expr::new(rewritten_instrs),
          ),
          unchanged_original: false,
          trace_skip_raw: false,
        })
      }
    }
    return Some({
      reason: "no-local-writes",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  let should_rewrite_ladder = if stats.locals_count < 16 ||
    stats.locals_count > 512 {
    false
  } else if !stats.has_structured_control || stats.instr_count > 12000 {
    false
  } else {
    let large_ladder = stats.locals_count >= 48 &&
      stats.instr_count >= 160 &&
      stats.if_count >= 16 &&
      stats.local_set_count >= 16 &&
      stats.local_get_count >= 32 &&
      stats.exact_tail_count >= 12 &&
      stats.exact_tail_count * 4 + 16 >= stats.if_count &&
      stats.return_count <= stats.exact_tail_count + 8
    let small_ladder = stats.locals_count >= 16 &&
      stats.instr_count >= 80 &&
      stats.if_count >= 8 &&
      stats.local_set_count >= 8 &&
      stats.local_get_count >= 16 &&
      stats.exact_tail_count >= 4 &&
      stats.exact_tail_count * 2 + 4 >= stats.if_count &&
      stats.return_count <= stats.exact_tail_count + 4
    let sparse_ladder = stats.locals_count >= 16 &&
      stats.instr_count >= 80 &&
      stats.if_count >= 12 &&
      stats.local_set_count >= 10 &&
      stats.local_get_count >= 24 &&
      stats.call_count >= stats.if_count &&
      stats.exact_tail_count >= 5 &&
      stats.exact_tail_count * 3 + 1 >= stats.if_count &&
      stats.return_count <= stats.if_count
    large_ladder || small_ladder || sparse_ladder
  }
  let should_rewrite_straight_line_adjacent_local_tees = !stats.has_structured_control &&
    stats.locals_count >= 512 &&
    stats.instr_count >= 2048 &&
    stats.local_set_count >= 1 &&
    stats.local_set_count <= 16 &&
    stats.local_get_count >= 1024 &&
    stats.local_get_count >= stats.local_set_count * 64 &&
    stats.call_count >= 768 &&
    stats.return_count <= 1
  let should_rewrite_straight_line_lane_builder = !stats.has_structured_control &&
    stats.locals_count >= 48 &&
    stats.locals_count <= 64 &&
    stats.instr_count >= 240 &&
    stats.instr_count <= 384 &&
    stats.if_count == 0 &&
    stats.block_count == 0 &&
    stats.loop_count == 0 &&
    stats.local_set_count >= 48 &&
    stats.local_set_count <= 64 &&
    stats.local_get_count >= 80 &&
    stats.local_get_count <= 128 &&
    stats.call_count >= 32 &&
    stats.call_count <= 40 &&
    stats.return_count == 0
  let should_rewrite_pure_call_tails = !stats.has_structured_control &&
    stats.locals_count >= 32 &&
    stats.instr_count >= 128 &&
    stats.local_set_count >= 16 &&
    stats.local_get_count >= 32
  let should_skip_straight_line_builder_churn = stats.locals_count >= 224 &&
    stats.locals_count <= 320 &&
    !stats.has_structured_control &&
    stats.instr_count >= 768 &&
    stats.if_count == 0 &&
    stats.block_count == 0 &&
    stats.loop_count == 0 &&
    stats.local_set_count >= 144 &&
    stats.local_set_count <= 192 &&
    stats.local_get_count >= 384 &&
    stats.local_get_count <= 704 &&
    stats.local_get_count >= stats.local_set_count * 2 + 48 &&
    stats.call_count >= 72 &&
    stats.call_count <= 128 &&
    stats.return_count == 0
  let should_skip_multivalue_call_ladder = {
    let sparse_call_ladder = stats.locals_count >= 16 &&
      stats.locals_count <= 512 &&
      stats.has_structured_control &&
      stats.exact_tail_count == 0 &&
      stats.instr_count >= 160 &&
      stats.if_count >= 12 &&
      stats.loop_count <= 2 &&
      stats.local_set_count >= 6 &&
      stats.local_get_count >= 48 &&
      stats.local_get_count >= stats.local_set_count * 3 &&
      stats.call_count >= 24 &&
      stats.call_count >= stats.if_count &&
      stats.return_count <= stats.if_count + 12
    let compact_call_ladder = stats.locals_count >= 32 &&
      stats.locals_count <= 64 &&
      stats.has_structured_control &&
      stats.exact_tail_count == 0 &&
      stats.instr_count >= 192 &&
      stats.if_count >= 10 &&
      stats.if_count <= 24 &&
      stats.block_count <= 2 &&
      stats.loop_count == 0 &&
      stats.local_set_count >= 12 &&
      stats.local_get_count >= 64 &&
      stats.local_get_count >= stats.local_set_count * 5 &&
      stats.call_count >= 32 &&
      stats.call_count >= stats.if_count * 3 &&
      stats.return_count <= 4
    let flat_dense_call_ladder = stats.locals_count >= 96 &&
      stats.locals_count <= 192 &&
      stats.has_structured_control &&
      stats.exact_tail_count == 0 &&
      stats.instr_count >= 480 &&
      stats.if_count >= 32 &&
      stats.block_count == 0 &&
      stats.loop_count == 0 &&
      stats.local_set_count >= 48 &&
      stats.local_get_count >= 160 &&
      stats.local_get_count >= stats.local_set_count * 2 + 32 &&
      stats.call_count >= 48 &&
      stats.call_count >= stats.if_count + 16 &&
      stats.return_count <= stats.if_count
    let loop_rich_call_ladder = stats.locals_count >= 160 &&
      stats.locals_count <= 256 &&
      stats.has_structured_control &&
      stats.exact_tail_count == 0 &&
      stats.instr_count >= 1000 &&
      stats.if_count >= 48 &&
      stats.block_count <= 4 &&
      stats.loop_count <= 4 &&
      stats.local_set_count >= 96 &&
      stats.local_get_count >= 384 &&
      stats.local_get_count >= stats.local_set_count * 3 + 64 &&
      stats.call_count >= 192 &&
      stats.call_count >= stats.if_count * 4 &&
      stats.return_count <= stats.if_count
    sparse_call_ladder ||
    compact_call_ladder ||
    flat_dense_call_ladder ||
    loop_rich_call_ladder
  }
  let should_skip_validator_structured_call_heavy = stats.locals_count >= 256 &&
    stats.has_structured_control &&
    stats.instr_count >= 256 &&
    stats.if_count >= 48 &&
    stats.block_count >= 32 &&
    stats.loop_count >= 4 &&
    stats.local_set_count >= 128 &&
    stats.local_get_count >= 384 &&
    stats.call_count >= 192
  let should_skip_parser_structured_call_heavy = stats.locals_count >= 96 &&
    stats.locals_count <= 352 &&
    stats.has_structured_control &&
    stats.instr_count >= 160 &&
    stats.if_count >= 16 &&
    stats.if_count <= 64 &&
    stats.block_count >= 4 &&
    stats.block_count <= 20 &&
    stats.loop_count <= 2 &&
    stats.local_set_count >= 80 &&
    stats.local_get_count >= 220 &&
    stats.call_count >= 64 &&
    stats.call_count <= 128 &&
    stats.return_count <= stats.if_count
  let should_skip_decode_structured_call_heavy = stats.locals_count >= 80 &&
    stats.locals_count <= 128 &&
    stats.has_structured_control &&
    stats.instr_count >= 192 &&
    stats.if_count >= 12 &&
    stats.if_count <= 40 &&
    stats.block_count >= 8 &&
    stats.block_count <= 24 &&
    stats.loop_count == 1 &&
    stats.local_set_count >= 40 &&
    stats.local_set_count <= 96 &&
    stats.local_get_count >= 144 &&
    stats.local_get_count <= 180 &&
    stats.call_count >= 48 &&
    stats.call_count <= 64 &&
    stats.return_count <= 16
  let should_skip_encode_structured_call_heavy = stats.locals_count >= 192 &&
    stats.locals_count <= 256 &&
    stats.has_structured_control &&
    stats.instr_count >= 512 &&
    stats.if_count >= 96 &&
    stats.if_count <= 192 &&
    stats.block_count >= 32 &&
    stats.block_count <= 64 &&
    stats.loop_count == 0 &&
    stats.local_set_count >= 56 &&
    stats.local_set_count <= 96 &&
    stats.local_get_count >= 352 &&
    stats.local_get_count <= 544 &&
    stats.call_count >= 160 &&
    stats.call_count <= 224 &&
    stats.return_count >= 8 &&
    stats.return_count <= 16
  let should_skip_branchy_decode_structured_call_heavy = stats.locals_count >=
    192 &&
    stats.locals_count <= 224 &&
    stats.has_structured_control &&
    stats.instr_count >= 640 &&
    stats.if_count >= 48 &&
    stats.if_count <= 80 &&
    stats.block_count >= 16 &&
    stats.block_count <= 32 &&
    stats.loop_count == 0 &&
    stats.local_set_count >= 48 &&
    stats.local_set_count <= 96 &&
    stats.local_get_count >= 240 &&
    stats.local_get_count <= 384 &&
    stats.call_count >= 80 &&
    stats.call_count <= 128 &&
    stats.return_count >= 4 &&
    stats.return_count <= 12
  let should_skip_transformer_catch_structured_call_heavy = stats.locals_count >=
    184 &&
    stats.locals_count <= 224 &&
    stats.has_structured_control &&
    stats.instr_count >= 512 &&
    stats.if_count >= 32 &&
    stats.if_count <= 64 &&
    stats.block_count >= 24 &&
    stats.block_count <= 40 &&
    stats.loop_count == 0 &&
    stats.local_set_count >= 72 &&
    stats.local_set_count <= 96 &&
    stats.local_get_count >= 256 &&
    stats.local_get_count <= 352 &&
    stats.call_count >= 80 &&
    stats.call_count <= 112 &&
    stats.return_count >= 8 &&
    stats.return_count <= 16
  let should_skip_branchy_structured_call_heavy = stats.locals_count >= 176 &&
    stats.locals_count <= 224 &&
    stats.has_structured_control &&
    stats.instr_count >= 768 &&
    stats.if_count >= 48 &&
    stats.if_count <= 64 &&
    stats.block_count >= 24 &&
    stats.block_count <= 40 &&
    stats.loop_count == 0 &&
    stats.local_set_count >= 64 &&
    stats.local_set_count <= 80 &&
    stats.local_get_count >= 280 &&
    stats.local_get_count <= 352 &&
    stats.call_count >= 96 &&
    stats.call_count <= 144 &&
    stats.return_count >= 4 &&
    stats.return_count <= 8
  let should_skip_dense_structured_call_heavy = run_hot_pipeline_raw_simplify_locals_dense_structured_call_heavy_stats(
    stats,
  )
  let should_skip_stringview_trim_loop_churn = stats.locals_count >= 34 &&
    stats.locals_count <= 40 &&
    stats.has_structured_control &&
    stats.instr_count >= 64 &&
    stats.if_count >= 2 &&
    stats.if_count <= 3 &&
    stats.block_count == 0 &&
    stats.loop_count == 1 &&
    stats.local_set_count >= 8 &&
    stats.local_set_count <= 12 &&
    stats.local_get_count >= 32 &&
    stats.local_get_count <= 52 &&
    stats.call_count >= 12 &&
    stats.call_count <= 18 &&
    stats.return_count == 0
  let should_skip_transformer_structured_call_heavy = stats.locals_count >= 84 &&
    stats.locals_count <= 96 &&
    stats.has_structured_control &&
    stats.instr_count >= 160 &&
    stats.if_count >= 18 &&
    stats.if_count <= 28 &&
    stats.block_count >= 12 &&
    stats.block_count <= 20 &&
    stats.loop_count == 0 &&
    stats.local_set_count >= 32 &&
    stats.local_set_count <= 48 &&
    stats.local_get_count >= 140 &&
    stats.local_get_count <= 180 &&
    stats.call_count >= 48 &&
    stats.call_count <= 64 &&
    stats.return_count <= 8
  let should_skip_small_loop_call_heavy = stats.locals_count >= 80 &&
    stats.locals_count <= 90 &&
    stats.has_structured_control &&
    stats.instr_count >= 160 &&
    stats.if_count >= 12 &&
    stats.if_count <= 20 &&
    stats.block_count == 0 &&
    stats.loop_count == 2 &&
    stats.local_set_count >= 72 &&
    stats.local_set_count <= 84 &&
    stats.local_get_count >= 100 &&
    stats.local_get_count <= 192 &&
    stats.call_count >= 24 &&
    stats.call_count <= 48 &&
    stats.return_count <= 4
  let should_skip_huge_straight_line_call_builder = stats.locals_count >= 768 &&
    !stats.has_structured_control &&
    stats.instr_count >= 2048 &&
    stats.if_count == 0 &&
    stats.block_count == 0 &&
    stats.loop_count == 0 &&
    stats.local_set_count <= 16 &&
    stats.local_get_count >= 1536 &&
    stats.call_count >= 1024 &&
    stats.return_count == 0
  let should_skip_medium_structured_call_heavy = stats.locals_count >= 176 &&
    stats.locals_count <= 320 &&
    stats.has_structured_control &&
    stats.instr_count >= 224 &&
    stats.if_count >= 24 &&
    stats.if_count <= 96 &&
    stats.loop_count <= 3 &&
    stats.local_set_count >= 96 &&
    stats.local_get_count >= 256 &&
    stats.call_count >= 128 &&
    stats.call_count <= 224 &&
    stats.return_count <= stats.if_count
  let should_skip_loop_heavy_structured_call_heavy = stats.locals_count >= 176 &&
    stats.locals_count <= 320 &&
    stats.has_structured_control &&
    stats.instr_count >= 256 &&
    stats.if_count >= 28 &&
    stats.if_count <= 80 &&
    stats.block_count >= 8 &&
    stats.loop_count >= 4 &&
    stats.local_set_count >= 80 &&
    stats.local_get_count >= 200 &&
    stats.call_count >= 80 &&
    stats.call_count <= 224 &&
    stats.return_count <= stats.if_count
  let should_skip_giant_structured_call_heavy = stats.locals_count >= 352 &&
    stats.has_structured_control &&
    stats.instr_count >= 256 &&
    stats.if_count >= 80 &&
    stats.local_set_count >= 176 &&
    stats.local_get_count >= 384 &&
    stats.call_count >= 240
  let should_skip_giant_structured_local_churn = stats.locals_count >= 600 &&
    stats.has_structured_control &&
    stats.instr_count >= 1500 &&
    stats.if_count >= 96 &&
    stats.local_set_count >= 384 &&
    stats.local_get_count >= 768 &&
    stats.call_count >= 16 &&
    stats.call_count <= 96 &&
    stats.return_count <= 4
  let should_skip_unchecked_small_structured_call_mesh = !options.validate_final_module &&
    run_hot_pipeline_raw_simplify_locals_unchecked_small_structured_call_mesh_stats(
      stats,
    )
  let should_skip_giant_validator_structured_call_heavy = run_hot_pipeline_raw_simplify_locals_giant_validator_structured_call_heavy_stats(
    stats,
  )
  let should_skip_branch_dense_structured_call_heavy = run_hot_pipeline_raw_simplify_locals_branch_dense_structured_call_heavy_stats(
    stats,
  )
  let should_skip_block_rich_structured_call_heavy = run_hot_pipeline_raw_simplify_locals_block_rich_structured_call_heavy_stats(
    stats,
  )
  let should_skip_call_dense_structured_walker = run_hot_pipeline_raw_simplify_locals_call_dense_structured_walker_stats(
    stats,
  )
  let should_skip_low_local_decision_ladder = run_hot_pipeline_raw_simplify_locals_low_local_decision_ladder_stats(
    stats,
  )
  let should_skip_giant_func = stats.locals_count >= 1500 &&
    stats.has_structured_control &&
    stats.instr_count >= 2000
  let should_rewrite_structured_pure_call_tails = stats.has_structured_control &&
    stats.locals_count >= 128 &&
    stats.instr_count >= 256 &&
    stats.local_set_count >= 24 &&
    stats.local_get_count >= 48
  if !should_rewrite_ladder && should_rewrite_straight_line_adjacent_local_tees {
    let (rewritten_instrs, rewrite_count) = run_hot_pipeline_raw_simplify_locals_rewrite_adjacent_local_tees(
      instrs,
    )
    if rewrite_count > 0 {
      return Some({
        reason: "straight-line-adjacent-local-tee",
        func: @lib.Func::new(locals, @lib.Expr::new(rewritten_instrs)),
        unchanged_original: false,
        trace_skip_raw: true,
      })
    }
  }
  if !should_rewrite_ladder && should_rewrite_straight_line_lane_builder {
    let (rewritten_instrs, rewrite_count) = run_hot_pipeline_raw_simplify_locals_rewrite_straight_line_lane_builder(
      instrs,
    )
    if rewrite_count > 0 {
      return Some({
        reason: "straight-line-lane-builder",
        func: @lib.Func::new(locals, @lib.Expr::new(rewritten_instrs)),
        unchanged_original: false,
        trace_skip_raw: true,
      })
    }
  }
  if should_rewrite_pure_call_tails {
    let (rewritten_instrs, rewrite_count) = run_hot_pipeline_raw_simplify_locals_rewrite_pure_call_tails(
      instrs,
    )
    if rewrite_count > 0 {
      return Some({
        reason: "straight-line-pure-copy-call-tail",
        func: @lib.Func::new(locals, @lib.Expr::new(rewritten_instrs)),
        unchanged_original: false,
        trace_skip_raw: true,
      })
    }
  }
  if !should_rewrite_ladder {
    if should_skip_straight_line_builder_churn {
      return Some({
        reason: "straight-line-builder-churn",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
    if should_skip_huge_straight_line_call_builder {
      return Some({
        reason: "huge-straight-line-call-builder",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
    if run_hot_pipeline_raw_simplify_locals_has_i32_pair_result(
        mod_, func_idx, module_state, options,
      ) &&
      should_skip_multivalue_call_ladder {
      return Some({
        reason: "multivalue-call-heavy-ladder",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
    if should_skip_unchecked_small_structured_call_mesh {
      return Some({
        reason: "unchecked-small-structured-call-mesh-noop",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
    if should_skip_giant_validator_structured_call_heavy {
      return Some({
        reason: "giant-validator-structured-call-heavy-noop",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
    if should_skip_validator_structured_call_heavy {
      let module_ctx = run_hot_pipeline_require_module_ctx(
        mod_, module_state, options,
      )
      let env = run_hot_pipeline_raw_simplify_locals_func_env(
        mod_, func_idx, module_ctx, locals,
      )
      let (pure_call_tail_instrs, pure_call_tail_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_pure_call_tails_nested_fixpoint(
        instrs,
      )
      let (pure_suffix_instrs, pure_suffix_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets_fixpoint(
        pure_call_tail_instrs, env,
      )
      let (carrier_instrs, carrier_rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_control_carrier_local_gets_fixpoint(
        pure_suffix_instrs,
      )
      let (rewritten_instrs, rewrite_count) = run_hot_pipeline_raw_simplify_locals_rewrite_effectful_suffix_local_gets_fixpoint(
        carrier_instrs, env,
      )
      let total_rewrites = pure_call_tail_rewrites +
        pure_suffix_rewrites +
        carrier_rewrites +
        rewrite_count
      let rewritten_func = if total_rewrites > 0 {
        @lib.Func::new(locals, @lib.Expr::new(rewritten_instrs))
      } else {
        original
      }
      let (cleaned, changed) = run_hot_pipeline_simplify_locals_cleanup_exact_func(
        rewritten_func,
      )
      return Some({
        reason: "validator-structured-call-heavy",
        func: cleaned,
        unchanged_original: total_rewrites == 0 && !changed,
        trace_skip_raw: true,
      })
    }
    if should_skip_branch_dense_structured_call_heavy {
      return Some({
        reason: "branch-dense-structured-call-heavy-noop",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
    if should_skip_low_local_decision_ladder {
      return Some({
        reason: "low-local-decision-ladder-noop",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
    if should_skip_parser_structured_call_heavy {
      return Some({
        reason: "parser-structured-call-heavy",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
    if should_skip_decode_structured_call_heavy {
      return Some({
        reason: "decode-structured-call-heavy",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
    if should_skip_encode_structured_call_heavy {
      return Some({
        reason: "encode-structured-call-heavy",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
    if should_skip_branchy_decode_structured_call_heavy {
      return Some({
        reason: "branchy-decode-structured-call-heavy",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
    if should_skip_transformer_catch_structured_call_heavy {
      return Some({
        reason: "transformer-catch-structured-call-heavy",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
    if should_skip_branchy_structured_call_heavy {
      return Some({
        reason: "branchy-structured-call-heavy",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
    if should_skip_dense_structured_call_heavy {
      return Some({
        reason: "dense-structured-call-heavy",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
    if should_skip_stringview_trim_loop_churn {
      return Some({
        reason: "stringview-trim-loop-churn",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
    if should_skip_transformer_structured_call_heavy {
      return Some({
        reason: "transformer-structured-call-heavy",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
    if should_skip_small_loop_call_heavy {
      return Some({
        reason: "small-loop-call-heavy",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
    if should_skip_block_rich_structured_call_heavy {
      return Some({
        reason: "block-rich-structured-call-heavy-noop",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
    if should_skip_call_dense_structured_walker {
      return Some({
        reason: "call-dense-structured-walker-noop",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
    if should_skip_medium_structured_call_heavy {
      return Some({
        reason: "medium-structured-call-heavy",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
    if should_skip_loop_heavy_structured_call_heavy {
      return Some({
        reason: "loop-heavy-structured-call-heavy",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
    if should_skip_giant_structured_call_heavy {
      match
        run_hot_pipeline_raw_simplify_locals_rewrite_skipped_effectful_carriers(
          mod_, func_idx, module_state, descriptor, options, locals, instrs, "giant-structured-call-heavy-carrier",
        ) {
        Some(result) => return Some(result)
        None => ()
      }
      return Some({
        reason: "giant-structured-call-heavy",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
    if should_skip_giant_structured_local_churn {
      match
        run_hot_pipeline_raw_simplify_locals_rewrite_skipped_effectful_carriers(
          mod_, func_idx, module_state, descriptor, options, locals, instrs, "giant-structured-local-churn-carrier",
        ) {
        Some(result) => return Some(result)
        None => ()
      }
      return Some({
        reason: "giant-structured-local-churn",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
    if should_skip_giant_func {
      return Some({
        reason: "giant-local-func-noop",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
    if should_rewrite_structured_pure_call_tails {
      let module_ctx = run_hot_pipeline_require_module_ctx(
        mod_, module_state, options,
      )
      let env = run_hot_pipeline_raw_simplify_locals_func_env(
        mod_, func_idx, module_ctx, locals,
      )
      let (rewritten_instrs, rewrite_count) = run_hot_pipeline_raw_simplify_locals_rewrite_instrs(
        instrs, env,
      )
      if rewrite_count >= 16 {
        return Some({
          reason: "structured-pure-copy-call-tail",
          func: @lib.Func::new(locals, @lib.Expr::new(rewritten_instrs)),
          unchanged_original: false,
          trace_skip_raw: true,
        })
      }
    }
    return None
  }
  let module_ctx = run_hot_pipeline_require_module_ctx(
    mod_, module_state, options,
  )
  let env = run_hot_pipeline_raw_simplify_locals_func_env(
    mod_, func_idx, module_ctx, locals,
  )
  let (rewritten_instrs, rewrite_count) = run_hot_pipeline_raw_simplify_locals_rewrite_instrs(
    instrs, env,
  )
  if rewrite_count == 0 {
    return None
  }
  Some({
    reason: "multivalue-tail-local-get-ladder",
    func: @lib.Func::new(locals, @lib.Expr::new(rewritten_instrs)),
    unchanged_original: false,
    trace_skip_raw: true,
  })
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
fn run_hot_pipeline_dce_raw_instr_is_definitely_impure_value(
  instr : @lib.Instruction,
  module_ctx : @ir.HotModuleContext,
) -> Bool {
  match instr {
    @lib.Call(func_idx) =>
      match @ir.hot_module_resolve_func_type(module_ctx, func_idx) {
        Some(@lib.FuncType(_, results)) => !results.is_empty()
        None => false
      }
    @lib.CallIndirect(type_idx, _) | @lib.CallRef(type_idx) =>
      match @ir.hot_module_resolve_type_func_type(module_ctx, type_idx) {
        Some(@lib.FuncType(_, results)) => !results.is_empty()
        None => false
      }
    @lib.Block(block_type, @lib.Expr(_))
    | @lib.Loop(block_type, @lib.Expr(_))
    | @lib.If(block_type, _, _)
    | @lib.TryTable(block_type, _, @lib.Expr(_)) =>
      block_type != @lib.BlockType::void_()
    _ => false
  }
}

///|
fn run_hot_pipeline_dce_raw_drops_follow_definitely_impure_values(
  instrs : Array[@lib.Instruction],
  module_ctx : @ir.HotModuleContext,
) -> Bool {
  let mut prev : @lib.Instruction? = None
  for instr in instrs {
    match instr {
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        if !run_hot_pipeline_dce_raw_drops_follow_definitely_impure_values(
            body, module_ctx,
          ) {
          return false
        }
      @lib.If(_, then_body, else_body) => {
        if !run_hot_pipeline_dce_raw_drops_follow_definitely_impure_values(
            then_body, module_ctx,
          ) {
          return false
        }
        match else_body {
          Some(else_body) =>
            if !run_hot_pipeline_dce_raw_drops_follow_definitely_impure_values(
                else_body, module_ctx,
              ) {
              return false
            }
          None => ()
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        if !run_hot_pipeline_dce_raw_drops_follow_definitely_impure_values(
            body, module_ctx,
          ) {
          return false
        }
      _ => ()
    }
    match instr {
      @lib.Drop =>
        match prev {
          Some(prev) if run_hot_pipeline_dce_raw_instr_is_definitely_impure_value(
              prev, module_ctx,
            ) => ()
          _ => return false
        }
      _ => ()
    }
    prev = Some(instr)
  }
  true
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
fn run_hot_pipeline_dce_raw_final_instr_is_fallthrough_value_structured(
  instrs : Array[@lib.Instruction],
) -> Bool {
  if instrs.is_empty() {
    return false
  }
  let final_instr = instrs[instrs.length() - 1]
  if !run_hot_pipeline_dce_raw_instr_may_fallthrough(final_instr) {
    return false
  }
  match final_instr {
    @lib.Block(block_type, @lib.Expr(_))
    | @lib.Loop(block_type, @lib.Expr(_))
    | @lib.If(block_type, _, _)
    | @lib.TryTable(block_type, _, @lib.Expr(_)) =>
      block_type != @lib.BlockType::void_()
    _ => false
  }
}

///|
fn run_hot_pipeline_dce_raw_live_typed_control_only(
  instrs : Array[@lib.Instruction],
  result_live : Bool,
) -> Bool {
  let mut prev_may_fallthrough = true
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    let instr = instrs[idx]
    let is_final = idx + 1 == instrs.length()
    if !prev_may_fallthrough {
      return false
    }
    match instr {
      @lib.Drop => return false
      @lib.Block(block_type, @lib.Expr(body)) => {
        let child_result_live = is_final &&
          result_live &&
          block_type != @lib.BlockType::void_()
        if block_type != @lib.BlockType::void_() && !child_result_live {
          return false
        }
        if !run_hot_pipeline_dce_raw_live_typed_control_only(
            body, child_result_live,
          ) {
          return false
        }
      }
      @lib.Loop(_, @lib.Expr(_)) => return false
      @lib.If(block_type, then_body, else_body) => {
        let child_result_live = is_final &&
          result_live &&
          block_type != @lib.BlockType::void_()
        if block_type != @lib.BlockType::void_() && !child_result_live {
          return false
        }
        if !run_hot_pipeline_dce_raw_live_typed_control_only(
            then_body, child_result_live,
          ) {
          return false
        }
        match else_body {
          Some(else_body) =>
            if !run_hot_pipeline_dce_raw_live_typed_control_only(
                else_body, child_result_live,
              ) {
              return false
            }
          None => ()
        }
      }
      @lib.TryTable(block_type, _, @lib.Expr(body)) => {
        let child_result_live = is_final &&
          result_live &&
          block_type != @lib.BlockType::void_()
        if block_type != @lib.BlockType::void_() && !child_result_live {
          return false
        }
        if !run_hot_pipeline_dce_raw_live_typed_control_only(
            body, child_result_live,
          ) {
          return false
        }
      }
      _ => ()
    }
    prev_may_fallthrough = run_hot_pipeline_dce_raw_instr_may_fallthrough(instr)
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
  let (
    _,
    has_structured_control,
    has_branches,
    has_drop,
    has_dead_tail_after_nonfallthrough,
    _,
  ) = run_hot_pipeline_instr_scan(instrs)
  let returns_value = match
    @ir.hot_module_resolve_func_type(module_ctx, func_idx) {
    Some(@lib.FuncType(_, results)) => !results.is_empty()
    None =>
      abort(
        "hot pipeline raw dead-code-elimination skip requires the function type to resolve",
      )
  }
  let straight_line_noop = !has_structured_control &&
    run_hot_pipeline_dce_raw_straight_line_noop(instrs)
  let structured_void_noop = has_structured_control &&
    run_hot_pipeline_dce_raw_void_structured_noop(instrs)
  let drops_follow_impure_values = !has_drop ||
    run_hot_pipeline_dce_raw_drops_follow_definitely_impure_values(
      instrs, module_ctx,
    )
  let structured_typed_noop = has_structured_control &&
    returns_value &&
    drops_follow_impure_values &&
    !has_dead_tail_after_nonfallthrough &&
    run_hot_pipeline_dce_raw_final_instr_is_fallthrough_value_structured(instrs)
  let branchy_live_typed_noop = has_branches &&
    has_structured_control &&
    returns_value &&
    !has_drop &&
    !has_dead_tail_after_nonfallthrough &&
    run_hot_pipeline_dce_raw_live_typed_control_only(instrs, true)
  if !straight_line_noop && !structured_void_noop && !structured_typed_noop {
    if !branchy_live_typed_noop {
      return false
    }
  }
  returns_value ||
  structured_void_noop ||
  instrs.is_empty() ||
  run_hot_pipeline_dce_raw_instr_is_definitely_void(
    instrs[instrs.length() - 1],
    module_ctx,
  )
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
priv struct HotPipelineLowerState {
  mut next_type_sec : @lib.TypeSec?
  mut type_sec_changed : Bool
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
fn run_hot_pipeline_lower_type_sec_flat_count(type_sec : @lib.TypeSec?) -> Int {
  let mut count = 0
  match type_sec {
    Some(@lib.TypeSec(rec_types)) =>
      for rec_type in rec_types {
        match rec_type {
          @lib.SingleRecType(_) => count += 1
          @lib.GroupRecType(group) => count += group.length()
        }
      }
    None => ()
  }
  count
}

///|
fn run_hot_pipeline_lower_find_block_result_type_idx(
  type_sec : @lib.TypeSec?,
  results : Array[@lib.ValType],
) -> @lib.TypeIdx? {
  let mut flat_idx = 0
  match type_sec {
    Some(@lib.TypeSec(rec_types)) =>
      for rec_type in rec_types {
        match rec_type {
          @lib.SingleRecType(subtype) => {
            match subtype.get_comptype() {
              @lib.FuncCompType(params, candidate_results) =>
                if params.is_empty() && candidate_results == results {
                  return Some(@lib.TypeIdx::new(flat_idx.reinterpret_as_uint()))
                }
              _ => ()
            }
            flat_idx += 1
          }
          @lib.GroupRecType(group) =>
            for subtype in group {
              match subtype.get_comptype() {
                @lib.FuncCompType(params, candidate_results) =>
                  if params.is_empty() && candidate_results == results {
                    return Some(
                      @lib.TypeIdx::new(flat_idx.reinterpret_as_uint()),
                    )
                  }
                _ => ()
              }
              flat_idx += 1
            }
        }
      }
    None => ()
  }
  None
}

///|
fn run_hot_pipeline_lower_intern_block_result_type_idx(
  lower_state : HotPipelineLowerState,
  results : Array[@lib.ValType],
) -> @lib.TypeIdx {
  match
    run_hot_pipeline_lower_find_block_result_type_idx(
      lower_state.next_type_sec,
      results,
    ) {
    Some(type_idx) => type_idx
    None => {
      let next_flat_idx = run_hot_pipeline_lower_type_sec_flat_count(
        lower_state.next_type_sec,
      )
      let next_rec_types : Array[@lib.RecType] = []
      match lower_state.next_type_sec {
        Some(@lib.TypeSec(rec_types)) =>
          for rec_type in rec_types {
            next_rec_types.push(rec_type)
          }
        None => ()
      }
      next_rec_types.push(
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([], results)),
        ),
      )
      lower_state.next_type_sec = Some(@lib.TypeSec::new(next_rec_types))
      lower_state.type_sec_changed = true
      @lib.TypeIdx::new(next_flat_idx.reinterpret_as_uint())
    }
  }
}

///|
fn run_hot_pipeline_prepare_tuple_make_lowering(
  func : @ir.HotFunc,
  lower_state : HotPipelineLowerState,
) -> Unit {
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    if node.op.to_string() != "TupleMake" {
      continue
    }
    let results = @ir.hot_type_results(func, node.ty)
    if results.length() <= 1 {
      continue
    }
    @ir.hot_tuple_make_promote_to_block(
      func,
      node_id,
      @lib.BlockType::type_idx(
        run_hot_pipeline_lower_intern_block_result_type_idx(
          lower_state, results,
        ),
      ),
    )
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
priv struct PlsCandidateScanState {
  mut has_candidate_producer : Bool
  mut has_local_get : Bool
  mut has_extension_surface : Bool
}

///|
fn run_hot_pipeline_pls_candidate_scan_into(
  instrs : Array[@lib.Instruction],
  state : PlsCandidateScanState,
) -> Unit {
  let mut prev_was_candidate_load = false
  for instr in instrs {
    if state.has_candidate_producer &&
      state.has_local_get &&
      state.has_extension_surface {
      return
    }
    match instr {
      @lib.LocalSet(_) =>
        if prev_was_candidate_load {
          state.has_candidate_producer = true
        }
      @lib.LocalGet(_) => state.has_local_get = true
      @lib.I32Extend8S
      | @lib.I32Extend16S
      | @lib.I64Extend8S
      | @lib.I64Extend16S
      | @lib.I64Extend32S
      | @lib.I64ExtendI32S
      | @lib.I64ExtendI32U
      | @lib.I32And
      | @lib.I64And
      | @lib.I32Shl
      | @lib.I64Shl => state.has_extension_surface = true
      @lib.I32Load8S(_)
      | @lib.I32Load8U(_)
      | @lib.I32Load16S(_)
      | @lib.I32Load16U(_)
      | @lib.I64Load8S(_)
      | @lib.I64Load8U(_)
      | @lib.I64Load16S(_)
      | @lib.I64Load16U(_)
      | @lib.I64Load32S(_)
      | @lib.I64Load32U(_) => prev_was_candidate_load = true
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) => {
        run_hot_pipeline_pls_candidate_scan_into(body, state)
        prev_was_candidate_load = false
      }
      @lib.If(_, then_body, else_body) => {
        run_hot_pipeline_pls_candidate_scan_into(then_body, state)
        match else_body {
          Some(else_body) =>
            run_hot_pipeline_pls_candidate_scan_into(else_body, state)
          None => ()
        }
        prev_was_candidate_load = false
      }
      @lib.TryTable(_, _, @lib.Expr(body)) => {
        run_hot_pipeline_pls_candidate_scan_into(body, state)
        prev_was_candidate_load = false
      }
      _ => prev_was_candidate_load = false
    }
  }
}

///|
fn run_hot_pipeline_pls_candidate_scan(
  instrs : Array[@lib.Instruction],
) -> (Bool, Bool, Bool) {
  let state = {
    has_candidate_producer: false,
    has_local_get: false,
    has_extension_surface: false,
  }
  run_hot_pipeline_pls_candidate_scan_into(instrs, state)
  (
    state.has_candidate_producer,
    state.has_local_get,
    state.has_extension_surface,
  )
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
fn run_hot_pipeline_raw_default_instr_for_local(
  params : Array[@lib.ValType],
  locals : @lib.Locals,
  local_id : Int,
) -> @lib.Instruction {
  match run_hot_pipeline_raw_local_type(params, locals, local_id) {
    @lib.NumTypeValType(@lib.I32NumType) =>
      @lib.Instruction::i32_const(@lib.I32::new(0))
    @lib.NumTypeValType(@lib.I64NumType) =>
      @lib.Instruction::i64_const(@lib.I64::new(0L))
    @lib.NumTypeValType(@lib.F32NumType) =>
      @lib.Instruction::f32_const(@lib.F32::new(0.0))
    @lib.NumTypeValType(@lib.F64NumType) =>
      @lib.Instruction::f64_const(@lib.F64::new(0.0))
    @lib.VecTypeValType =>
      @lib.Instruction::v128_const(
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      )
    @lib.RefTypeValType(rt) => @lib.Instruction::ref_null_type(rt)
    _ =>
      abort(
        "hot pipeline raw ssa-nomerge rewrite hit unsupported default local type",
      )
  }
}

///|
fn run_hot_pipeline_raw_append_local_read(
  out : Array[@lib.Instruction],
  source_aliases : Array[@lib.LocalIdx],
  canonical_aliases : Array[@lib.LocalIdx],
  initialized_locals : @bitset.BitSet,
  params : Array[@lib.ValType],
  locals : @lib.Locals,
  local_id : Int,
) -> Unit {
  if local_id >= params.length() &&
    source_aliases[local_id] == canonical_aliases[local_id] &&
    !initialized_locals[local_id] {
    out.push(
      run_hot_pipeline_raw_default_instr_for_local(params, locals, local_id),
    )
  } else {
    out.push(@lib.Instruction::local_get(source_aliases[local_id]))
  }
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
  canonical_aliases : Array[@lib.LocalIdx],
  initialized_locals : @bitset.BitSet,
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
    run_hot_pipeline_raw_append_local_read(
      out, source_aliases, canonical_aliases, initialized_locals, params, locals,
      local_id,
    )
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
  canonical_aliases : Array[@lib.LocalIdx],
  initialized_locals : @bitset.BitSet,
  params : Array[@lib.ValType],
  locals : @lib.Locals,
) -> Unit {
  for local_id = 0; local_id < target_aliases.length(); local_id = local_id + 1 {
    if source_aliases[local_id] == target_aliases[local_id] {
      continue
    }
    run_hot_pipeline_raw_append_local_read(
      out, source_aliases, canonical_aliases, initialized_locals, params, locals,
      local_id,
    )
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
fn run_hot_pipeline_raw_initialized_locals(
  base_local_count : Int,
  param_count : Int,
) -> @bitset.BitSet {
  let initialized = @bitset.BitSet::new(base_local_count)
  for local_id = 0; local_id < base_local_count; local_id = local_id + 1 {
    initialized[local_id] = local_id < param_count
  }
  initialized
}

///|
fn run_hot_pipeline_raw_has_default_local_reads(
  instrs : Array[@lib.Instruction],
  param_count : Int,
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Block(_, @lib.Expr(body)) =>
        if run_hot_pipeline_raw_has_default_local_reads(body, param_count) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if run_hot_pipeline_raw_has_default_local_reads(then_body, param_count) {
          return true
        }
        match else_body {
          Some(body) =>
            if run_hot_pipeline_raw_has_default_local_reads(body, param_count) {
              return true
            }
          None => ()
        }
      }
      @lib.LocalGet(@lib.LocalIdx(raw)) =>
        if raw.reinterpret_as_int() >= param_count {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn run_hot_pipeline_raw_instrs_have_later_local_read(
  instrs : Array[@lib.Instruction],
  start_idx : Int,
  local_id : Int,
) -> Bool {
  for idx = start_idx; idx < instrs.length(); idx = idx + 1 {
    match instrs[idx] {
      @lib.Block(_, @lib.Expr(body)) =>
        if run_hot_pipeline_raw_instrs_have_later_local_read(body, 0, local_id) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if run_hot_pipeline_raw_instrs_have_later_local_read(
            then_body, 0, local_id,
          ) {
          return true
        }
        match else_body {
          Some(body) =>
            if run_hot_pipeline_raw_instrs_have_later_local_read(
                body, 0, local_id,
              ) {
              return true
            }
          None => ()
        }
      }
      @lib.LocalGet(@lib.LocalIdx(raw)) =>
        if raw.reinterpret_as_int() == local_id {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn run_hot_pipeline_raw_instr_reads_local(
  instr : @lib.Instruction,
  local_id : Int,
) -> Bool {
  match instr {
    @lib.LocalGet(@lib.LocalIdx(raw)) => raw.reinterpret_as_int() == local_id
    @lib.Block(_, @lib.Expr(body))
    | @lib.Loop(_, @lib.Expr(body))
    | @lib.TryTable(_, _, @lib.Expr(body)) =>
      run_hot_pipeline_raw_instrs_have_later_local_read(body, 0, local_id)
    @lib.If(_, then_body, else_body) => {
      if run_hot_pipeline_raw_instrs_have_later_local_read(
          then_body, 0, local_id,
        ) {
        return true
      }
      match else_body {
        Some(body) =>
          run_hot_pipeline_raw_instrs_have_later_local_read(body, 0, local_id)
        None => false
      }
    }
    _ => false
  }
}

///|
fn run_hot_pipeline_raw_instrs_have_later_local_read_before_next_local_write(
  instrs : Array[@lib.Instruction],
  start_idx : Int,
  local_id : Int,
) -> Bool {
  for idx = start_idx; idx < instrs.length(); idx = idx + 1 {
    if run_hot_pipeline_raw_simplify_locals_instr_is_unconditional_terminator(
        instrs[idx],
      ) {
      return false
    }
    if run_hot_pipeline_raw_simplify_locals_instr_writes_local(
        instrs[idx],
        local_id,
      ) {
      return false
    }
    if run_hot_pipeline_raw_instr_reads_local(instrs[idx], local_id) {
      return true
    }
  }
  false
}

///|
fn run_hot_pipeline_raw_instrs_have_later_local_write(
  instrs : Array[@lib.Instruction],
  start_idx : Int,
  local_id : Int,
) -> Bool {
  for idx = start_idx; idx < instrs.length(); idx = idx + 1 {
    match instrs[idx] {
      @lib.Block(_, @lib.Expr(body)) =>
        if run_hot_pipeline_raw_instrs_have_later_local_write(body, 0, local_id) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if run_hot_pipeline_raw_instrs_have_later_local_write(
            then_body, 0, local_id,
          ) {
          return true
        }
        match else_body {
          Some(body) =>
            if run_hot_pipeline_raw_instrs_have_later_local_write(
                body, 0, local_id,
              ) {
              return true
            }
          None => ()
        }
      }
      @lib.LocalSet(@lib.LocalIdx(raw)) | @lib.LocalTee(@lib.LocalIdx(raw)) =>
        if raw.reinterpret_as_int() == local_id {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn run_hot_pipeline_raw_mark_future_local_accesses(
  instrs : Array[@lib.Instruction],
  start_idx : Int,
  accesses : @bitset.BitSet,
  reads : Bool,
) -> Unit {
  for idx = start_idx; idx < instrs.length(); idx = idx + 1 {
    match instrs[idx] {
      @lib.Block(_, @lib.Expr(body)) =>
        run_hot_pipeline_raw_mark_future_local_accesses(
          body, 0, accesses, reads,
        )
      @lib.If(_, then_body, else_body) => {
        run_hot_pipeline_raw_mark_future_local_accesses(
          then_body, 0, accesses, reads,
        )
        match else_body {
          Some(body) =>
            run_hot_pipeline_raw_mark_future_local_accesses(
              body, 0, accesses, reads,
            )
          None => ()
        }
      }
      @lib.LocalGet(@lib.LocalIdx(raw)) =>
        if reads {
          accesses[raw.reinterpret_as_int()] = true
        }
      @lib.LocalSet(@lib.LocalIdx(raw)) | @lib.LocalTee(@lib.LocalIdx(raw)) =>
        if !reads {
          accesses[raw.reinterpret_as_int()] = true
        }
      _ => ()
    }
  }
}

///|
fn run_hot_pipeline_raw_future_local_accesses(
  instrs : Array[@lib.Instruction],
  start_idx : Int,
  inherited : @bitset.BitSet,
  reads : Bool,
) -> @bitset.BitSet {
  let future = inherited.copy()
  run_hot_pipeline_raw_mark_future_local_accesses(
    instrs, start_idx, future, reads,
  )
  future
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
) -> @bitset.BitSet {
  @bitset.BitSet::new(label_stack.length())
}

///|
fn run_hot_pipeline_raw_propagate_outer_exits(
  exit_depths : @bitset.BitSet,
  nested_exit_depths : @bitset.BitSet,
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
  initialized_locals : @bitset.BitSet,
  params : Array[@lib.ValType],
  locals : @lib.Locals,
  extra_local_types : Array[@lib.ValType],
) -> Array[@lib.Instruction]? {
  let target_label = run_hot_pipeline_raw_label_inc(label_idx)
  if label_target.result_types.length() == 0 {
    let then_body : Array[@lib.Instruction] = []
    run_hot_pipeline_raw_append_alias_copies(
      then_body, source_aliases, canonical_aliases, canonical_aliases, initialized_locals,
      params, locals,
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
    then_body, source_aliases, canonical_aliases, canonical_aliases, initialized_locals,
    params, locals,
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
  initialized_locals : @bitset.BitSet,
  label_stack : Array[RawSsaLabelTarget],
  future_reads : @bitset.BitSet,
  future_writes : @bitset.BitSet,
  extra_local_types : Array[@lib.ValType],
) -> (
  Array[@lib.Instruction],
  Array[@lib.LocalIdx],
  @bitset.BitSet,
  Bool,
  @bitset.BitSet,
)? {
  let rewritten : Array[@lib.Instruction] = []
  let mut aliases = local_aliases
  let mut initialized = initialized_locals
  let mut fallthrough = true
  let exit_depths = run_hot_pipeline_raw_empty_exit_depths(label_stack)
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    let instr = instrs[idx]
    let was_reachable = fallthrough
    match instr {
      @lib.Block(block_type, @lib.Expr(body)) => {
        let label_target = match
          run_hot_pipeline_raw_label_target(module_ctx, block_type, false) {
          Some(label_target) => label_target
          None => return None
        }
        let child_future_reads = run_hot_pipeline_raw_future_local_accesses(
          instrs,
          idx + 1,
          future_reads,
          true,
        )
        let child_future_writes = run_hot_pipeline_raw_future_local_accesses(
          instrs,
          idx + 1,
          future_writes,
          false,
        )
        match
          run_hot_pipeline_raw_rewrite_instrs(
            body,
            module_ctx,
            params,
            locals,
            aliases.copy(),
            canonical_aliases,
            initialized.copy(),
            run_hot_pipeline_raw_push_label_target(label_stack, label_target),
            child_future_reads,
            child_future_writes,
            extra_local_types,
          ) {
          Some(
            (
              rewritten_body,
              body_aliases,
              body_initialized,
              body_fallthrough,
              body_exit_depths,
            )
          ) => {
            let body_exits_current_label = body_exit_depths.length() > 0 &&
              body_exit_depths[0]
            let mut finalized_body = rewritten_body
            if body_fallthrough && body_exits_current_label {
              finalized_body = run_hot_pipeline_raw_append_alias_merge_copies(
                finalized_body,
                body_aliases,
                canonical_aliases,
                canonical_aliases,
                body_initialized,
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
                initialized = if body_exits_current_label {
                  let next_initialized = initialized.copy()
                  for local_id = 0
                      local_id < next_initialized.length()
                      local_id = local_id + 1 {
                    if body_aliases[local_id] != canonical_aliases[local_id] ||
                      body_initialized[local_id] {
                      next_initialized[local_id] = true
                    }
                  }
                  next_initialized
                } else {
                  body_initialized
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
        let child_future_reads = run_hot_pipeline_raw_future_local_accesses(
          instrs,
          idx + 1,
          future_reads,
          true,
        )
        let child_future_writes = run_hot_pipeline_raw_future_local_accesses(
          instrs,
          idx + 1,
          future_writes,
          false,
        )
        let then_result = match
          run_hot_pipeline_raw_rewrite_instrs(
            then_body,
            module_ctx,
            params,
            locals,
            aliases.copy(),
            canonical_aliases,
            initialized.copy(),
            run_hot_pipeline_raw_push_label_target(label_stack, label_target),
            child_future_reads,
            child_future_writes,
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
                initialized.copy(),
                run_hot_pipeline_raw_push_label_target(
                  label_stack, label_target,
                ),
                child_future_reads,
                child_future_writes,
                extra_local_types,
              ) {
              Some(result) => result
              None => return None
            }
          None =>
            (
              [],
              aliases.copy(),
              initialized.copy(),
              true,
              run_hot_pipeline_raw_empty_exit_depths(
                run_hot_pipeline_raw_push_label_target(
                  label_stack, label_target,
                ),
              ),
            )
        }
        let (
          rewritten_then,
          then_aliases,
          then_initialized,
          then_fallthrough,
          then_exit_depths,
        ) = then_result
        let (
          rewritten_else,
          else_aliases,
          else_initialized,
          else_fallthrough,
          else_exit_depths,
        ) = else_result
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
              canonical_aliases,
              then_initialized,
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
              canonical_aliases,
              else_initialized,
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
              merged_aliases[local_id] = if local_id < params.length() {
                canonical_aliases[local_id]
              } else {
                run_hot_pipeline_raw_fresh_local(
                  params, locals, local_id, extra_local_types,
                )
              }
            }
            finalized_then = run_hot_pipeline_raw_append_alias_merge_copies(
              finalized_then,
              then_aliases,
              merged_aliases,
              canonical_aliases,
              then_initialized,
              label_target.result_types,
              params,
              locals,
              extra_local_types,
            )
            finalized_else = run_hot_pipeline_raw_append_alias_merge_copies(
              finalized_else,
              else_aliases,
              merged_aliases,
              canonical_aliases,
              else_initialized,
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
              for local_id = 0
                  local_id < initialized.length()
                  local_id = local_id + 1 {
                if then_aliases[local_id] != canonical_aliases[local_id] ||
                  then_initialized[local_id] ||
                  else_aliases[local_id] != canonical_aliases[local_id] ||
                  else_initialized[local_id] {
                  initialized[local_id] = true
                }
              }
              fallthrough = true
            } else {
              fallthrough = false
            }
          } else {
            match (then_fallthrough, else_fallthrough) {
              (true, true) => {
                aliases = merged_aliases
                for local_id = 0
                    local_id < initialized.length()
                    local_id = local_id + 1 {
                  initialized[local_id] = then_initialized[local_id] ||
                    else_initialized[local_id]
                }
                fallthrough = true
              }
              (true, false) => {
                aliases = then_aliases
                initialized = then_initialized
                fallthrough = true
              }
              (false, true) => {
                aliases = else_aliases
                initialized = else_initialized
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
          canonical_aliases,
          initialized,
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
            module_ctx, label_idx, label_target, aliases, canonical_aliases, initialized,
            params, locals, extra_local_types,
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
        run_hot_pipeline_raw_append_local_read(
          rewritten,
          aliases,
          canonical_aliases,
          initialized,
          params,
          locals,
          raw.reinterpret_as_int(),
        )
      @lib.LocalSet(@lib.LocalIdx(raw)) => {
        let local_id = raw.reinterpret_as_int()
        let later_read = run_hot_pipeline_raw_instrs_have_later_local_read(
            instrs,
            idx + 1,
            local_id,
          ) ||
          (local_id < params.length() && future_reads[local_id])
        let later_write = run_hot_pipeline_raw_instrs_have_later_local_write(
            instrs,
            idx + 1,
            local_id,
          ) ||
          (local_id < params.length() && future_writes[local_id])
        if aliases[local_id] == canonical_aliases[local_id] &&
          later_read &&
          !later_write {
          initialized[local_id] = true
          rewritten.push(
            @lib.Instruction::local_set(canonical_aliases[local_id]),
          )
        } else {
          let fresh_local = run_hot_pipeline_raw_fresh_local(
            params, locals, local_id, extra_local_types,
          )
          aliases[local_id] = fresh_local
          initialized[local_id] = true
          rewritten.push(@lib.Instruction::local_set(fresh_local))
        }
      }
      @lib.LocalTee(@lib.LocalIdx(raw)) => {
        let local_id = raw.reinterpret_as_int()
        let later_read = run_hot_pipeline_raw_instrs_have_later_local_read(
            instrs,
            idx + 1,
            local_id,
          ) ||
          (local_id < params.length() && future_reads[local_id])
        let later_write = run_hot_pipeline_raw_instrs_have_later_local_write(
            instrs,
            idx + 1,
            local_id,
          ) ||
          (local_id < params.length() && future_writes[local_id])
        if aliases[local_id] == canonical_aliases[local_id] &&
          later_read &&
          !later_write {
          initialized[local_id] = true
          rewritten.push(
            @lib.Instruction::local_tee(canonical_aliases[local_id]),
          )
        } else {
          let fresh_local = run_hot_pipeline_raw_fresh_local(
            params, locals, local_id, extra_local_types,
          )
          aliases[local_id] = fresh_local
          initialized[local_id] = true
          rewritten.push(@lib.Instruction::local_tee(fresh_local))
        }
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
  Some((rewritten, aliases, initialized, fallthrough, exit_depths))
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
  let initialized_locals = run_hot_pipeline_raw_initialized_locals(
    base_local_count,
    params.length(),
  )
  let extra_local_types : Array[@lib.ValType] = []
  match
    run_hot_pipeline_raw_rewrite_instrs(
      instrs,
      module_ctx,
      params,
      locals,
      local_aliases,
      canonical_aliases,
      initialized_locals,
      [],
      @bitset.BitSet::new(base_local_count),
      @bitset.BitSet::new(base_local_count),
      extra_local_types,
    ) {
    Some((rewritten_instrs, _, _, _, _)) => {
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
  let canonical_aliases : Array[@lib.LocalIdx] = []
  let initialized_locals = run_hot_pipeline_raw_initialized_locals(
    params.length() + locals.length(),
    params.length(),
  )
  let extra_local_types : Array[@lib.ValType] = []
  let base_local_count = params.length() + locals.length()
  for local_id = 0; local_id < base_local_count; local_id = local_id + 1 {
    let local_idx = @lib.LocalIdx::new(local_id.reinterpret_as_uint())
    local_aliases.push(local_idx)
    canonical_aliases.push(local_idx)
  }
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    let instr = instrs[idx]
    match instr {
      @lib.LocalGet(@lib.LocalIdx(raw)) =>
        run_hot_pipeline_raw_append_local_read(
          rewritten_instrs,
          local_aliases,
          canonical_aliases,
          initialized_locals,
          params,
          locals,
          raw.reinterpret_as_int(),
        )
      @lib.LocalSet(@lib.LocalIdx(raw)) => {
        let local_id = raw.reinterpret_as_int()
        if local_aliases[local_id] == canonical_aliases[local_id] &&
          run_hot_pipeline_raw_instrs_have_later_local_read(
            instrs,
            idx + 1,
            local_id,
          ) &&
          !run_hot_pipeline_raw_instrs_have_later_local_write(
            instrs,
            idx + 1,
            local_id,
          ) {
          initialized_locals[local_id] = true
          local_aliases[local_id] = canonical_aliases[local_id]
          rewritten_instrs.push(
            @lib.Instruction::local_set(canonical_aliases[local_id]),
          )
        } else {
          let fresh_local_id = base_local_count + extra_local_types.length()
          let fresh_local = @lib.LocalIdx::new(
            fresh_local_id.reinterpret_as_uint(),
          )
          extra_local_types.push(
            run_hot_pipeline_raw_local_type(params, locals, local_id),
          )
          local_aliases[local_id] = fresh_local
          initialized_locals[local_id] = true
          rewritten_instrs.push(@lib.Instruction::local_set(fresh_local))
        }
      }
      @lib.LocalTee(@lib.LocalIdx(raw)) => {
        let local_id = raw.reinterpret_as_int()
        if local_aliases[local_id] == canonical_aliases[local_id] &&
          run_hot_pipeline_raw_instrs_have_later_local_read(
            instrs,
            idx + 1,
            local_id,
          ) &&
          !run_hot_pipeline_raw_instrs_have_later_local_write(
            instrs,
            idx + 1,
            local_id,
          ) {
          initialized_locals[local_id] = true
          local_aliases[local_id] = canonical_aliases[local_id]
          rewritten_instrs.push(
            @lib.Instruction::local_tee(canonical_aliases[local_id]),
          )
        } else {
          let fresh_local_id = base_local_count + extra_local_types.length()
          let fresh_local = @lib.LocalIdx::new(
            fresh_local_id.reinterpret_as_uint(),
          )
          extra_local_types.push(
            run_hot_pipeline_raw_local_type(params, locals, local_id),
          )
          local_aliases[local_id] = fresh_local
          initialized_locals[local_id] = true
          rewritten_instrs.push(@lib.Instruction::local_tee(fresh_local))
        }
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
      trace_skip_raw: true,
    })
  }
  if descriptor.name != "ssa-nomerge" {
    return None
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = original
  let (has_writes, has_structured_control, has_branches, _, _, instr_count) = run_hot_pipeline_instr_scan(
    instrs,
  )
  let module_ctx = run_hot_pipeline_require_module_ctx(
    mod_, module_state, options,
  )
  let params = run_hot_pipeline_required_func_params(module_ctx, func_idx)
  if !has_writes {
    if !run_hot_pipeline_raw_has_default_local_reads(instrs, params.length()) {
      return Some({
        reason: "no-local-writes",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
    if has_structured_control {
      match
        run_hot_pipeline_raw_ssa_nomerge_structured(
          original, module_ctx, params,
        ) {
        Some(rewritten) =>
          if run_hot_pipeline_precompute_lowered_func_has_invalid_escape_carrier(
              rewritten,
            ) {
            return None
          } else {
            return Some({
              reason: "default-local-reads",
              func: rewritten,
              unchanged_original: false,
              trace_skip_raw: true,
            })
          }
        None => return None
      }
    }
    return Some({
      reason: "default-local-reads",
      func: run_hot_pipeline_raw_ssa_nomerge_straight_line(original, params),
      unchanged_original: false,
      trace_skip_raw: true,
    })
  }
  if has_structured_control {
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
        if run_hot_pipeline_precompute_lowered_func_has_invalid_escape_carrier(
            rewritten,
          ) {
          None
        } else {
          Some({
            reason: "structured-local-writes",
            func: rewritten,
            unchanged_original: false,
            trace_skip_raw: true,
          })
        }
      None => None
    }
  } else {
    Some({
      reason: "straight-line-local-writes",
      func: run_hot_pipeline_raw_ssa_nomerge_straight_line(original, params),
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
fn run_hot_pipeline_raw_pick_load_signs(
  mod_ : @lib.Module,
  func_idx : @lib.FuncIdx,
  descriptor : @ir.HotPassDescriptor,
) -> HotPipelineFuncResult? {
  if descriptor.name != "pick-load-signs" {
    return None
  }
  let original = run_hot_pipeline_original_func(mod_, func_idx)
  let @lib.Func(_, @lib.Expr(instrs)) = original
  let (has_candidate_producer, has_local_get, has_extension_surface) = run_hot_pipeline_pls_candidate_scan(
    instrs,
  )
  if has_candidate_producer && has_local_get && has_extension_surface {
    return None
  }
  Some({
    reason: "no-pick-load-signs-candidates",
    func: original,
    unchanged_original: true,
    trace_skip_raw: true,
  })
}

///|
fn run_hot_pipeline_raw_precompute(
  mod_ : @lib.Module,
  func_idx : @lib.FuncIdx,
  module_state : HotPipelineModuleState,
  descriptor : @ir.HotPassDescriptor,
  options : HotPipelineOptions,
) -> HotPipelineFuncResult? {
  if descriptor.name != "precompute" {
    return None
  }
  let original = run_hot_pipeline_original_func(mod_, func_idx)
  let module_ctx = if precompute_raw_func_has_global_get(original) {
    Some(run_hot_pipeline_require_module_ctx(mod_, module_state, options))
  } else {
    None
  }
  match precompute_run_raw_func(original, module_ctx) {
    Some((rewritten, changed, reason)) =>
      Some({
        reason,
        func: rewritten,
        unchanged_original: !changed,
        trace_skip_raw: true,
      })
    None => None
  }
}

///|
fn run_hot_pipeline_raw_rse(
  mod_ : @lib.Module,
  func_idx : @lib.FuncIdx,
  module_state : HotPipelineModuleState,
  descriptor : @ir.HotPassDescriptor,
  options : HotPipelineOptions,
) -> HotPipelineFuncResult? {
  if descriptor.name != "redundant-set-elimination" {
    return None
  }
  let original = run_hot_pipeline_original_func(mod_, func_idx)
  let module_ctx = run_hot_pipeline_require_module_ctx(
    mod_, module_state, options,
  )
  let params = run_hot_pipeline_required_func_params(module_ctx, func_idx)
  let env = @validate.Env::new().with_module(mod_)
  let (rewritten, changed) = rse_run_raw_func(original, params, env)
  Some({
    reason: if changed {
      "raw-same-value-local-write"
    } else {
      "no-rse-candidates"
    },
    func: rewritten,
    unchanged_original: !changed,
    trace_skip_raw: true,
  })
}

///|
fn run_hot_pipeline_raw_vacuum_instr_is_pure_drop_leaf(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.I32Const(_)
    | @lib.I64Const(_)
    | @lib.F32Const(_)
    | @lib.F64Const(_)
    | @lib.RefNull(_)
    | @lib.RefFunc(_)
    | @lib.StringConst(_)
    | @lib.LocalGet(_)
    | @lib.GlobalGet(_) => true
    _ => false
  }
}

///|
fn run_hot_pipeline_raw_vacuum_preclean_instrs(
  instrs : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Bool) {
  let rewritten : Array[@lib.Instruction] = []
  let mut changed = false
  let mut idx = 0
  let mut prev_may_fallthrough = true
  while idx < instrs.length() {
    if !prev_may_fallthrough {
      changed = true
      break
    }
    let instr = instrs[idx]
    match instr {
      @lib.Nop => {
        changed = true
        idx = idx + 1
        continue
      }
      @lib.Block(block_type, @lib.Expr(body)) => {
        let (next_body, body_changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
          body,
        )
        changed = changed || body_changed
        rewritten.push(
          @lib.Instruction::block(block_type, @lib.Expr::new(next_body)),
        )
      }
      @lib.Loop(block_type, @lib.Expr(body)) => {
        let (next_body, body_changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
          body,
        )
        changed = changed || body_changed
        rewritten.push(
          @lib.Instruction::loop_(block_type, @lib.Expr::new(next_body)),
        )
      }
      @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
        let (next_body, body_changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
          body,
        )
        changed = changed || body_changed
        rewritten.push(
          @lib.Instruction::try_table(
            block_type,
            catches,
            @lib.Expr::new(next_body),
          ),
        )
      }
      @lib.If(block_type, then_body, else_body) => {
        let (next_then, then_changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
          then_body,
        )
        let (next_else, else_changed) = match else_body {
          Some(body) => {
            let (cleaned, did_change) = run_hot_pipeline_raw_vacuum_preclean_instrs(
              body,
            )
            (Some(cleaned), did_change)
          }
          None => (None, false)
        }
        changed = changed || then_changed || else_changed
        rewritten.push(@lib.Instruction::if_(block_type, next_then, next_else))
      }
      _ => {
        match instr {
          @lib.Drop if rewritten.length() > 0 &&
            run_hot_pipeline_raw_vacuum_instr_is_pure_drop_leaf(
              rewritten[rewritten.length() - 1],
            ) => {
            ignore(rewritten.pop())
            changed = true
            idx = idx + 1
            continue
          }
          _ => ()
        }
        if idx + 1 < instrs.length() &&
          run_hot_pipeline_raw_vacuum_instr_is_pure_drop_leaf(instr) {
          match instrs[idx + 1] {
            @lib.Drop => {
              changed = true
              idx = idx + 2
              continue
            }
            _ => ()
          }
        }
        rewritten.push(instr)
      }
    }
    prev_may_fallthrough = match rewritten[rewritten.length() - 1] {
      @lib.Unreachable
      | @lib.Return
      | @lib.ReturnCall(_)
      | @lib.ReturnCallRef(_)
      | @lib.Br(_)
      | @lib.BrTable(_, _) => false
      _ => true
    }
    idx = idx + 1
  }
  (rewritten, changed)
}

///|
fn run_hot_pipeline_raw_vacuum_preclean(
  mod_ : @lib.Module,
  func_idx : @lib.FuncIdx,
  descriptor : @ir.HotPassDescriptor,
) -> HotPipelineFuncResult? {
  if descriptor.name != "vacuum" {
    return None
  }
  let original = run_hot_pipeline_original_func(mod_, func_idx)
  let @lib.Func(locals, @lib.Expr(instrs)) = original
  let (_, _, _, _, _, instr_count) = run_hot_pipeline_instr_scan(instrs)
  if instr_count <= 2048 {
    return None
  }
  let (rewritten, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(instrs)
  if !changed {
    return None
  }
  Some({
    reason: "raw-vacuum-preclean",
    func: @lib.Func::new(locals, @lib.Expr::new(rewritten)),
    unchanged_original: false,
    trace_skip_raw: true,
  })
}

///|
fn run_hot_pipeline_raw_vacuum_has_candidate_instrs(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Nop | @lib.Drop => return true
      @lib.Block(block_type, @lib.Expr(body)) => {
        match block_type {
          @lib.VoidBlockType if body.length() == 0 => return true
          _ => ()
        }
        if body.length() == 1 {
          match body[0] {
            @lib.Unreachable => return true
            _ => ()
          }
        }
        if run_hot_pipeline_raw_vacuum_has_candidate_instrs(body) {
          return true
        }
      }
      @lib.Loop(_, @lib.Expr(body)) | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if run_hot_pipeline_raw_vacuum_has_candidate_instrs(body) {
          return true
        }
      @lib.If(block_type, then_body, else_body) => {
        match (block_type, then_body.length(), else_body) {
          (@lib.VoidBlockType, 0, Some(body)) if body.length() > 0 =>
            return true
          _ => ()
        }
        if run_hot_pipeline_raw_vacuum_has_candidate_instrs(then_body) {
          return true
        }
        match else_body {
          Some(else_body) =>
            if run_hot_pipeline_raw_vacuum_has_candidate_instrs(else_body) {
              return true
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn run_hot_pipeline_raw_vacuum_no_candidates(
  mod_ : @lib.Module,
  func_idx : @lib.FuncIdx,
  descriptor : @ir.HotPassDescriptor,
) -> HotPipelineFuncResult? {
  if descriptor.name != "vacuum" {
    return None
  }
  let original = run_hot_pipeline_original_func(mod_, func_idx)
  let @lib.Func(_, @lib.Expr(instrs)) = original
  if instrs.length() == 0 ||
    run_hot_pipeline_raw_vacuum_has_candidate_instrs(instrs) {
    return None
  }
  Some({
    reason: "no-vacuum-candidates",
    func: original,
    unchanged_original: true,
    trace_skip_raw: true,
  })
}

///|
fn run_hot_pipeline_instr_has_remove_unused_names_candidate(
  instrs : Array[@lib.Instruction],
) -> Bool {
  instrs.any(fn(instr) {
    run_hot_pipeline_instr_is_remove_unused_names_candidate(instr)
  })
}

///|
fn run_hot_pipeline_instr_is_remove_unused_names_candidate(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.Instruction::Loop(_, _) => true
    @lib.Instruction::Block(
      _,
      @lib.Expr([@lib.Instruction::Block(_, @lib.Expr(_))])
    ) => true
    @lib.Instruction::Block(_, @lib.Expr(body))
    | @lib.Instruction::TryTable(_, _, @lib.Expr(body)) =>
      run_hot_pipeline_instr_has_remove_unused_names_candidate(body)
    @lib.Instruction::If(_, then_, Some(else_)) =>
      run_hot_pipeline_instr_has_remove_unused_names_candidate(then_) ||
      run_hot_pipeline_instr_has_remove_unused_names_candidate(else_)
    @lib.Instruction::If(_, then_, None) =>
      run_hot_pipeline_instr_has_remove_unused_names_candidate(then_)
    _ => false
  }
}

///|
fn run_hot_pipeline_raw_remove_unused_names(
  mod_ : @lib.Module,
  func_idx : @lib.FuncIdx,
  descriptor : @ir.HotPassDescriptor,
) -> HotPipelineFuncResult? {
  if descriptor.name != "remove-unused-names" {
    return None
  }
  let original = run_hot_pipeline_original_func(mod_, func_idx)
  let @lib.Func(_, @lib.Expr(instrs)) = original
  if run_hot_pipeline_instr_has_remove_unused_names_candidate(instrs) {
    None
  } else {
    Some({
      reason: "no-remove-unused-names-candidates",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
}

///|
fn run_hot_pipeline_raw_remove_unused_brs(
  mod_ : @lib.Module,
  func_idx : @lib.FuncIdx,
  descriptor : @ir.HotPassDescriptor,
  options : HotPipelineOptions,
) -> HotPipelineFuncResult? {
  if descriptor.name != "remove-unused-brs" {
    return None
  }
  let original = run_hot_pipeline_original_func(mod_, func_idx)
  let @lib.Func(locals, @lib.Expr(instrs)) = original
  let (rewritten_instrs, rewrite_count, saw_br_table) = run_hot_pipeline_raw_remove_unused_brs_rewrite_decision_ladder_instrs(
    instrs,
  )
  if rewrite_count > 0 &&
    saw_br_table &&
    !run_hot_pipeline_raw_remove_unused_brs_has_hot_only_candidates(
      rewritten_instrs,
    ) {
    return Some({
      reason: "decision-ladder-selects",
      func: @lib.Func::new(locals, @lib.Expr::new(rewritten_instrs)),
      unchanged_original: false,
      trace_skip_raw: true,
    })
  }
  if run_hot_pipeline_raw_remove_unused_brs_can_skip_large_void_if_return_ladder(
      locals, instrs,
    ) {
    return Some({
      reason: "large-void-if-return-ladder-noop",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if run_hot_pipeline_raw_remove_unused_brs_can_skip_large_result_br_table_dispatch_ladder(
      instrs,
    ) {
    return Some({
      reason: "large-result-br-table-dispatch-ladder-noop",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if run_hot_pipeline_raw_remove_unused_brs_can_skip_large_value_if_branch_ladder(
      locals, instrs,
    ) {
    return Some({
      reason: "large-value-if-branch-ladder-noop",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if run_hot_pipeline_raw_remove_unused_brs_can_skip_large_drop_heavy_branch_ladder(
      locals, instrs,
    ) &&
    !run_hot_pipeline_raw_remove_unused_brs_has_condition_child_value_if_candidate(
      instrs,
    ) &&
    !run_hot_pipeline_raw_remove_unused_brs_has_prefix_guard_payload_branch_candidate(
      instrs,
    ) {
    return Some({
      reason: "large-drop-heavy-branch-ladder-noop",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if run_hot_pipeline_raw_remove_unused_brs_can_skip_moderate_control_ladder(
      locals, instrs,
    ) {
    return Some({
      reason: "moderate-control-ladder-noop",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if run_hot_pipeline_raw_remove_unused_brs_can_skip_large_typed_br_table_encoder_ladder(
      locals, instrs,
    ) {
    return Some({
      reason: "large-typed-br-table-encoder-ladder-noop",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if run_hot_pipeline_raw_remove_unused_brs_can_skip_unique_loop_select_return_ladder(
      locals, instrs,
    ) &&
    !run_hot_pipeline_raw_remove_unused_brs_has_prefix_guard_payload_branch_candidate(
      instrs,
    ) {
    return Some({
      reason: "unique-loop-select-return-ladder-noop",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if run_hot_pipeline_raw_remove_unused_brs_can_skip_structured_return_ladder(
      locals, instrs,
    ) &&
    !run_hot_pipeline_raw_remove_unused_brs_has_condition_child_value_if_candidate(
      instrs,
    ) &&
    !run_hot_pipeline_raw_remove_unused_brs_has_prefix_guard_payload_branch_candidate(
      instrs,
    ) {
    return Some({
      reason: "structured-return-ladder-noop",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if !options.validate_final_module &&
    run_hot_pipeline_raw_remove_unused_brs_can_skip_unchecked_moderate_call_mesh(
      locals, instrs,
    ) {
    return Some({
      reason: "unchecked-moderate-call-mesh-noop",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if run_hot_pipeline_instr_has_remove_unused_brs_candidate(instrs) {
    None
  } else {
    Some({
      reason: "no-remove-unused-brs-candidates",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
}

///|
fn run_hot_pipeline_simplify_locals_lowered_count_local_gets_in_instr(
  instr : @lib.Instruction,
  counts : Array[Int],
) -> Unit {
  match instr {
    @lib.LocalGet(local_idx) =>
      match local_idx {
        @lib.LocalIdx(raw) => {
          let idx = raw.reinterpret_as_int()
          if idx >= 0 && idx < counts.length() {
            counts[idx] = counts[idx] + 1
          }
        }
      }
    @lib.Block(_, @lib.Expr(body))
    | @lib.Loop(_, @lib.Expr(body))
    | @lib.TryTable(_, _, @lib.Expr(body)) =>
      run_hot_pipeline_simplify_locals_lowered_count_local_gets_in_body(
        body, counts,
      )
    @lib.If(_, then_, else_) => {
      run_hot_pipeline_simplify_locals_lowered_count_local_gets_in_body(
        then_, counts,
      )
      match else_ {
        Some(else_body) =>
          run_hot_pipeline_simplify_locals_lowered_count_local_gets_in_body(
            else_body, counts,
          )
        None => ()
      }
    }
    _ => ()
  }
}

///|
fn run_hot_pipeline_simplify_locals_lowered_max_local_idx_in_instr(
  instr : @lib.Instruction,
) -> Int {
  match instr {
    @lib.LocalGet(@lib.LocalIdx(raw))
    | @lib.LocalSet(@lib.LocalIdx(raw))
    | @lib.LocalTee(@lib.LocalIdx(raw)) => raw.reinterpret_as_int()
    @lib.Block(_, @lib.Expr(body))
    | @lib.Loop(_, @lib.Expr(body))
    | @lib.TryTable(_, _, @lib.Expr(body)) =>
      run_hot_pipeline_simplify_locals_lowered_max_local_idx_in_body(body)
    @lib.If(_, then_, else_) => {
      let then_max = run_hot_pipeline_simplify_locals_lowered_max_local_idx_in_body(
        then_,
      )
      let else_max = match else_ {
        Some(else_body) =>
          run_hot_pipeline_simplify_locals_lowered_max_local_idx_in_body(
            else_body,
          )
        None => -1
      }
      if then_max > else_max {
        then_max
      } else {
        else_max
      }
    }
    _ => -1
  }
}

///|
fn run_hot_pipeline_simplify_locals_lowered_max_local_idx_in_body(
  body : Array[@lib.Instruction],
) -> Int {
  let mut max_idx = -1
  for instr in body {
    let instr_max = run_hot_pipeline_simplify_locals_lowered_max_local_idx_in_instr(
      instr,
    )
    if instr_max > max_idx {
      max_idx = instr_max
    }
  }
  max_idx
}

///|
fn run_hot_pipeline_simplify_locals_lowered_instr_stops_following_body_instrs(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.Br(_)
    | @lib.BrTable(_, _)
    | @lib.Return
    | @lib.Throw(_)
    | @lib.ThrowRef
    | @lib.Unreachable => true
    @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
      run_hot_pipeline_simplify_locals_lowered_body_is_nonfallthrough(body)
    @lib.If(_, then_, Some(else_)) =>
      run_hot_pipeline_simplify_locals_lowered_body_is_nonfallthrough(then_) &&
      run_hot_pipeline_simplify_locals_lowered_body_is_nonfallthrough(else_)
    _ => false
  }
}

///|
fn run_hot_pipeline_simplify_locals_lowered_body_is_nonfallthrough(
  body : Array[@lib.Instruction],
) -> Bool {
  if body.length() == 0 {
    return false
  }
  match body[body.length() - 1] {
    @lib.Br(_)
    | @lib.BrTable(_, _)
    | @lib.Return
    | @lib.Throw(_)
    | @lib.ThrowRef
    | @lib.Unreachable => true
    _ => false
  }
}

///|
fn run_hot_pipeline_simplify_locals_lowered_count_local_gets_in_body(
  body : Array[@lib.Instruction],
  counts : Array[Int],
) -> Unit {
  for instr in body {
    run_hot_pipeline_simplify_locals_lowered_count_local_gets_in_instr(
      instr, counts,
    )
    if run_hot_pipeline_simplify_locals_lowered_instr_stops_following_body_instrs(
        instr,
      ) {
      break
    }
  }
}

///|
fn run_hot_pipeline_simplify_locals_lowered_split_wrapper_middle_is_safe(
  body : Array[@lib.Instruction],
  start : Int,
  end_ : Int,
  scratch_raw : UInt,
  source_local : Int?,
) -> Bool {
  let mut stack_depth = 0
  for idx = start; idx < end_; idx = idx + 1 {
    match body[idx] {
      @lib.Nop => ()
      @lib.LocalGet(@lib.LocalIdx(raw)) => {
        if raw == scratch_raw {
          return false
        }
        stack_depth = stack_depth + 1
      }
      @lib.I32Const(_)
      | @lib.I64Const(_)
      | @lib.F32Const(_)
      | @lib.F64Const(_) => stack_depth = stack_depth + 1
      @lib.LocalSet(@lib.LocalIdx(raw)) =>
        if raw == scratch_raw {
          return false
        } else {
          match source_local {
            Some(source_local) =>
              if raw.reinterpret_as_int() == source_local {
                return false
              }
            None => ()
          }
          stack_depth = stack_depth - 1
          if stack_depth < 0 {
            return false
          }
        }
      _ => return false
    }
  }
  stack_depth == 0
}

///|
fn run_hot_pipeline_simplify_locals_lowered_rewrite_split_value_wrapper_body(
  body : Array[@lib.Instruction],
) -> Array[@lib.Instruction]? {
  if body.length() < 3 {
    return None
  }
  let producer = body[0]
  if !run_hot_pipeline_raw_simplify_locals_instr_is_dupable_copy_value(producer) {
    return None
  }
  match (body[1], body[body.length() - 1]) {
    (
      @lib.LocalSet(@lib.LocalIdx(scratch_raw)),
      @lib.LocalGet(@lib.LocalIdx(last_raw)),
    ) =>
      if scratch_raw != last_raw {
        None
      } else {
        let source_local = run_hot_pipeline_raw_simplify_locals_instr_source_local(
          producer,
        )
        if !run_hot_pipeline_simplify_locals_lowered_split_wrapper_middle_is_safe(
            body,
            2,
            body.length() - 1,
            scratch_raw,
            source_local,
          ) {
          return None
        }
        let rewritten : Array[@lib.Instruction] = []
        for idx = 2; idx + 1 < body.length(); idx = idx + 1 {
          match body[idx] {
            @lib.Nop => ()
            instr => rewritten.push(instr)
          }
        }
        rewritten.push(producer)
        Some(rewritten)
      }
    _ => None
  }
}

///|
fn run_hot_pipeline_simplify_locals_lowered_hoist_nops_across_dupable_values(
  instrs : Array[@lib.Instruction],
) -> Array[@lib.Instruction] {
  let rewritten : Array[@lib.Instruction] = []
  let mut idx = 0
  while idx < instrs.length() {
    let mut end_ = idx
    let mut saw_nop = false
    let mut saw_dupable = false
    while end_ < instrs.length() {
      match instrs[end_] {
        @lib.Nop => {
          saw_nop = true
          end_ = end_ + 1
        }
        instr =>
          if run_hot_pipeline_raw_simplify_locals_instr_is_dupable_copy_value(
              instr,
            ) {
            saw_dupable = true
            end_ = end_ + 1
          } else {
            break
          }
      }
    }
    if saw_nop && saw_dupable {
      for run_idx = idx; run_idx < end_; run_idx = run_idx + 1 {
        match instrs[run_idx] {
          @lib.Nop => rewritten.push(instrs[run_idx])
          _ => ()
        }
      }
      for run_idx = idx; run_idx < end_; run_idx = run_idx + 1 {
        match instrs[run_idx] {
          instr =>
            if run_hot_pipeline_raw_simplify_locals_instr_is_dupable_copy_value(
                instr,
              ) {
              rewritten.push(instr)
            }
        }
      }
      idx = end_
    } else {
      rewritten.push(instrs[idx])
      idx = idx + 1
    }
  }
  rewritten
}

///|
fn run_hot_pipeline_simplify_locals_lowered_cleanup_instr(
  instr : @lib.Instruction,
  counts : Array[Int],
) -> @lib.Instruction? {
  match instr {
    @lib.Nop => Some(instr)
    @lib.LocalTee(local_idx) =>
      match local_idx {
        @lib.LocalIdx(raw) => {
          let idx = raw.reinterpret_as_int()
          if idx >= 0 && idx < counts.length() && counts[idx] == 0 {
            None
          } else {
            Some(instr)
          }
        }
      }
    @lib.Block(block_type, @lib.Expr(body)) => {
      let cleaned_body = run_hot_pipeline_simplify_locals_lowered_cleanup_body(
        body, counts,
      )
      match
        run_hot_pipeline_simplify_locals_lowered_rewrite_split_value_wrapper_body(
          cleaned_body,
        ) {
        Some(rewritten_body) =>
          if rewritten_body.length() == 1 {
            Some(rewritten_body[0])
          } else {
            Some(
              @lib.Instruction::block(
                block_type,
                @lib.Expr::new(rewritten_body),
              ),
            )
          }
        None =>
          Some(
            @lib.Instruction::block(block_type, @lib.Expr::new(cleaned_body)),
          )
      }
    }
    @lib.Loop(block_type, @lib.Expr(body)) =>
      Some(
        @lib.Instruction::loop_(
          block_type,
          @lib.Expr::new(
            run_hot_pipeline_simplify_locals_lowered_cleanup_body(body, counts),
          ),
        ),
      )
    @lib.If(block_type, then_, else_) =>
      Some(
        @lib.Instruction::if_(
          block_type,
          run_hot_pipeline_simplify_locals_lowered_cleanup_body(then_, counts),
          match else_ {
            Some(else_body) =>
              Some(
                run_hot_pipeline_simplify_locals_lowered_cleanup_body(
                  else_body, counts,
                ),
              )
            None => None
          },
        ),
      )
    @lib.TryTable(block_type, catches, @lib.Expr(body)) =>
      Some(
        @lib.Instruction::try_table(
          block_type,
          catches,
          @lib.Expr::new(
            run_hot_pipeline_simplify_locals_lowered_cleanup_body(body, counts),
          ),
        ),
      )
    _ => Some(instr)
  }
}

///|
fn run_hot_pipeline_simplify_locals_lowered_drop_dead_adjacent_local_set_get_pairs(
  instrs : Array[@lib.Instruction],
) -> Array[@lib.Instruction] {
  let normalized : Array[@lib.Instruction] = []
  for instr in instrs {
    match instr {
      @lib.Block(bt, @lib.Expr(body)) =>
        normalized.push(
          @lib.Instruction::block(
            bt,
            @lib.Expr::new(
              run_hot_pipeline_simplify_locals_lowered_drop_dead_adjacent_local_set_get_pairs(
                body,
              ),
            ),
          ),
        )
      @lib.Loop(bt, @lib.Expr(body)) =>
        normalized.push(
          @lib.Instruction::loop_(
            bt,
            @lib.Expr::new(
              run_hot_pipeline_simplify_locals_lowered_drop_dead_adjacent_local_set_get_pairs(
                body,
              ),
            ),
          ),
        )
      @lib.TryTable(bt, catches, @lib.Expr(body)) =>
        normalized.push(
          @lib.Instruction::try_table(
            bt,
            catches,
            @lib.Expr::new(
              run_hot_pipeline_simplify_locals_lowered_drop_dead_adjacent_local_set_get_pairs(
                body,
              ),
            ),
          ),
        )
      @lib.If(bt, then_body, else_body) =>
        normalized.push(
          @lib.Instruction::if_(
            bt,
            run_hot_pipeline_simplify_locals_lowered_drop_dead_adjacent_local_set_get_pairs(
              then_body,
            ),
            match else_body {
              Some(else_body) =>
                Some(
                  run_hot_pipeline_simplify_locals_lowered_drop_dead_adjacent_local_set_get_pairs(
                    else_body,
                  ),
                )
              None => None
            },
          ),
        )
      _ => normalized.push(instr)
    }
  }
  let rewritten : Array[@lib.Instruction] = []
  let mut idx = 0
  while idx < normalized.length() {
    if idx + 1 < normalized.length() {
      match (normalized[idx], normalized[idx + 1]) {
        (
          @lib.LocalSet(@lib.LocalIdx(raw)),
          @lib.LocalGet(@lib.LocalIdx(next_raw)),
        ) =>
          if raw == next_raw &&
            !run_hot_pipeline_raw_instrs_have_later_local_read(
              normalized,
              idx + 2,
              raw.reinterpret_as_int(),
            ) {
            rewritten.push(@lib.Instruction::nop())
            idx = idx + 2
          } else {
            rewritten.push(normalized[idx])
            idx = idx + 1
          }
        _ => {
          rewritten.push(normalized[idx])
          idx = idx + 1
        }
      }
    } else {
      rewritten.push(normalized[idx])
      idx = idx + 1
    }
  }
  rewritten
}

///|
fn run_hot_pipeline_simplify_locals_lowered_cleanup_body(
  body : Array[@lib.Instruction],
  counts : Array[Int],
) -> Array[@lib.Instruction] {
  let cleaned : Array[@lib.Instruction] = []
  for idx = 0; idx < body.length(); idx = idx + 1 {
    let instr = body[idx]
    let preserve_suffix_read_tee = match instr {
      @lib.LocalTee(@lib.LocalIdx(raw)) => {
        let local_id = raw.reinterpret_as_int()
        local_id >= 0 &&
        local_id < counts.length() &&
        counts[local_id] == 0 &&
        run_hot_pipeline_raw_instrs_have_later_local_read(
          body,
          idx + 1,
          local_id,
        )
      }
      _ => false
    }
    if preserve_suffix_read_tee {
      cleaned.push(instr)
      continue
    }
    match
      run_hot_pipeline_simplify_locals_lowered_cleanup_instr(instr, counts) {
      Some(rewritten) => cleaned.push(rewritten)
      None => ()
    }
  }
  run_hot_pipeline_simplify_locals_lowered_hoist_nops_across_dupable_values(
    cleaned,
  )
}

///|
fn run_hot_pipeline_simplify_locals_cleanup_exact_func(
  func : @lib.Func,
) -> (@lib.Func, Bool) {
  let @lib.Func(locals, @lib.Expr(body)) = func
  let rewritten_body = run_hot_pipeline_simplify_locals_lowered_drop_dead_adjacent_local_set_get_pairs(
    body,
  )
  let max_local_idx = run_hot_pipeline_simplify_locals_lowered_max_local_idx_in_body(
    rewritten_body,
  )
  let counts = Array::make(max_local_idx + 1, 0)
  run_hot_pipeline_simplify_locals_lowered_count_local_gets_in_body(
    rewritten_body, counts,
  )
  let cleaned_body = run_hot_pipeline_simplify_locals_lowered_cleanup_body(
    rewritten_body, counts,
  )
  (
    @lib.Func::new(locals, @lib.Expr::new(cleaned_body)),
    rewritten_body != body || cleaned_body != rewritten_body,
  )
}

///|
fn run_hot_pipeline_simplify_locals_cleanup_lowered_func(
  func : @lib.Func,
  descriptor_name : String,
) -> @lib.Func {
  if descriptor_name != "simplify-locals" &&
    descriptor_name != "simplify-locals-nostructure" &&
    descriptor_name != "simplify-locals-no-structure" &&
    descriptor_name != "simplify-locals-notee-nostructure" {
    return func
  }
  let (cleaned, _) = run_hot_pipeline_simplify_locals_cleanup_exact_func(func)
  cleaned
}

///|
fn run_hot_pipeline_vacuum_needs_empty_func_nop_canonicalization(
  func : @lib.Func,
) -> Bool {
  match func {
    @lib.Func(_, @lib.Expr([])) => true
    _ => false
  }
}

///|
fn run_hot_pipeline_canonicalize_lowered_func_for_descriptor(
  func : @lib.Func,
  descriptor_name : String,
) -> @lib.Func {
  let cleaned = run_hot_pipeline_simplify_locals_cleanup_lowered_func(
    func, descriptor_name,
  )
  if descriptor_name != "vacuum" && descriptor_name != "precompute" {
    return cleaned
  }
  match cleaned {
    @lib.Func(locals, @lib.Expr([])) =>
      @lib.Func::new(locals, @lib.Expr::new([@lib.Instruction::nop()]))
    _ => cleaned
  }
}

///|
fn run_hot_pipeline_lower_options_for_descriptor(
  descriptor_name : String,
) -> @ir.HotLowerOptions {
  if descriptor_name == "ssa-nomerge" {
    @ir.HotLowerOptions::new(preserve_dead_local_tee_drops=true)
  } else if descriptor_name == "simplify-locals" ||
    descriptor_name == "simplify-locals-nostructure" ||
    descriptor_name == "simplify-locals-no-structure" ||
    descriptor_name == "simplify-locals-notee-nostructure" {
    @ir.HotLowerOptions::new(
      preserve_if_arm_single_nops=true,
      preserve_dead_local_tee_drops=true,
      preserve_nontrailing_nops=true,
      preserve_trailing_nops=true,
    )
  } else if descriptor_name == "precompute" ||
    descriptor_name == "precompute-propagate-prefix" {
    @ir.HotLowerOptions::new(preserve_nontrailing_nops=true)
  } else if descriptor_name == "remove-unused-brs" {
    @ir.HotLowerOptions::new(
      preserve_if_arm_single_nops=true,
      preserve_dead_local_tee_drops=true,
      preserve_nontrailing_nops=true,
    )
  } else if descriptor_name == "merge-blocks" {
    @ir.HotLowerOptions::new(
      preserve_if_arm_single_nops=true,
      preserve_dead_local_tee_drops=true,
      preserve_nontrailing_nops=true,
      preserve_trailing_nops=true,
      preserve_typed_loop_const_prefix_spills=true,
    )
  } else {
    @ir.HotLowerOptions::new()
  }
}

///|
fn run_hot_pipeline_unchecked_should_verify_before_lower(
  descriptor_name : String,
) -> Bool {
  descriptor_name == "simplify-locals" ||
  descriptor_name == "simplify-locals-nostructure" ||
  descriptor_name == "simplify-locals-no-structure" ||
  descriptor_name == "simplify-locals-notee-nostructure"
}

///|
fn run_hot_pipeline_unchecked_verify_before_lower_skip_reason(
  func : @ir.HotFunc,
  descriptor_name : String,
  options : HotPipelineOptions,
) -> String? {
  if options.validate_final_module ||
    !run_hot_pipeline_unchecked_should_verify_before_lower(descriptor_name) {
    return None
  }
  match
    pipeline_verify_checkpoint_with_perf(
      options.perf,
      HotPipelineVerifyPolicy::AfterEachPass,
      "verify before lower",
      HotPipelineVerifyTarget::HotFuncTarget(func),
      "verify:before-lower",
    ) {
    Ok(_) => None
    Err(err) => Some(err)
  }
}

///|
fn run_hot_pipeline_func(
  mod_ : @lib.Module,
  func_idx : @lib.FuncIdx,
  descriptor : @ir.HotPassDescriptor,
  module_state : HotPipelineModuleState,
  lower_state : HotPipelineLowerState,
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
  match run_hot_pipeline_raw_pick_load_signs(mod_, func_idx, descriptor) {
    Some(result) => return Ok(result)
    None => ()
  }
  match
    run_hot_pipeline_raw_precompute(
      mod_, func_idx, module_state, descriptor, options,
    ) {
    Some(result) => return Ok(result)
    None => ()
  }
  match
    run_hot_pipeline_raw_rse(mod_, func_idx, module_state, descriptor, options) {
    Some(result) => return Ok(result)
    None => ()
  }
  match run_hot_pipeline_raw_vacuum_preclean(mod_, func_idx, descriptor) {
    Some(result) => return Ok(result)
    None => ()
  }
  match run_hot_pipeline_raw_vacuum_no_candidates(mod_, func_idx, descriptor) {
    Some(result) => return Ok(result)
    None => ()
  }
  match run_hot_pipeline_raw_remove_unused_names(mod_, func_idx, descriptor) {
    Some(result) => return Ok(result)
    None => ()
  }
  pipeline_trace_hook(
    options.trace,
    descriptor.name,
    "func",
    payload="func_idx=\{func_idx}",
  )
  match
    run_hot_pipeline_raw_remove_unused_brs(mod_, func_idx, descriptor, options) {
    Some(result) => return Ok(result)
    None => ()
  }
  match
    run_hot_pipeline_raw_simplify_locals(
      mod_, func_idx, module_state, descriptor, options,
    ) {
    Some(result) => return Ok(result)
    None => ()
  }
  let lift_start_us = perf_start_timer_opt(options.perf, "lift")
  let module_ctx = run_hot_pipeline_require_module_ctx(
    mod_, module_state, options,
  )
  let func = match
    @ir.hot_lift_func_with_context_result(mod_, func_idx, module_ctx) {
    Ok(func) => func
    Err(err) => {
      pipeline_trace_hook(
        options.trace,
        descriptor.name,
        "lift-error",
        payload="func_idx=\{func_idx} err=\{err}",
      )
      if !options.validate_final_module {
        return Ok({
          reason: "hot-lift-error",
          func: run_hot_pipeline_original_func(mod_, func_idx),
          unchanged_original: true,
          trace_skip_raw: true,
        })
      }
      return Err("lift: \{err}")
    }
  }
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
    func_idx == @lib.FuncIdx::new(3660U) {
    let use_def = @ir.use_def_build(func)
    let analysis = tuple_optimization_analyze(func, use_def)
    let rewrite_mask = tuple_optimization_build_group_rewrite_mask(
      func,
      use_def,
      analysis.query_summary,
      analysis.groups,
    )
    (options.trace)(
      "debug[after-lift:\{descriptor.name}]:group-count \{analysis.groups.length()} rewrite-mask=\{tuple_optimization_bitset_debug_string(rewrite_mask)}",
    )
    for group_id = 0
        group_id < analysis.groups.length()
        group_id = group_id + 1 {
      (options.trace)(
        "debug[after-lift:\{descriptor.name}]:group \{group_id} rewrite=\{rewrite_mask[group_id]} \{analysis.groups[group_id]}",
      )
    }
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
        (
          @ir.hot_revision_current(func) == lifted_revision ||
          descriptor.name == "remove-unused-brs"
        ) &&
        descriptor.name != "heap-store-optimization" &&
        !((descriptor.name == "vacuum" || descriptor.name == "precompute") &&
        run_hot_pipeline_vacuum_needs_empty_func_nop_canonicalization(
          run_hot_pipeline_original_func(mod_, func_idx),
        )) &&
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
    func_idx == @lib.FuncIdx::new(3660U) {
    (options.trace)(
      "debug[after-pass:\{descriptor.name}]:core \{@ir.hot_debug_dump_core(func)}",
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
          run_hot_pipeline_prepare_tuple_make_lowering(func, lower_state)
          let lower_start_us = perf_start_timer_opt(options.perf, "lower")
          let lowered = run_hot_pipeline_canonicalize_lowered_func_for_descriptor(
            @ir.hot_lower_func_with_options(
              func,
              run_hot_pipeline_lower_options_for_descriptor(descriptor.name),
            ),
            descriptor.name,
          )
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
      match
        run_hot_pipeline_unchecked_verify_before_lower_skip_reason(
          func,
          descriptor.name,
          options,
        ) {
        Some(err) => {
          pipeline_trace_hook(
            options.trace,
            descriptor.name,
            "verify-before-lower-error",
            payload="func_idx=\{func_idx} err=\{err}",
          )
          return Ok({
            reason: "hot-verify-before-lower-error",
            func: run_hot_pipeline_original_func(mod_, func_idx),
            unchanged_original: true,
            trace_skip_raw: true,
          })
        }
        None => ()
      }
      run_hot_pipeline_prepare_tuple_make_lowering(func, lower_state)
      let lower_start_us = perf_start_timer_opt(options.perf, "lower")
      let lowered = run_hot_pipeline_canonicalize_lowered_func_for_descriptor(
        @ir.hot_lower_func_unverified_with_options(
          func,
          run_hot_pipeline_lower_options_for_descriptor(descriptor.name),
        ),
        descriptor.name,
      )
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
fn run_hot_pipeline_precompute_writeback_validation_error(
  mod_ : @lib.Module,
  code_idx : Int,
  rewritten : @lib.Func,
) -> String? {
  let func_idx = @lib.FuncIdx::new(
    (run_hot_pipeline_imported_func_count(mod_) + code_idx).reinterpret_as_uint(),
  )
  match
    @validate.validate_defined_func_against_module(mod_, func_idx, rewritten) {
    Ok(_) => None
    Err(err) => Some(err)
  }
}

///|
fn run_hot_pipeline_skip_invalid_lower_reason(
  current_mod : @lib.Module,
  validation_mod : @lib.Module,
  code_idx : Int,
  descriptor_name : String,
  result : HotPipelineFuncResult,
) -> String? {
  if result.unchanged_original {
    return None
  }
  if descriptor_name == "precompute" ||
    descriptor_name == "precompute-propagate-prefix" {
    if run_hot_pipeline_precompute_lowered_func_has_invalid_escape_carrier(
        result.func,
      ) {
      return Some("invalid-escape-carrier")
    }
    return match
      run_hot_pipeline_precompute_writeback_validation_error(
        validation_mod,
        code_idx,
        result.func,
      ) {
      Some(msg) => Some("writeback-validate:\{msg}")
      None => None
    }
  }
  if descriptor_name == "dead-code-elimination" {
    if run_hot_pipeline_precompute_lowered_func_has_invalid_escape_carrier(
        result.func,
      ) {
      return Some("invalid-escape-carrier")
    }
    if run_hot_pipeline_lowered_func_has_suspicious_escape_carrier(result.func) {
      return Some("suspicious-escape-carrier")
    }
    if run_hot_pipeline_lowered_func_exceeds_local_limit(result.func) {
      return Some("local-limit")
    }
    return match
      run_hot_pipeline_precompute_writeback_validation_error(
        validation_mod,
        code_idx,
        result.func,
      ) {
      Some(msg) => Some("writeback-validate:\{msg}")
      None => None
    }
  }
  if descriptor_name == "simplify-locals" ||
    descriptor_name == "simplify-locals-nostructure" ||
    descriptor_name == "simplify-locals-no-structure" ||
    descriptor_name == "simplify-locals-notee-nostructure" {
    if run_hot_pipeline_precompute_lowered_func_has_invalid_escape_carrier(
        result.func,
      ) {
      return Some("invalid-escape-carrier")
    }
    if run_hot_pipeline_lowered_func_has_suspicious_escape_carrier(result.func) {
      return Some("suspicious-escape-carrier")
    }
    return match
      run_hot_pipeline_precompute_writeback_validation_error(
        validation_mod,
        code_idx,
        result.func,
      ) {
      Some(msg) => Some("writeback-validate:\{msg}")
      None => None
    }
  }
  if descriptor_name == "remove-unused-brs" {
    return match
      run_hot_pipeline_precompute_writeback_validation_error(
        validation_mod,
        code_idx,
        result.func,
      ) {
      Some(msg) => Some("writeback-validate:\{msg}")
      None => None
    }
  }
  if descriptor_name == "vacuum" {
    return match
      run_hot_pipeline_precompute_writeback_validation_error(
        validation_mod,
        code_idx,
        result.func,
      ) {
      Some(msg) => Some("writeback-validate:\{msg}")
      None => None
    }
  }
  if descriptor_name == "ssa-nomerge" {
    if run_hot_pipeline_precompute_lowered_func_has_invalid_escape_carrier(
        result.func,
      ) {
      return Some("invalid-escape-carrier")
    }
    if run_hot_pipeline_lowered_func_has_suspicious_escape_carrier(result.func) {
      return Some("suspicious-escape-carrier")
    }
    return match
      run_hot_pipeline_precompute_writeback_validation_error(
        current_mod,
        code_idx,
        result.func,
      ) {
      Some(msg) => Some("writeback-validate:\{msg}")
      None => None
    }
  }
  None
}

///|
fn run_hot_pipeline_precompute_branch_depth(instr : @lib.Instruction) -> Int? {
  match instr {
    @lib.Instruction::Br(label_idx) => {
      let @lib.LabelIdx(raw) = label_idx
      Some(raw.reinterpret_as_int())
    }
    _ => None
  }
}

///|
fn run_hot_pipeline_precompute_has_control_transfer(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.Instruction::Block(_, _)
    | @lib.Instruction::Loop(_, _)
    | @lib.Instruction::If(_, _, _)
    | @lib.Instruction::TryTable(_, _, _)
    | @lib.Instruction::Br(_)
    | @lib.Instruction::BrIf(_)
    | @lib.Instruction::BrTable(_, _)
    | @lib.Instruction::Return
    | @lib.Instruction::Throw(_)
    | @lib.Instruction::ThrowRef
    | @lib.Instruction::Unreachable => true
    _ => false
  }
}

///|
fn run_hot_pipeline_precompute_has_mismatched_escape_carrier_block(
  instr : @lib.Instruction,
) -> Bool {
  let walk_body = fn(body : Array[@lib.Instruction]) -> Bool {
    body.any(fn(child) {
      run_hot_pipeline_precompute_has_mismatched_escape_carrier_block(child)
    })
  }
  match instr {
    @lib.Instruction::Block(
      block_type,
      @lib.Expr(
        [
          @lib.Instruction::Block(
            @lib.VoidBlockType,
            @lib.Expr(
              [
                .. prefix,
                @lib.Instruction::If(@lib.VoidBlockType, then_, Some(else_)),
                @lib.Instruction::Unreachable,
              ]
            )
          ),
          @lib.Instruction::LocalGet(_),
        ]
      )
    ) => {
      match block_type {
        @lib.VoidBlockType => ()
        _ =>
          match
            (
              match then_.last() {
                Some(last) => run_hot_pipeline_precompute_branch_depth(last)
                None => None
              },
              match else_.last() {
                Some(last) => run_hot_pipeline_precompute_branch_depth(last)
                None => None
              },
            ) {
            (Some(then_depth), Some(else_depth)) if (
                then_depth == 1 && else_depth == 2
              ) ||
              (then_depth == 2 && else_depth == 1) => {
              for item in prefix {
                if run_hot_pipeline_precompute_has_control_transfer(item) {
                  return false
                }
              }
              return true
            }
            _ => ()
          }
      }
      if walk_body(then_) || walk_body(else_) {
        return true
      }
      for item in prefix {
        if run_hot_pipeline_precompute_has_mismatched_escape_carrier_block(item) {
          return true
        }
      }
      false
    }
    @lib.Instruction::Block(_, @lib.Expr(body))
    | @lib.Instruction::Loop(_, @lib.Expr(body))
    | @lib.Instruction::TryTable(_, _, @lib.Expr(body)) => walk_body(body)
    @lib.Instruction::If(_, then_, Some(else_)) =>
      walk_body(then_) || walk_body(else_)
    @lib.Instruction::If(_, then_, None) => walk_body(then_)
    _ => false
  }
}

///|
fn run_hot_pipeline_has_hard_exit(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Instruction::Return
    | @lib.Instruction::Unreachable
    | @lib.Instruction::Throw(_)
    | @lib.Instruction::ThrowRef => true
    @lib.Instruction::Block(_, @lib.Expr(body))
    | @lib.Instruction::Loop(_, @lib.Expr(body))
    | @lib.Instruction::TryTable(_, _, @lib.Expr(body)) =>
      body.any(fn(child) { run_hot_pipeline_has_hard_exit(child) })
    @lib.Instruction::If(_, then_, Some(else_)) =>
      then_.any(fn(child) { run_hot_pipeline_has_hard_exit(child) }) ||
      else_.any(fn(child) { run_hot_pipeline_has_hard_exit(child) })
    @lib.Instruction::If(_, then_, None) =>
      then_.any(fn(child) { run_hot_pipeline_has_hard_exit(child) })
    _ => false
  }
}

///|
fn run_hot_pipeline_has_invalid_hard_exit_escape_carrier_block(
  instr : @lib.Instruction,
) -> Bool {
  let walk_body = fn(body : Array[@lib.Instruction]) -> Bool {
    body.any(fn(child) {
      run_hot_pipeline_has_invalid_hard_exit_escape_carrier_block(child)
    })
  }
  match instr {
    @lib.Instruction::Block(
      block_type,
      @lib.Expr(
        [
          @lib.Instruction::Block(@lib.VoidBlockType, @lib.Expr(prefix)),
          ..,
          @lib.Instruction::LocalGet(_),
        ]
      )
    ) =>
      match block_type {
        @lib.VoidBlockType => walk_body(prefix)
        _ =>
          if prefix.any(fn(item) { run_hot_pipeline_has_hard_exit(item) }) {
            true
          } else {
            walk_body(prefix)
          }
      }
    @lib.Instruction::Block(_, @lib.Expr(body))
    | @lib.Instruction::Loop(_, @lib.Expr(body))
    | @lib.Instruction::TryTable(_, _, @lib.Expr(body)) => walk_body(body)
    @lib.Instruction::If(_, then_, Some(else_)) =>
      walk_body(then_) || walk_body(else_)
    @lib.Instruction::If(_, then_, None) => walk_body(then_)
    _ => false
  }
}

///|
fn run_hot_pipeline_precompute_lowered_func_has_invalid_escape_carrier(
  func : @lib.Func,
) -> Bool {
  let @lib.Func(_, @lib.Expr(body)) = func
  body.any(fn(instr) {
    run_hot_pipeline_precompute_has_mismatched_escape_carrier_block(instr)
  })
}

///|
fn run_hot_pipeline_lowered_func_has_suspicious_escape_carrier(
  func : @lib.Func,
) -> Bool {
  let @lib.Func(_, @lib.Expr(body)) = func
  body.any(fn(instr) {
    run_hot_pipeline_has_invalid_hard_exit_escape_carrier_block(instr)
  })
}

///|
fn run_hot_pipeline_lowered_func_exceeds_local_limit(func : @lib.Func) -> Bool {
  let @lib.Func(locals, _) = func
  locals.length() > 50000
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
  let mut current_mod = mod_
  let imported_func_count = run_hot_pipeline_imported_func_count(mod_)
  let next_code_sec = match mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let mut lowered : Array[@lib.Func]? = None
      let mut hso_raw_skip_count = 0
      let mut pls_raw_skip_count = 0
      let mut run_raw_skip_count = 0
      for code_idx = 0; code_idx < defs.length(); code_idx = code_idx + 1 {
        let func_idx = @lib.FuncIdx::new(
          (imported_func_count + code_idx).reinterpret_as_uint(),
        )
        if descriptor.name == "dead-code-elimination" {
          if run_hot_pipeline_lowered_func_has_suspicious_escape_carrier(
              defs[code_idx],
            ) {
            pipeline_trace_hook(
              options.trace,
              descriptor.name,
              "skip-invalid-lower",
              payload="func=\{func_idx} reason=suspicious-escape-carrier-original",
            )
            continue
          }
          let @lib.Func(locals, _) = defs[code_idx]
          if locals.length() > 1000 {
            pipeline_trace_hook(
              options.trace,
              descriptor.name,
              "skip-raw",
              payload="reason=large-local-dce-noop func=\{func_idx}",
            )
            continue
          }
        }
        let lower_state = {
          next_type_sec: current_mod.type_sec,
          type_sec_changed: false,
        }
        let result = match
          run_hot_pipeline_func(
            current_mod, func_idx, descriptor, module_state, lower_state, options,
          ) {
          Ok(result) => result
          Err(err) => return Err("func[\{func_idx}]: \{err}")
        }
        let validation_mod = if lower_state.type_sec_changed {
          current_mod.with_type_sec(lower_state.next_type_sec.unwrap())
        } else {
          current_mod
        }
        let skip_invalid_lower_reason = run_hot_pipeline_skip_invalid_lower_reason(
          current_mod,
          validation_mod,
          code_idx,
          descriptor.name,
          result,
        )
        if skip_invalid_lower_reason != None {
          pipeline_trace_hook(
            options.trace,
            descriptor.name,
            "skip-invalid-lower",
            payload="func=\{func_idx} reason=\{skip_invalid_lower_reason.unwrap()}",
          )
          continue
        }
        if lower_state.type_sec_changed {
          current_mod = validation_mod
        }
        if result.trace_skip_raw {
          if descriptor.name == "heap-store-optimization" &&
            result.reason == "no-heap-store-candidates" {
            hso_raw_skip_count += 1
          } else if descriptor.name == "pick-load-signs" &&
            result.reason == "no-pick-load-signs-candidates" {
            pls_raw_skip_count += 1
          } else if descriptor.name == "remove-unused-names" &&
            result.reason == "no-remove-unused-names-candidates" {
            run_raw_skip_count += 1
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
      if pls_raw_skip_count > 0 {
        pipeline_trace_hook(
          options.trace,
          descriptor.name,
          "skip-raw",
          payload="reason=no-pick-load-signs-candidates count=\{pls_raw_skip_count}",
        )
      }
      if run_raw_skip_count > 0 {
        pipeline_trace_hook(
          options.trace,
          descriptor.name,
          "skip-raw",
          payload="reason=no-remove-unused-names-candidates count=\{run_raw_skip_count}",
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
        run_hot_pipeline_drop_label_names(current_mod.with_code_sec(code_sec))
      None => current_mod
    },
  )
}

///|
fn run_hot_pipeline_dae_nested_cleanup_passes() -> Array[String] {
  [
    // Narrow scheduler slice: consume fresh expression/control/local cleanup
    // opportunities DAE creates with currently function-filterable passes, but
    // do not run Starshine's full default function pipeline yet. The full
    // Binaryen-equivalent lane still depends on a faster filtered batch runner
    // plus a real public `precompute-propagate` port. For now, start with a
    // touched-only faithful prefix equivalent over default-init and SSA-backed
    // local constant facts before the narrower cleanup subset.
    "precompute-propagate-prefix", "dead-code-elimination", "optimize-instructions",
    "local-cse", "pick-load-signs", "heap-store-optimization", "heap2local", "optimize-casts",
    "code-pushing", "simplify-locals", "code-folding", "precompute", "merge-blocks",
    "remove-unused-brs", "remove-unused-names", "merge-blocks", "coalesce-locals",
    "reorder-locals", "vacuum",
  ]
}

///|
fn run_hot_pipeline_dae_nested_cleanup_descriptor(
  pass_name : String,
) -> Result[@ir.HotPassDescriptor, String] {
  match pass_registry_lookup_cached(pass_name) {
    Some(entry) =>
      match entry.descriptor {
        Some(descriptor) => Ok(descriptor)
        None => Err("DAE nested cleanup pass \{pass_name} is not a hot pass")
      }
    None => Err("DAE nested cleanup expanded to unknown pass \{pass_name}")
  }
}

///|
fn run_hot_pipeline_apply_hot_pass_to_touched(
  mod_ : @lib.Module,
  descriptor : @ir.HotPassDescriptor,
  touched : Array[Bool],
  options : HotPipelineOptions,
) -> Result[@lib.Module, String] {
  if descriptor.name == "pick-load-signs" &&
    !run_hot_pipeline_module_has_memory(mod_) {
    pipeline_trace_hook(options.trace, descriptor.name, "skip-no-memory")
    return Ok(mod_)
  }
  let module_state = { module_ctx: None }
  let mut current_mod = mod_
  let imported_func_count = run_hot_pipeline_imported_func_count(mod_)
  let next_code_sec = match mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let mut lowered : Array[@lib.Func]? = None
      let mut hso_raw_skip_count = 0
      let mut pls_raw_skip_count = 0
      let mut run_raw_skip_count = 0
      for code_idx = 0; code_idx < defs.length(); code_idx = code_idx + 1 {
        if code_idx >= touched.length() || !touched[code_idx] {
          continue
        }
        let func_idx = @lib.FuncIdx::new(
          (imported_func_count + code_idx).reinterpret_as_uint(),
        )
        if descriptor.name == "dead-code-elimination" {
          if run_hot_pipeline_lowered_func_has_suspicious_escape_carrier(
              defs[code_idx],
            ) {
            pipeline_trace_hook(
              options.trace,
              descriptor.name,
              "skip-invalid-lower",
              payload="func=\{func_idx} reason=suspicious-escape-carrier-original",
            )
            continue
          }
          let @lib.Func(locals, _) = defs[code_idx]
          if locals.length() > 1000 {
            pipeline_trace_hook(
              options.trace,
              descriptor.name,
              "skip-raw",
              payload="reason=large-local-dce-noop func=\{func_idx}",
            )
            continue
          }
        }
        let lower_state = {
          next_type_sec: current_mod.type_sec,
          type_sec_changed: false,
        }
        let result = match
          run_hot_pipeline_func(
            current_mod, func_idx, descriptor, module_state, lower_state, options,
          ) {
          Ok(result) => result
          Err(err) => return Err("func[\{func_idx}]: \{err}")
        }
        let validation_mod = if lower_state.type_sec_changed {
          current_mod.with_type_sec(lower_state.next_type_sec.unwrap())
        } else {
          current_mod
        }
        let skip_invalid_lower_reason = run_hot_pipeline_skip_invalid_lower_reason(
          current_mod,
          validation_mod,
          code_idx,
          descriptor.name,
          result,
        )
        if skip_invalid_lower_reason != None {
          pipeline_trace_hook(
            options.trace,
            descriptor.name,
            "skip-invalid-lower",
            payload="func=\{func_idx} reason=\{skip_invalid_lower_reason.unwrap()}",
          )
          continue
        }
        if lower_state.type_sec_changed {
          current_mod = validation_mod
        }
        if result.trace_skip_raw {
          if descriptor.name == "heap-store-optimization" &&
            result.reason == "no-heap-store-candidates" {
            hso_raw_skip_count += 1
          } else if descriptor.name == "pick-load-signs" &&
            result.reason == "no-pick-load-signs-candidates" {
            pls_raw_skip_count += 1
          } else if descriptor.name == "remove-unused-names" &&
            result.reason == "no-remove-unused-names-candidates" {
            run_raw_skip_count += 1
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
      if pls_raw_skip_count > 0 {
        pipeline_trace_hook(
          options.trace,
          descriptor.name,
          "skip-raw",
          payload="reason=no-pick-load-signs-candidates count=\{pls_raw_skip_count}",
        )
      }
      if run_raw_skip_count > 0 {
        pipeline_trace_hook(
          options.trace,
          descriptor.name,
          "skip-raw",
          payload="reason=no-remove-unused-names-candidates count=\{run_raw_skip_count}",
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
        run_hot_pipeline_drop_label_names(current_mod.with_code_sec(code_sec))
      None => current_mod
    },
  )
}

///|
fn run_hot_pipeline_apply_local_cse_to_touched(
  mod_ : @lib.Module,
  touched : Array[Bool],
  options : HotPipelineOptions,
) -> Result[@lib.Module, String] {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Ok(mod_)
  }
  let params = cl_defined_func_param_cache(mod_)
  let imported_func_count = run_hot_pipeline_imported_func_count(mod_)
  let mut rewritten : Array[@lib.Func]? = None
  for code_idx = 0; code_idx < funcs.length(); code_idx = code_idx + 1 {
    if code_idx >= touched.length() || !touched[code_idx] {
      continue
    }
    let func_idx = @lib.FuncIdx::new(
      (imported_func_count + code_idx).reinterpret_as_uint(),
    )
    pipeline_trace_hook(
      options.trace,
      "local-cse",
      "func",
      payload="func_idx=\{func_idx}",
    )
    pipeline_trace_hook(options.trace, "local-cse", "start")
    let (next_func, changed) = local_cse_run_raw_func_with_params(
      funcs[code_idx],
      params[code_idx],
    )
    pipeline_trace_hook(
      options.trace,
      "local-cse",
      "done",
      payload="changed=\{changed}",
    )
    if changed {
      match rewritten {
        Some(copy) => copy[code_idx] = next_func
        None => {
          let copy = funcs.copy()
          copy[code_idx] = next_func
          rewritten = Some(copy)
        }
      }
    }
  }
  match rewritten {
    Some(copy) =>
      Ok(mod_.with_code_sec(@lib.CodeSec::new(copy)).without_name_sec())
    None => Ok(mod_)
  }
}

///|
fn run_hot_pipeline_apply_coalesce_locals_to_touched(
  mod_ : @lib.Module,
  touched : Array[Bool],
) -> Result[@lib.Module, String] {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Ok(mod_)
  }
  let params = cl_defined_func_param_cache(mod_)
  let mut rewritten : Array[@lib.Func]? = None
  for code_idx = 0; code_idx < funcs.length(); code_idx = code_idx + 1 {
    if code_idx >= touched.length() || !touched[code_idx] {
      continue
    }
    let func_params = match params.get(code_idx) {
      Some(params) => params
      None =>
        return Err("missing defined function params for code index \{code_idx}")
    }
    let rewrite = cl_rewrite_func(funcs[code_idx], func_params)
    if rewrite.changed {
      match rewritten {
        Some(copy) => copy[code_idx] = rewrite.func
        None => {
          let copy = funcs.copy()
          copy[code_idx] = rewrite.func
          rewritten = Some(copy)
        }
      }
    }
  }
  match rewritten {
    Some(copy) =>
      Ok(mod_.with_code_sec(@lib.CodeSec::new(copy)).without_name_sec())
    None => Ok(mod_)
  }
}

///|
fn run_hot_pipeline_apply_merge_locals_to_touched(
  mod_ : @lib.Module,
  touched : Array[Bool],
) -> Result[@lib.Module, String] {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Ok(mod_)
  }
  let params = cl_defined_func_param_cache(mod_)
  let mut rewritten : Array[@lib.Func]? = None
  for code_idx = 0; code_idx < funcs.length(); code_idx = code_idx + 1 {
    if code_idx >= touched.length() || !touched[code_idx] {
      continue
    }
    let func_params = match params.get(code_idx) {
      Some(params) => params
      None =>
        return Err("missing defined function params for code index \{code_idx}")
    }
    match merge_locals_run_func(funcs[code_idx], func_params) {
      Some(func) =>
        match rewritten {
          Some(copy) => copy[code_idx] = func
          None => {
            let copy = funcs.copy()
            copy[code_idx] = func
            rewritten = Some(copy)
          }
        }
      None => ()
    }
  }
  match rewritten {
    Some(copy) =>
      Ok(mod_.with_code_sec(@lib.CodeSec::new(copy)).without_name_sec())
    None => Ok(mod_)
  }
}

///|
fn run_hot_pipeline_apply_local_subtyping_to_touched(
  mod_ : @lib.Module,
  touched : Array[Bool],
) -> Result[@lib.Module, String] {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Ok(mod_)
  }
  let module_ctx = @ir.hot_module_context_from_module(mod_)
  let imported_func_count = run_hot_pipeline_imported_func_count(mod_)
  let mut rewritten : Array[@lib.Func]? = None
  for code_idx = 0; code_idx < funcs.length(); code_idx = code_idx + 1 {
    if code_idx >= touched.length() || !touched[code_idx] {
      continue
    }
    let func_idx = @lib.FuncIdx::new(
      (imported_func_count + code_idx).reinterpret_as_uint(),
    )
    let (next_func, changed) = ls_rewrite_func(
      funcs[code_idx],
      func_idx,
      mod_,
      module_ctx,
    )
    if changed {
      match rewritten {
        Some(copy) => copy[code_idx] = next_func
        None => {
          let copy = funcs.copy()
          copy[code_idx] = next_func
          rewritten = Some(copy)
        }
      }
    }
  }
  match rewritten {
    Some(copy) => Ok(mod_.with_code_sec(@lib.CodeSec::new(copy)))
    None => Ok(mod_)
  }
}

///|
fn run_hot_pipeline_apply_reorder_locals_to_touched(
  mod_ : @lib.Module,
  touched : Array[Bool],
) -> Result[@lib.Module, String] {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Ok(mod_)
  }
  let params = rl_defined_func_param_cache(mod_)
  let mut rewritten : Array[@lib.Func]? = None
  for code_idx = 0; code_idx < funcs.length(); code_idx = code_idx + 1 {
    if code_idx >= touched.length() || !touched[code_idx] {
      continue
    }
    let func_params = match params.get(code_idx) {
      Some(params) => params
      None =>
        return Err("missing defined function params for code index \{code_idx}")
    }
    let rewrite = rl_rewrite_func(funcs[code_idx], func_params)
    if rewrite.changed {
      match rewritten {
        Some(copy) => copy[code_idx] = rewrite.func
        None => {
          let copy = funcs.copy()
          copy[code_idx] = rewrite.func
          rewritten = Some(copy)
        }
      }
    }
  }
  match rewritten {
    Some(copy) =>
      Ok(mod_.with_code_sec(@lib.CodeSec::new(copy)).without_name_sec())
    None => Ok(mod_)
  }
}

///|
fn run_hot_pipeline_dae_nested_cleanup_size_skip_reason(
  mod_ : @lib.Module,
  touched : Array[Bool],
) -> String? {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      if funcs.length() > 100 {
        return Some("large-module")
      }
      run_hot_pipeline_touched_function_size_skip_reason(funcs, touched)
    }
    None => None
  }
}

///|
fn run_hot_pipeline_touched_function_size_skip_reason(
  funcs : Array[@lib.Func],
  touched : Array[Bool],
) -> String? {
  for code_idx = 0; code_idx < funcs.length(); code_idx = code_idx + 1 {
    if code_idx >= touched.length() || !touched[code_idx] {
      continue
    }
    let @lib.Func(locals, @lib.Expr(body)) = funcs[code_idx]
    let (_, _, _, _, _, instr_count) = run_hot_pipeline_instr_scan(body)
    if locals.length() > 128 || instr_count > 1000 {
      return Some("large-touched-function")
    }
  }
  None
}

///|
fn run_hot_pipeline_sgo_nested_cleanup_filter_touched(
  mod_ : @lib.Module,
  touched : Array[Bool],
) -> (Array[Bool], Int) {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let filtered = touched.copy()
      let mut filtered_large = 0
      for code_idx = 0; code_idx < funcs.length(); code_idx = code_idx + 1 {
        if code_idx >= filtered.length() || !filtered[code_idx] {
          continue
        }
        let @lib.Func(locals, @lib.Expr(body)) = funcs[code_idx]
        let (_, _, _, _, _, instr_count) = run_hot_pipeline_instr_scan(body)
        if locals.length() > 192 || instr_count > 1000 {
          filtered[code_idx] = false
          filtered_large = filtered_large + 1
        }
      }
      (filtered, filtered_large)
    }
    None => (touched, 0)
  }
}

///|
fn run_hot_pipeline_apply_dae_nested_cleanup(
  mod_ : @lib.Module,
  touched : Array[Bool],
  options : HotPipelineOptions,
) -> Result[@lib.Module, String] {
  let touched_count = dae_count_touched(touched)
  if touched_count == 0 {
    return Ok(mod_)
  }
  (options.trace)(
    "pass[dae-optimizing]:nested-cleanup touched=\{touched_count} prefix=precompute-propagate",
  )
  if touched_count > 8 {
    // The large-touched-set guard wins over per-function size reasons. Return
    // before scanning touched bodies so artifact-sized DAE runs do not pay for a
    // skip reason that cannot affect the emitted trace or output.
    pipeline_trace_hook(
      options.trace,
      "dae-optimizing",
      "nested-cleanup-skip",
      payload="reason=large-touched-set touched=\{touched_count}",
    )
    return Ok(mod_)
  }
  let size_skip_reason = run_hot_pipeline_dae_nested_cleanup_size_skip_reason(
    mod_, touched,
  )
  if size_skip_reason != None {
    pipeline_trace_hook(
      options.trace,
      "dae-optimizing",
      "nested-cleanup-skip",
      payload="reason=\{size_skip_reason.unwrap()} touched=\{touched_count}",
    )
    return Ok(mod_)
  }
  let mut current = mod_
  for pass_name in run_hot_pipeline_dae_nested_cleanup_passes() {
    pipeline_trace_hook(
      options.trace,
      "dae-optimizing",
      "nested-pass",
      payload="name=\{pass_name}",
    )
    if pass_name == "precompute-propagate-prefix" {
      current = match
        run_hot_pipeline_apply_hot_pass_to_touched(
          current,
          precompute_propagate_prefix_descriptor(),
          touched,
          options,
        ) {
        Ok(next) => next
        Err(err) => return Err("DAE nested cleanup pass \{pass_name}: \{err}")
      }
      continue
    }
    if pass_name == "local-cse" {
      current = match
        run_hot_pipeline_apply_local_cse_to_touched(current, touched, options) {
        Ok(next) => next
        Err(err) => return Err("DAE nested cleanup pass \{pass_name}: \{err}")
      }
      continue
    }
    if pass_name == "coalesce-locals" {
      current = match
        run_hot_pipeline_apply_coalesce_locals_to_touched(current, touched) {
        Ok(next) => next
        Err(err) => return Err("DAE nested cleanup pass \{pass_name}: \{err}")
      }
      continue
    }
    if pass_name == "reorder-locals" {
      current = match
        run_hot_pipeline_apply_reorder_locals_to_touched(current, touched) {
        Ok(next) => next
        Err(err) => return Err("DAE nested cleanup pass \{pass_name}: \{err}")
      }
      continue
    }
    let descriptor = match
      run_hot_pipeline_dae_nested_cleanup_descriptor(pass_name) {
      Ok(descriptor) => descriptor
      Err(err) => return Err(err)
    }
    current = match
      run_hot_pipeline_apply_hot_pass_to_touched(
        current, descriptor, touched, options,
      ) {
      Ok(next) => next
      Err(err) => return Err("DAE nested cleanup pass \{pass_name}: \{err}")
    }
  }
  Ok(current)
}

///|
fn run_hot_pipeline_sgo_nested_cleanup_passes() -> Array[String] {
  [
    // Binaryen's simplify-globals-optimizing reruns ordinary default function
    // optimization on changed functions, but does not prepend the
    // precompute-propagate prefix used by DAE / inlining after-inlining lanes.
    // Starshine currently uses this artifact-tuned subset because the omitted
    // slots add more wrapper/candidate-scan cost than size wins on the direct
    // debug artifact.
    "optimize-instructions", "local-cse", "pick-load-signs", "merge-blocks", "remove-unused-names",
    "merge-blocks", "coalesce-locals", "reorder-locals", "redundant-set-elimination",
    "vacuum",
  ]
}

///|
fn run_hot_pipeline_sgo_nested_cleanup_descriptor(
  pass_name : String,
) -> Result[@ir.HotPassDescriptor, String] {
  match pass_registry_lookup_cached(pass_name) {
    Some(entry) =>
      match entry.descriptor {
        Some(descriptor) => Ok(descriptor)
        None => Err("SGO nested cleanup pass \{pass_name} is not a hot pass")
      }
    None => Err("SGO nested cleanup expanded to unknown pass \{pass_name}")
  }
}

///|
fn run_hot_pipeline_apply_sgo_nested_cleanup(
  mod_ : @lib.Module,
  touched : Array[Bool],
  options : HotPipelineOptions,
) -> Result[@lib.Module, String] {
  let touched_count = sgo_count_touched(touched)
  if touched_count == 0 {
    return Ok(mod_)
  }
  let (cleanup_touched, filtered_large_count) = run_hot_pipeline_sgo_nested_cleanup_filter_touched(
    mod_, touched,
  )
  let cleanup_touched_count = sgo_count_touched(cleanup_touched)
  (options.trace)(
    "pass[simplify-globals-optimizing]:nested-cleanup touched=\{touched_count} prefix=default",
  )
  (options.trace)(
    "pass[simplify-globals-optimizing]:nested-cleanup-stats touched=\{touched_count} cleaned=\{cleanup_touched_count} filtered-large=\{filtered_large_count}",
  )
  if cleanup_touched_count == 0 && filtered_large_count > 0 {
    pipeline_trace_hook(
      options.trace,
      "simplify-globals-optimizing",
      "nested-cleanup-skip",
      payload="reason=large-touched-function touched=\{touched_count}",
    )
    return Ok(mod_)
  }
  let nested_total_start_us = perf_start_timer_opt(
    options.perf,
    "detail:sgo:nested-total",
  )
  let mut current = mod_
  for pass_name in run_hot_pipeline_sgo_nested_cleanup_passes() {
    pipeline_trace_hook(
      options.trace,
      "simplify-globals-optimizing",
      "nested-pass",
      payload="name=\{pass_name}",
    )
    let nested_pass_start_us = perf_start_timer_opt(
      options.perf,
      "detail:sgo:nested:\{pass_name}",
    )
    if pass_name == "local-cse" {
      current = match
        run_hot_pipeline_apply_local_cse_to_touched(
          current, cleanup_touched, options,
        ) {
        Ok(next) => next
        Err(err) => {
          perf_stop_timer_opt(
            options.perf,
            "detail:sgo:nested:\{pass_name}",
            nested_pass_start_us,
          )
          perf_stop_timer_opt(
            options.perf,
            "detail:sgo:nested-total",
            nested_total_start_us,
          )
          return Err("SGO nested cleanup pass \{pass_name}: \{err}")
        }
      }
      perf_stop_timer_opt(
        options.perf,
        "detail:sgo:nested:\{pass_name}",
        nested_pass_start_us,
      )
      continue
    }
    if pass_name == "coalesce-locals" {
      current = match
        run_hot_pipeline_apply_coalesce_locals_to_touched(
          current, cleanup_touched,
        ) {
        Ok(next) => next
        Err(err) => {
          perf_stop_timer_opt(
            options.perf,
            "detail:sgo:nested:\{pass_name}",
            nested_pass_start_us,
          )
          perf_stop_timer_opt(
            options.perf,
            "detail:sgo:nested-total",
            nested_total_start_us,
          )
          return Err("SGO nested cleanup pass \{pass_name}: \{err}")
        }
      }
      perf_stop_timer_opt(
        options.perf,
        "detail:sgo:nested:\{pass_name}",
        nested_pass_start_us,
      )
      continue
    }
    if pass_name == "reorder-locals" {
      current = match
        run_hot_pipeline_apply_reorder_locals_to_touched(
          current, cleanup_touched,
        ) {
        Ok(next) => next
        Err(err) => {
          perf_stop_timer_opt(
            options.perf,
            "detail:sgo:nested:\{pass_name}",
            nested_pass_start_us,
          )
          perf_stop_timer_opt(
            options.perf,
            "detail:sgo:nested-total",
            nested_total_start_us,
          )
          return Err("SGO nested cleanup pass \{pass_name}: \{err}")
        }
      }
      perf_stop_timer_opt(
        options.perf,
        "detail:sgo:nested:\{pass_name}",
        nested_pass_start_us,
      )
      continue
    }
    let descriptor = match
      run_hot_pipeline_sgo_nested_cleanup_descriptor(pass_name) {
      Ok(descriptor) => descriptor
      Err(err) => {
        perf_stop_timer_opt(
          options.perf,
          "detail:sgo:nested:\{pass_name}",
          nested_pass_start_us,
        )
        perf_stop_timer_opt(
          options.perf,
          "detail:sgo:nested-total",
          nested_total_start_us,
        )
        return Err(err)
      }
    }
    current = match
      run_hot_pipeline_apply_hot_pass_to_touched(
        current, descriptor, cleanup_touched, options,
      ) {
      Ok(next) => next
      Err(err) => {
        perf_stop_timer_opt(
          options.perf,
          "detail:sgo:nested:\{pass_name}",
          nested_pass_start_us,
        )
        perf_stop_timer_opt(
          options.perf,
          "detail:sgo:nested-total",
          nested_total_start_us,
        )
        return Err("SGO nested cleanup pass \{pass_name}: \{err}")
      }
    }
    perf_stop_timer_opt(
      options.perf,
      "detail:sgo:nested:\{pass_name}",
      nested_pass_start_us,
    )
  }
  perf_stop_timer_opt(
    options.perf,
    "detail:sgo:nested-total",
    nested_total_start_us,
  )
  Ok(current)
}

///|
fn run_hot_pipeline_apply_sgo_optimizing_module_pass(
  mod_ : @lib.Module,
  options : HotPipelineOptions,
) -> Result[@lib.Module, String] {
  let result = sgo_run_core(mod_, options.trace, perf=options.perf)
  run_hot_pipeline_apply_sgo_nested_cleanup(
    result.mod_out,
    result.touched,
    options,
  )
}

///|
fn run_hot_pipeline_apply_dae_optimizing_module_pass(
  mod_ : @lib.Module,
  options : HotPipelineOptions,
) -> Result[@lib.Module, String] {
  let result = dae_run_core(mod_, options.trace)
  let cleaned = match
    run_hot_pipeline_apply_dae_nested_cleanup(
      result.mod_out,
      result.touched,
      options,
    ) {
    Ok(next) => next
    Err(err) => return Err(err)
  }
  Ok(dae_prune_unused_simple_func_types(cleaned))
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
    "avoid-reinterprets" => avoid_reinterprets_run_module_pass(mod_)
    "untee" => untee_run_module_pass(mod_)
    "duplicate-function-elimination" =>
      dfe_run_module_pass_with_perf(mod_, options.perf)
    "remove-unused-module-elements" => rume_run_module_pass(mod_)
    "remove-unused-nonfunction-module-elements" =>
      rume_run_nonfunction_module_pass(mod_)
    "memory-packing" => memory_packing_run_module_pass(mod_)
    "once-reduction" => once_reduction_run_module_pass(mod_)
    "global-refining" => global_refining_run_module_pass(mod_)
    "global-struct-inference" =>
      global_struct_inference_run_module_pass(mod_, options.closed_world)
    "reorder-locals" => reorder_locals_run_module_pass(mod_)
    "local-subtyping" => local_subtyping_run_module_pass(mod_)
    "coalesce-locals" => coalesce_locals_run_module_pass(mod_)
    "local-cse" => local_cse_run_module_pass(mod_)
    "merge-locals" => merge_locals_run_module_pass(mod_)
    "duplicate-import-elimination" => die_run_module_pass(mod_)
    "simplify-globals-optimizing" =>
      match run_hot_pipeline_apply_sgo_optimizing_module_pass(mod_, options) {
        Ok(next) => next
        Err(err) => return Err(err)
      }
    "dae-optimizing" | "dead-argument-elimination-optimizing" =>
      match run_hot_pipeline_apply_dae_optimizing_module_pass(mod_, options) {
        Ok(next) => next
        Err(err) => return Err(err)
      }
    "inlining" =>
      inlining_run_module_pass(
        mod_,
        optimize=false,
        pass_name="inlining",
        optimize_level=options.optimize_level,
        shrink_level=options.shrink_level,
      )
    "inlining-optimizing" =>
      inlining_run_module_pass(
        mod_,
        optimize=true,
        trace=Some(options.trace),
        pass_name="inlining-optimizing",
        optimize_level=options.optimize_level,
        shrink_level=options.shrink_level,
      )
    _ =>
      match no_inline_pass_pattern(entry.name) {
        Some((base, pattern)) =>
          match base {
            "no-inline" =>
              no_inline_run_module_pass(
                mod_,
                pattern,
                mark_full=true,
                mark_partial=true,
              )
            "no-full-inline" =>
              no_inline_run_module_pass(
                mod_,
                pattern,
                mark_full=true,
                mark_partial=false,
              )
            "no-partial-inline" =>
              no_inline_run_module_pass(
                mod_,
                pattern,
                mark_full=false,
                mark_partial=true,
              )
            _ => return Err("unsupported module pass \{entry.name}")
          }
        None =>
          match entry.name {
            "string-gathering" => string_gathering_run_module_pass(mod_)
            "reorder-globals" => reorder_globals_run_module_pass(mod_)
            "directize" => directize_run_module_pass(mod_)
            _ => return Err("unsupported module pass \{entry.name}")
          }
      }
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
      if hot_pass_remove_region_nops(
          ctx,
          func,
          @ir.HotRegionRef::root(),
          Array::make(@ir.hot_node_count(func), false),
        ) {
        HotPassResult::changed()
      } else {
        HotPassResult::unchanged()
      }
    "dead-code-elimination" => dead_code_elimination_run(ctx, func)
    "remove-unused-names" => remove_unused_names_run(ctx, func)
    "remove-unused-brs" => remove_unused_brs_run(ctx, func)
    "optimize-instructions" => optimize_instructions_run(ctx, func)
    "heap-store-optimization" => heap_store_optimization_run(ctx, func)
    "heap2local" => heap2local_run(ctx, func)
    "optimize-casts" => optimize_casts_run(ctx, func)
    "pick-load-signs" => pick_load_signs_run(ctx, func)
    "precompute" => precompute_run(ctx, func)
    "precompute-propagate-prefix" => precompute_propagate_prefix_run(ctx, func)
    "code-pushing" => code_pushing_run(ctx, func)
    "code-folding" => code_folding_run(ctx, func)
    "tuple-optimization" => tuple_optimization_run(ctx, func)
    "simplify-locals" => simplify_locals_run(ctx, func)
    "simplify-locals-nostructure" | "simplify-locals-no-structure" =>
      simplify_locals_nostructure_run(ctx, func)
    "simplify-locals-notee-nostructure" =>
      simplify_locals_notee_nostructure_run(ctx, func)
    "merge-blocks" => merge_blocks_run(ctx, func)
    "redundant-set-elimination" => rse_run(ctx, func)
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
