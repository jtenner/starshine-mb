///|
test "operand swaps preserve exact use sites and effect summaries" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32 i32) (result i32) local.get 0 local.get 1 i32.add))",
  )
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  let root = @ir.hot_root_get(func, 0)
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  let uses = pass_require_use_def(ctx, func)
  let effects = pass_require_effects(ctx, func)
  assert_true(pass_swap_scalar_operands(ctx, func, root))
  assert_eq(@ir.hot_child_get(func, root, 0), rhs)
  assert_eq(@ir.hot_child_get(func, root, 1), lhs)
  assert_true(
    physical_equal(uses.node_uses, pass_require_use_def(ctx, func).node_uses),
  )
  assert_true(
    physical_equal(
      effects.node_masks,
      pass_require_effects(ctx, func).node_masks,
    ),
  )
  @debug.assert_eq(
    pass_require_use_def(ctx, func),
    @ir.cache_get_or_build_use_def(@ir.HotAnalysisCache::new(), func),
  )
  @debug.assert_eq(
    pass_require_effects(ctx, func),
    @ir.cache_get_or_build_effects(@ir.HotAnalysisCache::new(), func),
  )
  assert_true(@ir.hot_verify_cached_analyses(func, ctx.cache) is Ok(_))
}

///|
test "operand swaps leave control-bearing operands to general mutation" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) (result i32) local.get 0 block (result i32) i32.const 1 end i32.add))",
  )
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  let root = @ir.hot_root_get(func, 0)
  let before = @ir.hot_lower_func_unverified(func)
  assert_false(pass_swap_scalar_operands(ctx, func, root))
  @debug.assert_eq(@ir.hot_lower_func_unverified(func), before)
}

///|
test "OI cached purity follows child mutations and dead nodes" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32 i32) (result i32) local.get 0 i32.eqz local.get 1 i32.eqz i32.add))",
  )
  let dead = @bitset.BitSet::new(@ir.hot_node_count(func))
  let cache = OiPurityCache::new()
  let root = @ir.hot_root_get(func, 0)
  assert_true(
    OiSideEffectFreeExpressionFact::proves_node_free(
      func,
      dead,
      root,
      purity_cache=Some(cache),
    ),
  )
  let original = @ir.hot_child_get(func, root, 0)
  let effect = @ir.hot_build_local_tee(func, 0, original)
  @ir.hot_child_set(func, root, 0, effect)
  assert_false(
    OiSideEffectFreeExpressionFact::proves_node_free(
      func,
      dead,
      root,
      purity_cache=Some(cache),
    ),
  )
  @ir.hot_child_set(func, root, 0, original)
  assert_true(
    OiSideEffectFreeExpressionFact::proves_node_free(
      func,
      dead,
      root,
      purity_cache=Some(cache),
    ),
  )
  dead[root] = true
  assert_false(
    OiSideEffectFreeExpressionFact::proves_node_free(
      func,
      dead,
      root,
      purity_cache=Some(cache),
    ),
  )
}

///|
test "compound operand swaps preserve exact effects" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32 i32) (result i32) local.get 0 i32.eqz local.get 1 i32.eqz i32.add))",
  )
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  let root = @ir.hot_root_get(func, 0)
  let uses = pass_require_use_def(ctx, func)
  let effects = pass_require_effects(ctx, func)
  assert_true(pass_swap_scalar_operands(ctx, func, root))
  assert_true(
    physical_equal(uses.node_uses, pass_require_use_def(ctx, func).node_uses),
  )
  @debug.assert_eq(
    pass_require_use_def(ctx, func),
    @ir.cache_get_or_build_use_def(@ir.HotAnalysisCache::new(), func),
  )
  assert_true(
    physical_equal(
      effects.node_masks,
      pass_require_effects(ctx, func).node_masks,
    ),
  )
  @debug.assert_eq(
    pass_require_effects(ctx, func),
    @ir.cache_get_or_build_effects(@ir.HotAnalysisCache::new(), func),
  )
  assert_true(@ir.hot_verify_cached_analyses(func, ctx.cache) is Ok(_))
}

