///|
fn hso_ordered_perf_struct_fields() -> Array[@lib.FieldType] {
  [
    @lib.FieldType::new(
      @lib.StorageType::val_type(@lib.ValType::i32()),
      @lib.Mut::var_(),
    ),
    @lib.FieldType::new(
      @lib.StorageType::val_type(@lib.ValType::i32()),
      @lib.Mut::var_(),
    ),
  ]
}

///|
fn hso_ordered_perf_module(candidate_count : Int) -> @lib.Module {
  let pair = @lib.TypeIdx::new(0U)
  let descriptor = @lib.TypeIdx::new(1U)
  let func_type = @lib.TypeIdx::new(2U)
  let pair_ref = @lib.ValType::ref_null(@lib.HeapType::new(pair))
  let descriptor_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(descriptor), exact=true),
  )
  let descriptor_group = @lib.RecType::group([
    @lib.SubType::comp_type(
      @lib.CompType::struct_(hso_ordered_perf_struct_fields()),
      metadata=@lib.TypeMetadata::new(descriptor=Some(descriptor), shared=true),
    ),
    @lib.SubType::comp_type(
      @lib.CompType::struct_([]),
      metadata=@lib.TypeMetadata::new(describes=Some(pair), shared=true),
    ),
  ])
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::struct_new_desc(pair),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ]
  let memarg = @lib.MemArg::new(2U, None, 0UL)
  for candidate = 0; candidate < candidate_count; candidate = candidate + 1 {
    body.append([
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::i32_atomic_load(
            memarg,
            order=@lib.AtomicOrder::acq_rel(),
          ),
          @lib.Instruction::drop(),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::i32_const(@lib.I32(candidate)),
          @lib.Instruction::i32_atomic_store(
            memarg,
            order=@lib.AtomicOrder::acq_rel(),
          ),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::atomic_rmw(
            @lib.AtomicRmwOp::i32_add(),
            memarg,
            order=@lib.AtomicOrder::seq_cst(),
          ),
          @lib.Instruction::drop(),
          @lib.Instruction::i32_const(@lib.I32(candidate)),
        ]),
      ),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::struct_atomic_get(
        @lib.AtomicOrder::acq_rel(),
        pair,
        @lib.U32(1U),
      ),
      @lib.Instruction::block(
        @lib.BlockType::val_type(descriptor_ref),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::val_type(descriptor_ref),
            @lib.Expr::new([
              @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
            ]),
          ),
        ]),
      ),
      @lib.Instruction::struct_new_desc(pair),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::i32_atomic_load(
        memarg,
        order=@lib.AtomicOrder::acq_rel(),
      ),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::i32_const(@lib.I32(candidate + 1)),
      @lib.Instruction::i32_atomic_store(
        memarg,
        order=@lib.AtomicOrder::acq_rel(),
      ),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::struct_atomic_rmw(
        @lib.AggregateAtomicRmwOp::add(),
        pair,
        @lib.U32(1U),
        order=@lib.AtomicOrder::acq_rel(),
      ),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::i32_const(@lib.I32(candidate + 1000)),
      @lib.Instruction::struct_set(pair, @lib.U32(0U)),
    ])
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      descriptor_group,
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_import_sec(
    @lib.ImportSec::new([
      @lib.Import::new(
        @lib.Name::new("env"),
        @lib.Name::new("desc"),
        @lib.ExternType::global(@lib.GlobalType::new(descriptor_ref, false)),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([func_type]))
  .with_mem_sec(
    @lib.MemSec::new([
      @lib.MemType::new(@lib.Limits::i32(1U, Some(1U)), shared=true),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([pair_ref, pair_ref]),
        @lib.Expr::new(body),
      ),
    ]),
  )
}

///|
#skip("manual native-release ordered HSO summary-cache benchmark")
test "heap-store-optimization ordered perf lane measures repeated subtree summaries" {
  let candidate_count = 192
  for _ in 0..<2 {
    match
      @passes.run_hot_pipeline(
        hso_ordered_perf_module(candidate_count),
        @passes.HotPipelineOptions::new(),
        ["heap-store-optimization"],
      ) {
      Ok(_) => ()
      Err(err) => fail("expected ordered HSO warmup success, got \{err}")
    }
  }

  let samples : Array[UInt64] = []
  for _ in 0..<9 {
    let start = @lib.trace_now_us()
    match
      @passes.run_hot_pipeline(
        hso_ordered_perf_module(candidate_count),
        @passes.HotPipelineOptions::new(),
        ["heap-store-optimization"],
      ) {
      Ok(_) => ()
      Err(err) => fail("expected ordered HSO benchmark success, got \{err}")
    }
    samples.push(@lib.trace_elapsed_us_since(start))
  }
  samples.sort()
  let median_us = samples[samples.length() / 2]
  println(
    "hso_ordered candidates=\{candidate_count} samples=\{samples.length()} median_us=\{median_us} per_query_full_bitset_allocations=0",
  )
  assert_true(
    median_us < 5000000UL,
    msg="expected ordered HSO stress fixture to stay under 5s, got \{median_us}us",
  )
}

///|
fn hso_ordered_perf_count_struct_sets(instrs : Array[@lib.Instruction]) -> Int {
  let mut count = 0
  for instr in instrs {
    match instr {
      @lib.Instruction::StructSet(_, _) => count = count + 1
      @lib.Instruction::Block(_, @lib.Expr(body))
      | @lib.Instruction::Loop(_, @lib.Expr(body)) =>
        count = count + hso_ordered_perf_count_struct_sets(body)
      @lib.Instruction::If(_, then_body, else_body) => {
        count = count + hso_ordered_perf_count_struct_sets(then_body)
        match else_body {
          Some(body) => count = count + hso_ordered_perf_count_struct_sets(body)
          None => ()
        }
      }
      @lib.Instruction::TryTable(_, _, @lib.Expr(body)) =>
        count = count + hso_ordered_perf_count_struct_sets(body)
      _ => ()
    }
  }
  count
}

///|
fn hso_ordered_perf_struct_set_count(mod_ : @lib.Module) -> Int {
  match mod_.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) =>
      hso_ordered_perf_count_struct_sets(body)
    _ => abort("expected one ordered HSO benchmark function")
  }
}

