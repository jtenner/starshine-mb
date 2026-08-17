///|
fn simplify_locals_wbtest_ctx() -> HotPassContext {
  HotPassContext::new(
    simplify_locals_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
}

///|
test "simplify-locals defers aggregate multi-read locals on the first cycle" {
  let func = pass_test_lift_first_func(
    "(module (func (local i32) i32.const 1 local.set 0 local.get 0 drop i32.const 2 local.set 0 local.get 0 drop))",
  )
  let get_counts = simplify_locals_count_local_gets(func)
  @debug.assert_eq(get_counts[0], 2)
  let detached : Array[Int] = []
  let (changed, has_deferred) = simplify_locals_run_main_cycle(
    simplify_locals_wbtest_ctx(),
    func,
    true,
    detached,
    SimplifyLocalsPolicy::new(false, true, true),
    false,
  )
  assert_false(changed)
  assert_true(has_deferred)
}

///|
test "simplify-locals no-tee keeps aggregate multi-read producers after copy sinking" {
  let func = pass_test_lift_first_func(
    "(module (func (local i32 i32) i32.const 1 i32.const 2 i32.add local.set 0 local.get 0 local.set 1 local.get 1 drop i32.const 3 i32.const 4 i32.add local.set 0 local.get 0 drop))",
  )
  let initial_counts = simplify_locals_count_local_gets(func)
  @debug.assert_eq(initial_counts[0], 2)
  @debug.assert_eq(initial_counts[1], 1)
  let policy = SimplifyLocalsPolicy::new(true, false, true)
  let first_detached : Array[Int] = []
  let (first_changed, first_deferred) = simplify_locals_run_main_cycle(
    simplify_locals_wbtest_ctx(),
    func,
    true,
    first_detached,
    policy,
    false,
  )
  assert_true(first_changed)
  assert_true(first_deferred)
  simplify_locals_delete_detached_nodes(func, first_detached)
  let after_first_counts = simplify_locals_count_local_gets(func)
  @debug.assert_eq(after_first_counts[0], 2)
  @debug.assert_eq(after_first_counts[1], 0)
  let cleanup_detached : Array[Int] = []
  let cleanup_rehomed : Array[SimplifyLocalsDetachedControlOwner] = []
  ignore(
    simplify_locals_run_dead_cleanup(
      simplify_locals_wbtest_ctx(),
      func,
      cleanup_detached,
      cleanup_rehomed,
      true,
    ),
  )
  simplify_locals_rehome_detached_control_owners(func, cleanup_rehomed)
  simplify_locals_delete_detached_nodes(func, cleanup_detached)
  @debug.assert_eq(simplify_locals_count_local_gets(func)[0], 2)
  let live_set_locals : Array[Int] = []
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if @ir.hot_node_is_live(func, node_id) {
      let node = @ir.hot_node_get(func, node_id)
      match node.op {
        @ir.HotOp::LocalSet => live_set_locals.push(node.imm0)
        _ => ()
      }
    }
  }
  @debug.assert_eq(live_set_locals, [0, 0])
  let second_detached : Array[Int] = []
  let (second_changed, _) = simplify_locals_run_main_cycle(
    simplify_locals_wbtest_ctx(),
    func,
    false,
    second_detached,
    policy,
    false,
  )
  assert_false(second_changed)
  simplify_locals_delete_detached_nodes(func, second_detached)
  let second_cleanup_detached : Array[Int] = []
  let second_cleanup_rehomed : Array[SimplifyLocalsDetachedControlOwner] = []
  assert_false(
    simplify_locals_run_dead_cleanup(
      simplify_locals_wbtest_ctx(),
      func,
      second_cleanup_detached,
      second_cleanup_rehomed,
      true,
    ),
  )
  simplify_locals_rehome_detached_control_owners(func, second_cleanup_rehomed)
  simplify_locals_delete_detached_nodes(func, second_cleanup_detached)
  @debug.assert_eq(simplify_locals_count_local_gets(func)[0], 2)
  let structure_detached : Array[Int] = []
  assert_false(
    simplify_locals_run_structure_rewrites(
      func,
      structure_detached,
      allow_multi_use=false,
    ),
  )
  @debug.assert_eq(simplify_locals_equivalent_candidate_count(func), 0)
}

