///|
fn ssa_test_first_defined_func(
  mod_ : @lib.Module,
) -> (@lib.Locals, Array[@lib.Instruction]) raise {
  ssa_test_defined_func(mod_, 0)
}

///|
fn ssa_test_defined_func(
  mod_ : @lib.Module,
  defined_idx : Int,
) -> (@lib.Locals, Array[@lib.Instruction]) raise {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs.get(defined_idx) {
        Some(@lib.Func(locals, @lib.Expr(instrs))) => (locals, instrs)
        None => fail("expected defined function \{defined_idx}")
      }
    None => fail("expected code section")
  }
}

///|
fn ssa_test_type_count(mod_ : @lib.Module) -> Int raise {
  match mod_.type_sec {
    Some(@lib.TypeSec(types)) => types.length()
    None => fail("expected type section")
  }
}

///|
fn ssa_test_local_types(locals : @lib.Locals) -> Array[@lib.ValType] {
  let types : Array[@lib.ValType] = []
  for idx = 0; idx < locals.length(); idx = idx + 1 {
    types.push(locals.get(idx))
  }
  types
}

///|
fn ssa_test_collect_local_write_indices(
  instrs : Array[@lib.Instruction],
  out : Array[UInt],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.LocalSet(@lib.LocalIdx(idx)) | @lib.LocalTee(@lib.LocalIdx(idx)) =>
        out.push(idx)
      @lib.If(_, then_instrs, else_instrs) => {
        ssa_test_collect_local_write_indices(then_instrs, out)
        match else_instrs {
          Some(else_body) =>
            ssa_test_collect_local_write_indices(else_body, out)
          None => ()
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        ssa_test_collect_local_write_indices(body, out)
      _ => ()
    }
  }
}

///|
fn ssa_test_local_write_indices(
  instrs : Array[@lib.Instruction],
) -> Array[UInt] {
  let out : Array[UInt] = []
  ssa_test_collect_local_write_indices(instrs, out)
  out
}

///|
fn ssa_test_collect_local_set_indices(
  instrs : Array[@lib.Instruction],
  out : Array[UInt],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.LocalSet(@lib.LocalIdx(idx)) => out.push(idx)
      @lib.If(_, then_instrs, else_instrs) => {
        ssa_test_collect_local_set_indices(then_instrs, out)
        match else_instrs {
          Some(else_body) => ssa_test_collect_local_set_indices(else_body, out)
          None => ()
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        ssa_test_collect_local_set_indices(body, out)
      _ => ()
    }
  }
}

///|
fn ssa_test_local_set_indices(instrs : Array[@lib.Instruction]) -> Array[UInt] {
  let out : Array[UInt] = []
  ssa_test_collect_local_set_indices(instrs, out)
  out
}

///|
fn ssa_test_collect_local_tee_indices(
  instrs : Array[@lib.Instruction],
  out : Array[UInt],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.LocalTee(@lib.LocalIdx(idx)) => out.push(idx)
      @lib.If(_, then_instrs, else_instrs) => {
        ssa_test_collect_local_tee_indices(then_instrs, out)
        match else_instrs {
          Some(else_body) => ssa_test_collect_local_tee_indices(else_body, out)
          None => ()
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        ssa_test_collect_local_tee_indices(body, out)
      _ => ()
    }
  }
}

///|
fn ssa_test_local_tee_indices(instrs : Array[@lib.Instruction]) -> Array[UInt] {
  let out : Array[UInt] = []
  ssa_test_collect_local_tee_indices(instrs, out)
  out
}

///|
fn ssa_test_root_i32_add_local_tee_targets(
  instrs : Array[@lib.Instruction],
) -> Array[UInt] {
  let out : Array[UInt] = []
  let mut previous_was_i32_add = false
  for instr in instrs {
    match instr {
      @lib.I32Add => previous_was_i32_add = true
      @lib.LocalTee(@lib.LocalIdx(idx)) => {
        if previous_was_i32_add {
          out.push(idx)
        }
        previous_was_i32_add = false
      }
      _ => previous_was_i32_add = false
    }
  }
  out
}

///|
fn ssa_test_root_i32_and_local_tee_targets(
  instrs : Array[@lib.Instruction],
) -> Array[UInt] {
  let out : Array[UInt] = []
  let mut previous_was_i32_and = false
  for instr in instrs {
    match instr {
      @lib.I32And => previous_was_i32_and = true
      @lib.LocalTee(@lib.LocalIdx(idx)) => {
        if previous_was_i32_and {
          out.push(idx)
        }
        previous_was_i32_and = false
      }
      _ => previous_was_i32_and = false
    }
  }
  out
}

///|
fn ssa_test_collect_i32_sub_local_set_targets(
  instrs : Array[@lib.Instruction],
  out : Array[UInt],
) -> Unit {
  let mut previous_was_i32_sub = false
  for instr in instrs {
    match instr {
      @lib.I32Sub => previous_was_i32_sub = true
      @lib.LocalSet(@lib.LocalIdx(idx)) => {
        if previous_was_i32_sub {
          out.push(idx)
        }
        previous_was_i32_sub = false
      }
      @lib.If(_, then_instrs, else_instrs) => {
        previous_was_i32_sub = false
        ssa_test_collect_i32_sub_local_set_targets(then_instrs, out)
        match else_instrs {
          Some(else_body) =>
            ssa_test_collect_i32_sub_local_set_targets(else_body, out)
          None => ()
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) => {
        previous_was_i32_sub = false
        ssa_test_collect_i32_sub_local_set_targets(body, out)
      }
      _ => previous_was_i32_sub = false
    }
  }
}

///|
fn ssa_test_i32_sub_local_set_targets(
  instrs : Array[@lib.Instruction],
) -> Array[UInt] {
  let out : Array[UInt] = []
  ssa_test_collect_i32_sub_local_set_targets(instrs, out)
  out
}

///|
fn ssa_test_has_ssa_temp_local_writes(
  instrs : Array[@lib.Instruction],
  canonical_local : UInt,
) -> Bool {
  ssa_test_local_write_indices(instrs).any(fn(idx) { idx > canonical_local })
}

///|
fn ssa_nomerge_test_plan(func : @ir.HotFunc) -> SsaNoMergeRewritePlan {
  let graph = @ir.local_graph_build(func, @ir.cfg_build(func))
  ssa_nomerge_build_rewrite_plan(func, graph)
}

///|
fn ssa_nomerge_test_write_decision(
  plan : SsaNoMergeRewritePlan,
  write_id : @ir.NodeId,
) -> SsaNoMergeWriteDecision? {
  for rewrite in plan.write_rewrites {
    if rewrite.write_id == write_id {
      return Some(rewrite.decision)
    }
  }
  None
}

///|
fn ssa_nomerge_test_get_decision(
  plan : SsaNoMergeRewritePlan,
  get_id : @ir.NodeId,
) -> SsaNoMergeGetDecision? {
  for rewrite in plan.get_rewrites {
    if rewrite.get_id == get_id {
      return Some(rewrite.decision)
    }
  }
  None
}

///|
struct SsaNoMergeShadowSummary {
  plan_freshen_writes : Int
  plan_keep_writes : Int
  plan_retarget_gets : Int
  plan_default_gets : Int
  plan_keep_gets : Int
  current_added_body_locals : Int
  current_local_gets : Array[UInt]
} derive(Debug)

///|
struct SsaNoMergeMixedPlanSummary {
  plan_freshen_writes : Int
  plan_keep_writes : Int
  plan_retarget_gets : Int
  plan_default_gets : Int
  plan_keep_gets : Int
} derive(Debug)

///|
fn ssa_nomerge_test_count_plan_freshen_writes(
  plan : SsaNoMergeRewritePlan,
) -> Int {
  let mut count = 0
  for rewrite in plan.write_rewrites {
    match rewrite.decision {
      SsaNoMergeWriteDecision::Freshen(_) => count = count + 1
      SsaNoMergeWriteDecision::KeepCanonical => ()
    }
  }
  count
}

///|
fn ssa_nomerge_test_count_plan_keep_writes(plan : SsaNoMergeRewritePlan) -> Int {
  let mut count = 0
  for rewrite in plan.write_rewrites {
    match rewrite.decision {
      SsaNoMergeWriteDecision::KeepCanonical => count = count + 1
      SsaNoMergeWriteDecision::Freshen(_) => ()
    }
  }
  count
}

///|
fn ssa_nomerge_test_count_plan_retarget_gets(
  plan : SsaNoMergeRewritePlan,
) -> Int {
  let mut count = 0
  for rewrite in plan.get_rewrites {
    match rewrite.decision {
      SsaNoMergeGetDecision::Retarget(_) => count = count + 1
      _ => ()
    }
  }
  count
}

///|
fn ssa_nomerge_test_count_plan_default_gets(
  plan : SsaNoMergeRewritePlan,
) -> Int {
  let mut count = 0
  for rewrite in plan.get_rewrites {
    match rewrite.decision {
      SsaNoMergeGetDecision::MaterializeDefault => count = count + 1
      _ => ()
    }
  }
  count
}

///|
fn ssa_nomerge_test_count_plan_keep_gets(plan : SsaNoMergeRewritePlan) -> Int {
  let mut count = 0
  for rewrite in plan.get_rewrites {
    match rewrite.decision {
      SsaNoMergeGetDecision::KeepCanonical => count = count + 1
      _ => ()
    }
  }
  count
}

///|
fn ssa_nomerge_test_collect_local_get_indices(
  instrs : Array[@lib.Instruction],
  out : Array[UInt],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.LocalGet(@lib.LocalIdx(idx)) => out.push(idx)
      @lib.If(_, then_instrs, else_instrs) => {
        ssa_nomerge_test_collect_local_get_indices(then_instrs, out)
        match else_instrs {
          Some(else_body) =>
            ssa_nomerge_test_collect_local_get_indices(else_body, out)
          None => ()
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        ssa_nomerge_test_collect_local_get_indices(body, out)
      _ => ()
    }
  }
}

///|
fn ssa_nomerge_test_local_get_indices(
  instrs : Array[@lib.Instruction],
) -> Array[UInt] {
  let out : Array[UInt] = []
  ssa_nomerge_test_collect_local_get_indices(instrs, out)
  out
}

///|
fn ssa_nomerge_test_has_brtable_default_zero_drop(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for idx = 0; idx + 2 < instrs.length(); idx = idx + 1 {
    match instrs[idx] {
      @lib.Block(_, @lib.Expr(body)) if ssa_test_instrs_have_br_table(body) =>
        match (instrs[idx + 1], instrs[idx + 2]) {
          (@lib.I32Const(@lib.I32(0)), @lib.Drop) => return true
          _ => ()
        }
      _ => ()
    }
  }
  false
}

///|
fn ssa_nomerge_test_shadow_summary_from_wat(
  source : String,
) -> SsaNoMergeShadowSummary raise {
  let input = pass_test_module_from_wat(source)
  let (input_locals, _) = try! ssa_test_first_defined_func(input)
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  @ir.hot_verify_all_or_abort(func)
  let plan = ssa_nomerge_test_plan(func)
  let optimized = match pass_test_run_pipeline(source, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected ssa-nomerge shadow pipeline success, got \{err}")
  }
  let (optimized_locals, optimized_instrs) = try! ssa_test_first_defined_func(
    optimized,
  )
  {
    plan_freshen_writes: ssa_nomerge_test_count_plan_freshen_writes(plan),
    plan_keep_writes: ssa_nomerge_test_count_plan_keep_writes(plan),
    plan_retarget_gets: ssa_nomerge_test_count_plan_retarget_gets(plan),
    plan_default_gets: ssa_nomerge_test_count_plan_default_gets(plan),
    plan_keep_gets: ssa_nomerge_test_count_plan_keep_gets(plan),
    current_added_body_locals: optimized_locals.length() - input_locals.length(),
    current_local_gets: ssa_nomerge_test_local_get_indices(optimized_instrs),
  }
}

///|
fn ssa_nomerge_test_mixed_plan_summary_from_wat(
  source : String,
  original_local : @ir.LocalId,
) -> SsaNoMergeMixedPlanSummary {
  let input = pass_test_module_from_wat(source)
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  @ir.hot_verify_all_or_abort(func)
  let plan = ssa_nomerge_test_plan(func)
  let mut freshen_writes = 0
  let mut keep_writes = 0
  for rewrite in plan.write_rewrites {
    if rewrite.original_local == original_local {
      match rewrite.decision {
        SsaNoMergeWriteDecision::Freshen(_) =>
          freshen_writes = freshen_writes + 1
        SsaNoMergeWriteDecision::KeepCanonical => keep_writes = keep_writes + 1
      }
    }
  }
  let mut retarget_gets = 0
  let mut default_gets = 0
  let mut keep_gets = 0
  for rewrite in plan.get_rewrites {
    if rewrite.original_local == original_local {
      match rewrite.decision {
        SsaNoMergeGetDecision::Retarget(_) => retarget_gets = retarget_gets + 1
        SsaNoMergeGetDecision::MaterializeDefault =>
          default_gets = default_gets + 1
        SsaNoMergeGetDecision::KeepCanonical => keep_gets = keep_gets + 1
      }
    }
  }
  {
    plan_freshen_writes: freshen_writes,
    plan_keep_writes: keep_writes,
    plan_retarget_gets: retarget_gets,
    plan_default_gets: default_gets,
    plan_keep_gets: keep_gets,
  }
}

///|
test "ssa-nomerge shadow matches current straight-line and default families" {
  let already = try! ssa_nomerge_test_shadow_summary_from_wat(
    "(module (func (result i32) (local i32) i32.const 5 local.set 0 local.get 0))",
  )
  @debug.assert_eq(already.plan_freshen_writes, 0)
  @debug.assert_eq(already.plan_retarget_gets, 0)
  @debug.assert_eq(already.plan_default_gets, 0)
  @debug.assert_eq(already.current_added_body_locals, 0)
  @debug.assert_eq(already.current_local_gets, [0U])

  let overwritten = try! ssa_nomerge_test_shadow_summary_from_wat(
    "(module (func (result f64) (local f64) f64.const 69 local.tee 0 drop f64.const 39 local.tee 0 drop local.get 0))",
  )
  @debug.assert_eq(overwritten.plan_freshen_writes, 2)
  @debug.assert_eq(overwritten.plan_retarget_gets, 1)
  @debug.assert_eq(overwritten.plan_default_gets, 0)
  @debug.assert_eq(overwritten.current_added_body_locals, 2)
  @debug.assert_eq(overwritten.current_local_gets, [2U])

  let body_default = try! ssa_nomerge_test_shadow_summary_from_wat(
    "(module (func (result i32) (local i32) block i32.const 0 br_table 0 0 end local.get 0))",
  )
  @debug.assert_eq(body_default.plan_freshen_writes, 0)
  @debug.assert_eq(body_default.plan_retarget_gets, 0)
  @debug.assert_eq(body_default.plan_default_gets, 1)
  @debug.assert_eq(body_default.current_added_body_locals, 0)
  @debug.assert_eq(body_default.current_local_gets, [])
}

///|
test "ssa-nomerge planner classifies mixed fresh and canonical merge regions" {
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 10
    #|    local.set 1
    #|    local.get 1
    #|    drop
    #|    local.get 0
    #|    if
    #|      i32.const 20
    #|      local.set 1
    #|    else
    #|      i32.const 30
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    drop
    #|    i32.const 40
    #|    local.set 1
    #|    local.get 1))
    #|)
  let mixed = ssa_nomerge_test_mixed_plan_summary_from_wat(source, 1)

  @debug.assert_eq(mixed.plan_freshen_writes, 2)
  @debug.assert_eq(mixed.plan_keep_writes, 2)
  @debug.assert_eq(mixed.plan_retarget_gets, 2)
  @debug.assert_eq(mixed.plan_keep_gets, 1)
  @debug.assert_eq(mixed.plan_default_gets, 0)
}

///|
test "ssa-nomerge shadow records branch-local already-SSA alignment" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if
    #|      i32.const 7
    #|      local.set 1
    #|      local.get 1
    #|      drop
    #|    else
    #|      nop
    #|    end))
    #|)
  let shadow = try! ssa_nomerge_test_shadow_summary_from_wat(source)

  @debug.assert_eq(shadow.plan_freshen_writes, 0)
  @debug.assert_eq(shadow.plan_keep_writes, 1)
  @debug.assert_eq(shadow.plan_retarget_gets, 0)
  @debug.assert_eq(shadow.current_added_body_locals, 0)
  @debug.assert_eq(shadow.current_local_gets, [0U, 1U])
}

///|
test "ssa-nomerge planner keeps already-ssa straight-line locals canonical" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let set = @ir.hot_build_local_set(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(7)),
  )
  let get = @ir.hot_build_local_get(func, 0)
  @ir.hot_root_append(func, set)
  @ir.hot_root_append(func, @ir.hot_build_drop(func, get))

  let plan = ssa_nomerge_test_plan(func)

  @debug.assert_eq(plan.write_rewrites.length(), 1)
  @debug.assert_eq(plan.get_rewrites.length(), 1)
  @debug.assert_eq(
    ssa_nomerge_test_write_decision(plan, set),
    Some(SsaNoMergeWriteDecision::KeepCanonical),
  )
  @debug.assert_eq(
    ssa_nomerge_test_get_decision(plan, get),
    Some(SsaNoMergeGetDecision::KeepCanonical),
  )
}

///|
test "ssa-nomerge planner freshens overwritten writes and retargets single-source gets" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let first_set = @ir.hot_build_local_set(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  )
  let first_get = @ir.hot_build_local_get(func, 0)
  let second_set = @ir.hot_build_local_set(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(2)),
  )
  let second_get = @ir.hot_build_local_get(func, 0)
  @ir.hot_root_append(func, first_set)
  @ir.hot_root_append(func, @ir.hot_build_drop(func, first_get))
  @ir.hot_root_append(func, second_set)
  @ir.hot_root_append(func, @ir.hot_build_drop(func, second_get))

  let plan = ssa_nomerge_test_plan(func)

  @debug.assert_eq(plan.write_rewrites.length(), 2)
  @debug.assert_eq(plan.get_rewrites.length(), 2)
  @debug.assert_eq(
    ssa_nomerge_test_write_decision(plan, first_set),
    Some(SsaNoMergeWriteDecision::Freshen(1)),
  )
  @debug.assert_eq(
    ssa_nomerge_test_write_decision(plan, second_set),
    Some(SsaNoMergeWriteDecision::Freshen(2)),
  )
  @debug.assert_eq(
    ssa_nomerge_test_get_decision(plan, first_get),
    Some(SsaNoMergeGetDecision::Retarget(1)),
  )
  @debug.assert_eq(
    ssa_nomerge_test_get_decision(plan, second_get),
    Some(SsaNoMergeGetDecision::Retarget(2)),
  )
}

///|
test "ssa-nomerge planner materializes body defaults and keeps param entries" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let param_get = @ir.hot_build_local_get(func, 0)
  let default_get = @ir.hot_build_local_get(func, 1)
  @ir.hot_root_append(func, @ir.hot_build_drop(func, param_get))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, default_get))

  let plan = ssa_nomerge_test_plan(func)

  @debug.assert_eq(plan.write_rewrites.length(), 0)
  @debug.assert_eq(plan.get_rewrites.length(), 2)
  @debug.assert_eq(
    ssa_nomerge_test_get_decision(plan, param_get),
    Some(SsaNoMergeGetDecision::KeepCanonical),
  )
  @debug.assert_eq(
    ssa_nomerge_test_get_decision(plan, default_get),
    Some(SsaNoMergeGetDecision::MaterializeDefault),
  )
}

///|
test "ssa-nomerge planner keeps merge-feeding branch writes canonical" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let then_set = @ir.hot_build_local_set(
    func,
    1,
    @ir.hot_build_const_i32(func, @lib.I32(7)),
  )
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 0),
    [then_set],
    else_body=Some([@ir.hot_build_nop(func)]),
  )
  let merge_get = @ir.hot_build_local_get(func, 1)
  @ir.hot_root_append(func, if_id)
  @ir.hot_root_append(func, @ir.hot_build_drop(func, merge_get))

  let plan = ssa_nomerge_test_plan(func)

  @debug.assert_eq(plan.write_rewrites.length(), 1)
  @debug.assert_eq(
    ssa_nomerge_test_write_decision(plan, then_set),
    Some(SsaNoMergeWriteDecision::KeepCanonical),
  )
  @debug.assert_eq(
    ssa_nomerge_test_get_decision(plan, merge_get),
    Some(SsaNoMergeGetDecision::KeepCanonical),
  )
}

///|
test "ssa-nomerge planner classifies loop-carried no-read set and dead tee writes" {
  let loop_func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let entry_set = @ir.hot_build_local_set(
    loop_func,
    0,
    @ir.hot_build_const_i32(loop_func, @lib.I32(1)),
  )
  let loop_get = @ir.hot_build_local_get(loop_func, 0)
  let loop_set = @ir.hot_build_local_set(
    loop_func,
    0,
    @ir.hot_build_const_i32(loop_func, @lib.I32(2)),
  )
  let loop_id = @ir.hot_build_loop(loop_func, @lib.BlockType::void_(), [])
  let label = @ir.hot_control_node_label(loop_func, loop_id)
  @ir.hot_region_replace_body(
    loop_func,
    @ir.hot_region_body_ref(loop_func, loop_id),
    [
      @ir.hot_build_drop(loop_func, loop_get),
      loop_set,
      @ir.hot_build_br_if(
        loop_func,
        label,
        @ir.hot_build_const_i32(loop_func, @lib.I32(1)),
      ),
    ],
  )
  @ir.hot_root_append(loop_func, entry_set)
  @ir.hot_root_append(loop_func, loop_id)

  let loop_plan = ssa_nomerge_test_plan(loop_func)

  @debug.assert_eq(
    ssa_nomerge_test_write_decision(loop_plan, entry_set),
    Some(SsaNoMergeWriteDecision::KeepCanonical),
  )
  @debug.assert_eq(
    ssa_nomerge_test_write_decision(loop_plan, loop_set),
    Some(SsaNoMergeWriteDecision::KeepCanonical),
  )
  @debug.assert_eq(
    ssa_nomerge_test_get_decision(loop_plan, loop_get),
    Some(SsaNoMergeGetDecision::KeepCanonical),
  )

  let overwritten_before_loop_func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let preloop_set = @ir.hot_build_local_set(
    overwritten_before_loop_func,
    0,
    @ir.hot_build_const_i32(overwritten_before_loop_func, @lib.I32(7)),
  )
  let preloop_get = @ir.hot_build_local_get(overwritten_before_loop_func, 0)
  let loop_entry_set = @ir.hot_build_local_set(
    overwritten_before_loop_func,
    0,
    @ir.hot_build_const_i32(overwritten_before_loop_func, @lib.I32(0)),
  )
  let carried_get = @ir.hot_build_local_get(overwritten_before_loop_func, 0)
  let carried_set = @ir.hot_build_local_set(
    overwritten_before_loop_func,
    0,
    @ir.hot_build_const_i32(overwritten_before_loop_func, @lib.I32(2)),
  )
  let carried_loop = @ir.hot_build_loop(
    overwritten_before_loop_func,
    @lib.BlockType::void_(),
    [],
  )
  let carried_label = @ir.hot_control_node_label(
    overwritten_before_loop_func, carried_loop,
  )
  @ir.hot_region_replace_body(
    overwritten_before_loop_func,
    @ir.hot_region_body_ref(overwritten_before_loop_func, carried_loop),
    [
      @ir.hot_build_drop(overwritten_before_loop_func, carried_get),
      carried_set,
      @ir.hot_build_br_if(
        overwritten_before_loop_func,
        carried_label,
        @ir.hot_build_const_i32(overwritten_before_loop_func, @lib.I32(1)),
      ),
    ],
  )
  @ir.hot_root_append(overwritten_before_loop_func, preloop_set)
  @ir.hot_root_append(
    overwritten_before_loop_func,
    @ir.hot_build_drop(overwritten_before_loop_func, preloop_get),
  )
  @ir.hot_root_append(overwritten_before_loop_func, loop_entry_set)
  @ir.hot_root_append(overwritten_before_loop_func, carried_loop)

  let overwritten_before_loop_plan = ssa_nomerge_test_plan(
    overwritten_before_loop_func,
  )

  @debug.assert_eq(
    ssa_nomerge_test_write_decision(overwritten_before_loop_plan, preloop_set),
    Some(SsaNoMergeWriteDecision::Freshen(1)),
  )
  @debug.assert_eq(
    ssa_nomerge_test_get_decision(overwritten_before_loop_plan, preloop_get),
    Some(SsaNoMergeGetDecision::Retarget(1)),
  )
  @debug.assert_eq(
    ssa_nomerge_test_write_decision(
      overwritten_before_loop_plan, loop_entry_set,
    ),
    Some(SsaNoMergeWriteDecision::KeepCanonical),
  )
  @debug.assert_eq(
    ssa_nomerge_test_write_decision(overwritten_before_loop_plan, carried_set),
    Some(SsaNoMergeWriteDecision::KeepCanonical),
  )
  @debug.assert_eq(
    ssa_nomerge_test_get_decision(overwritten_before_loop_plan, carried_get),
    Some(SsaNoMergeGetDecision::KeepCanonical),
  )

  let dead_set_func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let dead_set = @ir.hot_build_local_set(
    dead_set_func,
    0,
    @ir.hot_build_const_i32(dead_set_func, @lib.I32(3)),
  )
  @ir.hot_root_append(dead_set_func, dead_set)

  let dead_set_plan = ssa_nomerge_test_plan(dead_set_func)

  @debug.assert_eq(dead_set_plan.write_rewrites.length(), 1)
  @debug.assert_eq(
    ssa_nomerge_test_write_decision(dead_set_plan, dead_set),
    Some(SsaNoMergeWriteDecision::Freshen(1)),
  )

  let tee_func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let tee = @ir.hot_build_local_tee(
    tee_func,
    0,
    @ir.hot_build_const_i32(tee_func, @lib.I32(4)),
  )
  @ir.hot_root_append(tee_func, @ir.hot_build_drop(tee_func, tee))

  let tee_plan = ssa_nomerge_test_plan(tee_func)

  @debug.assert_eq(tee_plan.write_rewrites.length(), 1)
  @debug.assert_eq(
    ssa_nomerge_test_write_decision(tee_plan, tee),
    Some(SsaNoMergeWriteDecision::Freshen(1)),
  )
}

///|
fn ssa_test_instrs_have_ref_null_type(
  instrs : Array[@lib.Instruction],
  expected : @lib.RefType,
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.RefNull(rt) => if rt == expected { return true }
      @lib.If(_, then_body, else_body) => {
        if ssa_test_instrs_have_ref_null_type(then_body, expected) {
          return true
        }
        match else_body {
          Some(else_body) =>
            if ssa_test_instrs_have_ref_null_type(else_body, expected) {
              return true
            }
          None => ()
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_ref_null_type(body, expected) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn ssa_test_instrs_have_local_get(instrs : Array[@lib.Instruction]) -> Bool {
  for instr in instrs {
    match instr {
      @lib.LocalGet(_) => return true
      @lib.If(_, then_body, else_body) => {
        if ssa_test_instrs_have_local_get(then_body) {
          return true
        }
        match else_body {
          Some(else_body) =>
            if ssa_test_instrs_have_local_get(else_body) {
              return true
            }
          None => ()
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_local_get(body) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn ssa_test_assert_no_local_gets(
  instrs : Array[@lib.Instruction],
  context : String,
) -> Unit raise {
  let text = instrs.to_string()
  assert_false(
    ssa_test_instrs_have_local_get(instrs),
    msg="\{context}; output still had local.get: \{text}",
  )
}

///|
fn ssa_test_assert_default_read_replaced_with_ref_null(
  instrs : Array[@lib.Instruction],
  expected : @lib.RefType,
  context : String,
) -> Unit raise {
  let text = instrs.to_string()
  assert_true(
    ssa_test_instrs_have_ref_null_type(instrs, expected),
    msg="\{context}; expected ref.null \{expected}, output: \{text}",
  )
}

///|
fn ssa_test_instrs_have_br_on_null(instrs : Array[@lib.Instruction]) -> Bool {
  for instr in instrs {
    match instr {
      @lib.BrOnNull(_) => return true
      @lib.If(_, then_body, else_body) => {
        if ssa_test_instrs_have_br_on_null(then_body) {
          return true
        }
        match else_body {
          Some(else_body) =>
            if ssa_test_instrs_have_br_on_null(else_body) {
              return true
            }
          None => ()
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_br_on_null(body) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn ssa_test_instrs_have_br_on_non_null(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.BrOnNonNull(_) => return true
      @lib.If(_, then_body, else_body) => {
        if ssa_test_instrs_have_br_on_non_null(then_body) {
          return true
        }
        match else_body {
          Some(else_body) =>
            if ssa_test_instrs_have_br_on_non_null(else_body) {
              return true
            }
          None => ()
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_br_on_non_null(body) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn ssa_test_instrs_have_br_on_cast(instrs : Array[@lib.Instruction]) -> Bool {
  for instr in instrs {
    match instr {
      @lib.BrOnCast(_, _, _, _) => return true
      @lib.If(_, then_body, else_body) => {
        if ssa_test_instrs_have_br_on_cast(then_body) {
          return true
        }
        match else_body {
          Some(else_body) =>
            if ssa_test_instrs_have_br_on_cast(else_body) {
              return true
            }
          None => ()
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_br_on_cast(body) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn ssa_test_instrs_have_br_on_cast_fail(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.BrOnCastFail(_, _, _, _) => return true
      @lib.If(_, then_body, else_body) => {
        if ssa_test_instrs_have_br_on_cast_fail(then_body) {
          return true
        }
        match else_body {
          Some(else_body) =>
            if ssa_test_instrs_have_br_on_cast_fail(else_body) {
              return true
            }
          None => ()
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_br_on_cast_fail(body) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn ssa_test_has_adjacent_call_drop(
  instrs : Array[@lib.Instruction],
  target : UInt,
) -> Bool {
  for idx = 0; idx + 1 < instrs.length(); idx = idx + 1 {
    match (instrs[idx], instrs[idx + 1]) {
      (@lib.Call(@lib.FuncIdx(func_idx)), @lib.Drop) =>
        if func_idx == target {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn ssa_test_instrs_have_i32_const_call(
  instrs : Array[@lib.Instruction],
  value : Int,
  target : UInt,
) -> Bool {
  for idx = 0; idx + 1 < instrs.length(); idx = idx + 1 {
    match (instrs[idx], instrs[idx + 1]) {
      (@lib.I32Const(@lib.I32(found)), @lib.Call(@lib.FuncIdx(func_idx))) =>
        if found == value && func_idx == target {
          return true
        }
      _ => ()
    }
  }
  for instr in instrs {
    match instr {
      @lib.If(_, then_body, else_body) => {
        if ssa_test_instrs_have_i32_const_call(then_body, value, target) {
          return true
        }
        match else_body {
          Some(else_body) =>
            if ssa_test_instrs_have_i32_const_call(else_body, value, target) {
              return true
            }
          None => ()
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_i32_const_call(body, value, target) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn ssa_test_instrs_have_ref_null_branch_copy_lowering(
  instrs : Array[@lib.Instruction],
  canonical_local : UInt,
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.If(_, then_body, Some(else_body)) => {
        let then_copies_canonical = ssa_test_local_write_indices(then_body).any(fn(
            idx,
          ) {
            idx == canonical_local
          },
        )
        let then_branches = then_body.any(fn(then_instr) {
          match then_instr {
            @lib.Br(_) => true
            _ => false
          }
        })
        if then_copies_canonical && then_branches {
          return true
        }
        if ssa_test_instrs_have_ref_null_branch_copy_lowering(
            then_body, canonical_local,
          ) ||
          ssa_test_instrs_have_ref_null_branch_copy_lowering(
            else_body, canonical_local,
          ) {
          return true
        }
      }
      @lib.If(_, then_body, None) => {
        let then_copies_canonical = ssa_test_local_write_indices(then_body).any(fn(
            idx,
          ) {
            idx == canonical_local
          },
        )
        let then_branches = then_body.any(fn(then_instr) {
          match then_instr {
            @lib.Br(_) => true
            _ => false
          }
        })
        if then_copies_canonical && then_branches {
          return true
        }
        if ssa_test_instrs_have_ref_null_branch_copy_lowering(
            then_body, canonical_local,
          ) {
          return true
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_ref_null_branch_copy_lowering(
            body, canonical_local,
          ) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn ssa_test_instrs_have_ref_non_null_branch_copy_lowering(
  instrs : Array[@lib.Instruction],
  canonical_local : UInt,
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.If(_, then_body, Some(else_body)) => {
        let else_copies_canonical = ssa_test_local_write_indices(else_body).any(fn(
            idx,
          ) {
            idx == canonical_local
          },
        )
        let else_restores_non_null = else_body.any(fn(else_instr) {
          else_instr == @lib.Instruction::ref_as_non_null()
        })
        let else_branches = else_body.any(fn(else_instr) {
          match else_instr {
            @lib.Br(_) => true
            _ => false
          }
        })
        if else_copies_canonical && else_restores_non_null && else_branches {
          return true
        }
        if ssa_test_instrs_have_ref_non_null_branch_copy_lowering(
            then_body, canonical_local,
          ) ||
          ssa_test_instrs_have_ref_non_null_branch_copy_lowering(
            else_body, canonical_local,
          ) {
          return true
        }
      }
      @lib.If(_, then_body, None) =>
        if ssa_test_instrs_have_ref_non_null_branch_copy_lowering(
            then_body, canonical_local,
          ) {
          return true
        }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_ref_non_null_branch_copy_lowering(
            body, canonical_local,
          ) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn ssa_test_divergent_i32_local_prefix(
  local_idx : @lib.LocalIdx,
) -> Array[@lib.Instruction] {
  [
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::i32_const(@lib.I32::new(7)),
        @lib.Instruction::local_set(local_idx),
      ],
      Some([
        @lib.Instruction::i32_const(@lib.I32::new(8)),
        @lib.Instruction::local_set(local_idx),
      ]),
    ),
  ]
}

///|
// Raw-path boundary: GC/reference branch operands are not hot-mutated, but the
// raw lowering must still materialize the required Starshine-owned branch-copy
// shape. This is not a green no-op: the structural assertions below prove the
// observable no-merge copy lowering is present.
fn ssa_test_assert_raw_ref_branch_copy_lowering(
  input : @lib.Module,
  canonical_local : UInt,
  branch_on_non_null : Bool,
  context : String,
) -> Unit raise {
  let trace : Array[String] = []
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected \{context} ssa-nomerge success, got \{err}")
  }

  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("hot-lift-error") }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  if branch_on_non_null {
    assert_true(
      ssa_test_instrs_have_ref_non_null_branch_copy_lowering(
        instrs, canonical_local,
      ),
      msg=instrs.to_string(),
    )
  } else {
    assert_true(
      ssa_test_instrs_have_ref_null_branch_copy_lowering(
        instrs, canonical_local,
      ),
      msg=instrs.to_string(),
    )
  }
}

///|
fn ssa_test_instrs_have_loop_param_cast_proxy(
  instrs : Array[@lib.Instruction],
  expect_fail_variant : Bool,
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Loop(@lib.VoidBlockType, @lib.Expr(loop_body)) =>
        for loop_instr in loop_body {
          match loop_instr {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) => {
              let has_loop_backedge = outer_body.any(fn(outer_instr) {
                outer_instr == @lib.Instruction::br(@lib.LabelIdx::new(1U))
              })
              let has_inner_cast_proxy = outer_body.any(fn(outer_instr) {
                match outer_instr {
                  @lib.Block(@lib.ValTypeBlockType(_), @lib.Expr(inner_body)) =>
                    inner_body.any(fn(inner_instr) {
                      match inner_instr {
                        @lib.BrOnCastFail(@lib.LabelIdx(raw), _, _, _) =>
                          expect_fail_variant && raw == 0U
                        @lib.BrOnCast(@lib.LabelIdx(raw), _, _, _) =>
                          !expect_fail_variant && raw == 0U
                        _ => false
                      }
                    })
                  _ => false
                }
              })
              if has_loop_backedge && has_inner_cast_proxy {
                return true
              }
            }
            _ => ()
          }
        }
      @lib.Block(_, @lib.Expr(body)) | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_loop_param_cast_proxy(body, expect_fail_variant) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if ssa_test_instrs_have_loop_param_cast_proxy(
            then_body, expect_fail_variant,
          ) {
          return true
        }
        match else_body {
          Some(body) =>
            if ssa_test_instrs_have_loop_param_cast_proxy(
                body, expect_fail_variant,
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
fn ssa_test_instrs_have_loop_param_scalar_br_proxy(
  instrs : Array[@lib.Instruction],
) -> Bool {
  ssa_test_instrs_have_loop_param_scalar_branch_proxy(instrs, false)
}

///|
fn ssa_test_instrs_have_loop_param_scalar_br_if_proxy(
  instrs : Array[@lib.Instruction],
) -> Bool {
  ssa_test_instrs_have_loop_param_scalar_branch_proxy(instrs, true)
}

///|
fn ssa_test_instrs_have_nonvoid_loop(instrs : Array[@lib.Instruction]) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Loop(@lib.VoidBlockType, _) => ()
      @lib.Loop(_, _) => return true
      @lib.Block(_, @lib.Expr(body)) | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_nonvoid_loop(body) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if ssa_test_instrs_have_nonvoid_loop(then_body) {
          return true
        }
        match else_body {
          Some(body) =>
            if ssa_test_instrs_have_nonvoid_loop(body) {
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
fn ssa_test_instrs_have_block_type_idx(
  instrs : Array[@lib.Instruction],
  expected : UInt,
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Block(@lib.TypeIdxBlockType(@lib.TypeIdx(raw)), _) if raw == expected =>
        return true
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_block_type_idx(body, expected) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if ssa_test_instrs_have_block_type_idx(then_body, expected) {
          return true
        }
        match else_body {
          Some(body) =>
            if ssa_test_instrs_have_block_type_idx(body, expected) {
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
fn ssa_test_instrs_have_multi_param_loop_store_backedge(
  instrs : Array[@lib.Instruction],
) -> Bool {
  fn body_has_loop_backedge(
    body : Array[@lib.Instruction],
    depth : UInt,
  ) -> Bool {
    for instr in body {
      match instr {
        @lib.Br(@lib.LabelIdx(raw)) => if raw == depth { return true }
        @lib.Block(_, @lib.Expr(nested_body))
        | @lib.Loop(_, @lib.Expr(nested_body))
        | @lib.TryTable(_, _, @lib.Expr(nested_body)) =>
          if body_has_loop_backedge(nested_body, depth + 1U) {
            return true
          }
        @lib.If(_, then_body, else_body) => {
          if body_has_loop_backedge(then_body, depth + 1U) {
            return true
          }
          match else_body {
            Some(body) =>
              if body_has_loop_backedge(body, depth + 1U) {
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
  for instr in instrs {
    match instr {
      @lib.Loop(@lib.VoidBlockType, @lib.Expr(loop_body)) =>
        if body_has_loop_backedge(loop_body, 0U) {
          return true
        }
      @lib.Block(_, @lib.Expr(body)) | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_multi_param_loop_store_backedge(body) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if ssa_test_instrs_have_multi_param_loop_store_backedge(then_body) {
          return true
        }
        match else_body {
          Some(body) =>
            if ssa_test_instrs_have_multi_param_loop_store_backedge(body) {
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
fn ssa_test_instrs_have_br(instrs : Array[@lib.Instruction]) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Br(_) => return true
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_br(body) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if ssa_test_instrs_have_br(then_body) {
          return true
        }
        match else_body {
          Some(body) => if ssa_test_instrs_have_br(body) { return true }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn ssa_test_instrs_have_loop_backedge(instrs : Array[@lib.Instruction]) -> Bool {
  fn body_has_backedge(body : Array[@lib.Instruction], depth : UInt) -> Bool {
    for instr in body {
      match instr {
        @lib.Br(@lib.LabelIdx(raw)) | @lib.BrIf(@lib.LabelIdx(raw)) =>
          if raw == depth {
            return true
          }
        @lib.BrTable(labels, @lib.LabelIdx(default_raw)) => {
          if default_raw == depth {
            return true
          }
          for label in labels {
            let @lib.LabelIdx(raw) = label
            if raw == depth {
              return true
            }
          }
        }
        @lib.Block(_, @lib.Expr(nested_body))
        | @lib.Loop(_, @lib.Expr(nested_body))
        | @lib.TryTable(_, _, @lib.Expr(nested_body)) =>
          if body_has_backedge(nested_body, depth + 1U) {
            return true
          }
        @lib.If(_, then_body, else_body) => {
          if body_has_backedge(then_body, depth + 1U) {
            return true
          }
          match else_body {
            Some(body) => if body_has_backedge(body, depth + 1U) { return true }
            None => ()
          }
        }
        _ => ()
      }
    }
    false
  }
  for instr in instrs {
    match instr {
      @lib.Loop(_, @lib.Expr(body)) =>
        if body_has_backedge(body, 0U) {
          return true
        }
      @lib.Block(_, @lib.Expr(body)) | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_loop_backedge(body) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if ssa_test_instrs_have_loop_backedge(then_body) {
          return true
        }
        match else_body {
          Some(body) =>
            if ssa_test_instrs_have_loop_backedge(body) {
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
fn ssa_test_instrs_have_br_if(instrs : Array[@lib.Instruction]) -> Bool {
  for instr in instrs {
    match instr {
      @lib.BrIf(_) => return true
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_br_if(body) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if ssa_test_instrs_have_br_if(then_body) {
          return true
        }
        match else_body {
          Some(body) => if ssa_test_instrs_have_br_if(body) { return true }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn ssa_test_instrs_have_br_table(instrs : Array[@lib.Instruction]) -> Bool {
  for instr in instrs {
    match instr {
      @lib.BrTable(_, _) => return true
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_br_table(body) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if ssa_test_instrs_have_br_table(then_body) {
          return true
        }
        match else_body {
          Some(body) => if ssa_test_instrs_have_br_table(body) { return true }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn ssa_test_instrs_have_loop_param_br_table_proxy(
  instrs : Array[@lib.Instruction],
) -> Bool {
  fn body_has_br_table_depth(
    body : Array[@lib.Instruction],
    depth : UInt,
  ) -> Bool {
    for instr in body {
      match instr {
        @lib.BrTable(labels, @lib.LabelIdx(default_raw)) => {
          let mut all_targets_match = default_raw == depth
          for label in labels {
            let @lib.LabelIdx(raw) = label
            if raw != depth {
              all_targets_match = false
            }
          }
          if all_targets_match {
            return true
          }
        }
        @lib.Block(_, @lib.Expr(nested_body))
        | @lib.Loop(_, @lib.Expr(nested_body))
        | @lib.TryTable(_, _, @lib.Expr(nested_body)) =>
          if body_has_br_table_depth(nested_body, depth + 1U) {
            return true
          }
        @lib.If(_, then_body, else_body) => {
          if body_has_br_table_depth(then_body, depth + 1U) {
            return true
          }
          match else_body {
            Some(body) =>
              if body_has_br_table_depth(body, depth + 1U) {
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
  for instr in instrs {
    match instr {
      @lib.Loop(@lib.VoidBlockType, @lib.Expr(loop_body)) =>
        for loop_instr in loop_body {
          match loop_instr {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) => {
              let has_loop_backedge = outer_body.any(fn(outer_instr) {
                outer_instr == @lib.Instruction::br(@lib.LabelIdx::new(1U))
              })
              let has_inner_table_proxy = outer_body.any(fn(outer_instr) {
                match outer_instr {
                  @lib.Block(@lib.ValTypeBlockType(_), @lib.Expr(inner_body)) =>
                    body_has_br_table_depth(inner_body, 0U)
                  _ => false
                }
              })
              if has_loop_backedge && has_inner_table_proxy {
                return true
              }
            }
            _ => ()
          }
        }
      @lib.Block(_, @lib.Expr(body)) | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_loop_param_br_table_proxy(body) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if ssa_test_instrs_have_loop_param_br_table_proxy(then_body) {
          return true
        }
        match else_body {
          Some(body) =>
            if ssa_test_instrs_have_loop_param_br_table_proxy(body) {
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
fn ssa_test_instrs_have_loop_param_scalar_branch_proxy(
  instrs : Array[@lib.Instruction],
  expect_br_if : Bool,
) -> Bool {
  fn body_has_branch_depth(
    body : Array[@lib.Instruction],
    depth : UInt,
  ) -> Bool {
    for instr in body {
      match instr {
        @lib.Br(@lib.LabelIdx(raw)) =>
          if !expect_br_if && raw == depth {
            return true
          }
        @lib.BrIf(@lib.LabelIdx(raw)) =>
          if expect_br_if && raw == depth {
            return true
          }
        @lib.Block(_, @lib.Expr(nested_body))
        | @lib.Loop(_, @lib.Expr(nested_body))
        | @lib.TryTable(_, _, @lib.Expr(nested_body)) =>
          if body_has_branch_depth(nested_body, depth + 1U) {
            return true
          }
        @lib.If(_, then_body, else_body) => {
          if body_has_branch_depth(then_body, depth + 1U) {
            return true
          }
          match else_body {
            Some(body) =>
              if body_has_branch_depth(body, depth + 1U) {
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
  for instr in instrs {
    match instr {
      @lib.Loop(@lib.VoidBlockType, @lib.Expr(loop_body)) => {
        for loop_instr in loop_body {
          match loop_instr {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) => {
              let has_loop_backedge = outer_body.any(fn(outer_instr) {
                outer_instr == @lib.Instruction::br(@lib.LabelIdx::new(1U))
              })
              let has_inner_branch_proxy = outer_body.any(fn(outer_instr) {
                match outer_instr {
                  @lib.Block(@lib.ValTypeBlockType(_), @lib.Expr(inner_body)) =>
                    body_has_branch_depth(inner_body, 0U)
                  _ => false
                }
              })
              if has_loop_backedge && has_inner_branch_proxy {
                return true
              }
            }
            _ => ()
          }
        }
        if ssa_test_instrs_have_loop_param_scalar_branch_proxy(
            loop_body, expect_br_if,
          ) {
          return true
        }
      }
      @lib.Block(block_type, @lib.Expr(body)) => {
        if !expect_br_if && block_type != @lib.BlockType::void_() {
          for block_instr in body {
            match block_instr {
              @lib.Loop(@lib.VoidBlockType, @lib.Expr(loop_body)) =>
                if body_has_branch_depth(loop_body, 1U) {
                  return true
                }
              _ => ()
            }
          }
        }
        if expect_br_if && block_type == @lib.BlockType::void_() {
          for block_instr in body {
            match block_instr {
              @lib.Loop(@lib.VoidBlockType, @lib.Expr(loop_body)) =>
                if body_has_branch_depth(loop_body, 0U) &&
                  loop_body.any(fn(loop_instr) {
                    match loop_instr {
                      @lib.LocalSet(_) | @lib.LocalTee(_) => true
                      _ => false
                    }
                  }) {
                  return true
                }
              _ => ()
            }
          }
        }
        if ssa_test_instrs_have_loop_param_scalar_branch_proxy(
            body, expect_br_if,
          ) {
          return true
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_loop_param_scalar_branch_proxy(
            body, expect_br_if,
          ) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if ssa_test_instrs_have_loop_param_scalar_branch_proxy(
            then_body, expect_br_if,
          ) {
          return true
        }
        match else_body {
          Some(body) =>
            if ssa_test_instrs_have_loop_param_scalar_branch_proxy(
                body, expect_br_if,
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
fn ssa_test_instrs_have_loop_param_null_proxy(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Loop(@lib.VoidBlockType, @lib.Expr(loop_body)) =>
        for loop_instr in loop_body {
          match loop_instr {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) => {
              let has_loop_backedge = outer_body.any(fn(outer_instr) {
                outer_instr == @lib.Instruction::br(@lib.LabelIdx::new(1U))
              })
              let has_inner_null_proxy = outer_body.any(fn(outer_instr) {
                match outer_instr {
                  @lib.Block(@lib.ValTypeBlockType(_), @lib.Expr(inner_body)) =>
                    inner_body.any(fn(inner_instr) {
                      match inner_instr {
                        @lib.BrOnNull(@lib.LabelIdx(raw)) => raw == 0U
                        _ => false
                      }
                    })
                  _ => false
                }
              })
              if has_loop_backedge && has_inner_null_proxy {
                return true
              }
            }
            _ => ()
          }
        }
      @lib.Block(_, @lib.Expr(body)) | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_loop_param_null_proxy(body) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if ssa_test_instrs_have_loop_param_null_proxy(then_body) {
          return true
        }
        match else_body {
          Some(body) =>
            if ssa_test_instrs_have_loop_param_null_proxy(body) {
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
fn ssa_test_instrs_have_null_taken_copy_branch(
  instrs : Array[@lib.Instruction],
  canonical_local : UInt,
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.If(_, then_body, else_body) => {
        let then_copies_canonical = ssa_test_local_write_indices(then_body).any(fn(
            idx,
          ) {
            idx == canonical_local
          },
        )
        let then_branches = then_body.any(fn(then_instr) {
          match then_instr {
            @lib.Br(_) => true
            _ => false
          }
        })
        if then_copies_canonical && then_branches {
          return true
        }
        if ssa_test_instrs_have_null_taken_copy_branch(
            then_body, canonical_local,
          ) {
          return true
        }
        match else_body {
          Some(body) =>
            if ssa_test_instrs_have_null_taken_copy_branch(
                body, canonical_local,
              ) {
              return true
            }
          None => ()
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_null_taken_copy_branch(body, canonical_local) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn ssa_test_instrs_have_loop_param_non_null_proxy(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Loop(@lib.VoidBlockType, @lib.Expr(loop_body)) =>
        for loop_instr in loop_body {
          match loop_instr {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) => {
              let has_loop_backedge = outer_body.any(fn(outer_instr) {
                outer_instr == @lib.Instruction::br(@lib.LabelIdx::new(1U))
              })
              let has_inner_non_null_proxy = outer_body.any(fn(outer_instr) {
                match outer_instr {
                  @lib.Block(@lib.ValTypeBlockType(_), @lib.Expr(inner_body)) =>
                    inner_body.any(fn(inner_instr) {
                      match inner_instr {
                        @lib.BrOnNonNull(@lib.LabelIdx(raw)) => raw == 0U
                        _ => false
                      }
                    })
                  _ => false
                }
              })
              if has_loop_backedge && has_inner_non_null_proxy {
                return true
              }
            }
            _ => ()
          }
        }
      @lib.Block(_, @lib.Expr(body)) | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_loop_param_non_null_proxy(body) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if ssa_test_instrs_have_loop_param_non_null_proxy(then_body) {
          return true
        }
        match else_body {
          Some(body) =>
            if ssa_test_instrs_have_loop_param_non_null_proxy(body) {
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
fn ssa_test_instrs_have_ref_cast_branch_copy_block(
  instrs : Array[@lib.Instruction],
  canonical_local : UInt,
  expect_fail_variant : Bool,
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Block(_, @lib.Expr(body)) => {
        let has_inverse_cast = body.any(fn(body_instr) {
          match body_instr {
            @lib.BrOnCast(@lib.LabelIdx(label), _, _, _) =>
              !expect_fail_variant && label == 0U
            @lib.BrOnCastFail(@lib.LabelIdx(label), _, _, _) =>
              expect_fail_variant && label == 0U
            _ => false
          }
        })
        let copies_canonical = ssa_test_local_write_indices(body).any(fn(idx) {
          idx == canonical_local
        })
        let exits_outer = body.any(fn(body_instr) {
          match body_instr {
            @lib.Br(@lib.LabelIdx(label)) => label > 0U
            _ => false
          }
        })
        if has_inverse_cast && copies_canonical && exits_outer {
          return true
        }
        if ssa_test_instrs_have_ref_cast_branch_copy_block(
            body, canonical_local, expect_fail_variant,
          ) {
          return true
        }
      }
      @lib.Loop(_, @lib.Expr(body)) | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_ref_cast_branch_copy_block(
            body, canonical_local, expect_fail_variant,
          ) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if ssa_test_instrs_have_ref_cast_branch_copy_block(
            then_body, canonical_local, expect_fail_variant,
          ) {
          return true
        }
        match else_body {
          Some(body) =>
            if ssa_test_instrs_have_ref_cast_branch_copy_block(
                body, canonical_local, expect_fail_variant,
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
fn ssa_test_run_hot_path_only(text : String) -> Result[@lib.Module, String] {
  let mod_ = pass_test_module_from_wat(text)
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  @ir.hot_verify_all_or_abort(func)
  let ctx = HotPassContext::new(
    ssa_nomerge_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) => return Err("ssa-nomerge hot-path run failed: \{err}")
  }
  let lowered = @ir.hot_lower_func_with_options(
    func,
    @ir.HotLowerOptions::new(preserve_dead_local_tee_drops=true),
  )
  let next_code_sec = match mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[0] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => return Err("expected code sec in hot-path fixture")
  }
  let out = mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => Ok(out)
    Err(err) => Err(@validate.validation_error_message(err))
  }
}

///|
test "ssa-nomerge leaves already SSA nested compare tee canonical" {
  // Reduced from current debug-WASI `defined=1474 abs=1501`: the local.tee
  // feeds a straight-line nested compare chain and the original local is already
  // SSA. Freshening it appends a body local without a size or semantic win.
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $touch (param i32))
    #|  (func (param i32) (result i32)
    #|    (local i32)
    #|    local.get 0
    #|    i32.load offset=8 align=1
    #|    local.tee 1
    #|    i32.const 113
    #|    i32.eq
    #|    if (result i32)
    #|      i32.const 1
    #|    else
    #|      local.get 1
    #|      i32.const 131
    #|      i32.eq
    #|      if (result i32)
    #|        i32.const 1
    #|      else
    #|        local.get 1
    #|        i32.const 115
    #|        i32.eq
    #|        if (result i32)
    #|          i32.const 1
    #|        else
    #|          local.get 0
    #|          call $touch
    #|          i32.const 0
    #|        end
    #|      end
    #|    end)
    #|)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected ssa-nomerge pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected ssa-nomerge output to validate, got \{@validate.validation_error_message(err)}",
      )
  }
  assert_true(
    trace.any(fn(line) { line.contains("structured-already-ssa-tee-noop") }),
    msg=trace.join("\n"),
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(
    locals.length() <= 1,
    msg=locals.to_string() + "\n" + instrs.to_string(),
  )
  assert_false(
    ssa_test_local_tee_indices(instrs).any(fn(idx) { idx > 1U }),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge reuses unused body local for structured load scratch" {
  // Reduced from current debug-WASI `defined=678 abs=705`: the structured
  // memory-load scratch is a one-set/one-get i32 temporary after a call and
  // before another call. Appending a new local is body-size neutral but loses
  // the local-count comparison when an unused same-typed body local is already
  // available.
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $produce (param i32) (result i32)
    #|    local.get 0)
    #|  (func $touch (param i32))
    #|  (func (param i32) (result i64)
    #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|    block
    #|      local.get 0
    #|      call $produce
    #|      local.tee 6
    #|      i32.const 0
    #|      i32.eq
    #|      if (result i64)
    #|        local.get 0
    #|        local.tee 2
    #|        i32.load offset=8 align=1
    #|        local.set 6
    #|        local.get 2
    #|        call $touch
    #|        local.get 6
    #|        local.tee 7
    #|        local.set 1
    #|        br 1
    #|      else
    #|        local.get 0
    #|        call $touch
    #|        i64.const 4294967296
    #|      end
    #|      return
    #|    end
    #|    local.get 1
    #|    local.tee 8
    #|    i64.extend_i32_s)
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 2)
  assert_true(
    locals.length() <= 9,
    msg=locals.to_string() + "\n" + instrs.to_string(),
  )
  assert_false(
    ssa_test_local_set_indices(instrs).any(fn(idx) { idx > 9U }),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge reuses unused body local for medium structured load scratch" {
  // Reduced from current debug-WASI `defined=1500 abs=1527`: the same
  // one-set/one-get structured-load scratch family can appear just above the
  // original small 8-10 body-local guard. Appending a twelfth body local is
  // byte-neutral but loses the local-count comparison when unused i32 locals
  // are already available.
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $produce (param i32) (result i32)
    #|    local.get 0)
    #|  (func $touch (param i32))
    #|  (func (param i32) (result i64)
    #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|    block
    #|      local.get 0
    #|      call $produce
    #|      local.tee 6
    #|      i32.const 0
    #|      i32.eq
    #|      if (result i64)
    #|        local.get 0
    #|        local.tee 2
    #|        i32.load offset=8 align=1
    #|        local.set 6
    #|        local.get 2
    #|        call $touch
    #|        local.get 6
    #|        local.tee 7
    #|        local.set 1
    #|        br 1
    #|      else
    #|        local.get 0
    #|        call $touch
    #|        i64.const 4294967296
    #|      end
    #|      return
    #|    end
    #|    local.get 1
    #|    local.tee 8
    #|    i64.extend_i32_s)
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 2)
  assert_true(
    locals.length() <= 11,
    msg=locals.to_string() + "\n" + instrs.to_string(),
  )
  assert_false(
    ssa_test_local_set_indices(instrs).any(fn(idx) { idx > 11U }),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge reuses unused body locals for branch dead tees" {
  // Reduced from current debug-WASI `defined=1501 abs=1528`: the structured
  // loop has two branch-local `local.tee` scratch values and already-declared
  // unused body locals. Appending scratch locals is byte-neutral but loses the
  // local-count comparison, so reuse the existing same-typed slots.
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $alloc (param i32) (result i32) (local.get 0))
    #|  (func $tick (param i32))
    #|  (func $dropref (param i32))
    #|  (func $limit (param i32) (result i32) (local.get 0))
    #|  (func $lookup (param i32 i32) (result i32) (local.get 0))
    #|  (func $check (param i32 i32) (result i32) (local.get 1))
    #|  (func $target (param $0 i32) (result i32)
    #|  (local $1 i32)
    #|  (local $2 i32)
    #|  (local $3 i32)
    #|  (local $4 i32)
    #|  (local $5 i32)
    #|  (local $6 i32)
    #|  (local $7 i32)
    #|  (local $8 i32)
    #|  (local $9 i32)
    #|  (local $10 i32)
    #|  (local $11 i32)
    #|  (local $12 i32)
    #|  (local $13 i32)
    #|  (local $14 i32)
    #|  (local $15 i32)
    #|  (local $16 i32)
    #|  (local $17 i32)
    #|  (local $18 i32)
    #|  (local $19 i32)
    #|  (i32.store offset=4 align=1
    #|   (local.tee $12
    #|    (call $alloc
    #|     (i32.const 4)
    #|    )
    #|   )
    #|   (i32.const 1572864)
    #|  )
    #|  (i32.store offset=8 align=1
    #|   (local.get $12)
    #|   (i32.const 0)
    #|  )
    #|  (local.set $1
    #|   (local.get $12)
    #|  )
    #|  (i32.store offset=4 align=1
    #|   (local.tee $11
    #|    (call $alloc
    #|     (i32.const 4)
    #|    )
    #|   )
    #|   (i32.const 1572864)
    #|  )
    #|  (i32.store offset=8 align=1
    #|   (local.get $11)
    #|   (i32.const 0)
    #|  )
    #|  (local.set $2
    #|   (local.get $11)
    #|  )
    #|  (i32.store offset=4 align=1
    #|   (local.tee $10
    #|    (call $alloc
    #|     (i32.const 4)
    #|    )
    #|   )
    #|   (i32.const 1572864)
    #|  )
    #|  (i32.store offset=8 align=1
    #|   (local.get $10)
    #|   (i32.const 0)
    #|  )
    #|  (local.set $3
    #|   (local.get $10)
    #|  )
    #|  (local.set $13
    #|   (i32.const 0)
    #|  )
    #|  (loop $label
    #|   (block $block8
    #|    (local.set $13
    #|     (block $block7 (result i32)
    #|      (local.set $4
    #|       (local.get $13)
    #|      )
    #|      (call $tick
    #|       (local.get $0)
    #|      )
    #|      (local.set $6
    #|       (call $limit
    #|        (local.get $0)
    #|       )
    #|      )
    #|      (if
    #|       (i32.lt_s
    #|        (local.get $4)
    #|        (local.get $6)
    #|       )
    #|       (then
    #|        (block $block
    #|         (call $tick
    #|          (local.get $0)
    #|         )
    #|         (if
    #|          (i32.eqz
    #|           (local.tee $18
    #|            (call $check
    #|             (local.get $0)
    #|             (local.get $4)
    #|            )
    #|           )
    #|          )
    #|          (then
    #|           (br $block)
    #|          )
    #|         )
    #|         (drop
    #|          (i32.const 0)
    #|         )
    #|         (drop
    #|          (block $block6 (result i32)
    #|           (block $block3
    #|            (br $block6
    #|             (block $block5 (result i32)
    #|              (block $block2
    #|               (br $block5
    #|                (block $block4 (result i32)
    #|                 (block $block1
    #|                  (call $tick
    #|                   (local.get $0)
    #|                  )
    #|                  (local.set $14
    #|                   (i32.load offset=8 align=1
    #|                    (local.tee $9
    #|                     (call $lookup
    #|                      (local.get $0)
    #|                      (local.get $4)
    #|                     )
    #|                    )
    #|                   )
    #|                  )
    #|                  (call $dropref
    #|                   (local.get $9)
    #|                  )
    #|                  (if
    #|                   (i32.eq
    #|                    (local.tee $5
    #|                     (local.get $14)
    #|                    )
    #|                    (i32.const 22)
    #|                   )
    #|                   (then
    #|                    (br $block1)
    #|                   )
    #|                   (else
    #|                    (if
    #|                     (i32.eq
    #|                      (local.get $5)
    #|                      (i32.const 23)
    #|                     )
    #|                     (then
    #|                      (br $block1)
    #|                     )
    #|                     (else
    #|                      (if
    #|                       (i32.eq
    #|                        (local.get $5)
    #|                        (i32.const 2)
    #|                       )
    #|                       (then
    #|                        (br $block2)
    #|                       )
    #|                       (else
    #|                        (if
    #|                         (i32.eq
    #|                          (local.get $5)
    #|                          (i32.const 3)
    #|                         )
    #|                         (then
    #|                          (br $block2)
    #|                         )
    #|                         (else
    #|                          (if
    #|                           (i32.eq
    #|                            (local.get $5)
    #|                            (i32.const 4)
    #|                           )
    #|                           (then
    #|                            (br $block2)
    #|                           )
    #|                           (else
    #|                            (if
    #|                             (i32.eq
    #|                              (local.get $5)
    #|                              (i32.const 5)
    #|                             )
    #|                             (then
    #|                              (br $block2)
    #|                             )
    #|                             (else
    #|                              (if
    #|                               (i32.eq
    #|                                (local.get $5)
    #|                                (i32.const 6)
    #|                               )
    #|                               (then
    #|                                (br $block2)
    #|                               )
    #|                               (else
    #|                                (if
    #|                                 (i32.eq
    #|                                  (local.get $5)
    #|                                  (i32.const 7)
    #|                                 )
    #|                                 (then
    #|                                  (br $block3)
    #|                                 )
    #|                                 (else
    #|                                  (if
    #|                                   (i32.eq
    #|                                    (local.get $5)
    #|                                    (i32.const 8)
    #|                                   )
    #|                                   (then
    #|                                    (br $block3)
    #|                                   )
    #|                                   (else
    #|                                    (if
    #|                                     (i32.eq
    #|                                      (local.get $5)
    #|                                      (i32.const 9)
    #|                                     )
    #|                                     (then
    #|                                      (br $block3)
    #|                                     )
    #|                                     (else
    #|                                      (if
    #|                                       (i32.eq
    #|                                        (local.get $5)
    #|                                        (i32.const 14)
    #|                                       )
    #|                                       (then
    #|                                        (br $block3)
    #|                                       )
    #|                                       (else
    #|                                        (if
    #|                                         (i32.eq
    #|                                          (local.get $5)
    #|                                          (i32.const 18)
    #|                                         )
    #|                                         (then
    #|                                          (br $block3)
    #|                                         )
    #|                                         (else
    #|                                          (if
    #|                                           (i32.eq
    #|                                            (local.get $5)
    #|                                            (i32.const 19)
    #|                                           )
    #|                                           (then
    #|                                            (br $block3)
    #|                                           )
    #|                                           (else
    #|                                            (if
    #|                                             (i32.eq
    #|                                              (local.get $5)
    #|                                              (i32.const 20)
    #|                                             )
    #|                                             (then
    #|                                              (br $block3)
    #|                                             )
    #|                                             (else
    #|                                              (drop
    #|                                               (i32.const 0)
    #|                                              )
    #|                                             )
    #|                                            )
    #|                                           )
    #|                                          )
    #|                                         )
    #|                                        )
    #|                                       )
    #|                                      )
    #|                                     )
    #|                                    )
    #|                                   )
    #|                                  )
    #|                                 )
    #|                                )
    #|                               )
    #|                              )
    #|                             )
    #|                            )
    #|                           )
    #|                          )
    #|                         )
    #|                        )
    #|                       )
    #|                      )
    #|                     )
    #|                    )
    #|                   )
    #|                  )
    #|                  (br $block4
    #|                   (i32.const 0)
    #|                  )
    #|                 )
    #|                 (i32.store offset=8 align=1
    #|                  (local.get $1)
    #|                  (i32.const 1)
    #|                 )
    #|                 (i32.const 0)
    #|                )
    #|               )
    #|              )
    #|              (i32.store offset=8 align=1
    #|               (local.get $2)
    #|               (i32.const 1)
    #|              )
    #|              (i32.const 0)
    #|             )
    #|            )
    #|           )
    #|           (i32.store offset=8 align=1
    #|            (local.get $3)
    #|            (i32.const 1)
    #|           )
    #|           (i32.const 0)
    #|          )
    #|         )
    #|         (br $block)
    #|        )
    #|        (drop
    #|         (br $block7
    #|          (local.tee $19
    #|           (i32.add
    #|            (local.get $4)
    #|            (i32.const 1)
    #|           )
    #|          )
    #|         )
    #|        )
    #|       )
    #|       (else
    #|        (call $dropref
    #|         (local.get $0)
    #|        )
    #|       )
    #|      )
    #|      (drop
    #|       (i32.const 0)
    #|      )
    #|      (br $block8)
    #|     )
    #|    )
    #|    (br $label)
    #|   )
    #|  )
    #|  (drop
    #|   (i32.const 0)
    #|  )
    #|  (local.set $15
    #|   (i32.load offset=8 align=1
    #|    (local.get $1)
    #|   )
    #|  )
    #|  (call $dropref
    #|   (local.get $1)
    #|  )
    #|  (if (result i32)
    #|   (local.get $15)
    #|   (then
    #|    (local.set $16
    #|     (i32.load offset=8 align=1
    #|      (local.get $2)
    #|     )
    #|    )
    #|    (call $dropref
    #|     (local.get $2)
    #|    )
    #|    (if (result i32)
    #|     (local.get $16)
    #|     (then
    #|      (local.set $17
    #|       (i32.load offset=8 align=1
    #|        (local.get $3)
    #|       )
    #|      )
    #|      (call $dropref
    #|       (local.get $3)
    #|      )
    #|      (local.get $17)
    #|     )
    #|     (else
    #|      (call $dropref
    #|       (local.get $3)
    #|      )
    #|      (i32.const 0)
    #|     )
    #|    )
    #|   )
    #|   (else
    #|    (call $dropref
    #|     (local.get $3)
    #|    )
    #|    (call $dropref
    #|     (local.get $2)
    #|    )
    #|    (i32.const 0)
    #|   )
    #|  )
    #| )
    #|
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 6)
  assert_true(
    locals.length() <= 19,
    msg=locals.to_string() + "\n" + instrs.to_string(),
  )
  assert_false(
    ssa_test_local_tee_indices(instrs).any(fn(idx) { idx > 19U }),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge reuses unused body local for nested compare tee chain" {
  // Reduced from current debug-WASI `defined=1506 abs=1533`: the loaded tag
  // feeds a nested compare chain through a single `local.tee`, and an unused
  // same-typed body local is already available. Reusing that slot avoids a
  // byte-neutral appended local-count loss.
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $touch (param i32))
    #|  (func (param $0 i32) (result i32)
    #|    (local $1 i32) (local $2 i32) (local $3 i32) (local $4 i32)
    #|    (if (result i32)
    #|      (i32.eq (local.get $0) (i32.const 0))
    #|      (then
    #|        (if (local.get $0) (then (call $touch (local.get $0))))
    #|        (i32.const 0))
    #|      (else
    #|        (if (result i32)
    #|          (i32.eq
    #|            (local.tee $3
    #|              (i32.load offset=8 align=1
    #|                (local.tee $2 (local.tee $4 (local.get $0)))))
    #|            (i32.const 174))
    #|          (then (i32.const 1))
    #|          (else
    #|            (if (result i32)
    #|              (i32.eq (local.get $3) (i32.const 179))
    #|              (then (i32.const 1))
    #|              (else
    #|                (if (result i32)
    #|                  (i32.eq (local.get $3) (i32.const 180))
    #|                  (then (i32.const 1))
    #|                  (else
    #|                    (if (result i32)
    #|                      (i32.eq (local.get $3) (i32.const 185))
    #|                      (then (i32.const 1))
    #|                      (else
    #|                        (local.get $2)
    #|                        call $touch
    #|                        (i32.const 0))))))))))))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(
    locals.length() <= 4,
    msg=locals.to_string() + "\n" + instrs.to_string(),
  )
  assert_false(
    ssa_test_local_tee_indices(instrs).any(fn(idx) { idx > 4U }),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge artifact parity freshens allocator searchBlock temps" {
  // Artifact repro from the checked-in debug-WASI artifact, first canonical
  // difference `defined=0 abs=27` (`tlsf/searchBlock`). Binaryen's
  // `ssa-nomerge` freshens the allocator size-class value-if result, following
  // mask temporaries, and ctz bucket index into appended locals even though the
  // function has no merge-copy branch rewrite. Reusing the original param/body
  // locals has no measured Starshine win, so keep this narrow source-mode
  // neighborhood aligned with Binaryen instead of leaving full-artifact parity
  // blocked on a no-op raw path.
  let source =
    #|(module
    #|  (memory 1)
    #| (func (param $0 i32) (param $1 i32) (result i32)
    #|  (local $2 i32)
    #|  (if (result i32)
    #|   (local.tee $1
    #|    (i32.and
    #|     (i32.load offset=4 align=1
    #|      (i32.add
    #|       (local.get $0)
    #|       (i32.shl
    #|        (local.tee $2
    #|         (if (result i32)
    #|          (i32.lt_u
    #|           (local.get $1)
    #|           (i32.const 256)
    #|          )
    #|          (then
    #|           (local.set $1
    #|            (i32.shr_u
    #|             (local.get $1)
    #|             (i32.const 4)
    #|            )
    #|           )
    #|           (i32.const 0)
    #|          )
    #|          (else
    #|           (if
    #|            (i32.lt_u
    #|             (local.get $1)
    #|             (i32.const 536870910)
    #|            )
    #|            (then
    #|             (local.set $1
    #|              (i32.sub
    #|               (i32.add
    #|                (local.get $1)
    #|                (i32.shl
    #|                 (i32.const 1)
    #|                 (i32.sub
    #|                  (i32.const 27)
    #|                  (i32.clz
    #|                   (local.get $1)
    #|                  )
    #|                 )
    #|                )
    #|               )
    #|               (i32.const 1)
    #|              )
    #|             )
    #|            )
    #|           )
    #|           (local.set $2
    #|            (i32.sub
    #|             (i32.const 31)
    #|             (i32.clz
    #|              (local.get $1)
    #|             )
    #|            )
    #|           )
    #|           (local.set $1
    #|            (i32.xor
    #|             (i32.shr_u
    #|              (local.get $1)
    #|              (i32.sub
    #|               (local.get $2)
    #|               (i32.const 4)
    #|              )
    #|             )
    #|             (i32.const 16)
    #|            )
    #|           )
    #|           (i32.sub
    #|            (local.get $2)
    #|            (i32.const 7)
    #|           )
    #|          )
    #|         )
    #|        )
    #|        (i32.const 2)
    #|       )
    #|      )
    #|     )
    #|     (i32.shl
    #|      (i32.const -1)
    #|      (local.get $1)
    #|     )
    #|    )
    #|   )
    #|   (then
    #|    (i32.load offset=96 align=1
    #|     (i32.add
    #|      (local.get $0)
    #|      (i32.shl
    #|       (i32.add
    #|        (i32.ctz
    #|         (local.get $1)
    #|        )
    #|        (i32.shl
    #|         (local.get $2)
    #|         (i32.const 4)
    #|        )
    #|       )
    #|       (i32.const 2)
    #|      )
    #|     )
    #|    )
    #|   )
    #|   (else
    #|    (if (result i32)
    #|     (local.tee $1
    #|      (i32.and
    #|       (i32.load align=1
    #|        (local.get $0)
    #|       )
    #|       (i32.shl
    #|        (i32.const -1)
    #|        (i32.add
    #|         (local.get $2)
    #|         (i32.const 1)
    #|        )
    #|       )
    #|      )
    #|     )
    #|     (then
    #|      (i32.load offset=96 align=1
    #|       (i32.add
    #|        (local.get $0)
    #|        (i32.shl
    #|         (i32.add
    #|          (i32.ctz
    #|           (i32.load offset=4 align=1
    #|            (i32.add
    #|             (local.get $0)
    #|             (i32.shl
    #|              (local.tee $1
    #|               (i32.ctz
    #|                (local.get $1)
    #|               )
    #|              )
    #|              (i32.const 2)
    #|             )
    #|            )
    #|           )
    #|          )
    #|          (i32.shl
    #|           (local.get $1)
    #|           (i32.const 4)
    #|          )
    #|         )
    #|         (i32.const 2)
    #|        )
    #|       )
    #|      )
    #|     )
    #|     (else
    #|      (i32.const 0)
    #|     )
    #|    )
    #|   )
    #|  )
    #| )
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() >= 6, msg=locals.to_string())
  let write_indices = ssa_test_local_write_indices(instrs)
  assert_true(write_indices.any(fn(idx) { idx == 3U }), msg=instrs.to_string())
  assert_true(write_indices.any(fn(idx) { idx == 4U }), msg=instrs.to_string())
  assert_true(write_indices.any(fn(idx) { idx == 5U }), msg=instrs.to_string())
  assert_true(write_indices.any(fn(idx) { idx == 6U }), msg=instrs.to_string())
  assert_true(write_indices.any(fn(idx) { idx == 7U }), msg=instrs.to_string())
}

///|
test "ssa-nomerge does not freshen multi-param branch-carried body locals" {
  // The debug-WASI `defined=119 abs=146` follow-up has four parameters and two
  // sibling value arms that carry a refcount/decref local out through a value
  // block. Binaryen keeps the carried body local canonical in that multi-param
  // adapter-like shape; the allocator/selector freshening post-passes are not
  // allowed to append fresh lanes here because that shifts the whole suffix local
  // budget.
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $touch (param i32))
    #|  (func (param $p0 i32) (param $p1 i32) (param $p2 i32) (param $p3 i32) (result i32)
    #|    (local $carried i32) (local $obj i32) (local $count i32)
    #|    (local $fresh i32) (local $suffix i32) (local $result i32)
    #|    local.get $p3
    #|    if (result i32)
    #|      block (result i32)
    #|        block
    #|          block (result i32)
    #|            local.get $p0
    #|            local.tee $obj
    #|            call $touch
    #|            local.get $obj
    #|            i32.load
    #|            local.set $carried
    #|            local.get $obj
    #|            i32.load offset=4
    #|            local.tee $count
    #|            i32.const 1
    #|            i32.gt_s
    #|            if
    #|              local.get $count
    #|              i32.const 1
    #|              i32.sub
    #|              local.set $fresh
    #|              local.get $obj
    #|              local.get $fresh
    #|              i32.store offset=4
    #|              local.get $carried
    #|              call $touch
    #|            else
    #|              local.get $count
    #|              i32.const 1
    #|              i32.eq
    #|              if
    #|                local.get $obj
    #|                call $touch
    #|              end
    #|            end
    #|            local.get $carried
    #|          end
    #|          drop
    #|          br 0
    #|        end
    #|        i32.const 7
    #|      end
    #|    else
    #|      i32.const 3
    #|    end
    #|    local.set $result
    #|    i32.const 8
    #|    local.set $suffix
    #|    local.get $result
    #|    local.get $suffix
    #|    i32.add))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(
    locals.length() <= 6,
    msg=locals.to_string() + "\n" + instrs.to_string(),
  )
  assert_false(
    ssa_test_local_write_indices(instrs).any(fn(idx) { idx >= 10U }),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge spills br_table arm load across following call" {
  // Reduced from the debug-WASI `defined=161 abs=188` br_table dispatcher
  // shape. Binaryen spills a loaded branch payload before a following decref-like
  // call even when the payload is immediately written through a local.tee and
  // consumed only by that arm's suffix block.
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $tag (param i32) (result i32) local.get 0)
    #|  (func $decref (param i32))
    #|  (func $fmt (param i32) (result i32) local.get 0)
    #|  (func (param $err i32) (result i32)
    #|    (local $taglocal i32) (local $flag0 i32) (local $flag1 i32)
    #|    (local $obj0 i32) (local $obj1 i32) (local $cnt i32)
    #|    (local $newcnt i32) (local $field0 i32) (local $suffix0 i32) (local $suffix1 i32)
    #|    local.get $err
    #|    call $tag
    #|    local.set $taglocal
    #|    block $suffix1block
    #|      block $suffix0block
    #|        block $case1
    #|          block $case0
    #|            local.get $taglocal
    #|            br_table $case0 $case1
    #|          end
    #|          local.get $err
    #|          local.tee $obj0
    #|          i32.load offset=8
    #|          local.set $field0
    #|          local.get $obj0
    #|          i32.load
    #|          local.tee $cnt
    #|          i32.const 1
    #|          i32.gt_s
    #|          if
    #|            local.get $cnt
    #|            i32.const 1
    #|            i32.sub
    #|            local.set $newcnt
    #|            local.get $obj0
    #|            local.get $newcnt
    #|            i32.store
    #|            local.get $field0
    #|            call $decref
    #|          end
    #|          local.get $field0
    #|          local.tee $flag0
    #|          br $suffix0block
    #|        end
    #|        local.get $err
    #|        local.tee $obj1
    #|        i32.load offset=8
    #|        local.get $obj1
    #|        call $decref
    #|        local.tee $flag1
    #|        br $suffix1block
    #|      end
    #|      local.get $flag0
    #|      call $fmt
    #|      local.set $suffix0
    #|      local.get $suffix0
    #|      return
    #|    end
    #|    local.get $flag1
    #|    call $fmt
    #|    local.set $suffix1
    #|    local.get $suffix1))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 3)
  assert_true(
    locals.length() >= 12,
    msg=locals.to_string() + "\n" + instrs.to_string(),
  )
  assert_true(
    ssa_test_local_write_indices(instrs).any(fn(idx) { idx == 12U }),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge artifact parity preserves selector formatter local budget" {
  // Binary fixture reduced from the checked-in debug-WASI first diff
  // `.tmp/self-ssa-nomerge-debug-wasi-adapter-error-20260613`, defined=109
  // abs=136 (`cmd__print__selector__text`). The WAT fixture alone normalizes
  // differently, so this guard decodes the compact binary-path shape. Binaryen
  // spends three branch-carrier/tag temps and four suffix-formatting temps but
  // does not allocate a 23rd body local; Starshine's current binary-path drift
  // writes the tag to an early fresh lane and shifts suffix temps to local 23.
  let input = ssa_test_decode_wasm_bytes([
    0, 97, 115, 109, 1, 0, 0, 0, 1, 16, 3, 96, 1, 127, 1, 127, 96, 1, 127, 0, 96,
    2, 127, 127, 1, 127, 3, 9, 8, 0, 1, 1, 1, 0, 0, 2, 0, 5, 3, 1, 0, 1, 10, 195,
    1, 8, 4, 0, 32, 0, 11, 2, 0, 11, 2, 0, 11, 2, 0, 11, 4, 0, 32, 0, 11, 4, 0, 32,
    0, 11, 4, 0, 32, 1, 11, 163, 1, 1, 14, 127, 2, 64, 2, 64, 32, 0, 16, 0, 34, 14,
    65, 0, 70, 4, 127, 32, 0, 34, 3, 40, 0, 8, 32, 3, 16, 1, 34, 4, 33, 2, 12, 1,
    5, 32, 0, 34, 5, 40, 0, 8, 33, 11, 32, 5, 40, 0, 0, 34, 12, 65, 1, 74, 4, 64,
    32, 12, 65, 1, 107, 33, 13, 32, 5, 32, 13, 54, 0, 0, 32, 11, 16, 2, 5, 32, 12,
    65, 1, 70, 4, 64, 32, 5, 16, 3, 11, 11, 32, 11, 34, 6, 33, 1, 12, 2, 11, 15,
    11, 32, 2, 16, 4, 33, 10, 65, 232, 180, 1, 32, 10, 16, 6, 32, 10, 16, 1, 34,
    9, 65, 216, 180, 1, 16, 6, 32, 9, 16, 1, 15, 11, 32, 1, 16, 5, 33, 8, 65, 248,
    180, 1, 32, 8, 16, 6, 32, 8, 16, 1, 34, 7, 65, 248, 180, 1, 16, 6, 32, 7, 16,
    1, 11, 0, 187, 1, 4, 110, 97, 109, 101, 1, 78, 7, 0, 7, 103, 101, 116, 95, 116,
    97, 103, 1, 6, 100, 101, 99, 114, 101, 102, 2, 6, 105, 110, 99, 114, 101, 102,
    3, 4, 102, 114, 101, 101, 4, 14, 117, 105, 110, 116, 95, 116, 111, 95, 115, 116,
    114, 105, 110, 103, 5, 16, 115, 116, 114, 105, 110, 103, 95, 116, 111, 95, 115,
    116, 114, 105, 110, 103, 6, 10, 97, 100, 100, 95, 115, 116, 114, 105, 110, 103,
    2, 100, 1, 7, 15, 0, 8, 115, 101, 108, 101, 99, 116, 111, 114, 1, 4, 110, 97,
    109, 101, 2, 3, 105, 100, 120, 3, 5, 73, 110, 100, 101, 120, 4, 4, 105, 100,
    120, 50, 5, 4, 78, 97, 109, 101, 6, 5, 110, 97, 109, 101, 50, 7, 4, 116, 109,
    112, 48, 8, 4, 116, 109, 112, 49, 9, 4, 116, 109, 112, 50, 10, 4, 116, 109, 112,
    51, 11, 5, 102, 105, 101, 108, 100, 12, 3, 99, 110, 116, 13, 7, 110, 101, 119,
    95, 99, 110, 116, 14, 3, 116, 97, 103,
  ])
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected selector formatter binary-path ssa-nomerge success, got \{err}",
      )
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected selector formatter binary-path output to validate, got \{@validate.validation_error_message(err)}",
      )
  }
  let encoded = match @binary.encode_module(optimized) {
    Ok(bytes) => bytes
    Err(err) =>
      fail("expected selector formatter binary-path encode success, got \{err}")
  }
  let reparsed = match @binary.decode_module(encoded) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected selector formatter binary-path reparse success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_defined_func(reparsed, 7)
  let writes = ssa_test_local_write_indices(instrs)
  assert_true(
    locals.length() <= 22,
    msg=locals.to_string() + "\n" + instrs.to_string(),
  )
  assert_true(writes.any(fn(idx) { idx == 19U }), msg=instrs.to_string())
  assert_false(writes.any(fn(idx) { idx == 23U }), msg=instrs.to_string())
}

///|
test "ssa-nomerge artifact parity freshens allocator unlink load temps" {
  // Artifact repro from the checked-in debug-WASI artifact, current first
  // canonical difference after `tlsf/searchBlock`, `defined=1 abs=28`. Binaryen
  // freshens the allocator unlink loads and bitmap update temps into appended
  // locals; Starshine must not keep reusing earlier value-if/body scratch locals
  // unless a measured Starshine win is documented.
  let source =
    #|(module
    #|  (memory 1)
    #|  (func (param $0 i32) (param $1 i32)
    #|    (local $2 i32) (local $3 i32) (local $4 i32) (local $5 i32)
    #|    local.get $1
    #|    i32.load align=1
    #|    i32.const -4
    #|    i32.and
    #|    local.tee $2
    #|    i32.const 256
    #|    i32.lt_u
    #|    if (result i32)
    #|      local.get $2
    #|      i32.const 4
    #|      i32.shr_u
    #|      local.set $3
    #|      i32.const 0
    #|    else
    #|      i32.const 31
    #|      i32.const 1073741820
    #|      local.get $2
    #|      local.get $2
    #|      i32.const 1073741820
    #|      i32.ge_u
    #|      select
    #|      local.tee $3
    #|      i32.clz
    #|      i32.sub
    #|      local.set $2
    #|      local.get $3
    #|      local.get $2
    #|      i32.const 4
    #|      i32.sub
    #|      i32.shr_u
    #|      i32.const 16
    #|      i32.xor
    #|      local.set $3
    #|      local.get $2
    #|      i32.const 7
    #|      i32.sub
    #|    end
    #|    local.set $5
    #|    local.get $1
    #|    i32.load offset=8 align=1
    #|    local.set $2
    #|    local.get $1
    #|    i32.load offset=4 align=1
    #|    local.tee $4
    #|    if
    #|      local.get $4
    #|      local.get $2
    #|      i32.store offset=8 align=1
    #|    end
    #|    local.get $2
    #|    if
    #|      local.get $2
    #|      local.get $4
    #|      i32.store offset=4 align=1
    #|    end
    #|    local.get $1
    #|    local.get $0
    #|    local.get $5
    #|    i32.const 4
    #|    i32.shl
    #|    local.get $3
    #|    i32.add
    #|    i32.const 2
    #|    i32.shl
    #|    i32.add
    #|    local.tee $4
    #|    i32.load offset=96 align=1
    #|    i32.eq
    #|    if
    #|      local.get $4
    #|      local.get $2
    #|      i32.store offset=96 align=1
    #|      local.get $2
    #|      i32.eqz
    #|      if
    #|        local.get $0
    #|        local.get $5
    #|        i32.const 2
    #|        i32.shl
    #|        i32.add
    #|        local.tee $1
    #|        local.get $1
    #|        i32.load offset=4 align=1
    #|        i32.const -2
    #|        local.get $3
    #|        i32.rotl
    #|        i32.and
    #|        local.tee $1
    #|        i32.store offset=4 align=1
    #|        local.get $1
    #|        i32.eqz
    #|        if
    #|          local.get $0
    #|          local.get $0
    #|          i32.load align=1
    #|          i32.const -2
    #|          local.get $5
    #|          i32.rotl
    #|          i32.and
    #|          i32.store align=1
    #|        end
    #|      end
    #|    end)
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() >= 11, msg=locals.to_string())
  let write_indices = ssa_test_local_write_indices(instrs)
  assert_true(write_indices.any(fn(idx) { idx == 12U }), msg=instrs.to_string())
}

///|
test "ssa-nomerge artifact parity limits allocator insertBlock call scratch temps" {
  // Artifact repro from the checked-in debug-WASI artifact, current first
  // canonical difference after `tlsf/removeBlock`, `defined=2 abs=29`
  // (`tlsf/insertBlock`). Binaryen freshens the top-level `block + 4` address,
  // allocator size-class result, and bitmap-update temps, but does not keep
  // freshening every repeated body-local scratch write across the call-bearing
  // unlink prefix. The broader shape has no measured Starshine win and bloats
  // the artifact, so keep this neighborhood from over-allocating scratch locals
  // while exact artifact parity remains open.
  let source =
    #|(module
    #|  (memory 1)
    #|  (func (param $0 i32) (param $1 i32)
    #|    (local $2 i32) (local $3 i32) (local $4 i32) (local $5 i32)
    #|    local.get $1
    #|    i32.load align=1
    #|    local.tee $4
    #|    local.set $3
    #|    local.get $1
    #|    i32.const 4
    #|    i32.add
    #|    local.tee $5
    #|    local.get $4
    #|    i32.const -4
    #|    i32.and
    #|    i32.add
    #|    local.tee $2
    #|    i32.load align=1
    #|    local.tee $4
    #|    i32.const 1
    #|    i32.and
    #|    if
    #|      local.get $0
    #|      local.get $2
    #|      call $removeBlock
    #|      local.get $1
    #|      local.get $3
    #|      i32.const 4
    #|      i32.add
    #|      local.get $4
    #|      i32.const -4
    #|      i32.and
    #|      i32.add
    #|      local.tee $3
    #|      i32.store align=1
    #|      local.get $1
    #|      i32.load align=1
    #|      i32.const -4
    #|      i32.and
    #|      local.get $5
    #|      i32.add
    #|      local.tee $2
    #|      i32.load align=1
    #|      local.set $4
    #|    end
    #|    local.get $3
    #|    i32.const 2
    #|    i32.and
    #|    if
    #|      local.get $1
    #|      i32.const 4
    #|      i32.sub
    #|      i32.load align=1
    #|      local.tee $1
    #|      i32.load align=1
    #|      local.set $5
    #|      local.get $0
    #|      local.get $1
    #|      call $removeBlock
    #|      local.get $1
    #|      local.get $5
    #|      i32.const 4
    #|      i32.add
    #|      local.get $3
    #|      i32.const -4
    #|      i32.and
    #|      i32.add
    #|      local.tee $3
    #|      i32.store align=1
    #|    end
    #|    local.get $2
    #|    local.get $4
    #|    i32.const 2
    #|    i32.or
    #|    i32.store align=1
    #|    local.get $2
    #|    i32.const 4
    #|    i32.sub
    #|    local.get $1
    #|    i32.store align=1
    #|    local.get $3
    #|    i32.const -4
    #|    i32.and
    #|    local.tee $2
    #|    i32.const 256
    #|    i32.lt_u
    #|    if (result i32)
    #|      local.get $2
    #|      i32.const 4
    #|      i32.shr_u
    #|      local.set $2
    #|      i32.const 0
    #|    else
    #|      i32.const 31
    #|      i32.const 1073741820
    #|      local.get $2
    #|      local.get $2
    #|      i32.const 1073741820
    #|      i32.ge_u
    #|      select
    #|      local.tee $2
    #|      i32.clz
    #|      i32.sub
    #|      local.set $3
    #|      local.get $2
    #|      local.get $3
    #|      i32.const 4
    #|      i32.sub
    #|      i32.shr_u
    #|      i32.const 16
    #|      i32.xor
    #|      local.set $2
    #|      local.get $3
    #|      i32.const 7
    #|      i32.sub
    #|    end
    #|    local.set $3
    #|    local.get $0
    #|    local.get $3
    #|    i32.const 4
    #|    i32.shl
    #|    local.get $2
    #|    i32.add
    #|    i32.const 2
    #|    i32.shl
    #|    i32.add
    #|    i32.load offset=96 align=1
    #|    local.set $4
    #|    local.get $1
    #|    i32.const 0
    #|    i32.store offset=4 align=1
    #|    local.get $1
    #|    local.get $4
    #|    i32.store offset=8 align=1
    #|    local.get $4
    #|    if
    #|      local.get $4
    #|      local.get $1
    #|      i32.store offset=4 align=1
    #|    end
    #|    local.get $0
    #|    local.get $3
    #|    i32.const 4
    #|    i32.shl
    #|    local.get $2
    #|    i32.add
    #|    i32.const 2
    #|    i32.shl
    #|    i32.add
    #|    local.get $1
    #|    i32.store offset=96 align=1
    #|    local.get $0
    #|    local.get $0
    #|    i32.load align=1
    #|    i32.const 1
    #|    local.get $3
    #|    i32.shl
    #|    i32.or
    #|    i32.store align=1
    #|    local.get $0
    #|    local.get $3
    #|    i32.const 2
    #|    i32.shl
    #|    i32.add
    #|    local.tee $0
    #|    local.get $0
    #|    i32.load offset=4 align=1
    #|    i32.const 1
    #|    local.get $2
    #|    i32.shl
    #|    i32.or
    #|    i32.store offset=4 align=1)
    #|  (func $removeBlock (param i32 i32))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  let write_indices = ssa_test_local_write_indices(instrs)
  let root_add_tees = ssa_test_root_i32_add_local_tee_targets(instrs)
  assert_true(
    root_add_tees.any(fn(idx) { idx == 6U }),
    msg=root_add_tees.to_string() + "\n" + instrs.to_string(),
  )
  let set_indices = ssa_test_local_set_indices(instrs)
  assert_true(set_indices.any(fn(idx) { idx == 7U }), msg=instrs.to_string())
  let root_and_tees = ssa_test_root_i32_and_local_tee_targets(instrs)
  assert_true(
    root_and_tees.any(fn(idx) { idx == 2U }),
    msg=root_and_tees.to_string() + "\n" + instrs.to_string(),
  )
  let i32_sub_sets = ssa_test_i32_sub_local_set_targets(instrs)
  assert_true(
    i32_sub_sets.any(fn(idx) { idx == 3U }),
    msg=i32_sub_sets.to_string() + "\n" + instrs.to_string(),
  )
  assert_true(locals.length() <= 13, msg=locals.to_string())
  assert_false(
    write_indices.any(fn(idx) { idx == 14U }),
    msg=instrs.to_string(),
  )
  assert_true(write_indices.any(fn(idx) { idx == 8U }), msg=instrs.to_string())
}

///|
test "ssa-nomerge artifact parity freshens parameter scratch writes in nested unlink" {
  // Artifact repro reduced from
  // `.tmp/self-ssa-nomerge-debug-wasi-bronull-prefix-subtype-results`, sampled
  // canonical difference `defined=0 abs=28` (`tlsf/removeBlock`). Binaryen does
  // not write back to parameter locals for nested unlink scratch values; it
  // appends fresh body locals for the address and masked-word temporaries. A
  // raw Starshine reuse of `param 1` has no measured win, so keep Binaryen's
  // no-parameter-write shape for this family.
  let source =
    #|(module
    #|  (memory 1)
    #|  (func (param i32 i32)
    #|    (local i32 i32 i32 i32)
    #|    local.get 1
    #|    i32.load
    #|    i32.const -4
    #|    i32.and
    #|    local.tee 2
    #|    i32.const 256
    #|    i32.lt_u
    #|    if (result i32)
    #|      local.get 2
    #|      i32.const 4
    #|      i32.shr_u
    #|      local.set 3
    #|      i32.const 0
    #|    else
    #|      i32.const 31
    #|      local.get 2
    #|      i32.clz
    #|      i32.sub
    #|      local.set 2
    #|      local.get 2
    #|      i32.const 7
    #|      i32.sub
    #|    end
    #|    local.set 5
    #|    local.get 1
    #|    i32.load offset=8
    #|    local.set 2
    #|    local.get 1
    #|    i32.load offset=4
    #|    local.tee 4
    #|    if
    #|      local.get 4
    #|      local.get 2
    #|      i32.store offset=8
    #|      local.get 2
    #|      if
    #|        local.get 2
    #|        local.get 4
    #|        i32.store offset=4
    #|        local.get 0
    #|        local.get 5
    #|        i32.const 2
    #|        i32.shl
    #|        i32.add
    #|        local.tee 1
    #|        local.get 1
    #|        i32.load offset=4
    #|        i32.const -2
    #|        local.get 3
    #|        i32.rotl
    #|        i32.and
    #|        local.tee 1
    #|        i32.store offset=4
    #|        local.get 1
    #|        i32.eqz
    #|        if
    #|          local.get 0
    #|          local.get 0
    #|          i32.load
    #|          i32.const -2
    #|          local.get 5
    #|          i32.rotl
    #|          i32.and
    #|          i32.store
    #|        end
    #|      end
    #|    end))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() >= 6, msg=locals.to_string())
  assert_false(
    ssa_test_local_write_indices(instrs).any(fn(idx) { idx < 2U }),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge artifact parity freshens split-memory body scratch locals" {
  // Artifact repro reduced from
  // `.tmp/self-ssa-nomerge-debug-wasi-bronull-prefix-subtype-results`, sampled
  // canonical difference `defined=0 abs=30`. Binaryen freshens the derived split
  // size and new-block address temporaries before the nested stores and call;
  // Starshine reused one body-local scratch for all of them with no proven win.
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $insertBlock (param i32 i32))
    #|  (func (param i32 i32 i64)
    #|    (local i32 i32 i32)
    #|    local.get 0
    #|    i32.load offset=1568
    #|    local.tee 4
    #|    i32.const 0
    #|    local.get 1
    #|    i32.const 19
    #|    i32.add
    #|    i32.const -16
    #|    i32.and
    #|    i32.const 4
    #|    i32.sub
    #|    local.tee 1
    #|    i32.const 16
    #|    i32.sub
    #|    local.tee 3
    #|    local.get 4
    #|    i32.eq
    #|    select
    #|    if
    #|      local.get 4
    #|      i32.load
    #|      local.set 5
    #|      local.get 3
    #|      local.set 1
    #|    end
    #|    local.get 2
    #|    i32.wrap_i64
    #|      i32.const -16
    #|      i32.and
    #|      local.get 1
    #|      i32.sub
    #|      local.tee 3
    #|      i32.const 20
    #|      i32.lt_u
    #|      if
    #|        return
    #|      end
    #|      local.get 1
    #|      local.get 5
    #|      i32.const 2
    #|      i32.and
    #|      local.get 3
    #|      i32.const 8
    #|      i32.sub
    #|      local.tee 3
    #|      i32.const 1
    #|      i32.or
    #|      i32.or
    #|      i32.store
    #|      local.get 1
    #|      i32.const 0
    #|      i32.store offset=4
    #|      local.get 1
    #|      i32.const 0
    #|      i32.store offset=8
    #|      local.get 1
    #|      i32.const 4
    #|      i32.add
    #|      local.get 3
    #|      i32.add
    #|      local.tee 3
    #|      i32.const 2
    #|      i32.store
    #|      local.get 0
    #|      local.get 3
    #|      i32.store offset=1568
    #|      local.get 0
    #|      local.get 1
    #|      call $insertBlock)
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() >= 7, msg=locals.to_string())
  assert_false(
    ssa_test_local_write_indices(instrs).any(fn(idx) { idx == 3U }),
    msg=instrs.to_string(),
  )
  let set_indices = ssa_test_local_set_indices(instrs)
  assert_true(set_indices.any(fn(idx) { idx == 1U }), msg=instrs.to_string())
  assert_true(set_indices.any(fn(idx) { idx == 5U }), msg=instrs.to_string())
}

///|
test "ssa-nomerge artifact parity preserves loop branch parameter updates" {
  // Artifact repro from checked-in debug-WASI after the split-memory malloc
  // branch-merge fix, first canonical difference `defined=19 abs=46`. Binaryen
  // keeps the pointer bump updates on the original parameter locals across the
  // loop backedge; fresh scratch locals leave the loop-carried values stale.
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $len (param i32) (result i32)
    #|    local.get 0)
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i64)
    #|    local.get 0
    #|    call $len
    #|    local.set 2
    #|    local.get 2
    #|    local.get 1
    #|    call $len
    #|    i32.ne
    #|    if
    #|      i32.const 0
    #|      return
    #|    end
    #|    loop
    #|      local.get 2
    #|      i32.const 8
    #|      i32.ge_s
    #|      if
    #|        local.get 0
    #|        i64.load offset=8
    #|        local.get 1
    #|        i64.load offset=8
    #|        i64.ne
    #|        if
    #|          i32.const 0
    #|          return
    #|        end
    #|        local.get 2
    #|        i32.const 8
    #|        i32.sub
    #|        local.set 2
    #|        local.get 0
    #|        i32.const 8
    #|        i32.add
    #|        local.set 0
    #|        local.get 1
    #|        i32.const 8
    #|        i32.add
    #|        local.set 1
    #|        br 1
    #|      end
    #|    end
    #|    local.get 2
    #|    i32.const 0
    #|    i32.gt_s
    #|    if (result i32)
    #|      i64.const 1
    #|      local.get 2
    #|      i32.const 3
    #|      i32.shl
    #|      i64.extend_i32_u
    #|      i64.shl
    #|      i64.const 1
    #|      i64.sub
    #|      local.set 3
    #|      local.get 0
    #|      i64.load offset=8
    #|      local.get 3
    #|      i64.and
    #|      local.get 1
    #|      i64.load offset=8
    #|      local.get 3
    #|      i64.and
    #|      i64.eq
    #|    else
    #|      i32.const 1
    #|    end)
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (_, instrs) = try! ssa_test_defined_func(optimized, 1)
  let set_indices = ssa_test_local_set_indices(instrs)
  assert_true(set_indices.any(fn(idx) { idx == 0U }), msg=instrs.to_string())
  assert_true(set_indices.any(fn(idx) { idx == 1U }), msg=instrs.to_string())
  assert_false(set_indices.any(fn(idx) { idx == 4U }), msg=instrs.to_string())
  assert_false(set_indices.any(fn(idx) { idx == 5U }), msg=instrs.to_string())
}

///|
test "ssa-nomerge artifact parity freshens tee-set loop base scratch" {
  // Artifact repro reduced from
  // `.tmp/self-ssa-nomerge-debug-wasi-bronull-prefix-subtype-results`, sampled
  // canonical difference `defined=0 abs=50` (`moonbit.unsafe_make_string`).
  // Binaryen keeps the allocation result tee and the loop base pointer in
  // separate fresh locals before the store loop; Starshine reused the original
  // body-local slot with no proven benefit.
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $make (param i32) (result i32)
    #|    local.get 0)
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32)
    #|    local.get 0
    #|    call $make
    #|    local.tee 2
    #|    local.set 2
    #|    loop
    #|      local.get 3
    #|      local.get 0
    #|      i32.lt_s
    #|      if
    #|        local.get 2
    #|        local.get 3
    #|        i32.const 1
    #|        i32.shl
    #|        i32.add
    #|        local.get 1
    #|        i32.store16 offset=8 align=1
    #|        local.get 3
    #|        i32.const 1
    #|        i32.add
    #|        local.set 3
    #|        br 1
    #|      end
    #|    end
    #|    local.get 2))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() >= 4, msg=locals.to_string())
  assert_true(
    ssa_test_local_write_indices(instrs).any(fn(idx) { idx == 5U }),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_local_write_indices(instrs).any(fn(idx) { idx == 2U }),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge artifact parity lowers loop-param block-branch scratch" {
  // Artifact repro reduced from
  // `.tmp/self-ssa-nomerge-debug-wasi-bronull-prefix-subtype-results`, sampled
  // canonical difference `defined=0 abs=111` (`spec/failed_preview`). Binaryen
  // lowers this loop-carried i32 param through a fresh scratch local even though
  // the loop body contains nested value blocks with internal branches. Keeping
  // the typed loop leaves Starshine with a smaller, unproven local allocation
  // shape, so this locks the Binaryen-like scratch write.
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $mk (param i32) (result i32) local.get 0)
    #|  (func $dropref (param i32))
    #|  (func $kind (param i32) (result i32) local.get 0)
    #|  (func $join (param i32 i32) (result i32) local.get 0)
    #|  (func $use (param i32 i32))
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|    i32.const 10080
    #|    local.set 28
    #|    i32.const 8
    #|    call $mk
    #|    local.tee 38
    #|    i32.const 1573120
    #|    i32.store offset=4
    #|    local.get 38
    #|    i32.const 0
    #|    i32.store offset=8
    #|    local.get 38
    #|    local.get 28
    #|    i32.store offset=12
    #|    local.get 38
    #|    local.set 2
    #|    local.get 0
    #|    i32.load offset=24
    #|    local.set 30
    #|    local.get 30
    #|    local.tee 3
    #|    i32.load offset=8
    #|    local.set 4
    #|    i32.const 0
    #|    loop (param i32)
    #|      local.tee 5
    #|      local.get 4
    #|      i32.lt_s
    #|      if
    #|        local.get 3
    #|        i32.load offset=12
    #|        local.tee 19
    #|        local.get 5
    #|        i32.const 2
    #|        i32.shl
    #|        i32.add
    #|        i32.load offset=8
    #|        local.set 6
    #|        block $out (result i32)
    #|          block $inner
    #|            local.get 6
    #|            i32.load offset=24
    #|            local.tee 8
    #|            call $kind
    #|            local.tee 37
    #|            i32.const 2
    #|            i32.eq
    #|            if
    #|              local.get 8
    #|              local.tee 9
    #|              i32.load offset=8
    #|              local.tee 10
    #|              call $dropref
    #|              local.get 6
    #|              call $dropref
    #|              local.get 10
    #|              local.set 7
    #|              br $inner
    #|            else
    #|              i32.const 0
    #|              drop
    #|            end
    #|            i32.const 0
    #|            br $out
    #|          end
    #|          i32.const 1
    #|        end
    #|        drop
    #|        local.get 6
    #|        i32.load offset=20
    #|        local.set 29
    #|        local.get 29
    #|        local.tee 17
    #|        call $kind
    #|        local.tee 16
    #|        i32.const 11400
    #|        call $join
    #|        local.get 16
    #|        call $dropref
    #|        local.set 14
    #|        local.get 7
    #|        call $kind
    #|        local.set 15
    #|        local.get 14
    #|        local.get 15
    #|        call $join
    #|        local.get 15
    #|        call $dropref
    #|        local.get 14
    #|        call $dropref
    #|        local.set 13
    #|        local.get 2
    #|        call $dropref
    #|        local.get 2
    #|        local.get 13
    #|        call $use
    #|        local.get 5
    #|        i32.const 1
    #|        i32.add
    #|        local.tee 18
    #|        br 1
    #|      else
    #|        local.get 3
    #|        call $dropref
    #|      end
    #|    end
    #|    i32.const 0))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 5)
  assert_true(locals.length() >= 38, msg=locals.to_string())
  let writes = ssa_test_local_write_indices(instrs)
  assert_true(writes.any(fn(idx) { idx == 39U }), msg=instrs.to_string())
  assert_true(
    writes.any(fn(idx) { idx == 38U }) && writes.any(fn(idx) { idx == 3U }),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge artifact parity freshens memory growth page temporaries only" {
  // Artifact repro reduced from
  // `.tmp/self-ssa-nomerge-debug-wasi-bronull-prefix-subtype-results`, sampled
  // canonical difference `defined=0 abs=31` (`tlsf/initialize`). Binaryen
  // freshens the pre-loop memory-size/page-count temps but keeps the loop
  // induction locals canonical; do not let repeated-store freshening spill the
  // induction locals beyond Binaryen's local budget.
  let source =
    #|(module
    #|  (memory 1)
    #|  (global (mut i32) (i32.const 0))
    #|  (func $addMemory (param i32 i32 i64))
    #|  (func
    #|    (local i32 i32 i32)
    #|    i32.const 220368
    #|    i32.const 15
    #|    i32.add
    #|    i32.const -16
    #|    i32.and
    #|    local.set 0
    #|    memory.size
    #|    local.tee 1
    #|    local.get 0
    #|    i32.const 67107
    #|    i32.add
    #|    i32.const -65536
    #|    i32.and
    #|    i32.const 16
    #|    i32.shr_u
    #|    local.tee 2
    #|    i32.lt_s
    #|    if (result i32)
    #|      local.get 2
    #|      local.get 1
    #|      i32.sub
    #|      memory.grow
    #|      i32.const 0
    #|      i32.lt_s
    #|    else
    #|      i32.const 0
    #|    end
    #|    if
    #|      unreachable
    #|    else
    #|      local.get 0
    #|      i32.const 0
    #|      i32.store
    #|      local.get 0
    #|      i32.const 0
    #|      i32.store offset=1568
    #|      i32.const 0
    #|      local.set 1
    #|      loop
    #|        local.get 1
    #|        i32.const 23
    #|        i32.lt_u
    #|        if
    #|          local.get 0
    #|          local.get 1
    #|          i32.const 2
    #|          i32.shl
    #|          i32.add
    #|          i32.const 0
    #|          i32.store offset=4
    #|          i32.const 0
    #|          local.set 2
    #|          loop
    #|            local.get 2
    #|            i32.const 16
    #|            i32.lt_u
    #|            if
    #|              local.get 0
    #|              local.get 1
    #|              i32.const 4
    #|              i32.shl
    #|              local.get 2
    #|              i32.add
    #|              i32.const 2
    #|              i32.shl
    #|              i32.add
    #|              i32.const 0
    #|              i32.store offset=96
    #|              local.get 2
    #|              i32.const 1
    #|              i32.add
    #|              local.set 2
    #|              br 1
    #|            end
    #|          end
    #|          local.get 1
    #|          i32.const 1
    #|          i32.add
    #|          local.set 1
    #|          br 1
    #|        end
    #|      end
    #|      local.get 0
    #|      local.get 0
    #|      i32.const 1572
    #|      i32.add
    #|      memory.size
    #|      i64.extend_i32_s
    #|      i64.const 16
    #|      i64.shl
    #|      call $addMemory
    #|      local.get 0
    #|      global.set 0
    #|    end))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() >= 5, msg=locals.to_string())
  assert_false(
    ssa_test_local_write_indices(instrs).any(fn(idx) { idx > 4U }),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_local_write_indices(instrs).any(fn(idx) { idx == 3U }) &&
    ssa_test_local_write_indices(instrs).any(fn(idx) { idx == 4U }),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge artifact parity freshens malloc split and grow temporaries" {
  // Artifact repro reduced from
  // `.tmp/self-ssa-nomerge-debug-wasi-bronull-prefix-subtype-results`, sampled
  // canonical difference `defined=0 abs=32` (`moonbit.malloc`). Binaryen
  // allocates distinct temporaries for the allocator base, requested size,
  // memory-size/grow pages, split remainder, split block pointer, and coalesced
  // block-size slots. Reusing the canonical five-body-local shape has no proven
  // Starshine benefit, so keep matching Binaryen's fresh allocator scratch
  // shape when the grow path and split/coalesce stores appear together.
  let source =
    #|(module
    #|  (memory 1)
    #|  (global (mut i32) (i32.const 0))
    #|  (func $tlsf.searchBlock (param i32 i32) (result i32)
    #|    i32.const 0)
    #|  (func $tlsf.unlinkBlock (param i32 i32))
    #|  (func $tlsf.insertBlock (param i32 i32))
    #|  (func $addMemory (param i32 i32 i64))
    #|  (func $malloc (param i32) (result i32)
    #|    (local i32 i32 i32 i32)
    #|    global.get 0
    #|    i32.eqz
    #|    if
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    i32.const 1073741820
    #|    i32.gt_u
    #|    if
    #|      unreachable
    #|    end
    #|    global.get 0
    #|    local.tee 2
    #|    local.get 0
    #|    i32.const 12
    #|    i32.le_u
    #|    if (result i32)
    #|      i32.const 12
    #|    else
    #|      local.get 0
    #|      i32.const 19
    #|      i32.add
    #|      i32.const -16
    #|      i32.and
    #|      i32.const 4
    #|      i32.sub
    #|    end
    #|    local.tee 1
    #|    call $tlsf.searchBlock
    #|    local.tee 0
    #|    i32.eqz
    #|    if
    #|      memory.size
    #|      local.tee 0
    #|      local.get 1
    #|      i32.const 256
    #|      i32.ge_u
    #|      if (result i32)
    #|        local.get 1
    #|        i32.const 536870910
    #|        i32.lt_u
    #|        if (result i32)
    #|          local.get 1
    #|          i32.const 1
    #|          i32.const 27
    #|          local.get 1
    #|          i32.clz
    #|          i32.sub
    #|          i32.shl
    #|          i32.add
    #|          i32.const 1
    #|          i32.sub
    #|        else
    #|          local.get 1
    #|        end
    #|      else
    #|        local.get 1
    #|      end
    #|      i32.const 4
    #|      local.get 2
    #|      i32.load offset=1568
    #|      local.get 0
    #|      i32.const 16
    #|      i32.shl
    #|      i32.const 4
    #|      i32.sub
    #|      i32.ne
    #|      i32.shl
    #|      i32.add
    #|      i32.const 65535
    #|      i32.add
    #|      i32.const -65536
    #|      i32.and
    #|      i32.const 16
    #|      i32.shr_u
    #|      local.tee 3
    #|      local.get 0
    #|      local.get 3
    #|      i32.gt_s
    #|      select
    #|      memory.grow
    #|      i32.const 0
    #|      i32.lt_s
    #|      if
    #|        local.get 3
    #|        memory.grow
    #|        i32.const 0
    #|        i32.lt_s
    #|        if
    #|          unreachable
    #|        end
    #|      end
    #|      local.get 2
    #|      local.get 0
    #|      i32.const 16
    #|      i32.shl
    #|      memory.size
    #|      i64.extend_i32_s
    #|      i64.const 16
    #|      i64.shl
    #|      call $addMemory
    #|      local.get 2
    #|      local.get 1
    #|      call $tlsf.searchBlock
    #|      local.set 0
    #|    end
    #|    local.get 2
    #|    local.get 0
    #|    call $tlsf.unlinkBlock
    #|    local.get 0
    #|    i32.load
    #|    local.tee 3
    #|    i32.const -4
    #|    i32.and
    #|    local.get 1
    #|    i32.sub
    #|    local.tee 4
    #|    i32.const 16
    #|    i32.ge_u
    #|    if
    #|      local.get 0
    #|      local.get 1
    #|      local.get 3
    #|      i32.const 2
    #|      i32.and
    #|      i32.or
    #|      i32.store
    #|      local.get 0
    #|      i32.const 4
    #|      i32.add
    #|      local.get 1
    #|      i32.add
    #|      local.tee 1
    #|      local.get 4
    #|      i32.const 4
    #|      i32.sub
    #|      i32.const 1
    #|      i32.or
    #|      i32.store
    #|      local.get 2
    #|      local.get 1
    #|      call $tlsf.insertBlock
    #|    else
    #|      local.get 0
    #|      local.get 3
    #|      i32.const -2
    #|      i32.and
    #|      i32.store
    #|      local.get 0
    #|      i32.const 4
    #|      i32.add
    #|      local.tee 1
    #|      local.get 0
    #|      i32.load
    #|      i32.const -4
    #|      i32.and
    #|      local.tee 2
    #|      i32.add
    #|      local.get 1
    #|      local.get 2
    #|      i32.add
    #|      i32.load
    #|      i32.const -3
    #|      i32.and
    #|      i32.store
    #|    end
    #|    local.get 0
    #|    i32.const 4
    #|    i32.add)
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 4)
  assert_true(locals.length() >= 11, msg=locals.to_string())
  let writes = ssa_test_local_write_indices(instrs)
  assert_false(writes.any(fn(idx) { idx > 11U }), msg=instrs.to_string())
  assert_true(
    writes.any(fn(idx) { idx == 10U }) && writes.any(fn(idx) { idx == 11U }),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge artifact parity freshens table growth slot temporaries" {
  // Artifact repro reduced from
  // `.tmp/self-ssa-nomerge-debug-wasi-bronull-prefix-subtype-results`, sampled
  // canonical difference `defined=0 abs=59` (`moonbit.alloc_externref`).
  // Binaryen freshens the table size and allocated slot temporaries around the
  // table growth/free-list update while preserving the grow-count loop local.
  let source =
    #|(module
    #|  (memory 1)
    #|  (table 0 externref)
    #|  (global (mut i32) (i32.const -1))
    #|  (func $malloc (param i32) (result i32)
    #|    local.get 0)
    #|  (func $alloc (param i32) (result i32)
    #|    local.get 0)
    #|  (func (param externref) (result i32)
    #|    (local i32 i32 i32 i32 i32)
    #|    global.get 0
    #|    local.tee 1
    #|    i32.const 0
    #|    i32.lt_s
    #|    if
    #|      table.size 0
    #|      local.set 3
    #|      local.get 3
    #|      i32.eqz
    #|      if (result i32)
    #|        i32.const 16
    #|      else
    #|        local.get 3
    #|        i32.const 1
    #|        i32.shl
    #|      end
    #|      local.set 5
    #|      ref.null extern
    #|      local.get 5
    #|      table.grow 0
    #|      i32.const 0
    #|      i32.lt_s
    #|      if
    #|        unreachable
    #|      end
    #|      loop
    #|        local.get 5
    #|        local.get 3
    #|        i32.gt_s
    #|        if
    #|          local.get 5
    #|          i32.const 1
    #|          i32.sub
    #|          local.set 5
    #|          i32.const 8
    #|          call $malloc
    #|          local.tee 2
    #|          local.get 5
    #|          i32.store
    #|          local.get 2
    #|          local.get 1
    #|          i32.store offset=4
    #|          local.get 2
    #|          local.set 1
    #|          br 1
    #|        end
    #|      end
    #|    end
    #|    local.get 1
    #|    i32.load offset=4
    #|    global.set 0
    #|    local.get 1
    #|    i32.load
    #|    local.set 3
    #|    local.get 3
    #|    local.get 0
    #|    table.set 0
    #|    i32.const 4
    #|    call $alloc
    #|    local.tee 4
    #|    i32.const 3
    #|    i32.const 30
    #|    i32.shl
    #|    i32.store offset=4
    #|    local.get 4
    #|    local.get 3
    #|    i32.store offset=8
    #|    local.get 4)
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 2)
  assert_true(locals.length() >= 7, msg=locals.to_string())
  assert_true(
    ssa_test_local_write_indices(instrs).any(fn(idx) { idx == 6U }) &&
    ssa_test_local_write_indices(instrs).any(fn(idx) { idx == 7U }),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_local_write_indices(instrs).any(fn(idx) { idx == 3U }),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_local_write_indices(instrs).any(fn(idx) { idx > 7U }),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge artifact parity keeps loop-carried result update in canonical local" {
  // Artifact repro reduced from
  // `.tmp/self-ssa-nomerge-debug-wasi-bronull-prefix-subtype-results`, sampled
  // canonical difference `defined=0 abs=37`. Binaryen rewrites the loop-carried
  // update with only the original body-local slot (`local 2`); Starshine used
  // to spill `local.get 2` through an unnecessary extra temp (`local 3`), adding
  // one local and one write with no proven Starshine benefit.
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $id (param i32) (result i32)
    #|    local.get 0)
    #|  (func (param i32 i32) (result i32)
    #|    (local i32)
    #|    local.get 0
    #|    call $id
    #|    local.get 1
    #|    call $id
    #|    i32.eq
    #|    if (result i32)
    #|      loop (result i32)
    #|        local.get 2
    #|        local.get 0
    #|        call $id
    #|        i32.lt_s
    #|        if (result i32)
    #|          local.get 0
    #|          local.get 2
    #|          i32.const 1
    #|          i32.shl
    #|          i32.add
    #|          i32.load16_u offset=8 align=1
    #|          local.get 1
    #|          local.get 2
    #|          i32.const 1
    #|          i32.shl
    #|          i32.add
    #|          i32.load16_u offset=8 align=1
    #|          i32.eq
    #|          if (result i32)
    #|            local.get 2
    #|            i32.const 1
    #|            i32.add
    #|            local.set 2
    #|            br 2
    #|          else
    #|            i32.const 0
    #|            return
    #|          end
    #|        else
    #|          i32.const 1
    #|          return
    #|        end
    #|      end
    #|    else
    #|      i32.const 0
    #|      return
    #|    end))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() <= 1, msg=locals.to_string())
  assert_false(
    ssa_test_local_write_indices(instrs).any(fn(idx) { idx == 3U }),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge artifact parity keeps gc free branch exits at Binaryen local budget" {
  // Artifact repro from
  // `.tmp/self-ssa-nomerge-debug-wasi-bronull-prefix-subtype-results`, sampled
  // canonical difference `defined=0 abs=57` (`moonbit.gc.free`). The saved
  // artifact has no typed result loop, so it is distinct from the abs37 loop
  // result guard: Binaryen appends four body locals for this branch-heavy free
  // walk, while Starshine used to append six. Until a measured Starshine win is
  // proven, keep the Binaryen local budget shape.
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $moonbit.decref (param i32))
    #|  (func $moonbit.drop_externref (param i32))
    #|  (func $moonbit.free (param i32))
    #|  (func $moonbit.gc.free (param $ptr i32)
    #|    (local $parent i32) (local $curr_child_offset i32) (local $remaining_children_count i32)
    #|    (local $n_ptr_fields i32) (local $ptr_fields_offset i32) (local $kind i32)
    #|    (local $ref_array_kind i32) (local $vt_ptr i32) (local $vt_ptr_index i32)
    #|    (local $vt_ptr_fields_offset i32) (local $vt_n_ptr_fields i32) (local $vt_header i32)
    #|    (local $meta i32) (local $next i32) (local $addr_of_next i32) (local $len i32) (local $count i32)
    #|    loop
    #|      local.get $ptr
    #|      i32.load offset=4 align=1
    #|      local.tee $meta
    #|      i32.const 30
    #|      i32.shr_u
    #|      local.set $kind
    #|      block
    #|        i32.const 0
    #|        local.get $kind
    #|        i32.eq
    #|        if
    #|          local.get $meta
    #|          i32.const 8
    #|          i32.shr_u
    #|          i32.const 2047
    #|          i32.and
    #|          local.tee $n_ptr_fields
    #|          i32.eqz
    #|          if
    #|          else
    #|            local.get $meta
    #|            i32.const 19
    #|            i32.shr_u
    #|            i32.const 2047
    #|            i32.and
    #|            local.set $ptr_fields_offset
    #|            local.get $ptr_fields_offset
    #|            local.set $curr_child_offset
    #|            local.get $n_ptr_fields
    #|            local.set $remaining_children_count
    #|            br 2
    #|          end
    #|        else
    #|          i32.const 2
    #|          local.get $kind
    #|          i32.eq
    #|          if
    #|            i32.const 3
    #|            local.get $meta
    #|            i32.const 28
    #|            i32.shr_u
    #|            i32.and
    #|            local.set $ref_array_kind
    #|            i32.const 1
    #|            local.get $ref_array_kind
    #|            i32.eq
    #|            if
    #|              local.get $meta
    #|              i32.const 268435455
    #|              i32.and
    #|              local.set $len
    #|              local.get $ptr
    #|              i32.const 8
    #|              i32.add
    #|              local.set $vt_ptr
    #|              local.get $vt_ptr
    #|              i32.load align=1
    #|              local.set $vt_header
    #|              i32.const 2047
    #|              local.get $vt_header
    #|              i32.const 8
    #|              i32.shr_u
    #|              i32.and
    #|              local.set $vt_n_ptr_fields
    #|              i32.const 2047
    #|              local.get $vt_header
    #|              i32.const 19
    #|              i32.shr_u
    #|              i32.and
    #|              local.set $vt_ptr_fields_offset
    #|              local.get $vt_ptr
    #|              i32.const 4
    #|              i32.add
    #|              local.set $vt_ptr
    #|              loop
    #|                local.get $len
    #|                i32.const 0
    #|                i32.gt_s
    #|                if
    #|                  local.get $len
    #|                  i32.const 1
    #|                  i32.sub
    #|                  local.set $len
    #|                  i32.const 0
    #|                  local.set $vt_ptr_index
    #|                  local.get $vt_ptr
    #|                  local.get $vt_ptr_fields_offset
    #|                  i32.const 4
    #|                  i32.mul
    #|                  i32.add
    #|                  local.set $vt_ptr
    #|                  loop
    #|                    local.get $vt_ptr_index
    #|                    local.get $vt_n_ptr_fields
    #|                    i32.lt_s
    #|                    if
    #|                      local.get $vt_ptr
    #|                      i32.load align=1
    #|                      i32.const 0
    #|                      i32.ne
    #|                      if
    #|                        local.get $vt_ptr
    #|                        i32.load align=1
    #|                        call $moonbit.decref
    #|                      end
    #|                      local.get $vt_ptr_index
    #|                      i32.const 1
    #|                      i32.add
    #|                      local.set $vt_ptr_index
    #|                      local.get $vt_ptr
    #|                      i32.const 4
    #|                      i32.add
    #|                      local.set $vt_ptr
    #|                      br 1
    #|                    end
    #|                  end
    #|                  br 1
    #|                end
    #|              end
    #|            else
    #|              local.get $meta
    #|              i32.const 268435455
    #|              i32.and
    #|              local.set $len
    #|              local.get $len
    #|              i32.const 0
    #|              i32.gt_s
    #|              if
    #|                i32.const 8
    #|                i32.const 2
    #|                i32.shr_u
    #|                local.set $curr_child_offset
    #|                local.get $len
    #|                local.set $remaining_children_count
    #|                br 4
    #|              end
    #|            end
    #|          else
    #|            i32.const 1
    #|            local.get $kind
    #|            i32.eq
    #|            if
    #|            else
    #|              i32.const 3
    #|              local.get $kind
    #|              i32.eq
    #|              if
    #|                local.get $ptr
    #|                call $moonbit.drop_externref
    #|              else
    #|                unreachable
    #|              end
    #|            end
    #|          end
    #|        end
    #|        local.get $ptr
    #|        call $moonbit.free
    #|        local.get $parent
    #|        i32.eqz
    #|        if
    #|          return
    #|        end
    #|        local.get $parent
    #|        i32.load align=1
    #|        local.set $curr_child_offset
    #|        local.get $parent
    #|        i32.load offset=4 align=1
    #|        local.set $remaining_children_count
    #|        local.get $parent
    #|        local.set $ptr
    #|        local.get $ptr
    #|        local.get $curr_child_offset
    #|        i32.const 4
    #|        i32.mul
    #|        i32.add
    #|        i32.load align=1
    #|        local.set $parent
    #|        local.get $curr_child_offset
    #|        i32.const 1
    #|        i32.add
    #|        local.set $curr_child_offset
    #|      end
    #|      loop
    #|        loop
    #|          local.get $remaining_children_count
    #|          i32.const 0
    #|          i32.gt_s
    #|          if
    #|            local.get $remaining_children_count
    #|            i32.const 1
    #|            i32.sub
    #|            local.set $remaining_children_count
    #|            local.get $ptr
    #|            local.get $curr_child_offset
    #|            i32.const 4
    #|            i32.mul
    #|            i32.add
    #|            local.tee $addr_of_next
    #|            i32.load align=1
    #|            local.tee $next
    #|            i32.eqz
    #|            if
    #|              local.get $curr_child_offset
    #|              i32.const 1
    #|              i32.add
    #|              local.set $curr_child_offset
    #|              br 2
    #|            end
    #|            local.get $next
    #|            i32.load align=1
    #|            local.tee $count
    #|            i32.const 1
    #|            i32.gt_s
    #|            if
    #|              local.get $next
    #|              local.get $count
    #|              i32.const 1
    #|              i32.sub
    #|              i32.store align=1
    #|            else
    #|              local.get $count
    #|              i32.const 1
    #|              i32.eq
    #|              if
    #|                local.get $remaining_children_count
    #|                i32.const 0
    #|                i32.eq
    #|                if
    #|                  local.get $ptr
    #|                  call $moonbit.free
    #|                else
    #|                  local.get $ptr
    #|                  local.get $curr_child_offset
    #|                  i32.store align=1
    #|                  local.get $ptr
    #|                  local.get $remaining_children_count
    #|                  i32.store offset=4 align=1
    #|                  local.get $addr_of_next
    #|                  local.get $parent
    #|                  i32.store align=1
    #|                  local.get $ptr
    #|                  local.set $parent
    #|                end
    #|                local.get $next
    #|                local.set $ptr
    #|                br 5
    #|              end
    #|            end
    #|            local.get $curr_child_offset
    #|            i32.const 1
    #|            i32.add
    #|            local.set $curr_child_offset
    #|            br 1
    #|          end
    #|        end
    #|        local.get $ptr
    #|        call $moonbit.free
    #|        local.get $parent
    #|        i32.eqz
    #|        if
    #|          return
    #|        end
    #|        local.get $parent
    #|        i32.load align=1
    #|        local.set $curr_child_offset
    #|        local.get $parent
    #|        i32.load offset=4 align=1
    #|        local.set $remaining_children_count
    #|        local.get $parent
    #|        local.set $ptr
    #|        local.get $ptr
    #|        local.get $curr_child_offset
    #|        i32.const 4
    #|        i32.mul
    #|        i32.add
    #|        i32.load align=1
    #|        local.set $parent
    #|        local.get $curr_child_offset
    #|        i32.const 1
    #|        i32.add
    #|        local.set $curr_child_offset
    #|        br 0
    #|      end
    #|      unreachable
    #|    end)
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 3)
  assert_true(locals.length() <= 21, msg=locals.to_string())
  let writes = ssa_test_local_write_indices(instrs)
  assert_true(writes.any(fn(idx) { idx == 18U }), msg=instrs.to_string())
  assert_true(writes.any(fn(idx) { idx == 20U }), msg=instrs.to_string())
  assert_true(writes.any(fn(idx) { idx == 21U }), msg=instrs.to_string())
  assert_false(writes.any(fn(idx) { idx > 21U }), msg=instrs.to_string())
}

///|
test "ssa-nomerge artifact parity preserves branch-carried refcount locals" {
  // Artifact repro from checked-in debug-WASI after the table-growth count-lane
  // fix, current first canonical difference `defined=55 abs=82`. The structured
  // early-return block carries the else-branch child reference through canonical
  // local $3 for later use; freshening that branch result to a temporary drops
  // the reaching value and leaves the post-block consumer on Binaryen's default
  // zero lane. Binaryen also keeps the paired refcount/load lanes on canonical
  // locals $10, $11, $12, and $23, so guard the full local budget here instead
  // of accepting a representation-only drift.
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $retain (param i32))
    #|  (func $release (param i32))
    #|  (func $free (param i32))
    #|  (func $make (param i32 i32 i32) (result i32) local.get 0)
    #|  (func $tag (param i32) (result i32) i32.const 2)
    #|  (func $stderr_bytes (param i32) (result i32) local.get 0)
    #|  (func $dispatch (param i32 i32) (result i32) local.get 1)
    #|  (func (param $a i32) (param $obj i32) (param $arg i32) (result i32)
    #|    (local $result i32) (local $callee i32) (local $made i32) (local $ptr i32)
    #|    (local $errtmp i32) (local $call_result i32) (local $stderr i32) (local $payload i32)
    #|    (local $child i32) (local $obj_count i32) (local $drop8 i32) (local $drop12 i32)
    #|    (local $drop16 i32) (local $drop20 i32) (local $drop24 i32) (local $drop28 i32)
    #|    (local $drop32 i32) (local $drop40 i32) (local $drop44 i32) (local $obj_dec i32)
    #|    (local $child_count i32) (local $child_dec i32) (local $status i32)
    #|    block
    #|      local.get $obj
    #|      call $retain
    #|      local.get $a
    #|      local.get $obj
    #|      local.get $arg
    #|      call $make
    #|      local.tee $made
    #|      call $tag
    #|      local.tee $status
    #|      i32.const 1
    #|      i32.eq
    #|      if (result i32)
    #|        local.get $made
    #|        call $release
    #|        local.get $obj
    #|        call $release
    #|        i32.const 0
    #|      else
    #|        local.get $made
    #|        local.tee $ptr
    #|        i32.load offset=8 align=1
    #|        local.set $child
    #|        local.get $ptr
    #|        i32.load align=1
    #|        local.tee $child_count
    #|        i32.const 1
    #|        i32.gt_s
    #|        if
    #|          local.get $child_count
    #|          i32.const 1
    #|          i32.sub
    #|          local.set $child_dec
    #|          local.get $ptr
    #|          local.get $child_dec
    #|          i32.store align=1
    #|          local.get $child
    #|          call $retain
    #|        else
    #|          local.get $child_count
    #|          i32.const 1
    #|          i32.eq
    #|          if
    #|            local.get $ptr
    #|            call $free
    #|          end
    #|        end
    #|        local.get $child
    #|        local.tee $errtmp
    #|        local.set $result
    #|        br 1
    #|      end
    #|      return
    #|    end
    #|    local.get $obj
    #|    i32.load offset=36 align=1
    #|    local.set $payload
    #|    local.get $obj
    #|    i32.load align=1
    #|    local.tee $obj_count
    #|    i32.const 1
    #|    i32.gt_s
    #|    if
    #|      local.get $obj_count
    #|      i32.const 1
    #|      i32.sub
    #|      local.set $obj_dec
    #|      local.get $obj
    #|      local.get $obj_dec
    #|      i32.store align=1
    #|      local.get $payload
    #|      call $retain
    #|    else
    #|      local.get $obj_count
    #|      i32.const 1
    #|      i32.eq
    #|      if
    #|        local.get $obj
    #|        i32.load offset=44 align=1
    #|        local.tee $drop44
    #|        call $release
    #|        local.get $obj
    #|        i32.load offset=40 align=1
    #|        local.tee $drop40
    #|        call $release
    #|        local.get $obj
    #|        i32.load offset=32 align=1
    #|        local.tee $drop32
    #|        call $release
    #|        local.get $obj
    #|        i32.load offset=28 align=1
    #|        local.tee $drop28
    #|        call $release
    #|        local.get $obj
    #|        i32.load offset=24 align=1
    #|        local.tee $drop24
    #|        call $release
    #|        local.get $obj
    #|        i32.load offset=20 align=1
    #|        local.tee $drop20
    #|        call $release
    #|        local.get $obj
    #|        i32.load offset=16 align=1
    #|        local.tee $drop16
    #|        call $release
    #|        local.get $obj
    #|        i32.load offset=12 align=1
    #|        local.tee $drop12
    #|        call $release
    #|        local.get $obj
    #|        i32.load offset=8 align=1
    #|        local.tee $drop8
    #|        call $release
    #|        local.get $obj
    #|        call $free
    #|      end
    #|    end
    #|    local.get $payload
    #|    local.set $callee
    #|    local.get $result
    #|    call $stderr_bytes
    #|    local.set $stderr
    #|    local.get $callee
    #|    local.get $stderr
    #|    call $dispatch
    #|    local.tee $call_result
    #|    call $release
    #|    i32.const 1)
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 7)
  let writes = ssa_test_local_write_indices(instrs)
  assert_true(locals.length() <= 35, msg=locals.to_string())
  assert_true(writes.any(fn(idx) { idx == 3U }), msg=instrs.to_string())
  assert_true(writes.any(fn(idx) { idx == 10U }), msg=instrs.to_string())
  assert_true(writes.any(fn(idx) { idx == 11U }), msg=instrs.to_string())
  assert_true(writes.any(fn(idx) { idx == 12U }), msg=instrs.to_string())
  assert_true(writes.any(fn(idx) { idx == 23U }), msg=instrs.to_string())
  let text = instrs.to_string()
  assert_true(text.contains("(local.get (Local 3)), (call (Func 5))"), msg=text)
  assert_false(writes.any(fn(idx) { idx > 37U }), msg=instrs.to_string())
}

///|
test "ssa-nomerge artifact parity preserves nested startup error local" {
  // Artifact repro from checked-in debug-WASI after the branch-carried refcount
  // fix, current first canonical difference `defined=70 abs=97`
  // (`cmd_try_trivial_startup_exit`). In the help/version output path,
  // Binaryen keeps the error payload that exits an inner block on the canonical
  // body local consumed by the following error formatting code. Freshening that
  // branch-carried write leaves the post-block `local.get` on an uninitialized
  // default lane, so this is a behavior-parity gap rather than harmless local
  // numbering drift.
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $retain (param i32))
    #|  (func $release (param i32))
    #|  (func $free (param i32))
    #|  (func $malloc (param i32) (result i32) local.get 0)
    #|  (func $tag (param i32) (result i32) i32.const 0)
    #|  (func $to_string (param i32) (result i32) local.get 0)
    #|  (func $add_string (param i32 i32) (result i32) local.get 1)
    #|  (func (param $io i32) (result i32)
    #|    (local $dummy i32) (local $err i32) (local $bind i32) (local $func i32) (local $result i32)
    #|    (local $e i32) (local $tmp_string i32) (local $tmp_prefixed i32)
    #|    (local $out_failed i32) (local $field i32) (local $cnt i32)
    #|    (local $new_cnt i32) (local $drop8 i32) (local $drop12 i32)
    #|    (local $drop16 i32) (local $drop20 i32) (local $drop24 i32)
    #|    (local $drop28 i32) (local $drop36 i32) (local $drop40 i32)
    #|    (local $drop44 i32) (local $ptr_a i32) (local $ptr_b i32)
    #|    (block (result i32)
    #|      block
    #|        local.get $io
    #|        i32.load offset=32 align=1
    #|        local.set $func
    #|        local.get $io
    #|        i32.load align=1
    #|        local.tee $cnt
    #|        i32.const 1
    #|        i32.gt_s
    #|        if
    #|          local.get $cnt
    #|          i32.const 1
    #|          i32.sub
    #|          local.set $new_cnt
    #|          local.get $io
    #|          local.get $new_cnt
    #|          i32.store align=1
    #|          local.get $func
    #|          call $retain
    #|        else
    #|          local.get $cnt
    #|          i32.const 1
    #|          i32.eq
    #|          if
    #|            local.get $io
    #|            i32.load offset=44 align=1
    #|            local.tee $drop44
    #|            call $release
    #|            local.get $io
    #|            i32.load offset=40 align=1
    #|            local.tee $drop40
    #|            call $release
    #|            local.get $io
    #|            i32.load offset=36 align=1
    #|            local.tee $drop36
    #|            call $release
    #|            local.get $io
    #|            i32.load offset=28 align=1
    #|            local.tee $drop28
    #|            call $release
    #|            local.get $io
    #|            i32.load offset=24 align=1
    #|            local.tee $drop24
    #|            call $release
    #|            local.get $io
    #|            i32.load offset=20 align=1
    #|            local.tee $drop20
    #|            call $release
    #|            local.get $io
    #|            i32.load offset=16 align=1
    #|            local.tee $drop16
    #|            call $release
    #|            local.get $io
    #|            i32.load offset=12 align=1
    #|            local.tee $drop12
    #|            call $release
    #|            local.get $io
    #|            i32.load offset=8 align=1
    #|            local.tee $drop8
    #|            call $release
    #|            local.get $io
    #|            call $free
    #|          end
    #|        end
    #|        i32.const 42
    #|        local.tee $bind
    #|        call $tag
    #|        i32.const 1
    #|        i32.eq
    #|        if (result i32)
    #|          local.get $bind
    #|          call $release
    #|          i32.const 4
    #|          call $malloc
    #|        else
    #|          local.get $bind
    #|          local.tee $e
    #|          i32.load offset=8 align=1
    #|          local.set $field
    #|          local.get $e
    #|          i32.load align=1
    #|          local.tee $cnt
    #|          i32.const 1
    #|          i32.gt_s
    #|          if
    #|            local.get $cnt
    #|            i32.const 1
    #|            i32.sub
    #|            local.set $new_cnt
    #|            local.get $e
    #|            local.get $new_cnt
    #|            i32.store align=1
    #|            local.get $field
    #|            call $retain
    #|          else
    #|            local.get $cnt
    #|            i32.const 1
    #|            i32.eq
    #|            if
    #|              local.get $e
    #|              call $free
    #|            end
    #|          end
    #|          local.get $field
    #|          local.tee $result
    #|          local.set $err
    #|          br 1
    #|        end
    #|        br 1
    #|      end
    #|      local.get $err
    #|      call $to_string
    #|      local.set $tmp_string
    #|      i32.const 12088
    #|      local.get $tmp_string
    #|      call $add_string
    #|      local.set $tmp_prefixed
    #|      i32.const 4
    #|      call $malloc
    #|      local.tee $ptr_a
    #|      i32.const 1048843
    #|      i32.store offset=4 align=1
    #|      local.get $ptr_a
    #|      local.get $tmp_prefixed
    #|      i32.store offset=8 align=1
    #|      local.get $ptr_a
    #|      local.set $out_failed
    #|      i32.const 4
    #|      call $malloc
    #|      local.tee $ptr_b
    #|      i32.const 1048832
    #|      i32.store offset=4 align=1
    #|      local.get $ptr_b
    #|      local.get $out_failed
    #|      i32.store offset=8 align=1
    #|      local.get $ptr_b
    #|    )
    #|    return)
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 7)
  let writes = ssa_test_local_write_indices(instrs)
  assert_true(locals.length() <= 35, msg=locals.to_string())
  assert_true(writes.any(fn(idx) { idx == 2U }), msg=instrs.to_string())
  let text = instrs.to_string()
  assert_true(text.contains("(local.get (Local 2))(call (Func 5))"), msg=text)
  assert_false(writes.any(fn(idx) { idx > 35U }), msg=instrs.to_string())
}

///|
test "ssa-nomerge artifact parity preserves adapter error across sibling block" {
  // Follow-up for checked-in debug-WASI after the startup-error local slice,
  // current first canonical difference `defined=73 abs=100`
  // (`lower_text_module_for_pipeline`). The first adapter branch exits an outer
  // block after writing the canonical adapter-error local; the following sibling
  // in-process block reads that local on both its success cleanup path and final
  // error-formatting suffix. Binaryen keeps the branch-carried value on the
  // canonical local rather than defaulting those later reads to zero.
  let source =
    #|(module
    #|  (memory 1)
    #|  (type $writer (func (param i32 i32 i32 i32) (result i32)))
    #|  (table 1 funcref)
    #|  (func $retain (param i32))
    #|  (func $release (param i32))
    #|  (func $free (param i32))
    #|  (func $malloc (param i32) (result i32) local.get 0)
    #|  (func $tag (param i32) (result i32) i32.const 0)
    #|  (func $in_process (param i32 i32 i32) (result i32) local.get 0)
    #|  (func $to_string (param i32) (result i32) local.get 0)
    #|  (func $add_string (param i32 i32) (result i32) local.get 1)
    #|  (func (param $io i32) (param $path i32) (param $format i32) (param $bytes i32) (result i32)
    #|    (local $adapter_err i32) (local $in_process_err i32) (local $out i32)
    #|    (local $bind i32) (local $ok i32) (local $err i32) (local $func i32)
    #|    (local $adapter_carrier i32) (local $out_carrier i32) (local $inner_carrier i32)
    #|    (local $field i32) (local $cnt i32) (local $new_cnt i32)
    #|    (local $tmp_a i32) (local $tmp_b i32) (local $tmp_c i32)
    #|    (local $drop8 i32) (local $drop12 i32) (local $drop16 i32)
    #|    (local $drop20 i32) (local $drop24 i32) (local $drop28 i32)
    #|    (local $drop32 i32) (local $drop36 i32) (local $drop40 i32)
    #|    (local $ptr i32)
    #|    block
    #|      block
    #|        local.get $io
    #|        i32.load offset=44 align=1
    #|        local.set $func
    #|        local.get $io
    #|        i32.load align=1
    #|        local.tee $cnt
    #|        i32.const 1
    #|        i32.gt_s
    #|        if
    #|          local.get $cnt
    #|          i32.const 1
    #|          i32.sub
    #|          local.set $new_cnt
    #|          local.get $io
    #|          local.get $new_cnt
    #|          i32.store align=1
    #|          local.get $func
    #|          call $retain
    #|        else
    #|          local.get $cnt
    #|          i32.const 1
    #|          i32.eq
    #|          if
    #|            local.get $io
    #|            i32.load offset=40 align=1
    #|            local.tee $drop40
    #|            call $release
    #|            local.get $io
    #|            i32.load offset=36 align=1
    #|            local.tee $drop36
    #|            call $release
    #|            local.get $io
    #|            i32.load offset=32 align=1
    #|            local.tee $drop32
    #|            call $release
    #|            local.get $io
    #|            i32.load offset=28 align=1
    #|            local.tee $drop28
    #|            call $release
    #|            local.get $io
    #|            i32.load offset=24 align=1
    #|            local.tee $drop24
    #|            call $release
    #|            local.get $io
    #|            i32.load offset=20 align=1
    #|            local.tee $drop20
    #|            call $release
    #|            local.get $io
    #|            i32.load offset=16 align=1
    #|            local.tee $drop16
    #|            call $release
    #|            local.get $io
    #|            i32.load offset=12 align=1
    #|            local.tee $drop12
    #|            call $release
    #|            local.get $io
    #|            i32.load offset=8 align=1
    #|            local.tee $drop8
    #|            call $release
    #|            local.get $io
    #|            call $free
    #|          end
    #|        end
    #|        local.get $func
    #|        local.get $path
    #|        local.get $format
    #|        local.get $bytes
    #|        local.get $func
    #|        i32.load offset=8 align=1
    #|        call_indirect (type $writer)
    #|        local.tee $bind
    #|        call $tag
    #|        i32.const 1
    #|        i32.eq
    #|        if (result i32)
    #|          local.get $bind
    #|          local.tee $ok
    #|          i32.load offset=8 align=1
    #|          local.set $field
    #|          local.get $ok
    #|          call $free
    #|          local.get $field
    #|          local.tee $out_carrier
    #|          local.set $out
    #|          br 1
    #|        else
    #|          local.get $bind
    #|          local.tee $err
    #|          i32.load offset=8 align=1
    #|          local.set $field
    #|          local.get $err
    #|          call $free
    #|          local.get $field
    #|          local.tee $adapter_carrier
    #|          local.set $adapter_err
    #|          br 2
    #|        end
    #|        return
    #|      end
    #|      i32.const 4
    #|      call $malloc
    #|      local.tee $ptr
    #|      i32.const 1048833
    #|      i32.store offset=4 align=1
    #|      local.get $ptr
    #|      local.get $out
    #|      i32.store offset=8 align=1
    #|      local.get $ptr
    #|      return
    #|    end
    #|    block
    #|      block
    #|        local.get $path
    #|        call $retain
    #|        local.get $path
    #|        local.get $format
    #|        local.get $bytes
    #|        call $in_process
    #|        local.tee $bind
    #|        call $tag
    #|        i32.const 1
    #|        i32.eq
    #|        if (result i32)
    #|          local.get $path
    #|          call $release
    #|          local.get $adapter_err
    #|          call $release
    #|          local.get $bind
    #|          local.tee $ok
    #|          i32.load offset=8 align=1
    #|          local.set $field
    #|          local.get $ok
    #|          call $free
    #|          local.get $field
    #|          local.tee $out_carrier
    #|          local.set $out
    #|          br 1
    #|        else
    #|          local.get $bind
    #|          local.tee $err
    #|          i32.load offset=8 align=1
    #|          local.set $field
    #|          local.get $err
    #|          call $free
    #|          local.get $field
    #|          local.tee $inner_carrier
    #|          local.set $in_process_err
    #|          br 2
    #|        end
    #|        return
    #|      end
    #|      i32.const 4
    #|      call $malloc
    #|      local.tee $ptr
    #|      i32.const 1048833
    #|      i32.store offset=4 align=1
    #|      local.get $ptr
    #|      local.get $out
    #|      i32.store offset=8 align=1
    #|      local.get $ptr
    #|      return
    #|    end
    #|    local.get $path
    #|    call $to_string
    #|    local.tee $tmp_a
    #|    i32.const 11400
    #|    call $add_string
    #|    local.set $tmp_b
    #|    local.get $adapter_err
    #|    call $to_string
    #|    local.set $tmp_c
    #|    local.get $tmp_b
    #|    local.get $tmp_c
    #|    call $add_string
    #|    drop
    #|    local.get $in_process_err)
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 8)
  let writes = ssa_test_local_write_indices(instrs)
  assert_true(locals.length() <= 75, msg=locals.to_string())
  assert_true(writes.any(fn(idx) { idx == 4U }), msg=instrs.to_string())
  let text = instrs.to_string()
  assert_true(text.contains("(local.get (Local 4)) (call (Func 1))"), msg=text)
  assert_false(text.contains("(i32.const I32(0)) (call (Func 1))"), msg=text)
}

///|
test "ssa-nomerge runs in O4z scheduling mode" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 1 local.set 0 i32.const 2 local.set 0 local.get 0))",
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(
        optimize_level=4,
        shrink_level=1,
        trace=Some(fn(line) { trace.push(line) }),
      ),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected O4z ssa-nomerge success, got \{err}")
  }
  assert_false(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=o4z-ssa-nomerge-noop")
    }),
    msg=trace.join("\n"),
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
  ])
}

///|
test "ssa-nomerge preserves dropped local increments without local writes" {
  // This fixture has no local writes, so `ssa_nomerge_run` returns before the
  // dropped-increment guard. It protects no-write/raw preservation, not the HOT
  // guard itself.
  let source =
    #|(module
    #|  (func (local i32)
    #|    local.get 0
    #|    i32.const 1
    #|    i32.add
    #|    drop))
    #|)
  let optimized = match pass_test_run_pipeline(source, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected dropped increment ssa-nomerge success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.add"), msg=text)
  assert_true(text.contains("drop"), msg=text)
}

///|
test "ssa-nomerge rewrites functions containing dropped local increment debris" {
  let source =
    #|(module
    #|  (func (local i32)
    #|    i32.const 10
    #|    local.set 0
    #|
    #|    local.get 0
    #|    i32.const 1
    #|    i32.add
    #|    drop
    #|
    #|    local.get 0
    #|    drop))
    #|)
  assert_true(
    ssa_test_hot_path_revision_changed(source),
    msg="expected hot-path rewrite for dropped increment debris",
  )
}

///|
test "ssa-nomerge preserves reaching local after dropped increment debris" {
  let source =
    #|(module
    #|  (func (local i32)
    #|    i32.const 10
    #|    local.set 0
    #|
    #|    local.get 0
    #|    i32.const 1
    #|    i32.add
    #|    drop
    #|
    #|    local.get 0
    #|    drop))
    #|)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) => fail("expected dropped increment hot-path success, got \{err}")
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(10)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ])
}

///|
test "ssa-nomerge handles dropped increment after local.tee" {
  let source =
    #|(module
    #|  (func (local i32)
    #|    i32.const 10
    #|    local.tee 0
    #|    drop
    #|
    #|    local.get 0
    #|    i32.const 1
    #|    i32.add
    #|    drop
    #|
    #|    local.get 0
    #|    drop))
    #|)
  assert_true(
    ssa_test_hot_path_revision_changed(source),
    msg="expected hot-path rewrite after local.tee",
  )
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected dropped increment tee hot-path success, got \{err}")
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(10)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ])
}

///|
test "ssa-nomerge validates reversed dropped local increment boundary" {
  let source =
    #|(module
    #|  (func (local i32)
    #|    i32.const 10
    #|    local.set 0
    #|
    #|    i32.const 1
    #|    local.get 0
    #|    i32.add
    #|    drop
    #|
    #|    local.get 0
    #|    drop))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.add"), msg=text)
  assert_true(text.contains("drop"), msg=text)
}

///|
test "ssa-nomerge validates non-one dropped increment boundary" {
  let source =
    #|(module
    #|  (func (local i32)
    #|    i32.const 10
    #|    local.set 0
    #|
    #|    local.get 0
    #|    i32.const 2
    #|    i32.add
    #|    drop
    #|
    #|    local.get 0
    #|    drop))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.const I32(2)"), msg=text)
  assert_true(text.contains("i32.add"), msg=text)
  assert_true(text.contains("drop"), msg=text)
}

///|
fn ssa_test_hot_path_revision_changed(source : String) -> Bool raise {
  let mod_ = pass_test_module_from_wat(source)
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  @ir.hot_verify_all_or_abort(func)
  let revision_before = @ir.hot_revision_current(func)
  let ctx = HotPassContext::new(
    ssa_nomerge_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected hot-path ssa-nomerge success, got \{err}")
  }
  @ir.hot_revision_current(func) != revision_before
}

///|
fn ssa_test_bytes_from_ints(values : Array[Int]) -> Bytes {
  let out = @buffer.new(size_hint=values.length())
  for value in values {
    out.write_byte(value.to_byte())
  }
  out.to_bytes()
}

///|
fn ssa_test_decode_wasm_bytes(values : Array[Int]) -> @lib.Module {
  match @binary.decode_module(ssa_test_bytes_from_ints(values)) {
    Ok(mod_) => mod_
    Err(err) => abort("expected SSA wasm fixture decode success, got \{err}")
  }
}

///|
fn ssa_test_validate_ssa_nomerge_pipeline(source : String) -> @lib.Module raise {
  let optimized = match pass_test_run_pipeline(source, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected ssa-nomerge pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => optimized
    Err(err) =>
      fail(
        "expected ssa-nomerge output to validate, got \{@validate.validation_error_message(err)}",
      )
  }
}

///|
fn ssa_test_module_expected_mutation_valid(
  input : @lib.Module,
  context : String,
) -> @lib.Module raise {
  let trace : Array[String] = []
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected \{context} ssa-nomerge success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected \{context} ssa-nomerge output to validate, got \{@validate.validation_error_message(err)}",
      )
  }
  assert_true(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg="expected \{context} to mutate; trace:\n\{trace.join("\n")}",
  )
  optimized
}

///|
fn ssa_test_pipeline_expected_mutation_valid(
  source : String,
  context : String,
) -> @lib.Module raise {
  ssa_test_module_expected_mutation_valid(
    pass_test_module_from_wat(source),
    context,
  )
}

///|
// Boundary helper for problem-1 arbitrary reference branch inputs. These
// fixtures intentionally stay fail-closed under SSA v1: broad expression-stack
// scanning could duplicate calls, allocations, casts, conversions, or traps, so
// unsupported shapes must validate and preserve the original raw ref branch.
// Some shapes reach HOT before the final writeback guard rejects them; the
// executable contract here is no committed rewrite of the unsafe branch input.
fn ssa_test_problem1_fail_closed_reference_branch_input(
  input : @lib.Module,
  defined_idx : Int,
  context : String,
  has_branch : (Array[@lib.Instruction]) -> Bool,
) -> Unit raise {
  let trace : Array[String] = []
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected fail-closed \{context} ssa-nomerge success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected fail-closed \{context} ssa-nomerge output to validate, got \{@validate.validation_error_message(err)}",
      )
  }
  let (_, instrs) = try! ssa_test_defined_func(optimized, defined_idx)
  assert_true(
    has_branch(instrs),
    msg="expected fail-closed \{context} to preserve the raw branch; instrs=\{instrs}",
  )
}

///|
fn ssa_test_hot_exceptional_local_traffic_preserved(
  source : String,
) -> Unit raise {
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected exceptional hot-path ssa-nomerge success, got \{err}")
  }
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(
    text.contains("local.set") || text.contains("local.tee"),
    msg=text,
  )
}

///|
fn ssa_test_hot_func_has_local_write(func : @ir.HotFunc) -> Bool {
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => return true
      _ => ()
    }
  }
  false
}

///|
fn ssa_test_hot_func_ssa_nomerge_revision_unchanged(
  func : @ir.HotFunc,
) -> Unit raise {
  @ir.hot_verify_all_or_abort(func)
  let revision_before = @ir.hot_revision_current(func)
  let ctx = HotPassContext::new(
    ssa_nomerge_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected hot func ssa-nomerge success, got \{err}")
  }
  @debug.assert_eq(@ir.hot_revision_current(func), revision_before)
}

///|
// Boundary helper for nested CFG shapes outside SSA no-merge v1's straight-line
// value-block/result-if model. These tests must prove the input still contains
// local traffic and that the pass deliberately leaves it untouched; behavior
// gaps that should be implemented must use the expected-mutation helpers instead.
fn ssa_test_unsupported_nested_cfg_pipeline_no_mutation(
  source : String,
) -> Unit raise {
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected unsupported nested-CFG ssa-nomerge no-mutation success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
}

///|
fn ssa_test_unsupported_nested_cfg_hot_no_mutation(
  source : String,
) -> Unit raise {
  let mod_ = pass_test_module_from_wat(source)
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  @ir.hot_verify_all_or_abort(func)
  ssa_test_hot_func_ssa_nomerge_revision_unchanged(func)
  assert_true(ssa_test_hot_func_has_local_write(func))
}

///|
fn ssa_test_nested_cfg_hot_local_traffic_preserved(
  source : String,
) -> Unit raise {
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested-CFG hot-path ssa-nomerge success, got \{err}")
  }
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(
    text.contains("local.set") || text.contains("local.tee"),
    msg=text,
  )
  assert_true(text.contains("local.get"), msg=text)
}

///|
// Boundary helper for typed loop-param fixtures with no loop-carried overwrite
// or edge copy requirement. Required typed-loop SSA rewrites use expected-mutation
// helpers elsewhere in this file.
fn ssa_test_no_copy_typed_loop_param_module_no_mutation(
  input : @lib.Module,
) -> Unit raise {
  let trace : Array[String] = []
  match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["ssa-nomerge"],
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected no-copy typed-loop-param ssa-nomerge no-mutation success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
}

///|
fn ssa_test_no_copy_typed_loop_param_pipeline_no_mutation(
  source : String,
) -> Unit raise {
  ssa_test_no_copy_typed_loop_param_module_no_mutation(
    pass_test_module_from_wat(source),
  )
}

///|
// Boundary helper for exceptional-control fixtures. SSA no-merge v1 is
// normal-flow-only, so these direct HOT checks assert deliberate no-mutation
// while preserving the local traffic that would be unsafe to rewrite.
fn ssa_test_unsupported_exceptional_hot_no_mutation(
  func : @ir.HotFunc,
) -> Unit raise {
  @ir.hot_verify_all_or_abort(func)
  let revision_before = @ir.hot_revision_current(func)
  let ctx = HotPassContext::new(
    ssa_nomerge_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected hot func ssa-nomerge success, got \{err}")
  }
  @debug.assert_eq(@ir.hot_revision_current(func), revision_before)
  assert_true(ssa_test_hot_func_has_local_write(func))
}

///|
fn ssa_test_assert_no_planned_structured_trace_reason(
  trace : Array[String],
) -> Unit raise {
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-localgraph-plan",
      ) ||
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-mixed-localgraph-plan",
      ) ||
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-multisource-merge-localgraph-plan",
      ) ||
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-loop-backedge-merge-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
}

///|
fn ssa_test_assert_no_ssa_nomerge_mutation_trace(
  trace : Array[String],
) -> Unit raise {
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
}

///|
fn ssa_test_expect_null_branch_boundary_module_output(
  input : @lib.Module,
  defined_idx : Int,
  context : String,
) -> (@lib.Locals, Array[@lib.Instruction]) raise {
  let trace : Array[String] = []
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected null branch \{context} boundary success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected null branch \{context} boundary output to validate, got \{@validate.validation_error_message(err)}",
      )
  }
  ssa_test_assert_no_planned_structured_trace_reason(trace)
  try! ssa_test_defined_func(optimized, defined_idx)
}

///|
fn ssa_test_expect_cast_branch_boundary_module_output(
  input : @lib.Module,
  defined_idx : Int,
  context : String,
) -> (@lib.Locals, Array[@lib.Instruction], Array[String]) raise {
  let trace : Array[String] = []
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected cast branch \{context} boundary success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected cast branch \{context} boundary output to validate, got \{@validate.validation_error_message(err)}",
      )
  }
  ssa_test_assert_no_planned_structured_trace_reason(trace)
  assert_false(
    trace.any(fn(line) { line.contains("hot-lift-error") }),
    msg=trace.join("\n"),
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, defined_idx)
  (locals, instrs, trace)
}

///|
fn ssa_test_assert_ssa_nomerge_raw_reason(
  trace : Array[String],
  reason : String,
) -> Unit raise {
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=\{reason}") ||
      line.contains("pass[ssa-nomerge]:mutated raw reason=\{reason}")
    }),
    msg="expected ssa-nomerge raw reason \{reason}; trace:\n\{trace.join("\n")}",
  )
}

///|
test "ssa-nomerge rewrites no-throw try_table local writes" {
  let trace : Array[String] = []
  let input =
    #| (module
    #|   (func (result i32)
    #|     (local i32)
    #|     i32.const 1
    #|     local.set 0
    #|     block
    #|       try_table (catch_all 0)
    #|         i32.const 7
    #|         local.set 0
    #|       end
    #|     end
    #|     i32.const 9
    #|     local.set 0
    #|     local.get 0))
    #|
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected no-throw try_table ssa-nomerge success, got \{err}")
  }

  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::try_table(
          @lib.BlockType::void_(),
          [@lib.Catch::all(@lib.LabelIdx::new(0U))],
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    ),
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
}

///|
test "ssa-nomerge keeps call-bearing try_table bodies off no-throw local rewrite" {
  // `[SSANM-007a3b]` keeps the admitted no-throw `try_table` local-write
  // subset narrow: a call-bearing body may have an exceptional edge from the
  // helper's perspective, so it must not use the no-throw structured rewrite.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func $g)
    #|  (func (export "f") (result i32)
    #|    (local i32)
    #|    i32.const 1
    #|    local.set 0
    #|    block
    #|      try_table (catch_all 0)
    #|        call $g
    #|        i32.const 7
    #|        local.set 0
    #|      end
    #|    end
    #|    local.get 0))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected call-bearing try_table boundary success, got \{err}")
  }
  assert_false(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  ssa_test_assert_no_ssa_nomerge_mutation_trace(trace)
  let (_, instrs) = try! ssa_test_defined_func(optimized, 1)
  let text = instrs.to_string()
  assert_true(text.contains("call"), msg=text)
  assert_true(text.contains("local.set"), msg=text)
}

///|
test "ssa-nomerge does not mutate unsupported exceptional-flow functions" {
  // Exceptional predecessors are outside SSA no-merge v1's normal-flow model;
  // this boundary test must stay green only because the pass leaves them untouched.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (tag $e)
    #|  (func (export "f") (result i32)
    #|    (local i32)
    #|    i32.const 1
    #|    local.set 0
    #|    (block $h
    #|      (try_table (catch $e $h)
    #|        i32.const 2
    #|        local.set 0
    #|        throw $e))
    #|    local.get 0))
    #|)
  match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected unsupported exceptional-flow ssa-nomerge no-mutation success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge keeps throwing try_table catch exits off planned structured path" {
  // `[SSANM-007a2a]` locks real exceptional exits out of ordinary LocalGraph
  // mutation. LocalGraph no-merge is normal-flow-only in Starshine today, so a
  // write before a caught throw must be preserved without claiming structured
  // LocalGraph rewrite reasons.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (tag $e)
    #|  (func (export "f") (param i32) (result i32)
    #|    (local i32)
    #|    i32.const 1
    #|    local.set 1
    #|    (block $h
    #|      (try_table (catch $e $h)
    #|        i32.const 2
    #|        local.set 1
    #|        throw $e))
    #|    local.get 1))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected throwing try_table boundary success, got \{err}")
  }

  ssa_test_assert_no_planned_structured_trace_reason(trace)
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("local.set"), msg=text)
  assert_true(text.contains("throw"), msg=text)
}

///|
test "ssa-nomerge keeps conditional catch_all throws off planned structured path" {
  // `[SSANM-007a2a]` also locks catch-all exceptional exits. A conditional
  // throw has a normal fallthrough arm, but the catch edge still makes local
  // reaching-set mutation unsafe for the ordinary planned LocalGraph paths.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (tag $e)
    #|  (func (export "f") (param i32) (result i32)
    #|    (local i32)
    #|    i32.const 10
    #|    local.set 1
    #|    (block $h
    #|      (try_table (catch_all $h)
    #|        local.get 0
    #|        if
    #|          i32.const 20
    #|          local.set 1
    #|          throw $e
    #|        end))
    #|    local.get 1))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected conditional catch_all boundary success, got \{err}")
  }

  ssa_test_assert_no_planned_structured_trace_reason(trace)
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("local.set"), msg=text)
  assert_true(text.contains("throw"), msg=text)
}

///|
test "ssa-nomerge preserves try-table local writes across exceptional exits" {
  let source =
    #|(module
    #|  (tag $e)
    #|  (func (export "f") (result i32)
    #|    (local i32)
    #|    i32.const 1
    #|    local.set 0
    #|    (block $h
    #|      (try_table (catch $e $h)
    #|        i32.const 2
    #|        local.set 0
    #|        throw $e))
    #|    local.get 0))
    #|)
  let optimized = match pass_test_run_pipeline(source, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected try-table ssa-nomerge success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("local.set"), msg=text)
  assert_false(text.contains("drop"), msg=text)
}

///|
test "ssa-nomerge preserves try-table default local at catch continuation" {
  let source =
    #|(module
    #|  (tag $e)
    #|  (func (export "f") (result i32)
    #|    (local i32)
    #|    (block $h
    #|      (try_table (catch $e $h)
    #|        throw $e))
    #|    local.get 0))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(
    text.contains("local.get") || text.contains("i32.const I32(0)"),
    msg=text,
  )
}

///|
test "ssa-nomerge preserves local written before conditional throw to catch" {
  let source =
    #|(module
    #|  (tag $e)
    #|  (func (export "f") (param i32) (result i32)
    #|    (local i32)
    #|    i32.const 10
    #|    local.set 1
    #|    (block $h
    #|      (try_table (catch $e $h)
    #|        local.get 0
    #|        if
    #|          i32.const 20
    #|          local.set 1
    #|          throw $e
    #|        end))
    #|    local.get 1))
    #|)
  ssa_test_hot_exceptional_local_traffic_preserved(source)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("local.set"), msg=text)
}

///|
test "ssa-nomerge materializes defaults before null throw_ref debris" {
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func (export "f") (local i32)
    #|    block
    #|      i32.const 0
    #|      br_table 0 0
    #|    end
    #|    local.get 0
    #|    drop
    #|    i32.const 1
    #|    local.set 0
    #|    try_table (catch_all 0)
    #|      i32.const 42
    #|      local.set 0
    #|      ref.null noexn
    #|      throw_ref
    #|    end))
    #|
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected default-plus-null-throwref pipeline success, got \{err}")
  }
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_false(text.contains("try_table"), msg=text)
  assert_false(text.contains("throw_ref"), msg=text)
  assert_true(text.contains("i32.const I32(0)"), msg=text)
  assert_false(
    ssa_nomerge_test_local_get_indices(instrs).contains(0U),
    msg=text,
  )
  assert_true(
    trace.any(fn(line) { line.contains("null-throwref-debris") }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge composes defaults with typed-loop null throw_ref debris" {
  // The dedicated coverage equal-size family can put an entry-default read
  // before later writes, followed by a typed self-branching loop and a local-only
  // null throw_ref suffix. Binaryen still applies LocalGraph default
  // materialization to the surviving prefix before reducing the EH debris.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (type $take_i32 (func (param i32)))
    #|  (func (export "f") (type $take_i32) (param i32)
    #|    (local i32 i32 i32 i32 i32)
    #|    local.get 0
    #|    drop
    #|    i32.const 101
    #|    local.set 4
    #|    local.get 4
    #|    drop
    #|    i32.const 1
    #|    if
    #|      i32.const 103
    #|      local.set 3
    #|    end
    #|    local.get 3
    #|    drop
    #|    local.get 0
    #|    if
    #|      i32.const 104
    #|      local.set 0
    #|    end
    #|    local.get 0
    #|    drop
    #|    i32.const 102
    #|    local.set 5
    #|    block
    #|      i32.const 0
    #|      br_table 0 0
    #|    end
    #|    local.get 1
    #|    drop
    #|    i32.const 1
    #|    local.set 1
    #|    local.get 1
    #|    drop
    #|    i32.const 2
    #|    local.set 1
    #|    local.get 1
    #|    drop
    #|    i32.const 7
    #|    local.tee 1
    #|    drop
    #|    local.get 1
    #|    drop
    #|    i32.const 9
    #|    local.set 0
    #|    local.get 0
    #|    drop
    #|    i32.const 0
    #|    local.set 1
    #|    local.get 1
    #|    if
    #|      i32.const 1
    #|      local.set 1
    #|    else
    #|      i32.const 2
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    drop
    #|    local.get 1
    #|    if
    #|      i32.const 7
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    drop
    #|    i32.const 0
    #|    local.set 1
    #|    block
    #|      loop
    #|        local.get 1
    #|        drop
    #|        i32.const 1
    #|        local.set 1
    #|        local.get 1
    #|        br_if 0
    #|      end
    #|    end
    #|    local.get 1
    #|    drop
    #|    i32.const 0
    #|    local.set 1
    #|    local.get 0
    #|    loop (type $take_i32) (param i32)
    #|      drop
    #|      i32.const 1
    #|      local.set 1
    #|      local.get 1
    #|      br 0
    #|    end
    #|    local.get 1
    #|    drop
    #|    try_table (catch_all 0)
    #|      i32.const 42
    #|      local.set 1
    #|      ref.null noexn
    #|      throw_ref
    #|    end))
    #|
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected typed-loop default/null-debris pipeline success, got \{err}",
      )
  }
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_false(text.contains("try_table"), msg=text)
  assert_false(text.contains("throw_ref"), msg=text)
  assert_true(ssa_nomerge_test_has_brtable_default_zero_drop(instrs), msg=text)
  assert_true(
    ssa_test_local_tee_indices(instrs).any(fn(idx) { idx > 1U }),
    msg="expected the pre-loop single-source local.tee to freshen; output: " +
      text,
  )
  assert_true(
    trace.any(fn(line) {
      line.contains("localgraph-plan") && line.contains("null-throwref-debris")
    }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge freshens post-branch default chains" {
  // Binaryen materializes the body-local default read after an ordinary block
  // branch, then freshens the subsequent single-source set/get and tee/get
  // chain. Keeping those writes on the canonical local is the dominant
  // dedicated smoke mismatch shape after default materialization landed.
  let source =
    #|(module
    #|  (func (export "f") (param i32) (local i32)
    #|    block
    #|      br 0
    #|    end
    #|    local.get 1
    #|    drop
    #|    i32.const 1
    #|    local.set 1
    #|    local.get 1
    #|    drop
    #|    i32.const 2
    #|    local.set 1
    #|    local.get 1
    #|    drop
    #|    i32.const 7
    #|    local.tee 1
    #|    drop
    #|    local.get 1
    #|    drop))
    #|
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.const I32(0)"), msg=text)
  assert_true(locals.length() >= 4, msg=locals.to_string() + "\n" + text)
  assert_false(
    ssa_test_local_write_indices(instrs).contains(1U),
    msg="expected post-branch single-source writes to freshen: " + text,
  )
  assert_false(
    ssa_nomerge_test_local_get_indices(instrs).contains(1U),
    msg="expected post-branch single-source reads to retarget: " + text,
  )
}

///|
test "ssa-nomerge preserves dead-tail fresh local declarations before null throw_ref collapse" {
  // Binaryen `SSAify(false)` allocates fresh locals while walking all
  // `local.set` / `local.tee` nodes, before later unreachable-tail cleanup
  // removes a null-throw_ref suffix and its dead followers. Starshine must keep
  // those declarations so the dedicated GenValid lane does not drift solely
  // because the LocalGraph plan was rebuilt after trimming the suffix.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func (export "f") (param i32) (local i32)
    #|    local.get 1
    #|    drop
    #|    i32.const 1
    #|    local.set 1
    #|    try_table (catch_all 0)
    #|      i32.const 42
    #|      local.set 1
    #|      ref.null noexn
    #|      throw_ref
    #|    end
    #|    i32.const 10
    #|    local.set 1
    #|    local.get 1
    #|    drop
    #|    i32.const 11
    #|    local.set 1
    #|    local.get 1
    #|    drop
    #|    i32.const 12
    #|    local.tee 1
    #|    drop
    #|    local.get 1
    #|    drop))
    #|
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected dead-tail null throw_ref pipeline success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) { line.contains("null-throwref-debris") }),
    msg=trace.to_string(),
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_false(text.contains("try_table"), msg=text)
  assert_false(text.contains("throw_ref"), msg=text)
  assert_true(
    text.contains("Unreachable") || text.contains("unreachable"),
    msg=text,
  )
  assert_true(
    locals.length() >= 6,
    msg="expected declarations for fresh locals planned before dead-tail collapse; locals: " +
      locals.to_string() +
      "\n" +
      text,
  )
}

///|
test "ssa-nomerge lowers null throw_ref try_table debris to unreachable" {
  // Dedicated `ssa-nomerge-coverage` GenValid failures such as
  // `.tmp/pass-fuzz-ssa-nomerge-genvalid-coverage-abs6097-branchcopyfix-10000/failures/case-000022-gen-valid`
  // carry a dead/always-trapping `try_table` suffix whose body ends with
  // `ref.null noexn; throw_ref`. Binaryen's `ssa-nomerge` canonicalizes this
  // local-only exceptional debris to `unreachable`; keeping the EH shell is a
  // repeatable size-losing output-shape gap, not a Starshine win.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func (export "f") (param i32)
    #|    (local i32)
    #|    i32.const 0
    #|    local.set 1
    #|    local.get 0
    #|    loop (param i32)
    #|      drop
    #|      i32.const 1
    #|      local.set 1
    #|      local.get 1
    #|      br 0
    #|    end
    #|    local.get 1
    #|    drop
    #|    try_table (catch_all 0)
    #|      i32.const 42
    #|      local.set 1
    #|      ref.null noexn
    #|      throw_ref
    #|    end
    #|    local.get 1
    #|    drop))
    #|
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected null throw_ref try_table pipeline success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=null-throwref-debris") ||
      line.contains("null-throwref-debris")
    }),
    msg=trace.join("\n"),
  )
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_false(text.contains("try_table"), msg=text)
  assert_false(text.contains("throw_ref"), msg=text)
  assert_true(
    text.contains("Unreachable") || text.contains("unreachable"),
    msg=text,
  )
  match instrs[instrs.length() - 1] {
    @lib.Instruction::Unreachable => ()
    other =>
      fail(
        "expected trapping EH debris to end at unreachable, got \{@debug.to_string(other)} in \{text}",
      )
  }
  if instrs.length() >= 2 {
    match instrs[instrs.length() - 2] {
      @lib.Instruction::Drop =>
        fail(
          "expected local-only debris before unreachable to be removed: \{text}",
        )
      _ => ()
    }
  }
}

///|
test "ssa-nomerge preserves throw_ref shapes without hot local corruption" {
  // `[SSANM-007a2b1]` locks direct throw_ref roots as an exceptional-flow
  // boundary. The pass must leave nearby local traffic and the HOT revision alone.
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let set = @ir.hot_build_local_set(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  let exnref = @ir.hot_build_ref_null(
    func,
    @lib.RefType::abs(@lib.AbsHeapType::exn()),
  )
  let throw_ref = @ir.hot_build_throw_ref(func, exnref)
  @ir.hot_root_append(func, set)
  @ir.hot_root_append(func, throw_ref)
  ssa_test_unsupported_exceptional_hot_no_mutation(func)
}

///|
test "ssa-nomerge preserves legacy rethrow shapes without hot local corruption" {
  // `[SSANM-007a2b2]` keeps legacy try/catch/rethrow outside planned
  // LocalGraph mutation and outside lifted HOT SSA destruction.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (tag $e0)
    #|  (func (export "f") (result i32)
    #|    (local i32)
    #|    i32.const 5
    #|    local.set 0
    #|    (try
    #|      (do (throw $e0))
    #|      (catch $e0
    #|        (rethrow 0)))))
    #|)
  ssa_test_hot_exceptional_local_traffic_preserved(source)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected legacy rethrow boundary success, got \{err}")
  }
  ssa_test_assert_no_planned_structured_trace_reason(trace)
  ssa_test_assert_no_ssa_nomerge_mutation_trace(trace)
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("local.set"), msg=text)
  assert_true(text.contains("throw"), msg=text)
}

///|
test "ssa-nomerge preserves delegate shapes without hot local corruption" {
  // Nested legacy delegate WAT does not survive `hot_lift_func`; build HOT IR directly.
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let set = @ir.hot_build_local_set(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(7)),
  )
  let block = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let target = @ir.hot_control_node_label(func, block)
  let delegate = @ir.hot_build_delegate(func, target)
  @ir.hot_root_append(func, set)
  @ir.hot_root_append(func, delegate)
  ssa_test_unsupported_exceptional_hot_no_mutation(func)
}

///|
fn ssa_test_expect_scalar_loop_param_branch_proxy(
  source : String,
  min_local_count : Int,
  expect_br_if : Bool,
) -> Unit raise {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected scalar loop-param ssa-nomerge success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected scalar loop-param ssa-nomerge output to validate, got \{@validate.validation_error_message(err)}",
      )
  }
  ssa_test_assert_ssa_nomerge_raw_reason(
    trace, "structured-local-writes-mutated",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() >= min_local_count, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_branch_proxy(instrs, expect_br_if),
    msg=instrs.to_string(),
  )
}

///|
fn ssa_test_expect_scalar_loop_param_br_if_proxy(
  source : String,
  min_local_count : Int,
) -> Unit raise {
  ssa_test_expect_scalar_loop_param_branch_proxy(source, min_local_count, true)
}

///|
fn ssa_test_expect_typed_loop_boundary_output(
  source : String,
  min_local_count : Int,
  context : String,
) -> (@lib.Locals, Array[@lib.Instruction]) raise {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected typed loop-param \{context} ssa-nomerge success, got \{err}",
      )
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected typed loop-param \{context} ssa-nomerge output to validate, got \{@validate.validation_error_message(err)}",
      )
  }
  ssa_test_assert_ssa_nomerge_raw_reason(
    trace, "structured-local-writes-mutated",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() >= min_local_count, msg=locals.to_string())
  (locals, instrs)
}

///|
fn ssa_test_expect_typed_loop_module_boundary_output(
  input : @lib.Module,
  min_local_count : Int,
  context : String,
) -> (@lib.Locals, Array[@lib.Instruction]) raise {
  let trace : Array[String] = []
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected typed loop-param \{context} ssa-nomerge success, got \{err}",
      )
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected typed loop-param \{context} ssa-nomerge output to validate, got \{@validate.validation_error_message(err)}",
      )
  }
  ssa_test_assert_ssa_nomerge_raw_reason(
    trace, "structured-local-writes-mutated",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() >= min_local_count, msg=locals.to_string())
  (locals, instrs)
}

///|
fn ssa_test_expect_loop_param_store_model(
  source : String,
  min_local_count : Int,
) -> Unit raise {
  let (_, instrs) = try! ssa_test_expect_typed_loop_boundary_output(
    source, min_local_count, "store-model",
  )
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
fn ssa_test_expect_loop_param_br_table_proxy(
  source : String,
  min_local_count : Int,
) -> Unit raise {
  let (_, instrs) = try! ssa_test_expect_typed_loop_boundary_output(
    source, min_local_count, "br_table proxy",
  )
  assert_true(
    ssa_test_instrs_have_loop_param_br_table_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites direct scalar typed loop-param br backedge" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    loop $l (type $loop_t)
    #|      local.tee 1
    #|      local.get 0
    #|      i32.lt_s
    #|      if
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        br $l
    #|      end
    #|    end
    #|    local.get 1))
    #|)
  ssa_test_expect_scalar_loop_param_branch_proxy(source, 2, false)
}

///|
test "ssa-nomerge rewrites no-copy scalar typed loop-param br_if backedge" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    loop $l (type $loop_t)
    #|      local.tee 1
    #|      i32.const 1
    #|      i32.add
    #|      local.get 1
    #|      local.get 0
    #|      i32.lt_s
    #|      br_if $l
    #|      drop
    #|    end
    #|    local.get 1))
    #|)
  let optimized = match pass_test_run_pipeline(source, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected scalar loop-param br_if ssa-nomerge success, got \{err}")
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_if_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites no-copy scalar typed loop-param br_if for i64" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i64)))
    #|  (func (param i64) (result i64) (local i64)
    #|    i64.const 0
    #|    loop $l (type $loop_t)
    #|      local.tee 1
    #|      i64.const 1
    #|      i64.add
    #|      local.get 1
    #|      local.get 0
    #|      i64.lt_s
    #|      br_if $l
    #|      drop
    #|    end
    #|    local.get 1))
    #|)
  ssa_test_expect_scalar_loop_param_br_if_proxy(source, 2)
}

///|
test "ssa-nomerge rewrites no-copy scalar typed loop-param br_if for f32" {
  let source =
    #|(module
    #|  (type $loop_t (func (param f32)))
    #|  (func (param f32) (result f32) (local f32)
    #|    f32.const 0
    #|    loop $l (type $loop_t)
    #|      local.tee 1
    #|      f32.const 1
    #|      f32.add
    #|      local.get 1
    #|      local.get 0
    #|      f32.lt
    #|      br_if $l
    #|      drop
    #|    end
    #|    local.get 1))
    #|)
  ssa_test_expect_scalar_loop_param_br_if_proxy(source, 2)
}

///|
test "ssa-nomerge rewrites no-copy scalar typed loop-param br_if for f64" {
  let source =
    #|(module
    #|  (type $loop_t (func (param f64)))
    #|  (func (param f64) (result f64) (local f64)
    #|    f64.const 0
    #|    loop $l (type $loop_t)
    #|      local.tee 1
    #|      f64.const 1
    #|      f64.add
    #|      local.get 1
    #|      local.get 0
    #|      f64.lt
    #|      br_if $l
    #|      drop
    #|    end
    #|    local.get 1))
    #|)
  ssa_test_expect_scalar_loop_param_br_if_proxy(source, 2)
}

///|
test "ssa-nomerge rewrites nested no-copy scalar typed loop-param br_if" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    loop $l (type $loop_t)
    #|      local.tee 1
    #|      local.get 0
    #|      i32.lt_s
    #|      if
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.get 1
    #|        i32.const 0
    #|        i32.ge_s
    #|        br_if $l
    #|        drop
    #|      end
    #|    end
    #|    local.get 1))
    #|)
  ssa_test_expect_scalar_loop_param_br_if_proxy(source, 2)
}

///|
test "ssa-nomerge rewrites copy-needing scalar typed loop-param br_if" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    i32.const 0
    #|    loop $l (type $loop_t)
    #|      local.tee 1
    #|      i32.const 1
    #|      i32.add
    #|      local.get 2
    #|      drop
    #|      local.get 1
    #|      i32.const 0
    #|      i32.eq
    #|      if
    #|        i32.const 7
    #|        local.set 2
    #|      else
    #|        i32.const 8
    #|        local.set 2
    #|      end
    #|      local.get 1
    #|      local.get 0
    #|      i32.lt_s
    #|      br_if $l
    #|      drop
    #|      i32.const 9
    #|      local.set 2
    #|    end
    #|    local.get 2))
    #|)
  ssa_test_expect_scalar_loop_param_branch_proxy(source, 3, false)
}

///|
test "ssa-nomerge rewrites nullable reference typed loop-param br_if" {
  let source =
    #|(module
    #|  (type $loop_t (func (param externref)))
    #|  (func (param externref) (param i32) (result externref) (local externref)
    #|    local.get 0
    #|    loop $l (type $loop_t)
    #|      local.set 2
    #|      local.get 2
    #|      local.get 1
    #|      br_if $l
    #|      drop
    #|    end
    #|    local.get 2))
    #|)
  ssa_test_expect_scalar_loop_param_br_if_proxy(source, 2)
}

///|
test "ssa-nomerge rewrites non-null reference typed loop-param br_if" {
  let source =
    #|(module
    #|  (type $loop_t (func (param (ref extern))))
    #|  (func (param (ref extern)) (param i32) (result (ref extern)) (local externref)
    #|    local.get 0
    #|    loop $l (type $loop_t)
    #|      local.set 2
    #|      local.get 2
    #|      ref.as_non_null
    #|      local.get 1
    #|      br_if $l
    #|      drop
    #|    end
    #|    local.get 2
    #|    ref.as_non_null))
    #|)
  ssa_test_expect_scalar_loop_param_br_if_proxy(source, 2)
}

///|
test "ssa-nomerge rewrites copy-needing nullable reference typed loop-param br_if" {
  let source =
    #|(module
    #|  (type $loop_t (func (param externref)))
    #|  (func (param externref) (param i32) (result externref) (local externref externref)
    #|    local.get 0
    #|    loop $l (type $loop_t)
    #|      local.tee 2
    #|      local.get 3
    #|      drop
    #|      local.get 1
    #|      if
    #|        local.get 0
    #|        local.set 3
    #|      else
    #|        ref.null extern
    #|        local.set 3
    #|      end
    #|      local.get 1
    #|      br_if $l
    #|      drop
    #|      ref.null extern
    #|      local.set 3
    #|    end
    #|    local.get 3))
    #|)
  ssa_test_expect_scalar_loop_param_branch_proxy(source, 4, false)
}

///|
test "ssa-nomerge rewrites copy-needing non-null reference typed loop-param br_if" {
  let source =
    #|(module
    #|  (type $loop_t (func (param (ref extern))))
    #|  (func (param (ref extern)) (param i32) (result externref) (local externref externref)
    #|    local.get 0
    #|    loop $l (type $loop_t)
    #|      local.set 2
    #|      local.get 2
    #|      ref.as_non_null
    #|      local.get 3
    #|      drop
    #|      local.get 1
    #|      if
    #|        local.get 0
    #|        local.set 3
    #|      else
    #|        ref.null extern
    #|        local.set 3
    #|      end
    #|      local.get 1
    #|      br_if $l
    #|      drop
    #|      ref.null extern
    #|      local.set 3
    #|    end
    #|    local.get 3))
    #|)
  ssa_test_expect_scalar_loop_param_branch_proxy(source, 4, false)
}

///|
test "ssa-nomerge rewrites no-copy br_on_null typed loop-param backedge" {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let extern_ref = @lib.ValType::ref_type(@lib.RefType::new(true, extern_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([extern_ref], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([extern_ref], [extern_ref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([extern_ref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let (locals, instrs) = try! ssa_test_expect_null_branch_boundary_module_output(
    input, 0, "no-copy br_on_null typed loop-param",
  )
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_null_proxy(instrs),
    msg=instrs.to_string(),
  )
  assert_true(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites copy-needing br_on_null typed loop-param backedge" {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let extern_ref = @lib.ValType::ref_type(@lib.RefType::new(true, extern_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([extern_ref], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([extern_ref, @lib.ValType::i32()], [extern_ref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([extern_ref, extern_ref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
                  ],
                  Some([
                    @lib.Instruction::ref_null(extern_heap),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(extern_heap),
                @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
          ]),
        ),
      ]),
    )
  let (locals, instrs) = try! ssa_test_expect_null_branch_boundary_module_output(
    input, 0, "copy-needing br_on_null typed loop-param",
  )
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_null_taken_copy_branch(instrs, 3U),
    msg=instrs.to_string(),
  )
  assert_true(
    instrs.to_string().contains("ref.as_non_null"),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites multi-result br_on_null taken-edge copies" {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let extern_ref = @lib.ValType::ref_type(@lib.RefType::new(true, extern_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([extern_ref, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), extern_ref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(7),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(8),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ]),
                ),
                @lib.Instruction::i32_const(42),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(9),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::i32_const(1),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::i32_add(),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected multi-result br_on_null ssa-nomerge success, got \{err}")
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_null_taken_copy_branch(instrs, 2U),
    msg=instrs.to_string(),
  )
  assert_true(
    instrs.to_string().contains("ref.as_non_null"),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites multi-param typed loop direct br backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32 i64)))
    #|  (func (param i32) (result i32) (local i32 i64)
    #|    i32.const 0
    #|    i64.const 1
    #|    loop $l (type $loop_t)
    #|      local.set 2
    #|      local.tee 1
    #|      local.get 0
    #|      i32.lt_s
    #|      if
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.get 2
    #|        i64.const 1
    #|        i64.add
    #|        br $l
    #|      end
    #|    end
    #|    local.get 1))
    #|)
  ssa_test_expect_loop_param_store_model(source, 3)
}

///|
test "ssa-nomerge rewrites multi-param typed loop br_if backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32 i64)))
    #|  (func (param i32) (result i32) (local i32 i64)
    #|    i32.const 0
    #|    i64.const 1
    #|    loop $l (type $loop_t)
    #|      local.set 2
    #|      local.set 1
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.get 2
    #|      i64.const 1
    #|      i64.add
    #|      local.get 1
    #|      local.get 0
    #|      i32.lt_s
    #|      br_if $l
    #|      drop
    #|      drop
    #|    end
    #|    local.get 1))
    #|)
  ssa_test_expect_loop_param_store_model(source, 3)
}

///|
test "ssa-nomerge preserves result loop carrier for multi-param direct br backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32 i32 i32) (result i32)))
    #|  (func (param i32) (result i32) (local i32 i32 i32)
    #|    i32.const 0
    #|    i32.const 1
    #|    i32.const 2
    #|    loop $l (type $loop_t)
    #|      local.set 3
    #|      local.set 2
    #|      local.set 1
    #|      local.get 1
    #|      local.get 0
    #|      i32.lt_s
    #|      if (result i32)
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.get 2
    #|        local.get 3
    #|        br $l
    #|      else
    #|        local.get 1
    #|      end
    #|    end)
    #|)
  let (_, instrs) = try! ssa_test_expect_typed_loop_boundary_output(
    source, 6, "multi-param single-result direct br result-loop carrier",
  )
  assert_true(ssa_test_instrs_have_nonvoid_loop(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge leaves tuple carrier disabled without canonical local proof" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32 i32 i32) (result i32)))
    #|  (type $carrier_t (func (result i32 i32 i32)))
    #|  (func (param i32) (result i32) (local i32 i32 i32)
    #|    i32.const 0
    #|    i32.const 1
    #|    i32.const 2
    #|    loop $l (type $loop_t)
    #|      local.set 3
    #|      local.set 2
    #|      local.set 1
    #|      local.get 1
    #|      local.get 0
    #|      i32.lt_s
    #|      if (result i32)
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.get 2
    #|        local.get 3
    #|        br $l
    #|      else
    #|        local.get 1
    #|      end
    #|    end)
    #|)
  let (_, instrs) = try! ssa_test_expect_typed_loop_boundary_output(
    source, 6, "multi-param single-result direct br tuple carrier disabled",
  )
  assert_true(ssa_test_instrs_have_nonvoid_loop(instrs), msg=instrs.to_string())
  assert_false(
    ssa_test_instrs_have_block_type_idx(instrs, 1U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites scalar typed loop br_table backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    loop $l (type $loop_t)
    #|      local.set 1
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.get 0
    #|      br_table $l $l
    #|    end
    #|    local.get 1))
    #|)
  ssa_test_expect_loop_param_br_table_proxy(source, 2)
}

///|
test "ssa-nomerge rewrites copy-needing scalar typed loop br_table backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    i32.const 0
    #|    loop $l (type $loop_t)
    #|      local.set 1
    #|      local.get 2
    #|      drop
    #|      local.get 1
    #|      i32.const 0
    #|      i32.eq
    #|      if
    #|        i32.const 7
    #|        local.set 2
    #|      else
    #|        i32.const 8
    #|        local.set 2
    #|      end
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.get 0
    #|      br_table $l $l
    #|    end
    #|    local.get 2))
    #|)
  ssa_test_expect_loop_param_br_table_proxy(source, 3)
}

///|
test "ssa-nomerge rewrites multi-param typed loop br_table backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32 i64)))
    #|  (func (param i32) (result i32) (local i32 i64)
    #|    i32.const 0
    #|    i64.const 1
    #|    loop $l (type $loop_t)
    #|      local.set 2
    #|      local.set 1
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.get 2
    #|      i64.const 1
    #|      i64.add
    #|      local.get 0
    #|      br_table $l $l
    #|    end
    #|    local.get 1))
    #|)
  ssa_test_expect_loop_param_store_model(source, 3)
}

///|
test "ssa-nomerge rewrites mixed-target single-result typed loop br_table backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32) (result i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    block $exit (result i32)
    #|      i32.const 0
    #|      loop $l (type $loop_t)
    #|        local.tee 1
    #|        i32.const 1
    #|        i32.add
    #|        local.get 0
    #|        br_table $l $exit
    #|      end
    #|    end)
    #|)
  let (_, instrs) = try! ssa_test_expect_typed_loop_boundary_output(
    source, 2, "mixed-target single-result br_table",
  )
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
  assert_true(instrs.to_string().contains("i32.eq"), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites mixed-target single-param no-result typed loop br_table backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    block $exit (result i32)
    #|      i32.const 0
    #|      loop $l (type $loop_t)
    #|        local.tee 1
    #|        i32.const 1
    #|        i32.add
    #|        local.get 0
    #|        br_table $l $exit
    #|      end
    #|      unreachable
    #|    end)
    #|)
  let (_, instrs) = try! ssa_test_expect_typed_loop_boundary_output(
    source, 2, "mixed-target single-param br_table",
  )
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
  assert_true(instrs.to_string().contains("i32.eq"), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites copy-needing mixed-target single-param no-result typed loop br_table backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    block $exit (result i32)
    #|      i32.const 0
    #|      loop $l (type $loop_t)
    #|        local.set 1
    #|        local.get 2
    #|        drop
    #|        local.get 1
    #|        i32.const 0
    #|        i32.eq
    #|        if
    #|          i32.const 7
    #|          local.set 2
    #|        else
    #|          i32.const 8
    #|          local.set 2
    #|        end
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.get 0
    #|        br_table $l $exit
    #|      end
    #|      unreachable
    #|    end)
    #|)
  let (_, instrs) = try! ssa_test_expect_typed_loop_boundary_output(
    source, 3, "copy-needing mixed-target single-param br_table",
  )
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
  assert_true(instrs.to_string().contains("i32.eq"), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites mixed-target multi-param typed loop br_table backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32 i64)))
    #|  (type $exit_t (func (result i32 i64)))
    #|  (func (param i32) (result i32 i64) (local i32 i64)
    #|    block $exit (type $exit_t)
    #|      i32.const 0
    #|      i64.const 1
    #|      loop $l (type $loop_t)
    #|        local.set 2
    #|        local.set 1
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.get 2
    #|        i64.const 1
    #|        i64.add
    #|        local.get 0
    #|        br_table $l $exit
    #|      end
    #|      unreachable
    #|    end)
    #|)
  let (_, instrs) = try! ssa_test_expect_typed_loop_boundary_output(
    source, 3, "mixed-target multi-param br_table",
  )
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
  assert_true(instrs.to_string().contains("i32.eq"), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites copy-needing mixed-target single-result typed loop br_table backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32) (result i32)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    block $exit (result i32)
    #|      i32.const 0
    #|      loop $l (type $loop_t)
    #|        local.set 1
    #|        local.get 1
    #|        i32.const 0
    #|        i32.eq
    #|        if
    #|          i32.const 7
    #|          local.set 2
    #|        else
    #|          i32.const 8
    #|          local.set 2
    #|        end
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.get 0
    #|        br_table $l $exit
    #|      end
    #|    end)
    #|)
  let (_, instrs) = try! ssa_test_expect_typed_loop_boundary_output(
    source, 3, "copy-needing mixed-target single-result br_table",
  )
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
  assert_true(instrs.to_string().contains("i32.eq"), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites single-result typed loop direct br backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32) (result i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    loop $l (type $loop_t)
    #|      local.tee 1
    #|      local.get 0
    #|      i32.lt_s
    #|      if
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        br $l
    #|      end
    #|      local.get 1
    #|    end)
    #|)
  ssa_test_expect_loop_param_store_model(source, 2)
}

///|
test "ssa-nomerge rewrites single-result typed loop br_if backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32) (result i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    loop $l (type $loop_t)
    #|      local.set 1
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.get 1
    #|      local.get 0
    #|      i32.lt_s
    #|      br_if $l
    #|      drop
    #|      local.get 1
    #|    end)
    #|)
  ssa_test_expect_loop_param_store_model(source, 2)
}

///|
test "ssa-nomerge rewrites multi-param single-result typed loop br_table backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32 i64) (result i32)))
    #|  (func (param i32) (result i32) (local i32 i64)
    #|    i32.const 0
    #|    i64.const 1
    #|    loop $l (type $loop_t)
    #|      local.set 2
    #|      local.set 1
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.get 2
    #|      i64.const 1
    #|      i64.add
    #|      local.get 0
    #|      br_table $l $l
    #|    end)
    #|)
  ssa_test_expect_loop_param_store_model(source, 3)
}

///|
test "ssa-nomerge rewrites multi-param typed loop br_on_null backedges" {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let extern_ref = @lib.ValType::ref_type(@lib.RefType::new(true, extern_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), extern_ref], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([extern_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), extern_ref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected multi-param br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites copy-needing multi-param typed loop br_on_null backedges" {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let extern_ref = @lib.ValType::ref_type(@lib.RefType::new(true, extern_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), extern_ref], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([extern_ref, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), extern_ref, extern_ref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
                  ],
                  Some([
                    @lib.Instruction::ref_null(extern_heap),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(extern_heap),
                @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected copy-needing multi-param br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 3, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_instrs_have_ref_null_branch_copy_lowering(instrs, 4U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites copy-needing multi-param single-result typed loop br_on_null backedges" {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let extern_ref = @lib.ValType::ref_type(@lib.RefType::new(true, extern_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), extern_ref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([extern_ref, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), extern_ref, extern_ref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
                  ],
                  Some([
                    @lib.Instruction::ref_null(extern_heap),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(extern_heap),
                @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected copy-needing multi-param single-result br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 3, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_instrs_have_ref_null_branch_copy_lowering(instrs, 4U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites multi-param typed loop br_on_non_null backedges" {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let extern_ref = @lib.ValType::ref_type(@lib.RefType::new(true, extern_heap))
  let non_null_extern_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, extern_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), non_null_extern_ref], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([non_null_extern_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), extern_ref, extern_ref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected multi-param br_on_non_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 3, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites copy-needing multi-param typed loop br_on_non_null backedges" {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let extern_ref = @lib.ValType::ref_type(@lib.RefType::new(true, extern_heap))
  let non_null_extern_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, extern_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), non_null_extern_ref], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([non_null_extern_ref, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([
            @lib.ValType::i32(),
            extern_ref,
            extern_ref,
            extern_ref,
          ]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
                  ],
                  Some([
                    @lib.Instruction::ref_null(extern_heap),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(extern_heap),
                @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected copy-needing multi-param br_on_non_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 4, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_instrs_have_ref_non_null_branch_copy_lowering(instrs, 4U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites copy-needing multi-param single-result typed loop br_on_non_null backedges" {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let extern_ref = @lib.ValType::ref_type(@lib.RefType::new(true, extern_heap))
  let non_null_extern_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, extern_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), non_null_extern_ref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([non_null_extern_ref, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([
            @lib.ValType::i32(),
            extern_ref,
            extern_ref,
            extern_ref,
          ]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
                  ],
                  Some([
                    @lib.Instruction::ref_null(extern_heap),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(extern_heap),
                @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected copy-needing multi-param single-result br_on_non_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 4, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_instrs_have_ref_non_null_branch_copy_lowering(instrs, 4U),
    msg=instrs.to_string(),
  )
}

///|
fn ssa_test_multi_param_loop_store_local_tee_ref_branch_module(
  non_null_branch : Bool,
  single_result : Bool,
) -> @lib.Module {
  let struct_idx = @lib.TypeIdx::new(0U)
  let struct_heap = @lib.HeapType::new(struct_idx)
  let nullable_struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, struct_heap),
  )
  let non_null_struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, struct_heap),
  )
  let loop_ref_type = if non_null_branch {
    non_null_struct_ref
  } else {
    nullable_struct_ref
  }
  let loop_result_types = if single_result { [@lib.ValType::i32()] } else { [] }
  let loop_body : Array[@lib.Instruction] = [
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::i32_add(),
  ]
  if !non_null_branch {
    loop_body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(2U)))
  }
  loop_body.append([
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(3U)),
  ])
  if non_null_branch {
    loop_body.push(@lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)))
    if !single_result {
      loop_body.push(@lib.Instruction::drop())
    }
  } else {
    loop_body.push(@lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)))
    loop_body.push(@lib.Instruction::drop())
    loop_body.push(@lib.Instruction::drop())
    if !single_result {
      loop_body.push(@lib.Instruction::drop())
    }
  }
  let func_body : Array[@lib.Instruction] = [@lib.Instruction::i32_const(0)]
  if non_null_branch {
    func_body.push(@lib.Instruction::struct_new_default(struct_idx))
  } else {
    func_body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  }
  func_body.push(
    @lib.Instruction::loop_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      @lib.Expr::new(loop_body),
    ),
  )
  if !single_result {
    func_body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func(
            [@lib.ValType::i32(), loop_ref_type],
            loop_result_types,
          ),
        ),
      ),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([nullable_struct_ref], [@lib.ValType::i32()]),
        ),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([
          @lib.ValType::i32(),
          nullable_struct_ref,
          nullable_struct_ref,
        ]),
        @lib.Expr::new(func_body),
      ),
    ]),
  )
}

///|
test "ssa-nomerge rewrites ref-null-tested multi-param typed loop br_on_null backedges" {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let extern_ref = @lib.ValType::ref_type(@lib.RefType::new(true, extern_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), extern_ref], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([extern_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), extern_ref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::ref_null_type(
                  @lib.RefType::new(true, extern_heap),
                ),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ref-null-tested br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites ref-null-tested multi-param typed loop br_on_non_null backedges" {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let non_null_extern_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, extern_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), non_null_extern_ref], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([non_null_extern_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
                @lib.Instruction::ref_null_type(
                  @lib.RefType::new(true, extern_heap),
                ),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ref-null-tested br_on_non_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites any-convert-tested multi-param typed loop br_on_null backedges" {
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::anyref()], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::externref()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::anyref()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::any_convert_extern(),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::any_convert_extern(),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected any-convert-tested br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites extern-convert-tested multi-param typed loop br_on_null backedges" {
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [@lib.ValType::i32(), @lib.ValType::externref()],
              [],
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::anyref()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([
            @lib.ValType::i32(),
            @lib.ValType::externref(),
          ]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::extern_convert_any(),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::extern_convert_any(),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected extern-convert-tested br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites ref-cast-tested multi-param typed loop br_on_null backedges" {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let any_ref = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), any_ref], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([any_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::ref_cast(true, any_heap),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ref-cast-tested br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites ref-cast-tested multi-param typed loop br_on_non_null backedges" {
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i31ref()], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::ref_i31(),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
                @lib.Instruction::ref_null_type(
                  @lib.RefType::new(true, i31_heap),
                ),
                @lib.Instruction::ref_cast(true, i31_heap),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ref-cast-tested br_on_non_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites ref-i31-tested multi-param typed loop br_on_null backedges" {
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [@lib.ValType::i32(), @lib.ValType::i31ref_nullable()],
              [@lib.ValType::i32()],
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_i31(),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
                @lib.Instruction::ref_null_type(
                  @lib.RefType::new(
                    true,
                    @lib.HeapType::abs(@lib.AbsHeapType::i31()),
                  ),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::ref_i31(),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ref-i31-tested br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites ref-i31-tested multi-param typed loop br_on_non_null backedges" {
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i31ref()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_i31(),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::ref_i31(),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ref-i31-tested br_on_non_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites ref-func-tested multi-param typed loop br_on_null concrete-label backedges" {
  let callee_type_idx = @lib.TypeIdx::new(0U)
  let loop_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let callee_heap = @lib.HeapType::new(callee_type_idx)
  let nullable_callee_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, callee_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), nullable_callee_ref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx, callee_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(1U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), nullable_callee_ref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::ref_null(callee_heap),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(loop_type_idx),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
          ]),
        ),
        @lib.Func::new(@lib.Locals::new([]), @lib.Expr::new([])),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ref-func-tested br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites ref-func-tested multi-param typed loop br_on_non_null concrete-label backedges" {
  let callee_type_idx = @lib.TypeIdx::new(0U)
  let loop_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let callee_heap = @lib.HeapType::new(callee_type_idx)
  let nullable_callee_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, callee_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), nullable_callee_ref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx, callee_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(1U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), nullable_callee_ref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::ref_null(callee_heap),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(loop_type_idx),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
                @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
              ]),
            ),
          ]),
        ),
        @lib.Func::new(@lib.Locals::new([]), @lib.Expr::new([])),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ref-func-tested br_on_non_null concrete-label loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites ref-func-tested multi-param typed loop br_on_non_null funcref-label backedges" {
  let callee_type_idx = @lib.TypeIdx::new(0U)
  let loop_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let funcref = @lib.ValType::funcref()
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), funcref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx, callee_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(1U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), funcref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::ref_null_type(
              @lib.RefType::abs(@lib.AbsHeapType::func()),
            ),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(loop_type_idx),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
                @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
              ]),
            ),
          ]),
        ),
        @lib.Func::new(@lib.Locals::new([]), @lib.Expr::new([])),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ref-func-tested br_on_non_null funcref-label loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites struct-subtype-new-default-tested multi-param typed loop br_on_non_null parent-label backedges" {
  let base_idx = @lib.TypeIdx::new(0U)
  let child_idx = @lib.TypeIdx::new(1U)
  let loop_type_idx = @lib.TypeIdx::new(2U)
  let test_type_idx = @lib.TypeIdx::new(3U)
  let base_heap = @lib.HeapType::new(base_idx)
  let nullable_base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, base_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(
          @lib.SubType::new(false, [base_idx], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), nullable_base_ref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::ref_null(base_heap),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(loop_type_idx),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
                @lib.Instruction::struct_new_default(child_idx),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected struct-subtype-new-default-tested br_on_non_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites array-subtype-new-default-tested multi-param typed loop br_on_non_null parent-label backedges" {
  let base_idx = @lib.TypeIdx::new(0U)
  let child_idx = @lib.TypeIdx::new(1U)
  let loop_type_idx = @lib.TypeIdx::new(2U)
  let test_type_idx = @lib.TypeIdx::new(3U)
  let base_heap = @lib.HeapType::new(base_idx)
  let nullable_base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, base_heap),
  )
  let array_field = @lib.FieldType::new(
    @lib.StorageType::val_type(@lib.ValType::i32()),
    @lib.Mut::var_(),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::array(array_field)),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [base_idx],
            @lib.CompType::array(array_field),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), nullable_base_ref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::ref_null(base_heap),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(loop_type_idx),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::array_new_default(child_idx),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected array-subtype-new-default-tested br_on_non_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites ref-func-subtype-tested multi-param typed loop br_on_non_null parent-label backedges" {
  let base_idx = @lib.TypeIdx::new(0U)
  let child_idx = @lib.TypeIdx::new(1U)
  let loop_type_idx = @lib.TypeIdx::new(2U)
  let test_type_idx = @lib.TypeIdx::new(3U)
  let base_heap = @lib.HeapType::new(base_idx)
  let nullable_base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, base_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::new(false, [base_idx], @lib.CompType::func([], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), nullable_base_ref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx, child_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(1U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::ref_null(base_heap),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(loop_type_idx),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
                @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
              ]),
            ),
          ]),
        ),
        @lib.Func::new(@lib.Locals::new([]), @lib.Expr::new([])),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ref-func-subtype-tested br_on_non_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites struct-new-default-tested multi-param typed loop br_on_null backedges" {
  let struct_idx = @lib.TypeIdx::new(0U)
  let struct_heap = @lib.HeapType::new(struct_idx)
  let nullable_struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, struct_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), nullable_struct_ref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), nullable_struct_ref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::ref_null(struct_heap),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::struct_new_default(struct_idx),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected struct-new-default-tested br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites array-new-default-tested multi-param typed loop br_on_null backedges" {
  let array_idx = @lib.TypeIdx::new(0U)
  let array_heap = @lib.HeapType::new(array_idx)
  let nullable_array_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, array_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::array(
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::var_(),
              ),
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), nullable_array_ref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), nullable_array_ref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::ref_null(array_heap),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(@lib.I32::new(0)),
                @lib.Instruction::array_new_default(array_idx),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected array-new-default-tested br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites struct-new-default-tested multi-param typed loop br_on_non_null nullable-label backedges" {
  let struct_idx = @lib.TypeIdx::new(0U)
  let struct_heap = @lib.HeapType::new(struct_idx)
  let nullable_struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, struct_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), nullable_struct_ref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::ref_null(struct_heap),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
                @lib.Instruction::struct_new_default(struct_idx),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected struct-new-default-tested br_on_non_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites array-new-default-tested multi-param typed loop br_on_non_null nullable-label backedges" {
  let array_idx = @lib.TypeIdx::new(0U)
  let array_heap = @lib.HeapType::new(array_idx)
  let nullable_array_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, array_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::array(
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::var_(),
              ),
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), nullable_array_ref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::ref_null(array_heap),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::array_new_default(array_idx),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected array-new-default-tested br_on_non_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites array-new-data-tested multi-param typed loop br_on_non_null nullable-label backedges" {
  let array_idx = @lib.TypeIdx::new(0U)
  let array_heap = @lib.HeapType::new(array_idx)
  let nullable_array_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, array_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::array(
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::var_(),
              ),
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), nullable_array_ref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_data_sec(
      @lib.DataSec::new([@lib.Data::new(@lib.DataMode::passive(), b"")]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::ref_null(array_heap),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(0)),
                @lib.Instruction::i32_const(@lib.I32::new(0)),
                @lib.Instruction::array_new_data(
                  array_idx,
                  @lib.DataIdx::new(0U),
                ),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected array-new-data-tested br_on_non_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites array-new-elem-tested multi-param typed loop br_on_non_null nullable-label backedges" {
  let array_idx = @lib.TypeIdx::new(0U)
  let array_heap = @lib.HeapType::new(array_idx)
  let nullable_array_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, array_heap),
  )
  let funcref = @lib.ValType::funcref()
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::array(
              @lib.FieldType::new(
                @lib.StorageType::val_type(funcref),
                @lib.Mut::var_(),
              ),
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), nullable_array_ref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(@lib.ElemMode::passive(), @lib.ElemKind::funcs([])),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::ref_null(array_heap),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(0)),
                @lib.Instruction::i32_const(@lib.I32::new(0)),
                @lib.Instruction::array_new_elem(
                  array_idx,
                  @lib.ElemIdx::new(0U),
                ),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected array-new-elem-tested br_on_non_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites local-tee-tested multi-param typed loop br_on_null backedges" {
  let input = ssa_test_multi_param_loop_store_local_tee_ref_branch_module(
    false, false,
  )
  let (locals, instrs) = try! ssa_test_expect_null_branch_boundary_module_output(
    input, 0, "local-tee-tested multi-param br_on_null loop-param",
  )
  assert_true(locals.length() > 3, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites local-tee-tested multi-param single-result typed loop br_on_null backedges" {
  let input = ssa_test_multi_param_loop_store_local_tee_ref_branch_module(
    false, true,
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected local-tee-tested multi-param single-result br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 3, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites local-tee-tested multi-param typed loop br_on_non_null backedges" {
  let input = ssa_test_multi_param_loop_store_local_tee_ref_branch_module(
    true, false,
  )
  let (locals, instrs) = try! ssa_test_expect_null_branch_boundary_module_output(
    input, 0, "local-tee-tested multi-param br_on_non_null loop-param",
  )
  assert_true(locals.length() > 3, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites local-tee-tested multi-param single-result typed loop br_on_non_null backedges" {
  let input = ssa_test_multi_param_loop_store_local_tee_ref_branch_module(
    true, true,
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected local-tee-tested multi-param single-result br_on_non_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 3, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites multi-param single-result typed loop br_on_null backedges" {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let extern_ref = @lib.ValType::ref_type(@lib.RefType::new(true, extern_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), extern_ref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([extern_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), extern_ref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected multi-param single-result br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested-loop multi-param typed loop br backedges" {
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i64()], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i64()], []),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i64()]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::loop_(
                  @lib.BlockType::void_(),
                  @lib.Expr::new([
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::i32_const(@lib.I32::new(1)),
                    @lib.Instruction::i32_add(),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                    @lib.Instruction::i64_const(@lib.I64::new(1L)),
                    @lib.Instruction::i64_add(),
                    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nested-loop multi-param br loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested-loop multi-param single-result typed loop br_if backedges" {
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i64()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i64()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i64()]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::loop_(
                  @lib.BlockType::void_(),
                  @lib.Expr::new([
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::i32_const(@lib.I32::new(1)),
                    @lib.Instruction::i32_add(),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                    @lib.Instruction::i64_const(@lib.I64::new(1L)),
                    @lib.Instruction::i64_add(),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::i32_const(@lib.I32::new(10)),
                    @lib.Instruction::i32_lt_s(),
                    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
                    @lib.Instruction::unreachable_(),
                  ]),
                ),
                @lib.Instruction::unreachable_(),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nested-loop multi-param single-result br_if loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested-loop multi-param typed loop br_on_null backedges" {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let any_ref = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), any_ref], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([any_ref], [])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), any_ref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::loop_(
                  @lib.BlockType::void_(),
                  @lib.Expr::new([
                    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                    @lib.Instruction::i32_const(@lib.I32::new(1)),
                    @lib.Instruction::i32_add(),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::br_on_null(@lib.LabelIdx::new(1U)),
                    @lib.Instruction::drop(),
                    @lib.Instruction::drop(),
                    @lib.Instruction::drop(),
                    @lib.Instruction::unreachable_(),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nested-loop multi-param br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested self-loop br_if plus multi-param typed loop br backedges" {
  let source =
    #|(module
    #|  (type $outer_t (func (param i32 i64)))
    #|  (func (param i32 i64) (result i32) (local i32 i64)
    #|    local.get 0
    #|    local.get 1
    #|    loop $outer (type $outer_t)
    #|      local.set 3
    #|      local.set 2
    #|      loop $inner
    #|        local.get 2
    #|        i32.const 0
    #|        i32.gt_s
    #|        br_if $inner
    #|        local.get 2
    #|        i32.const 1
    #|        i32.add
    #|        local.get 3
    #|        i64.const 1
    #|        i64.add
    #|        br $outer
    #|      end
    #|    end
    #|    local.get 2)
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested self-loop br_if plus single-result typed loop br_if backedges" {
  let source =
    #|(module
    #|  (type $outer_t (func (param i32 i64) (result i32)))
    #|  (func (param i32 i64) (result i32) (local i32 i64)
    #|    local.get 0
    #|    local.get 1
    #|    loop $outer (type $outer_t)
    #|      local.set 3
    #|      local.set 2
    #|      loop $inner
    #|        local.get 2
    #|        i32.const 0
    #|        i32.gt_s
    #|        br_if $inner
    #|        local.get 2
    #|        i32.const 1
    #|        i32.add
    #|        local.get 3
    #|        i64.const 1
    #|        i64.add
    #|        local.get 2
    #|        i32.const 10
    #|        i32.lt_s
    #|        br_if $outer
    #|        unreachable
    #|      end
    #|      unreachable
    #|    end)
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested self-loop br_if plus typed loop br_on_null backedges" {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let extern_ref = @lib.ValType::ref_type(@lib.RefType::new(true, extern_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), extern_ref], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([extern_ref], [])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), extern_ref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::loop_(
                  @lib.BlockType::void_(),
                  @lib.Expr::new([
                    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                    @lib.Instruction::i32_const(@lib.I32::new(0)),
                    @lib.Instruction::i32_gt_s(),
                    @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                    @lib.Instruction::i32_const(@lib.I32::new(1)),
                    @lib.Instruction::i32_add(),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::br_on_null(@lib.LabelIdx::new(1U)),
                    @lib.Instruction::drop(),
                    @lib.Instruction::drop(),
                    @lib.Instruction::drop(),
                    @lib.Instruction::unreachable_(),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nested self-loop br_if plus br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
fn ssa_test_multi_param_loop_store_cast_module(
  fail_variant : Bool,
  copy_needed : Bool,
  single_result : Bool,
) -> @lib.Module {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let any_ref_type = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let i31_ref_type = @lib.ValType::ref_type(@lib.RefType::new(false, i31_heap))
  let nullable_i31_ref_type = @lib.ValType::ref_type(
    @lib.RefType::new(true, i31_heap),
  )
  let loop_ref_type = if fail_variant { any_ref_type } else { i31_ref_type }
  let stored_ref_type = if fail_variant {
    any_ref_type
  } else {
    nullable_i31_ref_type
  }
  let loop_result_types = if single_result { [@lib.ValType::i32()] } else { [] }
  let loop_body : Array[@lib.Instruction] = [
    @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
  ]
  if copy_needed {
    loop_body.append([
      @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
        ],
        Some([
          @lib.Instruction::ref_null(any_heap),
          @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
        ]),
      ),
    ])
  }
  loop_body.append([
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(
      if fail_variant {
        @lib.LocalIdx::new(3U)
      } else {
        @lib.LocalIdx::new(0U)
      },
    ),
  ])
  if fail_variant {
    loop_body.push(
      @lib.Instruction::br_on_cast_fail(
        @lib.LabelIdx::new(0U),
        true,
        any_heap,
        false,
        i31_heap,
      ),
    )
  } else {
    loop_body.push(
      @lib.Instruction::br_on_cast(
        @lib.LabelIdx::new(0U),
        true,
        any_heap,
        false,
        i31_heap,
      ),
    )
  }
  loop_body.append([@lib.Instruction::drop(), @lib.Instruction::drop()])
  if copy_needed {
    loop_body.append([
      @lib.Instruction::ref_null(any_heap),
      @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
    ])
  }
  if single_result {
    loop_body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(2U)))
  }
  let func_body : Array[@lib.Instruction] = [
    @lib.Instruction::i32_const(@lib.I32::new(0)),
  ]
  if fail_variant {
    func_body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  } else {
    func_body.push(@lib.Instruction::i32_const(@lib.I32::new(1)))
    func_body.push(@lib.Instruction::ref_i31())
  }
  func_body.push(
    @lib.Instruction::loop_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      @lib.Expr::new(loop_body),
    ),
  )
  if !single_result {
    func_body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(2U)))
  }
  let local_types = if copy_needed {
    [@lib.ValType::i32(), stored_ref_type, any_ref_type]
  } else {
    [@lib.ValType::i32(), stored_ref_type]
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func(
            [@lib.ValType::i32(), loop_ref_type],
            loop_result_types,
          ),
        ),
      ),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([any_ref_type, @lib.ValType::i32()], [
            @lib.ValType::i32(),
          ]),
        ),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types(local_types),
        @lib.Expr::new(func_body),
      ),
    ]),
  )
}

///|
test "ssa-nomerge rewrites multi-param typed loop br_on_cast backedges" {
  let input = ssa_test_multi_param_loop_store_cast_module(false, false, false)
  let (locals, instrs, _) = try! ssa_test_expect_cast_branch_boundary_module_output(
    input, 0, "multi-param br_on_cast loop-param",
  )
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites copy-needing multi-param typed loop br_on_cast backedges" {
  let input = ssa_test_multi_param_loop_store_cast_module(false, true, false)
  let (locals, instrs, _) = try! ssa_test_expect_cast_branch_boundary_module_output(
    input, 0, "copy-needing multi-param br_on_cast loop-param",
  )
  assert_true(locals.length() > 3, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_instrs_have_ref_cast_branch_copy_block(instrs, 4U, true),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites copy-needing multi-param single-result typed loop br_on_cast backedges" {
  let input = ssa_test_multi_param_loop_store_cast_module(false, true, true)
  let (locals, instrs, _) = try! ssa_test_expect_cast_branch_boundary_module_output(
    input, 0, "copy-needing multi-param single-result br_on_cast loop-param",
  )
  assert_true(locals.length() > 3, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_instrs_have_ref_cast_branch_copy_block(instrs, 4U, true),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites copy-needing multi-param typed loop br_on_cast_fail backedges" {
  let input = ssa_test_multi_param_loop_store_cast_module(true, true, false)
  let (locals, instrs, _) = try! ssa_test_expect_cast_branch_boundary_module_output(
    input, 0, "copy-needing multi-param br_on_cast_fail loop-param",
  )
  assert_true(locals.length() > 3, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_instrs_have_ref_cast_branch_copy_block(instrs, 4U, false),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites copy-needing multi-param single-result typed loop br_on_cast_fail backedges" {
  let input = ssa_test_multi_param_loop_store_cast_module(true, true, true)
  let (locals, instrs, _) = try! ssa_test_expect_cast_branch_boundary_module_output(
    input, 0, "copy-needing multi-param single-result br_on_cast_fail loop-param",
  )
  assert_true(locals.length() > 3, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_instrs_have_ref_cast_branch_copy_block(instrs, 4U, false),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites no-throw try_table scalar proxy backedges" {
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    (block $h
    #|      i32.const 0
    #|      (loop $l (param i32)
    #|        local.set 1
    #|        (try_table (catch_all $h)
    #|          local.get 1
    #|          i32.const 1
    #|          i32.add
    #|          br $l)))
    #|    local.get 1))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected no-throw try_table scalar proxy backedge ssa-nomerge success, got \{err}",
      )
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected no-throw try_table scalar proxy backedge output to validate, got \{@validate.validation_error_message(err)}",
      )
  }
  assert_true(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites no-throw try_table multi-param typed loop br backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32 i32)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    (block $h
    #|      i32.const 0
    #|      local.get 0
    #|      (loop $l (type $loop_t)
    #|        local.set 2
    #|        local.set 1
    #|        (try_table (catch_all $h)
    #|          local.get 1
    #|          i32.const 1
    #|          i32.add
    #|          local.get 2
    #|          br $l)))
    #|    local.get 1))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites no-throw try_table single-result typed loop br backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32 i32) (result i32)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    i32.const 0
    #|    local.get 0
    #|    (loop $l (type $loop_t)
    #|      local.set 2
    #|      local.set 1
    #|      (block $h
    #|        (try_table (catch_all $h)
    #|          local.get 1
    #|          i32.const 1
    #|          i32.add
    #|          local.get 2
    #|          br $l))
    #|      unreachable)))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites throwing try_table typed loop backedges" {
  let source =
    #|(module
    #|  (tag $e)
    #|  (func (param i32) (result i32) (local i32)
    #|    (block $h
    #|      i32.const 0
    #|      (loop $l (param i32)
    #|        local.set 1
    #|        (try_table (catch $e $h)
    #|          local.get 1
    #|          i32.const 1
    #|          i32.add
    #|          br $l
    #|          throw $e)))
    #|    local.get 1))
    #|)
  let optimized = ssa_test_pipeline_expected_mutation_valid(
    source, "throwing try_table typed-loop backedge",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites multi-result typed loop-param direct br" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32) (result i32 i64)))
    #|  (func (param i32) (result i32 i64) (local i32)
    #|    i32.const 0
    #|    loop $l (type $loop_t)
    #|      local.tee 1
    #|      local.get 0
    #|      i32.lt_s
    #|      if
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        br $l
    #|      end
    #|      local.get 1
    #|      i64.const 7
    #|    end)
    #|)
  let optimized = ssa_test_pipeline_expected_mutation_valid(
    source, "multi-result typed loop-param direct br",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites multi-instruction br_on_null loop-store tested refs" {
  let externref = @lib.ValType::externref()
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::block(
                  @lib.BlockType::val_type(externref),
                  @lib.Expr::new([
                    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                  ]),
                ),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "multi-instruction br_on_null loop-store tested ref",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites if-result br_on_null loop-store tested refs" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), externref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(0),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::val_type(externref),
                  [@lib.Instruction::local_get(@lib.LocalIdx::new(1U))],
                  Some([@lib.Instruction::ref_null(extern_heap)]),
                ),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "if-result br_on_null loop-store tested ref",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 3U),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites select-result br_on_null loop-store tested refs" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), externref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(0),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::ref_null(extern_heap),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::select(types=Some([externref])),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "select-result br_on_null loop-store tested ref",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 3U),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites multi-instruction br_on_non_null loop-store tested refs" {
  let externref = @lib.ValType::externref()
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::block(
                  @lib.BlockType::val_type(externref),
                  @lib.Expr::new([
                    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                  ]),
                ),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "multi-instruction br_on_non_null loop-store tested ref",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites if-result br_on_non_null loop-store tested refs" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(1),
                @lib.Instruction::if_(
                  @lib.BlockType::val_type(externref),
                  [@lib.Instruction::local_get(@lib.LocalIdx::new(1U))],
                  Some([@lib.Instruction::ref_null(extern_heap)]),
                ),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "if-result br_on_non_null loop-store tested ref",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites select-result br_on_non_null loop-store tested refs" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::ref_null(extern_heap),
                @lib.Instruction::i32_const(1),
                @lib.Instruction::select(types=Some([externref])),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "select-result br_on_non_null loop-store tested ref",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites non-current multi-instruction br_on_null branch inputs" {
  let externref = @lib.ValType::externref()
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([externref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ],
              Some([
                @lib.Instruction::i32_const(8),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ]),
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::block(
                  @lib.BlockType::val_type(externref),
                  @lib.Expr::new([
                    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                  ]),
                ),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(9),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "non-current multi-instruction br_on_null branch input",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites non-current multi-instruction br_on_non_null branch inputs" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ],
              Some([
                @lib.Instruction::i32_const(8),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ]),
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(externref),
              @lib.Expr::new([
                @lib.Instruction::block(
                  @lib.BlockType::val_type(externref),
                  @lib.Expr::new([
                    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                  ]),
                ),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "non-current multi-instruction br_on_non_null branch input",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites non-current if-result br_on_null branch inputs" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([externref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ],
              Some([
                @lib.Instruction::i32_const(8),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ]),
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(1),
                @lib.Instruction::if_(
                  @lib.BlockType::val_type(externref),
                  [@lib.Instruction::local_get(@lib.LocalIdx::new(0U))],
                  Some([@lib.Instruction::ref_null(extern_heap)]),
                ),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(9),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "non-current if-result br_on_null branch input",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites non-current if-result br_on_non_null branch inputs" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(externref),
              @lib.Expr::new([
                @lib.Instruction::i32_const(1),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(7),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(8),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                  ]),
                ),
                @lib.Instruction::i32_const(1),
                @lib.Instruction::if_(
                  @lib.BlockType::val_type(externref),
                  [@lib.Instruction::local_get(@lib.LocalIdx::new(0U))],
                  Some([@lib.Instruction::ref_null(extern_heap)]),
                ),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::i32_const(9),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "non-current if-result br_on_non_null branch input",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_instrs_have_ref_non_null_branch_copy_lowering(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites non-current prefix if-result br_on_non_null branch inputs" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([externref, @lib.ValType::i32()], [
              @lib.ValType::i32(),
              externref,
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ],
              Some([
                @lib.Instruction::i32_const(8),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ]),
            ),
            @lib.Instruction::block(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(1),
                @lib.Instruction::if_(
                  @lib.BlockType::val_type(externref),
                  [@lib.Instruction::local_get(@lib.LocalIdx::new(0U))],
                  Some([@lib.Instruction::ref_null(extern_heap)]),
                ),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::i32_const(9),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "non-current prefix if-result br_on_non_null branch input",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 2U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites non-current prefix if-result br_on_null branch inputs" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([externref], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ],
              Some([
                @lib.Instruction::i32_const(8),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ]),
            ),
            @lib.Instruction::block(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(1),
                @lib.Instruction::if_(
                  @lib.BlockType::val_type(externref),
                  [@lib.Instruction::local_get(@lib.LocalIdx::new(0U))],
                  Some([@lib.Instruction::ref_null(extern_heap)]),
                ),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(9),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "non-current prefix if-result br_on_null branch input",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites non-current select-result br_on_null branch inputs" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([externref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ],
              Some([
                @lib.Instruction::i32_const(8),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ]),
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
                @lib.Instruction::i32_const(1),
                @lib.Instruction::select(types=Some([externref])),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(9),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "non-current select-result br_on_null branch input",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites non-current select-result br_on_non_null branch inputs" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ],
              Some([
                @lib.Instruction::i32_const(8),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ]),
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(externref),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
                @lib.Instruction::i32_const(1),
                @lib.Instruction::select(types=Some([externref])),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "non-current select-result br_on_non_null branch input",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites non-current prefix select-result br_on_null branch inputs" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([externref], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ],
              Some([
                @lib.Instruction::i32_const(8),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ]),
            ),
            @lib.Instruction::block(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
                @lib.Instruction::i32_const(1),
                @lib.Instruction::select(types=Some([externref])),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(9),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "non-current prefix select-result br_on_null branch input",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites non-current prefix select-result br_on_non_null branch inputs" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([externref, @lib.ValType::i32()], [
              @lib.ValType::i32(),
              externref,
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ],
              Some([
                @lib.Instruction::i32_const(8),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ]),
            ),
            @lib.Instruction::block(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
                @lib.Instruction::i32_const(1),
                @lib.Instruction::select(types=Some([externref])),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::i32_const(9),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "non-current prefix select-result br_on_non_null branch input",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 2U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
// Problem 1 matrix: narrow final-producer positives plus deliberately
// fail-closed arbitrary reference branch inputs. These fixtures cover
// representative expression families that Binaryen can SSAify but Starshine SSA
// v1 must not lower by broad stack scanning: direct calls, calls with operands,
// allocation with operand evaluation, and prefix payload exits. Supported
// typed-control/select/direct final producers are covered by the positive tests
// immediately above and by the block-exit tests later in this file.
test "ssa-nomerge rewrites problem1 zero-param call br_on_null loop-store input" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let helper_type_idx = @lib.TypeIdx::new(0U)
  let loop_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([helper_type_idx, test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::ref_null(extern_heap)]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(loop_type_idx),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "call br_on_null loop-store input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites problem1 direct call operands br_on_null loop-store input" {
  // Narrow problem-1 implementation target: a final direct call with explicit
  // operands can be evaluated exactly once, spilled immediately after the call,
  // and lowered through the current typed-loop br_on_null store model without
  // scanning or duplicating the operand prefix.
  let externref = @lib.ValType::externref()
  let id_type_idx = @lib.TypeIdx::new(0U)
  let loop_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([id_type_idx, test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(1U))]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([externref, externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(loop_type_idx),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "direct call operands br_on_null loop-store input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites problem1 call_ref operands br_on_null loop-store input" {
  // Narrow problem-1 coverage sibling for direct calls: call_ref operands and
  // the function reference are consumed exactly once before the nullable result
  // is spilled into the existing typed-loop br_on_null store model.
  let externref = @lib.ValType::externref()
  let call_type_idx = @lib.TypeIdx::new(0U)
  let loop_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let helper_idx = @lib.FuncIdx::new(0U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([call_type_idx, test_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([helper_idx]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(1U))]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(loop_type_idx),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::ref_func(helper_idx),
                @lib.Instruction::call_ref(call_type_idx),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "call_ref operands br_on_null loop-store input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites problem1 call_indirect operands br_on_null loop-store input" {
  // Coverage sibling for call_ref: the table index and value operands are
  // consumed before the nullable call_indirect result is spilled into the
  // existing typed-loop br_on_null store model.
  let externref = @lib.ValType::externref()
  let call_type_idx = @lib.TypeIdx::new(0U)
  let loop_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            @lib.RefType::new(
              true,
              @lib.HeapType::abs(@lib.AbsHeapType::func()),
            ),
            @lib.Limits::i32(1U, Some(1U)),
          ),
          None,
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(loop_type_idx),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(0),
                @lib.Instruction::call_indirect(
                  call_type_idx,
                  @lib.TableIdx::new(0U),
                ),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "call_indirect operands br_on_null loop-store input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 0)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites problem1 zero-param call br_on_non_null loop-store input" {
  // Narrow problem-1 implementation: a zero-param single-ref-result call can
  // be evaluated once, spilled immediately, and then tested via the existing
  // typed-loop store model without scanning across arbitrary call operands.
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let helper_type_idx = @lib.TypeIdx::new(0U)
  let loop_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([helper_type_idx, test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::ref_null(extern_heap)]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(loop_type_idx),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "call br_on_non_null loop-store input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites problem1 direct call operands br_on_non_null loop-store input" {
  // Narrow problem-1 implementation target: a final direct call with explicit
  // operands can be evaluated exactly once, spilled immediately after the call,
  // and lowered through the current typed-loop store model without scanning or
  // duplicating the operand prefix.
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let id_type_idx = @lib.TypeIdx::new(0U)
  let loop_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([id_type_idx, test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(1U))]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(loop_type_idx),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "direct call operands br_on_non_null loop-store input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites problem1 call_ref operands br_on_non_null loop-store input" {
  // Coverage sibling for direct calls: call_ref operands and the function
  // reference are consumed exactly once before the non-null taken result is
  // spilled into the existing typed-loop br_on_non_null store model.
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let call_type_idx = @lib.TypeIdx::new(0U)
  let loop_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let helper_idx = @lib.FuncIdx::new(0U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([call_type_idx, test_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([helper_idx]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(1U))]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(loop_type_idx),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::ref_func(helper_idx),
                @lib.Instruction::call_ref(call_type_idx),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "call_ref operands br_on_non_null loop-store input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites problem1 call_indirect operands br_on_non_null loop-store input" {
  // Coverage sibling for call_ref: the table index and value operands are
  // consumed before the non-null call_indirect result is spilled/tested through
  // the existing typed-loop br_on_non_null store model.
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let call_type_idx = @lib.TypeIdx::new(0U)
  let loop_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            @lib.RefType::new(
              true,
              @lib.HeapType::abs(@lib.AbsHeapType::func()),
            ),
            @lib.Limits::i32(1U, Some(1U)),
          ),
          None,
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(loop_type_idx),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(0),
                @lib.Instruction::call_indirect(
                  call_type_idx,
                  @lib.TableIdx::new(0U),
                ),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "call_indirect operands br_on_non_null loop-store input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 0)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites problem1 direct call br_on_null non-current input" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([], [externref])),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(1U)]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::ref_null(extern_heap)]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(externref),
              @lib.Expr::new([
                @lib.Instruction::ref_null(extern_heap),
                @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "direct call br_on_null non-current input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites problem1 direct call br_on_non_null non-current input" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([], [externref])),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(1U)]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::ref_null(extern_heap)]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(externref),
              @lib.Expr::new([
                @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "direct call br_on_non_null non-current input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites problem1 direct call operands br_on_null non-current input" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let id_type_idx = @lib.TypeIdx::new(0U)
  let test_type_idx = @lib.TypeIdx::new(1U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([id_type_idx, test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(1U))]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(externref),
              @lib.Expr::new([
                @lib.Instruction::ref_null(extern_heap),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "direct call operands br_on_null non-current input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites problem1 direct call operands br_on_non_null non-current input" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let id_type_idx = @lib.TypeIdx::new(0U)
  let test_type_idx = @lib.TypeIdx::new(1U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([id_type_idx, test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(1U))]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(externref),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "direct call operands br_on_non_null non-current input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites problem1 prefix direct call br_on_non_null input" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let result_type_idx = @lib.TypeIdx::new(1U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U), result_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::ref_null(extern_heap)]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::type_idx(result_type_idx),
              @lib.Expr::new([
                @lib.Instruction::i32_const(5),
                @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(6),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "prefix direct call br_on_non_null input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites problem1 call_ref operands br_on_non_null non-current input" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let call_type_idx = @lib.TypeIdx::new(0U)
  let test_type_idx = @lib.TypeIdx::new(1U)
  let helper_idx = @lib.FuncIdx::new(0U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([call_type_idx, test_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([helper_idx]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(1U))]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(externref),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::ref_func(helper_idx),
                @lib.Instruction::call_ref(call_type_idx),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "call_ref operands br_on_non_null non-current input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites problem1 call_ref operands br_on_null non-current input" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let call_type_idx = @lib.TypeIdx::new(0U)
  let test_type_idx = @lib.TypeIdx::new(1U)
  let helper_idx = @lib.FuncIdx::new(0U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([call_type_idx, test_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([helper_idx]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(1U))]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(externref),
              @lib.Expr::new([
                @lib.Instruction::ref_null(extern_heap),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::ref_func(helper_idx),
                @lib.Instruction::call_ref(call_type_idx),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "call_ref operands br_on_null non-current input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites problem1 call_indirect operands br_on_non_null non-current input" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let call_type_idx = @lib.TypeIdx::new(0U)
  let test_type_idx = @lib.TypeIdx::new(1U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            @lib.RefType::new(
              true,
              @lib.HeapType::abs(@lib.AbsHeapType::func()),
            ),
            @lib.Limits::i32(1U, Some(1U)),
          ),
          None,
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(externref),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(0),
                @lib.Instruction::call_indirect(
                  call_type_idx,
                  @lib.TableIdx::new(0U),
                ),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "call_indirect operands br_on_non_null non-current input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 0)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites problem1 call_indirect operands br_on_null non-current input" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let call_type_idx = @lib.TypeIdx::new(0U)
  let test_type_idx = @lib.TypeIdx::new(1U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            @lib.RefType::new(
              true,
              @lib.HeapType::abs(@lib.AbsHeapType::func()),
            ),
            @lib.Limits::i32(1U, Some(1U)),
          ),
          None,
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(externref),
              @lib.Expr::new([
                @lib.Instruction::ref_null(extern_heap),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(0),
                @lib.Instruction::call_indirect(
                  call_type_idx,
                  @lib.TableIdx::new(0U),
                ),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "call_indirect operands br_on_null non-current input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 0)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites problem1 prefix direct call operands br_on_non_null input" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let id_type_idx = @lib.TypeIdx::new(0U)
  let result_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [
              @lib.ValType::i32(),
              externref,
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([id_type_idx, test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(1U))]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::type_idx(result_type_idx),
              @lib.Expr::new([
                @lib.Instruction::i32_const(5),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(6),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "prefix direct call operands br_on_non_null input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites problem1 prefix call_ref operands br_on_non_null input" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let call_type_idx = @lib.TypeIdx::new(0U)
  let result_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let helper_idx = @lib.FuncIdx::new(0U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [
              @lib.ValType::i32(),
              externref,
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([call_type_idx, test_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([helper_idx]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(1U))]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::type_idx(result_type_idx),
              @lib.Expr::new([
                @lib.Instruction::i32_const(5),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::ref_func(helper_idx),
                @lib.Instruction::call_ref(call_type_idx),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(6),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "prefix call_ref operands br_on_non_null input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites problem1 prefix call_indirect operands br_on_non_null input" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let call_type_idx = @lib.TypeIdx::new(0U)
  let result_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [
              @lib.ValType::i32(),
              externref,
            ]),
          ),
        ),
      ]),
    )
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            @lib.RefType::new(
              true,
              @lib.HeapType::abs(@lib.AbsHeapType::func()),
            ),
            @lib.Limits::i32(1U, Some(1U)),
          ),
          None,
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::type_idx(result_type_idx),
              @lib.Expr::new([
                @lib.Instruction::i32_const(5),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(0),
                @lib.Instruction::call_indirect(
                  call_type_idx,
                  @lib.TableIdx::new(0U),
                ),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(6),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "prefix call_indirect operands br_on_non_null input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 0)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites problem1 prefix direct call operands then ref-cast br_on_non_null input" {
  // Coverage for the prefix-payload br_on_non_null sibling of the narrow
  // call/ref.cast suffix: operands are consumed before the final cast, and the
  // rewrite spills only that already-produced cast result.
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let id_type_idx = @lib.TypeIdx::new(0U)
  let result_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [
              @lib.ValType::i32(),
              externref,
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([id_type_idx, test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(1U))]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::type_idx(result_type_idx),
              @lib.Expr::new([
                @lib.Instruction::i32_const(5),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                @lib.Instruction::ref_cast(true, extern_heap),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(6),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "prefix direct call operands then ref-cast br_on_non_null input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites problem1 prefix call_ref operands then ref-cast br_on_non_null input" {
  // Coverage sibling for call_ref: the value operands and function reference are
  // consumed before ref.cast, and the prefix-payload branch rewrite still spills
  // only the final cast result.
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let call_type_idx = @lib.TypeIdx::new(0U)
  let result_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let helper_idx = @lib.FuncIdx::new(0U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [
              @lib.ValType::i32(),
              externref,
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([call_type_idx, test_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([helper_idx]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(1U))]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::type_idx(result_type_idx),
              @lib.Expr::new([
                @lib.Instruction::i32_const(5),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::ref_func(helper_idx),
                @lib.Instruction::call_ref(call_type_idx),
                @lib.Instruction::ref_cast(true, extern_heap),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(6),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "prefix call_ref operands then ref-cast br_on_non_null input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites problem1 prefix call_indirect operands then ref-cast br_on_non_null input" {
  // Coverage sibling for call_indirect: the table index and value operands are
  // consumed before ref.cast, so the prefix rewrite does not need broad stack
  // scanning or operand duplication.
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let call_type_idx = @lib.TypeIdx::new(0U)
  let result_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [
              @lib.ValType::i32(),
              externref,
            ]),
          ),
        ),
      ]),
    )
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            @lib.RefType::new(
              true,
              @lib.HeapType::abs(@lib.AbsHeapType::func()),
            ),
            @lib.Limits::i32(1U, Some(1U)),
          ),
          None,
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::type_idx(result_type_idx),
              @lib.Expr::new([
                @lib.Instruction::i32_const(5),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(0),
                @lib.Instruction::call_indirect(
                  call_type_idx,
                  @lib.TableIdx::new(0U),
                ),
                @lib.Instruction::ref_cast(true, extern_heap),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(6),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "prefix call_indirect operands then ref-cast br_on_non_null input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 0)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites problem1 prefix direct call operands br_on_null input" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let id_type_idx = @lib.TypeIdx::new(0U)
  let result_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [
              @lib.ValType::i32(),
              externref,
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([id_type_idx, test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(1U))]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::type_idx(result_type_idx),
              @lib.Expr::new([
                @lib.Instruction::i32_const(5),
                @lib.Instruction::ref_null(extern_heap),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(6),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "prefix direct call operands br_on_null input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites problem1 prefix call_ref operands br_on_null input" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let call_type_idx = @lib.TypeIdx::new(0U)
  let result_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let helper_idx = @lib.FuncIdx::new(0U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [
              @lib.ValType::i32(),
              externref,
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([call_type_idx, test_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([helper_idx]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(1U))]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::type_idx(result_type_idx),
              @lib.Expr::new([
                @lib.Instruction::i32_const(5),
                @lib.Instruction::ref_null(extern_heap),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::ref_func(helper_idx),
                @lib.Instruction::call_ref(call_type_idx),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(6),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "prefix call_ref operands br_on_null input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites problem1 prefix call_indirect operands br_on_null input" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let call_type_idx = @lib.TypeIdx::new(0U)
  let result_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [
              @lib.ValType::i32(),
              externref,
            ]),
          ),
        ),
      ]),
    )
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            @lib.RefType::new(
              true,
              @lib.HeapType::abs(@lib.AbsHeapType::func()),
            ),
            @lib.Limits::i32(1U, Some(1U)),
          ),
          None,
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::type_idx(result_type_idx),
              @lib.Expr::new([
                @lib.Instruction::i32_const(5),
                @lib.Instruction::ref_null(extern_heap),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(0),
                @lib.Instruction::call_indirect(
                  call_type_idx,
                  @lib.TableIdx::new(0U),
                ),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(6),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "prefix call_indirect operands br_on_null input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 0)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites problem1 prefix direct call operands then ref-cast br_on_null input" {
  // Coverage for the prefix-payload br_on_null sibling of the narrow
  // call/ref.cast suffix: operands are consumed before the final cast, and the
  // rewrite spills only that already-produced cast result.
  let anyref = @lib.ValType::anyref()
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let id_type_idx = @lib.TypeIdx::new(0U)
  let result_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), anyref], [anyref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), anyref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([anyref], [@lib.ValType::i32(), anyref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([id_type_idx, test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(1U))]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::type_idx(result_type_idx),
              @lib.Expr::new([
                @lib.Instruction::i32_const(5),
                @lib.Instruction::ref_null(any_heap),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                @lib.Instruction::ref_cast(true, any_heap),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(6),
                @lib.Instruction::ref_null(any_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "prefix direct call operands then ref-cast br_on_null input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites problem1 prefix call_ref operands then ref-cast br_on_null input" {
  // Coverage sibling for call_ref: the value operands and function reference are
  // consumed before ref.cast, and the prefix-payload branch rewrite still spills
  // only the final cast result.
  let anyref = @lib.ValType::anyref()
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let call_type_idx = @lib.TypeIdx::new(0U)
  let result_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let helper_idx = @lib.FuncIdx::new(0U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), anyref], [anyref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), anyref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([anyref], [@lib.ValType::i32(), anyref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([call_type_idx, test_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([helper_idx]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(1U))]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::type_idx(result_type_idx),
              @lib.Expr::new([
                @lib.Instruction::i32_const(5),
                @lib.Instruction::ref_null(any_heap),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::ref_func(helper_idx),
                @lib.Instruction::call_ref(call_type_idx),
                @lib.Instruction::ref_cast(true, any_heap),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(6),
                @lib.Instruction::ref_null(any_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "prefix call_ref operands then ref-cast br_on_null input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites problem1 prefix call_indirect operands then ref-cast br_on_null input" {
  // Coverage sibling for call_indirect: the table index and value operands are
  // consumed before ref.cast, so the prefix rewrite does not need broad stack
  // scanning or operand duplication.
  let anyref = @lib.ValType::anyref()
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let call_type_idx = @lib.TypeIdx::new(0U)
  let result_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), anyref], [anyref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), anyref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([anyref], [@lib.ValType::i32(), anyref]),
          ),
        ),
      ]),
    )
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            @lib.RefType::new(
              true,
              @lib.HeapType::abs(@lib.AbsHeapType::func()),
            ),
            @lib.Limits::i32(1U, Some(1U)),
          ),
          None,
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::type_idx(result_type_idx),
              @lib.Expr::new([
                @lib.Instruction::i32_const(5),
                @lib.Instruction::ref_null(any_heap),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(0),
                @lib.Instruction::call_indirect(
                  call_type_idx,
                  @lib.TableIdx::new(0U),
                ),
                @lib.Instruction::ref_cast(true, any_heap),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(6),
                @lib.Instruction::ref_null(any_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "prefix call_indirect operands then ref-cast br_on_null input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 0)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge fail-closed problem1 multi-result direct call br_on_null input" {
  // Boundary: multi-result calls are intentionally not rewritten for br_on_null
  // either. The first result may be a label payload while the second is the
  // tested reference; keep the raw branch until lane preservation is designed.
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let call_type_idx = @lib.TypeIdx::new(0U)
  let result_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([call_type_idx, test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(9),
            @lib.Instruction::ref_null(extern_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::type_idx(result_type_idx),
              @lib.Expr::new([
                @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(6),
              ]),
            ),
          ]),
        ),
      ]),
    )
  ssa_test_problem1_fail_closed_reference_branch_input(
    input, 1, "multi-result direct call br_on_null input", ssa_test_instrs_have_br_on_null,
  )
}

///|
test "ssa-nomerge fail-closed problem1 multi-result call_ref br_on_null input" {
  // Boundary: multi-result call_ref needs the same lane-preservation design as
  // direct multi-result calls, plus function-reference operand handling.
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let call_type_idx = @lib.TypeIdx::new(0U)
  let result_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let helper_idx = @lib.FuncIdx::new(0U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([call_type_idx, test_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([helper_idx]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(9),
            @lib.Instruction::ref_null(extern_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::type_idx(result_type_idx),
              @lib.Expr::new([
                @lib.Instruction::ref_func(helper_idx),
                @lib.Instruction::call_ref(call_type_idx),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(6),
              ]),
            ),
          ]),
        ),
      ]),
    )
  ssa_test_problem1_fail_closed_reference_branch_input(
    input, 1, "multi-result call_ref br_on_null input", ssa_test_instrs_have_br_on_null,
  )
}

///|
test "ssa-nomerge fail-closed problem1 multi-result call_indirect br_on_null input" {
  // Boundary: multi-result call_indirect also has a table-index operand; keep
  // this raw until the tested-result lane and payload lanes can be preserved.
  let externref = @lib.ValType::externref()
  let call_type_idx = @lib.TypeIdx::new(0U)
  let result_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            @lib.RefType::new(
              true,
              @lib.HeapType::abs(@lib.AbsHeapType::func()),
            ),
            @lib.Limits::i32(1U, Some(1U)),
          ),
          None,
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::type_idx(result_type_idx),
              @lib.Expr::new([
                @lib.Instruction::i32_const(0),
                @lib.Instruction::call_indirect(
                  call_type_idx,
                  @lib.TableIdx::new(0U),
                ),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(6),
              ]),
            ),
          ]),
        ),
      ]),
    )
  ssa_test_problem1_fail_closed_reference_branch_input(
    input, 0, "multi-result call_indirect br_on_null input", ssa_test_instrs_have_br_on_null,
  )
}

///|
test "ssa-nomerge fail-closed problem1 multi-result direct call br_on_non_null input" {
  // Boundary: multi-result calls are intentionally not rewritten yet because
  // the spill helper must preserve non-tested result lanes and know which lane
  // contains the tested reference. Keep the raw branch instead of guessing.
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let call_type_idx = @lib.TypeIdx::new(0U)
  let result_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([call_type_idx, test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(9),
            @lib.Instruction::ref_null(extern_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::type_idx(result_type_idx),
              @lib.Expr::new([
                @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(6),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  ssa_test_problem1_fail_closed_reference_branch_input(
    input, 1, "multi-result direct call br_on_non_null input", ssa_test_instrs_have_br_on_non_null,
  )
}

///|
test "ssa-nomerge fail-closed problem1 multi-result call_ref br_on_non_null input" {
  // Boundary: the current raw spill helper only admits exactly one reference
  // result. Multi-result `call_ref` must stay raw until lane preservation is
  // designed and tested.
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let call_type_idx = @lib.TypeIdx::new(0U)
  let result_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let helper_idx = @lib.FuncIdx::new(0U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([call_type_idx, test_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([helper_idx]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(9),
            @lib.Instruction::ref_null(extern_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::type_idx(result_type_idx),
              @lib.Expr::new([
                @lib.Instruction::ref_func(helper_idx),
                @lib.Instruction::call_ref(call_type_idx),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(6),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  ssa_test_problem1_fail_closed_reference_branch_input(
    input, 1, "multi-result call_ref br_on_non_null input", ssa_test_instrs_have_br_on_non_null,
  )
}

///|
test "ssa-nomerge fail-closed problem1 multi-result call_indirect br_on_non_null input" {
  // Boundary: multi-result `call_indirect` has the same lane-preservation risk
  // as direct/call_ref multi-result calls, plus a table-index operand.
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let call_type_idx = @lib.TypeIdx::new(0U)
  let result_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), externref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), externref]),
          ),
        ),
      ]),
    )
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            @lib.RefType::new(
              true,
              @lib.HeapType::abs(@lib.AbsHeapType::func()),
            ),
            @lib.Limits::i32(1U, Some(1U)),
          ),
          None,
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::type_idx(result_type_idx),
              @lib.Expr::new([
                @lib.Instruction::i32_const(0),
                @lib.Instruction::call_indirect(
                  call_type_idx,
                  @lib.TableIdx::new(0U),
                ),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(6),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  ssa_test_problem1_fail_closed_reference_branch_input(
    input, 0, "multi-result call_indirect br_on_non_null input", ssa_test_instrs_have_br_on_non_null,
  )
}

///|
test "ssa-nomerge fail-closed problem1 return-call br_on_non_null unreachable input" {
  // Boundary: `return_call` is terminal and produces no normal stack value for
  // the following branch. Validation accepts the suffix only through
  // unreachable-stack polymorphism; ssa-nomerge must not treat the tail call as
  // a spillable reference producer.
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let non_null_externref = @lib.ValType::ref_type(
    @lib.RefType::new(false, extern_heap),
  )
  let func_type_idx = @lib.TypeIdx::new(0U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([], [non_null_externref])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([func_type_idx, func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::unreachable_()]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(non_null_externref),
              @lib.Expr::new([
                @lib.Instruction::return_call(@lib.FuncIdx::new(0U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  ssa_test_problem1_fail_closed_reference_branch_input(
    input, 1, "return-call br_on_non_null unreachable input", ssa_test_instrs_have_br_on_non_null,
  )
}

///|
test "ssa-nomerge fail-closed problem1 return-call-ref br_on_non_null unreachable input" {
  // Boundary: `return_call_ref` consumes its function reference and terminates;
  // the later branch sees only unreachable-stack polymorphism, not a concrete
  // reference producer that ssa-nomerge can safely spill.
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let non_null_externref = @lib.ValType::ref_type(
    @lib.RefType::new(false, extern_heap),
  )
  let func_type_idx = @lib.TypeIdx::new(0U)
  let helper_idx = @lib.FuncIdx::new(0U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([], [non_null_externref])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([func_type_idx, func_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([helper_idx]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::unreachable_()]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(non_null_externref),
              @lib.Expr::new([
                @lib.Instruction::ref_func(helper_idx),
                @lib.Instruction::return_call_ref(func_type_idx),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  ssa_test_problem1_fail_closed_reference_branch_input(
    input, 1, "return-call-ref br_on_non_null unreachable input", ssa_test_instrs_have_br_on_non_null,
  )
}

///|
test "ssa-nomerge fail-closed problem1 return-call-indirect br_on_non_null unreachable input" {
  // Boundary: `return_call_indirect` consumes its table index and terminates;
  // do not reinterpret the unreachable suffix as a normal branch-input value.
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let non_null_externref = @lib.ValType::ref_type(
    @lib.RefType::new(false, extern_heap),
  )
  let func_type_idx = @lib.TypeIdx::new(0U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([], [non_null_externref])),
        ),
      ]),
    )
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            @lib.RefType::new(
              true,
              @lib.HeapType::abs(@lib.AbsHeapType::func()),
            ),
            @lib.Limits::i32(1U, Some(1U)),
          ),
          None,
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(non_null_externref),
              @lib.Expr::new([
                @lib.Instruction::i32_const(0),
                @lib.Instruction::return_call_indirect(
                  func_type_idx,
                  @lib.TableIdx::new(0U),
                ),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  ssa_test_problem1_fail_closed_reference_branch_input(
    input, 0, "return-call-indirect br_on_non_null unreachable input", ssa_test_instrs_have_br_on_non_null,
  )
}

///|
test "ssa-nomerge rewrites problem1 struct-new operands br_on_non_null input" {
  let struct_idx = @lib.TypeIdx::new(0U)
  let struct_heap = @lib.HeapType::new(struct_idx)
  let nullable_struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, struct_heap),
  )
  let field = @lib.FieldType::new(
    @lib.StorageType::val_type(@lib.ValType::i32()),
    @lib.Mut::var_(),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::struct_([field])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [nullable_struct_ref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(nullable_struct_ref),
              @lib.Expr::new([
                @lib.Instruction::i32_const(1),
                @lib.Instruction::struct_new(struct_idx),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(struct_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "struct-new operands br_on_non_null input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 0)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites problem1 array-new operands br_on_non_null input" {
  let externref = @lib.ValType::externref()
  let array_idx = @lib.TypeIdx::new(0U)
  let array_heap = @lib.HeapType::new(array_idx)
  let nullable_array_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, array_heap),
  )
  let field = @lib.FieldType::new(
    @lib.StorageType::val_type(externref),
    @lib.Mut::var_(),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::array(field))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([externref], [nullable_array_ref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(nullable_array_ref),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(1),
                @lib.Instruction::array_new(array_idx),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(array_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "array-new operands br_on_non_null input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 0)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites problem1 array-new-fixed operands br_on_non_null input" {
  // Narrow problem-1 implementation: `array.new_fixed` consumes its element
  // operands before producing the tested reference, so the rewrite spills only
  // the already-produced final array reference.
  let array_idx = @lib.TypeIdx::new(0U)
  let array_heap = @lib.HeapType::new(array_idx)
  let nullable_array_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, array_heap),
  )
  let field = @lib.FieldType::new(
    @lib.StorageType::val_type(@lib.ValType::i32()),
    @lib.Mut::var_(),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::array(field))),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([], [nullable_array_ref])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(nullable_array_ref),
              @lib.Expr::new([
                @lib.Instruction::i32_const(4),
                @lib.Instruction::i32_const(5),
                @lib.Instruction::array_new_fixed(array_idx, 2),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(array_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "array-new-fixed operands br_on_non_null input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 0)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites problem1 array-new-data operands br_on_non_null input" {
  // Narrow problem-1 implementation: `array.new_data` may trap while consuming
  // source/length and data-segment state, but only produces a reference after
  // those effects finish. The rewrite spills only that final produced array ref.
  let array_idx = @lib.TypeIdx::new(0U)
  let array_heap = @lib.HeapType::new(array_idx)
  let nullable_array_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, array_heap),
  )
  let field = @lib.FieldType::new(
    @lib.StorageType::val_type(@lib.ValType::i32()),
    @lib.Mut::var_(),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::array(field))),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([], [nullable_array_ref])),
        ),
      ]),
    )
    .with_data_sec(
      @lib.DataSec::new([@lib.Data::new(@lib.DataMode::passive(), b"")]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(nullable_array_ref),
              @lib.Expr::new([
                @lib.Instruction::i32_const(0),
                @lib.Instruction::i32_const(0),
                @lib.Instruction::array_new_data(
                  array_idx,
                  @lib.DataIdx::new(0U),
                ),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(array_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "array-new-data operands br_on_non_null input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 0)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites problem1 array-new-elem operands br_on_non_null input" {
  // Narrow problem-1 implementation: `array.new_elem` may trap while consuming
  // source/length and element-segment state, but only produces a reference after
  // those effects finish. The rewrite spills only that final produced array ref.
  let array_idx = @lib.TypeIdx::new(0U)
  let array_heap = @lib.HeapType::new(array_idx)
  let nullable_array_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, array_heap),
  )
  let funcref = @lib.ValType::funcref()
  let field = @lib.FieldType::new(
    @lib.StorageType::val_type(funcref),
    @lib.Mut::var_(),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::array(field))),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([], [nullable_array_ref])),
        ),
      ]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(@lib.ElemMode::passive(), @lib.ElemKind::funcs([])),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(nullable_array_ref),
              @lib.Expr::new([
                @lib.Instruction::i32_const(0),
                @lib.Instruction::i32_const(0),
                @lib.Instruction::array_new_elem(
                  array_idx,
                  @lib.ElemIdx::new(0U),
                ),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(array_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "array-new-elem operands br_on_non_null input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 0)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites problem1 call-then-ref-cast br_on_non_null input" {
  // Narrow problem-1 implementation: a final `ref.cast` after a single-ref
  // call can be spilled immediately after the cast. The recognizer admits only
  // the call/ref.cast/branch suffix; it still does not scan backward or
  // duplicate the call operands.
  let anyref = @lib.ValType::anyref()
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([], [anyref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([], [anyref])),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(1U)]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::ref_null(any_heap)]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(anyref),
              @lib.Expr::new([
                @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                @lib.Instruction::ref_cast(true, any_heap),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(any_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "call-then-ref-cast br_on_non_null input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites problem1 direct call operands then ref-cast br_on_non_null input" {
  // Coverage for the operandful version of the call/ref.cast/branch suffix:
  // the call operands are consumed before the final cast, and the rewrite only
  // spills the already-produced cast result.
  let anyref = @lib.ValType::anyref()
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let id_type_idx = @lib.TypeIdx::new(0U)
  let test_type_idx = @lib.TypeIdx::new(1U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), anyref], [anyref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([anyref], [anyref])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([id_type_idx, test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(1U))]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(anyref),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                @lib.Instruction::ref_cast(true, any_heap),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(any_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "direct call operands then ref-cast br_on_non_null input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites problem1 direct call operands then ref-cast br_on_null input" {
  // Br_on_null sibling for the operandful direct-call/ref.cast suffix: the
  // null-edge prefix payload is already on the stack, while the non-null
  // fallthrough keeps the cast result. The rewrite spills only the final cast.
  let anyref = @lib.ValType::anyref()
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let id_type_idx = @lib.TypeIdx::new(0U)
  let test_type_idx = @lib.TypeIdx::new(1U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), anyref], [anyref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([anyref], [anyref])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([id_type_idx, test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(1U))]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(anyref),
              @lib.Expr::new([
                @lib.Instruction::ref_null(any_heap),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                @lib.Instruction::ref_cast(true, any_heap),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(any_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "direct call operands then ref-cast br_on_null input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites problem1 call_ref operands then ref-cast br_on_non_null input" {
  // Coverage for the operandful call_ref/ref.cast/branch suffix admitted by the
  // narrow call-family recognizer: operands and the function reference are
  // consumed before the final cast, and the rewrite spills only that cast result.
  let anyref = @lib.ValType::anyref()
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let call_type_idx = @lib.TypeIdx::new(0U)
  let test_type_idx = @lib.TypeIdx::new(1U)
  let helper_idx = @lib.FuncIdx::new(0U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), anyref], [anyref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([anyref], [anyref])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([call_type_idx, test_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([helper_idx]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(1U))]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(anyref),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::ref_func(helper_idx),
                @lib.Instruction::call_ref(call_type_idx),
                @lib.Instruction::ref_cast(true, any_heap),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(any_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "call_ref operands then ref-cast br_on_non_null input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites problem1 call_indirect operands then ref-cast br_on_non_null input" {
  // Coverage for the operandful call_indirect/ref.cast/branch suffix admitted by
  // the narrow call-family recognizer. The table index and value operands are
  // already consumed by call_indirect before the final cast is spilled.
  let anyref = @lib.ValType::anyref()
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let call_type_idx = @lib.TypeIdx::new(0U)
  let test_type_idx = @lib.TypeIdx::new(1U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), anyref], [anyref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([anyref], [anyref])),
        ),
      ]),
    )
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            @lib.RefType::new(
              true,
              @lib.HeapType::abs(@lib.AbsHeapType::func()),
            ),
            @lib.Limits::i32(1U, Some(1U)),
          ),
          None,
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(anyref),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(0),
                @lib.Instruction::call_indirect(
                  call_type_idx,
                  @lib.TableIdx::new(0U),
                ),
                @lib.Instruction::ref_cast(true, any_heap),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(any_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "call_indirect operands then ref-cast br_on_non_null input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 0)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites problem1 call_ref operands then ref-cast br_on_null input" {
  // Br_on_null sibling for the operandful call_ref/ref.cast suffix: operands and
  // the function reference are consumed before the final cast, and the rewrite
  // spills only the final cast result while preserving the null-edge prefix.
  let anyref = @lib.ValType::anyref()
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let call_type_idx = @lib.TypeIdx::new(0U)
  let test_type_idx = @lib.TypeIdx::new(1U)
  let helper_idx = @lib.FuncIdx::new(0U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), anyref], [anyref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([anyref], [anyref])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([call_type_idx, test_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([helper_idx]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(1U))]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(anyref),
              @lib.Expr::new([
                @lib.Instruction::ref_null(any_heap),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::ref_func(helper_idx),
                @lib.Instruction::call_ref(call_type_idx),
                @lib.Instruction::ref_cast(true, any_heap),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(any_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "call_ref operands then ref-cast br_on_null input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites problem1 call_indirect operands then ref-cast br_on_null input" {
  // Br_on_null sibling for the operandful call_indirect/ref.cast suffix: the
  // table index and value operands are consumed by the indirect call before the
  // final cast is spilled, so no backward scan or operand duplication is needed.
  let anyref = @lib.ValType::anyref()
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let call_type_idx = @lib.TypeIdx::new(0U)
  let test_type_idx = @lib.TypeIdx::new(1U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), anyref], [anyref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([anyref], [anyref])),
        ),
      ]),
    )
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            @lib.RefType::new(
              true,
              @lib.HeapType::abs(@lib.AbsHeapType::func()),
            ),
            @lib.Limits::i32(1U, Some(1U)),
          ),
          None,
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ],
              None,
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(anyref),
              @lib.Expr::new([
                @lib.Instruction::ref_null(any_heap),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(0),
                @lib.Instruction::call_indirect(
                  call_type_idx,
                  @lib.TableIdx::new(0U),
                ),
                @lib.Instruction::ref_cast(true, any_heap),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(any_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "call_indirect operands then ref-cast br_on_null input",
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 0)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites non-current scalar typed loop br_table targets" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    loop $l (type $loop_t)
    #|      local.set 1
    #|      block $inner
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.get 0
    #|        br_table $l $l
    #|      end
    #|      local.get 1
    #|      drop
    #|    end
    #|    local.get 1))
    #|)
  ssa_test_expect_loop_param_br_table_proxy(source, 2)
}

///|
test "ssa-nomerge rewrites try_table scalar proxy br_if catch-relabeling" {
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    (block $h
    #|      i32.const 0
    #|      (loop $l (param i32)
    #|        local.set 1
    #|        (try_table (catch_all $h)
    #|          local.get 1
    #|          i32.const 1
    #|          i32.add
    #|          local.get 0
    #|          br_if $l
    #|          drop)))
    #|    local.get 1))
    #|)
  let optimized = ssa_test_pipeline_expected_mutation_valid(
    source, "try_table scalar proxy br_if catch-label relabeling",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_if_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites try_table scalar proxy br_table catch-relabeling" {
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    (block $h
    #|      i32.const 0
    #|      (loop $l (param i32)
    #|        local.set 1
    #|        (try_table (catch_all $h)
    #|          local.get 1
    #|          i32.const 1
    #|          i32.add
    #|          local.get 0
    #|          br_table $l $l
    #|          drop)))
    #|    local.get 1))
    #|)
  ssa_test_expect_loop_param_br_table_proxy(source, 2)
}

///|
test "ssa-nomerge rewrites try_table single-result fallthrough store model" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32 i32) (result i32)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    (block $h
    #|      i32.const 0
    #|      local.get 0
    #|      loop $l (type $loop_t)
    #|        local.set 2
    #|        local.set 1
    #|        try_table (result i32) (catch_all $h)
    #|          local.get 1
    #|          i32.const 1
    #|          i32.add
    #|          local.get 2
    #|          local.get 0
    #|          br_if $l
    #|          drop
    #|        end
    #|      end
    #|      return)
    #|    local.get 1))
    #|)
  let optimized = ssa_test_pipeline_expected_mutation_valid(
    source, "try_table single-result fallthrough store model",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites try_table single-result br_table fallthrough store model" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32 i32) (result i32)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    (block $h
    #|      i32.const 0
    #|      local.get 0
    #|      loop $l (type $loop_t)
    #|        local.set 2
    #|        local.set 1
    #|        try_table (result i32) (catch_all $h)
    #|          local.get 1
    #|          i32.const 1
    #|          i32.add
    #|          local.get 2
    #|          local.get 0
    #|          br_table $l $l
    #|          drop
    #|        end
    #|      end
    #|      return)
    #|    local.get 1))
    #|)
  ssa_test_expect_loop_param_store_model(source, 3)
}

///|
test "ssa-nomerge rewrites nested non-void loop self-backedges" {
  let source =
    #|(module
    #|  (type $outer_t (func (param i32)))
    #|  (type $inner_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    i32.const 0
    #|    loop $outer (type $outer_t)
    #|      local.set 1
    #|      i32.const 0
    #|      loop $inner (type $inner_t)
    #|        local.set 2
    #|        local.get 2
    #|        i32.const 1
    #|        i32.add
    #|        local.get 0
    #|        br_if $inner
    #|        drop
    #|      end
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      br $outer
    #|    end
    #|    local.get 1))
    #|)
  let (_, instrs) = try! ssa_test_expect_typed_loop_boundary_output(
    source, 3, "nested non-void loop self-backedge",
  )
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_if_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested non-void loop direct self-backedges" {
  let source =
    #|(module
    #|  (type $outer_t (func (param i32)))
    #|  (type $inner_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    i32.const 0
    #|    loop $outer (type $outer_t)
    #|      local.set 1
    #|      i32.const 0
    #|      loop $inner (type $inner_t)
    #|        local.set 2
    #|        local.get 2
    #|        i32.const 1
    #|        i32.add
    #|        br $inner
    #|      end
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      br $outer
    #|    end
    #|    local.get 1))
    #|)
  let (_, instrs) = try! ssa_test_expect_typed_loop_boundary_output(
    source, 3, "nested non-void loop direct self-backedge",
  )
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested other-label branches under typed loop params" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    loop $outer (type $loop_t)
    #|      local.set 1
    #|      block $other
    #|        br $other
    #|      end
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      br $outer
    #|    end
    #|    local.get 1))
    #|)
  let (_, instrs) = try! ssa_test_expect_typed_loop_boundary_output(
    source, 2, "nested other-label branch under typed loop param",
  )
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested other-label br_if branches under typed loop params" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    loop $outer (type $loop_t)
    #|      local.set 1
    #|      block $other
    #|        local.get 0
    #|        br_if $other
    #|      end
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      br $outer
    #|    end
    #|    local.get 1))
    #|)
  let (_, instrs) = try! ssa_test_expect_typed_loop_boundary_output(
    source, 2, "nested other-label br_if under typed loop param",
  )
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites copy-needing non-current scalar typed loop br_table targets" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    i32.const 0
    #|    loop $l (type $loop_t)
    #|      local.set 1
    #|      local.get 2
    #|      drop
    #|      local.get 1
    #|      i32.const 0
    #|      i32.eq
    #|      if
    #|        i32.const 7
    #|        local.set 2
    #|      else
    #|        i32.const 8
    #|        local.set 2
    #|      end
    #|      block $inner
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.get 0
    #|        br_table $l $l
    #|      end
    #|    end
    #|    local.get 2))
    #|)
  ssa_test_expect_loop_param_br_table_proxy(source, 3)
}

///|
test "ssa-nomerge rewrites non-current multi-param typed loop br_table targets" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32 i32)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    i32.const 0
    #|    local.get 0
    #|    loop $l (type $loop_t)
    #|      local.set 2
    #|      local.set 1
    #|      block $inner
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.get 2
    #|        local.get 0
    #|        br_table $l $l
    #|      end
    #|    end
    #|    local.get 1))
    #|)
  ssa_test_expect_loop_param_store_model(source, 3)
}

///|
test "ssa-nomerge rewrites non-current single-result typed loop br_table targets" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32 i32) (result i32)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    i32.const 0
    #|    local.get 0
    #|    loop $l (type $loop_t)
    #|      local.set 2
    #|      local.set 1
    #|      block $inner
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.get 2
    #|        local.get 0
    #|        br_table $l $l
    #|      end
    #|      local.get 1
    #|    end))
    #|)
  ssa_test_expect_loop_param_store_model(source, 3)
}

///|
test "ssa-nomerge rewrites non-current mixed-target scalar typed loop br_table targets" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    block $exit (result i32)
    #|      i32.const 0
    #|      loop $l (type $loop_t)
    #|        local.set 1
    #|        block $inner
    #|          local.get 1
    #|          i32.const 1
    #|          i32.add
    #|          local.get 0
    #|          br_table $l $exit
    #|        end
    #|        unreachable
    #|      end
    #|      unreachable
    #|    end))
    #|)
  let (_, instrs) = try! ssa_test_expect_typed_loop_boundary_output(
    source, 2, "non-current mixed-target scalar br_table",
  )
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
  assert_true(instrs.to_string().contains("i32.eq"), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites non-current mixed-target multi-param typed loop br_table targets" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32 i64)))
    #|  (type $exit_t (func (result i32 i64)))
    #|  (func (param i32) (result i32 i64) (local i32 i64)
    #|    block $exit (type $exit_t)
    #|      i32.const 0
    #|      i64.const 1
    #|      loop $l (type $loop_t)
    #|        local.set 2
    #|        local.set 1
    #|        block $inner
    #|          local.get 1
    #|          i32.const 1
    #|          i32.add
    #|          local.get 2
    #|          i64.const 1
    #|          i64.add
    #|          local.get 0
    #|          br_table $l $exit
    #|        end
    #|        unreachable
    #|      end
    #|      unreachable
    #|    end))
    #|)
  let (_, instrs) = try! ssa_test_expect_typed_loop_boundary_output(
    source, 3, "non-current mixed-target multi-param br_table",
  )
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
  assert_true(instrs.to_string().contains("i32.eq"), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites mixed scalar typed loop br_table and br_if backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    loop $l (type $loop_t)
    #|      local.set 1
    #|      local.get 1
    #|      i32.const 3
    #|      i32.lt_s
    #|      if
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.get 0
    #|        br_table $l $l
    #|      end
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.get 1
    #|      local.get 0
    #|      i32.lt_s
    #|      br_if $l
    #|      drop
    #|    end
    #|    local.get 1))
    #|)
  let (_, instrs) = try! ssa_test_expect_typed_loop_boundary_output(
    source, 2, "mixed scalar br_table and br_if",
  )
  assert_true(
    ssa_test_instrs_have_loop_param_br_table_proxy(instrs),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_if_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites concrete reference typed loop br_table backedges" {
  let struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([struct_ref], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([struct_ref, @lib.ValType::i32()], [struct_ref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([struct_ref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::br_table(
                  [@lib.LabelIdx::new(0U)],
                  @lib.LabelIdx::new(0U),
                ),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let (_, instrs) = try! ssa_test_expect_typed_loop_module_boundary_output(
    input, 2, "reference br_table",
  )
  assert_true(
    ssa_test_instrs_have_loop_param_br_table_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites mixed scalar typed loop br and br_if backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    loop $l (type $loop_t)
    #|      local.set 1
    #|      local.get 1
    #|      i32.const 3
    #|      i32.lt_s
    #|      if
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        br $l
    #|      end
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.get 1
    #|      local.get 0
    #|      i32.lt_s
    #|      br_if $l
    #|      drop
    #|    end
    #|    local.get 1))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_if_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites mixed reference typed loop br_if and br_on_null backedges" {
  let struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([struct_ref], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([struct_ref, @lib.ValType::i32()], [struct_ref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([struct_ref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected mixed reference typed-loop success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected output to validate, got \{@validate.validation_error_message(err)}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_if_proxy(instrs),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_instrs_have_loop_param_null_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites mixed reference typed loop br_if and br_on_non_null backedges" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "mixed reference typed loop br_if and br_on_non_null backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites mixed reference typed loop br_on_null and br_on_non_null backedges" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "mixed reference typed loop br_on_null and br_on_non_null backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites mixed reference typed loop br_if br_on_null and br_on_non_null backedges" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "mixed reference typed loop br_if br_on_null and br_on_non_null backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites mixed reference typed loop br br_on_null and br_on_non_null backedges" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "mixed reference typed loop br br_on_null and br_on_non_null backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites mixed reference typed loop br br_table br_on_null and br_on_non_null backedges" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::i32_const(0),
                    @lib.Instruction::br_table(
                      [@lib.LabelIdx::new(1U)],
                      @lib.LabelIdx::new(1U),
                    ),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "mixed reference typed loop br br_table br_on_null and br_on_non_null backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_table(instrs), msg=instrs.to_string())
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites mixed reference typed loop br br_if br_on_null and br_on_non_null backedges" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "mixed reference typed loop br br_if br_on_null and br_on_non_null backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_if(instrs), msg=instrs.to_string())
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites mixed reference typed loop br br_table and br_if backedges" {
  let externref = @lib.ValType::externref()
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::i32_const(0),
                    @lib.Instruction::br_table(
                      [@lib.LabelIdx::new(1U)],
                      @lib.LabelIdx::new(1U),
                    ),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "mixed reference typed loop br br_table and br_if backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_table(instrs), msg=instrs.to_string())
  assert_false(ssa_test_instrs_have_br_if(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites mixed reference typed loop br br_table br_if br_on_null and br_on_non_null backedges" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::i32_const(0),
                    @lib.Instruction::br_table(
                      [@lib.LabelIdx::new(1U)],
                      @lib.LabelIdx::new(1U),
                    ),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "mixed reference typed loop br br_table br_if br_on_null and br_on_non_null backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_table(instrs), msg=instrs.to_string())
  assert_false(ssa_test_instrs_have_br_if(instrs), msg=instrs.to_string())
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites mixed reference typed loop br_table and br_if backedges" {
  let externref = @lib.ValType::externref()
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::i32_const(0),
                    @lib.Instruction::br_table(
                      [@lib.LabelIdx::new(1U)],
                      @lib.LabelIdx::new(1U),
                    ),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "mixed reference typed loop br_table and br_if backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_false(ssa_test_instrs_have_br_table(instrs), msg=instrs.to_string())
  assert_false(ssa_test_instrs_have_br_if(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites mixed reference typed loop br_table and br_on_non_null backedges" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::i32_const(0),
                    @lib.Instruction::br_table(
                      [@lib.LabelIdx::new(1U)],
                      @lib.LabelIdx::new(1U),
                    ),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "mixed reference typed loop br_table and br_on_non_null backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites mixed reference typed loop br_table and br_on_null backedges" {
  let externref = @lib.ValType::externref()
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::i32_const(0),
                    @lib.Instruction::br_table(
                      [@lib.LabelIdx::new(1U)],
                      @lib.LabelIdx::new(1U),
                    ),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "mixed reference typed loop br_table and br_on_null backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites mixed reference typed loop br_table br_on_null and br_on_non_null backedges" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::i32_const(0),
                    @lib.Instruction::br_table(
                      [@lib.LabelIdx::new(1U)],
                      @lib.LabelIdx::new(1U),
                    ),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "mixed reference typed loop br_table br_on_null and br_on_non_null backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites mixed reference typed loop br_table br_if br_on_null and br_on_non_null backedges" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::i32_const(0),
                    @lib.Instruction::br_table(
                      [@lib.LabelIdx::new(1U)],
                      @lib.LabelIdx::new(1U),
                    ),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "mixed reference typed loop br_table br_if br_on_null and br_on_non_null backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_false(ssa_test_instrs_have_br_table(instrs), msg=instrs.to_string())
  assert_false(ssa_test_instrs_have_br_if(instrs), msg=instrs.to_string())
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested mixed reference typed loop br_if and br_on_null backedges" {
  let struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([struct_ref], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([struct_ref, @lib.ValType::i32()], [struct_ref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([struct_ref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
                    @lib.Instruction::drop(),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested mixed reference typed-loop success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected output to validate, got \{@validate.validation_error_message(err)}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_if_proxy(instrs),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_instrs_have_loop_param_null_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested mixed reference typed loop br_if and br_on_non_null backedges" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
                    @lib.Instruction::drop(),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "nested mixed reference typed loop br_if and br_on_non_null backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested mixed reference typed loop br_on_null and br_on_non_null backedges" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::br_on_null(@lib.LabelIdx::new(1U)),
                    @lib.Instruction::drop(),
                    @lib.Instruction::drop(),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "nested mixed reference typed loop br_on_null and br_on_non_null backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested mixed reference typed loop br_if br_on_null and br_on_non_null backedges" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
                    @lib.Instruction::drop(),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::br_on_null(@lib.LabelIdx::new(1U)),
                    @lib.Instruction::drop(),
                    @lib.Instruction::drop(),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "nested mixed reference typed loop br_if br_on_null and br_on_non_null backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested mixed reference typed loop br br_on_null and br_on_non_null backedges" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::br_on_null(@lib.LabelIdx::new(1U)),
                    @lib.Instruction::drop(),
                    @lib.Instruction::drop(),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "nested mixed reference typed loop br br_on_null and br_on_non_null backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested mixed reference typed loop br br_table br_on_null and br_on_non_null backedges" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::i32_const(0),
                    @lib.Instruction::br_table(
                      [@lib.LabelIdx::new(1U)],
                      @lib.LabelIdx::new(1U),
                    ),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::br_on_null(@lib.LabelIdx::new(1U)),
                    @lib.Instruction::drop(),
                    @lib.Instruction::drop(),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "nested mixed reference typed loop br br_table br_on_null and br_on_non_null backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_table(instrs), msg=instrs.to_string())
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested mixed reference typed loop br br_if br_on_null and br_on_non_null backedges" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
                    @lib.Instruction::drop(),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::br_on_null(@lib.LabelIdx::new(1U)),
                    @lib.Instruction::drop(),
                    @lib.Instruction::drop(),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "nested mixed reference typed loop br br_if br_on_null and br_on_non_null backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_if(instrs), msg=instrs.to_string())
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested mixed reference typed loop br_table and br_if backedges" {
  let externref = @lib.ValType::externref()
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::i32_const(0),
                    @lib.Instruction::br_table(
                      [@lib.LabelIdx::new(1U)],
                      @lib.LabelIdx::new(1U),
                    ),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
                    @lib.Instruction::drop(),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "nested mixed reference typed loop br_table and br_if backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_false(ssa_test_instrs_have_br_table(instrs), msg=instrs.to_string())
  assert_false(ssa_test_instrs_have_br_if(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites nested mixed reference typed loop br_table and br_on_non_null backedges" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::i32_const(0),
                    @lib.Instruction::br_table(
                      [@lib.LabelIdx::new(1U)],
                      @lib.LabelIdx::new(1U),
                    ),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "nested mixed reference typed loop br_table and br_on_non_null backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_false(ssa_test_instrs_have_br_table(instrs), msg=instrs.to_string())
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested mixed reference typed loop br_table and br_on_null backedges" {
  let externref = @lib.ValType::externref()
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::i32_const(0),
                    @lib.Instruction::br_table(
                      [@lib.LabelIdx::new(1U)],
                      @lib.LabelIdx::new(1U),
                    ),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "nested mixed reference typed loop br_table and br_on_null backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_false(ssa_test_instrs_have_br_table(instrs), msg=instrs.to_string())
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites nested mixed reference typed loop br_table br_on_null and br_on_non_null backedges" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::i32_const(0),
                    @lib.Instruction::br_table(
                      [@lib.LabelIdx::new(1U)],
                      @lib.LabelIdx::new(1U),
                    ),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "nested mixed reference typed loop br_table br_on_null and br_on_non_null backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_false(ssa_test_instrs_have_br_table(instrs), msg=instrs.to_string())
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested mixed reference typed loop br_table br_if br_on_null and br_on_non_null backedges" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::i32_const(0),
                    @lib.Instruction::br_table(
                      [@lib.LabelIdx::new(1U)],
                      @lib.LabelIdx::new(1U),
                    ),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
                    @lib.Instruction::drop(),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::br_on_null(@lib.LabelIdx::new(1U)),
                    @lib.Instruction::drop(),
                    @lib.Instruction::drop(),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "nested mixed reference typed loop br_table br_if br_on_null and br_on_non_null backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_false(ssa_test_instrs_have_br_table(instrs), msg=instrs.to_string())
  assert_false(ssa_test_instrs_have_br_if(instrs), msg=instrs.to_string())
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested mixed reference typed loop br br_table and br_if backedges" {
  let externref = @lib.ValType::externref()
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::i32_const(0),
                    @lib.Instruction::br_table(
                      [@lib.LabelIdx::new(1U)],
                      @lib.LabelIdx::new(1U),
                    ),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
                    @lib.Instruction::drop(),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "nested mixed reference typed loop br br_table and br_if backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_table(instrs), msg=instrs.to_string())
  assert_false(ssa_test_instrs_have_br_if(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites nested mixed reference typed loop br br_table br_if br_on_null and br_on_non_null backedges" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), externref], [externref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::i32_const(0),
                    @lib.Instruction::br_table(
                      [@lib.LabelIdx::new(1U)],
                      @lib.LabelIdx::new(1U),
                    ),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
                    @lib.Instruction::drop(),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::br_on_null(@lib.LabelIdx::new(1U)),
                    @lib.Instruction::drop(),
                    @lib.Instruction::drop(),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "nested mixed reference typed loop br br_table br_if br_on_null and br_on_non_null backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
  assert_false(ssa_test_instrs_have_br_table(instrs), msg=instrs.to_string())
  assert_false(ssa_test_instrs_have_br_if(instrs), msg=instrs.to_string())
  assert_false(ssa_test_instrs_have_br_on_null(instrs), msg=instrs.to_string())
  assert_false(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge does not mutate branch-bearing nested loops without loop-carried backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    loop $outer (type $loop_t)
    #|      local.set 1
    #|      loop $inner
    #|        br $inner
    #|      end
    #|    end
    #|    local.get 1))
    #|)
  // Boundary coverage: this fixture has branch-bearing nested control but no
  // backedge carrying a new value to the typed outer loop, so ssa-nomerge has
  // no required no-merge rewrite to perform.
  ssa_test_no_copy_typed_loop_param_pipeline_no_mutation(source)
}

///|
test "ssa-nomerge rewrites typed loop-param control functions" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32) (result i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    (local.get 0)
    #|    (loop $l (type $loop_t)
    #|      local.tee 1
    #|      local.get 0
    #|      i32.lt_s
    #|      if (result i32)
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        br $l
    #|      else
    #|        local.get 1
    #|      end)))
    #|)
  let optimized = ssa_test_pipeline_expected_mutation_valid(
    source, "typed loop-param control function",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites locals written before typed loop-param control" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32) (result i32)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    i32.const 5
    #|    local.set 1
    #|    local.get 0
    #|    (loop $l (type $loop_t)
    #|      local.tee 2
    #|      local.get 0
    #|      i32.lt_s
    #|      if (result i32)
    #|        local.get 2
    #|        i32.const 1
    #|        i32.add
    #|        br $l
    #|      else
    #|        local.get 1
    #|      end)))
    #|)
  let optimized = ssa_test_pipeline_expected_mutation_valid(
    source, "locals before typed loop-param control",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(text.contains("i32.const I32(5)"), msg=text)
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites typed loop-param backedge values separate from body locals" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32) (result i32)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    i32.const 100
    #|    local.set 1
    #|    local.get 0
    #|    (loop $l (type $loop_t)
    #|      local.tee 2
    #|      local.get 0
    #|      i32.lt_s
    #|      if (result i32)
    #|        local.get 2
    #|        i32.const 1
    #|        i32.add
    #|        br $l
    #|      else
    #|        local.get 1
    #|      end)))
    #|)
  let optimized = ssa_test_pipeline_expected_mutation_valid(
    source, "typed loop-param backedge/body-local separation",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(text.contains("i32.const I32(100)"), msg=text)
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites typed loop-param control on the hot path" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    loop $l (type $loop_t)
    #|      local.tee 1
    #|      local.get 0
    #|      i32.lt_s
    #|      if
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        br $l
    #|      end
    #|      local.get 1
    #|      drop
    #|    end
    #|    i32.const 1)
    #|)
  let optimized = ssa_test_pipeline_expected_mutation_valid(
    source, "typed loop-param control on the hot path",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites typed loop-carried induction values" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32) (result i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    (local.get 0)
    #|    (loop $grow (type $loop_t)
    #|      local.tee 1
    #|      local.get 0
    #|      i32.lt_s
    #|      if (result i32)
    #|        local.get 1
    #|        i32.const 1
    #|        i32.shl
    #|        br $grow
    #|      else
    #|        local.get 1
    #|      end)))
    #|)
  let optimized = ssa_test_pipeline_expected_mutation_valid(
    source, "typed loop-carried induction value",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(text.contains("i32.shl"), msg=text)
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
fn ssa_test_nested_cfg_hot_mutates(source : String) -> Unit raise {
  assert_true(
    ssa_test_hot_path_revision_changed(source),
    msg="expected hot-path rewrite for simple nested value block",
  )
}

///|
test "ssa-nomerge rewrites simple nested value-block local traffic" {
  let source =
    #|(module
    #|  (func (local i32)
    #|    (block (result i32)
    #|      i32.const 7
    #|      local.set 0
    #|      local.get 0)
    #|    drop
    #|    local.get 0
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge preserves reaching local from nested value-block local.set" {
  let source =
    #|(module
    #|  (func (local i32)
    #|    i32.const 3
    #|    local.set 0
    #|    (block (result i32)
    #|      i32.const 7
    #|      local.set 0
    #|      local.get 0)
    #|    drop
    #|    local.get 0
    #|    drop))
    #|)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nested value-block prior-write hot-path success, got \{err}",
      )
  }
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.const I32(3)"), msg=text)
  assert_true(text.contains("i32.const I32(7)"), msg=text)
  assert_true(text.contains("local.set"), msg=text)
  assert_false(text.contains("local.get (Local 0)"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
}

///|
test "ssa-nomerge handles simple nested value-block local.tee" {
  let source =
    #|(module
    #|  (func (local i32)
    #|    (block (result i32)
    #|      i32.const 7
    #|      local.tee 0)
    #|    drop
    #|    local.get 0
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested value-block tee hot-path success, got \{err}")
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
      ]),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ])
}

///|
test "ssa-nomerge preserves distinct locals around nested value-block traffic" {
  let source =
    #|(module
    #|  (func (local i32 i32)
    #|    i32.const 10
    #|    local.set 0
    #|    i32.const 20
    #|    local.set 1
    #|    (block (result i32)
    #|      local.get 0
    #|      i32.const 1
    #|      i32.add
    #|      local.set 0
    #|      local.get 0)
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 0
    #|    drop))
    #|)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested value-block two-local hot-path success, got \{err}")
  }
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.const I32(10)"), msg=text)
  assert_true(text.contains("i32.const I32(20)"), msg=text)
  assert_true(text.contains("i32.add"), msg=text)
  assert_false(text.contains("local.get (Local 0)"), msg=text)
  assert_false(text.contains("local.set (Local 0)"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
  assert_true(text.contains("local.set"), msg=text)
}

///|
test "ssa-nomerge rewrites simple nested result-if local traffic" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 7
    #|      local.set 1
    #|      local.get 1
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge preserves reaching local from nested result-if arms" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    i32.const 3
    #|    local.set 1
    #|
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 7
    #|      local.set 1
    #|      local.get 1
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|
    #|    local.get 1
    #|    drop))
    #|)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested result-if prior-write hot-path success, got \{err}")
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.const I32(3)"), msg=text)
  assert_true(text.contains("i32.const I32(7)"), msg=text)
  assert_true(text.contains("i32.const I32(9)"), msg=text)
  assert_true(text.contains("local.set"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
  assert_true(text.contains("if I32"), msg=text)
  assert_true(
    locals.length() > 2,
    msg="expected SSA temps beyond param and one body local, got \{locals}",
  )
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg="expected if-arm local writes to use SSA temps, got \{text}",
  )
}

///|
test "ssa-nomerge handles local.tee in simple nested result-if arm" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 7
    #|      local.tee 1
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested result-if tee hot-path success, got \{err}")
  }
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(
    text.contains("local.tee") || text.contains("local.set"),
    msg=text,
  )
  assert_true(text.contains("local.get"), msg=text)
}

///|
test "ssa-nomerge preserves distinct locals around nested result-if traffic" {
  let source =
    #|(module
    #|  (func (param i32) (local i32 i32)
    #|    i32.const 10
    #|    local.set 1
    #|    i32.const 20
    #|    local.set 2
    #|
    #|    local.get 0
    #|    if (result i32)
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.set 1
    #|      local.get 1
    #|    else
    #|      local.get 1
    #|      i32.const 2
    #|      i32.add
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|
    #|    local.get 2
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested result-if two-local hot-path success, got \{err}")
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.const I32(10)"), msg=text)
  assert_true(text.contains("i32.const I32(20)"), msg=text)
  assert_true(text.contains("i32.add"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
  assert_true(text.contains("local.set"), msg=text)
  assert_true(text.contains("if I32"), msg=text)
  assert_true(
    locals.length() > 3,
    msg="expected SSA temps beyond param and two body locals, got \{locals}",
  )
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 2U),
    msg="expected if-arm local writes to use SSA temps above local 2, got \{text}",
  )
}

///|
test "ssa-nomerge rewrites simple nested result-if with i64 result" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result i64)
    #|      i32.const 7
    #|      local.set 1
    #|      i64.const 70
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      i64.const 90
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge rewrites simple nested result-if with f32 result" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result f32)
    #|      i32.const 7
    #|      local.set 1
    #|      f32.const 7.0
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      f32.const 9.0
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge rewrites simple nested result-if with f64 result" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result f64)
    #|      i32.const 7
    #|      local.set 1
    #|      f64.const 7.0
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      f64.const 9.0
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge preserves i64 local traffic inside nested result-if" {
  let source =
    #|(module
    #|  (func (param i32) (local i64)
    #|    local.get 0
    #|    if (result i64)
    #|      i64.const 7
    #|      local.set 1
    #|      local.get 1
    #|    else
    #|      i64.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested i64 result-if hot-path success, got \{err}")
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i64.const"), msg=text)
  assert_true(text.contains("local.set"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
  assert_true(
    locals.length() > 2,
    msg="expected SSA temps beyond param and one body local, got \{locals}",
  )
}

///|
test "ssa-nomerge preserves f32 local traffic inside nested result-if" {
  let source =
    #|(module
    #|  (func (param i32) (local f32)
    #|    local.get 0
    #|    if (result f32)
    #|      f32.const 7.0
    #|      local.set 1
    #|      local.get 1
    #|    else
    #|      f32.const 9.0
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested f32 result-if hot-path success, got \{err}")
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("f32.const"), msg=text)
  assert_true(text.contains("local.set"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
  assert_true(
    locals.length() > 2,
    msg="expected SSA temps beyond param and one body local, got \{locals}",
  )
}

///|
test "ssa-nomerge preserves f64 local traffic inside nested result-if" {
  let source =
    #|(module
    #|  (func (param i32) (local f64)
    #|    local.get 0
    #|    if (result f64)
    #|      f64.const 7.0
    #|      local.set 1
    #|      local.get 1
    #|    else
    #|      f64.const 9.0
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested f64 result-if hot-path success, got \{err}")
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("f64.const"), msg=text)
  assert_true(text.contains("local.set"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
  assert_true(
    locals.length() > 2,
    msg="expected SSA temps beyond param and one body local, got \{locals}",
  )
}

///|
test "ssa-nomerge rewrites nested result-if with condition local.set" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    i32.const 1
    #|    local.set 1
    #|    local.get 1
    #|    if (result i32)
    #|      i32.const 7
    #|      local.set 1
    #|      local.get 1
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge rewrites nested result-if with condition local.tee" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    i32.const 1
    #|    local.tee 1
    #|    if (result i32)
    #|      i32.const 7
    #|      local.set 1
    #|      local.get 1
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nested result-if condition tee hot-path success, got \{err}",
      )
  }
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(
    text.contains("local.tee") || text.contains("local.set"),
    msg=text,
  )
  assert_true(text.contains("local.get"), msg=text)
}

///|
test "ssa-nomerge preserves condition-written local across nested result-if arms" {
  let source =
    #|(module
    #|  (func (param i32) (local i32 i32)
    #|    i32.const 1
    #|    local.set 1
    #|    local.get 1
    #|    if (result i32)
    #|      i32.const 7
    #|      local.set 2
    #|      local.get 2
    #|    else
    #|      i32.const 9
    #|      local.set 2
    #|      local.get 2
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2
    #|    drop))
    #|)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nested result-if condition-written local preservation, got \{err}",
      )
  }
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.const I32(1)"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
  assert_true(text.contains("local.set"), msg=text)
}

///|
test "ssa-nomerge lets nested result-if arms read condition-written locals" {
  let source =
    #|(module
    #|  (func (param i32) (local i32 i32)
    #|    i32.const 4
    #|    local.set 1
    #|    local.get 0
    #|    if (result i32)
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.set 2
    #|      local.get 2
    #|    else
    #|      local.get 1
    #|      i32.const 2
    #|      i32.add
    #|      local.set 2
    #|      local.get 2
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nested result-if arms reading condition-written local, got \{err}",
      )
  }
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.const I32(4)"), msg=text)
  assert_true(text.contains("i32.add"), msg=text)
}

///|
test "ssa-nomerge handles scalar result-if with condition local write" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    i32.const 1
    #|    local.tee 1
    #|    if (result f64)
    #|      i32.const 7
    #|      local.set 1
    #|      f64.const 7.0
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      f64.const 9.0
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge rewrites nested result-if with condition value-block local.set" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    (block (result i32)
    #|      i32.const 1
    #|      local.set 1
    #|      local.get 1)
    #|    if (result i32)
    #|      i32.const 7
    #|      local.set 1
    #|      local.get 1
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge rewrites nested result-if with condition value-block local.tee" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    (block (result i32)
    #|      i32.const 1
    #|      local.tee 1)
    #|    if (result i32)
    #|      i32.const 7
    #|      local.set 1
    #|      local.get 1
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge preserves condition-block-written local across nested result-if arms" {
  let source =
    #|(module
    #|  (func (param i32) (local i32 i32)
    #|    (block (result i32)
    #|      i32.const 1
    #|      local.set 1
    #|      local.get 1)
    #|    if (result i32)
    #|      i32.const 7
    #|      local.set 2
    #|      local.get 2
    #|    else
    #|      i32.const 9
    #|      local.set 2
    #|      local.get 2
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2
    #|    drop))
    #|)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected condition-block-written local preservation hot-path success, got \{err}",
      )
  }
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.const I32(1)"), msg=text)
  assert_true(text.contains("i32.const I32(7)"), msg=text)
  assert_true(text.contains("i32.const I32(9)"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
}

///|
test "ssa-nomerge lets nested result-if arms read condition-block-written locals" {
  let source =
    #|(module
    #|  (func (param i32) (local i32 i32)
    #|    (block (result i32)
    #|      i32.const 4
    #|      local.set 1
    #|      local.get 0)
    #|    if (result i32)
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.set 2
    #|      local.get 2
    #|    else
    #|      local.get 1
    #|      i32.const 2
    #|      i32.add
    #|      local.set 2
    #|      local.get 2
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2
    #|    drop))
    #|)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected arms-read-condition-block-local hot-path success, got \{err}",
      )
  }
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.const I32(4)"), msg=text)
  assert_true(text.contains("i32.add"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
}

///|
test "ssa-nomerge handles scalar result-if with condition value-block" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    (block (result i32)
    #|      i32.const 1
    #|      local.set 1
    #|      local.get 1)
    #|    if (result f64)
    #|      i32.const 7
    #|      local.set 1
    #|      f64.const 7.0
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      f64.const 9.0
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge does not mutate unsupported nested result-if with branch in condition block" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    block
    #|      (block (result i32)
    #|        i32.const 1
    #|        local.set 1
    #|        br 1
    #|        local.get 1)
    #|      if (result i32)
    #|        i32.const 7
    #|        local.set 1
    #|        local.get 1
    #|      else
    #|        i32.const 9
    #|        local.set 1
    #|        local.get 1
    #|      end
    #|      drop
    #|    end
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge does not mutate unsupported nested result-if with br_if in condition block" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    block
    #|      (block (result i32)
    #|        i32.const 1
    #|        local.set 1
    #|        i32.const 1
    #|        br_if 1
    #|        local.get 1)
    #|      if (result i32)
    #|        i32.const 7
    #|        local.set 1
    #|        local.get 1
    #|      else
    #|        i32.const 9
    #|        local.set 1
    #|        local.get 1
    #|      end
    #|      drop
    #|    end
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge does not mutate unsupported nested result-if with nested loop in condition block" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    (block (result i32)
    #|      loop
    #|        i32.const 1
    #|        local.set 1
    #|      end
    #|      local.get 1)
    #|    if (result i32)
    #|      i32.const 7
    #|      local.set 1
    #|      local.get 1
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge rejects unsupported nested result-if with non-i32 condition block result" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let condition_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i64()),
    [@ir.hot_build_const_i64(func, @lib.I64(1))],
  )
  let result_if = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    condition_block,
    [
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(7)),
      ),
      @ir.hot_build_local_get(func, 1),
    ],
    else_body=Some([
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(9)),
      ),
      @ir.hot_build_local_get(func, 1),
    ]),
  )
  let drop = @ir.hot_build_drop(func, result_if)
  @ir.hot_root_append(func, drop)
  @ir.hot_root_append(
    func,
    @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1)),
  )
  assert_false(
    @ir.ssa_simple_drop_result_if_allowed(func, drop, 0, result_if),
    msg="non-i32 condition block is unsupported boundary",
  )
  ssa_test_hot_func_ssa_nomerge_revision_unchanged(func)
}

///|
test "ssa-nomerge rejects unsupported nested result-if with branch in condition" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let outer = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let condition_br = @ir.hot_build_br(
    func,
    @ir.hot_control_node_label(func, outer),
  )
  let result_if = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    condition_br,
    [
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(7)),
      ),
      @ir.hot_build_local_get(func, 1),
    ],
    else_body=Some([
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(9)),
      ),
      @ir.hot_build_local_get(func, 1),
    ]),
  )
  let drop = @ir.hot_build_drop(func, result_if)
  @ir.hot_root_append(func, drop)
  @ir.hot_root_append(
    func,
    @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1)),
  )
  assert_false(
    @ir.ssa_simple_drop_result_if_allowed(func, drop, 0, result_if),
    msg="branch in condition is unsupported boundary",
  )
  ssa_test_hot_func_ssa_nomerge_revision_unchanged(func)
}

///|
test "ssa-nomerge rewrites drop operand result-if with simple condition value-block" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    (if (result i32)
    #|      (block (result i32)
    #|        (i32.const 1)
    #|        (local.set 1)
    #|        (local.get 1))
    #|      (then
    #|        (i32.const 7)
    #|        (local.set 1)
    #|        (local.get 1))
    #|      (else
    #|        (i32.const 9)
    #|        (local.set 1)
    #|        (local.get 1)))
    #|    drop
    #|    (local.get 1)
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge rewrites nested result-if with value-block arms" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      (block (result i32)
    #|        i32.const 7
    #|        local.set 1
    #|        local.get 1)
    #|    else
    #|      (block (result i32)
    #|        i32.const 9
    #|        local.set 1
    #|        local.get 1)
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge rewrites nested result-if with one value-block arm" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      (block (result i32)
    #|        i32.const 7
    #|        local.set 1
    #|        local.get 1)
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge handles local.tee inside result-if arm value-block" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      (block (result i32)
    #|        i32.const 7
    #|        local.tee 1)
    #|    else
    #|      (block (result i32)
    #|        i32.const 9
    #|        local.set 1
    #|        local.get 1)
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge lets arm value-blocks read condition-written locals" {
  let source =
    #|(module
    #|  (func (param i32) (local i32 i32)
    #|    i32.const 4
    #|    local.set 1
    #|    local.get 0
    #|    if (result i32)
    #|      (block (result i32)
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.set 2
    #|        local.get 2)
    #|    else
    #|      (block (result i32)
    #|        local.get 1
    #|        i32.const 2
    #|        i32.add
    #|        local.set 2
    #|        local.get 2)
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge handles scalar result-if with scalar arm value-blocks" {
  let source =
    #|(module
    #|  (func (param i32) (local f64)
    #|    local.get 0
    #|    if (result f64)
    #|      (block (result f64)
    #|        f64.const 7.0
    #|        local.set 1
    #|        local.get 1)
    #|    else
    #|      (block (result f64)
    #|        f64.const 9.0
    #|        local.set 1
    #|        local.get 1)
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge handles condition value-block plus arm value-blocks" {
  let source =
    #|(module
    #|  (func (param i32) (local i32 i32)
    #|    (block (result i32)
    #|      i32.const 1
    #|      local.set 1
    #|      local.get 1)
    #|    if (result i32)
    #|      (block (result i32)
    #|        i32.const 7
    #|        local.set 2
    #|        local.get 2)
    #|    else
    #|      (block (result i32)
    #|        i32.const 9
    #|        local.set 2
    #|        local.get 2)
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge does not mutate unsupported nested result-if with branch in arm value-block" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      (block (result i32)
    #|        i32.const 7
    #|        local.set 1
    #|        block
    #|          br 0
    #|        end
    #|        local.get 1)
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge does not mutate unsupported nested result-if with br_if in arm value-block" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      (block (result i32)
    #|        i32.const 7
    #|        local.set 1
    #|        block
    #|          i32.const 0
    #|          br_if 0
    #|        end
    #|        local.get 1)
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge does not mutate unsupported nested result-if with nested if in arm value-block" {
  let source =
    #|(module
    #|  (func (param i32 i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      (block (result i32)
    #|        local.get 1
    #|        if
    #|          i32.const 7
    #|          local.set 2
    #|        end
    #|        local.get 2)
    #|    else
    #|      i32.const 9
    #|      local.set 2
    #|      local.get 2
    #|    end
    #|    drop
    #|    local.get 2
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge does not mutate unsupported nested result-if with nested loop in arm value-block" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      (block (result i32)
    #|        loop
    #|          i32.const 7
    #|          local.set 1
    #|        end
    #|        local.get 1)
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge rewrites nested result-if with void prefixes before arm value-blocks" {
  let source =
    #|(module
    #|  (func (param i32) (local i32 i32)
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 1
    #|      local.set 1
    #|      (block (result i32)
    #|        i32.const 7
    #|        local.set 2
    #|        local.get 2)
    #|    else
    #|      i32.const 2
    #|      local.set 1
    #|      (block (result i32)
    #|        i32.const 9
    #|        local.set 2
    #|        local.get 2)
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge rewrites nested result-if with one mixed arm value-block" {
  let source =
    #|(module
    #|  (func (param i32) (local i32 i32)
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 1
    #|      local.set 1
    #|      (block (result i32)
    #|        i32.const 7
    #|        local.set 2
    #|        local.get 2)
    #|    else
    #|      (block (result i32)
    #|        i32.const 9
    #|        local.set 2
    #|        local.get 2)
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge lets arm value-blocks read prefix-written locals" {
  let source =
    #|(module
    #|  (func (param i32) (local i32 i32)
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 4
    #|      local.set 1
    #|      (block (result i32)
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.set 2
    #|        local.get 2)
    #|    else
    #|      i32.const 5
    #|      local.set 1
    #|      (block (result i32)
    #|        local.get 1
    #|        i32.const 2
    #|        i32.add
    #|        local.set 2
    #|        local.get 2)
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge handles condition value-block plus mixed arm roots" {
  let source =
    #|(module
    #|  (func (param i32) (local i32 i32 i32)
    #|    (block (result i32)
    #|      i32.const 1
    #|      local.set 1
    #|      local.get 1)
    #|    if (result i32)
    #|      i32.const 4
    #|      local.set 2
    #|      (block (result i32)
    #|        i32.const 7
    #|        local.set 3
    #|        local.get 3)
    #|    else
    #|      i32.const 5
    #|      local.set 2
    #|      (block (result i32)
    #|        i32.const 9
    #|        local.set 3
    #|        local.get 3)
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2
    #|    drop
    #|    local.get 3
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge handles scalar result-if with mixed scalar arm value-blocks" {
  let source =
    #|(module
    #|  (func (param i32) (local i32 f64)
    #|    local.get 0
    #|    if (result f64)
    #|      i32.const 1
    #|      local.set 1
    #|      (block (result f64)
    #|        f64.const 7.0
    #|        local.set 2
    #|        local.get 2)
    #|    else
    #|      i32.const 2
    #|      local.set 1
    #|      (block (result f64)
    #|        f64.const 9.0
    #|        local.set 2
    #|        local.get 2)
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge handles drop prefixes before arm value-blocks" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 123
    #|      drop
    #|      (block (result i32)
    #|        i32.const 7
    #|        local.set 1
    #|        local.get 1)
    #|    else
    #|      i32.const 456
    #|      drop
    #|      (block (result i32)
    #|        i32.const 9
    #|        local.set 1
    #|        local.get 1)
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge rejects mixed arm with value-producing prefix root" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let then_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(7)),
      ),
      @ir.hot_build_local_get(func, 1),
    ],
  )
  let result_if = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @ir.hot_build_local_get(func, 0),
    [@ir.hot_build_const_i32(func, @lib.I32(111)), then_block],
    else_body=Some([
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(9)),
      ),
      @ir.hot_build_local_get(func, 1),
    ]),
  )
  let drop = @ir.hot_build_drop(func, result_if)
  @ir.hot_root_append(func, drop)
  @ir.hot_root_append(
    func,
    @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1)),
  )
  assert_false(
    @ir.ssa_simple_drop_result_if_allowed(func, drop, 0, result_if),
    msg="value-producing mixed-arm prefix is unsupported boundary",
  )
  ssa_test_hot_func_ssa_nomerge_revision_unchanged(func)
}

///|
test "ssa-nomerge rejects mixed arm with roots after final value-block" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let then_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(7)),
      ),
      @ir.hot_build_local_get(func, 1),
    ],
  )
  let result_if = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @ir.hot_build_local_get(func, 0),
    [
      then_block,
      @ir.hot_build_drop(func, @ir.hot_build_const_i32(func, @lib.I32(222))),
    ],
    else_body=Some([
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(9)),
      ),
      @ir.hot_build_local_get(func, 1),
    ]),
  )
  let drop = @ir.hot_build_drop(func, result_if)
  @ir.hot_root_append(func, drop)
  @ir.hot_root_append(
    func,
    @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1)),
  )
  assert_false(
    @ir.ssa_simple_drop_result_if_allowed(func, drop, 0, result_if),
    msg="roots after final mixed-arm value block are unsupported boundary",
  )
  ssa_test_hot_func_ssa_nomerge_revision_unchanged(func)
}

///|
test "ssa-nomerge rejects mixed arm with two value-block roots" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let first_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let second_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(8)),
      ),
      @ir.hot_build_local_get(func, 1),
    ],
  )
  let result_if = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @ir.hot_build_local_get(func, 0),
    [first_block, second_block],
    else_body=Some([
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(9)),
      ),
      @ir.hot_build_local_get(func, 1),
    ]),
  )
  let drop = @ir.hot_build_drop(func, result_if)
  @ir.hot_root_append(func, drop)
  @ir.hot_root_append(
    func,
    @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1)),
  )
  assert_false(
    @ir.ssa_simple_drop_result_if_allowed(func, drop, 0, result_if),
    msg="two mixed-arm value blocks are unsupported boundary",
  )
  ssa_test_hot_func_ssa_nomerge_revision_unchanged(func)
}

///|
test "ssa-nomerge rejects unsupported mixed arm with branch in final value-block" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let prefix = @ir.hot_build_local_set(
    func,
    1,
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  )
  let outer_block = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let then_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [
      @ir.hot_build_br(func, @ir.hot_control_node_label(func, outer_block)),
      @ir.hot_build_local_get(func, 1),
    ],
  )
  let result_if = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @ir.hot_build_local_get(func, 0),
    [prefix, then_block],
    else_body=Some([
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(9)),
      ),
      @ir.hot_build_local_get(func, 1),
    ]),
  )
  let drop = @ir.hot_build_drop(func, result_if)
  @ir.hot_region_replace_body(
    func,
    @ir.hot_region_body_ref(func, outer_block),
    [drop],
  )
  @ir.hot_root_append(func, outer_block)
  @ir.hot_root_append(
    func,
    @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1)),
  )
  assert_false(
    @ir.ssa_simple_drop_result_if_allowed(func, drop, 0, result_if),
    msg="branch inside mixed-arm final value block is unsupported boundary",
  )
  ssa_test_hot_func_ssa_nomerge_revision_unchanged(func)
}

///|
test "ssa-nomerge rejects mixed arm value-block result type mismatch" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let prefix = @ir.hot_build_local_set(
    func,
    1,
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  )
  let then_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i64()),
    [
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i64(func, @lib.I64(7)),
      ),
      @ir.hot_build_local_get(func, 1),
    ],
  )
  let else_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(9)),
      ),
      @ir.hot_build_local_get(func, 1),
    ],
  )
  let result_if = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @ir.hot_build_local_get(func, 0),
    [prefix, then_block],
    else_body=Some([else_block]),
  )
  let drop = @ir.hot_build_drop(func, result_if)
  @ir.hot_root_append(func, drop)
  @ir.hot_root_append(
    func,
    @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1)),
  )
  assert_false(
    @ir.ssa_simple_drop_result_if_allowed(func, drop, 0, result_if),
    msg="mixed arm value-block result type mismatch is unsupported boundary",
  )
  ssa_test_hot_func_ssa_nomerge_revision_unchanged(func)
}

///|
test "ssa-nomerge does not mutate unsupported mixed arm with nested block inside final value-block" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 1
    #|      local.set 1
    #|      (block (result i32)
    #|        (block
    #|          i32.const 7
    #|          local.set 1)
    #|        local.get 1)
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge rejects arm value-block result type mismatch" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let then_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i64()),
    [
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i64(func, @lib.I64(7)),
      ),
      @ir.hot_build_local_get(func, 1),
    ],
  )
  let else_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(9)),
      ),
      @ir.hot_build_local_get(func, 1),
    ],
  )
  let result_if = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @ir.hot_build_local_get(func, 0),
    [then_block],
    else_body=Some([else_block]),
  )
  let drop = @ir.hot_build_drop(func, result_if)
  @ir.hot_root_append(func, drop)
  @ir.hot_root_append(
    func,
    @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1)),
  )
  assert_false(
    @ir.ssa_simple_drop_result_if_allowed(func, drop, 0, result_if),
    msg="arm value-block result type mismatch is unsupported boundary",
  )
  ssa_test_hot_func_ssa_nomerge_revision_unchanged(func)
}

///|
test "ssa-nomerge does not mutate unsupported nested result-if with nested if in condition" {
  let source =
    #|(module
    #|  (func (param i32 i32) (local i32)
    #|    (if (result i32)
    #|      (if (result i32) (local.get 0)
    #|        (then (i32.const 1))
    #|        (else (i32.const 0)))
    #|      (then
    #|        (i32.const 7)
    #|        (local.set 1)
    #|        (local.get 1))
    #|      (else
    #|        (i32.const 9)
    #|        (local.set 1)
    #|        (local.get 1)))
    #|    drop
    #|    (local.get 1)
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge rewrites nested result-if when one arm does not overwrite condition local" {
  // Phi placement records the condition-written reaching def for the non-writing arm
  // and the arm overwrite for the other predecessor; CFG-backed rename visits the
  // condition in the shared predecessor block before both arms.
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    i32.const 1
    #|    local.tee 1
    #|    if (result i32)
    #|      local.get 1
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected one-arm-non-overwrite condition-write hot-path success, got \{err}",
      )
  }
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.const I32(1)"), msg=text)
  assert_true(text.contains("i32.const I32(9)"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
}

///|
test "ssa-nomerge does not mutate unsupported nested result-if with multi-value result" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result i32 i32)
    #|      i32.const 7
    #|      local.set 1
    #|      local.get 1
    #|      i32.const 1
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|      i32.const 2
    #|    end
    #|    drop
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge does not mutate unsupported nested result-if with br" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    (block $outer
    #|      local.get 0
    #|      if (result i32)
    #|        i32.const 7
    #|        local.set 1
    #|        br $outer
    #|        local.get 1
    #|      else
    #|        i32.const 9
    #|        local.set 1
    #|        local.get 1
    #|      end
    #|      drop)
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge does not mutate unsupported nested result-if with br_if" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    (block $outer
    #|      local.get 0
    #|      if (result i32)
    #|        i32.const 7
    #|        local.set 1
    #|        i32.const 1
    #|        br_if $outer
    #|        local.get 1
    #|      else
    #|        i32.const 9
    #|        local.set 1
    #|        local.get 1
    #|      end
    #|      drop)
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge does not mutate unsupported nested result-if with nested loop" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      loop
    #|        i32.const 7
    #|        local.set 1
    #|      end
    #|      local.get 1
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge does not mutate unsupported nested result-if with nested if" {
  let source =
    #|(module
    #|  (func (param i32 i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      local.get 1
    #|      if
    #|        i32.const 7
    #|        local.set 2
    #|      end
    #|      local.get 2
    #|    else
    #|      i32.const 9
    #|      local.set 2
    #|      local.get 2
    #|    end
    #|    drop
    #|    local.get 2
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge does not mutate unsupported nested result-if under value block" {
  // The result-typed `if` arms are region roots, but the enclosing value block
  // sits in `drop`'s operand slot and is therefore nested CFG-sensitive control.
  let source =
    #|(module
    #|  (func (param i32) (result i32)
    #|    (local i32)
    #|    (block (result i32)
    #|      local.get 0
    #|      if (result i32)
    #|        i32.const 10
    #|        local.set 1
    #|        local.get 1
    #|      else
    #|        i32.const 20
    #|        local.set 1
    #|        local.get 1
    #|      end)
    #|    drop
    #|    local.get 1))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
  ssa_test_nested_cfg_hot_local_traffic_preserved(source)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("local.set"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
}

///|
test "ssa-nomerge does not mutate unsupported nested value block with br" {
  // `br` is a terminator; when it appears inside a value block nested under
  // `drop`, the guard treats the subtree as nested CFG-sensitive local traffic.
  // An outer `$outer` label gives the inner `br` a valid exit target.
  let source =
    #|(module
    #|  (func (param i32) (result i32)
    #|    (local i32)
    #|    (block $outer
    #|      (block (result i32)
    #|        i32.const 7
    #|        local.set 1
    #|        br $outer
    #|        local.get 1)
    #|      drop)
    #|    local.get 1))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("local.set"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
}

///|
test "ssa-nomerge does not mutate unsupported nested value block with br_if" {
  // `br_if` is branch-shaped but not a HOT terminator flag; this fixture still
  // triggers the guard via the nested value block under `drop` with local traffic.
  // The outer `$outer` label keeps the inner `br_if` stack-valid.
  let source =
    #|(module
    #|  (func (param i32) (result i32)
    #|    (local i32)
    #|    (block $outer
    #|      (block (result i32)
    #|        i32.const 7
    #|        local.set 1
    #|        i32.const 1
    #|        br_if $outer
    #|        local.get 1)
    #|      drop)
    #|    local.get 1))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge does not mutate unsupported nested loop under value block" {
  let source =
    #|(module
    #|  (func (local i32)
    #|    (block (result i32)
    #|      loop
    #|        i32.const 7
    #|        local.set 0
    #|      end
    #|      local.get 0)
    #|    drop
    #|    local.get 0
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("local.set"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
}

///|
fn ssa_nomerge_test_run_trace_locked_raw_exit(
  source : String,
  reason : String,
  context : String,
) -> @lib.Module raise {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected \{context} ssa-nomerge success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=\{reason}")
    }),
    msg="expected \{context} to use \{reason}; trace:\n\{trace.join("\n")}",
  )
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg="expected \{context} to avoid lifted HOT fallback mutation; trace:\n\{trace.join("\n")}",
  )
  assert_false(
    trace.any(fn(line) { line.contains("skip-invalid-lower") }),
    msg="expected \{context} to avoid invalid lowered fallback; trace:\n\{trace.join("\n")}",
  )
  optimized
}

///|
test "ssa-nomerge keeps straight-line local traffic on the canonical slot" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 5 local.set 0 local.get 0))",
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(5)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
}

///|
test "ssa-nomerge LocalGraph straight-line set keeps live parameter overwrite canonical" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) i32.const 5 local.set 0 local.get 0))",
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected live param overwrite ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::empty())
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(5)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=straight-line-local-writes-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge LocalGraph straight-line set freshens overwritten body writes" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 1 local.set 0 i32.const 2 local.set 0 local.get 0))",
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected overwritten local.set ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
  ])
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=straight-line-local-writes-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge LocalGraph straight-line tee freshens and preserves stack result" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 1 local.tee 0 drop i32.const 2 local.tee 0 i32.const 10 i32.add drop local.get 0))",
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected overwritten local.tee ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i32_const(@lib.I32(10)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
  ])
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=straight-line-local-writes-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge LocalGraph straight-line tee keeps folded effect operand single" {
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func $make (result i32) (i32.const 11))
    #|  (func (result i32) (local i32)
    #|    (drop (i32.add (local.tee 0 (call $make)) (i32.const 10)))
    #|    (drop (local.tee 0 (i32.const 2)))
    #|    (local.get 0)))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected folded local.tee ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(10)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
  ])
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=straight-line-local-writes-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge artifact value-if carrier does not read unwritten fresh locals" {
  // Reduced standalone module for the current debug-WASI first diff after
  // `[SSANM-009b1]`, `defined=215 abs=242` (`run_hot_pipeline::flush_hot_passes`).
  // The legacy structured raw path may first allocate fresh branch-carrier
  // aliases, then the value-if scratch post-pass must not freshen those already
  // fresh aliases again while leaving the outer block's carrier read on the old
  // fresh local.
  let source =
    #|(module
    #|  (import "env" "incref" (func $moonbit.incref (param i32)))
    #|  (import "env" "decref" (func $moonbit.decref (param i32)))
    #|  (import "env" "free" (func $moonbit.free (param i32)))
    #|  (import "env" "malloc" (func $moonbit.gc.malloc (param i32) (result i32)))
    #|  (import "env" "get_tag" (func $moonbit.get_tag (param i32) (result i32)))
    #|  (import "env" "length" (func $_M0MPC15array5Array6lengthGRP37jtenner9starshine3lib5TableE (param i32) (result i32)))
    #|  (import "env" "apply_stack" (func $_M0FP37jtenner9starshine6passes43run__hot__pipeline__apply__hot__pass__stack (param i32 i32 i32) (result i32)))
    #|  (import "env" "apply" (func $_M0FP37jtenner9starshine6passes36run__hot__pipeline__apply__hot__pass (param i32 i32 i32) (result i32)))
    #|  (import "env" "clear" (func $_M0MPC15array5Array5clearGRP37jtenner9starshine6passes20HotPassRegistryEntryE (param i32) (result i32)))
    #|  (memory 1)
    #|  (func $f (export "f") (param $_M0L6_2aenvS156477 i32) (result i32)
    #|    (local $_M0L7optionsS98468 i32) (local $_M0L7currentS98475 i32) (local $_M0L20pending__hot__passesS98477 i32) (local $_M0L3errS98480 i32) (local $_M0L4nextS98482 i32) (local $_M0L7_2abindS98483 i32) (local $_M0L5_2aOkS98484 i32) (local $_M0L7_2anextS98485 i32) (local $_M0L6_2aErrS98486 i32) (local $_M0L6_2aerrS98487 i32) (local $_M0L13next__currentS98488 i32) (local $_M0L7_2abindS98489 i32) (local $_M0L2__S98490 i32) (local $_M0L7pendingS98491 i32) (local $_M0L3errS98493 i32) (local $_M0L4nextS98495 i32) (local $_M0L7_2abindS98496 i32) (local $_M0L5_2aOkS98497 i32) (local $_M0L7_2anextS98498 i32) (local $_M0L6_2aErrS98499 i32) (local $_M0L6_2aerrS98500 i32) (local $_M0L6_2atmpS156478 i32) (local $_M0L6_2atmpS156479 i32) (local $_M0L6_2atmpS156480 i32) (local $_M0L6_2atmpS156481 i32) (local $_M0L3valS156482 i32) (local $_M0L6_2atmpS156483 i32) (local $_M0L3valS156484 i32) (local $_M0L6_2atmpS156485 i32) (local $_M0L3bufS156486 i32) (local $_M0L3valS156487 i32) (local $_M0L6_2atmpS156488 i32) (local $_M0L6_2aoldS158396 i32) (local $_M0L8_2afieldS158397 i32) (local $_M0L8_2afieldS158398 i32) (local $_M0L8_2afieldS158400 i32) (local $_M0L6_2aoldS158401 i32) (local $_M0L8_2afieldS158402 i32) (local $_M0L8_2afieldS158403 i32) (local $_M0L8_2afieldS158408 i32) (local $_M0L6_2acntS177135 i32) (local $_M0L11_2anew__cntS177136 i32) (local $_M0L6_2acntS177137 i32) (local $_M0L11_2anew__cntS177138 i32) (local $_M0L6_2acntS177139 i32) (local $_M0L11_2anew__cntS177140 i32) (local $_M0L6_2acntS177141 i32) (local $_M0L11_2anew__cntS177142 i32) (local $_M0L6_2acntS177143 i32) (local $_M0L11_2anew__cntS177144 i32) (local $_M0L6_2acntS177145 i32) (local $_M0L11_2anew__cntS177146 i32) (local $_M0L3ptrS199880 i32) (local $_M0L6_2atagS199883 i32) (local $_M0L3ptrS199884 i32) (local $_M0L6_2atagS199887 i32) (local $_M0L3ptrS199888 i32) (local $_M0L3ptrS199889 i32) (local $_M0L3ptrS199890 i32)
    #|    local.get $_M0L6_2aenvS156477
    #|    i32.load offset=16 align=1
    #|    local.set $_M0L7optionsS98468
    #|    local.get $_M0L6_2aenvS156477
    #|    i32.load offset=12 align=1
    #|    local.set $_M0L7currentS98475
    #|    local.get $_M0L6_2aenvS156477
    #|    i32.load offset=8 align=1
    #|    local.set $_M0L8_2afieldS158408
    #|    local.get $_M0L6_2aenvS156477
    #|    i32.load align=1
    #|    local.tee $_M0L6_2acntS177135
    #|    i32.const 1
    #|    i32.gt_s
    #|    if ;; label = @1
    #|      local.get $_M0L6_2acntS177135
    #|      i32.const 1
    #|      i32.sub
    #|      local.set $_M0L11_2anew__cntS177136
    #|      local.get $_M0L6_2aenvS156477
    #|      local.get $_M0L11_2anew__cntS177136
    #|      i32.store align=1
    #|      local.get $_M0L7optionsS98468
    #|      call $moonbit.incref
    #|      local.get $_M0L7currentS98475
    #|      call $moonbit.incref
    #|      local.get $_M0L8_2afieldS158408
    #|      call $moonbit.incref
    #|    else
    #|      local.get $_M0L6_2acntS177135
    #|      i32.const 1
    #|      i32.eq
    #|      if ;; label = @2
    #|        local.get $_M0L6_2aenvS156477
    #|        call $moonbit.free
    #|      end
    #|    end
    #|    local.get $_M0L8_2afieldS158408
    #|    local.set $_M0L20pending__hot__passesS98477
    #|    local.get $_M0L20pending__hot__passesS98477
    #|    call $moonbit.incref
    #|    local.get $_M0L20pending__hot__passesS98477
    #|    call $_M0MPC15array5Array6lengthGRP37jtenner9starshine3lib5TableE
    #|    local.tee $_M0L6_2atmpS156478
    #|    i32.const 0
    #|    i32.eq
    #|    if ;; label = @1
    #|      local.get $_M0L20pending__hot__passesS98477
    #|      call $moonbit.decref
    #|      local.get $_M0L7currentS98475
    #|      call $moonbit.decref
    #|      local.get $_M0L7optionsS98468
    #|      call $moonbit.decref
    #|      i32.const 0
    #|      local.set $_M0L6_2atmpS156479
    #|      i32.const 4
    #|      call $moonbit.gc.malloc
    #|      local.tee $_M0L3ptrS199890
    #|      i32.const 1572865
    #|      i32.store offset=4 align=1
    #|      local.get $_M0L3ptrS199890
    #|      local.get $_M0L6_2atmpS156479
    #|      i32.store offset=8 align=1
    #|      local.get $_M0L3ptrS199890
    #|      return
    #|    end
    #|    i32.const 0
    #|    drop
    #|    local.get $_M0L7optionsS98468
    #|    i32.load offset=28 align=1
    #|    if (result i32) ;; label = @1
    #|      local.get $_M0L20pending__hot__passesS98477
    #|      call $moonbit.incref
    #|      local.get $_M0L20pending__hot__passesS98477
    #|      call $_M0MPC15array5Array6lengthGRP37jtenner9starshine3lib5TableE
    #|      local.tee $_M0L6_2atmpS156481
    #|      i32.const 1
    #|      i32.gt_s
    #|    else
    #|      i32.const 0
    #|    end
    #|    if (result i32) ;; label = @1
    #|      block (result i32) ;; label = @2
    #|        block ;; label = @3
    #|          block (result i32) ;; label = @4
    #|            block ;; label = @5
    #|              local.get $_M0L7currentS98475
    #|              i32.load offset=8 align=1
    #|              local.tee $_M0L3valS156482
    #|              call $moonbit.incref
    #|              local.get $_M0L20pending__hot__passesS98477
    #|              call $moonbit.incref
    #|              local.get $_M0L3valS156482
    #|              local.get $_M0L20pending__hot__passesS98477
    #|              local.get $_M0L7optionsS98468
    #|              call $_M0FP37jtenner9starshine6passes43run__hot__pipeline__apply__hot__pass__stack
    #|              local.tee $_M0L7_2abindS98483
    #|              call $moonbit.get_tag
    #|              local.tee $_M0L6_2atagS199883
    #|              i32.const 1
    #|              i32.eq
    #|              if (result i32) ;; label = @6
    #|                local.get $_M0L7_2abindS98483
    #|                local.tee $_M0L5_2aOkS98484
    #|                i32.load offset=8 align=1
    #|                local.set $_M0L8_2afieldS158397
    #|                local.get $_M0L5_2aOkS98484
    #|                i32.load align=1
    #|                local.tee $_M0L6_2acntS177137
    #|                i32.const 1
    #|                i32.gt_s
    #|                if ;; label = @7
    #|                  local.get $_M0L6_2acntS177137
    #|                  i32.const 1
    #|                  i32.sub
    #|                  local.set $_M0L11_2anew__cntS177138
    #|                  local.get $_M0L5_2aOkS98484
    #|                  local.get $_M0L11_2anew__cntS177138
    #|                  i32.store align=1
    #|                  local.get $_M0L8_2afieldS158397
    #|                  call $moonbit.incref
    #|                else
    #|                  local.get $_M0L6_2acntS177137
    #|                  i32.const 1
    #|                  i32.eq
    #|                  if ;; label = @8
    #|                    local.get $_M0L5_2aOkS98484
    #|                    call $moonbit.free
    #|                  end
    #|                end
    #|                local.get $_M0L8_2afieldS158397
    #|                local.tee $_M0L7_2anextS98485
    #|                local.set $_M0L4nextS98482
    #|                br 1 (;@5;)
    #|              else
    #|                local.get $_M0L20pending__hot__passesS98477
    #|                call $moonbit.decref
    #|                local.get $_M0L7currentS98475
    #|                call $moonbit.decref
    #|                local.get $_M0L7_2abindS98483
    #|                local.tee $_M0L6_2aErrS98486
    #|                i32.load offset=8 align=1
    #|                local.set $_M0L8_2afieldS158398
    #|                local.get $_M0L6_2aErrS98486
    #|                i32.load align=1
    #|                local.tee $_M0L6_2acntS177139
    #|                i32.const 1
    #|                i32.gt_s
    #|                if ;; label = @7
    #|                  local.get $_M0L6_2acntS177139
    #|                  i32.const 1
    #|                  i32.sub
    #|                  local.set $_M0L11_2anew__cntS177140
    #|                  local.get $_M0L6_2aErrS98486
    #|                  local.get $_M0L11_2anew__cntS177140
    #|                  i32.store align=1
    #|                  local.get $_M0L8_2afieldS158398
    #|                  call $moonbit.incref
    #|                else
    #|                  local.get $_M0L6_2acntS177139
    #|                  i32.const 1
    #|                  i32.eq
    #|                  if ;; label = @8
    #|                    local.get $_M0L6_2aErrS98486
    #|                    call $moonbit.free
    #|                  end
    #|                end
    #|                local.get $_M0L8_2afieldS158398
    #|                local.tee $_M0L6_2aerrS98487
    #|                local.set $_M0L3errS98480
    #|                br 3 (;@3;)
    #|              end
    #|              br 1 (;@4;)
    #|            end
    #|            local.get $_M0L4nextS98482
    #|          end
    #|          br 1 (;@2;)
    #|        end
    #|        i32.const 4
    #|        call $moonbit.gc.malloc
    #|        local.tee $_M0L3ptrS199884
    #|        i32.const 1048832
    #|        i32.store offset=4 align=1
    #|        local.get $_M0L3ptrS199884
    #|        local.get $_M0L3errS98480
    #|        i32.store offset=8 align=1
    #|        local.get $_M0L3ptrS199884
    #|        return
    #|      end
    #|    else
    #|      local.get $_M0L7currentS98475
    #|      i32.load offset=8 align=1
    #|      local.tee $_M0L3valS156487
    #|      call $moonbit.incref
    #|      i32.const 4
    #|      call $moonbit.gc.malloc
    #|      local.tee $_M0L3ptrS199889
    #|      i32.const 1048832
    #|      i32.store offset=4 align=1
    #|      local.get $_M0L3ptrS199889
    #|      local.get $_M0L3valS156487
    #|      i32.store offset=8 align=1
    #|      local.get $_M0L3ptrS199889
    #|      local.set $_M0L13next__currentS98488
    #|      local.get $_M0L20pending__hot__passesS98477
    #|      i32.load offset=8 align=1
    #|      local.set $_M0L7_2abindS98489
    #|      i32.const 0
    #|      loop (param i32) ;; label = @2
    #|        local.tee $_M0L2__S98490
    #|        local.get $_M0L7_2abindS98489
    #|        i32.lt_s
    #|        if ;; label = @3
    #|          local.get $_M0L20pending__hot__passesS98477
    #|          i32.load offset=12 align=1
    #|          local.tee $_M0L3bufS156486
    #|          local.get $_M0L2__S98490
    #|          i32.const 2
    #|          i32.shl
    #|          i32.add
    #|          i32.load offset=8 align=1
    #|          local.set $_M0L7pendingS98491
    #|          block (result i32) ;; label = @4
    #|            block ;; label = @5
    #|              block (result i32) ;; label = @6
    #|                block ;; label = @7
    #|                  local.get $_M0L13next__currentS98488
    #|                  i32.load offset=8 align=1
    #|                  local.tee $_M0L3valS156484
    #|                  call $moonbit.incref
    #|                  local.get $_M0L7pendingS98491
    #|                  call $moonbit.incref
    #|                  local.get $_M0L7optionsS98468
    #|                  call $moonbit.incref
    #|                  local.get $_M0L3valS156484
    #|                  local.get $_M0L7pendingS98491
    #|                  local.get $_M0L7optionsS98468
    #|                  call $_M0FP37jtenner9starshine6passes36run__hot__pipeline__apply__hot__pass
    #|                  local.tee $_M0L7_2abindS98496
    #|                  call $moonbit.get_tag
    #|                  local.tee $_M0L6_2atagS199887
    #|                  i32.const 1
    #|                  i32.eq
    #|                  if (result i32) ;; label = @8
    #|                    local.get $_M0L7_2abindS98496
    #|                    local.tee $_M0L5_2aOkS98497
    #|                    i32.load offset=8 align=1
    #|                    local.set $_M0L8_2afieldS158402
    #|                    local.get $_M0L5_2aOkS98497
    #|                    i32.load align=1
    #|                    local.tee $_M0L6_2acntS177141
    #|                    i32.const 1
    #|                    i32.gt_s
    #|                    if ;; label = @9
    #|                      local.get $_M0L6_2acntS177141
    #|                      i32.const 1
    #|                      i32.sub
    #|                      local.set $_M0L11_2anew__cntS177142
    #|                      local.get $_M0L5_2aOkS98497
    #|                      local.get $_M0L11_2anew__cntS177142
    #|                      i32.store align=1
    #|                      local.get $_M0L8_2afieldS158402
    #|                      call $moonbit.incref
    #|                    else
    #|                      local.get $_M0L6_2acntS177141
    #|                      i32.const 1
    #|                      i32.eq
    #|                      if ;; label = @10
    #|                        local.get $_M0L5_2aOkS98497
    #|                        call $moonbit.free
    #|                      end
    #|                    end
    #|                    local.get $_M0L8_2afieldS158402
    #|                    local.tee $_M0L7_2anextS98498
    #|                    local.set $_M0L4nextS98495
    #|                    br 1 (;@7;)
    #|                  else
    #|                    local.get $_M0L13next__currentS98488
    #|                    call $moonbit.decref
    #|                    local.get $_M0L20pending__hot__passesS98477
    #|                    call $moonbit.decref
    #|                    local.get $_M0L7currentS98475
    #|                    call $moonbit.decref
    #|                    local.get $_M0L7optionsS98468
    #|                    call $moonbit.decref
    #|                    local.get $_M0L7_2abindS98496
    #|                    local.tee $_M0L6_2aErrS98499
    #|                    i32.load offset=8 align=1
    #|                    local.set $_M0L8_2afieldS158403
    #|                    local.get $_M0L6_2aErrS98499
    #|                    i32.load align=1
    #|                    local.tee $_M0L6_2acntS177143
    #|                    i32.const 1
    #|                    i32.gt_s
    #|                    if ;; label = @9
    #|                      local.get $_M0L6_2acntS177143
    #|                      i32.const 1
    #|                      i32.sub
    #|                      local.set $_M0L11_2anew__cntS177144
    #|                      local.get $_M0L6_2aErrS98499
    #|                      local.get $_M0L11_2anew__cntS177144
    #|                      i32.store align=1
    #|                      local.get $_M0L8_2afieldS158403
    #|                      call $moonbit.incref
    #|                    else
    #|                      local.get $_M0L6_2acntS177143
    #|                      i32.const 1
    #|                      i32.eq
    #|                      if ;; label = @10
    #|                        local.get $_M0L6_2aErrS98499
    #|                        call $moonbit.free
    #|                      end
    #|                    end
    #|                    local.get $_M0L8_2afieldS158403
    #|                    local.tee $_M0L6_2aerrS98500
    #|                    local.set $_M0L3errS98493
    #|                    br 3 (;@5;)
    #|                  end
    #|                  br 1 (;@6;)
    #|                end
    #|                local.get $_M0L4nextS98495
    #|              end
    #|              br 1 (;@4;)
    #|            end
    #|            i32.const 4
    #|            call $moonbit.gc.malloc
    #|            local.tee $_M0L3ptrS199888
    #|            i32.const 1048832
    #|            i32.store offset=4 align=1
    #|            local.get $_M0L3ptrS199888
    #|            local.get $_M0L3errS98493
    #|            i32.store offset=8 align=1
    #|            local.get $_M0L3ptrS199888
    #|            return
    #|          end
    #|          local.set $_M0L6_2atmpS156483
    #|          local.get $_M0L13next__currentS98488
    #|          i32.load offset=8 align=1
    #|          local.tee $_M0L6_2aoldS158401
    #|          call $moonbit.decref
    #|          local.get $_M0L13next__currentS98488
    #|          local.get $_M0L6_2atmpS156483
    #|          i32.store offset=8 align=1
    #|          i32.const 0
    #|          drop
    #|          local.get $_M0L2__S98490
    #|          i32.const 1
    #|          i32.add
    #|          local.tee $_M0L6_2atmpS156485
    #|          br 1 (;@2;)
    #|        else
    #|          local.get $_M0L7optionsS98468
    #|          call $moonbit.decref
    #|        end
    #|      end
    #|      i32.const 0
    #|      drop
    #|      local.get $_M0L13next__currentS98488
    #|      i32.load offset=8 align=1
    #|      local.set $_M0L8_2afieldS158400
    #|      local.get $_M0L13next__currentS98488
    #|      i32.load align=1
    #|      local.tee $_M0L6_2acntS177145
    #|      i32.const 1
    #|      i32.gt_s
    #|      if ;; label = @2
    #|        local.get $_M0L6_2acntS177145
    #|        i32.const 1
    #|        i32.sub
    #|        local.set $_M0L11_2anew__cntS177146
    #|        local.get $_M0L13next__currentS98488
    #|        local.get $_M0L11_2anew__cntS177146
    #|        i32.store align=1
    #|        local.get $_M0L8_2afieldS158400
    #|        call $moonbit.incref
    #|      else
    #|        local.get $_M0L6_2acntS177145
    #|        i32.const 1
    #|        i32.eq
    #|        if ;; label = @3
    #|          local.get $_M0L13next__currentS98488
    #|          call $moonbit.free
    #|        end
    #|      end
    #|      local.get $_M0L8_2afieldS158400
    #|    end
    #|    local.set $_M0L6_2atmpS156480
    #|    local.get $_M0L7currentS98475
    #|    i32.load offset=8 align=1
    #|    local.tee $_M0L6_2aoldS158396
    #|    call $moonbit.decref
    #|    local.get $_M0L7currentS98475
    #|    local.get $_M0L6_2atmpS156480
    #|    i32.store offset=8 align=1
    #|    local.get $_M0L7currentS98475
    #|    call $moonbit.decref
    #|    i32.const 0
    #|    drop
    #|    local.get $_M0L20pending__hot__passesS98477
    #|    call $_M0MPC15array5Array5clearGRP37jtenner9starshine6passes20HotPassRegistryEntryE
    #|    drop
    #|    i32.const 0
    #|    local.set $_M0L6_2atmpS156488
    #|    i32.const 4
    #|    call $moonbit.gc.malloc
    #|    local.tee $_M0L3ptrS199880
    #|    i32.const 1572865
    #|    i32.store offset=4 align=1
    #|    local.get $_M0L3ptrS199880
    #|    local.get $_M0L6_2atmpS156488
    #|    i32.store offset=8 align=1
    #|    local.get $_M0L3ptrS199880
    #|  )
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  let writes = ssa_test_local_write_indices(instrs)
  let gets = ssa_nomerge_test_local_get_indices(instrs)
  let original_local_count = 1U + 59U
  for get_idx in gets {
    if get_idx >= original_local_count && !writes.contains(get_idx) {
      fail(
        "ssa-nomerge read appended local \{get_idx} without any write; locals=\{locals} instrs=\{instrs}",
      )
    }
  }
}

///|
test "ssa-nomerge keeps loop-carried plain br boundary canonical" {
  // Reduced from the post-`[SSANM-009b3]` debug-WASI first diff,
  // `defined=501 abs=528` (`dae_rewrite_dropped_result_calls_instrs`).
  // The legacy structured helper used to freshen the loop-carried index and
  // synthesize branch/else copies around a plain `br`. Until this branch-target
  // family has a Binaryen-shaped LocalGraph rewrite, keep it fail-closed so the
  // canonical loop carrier is not materialized through helper locals.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func $sink (param i32))
    #|  (func $f (export "f") (param $p i32) (result i32)
    #|    (local $carrier i32) (local $i i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|    i32.const 10
    #|    local.set $carrier
    #|    i32.const 0
    #|    local.set $i
    #|    block
    #|      loop
    #|        local.get $i
    #|        i32.const 1
    #|        i32.lt_s
    #|        if
    #|          local.get $carrier
    #|          call $sink
    #|          local.get $p
    #|          if
    #|            i32.const 20
    #|            local.set $carrier
    #|            br 1
    #|          end
    #|          local.get $carrier
    #|          call $sink
    #|          local.get $i
    #|          i32.const 1
    #|          i32.add
    #|          local.set $i
    #|          br 0
    #|        end
    #|      end
    #|    end
    #|    local.get $carrier))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected loop-carried plain br boundary success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected loop-carried plain br boundary output to validate, got \{@validate.validation_error_message(err)}",
      )
  }
  ssa_test_assert_ssa_nomerge_raw_reason(
    trace, "loop-carried-plain-br-boundary-noop",
  )
  ssa_test_assert_no_planned_structured_trace_reason(trace)
  ssa_test_assert_no_ssa_nomerge_mutation_trace(trace)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() <= 131, msg=locals.to_string())
  let writes = ssa_test_local_write_indices(instrs)
  assert_true(writes.any(fn(idx) { idx == 2U }), msg=instrs.to_string())
  assert_false(writes.any(fn(idx) { idx > 2U }), msg=instrs.to_string())
}

///|
test "ssa-nomerge keeps medium loop-carried plain br scanner boundary canonical" {
  // Reduced from the post-`[SSANM-009b4]` debug-WASI first diff,
  // `defined=538 abs=565` (`dae_scan_local_use_ignoring_instrs`). The
  // source-lowered scanner has fewer than the earlier huge boundary locals, but
  // the same parity-risky shape: a loop-carried local is read around nested
  // plain-`br` exits while the legacy structured helper would synthesize helper
  // locals and branch/else copies. Keep this medium scanner boundary fail-closed
  // until a Binaryen-shaped branch-target LocalGraph rewrite owns it.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func $sink (param i32))
    #|  (func $f (export "f") (param $p i32) (result i32)
    #|    (local $carrier i32) (local $i i32) (local $scratch i32)
    #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|    i32.const 10
    #|    local.set $carrier
    #|    i32.const 0
    #|    local.set $i
    #|    block
    #|      loop
    #|        local.get $carrier
    #|        local.set $scratch
    #|        local.get $i
    #|        i32.const 1
    #|        i32.lt_s
    #|        if
    #|          local.get $carrier
    #|          call $sink
    #|          local.get $p
    #|          if
    #|            i32.const 20
    #|            local.set $scratch
    #|            local.get $scratch
    #|            call $sink
    #|            br 1
    #|          end
    #|          local.get $carrier
    #|          call $sink
    #|          local.get $i
    #|          i32.const 1
    #|          i32.add
    #|          local.set $i
    #|          br 0
    #|        end
    #|      end
    #|    end
    #|    local.get $carrier))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected medium loop-carried plain br boundary success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected medium loop-carried plain br boundary output to validate, got \{@validate.validation_error_message(err)}",
      )
  }
  ssa_test_assert_ssa_nomerge_raw_reason(
    trace, "loop-carried-plain-br-boundary-noop",
  )
  ssa_test_assert_no_planned_structured_trace_reason(trace)
  ssa_test_assert_no_ssa_nomerge_mutation_trace(trace)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() <= 67, msg=locals.to_string())
  let writes = ssa_test_local_write_indices(instrs)
  assert_false(writes.any(fn(idx) { idx > 3U }), msg=instrs.to_string())
}

///|
test "ssa-nomerge keeps result loop plain br carrier boundary canonical" {
  // Reduced from the post-`[SSANM-009b5]` debug-WASI first diff,
  // `defined=651 abs=678` (`dae_instr_is_unreachable_root`). Binaryen leaves
  // the source-lowered result-typed loop carrier on the canonical scratch local,
  // while the legacy structured helper rewrote it through a void-loop/outer-block
  // shape and appended helper locals. Keep this result-loop/plain-`br` boundary
  // fail-closed until a Binaryen-shaped rewrite owns loop-result carriers.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (type $loop_t (func (param i32) (result i32)))
    #|  (memory 1)
    #|  (func $moonbit.incref (param i32))
    #|  (func $moonbit.decref (param i32))
    #|  (func $moonbit.free (param i32))
    #|  (func $_M0MPC15array5Array6lengthGRP37jtenner9starshine3cli19CliOptimizationFlagE (param i32) (result i32) (i32.const 0))
    #|  (func $_M0MPC15array5Array2atGRP37jtenner9starshine3lib7TypeIdxE (param i32 i32) (result i32) (local.get 0))
    #|  (func $f (export "f") (param $_M0L5instrS85935 i32) (result i32)
    #|    (local $_M0L5instrS85928 i32) (local $_M0L4bodyS85930 i32) (local $_M0L8_2aBlockS85932 i32) (local $_M0L4_2axS85933 i32) (local $_M0L7_2abodyS85934 i32) (local $_M0L6_2atmpS148086 i32) (local $_M0L6_2atmpS148087 i32) (local $_M0L8_2afieldS160546 i32) (local $_M0L6_2acntS179205 i32) (local $_M0L8_2afieldS179206 i32) (local $_M0L11_2anew__cntS179207 i32) (local $_M0L6_2atagS202657 i32)
    #|    local.get $_M0L5instrS85935
    #|    loop (type $loop_t) ;; label = @1
    #|      local.set $_M0L5instrS85928
    #|      block (result i32) ;; label = @2
    #|        block ;; label = @3
    #|          local.get $_M0L5instrS85928
    #|          i32.load offset=8 align=1
    #|          local.tee $_M0L6_2atagS202657
    #|          i32.const 0
    #|          i32.eq
    #|          if (result i32) ;; label = @4
    #|            i32.const 1
    #|          else
    #|            local.get $_M0L6_2atagS202657
    #|            i32.const 2
    #|            i32.eq
    #|            if (result i32) ;; label = @5
    #|              local.get $_M0L5instrS85928
    #|              local.tee $_M0L8_2aBlockS85932
    #|              i32.load offset=16 align=1
    #|              local.set $_M0L8_2afieldS160546
    #|              local.get $_M0L8_2aBlockS85932
    #|              i32.load align=1
    #|              local.tee $_M0L6_2acntS179205
    #|              i32.const 1
    #|              i32.gt_s
    #|              if ;; label = @6
    #|                local.get $_M0L6_2acntS179205
    #|                i32.const 1
    #|                i32.sub
    #|                local.set $_M0L11_2anew__cntS179207
    #|                local.get $_M0L8_2aBlockS85932
    #|                local.get $_M0L11_2anew__cntS179207
    #|                i32.store align=1
    #|                local.get $_M0L8_2afieldS160546
    #|                call $moonbit.incref
    #|              else
    #|                local.get $_M0L6_2acntS179205
    #|                i32.const 1
    #|                i32.eq
    #|                if ;; label = @7
    #|                  local.get $_M0L8_2aBlockS85932
    #|                  i32.load offset=12 align=1
    #|                  local.tee $_M0L8_2afieldS179206
    #|                  call $moonbit.decref
    #|                  local.get $_M0L8_2aBlockS85932
    #|                  call $moonbit.free
    #|                end
    #|              end
    #|              local.get $_M0L8_2afieldS160546
    #|              local.tee $_M0L4_2axS85933
    #|              local.tee $_M0L7_2abodyS85934
    #|              local.set $_M0L4bodyS85930
    #|              br 2 (;@3;)
    #|            else
    #|              local.get $_M0L5instrS85928
    #|              call $moonbit.decref
    #|              i32.const 0
    #|            end
    #|          end
    #|          br 1 (;@2;)
    #|        end
    #|        local.get $_M0L4bodyS85930
    #|        call $moonbit.incref
    #|        local.get $_M0L4bodyS85930
    #|        call $_M0MPC15array5Array6lengthGRP37jtenner9starshine3cli19CliOptimizationFlagE
    #|        local.tee $_M0L6_2atmpS148087
    #|        i32.const 1
    #|        i32.eq
    #|        if (result i32) ;; label = @3
    #|          local.get $_M0L4bodyS85930
    #|          i32.const 0
    #|          call $_M0MPC15array5Array2atGRP37jtenner9starshine3lib7TypeIdxE
    #|          local.tee $_M0L6_2atmpS148086
    #|          br 2 (;@1;)
    #|        else
    #|          local.get $_M0L4bodyS85930
    #|          call $moonbit.decref
    #|          i32.const 0
    #|        end
    #|      end
    #|    end
    #|  )
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected result loop plain br carrier boundary success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected result loop plain br carrier boundary output to validate, got \{@validate.validation_error_message(err)}",
      )
  }
  ssa_test_assert_ssa_nomerge_raw_reason(
    trace, "result-loop-plain-br-boundary-noop",
  )
  ssa_test_assert_no_planned_structured_trace_reason(trace)
  ssa_test_assert_no_ssa_nomerge_mutation_trace(trace)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 5)
  assert_true(locals.length() <= 13, msg=locals.to_string())
  let writes = ssa_test_local_write_indices(instrs)
  assert_false(writes.any(fn(idx) { idx >= 13U }), msg=instrs.to_string())
}

///|
test "ssa-nomerge keeps typed loop-param local.set plain br boundary canonical" {
  // Reduced from the post-`[SSANM-009b6]` debug-WASI first diff,
  // `defined=987 abs=1014` (`gr_collect_func_global_sets`). Binaryen leaves
  // this source-lowered single-param/no-result typed loop carrier canonical: the
  // loop param is stored into a body local at the top, and the recursive backedge
  // uses a plain `br`. The legacy scalar proxy helper could add a loop scratch,
  // then later local freshening could strand the backedge value on a different
  // local. Keep this plain-`br` boundary fail-closed; `local.tee`, `br_if`,
  // `br_table`, and ref/cast typed-loop helpers remain covered by their
  // dedicated typed-control tests.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func $sink (param i32))
    #|  (func $id (param i32) (result i32) (local.get 0))
    #|  (func $f (export "f") (param $p i32) (result i32)
    #|    (local $carrier i32) (local $scratch i32) (local $x i32)
    #|    i32.const 3
    #|    loop (type $loop_t)
    #|      local.set $carrier
    #|      local.get $carrier
    #|      local.set $scratch
    #|      local.get $scratch
    #|      i32.const 0
    #|      i32.ge_s
    #|      if
    #|        local.get $scratch
    #|        call $sink
    #|        local.get $scratch
    #|        i32.const 1
    #|        i32.sub
    #|        br 1
    #|      end
    #|      i32.const 0
    #|      drop
    #|    end
    #|    local.get $p
    #|    call $id
    #|    local.set $x
    #|    local.get $x
    #|    call $sink
    #|    local.get $carrier))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected typed loop-param plain br boundary success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected typed loop-param plain br boundary output to validate, got \{@validate.validation_error_message(err)}",
      )
  }
  ssa_test_assert_ssa_nomerge_raw_reason(
    trace, "loop-param-plain-br-boundary-noop",
  )
  ssa_test_assert_no_planned_structured_trace_reason(trace)
  ssa_test_assert_no_ssa_nomerge_mutation_trace(trace)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 2)
  assert_true(locals.length() <= 3, msg=locals.to_string())
  let writes = ssa_test_local_write_indices(instrs)
  assert_false(writes.any(fn(idx) { idx >= 4U }), msg=instrs.to_string())
}

///|
test "ssa-nomerge keeps nested typed loop-param plain br boundary canonical" {
  // Reduced from the post-`[SSANM-009b8]` debug-WASI first diff,
  // `defined=1286 abs=1313` (`run_hot_pipeline_raw_simplify_locals_take_value_suffix`).
  // The raw input nests a source-lowered single-param/no-result typed loop inside
  // an outer void loop. Binaryen leaves the typed loop carrier canonical; the
  // legacy structured helper lowers it to a void loop with block-result carrier
  // locals, which can add size and risks stranding later backedge updates on a
  // different helper local. Keep this nested plain-`br` boundary fail-closed
  // until nested typed-loop carrier lowering is Binaryen-shaped.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func $sink (param i32))
    #|  (func $len (param i32) (result i32) (i32.const 3))
    #|  (func $at (param i32 i32) (result i32) (local.get 1))
    #|  (func $f (export "f") (param $arr i32) (result i32)
    #|    (local $outer i32) (local $idx i32) (local $tmp i32)
    #|    (local $item i32) (local $tee i32) (local $unused i32)
    #|    i32.const 0
    #|    local.set $outer
    #|    loop $outer_loop
    #|      local.get $outer
    #|      i32.const 1
    #|      i32.lt_s
    #|      if
    #|        local.get $arr
    #|        call $len
    #|        local.tee $tee
    #|        loop (type $loop_t)
    #|          local.set $idx
    #|          local.get $arr
    #|          call $len
    #|          local.set $tmp
    #|          local.get $idx
    #|          local.get $tmp
    #|          i32.lt_s
    #|          if
    #|            local.get $arr
    #|            local.get $idx
    #|            call $at
    #|            local.set $item
    #|            local.get $item
    #|            call $sink
    #|            local.get $idx
    #|            i32.const 1
    #|            i32.add
    #|            local.tee $unused
    #|            br 1
    #|          end
    #|          i32.const 0
    #|          drop
    #|        end
    #|        local.get $outer
    #|        i32.const 1
    #|        i32.add
    #|        local.set $outer
    #|        br $outer_loop
    #|      end
    #|    end
    #|    local.get $idx))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nested typed loop-param plain br boundary success, got \{err}",
      )
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected nested typed loop-param plain br boundary output to validate, got \{@validate.validation_error_message(err)}",
      )
  }
  ssa_test_assert_ssa_nomerge_raw_reason(
    trace, "loop-param-plain-br-boundary-noop",
  )
  ssa_test_assert_no_planned_structured_trace_reason(trace)
  ssa_test_assert_no_ssa_nomerge_mutation_trace(trace)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 3)
  assert_true(locals.length() <= 6, msg=locals.to_string())
  let writes = ssa_test_local_write_indices(instrs)
  assert_false(writes.any(fn(idx) { idx >= 7U }), msg=instrs.to_string())
}

///|
test "ssa-nomerge artifact branch result carriers are not defaulted" {
  // Reduced from the post-`[SSANM-009b7]` debug-WASI first diff,
  // `defined=1163 abs=1190` (`ar_rewrite_load_reinterpret_pair`). The
  // branch arms store the selected memarg in a canonical local and branch to a
  // constructor-specific continuation. Binaryen keeps those continuation reads
  // canonical; Starshine must not treat them as body-local entry defaults and
  // call the constructors with `i32.const 0`.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $moonbit.free (param i32))
    #|  (func $moonbit.incref (param i32))
    #|  (func $moonbit.decref (param i32))
    #|  (func $i32_load (param i32) (result i32) (local.get 0))
    #|  (func $i64_load (param i32) (result i32) (local.get 0))
    #|  (func $f32_load (param i32) (result i32) (local.get 0))
    #|  (func $f64_load (param i32) (result i32) (local.get 0))
    #|  (func $f (export "f") (param $load i32) (param $reinterpret i32) (result i32)
    #|    (local $memarg_f64 i32) (local $memarg_f32 i32) (local $memarg_i64 i32) (local $memarg_i32 i32)
    #|    (local $F32Load i32) (local $memarg_f32_tmp i32) (local $F64Load i32) (local $memarg_f64_tmp i32)
    #|    (local $I32Load i32) (local $memarg_i32_tmp i32) (local $I64Load i32) (local $memarg_i64_tmp i32)
    #|    (local $cnt0 i32) (local $new_cnt0 i32) (local $cnt1 i32) (local $new_cnt1 i32)
    #|    (local $cnt2 i32) (local $new_cnt2 i32) (local $cnt3 i32) (local $new_cnt3 i32)
    #|    (local $tag0 i32) (local $tag1 i32) (local $tag2 i32) (local $tag3 i32) (local $tag4 i32)
    #|    block ;; label = @1
    #|      block ;; label = @2
    #|        block ;; label = @3
    #|          block ;; label = @4
    #|            block ;; label = @5
    #|              local.get $load
    #|              i32.load offset=8 align=1
    #|              local.set $tag0
    #|              block (result i32) ;; label = @6
    #|                block ;; label = @7
    #|                  block ;; label = @8
    #|                    block ;; label = @9
    #|                      block ;; label = @10
    #|                        block ;; label = @11
    #|                          local.get $tag0
    #|                          i32.const 27
    #|                          i32.sub
    #|                          br_table 2 (;@9;) 3 (;@8;) 0 (;@11;) 1 (;@10;) 4 (;@7;)
    #|                        end
    #|                        local.get $load
    #|                        local.tee $F32Load
    #|                        i32.load offset=12 align=1
    #|                        local.set $memarg_f32_tmp
    #|                        local.get $F32Load
    #|                        i32.load align=1
    #|                        local.tee $cnt0
    #|                        i32.const 1
    #|                        i32.gt_s
    #|                        if
    #|                          local.get $cnt0
    #|                          i32.const 1
    #|                          i32.sub
    #|                          local.set $new_cnt0
    #|                          local.get $F32Load
    #|                          local.get $new_cnt0
    #|                          i32.store align=1
    #|                          local.get $memarg_f32_tmp
    #|                          call $moonbit.incref
    #|                        else
    #|                          local.get $cnt0
    #|                          i32.const 1
    #|                          i32.eq
    #|                          if
    #|                            local.get $F32Load
    #|                            call $moonbit.free
    #|                          end
    #|                        end
    #|                        local.get $memarg_f32_tmp
    #|                        local.set $memarg_i32
    #|                        local.get $reinterpret
    #|                        i32.load offset=8 align=1
    #|                        local.tee $tag1
    #|                        i32.const 195
    #|                        i32.eq
    #|                        if (result i32)
    #|                          local.get $memarg_i32
    #|                          local.set $memarg_i32
    #|                          br 6 (;@5;)
    #|                        else
    #|                          local.get $reinterpret
    #|                          call $moonbit.decref
    #|                          local.get $memarg_i32
    #|                          call $moonbit.decref
    #|                          br 10 (;@1;)
    #|                        end
    #|                        br 4 (;@6;)
    #|                      end
    #|                      local.get $load
    #|                      local.tee $F64Load
    #|                      i32.load offset=12 align=1
    #|                      local.set $memarg_f64_tmp
    #|                      local.get $F64Load
    #|                      i32.load align=1
    #|                      local.tee $cnt1
    #|                      i32.const 1
    #|                      i32.gt_s
    #|                      if
    #|                        local.get $cnt1
    #|                        i32.const 1
    #|                        i32.sub
    #|                        local.set $new_cnt1
    #|                        local.get $F64Load
    #|                        local.get $new_cnt1
    #|                        i32.store align=1
    #|                        local.get $memarg_f64_tmp
    #|                        call $moonbit.incref
    #|                      else
    #|                        local.get $cnt1
    #|                        i32.const 1
    #|                        i32.eq
    #|                        if
    #|                          local.get $F64Load
    #|                          call $moonbit.free
    #|                        end
    #|                      end
    #|                      local.get $memarg_f64_tmp
    #|                      local.set $memarg_i64
    #|                      local.get $reinterpret
    #|                      i32.load offset=8 align=1
    #|                      local.tee $tag2
    #|                      i32.const 196
    #|                      i32.eq
    #|                      if (result i32)
    #|                        local.get $memarg_i64
    #|                        local.set $memarg_i64
    #|                        br 6 (;@4;)
    #|                      else
    #|                        local.get $memarg_i64
    #|                        call $moonbit.decref
    #|                        local.get $reinterpret
    #|                        call $moonbit.decref
    #|                        br 9 (;@1;)
    #|                      end
    #|                      br 3 (;@6;)
    #|                    end
    #|                    local.get $load
    #|                    local.tee $I32Load
    #|                    i32.load offset=12 align=1
    #|                    local.set $memarg_i32_tmp
    #|                    local.get $I32Load
    #|                    i32.load align=1
    #|                    local.tee $cnt2
    #|                    i32.const 1
    #|                    i32.gt_s
    #|                    if
    #|                      local.get $cnt2
    #|                      i32.const 1
    #|                      i32.sub
    #|                      local.set $new_cnt2
    #|                      local.get $I32Load
    #|                      local.get $new_cnt2
    #|                      i32.store align=1
    #|                      local.get $memarg_i32_tmp
    #|                      call $moonbit.incref
    #|                    else
    #|                      local.get $cnt2
    #|                      i32.const 1
    #|                      i32.eq
    #|                      if
    #|                        local.get $I32Load
    #|                        call $moonbit.free
    #|                      end
    #|                    end
    #|                    local.get $memarg_i32_tmp
    #|                    local.set $memarg_f32
    #|                    local.get $reinterpret
    #|                    i32.load offset=8 align=1
    #|                    local.tee $tag3
    #|                    i32.const 197
    #|                    i32.eq
    #|                    if (result i32)
    #|                      local.get $memarg_f32
    #|                      local.set $memarg_f32
    #|                      br 6 (;@3;)
    #|                    else
    #|                      local.get $memarg_f32
    #|                      call $moonbit.decref
    #|                      local.get $reinterpret
    #|                      call $moonbit.decref
    #|                      br 8 (;@1;)
    #|                    end
    #|                    br 2 (;@6;)
    #|                  end
    #|                  local.get $load
    #|                  local.tee $I64Load
    #|                  i32.load offset=12 align=1
    #|                  local.set $memarg_i64_tmp
    #|                  local.get $I64Load
    #|                  i32.load align=1
    #|                  local.tee $cnt3
    #|                  i32.const 1
    #|                  i32.gt_s
    #|                  if
    #|                    local.get $cnt3
    #|                    i32.const 1
    #|                    i32.sub
    #|                    local.set $new_cnt3
    #|                    local.get $I64Load
    #|                    local.get $new_cnt3
    #|                    i32.store align=1
    #|                    local.get $memarg_i64_tmp
    #|                    call $moonbit.incref
    #|                  else
    #|                    local.get $cnt3
    #|                    i32.const 1
    #|                    i32.eq
    #|                    if
    #|                      local.get $I64Load
    #|                      call $moonbit.free
    #|                    end
    #|                  end
    #|                  local.get $memarg_i64_tmp
    #|                  local.set $memarg_f64
    #|                  local.get $reinterpret
    #|                  i32.load offset=8 align=1
    #|                  local.tee $tag4
    #|                  i32.const 198
    #|                  i32.eq
    #|                  if (result i32)
    #|                    local.get $memarg_f64
    #|                    local.set $memarg_f64
    #|                    br 6 (;@2;)
    #|                  else
    #|                    local.get $memarg_f64
    #|                    call $moonbit.decref
    #|                    local.get $reinterpret
    #|                    call $moonbit.decref
    #|                    br 7 (;@1;)
    #|                  end
    #|                  br 1 (;@6;)
    #|                end
    #|                local.get $reinterpret
    #|                call $moonbit.decref
    #|                local.get $load
    #|                call $moonbit.decref
    #|                br 5 (;@1;)
    #|              end
    #|              return
    #|            end
    #|            local.get $memarg_i32
    #|            call $i32_load
    #|            return
    #|          end
    #|          local.get $memarg_i64
    #|          call $i64_load
    #|          return
    #|        end
    #|        local.get $memarg_f32
    #|        call $f32_load
    #|        return
    #|      end
    #|      local.get $memarg_f64
    #|      call $f64_load
    #|      return
    #|    end
    #|    i32.const 0)
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected branch result-carrier fixture success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected branch result-carrier output to validate, got \{@validate.validation_error_message(err)}",
      )
  }
  let (_, instrs) = try! ssa_test_defined_func(optimized, 7)
  assert_false(
    ssa_test_instrs_have_i32_const_call(instrs, 0, 3U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_i32_const_call(instrs, 0, 4U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_i32_const_call(instrs, 0, 5U),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_instrs_have_i32_const_call(instrs, 0, 6U),
    msg=instrs.to_string(),
  )
  assert_true(trace.length() > 0, msg=trace.join("\n"))
}

///|
test "ssa-nomerge artifact branch carrier keeps canonical merged label writes" {
  // Reduced standalone module for the post-`[SSANM-009b2]` debug-WASI
  // first diff, `defined=363 abs=390` (`dae_instr_has_escaping_branch`).
  // Binaryen keeps the shared branch label local canonical because two tag arms
  // feed later branch-target checks. Starshine must not freshen those writes into
  // private arm locals while leaving the outer reads on the original body local.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $moonbit.decref (param i32))
    #|  (func $moonbit.incref (param i32))
    #|  (func $moonbit.free (param i32))
    #|  (func $_M0FP37jtenner9starshine6passes36dae__branch__targets__outside__depth (param i32 i32) (result i32) (local.get 0))
    #|  (func $_M0FP37jtenner9starshine6passes35dae__instrs__have__escaping__branch (param i32 i32) (result i32) (local.get 0))
    #|  (func $f (export "f") (param $_M0L5instrS93868 i32) (param $_M0L5depthS93853 i32) (result i32)
    #|    (local $_M0L10then__bodyS93852 i32) (local $_M0L10then__bodyS93855 i32) (local $_M0L10else__bodyS93856 i32) (local $_M0L4bodyS93858 i32) (local $_M0L6labelsS93860 i32) (local $_M0L8fallbackS93861 i32) (local $_M0L7_2abindS93862 i32) (local $_M0L2__S93863 i32) (local $_M0L10label__idxS93864 i32) (local $_M0L10label__idxS93867 i32) (local $_M0L5_2aBrS93869 i32) (local $_M0L13_2alabel__idxS93870 i32) (local $_M0L7_2aBrIfS93871 i32) (local $_M0L13_2alabel__idxS93872 i32) (local $_M0L10_2aBrTableS93873 i32) (local $_M0L9_2alabelsS93874 i32) (local $_M0L11_2afallbackS93875 i32) (local $_M0L8_2aBlockS93876 i32) (local $_M0L4_2axS93877 i32) (local $_M0L7_2abodyS93878 i32) (local $_M0L7_2aLoopS93879 i32) (local $_M0L4_2axS93880 i32) (local $_M0L7_2abodyS93881 i32) (local $_M0L11_2aTryTableS93882 i32) (local $_M0L4_2axS93883 i32) (local $_M0L7_2abodyS93884 i32) (local $_M0L5_2aIfS93885 i32) (local $_M0L13_2athen__bodyS93886 i32) (local $_M0L4_2axS93887 i32) (local $_M0L7_2aSomeS93888 i32) (local $_M0L13_2aelse__bodyS93889 i32) (local $_M0L6_2atmpS152630 i32) (local $_M0L6_2atmpS152631 i32) (local $_M0L6_2atmpS152632 i32) (local $_M0L6_2atmpS152633 i32) (local $_M0L6_2atmpS152634 i32) (local $_M0L3bufS152635 i32) (local $_M0L8_2afieldS159536 i32) (local $_M0L8_2afieldS159537 i32) (local $_M0L8_2afieldS159538 i32) (local $_M0L8_2afieldS159539 i32) (local $_M0L6_2acntS177856 i32) (local $_M0L11_2anew__cntS177857 i32) (local $_M0L6_2acntS177858 i32) (local $_M0L8_2afieldS177859 i32) (local $_M0L11_2anew__cntS177860 i32) (local $_M0L6_2acntS177861 i32) (local $_M0L8_2afieldS177862 i32) (local $_M0L11_2anew__cntS177863 i32) (local $_M0L6_2acntS177864 i32) (local $_M0L8_2afieldS177865 i32) (local $_M0L8_2afieldS177866 i32) (local $_M0L11_2anew__cntS177867 i32) (local $_M0L6_2acntS177868 i32) (local $_M0L8_2afieldS177869 i32) (local $_M0L11_2anew__cntS177870 i32) (local $_M0L6_2atagS201047 i32)
    #|    block ;; label = @1
    #|      block ;; label = @2
    #|        block ;; label = @3
    #|          block ;; label = @4
    #|            block ;; label = @5
    #|              local.get $_M0L5instrS93868
    #|              i32.load offset=8 align=1
    #|              local.tee $_M0L6_2atagS201047
    #|              i32.const 7
    #|              i32.eq
    #|              if (result i32) ;; label = @6
    #|                local.get $_M0L5instrS93868
    #|                local.tee $_M0L5_2aBrS93869
    #|                i32.load offset=12 align=1
    #|                local.get $_M0L5_2aBrS93869
    #|                call $moonbit.decref
    #|                local.tee $_M0L13_2alabel__idxS93870
    #|                local.set $_M0L10label__idxS93867
    #|                br 1 (;@5;)
    #|              else
    #|                local.get $_M0L6_2atagS201047
    #|                i32.const 8
    #|                i32.eq
    #|                if (result i32) ;; label = @7
    #|                  local.get $_M0L5instrS93868
    #|                  local.tee $_M0L7_2aBrIfS93871
    #|                  i32.load offset=12 align=1
    #|                  local.get $_M0L7_2aBrIfS93871
    #|                  call $moonbit.decref
    #|                  local.tee $_M0L13_2alabel__idxS93872
    #|                  local.set $_M0L10label__idxS93867
    #|                  br 2 (;@5;)
    #|                else
    #|                  local.get $_M0L6_2atagS201047
    #|                  i32.const 9
    #|                  i32.eq
    #|                  if (result i32) ;; label = @8
    #|                    local.get $_M0L5instrS93868
    #|                    local.tee $_M0L10_2aBrTableS93873
    #|                    i32.load offset=16 align=1
    #|                    local.set $_M0L9_2alabelsS93874
    #|                    local.get $_M0L10_2aBrTableS93873
    #|                    i32.load offset=12 align=1
    #|                    local.get $_M0L10_2aBrTableS93873
    #|                    i32.load align=1
    #|                    local.tee $_M0L6_2acntS177856
    #|                    i32.const 1
    #|                    i32.gt_s
    #|                    if ;; label = @9
    #|                      local.get $_M0L6_2acntS177856
    #|                      i32.const 1
    #|                      i32.sub
    #|                      local.set $_M0L11_2anew__cntS177857
    #|                      local.get $_M0L10_2aBrTableS93873
    #|                      local.get $_M0L11_2anew__cntS177857
    #|                      i32.store align=1
    #|                      local.get $_M0L9_2alabelsS93874
    #|                      call $moonbit.incref
    #|                    else
    #|                      local.get $_M0L6_2acntS177856
    #|                      i32.const 1
    #|                      i32.eq
    #|                      if ;; label = @10
    #|                        local.get $_M0L10_2aBrTableS93873
    #|                        call $moonbit.free
    #|                      end
    #|                    end
    #|                    local.set $_M0L11_2afallbackS93875
    #|                    local.get $_M0L9_2alabelsS93874
    #|                    local.get $_M0L11_2afallbackS93875
    #|                    local.set $_M0L8fallbackS93861
    #|                    local.set $_M0L6labelsS93860
    #|                    br 4 (;@4;)
    #|                  else
    #|                    local.get $_M0L6_2atagS201047
    #|                    i32.const 2
    #|                    i32.eq
    #|                    if (result i32) ;; label = @9
    #|                      local.get $_M0L5instrS93868
    #|                      local.tee $_M0L8_2aBlockS93876
    #|                      i32.load offset=16 align=1
    #|                      local.set $_M0L8_2afieldS159536
    #|                      local.get $_M0L8_2aBlockS93876
    #|                      i32.load align=1
    #|                      local.tee $_M0L6_2acntS177858
    #|                      i32.const 1
    #|                      i32.gt_s
    #|                      if ;; label = @10
    #|                        local.get $_M0L6_2acntS177858
    #|                        i32.const 1
    #|                        i32.sub
    #|                        local.set $_M0L11_2anew__cntS177860
    #|                        local.get $_M0L8_2aBlockS93876
    #|                        local.get $_M0L11_2anew__cntS177860
    #|                        i32.store align=1
    #|                        local.get $_M0L8_2afieldS159536
    #|                        call $moonbit.incref
    #|                      else
    #|                        local.get $_M0L6_2acntS177858
    #|                        i32.const 1
    #|                        i32.eq
    #|                        if ;; label = @11
    #|                          local.get $_M0L8_2aBlockS93876
    #|                          i32.load offset=12 align=1
    #|                          local.tee $_M0L8_2afieldS177859
    #|                          call $moonbit.decref
    #|                          local.get $_M0L8_2aBlockS93876
    #|                          call $moonbit.free
    #|                        end
    #|                      end
    #|                      local.get $_M0L8_2afieldS159536
    #|                      local.tee $_M0L4_2axS93877
    #|                      local.tee $_M0L7_2abodyS93878
    #|                      local.set $_M0L4bodyS93858
    #|                      br 6 (;@3;)
    #|                    else
    #|                      local.get $_M0L6_2atagS201047
    #|                      i32.const 3
    #|                      i32.eq
    #|                      if (result i32) ;; label = @10
    #|                        local.get $_M0L5instrS93868
    #|                        local.tee $_M0L7_2aLoopS93879
    #|                        i32.load offset=16 align=1
    #|                        local.set $_M0L8_2afieldS159537
    #|                        local.get $_M0L7_2aLoopS93879
    #|                        i32.load align=1
    #|                        local.tee $_M0L6_2acntS177861
    #|                        i32.const 1
    #|                        i32.gt_s
    #|                        if ;; label = @11
    #|                          local.get $_M0L6_2acntS177861
    #|                          i32.const 1
    #|                          i32.sub
    #|                          local.set $_M0L11_2anew__cntS177863
    #|                          local.get $_M0L7_2aLoopS93879
    #|                          local.get $_M0L11_2anew__cntS177863
    #|                          i32.store align=1
    #|                          local.get $_M0L8_2afieldS159537
    #|                          call $moonbit.incref
    #|                        else
    #|                          local.get $_M0L6_2acntS177861
    #|                          i32.const 1
    #|                          i32.eq
    #|                          if ;; label = @12
    #|                            local.get $_M0L7_2aLoopS93879
    #|                            i32.load offset=12 align=1
    #|                            local.tee $_M0L8_2afieldS177862
    #|                            call $moonbit.decref
    #|                            local.get $_M0L7_2aLoopS93879
    #|                            call $moonbit.free
    #|                          end
    #|                        end
    #|                        local.get $_M0L8_2afieldS159537
    #|                        local.tee $_M0L4_2axS93880
    #|                        local.tee $_M0L7_2abodyS93881
    #|                        local.set $_M0L4bodyS93858
    #|                        br 7 (;@3;)
    #|                      else
    #|                        local.get $_M0L6_2atagS201047
    #|                        i32.const 19
    #|                        i32.eq
    #|                        if (result i32) ;; label = @11
    #|                          local.get $_M0L5instrS93868
    #|                          local.tee $_M0L11_2aTryTableS93882
    #|                          i32.load offset=20 align=1
    #|                          local.set $_M0L8_2afieldS159538
    #|                          local.get $_M0L11_2aTryTableS93882
    #|                          i32.load align=1
    #|                          local.tee $_M0L6_2acntS177864
    #|                          i32.const 1
    #|                          i32.gt_s
    #|                          if ;; label = @12
    #|                            local.get $_M0L6_2acntS177864
    #|                            i32.const 1
    #|                            i32.sub
    #|                            local.set $_M0L11_2anew__cntS177867
    #|                            local.get $_M0L11_2aTryTableS93882
    #|                            local.get $_M0L11_2anew__cntS177867
    #|                            i32.store align=1
    #|                            local.get $_M0L8_2afieldS159538
    #|                            call $moonbit.incref
    #|                          else
    #|                            local.get $_M0L6_2acntS177864
    #|                            i32.const 1
    #|                            i32.eq
    #|                            if ;; label = @13
    #|                              local.get $_M0L11_2aTryTableS93882
    #|                              i32.load offset=16 align=1
    #|                              local.tee $_M0L8_2afieldS177866
    #|                              call $moonbit.decref
    #|                              local.get $_M0L11_2aTryTableS93882
    #|                              i32.load offset=12 align=1
    #|                              local.tee $_M0L8_2afieldS177865
    #|                              call $moonbit.decref
    #|                              local.get $_M0L11_2aTryTableS93882
    #|                              call $moonbit.free
    #|                            end
    #|                          end
    #|                          local.get $_M0L8_2afieldS159538
    #|                          local.tee $_M0L4_2axS93883
    #|                          local.tee $_M0L7_2abodyS93884
    #|                          local.set $_M0L4bodyS93858
    #|                          br 8 (;@3;)
    #|                        else
    #|                          local.get $_M0L6_2atagS201047
    #|                          i32.const 4
    #|                          i32.eq
    #|                          if (result i32) ;; label = @12
    #|                            local.get $_M0L5instrS93868
    #|                            local.tee $_M0L5_2aIfS93885
    #|                            i32.load offset=16 align=1
    #|                            local.set $_M0L13_2athen__bodyS93886
    #|                            local.get $_M0L5_2aIfS93885
    #|                            i32.load offset=20 align=1
    #|                            local.set $_M0L8_2afieldS159539
    #|                            local.get $_M0L5_2aIfS93885
    #|                            i32.load align=1
    #|                            local.tee $_M0L6_2acntS177868
    #|                            i32.const 1
    #|                            i32.gt_s
    #|                            if ;; label = @13
    #|                              local.get $_M0L6_2acntS177868
    #|                              i32.const 1
    #|                              i32.sub
    #|                              local.set $_M0L11_2anew__cntS177870
    #|                              local.get $_M0L5_2aIfS93885
    #|                              local.get $_M0L11_2anew__cntS177870
    #|                              i32.store align=1
    #|                              local.get $_M0L8_2afieldS159539
    #|                              if ;; label = @14
    #|                                local.get $_M0L8_2afieldS159539
    #|                                call $moonbit.incref
    #|                              end
    #|                              local.get $_M0L13_2athen__bodyS93886
    #|                              call $moonbit.incref
    #|                            else
    #|                              local.get $_M0L6_2acntS177868
    #|                              i32.const 1
    #|                              i32.eq
    #|                              if ;; label = @14
    #|                                local.get $_M0L5_2aIfS93885
    #|                                i32.load offset=12 align=1
    #|                                local.tee $_M0L8_2afieldS177869
    #|                                call $moonbit.decref
    #|                                local.get $_M0L5_2aIfS93885
    #|                                call $moonbit.free
    #|                              end
    #|                            end
    #|                            local.get $_M0L8_2afieldS159539
    #|                            local.tee $_M0L4_2axS93887
    #|                            i32.const 0
    #|                            i32.eq
    #|                            if (result i32) ;; label = @13
    #|                              local.get $_M0L4_2axS93887
    #|                              if ;; label = @14
    #|                                local.get $_M0L4_2axS93887
    #|                                call $moonbit.decref
    #|                              end
    #|                              local.get $_M0L13_2athen__bodyS93886
    #|                              local.set $_M0L10then__bodyS93852
    #|                              br 12 (;@1;)
    #|                            else
    #|                              local.get $_M0L4_2axS93887
    #|                              local.tee $_M0L7_2aSomeS93888
    #|                              local.set $_M0L13_2aelse__bodyS93889
    #|                              local.get $_M0L13_2athen__bodyS93886
    #|                              local.get $_M0L13_2aelse__bodyS93889
    #|                              local.set $_M0L10else__bodyS93856
    #|                              local.set $_M0L10then__bodyS93855
    #|                              br 11 (;@2;)
    #|                            end
    #|                          else
    #|                            local.get $_M0L5instrS93868
    #|                            call $moonbit.decref
    #|                            i32.const 0
    #|                          end
    #|                        end
    #|                      end
    #|                    end
    #|                  end
    #|                end
    #|              end
    #|              return
    #|            end
    #|            local.get $_M0L10label__idxS93867
    #|            local.get $_M0L5depthS93853
    #|            call $_M0FP37jtenner9starshine6passes36dae__branch__targets__outside__depth
    #|            return
    #|          end
    #|          local.get $_M0L6labelsS93860
    #|          i32.load offset=8 align=1
    #|          local.set $_M0L7_2abindS93862
    #|          i32.const 0
    #|          loop (param i32) ;; label = @4
    #|            local.tee $_M0L2__S93863
    #|            local.get $_M0L7_2abindS93862
    #|            i32.lt_s
    #|            if ;; label = @5
    #|              local.get $_M0L6labelsS93860
    #|              i32.load offset=12 align=1
    #|              local.tee $_M0L3bufS152635
    #|              local.get $_M0L2__S93863
    #|              i32.const 2
    #|              i32.shl
    #|              i32.add
    #|              i32.load offset=8 align=1
    #|              local.set $_M0L10label__idxS93864
    #|              local.get $_M0L10label__idxS93864
    #|              local.get $_M0L5depthS93853
    #|              call $_M0FP37jtenner9starshine6passes36dae__branch__targets__outside__depth
    #|              if ;; label = @6
    #|                local.get $_M0L6labelsS93860
    #|                call $moonbit.decref
    #|                i32.const 1
    #|                return
    #|              end
    #|              i32.const 0
    #|              drop
    #|              local.get $_M0L2__S93863
    #|              i32.const 1
    #|              i32.add
    #|              local.tee $_M0L6_2atmpS152634
    #|              br 1 (;@4;)
    #|            else
    #|              local.get $_M0L6labelsS93860
    #|              call $moonbit.decref
    #|            end
    #|          end
    #|          i32.const 0
    #|          drop
    #|          local.get $_M0L8fallbackS93861
    #|          local.get $_M0L5depthS93853
    #|          call $_M0FP37jtenner9starshine6passes36dae__branch__targets__outside__depth
    #|          return
    #|        end
    #|        local.get $_M0L5depthS93853
    #|        i32.const 1
    #|        i32.add
    #|        local.set $_M0L6_2atmpS152633
    #|        local.get $_M0L4bodyS93858
    #|        local.get $_M0L6_2atmpS152633
    #|        call $_M0FP37jtenner9starshine6passes35dae__instrs__have__escaping__branch
    #|        return
    #|      end
    #|      local.get $_M0L5depthS93853
    #|      i32.const 1
    #|      i32.add
    #|      local.set $_M0L6_2atmpS152632
    #|      local.get $_M0L10then__bodyS93855
    #|      local.get $_M0L6_2atmpS152632
    #|      call $_M0FP37jtenner9starshine6passes35dae__instrs__have__escaping__branch
    #|      if (result i32) ;; label = @2
    #|        local.get $_M0L10else__bodyS93856
    #|        call $moonbit.decref
    #|        i32.const 1
    #|      else
    #|        local.get $_M0L5depthS93853
    #|        i32.const 1
    #|        i32.add
    #|        local.set $_M0L6_2atmpS152631
    #|        local.get $_M0L10else__bodyS93856
    #|        local.get $_M0L6_2atmpS152631
    #|        call $_M0FP37jtenner9starshine6passes35dae__instrs__have__escaping__branch
    #|      end
    #|      return
    #|    end
    #|    local.get $_M0L5depthS93853
    #|    i32.const 1
    #|    i32.add
    #|    local.set $_M0L6_2atmpS152630
    #|    local.get $_M0L10then__bodyS93852
    #|    local.get $_M0L6_2atmpS152630
    #|    call $_M0FP37jtenner9starshine6passes35dae__instrs__have__escaping__branch
    #|  )
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected branch-carrier fixture success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_defined_func(optimized, 5)
  let writes = ssa_test_local_write_indices(instrs)
  let gets = ssa_nomerge_test_local_get_indices(instrs)
  assert_true(
    writes.contains(11U),
    msg="branch-carried label local must be written canonically; locals=\{locals} instrs=\{instrs}",
  )
  assert_true(
    gets.contains(11U),
    msg="branch-carried label local should still feed the outer branch-target check; locals=\{locals} instrs=\{instrs}",
  )
  assert_false(
    trace.any(fn(line) { line.contains("hot-lift-error") }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge LocalGraph straight-line stack-carried tee keeps later gets live" {
  // Reduced from the current debug-WASI first diff
  // `.tmp/self-ssa-nomerge-debug-wasi-anchor-refresh-20260614`,
  // `defined=108 abs=135`. A void call can sit between a stack-carried
  // producer and `local.tee`; later reads must use the fresh tee local, not the
  // body-local default.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func $make (param i32) (result i32) (local.get 0))
    #|  (func $join (param i32 i32) (result i32) (local.get 0))
    #|  (func $drop (param i32))
    #|  (func (param i32) (result i32) (local i32 i32 i32)
    #|    local.get 0
    #|    call $make
    #|    local.set 1
    #|    i32.const 100
    #|    local.get 1
    #|    call $join
    #|    local.get 1
    #|    call $drop
    #|    local.tee 2
    #|    i32.const 200
    #|    call $join
    #|    local.get 2
    #|    call $drop
    #|    local.set 3
    #|    local.get 3))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected stack-carried local.tee ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_defined_func(optimized, 3)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(100)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::call(@lib.FuncIdx::new(2U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(4U)),
    @lib.Instruction::i32_const(@lib.I32(200)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
    @lib.Instruction::call(@lib.FuncIdx::new(2U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
  ])
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=straight-line-local-writes-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge preserves branch-carried parameter tee boundary canonical" {
  // Reduced from the post-[SSANM-009b9] debug-WASI first alpha-diff
  // `defined=3 abs=30` (`tlsf/addMemory`). The condition writes an aligned
  // pointer back to parameter local 1 with `local.tee`, while the taken branch
  // may overwrite that same parameter before later reads. Binaryen keeps this
  // parameter carrier canonical; freshening the tee to a body local changes the
  // value observed on the not-taken path.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (memory 1)
    #|  (func (param i32 i32 i64) (local i32 i32 i32)
    #|    local.get 0
    #|    i32.load
    #|    local.tee 4
    #|    i32.const 0
    #|    local.get 1
    #|    i32.const 19
    #|    i32.add
    #|    i32.const -16
    #|    i32.and
    #|    i32.const 4
    #|    i32.sub
    #|    local.tee 1
    #|    i32.const 16
    #|    i32.sub
    #|    local.tee 3
    #|    local.get 4
    #|    i32.eq
    #|    select
    #|    if
    #|      local.get 4
    #|      i32.load
    #|      local.set 5
    #|      local.get 3
    #|      local.set 1
    #|    end
    #|    local.get 2
    #|    i32.wrap_i64
    #|    i32.const -16
    #|    i32.and
    #|    local.get 1
    #|    i32.sub
    #|    local.tee 3
    #|    i32.const 20
    #|    i32.lt_u
    #|    if
    #|      return
    #|    end
    #|    local.get 1
    #|    local.get 5
    #|    local.get 3
    #|    i32.add
    #|    i32.store))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected parameter tee branch-carrier boundary success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(ssa_test_local_tee_indices(instrs), [6U, 1U, 7U, 8U])
  @debug.assert_eq(ssa_test_local_set_indices(instrs), [5U, 1U])
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge LocalGraph materializes straight-line default numeric and vector gets" {
  let numeric_trace : Array[String] = []
  let numeric = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32 i32) i32.const 9 local.set 0 local.get 0 local.get 1 i32.add))",
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(
        trace=Some(fn(line) { numeric_trace.push(line) }),
      ),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected numeric default materialization success, got \{err}")
  }
  let (_, numeric_instrs) = try! ssa_test_first_defined_func(numeric)
  @debug.assert_eq(numeric_instrs, [
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_add(),
  ])
  assert_true(
    numeric_trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=straight-line-local-writes-localgraph-plan",
      )
    }),
    msg=numeric_trace.join("\n"),
  )

  let vector_trace : Array[String] = []
  let vector = match
    pass_test_run_pipeline(
      "(module (func (result v128) (local i32 v128) i32.const 1 local.set 0 local.get 1))",
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(
        trace=Some(fn(line) { vector_trace.push(line) }),
      ),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected vector default materialization success, got \{err}")
  }
  let (_, vector_instrs) = try! ssa_test_first_defined_func(vector)
  @debug.assert_eq(vector_instrs, [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::v128_const(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  ])
  assert_true(
    vector_trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=straight-line-local-writes-localgraph-plan",
      )
    }),
    msg=vector_trace.join("\n"),
  )
}

///|
test "ssa-nomerge LocalGraph materializes structured body defaults with writes" {
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    i32.const 7
    #|    local.set 1
    #|    block
    #|      local.get 0
    #|      br_if 0
    #|    end
    #|    local.get 1
    #|    local.get 2
    #|    i32.add))
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected structured default materialization success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let gets = ssa_nomerge_test_local_get_indices(instrs)
  assert_false(gets.contains(2U), msg=instrs.to_string())
  assert_true(
    instrs.to_string().contains("i32.const I32(0)"),
    msg=instrs.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-default-local-reads-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge LocalGraph materializes pre-write body defaults" {
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func (result i32) (local i32)
    #|    (block (br 0))
    #|    local.get 0
    #|    drop
    #|    i32.const 7
    #|    local.set 0
    #|    local.get 0))
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected pre-write default materialization success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(ssa_nomerge_test_local_get_indices(instrs), [0U])
  assert_true(
    instrs.to_string().contains("i32.const I32(0)"),
    msg=instrs.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-default-local-reads-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )

  let table_trace : Array[String] = []
  let table_source =
    #|(module
    #|  (func (result i32) (local i32)
    #|    (block
    #|      i32.const 0
    #|      br_table 0 0)
    #|    local.get 0
    #|    drop
    #|    i32.const 9
    #|    local.set 0
    #|    local.get 0))
  let table_optimized = match
    pass_test_run_pipeline(
      table_source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(
        trace=Some(fn(line) { table_trace.push(line) }),
      ),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected br_table pre-write default materialization success, got \{err}",
      )
  }
  let (_, table_instrs) = try! ssa_test_first_defined_func(table_optimized)
  @debug.assert_eq(ssa_nomerge_test_local_get_indices(table_instrs), [0U])
  assert_true(
    table_instrs.to_string().contains("i32.const I32(0)"),
    msg=table_instrs.to_string(),
  )
  assert_true(
    table_trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-default-local-reads-localgraph-plan",
      )
    }),
    msg=table_trace.join("\n"),
  )
}

///|
test "ssa-nomerge LocalGraph materializes structured exact ref defaults with writes" {
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $child (sub $base (struct)))
    #|  (func (result (ref null $base))
    #|    (local i32 (ref null (exact $child)))
    #|    i32.const 3
    #|    local.set 0
    #|    (block (result (ref null $base))
    #|      local.get 1)))
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected structured exact-ref default materialization success, got \{err}",
      )
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  ssa_test_assert_default_read_replaced_with_ref_null(
    instrs,
    @lib.RefType::new(
      true,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
    "LocalGraph structured exact-ref default should keep child exact ref.null",
  )
  assert_false(
    ssa_nomerge_test_local_get_indices(instrs).contains(1U),
    msg=instrs.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-default-local-reads-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge LocalGraph keeps parameter-entry reads canonical" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) i32.const 5 local.set 1 local.get 0))",
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected parameter-entry fixture success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(ssa_nomerge_test_local_get_indices(instrs), [0U])
}

///|
test "ssa-nomerge LocalGraph preserves one-arm body-local default merge canonical" {
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    if
    #|      i32.const 7
    #|      local.set 1
    #|    end
    #|    local.get 1))
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected one-arm body-local merge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(ssa_test_local_set_indices(instrs), [1U])
  @debug.assert_eq(ssa_nomerge_test_local_get_indices(instrs), [0U, 1U])
  assert_false(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_false(
    instrs.to_string().contains("i32.const I32(0)"),
    msg=instrs.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-one-arm-merge-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge LocalGraph preserves one-arm parameter-entry merge canonical" {
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    local.get 1
    #|    if
    #|      i32.const 9
    #|      local.set 0
    #|    end
    #|    local.get 0))
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected one-arm param-entry merge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::empty())
  @debug.assert_eq(ssa_test_local_set_indices(instrs), [0U])
  @debug.assert_eq(ssa_nomerge_test_local_get_indices(instrs), [1U, 0U])
  assert_false(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-one-arm-merge-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge LocalGraph preserves both-arm body-local merge canonical" {
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    if
    #|      i32.const 7
    #|      local.set 1
    #|    else
    #|      i32.const 8
    #|      local.set 1
    #|    end
    #|    local.get 1))
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected both-arm body-local merge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(ssa_test_local_set_indices(instrs), [1U, 1U])
  @debug.assert_eq(ssa_nomerge_test_local_get_indices(instrs), [0U, 1U])
  assert_false(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-multisource-merge-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge LocalGraph preserves br_if body-local merge canonical" {
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 1
    #|    local.set 1
    #|    block
    #|      local.get 0
    #|      br_if 0
    #|      i32.const 2
    #|      local.set 1
    #|    end
    #|    local.get 1))
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected br_if body-local merge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(ssa_test_local_set_indices(instrs), [1U, 1U])
  @debug.assert_eq(ssa_nomerge_test_local_get_indices(instrs), [0U, 1U])
  assert_false(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-multisource-merge-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge LocalGraph freshens ordinary structured set writes" {
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    if
    #|      i32.const 10
    #|      local.set 1
    #|      local.get 1
    #|      drop
    #|      i32.const 11
    #|      local.set 1
    #|      local.get 1
    #|      drop
    #|    end
    #|    i32.const 0))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected ordinary structured set success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(ssa_test_local_set_indices(instrs), [2U, 3U])
  @debug.assert_eq(ssa_nomerge_test_local_get_indices(instrs), [0U, 2U, 3U])
  assert_false(
    ssa_test_has_ssa_temp_local_writes(instrs, 3U),
    msg=instrs.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge LocalGraph freshens ordinary nested block set writes" {
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    block
    #|      block
    #|        i32.const 10
    #|        local.set 1
    #|        local.get 1
    #|        drop
    #|        i32.const 11
    #|        local.set 1
    #|        local.get 1
    #|        drop
    #|      end
    #|    end
    #|    i32.const 0))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected ordinary nested block set success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(ssa_test_local_set_indices(instrs), [2U, 3U])
  @debug.assert_eq(ssa_nomerge_test_local_get_indices(instrs), [2U, 3U])
  assert_false(
    ssa_test_has_ssa_temp_local_writes(instrs, 3U),
    msg=instrs.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge preserves post-if merge read after condition tee" {
  // Reduced from debug-WASI `tlsf/insertBlock` (defined=2 abs=29): the
  // condition tee's value is no longer the right value after the taken arm
  // reloads the same local. The post-if read must stay canonical instead of
  // retargeting to the pre-branch fresh temp.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (memory 1)
    #|  (func (param i32) (result i32) (local i32 i32 i32)
    #|    local.get 0
    #|    local.tee 2
    #|    i32.load
    #|    local.tee 1
    #|    i32.const 1
    #|    i32.and
    #|    if
    #|      local.get 2
    #|      call $side
    #|      local.get 0
    #|      local.get 3
    #|      i32.const 4
    #|      i32.add
    #|      local.get 1
    #|      i32.const -4
    #|      i32.and
    #|      i32.add
    #|      local.tee 3
    #|      i32.store
    #|      local.get 2
    #|      i32.load
    #|      local.set 1
    #|    end
    #|    local.get 1)
    #|  (func $side (param i32)))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected post-if merge read pipeline success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let gets = ssa_nomerge_test_local_get_indices(instrs)

  @debug.assert_eq(gets[gets.length() - 1], 1U, msg=trace.join("\n"))
}

///|
test "ssa-nomerge preserves branch reload merge carrier used by suffix store" {
  // Reduced from the remaining debug-WASI `tlsf/insertBlock` (defined=2
  // abs=29) first diff after the initial stale-read fix. A no-else branch
  // reloads the same local that a later suffix store consumes. Freshening the
  // branch-local set leaves the suffix store reading the stale pre-branch tee
  // on the taken path.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (memory 1)
    #|  (func (param i32 i32) (local i32 i32 i32)
    #|    local.get 1
    #|    i32.load
    #|    local.tee 4
    #|    i32.const 1
    #|    i32.and
    #|    if
    #|      local.get 0
    #|      call $side
    #|      local.get 1
    #|      i32.load
    #|      local.set 4
    #|    end
    #|    local.get 3
    #|    if
    #|      local.get 0
    #|      call $side
    #|    end
    #|    local.get 2
    #|    local.get 4
    #|    i32.const 2
    #|    i32.or
    #|    i32.store)
    #|  (func $side (param i32)))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected branch reload merge-carrier pipeline success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let writes = ssa_test_local_write_indices(instrs)

  assert_true(
    writes.contains(4U),
    msg=trace.join("\n") + "\n" + instrs.to_string(),
  )
  assert_false(
    writes.any(fn(idx) { idx > 4U }),
    msg=trace.join("\n") + "\n" + instrs.to_string(),
  )
}

///|
test "ssa-nomerge preserves loop-carried decrement before backedge" {
  // Reduced from debug-WASI `abs=59`: a helper decrements a loop counter and
  // branches back to the loop. The next iteration's loop condition must see the
  // decremented canonical local, not a fresh scratch local.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (memory 1)
    #|  (func (param externref) (result i32) (local i32 i32 i32)
    #|    i32.const 3
    #|    local.set 1
    #|    loop
    #|      local.get 1
    #|      i32.const 0
    #|      i32.gt_s
    #|      if
    #|        local.get 1
    #|        i32.const 1
    #|        i32.sub
    #|        local.set 1
    #|        i32.const 8
    #|        call $make
    #|        local.tee 2
    #|        local.get 1
    #|        i32.store
    #|        br 1
    #|      end
    #|    end
    #|    i32.const 4
    #|    call $done
    #|    drop
    #|    local.get 1)
    #|  (func $make (param i32) (result i32) (i32.const 0))
    #|  (func $done (param i32) (result i32) (i32.const 0)))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected loop-carried decrement pipeline success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let sets = ssa_test_local_set_indices(instrs)

  assert_true(
    sets.contains(1U),
    msg=trace.join("\n") + "\n" + instrs.to_string(),
  )
  assert_false(
    sets.any(fn(idx) { idx > 3U }),
    msg=trace.join("\n") + "\n" + instrs.to_string(),
  )
}

///|
test "ssa-nomerge preserves table-growth loop counter before backedge" {
  // Closer reduction of debug-WASI `defined=32 abs=59`. The table-growth arm
  // computes a loop counter, decrements it inside the loop, stores it, and
  // branches back. If the decrement is freshened while the loop condition keeps
  // reading the pre-loop counter, the loop-carried value is stale.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (table 1 externref)
    #|  (global $free (mut i32) (i32.const -1))
    #|  (memory 1)
    #|  (func (param externref) (result i32) (local i32 i32 i32 i32 i32 i32 i32)
    #|    global.get $free
    #|    local.tee 1
    #|    i32.const 0
    #|    i32.lt_s
    #|    if
    #|      table.size
    #|      local.set 6
    #|      local.get 6
    #|      i32.eqz
    #|      if (result i32)
    #|        i32.const 16
    #|      else
    #|        local.get 6
    #|        i32.const 1
    #|        i32.shl
    #|      end
    #|      local.set 5
    #|      ref.null noextern
    #|      local.get 5
    #|      table.grow
    #|      i32.const 0
    #|      i32.lt_s
    #|      if
    #|        unreachable
    #|      end
    #|      loop
    #|        local.get 5
    #|        local.get 6
    #|        i32.gt_s
    #|        if
    #|          local.get 5
    #|          i32.const 1
    #|          i32.sub
    #|          local.set 5
    #|          i32.const 8
    #|          call $alloc
    #|          local.tee 2
    #|          local.get 5
    #|          i32.store
    #|          local.get 2
    #|          local.get 1
    #|          i32.store offset=4
    #|          local.get 2
    #|          local.set 1
    #|          br 1
    #|        end
    #|      end
    #|    end
    #|    local.get 1
    #|    i32.load offset=4
    #|    global.set $free
    #|    local.get 1
    #|    i32.load
    #|    local.set 7
    #|    local.get 7
    #|    local.get 0
    #|    table.set
    #|    i32.const 4
    #|    call $alloc
    #|    local.tee 4
    #|    i32.const 3
    #|    i32.const 30
    #|    i32.shl
    #|    i32.store offset=4
    #|    local.get 4
    #|    local.get 7
    #|    i32.store offset=8
    #|    local.get 4)
    #|  (func $alloc (param i32) (result i32) (i32.const 0)))
    #|)
  let input = pass_test_module_from_wat(source)
  let hot = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let preserve_writes = ssa_nomerge_loop_carried_canonical_writes(hot)
  let mut preserved_counter_writes = 0
  for node_id = 0; node_id < @ir.hot_node_count(hot); node_id = node_id + 1 {
    if node_id < preserve_writes.length() && preserve_writes[node_id] {
      match @ir.hot_node_get(hot, node_id).op {
        @ir.HotOp::LocalSet | @ir.HotOp::LocalTee =>
          if @ir.hot_node_get(hot, node_id).imm0 == 5 {
            preserved_counter_writes = preserved_counter_writes + 1
          }
        _ => ()
      }
    }
  }
  assert_true(
    preserved_counter_writes >= 2,
    msg=preserved_counter_writes.to_string(),
  )

  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected table-growth loop-counter pipeline success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let sets = ssa_test_local_set_indices(instrs)

  let mut counter_sets = 0
  for idx in sets {
    if idx == 5U {
      counter_sets = counter_sets + 1
    }
  }
  assert_true(
    counter_sets >= 2,
    msg=trace.join("\n") + "\n" + instrs.to_string(),
  )
}

///|
test "ssa-nomerge LocalGraph freshens mixed structured non-merge writes" {
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 10
    #|    local.set 1
    #|    local.get 1
    #|    drop
    #|    local.get 0
    #|    if
    #|      i32.const 20
    #|      local.set 1
    #|    else
    #|      i32.const 30
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    drop
    #|    i32.const 40
    #|    local.set 1
    #|    local.get 1))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected mixed structured ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(ssa_test_local_set_indices(instrs), [2U, 1U, 1U, 3U])
  @debug.assert_eq(ssa_nomerge_test_local_get_indices(instrs), [2U, 0U, 1U, 3U])
  assert_false(
    ssa_test_has_ssa_temp_local_writes(instrs, 3U),
    msg=instrs.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-mixed-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge LocalGraph preserves merge sets between ordinary fresh sets" {
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    block
    #|      i32.const 10
    #|      local.set 1
    #|      local.get 1
    #|      drop
    #|      local.get 0
    #|      if
    #|        i32.const 20
    #|        local.set 1
    #|      else
    #|        i32.const 30
    #|        local.set 1
    #|      end
    #|      local.get 1
    #|      drop
    #|      block
    #|        i32.const 40
    #|        local.set 1
    #|        local.get 1
    #|        drop
    #|      end
    #|    end
    #|    local.get 1))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected mixed ordinary set success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(ssa_test_local_set_indices(instrs), [2U, 1U, 1U, 3U])
  @debug.assert_eq(ssa_nomerge_test_local_get_indices(instrs), [
    2U, 0U, 1U, 3U, 3U,
  ])
  assert_false(
    ssa_test_has_ssa_temp_local_writes(instrs, 3U),
    msg=instrs.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-mixed-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge LocalGraph freshens mixed structured tee writes" {
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    i32.const 10
    #|    i32.add
    #|    local.tee 1
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 0
    #|    if
    #|      i32.const 20
    #|      local.set 1
    #|    else
    #|      i32.const 30
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    drop
    #|    local.get 0
    #|    i32.const 40
    #|    i32.add
    #|    local.tee 1
    #|    local.get 1
    #|    i32.add))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected mixed structured tee success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(ssa_test_local_tee_indices(instrs), [2U, 3U])
  @debug.assert_eq(ssa_test_local_set_indices(instrs), [1U, 1U])
  @debug.assert_eq(ssa_nomerge_test_local_get_indices(instrs), [
    0U, 2U, 0U, 1U, 0U, 3U,
  ])
  assert_false(
    ssa_test_has_ssa_temp_local_writes(instrs, 3U),
    msg=instrs.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-mixed-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge LocalGraph freshens mixed br_if early-exit writes" {
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 10
    #|    local.set 1
    #|    local.get 1
    #|    drop
    #|    i32.const 15
    #|    local.set 1
    #|    block
    #|      local.get 0
    #|      br_if 0
    #|      i32.const 20
    #|      local.set 1
    #|    end
    #|    local.get 1))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected mixed br_if early-exit success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(ssa_test_local_set_indices(instrs), [2U, 1U, 1U])
  @debug.assert_eq(ssa_nomerge_test_local_get_indices(instrs), [2U, 0U, 1U])
  assert_true(ssa_test_instrs_have_br_if(instrs), msg=instrs.to_string())
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-mixed-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge keeps mixed plain br regions off LocalGraph path" {
  // Plain `br` exits remain fail-closed for this mixed-region slice: they can
  // interact with branch-alias/copy helper families and should not silently use
  // the planned mixed rewrite until those helpers are retired or narrowed.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 10
    #|    local.set 1
    #|    local.get 1
    #|    drop
    #|    block
    #|      local.get 0
    #|      if
    #|        i32.const 15
    #|        local.set 1
    #|        br 1
    #|      end
    #|      i32.const 20
    #|      local.set 1
    #|    end
    #|    local.get 1))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected mixed plain br boundary success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-mixed-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
  assert_true(ssa_test_instrs_have_br(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge keeps mixed br_table regions off LocalGraph path" {
  // `br_table` exits remain fail-closed for this mixed-region slice for the same
  // reason as plain `br`: table-target and branch-operand scratch helpers still
  // own these boundary shapes.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 10
    #|    local.set 1
    #|    local.get 1
    #|    drop
    #|    i32.const 15
    #|    local.set 1
    #|    block
    #|      block
    #|        local.get 0
    #|        br_table 0 1
    #|      end
    #|      i32.const 20
    #|      local.set 1
    #|    end
    #|    local.get 1))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected mixed br_table boundary success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-mixed-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
  assert_true(ssa_test_instrs_have_br_table(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge keeps ordinary plain br local-source regions off planned structured path" {
  // `[SSANM-006a3b]` classifies ordinary void `br` exits with only local-source
  // traffic as branch-helper territory for now. They must validate and preserve
  // the branch, but should not claim the ordinary planned LocalGraph path until
  // branch-alias ownership is narrowed.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 10
    #|    local.set 1
    #|    block
    #|      local.get 0
    #|      if
    #|        br 1
    #|      end
    #|      local.get 1
    #|      drop
    #|    end
    #|    local.get 1))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ordinary plain br local-source boundary success, got \{err}",
      )
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-localgraph-plan",
      ) ||
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-mixed-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
  assert_true(ssa_test_instrs_have_br(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge keeps ordinary br_if local-source regions off planned structured path" {
  // `[SSANM-006a3b]` keeps ordinary `br_if` exits without mixed merge traffic
  // outside the planned structured LocalGraph path. The already-supported
  // `br_if` families remain the mixed early-exit and simple loop-backedge cases.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 10
    #|    local.set 1
    #|    block
    #|      local.get 0
    #|      br_if 0
    #|      local.get 1
    #|      drop
    #|    end
    #|    local.get 1))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected ordinary br_if local-source boundary success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-localgraph-plan",
      ) ||
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-mixed-localgraph-plan",
      ) ||
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-loop-backedge-merge-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
  assert_true(ssa_test_instrs_have_br_if(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge keeps ordinary br_table local-source regions off planned structured path" {
  // `[SSANM-006a3c]` keeps ordinary table exits without typed/value operands
  // outside planned structured LocalGraph mutation. Table-target alias/scratch
  // helpers still own this boundary until branch-table lowering is narrowed.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 10
    #|    local.set 1
    #|    block
    #|      block
    #|        local.get 0
    #|        br_table 0 1
    #|      end
    #|      local.get 1
    #|      drop
    #|    end
    #|    local.get 1))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ordinary br_table local-source boundary success, got \{err}",
      )
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-localgraph-plan",
      ) ||
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-mixed-localgraph-plan",
      ) ||
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-multisource-merge-localgraph-plan",
      ) ||
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-loop-backedge-merge-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
  assert_true(ssa_test_instrs_have_br_table(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge keeps nested br_if to outer block off planned structured path" {
  // `[SSANM-006a3d2]` classifies nested normal branch targets that are not
  // the already-supported mixed early-exit or simple loop-backedge subset as
  // fail-closed from planned LocalGraph mutation. This intentionally preserves
  // the nested branch until branch-target alias ownership is narrowed.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 10
    #|    local.set 1
    #|    block
    #|      block
    #|        local.get 0
    #|        br_if 1
    #|        local.get 1
    #|        drop
    #|      end
    #|      local.get 1
    #|      drop
    #|    end
    #|    local.get 1))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested br_if local-source boundary success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-localgraph-plan",
      ) ||
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-mixed-localgraph-plan",
      ) ||
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-multisource-merge-localgraph-plan",
      ) ||
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-loop-backedge-merge-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
  assert_true(ssa_test_instrs_have_br_if(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge keeps nested loop-exit br_if off planned structured path" {
  // This is a nested normal-control boundary, not the simple direct void-loop
  // `br_if 0` canonical backedge admitted by `[SSANM-005b2]`. Keep it off
  // ordinary planned LocalGraph reasons until `[SSANM-007b]` / loop-target
  // lowering proves a narrower safe subset.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 10
    #|    local.set 1
    #|    block
    #|      loop
    #|        local.get 0
    #|        br_if 1
    #|        local.get 1
    #|        drop
    #|      end
    #|      local.get 1
    #|      drop
    #|    end
    #|    local.get 1))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested loop-exit br_if boundary success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-localgraph-plan",
      ) ||
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-mixed-localgraph-plan",
      ) ||
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-multisource-merge-localgraph-plan",
      ) ||
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-loop-backedge-merge-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
  assert_true(ssa_test_instrs_have_br_if(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge keeps plain br multi-source merges off LocalGraph path" {
  // `[SSANM-005b3]` deliberately classifies plain `br` multi-source merge
  // regions as branch-helper territory for now. They must validate, preserve the
  // branch, and avoid claiming the canonical-only or mixed LocalGraph paths until
  // branch-alias/copy ownership is narrowed.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 10
    #|    local.set 1
    #|    block
    #|      local.get 0
    #|      if
    #|        i32.const 20
    #|        local.set 1
    #|        br 1
    #|      end
    #|      i32.const 30
    #|      local.set 1
    #|    end
    #|    local.get 1))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected plain br multi-source boundary success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-multisource-merge-localgraph-plan",
      ) ||
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-mixed-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
  assert_true(ssa_test_instrs_have_br(instrs), msg=instrs.to_string())
}

///|
fn ssa_test_expect_value_branch_boundary_output(
  source : String,
  context : String,
) -> Array[@lib.Instruction] raise {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected value branch \{context} boundary success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected value branch \{context} boundary output to validate, got \{@validate.validation_error_message(err)}",
      )
  }
  ssa_test_assert_no_planned_structured_trace_reason(trace)
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  instrs
}

///|
test "ssa-nomerge keeps value br operands off LocalGraph path" {
  // `[SSANM-007b3a]` classifies value-carrying plain `br` as typed-control /
  // branch-operand territory. It must not silently claim the ordinary
  // LocalGraph structured paths until branch-operand ownership is narrowed.
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 10
    #|    local.set 1
    #|    block (result i32)
    #|      i32.const 20
    #|      local.set 1
    #|      local.get 1
    #|      br 0
    #|      i32.const 0
    #|    end
    #|    drop
    #|    local.get 1))
    #|)
  let instrs = try! ssa_test_expect_value_branch_boundary_output(
    source, "plain br operand",
  )
  assert_true(ssa_test_instrs_have_br(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge keeps value br_if operands off LocalGraph path" {
  // Conditional value branches carry a stack payload plus a condition. Keep
  // this ABI shape on the branch-operand boundary, not on ordinary
  // LocalGraph local-source mutation.
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 10
    #|    local.set 1
    #|    block (result i32)
    #|      i32.const 20
    #|      local.set 1
    #|      local.get 1
    #|      local.get 0
    #|      br_if 0
    #|    end
    #|    drop
    #|    local.get 1))
    #|)
  let instrs = try! ssa_test_expect_value_branch_boundary_output(
    source, "conditional br_if operand",
  )
  assert_true(ssa_test_instrs_have_br_if(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge keeps value br_table operands off LocalGraph path" {
  // `[SSANM-007b3b]` gives value-carrying table branches the same boundary
  // ownership as plain value `br`: selector/target ABI repair must not be
  // mistaken for ordinary LocalGraph no-merge local-source work.
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 10
    #|    local.set 1
    #|    block (result i32)
    #|      i32.const 20
    #|      local.set 1
    #|      local.get 1
    #|      local.get 0
    #|      br_table 0 0
    #|      i32.const 0
    #|    end
    #|    drop
    #|    local.get 1))
    #|)
  let instrs = try! ssa_test_expect_value_branch_boundary_output(
    source, "br_table operand",
  )
  assert_true(ssa_test_instrs_have_br_table(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge keeps mixed-target value br_table operands off LocalGraph path" {
  // A value-carrying table can target multiple result labels while also
  // consuming a selector. Keep this mixed-target table ABI outside planned
  // structured LocalGraph mutation until table scratch ownership is narrowed.
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 10
    #|    local.set 1
    #|    block (result i32)
    #|      block (result i32)
    #|        i32.const 20
    #|        local.set 1
    #|        local.get 1
    #|        local.get 0
    #|        br_table 0 1
    #|      end
    #|    end
    #|    drop
    #|    local.get 1))
    #|)
  let instrs = try! ssa_test_expect_value_branch_boundary_output(
    source, "mixed-target br_table operand",
  )
  assert_true(ssa_test_instrs_have_br_table(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge keeps br_table multi-source merges off LocalGraph path" {
  // `[SSANM-005b3]` keeps table exits with merge reads on the existing
  // table-target/branch-operand helper boundary. This is a deliberate
  // fail-closed classification, not a successful LocalGraph canonical merge.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 10
    #|    local.set 1
    #|    block
    #|      block
    #|        local.get 0
    #|        br_table 0 1
    #|      end
    #|      i32.const 20
    #|      local.set 1
    #|    end
    #|    local.get 1))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected br_table multi-source boundary success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-multisource-merge-localgraph-plan",
      ) ||
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-mixed-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
  assert_true(ssa_test_instrs_have_br_table(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge LocalGraph freshens nested mixed block if writes" {
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 10
    #|    local.set 1
    #|    local.get 1
    #|    drop
    #|    block
    #|      local.get 0
    #|      if
    #|        i32.const 20
    #|        local.set 1
    #|      else
    #|        block
    #|          i32.const 30
    #|          local.set 1
    #|        end
    #|      end
    #|    end
    #|    local.get 1
    #|    drop
    #|    i32.const 40
    #|    local.set 1
    #|    local.get 1))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected nested mixed block/if success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(ssa_test_local_set_indices(instrs), [2U, 1U, 1U, 3U])
  @debug.assert_eq(ssa_nomerge_test_local_get_indices(instrs), [2U, 0U, 1U, 3U])
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-mixed-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge keeps mixed loop regions off LocalGraph path" {
  // Loops are intentionally outside `[SSANM-005c3c]`; loop-carried and typed
  // loop boundary decisions remain owned by `[SSANM-006a]` / `[SSANM-007b]`.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 10
    #|    local.set 1
    #|    local.get 1
    #|    drop
    #|    loop
    #|      i32.const 20
    #|      local.set 1
    #|      local.get 0
    #|      br_if 0
    #|    end
    #|    local.get 1))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected mixed loop boundary success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-mixed-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
  assert_true(
    ssa_test_instrs_have_loop_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge keeps call result assigned when a later loop reads the local" {
  let source =
    #|(module
    #|  (func $to_string (param i32) (result i32)
    #|    local.get 0)
    #|  (func $add_string (param i32 i32) (result i32)
    #|    local.get 1)
    #|  (func $decref (param i32))
    #|  (func $iter (param i32) (result i32)
    #|    local.get 0)
    #|  (func $next (param i32) (result i32)
    #|    local.get 0)
    #|  (func $write_char (param i32 i32))
    #|  (func (param i32 i32 i32) (result i32)
    #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|    local.get 1
    #|    call $to_string
    #|    local.set 14
    #|    local.get 14
    #|    call $decref
    #|    local.get 12
    #|    call $decref
    #|    i32.const 21800
    #|    local.get 14
    #|    call $add_string
    #|    i32.const 21776
    #|    call $add_string
    #|    local.set 16
    #|    local.get 2
    #|    call $to_string
    #|    local.set 17
    #|    local.get 17
    #|    call $decref
    #|    local.get 16
    #|    call $decref
    #|    local.get 9
    #|    call $decref
    #|    local.get 16
    #|    local.get 17
    #|    call $add_string
    #|    i32.const 12080
    #|    call $add_string
    #|    call $iter
    #|    local.set 3
    #|    loop
    #|      block (result i32)
    #|        block
    #|          local.get 3
    #|          call $next
    #|          local.tee 5
    #|          i32.const -1
    #|          i32.eq
    #|          if
    #|            local.get 0
    #|            call $decref
    #|            local.get 3
    #|            call $decref
    #|          else
    #|            local.get 5
    #|            local.set 4
    #|            br 1
    #|          end
    #|          i32.const 0
    #|          br 1
    #|        end
    #|        local.get 0
    #|        local.get 4
    #|        call $write_char
    #|        br 1
    #|      end
    #|      drop
    #|    end
    #|    i32.const 0))
    #|)
  let optimized = match pass_test_run_pipeline(source, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected call-result loop ssa-nomerge success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_defined_func(optimized, 6)
  assert_false(
    ssa_test_has_adjacent_call_drop(instrs, 3U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge keeps the latest straight-line local alias live" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result f64) (local f64) f64.const 69 local.tee 0 drop f64.const 39 local.tee 0 drop local.get 0))",
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected straight-line alias replay success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::f64(),
      @lib.ValType::f64(),
      @lib.ValType::f64(),
    ]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::f64_const(@lib.F64(69.0)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::f64_const(@lib.F64(39.0)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
  ])
}

///|
fn ssa_test_large_structured_branch_fixture() -> String {
  let out = StringBuilder::new()
  out.write_string("(module (func (local i32")
  for i = 0; i < 64; i = i + 1 {
    out.write_string(" i32")
  }
  out.write_string(") block i32.const 0 br 0 end i32.const 1 local.set 64))")
  out.to_string()
}

///|
fn ssa_test_assert_raw_structured_rewrite_added_alias_local(
  optimized : @lib.Module,
  original_local_count : Int,
  context : String,
) -> Unit raise {
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(
    locals.length() > original_local_count,
    msg="expected \{context} to add an SSA alias local; locals=\{locals}",
  )
  assert_true(instrs.to_string().contains("local.set"), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites moderately large structured branch functions without hot fallback" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      ssa_test_large_structured_branch_fixture(),
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected moderately large structured ssa-nomerge success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=large-structured-local-writes",
      )
    }),
    msg=trace.join("\n"),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  ssa_test_assert_raw_structured_rewrite_added_alias_local(
    optimized, 65, "moderately large structured branch raw rewrite",
  )
}

///|
fn ssa_test_large_structured_local_write_fixture(if_count : Int) -> String {
  let out = StringBuilder::new()
  out.write_string("(module (func (local i32) ")
  for i = 0; i < if_count; i = i + 1 {
    out.write_string("i32.const 0 if nop else nop end ")
  }
  out.write_string("i32.const 1 local.set 0))")
  out.to_string()
}

///|
test "ssa-nomerge rewrites very large structured local-write functions without branches" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      ssa_test_large_structured_local_write_fixture(130),
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected large structured local-write ssa-nomerge rewrite success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=large-structured-local-writes",
      )
    }),
    msg=trace.join("\n"),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  ssa_test_assert_raw_structured_rewrite_added_alias_local(
    optimized, 1, "large no-branch raw rewrite",
  )
}

///|
test "ssa-nomerge keeps audited high-threshold structured local-write functions without branches on raw path" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      ssa_test_large_structured_local_write_fixture(2047),
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected audited high-threshold no-branch ssa-nomerge success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=large-structured-local-writes",
      )
    }),
    msg=trace.join("\n"),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("skip-invalid-lower") }),
    msg=trace.join("\n"),
  )
  ssa_test_assert_raw_structured_rewrite_added_alias_local(
    optimized, 1, "high-threshold no-branch raw rewrite",
  )
}

///|
test "ssa-nomerge rewrites larger no-branch structured functions without binaryen size limit" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      ssa_test_large_structured_local_write_fixture(2048),
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected above-threshold no-branch ssa-nomerge success, got \{err}")
  }
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=large-structured-local-writes",
      )
    }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("skip-invalid-lower") }),
    msg=trace.join("\n"),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  ssa_test_assert_raw_structured_rewrite_added_alias_local(
    optimized, 1, "above-threshold no-branch raw rewrite",
  )
}

///|
fn ssa_test_large_structured_branch_if_prefix_fixture(if_count : Int) -> String {
  let out = StringBuilder::new()
  out.write_string("(module (func (local i32) block i32.const 0 br 0 end ")
  for i = 0; i < if_count; i = i + 1 {
    out.write_string("i32.const 0 if nop else nop end ")
  }
  out.write_string("i32.const 1 local.set 0))")
  out.to_string()
}

///|
test "ssa-nomerge keeps structured branch functions below raw instruction threshold on raw path" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      ssa_test_large_structured_branch_if_prefix_fixture(1020),
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected below-threshold structured branch ssa-nomerge success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=large-structured-local-writes",
      )
    }),
    msg=trace.join("\n"),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("skip-invalid-lower") }),
    msg=trace.join("\n"),
  )
  ssa_test_assert_raw_structured_rewrite_added_alias_local(
    optimized, 1, "below-threshold structured branch raw rewrite",
  )
}

///|
test "ssa-nomerge keeps audited high-threshold structured branch functions on raw path" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      ssa_test_large_structured_branch_if_prefix_fixture(2046),
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected audited high-threshold structured branch ssa-nomerge success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=large-structured-local-writes",
      )
    }),
    msg=trace.join("\n"),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("skip-invalid-lower") }),
    msg=trace.join("\n"),
  )
  ssa_test_assert_raw_structured_rewrite_added_alias_local(
    optimized, 1, "high-threshold structured branch raw rewrite",
  )
}

///|
test "ssa-nomerge rewrites larger structured branch functions without binaryen size limit" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      ssa_test_large_structured_branch_if_prefix_fixture(2047),
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected above-threshold structured branch ssa-nomerge success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=large-structured-local-writes",
      )
    }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("skip-invalid-lower") }),
    msg=trace.join("\n"),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  ssa_test_assert_raw_structured_rewrite_added_alias_local(
    optimized, 1, "above-threshold structured branch raw rewrite",
  )
}

///|
test "ssa-nomerge rewrites default local reads after branchy control without hot fallback" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) block i32.const 0 br_table 0 0 end local.get 0))",
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected branchy default-read rewrite success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.const I32(0)"), msg=text)
  assert_false(text.contains("local.get"), msg=text)
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=default-local-reads-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge keeps no-write unreachable debris cleanup separate from default plan" {
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func
    #|    (block (result i32)
    #|      unreachable
    #|      unreachable)
    #|    unreachable))
    #|)
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected unreachable-debris rewrite success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("unreachable"), msg=text)
  assert_false(text.contains("(block"), msg=text)
  assert_false(text.contains("Drop"), msg=text)
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=no-local-writes-unreachable-debris",
      )
    }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge locks straight-line writes off HOT fallback" {
  let set_output = try! ssa_nomerge_test_run_trace_locked_raw_exit(
    "(module (func (result i32) (local i32) i32.const 1 local.set 0 i32.const 2 local.set 0 local.get 0))",
    "straight-line-local-writes-localgraph-plan", "straight-line local.set fallback lock",
  )
  let (set_locals, set_instrs) = try! ssa_test_first_defined_func(set_output)
  @debug.assert_eq(
    set_locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(ssa_nomerge_test_local_get_indices(set_instrs), [2U])

  let tee_output = try! ssa_nomerge_test_run_trace_locked_raw_exit(
    "(module (func (result i32) (local i32) i32.const 1 local.tee 0 drop i32.const 2 local.tee 0 drop local.get 0))",
    "straight-line-local-writes-localgraph-plan", "straight-line local.tee fallback lock",
  )
  let (tee_locals, tee_instrs) = try! ssa_test_first_defined_func(tee_output)
  @debug.assert_eq(
    tee_locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(ssa_test_local_tee_indices(tee_instrs), [1U, 2U])
  @debug.assert_eq(ssa_nomerge_test_local_get_indices(tee_instrs), [2U])
}

///|
test "ssa-nomerge locks no-write default families off HOT fallback" {
  let plain_no_write = try! ssa_nomerge_test_run_trace_locked_raw_exit(
    "(module (func (result i32) i32.const 1))", "no-local-writes", "plain no-write fallback lock",
  )
  let (_, plain_instrs) = try! ssa_test_first_defined_func(plain_no_write)
  @debug.assert_eq(plain_instrs, [@lib.Instruction::i32_const(@lib.I32(1))])

  let default_output = try! ssa_nomerge_test_run_trace_locked_raw_exit(
    "(module (func (result i32) (local i32) block i32.const 0 br_table 0 0 end local.get 0))",
    "default-local-reads-localgraph-plan", "no-write default-read fallback lock",
  )
  let (_, default_instrs) = try! ssa_test_first_defined_func(default_output)
  let default_text = default_instrs.to_string()
  assert_true(default_text.contains("i32.const I32(0)"), msg=default_text)
  assert_false(default_text.contains("local.get"), msg=default_text)

  let debris_source =
    #|(module
    #|  (func
    #|    (block (result i32)
    #|      unreachable
    #|      unreachable)
    #|    unreachable))
    #|)
  let debris_output = try! ssa_nomerge_test_run_trace_locked_raw_exit(
    debris_source, "no-local-writes-unreachable-debris", "no-write unreachable-debris fallback lock",
  )
  let (_, debris_instrs) = try! ssa_test_first_defined_func(debris_output)
  let debris_text = debris_instrs.to_string()
  assert_true(debris_text.contains("unreachable"), msg=debris_text)
  assert_false(debris_text.contains("(block"), msg=debris_text)
  assert_false(debris_text.contains("Drop"), msg=debris_text)
}

///|
test "ssa-nomerge default ref replacement preserves exact nullable subtype under parent block" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $child (sub $base (struct)))
    #|  (func (result (ref null $base))
    #|    (local (ref null (exact $child)))
    #|    (block (result (ref null $base))
    #|      local.get 0)))
  let optimized = match pass_test_run_pipeline(source, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected exact default-ref replacement success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  ssa_test_assert_no_local_gets(
    instrs, "exact nullable default-ref replacement should remove body-local read",
  )
  ssa_test_assert_default_read_replaced_with_ref_null(
    instrs,
    @lib.RefType::new(
      true,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
    "exact nullable subtype default should keep the child exact ref.null type",
  )
}

///|
test "ssa-nomerge default ref replacement validates struct.get parent type repair" {
  let source =
    #|(module
    #|  (type $box (sub (struct (field i32))))
    #|  (func (result i32)
    #|    (local (ref null (exact $box)))
    #|    local.get 0
    #|    ref.as_non_null
    #|    struct.get $box 0))
  let optimized = match pass_test_run_pipeline(source, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected struct.get default-ref replacement success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  ssa_test_assert_no_local_gets(
    instrs, "struct.get parent repair fixture should remove body-local read",
  )
  ssa_test_assert_default_read_replaced_with_ref_null(
    instrs,
    @lib.RefType::new(
      true,
      @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      exact=true,
    ),
    "struct aggregate default should keep the exact ref.null payload",
  )
}

///|
test "ssa-nomerge default ref replacement validates array.get parent type repair" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([array_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([
            @lib.ValType::ref_array_nullable(array_type_idx),
          ]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::array_get(array_type_idx),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected array.get default-ref replacement success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  ssa_test_assert_no_local_gets(
    instrs, "array.get parent repair fixture should remove body-local read",
  )
  ssa_test_assert_default_read_replaced_with_ref_null(
    instrs,
    @lib.RefType::new(true, @lib.HeapType::new(array_type_idx), exact=false),
    "array aggregate default should keep the array ref.null payload",
  )
}

///|
test "ssa-nomerge removes dropped unreachable debris before a following unreachable" {
  let source =
    #|(module
    #|  (func
    #|    (block (result i32)
    #|      unreachable
    #|      unreachable)
    #|    unreachable))
    #|)
  let optimized = match pass_test_run_pipeline(source, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected unreachable-debris rewrite success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("unreachable"), msg=text)
  assert_false(text.contains("(block"), msg=text)
  assert_false(text.contains("Drop"), msg=text)
}

///|
test "ssa-nomerge rewrites dead param sets through fresh locals" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i64) (result i32) i64.const 756 local.set 0 i32.const 700))",
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected dead param set rewrite success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i64()]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::i64_const(@lib.I64(756L)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(700)),
  ])
}

///|
test "ssa-nomerge rewrites dead param tees through fresh locals" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param f64) (result f32) f64.const 17 local.tee 0 drop f32.const 92))",
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected dead param tee rewrite success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::f64()]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::f64_const(@lib.F64(17.0)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::f32_const(@lib.F32::new(92.0)),
  ])
}

///|
test "ssa-nomerge keeps structured param writes on the canonical slot" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     i32.const 0
    #|     if
    #|       nop
    #|     else
    #|       nop
    #|     end
    #|     i32.const 1
    #|     if
    #|       nop
    #|     else
    #|       nop
    #|     end
    #|     i32.const 819
    #|     local.tee 0
    #|     drop
    #|     local.get 0))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected structured param slot reuse success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::nop()],
      Some([@lib.Instruction::nop()]),
    ),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::nop()],
      Some([@lib.Instruction::nop()]),
    ),
    @lib.Instruction::i32_const(@lib.I32(819)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
}

///|
test "ssa-nomerge LocalGraph freshens body-local writes before next read" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     local.get 0
    #|     if
    #|       i32.const 1
    #|       local.set 1
    #|       local.get 1
    #|       drop
    #|     end
    #|     i32.const 2
    #|     local.set 1
    #|     local.get 1))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected body-local canonical rewrite success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(ssa_test_local_set_indices(instrs), [2U, 3U])
  @debug.assert_eq(ssa_nomerge_test_local_get_indices(instrs), [0U, 2U, 3U])
}

///|
test "ssa-nomerge keeps nested structured param write canonical before next read" {
  let input =
    #| (module
    #|   (func (param i32) (param i32) (result i32)
    #|     (local i32)
    #|     local.get 1
    #|     i32.const 256
    #|     i32.lt_u
    #|     if (result i32)
    #|       local.get 1
    #|       i32.const 4
    #|       i32.shr_u
    #|       local.set 1
    #|       i32.const 0
    #|     else
    #|       local.get 1
    #|       i32.const 536870910
    #|       i32.lt_u
    #|       if
    #|         local.get 1
    #|         i32.const 1
    #|         i32.add
    #|         local.set 1
    #|       end
    #|       i32.const 31
    #|       local.get 1
    #|       i32.clz
    #|       i32.sub
    #|       local.set 2
    #|       local.get 1
    #|       local.get 2
    #|       i32.const 4
    #|       i32.sub
    #|       i32.shr_u
    #|       i32.const 16
    #|       i32.xor
    #|       local.set 1
    #|       local.get 2
    #|       i32.const 7
    #|       i32.sub
    #|     end
    #|     local.get 1
    #|     i32.add))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested structured param rewrite success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(instrs.to_string().contains("Local 3"), false)
}

///|
test "ssa-nomerge avoids canonical copies for block-exit locals not read later" {
  let input =
    #| (module
    #|   (func (result i32)
    #|     (local i32 i32)
    #|     block
    #|       i32.const 7
    #|       local.set 0
    #|       br 0
    #|     end
    #|     i32.const 1))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected unneeded block-exit rewrite success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_false(text.contains("i32.const I32(0)"), msg=text)
  assert_false(text.contains("local.set (Local 0)"), msg=text)
}

///|
test "ssa-nomerge avoids default merge copies for branch locals not read later" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32 i32 i32)
    #|     local.get 0
    #|     if (result i32)
    #|       i32.const 10
    #|       local.set 1
    #|       i32.const 1
    #|     else
    #|       local.get 0
    #|       i32.const 2
    #|       i32.eq
    #|       if (result i32)
    #|         i32.const 20
    #|         local.set 2
    #|         i32.const 2
    #|       else
    #|         i32.const 30
    #|         local.set 3
    #|         i32.const 3
    #|       end
    #|     end))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected unneeded branch-local rewrite success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_false(text.contains("i32.const I32(0)"), msg=text)
  assert_false(text.contains("Local 7"), msg=text)
}

///|
test "ssa-nomerge rewrites func4302-style returning carriers without suspicious skip" {
  let trace : Array[String] = []
  let input =
    #| (module
    #|   (func $dec (param i32))
    #|   (func $len (param i32) (result i32) local.get 0)
    #|   (func (param i64 i32) (result i32)
    #|     (local i32 i32)
    #|     (block
    #|       (if (result i32) (i64.eq (local.get 0) (i64.const 4294967296))
    #|         (then
    #|           (if (local.get 1) (then (call $dec (local.get 1))))
    #|           (i32.const 0))
    #|         (else
    #|           (local.set 2 (i32.wrap_i64 (local.get 0)))
    #|           (br 1)))
    #|       return)
    #|     (local.set 3
    #|       (block (result i32)
    #|         (block
    #|           (if (result i32) (i32.eqz (local.get 1))
    #|             (then
    #|               (if (local.get 1) (then (call $dec (local.get 1))))
    #|               (if (result i32) (i32.eqz (local.get 2))
    #|                 (then (i32.const 0))
    #|                 (else (return (i32.const 4)))))
    #|             (else
    #|               (local.set 2 (local.get 1))
    #|               (br 1)))
    #|           (br 1))
    #|         (call $len (local.get 2))))
    #|     (i32.eq (local.get 2) (local.get 3))))
    #|
  match
    pass_test_run_pipeline(
      input,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected func4302-style ssa-nomerge success, got \{err}")
  }
  assert_false(
    trace.any(fn(line) { line.contains("skip-invalid-lower") }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge keeps branch joins canonical when the next read is safe" {
  let input =
    #| (module
    #|   (func (result i32)
    #|     (local i32)
    #|     i32.const 1
    #|     local.set 0
    #|     i32.const 1
    #|     if
    #|       i32.const 7
    #|       local.set 0
    #|     else
    #|       nop
    #|     end
    #|     local.get 0))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected branch-join ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      ],
      Some([@lib.Instruction::nop()]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
}

///|
test "ssa-nomerge LocalGraph preserves decorated loop-carried br_if merge canonical" {
  // `[SSANM-006b2c]` reduced an ordinary loop-carried candidate that the
  // original direct-void-loop gate rejected only because the loop body contains
  // branch-free structured decoration before the backedge. This is still
  // canonical no-merge work: preserve the original local and do not fall through
  // to lifted HOT SSA destruction / predecessor copies.
  let trace : Array[String] = []
  let input =
    #| (module
    #|   (func (result i32)
    #|     (local i32)
    #|     i32.const 1
    #|     local.set 0
    #|     loop
    #|       local.get 0
    #|       drop
    #|       i32.const 2
    #|       local.set 0
    #|       block
    #|         local.get 0
    #|         drop
    #|       end
    #|       i32.const 1
    #|       br_if 0
    #|     end
    #|     local.get 0))
    #|
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected decorated loop-carried br_if merge success, got \{err}")
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(ssa_test_local_set_indices(instrs), [0U, 0U])
  @debug.assert_eq(ssa_nomerge_test_local_get_indices(instrs), [0U, 0U, 0U])
  assert_false(
    ssa_test_has_ssa_temp_local_writes(instrs, 0U),
    msg=instrs.to_string(),
  )
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-loop-backedge-merge-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge rejects branchy decorated loop-backedge boundary reasons" {
  // `[SSANM-006b2c3a]` locks the retained boundary after the decorated
  // loop-backedge positive: once a decoration block contains its own branch,
  // the shape is branch-helper territory, not the ordinary canonical-only
  // loop-backedge LocalGraph reroute. This is a fail-closed regression lock,
  // not a new mutation admission.
  let trace : Array[String] = []
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     i32.const 1
    #|     local.set 1
    #|     loop
    #|       local.get 1
    #|       drop
    #|       i32.const 2
    #|       local.set 1
    #|       block
    #|         local.get 0
    #|         br_if 0
    #|         local.get 1
    #|         drop
    #|       end
    #|       i32.const 1
    #|       br_if 0
    #|     end
    #|     local.get 1))
    #|
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected branchy decorated loop-backedge boundary success, got \{err}",
      )
  }
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  ssa_test_assert_no_planned_structured_trace_reason(trace)
  ssa_test_assert_no_ssa_nomerge_mutation_trace(trace)
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-loop-backedge-boundary-noop",
      )
    }),
    msg=trace.join("\n"),
  )
  assert_true(ssa_test_instrs_have_br_if(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rejects table decorated loop-backedge boundary reasons" {
  // `[SSANM-006b2c3a]` keeps `br_table` decoration outside the ordinary
  // loop-backedge LocalGraph reroute because table-target repair remains an
  // explicit boundary helper. The pass should validate and preserve the table
  // branch without claiming a planned structured LocalGraph reason.
  let trace : Array[String] = []
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     i32.const 1
    #|     local.set 1
    #|     loop
    #|       local.get 1
    #|       drop
    #|       i32.const 2
    #|       local.set 1
    #|       block
    #|         block
    #|           local.get 0
    #|           br_table 0 1
    #|         end
    #|         local.get 1
    #|         drop
    #|       end
    #|       i32.const 1
    #|       br_if 0
    #|     end
    #|     local.get 1))
    #|
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table decorated loop-backedge boundary success, got \{err}",
      )
  }
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  ssa_test_assert_no_planned_structured_trace_reason(trace)
  ssa_test_assert_no_ssa_nomerge_mutation_trace(trace)
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-loop-backedge-boundary-noop",
      )
    }),
    msg=trace.join("\n"),
  )
  assert_true(ssa_test_instrs_have_br_table(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge LocalGraph preserves loop-carried br_if merge canonical" {
  let trace : Array[String] = []
  let input =
    #| (module
    #|   (func (result i32)
    #|     (local i32)
    #|     i32.const 1
    #|     local.set 0
    #|     block
    #|       loop
    #|         local.get 0
    #|         drop
    #|         i32.const 2
    #|         local.set 0
    #|         i32.const 1
    #|         br_if 0
    #|       end
    #|     end
    #|     local.get 0))
    #|
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected loop-carried br_if merge success, got \{err}")
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(ssa_test_local_set_indices(instrs), [0U, 0U])
  @debug.assert_eq(ssa_nomerge_test_local_get_indices(instrs), [0U, 0U])
  assert_false(
    ssa_test_has_ssa_temp_local_writes(instrs, 0U),
    msg=instrs.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=structured-loop-backedge-merge-localgraph-plan",
      )
    }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge skips synthetic entry copies for root loop headers" {
  let input =
    #| (module
    #|   (func (param i32)
    #|     (local i32)
    #|     loop
    #|       local.get 1
    #|       local.get 0
    #|       i32.lt_s
    #|       if
    #|         local.get 1
    #|         i32.const 1
    #|         i32.add
    #|         local.set 1
    #|         br 1
    #|       end
    #|     end))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected root-loop ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_lt_s(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ],
          None,
        ),
      ]),
    ),
  ])
}

///|
test "ssa-nomerge rewrites structured early-return local traffic without hot lift" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     local.get 0
    #|     if
    #|       i32.const 7
    #|       local.set 1
    #|       local.get 1
    #|       return
    #|     else
    #|       i32.const 9
    #|       local.set 1
    #|     end
    #|     local.get 1))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected structured raw ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::return_(),
      ],
      Some([
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ])
}

///|
test "ssa-nomerge keeps body-local tees canonical before branch continuation read" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     block
    #|       i32.const 7
    #|       local.tee 1
    #|       drop
    #|       br 0
    #|     end
    #|     local.get 1))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected branch-continuation tee rewrite success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  assert_false(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge keeps result-branch tees canonical before continuation read" {
  let input =
    #| (module
    #|   (func (result i32)
    #|     (local i32)
    #|     block (result i32)
    #|       i32.const 7
    #|       local.tee 0
    #|       br 0
    #|     end
    #|     local.get 0
    #|     i32.add))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected result-branch tee rewrite success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  assert_false(
    ssa_test_has_ssa_temp_local_writes(instrs, 0U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites block-target branches through canonical locals" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     i32.const 0
    #|     local.set 1
    #|     block
    #|       local.get 0
    #|       if
    #|         i32.const 7
    #|         local.set 1
    #|         br 1
    #|       end
    #|       i32.const 9
    #|       local.set 1
    #|     end
    #|     local.get 1))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected block-target raw ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ],
          None,
        ),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ])
}

///|
test "ssa-nomerge redirects enclosing label copies after divergent branch aliases" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     block
    #|       local.get 0
    #|       if
    #|         i32.const 7
    #|         local.set 1
    #|       else
    #|         i32.const 8
    #|         local.set 1
    #|       end
    #|       block
    #|         br 1
    #|       end
    #|       i32.const 9
    #|       local.set 1
    #|     end
    #|     local.get 1))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected enclosing-label copy rewrite success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
          ],
          Some([
            @lib.Instruction::i32_const(@lib.I32(8)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
          ]),
        ),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(1U))]),
        ),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ])
}

///|
test "ssa-nomerge preserves no-copy block-target br_if" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     i32.const 7
    #|     local.set 1
    #|     block
    #|       local.get 0
    #|       br_if 0
    #|       i32.const 9
    #|       local.set 1
    #|     end
    #|     local.get 1))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected block-target br_if raw ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ])
}

///|
test "ssa-nomerge preserves no-copy br_on_non_null on raw path" {
  let trace : Array[String] = []
  let ref_type = @lib.ValType::ref_null(
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
  )
  let non_null_ref_type = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([ref_type], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(1U)]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(non_null_ref_type),
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32::new(7)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
              ]),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32::new(1)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected br_on_non_null raw ssa-nomerge success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected no-copy br_on_non_null boundary output to validate, got \{@validate.validation_error_message(err)}",
      )
  }
  ssa_test_assert_no_planned_structured_trace_reason(trace)

  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("hot-lift-error") }),
    msg=trace.join("\n"),
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_instrs_have_br_on_non_null(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge preserves no-copy br_on_cast on raw path" {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let any_ref_type = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let i31_ref_type = @lib.ValType::ref_type(@lib.RefType::new(false, i31_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([any_ref_type], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(i31_ref_type),
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32::new(7)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_cast(
                  @lib.LabelIdx::new(0U),
                  true,
                  any_heap,
                  false,
                  i31_heap,
                ),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(42)),
                @lib.Instruction::ref_i31(),
              ]),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32::new(1)),
          ]),
        ),
      ]),
    )
  let (_, instrs, trace) = try! ssa_test_expect_cast_branch_boundary_module_output(
    input, 0, "no-copy br_on_cast raw path",
  )
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_true(ssa_test_instrs_have_br_on_cast(instrs), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites br_on_cast taken-edge copies after divergent aliases" {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let any_ref_type = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let i31_ref_type = @lib.ValType::ref_type(@lib.RefType::new(false, i31_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([any_ref_type, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(i31_ref_type),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_cast(
                  @lib.LabelIdx::new(0U),
                  true,
                  any_heap,
                  false,
                  i31_heap,
                ),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(42)),
                @lib.Instruction::ref_i31(),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ]),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let (_, instrs, trace) = try! ssa_test_expect_cast_branch_boundary_module_output(
    input, 0, "br_on_cast taken-edge copies after divergent aliases",
  )
  assert_true(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
  assert_true(
    ssa_test_instrs_have_ref_cast_branch_copy_block(instrs, 2U, true),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites multi-result br_on_cast taken-edge copies" {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let any_ref_type = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let i31_ref_type = @lib.ValType::ref_type(@lib.RefType::new(false, i31_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([any_ref_type, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), i31_ref_type]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ]),
                ),
                @lib.Instruction::i32_const(@lib.I32::new(99)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_cast(
                  @lib.LabelIdx::new(0U),
                  true,
                  any_heap,
                  false,
                  i31_heap,
                ),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::i32_const(@lib.I32::new(42)),
                @lib.Instruction::ref_i31(),
              ]),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let (_, instrs, trace) = try! ssa_test_expect_cast_branch_boundary_module_output(
    input, 0, "multi-result br_on_cast taken-edge copies",
  )
  assert_true(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
  assert_true(
    ssa_test_instrs_have_ref_cast_branch_copy_block(instrs, 2U, true),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge does not mutate no-copy loop-target br_on_non_null with typed loop param" {
  let trace : Array[String] = []
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let non_null_any_ref_type = @lib.ValType::ref_type(
    @lib.RefType::new(false, any_heap),
  )
  let nullable_any_ref_type = @lib.ValType::ref_type(
    @lib.RefType::new(true, any_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([non_null_any_ref_type], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([non_null_any_ref_type, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), nullable_any_ref_type]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected loop-target br_on_non_null raw ssa-nomerge success, got \{err}",
      )
  }

  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("hot-lift-error") }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_non_null_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites copy-needing loop-target br_on_non_null with typed loop param" {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let non_null_any_ref_type = @lib.ValType::ref_type(
    @lib.RefType::new(false, any_heap),
  )
  let nullable_any_ref_type = @lib.ValType::ref_type(
    @lib.RefType::new(true, any_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([non_null_any_ref_type], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([non_null_any_ref_type, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), nullable_any_ref_type]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "copy-needing loop-target br_on_non_null with typed loop param",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_ref_non_null_branch_copy_lowering(instrs, 2U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge does not mutate no-copy loop-target br_on_cast with typed loop param" {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let any_ref_type = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([any_ref_type], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([any_ref_type, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_cast(
                  @lib.LabelIdx::new(0U),
                  true,
                  any_heap,
                  false,
                  i31_heap,
                ),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let (locals, instrs, trace) = try! ssa_test_expect_cast_branch_boundary_module_output(
    input, 0, "no-copy loop-target br_on_cast with typed loop param",
  )
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_cast_proxy(instrs, false),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites copy-needing loop-target br_on_cast with typed loop param" {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let any_ref_type = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([any_ref_type], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([any_ref_type, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_cast(
                  @lib.LabelIdx::new(0U),
                  true,
                  any_heap,
                  false,
                  i31_heap,
                ),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let (locals, instrs, trace) = try! ssa_test_expect_cast_branch_boundary_module_output(
    input, 0, "copy-needing loop-target br_on_cast with typed loop param",
  )
  assert_true(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_ref_cast_branch_copy_block(instrs, 2U, true),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge preserves no-copy br_on_cast_fail on raw path" {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let any_ref_type = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([any_ref_type], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(any_ref_type),
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32::new(7)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_cast_fail(
                  @lib.LabelIdx::new(0U),
                  true,
                  any_heap,
                  false,
                  i31_heap,
                ),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(any_heap),
              ]),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32::new(1)),
          ]),
        ),
      ]),
    )
  let (_, instrs, trace) = try! ssa_test_expect_cast_branch_boundary_module_output(
    input, 0, "no-copy br_on_cast_fail raw path",
  )
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_instrs_have_br_on_cast_fail(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites br_on_cast_fail taken-edge copies after divergent aliases" {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let any_ref_type = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([any_ref_type, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(any_ref_type),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_cast_fail(
                  @lib.LabelIdx::new(0U),
                  true,
                  any_heap,
                  false,
                  i31_heap,
                ),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(any_heap),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ]),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let (_, instrs, trace) = try! ssa_test_expect_cast_branch_boundary_module_output(
    input, 0, "br_on_cast_fail taken-edge copies after divergent aliases",
  )
  assert_true(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
  assert_true(
    ssa_test_instrs_have_ref_cast_branch_copy_block(instrs, 2U, false),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites multi-result br_on_cast_fail taken-edge copies" {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let any_ref_type = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([any_ref_type, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), any_ref_type]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ]),
                ),
                @lib.Instruction::i32_const(@lib.I32::new(99)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_cast_fail(
                  @lib.LabelIdx::new(0U),
                  true,
                  any_heap,
                  false,
                  i31_heap,
                ),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::i32_const(@lib.I32::new(42)),
                @lib.Instruction::ref_i31(),
              ]),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let (_, instrs, trace) = try! ssa_test_expect_cast_branch_boundary_module_output(
    input, 0, "multi-result br_on_cast_fail taken-edge copies",
  )
  assert_true(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
  assert_true(
    ssa_test_instrs_have_ref_cast_branch_copy_block(instrs, 2U, false),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge does not mutate no-copy loop-target br_on_cast_fail with typed loop param" {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let any_ref_type = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([any_ref_type], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([any_ref_type, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_cast_fail(
                  @lib.LabelIdx::new(0U),
                  true,
                  any_heap,
                  false,
                  i31_heap,
                ),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let (locals, instrs, trace) = try! ssa_test_expect_cast_branch_boundary_module_output(
    input, 0, "no-copy loop-target br_on_cast_fail with typed loop param",
  )
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_cast_proxy(instrs, true),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites copy-needing loop-target br_on_cast_fail with typed loop param" {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let any_ref_type = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([any_ref_type], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([any_ref_type, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_cast_fail(
                  @lib.LabelIdx::new(0U),
                  true,
                  any_heap,
                  false,
                  i31_heap,
                ),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let (locals, instrs, trace) = try! ssa_test_expect_cast_branch_boundary_module_output(
    input, 0, "copy-needing loop-target br_on_cast_fail with typed loop param",
  )
  assert_true(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_ref_cast_branch_copy_block(instrs, 2U, false),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites br_on_non_null taken-edge copies after divergent aliases" {
  let ref_type = @lib.ValType::ref_null(
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
  )
  let non_null_ref_type = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([ref_type, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(1U)]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(non_null_ref_type),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ]),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "br_on_non_null taken-edge copies after divergent aliases",
  )
  let (_, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(
    ssa_test_instrs_have_ref_non_null_branch_copy_lowering(instrs, 2U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites br_on_null taken-edge copies after divergent aliases" {
  let ref_type = @lib.ValType::ref_null(
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([ref_type, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "br_on_null taken-edge copies after divergent aliases",
  )
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(
    ssa_test_instrs_have_ref_null_branch_copy_lowering(instrs, 2U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites local-tee-tested br_on_null block-exit copies" {
  let struct_idx = @lib.TypeIdx::new(0U)
  let struct_heap = @lib.HeapType::new(struct_idx)
  let nullable_struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, struct_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([nullable_struct_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "local-tee-tested br_on_null block-exit copies",
  )
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(
    ssa_test_instrs_have_ref_null_branch_copy_lowering(instrs, 1U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites local-tee-tested br_on_non_null block-exit copies" {
  let struct_idx = @lib.TypeIdx::new(0U)
  let struct_heap = @lib.HeapType::new(struct_idx)
  let nullable_struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, struct_heap),
  )
  let non_null_struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, struct_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([nullable_struct_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(non_null_struct_ref),
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::struct_new_default(struct_idx),
              ]),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "local-tee-tested br_on_non_null block-exit copies",
  )
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(
    ssa_test_instrs_have_ref_non_null_branch_copy_lowering(instrs, 1U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites ref-i31-tested br_on_null block-exit copies" {
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::ref_i31(),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "ref-i31-tested br_on_null block-exit copies",
  )
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(
    ssa_test_instrs_have_ref_null_branch_copy_lowering(instrs, 1U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites ref-i31-tested br_on_non_null block-exit copies" {
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::i31ref()),
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::ref_i31(),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::ref_i31(),
              ]),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "ref-i31-tested br_on_non_null block-exit copies",
  )
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(
    ssa_test_instrs_have_ref_non_null_branch_copy_lowering(instrs, 1U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge preserves ref-i31-to-eq br_on_non_null block-exit copies" {
  let non_null_eq_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
  )
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(1U))
  block_body.append([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::ref_i31(),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(non_null_eq_ref),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 1U, true, "ref-i31-to-eq br_on_non_null block-exit copies",
  )
}

///|
test "ssa-nomerge preserves struct-child-to-parent br_on_non_null block-exit copies" {
  let parent_idx = @lib.TypeIdx::new(0U)
  let child_idx = @lib.TypeIdx::new(1U)
  let parent_heap = @lib.HeapType::new(parent_idx)
  let non_null_parent_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, parent_heap),
  )
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(0U))
  block_body.append([
    @lib.Instruction::struct_new_default(child_idx),
    @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::struct_new_default(parent_idx),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::new(false, [], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(false, [parent_idx], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(non_null_parent_ref),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          ]),
        ),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 0U, true, "struct-child-to-parent br_on_non_null block-exit copies",
  )
}

///|
test "ssa-nomerge preserves array-child-to-parent br_on_non_null block-exit copies" {
  let parent_idx = @lib.TypeIdx::new(0U)
  let child_idx = @lib.TypeIdx::new(1U)
  let parent_heap = @lib.HeapType::new(parent_idx)
  let array_field = @lib.FieldType::new(
    @lib.StorageType::val_type(@lib.ValType::i32()),
    @lib.Mut::var_(),
  )
  let non_null_parent_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, parent_heap),
  )
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(0U))
  block_body.append([
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::array_new_default(child_idx),
    @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::array_new_default(parent_idx),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::new(false, [], @lib.CompType::array(array_field)),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [parent_idx],
            @lib.CompType::array(array_field),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(non_null_parent_ref),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          ]),
        ),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 0U, true, "array-child-to-parent br_on_non_null block-exit copies",
  )
}

///|
test "ssa-nomerge preserves ref-func-child-to-parent br_on_non_null block-exit copies" {
  let parent_idx = @lib.TypeIdx::new(0U)
  let child_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let callee_idx = @lib.FuncIdx::new(1U)
  let parent_heap = @lib.HeapType::new(parent_idx)
  let non_null_parent_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, parent_heap),
  )
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(0U))
  block_body.append([
    @lib.Instruction::ref_func(callee_idx),
    @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::ref_func(callee_idx),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::new(false, [], @lib.CompType::func([], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(false, [parent_idx], @lib.CompType::func([], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx, child_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([callee_idx]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(non_null_parent_ref),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          ]),
        ),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 0U, true, "ref-func-child-to-parent br_on_non_null block-exit copies",
  )
}

///|
test "ssa-nomerge preserves ref-i31-to-eq br_on_null prefix block-exit copies" {
  let nullable_eq_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
  )
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(2U))
  block_body.append([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::ref_i31(),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), nullable_eq_ref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(nullable_eq_ref),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 2U, false, "ref-i31-to-eq br_on_null prefix block-exit copies",
  )
}

///|
test "ssa-nomerge preserves struct-child-to-parent br_on_null prefix block-exit copies" {
  let parent_idx = @lib.TypeIdx::new(0U)
  let child_idx = @lib.TypeIdx::new(1U)
  let parent_heap = @lib.HeapType::new(parent_idx)
  let nullable_eq_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
  )
  let nullable_parent_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, parent_heap),
  )
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(1U))
  block_body.append([
    @lib.Instruction::struct_new_default(child_idx),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::struct_new_default(parent_idx),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::new(false, [], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(false, [parent_idx], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([nullable_eq_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(nullable_parent_ref),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 1U, false, "struct-child-to-parent br_on_null prefix block-exit copies",
  )
}

///|
test "ssa-nomerge preserves array-child-to-parent br_on_null prefix block-exit copies" {
  let parent_idx = @lib.TypeIdx::new(0U)
  let child_idx = @lib.TypeIdx::new(1U)
  let parent_heap = @lib.HeapType::new(parent_idx)
  let array_field = @lib.FieldType::new(
    @lib.StorageType::val_type(@lib.ValType::i32()),
    @lib.Mut::var_(),
  )
  let nullable_eq_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
  )
  let nullable_parent_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, parent_heap),
  )
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(1U))
  block_body.append([
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::array_new_default(child_idx),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::array_new_default(parent_idx),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::new(false, [], @lib.CompType::array(array_field)),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [parent_idx],
            @lib.CompType::array(array_field),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([nullable_eq_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(nullable_parent_ref),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 1U, false, "array-child-to-parent br_on_null prefix block-exit copies",
  )
}

///|
test "ssa-nomerge preserves ref-func-child-to-parent br_on_null prefix block-exit copies" {
  let parent_idx = @lib.TypeIdx::new(0U)
  let child_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let callee_idx = @lib.FuncIdx::new(1U)
  let parent_heap = @lib.HeapType::new(parent_idx)
  let nullable_eq_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
  )
  let nullable_parent_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, parent_heap),
  )
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(1U))
  block_body.append([
    @lib.Instruction::ref_func(callee_idx),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::ref_func(callee_idx),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::new(false, [], @lib.CompType::func([], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(false, [parent_idx], @lib.CompType::func([], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([nullable_eq_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx, child_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([callee_idx]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(nullable_parent_ref),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 1U, false, "ref-func-child-to-parent br_on_null prefix block-exit copies",
  )
}

///|
test "ssa-nomerge rewrites struct-new-default-tested br_on_null block-exit copies" {
  let struct_idx = @lib.TypeIdx::new(0U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                  ]),
                ),
                @lib.Instruction::struct_new_default(struct_idx),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "struct-new-default-tested br_on_null block-exit copies",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_ref_null_branch_copy_lowering(instrs, 0U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites struct-new-default-tested br_on_non_null block-exit copies" {
  let struct_idx = @lib.TypeIdx::new(0U)
  let struct_heap = @lib.HeapType::new(struct_idx)
  let non_null_struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, struct_heap, exact=true),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(non_null_struct_ref),
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                  ]),
                ),
                @lib.Instruction::struct_new_default(struct_idx),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::struct_new_default(struct_idx),
              ]),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "struct-new-default-tested br_on_non_null block-exit copies",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_ref_non_null_branch_copy_lowering(instrs, 0U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge preserves array-new-default-tested br_on_null block-exit copies" {
  let array_idx = @lib.TypeIdx::new(0U)
  let array_field = @lib.FieldType::new(
    @lib.StorageType::val_type(@lib.ValType::i32()),
    @lib.Mut::var_(),
  )
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(0U))
  block_body.append([
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::array_new_default(array_idx),
    @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::array(array_field)),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          ]),
        ),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 0U, false, "array-new-default-tested br_on_null block-exit copies",
  )
}

///|
test "ssa-nomerge preserves array-new-default-tested br_on_non_null block-exit copies" {
  let array_idx = @lib.TypeIdx::new(0U)
  let array_field = @lib.FieldType::new(
    @lib.StorageType::val_type(@lib.ValType::i32()),
    @lib.Mut::var_(),
  )
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(0U))
  block_body.append([
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::array_new_default(array_idx),
    @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::array_new_default(array_idx),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::array(array_field)),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(
                @lib.ValType::ref_array_nonnull(array_idx),
              ),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          ]),
        ),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 0U, true, "array-new-default-tested br_on_non_null block-exit copies",
  )
}

///|
test "ssa-nomerge preserves ref-func-tested br_on_null block-exit copies" {
  let callee_type_idx = @lib.TypeIdx::new(0U)
  let test_type_idx = @lib.TypeIdx::new(1U)
  let callee_idx = @lib.FuncIdx::new(1U)
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(0U))
  block_body.append([
    @lib.Instruction::ref_func(callee_idx),
    @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx, callee_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([callee_idx]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          ]),
        ),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 0U, false, "ref-func-tested br_on_null block-exit copies",
  )
}

///|
test "ssa-nomerge preserves ref-func-tested br_on_non_null block-exit copies" {
  let callee_type_idx = @lib.TypeIdx::new(0U)
  let test_type_idx = @lib.TypeIdx::new(1U)
  let callee_idx = @lib.FuncIdx::new(1U)
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(0U))
  block_body.append([
    @lib.Instruction::ref_func(callee_idx),
    @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::ref_func(callee_idx),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx, callee_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([callee_idx]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::funcref()),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          ]),
        ),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 0U, true, "ref-func-tested br_on_non_null block-exit copies",
  )
}

///|
test "ssa-nomerge preserves ref-cast-tested br_on_null block-exit copies" {
  let struct_idx = @lib.TypeIdx::new(0U)
  let struct_heap = @lib.HeapType::new(struct_idx)
  let nullable_struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, struct_heap),
  )
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(1U))
  block_body.append([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::ref_cast(true, struct_heap),
    @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([nullable_struct_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 1U, false, "ref-cast-tested br_on_null block-exit copies",
  )
}

///|
test "ssa-nomerge preserves ref-cast-tested br_on_non_null block-exit copies" {
  let struct_idx = @lib.TypeIdx::new(0U)
  let struct_heap = @lib.HeapType::new(struct_idx)
  let nullable_struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, struct_heap),
  )
  let non_null_struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, struct_heap),
  )
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(1U))
  block_body.append([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::ref_cast(true, struct_heap),
    @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::struct_new_default(struct_idx),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([nullable_struct_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(non_null_struct_ref),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 1U, true, "ref-cast-tested br_on_non_null block-exit copies",
  )
}

///|
test "ssa-nomerge preserves any-convert-tested br_on_null block-exit copies" {
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(1U))
  block_body.append([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::any_convert_extern(),
    @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::externref()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 1U, false, "any-convert-tested br_on_null block-exit copies",
  )
}

///|
test "ssa-nomerge preserves any-convert-tested br_on_non_null block-exit copies" {
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(1U))
  block_body.append([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::any_convert_extern(),
    @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::any_convert_extern(),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::externref()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::anyref()),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 1U, true, "any-convert-tested br_on_non_null block-exit copies",
  )
}

///|
test "ssa-nomerge preserves extern-convert-tested br_on_null block-exit copies" {
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(1U))
  block_body.append([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::extern_convert_any(),
    @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::anyref()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 1U, false, "extern-convert-tested br_on_null block-exit copies",
  )
}

///|
test "ssa-nomerge preserves extern-convert-tested br_on_non_null block-exit copies" {
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(1U))
  block_body.append([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::extern_convert_any(),
    @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::extern_convert_any(),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::anyref()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::externref()),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 1U, true, "extern-convert-tested br_on_non_null block-exit copies",
  )
}

///|
test "ssa-nomerge does not mutate no-copy block-target br_table on raw path" {
  let trace : Array[String] = []
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     block
    #|       i32.const 7
    #|       local.set 1
    #|       local.get 0
    #|       br_table 0 0
    #|     end
    #|     i32.const 1))
    #|
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected no-copy br_table raw ssa-nomerge success, got \{err}")
  }

  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::br_table(
          [@lib.LabelIdx::new(0U)],
          @lib.LabelIdx::new(0U),
        ),
      ]),
    ),
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "ssa-nomerge does not mutate no-copy loop-target br_if on raw path" {
  let trace : Array[String] = []
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     loop
    #|       i32.const 7
    #|       local.set 1
    #|       local.get 0
    #|       br_if 0
    #|     end
    #|     i32.const 1))
    #|
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected loop br_if raw ssa-nomerge success, got \{err}")
  }

  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
      ]),
    ),
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "ssa-nomerge does not mutate no-copy loop-target br_table on raw path" {
  let trace : Array[String] = []
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     loop
    #|       i32.const 7
    #|       local.set 1
    #|       local.get 0
    #|       br_table 0 0
    #|     end
    #|     i32.const 1))
    #|
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected loop br_table raw ssa-nomerge success, got \{err}")
  }

  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::br_table(
          [@lib.LabelIdx::new(0U)],
          @lib.LabelIdx::new(0U),
        ),
      ]),
    ),
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "ssa-nomerge rewrites loop-carried reads for br_table backedges" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     loop
    #|       local.get 1
    #|       drop
    #|       i32.const 7
    #|       local.set 1
    #|       local.get 0
    #|       br_table 0 0
    #|     end
    #|     i32.const 1))
    #|
  let optimized = ssa_test_pipeline_expected_mutation_valid(
    input, "loop-carried reads for br_table backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::br_table(
          [@lib.LabelIdx::new(0U)],
          @lib.LabelIdx::new(0U),
        ),
      ]),
    ),
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "ssa-nomerge rewrites void br_table with canonical merge copies" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     block
    #|       local.get 0
    #|       if
    #|         i32.const 7
    #|         local.set 1
    #|       else
    #|         i32.const 8
    #|         local.set 1
    #|       end
    #|       block
    #|         local.get 0
    #|         br_table 1 1
    #|       end
    #|       i32.const 9
    #|       local.set 1
    #|     end
    #|     local.get 1))
    #|
  let optimized = ssa_test_pipeline_expected_mutation_valid(
    input, "void br_table with canonical merge copies",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
          ],
          Some([
            @lib.Instruction::i32_const(@lib.I32(8)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
          ]),
        ),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::br_table(
              [@lib.LabelIdx::new(1U)],
              @lib.LabelIdx::new(1U),
            ),
          ]),
        ),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ])
}

///|
test "ssa-nomerge rewrites result br_table with canonical merge copies" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     block (result i32)
    #|       local.get 0
    #|       if
    #|         i32.const 7
    #|         local.set 1
    #|       else
    #|         i32.const 8
    #|         local.set 1
    #|       end
    #|       block
    #|         i32.const 42
    #|         local.get 0
    #|         br_table 1 1
    #|       end
    #|       i32.const 9
    #|       local.set 1
    #|       i32.const 10
    #|     end
    #|     drop
    #|     local.get 1))
    #|
  let optimized = ssa_test_pipeline_expected_mutation_valid(
    input, "result br_table with canonical merge copies",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
          ],
          Some([
            @lib.Instruction::i32_const(@lib.I32(8)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
          ]),
        ),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(42)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::br_table(
              [@lib.LabelIdx::new(1U)],
              @lib.LabelIdx::new(1U),
            ),
          ]),
        ),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_const(@lib.I32(10)),
      ]),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ])
}

///|
test "ssa-nomerge preserves no-copy result block br_if" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     i32.const 1
    #|     local.set 1
    #|     block (result i32)
    #|       i32.const 7
    #|       local.get 0
    #|       br_if 0
    #|       drop
    #|       i32.const 9
    #|     end))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected no-copy result br_if raw ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(9)),
      ]),
    ),
  ])
}

///|
test "ssa-nomerge rewrites structured branch merges with result-typed ifs" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     i32.const 0
    #|     local.set 1
    #|     local.get 0
    #|     if (result i32)
    #|       i32.const 1
    #|       local.set 1
    #|       i32.const 7
    #|     else
    #|       i32.const 2
    #|       local.set 1
    #|       i32.const 9
    #|     end
    #|     drop
    #|     local.get 1))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected structured merge raw ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_const(@lib.I32(7)),
      ],
      Some([
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_const(@lib.I32(9)),
      ]),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ])
}

///|
test "ssa-nomerge keeps canonical param slots across typed if branch merges" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     local.get 0
    #|     if (result i32)
    #|       i32.const 7
    #|       local.set 0
    #|       i32.const 1
    #|     else
    #|       i32.const 9
    #|       local.set 0
    #|       i32.const 2
    #|     end
    #|     drop
    #|     local.get 0))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected typed-if param merge raw ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
      ],
      Some([
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
      ]),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
}

///|
test "ssa-nomerge preserves unreachable compare carriers from func 523 shape" {
  let input =
    #| (module
    #|   (func (param i64) (result i32) (local i32 i64)
    #|     i32.const 7
    #|     local.set 1
    #|     block (result i64)
    #|       block
    #|         local.get 0
    #|         i64.const 1
    #|         i64.eq
    #|         if
    #|           i64.const 4
    #|           local.set 2
    #|           br 1
    #|         else
    #|           i32.const 0
    #|           return
    #|         end
    #|         unreachable
    #|       end
    #|       local.get 2
    #|     end
    #|     i64.const 0
    #|     i64.eq
    #|     if (result i32)
    #|       i32.const 1
    #|     else
    #|       local.get 2
    #|       i64.const 0
    #|       i64.gt_u
    #|     end))
    #|
  match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected func 523 followup compare carrier shape to survive ssa-nomerge, got \{err}",
      )
  }
}

///|
test "ssa-nomerge hot path preserves temp locals for unreachable dead tees" {
  let input =
    #| (module
    #|   (func (result i32)
    #|     (local i32)
    #|     block
    #|       unreachable
    #|     end
    #|     i32.const 7
    #|     local.tee 0
    #|     drop
    #|     i32.const 9))
    #|
  let optimized = match ssa_test_run_hot_path_only(input) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected unreachable dead tee hot-path success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(9)),
  ])
}

///|
test "ssa-nomerge preserves unreachable dead tee temps before later control" {
  let input =
    #| (module
    #|   (func (param i32)
    #|     block
    #|       i32.const 1
    #|       br_table 0 0
    #|     end
    #|     block
    #|       unreachable
    #|     end
    #|     i32.const 7
    #|     local.tee 0
    #|     drop
    #|     block (result i32)
    #|       i32.const 1
    #|     end
    #|     drop
    #|     local.get 0
    #|     drop
    #|     block
    #|       i32.const 1
    #|       br_if 0
    #|     end
    #|     loop
    #|       i32.const 1
    #|       br_if 0
    #|     end
    #|     i32.const 1
    #|     if
    #|       block
    #|         br 0
    #|       end
    #|     else
    #|       nop
    #|     end))
    #|
  let optimized = match ssa_test_run_hot_path_only(input) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected unreachable dead tee temp preservation before later control, got \{err}",
      )
  }

  let (locals, _) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
}

///|
test "ssa-nomerge keeps canonical locals for if-result unreachable tee carriers" {
  let input =
    #| (module
    #|   (func (param f64 i32) (result i32)
    #|     block
    #|       i32.const 1
    #|       br_table 0 0
    #|     end
    #|     block
    #|       unreachable
    #|     end
    #|     i32.const 7
    #|     local.tee 1
    #|     drop
    #|     i32.const 11
    #|     i32.const 22
    #|     i32.const 1
    #|     select (result i32)
    #|     drop
    #|     i32.const 1
    #|     if (result i32)
    #|       i32.const 4
    #|     else
    #|       i32.const 58
    #|     end
    #|     drop
    #|     local.get 1
    #|     drop
    #|     block
    #|       i32.const 1
    #|       br_if 0
    #|     end
    #|     loop
    #|       i32.const 0
    #|       br_if 0
    #|     end
    #|     i32.const 0
    #|     if
    #|       block
    #|         br 0
    #|       end
    #|     else
    #|       nop
    #|     end
    #|     i32.const 869))
    #|
  let optimized = match ssa_test_run_hot_path_only(input) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected if-result unreachable tee-carrier success, got \{err}")
  }

  let (locals, _) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
}

///|
test "ssa-nomerge keeps canonical locals when unreachable reads stay behind later control blocks" {
  let input =
    #| (module
    #|   (func (result i32)
    #|     (local i32)
    #|     block
    #|       unreachable
    #|     end
    #|     i32.const 7
    #|     local.tee 0
    #|     drop
    #|     block
    #|       i32.const 1
    #|       br_if 0
    #|     end
    #|     loop
    #|       i32.const 1
    #|       br_if 0
    #|     end
    #|     i32.const 1
    #|     if
    #|       block
    #|         br 0
    #|       end
    #|     else
    #|       nop
    #|     end
    #|     local.get 0))
    #|
  let optimized = match ssa_test_run_hot_path_only(input) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected structured unreachable tee-carrier hot-path success, got \{err}",
      )
  }

  let (locals, _) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
}

///|
test "ssa-nomerge hot path validates unreachable default-local carrier followup" {
  let input =
    #| (module
    #|   (func (param i64 i64 i64) (result i64)
    #|     (local i64 i64 i64
    #|       i32 i32 i32 i32 i32 i32 i32 i32 i32 i32
    #|       i32 i32 i32 i32 i32 i32 i32 i32 i32 i32
    #|       i32 i32 i32 i32 i32 i32 i32 i32 i32 i32
    #|       i32 i32 i32 i32 i32 i32 i32 i32 i32 i32
    #|       i32 i32 i32 i32 i32 i32 i32 i32 i32 i32
    #|       i32 i32 i32 i32 i32 i32 i32 i32 i32 i32
    #|       i32 i32 i32 i32 i32)
    #|     i64.const 9
    #|     local.set 5
    #|     local.get 5
    #|     drop
    #|     block (result i64)
    #|       block
    #|         local.get 0
    #|         i64.const 1
    #|         i64.eq
    #|         if
    #|           i64.const 4
    #|           local.set 3
    #|           br 1
    #|         else
    #|           i64.const 0
    #|           return
    #|         end
    #|         unreachable
    #|       end
    #|       local.get 3
    #|     end
    #|     i64.const 0
    #|     i64.eq
    #|     if (result i32)
    #|       i32.const 1
    #|     else
    #|       local.get 4
    #|       local.get 2
    #|       i64.gt_u
    #|     end
    #|     drop
    #|     local.get 1
    #|     local.get 4
    #|     i64.or))
    #|
  match ssa_test_run_hot_path_only(input) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected hot-path-only ssa-nomerge carrier followup to validate, got \{err}",
      )
  }
}

///|
test "ssa-nomerge keeps branch-exit store suffix carriers canonical" {
  // Reduced from debug-WASI `dae__try__unwrap__func313__suffix__staging__block__once`
  // (`defined=300 abs=327`). Branch arms push multiple carrier values before
  // adjacent `local.set`s and a plain branch to an outer merge. These stores feed
  // post-merge reads, so the stack-to-local suffix should stay canonical instead
  // of freshening an earlier store and repairing it with a size-losing alias copy.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    (block
    #|      (block
    #|        local.get 0
    #|        (if
    #|          (then
    #|            i32.const 10
    #|            i32.const 20
    #|            local.set 2
    #|            local.set 1
    #|            br 2)
    #|          (else
    #|            i32.const 30
    #|            i32.const 40
    #|            local.set 2
    #|            local.set 1
    #|            br 2)))
    #|      i32.const 50
    #|      i32.const 60
    #|      local.set 2
    #|      local.set 1
    #|      br 0)
    #|    local.get 1
    #|    local.get 2
    #|    i32.add))
    #|
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected branch-exit store suffix carrier success, got \{err}")
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(ssa_test_local_set_indices(instrs), [2U, 1U, 2U, 1U, 2U, 1U])
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge redirects if-arm branch copy aliases" {
  // Reduced from dedicated `ssa-nomerge-smoke` GenValid failures such as
  // `.tmp/pass-fuzz-ssa-nomerge-genvalid-smoke-nullthrowfix4-10000/failures/case-000022-gen-valid`.
  // Starshine was preserving a size-losing parallel-copy shape around the final
  // block exit: each `if` arm wrote a fresh scratch, copied it to a join scratch,
  // then copied that scratch back to local 1 immediately before `br`. Binaryen
  // writes the branch carrier directly in each arm.
  let source =
    #|(module
    #|  (func (export "main") (param i32)
    #|    (local i32 i32 i32 i32 i32 i64 f32 f64)
    #|    local.get 0
    #|    drop
    #|    i32.const 101
    #|    local.set 4
    #|    local.get 4
    #|    drop
    #|    i32.const 1
    #|    if
    #|      i32.const 103
    #|      local.set 3
    #|    end
    #|    local.get 3
    #|    drop
    #|    local.get 0
    #|    if
    #|      i32.const 104
    #|      local.set 0
    #|    end
    #|    local.get 0
    #|    drop
    #|    i32.const 102
    #|    local.set 5
    #|    block
    #|      br 0
    #|    end
    #|    local.get 1
    #|    drop
    #|    i32.const 1
    #|    local.set 1
    #|    local.get 1
    #|    drop
    #|    i32.const 2
    #|    local.set 1
    #|    local.get 1
    #|    drop
    #|    i32.const 7
    #|    local.tee 1
    #|    drop
    #|    local.get 1
    #|    drop
    #|    i32.const 9
    #|    local.set 0
    #|    local.get 0
    #|    drop
    #|    i32.const 0
    #|    local.set 1
    #|    local.get 1
    #|    if
    #|      i32.const 1
    #|      local.set 1
    #|    else
    #|      i32.const 2
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    drop
    #|    local.get 1
    #|    if
    #|      i32.const 7
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    drop
    #|    local.get 0
    #|    if
    #|      i32.const 7
    #|      local.set 1
    #|      return
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    drop
    #|    i32.const 0
    #|    local.set 1
    #|    block
    #|      local.get 0
    #|      if
    #|        i32.const 7
    #|        local.set 1
    #|        br 1
    #|      end
    #|      i32.const 9
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    drop
    #|    i32.const 7
    #|    local.set 1
    #|    block
    #|      local.get 0
    #|      br_if 0
    #|      i32.const 9
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    drop
    #|    local.get 0
    #|    if
    #|      nop
    #|    end
    #|    i32.const 12
    #|    local.set 1
    #|    local.get 1
    #|    drop
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 7
    #|      local.set 0
    #|      i32.const 1
    #|    else
    #|      i32.const 9
    #|      local.set 0
    #|      i32.const 2
    #|    end
    #|    drop
    #|    local.get 0
    #|    drop
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 20
    #|      local.set 2
    #|      i32.const 2
    #|    else
    #|      i32.const 30
    #|      local.set 3
    #|      i32.const 3
    #|    end
    #|    drop
    #|    block
    #|      local.get 0
    #|      if
    #|        i32.const 37
    #|        local.set 1
    #|      else
    #|        i32.const 38
    #|        local.set 1
    #|      end
    #|      br 0
    #|    end
    #|    local.get 1
    #|    drop
    #|    i32.const 0
    #|    local.set 3
    #|    local.get 3
    #|    if
    #|      i32.const 120
    #|      local.tee 3
    #|      drop
    #|    end
    #|    local.get 3
    #|    drop
    #|    i32.const 121
    #|    local.tee 5
    #|    i32.const 1
    #|    i32.add
    #|    drop
    #|    local.get 5
    #|    drop
    #|    i32.const 122
    #|    local.tee 2
    #|    drop))
    #|
  let optimized = match pass_test_run_pipeline(source, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected if-arm branch copy alias success, got \{err}")
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() <= 28, msg=locals.to_string())
  let tee_indices = ssa_test_local_tee_indices(instrs)
  let mut final_tee = 0U
  for idx in tee_indices {
    if idx > final_tee {
      final_tee = idx
    }
  }
  assert_false(
    ssa_nomerge_test_local_get_indices(instrs).contains(final_tee),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge groups mixed body locals and duplicate func types like Binaryen raw output" {
  // Binaryen parses/writes function body-local declarations in grouped type
  // order and canonicalizes duplicate simple function types around SSAify(false).
  // Starshine's raw `ssa-nomerge` path must not keep mixed local declarations or
  // duplicate function-type entries that make dedicated smoke samples raw larger
  // before the normalized writer repairs them.
  let source =
    #|(module
    #|  (type $p (func (param i32)))
    #|  (type $dup (func (param i32)))
    #|  (func (export "main") (type $p) (param i32)
    #|    (local i32 i64 i32)
    #|    i32.const 1
    #|    local.set 3
    #|    local.get 3
    #|    drop
    #|    i32.const 2
    #|    local.set 3
    #|    local.get 3
    #|    drop)
    #|  (func (type $dup) (param i32)
    #|    local.get 0
    #|    drop))
    #|
  let optimized = match pass_test_run_pipeline(source, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected mixed-local grouping success, got \{err}")
  }
  @debug.assert_eq(ssa_test_type_count(optimized), 1)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(ssa_test_local_types(locals), [
    @lib.ValType::i32(),
    @lib.ValType::i32(),
    @lib.ValType::i32(),
    @lib.ValType::i32(),
    @lib.ValType::i64(),
  ])
  assert_false(
    ssa_test_local_write_indices(instrs).contains(5U) ||
    ssa_nomerge_test_local_get_indices(instrs).contains(5U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge drops unused appended locals after post-default branch planning" {
  // Reduced from dedicated `ssa-nomerge-smoke` GenValid
  // `case-000002-gen-valid` after post-default freshening was composed. The
  // combined LocalGraph/default/branch-copy pipeline can make early planned
  // fresh locals unreachable before the final raw function is returned; keeping
  // those dead appended declarations made Starshine local-count-losing even
  // though the executable local traffic had already converged.
  let source =
    #|(module
    #|  (func (export "main") (param i32)
    #|    (local i32 i32 i32 i32 i32 i64 i32 f32 i64 f64)
    #|    local.get 0
    #|    drop
    #|    i32.const 101
    #|    local.set 4
    #|    local.get 4
    #|    drop
    #|    i32.const 1
    #|    if
    #|      i32.const 103
    #|      local.set 3
    #|    end
    #|    local.get 3
    #|    drop
    #|    local.get 0
    #|    if
    #|      i32.const 104
    #|      local.set 0
    #|    end
    #|    local.get 0
    #|    drop
    #|    i32.const 102
    #|    local.set 5
    #|    block
    #|      br 0
    #|    end
    #|    local.get 1
    #|    drop
    #|    i32.const 1
    #|    local.set 1
    #|    local.get 1
    #|    drop
    #|    i32.const 2
    #|    local.set 1
    #|    local.get 1
    #|    drop
    #|    i32.const 7
    #|    local.tee 1
    #|    drop
    #|    local.get 1
    #|    drop
    #|    i32.const 9
    #|    local.set 0
    #|    local.get 0
    #|    drop
    #|    i32.const 0
    #|    local.set 1
    #|    local.get 1
    #|    if
    #|      i32.const 1
    #|      local.set 1
    #|    else
    #|      i32.const 2
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    drop
    #|    local.get 1
    #|    if
    #|      i32.const 7
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    drop
    #|    local.get 0
    #|    if
    #|      i32.const 7
    #|      local.set 1
    #|      return
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    drop
    #|    i32.const 0
    #|    local.set 1
    #|    block
    #|      local.get 0
    #|      if
    #|        i32.const 7
    #|        local.set 1
    #|        br 1
    #|      end
    #|      i32.const 9
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    drop
    #|    i32.const 7
    #|    local.set 1
    #|    block
    #|      local.get 0
    #|      br_if 0
    #|      i32.const 9
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    drop
    #|    local.get 0
    #|    if
    #|      nop
    #|    end
    #|    i32.const 12
    #|    local.set 1
    #|    local.get 1
    #|    drop
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 7
    #|      local.set 0
    #|      i32.const 1
    #|    else
    #|      i32.const 9
    #|      local.set 0
    #|      i32.const 2
    #|    end
    #|    drop
    #|    local.get 0
    #|    drop
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 20
    #|      local.set 2
    #|      i32.const 2
    #|    else
    #|      i32.const 30
    #|      local.set 3
    #|      i32.const 3
    #|    end
    #|    drop
    #|    block
    #|      local.get 0
    #|      if
    #|        i32.const 37
    #|        local.set 1
    #|      else
    #|        i32.const 38
    #|        local.set 1
    #|      end
    #|      block
    #|        br 1
    #|      end
    #|      i32.const 39
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    drop
    #|    block
    #|      local.get 0
    #|      if
    #|        i32.const 80
    #|        local.set 1
    #|      else
    #|        i32.const 82
    #|        local.set 1
    #|      end
    #|      block
    #|        br 1
    #|      end
    #|      i32.const 84
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    drop
    #|    i32.const 0
    #|    local.set 3
    #|    local.get 3
    #|    if
    #|      i32.const 120
    #|      local.tee 3
    #|      drop
    #|    end
    #|    local.get 3
    #|    drop
    #|    i32.const 121
    #|    local.tee 5
    #|    i32.const 1
    #|    i32.add
    #|    drop
    #|    local.get 5
    #|    drop
    #|    i32.const 122
    #|    local.tee 2
    #|    drop))
    #|
  let optimized = match pass_test_run_pipeline(source, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected post-default branch planning success, got \{err}")
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(
    locals.length() <= 26,
    msg=locals.to_string() + "\n" + instrs.to_string(),
  )
}

///|
test "ssa-nomerge compacts large branch-exit alias scratch locals" {
  // Reduced from the current debug-WASI `defined=6070 abs=6097` first
  // non-masked diff after the one-use temp-local chain. A branch exit stores
  // two merge carriers just before a plain `br`; Starshine should not keep
  // extra alias scratch locals when the branch-local carriers can be written
  // directly like Binaryen's shape.
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $moonbit.array_length (param i32) (result i32) i32.const 1)
    #|  (func $moonbit.check_range (param i32 i32) (result i32) local.get 0)
    #|  (func $moonbit.incref (param i32))
    #|  (func $_M0MPB3Map4growGsRPB4JsonE (param i32) (result i32) local.get 0)
    #|  (func $moonbit.gc.malloc (param i32) (result i32) local.get 0)
    #|  (func $_M0MPB3Map20add__entry__to__tailGsRPB4JsonE (param i32 i32 i32) (result i32) i32.const 0)
    #|  (func $moonbit.string_equal (param i32 i32) (result i32) i32.const 0)
    #|  (func $moonbit.decref (param i32))
    #|  (func $_M0MPB3Map10push__awayGsRPB4JsonE (param i32 i32 i32) (result i32) i32.const 0)
    #|  (func $f (param i32 i32 i32 i32) (result i32)
    #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|    local.get 0
    #|    i32.load offset=16 align=1
    #|    local.set 32
    #|    local.get 3
    #|    local.get 32
    #|    i32.and
    #|    local.set 31
    #|    i32.const 0
    #|    local.get 31
    #|    local.set 39
    #|    local.set 38
    #|    loop
    #|      local.get 38
    #|      local.get 39
    #|      local.set 5
    #|      local.set 4
    #|      local.get 0
    #|      i32.load offset=28 align=1
    #|      local.tee 40
    #|      local.get 5
    #|      local.set 37
    #|      local.set 36
    #|      local.get 37
    #|      i32.const 0
    #|      local.get 36
    #|      call $moonbit.array_length
    #|      i32.const 1
    #|      i32.sub
    #|      call $moonbit.check_range
    #|      local.get 36
    #|      local.get 37
    #|      i32.const 2
    #|      i32.shl
    #|      i32.add
    #|      i32.load offset=8 align=1
    #|      local.tee 6
    #|      i32.const 0
    #|      i32.eq
    #|      if
    #|        local.get 0
    #|        i32.load offset=8 align=1
    #|        local.set 15
    #|        local.get 0
    #|        i32.load offset=20 align=1
    #|        local.set 16
    #|        local.get 15
    #|        local.get 16
    #|        i32.ge_s
    #|        if
    #|          local.get 0
    #|          call $moonbit.incref
    #|          local.get 0
    #|          call $_M0MPB3Map4growGsRPB4JsonE
    #|          drop
    #|          local.get 0
    #|          i32.load offset=16 align=1
    #|          local.set 18
    #|          local.get 3
    #|          local.get 18
    #|          i32.and
    #|          local.set 17
    #|          i32.const 0
    #|          local.get 17
    #|          local.set 39
    #|          local.set 38
    #|          br 2
    #|        end
    #|        i32.const 0
    #|        drop
    #|        local.get 0
    #|        i32.load offset=24 align=1
    #|        local.set 7
    #|        i32.const 0
    #|        local.set 8
    #|        i32.const 24
    #|        call $moonbit.gc.malloc
    #|        local.tee 34
    #|        i32.const 2622208
    #|        i32.store offset=4 align=1
    #|        local.get 34
    #|        local.get 2
    #|        i32.store offset=28 align=1
    #|        local.get 34
    #|        local.get 1
    #|        i32.store offset=24 align=1
    #|        local.get 34
    #|        local.get 3
    #|        i32.store offset=16 align=1
    #|        local.get 34
    #|        local.get 4
    #|        i32.store offset=12 align=1
    #|        local.get 34
    #|        local.get 8
    #|        i32.store offset=20 align=1
    #|        local.get 34
    #|        local.get 7
    #|        i32.store offset=8 align=1
    #|        local.get 34
    #|        local.set 9
    #|        local.get 0
    #|        local.get 5
    #|        local.get 9
    #|        call $_M0MPB3Map20add__entry__to__tailGsRPB4JsonE
    #|        drop
    #|        i32.const 0
    #|        return
    #|      else
    #|        local.get 6
    #|        local.tee 41
    #|        local.set 11
    #|        local.get 11
    #|        i32.load offset=16 align=1
    #|        local.tee 42
    #|        local.get 3
    #|        i32.eq
    #|        if (result i32)
    #|          local.get 11
    #|          i32.load offset=24 align=1
    #|          local.tee 43
    #|          local.get 1
    #|          call $moonbit.string_equal
    #|        else
    #|          i32.const 0
    #|        end
    #|        if
    #|          local.get 11
    #|          call $moonbit.incref
    #|          local.get 1
    #|          call $moonbit.decref
    #|          local.get 0
    #|          call $moonbit.decref
    #|          local.get 11
    #|          i32.load offset=28 align=1
    #|          local.tee 44
    #|          call $moonbit.decref
    #|          local.get 11
    #|          local.get 2
    #|          i32.store offset=28 align=1
    #|          local.get 11
    #|          call $moonbit.decref
    #|          i32.const 0
    #|          drop
    #|          i32.const 0
    #|          return
    #|        else
    #|          local.get 11
    #|          call $moonbit.incref
    #|        end
    #|        i32.const 0
    #|        drop
    #|        local.get 11
    #|        i32.load offset=12 align=1
    #|        local.set 21
    #|        local.get 4
    #|        local.get 21
    #|        i32.gt_s
    #|        if
    #|          local.get 0
    #|          i32.load offset=8 align=1
    #|          local.set 22
    #|          local.get 0
    #|          i32.load offset=20 align=1
    #|          local.set 23
    #|          local.get 22
    #|          local.get 23
    #|          i32.ge_s
    #|          if
    #|            local.get 11
    #|            call $moonbit.decref
    #|            local.get 0
    #|            call $moonbit.incref
    #|            local.get 0
    #|            call $_M0MPB3Map4growGsRPB4JsonE
    #|            drop
    #|            local.get 0
    #|            i32.load offset=16 align=1
    #|            local.set 25
    #|            local.get 3
    #|            local.get 25
    #|            i32.and
    #|            local.set 24
    #|            i32.const 0
    #|            local.get 24
    #|            local.set 39
    #|            local.set 38
    #|            br 3
    #|          end
    #|          i32.const 0
    #|          drop
    #|          local.get 0
    #|          call $moonbit.incref
    #|          local.get 0
    #|          local.get 5
    #|          local.get 11
    #|          call $_M0MPB3Map10push__awayGsRPB4JsonE
    #|          drop
    #|          local.get 0
    #|          i32.load offset=24 align=1
    #|          local.set 12
    #|          i32.const 0
    #|          local.set 13
    #|          i32.const 24
    #|          call $moonbit.gc.malloc
    #|          local.tee 35
    #|          i32.const 2622208
    #|          i32.store offset=4 align=1
    #|          local.get 35
    #|          local.get 2
    #|          i32.store offset=28 align=1
    #|          local.get 35
    #|          local.get 1
    #|          i32.store offset=24 align=1
    #|          local.get 35
    #|          local.get 3
    #|          i32.store offset=16 align=1
    #|          local.get 35
    #|          local.get 4
    #|          i32.store offset=12 align=1
    #|          local.get 35
    #|          local.get 13
    #|          i32.store offset=20 align=1
    #|          local.get 35
    #|          local.get 12
    #|          i32.store offset=8 align=1
    #|          local.get 35
    #|          local.set 14
    #|          local.get 0
    #|          local.get 5
    #|          local.get 14
    #|          call $_M0MPB3Map20add__entry__to__tailGsRPB4JsonE
    #|          drop
    #|          i32.const 0
    #|          return
    #|        else
    #|          local.get 11
    #|          call $moonbit.decref
    #|        end
    #|        i32.const 0
    #|        drop
    #|        local.get 4
    #|        i32.const 1
    #|        i32.add
    #|        local.set 26
    #|        local.get 5
    #|        i32.const 1
    #|        i32.add
    #|        local.set 28
    #|        local.get 0
    #|        i32.load offset=16 align=1
    #|        local.set 29
    #|        local.get 28
    #|        local.get 29
    #|        i32.and
    #|        local.set 27
    #|        local.get 26
    #|        local.get 27
    #|        local.set 39
    #|        local.set 38
    #|        br 1
    #|      end
    #|      i32.const 0
    #|      drop
    #|    end
    #|    i32.const 0))
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected ssa-nomerge success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected ssa-nomerge output to validate, got \{@validate.validation_error_message(err)}",
      )
  }
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 2)
  assert_true(
    locals.length() <= 50,
    msg=trace.join("\n") + "\n" + locals.to_string() + "\n" + instrs.to_string(),
  )
}

///|
test "ssa-nomerge avoids loop-backedge alias copies for header-read locals" {
  // Reduced from debug-WASI `parse__olevel__text` (`defined=154 abs=181`).
  // Binaryen keeps locals written before the loop canonical when the loop header
  // reads them before any loop-local write; Starshine should not freshen them and
  // then repair every plain backedge with size-losing alias copies.
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $alloc (param i32) (result i32) local.get 0)
    #|  (func $drop (param i32))
    #|  (func $parse (param $text i32) (result i32)
    #|    (local $limit i32) (local $posbox i32) (local $digitsbox i32)
    #|    (local $ch i32) (local $value i32) (local $tmp i32)
    #|    local.get $text
    #|    call $alloc
    #|    local.set $limit
    #|    i32.const 4
    #|    call $alloc
    #|    local.tee $posbox
    #|    i32.const 0
    #|    i32.store offset=8 align=1
    #|    i32.const 4
    #|    call $alloc
    #|    local.tee $digitsbox
    #|    i32.const 0
    #|    i32.store offset=8 align=1
    #|    block $exit
    #|      loop $loop
    #|        local.get $posbox
    #|        i32.load offset=8 align=1
    #|        local.get $limit
    #|        i32.lt_s
    #|        if
    #|          local.get $text
    #|          local.get $posbox
    #|          i32.load offset=8 align=1
    #|          i32.const 1
    #|          i32.shl
    #|          i32.add
    #|          i32.load16_u offset=8 align=1
    #|          local.set $ch
    #|          local.get $ch
    #|          i32.const 48
    #|          i32.lt_s
    #|          if
    #|            local.get $posbox
    #|            call $drop
    #|            br $exit
    #|          end
    #|          local.get $digitsbox
    #|          i32.load offset=8 align=1
    #|          i32.eqz
    #|          if
    #|            local.get $digitsbox
    #|            i32.const 1
    #|            i32.store offset=8 align=1
    #|          end
    #|          local.get $digitsbox
    #|          i32.load offset=8 align=1
    #|          i32.const 10
    #|          i32.mul
    #|          local.get $ch
    #|          i32.add
    #|          local.set $value
    #|          local.get $digitsbox
    #|          local.get $value
    #|          i32.store offset=8 align=1
    #|          local.get $posbox
    #|          i32.load offset=8 align=1
    #|          i32.const 1
    #|          i32.add
    #|          local.set $tmp
    #|          local.get $posbox
    #|          local.get $tmp
    #|          i32.store offset=8 align=1
    #|          br $loop
    #|        end
    #|      end
    #|    end
    #|    local.get $digitsbox
    #|    i32.load offset=8 align=1))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 2)
  assert_true(locals.length() <= 6, msg=locals.to_string())
  let writes = ssa_test_local_write_indices(instrs)
  assert_false(writes.any(fn(idx) { idx > 6U }), msg=writes.to_string())
}
