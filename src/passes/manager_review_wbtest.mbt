///|
test "block result interning preserves source groups and uses the first matching type" {
  let results = [@lib.ValType::i32(), @lib.ValType::i64()]
  let types = @lib.TypeSec::new([
    @lib.RecType::group([
      @lib.SubType::comp_type(@lib.CompType::struct_([])),
      @lib.SubType::comp_type(@lib.CompType::func([], results)),
    ]),
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], results))),
  ])
  let saved = @binary.encode_module(@lib.Module::new().with_type_sec(types)).unwrap()
  let state : HotPipelineLowerState = HotPipelineLowerState::new(Some(types))
  assert_eq(
    run_hot_pipeline_lower_intern_block_result_type_idx(state, results),
    @lib.TypeIdx::new(1U),
  )
  let fresh = [@lib.ValType::f64(), @lib.ValType::i64()]
  assert_eq(
    run_hot_pipeline_lower_intern_block_result_type_idx(state, fresh),
    @lib.TypeIdx::new(3U),
  )
  assert_eq(
    run_hot_pipeline_lower_intern_block_result_type_idx(state, fresh.copy()),
    @lib.TypeIdx::new(3U),
  )
  assert_eq(run_hot_pipeline_lower_type_sec_flat_count(state.next_type_sec), 4)
  assert_eq(
    @binary.encode_module(@lib.Module::new().with_type_sec(types)).unwrap(),
    saved,
  )
  assert_eq(run_hot_pipeline_lower_type_sec_flat_count(Some(types)), 3)
}

///|
test "block result interning refreshes after a DAE2 type replacement" {
  let state = HotPipelineLowerState::new(None)
  let results = [@lib.ValType::i32(), @lib.ValType::i64()]
  assert_eq(
    run_hot_pipeline_lower_intern_block_result_type_idx(state, results),
    @lib.TypeIdx::new(0U),
  )
  let (types, _) = dae_append_new_func_type(
    state.next_type_sec.unwrap(),
    [@lib.ValType::i32()],
    [],
  )
  state.adopt_rewritten_types(types)
  let adopted_count = run_hot_pipeline_lower_type_sec_flat_count(Some(types))
  assert_eq(
    run_hot_pipeline_lower_intern_block_result_type_idx(state, [
      @lib.ValType::i64(),
      @lib.ValType::i32(),
    ]),
    @lib.TypeIdx::new(2U),
  )
  assert_eq(
    run_hot_pipeline_lower_intern_block_result_type_idx(state, results),
    @lib.TypeIdx::new(0U),
  )
  assert_eq(run_hot_pipeline_lower_type_sec_flat_count(state.next_type_sec), 3)
  assert_eq(
    run_hot_pipeline_lower_type_sec_flat_count(Some(types)),
    adopted_count,
  )
}

///|
test "indexed block result interning keeps recursive group indices and refreshes replacements" {
  let results = [@lib.ValType::i32(), @lib.ValType::i64()]
  let groups = Array::make(
    20,
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
    ),
  )
  groups[0] = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  groups[3] = @lib.RecType::group([
    @lib.SubType::comp_type(@lib.CompType::struct_([])),
    @lib.SubType::comp_type(@lib.CompType::func([], results)),
  ])
  groups[7] = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], results)),
  )
  let original = @lib.TypeSec::new(groups)
  let state = HotPipelineLowerState::new(Some(original))
  assert_eq(
    run_hot_pipeline_lower_intern_block_result_type_idx(state, results),
    @lib.TypeIdx::new(4U),
  )
  assert_eq(
    run_hot_pipeline_lower_intern_block_result_type_idx(state, [
      @lib.ValType::i64(),
      @lib.ValType::i32(),
    ]),
    @lib.TypeIdx::new(21U),
  )
  assert_eq(
    run_hot_pipeline_lower_intern_block_result_type_idx(state, results.copy()),
    @lib.TypeIdx::new(4U),
  )
  assert_eq(
    run_hot_pipeline_lower_intern_block_result_type_idx(state, [
      @lib.ValType::i32(),
    ]),
    @lib.TypeIdx::new(0U),
  )
  let (rewritten, _) = dae_append_new_func_type(
    state.next_type_sec.unwrap(),
    [@lib.ValType::f64()],
    [],
  )
  state.adopt_rewritten_types(rewritten)
  assert_eq(
    run_hot_pipeline_lower_intern_block_result_type_idx(state, [
      @lib.ValType::f32(),
      @lib.ValType::i64(),
    ]),
    @lib.TypeIdx::new(23U),
  )
  assert_eq(run_hot_pipeline_lower_type_sec_flat_count(Some(original)), 21)
  assert_eq(run_hot_pipeline_lower_type_sec_flat_count(state.next_type_sec), 24)
}

///|
test "vacuum admission preserves typed control and legacy exception cleanup" {
  for
    wat in [
      "(module (func (export \"run\") (result i32) block (result i32) i32.const 7 end))",
      "(module (tag) (func (export \"run\") (result i32) (try (result i32) (do i32.const 7) (catch 0 i32.const 8))))",
      "(module (func (export \"run\") (result i32) i32.const 7 unreachable))",
    ] {
    let input = pass_test_module_from_wat(wat)
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]).unwrap()
    @validate.validate_module(output).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    assert_eq(body.length(), 1)
  }
}