///|
test "simplify-locals no-tee canonicalizes repeated copies without sinking their source" {
  let func = pass_test_lift_first_func(
    "(module (func (local i32 i32) i32.const 70 local.set 0 local.get 0 local.set 1 local.get 1 drop i32.const 71 i32.const 1 i32.add local.set 0 local.get 0 local.set 1 local.get 1 drop i32.const 72 i32.const 2 i32.add local.set 0 local.get 0 drop))",
  )
  let policy = SimplifyLocalsPolicy::new(true, false, true)
  let first_detached : Array[Int] = []
  let (first_changed, first_deferred) = simplify_locals_run_main_cycle(
    simplify_locals_wbtest_ctx(),
    func,
    true,
    first_detached,
    policy,
    false,
  )
  assert_false(first_changed)
  assert_true(first_deferred)
  let second_detached : Array[Int] = []
  let (second_changed, _) = simplify_locals_run_main_cycle(
    simplify_locals_wbtest_ctx(),
    func,
    false,
    second_detached,
    policy,
    false,
  )
  assert_false(second_changed)
  @debug.assert_eq(simplify_locals_equivalent_candidate_count(func), 2)
  assert_true(
    simplify_locals_run_equivalent_cleanup(simplify_locals_wbtest_ctx(), func),
  )
  let late_detached : Array[Int] = []
  let late_rehomed : Array[SimplifyLocalsDetachedControlOwner] = []
  assert_true(
    simplify_locals_run_dead_cleanup(
      simplify_locals_wbtest_ctx(),
      func,
      late_detached,
      late_rehomed,
      true,
    ),
  )
  simplify_locals_rehome_detached_control_owners(func, late_rehomed)
  simplify_locals_delete_detached_nodes(func, late_detached)
  let counts = simplify_locals_count_local_gets(func)
  @debug.assert_eq(counts[0], 3)
  @debug.assert_eq(counts[1], 0)
  let source_sets : Array[Int] = []
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if @ir.hot_node_is_live(func, node_id) {
      let node = @ir.hot_node_get(func, node_id)
      match node.op {
        @ir.HotOp::LocalSet if node.imm0 == 0 => source_sets.push(node_id)
        _ => ()
      }
    }
  }
  @debug.assert_eq(source_sets.length(), 3)
  let final_detached : Array[Int] = []
  let (final_changed, _) = simplify_locals_run_main_cycle(
    simplify_locals_wbtest_ctx(),
    func,
    false,
    final_detached,
    policy,
    false,
  )
  assert_false(final_changed)
  let full_func = pass_test_lift_first_func(
    "(module (func (local i32 i32) i32.const 70 local.set 0 local.get 0 local.set 1 local.get 1 drop i32.const 71 i32.const 1 i32.add local.set 0 local.get 0 local.set 1 local.get 1 drop i32.const 72 i32.const 2 i32.add local.set 0 local.get 0 drop))",
  )
  ignore(
    simplify_locals_run_with_options(
      simplify_locals_wbtest_ctx(),
      full_func,
      policy,
    ),
  )
  @debug.assert_eq(simplify_locals_count_local_gets(full_func)[0], 3)
  let source = "(module (func (local i32 i32) i32.const 70 local.set 0 local.get 0 local.set 1 local.get 1 drop i32.const 71 i32.const 1 i32.add local.set 0 local.get 0 local.set 1 local.get 1 drop i32.const 72 i32.const 2 i32.add local.set 0 local.get 0 drop))"
  let mod_ = pass_test_module_from_wat(source)
  let module_state = HotPipelineModuleState::new()
  let options = HotPipelineOptions::new()
  let module_ctx = run_hot_pipeline_require_module_ctx(
    mod_, module_state, options,
  )
  let context_func = match
    @ir.hot_lift_func_with_context_result(
      mod_,
      @lib.FuncIdx::new(0U),
      module_ctx,
    ) {
    Ok(func) => func
    Err(err) => fail("expected context lift success, got \{err}")
  }
  let context_pass = HotPassContext::new(
    simplify_locals_notee_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
    module_ctx=Some(module_ctx),
  )
  ignore(simplify_locals_run_with_options(context_pass, context_func, policy))
  @debug.assert_eq(simplify_locals_count_local_gets(context_func)[0], 3)
}

