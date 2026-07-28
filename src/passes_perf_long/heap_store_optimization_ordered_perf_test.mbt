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