///|
test "multiple hot passes keep type and function references valid across module passes" {
  let input = pass_test_module_from_wat(
    "(module (type (func (param i32) (result i32))) (type (func (result i32))) (func (type 0) (param i32) (result i32) local.get 0 i32.const 1 i32.add) (func (export \"run\") (type 1) (result i32) i32.const 9 call 0))",
  )
  let passes = [
    "optimize-instructions", "simplify-locals", "inlining", "vacuum", "optimize-instructions",
  ]
  let actual = run_hot_pipeline(input, HotPipelineOptions::new(), passes).unwrap()
  let mut expected = input
  for pass_ in passes {
    expected = run_hot_pipeline(expected, HotPipelineOptions::new(), [pass_]).unwrap()
  }
  @validate.validate_module(actual).unwrap()
  assert_eq(
    @binary.encode_module(actual).unwrap(),
    @binary.encode_module(expected).unwrap(),
  )
}

///|
test "optimize instructions changes one function and retains an unchanged neighbor" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) local.get 0 i32.const 0 i32.add) (func (param i32) (result i32) local.get 0))",
  )
  let original = input.code_sec.unwrap().0
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "optimize-instructions",
  ]).unwrap()
  let actual = output.code_sec.unwrap().0
  let @lib.Func(_, @lib.Expr(body)) = actual[0]
  assert_eq(body, [@lib.Instruction::local_get(@lib.LocalIdx::new(0U))])
  assert_true(physical_equal(actual[1], original[1]))
  @validate.validate_module(output).unwrap()
}

///|
test "shared module context refreshes changed signatures and global initializers" {
  let input = pass_test_module_from_wat(
    "(module (global i32 (i32.const 1)) (func (result i32) global.get 0))",
  )
  let cache = HotPipelineModuleCache::new()
  let options = HotPipelineOptions::new()
  let first = run_hot_pipeline_require_module_ctx(
    input,
    HotPipelineModuleState::new(module_cache=Some(cache)),
    options,
  )
  let body_changed = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(2))]),
      ),
    ]),
  )
  let second = run_hot_pipeline_require_module_ctx(
    body_changed,
    HotPipelineModuleState::new(module_cache=Some(cache)),
    options,
  )
  assert_eq(second, @ir.hot_module_context_from_module(body_changed))
  assert_true(physical_equal(first, second))
  let changed = body_changed.with_global_sec(
    @lib.GlobalSec::new([
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), false),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(3))]),
      ),
    ]),
  )
  let third = run_hot_pipeline_require_module_ctx(
    changed,
    HotPipelineModuleState::new(module_cache=Some(cache)),
    options,
  )
  assert_eq(third, @ir.hot_module_context_from_module(changed))
  assert_false(physical_equal(second, third))
  let changed_type = changed.with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i64()])),
      ),
    ]),
  )
  let fourth = run_hot_pipeline_require_module_ctx(
    changed_type,
    HotPipelineModuleState::new(module_cache=Some(cache)),
    options,
  )
  assert_eq(fourth, @ir.hot_module_context_from_module(changed_type))
  assert_false(physical_equal(third, fourth))
}

///|
test "shared module context tracks exact references introduced and removed from bodies" {
  let input = pass_test_module_from_wat("(module (type (struct)) (func))")
  let cache = HotPipelineModuleCache::new()
  let options = HotPipelineOptions::new()
  let require_context = fn(mod_ : @lib.Module) {
    run_hot_pipeline_require_module_ctx(
      mod_,
      HotPipelineModuleState::new(module_cache=Some(cache)),
      options,
    )
  }
  assert_false(require_context(input).uses_custom_descriptors)
  let exact = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::ref_null_type(
            @lib.RefType::new(
              true,
              @lib.HeapType::new(@lib.TypeIdx::new(0U)),
              exact=true,
            ),
          ),
          @lib.Instruction::drop(),
        ]),
      ),
    ]),
  )
  assert_true(require_context(exact).uses_custom_descriptors)
  let ordinary = exact.with_code_sec(input.code_sec.unwrap())
  assert_false(require_context(ordinary).uses_custom_descriptors)
}

///|
test "shared module cache releases obsolete code after hot writeback and before module passes" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) nop i32.const 7))",
  )
  let cache = HotPipelineModuleCache::new()
  let options = HotPipelineOptions::new()
  ignore(
    run_hot_pipeline_require_module_ctx(
      input,
      HotPipelineModuleState::new(module_cache=Some(cache)),
      options,
    ),
  )
  let output = run_hot_pipeline_apply_hot_pass(
    input,
    pass_registry_lookup_cached("vacuum").unwrap(),
    options,
    module_cache=Some(cache),
  ).unwrap()
  assert_false(hot_pipeline_same_section(input.code_sec, output.code_sec))
  assert_true(
    hot_pipeline_same_section(cache.source.unwrap().code_sec, output.code_sec),
  )
  let next = run_hot_pipeline_apply_module_pass(
    output,
    pass_registry_lookup_cached("reorder-locals").unwrap(),
    options,
    module_cache=Some(cache),
  ).unwrap()
  @validate.validate_module(next).unwrap()
  assert_true(cache.source is None)
  assert_true(cache.context is None)
}