///|
test "simplify-locals no-structure Hot result removes the transparent copy read" {
  let source = "(module (func (param i32) (local i32 i32 i32) local.get 0 local.set 1 block local.get 1 local.set 2 end local.get 2 local.set 1 local.get 1 drop local.get 0 drop))"
  let func = pass_test_lift_first_func(source)
  ignore(
    simplify_locals_run_with_options(
      simplify_locals_wbtest_ctx(),
      func,
      SimplifyLocalsPolicy::new(false, true, true),
    ),
  )
  let lowered = @ir.hot_lower_func(func)
  let candidate = pass_test_module_from_wat(source).with_code_sec(
    @lib.CodeSec::new([lowered]),
  )
  let pretty = candidate.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(pretty.split("local.get (Local 0)").length(), 2)
}

///|
test "simplify-locals keeps deferred repeated-read sinking core-valid" {
  let source = "(module (memory 1) (table 1 funcref) (global (mut i32) (i32.const 0)) (func (local i32 funcref) global.get 0 local.set 0 i32.const 1 global.set 0 local.get 0 drop i32.const 0 i32.load local.set 0 i32.const 4 i32.load drop local.get 0 drop i32.const 0 i32.load local.set 0 i32.const 0 i32.const 2 i32.store local.get 0 drop i32.const 0 table.get 0 local.set 1 nop local.get 1 drop i32.const 0 ref.null func table.set 0 call 1 drop) (func (result i32) i32.const 3))"
  let func = pass_test_lift_first_func(source)
  let result = simplify_locals_run(simplify_locals_wbtest_ctx(), func)
  assert_true(result.changed)
  match @ir.hot_verify_core(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected deferred repeated-read sinking core validity, got \{err}")
  }
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected deferred repeated-read sinking control validity, got \{err}",
      )
  }
  let lowered = @ir.hot_lower_func(func)
  let original = pass_test_module_from_wat(source)
  let helper = @ir.hot_lower_func(
    pass_test_lift_first_func("(module (func (result i32) i32.const 3))"),
  )
  let candidate = original.with_code_sec(@lib.CodeSec::new([lowered, helper]))
  match @validate.validate_module(candidate) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected deferred repeated-read sinking module validity, got \{@validate.validation_error_message(err)}; module=\{candidate}",
      )
  }
}

///|
test "simplify-locals full runner keeps conditional block result formation valid" {
  let source = "(module (func (param i32) (local i32) block i32.const 7 local.set 1 local.get 0 br_if 0 i32.const 9 local.set 1 end local.get 1 drop))"
  let probe = pass_test_lift_first_func(source)
  let probe_detached : Array[Int] = []
  assert_true(
    simplify_locals_try_rewrite_block_return(
      probe,
      @ir.HotRegionRef::root(),
      0,
      @ir.hot_root_get(probe, 0),
      simplify_locals_count_local_gets(probe),
      probe_detached,
    ),
  )
  let probe_drop = @ir.hot_root_get(probe, 1)
  @debug.assert_eq(@ir.hot_node_get(probe, probe_drop).op.to_string(), "Drop")
  let probe_block = @ir.hot_child_get(probe, probe_drop, 0)
  @debug.assert_eq(@ir.hot_node_get(probe, probe_block).op.to_string(), "Block")
  let probe_body = @ir.hot_region_body_ref(probe, probe_block)
  @debug.assert_eq(@ir.hot_region_root_count(probe, probe_body), 4)
  @debug.assert_eq(
    @ir.hot_node_get(probe, @ir.hot_region_get(probe, probe_body, 2)).op.to_string(),
    "Nop",
  )
  @debug.assert_eq(
    @ir.hot_node_get(probe, @ir.hot_region_get(probe, probe_body, 3)).op.to_string(),
    "Const",
  )
  let func = pass_test_lift_first_func(source)
  let result = simplify_locals_run(simplify_locals_wbtest_ctx(), func)
  assert_true(result.changed)
  match @ir.hot_verify_core(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected full block rewrite to remain core-valid, got \{err}")
  }
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected full block rewrite to remain control-valid, got \{err}")
  }
  let lowered = @ir.hot_lower_func(func)
  let candidate = pass_test_module_from_wat(source).with_code_sec(
    @lib.CodeSec::new([lowered]),
  )
  match @validate.validate_module(candidate) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected full block rewrite module validation, got \{@validate.validation_error_message(err)}; module=\{candidate}",
      )
  }
  let @lib.Func(_, @lib.Expr(body)) = lowered
  assert_true(body.any(fn(instr) { instr is @lib.Drop }))
  assert_false(body.any(fn(instr) { instr is @lib.LocalSet(_) }))
  assert_false(
    body.any(fn(instr) { instr is @lib.LocalGet(@lib.LocalIdx(1U)) }),
  )
}

