///|
fn rub_perf_literal_multivalue_module(block_count : Int) -> @lib.Module {
  let body : Array[@lib.Instruction] = Array::new(capacity=block_count * 3)
  for index in 0..<block_count {
    body.push(
      @lib.Instruction::block(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(index)),
          @lib.Instruction::i64_const(@lib.I64(index.to_int64())),
        ]),
      ),
    )
    if index + 1 == block_count {
      body.push(@lib.Instruction::drop())
      body.push(@lib.Instruction::drop())
    } else {
      body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(1U)))
      body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
    }
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([], [@lib.ValType::i32(), @lib.ValType::i64()]),
        ),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i64()]),
        @lib.Expr::new(body),
      ),
    ]),
  )
}

///|
fn rub_perf_median_us(samples : Array[UInt64]) -> UInt64 {
  samples.sort_by(fn(a, b) { a.compare(b) })
  samples[samples.length() / 2]
}

///|
#skip("manual native-release remove-unused-brs literal multivalue benchmark")
test "remove-unused-brs long perf lane measures literal multivalue use accounting" {
  let block_count = 3000
  for _ in 0..<2 {
    match
      @passes.run_hot_pipeline(
        rub_perf_literal_multivalue_module(block_count),
        @passes.HotPipelineOptions::new(),
        ["remove-unused-brs"],
      ) {
      Ok(_) => ()
      Err(err) => fail("expected RUB benchmark warmup success, got \{err}")
    }
  }
  let samples : Array[UInt64] = []
  for _ in 0..<5 {
    let input = rub_perf_literal_multivalue_module(block_count)
    let start = @lib.trace_now_us()
    match
      @passes.run_hot_pipeline(input, @passes.HotPipelineOptions::new(), [
        "remove-unused-brs",
      ]) {
      Ok(_) => ()
      Err(err) => fail("expected RUB benchmark success, got \{err}")
    }
    samples.push(@lib.trace_elapsed_us_since(start))
  }
  println(
    "remove_unused_brs literal_multivalue_blocks=\{block_count} median_us=\{rub_perf_median_us(samples)} samples=\{samples}",
  )
}

///|
test "bench HOT lift remove-unused-brs literal multivalue blocks=3000" (
  it : @bench.T,
) {
  let fixture = rub_perf_literal_multivalue_module(3000)
  let preflight = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
  assert_true(@ir.hot_node_count(preflight) > 0)
  it.bench(fn() {
    let lifted = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
    ignore(@ir.hot_node_count(lifted))
  })
}

///|
test "bench HOT lower remove-unused-brs literal multivalue blocks=3000" (
  it : @bench.T,
) {
  let fixture = rub_perf_literal_multivalue_module(3000)
  let lifted = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
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
test "bench remove-unused-brs pass literal multivalue blocks=3000" (
  it : @bench.T,
) {
  let fixture = rub_perf_literal_multivalue_module(3000)
  match
    @passes.run_hot_pipeline(fixture, @passes.HotPipelineOptions::new(), [
      "remove-unused-brs",
    ]) {
    Ok(_) => ()
    Err(err) => abort("expected RUB benchmark fixture success, got \{err}")
  }
  let options = @passes.HotPipelineOptions::new(validate_final_module=false)
  it.bench(fn() {
    match @passes.run_hot_pipeline(fixture, options, ["remove-unused-brs"]) {
      Ok(mod_) => ignore(mod_.code_sec)
      Err(err) => abort("expected RUB benchmark success, got \{err}")
    }
  })
}
