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
fn tuple_optimization_perf_candidate_free_module(
  function_count : Int,
) -> @lib.Module {
  let func_types : Array[@lib.TypeIdx] = Array::new(capacity=function_count)
  let funcs : Array[@lib.Func] = Array::new(capacity=function_count)
  for func_idx in 0..<function_count {
    func_types.push(@lib.TypeIdx::new(0U))
    funcs.push(
      @lib.Func::new(
        @lib.Locals::from_types([]),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(func_idx)),
          @lib.Instruction::drop(),
        ]),
      ),
    )
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new(func_types))
  .with_code_sec(@lib.CodeSec::new(funcs))
}

///|
test "bench tuple-optimization candidate-free scalar functions=2000" (
  it : @bench.T,
) {
  let function_count = 2000
  let fixture = tuple_optimization_perf_candidate_free_module(function_count)
  let trace : Array[String] = []
  let preflight = match
    @passes.run_hot_pipeline(
      fixture,
      @passes.HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["tuple-optimization"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      abort(
        "expected candidate-free tuple benchmark preflight success, got \{err}",
      )
  }
  let mut candidate_free_skip_count = 0
  for line in trace {
    if line.contains(
        "pass[tuple-optimization]:skip-raw reason=candidate-free-tuple-optimization-noop",
      ) {
      candidate_free_skip_count += 1
    }
  }
  assert_eq(candidate_free_skip_count, function_count)
  match preflight.code_sec {
    Some(@lib.CodeSec(funcs)) => assert_eq(funcs.length(), function_count)
    None => abort("expected candidate-free tuple benchmark code section")
  }
  let options = @passes.HotPipelineOptions::new(validate_final_module=false)
  it.bench(fn() {
    match @passes.run_hot_pipeline(fixture, options, ["tuple-optimization"]) {
      Ok(mod_) => ignore(mod_.code_sec)
      Err(err) =>
        abort("expected candidate-free tuple benchmark success, got \{err}")
    }
  })
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
