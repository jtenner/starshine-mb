///|
fn tuple_optimization_perf_candidate_module(pair_count : Int) -> @lib.Module {
  let locals : Array[@lib.ValType] = []
  let body : Array[@lib.Instruction] = Array::new(capacity=pair_count * 7)
  for pair_idx in 0..<pair_count {
    let i32_local = pair_idx * 2
    let i64_local = i32_local + 1
    locals.push(@lib.ValType::i32())
    locals.push(@lib.ValType::i64())
    body.push(
      @lib.Instruction::block(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(pair_idx)),
          @lib.Instruction::i64_const(@lib.I64(pair_idx.to_int64())),
        ]),
      ),
    )
    body.push(
      @lib.Instruction::local_set(@lib.LocalIdx::new(i64_local.to_uint())),
    )
    body.push(
      @lib.Instruction::local_set(@lib.LocalIdx::new(i32_local.to_uint())),
    )
    body.push(
      @lib.Instruction::local_get(@lib.LocalIdx::new(i32_local.to_uint())),
    )
    body.push(@lib.Instruction::drop())
    body.push(
      @lib.Instruction::local_get(@lib.LocalIdx::new(i64_local.to_uint())),
    )
    body.push(@lib.Instruction::drop())
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
      @lib.Func::new(@lib.Locals::from_types(locals), @lib.Expr::new(body)),
    ]),
  )
}

///|
test "bench HOT lift tuple-optimization drop-only pairs=2000" (it : @bench.T) {
  let fixture = tuple_optimization_perf_candidate_module(2000)
  let preflight = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
  assert_true(@ir.hot_node_count(preflight) > 0)
  it.bench(fn() {
    let lifted = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
    ignore(@ir.hot_node_count(lifted))
  })
}

///|
test "bench HOT lower tuple-optimization drop-only pairs=2000" (it : @bench.T) {
  let fixture = tuple_optimization_perf_candidate_module(2000)
  let optimized = match
    @passes.run_hot_pipeline(fixture, @passes.HotPipelineOptions::new(), [
      "tuple-optimization",
    ]) {
    Ok(mod_) => mod_
    Err(err) => abort("expected tuple benchmark preflight success, got \{err}")
  }
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
test "bench tuple-optimization pass drop-only pairs=2000" (it : @bench.T) {
  let fixture = tuple_optimization_perf_candidate_module(2000)
  let preflight = match
    @passes.run_hot_pipeline(fixture, @passes.HotPipelineOptions::new(), [
      "tuple-optimization",
    ]) {
    Ok(mod_) => mod_
    Err(err) => abort("expected tuple benchmark preflight success, got \{err}")
  }
  let preflight_has_block = match preflight.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) =>
      body.any(fn(instr) {
        match instr {
          @lib.Block(_, _) => true
          _ => false
        }
      })
    _ => abort("expected one benchmark function")
  }
  assert_false(preflight_has_block)
  let options = @passes.HotPipelineOptions::new(validate_final_module=false)
  it.bench(fn() {
    match @passes.run_hot_pipeline(fixture, options, ["tuple-optimization"]) {
      Ok(mod_) => ignore(mod_.code_sec)
      Err(err) => abort("expected tuple benchmark success, got \{err}")
    }
  })
}