///|
test "simplify-locals full runner keeps simple loop result formation valid" {
  let source = "(module (func (local i32) loop i32.const 44 local.set 0 nop end local.get 0 drop))"
  let func = pass_test_lift_first_func(source)
  let result = simplify_locals_run(simplify_locals_wbtest_ctx(), func)
  assert_true(result.changed)
  match @ir.hot_verify_core(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected full loop rewrite to remain core-valid, got \{err}")
  }
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected full loop rewrite to remain control-valid, got \{err}")
  }
  let lowered = @ir.hot_lower_func(func)
  let @lib.Func(_, @lib.Expr(body)) = lowered
  assert_true(body.any(fn(instr) { instr is @lib.Drop }))
  assert_false(body.any(fn(instr) { instr is @lib.LocalSet(_) }))
  assert_false(body.any(fn(instr) { instr is @lib.LocalGet(_) }))
  let candidate = pass_test_module_from_wat(source).with_code_sec(
    @lib.CodeSec::new([lowered]),
  )
  match @validate.validate_module(candidate) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected full loop rewrite module validation, got \{@validate.validation_error_message(err)}; module=\{candidate}",
      )
  }
}

///|
test "simplify-locals recognizes simple loop tail writes before sink cleanup" {
  let func = pass_test_lift_first_func(
    "(module (func (local i32) loop i32.const 44 local.set 0 nop end local.get 0 drop))",
  )
  let loop_id = @ir.hot_root_get(func, 0)
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  let tail = simplify_locals_region_tail_local_set(func, body_ref)
  assert_true(tail is Some(_))
  let counts = simplify_locals_count_local_gets(func)
  @debug.assert_eq(counts[0], 1)
  let detached : Array[Int] = []
  assert_true(
    simplify_locals_try_rewrite_loop_return(
      func,
      @ir.HotRegionRef::root(),
      0,
      loop_id,
      counts,
      detached,
    ),
  )
  @debug.assert_eq(@ir.hot_node_result_arity(func, loop_id), 0)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).op.to_string(),
    "Nop",
  )
  let drop_id = @ir.hot_root_get(func, 1)
  @debug.assert_eq(@ir.hot_node_get(func, drop_id).op.to_string(), "Drop")
  let moved_loop_id = @ir.hot_child_get(func, drop_id, 0)
  assert_true(moved_loop_id != loop_id)
  @debug.assert_eq(@ir.hot_node_get(func, moved_loop_id).op.to_string(), "Loop")
  @debug.assert_eq(@ir.hot_node_result_arity(func, moved_loop_id), 1)
  match @ir.hot_verify_core(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected moved loop result to remain core-valid, got \{err}")
  }
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected moved loop result to remain control-valid, got \{err}")
  }
}

