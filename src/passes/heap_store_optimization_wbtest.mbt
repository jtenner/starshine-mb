///|
test "heap-store-optimization external root context visits suffixes without prefixes" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  let prefix = @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 0))
  let suffix = @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1))
  let outer = @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 2))
  let external_roots = hso_new_external_roots()

  hso_external_roots_push(external_roots, [prefix, suffix], 1)
  assert_false(hso_external_roots_touch_local(func, external_roots, 0))
  assert_true(hso_external_roots_touch_local(func, external_roots, 1))
  assert_false(hso_external_roots_touch_local(func, external_roots, 2))

  hso_external_roots_push(external_roots, [outer], 0)
  assert_false(hso_external_roots_touch_local(func, external_roots, 0))
  assert_true(hso_external_roots_touch_local(func, external_roots, 1))
  assert_true(hso_external_roots_touch_local(func, external_roots, 2))

  hso_external_roots_pop(external_roots)
  assert_true(hso_external_roots_touch_local(func, external_roots, 1))
  assert_false(hso_external_roots_touch_local(func, external_roots, 2))
}

///|
test "heap-store-optimization bounds per-candidate chain scratch capacity" {
  @debug.assert_eq(hso_chain_scratch_capacity(0), 0)
  @debug.assert_eq(hso_chain_scratch_capacity(3), 3)
  @debug.assert_eq(hso_chain_scratch_capacity(4096), 8)
}

///|
test "heap-store-optimization reports rejected folds that trim unreachable tails" {
  let struct_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_([
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ]),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([struct_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([
            @lib.ValType::ref_null(@lib.HeapType::new(struct_type_idx)),
          ]),
          @lib.Expr::new([
            @lib.Instruction::struct_new_default(struct_type_idx),
            @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::br(@lib.LabelIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(2)),
              ]),
            ),
            @lib.Instruction::struct_set(struct_type_idx, @lib.U32::new(0U)),
          ]),
        ),
      ]),
    )
  @validate.validate_module(input).unwrap()
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    heap_store_optimization_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
    module_ctx=Some(@ir.hot_module_context_from_module(input)),
  )
  let before = @ir.hot_revision_current(func)

  assert_eq(heap_store_optimization_run(ctx, func), HotPassResult::changed())
  assert_true(@ir.hot_revision_current(func) > before)
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) => abort("expected trimmed HSO candidate to remain valid: \{err}")
  }
}

///|
test "heap-store-optimization bounds shared control DAG expansion without changing code" {
  let func = @ir.HotFunc::new()
  let mut shared = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  // Only 13 control nodes, but the old walk enters 8191 regions: each
  // occurrence recursively re-expands the same child region twice.
  for depth = 0; depth < 12; depth = depth + 1 {
    shared = @ir.hot_build_block(func, @lib.BlockType::void_(), [shared, shared])
  }
  ignore(@ir.hot_region_splice(func, @ir.HotRegionRef::root(), 0, 0, [shared]))
  assert_true(
    hso_discovery_expansion_exceeds_limit(func, @ir.hot_node_count(func) * 8),
  )
  assert_false(hso_discovery_expansion_exceeds_limit(func, 8191))
  assert_true(hso_discovery_expansion_exceeds_limit(func, 8190))
  let ctx = HotPassContext::new(
    heap_store_optimization_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  assert_eq(heap_store_optimization_run(ctx, func), HotPassResult::unchanged())
  let cache = hso_new_predicate_cache(descent_limit=64)
  let revision = @ir.hot_revision_current(func)
  let masks = Array::make(@ir.hot_node_count(func), @ir.EFFECT_MASK_CONTROL)
  assert_false(
    hso_process_region(
      cache,
      hso_new_type_cache(),
      func,
      None,
      masks,
      @ir.HotRegionRef::root(),
      0,
      None,
      hso_new_external_roots(),
      hso_new_local_order_workspace(0),
    ),
  )
  // This is the work invariant, independent of machine speed or a timeout.
  assert_eq(cache.descent_remaining[0], 0)
  assert_eq(@ir.hot_revision_current(func), revision)
  assert_eq(@ir.hot_region_get(func, @ir.HotRegionRef::root(), 0), shared)
}

///|
test "heap-store-optimization still folds current region after descent exhaustion" {
  // Encoded straight-line constructor/store fixture; folding must stay active.
  let input = @binary.decode_module(
    b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x08\x02\x5f\x01\x7f\x01\x60\x00\x00\x03\x02\x01\x01\x0a\x14\x01\x12\x01\x01\x63\x00\xfb\x01\x00\x21\x00\x20\x00\x41\x2a\xfb\x05\x00\x00\x0b\x00\x0b\x04\x6e\x61\x6d\x65\x04\x04\x01\x00\x01\x73",
  ).unwrap()
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    heap_store_optimization_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
    module_ctx=Some(@ir.hot_module_context_from_module(input)),
  )
  let cache = hso_new_predicate_cache(descent_limit=0)
  let effects = pass_require_effects(ctx, func)
  assert_true(
    hso_process_region(
      cache,
      hso_new_type_cache(),
      func,
      ctx.module_ctx,
      effects.node_masks,
      @ir.HotRegionRef::root(),
      0,
      None,
      hso_new_external_roots(),
      hso_new_local_order_workspace(@ir.hot_local_count(func)),
    ),
  )
  let set_id = @ir.hot_region_get(func, @ir.HotRegionRef::root(), 0)
  let new_id = @ir.hot_child_get(func, set_id, 0)
  assert_eq(
    @ir.hot_node_exact_instr(func, new_id),
    Some(@lib.Instruction::struct_new(@lib.TypeIdx::new(0U))),
  )
  assert_eq(@ir.hot_child_count(func, new_id), 1)
  let value = @ir.hot_node_get(func, @ir.hot_child_get(func, new_id, 0))
  assert_true(value.op is @ir.HotOp::Const)
  assert_eq(
    @ir.hot_const_get(func, value.imm0),
    @ir.HotConstPayload::i32_const(@lib.I32::new(42)),
  )
  pass_mark_mutated(ctx, func)
  match pass_verify_before_after(ctx, func) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}
