///|
fn review_oc_type_bench(it : @bench.T, cached : Bool) -> Unit raise {
  let ctx = @ir.hot_module_context_from_module(
    @lib.Module::new().with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
      ]),
    ),
  )
  let lhs = @lib.HeapType::new(@lib.TypeIdx::new(0U))
  let rhs = @lib.HeapType::new(@lib.TypeIdx::new(1U))
  assert_true(oc_heap_identical(ctx, lhs, rhs))
  let env = Some(OcTypeEnvironment::new())
  it.bench(fn() {
    env.unwrap().value = None
    for _ in 0..<1024 {
      it.keep(
        if cached {
          oc_heap_identical(ctx, lhs, rhs, type_env=env)
        } else {
          review_reference_oc_heap_identical(ctx, lhs, rhs)
        },
      )
    }
  })
}

///|
fn review_cleanup_type_bench(it : @bench.T, reference : Bool) -> Unit raise {
  let original = precompute_unused_gc_type_parity_fixture()
  let rewritten = original.with_code_sec(
    @lib.CodeSec::new(
      original.code_sec.unwrap().0.map(fn(func) {
        let @lib.Func(locals, _) = func
        @lib.Func::new(
          locals,
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
        )
      }),
    ),
  )
  let output = precompute_cleanup_unused_gc_types(original, rewritten)
  assert_eq(output.type_sec.unwrap().0.length(), 1)
  it.bench(fn() {
    it.keep(
      if reference {
        review_reference_precompute_cleanup_unused_gc_types(original, rewritten)
      } else {
        precompute_cleanup_unused_gc_types(original, rewritten)
      },
    )
  })
}

///|
fn review_gsi_equivalence_fixture(count : Int32) -> @validate.Env {
  let fields = [
    @lib.FieldType::new(
      @lib.StorageType::val_type(@lib.ValType::i32()),
      @lib.Mut::const_(),
    ),
  ]
  @validate.Env::new().with_types(
    Array::make(count, @lib.SubType::comp_type(@lib.CompType::struct_(fields))),
  )
}

///|
fn review_gsi_type_bench(
  it : @bench.T,
  reference : Bool,
  coarse~ : Bool = false,
) -> Unit {
  let env = review_gsi_equivalence_fixture(256)
  it.bench(fn() {
    let candidates : Array[Array[@lib.GlobalIdx]] = []
    for index in 0..<256 {
      candidates.push(if index == 0 { [@lib.GlobalIdx::new(0U)] } else { [] })
    }
    if reference {
      review_reference_gsi_merge_equivalent_struct_type_facts(
        env,
        Array::make(256, false),
        candidates,
      )
    } else if coarse {
      review_coarse_gsi_merge_equivalent_struct_type_facts(
        env,
        Array::make(256, false),
        candidates,
      )
    } else {
      gsi_merge_equivalent_struct_type_facts(
        env,
        Array::make(256, false),
        candidates,
      )
    }
    it.keep(candidates)
  })
}

///|
test "bench review optimize casts original environment" (it : @bench.T) {
  review_oc_type_bench(it, false)
}

///|
test "bench review optimize casts shared environment" (it : @bench.T) {
  review_oc_type_bench(it, true)
}

///|
test "bench review cleanup original encodes" (it : @bench.T) {
  review_cleanup_type_bench(it, true)
}

///|
test "bench review cleanup exact sizes" (it : @bench.T) {
  review_cleanup_type_bench(it, false)
}

///|
test "bench review GSI original pairs" (it : @bench.T) {
  review_gsi_type_bench(it, true)
}

///|
test "bench review GSI type classes" (it : @bench.T) {
  review_gsi_type_bench(it, false)
}

///|
fn review_global_value_bench(it : @bench.T, cached : Bool) -> Unit {
  let fields = Array::make(128, "(field i32)").join(" ")
  let values = Array::make(128, "i32.const 7").join(" ")
  let input = pass_test_module_from_wat(
    "(module (type $s (struct \{fields})) (global (ref $s) \{values} struct.new $s))",
  )
  let ctx = review_precompute_context(input)
  let index = @lib.GlobalIdx::new(0U)
  it.bench(fn() {
    ctx.precompute_global_values = None
    for _ in 0..<128 {
      it.keep(
        if cached {
          precompute_known_heap_value_from_global_cached(ctx, index, 0)
        } else {
          review_reference_precompute_known_heap_value_from_global(
            ctx.module_ctx.unwrap(),
            index,
            0,
          )
        },
      )
    }
  })
}

///|
test "bench review immutable globals original interpreter" (it : @bench.T) {
  review_global_value_bench(it, false)
}

///|
test "bench review immutable globals cached interpreter" (it : @bench.T) {
  review_global_value_bench(it, true)
}

///|
fn review_raw_admission_bench(it : @bench.T, reference : Bool) -> Unit {
  let body : Array[@lib.Instruction] = []
  for _ in 0..<4096 {
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
    body.push(@lib.Instruction::global_set(@lib.GlobalIdx::new(0U)))
  }
  let func = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
  it.bench(fn() {
    it.keep(
      if reference {
        review_reference_precompute_run_raw_func(func, None)
      } else {
        precompute_run_raw_func(func, None)
      },
    )
  })
}

///|
test "bench review raw precompute original scans" (it : @bench.T) {
  review_raw_admission_bench(it, true)
}

///|
test "bench review raw precompute combined scan" (it : @bench.T) {
  review_raw_admission_bench(it, false)
}

///|
fn review_reorder_size_bench(it : @bench.T, reference : Bool) -> Unit {
  let input = review_reorder_fixture()
  it.bench(fn() {
    it.keep(
      if reference {
        review_reference_reorder_globals_run_module_pass_with_threshold(
          input, true,
        )
      } else {
        reorder_globals_run_module_pass(input)
      },
    )
  })
}

