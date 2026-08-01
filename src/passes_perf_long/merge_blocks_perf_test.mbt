///|
fn merge_blocks_perf_multivalue_module(block_count : Int) -> @lib.Module {
  let blocks_per_func = 1000
  let function_count = block_count / blocks_per_func
  let function_types : Array[@lib.TypeIdx] = [@lib.TypeIdx::new(0U)]
  let funcs : Array[@lib.Func] = [
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i64_const(@lib.I64(9L)),
      ]),
    ),
  ]
  for function_index in 0..<function_count {
    let body : Array[@lib.Instruction] = Array::new(
      capacity=blocks_per_func * 5,
    )
    for local_index in 0..<blocks_per_func {
      let index = function_index * blocks_per_func + local_index
      body.push(
        @lib.Instruction::block(
          @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(index)),
            @lib.Instruction::i32_const(@lib.I32(index + 1)),
            @lib.Instruction::i32_const(@lib.I32(index + 2)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ]),
        ),
      )
      body.push(@lib.Instruction::drop())
    }
    function_types.push(@lib.TypeIdx::new(2U))
    funcs.push(@lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)))
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func(
            [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
            [@lib.ValType::i32(), @lib.ValType::i64()],
          ),
        ),
      ),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([], [@lib.ValType::i32(), @lib.ValType::i64()]),
        ),
      ),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func(
            [],
            Array::make(blocks_per_func, @lib.ValType::i32()),
          ),
        ),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new(function_types))
  .with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn merge_blocks_perf_median_us(samples : Array[UInt64]) -> UInt64 {
  samples.sort_by(fn(a, b) { a.compare(b) })
  samples[samples.length() / 2]
}

///|
#skip("manual native-release merge-blocks multivalue drop-parent index benchmark")
test "merge-blocks long perf lane measures one drop-parent index scan" {
  let block_count = 4000
  for _ in 0..<2 {
    match
      @passes.run_hot_pipeline(
        merge_blocks_perf_multivalue_module(block_count),
        @passes.HotPipelineOptions::new(),
        ["merge-blocks"],
      ) {
      Ok(_) => ()
      Err(err) =>
        fail("expected merge-blocks benchmark warmup success, got \{err}")
    }
  }
  let samples : Array[UInt64] = []
  let drop_parent_index_trace : Array[String] = []
  for _ in 0..<5 {
    let perf = @passes.HotPerfSession::new(
      trace=fn(line) {
        if line.contains("perf:timer name=pass:merge-blocks") {
          println(line)
        }
      },
      trace_checkpoints=false,
      trace_counters=false,
      dump_options=@passes.HotPerfDumpOptions::new(),
    )
    let start = @lib.trace_now_us()
    match
      @passes.run_hot_pipeline(
        merge_blocks_perf_multivalue_module(block_count),
        @passes.HotPipelineOptions::new(
          perf=Some(perf),
          trace=Some(fn(line) {
            if line.contains("pass[merge-blocks]:drop-parent-index") {
              drop_parent_index_trace.push(line)
              println(line)
            }
          }),
        ),
        ["merge-blocks"],
      ) {
      Ok(_) => ()
      Err(err) => fail("expected merge-blocks benchmark success, got \{err}")
    }
    samples.push(@lib.trace_elapsed_us_since(start))
  }
  let indexed_functions_per_run = 4
  assert_eq(drop_parent_index_trace.length(), 5 * indexed_functions_per_run)
  assert_true(
    drop_parent_index_trace.all(fn(line) {
      line.contains("full_function_scans=1") &&
      line.contains("drop_child_slots=1000")
    }),
  )
  println(
    "merge_blocks multivalue_blocks=\{block_count} partial_drop_blocks=\{block_count} indexed_functions_per_run=\{indexed_functions_per_run} pipeline_median_us=\{merge_blocks_perf_median_us(samples)} full_function_drop_parent_scans_per_function=1 samples=\{samples}",
  )
}