///|
test "bench heap-store-optimization ordered candidates=192" (it : @bench.T) {
  let fixture = hso_ordered_perf_module(192)
  let preflight = match
    @passes.run_hot_pipeline(fixture, @passes.HotPipelineOptions::new(), [
      "heap-store-optimization",
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      abort("expected ordered HSO benchmark fixture success, got \{err}")
  }
  let input_set_count = hso_ordered_perf_struct_set_count(fixture)
  assert_true(input_set_count > 0)
  assert_true(hso_ordered_perf_struct_set_count(preflight) == input_set_count)
  let options = @passes.HotPipelineOptions::new(validate_final_module=false)
  it.bench(fn() {
    match
      @passes.run_hot_pipeline(fixture, options, ["heap-store-optimization"]) {
      Ok(mod_) => ignore(mod_.code_sec)
      Err(err) => abort("expected ordered HSO benchmark success, got \{err}")
    }
  })
}

///|
test "bench HOT lift heap-store-optimization ordered candidates=1024" (
  it : @bench.T,
) {
  let fixture = hso_ordered_perf_module(1024)
  let preflight = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
  assert_true(@ir.hot_node_count(preflight) > 0)
  it.bench(fn() {
    let lifted = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
    ignore(@ir.hot_node_count(lifted))
  })
}

///|
test "bench HOT lift plus heap-store-optimization pass ordered candidates=1024" (
  it : @bench.T,
) {
  let fixture = hso_ordered_perf_module(1024)
  let module_ctx = @ir.hot_module_context_from_module(fixture)
  let preflight = match
    @passes.run_hot_pipeline(fixture, @passes.HotPipelineOptions::new(), [
      "heap-store-optimization",
    ]) {
    Ok(mod_) => mod_
    Err(err) => abort("expected ordered HSO preflight success, got \{err}")
  }
  assert_true(
    hso_ordered_perf_struct_set_count(preflight) ==
    hso_ordered_perf_struct_set_count(fixture),
  )
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
      Err(err) => abort("expected ordered HSO direct-pass success, got \{err}")
    }
  })
}

///|
test "bench HOT lower heap-store-optimization ordered candidates=1024" (
  it : @bench.T,
) {
  let fixture = hso_ordered_perf_module(1024)
  let optimized = match
    @passes.run_hot_pipeline(fixture, @passes.HotPipelineOptions::new(), [
      "heap-store-optimization",
    ]) {
    Ok(mod_) => mod_
    Err(err) => abort("expected ordered HSO preflight success, got \{err}")
  }
  let input_set_count = hso_ordered_perf_struct_set_count(fixture)
  assert_true(input_set_count > 0)
  assert_true(hso_ordered_perf_struct_set_count(optimized) == input_set_count)
  let lifted = @ir.hot_lift_func(optimized, @lib.FuncIdx::new(0U))
  let preflight = @ir.hot_lower_func_unverified(lifted)
  let @lib.Func(_, @lib.Expr(preflight_body)) = preflight
  assert_true(preflight_body.length() > 0)
  it.bench(fn() {
    let lowered = @ir.hot_lower_func_unverified(lifted)
    let @lib.Func(_, @lib.Expr(body)) = lowered
    ignore(body.length())
  })
}

///|
test "bench heap-store-optimization ordered candidates=1024" (it : @bench.T) {
  let fixture = hso_ordered_perf_module(1024)
  let preflight = match
    @passes.run_hot_pipeline(fixture, @passes.HotPipelineOptions::new(), [
      "heap-store-optimization",
    ]) {
    Ok(mod_) => mod_
    Err(err) => abort("expected ordered HSO preflight success, got \{err}")
  }
  let input_set_count = hso_ordered_perf_struct_set_count(fixture)
  assert_true(input_set_count > 0)
  assert_true(hso_ordered_perf_struct_set_count(preflight) == input_set_count)
  let options = @passes.HotPipelineOptions::new(validate_final_module=false)
  it.bench(fn() {
    match
      @passes.run_hot_pipeline(fixture, options, ["heap-store-optimization"]) {
      Ok(mod_) => ignore(mod_.code_sec)
      Err(err) => abort("expected ordered HSO benchmark success, got \{err}")
    }
  })
}