///|
test "bench review reorder original candidates" (it : @bench.T) {
  review_reorder_size_bench(it, true)
}

///|
test "bench review reorder unique width candidates" (it : @bench.T) {
  review_reorder_size_bench(it, false)
}

///|
fn review_gsi_inactive_bench(
  it : @bench.T,
  reference : Bool,
  coarse~ : Bool = false,
) -> Unit {
  let types : Array[@lib.SubType] = []
  let field = @lib.FieldType::new(
    @lib.StorageType::val_type(@lib.ValType::i32()),
    @lib.Mut::const_(),
  )
  for count in 0..<128 {
    types.push(
      @lib.SubType::comp_type(@lib.CompType::struct_(Array::make(count, field))),
    )
  }
  for slot in 0..<128 {
    types.push(
      @lib.SubType::comp_type(
        @lib.CompType::struct_([
          @lib.FieldType::new(
            @lib.StorageType::val_type(
              @lib.ValType::ref_type(
                @lib.RefType::new(
                  false,
                  @lib.HeapType::new(@lib.TypeIdx::new(slot.to_uint())),
                ),
              ),
            ),
            @lib.Mut::const_(),
          ),
        ]),
      ),
    )
  }
  let env = @validate.Env::new().with_types(types)
  it.bench(fn() {
    let candidates : Array[Array[@lib.GlobalIdx]] = []
    for slot in 0..<256 {
      candidates.push(if slot == 128 { [@lib.GlobalIdx::new(0U)] } else { [] })
    }
    if reference {
      review_reference_gsi_merge_equivalent_struct_type_facts(
        env,
        Array::make(256, false),
        candidates,
      )
    } else if coarse {
      review_coarse_gsi_merge_equivalent_struct_type_facts(
        env,
        Array::make(256, false),
        candidates,
      )
    } else {
      gsi_merge_equivalent_struct_type_facts(
        env,
        Array::make(256, false),
        candidates,
      )
    }
    it.keep(candidates)
  })
}

///|
test "bench review GSI original mostly inactive concrete references" (
  it : @bench.T,
) {
  review_gsi_inactive_bench(it, true)
}

///|
test "bench review GSI active classes concrete references" (it : @bench.T) {
  review_gsi_inactive_bench(it, false)
}

///|
fn review_precompute_gate_fixture() -> @lib.Module {
  let body : Array[@lib.Instruction] = []
  for _ in 0..<1024 {
    body.push(@lib.Instruction::i32_const(@lib.I32::new(0)))
    body.push(@lib.Instruction::drop())
  }
  pass_test_module_from_wat("(module (func))").with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
    ]),
  )
}

///|
fn review_gate_features_bench(it : @bench.T, reference : Bool) -> Unit {
  let @lib.Func(_, @lib.Expr(body)) = review_precompute_gate_fixture().code_sec.unwrap().0[0]
  it.bench(fn() {
    it.keep(
      if reference {
        review_precompute_gate_expected(body)
      } else {
        precompute_raw_gate_features(body)
      },
    )
  })
}

///|
fn review_gate_dispatch_bench(it : @bench.T, reference : Bool) -> Unit {
  let input = review_precompute_gate_fixture()
  let descriptor = precompute_propagate_descriptor()
  let options = HotPipelineOptions::new()
  it.bench(fn() {
    let state = HotPipelineModuleState::new()
    it.keep(
      if reference {
        review_reference_raw_precompute_dispatch(
          input,
          @lib.FuncIdx::new(0U),
          state,
          descriptor,
          options,
        )
      } else {
        run_hot_pipeline_raw_precompute(
          input,
          @lib.FuncIdx::new(0U),
          state,
          descriptor,
          options,
        )
      },
    )
  })
}

///|
test "bench review precompute original-body original scans" (it : @bench.T) {
  review_gate_features_bench(it, true)
}

///|
test "bench review precompute original-body combined scan" (it : @bench.T) {
  review_gate_features_bench(it, false)
}

///|
test "bench review precompute exact dispatch original scans" (it : @bench.T) {
  review_gate_dispatch_bench(it, true)
}

///|
test "bench review precompute exact dispatch combined scan" (it : @bench.T) {
  review_gate_dispatch_bench(it, false)
}

///|
fn review_gsi_active_bench(
  it : @bench.T,
  count : Int32,
  mode : Int32,
) -> Unit raise {
  let input = review_gsi_active_reference_fixture(count)
  assert_true(@validate.validate_module(input) is Ok(_))
  let env = @validate.Env::new().with_module(input)
  it.bench(fn() {
    let candidates = review_gsi_active_reference_candidates(count)
    let poisoned = Array::make(count * 2, false)
    match mode {
      0 =>
        review_reference_gsi_merge_equivalent_struct_type_facts(
          env, poisoned, candidates,
        )
      1 =>
        review_coarse_gsi_merge_equivalent_struct_type_facts(
          env, poisoned, candidates,
        )
      _ => gsi_merge_equivalent_struct_type_facts(env, poisoned, candidates)
    }
    it.keep(candidates)
  })
}

///|
test "bench review GSI256distinct active references original pairs" (
  it : @bench.T,
) {
  review_gsi_active_bench(it, 256, 0)
}

///|
test "bench review GSI256distinct active references class buckets" (
  it : @bench.T,
) {
  review_gsi_active_bench(it, 256, 2)
}

///|
test "bench review GSI512distinct active references original pairs" (
  it : @bench.T,
) {
  review_gsi_active_bench(it, 512, 0)
}

///|
test "bench review GSI512distinct active references class buckets" (
  it : @bench.T,
) {
  review_gsi_active_bench(it, 512, 2)
}
