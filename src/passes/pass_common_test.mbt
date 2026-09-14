///|
fn pass_common_fixture_wat() -> String {
  "(module (func (param i32) (local i32) local.get 0 if i32.const 7 local.set 1 else nop end local.get 1 drop))"
}

///|
test "pass_require helpers build and reuse derived analyses" {
  let func = pass_test_lift_first_func(pass_common_fixture_wat())
  let ctx = HotPassContext::new(
    @ir.HotPassDescriptor::new("test"),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  let cfg0 = pass_require_cfg(ctx, func)
  let cfg1 = pass_require_cfg(ctx, func)
  let _dom = pass_require_dom(ctx, func)
  let _liveness = pass_require_liveness(ctx, func)
  let _ssa = pass_require_ssa(ctx, func)

  @debug.assert_eq(cfg0, cfg1)
  assert_true(ctx.cache.cfg is Some(_))
  assert_true(ctx.cache.dom is Some(_))
  assert_true(ctx.cache.liveness is Some(_))
  assert_true(ctx.cache.ssa is Some(_))
}

///|
test "pass_mark_mutated invalidates only declared analysis dependencies" {
  let func = pass_test_lift_first_func(pass_common_fixture_wat())
  let ctx = HotPassContext::new(
    @ir.HotPassDescriptor::new("test", invalidates=[@ir.HotAnalysis::effects()]),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  ignore(pass_require_cfg(ctx, func))
  ignore(pass_require_effects(ctx, func))

  pass_mark_mutated(ctx, func)

  assert_true(ctx.cache.cfg is Some(_))
  @debug.assert_eq(ctx.cache.effects, None)
}

///|
test "diagnostic pass verification rejects stale analysis after unmarked mutation" {
  let func = pass_test_lift_first_func(pass_common_fixture_wat())
  let ctx = HotPassContext::new(
    @ir.HotPassDescriptor::new("test", requires=[@ir.HotAnalysis::cfg()], invalidates=[
      @ir.HotAnalysis::cfg(),
    ]),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  ignore(pass_require_cfg(ctx, func))
  @ir.hot_root_append(func, @ir.hot_build_nop(func))

  match pass_verify_before_after(ctx, func) {
    Ok(_) => fail("expected stale analysis diagnostic")
    Err(err) => assert_true(err.contains("InvalidAnalysisRevision"), msg=err)
  }
}

///|
test "pass_splice_region and pass_delete_detached_nodes mark mutation" {
  let func = pass_test_lift_first_func("(module (func nop i32.const 4 drop))")
  let ctx = HotPassContext::new(
    @ir.HotPassDescriptor::new("test"),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  let rev0 = @ir.hot_revision_current(func)

  let removed = pass_splice_region(ctx, func, @ir.HotRegionRef::root(), 0, 1, [])
  pass_delete_detached_nodes(ctx, func, removed)

  assert_true(@ir.hot_revision_current(func) > rev0)
  @debug.assert_eq(@ir.hot_root_count(func), 1)
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected helper-mutated function to verify, got \{err}")
  }
}

///|
test "pass_compute_label_used marks branch and br_table targets" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) block local.get 0 br_table 0 0 end))",
  )
  let labels = pass_compute_label_used(func)
  let root_block = @ir.hot_root_get(func, 0)
  let label_id = @ir.hot_control_node_label(func, root_block)

  assert_true(label_id >= 0)
  assert_true(labels[label_id])
}

///|
test "pass_test helpers run public pipeline code" {
  let optimized = match
    pass_test_run_pipeline("(module (func (result i32) nop i32.const 9))", [
      "vacuum",
    ]) {
    Ok(mod) => mod
    Err(err) => fail("expected helper pipeline success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("nop"))
  assert_true(pretty.contains("I32(9)"))
}

///|
test "raw block cleanup retains every try_table catch target" {
  let label = @lib.LabelIdx::new(0U)
  for
    catch_ in [
      @lib.Catch::new(@lib.TagIdx::new(0U), label),
      @lib.Catch::ref_(@lib.TagIdx::new(0U), label),
      @lib.Catch::all(label),
      @lib.Catch::all_ref(label),
    ] {
    let body = [
      @lib.Instruction::try_table(
        @lib.BlockType::void_(),
        [catch_],
        @lib.Expr::new([]),
      ),
    ]
    assert_true(pass_raw_instrs_have_branch_control(body))
    let block = @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new(body),
    )
    assert_false(pass_raw_void_block_can_inline_before_unreachable(block))
    let input = [block, @lib.Instruction::unreachable_()]
    let (output, changed) = pass_raw_remove_dropped_unreachable_debris(input)
    assert_false(changed)
    @debug.assert_eq(output, input)
  }
  assert_false(
    pass_raw_instrs_have_branch_control([
      @lib.Instruction::try_table(
        @lib.BlockType::void_(),
        [],
        @lib.Expr::new([]),
      ),
    ]),
  )
}

///|
test "label-use scan handles label-free implicit returns and mixed labels" {
  let flat = pass_test_lift_first_func(
    "(module (func (result i32) i32.const 7 return))",
  )
  assert_eq(flat.labels.length(), 0)
  assert_eq(pass_compute_label_used(flat).length(), 0)
  let nested = pass_test_lift_first_func(
    "(module (func block block br 1 end end))",
  )
  let labels = pass_compute_label_used(nested)
  let outer = @ir.hot_root_get(nested, 0)
  let inner = @ir.hot_region_get(
    nested,
    @ir.hot_region_body_ref(nested, outer),
    0,
  )
  assert_true(labels[@ir.hot_control_node_label(nested, outer)])
  assert_false(labels[@ir.hot_control_node_label(nested, inner)])
}

///|
test "label-free precompute pipeline still folds arithmetic" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 4 i32.const 5 i32.add))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail(err)
  }
  let @lib.Func(_, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  assert_eq(body, [@lib.Instruction::i32_const(@lib.I32(9))])
}
