///|
fn oi_raw_module_env_fixture(count : Int) -> @lib.Module {
  let functions : Array[String] = []
  for _ in 0..<count {
    functions.push(
      "(func (result i32 i64) block (type 0) i32.const 7 call \{count} end try_table nop end)",
    )
  }
  let bodies = functions.join(" ")
  pass_test_module_from_wat(
    "(module (type (func (result i32 i64))) (global (mut i64) (i64.const 0)) \{bodies} (func (result i64) i64.const 123 global.set 0 i64.const 9))",
  )
}

///|
test "OI raw return shares tuple cleanup environment and preserves carried effectful lanes" {
  let input = oi_raw_module_env_fixture(2)
  let state = HotPipelineModuleState::new()
  let trace : Array[String] = []
  let options = HotPipelineOptions::new(
    perf=Some(HotPerfSession::new(trace=fn(line) { trace.push(line) })),
  )
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
    // OI intentionally leaves try_table itself unsupported by HOT rewriting;
    // the required raw-return tuple cleanup still removes its preceding wrapper.
    assert_eq(result.reason, "try-table-optimize-instructions-noop")
    assert_true(result.trace_skip_raw)
    assert_false(result.unchanged_original)
    let @lib.Func(_, @lib.Expr(before)) = outputs[index.to_int()]
    let @lib.Func(_, @lib.Expr(after)) = result.func
    assert_eq(after, [
      @lib.Instruction::i32_const(@lib.I32(7)),
      @lib.Instruction::call(@lib.FuncIdx::new(2U)),
      before[1],
    ])
    outputs[index.to_int()] = result.func
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