///|
test "simplify-locals does not collect block exits through typed child carriers" {
  let func = pass_test_lift_first_func(
    (
      #|(module
      #|  (func (param i32 i32) (result i32) (local i32)
      #|    (block $outer
      #|      (block $inner_res (result i32)
      #|        (block $inner
      #|          (local.get 0)
      #|          (if (result i32)
      #|            (then
      #|              (local.get 1)
      #|              (local.set 2)
      #|              (br $inner)
      #|            )
      #|            (else
      #|              (local.get 1)
      #|              (local.set 2)
      #|              (br $outer)
      #|            )
      #|          )
      #|          (br $inner_res)
      #|        )
      #|        (local.get 2)
      #|      )
      #|      (local.set 2)
      #|    )
      #|    (local.get 2))
      #|),
    ),
  )
  let outer_id = @ir.hot_root_get(func, 0)
  let outer_body = @ir.hot_region_body_ref(func, outer_id)
  let fallthrough_set = @ir.hot_region_get(func, outer_body, 0)
  @debug.assert_eq(
    @ir.hot_node_get(func, fallthrough_set).op.to_string(),
    "LocalSet",
  )
  let inner_res_id = @ir.hot_child_get(func, fallthrough_set, 0)
  assert_true(
    simplify_locals_control_has_typed_branch_payload(func, inner_res_id),
  )
  assert_true(
    simplify_locals_subtree_has_branch_to_label(
      func,
      fallthrough_set,
      @ir.hot_control_node_label(func, outer_id),
    ),
  )
  let exits : Array[SimplifyLocalsBranchExit] = []
  assert_false(
    simplify_locals_collect_block_branch_exits(
      func,
      outer_body,
      @ir.hot_control_node_label(func, outer_id),
      2,
      exits,
    ),
  )
}

///|
test "simplify-locals does not rewrite block returns when the fallthrough value branches back" {
  let func = pass_test_lift_first_func(
    (
      #|(module
      #|  (func (param i32 i32) (result i32) (local i32)
      #|    (block $outer
      #|      (block $inner_res (result i32)
      #|        (block $inner
      #|          (local.get 0)
      #|          (if (result i32)
      #|            (then
      #|              (local.get 1)
      #|              (local.set 2)
      #|              (br $inner)
      #|            )
      #|            (else
      #|              (local.get 1)
      #|              (local.set 2)
      #|              (br $outer)
      #|            )
      #|          )
      #|          (br $inner_res)
      #|        )
      #|        (local.get 2)
      #|      )
      #|      (local.set 2)
      #|    )
      #|    (local.get 2))
      #|),
    ),
  )
  let detached : Array[Int] = []
  assert_false(
    simplify_locals_try_rewrite_block_return(
      func,
      @ir.HotRegionRef::root(),
      0,
      @ir.hot_root_get(func, 0),
      simplify_locals_count_local_gets(func),
      detached,
    ),
  )
}

///|
test "simplify-locals records sparse pending local effects" {
  let func = pass_test_lift_first_func(
    (
      #|(module
      #|  (func (param i32 i32) (result i32) (local i32 i32)
      #|    local.get 0
      #|    local.tee 3
      #|    local.get 3
      #|    i32.add
      #|    local.set 2
      #|    local.get 2))
      #|),
    ),
  )
  let set_id = @ir.hot_root_get(func, 0)
  let set_node = @ir.hot_node_get(func, set_id)
  let sinkables = simplify_locals_new_sinkables(func)
  let effects = simplify_locals_effects_for_pending_local_set(
    func, set_id, set_node, sinkables,
  )

  @debug.assert_eq(effects.local_reads.length(), 2)
  assert_true(effects.local_reads.contains(0))
  assert_true(effects.local_reads.contains(3))
  @debug.assert_eq(effects.local_writes.length(), 2)
  assert_true(effects.local_writes.contains(2))
  assert_true(effects.local_writes.contains(3))
}

