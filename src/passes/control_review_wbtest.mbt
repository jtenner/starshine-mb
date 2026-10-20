///|
test "SSA direct hot passes keep non-null local reads valid outside a write frame" {
  for
    control in [
      "block local.get 0 local.set 1 end", "i32.const 1 if local.get 0 local.set 1 else local.get 0 local.set 1 end",
      "loop local.get 0 local.set 1 end",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func (param (ref extern)) (result (ref extern)) (local (ref extern)) local.get 0 local.set 1 \{control} local.get 1))",
    )
    @validate.validate_module(input).unwrap()
    for full in [false, true] {
      let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
      let descriptor = if full {
        ssa_full_descriptor()
      } else {
        ssa_nomerge_descriptor()
      }
      let ctx = HotPassContext::new(
        descriptor,
        @ir.HotAnalysisCache::new(),
        HotPipelineVerifyPolicy::final_module_only(),
        false,
        fn(_) { () },
        module_ctx=Some(@ir.hot_module_context_from_module(input)),
      )
      let result = if full {
        ssa_full_run(ctx, func)
      } else {
        ssa_nomerge_run(ctx, func)
      }
      assert_true(result.changed)
      let output = input.with_code_sec(
        @lib.CodeSec::new([@ir.hot_lower_func(func)]),
      )
      match @validate.validate_module(output) {
        Ok(_) => ()
        Err(err) => fail("SSA full=\{full} control=\{control}: \{err}")
      }
    }
  }
}

///|
test "SSA dispatcher retains fresh non-null definitions across write frames" {
  let source = "(module (func (param (ref extern)) (result (ref extern)) (local (ref extern)) local.get 0 local.set 1 block local.get 0 local.set 1 end local.get 1))"
  for pass in ["ssa", "ssa-nomerge"] {
    let trace : Array[String] = []
    let output = pass_test_run_pipeline(
      source,
      [pass],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ).unwrap()
    @validate.validate_module(output).unwrap()
    let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
    assert_true(locals.length() > 1)
    assert_false(trace.any(fn(line) { line.contains("rollback") }))
  }
}

///|
test "remove unused branches retains a used if label during suffix voidification" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) block local.get 0 if local.get 0 br_if 0 i32.const 7 return else br 1 end unreachable end i32.const 9))",
  )
  @validate.validate_module(input).unwrap()
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let block_id = @ir.hot_root_get(func, 0)
  let body = @ir.hot_region_body_ref(func, block_id)
  let ctx = control_review_brs_ctx()
  let refs = remove_unused_brs_compute_cycle_scan(func).label_refs
  assert_false(
    remove_unused_brs_try_voidify_if_block_exit_unreachable_suffix(
      ctx, func, body, 0, refs,
    ),
  )
  let output = input.with_code_sec(
    @lib.CodeSec::new([@ir.hot_lower_func(func)]),
  )
  @validate.validate_module(output).unwrap()
  let dispatched = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "remove-unused-brs",
  ]).unwrap()
  @validate.validate_module(dispatched).unwrap()
}

///|
test "remove unused branches retains a used value if label during voidification" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) block (result i32) unreachable local.get 0 if (result i32) i32.const 9 local.get 0 br_if 0 drop i32.const 7 return else unreachable br 1 end end))",
  )
  @validate.validate_module(input).unwrap()
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let block_id = @ir.hot_root_get(func, 0)
  let body = @ir.hot_region_body_ref(func, block_id)
  let ctx = control_review_brs_ctx()
  let refs = remove_unused_brs_compute_cycle_scan(func).label_refs
  assert_false(
    remove_unused_brs_try_voidify_tail_value_if_block_exit(
      ctx, func, body, refs,
    ),
  )
  let output = input.with_code_sec(
    @lib.CodeSec::new([@ir.hot_lower_func(func)]),
  )
  @validate.validate_module(output).unwrap()
}

///|
test "merge blocks preserves negative loop facts after unrelated removals" {
  let func = pass_test_lift_first_func(
    "(module (func block block nop end end block nop end))",
  )
  let workspace = MergeBlocksBranchScanWorkspace::new(
    loop_changes_are_removals=true,
  )
  let root = @ir.HotRegionRef::root()
  let visits = [0]
  assert_false(
    merge_blocks_region_contains_loop(
      func,
      root,
      workspace=Some(workspace),
      visits=Some(visits),
    ),
  )
  let first_visits = visits[0]
  let second = @ir.hot_root_get(func, 1)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, second), [])
  assert_false(
    merge_blocks_region_contains_loop(
      func,
      root,
      workspace=Some(workspace),
      visits=Some(visits),
    ),
  )
  // Removing roots cannot introduce a loop into any previously loop-free node.
  assert_eq(visits[0], first_visits)
}

