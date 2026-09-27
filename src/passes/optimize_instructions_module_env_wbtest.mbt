///|
fn oi_module_env_fixture(count : Int) -> @lib.Module {
  let functions : Array[String] = []
  for _ in 0..<count {
    functions.push(
      "(func (result i32) (local i32 i64 f32 f64) block (type 0) i32.const 1159 call \{count} f32.const 59.5 f64.const 87.25 end local.set 3 local.set 2 local.set 1 local.set 0 local.get 0)",
    )
  }
  let bodies = functions.join(" ")
  pass_test_module_from_wat(
    "(module (type (func (result i32 i64 f32 f64))) (global (mut i64) (i64.const 0)) \{bodies} (func (result i64) i64.const 123 global.set 0 i64.const 22))",
  )
}

///|
test "OI tuple cleanup shares one validation snapshot across lowered functions" {
  let input = oi_module_env_fixture(2)
  let state = HotPipelineModuleState::new()
  let trace : Array[String] = []
  let perf = HotPerfSession::new(trace=fn(line) { trace.push(line) })
  let options = HotPipelineOptions::new(perf=Some(perf))
  let outputs = input.code_sec.unwrap().0.copy()
  for index in [0U, 1U] {
    let result = run_hot_pipeline_func(
      input,
      @lib.FuncIdx::new(index),
      optimize_instructions_descriptor(),
      state,
      { next_type_sec: input.type_sec, type_sec_changed: false, },
      options,
    ).unwrap()
    outputs[index.to_int()] = result.func
    let @lib.Func(_, @lib.Expr(body)) = result.func
    assert_eq(body.filter(fn(i) { i is @lib.Block(_, _) }).length(), 0)
    assert_eq(
      body.filter(fn(i) {
        i is @lib.I32Const(_) ||
        i is @lib.Call(_) ||
        i is @lib.F32Const(_) ||
        i is @lib.F64Const(_)
      }),
      [
        @lib.Instruction::i32_const(@lib.I32(1159)),
        @lib.Instruction::call(@lib.FuncIdx::new(2U)),
        @lib.Instruction::f32_const(@lib.F32(59.5)),
        @lib.Instruction::f64_const(@lib.F64(87.25)),
      ],
    )
  }
  @validate.validate_module(input.with_code_sec(@lib.CodeSec::new(outputs))).unwrap()
  assert_true(state.validation_module_env is Some(_))
  assert_eq(
    trace
    .filter(fn(line) {
      line.contains(
        "perf:timer name=analysis:optimize-instructions-validation-module-env",
      )
    })
    .length(),
    1,
  )
}

///|
test "OI tuple wrapper cleanup consults the shared provider only for multivalue producers" {
  let input = oi_module_env_fixture(2)
  let state = HotPipelineModuleState::new()
  let options = HotPipelineOptions::new()
  let calls = [0]
  let builds = [0]
  let provider = fn() {
    calls[0] += 1
    if state.validation_module_env is None {
      builds[0] += 1
    }
    run_hot_pipeline_require_validation_module_env(input, state, options)
  }
  let ctx = @ir.hot_module_context_from_module(input)
  let outputs = input.code_sec.unwrap().0.copy()
  for index in 0..<2 {
    let original = outputs[index]
    let (cleaned, changed) = run_hot_pipeline_optimize_instructions_cleanup_tuple_wrappers(
      original,
      Some(original),
      input,
      module_ctx=Some(ctx),
      module_env_provider=Some(provider),
    )
    assert_true(changed)
    let @lib.Func(_, @lib.Expr(body)) = cleaned
    assert_eq(body[0:4].to_array(), [
      @lib.Instruction::i32_const(@lib.I32(1159)),
      @lib.Instruction::call(@lib.FuncIdx::new(2U)),
      @lib.Instruction::f32_const(@lib.F32(59.5)),
      @lib.Instruction::f64_const(@lib.F64(87.25)),
    ])
    outputs[index] = cleaned
  }
  @validate.validate_module(input.with_code_sec(@lib.CodeSec::new(outputs))).unwrap()
  assert_eq(calls[0], 2)
  assert_eq(builds[0], 1)
  let plain = outputs[2]
  let (unchanged, changed) = run_hot_pipeline_optimize_instructions_cleanup_tuple_wrappers(
    plain,
    Some(plain),
    input,
    module_ctx=Some(ctx),
    module_env_provider=Some(provider),
  )
  assert_false(changed)
  assert_eq(unchanged, plain)
  assert_eq(calls[0], 2)
}
