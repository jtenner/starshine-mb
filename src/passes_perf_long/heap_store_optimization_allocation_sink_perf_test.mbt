///|
fn hso_allocation_sink_perf_module(candidate_count : Int) -> @lib.Module {
  let pair = @lib.TypeIdx::new(0U)
  let func_type = @lib.TypeIdx::new(1U)
  let body : Array[@lib.Instruction] = []
  for candidate = 0; candidate < candidate_count; candidate = candidate + 1 {
    body.append([
      @lib.Instruction::struct_new_default(pair),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::i32_const(@lib.I32(candidate & 1)),
      @lib.Instruction::if_(
        @lib.BlockType::val_type(@lib.ValType::anyref()),
        [
          @lib.Instruction::i32_const(@lib.I32(candidate)),
          @lib.Instruction::ref_i31(),
        ],
        Some([
          @lib.Instruction::i32_const(@lib.I32(candidate + 1)),
          @lib.Instruction::ref_i31(),
        ]),
      ),
      @lib.Instruction::drop(),
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::anyref()),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(candidate + 2)),
          @lib.Instruction::ref_i31(),
          @lib.Instruction::br(@lib.LabelIdx::new(0U)),
        ]),
      ),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
    ])
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::struct_([
            @lib.FieldType::new(
              @lib.StorageType::val_type(@lib.ValType::i32()),
              @lib.Mut::var_(),
            ),
          ]),
        ),
      ),
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([func_type]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([@lib.ValType::anyref()]),
        @lib.Expr::new(body),
      ),
    ]),
  )
}

///|
fn hso_allocation_sink_perf_adjacent_count(mod_ : @lib.Module) -> Int {
  let body = match mod_.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) => body
    _ => abort("expected one allocation-sinking HSO benchmark function")
  }
  let mut count = 0
  for idx = 0; idx + 3 < body.length(); idx = idx + 1 {
    match (body[idx], body[idx + 1], body[idx + 2], body[idx + 3]) {
      (
        @lib.StructNewDefault(_),
        @lib.LocalSet(@lib.LocalIdx(set_local)),
        @lib.LocalGet(@lib.LocalIdx(get_local)),
        @lib.Drop,
      ) if set_local == get_local => count = count + 1
      _ => ()
    }
  }
  count
}

///|
test "bench HOT lift heap-store-optimization allocation-only sinks=1024" (
  it : @bench.T,
) {
  let fixture = hso_allocation_sink_perf_module(1024)
  let preflight = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
  assert_true(@ir.hot_node_count(preflight) > 0)
  it.bench(fn() {
    let lifted = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
    ignore(@ir.hot_node_count(lifted))
  })
}

///|
test "bench HOT lift plus heap-store-optimization pass allocation-only sinks=1024" (
  it : @bench.T,
) {
  let fixture = hso_allocation_sink_perf_module(1024)
  let module_ctx = @ir.hot_module_context_from_module(fixture)
  let preflight = match
    @passes.run_hot_pipeline(fixture, @passes.HotPipelineOptions::new(), [
      "heap-store-optimization",
    ]) {
    Ok(mod_) => mod_
    Err(err) => abort("expected allocation-sinking HSO preflight, got \{err}")
  }
  assert_true(hso_allocation_sink_perf_adjacent_count(preflight) == 1024)
  it.bench(fn() {
    let func = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
    let ctx = @passes.HotPassContext::new(
      @passes.heap_store_optimization_descriptor(),
      @ir.HotAnalysisCache::new(),
      @passes.HotPipelineVerifyPolicy::final_module_only(),
      false,
      fn(_) { () },
      module_ctx=Some(module_ctx),
    )
    match @passes.hot_pass_run(ctx, func) {
      Ok(result) => ignore(result)
      Err(err) => abort("expected allocation-sinking direct HSO, got \{err}")
    }
  })
}

///|
test "bench HOT lower heap-store-optimization allocation-only sinks=1024" (
  it : @bench.T,
) {
  let fixture = hso_allocation_sink_perf_module(1024)
  let optimized = match
    @passes.run_hot_pipeline(fixture, @passes.HotPipelineOptions::new(), [
      "heap-store-optimization",
    ]) {
    Ok(mod_) => mod_
    Err(err) => abort("expected allocation-sinking HSO preflight, got \{err}")
  }
  assert_true(hso_allocation_sink_perf_adjacent_count(optimized) == 1024)
  let lifted = @ir.hot_lift_func(optimized, @lib.FuncIdx::new(0U))
  let preflight = @ir.hot_lower_func_unverified(lifted)
  let @lib.Func(_, @lib.Expr(body)) = preflight
  assert_true(body.length() > 0)
  it.bench(fn() {
    let lowered = @ir.hot_lower_func_unverified(lifted)
    let @lib.Func(_, @lib.Expr(body)) = lowered
    ignore(body.length())
  })
}

///|
test "bench heap-store-optimization allocation-only sinks=1024" (it : @bench.T) {
  let candidate_count = 1024
  let fixture = hso_allocation_sink_perf_module(candidate_count)
  assert_true(hso_allocation_sink_perf_adjacent_count(fixture) == 0)
  let preflight = match
    @passes.run_hot_pipeline(fixture, @passes.HotPipelineOptions::new(), [
      "heap-store-optimization",
    ]) {
    Ok(mod_) => mod_
    Err(err) => abort("expected allocation-sinking HSO preflight, got \{err}")
  }
  assert_true(
    hso_allocation_sink_perf_adjacent_count(preflight) == candidate_count,
  )
  let options = @passes.HotPipelineOptions::new(validate_final_module=false)
  it.bench(fn() {
    match
      @passes.run_hot_pipeline(fixture, options, ["heap-store-optimization"]) {
      Ok(mod_) => ignore(mod_.code_sec)
      Err(err) => abort("expected allocation-sinking HSO benchmark, got \{err}")
    }
  })
}