///|
test "simplify-locals bulk-clear gate follows active sinkable density" {
  let func = pass_test_lift_first_func(
    (
      #|(module
      #|  (func
      #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
      #|    nop))
      #|),
    ),
  )
  let sinkables = simplify_locals_new_sinkables(func)
  let effects = {
    mask: @ir.EFFECT_MASK_LOCAL_STATE,
    local_reads: [0],
    local_writes: [1],
    global_reads: [],
    global_writes: [],
  }

  assert_false(simplify_locals_sinkables_should_bulk_clear(sinkables))

  simplify_locals_sinkables_set(sinkables, 1, { node_id: 1, effects })
  simplify_locals_sinkables_set(sinkables, 2, { node_id: 2, effects })
  assert_false(simplify_locals_sinkables_should_bulk_clear(sinkables))

  simplify_locals_sinkables_set(sinkables, 3, { node_id: 3, effects })
  assert_true(simplify_locals_sinkables_should_bulk_clear(sinkables))

  simplify_locals_clear_sinkables(sinkables)
  @debug.assert_eq(sinkables.active_locals.length(), 0)
  @debug.assert_eq(sinkables.local_read_counts[0], 0)
  @debug.assert_eq(sinkables.local_write_counts[1], 0)
}

///|
test "simplify-locals deferred follow-up records only scanned first-cycle sets" {
  // Protected embedded-tee child regions are intentionally skipped by the
  // root-only SLNS path. Their internal multi-use local.set traffic must not be
  // counted as a deferred root follow-up candidate, otherwise the pass pays for
  // a second protected root scan that cannot touch those child nodes.
  let func = pass_test_lift_first_func(
    (
      #|(module
      #|  (func (param i32) (local i32 i32)
      #|    local.get 0
      #|    if
      #|      i32.const 7
      #|      local.set 1
      #|      local.get 1
      #|      drop
      #|      local.get 1
      #|      drop
      #|      i32.const 9
      #|      local.tee 2
      #|      i32.eqz
      #|      drop
      #|      local.get 2
      #|      drop
      #|    end))
      #|),
    ),
  )
  let detached : Array[Int] = []
  let deferred_sets : Array[Int] = []
  assert_false(
    simplify_locals_scan_region(
      func,
      @ir.HotRegionRef::root(),
      simplify_locals_new_sinkables(func),
      true,
      simplify_locals_count_local_gets(func),
      detached,
      SimplifyLocalsPolicy::new(true, true, true),
      true,
      false,
      deferred_sets,
    ),
  )
  @debug.assert_eq(deferred_sets.length(), 0)
}

///|
fn simplify_locals_wbtest_run_nostructure(func : @ir.HotFunc) -> Unit {
  let ctx = HotPassContext::new(
    simplify_locals_nostructure_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      abort("expected simplify-locals-nostructure success, got \{err}")
  }
}

///|
fn simplify_locals_wbtest_try_fixture(throwing : Bool) -> @ir.HotFunc {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new(locals=@ir.HotLocals::new(locals=[i32_type]))
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let value_id = if throwing {
    @ir.hot_build_call(func, 0, [i32_type], [])
  } else {
    @ir.hot_build_const_i32(func, @lib.I32(7))
  }
  @ir.hot_root_append(func, @ir.hot_build_local_set(func, 0, value_id))
  @ir.hot_root_append(
    func,
    @ir.hot_build_try(
      func,
      @lib.BlockType::val_type(i32_type),
      [@ir.hot_build_local_get(func, 0)],
      catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(9))]),
    ),
  )
  func
}

///|
fn simplify_locals_wbtest_try_catch_parent_fixture() -> @ir.HotFunc {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new(locals=@ir.HotLocals::new(locals=[i32_type]))
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  @ir.hot_root_append(
    func,
    @ir.hot_build_local_set(func, 0, @ir.hot_build_const_i32(func, @lib.I32(7))),
  )
  @ir.hot_root_append(
    func,
    @ir.hot_build_try(
      func,
      @lib.BlockType::val_type(i32_type),
      [
        @ir.hot_build_throw(func, @lib.TagIdx::new(0U), []),
        @ir.hot_build_const_i32(func, @lib.I32(0)),
      ],
      catch_body=Some([@ir.hot_build_local_get(func, 0)]),
    ),
  )
  func
}