///|
fn control_review_brs_ctx() -> HotPassContext {
  HotPassContext::new(
    remove_unused_brs_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
}

///|
test "merge loop cache rechecks insertions outside a removal-only pass" {
  let func = pass_test_lift_first_func("(module (func block nop end))")
  let workspace = MergeBlocksBranchScanWorkspace::new()
  let root = @ir.HotRegionRef::root()
  assert_false(
    merge_blocks_region_contains_loop(func, root, workspace=Some(workspace)),
  )
  let body = @ir.hot_region_body_ref(func, @ir.hot_root_get(func, 0))
  @ir.hot_region_replace_body(func, body, [
    @ir.hot_build_loop(func, @lib.BlockType::void_(), []),
  ])
  assert_true(
    merge_blocks_region_contains_loop(func, root, workspace=Some(workspace)),
  )
}

///|
test "raw SSA scope repair retains non-null storage initialized in the same frame" {
  let input = pass_test_module_from_wat(
    "(module (func (param (ref extern)) (result (ref extern)) (local (ref extern)) local.get 0 local.set 1 local.get 1))",
  )
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let original = input.code_sec.unwrap().0[0]
  let (repaired, changed) = ssa_repair_raw_nondefaultable_local_scopes(
    original,
    [@ir.hot_local_type(func, 0).unwrap()],
  )
  assert_false(changed)
  let @lib.Func(locals, @lib.Expr(body)) = repaired
  assert_eq(locals.get(0), @ir.hot_local_type(func, 1).unwrap())
  assert_eq(body.length(), 3)
}

///|
test "flatten ownership index refreshes after new consumers and removed roots" {
  let func = pass_test_lift_first_func(
    "(module (func block (result i32 i32) i32.const 1 i32.const 2 end drop drop))",
  )
  let state = FlattenRewriteState::new(func)
  let mut control = -1
  for node in 0..<@ir.hot_node_count(func) {
    if @ir.hot_node_is_live(func, node) &&
      @ir.hot_node_result_arity(func, node) == 2 &&
      @ir.hot_node_kind_is_control(func, node) {
      control = node
      break
    }
  }
  assert_true(control >= 0)
  let index = flatten_ownership_index(func, Some(state))
  let before = index.sites.get(control).unwrap().length()
  let extra = @ir.hot_build_drop(func, control)
  @ir.hot_root_append(func, extra)
  let changed = flatten_ownership_index(func, Some(state))
  assert_eq(changed.sites.get(control).unwrap().length(), before + 1)
  assert_false(
    flatten_multivalue_control_has_exclusive_dropped_region_span(
      func,
      control,
      state=Some(state),
    ),
  )
  ignore(
    @ir.hot_region_splice(
      func,
      @ir.HotRegionRef::root(),
      @ir.hot_root_count(func) - 1,
      1,
      [],
    ),
  )
  @ir.hot_delete_node(func, extra)
  let restored = flatten_ownership_index(func, Some(state))
  assert_eq(restored.sites.get(control).unwrap().length(), before)
}

///|
test "flatten counts and spills rich Block and If entry operands" {
  for
    source in [
      "(module (type $entry (func (param i32 i32))) (func i32.const 1 i32.const 2 i32.add i32.const 3 block (type $entry) drop drop end))",
      "(module (type $entry (func (param i32 i32))) (func block (result i32) i32.const 7 end i32.const 3 block (type $entry) drop drop end))",
      "(module (type $entry (func (param i32))) (func i32.const 1 i32.const 2 i32.add i32.const 0 if (type $entry) drop else drop end))",
    ] {
    let input = pass_test_module_from_wat(source)
    let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
    let root = @ir.hot_root_get(func, 0)
    let header_slot = if @ir.hot_node_get(func, root).op is @ir.HotOp::If {
      3
    } else {
      0
    }
    assert_false(
      flatten_node_is_simple_operand(
        func,
        @ir.hot_child_get(func, root, header_slot),
      ),
    )
    let ctx = HotPassContext::new(
      flatten_descriptor(),
      @ir.HotAnalysisCache::new(),
      HotPipelineVerifyPolicy::after_each_pass(),
      false,
      fn(_) { () },
      module_ctx=Some(@ir.hot_module_context_from_module(input)),
    )
    assert_true(flatten_run(ctx, func).changed)
    assert_true(
      flatten_node_is_simple_operand(
        func,
        @ir.hot_child_get(func, root, header_slot),
      ),
    )
    let output = input.with_code_sec(
      @lib.CodeSec::new([@ir.hot_lower_func(func)]),
    )
    @validate.validate_module(output).unwrap()
  }
}

///|
test "merge blocks preserves positive loop facts after unrelated removals" {
  let func = pass_test_lift_first_func(
    "(module (func block block loop nop end end end block nop end))",
  )
  let workspace = MergeBlocksBranchScanWorkspace::new(
    loop_changes_are_removals=true,
  )
  let region = @ir.hot_region_body_ref(func, @ir.hot_root_get(func, 0))
  let visits = [0]
  assert_true(
    merge_blocks_region_contains_loop(
      func,
      region,
      workspace=Some(workspace),
      visits=Some(visits),
    ),
  )
  let before = visits[0]
  @ir.hot_region_replace_body(
    func,
    @ir.hot_region_body_ref(func, @ir.hot_root_get(func, 1)),
    [],
  )
  assert_true(
    merge_blocks_region_contains_loop(
      func,
      region,
      workspace=Some(workspace),
      visits=Some(visits),
    ),
  )
  assert_eq(visits[0], before)
}

///|
test "merge blocks invalidates a positive loop witness when the loop is removed" {
  let func = pass_test_lift_first_func(
    "(module (func block loop nop nop end end))",
  )
  let workspace = MergeBlocksBranchScanWorkspace::new(
    loop_changes_are_removals=true,
  )
  let region = @ir.hot_region_body_ref(func, @ir.hot_root_get(func, 0))
  let visits = [0]
  assert_true(
    merge_blocks_region_contains_loop(
      func,
      @ir.HotRegionRef::root(),
      workspace=Some(workspace),
      visits=Some(visits),
    ),
  )
  assert_true(
    merge_blocks_flatten_branch_free_loop_body(
      func,
      region,
      0,
      pass_compute_label_used(func),
      [],
      None,
      workspace,
    ),
  )
  assert_false(
    merge_blocks_region_contains_loop(
      func,
      @ir.HotRegionRef::root(),
      workspace=Some(workspace),
      visits=Some(visits),
    ),
  )
}

///|
test "flatten captures a header call once for the header and its body aliases" {
  for
    control in [
      "i32.const 3 block (type $entry) drop drop end", "i32.const 0 if (type $entry_if) drop else drop end",
    ] {
    let input = pass_test_module_from_wat(
      "(module (type $entry (func (param i32 i32))) (type $entry_if (func (param i32))) (import \"env\" \"tick\" (func (result i32))) (func call 0 \{control}))",
    )
    let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(1U))
    let ctx = HotPassContext::new(
      flatten_descriptor(),
      @ir.HotAnalysisCache::new(),
      HotPipelineVerifyPolicy::after_each_pass(),
      false,
      fn(_) { () },
      module_ctx=Some(@ir.hot_module_context_from_module(input)),
    )
    assert_true(flatten_run(ctx, func).changed)
    let lowered = @ir.hot_lower_func(func)
    let @lib.Func(_, @lib.Expr(body)) = lowered
    assert_eq(run_hot_pipeline_raw_count_call_like(body), 1)
    match body[0] {
      @lib.Call(_) => ()
      _ => fail("the header call must remain before its control")
    }
    @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([lowered]))).unwrap()
  }
}

