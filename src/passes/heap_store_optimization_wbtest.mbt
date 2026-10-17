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