///|
fn simplify_locals_wbtest_try_catch_inner_fixture() -> @ir.HotFunc {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new(locals=@ir.HotLocals::new(locals=[i32_type]))
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  @ir.hot_root_append(
    func,
    @ir.hot_build_try(
      func,
      @lib.BlockType::val_type(i32_type),
      [
        @ir.hot_build_throw(func, @lib.TagIdx::new(0U), []),
        @ir.hot_build_const_i32(func, @lib.I32(0)),
      ],
      catch_body=Some([
        @ir.hot_build_local_set(
          func,
          0,
          @ir.hot_build_const_i32(func, @lib.I32(7)),
        ),
        @ir.hot_build_local_get(func, 0),
      ]),
    ),
  )
  func
}

///|
fn simplify_locals_wbtest_try_table_catch_list_parent_fixture() -> @ir.HotFunc {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new(locals=@ir.HotLocals::new(locals=[i32_type]))
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  @ir.hot_root_append(
    func,
    @ir.hot_build_local_set(func, 0, @ir.hot_build_const_i32(func, @lib.I32(7))),
  )
  @ir.hot_root_append(
    func,
    @ir.hot_build_try_table(
      func,
      @lib.BlockType::val_type(i32_type),
      [],
      [@ir.hot_build_const_i32(func, @lib.I32(0))],
      catch_list_body=[@ir.hot_build_local_get(func, 0)],
    ),
  )
  func
}

///|
fn simplify_locals_wbtest_try_table_catch_list_inner_fixture() -> @ir.HotFunc {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new(locals=@ir.HotLocals::new(locals=[i32_type]))
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  @ir.hot_root_append(
    func,
    @ir.hot_build_try_table(
      func,
      @lib.BlockType::val_type(i32_type),
      [],
      [@ir.hot_build_const_i32(func, @lib.I32(0))],
      catch_list_body=[
        @ir.hot_build_local_set(
          func,
          0,
          @ir.hot_build_const_i32(func, @lib.I32(7)),
        ),
        @ir.hot_build_local_get(func, 0),
      ],
    ),
  )
  func
}

///|
test "simplify-locals-nostructure sinks nonthrowing set into legacy try body" {
  // Binaryen version_130 sinks a pure pending value into a legacy `try` body.
  // The public WAT path desugars legacy `try` before HOT, so this direct-HOT
  // fixture locks the existing `HotOp::Try` implementation rather than adding a
  // red-first behavior fix.
  let func = simplify_locals_wbtest_try_fixture(false)
  simplify_locals_wbtest_run_nostructure(func)

  match @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).op {
    @ir.HotOp::Nop => ()
    other => fail("expected dead root local.set to become nop, got \{other}")
  }
  let try_id = @ir.hot_root_get(func, 1)
  match @ir.hot_node_get(func, try_id).op {
    @ir.HotOp::Try => ()
    other => fail("expected legacy try root, got \{other}")
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 1)
  match @ir.hot_node_get(func, @ir.hot_region_get(func, body_ref, 0)).op {
    @ir.HotOp::Const => ()
    other => fail("expected try body local.get replaced by const, got \{other}")
  }
}

///|
test "simplify-locals-nostructure keeps throwing set before legacy try body" {
  // Calls may throw, so the pending value must stay outside the legacy try
  // handler just as Binaryen version_130 keeps `local.set(call)` before `try`.
  let func = simplify_locals_wbtest_try_fixture(true)
  simplify_locals_wbtest_run_nostructure(func)

  match @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).op {
    @ir.HotOp::LocalSet => ()
    other => fail("expected throwing root local.set to remain, got \{other}")
  }
  let try_id = @ir.hot_root_get(func, 1)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 1)
  match @ir.hot_node_get(func, @ir.hot_region_get(func, body_ref, 0)).op {
    @ir.HotOp::LocalGet => ()
    other => fail("expected try body local.get to remain, got \{other}")
  }
}

///|
test "simplify-locals-nostructure keeps parent set out of legacy try catch" {
  // Binaryen version_130 does not sink a pending pre-try value into a legacy
  // catch body. The catch region is scanned with fresh sinkables, so the parent
  // carrier remains available to exceptional control without moving into it.
  let func = simplify_locals_wbtest_try_catch_parent_fixture()
  simplify_locals_wbtest_run_nostructure(func)

  match @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).op {
    @ir.HotOp::LocalSet => ()
    other => fail("expected parent local.set to remain, got \{other}")
  }
  let try_id = @ir.hot_root_get(func, 1)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 1)
  match @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 0)).op {
    @ir.HotOp::LocalGet => ()
    other => fail("expected catch local.get to remain, got \{other}")
  }
}