///|
test "flatten keeps the intentionally unsupported carried rich scalar write guard" {
  let func = pass_test_lift_first_func(
    "(module (global (mut i32) (i32.const 0)) (func i32.const 1 i32.const 2 i32.add i32.const 9 global.set 0 global.set 0))",
  )
  assert_true(
    FlattenCarriedScalarAcrossGlobalWriteFact::from_func(func).has_hazard,
  )
}

///|
test "flatten permits a rich scalar produced after an earlier global write" {
  let func = pass_test_lift_first_func(
    "(module (global (mut i32) (i32.const 0)) (func i32.const 9 global.set 0 i32.const 1 i32.const 2 i32.add global.set 0))",
  )
  assert_false(
    FlattenCarriedScalarAcrossGlobalWriteFact::from_func(func).has_hazard,
  )
}

///|
test "flatten sparse membership keeps zero and high index bits distinct" {
  let roots = FlattenSparseMembership::new()
  for
    pair in [
      (0, 0),
      (0, 0x7fffffff),
      (0x7fffffff, 0),
      (0x7fffffff, 0x7fffffff),
      (1, 19),
      (4, 19),
    ] {
    assert_true(flatten_sequenced_root_record(roots, pair.0, pair.1))
  }
  for
    pair in [
      (0, 0),
      (0, 0x7fffffff),
      (0x7fffffff, 0),
      (0x7fffffff, 0x7fffffff),
      (1, 19),
      (4, 19),
    ] {
    assert_true(flatten_sequenced_root_contains(roots, pair.0, pair.1))
    assert_false(flatten_sequenced_root_record(roots, pair.0, pair.1))
  }
  assert_false(flatten_sequenced_root_contains(roots, 2, 19))
  assert_false(flatten_sequenced_root_record(roots, -1, 0))
  assert_eq(roots.length(), 6)
  // Sparse high ids must not allocate storage indexed by the node id.
  assert_true(roots.capacity() <= 16)
  let payloads = FlattenSparseMembership::new()
  assert_true(flatten_terminal_payload_record(payloads, 0))
  assert_true(flatten_terminal_payload_record(payloads, 0x7fffffff))
  assert_true(flatten_terminal_payload_contains(payloads, 0))
  assert_true(flatten_terminal_payload_contains(payloads, 0x7fffffff))
  assert_false(flatten_terminal_payload_contains(payloads, -1))
}