///|
fn manager_review_assert_vacuum_admission(
  body : Array[@lib.Instruction],
) -> Unit raise {
  for
    wrapped in [
      body,
      [@lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(body))],
      [@lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new(body))],
      [@lib.Instruction::if_(@lib.BlockType::void_(), [], Some(body))],
    ] {
    let facts = VacuumPrecleanAdmissionFacts::new(wrapped)
    assert_eq(
      facts.dropped_typeidx_block,
      run_hot_pipeline_raw_vacuum_instrs_have_dropped_typeidx_block(wrapped),
    )
    assert_eq(
      facts.flattenable_exception,
      run_hot_pipeline_raw_vacuum_instrs_have_flattenable_no_throw_exception_region(
        wrapped,
      ),
    )
    assert_eq(
      facts.legacy_try,
      run_hot_pipeline_raw_vacuum_instrs_have_legacy_try(wrapped),
    )
    assert_eq(
      facts.fresh_array_set,
      run_hot_pipeline_raw_vacuum_instrs_have_fresh_array_set_candidate(wrapped),
    )
    assert_eq(
      facts.dropped_simple_struct,
      run_hot_pipeline_raw_vacuum_instrs_have_dropped_simple_struct(wrapped),
    )
    assert_eq(
      facts.needs_type_context,
      run_hot_pipeline_raw_vacuum_instrs_require_type_context(wrapped),
    )
  }
}

///|
test "combined vacuum admission retains each original predicate boundary" {
  for
    wat in [
      "(module (func (result i32) i32.const 7))", "(module (tag) (func (result i32) (try (result i32) (do i32.const 7) (catch 0 i32.const 8))))",
      "(module (type (func (result i32 i64))) (func block (type 0) i32.const 1 i64.const 2 end drop drop))",
      "(module (type (func (result i32 i64))) (func loop (type 0) i32.const 1 i64.const 2 end drop drop))",
    ] {
    let mod_ = pass_test_module_from_wat(wat)
    for func in mod_.code_sec.unwrap().0 {
      let @lib.Func(_, @lib.Expr(body)) = func
      manager_review_assert_vacuum_admission(body)
    }
  }
  let ty = @lib.TypeIdx::new(0U)
  // The in-process parser does not accept array.set. Admission itself reads
  // direct instructions and must retain the same boundary for these shapes.
  for
    body in [
      [
        @lib.Instruction::i32_const(@lib.I32(3)),
        @lib.Instruction::array_new_default(ty),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::array_set(ty),
      ],
      [
        @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
        @lib.Instruction::struct_new(ty),
        @lib.Instruction::drop(),
      ],
      [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::struct_new(ty),
        @lib.Instruction::drop(),
      ],
      [
        @lib.Instruction::try_table(
          @lib.BlockType::void_(),
          [],
          @lib.Expr::new([
            @lib.Instruction::ref_null(
              @lib.HeapType::abs(@lib.AbsHeapType::no_exn()),
            ),
            @lib.Instruction::throw_ref(),
          ]),
        ),
      ],
      [
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::try_table(
              @lib.BlockType::void_(),
              [@lib.Catch::all(@lib.LabelIdx::new(0U))],
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32(1)),
                @lib.Instruction::drop(),
              ]),
            ),
          ]),
        ),
      ],
    ] {
    manager_review_assert_vacuum_admission(body)
  }
}

///|
test "raw shortcuts share import-aware lookup and preserve optional direct callers" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"a\" (func)) (import \"env\" \"b\" (func)) (func (result i32) i32.const 7) (func (result i32) i32.const 9))",
  )
  let state = HotPipelineModuleState::new()
  let vacuum = pass_registry_lookup_cached("vacuum").unwrap().descriptor.unwrap()
  let casts = pass_registry_lookup_cached("optimize-casts").unwrap().descriptor.unwrap()
  let last_idx = @lib.FuncIdx::new(3U)
  let first_idx = @lib.FuncIdx::new(2U)
  let last = run_hot_pipeline_raw_vacuum_no_candidates(
    input,
    last_idx,
    vacuum,
    module_state=Some(state),
  ).unwrap()
  assert_eq(last.func, input.code_sec.unwrap().0[1])
  assert_eq(state.imported_func_count, Some(2))
  let first = run_hot_pipeline_raw_optimize_casts_no_candidates(
    input,
    first_idx,
    casts,
    module_state=Some(state),
  ).unwrap()
  assert_eq(first.func, input.code_sec.unwrap().0[0])
  assert_eq(state.imported_func_count, Some(2))
  assert_eq(
    run_hot_pipeline_raw_vacuum_no_candidates(input, last_idx, vacuum).unwrap().func,
    last.func,
  )
  assert_eq(
    run_hot_pipeline_raw_optimize_casts_no_candidates(input, first_idx, casts).unwrap().func,
    first.func,
  )
  @validate.validate_module(input).unwrap()
}
