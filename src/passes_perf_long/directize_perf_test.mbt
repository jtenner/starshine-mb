///|
fn directize_perf_type_sec() -> @lib.TypeSec {
  @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
      ),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], []),
      ),
    ),
  ])
}

///|
fn directize_perf_long_i32_expr(
  body : Array[@lib.Instruction],
  local_idx : UInt,
  depth : Int,
) -> Unit {
  body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(local_idx)))
  for _ in 0..<depth {
    body.push(@lib.Instruction::i32_const(@lib.I32(1)))
    body.push(@lib.Instruction::i32_add())
  }
}

///|
fn directize_perf_module(call_count : Int, depth : Int) -> @lib.Module {
  let type_idx = @lib.TypeIdx::new(0U)
  let body : Array[@lib.Instruction] = Array::new(
    capacity=call_count * (depth * 4 + 8),
  )
  for _ in 0..<call_count {
    directize_perf_long_i32_expr(body, 0U, depth)
    body.push(@lib.Instruction::i32_const(@lib.I32(0)))
    body.push(@lib.Instruction::i32_const(@lib.I32(1)))
    directize_perf_long_i32_expr(body, 1U, depth)
    body.push(@lib.Instruction::select())
    body.push(@lib.Instruction::call_indirect(type_idx, @lib.TableIdx::new(0U)))
    body.push(@lib.Instruction::drop())
  }
  @lib.Module::new()
  .with_type_sec(directize_perf_type_sec())
  .with_func_sec(@lib.FuncSec::new([type_idx, type_idx, @lib.TypeIdx::new(1U)]))
  .with_table_sec(
    @lib.TableSec::new([
      @lib.Table::new(
        @lib.TableType::new(
          @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func())),
          @lib.Limits::i32(2U, Some(2U)),
        ),
        None,
      ),
    ]),
  )
  .with_elem_sec(
    @lib.ElemSec::new([
      @lib.Elem::new(
        @lib.ElemMode::active(
          @lib.TableIdx::new(0U),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
        ),
        @lib.ElemKind::funcs([@lib.FuncIdx::new(0U), @lib.FuncIdx::new(1U)]),
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(0U))]),
      ),
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_add(),
        ]),
      ),
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
    ]),
  )
}

///|
fn directize_perf_measure(call_count : Int, depth : Int) -> UInt64 {
  for _ in 0..<2 {
    ignore(
      @passes.run_hot_pipeline(
        directize_perf_module(call_count, depth),
        @passes.HotPipelineOptions::new(),
        ["directize"],
      ),
    )
  }
  let samples : Array[UInt64] = []
  for _ in 0..<7 {
    let fixture = directize_perf_module(call_count, depth)
    let start = @lib.trace_now_us()
    let optimized = match
      @passes.run_hot_pipeline(fixture, @passes.HotPipelineOptions::new(), [
        "directize",
      ]) {
      Ok(mod_) => mod_
      Err(err) => abort("expected directize perf fixture success, got \{err}")
    }
    samples.push(@lib.trace_elapsed_us_since(start))
    let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
    if pretty.contains("call_indirect") {
      abort("directize perf fixture must trigger")
    }
  }
  samples.sort()
  samples[samples.length() / 2]
}

///|
#skip("manual native-release directize trigger-bearing select benchmark")
test "directize perf lane bounds trigger-bearing long select discovery" {
  let call_count = 256
  let depth = 64
  let median_us = directize_perf_measure(call_count, depth)
  println("directize calls=\{call_count} depth=\{depth} median_us=\{median_us}")
  assert_true(
    median_us < 22000UL,
    msg="expected trigger-bearing select discovery below 22ms, got \{median_us}us",
  )
}

///|
test "bench directize pass select calls=256 depth=64" (it : @bench.T) {
  let call_count = 256
  let depth = 64
  let fixture = directize_perf_module(call_count, depth)
  let optimized = match
    @passes.run_hot_pipeline(fixture, @passes.HotPipelineOptions::new(), [
      "directize",
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      abort("expected directize benchmark fixture success, got \{err}")
  }
  if optimized
    .pretty_print_func(@lib.FuncIdx::new(2U))
    .contains("call_indirect") {
    abort("directize benchmark fixture must trigger")
  }
  if !fixture.pretty_print_func(@lib.FuncIdx::new(2U)).contains("call_indirect") {
    abort("directize benchmark fixture must remain reusable")
  }
  let options = @passes.HotPipelineOptions::new(validate_final_module=false)
  it.bench(fn() {
    match @passes.run_hot_pipeline(fixture, options, ["directize"]) {
      Ok(mod_) => ignore(mod_.code_sec)
      Err(err) => abort("expected directize benchmark success, got \{err}")
    }
  })
}