///|
test "flatten sparse membership retains entries through growth" {
  let roots = FlattenSparseMembership::new()
  for node in 0..<64 {
    assert_true(flatten_sequenced_root_record(roots, node % 3, node * 17))
  }
  for node in 0..<64 {
    assert_true(flatten_sequenced_root_contains(roots, node % 3, node * 17))
    assert_false(
      flatten_sequenced_root_contains(roots, (node + 1) % 3, node * 17),
    )
    assert_false(flatten_sequenced_root_record(roots, node % 3, node * 17))
  }
  assert_eq(roots.length(), 64)
}

///|
test "flatten routes independent tuple operand trees in source order" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"pair\" (func $pair (param i32) (result i32 i32))) (func (export \"run\") (param i32) (result i32) block (result i32 i32) local.get 0 call $pair end i32.add drop block (result i32 i32) local.get 0 call $pair end i32.add))",
  )
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(1U))
  let state = FlattenRewriteState::new(func)
  assert_true(flatten_prepare_fixed_operand_ownership(func, state))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
    module_ctx=Some(@ir.hot_module_context_from_module(input)),
  )
  assert_true(flatten_run(ctx, func).changed)
  let output = input.with_code_sec(
    @lib.CodeSec::new([@ir.hot_lower_func(func)]),
  )
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 6)
  assert_eq(body.length(), 10)
  for
    source in [
      "(module (func block (result i32 i32) i32.const 1 i32.const 2 end drop drop))",
      "(module (func block (result i32 i32) i32.const 1 i32.const 2 br 0 end i32.add drop))",
      "(module (func (local i32) block (result i32 i32) i32.const 1 local.tee 0 i32.const 2 end i32.add drop))",
      "(module (type $entry (func (param i32) (result i32 i32))) (func i32.const 1 i32.const 2 i32.add block (type $entry) drop i32.const 2 i32.const 3 end i32.add drop))",
    ] {
    let fallback = pass_test_lift_first_func(source)
    assert_false(
      flatten_prepare_fixed_operand_ownership(
        fallback,
        FlattenRewriteState::new(fallback),
      ),
    )
  }
}