///|
test "scalar swaps rebuild ordered reads when both operands use one local" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) (result i32) local.get 0 i32.eqz local.get 0 i32.eqz i32.add))",
  )
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  let root = @ir.hot_root_get(func, 0)
  ignore(pass_require_use_def(ctx, func))
  ignore(pass_require_effects(ctx, func))
  assert_true(pass_swap_scalar_operands(ctx, func, root))
  @debug.assert_eq(
    pass_require_use_def(ctx, func),
    @ir.cache_get_or_build_use_def(@ir.HotAnalysisCache::new(), func),
  )
}

///|
test "scalar swap opcode changes do not preserve stale trap effects" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32 i32) (result i32) local.get 0 local.get 1 i32.add))",
  )
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  let root = @ir.hot_root_get(func, 0)
  let effects = pass_require_effects(ctx, func)
  assert_true(
    pass_swap_scalar_operands(
      ctx,
      func,
      root,
      instr=Some(@lib.Instruction::i32_div_s()),
    ),
  )
  let after = pass_require_effects(ctx, func)
  assert_false(physical_equal(effects.node_masks, after.node_masks))
  @debug.assert_eq(
    after,
    @ir.cache_get_or_build_effects(@ir.HotAnalysisCache::new(), func),
  )
}

///|
test "pass value operand mapping includes retained legacy try entries" {
  let func = @ir.HotFunc::new()
  let entry = @ir.hot_build_const_i32(func, @lib.I32(7))
  let node = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [],
    catch_body=Some([]),
  )
  ignore(
    @ir.hot_replace_child_span(func, node, [
      @ir.hot_child_get(func, node, 0),
      @ir.hot_child_get(func, node, 1),
      entry,
    ]),
  )
  assert_eq(pass_value_operand_count(func, node), 1)
  assert_eq(pass_value_operand_slot(@ir.hot_node_get(func, node), 0), 2)
  assert_eq(
    @ir.hot_child_get(
      func,
      node,
      pass_value_operand_slot(@ir.hot_node_get(func, node), 0),
    ),
    entry,
  )
}

///|
test "pass value operand mapping includes retained try table entries" {
  let func = @ir.HotFunc::new()
  let entry = @ir.hot_build_const_i32(func, @lib.I32(7))
  let node = @ir.hot_build_try_table(func, @lib.BlockType::void_(), [], [])
  ignore(
    @ir.hot_replace_child_span(func, node, [
      @ir.hot_child_get(func, node, 0),
      @ir.hot_child_get(func, node, 1),
      entry,
    ]),
  )
  assert_eq(pass_value_operand_count(func, node), 1)
  assert_eq(pass_value_operand_slot(@ir.hot_node_get(func, node), 0), 2)
}

///|
test "OI purity retains evaluated block entries after body cleanup" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) (result i32) (local i32) local.get 0 local.tee 1 block (param i32) (result i32) drop i32.const 3 end))",
  )
  let root = @ir.hot_root_get(func, 0)
  // Header evaluation remains part of the control after body cleanup.
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, root), [
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  ])
  let dead = @bitset.BitSet::new(@ir.hot_node_count(func))
  assert_false(
    OiSideEffectFreeExpressionFact::proves_node_free(func, dead, root),
  )
  assert_false(
    OiSideEffectFreeExpressionFact::proves_node_free(
      func,
      dead,
      root,
      purity_cache=Some(OiPurityCache::new()),
    ),
  )
}

///|
test "subtree effect query matches the full arena query" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) (result i32) (local i32) i32.const 7 local.set 1 local.get 0 if (result i32) local.get 1 else local.get 0 i32.const 2 i32.div_s end))",
  )
  for node in 0..<@ir.hot_node_count(func) {
    if @ir.hot_node_is_live(func, node) {
      assert_eq(
        @ir.effects_for_node_subtree(func, node),
        @ir.effects_for_node(func, node),
      )
    }
  }
}

///|
test "subtree effect query handles shared scalar children" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32 i32) (result i32) local.get 0 i32.eqz local.get 1 i32.eqz i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  @ir.hot_child_set(func, root, 1, @ir.hot_child_get(func, root, 0))
  assert_eq(
    @ir.effects_for_node_subtree(func, root),
    @ir.effects_for_node(func, root),
  )
}