///|
test "simplify-locals-nostructure optimizes local traffic inside legacy try catch" {
  // The catch boundary is fresh, not disabled: Binaryen version_130 still sinks
  // local traffic that is produced and consumed wholly inside the catch body.
  let func = simplify_locals_wbtest_try_catch_inner_fixture()
  simplify_locals_wbtest_run_nostructure(func)

  let try_id = @ir.hot_root_get(func, 0)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 2)
  match @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 0)).op {
    @ir.HotOp::Nop => ()
    other => fail("expected catch local.set to become nop, got \{other}")
  }
  match @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 1)).op {
    @ir.HotOp::Const => ()
    other => fail("expected catch local.get replaced by const, got \{other}")
  }
}

///|
test "simplify-locals-nostructure keeps parent set out of try_table catch list" {
  // Starshine's HOT `try_table` catch-list region is a branch-target region, not
  // ordinary fallthrough body code. Keep parent sinkables out of that region just
  // as public Binaryen catch bodies do not inherit pre-try sinkables.
  let func = simplify_locals_wbtest_try_table_catch_list_parent_fixture()
  simplify_locals_wbtest_run_nostructure(func)

  match @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).op {
    @ir.HotOp::LocalSet => ()
    other => fail("expected parent local.set to remain, got \{other}")
  }
  let try_id = @ir.hot_root_get(func, 1)
  let catch_ref = @ir.hot_region_catch_list_ref(func, try_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 1)
  match @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 0)).op {
    @ir.HotOp::LocalGet => ()
    other => fail("expected catch-list local.get to remain, got \{other}")
  }
}

///|
test "simplify-locals-nostructure optimizes local traffic inside try_table catch list" {
  // The catch-list scan is fresh but still active for local traffic whose
  // producer and consumer both live inside Starshine's HOT catch-list region.
  let func = simplify_locals_wbtest_try_table_catch_list_inner_fixture()
  simplify_locals_wbtest_run_nostructure(func)

  let try_id = @ir.hot_root_get(func, 0)
  let catch_ref = @ir.hot_region_catch_list_ref(func, try_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 2)
  match @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 0)).op {
    @ir.HotOp::Nop => ()
    other => fail("expected catch-list local.set to become nop, got \{other}")
  }
  match @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 1)).op {
    @ir.HotOp::Const => ()
    other =>
      fail("expected catch-list local.get replaced by const, got \{other}")
  }
}

///|
test "simplify-locals folds admitted adjacent set get pairs to tees" {
  let target = @lib.LocalIdx::new(2U)
  let input = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(48),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(target),
    @lib.Instruction::local_get(target),
    @lib.Instruction::drop(),
  ]
  let (rewritten, count) = run_hot_pipeline_raw_simplify_locals_rewrite_adjacent_set_gets(
    input,
  )
  inspect(count, content="1")
  inspect(
    rewritten,
    content=(
      #|[(local.get (Local 0)), (i32.const I32(48)), i32.add, (local.tee (Local 2)), drop]
    ),
  )
}

///|
test "simplify-locals WAGO countdown guard admits local-only classifiers" {
  let instrs : Array[@lib.Instruction] = []
  for local_idx = 0; local_idx < 6; local_idx = local_idx + 1 {
    instrs.push(@lib.Instruction::i32_const(local_idx))
    instrs.push(
      @lib.Instruction::local_set(@lib.LocalIdx::new(local_idx.to_uint())),
    )
  }
  for if_idx = 0; if_idx < 2; if_idx = if_idx + 1 {
    instrs.push(@lib.Instruction::i32_const(1))
    instrs.push(@lib.Instruction::if_(@lib.BlockType::void_(), [], None))
  }
  while instrs.length() < 32 {
    instrs.push(@lib.Instruction::nop())
  }
  assert_false(
    run_hot_pipeline_raw_simplify_locals_has_wago_expansion_hazard(instrs),
  )
}