///|
fn control_review_constant_pair_arguments(
  body : Array[@lib.Instruction],
  arguments : Array[Int32],
) -> Unit {
  for idx in 0..<body.length() {
    match body[idx] {
      @lib.Call(_) =>
        match body[idx - 1] {
          @lib.I32Const(value) => arguments.push(value.0)
          _ => ()
        }
      @lib.Block(_, @lib.Expr(nested)) =>
        control_review_constant_pair_arguments(nested, arguments)
      @lib.If(_, then_, else_) => {
        control_review_constant_pair_arguments(then_, arguments)
        match else_ {
          Some(nested) =>
            control_review_constant_pair_arguments(nested, arguments)
          None => ()
        }
      }
      _ => ()
    }
  }
}

///|
test "flatten fixed operand census preserves nested Block and If call order" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"pair\" (func $pair (param i32) (result i32 i32))) (func (param i32) block (result i32 i32) block (result i32 i32) i32.const 11 call $pair end i32.add call $pair end i32.add drop local.get 0 if (result i32 i32) i32.const 21 call $pair else i32.const 22 call $pair end i32.add drop))",
  )
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(1U))
  let state = FlattenRewriteState::new(func)
  // The synthetic If arm holders have structural ownership, not operand lanes.
  assert_true(flatten_prepare_fixed_operand_ownership(func, state))
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
    module_ctx=Some(@ir.hot_module_context_from_module(input)),
  )
  assert_true(flatten_run(ctx, func).changed)
  let output = input.with_code_sec(
    @lib.CodeSec::new([@ir.hot_lower_func(func)]),
  )
  @validate.validate_module(output).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  let arguments : Array[Int32] = []
  control_review_constant_pair_arguments(body, arguments)
  assert_eq(arguments, [11, 21, 22])
}

///|
test "flatten shared scalar input uses revision ownership checks" {
  let func = pass_test_lift_first_func(
    "(module (func block (result i32 i32) i32.const 1 i32.const 2 end i32.add drop i32.const 3 i32.const 4 i32.add drop))",
  )
  let root = @ir.hot_root_get(func, 1)
  let add = @ir.hot_child_get(func, root, 0)
  @ir.hot_child_set(func, add, 1, @ir.hot_child_get(func, add, 0))
  assert_false(
    flatten_prepare_fixed_operand_ownership(
      func,
      FlattenRewriteState::new(func),
    ),
  )
}

///|
test "flatten cached operand ownership rechecks a changed live span" {
  let func = pass_test_lift_first_func(
    "(module (func block (result i32 i32) i32.const 1 i32.const 2 end i32.add drop))",
  )
  let parent = @ir.hot_child_get(func, @ir.hot_root_get(func, 0), 0)
  let control = @ir.hot_child_get(func, parent, 0)
  let state = FlattenRewriteState::new(func)
  assert_true(flatten_prepare_fixed_operand_ownership(func, state))
  // Exercise the private stable mode against an adversarial stale owner.
  state.fixed_operand_ownership = true
  @ir.hot_child_set(func, parent, 0, @ir.hot_build_nop(func))
  assert_false(
    flatten_multivalue_control_has_exclusive_consumer_span(
      func,
      control,
      state=Some(state),
    ),
  )
  assert_false(
    flatten_multivalue_control_use_span_is_exclusive(
      func,
      parent,
      0,
      control,
      2,
      state=Some(state),
    ),
  )
}

///|
test "flatten fixed operand prefix retains captures before later effects" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"pair\" (func $pair (param i32) (result i32 i32))) (import \"env\" \"one\" (func $one (param i32) (result i32))) (import \"env\" \"effect\" (func $effect (param i32))) (func (export \"run\") (result i32) block (result i32 i32) i32.const 1 call $pair end i32.add drop i32.const 11 call $one i32.const 13 call $one i32.const 14 call $effect block (result i32 i32) i32.const 21 call $pair end i32.add i32.add i32.add))",
  )
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(3U))
  assert_true(
    flatten_prepare_fixed_operand_ownership(
      func,
      FlattenRewriteState::new(func),
    ),
  )
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
    module_ctx=Some(@ir.hot_module_context_from_module(input)),
  )
  assert_true(flatten_run(ctx, func).changed)
  let output = input.with_code_sec(
    @lib.CodeSec::new([@ir.hot_lower_func(func)]),
  )
  @validate.validate_module(output).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  let arguments : Array[Int32] = []
  control_review_constant_pair_arguments(body, arguments)
  assert_eq(arguments, [1, 11, 13, 14, 21])
}
